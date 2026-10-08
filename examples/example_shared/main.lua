-- LÖVE launcher for app.lua:  python3 tools/bundle.py --target love  then  love examples/example_shared
local ROOT = love.filesystem.getSource() .. "/../../"   -- repo root (build/, fonts/)
local function load_bundle()
    local f = assert(io.open(ROOT .. "build/imgui_love.lua", "rb"), "run: python3 tools/bundle.py --target love")
    local src = f:read("*a"); f:close()
    return assert(loadstring(src, "@imgui_love.lua"))()
end

local G, ImGui, App

function love.load()
    G = load_bundle()
    ImGui = G.ImGui
    ImGui.CreateContext()
    local io = ImGui.GetIO()
    io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.NavEnableKeyboard, G.ImGuiConfigFlags.DockingEnable)
    io.IniFilename = nil
    G.ImGui_ImplLove.Init({ root = ROOT })
    App = love.filesystem.load("app.lua")()(G)
    App.Platform = "LÖVE"
end

function love.update(dt)
    G.ImGui_ImplLove.NewFrame()
    ImGui.NewFrame()
    App.Frame()
    ImGui.Render()
end

function love.draw()
    local c = App.ClearColor
    love.graphics.clear(c.x, c.y, c.z, 1)
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
