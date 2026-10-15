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
local readf64 = buffer.readf64
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
local proxy_focused = false
local function ImGui_ImplRoblox_PlatformGetClipboardText(ctx) if proxy_focused then return "" end return clipboard end

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
@native
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

--- User texture from RGBA8 pixels (e.g. EditableImage:ReadPixelsBuffer()). Returns an ImTextureRef for
--- ImGui.Image / draw_list:AddImage. Ids are never reused, so cached tiles can't show a stale image.
function ImGui_ImplRoblox_CreateTexture(pixels, w, h)
    local bd = ImGui_ImplRoblox_GetBackendData()
    bd.TextureCount = bd.TextureCount + 1
    bd.Textures[bd.TextureCount] = { Buffer = pixels, Width = w, Height = h }
    return ImTextureRef(bd.TextureCount)
end

function ImGui_ImplRoblox_DestroyTexture(tex_ref)
    ImGui_ImplRoblox_GetBackendData().Textures[tex_ref._TexID] = nil
end

---------------------------------------------------------
-- RENDERING (software rasterizer into tile buffers)
---------------------------------------------------------
-- Buffer layout: 4 bytes per pixel, R G B A, row-major, 0-based offsets. ImU32 colours are already R | G<<8 | B<<16 | A<<24.
-- Blending is non-premultiplied "over" with a transparent (alpha 0) background, so the game stays visible behind ImGui.

local buf, buf_w -- buffer/width of the tile being drawn
local rect_cols = table.create(256, 0) -- scratch: texel column offsets for DrawRect
local sub_bufs, n_sub_bufs = {}, 0 -- scratch: partial tile upload buffers by size
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
    -- The texel column only depends on x: compute it once per column instead of once per pixel
    local ncol = px1 - px0
    local cols = rect_cols
    for c = 1, ncol do
        local tx = floor((u0 + (px0 + c - 1 + 0.5 - x0) * du) * tw)
        if tx < 0 then tx = 0 elseif tx >= tw then tx = tw - 1 end
        cols[c] = tx * 4
    end
    for y = py0, py1 - 1 do
        local ty = floor((v0 + (y + 0.5 - y0) * dv) * th)
        if ty < 0 then ty = 0 elseif ty >= th then ty = th - 1 end
        local trow4 = ty * tw * 4
        local o = (y * buf_w + px0) * 4
        for c = 1, ncol do
            local to = trow4 + cols[c]
            local ta = readu8(tbuf, to + 3)
            if ta > 0 then
                local sa = ta * a255
                local sr, sg, sb = readu8(tbuf, to) * r255, readu8(tbuf, to + 1) * g255, readu8(tbuf, to + 2) * b255
                if sa >= 255 then -- (BlendPixel's opaque case, inlined: most glyph texels)
                    writeu32(buf, o, floor(sr + 0.5) + floor(sg + 0.5) * 256 + floor(sb + 0.5) * 65536 + 4278190080)
                else
                    BlendPixel(o, sr, sg, sb, sa)
                end
            end
            o = o + 4
        end
    end
end

-- Generic triangle: per-vertex colour + uv, top-left fill rule, clipped to [cx0, cx1) x [cy0, cy1)
@native
local function DrawTriangle(vbuf, va, vb, vc, t, cx0, cy0, cx1, cy1, ox, oy)
    local x0, y0 = readf64(vbuf, va) - ox, readf64(vbuf, va + 8) - oy
    local x1, y1 = readf64(vbuf, vb) - ox, readf64(vbuf, vb + 8) - oy
    local x2, y2 = readf64(vbuf, vc) - ox, readf64(vbuf, vc + 8) - oy
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
    local ra, ga, ba, aa = UnpackColor(readu32(vbuf, va + 32))
    local rb, gb, bb, ab = UnpackColor(readu32(vbuf, vb + 32))
    local rc, gc, bc, ac = UnpackColor(readu32(vbuf, vc + 32))
    local ua, vva, ub, vvb, uc, vvc = readf64(vbuf, va + 16), readf64(vbuf, va + 24), readf64(vbuf, vb + 16), readf64(vbuf, vb + 24), readf64(vbuf, vc + 16), readf64(vbuf, vc + 24)

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

-- Layers: every ImDrawList (one per top level window, popup, tooltip, plus the viewport bg/fg lists) gets its own
-- Frame, stacked by draw order. A layer is covered by TILE x TILE EditableImages (one ImageLabel each) placed
-- relative to the layer's origin (top-left of its content). Primitives are hashed into tiles in layer-relative
-- coordinates, so moving a window only moves its Frame: no tile changes, nothing re-rasterized or uploaded.
-- Only tiles whose hash changed are redrawn; the hash covers everything that affects a tile's pixels.
local TILE = 128
TILE_SIZE = Vector2.new(TILE, TILE)
local P1, P2 = 2147483647, 2147483629 -- two independent 31 bit hashes per tile (collision odds ~2^-62)
local KEY_W = 64 -- tile key = ty * KEY_W + tx (layers up to 16384 px wide)
local CLIP_PAD = 2048 -- content up to this far off screen is kept, so dragging a window past the edge doesn't redraw it
local LAYER_KEEP_FRAMES = 120 -- unused layers are destroyed after this many rendered frames
local MAX_DEFER_FRAMES = 8 -- a tile is redrawn at the latest this many frames after it changed, even over the redraw budget

-- Primitive arrays (reused between frames, no per-frame allocation)
local pr_a, pr_b, pr_c, pr_d, pr_t, pr_g = {}, {}, {}, {}, {}, {} -- vertices (pr_d == false -> triangle), texture, gradient kind
local pr_cx0, pr_cy0, pr_cx1, pr_cy1 = {}, {}, {}, {}  -- clip (screen pixels)
local pr_bx0, pr_by0, pr_bx1, pr_by1 = {}, {}, {}, {}  -- clipped bounds (screen pixels)
local pr_tex = {}                                      -- texture id
local pr_vb = {}                                       -- vertex buffer (draw list VtxBuffer.Buf)
local pr_k = {}                                        -- layer kind (1..3)
local plist1, plist2, plist3 = {}, {}, {}              -- primitive indices per layer kind
local cm_free, cm_kind, cm_x0, cm_y0, cm_x1, cm_y1 = {}, {}, {}, {}, {}, {} -- per draw command (collect -> Snapshot)

@native
local function HashVertex(h1, h2, vbuf, v, ox, oy)
    local x, y = readf64(vbuf, v) - ox, readf64(vbuf, v + 8) - oy
    local uv = readf64(vbuf, v + 16) * 8192 + readf64(vbuf, v + 24)
    local c = readu32(vbuf, v + 32)
    h1 = (h1 * 48271 + x * 4096 + y) % P1
    h1 = (h1 * 48271 + uv * 4096) % P1
    h1 = (h1 * 48271 + c) % P1
    h2 = (h2 * 16807 + y * 4093 + x) % P2
    h2 = (h2 * 16807 + uv * 65521) % P2
    h2 = (h2 * 16807 + c) % P2
    return h1, h2
end

-- Axis aligned quad with a linear colour gradient and constant uv (ColorPicker hue/SV/alpha bars, AddRectFilledMultiColor).
-- kind 1: colour varies along y (ca top, cb bottom), kind 2: along x (ca left, cb right). Same pixels as the two triangles.
@native
local function DrawRectGradient(x0, y0, x1, y1, ca, cb, kind, t, u, v, cx0, cy0, cx1, cy1)
    local px0, py0 = max(ceil(x0 - 0.5), cx0), max(ceil(y0 - 0.5), cy0)
    local px1, py1 = min(ceil(x1 - 0.5), cx1), min(ceil(y1 - 0.5), cy1)
    if px0 >= px1 or py0 >= py1 then return end
    local ra, ga, ba, aa = UnpackColor(ca)
    local rb, gb, bb, ab = UnpackColor(cb)
    if t then
        local tr, tg, tb, ta = SampleTexture(t, u, v)
        ra, ga, ba, aa = ra * tr / 255, ga * tg / 255, ba * tb / 255, aa * ta / 255
        rb, gb, bb, ab = rb * tr / 255, gb * tg / 255, bb * tb / 255, ab * ta / 255
    end
    if kind == 1 then
        local inv = 1 / (y1 - y0)
        for y = py0, py1 - 1 do
            local f = (y + 0.5 - y0) * inv
            local nf = 1 - f
            FillSpan(y, px0, px1, ra * nf + rb * f, ga * nf + gb * f, ba * nf + bb * f, aa * nf + ab * f)
        end
    else
        -- Every row gets the same colours: when a row's destination equals the previous row's, copy its result
        local inv = 1 / (x1 - x0)
        local len = (px1 - px0) * 4
        local opaque = aa >= 255 and ab >= 255
        local prev_dst, prev_o = nil, 0
        for y = py0, py1 - 1 do
            local o = (y * buf_w + px0) * 4
            local dst = (not opaque) and readstring(buf, o, len) or true
            if prev_dst ~= nil and dst == prev_dst then
                buffer.copy(buf, o, buf, prev_o, len)
            else
                local oo = o
                for x = px0, px1 - 1 do
                    local f = (x + 0.5 - x0) * inv
                    local nf = 1 - f
                    BlendPixel(oo, ra * nf + rb * f, ga * nf + gb * f, ba * nf + bb * f, aa * nf + ab * f)
                    oo = oo + 4
                end
                prev_dst = dst
            end
            prev_o = o
        end
    end
end

-- Layer kinds per draw list: 1 = drawn before the window content (background, title bar, borders, scrollbar),
-- 2 = window content (positioned at the scroll origin inside a ClipsDescendants frame, so scrolling just moves it),
-- 3 = anything not clipped to the content drawn after content started (menu bar, overlays). Stacked 1 < 2 < 3.
local function NewFrame(parent, clips)
    local frame = Instance.new("Frame")
    frame.Name = "Layer"
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Size = UDim2.fromOffset(0, 0)
    frame.ClipsDescendants = clips
    frame.Visible = false
    frame.Parent = parent
    return frame
end

local function GetLayer(bd, draw_list, kind)
    local set = bd.Layers[draw_list]
    if not set then set = { LastUsed = 0 }; bd.Layers[draw_list] = set end
    local layer = set[kind]
    if layer then return layer end
    local root, frame
    if kind == 2 then
        root = NewFrame(bd.Gui, true)
        frame = NewFrame(root, false); frame.Visible = true
    else
        frame = NewFrame(bd.Gui, false); root = frame
    end
    layer = { Root = root, Frame = frame, Tiles = {}, TH1 = {}, TH2 = {}, TN = {}, TL = {}, TL1 = {}, TL2 = {}, TLF = {}, TX = {}, TY = {}, Touched = {}, NTouched = 0,
              Visible = false, X = false, Y = false, Z = -1, CX0 = false, CY0 = false, CX1 = false, CY1 = false }
    set[kind] = layer
    return layer
end

local function HideLayer(layer)
    if layer.Visible then layer.Visible = false; layer.Root.Visible = false end
end

local function GetTile(bd, layer, key, tx, ty)
    local tile = layer.Tiles[key]
    if tile then return tile end
    local img = AssetService:CreateEditableImage({ Size = Vector2.new(TILE, TILE) })
    assert(img, "imgui_impl_roblox: EditableImage memory budget exceeded")
    local label = Instance.new("ImageLabel")
    label.Name = "Tile" .. key
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    local scale = bd.Scale
    label.Size = UDim2.fromOffset(TILE / scale, TILE / scale)
    label.Position = UDim2.fromOffset(tx * TILE / scale, ty * TILE / scale)
    label.ResampleMode = Enum.ResamplerMode.Pixelated
    label.ImageContent = Content.fromObject(img)
    label.Visible = false
    label.Active = bd.TilesActive
    label.Parent = layer.Frame
    tile = { Image = img, Label = label, Buffer = buffer.create(TILE * TILE * 4), H1 = -1, H2 = -1, Visible = false, BX0 = TILE, BY0 = TILE, BX1 = 0, BY1 = 0,
             ON = -1, OH1 = {}, OH2 = {}, OF = {}, OB0 = {}, OB1 = {}, OB2 = {}, OB3 = {} } -- last drawn primitive list (hashes, bounds in tile)
    layer.Tiles[key] = tile
    return tile
end

local function DestroyLayerSet(set)
    for kind = 1, 3 do
        local layer = set[kind]
        if layer then
            for _, tile in pairs(layer.Tiles) do tile.Image:Destroy() end
            layer.Root:Destroy()
        end
    end
end

local function DestroyTiles(bd)
    for _, set in pairs(bd.Layers) do DestroyLayerSet(set) end
    bd.Layers = {}
end

-- Snapshot of everything in a draw list that affects its layers, compared exactly with the next frame's list:
-- 1 = identical (only restack), 2 = everything moved by the same whole pixels (dx, dy) (only move the layers: a window
-- being dragged), 0 = changed (full path). Compared in place (no strings built): early exit at the first difference.
local writef64 = buffer.writef64
local CMD_STRIDE = 70 -- clip (4 f64), ElemCount, IdxOffset, VtxOffset (u32), tex id (f64), kind (u8), free (u8), bounds of its primitives (4 x i32)

@native
local function Snapshot(set, draw_list, ox, oy, sw, sh)
    local nv = draw_list.VtxBuffer.Size * VTX_STRIDE
    local idx, ni = draw_list.IdxBuffer.Data, draw_list.IdxBuffer.Size
    local ncmd = draw_list.CmdBuffer.Size
    local sv, si, sc = set.SV, set.SI, set.SC
    if not sv or buffer.len(sv) < nv then sv = buffer.create(max(nv, 64) * 2); set.SV = sv end
    if not si or buffer.len(si) < ni * 4 then si = buffer.create(max(ni, 16) * 8); set.SI = si end
    if not sc or buffer.len(sc) < ncmd * CMD_STRIDE then sc = buffer.create(max(ncmd, 4) * CMD_STRIDE * 2); set.SC = sc end
    buffer.copy(sv, 0, draw_list.VtxBuffer.Buf, 0, nv)
    for i = 1, ni do writeu32(si, (i - 1) * 4, idx[i]) end
    local o, ci = 0, 0
    for _, pcmd in draw_list.CmdBuffer:iter() do
        if pcmd.UserCallback ~= nil then set.SnapOK = false; return end
        local c = pcmd.ClipRect
        writef64(sc, o, c.x); writef64(sc, o + 8, c.y); writef64(sc, o + 16, c.z); writef64(sc, o + 24, c.w)
        writeu32(sc, o + 32, pcmd.ElemCount); writeu32(sc, o + 36, pcmd.IdxOffset); writeu32(sc, o + 40, pcmd.VtxOffset)
        writef64(sc, o + 44, pcmd:GetTexID())
        ci += 1
        buffer.writeu8(sc, o + 52, cm_kind[ci] or 0); buffer.writeu8(sc, o + 53, cm_free[ci] and 1 or 0)
        if cm_free[ci] then
            buffer.writei32(sc, o + 54, cm_x0[ci]); buffer.writei32(sc, o + 58, cm_y0[ci]); buffer.writei32(sc, o + 62, cm_x1[ci]); buffer.writei32(sc, o + 66, cm_y1[ci])
        end
        o += CMD_STRIDE
    end
    set.SVN, set.SIN, set.SCN = nv, ni, ncmd
    set.SOX, set.SOY, set.SSW, set.SSH = ox, oy, sw, sh
    set.SCC = draw_list._ContentClipX0 ~= nil
    set.SCX0, set.SCY0, set.SCX1, set.SCY1 = draw_list._ContentClipX0 or 0, draw_list._ContentClipY0 or 0, draw_list._ContentClipX1 or 0, draw_list._ContentClipY1 or 0
    set.SSX, set.SSY = draw_list._ScrollOriginX or 0, draw_list._ScrollOriginY or 0
    set.SnapOK = true
end

-- a + d == b exactly, with no rounding in a + d (so every later "x - origin" gives the same result as before the move)
@native
local function ShiftedExact(a, d, b)
    local s = a + d
    if s ~= b then return false end
    local bb = s - a
    return (a - (s - bb)) + (d - bb) == 0
end

@native
local function CompareDrawList(set, draw_list, ox, oy, sw, sh)
    if not set or not set.SnapOK then return 0 end
    local nv = draw_list.VtxBuffer.Size * VTX_STRIDE
    local ni, ncmd = draw_list.IdxBuffer.Size, draw_list.CmdBuffer.Size
    if nv ~= set.SVN or ni ~= set.SIN or ncmd ~= set.SCN or ox ~= set.SOX or oy ~= set.SOY or sw ~= set.SSW or sh ~= set.SSH then return 0 end
    if (draw_list._ContentClipX0 ~= nil) ~= set.SCC then return 0 end
    local vb, sv = draw_list.VtxBuffer.Buf, set.SV
    if nv == 0 then return 1 end
    -- translation from the first vertex: whole pixels only, and only with DisplayPos at 0 (so it stays exact)
    local dx, dy = readf64(vb, 0) - readf64(sv, 0), readf64(vb, 8) - readf64(sv, 8)
    if dx ~= dx or dy ~= dy then return 0 end
    if dx ~= 0 or dy ~= 0 then
        if dx ~= floor(dx) or dy ~= floor(dy) or ox ~= 0 or oy ~= 0 or not set.SLimFree then return 0 end
        -- everything must stay as far from the clip limits as before (nothing newly clamped)
        if set.SEX0 + dx < -CLIP_PAD or set.SEY0 + dy < -CLIP_PAD or set.SEX1 + dx > sw + CLIP_PAD or set.SEY1 + dy > sh + CLIP_PAD then return 0 end
    end
    local idx, si = draw_list.IdxBuffer.Data, set.SI
    for i = 1, ni do if idx[i] ~= readu32(si, (i - 1) * 4) then return 0 end end
    local sc, o = set.SC, 0
    local ccx0, ccy0, ccx1, ccy1 = draw_list._ContentClipX0, draw_list._ContentClipY0, draw_list._ContentClipX1, draw_list._ContentClipY1
    local seen_content = false
    for _, pcmd in draw_list.CmdBuffer:iter() do
        if pcmd.UserCallback ~= nil then return 0 end
        if pcmd.ElemCount ~= readu32(sc, o + 32) or pcmd.IdxOffset ~= readu32(sc, o + 36) or pcmd.VtxOffset ~= readu32(sc, o + 40) or pcmd:GetTexID() ~= readf64(sc, o + 44) then return 0 end
        local c = pcmd.ClipRect
        if dx == 0 and dy == 0 then
            if c.x ~= readf64(sc, o) or c.y ~= readf64(sc, o + 8) or c.z ~= readf64(sc, o + 16) or c.w ~= readf64(sc, o + 24) then return 0 end
        elseif not (ShiftedExact(readf64(sc, o), dx, c.x) and ShiftedExact(readf64(sc, o + 8), dy, c.y)
            and ShiftedExact(readf64(sc, o + 16), dx, c.z) and ShiftedExact(readf64(sc, o + 24), dy, c.w)) then
            -- An unchanged clip rect (e.g. the viewport) is fine if it clipped none of this command's primitives before
            -- the move and still clips none after it
            if c.x ~= readf64(sc, o) or c.y ~= readf64(sc, o + 8) or c.z ~= readf64(sc, o + 16) or c.w ~= readf64(sc, o + 24)
                or buffer.readu8(sc, o + 53) == 0 then return 0 end
            if buffer.readi32(sc, o + 54) + dx < floor(c.x) or buffer.readi32(sc, o + 58) + dy < floor(c.y)
                or buffer.readi32(sc, o + 62) + dx > floor(c.z) or buffer.readi32(sc, o + 66) + dy > floor(c.w) then return 0 end
        end
        -- same layer kind as before (same rule as the collect pass)
        if pcmd.ElemCount > 0 then
            local kind = 1
            if ccx0 and c.x >= ccx0 and c.y >= ccy0 and c.z <= ccx1 and c.w <= ccy1 then kind = 2; seen_content = true
            elseif seen_content then kind = 3 end
            if kind ~= buffer.readu8(sc, o + 52) then return 0 end
        end
        o += CMD_STRIDE
    end
    if dx == 0 and dy == 0 then
        if set.SCC and (draw_list._ContentClipX0 ~= set.SCX0 or draw_list._ContentClipY0 ~= set.SCY0 or draw_list._ContentClipX1 ~= set.SCX1
            or draw_list._ContentClipY1 ~= set.SCY1 or draw_list._ScrollOriginX ~= set.SSX or draw_list._ScrollOriginY ~= set.SSY) then return 0 end
        for v = 0, nv - VTX_STRIDE, VTX_STRIDE do
            if readf64(vb, v) ~= readf64(sv, v) or readf64(vb, v + 8) ~= readf64(sv, v + 8) or readf64(vb, v + 16) ~= readf64(sv, v + 16)
                or readf64(vb, v + 24) ~= readf64(sv, v + 24) or readu32(vb, v + 32) ~= readu32(sv, v + 32) then return 0 end
        end
        return 1
    end
    if set.SCC and not (ShiftedExact(set.SCX0, dx, draw_list._ContentClipX0) and ShiftedExact(set.SCY0, dy, draw_list._ContentClipY0)
        and ShiftedExact(set.SCX1, dx, draw_list._ContentClipX1) and ShiftedExact(set.SCY1, dy, draw_list._ContentClipY1)
        and ShiftedExact(set.SSX, dx, draw_list._ScrollOriginX) and ShiftedExact(set.SSY, dy, draw_list._ScrollOriginY)) then return 0 end
    for v = 0, nv - VTX_STRIDE, VTX_STRIDE do
        if not ShiftedExact(readf64(sv, v), dx, readf64(vb, v)) or not ShiftedExact(readf64(sv, v + 8), dy, readf64(vb, v + 8))
            or readf64(vb, v + 16) ~= readf64(sv, v + 16) or readf64(vb, v + 24) ~= readf64(sv, v + 24) or readu32(vb, v + 32) ~= readu32(sv, v + 32) then return 0 end
    end
    return 2, dx, dy
end

-- A window moved by whole pixels: its tiles are unchanged, only the layer frames move
local function ShiftLayer(layer, dx, dy, scale)
    layer.X += dx; layer.Y += dy
    local root = layer.Root
    if root ~= layer.Frame then
        layer.CX0 += dx; layer.CY0 += dy; layer.CX1 += dx; layer.CY1 += dy
        root.Position = UDim2.fromOffset(layer.CX0 / scale, layer.CY0 / scale)
    else
        root.Position = UDim2.fromOffset(layer.X / scale, layer.Y / scale)
    end
end

-- Overlays: user Instances (e.g. a Frame holding a ViewportFrame) placed inside a window, registered every frame with
-- ImGui_ImplRoblox.SetOverlay() while that window is current. They stack right above the window's layers, move with
-- it, and (clip = true) are clipped to the window's content area like its widgets.
local function OverlayHolder(bd, draw_list, clip)
    local hs = bd.OverlayHolders[draw_list]
    if not hs then hs = {}; bd.OverlayHolders[draw_list] = hs end
    local h = hs[clip]
    if not h then
        h = Instance.new("Frame")
        h.Name = clip and "OverlayClip" or "Overlay"
        h.BackgroundTransparency = 1
        h.BorderSizePixel = 0
        h.ClipsDescendants = clip
        h.Size = UDim2.fromOffset(0, 0)
        h.Parent = bd.Gui
        hs[clip] = h
    end
    return h
end

local function PlaceOverlays(bd, draw_list, z, ox, oy)
    local list = bd.Overlays[draw_list]
    local hs = bd.OverlayHolders[draw_list]
    if not list then
        if hs then for _, h in pairs(hs) do h.Visible = false end end
        return z
    end
    local scale, frame_no = bd.Scale, bd.FrameNo
    z += 1
    local used = {}
    for _, o in ipairs(list) do
        local clip = o.Clip and draw_list._ContentClipX0 ~= nil
        local h = OverlayHolder(bd, draw_list, clip)
        local hx, hy = 0, 0
        if clip then
            hx, hy = draw_list._ContentClipX0 - ox, draw_list._ContentClipY0 - oy
            if not used[h] then
                h.Position = UDim2.fromOffset(hx / scale, hy / scale)
                h.Size = UDim2.fromOffset((draw_list._ContentClipX1 - draw_list._ContentClipX0) / scale, (draw_list._ContentClipY1 - draw_list._ContentClipY0) / scale)
            end
        elseif not used[h] then
            h.Position = UDim2.fromOffset(0, 0)
        end
        used[h] = true
        h.ZIndex = z
        h.Visible = true
        local f = o.Frame
        if f.Parent ~= h then f.Parent = h end
        f.Position = UDim2.fromOffset((o.X - ox - hx) / scale, (o.Y - oy - hy) / scale)
        f.Size = UDim2.fromOffset(o.W / scale, o.H / scale)
        f.Visible = true
        bd.OverlayShown[f] = frame_no
    end
    if hs then for _, h in pairs(hs) do if not used[h] then h.Visible = false end end end
    return z
end

--- Show `frame` this frame at (x, y, w, h) (imgui coordinates) inside the current window. Call every frame it should
--- be visible; frames not submitted are hidden. clip: clip to the window's content area (scrolls with it).
function ImGui_ImplRoblox_SetOverlay(frame, x, y, w, h, clip)
    local bd = ImGui_ImplRoblox_GetBackendData()
    local dl = ImGui.GetWindowDrawList()
    local list = bd.Overlays[dl]
    if not list then list = {}; bd.Overlays[dl] = list end
    list[#list + 1] = { Frame = frame, X = x, Y = y, W = w, H = h, Clip = clip ~= false }
end

-- MicroProfiler labels, enabled with ImGui_ImplRoblox.SetProfiling(true)
local profilebegin, profileend = debug.profilebegin, debug.profileend
local profiling = false
local function PB(name) if profiling then profilebegin(name) end end
local function PE() if profiling then profileend() end end

@native
local function DrawLayer(bd, layer, plist, np, lx0, ly0, ox, oy, force, z, clip_x0, clip_y0, clip_x1, clip_y1)
    local scale = bd.Scale
    local deferred = false
    -- Pass 2: hash primitives into layer-relative tiles
    PB("ImGui tile hash")
    local th1, th2, tn, tl, touched = layer.TH1, layer.TH2, layer.TN, layer.TL, layer.Touched
    local tl1, tl2, tlf = layer.TL1, layer.TL2, layer.TLF -- per-tile list of the primitives' hashes (for partial redraws)
    for k = 1, layer.NTouched do tn[touched[k]] = 0 end
    local nt = 0
    for pi = 1, np do
        local p = plist[pi]
        local tex_id = pr_tex[p]
        -- The clip rect only affects pixels inside the primitive's bounds, so hash the clipped bounds (relative)
        -- instead of the clip itself: a window clipped by the (fixed) viewport rect stays hash-stable when moved.
        local cx0, cy0, cx1, cy1 = pr_bx0[p] - lx0, pr_by0[p] - ly0, pr_bx1[p] - lx0, pr_by1[p] - ly0
        local vbuf = pr_vb[p]
        local va, vd = pr_a[p], pr_d[p]
        -- Flat rect (single colour, no gradient, constant uv): its pixels in a tile are exactly its clipped pixel rect
        -- inside that tile filled with one colour, so hash that per tile instead of the vertices. Resizing a window
        -- then only changes the tiles its edges cross, not every tile its background covers.
        local flat_rect, rcol, ruv = false, 0, 0
        if vd and not pr_g[p] then
            local u0, v0 = readf64(vbuf, va + 16), readf64(vbuf, va + 24)
            local vc = pr_c[p]
            if not pr_t[p] or (u0 == readf64(vbuf, vc + 16) and v0 == readf64(vbuf, vc + 24)) then
                flat_rect, rcol, ruv = true, readu32(vbuf, va + 32), u0 * 8192 + v0
            end
        end
        local h1, h2 = 0, 0
        local fsig = -1 -- flat rect: colour/uv/texture without the geometry (-1: not a flat rect)
        if flat_rect then fsig = ((rcol * 8191 + ruv * 4096) % P1 * 64 + tex_id) % P1 end
        if not flat_rect then
            h1 = ((cx0 * 8191 + cy0) * 8191 + cx1) % P1
            h2 = ((cy1 * 8191 + cx1) * 8191 + cy0 + tex_id) % P2
            local vax, vay = lx0 + ox, ly0 + oy
            if vd then
                -- Axis aligned quad: the collect pass checked that TR/BL (positions, uvs, colours) follow from TL/BR
                -- (and the gradient kind), so TL + BR + kind determine its pixels
                h1, h2 = HashVertex(h1, h2, vbuf, va, vax, vay)
                h1, h2 = HashVertex(h1, h2, vbuf, pr_c[p], vax, vay)
                local gk = pr_g[p]
                if gk then h1 = (h1 * 48271 + gk) % P1; h2 = (h2 * 16807 + gk * 3) % P2 end
            else
                h1, h2 = HashVertex(h1, h2, vbuf, va, vax, vay)
                h1, h2 = HashVertex(h1, h2, vbuf, pr_b[p], vax, vay)
                h1, h2 = HashVertex(h1, h2, vbuf, pr_c[p], vax, vay)
            end
        end
        for ty = floor((pr_by0[p] - ly0) / TILE), floor((pr_by1[p] - 1 - ly0) / TILE) do
            for tx = floor((pr_bx0[p] - lx0) / TILE), floor((pr_bx1[p] - 1 - lx0) / TILE) do
                if flat_rect then
                    local tx0, ty0 = tx * TILE, ty * TILE
                    local ix0, iy0 = max(cx0 - tx0, 0), max(cy0 - ty0, 0)
                    local ix1, iy1 = min(cx1 - tx0, TILE), min(cy1 - ty0, TILE)
                    local r = ((ix0 * 131 + iy0) * 131 + ix1) * 131 + iy1
                    h1 = ((r * 48271 + rcol) % P1 * 48271 + ruv * 4096 + 7) % P1
                    h2 = ((r * 16807 + rcol + tex_id) % P2 * 16807 + ruv * 65521 + 11) % P2
                end
                local key = ty * KEY_W + tx
                local k = tn[key]
                if not k or k == 0 then
                    k = 0
                    th1[key], th2[key] = 0, 0
                    if not tl[key] then tl[key] = {}; tl1[key] = {}; tl2[key] = {}; tlf[key] = {} end
                    nt = nt + 1
                    touched[nt] = key
                    layer.TX[key], layer.TY[key] = tx, ty
                end
                k = k + 1
                tn[key] = k
                tl[key][k] = p
                tl1[key][k], tl2[key][k], tlf[key][k] = h1, h2, fsig
                th1[key] = (th1[key] * 48271 + h1) % P1
                th2[key] = (th2[key] * 16807 + h2 + k) % P2
            end
        end
    end
    layer.NTouched = nt
    PE()

    -- Place the layer (this is all a window move costs)
    local root = layer.Root
    if root ~= layer.Frame then
        -- content: clip frame at the content clip rect, tiles frame at the scroll origin relative to it
        if layer.CX0 ~= clip_x0 or layer.CY0 ~= clip_y0 or layer.CX1 ~= clip_x1 or layer.CY1 ~= clip_y1 then
            layer.CX0, layer.CY0, layer.CX1, layer.CY1 = clip_x0, clip_y0, clip_x1, clip_y1
            root.Position = UDim2.fromOffset(clip_x0 / scale, clip_y0 / scale)
            root.Size = UDim2.fromOffset((clip_x1 - clip_x0) / scale, (clip_y1 - clip_y0) / scale)
            layer.X = false
        end
        if layer.X ~= lx0 or layer.Y ~= ly0 then
            layer.X, layer.Y = lx0, ly0
            layer.Frame.Position = UDim2.fromOffset((lx0 - clip_x0) / scale, (ly0 - clip_y0) / scale)
        end
    elseif layer.X ~= lx0 or layer.Y ~= ly0 then
        layer.X, layer.Y = lx0, ly0
        root.Position = UDim2.fromOffset(lx0 / scale, ly0 / scale)
    end
    if layer.Z ~= z then layer.Z = z; root.ZIndex = z end
    if not layer.Visible then layer.Visible = true; root.Visible = true end

    -- Pass 3: redraw + upload changed tiles, hide unused ones
    PB("ImGui raster+upload")
    for key, tile in pairs(layer.Tiles) do
        if not tn[key] or tn[key] == 0 then
            if tile.Visible then tile.Visible = false; tile.Label.Visible = false; tile.H1 = -1; tile.ON = -1 end
        end
    end
    for kk = 1, nt do
        local key = touched[kk]
        local count = tn[key]
        local tx, ty = layer.TX[key], layer.TY[key]
        local tile = GetTile(bd, layer, key, tx, ty)
        local dirty = force or tile.H1 ~= th1[key] or tile.H2 ~= th2[key]
        if dirty and bd.RedrawStarted and (tile.Deferred or 0) < MAX_DEFER_FRAMES
            and ((bd.RedrawBudget > 0 and os.clock() - bd.FrameT0 >= bd.RedrawBudget) or (bd.TileLimit and bd.FrameTiles >= bd.TileLimit)) then -- (TileLimit: test hook, tools/test/scripts/t_pixels.luau)
            -- Over this frame's redraw budget: keep showing the old pixels, redraw on a following frame. The tile's
            -- stored hashes/list still describe what it shows, so the next comparison is against the real content.
            tile.Deferred = (tile.Deferred or 0) + 1
            if force then tile.H1 = -1; tile.ON = -1 end -- full redraw later (force doesn't persist)
            deferred = true
            dirty = false
        end
        if dirty then
            bd.RedrawStarted = true
            bd.FrameTiles += 1
            tile.Deferred = 0
            tile.H1, tile.H2 = th1[key], th2[key]
            local x0, y0 = lx0 + tx * TILE, ly0 + ty * TILE
            local x1, y1 = x0 + TILE, y0 + TILE
            buf, buf_w = tile.Buffer, TILE
            local list, lh1, lh2 = tl[key], tl1[key], tl2[key]
            local oh1, oh2, ob0, ob1, ob2, ob3, on = tile.OH1, tile.OH2, tile.OB0, tile.OB1, tile.OB2, tile.OB3, tile.ON
            -- New content bounds (union of the primitives' bounds in this tile)
            local nx0, ny0, nx1, ny1 = TILE, TILE, 0, 0
            for k = 1, count do
                local p = list[k]
                local a, b = pr_bx0[p] - x0, pr_by0[p] - y0
                local c, d = pr_bx1[p] - x0, pr_by1[p] - y0
                if a < nx0 then nx0 = a end
                if b < ny0 then ny0 = b end
                if c > nx1 then nx1 = c end
                if d > ny1 then ny1 = d end
            end
            nx0, ny0, nx1, ny1 = max(nx0, 0), max(ny0, 0), min(nx1, TILE), min(ny1, TILE)
            local rx0, ry0, rx1, ry1
            if force or on < 0 then
                -- Dirty region = old content bounds + new content bounds. Outside it the tile is already
                -- transparent, so only this region is cleared and uploaded (edge tiles are often mostly empty).
                rx0, ry0, rx1, ry1 = min(nx0, tile.BX0), min(ny0, tile.BY0), max(nx1, tile.BX1), max(ny1, tile.BY1)
            else
                -- Partial redraw: the primitives before the first and after the last changed one are the same as last
                -- time. A pixel that no changed primitive (old or new) touches is covered by the same primitives in the
                -- same order, so it is already correct: only the bounds of the changed ones are cleared and redrawn.
                local i, lim = 1, min(on, count)
                while i <= lim and oh1[i] == lh1[i] and oh2[i] == lh2[i] do i += 1 end
                local j = 0
                while j <= lim - i and oh1[on - j] == lh1[count - j] and oh2[on - j] == lh2[count - j] do j += 1 end
                rx0, ry0, rx1, ry1 = TILE, TILE, 0, 0
                local of, lf = tile.OF, tlf[key]
                local paired = on - j - i == count - j - i
                for k = i, count - j do
                    local p = list[k]
                    local a, b, c, d = max(pr_bx0[p] - x0, 0), max(pr_by0[p] - y0, 0), min(pr_bx1[p] - x0, TILE), min(pr_by1[p] - y0, TILE)
                    local oa, ob, oc, od = ob0[k], ob1[k], ob2[k], ob3[k]
                    if paired and lf[k] >= 0 and lf[k] == of[k] then
                        -- Same flat rect (colour/uv/texture) with new bounds: pixels inside both are unchanged, only the
                        -- strips between the old and new edges can differ (e.g. a window background growing on resize)
                        local uy0, uy1 = min(b, ob), max(d, od)
                        local ux0, ux1 = min(a, oa), max(c, oc)
                        if a ~= oa then ux0 = min(a, oa); local e = max(a, oa); rx0 = min(rx0, ux0); rx1 = max(rx1, e); ry0 = min(ry0, uy0); ry1 = max(ry1, uy1) end
                        if c ~= oc then local e = min(c, oc); rx0 = min(rx0, e); rx1 = max(rx1, max(c, oc)); ry0 = min(ry0, uy0); ry1 = max(ry1, uy1) end
                        if b ~= ob then ry0 = min(ry0, min(b, ob)); ry1 = max(ry1, max(b, ob)); rx0 = min(rx0, ux0); rx1 = max(rx1, ux1) end
                        if d ~= od then ry0 = min(ry0, min(d, od)); ry1 = max(ry1, max(d, od)); rx0 = min(rx0, ux0); rx1 = max(rx1, ux1) end
                    else
                        if a < rx0 then rx0 = a end
                        if b < ry0 then ry0 = b end
                        if c > rx1 then rx1 = c end
                        if d > ry1 then ry1 = d end
                        if k <= on - j then
                            if oa < rx0 then rx0 = oa end
                            if ob < ry0 then ry0 = ob end
                            if oc > rx1 then rx1 = oc end
                            if od > ry1 then ry1 = od end
                        end
                    end
                end
                for k = count - j + 1, on - j do -- old middle longer than the new one
                    if ob0[k] < rx0 then rx0 = ob0[k] end
                    if ob1[k] < ry0 then ry0 = ob1[k] end
                    if ob2[k] > rx1 then rx1 = ob2[k] end
                    if ob3[k] > ry1 then ry1 = ob3[k] end
                end
            end
            tile.BX0, tile.BY0, tile.BX1, tile.BY1 = nx0, ny0, nx1, ny1
            -- Remember this list for the next partial redraw
            for k = 1, count do
                local p = list[k]
                oh1[k], oh2[k], tile.OF[k] = lh1[k], lh2[k], tlf[key][k]
                ob0[k], ob1[k], ob2[k], ob3[k] = max(pr_bx0[p] - x0, 0), max(pr_by0[p] - y0, 0), min(pr_bx1[p] - x0, TILE), min(pr_by1[p] - y0, TILE)
            end
            tile.ON = count
            local rw = rx1 - rx0
            if rw == TILE then
                buffer.fill(buf, ry0 * TILE * 4, 0, (ry1 - ry0) * TILE * 4)
            else
                for y = ry0, ry1 - 1 do buffer.fill(buf, (y * TILE + rx0) * 4, 0, rw * 4) end
            end
            local tox, toy = ox + x0, oy + y0
            for k = 1, count do
                local p = list[k]
                -- clip to the dirty region (only those pixels are redrawn)
                local cx0, cy0 = max(pr_cx0[p] - x0, rx0), max(pr_cy0[p] - y0, ry0)
                local cx1, cy1 = min(pr_cx1[p] - x0, rx1), min(pr_cy1[p] - y0, ry1)
                if cx0 >= cx1 or cy0 >= cy1 or pr_bx0[p] - x0 >= rx1 or pr_by0[p] - y0 >= ry1 or pr_bx1[p] - x0 <= rx0 or pr_by1[p] - y0 <= ry0 then continue end
                local va, vc, vd, vbuf = pr_a[p], pr_c[p], pr_d[p], pr_vb[p]
                if vd then
                    local ax, ay, cx, cy = readf64(vbuf, va) - tox, readf64(vbuf, va + 8) - toy, readf64(vbuf, vc) - tox, readf64(vbuf, vc + 8) - toy
                    local gk = pr_g[p]
                    if gk then
                        DrawRectGradient(ax, ay, cx, cy, readu32(vbuf, va + 32), readu32(vbuf, vc + 32), gk, pr_t[p], readf64(vbuf, va + 16), readf64(vbuf, va + 24), cx0, cy0, cx1, cy1)
                    else
                        DrawRect(ax, ay, cx, cy, readf64(vbuf, va + 16), readf64(vbuf, va + 24), readf64(vbuf, vc + 16), readf64(vbuf, vc + 24), readu32(vbuf, va + 32), pr_t[p], cx0, cy0, cx1, cy1)
                    end
                else
                    DrawTriangle(vbuf, va, pr_b[p], vc, pr_t[p], cx0, cy0, cx1, cy1, tox, toy)
                end
            end
            PB("ImGui upload")
            if rw == TILE and ry0 == 0 and ry1 == TILE then
                tile.Image:WritePixelsBuffer(Vector2.zero, TILE_SIZE, buf)
            elseif rw > 0 and ry1 > ry0 then
                local rh = ry1 - ry0
                local sk = rw * 1024 + rh -- partial upload buffers are reused (WritePixelsBuffer needs the exact size)
                local sub = sub_bufs[sk]
                if not sub then
                    if n_sub_bufs >= 256 then table.clear(sub_bufs); n_sub_bufs = 0 end
                    sub = buffer.create(rw * rh * 4); sub_bufs[sk] = sub; n_sub_bufs += 1
                end
                for y = 0, rh - 1 do buffer.copy(sub, y * rw * 4, buf, ((ry0 + y) * TILE + rx0) * 4, rw * 4) end
                tile.Image:WritePixelsBuffer(Vector2.new(rx0, ry0), Vector2.new(rw, rh), sub)
            end
            PE()
        end
        if not tile.Visible and (tile.Deferred or 0) == 0 then -- (a deferred tile that was hidden holds old pixels: stays hidden until drawn)
            tile.Visible = true
            tile.Label.Visible = true
        end
    end
    PE()
    return deferred
end

@native
function ImGui_ImplRoblox_RenderDrawData(draw_data)
    local bd = ImGui_ImplRoblox_GetBackendData()
    PB("ImGui RenderDrawData")
    bd.FrameT0 = os.clock()
    bd.FrameTiles = 0
    bd.RedrawStarted = false -- the first dirty tile of a frame is always redrawn (progress), the rest within the budget
    bd.Stale = nil

    PB("ImGui textures")
    if draw_data.Textures ~= nil then
        for _, tex in draw_data.Textures:iter() do
            if tex.Status ~= ImTextureStatus.OK then
                -- No redraw needed for WantUpdates: it only writes texture portions which have never been used before
                -- (new glyphs/rects), so no existing tile samples them. Created textures get a new (never reused) id.
                ImGui_ImplRoblox_UpdateTexture(tex)
            end
        end
    end
    PE()

    -- Render rate cap: textures are always updated (imgui expects it), tiles only at bd.RenderRate Hz
    -- Optional lower cap while scrolling / resizing / moving a window (SetBusyRenderRate, off by default)
    local rate = bd.RenderRate
    if bd.BusyRenderRate > 0 then
        local g = ImGui.GetCurrentContext()
        local busy = g.WheelingWindow ~= nil or g.MovingWindow ~= nil -- (io.MouseWheel is already cleared by EndFrame)
        if not busy and g.ActiveId ~= 0 then
            local w = g.ActiveIdWindow
            local cur = g.MouseCursor -- ResizeAll..ResizeNWSE while a resize grip/border is held
            busy = (cur >= ImGuiMouseCursor.ResizeAll and cur <= ImGuiMouseCursor.ResizeNWSE)
                or (w ~= nil and (g.ActiveId == ImGui.GetWindowScrollbarID(w, ImGuiAxis.X) or g.ActiveId == ImGui.GetWindowScrollbarID(w, ImGuiAxis.Y)))
        end
        if busy and (rate <= 0 or bd.BusyRenderRate < rate) then rate = bd.BusyRenderRate end
    end
    if rate > 0 then
        local now = os.clock()
        -- Skipped: kept pending, so if no new frame comes (the app stopped rendering) Heartbeat still draws it
        if now + 0.002 < bd.NextRender then bd.Pending = draw_data; PE(); return end
        bd.NextRender = math.max(bd.NextRender + 1 / rate, now)
    end

    local sw, sh = floor(draw_data.DisplaySize.x), floor(draw_data.DisplaySize.y)
    if sw <= 0 or sh <= 0 then PE(); return end
    local ox, oy = draw_data.DisplayPos.x, draw_data.DisplayPos.y
    local lim_x0, lim_y0, lim_x1, lim_y1 = -CLIP_PAD, -CLIP_PAD, sw + CLIP_PAD, sh + CLIP_PAD
    bd.FrameNo += 1
    local frame_no = bd.FrameNo
    local force = bd.ForceRedraw
    bd.ForceRedraw = false

    local n = 0
    local z = 0
    local any_deferred = false
    for _, draw_list in draw_data.CmdLists:iter() do
        -- Unchanged draw list (same vertices, indices, commands, origin and scroll): its layers are already correct,
        -- only restack them. Moved by whole pixels (a dragged window): only move its layers. Either way no collect + hash.
        PB("ImGui unchanged check")
        local set = bd.Layers[draw_list]
        local same, sdx, sdy = 0, 0, 0
        if not force then same, sdx, sdy = CompareDrawList(set, draw_list, ox, oy, sw, sh) end
        if same ~= 0 then
            for kind = 1, 3 do
                local layer = set[kind]
                if layer and layer.Visible then
                    if same == 2 then ShiftLayer(layer, sdx, sdy, bd.Scale) end
                    z += 1
                    if layer.Z ~= z then layer.Z = z; layer.Root.ZIndex = z end
                end
            end
            if same == 2 then
                Snapshot(set, draw_list, ox, oy, sw, sh)
                set.SEX0 += sdx; set.SEY0 += sdy; set.SEX1 += sdx; set.SEY1 += sdy
            end
            set.LastUsed = frame_no
            z = PlaceOverlays(bd, draw_list, z, ox, oy)
            PE()
            continue
        end
        PE()
        -- Pass 1: collect this list's primitives and their bounds
        PB("ImGui collect")
        local first = n + 1
        local vbuf, idx = draw_list.VtxBuffer.Buf, draw_list.IdxBuffer.Data
        local ccx0, ccy0, ccx1, ccy1 = draw_list._ContentClipX0, draw_list._ContentClipY0, draw_list._ContentClipX1, draw_list._ContentClipY1
        local content_x0, content_y0, content_x1, content_y1
        if ccx0 then
            content_x0, content_y0 = max(floor(ccx0 - ox), lim_x0), max(floor(ccy0 - oy), lim_y0)
            content_x1, content_y1 = min(floor(ccx1 - ox), lim_x1), min(floor(ccy1 - oy), lim_y1)
        end
        local seen_content = false
        -- extents of everything clamped by the clip limits below (lim_free: nothing was), for the move fast path
        local ex0, ey0, ex1, ey1 = math.huge, math.huge, -math.huge, -math.huge
        local lim_free = true
        if ccx0 then
            local a, b, c, d = floor(ccx0 - ox), floor(ccy0 - oy), floor(ccx1 - ox), floor(ccy1 - oy)
            if a < lim_x0 or b < lim_y0 or c > lim_x1 or d > lim_y1 then lim_free = false end
            ex0, ey0, ex1, ey1 = min(ex0, a), min(ey0, b), max(ex1, c), max(ey1, d)
        end
        local ci = 0
        for _, pcmd in draw_list.CmdBuffer:iter() do
            ci += 1
            cm_free[ci], cm_kind[ci] = false, 0
            if pcmd.UserCallback ~= nil then
                pcmd.UserCallback(draw_list, pcmd)
            elseif pcmd.ElemCount > 0 then
                local clip = pcmd.ClipRect
                local rcx0, rcy0, rcx1, rcy1 = floor(clip.x - ox), floor(clip.y - oy), floor(clip.z - ox), floor(clip.w - oy)
                if rcx0 < lim_x0 or rcy0 < lim_y0 or rcx1 > lim_x1 or rcy1 > lim_y1 then lim_free = false end
                if rcx0 < ex0 then ex0 = rcx0 end
                if rcy0 < ey0 then ey0 = rcy0 end
                if rcx1 > ex1 then ex1 = rcx1 end
                if rcy1 > ey1 then ey1 = rcy1 end
                local cx0, cy0 = max(rcx0, lim_x0), max(rcy0, lim_y0)
                local cx1, cy1 = min(rcx1, lim_x1), min(rcy1, lim_y1)
                local kind = 1
                if ccx0 and clip.x >= ccx0 and clip.y >= ccy0 and clip.z <= ccx1 and clip.w <= ccy1 then
                    kind = 2; seen_content = true
                    if clip.x == ccx0 and clip.y == ccy0 and clip.z == ccx1 and clip.w == ccy1 then
                        -- clipped by the layer's clip frame instead: partly visible rows stay hash-stable while scrolling
                        cx0, cy0, cx1, cy1 = lim_x0, lim_y0, lim_x1, lim_y1
                    end
                elseif seen_content then
                    kind = 3
                end
                cm_kind[ci] = kind
                local cfree, cex0, cey0, cex1, cey1 = cx1 > cx0 and cy1 > cy0, math.huge, math.huge, -math.huge, -math.huge
                if cx1 > cx0 and cy1 > cy0 then
                    local tex_id = pcmd:GetTexID()
                    local t = bd.Textures[tex_id]
                    local vo = pcmd.VtxOffset
                    local i, last = pcmd.IdxOffset + 1, pcmd.IdxOffset + pcmd.ElemCount
                    while i <= last do
                        local ia, ic = idx[i], idx[i + 2]
                        -- byte offsets of the vertices (index is 1-based)
                        local va, vb, vc = (vo + ia - 1) * VTX_STRIDE, (vo + idx[i + 1] - 1) * VTX_STRIDE, (vo + ic - 1) * VTX_STRIDE
                        local vd = false
                        local gk = false
                        local pax, pay = readf64(vbuf, va), readf64(vbuf, va + 8)
                        local pbx, pby = readf64(vbuf, vb), readf64(vbuf, vb + 8)
                        local pcx, pcy = readf64(vbuf, vc), readf64(vbuf, vc + 8)
                        local bx0, by0, bx1, by1
                        if i + 5 <= last and idx[i + 3] == ia and idx[i + 4] == ic then
                            local d = (vo + idx[i + 5] - 1) * VTX_STRIDE
                            local pdx, pdy = readf64(vbuf, d), readf64(vbuf, d + 8)
                            -- axis aligned quad (TL, TR, BR, BL)
                            if pay == pby and pbx == pcx and pcy == pdy and pdx == pax and pax < pbx and pay < pdy then
                                local col, colb, colc, cold = readu32(vbuf, va + 32), readu32(vbuf, vb + 32), readu32(vbuf, vc + 32), readu32(vbuf, d + 32)
                                local tax, tay = readf64(vbuf, va + 16), readf64(vbuf, va + 24)
                                local tbx, tby = readf64(vbuf, vb + 16), readf64(vbuf, vb + 24)
                                local tcx, tcy = readf64(vbuf, vc + 16), readf64(vbuf, vc + 24)
                                local tdx, tdy = readf64(vbuf, d + 16), readf64(vbuf, d + 24)
                                if colb == col and colc == col and cold == col then
                                    if tbx == tcx and tby == tay and tdx == tax and tdy == tcy then vd = d end
                                elseif tax == tbx and tax == tcx and tax == tdx and tay == tby and tay == tcy and tay == tdy then
                                    -- constant uv, linear gradient: vertical (top/bottom pairs equal) or horizontal (left/right pairs equal)
                                    if colb == col and cold == colc then vd = d; gk = 1
                                    elseif cold == col and colb == colc then vd = d; gk = 2 end
                                end
                                if vd then
                                    bx0, by0 = ceil(pax - ox - 0.5), ceil(pay - oy - 0.5)
                                    bx1, by1 = ceil(pcx - ox - 0.5), ceil(pcy - oy - 0.5)
                                end
                            end
                        end
                        if vd then
                            i = i + 6
                        else
                            bx0, by0 = floor(min(pax, pbx, pcx) - ox), floor(min(pay, pby, pcy) - oy)
                            bx1, by1 = ceil(max(pax, pbx, pcx) - ox) + 1, ceil(max(pay, pby, pcy) - oy) + 1
                            i = i + 3
                        end
                        if bx0 < cx0 or by0 < cy0 or bx1 > cx1 or by1 > cy1 then cfree = false end
                        if bx0 < cex0 then cex0 = bx0 end
                        if by0 < cey0 then cey0 = by0 end
                        if bx1 > cex1 then cex1 = bx1 end
                        if by1 > cey1 then cey1 = by1 end
                        if bx0 < ex0 then ex0 = bx0 end
                        if by0 < ey0 then ey0 = by0 end
                        if bx1 > ex1 then ex1 = bx1 end
                        if by1 > ey1 then ey1 = by1 end
                        if bx0 < lim_x0 or by0 < lim_y0 or bx1 > lim_x1 or by1 > lim_y1 then lim_free = false end
                        if bx0 < cx0 then bx0 = cx0 end
                        if by0 < cy0 then by0 = cy0 end
                        if bx1 > cx1 then bx1 = cx1 end
                        if by1 > cy1 then by1 = cy1 end
                        if bx0 < bx1 and by0 < by1 then
                            n = n + 1
                            pr_a[n], pr_b[n], pr_c[n], pr_d[n], pr_t[n], pr_g[n], pr_tex[n], pr_vb[n] = va, vb, vc, vd, t, gk, tex_id, vbuf
                            pr_cx0[n], pr_cy0[n], pr_cx1[n], pr_cy1[n] = cx0, cy0, cx1, cy1
                            pr_bx0[n], pr_by0[n], pr_bx1[n], pr_by1[n] = bx0, by0, bx1, by1
                            pr_k[n] = kind
                        end
                    end
                end
                if cex0 > cex1 then cex0, cey0, cex1, cey1 = 0, 0, 0, 0 end -- (no primitives)
                cm_free[ci] = cfree
                cm_x0[ci], cm_y0[ci], cm_x1[ci], cm_y1[ci] = cex0, cey0, cex1, cey1
            end
        end
        PE()

        -- Split into layer kinds and place each one
        set = bd.Layers[draw_list]
        local list_deferred = false
        local nk1, nk2, nk3 = 0, 0, 0
        local o1x, o1y, o3x, o3y = math.huge, math.huge, math.huge, math.huge
        for p = first, n do
            local k = pr_k[p]
            if k == 1 then
                nk1 += 1; plist1[nk1] = p
                if pr_bx0[p] < o1x then o1x = pr_bx0[p] end
                if pr_by0[p] < o1y then o1y = pr_by0[p] end
            elseif k == 2 then
                nk2 += 1; plist2[nk2] = p
            else
                nk3 += 1; plist3[nk3] = p
                if pr_bx0[p] < o3x then o3x = pr_bx0[p] end
                if pr_by0[p] < o3y then o3y = pr_by0[p] end
            end
        end
        if nk1 > 0 then
            z += 1
            if DrawLayer(bd, GetLayer(bd, draw_list, 1), plist1, nk1, o1x, o1y, ox, oy, force, z) then list_deferred = true end
        elseif set and set[1] then HideLayer(set[1]) end
        if nk2 > 0 then
            z += 1
            if DrawLayer(bd, GetLayer(bd, draw_list, 2), plist2, nk2, floor(draw_list._ScrollOriginX - ox), floor(draw_list._ScrollOriginY - oy), ox, oy, force, z,
                content_x0, content_y0, content_x1, content_y1) then list_deferred = true end
        elseif set and set[2] then HideLayer(set[2]) end
        if nk3 > 0 then
            z += 1
            if DrawLayer(bd, GetLayer(bd, draw_list, 3), plist3, nk3, o3x, o3y, ox, oy, force, z) then list_deferred = true end
        elseif set and set[3] then HideLayer(set[3]) end
        set = bd.Layers[draw_list]
        -- (deferred tiles: not "unchanged" next frame even if the draw list is, so they get redrawn)
        if set then
            set.LastUsed = frame_no
            if list_deferred then set.SnapOK = false else
                Snapshot(set, draw_list, ox, oy, sw, sh)
                set.SLimFree = lim_free
                set.SEX0, set.SEY0, set.SEX1, set.SEY1 = ex0, ey0, ex1, ey1
            end
        end
        if list_deferred then any_deferred = true end
        z = PlaceOverlays(bd, draw_list, z, ox, oy)
    end

    -- Overlay frames not submitted this frame are hidden (never destroyed: the user owns them)
    for frame, shown in pairs(bd.OverlayShown) do
        if shown ~= frame_no then frame.Visible = false; bd.OverlayShown[frame] = nil end
    end
    table.clear(bd.Overlays)

    -- Hide layers not drawn this frame; free long unused ones (closed windows, old tooltips)
    for draw_list, set in pairs(bd.Layers) do
        if set.LastUsed ~= frame_no then
            set.SnapOK = false -- hidden now: must go through the full path when shown again
            for kind = 1, 3 do if set[kind] then HideLayer(set[kind]) end end
            if frame_no - set.LastUsed > LAYER_KEEP_FRAMES then
                DestroyLayerSet(set)
                bd.Layers[draw_list] = nil
            end
        end
    end

    -- drop references so old vertex tables can be collected
    for k = n + 1, bd.LastPrimCount do pr_t[k], pr_vb[k] = nil, nil end
    bd.LastPrimCount = n
    -- Tiles left for later: if the app doesn't submit a new frame, Heartbeat finishes them from this draw data
    if any_deferred then bd.Stale = draw_data; bd.StaleHB = bd.HB end
    PE()
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
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- layers (one Frame per draw list) stack by ZIndex
    gui.Parent = parent or Players.LocalPlayer:WaitForChild("PlayerGui")

    local bd = {
        Time = os.clock(), Gui = gui, Connections = {},
        Textures = {}, TextureCount = 0, MouseX = -1, MouseY = -1,
        Layers = {}, Overlays = {}, OverlayHolders = {}, OverlayShown = {}, FrameNo = 0, Scale = render_scale or 1, TilesActive = false, RenderRate = 60, BusyRenderRate = 0, RedrawBudget = 0, HB = 0, NextRender = 0, LastPrimCount = 0, ForceRedraw = true,
    }
    io.BackendPlatformUserData = bd
    io.BackendPlatformName = "imgui_impl_roblox"
    io.BackendRendererName = "imgui_impl_roblox"

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
        elseif input.UserInputType == Enum.UserInputType.Keyboard and (not game_processed or proxy_focused) then
            local ctrl, shift, alt = ImGui_ImplRoblox_UpdateKeyModifiers()
            local key = KEY_MAP[input.KeyCode]
            if key then io:AddKeyEvent(key, true) end
            if proxy_focused and (key == ImGuiKey.Backspace or key == ImGuiKey.Delete) then ImGui_ImplRoblox_GetBackendData().DeleteKeySeen = true end

            -- Text: printable ASCII keys, skipped while Ctrl/Alt are held (shortcuts)
            local v = input.KeyCode.Value
            if v >= 32 and v < 127 and not (ctrl or alt) then
                local c = string.char(v)
                if shift then c = SHIFTED[c] or c:upper() end
                -- While the proxy may own text input, hold the char: NewFrame uses the proxy's text if it changed
                -- (correct layout/unicode), otherwise these. So typing works even if the proxy silently lost focus.
                if proxy_focused then table.insert(ImGui_ImplRoblox_GetBackendData().PendingChars, string.byte(c))
                else io:AddInputCharacter(string.byte(c)) end
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

    bd.PendingChars = {}

    -- Render rate cap trailing edge: the last frame submitted is always drawn, even if it was skipped and the app
    -- then stopped calling NewFrame (e.g. it rendered one empty frame to hide its windows)
    connect(game:GetService("RunService").Heartbeat, function()
        local d = bd.Pending
        if d and os.clock() + 0.002 >= bd.NextRender then
            bd.Pending = nil
            ImGui_ImplRoblox_RenderDrawData(d)
        elseif bd.Stale and bd.HB > bd.StaleHB then -- deferred tiles of a frame not followed by a new one
            ImGui_ImplRoblox_RenderDrawData(bd.Stale)
        end
        bd.HB += 1
    end)

    connect(UserInputService.WindowFocused, function() ImGui.GetIO():AddFocusEvent(true) end)
    connect(UserInputService.WindowFocusReleased, function() ImGui.GetIO():AddFocusEvent(false) end)
end

-- Text proxy (opt-in, ImGui_ImplRoblox.SetTextProxy(true)): a hidden TextBox holds focus while an imgui text field is
-- active, so the OS gives us typing (any layout/unicode), paste (Ctrl+V) and copy/cut (Ctrl+C/X of imgui's selection).
-- Off: typing comes from KeyCodes (printable ASCII), no OS clipboard.
function ImGui_ImplRoblox_SetTextProxy(enabled)
    local bd = ImGui_ImplRoblox_GetBackendData()
    if not enabled then
        if bd.Proxy then bd.Proxy:Destroy(); bd.Proxy = nil end
        proxy_focused = false
        return
    end
    if bd.Proxy then return end
    local proxy = Instance.new("TextBox")
    proxy.Name = "TextProxy"
    proxy.BackgroundTransparency = 1
    proxy.TextTransparency = 0 -- kept opaque but parked off screen: a transparent TextBox may not get native paste
    proxy.BorderSizePixel = 0
    proxy.Size = UDim2.fromOffset(200, 20)
    proxy.Position = UDim2.fromOffset(-10000, -10000)
    proxy.MultiLine = true
    proxy.ClearTextOnFocus = false
    proxy.TextEditable = true
    proxy.Text = ""
    proxy.Parent = bd.Gui
    bd.Proxy, bd.ProxyText = proxy, ""
    -- Clicking elsewhere (or Roblox taking focus) ends the edit, like clicking outside the field in imgui.
    -- (Text is polled in NewFrame instead of using Text changed signals: those are deferred in Roblox.)
    proxy.FocusLost:Connect(function()
        if bd.ProxyReleasing then return end
        -- Roblox drops TextBox focus on any click, including clicks inside imgui (e.g. moving the cursor within the
        -- same field). Those must not end the edit: just recapture next frame. Only a click outside imgui ends it.
        if ImGui.GetIO().WantCaptureMouse then bd.ProxyLostId = nil; return end
        bd.ProxyLostId = bd.ProxyActiveId -- don't recapture for the same field
        local g = ImGui.GetCurrentContext()
        if g and g.ActiveId ~= 0 and g.ActiveId == bd.ProxyActiveId then ImGui.ClearActiveID() end
    end)
end

function ImGui_ImplRoblox_Shutdown()
    local io = ImGui.GetIO()
    local bd = ImGui_ImplRoblox_GetBackendData()
    for _, c in ipairs(bd.Connections) do c:Disconnect() end
    DestroyTiles(bd)
    bd.Gui:Destroy()

    io.BackendPlatformUserData = nil
    io.BackendPlatformName = nil
    io.BackendRendererName = nil
    io.BackendFlags = bit32.band(io.BackendFlags, bit32.bnot(bit32.bor(
        ImGuiBackendFlags.RendererHasTextures,
        ImGuiBackendFlags.RendererHasVtxOffset
    )))
end

function ImGui_ImplRoblox_NewFrame()
    PB("ImGui NewFrame (backend)")
    local io = ImGui.GetIO()
    local bd = ImGui_ImplRoblox_GetBackendData()
    if bd.Pending then bd.Pending = nil; table.clear(bd.Overlays) end -- skipped frame superseded (its draw lists get reset)
    bd.Stale = nil

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

    -- Text proxy: focused while an imgui text field is active. proxy_focused only when Roblox really gave it focus,
    -- otherwise the KeyCode fallback keeps typing working.
    local proxy = bd.Proxy
    local g = ImGui.GetCurrentContext()
    local focused_box = proxy and UserInputService:GetFocusedTextBox()
    if not proxy then
        -- text proxy disabled: KeyCode typing only
    elseif io.WantTextInput and g.ActiveId ~= 0 then
        if g.ActiveId ~= bd.ProxyActiveId or g.ActiveIdIsJustActivated or g.IO.MouseClicked[0] then bd.ProxyActiveId = g.ActiveId; bd.ProxyLostId = nil end -- (re)clicking a field recaptures
        local mouse_up = not (io.MouseDown[0] or io.MouseDown[1] or io.MouseDown[2])
        if focused_box ~= proxy and mouse_up and bd.ProxyLostId ~= g.ActiveId and (focused_box == nil or not focused_box:IsDescendantOf(game)) then
            bd.ProxyText = proxy.Text -- what it already holds is not new input (else re-typing it would collapse imgui's selection)
            proxy:CaptureFocus()
            focused_box = UserInputService:GetFocusedTextBox()
        end
    elseif focused_box == proxy then
        bd.ProxyReleasing = true
        proxy:ReleaseFocus()
        bd.ProxyReleasing = false
        focused_box = nil
    end
    proxy_focused = proxy ~= nil and focused_box == proxy
    local used_proxy_text = false
    if proxy_focused then
        -- 1) whatever the OS put in the proxy since last frame (typing, paste, cut) replaces imgui's selection
        local text = proxy.Text
        if text ~= bd.ProxyText and text ~= bd.ProxyLastRaw then -- (LastRaw: don't re-send if our reset hasn't applied yet)
            bd.ProxyLastRaw = text
            -- InputText ignores characters while Ctrl is held (upstream, so shortcuts don't type); a paste arrives with
            -- Ctrl still down, so release Ctrl around the characters in the event queue.
            local ctrl = io.KeyCtrl or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
            if ctrl then io:AddKeyEvent(ImGuiMod_Ctrl, false) end
            local prev = bd.ProxyText or ""
            if #text < #prev and prev:sub(1, #text) == text and text:sub(-1) ~= "\n" then
                -- The TextBox deleted from its own text (Backspace/Delete; Roblox can't hold a real selection in it, so it
                -- may remove just 1 char). Apply the deletion with imgui's own selection instead: one Backspace deletes
                -- the whole imgui selection, or one char if none. Skipped if imgui already got the key event.
                if not bd.DeleteKeySeen then io:AddKeyEvent(ImGuiKey.Backspace, true); io:AddKeyEvent(ImGuiKey.Backspace, false) end
            elseif text ~= "\n" and text ~= "\r" and text ~= "\t" then -- Enter/Tab arrive as key events
                local prev = bd.ProxyText or ""
                if #text > 0 and (prev == "" or text:sub(1, #prev) ~= prev or #text <= #prev) then
                    for _, cp in utf8.codes(text) do io:AddInputCharacter(cp) end
                elseif #text > #prev then
                    for _, cp in utf8.codes(text:sub(#prev + 1)) do io:AddInputCharacter(cp) end
                end
            end
            if ctrl then io:AddKeyEvent(ImGuiMod_Ctrl, true) end
            used_proxy_text = true
            bd.ProxyText = nil
        end
        -- 2) mirror imgui's selection, fully selected, so the native Ctrl+C / Ctrl+X copy exactly that
        local st = g.InputTextState
        local sel = ""
        if st and st.ID ~= 0 and st.ID == g.ActiveId and st.Stb and st:HasSelection() then
            local a, b = math.min(st.Stb.select_start, st.Stb.select_end), math.max(st.Stb.select_start, st.Stb.select_end)
            sel = ImGui._ByteArrayToString(st.TextA.Data, a, b) -- stb positions are 1-based in this port
        end
        if sel ~= bd.ProxyText then
            proxy.Text = sel
            bd.ProxyLastRaw = nil
            bd.ProxyText = sel
        end
        -- keep imgui's selection fully selected in the proxy, so Ctrl+C copies it and typing/Ctrl+V replaces it
        local want_sel, want_cur = (#sel > 0) and 1 or -1, #sel + 1
        if proxy.SelectionStart ~= want_sel then proxy.SelectionStart = want_sel end
        if proxy.CursorPosition ~= want_cur then proxy.CursorPosition = want_cur end
    end

    bd.DeleteKeySeen = false

    -- Held KeyCode chars: dropped if the proxy delivered the text, otherwise typed (proxy didn't really get the keys)
    local pending = bd.PendingChars
    if #pending > 0 then
        if not used_proxy_text then for _, c in ipairs(pending) do io:AddInputCharacter(c) end end
        table.clear(pending)
    end

    -- While the mouse is over imgui, make the tiles Active so Roblox stops passing clicks/wheel to the game (camera zoom etc.)
    local want = io.WantCaptureMouse
    if want ~= bd.TilesActive then
        bd.TilesActive = want
        for _, set in pairs(bd.Layers) do for kind = 1, 3 do local layer = set[kind]; if layer then for _, tile in pairs(layer.Tiles) do tile.Label.Active = want end end end end
    end
    PE()
end

--- Opt-in: max milliseconds per frame spent redrawing changed tiles (default 0 = no limit, every change is drawn the
--- same frame). With a budget (e.g. 1.5), tiles over it keep
--- their previous pixels and are redrawn on the following frames (each one at most a few frames late), so a big change
--- (resizing a large window, opening one, scrolling a long list) is spread over frames instead of one long frame.
function ImGui_ImplRoblox_SetRedrawBudget(ms)
    ImGui_ImplRoblox_GetBackendData().RedrawBudget = (ms or 0) / 1000
end

--- Max tile redraws per second (default 60; 0 = every frame, limited by the redraw budget instead). imgui logic still runs every frame.
function ImGui_ImplRoblox_SetRenderRate(hz)
    ImGui_ImplRoblox_GetBackendData().RenderRate = hz or 0
end

--- Optional: max tile redraws per second while scrolling, resizing or moving a window (0 = off, the default)
function ImGui_ImplRoblox_SetBusyRenderRate(hz)
    ImGui_ImplRoblox_GetBackendData().BusyRenderRate = hz or 0
end

--- Toggle MicroProfiler labels (debug.profilebegin) for the backend
function ImGui_ImplRoblox_SetProfiling(enabled) profiling = enabled and true or false end
local function ImGui_ImplRoblox_IsProfiling() return profiling end

function ImGui_ImplRoblox_SetRenderScale(scale)
    local bd = ImGui_ImplRoblox_GetBackendData()
    if scale == bd.Scale then return end
    bd.Scale = scale
    DestroyTiles(bd)
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
    SetRedrawBudget = ImGui_ImplRoblox_SetRedrawBudget,
    SetOverlay     = ImGui_ImplRoblox_SetOverlay,
    SetTextProxy   = ImGui_ImplRoblox_SetTextProxy,
    CreateTexture  = ImGui_ImplRoblox_CreateTexture,
    DestroyTexture = ImGui_ImplRoblox_DestroyTexture,
    GetRenderScale = function() return ImGui_ImplRoblox_GetBackendData().Scale end,
    SetBusyRenderRate = ImGui_ImplRoblox_SetBusyRenderRate,
    SetProfiling   = ImGui_ImplRoblox_SetProfiling,
    IsProfiling    = ImGui_ImplRoblox_IsProfiling,
}

return true -- [Roblox] ModuleScripts must return exactly one value
