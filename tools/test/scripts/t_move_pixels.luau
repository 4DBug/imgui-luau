-- Moving-window pixel oracle (like t_pixels): a window with circles, rounded rects, bullets and curves moves by whole
-- pixels (some frames by half a pixel), "PIX <frame> <hash>" every 4 frames. Trig-generated vertices drift by an ulp
-- off the exact shift: the backend must still redraw what they touch. Run with RUN_FLAGS="ARG_FORCE=true" for a full
-- redraw every frame: incremental output must match it exactly.
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
if ARG_TILELIMIT then ImGui.GetIO().BackendPlatformUserData.TileLimit = ARG_TILELIMIT end
local io = ImGui.GetIO()
local W, H = 1280, 760
local col = ImVec4(0.4, 0.7, 0.2, 0.5)
local buf = ImGui.NewTextBuffer("type here", 128)
local slider = 0.3

local function composite(gui)
    local screen = buffer.create(W * H * 3)
    local function walk(inst, ox, oy, kx0, ky0, kx1, ky1)
        local kids = inst:GetChildren()
        table.sort(kids, function(a, b) return (a.ZIndex or 1) < (b.ZIndex or 1) end)
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
                        if sy >= cy0 and sy < cy1 then
                            for tx = 0, sz - 1 do
                                local sx = x + tx
                                if sx >= cx0 and sx < cx1 then
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
    local h = 0
    for i = 0, W * H * 3 - 4, 4 do h = (h * 31 + buffer.readu32(screen, i)) % 2147483647 end
    return h
end

local frame = 0
local pos = ImVec2(40, 40)
local radio = 1
game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    if frame > 240 then return end
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    io:AddMousePosEvent(1200, 740)
    if frame > 4 then
        if frame < 120 then pos = ImVec2(pos.x + 3, pos.y + 2) else pos = ImVec2(pos.x - 5, pos.y - 1) end
        if frame % 37 == 0 then pos = ImVec2(pos.x + 0.5, pos.y) end -- fractional: full path
    end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(pos, G.ImGuiCond.Always); ImGui.SetNextWindowSize(ImVec2(420, 460), G.ImGuiCond.Always)
    ImGui.Begin("Stress")
    for i = 1, 6 do ImGui.Button("Button " .. i); ImGui.SameLine(); slider = ImGui.SliderFloat("##s" .. i, slider, 0, 1) end
    for i = 1, 4 do if ImGui.RadioButton("r" .. i, radio == i) then radio = i end; ImGui.SameLine() end
    ImGui.NewLine()
    ImGui.Checkbox("check", true)
    ImGui.Bullet(); ImGui.Text("bullet")
    if ImGui.TreeNode("tree") then ImGui.Text("inside"); ImGui.TreePop() end
    ImGui.ColorButton("cb", col)
    local dl = ImGui.GetWindowDrawList()
    local p = ImGui.GetCursorScreenPos()
    dl:AddCircleFilled(ImVec2(p.x + 40, p.y + 40), 33.3, 0xFF3080F0)
    dl:AddCircle(ImVec2(p.x + 120, p.y + 40), 27.7, 0xFFF08030, 0, 2.5)
    dl:AddRectFilled(ImVec2(p.x + 170, p.y + 10), ImVec2(p.x + 260, p.y + 70), 0x8040F040, 12.3)
    dl:AddBezierCubic(ImVec2(p.x, p.y + 90), ImVec2(p.x + 90, p.y + 60), ImVec2(p.x + 180, p.y + 140), ImVec2(p.x + 300, p.y + 90), 0xFFFFFFFF, 1.7)
    ImGui.Dummy(ImVec2(300, 150))
    for i = 1, 40 do ImGui.TextWrapped("Line %d: the quick brown fox jumps over the lazy dog.", i) end
    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame % 4 == 0 then
        print("PIX", frame, composite(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ImGui")))
    end
    if frame == 240 then print("MOVEPIX DONE") end
end)
