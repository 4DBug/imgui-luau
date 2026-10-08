-- LuaJIT twin of tools/test/scripts/t_drawhash.luau: same input, same checksum => compat shims behave like Luau.
-- usage: luajit tools/test/love/t_drawhash.lua <frames> [Widgets,Basic | all]
dofile("tools/test/love/mock_love.lua")
local G = dofile("build/imgui_love.lua")
local ImGui = G.ImGui
local FRAMES, OPEN = tonumber(arg[1] or 150), arg[2] or ""
local open = {}
for n in OPEN:gmatch("[^,]+") do open[n] = true end
for _, fname in ipairs({ "TreeNode", "CollapsingHeader" }) do
    local real = ImGui[fname]
    ImGui[fname] = function(label, ...)
        if open[label] or OPEN == "all" then ImGui.SetNextItemOpen(true, G.ImGuiCond.Always) end
        return real(label, ...)
    end
end
ImGui.CreateContext()
G.ImGui_ImplLove.Init({ root = "./" })
local io = ImGui.GetIO()
local h = 0
local function mix(v) h = (h * 31 + math.floor(v * 64 + 0.5)) % 2147483647 end
for frame = 1, FRAMES do
    love.timer.step(1 / 60)
    G.ImGui_ImplLove.NewFrame()
    io.DeltaTime = 1 / 60
    if frame == 1 then io:AddMousePosEvent(0, 0) end -- (the Roblox backend reports the initial mouse position)
    io:AddMousePosEvent(100 + (frame * 37) % 500, 60 + (frame * 53) % 600)
    if frame % 7 == 0 then io:AddMouseButtonEvent(0, frame % 14 == 0) end
    if frame % 11 == 0 then io:AddMouseWheelEvent(0, -1) end
    ImGui.NewFrame()
    ImGui.ShowDemoWindow(true)
    ImGui.Render()
    for _, dl in ImGui.GetDrawData().CmdLists:iter() do
        local vb, id = dl.VtxBuffer.Buf, dl.IdxBuffer.Data
        for i = 1, dl.VtxBuffer.Size do local o = (i - 1) * 36; mix(buffer.readf64(vb, o)); mix(buffer.readf64(vb, o + 8)); mix(buffer.readf64(vb, o + 16) * 4096); mix(buffer.readf64(vb, o + 24) * 4096); mix(buffer.readu32(vb, o + 32) / 64) end
        for i = 1, dl.IdxBuffer.Size do mix(id[i]) end
        for _, c in dl.CmdBuffer:iter() do mix(c.ClipRect.x); mix(c.ClipRect.y); mix(c.ClipRect.z); mix(c.ClipRect.w); mix(c.ElemCount) end
    end
    G.ImGui_ImplLove.RenderDrawData(ImGui.GetDrawData())
    if frame == FRAMES - 1 then print("DRAWHASH", string.format("%d", h)) end
end
print("draws", MOCK_DRAWS)
