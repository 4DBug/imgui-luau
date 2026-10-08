-- Clipper, TextFilter, Combo, ListBox, TreeNodeEx, MainMenuBar, error recovery
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
ImGui.GetIO().ConfigErrorRecoveryEnableAssert = false
ImGui.GetIO().ConfigErrorRecoveryEnableDebugLog = false
local frame = 0
local item, lb = 2, 1
local filter = G.ImGuiTextFilter("aa -bb")
assert(filter:PassFilter("xxaAyy") and not filter:PassFilter("aabb") and not filter:PassFilter("cc"), "filter")
local f2 = G.ImGuiTextFilter("x,y")
assert(f2:PassFilter("y") and f2:PassFilter("x") and not f2:PassFilter("z"), "filter or")
local seen = {}
RunService.Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()
    if ImGui.BeginMainMenuBar() then
        if ImGui.BeginMenu("File") then ImGui.MenuItem("Open"); ImGui.EndMenu() end
        ImGui.EndMainMenuBar()
    end
    ImGui.SetNextWindowPos(ImVec2(20, 40), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(400, 300), G.ImGuiCond.Always)
    ImGui.Begin("W")
    if frame == 3 then ImGui.OpenPopup("##combo_popup") end
    item = ImGui.Combo("combo", item, { "a", "b", "c", "d" })
    item = ImGui.Combo("combo0", item, "x\0y\0z\0")
    lb = ImGui.ListBox("lb", lb, { "one", "two", "three" })
    if ImGui.TreeNodeEx("node", G.ImGuiTreeNodeFlags.DefaultOpen) then
        if ImGui.TreeNode("ptr", "Fmt %d", 5) then ImGui.TreePop() end
        ImGui.TreePop()
    end
    ImGui.TreePush("x"); ImGui.TreePop()
    local clipper = G.ImGuiListClipper()
    clipper:Begin(10000)
    local n = 0
    while clipper:Step() do
        for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do ImGui.Text("line %d", i); n += 1 end
    end
    seen[frame] = n
    -- error recovery: missing PopID / TreePop / End
    ImGui.PushID("leak")
    ImGui.Begin("Leaky")
    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 5 then
        assert(seen[5] > 0 and seen[5] < 40, "clipper visible count " .. tostring(seen[5]))
        print("clipper items", seen[5], "WIDGETS OK")
    end
end)
