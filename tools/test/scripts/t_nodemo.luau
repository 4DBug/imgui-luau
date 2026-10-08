-- Library without imgui_demo.lua: run with NO_DEMO=1 (bundle --no-demo). Window + Metrics/Debug Log/ID Stack tools must work.
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui = G.ImGui
ImGui.CreateContext(); G.ImGui_ImplRoblox.Init()
assert(ImGui.ShowDemoWindow == nil, "demo was bundled")
local f = 0
game:GetService("RunService").Stepped:Connect(function()
    f += 1
    G.ImGui_ImplRoblox.NewFrame(); ImGui.NewFrame()
    ImGui.Begin("W"); ImGui.Text("hi"); ImGui.Button("b"); ImGui.End()
    ImGui.ShowMetricsWindow(); ImGui.ShowDebugLogWindow(); ImGui.ShowIDStackToolWindow()
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if f == 20 then print("NODEMO OK") end
end)
