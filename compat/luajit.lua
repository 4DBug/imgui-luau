-- Luau standard library pieces the port uses, for LuaJIT (LÖVE). Prepended by `tools/bundle.py --target love` only:
-- the Roblox build uses Luau's native bit32/buffer/table/utf8 and never sees this file.

local ffi = require("ffi")
local bit = require("bit")
local floor = math.floor
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
