-- Pixel oracle for the bench scenes (tools/test/bench_scenes.luau: plots, colorpicker, implot if ImPlot is given,
-- demo_all), animated: composites the ScreenGui (like t_pixels) every few frames and prints "PIX <scene> <frame> <hash>".
-- Run with RUN_FLAGS="ARG_FORCE=true" for a full redraw every frame: incremental output must match it exactly (and match
-- the previous backend version).
--   python3 tools/test/run.py --main tools/test/scripts/t_scene_pixels.luau --frames 200 --quiet --roblox \
--       --module BenchScenes=tools/test/bench_scenes.luau [--module ImPlot=extensions/implot-luau/ImPlot.lua]
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("ImGui"))
local ImGui = G.ImGui
local ImPlot = RS:FindFirstChild("ImPlot") and require(RS.ImPlot)(G)
ImGui.CreateContext()
if ImPlot then ImPlot.CreateContext() end
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
local io = ImGui.GetIO()
local W, H = 1280, 760
local scenes = require(RS:WaitForChild("BenchScenes"))(G, ImPlot)
local ORDER = {}
for _, name in { "plots", "colorpicker", "implot", "demo_all" } do
    if scenes[name] then table.insert(ORDER, name) end
end
local FRAMES, EVERY = 40, 8

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
                    local img = c.ImageContent.Object
                    local px, sz = img.Pixels, img.Size.X
                    for ty = 0, sz - 1 do
                        local sy = y + ty
                        if sy >= cy0 and sy < cy1 then
                            for tx = 0, sz - 1 do
                                local sx = x + tx
                                if sx >= cx0 and sx < cx1 then
                                    local o = (ty * sz + tx) * 4
                                    local a = buffer.readu8(px, o + 3)
                                    if a > 0 then
                                        local d = (sy * W + sx) * 3
                                        local fa = a / 255
                                        for ch = 0, 2 do
                                            local v = buffer.readu8(px, o + ch) * fa + buffer.readu8(screen, d + ch) * (1 - fa)
                                            buffer.writeu8(screen, d + ch, math.floor(v + 0.5))
                                        end
                                    end
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

local frame = 0
game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    local si = (frame - 1) // FRAMES + 1
    local name = ORDER[si]
    if not name then return end
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    io:AddMousePosEvent(-1000, -1000)
    ImGui.NewFrame()
    scenes[name](frame)
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame % EVERY == 0 then
        print("PIX", name, frame, composite(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ImGui")))
    end
    if frame == #ORDER * FRAMES then print("SCENEPIX DONE") end
end)
