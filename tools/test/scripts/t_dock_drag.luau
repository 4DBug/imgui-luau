local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.DockingEnable)
G.ImGui_ImplRoblox.Init()
local frame = 0
-- script: {frame, x, y, down}
local function lerp(a, b, t) return a + (b - a) * t end
local function script(f)
    if f >= 50 then
        -- tab of B inside the docked node: press on the tab, drag far downward to undock
        if f < 52 then return 150, 108, false end
        if f == 52 then return 150, 108, true end
        if f <= 66 then local t = (f - 52) / 14 return lerp(150, 700, t), lerp(108, 600, t), true end
        if f <= 70 then return 700, 600, true end
        return 700, 600, false
    end
    if f < 6 then return 600, 108, false end
    if f == 6 then return 600, 108, true end
    if f <= 20 then local t = (f - 6) / 14 return lerp(600, 250, t), lerp(108, 190, t), true end
    if f <= 26 then return 250, 190, true end
    if f == 27 then return 250, 190, false end
    return 250, 190, false
end
local last_down = false
RunService.Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    local x, y, down = script(frame)
    io:AddMousePosEvent(x, y)
    if down ~= last_down then io:AddMouseButtonEvent(0, down); last_down = down end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(100, 100), G.ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(ImVec2(300, 200), G.ImGuiCond.FirstUseEver)
    if ImGui.Begin("A") then ImGui.Text("window A") end
    ImGui.End()
    ImGui.SetNextWindowPos(ImVec2(500, 100), G.ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(ImVec2(300, 200), G.ImGuiCond.FirstUseEver)
    if ImGui.Begin("B") then ImGui.Text("window B") end
    ImGui.End()
    if frame == 28 or frame == 40 then
        local a, b = ImGui.FindWindowByName("A"), ImGui.FindWindowByName("B")
        local g = ImGui.GetCurrentContext()
        print("frame", frame, "movingwindow", g.MovingWindow and g.MovingWindow.Name, "dragdrop", g.DragDropActive, "A.node", a.DockNode and a.DockNode.ID, "B.node", b.DockNode and b.DockNode.ID, "B.pos", b.Pos.x, b.Pos.y)
    end
    if frame == 45 then
        local a, b = ImGui.FindWindowByName("A"), ImGui.FindWindowByName("B")
        assert(a.DockNode ~= nil and a.DockNode == b.DockNode, "B must be docked into A's node")
        assert(a.DockNode.Windows.Size == 2, "node has 2 windows")
        print("DRAG DOCK OK")
    end
    if frame >= 60 and frame <= 90 and frame % 3 == 0 then local g = ImGui.GetCurrentContext(); local b = ImGui.FindWindowByName("B"); local tb = b.DockNode and b.DockNode.TabBar; print("f", frame, "Bnode", b.DockNode and b.DockNode.ID, "Bpos", b.Pos.x, b.Pos.y, "active", g.ActiveId, "hovered", g.HoveredId, "hovwin", g.HoveredWindow and g.HoveredWindow.Name, "tabid", b.TabId, "moving", g.MovingWindow and g.MovingWindow.Name, "dd", g.DragDropActive, "mouse", g.IO.MousePos.x, g.IO.MousePos.y, "down", g.IO.MouseDown[0], "drag", ImGui.IsMouseDragging(0)) end
    if frame == 52 then
        local b = ImGui.FindWindowByName("B")
        local tb = b.DockNode.TabBar
        for i = 1, tb.Tabs.Size do local t = tb.Tabs.Data[i]; print("tab", i, ImGui.TabBarGetTabName(tb, t), "offset", t.Offset, "width", t.Width, "bar", tb.BarRect.Min.x, tb.BarRect.Min.y, tb.BarRect.Max.x, tb.BarRect.Max.y) end
    end
    if frame == 90 then
        local a, b = ImGui.FindWindowByName("A"), ImGui.FindWindowByName("B")
        print("final", "A.node", a.DockNode and a.DockNode.ID, "B.node", b.DockNode and b.DockNode.ID, "B.pos", b.Pos.x, b.Pos.y)
        assert(b.DockNode == nil or b.DockNode ~= a.DockNode, "B must be undocked from A")
        print("UNDOCK OK")
    end
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
