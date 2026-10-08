-- Roblox launcher for app.lua (sync with examples/example_shared/default.project.json).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui = G.ImGui

ImGui.CreateContext()
local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.NavEnableKeyboard, G.ImGuiConfigFlags.DockingEnable)
G.ImGui_ImplRoblox.Init()

local App = require(ReplicatedStorage:WaitForChild("SharedApp"))(G)
App.Platform = "Roblox"

RunService.Stepped:Connect(function()
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()
    App.Frame()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
