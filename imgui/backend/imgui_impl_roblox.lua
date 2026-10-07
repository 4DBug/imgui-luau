if _G.__IMGUI_ENV then setfenv(1, _G.__IMGUI_ENV) end -- [Roblox] shared env, see init.lua
--- ImGui Backend for Roblox
--- Structurally mirrors imgui_impl_love.lua
---  - Renderer: software rasterizer drawing into a CanvasDraw canvas (EditableImage). CanvasDraw's own shape
---    functions can't do per-vertex colours, texture tinting or clip rects, so triangles are rasterized straight
---    into `Canvas.Buffer` (same RGBA8 layout as ImU32) and pushed with `Canvas:Render()`.
---  - Platform: UserInputService
---  - Files: an in-memory file system (VFS), pre-filled with the fonts from imgui_impl_roblox_fonts.lua
---
--- Usage (LocalScript):
---   local G = require(ReplicatedStorage.imgui)
---   G.ImGui.CreateContext()
---   G.ImGui_ImplRoblox.Init(require(ReplicatedStorage.CanvasDraw))

local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local readu8, writeu8, writeu32 = buffer.readu8, buffer.writeu8, buffer.writeu32

-- EditableImage size limit. Bigger screens get a downscaled canvas that is stretched to fit.
-- Lower it to trade sharpness for speed.
local MAX_CANVAS_SIZE = 1024

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
-- RENDERING (software rasterizer into the canvas buffer)
---------------------------------------------------------
-- Buffer layout: 4 bytes per pixel, R G B A, row-major, 0-based offsets. ImU32 colours are already R | G<<8 | B<<16 | A<<24.
-- Blending is non-premultiplied "over" with a transparent (alpha 0) background, so the game stays visible behind ImGui.

local buf, buf_w -- current canvas buffer/width, set at the start of RenderDrawData

-- Blends one pixel (r, g, b, a are 0..255)
local function BlendPixel(o, r, g, b, a)
    if a >= 255 then
        writeu32(buf, o, floor(r + 0.5) + floor(g + 0.5) * 256 + floor(b + 0.5) * 65536 + 4278190080)
        return
    end
    if a <= 0 then return end
    local da = readu8(buf, o + 3)
    if da == 0 then
        writeu32(buf, o, floor(r + 0.5) + floor(g + 0.5) * 256 + floor(b + 0.5) * 65536 + floor(a + 0.5) * 16777216)
    elseif da == 255 then
        local sa = a / 255
        local dr, dg, db = readu8(buf, o), readu8(buf, o + 1), readu8(buf, o + 2)
        writeu8(buf, o,     dr + (r - dr) * sa + 0.5)
        writeu8(buf, o + 1, dg + (g - dg) * sa + 0.5)
        writeu8(buf, o + 2, db + (b - db) * sa + 0.5)
    else
        local sa = a / 255
        local k = (da / 255) * (1 - sa)
        local oa = sa + k
        writeu8(buf, o,     (r * sa + readu8(buf, o) * k) / oa + 0.5)
        writeu8(buf, o + 1, (g * sa + readu8(buf, o + 1) * k) / oa + 0.5)
        writeu8(buf, o + 2, (b * sa + readu8(buf, o + 2) * k) / oa + 0.5)
        writeu8(buf, o + 3, oa * 255 + 0.5)
    end
end

-- Fills pixels [x0, x1) of row y with one colour
local function FillSpan(y, x0, x1, r, g, b, a)
    if a <= 0 then return end
    local o = (y * buf_w + x0) * 4
    if a >= 255 then
        local packed = floor(r + 0.5) + floor(g + 0.5) * 256 + floor(b + 0.5) * 65536 + 4278190080
        for x = 0, x1 - x0 - 1 do writeu32(buf, o + x * 4, packed) end
    else
        for x = 0, x1 - x0 - 1 do BlendPixel(o + x * 4, r, g, b, a) end
    end
end

local function UnpackColor(col)
    return col % 256, floor(col / 256) % 256, floor(col / 65536) % 256, floor(col / 16777216) % 256
end

-- Nearest texel at (u, v) as r, g, b, a (0..255)
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
        for y = py0, py1 - 1 do FillSpan(y, px0, px1, r, g, b, a) end
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

function ImGui_ImplRoblox_RenderDrawData(draw_data)
    local bd = ImGui_ImplRoblox_GetBackendData()
    local canvas = bd.Canvas

    if draw_data.Textures ~= nil then
        for _, tex in draw_data.Textures:iter() do
            if tex.Status ~= ImTextureStatus.OK then
                ImGui_ImplRoblox_UpdateTexture(tex)
            end
        end
    end

    canvas:Clear()
    buf, buf_w = canvas.Buffer, canvas.CurrentResX
    local buf_h = canvas.CurrentResY
    local ox, oy = draw_data.DisplayPos.x, draw_data.DisplayPos.y

    if draw_data.DisplaySize.x > 0.0 and draw_data.DisplaySize.y > 0.0 then
        for _, draw_list in draw_data.CmdLists:iter() do
            local vtx, idx = draw_list.VtxBuffer.Data, draw_list.IdxBuffer.Data
            for _, pcmd in draw_list.CmdBuffer:iter() do
                if pcmd.UserCallback ~= nil then
                    pcmd.UserCallback(draw_list, pcmd)
                elseif pcmd.ElemCount > 0 then
                    local clip = pcmd.ClipRect
                    local cx0, cy0 = max(floor(clip.x - ox), 0), max(floor(clip.y - oy), 0)
                    local cx1, cy1 = min(floor(clip.z - ox), buf_w), min(floor(clip.w - oy), buf_h)
                    if cx1 > cx0 and cy1 > cy0 then
                        local t = bd.Textures[pcmd:GetTexID()]
                        local vo = pcmd.VtxOffset
                        local i, last = pcmd.IdxOffset + 1, pcmd.IdxOffset + pcmd.ElemCount
                        while i <= last do
                            local ia, ic = idx[i], idx[i + 2]
                            local va, vb, vc = vtx[vo + ia], vtx[vo + idx[i + 1]], vtx[vo + ic]
                            if i + 5 <= last and idx[i + 3] == ia and idx[i + 4] == ic
                                and TryDrawRect(va, vb, vc, vtx[vo + idx[i + 5]], t, cx0, cy0, cx1, cy1, ox, oy) then
                                i = i + 6
                            else
                                DrawTriangle(va, vb, vc, t, cx0, cy0, cx1, cy1, ox, oy)
                                i = i + 3
                            end
                        end
                    end
                end
            end
        end
    end

    canvas:Render()
end

---------------------------------------------------------
-- CORE LIFECYCLE
---------------------------------------------------------

-- Canvas resolution for a given screen size (capped by MAX_CANVAS_SIZE, aspect ratio kept)
local function GetCanvasSize(screen)
    local scale = max(1, screen.X / MAX_CANVAS_SIZE, screen.Y / MAX_CANVAS_SIZE)
    return max(1, floor(screen.X / scale)), max(1, floor(screen.Y / scale))
end

--- @param CanvasDraw table     # require(path.to.CanvasDraw)
--- @param parent     Instance? # where the ScreenGui goes, defaults to the local player's PlayerGui
function ImGui_ImplRoblox_Init(CanvasDraw, parent)
    assert(CanvasDraw, "ImGui_ImplRoblox.Init: pass the CanvasDraw module, e.g. Init(require(ReplicatedStorage.CanvasDraw))")
    local io = ImGui.GetIO()

    local gui = Instance.new("ScreenGui")
    gui.Name = "ImGui"
    gui.IgnoreGuiInset = true -- so GetMouseLocation() and the canvas share the same origin
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1000
    gui.Parent = parent or Players.LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundTransparency = 1
    frame.Parent = gui

    local screen = gui.AbsoluteSize
    if screen.X < 1 or screen.Y < 1 then screen = workspace.CurrentCamera.ViewportSize end
    local w, h = GetCanvasSize(screen)

    local canvas = CanvasDraw.new(frame, Vector2.new(w, h), Color3.new(0, 0, 0))
    canvas.AutoRender = false
    canvas:SetStretchToFit(true)
    canvas:SetClearRGBA(0, 0, 0, 0)
    canvas:Clear()

    local bd = {
        Time = os.clock(), Gui = gui, Canvas = canvas, Connections = {},
        Textures = {}, TextureCount = 0, MouseX = -1, MouseY = -1,
    }
    io.BackendPlatformUserData = bd

    io.BackendFlags = bit32.bor(io.BackendFlags, ImGuiBackendFlags.RendererHasTextures, ImGuiBackendFlags.RendererHasVtxOffset)

    local platform_io = ImGui.GetPlatformIO()
    platform_io.Platform_SetClipboardTextFn = ImGui_ImplRoblox_PlatformSetClipboardText
    platform_io.Platform_GetClipboardTextFn = ImGui_ImplRoblox_PlatformGetClipboardText

    ImGui_ImplRoblox_UpdateMonitors(w, h)

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
    bd.Canvas:Destroy()
    bd.Gui:Destroy()

    io.BackendPlatformUserData = nil
    io.BackendFlags = bit32.band(io.BackendFlags, bit32.bnot(bit32.bor(
        ImGuiBackendFlags.RendererHasTextures,
        ImGuiBackendFlags.RendererHasVtxOffset
    )))
end

function ImGui_ImplRoblox_NewFrame()
    local io = ImGui.GetIO()
    local bd = ImGui_ImplRoblox_GetBackendData()
    local canvas = bd.Canvas

    -- Follow screen size changes
    local screen = bd.Gui.AbsoluteSize
    if screen.X >= 1 and screen.Y >= 1 then
        local w, h = GetCanvasSize(screen)
        if w ~= canvas.CurrentResX or h ~= canvas.CurrentResY then
            canvas:Resize(Vector2.new(w, h))
            ImGui_ImplRoblox_UpdateMonitors(w, h)
        end
    end
    local w, h = canvas.CurrentResX, canvas.CurrentResY
    ImVec2_CopyV(io.DisplaySize, w, h)

    local current_time = os.clock()
    io.DeltaTime = (current_time > bd.Time) and (current_time - bd.Time) or (1.0 / 60.0)
    bd.Time = current_time

    -- Mouse position: screen pixels -> canvas pixels (the canvas is stretched over the whole screen)
    local m = UserInputService:GetMouseLocation()
    local mx, my = m.X * w / max(screen.X, 1), m.Y * h / max(screen.Y, 1)
    if mx ~= bd.MouseX or my ~= bd.MouseY then
        bd.MouseX, bd.MouseY = mx, my
        io:AddMouseSourceEvent(ImGuiMouseSource.Mouse)
        io:AddMousePosEvent(mx, my)
    end
end

ImGui_ImplRoblox = {
    Init           = ImGui_ImplRoblox_Init,
    Shutdown       = ImGui_ImplRoblox_Shutdown,
    NewFrame       = ImGui_ImplRoblox_NewFrame,
    RenderDrawData = ImGui_ImplRoblox_RenderDrawData,
    AddFile        = ImGui_ImplRoblox_AddFile,
}

return true -- [Roblox] ModuleScripts must return exactly one value
