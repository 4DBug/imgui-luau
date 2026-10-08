--- ImGui Backend for Roblox
---  - Renderer: exact software rasterizer (1:1 with imgui's triangles) into 256x256 EditableImage tiles at native
---    screen resolution; only tiles whose content changed are redrawn/uploaded (see RenderDrawData).
---  - Platform: UserInputService
---  - Files: an in-memory file system (VFS), pre-filled with the fonts from imgui_impl_roblox_fonts.lua
--- Requires "Allow Mesh / Image APIs" (EditableImage) in game settings.

local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local AssetService     = game:GetService("AssetService")

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local readu8, readu32, writeu32, readstring = buffer.readu8, buffer.readu32, buffer.writeu32, buffer.readstring
local band, rshift = bit32.band, bit32.rshift

local ImGui_ImplRoblox_GetBackendData
local ImGui_ImplRoblox_UpdateTexture
local ImGui_ImplRoblox_RenderDrawData
local ImGui_ImplRoblox_Shutdown

local KEY_MAP = {} -- Enum.KeyCode -> ImGuiKey
do
    local names = {
        Return = "Enter", Escape = "Escape", Backspace = "Backspace", Tab = "Tab", Space = "Space", KeypadEnter = "KeypadEnter",
        Up = "UpArrow", Down = "DownArrow", Left = "LeftArrow", Right = "RightArrow",
        Home = "Home", End = "End", PageUp = "PageUp", PageDown = "PageDown", Insert = "Insert", Delete = "Delete",
        LeftControl = "LeftCtrl", RightControl = "RightCtrl", LeftShift = "LeftShift", RightShift = "RightShift",
        LeftAlt = "LeftAlt", RightAlt = "RightAlt", LeftSuper = "LeftSuper", RightSuper = "RightSuper",
        Quote = "Apostrophe", Comma = "Comma", Minus = "Minus", Period = "Period", Slash = "Slash", Semicolon = "Semicolon",
        Equals = "Equal", LeftBracket = "LeftBracket", BackSlash = "Backslash", RightBracket = "RightBracket", Backquote = "GraveAccent",
        CapsLock = "CapsLock",
        KeypadPeriod = "KeypadDecimal", KeypadDivide = "KeypadDivide", KeypadMultiply = "KeypadMultiply",
        KeypadMinus = "KeypadSubtract", KeypadPlus = "KeypadAdd", KeypadEquals = "KeypadEqual",
    }
    local digits = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
    for i = 0, 9 do
        names[digits[i + 1]] = "K" .. i
        names["Keypad" .. digits[i + 1]] = "Keypad" .. i
    end
    for i = 1, 12 do names["F" .. i] = "F" .. i end
    for c in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do names[c] = c end

    for rbx_name, imgui_name in pairs(names) do
        KEY_MAP[Enum.KeyCode[rbx_name]] = ImGuiKey[imgui_name]
    end
end

-- Roblox has no "text input" event, so characters come from KeyCode.Value (ASCII for printable keys) + a US layout shift table.
local SHIFTED = {
    ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%", ["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", ["0"] = ")",
    ["-"] = "_", ["="] = "+", ["["] = "{", ["]"] = "}", ["\\"] = "|", [";"] = ":", ["'"] = "\"", [","] = "<", ["."] = ">", ["/"] = "?", ["`"] = "~",
}

local MOUSE_BUTTONS = {
    [Enum.UserInputType.MouseButton1] = 0, -- ImGuiMouseButton.Left
    [Enum.UserInputType.MouseButton2] = 1, -- ImGuiMouseButton.Right
    [Enum.UserInputType.MouseButton3] = 2, -- ImGuiMouseButton.Middle
}

--- @return boolean ctrl, boolean shift, boolean alt
local function ImGui_ImplRoblox_UpdateKeyModifiers()
    local io = ImGui.GetIO()
    local K = Enum.KeyCode
    local ctrl  = UserInputService:IsKeyDown(K.LeftControl) or UserInputService:IsKeyDown(K.RightControl)
    local shift = UserInputService:IsKeyDown(K.LeftShift) or UserInputService:IsKeyDown(K.RightShift)
    local alt   = UserInputService:IsKeyDown(K.LeftAlt) or UserInputService:IsKeyDown(K.RightAlt)
    io:AddKeyEvent(ImGuiMod_Ctrl, ctrl)
    io:AddKeyEvent(ImGuiMod_Shift, shift)
    io:AddKeyEvent(ImGuiMod_Alt, alt)
    io:AddKeyEvent(ImGuiMod_Super, UserInputService:IsKeyDown(K.LeftSuper) or UserInputService:IsKeyDown(K.RightSuper))
    return ctrl, shift, alt
end

--- @return table?
function ImGui_ImplRoblox_GetBackendData()
    return ImGui.GetCurrentContext() and ImGui.GetIO().BackendPlatformUserData or nil
end

local function ImGui_ImplRoblox_UpdateMonitors(w, h)
    local platform_io = ImGui.GetPlatformIO()
    platform_io.Monitors:resize(0)

    local imgui_monitor = ImGuiPlatformMonitor()
    ImVec2_Copy(imgui_monitor.MainSize, ImVec2(w, h))
    ImVec2_Copy(imgui_monitor.WorkSize, ImVec2(w, h))

    platform_io.Monitors:push_back(imgui_monitor)
end

---------------------------------------------------------
-- PLATFORM DATA & CALLBACKS
---------------------------------------------------------

-- Games can't touch the OS clipboard, so copy/paste only works inside ImGui
local clipboard = ""
local function ImGui_ImplRoblox_PlatformSetClipboardText(ctx, text) clipboard = text end
local function ImGui_ImplRoblox_PlatformGetClipboardText(ctx) return clipboard end

---------------------------------------------------------
-- FILE SYSTEM (in-memory, Roblox has no file access)
---------------------------------------------------------

local VFS = {} -- path -> string of raw bytes

--- Registers a file so ImGui can load it, e.g. ImGui_ImplRoblox.AddFile("fonts/MyFont.ttf", bytes)
--- then io.Fonts:AddFontFromFileTTF("fonts/MyFont.ttf", 16)
local function ImGui_ImplRoblox_AddFile(path, bytes) VFS[path] = bytes end

for path, hex in pairs(IM_INCLUDE("imgui_impl_roblox_fonts.lua")) do
    VFS[path] = hex:gsub("%s", ""):gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end)
end

function ImStd.ImFileOpen(filename, mode)
    local data = VFS[filename]
    return data and { Data = data, Pos = 0 } or nil
end

function ImStd.ImFileClose(f) end

function ImStd.ImFileGetSize(f) return #f.Data end

function ImStd.ImFileRead(f, data, count)
    local s, pos = f.Data, f.Pos
    count = min(count, #s - pos)
    for i = 1, count do data[i] = string.byte(s, pos + i) end
    f.Pos = pos + count
    return count
end

function ImStd.ImFileLoadToMemory(filename, mode)
    local f = ImStd.ImFileOpen(filename, mode)
    if not f or #f.Data == 0 then return end
    local file_data = {}
    local size = ImStd.ImFileRead(f, file_data, #f.Data)
    return file_data, size
end

---------------------------------------------------------
-- TEXTURE MANAGEMENT
---------------------------------------------------------

-- Copies a region of ImTextureData pixels (1-based byte table) into our RGBA8 buffer
local function CopyTexturePixels(tex, dst, x, y, w, h)
    local bpp, tex_w = tex.BytesPerPixel, tex.Width
    for row = 0, h - 1 do
        local src, src_base = tex:GetPixelsAt(x, y + row)
        local dst_off = ((y + row) * tex_w + x) * 4
        if bpp == 4 then
            for i = 0, w - 1 do
                local s = src_base + i * 4
                writeu32(dst, dst_off + i * 4, src[s] + src[s + 1] * 256 + src[s + 2] * 65536 + src[s + 3] * 16777216)
            end
        else -- Alpha8: white with alpha
            for i = 0, w - 1 do
                writeu32(dst, dst_off + i * 4, 16777215 + src[src_base + i] * 16777216)
            end
        end
    end
end

function ImGui_ImplRoblox_UpdateTexture(tex)
    local bd = ImGui_ImplRoblox_GetBackendData()
    if tex.Status == ImTextureStatus.WantCreate then
        local t = { Buffer = buffer.create(tex.Width * tex.Height * 4), Width = tex.Width, Height = tex.Height }
        CopyTexturePixels(tex, t.Buffer, 0, 0, tex.Width, tex.Height)

        bd.TextureCount = bd.TextureCount + 1
        bd.Textures[bd.TextureCount] = t
        tex.BackendUserData = bd.TextureCount
        tex:SetTexID(bd.TextureCount)
        tex:SetStatus(ImTextureStatus.OK)
    elseif tex.Status == ImTextureStatus.WantUpdates then
        local t = bd.Textures[tex.BackendUserData]
        IM_ASSERT(t ~= nil)
        for _, r in tex.Updates:iter() do
            CopyTexturePixels(tex, t.Buffer, r.x, r.y, r.w, r.h)
        end
        tex:SetStatus(ImTextureStatus.OK)
    elseif tex.Status == ImTextureStatus.WantDestroy then
        if tex.BackendUserData then
            bd.Textures[tex.BackendUserData] = nil
            tex.BackendUserData = nil
        end
        tex:SetTexID(ImTextureID_Invalid)
        tex:SetStatus(ImTextureStatus.Destroyed)
    end
end

---------------------------------------------------------
-- RENDERING (software rasterizer into tile buffers)
---------------------------------------------------------
-- Buffer layout: 4 bytes per pixel, R G B A, row-major, 0-based offsets. ImU32 colours are already R | G<<8 | B<<16 | A<<24.
-- Blending is non-premultiplied "over" with a transparent (alpha 0) background, so the game stays visible behind ImGui.

local buf, buf_w -- buffer/width of the tile being drawn
local TILE_SIZE -- Vector2, set below

-- Blends one pixel (r, g, b, a are 0..255). One u32 read/write, one division in the general case.
-- FillSpan below inlines the same math with per-span constants - keep the two in sync.
@native
local function BlendPixel(o, r, g, b, a)
    if a >= 255 then
        writeu32(buf, o, floor(r + 0.5) + floor(g + 0.5) * 256 + floor(b + 0.5) * 65536 + 4278190080)
        return
    end
    if a <= 0 then return end
    local d = readu32(buf, o)
    local da = rshift(d, 24)
    if da == 0 then
        writeu32(buf, o, floor(r + 0.5) + floor(g + 0.5) * 256 + floor(b + 0.5) * 65536 + floor(a + 0.5) * 16777216)
        return
    end
    local sa = a / 255
    local dr, dg, db = band(d, 255), band(rshift(d, 8), 255), band(rshift(d, 16), 255)
    if da == 255 then
        local ns = 1 - sa
        writeu32(buf, o, floor(r * sa + dr * ns + 0.5) + floor(g * sa + dg * ns + 0.5) * 256 + floor(b * sa + db * ns + 0.5) * 65536 + 4278190080)
    else
        local k = da * ((1 - sa) / 255)
        local oa = sa + k
        local inv = 1 / oa
        writeu32(buf, o, floor((r * sa + dr * k) * inv + 0.5) + floor((g * sa + dg * k) * inv + 0.5) * 256
            + floor((b * sa + db * k) * inv + 0.5) * 65536 + floor(oa * 255 + 0.5) * 16777216)
    end
end

-- Fills pixels [x0, x1) of row y with one colour
@native
local function FillSpan(y, x0, x1, r, g, b, a)
    if a <= 0 then return end
    local o0 = (y * buf_w + x0) * 4
    local o1 = o0 + (x1 - x0 - 1) * 4
    if a >= 255 then
        local packed = floor(r + 0.5) + floor(g + 0.5) * 256 + floor(b + 0.5) * 65536 + 4278190080
        for o = o0, o1, 4 do writeu32(buf, o, packed) end
        return
    end
    local packed0 = floor(r + 0.5) + floor(g + 0.5) * 256 + floor(b + 0.5) * 65536 + floor(a + 0.5) * 16777216
    local sa = a / 255
    local ns = 1 - sa
    local c1 = ns / 255
    local rs, gs, bs = r * sa, g * sa, b * sa
    local last_d, last_v = -1, 0 -- UI backgrounds are mostly flat: reuse the previous result for the same destination
    for o = o0, o1, 4 do
        local d = readu32(buf, o)
        local da = rshift(d, 24)
        if d == last_d then
            writeu32(buf, o, last_v)
        elseif da == 0 then
            writeu32(buf, o, packed0)
        else
            last_d = d
            local dr, dg, db = band(d, 255), band(rshift(d, 8), 255), band(rshift(d, 16), 255)
            if da == 255 then
                last_v = floor(rs + dr * ns + 0.5) + floor(gs + dg * ns + 0.5) * 256 + floor(bs + db * ns + 0.5) * 65536 + 4278190080
            else
                local k = da * c1
                local oa = sa + k
                local inv = 1 / oa
                last_v = floor((rs + dr * k) * inv + 0.5) + floor((gs + dg * k) * inv + 0.5) * 256
                    + floor((bs + db * k) * inv + 0.5) * 65536 + floor(oa * 255 + 0.5) * 16777216
            end
            writeu32(buf, o, last_v)
        end
    end
end

@native
local function UnpackColor(col)
    return col % 256, floor(col / 256) % 256, floor(col / 65536) % 256, floor(col / 16777216) % 256
end

-- Nearest texel at (u, v) as r, g, b, a (0..255)
@native
local function SampleTexture(t, u, v)
    local tw, th = t.Width, t.Height
    local tx, ty = floor(u * tw), floor(v * th)
    if tx < 0 then tx = 0 elseif tx >= tw then tx = tw - 1 end
    if ty < 0 then ty = 0 elseif ty >= th then ty = th - 1 end
    local o = (ty * tw + tx) * 4
    local tb = t.Buffer
    return readu8(tb, o), readu8(tb, o + 1), readu8(tb, o + 2), readu8(tb, o + 3)
end

-- Axis aligned, single colour quad (rects, glyphs, images). Pixel centers inside [x0, x1) x [y0, y1) are drawn.
@native
local function DrawRect(x0, y0, x1, y1, u0, v0, u1, v1, col, t, cx0, cy0, cx1, cy1)
    local r, g, b, a = UnpackColor(col)
    if a == 0 then return end
    local px0, py0 = max(ceil(x0 - 0.5), cx0), max(ceil(y0 - 0.5), cy0)
    local px1, py1 = min(ceil(x1 - 0.5), cx1), min(ceil(y1 - 0.5), cy1)
    if px0 >= px1 or py0 >= py1 then return end

    if not t or (u0 == u1 and v0 == v1) then
        if t then
            local tr, tg, tb, ta = SampleTexture(t, u0, v0)
            r, g, b, a = r * tr / 255, g * tg / 255, b * tb / 255, a * ta / 255
        end
        if a <= 0 then return end
        -- Rows of a flat rect usually blend over identical rows: when this row's destination equals the previous
        -- row's (exact string compare), the result is identical too, so memcpy the previous row's result.
        local len = (px1 - px0) * 4
        local prev_dst, prev_o = nil, 0
        for y = py0, py1 - 1 do
            local o = (y * buf_w + px0) * 4
            if a >= 255 then
                if prev_dst then buffer.copy(buf, o, buf, prev_o, len) else FillSpan(y, px0, px1, r, g, b, a); prev_dst = true end
            else
                local dst = readstring(buf, o, len)
                if dst == prev_dst then
                    buffer.copy(buf, o, buf, prev_o, len)
                else
                    FillSpan(y, px0, px1, r, g, b, a)
                    prev_dst = dst
                end
            end
            prev_o = o
        end
        return
    end

    local du, dv = (u1 - u0) / (x1 - x0), (v1 - v0) / (y1 - y0)
    local tw, th, tbuf = t.Width, t.Height, t.Buffer
    local r255, g255, b255, a255 = r / 255, g / 255, b / 255, a / 255
    for y = py0, py1 - 1 do
        local ty = floor((v0 + (y + 0.5 - y0) * dv) * th)
        if ty < 0 then ty = 0 elseif ty >= th then ty = th - 1 end
        local trow = ty * tw
        local o = (y * buf_w + px0) * 4
        for x = px0, px1 - 1 do
            local tx = floor((u0 + (x + 0.5 - x0) * du) * tw)
            if tx < 0 then tx = 0 elseif tx >= tw then tx = tw - 1 end
            local to = (trow + tx) * 4
            local ta = readu8(tbuf, to + 3)
            if ta > 0 then
                BlendPixel(o, readu8(tbuf, to) * r255, readu8(tbuf, to + 1) * g255, readu8(tbuf, to + 2) * b255, ta * a255)
            end
            o = o + 4
        end
    end
end

-- Generic triangle: per-vertex colour + uv, top-left fill rule, clipped to [cx0, cx1) x [cy0, cy1)
@native
local function DrawTriangle(va, vb, vc, t, cx0, cy0, cx1, cy1, ox, oy)
    local x0, y0 = va[1][1] - ox, va[1][2] - oy
    local x1, y1 = vb[1][1] - ox, vb[1][2] - oy
    local x2, y2 = vc[1][1] - ox, vc[1][2] - oy
    local area = (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0)
    if area == 0 then return end
    if area < 0 then -- make the winding consistent so "inside" means all edge functions >= 0
        vb, vc = vc, vb
        x1, y1, x2, y2 = x2, y2, x1, y1
        area = -area
    end

    local minx, maxx = max(floor(min(x0, x1, x2)), cx0), min(ceil(max(x0, x1, x2)), cx1 - 1)
    local miny, maxy = max(floor(min(y0, y1, y2)), cy0), min(ceil(max(y0, y1, y2)), cy1 - 1)
    if minx > maxx or miny > maxy then return end

    -- Edge functions E(p) = A*px + B*py + C, w0 is opposite va, w1 opposite vb, w2 opposite vc
    local A0, B0 = y1 - y2, x2 - x1; local C0 = -(A0 * x1 + B0 * y1)
    local A1, B1 = y2 - y0, x0 - x2; local C1 = -(A1 * x2 + B1 * y2)
    local A2, B2 = y0 - y1, x1 - x0; local C2 = -(A2 * x0 + B2 * y0)
    local tl0 = A0 > 0 or (A0 == 0 and B0 > 0)
    local tl1 = A1 > 0 or (A1 == 0 and B1 > 0)
    local tl2 = A2 > 0 or (A2 == 0 and B2 > 0)

    local inv = 1 / area
    local ra, ga, ba, aa = UnpackColor(va[3])
    local rb, gb, bb, ab = UnpackColor(vb[3])
    local rc, gc, bc, ac = UnpackColor(vc[3])
    local ua, vva, ub, vvb, uc, vvc = va[2][1], va[2][2], vb[2][1], vb[2][2], vc[2][1], vc[2][2]

    local textured = t and not (ua == ub and ua == uc and vva == vvb and vva == vvc)
    if t and not textured then -- constant uv (e.g. the atlas white pixel): fold the texel into the vertex colours
        local tr, tg, tb, ta = SampleTexture(t, ua, vva)
        ra, ga, ba, aa = ra * tr / 255, ga * tg / 255, ba * tb / 255, aa * ta / 255
        rb, gb, bb, ab = rb * tr / 255, gb * tg / 255, bb * tb / 255, ab * ta / 255
        rc, gc, bc, ac = rc * tr / 255, gc * tg / 255, bc * tb / 255, ac * ta / 255
    end
    local flat = not textured and ra == rb and ra == rc and ga == gb and ga == gc and ba == bb and ba == bc and aa == ab and aa == ac
    if flat and aa <= 0 then return end

    for y = miny, maxy do
        local py = y + 0.5
        -- Narrow the x range of this row using the edges (expanded by one pixel, exact test below)
        local xl, xr = minx, maxx
        local e0, e1, e2 = B0 * py + C0, B1 * py + C1, B2 * py + C2
        if A0 ~= 0 then local xe = -e0 / A0 - 0.5; if A0 > 0 then xl = max(xl, floor(xe)) else xr = min(xr, ceil(xe)) end end
        if A1 ~= 0 then local xe = -e1 / A1 - 0.5; if A1 > 0 then xl = max(xl, floor(xe)) else xr = min(xr, ceil(xe)) end end
        if A2 ~= 0 then local xe = -e2 / A2 - 0.5; if A2 > 0 then xl = max(xl, floor(xe)) else xr = min(xr, ceil(xe)) end end

        local row = y * buf_w
        for x = xl, xr do
            local px = x + 0.5
            local w0, w1, w2 = A0 * px + e0, A1 * px + e1, A2 * px + e2
            if (w0 > 0 or (w0 == 0 and tl0)) and (w1 > 0 or (w1 == 0 and tl1)) and (w2 > 0 or (w2 == 0 and tl2)) then
                local o = (row + x) * 4
                if flat then
                    BlendPixel(o, ra, ga, ba, aa)
                else
                    w0, w1, w2 = w0 * inv, w1 * inv, w2 * inv
                    local r = w0 * ra + w1 * rb + w2 * rc
                    local g = w0 * ga + w1 * gb + w2 * gc
                    local b = w0 * ba + w1 * bb + w2 * bc
                    local a = w0 * aa + w1 * ab + w2 * ac
                    if textured then
                        local tr, tg, tb, ta = SampleTexture(t, w0 * ua + w1 * ub + w2 * uc, w0 * vva + w1 * vvb + w2 * vvc)
                        r, g, b, a = r * tr / 255, g * tg / 255, b * tb / 255, a * ta / 255
                    end
                    BlendPixel(o, r, g, b, a)
                end
            end
        end
    end
end

-- Quads emitted by PrimRect/PrimRectUV/RenderText use indices (a, b, c, a, c, d) with a=TL, b=TR, c=BR, d=BL.
-- When such a quad is axis aligned with one colour it is drawn with the much cheaper DrawRect.
@native
local function TryDrawRect(va, vb, vc, vd, t, cx0, cy0, cx1, cy1, ox, oy)
    local pa, pb, pc, pd = va[1], vb[1], vc[1], vd[1]
    if not (pa[2] == pb[2] and pb[1] == pc[1] and pc[2] == pd[2] and pd[1] == pa[1] and pa[1] < pb[1] and pa[2] < pd[2]) then return false end
    local col = va[3]
    if vb[3] ~= col or vc[3] ~= col or vd[3] ~= col then return false end
    local ta, tb, tc, td = va[2], vb[2], vc[2], vd[2]
    if not (tb[1] == tc[1] and tb[2] == ta[2] and td[1] == ta[1] and td[2] == tc[2]) then return false end
    DrawRect(pa[1] - ox, pa[2] - oy, pc[1] - ox, pc[2] - oy, ta[1], ta[2], tc[1], tc[2], col, t, cx0, cy0, cx1, cy1)
    return true
end

-- Tiles: the screen is covered by TILE x TILE EditableImages (one ImageLabel each). Every frame each primitive
-- (triangle, or axis aligned quad) is hashed into the tiles it touches; only tiles whose hash changed are
-- re-rasterized and uploaded. Static UI therefore costs ~nothing to draw, and the result is pixel-identical to a
-- full redraw (the hash covers everything that affects a tile's pixels: geometry, uv, colour, texture, clip, order).
local TILE = 256
TILE_SIZE = Vector2.new(TILE, TILE)
local P1, P2 = 2147483647, 2147483629 -- two independent 31 bit hashes per tile (collision odds ~2^-62)

-- Primitive arrays (reused between frames, no per-frame allocation)
local pr_a, pr_b, pr_c, pr_d, pr_t = {}, {}, {}, {}, {} -- vertices (pr_d == false -> triangle), texture
local pr_cx0, pr_cy0, pr_cx1, pr_cy1 = {}, {}, {}, {}  -- clip (screen pixels)

@native
local function HashVertex(h1, h2, v)
    local p, u, c = v[1], v[2], v[3]
    local x, y = p[1], p[2]
    local uv = u[1] * 8192 + u[2]
    h1 = (h1 * 48271 + x * 4096 + y) % P1
    h1 = (h1 * 48271 + uv * 4096) % P1
    h1 = (h1 * 48271 + c) % P1
    h2 = (h2 * 16807 + y * 4093 + x) % P2
    h2 = (h2 * 16807 + uv * 65521) % P2
    h2 = (h2 * 16807 + c) % P2
    return h1, h2
end

local function GetTile(bd, index, tx, ty)
    local tile = bd.Tiles[index]
    if tile then return tile end
    local img = AssetService:CreateEditableImage({ Size = Vector2.new(TILE, TILE) })
    assert(img, "imgui_impl_roblox: EditableImage memory budget exceeded")
    local label = Instance.new("ImageLabel")
    label.Name = "Tile" .. index
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    local scale = bd.Scale
    label.Size = UDim2.fromOffset(TILE / scale, TILE / scale)
    label.Position = UDim2.fromOffset(tx * TILE / scale, ty * TILE / scale)
    label.ResampleMode = Enum.ResamplerMode.Pixelated
    label.ImageContent = Content.fromObject(img)
    label.Visible = false
    label.Active = bd.TilesActive
    label.Parent = bd.Gui
    tile = { Image = img, Label = label, Buffer = buffer.create(TILE * TILE * 4), H1 = -1, H2 = -1, Visible = false }
    bd.Tiles[index] = tile
    return tile
end

local function DestroyTiles(bd)
    for _, tile in pairs(bd.Tiles) do tile.Label:Destroy(); tile.Image:Destroy() end
    bd.Tiles = {}
end

-- MicroProfiler labels, enabled with ImGui_ImplRoblox.SetProfiling(true)
local profilebegin, profileend = debug.profilebegin, debug.profileend
local profiling = false
local function PB(name) if profiling then profilebegin(name) end end
local function PE() if profiling then profileend() end end

@native
function ImGui_ImplRoblox_RenderDrawData(draw_data)
    local bd = ImGui_ImplRoblox_GetBackendData()
    PB("ImGui RenderDrawData")

    PB("ImGui textures")
    if draw_data.Textures ~= nil then
        for _, tex in draw_data.Textures:iter() do
            if tex.Status ~= ImTextureStatus.OK then
                ImGui_ImplRoblox_UpdateTexture(tex)
                bd.ForceRedraw = true -- texture contents changed: tiles sampling it must be redrawn
            end
        end
    end
    PE()

    -- Render rate cap: textures are always updated (imgui expects it), tiles only at bd.RenderRate Hz
    if bd.RenderRate > 0 then
        local now = os.clock()
        if now + 0.002 < bd.NextRender then PE(); return end
        bd.NextRender = math.max(bd.NextRender + 1 / bd.RenderRate, now)
    end

    local sw, sh = floor(draw_data.DisplaySize.x), floor(draw_data.DisplaySize.y)
    if sw <= 0 or sh <= 0 then PE(); return end
    local cols, rows = ceil(sw / TILE), ceil(sh / TILE)
    if cols ~= bd.TileCols or rows ~= bd.TileRows then
        DestroyTiles(bd)
        bd.TileCols, bd.TileRows = cols, rows
    end
    local ntiles = cols * rows
    local ox, oy = draw_data.DisplayPos.x, draw_data.DisplayPos.y

    -- Per tile: hashes and the list of primitives touching it
    local th1, th2, tn, tl = bd.TH1, bd.TH2, bd.TN, bd.TL
    for t = 0, ntiles - 1 do
        th1[t], th2[t], tn[t] = 0, 0, 0
        if not tl[t] then tl[t] = {} end
    end

    -- Pass 1: collect primitives, hash them into tiles
    PB("ImGui tile hash")
    local n = 0
    for _, draw_list in draw_data.CmdLists:iter() do
        local vtx, idx = draw_list.VtxBuffer.Data, draw_list.IdxBuffer.Data
        for _, pcmd in draw_list.CmdBuffer:iter() do
            if pcmd.UserCallback ~= nil then
                pcmd.UserCallback(draw_list, pcmd)
            elseif pcmd.ElemCount > 0 then
                local clip = pcmd.ClipRect
                local cx0, cy0 = max(floor(clip.x - ox), 0), max(floor(clip.y - oy), 0)
                local cx1, cy1 = min(floor(clip.z - ox), sw), min(floor(clip.w - oy), sh)
                if cx1 > cx0 and cy1 > cy0 then
                    local tex_id = pcmd:GetTexID()
                    local t = bd.Textures[tex_id]
                    local ch1 = ((cx0 * 8191 + cy0) * 8191 + cx1) % P1
                    local ch2 = ((cy1 * 8191 + cx1) * 8191 + cy0 + tex_id) % P2
                    local vo = pcmd.VtxOffset
                    local i, last = pcmd.IdxOffset + 1, pcmd.IdxOffset + pcmd.ElemCount
                    while i <= last do
                        local ia, ic = idx[i], idx[i + 2]
                        local va, vb, vc = vtx[vo + ia], vtx[vo + idx[i + 1]], vtx[vo + ic]
                        local vd = false
                        local pa, pb, pc = va[1], vb[1], vc[1]
                        local bx0, by0, bx1, by1
                        if i + 5 <= last and idx[i + 3] == ia and idx[i + 4] == ic then
                            local d = vtx[vo + idx[i + 5]]
                            local pd = d[1]
                            -- axis aligned quad (TL, TR, BR, BL) with one colour and a matching uv rect
                            if pa[2] == pb[2] and pb[1] == pc[1] and pc[2] == pd[2] and pd[1] == pa[1] and pa[1] < pb[1] and pa[2] < pd[2] then
                                local col = va[3]
                                local ta, tb, tc, td = va[2], vb[2], vc[2], d[2]
                                if vb[3] == col and vc[3] == col and d[3] == col
                                    and tb[1] == tc[1] and tb[2] == ta[2] and td[1] == ta[1] and td[2] == tc[2] then
                                    vd = d
                                    bx0, by0 = ceil(pa[1] - ox - 0.5), ceil(pa[2] - oy - 0.5)
                                    bx1, by1 = ceil(pc[1] - ox - 0.5), ceil(pc[2] - oy - 0.5)
                                end
                            end
                        end
                        if vd then
                            i = i + 6
                        else
                            bx0, by0 = floor(min(pa[1], pb[1], pc[1]) - ox), floor(min(pa[2], pb[2], pc[2]) - oy)
                            bx1, by1 = ceil(max(pa[1], pb[1], pc[1]) - ox) + 1, ceil(max(pa[2], pb[2], pc[2]) - oy) + 1
                            i = i + 3
                        end
                        if bx0 < cx0 then bx0 = cx0 end
                        if by0 < cy0 then by0 = cy0 end
                        if bx1 > cx1 then bx1 = cx1 end
                        if by1 > cy1 then by1 = cy1 end
                        if bx0 < bx1 and by0 < by1 then
                            n = n + 1
                            pr_a[n], pr_b[n], pr_c[n], pr_d[n], pr_t[n] = va, vb, vc, vd, t
                            pr_cx0[n], pr_cy0[n], pr_cx1[n], pr_cy1[n] = cx0, cy0, cx1, cy1
                            local h1, h2 = HashVertex(ch1, ch2, va)
                            h1, h2 = HashVertex(h1, h2, vb)
                            h1, h2 = HashVertex(h1, h2, vc)
                            if vd then h1, h2 = HashVertex(h1, h2, vd) end
                            for ty = floor(by0 / TILE), floor((by1 - 1) / TILE) do
                                for tx = floor(bx0 / TILE), floor((bx1 - 1) / TILE) do
                                    local ti = ty * cols + tx
                                    local k = tn[ti] + 1
                                    tn[ti] = k
                                    tl[ti][k] = n
                                    th1[ti] = (th1[ti] * 48271 + h1) % P1
                                    th2[ti] = (th2[ti] * 16807 + h2 + k) % P2
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    PE()

    -- Pass 2: redraw + upload changed tiles
    PB("ImGui raster+upload")
    local force = bd.ForceRedraw
    bd.ForceRedraw = false
    for ty = 0, rows - 1 do
        for tx = 0, cols - 1 do
            local ti = ty * cols + tx
            local count = tn[ti]
            local tile = bd.Tiles[ti]
            if count == 0 then
                if tile and tile.Visible then
                    tile.Visible = false
                    tile.Label.Visible = false
                    tile.H1 = -1
                end
            else
                tile = tile or GetTile(bd, ti, tx, ty)
                if force or tile.H1 ~= th1[ti] or tile.H2 ~= th2[ti] then
                    tile.H1, tile.H2 = th1[ti], th2[ti]
                    local x0, y0 = tx * TILE, ty * TILE
                    local x1, y1 = x0 + TILE, y0 + TILE
                    buf, buf_w = tile.Buffer, TILE
                    buffer.fill(buf, 0, 0)
                    local list = tl[ti]
                    local tox, toy = ox + x0, oy + y0
                    for k = 1, count do
                        local p = list[k]
                        local cx0, cy0 = max(pr_cx0[p], x0) - x0, max(pr_cy0[p], y0) - y0
                        local cx1, cy1 = min(pr_cx1[p], x1) - x0, min(pr_cy1[p], y1) - y0
                        local va, vc, vd = pr_a[p], pr_c[p], pr_d[p]
                        if vd then
                            local pa, pc, ta, tc = va[1], vc[1], va[2], vc[2]
                            DrawRect(pa[1] - tox, pa[2] - toy, pc[1] - tox, pc[2] - toy, ta[1], ta[2], tc[1], tc[2], va[3], pr_t[p], cx0, cy0, cx1, cy1)
                        else
                            DrawTriangle(va, pr_b[p], vc, pr_t[p], cx0, cy0, cx1, cy1, tox, toy)
                        end
                    end
                    PB("ImGui upload")
                    tile.Image:WritePixelsBuffer(Vector2.zero, TILE_SIZE, buf)
                    PE()
                end
                if not tile.Visible then
                    tile.Visible = true
                    tile.Label.Visible = true
                end
            end
        end
    end

    -- drop references so old vertex tables can be collected
    for k = n + 1, bd.LastPrimCount do pr_a[k], pr_b[k], pr_c[k], pr_d[k], pr_t[k] = nil, nil, nil, nil, nil end
    bd.LastPrimCount = n
    PE(); PE()
end

---------------------------------------------------------
-- CORE LIFECYCLE
---------------------------------------------------------

--- @param parent Instance? # where the ScreenGui goes, defaults to the local player's PlayerGui
--- @param render_scale number? # imgui pixels per Roblox UI point (defaults to 1). Roblox UI points are scaled by the
---                             # OS display scale, so on a 150% display pass 1.5 to render at physical resolution
---                             # (imgui then looks the same size as a desktop imgui app). Change later with SetRenderScale().
function ImGui_ImplRoblox_Init(parent, render_scale)
    local io = ImGui.GetIO()

    local gui = Instance.new("ScreenGui")
    gui.Name = "ImGui"
    gui.IgnoreGuiInset = true -- so GetMouseLocation() and the tiles share the same origin
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1000
    gui.Parent = parent or Players.LocalPlayer:WaitForChild("PlayerGui")

    local bd = {
        Time = os.clock(), Gui = gui, Connections = {},
        Textures = {}, TextureCount = 0, MouseX = -1, MouseY = -1,
        Tiles = {}, TileCols = 0, TileRows = 0, Scale = render_scale or 1, TilesActive = false, RenderRate = 60, NextRender = 0, TH1 = {}, TH2 = {}, TN = {}, TL = {}, LastPrimCount = 0, ForceRedraw = true,
    }
    io.BackendPlatformUserData = bd

    io.BackendFlags = bit32.bor(io.BackendFlags, ImGuiBackendFlags.RendererHasTextures, ImGuiBackendFlags.RendererHasVtxOffset)

    local platform_io = ImGui.GetPlatformIO()
    platform_io.Platform_SetClipboardTextFn = ImGui_ImplRoblox_PlatformSetClipboardText
    platform_io.Platform_GetClipboardTextFn = ImGui_ImplRoblox_PlatformGetClipboardText

    local screen = gui.AbsoluteSize
    ImGui_ImplRoblox_UpdateMonitors(screen.X, screen.Y)

    local function connect(signal, fn) table.insert(bd.Connections, signal:Connect(fn)) end

    connect(UserInputService.InputBegan, function(input, game_processed)
        local io = ImGui.GetIO()
        local button = MOUSE_BUTTONS[input.UserInputType]
        if button then
            io:AddMouseSourceEvent(ImGuiMouseSource.Mouse)
            io:AddMouseButtonEvent(button, true)
        elseif input.UserInputType == Enum.UserInputType.Keyboard and not game_processed then
            local ctrl, shift, alt = ImGui_ImplRoblox_UpdateKeyModifiers()
            local key = KEY_MAP[input.KeyCode]
            if key then io:AddKeyEvent(key, true) end

            -- Text: printable ASCII keys, skipped while Ctrl/Alt are held (shortcuts)
            local v = input.KeyCode.Value
            if v >= 32 and v < 127 and not (ctrl or alt) then
                local c = string.char(v)
                if shift then c = SHIFTED[c] or c:upper() end
                io:AddInputCharacter(string.byte(c))
            end
        end
    end)

    connect(UserInputService.InputEnded, function(input, game_processed)
        local io = ImGui.GetIO()
        local button = MOUSE_BUTTONS[input.UserInputType]
        if button then
            io:AddMouseButtonEvent(button, false)
        elseif input.UserInputType == Enum.UserInputType.Keyboard then
            ImGui_ImplRoblox_UpdateKeyModifiers()
            local key = KEY_MAP[input.KeyCode]
            if key then io:AddKeyEvent(key, false) end
        end
    end)

    connect(UserInputService.InputChanged, function(input, game_processed)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            ImGui.GetIO():AddMouseWheelEvent(0, input.Position.Z)
        end
    end)

    connect(UserInputService.WindowFocused, function() ImGui.GetIO():AddFocusEvent(true) end)
    connect(UserInputService.WindowFocusReleased, function() ImGui.GetIO():AddFocusEvent(false) end)
end

function ImGui_ImplRoblox_Shutdown()
    local io = ImGui.GetIO()
    local bd = ImGui_ImplRoblox_GetBackendData()
    for _, c in ipairs(bd.Connections) do c:Disconnect() end
    DestroyTiles(bd)
    bd.Gui:Destroy()

    io.BackendPlatformUserData = nil
    io.BackendFlags = bit32.band(io.BackendFlags, bit32.bnot(bit32.bor(
        ImGuiBackendFlags.RendererHasTextures,
        ImGuiBackendFlags.RendererHasVtxOffset
    )))
end

function ImGui_ImplRoblox_NewFrame()
    PB("ImGui NewFrame (backend)")
    local io = ImGui.GetIO()
    local bd = ImGui_ImplRoblox_GetBackendData()

    local screen = bd.Gui.AbsoluteSize
    local w, h = floor(screen.X * bd.Scale), floor(screen.Y * bd.Scale)
    if w ~= bd.ScreenW or h ~= bd.ScreenH then
        bd.ScreenW, bd.ScreenH = w, h
        ImGui_ImplRoblox_UpdateMonitors(w, h)
    end
    ImVec2_CopyV(io.DisplaySize, w, h)

    local current_time = os.clock()
    io.DeltaTime = (current_time > bd.Time) and (current_time - bd.Time) or (1.0 / 60.0)
    bd.Time = current_time

    local m = UserInputService:GetMouseLocation()
    if m.X ~= bd.MouseX or m.Y ~= bd.MouseY then
        bd.MouseX, bd.MouseY = m.X, m.Y
        io:AddMouseSourceEvent(ImGuiMouseSource.Mouse)
        io:AddMousePosEvent(m.X * bd.Scale, m.Y * bd.Scale)
    end

    -- While the mouse is over imgui, make the tiles Active so Roblox stops passing clicks/wheel to the game (camera zoom etc.)
    local want = io.WantCaptureMouse
    if want ~= bd.TilesActive then
        bd.TilesActive = want
        for _, tile in pairs(bd.Tiles) do tile.Label.Active = want end
    end
    PE()
end

--- Max tile redraws per second (default 60); 0 = every frame. imgui logic still runs every frame.
function ImGui_ImplRoblox_SetRenderRate(hz)
    ImGui_ImplRoblox_GetBackendData().RenderRate = hz or 0
end

--- Toggle MicroProfiler labels (debug.profilebegin) for the backend
function ImGui_ImplRoblox_SetProfiling(enabled) profiling = enabled and true or false end
local function ImGui_ImplRoblox_IsProfiling() return profiling end

function ImGui_ImplRoblox_SetRenderScale(scale)
    local bd = ImGui_ImplRoblox_GetBackendData()
    if scale == bd.Scale then return end
    bd.Scale = scale
    DestroyTiles(bd)
    bd.TileCols, bd.TileRows = 0, 0
    bd.ForceRedraw = true
end

ImGui_ImplRoblox = {
    Init           = ImGui_ImplRoblox_Init,
    Shutdown       = ImGui_ImplRoblox_Shutdown,
    NewFrame       = ImGui_ImplRoblox_NewFrame,
    RenderDrawData = ImGui_ImplRoblox_RenderDrawData,
    AddFile        = ImGui_ImplRoblox_AddFile,
    SetRenderScale = ImGui_ImplRoblox_SetRenderScale,
    SetRenderRate  = ImGui_ImplRoblox_SetRenderRate,
    SetProfiling   = ImGui_ImplRoblox_SetProfiling,
    IsProfiling    = ImGui_ImplRoblox_IsProfiling,
}

return true -- [Roblox] ModuleScripts must return exactly one value
