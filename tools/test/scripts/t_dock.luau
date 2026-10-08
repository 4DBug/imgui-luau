local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.DockingEnable)
G.ImGui_ImplRoblox.Init()
local frame = 0
local dockspace_id
local winA, winB, winC
RunService.Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()
    dockspace_id = ImGui.DockSpaceOverViewport(0, nil, 0)
    if frame == 2 then
        ImGui.DockBuilderRemoveNode(dockspace_id)
        ImGui.DockBuilderAddNode(dockspace_id, bit32.bor(G.ImGuiDockNodeFlags.DockSpace))
        ImGui.DockBuilderSetNodeSize(dockspace_id, ImGui.GetMainViewport().Size)
        local left, right = ImGui.DockBuilderSplitNode(dockspace_id, G.ImGuiDir.Left, 0.3)
        ImGui.DockBuilderDockWindow("A", left)
        ImGui.DockBuilderDockWindow("B", right)
        ImGui.DockBuilderDockWindow("C", right)
        ImGui.DockBuilderFinish(dockspace_id)
        print("split", left, right)
    end
    for _, n in ipairs({"A", "B", "C"}) do
        if ImGui.Begin(n) then ImGui.Text("window " .. n) end
        ImGui.End()
    end
    if frame == 30 then
        local g = ImGui.GetCurrentContext()
        local a, b, c = ImGui.FindWindowByName("A"), ImGui.FindWindowByName("B"), ImGui.FindWindowByName("C")
        print("A node", a.DockNode and a.DockNode.ID, "B node", b.DockNode and b.DockNode.ID, "C node", c.DockNode and c.DockNode.ID)
        assert(a.DockNode ~= nil and b.DockNode ~= nil, "windows must be docked")
        assert(a.DockNode ~= b.DockNode, "A and B in different nodes")
        assert(b.DockNode == c.DockNode, "B and C share a node")
        assert(b.DockNode.TabBar ~= nil and b.DockNode.TabBar.Tabs.Size == 2, "B/C tab bar with 2 tabs")
        local ini = ImGui.SaveIniSettingsToMemory()
        print(ini)
        assert(ini:find("%[Docking%]%[Data%]"), "docking ini section")
        print("DOCK OK")
    end
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
