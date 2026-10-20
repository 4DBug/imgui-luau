-- Layers and tiles (one Frame per draw list and kind, TILE x TILE EditableImages); draw list snapshot/compare
local Raster = IM_INCLUDE("roblox/raster.lua")
local Textures = IM_INCLUDE("roblox/textures.lua")

local floor, max = math.floor, math.max
local readu32, writeu32, readf64, writef64 = buffer.readu32, buffer.writeu32, buffer.readf64, buffer.writef64
local TILE = Raster.TILE
local EditableImages = Textures.EditableImages

local M = {}
-- content up to this far off screen is kept, so dragging a window past the edge doesn't redraw it
local CLIP_PAD = 2048
M.CLIP_PAD = CLIP_PAD
-- per draw command, filled by CollectPrims for Snapshot: no primitive clipped, layer kind, bounds of its primitives
local CmdUnclipped, CmdKind, CmdBoundsX0, CmdBoundsY0, CmdBoundsX1, CmdBoundsY1 = {}, {}, {}, {}, {}, {}
M.CmdUnclipped, M.CmdKind, M.CmdBoundsX0, M.CmdBoundsY0, M.CmdBoundsX1, M.CmdBoundsY1 =
    CmdUnclipped, CmdKind, CmdBoundsX0, CmdBoundsY0, CmdBoundsX1, CmdBoundsY1
-- free per-tile primitive lists, 4 at a time
EditableImages.ListPool = {}

-- Kinds: 1 = before the window content (background, title bar, scrollbar), 2 = content (at the scroll origin in a
-- ClipsDescendants frame, so scrolling just moves it), 3 = drawn after content, not clipped to it (menu bar).
local function NewFrame(parent, clips)
    local frame = Instance.new("Frame")
    frame.Name = "Layer"
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Size = UDim2.fromOffset(0, 0)
    frame.ClipsDescendants = clips
    frame.Visible = false
    frame.Parent = parent
    return frame
end

function M.GetLayer(BackendData, draw_list, kind)
    local set = BackendData.Layers[draw_list]
    if not set then
        set = { LastUsed = 0 }
        BackendData.Layers[draw_list] = set
    end
    local layer = set[kind]
    if layer then return layer end
    local root, frame
    if kind == 2 then
        root = NewFrame(BackendData.Gui, true)
        frame = NewFrame(root, false)
        frame.Visible = true
    else
        frame = NewFrame(BackendData.Gui, false)
        root = frame
    end
    layer = {
        Root = root, Frame = frame, Tiles = {},
        TileHash1 = {}, TileHash2 = {}, TileCounts = {}, TileLists = {},
        TileListHash1 = {}, TileListHash2 = {}, TileListFlat = {}, TileX = {}, TileY = {},
        Touched = {}, TouchedCount = 0,
        Visible = false, X = false, Y = false, Z = -1,
        ClipX0 = false, ClipY0 = false, ClipX1 = false, ClipY1 = false,
    }
    set[kind] = layer
    return layer
end

function M.HideLayer(layer)
    if layer.Visible then
        layer.Visible = false
        layer.Root.Visible = false
    end
end

-- recycle: to EditableImages.Pool. Its label stays parented (hidden): Studio reparenting costs far more than a
-- property set, and a scrolling layer's next tile usually goes back into the same frame
function EditableImages.FreeTile(layer, key, recycle)
    local tile = layer.Tiles[key]
    if recycle and #EditableImages.Pool < EditableImages.PoolMax then
        table.insert(EditableImages.Pool, tile)
    else
        EditableImages.Destroy(tile.Image)
        tile.Label:Destroy()
    end
    layer.Tiles[key] = nil
    if EditableImages.StageTiming then EditableImages.AddStat("TilesFreed", 1) end
    if (layer.TileCounts[key] or 0) > 0 then return end -- touched this frame: its primitive list is still needed
    local lp = EditableImages.ListPool
    if layer.TileLists[key] and #lp < 256 then
        lp[#lp + 1] = layer.TileLists[key]
        lp[#lp + 1] = layer.TileListHash1[key]
        lp[#lp + 1] = layer.TileListHash2[key]
        lp[#lp + 1] = layer.TileListFlat[key]
    end
    layer.TileLists[key], layer.TileListHash1[key], layer.TileListHash2[key], layer.TileListFlat[key] =
        nil, nil, nil, nil
    layer.TileHash1[key], layer.TileHash2[key], layer.TileCounts[key], layer.TileX[key], layer.TileY[key] =
        nil, nil, nil, nil, nil
end

function M.GetTile(BackendData, layer, key, tx, ty)
    local tile = layer.Tiles[key]
    if tile then return tile end
    local scale = BackendData.Scale
    local old = table.remove(EditableImages.Pool)
    local label, img
    if old then
        label, img = old.Label, old.Image
    else
        img = EditableImages.Create(TILE, TILE)
        if not img then return nil end -- over the budget even after eviction: the caller skips this tile this frame
        label = Instance.new("ImageLabel")
        label.Name = "Tile"
        label.BackgroundTransparency = 1
        label.BorderSizePixel = 0
        label.ResampleMode = Enum.ResamplerMode.Pixelated
        label.ImageContent = Content.fromObject(img)
        label.Visible = false
    end
    if not old or old.Scale ~= scale then label.Size = UDim2.fromOffset(TILE / scale, TILE / scale) end
    label.Position = UDim2.fromOffset(tx * TILE / scale, ty * TILE / scale)
    if not old or old.Active ~= BackendData.TilesActive then label.Active = BackendData.TilesActive end
    if not old or old.Parent ~= layer.Frame then label.Parent = layer.Frame end
    -- Content*: content bounds; Valid*: where the image pixels are current. A recycled tile keeps both (they still describe
    -- its image): its first draw is a full one (DrawnCount -1) that only clears old + new content bounds.
    if old then
        tile = old
        tile.Hash1, tile.Hash2, tile.Visible, tile.Used, tile.Deferred, tile.DrawnCount =
            -1, -1, false, BackendData.FrameNo, nil, -1
        tile.Scale, tile.Active, tile.Parent = scale, BackendData.TilesActive, layer.Frame
    else
        tile = {
            Image = img, Label = label,
            Hash1 = -1, Hash2 = -1, Visible = false, Used = BackendData.FrameNo,
            ContentX0 = TILE, ContentY0 = TILE, ContentX1 = 0, ContentY1 = 0,
            ValidX0 = 0, ValidY0 = 0, ValidX1 = TILE, ValidY1 = TILE,
            Scale = scale, Active = BackendData.TilesActive, Parent = layer.Frame,
            DrawnCount = -1, DrawnHash1 = {}, DrawnHash2 = {}, DrawnFlat = {},
            DrawnX0 = {}, DrawnY0 = {}, DrawnX1 = {}, DrawnY1 = {},
        }
    end
    layer.Tiles[key] = tile
    if EditableImages.StageTiming then EditableImages.AddStat("TilesCreated", 1) end
    return tile
end

function M.DestroyLayerSet(set)
    for kind = 1, 3 do
        local layer = set[kind]
        if layer then
            for _, tile in pairs(layer.Tiles) do EditableImages.Destroy(tile.Image) end
            for _, t in EditableImages.Pool do
                if t.Parent == layer.Frame then
                    t.Label.Parent = nil
                    t.Parent = nil
                end
            end
            layer.Root:Destroy()
        end
    end
end

function M.DestroyTiles(BackendData)
    for _, set in pairs(BackendData.Layers) do M.DestroyLayerSet(set) end
    BackendData.Layers = {}
end

-- Snapshot compared exactly with the next frame's list: 1 = identical (only restack), 2 = moved by whole pixels
-- (only move the layers), 0 = changed. Per command: clip (4 f64), ElemCount, IdxOffset, VtxOffset (u32), tex id
-- (f64), kind (u8), unclipped (u8), bounds of its primitives (4 x i32).
local CMD_STRIDE = 70

@native
function M.Snapshot(set, draw_list, ox, oy, ScreenWidth, ScreenHeight)
    local nv = draw_list.VtxBuffer.Size * VTX_STRIDE
    local idx, ni = draw_list.IdxBuffer.Data, draw_list.IdxBuffer.Size
    local ncmd = draw_list.CmdBuffer.Size
    local sv, si, sc = set.SnapVtx, set.SnapIdx, set.SnapCmds
    if not sv or buffer.len(sv) < nv then
        sv = buffer.create(max(nv, 64) * 2)
        set.SnapVtx = sv
    end
    if not si then
        si = {}
        set.SnapIdx = si
    end
    if not sc or buffer.len(sc) < ncmd * CMD_STRIDE then
        sc = buffer.create(max(ncmd, 4) * CMD_STRIDE * 2)
        set.SnapCmds = sc
    end
    buffer.copy(sv, 0, draw_list.VtxBuffer.Buf, 0, nv)
    table.move(idx, 1, ni, 1, si)
    local o, ci = 0, 0
    for _, pcmd in draw_list.CmdBuffer:iter() do
        if pcmd.UserCallback ~= nil then
            set.SnapOK = false
            return
        end
        local c = pcmd.ClipRect
        writef64(sc, o, c.x)
        writef64(sc, o + 8, c.y)
        writef64(sc, o + 16, c.z)
        writef64(sc, o + 24, c.w)
        writeu32(sc, o + 32, pcmd.ElemCount)
        writeu32(sc, o + 36, pcmd.IdxOffset)
        writeu32(sc, o + 40, pcmd.VtxOffset)
        writef64(sc, o + 44, pcmd:GetTexID())
        ci += 1
        buffer.writeu8(sc, o + 52, CmdKind[ci] or 0)
        buffer.writeu8(sc, o + 53, CmdUnclipped[ci] and 1 or 0)
        if CmdUnclipped[ci] then
            buffer.writei32(sc, o + 54, CmdBoundsX0[ci])
            buffer.writei32(sc, o + 58, CmdBoundsY0[ci])
            buffer.writei32(sc, o + 62, CmdBoundsX1[ci])
            buffer.writei32(sc, o + 66, CmdBoundsY1[ci])
        end
        o += CMD_STRIDE
    end
    set.SnapVtxBytes, set.SnapIdxCount, set.SnapCmdCount = nv, ni, ncmd
    set.SnapOriginX, set.SnapOriginY, set.SnapScreenW, set.SnapScreenH = ox, oy, ScreenWidth, ScreenHeight
    set.SnapHasContent = draw_list._ContentClipX0 ~= nil
    set.SnapContentX0, set.SnapContentY0, set.SnapContentX1, set.SnapContentY1 =
        draw_list._ContentClipX0 or 0, draw_list._ContentClipY0 or 0, draw_list._ContentClipX1 or 0,
        draw_list._ContentClipY1 or 0
    set.SnapScrollX, set.SnapScrollY = draw_list._ScrollOriginX or 0, draw_list._ScrollOriginY or 0
    set.SnapOK = true
end

-- The snapshot of a list CompareDrawList found moved by (dx, dy): only its vertices, clip rects, content clip,
-- scroll origin, primitive bounds and extents move (counts, indices, kinds are equal; Cmd* describe another list now)
@native
function M.ShiftSnapshot(set, draw_list, dx, dy)
    buffer.copy(set.SnapVtx, 0, draw_list.VtxBuffer.Buf, 0, set.SnapVtxBytes)
    local sc, o = set.SnapCmds, 0
    for _, pcmd in draw_list.CmdBuffer:iter() do
        local c = pcmd.ClipRect
        writef64(sc, o, c.x)
        writef64(sc, o + 8, c.y)
        writef64(sc, o + 16, c.z)
        writef64(sc, o + 24, c.w)
        if buffer.readu8(sc, o + 53) ~= 0 then
            buffer.writei32(sc, o + 54, buffer.readi32(sc, o + 54) + dx)
            buffer.writei32(sc, o + 58, buffer.readi32(sc, o + 58) + dy)
            buffer.writei32(sc, o + 62, buffer.readi32(sc, o + 62) + dx)
            buffer.writei32(sc, o + 66, buffer.readi32(sc, o + 66) + dy)
        end
        o += CMD_STRIDE
    end
    if set.SnapHasContent then
        set.SnapContentX0, set.SnapContentY0, set.SnapContentX1, set.SnapContentY1 = draw_list._ContentClipX0,
            draw_list._ContentClipY0, draw_list._ContentClipX1, draw_list._ContentClipY1
        set.SnapScrollX, set.SnapScrollY = draw_list._ScrollOriginX, draw_list._ScrollOriginY
    end
    set.SnapExtentX0 += dx
    set.SnapExtentY0 += dy
    set.SnapExtentX1 += dx
    set.SnapExtentY1 += dy
end

-- a + d == b exactly, with no rounding in a + d (so every later "x - origin" gives the same result as before the move)
@native
local function ShiftedExact(a, d, b)
    local s = a + d
    if s ~= b then return false end
    local bb = s - a
    return (a - (s - bb)) + (d - bb) == 0
end

@native
function M.CompareDrawList(set, draw_list, ox, oy, ScreenWidth, ScreenHeight)
    if not set or not set.SnapOK then return 0 end
    local nv = draw_list.VtxBuffer.Size * VTX_STRIDE
    local ni, ncmd = draw_list.IdxBuffer.Size, draw_list.CmdBuffer.Size
    if nv ~= set.SnapVtxBytes or ni ~= set.SnapIdxCount or ncmd ~= set.SnapCmdCount or ox ~= set.SnapOriginX
        or oy ~= set.SnapOriginY or ScreenWidth ~= set.SnapScreenW or ScreenHeight ~= set.SnapScreenH then
        return 0
    end
    if (draw_list._ContentClipX0 ~= nil) ~= set.SnapHasContent then return 0 end
    local vb, sv = draw_list.VtxBuffer.Buf, set.SnapVtx
    if nv == 0 then return 1 end
    -- translation from the first vertex: whole pixels only, and only with DisplayPos at 0 (so it stays exact)
    local dx, dy = readf64(vb, 0) - readf64(sv, 0), readf64(vb, 8) - readf64(sv, 8)
    if dx ~= dx or dy ~= dy then return 0 end
    if dx == 0 and dy == 0 then
        -- per vertex: x y u v as f64s + col, not readstring == (that allocated 2 vertex-buffer strings per list per
        -- frame: GC spikes) or 9 u32s (3x slower). Equal f64s have equal bits except +-0: their sign words decide.
        for v = 0, nv - VTX_STRIDE, VTX_STRIDE do
            local x, y, u, w = readf64(vb, v), readf64(vb, v + 8), readf64(vb, v + 16), readf64(vb, v + 24)
            if x ~= readf64(sv, v) or y ~= readf64(sv, v + 8) or u ~= readf64(sv, v + 16)
                or w ~= readf64(sv, v + 24) or readu32(vb, v + 32) ~= readu32(sv, v + 32) then
                return 0
            end
            if x == 0 or y == 0 or u == 0 or w == 0 then
                for p = v + 4, v + 28, 8 do if readu32(vb, p) ~= readu32(sv, p) then return 0 end end
            end
        end
    else
        if dx ~= floor(dx) or dy ~= floor(dy) or ox ~= 0 or oy ~= 0 or not set.SnapLimitFree then return 0 end
        -- everything must stay as far from the clip limits as before (nothing newly clamped)
        if set.SnapExtentX0 + dx < -CLIP_PAD or set.SnapExtentY0 + dy < -CLIP_PAD
            or set.SnapExtentX1 + dx > ScreenWidth + CLIP_PAD or set.SnapExtentY1 + dy > ScreenHeight + CLIP_PAD then
            return 0
        end
    end
    local idx, si = draw_list.IdxBuffer.Data, set.SnapIdx
    local n4 = ni - ni % 4
    for i = 1, n4, 4 do
        if idx[i] ~= si[i] or idx[i + 1] ~= si[i + 1] or idx[i + 2] ~= si[i + 2] or idx[i + 3] ~= si[i + 3] then
            return 0
        end
    end
    for i = n4 + 1, ni do if idx[i] ~= si[i] then return 0 end end
    local sc, o = set.SnapCmds, 0
    local ccx0, ccy0, ccx1, ccy1 = draw_list._ContentClipX0, draw_list._ContentClipY0, draw_list._ContentClipX1,
        draw_list._ContentClipY1
    local seen_content = false
    for _, pcmd in draw_list.CmdBuffer:iter() do
        if pcmd.UserCallback ~= nil then return 0 end
        if pcmd.ElemCount ~= readu32(sc, o + 32) or pcmd.IdxOffset ~= readu32(sc, o + 36)
            or pcmd.VtxOffset ~= readu32(sc, o + 40) or pcmd:GetTexID() ~= readf64(sc, o + 44) then
            return 0
        end
        local c = pcmd.ClipRect
        if dx == 0 and dy == 0 then
            if c.x ~= readf64(sc, o) or c.y ~= readf64(sc, o + 8) or c.z ~= readf64(sc, o + 16)
                or c.w ~= readf64(sc, o + 24) then
                return 0
            end
        elseif not (ShiftedExact(readf64(sc, o), dx, c.x) and ShiftedExact(readf64(sc, o + 8), dy, c.y)
            and ShiftedExact(readf64(sc, o + 16), dx, c.z) and ShiftedExact(readf64(sc, o + 24), dy, c.w)) then
            -- an unchanged clip rect (e.g. the viewport) is fine if it clips none of this command's primitives
            if c.x ~= readf64(sc, o) or c.y ~= readf64(sc, o + 8) or c.z ~= readf64(sc, o + 16)
                or c.w ~= readf64(sc, o + 24)
                or buffer.readu8(sc, o + 53) == 0 then return 0 end
            if buffer.readi32(sc, o + 54) + dx < floor(c.x) or buffer.readi32(sc, o + 58) + dy < floor(c.y)
                or buffer.readi32(sc, o + 62) + dx > floor(c.z)
                or buffer.readi32(sc, o + 66) + dy > floor(c.w) then return 0 end
        end
        if pcmd.ElemCount > 0 then
            local kind = 1
            if ccx0 and c.x >= ccx0 and c.y >= ccy0 and c.z <= ccx1 and c.w <= ccy1 then
                kind = 2
                seen_content = true
            elseif seen_content then kind = 3 end
            if kind ~= buffer.readu8(sc, o + 52) then return 0 end
        end
        o += CMD_STRIDE
    end
    if dx == 0 and dy == 0 then
        if set.SnapHasContent and (draw_list._ContentClipX0 ~= set.SnapContentX0
            or draw_list._ContentClipY0 ~= set.SnapContentY0 or draw_list._ContentClipX1 ~= set.SnapContentX1
            or draw_list._ContentClipY1 ~= set.SnapContentY1 or draw_list._ScrollOriginX ~= set.SnapScrollX
            or draw_list._ScrollOriginY ~= set.SnapScrollY) then return 0 end
        return 1
    end
    if set.SnapHasContent and not (ShiftedExact(set.SnapContentX0, dx, draw_list._ContentClipX0)
        and ShiftedExact(set.SnapContentY0, dy, draw_list._ContentClipY0)
        and ShiftedExact(set.SnapContentX1, dx, draw_list._ContentClipX1)
        and ShiftedExact(set.SnapContentY1, dy, draw_list._ContentClipY1)
        and ShiftedExact(set.SnapScrollX, dx, draw_list._ScrollOriginX)
        and ShiftedExact(set.SnapScrollY, dy, draw_list._ScrollOriginY)) then return 0 end
    for v = 0, nv - VTX_STRIDE, VTX_STRIDE do
        if not ShiftedExact(readf64(sv, v), dx, readf64(vb, v))
            or not ShiftedExact(readf64(sv, v + 8), dy, readf64(vb, v + 8))
            or readf64(vb, v + 16) ~= readf64(sv, v + 16) or readf64(vb, v + 24) ~= readf64(sv, v + 24)
            or readu32(vb, v + 32) ~= readu32(sv, v + 32) then return 0 end
    end
    return 2, dx, dy
end

function M.ShiftLayer(layer, dx, dy, scale)
    layer.X += dx
    layer.Y += dy
    local root = layer.Root
    if root ~= layer.Frame then
        layer.ClipX0 += dx
        layer.ClipY0 += dy
        layer.ClipX1 += dx
        layer.ClipY1 += dy
        root.Position = UDim2.fromOffset(layer.ClipX0 / scale, layer.ClipY0 / scale)
    else
        root.Position = UDim2.fromOffset(layer.X / scale, layer.Y / scale)
    end
end

return M
