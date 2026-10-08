local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.DockingEnable)
G.ImGui_ImplRoblox.Init()
local frame = 0
RunService.Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    if frame == 5 then io:AddMousePosEvent(io.DisplaySize.x * 0.5, io.DisplaySize.y * 0.5) end
    if frame == 10 then io:AddMousePosEvent(60, 60) end
    ImGui.NewFrame()
    ImGui.DockSpaceOverViewport(0, nil, G.ImGuiDockNodeFlags.PassthruCentralNode)
    ImGui.SetNextWindowPos(ImVec2(20, 20)); ImGui.SetNextWindowSize(ImVec2(200, 200))
    ImGui.Begin("W"); ImGui.Text("hi"); ImGui.End()
    ImGui.Render()
    if frame == 8 then assert(not io.WantCaptureMouse, "central node must not capture") end
    if frame == 13 then assert(io.WantCaptureMouse, "window must capture"); print("PASSTHRU OK") end
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
