-- Parallel raster executor (ImGui_ImplRoblox.EnableParallel) vs the inline backend, pixel for pixel. Two contexts draw the same
-- benchmark scenarios every frame: A inline (Config.Inline), B through the executor in Sync mode (the mock has no Actors: the "workers"
-- run inline, same code). Frames cycle through: dispatch window open (batches pending until Finish, like
-- PreSimulation -> PostSimulation), open with SyncDrop (half the worker results lost -> Finish falls back), and closed
-- (late RenderDrawData: rasterized + uploaded at once). The composites of A and B must match at every checkpoint.
-- Prints the executor's main-thread pack cost per frame next to A's inline raster + upload cost.
-- run: python3 tools/test/run.py --main tools/test/scripts/t_parallel.luau --frames 900 --quiet --roblox
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local Impl = G.ImGui_ImplRoblox
local W, H = 1280, 760
local N = ARG_N or 120 -- frames per scenario

local function composite(gui)
    local screen = buffer.create(W * H * 3)
    local function walk(inst, ox, oy, kx0, ky0, kx1, ky1)
        local kids = inst:GetChildren()
        table.sort(kids, function(a, b) return (a.ZIndex or 1) < (b.ZIndex or 1) end)
        for _, c in ipairs(kids) do
            if c.Visible ~= false then
                local x, y = ox + (c.Position and c.Position.X or 0), oy + (c.Position and c.Position.Y or 0)
                local cx0, cy0, cx1, cy1 = kx0, ky0, kx1, ky1
                if c.ClipsDescendants then
                    cx0, cy0 = math.max(cx0, x), math.max(cy0, y)
                    cx1, cy1 = math.min(cx1, x + c.Size.X), math.min(cy1, y + c.Size.Y)
                end
                if c.ClassName == "ImageLabel" then
                    local px, sz = c.ImageContent.Object.Pixels, c.ImageContent.Object.Size.X
                    for ty = math.max(0, cy0 - y), math.min(sz, cy1 - y) - 1 do
                        local sy = y + ty
                        for tx = math.max(0, cx0 - x), math.min(sz, cx1 - x) - 1 do
                            local o = (ty * sz + tx) * 4
                            local a = buffer.readu8(px, o + 3)
                            if a > 0 then
                                local d = (sy * W + x + tx) * 3
                                local fa = a / 255
                                for ch = 0, 2 do
                                    buffer.writeu8(screen, d + ch, math.floor(buffer.readu8(px, o + ch) * fa + buffer.readu8(screen, d + ch) * (1 - fa) + 0.5))
                                end
                            end
                        end
                    end
                end
                walk(c, x, y, cx0, cy0, cx1, cy1)
            end
        end
    end
    walk(gui, 0, 0, 0, 0, W, H)
    local h = 0
    for i = 0, W * H * 3 - 4, 4 do h = (h * 31 + buffer.readu32(screen, i)) % 2147483647 end
    return h
end

local plot = table.create(120, 0)
local SCEN = {
    { "resize", function(f)
        local s = 520 + ((f % 80) < 40 and (f % 40) * 7 or (40 - f % 40) * 7)
        ImGui.ShowDemoWindow()
        ImGui.SetWindowPos("Dear ImGui Demo", ImVec2(30, 20)); ImGui.SetWindowSize("Dear ImGui Demo", ImVec2(s, s * 0.8 + 60))
    end },
    { "assets", function(f)
        ImGui.SetNextWindowPos(ImVec2(20, 20), G.ImGuiCond.Always)
        G.ShowExampleAppAssetsBrowser(true)
        local w = ImGui.FindWindowByName("Example: Assets Browser")
        if w and f > 2 then for _, c in ipairs(w.DC.ChildWindows.Data) do ImGui.SetScrollY(c, (f * 40) % 6000) end end
    end },
    { "list", function(f)
        ImGui.SetNextWindowPos(ImVec2(40, 30), G.ImGuiCond.Always); ImGui.SetNextWindowSize(ImVec2(560, 680), G.ImGuiCond.Always)
        ImGui.Begin("Long list")
        ImGui.SetScrollY(13 * (f <= 60 and f or 120 - f))
        local clipper = G.ImGuiListClipper()
        clipper:Begin(10000)
        while clipper:Step() do
            for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do ImGui.Text("%05d: The quick brown fox jumps over the lazy dog", i) end
        end
        ImGui.End()
    end },
    { "plots", function(f)
        for i = 1, 120 do plot[i] = math.sin((i + f) * 0.15) + 0.3 * math.sin((i * 3 + f) * 0.4) end
        ImGui.SetNextWindowPos(ImVec2(40, 30), G.ImGuiCond.Always); ImGui.SetNextWindowSize(ImVec2(620, 520), G.ImGuiCond.Always)
        ImGui.Begin("Plots")
        ImGui.PlotLines("Lines", plot, nil, 120, 0, nil, -1.5, 1.5, ImVec2(0, 160))
        ImGui.PlotHistogram("Histogram", plot, nil, 120, 0, nil, -1.5, 1.5, ImVec2(0, 160))
        ImGui.Text("frame %d", f)
        ImGui.End()
    end },
}

local ctx, gui = {}, {}
for i = 1, 2 do
    ctx[i] = ImGui.CreateContext()
    ImGui.SetCurrentContext(ctx[i])
    local parent = Instance.new("Folder")
    Impl.Init(parent)
    Impl.SetRenderRate(0)
    Impl.SetStageTiming(true)
    gui[i] = parent:FindFirstChild("ImGui")
end
Impl.EnableParallel({ Sync = true, Actors = 4 })
local C = Impl.GetParallelConfig()

local si, f, checks, bad = 1, 0, 0, 0
local pack, inline, flushes = {}, {}, { open = 0, drop = 0, closed = 0 }
local S = Impl.GetParallelStats()
local s0 = table.clone(S)
local kb = { 0, 0 } -- KB allocated in RenderDrawData (+ Finish for the executor context), per context
local function k_add(i, k0) local d = collectgarbage("count") - k0; if f > 5 and d > 0 then kb[i] += d end end
game:GetService("RunService").Stepped:Connect(function()
    local sc = SCEN[si]
    if not sc then return end
    f += 1
    local mode = f % 3 -- 0 closed, 1 open, 2 open + SyncDrop
    C.SyncDrop = mode == 2
    if mode ~= 0 then Impl.BeginParallelFrame() end
    flushes[mode == 0 and "closed" or mode == 1 and "open" or "drop"] += 1
    for i = 1, 2 do
        ImGui.SetCurrentContext(ctx[i])
        C.Inline = i == 1
        Impl.NewFrame()
        local io = ImGui.GetIO()
        io.DeltaTime = 1 / 60
        io:AddMousePosEvent(1270, 750)
        ImGui.NewFrame()
        sc[2](f)
        ImGui.Render()
        local fake = os.clock
        os.clock = os.realclock -- (mock: os.clock is frozen; real time for the stage / pack timers)
        local p0, k0 = S.Pack, collectgarbage("count")
        Impl.RenderDrawData(ImGui.GetDrawData())
        k_add(i, k0)
        os.clock = fake
        if f > 5 then
            if i == 1 then local st = Impl.GetStats().Frame; table.insert(inline, (st.Raster + st.Upload) * 1000)
            else table.insert(pack, (S.Pack - p0) * 1000) end
        end
    end
    local k0 = collectgarbage("count")
    Impl.FinishParallel()
    k_add(2, k0)
    if f % 10 == 0 or f == N then
        checks += 1
        local a, b = composite(gui[1]), composite(gui[2])
        if a ~= b then bad += 1; print("MISMATCH", sc[1], f, a, b) end
    end
    if f == N then
        local function stats(t)
            local s, m = 0, 0
            for _, v in t do s += v; m = math.max(m, v) end
            return s / math.max(#t, 1), m
        end
        local pm, px = stats(pack)
        local im, ix = stats(inline)
        print(string.format("PACK %-7s mean %.3f max %.3f ms/frame | inline raster+upload mean %.3f max %.3f ms/frame | tiles %.1f rects %.1f send %d KB/frame, tex resends %d (%d KB)",
            sc[1], pm, px, im, ix, (S.Tiles - s0.Tiles) / N, (S.Rects - s0.Rects) / N, (S.SendBytes - s0.SendBytes) / 1024 / N, S.TexSends - s0.TexSends, (S.TexBytes - s0.TexBytes) / 1024))
        print(string.format("ALLOC %-7s KB/frame inline %.1f executor %.1f (Sync: includes the inline worker raster)", sc[1], kb[1] / (N - 5), kb[2] / (N - 5)))
        kb = { 0, 0 }
        s0 = table.clone(S)
        pack, inline = {}, {}
        for i = 1, 2 do ImGui.SetCurrentContext(ctx[i]); Impl.SetRenderScale(2); Impl.SetRenderScale(1) end
        si += 1; f = 0
        Impl.EnableParallel({ Actors = si }) -- runtime re-Enable with a different actor count (pixels must still match)
        assert(C.Sync and Impl.GetParallelConfig() == C, "re-Enable kept Sync")
        if not SCEN[si] then
            print(string.format("STATS parallel flushes %d serial %d tiles %d fallbacks %d | frames open %d drop %d closed %d",
                S.ParallelFlushes, S.SerialFlushes, S.Tiles, S.Fallbacks, flushes.open, flushes.drop, flushes.closed))
            assert(S.ParallelFlushes > 0 and S.SerialFlushes > 0 and S.Fallbacks > 0, "a path was not exercised")
            if bad == 0 then print("PARALLEL OK " .. checks .. " checkpoints") else print("PARALLEL FAIL " .. bad .. "/" .. checks) end
        end
    end
end)
