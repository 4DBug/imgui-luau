local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.DockingEnable)
G.ImGui_ImplRoblox.Init()
local frame, last_down, host0 = 0, false, nil
local function lerp(a, b, t) return a + (b - a) * t end
local function script(f)
    if f < 6 then return 600, 108, false end
    if f == 6 then return 600, 108, true end
    if f <= 20 then local t = (f - 6) / 14 return lerp(600, 250, t), lerp(108, 190, t), true end
    if f <= 27 then return 250, 190, true end
    if f <= 40 then return 250, 190, false end
    -- now grab empty space of the shared tab bar (right of the tabs) and move
    if f == 41 then return 380, 108, false end
    if f == 42 then return 380, 108, true end
    if f <= 56 then local t = (f - 42) / 14 return lerp(380, 600, t), lerp(108, 300, t), true end
    return 600, 300, false
end
RunService.Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    local x, y, down = script(frame)
    io:AddMousePosEvent(x, y)
    if down ~= last_down then io:AddMouseButtonEvent(0, down); last_down = down end
    ImGui.NewFrame()
    for i, n in ipairs({"A", "B"}) do
        ImGui.SetNextWindowPos(ImVec2(100 + (i - 1) * 400, 100), G.ImGuiCond.FirstUseEver)
        ImGui.SetNextWindowSize(ImVec2(300, 200), G.ImGuiCond.FirstUseEver)
        if ImGui.Begin(n) then ImGui.Text("window " .. n) end
        ImGui.End()
    end
    local a = ImGui.FindWindowByName("A")
    if frame == 40 then
        assert(a.DockNode and a.DockNode.Windows.Size == 2, "docked")
        host0 = {Pos = {x = a.DockNode.HostWindow.Pos.x, y = a.DockNode.HostWindow.Pos.y}}
        print("host before", host0.Pos.x, host0.Pos.y)
    end
    if frame == 70 then
        local h = a.DockNode.HostWindow
        print("host after", h.Pos.x, h.Pos.y)
        assert(math.abs(h.Pos.x - host0.Pos.x) > 100 or math.abs(h.Pos.y - host0.Pos.y) > 50, "dock host must move")
        -- background: host draw list must contain a filled rect covering the node body
    end
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 70 then
        local want = ImGui.GetColorU32(G.ImGuiCol.WindowBg)
        local found = false
        for _, l in ImGui.GetDrawData().CmdLists:iter() do
            for i = 1, l.VtxBuffer.Size do if G.ImDrawVtx_Col(l.VtxBuffer.Buf, i) == want then found = true break end end
        end
        assert(found, "docked windows must draw a WindowBg background")
        print("MOVE OK")
    end
end)
