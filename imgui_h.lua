-- dear imgui, v1.93.0 WIP
-- (headers)

-- Help:
-- - Call and read ImGui.ShowDemoWindow() in imgui_demo.lua. All applications in examples/ are doing that.
-- - Read top of imgui.lua for more details, links and comments.

-- Resources:
-- - FAQ ........................ https://dearimgui.com/faq
-- - Homepage ................... https://github.com/ocornut/imgui
-- - Releases & Changelog ....... https://github.com/ocornut/imgui/releases
-- - Wiki ....................... https://github.com/ocornut/imgui/wiki (lots of good stuff there)
-- - Issues & support ........... https://github.com/ocornut/imgui/issues

-- Index of this file:
-- [SECTION] Forward declarations and basic types
-- [Port] [SECTION] METATABLE MANAGEMENT
-- [SECTION] Helpers: Debug log, memory allocations macros, ImVector<>
-- [SECTION] Drawing API (ImDrawCmd, ImDrawIdx, ImDrawVert, ImDrawChannel, ImDrawListSplitter, ImDrawFlags, ImDrawList, ImDrawData)
-- [SECTION] Texture API (ImTextureFormat, ImTextureStatus, ImTextureRect, ImTextureData)
-- [SECTION] Texture identifiers (ImTextureID, ImTextureRef)
-- [SECTION] Font API (ImFontConfig, ImFontGlyph, ImFontGlyphRangesBuilder, ImFontAtlasFlags, ImFontAtlas, ImFontBaked, ImFont)
-- [SECTION] ImGuiIO
-- [SECTION] Viewports
-- [SECTION] ImGuiPlatformIO + other Platform Dependent Interfaces (ImGuiPlatformMonitor, ImGuiPlatformImeData)
-- [SECTION] Flags & Enumerations
-- [SECTION] Misc data structures (ImGuiInputTextCallbackData, ImGuiSizeCallbackData, ImGuiPayload)
-- [SECTION] Tables API flags and structures (ImGuiTableFlags, ImGuiTableColumnFlags, ImGuiTableRowFlags, ImGuiTableBgTarget, ImGuiTableSortSpecs, ImGuiTableColumnSortSpecs)
-- [SECTION] Helpers (ImGuiOnceUponAFrame, ImGuiTextFilter, ImGuiTextBuffer, ImGuiStorage, ImGuiListClipper, Math Operators, ImColor)

--- @meta

local type   = type -- [Luau] builtin (FASTCALL); ImGui._GetTypeFunc() kept for compatibility
local rawget = rawget; local rawset = rawset

-- [Port] [LuaBitOp](https://bitop.luajit.org/semantics.html)
local bitAnd    = bit32.band; local bitOr = bit32.bor
local bitLShift = bit32.lshift

-------------------------------------------------------------------------------
-- [SECTION] Forward declarations and basic types
-------------------------------------------------------------------------------

-- Scalar data types
--- @class char          : integer
--- @class unsigned_char : integer

--- @alias ImS8 char
--- @alias ImU8 unsigned_char

--- @class ImU16 : integer
--- @class ImS16 : integer

--- @class ImU32 : integer
--- @class ImS32 : integer

--- @param val number
--- @return ImU8
function ImU8(val) return bitAnd(val, 0xFF) end
--- @param val number
--- @return ImS8
function ImS8(val) return bitAnd(val, 0xFF) - (bitAnd(val, 0x80) ~= 0 and 0x100 or 0) end

--- @param val number
--- @return ImU16
function ImU16(val) return bitAnd(val, 0xFFFF) end
--- @param val number
--- @return ImS16
function ImS16(val) return bitAnd(val, 0xFFFF) - (bitAnd(val, 0x8000) ~= 0 and 0x10000 or 0) end

--- @param val number
--- @return ImU32
function ImU32(val) return bitAnd(val, 0xFFFFFFFF) end
--- @param val number
--- @return ImS32
function ImS32(val) return bitAnd(val, 0xFFFFFFFF) end

-- [Luau] 64-bit integers are stored in doubles (exact only within +-2^53): the cast just truncates toward zero like a C double->int64 cast.
--- @param val number
--- @return ImS64
function ImS64(val) if val >= 0 then return math.floor(val) end return -math.floor(-val) end
--- @param val number
--- @return ImU64
function ImU64(val) if val >= 0 then return math.floor(val) end return -math.floor(-val) end

--- @alias float          number
--- @class double : number

--- @alias int            integer
--- @alias unsigned_int   integer

--- @alias short          integer
--- @alias unsigned_short integer

--- @alias size_t unsigned_int

-- Character types
-- (we generally use UTF-8 encoded string in the API. This is storage specifically for a decoded character used for keyboard input and display)
--- @alias ImWchar16 unsigned_short
--- @alias ImWchar   ImWchar16

--- @alias bool boolean

-- A unique ID used by widgets (typically the result of hashing a stack of string)
--- @alias ImGuiID unsigned_int

-- ImTextureID = backend specific, low-level identifier for a texture uploaded in GPU/graphics system.
-- [Compile-time configurable type]
-- - When a Rendered Backend creates a texture, it store its native identifier into a ImTextureID value.
--   (e.g. Used by DX11 backend to a `ID3D11ShaderResourceView*`; Used by OpenGL backends to store `GLuint`;
--         Used by SDLGPU backend to store a `SDL_GPUTextureSamplerBinding*`, etc.).
-- - User may submit their own textures to e.g. ImGui.Image() function by passing this value.
-- - During the rendering loop, the Renderer Backend retrieve the ImTextureID, which stored inside a
--   ImTextureRef, which is stored inside a ImDrawCmd.
--- @alias ImTextureID integer

-- ImGuiKey | ImGuiMod_XXX: for IsKeyChordPressed(), Shortcut() etc. an ImGuiKey optionally OR-ed with one or more ImGuiMod_XXX values.
--- @alias ImGuiKeyChord int

-- ImDrawIdx: vertex index. [Compile-time configurable type]
--- @alias ImDrawIdx unsigned_int

-- Library Version
-- (Integer encoded as XYYZZ for use in conditionals, e.g. 'if IMGUI_VERSION_NUM >= 12345')
IMGUI_VERSION     = "1.93.0 WIP"
IMGUI_VERSION_NUM = 19298

-- Helper: Unicode defines
IM_UNICODE_CODEPOINT_INVALID = 0xFFFD -- Invalid Unicode code point (standard value).
IM_UNICODE_CODEPOINT_MAX     = 0xFFFF -- Maximum Unicode code point supported by this build.

-- IM_ALLOC(), IM_FREE(), IM_DELETE()
IM_ALLOC = ImGui.MemAlloc
IM_FREE = ImGui.MemFree

--- @param owner table
--- @param field string|int
IM_DELETE = function(owner, field) if owner[field] ~= nil then owner[field] = nil; ImGui.MemFree(owner, field); end end

-------------------------------------------------------------------------------
-- [Port] [SECTION] METATABLE MANAGEMENT
-------------------------------------------------------------------------------

--- [Port] File-scope metatable storage
local MT = {}

function ImGui.GetMetatables() return MT end

--- @param _EXPR any
--- @param _MSG  string?
@native
function IM_ASSERT(_EXPR, _MSG) assert((_EXPR), _MSG) end

IM_ASSERT_PARANOID = IM_ASSERT

-- A primary data type
--- [Port] Note that `S64` and `U64` are not supported
--- @enum ImGuiDataType
ImGuiDataType =
{
    S8     = 0, -- signed char / char (with sensible compilers)
    U8     = 1, -- unsigned char
    S16    = 2, -- short
    U16    = 3, -- unsigned short
    S32    = 4, -- int
    U32    = 5, -- unsigned int
    S64    = 6, -- long long / __int64 -- [Luau] stored in a double: exact only within +-2^53
    U64    = 7, -- unsigned long long / unsigned __int64 -- [Luau] stored in a double: exact only within 0..2^53
    Float  = 8, -- float
    Double = 9, -- double
    Bool   = 10, -- bool (provided for user convenience, not supported by scalar widgets)
    String = 11, -- string (provided for user convenience, not supported by scalar widgets)
    COUNT  = 12
}
-- Extend ImGuiDataType_
ImGuiDataType.Pointer = ImGuiDataType.COUNT -- [internal]
ImGuiDataType.ID      = ImGuiDataType.COUNT + 1 -- [internal]

ImTextureID_Invalid = -1

-- We intentionally support a limited amount of texture formats to limit burden on CPU-side code and extension.
-- Most standard backends only support RGBA32 but we provide a single channel option for low-resource/embedded systems.
--- @enum ImTextureFormat
ImTextureFormat =
{
    RGBA32 = 0, -- 4 components per pixel, each is unsigned 8-bit. Total size = TexWidth * TexHeight * 4
    Alpha8 = 1, -- 1 component per pixel, each is unsigned 8-bit. Total size = TexWidth * TexHeight
}

-- Status of a texture to communicate with Renderer Backend.
--- @enum ImTextureStatus
ImTextureStatus =
{
    OK          = 0,
    Destroyed   = 1, -- Backend destroyed the texture.
    WantCreate  = 2, -- Requesting backend to create the texture. Set status OK when done.
    WantUpdates = 3, -- Requesting backend to update specific blocks of pixels (write to texture portions which have never been used before). Set status OK when done.
    WantDestroy = 4, -- Requesting backend to destroy the texture. Set status to Destroyed when done.
}

-- Flags for ImFontAtlas build
--- @enum ImFontAtlasFlags
ImFontAtlasFlags =
{
    None               = 0,
    NoPowerOfTwoHeight = bitLShift(1, 0), -- Don't round the height to next power of two
    NoMouseCursors     = bitLShift(1, 1), -- Don't build software mouse cursors into the atlas (save a little texture memory)
    NoBakedLines       = bitLShift(1, 2), -- Don't build anti-aliased line textures into the atlas (save a little texture memory). SINCE 1.93.0 THIS PREVENTS ANTI-ALIASED LINES FROM WORKING AND WILL DISABLE THEM.
    NoBakedRoundCorners= bitLShift(1, 3), -- Don't build round corners into the atlas.
}

-- A cardinal direction
--- @enum ImGuiDir
ImGuiDir =
{
    None  = -1,
    Left  = 0,
    Right = 1,
    Up    = 2,
    Down  = 3,
    COUNT = 4
}

-- Identify a mouse button.
-- Those values are guaranteed to be stable and we frequently use 0/1 directly. Named enums provided for convenience.
--- @enum ImGuiMouseButton
ImGuiMouseButton =
{
    Left   = 0,
    Right  = 1,
    Middle = 2,
    COUNT  = 5
}

-- Enumeration for GetMouseCursor()
-- User code may request backend to display given cursor by calling SetMouseCursor(), which is why we have some cursors that are marked unused here
--- @enum ImGuiMouseCursor
ImGuiMouseCursor =
{
    None       = -1,
    Arrow      = 0,
    TextInput  = 1, -- When hovering over InputText, etc.
    ResizeAll  = 2, -- (Unused by Dear ImGui functions)
    ResizeNS   = 3, -- When hovering over a horizontal border
    ResizeEW   = 4, -- When hovering over a vertical border or a column
    ResizeNESW = 5, -- When hovering over the bottom-left corner of a window
    ResizeNWSE = 6, -- When hovering over the bottom-right corner of a window
    Hand       = 7, -- (Unused by Dear ImGui functions. Use for e.g. hyperlinks)
    Wait       = 8, -- When waiting for something to process/load.
    Progress   = 9, -- When waiting for something to process/load, but application is still interactive.
    NotAllowed = 10, -- When hovering something with disallowed interaction. Usually a crossed circle.
    COUNT      = 11
}

-- Coordinates of a rectangle within a texture.
-- When a texture is in ImTextureStatus.WantUpdates state, we provide a list of individual rectangles to copy to the graphics system.
-- You may use ImTextureData::Updates[] for the list, or ImTextureData::UpdateBox for a single bounding box.
--- @class ImTextureRect
--- @field x unsigned_short
--- @field y unsigned_short
--- @field w unsigned_short
--- @field h unsigned_short

--- @param x? unsigned_short
--- @param y? unsigned_short
--- @param w? unsigned_short
--- @param h? unsigned_short
--- @return ImTextureRect
function ImTextureRect(x, y, w, h) return { x = x, y = y, w = w, h = h } end

-- ImVec2: 2D vector used to store positions, sizes etc. [Compile-time configurable type]
-- [Luau] Stored as named fields {x=, y=} so the common `.x`/`.y` access is a plain table read (no metamethod call).
-- Numeric keys 1, 2 still work through the metatable, but are slower: prefer .x/.y in hot code.
--- @class ImVec2
--- @operator add(ImVec2): ImVec2
--- @operator sub(ImVec2): ImVec2
--- @operator mul(number): ImVec2
--- @operator mul(ImVec2): ImVec2
--- @operator div(number): ImVec2
--- @operator div(ImVec2): ImVec2
--- @field x number
--- @field y number
local IM_VEC2 = {}
local VEC2_KEYS = { "x", "y" }

IM_VEC2.__index = function(t, k)
    local n = VEC2_KEYS[k]
    if n then return rawget(t, n) end
end

IM_VEC2.__newindex = function(t, k, v)
    local n = VEC2_KEYS[k]
    IM_ASSERT(n ~= nil)
    rawset(t, n, v)
end

--- @param x? number
--- @param y? number
--- @return ImVec2
--- @nodiscard
@native
function ImVec2(x, y) return setmetatable({ x = x or 0, y = y or 0 }, IM_VEC2) end

@native
function IM_VEC2.__add(lhs, rhs) return setmetatable({ x = lhs.x + rhs.x, y = lhs.y + rhs.y }, IM_VEC2) end
@native
function IM_VEC2.__sub(lhs, rhs) return setmetatable({ x = lhs.x - rhs.x, y = lhs.y - rhs.y }, IM_VEC2) end

@native
function IM_VEC2.__mul(lhs, rhs)
    if type(rhs) == "number" then return setmetatable({ x = lhs.x * rhs, y = lhs.y * rhs }, IM_VEC2) end
    return setmetatable({ x = lhs.x * rhs.x, y = lhs.y * rhs.y }, IM_VEC2)
end

@native
function IM_VEC2.__div(lhs, rhs)
    if type(rhs) == "number" then return setmetatable({ x = lhs.x / rhs, y = lhs.y / rhs }, IM_VEC2) end
    return setmetatable({ x = lhs.x / rhs.x, y = lhs.y / rhs.y }, IM_VEC2)
end

function IM_VEC2.__eq(lhs, rhs) return lhs.x == rhs.x and lhs.y == rhs.y end

function IM_VEC2:__tostring() return string.format("ImVec2(%g, %g)", self.x, self.y) end

--- @param dest ImVec2
--- @param src  ImVec2
@native
function ImVec2_Copy(dest, src) dest.x = src.x; dest.y = src.y end

function ImVec2_CopyV(dest, src_x, src_y) dest.x = src_x; dest.y = src_y end

function ImVec2_AddVA(v, add_x, add_y) return v.x + add_x, v.y + add_y end

function ImVec2_SubVA(v, sub_x, sub_y) return v.x - sub_x, v.y - sub_y end

function ImVec2_MulVX(a, scalar) return a.x * scalar, a.y * scalar end

--- [Port] An inlined version of `ImVec2_Copy` currently for use in certain ImVector<ImVec2> `push_back`
local function ImVec2_TCopy(t, k, v) local dest = t[k]; dest.x = v.x; dest.y = v.y; end

-- ImVec4: 4D vector used to store clipping rectangles, colors etc. [Compile-time configurable type]
-- [Luau] Same layout as ImVec2: named fields x, y, z, w; numeric keys 1..4 go through the metatable.
--- @class ImVec4
--- @operator add(ImVec4): ImVec4
--- @operator sub(ImVec4): ImVec4
--- @operator mul(number): ImVec4
--- @field x number
--- @field y number
--- @field z number
--- @field w number
local IM_VEC4 = {}
local VEC4_KEYS = { "x", "y", "z", "w" }

IM_VEC4.__index = function(t, k)
    local n = VEC4_KEYS[k]
    if n then return rawget(t, n) end
end

IM_VEC4.__newindex = function(t, k, v)
    local n = VEC4_KEYS[k]
    IM_ASSERT(n ~= nil)
    rawset(t, n, v)
end

--- @return ImVec4
--- @nodiscard
@native
function ImVec4(x, y, z, w) return setmetatable({ x = x or 0, y = y or 0, z = z or 0, w = w or 0 }, IM_VEC4) end

function IM_VEC4.__add(lhs, rhs) return ImVec4(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z, lhs.w + rhs.w) end
function IM_VEC4.__sub(lhs, rhs) return ImVec4(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z, lhs.w - rhs.w) end
function IM_VEC4.__mul(lhs, rhs) return ImVec4(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs, lhs.w * rhs) end
function IM_VEC4.__eq(lhs, rhs) return lhs.x == rhs.x and lhs.y == rhs.y and lhs.z == rhs.z and lhs.w == rhs.w end

function IM_VEC4:__tostring() return string.format("ImVec4(%g, %g, %g, %g)", self.x, self.y, self.z, self.w) end

--- @param dest ImVec4
--- @param src  ImVec4
@native
function ImVec4_Copy(dest, src) dest.x = src.x; dest.y = src.y; dest.z = src.z; dest.w = src.w end

-------------------------------------------------------------------------------
-- [SECTION] Helpers: Debug log, memory allocations macros, ImVector<>
-------------------------------------------------------------------------------

-- ImVector<>
--- [Port] A compact ImVector clone
--- @class ImVector<T>
--- @field Data          T[] # 1-based table
--- @field Size          int # >= 0
--- @field _Constructor  function
--- @field _CopyFunc     function
local IM_VECTOR = {}

-- [Port] Support 1-based number key indexing while keep method accessing speed
--- @param t ImVector
--- @param k string|int
--- @return any
@native
local function IM_VECTOR_index(t, k)
    local m = IM_VECTOR[k] -- [Port] methods first (hot path)
    if m ~= nil then return m end
    if k == "Data" then return nil end -- [Port] Data has already been discarded
    return t.Data[IM_ASSERT(k >= 1 and k <= t.Size) or k] -- [Port] if the mt access turns out nil, the k must be int index into Data
end
IM_VECTOR.__index = IM_VECTOR_index

--- @param t ImVector
--- @param k int
--- @param v any
IM_VECTOR.__newindex = function(t, k, v)
    if k == "Data" then rawset(t, "Data", v); return; end -- [Port] set new Data. old Data is already discarded
    IM_ASSERT(k >= 1 and k <= t.Size)
    t.Data[k] = v
end

local _default_constructor = function() return nil end
local _default_copyfunc = function(t, k, v) t[k] = v end

local function _grow_capacity(v, sz) local new_capacity = (v.Capacity ~= 0) and math.floor(v.Capacity + v.Capacity / 2) or 8; return (new_capacity > sz) and new_capacity or sz; end

--- @param T?         function
--- @param COPY_FUNC? function
--- @return ImVector
--- @nodiscard
function ImVector(T, COPY_FUNC) return setmetatable({Data = nil, Size = 0, Capacity = 0, _Constructor = T or _default_constructor, _CopyFunc = COPY_FUNC or _default_copyfunc}, IM_VECTOR) end

@native
function IM_VECTOR:push_back(value) if self.Size == self.Capacity then self:reserve(_grow_capacity(self, self.Size + 1)) end; self._CopyFunc(self.Data, self.Size + 1, value); self.Size = self.Size + 1; return value end
@native
function IM_VECTOR:pop_back() IM_ASSERT(self.Size > 0); self.Size = self.Size - 1; end
function IM_VECTOR:push_front(value) if self.Size == 0 then self:push_back(value) else self:insert(1, value) end end
function IM_VECTOR:clear() if self.Data then self.Size = 0; self.Capacity = 0; IM_FREE(self, "Data"); self.Data = nil end end
function IM_VECTOR:clear_delete() for i = 1, self.Size do self.Data[i] = nil end self.Size = 0 end
function IM_VECTOR:empty() return self.Size == 0 end
@native
function IM_VECTOR:back()   IM_ASSERT(self.Size > 0) return self.Data[self.Size] end
function IM_VECTOR:erase(i) IM_ASSERT(i >= 1 and i <= self.Size) local removed = (table.remove(self.Data, i)) ~= nil self.Size = self.Size - 1 return removed end
@native
local function _iter(v, i) i = i + 1 if i <= v.Size then return i, v.Data[i] end end
function IM_VECTOR:iter() return _iter, self, 0 end
function IM_VECTOR:find_index(value) for i = 1, self.Size do if self.Data[i] == value then return i end end return nil end
function IM_VECTOR:erase_unsorted(index) IM_ASSERT(index >= 1 and index <= self.Size) local last_idx = self.Size if index ~= last_idx then self.Data[index] = self.Data[last_idx] end self.Data[last_idx] = nil self.Size = self.Size - 1 return true end
function IM_VECTOR:find_erase(value) local idx = self:find_index(value) if idx then return self:erase(idx) end return false end
function IM_VECTOR:find_erase_unsorted(value) local idx = self:find_index(value) if idx then return self:erase_unsorted(idx) end return false end

function IM_VECTOR:reserve(new_capacity)
    if new_capacity <= self.Capacity then return end
    local new_data = IM_ALLOC(self._Constructor, new_capacity)
    if self.Data then
        ImStd.memmove(new_data, 1, self.Data, 1, self.Size)
        IM_FREE(self, "Data")
    end
    self.Data = new_data
    self.Capacity = new_capacity
end

function IM_VECTOR:reserve_discard(new_capacity)
    if new_capacity <= self.Capacity then return end
    if self.Data then IM_FREE(self, "Data") end
    self.Data = IM_ALLOC(self._Constructor, new_capacity)
    self.Capacity = new_capacity
end

function IM_VECTOR:shrink(new_size) IM_ASSERT(new_size <= self.Size) self.Size = new_size end

function IM_VECTOR:resize(new_size, v)
    if new_size > self.Capacity then self:reserve(_grow_capacity(self, new_size)) end
    if v ~= nil and new_size > self.Size then
        local data = self.Data
        for n = self.Size + 1, new_size do data[n] = v end
    end
    self.Size = new_size
end

function IM_VECTOR:swap(other) self.Size, other.Size = other.Size, self.Size; self.Capacity, other.Capacity = other.Capacity, self.Capacity; self.Data, other.Data = other.Data, self.Data end
function IM_VECTOR:contains(v) for i = 1, self.Size do if self.Data[i] == v then return true end end return false end

-- [Port] NOTE: This currently does not use type-aware copy!
function IM_VECTOR:insert(pos, value) IM_ASSERT(pos >= 1 and pos <= self.Size + 1); if self.Size == self.Capacity then self:reserve(_grow_capacity(self, self.Size + 1)) end; for i = self.Size, pos, -1 do self.Data[i + 1] = self.Data[i] end self.Data[pos] = value self.Size = self.Size + 1 return value end

-- [Port] NOTE: This currently does not copy type related info!
--- @nodiscard
function IM_VECTOR:copy()
    local v = ImVector(); v:resize(self.Size)
    local dest = v.Data; local src = self.Data
    for i = 1, v.Size do dest[i] = src[i] end
    return v
end

-- [Port] Not keeping value-key records inside `ImVector`, instead just find it
--- @return int # 0-based index
function IM_VECTOR:index_from_ptr(p)
    local data = self.Data; for i = 1, self.Size do if p == data[i] then return i - 1 end end
    --- @diagnostic disable-next-line
    IM_ASSERT(false, "index_from_ptr failed!")
end

-------------------------------------------------------------------------------
-- [SECTION] Drawing API (ImDrawCmd, ImDrawIdx, ImDrawVert, ImDrawChannel, ImDrawListSplitter, ImDrawFlags, ImDrawList, ImDrawData)
-------------------------------------------------------------------------------

-- Hold a series of drawing commands. The user provides a renderer for ImDrawData which essentially contains an array of ImDrawList.

-- Typically, 1 command = 1 GPU draw call (unless command is a callback)
-- - VtxOffset: When 'io.BackendFlags & ImGuiBackendFlags.RendererHasVtxOffset' is enabled,
--   this fields allow us to render meshes larger than 64K vertices while keeping 16-bit indices.
--   Backends made for <1.71. will typically ignore the VtxOffset fields.
--- @class ImDrawCmd
--- @field ClipRect               ImVec4
--- @field TexRef                 ImTextureRef
--- @field VtxOffset              unsigned_int
--- @field IdxOffset              unsigned_int
--- @field ElemCount              unsigned_int
--- @field UserCallback           ImDrawCallback
--- @field UserCallbackData       any
--- @field UserCallbackDataSize   int
--- @field UserCallbackDataOffset int
MT.ImDrawCmd = {}
MT.ImDrawCmd.__index = MT.ImDrawCmd

--- @return ImDrawCmd
--- @nodiscard
function ImDrawCmd()
    return setmetatable({
        ClipRect               = ImVec4(), -- 4*4  -- Clipping rectangle (x1, y1, x2, y2). Subtract ImDrawData->DisplayPos to get clipping rectangle in "viewport" coordinates
        TexRef                 = nil, -- 16   -- Reference to a font/texture atlas (where backend called ImTextureData::SetTexID()) or to a user-provided texture ID (via e.g. ImGui.Image() calls). Both will lead to a ImTextureID value.
        VtxOffset              = 0, -- 4    -- Start offset in vertex buffer. ImGuiBackendFlags.RendererHasVtxOffset: always 0, otherwise may be >0 to support meshes larger than 64K vertices with 16-bit indices.
        IdxOffset              = 0, -- 4    -- Start offset in index buffer.
        ElemCount              = 0, -- 4    -- Number of indices (multiple of 3) to be rendered as triangles. Vertices are stored in the callee ImDrawList's vtx_buffer[] array, indices in idx_buffer[].
        UserCallback           = nil, -- 4-8  -- If != nil, call the function instead of rendering the vertices. clip_rect and texture_id will be set normally.
        UserCallbackData       = nil, -- 4-8  -- Callback user data (when UserCallback != nil). If called AddCallback() with size == 0, this is a copy of the AddCallback() argument. If called AddCallback() with size > 0, this is pointing to a buffer where data is stored.
        UserCallbackDataSize   = 0, -- 4 -- Size of callback user data when using storage, otherwise 0.
        UserCallbackDataOffset = 0 -- 4 -- [Internal] Offset of callback user data when using storage, otherwise -1.
    }, MT.ImDrawCmd)
end

--- @return ImTextureID
function MT.ImDrawCmd:GetTexID()
    local tex_id = (self.TexRef._TexData) and self.TexRef._TexData.TexID or self.TexRef._TexID
    if self.TexRef._TexData ~= nil then
        IM_ASSERT(tex_id ~= ImTextureID_Invalid, "ImDrawCmd is referring to ImTextureData that wasn't uploaded to graphics system. Backend must call ImTextureData::SetTexID() after handling ImTextureStatus_WantCreate request!")
    end
    return tex_id
end

-- Vertex layout
--- @class ImDrawVert
--- @field [1] ImVec2 # pos
--- @field [2] ImVec2 # uv
--- @field [3] ImU32  # col

--- @return ImDrawVert
--- @nodiscard
function ImDrawVert() return { ImVec2(), ImVec2(), nil } end

-- [Luau] ImDrawList.VtxBuffer storage: one buffer, VTX_STRIDE bytes per vertex. Vertex i (1-based) is at
-- byte (i - 1) * VTX_STRIDE: f64 pos.x, f64 pos.y, f64 uv.x, f64 uv.y, u32 col. (f64 keeps results identical to tables.)
-- Same Size/Capacity/resize/reserve/shrink/clear interface as ImVector; elements are read with ImDrawVtx_* below.
VTX_STRIDE = 36
local IM_VTXBUF = {}
IM_VTXBUF.__index = IM_VTXBUF
function ImDrawVtxBuffer() return setmetatable({ Size = 0, Capacity = 0, Buf = buffer.create(0) }, IM_VTXBUF) end
function IM_VTXBUF:reserve(n)
    if n <= self.Capacity then return end
    local nb = buffer.create(n * VTX_STRIDE)
    buffer.copy(nb, 0, self.Buf, 0, self.Size * VTX_STRIDE)
    self.Buf = nb
    self.Capacity = n
end
function IM_VTXBUF:resize(n)
    if n > self.Capacity then self:reserve(math.max(n, math.floor(self.Capacity * 1.5), 64)) end
    self.Size = n
end
function IM_VTXBUF:shrink(n) self.Size = n end
function IM_VTXBUF:clear() self.Size = 0; self.Capacity = 0; self.Buf = buffer.create(0) end

function ImDrawVtx_Pos(b, i) local o = (i - 1) * VTX_STRIDE; return buffer.readf64(b, o), buffer.readf64(b, o + 8) end
function ImDrawVtx_Col(b, i) return buffer.readu32(b, (i - 1) * VTX_STRIDE + 32) end

-- [Internal] For use by ImDrawList
--- @class ImDrawCmdHeader
--- @field ClipRect  ImVec4
--- @field TexRef    ImTextureRef
--- @field VtxOffset unsigned_int

--- @return ImDrawCmdHeader
--- @nodiscard
function ImDrawCmdHeader() return { ClipRect = ImVec4(), TexRef = nil, VtxOffset = 0 } end

-- [Internal] For use by ImDrawListSplitter
--- @class ImDrawChannel
--- @field _CmdBuffer ImVector<ImDrawCmd>
--- @field _IdxBuffer ImVector<ImDrawIdx>

--- @return ImDrawChannel
--- @nodiscard
function ImDrawChannel() return { _CmdBuffer = ImVector(), _IdxBuffer = ImVector() } end

-- Split/Merge functions are used to split the draw list into different layers which can be drawn into out of order.
-- This is used by the Columns/Tables API, so items of each column can be batched together in a same draw call.
--- @class ImDrawListSplitter
--- @field _Current  int
--- @field _Count    int
--- @field _Channels ImVector<ImDrawChannel>

--- @return ImDrawListSplitter
--- @nodiscard
MT.ImDrawListSplitter = {} -- [Port] methods in imgui_draw.lua
MT.ImDrawListSplitter.__index = MT.ImDrawListSplitter
function ImDrawListSplitter() return setmetatable({ _Current = 0, _Count = 0, _Channels = ImVector() }, MT.ImDrawListSplitter) end

-- Draw command list
-- This is the low-level list of polygons that ImGui.* functions are filling. At the end of the frame,
-- all command lists are passed to your ImGuiIO::RenderDrawListFn function for rendering.
-- Each dear imgui window contains its own ImDrawList. You can use ImGui.GetWindowDrawList() to
-- access the current window draw list and draw custom primitives.
-- You can interleave normal ImGui.* calls and adding primitives to the current draw list.
-- In single viewport mode, top-left is == GetMainViewport()->Pos (generally 0,0), bottom-right is == GetMainViewport()->Pos+Size (generally io.DisplaySize).
-- You are totally free to apply whatever transformation matrix you want to the data (depending on the use of the transformation you may want to apply it to ClipRect as well!)
-- Important: Primitives are always added to the list and not culled (culling is done at higher-level by ImGui.* functions), if you use this API a lot consider coarse culling your drawn objects.
--- @class ImDrawList
--- @field CmdBuffer         ImVector<ImDrawCmd>
--- @field IdxBuffer         ImVector<ImDrawIdx>
--- @field VtxBuffer         ImVector<ImDrawVert>
--- @field Flags             ImDrawFlags          # Current flags for drawing primitives. Alter with PushDrawFlag()/PopDrawFlag()
--- @field _VtxCurrentIdx    unsigned_int         # 1-based, generally == (VtxBuffer.Size + 1)
--- @field _Data             ImDrawListSharedData # Pointes to shared draw data
--- @field _VtxWritePtr      unsigned_int         # 1-based, points to the current writing vertex in VtxBuffer (see ImDrawVtxBuffer)
--- @field _IdxWritePtr      unsigned_int         # 1-based, points to the current writing index in IdxBuffer.Data
--- @field _Path             ImVector<ImVec2>     # current path building
--- @field _CmdHeader        ImDrawCmdHeader      # template of active commands. Fields should match those of CmdBuffer:back()
--- @field _Splitter         ImDrawListSplitter
--- @field _ClipRectStack    ImVector<ImVec4>
--- @field _TextureStack     ImVector<ImTextureRef>
--- @field _CallbacksDataBuf any
--- @field _DrawFlagsStack   ImVector<ImDrawFlags>
--- @field _FringeScale      float
--- @field _InvFringeScale   float
--- @field _FringeScaleIsInteger bool
--- @field _OwnerName        string
MT.ImDrawList = {}
MT.ImDrawList.__index = MT.ImDrawList

--- @param pos ImVec2
--- @param uv  ImVec2
--- @param col ImU32
function MT.ImDrawList:PrimWriteVtx(pos, uv, col)
    local b, o = self.VtxBuffer.Buf, (self._VtxWritePtr - 1) * VTX_STRIDE
    buffer.writef64(b, o, pos.x); buffer.writef64(b, o + 8, pos.y)
    buffer.writef64(b, o + 16, uv.x); buffer.writef64(b, o + 24, uv.y)
    buffer.writeu32(b, o + 32, col)
    self._VtxWritePtr = self._VtxWritePtr + 1
    self._VtxCurrentIdx = self._VtxCurrentIdx + 1
end

--- @param idx ImDrawIdx
function MT.ImDrawList:PrimWriteIdx(idx)
    self.IdxBuffer.Data[self._IdxWritePtr] = idx
    self._IdxWritePtr = self._IdxWritePtr + 1
end

--- @param pos ImVec2
--- @param uv  ImVec2
--- @param col ImU32
function MT.ImDrawList:PrimVtx(pos, uv, col)
    self:PrimWriteIdx(self._VtxCurrentIdx)
    self:PrimWriteVtx(pos, uv, col)
end

--- @param data? ImDrawListSharedData
--- @return ImDrawList
--- @nodiscard
function ImDrawList(data)
    --- @type ImDrawList
    local this = setmetatable({
        -- This is what you have to render
        CmdBuffer = ImVector(), -- Draw commands. Typically 1 command = 1 GPU draw call, unless the command is a callback.
        IdxBuffer = ImVector(), -- Index buffer. Each command consume ImDrawCmd::ElemCount of those
        VtxBuffer = ImDrawVtxBuffer(), -- Vertex buffer.
        Flags     = 0, -- Current flags for drawing primitives.  Alter with PushDrawFlag()/PopDrawFlags() to adjust defaults to a given scope.

        -- [Internal, used while building lists]
        _VtxCurrentIdx = 1, -- [Internal] generally == VtxBuffer.Size unless we are past 64K vertices, in which case this gets reset to 0.
        _Data          = nil, -- Pointer to shared draw data (you can use ImGui.GetDrawListSharedData() to get the one from current ImGui context)
        _VtxWritePtr   = 1, -- [Internal] point within VtxBuffer.Data after each add command (to avoid using the ImVector<> operators too much)
        _IdxWritePtr   = 1, -- [Internal] point within IdxBuffer.Data after each add command (to avoid using the ImVector<> operators too much)
        _Path          = ImVector(ImVec2, ImVec2_TCopy), -- [Internal] current path building
        _CmdHeader     = ImDrawCmdHeader(), -- [Internal] template of active commands. Fields should match those of CmdBuffer.back().
        _Splitter      = ImDrawListSplitter(), -- [Internal] for channels api (note: prefer using your own persistent instance of ImDrawListSplitter!)
        _ClipRectStack = ImVector(), -- [Internal]
        _TextureStack  = ImVector(), -- [Internal]
        _CallbacksDataBuf = ImVector(), -- [Internal] [Lua] copies of AddCallback() userdata (userdata_size > 0)
        _DrawFlagsStack = ImVector(), -- [Internal] ImSmallStack_<ImDrawFlags,3>: capacity checked by PushDrawFlag()
        _FringeScale = 1.0, -- [Internal] anti-alias fringe is scaled by this value, this helps to keep things sharp while zooming at vertex buffer content -- [Luau] 1.0 instead of memset 0 so a list used before _SetPixelDensity() still works
        _InvFringeScale = 1.0, -- [internal] 1.0 / _FringeScale // FIXME: Consider renaming to _PixelDensity.
        _FringeScaleIsInteger = true, -- [Internal] true if 1/_FringeScale is a whole number, used to select fast path for rendering
        _OwnerName = nil -- Pointer to owner window's name for debugging
    }, MT.ImDrawList)

    this:_SetDrawListSharedData(data)

    return this
end

-- All draw data to render a Dear ImGui frame
-- (NB: the style and the naming convention here is a little inconsistent, we currently preserve them for backward compatibility purpose,
-- as this is one of the oldest structure exposed by the library! Basically, ImDrawList == CmdList)
--- @class ImDrawData
--- @field Valid            bool
--- @field FrameCount       int
--- @field TotalIdxCount    int
--- @field TotalVtxCount    int
--- @field CmdLists         ImVector<ImDrawList>
--- @field DisplayPos       ImVec2
--- @field DisplaySize      ImVec2
--- @field FramebufferScale ImVec2
--- @field OwnerViewport    ImGuiViewport
--- @field Textures         ImVector<ImTextureData>
MT.ImDrawData = {}
MT.ImDrawData.__index = MT.ImDrawData

--- @return ImDrawData
function ImDrawData()
    --- @type ImDrawData
    local this = setmetatable({}, MT.ImDrawData)

    this.CmdLists = ImVector() -- Array of ImDrawList* to render. The ImDrawLists are owned by ImGuiContext and only pointed to from here.
    this:Clear()

    return this
end

-------------------------------------------------------------------------------
-- [SECTION] Texture API (ImTextureFormat, ImTextureStatus, ImTextureRect, ImTextureData)
-------------------------------------------------------------------------------

-- Specs and pixel storage for a texture used by Dear ImGui.
-- This is only useful for (1) core library and (2) backends. End-user/applications do not need to care about this.
-- Renderer Backends will create a GPU-side version of this.
-- Why does we store two identifiers: TexID and BackendUserData?
-- - ImTextureID    TexID           = lower-level identifier stored in ImDrawCmd. ImDrawCmd can refer to textures not created by the backend, and for which there's no ImTextureData.
-- - void*          BackendUserData = higher-level opaque storage for backend own book-keeping. Some backends may have enough with TexID and not need both.
-- In columns below: who reads/writes each fields? 'r'=read, 'w'=write, 'core'=main library, 'backend'=renderer backend
--- @class ImTextureData
--- @field UniqueID             int
--- @field Status               ImTextureStatus
--- @field BackendUserData      any
--- @field QueueUserData        any
--- @field TexID                ImTextureID
--- @field Format               ImTextureFormat
--- @field Width                int
--- @field Height               int
--- @field BytesPerPixel        int
--- @field Pixels               unsigned_char[]
--- @field UsedRect             ImTextureRect
--- @field UpdateRect           ImTextureRect
--- @field Updates              ImVector<ImTextureRect>
--- @field UnusedFrames         int
--- @field RefCount             unsigned_short
--- @field UseColors            bool
--- @field WantDestroyNextFrame bool
MT.ImTextureData = {}
MT.ImTextureData.__index = MT.ImTextureData

--- @return ImTextureData
--- @nodiscard
function ImTextureData()
    --- @type ImTextureData
    local this = setmetatable({}, MT.ImTextureData)

    -------------------------------------------- core / backend ---------------------------------------
    this.UniqueID             = 0 -- w    -   -- [DEBUG] Sequential index to facilitate identifying a texture when debugging/printing. Unique per atlas.
    this.Status               = ImTextureStatus.Destroyed -- rw   rw  -- ImTextureStatus.OK/_WantCreate/_WantUpdates/_WantDestroy. Always use SetStatus() to modify!
    this.BackendUserData      = nil -- -    rw  -- Convenience storage for backend. Some backends may have enough with TexID.
    this.QueueUserData        = nil -- r    -   -- Convenience storage for a staged/multi-threaded rendering texture queue (e.g. imgui_threaded_rendering.h. See #8597). When ~= nil, core assumes the texture is referenced by the queue.
    this.TexID                = ImTextureID_Invalid -- r    w   -- Backend-specific texture identifier. Always use SetTexID() to modify! The identifier will stored in ImDrawCmd::GetTexID() and passed to backend's RenderDrawData function.
    this.Format               = 0 -- w    r   -- ImTextureFormat.RGBA32 (default) or ImTextureFormat.Alpha8
    this.Width                = 0 -- w    r   -- Texture width
    this.Height               = 0 -- w    r   -- Texture height
    this.BytesPerPixel        = 0 -- w    r   -- 4 or 1
    this.Pixels               = nil -- w    r   -- Pointer to whole texture buffer holding 'Width*Height' pixels and 'Width*Height*BytesPerPixels' bytes.
    this.UsedRect             = ImTextureRect() -- w    r   -- Bounding box encompassing all past and queued Updates[].
    this.UpdateRect           = ImTextureRect() -- w    r   -- Bounding box encompassing all queued Updates[].
    this.Updates              = ImVector() -- w    r   -- Array of individual updates.
    this.UnusedFrames         = 0 -- w    r   -- In order to facilitate handling Status==WantDestroy in some backend: this is a count successive frames where the texture was not used. Always >0 when Status==WantDestroy.
    this.RefCount             = 0 -- w    r   -- Number of contexts using this texture. Used during backend shutdown.
    this.UseColors            = false -- w    r   -- Tell whether our texture data is known to use colors (rather than just white + alpha).
    this.WantDestroyNextFrame = false -- rw   -   -- [Internal] Queued to set ImTextureStatus.WantDestroy next frame. May still be used in the current frame.

    return this
end

--- @param x int
--- @param y int
function MT.ImTextureData:GetPixels() IM_ASSERT(self.Pixels ~= nil); return self.Pixels end
function MT.ImTextureData:GetPixelsAt(x, y)
    return self.Pixels, (x + y * self.Width) * self.BytesPerPixel + 1
end

function MT.ImTextureData:GetSizeInBytes() return self.Width * self.Height * self.BytesPerPixel end
function MT.ImTextureData:GetPitch() return self.Width * self.BytesPerPixel end
function MT.ImTextureData:GetTexRef() local tex_ref = ImTextureRef(); tex_ref._TexData = self; tex_ref._TexID = ImTextureID_Invalid; return tex_ref end
function MT.ImTextureData:GetTexID() return self.TexID end

--- @param tex_id ImTextureID
function MT.ImTextureData:SetTexID(tex_id) self.TexID = tex_id end

--- @param status ImTextureStatus
function MT.ImTextureData:SetStatus(status) self.Status = status if (status == ImTextureStatus.Destroyed and not self.WantDestroyNextFrame and self.Pixels ~= nil) then self.Status = ImTextureStatus.WantCreate end end

-------------------------------------------------------------------------------
-- [SECTION] Texture identifiers (ImTextureID, ImTextureRef)
-------------------------------------------------------------------------------

-- ImTextureRef = higher-level identifier for a texture. Store a ImTextureID _or_ a ImTextureData*.
-- The identifier is valid even before the texture has been uploaded to the GPU/graphics system.
-- This is what gets passed to functions such as `ImGui.Image()`, `ImDrawList::AddImage()`.
-- This is what gets stored in draw commands (`ImDrawCmd`) to identify a texture during rendering.
--- @class ImTextureRef
--- @field _TexData? ImTextureData
--- @field _TexID    ImTextureID
MT.ImTextureRef = {}
MT.ImTextureRef.__index = MT.ImTextureRef

--- @return ImTextureRef
--- @nodiscard
function ImTextureRef(tex_id)
    return setmetatable({
        -- Members (either are set, never both!)
        _TexData = nil, -- A texture, generally owned by a ImFontAtlas. Will convert to ImTextureID during render loop, after texture has been uploaded.
        _TexID   = tex_id or ImTextureID_Invalid -- _OR_ Low-level backend texture identifier, if already uploaded or created by user/app. Generally provided to e.g. ImGui.Image() calls.
    }, MT.ImTextureRef)
end

-- This is provided for consistency (but we don't actually use this)
--- @return ImTextureID
function MT.ImTextureRef:GetTexID()
    IM_ASSERT(not (self._TexData ~= nil and self._TexID ~= ImTextureID_Invalid))
    if self._TexData then return self._TexData.TexID else return self._TexID end
end

-------------------------------------------------------------------------------
-- [SECTION] Font API (ImFontConfig, ImFontGlyph, ImFontGlyphRangesBuilder, ImFontAtlasFlags, ImFontAtlas, ImFontBaked, ImFont)
-------------------------------------------------------------------------------

-- Font runtime data for a given size
-- Important: pointers to ImFontBaked are only valid for the current frame.
--- @class ImFontBaked
--- @field IndexAdvanceX        ImVector<float>       # Glyphs->AdvanceX in a directly indexable way. Note that codepoint starts from 0, so IndexAdvanceX.Data[0 + 1] holds the advanceX of glyph at codepoint 0
--- @field FallbackAdvanceX     float
--- @field Size                 float
--- @field RasterizerDensity    float
--- @field IndexLookup          ImVector<ImU16>       # Index glyphs by Unicode codepoint. use IndexLookup.Data[codepoint + 1] for codepoint. Stores 1-based index!
--- @field Glyphs               ImVector<ImFontGlyph>
--- @field FallbackGlyphIndex   int                   # Initial value = -1, then becomes 1-based index if fallback char is set
--- @field Ascent               float
--- @field Descent              float
--- @field MetricsTotalSurface  unsigned_int
--- @field WantDestroy          bool
--- @field LoadNoFallback       bool
--- @field LoadNoRenderOnLayout bool
--- @field LastUsedFrame        int
--- @field BakedId              ImGuiID
--- @field OwnerFont            ImFont
--- @field FontLoaderDatas      any
MT.ImFontBaked = {}
MT.ImFontBaked.__index = MT.ImFontBaked

--- @return ImFontBaked
--- @nodiscard
function ImFontBaked()
    --- @type ImFontBaked
    local this = setmetatable({}, MT.ImFontBaked)

    -- [Internal] Members: Hot ~20/24 bytes (for CalcTextSize)
    this.IndexAdvanceX     = ImVector() -- 12-16 -- out -- Sparse. Glyphs->AdvanceX in a directly indexable way (cache-friendly for CalcTextSize functions which only this info, and are often bottleneck in large UI).
    this.FallbackAdvanceX  = 0 -- 4     -- out -- FindGlyph(FallbackChar)->AdvanceX
    this.Size              = 0 -- 4     -- in  -- Height of characters/line, set during loading (doesn't change after loading)
    this.RasterizerDensity = 0 -- 4     -- in  -- Density this is baked at

    -- [Internal] Members: Hot ~28/36 bytes (for RenderText loop)
    this.IndexLookup        = ImVector() -- 12-16 -- out -- Sparse. Index glyphs by Unicode code-point.
    this.Glyphs             = ImVector() -- 12-16 -- out -- All glyphs.
    this.FallbackGlyphIndex = -1 -- 4     -- out -- Index of FontFallbackChar

    -- [Internal] Members: Cold
    this.Ascent               = 0 -- 4+4   -- out -- Ascent: distance from top to bottom of e.g. 'A' [0..FontSize] (unscaled)
    this.Descent              = 0
    this.MetricsTotalSurface  = 0
    this.WantDestroy          = false
    this.LoadNoFallback       = false
    this.LoadNoRenderOnLayout = false
    this.LastUsedFrame        = 0 -- 4  --     -- Record of that time this was bounds
    this.BakedId              = 0 -- 4     --     -- Unique ID for this baked storage
    this.OwnerFont            = nil -- 4-8   -- in  -- Parent font
    this.FontLoaderDatas      = nil -- 4-8   --     -- Font loader opaque storage (per baked font * sources): single contiguous buffer allocated by imgui, passed to loader.

    return this
end

-- Font runtime data and rendering
-- - ImFontAtlas automatically loads a default embedded font for you if you didn't load one manually.
-- - Since 1.92.0 a font may be rendered as any size! Therefore a font doesn't have one specific size.
-- - Use 'font->GetFontBaked(size)' to retrieve the ImFontBaked* corresponding to a given size.
-- - If you used g.Font + g.FontSize (which is frequent from the ImGui layer), you can use g.FontBaked as a shortcut, as g.FontBaked == g.Font->GetFontBaked(g.FontSize).
--- @class ImFont
--- @field LastBaked                ImFontBaked
--- @field OwnerAtlas               ImFontAtlas
--- @field Flags                    ImFontFlags
--- @field CurrentRasterizerDensity float
--- @field FontId                   ImGuiID
--- @field LegacySize               float
--- @field Sources                  ImVector<ImFontConfig>
--- @field EllipsisChar             ImWchar
--- @field FallbackChar             ImWchar
--- @field Used8kPagesMap           ImU8[]                 # 1-based table
--- @field EllipsisAutoBake         bool
--- @field RemapPairs               table<ImGuiID, any>    # LUA: No ImGuiStorage
--- @field Scale                    float
MT.ImFont = {}
MT.ImFont.__index = MT.ImFont

function MT.ImFont:IsLoaded() return self.OwnerAtlas ~= nil end
function MT.ImFont:GetDebugName() if self.Sources.Size > 0 then return self.Sources[1].Name else return "<unknown>" end end

--- @return ImFont
--- @nodiscard
function ImFont()
    --- @type ImFont
    local this = setmetatable({}, MT.ImFont)

    -- [Internal] Members: Hot ~12-20 bytes
    this.LastBaked                = nil -- 4-8   -- Cache last bound baked. NEVER USE DIRECTLY. Use GetFontBaked().
    this.OwnerAtlas               = nil -- 4-8   -- What we have been loaded into.
    this.Flags                    = 0 -- 4     -- Font flags.
    this.CurrentRasterizerDensity = 0 -- Current rasterizer density. This is a varying state of the font.
    -- [Internal] Members: Cold ~24-52 bytes
    -- Conceptually Sources[] is the list of font sources merged to create this font.
    this.FontId           = 0 -- Unique identifier for the font
    this.LegacySize       = 0 -- 4     -- in  -- Font size passed to AddFont(). Use for old code calling PushFont() expecting to use that size. (use ImGui.GetFontBaked() to get font baked at current bound size).
    this.Sources          = ImVector() -- 16    -- in  -- List of sources. Pointers within OwnerAtlas->Sources[]
    this.EllipsisChar     = 0 -- 2-4   -- out -- Character used for ellipsis rendering ('...'). If you ever want to temporarily swap this for an alternative/dummy char, make sure to clear EllipsisAutoBake.
    this.FallbackChar     = 0 -- 2-4   -- out -- Character used if a glyph isn't found (U+FFFD, '?')
    this.Used8kPagesMap   = {}
    this.EllipsisAutoBake = false -- 1     --     -- Mark when the "..." glyph (== EllipsisChar) needs to be generated by combining multiple '.'.
    this.RemapPairs       = {} -- 16    --     -- Remapping pairs when using AddRemapCodepointXXX().
    this.Scale            = 0

    return this
end

-- A font input/source (we may rename this to ImFontSource in the future)
--- @class ImFontConfig
--- @field Name                 string
--- @field FontData             table
--- @field FontDataSize         int
--- @field FontDataOwnedByAtlas bool
--- @field MergeMode            bool
--- @field PixelSnapH           bool
--- @field OversampleH          ImS8
--- @field OversampleV          ImS8
--- @field EllipsisChar         ImWchar
--- @field SizePixels           float
--- @field GlyphRanges          ImWchar[]
--- @field GlyphExcludeRanges   ImWchar[]
--- @field GlyphOffset          ImVec2
--- @field GlyphMinAdvanceX     float
--- @field GlyphMaxAdvanceX     float
--- @field GlyphExtraAdvanceX   float
--- @field FontNo               ImU32
--- @field FontLoaderFlags      unsigned_int
--- @field RasterizerMultiply   float
--- @field RasterizerDensity    float
--- @field ExtraSizeScale       float
--- @field Flags                ImFontFlags
--- @field DstFont              ImFont
--- @field FontLoader           ImFontLoader
--- @field FontLoaderData       any
local IM_FONT_CONFIG = {}
IM_FONT_CONFIG.__index = IM_FONT_CONFIG

--- @return ImFontConfig
--- @nodiscard
function ImFontConfig()
    --- @type ImFontConfig
    local this = setmetatable({}, IM_FONT_CONFIG)

    -- Data Source
    this.Name                 = nil -- <auto>   -- Name (strictly to ease debugging, hence limited size buffer)
    this.FontData             = nil -- TTF/OTF data
    this.FontDataSize         = 0 -- TTF/OTF data size
    this.FontDataOwnedByAtlas = true -- true     -- TTF/OTF data ownership taken by the owner ImFontAtlas (will delete memory itself). SINCE 1.92, THE DATA NEEDS TO PERSIST FOR WHOLE DURATION OF ATLAS.

    -- Options
    this.MergeMode          = false -- false    -- Merge into previous ImFont, so you can combine multiple inputs font into one ImFont (e.g. ASCII font + icons + Japanese glyphs). You may want to use GlyphOffset.y when merge font of different heights.
    this.PixelSnapH         = false -- false    -- Align every glyph AdvanceX to pixel boundaries. Prevents fractional font size from working correctly! Useful e.g. if you are merging a non-pixel aligned font with the default font. If enabled, OversampleH/V will default to 1.
    this.OversampleH        = 0 -- 0 (2)    -- Rasterize at higher quality for sub-pixel positioning. 0 == auto == 1 or 2 depending on size. Note the difference between 2 and 3 is minimal. You can reduce this to 1 for large glyphs save memory. Read https://github.com/nothings/stb/blob/master/tests/oversample/README.md for details.
    this.OversampleV        = 0 -- 0 (1)    -- Rasterize at higher quality for sub-pixel positioning. 0 == auto == 1. This is not really useful as we don't use sub-pixel positions on the Y axis.
    this.EllipsisChar       = 0 -- 0        -- Explicitly specify Unicode codepoint of ellipsis character. When fonts are being merged first specified ellipsis will be used.
    this.SizePixels         = 0 -- Output size in pixels for rasterizer (more or less maps to the resulting font height).
    this.GlyphRanges        = nil -- nil     -- *LEGACY* THE ARRAY DATA NEEDS TO PERSIST AS LONG AS THE FONT IS ALIVE. Pointer to a user-provided list of Unicode range (2 value per range, values are inclusive, zero-terminated list).
    this.GlyphExcludeRanges = nil -- nil     -- Pointer to a small user-provided list of Unicode ranges (2 value per range, values are inclusive, zero-terminated list). This is very close to GlyphRanges[] but designed to exclude ranges from a font source, when merging fonts with overlapping glyphs. Use "Input Glyphs Overlap Detection Tool" to find about your overlapping ranges.
    this.GlyphOffset        = ImVec2() -- 0, 0     -- Offset (in pixels) all glyphs from this font input. Absolute value for default size, other sizes will scale this value.
    this.GlyphMinAdvanceX   = 0 -- 0        -- Minimum AdvanceX for glyphs, set Min to align font icons, set both Min/Max to enforce mono-space font. Absolute value for default size, other sizes will scale this value.
    this.GlyphMaxAdvanceX   = FLT_MAX -- FLT_MAX  -- Maximum AdvanceX for glyphs
    this.GlyphExtraAdvanceX = 0 -- 0        -- Extra spacing (in pixels) between glyphs. Please contact us if you are using this. -- FIXME-NEWATLAS: Intentionally unscaled
    this.FontNo             = 0 -- 0        -- Index of font within TTF/OTF file
    this.FontLoaderFlags    = 0 -- 0        -- Settings for custom font builder. THIS IS BUILDER IMPLEMENTATION DEPENDENT. Leave as zero if unsure.
    this.RasterizerMultiply = 1.0 -- 1.0f     -- Linearly brighten (>1.0f) or darken (<1.0f) font output. Brightening small fonts may be a good workaround to make them more readable. This is a silly thing we may remove in the future.
    this.RasterizerDensity  = 1.0 -- 1.0f     -- [LEGACY: this only makes sense when ImGuiBackendFlags.RendererHasTextures is not supported] DPI scale multiplier for rasterization. Not altering other font metrics: makes it easy to swap between e.g. a 100% and a 400% fonts for a zooming display, or handle Retina screen. IMPORTANT: If you change this it is expected that you increase/decrease font scale roughly to the inverse of this, otherwise quality may look lowered.
    this.ExtraSizeScale     = 1.0 -- 1.0f     -- Extra rasterizer scale over SizePixels.

    -- [Internal]
    this.Flags          = 0 -- Font flags (don't use just yet, will be exposed in upcoming 1.92.X updates)
    this.DstFont        = nil -- Target font (as we merging fonts, multiple ImFontConfig may target the same font)
    this.FontLoader     = nil -- Custom font backend for this source (default source is the one stored in ImFontAtlas)
    this.FontLoaderData = nil -- Font loader opaque storage (per font config)

    return this
end

-- Load and rasterize multiple TTF/OTF fonts into a same texture. The font atlas will build a single texture holding:
--  - One or more fonts.
--  - Custom graphics data needed to render the shapes needed by Dear ImGui.
--  - Mouse cursor shapes for software cursor rendering (unless setting 'Flags |= ImFontAtlasFlags.NoMouseCursors' in the font atlas).
--  - If you don't call any AddFont*** functions, the default font embedded in the code will be loaded for you.
-- It is the rendering backend responsibility to upload texture into your graphics API:
--  - ImGui_ImplXXXX_RenderDrawData() functions generally iterate platform_io->Textures[] to create/update/destroy each ImTextureData instance.
--  - Backend then set ImTextureData's TexID and BackendUserData.
--  - Texture id are passed back to you during rendering to identify the texture. Read FAQ entry about ImTextureID/ImTextureRef for more details.
--- @class ImFontAtlas
--- @field Flags               ImFontAtlasFlags
--- @field TexDesiredFormat    ImTextureFormat
--- @field TexGlyphPadding     int
--- @field TexMinWidth         int
--- @field TexMinHeight        int
--- @field TexMaxWidth         int
--- @field TexMaxHeight        int
--- @field TexRef              ImTextureRef
--- @field TexData             ImTextureData
--- @field TexList             ImVector<ImTextureData>
--- @field Locked              bool
--- @field RendererHasTextures bool
--- @field TexPixelsUseColors  bool
--- @field TexUvScale          ImVec2
--- @field TexUvWhitePixel     ImVec2
--- @field Fonts               ImVector<ImFont>
--- @field Sources             ImVector<ImFontConfig>
--- @field TexUvLines          ImVec4[]                       # 0-based table
--- @field TexNextUniqueID     int
--- @field FontNextUniqueID    int
--- @field DrawListSharedDatas ImVector<ImDrawListSharedData>
--- @field Builder             ImFontAtlasBuilder
--- @field FontLoader          ImFontLoader
--- @field FontLoaderName      string
--- @field FontLoaderData      any
--- @field FontLoaderFlags     unsigned_int
--- @field RefCount            int
--- @field OwnerContext        ImGuiContext
MT.ImFontAtlas = {}
MT.ImFontAtlas.__index = MT.ImFontAtlas

--- @return ImFontAtlas
--- @nodiscard
function ImFontAtlas()
    --- @type ImFontAtlas
    local this = setmetatable({}, MT.ImFontAtlas)

    -- Input
    this.Flags               = 0 -- Build flags (see ImFontAtlasFlags_)
    this.TexDesiredFormat    = ImTextureFormat.RGBA32 -- Desired texture format (default to ImTextureFormat.RGBA32 but may be changed to ImTextureFormat.Alpha8).
    this.TexGlyphPadding     = 1 -- FIXME: Should be called "TexPackPadding". Padding between glyphs within texture in pixels. Defaults to 1. If your rendering method never relies on bilinear filtering you may set this to 0.
    this.TexMinWidth         = 512 -- Minimum desired texture width. Must be a power of two. Default to 512.
    this.TexMinHeight        = 128 -- Minimum desired texture height. Must be a power of two. Default to 128.
    this.TexMaxWidth         = 8192 -- Maximum desired texture width. Must be a power of two. Default to 8192.
    this.TexMaxHeight        = 8192 -- Maximum desired texture height. Must be a power of two. Default to 8192.

    this.TexRef              = ImTextureRef()

    this.TexData             = nil -- Latest texture.

    -- [Internal]
    this.TexList             = ImVector() -- Texture list (most often TexList.Size == 1). TexData is always == TexList.back(). DO NOT USE DIRECTLY, USE GetDrawData().Textures[]/GetPlatformIO().Textures[] instead!
    this.Locked              = false -- Marked as locked during ImGui.NewFrame()..EndFrame() scope if TexUpdates are not supported. Any attempt to modify the atlas will assert.
    this.RendererHasTextures = false -- Copy of (BackendFlags & ImGuiBackendFlags.RendererHasTextures) from supporting context.
    this.TexPixelsUseColors  = nil -- Tell whether our texture data is known to use colors (rather than just alpha channel), in order to help backend select a format or conversion process.
    this.TexUvScale          = nil -- = (1.0f/TexData->TexWidth, 1.0f/TexData->TexHeight). May change as new texture gets created.
    this.TexUvWhitePixel     = nil -- Texture coordinates to a white pixel. May change as new texture gets created.
    this.Fonts               = ImVector() -- Hold all the fonts returned by AddFont*. Fonts[0] is the default font upon calling ImGui.NewFrame(), use ImGui.PushFont()/PopFont() to change the current font.
    this.Sources             = ImVector() -- Source/configuration data
    this.TexUvLines          = {}
    this.TexNextUniqueID     = 1 -- Next value to be stored in TexData->UniqueID
    this.FontNextUniqueID    = 1 -- Next value to be stored in ImFont->FontID
    this.DrawListSharedDatas = ImVector() -- List of users for this atlas. Typically one per Dear ImGui context.
    this.Builder             = nil -- Opaque interface to our data that doesn't need to be public and may be discarded when rebuilding.
    this.FontLoader          = nil -- Font loader opaque interface (default to use FreeType when IMGUI_ENABLE_FREETYPE is defined, otherwise default to use stb_truetype). Use SetFontLoader() to change this at runtime.
    this.FontLoaderName      = nil -- Font loader name (for display e.g. in About box) == FontLoader->Name
    this.FontLoaderData      = nil -- Font backend opaque storage
    this.FontLoaderFlags     = nil -- Shared flags (for all fonts) for font loader. THIS IS BUILD IMPLEMENTATION DEPENDENT (e.g. Per-font override is also available in ImFontConfig).
    this.RefCount            = 0 -- Number of contexts using this atlas
    this.OwnerContext        = nil -- Context which own the atlas will be in charge of updating and destroying it.

    return this
end

-- Output of ImFontAtlas::GetCustomRect() when using custom rectangles.
-- Those values may not be cached/stored as they are only valid for the current value of atlas->TexRef
-- (this is in theory derived from ImTextureRect but we use separate structures for reasons)
--- @class ImFontAtlasRect
--- @field x   unsigned_short
--- @field y   unsigned_short
--- @field w   unsigned_short
--- @field h   unsigned_short
--- @field uv0 ImVec2
--- @field uv1 ImVec2

-- An opaque identifier to a rectangle in the atlas. -1 when invalid.
-- The rectangle may move and UV may be invalidated, use GetCustomRect() to retrieve it.
--- @alias ImFontAtlasRectId int

ImFontAtlasRectId_Invalid = -1

--- @return ImFontAtlasRect
--- @nodiscard
function ImFontAtlasRect()
    return {
        x = nil, y = nil, -- Position (in current texture)
        w = nil, h = nil, -- Size
        uv0 = ImVec2(), -- UV coordinates (in current texture)
        uv1 = ImVec2()
    }
end

-- Hold rendering data for one glyph.
--- @class ImFontGlyph
--- @field Colored   boolean
--- @field Visible   boolean
--- @field SourceIdx unsigned_int
--- @field Codepoint unsigned_int
--- @field AdvanceX  float
--- @field X0        float
--- @field Y0        float
--- @field X1        float
--- @field Y1        float
--- @field U0        float
--- @field V0        float
--- @field U1        float
--- @field V1        float
--- @field PackId    int

--- @return ImFontGlyph
--- @nodiscard
function ImFontGlyph()
    return {
        Colored   = false,
        Visible   = false,
        SourceIdx = 0,
        Codepoint = 0,
        AdvanceX  = 0, -- Horizontal distance to advance cursor/layout position.

        X0 = 0, Y0 = 0, X1 = 0, Y1 = 0, -- Glyph corners. Offsets from current cursor/layout position.
        U0 = 0, V0 = 0, U1 = 0, V1 = 0, -- Texture coordinates for the current value of ImFontAtlas->TexRef. Cached equivalent of calling GetCustomRect() with PackId.

        PackId = -1 -- [Internal] ImFontAtlasRectId value (FIXME: Cold data, could be moved elsewhere?)
    }
end

-- Helper to build glyph ranges from text/string data. Feed your application strings/characters to it then call BuildRanges().
-- This is essentially a tightly packed of vector of 64k booleans = 8KB storage.
--- @class ImFontGlyphRangesBuilder
--- @field UsedChars ImVector<ImU32> # Store 1-bit per Unicode code point (0=unused, 1=used)
MT.ImFontGlyphRangesBuilder = {}
MT.ImFontGlyphRangesBuilder.__index = MT.ImFontGlyphRangesBuilder

--- @return ImFontGlyphRangesBuilder
--- @nodiscard
function ImFontGlyphRangesBuilder()
    local this = setmetatable({ UsedChars = ImVector() }, MT.ImFontGlyphRangesBuilder)
    this:Clear()
    return this
end

function MT.ImFontGlyphRangesBuilder:Clear()
    local size_in_bytes = (IM_UNICODE_CODEPOINT_MAX + 1) / 8
    self.UsedChars:resize(size_in_bytes / 4)
    local data = self.UsedChars.Data
    for i = 1, self.UsedChars.Size do data[i] = 0 end
end
-- Get bit n in the array
function MT.ImFontGlyphRangesBuilder:GetBit(n) local off = bit32.rshift(n, 5); local mask = bit32.lshift(1, bit32.band(n, 31)); return bit32.band(self.UsedChars.Data[off + 1], mask) ~= 0 end
-- Set bit n in the array
function MT.ImFontGlyphRangesBuilder:SetBit(n) local off = bit32.rshift(n, 5); local mask = bit32.lshift(1, bit32.band(n, 31)); self.UsedChars.Data[off + 1] = bit32.bor(self.UsedChars.Data[off + 1], mask) end
-- Add character
function MT.ImFontGlyphRangesBuilder:AddChar(c) self:SetBit(c) end

-------------------------------------------------------------------------------
-- [SECTION] ImGuiIO
-------------------------------------------------------------------------------

-- Communicate most settings and inputs/outputs to Dear ImGui using this structure.
-- Access via ImGui.GetIO(). Read 'Programmer guide' section in .cpp file for general usage.
-- It is generally expected that:
-- - initialization: backends and user code writes to ImGuiIO.
-- - main loop: backends writes to ImGuiIO, user code and imgui code reads from ImGuiIO.
-------------------------------------------------------------------------------
-- Also see ImGui.GetPlatformIO() and ImGuiPlatformIO struct for OS/platform related functions: clipboard, IME etc.
-------------------------------------------------------------------------------

-- [Internal] Storage used by IsKeyDown(), IsKeyPressed() etc functions.
-- If prior to 1.87 you used io.KeysDownDuration[] (which was marked as internal), you should use GetKeyData(key)->DownDuration and *NOT* io.KeysData[key]->DownDuration.
--- @class ImGuiKeyData
--- @field Down             bool
--- @field DownDuration     float
--- @field DownDurationPrev float
--- @field AnalogValue      float

--- @return ImGuiKeyData
--- @nodiscard
function ImGuiKeyData() return { Down = false, DownDuration = 0.0, DownDurationPrev = 0.0, AnalogValue = 0.0 } end

-- Configuration flags stored in io.ConfigFlags. Set by user/application.
-- Note that nowadays most of our configuration options are in other ImGuiIO fields, e.g. io.ConfigWindowsMoveFromTitleBarOnly.
--- @enum ImGuiConfigFlags
ImGuiConfigFlags = {
    None                = 0,
    NavEnableKeyboard   = bitLShift(1, 0),
    NavEnableGamepad    = bitLShift(1, 1),
    NoMouse             = bitLShift(1, 4),
    NoMouseCursorChange = bitLShift(1, 5),
    NoKeyboard          = bitLShift(1, 6),
    DockingEnable       = bitLShift(1, 7),
    ViewportsEnable     = bitLShift(1, 10),
    IsSRGB              = bitLShift(1, 20),
    IsTouchScreen       = bitLShift(1, 21)
}

--- @class ImGuiIO
MT.ImGuiIO = {}
MT.ImGuiIO.__index = MT.ImGuiIO

--- @return ImGuiIO
function ImGuiIO()
    local this = {
        Ctx = nil, -- Parent UI context (needs to be set explicitly by parent).

        KeyCtrl  = false, -- Keyboard modifier down: Ctrl (non-macOS), Cmd (macOS)
        KeyShift = false, -- Keyboard modifier down: Shift
        KeyAlt   = false, -- Keyboard modifier down: Alt
        KeySuper = false, -- Keyboard modifier down: Windows/Super (non-macOS), Ctrl (macOS)

        -- Other state maintained from data above + IO function calls
        KeyMods  = nil, -- Key mods flags (any of ImGuiMod_Ctrl/ImGuiMod_Shift/ImGuiMod_Alt/ImGuiMod_Super flags, same as io.KeyCtrl/KeyShift/KeyAlt/KeySuper but merged into flags). Read-only, updated by NewFrame()

        BackendPlatformName = nil, -- = NULL
        BackendRendererName = nil, -- = NULL
        BackendFlags = ImGuiBackendFlags.None, -- = 0              -- See ImGuiBackendFlags_ enum. Set by backend (imgui_impl_xxx files or custom backend) to communicate features supported by the backend.
        ConfigFlags  = ImGuiConfigFlags.None, -- = 0              -- See ImGuiConfigFlags_ enum. Set by user/application. Keyboard/Gamepad navigation options, etc.
        DisplaySize = ImVec2(-1.0, -1.0), -- <unset>          -- Main display size, in pixels (== GetMainViewport()->Size). May change every frame.

        DeltaTime = 1.0 / 60.0, -- = 1.0f/60.0f     -- Time elapsed since last frame, in seconds. May change every frame.

        DisplayFramebufferScale = ImVec2(1.0, 1.0), -- = (1, 1)         -- Main display density. For retina display where window coordinates are different from framebuffer coordinates. This will affect font density + will end up in ImDrawData::FramebufferScale.

        -- Font system
        FontAllowUserScaling = false, -- = false          -- Allow user scaling text of individual window with Ctrl+Wheel.

        -- Main Input State
        -- (this block used to be written by backend, since 1.87 it is best to NOT write to those directly, call the AddXXX functions above instead)
        -- (reading from those variables is fair game, as they are extremely unlikely to be moving anywhere)
        MousePos = ImVec2(), -- Mouse position, in pixels. Set to ImVec2(-FLT_MAX, -FLT_MAX) if mouse is unavailable (on another screen, etc.)
        MousePosPrev = ImVec2(), -- Previous mouse position (note that MouseDelta is not necessary == MousePos-MousePosPrev, in case either position is invalid)

        WantSetMousePos = false, -- MousePos has been altered, backend should reposition mouse on next frame. Rarely used! Set only when io.ConfigNavMoveSetMousePos is enabled.

        MouseDelta = ImVec2(), -- Mouse delta. Note that this is zero if either current or previous position are invalid (-FLT_MAX,-FLT_MAX), so a disappearing/reappearing mouse won't have a huge delta.

        MouseDown = {[0] = false, [1] = false, [2] = false, [3] = false, [4] = false}, -- Mouse buttons: 0=left, 1=right, 2=middle + extras (ImGuiMouseButton.COUNT == 5). Dear ImGui mostly uses left and right buttons. Other buttons allow us to track if the mouse is being used by your application + available to user as a convenience via IsMouse** API.

        MouseWheel = 0, -- Mouse wheel Vertical: 1 unit scrolls about 5 lines text. >0 scrolls Up, <0 scrolls Down. Hold Shift to turn vertical scroll into horizontal scroll.
        MouseWheelH = 0, -- Mouse wheel Horizontal. >0 scrolls Left, <0 scrolls Right. Most users don't have a mouse with a horizontal wheel, may not be filled by all backends.

        MouseCtrlLeftAsRightClick = false, -- (OSX) Set to true when the current click was a Ctrl+Click that spawned a simulated right click
        MouseSource = ImGuiMouseSource.Mouse, -- Mouse actual input peripheral (Mouse/TouchScreen/Pen).
        PenPressure = 0.0, -- Touch/Pen pressure (0.0f to 1.0f, should be >0.0f only when MouseDown[0] == true). Helper storage currently unused by Dear ImGui.

        MouseWheelRequestAxisSwap = false, -- On a non-Mac system, holding Shift requests WheelY to perform the equivalent of a WheelX event. On a Mac system this is already enforced by the system.

        ConfigColorEditFlags = ImGuiColorEditFlags.DefaultOptions_, -- = <defaults>     -- Current settings for ColorEdit/ColorPicker widgets. Must have one bit of ImGuiColorEditFlags.DisplayMask_, one bit of ImGuiColorEditFlags.DataTypeMask_, one bit of ImGuiColorEditFlags.PickerMask_, one bit of ImGuiColorEditFlags.InputMask_. Defaults to ImGuiColorEditFlags.DefaultOptions_. May be further edited by users, unless you also set ImGuiColorEditFlags.NoOptions.

        -- Widget options
        ConfigMacOSXBehaviors = false, -- Swap Cmd<>Ctrl keys + OS X style text editing cursor movement using Alt instead of Ctrl, Shortcuts using Cmd/Super instead of Ctrl, Line/Text Start and End using Cmd+Arrows instead of Home/End, Double click selects by word instead of selecting whole text, Multi-selection in lists uses Cmd/Super instead of Ctrl.
        ConfigNavCursorVisibleAuto = true, -- = true           -- Using directional navigation key makes the cursor visible. Mouse click hides the cursor.
        ConfigNavCursorVisibleAlways = false, -- = false          -- Navigation cursor is always visible.
        ConfigInputTrickleEventQueue = true, -- = true           -- Enable input queue trickling: some types of events submitted during the same frame (e.g. button down + up) will be spread over multiple frames, improving interactions with low framerates.
        ConfigWindowsResizeFromEdges = true, -- = true           -- Enable resizing of windows from their edges and from the lower-left corner. This requires ImGuiBackendFlags.HasMouseCursors for better mouse cursor feedback. (This used to be a per-window ImGuiWindowFlags.ResizeFromAnySide flag)

        ConfigDebugIniSettings = false, -- = false          -- Save .ini data with extra comments (particularly helpful for Docking, but makes saving slower)
        ConfigWindowsCopyContentsWithCtrlC = false, -- = false      -- [EXPERIMENTAL] Ctrl+C copy the contents of focused window into the clipboard. Experimental because: (1) has known issues with nested Begin/End pairs (2) text output quality varies (3) text output is in submission order rather than spatial order.
        ConfigWindowsMoveFromTitleBarOnly = false, -- = false      -- Enable allowing to move windows only when clicking on their title bar. Does not apply to windows without a title bar.
        ConfigScrollbarScrollByPage = true, -- = true           -- Enable scrolling page by page when clicking outside the scrollbar grab. When disabled, always scroll to clicked location. When enabled, Shift+Click scrolls to clicked location.
        ConfigInputTextCursorBlink = true, -- = true           -- Enable blinking cursor (optional as some users consider it to be distracting).
        ConfigInputTextEnterKeepActive = false, -- = false          -- [BETA] Pressing Enter will reactivate item and select all text (single-line only). Ctrl+Enter or Shift+Enter will deactivate normally.
        ConfigDragClickToInputText = false, -- = false          -- [BETA] Enable turning DragXXX widgets into text input with a simple mouse click-release (without moving). Not desirable on devices without a keyboard.

        -- Keyboard/Gamepad Navigation options
        ConfigNavSwapGamepadButtons = false, -- = false          -- Swap Activate<>Cancel (A<>B) buttons, matching typical "Nintendo/Japanese style" gamepad layout.
        ConfigNavMoveSetMousePos = false, -- = false          -- Directional/tabbing navigation teleports the mouse cursor. May be useful on TV/console systems where moving a virtual mouse is difficult. Will update io.MousePos and set io.WantSetMousePos=true.
        ConfigNavCaptureKeyboard = true, -- = true           -- Sets io.WantCaptureKeyboard when io.NavActive is set.
        ConfigNavEscapeClearFocusItem = true, -- = true           -- Pressing Escape can clear focused item + navigation id/highlight. Set to false if you want to always keep highlight on.
        ConfigNavEscapeClearFocusWindow = false, -- = false          -- Pressing Escape can clear focused window as well (super set of io.ConfigNavEscapeClearFocusItem).

        -- DPI/Scaling options
        ConfigDpiScaleFonts = false, -- = false          -- [EXPERIMENTAL] Automatically overwrite style.FontScaleDpi when Monitor DPI changes. This will scale fonts but _NOT_ scale sizes/padding for now.
        ConfigDpiScaleViewports = false, -- = false          -- [EXPERIMENTAL] Scale Dear ImGui and Platform Windows when Monitor DPI changes.

        -- Ini Settings options
        ConfigIniSettingsSaveLastUsedDate = true, -- = true         -- Enable loading/saving last used day (YYYYMMDD) in some .ini struct, making things easier to audit and allowing custom tools to cleanup old data.
        ConfigIniSettingsAutoDiscardMonths = 0, -- = 0          -- [BETA] Set number of months after which unused .ini entries are discarded on load. Require platform_io.Platform_SessionDate to be set. For systems supporting the feature, .ini entries without a LastUsed field will always be discarded! Please report if you are using this.
        -- Options to configure Error Handling and how we handle recoverable errors [EXPERIMENTAL]
        -- - Error recovery is provided as a way to facilitate:
        --    - Recovery after a programming error (native code or scripting language - the latter tends to facilitate iterating on code while running).
        --    - Recovery after running an exception handler or any error processing which may skip code after an error has been detected.
        -- - Error recovery is not perfect nor guaranteed! It is a feature to ease development.
        --   You not are not supposed to rely on it in the course of a normal application run.
        -- - Functions that support error recovery are using IM_ASSERT_USER_ERROR() instead of IM_ASSERT().
        -- - By design, we do NOT allow error recovery to be 100% silent. One of the three options needs to be checked!
        -- - Always ensure that on programmers seats you have at minimum Asserts or Tooltips enabled when making direct imgui API calls!
        --   Otherwise it would severely hinder your ability to catch and correct mistakes!
        -- Read https://github.com/ocornut/imgui/wiki/Error-Handling for details.
        -- - Programmer seats: keep asserts (default), or disable asserts and keep error tooltips (new and nice!)
        -- - Non-programmer seats: maybe disable asserts, but make sure errors are resurfaced (tooltips, visible log entries, use callback etc.)
        -- - Recovery after error/exception: record stack sizes with ErrorRecoveryStoreState(), disable assert, set log callback (to e.g. trigger high-level breakpoint), recover with ErrorRecoveryTryToRecoverState(), restore settings.
        ConfigErrorRecovery = true, -- = true       -- Enable error recovery support. Some errors won't be detected and lead to direct crashes if recovery is disabled.
        ConfigErrorRecoveryEnableAssert = true, -- = true       -- Enable asserts on recoverable error. By default call IM_ASSERT() when returning from a failing IM_ASSERT_USER_ERROR()
        ConfigErrorRecoveryEnableDebugLog = true, -- = true       -- Enable debug log output on recoverable errors.
        ConfigErrorRecoveryEnableTooltip = true, -- = true       -- Enable tooltip on recoverable errors. The tooltip include a way to enable asserts if they were disabled.
        -- Tools to detect code submitting items with conflicting/duplicate IDs
        -- - Code should use PushID()/PopID() in loops, or append "##xx" to same-label identifiers.
        -- - Empty label e.g. Button("") == same ID as parent widget/node. Use Button("##xx") instead!
        -- - See FAQ https://github.com/ocornut/imgui/blob/master/docs/FAQ.md#q-about-the-id-stack-system
        ConfigDebugHighlightIdConflicts = false, -- Highlight and show an error message popup when multiple items have conflicting identifiers.
        ConfigDebugHighlightIdConflictsShowItemPicker = true, -- =true -- Show "Item Picker" button in aforementioned popup.
        ConfigDebugIsDebuggerPresent = false, -- = false          -- Enable various tools calling IM_DEBUG_BREAK().
        -- Tools to test correct Begin/End and BeginChild/EndChild behaviors.
        ConfigDebugBeginReturnValueOnce = false, -- = false          -- First-time calls to Begin()/BeginChild() will return false. NEEDS TO BE SET AT APPLICATION BOOT TIME if you don't want to miss windows.
        ConfigDebugBeginReturnValueLoop = false, -- = false          -- Some calls to Begin()/BeginChild() will return false. Will cycle through window depths then repeat. Suggested use: add "io.ConfigDebugBeginReturnValue = io.KeyShift" in your main loop then occasionally press SHIFT. Windows should be flickering while running.
        -- Option to deactivate io.AddFocusEvent(false) handling.
        ConfigDebugIgnoreFocusLoss = false, -- = false          -- Ignore io.AddFocusEvent(false), consequently not calling io.ClearInputKeys()/io.ClearInputMouse() in input processing.
        -- Option to compare < 1.93.0 rendering details vs 1.93.0 rendering details. (#9504)
        -- - Equivalent to calling PushDrawFlag(ImDrawList_StrokeLegacy,true) on every draw list instances.
        -- - Suggested use, e.g. io.ConfigDebugDrawListDefaultsToStrokeLegacy = io.KeyShift; // Map to SHIFT modifier
        ConfigDebugDrawListDefaultsToStrokeLegacy = false, -- false -- Default all ImDrawList to ImDrawList_StrokeLegacy mode, mimicking pre-1.93.0 rendering.

        IniFilename = "imgui.ini", -- [Port] no disk access, only used as a flag (nil disables .ini handling)
        IniSavingRate = 5.0, -- = 5.0f           -- Minimum time between saving positions/sizes to .ini file, in seconds.
        LogFilename = "imgui_log.txt", -- = "imgui_log.txt"-- Path to .log file (default parameter to ImGui.LogToFile when no file is specified).
        WantSaveIniSettings = false, -- When manual .ini load/save is active (io.IniFilename == nil), this will be set to notify your application that you can call SaveIniSettingsToMemory() and save yourself. Important: clear io.WantSaveIniSettings yourself after saving!

        -- Docking options (when ImGuiConfigFlags.DockingEnable is set)
        ConfigDockingNoSplit = false, -- = false          -- Simplified docking mode: disable window splitting, so docking is limited to merging multiple windows together into tab-bars.
        ConfigDockingNoDockingOver = false, -- = false          -- Simplified docking mode: disable window merging into a same tab-bar, so docking is limited to splitting windows.
        ConfigDockingWithShift = false, -- = false          -- Enable docking with holding Shift key (reduce visual noise, allows dropping in wider space)
        ConfigDockingAlwaysTabBar = false, -- = false          -- [BETA] [FIXME: This currently creates regression with auto-sizing and general overhead] Make every single floating window display within a docking node.
        ConfigDockingTransparentPayload = false, -- = false          -- [BETA] Make window or viewport transparent when docking and only display docking boxes on the target viewport. Useful if rendering of multiple viewport cannot be synced. Best used with ConfigViewportsNoAutoMerge.
        -- Viewport options (when ImGuiConfigFlags.ViewportsEnable is set)
        -- (sorry for the amount of "NoXXXX" flags, which may be harder to reason about! may rework someday)
        ConfigViewportsNoAutoMerge = false, -- = false;         -- Set to make all floating imgui windows always create their own viewport. Otherwise, they are merged into the main host viewports when overlapping it. May also set ImGuiViewportFlags.NoAutoMerge on individual viewport.
        ConfigViewportsNoTaskBarIcon = false, -- = false          -- Disable default OS task bar icon flag for secondary viewports. When a viewport doesn't want a task bar icon, ImGuiViewportFlags.NoTaskBarIcon will be set on it.
        ConfigViewportsNoDecoration = true, -- = true           -- Disable default OS window decoration flag for secondary viewports. When a viewport doesn't want window decorations, ImGuiViewportFlags.NoDecoration will be set on it. Enabling decoration can create subsequent issues at OS levels (e.g. minimum window size).
        ConfigViewportsNoDefaultParent = true, -- = true           -- Disable setting OS window parent to main viewport by default. The platform backend is expected to honor `viewport->ParentViewportID` to setup a parent/child relationship between the OS windows (supported if ImGuiBackendFlags.HasParentViewport is set). When parented: child windows always appear in front of their parent. Set to false if you want viewports to automatically be parent of main viewport, otherwise all viewports will be top-level OS windows. Parent/child relationship may be set on a per-window basis using ImGuiWindowClass.
        ConfigViewportsPlatformFocusSetsImGuiFocus = true, -- = true -- When a platform window is focused (e.g. using Alt+Tab, clicking Platform Title Bar), apply corresponding focus on imgui windows (may clear focus/active id from imgui windows location in other platform windows). In principle this is better enabled but we provide an opt-out, because some Linux window managers tend to eagerly focus windows (e.g. on mouse hover, or even a simple window pos/size change).

        ConfigMemoryCompactTimer = 60.0, -- = 60.0f          -- Timer (in seconds) to free transient windows/tables memory buffers when unused. Set to -1.0f to disable.

        -- Miscellaneous options
        -- (you can visualize and interact with all options in 'Demo->Configuration')
        MouseDrawCursor = false, -- = false          -- Request ImGui to draw a mouse cursor for you (if you are on a platform without a mouse cursor). Cannot be easily renamed to 'io.ConfigXXX' because this is frequently used by backend implementations.

        MouseClicked          = {[0] = false, [1] = false, [2] = false, [3] = false, [4] = false}, -- Mouse button went from !Down to Down (same as MouseClickedCount[x] != 0)
        MouseReleased         = {[0] = false, [1] = false, [2] = false, [3] = false, [4] = false}, -- Mouse button went from Down to !Down
        MouseClickedCount     = {[0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0}, -- == 0 (not clicked), == 1 (same as MouseClicked[]), == 2 (double-clicked), == 3 (triple-clicked) etc. when going from !Down to Down
        MouseClickedLastCount = {[0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0}, -- Count successive number of clicks. Stays valid after mouse release. Reset after another click is done.
        MouseDownDuration     = {[0] = -1, [1] = -1, [2] = -1, [3] = -1, [4] = -1}, -- Duration the mouse button has been down (0.0f == just clicked)
        MouseDownDurationPrev = {[0] = -1, [1] = -1, [2] = -1, [3] = -1, [4] = -1}, -- Previous time the mouse button has been down

        MouseDragMaxDistanceAbs = {[0] = ImVec2(), [1] = ImVec2(), [2] = ImVec2(), [3] = ImVec2(), [4] = ImVec2()}, -- Maximum distance, absolute, on each axis, of how much mouse has traveled from the clicking point
        MouseDragMaxDistanceSqr = {[0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0}, -- Squared maximum distance of how much mouse has traveled from the clicking point (used for moving thresholds)

        MouseDownOwned    = {[0] = nil, [1] = nil, [2] = nil, [3] = nil, [4] = nil}, -- Track if button was clicked inside a dear imgui window or over void blocked by a popup. We don't request mouse capture from the application if click started outside ImGui bounds.
        MouseDownOwnedUnlessPopupClose = {[0] = nil, [1] = nil, [2] = nil, [3] = nil, [4] = nil}, -- Track if button was clicked inside a dear imgui window.
        MouseClickedTime  = {[0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0}, -- Time of last click (used to figure out double-click)
        MouseReleasedTime = {[0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0}, -- Time of last released (rarely used! but useful to handle delayed single-click when trying to disambiguate them from double-click).
        MouseClickedPos   = {[0] = ImVec2(), [1] = ImVec2(), [2] = ImVec2(), [3] = ImVec2(), [4] = ImVec2()}, -- Position at time of clicking

        MouseDoubleClicked = {[0] = false, [1] = false, [2] = false, [3] = false, [4] = false}, -- Has mouse button been double-clicked? (same as MouseClickedCount[x] == 2)

        -- Inputs Behaviors
        -- (other variables, ones which are expected to be tweaked within UI code, are exposed in ImGuiStyle)
        MouseDoubleClickTime    = 0.30, -- = 0.30f          -- Time for consecutive clicks to account as a double-click, in seconds.
        MouseSingleClickDelay   = 0.50, -- Time for a delayed click when using GetItemClickedCountWithSingleClickDelay() or IsMouseReleasedWithDelay(), in seconds. Must be > io.MouseDoubleClickTime.
        MouseDoubleClickMaxDist = 6.0, -- = 6.0f           -- Distance threshold to stay in to validate a double-click or multiple clicks, in pixels.
        MouseDragThreshold      = 6.0, -- = 6.0f           -- Distance threshold before considering we are dragging.
        KeyRepeatDelay          = 0.275, -- = 0.275f         -- When holding a key/button, time before it starts repeating, in seconds (for buttons in Repeat mode, etc.).
        KeyRepeatRate           = 0.050, -- = 0.050f         -- When holding a key/button, rate at which it repeats, in seconds.

        KeysData = {}, -- size = ImGuiKey.NamedKey_COUNT

        WantCaptureMouse    = nil, -- Set when Dear ImGui will use mouse inputs, in this case do not dispatch them to your main game/application (either way, always pass on mouse inputs to imgui). (e.g. unclicked mouse is hovering over an imgui window, widget is active, mouse was clicked over an imgui window, etc.).
        WantCaptureKeyboard = nil, -- Set when Dear ImGui will use keyboard inputs, in this case do not dispatch them to your main game/application (either way, always pass keyboard inputs to imgui). (e.g. InputText active, or an imgui window is focused and navigation is enabled, etc.).
        WantTextInput       = nil, -- Mobile/console: when set, you may display an on-screen keyboard. This is set by Dear ImGui when it wants textual keyboard input to happen (e.g. when a InputText widget is active).

        Framerate = 0, -- Estimate of application framerate (rolling average over 60 frames, based on io.DeltaTime), in frame per second. Solely for convenience. Slow applications may not want to use a moving average or may want to reset underlying buffers occasionally.
        MetricsRenderVertices = 0, MetricsRenderIndices = 0, MetricsRenderWindows = 0, MetricsActiveWindows = 0,

        NavActive = false, -- Keyboard/Gamepad navigation is currently allowed (will handle ImGuiKey.NavXXX events) = a window is focused and it doesn't use the ImGuiWindowFlags.NoNavInputs flag.
        NavVisible = false, -- Keyboard/Gamepad navigation highlight is visible and allowed (will handle ImGuiKey.NavXXX events).

        MetricsRenderWindows = 0, -- Number of visible windows

        -- Font system
        Fonts = nil, -- <auto>           -- Font atlas: load, rasterize and pack one or more fonts into a single texture.
        FontDefault = nil, -- = nil           -- Font to use on NewFrame(). Use nil to uses Fonts->Fonts[0].

        BackendPlatformUserData = nil, -- = nil           -- User data for platform backend
        BackendRendererUserData = nil, -- = nil           -- User data for renderer backend

        InputQueueCharacters = ImVector(), -- Queue of _characters_ input (obtained by platform backend). Fill using AddInputCharacter() helper.

        AppAcceptingEvents = true, -- Only modify via SetAppAcceptingEvents()
        InputQueueSurrogate = 0 -- For AddInputCharacterUTF16()
    }

    for i = 0, ImGuiKey.NamedKey_COUNT - 1 do
        this.KeysData[i] = ImGuiKeyData()
    end

    return setmetatable(this, MT.ImGuiIO)
end

-- (Optional) Support for IME (Input Method Editor) via the platform_io.Platform_SetImeDataFn() function. Handler is called during EndFrame().
--- @class ImGuiPlatformImeData
--- @field WantVisible     bool
--- @field WantTextInput   bool
--- @field InputPos        ImVec2
--- @field InputLineHeight float
--- @field ViewportId      ImGuiID
--- @field SelectedText    string

--- @return ImGuiPlatformImeData
--- @nodiscard
function ImGuiPlatformImeData()
    return {
        WantVisible     = false, -- A widget wants the IME to be visible.
        WantTextInput   = false, -- A widget wants text input, not necessarily IME to be visible. This is automatically set to the upcoming value of io.WantTextInput.
        InputPos        = ImVec2(), -- Position of input cursor (for IME).
        InputLineHeight = 0.0, -- Line height (for IME).
        ViewportId      = 0, -- ID of platform window/viewport.
        SelectedText    = "" -- [Port] Text currently selected in the widget wanting text input (backends may mirror it, e.g. for native copy).
    }
end

--- @param dest ImGuiPlatformImeData
--- @param src  ImGuiPlatformImeData
function ImGuiPlatformImeData_Copy(dest, src)
    dest.WantVisible = src.WantVisible
    dest.WantTextInput = src.WantTextInput
    ImVec2_Copy(dest.InputPos, src.InputPos)
    dest.InputLineHeight = src.InputLineHeight
    dest.ViewportId = src.ViewportId
    dest.SelectedText = src.SelectedText -- [Port]
end

--- @param data1 ImGuiPlatformImeData
--- @param data2 ImGuiPlatformImeData
function ImGuiPlatformImeData_Compare(data1, data2)
    if data1.WantVisible ~= data2.WantVisible or
        data1.WantTextInput ~= data2.WantTextInput or
        data1.InputPos ~= data2.InputPos or
        data1.InputLineHeight ~= data2.InputLineHeight or
        data1.ViewportId ~= data2.ViewportId or
        data1.SelectedText ~= data2.SelectedText then
        return false
    end

    return true
end

-------------------------------------------------------------------------------
-- [SECTION] Viewports
-------------------------------------------------------------------------------

-- Flags stored in ImGuiViewport::Flags, giving indications to the platform backends.
--- @enum ImGuiViewportFlags
ImGuiViewportFlags = {
    None                = 0,
    IsPlatformWindow    = bitLShift(1, 0), -- Represent a Platform Window
    IsPlatformMonitor   = bitLShift(1, 1), -- Represent a Platform Monitor (unused yet)
    OwnedByApp          = bitLShift(1, 2), -- Platform Window: Is created/managed by the user application? (rather than our backend)
    NoDecoration        = bitLShift(1, 3), -- Platform Window: Disable platform decorations: title bar, borders, etc. (generally set all windows, but if ImGuiConfigFlags.ViewportsDecoration is set we only set this on popups/tooltips)
    NoTaskBarIcon       = bitLShift(1, 4), -- Platform Window: Disable platform task bar icon (generally set on popups/tooltips, or all windows if ImGuiConfigFlags.ViewportsNoTaskBarIcon is set)
    NoFocusOnAppearing  = bitLShift(1, 5), -- Platform Window: Don't take focus when created.
    NoFocusOnClick      = bitLShift(1, 6), -- Platform Window: Don't take focus when clicked on.
    NoInputs            = bitLShift(1, 7), -- Platform Window: Make mouse pass through so we can drag this window while peaking behind it.
    NoRendererClear     = bitLShift(1, 8), -- Platform Window: Renderer doesn't need to clear the framebuffer ahead (because we will fill it entirely).
    NoAutoMerge         = bitLShift(1, 9), -- Platform Window: Avoid merging this window into another host window. This can only be set via ImGuiWindowClass viewport flags override (because we need to now ahead if we are going to create a viewport in the first place!).
    TopMost             = bitLShift(1, 10), -- Platform Window: Display on top (for tooltips only).
    CanHostOtherWindows = bitLShift(1, 11), -- Viewport can host multiple imgui windows (secondary viewports are associated to a single window). -- FIXME: In practice there's still probably code making the assumption that this is always and only on the MainViewport. Will fix once we add support for "no main viewport".

    -- Output status flags (from Platform)
    IsMinimized = bitLShift(1, 12), -- Platform Window: Window is minimized, can skip render. When minimized we tend to avoid using the viewport pos/size for clipping window or testing if they are contained in the viewport.
    IsFocused   = bitLShift(1, 13) -- Platform Window: Window is focused (last call to Platform_GetWindowFocus() returned true)
}

-- - Currently represents the Platform Window created by the application which is hosting our Dear ImGui windows.
-- - With multi-viewport enabled, we extend this concept to have multiple active viewports.
-- - In the future we will extend this concept further to also represent Platform Monitor and support a "no main platform window" operation mode.
-- - About Main Area vs Work Area:
--   - Main Area = entire viewport.
--   - Work Area = entire viewport minus sections used by main menu bars (for platform windows), or by task bar (for platform monitor).
--   - Windows are generally trying to stay within the Work Area of their host viewport.
--- @class ImGuiViewport
--- @field ID                    ImGuiID
--- @field Flags                 ImGuiViewportFlags
--- @field Pos                   ImVec2
--- @field Size                  ImVec2
--- @field FramebufferScale      ImVec2
--- @field WorkPos               ImVec2
--- @field WorkSize              ImVec2
--- @field DpiScale              float
--- @field ParentViewportId      ImGuiID
--- @field ParentViewport        ImGuiViewport
--- @field DrawData              ImDrawData
--- @field RendererUserData      any
--- @field PlatformUserData      any
--- @field PlatformHandle        any
--- @field PlatformHandleRaw     any
--- @field PlatformWindowCreated bool
--- @field PlatformRequestMove   bool
--- @field PlatformRequestResize bool
--- @field PlatformRequestClose  bool
MT.ImGuiViewport = {}
MT.ImGuiViewport.__index = MT.ImGuiViewport

function MT.ImGuiViewport:GetCenter()
    return ImVec2(self.Pos.x + self.Size.x * 0.5, self.Pos.y + self.Size.y * 0.5)
end

function MT.ImGuiViewport:GetWorkCenter()
    return ImVec2(self.WorkPos.x + self.WorkSize.x * 0.5, self.WorkPos.y + self.WorkSize.y * 0.5)
end

--- @return ImGuiViewport
--- @nodiscard
function ImGuiViewport()
    return setmetatable({
        ID       = 0, -- Unique identifier for the viewport
        Flags    = 0, -- See ImGuiViewportFlags_
        Pos      = ImVec2(), -- Main Area: Position of the viewport (Dear ImGui coordinates are the same as OS desktop/native coordinates)
        Size     = ImVec2(), -- Main Area: Size of the viewport.
        FramebufferScale = ImVec2(), -- Density of the viewport for Retina display (always 1,1 on Windows, may be 2,2 etc on macOS/iOS). This will affect font rasterizer density.
        WorkPos  = ImVec2(), -- Work Area: Position of the viewport minus task bars, menus bars, status bars (>= Pos)
        WorkSize = ImVec2(), -- Work Area: Size of the viewport minus task bars, menu bars, status bars (<= Size)
        DpiScale = 0, -- 1.0f = 96 DPI = No extra scale.

        PlatformHandle = nil, -- void* to hold higher-level, platform window handle (e.g. HWND for Win32 backend, Uint32 WindowID for SDL, GLFWWindow* for GLFW), for FindViewportByPlatformHandle().
        PlatformHandleRaw = nil, -- void* to hold lower-level, platform-native window handle (always HWND on Win32 platform, unused for other platforms).
        PlatformIconData = nil, -- [EXPERIMENTAL] Pass opaque data for Platform backend to handle.
        PlatformWindowCreated = false -- Platform window has been created (Platform_CreateWindow() has been called). This is false during the first frame where a viewport is being created.
    }, MT.ImGuiViewport)
end

-------------------------------------------------------------------------------
-- [SECTION] ImGuiPlatformIO + other Platform Dependent Interfaces (ImGuiPlatformMonitor, ImGuiPlatformImeData)
-------------------------------------------------------------------------------

-- Access via ImGui.GetPlatformIO()
--- @class ImGuiPlatformIO
--- @field Platform_GetClipboardTextFn fun(ctx?: ImGuiContext): string
--- @field Platform_CreateWindow       fun(vp: ImGuiViewport)
--- @field Platform_OnChangedViewport  fun(vp: ImGuiViewport)
--- @field Monitors                    ImVector<ImGuiPlatformMonitor>
--- @field Textures                    ImVector<ImTextureData>
--- @field Viewports                   ImVector<ImGuiViewport>
MT.ImGuiPlatformIO = {}
MT.ImGuiPlatformIO.__index = MT.ImGuiPlatformIO

--- @return ImGuiPlatformIO
--- @nodiscard
function ImGuiPlatformIO()
    local this = {
        -------------------------------------------------------------------------------
        -- Input - Interface with OS and Platform backend (most common stuff)
        -------------------------------------------------------------------------------

        -- Optional: Access OS clipboard
        -- (default to use native Win32 clipboard on Windows, otherwise uses a private clipboard. Override to access OS clipboard on other architectures)
        Platform_GetClipboardTextFn = nil, -- Should return nil on failure (e.g. clipboard data is not text).
        Platform_SetClipboardTextFn = nil,
        Platform_ClipboardUserData = nil,

        -- Optional: Open link/folder/file in OS Shell
        -- (default to use ShellExecuteW() on Windows, system() on Linux/Mac. expected to return false on failure, but some platforms may always return true)
        Platform_OpenInShellFn = nil,
        Platform_OpenInShellUserData = nil,

        -- Optional: Notify OS Input Method Editor of the screen position of your cursor for text input position (e.g. when using Japanese/Chinese IME on Windows)
        Platform_SetImeDataFn = nil, -- fun(ctx, viewport, data)
        Platform_ImeUserData = nil,

        -- Optional: Platform locale
        -- [Experimental] Configure decimal point e.g. '.' or ',' useful for some languages (e.g. German), generally pulled from *localeconv()->decimal_point
        Platform_LocaleDecimalPoint = 46, -- '.'

        -- Optional: Session date
        Platform_SessionDate = 0, -- Integer storing YYYYMMDD e.g. 20261231 corresponding to the beginning of application session.

        -------------------------------------------------------------------------------
        -- Input - Interface with Renderer Backend
        -------------------------------------------------------------------------------

        -- Optional: Maximum texture size supported by renderer (used to adjust how we size textures). 0 if not known.
        Renderer_TextureMaxWidth = 0,
        Renderer_TextureMaxHeight = 0,

        -- Written by some backends during ImGui_ImplXXXX_RenderDrawData() call to point backend_specific ImGui_ImplXXXX_RenderState* structure.
        Renderer_RenderState = nil,

        -- Optional: Standard draw callbacks (set by backends that support them)
        DrawCallback_ResetRenderState = nil, -- Request to reset the graphics/render state.
        DrawCallback_SetSamplerLinear = nil, -- Request backend to set texture sampling to Linear.
        DrawCallback_SetSamplerNearest = nil, -- Request backend to set texture sampling to Nearest/Point.
        DrawCallback_SetSamplerFromTex = nil, -- Request backend to use sampler associated to texture - only available in some backends: OpenGL2/3 and SDLRenderer3.

        -- (Optional) Monitor list
        -- - Updated by: app/backend. Update every frame to dynamically support changing monitor or DPI configuration.
        -- - Used by: dear imgui to query DPI info, clamp popups/tooltips within same monitor and not have them straddle monitors.
        Monitors = ImVector(),
        -- Textures list (the list is updated by calling ImGui.EndFrame or ImGui.Render)
        -- The ImGui_ImplXXXX_RenderDrawData() function of each backend generally access this via ImDrawData::Textures which points to this. The array is available here mostly because backends will want to destroy textures on shutdown.
        Textures = ImVector(), -- List of textures used by Dear ImGui (most often 1) + contents of external texture list is automatically appended into this.
        -- Viewports list (the list is updated by calling ImGui.EndFrame or ImGui.Render)
        -- (in the future we will attempt to organize this feature to remove the need for a "main viewport")
        Viewports = ImVector(), -- Main viewports, followed by all secondary viewports.

        Platform_OnChangedViewport = nil, -- (Optional) [BETA] FIXME-DPI: DPI handling: Called during Begin() every time the viewport we are outputting into changes, so backend has a chance to swap fonts to adjust style.
    }

    return setmetatable(this, MT.ImGuiPlatformIO)
end

-- (Optional) This is required when enabling multi-viewport. Represent the bounds of each connected monitor/display and their DPI.
-- We use this information for multiple DPI support + clamping the position of popups and tooltips so they don't straddle multiple monitors.
--- @class ImGuiPlatformMonitor
--- @field MainPos        ImVec2
--- @field MainSize       ImVec2
--- @field WorkPos        ImVec2
--- @field WorkSize       ImVec2
--- @field DpiScale       float
--- @field PlatformHandle any

--- @return ImGuiPlatformMonitor
--- @nodiscard
function ImGuiPlatformMonitor()
    return {
        MainPos  = ImVec2(0, 0), -- Coordinates of the area displayed on this monitor (Min = upper left, Max = bottom right)
        MainSize = ImVec2(0, 0),
        WorkPos  = ImVec2(0, 0), -- Coordinates without task bars / side bars / menu bars. Used to avoid positioning popups/tooltips inside this region. If you don't have this info, please copy the value for MainPos/MainSize.
        WorkSize = ImVec2(0, 0),
        DpiScale = 1.0, -- 1.0f = 96 DPI

        PlatformHandle = nil -- Backend dependant data (e.g. HMONITOR, GLFWmonitor*, SDL Display Index, NSScreen*)
    }
end

-------------------------------------------------------------------------------
-- [SECTION] Flags & Enumerations
-------------------------------------------------------------------------------

-- Flags for ImGui.Begin()
-- (Those are per-window flags. There are shared flags in ImGuiIO: io.ConfigWindowsResizeFromEdges and io.ConfigWindowsMoveFromTitleBarOnly)
--- @enum ImGuiWindowFlags
ImGuiWindowFlags = {
    None                      = 0,
    NoTitleBar                = bitLShift(1, 0), -- Disable title-bar
    NoResize                  = bitLShift(1, 1), -- Disable user resizing with the lower-right grip
    NoMove                    = bitLShift(1, 2), -- Disable user moving the window
    NoScrollbar               = bitLShift(1, 3), -- Disable scrollbars (window can still scroll with mouse or programmatically)
    NoScrollWithMouse         = bitLShift(1, 4), -- Disable user vertically scrolling with mouse wheel. On child window, mouse wheel will be forwarded to the parent unless NoScrollbar is also set.
    NoCollapse                = bitLShift(1, 5), -- Disable user collapsing window by double-clicking on it. Also referred to as Window Menu Button (e.g. within a docking node).
    AlwaysAutoResize          = bitLShift(1, 6), -- Resize every window to its content every frame
    NoBackground              = bitLShift(1, 7), -- Disable drawing background color (WindowBg, etc.) and outside border. Similar as using SetNextWindowBgAlpha(0.0f).
    NoSavedSettings           = bitLShift(1, 8), -- Never load/save settings in .ini file
    NoMouseInputs             = bitLShift(1, 9), -- Disable catching mouse, hovering test with pass through.
    MenuBar                   = bitLShift(1, 10), -- Has a menu-bar
    HorizontalScrollbar       = bitLShift(1, 11), -- Allow horizontal scrollbar to appear (off by default). You may use SetNextWindowContentSize(ImVec2(width,0.0f)); prior to calling Begin() to specify width. Read code in imgui_demo in the "Horizontal Scrolling" section.
    NoFocusOnAppearing        = bitLShift(1, 12), -- Disable taking focus when transitioning from hidden to visible state
    NoBringToFrontOnFocus     = bitLShift(1, 13), -- Disable bringing window to front when taking focus (e.g. clicking on it or programmatically giving it focus)
    AlwaysVerticalScrollbar   = bitLShift(1, 14), -- Always show vertical scrollbar (even if ContentSize.y < Size.y)
    AlwaysHorizontalScrollbar = bitLShift(1, 15), -- Always show horizontal scrollbar (even if ContentSize.x < Size.x)
    NoNavInputs               = bitLShift(1, 16), -- No keyboard/gamepad navigation within the window
    NoNavFocus                = bitLShift(1, 17), -- No focusing toward this window with keyboard/gamepad navigation (e.g. skipped by Ctrl+Tab)
    UnsavedDocument           = bitLShift(1, 18), -- Display a dot next to the title. When used in a tab/docking context, tab is selected when clicking the X + closure is not assumed (will wait for user to stop submitting the tab). Otherwise closure is assumed when pressing the X, so if you keep submitting the tab may reappear at end of tab bar.
    NoDocking                 = bitLShift(1, 19), -- Disable docking of this window
    -- [Internal]
    DockNodeHost              = bitLShift(1, 23), -- Don't use! For internal use by Begin()/NewFrame()
    ChildWindow               = bitLShift(1, 24), -- Don't use! For internal use by BeginChild()
    Tooltip                   = bitLShift(1, 25), -- Don't use! For internal use by BeginTooltip()
    Popup                     = bitLShift(1, 26), -- Don't use! For internal use by BeginPopup()
    Modal                     = bitLShift(1, 27), -- Don't use! For internal use by BeginPopupModal()
    ChildMenu                 = bitLShift(1, 28) -- Don't use! For internal use by BeginMenu()
}

-- [Internal]
ImGuiWindowFlags.NoNav        = bitOr(ImGuiWindowFlags.NoNavInputs, ImGuiWindowFlags.NoNavFocus)
ImGuiWindowFlags.NoDecoration = bitOr(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoCollapse)
ImGuiWindowFlags.NoInputs     = bitOr(ImGuiWindowFlags.NoMouseInputs, ImGuiWindowFlags.NoNavInputs, ImGuiWindowFlags.NoNavFocus)

-- Flags for ImGui.PushItemFlag()
-- (Those are shared by all submitted items)
--- @enum ImGuiItemFlags
ImGuiItemFlags = {
    None                  = 0, -- Default:
    NoTabStop             = bitLShift(1, 0), -- false    -- Disable keyboard tabbing. This is a "lighter" version of ImGuiItemFlags.NoNav.
    NoNav                 = bitLShift(1, 1), -- false    -- Disable any form of focusing: keyboard/gamepad directional navigation and SetKeyboardFocusHere() calls.
    NoNavDefaultFocus     = bitLShift(1, 2), -- false    -- Disable item being a candidate for default focus (e.g. used by title bar items).
    ButtonRepeat          = bitLShift(1, 3), -- false    -- Any button-like behavior will have repeat mode enabled (based on io.KeyRepeatDelay and io.KeyRepeatRate values). Note that you can also call IsItemActive() after any button to tell if it is being held.
    AutoClosePopups       = bitLShift(1, 4), -- true     -- MenuItem()/Selectable() automatically close their parent popup window.
    AllowDuplicateId      = bitLShift(1, 5), -- false    -- Allow submitting an item with the same identifier as an item already submitted this frame without triggering a warning tooltip if io.ConfigDebugHighlightIdConflicts is set.
    Disabled              = bitLShift(1, 6), -- false    -- [Internal] Disable interactions. DOES NOT affect visuals. This is used by BeginDisabled()/EndDisabled() and only provided here so you can read back via GetItemFlags().
    -------------------------------------------------------------------------------
    -- LiveEdit refers to applying edits to backing variables _while_ typing a value using the keyboard.
    -- Widget:                          | Input:   | w/ LiveEdit:    | Output:
    --   InputText()                    |   "123"  |   on(default)   |  "1" then "12" then "123"
    --   InputText()                    |   "123"  |   off           |  "123" after validating or tabbing out or losing focus.
    --   DragFloat(), SliderInt(), etc. |   "123"  |   on*           |  1 then 12 then 123
    --   DragFloat(), SliderInt(), etc. |   "123"  |   off(default)* |  123 after validation or tabbing out or losing focus.
    -- (*) Since 1.92.9 (July 2026), ImGuiItemFlags.LiveEditOnInputScalar is OFF by default. In prior version it was ON for everything.
    -------------------------------------------------------------------------------
    LiveEditOnInputText   = bitLShift(1, 7), -- true     -- InputText: apply keyboard edits to backing value while typing. Otherwise, edits are applied when validating, tabbing out or losing focus.
    LiveEditOnInputScalar = bitLShift(1, 8) -- false    -- DragXXX, SliderXXX, InputScalar: apply keyboard edits to backing value while typing. Otherwise, edits are applied when validating, tabbing out or losing focus.
}

ImGuiItemFlags.LiveEditOnInput = bitOr(ImGuiItemFlags.LiveEditOnInputText, ImGuiItemFlags.LiveEditOnInputScalar)

-- Status flags for an already submitted item
-- - output: stored in g.LastItemData.StatusFlags
--- @enum ImGuiItemStatusFlags
ImGuiItemStatusFlags = {
    None             = 0,
    HoveredRect      = bitLShift(1, 0), -- Mouse position is within item rectangle (does NOT mean that the window is in correct z-order and can be hovered!, this is only one part of the most-common IsItemHovered test)
    HasDisplayRect   = bitLShift(1, 1), -- g.LastItemData.DisplayRect is valid
    Edited           = bitLShift(1, 2), -- Value exposed by item was edited in the current frame (should match the bool return value of most widgets)
    ToggledSelection = bitLShift(1, 3), -- Set when Selectable(), TreeNode() reports toggling a selection. We can't report "Selected", only state changes, in order to easily handle clipping with less issues.
    ToggledOpen      = bitLShift(1, 4), -- Set when TreeNode() reports toggling their open state.
    HasDeactivated   = bitLShift(1, 5), -- Set if the widget/group is able to provide data for the ImGuiItemStatusFlags.Deactivated flag.
    Deactivated      = bitLShift(1, 6), -- Only valid if ImGuiItemStatusFlags.HasDeactivated is set.
    HoveredWindow    = bitLShift(1, 7), -- Override the HoveredWindow test to allow cross-window hover testing.
    Visible          = bitLShift(1, 8), -- [WIP] Set when item is overlapping the current clipping rectangle (Used internally. Please don't use yet: API/system will change as we refactor Itemadd()).
    HasClipRect      = bitLShift(1, 9), -- g.LastItemData.ClipRect is valid.
    HasShortcut      = bitLShift(1, 10), -- g.LastItemData.Shortcut valid. Set by SetNextItemShortcut() -> ItemAdd().
    --ImGuiItemStatusFlags.FocusedByTabbing = 1 << 8,   -- Removed IN 1.90.1 (Dec 2023). The trigger is part of g.NavActivateId. See commit 54c1bdeceb.
    EditedInternal   = bitLShift(1, 11) -- Similar to ImGuiItemStatusFlags.Edited but bypassing ImGuiItemFlags.NoMarkEdited.
}

-- Flags for ImGui.BeginChild()
-- (Legacy: bit 0 must always correspond to ImGuiChildFlags.Borders to be backward compatible with old API using 'bool border = false'.)
-- About using AutoResizeX/AutoResizeY flags:
-- - May be combined with SetNextWindowSizeConstraints() to set a min/max size for each axis (see "Demo->Child->Auto-resize with Constraints").
-- - Size measurement for a given axis is only performed when the child window is within visible boundaries, or is just appearing.
--   - This allows BeginChild() to return false when not within boundaries (e.g. when scrolling), which is more optimal. BUT it won't update its auto-size while clipped.
--     While not perfect, it is a better default behavior as the always-on performance gain is more valuable than the occasional "resizing after becoming visible again" glitch.
--   - You may also use ImGuiChildFlags.AlwaysAutoResize to force an update even when child window is not in view.
--     HOWEVER PLEASE UNDERSTAND THAT DOING SO WILL PREVENT BeginChild() FROM EVER RETURNING FALSE, disabling benefits of coarse clipping.
--- @enum ImGuiChildFlags
ImGuiChildFlags = {
    None                   = 0,
    Borders                = bitLShift(1, 0), -- Show an outer border and enable WindowPadding. (IMPORTANT: this is always == 1 == true for legacy reason)
    AlwaysUseWindowPadding = bitLShift(1, 1), -- Pad with style.WindowPadding even if no border are drawn (no padding by default for non-bordered child windows because it makes more sense)
    ResizeX                = bitLShift(1, 2), -- Allow resize from right border (layout direction). Enable .ini saving (unless ImGuiWindowFlags.NoSavedSettings passed to window flags)
    ResizeY                = bitLShift(1, 3), -- Allow resize from bottom border (layout direction). "
    AutoResizeX            = bitLShift(1, 4), -- Enable auto-resizing width. Read "IMPORTANT: Size measurement" details above.
    AutoResizeY            = bitLShift(1, 5), -- Enable auto-resizing height. Read "IMPORTANT: Size measurement" details above.
    AlwaysAutoResize       = bitLShift(1, 6), -- Combined with AutoResizeX/AutoResizeY. Always measure size even when child is hidden, always return true, always disable clipping optimization! NOT RECOMMENDED.
    FrameStyle             = bitLShift(1, 7), -- Style the child window like a framed item: use FrameBg, FrameRounding, FrameBorderSize, FramePadding instead of ChildBg, ChildRounding, ChildBorderSize, WindowPadding.
    NavFlattened           = bitLShift(1, 8) -- [BETA] Share focus scope, allow keyboard/gamepad navigation to cross over parent border to this child or between sibling child windows.
}

ImGuiChildFlags.ResizeBoth = bitOr(ImGuiChildFlags.ResizeX, ImGuiChildFlags.ResizeY)
ImGuiChildFlags.ResizeXAndY = ImGuiChildFlags.ResizeBoth

--- @enum ImGuiNextItemDataFlags
ImGuiNextItemDataFlags = {
    None           = 0,
    HasWidth       = bitLShift(1, 0),
    HasOpen        = bitLShift(1, 1),
    HasShortcut    = bitLShift(1, 2),
    HasRefVal      = bitLShift(1, 3),
    HasStorageID   = bitLShift(1, 4),
    HasColorMarker = bitLShift(1, 5)
}

-- Flags for ImDrawList functions
--- @enum ImDrawFlags
ImDrawFlags = {
    None                    = 0,
    --ImDrawFlags_Closed                = 1,        // -> FLAG MOVED BELOW. Prior to 1.92.8 (May 2026): ImDrawFlags_Closed was guaranteed to be == (1<<0) == 1, for legacy compatibility reason. Hardcoded use of 1 or true should be replaced with 'ImDrawFlags_Closed'.

    -- About usage of flags:
    -- - "Prim" column:  'OK' = flag can be used to configure an individual AddXXX() call.
    -- - "Scope" column: 'OK' = initialized by ImGui based on Style options (e.g. whether anti-aliased is enabled) + may be modified using ImDrawList::PushDrawFlag().
    --                          OK(0)/OK(1) indicates whether this flag is set in the default ImGui Style settings.

    -- - Rounding default to ImDrawFlags_RoundAll when 'rounding > 0'.
    -- - So you only need to use the ImDrawFlags_RoundXXX flags if you want a special configuration (e.g. a rectangle with one rounded corner).
    -- Rounding for AddRectXXX(), PathRect() ------ -- Prim/Scope?
    RoundTopLeft            = bitLShift(1, 4), -- OK   --    -- Round top-left corner only (when 'rounding > 0.0f', we default to all corners).
    RoundTopRight           = bitLShift(1, 5), -- OK   --    -- Round top-right corner only (when 'rounding > 0.0f', we default to all corners).
    RoundBottomLeft         = bitLShift(1, 6), -- OK   --    -- Round bottom-left corner only (when 'rounding > 0.0f', we default to all corners).
    RoundBottomRight        = bitLShift(1, 7), -- OK   --    -- Round bottom-right corner only (when 'rounding > 0.0f', we default to all corners).
    RoundNone               = bitLShift(1, 8), -- OK   --    -- Disable rounding even when 'rounding > 0.0f'. This value is NOT zero, it is NOT an implicit flag!

    -- Stroke Options ----------------------------- -- Prim/Scope?
    Closed                  = bitLShift(1, 9),  -- OK   --     -- PathStroke(), AddPolyline(): specify that shape should be closed.
    JoinMiter               = bitLShift(1, 10), -- OK   --     -- PathStroke(), AddPolyline(): use miter joins/corners only. This assumes that the input polyline does not have corners sharper than 90 degrees. Slightly faster.
    CapSquare               = bitLShift(1, 11), -- OK   --     -- PathStroke(), AddPolyline(): use square cap line ends.

    -- About Stroke Ends:
    -- - Rendering is optimized for fast pixel-perfect UI, so line ends are not anti-aliased by default. It's cheaper (we can emit less vertices).
    -- - For more free-form drawings, light graphs and markers, or when using thick strokes: you can turn them on using the ImDrawFlags_AALineEnds flag.
    -- - See 'Demo->Examples->Custom Rendering' to interactively toy with those flags.
    -- - 'OK*' indicates using this at the AddXXX() call site is unlikely: it would only makes sense if (1) the option is disabled in style/scope and (2) you want to forcefully enable it for a single primitives. Possible but unlikely! Only supported for functions taking flags inputs.
    -- Stroke/Fill Anti-aliasing ------------------ -- Prim/Scope?
    AAFill                  = bitLShift(1, 12), -- OK*  OK(1)  -- Enable anti-aliasing for Filled shapes.
    AALines                 = bitLShift(1, 13), -- OK*  OK(1)  -- Enable anti-aliasing for Strokes (lines, borders).
    AALineEnds              = bitLShift(1, 14), -- OK   OK(0)  -- Enable anti-aliasing for Strokes Ends. Requires AALines to also be enabled. Useful on thick strokes or for precise continuity of multiple lines. A little more costly.
    --ImDrawFlags_NoAA                  = 1 << 15,  // OK   --     // Disable anti-aliasing for a given primitive.
    --ImDrawFlags_NoAALineEnds          = 1 << 16,  // OK   --     // Disable anti-aliasing ends for a given primitive.

    -- About Stroke Position:
    -- - Read https://github.com/ocornut/imgui/wiki/Draw-List (this guide includes a precise list of differences between 1.92.9 and 1.93.0)
    -- - Read https://github.com/ocornut/imgui/wiki/Pixel-Perfect-Rendering
    -- Stroke Position relative to shape outline -- -- Prim/Scope?
    StrokeInside            = bitLShift(1, 17), -- OK   --     -- Draw stroke inside of the shape outline (default for closed shapes and AddLineH, AddLineV functions)
    StrokeCenter            = bitLShift(2, 17), -- OK   --     -- Draw stroke at the center of the shape outline (default for paths, bezier, and AddLine functions)
    StrokeCenterBiased      = bitLShift(3, 17), -- OK   --     -- Draw stroke at the center of the shape outline, so that half thickness rounded down will be outside, and the rest inside the shape outline. Useful for axis-aligned shapes: AddLineH, AddLineV, AddRect. Does not animate well!
    StrokeOutside           = bitLShift(4, 17), -- OK   --     -- Draw stroke outside of the shape outline
    StrokeLegacy            = bitLShift(7, 17), -- OK   OK(0)  -- Use legacy positioning + enable JoinMiter + disable AALineEnds. Must be all bits set.

    -- Other Options ------------------------------ -- Prim/Scope?
    TextNoPixelSnap         = bitLShift(1, 20), -- OK   OK(0)  -- Disable automatically snapping AddText() calls to pixel boundaries.
    UseTexForRoundCorners   = bitLShift(1, 21), -- --   OK(1)  -- Enable using textures instead of strokes to draw rounded corners/circles where possible (faster). Used by default unless 'ImFontAtlasFlags_NoBakedRoundCorners' is enabled in the font atlas.
    UseVtxOffset            = bitLShift(1, 22), -- --   OK(1)  -- Can emit 'VtxOffset > 0' to allow large meshes with 16-bit ImDrawIdx. Used by default when 'ImGuiBackendFlags_RendererHasVtxOffset' is enabled by the backend.
    AllowTexForRoundCorners_= bitLShift(1, 23), -- --   OK(1)  -- [Internal]
}
ImDrawFlags.RoundAll                = bitOr(ImDrawFlags.RoundTopLeft, ImDrawFlags.RoundTopRight, ImDrawFlags.RoundBottomLeft, ImDrawFlags.RoundBottomRight) -- (Default!!)
ImDrawFlags.RoundTop                = bitOr(ImDrawFlags.RoundTopLeft, ImDrawFlags.RoundTopRight)
ImDrawFlags.RoundBottom             = bitOr(ImDrawFlags.RoundBottomLeft, ImDrawFlags.RoundBottomRight)
ImDrawFlags.RoundLeft               = bitOr(ImDrawFlags.RoundBottomLeft, ImDrawFlags.RoundTopLeft)
ImDrawFlags.RoundRight              = bitOr(ImDrawFlags.RoundBottomRight, ImDrawFlags.RoundTopRight)

-- [Internal]
ImDrawFlags.RoundMask_              = bitOr(ImDrawFlags.RoundAll, ImDrawFlags.RoundNone) -- [Internal]
ImDrawFlags.AllowInPushScope_       = bitOr(ImDrawFlags.AAFill, ImDrawFlags.AALines, ImDrawFlags.AALineEnds, ImDrawFlags.StrokeLegacy, ImDrawFlags.TextNoPixelSnap, ImDrawFlags.UseTexForRoundCorners, ImDrawFlags.UseVtxOffset, ImDrawFlags.RoundMask_) -- [Internal] Values allowed in PushDrawFlag() scope.
ImDrawFlags.AllowInFrameScope_      = bitOr(ImDrawFlags.AllowInPushScope_, ImDrawFlags.AllowTexForRoundCorners_)
ImDrawFlags.StrokeMask_             = bitLShift(0x07, 17)    -- [Internal]
ImDrawFlags.InvalidMask_            = 0x8000000F             -- [Internal] == ~0x7FFFFFF0 == 0x8000000F. Reserved to detect misuses.

-- Obsolete names
-- RENAMED in 1.93.0 (Oct 2026): ImDrawFlags_RoundCornersXXXX -> ImDrawFlags_RoundXXXX.
ImDrawFlags.RoundCornersTopLeft     = ImDrawFlags.RoundTopLeft
ImDrawFlags.RoundCornersTopRight    = ImDrawFlags.RoundTopRight
ImDrawFlags.RoundCornersBottomLeft  = ImDrawFlags.RoundBottomLeft
ImDrawFlags.RoundCornersBottomRight = ImDrawFlags.RoundBottomRight
ImDrawFlags.RoundCornersNone        = ImDrawFlags.RoundNone
ImDrawFlags.RoundCornersAll         = ImDrawFlags.RoundAll
ImDrawFlags.RoundCornersTop         = ImDrawFlags.RoundTop
ImDrawFlags.RoundCornersBottom      = ImDrawFlags.RoundBottom
ImDrawFlags.RoundCornersLeft        = ImDrawFlags.RoundLeft
ImDrawFlags.RoundCornersRight       = ImDrawFlags.RoundRight

-- -- RENAMED in 1.93.0: Merged ImDrawListFlags into ImDrawFlags.
--- @enum ImDrawListFlags
ImDrawListFlags = {
    None                   = ImDrawFlags.None,
    AntiAliasedFill        = ImDrawFlags.AAFill,
    AntiAliasedLines       = ImDrawFlags.AALines,
    AntiAliasedLinesUseTex = ImDrawFlags.AALines, -- No effect, anti-aliased rendering always uses textures from 1.93+
    AllowVtxOffset         = ImDrawFlags.UseVtxOffset,
    TextNoPixelSnap        = ImDrawFlags.TextNoPixelSnap,
}

-- Font flags
-- (in future versions as we redesign font loading API, this will become more important and better documented. for now please consider this as internal/advanced use)
--- @enum ImFontFlags
ImFontFlags = {
    None            = 0,
    NoLoadError     = bitLShift(1, 1), -- Disable throwing an error/assert when calling AddFontXXX() with missing file/data. Calling code is expected to check AddFontXXX() return value.
    NoLoadGlyphs    = bitLShift(1, 2), -- [Internal] Disable loading new glyphs.
    LockBakedSizes  = bitLShift(1, 3), -- [Internal] Disable loading new baked sizes, disable garbage collecting current ones. e.g. if you want to lock a font to a single size. Important: if you use this to preload given sizes, consider the possibility of multiple font density used on Retina display.
    ImplicitRefSize = bitLShift(1, 4) -- [Internal] Reference size was not set explicitly.
}

-- Enumeration for AddMouseSourceEvent() actual source of Mouse Input data.
-- Historically we use "Mouse" terminology everywhere to indicate pointer data, e.g. MousePos, IsMousePressed(), io.AddMousePosEvent()
-- But that "Mouse" data can come from different source which occasionally may be useful for application to know about.
-- You can submit a change of pointer type using io.AddMouseSourceEvent().
--- @enum ImGuiMouseSource
ImGuiMouseSource = {
    Mouse       = 0, -- Input is coming from an actual mouse.
    TouchScreen = 1, -- Input is coming from a touch screen (no hovering prior to initial press, less precise initial press aiming, dual-axis wheeling possible).
    Pen         = 2, -- Input is coming from a pressure/magnetic pen (often used in conjunction with high-sampling rates).
    COUNT       = 3
}

-- Enumeration for ImGui.SetNextWindow***(), SetWindow***(), SetNextItem***() functions
-- Represent a condition.
-- Important: Treat as a regular enum! Do NOT combine multiple values using binary operators! All the functions above treat 0 as a shortcut to ImGuiCond.Always.
--- @enum ImGuiCond
ImGuiCond = {
    None          = 0, -- No condition (always set the variable), same as _Always
    Always        = bitLShift(1, 0), -- No condition (always set the variable), same as _None
    Once          = bitLShift(1, 1), -- Set the variable once per runtime session (only the first call will succeed)
    FirstUseEver  = bitLShift(1, 2), -- Set the variable if the object/window has no persistently saved data (no entry in .ini file)
    Appearing     = bitLShift(1, 3) -- Set the variable if the object/window is appearing after being hidden/inactive (or the first time)
}

-- Flags for Shortcut(), SetNextItemShortcut(),
-- (and for upcoming extended versions of IsKeyPressed(), IsMouseClicked(), Shortcut(), SetKeyOwner(), SetItemKeyOwner() that are still in imgui_internal.h)
-- Don't mistake with ImGuiInputTextFlags! (which is for ImGui.InputText() function)
--- @enum ImGuiInputFlags
ImGuiInputFlags = {
    None                 = 0,
    Repeat               = bitLShift(1, 0), -- Enable repeat. Return true on successive repeats. Default for legacy IsKeyPressed(). NOT Default for legacy IsMouseClicked(). MUST BE == 1.
    -- Flags for Shortcut(), SetNextItemShortcut()
    -- - Routing policies: RouteGlobal+OverActive >> RouteActive or RouteFocused (if owner is active item) >> RouteGlobal+OverFocused >> RouteFocused (if in focused window stack) >> RouteGlobal.
    -- - Default policy is RouteFocused. Can select only 1 policy among all available.
    RouteActive          = bitLShift(1, 10), -- Route to active item only.
    RouteFocused         = bitLShift(1, 11), -- Route to windows in the focus stack (DEFAULT). Deep-most focused window takes inputs. Active item takes inputs over deep-most focused window.
    RouteGlobal          = bitLShift(1, 12), -- Global route (unless a focused window or active item registered the route).
    RouteAlways          = bitLShift(1, 13), -- Do not register route, poll keys directly.
    -- - Routing options
    RouteOverFocused     = bitLShift(1, 14), -- Option: global route: higher priority than focused route (unless active item in focused route).
    RouteOverActive      = bitLShift(1, 15), -- Option: global route: higher priority than active item. Unlikely you need to use that: will interfere with every active items, e.g. Ctrl+A registered by InputText will be overridden by this. May not be fully honored as user/internal code is likely to always assume they can access keys when active.
    RouteUnlessBgFocused = bitLShift(1, 16), -- Option: global route: will not be applied if underlying background/void is focused (== no Dear ImGui windows are focused). Useful for overlay applications.
    RouteFromRootWindow  = bitLShift(1, 17), -- Option: route evaluated from the point of view of root window rather than current window.
    -- Flags for SetNextItemShortcut()
    Tooltip              = bitLShift(1, 18) -- Automatically display a tooltip when hovering item [BETA] Unsure of right api (opt-in/opt-out)
}

-- Flags for InvisibleButton() [extended in imgui_internal.h]
--- @enum ImGuiButtonFlags
ImGuiButtonFlags = {
    None                          = 0,
    MouseButtonLeft               = bitLShift(1, 0), -- React on left mouse button (default)
    MouseButtonRight              = bitLShift(1, 1), -- React on right mouse button
    MouseButtonMiddle             = bitLShift(1, 2), -- React on center mouse button
    EnableNav                     = bitLShift(1, 3), -- InvisibleButton(): do not disable navigation/tabbing. Otherwise disabled by default.
    PressedOnClick                = bitLShift(1, 4), -- return true on click (mouse down event)
    PressedOnClickRelease         = bitLShift(1, 5), -- [Default] return true on click + release on same item <-- this is what the majority of Button are using
    PressedOnClickReleaseAnywhere = bitLShift(1, 6), -- return true on click + release even if the release event is not done while hovering the item
    PressedOnRelease              = bitLShift(1, 7), -- return true on release (default requires click+release). Prior to 2026/03/20 this implied ImGuiButtonFlags.NoHoldingActiveId but they are separate now.
    PressedOnDoubleClick          = bitLShift(1, 8), -- return true on double-click (default requires click+release)
    PressedOnDragDropHold         = bitLShift(1, 9), -- return true when held into while we are drag and dropping another item (used by e.g. tree nodes, collapsing headers)
    --ImGuiButtonFlags.Repeat               = 1 << 10,  -- hold to repeat -> use ImGuiItemFlags.ButtonRepeat instead.
    FlattenChildren               = bitLShift(1, 11), -- allow interactions even if a child window is overlapping
    AllowOverlap                  = bitLShift(1, 12), -- Hit testing will allow subsequent widgets to overlap this one. Require previous frame HoveredId to match before being usable. Shortcut to calling SetNextItemAllowOverlap().
    --ImGuiButtonFlags.DontClosePopups      = 1 << 13,  -- disable automatically closing parent popup on press
    --ImGuiButtonFlags.Disabled             = 1 << 14,  -- disable interactions -> use BeginDisabled() or ImGuiItemFlags.Disabled
    AlignTextBaseLine             = bitLShift(1, 15), -- vertically align button to match text baseline - ButtonEx() only -- FIXME: Should be removed and handled by SmallButton(), not possible currently because of DC.CursorPosPrevLine
    NoKeyModsAllowed              = bitLShift(1, 16), -- disable mouse interaction if a key modifier is held
    NoHoldingActiveId             = bitLShift(1, 17), -- don't set ActiveId while holding the mouse (ImGuiButtonFlags.PressedOnClick only)
    NoNavFocus                    = bitLShift(1, 18), -- don't override navigation focus when activated (FIXME: this is essentially used every time an item uses ImGuiItemFlags.NoNav, but because legacy specs don't requires LastItemData to be set ButtonBehavior(), we can't poll g.LastItemData.ItemFlags)
    NoHoveredOnFocus              = bitLShift(1, 19), -- don't report as hovered when nav focus is on this item
    NoSetKeyOwner                 = bitLShift(1, 20), -- don't set key/input owner on the initial click (note: mouse buttons are keys! often, the key in question will be ImGuiKey.MouseLeft!)
    NoTestKeyOwner                = bitLShift(1, 21), -- don't test key/input owner when polling the key (note: mouse buttons are keys! often, the key in question will be ImGuiKey.MouseLeft!)
    NoFocus                       = bitLShift(1, 22) -- [EXPERIMENTAL: Not very well specced]. Don't focus parent window when clicking.
}

ImGuiButtonFlags.MouseButtonMask_  = bitOr(ImGuiButtonFlags.MouseButtonLeft, ImGuiButtonFlags.MouseButtonRight, ImGuiButtonFlags.MouseButtonMiddle) -- [Internal]
ImGuiButtonFlags.PressedOnMask_    = bitOr(ImGuiButtonFlags.PressedOnClick, ImGuiButtonFlags.PressedOnClickRelease, ImGuiButtonFlags.PressedOnClickReleaseAnywhere, ImGuiButtonFlags.PressedOnRelease, ImGuiButtonFlags.PressedOnDoubleClick, ImGuiButtonFlags.PressedOnDragDropHold)
ImGuiButtonFlags.PressedOnDefault_ = ImGuiButtonFlags.PressedOnClickRelease
ImGuiButtonFlags.NoKeyModifiers    = ImGuiButtonFlags.NoKeyModsAllowed

-- Enumeration for PushStyleVar() / PopStyleVar() to temporarily modify the ImGuiStyle structure.
-- - The enum only refers to fields of ImGuiStyle which makes sense to be pushed/popped inside UI code.
--   During initialization or between frames, feel free to just poke into ImGuiStyle directly.
-- - When changing this enum, you need to update the associated internal table GStyleVarInfo[] accordingly. This is where we link enum values to members offset/type.
--- @enum ImGuiStyleVar
ImGuiStyleVar = {
    -- Enum name -------------------------- -- Member in ImGuiStyle structure (see ImGuiStyle for descriptions)
    Alpha                       = 0, -- float     Alpha
    DisabledAlpha               = 1, -- float     DisabledAlpha
    WindowPadding               = 2, -- ImVec2    WindowPadding
    WindowRounding              = 3, -- float     WindowRounding
    WindowBorderSize            = 4, -- float     WindowBorderSize
    WindowMinSize               = 5, -- ImVec2    WindowMinSize
    WindowTitleAlign            = 6, -- ImVec2    WindowTitleAlign
    ChildRounding               = 7, -- float     ChildRounding
    ChildBorderSize             = 8, -- float     ChildBorderSize
    PopupRounding               = 9, -- float     PopupRounding
    PopupBorderSize             = 10, -- float     PopupBorderSize
    FramePadding                = 11, -- ImVec2    FramePadding
    FrameRounding               = 12, -- float     FrameRounding
    FrameBorderSize             = 13, -- float     FrameBorderSize
    ItemSpacing                 = 14, -- ImVec2    ItemSpacing
    ItemInnerSpacing            = 15, -- ImVec2    ItemInnerSpacing
    IndentSpacing               = 16, -- float     IndentSpacing
    CellPadding                 = 17, -- ImVec2    CellPadding
    ScrollbarSize               = 18, -- float     ScrollbarSize
    ScrollbarRounding           = 19, -- float     ScrollbarRounding
    ScrollbarPadding            = 20, -- float     ScrollbarPadding
    GrabMinSize                 = 21, -- float     GrabMinSize
    GrabRounding                = 22, -- float     GrabRounding
    ImageRounding               = 23, -- float     ImageRounding
    ImageBorderSize             = 24, -- float     ImageBorderSize
    TabRounding                 = 25, -- float     TabRounding
    TabBorderSize               = 26, -- float     TabBorderSize
    TabMinWidthBase             = 27, -- float     TabMinWidthBase
    TabMinWidthShrink           = 28, -- float     TabMinWidthShrink
    TabBarBorderSize            = 29, -- float     TabBarBorderSize
    TabBarOverlineSize          = 30, -- float     TabBarOverlineSize
    TableAngledHeadersAngle     = 31, -- float     TableAngledHeadersAngle
    TableAngledHeadersTextAlign = 32, -- ImVec2  TableAngledHeadersTextAlign
    TreeLinesSize               = 33, -- float     TreeLinesSize
    TreeLinesRounding           = 34, -- float     TreeLinesRounding
    MenuItemRounding            = 35, -- float     MenuItemRounding
    SelectableRounding          = 36, -- float     SelectableRounding
    DragDropTargetRounding      = 37, -- float     DragDropTargetRounding
    ButtonTextAlign             = 38, -- ImVec2    ButtonTextAlign
    SelectableTextAlign         = 39, -- ImVec2    SelectableTextAlign
    SeparatorSize               = 40, -- float     SeparatorSize
    SeparatorTextBorderSize     = 41, -- float     SeparatorTextBorderSize
    SeparatorTextAlign          = 42, -- ImVec2    SeparatorTextAlign
    SeparatorTextPadding        = 43, -- ImVec2    SeparatorTextPadding
    DockingSeparatorSize        = 44, -- float     DockingSeparatorSize
    COUNT                       = 45
}

-- Flags for ImGui.IsItemHovered(), ImGui.IsWindowHovered()
-- Note: if you are trying to check whether your mouse should be dispatched to Dear ImGui or to your app, you should use 'io.WantCaptureMouse' instead! Please read the FAQ!
-- Note: windows with the ImGuiWindowFlags.NoInputs flag are ignored by IsWindowHovered() calls.
--- @enum ImGuiHoveredFlags
ImGuiHoveredFlags = {
    None                         = 0, -- Return true if directly over the item/window, not obstructed by another window, not obstructed by an active popup or modal blocking inputs under them.
    ChildWindows                 = bitLShift(1, 0), -- IsWindowHovered() only: Return true if any children of the window is hovered
    RootWindow                   = bitLShift(1, 1), -- IsWindowHovered() only: Test from root window (top most parent of the current hierarchy)
    AnyWindow                    = bitLShift(1, 2), -- IsWindowHovered() only: Return true if any window is hovered
    NoPopupHierarchy             = bitLShift(1, 3), -- IsWindowHovered() only: Do not consider popup hierarchy (do not treat popup emitter as parent of popup) (when used with _ChildWindows or _RootWindow)
    DockHierarchy                = bitLShift(1, 4), -- IsWindowHovered() only: Consider docking hierarchy (treat dockspace host as parent of docked window) (when used with _ChildWindows or _RootWindow)
    AllowWhenBlockedByPopup      = bitLShift(1, 5), -- Return true even if a popup window is normally blocking access to this item/window
    --ImGuiHoveredFlags.AllowWhenBlockedByModal     = 1 << 6,   -- Return true even if a modal popup window is normally blocking access to this item/window. FIXME-TODO: Unavailable yet.
    AllowWhenBlockedByActiveItem = bitLShift(1, 7), -- Return true even if an active item is blocking access to this item/window. Useful for Drag and Drop patterns.
    AllowWhenOverlappedByItem    = bitLShift(1, 8), -- IsItemHovered() only: Return true even if the item uses AllowOverlap mode and is overlapped by another hoverable item.
    AllowWhenOverlappedByWindow  = bitLShift(1, 9), -- IsItemHovered() only: Return true even if the position is obstructed or overlapped by another window.
    AllowWhenDisabled            = bitLShift(1, 10), -- IsItemHovered() only: Return true even if the item is disabled
    NoNavOverride                = bitLShift(1, 11), -- IsItemHovered() only: Disable using keyboard/gamepad navigation state when active, always query mouse
    -- Tooltips mode
    -- - typically used in IsItemHovered() + SetTooltip() sequence.
    -- - this is a shortcut to pull flags from 'style.HoverFlagsForTooltipMouse' or 'style.HoverFlagsForTooltipNav' where you can reconfigure desired behavior.
    --   e.g. 'HoverFlagsForTooltipMouse' defaults to 'ImGuiHoveredFlags.Stationary | ImGuiHoveredFlags.DelayShort | ImGuiHoveredFlags.AllowWhenDisabled'.
    -- - for frequently actioned or hovered items providing a tooltip, you want may to use ImGuiHoveredFlags.ForTooltip (stationary + delay) so the tooltip doesn't show too often.
    -- - for items which main purpose is to be hovered, or items with low affordance, or in less consistent apps, prefer no delay or shorter delay.
    ForTooltip                   = bitLShift(1, 12), -- Shortcut for standard flags when using IsItemHovered() + SetTooltip() sequence.
    -- (Advanced) Mouse Hovering delays.
    -- - generally you can use ImGuiHoveredFlags.ForTooltip to use application-standardized flags.
    -- - use those if you need specific overrides.
    Stationary                   = bitLShift(1, 13), -- Require mouse to be stationary for style.HoverStationaryDelay (~0.15 sec) _at least one time_. After this, can move on same item/window. Using the stationary test tends to reduces the need for a long delay.
    DelayNone                    = bitLShift(1, 14), -- IsItemHovered() only: Return true immediately (default). As this is the default you generally ignore this.
    DelayShort                   = bitLShift(1, 15), -- IsItemHovered() only: Return true after style.HoverDelayShort elapsed (~0.15 sec) (shared between items) + requires mouse to be stationary for style.HoverStationaryDelay (once per item).
    DelayNormal                  = bitLShift(1, 16), -- IsItemHovered() only: Return true after style.HoverDelayNormal elapsed (~0.40 sec) (shared between items) + requires mouse to be stationary for style.HoverStationaryDelay (once per item).
    NoSharedDelay                = bitLShift(1, 17) -- IsItemHovered() only: Disable shared delay system where moving from one item to the next keeps the previous timer for a short time (standard for tooltips with long delays)
}

-- Flags for ImGui.IsWindowFocused()
--- @enum ImGuiFocusedFlags
ImGuiFocusedFlags = {
    None             = 0,
    ChildWindows     = bitLShift(1, 0), -- Return true if any children of the window is focused
    RootWindow       = bitLShift(1, 1), -- Test from root window (top most parent of the current hierarchy)
    AnyWindow        = bitLShift(1, 2), -- Return true if any window is focused. Important: If you are trying to tell how to dispatch your low-level inputs, do NOT use this. Use 'io.WantCaptureMouse' instead! Please read the FAQ!
    NoPopupHierarchy = bitLShift(1, 3), -- Do not consider popup hierarchy (do not treat popup emitter as parent of popup) (when used with _ChildWindows or _RootWindow)
    DockHierarchy    = bitLShift(1, 4), -- Consider docking hierarchy (treat dockspace host as parent of docked window) (when used with _ChildWindows or _RootWindow)
}
ImGuiFocusedFlags.RootAndChildWindows = bitOr(ImGuiFocusedFlags.RootWindow, ImGuiFocusedFlags.ChildWindows)

ImGuiHoveredFlags.AllowWhenOverlapped = bitOr(ImGuiHoveredFlags.AllowWhenOverlappedByItem, ImGuiHoveredFlags.AllowWhenOverlappedByWindow)
ImGuiHoveredFlags.RectOnly            = bitOr(ImGuiHoveredFlags.AllowWhenBlockedByPopup, ImGuiHoveredFlags.AllowWhenBlockedByActiveItem, ImGuiHoveredFlags.AllowWhenOverlapped)
ImGuiHoveredFlags.RootAndChildWindows = bitOr(ImGuiHoveredFlags.RootWindow, ImGuiHoveredFlags.ChildWindows)
ImGuiHoveredFlags.DelayMask_ = bitOr(ImGuiHoveredFlags.DelayNone, ImGuiHoveredFlags.DelayShort, ImGuiHoveredFlags.DelayNormal, ImGuiHoveredFlags.NoSharedDelay)
ImGuiHoveredFlags.AllowedMaskForIsWindowHovered = bitOr(ImGuiHoveredFlags.ChildWindows, ImGuiHoveredFlags.RootWindow, ImGuiHoveredFlags.AnyWindow, ImGuiHoveredFlags.NoPopupHierarchy, ImGuiHoveredFlags.DockHierarchy, ImGuiHoveredFlags.AllowWhenBlockedByPopup, ImGuiHoveredFlags.AllowWhenBlockedByActiveItem, ImGuiHoveredFlags.ForTooltip, ImGuiHoveredFlags.Stationary)
ImGuiHoveredFlags.AllowedMaskForIsItemHovered = bitOr(ImGuiHoveredFlags.AllowWhenBlockedByPopup, ImGuiHoveredFlags.AllowWhenBlockedByActiveItem, ImGuiHoveredFlags.AllowWhenOverlapped, ImGuiHoveredFlags.AllowWhenDisabled, ImGuiHoveredFlags.NoNavOverride, ImGuiHoveredFlags.ForTooltip, ImGuiHoveredFlags.Stationary, ImGuiHoveredFlags.DelayMask_)

-- A key identifier (ImGuiKey.XXX or ImGuiMod_XXX value): can represent Keyboard, Mouse and Gamepad values.
-- All our named keys are >= 512. Keys value 0 to 511 are left unused and were legacy native/opaque key values (< 1.87).
-- Support for legacy keys was completely removed in 1.91.5.
-- Read details about the 1.87+ transition : https://github.com/ocornut/imgui/issues/4921
-- Note that "Keys" related to physical keys and are not the same concept as input "Characters", the latter are submitted via io.AddInputCharacter().
-- The keyboard key enum values are named after the keys on a standard US keyboard, and on other keyboard types the keys reported may not match the keycaps.
--- @enum ImGuiKey
ImGuiKey = {
    -- Keyboard
    None = 0,

    NamedKey_BEGIN = 512, -- First valid key value (other than 0)

    Tab        = 512, -- == ImGuiKey.NamedKey_BEGIN
    LeftArrow  = 513,
    RightArrow = 514,
    UpArrow    = 515,
    DownArrow  = 516,
    PageUp     = 517,
    PageDown   = 518,
    Home       = 519,
    End        = 520,
    Insert     = 521,
    Delete     = 522,
    Backspace  = 523,
    Space      = 524,
    Enter      = 525,
    Escape     = 526,
    LeftCtrl   = 527, LeftShift  = 528, LeftAlt  = 529, LeftSuper  = 530,
    RightCtrl  = 531, RightShift = 532, RightAlt = 533, RightSuper = 534,
    Menu       = 535,

    -- [Port] 0 ~ 9 (upstream ImGuiKey_0..ImGuiKey_9: K0..K9 in this port, ImGuiKey["0"]..ImGuiKey["9"] are aliases)
    K0 = 536, K1 = 537, K2 = 538, K3 = 539, K4 = 540, K5 = 541, K6 = 542, K7 = 543, K8 = 544, K9 = 545,
    ["0"] = 536, ["1"] = 537, ["2"] = 538, ["3"] = 539, ["4"] = 540, ["5"] = 541, ["6"] = 542, ["7"] = 543, ["8"] = 544, ["9"] = 545,

    A = 546, B = 547, C = 548, D = 549, E = 550, F = 551, G = 552, H = 553, I = 554, J = 555,
    K = 556, L = 557, M = 558, N = 559, O = 560, P = 561, Q = 562, R = 563, S = 564, T = 565,
    U = 566, V = 567, W = 568, X = 569, Y = 570, Z = 571,

    F1  = 572, F2  = 573, F3  = 574, F4  = 575, F5  = 576, F6  = 577,
    F7  = 578, F8  = 579, F9  = 580, F10 = 581, F11 = 582, F12 = 583,
    F13 = 584, F14 = 585, F15 = 586, F16 = 587, F17 = 588, F18 = 589,
    F19 = 590, F20 = 591, F21 = 592, F22 = 593, F23 = 594, F24 = 595,

    Apostrophe = 596, Comma      = 597, Minus   = 598, Period      = 599, Slash = 600, Semicolon = 601, Equal = 602, LeftBracket = 603, Backslash = 604, RightBracket = 605, GraveAccent = 606,
    CapsLock   = 607, ScrollLock = 608, NumLock = 609, PrintScreen = 610, Pause = 611,

    Keypad0       = 612, Keypad1      = 613, Keypad2        = 614, Keypad3        = 615, Keypad4   = 616, Keypad5     = 617, Keypad6     = 618, Keypad7 = 619, Keypad8 = 620, Keypad9 = 621,
    KeypadDecimal = 622, KeypadDivide = 623, KeypadMultiply = 624, KeypadSubtract = 625, KeypadAdd = 626, KeypadEnter = 627, KeypadEqual = 628,

    AppBack        = 629, -- Available on some keyboard/mouses. Often referred as "Browser Back"
    AppForward     = 630,
    Oem102         = 631, -- Non-US backslash.

    -- Gamepad
    -- (analog values are 0.0f to 1.0f)
    -- (download controller mapping PNG/PSD at http://dearimgui.com/controls_sheets)
    -- XBOX        | SWITCH  | PLAYSTA. | -> ACTION
    GamepadStart      = 632, GamepadBack        = 633,
    GamepadFaceLeft   = 634, GamepadFaceRight   = 635, GamepadFaceUp   = 636, GamepadFaceDown   = 637,
    GamepadDpadLeft   = 638, GamepadDpadRight   = 639, GamepadDpadUp   = 640, GamepadDpadDown   = 641,
    GamepadL1         = 642, GamepadR1          = 643,
    GamepadL2         = 644, GamepadR2          = 645,
    GamepadL3         = 646, GamepadR3          = 647,
    GamepadLStickLeft = 648, GamepadLStickRight = 649, GamepadLStickUp = 650, GamepadLStickDown = 651,
    GamepadRStickLeft = 652, GamepadRStickRight = 653, GamepadRStickUp = 654, GamepadRStickDown = 655,

    MouseLeft = 656, MouseRight = 657, MouseMiddle = 658, MouseX1 = 659, MouseX2 = 660, MouseWheelX = 661, MouseWheelY = 662,

    ReservedForModCtrl = 663, ReservedForModShift = 664, ReservedForModAlt = 665, ReservedForModSuper = 666,

    -- [Internal] If you need to iterate all keys (for e.g. an input mapper) you may use ImGuiKey.NamedKey_BEGIN..ImGuiKey.NamedKey_END.
    NamedKey_END = 667
}

ImGuiKey.NamedKey_COUNT = ImGuiKey.NamedKey_END - ImGuiKey.NamedKey_BEGIN

-- Keyboard Modifiers (explicitly submitted by backend via AddKeyEvent() calls)
-- - Any functions taking a ImGuiKeyChord parameter can binary-or those with regular keys, e.g. Shortcut(ImGuiMod_Ctrl | ImGuiKey.S).
-- - Those are written back into io.KeyCtrl, io.KeyShift, io.KeyAlt, io.KeySuper for convenience,
--   but may be accessed via standard key API such as IsKeyPressed(), IsKeyReleased(), querying duration etc.
-- - Code polling every key (e.g. an interface to detect a key press for input mapping) might want to ignore those
--   and prefer using the real keys (e.g. ImGuiKey.LeftCtrl, ImGuiKey.RightCtrl instead of ImGuiMod_Ctrl).
-- - In theory the value of keyboard modifiers should be roughly equivalent to a logical or of the equivalent left/right keys.
--   In practice: it's complicated; mods are often provided from different sources. Keyboard layout, IME, sticky keys and
--   backends tend to interfere and break that equivalence. The safer decision is to relay that ambiguity down to the end-user...
-- - On macOS, we swap Cmd(Super) and Ctrl keys at the time of the io.AddKeyEvent() call.
ImGuiMod_None  = 0
ImGuiMod_Ctrl  = bitLShift(1, 12) -- Ctrl (non-macOS), Cmd (macOS)
ImGuiMod_Shift = bitLShift(1, 13) -- Shift
ImGuiMod_Alt   = bitLShift(1, 14) -- Option/Menu
ImGuiMod_Super = bitLShift(1, 15) -- Windows/Super (non-macOS), Ctrl (macOS)
ImGuiMod_Mask_ = 0xF000 -- 4-bits

-- Enumeration for PushStyleColor() / PopStyleColor()
--- @enum ImGuiCol
ImGuiCol = {
    Text                      = 0,
    TextDisabled              = 1,
    WindowBg                  = 2, -- Background of normal windows
    ChildBg                   = 3, -- Background of child windows
    PopupBg                   = 4, -- Background of popups, menus, tooltips windows
    Border                    = 5,
    BorderShadow              = 6,
    FrameBg                   = 7, -- Background of checkbox, radio button, plot, slider, text input
    FrameBgHovered            = 8,
    FrameBgActive             = 9,
    TitleBg                   = 10, -- Title bar
    TitleBgActive             = 11, -- Title bar when focused
    TitleBgCollapsed          = 12, -- Title bar when collapsed
    MenuBarBg                 = 13,
    ScrollbarBg               = 14,
    ScrollbarGrab             = 15,
    ScrollbarGrabHovered      = 16,
    ScrollbarGrabActive       = 17,
    CheckMark                 = 18, -- Checkbox tick and RadioButton circle
    CheckboxSelectedBg        = 19, -- Checkbox background when Selected, otherwise use FrameBg
    SliderGrab                = 20,
    SliderGrabActive          = 21,
    Button                    = 22,
    ButtonHovered             = 23,
    ButtonActive              = 24,
    Header                    = 25, -- Header* colors are used for CollapsingHeader, TreeNode, Selectable, MenuItem
    HeaderHovered             = 26,
    HeaderActive              = 27,
    Separator                 = 28,
    SeparatorHovered          = 29,
    SeparatorActive           = 30,
    ResizeGrip                = 31, -- Resize grip in lower-right and lower-left corners of windows.
    ResizeGripHovered         = 32,
    ResizeGripActive          = 33,
    InputTextCursor           = 34, -- InputText cursor/caret
    TabHovered                = 35, -- Tab background, when hovered
    Tab                       = 36, -- Tab background, when tab-bar is focused & tab is unselected
    TabSelected               = 37, -- Tab background, when tab-bar is focused & tab is selected
    TabSelectedOverline       = 38, -- Tab horizontal overline, when tab-bar is focused & tab is selected
    TabDimmed                 = 39, -- Tab background, when tab-bar is unfocused & tab is unselected
    TabDimmedSelected         = 40, -- Tab background, when tab-bar is unfocused & tab is selected
    TabDimmedSelectedOverline = 41, -- ..horizontal overline, when tab-bar is unfocused & tab is selected
    DockingPreview            = 42, -- Preview overlay color when about to docking something
    DockingEmptyBg            = 43, -- Background color for empty node (e.g. CentralNode with no window docked into it)
    PlotLines                 = 44,
    PlotLinesHovered          = 45,
    PlotHistogram             = 46,
    PlotHistogramHovered      = 47,
    TableHeaderBg             = 48, -- Table header background
    TableBorderStrong         = 49, -- Table outer and header borders (prefer using Alpha=1.0 here)
    TableBorderLight          = 50, -- Table inner borders (prefer using Alpha=1.0 here)
    TableRowBg                = 51, -- Table row background (even rows)
    TableRowBgAlt             = 52, -- Table row background (odd rows)
    TextLink                  = 53, -- Hyperlink color
    TextSelectedBg            = 54, -- Selected text inside an InputText
    TreeLines                 = 55, -- Tree node hierarchy outlines when using ImGuiTreeNodeFlags.DrawLines
    DragDropTarget            = 56, -- Rectangle border highlighting a drop target
    DragDropTargetBg          = 57, -- Rectangle background highlighting a drop target
    UnsavedMarker             = 58, -- Unsaved Document marker (in window title and tabs)
    NavCursor                 = 59, -- Color of keyboard/gamepad navigation cursor/rectangle, when visible
    NavWindowingHighlight     = 60, -- Highlight window when using Ctrl+Tab
    NavWindowingDimBg         = 61, -- Darken/colorize entire screen behind the Ctrl+Tab window list, when active
    ModalWindowDimBg          = 62, -- Darken/colorize entire screen behind a modal window, when one is active
    COUNT = 63
}

-- Backend capabilities flags stored in io.BackendFlags. Set by imgui_impl_xxx or custom backend.
--- @enum ImGuiBackendFlags
ImGuiBackendFlags = {
    None                  = 0,
    HasGamepad            = bitLShift(1, 0), -- Backend Platform supports gamepad and currently has one connected.
    HasMouseCursors       = bitLShift(1, 1), -- Backend Platform supports honoring GetMouseCursor() value to change the OS cursor shape.
    HasSetMousePos        = bitLShift(1, 2), -- Backend Platform supports io.WantSetMousePos requests to reposition the OS mouse position (only used if io.ConfigNavMoveSetMousePos is set).
    RendererHasVtxOffset  = bitLShift(1, 3), -- Backend Renderer supports ImDrawCmd::VtxOffset. This enables output of large meshes (64K+ vertices) while still using 16-bit indices.
    RendererHasTextures   = bitLShift(1, 4), -- Backend Renderer supports ImTextureData requests to create/update/destroy textures. This enables incremental texture updates and texture reloads. See https://github.com/ocornut/imgui/blob/master/docs/BACKENDS.md for instructions on how to upgrade your custom backend.

    -- [BETA] Multi-Viewports
    RendererHasViewports    = bitLShift(1, 10), -- Backend Renderer supports multiple viewports.
    PlatformHasViewports    = bitLShift(1, 11), -- Backend Platform supports multiple viewports.
    HasMouseHoveredViewport = bitLShift(1, 12), -- Backend Platform supports calling io.AddMouseViewportEvent() with the viewport under the mouse. IF POSSIBLE, ignore viewports with the ImGuiViewportFlags.NoInputs flag (Win32 backend, GLFW 3.30+ backend can do this, SDL backend cannot). If this cannot be done, Dear ImGui needs to use a flawed heuristic to find the viewport under.
    HasParentViewport       = bitLShift(1, 13) -- Backend Platform supports honoring viewport->ParentViewport/ParentViewportId value, by applying the corresponding parent/child relationship at the Platform level. Child windows always appear in front of their parent window.
}

-- Flags for ImGui.BeginDragDropSource(), ImGui.AcceptDragDropPayload()
--- @enum ImGuiDragDropFlags
ImGuiDragDropFlags = {
    None                     = 0,
    -- BeginDragDropSource() flags
    SourceNoPreviewTooltip   = bitLShift(1, 0), -- Disable preview tooltip. By default, a successful call to BeginDragDropSource opens a tooltip so you can display a preview or description of the source contents. This flag disables this behavior.
    SourceNoDisableHover     = bitLShift(1, 1), -- By default, when dragging we clear data so that IsItemHovered() will return false, to avoid subsequent user code submitting tooltips. This flag disables this behavior so you can still call IsItemHovered() on the source item.
    SourceNoHoldToOpenOthers = bitLShift(1, 2), -- Disable the behavior that allows to open tree nodes and collapsing header by holding over them while dragging a source item.
    SourceAllowNullID        = bitLShift(1, 3), -- Allow items such as Text(), Image() that have no unique identifier to be used as drag source, by manufacturing a temporary identifier based on their window-relative position. This is extremely unusual within the dear imgui ecosystem and so we made it explicit.
    SourceExtern             = bitLShift(1, 4), -- External source (from outside of dear imgui), won't attempt to read current item/window info. Will always return true. Only one Extern source can be active simultaneously.
    PayloadAutoExpire        = bitLShift(1, 5), -- Automatically expire the payload if the source cease to be submitted (otherwise payloads are persisting while being dragged)
    PayloadNoCrossContext    = bitLShift(1, 6), -- Hint to specify that the payload may not be copied outside current dear imgui context.
    PayloadNoCrossProcess    = bitLShift(1, 7), -- Hint to specify that the payload may not be copied outside current process.
    -- AcceptDragDropPayload() flags
    AcceptBeforeDelivery     = bitLShift(1, 10), -- AcceptDragDropPayload() will returns true even before the mouse button is released. You can then call IsDelivery() to test if the payload needs to be delivered.
    AcceptNoDrawDefaultRect  = bitLShift(1, 11), -- Do not draw the default highlight rectangle when hovering over target.
    AcceptNoPreviewTooltip   = bitLShift(1, 12), -- Request hiding the BeginDragDropSource tooltip from the BeginDragDropTarget site.
    AcceptDrawAsHovered      = bitLShift(1, 13) -- Accepting item will render as if hovered. Useful for e.g. a Button() used as a drop target.
}

ImGuiDragDropFlags.AcceptPeekOnly = bitOr(ImGuiDragDropFlags.AcceptBeforeDelivery, ImGuiDragDropFlags.AcceptNoDrawDefaultRect) -- For peeking ahead and inspecting the payload before delivery.

-- Standard Drag and Drop payload types. You can define you own payload types using short strings. Types starting with '_' are defined by Dear ImGui.
IMGUI_PAYLOAD_TYPE_COLOR_3F = "_COL3F" -- float[3]: Standard type for colors, without alpha. User code may use this type. [Port] payload.Data = { r, g, b } (1-based)
IMGUI_PAYLOAD_TYPE_COLOR_4F = "_COL4F" -- float[4]: Standard type for colors. User code may use this type. [Port] payload.Data = { r, g, b, a } (1-based)

-- Helpers macros to generate 32-bit encoded colors
IM_COL32_R_SHIFT = 0
IM_COL32_G_SHIFT = 8
IM_COL32_B_SHIFT = 16
IM_COL32_A_SHIFT = 24
IM_COL32_A_MASK  = 0xFF000000

--- @param R ImU32
--- @param G ImU32
--- @param B ImU32
--- @param A ImU32
--@hoist
function IM_COL32(R, G, B, A) return (bitOr(bitLShift(A, IM_COL32_A_SHIFT), bitLShift(B, IM_COL32_B_SHIFT), bitLShift(G, IM_COL32_G_SHIFT), bitLShift(R, IM_COL32_R_SHIFT))) end
IM_COL32_WHITE       = IM_COL32(255, 255, 255, 255)
IM_COL32_BLACK       = IM_COL32(0, 0, 0, 255)
IM_COL32_BLACK_TRANS = IM_COL32(0, 0, 0, 0)

-- Flags for OpenPopup*(), BeginPopupContext*(), IsPopupOpen() functions.
-- - IMPORTANT: If you ever used the left mouse button with BeginPopupContextXXX() helpers before 1.92.6: Read "API BREAKING CHANGES" 2026/01/07 (1.92.6) entry in imgui.cpp or GitHub topic #9157.
-- - Multiple buttons currently cannot be combined/or-ed in those functions (we could allow it later).
--- @enum ImGuiPopupFlags
ImGuiPopupFlags = {
    None                    = 0,
    MouseButtonLeft         = bitLShift(1, 2), -- For BeginPopupContext*(): open on Left Mouse release. Only one button allowed!
    MouseButtonRight        = bitLShift(2, 2), -- For BeginPopupContext*(): open on Right Mouse release. Only one button allowed! (default)
    MouseButtonMiddle       = bitLShift(3, 2), -- For BeginPopupContext*(): open on Middle Mouse release. Only one button allowed!
    NoReopen                = bitLShift(1, 5), -- For OpenPopup*(), BeginPopupContext*(): don't reopen same popup if already open (won't reposition, won't reinitialize navigation)
    --ImGuiPopupFlags.NoReopenAlwaysNavInit = 1 << 6,   -- For OpenPopup*(), BeginPopupContext*(): focus and initialize navigation even when not reopening.
    NoOpenOverExistingPopup = bitLShift(1, 7), -- For OpenPopup*(), BeginPopupContext*(): don't open if there's already a popup at the same level of the popup stack
    NoOpenOverItems         = bitLShift(1, 8), -- For BeginPopupContextWindow(): don't return true when hovering items, only when hovering empty space
    AnyPopupId              = bitLShift(1, 10), -- For IsPopupOpen(): ignore the ImGuiID parameter and test for any popup.
    AnyPopupLevel           = bitLShift(1, 11) -- For IsPopupOpen(): search/test at any level of the popup stack (default test in the current level)
}

ImGuiPopupFlags.AnyPopup          = bitOr(ImGuiPopupFlags.AnyPopupId, ImGuiPopupFlags.AnyPopupLevel)
ImGuiPopupFlags.MouseButtonShift_ = 2 -- [Internal]
ImGuiPopupFlags.MouseButtonMask_  = 0x0C -- [Internal]
ImGuiPopupFlags.InvalidMask_      = 0x03 -- [Internal] Reserve legacy bits 0-1 to detect incorrectly passing 1 or 2 to the function.

-- Flags for ImGui.BeginCombo()
--- @enum ImGuiComboFlags
ImGuiComboFlags = {
    None            = 0,
    PopupAlignLeft  = bitLShift(1, 0), -- Align the popup toward the left by default
    HeightSmall     = bitLShift(1, 1), -- Max ~4 items visible. Tip: If you want your combo popup to be a specific size you can use SetNextWindowSizeConstraints() prior to calling BeginCombo()
    HeightRegular   = bitLShift(1, 2), -- Max ~8 items visible (default)
    HeightLarge     = bitLShift(1, 3), -- Max ~20 items visible
    HeightLargest   = bitLShift(1, 4), -- As many fitting items as possible
    NoArrowButton   = bitLShift(1, 5), -- Display on the preview box without the square arrow button
    NoPreview       = bitLShift(1, 6), -- Display only a square arrow button
    WidthFitPreview = bitLShift(1, 7) -- Width dynamically calculated from preview contents
}

ImGuiComboFlags.HeightMask_ = bitOr(ImGuiComboFlags.HeightSmall, ImGuiComboFlags.HeightRegular, ImGuiComboFlags.HeightLarge, ImGuiComboFlags.HeightLargest)
ImGuiComboFlags.CustomPreview = bitLShift(1, 20) -- [Luau] obsolete: removed in 1.93.0 (BeginComboPreview() no longer needs a flag), kept as an ignored value

-- Flags for ImGui.Selectable()
--- @enum ImGuiSelectableFlags
ImGuiSelectableFlags = {
    None              = 0,
    NoAutoClosePopups = bitLShift(1, 0), -- Clicking this doesn't close parent popup window (overrides ImGuiItemFlags.AutoClosePopups)
    SpanAllColumns    = bitLShift(1, 1), -- Frame will span all columns of its container table (text will still fit in current column)
    AllowDoubleClick  = bitLShift(1, 2), -- Generate press events on double clicks too
    Disabled          = bitLShift(1, 3), -- Cannot be selected, display grayed out text
    AllowOverlap      = bitLShift(1, 4), -- Hit testing will allow subsequent widgets to overlap this one. Require previous frame HoveredId to match before being usable. Shortcut to calling SetNextItemAllowOverlap().
    Highlight         = bitLShift(1, 5), -- Make the item be displayed as if it is hovered
    SelectOnNav       = bitLShift(1, 6), -- Auto-select when moved into, unless Ctrl is held. Automatic when in a BeginMultiSelect() block.

    -- NB: need to be in sync with last value of ImGuiSelectableFlags_
    NoHoldingActiveID    = bitLShift(1, 20),
    SelectOnClick        = bitLShift(1, 22), -- Override button behavior to react on Click (default is Click+Release)
    SelectOnRelease      = bitLShift(1, 23), -- Override button behavior to react on Release (default is Click+Release)
    SpanAvailWidth       = bitLShift(1, 24), -- Span all avail width even if we declared less for layout purpose. FIXME: We may be able to remove this (added in 6251d379, 2bcafc86 for menus)
    SetNavIdOnHover      = bitLShift(1, 25), -- Set Nav/Focus ID on mouse hover (used by MenuItem)
    NoPadWithHalfSpacing = bitLShift(1, 26), -- Disable padding each side with ItemSpacing * 0.5f
    NoSetKeyOwner        = bitLShift(1, 27), -- Don't set key/input owner on the initial click (note: mouse buttons are keys! often, the key in question will be ImGuiKey.MouseLeft!)
}

-- Flags for ColorEdit3() / ColorEdit4() / ColorPicker3() / ColorPicker4() / ColorButton()
--- @enum ImGuiColorEditFlags
ImGuiColorEditFlags = {
    None           = 0,
    NoAlpha        = bitLShift(1, 1), -- ColorEdit, ColorPicker, ColorButton: ignore Alpha component (will only read 3 components from the input pointer).
    NoPicker       = bitLShift(1, 2), -- ColorEdit: disable picker when clicking on color square.
    NoOptions      = bitLShift(1, 3), -- ColorEdit: disable toggling options menu when right-clicking on inputs/small preview.
    NoSmallPreview = bitLShift(1, 4), -- ColorEdit, ColorPicker: disable color square preview next to the inputs. (e.g. to show only the inputs)
    NoInputs       = bitLShift(1, 5), -- ColorEdit, ColorPicker: disable inputs sliders/text widgets (e.g. to show only the small preview color square).
    NoTooltip      = bitLShift(1, 6), -- ColorEdit, ColorPicker, ColorButton: disable tooltip when hovering the preview.
    NoLabel        = bitLShift(1, 7), -- ColorEdit, ColorPicker: disable display of inline text label (the label is still forwarded to the tooltip and picker).
    NoSidePreview  = bitLShift(1, 8), -- ColorPicker: disable bigger color preview on right side of the picker, use small color square preview instead.
    NoDragDrop     = bitLShift(1, 9), -- ColorEdit: disable drag and drop target/source. ColorButton: disable drag and drop source.
    NoBorder       = bitLShift(1, 10), -- ColorButton: disable border (which is enforced by default)
    NoColorMarkers = bitLShift(1, 11), -- ColorEdit: disable rendering R/G/B/A color marker. May also be disabled globally by setting style.ColorMarkerSize = 0.

    -- Alpha preview
    AlphaOpaque      = bitLShift(1, 12), -- ColorEdit, ColorPicker, ColorButton: disable alpha in the preview,. Contrary to _NoAlpha it may still be edited when calling ColorEdit4()/ColorPicker4(). For ColorButton() this does the same as _NoAlpha.
    AlphaNoBg        = bitLShift(1, 13), -- ColorEdit, ColorPicker, ColorButton: disable rendering a checkerboard background behind transparent color.
    AlphaPreviewHalf = bitLShift(1, 14), -- ColorEdit, ColorPicker, ColorButton: display half opaque / half transparent preview.

    -- User Options (right-click on widget to change some of them)
    AlphaBar       = bitLShift(1, 18), -- ColorEdit, ColorPicker: show vertical alpha bar/gradient in picker.
    HDR            = bitLShift(1, 19), -- (WIP) ColorEdit: Currently only disable 0.0f..1.0f limits in RGBA edition (note: you probably want to use ImGuiColorEditFlags.Float flag as well).
    DisplayRGB     = bitLShift(1, 20), -- [Display]    -- ColorEdit: override _display_ type among RGB/HSV/Hex. ColorPicker: select any combination using one or more of RGB/HSV/Hex.
    DisplayHSV     = bitLShift(1, 21), -- [Display]    -- "
    DisplayHex     = bitLShift(1, 22), -- [Display]    -- "
    Uint8          = bitLShift(1, 23), -- [DataType]   -- ColorEdit, ColorPicker, ColorButton: _display_ values formatted as 0..255.
    Float          = bitLShift(1, 24), -- [DataType]   -- ColorEdit, ColorPicker, ColorButton: _display_ values formatted as 0.0f..1.0f floats instead of 0..255 integers. No round-trip of value via integers.
    PickerHueBar   = bitLShift(1, 25), -- [Picker]     -- ColorPicker: bar for Hue, rectangle for Sat/Value.
    PickerHueWheel = bitLShift(1, 26), -- [Picker]     -- ColorPicker: wheel for Hue, triangle for Sat/Value.
    PickerNoRotate = bitLShift(1, 27), -- [Picker]     -- ColorPicker: disable rotating Sat/Value triangle. Best set in io.ConfigColorEditFlags once.
    InputRGB       = bitLShift(1, 28), -- [Input]      -- ColorEdit, ColorPicker: input and output data in RGB format.
    InputHSV       = bitLShift(1, 29) -- [Input]      -- ColorEdit, ColorPicker: input and output data in HSV format.
}

-- Defaults Options copied to io.ConfigColorEditFlags during initialization.
-- The intent is that you probably don't want to override them in most of your calls.
-- Let the user choose via the option menu and/or modify io.ConfigColorEditFlags directly during startup if you want.
ImGuiColorEditFlags.DefaultOptions_ = bitOr(ImGuiColorEditFlags.Uint8, ImGuiColorEditFlags.DisplayRGB, ImGuiColorEditFlags.InputRGB, ImGuiColorEditFlags.PickerHueBar)
-- [Internal] Masks
ImGuiColorEditFlags.AlphaMask_ = bitOr( ImGuiColorEditFlags.NoAlpha, ImGuiColorEditFlags.AlphaOpaque, ImGuiColorEditFlags.AlphaNoBg, ImGuiColorEditFlags.AlphaPreviewHalf )
ImGuiColorEditFlags.DisplayMask_ = bitOr( ImGuiColorEditFlags.DisplayRGB, ImGuiColorEditFlags.DisplayHSV, ImGuiColorEditFlags.DisplayHex )
ImGuiColorEditFlags.DataTypeMask_ = bitOr( ImGuiColorEditFlags.Uint8, ImGuiColorEditFlags.Float )
ImGuiColorEditFlags.PickerMask_ = bitOr( ImGuiColorEditFlags.PickerHueWheel, ImGuiColorEditFlags.PickerHueBar )
ImGuiColorEditFlags.InputMask_ = bitOr( ImGuiColorEditFlags.InputRGB, ImGuiColorEditFlags.InputHSV )

-- Flags for DragFloat(), DragInt(), SliderFloat(), SliderInt() etc.
-- We use the same sets of flags for DragXXX() and SliderXXX() functions as the features are the same and it makes it easier to swap them.
-- (Those are per-item flags. There is shared behavior flag too: ImGuiIO: io.ConfigDragClickToInputText)
--- @enum ImGuiSliderFlags
ImGuiSliderFlags = {
    None            = 0,
    Logarithmic     = bitLShift(1, 5), -- Make the widget logarithmic (linear otherwise). Consider using ImGuiSliderFlags.NoRoundToFormat with this if using a format-string with small amount of digits.
    NoRoundToFormat = bitLShift(1, 6), -- Disable rounding underlying value to match precision of the display format string (e.g. %.3f values are rounded to those 3 digits).
    NoInput         = bitLShift(1, 7), -- Disable Ctrl+Click or Enter key allowing to input text directly into the widget.
    WrapAround      = bitLShift(1, 8), -- Enable wrapping around from max to min and from min to max. Only supported by DragXXX() functions for now.
    ClampOnInput    = bitLShift(1, 9), -- Clamp value to min/max bounds when input manually with Ctrl+Click. By default Ctrl+Click allows going out of bounds.
    ClampZeroRange  = bitLShift(1, 10), -- Clamp even if min==max==0.0f. Otherwise due to legacy reason DragXXX functions don't clamp with those values. When your clamping limits are dynamic you almost always want to use it.
    NoSpeedTweaks   = bitLShift(1, 11), -- Disable keyboard modifiers altering tweak speed. Useful if you want to alter tweak speed yourself based on your own logic.
    ColorMarkers    = bitLShift(1, 12), -- DragScalarN(), SliderScalarN(): Draw R/G/B/A color markers on each component.
    --ImGuiSliderFlags.LiveEditOnInput  = 1 << 13,      -- Shortcut to enable LiveEdit for this field.
    --ImGuiSliderFlags.NoLiveEditOnInput= 1 << 14,      -- Shortcut to disable LiveEdit for this field.
    InvalidMask_    = 0x7000000F, -- [Internal] We treat using those bits as being potentially a 'float power' argument from legacy API (obsoleted 2020-08) that has got miscast to this enum, and will trigger an assert if needed.
}

ImGuiSliderFlags.AlwaysClamp = bitOr(ImGuiSliderFlags.ClampOnInput, ImGuiSliderFlags.ClampZeroRange)

ImGuiSliderFlags.Vertical = bitLShift(1, 20) -- Should this slider be orientated vertically?
ImGuiSliderFlags.ReadOnly = bitLShift(1, 21) -- Consider using g.NextItemData.ItemFlags |= ImGuiItemFlags.ReadOnly instead.

-- [ALPHA] Rarely used / very advanced uses only. Use with SetNextWindowClass() and DockSpace() functions.
-- Important: the content of this class is still highly WIP and likely to change and be refactored
-- before we stabilize Docking features. Please be mindful if using this.
-- Provide hints:
-- - To the platform backend via altered viewport flags (enable/disable OS decoration, OS task bar icons, etc.)
-- - To the platform backend for OS level parent/child relationships of viewport (otherwise: default is configured via io.ConfigViewportsNoDefaultParent)
-- - To the docking system for various options and filtering.
--- @class ImGuiWindowClass
--- @field ClassId                    ImGuiID
--- @field ParentViewportId           ImGuiID
--- @field FocusRouteParentWindowId   ImGuiID
--- @field ViewportFlagsOverrideSet   ImGuiViewportFlags
--- @field ViewportFlagsOverrideClear ImGuiViewportFlags

--- @return ImGuiWindowClass
--- @nodiscard
function ImGuiWindowClass()
    return {
        ClassId                    = 0, -- User data. 0 = Default class (unclassed). Windows of different classes cannot be docked with each others.
        ParentViewportId           = 0xFFFFFFFF, -- Hint for the platform backend. -1: use default. 0: request platform backend to not parent the platform. != 0: request platform backend to create a parent<>child relationship between the platform windows. Not conforming backends are free to e.g. parent every viewport to the main viewport or not.
        FocusRouteParentWindowId   = 0, -- ID of parent window for shortcut focus route evaluation, e.g. Shortcut() call from Parent Window will succeed when this window is focused.
        ViewportFlagsOverrideSet   = 0, -- Viewport flags to set when a window of this class owns a viewport. This allows you to enforce OS decoration or task bar icon, override the defaults on a per-window basis.
        ViewportFlagsOverrideClear = 0, -- Viewport flags to clear when a window of this class owns a viewport. This allows you to enforce OS decoration or task bar icon, override the defaults on a per-window basis.

        TabItemFlagsOverrideSet  = 0, -- [EXPERIMENTAL] TabItem flags to set when a window of this class gets submitted into a dock node tab bar. May use with ImGuiTabItemFlags.Leading or ImGuiTabItemFlags.Trailing.
        DockNodeFlagsOverrideSet = 0, -- [EXPERIMENTAL] Dock node flags to set when a window of this class is hosted by a dock node (it doesn't have to be selected!)
        DockingAlwaysTabBar      = false, -- Set to true to enforce single floating windows of this class always having their own docking node (equivalent of setting the global io.ConfigDockingAlwaysTabBar)
        PlatformIconData         = nil, -- void* to hold custom data structure for the OS / platform to specify an icon. Currently unused for exposed to allow experiments.
        DockingAllowUnclassed    = true -- Set to true to allow windows of this class to be docked/merged with an unclassed window. -- FIXME-DOCK: Move to DockNodeFlags override?
    }
end

-- Flags for ImGui.InputText()
-- (Those are per-item flags. There are shared flags in ImGuiIO: io.ConfigInputTextCursorBlink and io.ConfigInputTextEnterKeepActive)
--- @enum ImGuiInputTextFlags
ImGuiInputTextFlags = {
    -- Basic filters (also see ImGuiInputTextFlags.CallbackCharFilter)
    None = 0,

    -- Basic filters (also see ImGuiInputTextFlags.CallbackCharFilter)
    CharsDecimal     = bitLShift(1, 0), -- Allow 0123456789.+-*/
    CharsHexadecimal = bitLShift(1, 1), -- Allow 0123456789ABCDEFabcdef
    CharsScientific  = bitLShift(1, 2), -- Allow 0123456789.+-*/eE (Scientific notation input)
    CharsUppercase   = bitLShift(1, 3), -- Turn a..z into A..Z
    CharsNoBlank     = bitLShift(1, 4), -- Filter out spaces, tabs

    -- Inputs
    AllowTabInput       = bitLShift(1, 5), -- Pressing TAB input a '\t' character into the text field
    EnterReturnsTrue    = bitLShift(1, 6), -- Return 'true' when Enter is pressed (as opposed to every time the value was modified). Consider disabling LiveEdit! or using IsItemDeactivatedAfterEdit() instead!
    EscapeClearsAll     = bitLShift(1, 7), -- Escape key clears content if not empty, and deactivate otherwise (contrast to default behavior of Escape to revert)
    CtrlEnterForNewLine = bitLShift(1, 8), -- In multi-line mode: validate with Enter, add new line with Ctrl+Enter (default is opposite: validate with Ctrl+Enter, add line with Enter). Note that Shift+Enter always enter a new line either way.

    -- Other options
    ReadOnly           = bitLShift(1, 9), -- Read-only mode
    Password           = bitLShift(1, 10), -- Password mode, display all characters as '*', disable copy
    AlwaysOverwrite    = bitLShift(1, 11), -- Overwrite mode
    AutoSelectAll      = bitLShift(1, 12), -- Select entire text when first taking mouse focus
    ParseEmptyRefVal   = bitLShift(1, 13), -- InputFloat(), InputInt(), InputScalar() etc. only: parse empty string as zero value.
    DisplayEmptyRefVal = bitLShift(1, 14), -- InputFloat(), InputInt(), InputScalar() etc. only: when value is zero, do not display it. Generally used with ImGuiInputTextFlags.ParseEmptyRefVal.
    NoHorizontalScroll = bitLShift(1, 15), -- Disable following the cursor horizontally
    NoUndoRedo         = bitLShift(1, 16), -- Disable undo/redo. Note that input text owns the text data while active, if you want to provide your own undo/redo stack you need e.g. to call ClearActiveID().

    -- Elide display / Alignment
    ElideLeft = bitLShift(1, 17), -- When text doesn't fit, elide left side to ensure right side stays visible. Useful for path/filenames. Single-line only!

    -- Callback features
    CallbackCompletion = bitLShift(1, 18), -- Callback on pressing TAB (for completion handling)
    CallbackHistory    = bitLShift(1, 19), -- Callback on pressing Up/Down arrows (for history handling)
    CallbackAlways     = bitLShift(1, 20), -- Callback on each iteration. User code may query cursor position, modify text buffer.
    CallbackCharFilter = bitLShift(1, 21), -- Callback on character inputs to replace or discard them. Modify 'EventChar' to replace or discard, or return 1 in callback to discard.
    CallbackResize     = bitLShift(1, 22), -- Callback on buffer capacity changes request (beyond 'buf_size' parameter value), allowing the string to grow. Notify when the string wants to be resized (for string types which hold a cache of their Size). You will be provided a new BufSize in the callback and NEED to honor it. (see misc/cpp/imgui_stdlib.h for an example of using this)
    CallbackEdit       = bitLShift(1, 23), -- Callback on any edit. Note that InputText() already returns true on edit + you can always use IsItemEdited(). The callback is useful to manipulate the underlying buffer while focus is active.

    -- Multi-line Word-Wrapping [BETA]
    WordWrap = bitLShift(1, 24), -- InputTextMultiline(): word-wrap lines that are too long.

    -- [Internal]
    Multiline            = bitLShift(1, 26), -- For internal use by InputTextMultiline()
    TempInput            = bitLShift(1, 27), -- For internal use by TempInputText(), will skip calling ItemAdd(). Require bounding-box to strictly match.
    LocalizeDecimalPoint = bitLShift(1, 28), -- For internal use by InputScalar() and TempInputScalar()
}

-------------------------------------------------------------------------------
-- [SECTION] Misc data structures (ImGuiInputTextCallbackData, ImGuiSizeCallbackData, ImGuiPayload)
-------------------------------------------------------------------------------

-- Shared state of InputText(), passed as an argument to your callback when a ImGuiInputTextFlags.Callback* flag is used.
-- The callback function should return 0 by default.
-- Callbacks (follow a flag name and see comments in ImGuiInputTextFlags_ declarations for more details)
-- - ImGuiInputTextFlags.CallbackEdit:        Callback on buffer edit. Note that InputText() already returns true on edit + you can always use IsItemEdited(). The callback is useful to manipulate the underlying buffer while focus is active.
-- - ImGuiInputTextFlags.CallbackAlways:      Callback on each iteration
-- - ImGuiInputTextFlags.CallbackCompletion:  Callback on pressing TAB
-- - ImGuiInputTextFlags.CallbackHistory:     Callback on pressing Up/Down arrows
-- - ImGuiInputTextFlags.CallbackCharFilter:  Callback on character inputs to replace or discard them. Modify 'EventChar' to replace or discard, or return 1 in callback to discard.
-- - ImGuiInputTextFlags.CallbackResize:      Callback on buffer capacity changes request (beyond 'buf_size' parameter value), allowing the string to grow.
--- @class ImGuiInputTextCallbackData

--- @return ImGuiInputTextCallbackData
-- [Port] Buf is a 1-based zero-terminated byte table; positions (CursorPos, pos...) are 0-based byte offsets like upstream.
MT.ImGuiInputTextCallbackData = {}
MT.ImGuiInputTextCallbackData.__index = MT.ImGuiInputTextCallbackData
function ImGuiInputTextCallbackData()
    return setmetatable({}, MT.ImGuiInputTextCallbackData)
end

function MT.ImGuiInputTextCallbackData:DeleteChars(pos, bytes_count)
    IM_ASSERT(pos + bytes_count <= self.BufTextLen)
    local buf = self.Buf
    local n = self.BufTextLen - bytes_count - pos + 1 -- [Port] includes zero terminator
    for i = 1, n do buf[pos + i] = buf[pos + bytes_count + i] end

    if self.CursorPos >= pos + bytes_count then
        self.CursorPos = self.CursorPos - bytes_count
    elseif self.CursorPos >= pos then
        self.CursorPos = pos
    end
    self.SelectionStart = self.CursorPos; self.SelectionEnd = self.CursorPos
    self.BufDirty = true
    self.BufTextLen = self.BufTextLen - bytes_count
end

--- @param new_text string
function MT.ImGuiInputTextCallbackData:InsertChars(pos, new_text)
    local new_text_len = #new_text
    if new_text_len == 0 then return end
    local is_resizable = bit32.band(self.Flags, ImGuiInputTextFlags.CallbackResize) ~= 0
    -- We support partial insertion
    local avail = self.BufSize - 1 - self.BufTextLen
    if not is_resizable and new_text_len > avail then
        new_text_len = avail
    end
    if new_text_len <= 0 then return end

    if self.BufTextLen + new_text_len + 1 > self.BufSize then
        new_text_len = self.BufSize - 1 - self.BufTextLen
        if new_text_len <= 0 then return end
    end

    local buf = self.Buf
    for i = self.BufTextLen, pos + 1, -1 do buf[i + new_text_len] = buf[i] end
    for i = 1, new_text_len do buf[pos + i] = string.byte(new_text, i) end
    buf[self.BufTextLen + new_text_len + 1] = 0

    self.BufDirty = true
    self.BufTextLen = self.BufTextLen + new_text_len
    if self.CursorPos >= pos then
        self.CursorPos = self.CursorPos + new_text_len
    end
    self.SelectionStart = self.CursorPos; self.SelectionEnd = self.CursorPos
end

function MT.ImGuiInputTextCallbackData:SelectAll() self.SelectionStart = 0; self.CursorPos = self.BufTextLen; self.SelectionEnd = self.BufTextLen end
function MT.ImGuiInputTextCallbackData:SetSelection(s, e) IM_ASSERT(s >= 0 and s <= self.BufTextLen); IM_ASSERT(e >= 0 and e <= self.BufTextLen); self.SelectionStart = s; self.CursorPos = e; self.SelectionEnd = e end
function MT.ImGuiInputTextCallbackData:ClearSelection() self.SelectionStart = self.BufTextLen; self.SelectionEnd = self.BufTextLen end
function MT.ImGuiInputTextCallbackData:HasSelection() return self.SelectionStart ~= self.SelectionEnd end

-- Callback and functions types
--- @alias ImGuiInputTextCallback fun(data: ImGuiInputTextCallbackData)

--- @alias ImGuiMemAllocFunc fun(T: function, start_idx: int, end_idx: int, userdata: any): table
--- @alias ImGuiMemFreeFunc fun(owner: table, field: string, userdata: any)

-- ImDrawCallback: Draw callbacks for advanced uses [configurable type: override in imconfig.h]
-- NB: You most likely do NOT need to use draw callbacks just to create your own widget or customized UI rendering,
-- you can poke into the draw list for that! Draw callback may be useful for example to:
--  A) Change your GPU render state,
--  B) render a complex 3D scene inside a UI element without an intermediate texture/render target, etc.
-- The expected behavior from your rendering function is 'if (cmd.UserCallback != nil) { cmd.UserCallback(parent_list, cmd); } else { RenderTriangles() }'
--- @alias ImDrawCallback fun(parent_list: ImDrawList, cmd: ImDrawCmd)

-- Flags for ImGui.TreeNodeEx(), ImGui.CollapsingHeader*()
--- @enum ImGuiTreeNodeFlags
ImGuiTreeNodeFlags = {
    None                 = 0,
    Selected             = bitLShift(1, 0), -- Draw as selected
    Framed               = bitLShift(1, 1), -- Draw frame with background (e.g. for CollapsingHeader)
    AllowOverlap         = bitLShift(1, 2), -- Hit testing will allow subsequent widgets to overlap this one. Require previous frame HoveredId to match before being usable. Shortcut to calling SetNextItemAllowOverlap().
    NoTreePushOnOpen     = bitLShift(1, 3), -- Don't do a TreePush() when open (e.g. for CollapsingHeader) = no extra indent nor pushing on ID stack
    NoAutoOpenOnLog      = bitLShift(1, 4), -- Don't automatically and temporarily open node when Logging is active (by default logging will automatically open tree nodes)
    DefaultOpen          = bitLShift(1, 5), -- Default node to be open
    OpenOnDoubleClick    = bitLShift(1, 6), -- Open on double-click instead of simple click (default for multi-select unless any _OpenOnXXX behavior is set explicitly). Both behaviors may be combined.
    OpenOnArrow          = bitLShift(1, 7), -- Open when clicking on the arrow part (default for multi-select unless any _OpenOnXXX behavior is set explicitly). Both behaviors may be combined.
    Leaf                 = bitLShift(1, 8), -- No collapsing, no arrow (use as a convenience for leaf nodes). Note: will always open a tree/id scope and return true. If you never use that scope, add ImGuiTreeNodeFlags.NoTreePushOnOpen.
    Bullet               = bitLShift(1, 9), -- Display a bullet instead of arrow. IMPORTANT: node can still be marked open/close if you don't set the _Leaf flag!
    FramePadding         = bitLShift(1, 10), -- Use FramePadding (even for an unframed text node) to vertically align text baseline to regular widget height. Equivalent to calling AlignTextToFramePadding() before the node.
    SpanAvailWidth       = bitLShift(1, 11), -- Extend hit box to the right-most edge, even if not framed. This is not the default in order to allow adding other items on the same line without using AllowOverlap mode.
    SpanFullWidth        = bitLShift(1, 12), -- Extend hit box to the left-most and right-most edges (cover the indent area).
    SpanLabelWidth       = bitLShift(1, 13), -- Narrow hit box + narrow hovering highlight, will only cover the label text.
    SpanAllColumns       = bitLShift(1, 14), -- Frame will span all columns of its container table (label will still fit in current column)
    LabelSpanAllColumns  = bitLShift(1, 15), -- Label will span all columns of its container table
    --ImGuiTreeNodeFlags.NoScrollOnOpen     = 1 << 16,  -- FIXME: TODO: Disable automatic scroll on TreePop() if node got just open and contents is not visible
    NavLeftJumpsToParent = bitLShift(1, 17), -- Nav: left arrow moves back to parent. This is processed in TreePop() when there's an unfulfilled Left nav request remaining.
    -- [EXPERIMENTAL] Draw lines connecting TreeNode hierarchy. Discuss in GitHub issue #2920.
    -- Default value is pulled from style.TreeLinesFlags. May be overridden in TreeNode calls.
    DrawLinesNone        = bitLShift(1, 18), -- No lines drawn
    DrawLinesFull        = bitLShift(1, 19), -- Horizontal lines to child nodes. Vertical line drawn down to TreePop() position: cover full contents. Faster (for large trees).
    DrawLinesToNodes     = bitLShift(1, 20), -- Horizontal lines to child nodes. Vertical line drawn down to bottom-most child node. Slower (for large trees).

    NoNavFocus                 = bitLShift(1, 27), -- Don't claim nav focus when interacting with this item (#8551)
    ClipLabelForTrailingButton = bitLShift(1, 28), -- FIXME-WIP: Hard-coded for CollapsingHeader()
    UpsideDownArrow            = bitLShift(1, 29), -- FIXME-WIP: Turn Down arrow into an Up arrow, for reversed trees (#6517)
}

ImGuiTreeNodeFlags.CollapsingHeader = bitOr(ImGuiTreeNodeFlags.Framed, ImGuiTreeNodeFlags.NoTreePushOnOpen, ImGuiTreeNodeFlags.NoAutoOpenOnLog)

ImGuiTreeNodeFlags.OpenOnMask_ = bitOr(ImGuiTreeNodeFlags.OpenOnDoubleClick, ImGuiTreeNodeFlags.OpenOnArrow)
ImGuiTreeNodeFlags.DrawLinesMask_ = bitOr(ImGuiTreeNodeFlags.DrawLinesNone, ImGuiTreeNodeFlags.DrawLinesFull, ImGuiTreeNodeFlags.DrawLinesToNodes)

-------------------------------------------------------------------------------
-- [SECTION] Tables API flags and structures (ImGuiTableFlags, ImGuiTableColumnFlags, ImGuiTableRowFlags, ImGuiTableBgTarget, ImGuiTableSortSpecs, ImGuiTableColumnSortSpecs)
-------------------------------------------------------------------------------

-- Flags for ImGui.BeginTable()
-- - Important! Sizing policies have complex and subtle side effects, much more so than you would expect.
--   Read comments/demos carefully + experiment with live demos to get acquainted with them.
-- - The DEFAULT sizing policies are:
--    - Default to ImGuiTableFlags.SizingFixedFit    if ScrollX is on, or if host window has ImGuiWindowFlags.AlwaysAutoResize.
--    - Default to ImGuiTableFlags.SizingStretchSame if ScrollX is off.
-- - When ScrollX is off:
--    - Table defaults to ImGuiTableFlags.SizingStretchSame -> all Columns defaults to ImGuiTableColumnFlags.WidthStretch with same weight.
--    - Columns sizing policy allowed: Stretch (default), Fixed/Auto.
--    - Fixed Columns (if any) will generally obtain their requested width (unless the table cannot fit them all).
--    - Stretch Columns will share the remaining width according to their respective weight.
--    - Mixed Fixed/Stretch columns is possible but has various side-effects on resizing behaviors.
--      The typical use of mixing sizing policies is: any number of LEADING Fixed columns, followed by one or two TRAILING Stretch columns.
--      (this is because the visible order of columns have subtle but necessary effects on how they react to manual resizing).
-- - When ScrollX is on:
--    - Table defaults to ImGuiTableFlags.SizingFixedFit -> all Columns defaults to ImGuiTableColumnFlags.WidthFixed
--    - Columns sizing policy allowed: Fixed/Auto mostly.
--    - Fixed Columns can be enlarged as needed. Table will show a horizontal scrollbar if needed.
--    - When using auto-resizing (non-resizable) fixed columns, querying the content width to use item right-alignment e.g. SetNextItemWidth(-FLT_MIN) doesn't make sense, would create a feedback loop.
--    - Using Stretch columns OFTEN DOES NOT MAKE SENSE if ScrollX is on, UNLESS you have specified a value for 'inner_width' in BeginTable().
--      If you specify a value for 'inner_width' then effectively the scrolling space is known and Stretch or mixed Fixed/Stretch columns become meaningful again.
-- - Read on documentation at the top of imgui_tables.cpp for details.
--- @enum ImGuiTableFlags
ImGuiTableFlags =
{
    -- Features
    None                       = 0,
    Resizable                  = bitLShift(1, 0), -- Enable resizing columns.
    Reorderable                = bitLShift(1, 1), -- Enable reordering columns in header row. (Need calling TableSetupColumn() + TableHeadersRow() to display headers, or using ImGuiTableFlags.ContextMenuInBody to access context-menu without headers).
    Hideable                   = bitLShift(1, 2), -- Enable hiding/disabling columns in context menu.
    Sortable                   = bitLShift(1, 3), -- Enable sorting. Call TableGetSortSpecs() to obtain sort specs. Also see ImGuiTableFlags.SortMulti and ImGuiTableFlags.SortTristate.
    NoSavedSettings            = bitLShift(1, 4), -- Disable persisting columns order, width, visibility and sort settings in the .ini file.
    ContextMenuInBody          = bitLShift(1, 5), -- Right-click on columns body/contents will also display table context menu. By default it is available in TableHeadersRow().
    -- Decorations
    RowBg                      = bitLShift(1, 6), -- Set each RowBg color with ImGuiCol.TableRowBg or ImGuiCol.TableRowBgAlt (equivalent of calling TableSetBgColor with ImGuiTableBgFlags.RowBg0 on each row manually)
    BordersInnerH              = bitLShift(1, 7), -- Draw horizontal borders between rows.
    BordersOuterH              = bitLShift(1, 8), -- Draw horizontal borders at the top and bottom.
    BordersInnerV              = bitLShift(1, 9), -- Draw vertical borders between columns.
    BordersOuterV              = bitLShift(1, 10), -- Draw vertical borders on the left and right sides.
    NoBordersInBody            = bitLShift(1, 11), -- [ALPHA] Disable vertical borders in columns Body (borders will always appear in Headers). -> May move to style
    NoBordersInBodyUntilResize = bitLShift(1, 12), -- [ALPHA] Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers). -> May move to style
    -- Sizing Policy (read above for defaults)
    SizingFixedFit             = bitLShift(1, 13), -- Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable), matching contents width.
    SizingFixedSame            = bitLShift(2, 13), -- Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable), matching the maximum contents width of all columns. Implicitly enable ImGuiTableFlags.NoKeepColumnsVisible.
    SizingStretchProp          = bitLShift(3, 13), -- Columns default to _WidthStretch with default weights proportional to each columns contents widths.
    SizingStretchSame          = bitLShift(4, 13), -- Columns default to _WidthStretch with default weights all equal, unless overridden by TableSetupColumn().
    -- Sizing Extra Options
    NoHostExtendX              = bitLShift(1, 16), -- Make outer width auto-fit to columns, overriding outer_size.x value. Only available when ScrollX/ScrollY are disabled and Stretch columns are not used.
    NoHostExtendY              = bitLShift(1, 17), -- Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit). Only available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.
    NoKeepColumnsVisible       = bitLShift(1, 18), -- Disable keeping column always minimally visible when ScrollX is off and table gets too small. Not recommended if columns are resizable.
    PreciseWidths              = bitLShift(1, 19), -- Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.
    -- Clipping
    NoClip                     = bitLShift(1, 20), -- Disable clipping rectangle for every individual columns (reduce draw command count, items will be able to overflow into other columns). Generally incompatible with TableSetupScrollFreeze().
    -- Padding
    PadOuterX                  = bitLShift(1, 21), -- Default if BordersOuterV is on. Enable outermost padding. Generally desirable if you have headers.
    NoPadOuterX                = bitLShift(1, 22), -- Default if BordersOuterV is off. Disable outermost padding.
    NoPadInnerX                = bitLShift(1, 23), -- Disable inner padding between columns (double inner padding if BordersOuterV is on, single inner padding if BordersOuterV is off).
    -- Scrolling
    ScrollX                    = bitLShift(1, 24), -- Enable horizontal scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size. Changes default sizing policy. Because this creates a child window, ScrollY is currently generally recommended when using ScrollX.
    ScrollY                    = bitLShift(1, 25), -- Enable vertical scrolling. Require 'outer_size' parameter of BeginTable() to specify the container size.
    -- Sorting
    SortMulti                  = bitLShift(1, 26), -- Hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).
    SortTristate               = bitLShift(1, 27), -- Allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).
    -- Miscellaneous
    HighlightHoveredColumn     = bitLShift(1, 28), -- Highlight column headers when hovered (may evolve into a fuller highlight)
}
ImGuiTableFlags.BordersH     = bitOr(ImGuiTableFlags.BordersInnerH, ImGuiTableFlags.BordersOuterH) -- Draw horizontal borders.
ImGuiTableFlags.BordersV     = bitOr(ImGuiTableFlags.BordersInnerV, ImGuiTableFlags.BordersOuterV) -- Draw vertical borders.
ImGuiTableFlags.BordersInner = bitOr(ImGuiTableFlags.BordersInnerV, ImGuiTableFlags.BordersInnerH) -- Draw inner borders.
ImGuiTableFlags.BordersOuter = bitOr(ImGuiTableFlags.BordersOuterV, ImGuiTableFlags.BordersOuterH) -- Draw outer borders.
ImGuiTableFlags.Borders      = bitOr(ImGuiTableFlags.BordersInner, ImGuiTableFlags.BordersOuter) -- Draw all borders.
-- [Internal] Combinations and masks
ImGuiTableFlags.SizingMask_  = bitOr(ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.SizingFixedSame, ImGuiTableFlags.SizingStretchProp, ImGuiTableFlags.SizingStretchSame)

-- Flags for ImGui.TableSetupColumn()
--- @enum ImGuiTableColumnFlags
ImGuiTableColumnFlags =
{
    -- Input configuration flags
    None                 = 0,
    Disabled             = bitLShift(1, 0), -- Overriding/master disable flag: hide column, won't show in context menu (unlike calling TableSetColumnEnabled() which manipulates the user accessible state)
    DefaultHide          = bitLShift(1, 1), -- Default as a hidden/disabled column.
    DefaultSort          = bitLShift(1, 2), -- Default as a sorting column.
    WidthStretch         = bitLShift(1, 3), -- Column will stretch. Preferable with horizontal scrolling disabled (default if table sizing policy is _SizingStretchSame or _SizingStretchProp).
    WidthFixed           = bitLShift(1, 4), -- Column will not stretch. Preferable with horizontal scrolling enabled (default if table sizing policy is _SizingFixedFit and table is resizable).
    NoResize             = bitLShift(1, 5), -- Disable manual resizing.
    NoReorder            = bitLShift(1, 6), -- Disable manual reordering this column, this will also prevent other columns from crossing over this column.
    NoHide               = bitLShift(1, 7), -- Disable ability to hide/disable this column.
    NoClip               = bitLShift(1, 8), -- Disable clipping for this column (all NoClip columns will render in a same draw command).
    NoSort               = bitLShift(1, 9), -- Disable ability to sort on this field (even if ImGuiTableFlags.Sortable is set on the table).
    NoSortAscending      = bitLShift(1, 10), -- Disable ability to sort in the ascending direction.
    NoSortDescending     = bitLShift(1, 11), -- Disable ability to sort in the descending direction.
    NoHeaderLabel        = bitLShift(1, 12), -- TableHeadersRow() will submit an empty label for this column. Convenient for some small columns. Name will still appear in context menu or in angled headers. You may append into this cell by calling TableSetColumnIndex() right after the TableHeadersRow() call.
    NoHeaderWidth        = bitLShift(1, 13), -- Disable header text width contribution to automatic column width.
    PreferSortAscending  = bitLShift(1, 14), -- Make the initial sort direction Ascending when first sorting on this column (default).
    PreferSortDescending = bitLShift(1, 15), -- Make the initial sort direction Descending when first sorting on this column.
    IndentEnable         = bitLShift(1, 16), -- Use current Indent value when entering cell (default for column 0).
    IndentDisable        = bitLShift(1, 17), -- Ignore current Indent value when entering cell (default for columns > 0). Indentation changes _within_ the cell will still be honored.
    AngledHeader         = bitLShift(1, 18), -- TableHeadersRow() will submit an angled header row for this column. Note this will add an extra row.

    -- Output status flags, read-only via TableGetColumnFlags()
    IsEnabled            = bitLShift(1, 24), -- Status: is enabled == not hidden by user/api (referred to as "Hide" in _DefaultHide and _NoHide) flags.
    IsVisible            = bitLShift(1, 25), -- Status: is visible == is enabled AND not clipped by scrolling.
    IsSorted             = bitLShift(1, 26), -- Status: is currently part of the sort specs
    IsHovered            = bitLShift(1, 27), -- Status: is hovered by mouse

    NoDirectResize_      = bitLShift(1, 30), -- [Internal] Disable user resizing this column directly (it may however we resized indirectly from its left edge)
}
-- [Internal] Combinations and masks
ImGuiTableColumnFlags.WidthMask_  = bitOr(ImGuiTableColumnFlags.WidthStretch, ImGuiTableColumnFlags.WidthFixed)
ImGuiTableColumnFlags.IndentMask_ = bitOr(ImGuiTableColumnFlags.IndentEnable, ImGuiTableColumnFlags.IndentDisable)
ImGuiTableColumnFlags.StatusMask_ = bitOr(ImGuiTableColumnFlags.IsEnabled, ImGuiTableColumnFlags.IsVisible, ImGuiTableColumnFlags.IsSorted, ImGuiTableColumnFlags.IsHovered)

-- Flags for ImGui.TableNextRow()
-- - Headers: Identify header row (set default background color + width of its contents accounted differently for auto column width)
--- @enum ImGuiTableRowFlags
ImGuiTableRowFlags = { None = 0, Headers = bitLShift(1, 0) }

-- Enum for ImGui.TableSetBgColor()
-- Background colors are rendering in 3 layers:
--  - Layer 0: draw with RowBg0 color if set, otherwise draw with ColumnBg0 if set.
--  - Layer 1: draw with RowBg1 color if set, otherwise draw with ColumnBg1 if set.
--  - Layer 2: draw with CellBg color if set.
-- The purpose of the two row/columns layers is to let you decide if a background color change should override or blend with the existing color.
-- When using ImGuiTableFlags.RowBg on the table, each row has the RowBg0 color automatically set for odd/even rows.
-- If you set the color of RowBg0 target, your color will override the existing RowBg0 color.
-- If you set the color of RowBg1 or ColumnBg1 target, your color will blend over the RowBg0 color.
-- - RowBg0: Set row background color 0 (generally used for background, automatically set when ImGuiTableFlags.RowBg is used)
-- - RowBg1: Set row background color 1 (generally used for selection marking)
-- - CellBg: Set cell background color (top-most color)
--- @enum ImGuiTableBgTarget
ImGuiTableBgTarget = { None = 0, RowBg0 = 1, RowBg1 = 2, CellBg = 3 }

-- A sorting direction
-- - Ascending = 0->9, A->Z etc.
-- - Descending = 9->0, Z->A etc.
--- @enum ImGuiSortDirection
ImGuiSortDirection = { None = 0, Ascending = 1, Descending = 2 }

-- Resizing callback data to apply custom constraint. As enabled by SetNextWindowSizeConstraints(). Callback is called during the next Begin().
-- NB: For basic min/max size constraint on each axis you don't need to use the callback! The SetNextWindowSizeConstraints() parameters are enough.
--- @class ImGuiSizeCallbackData
--- @field UserData    any     Read-only.   What user passed to SetNextWindowSizeConstraints(). Generally store an integer or float in here.
--- @field Pos         ImVec2  Read-only.   Window position, for reference.
--- @field CurrentSize ImVec2  Read-only.   Current window size.
--- @field DesiredSize ImVec2  Read-write.  Desired size, based on user's mouse position. Write to this field to restrain resizing.
--- @return ImGuiSizeCallbackData
function ImGuiSizeCallbackData()
    return { UserData = nil, Pos = ImVec2(), CurrentSize = ImVec2(), DesiredSize = ImVec2() }
end


-- Data payload for Drag and Drop operations: AcceptDragDropPayload(), GetDragDropPayload()
--- @class ImGuiPayload
--- [Port] Drag and drop payload. `Data` is any Lua value (C++ stores raw bytes); `DataSize` kept for API parity.
local IM_PAYLOAD = {}
IM_PAYLOAD.__index = IM_PAYLOAD
function IM_PAYLOAD:Clear() ImGuiPayload_Clear(self) end
function IM_PAYLOAD:IsDataType(t) return ImGuiPayload_IsDataType(self, t) end
function IM_PAYLOAD:IsPreview() return self.Preview end
function IM_PAYLOAD:IsDelivery() return self.Delivery end
function ImGuiPayload()
    return setmetatable({ Data = nil, DataSize = 0, SourceId = 0, SourceParentId = 0, DataFrameCount = -1, DataType = "", Preview = false, Delivery = false }, IM_PAYLOAD)
end
function ImGuiPayload_Clear(p) p.SourceId = 0; p.SourceParentId = 0; p.Data = nil; p.DataSize = 0; p.DataType = ""; p.DataFrameCount = -1; p.Preview = false; p.Delivery = false end
function ImGuiPayload_IsDataType(p, t) return p.DataFrameCount ~= -1 and p.DataType == t end
function ImGuiPayload_IsPreview(p) return p.Preview end
function ImGuiPayload_IsDelivery(p) return p.Delivery end

-------------------------------------------------------------------------------
-- [SECTION] Helpers (ImGuiOnceUponAFrame, ImGuiTextFilter, ImGuiTextBuffer, ImGuiStorage, ImGuiListClipper, Math Operators, ImColor)
-------------------------------------------------------------------------------

-- Flags for ImGuiListClipper (currently not fully exposed in function calls: a future refactor will likely add this to ImGuiListClipper::Begin function equivalent)
--- @enum ImGuiListClipperFlags
ImGuiListClipperFlags = {
    None                  = 0,
    NoSetTableRowCounters = bitLShift(1, 0), -- [Internal] Disabled modifying table row counters. Avoid assumption that 1 clipper item == 1 table row.
}

-- Helper: Growable text buffer for logging/accumulating text
-- (this could be called 'ImGuiTextBuilder' / 'ImGuiStringBuilder')
--- @class ImGuiTextBuffer  # string builder: Buf is a list of string chunks
local ImGuiTextBufferMT = {}
ImGuiTextBufferMT.__index = ImGuiTextBufferMT
function ImGuiTextBuffer() return setmetatable({ Buf = {} }, ImGuiTextBufferMT) end
function ImGuiTextBufferMT:clear() self.Buf = {} end
function ImGuiTextBufferMT:empty() return #self.Buf == 0 end
function ImGuiTextBufferMT:append(str) self.Buf[#self.Buf + 1] = str end
function ImGuiTextBufferMT:appendf(fmt, ...) self.Buf[#self.Buf + 1] = string.format(fmt, ...) end
function ImGuiTextBufferMT:c_str() return table.concat(self.Buf) end
function ImGuiTextBufferMT:size() return #self:c_str() end

-- Helpers: ImColor() implicitly converts colors to either ImU32 (packed 4x1 byte) or ImVec4 (4x1 float)
-- Prefer using IM_COL32() macros. Avoid storing ImColor! Store either u32 of ImVec4. This is not a full-featured color class.
-- **None of the ImGui API are using ImColor directly but you can use it as a convenience to pass colors in either ImU32 or ImVec4 formats. Explicitly cast to ImU32 or ImVec4 if needed.
-- [Luau] no implicit conversions: use :U32() / .Value (ImVec4). Overloads: ImColor(), ImColor(r, g, b, a) floats,
-- ImColor(ImVec4), ImColor(ImU32). The C++ int (0-255) overload can't be told apart from floats: use ImColor(IM_COL32(r, g, b, a)).
--- @class ImColor
local ImColorMT = {}
ImColorMT.__index = ImColorMT
ImColor = setmetatable({}, { __call = function(_, r, g, b, a)
    local self = setmetatable({ Value = ImVec4() }, ImColorMT)
    if type(r) == "table" then
        ImVec4_Copy(self.Value, r)
    elseif r ~= nil and g == nil then
        local s = 1.0 / 255.0
        self.Value.x = bit32.band(bit32.rshift(r, IM_COL32_R_SHIFT), 0xFF) * s; self.Value.y = bit32.band(bit32.rshift(r, IM_COL32_G_SHIFT), 0xFF) * s
        self.Value.z = bit32.band(bit32.rshift(r, IM_COL32_B_SHIFT), 0xFF) * s; self.Value.w = bit32.band(bit32.rshift(r, IM_COL32_A_SHIFT), 0xFF) * s
    elseif r ~= nil then
        self.Value.x = r; self.Value.y = g; self.Value.z = b; self.Value.w = a or 1.0
    end
    return self
end })
function ImColorMT:U32() return ImGui.ColorConvertFloat4ToU32(self.Value) end
-- FIXME-OBSOLETE: May need to obsolete/cleanup those helpers.
function ImColorMT:SetHSV(h, s, v, a) self.Value.x, self.Value.y, self.Value.z = ImGui.ColorConvertHSVtoRGB(h, s, v); self.Value.w = a or 1.0 end
function ImColor.HSV(h, s, v, a) local r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v); return ImColor(r, g, b, a or 1.0) end

-------------------------------------------------------------------------------
-- [SECTION] Multi-Select API flags and structures (ImGuiMultiSelectFlags, ImGuiSelectionRequestType, ImGuiSelectionRequest, ImGuiMultiSelectIO, ImGuiSelectionBasicStorage)
-------------------------------------------------------------------------------

-- Multi-selection system
-- Documentation at: https://github.com/ocornut/imgui/wiki/Multi-Select
-- - Refer to 'Demo->Widgets->Selection State & Multi-Select' for demos using this.
-- - This system implements standard multi-selection idioms (Ctrl+Mouse/Keyboard, Shift+Mouse/Keyboard, etc)
--   with support for clipper (skipping non-visible items), box-select and many other details.
-- - Selectable(), Checkbox() are supported but custom widgets may use it as well.
-- - TreeNode() is technically supported but... using this correctly is more complicated: you need some sort of linear/random access to your tree,
--   which is suited to advanced trees setups also implementing filters and clipper. We will work toward simplifying and demoing it.
-- - In the spirit of Dear ImGui design, your code owns actual selection data.
--   This is designed to allow all kinds of selection storage you may use in your application e.g. set/map/hash.
-- About ImGuiSelectionBasicStorage:
-- - This is an optional helper to store a selection state and apply selection requests.
-- - It is used by our demos and provided as a convenience to quickly implement multi-selection.
-- Usage:
-- - Identify submitted items with SetNextItemSelectionUserData(), most likely using an index into your current data-set.
-- - Store and maintain actual selection data using persistent object identifiers.
-- - Usage flow:
--     BEGIN - (1) Call BeginMultiSelect() and retrieve the ImGuiMultiSelectIO result.
--           - (2) Honor request list (SetAll/SetRange requests) by updating your selection data. Same code as Step 6.
--           - (3) [If using clipper] You need to make sure RangeSrcItem is always submitted. Calculate its index and pass to clipper:IncludeItemByIndex(). If storing indices in ImGuiSelectionUserData, a simple clipper:IncludeItemByIndex(ms_io.RangeSrcItem) call will work.
--     LOOP  - (4) Submit your items with SetNextItemSelectionUserData() + Selectable()/TreeNode() calls.
--     END   - (5) Call EndMultiSelect() and retrieve the ImGuiMultiSelectIO result.
--           - (6) Honor request list (SetAll/SetRange requests) by updating your selection data. Same code as Step 2.
--     If you submit all items (no clipper), Step 2 and 3 are optional and will be handled by each item themselves. It is fine to always honor those steps.
-- About ImGuiSelectionUserData:
-- - This can store an application-defined identifier (e.g. index or pointer) submitted via SetNextItemSelectionUserData().
-- - In return we store them into RangeSrcItem/RangeFirstItem/RangeLastItem and other fields in ImGuiMultiSelectIO.
-- - Most applications will store an object INDEX, hence the chosen name and type. Storing an index is natural, because
--   SetRange requests will give you two end-points and you will need to iterate/interpolate between them to update your selection.
-- - However it is perfectly possible to store a POINTER or another IDENTIFIER inside ImGuiSelectionUserData.
--   Our system never assume that you identify items by indices, it never attempts to interpolate between two values.
-- - If you enable ImGuiMultiSelectFlags.NoRangeSelect then it is guaranteed that you will never have to interpolate
--   between two ImGuiSelectionUserData, which may be a convenient way to use part of the feature with less code work.
-- - As most users will want to store an index, for convenience and to reduce confusion we use ImS64 instead of void*,
--   being syntactically easier to downcast. Feel free to reinterpret_cast and store a pointer inside.
-- [Port] ImGuiSelectionUserData is any Lua value compared with '==' (an integer index, or e.g. a table reference instead of a pointer).
--        -1 (ImGuiSelectionUserData_Invalid) is reserved. ImGuiSelectionBasicStorage/ImGuiSelectionExternalStorage require integer indices.

-- Flags for BeginMultiSelect()
--- @enum ImGuiMultiSelectFlags
ImGuiMultiSelectFlags = {
    None                  = 0,
    SingleSelect          = bitLShift(1, 0),  -- Disable selecting more than one item. This is available to allow single-selection code to share same code/logic if desired. It essentially disables the main purpose of BeginMultiSelect() tho!
    NoSelectAll           = bitLShift(1, 1),  -- Disable Ctrl+A shortcut to select all.
    NoRangeSelect         = bitLShift(1, 2),  -- Disable Shift+selection mouse/keyboard support (useful for unordered 2D selection). With BoxSelect is also ensure contiguous SetRange requests are not combined into one. This allows not handling interpolation in SetRange requests.
    NoAutoSelect          = bitLShift(1, 3),  -- Disable selecting items when navigating (useful for e.g. supporting range-select in a list of checkboxes).
    NoAutoClear           = bitLShift(1, 4),  -- Disable clearing selection when navigating or selecting another one (generally used with ImGuiMultiSelectFlags.NoAutoSelect. useful for e.g. supporting range-select in a list of checkboxes).
    NoAutoClearOnReselect = bitLShift(1, 5),  -- Disable clearing selection when clicking/selecting an already selected item.
    BoxSelect1d           = bitLShift(1, 6),  -- Enable box-selection with same width and same x pos items (e.g. full row Selectable()). Box-selection works better with little bit of spacing between items hit-box in order to be able to aim at empty space.
    BoxSelect2d           = bitLShift(1, 7),  -- Enable box-selection with varying width or varying x pos items support (e.g. different width labels, or 2D layout/grid). This is slower: alters clipping logic so that e.g. horizontal movements will update selection of normally clipped items.
    BoxSelectNoScroll     = bitLShift(1, 8),  -- Disable scrolling when box-selecting and moving mouse near edges of scope.
    ClearOnEscape         = bitLShift(1, 9),  -- Clear selection when pressing Escape while scope is focused.
    ClearOnClickVoid      = bitLShift(1, 10), -- Clear selection when clicking on empty location within scope.
    ScopeWindow           = bitLShift(1, 11), -- Scope for _BoxSelect and _ClearOnClickVoid is whole window (Default). Use if BeginMultiSelect() covers a whole window or used a single time in same window.
    ScopeRect             = bitLShift(1, 12), -- Scope for _BoxSelect and _ClearOnClickVoid is rectangle encompassing BeginMultiSelect()/EndMultiSelect(). Use if BeginMultiSelect() is called multiple times in same window.
    SelectOnAuto          = bitLShift(1, 13), -- Apply selection on mouse down when clicking on unselected item, on mouse up when clicking on selected item. (Default)
    SelectOnClickAlways   = bitLShift(1, 14), -- Apply selection on mouse down when clicking on any items. Prevents Drag and Drop from being used on multiple-selection, but allows e.g. BoxSelect to always reselect even when clicking inside an existing selection. (Excel style behavior)
    SelectOnClickRelease  = bitLShift(1, 15), -- Apply selection on mouse release when clicking an unselected item. Allow dragging an unselected item without altering selection.
    --RangeSelect2d       = bitLShift(1, 15), -- Shift+Selection uses 2d geometry instead of linear sequence, so possible to use Shift+up/down to select vertically in grid. Analogous to what BoxSelect does.
    NavWrapX              = bitLShift(1, 16), -- [Temporary] Enable navigation wrapping on X axis. Provided as a convenience because we don't have a design for the general Nav API for this yet. When the more general feature be public we may obsolete this flag in favor of new one.
    NoSelectOnRightClick  = bitLShift(1, 17), -- Disable default right-click processing, which selects item on mouse down, and is designed for context-menus.
    CheckboxMode_         = bitLShift(1, 20), -- [Internal]
}
ImGuiMultiSelectFlags.SelectOnMask_ = bit32.bor(ImGuiMultiSelectFlags.SelectOnAuto, ImGuiMultiSelectFlags.SelectOnClickAlways, ImGuiMultiSelectFlags.SelectOnClickRelease)
ImGuiMultiSelectFlags.SelectOnClick = ImGuiMultiSelectFlags.SelectOnAuto -- RENAMED in 1.92.6

-- Main IO structure returned by BeginMultiSelect()/EndMultiSelect().
-- This mainly contains a list of selection requests.
-- - Use 'Demo->Tools->Debug Log->Selection' to see requests as they happen.
-- - Some fields are only useful if your list is dynamic and allows deletion (getting post-deletion focus/state right is shown in the demo)
-- - Below: who reads/writes each fields? 'r'=read, 'w'=write, 'ms'=multi-select code, 'app'=application/user code.
--- @class ImGuiMultiSelectIO
--- @field Requests      ImVector<ImGuiSelectionRequest> #  ms:w, app:r     /  ms:w  app:r   // Requests to apply to your selection data. (1-based .Data)
--- @field RangeSrcItem  ImGuiSelectionUserData          #  ms:w  app:r     /                // (If using clipper) Begin: Source item (often the first selected item) must never be clipped: use clipper:IncludeItemByIndex() to ensure it is submitted.
--- @field NavIdItem     ImGuiSelectionUserData          #  ms:w, app:r     /                // (If using deletion) Last known SetNextItemSelectionUserData() value for NavId (if part of submitted items).
--- @field NavIdSelected bool                            #  ms:w, app:r     /        app:r   // (If using deletion) Last known selection state for NavId (if part of submitted items).
--- @field RangeSrcReset bool                            #        app:w     /  ms:r          // (If using deletion) Set before EndMultiSelect() to reset ResetSrcItem (e.g. if deleted selection).
--- @field ItemsCount    int                             #  ms:w, app:r     /        app:r   // 'int items_count' parameter to BeginMultiSelect() is copied here for convenience, allowing simpler calls to your ApplyRequests handler. Not used internally.

-- Selection request type
--- @enum ImGuiSelectionRequestType
ImGuiSelectionRequestType = {
    None     = 0,
    SetAll   = 1, -- Request app to clear selection (if Selected==false) or select all items (if Selected==true). We cannot set RangeFirstItem/RangeLastItem as its contents is entirely up to user (not necessarily an index)
    SetRange = 2, -- Request app to select/unselect [RangeFirstItem..RangeLastItem] items (inclusive) based on value of Selected. Only EndMultiSelect() request this, app code can read after BeginMultiSelect() and it will always be false.
}

-- Selection request item
--- @class ImGuiSelectionRequest
--- @field Type           ImGuiSelectionRequestType #  ms:w, app:r     /  ms:w, app:r   // Request type. You'll most often receive 1 Clear + 1 SetRange with a single-item range.
--- @field Selected       bool                      #  ms:w, app:r     /  ms:w, app:r   // Parameter for SetAll/SetRange requests (true = select, false = unselect)
--- @field RangeDirection int                       #                  /  ms:w  app:r   // Parameter for SetRange request: +1 when RangeFirstItem comes before RangeLastItem, -1 otherwise. Useful if you want to preserve selection order on a backward Shift+Click.
--- @field RangeFirstItem ImGuiSelectionUserData    #                  /  ms:w, app:r   // Parameter for SetRange request (this is generally == RangeSrcItem when shift selecting from top to bottom).
--- @field RangeLastItem  ImGuiSelectionUserData    #                  /  ms:w, app:r   // Parameter for SetRange request (this is generally == RangeSrcItem when shift selecting from bottom to top). Inclusive!
function ImGuiSelectionRequest()
    return { Type = ImGuiSelectionRequestType.None, Selected = false, RangeDirection = 0, RangeFirstItem = -1, RangeLastItem = -1 }
end
-- [Port] ImVector<ImGuiSelectionRequest> copy function: push_back() copies fields into the preallocated element (C++ copies by value),
-- so callers can push a reused scratch request without allocating.
function ImGuiSelectionRequest_Copy(t, k, v)
    local dst = t[k]
    dst.Type = v.Type; dst.Selected = v.Selected; dst.RangeDirection = v.RangeDirection; dst.RangeFirstItem = v.RangeFirstItem; dst.RangeLastItem = v.RangeLastItem
end

--- @return ImGuiMultiSelectIO
function ImGuiMultiSelectIO()
    return { Requests = ImVector(ImGuiSelectionRequest, ImGuiSelectionRequest_Copy), RangeSrcItem = -1, NavIdItem = -1, NavIdSelected = false, RangeSrcReset = false, ItemsCount = 0 }
end

-- [Port] ImGuiSelectionBasicStorage, ImGuiSelectionExternalStorage: see [SECTION] Widgets: Multi-Select helpers in imgui_widgets.lua
-- (constructors and methods are defined there, like upstream's out-of-line definitions in imgui_widgets.cpp).

--- @class ImGuiSettingsHandler
--- [Port] Fns take (ctx, handler, ...) like upstream. ReadOpenFn(ctx, handler, name) returns entry; ReadLineFn(ctx, handler, entry, line);
--- WriteAllFn(ctx, handler, buf: ImGuiTextBuffer)
function ImGuiSettingsHandler()
    return { TypeName = nil, TypeHash = 0, ClearAllFn = nil, ReadInitFn = nil, ReadOpenFn = nil, ReadLineFn = nil,
             ApplyAllFn = nil, WriteAllFn = nil, CleanupFn = nil, UserData = nil }
end

return true -- [Port] [Roblox] ModuleScripts must return exactly one value
