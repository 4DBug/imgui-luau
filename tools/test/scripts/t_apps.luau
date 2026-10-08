-- Opens every demo example app / tool window. Run with --open and random input.
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui = G.ImGui
ImGui.CreateContext()
local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.DockingEnable)
G.ImGui_ImplRoblox.Init()
local names = { "ShowExampleAppConsole", "ShowExampleAppLog", "ShowExampleAppLayout", "ShowExampleAppPropertyEditor", "ShowExampleAppLongText",
    "ShowExampleAppAutoResize", "ShowExampleAppConstrainedResize", "ShowExampleAppSimpleOverlay", "ShowExampleAppWindowTitles",
    "ShowExampleAppCustomRendering", "ShowExampleAppDocuments", "ShowExampleAppDockSpace", "ShowExampleAppFullscreen", "ShowExampleAppAssetsBrowser", "ShowExampleAppMainMenuBar" }
local tools = { "ShowMetricsWindow", "ShowDebugLogWindow", "ShowIDStackToolWindow", "ShowAboutWindow" }
local open = {}
local frame = 0
game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame(); ImGui.NewFrame()
    for _, n in ipairs(names) do
        local fn = G[n]
        if fn then if open[n] == nil then open[n] = true end; if open[n] then open[n] = fn(open[n]) end
        elseif frame == 1 then print("missing", n) end
    end
    for _, n in ipairs(tools) do
        if ImGui[n] then if open[n] == nil then open[n] = true end; if open[n] ~= false then open[n] = ImGui[n](open[n]) end
        elseif frame == 1 then print("missing", n) end
    end
    if ImGui.Begin("Fonts") then if ImGui.ShowFontAtlas then ImGui.ShowFontAtlas(io.Fonts) end end; ImGui.End()
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 50 then print("APPS OK") end
end)
