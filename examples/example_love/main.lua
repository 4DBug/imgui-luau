-- Dear ImGui on LÖVE:  python3 tools/bundle.py --target love  then  love examples/example_love
local ROOT = love.filesystem.getSource() .. "/../../"   -- repo root (build/, fonts/)
local f = assert(io.open(ROOT .. "build/imgui_love.lua", "rb"), "run: python3 tools/bundle.py --target love")
local G = assert(loadstring(f:read("*a"), "@imgui_love.lua"))(); f:close()
local ImGui, ImVec4 = G.ImGui, G.ImVec4

local clear_color = ImVec4(0.45, 0.55, 0.60, 1.00)
local show_demo_window, show_another_window = true, false
local value, counter = 0.0, 0

function love.load()
    ImGui.CreateContext()
    local io = ImGui.GetIO()
    io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.NavEnableKeyboard, G.ImGuiConfigFlags.DockingEnable)
    io.IniFilename = nil
    G.ImGui_ImplLove.Init({ root = ROOT })
    io.Fonts:AddFontDefault()
    io.Fonts:AddFontFromFileTTF("fonts/Roboto-Medium.ttf", 16.0)
end

function love.update(dt)
    G.ImGui_ImplLove.NewFrame()
    ImGui.NewFrame()

    if show_demo_window then show_demo_window = ImGui.ShowDemoWindow(show_demo_window) end

    ImGui.Begin("Hello, world!")
    ImGui.Text("This is some useful text.")
    local _
    _, show_demo_window = ImGui.Checkbox("Demo Window", show_demo_window)
    _, show_another_window = ImGui.Checkbox("Another Window", show_another_window)
    value = ImGui.SliderFloat("float", value, 0.0, 1.0)
    ImGui.ColorEdit3("clear color", clear_color)
    if ImGui.Button("Button") then counter = counter + 1 end
    ImGui.SameLine(); ImGui.Text("counter = %d", counter)
    local io = ImGui.GetIO()
    ImGui.Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / io.Framerate, io.Framerate)
    ImGui.End()

    if show_another_window then
        show_another_window = ImGui.Begin("Another Window", show_another_window)
        ImGui.Text("Hello from another window!")
        if ImGui.Button("Close Me") then show_another_window = false end
        ImGui.End()
    end

    ImGui.Render()
end

function love.draw()
    love.graphics.clear(clear_color.x, clear_color.y, clear_color.z, 1)
    G.ImGui_ImplLove.RenderDrawData(ImGui.GetDrawData())
end

function love.mousemoved(x, y) G.ImGui_ImplLove.MouseMoved(x, y) end
function love.mousepressed(x, y, b) G.ImGui_ImplLove.MousePressed(x, y, b) end
function love.mousereleased(x, y, b) G.ImGui_ImplLove.MouseReleased(x, y, b) end
function love.wheelmoved(x, y) G.ImGui_ImplLove.WheelMoved(x, y) end
function love.keypressed(k) G.ImGui_ImplLove.KeyPressed(k) end
function love.keyreleased(k) G.ImGui_ImplLove.KeyReleased(k) end
function love.textinput(t) G.ImGui_ImplLove.TextInput(t) end
function love.focus(f) G.ImGui_ImplLove.Focus(f) end
