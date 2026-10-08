-- Scrolls the demo with everything open (run with --open) and asserts no style value changes
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui = G.ImGui
ImGui.CreateContext()
ImGui.GetIO().ConfigFlags = bit32.bor(ImGui.GetIO().ConfigFlags, G.ImGuiConfigFlags.NavEnableKeyboard, G.ImGuiConfigFlags.DockingEnable)
G.ImGui_ImplRoblox.Init()
local style = ImGui.GetStyle()
local function snap()
    local t = {}
    for k, v in pairs(style) do
        if type(v) == "number" then t[k] = tostring(v)
        elseif type(v) == "table" and getmetatable(v) ~= nil and v.x ~= nil then t[k] = v.x .. "," .. v.y; t[k .. "#id"] = v end
    end
    return t
end
local ref
local frame = 0
RunService.Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    local w0 = ImGui.FindWindowByName("Dear ImGui Demo")
    if w0 and frame > 2 then
        local io = ImGui.GetIO()
        -- sweep the mouse over the window so hover-only paths (tooltips etc.) run
        io:AddMousePosEvent(w0.Pos.x + 30 + (frame * 37) % math.max(1, w0.Size.x - 60), w0.Pos.y + 40 + (frame * 53) % math.max(1, w0.Size.y - 80))
        io:AddMouseWheelEvent(0, -1)
    end
    ImGui.NewFrame()
    ImGui.DockSpaceOverViewport(0, nil, G.ImGuiDockNodeFlags.PassthruCentralNode)
    ImGui.ShowDemoWindow(true)
    ImGui.Begin("Hello, world!"); ImGui.Checkbox("Demo Window", true); ImGui.SliderFloat("float", 0, 0, 1); ImGui.Button("Button"); ImGui.End()
    ImGui.EndFrame()
    local w = ImGui.FindWindowByName("Dear ImGui Demo")

    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 2 then ref = snap() end
    if frame > 2 and ref then
        for k, v in pairs(snap()) do
            if not rawequal(ref[k], v) then error(("style.%s changed %s -> %s at frame %d"):format(k, tostring(ref[k]), tostring(v), frame)) end
        end
    end
    if frame == ARG_FRAMES then print("STYLE OK") end
end)
