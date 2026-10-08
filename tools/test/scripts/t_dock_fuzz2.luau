local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.DockingEnable)
G.ImGui_ImplRoblox.Init()
local frame = 0
local seed = 7
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
local names = {"A", "B", "C", "D", "E"}
local drag -- {fx,fy,tx,ty,start}
local last_down = false
local docks, undocks = 0, 0
local function check_tree()
    local g = ImGui.GetCurrentContext()
    for id, node in pairs(g.DockContext.Nodes) do
        assert(node.ID == id)
        if node.ParentNode then
            assert(node.ParentNode.ChildNodes[0] == node or node.ParentNode.ChildNodes[1] == node, "parent link")
        end
        for _, w in node.Windows:iter() do assert(w.DockNode == node or w.DockNode == nil, "window->node link") end
        if node:IsSplitNode() then assert(node.ChildNodes[1] ~= nil and node.Windows.Size == 0, "split node has two children and no windows") end
    end
    for _, n in ipairs(names) do
        local w = ImGui.FindWindowByName(n)
        if w and w.DockNode then assert(w.DockNode.Windows:find_index(w) ~= nil, "node contains window") end
    end
end
RunService.Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    -- scripted drag
    local x, y, down = (drag and drag.x or 5), (drag and drag.y or 5), false
    if not drag and frame % 45 == 0 then
        local w = ImGui.FindWindowByName(names[rnd(#names) + 1])
        if w and w.Active then
            local sx, sy
            if w.DockNode and w.DockNode.TabBar and w.DockNode.TabBar.Tabs.Size > 0 and rnd(2) == 0 then
                local tb = w.DockNode.TabBar; local t = tb.Tabs.Data[rnd(tb.Tabs.Size) + 1]
                sx, sy = tb.BarRect.Min.x + t.Offset + 4, tb.BarRect.Min.y + 8
            else sx, sy = w.Pos.x + 40, w.Pos.y + 8 end
            local mode = rnd(3)
            local tx, ty
            if mode == 0 then local o = ImGui.FindWindowByName(names[rnd(#names) + 1]); tx, ty = o.Pos.x + o.Size.x * (0.1 + rnd(80) / 100), o.Pos.y + o.Size.y * (0.1 + rnd(80) / 100)
            else tx, ty = 50 + rnd(1800), 50 + rnd(980) end
            drag = { sx = sx, sy = sy, tx = tx, ty = ty, start = frame, x = sx, y = sy }
            x, y = sx, sy
        end
    end
    if drag then
        local f = frame - drag.start
        local t = math.min(f / 14, 1)
        drag.x = drag.sx + (drag.tx - drag.sx) * t; drag.y = drag.sy + (drag.ty - drag.sy) * t
        x, y = drag.x, drag.y
        down = f >= 1 and f <= 24
        if f > 26 then drag = nil end
    end
    io:AddMousePosEvent(x, y)
    if down ~= last_down then io:AddMouseButtonEvent(0, down); last_down = down end
    ImGui.NewFrame()
    ImGui.DockSpaceOverViewport(0, nil, G.ImGuiDockNodeFlags.PassthruCentralNode)
    for i, n in ipairs(names) do
        ImGui.SetNextWindowPos(ImVec2(60 + i * 90, 60 + i * 50), G.ImGuiCond.FirstUseEver)
        ImGui.SetNextWindowSize(ImVec2(260, 180), G.ImGuiCond.FirstUseEver)
        if ImGui.Begin(n) then ImGui.Text("window " .. n) end
        ImGui.End()
    end
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame % 50 == 0 then check_tree() end
    if frame % 1000 == 0 then
        local nodes, docked = 0, 0
        for _ in pairs(ImGui.GetCurrentContext().DockContext.Nodes) do nodes += 1 end
        for _, n in ipairs(names) do local w = ImGui.FindWindowByName(n); if w and w.DockNode then docked += 1 end end
        print("frame", frame, "nodes", nodes, "docked windows", docked)
        local ini = ImGui.SaveIniSettingsToMemory()
    end
end)
