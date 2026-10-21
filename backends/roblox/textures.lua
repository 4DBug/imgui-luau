-- Texture records, the module-wide EditableImage budget, profiling labels and stage timing stats.
local Raster = IM_INCLUDE("roblox/raster.lua")

local AssetService = game:GetService("AssetService")
local writeu32 = buffer.writeu32
local TILE = Raster.TILE

local M = {}

-- One table, not locals: shared by every context and module. FreeTile is set by layers.lua (Evict needs it),
-- TextureDropped(id, record) by parallel.lua (Actors free their copies).
local EditableImages = {
    Cap = 64 * 1024 * 1024, Bytes = 0, Count = 0, ImageBytes = setmetatable({}, { __mode = "k" }),
    Pool = {}, PoolMax = 16,
    Backends = setmetatable({}, { __mode = "k" }),
    LastTextureId = 0, KEEP_FRAMES = 30,
    StageTiming = false,
}
M.EditableImages = EditableImages

local ProfileBegin, ProfileEnd = debug.profilebegin, debug.profileend
local Profiling = false
function M.PB(name) if Profiling then ProfileBegin(name) end end
function M.PE() if Profiling then ProfileEnd() end end
function M.SetProfiling(enabled) Profiling = enabled and true or false end
function M.IsProfiling() return Profiling end

-- StageTiming on: RenderDrawData accumulates os.clock per stage into StageFrame (GetStats().Frame)
function EditableImages.BeginStage() EditableImages.StageStart = os.clock() end
function EditableImages.EndStage(stage)
    local f = EditableImages.StageFrame
    if f then f[stage] += os.clock() - EditableImages.StageStart end
end
function EditableImages.AddStat(name, n)
    local f = EditableImages.StageFrame
    if f then f[name] += n end
end

function M.GetBackendData()
    return ImGui.GetCurrentContext() and ImGui.GetIO().BackendPlatformUserData or nil
end

-- n pixels from the byte table src (1-based index s) to dst (byte offset d). Typed + unrolled by 4: the native code
-- skips the generic table/buffer checks (~40% faster than the plain loop).
@native
local function CopyRGBA(src: { number }, s: number, dst: buffer, d: number, n: number)
    for _ = 1, n // 4 do
        writeu32(dst, d, src[s] + src[s + 1] * 256 + src[s + 2] * 65536 + src[s + 3] * 16777216)
        writeu32(dst, d + 4, src[s + 4] + src[s + 5] * 256 + src[s + 6] * 65536 + src[s + 7] * 16777216)
        writeu32(dst, d + 8, src[s + 8] + src[s + 9] * 256 + src[s + 10] * 65536 + src[s + 11] * 16777216)
        writeu32(dst, d + 12, src[s + 12] + src[s + 13] * 256 + src[s + 14] * 65536 + src[s + 15] * 16777216)
        s += 16
        d += 16
    end
    for _ = 1, n % 4 do
        writeu32(dst, d, src[s] + src[s + 1] * 256 + src[s + 2] * 65536 + src[s + 3] * 16777216)
        s += 4
        d += 4
    end
end

@native
local function CopyAlpha8(src: { number }, s: number, dst: buffer, d: number, n: number) -- white with alpha
    for _ = 1, n do
        writeu32(dst, d, 16777215 + src[s] * 16777216)
        s += 1
        d += 4
    end
end

local function CopyTexturePixels(tex, dst, x, y, w, h)
    local tex_w = tex.Width
    local copy = tex.BytesPerPixel == 4 and CopyRGBA or CopyAlpha8
    if x == 0 and w == tex_w then -- whole rows: one flat run
        local src, s = tex:GetPixelsAt(0, y)
        copy(src, s, dst, y * tex_w * 4, w * h)
        return
    end
    for row = 0, h - 1 do
        local src, s = tex:GetPixelsAt(x, y + row)
        copy(src, s, dst, ((y + row) * tex_w + x) * 4, w)
    end
end

-- Shared by every context: a font atlas shared between contexts is created under one, drawn under the others
local Records = {}
M.Records = Records

-- The buffer of the last destroyed atlas texture record: the next one of the same size (an atlas repack: same size
-- every time) reuses it. buffer.create of an atlas is slow in Studio (~0.2-1.8 ms for 512 KB, spiky).
local SpareBuffer: buffer? = nil

local function CreateTextureRecord(tex)
    local w, h = tex.Width, tex.Height
    local b, reused = SpareBuffer, false
    if b and buffer.len(b) == w * h * 4 then
        SpareBuffer, reused = nil, true
    else
        b = buffer.create(w * h * 4)
    end
    -- The current font atlas texture: pixels outside the packed rects (MaxRectBounds) and the queued uploads (UsedRect)
    -- are still zero (repack's BlockCopy doesn't queue, but every copied rect is packed). Fill them with what zero
    -- converts to, convert only the used corner. A fresh/grown atlas is mostly empty. Any other texture: everything.
    local atlas = ImGui.GetCurrentContext() and ImGui.GetIO().Fonts
    local cw, ch = w, h
    if atlas and atlas.TexData == tex and atlas.Builder then
        local u, m = tex.UsedRect, atlas.Builder.MaxRectBounds
        cw = math.min(w, math.max(u.x + u.w, m.x))
        ch = math.min(h, math.max(u.y + u.h, m.y))
    end
    if cw < w or ch < h then
        if tex.BytesPerPixel == 4 then
            if reused then buffer.fill(b, 0, 0) end
        else -- Alpha8 zero -> 0x00FFFFFF; RGBA zero -> 0 (buffer.create's fill)
            local n, total = 4, w * h * 4
            writeu32(b, 0, 16777215)
            while n < total do
                local c = math.min(n, total - n)
                buffer.copy(b, n, b, 0, c)
                n += c
            end
        end
        CopyTexturePixels(tex, b, 0, 0, cw, ch)
    else
        CopyTexturePixels(tex, b, 0, 0, w, h)
    end
    -- rows FillRow.. hold only Fill (what zero converts to): parallel.lua sends Actors the rows above it
    local t = { Buffer = b, Width = w, Height = h, FillRow = ch, Fill = tex.BytesPerPixel ~= 4 and 16777215 or 0 }
    EditableImages.LastTextureId += 1
    Records[EditableImages.LastTextureId] = t
    tex.BackendUserData = EditableImages.LastTextureId
    tex:SetTexID(EditableImages.LastTextureId)
    tex:SetStatus(ImTextureStatus.OK)
end

function M.UpdateTexture(tex)
    if tex.Status == ImTextureStatus.WantCreate then
        CreateTextureRecord(tex)
    elseif tex.Status == ImTextureStatus.WantUpdates then
        local t = Records[tex.BackendUserData]
        if t == nil or t.Width ~= tex.Width or t.Height ~= tex.Height then
            CreateTextureRecord(tex)
            return
        end
        local y0, y1 = math.huge, -1
        local rects, n = {}, 0
        for _, r in tex.Updates:iter() do
            CopyTexturePixels(tex, t.Buffer, r.x, r.y, r.w, r.h)
            if r.y < y0 then y0 = r.y end
            if r.y + r.h > y1 then y1 = r.y + r.h end
            rects[n + 1], rects[n + 2], rects[n + 3], rects[n + 4] = r.x, r.y, r.w, r.h
            n += 4
        end
        -- parallel workers hold copies, patched when this changes: Log[V] = changed rows + the rects (x, y, w, h
        -- quadruples) (only the last 16 kept)
        if t.FillRow and y1 > t.FillRow then t.FillRow = y1 end
        local v = (t.V or 0) + 1
        t.V = v
        t.Log = t.Log or {}
        t.Log[v] = y1 > y0 and { y0, y1, rects } or { 0, 0 }
        t.Log[v - 16] = nil
        tex:SetStatus(ImTextureStatus.OK)
    elseif tex.Status == ImTextureStatus.WantDestroy then
        if tex.BackendUserData then
            local id = tex.BackendUserData
            local rec = Records[id]
            if EditableImages.TextureDropped then EditableImages.TextureDropped(id, rec) end
            if rec and rec.FillRow then SpareBuffer = rec.Buffer end -- (FillRow: a buffer CreateTextureRecord made)
            Records[id] = nil
            tex.BackendUserData = nil
        end
        tex:SetTexID(ImTextureID_Invalid)
        tex:SetStatus(ImTextureStatus.Destroyed)
    end
end

-- User texture from RGBA8 pixels. Ids are never reused, so cached tiles can't show a stale image.
function ImGui_ImplRoblox_CreateTexture(pixels, w, h)
    EditableImages.LastTextureId += 1
    Records[EditableImages.LastTextureId] = { Buffer = pixels, Width = w, Height = h }
    return ImTextureRef(EditableImages.LastTextureId)
end

function ImGui_ImplRoblox_DestroyTexture(tex_ref)
    local id = tex_ref._TexID
    if EditableImages.TextureDropped then EditableImages.TextureDropped(id, Records[id]) end
    Records[id] = nil
end

-- Every EditableImage goes through Create/Destroy, counted against Cap. Over the cap (or CreateEditableImage failing):
-- evict idle tiles, retry once; still nothing -> nil, the caller skips the tile this frame.
function EditableImages.Create(w, h)
    local need = w * h * 4
    if need > EditableImages.Cap then return nil end
    for attempt = 1, 2 do
        if EditableImages.Bytes + need <= EditableImages.Cap then
            local ok, img = pcall(AssetService.CreateEditableImage, AssetService, { Size = Vector2.new(w, h) })
            if ok and img then
                EditableImages.ImageBytes[img] = need
                EditableImages.Bytes += need
                EditableImages.Count += 1
                return img
            end
            if attempt == 1 then EditableImages.Evict(math.huge) end -- engine refused: free everything evictable
        elseif attempt == 1 then
            EditableImages.Evict(EditableImages.Bytes + need - EditableImages.Cap)
        end
    end
    return nil
end

function EditableImages.Destroy(img)
    local s = EditableImages.ImageBytes[img]
    if s then
        EditableImages.ImageBytes[img] = nil
        EditableImages.Bytes -= s
        EditableImages.Count -= 1
    end
    img:Destroy()
end

-- The free list first, then idle tiles (not shown, not used this frame) of every context
function EditableImages.Evict(need)
    local freed = 0
    while freed < need and #EditableImages.Pool > 0 do
        local t = table.remove(EditableImages.Pool)
        EditableImages.Destroy(t.Image)
        t.Label:Destroy()
        freed += TILE * TILE * 4
    end
    if freed >= need then return end
    for BackendData in EditableImages.Backends do
        for _, set in pairs(BackendData.Layers) do
            for kind = 1, 3 do
                local l = set[kind]
                if l then
                    for k, t in pairs(l.Tiles) do
                        if t.Used ~= BackendData.FrameNo and not (t.Visible and l.Visible) then
                            EditableImages.FreeTile(l, k)
                            freed += TILE * TILE * 4
                        end
                    end
                end
            end
        end
    end
end

return M
