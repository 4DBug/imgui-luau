local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local function setup()
    ImGui.CreateContext()
    local io = ImGui.GetIO()
    io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.DockingEnable)
    G.ImGui_ImplRoblox.Init()
end
setup()
local frame, phase, ini, base = 0, 1, nil, 0
local function windows()
    for _, n in ipairs({"A", "B", "C"}) do
        if ImGui.Begin(n) then ImGui.Text("window " .. n) end
        ImGui.End()
    end
end
RunService.Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()
    local id = ImGui.DockSpaceOverViewport(0, nil, 0)
    local f = frame - base
    if phase == 1 then
        if f == 2 then
            ImGui.DockBuilderRemoveNode(id)
            ImGui.DockBuilderAddNode(id, G.ImGuiDockNodeFlags.DockSpace)
            ImGui.DockBuilderSetNodeSize(id, ImGui.GetMainViewport().Size)
            local l, r = ImGui.DockBuilderSplitNode(id, G.ImGuiDir.Left, 0.25)
            local rt, rb = ImGui.DockBuilderSplitNode(r, G.ImGuiDir.Up, 0.6)
            ImGui.DockBuilderDockWindow("A", l); ImGui.DockBuilderDockWindow("B", rt); ImGui.DockBuilderDockWindow("C", rb)
            ImGui.DockBuilderFinish(id)
        end
        windows()
        if f == 20 then
            ini = ImGui.SaveIniSettingsToMemory()
            print(ini:match("%[Docking%].*"))
        end
    else
        windows()
        if f == 20 then
            local a, b, c = ImGui.FindWindowByName("A"), ImGui.FindWindowByName("B"), ImGui.FindWindowByName("C")
            print("reloaded nodes", a.DockNode and a.DockNode.ID, b.DockNode and b.DockNode.ID, c.DockNode and c.DockNode.ID, "sizes", a.Size.x, b.Size.x, b.Size.y, c.Size.y)
            assert(a.DockNode and b.DockNode and c.DockNode, "all docked after reload")
            assert(a.DockNode ~= b.DockNode and b.DockNode ~= c.DockNode, "3 distinct nodes")
            local ini2 = ImGui.SaveIniSettingsToMemory()
            assert(ini2:match("%[Docking%].*") == ini:match("%[Docking%].*"), "docking ini identical after round trip")
            print("INI ROUNDTRIP OK")
        end
    end
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if phase == 1 and f == 20 then
        G.ImGui_ImplRoblox.Shutdown()
        ImGui.DestroyContext()
        setup()
        ImGui.LoadIniSettingsFromMemory(ini)
        phase, base = 2, frame
    end
end)
