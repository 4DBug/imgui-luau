-- LocalScript. Build the library first: `python3 tools/bundle.py` -> build/ImGui.luau (see default.project.json)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local G = require(ReplicatedStorage:WaitForChild("ImGui"))

local ImGui, ImVec4, ImGuiConfigFlags, ImGui_ImplRoblox = G.ImGui, G.ImVec4, G.ImGuiConfigFlags, G.ImGui_ImplRoblox

local main_scale = 1.0
-- Roblox UI points are multiplied by the OS display scale (e.g. 150%), which makes imgui look large.
-- Set this to your display scale to render imgui at physical-pixel resolution (same size as a desktop imgui app).
local render_scale = 1.0
local clear_color = ImVec4(0.45, 0.55, 0.60, 1.00)
local show_demo_window = true
local show_another_window = false
local f = 0.0
local counter = 0

ImGui.CreateContext()

local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard, ImGuiConfigFlags.DockingEnable)

local style = ImGui.GetStyle()
style:ScaleAllSizes(main_scale)
style.FontScaleDpi = main_scale

ImGui_ImplRoblox.Init(nil, render_scale)

RunService.Stepped:Connect(function()
    ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()

    -- Dockspace covering the whole screen; the centre stays transparent so the game shows through
    ImGui.DockSpaceOverViewport(0, nil, G.ImGuiDockNodeFlags.PassthruCentralNode)

    if show_demo_window then
        ImGui.ShowDemoWindow()
    end

    do
        ImGui.Begin("Hello, world!")

        ImGui.Text("This is some useful text.")
        local _
        _, show_demo_window = ImGui.Checkbox("Demo Window", show_demo_window)
        _, show_another_window = ImGui.Checkbox("Another Window", show_another_window)

        f = ImGui.SliderFloat("float", f, 0.0, 1.0)
        ImGui.ColorEdit3("clear color", clear_color)

        if ImGui.Button("Button") then
            counter = counter + 1
        end
        ImGui.SameLine()
        ImGui.Text("counter = %d", counter)

        ImGui.Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / io.Framerate, io.Framerate)

        ImGui.End()
    end

    if show_another_window then
        show_another_window = ImGui.Begin("Another Window", show_another_window)

        ImGui.Text("Hello from another window!")
        if ImGui.Button("Close Me") then
            show_another_window = false
        end

        ImGui.End()
    end

    ImGui.EndFrame()
    ImGui.Render()
    ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
