local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui = G.ImGui
ImGui.CreateContext(); G.ImGui_ImplRoblox.Init()
local f = 0
game:GetService("RunService").Stepped:Connect(function()
    f += 1
    G.ImGui_ImplRoblox.NewFrame(); ImGui.NewFrame()
    ImGui.Begin("SE"); ImGui.ShowStyleEditor(); ImGui.End()
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if f == 10 then print("SE OK") end
end)
