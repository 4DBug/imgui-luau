local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
local frame = 0
local logged = nil
RunService.Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(20, 20), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(400, 300), G.ImGuiCond.Always)
    ImGui.Begin("Popups")
    if frame == 3 then ImGui.OpenPopup("Delete?") end
    if frame == 5 then ImGui.LogToClipboard() end
    ImGui.Text("Some text to log")
    if frame == 5 then ImGui.LogFinish(); logged = ImGui.GetClipboardText() end
    ImGui.BeginChild("child", ImVec2(0, 100), G.ImGuiChildFlags.Borders)
    for i = 1, 20 do ImGui.Text("child line " .. i) end
    ImGui.EndChild()
    if ImGui.BeginPopupContextWindow() then ImGui.Text("ctx"); ImGui.EndPopup() end
    if ImGui.BeginPopupModal("Delete?", nil, G.ImGuiWindowFlags.AlwaysAutoResize) then
        ImGui.Text("All those beautiful files will be deleted.\nThis operation cannot be undone!")
        ImGui.Separator()
        if ImGui.Button("OK", ImVec2(120, 0)) then ImGui.CloseCurrentPopup() end
        ImGui.EndPopup()
    end
    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 6 then
        print("LOG:", logged)
        local ini = ImGui.SaveIniSettingsToMemory()
        print("INI:", ini)
        ImGui.LoadIniSettingsFromMemory(ini)
        assert(ImGui.SaveIniSettingsToMemory() == ini, "ini round trip")
        print("INI round trip ok")
    end
end)
