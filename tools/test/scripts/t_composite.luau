-- Composites every visible tile ImageLabel (walking the ScreenGui like Roblox: ZIndex order, nested offsets) onto a
-- black screen and prints the RGB of a region as hex rows ("ROW y hex"). Compare two backend versions with
-- tools/test/compare_composite.py to prove a backend change renders the same pixels.
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
local io = ImGui.GetIO()
local col = ImVec4(0.4, 0.7, 0.2, 0.5)
local W, H = 1280, 760
local frame = 0

local function composite(gui)
    local screen = buffer.create(W * H * 3)
    local function walk(inst, ox, oy, kx0, ky0, kx1, ky1)
        local kids = inst:GetChildren()
        table.sort(kids, function(a, b) return (a.ZIndex or 1) < (b.ZIndex or 1) end) -- table.sort isn't stable, but siblings with equal ZIndex never overlap here
        for _, c in ipairs(kids) do
            if c.Visible ~= false then
                local x, y = ox + (c.Position and c.Position.X or 0), oy + (c.Position and c.Position.Y or 0)
                local cx0, cy0, cx1, cy1 = kx0, ky0, kx1, ky1
                if c.ClipsDescendants then
                    cx0, cy0 = math.max(cx0, x), math.max(cy0, y)
                    cx1, cy1 = math.min(cx1, x + c.Size.X), math.min(cy1, y + c.Size.Y)
                end
                if c.ClassName == "ImageLabel" then
                    local img = c.ImageContent.Object
                    local px, sz = img.Pixels, img.Size.X
                    for ty = 0, sz - 1 do
                        local sy = y + ty
                        if sy >= ky0 and sy < ky1 then
                            for tx = 0, sz - 1 do
                                local sx = x + tx
                                if sx >= kx0 and sx < kx1 then
                                    local o = (ty * sz + tx) * 4
                                    local a = buffer.readu8(px, o + 3)
                                    if a > 0 then
                                        local d = (sy * W + sx) * 3
                                        local fa = a / 255
                                        for ch = 0, 2 do
                                            local v = buffer.readu8(px, o + ch) * fa + buffer.readu8(screen, d + ch) * (1 - fa)
                                            buffer.writeu8(screen, d + ch, math.floor(v + 0.5))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                walk(c, x, y, cx0, cy0, cx1, cy1)
            end
        end
    end
    walk(gui, 0, 0, 0, 0, W, H)
    return screen
end

game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    io:AddMousePosEvent(300 + (frame * 37) % 300, 100 + (frame * 53) % 500)
    local dw = ImGui.FindWindowByName("Dear ImGui Demo")
    if dw and frame % 3 == 0 then io:AddMousePosEvent(dw.Pos.x + 200, dw.Pos.y + 300); io:AddMouseWheelEvent(0, (frame % 30 < 18) and -1 or 1) end
    ImGui.NewFrame()
    ImGui.ShowDemoWindow(true)
    ImGui.SetNextWindowPos(ImVec2(20, 20)); ImGui.SetNextWindowSize(ImVec2(600, 700))
    ImGui.Begin("Pickers")
    ImGui.ColorPicker4("bar", col, G.ImGuiColorEditFlags.PickerHueBar)
    ImGui.ColorPicker4("wheel", col, G.ImGuiColorEditFlags.PickerHueWheel)
    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == ARG_FRAMES - 1 then
        local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ImGui")
        local screen = composite(gui)
        for y = 0, H - 1 do
            local t = table.create(W * 3)
            for i = 0, W * 3 - 1 do t[i + 1] = string.format("%02x", buffer.readu8(screen, y * W * 3 + i)) end
            print("ROW", y, table.concat(t))
        end
    end
end)
