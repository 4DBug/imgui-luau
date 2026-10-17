-- Overlays: user Instances placed inside a window (SetOverlay), stacked right above its layers and moving with it.
local Textures = IM_INCLUDE("roblox/textures.lua")

local M = {}

local function OverlayHolder(BackendData, draw_list, clip)
    local hs = BackendData.OverlayHolders[draw_list]
    if not hs then
        hs = {}
        BackendData.OverlayHolders[draw_list] = hs
    end
    local h = hs[clip]
    if not h then
        h = Instance.new("Frame")
        h.Name = clip and "OverlayClip" or "Overlay"
        h.BackgroundTransparency = 1
        h.BorderSizePixel = 0
        h.ClipsDescendants = clip
        h.Size = UDim2.fromOffset(0, 0)
        h.Parent = BackendData.Gui
        hs[clip] = h
    end
    return h
end

local OverlayUsed = {}
function M.PlaceOverlays(BackendData, draw_list, z, ox, oy)
    local list = BackendData.Overlays[draw_list]
    local hs = BackendData.OverlayHolders[draw_list]
    if not list then
        if hs then for _, h in pairs(hs) do h.Visible = false end end
        return z
    end
    local scale, frame_no = BackendData.Scale, BackendData.FrameNo
    z += 1
    local used = OverlayUsed
    table.clear(used)
    for _, o in ipairs(list) do
        local clip = o.Clip and draw_list._ContentClipX0 ~= nil
        local h = OverlayHolder(BackendData, draw_list, clip)
        local hx, hy = 0, 0
        if clip then
            hx, hy = draw_list._ContentClipX0 - ox, draw_list._ContentClipY0 - oy
            if not used[h] then
                h.Position = UDim2.fromOffset(hx / scale, hy / scale)
                h.Size = UDim2.fromOffset((draw_list._ContentClipX1 - draw_list._ContentClipX0) / scale,
                    (draw_list._ContentClipY1 - draw_list._ContentClipY0) / scale)
            end
        elseif not used[h] then
            h.Position = UDim2.fromOffset(0, 0)
        end
        used[h] = true
        h.ZIndex = z
        h.Visible = true
        local f = o.Frame
        if f.Parent ~= h then f.Parent = h end
        f.Position = UDim2.fromOffset((o.X - ox - hx) / scale, (o.Y - oy - hy) / scale)
        f.Size = UDim2.fromOffset(o.W / scale, o.H / scale)
        f.Visible = true
        BackendData.OverlayShown[f] = frame_no
    end
    if hs then for _, h in pairs(hs) do if not used[h] then h.Visible = false end end end
    return z
end

--- Show `frame` this frame at (x, y, w, h) (imgui coordinates) inside the current window. Call every frame it should
--- be visible; frames not submitted are hidden. clip: clip to the window's content area (scrolls with it).
function ImGui_ImplRoblox_SetOverlay(frame, x, y, w, h, clip)
    local BackendData = Textures.GetBackendData()
    local dl = ImGui.GetWindowDrawList()
    local list = BackendData.Overlays[dl]
    if not list then
        list = {}
        BackendData.Overlays[dl] = list
    end
    list[#list + 1] = { Frame = frame, X = x, Y = y, W = w, H = h, Clip = clip ~= false }
end

return M
