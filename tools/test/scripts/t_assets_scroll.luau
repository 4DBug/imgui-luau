-- Demo Assets Browser (10000 items) scrolled continuously for ~1000 frames in raster mode: live tiles and
-- EditableImage bytes must stay bounded by what is visible and flat (no growth trend between the 1st and 2nd half).
-- Then (no input) the screen composited from those tiles (many recycled from the free list) must equal the one after
-- rebuilding every tile from scratch: a recycled EditableImage never shows stale pixels.
-- run: python3 tools/test/run.py --main tools/test/scripts/t_assets_scroll.luau --frames 1010 --quiet --roblox
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local Impl = G.ImGui_ImplRoblox
ImGui.CreateContext()
Impl.Init()
Impl.SetRenderRate(0)
local io = ImGui.GetIO()
local N = 1000
local frame, open = 0, true
local peak = { { 0, 0, 0 }, { 0, 0, 0 } } -- per half: tiles, EI count, EI bytes
local scroll_min, scroll_max = math.huge, 0
local W, H = 1280, 760 -- (composite: copied from t_composite.luau)
local function composite(gui)
    local screen = buffer.create(W * H * 3)
    local function walk(inst, ox, oy, kx0, ky0, kx1, ky1)
        local kids = inst:GetChildren()
        table.sort(kids, function(a, b) return (a.ZIndex or 1) < (b.ZIndex or 1) end) -- table.sort isn't stable, but siblings with equal ZIndex never overlap here
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
                        if sy >= ky0 and sy < ky1 then
                            for tx = 0, sz - 1 do
                                local sx = x + tx
                                if sx >= kx0 and sx < kx1 then
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
    return screen
end
local before

game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    if frame > N + 10 then return end
    Impl.NewFrame()
    io.DeltaTime = 1 / 60
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(20, 20), G.ImGuiCond.Always)
    open = G.ShowExampleAppAssetsBrowser(open)
    local w = ImGui.FindWindowByName("Example: Assets Browser")
    if w and frame > 2 and frame <= N then
        io:AddMousePosEvent(w.Pos.x + w.Size.x / 2, w.Pos.y + w.Size.y / 2)
        io:AddMouseWheelEvent(0, (frame % 400 < 250) and -2 or 3) -- down, then back up: continuous, both directions
    end
    ImGui.Render()
    Impl.RenderDrawData(ImGui.GetDrawData())
    local s
    if Impl.GetStats then s = Impl.GetStats() else -- (older backends, for before/after numbers: 1 EditableImage per tile)
        local n = 0
        for _, d in ipairs(game:GetService("Players").LocalPlayer.PlayerGui:GetDescendants()) do if d.ClassName == "ImageLabel" and d.Name:sub(1, 4) == "Tile" then n += 1 end end
        s = { Tiles = n, EditableImages = n, EditableImageBytes = n * 65536, EditableImageCap = math.huge }
    end
    assert(s.EditableImageBytes <= s.EditableImageCap)
    for _, c in ipairs(w and w.DC.ChildWindows.Data or {}) do scroll_min = math.min(scroll_min, c.Scroll.y); scroll_max = math.max(scroll_max, c.Scroll.y) end
    if frame > 50 then
        local p = peak[frame <= 525 and 1 or 2]
        p[1], p[2], p[3] = math.max(p[1], s.Tiles), math.max(p[2], s.EditableImages), math.max(p[3], s.EditableImageBytes)
    end
    if frame == N then
        print(("ASSETS scrolled %d..%d px; peak tiles %d / %d, EditableImages %d / %d, EI bytes %d / %d (1st / 2nd half); now %d tiles"):format(
            scroll_min, scroll_max, peak[1][1], peak[2][1], peak[1][2], peak[2][2], peak[1][3], peak[2][3], s.Tiles))
        assert(scroll_max - scroll_min > 5000, "assets browser did not scroll")
        -- the whole demo-sized screen is ~ 10 x 6 tiles per layer; content + chrome + spares + free list stay well below 150
        assert(peak[1][1] <= 150 and peak[2][1] <= 150, "tile count not bounded by what is visible")
        assert(peak[2][2] <= peak[1][2] + 4 and peak[2][3] <= peak[1][3] + 4 * 128 * 128 * 4, "EditableImage use grows over time")
    end
    if frame == N + 8 then
        before = buffer.tostring(composite(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ImGui")))
        Impl.SetRenderScale(2); Impl.SetRenderScale(1) -- (drops every tile: the next frame redraws all of them)
    elseif frame == N + 9 then
        local after = buffer.tostring(composite(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ImGui")))
        assert(#before:gsub("%z", "") > 10000, "nothing composited")
        assert(before == after, "recycled tiles show different pixels than freshly drawn ones")
        print("ASSETS OK")
    end
end)
