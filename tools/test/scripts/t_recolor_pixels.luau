-- Pixel oracle for the "recolored" path (CompareDrawList 4 + PatchDrawList recolor: same vertex positions, a few
-- vertices' colour / uv changed, e.g. hover): animated style colours on buttons, text, frames, a colour button, a
-- scrolled child, a wide button over several tiles and AddRectFilledMultiColor cycling flat <-> gradient (kind changes
-- fall back to the full path), between still frames, structure changes, hover, a colour picker (too many changed
-- vertices) and a tile limit (deferred tiles). Composites the ScreenGui every few frames and prints "PIX <frame> <hash>".
-- Run with RUN_FLAGS="ARG_FORCE=true" for a full redraw every frame: incremental output must match it exactly (also with
-- ARG_PAR=true: the parallel executor).
--   python3 tools/test/run.py --main tools/test/scripts/t_recolor_pixels.luau --frames 140 --quiet --roblox
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
if ARG_PAR then G.ImGui_ImplRoblox.EnableParallel({ Sync = true, Actors = 4 }) end
local io = ImGui.GetIO()
local Col = G.ImGuiCol
local W, H = 1280, 760
local SW, SH = 720, 560 -- composited area (the windows are inside it)
local hsv = ImVec4(0.4, 0.7, 0.2, 1)

local function composite(gui)
    local screen = buffer.create(SW * SH * 3)
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
                                        local d = (sy * SW + sx) * 3
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
    walk(gui, 0, 0, 0, 0, SW, SH)
    local h = 0
    for i = 0, SW * SH * 3 - 4, 4 do h = (h * 31 + buffer.readu32(screen, i)) % 2147483647 end
    return h
end

-- phases: name, frames
local PHASES = { { "recolor", 24 }, { "still", 6 }, { "grow", 8 }, { "recolor", 16 }, { "hover", 24 },
                 { "picker", 10 }, { "limit", 30 }, { "recolor", 12 }, { "still", 6 } }
local frame, pi, pf, extra, t = 0, 1, 0, 0, 0
game:GetService("RunService").Stepped:Connect(function()
    local ph = PHASES[pi]
    if not ph then return end
    frame += 1
    pf += 1
    local name = ph[1]
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    io:AddMousePosEvent(1200, 740)
    io.BackendPlatformUserData.TileLimit = name == "limit" and 2 or nil
    if name == "recolor" or name == "limit" then t += 1 end
    if name == "grow" and pf % 3 == 0 then extra += 1 end
    if name == "hover" then io:AddMousePosEvent(50 + (pf * 37) % 420, 60 + (pf * 29) % 300) end
    if name == "picker" then hsv.x = (hsv.x + 0.03) % 1 end
    ImGui.NewFrame()
    local c1 = ImVec4(0.5 + 0.5 * math.sin(t * 0.3), 0.4, 0.5 + 0.5 * math.cos(t * 0.2), 1)
    local c2 = ImVec4(0.2, 0.5 + 0.5 * math.sin(t * 0.25), 0.3, 0.6 + 0.4 * math.cos(t * 0.4))
    ImGui.SetNextWindowPos(ImVec2(20, 20), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(470, 520), G.ImGuiCond.Always)
    ImGui.Begin("Recolor")
    ImGui.PushStyleColor(Col.Button, c1)
    ImGui.PushStyleColor(Col.FrameBg, c2)
    for i = 1, 6 do
        ImGui.Button("Button " .. i)
        if i % 3 ~= 0 then ImGui.SameLine() end
    end
    ImGui.Button("A wide button over several tiles", ImVec2(400, 40))
    ImGui.PopStyleColor(2)
    ImGui.TextColored(c1, "Coloured text %d", 7)
    ImGui.ColorButton("##cb", c2)
    ImGui.SameLine()
    local dl = ImGui.GetWindowDrawList()
    local p = ImGui.GetCursorScreenPos()
    -- flat (t % 8 < 2), horizontal / vertical gradient otherwise: kind changes take the full path
    local u1 = ImGui.GetColorU32(c1)
    local u2 = (t % 8 < 2) and u1 or ImGui.GetColorU32(c2)
    if t % 16 < 8 then
        dl:AddRectFilledMultiColor(p, ImVec2(p.x + 140, p.y + 30), u1, u2, u2, u1)
    else
        dl:AddRectFilledMultiColor(p, ImVec2(p.x + 140, p.y + 30), u1, u1, u2, u2)
    end
    ImGui.Dummy(ImVec2(140, 30))
    for i = 1, extra do ImGui.Text("Extra line %d", i) end
    ImGui.BeginChild("scrolled", ImVec2(0, 200), G.ImGuiChildFlags.Borders)
    ImGui.SetScrollY(37)
    ImGui.PushStyleColor(Col.Text, c1)
    for i = 1, 20 do ImGui.Text("Child line %d", i) end
    ImGui.PopStyleColor()
    ImGui.PushStyleColor(Col.Button, c2)
    ImGui.Button("Child button")
    ImGui.PopStyleColor()
    ImGui.EndChild()
    _ = ImGui.Checkbox("Check", true)
    ImGui.End()
    if name == "picker" or pi > 6 then
        ImGui.SetNextWindowPos(ImVec2(500, 20), G.ImGuiCond.Always)
        ImGui.SetNextWindowSize(ImVec2(210, 300), G.ImGuiCond.Always)
        ImGui.Begin("Picker")
        ImGui.ColorPicker4("##p", hsv, G.ImGuiColorEditFlags.PickerHueBar)
        ImGui.End()
    end
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if ARG_PAR then G.ImGui_ImplRoblox.FinishParallel() end
    -- (checkpoints: exact as long as no tile is deferred, i.e. not during "limit"; the frame after it redraws them)
    if name ~= "limit" and (frame % 3 == 0 or pf == ph[2]) then
        print("PIX", name, frame, composite(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ImGui")))
    end
    if pf == ph[2] then
        pi += 1
        pf = 0
        if not PHASES[pi] then print("RECOLORPIX DONE") end
    end
end)
