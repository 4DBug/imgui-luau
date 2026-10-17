-- Texture records, the module-wide EditableImage budget, profiling labels and stage timing stats.
local Raster = IM_INCLUDE("roblox/raster.lua")

local AssetService = game:GetService("AssetService")
local writeu32 = buffer.writeu32
local TILE = Raster.TILE

local M = {}

-- One table, not locals: shared by every context and module. FreeTile is set by layers.lua (Evict needs it).
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

@native
local function CopyTexturePixels(tex, dst, x, y, w, h)
    local bpp, tex_w = tex.BytesPerPixel, tex.Width
    for row = 0, h - 1 do
        local src, src_base = tex:GetPixelsAt(x, y + row)
        local dst_off = ((y + row) * tex_w + x) * 4
        if bpp == 4 then
            for i = 0, w - 1 do
                local s = src_base + i * 4
                writeu32(dst, dst_off + i * 4, src[s] + src[s + 1] * 256 + src[s + 2] * 65536 + src[s + 3] * 16777216)
            end
        else -- Alpha8: white with alpha
            for i = 0, w - 1 do
                writeu32(dst, dst_off + i * 4, 16777215 + src[src_base + i] * 16777216)
            end
        end
    end
end

-- Shared by every context: a font atlas shared between contexts is created under one, drawn under the others
local Records = {}
M.Records = Records

local function CreateTextureRecord(tex)
    local t = { Buffer = buffer.create(tex.Width * tex.Height * 4), Width = tex.Width, Height = tex.Height }
    CopyTexturePixels(tex, t.Buffer, 0, 0, tex.Width, tex.Height)
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
        for _, r in tex.Updates:iter() do
            CopyTexturePixels(tex, t.Buffer, r.x, r.y, r.w, r.h)
        end
        t.V = (t.V or 0) + 1 -- parallel workers hold copies, resent when this changes
        tex:SetStatus(ImTextureStatus.OK)
    elseif tex.Status == ImTextureStatus.WantDestroy then
        if tex.BackendUserData then
            Records[tex.BackendUserData] = nil
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
    Records[tex_ref._TexID] = nil
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
