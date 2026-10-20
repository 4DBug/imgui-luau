-- Library CPU cost of the Studio bench's scene (demo window + "Stress" window: 20 buttons/sliders, a 60x6 table,
-- 80 TextWrapped lines), mouse sweeping over it. Prints the median ImGui.NewFrame..Render time (real clock, backend
-- excluded) and a checksum of the draw data. Use with --roblox (only @native functions native, like Studio); the machine
-- is often busy, so compare runs interleaved and look at the lower quartile (lowq-mean).
--   RUN_FLAGS="ARG_MODE='scroll'" python3 tools/test/run.py --main tools/test/scripts/t_stress.luau --frames 800 --quiet --roblox
-- ARG_MODE: "hover" (default), "idle" (mouse outside, like the bench's idle), "scroll", "resize", "fonts".
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
local io = ImGui.GetIO()
local MODE = type(ARG_MODE) == "string" and ARG_MODE or "hover"
local clock = os.realclock or os.clock
local S = { fsize = 13, scroll = 0, pos = ImVec2(60, 60), size = ImVec2(520, 640), slider = 0.5, check = true }

local function StressWindow()
    ImGui.SetNextWindowPos(S.pos, G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(S.size, G.ImGuiCond.Always)
    ImGui.PushFont(nil, S.fsize)
    ImGui.Begin("Stress")
    ImGui.SetScrollY(S.scroll)
    for i = 1, 20 do
        if ImGui.Button("Button " .. i) then end
        ImGui.SameLine()
        S.slider = ImGui.SliderFloat("##s" .. i, S.slider, 0, 1)
    end
    _, S.check = ImGui.Checkbox("Checkbox", S.check)
    if ImGui.BeginTable("tbl", 6, bit32.bor(G.ImGuiTableFlags.Borders, G.ImGuiTableFlags.RowBg)) then
        for r = 1, 60 do
            ImGui.TableNextRow()
            for c = 1, 6 do ImGui.TableNextColumn(); ImGui.Text("r%d c%d", r, c) end
        end
        ImGui.EndTable()
    end
    for i = 1, 80 do ImGui.TextWrapped("Line %d: the quick brown fox jumps over the lazy dog, again and again and again.", i) end
    ImGui.PopFont()
    ImGui.End()
end

local frame, h, times = 0, 0, {}
local function mix(v) h = (h * 31 + math.floor(v * 64 + 0.5)) % 2147483647 end
game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    if MODE == "idle" then io:AddMousePosEvent(-1000, -1000) else io:AddMousePosEvent(70 + (frame * 7) % 480, 80 + (frame * 13) % 560) end
    if MODE == "scroll" then S.scroll = (S.scroll + 6) % 2400 end
    if MODE == "resize" then S.size = ImVec2(420 + (frame * 3) % 300, 500 + (frame * 2) % 200) end
    if MODE == "fonts" then S.fsize = 12 + (frame * 0.25) % 40 end
    local t0 = clock()
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(620, 40), G.ImGuiCond.Once)
    ImGui.ShowDemoWindow()
    StressWindow()
    ImGui.Render()
    if frame > 20 then table.insert(times, clock() - t0) end
    for _, dl in ImGui.GetDrawData().CmdLists:iter() do
        local vb, id = dl.VtxBuffer.Buf, dl.IdxBuffer.Data
        for i = 1, dl.VtxBuffer.Size do local o = (i - 1) * 36; mix(buffer.readf64(vb, o)); mix(buffer.readf64(vb, o + 8)); mix(buffer.readf64(vb, o + 16) * 4096); mix(buffer.readf64(vb, o + 24) * 4096); mix(buffer.readu32(vb, o + 32) / 64) end
        for i = 1, dl.IdxBuffer.Size do mix(id[i]) end
        for _, c in dl.CmdBuffer:iter() do mix(c.ClipRect.x); mix(c.ClipRect.y); mix(c.ClipRect.z); mix(c.ClipRect.w); mix(c.ElemCount) end
    end
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == ARG_FRAMES - 1 then
        table.sort(times)
        local lo = 0
        for i = 1, #times // 4 do lo += times[i] end
        print(string.format("STRESS %s med %.3f ms p25 %.3f ms lowq-mean %.3f ms", MODE, times[#times // 2 + 1] * 1000, times[#times // 4] * 1000, lo / (#times // 4) * 1000))
        print("STRESSHASH", h)
    end
end)
