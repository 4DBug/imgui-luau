-- Checksum of draw data + layout of Style Editor > Colors while scrolling its list (fast-path equivalence check)
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
local io = ImGui.GetIO()
local realBTI = ImGui.BeginTabItem
ImGui.BeginTabItem = function(label, p_open, flags)
    if label == "Colors" then flags = bit32.bor(flags or 0, G.ImGuiTabItemFlags.SetSelected) end
    return realBTI(label, p_open, flags)
end
local frame, h = 0, 0
local function mix(v) h = (h * 31 + math.floor(v * 64 + 0.5)) % 2147483647 end
game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    io:AddMousePosEvent(200, 400 + (frame % 5) * 13)
    if frame > 5 then io:AddMouseWheelEvent(0, (frame % 60 < 35) and -1 or 1) end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(20, 20)); ImGui.SetNextWindowSize(ImVec2(550, 700))
    ImGui.Begin("Style Editor"); ImGui.ShowStyleEditor(); ImGui.End()
    ImGui.Render()
    for _, dl in ImGui.GetDrawData().CmdLists:iter() do
        local vb, id = dl.VtxBuffer.Buf, dl.IdxBuffer.Data
        for i = 1, dl.VtxBuffer.Size do local o = (i - 1) * 36; mix(buffer.readf64(vb, o)); mix(buffer.readf64(vb, o + 8)); mix(buffer.readu32(vb, o + 32) / 64) end
        for i = 1, dl.IdxBuffer.Size do mix(id[i]) end
    end
    for _, w in ipairs(ImGui.GetCurrentContext().Windows.Data) do mix(w.ContentSize.x); mix(w.ContentSize.y); mix(w.Scroll.y); mix(w.ScrollMax.y) end
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == ARG_FRAMES - 1 then print("COLORSHASH", h) end
end)
