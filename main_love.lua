require("imgui")

local RunService = Instance.new("RunService")

local main_scale = 1.0
local clear_color = ImVec4(0.45, 0.55, 0.60, 1.00)
local f = 0.0
local counter = 0

ImGui.CreateContext()

local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard)
--io.ConfigFlags = bit32.bor(io.ConfigFlags, ImGuiConfigFlags.ViewportsEnable)

local style = ImGui.GetStyle()
style:ScaleAllSizes(main_scale)
style.FontScaleDpi = main_scale

ImGui_ImplLove.Init()

RunService.Stepped:Connect(function(dt)
    ImGui_ImplLove.NewFrame()
    ImGui.NewFrame()

    ImGui.ShowDemoWindow()

    do
        ImGui.Begin("Hello, world!")

        ImGui.Text("This is some useful text.")
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
    return ImGui.Render()
end)

RunService.PreAnimation:Connect(function()
    ImGui_ImplLove.RenderDrawData(ImGui.GetDrawData())

    if bit32.band(io.ConfigFlags, ImGuiConfigFlags.ViewportsEnable) ~= 0 then
        ImGui.UpdatePlatformWindows()
        ImGui.RenderPlatformWindowsDefault()
    end
end)

function love.keypressed(k) ImGui_ImplLove.KeyPressed(k) end
function love.keyreleased(k) ImGui_ImplLove.KeyReleased(k) end
function love.mousepressed(x, y, b) ImGui_ImplLove.MousePressed(x, y, b) end
function love.mousereleased(x, y, b) ImGui_ImplLove.MouseReleased(x, y, b) end
function love.wheelmoved(x, y) ImGui_ImplLove.WheelMoved(x, y) end
function love.textinput(t) ImGui_ImplLove.TextInput(t) end
function love.mousemoved(x, y) ImGui_ImplLove.MouseMoved(x, y) end
