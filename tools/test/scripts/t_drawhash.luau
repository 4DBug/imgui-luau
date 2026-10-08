-- Prints one checksum of all draw data (vertices, indices, clip rects) per run, with scripted mouse input.
-- Use to prove an internal rewrite renders identically: run before/after with the same --open-only and compare.
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui = G.ImGui
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
local io = ImGui.GetIO()
local frame, h = 0, 0
local function mix(v) h = (h * 31 + math.floor(v * 64 + 0.5)) % 2147483647 end
game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    io:AddMousePosEvent(100 + (frame * 37) % 500, 60 + (frame * 53) % 600)
    if frame % 7 == 0 then io:AddMouseButtonEvent(0, frame % 14 == 0) end
    if frame % 11 == 0 then io:AddMouseWheelEvent(0, -1) end
    ImGui.NewFrame()
    ImGui.ShowDemoWindow(true)
    ImGui.Render()
    for _, dl in ImGui.GetDrawData().CmdLists:iter() do
        local vd, id = dl.VtxBuffer.Data, dl.IdxBuffer.Data
        for i = 1, dl.VtxBuffer.Size do local v = vd[i]; mix(v[1].x); mix(v[1].y); mix(v[2].x * 4096); mix(v[2].y * 4096); mix(v[3] / 64) end
        for i = 1, dl.IdxBuffer.Size do mix(id[i]) end
        for _, c in dl.CmdBuffer:iter() do mix(c.ClipRect.x); mix(c.ClipRect.y); mix(c.ClipRect.z); mix(c.ClipRect.w); mix(c.ElemCount) end
    end
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == ARG_FRAMES - 1 then print("DRAWHASH", h) end
end)
