--- Dear ImGui backend for LÖVE (11.x, LuaJIT). Platform (input, clipboard, cursors, IME) + renderer (Mesh per draw list).
--- Built into build/imgui_love.lua by `python3 tools/bundle.py --target love`.
--- Usage (see examples/example_love/main.lua):
---   love.load:  ImGui.CreateContext(); ImGui_ImplLove.Init({ root = "<repo root>/" })
---   love.update: ImGui_ImplLove.NewFrame(); ImGui.NewFrame(); ...your UI...; ImGui.Render()
---   love.draw:  ImGui_ImplLove.RenderDrawData(ImGui.GetDrawData())
---   forward love.mousemoved/mousepressed/mousereleased/wheelmoved/keypressed/keyreleased/textinput to ImGui_ImplLove.*

-- [SECTION] COMPAT (Luau stdlib for LuaJIT). tools/bundle.py --target love runs this section before the library.
--@compat-begin
local ffi = require("ffi")
local floor = math.floor
-- Luau standard library pieces the port uses, for LuaJIT (LÖVE). Prepended by `tools/bundle.py --target love` only:
-- the Roblox build uses Luau's native bit32/buffer/table/utf8 and never sees this file.

local bit = require("bit")
local TWO32 = 4294967296

-- bit32: unsigned 32-bit results like Luau/Lua 5.2 (LuaJIT's `bit` returns signed values)
if not bit32 then
    local band, bor, bxor, bnot, lshift, rshift, arshift, tobit = bit.band, bit.bor, bit.bxor, bit.bnot, bit.lshift, bit.rshift, bit.arshift, bit.tobit
    local function u(x) return x % TWO32 end
    local function t(x) return tobit(x % TWO32) end -- any number -> int32 (bit.* wraps doubles >= 2^31 unreliably)
    bit32 = {}
    function bit32.band(a, b, ...)
        if a == nil then return TWO32 - 1 end
        if b == nil then return u(t(a)) end
        local r = band(t(a), t(b))
        if ... ~= nil then for i = 1, select("#", ...) do r = band(r, t((select(i, ...)))) end end
        return u(r)
    end
    function bit32.bor(a, b, ...)
        if a == nil then return 0 end
        if b == nil then return u(t(a)) end
        local r = bor(t(a), t(b))
        if ... ~= nil then for i = 1, select("#", ...) do r = bor(r, t((select(i, ...)))) end end
        return u(r)
    end
    function bit32.bxor(a, b, ...)
        if a == nil then return 0 end
        if b == nil then return u(t(a)) end
        local r = bxor(t(a), t(b))
        if ... ~= nil then for i = 1, select("#", ...) do r = bxor(r, t((select(i, ...)))) end end
        return u(r)
    end
    function bit32.bnot(a) return u(bnot(t(a))) end
    function bit32.lshift(a, n) if n >= 32 or n <= -32 then return 0 end if n < 0 then return u(rshift(t(a), -n)) end return u(lshift(t(a), n)) end
    function bit32.rshift(a, n) if n >= 32 or n <= -32 then return 0 end if n < 0 then return u(lshift(t(a), -n)) end return u(rshift(t(a), n)) end
    function bit32.arshift(a, n) if n >= 32 then n = 31 end return u(arshift(t(a), n)) end
    function bit32.btest(...) return bit32.band(...) ~= 0 end
    function bit32.extract(n, field, width) width = width or 1; return u(band(rshift(t(n), field), 2 ^ width - 1)) end
end

-- buffer: fixed-size byte buffers (subset used by the port), on FFI memory. Little-endian like Luau.
if not buffer then
    ffi.cdef("void *memmove(void *dst, const void *src, size_t n); void *memset(void *s, int c, size_t n);")
    local C = ffi.C
    local u8p, u32p, f64p = ffi.typeof("uint8_t*"), ffi.typeof("uint32_t*"), ffi.typeof("double*")
    buffer = {}
    function buffer.create(n)
        local mem = ffi.new("uint8_t[?]", math.max(n, 1)) -- zero-filled
        return { p = ffi.cast(u8p, mem), n = n, mem = mem }
    end
    function buffer.len(b) return b.n end
    function buffer.readu8(b, o) return b.p[o] end
    function buffer.writeu8(b, o, v) b.p[o] = v end
    function buffer.readu32(b, o) return ffi.cast(u32p, b.p + o)[0] end
    function buffer.writeu32(b, o, v) ffi.cast(u32p, b.p + o)[0] = v % TWO32 end
    function buffer.readf64(b, o) return ffi.cast(f64p, b.p + o)[0] end
    function buffer.writef64(b, o, v) ffi.cast(f64p, b.p + o)[0] = v end
    function buffer.readstring(b, o, n) return ffi.string(b.p + o, n) end
    function buffer.writestring(b, o, s, n) ffi.copy(b.p + o, s, n or #s) end
    function buffer.copy(dst, doff, src, soff, n)
        soff = soff or 0
        n = n or (src.n - soff)
        if n > 0 then C.memmove(dst.p + doff, src.p + soff, n) end
    end
    function buffer.fill(b, o, v, n) n = n or (b.n - o); if n > 0 then C.memset(b.p + o, v, n) end end
    function buffer.tostring(b) return ffi.string(b.p, b.n) end
    function buffer.fromstring(s) local b = buffer.create(#s); ffi.copy(b.p, s, #s); return b end
end

-- table / math / utf8 additions from Luau / Lua 5.3
do
    local ok, clear = pcall(require, "table.clear")
    table.clear = table.clear or (ok and clear) or function(t) for k in pairs(t) do t[k] = nil end end
    table.unpack = table.unpack or unpack
    table.find = table.find or function(t, v, init) for i = init or 1, #t do if t[i] == v then return i end end end
    table.move = table.move or function(a1, f, e, t, a2)
        a2 = a2 or a1
        if e >= f then
            if t > f or t > e or a1 ~= a2 then for i = 0, e - f do a2[t + i] = a1[f + i] end
            else for i = e - f, 0, -1 do a2[t + i] = a1[f + i] end end
        end
        return a2
    end
    math.pow = math.pow or function(a, b) return a ^ b end
end

if not utf8 then
    utf8 = { charpattern = "[\0-\x7F\xC2-\xFD][\x80-\xBF]*" }
    function utf8.char(...)
        local out = {}
        for i = 1, select("#", ...) do
            local c = select(i, ...)
            if c < 0x80 then out[#out + 1] = string.char(c)
            elseif c < 0x800 then out[#out + 1] = string.char(0xC0 + floor(c / 64), 0x80 + c % 64)
            elseif c < 0x10000 then out[#out + 1] = string.char(0xE0 + floor(c / 4096), 0x80 + floor(c / 64) % 64, 0x80 + c % 64)
            else out[#out + 1] = string.char(0xF0 + floor(c / 262144), 0x80 + floor(c / 4096) % 64, 0x80 + floor(c / 64) % 64, 0x80 + c % 64) end
        end
        return table.concat(out)
    end
    local function decode(s, i)
        local c = s:byte(i)
        if not c then return nil end
        if c < 0x80 then return c, 1 end
        if c < 0xE0 then return (c % 32) * 64 + s:byte(i + 1) % 64, 2 end
        if c < 0xF0 then return (c % 16) * 4096 + (s:byte(i + 1) % 64) * 64 + s:byte(i + 2) % 64, 3 end
        return (c % 8) * 262144 + (s:byte(i + 1) % 64) * 4096 + (s:byte(i + 2) % 64) * 64 + s:byte(i + 3) % 64, 4
    end
    function utf8.codes(s)
        local i = 1
        return function()
            if i > #s then return nil end
            local c, n = decode(s, i)
            local p = i; i = i + n
            return p, c
        end
    end
    function utf8.codepoint(s, i, j)
        i = i or 1; j = j or i
        local out = {}
        while i <= j do local c, n = decode(s, i); out[#out + 1] = c; i = i + n end
        return unpack(out)
    end
    function utf8.len(s) local n = 0; for _ in utf8.codes(s) do n = n + 1 end return n end
    function utf8.offset(s, n, i)
        i = i or (n >= 0 and 1 or #s + 1)
        if n > 0 then
            n = n - 1
            while n > 0 and i <= #s do i = i + 1; while i <= #s and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do i = i + 1 end; n = n - 1 end
            if n > 0 then return nil end
            return i
        end
        return i
    end
end
--@compat-end

local floor, min = math.floor, math.min

local ImGui_ImplLOVE_GetBackendData

local CURSOR_MAP = {
    [ImGuiMouseCursor.Arrow]      = "arrow",
    [ImGuiMouseCursor.TextInput]  = "ibeam",
    [ImGuiMouseCursor.ResizeAll]  = "sizeall",
    [ImGuiMouseCursor.ResizeNS]   = "sizens",
    [ImGuiMouseCursor.ResizeEW]   = "sizewe",
    [ImGuiMouseCursor.ResizeNESW] = "sizenesw",
    [ImGuiMouseCursor.ResizeNWSE] = "sizenwse",
    [ImGuiMouseCursor.Hand]       = "hand",
    [ImGuiMouseCursor.Wait]       = "wait",
    [ImGuiMouseCursor.Progress]   = "waitarrow",
    [ImGuiMouseCursor.NotAllowed] = "no",
}

local KEY_MAP = {
    ["return"]    = ImGuiKey.Enter,       ["escape"]    = ImGuiKey.Escape,
    ["backspace"] = ImGuiKey.Backspace,   ["tab"]       = ImGuiKey.Tab,
    ["space"]     = ImGuiKey.Space,       ["kpenter"]   = ImGuiKey.KeypadEnter,
    ["up"]        = ImGuiKey.UpArrow,     ["down"]      = ImGuiKey.DownArrow,
    ["left"]      = ImGuiKey.LeftArrow,   ["right"]     = ImGuiKey.RightArrow,
    ["home"]      = ImGuiKey.Home,        ["end"]       = ImGuiKey.End,
    ["pageup"]    = ImGuiKey.PageUp,      ["pagedown"]  = ImGuiKey.PageDown,
    ["insert"]    = ImGuiKey.Insert,      ["delete"]    = ImGuiKey.Delete,
    ["lctrl"]     = ImGuiKey.LeftCtrl,    ["rctrl"]     = ImGuiKey.RightCtrl,
    ["lshift"]    = ImGuiKey.LeftShift,   ["rshift"]    = ImGuiKey.RightShift,
    ["lalt"]      = ImGuiKey.LeftAlt,     ["ralt"]      = ImGuiKey.RightAlt,
    ["lgui"]      = ImGuiKey.LeftSuper,   ["rgui"]      = ImGuiKey.RightSuper,
    ["-"] = ImGuiKey.Minus, ["="] = ImGuiKey.Equal, ["["] = ImGuiKey.LeftBracket, ["]"] = ImGuiKey.RightBracket,
    [";"] = ImGuiKey.Semicolon, ["'"] = ImGuiKey.Apostrophe, [","] = ImGuiKey.Comma, ["."] = ImGuiKey.Period,
    ["/"] = ImGuiKey.Slash, ["\\"] = ImGuiKey.Backslash, ["`"] = ImGuiKey.GraveAccent,
}
for i = 0, 9 do KEY_MAP[tostring(i)] = ImGuiKey["K" .. i]; KEY_MAP["kp" .. i] = ImGuiKey["Keypad" .. i] end
for i = 1, 12 do KEY_MAP["f" .. i] = ImGuiKey["F" .. i] end
for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do KEY_MAP[c] = ImGuiKey[c:upper()] end

local function UpdateKeyModifiers()
    local io = ImGui.GetIO()
    io:AddKeyEvent(ImGuiMod_Ctrl, love.keyboard.isDown("lctrl", "rctrl"))
    io:AddKeyEvent(ImGuiMod_Shift, love.keyboard.isDown("lshift", "rshift"))
    io:AddKeyEvent(ImGuiMod_Alt, love.keyboard.isDown("lalt", "ralt"))
    io:AddKeyEvent(ImGuiMod_Super, love.keyboard.isDown("lgui", "rgui"))
end

function ImGui_ImplLOVE_GetBackendData()
    return ImGui.GetCurrentContext() and ImGui.GetIO().BackendPlatformUserData or nil
end

local function UpdateMonitors(w, h)
    local platform_io = ImGui.GetPlatformIO()
    platform_io.Monitors:resize(0)
    local m = ImGuiPlatformMonitor()
    ImVec2_Copy(m.MainSize, ImVec2(w, h))
    ImVec2_Copy(m.WorkSize, ImVec2(w, h))
    platform_io.Monitors:push_back(m)
end

---------------------------------------------------------
-- PLATFORM DATA & CALLBACKS
---------------------------------------------------------

local function PlatformSetImeData(ctx, vp, data)
    if data.WantVisible or data.WantTextInput then
        love.keyboard.setTextInput(true, data.InputPos.x, data.InputPos.y, 1, data.InputLineHeight)
    else
        love.keyboard.setTextInput(false)
    end
end

local function PlatformSetClipboardText(ctx, text) love.system.setClipboardText(text) end
local function PlatformGetClipboardText(ctx) return love.system.getClipboardText() end
local function PlatformOpenInShell(ctx, path) return love.system.openURL(path) end

---------------------------------------------------------
-- FILE SYSTEM: love.filesystem (game folder), then io.open(<root> .. path) so fonts/ etc. load from the repo
---------------------------------------------------------

local function ReadFile(filename)
    local data = love.filesystem.getInfo(filename) and love.filesystem.read(filename)
    if data then return data end
    local bd = ImGui_ImplLOVE_GetBackendData()
    local f = io.open(((bd and bd.Root) or "") .. filename, "rb")
    if not f then return nil end
    data = f:read("*a"); f:close()
    return data
end

function ImStd.ImFileOpen(filename, mode)
    local data = ReadFile(filename)
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
-- TEXTURES
---------------------------------------------------------

local function CopyToImageData(tex, x, y, w, h)
    local img = love.image.newImageData(w, h, "rgba8")
    local dst = ffi.cast("uint8_t*", img:getFFIPointer())
    local bpp = tex.BytesPerPixel
    for row = 0, h - 1 do
        local src, base = tex:GetPixelsAt(x, y + row)
        local d = row * w * 4
        if bpp == 4 then
            for i = 0, w * 4 - 1 do dst[d + i] = src[base + i] end
        else -- Alpha8: white with alpha
            for i = 0, w - 1 do
                local o = d + i * 4
                dst[o], dst[o + 1], dst[o + 2], dst[o + 3] = 255, 255, 255, src[base + i]
            end
        end
    end
    return img
end

function ImGui_ImplLOVE_UpdateTexture(tex)
    local bd = ImGui_ImplLOVE_GetBackendData()
    if tex.Status == ImTextureStatus.WantCreate then
        local data = CopyToImageData(tex, 0, 0, tex.Width, tex.Height)
        local image = love.graphics.newImage(data)
        image:setFilter("nearest", "nearest")
        bd.TextureCount = bd.TextureCount + 1
        bd.Textures[bd.TextureCount] = image
        tex.BackendUserData = bd.TextureCount
        tex:SetTexID(bd.TextureCount)
        tex:SetStatus(ImTextureStatus.OK)
    elseif tex.Status == ImTextureStatus.WantUpdates then
        local image = bd.Textures[tex.BackendUserData]
        for _, r in tex.Updates:iter() do
            local data = CopyToImageData(tex, r.x, r.y, r.w, r.h)
            image:replacePixels(data, nil, 1, r.x, r.y, false)
            data:release()
        end
        tex:SetStatus(ImTextureStatus.OK)
    elseif tex.Status == ImTextureStatus.WantDestroy then
        local image = tex.BackendUserData and bd.Textures[tex.BackendUserData]
        if image then image:release(); bd.Textures[tex.BackendUserData] = nil end
        tex.BackendUserData = nil
        tex:SetTexID(ImTextureID_Invalid)
        tex:SetStatus(ImTextureStatus.Destroyed)
    end
end

--- User texture from RGBA8 pixels (a `buffer` of w*h*4 bytes, or a love ImageData). Returns an ImTextureRef.
function ImGui_ImplLOVE_CreateTexture(pixels, w, h)
    local bd = ImGui_ImplLOVE_GetBackendData()
    local data = pixels
    if type(pixels) == "table" and pixels.p then
        data = love.image.newImageData(w, h, "rgba8")
        ffi.copy(data:getFFIPointer(), pixels.p, w * h * 4)
    end
    bd.TextureCount = bd.TextureCount + 1
    bd.Textures[bd.TextureCount] = love.graphics.newImage(data)
    return ImTextureRef(bd.TextureCount)
end

function ImGui_ImplLOVE_DestroyTexture(tex_ref)
    local bd = ImGui_ImplLOVE_GetBackendData()
    local image = bd.Textures[tex_ref._TexID]
    if image then image:release(); bd.Textures[tex_ref._TexID] = nil end
end

---------------------------------------------------------
-- RENDERING: one streamed Mesh per draw list; vertices converted from the port's flat VtxBuffer (f64 x, y, u, v,
-- u32 col; 36 bytes) to LÖVE's float x, y, u, v + byte rgba (20 bytes); indices -> 0-based uint32 vertex map.
---------------------------------------------------------

ffi.cdef("typedef struct { float x, y, u, v; uint8_t r, g, b, a; } ImGuiLoveVertex;")
local VERTEX_FORMAT = { { "VertexPosition", "float", 2 }, { "VertexTexCoord", "float", 2 }, { "VertexColor", "byte", 4 } }
local vtx_ct, u32p, f64p = ffi.typeof("ImGuiLoveVertex*"), ffi.typeof("uint32_t*"), ffi.typeof("double*")

local function GetMesh(bd, draw_list, nvtx, nidx)
    local m = bd.Meshes[draw_list]
    if not m or m.VtxCap < nvtx or m.IdxCap < nidx then
        local vcap = math.max(nvtx, m and m.VtxCap * 2 or 256)
        local icap = math.max(nidx, m and m.IdxCap * 2 or 512)
        if m then m.Mesh:release() end
        m = {
            Mesh = love.graphics.newMesh(VERTEX_FORMAT, vcap, "triangles", "stream"),
            VtxData = love.data.newByteData(vcap * 20), IdxData = love.data.newByteData(icap * 4),
            VtxCap = vcap, IdxCap = icap,
        }
        bd.Meshes[draw_list] = m
    end
    m.Used = bd.FrameNo
    return m
end

function ImGui_ImplLOVE_RenderDrawData(draw_data)
    local bd = ImGui_ImplLOVE_GetBackendData()
    if draw_data.Textures ~= nil then
        for _, tex in draw_data.Textures:iter() do
            if tex.Status ~= ImTextureStatus.OK then ImGui_ImplLOVE_UpdateTexture(tex) end
        end
    end
    local fb_w, fb_h = draw_data.DisplaySize.x, draw_data.DisplaySize.y
    if fb_w <= 0 or fb_h <= 0 then return end
    bd.FrameNo = bd.FrameNo + 1

    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setColor(1, 1, 1, 1)
    local ox, oy = draw_data.DisplayPos.x, draw_data.DisplayPos.y
    love.graphics.translate(-ox, -oy)

    for _, draw_list in draw_data.CmdLists:iter() do
        local nvtx, nidx = draw_list.VtxBuffer.Size, draw_list.IdxBuffer.Size
        if nvtx > 0 and nidx > 0 then
            local m = GetMesh(bd, draw_list, nvtx, nidx)
            local base = draw_list.VtxBuffer.Buf.p
            local srcu = ffi.cast(u32p, base)
            local dst = ffi.cast(vtx_ct, m.VtxData:getFFIPointer())
            for i = 0, nvtx - 1 do
                local v, src = dst[i], ffi.cast(f64p, base + i * 36) -- 36-byte stride: cast per vertex
                v.x, v.y, v.u, v.v = src[0], src[1], src[2], src[3]
                local c = srcu[i * 9 + 8]
                v.r, v.g, v.b, v.a = c % 256, floor(c / 256) % 256, floor(c / 65536) % 256, floor(c / 16777216)
            end
            m.Mesh:setVertices(m.VtxData, 1, nvtx)

            -- vertex map: per command, 0-based vertex = VtxOffset + idx - 1 (port indices are 1-based)
            local map = ffi.cast(u32p, m.IdxData:getFFIPointer())
            local idx = draw_list.IdxBuffer.Data
            for _, pcmd in draw_list.CmdBuffer:iter() do
                local vo = pcmd.VtxOffset
                for i = pcmd.IdxOffset + 1, pcmd.IdxOffset + pcmd.ElemCount do map[i - 1] = vo + idx[i] - 1 end
            end
            m.Mesh:setVertexMap(m.IdxData, "uint32")

            for _, pcmd in draw_list.CmdBuffer:iter() do
                if pcmd.UserCallback ~= nil then
                    pcmd.UserCallback(draw_list, pcmd)
                elseif pcmd.ElemCount > 0 then
                    local c = pcmd.ClipRect
                    local x0, y0 = math.max(c.x - ox, 0), math.max(c.y - oy, 0)
                    local x1, y1 = min(c.z - ox, fb_w), min(c.w - oy, fb_h)
                    if x1 > x0 and y1 > y0 then
                        love.graphics.setScissor(x0, y0, x1 - x0, y1 - y0)
                        m.Mesh:setTexture(bd.Textures[pcmd:GetTexID()])
                        m.Mesh:setDrawRange(pcmd.IdxOffset + 1, pcmd.ElemCount)
                        love.graphics.draw(m.Mesh)
                    end
                end
            end
        end
    end

    -- free meshes of draw lists that went away
    for dl, m in pairs(bd.Meshes) do
        if bd.FrameNo - m.Used > 120 then m.Mesh:release(); bd.Meshes[dl] = nil end
    end
    love.graphics.setScissor()
    love.graphics.pop()
end

---------------------------------------------------------
-- LIFECYCLE
---------------------------------------------------------

--- opts.root: path prefix for files not in the LÖVE game folder (e.g. the repo root, for fonts/)
function ImGui_ImplLOVE_Init(opts)
    opts = opts or {}
    local io = ImGui.GetIO()
    local bd = { Time = love.timer.getTime(), Root = opts.root or "", Textures = {}, TextureCount = 0, Meshes = {}, FrameNo = 0 }
    io.BackendPlatformUserData = bd
    io.BackendFlags = bit32.bor(io.BackendFlags, ImGuiBackendFlags.RendererHasTextures, ImGuiBackendFlags.RendererHasVtxOffset, ImGuiBackendFlags.HasMouseCursors)

    local platform_io = ImGui.GetPlatformIO()
    platform_io.Platform_SetImeDataFn       = PlatformSetImeData
    platform_io.Platform_SetClipboardTextFn = PlatformSetClipboardText
    platform_io.Platform_GetClipboardTextFn = PlatformGetClipboardText
    platform_io.Platform_OpenInShellFn      = PlatformOpenInShell
    local w, h = love.graphics.getDimensions()
    UpdateMonitors(w, h)
    love.keyboard.setKeyRepeat(true)
end

function ImGui_ImplLOVE_Shutdown()
    local io = ImGui.GetIO()
    local bd = ImGui_ImplLOVE_GetBackendData()
    for _, m in pairs(bd.Meshes) do m.Mesh:release() end
    for _, t in pairs(bd.Textures) do t:release() end
    io.BackendPlatformUserData = nil
    io.BackendFlags = bit32.band(io.BackendFlags, bit32.bnot(bit32.bor(ImGuiBackendFlags.RendererHasTextures, ImGuiBackendFlags.RendererHasVtxOffset, ImGuiBackendFlags.HasMouseCursors)))
end

function ImGui_ImplLOVE_NewFrame()
    local io = ImGui.GetIO()
    local bd = ImGui_ImplLOVE_GetBackendData()

    local w, h = love.graphics.getDimensions()
    if w ~= bd.ScreenW or h ~= bd.ScreenH then bd.ScreenW, bd.ScreenH = w, h; UpdateMonitors(w, h) end
    ImVec2_CopyV(io.DisplaySize, w, h)

    local now = love.timer.getTime()
    io.DeltaTime = (now > bd.Time) and (now - bd.Time) or (1.0 / 60.0)
    bd.Time = now

    if bit32.band(io.ConfigFlags, ImGuiConfigFlags.NoMouseCursorChange) == 0 then
        local cursor = ImGui.GetMouseCursor()
        if cursor ~= bd.LastCursor then
            bd.LastCursor = cursor
            local name = CURSOR_MAP[cursor]
            love.mouse.setVisible(cursor ~= ImGuiMouseCursor.None and not io.MouseDrawCursor)
            love.mouse.setCursor(name and love.mouse.getSystemCursor(name) or nil)
        end
    end
end

---------------------------------------------------------
-- LÖVE EVENT HOOKS (forward from love.* callbacks)
---------------------------------------------------------

local MOUSE_BUTTONS = { [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4 } -- LÖVE: 1 left, 2 right, 3 middle

local function MouseMoved(x, y)
    local io = ImGui.GetIO()
    io:AddMouseSourceEvent(ImGuiMouseSource.Mouse)
    io:AddMousePosEvent(x, y)
end
local function MousePressed(x, y, button)
    local b = MOUSE_BUTTONS[button]
    if b then local io = ImGui.GetIO(); io:AddMouseSourceEvent(ImGuiMouseSource.Mouse); io:AddMouseButtonEvent(b, true) end
end
local function MouseReleased(x, y, button)
    local b = MOUSE_BUTTONS[button]
    if b then ImGui.GetIO():AddMouseButtonEvent(b, false) end
end
local function WheelMoved(x, y) ImGui.GetIO():AddMouseWheelEvent(-x, y) end
local function KeyPressed(key)
    UpdateKeyModifiers()
    local k = KEY_MAP[key]
    if k then ImGui.GetIO():AddKeyEvent(k, true) end
end
local function KeyReleased(key)
    UpdateKeyModifiers()
    local k = KEY_MAP[key]
    if k then ImGui.GetIO():AddKeyEvent(k, false) end
end
local function TextInput(text)
    local io = ImGui.GetIO()
    for _, c in utf8.codes(text) do io:AddInputCharacter(c) end
end
local function Focus(f) ImGui.GetIO():AddFocusEvent(f) end

--- True when ImGui wants the mouse / keyboard (don't pass the event to your game)
local function WantCaptureMouse() return ImGui.GetIO().WantCaptureMouse end
local function WantCaptureKeyboard() return ImGui.GetIO().WantCaptureKeyboard end

ImGui_ImplLove = {
    Init           = ImGui_ImplLOVE_Init,
    Shutdown       = ImGui_ImplLOVE_Shutdown,
    NewFrame       = ImGui_ImplLOVE_NewFrame,
    RenderDrawData = ImGui_ImplLOVE_RenderDrawData,
    CreateTexture  = ImGui_ImplLOVE_CreateTexture,
    DestroyTexture = ImGui_ImplLOVE_DestroyTexture,
    MouseMoved     = MouseMoved,
    MousePressed   = MousePressed,
    MouseReleased  = MouseReleased,
    WheelMoved     = WheelMoved,
    KeyPressed     = KeyPressed,
    KeyReleased    = KeyReleased,
    TextInput      = TextInput,
    Focus          = Focus,
    WantCaptureMouse = WantCaptureMouse,
    WantCaptureKeyboard = WantCaptureKeyboard,
}

return true
