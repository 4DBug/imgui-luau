-- Library-only draw-data checksum (no demo, run with NO_DEMO=1): widgets + raw ImDrawList primitives with scripted input.
-- Must stay identical across demo edits; changes only when library rendering changes. Prints "LIBHASH <n>".
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
ImGui.CreateContext(); G.ImGui_ImplRoblox.Init(); G.ImGui_ImplRoblox.SetRenderRate(0)
local io = ImGui.GetIO()
local frame, h = 0, 0
local function mix(v) h = (h * 31 + math.floor(v * 64 + 0.5)) % 2147483647 end
local st = { b = false, f = 0.25, i = 42, c = ImVec4(0.2, 0.7, 0.4, 1.0), buf = ImGui.NewTextBuffer("hello", 64), r = 0, tab = 0, combo = 1, list = 2 }
local plot = {}
for i = 1, 40 do plot[i] = math.sin(i * 0.3) end
local poly = { ImVec2(0, 0), ImVec2(60, 10), ImVec2(30, 30), ImVec2(70, 60), ImVec2(0, 50) }

game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    io:AddMousePosEvent(20 + (frame * 37) % 560, 20 + (frame * 53) % 560)
    if frame % 7 == 0 then io:AddMouseButtonEvent(0, frame % 14 == 0) end
    if frame % 11 == 0 then io:AddMouseWheelEvent(0, -1) end
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

    ImGui.Render()
    for _, dl in ImGui.GetDrawData().CmdLists:iter() do
        local vb, id = dl.VtxBuffer.Buf, dl.IdxBuffer.Data
        for i = 1, dl.VtxBuffer.Size do local o = (i - 1) * 36; mix(buffer.readf64(vb, o)); mix(buffer.readf64(vb, o + 8)); mix(buffer.readf64(vb, o + 16) * 4096); mix(buffer.readf64(vb, o + 24) * 4096); mix(buffer.readu32(vb, o + 32) / 64) end
        for i = 1, dl.IdxBuffer.Size do mix(id[i]) end
        for _, c in dl.CmdBuffer:iter() do mix(c.ClipRect.x); mix(c.ClipRect.y); mix(c.ClipRect.z); mix(c.ClipRect.w); mix(c.ElemCount) end
    end
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == ARG_FRAMES - 1 then print("LIBHASH", h) end
end)
