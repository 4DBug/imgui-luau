-- Headless twin of the Studio bench's round-3 scenes (tools/test/bench_scenes.luau): plots, colorpicker, implot,
-- demo_all. Prints the median / lower-quartile library time (NewFrame..Render) and backend time (RenderDrawData), and a
-- checksum of the draw data (must not change with internal optimizations).
--   RUN_FLAGS="ARG_MODE='plots'" python3 tools/test/run.py --main tools/test/scripts/t_stress2.luau --frames 400 --quiet --roblox \
--       --module BenchScenes=tools/test/bench_scenes.luau [--module ImPlot=../implot-luau/ImPlot.lua]
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImGui = G.ImGui
local ImPlot = RS:FindFirstChild("ImPlot") and require(RS.ImPlot)(G)
ImGui.CreateContext()
if ImPlot then ImPlot.CreateContext() end
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
local io = ImGui.GetIO()
local MODE = type(ARG_MODE) == "string" and ARG_MODE or "plots"
local scene = require(RS:WaitForChild("BenchScenes"))(G, ImPlot)[MODE]
assert(scene, "unknown or unavailable scene " .. MODE)
local clock = os.realclock or os.clock

local frame, h, lib, be = 0, 0, {}, {}
local function mix(v) h = (h * 31 + math.floor(v * 64 + 0.5)) % 2147483647 end
local function stats(t)
    table.sort(t)
    local lo = 0
    for i = 1, #t // 4 do lo += t[i] end
    return t[#t // 2 + 1] * 1000, lo / (#t // 4) * 1000
end
game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    io:AddMousePosEvent(-1000, -1000)
    local t0 = clock()
    ImGui.NewFrame()
    scene(frame)
    ImGui.Render()
    local t1 = clock()
    local dd = ImGui.GetDrawData()
    for _, dl in dd.CmdLists:iter() do
        local vb, id = dl.VtxBuffer.Buf, dl.IdxBuffer.Data
        for i = 1, dl.VtxBuffer.Size do local o = (i - 1) * 36; mix(buffer.readf64(vb, o)); mix(buffer.readf64(vb, o + 8)); mix(buffer.readf64(vb, o + 16) * 4096); mix(buffer.readf64(vb, o + 24) * 4096); mix(buffer.readu32(vb, o + 32) / 64) end
        for i = 1, dl.IdxBuffer.Size do mix(id[i]) end
        for _, c in dl.CmdBuffer:iter() do mix(c.ClipRect.x); mix(c.ClipRect.y); mix(c.ClipRect.z); mix(c.ClipRect.w); mix(c.ElemCount) end
    end
    local t2 = clock()
    G.ImGui_ImplRoblox.RenderDrawData(dd)
    local t3 = clock()
    if frame > 20 then table.insert(lib, t1 - t0); table.insert(be, t3 - t2) end
    if frame == ARG_FRAMES - 1 then
        local lm, ll = stats(lib)
        local bm, bl = stats(be)
        print(string.format("STRESS2 %s lib med %.3f lowq %.3f ms | backend med %.3f lowq %.3f ms", MODE, lm, ll, bm, bl))
        print("STRESS2HASH", MODE, h)
    end
end)
