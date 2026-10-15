-- Screenshot of a fixed scene (t_libhash's widgets + primitives, optionally the Custom Rendering example):
-- composites the ScreenGui like t_composite and prints "ROW y hex". tools/test/shot.py turns it into a PNG.
-- RUN_FLAGS: ARG_APP=true also opens ShowExampleAppCustomRendering (needs the demo).
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
ImGui.CreateContext(); G.ImGui_ImplRoblox.Init(); G.ImGui_ImplRoblox.SetRenderRate(0)
local io = ImGui.GetIO()
local W, H = 1280, 760
local frame = 0
local st = { b = false, f = 0.25, i = 42, c = ImVec4(0.2, 0.7, 0.4, 1.0), buf = ImGui.NewTextBuffer("hello", 64), r = 0, tab = 0, combo = 1, list = 2 }
local plot = {}
for i = 1, 40 do plot[i] = math.sin(i * 0.3) end
local poly = { ImVec2(0, 0), ImVec2(60, 10), ImVec2(30, 30), ImVec2(70, 60), ImVec2(0, 50) }

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
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10), G.ImGuiCond.Always); ImGui.SetNextWindowSize(ImVec2(320, 560), G.ImGuiCond.Always)
    ImGui.Begin("Widgets")
    ImGui.Text("Text %d", 123); ImGui.TextColored(ImVec4(1, 0.5, 0, 1), "Colored"); ImGui.TextWrapped("Wrapped text that is long enough to wrap around the window edge at least once.")
    ImGui.Button("Button"); ImGui.SameLine(); ImGui.SmallButton("Small"); ImGui.SameLine(); ImGui.ArrowButton("##a", G.ImGuiDir.Left)
    st.b = ImGui.Checkbox("Checkbox", st.b)
    st.r = ImGui.RadioButton("R0", st.r, 0); ImGui.SameLine(); st.r = ImGui.RadioButton("R1", st.r, 1)
    st.f = ImGui.SliderFloat("Slider", st.f, 0, 1); st.i = ImGui.DragInt("Drag", st.i, 1, 0, 100)
    ImGui.InputText("Input", st.buf, 64)
    ImGui.ColorEdit4("Color", st.c)
    st.combo = ImGui.Combo("Combo", st.combo, { "AAA", "BBB", "CCC" })
    st.list = ImGui.ListBox("List", st.list, { "one", "two", "three", "four" }, 4, 3)
    ImGui.ProgressBar(0.4, ImVec2(-1, 0)); ImGui.ProgressBar(-1.0 * frame / 60, ImVec2(-1, 0), "busy")
    ImGui.PlotLines("Lines", plot, nil, #plot); ImGui.PlotHistogram("Hist", plot, nil, #plot, 0, nil, -1, 1, ImVec2(0, 40))
    ImGui.Bullet(); ImGui.Text("bullet"); ImGui.Separator(); ImGui.SeparatorText("Sep")
    if ImGui.TreeNode("Tree") then ImGui.Text("inside"); ImGui.TreePop() end
    ImGui.SetNextItemOpen(true, G.ImGuiCond.Once)
    if ImGui.CollapsingHeader("Header") then
        if ImGui.BeginTabBar("tabs") then
            if ImGui.BeginTabItem("Tab A") then ImGui.Text("A"); ImGui.EndTabItem() end
            if ImGui.BeginTabItem("Tab B") then ImGui.Text("B"); ImGui.EndTabItem() end
            ImGui.EndTabBar()
        end
        if ImGui.BeginTable("t", 3, bit32.bor(G.ImGuiTableFlags.Borders, G.ImGuiTableFlags.RowBg, G.ImGuiTableFlags.Resizable)) then
            ImGui.TableSetupColumn("One"); ImGui.TableSetupColumn("Two"); ImGui.TableSetupColumn("Three"); ImGui.TableHeadersRow()
            for row = 0, 4 do ImGui.TableNextRow(); for col = 0, 2 do ImGui.TableSetColumnIndex(col); ImGui.Text("r%d c%d", row, col) end end
            ImGui.EndTable()
        end
    end
    ImGui.End()

    ImGui.SetNextWindowPos(ImVec2(340, 10), G.ImGuiCond.Always); ImGui.SetNextWindowSize(ImVec2(300, 560), G.ImGuiCond.Always)
    ImGui.Begin("Draw")
    local dl, p = ImGui.GetWindowDrawList(), ImGui.GetCursorScreenPos()
    local x, y, col = p.x + 4, p.y + 4, 0xFF40C0FF
    for i, th in { 1.0, 2.5, 6.0 } do
        local yy = y + (i - 1) * 70
        dl:AddRect(ImVec2(x, yy), ImVec2(x + 50, yy + 50), col, 10.0, th)
        dl:AddRectFilled(ImVec2(x + 60, yy), ImVec2(x + 110, yy + 50), col, 10.0, G.ImDrawFlags.RoundTopLeft or G.ImDrawFlags.RoundCornersTopLeft) -- RoundCornersTopLeft: pre-1.93 revs (hashes.sh)
        dl:AddCircle(ImVec2(x + 145, yy + 25), 25, col, 0, th)
        dl:AddNgon(ImVec2(x + 200, yy + 25), 25, col, 6, th)
        dl:AddTriangle(ImVec2(x + 230, yy + 50), ImVec2(x + 255, yy), ImVec2(x + 280, yy + 50), col, th)
        dl:AddLine(ImVec2(x, yy + 60), ImVec2(x + 280, yy + 55), col, th)
    end
    y += 210
    dl:AddBezierCubic(ImVec2(x, y), ImVec2(x + 60, y - 30), ImVec2(x + 120, y + 60), ImVec2(x + 180, y), col, 3.0)
    dl:AddBezierQuadratic(ImVec2(x, y + 30), ImVec2(x + 90, y - 10), ImVec2(x + 180, y + 30), col, 2.0)
    dl:AddEllipse(ImVec2(x + 230, y + 15), ImVec2(40, 15), col, 0.5, 0, 2.0)
    y += 50
    local pts = {}
    for i, v in poly do pts[i] = ImVec2(x + v.x, y + v.y) end
    dl:AddConcavePolyFilled(pts, #pts, 0xFF8080FF)
    for i, v in poly do pts[i] = ImVec2(x + 100 + v.x, y + v.y) end
    dl:AddPolyline(pts, #pts, col, 4.0, G.ImDrawFlags.Closed)
    for i, v in poly do pts[i] = ImVec2(x + 200 + v.x, y + v.y) end
    dl:AddPolyline(pts, #pts, col, 1.0, 0)
    y += 80
    dl:AddRectFilledMultiColor(ImVec2(x, y), ImVec2(x + 100, y + 40), 0xFF0000FF, 0xFF00FF00, 0xFFFF0000, 0xFFFFFFFF)
    dl:AddCircleFilled(ImVec2(x + 140, y + 20), 20, col)
    dl:AddEllipseFilled(ImVec2(x + 210, y + 20), ImVec2(30, 15), col, 0.3)
    dl:AddText(ImVec2(x, y + 50), 0xFFFFFFFF, "AddText")
    ImGui.End()

    if ARG_APP then ImGui.SetNextWindowPos(ImVec2(650, 10), G.ImGuiCond.Always); ImGui.SetNextWindowSize(ImVec2(620, 740), G.ImGuiCond.Always); G.ShowExampleAppCustomRendering(true) end
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == ARG_FRAMES - 1 then
        local screen = composite(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ImGui"))
        for y = 0, H - 1 do
            local t = table.create(W * 3)
            for i = 0, W * 3 - 1 do t[i + 1] = string.format("%02x", buffer.readu8(screen, y * W * 3 + i)) end
            print("ROW", y, table.concat(t))
        end
    end
end)
