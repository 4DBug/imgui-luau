-- Backend pixel oracle: composites the ScreenGui (like t_composite) at checkpoints and prints "PIX <frame> <hash>".
-- Phases: resize (bottom-right, then top-left), move, scroll, hover, typing, new font sizes (glyph baking), colour drag.
-- Each phase ends with a few still frames, then a checkpoint. Run with RUN_FLAGS="ARG_FORCE=true" for a full redraw
-- every frame: incremental output must match it exactly (and match the previous backend version).
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
if ARG_TILELIMIT then ImGui.GetIO().BackendPlatformUserData.TileLimit = ARG_TILELIMIT end
local io = ImGui.GetIO()
local W, H = 1280, 760
local col = ImVec4(0.4, 0.7, 0.2, 0.5)
local buf = ImGui.NewTextBuffer("type here", 128)
local slider = 0.3

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

-- phase list: name, frames of action (then 6 still frames + checkpoint)
local PHASES = { { "start", 4 }, { "resize_br", 24 }, { "resize_tl", 24 }, { "move", 24 }, { "scroll", 30 }, { "hover", 30 },
                 { "type", 24 }, { "fonts", 24 }, { "color", 20 } }
local STILL = ARG_STILL or (ARG_TILELIMIT and 40 or 6) -- tile limit: deferred tiles need more frames to settle
local PT = {}
local pi, pf = 1, 0
local pos, size, scroll, fsize = ImVec2(40, 40), ImVec2(460, 520), 0, 13
local frame = 0
local typing = "Hello, glyphs! 0123 xyz"

game:GetService("RunService").Stepped:Connect(function()
    local ph = PHASES[pi]
    if not ph then return end
    frame += 1; pf += 1
    local name, n = ph[1], ph[2]
    local act = pf <= n
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    io:AddMousePosEvent(1200, 740)
    if act then
        if name == "resize_br" then size = ImVec2(460 + pf * 7, 520 + pf * 5)
        elseif name == "resize_tl" then pos = ImVec2(40 + pf * 3, 40 + pf * 2); size = ImVec2(size.x - 3, size.y - 2)
        elseif name == "move" then pos = ImVec2(pos.x + 5, pos.y + 3)
        elseif name == "scroll" then scroll += 9
        elseif name == "hover" then io:AddMousePosEvent(pos.x + 30 + (pf * 17) % 300, pos.y + 40 + (pf * 23) % 400)
        elseif name == "type" then
            if pf == 1 then io:AddMousePosEvent(pos.x + 120, pos.y + 37); io:AddMouseButtonEvent(0, true)
            elseif pf == 2 then io:AddMouseButtonEvent(0, false)
            else io:AddInputCharacter(string.byte(typing, (pf - 3) % #typing + 1)) end
        elseif name == "fonts" then fsize = 13 + pf * 0.75
        elseif name == "color" then
            local p = ImVec2(700 + pf * 4, 120 + pf * 3)
            io:AddMousePosEvent(p.x, p.y); io:AddMouseButtonEvent(0, pf < n)
        end
    end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(pos, G.ImGuiCond.Always); ImGui.SetNextWindowSize(size, G.ImGuiCond.Always)
    ImGui.Begin("Stress")
    ImGui.InputText("##in", buf, 128)
    if name == "scroll" or scroll > 0 then ImGui.SetScrollY(scroll) end
    for i = 1, 12 do ImGui.Button("Button " .. i); ImGui.SameLine(); slider = ImGui.SliderFloat("##s" .. i, slider, 0, 1) end
    if ImGui.BeginTable("tbl", 4, bit32.bor(G.ImGuiTableFlags.Borders, G.ImGuiTableFlags.RowBg)) then
        for r = 1, 30 do ImGui.TableNextRow(); for c = 1, 4 do ImGui.TableNextColumn(); ImGui.Text("r%d c%d", r, c) end end
        ImGui.EndTable()
    end
    ImGui.PushFont(nil, fsize); ImGui.Text("Font size %.2f AaBbCc", fsize); ImGui.PopFont()
    for i = 1, 30 do ImGui.TextWrapped("Line %d: the quick brown fox jumps over the lazy dog.", i) end
    ImGui.End()
    ImGui.SetNextWindowPos(ImVec2(660, 60), G.ImGuiCond.Always); ImGui.SetNextWindowSize(ImVec2(500, 620), G.ImGuiCond.Always)
    ImGui.Begin("Pickers")
    ImGui.ColorPicker4("bar", col, G.ImGuiColorEditFlags.PickerHueBar)
    ImGui.End()
    ImGui.Render()
    local clk = os.realclock or os.clock
    local t0 = clk()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if act then PT[name] = (PT[name] or 0) + (clk() - t0) * 1000 end
    if pf == n then -- mid-action (not settled): only exact without a redraw budget
        print("PIXA", name, frame, composite(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ImGui")))
    end
    if pf == n + STILL then
        local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ImGui")
        print("PIX", name, frame, composite(gui))
        pi += 1; pf = 0
        if not PHASES[pi] then
            for _, q in PHASES do print(string.format("PIXT %-10s %7.2f ms/frame", q[1], PT[q[1]] / q[2])) end
            print("PIXELS DONE")
        end
    end
end)
