-- Scroll / resize pixel oracle (like t_pixels): the bench's stress window (buttons + sliders, a 60 x 6 table with row
-- backgrounds and borders, wrapped text) scrolls by 6 px a frame (down, then up), resizes from the bottom-right, then
-- from the top-left, "PIX <frame> <hash>" every 3 frames. Rows entering / leaving tiles and items shifting by one in a
-- tile's primitive list exercise DirtyRects' list diff. Run with RUN_FLAGS="ARG_FORCE=true" for a full redraw every
-- frame: incremental output must match it exactly.
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
if ARG_TILELIMIT then ImGui.GetIO().BackendPlatformUserData.TileLimit = ARG_TILELIMIT end
local io = ImGui.GetIO()
local W, H = 1280, 760

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
local pos, size, scroll, slider, check = ImVec2(60, 40), ImVec2(520, 640), 0, 0.5, true
local LAST = 210
game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    if frame > LAST then return end
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    io:AddMousePosEvent(1200, 740)
    if frame > 4 and frame <= 60 then scroll += 6
    elseif frame > 60 and frame <= 100 then scroll -= 7
    elseif frame > 100 and frame <= 150 then size = ImVec2(size.x + 3, size.y - 2)
    elseif frame > 150 and frame <= 200 then pos, size = ImVec2(pos.x + 2, pos.y + 2), ImVec2(size.x - 2, size.y - 2) end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(pos, G.ImGuiCond.Always); ImGui.SetNextWindowSize(size, G.ImGuiCond.Always)
    ImGui.Begin("Stress")
    ImGui.SetScrollY(scroll)
    for i = 1, 20 do
        ImGui.Button("Button " .. i); ImGui.SameLine()
        slider = ImGui.SliderFloat("##s" .. i, slider, 0, 1)
    end
    _, check = ImGui.Checkbox("Checkbox", check)
    if ImGui.BeginTable("tbl", 6, bit32.bor(G.ImGuiTableFlags.Borders, G.ImGuiTableFlags.RowBg)) then
        for r = 1, 60 do
            ImGui.TableNextRow()
            for c = 1, 6 do ImGui.TableNextColumn(); ImGui.Text("r%d c%d", r, c) end
        end
        ImGui.EndTable()
    end
    for i = 1, 40 do ImGui.TextWrapped("Line %d: the quick brown fox jumps over the lazy dog, again and again.", i) end
    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame % 3 == 0 then
        print("PIX", frame, composite(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ImGui")))
    end
    if frame == LAST then print("SCROLLPIX DONE") end
end)
