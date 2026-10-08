local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
local opened = {true, true, true, true, true, true, true, true}
local frame = 0
RunService.Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(0, 0), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(300, 300), G.ImGuiCond.Always)
    ImGui.Begin("Tabs")
    local flags = bit32.bor(G.ImGuiTabBarFlags.Reorderable, G.ImGuiTabBarFlags.TabListPopupButton, G.ImGuiTabBarFlags.FittingPolicyScroll, G.ImGuiTabBarFlags.AutoSelectNewTabs)
    if ImGui.BeginTabBar("bar", flags) then
        if ImGui.TabItemButton("+", G.ImGuiTabItemFlags.Trailing) then end
        for i = 1, #opened do
            local vis
            vis, opened[i] = ImGui.BeginTabItem("Tab number " .. i, opened[i], (i == 3) and G.ImGuiTabItemFlags.UnsavedDocument or 0)
            if vis then ImGui.Text("Contents of tab " .. i); ImGui.EndTabItem() end
        end
        ImGui.EndTabBar()
    end
    if frame == 50 then local tb = ImGui.GetCurrentContext().TabBars:GetByIndex(0); print("tabs", tb.Tabs.Size, "selected", tb.SelectedTabId ~= 0, "scrollbtn", tb.ScrollButtonEnabled) end
    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
