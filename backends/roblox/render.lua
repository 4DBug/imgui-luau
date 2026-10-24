-- Rendering: collect primitives, hash them into tiles, redraw + upload changed tiles (RenderDrawData).
local Raster = IM_INCLUDE("roblox/raster.lua")
local Textures = IM_INCLUDE("roblox/textures.lua")
local Layers = IM_INCLUDE("roblox/layers.lua")
local Overlays = IM_INCLUDE("roblox/overlays.lua")

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local readu32, readf64 = buffer.readu32, buffer.readf64
local SetTarget, ClearRect, DrawPrim = Raster.SetTarget, Raster.ClearRect, Raster.DrawPrim
local TILE = Raster.TILE
local TILE_SIZE = Vector2.new(TILE, TILE)
local EditableImages, PB, PE, GetBackendData, UpdateTexture = Textures.EditableImages, Textures.PB, Textures.PE,
    Textures.GetBackendData, Textures.UpdateTexture
local GetLayer, HideLayer, GetTile, DestroyLayerSet, Snapshot, CompareDrawList, ShiftLayer = Layers.GetLayer,
    Layers.HideLayer, Layers.GetTile, Layers.DestroyLayerSet, Layers.Snapshot, Layers.CompareDrawList, Layers.ShiftLayer
local ShiftSnapshot = Layers.ShiftSnapshot
local CmdUnclipped, CmdKind, CmdBoundsX0, CmdBoundsY0, CmdBoundsX1, CmdBoundsY1 = Layers.CmdUnclipped, Layers.CmdKind,
    Layers.CmdBoundsX0, Layers.CmdBoundsY0, Layers.CmdBoundsX1, Layers.CmdBoundsY1
local CLIP_PAD = Layers.CLIP_PAD
local PlaceOverlays = Overlays.PlaceOverlays

local M = {}
-- Parallel executor state; parallel.lua adds its functions. On: enabled; Active: used by the current RenderDrawData.
local Parallel = { On = false, Active = false }
M.Parallel = Parallel

local P1, P2 = 2147483647, 2147483629 -- two independent 31 bit hashes per tile (collision odds ~2^-62)
local LAYER_KEEP_FRAMES = 120
local MAX_DEFER_FRAMES = 8 -- a changed tile is redrawn at the latest this many frames later, even over the budget

local PrimA, PrimB, PrimC, PrimD, PrimGradient = {}, {}, {}, {}, {}
local PrimBoundsX0, PrimBoundsY0, PrimBoundsX1, PrimBoundsY1 = {}, {}, {}, {}
-- a primitive's draw command (index into Cmd*, numbered through the frame): its texture, vertex buffer and clip
local PrimCmd = {}
local CmdTexture, CmdTexId, CmdVtxBuffer = {}, {}, {}
local CmdClipX0, CmdClipY0, CmdClipX1, CmdClipY1 = {}, {}, {}, {}
local CmdCount = 0
-- flat rect (one colour, one uv or untextured): HashTiles hashes its clipped rect per tile
local PrimFlat = {}
-- the current draw list's primitives per layer kind (filled by CollectPrims): count, and min bounds for kinds 1 and 3
local LayerPrims1, LayerPrims2, LayerPrims3 = {}, {}, {}
local Kind1Count, Kind2Count, Kind3Count, Kind1X, Kind1Y, Kind3X, Kind3Y = 0, 0, 0, 0, 0, 0, 0
M.PrimA, M.PrimB, M.PrimC, M.PrimD, M.PrimGradient = PrimA, PrimB, PrimC, PrimD, PrimGradient
M.PrimBoundsX0, M.PrimBoundsY0, M.PrimBoundsX1, M.PrimBoundsY1 = PrimBoundsX0, PrimBoundsY0, PrimBoundsX1, PrimBoundsY1
M.PrimCmd, M.CmdTexture, M.CmdTexId, M.CmdVtxBuffer = PrimCmd, CmdTexture, CmdTexId, CmdVtxBuffer
M.CmdClipX0, M.CmdClipY0, M.CmdClipX1, M.CmdClipY1 = CmdClipX0, CmdClipY0, CmdClipX1, CmdClipY1

-- Adds [a, c) x [b, d) to the n dirty rects DX0..DY1 (merged unless that wastes area), returns the count
EditableImages.DX0, EditableImages.DY0, EditableImages.DX1, EditableImages.DY1 = {}, {}, {}, {}
@native
function EditableImages.AddRect(n: number, a: number, b: number, c: number, d: number): number
    if a >= c or b >= d then return n end
    local X0, Y0, X1, Y1 = EditableImages.DX0, EditableImages.DY0, EditableImages.DX1, EditableImages.DY1
    local best, best_grow = 1, math.huge
    for i = 1, n do
        local e, f, g, h = X0[i], Y0[i], X1[i], Y1[i]
        local ux0, uy0, ux1, uy1 = min(a, e), min(b, f), max(c, g), max(d, h)
        local box, own = (ux1 - ux0) * (uy1 - uy0), (g - e) * (h - f)
        local ov = max(min(c, g) - max(a, e), 0) * max(min(d, h) - max(b, f), 0)
        -- waste outside both rects vs. apart: the overlap twice + a primitive pass and an upload (~2048 px)
        if box - ((c - a) * (d - b) + own - ov) <= ov + 2048 then
            X0[i], Y0[i], X1[i], Y1[i] = ux0, uy0, ux1, uy1
            return n
        end
        if box - own < best_grow then best, best_grow = i, box - own end
    end
    if n < 4 then
        n += 1
        X0[n], Y0[n], X1[n], Y1[n] = a, b, c, d
    else
        X0[best], Y0[best], X1[best], Y1[best] = min(a, X0[best]), min(b, Y0[best]), max(c, X1[best]), max(d, Y1[best])
    end
    return n
end

-- Primitives with a vertex CompareDrawList found drifted (DriftSet[vertex offset // VTX_STRIDE + 1], current draw list):
-- their hashes get DriftMark* (new every frame) added, so their tiles are redrawn even when the hash doesn't see the ulp
local DriftSet, DriftOn, DriftMark1, DriftMark2 = table.create(4096, false), false, 0, 0

-- One primitive's HashTiles entry hash, for PatchDrawList (the same math as HashTiles' inlined copy: keep both equal).
-- Returns h1, h2 and the flat signature (>= 0: a flat rect, whose per-tile hash is FlatTileHash's)
@native
local function PrimHash(p, lx0, ly0, ox, oy)
    local cmd = PrimCmd[p]
    local vbuf, va, vd, tex_id = CmdVtxBuffer[cmd], PrimA[p], PrimD[p], CmdTexId[cmd]
    if PrimFlat[p] then
        local RectColor, RectUV = readu32(vbuf, va + 32), readf64(vbuf, va + 16) * 8192 + readf64(vbuf, va + 24)
        return 0, 0, ((RectColor * 8191 + RectUV * 4096) % P1 * 64 + tex_id) % P1
    end
    local cx0, cy0, cx1, cy1 = PrimBoundsX0[p] - lx0, PrimBoundsY0[p] - ly0, PrimBoundsX1[p] - lx0,
        PrimBoundsY1[p] - ly0
    local gk, v2, v3, nv = PrimGradient[p], PrimC[p], PrimB[p], 3
    local g = gk or 0
    local h1 = (((cx0 * 8191 + cy0) * 8191 + cx1) * 8 + g) % P1
    local h2 = (((cy1 * 8191 + cx1) * 8191 + cy0 + tex_id) * 8 + g) % P2
    local vax, vay = lx0 + ox, ly0 + oy
    if vd then
        nv = (gk == 3 or gk == 4) and 4 or 2
    else
        v2, v3 = v3, v2
    end
    local v = va
    for k = 1, nv do
        if k == 2 then v = v2 elseif k == 3 then v = v3 elseif k == 4 then v = vd end
        local x, y = readf64(vbuf, v) - vax, readf64(vbuf, v + 8) - vay
        local uv = readf64(vbuf, v + 16) * 8192 + readf64(vbuf, v + 24)
        local c = readu32(vbuf, v + 32)
        h1 = (h1 * 48271 + (x * 4096 + y) * 31 + uv * 4096 + c) % P1
        h2 = (h2 * 16807 + (y * 4093 + x) * 17 + uv * 65521 + c * 3) % P2
    end
    return h1, h2, -1
end

-- A flat rect's hash in tile (tx, ty) (HashTiles' per-tile flat hash)
@native
local function FlatTileHash(p, lx0, ly0, tx, ty)
    local cmd = PrimCmd[p]
    local vbuf, va, tex_id = CmdVtxBuffer[cmd], PrimA[p], CmdTexId[cmd]
    local RectColor, RectUV = readu32(vbuf, va + 32), readf64(vbuf, va + 16) * 8192 + readf64(vbuf, va + 24)
    local cx0, cy0, cx1, cy1 = PrimBoundsX0[p] - lx0, PrimBoundsY0[p] - ly0, PrimBoundsX1[p] - lx0,
        PrimBoundsY1[p] - ly0
    local px0, py0 = tx * TILE, ty * TILE
    local ix0, iy0 = max(cx0 - px0, 0), max(cy0 - py0, 0)
    local ix1, iy1 = min(cx1 - px0, TILE), min(cy1 - py0, TILE)
    local r = ((ix0 * 131 + iy0) * 131 + ix1) * 131 + iy1
    return ((r * 48271 + RectColor) % P1 * 48271 + RectUV * 4096 + 7) % P1,
        ((r * 16807 + RectColor + tex_id) % P2 * 16807 + RectUV * 65521 + 11) % P2
end

-- HashTiles scratch, per touched tile (slot = its index in layer.Touched): tile key -> slot, its list, count, hashes
local KeySlot, SlotCount, SlotHash1, SlotHash2 = {}, {}, {}, {}
local SlotList, SlotListHash1, SlotListHash2, SlotListFlat = {}, {}, {}, {}

@native
local function HashTiles(layer, plist, np, lx0, ly0, ox, oy)
    local TileHash1, TileHash2, TileCounts, TileLists, Touched =
        layer.TileHash1, layer.TileHash2, layer.TileCounts, layer.TileLists, layer.Touched
    local TileListHash1, TileListHash2, TileListFlat = layer.TileListHash1, layer.TileListHash2, layer.TileListFlat
    for k = 1, layer.TouchedCount do TileCounts[Touched[k]] = 0 end
    local TouchedCount = 0
    local CurKey, CurSlot, CurCount, CurHash1, CurHash2, CurList, CurListHash1, CurListHash2, CurListFlat =
        -1, 0, 0, 0, 0, nil, nil, nil, nil
    local TileXs, TileYs = layer.TileX, layer.TileY
    -- upvalues as locals: cheaper in the hot loop
    local PrimBoundsX0, PrimBoundsY0, PrimBoundsX1, PrimBoundsY1 = PrimBoundsX0, PrimBoundsY0, PrimBoundsX1, PrimBoundsY1
    local PrimA, PrimB, PrimC, PrimD, PrimGradient, PrimCmd, CmdTexId, CmdVtxBuffer, PrimFlat =
        PrimA, PrimB, PrimC, PrimD, PrimGradient, PrimCmd, CmdTexId, CmdVtxBuffer, PrimFlat
    local KeySlot, SlotCount, SlotHash1, SlotHash2 = KeySlot, SlotCount, SlotHash1, SlotHash2
    local SlotList, SlotListHash1, SlotListHash2, SlotListFlat = SlotList, SlotListHash1, SlotListHash2, SlotListFlat
    local TILE = TILE
    for pi = 1, np do
        local p = plist[pi]
        local cmd = PrimCmd[p]
        local tex_id = CmdTexId[cmd]
        -- hash the clipped bounds, not the clip: a window clipped by the fixed viewport stays hash-stable when moved
        local cx0, cy0, cx1, cy1 = PrimBoundsX0[p] - lx0, PrimBoundsY0[p] - ly0, PrimBoundsX1[p] - lx0,
            PrimBoundsY1[p] - ly0
        local vbuf = CmdVtxBuffer[cmd]
        local va, vd = PrimA[p], PrimD[p]
        -- flat rect: hash its clipped rect per tile, so resizing only changes the tiles its edges cross
        local FlatRect, RectColor, RectUV = PrimFlat[p], 0, 0
        if FlatRect then
            RectColor, RectUV = readu32(vbuf, va + 32), readf64(vbuf, va + 16) * 8192 + readf64(vbuf, va + 24)
        end
        local h1, h2 = 0, 0
        local FlatSig = -1
        if FlatRect then
            FlatSig = ((RectColor * 8191 + RectUV * 4096) % P1 * 64 + tex_id) % P1
        else
            -- the kind (gk: 0 triangle / plain quad, 1 / 2 gradient, 3 line quad, 4 triangle pair) mixed into the
            -- bounds: no extra %
            local gk = PrimGradient[p]
            local g = gk or 0
            h1 = (((cx0 * 8191 + cy0) * 8191 + cx1) * 8 + g) % P1
            h2 = (((cy1 * 8191 + cx1) * 8191 + cy0 + tex_id) * 8 + g) % P2
            local vax, vay = lx0 + ox, ly0 + oy
            -- vertices: triangle a, b, c; axis aligned quad a, c (CollectPrims checked that b, d follow from them + kind);
            -- line quad, triangle pair (any shape) a, c, b, d. Unrolled (PrimHash's loop, same math): one % per hash,
            -- h < 2^31, so h * 48271 + the terms (|x|, |y| < 2^15, uv < 2^14, c < 2^32) stays below 2^53
            local x, y = readf64(vbuf, va) - vax, readf64(vbuf, va + 8) - vay
            local uv = readf64(vbuf, va + 16) * 8192 + readf64(vbuf, va + 24)
            local c = readu32(vbuf, va + 32)
            h1 = (h1 * 48271 + (x * 4096 + y) * 31 + uv * 4096 + c) % P1
            h2 = (h2 * 16807 + (y * 4093 + x) * 17 + uv * 65521 + c * 3) % P2
            local v = vd and PrimC[p] or PrimB[p]
            x, y = readf64(vbuf, v) - vax, readf64(vbuf, v + 8) - vay
            uv = readf64(vbuf, v + 16) * 8192 + readf64(vbuf, v + 24)
            c = readu32(vbuf, v + 32)
            h1 = (h1 * 48271 + (x * 4096 + y) * 31 + uv * 4096 + c) % P1
            h2 = (h2 * 16807 + (y * 4093 + x) * 17 + uv * 65521 + c * 3) % P2
            if not vd or gk == 3 or gk == 4 then
                v = vd and PrimB[p] or PrimC[p]
                x, y = readf64(vbuf, v) - vax, readf64(vbuf, v + 8) - vay
                uv = readf64(vbuf, v + 16) * 8192 + readf64(vbuf, v + 24)
                c = readu32(vbuf, v + 32)
                h1 = (h1 * 48271 + (x * 4096 + y) * 31 + uv * 4096 + c) % P1
                h2 = (h2 * 16807 + (y * 4093 + x) * 17 + uv * 65521 + c * 3) % P2
                if vd then
                    x, y = readf64(vbuf, vd) - vax, readf64(vbuf, vd + 8) - vay
                    uv = readf64(vbuf, vd + 16) * 8192 + readf64(vbuf, vd + 24)
                    c = readu32(vbuf, vd + 32)
                    h1 = (h1 * 48271 + (x * 4096 + y) * 31 + uv * 4096 + c) % P1
                    h2 = (h2 * 16807 + (y * 4093 + x) * 17 + uv * 65521 + c * 3) % P2
                end
            end
            if DriftOn and (DriftSet[va // VTX_STRIDE + 1] or DriftSet[PrimB[p] // VTX_STRIDE + 1]
                or DriftSet[PrimC[p] // VTX_STRIDE + 1] or (vd and DriftSet[vd // VTX_STRIDE + 1])) then
                h1 = (h1 + DriftMark1) % P1
                h2 = (h2 + DriftMark2) % P2
            end
        end
        -- the tiles it touches, row by row (one loop, no nested for: most primitives touch one tile; never empty)
        local tx0, tx1, ty1 = cx0 // TILE, (cx1 - 1) // TILE, (cy1 - 1) // TILE
        local tx, ty = tx0, cy0 // TILE
        while true do
            if FlatRect then
                local px0, py0 = tx * TILE, ty * TILE
                local ix0, iy0 = max(cx0 - px0, 0), max(cy0 - py0, 0)
                local ix1, iy1 = min(cx1 - px0, TILE), min(cy1 - py0, TILE)
                local r = ((ix0 * 131 + iy0) * 131 + ix1) * 131 + iy1
                h1 = ((r * 48271 + RectColor) % P1 * 48271 + RectUV * 4096 + 7) % P1
                h2 = ((r * 16807 + RectColor + tex_id) % P2 * 16807 + RectUV * 65521 + 11) % P2
            end
            -- unique for |tx|, |ty| < 32768 (content tiles go negative)
            local key = (ty + 32768) * 65536 + tx + 32768
            if key ~= CurKey then
                -- consecutive primitives often alternate between tiles: the tile's state is in slot arrays
                if CurSlot > 0 then
                    SlotCount[CurSlot], SlotHash1[CurSlot], SlotHash2[CurSlot] = CurCount, CurHash1, CurHash2
                end
                CurKey = key
                local slot = KeySlot[key]
                if slot then
                    CurCount, CurHash1, CurHash2 = SlotCount[slot], SlotHash1[slot], SlotHash2[slot]
                else
                    if not TileLists[key] then
                        local ListPool = EditableImages.ListPool
                        local m = #ListPool
                        if m >= 4 then
                            TileLists[key], TileListHash1[key], TileListHash2[key], TileListFlat[key] =
                                ListPool[m - 3], ListPool[m - 2], ListPool[m - 1], ListPool[m]
                            ListPool[m - 3], ListPool[m - 2], ListPool[m - 1], ListPool[m] = nil, nil, nil, nil
                        else
                            TileLists[key] = {}
                            TileListHash1[key] = {}
                            TileListHash2[key] = {}
                            TileListFlat[key] = {}
                        end
                    end
                    TouchedCount = TouchedCount + 1
                    slot = TouchedCount
                    KeySlot[key] = slot
                    Touched[slot] = key
                    TileXs[key], TileYs[key] = tx, ty
                    SlotList[slot], SlotListHash1[slot], SlotListHash2[slot], SlotListFlat[slot] =
                        TileLists[key], TileListHash1[key], TileListHash2[key], TileListFlat[key]
                    CurCount, CurHash1, CurHash2 = 0, 0, 0
                end
                CurSlot = slot
                CurList, CurListHash1, CurListHash2, CurListFlat =
                    SlotList[slot], SlotListHash1[slot], SlotListHash2[slot], SlotListFlat[slot]
            end
            CurCount += 1
            CurList[CurCount], CurListHash1[CurCount], CurListHash2[CurCount], CurListFlat[CurCount] =
                p, h1, h2, FlatSig
            CurHash1 = (CurHash1 * 48271 + h1) % P1
            CurHash2 = (CurHash2 * 16807 + h2 + CurCount) % P2
            if tx < tx1 then
                tx += 1
            elseif ty < ty1 then
                tx, ty = tx0, ty + 1
            else
                break
            end
        end
    end
    if CurSlot > 0 then SlotCount[CurSlot], SlotHash1[CurSlot], SlotHash2[CurSlot] = CurCount, CurHash1, CurHash2 end
    for slot = 1, TouchedCount do
        local key = Touched[slot]
        TileCounts[key], TileHash1[key], TileHash2[key] = SlotCount[slot], SlotHash1[slot], SlotHash2[slot]
        KeySlot[key] = nil
    end
    layer.TouchedCount = TouchedCount
    return TouchedCount
end

local function PlaceLayer(layer, scale, lx0, ly0, z, clip_x0, clip_y0, clip_x1, clip_y1)
    local root = layer.Root
    if root ~= layer.Frame then
        if layer.ClipX0 ~= clip_x0 or layer.ClipY0 ~= clip_y0 or layer.ClipX1 ~= clip_x1 or layer.ClipY1 ~= clip_y1 then
            layer.ClipX0, layer.ClipY0, layer.ClipX1, layer.ClipY1 = clip_x0, clip_y0, clip_x1, clip_y1
            root.Position = UDim2.fromOffset(clip_x0 / scale, clip_y0 / scale)
            root.Size = UDim2.fromOffset((clip_x1 - clip_x0) / scale, (clip_y1 - clip_y0) / scale)
            layer.X = false
        end
        if layer.X ~= lx0 or layer.Y ~= ly0 then
            layer.X, layer.Y = lx0, ly0
            layer.Frame.Position = UDim2.fromOffset((lx0 - clip_x0) / scale, (ly0 - clip_y0) / scale)
        end
    elseif layer.X ~= lx0 or layer.Y ~= ly0 then
        layer.X, layer.Y = lx0, ly0
        root.Position = UDim2.fromOffset(lx0 / scale, ly0 / scale)
    end
    if layer.Z ~= z then
        layer.Z = z
        root.ZIndex = z
    end
    if not layer.Visible then
        layer.Visible = true
        root.Visible = true
    end
end

@native
local function SweepTiles(BackendData, layer, TouchedCount, lx0, ly0, clip_x0, clip_y0, clip_x1, clip_y1)
    local TileCounts, Touched = layer.TileCounts, layer.Touched
    -- content layer: only tiles inside its clip frame are kept, so scrolling holds the visible tiles + a few spares
    local FrameNo, VisibleCount, SpareCap = BackendData.FrameNo, TouchedCount, TouchedCount
    if layer.Root ~= layer.Frame then
        for kk = 1, TouchedCount do
            local key = Touched[kk]
            local x0, y0 = lx0 + layer.TileX[key] * TILE, ly0 + layer.TileY[key] * TILE
            if x0 >= clip_x1 or y0 >= clip_y1 or x0 + TILE <= clip_x0 or y0 + TILE <= clip_y0 then
                TileCounts[key] = 0
                VisibleCount -= 1
            end
        end
        SpareCap = min(VisibleCount, 4)
    end
    -- unused tiles stay for a quick scroll back: at most SpareCap of them, for at most KEEP_FRAMES
    local spare = 0
    for key, tile in pairs(layer.Tiles) do
        if not TileCounts[key] or TileCounts[key] == 0 then
            if tile.Visible then
                tile.Visible = false
                tile.Label.Visible = false
                tile.Hash1 = -1
                tile.DrawnCount = -1
            end
            spare += 1
            if spare > SpareCap or FrameNo - tile.Used > EditableImages.KEEP_FRAMES then
                EditableImages.FreeTile(layer, key, true)
            end
        end
    end
end

-- the new primitive bounds in the tile (clipped to it); swapped with the tile's Drawn* after a redraw
local NewX0, NewY0, NewX1, NewY1 = {}, {}, {}, {}
-- DirtyRects' list diff: how far ahead it looks for the entry that resyncs the old and new list, after how many
-- unpaired entries without a resync it gives up
local DIFF_WINDOW, DIFF_MISSES = 8, 2

-- DirtyRects' rects for old entries [i, oe] / new [i, ne] (prefix and suffix equal) from a greedy diff that pairs equal
-- entries of both lists in order (any order-preserving pairing is exact: a pixel no unpaired primitive touches is
-- covered by the same primitives in the same order), so a row scrolled in or out or an item inserted doesn't redraw
-- everything after it. -1: DIFF_MISSES unpaired entries without a resync (mostly changed: a new font size, animated
-- plots), DirtyRects' positional pass is cheaper there (fewer, larger rects, no lookahead)
@native
local function GreedyRects(tile, ListHash1, ListHash2, lf, i, oe, ne)
    local DrawnHash1, DrawnHash2, DrawnX0, DrawnY0, DrawnX1, DrawnY1, of = tile.DrawnHash1, tile.DrawnHash2,
        tile.DrawnX0, tile.DrawnY0, tile.DrawnX1, tile.DrawnY1, tile.DrawnFlat
    local NX0, NY0, NX1, NY1 = NewX0, NewY0, NewX1, NewY1
    local DX0, DY0, DX1, DY1, AddRect = EditableImages.DX0, EditableImages.DY0, EditableImages.DX1,
        EditableImages.DY1, EditableImages.AddRect
    local DirtyCount = 0
    local oi, ni, misses = i, i, 0
    while oi <= oe and ni <= ne do
        local h1, h2, o1, o2 = ListHash1[ni], ListHash2[ni], DrawnHash1[oi], DrawnHash2[oi]
        if o1 == h1 and o2 == h2 then
            oi += 1
            ni += 1
            continue
        end
        -- the nearest resync: old oi .. oi + skip - 1 gone, or new ni .. ni + skip - 1 inserted
        local skip, gone = 0, false
        for dd = 1, DIFF_WINDOW do
            if oi + dd <= oe and DrawnHash1[oi + dd] == h1 and DrawnHash2[oi + dd] == h2 then
                skip, gone = dd, true
                break
            end
            if ni + dd <= ne and ListHash1[ni + dd] == o1 and ListHash2[ni + dd] == o2 then
                skip = dd
                break
            end
        end
        local ko1, kn1 = oi, ni
        if skip > 0 then
            if gone then ko1, kn1 = oi + skip - 1, ni - 1 else ko1, kn1 = oi - 1, ni + skip - 1 end
            misses = 0
        elseif lf[ni] >= 0 and lf[ni] == of[oi] then
            -- same flat rect, new bounds: only the strips between the old and new edges can differ
            local a, b, c, d = NX0[ni], NY0[ni], NX1[ni], NY1[ni]
            local oa, ob, oc, od = DrawnX0[oi], DrawnY0[oi], DrawnX1[oi], DrawnY1[oi]
            local uy0, uy1 = min(b, ob), max(d, od)
            local ux0, ux1 = min(a, oa), max(c, oc)
            if a ~= oa then DirtyCount = AddRect(DirtyCount, ux0, uy0, max(a, oa), uy1) end
            if c ~= oc then DirtyCount = AddRect(DirtyCount, min(c, oc), uy0, ux1, uy1) end
            if b ~= ob then DirtyCount = AddRect(DirtyCount, ux0, uy0, ux1, max(b, ob)) end
            if d ~= od then DirtyCount = AddRect(DirtyCount, ux0, min(d, od), ux1, uy1) end
            ko1, kn1 = oi - 1, ni - 1
        else
            misses += 1
            if misses >= DIFF_MISSES then return -1 end
        end
        for k = oi, ko1 do
            local a, b, c, d = DrawnX0[k], DrawnY0[k], DrawnX1[k], DrawnY1[k]
            if DirtyCount == 0 or a < DX0[1] or b < DY0[1] or c > DX1[1] or d > DY1[1] then
                DirtyCount = AddRect(DirtyCount, a, b, c, d)
            end
        end
        for k = ni, kn1 do
            local a, b, c, d = NX0[k], NY0[k], NX1[k], NY1[k]
            if DirtyCount == 0 or a < DX0[1] or b < DY0[1] or c > DX1[1] or d > DY1[1] then
                DirtyCount = AddRect(DirtyCount, a, b, c, d)
            end
        end
        if skip == 0 then
            oi += 1
            ni += 1
        elseif gone then
            oi += skip
        else
            ni += skip
        end
    end
    for k = oi, oe do
        local a, b, c, d = DrawnX0[k], DrawnY0[k], DrawnX1[k], DrawnY1[k]
        if DirtyCount == 0 or a < DX0[1] or b < DY0[1] or c > DX1[1] or d > DY1[1] then
            DirtyCount = AddRect(DirtyCount, a, b, c, d)
        end
    end
    for k = ni, ne do
        local a, b, c, d = NX0[k], NY0[k], NX1[k], NY1[k]
        if DirtyCount == 0 or a < DX0[1] or b < DY0[1] or c > DX1[1] or d > DY1[1] then
            DirtyCount = AddRect(DirtyCount, a, b, c, d)
        end
    end
    return DirtyCount
end

@native
local function DirtyRects(tile, layer, key, count, x0, y0, force, exposed, vx0, vy0, vx1, vy1)
    local qx0, qy0, qx1, qy1 = tile.ValidX0, tile.ValidY0, tile.ValidX1, tile.ValidY1
    local list, ListHash1, ListHash2 = layer.TileLists[key], layer.TileListHash1[key], layer.TileListHash2[key]
    local DrawnHash1, DrawnHash2, DrawnX0, DrawnY0, DrawnX1, DrawnY1, DrawnCount =
        tile.DrawnHash1, tile.DrawnHash2, tile.DrawnX0, tile.DrawnY0, tile.DrawnX1, tile.DrawnY1,
        tile.DrawnCount
    local NX0, NY0, NX1, NY1 = NewX0, NewY0, NewX1, NewY1
    local PrimBoundsX0, PrimBoundsY0, PrimBoundsX1, PrimBoundsY1 = PrimBoundsX0, PrimBoundsY0, PrimBoundsX1, PrimBoundsY1
    -- content bounds = the union of the clipped primitive bounds (clipping to the tile commutes with min / max)
    local nx0, ny0, nx1, ny1 = TILE, TILE, 0, 0
    for k = 1, count do
        local p = list[k]
        local a, b = max(PrimBoundsX0[p] - x0, 0), max(PrimBoundsY0[p] - y0, 0)
        local c, d = min(PrimBoundsX1[p] - x0, TILE), min(PrimBoundsY1[p] - y0, TILE)
        NX0[k], NY0[k], NX1[k], NY1[k] = a, b, c, d
        if a < nx0 then nx0 = a end
        if b < ny0 then ny0 = b end
        if c > nx1 then nx1 = c end
        if d > ny1 then ny1 = d end
    end
    local DX0, DY0, DX1, DY1, AddRect = EditableImages.DX0, EditableImages.DY0, EditableImages.DX1,
        EditableImages.DY1, EditableImages.AddRect
    local DirtyCount = 0
    if force or DrawnCount < 0 then
        -- outside the old + new content bounds the valid part is already transparent
        DirtyCount = AddRect(AddRect(0, tile.ContentX0, tile.ContentY0, tile.ContentX1, tile.ContentY1), nx0,
            ny0, nx1, ny1)
    else
        -- partial redraw: a pixel no changed primitive (old or new) touches is covered by the same primitives in the
        -- same order, so only the bounds of the changed ones are redrawn
        local i, lim = 1, min(DrawnCount, count)
        while i <= lim and DrawnHash1[i] == ListHash1[i] and DrawnHash2[i] == ListHash2[i] do i += 1 end
        local j = 0
        while j <= lim - i and DrawnHash1[DrawnCount - j] == ListHash1[count - j]
            and DrawnHash2[DrawnCount - j] == ListHash2[count - j] do
            j += 1
        end
        local of, lf = tile.DrawnFlat, layer.TileListFlat[key]
        -- the lists differ in old [i, DrawnCount - j] / new [i, count - j]
        DirtyCount = GreedyRects(tile, ListHash1, ListHash2, lf, i, DrawnCount - j, count - j)
        if DirtyCount < 0 then
            -- positional (the lists mostly changed)
            DirtyCount = 0
            local paired = DrawnCount - j - i == count - j - i
            for k = i, count - j do
                local a, b, c, d = NX0[k], NY0[k], NX1[k], NY1[k]
                local oa, ob, oc, od = DrawnX0[k], DrawnY0[k], DrawnX1[k], DrawnY1[k]
                if paired and DrawnHash1[k] == ListHash1[k] and DrawnHash2[k] == ListHash2[k] then
                    -- same primitive at the same place in both lists: every pixel it covers is either in a changed
                    -- one's rect or drawn by the same primitives in the same order
                    continue
                elseif paired and lf[k] >= 0 and lf[k] == of[k] then
                    -- same flat rect, new bounds: only the strips between the old and new edges can differ
                    local uy0, uy1 = min(b, ob), max(d, od)
                    local ux0, ux1 = min(a, oa), max(c, oc)
                    if a ~= oa then DirtyCount = AddRect(DirtyCount, ux0, uy0, max(a, oa), uy1) end
                    if c ~= oc then DirtyCount = AddRect(DirtyCount, min(c, oc), uy0, ux1, uy1) end
                    if b ~= ob then DirtyCount = AddRect(DirtyCount, ux0, uy0, ux1, max(b, ob)) end
                    if d ~= od then DirtyCount = AddRect(DirtyCount, ux0, min(d, od), ux1, uy1) end
                else
                    -- (inside the first rect: AddRect would merge it there, changing nothing; skip the call.
                    -- Animated plots change hundreds of primitives per tile)
                    if DirtyCount == 0 or a < DX0[1] or b < DY0[1] or c > DX1[1] or d > DY1[1] then
                        DirtyCount = AddRect(DirtyCount, a, b, c, d)
                    end
                    if k <= DrawnCount - j
                        and (DirtyCount == 0 or oa < DX0[1] or ob < DY0[1] or oc > DX1[1] or od > DY1[1]) then
                        DirtyCount = AddRect(DirtyCount, oa, ob, oc, od)
                    end
                end
            end
            for k = count - j + 1, DrawnCount - j do
                local a, b, c, d = DrawnX0[k], DrawnY0[k], DrawnX1[k], DrawnY1[k]
                if DirtyCount == 0 or a < DX0[1] or b < DY0[1] or c > DX1[1] or d > DY1[1] then
                    DirtyCount = AddRect(DirtyCount, a, b, c, d)
                end
            end
        end
    end
    -- clip D to V, then add the exposed part that isn't valid. cut: part of D inside the valid rect was clipped away
    local cut, RectCount = false, 0
    for r = 1, DirtyCount do
        local a, b, c, d = DX0[r], DY0[r], DX1[r], DY1[r]
        local ix0, iy0, ix1, iy1 = max(a, qx0), max(b, qy0), min(c, qx1), min(d, qy1)
        if ix0 < ix1 and iy0 < iy1 and (ix0 < vx0 or iy0 < vy0 or ix1 > vx1 or iy1 > vy1) then cut = true end
        a, b, c, d = max(a, vx0), max(b, vy0), min(c, vx1), min(d, vy1)
        if a < c and b < d then
            RectCount += 1
            DX0[RectCount], DY0[RectCount], DX1[RectCount], DY1[RectCount] = a, b, c, d
        end
    end
    if exposed then
        local ex0, ey0, ex1, ey1 = vx0, vy0, vx1, vy1
        if qx0 <= vx0 and qx1 >= vx1 then
            if qy0 <= vy0 and qy1 > vy0 then ey0 = qy1 elseif qy1 >= vy1 and qy0 < vy1 then ey1 = qy0 end
        elseif qy0 <= vy0 and qy1 >= vy1 then
            if qx0 <= vx0 and qx1 > vx0 then ex0 = qx1 elseif qx1 >= vx1 and qx0 < vx1 then ex1 = qx0 end
        end
        RectCount = AddRect(RectCount, ex0, ey0, ex1, ey1)
    end
    if cut then
        qx0, qy0, qx1, qy1 = vx0, vy0, vx1, vy1
    elseif exposed then
        if (qx0 == vx0 and qx1 == vx1 and qy0 <= vy1 and vy0 <= qy1)
            or (qy0 == vy0 and qy1 == vy1 and qx0 <= vx1 and vx0 <= qx1)
            or (qx0 >= vx0 and qy0 >= vy0 and qx1 <= vx1 and qy1 <= vy1) then
            qx0, qy0, qx1, qy1 = min(qx0, vx0), min(qy0, vy0), max(qx1, vx1), max(qy1, vy1)
        else
            qx0, qy0, qx1, qy1 = vx0, vy0, vx1, vy1
        end
    end
    tile.ValidX0, tile.ValidY0, tile.ValidX1, tile.ValidY1 = qx0, qy0, qx1, qy1
    tile.ContentX0, tile.ContentY0, tile.ContentX1, tile.ContentY1 = nx0, ny0, nx1, ny1
    -- the drawn state is now the tile's list: swap tables instead of copying (HashTiles rewrites the layer's lists)
    tile.DrawnHash1, layer.TileListHash1[key] = ListHash1, DrawnHash1
    tile.DrawnHash2, layer.TileListHash2[key] = ListHash2, DrawnHash2
    tile.DrawnFlat, layer.TileListFlat[key] = layer.TileListFlat[key], tile.DrawnFlat
    tile.DrawnX0, tile.DrawnY0, tile.DrawnX1, tile.DrawnY1 = NX0, NY0, NX1, NY1
    NewX0, NewY0, NewX1, NewY1 = DrawnX0, DrawnY0, DrawnX1, DrawnY1
    tile.DrawnCount = count
    return RectCount
end

@native
local function RasterRect(list, count, x0, y0, tox, toy, rx0, ry0, rx1, ry1)
    ClearRect(rx0, ry0, rx1, ry1)
    for k = 1, count do
        local p = list[k]
        -- (bounds first: most of a tile's primitives miss a small rect)
        if PrimBoundsX0[p] - x0 >= rx1 or PrimBoundsY0[p] - y0 >= ry1 or PrimBoundsX1[p] - x0 <= rx0
            or PrimBoundsY1[p] - y0 <= ry0 then
            continue
        end
        local cmd = PrimCmd[p]
        local cx0, cy0 = max(CmdClipX0[cmd] - x0, rx0), max(CmdClipY0[cmd] - y0, ry0)
        local cx1, cy1 = min(CmdClipX1[cmd] - x0, rx1), min(CmdClipY1[cmd] - y0, ry1)
        if cx0 >= cx1 or cy0 >= cy1 then continue end
        local kind, gk = 0, PrimGradient[p]
        if PrimD[p] then kind = gk and gk + 1 or 1 end
        DrawPrim(kind, CmdTexture[cmd], CmdVtxBuffer[cmd], PrimA[p], PrimB[p], PrimC[p], PrimD[p] or 0, tox, toy, cx0, cy0,
            cx1, cy1)
    end
end

-- WritePixelsBuffer needs the exact size: a rect is rasterized straight into an upload buffer of its size (reused by
-- size; the whole tile: TileBuffer). One small buffer stays in cache, unlike a 64 KB buffer per tile.
local TileBuffer = buffer.create(TILE * TILE * 4)
local SubBuffers, SubBufferCount = {}, 0
local function RectBuffer(rw, rh)
    if rw == TILE and rh == TILE then return TileBuffer end
    local sk = rw * 1024 + rh
    local sub = SubBuffers[sk]
    if not sub then
        if SubBufferCount >= 256 then
            table.clear(SubBuffers)
            SubBufferCount = 0
        end
        sub = buffer.create(rw * rh * 4)
        SubBuffers[sk] = sub
        SubBufferCount += 1
    end
    return sub
end

local function RedrawTile(BackendData, layer, key, tile, count, x0, y0, ox, oy, force, exposed, vx0, vy0, vx1, vy1)
    BackendData.RedrawStarted = true
    BackendData.FrameTiles += 1
    tile.Deferred = 0
    tile.Hash1, tile.Hash2 = layer.TileHash1[key], layer.TileHash2[key]
    local RectCount = DirtyRects(tile, layer, key, count, x0, y0, force, exposed, vx0, vy0, vx1, vy1)
    local list = layer.TileLists[key]
    local tox, toy = ox + x0, oy + y0
    local Timing = EditableImages.StageTiming and EditableImages.StageFrame
    if Timing and RectCount > 0 then Timing.TilesRasterized += 1 end
    -- parallel: rasterized + uploaded later in the frame (pixels outside the rects are never read)
    if Parallel.Active and RectCount > 0 then
        Parallel.Tile(tile.Image, list, count, x0, y0, tox, toy, RectCount)
        return
    end
    local DX0, DY0, DX1, DY1 = EditableImages.DX0, EditableImages.DY0, EditableImages.DX1, EditableImages.DY1
    for r = 1, RectCount do
        local rx0, ry0, rx1, ry1 = DX0[r], DY0[r], DX1[r], DY1[r]
        local rw, rh = rx1 - rx0, ry1 - ry0
        local buf = RectBuffer(rw, rh)
        SetTarget(buf, rw, rx0, ry0)
        RasterRect(list, count, x0, y0, tox, toy, rx0, ry0, rx1, ry1)
        PB("ImGui upload")
        local t_up = Timing and os.clock()
        if Timing then
            Timing.PixelsRasterized += rw * rh
            Timing.Uploads += 1
        end
        if buf == TileBuffer then
            tile.Image:WritePixelsBuffer(Vector2.zero, TILE_SIZE, buf)
        else
            tile.Image:WritePixelsBuffer(Vector2.new(rx0, ry0), Vector2.new(rw, rh), buf)
        end
        if Timing then Timing.Upload += os.clock() - t_up end
        PE()
    end
end

@native
local function DrawLayer(BackendData, layer, plist, np, lx0, ly0, ox, oy, force, z, clip_x0, clip_y0, clip_x1, clip_y1)
    PB("ImGui tile hash")
    if EditableImages.StageTiming then EditableImages.BeginStage() end
    local TouchedCount = HashTiles(layer, plist, np, lx0, ly0, ox, oy)
    if EditableImages.StageTiming then EditableImages.EndStage("Hash") end
    PE()

    PlaceLayer(layer, BackendData.Scale, lx0, ly0, z, clip_x0, clip_y0, clip_x1, clip_y1)

    PB("ImGui raster+upload")
    if EditableImages.StageTiming then EditableImages.BeginStage() end
    SweepTiles(BackendData, layer, TouchedCount, lx0, ly0, clip_x0, clip_y0, clip_x1, clip_y1)
    local TileCounts, Touched, TileHash1, TileHash2 = layer.TileCounts, layer.Touched, layer.TileHash1, layer.TileHash2
    local content = layer.Root ~= layer.Frame
    local FrameNo, deferred = BackendData.FrameNo, false
    for kk = 1, TouchedCount do
        local key = Touched[kk]
        local count = TileCounts[key]
        if not count or count == 0 then continue end -- outside the content clip, or list freed
        local tx, ty = layer.TileX[key], layer.TileY[key]
        local tile = GetTile(BackendData, layer, key, tx, ty)
        if not tile then continue end
        tile.Used = FrameNo
        local x0, y0 = lx0 + tx * TILE, ly0 + ty * TILE
        -- redraws are clipped to the visible part; a part scrolled into view that isn't valid is redrawn then
        local vx0, vy0, vx1, vy1 = 0, 0, TILE, TILE
        if content then
            vx0, vy0, vx1, vy1 = max(clip_x0 - x0, 0), max(clip_y0 - y0, 0), min(clip_x1 - x0, TILE), min(clip_y1 - y0,
                TILE)
        end
        local exposed = vx0 < tile.ValidX0 or vy0 < tile.ValidY0 or vx1 > tile.ValidX1 or vy1 > tile.ValidY1
        local dirty = force or exposed or tile.Hash1 ~= TileHash1[key] or tile.Hash2 ~= TileHash2[key]
        if dirty and BackendData.RedrawStarted and (tile.Deferred or 0) < MAX_DEFER_FRAMES
            and ((BackendData.RedrawBudget > 0 and os.clock() - BackendData.FrameStartTime >= BackendData.RedrawBudget)
                or (BackendData.TileLimit and BackendData.FrameTiles >= BackendData.TileLimit)) then
            -- over budget (TileLimit: t_pixels hook): keep the old pixels (the stored hashes describe them)
            tile.Deferred = (tile.Deferred or 0) + 1
            if force then
                tile.Hash1 = -1
                tile.DrawnCount = -1
            end
            deferred = true
            dirty = false
        end
        if dirty then RedrawTile(BackendData, layer, key, tile, count, x0, y0, ox, oy, force, exposed, vx0, vy0, vx1, vy1) end
        -- a deferred tile that was hidden holds old pixels: stays hidden until drawn
        if not tile.Visible and (tile.Deferred or 0) == 0 then
            tile.Visible = true
            tile.Label.Visible = true
        end
    end
    if EditableImages.StageTiming then
        EditableImages.EndStage("Raster")
    end
    PE()
    return deferred
end

local function UpdateTextures(draw_data)
    PB("ImGui textures")
    if draw_data.Textures ~= nil then
        for _, tex in draw_data.Textures:iter() do
            if tex.Status ~= ImTextureStatus.OK then
                -- WantUpdates only writes regions no tile has sampled yet: no redraw needed
                UpdateTexture(tex)
            end
        end
    end
    PE()
end

local function RenderRateAllows(BackendData, draw_data)
    local rate = BackendData.RenderRate
    if BackendData.BusyRenderRate > 0 then
        local g = ImGui.GetCurrentContext()
        local busy = g.WheelingWindow ~= nil or g.MovingWindow ~= nil -- (io.MouseWheel is already cleared by EndFrame)
        if not busy and g.ActiveId ~= 0 then
            local w = g.ActiveIdWindow
            local cur = g.MouseCursor
            busy = (cur >= ImGuiMouseCursor.ResizeAll and cur <= ImGuiMouseCursor.ResizeNWSE)
                or (w ~= nil and (g.ActiveId == ImGui.GetWindowScrollbarID(w, ImGuiAxis.X)
                    or g.ActiveId == ImGui.GetWindowScrollbarID(w, ImGuiAxis.Y)))
        end
        if busy and (rate <= 0 or BackendData.BusyRenderRate < rate) then rate = BackendData.BusyRenderRate end
    end
    if rate > 0 then
        local now = os.clock()
        -- skipped: kept pending, Heartbeat draws it if no new frame comes
        if now + 0.002 < BackendData.NextRender then
            BackendData.Pending = draw_data
            return false
        end
        BackendData.NextRender = math.max(BackendData.NextRender + 1 / rate, now)
    end
    return true
end

local function ReuseDrawList(BackendData, set, draw_list, same, sdx, sdy, z, ox, oy, ScreenWidth, ScreenHeight)
    for kind = 1, 3 do
        local layer = set[kind]
        if layer and layer.Visible then
            if same == 2 then ShiftLayer(layer, sdx, sdy, BackendData.Scale) end
            z += 1
            if layer.Z ~= z then
                layer.Z = z
                layer.Root.ZIndex = z
            end
        end
    end
    if same == 2 then ShiftSnapshot(set, draw_list, sdx, sdy) end
    set.LastUsed = BackendData.FrameNo
    return PlaceOverlays(BackendData, draw_list, z, ox, oy)
end

-- Collects primitives into Prim* (from n + 1), LayerPrims* and commands into Cmd*; returns n, LimitFree and the extents
@native
local function CollectPrims(BackendData, draw_list, n, ox, oy, LimitX0, LimitY0, LimitX1, LimitY1)
    local vbuf, idx = draw_list.VtxBuffer.Buf, draw_list.IdxBuffer.Data
    local ccx0, ccy0, ccx1, ccy1 = draw_list._ContentClipX0, draw_list._ContentClipY0, draw_list._ContentClipX1,
        draw_list._ContentClipY1
    local SeenContent = false
    local ex0, ey0, ex1, ey1 = math.huge, math.huge, -math.huge, -math.huge
    local LimitFree = true
    if ccx0 then
        local a, b, c, d = floor(ccx0 - ox), floor(ccy0 - oy), floor(ccx1 - ox), floor(ccy1 - oy)
        if a < LimitX0 or b < LimitY0 or c > LimitX1 or d > LimitY1 then LimitFree = false end
        ex0, ey0, ex1, ey1 = min(ex0, a), min(ey0, b), max(ex1, c), max(ey1, d)
    end
    -- upvalues as locals: cheaper in the hot loop
    local PrimA, PrimB, PrimC, PrimD, PrimGradient, PrimFlat, PrimCmd = PrimA, PrimB, PrimC, PrimD, PrimGradient,
        PrimFlat, PrimCmd
    local PrimBoundsX0, PrimBoundsY0, PrimBoundsX1, PrimBoundsY1 = PrimBoundsX0, PrimBoundsY0, PrimBoundsX1, PrimBoundsY1
    local LayerPrims1, LayerPrims2, LayerPrims3 = LayerPrims1, LayerPrims2, LayerPrims3
    local ci = 0
    local c1, c2, c3 = 0, 0, 0
    local k1x, k1y, k3x, k3y = math.huge, math.huge, math.huge, math.huge
    for _, pcmd in draw_list.CmdBuffer:iter() do
        ci += 1
        CmdUnclipped[ci], CmdKind[ci] = false, 0
        if pcmd.UserCallback ~= nil then
            pcmd.UserCallback(draw_list, pcmd)
        elseif pcmd.ElemCount > 0 then
            local clip = pcmd.ClipRect
            local rcx0, rcy0, rcx1, rcy1 = floor(clip.x - ox), floor(clip.y - oy), floor(clip.z - ox),
                floor(clip.w - oy)
            if rcx0 < LimitX0 or rcy0 < LimitY0 or rcx1 > LimitX1 or rcy1 > LimitY1 then LimitFree = false end
            if rcx0 < ex0 then ex0 = rcx0 end
            if rcy0 < ey0 then ey0 = rcy0 end
            if rcx1 > ex1 then ex1 = rcx1 end
            if rcy1 > ey1 then ey1 = rcy1 end
            local cx0, cy0 = max(rcx0, LimitX0), max(rcy0, LimitY0)
            local cx1, cy1 = min(rcx1, LimitX1), min(rcy1, LimitY1)
            local kind = 1
            if ccx0 and clip.x >= ccx0 and clip.y >= ccy0 and clip.z <= ccx1 and clip.w <= ccy1 then
                kind = 2
                SeenContent = true
                if clip.x == ccx0 and clip.y == ccy0 and clip.z == ccx1 and clip.w == ccy1 then
                    -- clipped by the layer's clip frame instead: partly visible rows stay hash-stable while scrolling
                    cx0, cy0, cx1, cy1 = LimitX0, LimitY0, LimitX1, LimitY1
                end
            elseif SeenContent then
                kind = 3
            end
            CmdKind[ci] = kind
            local CmdFree, cex0, cey0, cex1, cey1 =
                cx1 > cx0 and cy1 > cy0, math.huge, math.huge, -math.huge, -math.huge
            if cx1 > cx0 and cy1 > cy0 then
                local tex_id = pcmd:GetTexID()
                local t = BackendData.Textures[tex_id]
                local cmd = CmdCount + 1
                CmdCount = cmd
                CmdTexture[cmd], CmdTexId[cmd], CmdVtxBuffer[cmd] = t, tex_id, vbuf
                CmdClipX0[cmd], CmdClipY0[cmd], CmdClipX1[cmd], CmdClipY1[cmd] = cx0, cy0, cx1, cy1
                local vo = pcmd.VtxOffset
                local i, last = pcmd.IdxOffset + 1, pcmd.IdxOffset + pcmd.ElemCount
                while i <= last do
                    local ia, ic = idx[i], idx[i + 2]
                    local va, vb, vc = (vo + ia - 1) * VTX_STRIDE, (vo + idx[i + 1] - 1) * VTX_STRIDE,
                        (vo + ic - 1) * VTX_STRIDE
                    local vd = false
                    local gk = false
                    local pax, pay = readf64(vbuf, va), readf64(vbuf, va + 8)
                    local pbx, pby = readf64(vbuf, vb), readf64(vbuf, vb + 8)
                    local pcx, pcy = readf64(vbuf, vc), readf64(vbuf, vc + 8)
                    local bx0, by0, bx1, by1
                    local flat = false
                    if i + 5 <= last and idx[i + 3] == ia and idx[i + 4] == ic then
                        local d = (vo + idx[i + 5] - 1) * VTX_STRIDE
                        local pdx, pdy = readf64(vbuf, d), readf64(vbuf, d + 8)
                        local col = readu32(vbuf, va + 32)
                        local colb, colc, cold = readu32(vbuf, vb + 32), readu32(vbuf, vc + 32), readu32(vbuf, d + 32)
                        local tax, tay = readf64(vbuf, va + 16), readf64(vbuf, va + 24)
                        local tcx, tcy = readf64(vbuf, vc + 16), readf64(vbuf, vc + 24)
                        -- axis aligned rect, then textured line quad: never both (a rect with one colour has u b = u c,
                        -- a line quad u a = u b ~= u c), so the order doesn't change the result
                        if pay == pby and pbx == pcx and pcy == pdy and pdx == pax and pax < pbx and pay < pdy then
                            local tbx, tby = readf64(vbuf, vb + 16), readf64(vbuf, vb + 24)
                            local tdx, tdy = readf64(vbuf, d + 16), readf64(vbuf, d + 24)
                            if colb == col and colc == col and cold == col then
                                if tbx == tcx and tby == tay and tdx == tax and tdy == tcy then
                                    vd, flat = d, not t or (tax == tcx and tay == tcy)
                                end
                            elseif tax == tbx and tax == tcx and tax == tdx and tay == tby and tay == tcy
                                and tay == tdy then
                                if colb == col and cold == colc then
                                    vd = d
                                    gk = 1
                                elseif cold == col and colb == colc then
                                    vd = d
                                    gk = 2
                                end
                            end
                            if vd then
                                bx0, by0 = ceil(pax - ox - 0.5), ceil(pay - oy - 0.5)
                                bx1, by1 = ceil(pcx - ox - 0.5), ceil(pcy - oy - 0.5)
                            end
                        end
                        -- textured line quad (ImPlot PrimLine): uv a = b, c = d, u a ~= u c
                        if not vd and t and colb == col and colc == col and cold == col and tax ~= tcx
                            and readf64(vbuf, vb + 16) == tax and readf64(vbuf, vb + 24) == tay
                            and readf64(vbuf, d + 16) == tcx and readf64(vbuf, d + 24) == tcy then
                            vd, gk = d, 3
                            bx0, by0 = floor(min(pax, pbx, pcx, pdx) - ox), floor(min(pay, pby, pcy, pdy) - oy)
                            bx1 = ceil(max(pax, pbx, pcx, pdx) - ox) + 1
                            by1 = ceil(max(pay, pby, pcy, pdy) - oy) + 1
                        end
                    elseif i + 5 <= last and idx[i + 3] == ia and idx[i + 4] == idx[i + 1] then
                        -- flat triangle pair a b c + a b d (ImPlot PrimRectFill: heatmap cells, bars): one colour, one
                        -- uv (or no texture), any shape; the bounds are the two triangles' together
                        local d = (vo + idx[i + 5] - 1) * VTX_STRIDE
                        local col = readu32(vbuf, va + 32)
                        if readu32(vbuf, vb + 32) == col and readu32(vbuf, vc + 32) == col and readu32(vbuf, d + 32) == col then
                            local tax, tay = readf64(vbuf, va + 16), readf64(vbuf, va + 24)
                            if not t or (readf64(vbuf, vb + 16) == tax and readf64(vbuf, vb + 24) == tay
                                and readf64(vbuf, vc + 16) == tax and readf64(vbuf, vc + 24) == tay
                                and readf64(vbuf, d + 16) == tax and readf64(vbuf, d + 24) == tay) then
                                local pdx, pdy = readf64(vbuf, d), readf64(vbuf, d + 8)
                                vd, gk = d, 4
                                bx0, by0 = floor(min(pax, pbx, pcx, pdx) - ox), floor(min(pay, pby, pcy, pdy) - oy)
                                bx1 = ceil(max(pax, pbx, pcx, pdx) - ox) + 1
                                by1 = ceil(max(pay, pby, pcy, pdy) - oy) + 1
                            end
                        end
                    end
                    if vd then
                        i = i + 6
                    else
                        bx0, by0 = floor(min(pax, pbx, pcx) - ox), floor(min(pay, pby, pcy) - oy)
                        bx1, by1 = ceil(max(pax, pbx, pcx) - ox) + 1, ceil(max(pay, pby, pcy) - oy) + 1
                        i = i + 3
                    end
                    if bx0 < cex0 then cex0 = bx0 end
                    if by0 < cey0 then cey0 = by0 end
                    if bx1 > cex1 then cex1 = bx1 end
                    if by1 > cey1 then cey1 = by1 end
                    if bx0 < cx0 then bx0 = cx0 end
                    if by0 < cy0 then by0 = cy0 end
                    if bx1 > cx1 then bx1 = cx1 end
                    if by1 > cy1 then by1 = cy1 end
                    if bx0 < bx1 and by0 < by1 then
                        n = n + 1
                        PrimA[n], PrimB[n], PrimC[n], PrimD[n], PrimGradient[n], PrimCmd[n] = va, vb, vc, vd, gk, cmd
                        PrimBoundsX0[n], PrimBoundsY0[n], PrimBoundsX1[n], PrimBoundsY1[n] = bx0, by0, bx1, by1
                        PrimFlat[n] = flat
                        if kind == 2 then
                            c2 += 1
                            LayerPrims2[c2] = n
                        elseif kind == 1 then
                            c1 += 1
                            LayerPrims1[c1] = n
                            if bx0 < k1x then k1x = bx0 end
                            if by0 < k1y then k1y = by0 end
                        else
                            c3 += 1
                            LayerPrims3[c3] = n
                            if bx0 < k3x then k3x = bx0 end
                            if by0 < k3y then k3y = by0 end
                        end
                    end
                end
                -- per command, from the bounds of all its primitives: one clipped, one past the limits, the extents
                if cex0 < cx0 or cey0 < cy0 or cex1 > cx1 or cey1 > cy1 then CmdFree = false end
                if cex0 < LimitX0 or cey0 < LimitY0 or cex1 > LimitX1 or cey1 > LimitY1 then LimitFree = false end
                if cex0 < ex0 then ex0 = cex0 end
                if cey0 < ey0 then ey0 = cey0 end
                if cex1 > ex1 then ex1 = cex1 end
                if cey1 > ey1 then ey1 = cey1 end
            end
            if cex0 > cex1 then cex0, cey0, cex1, cey1 = 0, 0, 0, 0 end
            CmdUnclipped[ci] = CmdFree
            CmdBoundsX0[ci], CmdBoundsY0[ci], CmdBoundsX1[ci], CmdBoundsY1[ci] = cex0, cey0, cex1, cey1
        end
    end
    Kind1Count, Kind2Count, Kind3Count, Kind1X, Kind1Y, Kind3X, Kind3Y = c1, c2, c3, k1x, k1y, k3x, k3y
    return n, LimitFree, ex0, ey0, ex1, ey1
end

local function DrawLists(BackendData, draw_list, z, ox, oy, force, LimitX0, LimitY0, LimitX1, LimitY1)
    local set = BackendData.Layers[draw_list]
    local ListDeferred = false
    if Kind1Count > 0 then
        z += 1
        if DrawLayer(BackendData, GetLayer(BackendData, draw_list, 1), LayerPrims1, Kind1Count, Kind1X, Kind1Y, ox,
            oy, force, z) then
            ListDeferred = true
        end
    elseif set and set[1] then HideLayer(set[1]) end
    if Kind2Count > 0 then
        local ccx0 = draw_list._ContentClipX0
        local ContentX0, ContentY0, ContentX1, ContentY1
        if ccx0 then
            ContentX0, ContentY0 = max(floor(ccx0 - ox), LimitX0), max(floor(draw_list._ContentClipY0 - oy), LimitY0)
            ContentX1, ContentY1 = min(floor(draw_list._ContentClipX1 - ox), LimitX1),
                min(floor(draw_list._ContentClipY1 - oy), LimitY1)
        end
        z += 1
        if DrawLayer(BackendData, GetLayer(BackendData, draw_list, 2), LayerPrims2, Kind2Count,
            floor(draw_list._ScrollOriginX - ox), floor(draw_list._ScrollOriginY - oy), ox, oy, force, z,
            ContentX0, ContentY0, ContentX1, ContentY1) then ListDeferred = true end
    elseif set and set[2] then HideLayer(set[2]) end
    if Kind3Count > 0 then
        z += 1
        if DrawLayer(BackendData, GetLayer(BackendData, draw_list, 3), LayerPrims3, Kind3Count, Kind3X, Kind3Y, ox,
            oy, force, z) then
            ListDeferred = true
        end
    elseif set and set[3] then HideLayer(set[3]) end
    return z, ListDeferred
end

-- The layer origin of each kind (DrawLists' DrawLayer arguments), from the last CollectPrims
local function LayerOrigin(draw_list, kind, ox, oy)
    if kind == 1 then return Kind1X, Kind1Y end
    if kind == 3 then return Kind3X, Kind3Y end
    return floor(draw_list._ScrollOriginX - ox), floor(draw_list._ScrollOriginY - oy)
end

local PatchLayers, PatchKeys, PatchPrim, PatchH1, PatchH2, PatchSig = {}, {}, {}, {}, {}, {}

-- CompareDrawList 3: moved by whole pixels, but a few vertices drifted off the exact shift (same bounds). CollectPrims
-- ran and gave the primitive sequence the tile lists were built from: the lists stay (indices moved to this frame's)
-- and every tile keeps its pixels, except those with a primitive using a drifted vertex: those entries' hashes change
-- (DriftMark), so the tile redraws just them. Changes nothing when it returns false (the caller takes the full path).
-- recolor (CompareDrawList 4: not moved, a few vertices' uv / colour changed): the same, but those primitives get
-- their real hashes (PrimHash, flat rects too), so the tiles end up exactly as HashTiles + DrawLayer would leave them.
-- Their kind must be the same (so the same bounds and tiles; the other primitives' entries are equal by construction).
@native
local function PatchDrawList(BackendData, set, draw_list, n0, n, dx, dy, ox, oy, LimitX0, LimitY0, LimitX1, LimitY1,
    recolor)
    table.clear(PatchPrim)
    local SigA, SigD, SigG = set.PrimSigA, set.PrimSigD, set.PrimSigG
    if not SigA or set.PrimN ~= n - n0 then return false end
    for m = 1, n - n0 do
        local p = n0 + m
        if PrimA[p] ~= SigA[m] or PrimD[p] ~= SigD[m] then return false end
    end
    -- the listed vertices' byte offset range
    local Drift, lo, hi = Layers.Drift, math.huge, -1
    for k = 1, Layers.DriftCount do
        local v = Drift[k]
        if v < lo then lo = v end
        if v > hi then hi = v end
    end
    local np = 0
    for kind = 1, 3 do
        local layer = set[kind]
        local count = kind == 1 and Kind1Count or kind == 2 and Kind2Count or Kind3Count
        if count == 0 then
            if layer and layer.Visible then return false end
            continue
        end
        if not (layer and layer.Visible and layer.X) then return false end
        local lx0, ly0 = LayerOrigin(draw_list, kind, ox, oy)
        if lx0 ~= layer.X + dx or ly0 ~= layer.Y + dy then return false end
        if layer.Root ~= layer.Frame then
            local ccx0 = draw_list._ContentClipX0
            if not ccx0 or not layer.ClipX0 then return false end
            if max(floor(ccx0 - ox), LimitX0) ~= layer.ClipX0 + dx
                or max(floor(draw_list._ContentClipY0 - oy), LimitY0) ~= layer.ClipY0 + dy
                or min(floor(draw_list._ContentClipX1 - ox), LimitX1) ~= layer.ClipX1 + dx
                or min(floor(draw_list._ContentClipY1 - oy), LimitY1) ~= layer.ClipY1 + dy then
                return false
            end
        end
        -- the tiles of the primitives with a drifted vertex (flat rects: drawn from their bounds only, unchanged)
        local plist = kind == 1 and LayerPrims1 or kind == 2 and LayerPrims2 or LayerPrims3
        local TileCounts, Tiles = layer.TileCounts, layer.Tiles
        for m = 1, count do
            local p = plist[m]
            local va, vb, vc, vd = PrimA[p], PrimB[p], PrimC[p], PrimD[p]
            -- (most primitives use no vertex in the listed ones' range: two compares per vertex, no lookups)
            if (va < lo or va > hi) and (vb < lo or vb > hi) and (vc < lo or vc > hi)
                and (not vd or vd < lo or vd > hi) then
                continue
            end
            if (PrimFlat[p] and not recolor)
                or not (DriftSet[va // VTX_STRIDE + 1] or DriftSet[vb // VTX_STRIDE + 1]
                    or DriftSet[vc // VTX_STRIDE + 1] or (vd and DriftSet[vd // VTX_STRIDE + 1])) then
                continue
            end
            if recolor then
                if PrimGradient[p] ~= SigG[p - n0] then return false end
                PatchH1[p], PatchH2[p], PatchSig[p] = PrimHash(p, lx0, ly0, ox, oy)
            end
            PatchPrim[p] = true
            local cx0, cy0, cx1, cy1 = PrimBoundsX0[p] - lx0, PrimBoundsY0[p] - ly0, PrimBoundsX1[p] - lx0,
                PrimBoundsY1[p] - ly0
            for ty = cy0 // TILE, (cy1 - 1) // TILE do
                for tx = cx0 // TILE, (cx1 - 1) // TILE do
                    local key = (ty + 32768) * 65536 + tx + 32768
                    local c, tile = TileCounts[key], Tiles[key]
                    if not c or c == 0 or not tile then continue end -- not drawn (outside the content clip)
                    if tile.DrawnCount ~= c or tile.Hash1 ~= layer.TileHash1[key] or tile.Hash2 ~= layer.TileHash2[key]
                        or (tile.Deferred or 0) > 0 then
                        return false
                    end
                    np += 1
                    PatchLayers[np], PatchKeys[np] = kind, key
                end
            end
        end
    end

    -- the lists: this frame's primitive indices
    local delta = n0 - set.PrimBase
    set.PrimBase = n0
    for kind = 1, 3 do
        local layer = set[kind]
        if delta == 0 or not (layer and layer.Visible) then continue end
        local TileCounts, TileLists, Touched = layer.TileCounts, layer.TileLists, layer.Touched
        for kk = 1, layer.TouchedCount do
            local key = Touched[kk]
            local c = TileCounts[key]
            if c and c > 0 then
                local list = TileLists[key]
                for k = 1, c do list[k] += delta end
            end
        end
    end

    -- the patched tiles: their drawn entries, the drifted primitives' hashes changed, redrawn
    local FrameNo = BackendData.FrameNo
    for i = 1, np do
        local kind, key = PatchLayers[i], PatchKeys[i]
        local layer = set[kind]
        local tile = layer.Tiles[key]
        if tile.Used == FrameNo then continue end -- (done: a tile of several drifted primitives)
        tile.Used = FrameNo
        local count = layer.TileCounts[key]
        local list, LH1, LH2 = layer.TileLists[key], layer.TileListHash1[key], layer.TileListHash2[key]
        table.move(tile.DrawnHash1, 1, count, 1, LH1)
        table.move(tile.DrawnHash2, 1, count, 1, LH2)
        table.move(tile.DrawnFlat, 1, count, 1, layer.TileListFlat[key])
        local lx0, ly0 = LayerOrigin(draw_list, kind, ox, oy)
        local LF = layer.TileListFlat[key]
        local h1, h2 = 0, 0
        for k = 1, count do
            local p = list[k]
            if not PatchPrim[p] then
                -- (unchanged entry)
            elseif not recolor then
                LH1[k], LH2[k] = (LH1[k] + DriftMark1) % P1, (LH2[k] + DriftMark2) % P2
            else
                local sig = PatchSig[p]
                if sig >= 0 then
                    LH1[k], LH2[k] = FlatTileHash(p, lx0, ly0, layer.TileX[key], layer.TileY[key])
                else
                    LH1[k], LH2[k] = PatchH1[p], PatchH2[p]
                end
                LF[k] = sig
            end
            h1 = (h1 * 48271 + LH1[k]) % P1
            h2 = (h2 * 16807 + LH2[k] + k) % P2
        end
        layer.TileHash1[key], layer.TileHash2[key] = h1, h2
        local x0, y0 = lx0 + layer.TileX[key] * TILE, ly0 + layer.TileY[key] * TILE
        local vx0, vy0, vx1, vy1 = 0, 0, TILE, TILE
        if layer.Root ~= layer.Frame then
            vx0, vy0 = max(layer.ClipX0 + dx - x0, 0), max(layer.ClipY0 + dy - y0, 0)
            vx1, vy1 = min(layer.ClipX1 + dx - x0, TILE), min(layer.ClipY1 + dy - y0, TILE)
        end
        local exposed = vx0 < tile.ValidX0 or vy0 < tile.ValidY0 or vx1 > tile.ValidX1 or vy1 > tile.ValidY1
        RedrawTile(BackendData, layer, key, tile, count, x0, y0, ox, oy, false, exposed, vx0, vy0, vx1, vy1)
    end
    table.clear(PatchPrim)
    return true
end

-- Overlay frames are only hidden (the user owns them); unused layers hidden, long unused ones freed
local function SweepLayers(BackendData, FrameNo)
    for frame, shown in pairs(BackendData.OverlayShown) do
        if shown ~= FrameNo then
            frame.Visible = false
            BackendData.OverlayShown[frame] = nil
        end
    end
    table.clear(BackendData.Overlays)

    for draw_list, set in pairs(BackendData.Layers) do
        if set.LastUsed ~= FrameNo then
            set.SnapOK = false
            for kind = 1, 3 do if set[kind] then HideLayer(set[kind]) end end
            if FrameNo - set.LastUsed > LAYER_KEEP_FRAMES then
                DestroyLayerSet(set)
                BackendData.Layers[draw_list] = nil
            end
        end
    end
end

function M.RenderDrawData(draw_data)
    local BackendData = GetBackendData()
    PB("ImGui RenderDrawData")
    BackendData.FrameStartTime = os.clock()
    if EditableImages.StageTiming then
        EditableImages.StageFrame = { Compare = 0, Collect = 0, Hash = 0, Raster = 0, Upload = 0, Textures = 0, Flush = 0, Other = 0, Total = 0,
        TilesRasterized = 0, PixelsRasterized = 0, Uploads = 0, TilesCreated = 0, TilesFreed = 0 } end
    BackendData.FrameTiles = 0
    -- the first dirty tile of a frame is always redrawn (progress), the rest within the budget
    BackendData.RedrawStarted = false
    BackendData.Stale = nil

    if EditableImages.StageTiming then EditableImages.BeginStage() end
    UpdateTextures(draw_data)
    if EditableImages.StageTiming then EditableImages.EndStage("Textures") end
    if not RenderRateAllows(BackendData, draw_data) then
        PE()
        return
    end

    local ScreenWidth, ScreenHeight = floor(draw_data.DisplaySize.x), floor(draw_data.DisplaySize.y)
    if ScreenWidth <= 0 or ScreenHeight <= 0 then
        PE()
        return
    end
    local ox, oy = draw_data.DisplayPos.x, draw_data.DisplayPos.y
    local LimitX0, LimitY0, LimitX1, LimitY1 = -CLIP_PAD, -CLIP_PAD, ScreenWidth + CLIP_PAD, ScreenHeight + CLIP_PAD
    BackendData.FrameNo += 1
    local FrameNo = BackendData.FrameNo
    local force = BackendData.ForceRedraw
    BackendData.ForceRedraw = false
    Parallel.Active = Parallel.On and not Parallel.Config.Inline

    local n = 0
    CmdCount = 0
    local z = 0
    local AnyDeferred = false
    for _, draw_list in draw_data.CmdLists:iter() do
        PB("ImGui unchanged check")
        if EditableImages.StageTiming then EditableImages.BeginStage() end
        local set = BackendData.Layers[draw_list]
        local same, sdx, sdy = 0, 0, 0
        if not force then same, sdx, sdy = CompareDrawList(set, draw_list, ox, oy, ScreenWidth, ScreenHeight) end
        if same == 1 or same == 2 then
            z = ReuseDrawList(BackendData, set, draw_list, same, sdx, sdy, z, ox, oy, ScreenWidth, ScreenHeight)
            if EditableImages.StageTiming then EditableImages.EndStage("Compare") end
            PE()
            continue
        end
        if EditableImages.StageTiming then EditableImages.EndStage("Compare") end
        PE()

        PB("ImGui collect")
        if EditableImages.StageTiming then EditableImages.BeginStage() end
        local LimitFree, ex0, ey0, ex1, ey1
        local n0 = n
        n, LimitFree, ex0, ey0, ex1, ey1 = CollectPrims(BackendData, draw_list, n, ox, oy, LimitX0, LimitY0, LimitX1,
            LimitY1)
        if EditableImages.StageTiming then EditableImages.EndStage("Collect") end
        PE()

        local nd = Layers.DriftCount
        if nd > 0 then
            local Drift = Layers.Drift
            for k = 1, nd do DriftSet[Drift[k] // VTX_STRIDE + 1] = true end
            -- (recolored vertices, 4: only for PatchDrawList; the full path hashes them like any other)
            DriftOn, DriftMark1, DriftMark2 = same == 3, (FrameNo * 7907 + 12345) % P1, (FrameNo * 7919 + 54321) % P2
        end
        if same == 3 or same == 4 then
            PB("ImGui drift patch")
            if EditableImages.StageTiming then EditableImages.BeginStage() end
            local patched = PatchDrawList(BackendData, set, draw_list, n0, n, sdx, sdy, ox, oy, LimitX0, LimitY0,
                LimitX1, LimitY1, same == 4)
            if EditableImages.StageTiming then EditableImages.EndStage("Raster") end
            PE()
            if patched then
                for k = 1, nd do DriftSet[Layers.Drift[k] // VTX_STRIDE + 1] = false end
                DriftOn = false
                if same == 4 then
                    -- the snapshot: only vertex bytes changed
                    buffer.copy(set.SnapVtx, 0, draw_list.VtxBuffer.Buf, 0, set.SnapVtxBytes)
                    z = ReuseDrawList(BackendData, set, draw_list, 1, 0, 0, z, ox, oy, ScreenWidth, ScreenHeight)
                else
                    z = ReuseDrawList(BackendData, set, draw_list, 2, sdx, sdy, z, ox, oy, ScreenWidth, ScreenHeight)
                end
                continue
            end
        end
        local ListDeferred
        z, ListDeferred = DrawLists(BackendData, draw_list, z, ox, oy, force, LimitX0, LimitY0, LimitX1, LimitY1)
        if nd > 0 then
            for k = 1, nd do DriftSet[Layers.Drift[k] // VTX_STRIDE + 1] = false end
            DriftOn = false
        end
        set = BackendData.Layers[draw_list]
        -- deferred tiles: not "unchanged" next frame, so they get redrawn
        if set then
            set.LastUsed = FrameNo
            if ListDeferred then set.SnapOK = false else
                Snapshot(set, draw_list, ox, oy, ScreenWidth, ScreenHeight)
                set.SnapLimitFree = LimitFree
                set.SnapExtentX0, set.SnapExtentY0, set.SnapExtentX1, set.SnapExtentY1 = ex0, ey0, ex1, ey1
                -- the primitive sequence the tile lists were built from (PatchDrawList)
                set.PrimBase, set.PrimN = n0, n - n0
                set.PrimSigA = table.move(PrimA, n0 + 1, n, 1, set.PrimSigA or {})
                set.PrimSigD = table.move(PrimD, n0 + 1, n, 1, set.PrimSigD or {})
                set.PrimSigG = table.move(PrimGradient, n0 + 1, n, 1, set.PrimSigG or {})
            end
        end
        if ListDeferred then AnyDeferred = true end
        z = PlaceOverlays(BackendData, draw_list, z, ox, oy)
    end

    SweepLayers(BackendData, FrameNo)
    -- drop references so old vertex tables can be collected
    for k = CmdCount + 1, BackendData.LastCmdCount do CmdTexture[k], CmdVtxBuffer[k] = nil, nil end
    BackendData.LastCmdCount = CmdCount
    -- Tiles left for later: if the app doesn't submit a new frame, Heartbeat finishes them from this draw data
    if AnyDeferred then
        BackendData.Stale = draw_data
        BackendData.StaleHeartbeat = BackendData.HeartbeatCount
    end
    if Parallel.Active then
        if EditableImages.StageTiming then EditableImages.BeginStage() end
        Parallel.Flush()
        if EditableImages.StageTiming then EditableImages.EndStage("Flush") end
    end
    if EditableImages.StageTiming and EditableImages.StageFrame then
        local f = EditableImages.StageFrame
        f.Raster -= f.Upload
        f.Total = os.clock() - BackendData.FrameStartTime
        f.Other = f.Total - f.Compare - f.Collect - f.Hash - f.Raster - f.Upload - f.Textures - f.Flush
        BackendData.FrameStats = f
    end
    PE()
end

return M
