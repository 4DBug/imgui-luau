-- dear imgui, v1.93.0 WIP
-- (internal structures/api)

-- You may use this file to debug, understand or extend Dear ImGui features but we don't provide any guarantee of forward compatibility.

-- Index of this file:
--
-- [SECTION] Context pointer
-- [SECTION] Macros
-- [SECTION] Generic helpers
-- [SECTION] ImDrawList support
-- [SECTION] Style support
-- [SECTION] Data types support
-- [SECTION] Widgets support: flags, enums, data structures
-- [SECTION] Popup support
-- [SECTION] Inputs support
-- [SECTION] Navigation support
-- [SECTION] Viewport support
-- [SECTION] Settings support
-- [SECTION] Localization support
-- [SECTION] Metrics, Debug tools
-- [SECTION] ImGuiContext (main imgui context)
-- [SECTION] ImGuiWindowTempData, ImGuiWindow
-- [SECTION] Tab bar, Tab item support
-- [SECTION] ImGui internal API
-- [SECTION] ImFontLoader
-- [SECTION] ImFontAtlas internal API
--
-- PORT: the order of declarations in this file does not strictly follow upstream's imgui_internal.h.

--- @meta

local type   = type -- [Luau] builtin (FASTCALL); ImGui._GetTypeFunc() kept for compatibility
local rawget = rawget

local mathMin   = math.min; local mathMax    = math.max
local mathFloor = math.floor; local mathCeil = math.ceil

local bitNot    = bit32.bnot
local bitAnd    = bit32.band; local bitOr       = bit32.bor
local bitLShift = bit32.lshift; local bitRShift = bit32.rshift

local t_sort = table.sort

--- @alias ImGuiTableColumnIdx ImS16

-- TODO: Implement actual ImString type
--- @alias ImString char[]|string
--- @alias ImStringBuffer char[]

-- NOTE: temporary solution
--- @param buf       char[]
--- @param buf_begin int
--- @param buf_end   int    # exclusive
function ImGui._ByteArrayToString(buf, buf_begin, buf_end)
    local str = {}
    for i = buf_begin, buf_end - 1 do
        table.insert(str, string.char(buf[i]))
    end
    return table.concat(str)
end


-- Helper: ImPool<>
-- Basic keyed storage for contiguous instances, slow/amortized insertion, O(1) indexable, O(Log N) queries by ID over a dense/hot buffer,
-- Indexes have the same lifetime as the associated object.
--- ImPool<T>: pool of objects keyed by ID. Public indices are 0-based like upstream (Buf is stored 1-based).
--- `ctor` creates a new element. Removed slots are recycled via FreeIdx (-1 = none; free slots chain through `_NextFree`).
local IM_POOL = {}
IM_POOL.__index = IM_POOL
function ImPool(ctor) return setmetatable({ Buf = {}, Map = {}, FreeIdx = 0, AliveCount = 0, BufSize = 0, _Ctor = ctor }, IM_POOL) end
function IM_POOL:GetByKey(key) local i = self.Map[key]; return i and self.Buf[i + 1] or nil end
function IM_POOL:GetByIndex(n) return self.Buf[n + 1] end
function IM_POOL:GetIndex(p) return p._PoolIdx end
function IM_POOL:Contains(p) return p ~= nil and self.Buf[(p._PoolIdx or -1) + 1] == p end
function IM_POOL:GetMapSize() return self.BufSize end
function IM_POOL:Clear() self.Buf = {}; self.Map = {}; self.FreeIdx = 0; self.AliveCount = 0; self.BufSize = 0 end
function IM_POOL:Add()
    local idx
    if self._Free and #self._Free > 0 then idx = table.remove(self._Free) else idx = self.BufSize; self.BufSize = self.BufSize + 1 end
    local p = self._Ctor and self._Ctor() or {}
    p._PoolIdx = idx
    self.Buf[idx + 1] = p
    self.AliveCount = self.AliveCount + 1
    return p
end
function IM_POOL:GetOrAddByKey(key)
    local i = self.Map[key]
    if i then return self.Buf[i + 1] end
    local p = self:Add(); self.Map[key] = p._PoolIdx; return p
end
function IM_POOL:Remove(key, p)
    if type(key) == "table" then p = key; key = nil end
    if key == nil then for k, i in pairs(self.Map) do if i == p._PoolIdx then key = k break end end end
    if key ~= nil then self.Map[key] = nil end
    self.Buf[p._PoolIdx + 1] = false
    self._Free = self._Free or {}
    table.insert(self._Free, p._PoolIdx)
    self.AliveCount = self.AliveCount - 1
end
function IM_POOL:Reserve(n) end
-- NOTE: removed slots hold `false`; iterate with `for i = 0, pool:GetMapSize() - 1 do local t = pool:GetByIndex(i) if t then ... end end`

-------------------------------------------------------------------------------
-- [SECTION] Context pointer
-- See implementation of this variable in imgui.cpp for comments and details.
-------------------------------------------------------------------------------

--- @type ImGuiContext?
local GImGui -- Current implicit context pointer

-- Sets local `GImGui` in this file(imgui_internal.lua).
-- This is currently only used in main code `ImGui.SetCurrentContext()`
--- @param ctx ImGuiContext?
function ImGui._SetCurrentContext_Internal(ctx)
    GImGui = ctx
end

local setmetatable = setmetatable

local MT = ImGui.GetMetatables()

-------------------------------------------------------------------------------
-- [SECTION] Macros
-------------------------------------------------------------------------------

IM_TABSIZE = 4

FLT_MIN = 1.1754943508223e-38
FLT_MAX = 3.4028234663853e+38
DBL_MAX = 1.7976931348623e+308
INT_MIN = -0x7fffffff - 1
INT_MAX = 0x7fffffff
UINT_MAX = 0x7fffffff * 2 + 1

NAV_WINDOWING_HIGHLIGHT_DELAY = 0.5 -- Time before the highlight and screen dimming starts fading in
NAV_ACTIVATE_HIGHLIGHT_TIMER = 0.10 -- Time to highlight an item activated by a shortcut.
NAV_ACTIVATE_INPUT_WITH_GAMEPAD_DELAY = 0.60 -- Time to hold activation button (e.g. FaceDown) to turn the activation into a text input.

IM_PI  = math.pi

-------------------------------------------------------------------------------
-- [SECTION] Generic helpers
-- Note that the ImXXX helpers functions are lower-level than ImGui functions.
-- ImGui functions or the ImGui context are never called/used from other ImXXX functions.
-------------------------------------------------------------------------------

-- Helpers: Maths
-- - Wrapper for standard libs functions. (Note that imgui_demo.cpp does _not_ use them to keep the code easy to copy)
ImPow  = math.pow -- DragBehaviorT/SliderBehaviorT uses ImPow with either float/double and need the precision
ImLog  = math.log -- DragBehaviorT/SliderBehaviorT uses ImLog with either float/double and need the precision
ImAbs  = math.abs
ImFabs = math.abs
ImFmod = function(a, b) if b < 0 then b = -b end; if a < 0 then return -(-a % b) else return a % b end; end

ImRound64 = function(val) return math.floor(val + 0.5) end -- FIXME: Positive values only

ImCeil  = math.ceil
ImSin   = math.sin
ImCos   = math.cos
ImAcos  = math.acos
ImAtan2 = math.atan2
ImSqrt  = math.sqrt

--- @generic T: number
--- @param a  T
--- @param b  T
--- @param mn T
--- @param mx T
--- @return T
function ImAddClampOverflow(a, b, mn, mx)
    if b < 0 and (a < mn - b) then return mn end
    if b > 0 and (a > mx - b) then return mx end
    return a + b
end

--- @generic T: number
--- @param a  T
--- @param b  T
--- @param mn T
--- @param mx T
--- @return T
function ImSubClampOverflow(a, b, mn, mx)
    if b > 0 and (a < mn + b) then return mn end
    if b < 0 and (a > mx + b) then return mx end
    return a - b
end

-- - ImMin/ImMax/ImClamp/ImLerp/ImSwap are used by widgets which support variety of types: signed/unsigned int/long long float/double
--- @overload fun(lhs: number, rhs: number): number
--- @overload fun(lhs: ImVec2, rhs: ImVec2): ImVec2
--@hoist
@native
function ImMin(lhs, rhs)
    if type(lhs) == "number" then return mathMin(lhs, rhs) end
    return ImVec2(mathMin(lhs.x, rhs.x), mathMin(lhs.y, rhs.y))
end

--- @overload fun(lhs: number, rhs: number): number
--- @overload fun(lhs: ImVec2, rhs: ImVec2): ImVec2
--@hoist
@native
function ImMax(lhs, rhs)
    if type(lhs) == "number" then return mathMax(lhs, rhs) end
    return ImVec2(mathMax(lhs.x, rhs.x), mathMax(lhs.y, rhs.y))
end

-- Helpers: Sorting
--- @param base     table
--- @param count    int
--- @param cmp_func fun(lhs, rhs): bool
ImStd.ImQsort = function(base, count, cmp_func) if count > 0 then t_sort(base, cmp_func) end end

--- @overload fun(v: number, mn: number, mx: number): number
--- @overload fun(v: ImVec2, mn: ImVec2, mx: ImVec2): ImVec2
--@hoist
@native
function ImClamp(v, mn, mx)
    if     type(v) == "number" and type(mn) == "number" and type(mx) == "number" then return mathMin(mathMax(v, mn), mx)
    elseif type(v) == "table"  and type(mn) == "table"  and type(mx) == "table"  then return ImVec2(mathMax(mn.x, mathMin(v.x, mx.x)), mathMax(mn.y, mathMin(v.y, mx.y)))
    end
end

--- @overload fun(a: number, b: number, t: number): number
--- @overload fun(a: ImVec2, b: ImVec2, t: number): ImVec2
--- @overload fun(a: ImVec2, b: ImVec2, t: ImVec2): ImVec2
--@hoist
@native
function ImLerp(a, b, t)
    if     type(a) == "number" and type(b) == "number" and type(t) == "number" then return ((a) + ((b) - (a)) * (t))
    elseif type(a) == "table"  and type(b) == "table"  and type(t) == "number" then return ImVec2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
    elseif type(a) == "table"  and type(b) == "table"  and type(t) == "table"  then return ImVec2(a.x + (b.x - a.x) * t.x, a.y + (b.y - a.y) * t.y)
    end
end

--@hoist
local function _Trunc(val) if val >= 0 then return mathFloor(val) else return mathCeil(val) end end

--- @overload fun(v: float): float
--- @overload fun(v: ImVec2): ImVec2
--@hoist
function ImTrunc(v)
    if     type(v) == "number" then return _Trunc(v)
    elseif type(v) == "table"  then return ImVec2(_Trunc(v.x), _Trunc(v.y))
    end
end

ImTrunc64 = _Trunc

-- Consider using the bit-hack version (search for "0x1p120f").
--- @param f float
function ImCeilFast(f)
    local i
    if f >= 0 then i = math.floor(f) else i = math.ceil(f) end -- same as `ImTrunc()`
    if f > i then return i + 1 end
    return i
end

function IM_ROUNDUP_TO_EVEN(n) return (ImCeil((n) / 2) * 2) end
function ImRsqrt(x)            return (1 / ImSqrt(x))       end
-- Converge to more precise solution using single step of Newton-Raphson method, repeating increases precision
function ImRsqrtPrecise(x)     return (1 / ImSqrt(x))       end -- [Luau] non-SSE upstream variant

function ImIsTruncated(x) return x % 1 == 0 end -- (float)(int)x == x
-- Returns true if all parameters are whole numbers.
function ImIsTruncated4(x, y, z, w) return x % 1 == 0 and y % 1 == 0 and z % 1 == 0 and w % 1 == 0 end

function IM_TRUNC(VAL) return math.floor(VAL) end -- Positive values only!
function IM_ROUND(VAL) return math.floor(VAL + 0.5) end -- Positive values only!

--@hoist
function ImFloor(f) return math.floor(f) end -- Decent replacement for floorf() -- [Luau] upstream: (int)f truncates, -1 for negatives == math.floor

-- Helpers: Bit manipulation
--- @param v int
function ImIsPowerOfTwo(v)
    return (v ~= 0) and (bitAnd(v, (v - 1)) == 0)
end

function ImUpperPowerOfTwo(v)
    if v <= 0 then return 0 end
    if v <= 1 then return 1 end

    v = v - 1
    v = bitOr(v, bitRShift(v, 1))
    v = bitOr(v, bitRShift(v, 2))
    v = bitOr(v, bitRShift(v, 4))
    v = bitOr(v, bitRShift(v, 8))
    v = bitOr(v, bitRShift(v, 16))
    return v + 1
end

--- @param v unsigned_int
--- @return unsigned_int
function ImCountSetBits(v)
    local count = 0
    while v > 0 do
        v = bitAnd(v, v - 1)
        count = count + 1
    end
    return count
end

--- @param avg    float
--- @param sample float
--- @param n      int
--- @return float
function ImStd.ImExponentialMovingAverage(avg, sample, n)
    avg = avg - avg / n
    avg = avg + sample / n
    return avg
end

-- Uses `string.match` internally
--- @param str string
function ImAtof(str)
    return tonumber(string.match(str, "[+-]?%d*%.?%d+"))
end

--- @param s table # 1-based
--- @param c any
--- @param n int
function ImStd.memset(s, c, n)
    for i = 1, n do s[i] = c end
end

do

local _memmove = function(dest, dest_start, src, src_start, count)
    if count <= 0 then return end

    -- more compact instead of writing separate if-else and for loops
    local c = (dest == src and dest_start >= src_start)
    for i = (c and count - 1 or 0), (c and 0 or count - 1), (c and -1 or 1) do
        dest[dest_start + i] = src[src_start + i]
    end
end

if table.move then
    --- [GMod] Platform specific: the `table.move` polyfill in non-x86-64 currently uses `unpack` which will break if too many elements
    -- Remove this check when the polyfill is fixed or removed
    if not gmod or (gmod and BRANCH == "x86-64") then
        _memmove = function(dest, dest_start, src, src_start, count)
            table.move(src, src_start, src_start + count - 1, dest_start, dest)
        end
    end
end

ImStd.memmove = _memmove

end

--- @param str1 ImStringBuffer
--- @param str2 ImStringBuffer
function ImStd.strcmp(str1, str2)
    local i = 1
    while true do
        local c1 = str1[i] or 0
        local c2 = str2[i] or 0

        if c1 ~= c2 then
            return c1 - c2
        end

        if c1 == 0 then
            return 0
        end

        i = i + 1
    end
end

--- @param str1      ImStringBuffer
--- @param str2      ImStringBuffer
--- @param max_count int
function ImStd.strncmp(str1, str2, max_count)
    for i = 1, max_count do
        local c1 = str1[i] or 0
        local c2 = str2[i] or 0

        if c1 ~= c2 then
            return c1 - c2
        end

        if c1 == 0 then
            return 0
        end
    end
    return 0
end

--@hoist
function ImSaturate(f) return ((f < 0.0 and 0.0) or (f > 1.0 and 1.0) or f) end

--- @param x float
--- @return float # Sign operator - returns -1, 0 or 1 based on sign of argument
function ImSign(x) if x < 0.0 then return -1.0 elseif x > 0.0 then return 1.0 end return 0.0 end

function ImLinearRemapClamp(s0, s1, d0, d1, x) return ImSaturate((x - s0) / (s1 - s0)) * (d1 - d0) + d0 end

--- @param c int # byte
--- @return int
function ImToUpper(c) if c >= 97 and c <= 122 then return bit32.band(c, bit32.bnot(32)) end return c end

IM_F32_TO_INT8_UNBOUND = function(val) return math.floor(val * 255.0 + (val >= 0 and 0.5 or -0.5)) end -- Unsaturated, for display purpose
IM_F32_TO_INT8_SAT = function(val) return math.floor(ImSaturate(val) * 255.0 + 0.5) end -- Saturated, always output 0..255

--- @param s ImString
--- @param i int
--- @return char
function ImStrByte(s, i)
    if type(s) == "string" then
        return string.byte(s, i, i)
    else --- @cast s char[]
        return s[i]
    end
end

-- Stacked color modifier, backup of modified data so we can restore it
--- @class ImGuiColorMod
--- @field Col         ImGuiCol
--- @field BackupValue ImVec4

--- @param col          ImGuiCol
--- @param backup_value ImVec4
--- @return ImGuiColorMod
function ImGuiColorMod(col, backup_value)
    local this = {
        Col = col,
        BackupValue = ImVec4()
    }

    ImVec4_Copy(this.BackupValue, backup_value)

    return this
end

--- @param lhs ImVec2
--- @return float
function ImLengthSqr(lhs) return (lhs.x * lhs.x) + (lhs.y * lhs.y) end

--- @param v     ImVec2
--- @param cos_a float
--- @param sin_a float
--- @return ImVec2
--- @nodiscard
function ImRotate(v, cos_a, sin_a)
    return ImVec2(v.x * cos_a - v.y * sin_a, v.x * sin_a + v.y * cos_a)
end

--- @param a ImVec2
--- @param b ImVec2
function ImDot(a, b)
    return a.x * b.x + a.y * b.y
end

--- @param lhs ImVec2
--- @param rhs ImVec2
--- @nodiscard
function ImMul(lhs, rhs)
    return ImVec2(lhs.x * rhs.x, lhs.y * rhs.y)
end

--- @param a ImVec2
--- @param b ImVec2
--- @param c ImVec2
--- @return float
function ImTriangleArea(a, b, c) return ImFabs((a.x * (b.y - c.y)) + (b.x * (c.y - a.y)) + (c.x * (a.y - b.y))) * 0.5 end

--- @param a ImVec2
--- @param b ImVec2
--- @param c ImVec2
--- @return boolean
function ImTriangleIsClockwise(a, b, c) return ((b.x - a.x) * (c.y - b.y)) - ((c.x - b.x) * (b.y - a.y)) > 0.0 end

--- @param str    char[]
--- @param begin? int
function ImStd.ImStrlen(str, begin)
    if begin == nil then begin = 1 end

    local l = #str

    for i = begin, l do
        if str[i] == 0 then
            return i - begin
        end
    end

    IM_ASSERT(false)
end

-- FIXME: should also accept count?
-- FIXME: avoid dynamic type checking?
-- string.find with patterns disabled
--- @param str        string|char[]
--- @param s          string|char
--- @param start_pos? int
--- @return int?
function ImMemchr(str, s, start_pos)
    local start = start_pos or 1
    if start < 1 then start = 1 end

    if type(str) == "table" then
        for i = start, #str do
            if str[i] == 0 then break end

            if str[i] == s then
                return i
            end
        end

        return nil
    end

    --- @cast str string
    local pos = string.find(str, s, start, true)

    return pos
end

IMGUI_FONT_SIZE_MAX                                = 512.0
IMGUI_FONT_SIZE_THRESHOLD_FOR_LOADADVANCEXONLYMODE = 128.0

IMGUI_WINDOW_HARD_MIN_SIZE = 4.0

-- ImDrawList: Lookup tables
IM_DRAWLIST_ARCFAST_TABLE_SIZE = 48 -- Number of samples in adaptive arc drawing lookup table.
IM_DRAWLIST_ARCFAST_SAMPLE_MAX = IM_DRAWLIST_ARCFAST_TABLE_SIZE -- Sample index _PathArcToFastEx() for 360 angle.

IM_DRAWLIST_TEX_LINES_WIDTH_MAX       = 32 -- The maximum line width to bake anti-aliased textures for.
IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH  = 4  -- Calculate detailed textures for width [1..IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH]
IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT    = 4  -- How many samples per integer thickness level.
IM_DRAWLIST_TEX_CORNERS_ROUNDING_MAX  = 16
IM_DRAWLIST_TEX_CORNERS_THICKNESS_MAX = 4  -- 0: fill, 1-3: strokes thickness
IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH_COUNT = ((IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH - 1) * IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT + 1)

-- Macros used by Recoverable Error handling
-- - Only dispatch error if _EXPR: evaluate as assert (similar to an assert macro).
-- - The message will always be a string literal, in order to increase likelihood of being display by an assert handler.
-- - See 'Demo->Configuration->Error Handling' and ImGuiIO definitions for details on error handling.
-- - Read https://github.com/ocornut/imgui/wiki/Error-Handling for details on error handling.
-- Upstream: `if (!(expr) && ErrorLog(msg)) IM_ASSERT(0)`. ErrorLog() returns io.ConfigErrorRecoveryEnableAssert.
function IM_ASSERT_USER_ERROR(_EXPR, _MSG) if not (_EXPR) or (_EXPR) == 0 then if not ImGui.ErrorLog or ImGui.ErrorLog(_MSG) then error(_MSG, 2) end end end -- Recoverable User Error
function IM_ASSERT_USER_ERROR_RET(_EXPR, _MSG) if not (_EXPR) or (_EXPR) == 0 then error(_MSG, 2) end end

-- Debug Logging for ShowDebugLogWindow(). This is designed for relatively rare events so please don't spam.
local function DebugLogIf(flag, fmt, ...)
    local g = GImGui
    if g and bitAnd(g.DebugLogFlags, flag) ~= 0 then ImGui.DebugLog(fmt, ...) end
end
function IMGUI_DEBUG_LOG_ACTIVEID(...) DebugLogIf(ImGuiDebugLogFlags.EventActiveId, ...) end
function IMGUI_DEBUG_LOG_POPUP(...) DebugLogIf(ImGuiDebugLogFlags.EventPopup, ...) end
function IMGUI_DEBUG_LOG_FONT(...) DebugLogIf(ImGuiDebugLogFlags.EventFont, ...) end -- Called from ImFontAtlas function which may operate without a context.
function IMGUI_DEBUG_LOG_VIEWPORT(...) DebugLogIf(ImGuiDebugLogFlags.EventViewport, ...) end
function IMGUI_DEBUG_LOG_FOCUS(...) DebugLogIf(ImGuiDebugLogFlags.EventFocus, ...) end
function IMGUI_DEBUG_LOG_NAV(...) DebugLogIf(ImGuiDebugLogFlags.EventNav, ...) end
function IMGUI_DEBUG_LOG_IO(...) DebugLogIf(ImGuiDebugLogFlags.EventIO, ...) end
function IMGUI_DEBUG_LOG_INPUTROUTING(...) DebugLogIf(ImGuiDebugLogFlags.EventInputRouting, ...) end
function IMGUI_DEBUG_LOG_TABLE(...) DebugLogIf(ImGuiDebugLogFlags.EventTable, ...) end
function IMGUI_DEBUG_LOG_DOCKING(...) DebugLogIf(ImGuiDebugLogFlags.EventDocking, ...) end
function IMGUI_DEBUG_LOG_SELECTION(...) DebugLogIf(ImGuiDebugLogFlags.EventSelection, ...) end
function IMGUI_DEBUG_LOG_CLIPPER(...) DebugLogIf(ImGuiDebugLogFlags.EventClipper, ...) end
function IMGUI_DEBUG_LOG_ERROR(...) DebugLogIf(ImGuiDebugLogFlags.EventError, ...) end

--- @alias ImGuiSelectionUserData any
ImGuiSelectionUserData_Invalid = -1

-- Input function taking an 'ImGuiID owner_id' argument defaults to (ImGuiKeyOwner_Any == 0) aka don't test ownership, which matches legacy behavior.
ImGuiKeyOwner_Any     = 0 -- Accept key that have an owner, UNLESS a call to SetKeyOwner() explicitly used ImGuiInputFlags.LockThisFrame or ImGuiInputFlags.LockUntilRelease.
ImGuiKeyOwner_NoOwner = 4294967295 -- Require key to have no owner.

-------------------------------------------------------------------------------
-- [SECTION] ImGui internal API
-- No guarantee of forward compatibility here!
-------------------------------------------------------------------------------

-- Inputs
-- FIXME: Eventually we should aim to move e.g. IsActiveIdUsingKey() into IsKeyXXX functions.
--- @param button ImGuiMouseButton
--- @return ImGuiKey
function ImGui.MouseButtonToKey(button) IM_ASSERT(button >= 0 and button < ImGuiMouseButton.COUNT) return ImGuiKey.MouseLeft + button end

--- @param key ImGuiKey
function ImGui.IsNamedKey(key)
    return key >= ImGuiKey.NamedKey_BEGIN and key < ImGuiKey.NamedKey_END
end

--- @param key ImGuiKey
function ImGui.IsKeyboardKey(key)
    return key >= ImGuiKey_Keyboard_BEGIN and key < ImGuiKey_Keyboard_END
end

--- @param key ImGuiKey
function ImGui.IsGamepadKey(key)
    return key >= ImGuiKey_Gamepad_BEGIN and key < ImGuiKey_Gamepad_END
end

--- @param key ImGuiKey
function ImGui.IsMouseKey(key)
    return key >= ImGuiKey_Mouse_BEGIN and key < ImGuiKey_Mouse_END
end

--- @param key ImGuiKey
function ImGui.IsAliasKey(key)
    return key >= ImGuiKey_Aliases_BEGIN and key < ImGuiKey_Aliases_END
end

--- @param key ImGuiKey
function ImGui.IsLRModKey(key)
    return key >= ImGuiKey.LeftCtrl and key <= ImGuiKey.RightSuper
end

--- @param key ImGuiKey
--- @return bool
function ImGui.IsNamedKeyOrMod(key)
    return (key >= ImGuiKey.NamedKey_BEGIN and key < ImGuiKey.NamedKey_END) or key == ImGuiMod_Ctrl or key == ImGuiMod_Shift or key == ImGuiMod_Alt or key == ImGuiMod_Super
end

--- @param key ImGuiKey
--- @return ImGuiKey
function ImGui.ConvertSingleModFlagToKey(key)
    if key == ImGuiMod_Ctrl then
        return ImGuiKey.ReservedForModCtrl
    elseif key == ImGuiMod_Shift then
        return ImGuiKey.ReservedForModShift
    elseif key == ImGuiMod_Alt then
        return ImGuiKey.ReservedForModAlt
    elseif key == ImGuiMod_Super then
        return ImGuiKey.ReservedForModSuper
    end
    return key
end

-- [EXPERIMENTAL] Low-Level: Key/Input Ownership
-- - The idea is that instead of "eating" a given input, we can link to an owner id.
-- - Ownership is most often claimed as a result of reacting to a press/down event (but occasionally may be claimed ahead).
-- - Input queries can then read input by specifying ImGuiKeyOwner_Any (== 0), ImGuiKeyOwner_NoOwner (== -1) or a custom ID.
-- - Legacy input queries (without specifying an owner or _Any or _None) are equivalent to using ImGuiKeyOwner_Any (== 0).
-- - Input ownership is automatically released on the frame after a key is released. Therefore:
--   - for ownership registration happening as a result of a down/press event, the SetKeyOwner() call may be done once (common case).
--   - for ownership registration happening ahead of a down/press event, the SetKeyOwner() call needs to be made every frame (happens if e.g. claiming ownership on hover).
-- - SetItemKeyOwner() is a shortcut for common simple case. A custom widget will probably want to call SetKeyOwner() multiple times directly based on its interaction state.
-- - This is marked experimental because not all widgets are fully honoring the Set/Test idioms. We will need to move forward step by step.
--   Please open a GitHub Issue to submit your usage scenario or if there's a use case you need solved.
--- @param ctx ImGuiContext
--- @param key ImGuiKey
function ImGui.GetKeyOwnerData(ctx, key)
    if bitAnd(key, ImGuiMod_Mask_) ~= 0 then key = ImGui.ConvertSingleModFlagToKey(key) end
    IM_ASSERT(ImGui.IsNamedKey(key))
    return ctx.KeysOwnerData[key - ImGuiKey.NamedKey_BEGIN]
end

-- This extends ImGuiKeyData but only for named keys (legacy keys don't support the new features)
-- Stored in main context (1 per named key). In the future it might be merged into ImGuiKeyData.
--- @class ImGuiKeyOwnerData

--- @return ImGuiKeyOwnerData
--- @nodiscard
function ImGuiKeyOwnerData()
    return {
        OwnerCurr        = ImGuiKeyOwner_NoOwner,
        OwnerNext        = ImGuiKeyOwner_NoOwner,
        LockThisFrame    = false, -- Reading this key requires explicit owner id (until end of frame). Set by ImGuiInputFlags.LockThisFrame.
        LockUntilRelease = false  -- Reading this key requires explicit owner id (until key is released). Set by ImGuiInputFlags.LockUntilRelease. When this is true LockThisFrame is always true as well.
    }
end

--- @param size float
--- @return float
function ImGui.GetRoundedFontSize(size) return IM_ROUND(size) end

--- @param window ImGuiWindow
--- @param r      ImRect
--- @return ImRect
--- @nodiscard
function ImGui.WindowRectAbsToRel(window, r) local off = window.DC.CursorStartPos return ImRect(r.Min.x - off.x, r.Min.y - off.y, r.Max.x - off.x, r.Max.y - off.y) end

--- @param window ImGuiWindow
--- @param r      ImRect
--- @nodiscard
function ImGui.WindowRectRelToAbs(window, r) local off = window.DC.CursorStartPos return ImRect(r.Min.x + off.x, r.Min.y + off.y, r.Max.x + off.x, r.Max.y + off.y) end

--- @param dir ImGuiDir
--- @return bool
function ImGui.IsActiveIdUsingNavDir(dir)
    local g = GImGui
    return bit32.band(g.ActiveIdUsingNavDirMask, bit32.lshift(1, dir)) ~= 0
end

--- @param window ImGuiWindow
--- @param p      ImVec2
--- @return ImVec2
--- @nodiscard
function ImGui.WindowPosAbsToRel(window, p) local off = window.DC.CursorStartPos return ImVec2(p.x - off.x, p.y - off.y) end

--- @param window ImGuiWindow
--- @param p      ImVec2
--- @return ImVec2
--- @nodiscard
function ImGui.WindowPosRelToAbs(window, p) local off = window.DC.CursorStartPos return ImVec2(p.x + off.x, p.y + off.y) end

--- @param c char
--- @return bool # True if this character is a ' ' or '\t'
function ImCharIsBlankA(c) return c == 32 or c == 9 end

--- @param c char
function ImCharIsBlankW(c) return c == 32 or c == 9 or c == 0x3000 end

--- @param c char
function ImCharIsXdigitA(c) return (c >= 48 and c <= 57) or (c >= 65 and c <= 70) or (c >= 97 and c <= 102) end

--- @param lhs        ImVec2
--- @param fail_value float
function ImInvLength(lhs, fail_value) local d = (lhs.x * lhs.x) + (lhs.y * lhs.y); if d > 0.0 then return ImRsqrt(d) end; return fail_value end
function ImRoundPositive64(f) return _Trunc(f + 0.5) end -- Positive values only.
function ImRoundSigned64(f) if f >= 0.0 then return _Trunc(f + 0.5) else return _Trunc(f - 0.5) end end
-- [Luau] C '%' truncates toward zero; math.fmod matches it
function ImModPositive(a, b) return math.fmod(a + b, b) end
function ImIsFloatAboveGuaranteedIntegerPrecision(f) return f <= -16777216 or f >= 16777216 end

-- Helper: ImVec2i (2D vector, integer) / ImVec2ih (2D vector, half-size integer, for long-term packed storage)
-- [Luau] both are plain ImVec2 holding whole numbers
function ImVec2i(x, y) return ImVec2(x or 0, y or 0) end
--- @overload fun(rhs: ImVec2): ImVec2
function ImVec2ih(x, y)
    if type(x) == "table" then return ImVec2(_Trunc(x.x), _Trunc(x.y)) end
    return ImVec2(x or 0, y or 0)
end

--- @enum ImGuiNavMoveFlags
ImGuiNavMoveFlags =
{
    None                  = 0,
    LoopX                 = bitLShift(1, 0), -- On failed request, restart from opposite side
    LoopY                 = bitLShift(1, 1),
    WrapX                 = bitLShift(1, 2), -- On failed request, request from opposite side one line down (when NavDir==right) or one line up (when NavDir==left)
    WrapY                 = bitLShift(1, 3), -- This is not super useful but provided for completeness
    AllowCurrentNavId     = bitLShift(1, 4), -- Allow scoring and considering the current NavId as a move target candidate. This is used when the move source is offset (e.g. pressing PageDown actually needs to send a Up move request, if we are pressing PageDown from the bottom-most item we need to stay in place)
    AlsoScoreVisibleSet   = bitLShift(1, 5), -- Store alternate result in NavMoveResultLocalVisible that only comprise elements that are already fully visible (used by PageUp/PageDown)
    ScrollToEdgeY         = bitLShift(1, 6), -- Force scrolling to min/max (used by Home/End) -- FIXME-NAV: Aim to remove or reword as ImGuiScrollFlags
    Forwarded             = bitLShift(1, 7),
    DebugNoResult         = bitLShift(1, 8), -- Dummy scoring for debug purpose, don't apply result
    FocusApi              = bitLShift(1, 9), -- Requests from focus API can land/focus/activate items even if they are marked with _NoTabStop (see NavProcessItemForTabbingRequest() for details)
    IsTabbing             = bitLShift(1, 10), -- == Focus + Activate if item is Inputable + DontChangeNavHighlight
    IsPageMove            = bitLShift(1, 11), -- Identify a PageDown/PageUp request.
    Activate              = bitLShift(1, 12), -- Activate/select target item.
    NoSelect              = bitLShift(1, 13), -- Don't trigger selection by not setting g.NavJustMovedTo
    NoSetNavCursorVisible = bitLShift(1, 14), -- Do not alter the nav cursor visible state
    NoClearActiveId       = bitLShift(1, 15), -- (Experimental) Do not clear active id when applying move result
}

ImGuiNavMoveFlags.WrapMask_ = bitOr(ImGuiNavMoveFlags.LoopX, ImGuiNavMoveFlags.LoopY, ImGuiNavMoveFlags.WrapX, ImGuiNavMoveFlags.WrapY)

--- @enum ImGuiNavLayer
ImGuiNavLayer =
{
    Main  = 0, -- Main scrolling layer
    Menu  = 1, -- Menu layer (access with Alt)
    COUNT = 2
}

-------------------------------------------------------------------------------
-- [SECTION] Widgets support: flags, enums, data structures
-------------------------------------------------------------------------------

-- Extend ImGuiItemFlags
-- - input: PushItemFlag() manipulates g.CurrentItemFlags, g.NextItemData.ItemFlags, ItemAdd() calls may add extra flags too.
-- - output: stored in g.LastItemData.ItemFlags

-- Controlled by user
ImGuiItemFlags.ReadOnly               = bitLShift(1, 11) -- false -- [ALPHA] Allow hovering interactions but underlying value is not changed.
ImGuiItemFlags.MixedValue             = bitLShift(1, 12)
ImGuiItemFlags.NoWindowHoverableCheck = bitLShift(1, 13) -- false -- Disable hoverable check in ItemHoverable()
ImGuiItemFlags.AllowOverlap           = bitLShift(1, 14) -- false -- Allow being overlapped by another widget. Not-hovered to Hovered transition deferred by a frame.
ImGuiItemFlags.NoNavDisableMouseHover = bitLShift(1, 15) -- false -- Nav keyboard/gamepad mode doesn't disable hover highlight (behave as if NavHighlightItemUnderNav==false).
ImGuiItemFlags.NoMarkEdited           = bitLShift(1, 16) -- false -- Skip calling MarkItemEdited()
ImGuiItemFlags.NoFocus                = bitLShift(1, 17) -- false -- [EXPERIMENTAL: Not very well specced] Clicking doesn't take focus. Automatically sets ImGuiButtonFlags.NoFocus + ImGuiButtonFlags.NoNavFocus in ButtonBehavior().

-- Controlled by widget code
ImGuiItemFlags.Inputable            = bitLShift(1, 20) -- false -- [WIP] Auto-activate input mode when tab focused. Currently only used and supported by a few items before it becomes a generic feature.
ImGuiItemFlags.HasSelectionUserData = bitLShift(1, 21) -- false -- Set by SetNextItemSelectionUserData()
ImGuiItemFlags.IsMultiSelect        = bitLShift(1, 22) -- false -- Set by SetNextItemSelectionUserData()

ImGuiItemFlags.Default_ = bitOr(ImGuiItemFlags.AutoClosePopups, ImGuiItemFlags.LiveEditOnInputText) -- Please don't change, use PushItemFlag() instead.

-- Helpers: High-level text functions (DO NOT USE!!! THIS IS A MINIMAL SUBSET OF LARGER UPCOMING CHANGES)
--- @enum ImDrawTextFlags
ImDrawTextFlags =
{
    None           = 0,
    CpuFineClip    = bitLShift(1, 0), -- Must be == 1/true for legacy with 'bool cpu_fine_clip' arg to RenderText()
    WrapKeepBlanks = bitLShift(1, 1),
    StopOnNewLine  = bitLShift(1, 2)
}

-- Flags for FocusWindow(). This is not called ImGuiFocusFlags to avoid confusion with public-facing ImGuiFocusedFlags.
-- FIXME: Once we finishing replacing more uses of GetTopMostPopupModal()+IsWindowWithinBeginStackOf()
-- and FindBlockingModal() with this, we may want to change the flag to be opt-out instead of opt-in.
--- @enum ImGuiFocusRequestFlags
ImGuiFocusRequestFlags =
{
    None                = 0,
    RestoreFocusedChild = bitLShift(1, 0), -- Find last focused child (if any) and focus it instead.
    UnlessBelowModal    = bitLShift(1, 1)  -- Do not set focus if the window is below a modal.
}

--- @enum ImGuiTextFlags
ImGuiTextFlags =
{
    None                       = 0,
    NoWidthForLargeClippedText = bitLShift(1, 0)
}

-- Character classification for word-wrapping logic
--- @enum ImWcharClass
ImWcharClass =
{
    Blank = 0,
    Punct = 1,
    Other = 2
}

-- Helper: ImVec1 (1D vector)
-- (this odd construct is used to facilitate the transition between 1D and 2D, and the maintenance of some branches/patches)
--- @class ImVec1
--- @field x number
local IM_VEC1 = {}
IM_VEC1.__index = IM_VEC1

local function ImVec1(x) return setmetatable({x = x or 0}, IM_VEC1) end

function IM_VEC1:__tostring() return string.format("ImVec1(%g)", self.x) end

--- @param dest ImVec1
--- @param src  ImVec1
function ImVec1_Copy(dest, src)
    dest.x = src.x
end

-- Helper: ImRect (2D axis aligned bounding-box)
-- NB: we can't rely on ImVec2 math operators being available here!
--- @class ImRect
--- @field [1] ImVec2
--- @field [2] ImVec2
--- @field Min ImVec2 # Upper-left
--- @field Max ImVec2 # Lower-right
local IM_RECT = {}
setmetatable(IM_RECT, { __index = function(_, k) if k ~= "Min" and k ~= "Max" then error("ImRect: unknown key " .. tostring(k), 2) end end })

--- @param t ImRect
--- @param k string
IM_RECT.__index = IM_RECT -- [Luau] plain table: fast method lookup. Use r.Min / r.Max (numeric r[1]/r[2] are not supported)

-- [Luau] Min/Max are named fields, so `r.Min = v` assigns the reference: use ImVec2_Copy(r.Min, v) to keep copy semantics
IM_RECT.__newindex = function(t, k, v) IM_ASSERT(false, "ImRect: unknown field " .. tostring(k)) end

--- @return ImRect
--- @nodiscard
@native
function ImRect(a, b, c, d) if c and d then return setmetatable({ Min = ImVec2(a, b), Max = ImVec2(c, d) }, IM_RECT) end return setmetatable({ Min = ImVec2(a and a.x or 0, a and a.y or 0), Max = ImVec2(b and b.x or 0, b and b.y or 0) }, IM_RECT) end

function IM_RECT:__eq(other) return self.Min == other.Min and self.Max == other.Max end
function IM_RECT:__tostring() return string.format("ImRect(Min: %g,%g, Max: %g,%g)", self.Min.x, self.Min.y, self.Max.x, self.Max.y) end

--- @param p ImRect|ImVec2
@native
function IM_RECT:Contains(p)
    if p.Min then
        --- @cast p ImRect
        return p.Min.x >= self.Min.x and p.Max.x <= self.Max.x and p.Min.y >= self.Min.y and p.Max.y <= self.Max.y
    else
        --- @cast p ImVec2
        return p.x >= self.Min.x and p.y >= self.Min.y and p.x < self.Max.x and p.y < self.Max.y
    end
end

--- @param p   ImVec2
--- @param pad ImVec2
function IM_RECT:ContainsWithPad(p, pad)
    return p.x >= self.Min.x - pad.x and p.y >= self.Min.y - pad.y and p.x < self.Max.x + pad.x and p.y < self.Max.y + pad.y
end

--- @param r ImRect
@native
function IM_RECT:Overlaps(r)
    return self.Min.x <= r.Max.x and self.Max.x >= r.Min.x and self.Min.y <= r.Max.y and self.Max.y >= r.Min.y
end

--- @nodiscard
function IM_RECT:GetCenter() return ImVec2((self.Min.x + self.Max.x) * 0.5, (self.Min.y + self.Max.y) * 0.5) end
function IM_RECT:GetWidth() return self.Max.x - self.Min.x end
function IM_RECT:GetHeight() return self.Max.y - self.Min.y end
--- @nodiscard
@native
function IM_RECT:GetSize() return ImVec2(self.Max.x - self.Min.x, self.Max.y - self.Min.y) end

--- @nodiscard
function IM_RECT:GetTL() return ImVec2(self.Min.x, self.Min.y) end -- Top-left
--- @nodiscard
function IM_RECT:GetTR() return ImVec2(self.Max.x, self.Min.y) end -- Top-right
--- @nodiscard
function IM_RECT:GetBL() return ImVec2(self.Min.x, self.Max.y) end -- Bottom-left
--- @nodiscard
function IM_RECT:GetBR() return ImVec2(self.Max.x, self.Max.y) end -- Bottom-right

-- Simple version, may lead to an inverted rectangle, which is fine for Contains/Overlaps test but not for display.
--- @param r ImRect
@native
function IM_RECT:ClipWith(r)
    -- [Luau] scalar math, no temporary ImVec2 (= ImMax(Min, r.Min) / ImMin(Max, r.Max))
    local smin, smax, rmin, rmax = self.Min, self.Max, r.Min, r.Max
    smin.x = mathMax(smin.x, rmin.x); smin.y = mathMax(smin.y, rmin.y)
    smax.x = mathMin(smax.x, rmax.x); smax.y = mathMin(smax.y, rmax.y)
end

-- Full version, ensure both points are fully clipped.
--- @param r ImRect
@native
function IM_RECT:ClipWithFull(r)
    -- [Luau] scalar math, no temporary ImVec2 (= ImClamp(Min/Max, r.Min, r.Max))
    local smin, smax, rmin, rmax = self.Min, self.Max, r.Min, r.Max
    local min_x, min_y, max_x, max_y = rmin.x, rmin.y, rmax.x, rmax.y
    smin.x = mathMax(min_x, mathMin(smin.x, max_x)); smin.y = mathMax(min_y, mathMin(smin.y, max_y))
    smax.x = mathMax(min_x, mathMin(smax.x, max_x)); smax.y = mathMax(min_y, mathMin(smax.y, max_y))
end

--- @param p ImRect|ImVec2
@native
function IM_RECT:Add(p)
    if p.Min then
        --- @cast p ImRect
        if (self.Min.x > p.Min.x) then self.Min.x = p.Min.x end
        if (self.Min.y > p.Min.y) then self.Min.y = p.Min.y end
        if (self.Max.x < p.Max.x) then self.Max.x = p.Max.x end
        if (self.Max.y < p.Max.y) then self.Max.y = p.Max.y end
    else
        --- @cast p ImVec2
        if p.x < self.Min.x then self.Min.x = p.x end
        if p.y < self.Min.y then self.Min.y = p.y end
        if p.x > self.Max.x then self.Max.x = p.x end
        if p.y > self.Max.y then self.Max.y = p.y end
    end
end

function IM_RECT:AddX(x) if self.Min.x > x then self.Min.x = x end if self.Max.x < x then self.Max.x = x end end
function IM_RECT:AddY(y) if self.Min.y > y then self.Min.y = y end if self.Max.y < y then self.Max.y = y end end

--- @param amount float|ImVec2
@native
function IM_RECT:Expand(amount)
    if     type(amount) == "number" then
        self.Min.x = self.Min.x - amount; self.Min.y = self.Min.y - amount
        self.Max.x = self.Max.x + amount; self.Max.y = self.Max.y + amount
    elseif type(amount) == "table"  then
        self.Min.x = self.Min.x - amount.x; self.Min.y = self.Min.y - amount.y
        self.Max.x = self.Max.x + amount.x; self.Max.y = self.Max.y + amount.y
    end
end

--- @nodiscard
function IM_RECT:ToVec4()
    return ImVec4(self.Min.x, self.Min.y, self.Max.x, self.Max.y)
end

--- @param d ImVec2
@native
function IM_RECT:Translate(d)
    self.Min.x = self.Min.x + d.x; self.Min.y = self.Min.y + d.y
    self.Max.x = self.Max.x + d.x; self.Max.y = self.Max.y + d.y
end

--- @param dx float
function IM_RECT:TranslateX(dx)
    self.Min.x = self.Min.x + dx; self.Max.x = self.Max.x + dx
end

--- @param dy float
function IM_RECT:TranslateY(dy)
    self.Min.y = self.Min.y + dy; self.Max.y = self.Max.y + dy
end

function IM_RECT:IsInverted() return self.Min.x > self.Max.x or self.Min.y > self.Max.y end

function IM_RECT:GetArea() return (self.Max.x - self.Min.x) * (self.Max.y - self.Min.y) end

--- @nodiscard
function IM_RECT:AsVec4() return ImVec4(self.Min.x, self.Min.y, self.Max.x, self.Max.y) end

--- @param dest ImRect
--- @param src  ImRect
@native
function ImRect_Copy(dest, src)
    dest.Min.x = src.Min.x; dest.Min.y = src.Min.y
    dest.Max.x = src.Max.x; dest.Max.y = src.Max.y
end

--- @param dest ImRect
--- @param src  ImVec4
function ImRect_CopyFromV4(dest, src)
    dest.Min.x = src.x; dest.Min.y = src.y
    dest.Max.x = src.z; dest.Max.y = src.w
end

-- Helper: ImBitArray
-- Macro version of ImBitArrayTestBit(): ensure args have side-effect or are costly!
--- @param _ARRAY ImU32[]
--- @param _N     int
function IM_BITARRAY_TESTBIT(_ARRAY, _N)
    return bitAnd(_ARRAY[bitRShift(_N - 1, 5) + 1], bitLShift(1, bitAnd(_N - 1, 31))) ~= 0
end

-- Macro version of ImBitArrayClearBit(): ensure args have side-effect or are costly!
--- @param _ARRAY ImU32[]
--- @param _N     int
function IM_BITARRAY_CLEARBIT(_ARRAY, _N)
    local idx = bitRShift(_N - 1, 5) + 1
    _ARRAY[idx] = bitAnd(_ARRAY[idx], bitNot(bitLShift(1, bitAnd(_N - 1, 31))))
end

--- @param arr ImU32[]
--- @param n   int
function ImBitArraySetBit(arr, n)
    local mask = bitLShift(1, bitAnd(n - 1, 31))
    local idx = bitRShift(n - 1, 5) + 1
    arr[idx] = bitOr(arr[idx], mask)
end

-- [Luau] bit arrays are ImU32[] tables with 1-based word indices; bit indices 'n' are 1-based like the functions above
--- @param bitcount int
function ImBitArrayGetStorageSizeInBytes(bitcount) return bitLShift(bitRShift(bitcount + 31, 5), 2) end
--- @param arr      ImU32[]
--- @param bitcount int
function ImBitArrayClearAllBits(arr, bitcount) for i = 1, bitRShift(bitcount + 31, 5) do arr[i] = 0 end end
function ImBitArrayTestBit(arr, n) local mask = bitLShift(1, bitAnd(n - 1, 31)); return bitAnd(arr[bitRShift(n - 1, 5) + 1], mask) ~= 0 end
function ImBitArrayClearBit(arr, n) local mask = bitLShift(1, bitAnd(n - 1, 31)); local idx = bitRShift(n - 1, 5) + 1; arr[idx] = bitAnd(arr[idx], bitNot(mask)) end
-- Works on range [n..n2)
function ImBitArraySetBitRange(arr, n, n2)
    n = n - 1; n2 = n2 - 1 -- [Luau] to 0-based
    n2 = n2 - 1
    while n <= n2 do
        local a_mod = bitAnd(n, 31)
        local b_mod = ((n2 > bitOr(n, 31)) and 31 or bitAnd(n2, 31)) + 1
        local mask = bitAnd(2 ^ b_mod - 1, bitNot(2 ^ a_mod - 1))
        local idx = bitRShift(n, 5) + 1
        arr[idx] = bitOr(arr[idx], mask)
        n = bitAnd(n + 32, bitNot(31))
    end
end

-- Bit array for named keys
--- @alias ImBitArrayForNamedKeys ImBitArray

-- Helper: ImBitArray class (wrapper over ImBitArray functions)
-- Store 1-bit per value.
--- NOTE: This struct is expensive to create
--- @class ImBitArray<BITCOUNT, OFFSET>
--- @field Data ImU32[]

--- @param BITCOUNT int
--- @param OFFSET?  int
--- @return ImBitArray
function ImBitArray(BITCOUNT, OFFSET)
    if OFFSET == nil then OFFSET = 0 end

    local this = { Data = {} }
    local size = bitRShift(BITCOUNT + 31, 5)

    this.ClearAllBits = function(self) local data = self.Data; for i = 1, size do data[i] = 0 end end
    this.SetAllBits   = function(self) local data = self.Data; for i = 1, size do data[i] = 0xFFFFFFFF end end
    --- @param n int # 1-based
    --- @return boolean
    this.TestBit = function(self, n) n = n + OFFSET; IM_ASSERT(n >= 1 and n <= BITCOUNT); return IM_BITARRAY_TESTBIT(self.Data, n); end
    --- @param n int # 1-based
    this.SetBit  = function(self, n) n = n + OFFSET; IM_ASSERT(n >= 1 and n <= BITCOUNT); ImBitArraySetBit(self.Data, n); end

    --- @param n int # 1-based
    this.ClearBit = function(self, n) n = n + OFFSET; IM_ASSERT(n >= 1 and n <= BITCOUNT); ImBitArrayClearBit(self.Data, n); end
    --- @param n int # 1-based, range [n..n2)
    this.SetBitRange = function(self, n, n2) n = n + OFFSET; n2 = n2 + OFFSET; IM_ASSERT(n >= 1 and n <= BITCOUNT and n2 > n and n2 <= BITCOUNT + 1); ImBitArraySetBitRange(self.Data, n, n2); end

    this:ClearAllBits()

    return this
end

-- Helper: ImBitVector
-- Store 1-bit per value.
--- @class ImBitVector
--- @field Storage ImVector<ImU32>
MT.ImBitVector = {}
MT.ImBitVector.__index = MT.ImBitVector
function ImBitVector() return setmetatable({ Storage = ImVector() }, MT.ImBitVector) end
function MT.ImBitVector:Create(sz) self.Storage:resize(bitRShift(sz + 31, 5)); for i = 1, self.Storage.Size do self.Storage.Data[i] = 0 end end
function MT.ImBitVector:Clear() self.Storage:clear() end
--- @param n int # 1-based
function MT.ImBitVector:TestBit(n) IM_ASSERT(n <= bitLShift(self.Storage.Size, 5)); return IM_BITARRAY_TESTBIT(self.Storage.Data, n) end
function MT.ImBitVector:SetBit(n) IM_ASSERT(n <= bitLShift(self.Storage.Size, 5)); ImBitArraySetBit(self.Storage.Data, n) end
function MT.ImBitVector:ClearBit(n) IM_ASSERT(n <= bitLShift(self.Storage.Size, 5)); ImBitArrayClearBit(self.Storage.Data, n) end

-- Stateful path API, add points then finish with PathFillConvex() or PathStroke()
-- - Important: filled shapes must always use clockwise winding order! The anti-aliasing fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
--   so e.g. 'PathArcTo(center, radius, PI * -0.5, PI)' is ok, whereas 'PathArcTo(center, radius, PI, PI * -0.5)' won't have correct anti-aliasing when followed by PathFillConvex().
function MT.ImDrawList:PathClear() self._Path.Size = 0 end

--- @param pos ImVec2
@native
function MT.ImDrawList:PathLineTo(pos)
    -- [Luau] inline self._Path:push_back(pos) (ImVec2_TCopy into the preallocated slot)
    local path = self._Path
    local n = path.Size + 1
    if n > path.Capacity then path:push_back(pos) return end
    local dest = path.Data[n]
    dest.x = pos.x; dest.y = pos.y
    path.Size = n
end

function MT.ImDrawList:PathLineToMergeDuplicate(pos)
    local path_size = self._Path.Size
    if path_size == 0 or self._Path.Data[path_size].x ~= pos.x or self._Path.Data[path_size].y ~= pos.y then
        self._Path:push_back(pos)
    end
end

--- @param col    ImU32
--- @param flags? ImDrawFlags
@native
function MT.ImDrawList:PathFillConvex(col, flags)
    self:AddConvexPolyFilled(self._Path.Data, self._Path.Size, col, flags)
    self._Path.Size = 0
end

--- @param col        ImU32
--- @param thickness? float
--- @param flags?     ImDrawFlags
function MT.ImDrawList:PathStroke(col, thickness, flags)
    if not thickness then thickness = 1.0 end
    if not flags     then flags     = 0   end

    self:_AddPolyline(self._Path.Data, self._Path.Size, col, thickness, flags, FLT_MAX)
    self._Path.Size = 0
end

-- General polygon
-- - Only simple polygons are supported by filling functions (no self-intersections, no holes).
-- - Concave polygon fill is more expensive than convex one: it has O(N^2) complexity. Provided as a convenience for the user but not used by the main library.
--- @param points     ImVec2[] # 1-based
--- @param num_points int
--- @param col        ImU32
--- @param thickness  float
--- @param flags?     ImDrawFlags
function MT.ImDrawList:AddPolyline(points, num_points, col, thickness, flags)
    if not flags then flags = 0 end
    self:_AddPolyline(points, num_points, col, thickness, flags, FLT_MAX)
end

--- @param col ImU32
function ImGui.SetNextItemColorMarker(col)
    local g = GImGui
    g.NextItemData.HasFlags = bitOr(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasColorMarker)
    g.NextItemData.ColorMarker = col
end

-------------------------------------------------------------------------------
-- [SECTION] ImDrawList support
-------------------------------------------------------------------------------

-- Data shared between all ImDrawList instances
-- Conceptually this could have been called e.g. ImDrawListSharedContext
-- Typically one ImGui context would create and maintain one of this.
-- You may want to create your own instance of you try to ImDrawList completely without ImGui. In that case, watch out for future changes to this structure.
--- @class ImDrawListSharedData
--- @field TexUvWhitePixel       ImVec2 # UV of white pixel in the atlas (== FontAtlas->TexUvWhitePixel)
--- @field TexUvLines            ImVec4[] # 0-based. UV of anti-aliased lines in the atlas (== FontAtlas->Builder->TexUvLines)
--- @field TexUvCorners          ImVec4[] # 0-based. UV of rounded corner (== FontAtlas->Builder->TexUvCorners)
--- @field FontAtlas             ImFontAtlas # Current font atlas
--- @field Font                  ImFont # Current font (used for simplified AddText overload)
--- @field FontSize              float # Current font size (used for simplified AddText overload)
--- @field FontScale             float # Current font scale (== FontSize / Font->FontSize)
--- @field CurveTessellationMaxError float # Tessellation tolerance when using PathBezierCurveTo()
--- @field CircleTessellationMaxError float # Number of circle segments to use per pixel of radius for AddCircle() etc
--- @field InitialDrawFlags      ImDrawFlags # Initial flags at the beginning of the frame (it is possible to alter flags on a per-drawlist basis afterwards)
--- @field ClipRectFullscreen?   ImVec4 # Value for PushClipRectFullscreen()
--- @field TempBuffer            ImVector<ImVec2> # Temporary write buffer
--- @field DrawLists             ImVector<ImDrawList> # All draw lists associated to this ImDrawListSharedData
--- @field Context?              ImGuiContext # [OPTIONAL] Link to Dear ImGui context. 99% of ImDrawList/ImFontAtlas can function without an ImGui context, but this facilitate handling one legacy edge case.
--- @field ArcFastVtx            table<ImVec2>        # 1-based table. Sample points on the quarter of the circle.
--- @field ArcFastRadiusCutoff   float # Cutoff radius after which arc drawing will fallback to slower PathArcTo()
--- @field CircleSegmentCounts   table<int>           # 1-based table. Precomputed segment count for given radius before we calculate it dynamically (to avoid calculation overhead)
MT.ImDrawListSharedData = {}
MT.ImDrawListSharedData.__index = MT.ImDrawListSharedData

--- @return ImDrawListSharedData
--- @nodiscard
function ImDrawListSharedData()
    local this = setmetatable({
        TexUvWhitePixel = nil, -- UV of white pixel in the atlas (== FontAtlas->TexUvWhitePixel)
        TexUvLines      = nil, -- UV of anti-aliased lines in the atlas (== FontAtlas->Builder->TexUvLines)
        TexUvCorners    = nil, -- UV of rounded corner (== FontAtlas->Builder->TexUvCorners)
        FontAtlas       = nil, -- Current font atlas

        Font      = nil, -- Current font (used for simplified AddText overload)
        FontSize  = 0,   -- Current font size (used for simplified AddText overload)
        FontScale = 0,   -- Current font scale (== FontSize / Font->FontSize)

        CurveTessellationMaxError  = 0, -- Tessellation tolerance when using PathBezierCurveTo()
        CircleTessellationMaxError = 0, -- Number of circle segments to use per pixel of radius for AddCircle() etc
        InitialDrawFlags      = 0, -- Initial flags at the beginning of the frame (it is possible to alter flags on a per-drawlist basis afterwards)
        ClipRectFullscreen    = nil, -- Value for PushClipRectFullscreen()
        TempBuffer            = ImVector(ImVec2), -- Temporary write buffer
        DrawLists             = ImVector(), -- All draw lists associated to this ImDrawListSharedData

        -- Lookup tables
        ArcFastVtx          = {},  -- Sample points on the quarter of the circle.
        ArcFastRadiusCutoff = nil, -- Cutoff radius after which arc drawing will fallback to slower PathArcTo()
        CircleSegmentCounts = {},  -- Precomputed segment count for given radius before we calculate it dynamically (to avoid calculation overhead)

        Context = nil -- [OPTIONAL] Link to Dear ImGui context. 99% of ImDrawList/ImFontAtlas can function without an ImGui context, but this facilitate handling one legacy edge case.
    }, MT.ImDrawListSharedData)

    for i = 1, IM_DRAWLIST_ARCFAST_TABLE_SIZE do
        local a = ((i - 1) * 2 * IM_PI) / IM_DRAWLIST_ARCFAST_TABLE_SIZE
        this.ArcFastVtx[i] = ImVec2(ImCos(a), ImSin(a))
    end

    return this
end

-- Internal storage for incrementally packing and building a ImFontAtlas
--- @class ImFontAtlasBuilder
--- @field PackContext              stbrp_context
--- @field PackNodes                ImVector<stbrp_node>
--- @field Rects                    ImVector<ImTextureRect>
--- @field RectsIndex               ImVector<ImFontAtlasRectEntry>
--- @field TempBuffer               ImVector<char>
--- @field RectsIndexFreeListStart  int
--- @field RectsPackedCount         int
--- @field RectsPackedSurface       int
--- @field RectsDiscardedCount      int
--- @field RectsDiscardedSurface    int
--- @field FrameCount               int
--- @field MaxRectSize              ImVec2
--- @field MaxRectBounds            ImVec2
--- @field LockDisableResize        bool
--- @field PreloadedAllGlyphsRanges bool
--- @field BakedPool                ImVector<ImFontBaked>
--- @field BakedMap                 table<ImGuiID, any>            # LUA: No ImGuiStorage
--- @field BakedDiscardedCount      int
--- @field PackIdMouseCursors       ImFontAtlasRectId
--- @field PackIdLinesTexData       ImFontAtlasRectId
--- @field PackIdLineFractTexData   ImFontAtlasRectId
--- @field PackIdCornersTexData     ImFontAtlasRectId
--- @field TexUvLines               ImVec4[] # 0-based. UVs for baked anti-aliased lines (u0, u1, v, 1/thickness)
--- @field TexUvCorners             ImVec4[] # 0-based. UVs for baked anti-aliased corners (0= fill, 1> stroke thickness)
MT.ImFontAtlasBuilder = {}
MT.ImFontAtlasBuilder.__index = MT.ImFontAtlasBuilder

--- @return ImFontAtlasBuilder
function ImFontAtlasBuilder()
    --- @type ImFontAtlasBuilder
    local this = setmetatable({}, MT.ImFontAtlasBuilder)

    this.PackContext              = nil -- struct stbrp_context_opaque { char data[80]; }; -- Actually 'stbrp_context' but we don't want to define this in the header file.
    this.PackNodes                = ImVector()
    this.Rects                    = ImVector()
    this.RectsIndex               = ImVector() -- ImFontAtlasRectId -> index into Rects[]
    this.TempBuffer               = ImVector() -- Misc scratch buffer
    this.RectsIndexFreeListStart  = -1 -- First unused entry
    this.RectsPackedCount         = 0 -- Number of packed rectangles.
    this.RectsPackedSurface       = 0 -- Number of packed pixels. Used when compacting to heuristically find the ideal texture size.
    this.RectsDiscardedCount      = 0
    this.RectsDiscardedSurface    = 0
    this.FrameCount               = -1 -- Current frame count
    this.MaxRectSize              = ImVec2() -- Largest rectangle to pack (de-facto used as a "minimum texture size")
    this.MaxRectBounds            = ImVec2() -- Bottom-right most used pixels
    this.LockDisableResize        = false -- Disable resizing texture
    this.PreloadedAllGlyphsRanges = false -- Set when missing ImGuiBackendFlags.RendererHasTextures features forces atlas to preload everything.

    -- Cache of all ImFontBaked
    this.BakedPool           = ImVector() -- ImStableVector<ImFontBaked,32>
    this.BakedMap            = {} -- BakedId --> ImFontBaked
    this.BakedDiscardedCount = 0

    -- Custom rectangle identifiers
    this.PackIdMouseCursors = -1 -- White pixel + mouse cursors. Also happen to be fallback in case of packing failure.
    this.PackIdLinesTexData = -1
    this.PackIdLineFractTexData = -1
    this.PackIdCornersTexData = -1

    -- Cached UV coordinates
    this.TexUvLines   = {} -- [IM_DRAWLIST_TEX_LINES_WIDTH_MAX + 1 + IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH_COUNT] UVs for baked anti-aliased lines (u0, u1, v, 1/thickness) -- 0-based
    this.TexUvCorners = {} -- [IM_DRAWLIST_TEX_CORNERS_ROUNDING_MAX * IM_DRAWLIST_TEX_CORNERS_THICKNESS_MAX] UVs for baked anti-aliased corners (0= fill, 1> stroke thickness) -- 0-based
    for n = 0, IM_DRAWLIST_TEX_LINES_WIDTH_MAX + IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH_COUNT do this.TexUvLines[n] = ImVec4() end
    for n = 0, IM_DRAWLIST_TEX_CORNERS_ROUNDING_MAX * IM_DRAWLIST_TEX_CORNERS_THICKNESS_MAX - 1 do this.TexUvCorners[n] = ImVec4() end

    return this
end

--- @class ImFontStackData
--- @field Font                  ImFont
--- @field FontSizeBeforeScaling float # ~~ style.FontSizeBase
--- @field FontSizeAfterScaling  float # ~~ g.FontSize

--- @return ImFontStackData
--- @param font                     ImFont
--- @param font_size_before_scaling float
--- @param font_size_after_scaling  float
--- @nodiscard
function ImFontStackData(font, font_size_before_scaling, font_size_after_scaling)
    return {
        Font                  = font,
        FontSizeBeforeScaling = font_size_before_scaling, -- ~~ style.FontSizeBase
        FontSizeAfterScaling  = font_size_after_scaling   -- ~~ g.FontSize
    }
end

-------------------------------------------------------------------------------
-- [SECTION] Style support
-------------------------------------------------------------------------------

--- `GetVarPtr()` is currently only used on `g.Style` in Dear ImGui, and we don't have pointers!
--- @class ImGuiStyleVarInfo
--- @field Count    ImU32         # 1+
--- @field DataType ImGuiDataType
--- @field Key      string        # key in parent structure. Note that the cpp Dear ImGui uses `ImU32 Offset`!

--- @param count     ImU32
--- @param data_type ImGuiDataType
--- @param key       string
--- @return ImGuiStyleVarInfo
--- @nodiscard
MT.ImGuiStyleVarInfo = {}
MT.ImGuiStyleVarInfo.__index = MT.ImGuiStyleVarInfo
function ImGuiStyleVarInfo(count, data_type, key)
    return setmetatable({ Count = count, DataType = data_type, Key = key }, MT.ImGuiStyleVarInfo)
end
-- [Luau] no pointers: returns the field value (number, or the live ImVec2 table) of 'parent' (e.g. ImGuiStyle)
function MT.ImGuiStyleVarInfo:GetVarPtr(parent) return parent[self.Key] end

-- Stacked style modifier, backup of modified data so we can restore it. Data type inferred from the variable.
--- @class ImGuiStyleMod
--- @field VarIdx       ImGuiStyleVar
--- @field BackupVal    table

--- @param idx ImGuiStyleVar
--- @param v   int|float|ImVec2
function ImGuiStyleMod(idx, v)
    local this = { VarIdx = idx, BackupVal = {nil, nil} }
    --- @cast this ImGuiStyleMod

    if type(v) == "number" then
        this.BackupVal[1] = v
    else -- ImVec2
        this.BackupVal[1] = v.x; this.BackupVal[2] = v.y
    end

    return this
end

-------------------------------------------------------------------------------
-- [SECTION] Data types support
-------------------------------------------------------------------------------

-- Type information associated to one ImGuiDataType. Retrieve with DataTypeGetInfo().
--- @class ImGuiDataTypeInfo
--- @field Size     size_t # Size in bytes
--- @field Name     string # Short descriptive name for the type, for debugging
--- @field PrintFmt string # Default printf format for the type
--- @field ScanFmt  string # Default scanf format for the type

-- Status storage for the last submitted item
--- @class ImGuiLastItemData
--- @field ID          ImGuiID
--- @field ItemFlags   ImGuiItemFlags       # See ImGuiItemFlags (called 'InFlags' before v1.91.4).
--- @field StatusFlags ImGuiItemStatusFlags # See ImGuiItemStatusFlags
--- @field Rect        ImRect               # Full rectangle
--- @field NavRect     ImRect               # Navigation scoring rectangle (not displayed)
--- @field DisplayRect ImRect               # Display rectangle. ONLY VALID IF (StatusFlags & ImGuiItemStatusFlags.HasDisplayRect) is set.
--- @field ClipRect    ImRect               # Clip rectangle at the time of submitting item. ONLY VALID IF (StatusFlags & ImGuiItemStatusFlags.HasClipRect) is set..
--- @field Shortcut    ImGuiKeyChord        # Shortcut at the time of submitting item. ONLY VALID IF (StatusFlags & ImGuiItemStatusFlags.HasShortcut) is set..

--- @return ImGuiLastItemData
--- @nodiscard
function ImGuiLastItemData()
    return {
        ID          = 0,
        ItemFlags   = 0,        -- See ImGuiItemFlags (called 'InFlags' before v1.91.4).
        StatusFlags = 0,        -- See ImGuiItemStatusFlags
        Rect        = ImRect(), -- Full rectangle
        NavRect     = ImRect(), -- Navigation scoring rectangle (not displayed)

        -- Rarely used fields are not explicitly cleared, only valid when the corresponding ImGuiItemStatusFlags are set.
        DisplayRect = ImRect(), -- Display rectangle. ONLY VALID IF (StatusFlags & ImGuiItemStatusFlags.HasDisplayRect) is set.
        ClipRect    = ImRect(), -- Clip rectangle at the time of submitting item. ONLY VALID IF (StatusFlags & ImGuiItemStatusFlags.HasClipRect) is set..
        Shortcut    = 0         -- Shortcut at the time of submitting item. ONLY VALID IF (StatusFlags & ImGuiItemStatusFlags.HasShortcut) is set..
    }
end

--- @param dest ImGuiLastItemData
--- @param src  ImGuiLastItemData
function ImGuiLastItemData_Copy(dest, src)
    dest.ID = src.ID
    dest.ItemFlags = src.ItemFlags
    dest.StatusFlags = src.StatusFlags
    ImRect_Copy(dest.Rect, src.Rect)
    ImRect_Copy(dest.NavRect, src.NavRect)
    ImRect_Copy(dest.DisplayRect, src.DisplayRect)
    ImRect_Copy(dest.ClipRect, src.ClipRect)
    dest.Shortcut = src.Shortcut
end

-- Store data emitted by TreeNode() for usage by TreePop()
-- - To implement ImGuiTreeNodeFlags.NavLeftJumpsToParent: store the minimum amount of data
--   which we can't infer in TreePop(), to perform the equivalent of NavApplyItemToResult().
--   Only stored when the node is a potential candidate for landing on a Left arrow jump.
--- @class ImGuiTreeNodeStackData
--- @field ID                   ImGuiID
--- @field TreeFlags            ImGuiTreeNodeFlags
--- @field ItemFlags            ImGuiItemFlags
--- @field NavRect              ImRect
--- @field DrawLinesX1          float
--- @field DrawLinesToNodesY2   float
--- @field DrawLinesTableColumn ImGuiTableColumnIdx

--- @return ImGuiTreeNodeStackData
--- @nodiscard
local function ImGuiTreeNodeStackData()
    return {
        ID                   = nil,
        TreeFlags            = nil,
        ItemFlags            = nil,      -- Used for nav landing
        NavRect              = ImRect(), -- Used for nav landing
        DrawLinesX1          = nil,
        DrawLinesToNodesY2   = nil,
        DrawLinesTableColumn = nil
    }
end

-- Storage for SetNextItem** functions
--- @class ImGuiNextItemData
--- @field HasFlags          ImGuiNextItemDataFlags
--- @field ItemFlagsSet      ImGuiItemFlags
--- @field FocusScopeId      ImGuiID
--- @field SelectionUserData any
--- @field Width             number
--- @field Shortcut          ImGuiKeyChord
--- @field ShortcutFlags     ImGuiInputFlags
--- @field OpenVal           boolean
--- @field OpenCond          ImGuiCond
--- @field RefVal            any
--- @field StorageId         ImGuiID
--- @field ColorMarker       ImU32
MT.ImGuiNextItemData = {}
MT.ImGuiNextItemData.__index = MT.ImGuiNextItemData

-- Also cleared manually by ItemAdd()!
function MT.ImGuiNextItemData:ClearFlags()
    self.HasFlags = ImGuiNextItemDataFlags.None
    self.ItemFlagsSet = ImGuiItemFlags.None
end

--- @return ImGuiNextItemData
--- @nodiscard
function ImGuiNextItemData()
    return setmetatable({
        HasFlags          = 0, -- Called HasFlags instead of Flags to avoid mistaking this
        ItemFlagsSet      = 0, -- Currently only tested/used for ImGuiItemFlags.AllowOverlap and ImGuiItemFlags.HasSelectionUserData.

        -- Members below are NOT cleared by ItemAdd() meaning they are still valid during e.g. NavProcessItem(). Always rely on HasFlags.
        FocusScopeId      = 0,     -- Set by SetNextItemSelectionUserData()
        SelectionUserData = -1,    -- Set by SetNextItemSelectionUserData() (note that nil/0 is a valid value, we use -1 == ImGuiSelectionUserData_Invalid to mark invalid values)
        Width             = 0.0,   -- Set by SetNextItemWidth()
        Shortcut          = 0,     -- Set by SetNextItemShortcut()
        ShortcutFlags     = 0,     -- Set by SetNextItemShortcut()
        OpenVal           = false, -- Set by SetNextItemOpen()
        OpenCond          = 0,     -- Set by SetNextItemOpen()
        RefVal            = 0,     -- Not exposed yet, for ImGuiInputTextFlags.ParseEmptyAsRefVal
        StorageId         = 0,     -- Set by SetNextItemStorageID()
        ColorMarker       = 0      -- Set by SetNextItemColorMarker(). Not exposed yet, supported by DragScalar,SliderScalar and for ImGuiSliderFlags.ColorMarkers.
    }, MT.ImGuiNextItemData)
end

-- Storage for SetNexWindow** functions
--- @class ImGuiNextWindowData
--- @field HasFlags             ImGuiNextWindowDataFlags
--- @field PosCond              ImGuiCond
--- @field SizeCond             ImGuiCond
--- @field CollapsedCond        ImGuiCond
--- @field PosVal               ImVec2?
--- @field PosPivotVal          ImVec2?
--- @field SizeVal              ImVec2?
--- @field ContentSizeVal       ImVec2?
--- @field ScrollVal            ImVec2?
--- @field WindowFlags          ImGuiWindowFlags?
--- @field ChildFlags           ImGuiChildFlags?
--- @field CollapsedVal         boolean?
--- @field SizeConstraintRect   ImRect?
--- @field SizeCallback         function?
--- @field SizeCallbackUserData any
--- @field BgAlphaVal           number?
--- @field MenuBarOffsetMinVal  ImVec2?
--- @field RefreshFlagsVal      int?
MT.ImGuiNextWindowData = {}
MT.ImGuiNextWindowData.__index = MT.ImGuiNextWindowData

function MT.ImGuiNextWindowData:ClearFlags()
    self.HasFlags = ImGuiNextWindowDataFlags.None
end

--- @return ImGuiNextWindowData
--- @nodiscard
function ImGuiNextWindowData()
    return setmetatable({
        HasFlags = 0,

        -- Members below are NOT cleared. Always rely on HasFlags.
        PosCond              = 0,
        SizeCond             = 0,
        CollapsedCond        = 0,
        PosVal               = ImVec2(),
        PosPivotVal          = ImVec2(),
        SizeVal              = ImVec2(),
        ContentSizeVal       = ImVec2(),
        ScrollVal            = ImVec2(),
        WindowFlags          = nil,
        ChildFlags           = nil,
        WindowFlagsSet       = 0, -- Flags to set. Use SetNextWindowFlags()!
        WindowFlagsClear     = 0,
        ChildFlagsSet        = 0, -- Flags to set. Use SetNextWindowChildFlags().
        ChildFlagsClear      = 0,
        ViewportId           = 0,
        DockId               = 0,
        DockCond             = 0,
        PosUndock            = false,
        WindowClass          = nil,
        CollapsedVal         = nil,
        SizeConstraintRect   = nil,
        SizeCallback         = nil,
        SizeCallbackUserData = nil,
        BgAlphaVal           = nil, -- Override background alpha
        MenuBarOffsetMinVal  = ImVec2(), -- (Always on) This is not exposed publicly, so we don't clear it and it doesn't have a corresponding flag (could we? for consistency?)
        RefreshFlagsVal      = nil,
        CacheKeySet          = false, -- [Port] SetNextWindowCached()
        CacheKeyVal          = nil
    }, MT.ImGuiNextWindowData)
end

--- @enum ImGuiWindowBgClickFlags
ImGuiWindowBgClickFlags = {
    None = 0,
    Move = bitLShift(1, 0), -- Click on bg/void + drag to move window. Cleared by default when using io.ConfigWindowsMoveFromTitleBarOnly.
}

--- @enum ImGuiNextWindowDataFlags
ImGuiNextWindowDataFlags = {
    None              = 0,
    HasPos            = bitLShift(1, 0),
    HasSize           = bitLShift(1, 1),
    HasContentSize    = bitLShift(1, 2),
    HasCollapsed      = bitLShift(1, 3),
    HasSizeConstraint = bitLShift(1, 4),
    HasFocus          = bitLShift(1, 5),
    HasBgAlpha        = bitLShift(1, 6),
    HasScroll         = bitLShift(1, 7),
    HasWindowFlags    = bitLShift(1, 8),
    HasChildFlags     = bitLShift(1, 9),
    HasRefreshPolicy  = bitLShift(1, 10),
    HasViewport       = bitLShift(1, 11),
    HasDock           = bitLShift(1, 12),
    HasWindowClass    = bitLShift(1, 13)
}

-- FIXME: this is in development, not exposed/functional as a generic feature yet.
-- Horizontal/Vertical enums are fixed to 0/1 so they may be used to index ImVec2
--- @enum ImGuiLayoutType
ImGuiLayoutType =
{
    Horizontal = 0,
    Vertical   = 1
}

--- @enum ImGuiLogFlags
ImGuiLogFlags =
{
    None = 0,

    OutputTTY       = bitLShift(1, 0),
    OutputFile      = bitLShift(1, 1),
    OutputBuffer    = bitLShift(1, 2),
    OutputClipboard = bitLShift(1, 3),
}
ImGuiLogFlags.OutputMask_ = bitOr(ImGuiLogFlags.OutputTTY, ImGuiLogFlags.OutputFile, ImGuiLogFlags.OutputBuffer, ImGuiLogFlags.OutputClipboard)

-- Flags for internal's BeginColumns(). This is an obsolete API. Prefer using BeginTable() nowadays!
--- @enum ImGuiOldColumnFlags
ImGuiOldColumnFlags =
{
    None                   = 0,
    NoBorder               = bitLShift(1, 0), -- Disable column dividers
    NoResize               = bitLShift(1, 1), -- Disable resizing columns when clicking on the dividers
    NoPreserveWidths       = bitLShift(1, 2), -- Disable column width preservation when adjusting columns
    NoForceWithinWindow    = bitLShift(1, 3), -- Disable forcing columns to fit within window
    GrowParentContentsSize = bitLShift(1, 4), -- Restore pre-1.51 behavior of extending the parent window contents size but _without affecting the columns width at all_. Will eventually remove.
}

--- @enum ImGuiSeparatorFlags
ImGuiSeparatorFlags =
{
    None           = 0,
    Horizontal     = bitLShift(1, 0), -- Axis default to current layout type, so generally Horizontal unless e.g. in a menu bar
    Vertical       = bitLShift(1, 1),
    SpanAllColumns = bitLShift(1, 2)  -- Make separator cover all columns of a legacy Columns() set.
}

--- @class ImGuiStyle
MT.ImGuiStyle = {}
MT.ImGuiStyle.__index = MT.ImGuiStyle

--- @return ImGuiStyle
--- @nodiscard
function ImGuiStyle()
    --- @type ImGuiStyle
    local this = {
        FontSizeBase  = 0.0, -- Will default to io.Fonts.Fonts[0] on first frame.
        FontScaleMain = 1.0, -- Main scale factor. May be set by application once, or exposed to end-user.
        FontScaleDpi  = 1.0, -- Additional scale factor from viewport/monitor contents scale. When io.ConfigDpiScaleFonts is enabled, this is automatically overwritten when changing monitor DPI.

        Alpha = 1.0, -- Global alpha applies to everything in Dear ImGui.
        DisabledAlpha = 0.60, -- Additional alpha multiplier applied by BeginDisabled(). Multiply over current value of Alpha.

        FramePadding = ImVec2(4, 3), -- Padding within a framed rectangle (used by most widgets)
        FrameRounding = 0.0, -- Radius of frame corners rounding. Set to 0.0 to have rectangular frames (used by most widgets).
        FrameBorderSize = 0.0, -- Thickness of border around frames. Generally set to 0.0 or 1.0. Other values not well tested.
        WindowPadding = ImVec2(8, 8), -- Padding within a window

        TouchExtraPadding = ImVec2(0, 0), -- Expand reactive bounding box for touch-based system where touch position is not accurate enough. Unfortunately we don't sort widgets so priority on overlap will always be given to the first widget. So don't grow this too much!
        IndentSpacing = 21.0, -- Horizontal spacing when e.g. entering a tree node. Generally == (FontSize + FramePadding.x*2).

        WindowRounding = 0, -- Radius of window corners rounding. Set to 0.0 to have rectangular windows. Large values tend to lead to variety of artifacts and are not recommended.
        WindowBorderSize = 1, -- Thickness of border around windows. Generally set to 0.0 or 1.0. Other values not well tested.

        ScrollbarSize     = 14.0, -- Width of the vertical scrollbar, Height of the horizontal scrollbar
        ScrollbarRounding = 9.0, -- Radius of grab corners rounding for scrollbar
        ScrollbarPadding  = 2.0, -- Padding of scrollbar grab within its frame (same for both axes)
        GrabMinSize = 12.0, -- Minimum width/height of a grab box for slider/scrollbar
        GrabRounding = 0.0, -- Radius of grabs corners rounding. Set to 0.0 to have rectangular slider grabs.
        ImageRounding = 0.0, -- Rounding of Image() calls.
        ImageBorderSize = 0.0, -- Thickness of border around Image() calls.

        WindowBorderHoverPadding = 4.0, -- Hit-testing extent outside/inside resizing border. Also extend determination of hovered window. Generally meaningfully larger than WindowBorderSize to make it easy to reach borders.

        TreeLinesFlags = ImGuiTreeNodeFlags.DrawLinesNone,
        TreeLinesSize  = 1.0, -- Thickness of outlines when using ImGuiTreeNodeFlags.DrawLines.
        TreeLinesRounding = 0.0, -- Radius of lines connecting child nodes to the vertical line.
        MenuItemRounding = 0.0, -- Radius of MenuItem, BeginMenu rounding.
        SelectableRounding = 0.0, -- Radius of selectable rounding. MODIFYING THIS IS DISCOURAGED. CONTIGUOUS SELECTIONS WILL NOT LOOK RIGHT. (#7589)

        ColorMarkerSize = 3.0, -- Size of R/G/B/A color markers for ColorEdit4() and for Drags/Sliders when using ImGuiSliderFlags.ColorMarkers.
        ColorButtonPosition = ImGuiDir.Right, -- Side of the color button in the ColorEdit4 widget (left/right). Defaults to ImGuiDir.Right.

        InputTextCursorSize = 1.0, -- Thickness of cursor/caret in InputText().
        SeparatorSize           = 1.0, -- Thickness of border in Separator().
        SeparatorTextBorderSize = 3.0, -- Thickness of border in SeparatorText().
        SeparatorTextAlign      = ImVec2(0.0, 0.5), -- Alignment of text within the separator. Defaults to (0.0, 0.5) (left aligned, center).
        SeparatorTextPadding    = ImVec2(20.0, 3.0), -- Horizontal offset of text from each edge of the separator + spacing on other axis. Generally small values. .y is recommended to be == FramePadding.y.

        DisplaySafeAreaPadding = ImVec2(3, 3), -- If you cannot see the edge of your screen (e.g. on a TV) increase the safe area padding. Covers popups/tooltips as well regular windows.
        DisplayWindowPadding = ImVec2(19, 19), -- Window position are clamped to be visible within the display area or monitors by at least this amount. Only applies to regular windows.

        -- Rendering & Tessellation
        AntiAliasedLines            = true, -- Enable anti-aliased lines/borders. Used at the beginning of the frame to set ImDrawFlags_AALines in all draw-lists.
        AntiAliasedLineEnds         = false, -- Enable anti-aliased lines/borders ends. Nicer for thick lines but more expensive. Used at the beginning of the frame to set ImDrawFlags_AALineEnds in all draw-lists.
        AntiAliasedFill             = true, -- Enable anti-aliased edges around filled shapes (rounded rectangles, circles, etc.). Used at the beginning of the frame to set ImDrawFlags_AAFill in all draw-lists.
        CurveTessellationMaxError   = 1.12, -- Maximum error (in pixels) when using PathBezierCurveTo() without a specific number of segments. Decrease for highly tessellated curves (higher quality, more polygons), increase to reduce quality.
        CircleTessellationMaxError = 0.30, -- Maximum error (in pixels) allowed when using AddCircle()/AddCircleFilled() or drawing rounded corner rectangles with no explicit segment count specified. Decrease for higher quality but more geometry.

        -- Behaviors
        HoverStationaryDelay = 0.15, -- Delay for IsItemHovered(ImGuiHoveredFlags.Stationary). Time required to consider mouse stationary.
        HoverDelayShort = 0.15, -- Delay for IsItemHovered(ImGuiHoveredFlags.DelayShort). Usually used along with HoverStationaryDelay.
        HoverDelayNormal = 0.40, -- Delay for IsItemHovered(ImGuiHoveredFlags.DelayNormal). "

        Colors = {},

        ButtonTextAlign = ImVec2(0.5, 0.5), -- Alignment of button text when button is larger than text.
        SelectableTextAlign = ImVec2(0.0, 0.0), -- Alignment of selectable text. Defaults to (0.0, 0.0) (top-left aligned). It's generally important to keep this left-aligned if you want to lay multiple items on a same line.

        WindowMinSize = ImVec2(32, 32), -- Minimum window size
        WindowTitleAlign = ImVec2(0.0, 0.5), -- Alignment for title bar text
        WindowMenuButtonPosition = ImGuiDir.Left, -- Position of the collapsing/docking button in the title bar (left/right). Defaults to ImGuiDir.Left.
        ChildRounding = 0.0, -- Radius of child window corners rounding. Set to 0.0 to have rectangular child windows
        ChildBorderSize = 1.0, -- Thickness of border around child windows. Generally set to 0.0 or 1.0. Other values not well tested.
        PopupRounding = 0.0, -- Radius of popup window corners rounding. Set to 0.0 to have rectangular child windows
        PopupBorderSize = 1.0, -- Thickness of border around popup or tooltip windows. Generally set to 0.0 or 1.0. Other values not well tested.

        DockingSeparatorSize = 2.0, -- Thickness of resizing border between docked windows
        DockingNodeHasCloseButton = true, -- Docking nodes have their own CloseButton() to close all docked windows.
        MouseCursorScale = 1.0, -- Scale software rendered mouse cursor (when io.MouseDrawCursor is enabled). May be removed later.

        ItemSpacing = ImVec2(8, 4), -- Horizontal and vertical spacing between widgets/lines
        ItemInnerSpacing = ImVec2(4, 4), -- Horizontal and vertical spacing between within elements of a composed widget (e.g. a slider and its label)
        CellPadding = ImVec2(4, 2), -- Padding within a table cell. Cellpadding.x is locked for entire table. CellPadding.y may be altered between different rows.

        ColumnsMinSpacing = 6.0, -- Minimum horizontal spacing between two columns. Preferably > (FramePadding.x + 1).

        LogSliderDeadzone = 4.0, -- The size in pixels of the dead-zone around zero on logarithmic sliders that cross zero.

        TabRounding = 5.0, -- Radius of upper corners of a tab. Set to 0.0 to have rectangular tabs.
        TabBorderSize = 0.0, -- Thickness of border around tabs.
        TabMinWidthBase = 1.0, -- Minimum tab width, to make tabs larger than their contents. TabBar buttons are not affected.
        TabMinWidthShrink = 80.0, -- Minimum tab width after shrinking, when using ImGuiTabBarFlags.FittingPolicyMixed policy. FLT_MAX: never shrink, will behave like ImGuiTabBarFlags.FittingPolicyScroll.
        TabCloseButtonMinWidthSelected = -1.0, -- -1: always visible. 0.0: visible when hovered. >0.0: visible when hovered if minimum width.
        TabCloseButtonMinWidthUnselected = 0.0, -- -1: always visible. 0.0: visible when hovered. >0.0: visible when hovered if minimum width. FLT_MAX: never show close button when unselected.
        TabBarBorderSize = 1.0, -- Thickness of tab-bar separator, which takes on the tab active color to denote focus.
        TabBarOverlineSize = 1.0, -- Thickness of tab-bar overline, which highlights the selected tab-bar.
        TableAngledHeadersAngle = 35.0 * (IM_PI / 180.0), -- Angle of angled headers (supported values range from -50 degrees to +50 degrees).
        TableAngledHeadersTextAlign = ImVec2(0.5, 0.0), -- Alignment of angled headers within the cell

        DragDropTargetRounding = 0.0, -- Radius of the drag and drop target frame.
        DragDropTargetBorderSize = 2.0, -- Thickness of the drag and drop target border.
        DragDropTargetPadding = 3.0, -- Size to expand the drag and drop target from actual target item size.

        HoverFlagsForTooltipMouse = bitOr(ImGuiHoveredFlags.Stationary, ImGuiHoveredFlags.DelayShort, ImGuiHoveredFlags.AllowWhenDisabled), -- Default flags when using IsItemHovered(ImGuiHoveredFlags.ForTooltip) or BeginItemTooltip()/SetItemTooltip() while using mouse.
        HoverFlagsForTooltipNav = bitOr(ImGuiHoveredFlags.NoSharedDelay, ImGuiHoveredFlags.DelayNormal, ImGuiHoveredFlags.AllowWhenDisabled), -- Default flags when using IsItemHovered(ImGuiHoveredFlags.ForTooltip) or BeginItemTooltip()/SetItemTooltip() while using keyboard/gamepad.

        -- [Internal]
        _MainScale = 1.0,
        _NextFrameFontSizeBase = 0.0,

        -- Obsolete names (#ifndef IMGUI_DISABLE_OBSOLETE_FUNCTIONS)
        CurveTessellationTol        = 0.0, -- [OBSOLETE] Old CurveTessellationTol = CurveTessellationMaxError*CurveTessellationMaxError.
        AntiAliasedLinesUseTex      = true, -- [OBSOLETE] Enable anti-aliased lines/borders using textures for legacy strokes. Require backend to render with bilinear filtering (NOT point/nearest filtering).
    }

    -- Default theme
    ImGui.StyleColorsDark(this)

    setmetatable(this, MT.ImGuiStyle)

    return this
end

-- Storage for each window pushed into the stack.
--- @class ImGuiWindowStackData

--- @return ImGuiWindowStackData
--- @nodiscard
function ImGuiWindowStackData()
    return {
        Window                              = nil,
        ParentLastItemDataBackup            = ImGuiLastItemData(),
        StackSizesInBegin                   = nil, -- Store size of various stacks for asserting
        DisabledOverrideReenable            = nil, -- Non-child window override disabled flag
        DisabledOverrideReenableAlphaBackup = nil,
        ParentLastComboPreviewRect          = ImRect(),
    }
end

-- Storage data for BeginComboPreview()/EndComboPreview()
--- @class ImGuiComboPreviewData
--- @field PreviewRect                  ImRect
--- @field BackupCursorPos              ImVec2
--- @field BackupCursorMaxPos           ImVec2
--- @field BackupCursorPosPrevLine      ImVec2
--- @field BackupPrevLineTextBaseOffset float
--- @field BackupLayout                 ImGuiLayoutType

--- @return ImGuiComboPreviewData
--- @nodiscard
local function ImGuiComboPreviewData()
    return {
        PreviewRect                  = ImRect(),
        BackupCursorPos              = ImVec2(),
        BackupCursorMaxPos           = ImVec2(),
        BackupCursorPosPrevLine      = ImVec2(),
        BackupPrevLineTextBaseOffset = 0.0,
        BackupLayout                 = 0,
        BackupWorkRectMaxX           = 0.0,
        BackupContentRectMaxX        = 0.0,
        WithinPreview                = false,
    }
end

--- @alias IMSTB_TEXTEDIT_STRING ImGuiInputTextState

--- @alias ImStbTexteditState STB_TexteditState

-- Internal state of the currently focused/edited text input box
-- For a given item ID, access with ImGui.GetInputTextState()
--- @class ImGuiInputTextState
--- @field Ctx                  ImGuiContext        # parent UI context (needs to be set explicitly by parent)
--- @field Stb                  ImStbTexteditState  # State for stb_textedit.lua
--- @field Flags                ImGuiInputTextFlags # copy of InputText() flags. may be used to check if e.g. ImGuiInputTextFlags.Password is set.
--- @field ID                   ImGuiID             # widget id owning the text state
--- @field TextLen              int                 # UTF-8 length of the string in TextA (in bytes)
--- @field TextSrc              ImStringBuffer      # == TextA.Data unless read-only, in which case == buf passed to InputText(). For _ReadOnly fields, pointer will be null outside the InputText() call
--- @field TextA                ImVector<char>      # main UTF8 buffer. TextA.Size is a buffer size! Should always be >= buf_size passed by user (and of course >= CurLenA + 1)
--- @field TextToRevertTo       ImVector<char>      # value to revert to when pressing Escape = backup of end-user buffer at the time of focus (in UTF-8, unaltered)
--- @field CallbackTextBackup   ImVector<char>      # temporary storage for callback to support automatic reconcile of undo-stack
--- @field BufCapacity          int                 # end-user buffer capacity (include zero terminator)
--- @field Scroll               ImVec2              # horizontal offset (managed manually) + vertical scrolling (pulled from child window's own Scroll.y)
--- @field LineCount            int                 # last line count (solely for debugging)
--- @field WrapWidth            float               # word-wrapping width
--- @field CursorAnim           float               # timer for cursor blink, reset on every user action so the cursor reappears immediately
--- @field CursorFollow         bool                # set when we want scrolling to follow the current cursor position (not always!)
--- @field CursorCenterY        bool                # set when we want scrolling to be centered over the cursor position (while resizing a word-wrapping field)
--- @field SelectedAllMouseLock bool                # after a double-click to select all, we ignore further mouse drags to update selection
--- @field EditedBefore         bool                # edited since activated
--- @field EditedThisFrame      bool                # edited this frame
MT.ImGuiInputTextState = {}
MT.ImGuiInputTextState.__index = MT.ImGuiInputTextState

local function ImGuiInputTextState()
    local this = {
        Ctx   = nil, -- parent UI context (needs to be set explicitly by parent).
        Stb   = STB_TexteditState(), -- FIXME: no global! -- State for stb_textedit.h
        Flags = 0, -- copy of InputText() flags. may be used to check if e.g. ImGuiInputTextFlags.Password is set.
        ID    = 0, -- widget id owning the text state

        TextLen            = 0,          -- UTF-8 length of the string in TextA (in bytes)
        TextSrc            = nil,        -- == TextA.Data unless read-only, in which case == buf passed to InputText(). For _ReadOnly fields, pointer will be null outside the InputText() call.
        TextA              = ImVector(), -- main UTF8 buffer. TextA.Size is a buffer size! Should always be >= buf_size passed by user (and of course >= CurLenA + 1).
        TextToRevertTo     = ImVector(), -- value to revert to when pressing Escape = backup of end-user buffer at the time of focus (in UTF-8, unaltered)
        CallbackTextBackup = ImVector(), -- temporary storage for callback to support automatic reconcile of undo-stack

        BufCapacity = 0,        -- end-user buffer capacity (include zero terminator)
        Scroll      = ImVec2(), -- horizontal offset (managed manually) + vertical scrolling (pulled from child window's own Scroll.y)
        LineCount   = 0,        -- last line count (solely for debugging)
        WrapWidth   = 0.0,      -- word-wrapping width

        CursorAnim    = 0.0,   -- timer for cursor blink, reset on every user action so the cursor reappears immediately
        CursorFollow  = false, -- set when we want scrolling to follow the current cursor position (not always!)
        CursorCenterY = false, -- set when we want scrolling to be centered over the cursor position (while resizing a word-wrapping field)
        SelectedAllMouseLock = false, -- after a double-click to select all, we ignore further mouse drags to update selection
        EditedBefore = false,    -- edited since activated
        EditedThisFrame = false, -- edited this frame
        ValidatedThisFrame = false, -- validated this frame (e.g. Enter pressed)
        WantReloadUserBuf = false, -- force a reload of user buf so it may be modified externally. may be automatic in future version.
        LastMoveDirectionLR = ImGuiDir.Left, -- ImGuiDir_Left or ImGuiDir_Right. track last movement direction so when cursor cross over a word-wrapping boundaries we can display it on either line depending on last move.s
        ReloadSelectionStart = 0,
        ReloadSelectionEnd = 0,
    }

    return setmetatable(this, MT.ImGuiInputTextState)
end

function MT.ImGuiInputTextState:ClearText() self.TextLen = 0; self.TextA.Data[1] = 0; self:CursorClamp() end
function MT.ImGuiInputTextState:ClearFreeMemory() self.TextA:clear(); self.TextToRevertTo:clear() end
function MT.ImGuiInputTextState:GetText() if self.TextA.Data then return self.TextA.Data else return { 0 } end end -- [Luau] byte table (char[])

-- Internal temporary state for deactivating InputText() instances.
-- Store as part of ImGuiDeactivatedItemData?
--- @class ImGuiInputTextDeactivatedState
--- @field ID          ImGuiID        # widget id owning the text state (which just got deactivated)
--- @field ElapseFrame int
--- @field TextA       ImVector<char> # text buffer
MT.ImGuiInputTextDeactivatedState = {}
MT.ImGuiInputTextDeactivatedState.__index = MT.ImGuiInputTextDeactivatedState

function MT.ImGuiInputTextDeactivatedState:ClearFreeMemory()
    self.ID = 0
    self.ElapseFrame = 0
    self.TextA:clear()
end

--- @return ImGuiInputTextDeactivatedState
--- @nodiscard
local function ImGuiInputTextDeactivatedState()
    return setmetatable({
        ID          = 0,         -- widget id owning the text state (which just got deactivated)
        ElapseFrame = 0,
        TextA       = ImVector() -- text buffer
    }, MT.ImGuiInputTextDeactivatedState)
end

--- @alias ImGuiKeyRoutingIndex ImS16

-- Routing table entry (sizeof() == 16 bytes)
--- @class ImGuiKeyRoutingData
--- @field NextEntryIndex   ImGuiKeyRoutingIndex
--- @field Mods             ImU16 # Technically we'd only need 4-bits but for simplify we store ImGuiMod_ values which need 16-bits.
--- @field RoutingCurrScore ImU16 # [DEBUG] For debug display
--- @field RoutingNextScore ImU16 # Lower is better (0: perfect score)
--- @field RoutingCurr      ImGuiID
--- @field RoutingNext      ImGuiID

--- @return ImGuiKeyRoutingData
--- @nodiscard
function ImGuiKeyRoutingData()
    return {
        NextEntryIndex = -1,
        Mods = 0, -- Technically we'd only need 4-bits but for simplify we store ImGuiMod_ values which need 16-bits.
        RoutingCurrScore = 0, -- [DEBUG] For debug display
        RoutingNextScore = 0, -- Lower is better (0: perfect score)
        RoutingCurr = ImGuiKeyOwner_NoOwner,
        RoutingNext = ImGuiKeyOwner_NoOwner
    }
end

-- Routing table: maintain a desired owner for each possible key-chord (key + mods), and setup owner in NewFrame() when mods are matching.
-- Stored in main context (1 instance)
--- @class ImGuiKeyRoutingTable
--- @field Index       ImGuiKeyRoutingIndex[] # Index of first entry in Entries[]
--- @field Entries     ImVector<ImGuiKeyRoutingData>
--- @field EntriesNext ImVector<ImGuiKeyRoutingData> # Double-buffer to avoid reallocation (could use a shared buffer)
MT.ImGuiKeyRoutingTable = {}
MT.ImGuiKeyRoutingTable.__index = MT.ImGuiKeyRoutingTable

function MT.ImGuiKeyRoutingTable:Clear()
    for n = 1, ImGuiKey.NamedKey_COUNT do self.Index[n] = -1 end
    self.Entries:clear()
    self.EntriesNext:clear()
end

--- @return ImGuiKeyRoutingTable
local function ImGuiKeyRoutingTable()
    local this = setmetatable({
        Index       = {}, -- Index of first entry in Entries[]
        Entries     = ImVector(),
        EntriesNext = ImVector() -- Double-buffer to avoid reallocation (could use a shared buffer)
    }, MT.ImGuiKeyRoutingTable)

    this:Clear()

    return this
end

-- Helper: ImGuiTextIndex
-- Maintain a line index for a text buffer. This is a strong candidate to be moved into the public API.
--- @class ImGuiTextIndex
--- @field Offsets   ImVector<int>
--- @field EndOffset int # Because we don't own text buffer we need to maintain EndOffset (may bake in LineOffsets?)
local IMGUI_TEXT_INDEX = {}
IMGUI_TEXT_INDEX.__index = IMGUI_TEXT_INDEX

function IMGUI_TEXT_INDEX:clear() self.Offsets:clear(); self.EndOffset = 0; end

function IMGUI_TEXT_INDEX:size() return self.Offsets.Size end
-- [Port] 'n' is a 0-based line number like upstream (Offsets.Data is 1-based), 'base' the 1-based position of the buffer start; returns 1-based positions
function IMGUI_TEXT_INDEX:get_line_begin(base, n)
    return base + (self.Offsets.Size ~= 0 and self.Offsets.Data[n + 1] or 0)
end

function IMGUI_TEXT_INDEX:get_line_end(base, n)
    return base + ((n + 1 < self.Offsets.Size) and (self.Offsets.Data[n + 2] - 1) or self.EndOffset)
end

--- @return ImGuiTextIndex
local function ImGuiTextIndex()
    return setmetatable({ Offsets = ImVector(), EndOffset = 0 }, IMGUI_TEXT_INDEX)
end

--- @class ImGuiDebugAllocEntry
--- @field FrameCount int
--- @field AllocCount int
--- @field FreeCount  int

--- @return ImGuiDebugAllocEntry
local function ImGuiDebugAllocEntry()
    return { FrameCount = 0, AllocCount = 0, FreeCount = 0 }
end

--- @class ImGuiDebugAllocInfo
--- @field TotalAllocCount int # Number of call to MemAlloc().
--- @field TotalFreeCount  int
--- @field LastEntriesIdx  ImS16 # Current index in buffer
--- @field LastEntriesBuf  ImGuiDebugAllocEntry[] # Track last 6 frames that had allocations

--- @return ImGuiDebugAllocInfo
local function ImGuiDebugAllocInfo()
    local this = {
        TotalAllocCount = 0, -- Number of call to MemAlloc().
        TotalFreeCount = 0,
        LastEntriesIdx = 1, -- Current index in buffer
        LastEntriesBuf = {nil, nil, nil, nil, nil, nil}, -- Track last 6 frames that had allocations
    }

    for i = 1, 6 do
        this.LastEntriesBuf[i] = ImGuiDebugAllocEntry()
    end

    return this
end

--- @class ImGuiMetricsConfig

--- @return ImGuiMetricsConfig
local function ImGuiMetricsConfig()
    return
    {
        ShowDebugLog = false,
        ShowIDStackTool = false,
        ShowWindowsRects = false,
        ShowWindowsBeginOrder = false,
        ShowTablesRects = false,
        ShowDrawCmdMesh = true,
        ShowDrawCmdBoundingBoxes = true,
        ShowTextEncodingViewer = false,
        ShowTextureUsedRect = false,
        ShowDockingNodes = false,
        ShowWindowsRectsType = -1,
        ShowTablesRectsType = -1,
        HighlightMonitorIdx = -1,
        HighlightViewportID = 0,
        SettingsDiscardMonths = 6,
        SettingsHighlightOldEntries = false,
        ShowFontPreview = true,
    }
end

-- Storage for navigation query/results
--- @class ImGuiNavItemData
--- @field Window             ImGuiWindow?           # Init,Move -- Best candidate window (result->ItemWindow->RootWindowForNav == request->Window)
--- @field ID                 ImGuiID                # Init,Move -- Best candidate item ID
--- @field FocusScopeId       ImGuiID                # Init,Move -- Best candidate focus scope ID
--- @field RectRel            ImRect                 # Init,Move -- Best candidate bounding box in window relative space
--- @field ItemFlags          ImGuiItemFlags         # ????,Move -- Best candidate item flags
--- @field SelectionUserData  ImGuiSelectionUserData # I+Mov -- Best candidate SetNextItemSelectionUserData() value. Valid if (ItemFlags & ImGuiItemFlags.HasSelectionUserData)
--- @field DistBox            float                  # Move -- Best candidate box distance to current NavId
--- @field DistCenter         float                  # Move -- Best candidate center distance to current NavId
--- @field DistAxial          float                  # Move -- Best candidate axial distance to current NavId
MT.ImGuiNavItemData = {}
MT.ImGuiNavItemData.__index = MT.ImGuiNavItemData

function MT.ImGuiNavItemData:Clear()
    self.Window             = nil
    self.ID                 = 0
    self.FocusScopeId       = 0
    self.ItemFlags          = 0
    self.SelectionUserData  = ImGuiSelectionUserData_Invalid
    self.DistBox    = FLT_MAX
    self.DistCenter = FLT_MAX
    self.DistAxial  = FLT_MAX
end

--- @return ImGuiNavItemData
local function ImGuiNavItemData()
    local this = setmetatable({ }, MT.ImGuiNavItemData)
    this.RectRel = ImRect()
    this:Clear()
    return this
end

-------------------------------------------------------------------------------
-- [SECTION] Typing-select support
-------------------------------------------------------------------------------

-- Flags for GetTypingSelectRequest()
--- @enum ImGuiTypingSelectFlags
ImGuiTypingSelectFlags = {
    None                = 0,
    AllowBackspace      = bitLShift(1, 0), -- Backspace to delete character inputs. If using: ensure GetTypingSelectRequest() is not called more than once per frame (filter by e.g. focus state)
    AllowSingleCharMode = bitLShift(1, 1), -- Allow "single char" search mode which is activated when pressing the same character multiple times.
}

-- Returned by GetTypingSelectRequest(), designed to eventually be public.
--- @class ImGuiTypingSelectRequest
--- @field Flags           ImGuiTypingSelectFlags # Flags passed to GetTypingSelectRequest()
--- @field SearchBufferLen int
--- @field SearchBuffer    string                 # Search buffer contents (use full string. unless SingleCharMode is set, in which case use SingleCharSize).
--- @field SelectRequest   bool                   # Set when buffer was modified this frame, requesting a selection.
--- @field SingleCharMode  bool                   # Notify when buffer contains same character repeated, to implement special mode. In this situation it preferred to not display any on-screen search indication.
--- @field SingleCharSize  int                    # Length in bytes of first letter codepoint (1 for ascii, 2-4 for UTF-8). If (SearchBufferLen==RepeatCharSize) only 1 letter has been input.
local function ImGuiTypingSelectRequest()
    return { Flags = 0, SearchBufferLen = 0, SearchBuffer = "", SelectRequest = false, SingleCharMode = false, SingleCharSize = 0 }
end

-- Storage for GetTypingSelectRequest()
-- [Port] SearchBuffer is an immutable Lua string (C++: char[64], 63 bytes max + zero terminator). SearchBuffer[0] != 0 -> #SearchBuffer ~= 0.
--- @class ImGuiTypingSelectState
--- @field Request            ImGuiTypingSelectRequest # User-facing data
--- @field SearchBuffer       string                   # Search buffer: no need to make dynamic as this search is very transient.
--- @field FocusScope         ImGuiID
--- @field LastRequestFrame   int
--- @field LastRequestTime    float
--- @field SingleCharModeLock bool                     # After a certain single char repeat count we lock into SingleCharMode. Two benefits: 1) buffer never fill, 2) we can provide an immediate SingleChar mode without timer elapsing.
MT.ImGuiTypingSelectState = {}
MT.ImGuiTypingSelectState.__index = MT.ImGuiTypingSelectState

--- @return ImGuiTypingSelectState
function ImGuiTypingSelectState()
    return setmetatable({ Request = ImGuiTypingSelectRequest(), SearchBuffer = "", FocusScope = 0, LastRequestFrame = 0, LastRequestTime = 0.0, SingleCharModeLock = false }, MT.ImGuiTypingSelectState)
end
function MT.ImGuiTypingSelectState:Clear() self.SearchBuffer = ""; self.SingleCharModeLock = false end -- We preserve remaining data for easier debugging

-------------------------------------------------------------------------------
-- [SECTION] Box-select support
-------------------------------------------------------------------------------

--- @class ImGuiBoxSelectState
--- @field ID                    ImGuiID
--- @field IsActive              bool
--- @field IsStarting            bool
--- @field IsStartedFromVoid     bool         # Starting click was not from an item.
--- @field IsStartedSetNavIdOnce bool
--- @field RequestClear          bool
--- @field KeyMods               ImGuiKeyChord # Latched key-mods for box-select logic.
--- @field StartPosRel           ImVec2       # Start position in window-contents relative space (to support scrolling)
--- @field EndPosRel             ImVec2       # End position in window-contents relative space
--- @field ScrollAccum           ImVec2       # Scrolling accumulator (to behave at high-frame spaces)
--- @field Window                ImGuiWindow?
--- @field UnclipMode            bool         # (Temp/Transient, here in hot area). Set/cleared by the BeginMultiSelect()/EndMultiSelect() owning active box-select.
--- @field UnclipRect            ImRect       # Rectangle where ItemAdd() clipping may be temporarily disabled. Need support by multi-select supporting widgets.
--- @field UnclipRects           ImRect[]     # Per-axis versions. [Port] 1-based: [1] = upstream [0] (X), [2] = upstream [1] (Y)
--- @field BoxSelectRectPrev     ImRect       # Selection rectangle in absolute coordinates (derived every frame from BoxSelectStartPosRel and MousePos)
--- @field BoxSelectRectCurr     ImRect
--- @return ImGuiBoxSelectState
function ImGuiBoxSelectState()
    return {
        -- Active box-selection data (persistent, 1 active at a time)
        ID = 0, IsActive = false, IsStarting = false, IsStartedFromVoid = false, IsStartedSetNavIdOnce = false, RequestClear = false,
        KeyMods = 0,
        StartPosRel = ImVec2(), EndPosRel = ImVec2(), ScrollAccum = ImVec2(),
        Window = nil,

        -- Temporary/Transient data
        UnclipMode = false,
        UnclipRect = ImRect(),
        UnclipRects = { ImRect(), ImRect() },
        BoxSelectRectPrev = ImRect(),
        BoxSelectRectCurr = ImRect(),
    }
end

-------------------------------------------------------------------------------
-- [SECTION] Multi-select support
-------------------------------------------------------------------------------

-- We always assume that -1 is an invalid value (which works for indices and pointers)
-- (ImGuiSelectionUserData_Invalid is defined above with the ImGuiSelectionUserData alias)

-- Temporary storage for multi-select
--- @class ImGuiMultiSelectTempData
--- @field IO                           ImGuiMultiSelectIO # MUST BE FIRST FIELD. Requests are set and returned by BeginMultiSelect()/EndMultiSelect() + written to by user during the loop.
--- @field Storage                      ImGuiMultiSelectState?
--- @field FocusScopeId                 ImGuiID            # Copied from g.CurrentFocusScopeId (unless another selection scope was pushed manually)
--- @field Flags                        ImGuiMultiSelectFlags
--- @field ScopeRectMin                 ImVec2
--- @field BackupCursorMaxPos           ImVec2
--- @field BoxSelectId                  ImGuiID
--- @field KeyMods                      ImGuiKeyChord
--- @field LoopRequestSetAll            int                # -1: no operation, 0: clear all, 1: select all.
--- @field IsEndIO                      bool               # Set when switching IO from BeginMultiSelect() to EndMultiSelect() state.
--- @field IsFocused                    bool               # Set if currently focusing the selection scope (any item of the selection). May be used if you have custom shortcut associated to selection.
--- @field IsKeyboardSetRange           bool               # Set by BeginMultiSelect() when using Shift+Navigation. Because scrolling may be affected we can't afford a frame of lag with Shift+Navigation.
--- @field NavIdPassedBy                bool
--- @field RangeSrcPassedBy             bool               # Set by the item that matches RangeSrcItem.
--- @field RangeDstPassedBy             bool               # Set by the item that matches NavJustMovedToId when IsSetRange is set.
--- @field IsSoleOrUnknownSelectionSize bool
MT.ImGuiMultiSelectTempData = {}
MT.ImGuiMultiSelectTempData.__index = MT.ImGuiMultiSelectTempData

--- @return ImGuiMultiSelectTempData
function ImGuiMultiSelectTempData()
    local this = setmetatable({ IO = ImGuiMultiSelectIO(), ScopeRectMin = ImVec2(), BackupCursorMaxPos = ImVec2() }, MT.ImGuiMultiSelectTempData)
    this:Clear()
    return this
end
-- Zero-clear except IO as we preserve IO.Requests[] buffer allocation.
function MT.ImGuiMultiSelectTempData:Clear()
    self:ClearIO()
    self.Storage = nil
    self.FocusScopeId = 0
    self.Flags = 0
    ImVec2_CopyV(self.ScopeRectMin, 0.0, 0.0)
    ImVec2_CopyV(self.BackupCursorMaxPos, 0.0, 0.0)
    self.BoxSelectId = 0
    self.KeyMods = 0
    self.LoopRequestSetAll = 0
    self.IsEndIO = false
    self.IsFocused = false
    self.IsKeyboardSetRange = false
    self.NavIdPassedBy = false
    self.RangeSrcPassedBy = false
    self.RangeDstPassedBy = false
    self.IsSoleOrUnknownSelectionSize = false
end
function MT.ImGuiMultiSelectTempData:ClearIO() local io = self.IO; io.Requests:resize(0); io.RangeSrcItem = ImGuiSelectionUserData_Invalid; io.NavIdItem = ImGuiSelectionUserData_Invalid; io.NavIdSelected = false; io.RangeSrcReset = false end

-- Persistent storage for multi-select (as long as selection is alive)
--- @class ImGuiMultiSelectState
--- @field Window            ImGuiWindow?
--- @field ID                ImGuiID
--- @field LastFrameActive   int                    # Last used frame-count, for GC.
--- @field LastSelectionSize int                    # Set by BeginMultiSelect() based on optional info provided by user. May be -1 if unknown.
--- @field RangeSelected     int                    # -1 (don't have) or true/false
--- @field NavIdSelected     int                    # -1 (don't have) or true/false
--- @field RangeSrcItem      ImGuiSelectionUserData #
--- @field NavIdItem         ImGuiSelectionUserData # SetNextItemSelectionUserData() value for NavId (if part of submitted items)
--- @return ImGuiMultiSelectState
function ImGuiMultiSelectState()
    return { Window = nil, ID = 0, LastFrameActive = 0, LastSelectionSize = 0, RangeSelected = -1, NavIdSelected = -1, RangeSrcItem = ImGuiSelectionUserData_Invalid, NavIdItem = ImGuiSelectionUserData_Invalid }
end

--- @param id ImGuiID
--- @return ImGuiBoxSelectState?
function ImGui.GetBoxSelectState(id) local g = GImGui; if id ~= 0 and g.BoxSelectState.ID == id and g.BoxSelectState.IsActive then return g.BoxSelectState end return nil end
--- @param id ImGuiID
--- @return ImGuiMultiSelectState?
function ImGui.GetMultiSelectState(id) local g = GImGui; return g.MultiSelectStorage:GetByKey(id) end

-------------------------------------------------------------------------------
-- [SECTION] ImGuiContext (main Dear ImGui context)
-------------------------------------------------------------------------------

--- @class ImGuiContext
--- @field Initialized                        bool
--- @field WithinFrameScope                   bool # Set by NewFrame(), cleared by EndFrame()
--- @field WithinFrameScopeWithImplicitWindow bool # Set by NewFrame(), cleared by EndFrame() when the implicit debug window has been pushed
--- @field FrameCount                         int
--- @field FrameCountEnded                    int
--- @field CurrentWindow                      ImGuiWindow
--- @field HoveredWindow                      ImGuiWindow
--- @field Style                              ImGuiStyle
--- @field FontAtlases                        ImVector<ImFontAtlas>
--- @field Font                               ImFont
--- @field FontBaked                          ImFontBaked?
--- @field FontSize                           float
--- @field FontSizeBase                       float
--- @field FontBakedScale                     float
--- @field CurrentPixelDensity                float
--- @field DrawListSharedData                 ImDrawListSharedData
--- @field NextItemData                       ImGuiNextItemData
--- @field LastItemData                       ImGuiLastItemData
--- @field NextWindowData                     ImGuiNextWindowData
--- @field WithinEndChildID                   ImGuiID
--- @field WithinEndPopupID                   ImGuiID
--- @field StyleVarStack                      ImVector
--- @field AnyIdHasBeenEditedThisFrame        bool
--- @field ActiveId                           ImGuiID
--- @field ActiveIdMouseButton                ImS8
--- @field Windows                            ImVector<ImGuiWindow>
--- @field WindowsFocusOrder                  ImVector<ImGuiWindow>
--- @field WindowsTempSortBuffer              ImVector<ImGuiWindow>
--- @field CurrentWindowStack                 ImVector<ImGuiWindowStackData>
--- @field FocusScopeStack                    ImVector<ImGuiFocusScopeData>
--- @field ItemFlagsStack                     ImVector<ImGuiItemFlags>
--- @field GroupStack                         ImVector<ImGuiGroupData>
--- @field OpenPopupStack                     ImVector<ImGuiPopupData>
--- @field BeginPopupStack                    ImVector<ImGuiPopupData>
--- @field TreeNodeStack                      ImVector<ImGuiTreeNodeStackData>
--- @field IO                                 ImGuiIO
--- @field PlatformIO                         ImGuiPlatformIO
--- @field Viewports                          ImVector<ImGuiViewportP>
--- @field DebugLogFlags                      ImGuiDebugLogFlags
--- @field DebugFlashStyleColorIdx            ImGuiCol
--- @field ColorEditCurrentID                 ImGuiID                        # Set temporarily while inside of the parent-most ColorEdit4/ColorPicker4 (because they call each others)
--- @field ColorEditSavedID                   ImGuiID                        # ID we are saving/restoring HS for
--- @field ColorEditSavedHue                  float                          # Backup of last Hue associated to LastColor, so we can restore Hue in lossy RGB<>HSV round trips
--- @field ColorEditSavedSat                  float                          # Backup of last Saturation associated to LastColor, so we can restore Saturation in lossy RGB<>HSV round trips
--- @field ColorEditSavedColor                ImU32                          # RGB value with alpha set to 0
--- @field ColorPickerRef                     ImVec4                         # Initial/reference color at the time of opening the color picker
--- @field MenusIdSubmittedThisFrame          ImVector<ImGuiID>
--- @field InputTextState                     ImGuiInputTextState
--- @field InputTextLineIndex                 ImGuiTextIndex
--- @field InputTextDeactivatedState          ImGuiInputTextDeactivatedState
--- @field InputTextPasswordFontBackupBaked   ImFontBaked
--- @field KeysMayBeCharInput                 ImBitArrayForNamedKeys
--- @field KeysOwnerData                      ImGuiKeyOwnerData[]
--- @field KeysRoutingTable                   ImGuiKeyRoutingTable
--- @field NavFocusRoute                      ImVector<ImGuiFocusScopeData>
--- @field PlatformImeData                    ImGuiPlatformImeData
--- @field PlatformImeDataPrev                ImGuiPlatformImeData
--- @field UserTextures                       ImVector<ImTextureData>
--- @field DebugMetricsConfig                 ImGuiMetricsConfig
--- @field DebugAllocInfo                     ImGuiDebugAllocInfo
--- @field TempBuffer                         ImVector<char>

-------------------------------------------------------------------------------
-- [SECTION] Tab bar, Tab item support
-- PORT: public flags from imgui.h + private extensions
-------------------------------------------------------------------------------

-- Flags for ImGui.BeginTabBar()
--- @enum ImGuiTabBarFlags
ImGuiTabBarFlags = {
    None                         = 0,
    Reorderable                  = bitLShift(1, 0), -- Allow manually dragging tabs to re-order them + New tabs are appended at the end of list
    AutoSelectNewTabs            = bitLShift(1, 1), -- Automatically select new tabs when they appear
    TabListPopupButton           = bitLShift(1, 2), -- Disable buttons to open the tab list popup
    NoCloseWithMiddleMouseButton = bitLShift(1, 3), -- Disable behavior of closing tabs (that are submitted with p_open ~= nil) with middle mouse button. You may handle this behavior manually on user's side with if (IsItemHovered() && IsMouseClicked(2)) p_open = false.
    NoTabListScrollingButtons    = bitLShift(1, 4), -- Disable scrolling buttons (apply when fitting policy is ImGuiTabBarFlags.FittingPolicyScroll)
    NoTooltip                    = bitLShift(1, 5), -- Disable tooltips when hovering a tab
    DrawSelectedOverline         = bitLShift(1, 6), -- Draw selected overline markers over selected tab

    -- Fitting/Resize policy
    FittingPolicyMixed           = bitLShift(1, 7), -- Shrink down tabs when they don't fit, until width is style.TabMinWidthShrink, then enable scrolling. Setting TabMinWidthShrink to FLT_MAX makes this behave like ImGuiTabBarFlags.FittingPolicyScroll.
    FittingPolicyShrink          = bitLShift(1, 8), -- Shrink down tabs when they don't fit
    FittingPolicyScroll          = bitLShift(1, 9), -- Enable scrolling buttons when tabs don't fit
    -- Private
    DockNode                     = bitLShift(1, 20), -- Part of a dock node [we don't use this in the master branch but it facilitate branch syncing to keep this around]
    IsFocused                    = bitLShift(1, 21),
    SaveSettings                 = bitLShift(1, 22), -- FIXME: Settings are handled by the docking system, this only request the tab bar to mark settings dirty when reordering tabs
}
ImGuiTabBarFlags.FittingPolicyMask_       = bitOr(ImGuiTabBarFlags.FittingPolicyMixed, ImGuiTabBarFlags.FittingPolicyShrink, ImGuiTabBarFlags.FittingPolicyScroll)
ImGuiTabBarFlags.FittingPolicyDefault_    = ImGuiTabBarFlags.FittingPolicyMixed
ImGuiTabBarFlags.FittingPolicyResizeDown  = ImGuiTabBarFlags.FittingPolicyShrink -- Renamed in 1.92.2

-- Flags for ImGui.BeginTabItem()
--- @enum ImGuiTabItemFlags
ImGuiTabItemFlags = {
    None                         = 0,
    UnsavedDocument              = bitLShift(1, 0), -- Display a dot next to the title + set ImGuiTabItemFlags.NoAssumedClosure.
    SetSelected                  = bitLShift(1, 1), -- Trigger flag to programmatically make the tab selected when calling BeginTabItem()
    NoCloseWithMiddleMouseButton = bitLShift(1, 2), -- Disable behavior of closing tabs (that are submitted with p_open ~= nil) with middle mouse button. You may handle this behavior manually on user's side with if (IsItemHovered() && IsMouseClicked(2)) p_open = false.
    NoPushId                     = bitLShift(1, 3), -- Don't call PushID()/PopID() on BeginTabItem()/EndTabItem()
    NoTooltip                    = bitLShift(1, 4), -- Disable tooltip for the given tab
    NoReorder                    = bitLShift(1, 5), -- Disable reordering this tab or having another tab cross over this tab
    Leading                      = bitLShift(1, 6), -- Enforce the tab position to the left of the tab bar (after the tab list popup button)
    Trailing                     = bitLShift(1, 7), -- Enforce the tab position to the right of the tab bar (before the scrolling buttons)
    NoAssumedClosure             = bitLShift(1, 8), -- Tab is selected when trying to close + closure is not immediately assumed (will wait for user to stop submitting the tab). Otherwise closure is assumed when pressing the X, so if you keep submitting the tab may reappear at end of tab bar.
    -- Private
    NoCloseButton                = bitLShift(1, 20), -- Track whether p_open was set or not (we'll need this info on the next frame to recompute ContentWidth during layout)
    Button                       = bitLShift(1, 21), -- Used by TabItemButton, change the tab item behavior to mimic a button
    Invisible                    = bitLShift(1, 22), -- To reserve space e.g. with ImGuiTabItemFlags.Leading
    Unsorted                     = bitLShift(1, 23), -- [Docking] Trailing tabs with the _Unsorted flag will be sorted based on the DockOrder of their Window.
}
ImGuiTabItemFlags.SectionMask_ = bitOr(ImGuiTabItemFlags.Leading, ImGuiTabItemFlags.Trailing)

-- Storage for one active tab item. In this port the label is stored in `Name` (C++ uses NameOffset into TabBar.TabsNames)
--- @class ImGuiTabItem
--- @return ImGuiTabItem
function ImGuiTabItem()
    return {
        ID = 0, Flags = 0, Window = nil, -- Window: When TabItem is part of a DockNode's TabBar, we hold on to a window.
        LastFrameVisible = -1, LastFrameSelected = -1, -- LastFrameSelected: This allows us to infer an ordered list of the last activated tabs with little maintenance
        -- Offset: Position relative to beginning of tab bar
        -- Width: Width currently displayed
        -- ContentWidth: Width of label + padding, stored during BeginTabItem() call (misnamed as "Content" would normally imply width of label only)
        -- RequestedWidth: Width optionally requested by caller, -1.0 is unused
        Offset = 0.0, Width = 0.0, ContentWidth = 0.0, RequestedWidth = -1.0,
        NameOffset = -1, Name = nil,
        BeginOrder = -1,        -- 0-based -- BeginTabItem() order, used to re-order tabs after toggling ImGuiTabBarFlags.Reorderable
        IndexDuringLayout = -1, -- 0-based -- Index only used during TabBarLayout(). Tabs gets reordered so 'Tabs[n].IndexDuringLayout == n' but may mismatch during additions.
        WantClose = false, -- Marked as closed by SetTabItemClosed()
    }
end

-- Storage for a tab bar. Tabs: ImVector of ImGuiTabItem tables (references; "pointers" stay valid across reorders)
--- @class ImGuiTabBar
--- @return ImGuiTabBar
function ImGuiTabBar()
    return {
        Window = nil, Tabs = ImVector(), Flags = 0, ID = 0, -- ID: Zero for tab-bars used by docking
        -- SelectedTabId: Selected tab/window
        -- NextSelectedTabId: Next selected tab/window. Will also trigger a scrolling animation
        -- VisibleTabId: Can occasionally be != SelectedTabId (e.g. when previewing contents for Ctrl+Tab preview)
        SelectedTabId = 0, NextSelectedTabId = 0, NextScrollToTabId = 0, VisibleTabId = 0,
        CurrFrameVisible = -1, PrevFrameVisible = -1,
        BarRect = ImRect(), BarRectPrevWidth = 0.0, -- BarRectPrevWidth: Backup of previous width. When width change we enforce keep horizontal scroll on focused tab.
        CurrTabsContentsHeight = 0.0, PrevTabsContentsHeight = 0.0, -- PrevTabsContentsHeight: Record the height of contents submitted below the tab bar
        -- WidthAllTabs: Actual width of all tabs (locked during layout)
        -- WidthAllTabsIdeal: Ideal width if all tabs were visible and not clipped
        WidthAllTabs = 0.0, WidthAllTabsIdeal = 0.0,
        ScrollingAnim = 0.0, ScrollingTarget = 0.0, ScrollingTargetDistToVisibility = 0.0, ScrollingSpeed = 0.0,
        ScrollingRectMinX = 0.0, ScrollingRectMaxX = 0.0, SeparatorMinX = 0.0, SeparatorMaxX = 0.0,
        ReorderRequestTabId = 0, ReorderRequestOffset = 0, BeginCount = 0,
        WantLayout = false, VisibleTabWasSubmitted = false, TabsAddedNew = false, ScrollButtonEnabled = false, -- TabsAddedNew: Set to true when a new tab item or button has been added to the tab bar during last frame
        TabsActiveCount = 0, -- Number of tabs submitted this frame.
        LastTabItemIdx = -1, -- 0-based -- Index of last BeginTabItem() tab for use by EndTabItem()
        ItemSpacingY = 0.0, FramePadding = ImVec2(), BackupCursorPos = ImVec2(), -- FramePadding: style.FramePadding locked at the time of BeginTabBar()
    }
end

--- @class ImGuiShrinkWidthItem
function ImGuiShrinkWidthItem() return { Index = 0, Width = 0.0, InitialWidth = 0.0 } end

--- @param shared_font_atlas? ImFontAtlas
--- @return ImGuiContext
--- @nodiscard
function ImGuiContext(shared_font_atlas) -- TODO: tidy up / complete this structure
    local this = {
        Style = ImGuiStyle(),
        ColorStack = ImVector(), -- Stack for PushStyleColor()/PopStyleColor() - inherited by Begin()
        StyleVarStack = ImVector(), -- Stack for PushStyleVar()/PopStyleVar() - inherited by Begin()

        Config = nil,
        Initialized = false,
        WithinFrameScope = false, -- Set by NewFrame(), cleared by EndFrame()
        WithinFrameScopeWithImplicitWindow = false, -- Set by NewFrame(), cleared by EndFrame() when the implicit debug window has been pushed

        Windows = ImVector(), -- Windows sorted in display order, back to front
        WindowsById = {}, -- Map window's ID to window ref

        WindowsBorderHoverPadding = 0, -- Padding around resizable windows for which hovering on counts as hovering the window == ImMax(style.TouchExtraPadding, style.WindowBorderHoverPadding). This isn't so multi-dpi friendly.

        WindowsActiveCount = 0, -- Number of unique windows submitted by frame

        WindowsTempSortBuffer = ImVector(), -- Temporary buffer used in EndFrame() to reorder windows so parents are kept before their child
        CurrentWindowStack = ImVector(),
        CurrentWindow = nil, -- Window being drawn into

        WindowsFocusOrder = ImVector(), -- Root windows, sorted in focus order, back to front.

        IO = ImGuiIO(),
        PlatformIO = ImGuiPlatformIO(),

        ConfigFlagsCurrFrame = ImGuiConfigFlags.None, -- = g.IO.ConfigFlags at the time of NewFrame()
        ConfigFlagsLastFrame = ImGuiConfigFlags.None,

        MouseLastValidPos = ImVec2(),

        KeysMayBeCharInput = ImBitArray(ImGuiKey.NamedKey_COUNT, -ImGuiKey.NamedKey_BEGIN), -- Lookup to tell if a key can emit char input, see IsKeyChordPotentiallyCharInput().
        KeysOwnerData = {}, -- size = ImGuiKey.NamedKey_COUNT
        KeysRoutingTable = ImGuiKeyRoutingTable(),

        InputEventsQueue = ImVector(), -- Input events which will be trickled/written into IO structure.
        InputEventsTrail = ImVector(), -- Past input events processed in NewFrame(). This is to allow domain-specific application to access e.g mouse/pen trail.

        InputEventsNextMouseSource = ImGuiMouseSource.Mouse,
        InputEventsNextEventId = 1,

        MovingWindow = nil, -- Track the window we clicked on (in order to preserve focus). The actual window that is moved is generally MovingWindow.RootWindowDockTree.

        WheelingWindow = nil, -- Track the window we started mouse-wheeling on. Until a timer elapse or mouse has moved, generally keep scrolling the same window even if during the course of scrolling the mouse ends up hovering a child window.
        WheelingWindowStartFrame = -1, WheelingWindowScrolledFrame = -1, -- This may be set one frame before WheelingWindow is ~= nil
        WheelingWindowReleaseTimer = 0.0,
        WheelingWindowRefMousePos = ImVec2(),
        WheelingWindowWheelRemainder = ImVec2(),
        WheelingAxisAvg = ImVec2(),

        ActiveIdClickOffset = ImVec2(), -- Clicked offset from upper-left corner, if applicable (currently only set by ButtonBehavior)

        HoveredWindow = nil, -- Window the mouse is hovering. Will typically catch mouse inputs.
        HoveredWindowUnderMovingWindow = nil, -- Hovered window ignoring MovingWindow. Only set if MovingWindow is set.
        HoveredIdIsDisabled = false, -- At least one widget passed the rect test, but has been discarded by disabled flag or popup inhibit. May be true even if HoveredId == 0.

        ActiveIdFromShortcut = false,

        AnyIdHasBeenEditedThisFrame = false,
        ActiveId = 0, -- Active widget
        ActiveIdWindow = nil,

        ActiveIdMouseButton = -1,

        ActiveIdIsJustActivated = false, -- Set at the time of activation for one frame

        ActiveIdWasSelected = false, ActiveIdWasSoleSelected = false, -- Active ID was selected at the time of activating
        LastActiveIdWasSelected = false, LastActiveIdWasSoleSelected = false,

        ActiveIdNoClearOnFocusLoss = false, -- Disable losing active id if the active id window gets unfocused.
        ActiveIdHasBeenPressedBefore = false, -- Track whether the active id led to a press (this is to allow changing between PressOnClick and PressOnRelease without pressing twice). Used by range_select branch.

        ActiveIdIsAlive = nil, -- Active widget has been seen this frame (we can't use a bool as the ActiveId may change within the frame)

        ActiveIdPreviousFrame = 0,

        ActiveIdTimer = 0.0,
        ActiveIdSource = ImGuiInputSource.None, -- Activating source: ImGuiInputSource.Mouse OR ImGuiInputSource.Keyboard OR ImGuiInputSource.Gamepad

        LastActiveId = 0, -- Store the last non-zero ActiveId, useful for animation.
        LastActiveIdTimer = 0.0, -- Store the last non-zero ActiveId timer since the beginning of activation, useful for animation.

        ActiveIdUsingNavDirMask = 0x00, -- Active widget will want to read those nav move requests (e.g. can activate a button and move away from it)
        ActiveIdUsingAllKeyboardKeys = false, -- Active widget will want to read all keyboard keys inputs. (this is a shortcut for not taking ownership of 100+ keys, frequently used by drag operations)

        DeactivatedItemData = {
            ID = 0,
            ElapseFrame = 0,
            HasBeenEditedBefore = false,
            IsAlive = false
        },

        HoveredId = 0, -- Hovered widget, filled during the frame
        HoveredIdTimer = 0.0, -- Measure contiguous hovering time
        HoveredIdNotActiveTimer = 0.0, -- Measure contiguous hovering time where the item has not been active
        HoveredIdAllowOverlap = false,

        HoverItemDelayId = 0, HoverItemDelayIdPreviousFrame = 0, HoverItemUnlockedStationaryId = 0, HoverWindowUnlockedStationaryId = 0,
        HoverItemDelayTimer = 0.0, HoverItemDelayClearTimer = 0.0, -- Currently used by IsItemHovered()

        ActiveIdAllowOverlap = false, -- Active widget allows another widget to steal active id (generally for overlapping widgets, but not always)

        NavLayer = ImGuiNavLayer.Main, -- Focused layer (main scrolling layer, or menu/title bar layer)
        NavId = 0, -- Focused item for navigation
        NavOpenContextMenuItemId = 0, NavOpenContextMenuWindowId = 0,
        NavWindow = nil, -- Focused window for navigation. Could be called 'FocusedWindow'
        NavHighlightActivatedId = 0,
        NavHighlightActivatedTimer = 0.0,
        NavCursorVisible = false, -- Nav focus cursor/rectangle is visible? We hide it after a mouse click. We show it after a nav move.
        NavCursorHideFrames = 0,
        NavHighlightItemUnderNav = false, -- Disable mouse hovering highlight. Highlight navigation focused item instead of mouse hovered item.
        NavIdIsAlive = false, -- Nav widget has been seen this frame ~~ NavRectRel is valid
        NavInputSource = ImGuiInputSource.Keyboard, -- Keyboard or Gamepad mode? THIS CAN ONLY BE ImGuiInputSource.Keyboard or ImGuiInputSource.Gamepad
        NavLastValidSelectionUserData = ImGuiSelectionUserData_Invalid, -- Last valid data passed to SetNextItemSelectionUser(), or -1. For current window. Not reset when focusing an item that doesn't have selection data.
        NavWindowingTarget = nil, NavWindowingTargetAnim = nil, NavWindowingListWindow = nil, -- Target window when doing Ctrl+Tab (or Pad Menu + FocusPrev/Next), this window is temporarily displayed top-most!
        NavWindowingTimer = 0.0, NavWindowingHighlightAlpha = 0.0,
        NavWindowingToggleLayer = false, -- Set while Alt or GamepadMenu is held, may be cleared by other operations, and processed when releasing the key.
        NavWindowingToggleKey = ImGuiKey.None, -- Keyboard/gamepad key used when toggling to menu layer.
        NavWindowingInputSource = ImGuiInputSource.None,
        NavWindowingAccumDeltaPos = ImVec2(0.0, 0.0), NavWindowingAccumDeltaSize = ImVec2(0.0, 0.0),
        DimBgRatio = 0.0, -- 0.0..1.0 animation when fading in a dimming background (for modal window and Ctrl+Tab list)
        LastKeyboardKeyPressTime = -1.0, LastKeyModsChangeTime = -1.0, LastKeyModsChangeFromNoneTime = -1.0, -- Record the last time a keyboard key (ignore mouse/gamepad ones) was pressed.
        ConfigNavWindowingKeyNext = bit32.bor(ImGuiMod_Ctrl, ImGuiKey.Tab), -- = ImGuiMod_Ctrl | ImGuiKey.Tab (or ImGuiMod_Super | ImGuiKey.Tab on OS X). Set to 0 to disable. For reconfiguration (see #4828)
        ConfigNavWindowingKeyPrev = bit32.bor(ImGuiMod_Ctrl, ImGuiMod_Shift, ImGuiKey.Tab), -- = ImGuiMod_Ctrl | ImGuiMod_Shift | ImGuiKey.Tab (or ImGuiMod_Super | ImGuiMod_Shift | ImGuiKey.Tab on OS X)
        ConfigNavWindowingWithGamepad = true, -- = true. Enable Ctrl+Tab by holding ImGuiKey.GamepadFaceLeft (== ImGuiKey.NavGamepadMenu). When false, the button may still be used to toggle Menu layer.

        NavFocusRoute = ImVector(), -- Reversed copy focus scope stack for NavId (should contains NavFocusScopeId). This essentially follow the window.ParentWindowForFocusRoute chain.

        NavAnyRequest = false, -- ~~ NavMoveRequest || NavInitRequest this is to perform early out in ItemAdd()
        NavInitRequest = false, -- Init request for appearing window to select first item
        NavInitRequestFromMove = false,
        NavInitResult = ImGuiNavItemData(), -- Init request result (first item of the window, or one for which SetItemDefaultFocus() was called)
        NavMoveSubmitted = false, -- Move request submitted, will process result on next NewFrame()
        NavMoveScoringItems = false, -- Move request submitted, still scoring incoming items
        NavMoveForwardToNextFrame = false,
        NavMoveFlags = ImGuiNavMoveFlags.None,
        NavMoveScrollFlags = ImGuiScrollFlags.None,
        NavMoveKeyMods = ImGuiMod_None,
        NavMoveDir = ImGuiDir.None, NavMoveDirForDebug = ImGuiDir.None, NavMoveClipDir = ImGuiDir.None, -- Direction of the move request (left/right/up/down)
        NavMoveResultLocal = ImGuiNavItemData(), -- Best move request candidate within NavWindow
        NavMoveResultOther = ImGuiNavItemData(), -- Best move request candidate within NavWindow's flattened hierarchy (when using ImGuiWindowFlags.NavFlattened flag)
        NavMoveResultLocalVisible = ImGuiNavItemData(), -- Best move request candidate within NavWindow that are mostly visible (when using ImGuiNavMoveFlags.AlsoScoreVisibleSet flag)
        NavTabbingResultFirst = ImGuiNavItemData(), -- First tabbing request candidate within NavWindow and flattened hierarchy
        NavScoringRect = ImRect(), -- Rectangle used for scoring, in screen space. Based of window.NavRectRel[], modified for directional navigation scoring.
        NavScoringNoClipRect = ImRect(), -- Some nav operations (such as PageUp/PageDown) enforce a region which clipper will attempt to always keep submitted. Unset/invalid if inverted.
        ConfigNavEnableTabbing = true, -- = true. Enable tabbing (Tab, Shift+Tab). PLEASE LET ME KNOW IF YOU USE THIS.
        NavTabbingCounter = 0, -- >0 when counting items for tabbing
        NavTabbingDir = 0, -- Generally -1 or +1, 0 when tabbing without a nav id
        NavNextActivateId = 0, -- Set by ActivateItemByID(), queued until next frame.
        NavNextActivateFlags = ImGuiActivateFlags.None,
        NavActivateId = 0, NavActivateDownId = 0, NavActivatePressedId = 0, -- ~~ (g.ActiveId == 0) && (IsKeyPressed(ImGuiKey.Space) || IsKeyDown(ImGuiKey.Enter) || IsKeyPressed(ImGuiKey.NavGamepadActivate)) ? NavId : 0, also set when calling ActivateItemByID()
        NavActivateFlags = ImGuiActivateFlags.None,

        -- Navigation: record of last move request
        NavJustMovedFromFocusScopeId = 0, -- Just navigated from this focus scope id (result of a successfully MoveRequest).
        NavJustMovedToId = 0, -- Just navigated to this id (result of a successfully MoveRequest).
        NavJustMovedToFocusScopeId = 0, -- Just navigated to this focus scope id (result of a successfully MoveRequest).
        NavJustMovedToKeyMods = 0,
        NavJustMovedToIsTabbing = false, -- Copy of ImGuiNavMoveFlags.IsTabbing. Maybe we should store whole flags.
        NavJustMovedToIsInit = false, -- Copy of ImGuiNavMoveFlags.IsInit. Maybe we should store whole flags.
        NavJustMovedToHasSelectionData = false, -- Copy of move result's ItemFlags & ImGuiItemFlags.HasSelectionUserData). Maybe we should just store ImGuiNavItemData.

        FrameCount = 0,

        FrameCountEnded = -1,
        FrameCountPlatformEnded = -1,
        FrameCountRendered = -1,

        Time = 0,

        NextItemData = ImGuiNextItemData(), -- Storage for SetNextItem** functions
        LastItemData = ImGuiLastItemData(), -- Storage for last submitted item (setup by ItemAdd)
        NextWindowData = ImGuiNextWindowData(), -- Storage for SetNextWindow** functions

        Viewports = ImVector(), -- Active viewports (always 1+, and generally 1 unless multi-viewports are enabled). Each viewports hold their copy of ImDrawData.

        FallbackMonitor = nil, -- Virtual monitor used as fallback if backend doesn't provide monitor information.

        GcCompactAll = false, -- Request full GC

        CurrentViewport = nil,
        MouseViewport = nil, MouseLastHoveredViewport = nil,
        PlatformLastFocusedViewportId = 1,
        ViewportCreatedCount = 0, PlatformWindowsCreatedCount = 0, -- Unique sequential creation counter (mostly for testing/debugging)
        ViewportFocusedStampCount = 0, -- Every time the front-most window changes, we stamp its viewport with an incrementing counter

        Font = nil, -- Currently bound font. (== FontStack.back().Font)
        FontSize = 0.0, -- Currently bound font size == line height (== FontSizeBase + externals scales applied in the UpdateCurrentFontSize() function).
        FontSizeBase = 0.0, -- Font size before scaling == style.FontSizeBase == value passed to PushFont() when specified.
        CurrentDpiScale = 0.0, -- Current window/viewport DpiScale == CurrentViewport.DpiScale

        FontRefSize = 0.0,

        CurrentPixelDensity = 1.0,

        FontAtlases = ImVector(), -- List of font atlases used by the context (generally only contains g.IO.Fonts aka the main font atlas)

        FontStack = ImVector(), -- Stack for PushFont()/PopFont() - inherited by Begin()

        OpenPopupStack = ImVector(), -- Which popups are open (persistent)
        BeginPopupStack = ImVector(), -- Which level of BeginPopup() we are in (reset every frame)

        TreeNodeStack = ImVector(ImGuiTreeNodeStackData),

        WithinEndChildID = 0, WithinEndPopupID = 0, -- Set within EndChild()

        BeginMenuDepth = 0, BeginComboDepth = 0,

        ColorEditCurrentID = 0, ColorEditSavedID = 0, -- Set temporarily while inside of the parent-most ColorEdit4/ColorPicker4 (because they call each others).
        ColorEditSavedHue = 0.0, ColorEditSavedSat = 0.0, -- Backup of last Hue associated to LastColor, so we can restore Hue in lossy RGB<>HSV round trips
        ColorEditSavedColor = 0, -- RGB value with alpha set to 0.
        ColorPickerRef = ImVec4(), -- Initial/reference color at the time of opening the color picker.

        MenusIdSubmittedThisFrame = ImVector(), -- A list of menu IDs that were rendered at least once

        DrawListSharedData = ImDrawListSharedData(),

        StackSizesInBeginForCurrentWindow = nil,

        MouseCursor = ImGuiMouseCursor.Arrow,
        MouseStationaryTimer = 0.0, -- Time the mouse has been stationary (with some loose heuristic)

        TypingSelectState = ImGuiTypingSelectState(), -- State for GetTypingSelectRequest()

        InputTextState = ImGuiInputTextState(),
        InputTextLineIndex = ImGuiTextIndex(), -- Temporary storage
        InputTextDeactivatedState = ImGuiInputTextDeactivatedState(),
        InputTextPasswordFontBackupBaked = ImFontBaked(),
        InputTextReactivateId = 0, -- ID of InputText to reactivate on next frame (for io.ConfigInputTextEnterKeepActive behavior)
        TempInputId = 0, -- Temporary text input when using Ctrl+Click on a slider, etc.

        ActiveIdValueOnActivation = 0, -- Backup of initial value at the time of activation. ONLY SET BY SPECIFIC WIDGETS: DragXXX and SliderXXX.
        DataTypeZeroValue = 0, -- 0 for all data types

        ComboPreviewData = ImGuiComboPreviewData(),

        CurrentTabBar = nil,
        TabBars = ImPool(ImGuiTabBar),   -- ImPool<ImGuiTabBar>
        -- Docking
        DockContext = ImGuiDockContext(),
        DockNodeWindowMenuHandler = nil,
        DebugHoveredDockNode = nil, -- Hovered dock node.
        CurrentTabBarStack = ImVector(), -- ImVector<ImGuiPtrOrIndex>
        ShrinkWidthBuffer = ImVector(),  -- ImGuiShrinkWidthItem

        -- Multi-Select state
        BoxSelectState = ImGuiBoxSelectState(),
        CurrentMultiSelect = nil,
        MultiSelectTempDataStacked = 0, -- Temporary multi-select data size (because we leave previous instances undestructed, we generally don't use MultiSelectTempData.Size)
        MultiSelectTempData = ImVector(), -- ImVector<ImGuiMultiSelectTempData>, 1-based
        MultiSelectStorage = ImPool(ImGuiMultiSelectState), -- ImPool<ImGuiMultiSelectState>

        WindowResizeBorderExpectedRect = ImRect(), -- Expected border rect, switch to relative edit if moving
        WindowResizeRelativeMode = false,

        ScrollbarSeekMode = 0, -- 0: scroll to clicked location, -1/+1: prev/next page.
        ScrollbarClickDeltaToGrabCenter = 0.0, -- When scrolling to mouse location: distance between mouse and center of grab box, normalized in parent space.

        SliderGrabClickOffset = 0.0,
        SliderCurrentAccum = 0.0, -- Accumulated slider delta when using navigation controls.
        SliderCurrentAccumDirty = false, -- Has the accumulated slider delta changed since last time we tried to apply it?
        DragCurrentAccumDirty = false,
        DragCurrentAccum = 0.0, -- Accumulator for dragging modification. Always high-precision, not rounded by end-user precision settings
        DragSpeedDefaultRatio = 1.0 / 100.0, -- If speed == 0.0, uses (max-min) * DragSpeedDefaultRatio

        TooltipOverrideCount = 0,
        TooltipPreviousWindow = nil, -- Window of last tooltip submitted during the frame

        FocusScopeStack = ImVector(), -- Stack for PushFocusScope()/PopFocusScope() - inherited by BeginChild(), pushed into by Begin()
        CurrentFocusScopeId = 0, -- Value for currently appending items == g.FocusScopeStack.back(). Not to be mistaken with g.NavFocusScopeId.
        CurrentItemFlags = ImGuiItemFlags.None, -- Value for currently appending items == g.ItemFlagsStack.back()

        DisabledAlphaBackup = 0.0, -- Backup for style.Alpha for BeginDisabled()
        DisabledStackSize = 0,
        MixedValueLabel = "-", -- Value replacement when displaying a mixed value.

        ItemFlagsStack = ImVector(), -- Stack for PushItemFlag()/PopItemFlag() - inherited by Begin()
        GroupStack = ImVector(), -- Stack for BeginGroup()/EndGroup() - not inherited by Begin()

        PlatformImeData = ImGuiPlatformImeData(), -- Data updated by current frame. Will be applied at end of the frame. For some backends, this is required to have WantVisible=true in order to receive text message.
        PlatformImeDataPrev = ImGuiPlatformImeData(), -- Previous frame data. When changed we call the platform_io.Platform_SetImeDataFn() handler.

        -- Extensions
        UserTextures = ImVector(), -- List of textures created/managed by user or third-party extension. Automatically appended into platform_io.Textures[].

        -- Settings
        SettingsLoaded = false,
        SettingsDirtyTimer = 0.0, -- Save .ini Settings to memory when time reaches zero
        SettingsIniData = "",          -- In memory .ini settings (string)
        SettingsHandlers = ImVector(), -- List of .ini settings handlers
        SettingsWindows = ImVector(), -- ImGuiWindow .ini settings entries
        SettingsTables = ImVector(), -- ImGuiTable .ini settings entries

        -- Hooks
        Hooks = ImVector(), -- Hooks for extensions (e.g. test engine)
        HookIdNext = 0, -- Next available HookId
        SessionDate = ImGuiPackedDate(), -- Packed copy of platform_io.Platform_SessionDate, when valid.
        DemoMarkerCallback = nil, -- [Luau] fun(file, line, section)

        -- Drag and Drop
        DragDropActive = false,
        DragDropWithinSource = false, -- Set when within a BeginDragDropXXX/EndDragDropXXX block for a drag source.
        DragDropWithinTarget = false, -- Set when within a BeginDragDropXXX/EndDragDropXXX block for a drag target.
        DragDropSourceFlags = 0,
        DragDropSourceFrameCount = -1,
        DragDropMouseButton = -1,
        DragDropPayload = ImGuiPayload(),
        DragDropTargetRect = ImRect(), -- Store rectangle of current target candidate (we favor small targets when overlapping)
        DragDropTargetClipRect = ImRect(), -- Store ClipRect at the time of item's drawing
        DragDropTargetId = 0,
        DragDropTargetFullViewport = 0,
        DragDropAcceptFlagsCurr = 0, DragDropAcceptFlagsPrev = 0,
        DragDropAcceptIdCurrRectSurface = 0.0, -- Target item surface (we resolve overlapping targets by prioritizing the smaller surface)
        DragDropAcceptFrameCount = -1, -- Last time a target expressed a desire to accept the source
        DragDropHoldJustPressedId = 0, -- Set when holding a payload just made ButtonBehavior() return a press.

        DragDropAcceptIdPrev = 0, DragDropAcceptIdCurr = 0, -- Target item id from previous frame (we need to store this to allow for overlapping drag and drop targets)

        -- Clipper
        ClipperTempDataStacked = 0,
        ClipperTempData = ImVector(),

        -- Logging
        LogEnabled = false, -- Currently capturing
        LogLineFirstItem = false,
        LogFlags = 0, -- Capture flags/type
        LogWindow = nil,
        LogFile = nil, -- If ~= nil log to stdout/ file
        LogBuffer = ImGuiTextBuffer(), -- Accumulation buffer when log to clipboard.
        LogNextPrefix = nil, LogNextSuffix = nil, -- See comment in LogSetNextTextDecoration(): doesn't copy underlying data, use carefully!
        LogLinePosY = FLT_MAX,
        LogDepthRef = 0,
        LogDepthToExpand = 2, LogDepthToExpandDefault = 2,

        -- Error handling
        ErrorCallback = nil, ErrorCallbackUserData = nil, -- = nil. May be exposed in public API eventually.
        ErrorTooltipLockedPos = ImVec2(),
        ErrorFirst = true,
        ErrorCountCurrentFrame = 0, -- [Internal] Number of errors submitted this frame.
        StackSizesInNewFrame = nil, -- [Internal]
        ContextName = "", -- Storage for a context name (to facilitate debugging multi-context setups)
        DebugBreakInWindow = 0, -- Set to break in Begin() call.

        LocalizationTable = {},

        DebugLogBuf = ImGuiTextBuffer(),
        DebugLogLines = { "" }, -- [Luau] upstream DebugLogIndex: Lua array of complete lines (without '\n'), last one being filled
        DebugLogFlags = bitOr(ImGuiDebugLogFlags.EventError, ImGuiDebugLogFlags.OutputToTTY),
        DebugFlashStyleColorIdx = ImGuiCol.COUNT, -- (Keep close to ColorStack to share cache line)
        DebugBeginReturnValueCullDepth = -1, -- Cycle between 0..9 then wrap around.
        DebugLocateId = 0, -- Storage for DebugLocateItemOnHover() feature: this is read by ItemAdd() so we keep it in a hot/cached location
        DebugLogAutoDisableFlags = ImGuiDebugLogFlags.None,
        DebugLogAutoDisableFrames = 0,
        DebugLocateFrames = 0, -- For DebugLocateItemOnHover(). This is used together with DebugLocateId which is in a hot/cached spot above.
        DebugItemPickerActive = false, -- Item picker is active (started with DebugStartItemPicker())
        DebugItemPickerMouseButton = ImGuiMouseButton.Left,
        DebugItemPickerBreakId = 0, -- Will call IM_DEBUG_BREAK() when encountering this ID
        DebugFlashStyleColorTime = 0.0,
        DebugFlashStyleColorBackup = ImVec4(0, 0, 0, 0),
        -- Same as DebugBreakClearData(). Those fields are scattered in their respective subsystem to stay in hot-data locations
        DebugBreakInLocateId = false, -- Debug break in ItemAdd() call for g.DebugLocateId.
        DebugBreakKeyChord = ImGuiKey.Pause, -- = ImGuiKey_Pause
        DebugBreakInShortcutRouting = ImGuiKey.None, -- Set to break in SetShortcutRouting()/Shortcut() calls.
        DebugBreakCallback = nil, -- [Luau] fun(ctx): called by IM_DEBUG_BREAK() (Lua can't break into a debugger)

        DebugMetricsConfig = ImGuiMetricsConfig(),
        DebugItemPathQuery = ImGuiDebugItemPathQuery(),
        DebugIDStackTool = ImGuiIDStackTool(),
        DebugHookIdInfoId = 0, -- Will call core hooks: DebugHookIdInfo() from GetID functions, used by ID Stack Tool
        DebugAllocInfo = ImGuiDebugAllocInfo(),

        --- Misc
        FramerateSecPerFrame = {}, -- size = 60
        FramerateSecPerFrameIdx = 0,
        FramerateSecPerFrameCount = 0,
        FramerateSecPerFrameAccum = 0,

        WantCaptureMouseNextFrame = -1, -- Explicit capture override via SetNextFrameWantCaptureMouse()/SetNextFrameWantCaptureKeyboard(). Default to -1.
        WantCaptureKeyboardNextFrame = -1, -- "
        WantTextInputNextFrame = -1, -- Copied in EndFrame() from g.PlatformImeData.WantTextInput. Needs to be set for some backends (SDL3) to emit character inputs.
        TempBuffer = ImVector(), -- Temporary text buffer

        -- Tables (imgui_tables.lua)
        CurrentTable = nil,
        DebugBreakInTable = 0, -- Set to break in BeginTable() call.
        TablesTempDataStacked = 0, -- Temporary table data size (because we leave previous instances undestructed, we generally don't use TablesTempData.Size)
        TablesTempData = ImVector(), -- Temporary table data (buffers reused/shared across instances, support nesting)
        Tables = ImPool(),                 -- ImPool<ImGuiTable>, 0-based indices (imgui_tables.lua)
        TablesLastTimeActive = ImVector(), -- [table_idx + 1] = float
        DrawChannelsTempMergeBuffer = ImVector(),
        SettingsTables = ImVector(),       -- ImChunkStream<ImGuiTableSettings>: plain vector, SettingsOffset = 1-based index
    }

    for i = 0, 59 do this.FramerateSecPerFrame[i] = 0 end

    this.IO.Fonts = (shared_font_atlas ~= nil) and shared_font_atlas or ImFontAtlas()
    if shared_font_atlas == nil then
        this.IO.Fonts.OwnerContext = this
    end

    for i = 0, ImGuiKey.NamedKey_COUNT - 1 do
        this.KeysOwnerData[i] = ImGuiKeyOwnerData()
    end

    this.IO.Ctx = this
    this.InputTextState.Ctx = this

    ImVec2_Copy(this.PlatformImeDataPrev.InputPos, ImVec2(-1.0, -1.0))

    return this
end

-------------------------------------------------------------------------------
-- [SECTION] Settings support
-------------------------------------------------------------------------------

-- Windows data saved in imgui.ini file
--- @class ImGuiWindowSettings
--- @field ID           int     # Window ID
--- @field Pos          ImVec2  # Window position
--- @field Size         ImVec2  # Window size
--- @field Collapsed    bool    # Whether window is collapsed
--- @field IsChild      bool    # Whether window is a child window
--- @field WantApply    bool    # Set when loaded from .ini data
--- @field WantDelete   bool    # Set to invalidate/delete the settings entry
--- @field Name         string  # Window name
MT.ImGuiWindowSettings = {}
MT.ImGuiWindowSettings.__index = MT.ImGuiWindowSettings

function MT.ImGuiWindowSettings:GetName()
    return self.Name
end

function ImGuiWindowSettings()
    return setmetatable({
        ID           = 0,
        Pos          = ImVec2(0, 0), -- NB: Settings position are stored RELATIVE to the viewport! Whereas runtime ones are absolute positions.
        Size         = ImVec2(0, 0),
        Collapsed    = false,
        IsChild      = false,
        WantApply    = false, -- Set when loaded from .ini data (to enable merging/loading .ini data into an already running context)
        WantDelete   = false, -- Set to invalidate/delete the settings entry
        Name         = "",
        ViewportId   = 0,
        ViewportPos  = ImVec2(0, 0),
        DockId       = 0, -- ID of last known DockNode (even if the DockNode is invisible because it has only 1 active window), or 0 if none.
        DockOrder    = -1, -- Order of the last time the window was visible within its DockNode. This is used to reorder windows that are reappearing on the same frame. Same value between windows that were active and windows that were none are possible.
        ClassId      = 0, -- ID of window class if specified
        LastUsedDate = 0, -- [Luau] stored unpacked (YYYYMMDD int, 0 = invalid) instead of ImGuiPackedDate
    }, MT.ImGuiWindowSettings)
end

--- @class ImGuiSettingsCleanupArgs
function ImGuiSettingsCleanupArgs()
    return {
        TypeHashFilter = 0, -- Set to restrict cleanup to a given .ini type, e.g. == ImHashStr("Window"), ImHashStr("Table"). Otherwise every types supporting Cleanup will be affected.
        DiscardOlderThanMonths = 0, -- Enable to discard entries older than XX months.
        DiscardWhenMissingDate = false, -- Enable to discard entries missing a date.
        DiscardAll = false, -- Enable to discard all entries = same as calling ClearIniSettings() except it may be filtered.
        SetCurrentSessionDateToAll = false, -- Enable to write current SessionDate to all supporting entries. // Let us know in #9460 if you use this.
        SetCurrentSessionDateWhenMissingDate = false, -- Enable to write current SessionDate to all supporting entries missing a date. // Let us know in #9460 if you use this.
        _DiscardOlderThanDate = 0, -- [Internal]
    }
end

-- Simple column measurement, currently used for MenuItem() only.. This is very short-sighted/throw-away code and NOT a generic helper.
--- @class ImGuiMenuColumns
--- @field TotalWidth     ImU32
--- @field NextTotalWidth ImU32
--- @field Spacing        ImU16
--- @field OffsetIcon     ImU16   # Always zero for now
--- @field OffsetLabel    ImU16   # Offsets are locked in Update()
--- @field OffsetShortcut ImU16
--- @field OffsetMark     ImU16
--- @field Widths         ImU16[] # Width of: Icon, Label, Shortcut, Mark (accumulators for current frame)
MT.ImGuiMenuColumns = {}
MT.ImGuiMenuColumns.__index = MT.ImGuiMenuColumns

--- @return ImGuiMenuColumns
local function ImGuiMenuColumns()
    return setmetatable({
        TotalWidth     = 0,
        NextTotalWidth = 0,
        Spacing        = 0,
        OffsetIcon     = 0, -- Always zero for now
        OffsetLabel    = 0, -- Offsets are locked in Update()
        OffsetShortcut = 0,
        OffsetMark     = 0,
        Widths         = {0, 0, 0, 0} -- Width of:   Icon, Label, Shortcut, Mark  (accumulators for current frame)
    }, MT.ImGuiMenuColumns)
end

-------------------------------------------------------------------------------
-- [SECTION] ImGuiWindowTempData, ImGuiWindow
-------------------------------------------------------------------------------

-- Transient per-window data, reset at the beginning of the frame. This used to be called ImGuiDrawContext, hence the DC variable name in ImGuiWindow.
-- (That's theory, in practice the delimitation between ImGuiWindow and ImGuiWindowTempData is quite tenuous and could be reconsidered..)
--- @class ImGuiWindowTempData
--- @field CursorPos                     ImVec2
--- @field CursorPosPrevLine             ImVec2
--- @field CursorStartPos                ImVec2
--- @field CursorMaxPos                  ImVec2
--- @field IdealMaxPos                   ImVec2
--- @field CurrLineSize                  ImVec2
--- @field PrevLineSize                  ImVec2
--- @field CurrLineTextBaseOffset        float
--- @field PrevLineTextBaseOffset        float
--- @field IsSameLine                    bool
--- @field IsSetPos                      bool
--- @field Indent                        ImVec1
--- @field ColumnsOffset                 ImVec1
--- @field GroupOffset                   ImVec1
--- @field CursorStartPosLossyness       ImVec2
--- @field TextWrapPos                   float
--- @field TextWrapPosStack              ImVector
--- @field MenuBarAppending              bool
--- @field MenuBarOffset                 ImVec2
--- @field MenuColumns                   ImGuiMenuColumns
--- @field TreeDepth                     int
--- @field TreeHasStackDataDepthMask     ImU32
--- @field TreeRecordsClippedNodesY2Mask ImU32
--- @field ChildWindows                  ImVector<ImGuiWindow>
--- @field LayoutType                    ImGuiLayoutType

--- @return ImGuiWindowTempData
--- @nodiscard
local function ImGuiWindowTempData()
    return {
        DockTabItemStatusFlags = 0,
        DockTabItemRect = ImRect(),
        CursorPos         = ImVec2(), -- Current emitting position, in absolute coordinates.
        CursorPosPrevLine = ImVec2(),
        CursorStartPos    = ImVec2(), -- Initial position after Begin(), generally ~ window position + WindowPadding.
        CursorMaxPos      = ImVec2(), -- Used to implicitly calculate ContentSize at the beginning of next frame, for scrolling range and auto-resize. Always growing during the frame.
        IdealMaxPos       = ImVec2(), -- Used to implicitly calculate ContentSizeIdeal at the beginning of next frame, for auto-resize only. Always growing during the frame.
        CurrLineSize      = ImVec2(),
        PrevLineSize      = ImVec2(),

        CurrLineTextBaseOffset = 0, -- Baseline offset (0.0 by default on a new line, generally == style.FramePadding.y when a framed item has been added).
        PrevLineTextBaseOffset = 0,

        IsSameLine = false,
        IsSetPos = false,
        NavLayersActiveMask = 0, NavLayersActiveMaskNext = 0, -- Which layers have been written to (result from previous frame)

        Indent                  = ImVec1(), -- Indentation / start position from left of window (increased by TreePush/TreePop, etc.)
        ColumnsOffset           = ImVec1(), -- Offset to the current column (if ColumnsCurrent > 0). FIXME: This and the above should be a stack to allow use cases like Tree.Column.Tree. Need revamp columns API.
        GroupOffset             = ImVec1(),
        CursorStartPosLossyness = ImVec2(), -- Record the loss of precision of CursorStartPos due to really large scrolling amount. This is used by clipper to compensate and fix the most common use case of large scroll area.

        ItemWidth = 0, -- Current item width (>0.0: width in pixels, <0.0: align xx pixels to the right of window).
        ItemWidthDefault = 0,
        TextWrapPos = 0, -- Current text wrap pos.
        ItemWidthStack = ImVector(), -- Store item widths to restore (attention: .back() is not == ItemWidth)
        TextWrapPosStack = ImVector(), -- Store text wrap pos to restore (attention: .back() is not == TextWrapPos)

        MenuBarAppending = false, -- FIXME: Remove this
        MenuBarOffset = ImVec2(), -- MenuBarOffset.x is sort of equivalent of a per-layer CursorPos.x, saved/restored as we switch to the menu bar. The only situation when MenuBarOffset.y is > 0 if when (SafeAreaPadding.y > FramePadding.y), often used on TVs.
        MenuColumns = ImGuiMenuColumns(), -- Simplified columns storage for menu items measurement
        TreeDepth = 0, -- Current tree depth.
        TreeHasStackDataDepthMask = nil, -- Store whether given depth has ImGuiTreeNodeStackData data. Could be turned into a ImU64 if necessary. Sync any changes with TREE_NODE_MAX_DEPTH/TREE_NODE_GET_DEPTH_MASK!
        TreeRecordsClippedNodesY2Mask = nil, -- Store whether we should keep recording Y2. Cleared when passing clip max. Equivalent TreeHasStackDataDepthMask value should always be set.

        ChildWindows = ImVector(),
        CurrentTableIdx = -1,  -- 0-based index into g.Tables, -1 if none
        CurrentColumns = nil,  -- ImGuiOldColumns (legacy Columns API)
        StateStorage = nil, -- Current persistent per-window storage (store e.g. tree node open/close state)

        LayoutType = nil
    }
end

-- Storage for one window
--- @class ImGuiWindow
--- @field Ctx                                ImGuiContext
--- @field Name                               string
--- @field ID                                 ImGuiID
--- @field Flags                              ImGuiWindowFlags
--- @field FlagsPreviousFrame                 ImGuiWindowFlags
--- @field ChildFlags                         ImGuiChildFlags
--- @field WindowClass                        ImGuiWindowClass
--- @field Viewport                           ImGuiViewportP
--- @field ViewportId                         ImGuiID
--- @field ViewportPos                        ImVec2
--- @field ViewportAllowPlatformMonitorExtend int
--- @field Pos                                ImVec2
--- @field Size                               ImVec2
--- @field SizeFull                           ImVec2
--- @field ContentSize                        ImVec2
--- @field ContentSizeIdeal                   ImVec2
--- @field ContentSizeExplicit                ImVec2
--- @field Scroll                             ImVec2
--- @field IsExplicitChild                    bool
--- @field FocusOrder                         short               # 1-based, order within WindowsFocusOrder, altered when windows are focused. Can be -1 if invalid
--- @field IDStack                            ImVector<ImGuiID>
--- @field DC                                 ImGuiWindowTempData
--- @field OuterRectClipped                   ImRect
--- @field InnerRect                          ImRect
--- @field InnerClipRect                      ImRect
--- @field WorkRect                           ImRect
--- @field ParentWorkRect                     ImRect
--- @field ClipRect                           ImRect
--- @field ContentRegionRect                  ImRect
--- @field DrawList                           ImDrawList          # Points to DrawListInst
--- @field DrawListInst                       ImDrawList
--- @field ParentWindow?                      ImGuiWindow
--- @field RootWindow                         ImGuiWindow
--- @field RootWindowPopupTree                ImGuiWindow
--- @field RootWindowDockTree                 ImGuiWindow
--- @field StateStorage                       {[ImGuiID]: bool}
--- @field MemoryDrawListIdxCapacity          int
--- @field MemoryDrawListVtxCapacity          int
--- @field MemoryCompacted                    bool
MT.ImGuiWindow = {}
MT.ImGuiWindow.__index = MT.ImGuiWindow

-- We don't use g.FontSize because the window may be != g.CurrentWindow.
--- @return ImRect
--- @nodiscard
function MT.ImGuiWindow:Rect()
    return ImRect(self.Pos.x, self.Pos.y, self.Pos.x + self.Size.x, self.Pos.y + self.Size.y)
end

--- @return ImRect
--- @nodiscard
function MT.ImGuiWindow:TitleBarRect()
    return ImRect(self.Pos, ImVec2(self.Pos.x + self.SizeFull.x, self.Pos.y + self.TitleBarHeight))
end

--- @return ImRect
--- @nodiscard
function MT.ImGuiWindow:MenuBarRect()
    local y1 = self.Pos.y + self.TitleBarHeight
    return ImRect(self.Pos.x, y1, self.Pos.x + self.SizeFull.x, y1 + self.MenuBarHeight)
end

--- @return ImGuiWindow
--- @nodiscard
function ImGuiWindow(ctx, name)
    local this = {
        ID = 0, -- == ImHashStr(Name)

        MoveId = 0, -- == window.GetID("#MOVE")

        Ctx = ctx, -- Parent UI context (needs to be set explicitly by parent).
        Name = name, -- Window name

        Flags = 0,

        ChildFlags = 0, -- Set when window is a child window. See enum ImGuiChildFlags
        WindowClass = ImGuiWindowClass(), -- Advanced users only. Set with SetNextWindowClass()

        Pos = ImVec2(), -- Position (always rounded-up to nearest pixel)
        Size = ImVec2(), -- Current size (==SizeFull or collapsed title bar size)
        SizeFull = ImVec2(), -- Size when non collapsed

        Active = false, -- Set to true on Begin(), unless Collapsed
        WasActive = false,

        Collapsed = false, -- Set when collapsing window to become only title-bar

        SkipItems = false, -- Set when items can safely be all clipped (e.g. window not visible or collapsed)

        SkipRefresh = false, -- [EXPERIMENTAL] Reuse previous frame drawn contents, Begin() returns false.
        CacheSnap = nil, -- [Port] SetNextWindowCached(): state at the last refresh
        CacheSkipItemsBackup = nil,

        Appearing = false, -- Set during the frame where the window is appearing (or re-appearing)

        Hidden = false, -- Do not display (== HiddenFrames*** > 0)
        IsFallbackWindow = false, -- Set on the "Debug##Default" window.

        IsExplicitChild = nil, -- Set when passed _ChildWindow, left to false by BeginDocked()

        ResizeBorderHovered = -1, -- Current border being hovered for resize (-1: none, otherwise 0-3)
        ResizeBorderHeld = -1, -- Current border being held for resize (-1: none, otherwise 0-3)

        BeginCount = 0, -- Number of Begin() during the current frame (generally 0 or 1, 1+ if appending via multiple Begin/End pairs)
        BeginCountPreviousFrame = 0, -- Number of Begin() during the previous frame
        BeginOrderWithinParent = 0, -- Begin() order within immediate parent window, if we are a child window. Otherwise 0.
        BeginOrderWithinContext = 0, -- Begin() order within entire imgui context. This is mostly used for debugging submission order related issues.

        FocusOrder = nil, -- Order within WindowsFocusOrder[], altered when windows are focused.

        HiddenFramesCanSkipItems = 0, -- Hide the window for N frames
        HiddenFramesCannotSkipItems = 0, -- Hide the window for N frames while allowing items to be submitted so we can measure their size
        HiddenFramesForRenderOnly = 0, -- Hide the window until frame N at Render() time only

        DisableInputsFrames = 0, -- Disable window interactions for N frames

        WindowRounding = 0, -- Window rounding at the time of Begin(). May be clamped lower to avoid rendering artifacts with title bar, menu bar etc.
        WindowBorderSize = 1, -- Window border size at the time of Begin().

        TitleBarHeight = 0, MenuBarHeight = 0,

        DecoOuterSizeX1 = 0, DecoOuterSizeY1 = 0,
        DecoOuterSizeX2 = 0, DecoOuterSizeY2 = 0,
        DecoInnerSizeX1 = 0, DecoInnerSizeY1 = 0,

        ContentSize = ImVec2(), -- Size of contents/scrollable client area (calculated from the extents reach of the cursor) from previous frame. Does not include window decoration or window padding.
        ContentSizeIdeal = ImVec2(),
        ContentSizeExplicit = ImVec2(), -- Size of contents/scrollable client area explicitly request by the user via SetNextWindowContentSize().

        AutoFitFramesX = -1, AutoFitFramesY = -1,
        AutoFitOnlyGrows = false,

        HasCloseButton = true, -- Set when the window has a close button (p_open ~= nil)

        BgClickFlags = 0, -- Configure behavior of click+dragging on window bg/void or over items. Default sets by io.ConfigWindowsMoveFromTitleBarOnly. If you use this please report in #3379.

        SetWindowPosAllowFlags = 0, SetWindowSizeAllowFlags = 0, SetWindowCollapsedAllowFlags = 0, -- store acceptable condition flags for SetNextWindowPos() use.
        SetWindowPosVal = ImVec2(FLT_MAX, FLT_MAX), -- store window position when using a non-zero Pivot (position set needs to be processed when we know the window size)
        SetWindowPosPivot = ImVec2(FLT_MAX, FLT_MAX), -- store window pivot for positioning. ImVec2(0, 0) when positioning from top-left corner; ImVec2(0.5, 0.5) for centering; ImVec2(1, 1) for bottom right.

        SettingsOffset = -1, -- Offset into SettingsWindows[] (offsets are always valid as we only grow the array from the back)

        ScrollbarSizes = ImVec2(), -- Size taken by each scrollbars on their smaller axis. Pay attention! ScrollbarSizes.x == width of the vertical scrollbar, ScrollbarSizes.y = height of the horizontal scrollbar.
        Scroll = ImVec2(),

        ScrollbarX = false,
        ScrollbarY = false, -- Are scrollbars visible?
        ScrollMax = ImVec2(),
        ScrollTarget = ImVec2(FLT_MAX, FLT_MAX), -- target scroll position. stored as cursor position with scrolling canceled out, so the highest point is always 0.0. (FLT_MAX for no change)
        ScrollTargetCenterRatio = ImVec2(0.5, 0.5), -- 0.0 = scroll so that target position is at top, 0.5 = scroll so that target position is centered
        ScrollTargetEdgeSnapDist = ImVec2(), -- 0.0 = no snapping, >0.0 snapping threshold

        ScrollbarXStabilizeToggledHistory = 0, -- Used to stabilize scrollbar visibility in case of feedback loops

        DrawList = nil, -- == DrawListInst
        DrawListInst = ImDrawList(ctx.DrawListSharedData),

        RootWindow = nil, -- Point to ourself or first ancestor that is not a child window. Doesn't cross through popups/dock nodes.
        RootWindowPopupTree = nil, -- Point to ourself or first ancestor that is not a child window. Cross through popups parent<>child.
        RootWindowDockTree = nil, -- Point to ourself or first ancestor that is not a child window. Cross through dock nodes.

        ParentWindow = nil, -- If we are a child _or_ popup _or_ docked window, this is pointing to our parent. Otherwise nil.
        ParentWindowInBeginStack = nil,

        IDStack = ImVector(), -- ID stack. ID are hashes seeded with the value at the top of the stack. (In theory this should be in the TempData structure)

        ViewportAllowPlatformMonitorExtend = -1, -- Reset to -1 every frame (index is guaranteed to be valid between NewFrame..EndFrame), only used in the Appearing frame of a tooltip/popup to enforce clamping to a given monitor
        Viewport = nil, -- Always set in Begin(). Inactive windows may have a nil value here if their viewport was discarded.
        ViewportId = 0, -- We backup the viewport id (since the viewport may disappear or never be created if the window is inactive)
        ViewportPos = ImVec2(FLT_MAX, FLT_MAX), -- We backup the viewport position (since the viewport may disappear or never be created if the window is inactive)
        ViewportOwned = nil,

        DC = ImGuiWindowTempData(), -- Temporary per-window data, reset at the beginning of the frame. This used to be called ImGuiDrawContext, hence the "DC" variable name.

        OuterRectClipped  = ImRect(), -- == Window.Rect() just after setup in Begin(). == window.Rect() for root window.
        InnerRect         = ImRect(), -- Inner rectangle (omit title bar, menu bar, scroll bar)
        InnerClipRect     = ImRect(), -- == InnerRect shrunk by WindowPadding*0.5 on each side, clipped within viewport or parent clip rect.
        WorkRect          = ImRect(), -- Initially covers the whole scrolling region. Reduced by containers e.g columns/tables when active. Shrunk by WindowPadding*1.0 on each side. This is meant to replace ContentRegionRect over time (from 1.71+ onward).
        ParentWorkRect    = ImRect(), -- Backup of WorkRect before entering a container such as columns/tables. Used by e.g. SpanAllColumns functions to easily access. Stacked containers are responsible for maintaining this. -- FIXME-WORKRECT: Could be a stack?
        ContentRegionRect = ImRect(), -- FIXME: This is currently confusing/misleading. It is essentially WorkRect but not handling of scrolling. We currently rely on it as right/bottom aligned sizing operation need some size to rely on.

        ClipRect = ImRect(), -- Current clipping/scissoring rectangle, evolve as we are using PushClipRect(), etc. == DrawList.clip_rect_stack.back().

        LastFrameActive = -1, -- Last frame number the window was Active.
        LastFrameJustFocused = -1, -- Last frame number the window was made Focused.
        LastTimeActive = -1.0, -- Last timestamp the window was Active (using float as we don't need high precision there)

        StateStorage = {},
        ColumnsStorage = ImVector(), -- ImVector<ImGuiOldColumns>

        WriteAccessed = false, -- Set to true when any widget access the current window

        FontWindowScale = 1.0, -- User scale multiplier per-window, via SetWindowFontScale()
        FontWindowScaleParents = 1.0,

        HitTestHoleSize = ImVec2(), -- Define an optional rectangular hole where mouse will pass-through the window.

        NavLastChildNavWindow = nil, -- When going to the menu bar, we remember the child window we came from. (This could probably be made implicit if we kept g.Windows sorted by last focused including child window.)
        NavLastIds = {[0] = 0, [1] = 0}, -- FIXME: 1-based instead
        NavRectRel = {[0] = ImRect(), [1] = ImRect()}, -- Reference rectangle, in window relative space
        NavPreferredScoringPosRel = {[0] = ImVec2(), [1] = ImVec2()}, -- Preferred X/Y position updated when moving on a given axis, reset to FLT_MAX.
        NavRootFocusScopeId = 0 -- Focus Scope ID at the time of Begin()
    }

    this.DrawList = this.DrawListInst
    this.DrawList._OwnerName = name

    setmetatable(this, MT.ImGuiWindow)

    this.ID = ImHashStr(name)
    this.IDStack:push_back(this.ID)
    this.MoveId = this:GetID("#MOVE")
    this.TabId = this:GetID("#TAB") -- == window.GetID("#TAB")
    -- Docking
    this.ChildId = this.ChildId or 0 -- ID of corresponding item in parent window (for navigation to return from child window to parent window)
    this.SetWindowDockAllowFlags = 0 -- store acceptable condition flags for SetNextWindowDock() use.
    this.ParentWindowForFocusRoute = nil -- Set to manual link a window to its logical parent so that Shortcut() chain are honored (e.g. Tool linked to Document)
    this.DockIsActive = false -- When docking artifacts are actually visible. When this is set, DockNode is guaranteed to be != nil. ~~ (DockNode != nil) && (DockNode.Windows.Size > 1).
    this.DockNodeIsVisible = false
    this.DockTabIsVisible = false -- Is our window visible this frame? ~~ is the corresponding tab selected?
    this.DockTabWantClose = false
    this.DockOrder = -1 -- Order of the last time the window was visible within its DockNode. This is used to reorder windows that are reappearing on the same frame. Same value between windows that were active and windows that were none are possible.
    this.DockStyle = { Colors = {} }
    for i = 0, 8 do this.DockStyle.Colors[i] = 0 end
    this.DockNode = nil -- Which node are we docked into. Important: Prefer testing DockIsActive in many cases as this will still be set when the dock node is hidden.
    this.DockNodeAsHost = nil -- Which node are we owning (for parent windows)
    this.DockId = 0 -- Backup of last valid DockNode.ID, so single window remember their dock node id even when they are not bound any more

    return this
end

--- @class ImDrawDataBuilder
--- @field Layers     [ImVector<ImDrawList>?, ImVector<ImDrawList>?] # Pointers to global layers for: regular, tooltip. LayersP[0] is owned by DrawData.
--- @field LayerData1 ImVector<ImDrawList>

--- @return ImDrawDataBuilder
--- @nodiscard
local function ImDrawDataBuilder()
    return
    {
        Layers     = {nil, nil}, -- Pointers to global layers for: regular, tooltip. LayersP[0] is owned by DrawData.
        LayerData1 = ImVector()
    }
end

-------------------------------------------------------------------------------
-- [SECTION] Viewport support
-------------------------------------------------------------------------------

-- ImGuiViewport Private/Internals fields (cardinal sin: we are using inheritance!)
-- Every instance of ImGuiViewport is in fact a ImGuiViewportP.
--- @class ImGuiViewportP : ImGuiViewport
--- @field Window?                     ImGuiWindow
--- @field Idx                         int                      # Initial value = -1, then becomes 1-based index
--- @field LastFrameActive             int
--- @field LastFocusedStampCount       int
--- @field LastNameHash                ImGuiID
--- @field LastPos                     ImVec2
--- @field LastSize                    ImVec2
--- @field Alpha                       float
--- @field LastAlpha                   float
--- @field LastFocusedHadNavWindow     bool
--- @field PlatformMonitor             short
--- @field BgFgDrawListsLastFrameActive [int, int]              # 1-based
--- @field BgFgDrawListsLastTimeActive [int, int]               # 1-based
--- @field BgFgDrawLists               [ImDrawList, ImDrawList] # 1-based
--- @field DrawDataP                   ImDrawData
--- @field DrawDataBuilder             ImDrawDataBuilder
--- @field LastPlatformPos             ImVec2
--- @field LastPlatformSize            ImVec2
--- @field LastRendererSize            ImVec2
--- @field WorkInsetMin                ImVec2
--- @field WorkInsetMax                ImVec2
--- @field BuildWorkInsetMin           ImVec2
--- @field BuildWorkInsetMax           ImVec2
local IMGUI_VIEWPORT_P = {}
IMGUI_VIEWPORT_P.__index = IMGUI_VIEWPORT_P

setmetatable(IMGUI_VIEWPORT_P, {__index = MT.ImGuiViewport})

function IMGUI_VIEWPORT_P:ClearRequestFlags()
    self.PlatformRequestClose  = false
    self.PlatformRequestMove   = false
    self.PlatformRequestResize = false
end

-- Calculate work rect pos/size given a set of offset (we have 1 pair of offset for rect locked from last frame data, and 1 pair for currently building rect)
function IMGUI_VIEWPORT_P:CalcWorkRectPos(inset_min)
    return ImVec2(self.Pos.x + inset_min.x, self.Pos.y + inset_min.y)
end

function IMGUI_VIEWPORT_P:CalcWorkRectSize(inset_min, inset_max)
    return ImVec2(ImMax(0.0, self.Size.x - inset_min.x - inset_max.x), ImMax(0.0, self.Size.y - inset_min.y - inset_max.y))
end

-- Update public fields
function IMGUI_VIEWPORT_P:UpdateWorkRect()
    self.WorkPos = self:CalcWorkRectPos(self.WorkInsetMin)
    self.WorkSize = self:CalcWorkRectSize(self.WorkInsetMin, self.WorkInsetMax)
end

-- Helpers to retrieve ImRect (we don't need to store BuildWorkRect as every access tend to change it, hence the code asymmetry)
--- @nodiscard
function IMGUI_VIEWPORT_P:GetMainRect()
    return ImRect(self.Pos.x, self.Pos.y,
        self.Pos.x + self.Size.x,
        self.Pos.y + self.Size.y)
end

--- @nodiscard
function IMGUI_VIEWPORT_P:GetWorkRect()
    return ImRect(self.WorkPos.x, self.WorkPos.y,
        self.WorkPos.x + self.WorkSize.x,
        self.WorkPos.y + self.WorkSize.y)
end

--- @nodiscard
function IMGUI_VIEWPORT_P:GetBuildWorkRect()
    local pos = self:CalcWorkRectPos(self.BuildWorkInsetMin)
    local size = self:CalcWorkRectSize(self.BuildWorkInsetMin, self.BuildWorkInsetMax)
    return ImRect(pos.x, pos.y, pos.x + size.x, pos.y + size.y)
end

--- @return ImGuiViewportP
--- @nodiscard
function ImGuiViewportP()
    local this = setmetatable(ImGuiViewport(), IMGUI_VIEWPORT_P) --- @cast this ImGuiViewportP

    this.Window = nil -- Set when the viewport is owned by a window (and ImGuiViewportFlags.CanHostOtherWindows is NOT set)
    this.Idx = -1

    this.LastFrameActive       = -1 -- Last frame number this viewport was activated by a window
    this.LastFocusedStampCount = -1 -- Last stamp number from when a window hosted by this viewport was focused (by comparing this value between two viewport we have an implicit viewport z-order we use as fallback)
    this.LastNameHash          = 0
    this.LastPos               = ImVec2() -- ImGuiViewport() { memset(this, 0, sizeof(*this)); }
    this.LastSize              = ImVec2()

    this.Alpha     = 1.0 -- Window opacity (when dragging dockable windows/viewports we make them transparent)
    this.LastAlpha = 1.0

    this.LastFocusedHadNavWindow = false -- Instead of maintaining a LastFocusedWindow (which may harder to correctly maintain), we merely store weither NavWindow ~= nil last time the viewport was focused.
    this.PlatformMonitor = -1

    this.BgFgDrawListsLastFrameActive = {-1, -1} -- Last frame the background (1) and foreground (2) draw lists were used.
    this.BgFgDrawListsLastTimeActive = {-1, -1} -- Timestamps for Gc.
    this.BgFgDrawLists = {nil, nil} -- Convenience background [1] and foreground [2] draw lists. We use them to draw software mouser cursor when io.MouseDrawCursor is set and to draw most debug overlays.
    this.DrawDataP = ImDrawData()
    this.DrawDataBuilder = ImDrawDataBuilder() -- Temporary data while building final ImDrawData

    this.LastPlatformPos  = ImVec2(FLT_MAX, FLT_MAX)
    this.LastPlatformSize = ImVec2(FLT_MAX, FLT_MAX)
    this.LastRendererSize = ImVec2(FLT_MAX, FLT_MAX)

    -- Per-viewport work area
    -- - Insets are >= 0.0 values, distance from viewport corners to work area.
    -- - BeginMainMenuBar() and DockspaceOverViewport() tend to use work area to avoid stepping over existing contents.
    -- - Generally 'safeAreaInsets' in iOS land, 'DisplayCutout' in Android land.
    this.WorkInsetMin = ImVec2(0, 0) -- Work Area inset locked for the frame. GetWorkRect() always fits within GetMainRect().
    this.WorkInsetMax = ImVec2(0, 0) -- "
    this.BuildWorkInsetMin = ImVec2(0, 0) -- Work Area inset accumulator for current frame, to become next frame's WorkInset
    this.BuildWorkInsetMax = ImVec2(0, 0) -- "

    return this
end

-------------------------------------------------------------------------------
-- [SECTION] ImFontLoader
-------------------------------------------------------------------------------

-- Hooks and storage for a given font backend.
-- This structure is likely to evolve as we add support for incremental atlas updates.
-- Conceptually this could be public, but API is still going to be evolve.
--- @class ImFontLoader
--- @field Name                       string
--- @field LoaderInit?                fun(atlas: ImFontAtlas): bool
--- @field LoaderShutdown?            fun(atlas: ImFontAtlas)
--- @field FontSrcInit?               fun(atlas: ImFontAtlas, src: ImFontConfig): bool
--- @field FontSrcDestroy?            fun(atlas: ImFontAtlas, src: ImFontConfig)
--- @field FontSrcContainsGlyph?      fun(atlas: ImFontAtlas, src: ImFontConfig, codepoint: ImWchar): bool
--- @field FontBakedInit?             fun(atlas: ImFontAtlas, src: ImFontConfig, baked: ImFontBaked, loader_data_for_baked_src?: any): bool
--- @field FontBakedDestroy?          fun(atlas: ImFontAtlas, src: ImFontConfig, baked: ImFontBaked, loader_data_for_baked_src?: any)
--- @field FontBakedLoadGlyph         fun(atlas: ImFontAtlas, src: ImFontConfig, baked: ImFontBaked, loader_data_for_baked_src?: any, codepoint: ImWchar, out_glyph?: ImFontGlyph, advance_x?: float): bool, float?
--- @field FontBakedSrcLoaderDataSize unsigned_int
MT.ImFontLoader = {}
MT.ImFontLoader.__index = MT.ImFontLoader

--- @return ImFontLoader
--- @nodiscard
function ImFontLoader()
    --- @type ImFontLoader
    local this = setmetatable({}, MT.ImFontLoader)

    this.Name                 = nil
    this.LoaderInit           = nil
    this.LoaderShutdown       = nil
    this.FontSrcInit          = nil
    this.FontSrcDestroy       = nil
    this.FontSrcContainsGlyph = nil
    this.FontBakedInit        = nil
    this.FontBakedDestroy     = nil
    this.FontBakedLoadGlyph   = nil -- Required

    -- Size of backend data, Per Baked * Per Source. Buffers are managed by core to avoid excessive allocations.
    -- FIXME: At this point the two other types of buffers may be managed by core to be consistent?
    this.FontBakedSrcLoaderDataSize = 0

    return this
end

-------------------------------------------------------------------------------
-- [SECTION] ImFontAtlas internal API
-------------------------------------------------------------------------------

-- Packed rectangle lookup entry (we need an indirection to allow removing/reordering rectangles)
-- User are returned ImFontAtlasRectId values which are meant to be persistent.
-- We handle this with an indirection. While Rects[] may be in theory shuffled, compacted etc., RectsIndex[] cannot it is keyed by ImFontAtlasRectId.
-- RectsIndex[] is used both as an index into Rects[] and an index into itself. This is basically a free-list. See ImFontAtlasBuildAllocRectIndexEntry() code.
-- Having this also makes it easier to e.g. sort rectangles during repack.
--- @class ImFontAtlasRectEntry
--- @field TargetIndex int          # 0-based! When IsUsed = true, TargetIndex = this rect's index in Rects; IsUsed = false, TargetIndex = the next unused RectsIndex entry's index
--- @field Generation  unsigned_int # How many times this entry is reused
--- @field IsUsed      bool

--- @return ImFontAtlasRectEntry
--- @nodiscard
function ImFontAtlasRectEntry()
    return {
        TargetIndex = 0,
        Generation  = 0,
        IsUsed      = false
    }
end

-- Refer to ImFontAtlasPackGetRect() to better understand how this works.
local ImFontAtlasRectId_IndexMask_       = 0x0007FFFF -- 20-bits signed: index to access builder.RectsIndex[].
local ImFontAtlasRectId_GenerationMask_  = 0x3FF00000 -- 10-bits: entry generation, so each ID is unique and get can safely detected old identifiers.
local ImFontAtlasRectId_GenerationShift_ = 20

--- @param id ImFontAtlasRectId # Expects 0-based!
--- @return int                 # 0-based!
function ImFontAtlasRectId_GetIndex(id) return bitAnd(id, ImFontAtlasRectId_IndexMask_) end

--- @param id ImFontAtlasRectId # Expects 0-based!
--- @return unsigned_int
function ImFontAtlasRectId_GetGeneration(id) return bitRShift(bitAnd(id, ImFontAtlasRectId_GenerationMask_), ImFontAtlasRectId_GenerationShift_) end

--- @param index_idx int      # Expects 0-based!
--- @param gen_idx int
--- @return ImFontAtlasRectId # 0-based!
function ImFontAtlasRectId_Make(index_idx, gen_idx)
    IM_ASSERT(index_idx >= 0 and index_idx <= ImFontAtlasRectId_IndexMask_ and gen_idx <= bitRShift(ImFontAtlasRectId_GenerationMask_, ImFontAtlasRectId_GenerationShift_))
    return bitOr(index_idx, bitLShift(gen_idx, ImFontAtlasRectId_GenerationShift_))
end

-- Data available to potential texture post-processing functions
--- @class ImFontAtlasPostProcessData
--- @field FontAtlas   ImFontAtlas
--- @field Font        ImFont
--- @field FontSrc     ImFontConfig
--- @field FontBaked   ImFontBaked
--- @field Glyph       ImFontGlyph
--- @field Pixels      unsigned_char[]
--- @field _PixelsBase int             # LUA: in cpp code the `Pixels` is a pointer. we can do this to avoid creating another custom structure to mimic it
--- @field Format      ImTextureFormat
--- @field Pitch       int
--- @field Width       int
--- @field Height      int

--- @param atlas       ImFontAtlas
--- @param font        ImFont
--- @param font_src    ImFontConfig
--- @param font_baked  ImFontBaked
--- @param glyph       ImFontGlyph
--- @param pixels      unsigned_char[]
--- @param pixels_base int
--- @param format      ImTextureFormat
--- @param pitch       int
--- @param width       int
--- @param height      int
--- @return ImFontAtlasPostProcessData
--- @nodiscard
function ImFontAtlasPostProcessData(atlas, font, font_src, font_baked, glyph, pixels, pixels_base, format, pitch, width, height)
    return {
        FontAtlas = atlas,
        Font      = font,
        FontSrc   = font_src,
        FontBaked = font_baked,
        Glyph     = glyph,

        -- Pixel data
        Pixels = pixels,
        _PixelsBase = pixels_base,
        Format = format,
        Pitch  = pitch,
        Width  = width,
        Height = height,
    }
end

-------------------------------------------------------------------------------
-- [SECTION] Inputs support
-------------------------------------------------------------------------------

--- @enum ImGuiInputSource
ImGuiInputSource = {
    None     = 0,
    Mouse    = 1, -- Note: may be Mouse or TouchScreen or Pen. See io.MouseSource to distinguish them.
    Keyboard = 2,
    Gamepad  = 3,
    COUNT    = 4
}

--- @class ImGuiInputEventMousePos
--- @field PosX float
--- @field PosY float
--- @field MouseSource ImGuiMouseSource

--- @return ImGuiInputEventMousePos
--- @nodiscard
function ImGuiInputEventMousePos()
    return { PosX = 0, PosY = 0, MouseSource = ImGuiMouseSource.Mouse }
end

--- @class ImGuiInputEventMouseButton
--- @field Button int
--- @field Down   bool
--- @field MouseSource ImGuiMouseSource

--- @return ImGuiInputEventMouseButton
--- @nodiscard
function ImGuiInputEventMouseButton()
    return { Button = 0, Down = false, MouseSource = ImGuiMouseSource.Mouse }
end

--- @class ImGuiInputEventMouseWheel
--- @field WheelX float
--- @field WheelY float
--- @field MouseSource ImGuiMouseSource

--- @return ImGuiInputEventMouseWheel
--- @nodiscard
function ImGuiInputEventMouseWheel()
    return { WheelX = 0, WheelY = 0, MouseSource = ImGuiMouseSource.Mouse }
end

--- @class ImGuiInputEventKey
--- @field Key         ImGuiKey
--- @field Down        bool
--- @field AnalogValue float

--- @return ImGuiInputEventKey
--- @nodiscard
function ImGuiInputEventKey()
    return { Key = 0, Down = false, AnalogValue = 0 }
end

--- @class ImGuiInputEventText
--- @field Char unsigned_int

--- @return ImGuiInputEventText
--- @nodiscard
function ImGuiInputEventText()
    return { Char = nil }
end

--- @class ImGuiInputEventAppFocused
--- @field Focused bool

--- @return ImGuiInputEventAppFocused
--- @nodiscard
function ImGuiInputEventAppFocused()
    return { Focused = nil }
end

--- @class ImGuiInputEventMouseViewport
--- @field HoveredViewportID ImGuiID

--- @return ImGuiInputEventMouseViewport
--- @nodiscard
function ImGuiInputEventMouseViewport()
    return { HoveredViewportID = 0 }
end

--- @class ImGuiInputEvent

--- @return ImGuiInputEvent
--- @nodiscard
function ImGuiInputEvent()
    return {
        Type    = 0,
        Source  = 0,
        EventId = 0, -- Unique, sequential increasing integer to identify an event (if you need to correlate them to other data).

        -- union
        MousePos      = nil, -- if Type == ImGuiInputEventType.MousePos
        MouseWheel    = nil, -- if Type == ImGuiInputEventType.MouseWheel
        MouseButton   = nil, -- if Type == ImGuiInputEventType.MouseButton
        MouseViewport = nil, -- if Type == ImGuiInputEventType.MouseViewport
        Key           = nil, -- if Type == ImGuiInputEventType.Key
        Text          = nil, -- if Type == ImGuiInputEventType.Text
        AppFocused    = nil, -- if Type == ImGuiInputEventType.Focus
    }
end

-- [Internal] Key ranges
ImGuiKey_LegacyNativeKey_BEGIN = 0
ImGuiKey_LegacyNativeKey_END = 512
ImGuiKey_Keyboard_BEGIN = ImGuiKey.NamedKey_BEGIN
ImGuiKey_Keyboard_END   = ImGuiKey.GamepadStart
ImGuiKey_Gamepad_BEGIN  = ImGuiKey.GamepadStart
ImGuiKey_Gamepad_END    = ImGuiKey.GamepadRStickDown + 1
ImGuiKey_Mouse_BEGIN    = ImGuiKey.MouseLeft
ImGuiKey_Mouse_END      = ImGuiKey.MouseWheelY + 1
ImGuiKey_Aliases_BEGIN  = ImGuiKey_Mouse_BEGIN
ImGuiKey_Aliases_END    = ImGuiKey_Mouse_END

-- [Internal] Named shortcuts for Navigation
ImGuiKey.NavKeyboardTweakSlow = ImGuiMod_Ctrl
ImGuiKey.NavKeyboardTweakFast = ImGuiMod_Shift
ImGuiKey.NavGamepadTweakSlow = ImGuiKey.GamepadL1
ImGuiKey.NavGamepadTweakFast = ImGuiKey.GamepadR1
ImGuiKey.NavGamepadMenu = ImGuiKey.GamepadFaceLeft -- Toggle menu layer. Hold to enable Windowing.
ImGuiKey.NavGamepadContextMenu = ImGuiKey.GamepadFaceUp -- Open context menu (same as Shift+F10)

--- @enum ImGuiInputEventType
ImGuiInputEventType = {
    None          = 0,
    MousePos      = 1,
    MouseWheel    = 2,
    MouseButton   = 3,
    MouseViewport = 4,
    Key           = 5,
    Text          = 6,
    Focus         = 7,
    COUNT         = 8
}

-- Extend ImGuiInputFlags
-- Flags for extended versions of IsKeyPressed(), IsMouseClicked(), Shortcut(), SetKeyOwner(), SetItemKeyOwner()
-- Don't mistake with ImGuiInputTextFlags! (which is for ImGui.InputText() function)

-- Flags for IsKeyPressed(), IsKeyChordPressed(), IsMouseClicked(), Shortcut()
-- - Repeat mode: Repeat rate selection
ImGuiInputFlags.RepeatRateDefault                = bitLShift(1, 1) -- Repeat rate: Regular (default)
ImGuiInputFlags.RepeatRateNavMove                = bitLShift(1, 2) -- Repeat rate: Fast
ImGuiInputFlags.RepeatRateNavTweak               = bitLShift(1, 3) -- Repeat rate: Faster
-- - Repeat mode: Specify when repeating key pressed can be interrupted.
-- - In theory ImGuiInputFlags.RepeatUntilOtherKeyPress may be a desirable default, but it would break too many behavior so everything is opt-in.
ImGuiInputFlags.RepeatUntilRelease               = bitLShift(1, 4) -- Stop repeating when released (default for all functions except Shortcut). This only exists to allow overriding Shortcut() default behavior.
ImGuiInputFlags.RepeatUntilKeyModsChange         = bitLShift(1, 5) -- Stop repeating when released OR if keyboard mods are changed (default for Shortcut)
ImGuiInputFlags.RepeatUntilKeyModsChangeFromNone = bitLShift(1, 6) -- Stop repeating when released OR if keyboard mods are leaving the None state. Allows going from Mod+Key to Key by releasing Mod.
ImGuiInputFlags.RepeatUntilOtherKeyPress         = bitLShift(1, 7) -- Stop repeating when released OR if any other keyboard key is pressed during the repeat

-- Flags for SetKeyOwner(), SetItemKeyOwner()
-- - Locking key away from non-input aware code. Locking is useful to make input-owner-aware code steal keys from non-input-owner-aware code. If all code is input-owner-aware locking would never be necessary.
ImGuiInputFlags.LockThisFrame                    = bitLShift(1, 20) -- Further accesses to key data will require EXPLICIT owner ID (ImGuiKeyOwner_Any/0 will NOT accepted for polling). Cleared at end of frame.
ImGuiInputFlags.LockUntilRelease                 = bitLShift(1, 21) -- Further accesses to key data will require EXPLICIT owner ID (ImGuiKeyOwner_Any/0 will NOT accepted for polling). Cleared when the key is released or at end of each frame if key is released.

-- - Condition for SetItemKeyOwner()
ImGuiInputFlags.CondHovered                      = bitLShift(1, 22) -- Only set if item is hovered (default to both)
ImGuiInputFlags.CondActive                       = bitLShift(1, 23) -- Only set if item is active (default to both)

ImGuiInputFlags.CondDefault_                   = bitOr(ImGuiInputFlags.CondHovered, ImGuiInputFlags.CondActive)
-- [Internal] Mask of which function support which flags
ImGuiInputFlags.RepeatRateMask_                = bitOr(ImGuiInputFlags.RepeatRateDefault, ImGuiInputFlags.RepeatRateNavMove, ImGuiInputFlags.RepeatRateNavTweak)
ImGuiInputFlags.RepeatUntilMask_               = bitOr(ImGuiInputFlags.RepeatUntilRelease, ImGuiInputFlags.RepeatUntilKeyModsChange, ImGuiInputFlags.RepeatUntilKeyModsChangeFromNone, ImGuiInputFlags.RepeatUntilOtherKeyPress)
ImGuiInputFlags.RepeatMask_                    = bitOr(ImGuiInputFlags.Repeat, ImGuiInputFlags.RepeatRateMask_, ImGuiInputFlags.RepeatUntilMask_)
ImGuiInputFlags.CondMask_                      = bitOr(ImGuiInputFlags.CondHovered, ImGuiInputFlags.CondActive)
ImGuiInputFlags.RouteTypeMask_                 = bitOr(ImGuiInputFlags.RouteActive, ImGuiInputFlags.RouteFocused, ImGuiInputFlags.RouteGlobal, ImGuiInputFlags.RouteAlways)
ImGuiInputFlags.RouteOptionsMask_              = bitOr(ImGuiInputFlags.RouteOverFocused, ImGuiInputFlags.RouteOverActive, ImGuiInputFlags.RouteUnlessBgFocused, ImGuiInputFlags.RouteFromRootWindow)
ImGuiInputFlags.SupportedByIsKeyPressed        = ImGuiInputFlags.RepeatMask_
ImGuiInputFlags.SupportedByIsMouseClicked      = ImGuiInputFlags.Repeat
ImGuiInputFlags.SupportedByShortcut            = bitOr(ImGuiInputFlags.RepeatMask_, ImGuiInputFlags.RouteTypeMask_, ImGuiInputFlags.RouteOptionsMask_)
ImGuiInputFlags.SupportedBySetNextItemShortcut = bitOr(ImGuiInputFlags.RepeatMask_, ImGuiInputFlags.RouteTypeMask_, ImGuiInputFlags.RouteOptionsMask_, ImGuiInputFlags.Tooltip)
ImGuiInputFlags.SupportedBySetKeyOwner         = bitOr(ImGuiInputFlags.LockThisFrame, ImGuiInputFlags.LockUntilRelease)
ImGuiInputFlags.SupportedBySetItemKeyOwner     = bitOr(ImGuiInputFlags.SupportedBySetKeyOwner, ImGuiInputFlags.CondMask_)

--- @enum ImGuiAxis # can be used to index ImVec2
ImGuiAxis =
{
    None = 0,
    X    = 1,
    Y    = 2
}

--- @enum ImGuiPlotType
ImGuiPlotType =
{
    Lines     = 0,
    Histogram = 1
}

-------------------------------------------------------------------------------
-- [SECTION] Navigation support
-------------------------------------------------------------------------------

--- @enum ImGuiActivateFlags
ImGuiActivateFlags = {
    None               = 0,
    PreferInput        = bitLShift(1, 0), -- Favor activation that requires keyboard text input (e.g. for Slider/Drag). Default for Enter key.
    PreferTweak        = bitLShift(1, 1), -- Favor activation for tweaking with arrows or gamepad (e.g. for Slider/Drag). Default for Space key and if keyboard is not used.
    TryToPreserveState = bitLShift(1, 2), -- Request widget to preserve state if it can (e.g. InputText will try to preserve cursor/selection)
    FromTabbing        = bitLShift(1, 3), -- Activation requested by a tabbing request (ImGuiNavMoveFlags.IsTabbing)
    FromShortcut       = bitLShift(1, 4), -- Activation requested by an item shortcut via SetNextItemShortcut() function.
    FromFocusApi       = bitLShift(1, 5)  -- Activation requested by an api request (ImGuiNavMoveFlags.FocusApi)
}

-- Early work-in-progress API for ScrollToItem()
-- FIXME: Missing flags to request making both edges visible when possible.
--- @enum ImGuiScrollFlags
ImGuiScrollFlags = {
    None               = 0,
    KeepVisibleEdgeX   = bitLShift(1, 0), -- If item is not visible: scroll as little as possible on X axis to bring item back into view [default for X axis]
    KeepVisibleEdgeY   = bitLShift(1, 1), -- If item is not visible: scroll as little as possible on Y axis to bring item back into view [default for Y axis for windows that are already visible]
    KeepVisibleCenterX = bitLShift(1, 2), -- If item is not visible: scroll to make the item centered on X axis [rarely used]
    KeepVisibleCenterY = bitLShift(1, 3), -- If item is not visible: scroll to make the item centered on Y axis
    AlwaysCenterX      = bitLShift(1, 4), -- Always center the result item on X axis [rarely used]
    AlwaysCenterY      = bitLShift(1, 5), -- Always center the result item on Y axis [default for Y axis for appearing window)
    NoScrollParent     = bitLShift(1, 6), -- Disable forwarding scrolling to parent window if required to keep item/rect visible (only scroll window the function was applied to).
}

ImGuiScrollFlags.MaskX_ = bitOr(ImGuiScrollFlags.KeepVisibleEdgeX, ImGuiScrollFlags.KeepVisibleCenterX, ImGuiScrollFlags.AlwaysCenterX)
ImGuiScrollFlags.MaskY_ = bitOr(ImGuiScrollFlags.KeepVisibleEdgeY, ImGuiScrollFlags.KeepVisibleCenterY, ImGuiScrollFlags.AlwaysCenterY)

-- Stacked storage data for BeginGroup()/EndGroup()
--- @class ImGuiGroupData
--- @field WindowID                          ImGuiID
--- @field BackupCursorPos                   ImVec2
--- @field BackupCursorMaxPos                ImVec2
--- @field BackupCursorPosPrevLine           ImVec2
--- @field BackupIndent                      ImVec1
--- @field BackupGroupOffset                 ImVec1
--- @field BackupCurrLineSize                ImVec2
--- @field BackupCurrLineTextBaseOffset      float
--- @field BackupActiveIdIsAlive             ImGuiID
--- @field BackupAnyIdHasBeenEditedThisFrame bool
--- @field BackupDeactivatedIdIsAlive        bool
--- @field BackupHoveredIdIsAlive            bool
--- @field BackupIsSameLine                  bool
--- @field EmitItem                          bool

--- @return ImGuiGroupData
--- @nodiscard
function ImGuiGroupData()
    return
    {
        WindowID                          = nil,
        BackupCursorPos                   = ImVec2(),
        BackupCursorMaxPos                = ImVec2(),
        BackupCursorPosPrevLine           = ImVec2(),
        BackupIndent                      = ImVec1(),
        BackupGroupOffset                 = ImVec1(),
        BackupCurrLineSize                = ImVec2(),
        BackupCurrLineTextBaseOffset      = nil,
        BackupActiveIdIsAlive             = nil,
        BackupAnyIdHasBeenEditedThisFrame = nil,
        BackupDeactivatedIdIsAlive        = nil,
        BackupHoveredIdIsAlive            = nil,
        BackupIsSameLine                  = nil,
        EmitItem                          = nil
    }
end

--- @enum ImGuiTooltipFlags
ImGuiTooltipFlags =
{
    None             = 0,
    OverridePrevious = bitLShift(1, 1) -- Clear/ignore previously submitted tooltip (defaults to append)
}

-------------------------------------------------------------------------------
-- [SECTION] Popup support
-------------------------------------------------------------------------------

--- @enum ImGuiPopupPositionPolicy
ImGuiPopupPositionPolicy =
{
    Default  = 0,
    ComboBox = 1,
    Tooltip  = 2
}

-- Storage for popup stacks (g.OpenPopupStack and g.BeginPopupStack)
--- @class ImGuiPopupData
--- @field PopupId          ImGuiID
--- @field Window           ImGuiWindow
--- @field RestoreNavWindow ImGuiWindow
--- @field ParentNavLayer   int
--- @field OpenFrameCount   int
--- @field OpenParentId     ImGuiID
--- @field OpenPopupPos     ImVec2
--- @field OpenMousePos     ImVec2

--- @return ImGuiPopupData
--- @nodiscard
function ImGuiPopupData()
    return {
        PopupId          = 0,   -- Set on OpenPopup()
        Window           = nil, -- Resolved on BeginPopup() - may stay unresolved if user never calls OpenPopup()
        RestoreNavWindow = nil, -- Set on OpenPopup(), a NavWindow that will be restored on popup close
        ParentNavLayer   = -1,  -- Resolved on BeginPopup(). Actually a ImGuiNavLayer type (declared down below), initialized to -1 which is not part of an enum, but serves well-enough as "not any of layers" value
        OpenFrameCount   = -1,  -- Set on OpenPopup()
        OpenParentId     = 0,   -- Set on OpenPopup(), we need this to differentiate multiple menu sets from each others (e.g. inside menu bar vs loose menu items)
        OpenPopupPos     = ImVec2(), -- Set on OpenPopup(), preferred popup position (typically == OpenMousePos when using mouse)
        OpenMousePos     = ImVec2()  -- Set on OpenPopup(), copy of mouse position at the time of opening popup
    }
end

--- @enum ImGuiWindowRefreshFlags
ImGuiWindowRefreshFlags = {
    None              = 0,
    TryToAvoidRefresh = bitLShift(1, 0), -- [EXPERIMENTAL] Try to keep existing contents, USER MUST NOT HONOR BEGIN() RETURNING FALSE AND NOT APPEND.
    RefreshOnHover    = bitLShift(1, 1), -- [EXPERIMENTAL] Always refresh on hover
    RefreshOnFocus    = bitLShift(1, 2)  -- [EXPERIMENTAL] Always refresh on focus
    -- Refresh policy/frequency, Load Balancing etc.
}

--- @enum ImGuiNavRenderCursorFlags
ImGuiNavRenderCursorFlags = {
    None       = 0,
    Compact    = bitLShift(1, 1), -- Compact highlight, no padding/distance from focused item
    AlwaysDraw = bitLShift(1, 2), -- Draw rectangular highlight if (g.NavId == id) even when g.NavCursorVisible == false, aka even when using the mouse.
}

-------------------------------------------------------------------------------
-- [SECTION] Metrics, Debug Tools
-------------------------------------------------------------------------------

-- See IMGUI_DEBUG_LOG() and IMGUI_DEBUG_LOG_XXX() macros.
--- @enum ImGuiDebugLogFlags
ImGuiDebugLogFlags = {
    -- Event types
    None              = 0,
    EventError        = bitLShift(1, 0), -- Error submitted by IM_ASSERT_USER_ERROR()
    EventActiveId     = bitLShift(1, 1),
    EventFocus        = bitLShift(1, 2),
    EventPopup        = bitLShift(1, 3),
    EventNav          = bitLShift(1, 4),
    EventClipper      = bitLShift(1, 5),
    EventSelection    = bitLShift(1, 6),
    EventIO           = bitLShift(1, 7),
    EventFont         = bitLShift(1, 8),
    EventInputRouting = bitLShift(1, 9),
    EventDocking      = bitLShift(1, 10),
    EventViewport     = bitLShift(1, 11),
    EventTable        = bitLShift(1, 12),

    OutputToTTY        = bitLShift(1, 20), -- Also send output to TTY
    OutputToDebugger   = bitLShift(1, 21),
    OutputToTestEngine = bitLShift(1, 22),
}

ImGuiDebugLogFlags.EventMask_ = bitOr(
    ImGuiDebugLogFlags.EventError,
    ImGuiDebugLogFlags.EventActiveId,
    ImGuiDebugLogFlags.EventFocus,
    ImGuiDebugLogFlags.EventPopup,
    ImGuiDebugLogFlags.EventNav,
    ImGuiDebugLogFlags.EventClipper,
    ImGuiDebugLogFlags.EventSelection,
    ImGuiDebugLogFlags.EventTable,
    ImGuiDebugLogFlags.EventIO,
    ImGuiDebugLogFlags.EventFont,
    ImGuiDebugLogFlags.EventInputRouting,
    ImGuiDebugLogFlags.EventDocking,
    ImGuiDebugLogFlags.EventViewport
)

-------------------------------------------------------------------------------
-- [SECTION] Localization support
-------------------------------------------------------------------------------

-- This is experimental and not officially supported, it'll probably fall short of features, if/when it does we may backtrack.
--- @enum ImGuiLocKey
ImGuiLocKey = {
    VersionStr                    = 1,
    TableSizeOne                  = 2,
    TableSizeAllFit               = 3,
    TableSizeAllDefault           = 4,
    TableReset                    = 5,
    TableResetOrder               = 6,
    TableResetVisibility          = 7,
    WindowingMainMenuBar          = 8,
    WindowingPopup                = 9,
    WindowingUntitled             = 10,
    OpenLink_s                    = 11,
    CopyLink                      = 12,
    DockingHideTabBar             = 13,
    DockingHoldShiftToDock        = 14,
    DockingDragToUndockOrMoveNode = 15,
    COUNT                         = 15
}

--- @class ImGuiLocEntry
--- @field Key  ImGuiLocKey
--- @field Text string

--- @param key ImGuiLocKey
--- @return string
function ImGui.LocalizeGetMsg(key)
    local g = GImGui
    local msg = g.LocalizationTable[key]
    if msg then return msg else return "*Missing Text*" end
end

--- @param id ImGuiID
function ImGui.TempInputIsActive(id)
    local g = GImGui
    return (g.TempInputId == id and g.ActiveId == id) or (g.InputTextDeactivatedState.ID == id)
end

-- Get input text state if active
--- @param id ImGuiID
--- @return ImGuiInputTextState?
function ImGui.GetInputTextState(id)
    local g = GImGui
    if id ~= 0 and g.InputTextState.ID == id then
        return g.InputTextState
    end
    return nil
end

-- Storage for PushFocusScope(), g.FocusScopeStack[], g.NavFocusRoute[]
--- @class ImGuiFocusScopeData
--- @field ID       ImGuiID
--- @field WindowID ImGuiID

--- @return ImGuiFocusScopeData
--- @nodiscard
function ImGuiFocusScopeData() return { ID = nil, WindowID = nil } end

-------------------------------------------------------------------------------
-- [Luau] Inline struct helpers / constructors from imgui.h + imgui_internal.h
-------------------------------------------------------------------------------

-- Helper for running a block of code not more than once a frame
-- [Luau] no operator bool(): call the object, e.g. 'if once() then ... end'
MT.ImGuiOnceUponAFrame = {}
MT.ImGuiOnceUponAFrame.__index = MT.ImGuiOnceUponAFrame
MT.ImGuiOnceUponAFrame.__call = function(self) local current_frame = ImGui.GetFrameCount(); if self.RefFrame == current_frame then return false end; self.RefFrame = current_frame; return true end
function ImGuiOnceUponAFrame() return setmetatable({ RefFrame = -1 }, MT.ImGuiOnceUponAFrame) end

-- [Internal] ImGuiTextFilter item
-- [Luau] stores the item text as a Lua string (upstream: Begin pointer + Len)
--- @param buf string
--- @param b   int # 1-based
--- @param e   int # exclusive
function ImGuiTextFilterItem(buf, b, e) IM_ASSERT(e > b); return { Text = string.sub(buf, b, e - 1), CountInclude = 0, MatchIncludesMask = 0 } end

-- A date in YYYYMMDD format packed into 16-bits
--- @class ImGuiPackedDate
MT.ImGuiPackedDate = {}
MT.ImGuiPackedDate.__index = MT.ImGuiPackedDate
--- @param yyyymmdd? int
function ImGuiPackedDate(yyyymmdd)
    local this = setmetatable({ Year = 0, Month = 0, Day = 0 }, MT.ImGuiPackedDate)
    if yyyymmdd ~= nil then -- Pack
        this.Year = bitAnd(math.floor(yyyymmdd / 10000) - 2000, 0x7F) -- Year since 2000 (7 bits)
        this.Month = bitAnd(math.floor(yyyymmdd / 100) % 100, 0x0F) -- Month (1-12) (4 bits)
        this.Day = bitAnd(yyyymmdd % 100, 0x1F) -- Day (1-31) (5 bits)
    end
    return this
end
function MT.ImGuiPackedDate:IsValid() return self.Year ~= 0 and self.Month ~= 0 and self.Day ~= 0 end
function MT.ImGuiPackedDate:Unpack() if self.Year ~= 0 and self.Month ~= 0 and self.Day ~= 0 then return ((self.Year + 2000) * 10000) + (self.Month * 100) + self.Day end; return 0 end -- Unpack
function MT.ImGuiPackedDate:SubtractMonths(m) while m > 0 do if self.Month == 1 then self.Year = bitAnd(self.Year - 1, 0x7F) end; self.Month = (self.Month == 1) and 12 or self.Month - 1; m = m - 1 end end -- FIXME-OPT: Stupid but enough for what we do with it.

-- Pointer or index, e.g. g.CurrentTabBarStack[]
-- [Luau] overload by argument type: number = index, otherwise pointer
function ImGuiPtrOrIndex(ptr_or_index)
    if type(ptr_or_index) == "number" then return { Ptr = nil, Index = ptr_or_index } end
    return { Ptr = ptr_or_index, Index = -1 }
end

-- Note that Max is exclusive, so perhaps should be using a Begin/End convention.
--- @class ImGuiListClipperRange
MT.ImGuiListClipperRange = {}
function MT.ImGuiListClipperRange.FromIndices(min, max) return { Min = min, Max = max, PosToIndexConvert = false, PosToIndexOffsetMin = 0, PosToIndexOffsetMax = 0 } end
function MT.ImGuiListClipperRange.FromPositions(y1, y2, off_min, off_max) return { Min = _Trunc(y1), Max = _Trunc(y2), PosToIndexConvert = true, PosToIndexOffsetMin = off_min, PosToIndexOffsetMax = off_max } end

-- Temporary clipper data, buffers shared/reused between instances
--- @class ImGuiListClipperData
MT.ImGuiListClipperData = {}
MT.ImGuiListClipperData.__index = MT.ImGuiListClipperData
function ImGuiListClipperData() return setmetatable({ ListClipper = nil, LossynessOffset = 0.0, StepNo = 0, ItemsFrozen = 0, Ranges = ImVector() }, MT.ImGuiListClipperData) end
function MT.ImGuiListClipperData:Reset(clipper) self.ListClipper = clipper; self.StepNo = 0; self.ItemsFrozen = 0; self.Ranges:resize(0) end

-- [Luau] Desc holds the description string (upstream: DescOffset into ImGuiDebugItemPathQuery::ResultsDescBuf)
function ImGuiStackLevelInfo() return { ID = 0, QueryFrameCount = 0, QuerySuccess = false, DataType = -1, Desc = nil } end
-- [Luau] Results is a 1-based Lua array of ImGuiStackLevelInfo; ResultsDescBuf/ResultPathBuf are replaced by Lua strings.
function ImGuiDebugItemPathQuery() return { MainID = 0, Active = false, Complete = false, Step = 0, Results = {} } end
function ImGuiIDStackTool() return { OptHexEncodeNonAsciiChars = true, OptCopyToClipboardOnCtrlC = false, LastActiveFrame = -1, CopyToClipboardLastTime = -FLT_MAX } end
--- @enum ImGuiContextHookType
ImGuiContextHookType = { NewFramePre = 0, NewFramePost = 1, EndFramePre = 2, EndFramePost = 3, RenderPre = 4, RenderPost = 5, Shutdown = 6, PendingRemoval_ = 7 }

--- @class ImGuiContextHook
--- @field HookId   ImGuiID              -- A unique ID assigned by AddContextHook()
--- @field Type     ImGuiContextHookType
--- @field Owner    ImGuiID
--- @field Callback fun(ctx: ImGuiContext, hook: ImGuiContextHook)?
--- @field UserData any
function ImGuiContextHook() return { HookId = 0, Type = ImGuiContextHookType.NewFramePre, Owner = 0, Callback = nil, UserData = nil } end

-------------------------------------------------------------------------------
-- [Luau] ImGui:: inline helpers from imgui_internal.h
-------------------------------------------------------------------------------

function ImGui.GetCurrentTable() local g = GImGui; return g.CurrentTable end
--- @param window        ImGuiWindow
--- @param parent_window ImGuiWindow?
function ImGui.SetWindowParentWindowForFocusRoute(window, parent_window) window.ParentWindowForFocusRoute = parent_window end -- You may also use SetNextWindowClass()'s FocusRouteParentWindowId field.
function ImGui.GetPixelDensity() return GImGui.CurrentPixelDensity end
function ImGui.ScrollToBringRectIntoView(window, rect) ImGui.ScrollToRect(window, rect, ImGuiScrollFlags.KeepVisibleEdgeY) end
function ImGui.GetItemStatusFlags() local g = GImGui; return g.LastItemData.StatusFlags end
function ImGui.GetActiveID() local g = GImGui; return g.ActiveId end
function ImGui.GetFocusID() local g = GImGui; return g.NavId end
function ImGui.IsLegacyKey(key) return key >= ImGuiKey_LegacyNativeKey_BEGIN and key < ImGuiKey_LegacyNativeKey_END end
function ImGui.GetWindowDockNode() local g = GImGui; return g.CurrentWindow.DockNode end
function ImGui.GetCurrentFocusScope() local g = GImGui; return g.CurrentFocusScopeId end -- Focus scope we are outputting into, set by PushFocusScope()
function ImGui.GetCurrentTabBar() local g = GImGui; return g.CurrentTabBar end
-- This may be useful to apply workaround that a based on distinguish whenever an item is active as a text input field.
function ImGui.IsItemActiveAsInputText() local g = GImGui; return g.ActiveId ~= 0 and g.ActiveId == g.LastItemData.ID and g.InputTextState.ID == g.LastItemData.ID end


return true -- [Roblox] ModuleScripts must return exactly one value
