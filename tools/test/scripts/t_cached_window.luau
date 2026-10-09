-- SetNextWindowCached: the same scripted scenario runs twice, window "Win##A" uncached then "Win##B" cached.
-- Every frame the window's draw list must hash identically in both phases, while B's body runs far less often.
-- run: python3 tools/test/run.py --main tools/test/scripts/t_cached_window.luau --frames 130 --quiet --roblox
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
local io = ImGui.GetIO()
local P = 60 -- frames per phase
local frame, hashes, runs = 0, {}, { A = 0, B = 0 }

local function hash(dl)
    local h = 0
    local function mix(v) h = (h * 31 + math.floor(v * 64 + 0.5)) % 2147483647 end
    local vb, id = dl.VtxBuffer.Buf, dl.IdxBuffer.Data
    for i = 1, dl.VtxBuffer.Size do local o = (i - 1) * 36; mix(buffer.readf64(vb, o)); mix(buffer.readf64(vb, o + 8)); mix(buffer.readf64(vb, o + 16) * 4096); mix(buffer.readf64(vb, o + 24) * 4096); mix(buffer.readu32(vb, o + 32) / 64) end
    for i = 1, dl.IdxBuffer.Size do mix(id[i]) end
    for _, c in dl.CmdBuffer:iter() do mix(c.ClipRect.x); mix(c.ClipRect.y); mix(c.ClipRect.z); mix(c.ClipRect.w); mix(c.ElemCount) end
    return h
end

game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    if frame > 2 * P then return end
    local phase = frame <= P and "A" or "B"
    local t = (frame - 1) % P + 1 -- frame within the phase
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    -- mouse: away, over the button (hover highlight), away again
    if t >= 20 and t < 26 then io:AddMousePosEvent(60, 75) else io:AddMousePosEvent(700, 500) end
    local key = math.floor(t / 15) -- data version: changes at t = 15, 30, 45
    ImGui.NewFrame()
    if t == 3 then ImGui.SetWindowFocus(nil) end -- focused -> unfocused title bar must not stay stale
    if t == 1 then ImGui.SetNextWindowFocus() end
    ImGui.SetNextWindowPos(ImVec2(20, 20), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(220, 140), G.ImGuiCond.Always)
    if phase == "B" then ImGui.SetNextWindowCached(key) end
    local _, visible = ImGui.Begin("Win##" .. phase)
    if visible then
        runs[phase] += 1
        ImGui.Button("Button")
        ImGui.Text("value %d", key)
        ImGui.SliderFloat("slider", key * 0.1, 0, 1)
    end
    ImGui.End()
    ImGui.Render()
    local h = hash(ImGui.FindWindowByName("Win##" .. phase).DrawList)
    if phase == "A" then hashes[t] = h
    elseif h ~= hashes[t] then error(("frame %d: cached draw list differs from uncached"):format(t)) end
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 2 * P then
        print(("runs: uncached %d, cached %d"):format(runs.A, runs.B))
        assert(runs.A == P, "uncached window must run every frame")
        assert(runs.B < P / 3, "cached window ran too often")
        print("CACHED OK")
    end
end)
