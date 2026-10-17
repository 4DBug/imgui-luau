-- Reversed rects (min > max, e.g. box-select dragged up/left) must draw like upstream's GPU path:
-- AddRectFilled + AddRect from each of the 4 drag directions composite to identical, non-blank pixels.
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
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

local A, B = ImVec2(200, 150), ImVec2(520, 400) -- drag start/end, down-right
local DIRS = { "none", "dr", "ul", "ur", "dl" }
local CORNERS = {
    dr = { A, B }, ul = { B, A },
    ur = { ImVec2(A.x, B.y), ImVec2(B.x, A.y) }, dl = { ImVec2(B.x, A.y), ImVec2(A.x, B.y) },
}
local di, pf, res = 1, 0, {}
game:GetService("RunService").Stepped:Connect(function()
    local d = DIRS[di]
    if not d then return end
    pf += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 60
    ImGui.NewFrame()
    local c = CORNERS[d]
    if c then
        local dl = ImGui.GetForegroundDrawList()
        dl:AddRectFilled(c[1], c[2], 0x6496FF32)
        dl:AddRect(c[1], c[2], 0xFFFF9664, 0, 2)
        dl:AddRectFilled(c[1], c[2], 0xFF00FF00, 12) -- rounded too
    end
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if pf == 4 then
        res[d] = composite(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ImGui"))
        print("RECT", d, res[d])
        di += 1; pf = 0
        if not DIRS[di] then
            local ok = res.dr ~= res.none and res.ul == res.dr and res.ur == res.dr and res.dl == res.dr
            print(ok and "RECTFLIP OK" or "RECTFLIP MISMATCH")
        end
    end
end)
