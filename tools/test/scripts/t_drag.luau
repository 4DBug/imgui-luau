-- Benchmark: drags the demo window (real mouse drag on its title bar) and keeps a color picker window open.
-- Watch "render" ms and uploads/frame: with per-window layers, dragging should upload ~nothing.
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
local io = ImGui.GetIO()
local col = ImVec4(0.4, 0.7, 0.2, 0.5)
local frame = 0
local bx, by = 0, 0
local MODE = ARG_OPEN == true and "picker" or (type(ARG_OPEN) == "table" and "scroll" or "drag")
game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    if MODE == "drag" then
        local t = math.abs((frame % 200) - 100) -- triangle wave, smooth back and forth
        if frame == 5 then local w = ImGui.FindWindowByName("ImGui Sincerely Demo"); bx, by = w.Pos.x + 80, w.Pos.y + 8; io:AddMousePosEvent(bx, by) elseif frame == 6 then io:AddMouseButtonEvent(0, true)
        elseif frame > 6 then io:AddMousePosEvent(bx - t * 5, by + t * 2) end
    elseif MODE == "scroll" then
        local w = ImGui.FindWindowByName("ImGui Sincerely Demo"); if w then io:AddMousePosEvent(w.Pos.x + w.Size.x * 0.5, w.Pos.y + w.Size.y * 0.5) end
        io:AddMouseWheelEvent(0, (frame % 20 < 10) and -1 or 1)
    else
        io:AddMousePosEvent(60 + (frame * 7) % 200, 80 + (frame * 5) % 200)
        if frame == 6 then io:AddMouseButtonEvent(0, true) end
    end
    ImGui.NewFrame()
    if MODE ~= "picker" then
        if frame < 3 then ImGui.SetNextWindowPos(ImVec2(20, 20)); ImGui.SetNextWindowSize(ImVec2(500, 650)) end
        ImGui.ShowDemoWindow(true)
    else
        ImGui.SetNextWindowPos(ImVec2(20, 20)); ImGui.SetNextWindowSize(ImVec2(700, 700))
        ImGui.Begin("Pickers")
        ImGui.ColorPicker4("bar", col, G.ImGuiColorEditFlags.PickerHueBar)
        ImGui.ColorPicker4("wheel", col, G.ImGuiColorEditFlags.PickerHueWheel)
        ImGui.End()
    end
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == ARG_FRAMES - 1 and MODE == "drag" then
        local w = ImGui.FindWindowByName("ImGui Sincerely Demo")
        assert(w.Pos.y > 25, "window was not dragged")
        print("DRAG OK", w.Pos.x, w.Pos.y, w.Collapsed, ImGui.GetDrawData().TotalVtxCount)
    end
end)
