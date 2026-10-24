--- Dear ImGui
-- [Port] This is a Lua port of original `imstb_truetype.h`

-- [DEAR IMGUI]
-- This is a slightly modified version of stb_truetype.h 1.26.
-- Mostly fixing for compiler and static analyzer warnings.
-- Grep for [DEAR IMGUI] to find the changes.

-- stb_truetype.h - v1.26 - public domain
-- authored from 2009-2021 by Sean Barrett / RAD Game Tools
--
-- =======================================================================
--
--    NO SECURITY GUARANTEE -- DO NOT USE THIS ON UNTRUSTED FONT FILES
--
-- This library does no range checking of the offsets found in the file,
-- meaning an attacker can use it to read arbitrary memory.
--
-- =======================================================================
--
--   This library processes TrueType files:
--        parse files
--        extract glyph metrics
--        extract glyph shapes
--        render glyphs to one-channel bitmaps with antialiasing (box filter)
--
--   Todo:
--        non-MS cmaps
--        crashproof on bad data
--        hinting? (no longer patented)
--        cleartype-style AA?
--        optimize: build edge-list directly from curves
--        optimize: rasterize directly from curves?
--
-- ADDITIONAL CONTRIBUTORS
--
--   Mikko Mononen: compound shape support, more cmap formats
--   Tor Andersson: kerning, subpixel rendering
--   Dougall Johnson: OpenType / Type 2 font handling
--   Daniel Ribeiro Maciel: basic GPOS-based kerning
--
--   Misc other:
--       Ryan Gordon
--       Simon Glass
--       github:IntellectualKitty
--       Imanol Celaya
--       Daniel Ribeiro Maciel
--
--   Bug/warning reports/fixes:
--       "Zer" on mollyrocket       Fabian "ryg" Giesen   github:NiLuJe
--       Cass Everitt               Martins Mozeiko       github:aloucks
--       stoiko (Haemimont Games)   Cap Petschulat        github:oyvindjam
--       Brian Hook                 Omar Cornut           github:vassvik
--       Walter van Niftrik         Ryan Griege
--       David Gow                  Peter LaValle
--       David Given                Sergey Popov
--       Ivan-Assen Ivanov          Giumo X. Clanjor
--       Anthony Pesch              Higor Euripedes
--       Johan Duparc               Thomas Fields
--       Hou Qiming                 Derek Vinyard
--       Rob Loach                  Cort Stratton
--       Kenney Phillis Jr.         Brian Costabile
--       Ken Voskuil (kaesve)
--
-- USAGE
--
--   "Load" a font file from a memory buffer (you have to keep the buffer loaded)
--           stbtt_InitFont()
--           stbtt_GetFontOffsetForIndex()        -- indexing for TTC font collections
--
--   Character advance/positioning
--           stbtt_GetFontVMetrics()
--
--   Starting with version 1.06, the rasterizer was replaced with a new,
--   faster and generally-more-precise rasterizer. The new rasterizer more
--   accurately measures pixel coverage for anti-aliasing, except in the case
--   where multiple shapes overlap, in which case it overestimates the AA pixel
--   coverage. Thus, anti-aliasing of intersecting shapes may look wrong.
-- [Port] (This port only implements the new rasterizer.)
--
-- ADDITIONAL DOCUMENTATION
--
--   Some important concepts to understand to use this library:
--
--      Codepoint
--         Characters are defined by unicode codepoints, e.g. 65 is
--         uppercase A, 231 is lowercase c with a cedilla, 0x7e30 is
--         the hiragana for "ma".
--
--      Glyph
--         A visual character shape (every codepoint is rendered as
--         some glyph)
--
--      Glyph index
--         A font-specific integer ID representing a glyph
--
--      Baseline
--         Glyph shapes are defined relative to a baseline, which is the
--         bottom of uppercase characters. Characters extend both above
--         and below the baseline.
--
--      Current Point
--         As you draw text to the screen, you keep track of a "current point"
--         which is the origin of each character. The current point's vertical
--         position is the baseline. Even "baked fonts" use this model.
--
--      Vertical Font Metrics
--         The vertical qualities of the font, used to vertically position
--         and space the characters. See docs for stbtt_GetFontVMetrics.
--
--      Font Size in Pixels or Points
--         The preferred interface for specifying font sizes in stb_truetype
--         is to specify how tall the font's vertical extent should be in pixels.
--
-- DETAILED USAGE:
--
--  Scale:
--    Select how high you want the font to be, in pixels.
--    Call ScaleForPixelHeight to compute a scale factor SF that will be
--    used by all other functions.
--
--  Current point:
--    Set the current point where the first character will appear. The
--    first character could extend left of the current point; this is font
--    dependent. You can either choose a current point that is the leftmost
--    point and hope, or add some padding, or check the bounding box or
--    left-side-bearing of the first character to be displayed and set
--    the current point based on that.
--
--  Displaying a character:
--    Compute the bounding box of the character. It will contain signed values
--    relative to <current_point, baseline>. I.e. if it returns x0,y0,x1,y1,
--    then the character should be displayed in the rectangle from
--    <current_point+SF*x0, baseline+SF*y0> to <current_point+SF*x1,baseline+SF*y1).
--
--  Advancing for the next character:
--    Call GlyphHMetrics, and compute 'current_point += SF * advance'.
--
--
-- ADVANCED USAGE
--
--   Quality:
--
--    - Use the functions with Subpixel at the end to allow your characters
--      to have subpixel positioning. Since the font is anti-aliased, not
--      hinted, this is very import for quality. (This is not possible with
--      baked fonts.)
--
--   Performance:
--
--    - Convert Unicode codepoints to glyph indexes and operate on the glyphs;
--      if you don't do this, stb_truetype is forced to do the conversion on
--      every call.
--
-- NOTES
--
--   The system uses the raw data found in the .ttf file without changing it
--   and without building auxiliary data structures. This is a bit inefficient
--   on little-endian systems (the data is big-endian), but assuming you're
--   caching the bitmaps or glyph shapes this shouldn't be a big deal.

--- STBTT_RASTERIZER_VERSION == 2

local stbtt_fontinfo

local stbtt_InitFont
local stbtt_MakeGlyphBitmapSubpixelPrefilter
local stbtt_GetFontVMetrics
local stbtt__GetGlyphInfoT2
local stbtt__GetGlyphShapeT2
local stbtt_GetGlyphShape, stbtt_GetGlyphShapeUncached
local stbtt_GetGlyphBitmapBox
local stbtt_GetGlyphBitmapBoxSubpixel
local stbtt_GetGlyphHMetrics
local stbtt_GetFontOffsetForIndex
local stbtt_ScaleForPixelHeight
local stbtt_FindGlyphIndex

local STBTT_MAX_OVERSAMPLE = 8

--- @enum STBTT_PLATFORM_ID
local STBTT_PLATFORM_ID = { -- platformID
    UNICODE   = 0,
    MAC       = 1,
    ISO       = 2,
    MICROSOFT = 3,
}

--- @enum STBTT_MS_EID
local STBTT_MS_EID = { -- encodingID for STBTT_PLATFORM_ID_MICROSOFT
    SYMBOL       = 0,
    UNICODE_BMP  = 1,
    SHIFTJIS     = 2,
    UNICODE_FULL = 10
}

-- [Port] original enum doesn't have a name, so we name it
--- @enum STBTT_VTX
local STBTT_VTX = {
    MOVE = 1,
    LINE = 2,
    CURVE = 3,
    CUBIC = 4
}

local bit32 = bit32
local math = math

local STBTT_assert = assert
local STBTT_sort = table.sort
local STBTT_sqrt = math.sqrt
local STBTT_fabs = math.abs
local STBTT_ifloor = math.floor
local STBTT_iceil = math.ceil

@native
local function trunc(x)
    if x >= 0 then
        return math.floor(x)
    else
        return math.ceil(x)
    end
end

@native
local function STBTT__NOTUSED(_) return end

--- @alias stbtt_int32 int

local stbtt_int32   = ImS32
local stbtt_uint32  = ImU32
local stbtt_int16   = ImS16
local stbtt_uint16  = ImU16
local stbtt_int8    = ImS8
local stbtt_uint8   = ImU8
local unsigned_char = stbtt_uint8

-- private structure
--- @class stbtt__buf
--- @field data?  table # 1-based byte table
--- @field offset int   # Every access to `data` will be offset by this
--- @field cursor int   # >= 0
--- @field size   int

--- @param initial_offset? int
--- @return stbtt__buf
--- @nodiscard
@native
local function stbtt__buf(initial_offset)
    return {
        data   = nil,
        offset = initial_offset or 0,
        cursor = 0,
        size   = nil
    }
end

-- The following structure is defined publicly so you can declare one on
-- the stack or as a global or etc, but you should treat it as opaque.
--- @class stbtt_fontinfo
--- @field userdata         any
--- @field data             table       # pointer to .ttf file
--- @field fontstart        int         # offset of start of font
--- @field numGlyphs        int         # number of glyphs, needed for range checking
--- @field loca             int         # table location as offset from start of .ttf
--- @field head             int         # table location as offset from start of .ttf
--- @field glyf             int         # table location as offset from start of .ttf
--- @field hhea             int         # table location as offset from start of .ttf
--- @field hmtx             int         # table location as offset from start of .ttf
--- @field kern             int         # table location as offset from start of .ttf
--- @field gpos             int         # table location as offset from start of .ttf
--- @field svg              int         # table location as offset from start of .ttf
--- @field index_map        int         # a cmap mapping for our chosen character encoding
--- @field indexToLocFormat int         # format needed to map from glyph index to glyph
--- @field cff              stbtt__buf  # cff font data
--- @field charstrings      stbtt__buf  # the charstring index
--- @field gsubrs           stbtt__buf  # global charstring subroutines index
--- @field subrs            stbtt__buf  # private charstring subroutines index
--- @field fontdicts        stbtt__buf  # array of font dicts
--- @field fdselect         stbtt__buf  # map from glyph to fontdict

--- @return stbtt_fontinfo
@native
function stbtt_fontinfo()
    return {
        data      = nil,
        fontstart = nil,

        numGlyphs = nil,

        loca = nil,
        head = nil,
        glyf = nil,
        hhea = nil,
        hmtx = nil,
        kern = nil,
        gpos = nil,
        svg  = nil,

        index_map        = nil,
        indexToLocFormat = nil,

        cff         = nil,
        charstrings = nil,
        gsubrs      = nil,
        subrs       = nil,
        fontdicts   = nil,
        fdselect    = nil
    }
end

--- @class stbtt_vertex
--- @field x       int
--- @field y       int
--- @field cx      int
--- @field cy      int
--- @field cx1     int
--- @field cy1     int
--- @field type    int
--- @field padding int

--- @return stbtt_vertex
--- @nodiscard
@native
local function stbtt_vertex()
    return {
        x       = nil,
        y       = nil,
        cx      = nil,
        cy      = nil,
        cx1     = nil,
        cy1     = nil,
        type    = nil,
        padding = nil
    }
end

--- @class stbtt__csctx
--- @field bounds       bool
--- @field started      bool
--- @field first_x      float
--- @field first_y      float
--- @field x            float
--- @field y            float
--- @field min_x        int
--- @field max_x        int
--- @field min_y        int
--- @field max_y        int
--- @field pvertices    stbtt_vertex[]
--- @field num_vertices int

--- @return stbtt__csctx
--- @nodiscard
@native
local function stbtt__csctx()
    return {
        bounds  = false,
        started = false,
        first_x = nil,
        first_y = nil,
        x       = nil,
        y       = nil,
        min_x   = nil,
        max_x   = nil,
        min_y   = nil,
        max_y   = nil,

        pvertices    = nil,
        num_vertices = nil
    }
end

--- @param bounds bool
--- @return stbtt__csctx
--- @nodiscard
local function STBTT__CSCTX_INIT(bounds)
    local this = stbtt__csctx()

    this.bounds  = bounds
    this.started = false
    this.first_x = 0
    this.first_y = 0
    this.x       = 0
    this.y       = 0
    this.min_x   = 0
    this.max_x   = 0
    this.min_y   = 0
    this.max_y   = 0

    this.pvertices = nil
    this.num_vertices = 0

    return this
end

--- stbtt_kerningentry
--- stbtt_pack_range
--- stbtt_packedchar

--- @class stbtt__edge
--- @field x0     float
--- @field y0     float
--- @field x1     float
--- @field y1     float
--- @field invert bool

--- @return stbtt__edge
--- @nodiscard
@native
local function stbtt__edge()
    return {
        x0 = nil,
        y0 = nil,
        x1 = nil,
        y1 = nil,
        invert = false
    }
end

--- @class stbtt__active_edge

--- @return stbtt__active_edge
--- @nodiscard
@native
local function stbtt__active_edge()
    return {
        next = nil,
        fx = nil,
        fdx = nil,
        fdy = nil,
        direction = nil,
        sy = nil,
        ey = nil
    }
end

--- @return stbtt__active_edge
--- @nodiscard
local active_pool, active_pool_n = {}, 0 -- [Luau] reused per stbtt__rasterize_sorted_edges() call (C: stbtt__hheap)
@native
local function stbtt__new_active(e, off_x, start_point)
    active_pool_n = active_pool_n + 1
    local z = active_pool[active_pool_n]
    if z == nil then
        z = stbtt__active_edge()
        active_pool[active_pool_n] = z
    end
    local dxdy = (e.x1 - e.x0) / (e.y1 - e.y0)

    z.fdx = dxdy
    z.fdy = (dxdy ~= 0.0) and (1.0 / dxdy) or 0.0
    z.fx = e.x0 + dxdy * (start_point - e.y0)
    z.fx = z.fx - off_x
    z.direction = (e.invert) and 1.0 or -1.0
    z.sy = e.y0
    z.ey = e.y1
    z.next = nil

    return z
end

-- @TODO: don't expose this structure
--- @class stbtt__bitmap
--- @field w      int
--- @field h      int
--- @field stride int
--- @field pixels unsigned_char[]

--- @return stbtt__bitmap
--- @nodiscard
@native
local function stbtt__bitmap()
    return {
        w      = nil,
        h      = nil,
        stride = nil,
        pixels = nil
    }
end

--- @class stbtt__point
--- @field x number
--- @field y number

--- @return stbtt__point
--- @nodiscard
@native
local function stbtt__point() return { x = nil, y = nil } end

----------------------------------------------
----------------------------------------------
---
--- stbtt__buf helpers to parse data from file
---
---

--- @param b stbtt__buf
@native
local function stbtt__buf_get8(b)
    if b.cursor >= b.size then return 0 end
    local result = b.data[b.offset + b.cursor + 1]
    b.cursor = b.cursor + 1
    return result
end

--- @param b stbtt__buf
@native
local function stbtt__buf_peek8(b)
    if b.cursor >= b.size then return 0 end
    return b.data[b.offset + b.cursor + 1]
end

--- @param b stbtt__buf
--- @param o int
@native
local function stbtt__buf_seek(b, o)
    STBTT_assert(not (o > b.size or o < 0))
    if o > b.size or o < 0 then
        b.cursor = b.size
    else
        b.cursor = o
    end
end

--- @param b stbtt__buf
--- @param o int
@native
local function stbtt__buf_skip(b, o)
    stbtt__buf_seek(b, b.cursor + o)
end

@native
local function stbtt__buf_get(b, n)
    local v = 0
    STBTT_assert(n >= 1 and n <= 4)
    for _ = 1, n do
        v = bit32.bor(bit32.lshift(v, 8), stbtt__buf_get8(b))
    end
    return v
end

--- @param p?      table
--- @param size    int
--- @param offset? int
--- @return stbtt__buf
--- @nodiscard
@native
local function stbtt__new_buf(p, size, offset)
    local r = stbtt__buf(offset)
    STBTT_assert(size < 0x40000000)
    r.data = p
    r.size = trunc(size)
    r.cursor = 0
    return r
end

--- @param b stbtt__buf
@native
local function stbtt__buf_get16(b) return stbtt__buf_get(b, 2) end
--- @param b stbtt__buf
@native
local function stbtt__buf_get32(b) return stbtt__buf_get(b, 4) end

--- @param b stbtt__buf
--- @param o int
--- @param s int
--- @return stbtt__buf
--- @nodiscard
@native
local function stbtt__buf_range(b, o, s)
    local r = stbtt__new_buf(nil, 0)
    if (o < 0 or s < 0 or o > b.size or s > (b.size - o)) then
        return r
    end
    r.data = b.data
    r.offset = b.offset + o
    r.size = s
    return r
end

--- @param b stbtt__buf
local function stbtt__cff_get_index(b)
    local count, start, offsize
    start = b.cursor
    count = stbtt__buf_get16(b)
    if count > 0 then
        offsize = stbtt__buf_get8(b)
        STBTT_assert(offsize >= 1 and offsize <= 4)
        stbtt__buf_skip(b, count * offsize)
        stbtt__buf_skip(b, stbtt__buf_get(b, offsize) - 1)
    end
    return stbtt__buf_range(b, start, b.cursor - start)
end

--- @param b stbtt__buf
local function stbtt__cff_int(b)
    local b0 = stbtt__buf_get8(b)
    if b0 >= 32 and b0 <= 246 then return b0 - 139
    elseif b0 >= 247 and b0 <= 250 then return (b0 - 247) * 256 + stbtt__buf_get8(b) + 108
    elseif b0 >= 251 and b0 <= 254 then return -(b0 - 251) * 256 - stbtt__buf_get8(b) - 108
    elseif b0 == 28 then return stbtt__buf_get16(b)
    elseif b0 == 29 then return stbtt__buf_get32(b)
    end
    STBTT_assert(false)
    return 0
end

--- @param b stbtt__buf
local function stbtt__cff_skip_operand(b)
    local v
    local b0 = stbtt__buf_peek8(b)
    STBTT_assert(b0 >= 28)
    if b0 == 30 then
        stbtt__buf_skip(b, 1)
        while b.cursor < b.size do
            v = stbtt__buf_get8(b)
            if (bit32.band(v, 0xF) == 0xF or bit32.rshift(v, 4) == 0xF) then
                break
            end
        end
    else
        stbtt__cff_int(b)
    end
end

--- @param b stbtt__buf
--- @param key int
--- @return stbtt__buf
--- @nodiscard
local function stbtt__dict_get(b, key)
    stbtt__buf_seek(b, 0)
    while b.cursor < b.size do
        local start = b.cursor
        local _end, op
        while stbtt__buf_peek8(b) >= 28 do
            stbtt__cff_skip_operand(b)
        end
        _end = b.cursor
        op = stbtt__buf_get8(b)
        if op == 12 then op = bit32.bor(stbtt__buf_get8(b), 0x100) end
        if op == key then return stbtt__buf_range(b, start, _end - start) end
    end
    return stbtt__buf_range(b, 0, 0)
end

--- @param b        stbtt__buf
--- @param key      int
--- @param outcount int
--- @return int[]
--- @nodiscard
local function stbtt__dict_get_ints(b, key, outcount)
    local operands = stbtt__dict_get(b, key)
    local out = {}
    for i = 1, outcount do
        if operands.cursor >= operands.size then break end
        out[i] = stbtt__cff_int(operands)
    end
    return out
end

--- @param b stbtt__buf
local function stbtt__cff_index_count(b)
    stbtt__buf_seek(b, 0)
    return stbtt__buf_get16(b)
end

--- @param b stbtt__buf
--- @param i int
--- @return stbtt__buf
--- @nodiscard
local function stbtt__cff_index_get(b, i)
    local count, offsize, start, _end
    stbtt__buf_seek(b, 0)
    count = stbtt__buf_get16(b)
    offsize = stbtt__buf_get8(b)
    STBTT_assert(i >= 0 and i < count)
    STBTT_assert(offsize >= 1 and offsize <= 4)
    stbtt__buf_skip(b, i * offsize)
    start = stbtt__buf_get(b, offsize)
    _end = stbtt__buf_get(b, offsize)
    return stbtt__buf_range(b, 2 + (count + 1) * offsize + start, _end - start)
end

-------------------------------------
-------------------------------------
---
--- accessors to parse data from file
---
---

--- UNIMPLEMENTED / UNUSED:
---     stbtt_IsGlyphEmpty
---     stbtt_GetKerningTableLength
---     stbtt_GetKerningTable
---     stbtt__GetGlyphKernInfoAdvance
---     stbtt__GetCoverageIndex
---     stbtt__GetGlyphClass
---     stbtt__GetGlyphGPOSInfoAdvance
---     stbtt_GetGlyphKernAdvance
---     stbtt_FindSVGDoc
---     stbtt_GetGlyphSVG
---     stbtt_GetCodepointSVG
---     stbtt_GetCodepointKernAdvance
---     stbtt_GetFontVMetricsOS2
---     stbtt_GetCodepointHMetrics
---     stbtt_ScaleForMappingEmToPixels
---     stbtt_GetFontBoundingBox
---     stbtt_GetCodepointBitmapBox
---     stbtt_GetCodepointBitmapBoxSubpixel
---     stbtt_GetCodepointBox
---     stbtt_GetNumberOfFonts_internal
---     stbtt__get_svg

@native
local function ttUSHORT(p, offset) return stbtt_uint16(p[offset + 1] * 256 + p[offset + 2]) end
@native
local function ttSHORT(p, offset)  return stbtt_int16(p[offset + 1] * 256 + p[offset + 2]) end
@native
local function ttULONG(p, offset)  return stbtt_uint32(bit32.lshift(p[offset + 1], 24) + bit32.lshift(p[offset + 2], 16) + bit32.lshift(p[offset + 3], 8) + p[offset + 4]) end
@native
local function ttLONG(p, offset)   return stbtt_int32(bit32.lshift(p[offset + 1], 24) + bit32.lshift(p[offset + 2], 16) + bit32.lshift(p[offset + 3], 8) + p[offset + 4]) end

@native
local function ttBYTE(p, offset) return stbtt_uint8(p[offset + 1]) end
@native
local function ttCHAR(p, offset) return stbtt_int8(p[offset + 1]) end

@native
local function stbtt_tag4(p, c0, c1, c2, c3, offset) offset = offset or 0; return p[offset + 1] == c0 and p[offset + 2] == c1 and p[offset + 3] == c2 and p[offset + 4] == c3 end
@native
local function stbtt_tag(p, str, offset) local c0, c1, c2, c3 = string.byte(str, 1, 4); return stbtt_tag4(p, c0, c1, c2, c3, offset) end

local function stbtt__isfont(font)
    -- check the version number
    if stbtt_tag4(font, 49, 0, 0, 0) then return true end -- TrueType 1
    if stbtt_tag(font, "typ1") then return true end -- TrueType with type 1 font -- we don't support this!
    if stbtt_tag(font, "OTTO") then return true end -- OpenType with CFF
    if stbtt_tag4(font, 0, 1, 0, 0) then return true end -- OpenType 1.0
    if stbtt_tag(font, "true") then return true end -- Apple specification for TrueType fonts
    return false
end

-- @OPTIMIZE: binary search
local function stbtt__find_table(data, font_start, tag)
    local num_tables = ttUSHORT(data, font_start + 4)
    local tabledir = font_start + 12
    for i = 0, num_tables - 1 do
        local loc = tabledir + i * 16
        if stbtt_tag(data, tag, loc + 0) then
            return ttULONG(data, loc + 8)
        end
    end
    return 0
end

local function stbtt_GetFontOffsetForIndex_internal(font_collection, index)
    -- if it's just a font, there's only one valid index
    if stbtt__isfont(font_collection) then
        if index == 0 then return 0 else return -1 end
    end

    -- check if it's a TTC
    if stbtt_tag(font_collection, "ttcf") then
        -- version 1?
        if ttULONG(font_collection, 4) == 0x00010000 or ttULONG(font_collection, 4) == 0x00020000 then
            local n = ttLONG(font_collection, 8)
            if index >= n then
                return -1
            end
            return ttULONG(font_collection, 12 + index * 4)
        end
    end

    return -1
end

--- @param cff      stbtt__buf
--- @param fontdict stbtt__buf
local function stbtt__get_subrs(cff, fontdict)
    local private_loc = stbtt__dict_get_ints(fontdict, 18, 2)
    if (private_loc[2] == 0 or private_loc[1] == 0) then
        return stbtt__new_buf(nil, 0)
    end
    local pdict = stbtt__buf_range(cff, private_loc[2], private_loc[1])
    local subrsoff = stbtt__dict_get_ints(pdict, 19, 1)
    if subrsoff[1] == 0 then
        return stbtt__new_buf(nil, 0)
    end
    stbtt__buf_seek(cff, private_loc[2] + subrsoff[1])
    return stbtt__cff_get_index(cff)
end

--- @return bool
local function stbtt_InitFont_internal(info, data, fontstart)
    local cmap
    local numTables

    info.data = data
    info.fontstart = fontstart
    info.cff = stbtt__new_buf(nil, 0)

    cmap = stbtt__find_table(data, fontstart, "cmap")      -- required
    info.loca = stbtt__find_table(data, fontstart, "loca") -- required
    info.head = stbtt__find_table(data, fontstart, "head") -- required
    info.glyf = stbtt__find_table(data, fontstart, "glyf") -- required
    info.hhea = stbtt__find_table(data, fontstart, "hhea") -- required
    info.hmtx = stbtt__find_table(data, fontstart, "hmtx") -- required
    info.kern = stbtt__find_table(data, fontstart, "kern") -- not required
    info.gpos = stbtt__find_table(data, fontstart, "GPOS") -- not required

    if (cmap == 0 or info.head == 0 or info.hhea == 0 or info.hmtx == 0) then
        return false
    end
    if info.glyf ~= 0 then
        -- required for truetype
        if info.loca == 0 then
            return false
        end
    else
        -- initialization for CFF / Type2 fonts (OTF)
        local cff = stbtt__find_table(data, fontstart, "CFF ")
        if cff == 0 then
            return false
        end

        info.fontdicts = stbtt__new_buf(nil, 0)
        info.fdselect = stbtt__new_buf(nil, 0)

        -- @TODO this should use size from table (not 512MB)
        info.cff = stbtt__new_buf(data, 64 * 1024 * 1024, cff) -- [Port] 64MB here instead of 512MB
        local b = info.cff

        -- read the header
        stbtt__buf_skip(b, 2)
        stbtt__buf_seek(b, stbtt__buf_get8(b)) -- hdrsize

        -- @TODO the name INDEX could list multiple fonts,
        -- but we just use the first one.
        stbtt__cff_get_index(b) -- name INDEX
        local topdictidx = stbtt__cff_get_index(b)
        local topdict = stbtt__cff_index_get(topdictidx, 0)
        stbtt__cff_get_index(b) -- string INDEX
        info.gsubrs = stbtt__cff_get_index(b)

        local charstrings = stbtt__dict_get_ints(topdict, 17, 1)
        local cstype      = stbtt__dict_get_ints(topdict, bit32.bor(0x100, 6), 1)
        local fdarrayoff  = stbtt__dict_get_ints(topdict, bit32.bor(0x100, 36), 1)
        local fdselectoff = stbtt__dict_get_ints(topdict, bit32.bor(0x100, 37), 1)
        info.subrs = stbtt__get_subrs(b, topdict)

        -- we only support Type 2 charstrings
        if cstype[1] ~= 2 then
            return false
        end
        if charstrings[1] == 0 then
            return false
        end

        if fdarrayoff[1] ~= 0 then
            -- looks like a CID font
            if fdselectoff[1] == 0 then
                return false
            end

            stbtt__buf_seek(b, fdarrayoff[1])
            info.fontdicts = stbtt__cff_get_index(b)
            info.fdselect = stbtt__buf_range(b, fdselectoff[1], b.size - fdselectoff[1])
        end

        stbtt__buf_seek(b, charstrings[1])
        info.charstrings = stbtt__cff_get_index(b)
    end

    local t = stbtt__find_table(data, fontstart, "maxp")
    if t ~= 0 then
        info.numGlyphs = ttUSHORT(data, t + 4)
    else
        info.numGlyphs = 0xffff
    end

    info.svg = -1

    -- find a cmap encoding table we understand *now* to avoid searching
    -- later. (todo: could make this installable)
    -- the same regardless of glyph.
    numTables = ttUSHORT(data, cmap + 2)
    info.index_map = 0
    for i = 0, numTables - 1 do
        local encoding_record = cmap + 4 + 8 * i
        -- find an encoding we understand:
        local platform_id = ttUSHORT(data, encoding_record)

        if platform_id == STBTT_PLATFORM_ID.MICROSOFT then
            local ms_eid = ttUSHORT(data, encoding_record + 2)

            if ms_eid == STBTT_MS_EID.UNICODE_BMP or ms_eid == STBTT_MS_EID.UNICODE_FULL then
                -- MS/Unicode
                info.index_map = cmap + ttULONG(data, encoding_record + 4)
            end
        elseif platform_id == STBTT_PLATFORM_ID.UNICODE then
            -- Mac/iOS has these
            -- all the encodingIDs are unicode, so we don't bother to check it
            info.index_map = cmap + ttULONG(data, encoding_record + 4)
        end
    end
    if info.index_map == 0 then
        return false
    end

    info.indexToLocFormat = ttUSHORT(data, info.head + 50)
    return true
end

-- If you're going to perform multiple operations on the same character
-- and you want a speed-up, call this function with the character you're
-- going to process, then use glyph-based functions instead of the
-- codepoint-based functions.
-- Returns 0 if the character codepoint is not defined in the font.
--- @param info              stbtt_fontinfo
--- @param unicode_codepoint int
@native
function stbtt_FindGlyphIndex(info, unicode_codepoint)
    local data = info.data
    local index_map = info.index_map

    local format = ttUSHORT(data, index_map + 0)
    if format == 0 then -- apple byte encoding
        local bytes = ttUSHORT(data, index_map + 2)
        if unicode_codepoint < bytes - 6 then
            return ttBYTE(data, index_map + 6 + unicode_codepoint)
        end
        return 0
    elseif format == 6 then
        local first = ttUSHORT(data, index_map + 6)
        local count = ttUSHORT(data, index_map + 8)
        if unicode_codepoint >= first and unicode_codepoint < first + count then
            return ttUSHORT(data, index_map + 10 + (unicode_codepoint - first) * 2)
        end
        return 0
    elseif format == 2 then
        STBTT_assert(false) -- @TODO: high-byte mapping for japanese/chinese/korean
        return 0
    elseif format == 4 then -- standard mapping for windows fonts: binary search collection of ranges
        local segcount = bit32.rshift(ttUSHORT(data, index_map + 6), 1)
        local searchRange = bit32.rshift(ttUSHORT(data, index_map + 8), 1)
        local entrySelector = ttUSHORT(data, index_map + 10)
        local rangeShift = bit32.rshift(ttUSHORT(data, index_map + 12), 1)

        -- do a binary search of the segments
        local endCount = index_map + 14
        local search = endCount

        if unicode_codepoint > 0xffff then
            return 0
        end

        -- they lie from endCount .. endCount + segCount
        -- but searchRange is the nearest power of two, so...
        if unicode_codepoint >= ttUSHORT(data, search + rangeShift * 2) then
            search = search + rangeShift * 2
        end

        -- now decrement to bias correctly to find smallest
        search = search - 2
        while entrySelector ~= 0 do
            searchRange = bit32.rshift(searchRange, 1)
            local _end = ttUSHORT(data, search + searchRange * 2)
            if unicode_codepoint > _end then
                search = search + searchRange * 2
            end
            entrySelector = entrySelector - 1
        end
        search = search + 2

        do
            local item = stbtt_uint16(bit32.rshift(search - endCount, 1))

            local start = ttUSHORT(data, index_map + 14 + segcount * 2 + 2 + 2 * item)
            local last = ttUSHORT(data, endCount + 2 * item)
            if unicode_codepoint < start or unicode_codepoint > last then
                return 0
            end

            local offset = ttUSHORT(data, index_map + 14 + segcount * 6 + 2 + 2 * item)
            if offset == 0 then
                return stbtt_uint16(unicode_codepoint + ttSHORT(data, index_map + 14 + segcount * 4 + 2 + 2 * item))
            end

            return ttUSHORT(data, offset + (unicode_codepoint - start) * 2 + index_map + 14 + segcount * 6 + 2 + 2 * item)
        end
    elseif format == 12 or format == 13 then
        local ngroups = ttULONG(data, index_map + 12)
        local low = 0
        local high = ngroups
        -- Binary search the right group.
        while low < high do
            local mid = low + bit32.rshift(high - low, 1) -- rounds down, so low <= mid < high
            local start_char = ttULONG(data, index_map + 16 + mid * 12)
            local end_char = ttULONG(data, index_map + 16 + mid * 12 + 4)
            if unicode_codepoint < start_char then
                high = mid
            elseif unicode_codepoint > end_char then
                low = mid + 1
            else
                local start_glyph = ttULONG(data, index_map + 16 + mid * 12 + 8)
                if format == 12 then
                    return start_glyph + unicode_codepoint - start_char
                else -- format == 13
                    return start_glyph
                end
            end
        end
        return 0 -- not found
    end

    -- @TODO
    STBTT_assert(false)
    return 0
end

--- @param v        stbtt_vertex
--- @param vtx_type STBTT_VTX
--- @param x        stbtt_int32
--- @param y        stbtt_int32
--- @param cx       stbtt_int32
--- @param cy       stbtt_int32
@native
local function stbtt_setvertex(v, vtx_type, x, y, cx, cy)
    v.type = vtx_type
    v.x = (stbtt_int16)(x)
    v.y = (stbtt_int16)(y)
    v.cx = (stbtt_int16)(cx)
    v.cy = (stbtt_int16)(cy)
end

@native
local function stbtt__GetGlyfOffset(info, glyph_index)
    STBTT_assert(info.cff.size == 0)

    if glyph_index >= info.numGlyphs then return -1 end -- glyph index out of range
    if info.indexToLocFormat >= 2 then return -1 end -- unknown index->glyph map format

    local g1, g2
    if info.indexToLocFormat == 0 then
        g1 = info.glyf + ttUSHORT(info.data, info.loca + glyph_index * 2) * 2
        g2 = info.glyf + ttUSHORT(info.data, info.loca + glyph_index * 2 + 2) * 2
    else
        g1 = info.glyf + ttULONG(info.data, info.loca + glyph_index * 4)
        g2 = info.glyf + ttULONG(info.data, info.loca + glyph_index * 4 + 4)
    end

    if g1 == g2 then return -1 else return g1 end -- if length is 0, return -1
end

-- Gets the bounding box of the visible part of the glyph, in unscaled coordinates
--- @return integer, integer?, integer?, integer?, integer?
@native
local function stbtt_GetGlyphBox(info, glyph_index)
    local n, x0, y0, x1, y1

    if info.cff.size ~= 0 then
        n, x0, y0, x1, y1 = stbtt__GetGlyphInfoT2(info, glyph_index)
    else
        local g = stbtt__GetGlyfOffset(info, glyph_index)
        if g < 0 then return 0 end

        x0 = ttSHORT(info.data, g + 2)
        y0 = ttSHORT(info.data, g + 4)
        x1 = ttSHORT(info.data, g + 6)
        y1 = ttSHORT(info.data, g + 8)
    end

    return 1, x0, y0, x1, y1
end

--- @param vertices     stbtt_vertex[]
--- @param num_vertices int
--- @param was_off      bool
--- @param start_off    bool
--- @param sx           stbtt_int32
--- @param sy           stbtt_int32
--- @param scx          stbtt_int32
--- @param scy          stbtt_int32
--- @param cx           stbtt_int32
--- @param cy           stbtt_int32
@native
local function stbtt__close_shape(vertices, num_vertices, was_off, start_off, sx, sy, scx, scy, cx, cy)
    if start_off then
        if was_off then
            stbtt_setvertex(vertices[num_vertices + 1], STBTT_VTX.CURVE, bit32.rshift(cx + scx, 1), bit32.rshift(cy + scy, 1), cx, cy)
            num_vertices = num_vertices + 1
        end
        stbtt_setvertex(vertices[num_vertices + 1], STBTT_VTX.CURVE, sx, sy, scx, scy)
        num_vertices = num_vertices + 1
    else
        if was_off then
            stbtt_setvertex(vertices[num_vertices + 1], STBTT_VTX.CURVE, sx, sy, cx, cy)
            num_vertices = num_vertices + 1
        else
            stbtt_setvertex(vertices[num_vertices + 1], STBTT_VTX.LINE, sx, sy, 0, 0)
            num_vertices = num_vertices + 1
        end
    end
    return num_vertices
end

--- @param info        stbtt_fontinfo
--- @param glyph_index int
--- @return int             num_vertices
--- @return stbtt_vertex[]? vertices
@native
local function stbtt__GetGlyphShapeTT(info, glyph_index)
    local data = info.data
    local num_vertices

    local vertices = nil

    local g = stbtt__GetGlyfOffset(info, glyph_index)

    if g < 0 then return 0 end

    local numberOfContours = ttSHORT(data, g)

    if numberOfContours > 0 then
        local endPtsOfContours = g + 10
        local ins = ttUSHORT(data, endPtsOfContours + numberOfContours * 2)
        local points = (endPtsOfContours + numberOfContours * 2 + 2 + ins) + 1 -- [Port] 1-based idx

        local n = 1 + ttUSHORT(data, endPtsOfContours + numberOfContours * 2 - 2)
        local m = n + 2 * numberOfContours -- a loose bound on how many vertices we might need

        vertices = {}
        for i = 1, m do vertices[i] = stbtt_vertex() end

        local j = 0
        local was_off = false
        local start_off = false
        local next_move = 0
        local flagcount = 0

        -- in first pass, we load uninterpreted data into the allocated array
        -- above, shifted to the end of the array so we won't overwrite it when
        -- we create our final data starting from the front

        local off = m - n -- starting offset for uninterpreted data, regardless of how m ends up being calculated

        -- first load flags
        local flags = 0
        for i = 1, n do
            if flagcount == 0 then
                flags = data[points]
                points = points + 1

                if bit32.band(flags, 8) ~= 0 then
                    flagcount = data[points]
                    points = points + 1
                end
            else
                flagcount = flagcount - 1
            end

            vertices[off + i].type = flags
        end

        -- now load x coordinates
        local x = 0
        for i = 1, n do
            flags = vertices[off + i].type
            if bit32.band(flags, 2) ~= 0 then
                local dx = data[points]
                points = points + 1
                if bit32.band(flags, 16) ~= 0 then -- ???
                    x = x + dx
                else
                    x = x - dx
                end
            else
                if bit32.band(flags, 16) == 0 then
                    x = x + stbtt_int16(data[points] * 256 + data[points + 1])
                    points = points + 2
                end
            end

            vertices[off + i].x = stbtt_int16(x)
        end

        -- now load y coordinates
        local y = 0
        for i = 1, n do
            flags = vertices[off + i].type
            if bit32.band(flags, 4) ~= 0 then
                local dy = data[points]
                points = points + 1
                if bit32.band(flags, 32) ~= 0 then -- ???
                    y = y + dy
                else
                    y = y - dy
                end
            else
                if bit32.band(flags, 32) == 0 then
                    y = y + stbtt_int16(data[points] * 256 + data[points + 1])
                    points = points + 2
                end
            end

            vertices[off + i].y = stbtt_int16(y)
        end

        -- now convert them to our format
        num_vertices = 0
        local sx, sy, cx, cy, scx, scy = 0, 0, 0, 0, 0, 0
        for i = 1, n do
            flags = vertices[off + i].type
            x = stbtt_int16(vertices[off + i].x)
            y = stbtt_int16(vertices[off + i].y)

            if next_move == i - 1 then
                if i ~= 1 then
                    num_vertices = stbtt__close_shape(vertices, num_vertices, was_off, start_off, sx, sy, scx, scy, cx, cy)
                end

                -- now start the new one
                start_off = (bit32.band(flags, 1) == 0)
                if start_off then
                    -- if we start off with an off-curve point, then when we need to find a point on the curve
                    -- where we can start, and we need to save some state for when we wraparound.
                    scx = x
                    scy = y
                    if bit32.band(vertices[off + i + 1].type, 1) == 0 then
                        -- next point is also a curve point, so interpolate an on-point curve
                        sx = bit32.rshift(x + stbtt_int32(vertices[off + i + 1].x), 1)
                        sy = bit32.rshift(y + stbtt_int32(vertices[off + i + 1].y), 1)
                    else
                        -- otherwise just use the next point as our start point
                        sx = stbtt_int32(vertices[off + i + 1].x)
                        sy = stbtt_int32(vertices[off + i + 1].y)
                        i = i + 1 -- we're using point i+1 as the starting point, so skip it
                    end
                else
                    sx = x
                    sy = y
                end
                stbtt_setvertex(vertices[num_vertices + 1], STBTT_VTX.MOVE, sx, sy, 0, 0)
                num_vertices = num_vertices + 1
                was_off = false
                next_move = 1 + ttUSHORT(data, endPtsOfContours + j * 2)
                j = j + 1
            else
                if bit32.band(flags, 1) == 0 then -- if it's a curve
                    if was_off then -- two off-curve control points in a row means interpolate an on-curve midpoint
                        stbtt_setvertex(vertices[num_vertices + 1], STBTT_VTX.CURVE, bit32.rshift(cx + x, 1), bit32.rshift(cy + y, 1), cx, cy)
                        num_vertices = num_vertices + 1
                    end

                    cx = x
                    cy = y
                    was_off = true
                else
                    if was_off then
                        stbtt_setvertex(vertices[num_vertices + 1], STBTT_VTX.CURVE, x, y, cx, cy)
                        num_vertices = num_vertices + 1
                    else
                        stbtt_setvertex(vertices[num_vertices + 1], STBTT_VTX.LINE, x, y, 0, 0)
                        num_vertices = num_vertices + 1
                    end

                    was_off = false
                end
            end
        end

        num_vertices = stbtt__close_shape(vertices, num_vertices, was_off, start_off, sx, sy, scx, scy, cx, cy)
    elseif numberOfContours < 0 then
        -- Compound shapes.
        local more = 1
        local comp = g + 10
        num_vertices = 0

        while more ~= 0 do
            local flags, gidx
            local comp_num_vertices = 0
            local comp_verts

            local mtx = {1, 0, 0, 1, 0, 0}
            local m, n

            flags = ttSHORT(data, comp) comp = comp + 2
            gidx = ttSHORT(data, comp) comp = comp + 2

            if bit32.band(flags, 2) ~= 0 then -- XY values
                if bit32.band(flags, 1) ~= 0 then -- shorts
                    mtx[5] = ttSHORT(data, comp) comp = comp + 2
                    mtx[6] = ttSHORT(data, comp) comp = comp + 2
                else
                    mtx[5] = ttCHAR(data, comp) comp = comp + 1
                    mtx[6] = ttCHAR(data, comp) comp = comp + 1
                end
            else
                -- @TODO handle matching point
                STBTT_assert(false)
            end

            if bit32.band(flags, bit32.lshift(1, 3)) ~= 0 then -- WE_HAVE_A_SCALE
                mtx[4] = ttSHORT(data, comp) / 16384.0
                mtx[1] = mtx[4]
                comp = comp + 2

                mtx[3] = 0
                mtx[2] = mtx[3]
            elseif bit32.band(flags, bit32.lshift(1, 6)) ~= 0 then -- WE_HAVE_AN_X_AND_YSCALE
                mtx[1] = ttSHORT(data, comp) / 16384.0
                comp = comp + 2

                mtx[3] = 0
                mtx[2] = mtx[3]

                mtx[4] = ttSHORT(data, comp) / 16384.0
                comp = comp + 2
            elseif bit32.band(flags, bit32.lshift(1, 7)) ~= 0 then -- WE_HAVE_A_TWO_BY_TWO
                mtx[1] = ttSHORT(data, comp) / 16384.0 comp = comp + 2
                mtx[2] = ttSHORT(data, comp) / 16384.0 comp = comp + 2
                mtx[3] = ttSHORT(data, comp) / 16384.0 comp = comp + 2
                mtx[4] = ttSHORT(data, comp) / 16384.0 comp = comp + 2
            end

            -- Find transformation scales.
            m = STBTT_sqrt(mtx[1] * mtx[1] + mtx[2] * mtx[2])
            n = STBTT_sqrt(mtx[3] * mtx[3] + mtx[4] * mtx[4])

            -- Get indexed glyph.
            comp_num_vertices, comp_verts = stbtt_GetGlyphShapeUncached(info, gidx) -- [Luau] transformed in place below: must be a fresh copy
            if comp_num_vertices > 0 then
                -- Transform vertices.
                for i = 1, comp_num_vertices do
                    local v = comp_verts[i]
                    local x = v.x
                    local y = v.y
                    v.x = stbtt_int16(m * (mtx[1] * x + mtx[3] * y + mtx[5]))
                    v.y = stbtt_int16(n * (mtx[2] * x + mtx[4] * y + mtx[6]))
                    x = v.cx
                    y = v.cy
                    v.cx = stbtt_int16(m * (mtx[1] * x + mtx[3] * y + mtx[5]))
                    v.cy = stbtt_int16(n * (mtx[2] * x + mtx[4] * y + mtx[6]))
                end

                -- Append vertices.
                if num_vertices == 0 then -- [Port] No malloc
                    vertices = comp_verts
                else
                    for i = 1, comp_num_vertices do
                        vertices[num_vertices + i] = comp_verts[i]
                    end
                end

                num_vertices = num_vertices + comp_num_vertices
            end

            -- More components ?
            more = bit32.band(flags, bit32.lshift(1, 5))
        end
    end

    return num_vertices, vertices
end

--- @param c stbtt__csctx
--- @param x stbtt_int32
--- @param y stbtt_int32
local function stbtt__track_vertex(c, x, y)
    if x > c.max_x or not c.started then c.max_x = x end
    if y > c.max_y or not c.started then c.max_y = y end
    if x < c.min_x or not c.started then c.min_x = x end
    if y < c.min_y or not c.started then c.min_y = y end
    c.started = true
end

--- @param c        stbtt__csctx
--- @param vtx_type STBTT_VTX
--- @param x        stbtt_int32
--- @param y        stbtt_int32
--- @param cx       stbtt_int32
--- @param cy       stbtt_int32
--- @param cx1      stbtt_int32
--- @param cy1      stbtt_int32
local function stbtt__csctx_v(c, vtx_type, x, y, cx, cy, cx1, cy1)
    if c.bounds then
        stbtt__track_vertex(c, x, y)
        if vtx_type == STBTT_VTX.CUBIC then
            stbtt__track_vertex(c, cx, cy)
            stbtt__track_vertex(c, cx1, cy1)
        end
    else
        stbtt_setvertex(c.pvertices[c.num_vertices + 1], vtx_type, x, y, cx, cy)
        c.pvertices[c.num_vertices + 1].cx1 = stbtt_int16(cx1)
        c.pvertices[c.num_vertices + 1].cy1 = stbtt_int16(cy1)
    end
end

--- @param ctx stbtt__csctx
local function stbtt__csctx_close_shape(ctx)
    if ctx.first_x ~= ctx.x or ctx.first_y ~= ctx.y then
        stbtt__csctx_v(ctx, STBTT_VTX.LINE, trunc(ctx.first_x), trunc(ctx.first_y), 0, 0, 0, 0)
    end
end

--- @param ctx stbtt__csctx
--- @param dx  float
--- @param dy  float
local function stbtt__csctx_rmove_to(ctx, dx, dy)
    stbtt__csctx_close_shape(ctx)
    ctx.x = ctx.x + dx
    ctx.first_x = ctx.x
    ctx.y = ctx.y + dy
    ctx.first_y = ctx.y
    stbtt__csctx_v(ctx, STBTT_VTX.MOVE, trunc(ctx.x), trunc(ctx.y), 0, 0, 0, 0)
end

--- @param ctx stbtt__csctx
--- @param dx  float
--- @param dy  float
local function stbtt__csctx_rline_to(ctx, dx, dy)
    ctx.x = ctx.x + dx
    ctx.y = ctx.y + dy
    stbtt__csctx_v(ctx, STBTT_VTX.LINE, trunc(ctx.x), trunc(ctx.y), 0, 0, 0, 0)
end

--- @param ctx stbtt__csctx
--- @param dx1 float
--- @param dy1 float
--- @param dx2 float
--- @param dy2 float
--- @param dx3 float
--- @param dy3 float
local function stbtt__csctx_rccurve_to(ctx, dx1, dy1, dx2, dy2, dx3, dy3)
    local cx1 = ctx.x + dx1
    local cy1 = ctx.y + dy1
    local cx2 = cx1 + dx2
    local cy2 = cy1 + dy2
    ctx.x = cx2 + dx3
    ctx.y = cy2 + dy3
    stbtt__csctx_v(ctx, STBTT_VTX.CUBIC, trunc(ctx.x), trunc(ctx.y), trunc(cx1), trunc(cy1), trunc(cx2), trunc(cy2))
end

local function stbtt__get_subr(idx, n)
    local count = stbtt__cff_index_count(idx)
    local bias = 107
    if count >= 33900 then
        bias = 32768
    elseif count >= 1240 then
        bias = 1131
    end
    n = n + bias
    if n < 0 or n >= count then
        return stbtt__new_buf(nil, 0)
    end
    return stbtt__cff_index_get(idx, n)
end

local function stbtt__cid_get_glyph_subrs(info, glyph_index)
    local fdselect = info.fdselect
    local fdselector = -1

    stbtt__buf_seek(fdselect, 0)
    local fmt = stbtt__buf_get8(fdselect)
    if fmt == 0 then
        -- untested
        stbtt__buf_skip(fdselect, glyph_index)
        fdselector = stbtt__buf_get8(fdselect)
    elseif fmt == 3 then
        local nranges = stbtt__buf_get16(fdselect)
        local start = stbtt__buf_get16(fdselect)
        for i = 0, nranges - 1 do
            local v = stbtt__buf_get8(fdselect)
            local _end = stbtt__buf_get16(fdselect)
            if glyph_index >= start and glyph_index < _end then
                fdselector = v
                break
            end
            start = _end
        end
    end
    if fdselector == -1 then return stbtt__new_buf(nil, 0) end -- [DEAR IMGUI] fixed, see #6007 and nothings/stb#1422
    return stbtt__get_subrs(info.cff, stbtt__cff_index_get(info.fontdicts, fdselector))
end

--- @param info        stbtt_fontinfo
--- @param glyph_index int
--- @param c           stbtt__csctx
local function stbtt__run_charstring(info, glyph_index, c)
    local in_header = true
    local maskbits = 0
    local subr_stack_height = 0
    local sp = 0
    local has_subrs = 0
    local clear_stack

    local s = {} -- [Port] size = 48, 0-based

    local subr_stack = {} for i = 1, 10 do subr_stack[i] = stbtt__buf() end

    local subrs = info.subrs
    local b, f

    local function STBTT__CSERR(_s) return 0 end

    -- this currently ignores the initial width value, which isn't needed if we have hmtx
    b = stbtt__cff_index_get(info.charstrings, glyph_index)
    local i, v, b0
    while b.cursor < b.size do
        i = 0
        clear_stack = 1
        b0 = stbtt__buf_get8(b)

        -- @TODO implement hinting
        if b0 == 0x13 or b0 == 0x14 then -- hintmask or cntrmask
            if in_header then
                maskbits = maskbits + trunc(sp / 2)  -- implicit "vstem"
            end
            in_header = false
            stbtt__buf_skip(b, trunc((maskbits + 7) / 8))
        elseif b0 == 0x01 or b0 == 0x03 or b0 == 0x12 or b0 == 0x17 then -- hstem, vstem, hstemhm, vstemhm
            maskbits = maskbits + trunc(sp / 2)
        elseif b0 == 0x15 then -- rmoveto
            in_header = false
            if sp < 2 then return STBTT__CSERR("rmoveto stack") end
            stbtt__csctx_rmove_to(c, s[sp - 2], s[sp - 1])
        elseif b0 == 0x04 then -- vmoveto
            in_header = false
            if sp < 1 then return STBTT__CSERR("vmoveto stack") end
            stbtt__csctx_rmove_to(c, 0, s[sp - 1])
        elseif b0 == 0x16 then -- hmoveto
            in_header = false
            if sp < 1 then return STBTT__CSERR("hmoveto stack") end
            stbtt__csctx_rmove_to(c, s[sp - 1], 0)
        elseif b0 == 0x05 then -- rlineto
            if sp < 2 then return STBTT__CSERR("rlineto stack") end
            while i + 1 < sp do
                stbtt__csctx_rline_to(c, s[i], s[i + 1])
                i = i + 2
            end

        -- hlineto/vlineto and vhcurveto/hvcurveto alternate horizontal and vertical
        -- starting from a different place.

        elseif b0 == 0x07 then -- vlineto
            if sp < 1 then return STBTT__CSERR("vlineto stack") end
            while true do
                if i >= sp then break end
                stbtt__csctx_rline_to(c, 0, s[i])
                i = i + 1
                if i >= sp then break end
                stbtt__csctx_rline_to(c, s[i], 0)
                i = i + 1
            end
        elseif b0 == 0x06 then -- hlineto
            if sp < 1 then return STBTT__CSERR("hlineto stack") end

            while true do
                if i >= sp then break end
                stbtt__csctx_rline_to(c, s[i], 0)
                i = i + 1
            -- vlineto
                if i >= sp then break end
                stbtt__csctx_rline_to(c, 0, s[i])
                i = i + 1
            end
        elseif b0 == 0x1F then -- hvcurveto
            if sp < 4 then return STBTT__CSERR("hvcurveto stack") end
            while true do
                if i + 3 >= sp then break end
                stbtt__csctx_rccurve_to(c, s[i], 0, s[i + 1], s[i + 2], ((sp - i) == 5) and s[i + 4] or 0.0, s[i + 3])
                i = i + 4
                if i + 3 >= sp then break end
                stbtt__csctx_rccurve_to(c, 0, s[i], s[i + 1], s[i + 2], s[i + 3], ((sp - i) == 5) and s[i + 4] or 0.0)
                i = i + 4
            end
        elseif b0 == 0x1E then -- vhcurveto
            if sp < 4 then return STBTT__CSERR("vhcurveto stack") end

            while true do
                if i + 3 >= sp then break end
                stbtt__csctx_rccurve_to(c, 0, s[i], s[i + 1], s[i + 2], s[i + 3], ((sp - i) == 5) and s[i + 4] or 0.0)
                i = i + 4
            -- hvcurveto
                if i + 3 >= sp then break end
                stbtt__csctx_rccurve_to(c, s[i], 0, s[i + 1], s[i + 2], ((sp - i) == 5) and s[i + 4] or 0.0, s[i + 3])
                i = i + 4
            end
        elseif b0 == 0x08 then -- rrcurveto
            if sp < 6 then return STBTT__CSERR("rcurveline stack") end

            while i + 5 < sp do
                stbtt__csctx_rccurve_to(c, s[i], s[i + 1], s[i + 2], s[i + 3], s[i + 4], s[i + 5])
                i = i + 6
            end
        elseif b0 == 0x18 then -- rcurveline
            if sp < 8 then return STBTT__CSERR("rcurveline stack") end

            while i + 5 < sp - 2 do
                stbtt__csctx_rccurve_to(c, s[i], s[i + 1], s[i + 2], s[i + 3], s[i + 4], s[i + 5])
                i = i + 6
            end
            if i + 1 >= sp then return STBTT__CSERR("rcurveline stack") end
            stbtt__csctx_rline_to(c, s[i], s[i + 1])
        elseif b0 == 0x19 then -- rlinecurve
            if sp < 8 then return STBTT__CSERR("rlinecurve stack") end

            while i + 1 < sp - 6 do
                stbtt__csctx_rline_to(c, s[i], s[i + 1])
                i = i + 2
            end
            if i + 5 >= sp then return STBTT__CSERR("rlinecurve stack") end
            stbtt__csctx_rccurve_to(c, s[i], s[i + 1], s[i + 2], s[i + 3], s[i + 4], s[i + 5])
        elseif b0 == 0x1A or b0 == 0x1B then -- vvcurveto or hhcurveto
            if sp < 4 then return STBTT__CSERR("(vv|hh)curveto stack") end
            f = 0.0

            if bit32.band(sp, 1) ~= 0 then
                f = s[i]
                i = i + 1
            end
            while i + 3 < sp do
                if b0 == 0x1B then
                    stbtt__csctx_rccurve_to(c, s[i], f, s[i + 1], s[i + 2], s[i + 3], 0.0)
                else
                    stbtt__csctx_rccurve_to(c, f, s[i], s[i + 1], s[i + 2], 0.0, s[i + 3])
                end
                f = 0.0
                i = i + 4
            end
        elseif b0 == 0x0A -- callsubr
            or b0 == 0x1D then

            if b0 == 0x0A and has_subrs == 0 then
                if info.fdselect.size ~= 0 then
                    subrs = stbtt__cid_get_glyph_subrs(info, glyph_index)
                end
                has_subrs = 1
            end

            -- callgsubr
            if sp < 1 then return STBTT__CSERR("call(g|)subr stack") end
            sp = sp - 1
            v = trunc(s[sp])
            if subr_stack_height >= 10 then return STBTT__CSERR("recursion limit") end
            subr_stack[subr_stack_height + 1] = b
            subr_stack_height = subr_stack_height + 1
            b = stbtt__get_subr((b0 == 0x0A) and subrs or info.gsubrs, v)
            if b.size == 0 then return STBTT__CSERR("subr not found") end
            b.cursor = 0
            clear_stack = 0
        elseif b0 == 0x0B then -- return
            if subr_stack_height <= 0 then return STBTT__CSERR("return outside subr") end
            subr_stack_height = subr_stack_height - 1
            b = subr_stack[subr_stack_height + 1]
            clear_stack = 0
        elseif b0 == 0x0E then -- endchar
            stbtt__csctx_close_shape(c)
            return 1
        elseif b0 == 0x0C then -- two-byte escape
            local b1 = stbtt__buf_get8(b)

            -- @TODO These "flex" implementations ignore the flex-depth and resolution,
            -- and always draw beziers.
            if b1 == 0x22 then -- hflex
                if sp < 7 then return STBTT__CSERR("hflex stack") end
                local dx1 = s[0]
                local dx2 = s[1]
                local dy2 = s[2]
                local dx3 = s[3]
                local dx4 = s[4]
                local dx5 = s[5]
                local dx6 = s[6]
                stbtt__csctx_rccurve_to(c, dx1, 0, dx2, dy2, dx3, 0)
                stbtt__csctx_rccurve_to(c, dx4, 0, dx5, -dy2, dx6, 0)
            elseif b1 == 0x23 then -- flex
                if sp < 13 then return STBTT__CSERR("flex stack") end
                local dx1 = s[0]
                local dy1 = s[1]
                local dx2 = s[2]
                local dy2 = s[3]
                local dx3 = s[4]
                local dy3 = s[5]
                local dx4 = s[6]
                local dy4 = s[7]
                local dx5 = s[8]
                local dy5 = s[9]
                local dx6 = s[10]
                local dy6 = s[11]
                -- fd is s[12]
                stbtt__csctx_rccurve_to(c, dx1, dy1, dx2, dy2, dx3, dy3)
                stbtt__csctx_rccurve_to(c, dx4, dy4, dx5, dy5, dx6, dy6)
            elseif b1 == 0x24 then -- hflex1
                if sp < 9 then return STBTT__CSERR("hflex1 stack") end
                local dx1 = s[0]
                local dy1 = s[1]
                local dx2 = s[2]
                local dy2 = s[3]
                local dx3 = s[4]
                local dx4 = s[5]
                local dx5 = s[6]
                local dy5 = s[7]
                local dx6 = s[8]
                stbtt__csctx_rccurve_to(c, dx1, dy1, dx2, dy2, dx3, 0)
                stbtt__csctx_rccurve_to(c, dx4, 0, dx5, dy5, dx6, -(dy1 + dy2 + dy5))
            elseif b1 == 0x25 then -- flex1
                if sp < 11 then return STBTT__CSERR("flex1 stack") end
                local dx1 = s[0]
                local dy1 = s[1]
                local dx2 = s[2]
                local dy2 = s[3]
                local dx3 = s[4]
                local dy3 = s[5]
                local dx4 = s[6]
                local dy4 = s[7]
                local dx5 = s[8]
                local dy5 = s[9]
                local dx6 = s[10]
                local dy6 = s[10]
                local dx = dx1 + dx2 + dx3 + dx4 + dx5
                local dy = dy1 + dy2 + dy3 + dy4 + dy5
                if STBTT_fabs(dx) > STBTT_fabs(dy) then
                    dy6 = -dy
                else
                    dx6 = -dx
                end
                stbtt__csctx_rccurve_to(c, dx1, dy1, dx2, dy2, dx3, dy3)
                stbtt__csctx_rccurve_to(c, dx4, dy4, dx5, dy5, dx6, dy6)
            else
                return STBTT__CSERR("unimplemented")
            end
        else
            if b0 ~= 255 and b0 ~= 28 and b0 < 32 then
                return STBTT__CSERR("reserved operator")
            end

            -- push immediate
            if b0 == 255 then
                f = stbtt__buf_get32(b) / 0x10000
            else
                stbtt__buf_skip(b, -1)
                f = stbtt_int16(stbtt__cff_int(b))
            end
            if sp >= 48 then return STBTT__CSERR("push stack overflow") end
            s[sp] = f
            sp = sp + 1
            clear_stack = 0
        end

        if clear_stack ~= 0 then
            sp = 0
        end
    end

    return STBTT__CSERR("no endchar")
end

--- @param info        stbtt_fontinfo
--- @param glyph_index int
--- @return int             num_vertices
--- @return stbtt_vertex[]? vertices
function stbtt__GetGlyphShapeT2(info, glyph_index)
    -- runs the charstring twice, once to count and once to output (to avoid realloc)
    local vertices = nil
    local count_ctx = STBTT__CSCTX_INIT(true)
    local output_ctx = STBTT__CSCTX_INIT(false)
    if stbtt__run_charstring(info, glyph_index, count_ctx) ~= 0 then
        vertices = {} for i = 1, count_ctx.num_vertices do vertices[i] = stbtt_vertex() end

        output_ctx.pvertices = vertices
        if stbtt__run_charstring(info, glyph_index, output_ctx) ~= 0 then
            STBTT_assert(output_ctx.num_vertices == count_ctx.num_vertices)
            return output_ctx.num_vertices, vertices
        end
    end

    return 0, vertices
end

--- @param info        stbtt_fontinfo
--- @param glyph_index int
--- @return int
--- @return int x0
--- @return int y0
--- @return int x1
--- @return int y1
function stbtt__GetGlyphInfoT2(info, glyph_index)
    local c = STBTT__CSCTX_INIT(true)
    local r = stbtt__run_charstring(info, glyph_index, c)
    local x0 = (r ~= 0) and c.min_x or 0
    local y0 = (r ~= 0) and c.min_y or 0
    local x1 = (r ~= 0) and c.max_x or 0
    local y1 = (r ~= 0) and c.max_y or 0
    return ((r ~= 0) and c.num_vertices or 0), x0, y0, x1, y1
end

-- returns # of vertices and fills *vertices with the pointer to them
--   these are expressed in "unscaled" coordinates
--
-- The shape is a series of contours. Each one starts with
-- a STBTT_moveto, then consists of a series of mixed
-- STBTT_lineto and STBTT_curveto segments. A lineto
-- draws a line from previous endpoint to its x,y; a curveto
-- draws a quadratic bezier from previous endpoint to
-- its x,y, using cx,cy as the bezier control point.
--- @param info        stbtt_fontinfo
--- @param glyph_index int
@native
function stbtt_GetGlyphShapeUncached(info, glyph_index)
    if info.cff.size == 0 then
        return stbtt__GetGlyphShapeTT(info, glyph_index)
    else
        return stbtt__GetGlyphShapeT2(info, glyph_index)
    end
end

@native
function stbtt_GetGlyphShape(info, glyph_index)
    -- [Luau] shapes don't depend on the size: cache them per font (baking a new size re-used to re-parse every glyph).
    -- Callers only read the vertices (stbtt_FreeShape is a no-op).
    local cache = info._ShapeCache
    if cache == nil then cache = {}; info._ShapeCache = cache end
    local e = cache[glyph_index]
    if e == nil then
        local n, v
        if info.cff.size == 0 then
            n, v = stbtt__GetGlyphShapeTT(info, glyph_index)
        else
            n, v = stbtt__GetGlyphShapeT2(info, glyph_index)
        end
        e = { n, v }
        cache[glyph_index] = e
    end
    return e[1], e[2]
end

-- leftSideBearing is the offset from the current horizontal position to the left edge of the character
-- advanceWidth is the offset from the current horizontal position to the next horizontal position
--   these are expressed in unscaled coordinates
--- @param info        stbtt_fontinfo
--- @param glyph_index int
@native
function stbtt_GetGlyphHMetrics(info, glyph_index)
    local numOfLongHorMetrics = ttUSHORT(info.data, info.hhea + 34)

    local advanceWidth, leftSideBearing
    if glyph_index < numOfLongHorMetrics then
        advanceWidth = ttSHORT(info.data, info.hmtx + 4 * glyph_index)
        leftSideBearing = ttSHORT(info.data, info.hmtx + 4 * glyph_index + 2)
    else
        advanceWidth = ttSHORT(info.data, info.hmtx + 4 * (numOfLongHorMetrics - 1))
        leftSideBearing = ttSHORT(info.data, info.hmtx + 4 * numOfLongHorMetrics + 2 * (glyph_index - numOfLongHorMetrics))
    end

    return advanceWidth, leftSideBearing
end

-- ascent is the coordinate above the baseline the font extends; descent
-- is the coordinate below the baseline the font extends (i.e. it is typically negative)
-- lineGap is the spacing between one row's descent and the next row's ascent...
-- so you should advance the vertical position by "ascent - descent + lineGap"
--   these are expressed in unscaled coordinates, so you must multiply by
--   the scale factor for a given size
--- @param info stbtt_fontinfo
@native
function stbtt_GetFontVMetrics(info)
    local ascent = ttSHORT(info.data, info.hhea + 4)
    local descent = ttSHORT(info.data, info.hhea + 6)
    local lineGap = ttSHORT(info.data, info.hhea + 8)

    return ascent, descent, lineGap
end

-- computes a scale factor to produce a font whose "height" is 'pixels' tall.
-- Height is measured as the distance from the highest ascender to the lowest
-- descender; in other words, it's equivalent to calling stbtt_GetFontVMetrics
-- and computing:
--       scale = pixels / (ascent - descent)
-- so if you prefer to measure height by the ascent only, use a similar calculation.
--- @param info   stbtt_fontinfo
--- @param height float
@native
function stbtt_ScaleForPixelHeight(info, height)
    local fheight = ttSHORT(info.data, info.hhea + 4) - ttSHORT(info.data, info.hhea + 6)
    return height / fheight
end

------------------------------------
------------------------------------
---
--- antialiasing software rasterizer
---
---

-- same as stbtt_GetGlyphBitmapBox, but you can specify a subpixel
-- shift for the character
--- @param font    stbtt_fontinfo
--- @param glyph   int
--- @param scale_x float
--- @param scale_y float
--- @param shift_x float
--- @param shift_y float
@native
function stbtt_GetGlyphBitmapBoxSubpixel(font, glyph, scale_x, scale_y, shift_x, shift_y)
    local n, x0, y0, x1, y1 = stbtt_GetGlyphBox(font, glyph)

    local ix0, iy0, ix1, iy1
    if n == 0 then
        -- e.g. space character
        ix0 = 0
        iy0 = 0
        ix1 = 0
        iy1 = 0
    else
        -- move to integral bboxes (treating pixels as little squares, what pixels get touched)?
        ix0 = STBTT_ifloor( x0 * scale_x + shift_x)
        iy0 = STBTT_ifloor(-y1 * scale_y + shift_y)
        ix1 = STBTT_iceil( x1 * scale_x + shift_x)
        iy1 = STBTT_iceil(-y0 * scale_y + shift_y)
    end

    return ix0, iy0, ix1, iy1
end

-- get the bbox of the bitmap centered around the glyph origin; so the
-- bitmap width is ix1-ix0, height is iy1-iy0, and location to place
-- the bitmap top left is (leftSideBearing*scale,iy0).
-- (Note that the bitmap uses y-increases-down, but the shape uses
-- y-increases-up, so GlyphBitmapBox and GlyphBox are inverted.)
--- @param font    stbtt_fontinfo
--- @param glyph   int
--- @param scale_x float
--- @param scale_y float
@native
function stbtt_GetGlyphBitmapBox(font, glyph, scale_x, scale_y)
    return stbtt_GetGlyphBitmapBoxSubpixel(font, glyph, scale_x, scale_y, 0.0, 0.0)
end

--------------
--------------
---
--- Rasterizer
---
---

--- UNIMPLEMENTED / UNUSED:
---     stbtt_MakeCodepointBitmap
---     stbtt_MakeCodepointBitmapSubpixelPrefilter
---     stbtt_GetGlyphBitmap
---     stbtt_MakeGlyphBitmap
---     stbtt_GetGlyphBitmapSubpixel

-- the edge passed in here does not cross the vertical line at x or the vertical line at x+1
-- (i.e. it has already been clipped to those)
--- @param scanline float[]
--- @param x        int
--- @param e        stbtt__active_edge
--- @param x0       float
--- @param y0       float
--- @param x1       float
--- @param y1       float
@native
local function stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x1, y1)
    if y0 == y1 then return end
    STBTT_assert(y0 < y1)
    STBTT_assert(e.sy <= e.ey)

    if y0 > e.ey then return end
    if y1 < e.sy then return end
    if y0 < e.sy then
        x0 = x0 + (x1 - x0) * (e.sy - y0) / (y1 - y0)
        y0 = e.sy
    end
    if y1 > e.ey then
        x1 = x1 + (x1 - x0) * (e.ey - y1) / (y1 - y0)
        y1 = e.ey
    end

    if x0 == x then
        STBTT_assert(x1 <= x + 1)
    elseif x0 == x + 1 then
        STBTT_assert(x1 >= x)
    elseif x0 <= x then
        STBTT_assert(x1 <= x)
    elseif x0 >= x + 1 then
        STBTT_assert(x1 >= x + 1)
    else
        STBTT_assert(x1 >= x and x1 <= x + 1)
    end

    if x0 <= x and x1 <= x then
        scanline[x] = scanline[x] + e.direction * (y1 - y0)
    elseif x0 >= x + 1 and x1 >= x + 1 then
        -- do nothing
    else
        STBTT_assert(x0 >= x and x0 <= x + 1 and x1 >= x and x1 <= x + 1)
        scanline[x] = scanline[x] + e.direction * (y1 - y0) * (1 - ((x0 - x) + (x1 - x)) / 2) -- coverage = 1 - average x position
    end
end

--- @param height       float
--- @param top_width    float
--- @param bottom_width float
@native
local function stbtt__sized_trapezoid_area(height, top_width, bottom_width)
    STBTT_assert(top_width >= 0)
    STBTT_assert(bottom_width >= 0)
    return (top_width + bottom_width) / 2.0 * height
end

--- @param height float
--- @param tx0    float
--- @param tx1    float
--- @param bx0    float
--- @param bx1    float
@native
local function stbtt__position_trapezoid_area(height, tx0, tx1, bx0, bx1)
    return stbtt__sized_trapezoid_area(height, tx1 - tx0, bx1 - bx0)
end

--- @param height float
--- @param width  float
@native
local function stbtt__sized_triangle_area(height, width)
    return height * width / 2
end

--- @param scanline      float[]
--- @param scanline_fill float[]
--- @param len           int
--- @param e             stbtt__active_edge
--- @param y_top         float
@native
local function stbtt__fill_active_edges_new(scanline, scanline_fill, len, e, y_top)
    local y_bottom = y_top + 1

    while e do
        -- brute force every pixel

        -- compute intersection points with top & bottom
        STBTT_assert(e.ey >= y_top)

        if e.fdx == 0 then
            local x0 = e.fx
            if x0 < len then
                -- [Luau] the stbtt__handle_clipped_edge() calls, inlined (every edge of pixel fonts like ProggyClean is
                -- vertical): x0 == x1, so clipping to sy/ey keeps x, and the same arithmetic gives the same results
                local y0, y1 = y_top, y_bottom
                local sy, ey = e.sy, e.ey
                if y0 <= ey and y1 >= sy then
                    if y0 < sy then y0 = sy end
                    if y1 > ey then y1 = ey end
                    local height = e.direction * (y1 - y0)
                    if x0 >= 0 then
                        local x = math.floor(x0) -- trunc(x0)
                        if x0 <= x then
                            scanline[x] = scanline[x] + height
                        else
                            scanline[x] = scanline[x] + height * (1 - ((x0 - x) + (x0 - x)) / 2)
                        end
                        scanline_fill[x + 1] = scanline_fill[x + 1] + height
                    else
                        scanline_fill[0] = scanline_fill[0] + height
                    end
                end
            end
        else
            local x0 = e.fx
            local dx = e.fdx
            local xb = x0 + dx
            local x_top, x_bottom
            local sy0, sy1
            local dy = e.fdy
            STBTT_assert(e.sy <= y_bottom and e.ey >= y_top)

            -- compute endpoints of line segment clipped to this scanline (if the
            -- line segment starts on this scanline. x0 is the intersection of the
            -- line with y_top, but that may be off the line segment.
            if e.sy > y_top then
                x_top = x0 + dx * (e.sy - y_top)
                sy0 = e.sy
            else
                x_top = x0
                sy0 = y_top
            end
            if e.ey < y_bottom then
                x_bottom = x0 + dx * (e.ey - y_top)
                sy1 = e.ey
            else
                x_bottom = xb
                sy1 = y_bottom
            end

            if x_top >= 0 and x_bottom >= 0 and x_top < len and x_bottom < len then
                -- from here on, we don't have to range check x values
                if trunc(x_top) == trunc(x_bottom) then
                    local height
                    -- simple case, only spans one pixel
                    local x = trunc(x_top)
                    height = (sy1 - sy0) * e.direction
                    STBTT_assert(x >= 0 and x < len)
                    scanline[x] = scanline[x] + stbtt__position_trapezoid_area(height, x_top, x + 1.0, x_bottom, x + 1.0)
                    scanline_fill[x + 1] = scanline_fill[x + 1] + height -- everything right of this pixel is filled
                else
                    local x1, x2
                    local y_crossing, y_final, step, sign, area
                    -- covers 2+ pixels
                    if x_top > x_bottom then
                        -- flip scanline vertically; signed area is the same
                        sy0 = y_bottom - (sy0 - y_top)
                        sy1 = y_bottom - (sy1 - y_top)
                        local t
                        t = sy0; sy0 = sy1; sy1 = t
                        t = x_bottom; x_bottom = x_top; x_top = t
                        dx = -dx
                        dy = -dy
                        t = x0; x0 = xb; xb = t
                    end
                    STBTT_assert(dy >= 0)
                    STBTT_assert(dx >= 0)

                    x1 = trunc(x_top)
                    x2 = trunc(x_bottom)
                    -- compute intersection with y axis at x1+1
                    y_crossing = y_top + dy * (x1 + 1 - x0)

                    -- compute intersection with y axis at x2
                    y_final = y_top + dy * (x2 - x0)

                    --           x1    x_top                            x2    x_bottom
                    --     y_top  +------|-----+------------+------------+--------|---+------------+
                    --            |            |            |            |            |            |
                    --            |            |            |            |            |            |
                    --       sy0  |      Txxxxx|............|............|............|............|
                    -- y_crossing |            *xxxxx.......|............|............|............|
                    --            |            |     xxxxx..|............|............|............|
                    --            |            |     /-   xx*xxxx........|............|............|
                    --            |            | dy <       |    xxxxxx..|............|............|
                    --   y_final  |            |     \-     |          xx*xxx.........|............|
                    --       sy1  |            |            |            |   xxxxxB...|............|
                    --            |            |            |            |            |            |
                    --            |            |            |            |            |            |
                    --  y_bottom  +------------+------------+------------+------------+------------+
                    --
                    -- goal is to measure the area covered by '.' in each pixel

                    -- if x2 is right at the right edge of x1, y_crossing can blow up, github #1057
                    -- @TODO: maybe test against sy1 rather than y_bottom?
                    if y_crossing > y_bottom then
                        y_crossing = y_bottom
                    end

                    sign = e.direction

                    -- area of the rectangle covered from sy0..y_crossing
                    area = sign * (y_crossing - sy0)

                    -- area of the triangle (x_top,sy0), (x1+1,sy0), (x1+1,y_crossing)
                    scanline[x1] = scanline[x1] + stbtt__sized_triangle_area(area, x1 + 1 - x_top)

                    -- check if final y_crossing is blown up; no test case for this
                    if y_final > y_bottom then
                        local denom = (x2 - (x1 + 1))
                        y_final = y_bottom
                        if denom ~= 0 then -- [DEAR IMGUI] Avoid div by zero (https://github.com/nothings/stb/issues/1316)
                            dy = (y_final - y_crossing) / denom -- if denom=0, y_final = y_crossing, so y_final <= y_bottom
                        end
                    end

                    -- in second pixel, area covered by line segment found in first pixel
                    -- is always a rectangle 1 wide * the height of that line segment; this
                    -- is exactly what the variable 'area' stores. it also gets a contribution
                    -- from the line segment within it. the THIRD pixel will get the first
                    -- pixel's rectangle contribution, the second pixel's rectangle contribution,
                    -- and its own contribution. the 'own contribution' is the same in every pixel except
                    -- the leftmost and rightmost, a trapezoid that slides down in each pixel.
                    -- the second pixel's contribution to the third pixel will be the
                    -- rectangle 1 wide times the height change in the second pixel, which is dy.

                    step = sign * dy * 1 -- dy is dy/dx, change in y for every 1 change in x,
                    -- which multiplied by 1-pixel-width is how much pixel area changes for each step in x
                    -- so the area advances by 'step' every time

                    for x = x1 + 1, x2 - 1 do
                        scanline[x] = scanline[x] + area + step / 2 -- area of trapezoid is 1*step/2
                        area = area + step
                    end
                    STBTT_assert(STBTT_fabs(area) <= 1.01) -- accumulated error from area += step unless we round step down
                    STBTT_assert(sy1 > y_final - 0.01)

                    -- area covered in the last pixel is the rectangle from all the pixels to the left,
                    -- plus the trapezoid filled by the line segment in this pixel all the way to the right edge
                    scanline[x2] = scanline[x2] + area + sign * stbtt__position_trapezoid_area(sy1 - y_final, x2, x2 + 1.0, x_bottom, x2 + 1.0)

                    -- the rest of the line is filled based on the total height of the line segment in this pixel
                    scanline_fill[x2 + 1] = scanline_fill[x2 + 1] + sign * (sy1 - sy0)
                end
            else
                -- if edge goes outside of box we're drawing, we require
                -- clipping logic. since this does not match the intended use
                -- of this library, we use a different, very slow brute
                -- force implementation
                -- note though that this does happen some of the time because
                -- x_top and x_bottom can be extrapolated at the top & bottom of
                -- the shape and actually lie outside the bounding box
                for x = 0, len - 1 do
                    -- cases:
                    --
                    -- there can be up to two intersections with the pixel. any intersection
                    -- with left or right edges can be handled by splitting into two (or three)
                    -- regions. intersections with top & bottom do not necessitate case-wise logic.
                    --
                    -- the old way of doing this found the intersections with the left & right edges,
                    -- then used some simple logic to produce up to three segments in sorted order
                    -- from top-to-bottom. however, this had a problem: if an x edge was epsilon
                    -- across the x border, then the corresponding y position might not be distinct
                    -- from the other y segment, and it might ignored as an empty segment. to avoid
                    -- that, we need to explicitly produce segments based on x positions.

                    -- rename variables to clearly-defined pairs
                    local y0 = y_top
                    local x1 = x
                    local x2 = x + 1
                    local x3 = xb
                    local y3 = y_bottom

                    -- x = e->x + e->dx * (y-y_top)
                    -- (y-y_top) = (x - e->x) / e->dx
                    -- y = (x - e->x) / e->dx + y_top
                    local y1 = (x - x0) / dx + y_top
                    local y2 = (x + 1 - x0) / dx + y_top

                    if x0 < x1 and x3 > x2 then -- three segments descending down-right
                        stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x1, y1)
                        stbtt__handle_clipped_edge(scanline, x, e, x1, y1, x2, y2)
                        stbtt__handle_clipped_edge(scanline, x, e, x2, y2, x3, y3)
                    elseif x3 < x1 and x0 > x2 then -- three segments descending down-left
                        stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x2, y2)
                        stbtt__handle_clipped_edge(scanline, x, e, x2, y2, x1, y1)
                        stbtt__handle_clipped_edge(scanline, x, e, x1, y1, x3, y3)
                    elseif x0 < x1 and x3 > x1 then -- two segments across x, down-right
                        stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x1, y1)
                        stbtt__handle_clipped_edge(scanline, x, e, x1, y1, x3, y3)
                    elseif x3 < x1 and x0 > x1 then -- two segments across x, down-left
                        stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x1, y1)
                        stbtt__handle_clipped_edge(scanline, x, e, x1, y1, x3, y3)
                    elseif x0 < x2 and x3 > x2 then -- two segments across x+1, down-right
                        stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x2, y2)
                        stbtt__handle_clipped_edge(scanline, x, e, x2, y2, x3, y3)
                    elseif x3 < x2 and x0 > x2 then -- two segments across x+1, down-left
                        stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x2, y2)
                        stbtt__handle_clipped_edge(scanline, x, e, x2, y2, x3, y3)
                    else -- one segment
                        stbtt__handle_clipped_edge(scanline, x, e, x0, y0, x3, y3)
                    end
                end
            end
        end
        e = e.next
    end
end

-- directly AA rasterize edges w/o supersampling
--- @param result     stbtt__bitmap
--- @param e          stbtt__edge
--- @param n          int
--- @param vsubsample int
--- @param off_x      int
--- @param off_y      int
local rasterize_scanline, rasterize_scanline2 = {}, {} -- [Luau] reused: fully cleared per scanline below
@native
local function stbtt__rasterize_sorted_edges(result, e, n, vsubsample, off_x, off_y)
    local active = nil

    active_pool_n = 0 -- every active edge of the previous call is dead
    local scanline = rasterize_scanline -- [Port] size = result.w, 0-based
    local scanline2 = rasterize_scanline2 -- [Port] size = result.w + 1, 0-based

    STBTT__NOTUSED(vsubsample)

    local y = off_y
    e[n + 1].y0 = off_y + result.h + 1

    local j = 0
    local p = 1
    while j < result.h do
        -- find center of pixel for this scanline
        local scan_y_top = y + 0.0
        local scan_y_bottom = y + 1.0

        for i = 0, result.w - 1 do scanline[i] = 0 end
        for i = 0, result.w do scanline2[i] = 0 end

        -- update all active edges;
        -- remove all active edges that terminate before the top of this scanline
        local prev = nil
        local curr = active
        while curr do
            local next = curr.next
            if curr.ey <= scan_y_top then
                if prev then prev.next = next -- delete from list
                else          active   = next end
                curr.direction = 0
            else
                prev = curr -- advance through list
            end
            curr = next
        end

        -- insert all edges that start before the bottom of this scanline
        local edge = e[p]
        while edge.y0 <= scan_y_bottom do
            if edge.y0 ~= edge.y1 then
                local z = stbtt__new_active(edge, off_x, scan_y_top)
                if j == 0 and off_y ~= 0 and z.ey < scan_y_top then
                    -- this can happen due to subpixel positioning and some kind of fp rounding error i think
                    z.ey = scan_y_top
                end
                STBTT_assert(z.ey >= scan_y_top) -- if we get really unlucky a tiny bit of an edge can be out of bounds
                -- insert at front
                z.next = active
                active = z
            end
            p = p + 1
            edge = e[p]
        end

        -- now process all active edges
        if active then
            stbtt__fill_active_edges_new(scanline, scanline2, result.w, active, scan_y_top)
        end

        do
            local sum = 0
            local pixels, base = result.pixels, j * result.stride + 1
            for i = 0, result.w - 1 do
                sum = sum + scanline2[i]
                -- [Luau] k >= 0: trunc == floor, and m is already 0..255 (unsigned_char() is a no-op)
                local m = math.floor(math.abs(scanline[i] + sum) * 255 + 0.5)
                if m > 255 then m = 255 end
                pixels[base + i] = m
            end
        end

        -- advance all the edges
        local step = active
        while step do
            step.fx = step.fx + step.fdx -- advance to position for current scanline
            step = step.next -- advance through list
        end

        y = y + 1
        j = j + 1
    end
end

--- @param a stbtt__edge
--- @param b stbtt__edge
local STBTT__COMPARE = function(a, b)
    if a.y0 == nil then return false end -- [Port] sentinels on the back
    if b.y0 == nil then return true  end
    return a.y0 < b.y0
end

--- @param p stbtt__edge[]
@native
local function stbtt__sort_edges(p)
    STBTT_sort(p, STBTT__COMPARE)
end

-- [Luau] sorts p[lo..hi] by y0 without a comparator callback (like upstream's stbtt__sort_edges_quicksort + ins_sort)
@native
local function stbtt__sort_edges_range(p, lo, hi)
    while hi - lo > 12 do
        -- median of three -> p[lo]
        local m = math.floor((lo + hi) / 2)
        local a, b, c = p[lo], p[m], p[hi]
        if b.y0 < a.y0 then a, b = b, a end
        if c.y0 < b.y0 then b, c = c, b; if b.y0 < a.y0 then a, b = b, a end end
        p[lo], p[m], p[hi] = b, a, c
        local pivot = p[lo].y0
        local i, j = lo + 1, hi
        while true do
            while p[i].y0 < pivot do i = i + 1 end
            while pivot < p[j].y0 do j = j - 1 end
            if i >= j then break end
            p[i], p[j] = p[j], p[i]
            i = i + 1; j = j - 1
        end
        p[lo], p[j] = p[j], p[lo]
        -- recurse into the smaller side, loop on the larger
        if j - lo < hi - j then
            stbtt__sort_edges_range(p, lo, j - 1); lo = j + 1
        else
            stbtt__sort_edges_range(p, j + 1, hi); hi = j - 1
        end
    end
    for i = lo + 1, hi do
        local t = p[i]
        local y = t.y0
        local j = i - 1
        while j >= lo and p[j].y0 > y do p[j + 1] = p[j]; j = j - 1 end
        p[j + 1] = t
    end
end

--- @param result   stbtt__bitmap
--- @param pts      stbtt__point[]
--- @param wcount   int[]
--- @param windings int
--- @param scale_x  float
--- @param scale_y  float
--- @param shift_x  float
--- @param shift_y  float
--- @param off_x    int
--- @param off_y    int
--- @param invert   bool
local rasterize_edges = {}
@native
local function stbtt__rasterize(result, pts, wcount, windings, scale_x, scale_y, shift_x, shift_y, off_x, off_y, invert)
    local y_scale_inv = (invert) and -scale_y or scale_y
    local vsubsample = 1 -- STBTT_RASTERIZER_VERSION == 2
    -- vsubsample should divide 255 evenly; otherwise we won't reach full opacity

    -- now we have to blow out the windings into explicit edge lists
    local n = 0
    for i = 1, windings do
        n = n + wcount[i]
    end

    -- [Luau] edges reused across calls; unused entries are sentinels (y0 = nil) like the unfilled ones upstream
    local e = rasterize_edges
    for i = 1, n + 1 do
        local ed = e[i]
        if ed == nil then e[i] = stbtt__edge() else ed.y0 = nil; ed.invert = false end
    end
    for i = n + 2, #e do e[i].y0 = nil end
    n = 0

    local m = 0
    local j
    for i = 1, windings do
        local p = m
        m = m + wcount[i]
        j = wcount[i]
        for k = 1, wcount[i] do
            repeat
            local a = k
            local b = j
            -- skip the edge if horizontal
            if pts[p + j].y == pts[p + k].y then
                break
            end
            -- add edge from j to k to the list
            n = n + 1
            e[n].invert = false
            if invert then
                if pts[p + j].y > pts[p + k].y then
                    e[n].invert = true
                    a = j
                    b = k
                end
            else
                if pts[p + j].y < pts[p + k].y then
                    e[n].invert = true
                    a = j
                    b = k
                end
            end
            e[n].x0 = pts[p + a].x * scale_x + shift_x
            e[n].y0 = (pts[p + a].y * y_scale_inv + shift_y) * vsubsample
            e[n].x1 = pts[p + b].x * scale_x + shift_x
            e[n].y1 = (pts[p + b].y * y_scale_inv + shift_y) * vsubsample

            until true
            j = k
        end
    end

    -- now sort the edges by their highest point (should snap to integer, and then by x)
    stbtt__sort_edges_range(e, 1, n) -- [Luau] e[n + 1..] are y0 == nil sentinels, already last

    -- now, traverse the scanlines and find the intersections on each scanline, use xor winding rule
    stbtt__rasterize_sorted_edges(result, e, n, vsubsample, off_x, off_y)
end

--- @param points? stbtt__point[]
--- @param n       int
--- @param x       float
--- @param y       float
@native
local function stbtt__add_point(points, n, x, y)
    if points == nil then return end -- during first pass, it's unallocated
    points[n + 1].x = x
    points[n + 1].y = y
end

-- tessellate until threshold p is happy... @TODO warped to compensate for non-linear stretching
--- @param points?                   stbtt__point[]
--- @param num_points                int
--- @param x0                        float
--- @param y0                        float
--- @param x1                        float
--- @param y1                        float
--- @param x2                        float
--- @param y2                        float
--- @param objspace_flatness_squared float
--- @param n                         int
--- @return int num_points # updated num_points passed in
@native
local function stbtt__tesselate_curve(points, num_points, x0, y0, x1, y1, x2, y2, objspace_flatness_squared, n)
    -- midpoint
    local mx = (x0 + 2 * x1 + x2) / 4
    local my = (y0 + 2 * y1 + y2) / 4
    -- versus directly drawn line
    local dx = (x0 + x2) / 2 - mx
    local dy = (y0 + y2) / 2 - my

    if n > 16 then -- 65536 segments on one curve better be enough!
        return num_points
    end

    if dx * dx + dy * dy > objspace_flatness_squared then -- half-pixel error allowed... need to be smaller if AA
        num_points = stbtt__tesselate_curve(points, num_points, x0, y0, (x0 + x1) / 2.0, (y0 + y1) / 2.0, mx, my, objspace_flatness_squared, n + 1)
        num_points = stbtt__tesselate_curve(points, num_points, mx, my, (x1 + x2) / 2.0, (y1 + y2) / 2.0, x2, y2, objspace_flatness_squared, n + 1)
    else
        stbtt__add_point(points, num_points, x2, y2)
        num_points = num_points + 1
    end

    return num_points
end

--- @param points?                   stbtt__point[]
--- @param num_points                int
--- @param x0                        float
--- @param y0                        float
--- @param x1                        float
--- @param y1                        float
--- @param x2                        float
--- @param y2                        float
--- @param x3                        float
--- @param y3                        float
--- @param objspace_flatness_squared float
--- @param n                         int
--- @return int num_points # updated num_points passed in
local function stbtt__tesselate_cubic(points, num_points, x0, y0, x1, y1, x2, y2, x3, y3, objspace_flatness_squared, n)
    -- @TODO this "flatness" calculation is just made-up nonsense that seems to work well enough
    local dx0 = x1 - x0
    local dy0 = y1 - y0
    local dx1 = x2 - x1
    local dy1 = y2 - y1
    local dx2 = x3 - x2
    local dy2 = y3 - y2
    local dx = x3 - x0
    local dy = y3 - y0
    local longlen = STBTT_sqrt(dx0 * dx0 + dy0 * dy0) + STBTT_sqrt(dx1 * dx1 + dy1 * dy1) + STBTT_sqrt(dx2 * dx2 + dy2 * dy2)
    local shortlen = STBTT_sqrt(dx * dx + dy * dy)
    local flatness_squared = longlen * longlen - shortlen * shortlen

    if n > 16 then -- 65536 segments on one curve better be enough!
        return num_points
    end

    if flatness_squared > objspace_flatness_squared then
        local x01 = (x0 + x1) / 2
        local y01 = (y0 + y1) / 2
        local x12 = (x1 + x2) / 2
        local y12 = (y1 + y2) / 2
        local x23 = (x2 + x3) / 2
        local y23 = (y2 + y3) / 2

        local xa = (x01 + x12) / 2
        local ya = (y01 + y12) / 2
        local xb = (x12 + x23) / 2
        local yb = (y12 + y23) / 2

        local mx = (xa + xb) / 2
        local my = (ya + yb) / 2

        num_points = stbtt__tesselate_cubic(points, num_points, x0, y0, x01, y01, xa, ya, mx, my, objspace_flatness_squared, n + 1)
        num_points = stbtt__tesselate_cubic(points, num_points, mx, my, xb, yb, x23, y23, x3, y3, objspace_flatness_squared, n + 1)
    else
        stbtt__add_point(points, num_points, x3, y3)
        num_points = num_points + 1
    end

    return num_points
end

-- returns number of contours
--- @param vertices          stbtt_vertex[]
--- @param num_verts         int
--- @param objspace_flatness float
--- @return stbtt__point[]? points
--- @return int?            num_contours
--- @return int[]?          contour_lengths
local flatten_points = {}
@native
local function stbtt_FlattenCurves(vertices, num_verts, objspace_flatness)
    local points = nil
    local num_points = 0

    local objspace_flatness_squared = objspace_flatness * objspace_flatness
    local n = 0
    local start = 0

    -- [Luau] vertex types and the current vertex in locals, stbtt__add_point() inlined (same values)
    local VTX_MOVE, VTX_LINE, VTX_CURVE, VTX_CUBIC = STBTT_VTX.MOVE, STBTT_VTX.LINE, STBTT_VTX.CURVE, STBTT_VTX.CUBIC

    -- count how many "moves" there are to get the contour count
    for i = 1, num_verts do
        if vertices[i].type == VTX_MOVE then
            n = n + 1
        end
    end

    local num_contours = n
    if n == 0 then return nil end

    local contour_lengths = {} -- [Port] size = n

    -- make two passes through the points so we don't need to realloc
    for pass = 0, 1 do
        local x, y = 0, 0
        if pass == 1 then
            points = flatten_points -- [Luau] reused across calls (only [1..num_points] is read)
            for i = #points + 1, num_points do points[i] = stbtt__point() end
        end
        num_points = 0
        n = -1
        for i = 1, num_verts do
            local v = vertices[i]
            local vtype = v.type
            if vtype == VTX_MOVE then
                -- start the next contour
                if n >= 0 then
                    contour_lengths[n + 1] = num_points - start
                end
                n = n + 1
                start = num_points

                x = v.x
                y = v.y
                num_points = num_points + 1
                if points then local pt = points[num_points]; pt.x = x; pt.y = y end -- stbtt__add_point()
            elseif vtype == VTX_LINE then
                x = v.x
                y = v.y
                num_points = num_points + 1
                if points then local pt = points[num_points]; pt.x = x; pt.y = y end -- stbtt__add_point()
            elseif vtype == VTX_CURVE then
                num_points = stbtt__tesselate_curve(points, num_points, x, y,
                                    v.cx, v.cy,
                                    v.x, v.y,
                                    objspace_flatness_squared, 0)
                x = v.x
                y = v.y
            elseif vtype == VTX_CUBIC then
                num_points = stbtt__tesselate_cubic(points, num_points, x, y,
                                    v.cx, v.cy,
                                    v.cx1, v.cy1,
                                    v.x, v.y,
                                    objspace_flatness_squared, 0)
                x = v.x
                y = v.y
            end
        end
        contour_lengths[n + 1] = num_points - start
    end

    return points, num_contours, contour_lengths
end

-- rasterize a shape with quadratic beziers into a bitmap
--- @param result             stbtt__bitmap
--- @param flatness_in_pixels float
--- @param vertices           stbtt_vertex[]
--- @param num_verts          int
--- @param scale_x            float
--- @param scale_y            float
--- @param shift_x            float
--- @param shift_y            float
--- @param x_off              int
--- @param y_off              int
--- @param invert             bool
@native
local function stbtt_Rasterize(result, flatness_in_pixels, vertices, num_verts, scale_x, scale_y, shift_x, shift_y, x_off, y_off, invert)
    local scale = (scale_x > scale_y) and scale_y or scale_x

    local windings, winding_count, winding_lengths = stbtt_FlattenCurves(vertices, num_verts, flatness_in_pixels / scale)

    if windings then
        --- @cast winding_lengths int[]
        --- @cast winding_count   int
        stbtt__rasterize(result, windings, winding_lengths, winding_count, scale_x, scale_y, shift_x, shift_y, x_off, y_off, invert)
    end
end

-- renders the glyph into storage you pass in for the bitmap,
-- in the form of 'output', with row spacing of 'out_stride' bytes. the bitmap
-- is clipped to out_w/out_h bytes. Call stbtt_GetGlyphBitmapBox to get the
-- width and height and positioning info for it first. You can also specify
-- a subpixel shift for the character.
--- @param info       stbtt_fontinfo
--- @param output     unsigned_char[]
--- @param out_w      int
--- @param out_h      int
--- @param out_stride int
--- @param scale_x    float
--- @param scale_y    float
--- @param shift_x    float
--- @param shift_y    float
--- @param glyph      int
@native
local function stbtt_MakeGlyphBitmapSubpixel(info, output, out_w, out_h, out_stride, scale_x, scale_y, shift_x, shift_y, glyph)
    local num_verts, vertices = stbtt_GetGlyphShape(info, glyph)
    local gbm = stbtt__bitmap()

    local ix0, iy0 = stbtt_GetGlyphBitmapBoxSubpixel(info, glyph, scale_x, scale_y, shift_x, shift_y)
    gbm.pixels = output
    gbm.w = out_w
    gbm.h = out_h
    gbm.stride = out_stride

    if gbm.w ~= 0 and gbm.h ~= 0 then
        stbtt_Rasterize(gbm, 0.35, vertices, num_verts, scale_x, scale_y, shift_x, shift_y, ix0, iy0, true)
    end
end

-----------------
-----------------
---
--- bitmap baking
---
---

--- UNIMPLEMENTED / UNUSED:
---     stbtt_BakeFontBitmap_internal
---     stbtt_BakeFontBitmap
---     stbtt_GetBakedQuad

---------------------------
---------------------------
---
--- bitmap baking / packing
---
---

--- UNIMPLEMENTED / UNUSED:
---     stbtt_PackBegin
---     stbtt_PackSetOversampling
---     stbtt_PackSetSkipMissingCodepoints
---     stbtt_PackFontRangesGatherRects
---     stbtt_PackFontRangesRenderIntoRects
---     stbtt_PackFontRangesPackRects
---     stbtt_PackFontRanges
---     stbtt_PackFontRange
---     stbtt_GetPackedQuad
---     stbtt_GetScaledFontVMetrics

local STBTT__OVER_MASK = STBTT_MAX_OVERSAMPLE - 1

--- @param pixels          table
--- @param w               int
--- @param h               int
--- @param stride_in_bytes int
--- @param kernel_width    unsigned_int
@native
local function stbtt__h_prefilter(pixels, w, h, stride_in_bytes, kernel_width)
    local buffer = {}
    local safe_w = w - kernel_width

    for j = 0, h - 1 do
        local total = 0
        local row_offset = j * stride_in_bytes

        for i = 1, kernel_width do buffer[i] = 0 end

        for i = 0, safe_w do
            total = total + pixels[row_offset + i + 1] - buffer[bit32.band(i, STBTT__OVER_MASK) + 1]
            buffer[bit32.band(i + kernel_width, STBTT__OVER_MASK) + 1] = pixels[row_offset + i + 1]
            pixels[row_offset + i + 1] = unsigned_char(total / kernel_width)
        end

        for i = safe_w + 1, w - 1 do
            STBTT_assert(pixels[row_offset + i + 1] == 0)
            total = total - buffer[bit32.band(i, STBTT__OVER_MASK) + 1]
            pixels[row_offset + i + 1] = unsigned_char(total / kernel_width)
        end
    end
end

--- @param pixels          table
--- @param w               int
--- @param h               int
--- @param stride_in_bytes int
--- @param kernel_width    unsigned_int
@native
local function stbtt__v_prefilter(pixels, w, h, stride_in_bytes, kernel_width)
    local buffer = {}
    local safe_h = h - kernel_width

    for j = 0, w - 1 do
        local total = 0
        local col_offset = j

        for i = 1, kernel_width do buffer[i] = 0 end

        for i = 0, safe_h do
            total = total + pixels[col_offset + i * stride_in_bytes + 1] - buffer[bit32.band(i, STBTT__OVER_MASK) + 1]
            buffer[bit32.band(i + kernel_width, STBTT__OVER_MASK) + 1] = pixels[col_offset + i * stride_in_bytes + 1]
            pixels[col_offset + i * stride_in_bytes + 1] = unsigned_char(total / kernel_width)
        end

        for i = safe_h + 1, h - 1 do
            STBTT_assert(pixels[col_offset + i * stride_in_bytes + 1] == 0)
            total = total - buffer[bit32.band(i, STBTT__OVER_MASK) + 1]
            pixels[col_offset + i * stride_in_bytes + 1] = unsigned_char(total / kernel_width)
        end
    end
end

--- @param oversample int
--- @return float
@native
local function stbtt__oversample_shift(oversample)
    if oversample == 0 then
        return 0.0
    end

    -- The prefilter is a box filter of width "oversample",
    -- which shifts phase by (oversample - 1)/2 pixels in
    -- oversampled space. We want to shift in the opposite
    -- direction to counter this.
    return -(oversample - 1) / (2.0 * oversample)
end

-- same as stbtt_MakeGlyphBitmapSubpixel, but prefiltering
-- is performed. Returns (sub_x, sub_y).
--- @param info        stbtt_fontinfo
--- @param output      unsigned_char[]
--- @param out_w       int
--- @param out_h       int
--- @param out_stride  int
--- @param scale_x     float
--- @param scale_y     float
--- @param shift_x     float
--- @param shift_y     float
--- @param prefilter_x int
--- @param prefilter_y int
--- @param glyph       int
@native
function stbtt_MakeGlyphBitmapSubpixelPrefilter(info, output, out_w, out_h, out_stride, scale_x, scale_y, shift_x, shift_y, prefilter_x, prefilter_y, glyph)
    stbtt_MakeGlyphBitmapSubpixel(info, output, out_w - (prefilter_x - 1), out_h - (prefilter_y - 1), out_stride, scale_x, scale_y, shift_x, shift_y, glyph)

    if prefilter_x > 1 then
        stbtt__h_prefilter(output, out_w, out_h, out_stride, prefilter_x)
    end

    if prefilter_y > 1 then
        stbtt__v_prefilter(output, out_w, out_h, out_stride, prefilter_y)
    end

    local sub_x, sub_y
    sub_x = stbtt__oversample_shift(prefilter_x)
    sub_y = stbtt__oversample_shift(prefilter_y)
    return sub_x, sub_y
end

-------------------
-------------------
---
--- sdf computation
---
---

--- UNIMPLEMENTED / UNUSED:
---     stbtt__ray_intersect_bezier
---     stbtt__compute_crossings_x
---     stbtt__cuberoot
---     stbtt__solve_cubic
---     stbtt_GetGlyphSDF
---     stbtt_GetCodepointSDF

-----------------------------------------------------
-----------------------------------------------------
---
--- Font name matching -- recommended not to use this
---
---

--- UNIMPLEMENTED / UNUSED:
---     stbtt__CompareUTF8toUTF16_bigendian_prefix
---     stbtt_CompareUTF8toUTF16_bigendian_internal
---     stbtt_GetFontNameString
---     stbtt__matchpair
---     stbtt__matches

-- Each .ttf/.ttc file may have more than one font. Each font has a sequential
-- index number starting from 0. Call this function to get the font offset for
-- a given index; it returns -1 if the index is out of range. A regular .ttf
-- file will only define one font and it always be at offset 0, so it will
-- return '0' for index 0, and -1 for all other indices.
--- @param data  table
--- @param index int
function stbtt_GetFontOffsetForIndex(data, index) return stbtt_GetFontOffsetForIndex_internal(data, index) end

-- Given an offset into the file that defines a font, this function builds
-- the necessary cached info for the rest of the system. You must allocate
-- the stbtt_fontinfo yourself (see stbtt_fontinfo()), and stbtt_InitFont will fill it out. You don't
-- need to do anything special to free it, because the contents are pure
-- value data with no additional data structures. Returns false on failure.
--- @param info   stbtt_fontinfo
--- @param data   table
--- @param offset int
function stbtt_InitFont(info, data, offset) return stbtt_InitFont_internal(info, data, offset) end

return {
    fontinfo = stbtt_fontinfo,

    InitFont                         = stbtt_InitFont,
    FindGlyphIndex                   = stbtt_FindGlyphIndex,
    MakeGlyphBitmapSubpixelPrefilter = stbtt_MakeGlyphBitmapSubpixelPrefilter,
    GetFontVMetrics                  = stbtt_GetFontVMetrics,
    GetGlyphBitmapBox                = stbtt_GetGlyphBitmapBox,
    GetGlyphBitmapBoxSubpixel        = stbtt_GetGlyphBitmapBoxSubpixel,
    GetGlyphHMetrics                 = stbtt_GetGlyphHMetrics,
    GetFontOffsetForIndex            = stbtt_GetFontOffsetForIndex,
    ScaleForPixelHeight              = stbtt_ScaleForPixelHeight
}
