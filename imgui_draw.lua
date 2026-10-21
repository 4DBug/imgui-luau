--- Dear ImGui WIP
-- (drawing and font code)

--
-- Index of this file:
--
-- [SECTION] STB libraries implementation
-- [SECTION] Style functions
-- [SECTION] ImDrawList
-- [SECTION] ImTriangulator, ImDrawList concave polygon fill
-- [SECTION] ImDrawListSplitter
-- [SECTION] ImDrawData
-- [SECTION] Helpers ShadeVertsXXX functions
-- [SECTION] ImFontConfig
-- [SECTION] ImFontAtlas, ImFontAtlasBuilder
-- [SECTION] ImFontAtlas: backend for stb_truetype
-- [SECTION] ImFontAtlas: glyph ranges helpers
-- [SECTION] ImFontGlyphRangesBuilder
-- [SECTION] ImFontBaked, ImFont
-- [SECTION] ImGui Internal Render Helpers
-- [SECTION] Decompression code
-- [SECTION] Default font data (ProggyClean.ttf)
-- [SECTION] Default font data (ProggyForever.ttf)
--

FONT_ATLAS_DEFAULT_TEX_DATA_W = 122 -- Actual texture will be 2 times that + 1 spacing.
FONT_ATLAS_DEFAULT_TEX_DATA_H = 27

local IM_DRAWLIST_TEX_LINES_WIDTH_MAX = 32 -- The maximum line width to bake anti-aliased textures for.

local writef64, writeu32, readf64, readu32 = buffer.writef64, buffer.writeu32, buffer.readf64, buffer.readu32
-- [Port] Write vertex i (1-based) of a VtxBuffer.Buf
local function WV(b, i, x, y, u, v, col)
    local o = (i - 1) * 36
    writef64(b, o, x); writef64(b, o + 8, y); writef64(b, o + 16, u); writef64(b, o + 24, v); writeu32(b, o + 32, col)
end

local IM_FONTGLYPH_INDEX_UNUSED    = 0xFFFF -- [Port] ((ImU16)-1)
local IM_FONTGLYPH_INDEX_NOT_FOUND = 0xFFFE -- [Port] ((ImU16)-2)

--- @param str string
--- @return table
--- @nodiscard
--- @package
local function str_to_table(str)
    local t = {} for i = 1, #str do t[i] = string.sub(str, i, i) end return t
end

--- @param buf  char[] # 1-based
--- @param base int    # 1-based start index
--- @param u32  ImU32
@native
local function write_u32(buf, base, u32)
    buf[base + 0] = bit32.band(u32, 0xFF)
    buf[base + 1] = bit32.band(bit32.rshift(u32, 8), 0xFF)
    buf[base + 2] = bit32.band(bit32.rshift(u32, 16), 0xFF)
    buf[base + 3] = bit32.band(bit32.rshift(u32, 24), 0xFF)
end

-- A work of art lies ahead! (. = white layer, X = black layer, others are blank)
-- The 2x2 white texels on the top left are the ones we'll use everywhere in Dear ImGui to render filled shapes.
-- (This is used when io.MouseDrawCursor = true)
local FONT_ATLAS_DEFAULT_TEX_DATA_PIXELS = str_to_table(
    "..-         -XXXXXXX-    X    -           X           -XXXXXXX          -          XXXXXXX-     XX          - XX       XX " ..
    "..-         -X.....X-   X.X   -          X.X          -X.....X          -          X.....X-    X..X         -X..X     X..X" ..
    "---         -XXX.XXX-  X...X  -         X...X         -X....X           -           X....X-    X..X         -X...X   X...X" ..
    "X           -  X.X  - X.....X -        X.....X        -X...X            -            X...X-    X..X         - X...X X...X " ..
    "XX          -  X.X  -X.......X-       X.......X       -X..X.X           -           X.X..X-    X..X         -  X...X...X  " ..
    "X.X         -  X.X  -XXXX.XXXX-       XXXX.XXXX       -X.X X.X          -          X.X X.X-    X..XXX       -   X.....X   " ..
    "X..X        -  X.X  -   X.X   -          X.X          -XX   X.X         -         X.X   XX-    X..X..XXX    -    X...X    " ..
    "X...X       -  X.X  -   X.X   -    XX    X.X    XX    -      X.X        -        X.X      -    X..X..X..XX  -     X.X     " ..
    "X....X      -  X.X  -   X.X   -   X.X    X.X    X.X   -       X.X       -       X.X       -    X..X..X..X.X -    X...X    " ..
    "X.....X     -  X.X  -   X.X   -  X..X    X.X    X..X  -        X.X      -      X.X        -XXX X..X..X..X..X-   X.....X   " ..
    "X......X    -  X.X  -   X.X   - X...XXXXXX.XXXXXX...X -         X.X   XX-XX   X.X         -X..XX........X..X-  X...X...X  " ..
    "X.......X   -  X.X  -   X.X   -X.....................X-          X.X X.X-X.X X.X          -X...X...........X- X...X X...X " ..
    "X........X  -  X.X  -   X.X   - X...XXXXXX.XXXXXX...X -           X.X..X-X..X.X           - X..............X-X...X   X...X" ..
    "X.........X -XXX.XXX-   X.X   -  X..X    X.X    X..X  -            X...X-X...X            -  X.............X-X..X     X..X" ..
    "X..........X-X.....X-   X.X   -   X.X    X.X    X.X   -           X....X-X....X           -  X.............X- XX       XX " ..
    "X......XXXXX-XXXXXXX-   X.X   -    XX    X.X    XX    -          X.....X-X.....X          -   X............X--------------" ..
    "X...X..X    ---------   X.X   -          X.X          -          XXXXXXX-XXXXXXX          -   X...........X -             " ..
    "X..X X..X   -       -XXXX.XXXX-       XXXX.XXXX       -------------------------------------    X..........X -             " ..
    "X.X  X..X   -       -X.......X-       X.......X       -    XX           XX    -           -    X..........X -             " ..
    "XX    X..X  -       - X.....X -        X.....X        -   X.X           X.X   -           -     X........X  -             " ..
    "      X..X  -       -  X...X  -         X...X         -  X..X           X..X  -           -     X........X  -             " ..
    "       XX   -       -   X.X   -          X.X          - X...XXXXXXXXXXXXX...X -           -     XXXXXXXXXX  -             " ..
    "-------------       -    X    -           X           -X.....................X-           -------------------             " ..
    "                    ----------------------------------- X...XXXXXXXXXXXXX...X -                                           " ..
    "                                                      -  X..X           X..X  -                                           " ..
    "                                                      -   X.X           X.X   -                                           " ..
    "                                                      -    XX           XX    -                                           "
)

local FONT_ATLAS_DEFAULT_TEX_CURSOR_DATA = {
    -- Pos ..........  Size .........  Offset .......
    { ImVec2(  0,  3), ImVec2(12, 19), ImVec2( 0,  0) }, -- ImGuiMouseCursor.Arrow
    { ImVec2( 13,  0), ImVec2( 7, 16), ImVec2( 1,  8) }, -- ImGuiMouseCursor.TextInput
    { ImVec2( 31,  0), ImVec2(23, 23), ImVec2(11, 11) }, -- ImGuiMouseCursor.ResizeAll
    { ImVec2( 21,  0), ImVec2( 9, 23), ImVec2( 4, 11) }, -- ImGuiMouseCursor.ResizeNS
    { ImVec2( 55, 18), ImVec2(23,  9), ImVec2(11,  4) }, -- ImGuiMouseCursor.ResizeEW
    { ImVec2( 73,  0), ImVec2(17, 17), ImVec2( 8,  8) }, -- ImGuiMouseCursor.ResizeNESW
    { ImVec2( 55,  0), ImVec2(17, 17), ImVec2( 8,  8) }, -- ImGuiMouseCursor.ResizeNWSE
    { ImVec2( 91,  0), ImVec2(17, 22), ImVec2( 5,  0) }, -- ImGuiMouseCursor.Hand
    { ImVec2(  0,  3), ImVec2(12, 19), ImVec2( 0,  0) }, -- ImGuiMouseCursor.Wait     -- Arrow + custom code in ImGui.RenderMouseCursor()
    { ImVec2(  0,  3), ImVec2(12, 19), ImVec2( 0,  0) }, -- ImGuiMouseCursor.Progress -- Arrow + custom code in ImGui.RenderMouseCursor()
    { ImVec2(109,  0), ImVec2(13, 15), ImVec2( 6,  7) }, -- ImGuiMouseCursor.NotAllowed
}

local MT = ImGui.GetMetatables()

-------------------------------------------------------------------------------
-- [SECTION] STB libraries implementation (for stb_truetype and stb_rect_pack)
-------------------------------------------------------------------------------

--- @module "imstb_rectpack"
local stbrp = IM_INCLUDE("imstb_rectpack.lua")

--- @module "imstb_truetype"
local stbtt = IM_INCLUDE("imstb_truetype.lua")

-------------------------------------------------------------------------------
-- [SECTION] Style functions
-------------------------------------------------------------------------------

--- @param a ImVec4
--- @param b ImVec4
--- @param t float
local function ImLerpV4V4F(a, b, t) return ImVec4(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, a.w + (b.w - a.w) * t) end

--- @param dst? ImGuiStyle
function ImGui.StyleColorsDark(dst)
    local style = dst and dst or ImGui.GetStyle()
    local colors = style.Colors

    colors[ImGuiCol.Text]                      = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[ImGuiCol.TextDisabled]              = ImVec4(0.50, 0.50, 0.50, 1.00)
    colors[ImGuiCol.WindowBg]                  = ImVec4(0.06, 0.06, 0.06, 0.94)
    colors[ImGuiCol.ChildBg]                   = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[ImGuiCol.PopupBg]                   = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[ImGuiCol.Border]                    = ImVec4(0.43, 0.43, 0.50, 0.50)
    colors[ImGuiCol.BorderShadow]              = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[ImGuiCol.FrameBg]                   = ImVec4(0.16, 0.29, 0.48, 0.54)
    colors[ImGuiCol.FrameBgHovered]            = ImVec4(0.26, 0.59, 0.98, 0.40)
    colors[ImGuiCol.FrameBgActive]             = ImVec4(0.26, 0.59, 0.98, 0.67)
    colors[ImGuiCol.TitleBg]                   = ImVec4(0.04, 0.04, 0.04, 1.00)
    colors[ImGuiCol.TitleBgActive]             = ImVec4(0.16, 0.29, 0.48, 1.00)
    colors[ImGuiCol.TitleBgCollapsed]          = ImVec4(0.00, 0.00, 0.00, 0.51)
    colors[ImGuiCol.MenuBarBg]                 = ImVec4(0.14, 0.14, 0.14, 1.00)
    colors[ImGuiCol.ScrollbarBg]               = ImVec4(0.02, 0.02, 0.02, 0.53)
    colors[ImGuiCol.ScrollbarGrab]             = ImVec4(0.31, 0.31, 0.31, 1.00)
    colors[ImGuiCol.ScrollbarGrabHovered]      = ImVec4(0.41, 0.41, 0.41, 1.00)
    colors[ImGuiCol.ScrollbarGrabActive]       = ImVec4(0.51, 0.51, 0.51, 1.00)
    colors[ImGuiCol.CheckMark]                 = ImVec4(0.26, 0.59, 0.98, 1.00)
    colors[ImGuiCol.CheckboxSelectedBg]        = ImLerpV4V4F(colors[ImGuiCol.FrameBg], colors[ImGuiCol.FrameBgHovered], 0.65)
    colors[ImGuiCol.SliderGrab]                = ImVec4(0.24, 0.52, 0.88, 1.00)
    colors[ImGuiCol.SliderGrabActive]          = ImVec4(0.26, 0.59, 0.98, 1.00)
    colors[ImGuiCol.Button]                    = ImVec4(0.26, 0.59, 0.98, 0.40)
    colors[ImGuiCol.ButtonHovered]             = ImVec4(0.26, 0.59, 0.98, 1.00)
    colors[ImGuiCol.ButtonActive]              = ImVec4(0.06, 0.53, 0.98, 1.00)
    colors[ImGuiCol.Header]                    = ImVec4(0.26, 0.59, 0.98, 0.31)
    colors[ImGuiCol.HeaderHovered]             = ImVec4(0.26, 0.59, 0.98, 0.80)
    colors[ImGuiCol.HeaderActive]              = ImVec4(0.26, 0.59, 0.98, 1.00)
    colors[ImGuiCol.Separator]                 = colors[ImGuiCol.Border]
    colors[ImGuiCol.SeparatorHovered]          = ImVec4(0.10, 0.40, 0.75, 0.78)
    colors[ImGuiCol.SeparatorActive]           = ImVec4(0.10, 0.40, 0.75, 1.00)
    colors[ImGuiCol.ResizeGrip]                = ImVec4(0.26, 0.59, 0.98, 0.20)
    colors[ImGuiCol.ResizeGripHovered]         = ImVec4(0.26, 0.59, 0.98, 0.67)
    colors[ImGuiCol.ResizeGripActive]          = ImVec4(0.26, 0.59, 0.98, 0.95)
    colors[ImGuiCol.InputTextCursor]           = colors[ImGuiCol.Text]
    colors[ImGuiCol.TabHovered]                = colors[ImGuiCol.HeaderHovered]
    colors[ImGuiCol.Tab]                       = ImLerpV4V4F(colors[ImGuiCol.Header],       colors[ImGuiCol.TitleBgActive], 0.80)
    colors[ImGuiCol.TabSelected]               = ImLerpV4V4F(colors[ImGuiCol.HeaderActive], colors[ImGuiCol.TitleBgActive], 0.60)
    colors[ImGuiCol.TabSelectedOverline]       = colors[ImGuiCol.HeaderActive]
    colors[ImGuiCol.TabDimmed]                 = ImLerpV4V4F(colors[ImGuiCol.Tab],          colors[ImGuiCol.TitleBg], 0.80)
    colors[ImGuiCol.TabDimmedSelected]         = ImLerpV4V4F(colors[ImGuiCol.TabSelected],  colors[ImGuiCol.TitleBg], 0.40)
    colors[ImGuiCol.TabDimmedSelectedOverline] = ImVec4(0.50, 0.50, 0.50, 0.00)
    colors[ImGuiCol.DockingPreview] = ImVec4(colors[ImGuiCol.HeaderActive].x, colors[ImGuiCol.HeaderActive].y, colors[ImGuiCol.HeaderActive].z, colors[ImGuiCol.HeaderActive].w * 0.7)
    colors[ImGuiCol.DockingEmptyBg] = ImVec4(0.20, 0.20, 0.20, 1.00)
    colors[ImGuiCol.PlotLines]                 = ImVec4(0.61, 0.61, 0.61, 1.00)
    colors[ImGuiCol.PlotLinesHovered]          = ImVec4(1.00, 0.43, 0.35, 1.00)
    colors[ImGuiCol.PlotHistogram]             = ImVec4(0.90, 0.70, 0.00, 1.00)
    colors[ImGuiCol.PlotHistogramHovered]      = ImVec4(1.00, 0.60, 0.00, 1.00)
    colors[ImGuiCol.TableHeaderBg]             = ImVec4(0.19, 0.19, 0.20, 1.00)
    colors[ImGuiCol.TableBorderStrong]         = ImVec4(0.31, 0.31, 0.35, 1.00)   -- Prefer using Alpha=1.0 here
    colors[ImGuiCol.TableBorderLight]          = ImVec4(0.23, 0.23, 0.25, 1.00)   -- Prefer using Alpha=1.0 here
    colors[ImGuiCol.TableRowBg]                = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[ImGuiCol.TableRowBgAlt]             = ImVec4(1.00, 1.00, 1.00, 0.06)
    colors[ImGuiCol.TextLink]                  = colors[ImGuiCol.HeaderActive]
    colors[ImGuiCol.TextSelectedBg]            = ImVec4(0.26, 0.59, 0.98, 0.35)
    colors[ImGuiCol.TreeLines]                 = colors[ImGuiCol.Border]
    colors[ImGuiCol.DragDropTarget]            = ImVec4(1.00, 1.00, 0.00, 0.90)
    colors[ImGuiCol.DragDropTargetBg]          = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[ImGuiCol.UnsavedMarker]             = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[ImGuiCol.NavCursor]                 = ImVec4(0.26, 0.59, 0.98, 1.00)
    colors[ImGuiCol.NavWindowingHighlight]     = ImVec4(1.00, 1.00, 1.00, 0.70)
    colors[ImGuiCol.NavWindowingDimBg]         = ImVec4(0.80, 0.80, 0.80, 0.20)
    colors[ImGuiCol.ModalWindowDimBg]          = ImVec4(0.80, 0.80, 0.80, 0.35)
end

--- @param dst? ImGuiStyle
function ImGui.StyleColorsClassic(dst)
    local style = dst and dst or ImGui.GetStyle()
    local colors = style.Colors

    colors[ImGuiCol.Text]                      = ImVec4(0.90, 0.90, 0.90, 1.00)
    colors[ImGuiCol.TextDisabled]              = ImVec4(0.60, 0.60, 0.60, 1.00)
    colors[ImGuiCol.WindowBg]                  = ImVec4(0.00, 0.00, 0.00, 0.85)
    colors[ImGuiCol.ChildBg]                   = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[ImGuiCol.PopupBg]                   = ImVec4(0.11, 0.11, 0.14, 0.92)
    colors[ImGuiCol.Border]                    = ImVec4(0.50, 0.50, 0.50, 0.50)
    colors[ImGuiCol.BorderShadow]              = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[ImGuiCol.FrameBg]                   = ImVec4(0.43, 0.43, 0.43, 0.39)
    colors[ImGuiCol.FrameBgHovered]            = ImVec4(0.47, 0.47, 0.69, 0.40)
    colors[ImGuiCol.FrameBgActive]             = ImVec4(0.42, 0.41, 0.64, 0.69)
    colors[ImGuiCol.TitleBg]                   = ImVec4(0.27, 0.27, 0.54, 0.83)
    colors[ImGuiCol.TitleBgActive]             = ImVec4(0.32, 0.32, 0.63, 0.87)
    colors[ImGuiCol.TitleBgCollapsed]          = ImVec4(0.40, 0.40, 0.80, 0.20)
    colors[ImGuiCol.MenuBarBg]                 = ImVec4(0.40, 0.40, 0.55, 0.80)
    colors[ImGuiCol.ScrollbarBg]               = ImVec4(0.20, 0.25, 0.30, 0.60)
    colors[ImGuiCol.ScrollbarGrab]             = ImVec4(0.40, 0.40, 0.80, 0.30)
    colors[ImGuiCol.ScrollbarGrabHovered]      = ImVec4(0.40, 0.40, 0.80, 0.40)
    colors[ImGuiCol.ScrollbarGrabActive]       = ImVec4(0.41, 0.39, 0.80, 0.60)
    colors[ImGuiCol.CheckMark]                 = ImVec4(0.90, 0.90, 0.90, 0.50)
    colors[ImGuiCol.CheckboxSelectedBg]        = ImLerpV4V4F(colors[ImGuiCol.FrameBg], colors[ImGuiCol.FrameBgActive], 0.65)
    colors[ImGuiCol.SliderGrab]                = ImVec4(1.00, 1.00, 1.00, 0.30)
    colors[ImGuiCol.SliderGrabActive]          = ImVec4(0.41, 0.39, 0.80, 0.60)
    colors[ImGuiCol.Button]                    = ImVec4(0.35, 0.40, 0.61, 0.62)
    colors[ImGuiCol.ButtonHovered]             = ImVec4(0.40, 0.48, 0.71, 0.79)
    colors[ImGuiCol.ButtonActive]              = ImVec4(0.46, 0.54, 0.80, 1.00)
    colors[ImGuiCol.Header]                    = ImVec4(0.40, 0.40, 0.90, 0.45)
    colors[ImGuiCol.HeaderHovered]             = ImVec4(0.45, 0.45, 0.90, 0.80)
    colors[ImGuiCol.HeaderActive]              = ImVec4(0.53, 0.53, 0.87, 0.80)
    colors[ImGuiCol.Separator]                 = ImVec4(0.50, 0.50, 0.50, 0.60)
    colors[ImGuiCol.SeparatorHovered]          = ImVec4(0.60, 0.60, 0.70, 1.00)
    colors[ImGuiCol.SeparatorActive]           = ImVec4(0.70, 0.70, 0.90, 1.00)
    colors[ImGuiCol.ResizeGrip]                = ImVec4(1.00, 1.00, 1.00, 0.10)
    colors[ImGuiCol.ResizeGripHovered]         = ImVec4(0.78, 0.82, 1.00, 0.60)
    colors[ImGuiCol.ResizeGripActive]          = ImVec4(0.78, 0.82, 1.00, 0.90)
    colors[ImGuiCol.InputTextCursor]           = colors[ImGuiCol.Text]
    colors[ImGuiCol.TabHovered]                = colors[ImGuiCol.HeaderHovered]
    colors[ImGuiCol.Tab]                       = ImLerpV4V4F(colors[ImGuiCol.Header],       colors[ImGuiCol.TitleBgActive], 0.80)
    colors[ImGuiCol.TabSelected]               = ImLerpV4V4F(colors[ImGuiCol.HeaderActive], colors[ImGuiCol.TitleBgActive], 0.60)
    colors[ImGuiCol.TabSelectedOverline]       = colors[ImGuiCol.HeaderActive]
    colors[ImGuiCol.TabDimmed]                 = ImLerpV4V4F(colors[ImGuiCol.Tab],          colors[ImGuiCol.TitleBg], 0.80)
    colors[ImGuiCol.TabDimmedSelected]         = ImLerpV4V4F(colors[ImGuiCol.TabSelected],  colors[ImGuiCol.TitleBg], 0.40)
    colors[ImGuiCol.TabDimmedSelectedOverline] = ImVec4(0.53, 0.53, 0.87, 0.00)
    colors[ImGuiCol.DockingPreview] = ImVec4(colors[ImGuiCol.Header].x, colors[ImGuiCol.Header].y, colors[ImGuiCol.Header].z, colors[ImGuiCol.Header].w * 0.7)
    colors[ImGuiCol.DockingEmptyBg] = ImVec4(0.20, 0.20, 0.20, 1.00)
    colors[ImGuiCol.PlotLines]                 = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[ImGuiCol.PlotLinesHovered]          = ImVec4(0.90, 0.70, 0.00, 1.00)
    colors[ImGuiCol.PlotHistogram]             = ImVec4(0.90, 0.70, 0.00, 1.00)
    colors[ImGuiCol.PlotHistogramHovered]      = ImVec4(1.00, 0.60, 0.00, 1.00)
    colors[ImGuiCol.TableHeaderBg]             = ImVec4(0.27, 0.27, 0.38, 1.00)
    colors[ImGuiCol.TableBorderStrong]         = ImVec4(0.31, 0.31, 0.45, 1.00)   -- Prefer using Alpha=1.0 here
    colors[ImGuiCol.TableBorderLight]          = ImVec4(0.26, 0.26, 0.28, 1.00)   -- Prefer using Alpha=1.0 here
    colors[ImGuiCol.TableRowBg]                = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[ImGuiCol.TableRowBgAlt]             = ImVec4(1.00, 1.00, 1.00, 0.07)
    colors[ImGuiCol.TextLink]                  = colors[ImGuiCol.HeaderActive]
    colors[ImGuiCol.TextSelectedBg]            = ImVec4(0.00, 0.00, 1.00, 0.35)
    colors[ImGuiCol.TreeLines]                 = colors[ImGuiCol.Border]
    colors[ImGuiCol.DragDropTarget]            = ImVec4(1.00, 1.00, 0.00, 0.90)
    colors[ImGuiCol.DragDropTargetBg]          = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[ImGuiCol.UnsavedMarker]             = ImVec4(0.90, 0.90, 0.90, 1.00)
    colors[ImGuiCol.NavCursor]                 = colors[ImGuiCol.HeaderHovered]
    colors[ImGuiCol.NavWindowingHighlight]     = ImVec4(1.00, 1.00, 1.00, 0.70)
    colors[ImGuiCol.NavWindowingDimBg]         = ImVec4(0.80, 0.80, 0.80, 0.20)
    colors[ImGuiCol.ModalWindowDimBg]          = ImVec4(0.20, 0.20, 0.20, 0.35)
end

-- Those light colors are better suited with a thicker font than the default one + FrameBorder
--- @param dst? ImGuiStyle
function ImGui.StyleColorsLight(dst)
    local style = dst and dst or ImGui.GetStyle()
    local colors = style.Colors

    colors[ImGuiCol.Text]                      = ImVec4(0.00, 0.00, 0.00, 1.00)
    colors[ImGuiCol.TextDisabled]              = ImVec4(0.60, 0.60, 0.60, 1.00)
    colors[ImGuiCol.WindowBg]                  = ImVec4(0.94, 0.94, 0.94, 1.00)
    colors[ImGuiCol.ChildBg]                   = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[ImGuiCol.PopupBg]                   = ImVec4(1.00, 1.00, 1.00, 0.98)
    colors[ImGuiCol.Border]                    = ImVec4(0.00, 0.00, 0.00, 0.30)
    colors[ImGuiCol.BorderShadow]              = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[ImGuiCol.FrameBg]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[ImGuiCol.FrameBgHovered]            = ImVec4(0.26, 0.59, 0.98, 0.40)
    colors[ImGuiCol.FrameBgActive]             = ImVec4(0.26, 0.59, 0.98, 0.67)
    colors[ImGuiCol.TitleBg]                   = ImVec4(0.96, 0.96, 0.96, 1.00)
    colors[ImGuiCol.TitleBgActive]             = ImVec4(0.82, 0.82, 0.82, 1.00)
    colors[ImGuiCol.TitleBgCollapsed]          = ImVec4(1.00, 1.00, 1.00, 0.51)
    colors[ImGuiCol.MenuBarBg]                 = ImVec4(0.86, 0.86, 0.86, 1.00)
    colors[ImGuiCol.ScrollbarBg]               = ImVec4(0.98, 0.98, 0.98, 0.53)
    colors[ImGuiCol.ScrollbarGrab]             = ImVec4(0.69, 0.69, 0.69, 0.80)
    colors[ImGuiCol.ScrollbarGrabHovered]      = ImVec4(0.49, 0.49, 0.49, 0.80)
    colors[ImGuiCol.ScrollbarGrabActive]       = ImVec4(0.49, 0.49, 0.49, 1.00)
    colors[ImGuiCol.CheckMark]                 = ImVec4(0.26, 0.59, 0.98, 1.00)
    colors[ImGuiCol.CheckboxSelectedBg]        = ImVec4(0.95, 0.97, 1.00, 1.00)
    colors[ImGuiCol.SliderGrab]                = ImVec4(0.26, 0.59, 0.98, 0.78)
    colors[ImGuiCol.SliderGrabActive]          = ImVec4(0.46, 0.54, 0.80, 0.60)
    colors[ImGuiCol.Button]                    = ImVec4(0.26, 0.59, 0.98, 0.40)
    colors[ImGuiCol.ButtonHovered]             = ImVec4(0.26, 0.59, 0.98, 1.00)
    colors[ImGuiCol.ButtonActive]              = ImVec4(0.06, 0.53, 0.98, 1.00)
    colors[ImGuiCol.Header]                    = ImVec4(0.26, 0.59, 0.98, 0.31)
    colors[ImGuiCol.HeaderHovered]             = ImVec4(0.26, 0.59, 0.98, 0.80)
    colors[ImGuiCol.HeaderActive]              = ImVec4(0.26, 0.59, 0.98, 1.00)
    colors[ImGuiCol.Separator]                 = ImVec4(0.39, 0.39, 0.39, 0.62)
    colors[ImGuiCol.SeparatorHovered]          = ImVec4(0.14, 0.44, 0.80, 0.78)
    colors[ImGuiCol.SeparatorActive]           = ImVec4(0.14, 0.44, 0.80, 1.00)
    colors[ImGuiCol.ResizeGrip]                = ImVec4(0.35, 0.35, 0.35, 0.17)
    colors[ImGuiCol.ResizeGripHovered]         = ImVec4(0.26, 0.59, 0.98, 0.67)
    colors[ImGuiCol.ResizeGripActive]          = ImVec4(0.26, 0.59, 0.98, 0.95)
    colors[ImGuiCol.InputTextCursor]           = colors[ImGuiCol.Text]
    colors[ImGuiCol.TabHovered]                = colors[ImGuiCol.HeaderHovered]
    colors[ImGuiCol.Tab]                       = ImLerpV4V4F(colors[ImGuiCol.Header],       colors[ImGuiCol.TitleBgActive], 0.90)
    colors[ImGuiCol.TabSelected]               = ImLerpV4V4F(colors[ImGuiCol.HeaderActive], colors[ImGuiCol.TitleBgActive], 0.60)
    colors[ImGuiCol.TabSelectedOverline]       = colors[ImGuiCol.HeaderActive]
    colors[ImGuiCol.TabDimmed]                 = ImLerpV4V4F(colors[ImGuiCol.Tab],          colors[ImGuiCol.TitleBg], 0.80)
    colors[ImGuiCol.TabDimmedSelected]         = ImLerpV4V4F(colors[ImGuiCol.TabSelected],  colors[ImGuiCol.TitleBg], 0.40)
    colors[ImGuiCol.TabDimmedSelectedOverline] = ImVec4(0.26, 0.59, 1.00, 0.00)
    colors[ImGuiCol.DockingPreview] = ImVec4(colors[ImGuiCol.Header].x, colors[ImGuiCol.Header].y, colors[ImGuiCol.Header].z, colors[ImGuiCol.Header].w * 0.7)
    colors[ImGuiCol.DockingEmptyBg] = ImVec4(0.68, 0.69, 0.73, 1.00)
    colors[ImGuiCol.PlotLines]                 = ImVec4(0.39, 0.39, 0.39, 1.00)
    colors[ImGuiCol.PlotLinesHovered]          = ImVec4(1.00, 0.43, 0.35, 1.00)
    colors[ImGuiCol.PlotHistogram]             = ImVec4(0.90, 0.70, 0.00, 1.00)
    colors[ImGuiCol.PlotHistogramHovered]      = ImVec4(1.00, 0.45, 0.00, 1.00)
    colors[ImGuiCol.TableHeaderBg]             = ImVec4(0.78, 0.87, 0.98, 1.00)
    colors[ImGuiCol.TableBorderStrong]         = ImVec4(0.57, 0.57, 0.64, 1.00)   -- Prefer using Alpha=1.0 here
    colors[ImGuiCol.TableBorderLight]          = ImVec4(0.68, 0.68, 0.74, 1.00)   -- Prefer using Alpha=1.0 here
    colors[ImGuiCol.TableRowBg]                = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[ImGuiCol.TableRowBgAlt]             = ImVec4(0.30, 0.30, 0.30, 0.09)
    colors[ImGuiCol.TextLink]                  = colors[ImGuiCol.HeaderActive]
    colors[ImGuiCol.TextSelectedBg]            = ImVec4(0.26, 0.59, 0.98, 0.35)
    colors[ImGuiCol.TreeLines]                 = colors[ImGuiCol.Border]
    colors[ImGuiCol.DragDropTarget]            = ImVec4(0.26, 0.59, 0.98, 0.95)
    colors[ImGuiCol.DragDropTargetBg]          = ImVec4(0.00, 0.00, 0.00, 0.00)
    colors[ImGuiCol.UnsavedMarker]             = ImVec4(0.00, 0.00, 0.00, 1.00)
    colors[ImGuiCol.NavCursor]                 = colors[ImGuiCol.HeaderHovered]
    colors[ImGuiCol.NavWindowingHighlight]     = ImVec4(0.70, 0.70, 0.70, 0.70)
    colors[ImGuiCol.NavWindowingDimBg]         = ImVec4(0.20, 0.20, 0.20, 0.20)
    colors[ImGuiCol.ModalWindowDimBg]          = ImVec4(0.20, 0.20, 0.20, 0.35)
end

-------------------------------------------------------------------------------
-- [SECTION] Helpers ShadeVertsXXX functions
-------------------------------------------------------------------------------

-- Generic linear color gradient, write to RGB fields, leave A untouched.
--- @param draw_list      ImDrawList
--- @param vert_start_idx int
--- @param vert_end_idx   int
--- @param gradient_p0    ImVec2
--- @param gradient_p1    ImVec2
--- @param col0           ImU32
--- @param col1           ImU32
function ImGui.ShadeVertsLinearColorGradientKeepAlpha(draw_list, vert_start_idx, vert_end_idx, gradient_p0, gradient_p1, col0, col1)
    local gradient_extent = gradient_p1 - gradient_p0
    local gradient_inv_length2 = 1.0 / ImLengthSqr(gradient_extent)

    local col0_r = bit32.band(bit32.rshift(col0, IM_COL32_R_SHIFT), 0xFF)
    local col0_g = bit32.band(bit32.rshift(col0, IM_COL32_G_SHIFT), 0xFF)
    local col0_b = bit32.band(bit32.rshift(col0, IM_COL32_B_SHIFT), 0xFF)

    local col_delta_r = bit32.band(bit32.rshift(col1, IM_COL32_R_SHIFT), 0xFF) - col0_r
    local col_delta_g = bit32.band(bit32.rshift(col1, IM_COL32_G_SHIFT), 0xFF) - col0_g
    local col_delta_b = bit32.band(bit32.rshift(col1, IM_COL32_B_SHIFT), 0xFF) - col0_b

    for vert_idx = vert_start_idx, vert_end_idx - 1 do
        local vb = draw_list.VtxBuffer.Buf
        local o = (vert_idx - 1) * 36
        local d = (readf64(vb, o) - gradient_p0.x) * gradient_extent.x + (readf64(vb, o + 8) - gradient_p0.y) * gradient_extent.y
        local t = ImClamp(d * gradient_inv_length2, 0.0, 1.0)

        local r = math.floor(col0_r + col_delta_r * t)
        local g = math.floor(col0_g + col_delta_g * t)
        local b = math.floor(col0_b + col_delta_b * t)

        writeu32(vb, o + 32, bit32.bor(bit32.lshift(r, IM_COL32_R_SHIFT), bit32.lshift(g, IM_COL32_G_SHIFT), bit32.lshift(b, IM_COL32_B_SHIFT), bit32.band(readu32(vb, o + 32), IM_COL32_A_MASK)))
    end
end

-- [Port] Rotate and translate vertices [vert_start_idx, vert_end_idx) (1-based, like _VtxCurrentIdx)
function ImGui.ShadeVertsTransformPos(draw_list, vert_start_idx, vert_end_idx, pivot_in, cos_a, sin_a, pivot_out)
    local data = draw_list.VtxBuffer.Buf
    local pix, piy, pox, poy = pivot_in.x, pivot_in.y, pivot_out.x, pivot_out.y
    for i = vert_start_idx, vert_end_idx - 1 do
        local o = (i - 1) * 36
        local x, y = readf64(data, o) - pix, readf64(data, o + 8) - piy
        writef64(data, o, x * cos_a - y * sin_a + pox)
        writef64(data, o + 8, x * sin_a + y * cos_a + poy)
    end
end

-- Distribute UV over (a, b) rectangle
--- @param draw_list      ImDrawList
--- @param vert_start_idx int
--- @param vert_end_idx   int
--- @param a              ImVec2
--- @param b              ImVec2
--- @param uv_a           ImVec2
--- @param uv_b           ImVec2
--- @param clamp          bool
function ImGui.ShadeVertsLinearUV(draw_list, vert_start_idx, vert_end_idx, a, b, uv_a, uv_b, clamp)
    local size = b - a
    local uv_size = uv_b - uv_a
    local scale = ImVec2(
        (size.x ~= 0.0) and (uv_size.x / size.x) or 0.0,
        (size.y ~= 0.0) and (uv_size.y / size.y) or 0.0
    )

    local vertex
    local verts = draw_list.VtxBuffer.Buf
    if clamp then
        local min = ImMin(uv_a, uv_b)
        local max = ImMax(uv_a, uv_b)
        for vert_idx = vert_start_idx, vert_end_idx - 1 do
            local o = (vert_idx - 1) * 36
            local uv = ImClamp(uv_a + ImMul(ImVec2(readf64(verts, o), readf64(verts, o + 8)) - a, scale), min, max)
            writef64(verts, o + 16, uv.x); writef64(verts, o + 24, uv.y)
        end
    else
        for vert_idx = vert_start_idx, vert_end_idx - 1 do
            local o = (vert_idx - 1) * 36
            local uv = uv_a + ImMul(ImVec2(readf64(verts, o), readf64(verts, o + 8)) - a, scale)
            writef64(verts, o + 16, uv.x); writef64(verts, o + 24, uv.y)
        end
    end
end

--- Forward Declarations
local ImFontAtlasTextureAdd
local ImFontAtlasTextureGrow
local ImFontAtlasTextureGetSizeEstimate
local ImFontAtlasTextureBlockCopy
local ImFontAtlasTextureBlockConvert
local ImFontAtlasTextureBlockPostProcess
local ImFontAtlasTextureBlockPostProcessMultiply
local ImFontAtlasTextureBlockQueueUpload
local ImFontAtlasTextureCompact
local ImFontAtlasPackInit
local ImFontAtlasPackAddRect
local ImFontAtlasPackGetRect
local ImFontAtlasPackGetRectSafe
local ImFontAtlasBakedAdd
local ImFontAtlasBakedAddFontGlyph
local ImFontAtlasBakedAddFontGlyphAdvancedX
local ImFontAtlasBakedDiscard
local ImFontAtlasBakedGetOrAdd
local ImFontAtlasBakedGetId
local ImFontAtlasBakedGetClosestMatch
local ImFontAtlasBuildInit
local ImFontAtlasBuildSetTexture
local ImFontAtlasBuildUpdateTexDataLines
local ImFontAtlasBuildUpdateTexDataCorners
local ImFontAtlasBuildUpdateTexDataBasic
local IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC -- [Luau] forward declared, defined in [SECTION] ImDrawList
local CalcCornerArcStepAndCount            -- [Luau] forward declared, defined in [SECTION] ImDrawList
local ImFontAtlasBuildSetupFontLoader
local ImFontAtlasBuildSetupFontSpecialGlyphs
local ImFontAtlasBuildSetupFontBakedBlanks
local ImFontAtlasBuildSetupFontBakedEllipsis
local ImFontAtlasBuildSetupFontBakedFallback
local ImFontAtlasBuildDestroy
local ImFontAtlasBuildAcceptCodepointForSource
local ImFontAtlasBuildNotifySetFont
local ImFontAtlasBuildRenderBitmapFromString
local ImFontAtlasFontSourceInit
local ImFontAtlasFontSourceAddToFont
local ImFontAtlasFontDestroySourceData
local ImFontAtlasFontDestroyOutput

local ImFontBaked_BuildGrowIndex
local ImFontBaked_BuildLoadGlyph
local ImFontBaked_BuildLoadGlyphAdvanceX

local ImTextInitClassifiers
local ImTextClassifierGet
local ImTextClassifierClear
local ImTextClassifierSetCharClass
local ImTextClassifierSetCharClassFromStr

local ImTextureDataGetFormatBytesPerPixel

-------------------------------------------------------------------------------
-- [SECTION] ImFontAtlas, ImFontAtlasBuilder
-------------------------------------------------------------------------------
-- - Default texture data encoded in ASCII
-- - ImFontAtlas()
-- - ImFontAtlas:Clear()
-- - ImFontAtlas:ClearFonts()
-- - ImFontAtlas:ClearInputData()
-- - ImFontAtlas:ClearTexData()
-- - ImFontAtlas:CompactCache()
-- - ImFontAtlas:SetFontLoader()
-------------------------------------------------------------------------------
-- - ImFontAtlasUpdateNewFrame()
-- - ImFontAtlasTextureBlockConvert()
-- - ImFontAtlasTextureBlockPostProcess()
-- - ImFontAtlasTextureBlockPostProcessMultiply()
-- - ImFontAtlasTextureBlockFill()
-- - ImFontAtlasTextureBlockCopy()
-- - ImFontAtlasTextureBlockQueueUpload()
-------------------------------------------------------------------------------
-- - ImFontAtlas:GetTexDataAsAlpha8() [legacy]
-- - ImFontAtlas:GetTexDataAsRGBA32() [legacy]
-- - ImFontAtlas:Build() [legacy]
-------------------------------------------------------------------------------
-- - ImFontAtlas:AddFont()
-- - ImFontAtlas:AddFontDefault()
-- - ImFontAtlas:AddFontDefaultBitmap()
-- - ImFontAtlas:AddFontDefaultVector()
-- - ImFontAtlas:AddFontFromFileTTF()
-- - ImFontAtlas:AddFontFromMemoryTTF()
-- - ImFontAtlas:AddFontFromMemoryCompressedTTF()
-- - ImFontAtlas:AddFontFromMemoryCompressedBase85TTF()
-- - ImFontAtlas:RemoveFont()
-- - ImFontAtlasBuildNotifySetFont()
-------------------------------------------------------------------------------
-- - ImFontAtlas:AddCustomRect()
-- - ImFontAtlas:RemoveCustomRect()
-- - ImFontAtlas:GetCustomRect()
-- - ImFontAtlas:AddCustomRectFontGlyph() [legacy]
-- - ImFontAtlas:AddCustomRectFontGlyphForSize() [legacy]
-- - ImFontAtlasGetMouseCursorTexData()
-------------------------------------------------------------------------------
-- - ImFontAtlasBuildMain()
-- - ImFontAtlasBuildSetupFontLoader()
-- - ImFontAtlasBuildPreloadAllGlyphRanges()
-- - ImFontAtlasBuildUpdatePointers()
-- - ImFontAtlasBuildRenderBitmapFromString()
-- - ImFontAtlasBuildAddFont()
-- - ImFontAtlasBuildSetupFontBakedEllipsis()
-- - ImFontAtlasBuildSetupFontBakedBlanks()
-- - ImFontAtlasBuildSetupFontBakedFallback()
-- - ImFontAtlasBuildSetupFontSpecialGlyphs()
-- - ImFontAtlasBuildDiscardBakes()
-- - ImFontAtlasBuildDiscardFontBakedGlyph()
-- - ImFontAtlasBuildDiscardFontBaked()
-- - ImFontAtlasBuildDiscardFontBakes()
-------------------------------------------------------------------------------
-- - ImFontAtlasAddDrawListSharedData()
-- - ImFontAtlasRemoveDrawListSharedData()
-- - ImFontAtlasUpdateDrawListsTextures()
-- - ImFontAtlasUpdateDrawListsSharedData()
-------------------------------------------------------------------------------
-- - ImFontAtlasBuildSetTexture()
-- - ImFontAtlasBuildUpdateTexData()
-- - ImFontAtlasTextureAdd()
-- - ImFontAtlasTextureRepack()
-- - ImFontAtlasTextureGrow()
-- - ImFontAtlasTextureMakeSpace()
-- - ImFontAtlasTextureGetSizeEstimate()
-- - ImFontAtlasBuildClear()
-- - ImFontAtlasTextureCompact()
-- - ImFontAtlasBuildInit()
-- - ImFontAtlasBuildDestroy()
-------------------------------------------------------------------------------
-- - ImFontAtlasPackInit()
-- - ImFontAtlasPackAllocRectEntry()
-- - ImFontAtlasPackReuseRectEntry()
-- - ImFontAtlasPackDiscardRect()
-- - ImFontAtlasPackAddRect()
-- - ImFontAtlasPackGetRect()
-------------------------------------------------------------------------------
-- - ImFontBaked_BuildGrowIndex()
-- - ImFontBaked_BuildLoadGlyph()
-- - ImFontBaked_BuildLoadGlyphAdvanceX()
-- - ImFontAtlasDebugLogTextureRequests()
-------------------------------------------------------------------------------
-- - ImFontAtlasGetFontLoaderForStbTruetype()
-------------------------------------------------------------------------------

-- You probably should not call this directly. It is not well specified.
-- If you want to replace all your fonts mid-frame, most likely you should instead call ClearFonts() then load the new fonts.
-- Calling this mid-frame will discard the CPU-side copy of the texture data which is generally unreliable as you may have textures queued for creation or updates.
function MT.ImFontAtlas:Clear()
    IMGUI_DEBUG_LOG_FONT("[font] ImFontAtlas:Clear()")
    local backup_renderer_has_textures = self.RendererHasTextures
    self.RendererHasTextures = false -- Full Clear() is supported, but ClearTexData() only isn't.
    self:ClearFonts()
    self:ClearTexData()
    self.RendererHasTextures = backup_renderer_has_textures
end

function MT.ImFontAtlas:SetFontLoader(font_loader)
    ImFontAtlasBuildSetupFontLoader(self, font_loader)
end

function MT.ImFontAtlas:ClearInputData()
    IM_ASSERT(not self.Locked, "Cannot modify a locked ImFontAtlas!")

    for _, font in self.Fonts:iter() do
        ImFontAtlasFontDestroyOutput(self, font)
    end
    for _, font_cfg in self.Sources:iter() do
        ImFontAtlasFontDestroySourceData(self, font_cfg)
    end
    for _, font in self.Fonts:iter() do
        -- When clearing this we lose access to the font name and other information used to build the font.
        font.Sources:clear()
        font.Flags = bit32.bor(font.Flags, ImFontFlags.NoLoadGlyphs)
    end
    self.Sources:clear()
end

-- Clear CPU-side copy of the texture data.
function MT.ImFontAtlas:ClearTexData()
    IM_ASSERT(not self.Locked, "Cannot modify a locked ImFontAtlas!")
    IM_ASSERT(self.RendererHasTextures == false, "Not supported for dynamic atlases, but you may call Clear().")

    for _, tex in self.TexList:iter() do
        tex:DestroyPixels()
    end
    --self.Locked = true -- Hoped to be able to lock this down but some reload patterns may not be happy with it.
end

function MT.ImFontAtlas:CompactCache()
    ImFontAtlasTextureCompact(self)
end

function MT.ImFontAtlas:ClearFonts()
    -- FIXME-NEWATLAS: Illegal to remove currently bound font.
    IMGUI_DEBUG_LOG_FONT("[font] ImFontAtlas:ClearFonts()")
    IM_ASSERT(not self.Locked, "Cannot modify a locked ImFontAtlas!")

    for _, font in self.Fonts:iter() do
        ImFontAtlasBuildNotifySetFont(self, font, nil)
    end

    ImFontAtlasBuildDestroy(self)
    self:ClearInputData()
    self.Fonts:clear_delete()
    self.TexIsBuilt = false

    for _, shared_data in self.DrawListSharedDatas:iter() do
        if shared_data.FontAtlas == self then
            shared_data.Font = nil
            shared_data.FontSize = 0.0
            shared_data.FontScale = 0.0
        end
    end
end

-- [Luau] Pixels of the last atlas texture removed after the backend destroyed it: the next ImTextureData:Create() of
-- the same byte size (atlas repack: same size every time) zero-fills and reuses it instead of allocating a new table
local RecycledTexPixels, RecycledTexPixelsSize = nil, 0

--- @param tex ImTextureData
function ImTextureDataUpdateNewFrame(tex)
    local remove_from_list = false
    if tex.Status == ImTextureStatus.OK then
        tex.Updates:resize(0)
        tex.UpdateRect.x = 65535 tex.UpdateRect.y = 65535
        tex.UpdateRect.w = 0     tex.UpdateRect.h = 0
    end

    -- Request destroy
    -- - Keep bool to true in order to differentiate a planned destroy vs a destroy decided by the backend.
    -- - We don't destroy pixels right away, as backend may have an in-flight copy from RAM.
    if (tex.WantDestroyNextFrame and tex.Status ~= ImTextureStatus.Destroyed and tex.Status ~= ImTextureStatus.WantDestroy) then
        IM_ASSERT(tex.Status == ImTextureStatus.OK or tex.Status == ImTextureStatus.WantCreate or tex.Status == ImTextureStatus.WantUpdates)
        tex.Status = ImTextureStatus.WantDestroy
    end

    -- If a texture has never reached the backend, they don't need to know about it.
    -- (note: backends between 1.92.0 and 1.92.4 could set an already destroyed texture to ImTextureStatus.WantDestroy
    --  when invalidating graphics objects twice, which would previously remove it from the list and crash.)
    if (tex.Status == ImTextureStatus.WantDestroy and tex.TexID == ImTextureID_Invalid and tex.BackendUserData == nil and tex.QueueUserData == nil) then
        tex.Status = ImTextureStatus.Destroyed
    end

    -- Process texture being destroyed
    if (tex.Status == ImTextureStatus.Destroyed) then
        IM_ASSERT(tex.TexID == ImTextureID_Invalid and tex.BackendUserData == nil, "Backend set texture Status to Destroyed but did not clear TexID/BackendUserData!")
        IM_ASSERT(tex.QueueUserData == nil, "Texture queue set Status to Destroyed but did not clear QueueUserData!")
        if (tex.WantDestroyNextFrame) then
            remove_from_list = true -- Destroy was scheduled by us
        else
            tex.Status = ImTextureStatus.WantCreate -- Destroy was done was backend: recreate it (e.g. freed resources mid-run)
        end
    end

    -- The backend may need defer destroying by a few frames, to handle texture used by previous in-flight rendering.
    -- We allow the texture staying in _WantDestroy state and increment a counter which the backend can use to take its decision.
    if (tex.Status == ImTextureStatus.WantDestroy) then
        tex.UnusedFrames = tex.UnusedFrames + 1
    end

    return remove_from_list
end

-- Called by NewFrame() for atlases owned by a context.
-- If you manually manage font atlases, you'll need to call this yourself.
-- - 'frame_count' needs to be provided because we can gc/prioritize baked fonts based on their age.
-- - 'frame_count' may not match those of all imgui contexts using this atlas, as contexts may be updated as different frequencies. But generally you can use ImGui.GetFrameCount() on one of your context.
--- @param atlas                 ImFontAtlas
--- @param frame_count           int
--- @param renderer_has_textures any
function ImFontAtlasUpdateNewFrame(atlas, frame_count, renderer_has_textures)
    IM_ASSERT(atlas.Builder == nil or atlas.Builder.FrameCount < frame_count) -- Protection against being called twice.
    atlas.RendererHasTextures = renderer_has_textures

    -- Update texture status and discard old textures.
    -- (we do this first thing to handle an edge case: if user mistakenly calls ClearFonts()+SetStatus(OK) during
    --  rendering, it would ImFontAtlasBuildMain() rebuilding before tex.Updates[] gets a chance to be cleared)
    -- (if somehow we need to move this back lower in the function, we could manually call the code to clear Updates[]).
    local tex_n = 1
    while tex_n <= atlas.TexList.Size do
        -- Update and remove if requested
        local tex = atlas.TexList.Data[tex_n]

        if (tex.Status == ImTextureStatus.WantCreate and atlas.RendererHasTextures) then
            IM_ASSERT(tex.TexID == ImTextureID_Invalid and tex.BackendUserData == nil, "Backend set texture's TexID/BackendUserData but did not update Status to OK.")
        end

        local remove_from_list = ImTextureDataUpdateNewFrame(tex)

        if remove_from_list then
            IM_ASSERT(atlas.TexData ~= tex)
            if tex.Pixels ~= nil then
                RecycledTexPixels, RecycledTexPixelsSize = tex.Pixels, tex.Width * tex.Height * tex.BytesPerPixel
            end
            tex:DestroyPixels()
            atlas.TexList:erase(tex_n)
            tex_n = tex_n - 1
        end

        tex_n = tex_n + 1
    end

    -- Check that font atlas was built or backend support texture reload in which case we can build now
    if (atlas.RendererHasTextures) then
        atlas.TexIsBuilt = true
        if (atlas.Builder == nil) then -- This will only happen if fonts were not already loaded.
            ImFontAtlasBuildMain(atlas)
        end
    end
    -- Legacy backend
    if (not atlas.RendererHasTextures) then
        IM_ASSERT_USER_ERROR(atlas.TexIsBuilt, "Backend does not support ImGuiBackendFlags.RendererHasTextures, and font atlas is not built! Update backend OR make sure you called ImGui_ImplXXXX_NewFrame() function for renderer backend, which should call io.Fonts->GetTexDataAsRGBA32() / GetTexDataAsAlpha8().")
    end
    if (atlas.TexIsBuilt and atlas.Builder.PreloadedAllGlyphsRanges) then
        IM_ASSERT_USER_ERROR(atlas.RendererHasTextures == false, "Called ImFontAtlas::Build() before ImGuiBackendFlags.RendererHasTextures got set! With new backends: you don't need to call Build().")
    end

    -- Clear BakedCurrent cache, this is important because it ensure the uncached path gets taken once.
    -- We also rely on ImFontBaked pointers never crossing frames.
    local builder = atlas.Builder
    builder.FrameCount = frame_count
    for _, font in atlas.Fonts:iter() do
        font.LastBaked = nil
    end

    -- Garbage collect BakedPool
    if builder.BakedDiscardedCount > 0 then
        local dst_n = 1

        for src_n = 1, builder.BakedPool.Size do
            repeat
            local p_src = builder.BakedPool.Data[src_n]
            if p_src.WantDestroy then
                break
            end

            local p_dst = builder.BakedPool.Data[dst_n]
            dst_n = dst_n + 1
            if p_dst == p_src then
                break
            end

            builder.BakedPool.Data[dst_n - 1] = p_src
            builder.BakedMap[p_src.BakedId] = p_src

            until true
        end

        IM_ASSERT(dst_n - 1 + builder.BakedDiscardedCount == builder.BakedPool.Size)

        builder.BakedPool.Size = builder.BakedPool.Size - builder.BakedDiscardedCount
        builder.BakedDiscardedCount = 0
    end
end

--- @param src_pixels      unsigned_char[]
--- @param src_fmt         ImTextureFormat
--- @param src_pitch       int
--- @param dst_pixels      unsigned_char[]
--- @param dst_pixels_base int
--- @param dst_fmt         ImTextureFormat
--- @param dst_pitch       int
--- @param w               int
--- @param h               int
@native
function ImFontAtlasTextureBlockConvert(src_pixels, src_fmt, src_pitch, dst_pixels, dst_pixels_base, dst_fmt, dst_pitch, w, h)
    IM_ASSERT(src_pixels ~= nil and dst_pixels ~= nil)
    local src_pixels_base = 1
    if src_fmt == dst_fmt then
        local line_sz = w * ImTextureDataGetFormatBytesPerPixel(src_fmt)
        for ny = h, 1, -1 do
            ImStd.memmove(dst_pixels, dst_pixels_base, src_pixels, src_pixels_base, line_sz)

            src_pixels_base = src_pixels_base + src_pitch
            dst_pixels_base = dst_pixels_base + dst_pitch
        end
    elseif src_fmt == ImTextureFormat.Alpha8 and dst_fmt == ImTextureFormat.RGBA32 then
        for ny = h, 1, -1 do
            for nx = w, 1, -1 do
                local alpha = src_pixels[src_pixels_base + 0]
                src_pixels_base = src_pixels_base + 1

                -- [Luau] inline write_u32(dst_pixels, dst_pixels_base, IM_COL32(255, 255, 255, alpha))
                dst_pixels[dst_pixels_base] = 255; dst_pixels[dst_pixels_base + 1] = 255; dst_pixels[dst_pixels_base + 2] = 255; dst_pixels[dst_pixels_base + 3] = alpha
                dst_pixels_base = dst_pixels_base + 4
            end

            src_pixels_base = src_pixels_base + (src_pitch - w)
            dst_pixels_base = dst_pixels_base + (dst_pitch - w * 4)
        end
    elseif src_fmt == ImTextureFormat.RGBA32 and dst_fmt == ImTextureFormat.Alpha8 then
        for ny = h, 1, -1 do
            for nx = w, 1, -1 do
                local alpha = src_pixels[src_pixels_base + 3]
                src_pixels_base = src_pixels_base + 4

                dst_pixels[dst_pixels_base + 0] = alpha
                dst_pixels_base = dst_pixels_base + 1
            end

            src_pixels_base = src_pixels_base + (src_pitch - w * 4)
            dst_pixels_base = dst_pixels_base + (dst_pitch - w)
        end
    else
        IM_ASSERT(false)
    end
end

-- Source buffer may be written to (used for in-place mods).
-- Post-process hooks may eventually be added here.
--- @param data ImFontAtlasPostProcessData
function ImFontAtlasTextureBlockPostProcess(data)
    -- Multiply operator (legacy)
    if data.FontSrc.RasterizerMultiply ~= 1.0 then
        ImFontAtlasTextureBlockPostProcessMultiply(data, data.FontSrc.RasterizerMultiply)
    end
end

--- @param data            ImFontAtlasPostProcessData
--- @param multiply_factor float
function ImFontAtlasTextureBlockPostProcessMultiply(data, multiply_factor)
    local pixels, pixels_base = data.Pixels, data._PixelsBase
    local pitch = data.Pitch
    if data.Format == ImTextureFormat.Alpha8 then
        for ny = data.Height, 1, -1 do
            local p = pixels_base
            for nx = data.Width, 1, -1 do
                local v = ImMin(ImFloor(pixels[p + 0] * multiply_factor), 255)
                pixels[p + 0] = v

                p = p + 1
            end

            pixels_base = pixels_base + pitch
        end
    elseif data.Format == ImTextureFormat.RGBA32 then
        for ny = data.Height, 1, -1 do
            local p = pixels_base
            for nx = data.Width, 1, -1 do
                local a = ImMin(ImFloor(pixels[p + 3] * multiply_factor), 255)

                write_u32(pixels, p, IM_COL32(pixels[p + 0], pixels[p + 1], pixels[p + 2], a))

                p = p + 4
            end

            pixels_base = pixels_base + pitch
        end
    else
        IM_ASSERT(false)
    end
end

-- Copy block from one texture to another
--- @param src_tex ImTextureData
--- @param src_x   int
--- @param src_y   int
--- @param dst_tex ImTextureData
--- @param dst_x   int
--- @param dst_y   int
--- @param w       int
--- @param h       int
function ImFontAtlasTextureBlockCopy(src_tex, src_x, src_y, dst_tex, dst_x, dst_y, w, h)
    IM_ASSERT(src_tex.Pixels ~= nil and dst_tex.Pixels ~= nil)
    IM_ASSERT(src_tex.Format == dst_tex.Format)
    IM_ASSERT(src_x >= 0 and src_x + w <= src_tex.Width)
    IM_ASSERT(src_y >= 0 and src_y + h <= src_tex.Height)
    IM_ASSERT(dst_x >= 0 and dst_x + w <= dst_tex.Width)
    IM_ASSERT(dst_y >= 0 and dst_y + h <= dst_tex.Height)
    for y = 0, h - 1 do
        local dst, dst_base = dst_tex:GetPixelsAt(dst_x, dst_y + y)
        local src, src_base = src_tex:GetPixelsAt(src_x, src_y + y)
        ImStd.memmove(dst, dst_base, src, src_base, w * dst_tex.BytesPerPixel)
    end
end

--- @param dst_tex ImTextureData
--- @param col     ImU32
function ImFontAtlasTextureBlockFill(dst_tex, dst_x, dst_y, w, h, col)
    if dst_tex.Format == ImTextureFormat.Alpha8 then
        local col_a = bit32.band(bit32.rshift(col, IM_COL32_A_SHIFT), 0xFF)
        for y = 0, h - 1 do
            local p, base = dst_tex:GetPixelsAt(dst_x, dst_y + y)
            for i = base, base + w - 1 do p[i] = col_a end
        end
    else
        -- [Luau] Pixels is a byte table: write the 4 bytes of the little-endian ImU32
        local c0, c1, c2, c3 = bit32.band(col, 0xFF), bit32.band(bit32.rshift(col, 8), 0xFF), bit32.band(bit32.rshift(col, 16), 0xFF), bit32.band(bit32.rshift(col, 24), 0xFF)
        for y = 0, h - 1 do
            local p, i = dst_tex:GetPixelsAt(dst_x, dst_y + y)
            for _ = w, 1, -1 do
                p[i] = c0; p[i + 1] = c1; p[i + 2] = c2; p[i + 3] = c3
                i = i + 4
            end
        end
    end
end

-- Queue texture block update for renderer backend
--- @param tex   ImTextureData
--- @param x     int
--- @param y     int
--- @param w     int
--- @param h     int
local function ImTextureDataQueueUpload(tex, x, y, w, h)
    IM_ASSERT(tex.Status ~= ImTextureStatus.WantDestroy and tex.Status ~= ImTextureStatus.Destroyed)
    IM_ASSERT(x >= 0 and x <= 0xFFFF and y >= 0 and y <= 0xFFFF and w >= 0 and x + w <= 0x10000 and h >= 0 and y + h <= 0x10000)

    local req = ImTextureRect(x, y, w, h) -- (unsigned short)
    local new_x1 = ImMax(tex.UpdateRect.w == 0 and 0 or tex.UpdateRect.x + tex.UpdateRect.w, req.x + req.w)
    local new_y1 = ImMax(tex.UpdateRect.h == 0 and 0 or tex.UpdateRect.y + tex.UpdateRect.h, req.y + req.h)
    tex.UpdateRect.x = ImMin(tex.UpdateRect.x, req.x)
    tex.UpdateRect.y = ImMin(tex.UpdateRect.y, req.y)
    tex.UpdateRect.w = (new_x1 - tex.UpdateRect.x) -- (unsigned short)
    tex.UpdateRect.h = (new_y1 - tex.UpdateRect.y) -- (unsigned short)
    tex.UsedRect.x = ImMin(tex.UsedRect.x, req.x)
    tex.UsedRect.y = ImMin(tex.UsedRect.y, req.y)
    tex.UsedRect.w = (ImMax(tex.UsedRect.x + tex.UsedRect.w, req.x + req.w) - tex.UsedRect.x) -- (unsigned short)
    tex.UsedRect.h = (ImMax(tex.UsedRect.y + tex.UsedRect.h, req.y + req.h) - tex.UsedRect.y) -- (unsigned short)

    -- No need to queue if status is == ImTextureStatus.WantCreate
    if (tex.Status == ImTextureStatus.OK or tex.Status == ImTextureStatus.WantUpdates) then
        tex.Status = ImTextureStatus.WantUpdates
        tex.Updates:push_back(req)
    end
end

--- @param atlas ImFontAtlas
--- @param tex   ImTextureData
--- @param x     int
--- @param y     int
--- @param w     int
--- @param h     int
function ImFontAtlasTextureBlockQueueUpload(atlas, tex, x, y, w, h)
    ImTextureDataQueueUpload(tex, x, y, w, h)
    atlas.TexIsBuilt = false
end

-- Copy to texture, post-process and queue update for backend
--- @param atlas      ImFontAtlas
--- @param baked      ImFontBaked
--- @param src        ImFontConfig
--- @param glyph      ImFontGlyph
--- @param r          ImTextureRect
--- @param src_pixels unsigned_char[]
--- @param src_fmt    ImTextureFormat
--- @param src_pitch  int
local function ImFontAtlasBakedSetFontGlyphBitmap(atlas, baked, src, glyph, r, src_pixels, src_fmt, src_pitch)
    local tex = atlas.TexData
    IM_ASSERT(r.x + r.w <= tex.Width and r.y + r.h <= tex.Height)
    local out_p, out_p_base = tex:GetPixelsAt(r.x, r.y)
    IM_ASSERT(out_p ~= nil)
    ImFontAtlasTextureBlockConvert(src_pixels, src_fmt, src_pitch, out_p, out_p_base, tex.Format, tex:GetPitch(), r.w, r.h)
    local pp_data = ImFontAtlasPostProcessData(atlas, baked.OwnerFont, src, baked, glyph, out_p, out_p_base, tex.Format, tex:GetPitch(), r.w, r.h)
    ImFontAtlasTextureBlockPostProcess(pp_data)
    ImFontAtlasTextureBlockQueueUpload(atlas, tex, r.x, r.y, r.w, r.h)
end

local function ImFontAtlasBuildGetOversampleFactors(src, baked)
    -- (Only used by stb_truetype builder)
    -- Automatically disable horizontal oversampling over size 36
    local raster_size = baked.Size * baked.RasterizerDensity * src.RasterizerDensity
    local out_oversample_h
    if src.OversampleH ~= 0 then
        out_oversample_h = src.OversampleH
    elseif raster_size > 36.0 or src.PixelSnapH then
        out_oversample_h = 1
    else
        out_oversample_h = 2
    end
    local out_oversample_v = (src.OversampleV ~= 0) and src.OversampleV or 1
    return out_oversample_h, out_oversample_v
end

-- use unused_frames==0 to discard everything.
local function ImFontAtlasBuildDiscardBakes(atlas, unused_frames)
    local builder = atlas.Builder

    for baked_n = 1, builder.BakedPool.Size do
        repeat
        local baked = builder.BakedPool[baked_n]
        if (baked.LastUsedFrame + unused_frames > atlas.Builder.FrameCount) then
            break
        end

        if (baked.WantDestroy or (bit32.band(baked.OwnerFont.Flags, ImFontFlags.LockBakedSizes) ~= 0)) then
            break
        end

        ImFontAtlasBakedDiscard(atlas, baked.OwnerFont, baked)

        until true
    end
end

-- Those functions are designed to facilitate changing the underlying structures for ImFontAtlas to store an array of ImDrawListSharedData
--- @param atlas ImFontAtlas
--- @param data  ImDrawListSharedData
function ImFontAtlasAddDrawListSharedData(atlas, data)
    IM_ASSERT(not atlas.DrawListSharedDatas:contains(data))
    atlas.DrawListSharedDatas:push_back(data)
end

--- @param atlas ImFontAtlas
--- @param data  ImDrawListSharedData
function ImFontAtlasRemoveDrawListSharedData(atlas, data)
    IM_ASSERT(atlas.DrawListSharedDatas:contains(data))
    atlas.DrawListSharedDatas:find_erase(data)
end

-- [Luau] RectsIndex index of the entry the repack loop is re-adding: ImFontAtlasPackReuseRectEntry() checks it before
-- searching RectsIndex (index_from_ptr is a linear search: O(n^2) per repack otherwise)
local ImFontAtlasPackReuseIndexHint = nil

--- @param atlas ImFontAtlas
--- @param w     int
--- @param h     int
local function ImFontAtlasTextureRepack(atlas, w, h)
    local builder = atlas.Builder
    builder.LockDisableResize = true

    local old_tex = atlas.TexData
    local new_tex = ImFontAtlasTextureAdd(atlas, w, h)
    new_tex.UseColors = old_tex.UseColors

    IMGUI_DEBUG_LOG_FONT("[font] Texture #%03d: resize+repack %dx%d => Texture #%03d: %dx%d", old_tex.UniqueID, old_tex.Width, old_tex.Height, new_tex.UniqueID, new_tex.Width, new_tex.Height)
    --for baked_n = 1, builder.BakedPool.Size do
    --    IMGUI_DEBUG_LOG_FONT("[font] - Baked %.2fpx, %d glyphs, want_destroy=%d", builder.BakedPool[baked_n].FontSize, builder.BakedPool[baked_n].Glyphs.Size, builder.BakedPool[baked_n].WantDestroy)
    --end
    --IMGUI_DEBUG_LOG_FONT("[font] - Old packed rects: %d, area %d px", builder.RectsPackedCount, builder.RectsPackedSurface)
    --ImFontAtlasDebugWriteTexToDisk(old_tex, "Before Pack")

    -- Repack, lose discarded rectangle, copy pixels
    -- FIXME-NEWATLAS: This is unstable because packing order is based on RectsIndex
    -- FIXME-NEWATLAS-V2: Repacking in batch would be beneficial to packing heuristic, and fix stability.
    -- FIXME-NEWATLAS-TESTS: Test calling RepackTexture with size too small to fits existing rects.
    ImFontAtlasPackInit(atlas)
    local old_rects = ImVector()
    local old_index = builder.RectsIndex:copy()
    old_rects:swap(builder.Rects)

    for index_n, index_entry in builder.RectsIndex:iter() do
        repeat
        if index_entry.IsUsed == false then
            break
        end

        local old_r = old_rects[index_entry.TargetIndex + 1]
        if (old_r.w == 0 and old_r.h == 0) then
            break
        end

        ImFontAtlasPackReuseIndexHint = index_n - 1
        local new_r_id = ImFontAtlasPackAddRect(atlas, old_r.w, old_r.h, index_entry)
        ImFontAtlasPackReuseIndexHint = nil
        if new_r_id == ImFontAtlasRectId_Invalid then
            -- Undo, grow texture and try repacking again.
            -- FIXME-NEWATLAS-TESTS: This is a very rarely exercised path! It needs to be automatically tested properly.
            IMGUI_DEBUG_LOG_FONT("[font] Texture #%03d: resize failed. Will grow.", new_tex.UniqueID)

            new_tex.WantDestroyNextFrame = true
            builder.Rects:swap(old_rects)
            builder.RectsIndex = old_index
            ImFontAtlasBuildSetTexture(atlas, old_tex)
            ImFontAtlasTextureGrow(atlas, w, h) -- Recurse

            return
        end

        IM_ASSERT(ImFontAtlasRectId_GetIndex(new_r_id) == index_n - 1) -- [Luau] == RectsIndex:index_from_ptr(index_entry)

        local new_r = ImFontAtlasPackGetRect(atlas, new_r_id)
        ImFontAtlasTextureBlockCopy(old_tex, old_r.x, old_r.y, new_tex, new_r.x, new_r.y, new_r.w, new_r.h)

        until true
    end
    IM_ASSERT(old_rects.Size == builder.Rects.Size + builder.RectsDiscardedCount)
    builder.RectsDiscardedCount = 0
    builder.RectsDiscardedSurface = 0

    -- Patch glyphs UV
    for baked_n = 1, builder.BakedPool.Size do
        for _, glyph in builder.BakedPool[baked_n].Glyphs:iter() do
            if (glyph.PackId ~= ImFontAtlasRectId_Invalid) then
                local r = ImFontAtlasPackGetRect(atlas, glyph.PackId)
                glyph.U0 = (r.x) * atlas.TexUvScale.x
                glyph.V0 = (r.y) * atlas.TexUvScale.y
                glyph.U1 = (r.x + r.w) * atlas.TexUvScale.x
                glyph.V1 = (r.y + r.h) * atlas.TexUvScale.y
            end
        end
    end

    -- Update other cached UV
    ImFontAtlasBuildUpdateTexData(atlas)

    builder.LockDisableResize = false
    ImFontAtlasUpdateDrawListsSharedData(atlas)
    --ImFontAtlasDebugWriteTexToDisk(new_tex, "After Pack")
end

function ImFontAtlasTextureGrow(atlas, old_tex_w, old_tex_h)
    --ImFontAtlasDebugWriteTexToDisk(atlas.TexData, "Before Grow")
    local builder = atlas.Builder

    old_tex_w = old_tex_w or -1
    old_tex_h = old_tex_h or -1

    if (old_tex_w == -1) then
        old_tex_w = atlas.TexData.Width
    end
    if (old_tex_h == -1) then
        old_tex_h = atlas.TexData.Height
    end

    -- FIXME-NEWATLAS-V2: What to do when reaching limits exposed by backend?
    -- FIXME-NEWATLAS-V2: Does ImFontAtlasFlags.NoPowerOfTwoHeight makes sense now? Allow 'lock' and 'compact' operations?
    IM_ASSERT(ImIsPowerOfTwo(old_tex_w) and ImIsPowerOfTwo(old_tex_h))
    IM_ASSERT(ImIsPowerOfTwo(atlas.TexMinWidth) and ImIsPowerOfTwo(atlas.TexMaxWidth) and ImIsPowerOfTwo(atlas.TexMinHeight) and ImIsPowerOfTwo(atlas.TexMaxHeight))

    -- Grow texture so it follows roughly a square.
    -- - Grow height before width, as width imply more packing nodes.
    -- - Caller should be taking account of RectsDiscardedSurface and may not need to grow.
    local new_tex_w = (old_tex_h <= old_tex_w) and old_tex_w or old_tex_w * 2
    local new_tex_h = (old_tex_h <= old_tex_w) and old_tex_h * 2 or old_tex_h

    -- Handle minimum size first (for pathologically large packed rects)
    local pack_padding = atlas.TexGlyphPadding
    new_tex_w = ImMax(new_tex_w, ImUpperPowerOfTwo(builder.MaxRectSize.x + pack_padding))
    new_tex_h = ImMax(new_tex_h, ImUpperPowerOfTwo(builder.MaxRectSize.y + pack_padding))
    new_tex_w = ImClamp(new_tex_w, atlas.TexMinWidth, atlas.TexMaxWidth)
    new_tex_h = ImClamp(new_tex_h, atlas.TexMinHeight, atlas.TexMaxHeight)
    if (new_tex_w == old_tex_w and new_tex_h == old_tex_h) then
        return
    end

    ImFontAtlasTextureRepack(atlas, new_tex_w, new_tex_h)
end

--- @param atlas ImFontAtlas
local function ImFontAtlasTextureMakeSpace(atlas)
    -- Can some baked contents be ditched?
    --IMGUI_DEBUG_LOG_FONT("[font] ImFontAtlasBuildMakeSpace()")
    local builder = atlas.Builder
    ImFontAtlasBuildDiscardBakes(atlas, 2)

    -- Currently using a heuristic for repack without growing.
    if (builder.RectsDiscardedSurface < builder.RectsPackedSurface * 0.20) then
        ImFontAtlasTextureGrow(atlas)
    else
        ImFontAtlasTextureRepack(atlas, atlas.TexData.Width, atlas.TexData.Height)
    end
end

-- This is essentially a free-list pattern, it may be nice to wrap it into a dedicated type.
--- @param atlas    ImFontAtlas
--- @param rect_idx ImFontAtlasRectId
local function ImFontAtlasPackAllocRectEntry(atlas, rect_idx)
    local builder = atlas.Builder
    local index_idx, index_entry
    if builder.RectsIndexFreeListStart < 0 then
        builder.RectsIndex:resize(builder.RectsIndex.Size + 1)
        index_idx = builder.RectsIndex.Size - 1
        index_entry = ImFontAtlasRectEntry()
        builder.RectsIndex.Data[builder.RectsIndex.Size] = index_entry
    else
        index_idx = builder.RectsIndexFreeListStart
        index_entry = builder.RectsIndex[index_idx + 1]
        IM_ASSERT(index_entry.IsUsed == false and index_entry.Generation > 0) -- Generation is incremented during DiscardRect
        builder.RectsIndexFreeListStart = index_entry.TargetIndex
    end

    index_entry.TargetIndex = rect_idx
    index_entry.IsUsed = true

    return ImFontAtlasRectId_Make(index_idx, index_entry.Generation)
end

-- Overwrite existing entry
--- @param atlas       ImFontAtlas
--- @param index_entry ImFontAtlasRectEntry
local function ImFontAtlasPackReuseRectEntry(atlas, index_entry)
    IM_ASSERT(index_entry.IsUsed)
    index_entry.TargetIndex = atlas.Builder.Rects.Size - 1
    local index_idx = ImFontAtlasPackReuseIndexHint
    if index_idx == nil or atlas.Builder.RectsIndex.Data[index_idx + 1] ~= index_entry then
        index_idx = atlas.Builder.RectsIndex:index_from_ptr(index_entry)
    end
    return ImFontAtlasRectId_Make(index_idx, index_entry.Generation)
end

-- This is expected to be called in batches and followed by a repack
--- @param atlas ImFontAtlas
--- @param id    ImFontAtlasRectId
function ImFontAtlasPackDiscardRect(atlas, id)
    IM_ASSERT(id ~= ImFontAtlasRectId_Invalid)

    local rect = ImFontAtlasPackGetRect(atlas, id)
    if (rect == nil) then
        return
    end

    local builder = atlas.Builder
    local index_idx = ImFontAtlasRectId_GetIndex(id)
    local index_entry = builder.RectsIndex.Data[index_idx + 1]
    IM_ASSERT(index_entry.IsUsed and index_entry.TargetIndex >= 0)
    index_entry.IsUsed = false
    index_entry.TargetIndex = builder.RectsIndexFreeListStart
    index_entry.Generation = index_entry.Generation + 1
    if (index_entry.Generation == 0) then
        index_entry.Generation = index_entry.Generation + 1 -- Keep non-zero on overflow
    end

    local pack_padding = atlas.TexGlyphPadding
    builder.RectsIndexFreeListStart = index_idx
    builder.RectsDiscardedCount = builder.RectsDiscardedCount + 1
    builder.RectsDiscardedSurface = builder.RectsDiscardedSurface + ((rect.w + pack_padding) * (rect.h + pack_padding))
    rect.w = 0 rect.h = 0 -- Clear rectangle so it won't be packed again
end

-- Important: Calling this may recreate a new texture and therefore change atlas.TexData
-- FIXME-NEWFONTS: Expose other glyph padding settings for custom alteration (e.g. drop shadows). See #7962
function ImFontAtlasPackAddRect(atlas, w, h, overwrite_entry)
    IM_ASSERT(w > 0 and w <= 0xFFFF)
    IM_ASSERT(h > 0 and h <= 0xFFFF)

    local builder = atlas.Builder
    local pack_padding = atlas.TexGlyphPadding
    builder.MaxRectSize.x = ImMax(builder.MaxRectSize.x, w)
    builder.MaxRectSize.y = ImMax(builder.MaxRectSize.y, h)

    -- Pack
    local r = ImTextureRect(0, 0, w, h)
    for attempts_remaining = 3, 0, -1 do
        -- Try packing
        local pack_r = stbrp.rect()
        pack_r.w = w + pack_padding
        pack_r.h = h + pack_padding
        stbrp.pack_rects(builder.PackContext, {pack_r}, 1)
        r.x = pack_r.x -- (unsigned short)
        r.y = pack_r.y -- (unsigned short)
        if pack_r.was_packed == 1 then
            break
        end

        -- If we ran out of attempts, return fallback
        if (attempts_remaining == 0 or builder.LockDisableResize) then
            IMGUI_DEBUG_LOG_FONT("[font] Failed packing %dx%d rectangle. Returning fallback.", w, h)

            return ImFontAtlasRectId_Invalid
        end

        -- Resize or repack atlas! (this should be a rare event)
        ImFontAtlasTextureMakeSpace(atlas)
    end

    builder.MaxRectBounds.x = ImMax(builder.MaxRectBounds.x, r.x + r.w + pack_padding)
    builder.MaxRectBounds.y = ImMax(builder.MaxRectBounds.y, r.y + r.h + pack_padding)
    builder.RectsPackedCount = builder.RectsPackedCount + 1
    builder.RectsPackedSurface = builder.RectsPackedSurface + (w + pack_padding) * (h + pack_padding)

    builder.Rects:push_back(r)
    if (overwrite_entry ~= nil) then
        return ImFontAtlasPackReuseRectEntry(atlas, overwrite_entry) -- Write into an existing entry instead of adding one (used during repack)
    else
        return ImFontAtlasPackAllocRectEntry(atlas, builder.Rects.Size - 1)
    end
end

-- Generally for non-user facing functions: assert on invalid ID.
--- @param atlas ImFontAtlas
--- @param id    ImFontAtlasRectId
--- @return ImTextureRect
function ImFontAtlasPackGetRect(atlas, id)
    IM_ASSERT(id ~= ImFontAtlasRectId_Invalid)
    local index_idx = ImFontAtlasRectId_GetIndex(id)
    local builder = atlas.Builder
    local index_entry = builder.RectsIndex.Data[index_idx + 1]
    IM_ASSERT(index_entry.Generation == ImFontAtlasRectId_GetGeneration(id))
    IM_ASSERT(index_entry.IsUsed)
    --- @type ImTextureRect
    return builder.Rects.Data[index_entry.TargetIndex + 1]
end

-- For user-facing functions: return nil on invalid ID.
-- Important: return value is valid until next call to AddRect(), e.g. FindGlyph(), CalcTextSize() can all potentially invalidate previous rects.
--- @param atlas ImFontAtlas
--- @param id    ImFontAtlasRectId
function ImFontAtlasPackGetRectSafe(atlas, id)
    if id == ImFontAtlasRectId_Invalid then
        return nil
    end

    local index_idx = ImFontAtlasRectId_GetIndex(id)
    if atlas.Builder == nil then
        ImFontAtlasBuildInit(atlas)
    end
    local builder = atlas.Builder
    if index_idx >= builder.RectsIndex.Size then
        return nil
    end
    local index_entry = builder.RectsIndex.Data[index_idx + 1]
    if (index_entry.Generation ~= ImFontAtlasRectId_GetGeneration(id) or not index_entry.IsUsed) then
        return nil
    end
    return builder.Rects.Data[index_entry.TargetIndex + 1]
end

-- Important! This assume by ImFontConfig.GlyphExcludeRanges[] is a SMALL ARRAY (e.g. <10 entries)
-- Use "Input Glyphs Overlap Detection Tool" to display a list of glyphs provided by multiple sources in order to set this array up.
--- @param src       ImFontConfig
--- @param codepoint ImWchar
--- @return bool
function ImFontAtlasBuildAcceptCodepointForSource(src, codepoint)
    local exclude_list = src.GlyphExcludeRanges
    if exclude_list then
        local i = 1
        while exclude_list[i] ~= 0 do
            if codepoint >= exclude_list[i] and codepoint <= exclude_list[i + 1] then
                return false
            end

            i = i + 2
        end
    end

    return true
end

--- @param baked    ImFontBaked
--- @param new_size int
function ImFontBaked_BuildGrowIndex(baked, new_size)
    IM_ASSERT(baked.IndexAdvanceX.Size == baked.IndexLookup.Size)
    if (new_size <= baked.IndexLookup.Size) then
        return
    end
    baked.IndexAdvanceX:resize(new_size, -1.0)
    baked.IndexLookup:resize(new_size, IM_FONTGLYPH_INDEX_UNUSED)
end

-------------------------------------------------------------------------------
-- [SECTION] ImFontAtlas: backend for stb_truetype
-------------------------------------------------------------------------------
-- (imstb_truetype.lua in included near the top of this file)
-------------------------------------------------------------------------------

-- One for each ConfigData
--- @class ImGui_ImplStbTrueType_FontSrcData
--- @field FontInfo    stbtt_fontinfo
--- @field ScaleFactor float

--- @return ImGui_ImplStbTrueType_FontSrcData
--- @nodiscard
local function ImGui_ImplStbTrueType_FontSrcData()
    return {
        FontInfo    = stbtt.fontinfo(),
        ScaleFactor = nil
    }
end

-- [Port] Need this in Lua since I don't want to include 'stbrp' just for context constructor
-- in ImFontAtlasBuilder def code. The cpp code has 'stbrp_context_opaque' which I don't/can't have here
--- @param atlas ImFontAtlas
local function ImGui_ImplStbTrueType_LoaderInit(atlas)
    atlas.Builder.PackContext = atlas.Builder.PackContext or stbrp.context()
end

local function ImGui_ImplStbTrueType_FontSrcInit(atlas, src)
    -- [Port] IM_UNUSED(atlas)

    --- @type ImGui_ImplStbTrueType_FontSrcData?
    local bd_font_data = ImGui_ImplStbTrueType_FontSrcData()
    IM_ASSERT(src.FontLoaderData == nil)

    -- Initialize helper structure for font loading and verify that the TTF/OTF data is correct
    local font_offset = stbtt.GetFontOffsetForIndex(src.FontData, src.FontNo)
    if font_offset < 0 then
        bd_font_data = nil
        IM_ASSERT_USER_ERROR(0, "stbtt_GetFontOffsetForIndex(): FontData is incorrect, or FontNo cannot be found.")
        return false
    end
    if (not stbtt.InitFont(bd_font_data.FontInfo, src.FontData, font_offset)) then
        bd_font_data = nil
        IM_ASSERT_USER_ERROR(0, "stbtt_InitFont(): failed to parse FontData. It is correct and complete? Check FontDataSize.")
        return false
    end
    src.FontLoaderData = bd_font_data

    local ref_size = src.DstFont.Sources[1].SizePixels
    if (src.MergeMode and src.SizePixels == 0.0) then
        src.SizePixels = ref_size
    end

    bd_font_data.ScaleFactor = stbtt.ScaleForPixelHeight(bd_font_data.FontInfo, 1.0)
    if (src.MergeMode and src.SizePixels ~= 0.0 and ref_size ~= 0.0) then
        bd_font_data.ScaleFactor = bd_font_data.ScaleFactor * (src.SizePixels / ref_size) -- FIXME-NEWATLAS: Should tidy up that a bit
    end
    bd_font_data.ScaleFactor = bd_font_data.ScaleFactor * src.ExtraSizeScale

    return true
end

local function ImGui_ImplStbTrueType_FontSrcDestroy(atlas, src)
    -- [Port] IM_UNUSED(atlas)
    src.FontLoaderData = nil
end

local function ImGui_ImplStbTrueType_FontSrcContainsGlyph(atlas, src, codepoint)
    -- [Port] IM_UNUSED(atlas)
    local bd_font_data = src.FontLoaderData
    IM_ASSERT(bd_font_data ~= nil)

    local glyph_index = stbtt.FindGlyphIndex(bd_font_data.FontInfo, codepoint)
    return (glyph_index ~= 0)
end

local function ImGui_ImplStbTrueType_FontBakedInit(atlas, src, baked)
    -- [Port] IM_UNUSED(atlas)

    local bd_font_data = src.FontLoaderData
    if (src.MergeMode == false) then
        -- FIXME-NEWFONTS: reevaluate how to use sizing metrics
        -- FIXME-NEWFONTS: make use of line gap value
        local scale_for_layout = bd_font_data.ScaleFactor * baked.Size / src.ExtraSizeScale
        local unscaled_ascent, unscaled_descent, unscaled_line_gap = stbtt.GetFontVMetrics(bd_font_data.FontInfo)

        baked.Ascent = ImCeil(unscaled_ascent * scale_for_layout)
        baked.Descent = ImFloor(unscaled_descent * scale_for_layout)
        -- FIXME: round to rasterizer density? (#9348)
    end

    return true
end

--- @param atlas      ImFontAtlas
--- @param src        ImFontConfig
--- @param baked      ImFontBaked
--- @param _          any
--- @param codepoint  ImWchar
--- @param out_glyph  ImFontGlyph
--- @param advance_x? float
--- @return bool
--- @return float? out_advance_x # Updated `advance_x`
local function ImGui_ImplStbTrueType_FontBakedLoadGlyph(atlas, src, baked, _, codepoint, out_glyph, advance_x)
    -- Search for first font which has the glyph
    local bd_font_data = src.FontLoaderData
    IM_ASSERT(bd_font_data ~= nil)
    local glyph_index = stbtt.FindGlyphIndex(bd_font_data.FontInfo, codepoint)
    if (glyph_index == 0) then
        return false, advance_x
    end

    -- Fonts unit to pixels
    local oversample_h, oversample_v = ImFontAtlasBuildGetOversampleFactors(src, baked)
    local scale_for_layout = bd_font_data.ScaleFactor * baked.Size
    local rasterizer_density = src.RasterizerDensity * baked.RasterizerDensity
    local scale_for_raster_x = bd_font_data.ScaleFactor * baked.Size * rasterizer_density * oversample_h
    local scale_for_raster_y = bd_font_data.ScaleFactor * baked.Size * rasterizer_density * oversample_v

    -- Obtain size and advance
    local x0, y0, x1, y1 = stbtt.GetGlyphBitmapBoxSubpixel(bd_font_data.FontInfo, glyph_index, scale_for_raster_x, scale_for_raster_y, 0, 0)
    local advance, lsb = stbtt.GetGlyphHMetrics(bd_font_data.FontInfo, glyph_index)

    -- Load metrics only mode
    if (advance_x ~= nil) then
        IM_ASSERT(out_glyph == nil)
        advance_x = advance * scale_for_layout

        return true, advance_x
    end

    -- Prepare glyph
    out_glyph.Codepoint = codepoint
    out_glyph.AdvanceX = advance * scale_for_layout

    -- Pack and retrieve position inside texture atlas
    -- (generally based on stbtt_PackFontRangesRenderIntoRects)
    local is_visible = (x0 ~= x1 and y0 ~= y1)
    if is_visible then
        local w = (x1 - x0 + oversample_h - 1)
        local h = (y1 - y0 + oversample_v - 1)
        local pack_id = ImFontAtlasPackAddRect(atlas, w, h)
        if (pack_id == ImFontAtlasRectId_Invalid) then
            -- Pathological out of memory case (TexMaxWidth/TexMaxHeight set too small?)
            IM_ASSERT(pack_id ~= ImFontAtlasRectId_Invalid, "Out of texture memory.")
            return false, advance_x
        end

        local r = ImFontAtlasPackGetRect(atlas, pack_id)

        -- Render
        x0, y0, x1, y1 = stbtt.GetGlyphBitmapBox(bd_font_data.FontInfo, glyph_index, scale_for_raster_x, scale_for_raster_y)
        local builder = atlas.Builder
        builder.TempBuffer:resize(w * h * 1)
        local bitmap_pixels = builder.TempBuffer.Data
        ImStd.memset(bitmap_pixels, 0, w * h * 1)

        -- Render with oversampling
        -- (those functions conveniently assert if pixels are not cleared, which is another safety layer)
        local sub_x, sub_y = stbtt.MakeGlyphBitmapSubpixelPrefilter(bd_font_data.FontInfo, bitmap_pixels, w, h, w,
            scale_for_raster_x, scale_for_raster_y, 0, 0, oversample_h, oversample_v, glyph_index)

        local ref_size = baked.OwnerFont.Sources[1].SizePixels
        local offsets_scale = (ref_size ~= 0.0) and (baked.Size / ref_size) or 1.0
        local font_off_x = ImFloor(src.GlyphOffset.x * offsets_scale + 0.5) -- Snap scaled offset.
        local font_off_y = ImFloor(src.GlyphOffset.y * offsets_scale + 0.5)
        font_off_x = font_off_x + sub_x
        font_off_y = font_off_y + (sub_y + IM_ROUND(baked.Ascent))
        local recip_h = 1.0 / (oversample_h * rasterizer_density)
        local recip_v = 1.0 / (oversample_v * rasterizer_density)

        -- Register glyph
        -- r.x r.y are coordinates inside texture (in pixels)
        -- glyph.X0, glyph.Y0 are drawing coordinates from base text position, and accounting for oversampling.
        out_glyph.X0 = x0 * recip_h + font_off_x
        out_glyph.Y0 = y0 * recip_v + font_off_y
        out_glyph.X1 = (x0 + r.w) * recip_h + font_off_x
        out_glyph.Y1 = (y0 + r.h) * recip_v + font_off_y
        out_glyph.Visible = true
        out_glyph.PackId = pack_id

        ImFontAtlasBakedSetFontGlyphBitmap(atlas, baked, src, out_glyph, r, bitmap_pixels, ImTextureFormat.Alpha8, w)
    end

    return true, advance_x
end

local function ImFontAtlasGetFontLoaderForStbTruetype()
    local loader = ImFontLoader()

    loader.Name                 = "stb_truetype"
    loader.LoaderInit           = ImGui_ImplStbTrueType_LoaderInit
    loader.FontSrcInit          = ImGui_ImplStbTrueType_FontSrcInit
    loader.FontSrcDestroy       = ImGui_ImplStbTrueType_FontSrcDestroy
    loader.FontSrcContainsGlyph = ImGui_ImplStbTrueType_FontSrcContainsGlyph
    loader.FontBakedInit        = ImGui_ImplStbTrueType_FontBakedInit
    loader.FontBakedDestroy     = nil
    loader.FontBakedLoadGlyph   = ImGui_ImplStbTrueType_FontBakedLoadGlyph

    return loader
end

--- @param atlas ImFontAtlas
--- @param baked ImFontBaked
function ImFontAtlasBuildSetupFontBakedBlanks(atlas, baked)
    -- Mark space as always hidden (not strictly correct/necessary. but some e.g. icons fonts don't have a space. it tends to look neater in previews)
    local space_glyph = baked:FindGlyphNoFallback(32)
    if space_glyph ~= nil then
        space_glyph.Visible = false
    end

    -- Setup Tab character.
    -- FIXME: Needs proper TAB handling but it needs to be contextualized (or we could arbitrary say that each string starts at "column 0" ?)
    if baked:FindGlyphNoFallback(9) == nil and space_glyph ~= nil then
        local tab_glyph = ImFontGlyph()
        tab_glyph.Codepoint = 9
        tab_glyph.AdvanceX = space_glyph.AdvanceX * IM_TABSIZE
        ImFontAtlasBakedAddFontGlyph(atlas, baked, nil, tab_glyph)
    end
end

--- @param glyph ImFontGlyph
function ImFontAtlasBakedDiscardFontGlyph(atlas, font, baked, glyph)
    if glyph.PackId ~= ImFontAtlasRectId_Invalid then
        ImFontAtlasPackDiscardRect(atlas, glyph.PackId)
        glyph.PackId = ImFontAtlasRectId_Invalid
    end
    local c = glyph.Codepoint
    IM_ASSERT(font.FallbackChar ~= c and font.EllipsisChar ~= c) -- Unsupported for simplicity
    baked.IndexLookup.Data[c + 1] = IM_FONTGLYPH_INDEX_UNUSED
    baked.IndexAdvanceX.Data[c + 1] = baked.FallbackAdvanceX
end

--- @param atlas                   ImFontAtlas
--- @param font                    ImFont
--- @param font_size               float
--- @param font_rasterizer_density float
--- @param baked_id                ImGuiID
--- @return ImFontBaked?
function ImFontAtlasBakedAdd(atlas, font, font_size, font_rasterizer_density, baked_id)
    IMGUI_DEBUG_LOG_FONT("[font] Created baked %.2fpx", font_size)

    local baked = atlas.Builder.BakedPool:push_back(ImFontBaked())

    baked.Size              = font_size
    baked.RasterizerDensity = font_rasterizer_density
    baked.BakedId           = baked_id
    baked.OwnerFont         = font
    baked.LastUsedFrame     = atlas.Builder.FrameCount

    -- Initialize backend data
    local loader_data_size = 0
    for _, src in font.Sources:iter() do -- Cannot easily be cached as we allow changing backend
        local loader = src.FontLoader and src.FontLoader or atlas.FontLoader
        loader_data_size = loader_data_size + loader.FontBakedSrcLoaderDataSize
    end
    -- [Port] baked.FontLoaderDatas = (loader_data_size > 0) and IM_ALLOC(loader_data_size) or nil
    -- local loader_data_p = baked->FontLoaderDatas
    for _, src in font.Sources:iter() do
        local loader = src.FontLoader and src.FontLoader or atlas.FontLoader
        if (loader.FontBakedInit) then
            loader.FontBakedInit(atlas, src, baked--[[, loader_data_p--]])
        end
        -- [Port] loader_data_p += loader->FontBakedSrcLoaderDataSize
    end

    ImFontAtlasBuildSetupFontBakedBlanks(atlas, baked)
    return baked
end

-- FIXME-OPT: This is not a fast query. Adding a BakedCount field in Font might allow to take a shortcut for the most common case.
--- @param atlas                   ImFontAtlas
--- @param font                    ImFont
--- @param font_size               float
--- @param font_rasterizer_density float
--- @return ImFontBaked?
function ImFontAtlasBakedGetClosestMatch(atlas, font, font_size, font_rasterizer_density)
    local builder = atlas.Builder

    for step_n = 0, 1 do
        local closest_larger_match
        local closest_smaller_match
        for baked_n = 1, builder.BakedPool.Size do
            repeat
            local baked = builder.BakedPool[baked_n]
            if (baked.OwnerFont ~= font or baked.WantDestroy) then
                break
            end

            if (step_n == 0 and baked.RasterizerDensity ~= font_rasterizer_density) then -- First try with same density
                break
            end

            if (baked.Size > font_size and (closest_larger_match == nil or baked.Size < closest_larger_match.Size)) then
                closest_larger_match = baked
            end
            if (baked.Size < font_size and (closest_smaller_match == nil or baked.Size > closest_smaller_match.Size)) then
                closest_smaller_match = baked
            end

            until true
        end
        if (closest_larger_match) then
            if (closest_smaller_match == nil or (closest_larger_match.Size >= font_size * 2.0 and closest_smaller_match.Size > font_size * 0.5)) then
                return closest_larger_match
            end
        end
        if (closest_smaller_match) then
            return closest_smaller_match
        end
    end

    return nil
end

--- @param atlas ImFontAtlas
--- @param font  ImFont
--- @param baked ImFontBaked
function ImFontAtlasBakedDiscard(atlas, font, baked)
    local builder = atlas.Builder

    for _, glyph in baked.Glyphs:iter() do
        if glyph.PackId ~= ImFontAtlasRectId_Invalid then
            ImFontAtlasPackDiscardRect(atlas, glyph.PackId)
        end
    end

    -- [Port] char* loader_data_p = (char*)baked->FontLoaderDatas
    for _, src in font.Sources:iter() do
        local loader = src.FontLoader and src.FontLoader or atlas.FontLoader
        if loader.FontBakedDestroy then
            loader.FontBakedDestroy(atlas, src, baked)
        end
    end

    if baked.FontLoaderDatas then
        baked.FontLoaderDatas = nil
    end

    builder.BakedMap[baked.BakedId] = nil
    builder.BakedDiscardedCount = builder.BakedDiscardedCount + 1
    baked:ClearOutputData()
    baked.WantDestroy = true
    font.LastBaked = nil
end

-- use unused_frames==0 to discard everything.
function ImFontAtlasFontDiscardBakes(atlas, font, unused_frames)
    local builder = atlas.Builder
    if builder then -- This can be called from font destructor
        for baked_n = 1, builder.BakedPool.Size do
            repeat
            local baked = builder.BakedPool[baked_n]
            if baked.LastUsedFrame + unused_frames > atlas.Builder.FrameCount then
                break
            end

            if (baked.OwnerFont ~= font) or baked.WantDestroy then
                break
            end

            ImFontAtlasBakedDiscard(atlas, font, baked)

            until true
        end
    end
end

-- Was tempted to lazily init FontSrc but wouldn't save much + makes it more complicated to detect invalid data at AddFont()
function ImFontAtlasFontInitOutput(atlas, font)
    local ret = true
    for _, src in font.Sources:iter() do
        if not ImFontAtlasFontSourceInit(atlas, src) then
            ret = false
        end
    end
    IM_ASSERT(ret) -- Unclear how to react to this meaningfully. Assume that result will be same as initial AddFont() call.
    return ret
end

-- Keep source/input FontData
function ImFontAtlasFontDestroyOutput(atlas, font)
    font:ClearOutputData()
    for _, src in font.Sources:iter() do
        local loader = src.FontLoader and src.FontLoader or atlas.FontLoader
        if loader and loader.FontSrcDestroy ~= nil then
            loader.FontSrcDestroy(atlas, src)
        end
    end
end

function ImFontAtlasFontRebuildOutput(atlas, font)
    ImFontAtlasFontDestroyOutput(atlas, font)
    ImFontAtlasFontInitOutput(atlas, font)
end

--- @param atlas ImFontAtlas
--- @param src ImFontConfig
--- @return boolean
function ImFontAtlasFontSourceInit(atlas, src)
    local loader = (src.FontLoader) and src.FontLoader or atlas.FontLoader
    if (loader.FontSrcInit ~= nil and not loader.FontSrcInit(atlas, src)) then
        return false
    end
    return true
end

--- @param atlas ImFontAtlas
--- @param font ImFont
--- @param src ImFontConfig
function ImFontAtlasFontSourceAddToFont(atlas, font, src)
    if src.MergeMode == false then
        font:ClearOutputData()
        --font.FontSize = src.SizePixels
        font.OwnerAtlas = atlas
        IM_ASSERT(font.Sources[1] == src)
    end
    atlas.TexIsBuilt = false -- For legacy backends
    ImFontAtlasBuildSetupFontSpecialGlyphs(atlas, font, src)
end

--- @param atlas ImFontAtlas
--- @param src ImFontConfig
function ImFontAtlasFontDestroySourceData(atlas, src)
    -- [Port] IM_UNUSED(atlas)

    -- [Port] if src.FontDataOwnedByAtlas then
    --     IM_FREE(src.FontData)
    -- end
    src.FontData = nil
    -- [Port] if src.GlyphExcludeRanges then
    --     IM_FREE(src.GlyphExcludeRanges)
    -- end
    src.GlyphExcludeRanges = nil
end

-- Load/identify special glyphs
-- (note that this is called again for fonts with MergeMode)
--- @param atlas ImFontAtlas
--- @param font ImFont
--- @param src ImFontConfig
function ImFontAtlasBuildSetupFontSpecialGlyphs(atlas, font, src)
    -- [Port] IM_UNUSED(atlas)
    IM_ASSERT(font.Sources:contains(src))

    -- Find Fallback character. Actual glyph loaded in GetFontBaked().
    --- @type ImWchar[]
    local fallback_chars = {font.FallbackChar, IM_UNICODE_CODEPOINT_INVALID, 63, 32}
    if font.FallbackChar == 0 then
        for _, candidate_char in ipairs(fallback_chars) do
            if candidate_char ~= 0 and font:IsGlyphInFont(candidate_char) then
                font.FallbackChar = candidate_char

                break
            end
        end
    end

    -- Setup Ellipsis character. It is required for rendering elided text. We prefer using U+2026 (horizontal ellipsis).
    -- However some old fonts may contain ellipsis at U+0085. Here we auto-detect most suitable ellipsis character.
    -- FIXME: Note that 0x2026 is rarely included in our font ranges. Because of this we are more likely to use three individual dots.
    --- @type ImWchar[]
    local ellipsis_chars = {src.EllipsisChar, 0x2026, 0x0085}
    if font.EllipsisChar == 0 then
        for _, candidate_char in ipairs(ellipsis_chars) do
            if candidate_char ~= 0 and font:IsGlyphInFont(candidate_char) then
                font.EllipsisChar = candidate_char

                break
            end
        end
    end

    if font.EllipsisChar == 0 then
        font.EllipsisChar = 0x0085
        font.EllipsisAutoBake = true
    end
end

-- Create a compact, baked "..." if it doesn't exist, by using the ".".
-- This may seem overly complicated right now but the point is to exercise and improve a technique which should be increasingly used.
-- FIXME-NEWATLAS: This borrows too much from FontLoader's FontLoadGlyph() handlers and suggest that we should add further helpers.
--- @param atlas ImFontAtlas
--- @param baked ImFontBaked
--- @return ImFontGlyph?
function ImFontAtlasBuildSetupFontBakedEllipsis(atlas, baked)
    local font = baked.OwnerFont
    IM_ASSERT(font.EllipsisChar ~= 0)

    local dot_glyph = baked:FindGlyphNoFallback(46) -- '.'
    if (dot_glyph == nil) then
        dot_glyph = baked:FindGlyphNoFallback(0xFF0E)
    end
    if (dot_glyph == nil) then
        return nil
    end
    local dot_r_id = dot_glyph.PackId -- Deep copy to avoid invalidation of glyphs and rect pointers
    local dot_r = ImFontAtlasPackGetRect(atlas, dot_r_id)
    local dot_spacing = 1
    local dot_step = (dot_glyph.X1 - dot_glyph.X0) + dot_spacing

    local pack_id = ImFontAtlasPackAddRect(atlas, (dot_r.w * 3 + dot_spacing * 2), dot_r.h)
    local r = ImFontAtlasPackGetRect(atlas, pack_id)

    local glyph = ImFontGlyph()
    glyph.Codepoint = font.EllipsisChar
    glyph.AdvanceX = ImMax(dot_glyph.AdvanceX, dot_glyph.X0 + dot_step * 3.0 - dot_spacing) -- FIXME: Slightly odd for normally mono-space fonts but since this is used for trailing contents.
    glyph.X0 = dot_glyph.X0
    glyph.Y0 = dot_glyph.Y0
    glyph.X1 = dot_glyph.X0 + dot_step * 3 - dot_spacing
    glyph.Y1 = dot_glyph.Y1
    glyph.Visible = true
    glyph.PackId = pack_id
    glyph = ImFontAtlasBakedAddFontGlyph(atlas, baked, nil, glyph)
    dot_glyph = nil

    dot_r = ImFontAtlasPackGetRect(atlas, dot_r_id)
    local tex = atlas.TexData
    for n = 0, 2 do
        ImFontAtlasTextureBlockCopy(tex, dot_r.x, dot_r.y, tex, r.x + (dot_r.w + dot_spacing) * n, r.y, dot_r.w, dot_r.h)
    end
    ImFontAtlasTextureBlockQueueUpload(atlas, tex, r.x, r.y, r.w, r.h)

    return glyph
end

-- Load fallback in order to obtain its index
-- (this is called from in hot-path so we avoid extraneous parameters to minimize impact on code size)
--- @param baked ImFontBaked
function ImFontAtlasBuildSetupFontBakedFallback(baked)
    IM_ASSERT(baked.FallbackGlyphIndex == -1)
    IM_ASSERT(baked.FallbackAdvanceX == 0.0)
    local font = baked.OwnerFont
    local fallback_glyph
    if (font.FallbackChar ~= 0) then
        fallback_glyph = baked:FindGlyphNoFallback(font.FallbackChar)
    end
    if (fallback_glyph == nil) then
        local space_glyph = baked:FindGlyphNoFallback(32) -- ' '
        local glyph = ImFontGlyph()
        glyph.Codepoint = 0
        glyph.AdvanceX = space_glyph and space_glyph.AdvanceX or IM_ROUND(baked.Size * 0.40)
        fallback_glyph = ImFontAtlasBakedAddFontGlyph(font.OwnerAtlas, baked, nil, glyph)
    end
    baked.FallbackGlyphIndex = baked.Glyphs:index_from_ptr(fallback_glyph) + 1 -- Storing index avoid need to update pointer on growth and simplify inner loop code
    baked.FallbackAdvanceX = fallback_glyph.AdvanceX
end

-- Setup main font loader for the atlas
-- Every font source (ImFontConfig) will use this unless ImFontConfig.FontLoader specify a custom loader.
function ImFontAtlasBuildSetupFontLoader(atlas, font_loader)
    if atlas.FontLoader == font_loader then
        return
    end
    IM_ASSERT(not atlas.Locked, "Cannot modify a locked ImFontAtlas!")

    for _, font in atlas.Fonts:iter() do
        ImFontAtlasFontDestroyOutput(atlas, font)
    end
    if atlas.Builder and atlas.FontLoader and atlas.FontLoader.LoaderShutdown then
        atlas.FontLoader.LoaderShutdown(atlas)
    end

    atlas.FontLoader = font_loader
    atlas.FontLoaderName = font_loader and font_loader.Name or "NULL"
    IM_ASSERT(atlas.FontLoaderData == nil)

    if atlas.Builder and atlas.FontLoader and atlas.FontLoader.LoaderInit then
        atlas.FontLoader.LoaderInit(atlas)
    end
    for _, font in atlas.Fonts:iter() do
        ImFontAtlasFontInitOutput(atlas, font)
    end
    for _, font in atlas.Fonts:iter() do
        for _, src in font.Sources:iter() do
            ImFontAtlasFontSourceAddToFont(atlas, font, src)
        end
    end
end

local function ImFontAtlasBuildUpdateRendererHasTexturesFromContext(atlas)
    -- [LEGACY] Copy back the ImGuiBackendFlags.RendererHasTextures flag from ImGui context.
    -- - This is the 1% exceptional case where that dependency if useful, to bypass an issue where otherwise at the
    --   time of an early call to Build(), it would be impossible for us to tell if the backend supports texture update.
    -- - Without this hack, we would have quite a pitfall as many legacy codebases have an early call to Build().
    --   Whereas conversely, the portion of people using ImDrawList without ImGui is expected to be pathologically rare.
    for _, shared_data in atlas.DrawListSharedDatas:iter() do
        local imgui_ctx = shared_data.Context
        if (imgui_ctx) then
            atlas.RendererHasTextures = bit32.band(imgui_ctx.IO.BackendFlags, ImGuiBackendFlags.RendererHasTextures) ~= 0

            break
        end
    end
end

local function ImFontAtlasBuildUpdatePointers(atlas)
    -- [Port] for _, font in atlas.Fonts:iter() do
    --     font.Sources:resize(0)
    -- end
    -- for _, src in atlas.Sources:iter() do
    --     src.DstFont.Sources:push_back(src)
    -- end
end

-- Update texture identifier in all active draw lists
--- @param atlas   ImFontAtlas
--- @param old_tex ImTextureRef
--- @param new_tex ImTextureRef
local function ImFontAtlasUpdateDrawListsTextures(atlas, old_tex, new_tex)
    for _, shared_data in atlas.DrawListSharedDatas:iter() do
        repeat
        -- If Context 2 uses font owned by Context 1 which already called EndFrame()/Render(), we don't want to mess with draw commands for Context 1
        if (shared_data.Context and not shared_data.Context.WithinFrameScope) then
            break
        end

        for _, draw_list in shared_data.DrawLists:iter() do
            -- Replace in command-buffer
            -- (there is not need to replace in ImDrawListSplitter: current channel is in ImDrawList's CmdBuffer[],
            --  other channels will be on SetCurrentChannel() which already needs to compare CmdHeader anyhow)
            if (draw_list.CmdBuffer.Size > 0 and draw_list._CmdHeader.TexRef == old_tex) then
                draw_list:_SetTexture(new_tex)
            end

            -- Replace in stack
            for i, stacked_tex in draw_list._TextureStack:iter() do
                if (stacked_tex == old_tex) then
                    draw_list._TextureStack.Data[i] = new_tex
                end
            end
        end

        until true
    end
end

-- Set current texture. This is mostly called from AddTexture() + to handle a failed resize.
function ImFontAtlasBuildSetTexture(atlas, tex)
    local old_tex_ref = atlas.TexRef
    atlas.TexData = tex
    atlas.TexUvScale = ImVec2(1.0 / tex.Width, 1.0 / tex.Height)
    atlas.TexRef._TexData = tex
    --atlas.TexRef._TexID = tex.TexID -- <-- We intentionally don't do that. It would be misleading and betray promise that both fields aren't set.
    ImFontAtlasUpdateDrawListsTextures(atlas, old_tex_ref, atlas.TexRef)
end

--- @param atlas ImFontAtlas
function ImFontAtlasBuildUpdateTexData(atlas)
    ImFontAtlasBuildUpdateTexDataBasic(atlas)
    ImFontAtlasBuildUpdateTexDataLines(atlas)
    ImFontAtlasBuildUpdateTexDataCorners(atlas)
end

-- Create a new texture, discard previous one
function ImFontAtlasTextureAdd(atlas, w, h)
    local old_tex = atlas.TexData
    local new_tex

    -- FIXME: Cannot reuse texture because old UV may have been used already (unless we remap UV).
    --if (old_tex ~= nil and old_tex.Status == ImTextureStatus.WantCreate) then
    --    -- Reuse texture not yet used by backend.
    --    IM_ASSERT(old_tex.TexID == ImTextureID_Invalid and old_tex.BackendUserData == nil)
    --    old_tex:DestroyPixels()
    --    old_tex.Updates:clear()
    --    new_tex = old_tex
    --    old_tex = nil
    --else
    -- Add new
    new_tex = ImTextureData()
    new_tex.UniqueID = atlas.TexNextUniqueID
    atlas.TexNextUniqueID = atlas.TexNextUniqueID + 1
    atlas.TexList:push_back(new_tex)

    if old_tex ~= nil then
        -- Queue old as to destroy next frame
        old_tex.WantDestroyNextFrame = true
        IM_ASSERT(old_tex.Status == ImTextureStatus.OK or old_tex.Status == ImTextureStatus.WantCreate or old_tex.Status == ImTextureStatus.WantUpdates)
    end

    new_tex:Create(atlas.TexDesiredFormat, w, h)
    atlas.TexIsBuilt = false

    ImFontAtlasBuildSetTexture(atlas, new_tex)

    return new_tex
end

--- @param atlas ImFontAtlas
--- @return ImVec2
function ImFontAtlasTextureGetSizeEstimate(atlas)
    local min_w = ImUpperPowerOfTwo(atlas.TexMinWidth)
    local min_h = ImUpperPowerOfTwo(atlas.TexMinHeight)
    if (atlas.Builder == nil or atlas.TexData == nil or atlas.TexData.Status == ImTextureStatus.WantDestroy) then
        return ImVec2(min_w, min_h) -- ImVec2i
    end

    local builder = atlas.Builder
    min_w = ImMax(ImUpperPowerOfTwo(builder.MaxRectSize.x), min_w)
    min_h = ImMax(ImUpperPowerOfTwo(builder.MaxRectSize.y), min_h)
    local surface_approx = builder.RectsPackedSurface - builder.RectsDiscardedSurface -- Expected surface after repack
    local surface_sqrt = ImFloor(ImSqrt(surface_approx))

    local new_tex_w
    local new_tex_h
    if (min_w >= min_h) then
        new_tex_w = ImMax(min_w, ImUpperPowerOfTwo(surface_sqrt))
        new_tex_h = ImMax(min_h, ImFloor((surface_approx + new_tex_w - 1) / new_tex_w))
        if (bit32.band(atlas.Flags, ImFontAtlasFlags.NoPowerOfTwoHeight) == 0) then
            new_tex_h = ImUpperPowerOfTwo(new_tex_h)
        end
    else
        new_tex_h = ImMax(min_h, ImUpperPowerOfTwo(surface_sqrt))
        if (bit32.band(atlas.Flags, ImFontAtlasFlags.NoPowerOfTwoHeight) == 0) then
            new_tex_h = ImUpperPowerOfTwo(new_tex_h)
        end
        new_tex_w = ImMax(min_w, ImFloor((surface_approx + new_tex_h - 1) / new_tex_h))
    end

    IM_ASSERT(ImIsPowerOfTwo(new_tex_w) and ImIsPowerOfTwo(new_tex_h))
    return ImVec2(new_tex_w, new_tex_h) -- ImVec2i
end

-- Clear all output. Invalidates all AddCustomRect() return values!
--- @param atlas ImFontAtlas
function ImFontAtlasBuildClear(atlas)
    local new_tex_size = ImFontAtlasTextureGetSizeEstimate(atlas) -- ImVec2i
    ImFontAtlasBuildDestroy(atlas)
    ImFontAtlasTextureAdd(atlas, new_tex_size.x, new_tex_size.y)
    ImFontAtlasBuildInit(atlas)
    for _, src in atlas.Sources:iter() do
        ImFontAtlasFontSourceInit(atlas, src)
    end
    for _, font in atlas.Fonts:iter() do
        for _, src in font.Sources:iter() do
            ImFontAtlasFontSourceAddToFont(atlas, font, src)
        end
    end
end

-- You should not need to call this manually!
-- If you think you do, let us know and we can advise about policies auto-compact.
--- @param atlas ImFontAtlas
function ImFontAtlasTextureCompact(atlas)
    local builder = atlas.Builder
    ImFontAtlasBuildDiscardBakes(atlas, 1)

    local old_tex = atlas.TexData
    local old_tex_size = ImVec2(old_tex.Width, old_tex.Height)
    local new_tex_size = ImFontAtlasTextureGetSizeEstimate(atlas)
    if (builder.RectsDiscardedCount == 0 and new_tex_size.x == old_tex_size.x and new_tex_size.y == old_tex_size.y) then
        return
    end

    ImFontAtlasTextureRepack(atlas, new_tex_size.x, new_tex_size.y)
end

--- @param atlas ImFontAtlas
function ImFontAtlasPackInit(atlas)
    local tex = atlas.TexData
    local builder = atlas.Builder

    -- In theory we could decide to reduce the number of nodes, e.g. halve them, and waste a little texture space, but it doesn't seem worth it.
    local pack_node_count = ImFloor(tex.Width / 2)
    builder.PackNodes:resize(pack_node_count)
    for i = 1, builder.PackNodes.Size do builder.PackNodes.Data[i] = stbrp.node() end

    stbrp.init_target(builder.PackContext, tex.Width, tex.Height, builder.PackNodes.Data, builder.PackNodes.Size)
    builder.RectsPackedCount = 0
    builder.RectsPackedSurface = 0
    builder.MaxRectSize = ImVec2(0, 0) -- ImVec2i
    builder.MaxRectBounds = ImVec2(0, 0) -- ImVec2i
end

--- @param atlas ImFontAtlas
-- [Port] #define IM_DRAWLIST_CORNER_POINTS_MAX (IM_DRAWLIST_ARCFAST_TABLE_SIZE / 4 + 3) // Max number of points in corner profiles
-- [Luau] ImVec2 line_normals[] / float line_distances[] / ImVec2 points[] are flat 1-based scratch arrays (x, y, distance).
local corner_points_x, corner_points_y = {}, {}
local corner_normals_x, corner_normals_y, corner_distances = {}, {}, {}

-- [Luau] line_normals is passed as two arrays (line_normals_x, line_normals_y), 1-based.
local function InitCornerGeometry(cx, cy, rounding, circle_segment_max_error, line_normals_x, line_normals_y, line_distances)
    -- This tries to quite faithfully replicate how we render the corners using tessellation.
    -- Older code sampled a circle SDF directly, but it had clearly visible discrepancy between the baked corners
    -- and tessellated corners due to circle_segment_max_error.

    local auto_seg_count = IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC(rounding, circle_segment_max_error)
    local arc_step, arc_step_count = CalcCornerArcStepAndCount(auto_seg_count)
    local arc_point_count = arc_step_count + 1

    -- Build arc of points, with straight segments at each end.
    --      . [n-2]..[n-1]
    --    .`
    --   .
    --  [1]     x (cx,cy)
    --   :
    --  [0]
    local points_x, points_y = corner_points_x, corner_points_y
    local num_points = 0

    num_points = num_points + 1; points_x[num_points] = cx - rounding; points_y[num_points] = cy + 1.0

    local da = (arc_step / IM_DRAWLIST_ARCFAST_TABLE_SIZE) * IM_PI * 2.0
    local a = IM_PI
    for _ = 0, arc_point_count - 1 do
        local dx = ImCos(a)
        local dy = ImSin(a)
        num_points = num_points + 1; points_x[num_points] = cx + dx * rounding; points_y[num_points] = cy + dy * rounding
        a = a + da
    end

    num_points = num_points + 1; points_x[num_points] = cx + 1.0; points_y[num_points] = cy - rounding

    -- Turn segments to half spaces.
    for i = 1, num_points - 1 do
        local diff_x = points_x[i + 1] - points_x[i]
        local diff_y = points_y[i + 1] - points_y[i]
        local d2 = diff_x * diff_x + diff_y * diff_y
        local inv_d = ImRsqrtPrecise(d2)
        line_normals_x[i] = diff_y * inv_d -- Normal points outwards
        line_normals_y[i] = -diff_x * inv_d
        line_distances[i] = -(points_x[i] * line_normals_x[i] + points_y[i] * line_normals_y[i]) -- [Port] -ImDot()
    end

    return num_points - 1
end

-- Returns distance to convex shape limited by lines.
local function SampleConvex(x, y, line_normals_x, line_normals_y, line_distances, num_lines)
    local result = -FLT_MAX
    for i = 1, num_lines do
        local d = line_normals_x[i] * x + line_normals_y[i] * y + line_distances[i]
        if d > result then
            result = d
        end
    end
    return result
end

local function SampleCornerFillOrStroke(x, y, thickness, line_normals_x, line_normals_y, line_distances, num_lines)
    local d = SampleConvex(x, y, line_normals_x, line_normals_y, line_distances, num_lines)
    local aa_width = 1.0
    if thickness == 0.0 then
        -- Fill
        return math.floor(ImClamp(1.0 - (d + aa_width * 0.5) / aa_width, 0.0, 1.0) * 255.0) -- [Port] (ImU8)
    else
        -- Stroke
        local outer = 1.0 - (d + aa_width * 0.5) / aa_width
        local inner = (d + thickness + aa_width * 0.5) / aa_width
        return math.floor(ImClamp(ImMin(inner, outer), 0.0, 1.0) * 255.0) -- [Port] (ImU8)
    end
end

-- [Port] #if 0 DEBUG_TEX_CORNER_U8/DEBUG_TEX_CORNER_U32 coverage visualization not ported (always 0xFF/0xFFFFFFFF).

function ImFontAtlasBuildUpdateTexDataCorners(atlas)
    if bit32.band(atlas.Flags, ImFontAtlasFlags.NoBakedRoundCorners) ~= 0 then
        return
    end

    -- Pack and store identifier so we can refresh UV coordinates on texture resize.
    local tex = atlas.TexData
    local builder = atlas.Builder

    -- FIXME-TEXCORNERS: Ideally we should pick up the max error from the styles, but it does not seem be to set by the time we build the data the first time.
    local circle_segment_max_error = 0.30 -- Default matching ImGuiStyle::CircleTessellationMaxError.
    --    if (atlas->OwnerContext)
    --        circle_segment_max_error = atlas->OwnerContext->DrawListSharedData.CircleSegmentMaxError;

    -- Calculate size and pack
    local r = ImFontAtlasRect()
    local add_and_draw = (atlas:GetCustomRect(builder.PackIdCornersTexData, r) == false)
    if add_and_draw then
        -- (thickness 0 for filled, thickness >0 for strokes)
        local pack_size_x, pack_size_y = 0, 0 -- ImVec2i
        for thickness = 0, IM_DRAWLIST_TEX_CORNERS_THICKNESS_MAX - 1 do
            local is_filled = (thickness == 0)
            local row_width = 0
            local row_height = 0
            for n = 0, IM_DRAWLIST_TEX_CORNERS_ROUNDING_MAX - 1 do
                local rounding = n + 1
                local size = is_filled and (rounding + 1) or ImMax(rounding, thickness)
                row_width = row_width + size + 2
                row_height = ImMax(row_height, size + 2)
            end
            pack_size_x = ImMax(pack_size_x, row_width)
            pack_size_y = pack_size_y + row_height
        end
        builder.PackIdCornersTexData = atlas:AddCustomRect(pack_size_x, pack_size_y, r)
        IM_ASSERT(builder.PackIdCornersTexData ~= ImFontAtlasRectId_Invalid)
    end

    -- Render
    local y = r.y
    local line_normals_x, line_normals_y, line_distances = corner_normals_x, corner_normals_y, corner_distances
    for thickness = 0, IM_DRAWLIST_TEX_CORNERS_THICKNESS_MAX - 1 do
        local is_filled = (thickness == 0)
        local x = r.x
        local row_height = 0
        for n = 0, IM_DRAWLIST_TEX_CORNERS_ROUNDING_MAX - 1 do
            -- Filled: Always add 1px to the fill side of the rounded corner to prevent the corner AA to bleed into the rectangle edges.
            local rounding = n + 1
            local size = is_filled and (rounding + 1) or ImMax(rounding, thickness)
            local w = size + 2
            local h = size + 2

            -- Corner circle
            local cx = 1.0 + (n + 1)
            local cy = 1.0 + (n + 1)
            IM_ASSERT((x + w) <= (r.x + r.w) and (y + h) <= (r.y + r.h)) -- Make sure we're inside the texture bounds
            local num_lines = InitCornerGeometry(cx, cy, rounding, circle_segment_max_error, line_normals_x, line_normals_y, line_distances)

            -- Write each slice
            if add_and_draw and tex.Format == ImTextureFormat.Alpha8 then
                local write_ptr, write_ptr_base = tex:GetPixelsAt(x, y)
                local pitch = tex.Width
                for ly = 0, h - 1 do
                    for lx = 0, w - 1 do
                        write_ptr[write_ptr_base + lx] = SampleCornerFillOrStroke(lx + 0.5, ly + 0.5, thickness, line_normals_x, line_normals_y, line_distances, num_lines)
                    end
                    write_ptr_base = write_ptr_base + pitch
                end
            elseif add_and_draw and tex.Format == ImTextureFormat.RGBA32 then
                local write_ptr, write_ptr_base = tex:GetPixelsAt(x, y)
                local pitch = tex.Width * 4
                for ly = 0, h - 1 do
                    for lx = 0, w - 1 do
                        write_u32(write_ptr, write_ptr_base + lx * 4, IM_COL32(255, 255, 255, SampleCornerFillOrStroke(lx + 0.5, ly + 0.5, thickness, line_normals_x, line_normals_y, line_distances, num_lines)))
                    end
                    write_ptr_base = write_ptr_base + pitch
                end
            end

            -- Refresh UV coordinates
            local uv0_x, uv0_y = (x + 1) * atlas.TexUvScale.x, (y + 1) * atlas.TexUvScale.y
            local uv1_x, uv1_y = (x + 1 + size) * atlas.TexUvScale.x, (y + 1 + size) * atlas.TexUvScale.y
            builder.TexUvCorners[n + thickness * IM_DRAWLIST_TEX_CORNERS_ROUNDING_MAX] = ImVec4(uv0_x, uv0_y, uv1_x, uv1_y)

            x = x + w
            row_height = ImMax(row_height, h)
        end
        y = y + row_height
    end
end

function ImFontAtlasBuildUpdateTexDataLines(atlas)
    if bit32.band(atlas.Flags, ImFontAtlasFlags.NoBakedLines) ~= 0 then
        return
    end

    -- Pack and store identifier so we can refresh UV coordinates on texture resize.
    local tex = atlas.TexData
    local builder = atlas.Builder

    local r = ImFontAtlasRect()
    local add_and_draw = (atlas:GetCustomRect(builder.PackIdLinesTexData, r) == false)
    if add_and_draw then
        -- Register texture region for thick lines
        -- The +2 here is to give space for the end caps, whilst height +1 is to accommodate the fact we have a zero-width row
        local pack_size = ImVec2(IM_DRAWLIST_TEX_LINES_WIDTH_MAX + 2, IM_DRAWLIST_TEX_LINES_WIDTH_MAX + 1 + IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH_COUNT) -- ImVec2i
        builder.PackIdLinesTexData = atlas:AddCustomRect(pack_size.x, pack_size.y, r)
        IM_ASSERT(builder.PackIdLinesTexData ~= ImFontAtlasRectId_Invalid)
    end

    do
        -- FIXME: Lines 0 to IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH(4) are currently never used and could be ditched, saving DETAILED_WIDTH*WIDTH_MAX
        for n = 0, IM_DRAWLIST_TEX_LINES_WIDTH_MAX do -- +1 because of the zero-width row
            -- Each line consists of at least two empty pixels at the ends, with a line of solid pixels in the middle
            local y = n
            local line_width = n
            local pad_left = math.floor((r.w - line_width) / 2)
            local pad_right = r.w - (pad_left + line_width)
            IM_ASSERT(pad_left + line_width + pad_right == r.w and y < r.h) -- Make sure we're inside the texture bounds before we start writing pixels

            -- Write each slice
            if add_and_draw and tex.Format == ImTextureFormat.Alpha8 then
                local write_ptr, write_ptr_base = tex:GetPixelsAt(r.x, r.y + y)
                for i = 0, pad_left - 1 do
                    write_ptr[write_ptr_base + i] = 0x00
                end
                for i = 0, line_width - 1 do
                    write_ptr[write_ptr_base + pad_left + i] = 0xFF
                end
                for i = 0, pad_right - 1 do
                    write_ptr[write_ptr_base + pad_left + line_width + i] = 0x00
                end
            elseif add_and_draw and tex.Format == ImTextureFormat.RGBA32 then
                local write_ptr, write_ptr_base = tex:GetPixelsAt(r.x, r.y + y)
                for i = 0, pad_left - 1 do
                    write_u32(write_ptr, write_ptr_base + i * 4, IM_COL32(255, 255, 255, 0))
                end
                for i = 0, line_width - 1 do
                    write_u32(write_ptr, write_ptr_base + (pad_left + i) * 4, IM_COL32_WHITE)
                end
                for i = 0, pad_right - 1 do
                    write_u32(write_ptr, write_ptr_base + (pad_left + line_width + i) * 4, IM_COL32(255, 255, 255, 0))
                end
            end

            -- Refresh UV coordinates
            local uv0_x, uv0_y = (r.x + pad_left - 0.5) * atlas.TexUvScale.x, (r.y + y) * atlas.TexUvScale.y
            local uv1_x, uv1_y = (r.x + pad_left + line_width + 0.5) * atlas.TexUvScale.x, (r.y + y + 1) * atlas.TexUvScale.y
            local half_v = (uv0_y + uv1_y) * 0.5 -- Calculate a constant V in the middle of the row to avoid sampling artifacts
            -- Store inverse of the line-width (thickness) to the w component so that we can avoid division when selecting texture.
            local inv_line_width = (line_width > 0) and (1.0 / line_width) or 0.0
            builder.TexUvLines[n] = ImVec4(uv0_x, uv1_x, half_v, inv_line_width)
        end
    end

    do
        -- Calculate super sampled line textures for smaller line widths to make transition between sizes smoother.

        -- Calculate ramp used for all the textures.
        local ramp = {} -- [Port] ImU8[IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT], 0-based
        for n = 0, IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT - 1 do
            ramp[n] = math.floor((n / IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT) * 255.0)
        end

        for n = 0, IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH_COUNT - 1 do
            local y = IM_DRAWLIST_TEX_LINES_WIDTH_MAX + 1 + n
            -- For integer thickness lines the one pixel line texture looks like this:
            -- [  0  |  1  |  0  ]
            --    :...........:
            -- Since the texture samples are at the center of the texel, we only use range above.
            -- The result after bilinear filtering is a triangle across the used uv range.
            --
            -- To super 2x sample that signal, we end up with following texture:
            -- [  0  |  .5 |  1  |  .5 |  0  ]
            --    :.......................:
            -- One might think that there should be 2 opaque pixels in the middle section, but no since we're super sampling the triangle signal.
            local line_width = 1 + n
            IM_ASSERT(IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT + line_width + IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT <= r.w and y < r.h) -- Make sure we're inside the texture bounds before we start writing pixels

            -- Write each slice
            if add_and_draw and tex.Format == ImTextureFormat.Alpha8 then
                local write_ptr, write_ptr_base = tex:GetPixelsAt(r.x, r.y + y)
                local idx = 0
                for i = 0, IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT - 1 do
                    write_ptr[write_ptr_base + idx] = ramp[i]; idx = idx + 1
                end
                for _ = 0, line_width - 1 do
                    write_ptr[write_ptr_base + idx] = 0xFF; idx = idx + 1
                end
                for i = IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT - 1, 0, -1 do
                    write_ptr[write_ptr_base + idx] = ramp[i]; idx = idx + 1
                end
                while idx < r.w do
                    write_ptr[write_ptr_base + idx] = 0x0; idx = idx + 1
                end
            elseif add_and_draw and tex.Format == ImTextureFormat.RGBA32 then
                local write_ptr, write_ptr_base = tex:GetPixelsAt(r.x, r.y + y)
                local idx = 0
                for i = 0, IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT - 1 do
                    write_u32(write_ptr, write_ptr_base + idx * 4, IM_COL32(255, 255, 255, ramp[i])); idx = idx + 1
                end
                for _ = 0, line_width - 1 do
                    write_u32(write_ptr, write_ptr_base + idx * 4, IM_COL32(255, 255, 255, 255)); idx = idx + 1
                end
                for i = IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT - 1, 0, -1 do
                    write_u32(write_ptr, write_ptr_base + idx * 4, IM_COL32(255, 255, 255, ramp[i])); idx = idx + 1
                end
                while idx < r.w do
                    write_u32(write_ptr, write_ptr_base + idx * 4, IM_COL32(255, 255, 255, 0)); idx = idx + 1
                end
            end

            -- Refresh UV coordinates
            local uv0_x, uv0_y = (r.x + 0.5) * atlas.TexUvScale.x, (r.y + y) * atlas.TexUvScale.y
            local uv1_x, uv1_y = (r.x - 0.5 + IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT * 2 + line_width) * atlas.TexUvScale.x, (r.y + y + 1) * atlas.TexUvScale.y
            local half_v = (uv0_y + uv1_y) * 0.5 -- Calculate a constant V in the middle of the row to avoid sampling artifacts
            -- Store inverse of the line-width (thickness) to the w component so that we can avoid division when selecting texture.
            local inv_line_width = 1.0 / (1.0 + n / IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT)
            builder.TexUvLines[IM_DRAWLIST_TEX_LINES_WIDTH_MAX + 1 + n] = ImVec4(uv0_x, uv1_x, half_v, inv_line_width)
        end
    end
end

-- Render a white-colored bitmap encoded in a string
--- @param atlas          ImFontAtlas
--- @param x              int
--- @param y              int
--- @param w              int
--- @param h              int
--- @param in_str         string[]
--- @param in_marker_char string
function ImFontAtlasBuildRenderBitmapFromString(atlas, x, y, w, h, in_str, in_marker_char)
    local tex = atlas.TexData
    IM_ASSERT(x >= 0 and x + w <= tex.Width)
    IM_ASSERT(y >= 0 and y + h <= tex.Height)

    if tex.Format == ImTextureFormat.Alpha8 then
        local out_p, out_p_base = tex:GetPixelsAt(x, y)
        local str_base = 1
        for off_y = 0, h - 1 do
            for off_x = 0, w - 1 do
                out_p[out_p_base + off_x] = (in_str[str_base + off_x] == in_marker_char) and 0xFF or 0x00
            end

            out_p_base = out_p_base + tex.Width
            str_base = str_base + w
        end
    elseif tex.Format == ImTextureFormat.RGBA32 then
        local out_p, out_p_base = tex:GetPixelsAt(x, y)
        local str_base = 1
        for off_y = 0, h - 1 do
            for off_x = 0, w - 1 do
                write_u32(out_p, out_p_base + off_x * 4, (in_str[str_base + off_x] == in_marker_char) and IM_COL32_WHITE or IM_COL32_BLACK_TRANS)
            end

            out_p_base = out_p_base + tex.Width * 4
            str_base = str_base + w
        end
    end
end

--- @param atlas ImFontAtlas
function ImFontAtlasBuildUpdateTexDataBasic(atlas)
    -- Pack and store identifier so we can refresh UV coordinates on texture resize.
    -- FIXME-NEWATLAS: User/custom rects where user code wants to store UV coordinates will need to do the same thing.
    local builder = atlas.Builder
    local pack_size = (bit32.band(atlas.Flags, ImFontAtlasFlags.NoMouseCursors) ~= 0) and ImVec2(2, 2) or ImVec2(FONT_ATLAS_DEFAULT_TEX_DATA_W * 2 + 1, FONT_ATLAS_DEFAULT_TEX_DATA_H)

    local r = ImFontAtlasRect()
    local add_and_draw = (atlas:GetCustomRect(builder.PackIdMouseCursors, r) == false)
    if (add_and_draw) then
        builder.PackIdMouseCursors = atlas:AddCustomRect(pack_size.x, pack_size.y, r)
        IM_ASSERT(builder.PackIdMouseCursors ~= ImFontAtlasRectId_Invalid)

        -- Draw to texture
        if bit32.band(atlas.Flags, ImFontAtlasFlags.NoMouseCursors) ~= 0 then
            -- 2x2 white pixels
            ImFontAtlasBuildRenderBitmapFromString(atlas, r.x, r.y, 2, 2, {"X", "X", "X", "X"}, "X")
        else
            -- 2x2 white pixels + mouse cursors
            local x_for_white = r.x
            local x_for_black = r.x + FONT_ATLAS_DEFAULT_TEX_DATA_W + 1
            ImFontAtlasBuildRenderBitmapFromString(atlas, x_for_white, r.y, FONT_ATLAS_DEFAULT_TEX_DATA_W, FONT_ATLAS_DEFAULT_TEX_DATA_H, FONT_ATLAS_DEFAULT_TEX_DATA_PIXELS, ".")
            ImFontAtlasBuildRenderBitmapFromString(atlas, x_for_black, r.y, FONT_ATLAS_DEFAULT_TEX_DATA_W, FONT_ATLAS_DEFAULT_TEX_DATA_H, FONT_ATLAS_DEFAULT_TEX_DATA_PIXELS, "X")
        end
    end

    -- Refresh UV coordinates
    atlas.TexUvWhitePixel = ImVec2((r.x + 0.5) * atlas.TexUvScale.x, (r.y + 0.5) * atlas.TexUvScale.y)
end

-- Update texture coordinates in all draw list shared context
-- FIXME-NEWATLAS FIXME-OPT: Doesn't seem necessary to update for all, only one bound to current context?
function ImFontAtlasUpdateDrawListsSharedData(atlas)
    for _, shared_data in atlas.DrawListSharedDatas:iter() do
        if (shared_data.FontAtlas == atlas) then
            shared_data.TexUvWhitePixel = atlas.TexUvWhitePixel
            shared_data.TexUvLines = atlas.Builder.TexUvLines
            shared_data.TexUvCorners = atlas.Builder.TexUvCorners
        end
    end
end

-- Start packing over current empty texture
function ImFontAtlasBuildInit(atlas)
    -- Select Backend
    -- - Note that we do not reassign to atlas.FontLoader, since it is likely to point to static data which
    --   may mess with some hot-reloading schemes. If you need to assign to this (for dynamic selection) AND are
    --   using a hot-reloading scheme that messes up static data, store your own instance of FontLoader somewhere
    --   and point to it instead of pointing directly to return value of the GetFontLoaderXXX functions.
    if atlas.FontLoader == nil then
        -- IMGUI_ENABLE_STB_TRUETYPE
        atlas:SetFontLoader(ImFontAtlasGetFontLoaderForStbTruetype())
    end

    -- Create initial texture size
    if atlas.TexData == nil or atlas.TexData.Pixels == nil then
        ImFontAtlasTextureAdd(atlas, ImUpperPowerOfTwo(atlas.TexMinWidth), ImUpperPowerOfTwo(atlas.TexMinHeight))
    end
    atlas.Builder = ImFontAtlasBuilder()
    if atlas.FontLoader.LoaderInit then
        atlas.FontLoader.LoaderInit(atlas)
    end

    ImFontAtlasBuildUpdateRendererHasTexturesFromContext(atlas)

    ImFontAtlasPackInit(atlas)

    -- Add required texture data
    ImFontAtlasBuildUpdateTexData(atlas)

    -- Register fonts
    ImFontAtlasBuildUpdatePointers(atlas)

    -- Update UV coordinates etc. stored in bound ImDrawListSharedData instance
    ImFontAtlasUpdateDrawListsSharedData(atlas)

    --atlas.TexIsBuilt = true

    -- Lazily initialize char/text classifier
    -- FIXME: This could be practically anywhere, and should eventually be parameters to CalcTextSize/word-wrapping code, but there's no obvious spot now.
    ImTextInitClassifiers()
end

-- Destroy builder and all cached glyphs. Do not destroy actual fonts.
--- @param atlas ImFontAtlas
function ImFontAtlasBuildDestroy(atlas)
    for _, font in atlas.Fonts:iter() do
        ImFontAtlasFontDestroyOutput(atlas, font)
    end
    if atlas.Builder and atlas.FontLoader and atlas.FontLoader.LoaderShutdown then
        atlas.FontLoader.LoaderShutdown(atlas)
        IM_ASSERT(atlas.FontLoaderData == nil)
    end
    atlas.Builder = nil
end

-- On font removal we need to remove references (otherwise we could queue removal?)
-- We allow old_font == new_font which forces updating all values (e.g. sizes)
--- @param atlas    ImFontAtlas
--- @param old_font ImFont?
--- @param new_font ImFont?
function ImFontAtlasBuildNotifySetFont(atlas, old_font, new_font)
    for _, shared_data in atlas.DrawListSharedDatas:iter() do
        if shared_data.Font == old_font then
            shared_data.Font = new_font
        end
        local ctx = shared_data.Context
        if ctx then
            repeat
            -- While this should work either way, we save ourselves the bother / debugging confusion of running ImGui code so early when it is not needed.
            -- Also fixes erroneously rewriting style.FontSizeBase during init if adding default fonts.
            if old_font == nil and ctx.Font == nil and ctx.FontSizeBase == 0.0 then

                break
            end

            if ctx.IO.FontDefault == old_font then
                ctx.IO.FontDefault = new_font
            end
            if ctx.Font == old_font then
                local curr_ctx = ImGui.GetCurrentContext()
                local need_bind_ctx = ctx ~= curr_ctx
                if need_bind_ctx then
                    ImGui.SetCurrentContext(ctx)
                end
                ImGui.SetCurrentFont(new_font, ctx.FontSizeBase, ctx.FontSize)
                if need_bind_ctx then
                    ImGui.SetCurrentContext(curr_ctx)
                end
            end
            for _, font_stack_data in ctx.FontStack:iter() do
                if font_stack_data.Font == old_font then
                    font_stack_data.Font = new_font
                end
            end

            until true
        end
    end
end

-- When atlas.RendererHasTextures = true, this is only called if no font were loaded.
--- @param atlas ImFontAtlas
function ImFontAtlasBuildMain(atlas)
    IM_ASSERT(not atlas.Locked, "Cannot modify a locked ImFontAtlas!")
    if (atlas.TexData and atlas.TexData.Format ~= atlas.TexDesiredFormat) then
        ImFontAtlasBuildClear(atlas)
    end

    if atlas.Builder == nil then
        ImFontAtlasBuildInit(atlas)
    end

    -- Default font is none are specified
    if atlas.Sources.Size == 0 then
        atlas:AddFontDefault()
    end

    -- [LEGACY] For backends not supporting RendererHasTextures: preload all glyphs
    -- [Port] ImFontAtlasBuildUpdateRendererHasTexturesFromContext(atlas);
    -- if atlas.RendererHasTextures == false then -- ~ImGuiBackendFlags.RendererHasTextures
    --     ImFontAtlasBuildLegacyPreloadAllGlyphRanges(atlas)
    -- end

    atlas.TexIsBuilt = true
end

-- [Luau] Ported but its call above stays disabled: the Roblox/LÖVE backends support RendererHasTextures.
function ImFontAtlasBuildLegacyPreloadAllGlyphRanges(atlas)
    atlas.Builder.PreloadedAllGlyphsRanges = true
    for _, font in atlas.Fonts:iter() do
        local baked = font:GetFontBaked(font.LegacySize)
        if font.FallbackChar ~= 0 then
            baked:FindGlyph(font.FallbackChar)
        end
        if font.EllipsisChar ~= 0 then
            baked:FindGlyph(font.EllipsisChar)
        end
        for _, src in font.Sources:iter() do
            local ranges = src.GlyphRanges and src.GlyphRanges or atlas:GetGlyphRangesDefault()
            local i = 1
            while ranges[i] ~= 0 do
                local c = ranges[i]
                while c <= ranges[i + 1] and c <= IM_UNICODE_CODEPOINT_MAX do
                    baked:FindGlyph(c)
                    c = c + 1
                end
                i = i + 2
            end
        end
    end
end

-------------------------------------------------------------------------------
-- [SECTION] ImTextureData
-------------------------------------------------------------------------------
-- - ImTextureData:Create()
-- - ImTextureData:DestroyPixels()
-------------------------------------------------------------------------------

--- @param status ImTextureStatus
function ImTextureDataGetStatusName(status)
    if status == ImTextureStatus.OK then return "OK"
    elseif status == ImTextureStatus.Destroyed then return "Destroyed"
    elseif status == ImTextureStatus.WantCreate then return "WantCreate"
    elseif status == ImTextureStatus.WantUpdates then return "WantUpdates"
    elseif status == ImTextureStatus.WantDestroy then return "WantDestroy"
    end
    return "N/A"
end

--- @param format ImTextureFormat
function ImTextureDataGetFormatName(format)
    if format == ImTextureFormat.Alpha8 then return "Alpha8"
    elseif format == ImTextureFormat.RGBA32 then return "RGBA32"
    end
    return "N/A"
end

function MT.ImTextureData:DestroyPixels()
    self.Pixels = nil
    self.UseColors = false
end

function ImTextureDataGetFormatBytesPerPixel(format)
    if format == ImTextureFormat.Alpha8 then
        return 1
    elseif format == ImTextureFormat.RGBA32 then
        return 4
    end
    IM_ASSERT(false)
    return 0
end

function MT.ImTextureData:Create(format, w, h)
    IM_ASSERT(self.Status == ImTextureStatus.Destroyed)
    self:DestroyPixels()
    self.Format = format
    self.Status = ImTextureStatus.WantCreate
    self.Width = w
    self.Height = h
    self.BytesPerPixel = ImTextureDataGetFormatBytesPerPixel(format)
    self.UseColors = false
    local n = self.Width * self.Height * self.BytesPerPixel
    if RecycledTexPixels ~= nil and RecycledTexPixelsSize == n then
        -- [Luau] same contents as memset: zero the first block, then double it with table.move (native copies)
        local p, k = RecycledTexPixels, math.min(n, 4096)
        RecycledTexPixels, RecycledTexPixelsSize = nil, 0
        for i = 1, k do p[i] = 0 end
        while k < n do
            local c = math.min(k, n - k)
            table.move(p, 1, c, k + 1)
            k = k + c
        end
        self.Pixels = p
    elseif table.create then
        self.Pixels = table.create(n, 0) -- [Luau] native zero fill, same contents as memset
    else
        self.Pixels = {}
        ImStd.memset(self.Pixels, 0, n)
    end
    self.UsedRect.x = 0
    self.UsedRect.y = 0
    self.UsedRect.w = 0
    self.UsedRect.h = 0
    self.UpdateRect.x = 65535
    self.UpdateRect.y = 65535
    self.UpdateRect.w = 0
    self.UpdateRect.h = 0
end

-------------------------------------------------------------------------------
-- [SECTION] ImFontAtlas: glyph ranges helpers
-------------------------------------------------------------------------------
-- - GetGlyphRangesDefault()
-- [Luau] The obsolete GetGlyphRangesXXX() (IMGUI_DISABLE_OBSOLETE_FUNCTIONS) are not ported.
-------------------------------------------------------------------------------

-- Retrieve list of range (2 int per range, values are inclusive)
local GlyphRangesDefault =
{
    0x0020, 0x00FF, -- Basic Latin + Latin Supplement
    0,
}
function MT.ImFontAtlas:GetGlyphRangesDefault()
    return GlyphRangesDefault
end

-------------------------------------------------------------------------------
-- [SECTION] ImFontGlyphRangesBuilder
-------------------------------------------------------------------------------

--- @param text      ImString
--- @param text_end? int       # exclusive, 1-based
function MT.ImFontGlyphRangesBuilder:AddText(text, text_end)
    if text_end == nil then
        text_end = #text + 1
    end
    local s = 1
    while s < text_end do
        local c_len, c = ImStd.ImTextCharFromUtf8(text, s, text_end)
        s = s + c_len
        if c_len == 0 then
            break
        end
        self:AddChar(c)
    end
end

--- @param ranges ImWchar[] # 1-based, zero-terminated
function MT.ImFontGlyphRangesBuilder:AddRanges(ranges)
    local i = 1
    while ranges[i] ~= 0 do
        local c = ranges[i]
        while c <= ranges[i + 1] and c <= IM_UNICODE_CODEPOINT_MAX do
            self:AddChar(c)
            c = c + 1
        end
        i = i + 2
    end
end

--- @param out_ranges ImVector<ImWchar>
function MT.ImFontGlyphRangesBuilder:BuildRanges(out_ranges)
    local max_codepoint = IM_UNICODE_CODEPOINT_MAX
    local n = 0
    while n <= max_codepoint do
        if self:GetBit(n) then
            out_ranges:push_back(n)
            while n < max_codepoint and self:GetBit(n + 1) do
                n = n + 1
            end
            out_ranges:push_back(n)
        end
        n = n + 1
    end
    out_ranges:push_back(0)
end

-------------------------------------------------------------------------------
-- [SECTION] ImFontBaked, ImFont
-------------------------------------------------------------------------------

function MT.ImFontBaked:ClearOutputData()
    self.FallbackAdvanceX = 0.0
    self.Glyphs:clear()
    self.IndexAdvanceX:clear()
    self.IndexLookup:clear()
    self.FallbackGlyphIndex = -1
    self.Ascent = 0.0
    self.Descent = 0.0
    self.MetricsTotalSurface = 0
end

-- Find glyph, load if necessary, return fallback if missing
--- @param c ImWchar
--- @return ImFontGlyph?
@native
function MT.ImFontBaked:FindGlyph(c)
    if c < self.IndexLookup.Size then
        local i = self.IndexLookup.Data[c + 1]
        if i == IM_FONTGLYPH_INDEX_NOT_FOUND then
            return self.Glyphs.Data[self.FallbackGlyphIndex]
        end
        if i ~= IM_FONTGLYPH_INDEX_UNUSED then
            return self.Glyphs.Data[i]
        end
    end

    local glyph = ImFontBaked_BuildLoadGlyph(self, c, nil)
    return (glyph) and glyph or self.Glyphs.Data[self.FallbackGlyphIndex]
end

function MT.ImFontBaked:IsGlyphLoaded(c)
    if c >= self.IndexLookup.Size then return false end
    return self.IndexLookup.Data[c + 1] ~= IM_FONTGLYPH_INDEX_UNUSED
end

-- Attempt to load but when missing, return nil instead of FallbackGlyph
--- @param c ImWchar
--- @return ImFontGlyph?
function MT.ImFontBaked:FindGlyphNoFallback(c)
    if c < self.IndexLookup.Size then -- [Port] IM_LIKELY
        local i = self.IndexLookup.Data[c + 1]
        if i == IM_FONTGLYPH_INDEX_NOT_FOUND then
            return nil
        end
        if i ~= IM_FONTGLYPH_INDEX_UNUSED then
            return self.Glyphs.Data[i]
        end
    end

    self.LoadNoFallback = true -- This is actually a rare call, not done in hot-loop, so we prioritize not adding extra cruft to ImFontBaked_BuildLoadGlyph() call sites.
    local glyph = ImFontBaked_BuildLoadGlyph(self, c, nil)
    self.LoadNoFallback = false
    return glyph
end

function MT.ImFont:ClearOutputData()
    local atlas = self.OwnerAtlas
    if atlas ~= nil then
        ImFontAtlasFontDiscardBakes(atlas, self, 0)
    end
    --self.FallbackChar = 0 self.EllipsisChar = 0

    for i = 1, (IM_UNICODE_CODEPOINT_MAX + 1) / 8192 / 8 do self.Used8kPagesMap[i] = 0 end
    self.LastBaked = nil
end

-- API is designed this way to avoid exposing the 8K page size
-- e.g. use with IsGlyphRangeUnused(0, 255)
function MT.ImFont:IsGlyphRangeUnused(c_begin, c_last)
    local page_begin = math.floor(c_begin / 8192)
    local page_last = math.floor(c_last / 8192)
    for page_n = page_begin, page_last do
        if bit32.rshift(page_n, 3) < (IM_UNICODE_CODEPOINT_MAX + 1) / 8192 / 8 then -- [Port] sizeof(Used8kPagesMap)
            if bit32.band(self.Used8kPagesMap[bit32.rshift(page_n, 3) + 1] or 0, bit32.lshift(1, bit32.band(page_n, 7))) ~= 0 then
                return false
            end
        end
    end
    return true
end

--- @param font_id            ImGuiID
--- @param baked_size         float
--- @param rasterizer_density float
--- @return ImGuiID
function ImFontAtlasBakedGetId(font_id, baked_size, rasterizer_density)
    local hashed_data = {font_id, baked_size, rasterizer_density}
    return ImHashData(hashed_data)
end

--- @param atlas                   ImFontAtlas
--- @param font                    ImFont
--- @param font_size               float
--- @param font_rasterizer_density float
--- @return ImFontBaked?
function ImFontAtlasBakedGetOrAdd(atlas, font, font_size, font_rasterizer_density)
    -- FIXME-NEWATLAS: Design for picking a nearest size based on some criteria?
    -- FIXME-NEWATLAS: Altering font density won't work right away.
    IM_ASSERT(font_size > 0.0 and font_rasterizer_density > 0.0)
    local baked_id = ImFontAtlasBakedGetId(font.FontId, font_size, font_rasterizer_density)
    local builder = atlas.Builder
    local baked = builder.BakedMap[baked_id]
    if baked ~= nil then
        IM_ASSERT(baked.Size == font_size and baked.OwnerFont == font and baked.BakedId == baked_id)

        return baked
    end

    -- If atlas is locked, find closest match
    -- FIXME-OPT: This is not an optimal query.
    if (bit32.band(font.Flags, ImFontFlags.LockBakedSizes) ~= 0 or atlas.Locked) then
        baked = ImFontAtlasBakedGetClosestMatch(atlas, font, font_size, font_rasterizer_density)
        if baked ~= nil then
            return baked
        end
        if atlas.Locked then
            IM_ASSERT(not atlas.Locked, "Cannot use dynamic font size with a locked ImFontAtlas!") -- Locked because rendering backend does not support ImGuiBackendFlags.RendererHasTextures!
            return nil
        end
    end

    -- Create new
    baked = ImFontAtlasBakedAdd(atlas, font, font_size, font_rasterizer_density, baked_id)
    builder.BakedMap[baked_id] = baked

    return baked
end

-- x0/y0/x1/y1 are offset from the character upper-left layout position, in pixels. Therefore x0/y0 are often fairly close to zero.
-- Not to be mistaken with texture coordinates, which are held by u0/v0/u1/v1 in normalized format (0.0..1.0 on each texture axis).
-- - 'src' is not necessarily == 'self.Sources' because multiple source fonts+configs can be used to build one target font.
--- @param atlas    ImFontAtlas
--- @param baked    ImFontBaked
--- @param src?     ImFontConfig
--- @param in_glyph ImFontGlyph
--- @return ImFontGlyph
function ImFontAtlasBakedAddFontGlyph(atlas, baked, src, in_glyph)
    local glyph_idx = baked.Glyphs.Size + 1
    baked.Glyphs:push_back(in_glyph)
    local glyph = baked.Glyphs.Data[glyph_idx]
    IM_ASSERT(baked.Glyphs.Size < 0xFFFE) -- IndexLookup[] hold 16-bit values and -1/-2 are reserved.

    -- Set UV from packed rectangle
    if (glyph.PackId ~= ImFontAtlasRectId_Invalid) then
        local r = ImFontAtlasPackGetRect(atlas, glyph.PackId)
        IM_ASSERT(glyph.U0 == 0.0 and glyph.V0 == 0.0 and glyph.U1 == 0.0 and glyph.V1 == 0.0)
        glyph.U0 = (r.x) * atlas.TexUvScale.x
        glyph.V0 = (r.y) * atlas.TexUvScale.y
        glyph.U1 = (r.x + r.w) * atlas.TexUvScale.x
        glyph.V1 = (r.y + r.h) * atlas.TexUvScale.y
        baked.MetricsTotalSurface = baked.MetricsTotalSurface + r.w * r.h
    end

    if (src ~= nil) then
        -- Clamp & recenter if needed
        local ref_size = baked.OwnerFont.Sources[1].SizePixels
        local offsets_scale = (ref_size ~= 0.0) and (baked.Size / ref_size) or 1.0
        local advance_x = ImClamp(glyph.AdvanceX, src.GlyphMinAdvanceX * offsets_scale, src.GlyphMaxAdvanceX * offsets_scale)
        if (advance_x ~= glyph.AdvanceX) then
            local char_off_x = src.PixelSnapH and ImTrunc((advance_x - glyph.AdvanceX) * 0.5) or (advance_x - glyph.AdvanceX) * 0.5
            glyph.X0 = glyph.X0 + char_off_x
            glyph.X1 = glyph.X1 + char_off_x
        end

        -- Snap to pixel
        if (src.PixelSnapH) then
            advance_x = IM_ROUND(advance_x)
        end

        -- Bake spacing
        glyph.AdvanceX = advance_x + src.GlyphExtraAdvanceX
    end
    if (glyph.Colored) then
        atlas.TexData.UseColors  = true
        atlas.TexPixelsUseColors = true
    end

    -- Update lookup tables
    local codepoint = glyph.Codepoint
    ImFontBaked_BuildGrowIndex(baked, codepoint + 1)
    baked.IndexAdvanceX.Data[codepoint + 1] = glyph.AdvanceX
    baked.IndexLookup.Data[codepoint + 1] = glyph_idx -- [Port] (ImU16)
    local page_n = math.floor(codepoint / 8192)
    baked.OwnerFont.Used8kPagesMap[bit32.rshift(page_n, 3) + 1] = bit32.bor(baked.OwnerFont.Used8kPagesMap[bit32.rshift(page_n, 3) + 1], bit32.lshift(1, bit32.band(page_n, 7)))

    return glyph
end

-- FIXME: Code is duplicated with code above.
--- @param atlas     ImFontAtlas
--- @param baked     ImFontBaked
--- @param src?      ImFontConfig
--- @param codepoint ImWchar
--- @param advance_x float
function ImFontAtlasBakedAddFontGlyphAdvancedX(atlas, baked, src, codepoint, advance_x)
    -- [Port] IM_UNUSED(atlas)
    if (src ~= nil) then
        -- Clamp & recenter if needed
        local ref_size = baked.OwnerFont.Sources[1].SizePixels
        local offsets_scale = (ref_size ~= 0.0) and (baked.Size / ref_size) or 1.0
        advance_x = ImClamp(advance_x, src.GlyphMinAdvanceX * offsets_scale, src.GlyphMaxAdvanceX * offsets_scale)

        -- Snap to pixel
        if (src.PixelSnapH) then
            advance_x = IM_ROUND(advance_x)
        end

        -- Bake spacing
        advance_x = advance_x + src.GlyphExtraAdvanceX
    end

    ImFontBaked_BuildGrowIndex(baked, codepoint + 1)
    baked.IndexAdvanceX.Data[codepoint + 1] = advance_x
end

-- ImFontBaked are valid for the entire frame but shall never be kept between frames.
--- @param size    float
--- @param density float?
--- @return ImFontBaked?
@native
function MT.ImFont:GetFontBaked(size, density)
    if not density then density = -1.0 end

    --- @type ImFontBaked?
    local baked = self.LastBaked

    -- Round font size
    -- - ImGui.PushFont() will already round, but other paths calling GetFontBaked() directly also needs it (e.g. ImFontAtlasBuildPreloadAllGlyphRanges)
    size = math.floor(size + 0.5) -- [Luau] inline ImGui.GetRoundedFontSize() == IM_ROUND()

    if density < 0.0 then
        density = self.CurrentRasterizerDensity
    end
    if baked and baked.Size == size and baked.RasterizerDensity == density then
        return baked
    end

    local atlas = self.OwnerAtlas
    local builder = atlas.Builder
    baked = ImFontAtlasBakedGetOrAdd(atlas, self, size, density)
    if baked == nil then
        return nil
    end
    baked.LastUsedFrame = builder.FrameCount
    self.LastBaked = baked

    return baked
end

-- Makes 'from_codepoint' character points to 'to_codepoint' glyph.
-- [Luau] AddRemapCodepointToGlyphIndex() not ported: needs the 1.93 loader split (FontSrcGetGlyphIndexFromCodepoint).
function MT.ImFont:AddRemapCodepoint(from_codepoint, to_codepoint)
    local data = to_codepoint
    IM_ASSERT(bit32.band(data, bit32.lshift(1, 31)) == 0)
    self.RemapPairs[from_codepoint] = data
end

--- @param atlas ImFontAtlas
--- @param font  ImFont
--- @param c     ImWchar
--- @return ImWchar
--- @nodiscard
local function ImFontAtlas_FontHookRemapCodepoint(atlas, font, c)
    -- [Port] IM_UNUSED(atlas)
    if next(font.RemapPairs) ~= nil then -- [Luau] font->RemapPairs.Data.Size != 0 (RemapPairs is a hash table)
        local ret = font.RemapPairs[c]
        return (ret ~= nil) and ret or c
    end

    return c
end

--- @param baked                ImFontBaked
--- @param codepoint            ImWchar
--- @param only_load_advance_x? float
--- @return ImFontGlyph?
--- @return float?       # Updated `only_load_advance_x`
function ImFontBaked_BuildLoadGlyph(baked, codepoint, only_load_advance_x)
    local font = baked.OwnerFont
    local atlas = font.OwnerAtlas
    if atlas.Locked or bit32.band(font.Flags, ImFontFlags.NoLoadGlyphs) ~= 0 then
        -- Lazily load fallback glyph
        if baked.FallbackGlyphIndex == -1 and baked.LoadNoFallback == false then
            ImFontAtlasBuildSetupFontBakedFallback(baked)
        end

        return nil, only_load_advance_x
    end

    -- User remapping hooks
    local src_codepoint = codepoint
    codepoint = ImFontAtlas_FontHookRemapCodepoint(atlas, font, codepoint)

    --IMGUI_DEBUG_LOG("[font] BuildLoadGlyph U+%04X (%s)", codepoint, ImTextCharToUtf8(codepoint))

    -- Special hook
    -- FIXME-NEWATLAS: it would be nicer if this used a more standardized way of hooking
    if (codepoint == font.EllipsisChar and font.EllipsisAutoBake) then
        local glyph = ImFontAtlasBuildSetupFontBakedEllipsis(atlas, baked)
        if (glyph) then
            return glyph, only_load_advance_x
        end
    end

    -- Call backend
    local loader_user_data_p = baked.FontLoaderDatas
    local src_n = 1
    for _, src in font.Sources:iter() do
        local loader = src.FontLoader and src.FontLoader or atlas.FontLoader

        if (not src.GlyphExcludeRanges or ImFontAtlasBuildAcceptCodepointForSource(src, codepoint)) then
            if only_load_advance_x == nil then
                local glyph_buf = ImFontGlyph()

                if loader.FontBakedLoadGlyph(atlas, src, baked, loader_user_data_p, codepoint, glyph_buf, nil) then
                    -- FIXME: Add hooks for e.g. #7962
                    glyph_buf.Codepoint = src_codepoint
                    glyph_buf.SourceIdx = src_n

                    return ImFontAtlasBakedAddFontGlyph(atlas, baked, src, glyph_buf)
                end
            else
                -- Special mode but only loading glyphs metrics. Will rasterize and pack later.
                local ret --[[@as bool]]
                ret, only_load_advance_x = loader.FontBakedLoadGlyph(atlas, src, baked, loader_user_data_p, codepoint, nil, only_load_advance_x)
                if ret then
                    --- @cast only_load_advance_x float
                    ImFontAtlasBakedAddFontGlyphAdvancedX(atlas, baked, src, codepoint, only_load_advance_x)

                    return nil, only_load_advance_x
                end
            end
        end

        -- [Port] loader_user_data_p = loader_user_data_p + loader.FontBakedSrcLoaderDataSize
        src_n = src_n + 1
    end

    -- Lazily load fallback glyph
    if (baked.LoadNoFallback) then
        return nil, only_load_advance_x
    end
    if (baked.FallbackGlyphIndex == -1) then
        ImFontAtlasBuildSetupFontBakedFallback(baked)
    end

    -- Mark index as not found, so we don't attempt the search twice
    ImFontBaked_BuildGrowIndex(baked, codepoint + 1);
    baked.IndexAdvanceX.Data[codepoint + 1] = baked.FallbackAdvanceX
    baked.IndexLookup.Data[codepoint + 1] = IM_FONTGLYPH_INDEX_NOT_FOUND

    return nil, only_load_advance_x
end

--- @param baked ImFontBaked
--- @param codepoint ImWchar
--- @return float
function ImFontBaked_BuildLoadGlyphAdvanceX(baked, codepoint)
    if (baked.Size >= IMGUI_FONT_SIZE_THRESHOLD_FOR_LOADADVANCEXONLYMODE) or baked.LoadNoRenderOnLayout then
        -- First load AdvanceX value used by CalcTextSize() API then load the rest when loaded by drawing API.
        local only_advance_x
        local glyph
        glyph, only_advance_x = ImFontBaked_BuildLoadGlyph(baked, codepoint, only_advance_x)
        --- @cast only_advance_x float
        return glyph and glyph.AdvanceX or only_advance_x
    else
        local glyph = ImFontBaked_BuildLoadGlyph(baked, codepoint, nil)
        return glyph and glyph.AdvanceX or baked.FallbackAdvanceX
    end
end

-- This is not fast query
--- @param c ImWchar
--- @return bool
function MT.ImFont:IsGlyphInFont(c)
    local atlas = self.OwnerAtlas
    c = ImFontAtlas_FontHookRemapCodepoint(atlas, self, c)
    for _, src in self.Sources:iter() do
        local loader = src.FontLoader and src.FontLoader or atlas.FontLoader
        if loader.FontSrcContainsGlyph ~= nil and loader.FontSrcContainsGlyph(atlas, src, c) then
            return true
        end
    end

    return false
end

-- This is manually inlined in CalcTextSizeA() and CalcWordWrapPosition(), with a non-inline call to BuildLoadGlyphGetAdvanceOrFallback().
--- @param c ImWchar
--- @return float
function MT.ImFontBaked:GetCharAdvance(c)
    if c < self.IndexAdvanceX.Size then
        -- Missing glyphs fitting inside index will have stored FallbackAdvanceX already.
        local x = self.IndexAdvanceX.Data[c + 1]
        if x >= 0.0 then
            return x
        end
    end
    return ImFontBaked_BuildLoadGlyphAdvanceX(self, c)
end

-- The point of this indirection is to not be inlined in debug mode in order to not bloat inner loop.b
function BuildLoadGlyphGetAdvanceOrFallback(baked, codepoint)
    return ImFontBaked_BuildLoadGlyphAdvanceX(baked, codepoint)
end

-- Trim trailing space and find beginning of next line
--- @param text       ImString
--- @param text_begin int
--- @param text_end   int
--- @param flags      ImDrawTextFlags
--- @return int
local function ImTextCalcWordWrapNextLineStart(text, text_begin, text_end, flags)
    local pos = text_begin

    if bit32.band(flags, ImDrawTextFlags.WrapKeepBlanks) == 0 then
        while pos < text_end and ImCharIsBlankA(ImStrByte(text, pos)) do
            pos = pos + 1
        end
    end

    if pos < text_end and ImStrByte(text, pos) == 10 then -- '\n'
        pos = pos + 1
    end

    return pos
end

--- @param bits          ImU32[]
--- @param codepoint_min unsigned_int
--- @param codepoint_end unsigned_int
--- @param char_class    ImWcharClass
function ImTextClassifierClear(bits, codepoint_min, codepoint_end, char_class)
    for c = codepoint_min, codepoint_end - 1 do
        ImTextClassifierSetCharClass(bits, codepoint_min, codepoint_end, char_class, c)
    end
end

--- @param bits          ImU32[]
--- @param codepoint_min unsigned_int
--- @param codepoint_end unsigned_int
--- @param char_class    ImWcharClass
--- @param c             unsigned_int
function ImTextClassifierSetCharClass(bits, codepoint_min, codepoint_end, char_class, c)
    IM_ASSERT(c >= codepoint_min and c < codepoint_end)
    -- [Port] IM_UNUSED(codepoint_end)
    c = c - codepoint_min
    local shift = bit32.lshift(bit32.band(c, 15), 1)
    bits[bit32.rshift(c, 4) + 1] = bit32.bor(bit32.band(bits[bit32.rshift(c, 4) + 1], bit32.bnot(bit32.lshift(0x03, shift))), bit32.lshift(char_class, shift))
end

function ImTextClassifierSetCharClassFromStr(bits, codepoint_min, codepoint_end, char_class, s)
    local s_end = #s + 1
    local pos = 1
    while (pos < s_end) do
        local wanted, c = ImStd.ImTextCharFromUtf8(s, pos, s_end)
        pos = pos + wanted
        ImTextClassifierSetCharClass(bits, codepoint_min, codepoint_end, char_class, c)
    end
end

function ImTextClassifierGet(_BITS, _CHAR_OFFSET)
    return bit32.band(bit32.rshift(_BITS[bit32.rshift(_CHAR_OFFSET, 4) + 1], bit32.lshift(bit32.band(_CHAR_OFFSET, 15), 1)), 0x03)
end

-- 2-bit per character
local g_CharClassifierIsSeparator_0000_007f = {} for i = 1, 128 / 16 do g_CharClassifierIsSeparator_0000_007f[i] = 0 end
local g_CharClassifierIsSeparator_3000_300f = {} for i = 1, 16 / 16 do g_CharClassifierIsSeparator_3000_300f[i] = 0 end

function ImTextInitClassifiers()
    if (ImTextClassifierGet(g_CharClassifierIsSeparator_0000_007f, 44) ~= 0) then -- ','
        return
    end

    -- List of hardcoded separators: .,;!?'"
    -- Making this dynamic given known ranges is trivial BUT requires us to standardize where you pass them as parameters. (#3002, #8503)
    ImTextClassifierClear(g_CharClassifierIsSeparator_0000_007f, 0, 128, ImWcharClass.Other)
    ImTextClassifierSetCharClassFromStr(g_CharClassifierIsSeparator_0000_007f, 0, 128, ImWcharClass.Blank, " \t")
    ImTextClassifierSetCharClassFromStr(g_CharClassifierIsSeparator_0000_007f, 0, 128, ImWcharClass.Punct, ".,;!?\"")

    ImTextClassifierClear(g_CharClassifierIsSeparator_3000_300f, 0x3000, 0x300F, ImWcharClass.Other)
    ImTextClassifierSetCharClass(g_CharClassifierIsSeparator_3000_300f, 0x3000, 0x300F, ImWcharClass.Blank, 0x3000)
    ImTextClassifierSetCharClass(g_CharClassifierIsSeparator_3000_300f, 0x3000, 0x300F, ImWcharClass.Punct, 0x3001)
    ImTextClassifierSetCharClass(g_CharClassifierIsSeparator_3000_300f, 0x3000, 0x300F, ImWcharClass.Punct, 0x3002)
end

-- Simple word-wrapping for English, not full-featured. Please submit failing cases!
-- This will return the next location to wrap from. If no wrapping if necessary, this will fast-forward to e.g. text_end.
-- Refer to imgui_test_suite's "drawlist_text_wordwrap_1" for tests.
--- @param font       ImFont
--- @param size       float
--- @param text       ImString
--- @param pos        int
--- @param text_end   int
--- @param wrap_width float
--- @param flags      ImDrawTextFlags
--- @return int
local ImFontCalcWordWrapPositionEx_Uncached
local WRAP_MEMO_MAX = 4096

function ImFontCalcWordWrapPositionEx(font, size, text, pos, text_end, wrap_width, flags)
    local baked = font.LastBaked -- [Luau] inline font:GetFontBaked(size) fast path
    if not (baked and baked.Size == math.floor(size + 0.5) and baked.RasterizerDensity == font.CurrentRasterizerDensity) then
        baked = font:GetFontBaked(size)
    end
    if type(text) ~= "string" then
        return ImFontCalcWordWrapPositionEx_Uncached(baked, size, text, pos, text_end, wrap_width, flags)
    end
    -- [Luau] memo per baked font and string: CalcTextSize() and RenderText() of wrapped text ask for the same wrap points
    -- (same text/pos/width) every frame. The result only depends on these inputs and the (immutable once loaded) glyph advances.
    local memo = baked._WrapMemo
    if memo == nil or baked._WrapMemoN >= WRAP_MEMO_MAX then
        memo = {}; baked._WrapMemo = memo; baked._WrapMemoN = 0
    end
    local e = memo[text]
    if e == nil or e.ww ~= wrap_width or e.size ~= size or e.te ~= text_end or e.fl ~= flags then
        if e == nil then baked._WrapMemoN = baked._WrapMemoN + 1 end
        e = { ww = wrap_width, size = size, te = text_end, fl = flags }
        memo[text] = e
    else
        local r = e[pos]
        if r then return r end
    end
    local r = ImFontCalcWordWrapPositionEx_Uncached(baked, size, text, pos, text_end, wrap_width, flags)
    e[pos] = r
    return r
end

@native
function ImFontCalcWordWrapPositionEx_Uncached(baked, size, text, pos, text_end, wrap_width, flags)
    -- For references, possible wrap point marked with ^
    --  "aaa bbb, ccc,ddd. eee   fff. ggg!"
    --      ^    ^    ^   ^   ^__    ^    ^

    -- Skip extra blanks after a line returns (that includes not counting them in width computation)
    -- e.g. "Hello    world" --> "Hello" "World"

    -- Cut words that cannot possibly fit within one line.
    -- e.g.: "The tropical fish" with ~5 characters worth of width --> "The tr" "opical" "fish"

    -- [Luau] baked = font:GetFontBaked(size) is done by the caller
    local scale = size / baked.Size

    local line_width = 0.0
    local blank_width = 0.0
    wrap_width = wrap_width / scale -- We work with unscaled widths to avoid scaling every characters

    local s = pos
    IM_ASSERT(text_end ~= nil)

    local prev_type = ImWcharClass.Other
    local keep_blanks = bit32.band(flags, ImDrawTextFlags.WrapKeepBlanks) ~= 0

    -- Find next wrapping point
    --local span_begin = s
    local span_end = s
    local span_width = 0.0

    local stop = false
    local text_is_str = type(text) == "string" -- [Luau] ImStrByte() inlined (once per character)
    local adv_data, adv_n = baked.IndexAdvanceX.Data, baked.IndexAdvanceX.Size -- [Luau] hoisted, refreshed after a glyph load
    local CLASS_BLANK, CLASS_PUNCT, CLASS_OTHER = ImWcharClass.Blank, ImWcharClass.Punct, ImWcharClass.Other
    local classifier_0000_007f = g_CharClassifierIsSeparator_0000_007f
    while s < text_end do
        repeat
        --- @type unsigned_int
        local c
        if text_is_str then c = string.byte(text, s) else c = text[s] end
        local next_s
        if c < 0x80 then
            next_s = s + 1
        else
            local wanted, out_char = ImStd.ImTextCharFromUtf8(text, s, text_end)
            c = out_char
            next_s = s + wanted
        end

        if c < 32 then
            if c == 10 then -- '\n'
                return s -- Direct return, skip "Wrap_width is too small to fit anything" path.
            end
            if c == 13 then -- '\r'
                s = next_s -- Fast-skip

                break
            end
        end

        -- Optimized inline version of 'float char_width = GetCharAdvance((ImWchar)c);'
        local char_width = (c < adv_n) and adv_data[c + 1] or -1.0
        if char_width < 0.0 then
            char_width = BuildLoadGlyphGetAdvanceOrFallback(baked, c)
            adv_data, adv_n = baked.IndexAdvanceX.Data, baked.IndexAdvanceX.Size
        end

        -- Classify current character
        local curr_type
        if c < 128 then -- [Luau] ImTextClassifierGet() inlined
            curr_type = bit32.band(bit32.rshift(classifier_0000_007f[bit32.rshift(c, 4) + 1], bit32.lshift(bit32.band(c, 15), 1)), 0x03)
        elseif (c >= 0x3000 and c < 0x3010) then
            curr_type = ImTextClassifierGet(g_CharClassifierIsSeparator_3000_300f, bit32.band(c, 15))
        else
            curr_type = CLASS_OTHER
        end

        if curr_type == CLASS_BLANK then
            -- End span: 'A ' or '. '
            if (prev_type ~= CLASS_BLANK and not keep_blanks) then
                span_end = s
                line_width = line_width + span_width
                span_width = 0.0
            end

            blank_width = blank_width + char_width
        else
            -- End span: '.X' unless X is a digit
            if (prev_type == CLASS_PUNCT and curr_type ~= CLASS_PUNCT and not (c >= 48 and c <= 57)) then -- FIXME: Digit checks might be removed if allow custom separators (#8503)
                span_end = s
                line_width = line_width + (span_width + blank_width)
                blank_width = 0.0
                span_width = 0.0
            -- End span: 'A ' or '. '
            elseif (prev_type == CLASS_BLANK and keep_blanks) then
                span_end = s
                line_width = line_width + (span_width + blank_width)
                blank_width = 0.0
                span_width = 0.0
            end

            span_width = span_width + char_width
        end

        if (span_width + blank_width + line_width > wrap_width) then
            if span_width + blank_width > wrap_width then
                stop = true; break
            end
            -- FIXME: Narrow wrapping e.g. "A quick brown" -> "Quic|k br|own", would require knowing if span is going to be longer than wrap_width.
            --if (span_width > wrap_width and not is_blank and not was_blank) then
            --    return s
            --end
            return span_end
        end

        prev_type = curr_type
        s = next_s

        until true
        if stop then break end
    end

    -- Wrap_width is too small to fit anything. Force displaying 1 character to minimize the height discontinuity.
    -- +1 may not be a character start point in UTF-8 but it's ok because caller loops use (text >= word_wrap_eol).
    if s == pos and s < text_end then
        local bytes = ImStd.ImTextCountUtf8BytesFromChar(text, s, text_end)

        return s + bytes
    end

    return s
end

--- @param size       float
--- @param text       ImString
--- @param pos        int      # [Luau] 1-based start position (C++ 'text' pointer)
--- @param text_end   int      # exclusive
--- @param wrap_width float
--- @return int
function MT.ImFont:CalcWordWrapPosition(size, text, pos, text_end, wrap_width)
    return ImFontCalcWordWrapPositionEx(self, size, text, pos, text_end, wrap_width, ImDrawTextFlags.None)
end

--- @param font              ImFont
--- @param size              float
--- @param max_width         float
--- @param wrap_width        float
--- @param text              ImString
--- @param text_begin        int
--- @param text_end_display? int
--- @param text_end?         int
--- @param out_offset?       ImVec2
--- @param flags             ImDrawTextFlags
--- @return ImVec2 text_size
--- @return int    remaining
local TEXT_SIZE_CACHE_MAX = 4096

@native
-- [Luau] scalar core of ImFontCalcTextSizeEx(): returns size.x, size.y, remaining (no ImVec2 allocated)
function ImFontCalcTextSizeXY(font, size, max_width, wrap_width, text, text_begin, text_end_display, text_end, out_offset, flags)
    local text_is_str = type(text) == "string"
    -- [Luau] cache for the common case (whole string, single pass, no wrap/limit): per baked font, text -> unscaled width, line count.
    -- Advances of a baked font never change once loaded, so entries stay valid.
    local cache_key = nil
    local wrap_cache = nil
    local text_len1 = text_is_str and string.len(text) + 1 or -1 -- [Luau] string.len(): `#` on a string isn't a native fast path
    local baked = font.LastBaked -- [Luau] inline font:GetFontBaked(size) fast path (same baked as the calls below in upstream)
    if not (baked and baked.Size == math.floor(size + 0.5) and baked.RasterizerDensity == font.CurrentRasterizerDensity) then
        baked = font:GetFontBaked(size)
    end
    local cacheable = text_is_str and text_begin == 1 and out_offset == nil and max_width >= FLT_MAX
        and (text_end == nil or text_end == text_len1) and (text_end_display == nil or text_end_display == text_len1) and (flags == nil or bit32.band(flags, ImDrawTextFlags.StopOnNewLine) == 0)
    if cacheable and wrap_width <= 0.0 then
        local cache = baked._TextSizeCache
        if cache == nil or baked._TextSizeCacheN >= TEXT_SIZE_CACHE_MAX then
            cache = {}; baked._TextSizeCache = cache; baked._TextSizeCacheN = 0
        end
        local e = cache[text]
        if e then
            return e[1] * (size / baked.Size), e[2] * size, text_len1
        end
        cache_key = text
    elseif cacheable and wrap_width > 0.0 then
        -- [Luau] same for wrapped text (TextWrapped() measures every line every frame): exact results per (size, wrap width, text)
        local cache = baked._TextSizeCache
        if cache == nil or baked._TextSizeCacheN >= TEXT_SIZE_CACHE_MAX then
            cache = {}; baked._TextSizeCache = cache; baked._TextSizeCacheN = 0
        end
        local by_size = cache[size]
        if by_size == nil then by_size = {}; cache[size] = by_size end
        local by_wrap = by_size[wrap_width]
        if by_wrap == nil then by_wrap = {}; by_size[wrap_width] = by_wrap end
        local e = by_wrap[text]
        if e then
            return e[1], e[2], e[3]
        end
        wrap_cache = by_wrap
    end
    if not text_end then
        text_end = #text + 1 -- FIXME-OPT: Need to avoid this.
    end
    if not text_end_display then
        text_end_display = text_end
    end

    local line_height = size
    local scale = line_height / baked.Size

    local tx, ty = 0.0, 0.0
    local line_width = 0.0

    local word_wrap_enabled = (wrap_width > 0.0)
    local word_wrap_eol

    local s = text_begin
    local stop = false
    local adv_data, adv_n = baked.IndexAdvanceX.Data, baked.IndexAdvanceX.Size -- [Luau] hoisted, refreshed after a glyph load
    while s < text_end_display do
        repeat
        -- Word-wrapping
        if word_wrap_enabled then
            -- Calculate how far we can render. Requires two passes on the string data but keeps the code simple and not intrusive for what's essentially an uncommon feature.
            if not word_wrap_eol then
                word_wrap_eol = ImFontCalcWordWrapPositionEx(font, size, text, s, text_end, wrap_width - line_width, flags)
                adv_data, adv_n = baked.IndexAdvanceX.Data, baked.IndexAdvanceX.Size -- [Luau] may have loaded glyphs
            end

            if s >= word_wrap_eol then
                if tx < line_width then
                    tx = line_width
                end
                ty = ty + line_height
                line_width = 0.0
                s = ImTextCalcWordWrapNextLineStart(text, s, text_end, flags) -- Wrapping skips upcoming blanks
                if bit32.band(flags, ImDrawTextFlags.StopOnNewLine) ~= 0 then
                    stop = true; break
                end
                word_wrap_eol = nil

                break
            end
        end

        -- Decode and advance source
        local prev_s = s
        local c
        if text_is_str then c = string.byte(text, s) else c = text[s] end -- [Luau] ImStrByte() inlined
        if c < 0x80 then
            s = s + 1
        else
            local wanted, out_char = ImStd.ImTextCharFromUtf8(text, s, text_end)
            c = out_char
            s = s + wanted
        end

        if c == 10 then -- '\n'
            if tx < line_width then tx = line_width end
            ty = ty + line_height
            line_width = 0.0
            if bit32.band(flags, ImDrawTextFlags.StopOnNewLine) ~= 0 then
                stop = true; break
            end

            break
        end

        if c == 13 then -- '\r'
            break
        end

        -- Optimized inline version of 'float char_width = GetCharAdvance((ImWchar)c);'
        local char_width = (c < adv_n) and adv_data[c + 1] or -1.0
        if (char_width < 0.0) then
            char_width = BuildLoadGlyphGetAdvanceOrFallback(baked, c)
            adv_data, adv_n = baked.IndexAdvanceX.Data, baked.IndexAdvanceX.Size
        end
        char_width = char_width * scale

        if (line_width + char_width >= max_width) then
            s = prev_s
            stop = true; break
        end

        line_width = line_width + char_width

        until true
        if stop then break end
    end

    if (tx < line_width) then
        tx = line_width
    end

    if out_offset then -- offset allow for the possibility of sitting after a trailing \n
        out_offset.x = line_width
        out_offset.y = ty + line_height
    end

    if (line_width > 0 or ty == 0.0) then -- whereas size.y will ignore the trailing \n
        ty = ty + line_height
    end

    local out_remaining = s

    if cache_key then
        baked._TextSizeCache[cache_key] = { tx / scale, ty / line_height }
        baked._TextSizeCacheN = baked._TextSizeCacheN + 1
    elseif wrap_cache then
        wrap_cache[text] = { tx, ty, out_remaining }
        baked._TextSizeCacheN = baked._TextSizeCacheN + 1
    end

    return tx, ty, out_remaining
end

-- ImVec2 version (upstream signature)
function ImFontCalcTextSizeEx(font, size, max_width, wrap_width, text, text_begin, text_end_display, text_end, out_offset, flags)
    local x, y, remaining = ImFontCalcTextSizeXY(font, size, max_width, wrap_width, text, text_begin, text_end_display, text_end, out_offset, flags)
    return ImVec2(x, y), remaining
end

--- @param size       float
--- @param max_width  float
--- @param wrap_width float
--- @param text       ImString
--- @param text_begin int
--- @param text_end?  int
function MT.ImFont:CalcTextSizeA(size, max_width, wrap_width, text, text_begin, text_end)
    return ImFontCalcTextSizeEx(self, size, max_width, wrap_width, text, text_begin, text_end, text_end, nil, ImDrawTextFlags.None)
end

--- Note: as with every ImDrawList drawing function, this expects that the font atlas texture is bound.
--- @param draw_list     ImDrawList
--- @param size          float
--- @param pos           ImVec2
--- @param col           ImU32
--- @param c             ImWchar
--- @param cpu_fine_clip ImVec4
local RenderChar_a, RenderChar_c, RenderChar_uv_a, RenderChar_uv_c = ImVec2(), ImVec2(), ImVec2(), ImVec2()

function MT.ImFont:RenderChar(draw_list, size, pos, col, c, cpu_fine_clip)
    local baked = self:GetFontBaked(size)
    local glyph = baked:FindGlyph(c)
    if not glyph or not glyph.Visible then
        return
    end
    if glyph.Colored then
        col = bit32.bor(col, bit32.bnot(IM_COL32_A_MASK))
    end

    local scale
    if size >= 0.0 then
        scale = size / baked.Size
    else
        scale = 1.0
    end

    local x = pos.x
    local y = pos.y
    if bit32.band(draw_list.Flags, ImDrawFlags.TextNoPixelSnap) == 0 then
        x = IM_TRUNC(x)
        y = IM_TRUNC(y)
    end

    local x1 = x + glyph.X0 * scale
    local x2 = x + glyph.X1 * scale
    if cpu_fine_clip and (x1 > cpu_fine_clip.z or x2 < cpu_fine_clip.x) then
        return
    end

    local y1 = y + glyph.Y0 * scale
    local y2 = y + glyph.Y1 * scale
    local u1 = glyph.U0
    local v1 = glyph.V0
    local u2 = glyph.U1
    local v2 = glyph.V1

    -- Always CPU fine clip. Code extracted from RenderText().
    -- CPU side clipping used to fit text in their frame when the frame is too small. Only does clipping for axis aligned quads.
    if cpu_fine_clip then
        if x1 < cpu_fine_clip.x then u1 = u1 + (1.0 - (x2 - cpu_fine_clip.x) / (x2 - x1)) * (u2 - u1); x1 = cpu_fine_clip.x end
        if y1 < cpu_fine_clip.y then v1 = v1 + (1.0 - (y2 - cpu_fine_clip.y) / (y2 - y1)) * (v2 - v1); y1 = cpu_fine_clip.y end
        if x2 > cpu_fine_clip.z then u2 = u1 + ((cpu_fine_clip.z - x1) / (x2 - x1)) * (u2 - u1); x2 = cpu_fine_clip.z end
        if y2 > cpu_fine_clip.w then v2 = v1 + ((cpu_fine_clip.w - y1) / (y2 - y1)) * (v2 - v1); y2 = cpu_fine_clip.w end
        if y1 >= y2 then return end
    end
    draw_list:PrimReserve(6, 4)
    -- [Luau] scratch vectors, PrimRectUV() only reads them
    local a, c, uv_a, uv_c = RenderChar_a, RenderChar_c, RenderChar_uv_a, RenderChar_uv_c
    a.x = x1; a.y = y1; c.x = x2; c.y = y2; uv_a.x = u1; uv_a.y = v1; uv_c.x = u2; uv_c.y = v2
    draw_list:PrimRectUV(a, c, uv_a, uv_c, col)
end

function MT.ImFontAtlas:AddFont(font_cfg_in)
    -- Sanity Checks
    IM_ASSERT(not self.Locked, "Cannot modify a locked ImFontAtlas!")
    IM_ASSERT((font_cfg_in.FontData ~= nil and font_cfg_in.FontDataSize > 0) or (font_cfg_in.FontLoader ~= nil))
    IM_ASSERT(font_cfg_in.SizePixels > 0.0, "Is ImFontConfig struct correctly initialized?")
    IM_ASSERT(font_cfg_in.RasterizerDensity > 0.0, "Is ImFontConfig struct correctly initialized?")

    if font_cfg_in.GlyphOffset.x ~= 0.0 or font_cfg_in.GlyphOffset.y ~= 0.0 or
        font_cfg_in.GlyphMinAdvanceX ~= 0.0 or font_cfg_in.GlyphMaxAdvanceX ~= FLT_MAX then
        IM_ASSERT(font_cfg_in.SizePixels ~= 0.0,
            "Specifying glyph offset/advances requires a reference size to base it on.")
    end

    -- Lazily create builder on the first call to AddFont
    if self.Builder == nil then
        ImFontAtlasBuildInit(self)
    end

    -- Create new font
    local is_first_font = (self.Fonts.Size == 0)
    local font
    if not font_cfg_in.MergeMode then
        font = ImFont()
        font.FontId = self.FontNextUniqueID
        self.FontNextUniqueID = self.FontNextUniqueID + 1
        font.Flags = font_cfg_in.Flags
        font.LegacySize = font_cfg_in.SizePixels
        font.CurrentRasterizerDensity = font_cfg_in.RasterizerDensity
        self.Fonts:push_back(font)
    else
        IM_ASSERT(self.Fonts.Size > 0, "Cannot use MergeMode for the first font!") -- When using MergeMode make sure that a font has already been added before.
        font = (font_cfg_in.DstFont ~= nil) and font_cfg_in.DstFont or self.Fonts:back()
        ImFontAtlasFontDiscardBakes(self, font, 0) -- Need to discard bakes if the font was already used, because baked->FontLoaderDatas[] will change size. (#9162)
    end

    -- Add to list
    self.Sources:push_back(font_cfg_in)
    local font_cfg = self.Sources:back()
    if (font_cfg.DstFont == nil) then
        font_cfg.DstFont = font
    end
    font.Sources:push_back(font_cfg)
    ImFontAtlasBuildUpdatePointers(self)

    -- Sanity check
    -- We don't round cfg.SizePixels yet as relative size of merged fonts are used afterwards.
    if font_cfg.GlyphExcludeRanges ~= nil then
        local size = 0
        for _, v in ipairs(font_cfg.GlyphExcludeRanges) do if v == 0 then break end size = size + 1 end
        IM_ASSERT(bit32.band(size, 1) == 0, "GlyphExcludeRanges[] size must be multiple of two!")
        IM_ASSERT(size <= 64, "GlyphExcludeRanges[] size must be small!")
    end

    if font_cfg.FontLoader ~= nil then
        IM_ASSERT(font_cfg.FontLoader.FontBakedLoadGlyph ~= nil)
        IM_ASSERT(font_cfg.FontLoader.LoaderInit == nil and font_cfg.FontLoader.LoaderShutdown == nil) -- FIXME-NEWATLAS: Unsupported yet.
    end
    --                             | Target w/ Implicit RefSize | Target w/ Explicit RefSize |
    -- Adding w/ Implicit RefSize: | OK (same scale)            | OK (same scale)            |
    -- Adding w/ Explicit RefSize: | KO                         | OK (custom scale)          |
    if font_cfg_in.MergeMode and font_cfg_in.SizePixels > 0 then
        IM_ASSERT(bit32.band(font.Flags, ImFontFlags.ImplicitRefSize) == 0, "Cannot use MergeMode with an explicit reference size when the destination font used an implicit reference size!")
    end
    IM_ASSERT(font_cfg.FontLoaderData == nil)

    if not ImFontAtlasFontSourceInit(self, font_cfg) then
        -- Rollback (this is a fragile/rarely exercised code-path. TestSuite's "misc_atlas_add_invalid_font" aim to test this)
        ImFontAtlasFontDestroySourceData(self, font_cfg)
        self.Sources:pop_back()
        font.Sources:pop_back()
        if not font_cfg.MergeMode then
            font = nil
            self.Fonts:pop_back()
        end
        return nil
    end
    ImFontAtlasFontSourceAddToFont(self, font, font_cfg)

    if (is_first_font) then
        ImFontAtlasBuildNotifySetFont(self, nil, font)
    end

    return font
end

-- Default font TTF is compressed with stb_compress then base85 encoded (see misc/fonts/binary_to_compressed_c.cpp for encoder)
local stb_decompress_length
local stb_decompress
local function Decode85Byte(c) return (c >= 92) and (c - 36) or (c - 35) end -- c >= '\\'
--- @param src string
--- @param dst buffer
local function Decode85(src, dst)
    local d = 0
    local src_len = #src
    local s = 1
    while s + 4 <= src_len do -- [Luau] while (*src): stop at the last complete 5-char group
        local b0, b1, b2, b3, b4 = string.byte(src, s, s + 4)
        local tmp = (Decode85Byte(b0) + 85 * (Decode85Byte(b1) + 85 * (Decode85Byte(b2) + 85 * (Decode85Byte(b3) + 85 * Decode85Byte(b4))))) % 4294967296
        buffer.writeu8(dst, d + 0, tmp % 256); buffer.writeu8(dst, d + 1, math.floor(tmp / 256) % 256); buffer.writeu8(dst, d + 2, math.floor(tmp / 65536) % 256); buffer.writeu8(dst, d + 3, math.floor(tmp / 16777216) % 256) -- We can't assume little-endianness.
        s = s + 5
        d = d + 4
    end
end

-- This duplicates some of the logic in UpdateFontsNewFrame() which is a bit chicken-and-eggy/tricky to extract due to variety of codepaths and possible initialization ordering.
--- @param ctx ImGuiContext
--- @return float
local function GetExpectedContextFontSize(ctx)
    return ((ctx.Style.FontSizeBase > 0.0) and ctx.Style.FontSizeBase or 13.0) * ctx.Style.FontScaleMain * ctx.Style.FontScaleDpi
end

-- Legacy function with heuristic to select Pixel or Vector font.
-- The selection is based on (style.FontSizeBase * style.FontScaleMain * style.FontScaleDpi) reaching a small threshold at the time of adding the default font.
-- Prefer calling AddFontDefaultVector() or AddFontDefaultBitmap() based on your own logic.
--- @param font_cfg ImFontConfig
function MT.ImFontAtlas:AddFontDefault(font_cfg)
    if self.OwnerContext == nil or GetExpectedContextFontSize(self.OwnerContext) >= 15.0 then
        return self:AddFontDefaultVector(font_cfg)
    else
        return self:AddFontDefaultBitmap(font_cfg)
    end
end

function MT.ImFontAtlas:AddFontFromMemoryTTF(font_data, font_data_size, size_pixels, font_cfg_template, glyph_ranges)
    IM_ASSERT(not self.Locked, "Cannot modify a locked ImFontAtlas!")
    local font_cfg = font_cfg_template and font_cfg_template or ImFontConfig()
    IM_ASSERT(font_cfg.FontData == nil)
    IM_ASSERT(font_data_size > 100, "Incorrect value for font_data_size!") -- Heuristic to prevent accidentally passing a wrong value to font_data_size.
    font_cfg.FontData = font_data
    font_cfg.FontDataSize = font_data_size
    font_cfg.SizePixels = (size_pixels > 0.0) and size_pixels or font_cfg.SizePixels
    if glyph_ranges then
        font_cfg.GlyphRanges = glyph_ranges
    end
    return self:AddFont(font_cfg)
end

--- @param compressed_ttf_data buffer|string|ImU8[] # [Luau] stb_compress() output: buffer, string or 1-based byte table
--- @param compressed_ttf_size int
function MT.ImFontAtlas:AddFontFromMemoryCompressedTTF(compressed_ttf_data, compressed_ttf_size, size_pixels, font_cfg_template, glyph_ranges)
    -- [Luau] normalize input to a buffer
    if type(compressed_ttf_data) == "string" then
        compressed_ttf_data = buffer.fromstring(compressed_ttf_data)
    elseif type(compressed_ttf_data) == "table" then
        local b = buffer.create(compressed_ttf_size)
        for n = 1, compressed_ttf_size do buffer.writeu8(b, n - 1, compressed_ttf_data[n]) end
        compressed_ttf_data = b
    end
    local buf_decompressed_size = stb_decompress_length(compressed_ttf_data)
    local buf_decompressed_data = buffer.create(buf_decompressed_size)
    stb_decompress(buf_decompressed_data, compressed_ttf_data, compressed_ttf_size)

    -- [Luau] FontData is a 1-based byte table (see stbtt / ImFileLoadToMemory)
    local ttf_data = table.create and table.create(buf_decompressed_size) or {}
    for n = 1, buf_decompressed_size do ttf_data[n] = buffer.readu8(buf_decompressed_data, n - 1) end

    local font_cfg = font_cfg_template and font_cfg_template or ImFontConfig()
    IM_ASSERT(font_cfg.FontData == nil)
    font_cfg.FontDataOwnedByAtlas = true
    return self:AddFontFromMemoryTTF(ttf_data, buf_decompressed_size, size_pixels or 0.0, font_cfg, glyph_ranges)
end

--- @param compressed_ttf_data_base85 string
function MT.ImFontAtlas:AddFontFromMemoryCompressedBase85TTF(compressed_ttf_data_base85, size_pixels, font_cfg, glyph_ranges)
    local compressed_ttf_size = math.floor((#compressed_ttf_data_base85 + 4) / 5) * 4
    local compressed_ttf = buffer.create(compressed_ttf_size)
    Decode85(compressed_ttf_data_base85, compressed_ttf)
    local font = self:AddFontFromMemoryCompressedTTF(compressed_ttf, compressed_ttf_size, size_pixels, font_cfg, glyph_ranges)
    return font
end

--- @param font ImFont
function MT.ImFontAtlas:RemoveFont(font)
    IM_ASSERT(not self.Locked, "Cannot modify a locked ImFontAtlas!")

    ImFontAtlasFontDestroyOutput(self, font)
    for _, src in font.Sources:iter() do
        ImFontAtlasFontDestroySourceData(self, src)
    end
    local src_n = 1
    while src_n <= self.Sources.Size do
        if self.Sources.Data[src_n].DstFont == font then
            self.Sources:erase(src_n)
        else
            src_n = src_n + 1
        end
    end

    local removed = self.Fonts:find_erase(font)
    IM_ASSERT(removed)

    ImFontAtlasBuildUpdatePointers(self)

    font.OwnerAtlas = nil

    -- Notify external systems
    local new_current_font = nil
    if self.Fonts.Size > 0 then new_current_font = self.Fonts.Data[1] end
    ImFontAtlasBuildNotifySetFont(self, font, new_current_font)
end

function MT.ImFontAtlas:AddFontFromFileTTF(filename, size_pixels, font_cfg_template, glyph_ranges)
    IM_ASSERT(not self.Locked, "Cannot modify a locked ImFontAtlas!")

    local data, data_size = ImStd.ImFileLoadToMemory(filename, "rb")
    if not data then
        if (font_cfg_template == nil or (bit32.band(font_cfg_template.Flags, ImFontFlags.NoLoadError) == 0)) then
            -- [Port] IMGUI_DEBUG_LOG("While loading '%s'\n", filename)
            IM_ASSERT_USER_ERROR(0, "Could not load font file!")
        end

        return nil
    end

    local font_cfg = font_cfg_template and font_cfg_template or ImFontConfig()
    if not font_cfg.Name or font_cfg.Name == "" then
        -- Store a short copy of filename into the font name for convenience
        for i = #filename, 1, -1 do
            local c = string.byte(filename, i, i)
            if (c == 47 or c == 92) then -- '/' or '\\'
                font_cfg.Name = string.sub(filename, i + 1)
                break
            end
        end
    end

    return self:AddFontFromMemoryTTF(data, data_size, size_pixels, font_cfg, glyph_ranges)
end

function GetDefaultFontDataProggyClean()
    return ImStd.ImFileLoadToMemory("fonts/ProggyClean.ttf", "rb")
end

function GetDefaultFontDataProggyForever()
    return ImStd.ImFileLoadToMemory("fonts/ProggyForever.ttf", "rb")
end

-- TODO: IMGUI_DISABLE_DEFAULT_FONT, IMGUI_DISABLE_DEFAULT_FONT_BITMAP
-- Load ProggyClean.ttf. Default size 13, disable oversampling.
-- If you want a similar font which may be better scaled, consider using AddFontDefaultVector().
--- @param font_cfg_template ImFontConfig
function MT.ImFontAtlas:AddFontDefaultBitmap(font_cfg_template)
    local font_cfg = font_cfg_template and font_cfg_template or ImFontConfig()
    if not font_cfg_template then
        font_cfg.PixelSnapH = true -- Prevents sub-integer scaling factors at lower-level layers.
    end
    if font_cfg.SizePixels <= 0.0 then
        font_cfg.SizePixels = 13.0 -- This only serves (1) as a reference for GlyphOffset.y setting and (2) as a default for pre-1.92 backend.
        font_cfg.Flags = bit32.bor(font_cfg.Flags, ImFontFlags.ImplicitRefSize)
    end
    if not font_cfg.Name or font_cfg.Name == "" then
        font_cfg.Name = "ProggyClean.ttf"
    end
    font_cfg.EllipsisChar = 0x0085
    font_cfg.GlyphOffset.y = font_cfg.GlyphOffset.y +  1.0 * (font_cfg.SizePixels / 13.0) -- Add +1 offset per 13 units

    local ttf_data, ttf_data_size = GetDefaultFontDataProggyClean()
    return self:AddFontFromMemoryTTF(ttf_data, ttf_data_size, font_cfg.SizePixels, font_cfg)
end

-- Load a minimal version of ProggyForever, designed to match our good old ProggyClean, but nicely scalable.
-- (See build script in https://github.com/ocornut/proggyforever for details)
--- @param font_cfg_template ImFontConfig
function MT.ImFontAtlas:AddFontDefaultVector(font_cfg_template)
    local font_cfg = font_cfg_template and font_cfg_template or ImFontConfig()
    if not font_cfg_template then
        font_cfg.PixelSnapH = true -- Precisely match ProggyClean, but prevents sub-integer scaling factors at lower-level layers.
    end
    if font_cfg.SizePixels <= 0.0 then
        font_cfg.SizePixels = 13.0
        font_cfg.Flags = bit32.bor(font_cfg.Flags, ImFontFlags.ImplicitRefSize)
    end
    if not font_cfg.Name or font_cfg.Name == "" then
        font_cfg.Name = "ProggyForever.ttf"
    end
    font_cfg.ExtraSizeScale = font_cfg.ExtraSizeScale * 1.015 -- Match ProggyClean
    font_cfg.GlyphOffset.y = font_cfg.GlyphOffset.y + 0.5 * (font_cfg.SizePixels / 16.0) -- Closer match ProggyClean + avoid descenders going too high (with current code).

    local ttf_data, ttf_data_size = GetDefaultFontDataProggyForever()
    return self:AddFontFromMemoryTTF(ttf_data, ttf_data_size, font_cfg.SizePixels, font_cfg)
end

function MT.ImFontAtlas:GetCustomRect(id, out_r)
    local r = ImFontAtlasPackGetRectSafe(self, id)
    if r == nil then
        return false
    end
    IM_ASSERT(self.TexData.Width > 0 and self.TexData.Height > 0) -- Font atlas needs to be built before we can calculate UV coordinates
    if out_r == nil then
        return true
    end
    out_r.x = r.x
    out_r.y = r.y
    out_r.w = r.w
    out_r.h = r.h
    ImVec2_Copy(out_r.uv0, ImVec2((r.x), (r.y)) * self.TexUvScale)
    ImVec2_Copy(out_r.uv1, ImVec2((r.x + r.w), (r.y + r.h)) * self.TexUvScale)

    return true
end

--- @param atlas         ImFontAtlas
--- @param cursor_type   ImGuiMouseCursor
--- @param out_offset    ImVec2
--- @param out_size      ImVec2
--- @param out_uv_border ImVec2[]
--- @param out_uv_fill   ImVec2[]
function ImFontAtlasGetMouseCursorTexData(atlas, cursor_type, out_offset, out_size, out_uv_border, out_uv_fill)
    if cursor_type <= ImGuiMouseCursor.None or cursor_type >= ImGuiMouseCursor.COUNT then
        return false
    end
    if bit32.band(atlas.Flags, ImFontAtlasFlags.NoMouseCursors) ~= 0 then
        return false
    end

    local r = ImFontAtlasPackGetRect(atlas, atlas.Builder.PackIdMouseCursors)
    local pos = FONT_ATLAS_DEFAULT_TEX_CURSOR_DATA[cursor_type + 1][1] + ImVec2(r.x, r.y)
    local size = FONT_ATLAS_DEFAULT_TEX_CURSOR_DATA[cursor_type + 1][2]
    ImVec2_Copy(out_size, size)
    ImVec2_Copy(out_offset, FONT_ATLAS_DEFAULT_TEX_CURSOR_DATA[cursor_type + 1][3])
    ImVec2_Copy(out_uv_border[1], (pos) * atlas.TexUvScale)
    ImVec2_Copy(out_uv_border[2], (pos + size) * atlas.TexUvScale)
    pos.x = pos.x + (FONT_ATLAS_DEFAULT_TEX_DATA_W + 1)
    ImVec2_Copy(out_uv_fill[1], (pos) * atlas.TexUvScale)
    ImVec2_Copy(out_uv_fill[2], (pos + size) * atlas.TexUvScale)

    return true
end

-- At it is common to do an AddCustomRect() followed by a GetCustomRect(), we provide an optional 'out_r' argument to retrieve the info straight away.
function MT.ImFontAtlas:AddCustomRect(width, height, out_r)
    IM_ASSERT(width > 0 and width <= 0xFFFF)
    IM_ASSERT(height > 0 and height <= 0xFFFF)

    if (self.Builder == nil) then
        ImFontAtlasBuildInit(self)
    end

    local r_id = ImFontAtlasPackAddRect(self, width, height)
    if (r_id == ImFontAtlasRectId_Invalid) then
        return ImFontAtlasRectId_Invalid
    end
    if (out_r ~= nil) then
        self:GetCustomRect(r_id, out_r)
    end

    if (self.RendererHasTextures) then
        local r = ImFontAtlasPackGetRect(self, r_id)
        ImFontAtlasTextureBlockQueueUpload(self, self.TexData, r.x, r.y, r.w, r.h)
    end

    return r_id
end

function MT.ImFontAtlas:RemoveCustomRect(id)
    if ImFontAtlasPackGetRectSafe(self, id) == nil then
        return
    end
    ImFontAtlasPackDiscardRect(self, id)
end

local function IM_NORMALIZE2F_OVER_ZERO(VX, VY)
    local d2 = VX * VX + VY * VY
    if d2 > 0.0 then
        local inv_len = ImRsqrt(d2)
        VX = VX * inv_len
        VY = VY * inv_len
    end
    return VX, VY
end

local function IM_FIXNORMAL2F(VX, VY)
    local IM_FIXNORMAL2F_MAX_INVLEN2 = 100 -- 500.0f (see #4053, #3366)

    local d2 = VX * VX + VY * VY
    if d2 > 0.000001 then
        local inv_len2 = 1.0 / d2
        if inv_len2 > IM_FIXNORMAL2F_MAX_INVLEN2 then
            inv_len2 = IM_FIXNORMAL2F_MAX_INVLEN2
        end
        VX = VX * inv_len2
        VY = VY * inv_len2
    end
    return VX, VY
end

-- - The miter limit describes how much the miter cross section can be scaled before we turn it into a bevel instead.
--   The minimum value of miter limit is 1.0, which translates to 180 (all corners are bevels), the higher the number,
--   the closer to zero the angle is (never bevel a corner). The miter limit angle can be calculated as:
--      miter_limit_angle = 2 * acos(1 / miter_limit)
-- - We can use the miter limit angle to figure maximum number of beveled corners in a convex polygon,
--   to prevent having allocate much extra memory (for a reasonable miter limit).
--      (n - 2) * 360 > k * miter_limit_angle + (n - k) * 360
--   Where, n = number of corners in a polygon, k = beveled corners. Solved for k, simplifies to:
--      k < 360 / (180 - miter_limit_angle)
--   To find value strictly less than:
--      max_bevels = k = floor(360/(180-miter_limit_angle))
local IM_POLYLINE_MITER_ANGLE_LIMIT      = -0.9999619 -- Safeguard for miter corner calculation to avoid div by zero. cos(179.5)
local IM_POLYLINE_MITER_LIMIT            = 4.0        -- (~29 deg corner)
local IM_POLYLINE_CONVEX_POLY_MAX_BEVELS = 2          -- For miter value 4.0

--- @param col       ImU32
--- @param alpha_mul float
local function ImAlphaMultiply(col, alpha_mul)
    IM_ASSERT_PARANOID(alpha_mul >= 0.0 and alpha_mul < 1.0) -- We don't clamp!
    local a = bit32.rshift(bit32.band(col, IM_COL32_A_MASK), IM_COL32_A_SHIFT)
    a = math.floor(a * alpha_mul) -- We don't need to clamp 0..255 because alpha is in 0..1 range.
    return bit32.bor(bit32.band(col, bit32.bnot(IM_COL32_A_MASK)), bit32.lshift(a, IM_COL32_A_SHIFT))
end

-- [Port] #define _GetStrokePos(_FLAGS, _DEFAULT_STROKE_POS)
local function _GetStrokePos(flags, default_stroke_pos)
    local stroke_pos = bit32.band(flags, ImDrawFlags.StrokeMask_)
    if stroke_pos ~= 0 then return stroke_pos end
    return default_stroke_pos
end

-------------------------------------------------------------------------------
-- [SECTION] ImDrawData
-------------------------------------------------------------------------------

function MT.ImDrawData:Clear()
    self.Valid = false
    self.FrameCount = 0; self.TotalIdxCount = 0; self.TotalVtxCount = 0
    self.CmdLists:resize(0) -- The ImDrawList are NOT owned by ImDrawData but e.g. by ImGuiContext, so we don't clear them.
    self.DisplayPos       = ImVec2(0.0, 0.0)
    self.DisplaySize      = ImVec2(0.0, 0.0)
    self.FramebufferScale = ImVec2(0.0, 0.0)
    self.OwnerViewport    = nil
    self.Textures         = nil
end

-- Important: 'out_list' is generally going to be draw_data.CmdLists, but may be another temporary list
-- as long at it is expected that the result will be later merged into draw_data.CmdLists[].
function ImGui.AddDrawListToDrawDataEx(draw_data, out_list, draw_list)
    if draw_list.CmdBuffer.Size == 0 then
        return
    end
    if draw_list.CmdBuffer.Size == 1 and draw_list.CmdBuffer.Data[1].ElemCount == 0 and draw_list.CmdBuffer.Data[1].UserCallback == nil then
        return
    end

    -- Draw list sanity check. Detect mismatch between PrimReserve() calls and incrementing _VtxCurrentIdx, _VtxWritePtr etc.
    -- May trigger for you if you are using PrimXXX functions incorrectly.
    IM_ASSERT(draw_list.VtxBuffer.Size == 0 or draw_list._VtxWritePtr == draw_list.VtxBuffer.Size + 1)
    IM_ASSERT(draw_list.IdxBuffer.Size == 0 or draw_list._IdxWritePtr == draw_list.IdxBuffer.Size + 1)
    if (bit32.band(draw_list.Flags, ImDrawFlags.UseVtxOffset) == 0) then
        IM_ASSERT(draw_list._VtxCurrentIdx == draw_list.VtxBuffer.Size + 1)
    end

    -- Resolve callback data pointers
    local cb_buf = draw_list._CallbacksDataBuf
    if cb_buf.Size > 0 then
        for _, cmd in draw_list.CmdBuffer:iter() do
            if cmd.UserCallback ~= nil and cmd.UserCallbackDataOffset ~= -1 and cmd.UserCallbackDataSize > 0 then
                cmd.UserCallbackData = cb_buf.Data[cmd.UserCallbackDataOffset + 1]
            end
        end
    end

    -- Add to output list + records state in ImDrawData
    out_list:push_back(draw_list)
    draw_data.TotalVtxCount = draw_data.TotalVtxCount + draw_list.VtxBuffer.Size
    draw_data.TotalIdxCount = draw_data.TotalIdxCount + draw_list.IdxBuffer.Size
end

function MT.ImDrawData:AddDrawList(draw_list)
    draw_list:_PopUnusedDrawCmd()
    ImGui.AddDrawListToDrawDataEx(self, self.CmdLists, draw_list)
end

-- For backward compatibility: convert all buffers from indexed to de-indexed, in case you cannot render indexed. Note: this is slow and most likely a waste of resources. Always prefer indexed rendering!
-- [Luau] IdxBuffer values are 1-based vertex indices
function MT.ImDrawData:DeIndexAllBuffers()
    local new_vtx_buffer = ImDrawVtxBuffer()
    self.TotalVtxCount = 0; self.TotalIdxCount = 0
    for i = 1, self.CmdLists.Size do
        repeat
        local draw_list = self.CmdLists.Data[i]
        if draw_list.IdxBuffer.Size == 0 then
            break -- continue
        end
        new_vtx_buffer:resize(draw_list.IdxBuffer.Size)
        local src, dst, idx = draw_list.VtxBuffer.Buf, new_vtx_buffer.Buf, draw_list.IdxBuffer.Data
        for j = 1, draw_list.IdxBuffer.Size do
            buffer.copy(dst, (j - 1) * VTX_STRIDE, src, (idx[j] - 1) * VTX_STRIDE, VTX_STRIDE)
        end
        draw_list.VtxBuffer, new_vtx_buffer = new_vtx_buffer, draw_list.VtxBuffer -- swap()
        draw_list.IdxBuffer:resize(0)
        self.TotalVtxCount = self.TotalVtxCount + draw_list.VtxBuffer.Size
        until true
    end
end

-- Helper to scale the ClipRect field of each ImDrawCmd.
-- Use if your final output buffer is at a different scale than draw_data->DisplaySize,
-- or if there is a difference between your window resolution and framebuffer resolution.
function MT.ImDrawData:ScaleClipRects(fb_scale)
    for i = 1, self.CmdLists.Size do
        local draw_list = self.CmdLists.Data[i]
        for j = 1, draw_list.CmdBuffer.Size do
            local cmd = draw_list.CmdBuffer.Data[j]
            cmd.ClipRect = ImVec4(cmd.ClipRect.x * fb_scale.x, cmd.ClipRect.y * fb_scale.y, cmd.ClipRect.z * fb_scale.x, cmd.ClipRect.w * fb_scale.y)
        end
    end
end

local IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MIN = 4
local IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MAX = 512

function IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC(_RAD, _MAXERROR) return ImClamp(IM_ROUNDUP_TO_EVEN(ImCeil(IM_PI / ImAcos(1 - ImMin(_MAXERROR, _RAD) / _RAD))), IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MIN, IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MAX) end
local function IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC_R(_N, _MAXERROR) return (_MAXERROR / (1 - ImCos(IM_PI / ImMax(_N, IM_PI)))) end
local function IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC_ERROR(_N, _RAD)  return ((1 - ImCos(IM_PI / ImMax(_N, IM_PI))) / _RAD) end

-- Calculates arc step and step count for 90 degree arc. The calculated arc step will complete a 90 degree arc when stepped arc_step_count times.
-- [Luau] returns arc_step, arc_step_count (C++ out-references)
function CalcCornerArcStepAndCount(segment_count)
    local quarter = IM_DRAWLIST_ARCFAST_TABLE_SIZE / 4
    local arc_step = ImClamp(math.floor(IM_DRAWLIST_ARCFAST_SAMPLE_MAX / segment_count), 1, quarter)
    local arc_step_count = math.floor(quarter / arc_step)
    if (arc_step * arc_step_count) ~= quarter then -- Make sure that the arc step can iterate 90 degree arc.
        arc_step = math.floor(quarter / arc_step_count)
    end
    return arc_step, arc_step_count
end

local function ApproxApothem(num_segments)
    -- Calculates approximation (within 0.001%) distance from the center of the circumscribed circle to the edge of the polygon, cos(pi / n)
    IM_ASSERT_PARANOID(num_segments >= 3)
    local u = 1.0 / num_segments
    return ((4.058712 * u * u) - 4.934802) * u * u + 1.0
end

-------------------------------------------------------------------------------
-- [SECTION] ImDrawList
-------------------------------------------------------------------------------

function MT.ImDrawListSharedData:SetCircleTessellationMaxError(max_error)
    if self.CircleTessellationMaxError == max_error then
        return
    end

    IM_ASSERT(max_error > 0)

    self.CircleTessellationMaxError = max_error
    for i = 1, 64 do -- [Port] IM_COUNTOF(CircleSegmentCounts)
        local radius = (i - 1)
        self.CircleSegmentCounts[i] = (i > 1) and IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC(radius, self.CircleTessellationMaxError) or IM_DRAWLIST_ARCFAST_SAMPLE_MAX
    end

    self.ArcFastRadiusCutoff = IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC_R(IM_DRAWLIST_ARCFAST_SAMPLE_MAX, self.CircleTessellationMaxError)
end

--- @param data ImDrawListSharedData
function MT.ImDrawList:_SetDrawListSharedData(data)
    if self._Data ~= nil then
        self._Data.DrawLists:find_erase_unsorted(self)
    end
    self._Data = data
    if self._Data ~= nil then
        self._Data.DrawLists:push_back(self)
    end
end

-- Initialize before use in a new frame. We always have a command ready in the buffer.
-- In the majority of cases, you would want to call PushClipRect() and PushTexture() after this.
function MT.ImDrawList:_ResetForNewFrame()
    self._ContentClipX0 = nil -- [Port] set again by Begin() (Roblox backend scroll reuse)
    if self._Splitter._Count > 1 then
        self._Splitter:Merge(self)
    end
    self._Splitter._Current = 0 -- [Lua] recover from an error thrown mid-split
    self._Splitter._Count = 1

    self.CmdBuffer:resize(0)
    self.IdxBuffer:resize(0)
    self.VtxBuffer:resize(0)
    self.Flags = self._Data.InitialDrawFlags
    IM_ASSERT(bit32.band(self.Flags, bit32.bnot(ImDrawFlags.AllowInFrameScope_)) == 0)

    -- memset(&_CmdHeader, 0, sizeof(_CmdHeader)) -- [Luau] in place, no new table per frame
    local header = self._CmdHeader
    local hcr = header.ClipRect
    hcr.x = 0; hcr.y = 0; hcr.z = 0; hcr.w = 0
    header.TexRef = nil
    header.VtxOffset = 0

    self._VtxCurrentIdx = 1
    self._VtxWritePtr = 1
    self._IdxWritePtr = 1
    self._ClipRectStack:resize(0)
    self._TextureStack:resize(0)
    self._CallbacksDataBuf:resize(0)
    self._DrawFlagsStack.Size = 0 -- [Port] _DrawFlagsStack.clear() (ImSmallStack_)
    self._Path:resize(0)

    self:AddDrawCmd() -- [Luau] C++ push_back(ImDrawCmd()): same zeroed command (the header was just zeroed), reuses last frame's object
    -- Caller needs to bet _SetPixelDensity() as well.
end

function MT.ImDrawList:_ClearFreeMemory()
    self.CmdBuffer:clear()
    self.IdxBuffer:clear()
    self.VtxBuffer:clear()

    self.Flags = ImDrawFlags.None

    self._VtxCurrentIdx = 1
    self._VtxWritePtr = 1
    self._IdxWritePtr = 1

    self._ClipRectStack:clear()
    self._TextureStack:clear()
    self._CallbacksDataBuf:clear()
    self._DrawFlagsStack.Size = 0 -- [Port] _DrawFlagsStack.clear() (ImSmallStack_)
    self._Path:clear()
    self._Splitter:ClearFreeMemory()
end

-- Note: For multi-threaded rendering, consider using `imgui_threaded_rendering` from https://github.com/ocornut/imgui_club
-- [Luau] C++ copies the vectors by value: copy the ImDrawCmd structs and the vertex buffer bytes
--- @return ImDrawList
function MT.ImDrawList:CloneOutput()
    local dst = ImDrawList(nil)
    for i = 1, self.CmdBuffer.Size do
        local src_cmd = self.CmdBuffer.Data[i]
        local cmd = ImDrawCmd()
        for k, v in pairs(src_cmd) do cmd[k] = v end
        cmd.ClipRect = ImVec4(src_cmd.ClipRect.x, src_cmd.ClipRect.y, src_cmd.ClipRect.z, src_cmd.ClipRect.w)
        if src_cmd.TexRef then cmd.TexRef = ImTextureRef(src_cmd.TexRef._TexID); cmd.TexRef._TexData = src_cmd.TexRef._TexData end
        dst.CmdBuffer:push_back(cmd)
    end
    if self.IdxBuffer.Size > 0 then
        dst.IdxBuffer:resize(self.IdxBuffer.Size)
        table.move(self.IdxBuffer.Data, 1, self.IdxBuffer.Size, 1, dst.IdxBuffer.Data)
    end
    dst.VtxBuffer:resize(self.VtxBuffer.Size)
    buffer.copy(dst.VtxBuffer.Buf, 0, self.VtxBuffer.Buf, 0, self.VtxBuffer.Size * VTX_STRIDE)
    dst.Flags = self.Flags
    return dst
end

@native
function MT.ImDrawList:AddDrawCmd()
    -- [Luau] C++ constructs the command in the vector's storage, which keeps last frame's memory: reuse the command
    -- object left past Size by resize(0)/pop_back() (Merge() takes channel commands out of their slots, nothing else
    -- shares them) instead of allocating 3 tables per command per frame
    local cmd_buffer = self.CmdBuffer
    local n = cmd_buffer.Size + 1
    local draw_cmd = (n <= cmd_buffer.Capacity) and cmd_buffer.Data[n] or nil
    if draw_cmd then
        draw_cmd.ElemCount = 0
        draw_cmd.UserCallback = nil
        draw_cmd.UserCallbackData = nil
        draw_cmd.UserCallbackDataSize = 0
        draw_cmd.UserCallbackDataOffset = 0
    else
        draw_cmd = ImDrawCmd()
    end

    local header = self._CmdHeader
    local dcr, hcr = draw_cmd.ClipRect, header.ClipRect
    dcr.x = hcr.x; dcr.y = hcr.y; dcr.z = hcr.z; dcr.w = hcr.w -- Same as calling ImDrawCmd_HeaderCopy()
    draw_cmd.TexRef = header.TexRef
    draw_cmd.VtxOffset = header.VtxOffset
    draw_cmd.IdxOffset = self.IdxBuffer.Size

    IM_ASSERT(dcr.x <= dcr.z and dcr.y <= dcr.w)
    -- [Luau] inline self.CmdBuffer:push_back(draw_cmd)
    if n > cmd_buffer.Capacity then cmd_buffer:push_back(draw_cmd) else cmd_buffer.Data[n] = draw_cmd; cmd_buffer.Size = n end
end

-- Pop trailing draw command (used before merging or presenting to user)
-- Note that this leaves the ImDrawList in a state unfit for further commands, as most code assume that CmdBuffer.Size > 0 && CmdBuffer.back().UserCallback == nil
function MT.ImDrawList:_PopUnusedDrawCmd()
    while self.CmdBuffer.Size > 0 do
        local curr_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
        if curr_cmd.ElemCount ~= 0 or curr_cmd.UserCallback ~= nil then
            break -- return;// break;
        end

        self.CmdBuffer:pop_back()
    end
end

--- @param callback       ImDrawCallback
--- @param userdata       any
--- @param userdata_size? size_t
function MT.ImDrawList:AddCallback(callback, userdata, userdata_size)
    if userdata_size == nil then userdata_size = 0 end

    IM_ASSERT(callback ~= nil)
    IM_ASSERT_PARANOID(self.CmdBuffer.Size > 0)

    local curr_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    IM_ASSERT(curr_cmd.UserCallback == nil)
    if curr_cmd.ElemCount ~= 0 then
        self:AddDrawCmd()
        curr_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    end
    curr_cmd.UserCallback = callback
    if userdata_size == 0 then
        -- Store user data directly in command (no indirection)
        curr_cmd.UserCallbackData = userdata
        curr_cmd.UserCallbackDataSize = 0
        curr_cmd.UserCallbackDataOffset = -1
    else
        -- Copy and store user data in a buffer
        -- [Lua] No raw bytes: the "copy" is a shallow copy of a table userdata (other values are immutable and stored as is),
        -- so later changes to the caller's table don't affect this command. userdata_size is only recorded.
        IM_ASSERT(userdata ~= nil)
        IM_ASSERT(userdata_size < 2147483648) -- [Port] (1u << 31)
        curr_cmd.UserCallbackData = nil -- Will be resolved during Render()
        curr_cmd.UserCallbackDataSize = userdata_size
        curr_cmd.UserCallbackDataOffset = self._CallbacksDataBuf.Size -- 0-based
        local copy = userdata
        if type(userdata) == "table" then
            copy = {}
            for k, v in pairs(userdata) do copy[k] = v end
            setmetatable(copy, getmetatable(userdata))
        end
        self._CallbacksDataBuf:push_back(copy) -- memcpy()
    end

    self:AddDrawCmd() -- Force a new command after us (see comment below)
end

--- Compare ClipRect, TexRef, VtxOffset
--- @param CMD_LHS ImDrawCmd|ImDrawCmdHeader
--- @param CMD_RHS ImDrawCmd|ImDrawCmdHeader
--- @return bool
local function ImDrawCmd_HeaderCompare(CMD_LHS, CMD_RHS)
    local lcr, rcr = CMD_LHS.ClipRect, CMD_RHS.ClipRect -- [Luau] cache
    if lcr.x ~= rcr.x or
        lcr.y ~= rcr.y or
        lcr.z ~= rcr.z or
        lcr.w ~= rcr.w then
        return false
    end

    local ltex, rtex = CMD_LHS.TexRef, CMD_RHS.TexRef
    if ltex ~= rtex and (ltex._TexData ~= rtex._TexData or
        ltex._TexID ~= rtex._TexID) then
        return false
    end

    if CMD_LHS.VtxOffset ~= CMD_RHS.VtxOffset then
        return false
    end

    return true
end

--- Copy ClipRect, TexRef, VtxOffset
--- @param CMD_DST ImDrawCmd|ImDrawCmdHeader
--- @param CMD_SRC ImDrawCmd|ImDrawCmdHeader
local function ImDrawCmd_HeaderCopy(CMD_DST, CMD_SRC)
    CMD_DST.ClipRect.x = CMD_SRC.ClipRect.x
    CMD_DST.ClipRect.y = CMD_SRC.ClipRect.y
    CMD_DST.ClipRect.z = CMD_SRC.ClipRect.z
    CMD_DST.ClipRect.w = CMD_SRC.ClipRect.w

    CMD_DST.TexRef._TexData = CMD_SRC.TexRef._TexData
    CMD_DST.TexRef._TexID = CMD_SRC.TexRef._TexID

    CMD_DST.VtxOffset = CMD_SRC.VtxOffset
end

--- @param CMD_0 ImDrawCmd
--- @param CMD_1 ImDrawCmd
local function ImDrawCmd_AreSequentialIdxOffset(CMD_0, CMD_1)
    return CMD_0.IdxOffset + CMD_0.ElemCount == CMD_1.IdxOffset
end

-- Try to merge two last draw commands
function MT.ImDrawList:_TryMergeDrawCmds()
    IM_ASSERT_PARANOID(self.CmdBuffer.Size > 0)
    local curr_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    local prev_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size - 1]
    if ImDrawCmd_HeaderCompare(curr_cmd, prev_cmd) and ImDrawCmd_AreSequentialIdxOffset(prev_cmd, curr_cmd) and curr_cmd.UserCallback == nil and prev_cmd.UserCallback == nil then
        prev_cmd.ElemCount = prev_cmd.ElemCount + curr_cmd.ElemCount
        self.CmdBuffer:pop_back()
    end
end

-- Our scheme may appears a bit unusual, basically we want the most-common calls AddLine AddRect etc. to not have to perform any check so we always have a command ready in the stack.
-- The cost of figuring out if a new command has to be added or if we can merge is paid in those Update** functions only.
@native
function MT.ImDrawList:_OnChangedClipRect()
    -- If current command is used with different settings we need to add a new command
    IM_ASSERT_PARANOID(self.CmdBuffer.Size > 0)
    local curr_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    if curr_cmd.ElemCount ~= 0 then
        -- [Luau] inline IM_VEC4.__eq
        local hcr, ccr = self._CmdHeader.ClipRect, curr_cmd.ClipRect
        if hcr.x ~= ccr.x or hcr.y ~= ccr.y or hcr.z ~= ccr.z or hcr.w ~= ccr.w then
            self:AddDrawCmd()

            return
        end
    end

    IM_ASSERT(curr_cmd.UserCallback == nil)

    -- Try to merge with previous command if it matches, else use current command
    local prev_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size - 1]
    if (curr_cmd.ElemCount == 0 and self.CmdBuffer.Size > 1 and ImDrawCmd_HeaderCompare(self._CmdHeader, prev_cmd) and ImDrawCmd_AreSequentialIdxOffset(prev_cmd, curr_cmd) and prev_cmd.UserCallback == nil) then
        self.CmdBuffer:pop_back()

        return
    end

    ImVec4_Copy(curr_cmd.ClipRect, self._CmdHeader.ClipRect)
end

function MT.ImDrawList:_OnChangedTexture()
    -- If current command is used with different settings we need to add a new command
    IM_ASSERT_PARANOID(self.CmdBuffer.Size > 0)
    local curr_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    if curr_cmd.ElemCount ~= 0 and curr_cmd.TexRef ~= self._CmdHeader.TexRef then
        self:AddDrawCmd()

        return
    end

    -- Unlike other _OnChangedXXX functions this may be called by ImFontAtlasUpdateDrawListsTextures() in more locations so we need to handle this case.
    if curr_cmd.UserCallback ~= nil then
        return
    end

    -- Try to merge with previous command if it matches, else use current command
    local prev_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size - 1]
    if curr_cmd.ElemCount == 0 and self.CmdBuffer.Size > 1 and ImDrawCmd_HeaderCompare(self._CmdHeader, prev_cmd) and ImDrawCmd_AreSequentialIdxOffset(prev_cmd, curr_cmd) and prev_cmd.UserCallback == nil then
        self.CmdBuffer:pop_back()

        return
    end

    curr_cmd.TexRef = self._CmdHeader.TexRef
end

function MT.ImDrawList:_OnChangedVtxOffset()
    -- We don't need to compare curr_cmd.VtxOffset ~= _CmdHeader.VtxOffset because we know it'll be different at the time we call this.
    self._VtxCurrentIdx = 1
    IM_ASSERT_PARANOID(self.CmdBuffer.Size > 0)

    local curr_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    --IM_ASSERT(curr_cmd.VtxOffset ~= self._CmdHeader.VtxOffset) -- See #3349
    if curr_cmd.ElemCount ~= 0 then
        self:AddDrawCmd()
        return
    end
    IM_ASSERT(curr_cmd.UserCallback == nil)
    curr_cmd.VtxOffset = self._CmdHeader.VtxOffset
end

-------------------------------------------------------------------------------
-- [SECTION] ImDrawListSplitter
-------------------------------------------------------------------------------
-- FIXME: This may be a little confusing, trying to be a little too low-level/optimal instead of just doing vector swap..
-------------------------------------------------------------------------------
-- [Port] channels swap ImVector objects with the draw list (C++ memcpy of the vector headers).
-- Channel 0 holds nothing while it is the current channel (its buffers live in the draw list).

-- Copy ClipRect, TexRef, VtxOffset (TexRef is assigned by reference, never mutated)
local function ImDrawCmd_HeaderCopyRef(dst, src)
    ImVec4_Copy(dst.ClipRect, src.ClipRect)
    dst.TexRef = src.TexRef
    dst.VtxOffset = src.VtxOffset
end

function MT.ImDrawListSplitter:Clear()
    self._Current = 0
    self._Count = 1
end

function MT.ImDrawListSplitter:ClearFreeMemory()
    for i = 1, self._Channels.Size do
        local ch = self._Channels.Data[i]
        if i - 1 == self._Current then
            -- Current channel is a copy of CmdBuffer/IdxBuffer, don't destruct again
            self._Channels.Data[i] = ImDrawChannel()
        else
            ch._CmdBuffer:clear()
            ch._IdxBuffer:clear()
        end
    end
    self._Current = 0
    self._Count = 1
    self._Channels:clear()
end

--- @param draw_list      ImDrawList
--- @param channels_count int
function MT.ImDrawListSplitter:Split(draw_list, channels_count)
    IM_ASSERT(self._Current == 0 and self._Count <= 1, "Nested channel splitting is not supported. Please use separate instances of ImDrawListSplitter.")
    local old_channels_count = self._Channels.Size
    if old_channels_count < channels_count then
        self._Channels:reserve(channels_count) -- Avoid over reserving since this is likely to stay stable
        self._Channels:resize(channels_count)
    end
    self._Count = channels_count

    -- Channels[] hold storage that we'll swap with draw_list._CmdBuffer/_IdxBuffer
    -- The content of Channels[0] at this point doesn't matter. We clear it to make state tidy in a debugger but we don't strictly need to.
    -- When we switch to the next channel, we'll copy draw_list._CmdBuffer/_IdxBuffer into Channels[0] and then Channels[1] into draw_list.CmdBuffer/_IdxBuffer
    -- [Port] Channel 0 is the draw list itself (memset to 0 in C++)
    local channels = self._Channels.Data
    channels[1] = { _CmdBuffer = nil, _IdxBuffer = nil }
    for i = 2, channels_count do
        if i > old_channels_count or channels[i] == nil then
            channels[i] = ImDrawChannel()
        else
            channels[i]._CmdBuffer.Size = 0 -- [Luau] inline resize(0)
            channels[i]._IdxBuffer.Size = 0
        end
    end
end

--- @param draw_list ImDrawList
function MT.ImDrawListSplitter:Merge(draw_list)
    -- Note that we never use or rely on _Channels.Size because it is merely a buffer that we never shrink back to 0 to keep all sub-buffers ready for use.
    if self._Count <= 1 then
        return
    end

    self:SetCurrentChannel(draw_list, 0)
    draw_list:_PopUnusedDrawCmd()

    -- Calculate our final buffer sizes. Also fix the incorrect IdxOffset values in each command.
    local new_cmd_buffer_count = 0
    local new_idx_buffer_count = 0
    local last_cmd = (self._Count > 0 and draw_list.CmdBuffer.Size > 0) and draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size] or nil
    local idx_offset = last_cmd and (last_cmd.IdxOffset + last_cmd.ElemCount) or 0
    local channels = self._Channels.Data
    for i = 2, self._Count do
        local ch = channels[i]
        local cmds = ch._CmdBuffer
        if cmds.Size > 0 and cmds.Data[cmds.Size].ElemCount == 0 and cmds.Data[cmds.Size].UserCallback == nil then -- Equivalent of PopUnusedDrawCmd()
            cmds:pop_back()
        end

        if cmds.Size > 0 and last_cmd ~= nil then
            -- Do not include ImDrawCmd_AreSequentialIdxOffset() in the compare as we rebuild IdxOffset values ourselves.
            -- Manipulating IdxOffset (e.g. by reordering draw commands like done by RenderDimmedBackgroundBehindWindow()) is not supported within a splitter.
            local next_cmd = cmds.Data[1]
            if ImDrawCmd_HeaderCompare(last_cmd, next_cmd) and last_cmd.UserCallback == nil and next_cmd.UserCallback == nil then
                -- Merge previous channel last draw command with current channel first draw command if matching.
                last_cmd.ElemCount = last_cmd.ElemCount + next_cmd.ElemCount
                idx_offset = idx_offset + next_cmd.ElemCount
                -- [Luau] cmds:erase(1), keeping the erased command object past Size for AddDrawCmd() to reuse
                local d = cmds.Data
                for k = 1, cmds.Size - 1 do d[k] = d[k + 1] end
                d[cmds.Size] = next_cmd
                cmds.Size = cmds.Size - 1 -- FIXME-OPT: Improve for multiple merges.
            end
        end
        if cmds.Size > 0 then
            last_cmd = cmds.Data[cmds.Size]
        end
        new_cmd_buffer_count = new_cmd_buffer_count + cmds.Size
        new_idx_buffer_count = new_idx_buffer_count + ch._IdxBuffer.Size
        for cmd_n = 1, cmds.Size do
            cmds.Data[cmd_n].IdxOffset = idx_offset
            idx_offset = idx_offset + cmds.Data[cmd_n].ElemCount
        end
    end
    local cmd_write = draw_list.CmdBuffer.Size + 1
    local idx_write = draw_list.IdxBuffer.Size + 1
    draw_list.CmdBuffer:resize(draw_list.CmdBuffer.Size + new_cmd_buffer_count)
    draw_list.IdxBuffer:resize(draw_list.IdxBuffer.Size + new_idx_buffer_count)

    -- Write commands and indices in order (they are fairly small structures, we don't copy vertices only indices)
    local dst_cmds = draw_list.CmdBuffer.Data
    local dst_idx = draw_list.IdxBuffer.Data
    for i = 2, self._Count do
        local ch = channels[i]
        -- [Luau] skip empty buffers: their .Data may be nil (reading it goes through IM_VECTOR.__index)
        if ch._CmdBuffer.Size > 0 then
            local src_cmds = ch._CmdBuffer.Data
            for n = 1, ch._CmdBuffer.Size do
                -- [Port] ownership moved to the draw list; [Luau] the unused command object that was in the draw list's
                -- slot goes to the channel's slot instead of nil (AddDrawCmd() reuses it: each object stays in one slot)
                dst_cmds[cmd_write], src_cmds[n] = src_cmds[n], dst_cmds[cmd_write]
                cmd_write = cmd_write + 1
            end
        end
        if ch._IdxBuffer.Size > 0 then
            local src_idx = ch._IdxBuffer.Data
            for n = 1, ch._IdxBuffer.Size do
                dst_idx[idx_write] = src_idx[n]
                idx_write = idx_write + 1
            end
        end
    end
    draw_list._IdxWritePtr = idx_write

    -- Ensure there's always a non-callback draw command trailing the command-buffer
    if draw_list.CmdBuffer.Size == 0 or draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size].UserCallback ~= nil then
        draw_list:AddDrawCmd()
    end

    -- If current command is used with different settings we need to add a new command
    local curr_cmd = draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size]
    if curr_cmd.ElemCount == 0 then
        ImDrawCmd_HeaderCopyRef(curr_cmd, draw_list._CmdHeader) -- Copy ClipRect, TexRef, VtxOffset
    elseif not ImDrawCmd_HeaderCompare(curr_cmd, draw_list._CmdHeader) then
        draw_list:AddDrawCmd()
    end

    self._Count = 1
end

--- @param draw_list ImDrawList
--- @param idx       int # 0-based channel index
@native
function MT.ImDrawListSplitter:SetCurrentChannel(draw_list, idx)
    IM_ASSERT(idx >= 0 and idx < self._Count)
    if self._Current == idx then
        return
    end

    -- Overwrite ImVector (12/16 bytes), four times. This is merely a silly optimization instead of doing .swap()
    local channels = self._Channels.Data
    local cur = channels[self._Current + 1]
    cur._CmdBuffer = draw_list.CmdBuffer
    cur._IdxBuffer = draw_list.IdxBuffer
    self._Current = idx
    local ch = channels[idx + 1]
    local cmd_buffer = ch._CmdBuffer
    local idx_buffer = ch._IdxBuffer
    draw_list.CmdBuffer = cmd_buffer
    draw_list.IdxBuffer = idx_buffer
    draw_list._IdxWritePtr = idx_buffer.Size + 1

    -- If current command is used with different settings we need to add a new command
    -- [Luau] ImDrawCmd_HeaderCopyRef() / ImDrawCmd_HeaderCompare() inlined
    local cmd_count = cmd_buffer.Size
    if cmd_count == 0 then
        draw_list:AddDrawCmd()
        return
    end
    local curr_cmd = cmd_buffer.Data[cmd_count]
    local header = draw_list._CmdHeader
    local hcr, ccr = header.ClipRect, curr_cmd.ClipRect
    if curr_cmd.ElemCount == 0 then
        ccr.x = hcr.x; ccr.y = hcr.y; ccr.z = hcr.z; ccr.w = hcr.w -- Copy ClipRect, TexRef, VtxOffset
        curr_cmd.TexRef = header.TexRef
        curr_cmd.VtxOffset = header.VtxOffset
    elseif ccr.x ~= hcr.x or ccr.y ~= hcr.y or ccr.z ~= hcr.z or ccr.w ~= hcr.w
        or (curr_cmd.TexRef ~= header.TexRef and (curr_cmd.TexRef._TexData ~= header.TexRef._TexData or curr_cmd.TexRef._TexID ~= header.TexRef._TexID))
        or curr_cmd.VtxOffset ~= header.VtxOffset then
        draw_list:AddDrawCmd()
    end
end

--- @param count int
function MT.ImDrawList:ChannelsSplit(count) self._Splitter:Split(self, count) end
function MT.ImDrawList:ChannelsMerge() self._Splitter:Merge(self) end
--- @param n int # 0-based
function MT.ImDrawList:ChannelsSetCurrent(n) self._Splitter:SetCurrentChannel(self, n) end

function MT.ImDrawList:PushTexture(tex_ref)
    self._TextureStack:push_back(tex_ref)
    self._CmdHeader.TexRef = tex_ref
    if (tex_ref._TexData ~= nil) then
        IM_ASSERT(tex_ref._TexData.WantDestroyNextFrame == false)
    end
    self:_OnChangedTexture()
end

function MT.ImDrawList:PopTexture()
    self._TextureStack:pop_back()
    self._CmdHeader.TexRef = (self._TextureStack.Size == 0) and ImTextureRef() or self._TextureStack.Data[self._TextureStack.Size]
    self:_OnChangedTexture()
end

-- IMPORTANT: currently limited to 3 deep
--- @param flags   ImDrawFlags
--- @param enabled bool
function MT.ImDrawList:PushDrawFlag(flags, enabled)
    IM_ASSERT(bit32.band(flags, bit32.bnot(ImDrawFlags.AllowInPushScope_)) == 0)
    IM_ASSERT(bit32.band(flags, ImDrawFlags.StrokeMask_) == 0 or bit32.band(flags, ImDrawFlags.StrokeMask_) == ImDrawFlags.StrokeLegacy)
    IM_ASSERT_USER_ERROR_RET(self._DrawFlagsStack.Size < 3, "PushDrawFlag() has a depth limit. Contact us.") -- [Port] _DrawFlagsStack.capacity() == 3
    self._DrawFlagsStack:push_back(self.Flags)
    if enabled then
        self.Flags = bit32.bor(self.Flags, flags)
    else
        self.Flags = bit32.band(self.Flags, bit32.bnot(flags))
    end
end

function MT.ImDrawList:PopDrawFlag()
    IM_ASSERT_USER_ERROR_RET(self._DrawFlagsStack.Size > 0, "Calling PopDrawFlag() too many times!")
    self.Flags = self._DrawFlagsStack:back()
    self._DrawFlagsStack:pop_back()
end

-- This is used by ImGui.PushFont()/PopFont(). It works because we never use _TextureIdStack[] elsewhere than in PushTexture()/PopTexture().
function MT.ImDrawList:_SetTexture(tex_ref)
    if (self._CmdHeader.TexRef == tex_ref) then
        return
    end
    self._CmdHeader.TexRef = tex_ref
    self._TextureStack.Data[self._TextureStack.Size] = tex_ref
    self:_OnChangedTexture()
end

--- @param pixel_density float
function MT.ImDrawList:_SetPixelDensity(pixel_density)
    IM_ASSERT(pixel_density > 0.0)
    self._FringeScale = 1.0 / pixel_density
    self._InvFringeScale = pixel_density
    self._FringeScaleIsInteger = ImIsTruncated(self._InvFringeScale)
end

-- Reserve space for a number of vertices and indices.
-- You must finish filling your reserved data before calling PrimReserve() again, as it may reallocate or
-- submit the intermediate results. PrimUnreserve() can be used to release unused allocations.
-- [Luau] local function (also MT.ImDrawList.PrimReserve): hot callers in this file skip the method lookup
@native
local function PrimReserve(self, idx_count, vtx_count)
    -- Large mesh support (when enabled)
    IM_ASSERT_PARANOID(idx_count >= 0 and vtx_count >= 0)

    if (self._VtxCurrentIdx + vtx_count >= bit32.lshift(1, 16)) and (bit32.band(self.Flags, ImDrawFlags.UseVtxOffset) ~= 0) then
        -- FIXME: In theory we should be testing that vtx_count <64k here.
        -- In practice, RenderText() relies on reserving ahead for a worst case scenario so it is currently useful for us
        -- to not make that check until we rework the text functions to handle clipping and large horizontal lines better.
        self._CmdHeader.VtxOffset = self.VtxBuffer.Size + 1
        self:_OnChangedVtxOffset()
    end

    local draw_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    draw_cmd.ElemCount = draw_cmd.ElemCount + idx_count

    -- [Luau] inline resize() when no growth is needed (IdxBuffer:resize goes through IM_VECTOR.__index)
    local vtx_buffer = self.VtxBuffer
    local vtx_buffer_old_size = vtx_buffer.Size
    local vtx_new_size = vtx_buffer_old_size + vtx_count
    if vtx_new_size > vtx_buffer.Capacity then vtx_buffer:resize(vtx_new_size) else vtx_buffer.Size = vtx_new_size end
    self._VtxWritePtr = vtx_buffer_old_size + 1

    local idx_buffer = self.IdxBuffer
    local idx_buffer_old_size = idx_buffer.Size
    local idx_new_size = idx_buffer_old_size + idx_count
    if idx_new_size > idx_buffer.Capacity then idx_buffer:resize(idx_new_size) else idx_buffer.Size = idx_new_size end
    self._IdxWritePtr = idx_buffer_old_size + 1
end
MT.ImDrawList.PrimReserve = PrimReserve

-- Release the number of reserved vertices/indices from the end of the last reservation made with PrimReserve().
@native
function MT.ImDrawList:PrimUnreserve(idx_count, vtx_count)
    IM_ASSERT_PARANOID(idx_count >= 0 and vtx_count >= 0)

    local draw_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    draw_cmd.ElemCount = draw_cmd.ElemCount - idx_count

    self.VtxBuffer:shrink(self.VtxBuffer.Size - vtx_count)
    self.IdxBuffer:shrink(self.IdxBuffer.Size - idx_count)

    self._VtxWritePtr = self.VtxBuffer.Size + 1
    self._IdxWritePtr = self.IdxBuffer.Size + 1
end

-- Fully unrolled with inline call to keep our debug builds decently fast.
--- @param a   ImVec2
--- @param c   ImVec2
--- @param col ImU32
-- [Luau] scalar PrimRect (a = ax,ay; c = cx,cy): no ImVec2 needed by callers, vertex writes inlined
@native
local function PrimRectXY(self, ax, ay, cx, cy, col)
    local uv = self._Data.TexUvWhitePixel

    local idx = self._VtxCurrentIdx
    local idx_data = self.IdxBuffer.Data; local b = self.VtxBuffer.Buf

    local idx_write_ptr = self._IdxWritePtr
    idx_data[idx_write_ptr + 0] = idx
    idx_data[idx_write_ptr + 1] = idx + 1
    idx_data[idx_write_ptr + 2] = idx + 2

    idx_data[idx_write_ptr + 3] = idx
    idx_data[idx_write_ptr + 4] = idx + 2
    idx_data[idx_write_ptr + 5] = idx + 3

    local vtx_write_ptr = self._VtxWritePtr
    local u, v = uv.x, uv.y
    local o = (vtx_write_ptr - 1) * 36
    writef64(b, o, ax); writef64(b, o + 8, ay); writef64(b, o + 16, u); writef64(b, o + 24, v); writeu32(b, o + 32, col)
    writef64(b, o + 36, cx); writef64(b, o + 44, ay); writef64(b, o + 52, u); writef64(b, o + 60, v); writeu32(b, o + 68, col)
    writef64(b, o + 72, cx); writef64(b, o + 80, cy); writef64(b, o + 88, u); writef64(b, o + 96, v); writeu32(b, o + 104, col)
    writef64(b, o + 108, ax); writef64(b, o + 116, cy); writef64(b, o + 124, u); writef64(b, o + 132, v); writeu32(b, o + 140, col)

    self._VtxWritePtr = vtx_write_ptr + 4
    self._VtxCurrentIdx = idx + 4
    self._IdxWritePtr = idx_write_ptr + 6
end

function MT.ImDrawList:PrimRect(a, c, col)
    PrimRectXY(self, a.x, a.y, c.x, c.y, col)
end

--- @param a    ImVec2
--- @param c    ImVec2
--- @param uv_a ImVec2
--- @param uv_c ImVec2
--- @param col  any
@native
function MT.ImDrawList:PrimRectUV(a, c, uv_a, uv_c, col)
    local idx = self._VtxCurrentIdx
    local idx_data = self.IdxBuffer.Data; local vtx_data = self.VtxBuffer.Buf

    local idx_write_ptr = self._IdxWritePtr
    idx_data[idx_write_ptr + 0] = idx
    idx_data[idx_write_ptr + 1] = idx + 1
    idx_data[idx_write_ptr + 2] = idx + 2

    idx_data[idx_write_ptr + 3] = idx
    idx_data[idx_write_ptr + 4] = idx + 2
    idx_data[idx_write_ptr + 5] = idx + 3

    local vtx_write_ptr = self._VtxWritePtr
    WV(vtx_data, vtx_write_ptr + 0, a.x, a.y, uv_a.x, uv_a.y, col)
    WV(vtx_data, vtx_write_ptr + 1, c.x, a.y, uv_c.x, uv_a.y, col)
    WV(vtx_data, vtx_write_ptr + 2, c.x, c.y, uv_c.x, uv_c.y, col)
    WV(vtx_data, vtx_write_ptr + 3, a.x, c.y, uv_a.x, uv_c.y, col)

    self._VtxWritePtr   = vtx_write_ptr + 4
    self._VtxCurrentIdx = idx + 4
    self._IdxWritePtr   = idx_write_ptr + 6
end

function MT.ImDrawList:PrimQuadUV(a, b, c, d, uv_a, uv_b, uv_c, uv_d, col)
    local idx = self._VtxCurrentIdx
    local idx_data = self.IdxBuffer.Data; local vtx_data = self.VtxBuffer.Buf
    local idx_write_ptr = self._IdxWritePtr
    idx_data[idx_write_ptr + 0] = idx; idx_data[idx_write_ptr + 1] = idx + 1; idx_data[idx_write_ptr + 2] = idx + 2
    idx_data[idx_write_ptr + 3] = idx; idx_data[idx_write_ptr + 4] = idx + 2; idx_data[idx_write_ptr + 5] = idx + 3
    local vtx_write_ptr = self._VtxWritePtr
    WV(vtx_data, vtx_write_ptr + 0, a.x, a.y, uv_a.x, uv_a.y, col)
    WV(vtx_data, vtx_write_ptr + 1, b.x, b.y, uv_b.x, uv_b.y, col)
    WV(vtx_data, vtx_write_ptr + 2, c.x, c.y, uv_c.x, uv_c.y, col)
    WV(vtx_data, vtx_write_ptr + 3, d.x, d.y, uv_d.x, uv_d.y, col)
    self._VtxWritePtr = vtx_write_ptr + 4
    self._VtxCurrentIdx = idx + 4
    self._IdxWritePtr = idx_write_ptr + 6
end

--- @param thickness float
--- @return float
-- [Luau] local function (also MT.ImDrawList._CalculateCenterBiasedOffset)
local function _CalculateCenterBiasedOffset(self, thickness)
    -- Old jumpy one.
    -- return IM_TRUNC(thickness * 0.5f / _FringeScale) * _FringeScale;

    -- Calculate outside offset for stroke position ImDrawFlags_StrokeCenterBiased
    -- so that one side the of the line is always at pixel boundary.
    -- On integer thickness both sides of the line are on pixel boundary.
    local screen_thickness = thickness * self._InvFringeScale
    local s_thickness = math.floor(screen_thickness) -- (int) of a positive value
    return (math.floor(s_thickness / 2) + (s_thickness % 2) * (screen_thickness - s_thickness)) * self._FringeScale
end
MT.ImDrawList._CalculateCenterBiasedOffset = _CalculateCenterBiasedOffset

-- Check if R is considered to be worthy rounding. Can be only used within ImDrawList due to use of _FringeScale.
-- #define IM_HAS_ROUNDING(RAD) ((RAD) >= (0.25f * _FringeScale)) -- [Luau] written inline at each use

-- Select texture and adjust fringe size for specified line thickness.
-- [Luau] returns uv0.x, uv0.y, uv1.x, uv1.y, fringe instead of writing to out parameters
--- @param screen_thickness float
--- @param flags            ImDrawFlags
local function _SelectLineTexture(self, screen_thickness, flags)
    -- We assume that the screen_thickness has been clamped to 1.0 by the caller.
    IM_ASSERT_PARANOID(screen_thickness >= 1.0)

    if bit32.band(flags, ImDrawFlags.AALines) ~= 0 then
        -- Handle the thickness between 1.0 - IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH].
        -- We use super sampled textures in this range to make texture changes less noticeable.
        -- There are IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH_COUNT textures, where 0 maps to 1.0 and IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH_COUNT-1 maps to IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH (4.0).
        local texture_idx
        if screen_thickness <= IM_DRAWLIST_TEX_LINES_DETAILED_WIDTH then
            texture_idx = math.floor((screen_thickness - 1.0) * IM_DRAWLIST_TEX_LINES_SAMPLE_COUNT + 0.5) + (IM_DRAWLIST_TEX_LINES_WIDTH_MAX + 1)
        elseif screen_thickness < IM_DRAWLIST_TEX_LINES_WIDTH_MAX - 1.5 then
            texture_idx = math.floor(screen_thickness + 0.5)
        else
            texture_idx = IM_DRAWLIST_TEX_LINES_WIDTH_MAX - 1 -- Catches large values of screen_thickness (and +inf/NaN) that a ImMin() wouldn't.
        end

        -- Scale the fringe so that the texture matches the line thickness.
        local tex_uvs = self._Data.TexUvLines[texture_idx] -- [Port] 0-based table
        return tex_uvs.x, tex_uvs.z, tex_uvs.y, tex_uvs.z, self._FringeScale * screen_thickness * tex_uvs.w -- tex_uvs.w = 1 / thickness
    else
        -- For no anti-alias we use fully opaque texture, and no fringe expansion.
        local uv = self._Data.TexUvWhitePixel
        return uv.x, uv.y, uv.x, uv.y, 0.0
    end
end
MT.ImDrawList._SelectLineTexture = _SelectLineTexture

-- [Luau] scratch arrays (normals x/y and squared segment lengths) used instead of _Data->TempBuffer: no ImVec2 per point
local poly_normals_x, poly_normals_y, poly_sqr_lengths = {}, {}, {}

--- @param points           ImVec2[] # 1-based
--- @param points_count     int
--- @param col              ImU32
--- @param thickness        float
--- @param flags            ImDrawFlags
--- @param max_inner_offset float
-- [Luau] IM_APPEND_VTX()/IM_APPEND_TRI() are expanded inline: vertex/index write pointers and _VtxCurrentIdx kept in locals, stored back at the end
@native
function MT.ImDrawList:_AddPolyline(points, points_count, col, thickness, flags, max_inner_offset)
    if points_count < 2 or bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local screen_thickness = thickness * self._InvFringeScale
    if screen_thickness < 1.0 then
        if screen_thickness < 1.0 / 255.0 then
            return
        end
        col = ImAlphaMultiply(col, screen_thickness)
        screen_thickness = 1.0
        thickness = self._FringeScale
    end

    -- If this assert triggers on legacy code:
    -- - 1.92.8 (2025/05): swapped two last parameters order: flags, thickness --> thickness, flags. This should normally be caught by compile-time type-checking.
    -- - 1.92.8 (2025/05): changed value of ImDrawList_Closed which was previously guaranteed to be == 1. Hardcoded use of 1 or true should be replaced.
    -- Read more details near AddRect() + see "API BREAKING CHANGES" section for 1.82, 1.90 and 1.92.8.
    flags = bit32.bor(flags, self.Flags)
    IM_ASSERT_USER_ERROR_RET(bit32.band(flags, ImDrawFlags.InvalidMask_) == 0, "Incorrect parameter. Did you swap 'thickness' and 'flags'?")

    -- Allocate data for temp buffers
    local normals_x, normals_y, sqr_lengths = poly_normals_x, poly_normals_y, poly_sqr_lengths

    -- Calculate normals for each line segment
    for i = 1, points_count - 1 do
        local p0 = points[i]
        local p1 = points[i + 1]
        local dx = p1.x - p0.x
        local dy = p1.y - p0.y
        local d2 = dx * dx + dy * dy
        local inv_len = 0.0
        if d2 > 0.0 then inv_len = 1.0 / math.sqrt(d2) end -- [Port] ImRsqrtPrecise()
        normals_x[i] = -dy * inv_len
        normals_y[i] = dx * inv_len
        sqr_lengths[i] = d2
    end
    if bit32.band(flags, ImDrawFlags.Closed) ~= 0 then
        local p0 = points[points_count]
        local p1 = points[1]
        local dx = p1.x - p0.x
        local dy = p1.y - p0.y
        local d2 = dx * dx + dy * dy
        local inv_len = 0.0
        if d2 > 0.0 then inv_len = 1.0 / math.sqrt(d2) end -- [Port] ImRsqrtPrecise()
        normals_x[points_count] = -dy * inv_len
        normals_y[points_count] = dx * inv_len
        sqr_lengths[points_count] = d2
    else
        normals_x[points_count] = normals_x[points_count - 1]
        normals_y[points_count] = normals_y[points_count - 1]
        sqr_lengths[points_count] = 0.0
    end

    local u0, v0, u1, v1, fringe = _SelectLineTexture(self, screen_thickness, flags)

    local col_trans = bit32.band(col, bit32.bnot(IM_COL32_A_MASK))

    local stroke_pos = _GetStrokePos(flags, ImDrawFlags.StrokeCenter)
    if stroke_pos == ImDrawFlags.StrokeLegacy then
        flags = bit32.band(bit32.bor(flags, ImDrawFlags.JoinMiter), bit32.bnot(ImDrawFlags.AALineEnds))
    end

    local closed = bit32.band(flags, ImDrawFlags.Closed) ~= 0
    local miters_only = bit32.band(flags, ImDrawFlags.JoinMiter) ~= 0
    local miter_distance_limit_sqr = IM_POLYLINE_MITER_LIMIT * IM_POLYLINE_MITER_LIMIT

    local thickness0 = (thickness + fringe) * 0.5 -- Center (or legacy)
    if stroke_pos == ImDrawFlags.StrokeOutside then
        thickness0 = thickness + fringe * 0.5
    elseif stroke_pos == ImDrawFlags.StrokeCenterBiased then
        thickness0 = _CalculateCenterBiasedOffset(self, thickness) + fringe * 0.5
    elseif stroke_pos == ImDrawFlags.StrokeInside then
        thickness0 = fringe * 0.5
    end
    local thickness1 = (thickness + fringe) - thickness0

    local idx_count = 0
    local vtx_count = 0
    local max_verts_per_point = miters_only and 2 or 4
    local max_tris_per_point = miters_only and 2 or 5
    if closed then
        vtx_count = --[[body]] points_count * max_verts_per_point + --[[closing]] 2
        idx_count = (--[[body]] points_count * max_tris_per_point + --[[closing]] 2) * 3
    else
        vtx_count = --[[body]] (points_count - 2) * max_verts_per_point + --[[caps]] (4 * 2)
        idx_count = (--[[body]] (points_count - 2) * max_tris_per_point + --[[last seg]] 2 + --[[caps]] (2 * 2)) * 3
    end
    PrimReserve(self, idx_count, vtx_count)

    local ratio = thickness0 / (thickness0 + thickness1) -- The points that use uv2 are placed directly on the path (offset = 0), calculate the texture position from stroke offsets.
    local u2, v2 = u0 + (u1 - u0) * ratio, v0

    -- Clamp inner offset and adjust texture coordinates to match the change.
    -- This is used by some of the convex shape rendering to avoid rendering artifacts when thickness is about to fill the whole shape.
    if thickness1 > max_inner_offset then
        thickness1 = max_inner_offset
        local s = (thickness0 + thickness1) / (thickness + fringe)
        local du = u1 - u0
        u1 = u0 + du * s
    end

    local half_aa = self._FringeScale * 0.5 -- Used for end caps, does not use "fringe" since end cap AA is not using the texture.
    local use_aa_ends = bit32.band(flags, bit32.bor(ImDrawFlags.AALines, ImDrawFlags.AALineEnds)) == bit32.bor(ImDrawFlags.AALines, ImDrawFlags.AALineEnds)

    local vb = self.VtxBuffer.Buf
    local ib = self.IdxBuffer.Data
    local vw = self._VtxWritePtr     -- [Port] 1-based write position in VtxBuffer
    local iw = self._IdxWritePtr     -- [Port] 1-based write position in IdxBuffer
    local vtx_idx = self._VtxCurrentIdx
    local first_vtx_offset = vw
    local first_vtx_idx = vtx_idx    -- [Luau] VtxBuffer position of index 'n' is first_vtx_offset + (n - first_vtx_idx)
    local base_idx = vtx_idx

    local p1x, p1y
    local n1x, n1y
    local len_sqr1

    local point_idx = 1 -- [Luau] 1-based, iterate point_idx..point_last inclusive
    local point_last = points_count
    if not closed then
        -- Start cap
        point_idx = point_idx + 1
        point_last = point_last - 1
        local p = points[1]
        p1x, p1y = p.x, p.y
        n1x, n1y = normals_x[1], normals_y[1]
        len_sqr1 = sqr_lengths[1]

        local dir_x = n1y
        local dir_y = -n1x
        if bit32.band(flags, ImDrawFlags.CapSquare) ~= 0 then
            p1x = p1x - dir_x * thickness * 0.5
            p1y = p1y - dir_y * thickness * 0.5
        end

        if not use_aa_ends then
            base_idx = vtx_idx
            WV(vb, vw + 0, p1x - n1x * thickness0, p1y - n1y * thickness0, u0, v0, col)
            WV(vb, vw + 1, p1x + n1x * thickness1, p1y + n1y * thickness1, u1, v1, col)
            vw = vw + 2; vtx_idx = vtx_idx + 2
        else
            local pa_x = p1x - dir_x * half_aa
            local pa_y = p1y - dir_y * half_aa
            local pb_x = p1x + dir_x * half_aa
            local pb_y = p1y + dir_y * half_aa

            base_idx = vtx_idx
            WV(vb, vw + 0, pa_x - n1x * thickness0, pa_y - n1y * thickness0, u0, v0, col_trans)
            WV(vb, vw + 1, pa_x + n1x * thickness1, pa_y + n1y * thickness1, u1, v1, col_trans)

            local next_base_idx = vtx_idx + 2
            WV(vb, vw + 2, pb_x - n1x * thickness0, pb_y - n1y * thickness0, u0, v0, col)
            WV(vb, vw + 3, pb_x + n1x * thickness1, pb_y + n1y * thickness1, u1, v1, col)
            vw = vw + 4; vtx_idx = vtx_idx + 4

            -- AA cap
            ib[iw + 0] = base_idx + 0; ib[iw + 1] = base_idx + 2; ib[iw + 2] = base_idx + 3
            ib[iw + 3] = base_idx + 0; ib[iw + 4] = base_idx + 3; ib[iw + 5] = base_idx + 1
            iw = iw + 6
            base_idx = next_base_idx
        end
    else
        -- Wrap around segment
        local p = points[points_count]
        p1x, p1y = p.x, p.y
        n1x, n1y = normals_x[points_count], normals_y[points_count]
        len_sqr1 = sqr_lengths[points_count]

        -- This will be filled later, allocate space.
        base_idx = vtx_idx
        WV(vb, vw + 0, 0, 0, u0, v0, col)
        WV(vb, vw + 1, 0, 0, u1, v1, col)
        vw = vw + 2; vtx_idx = vtx_idx + 2
    end

    if miters_only then
        for pi = point_idx, point_last do
            local n0x, n0y = n1x, n1y
            local p = points[pi]
            p1x, p1y = p.x, p.y
            n1x, n1y = normals_x[pi], normals_y[pi]

            -- theta is the angle between two segments
            local cos_theta = n0x * n1x + n0y * n1y

            -- miter offset formula is derived here: https://www.angusj.com/clipper2/Docs/Trigonometry.htm
            local cos_theta_clamped = (IM_POLYLINE_MITER_ANGLE_LIMIT >= cos_theta) and IM_POLYLINE_MITER_ANGLE_LIMIT or cos_theta -- Avoid div by 0.
            local miter_scale_factor = 1.0 / (1.0 + cos_theta_clamped)
            if miter_scale_factor > 1000.0 then miter_scale_factor = 1000.0 end
            local miter_offset_x = (n0x + n1x) * miter_scale_factor
            local miter_offset_y = (n0y + n1y) * miter_scale_factor

            -- Miter
            local next_base_idx = vtx_idx
            WV(vb, vw + 0, p1x - miter_offset_x * thickness0, p1y - miter_offset_y * thickness0, u0, v0, col) -- 2
            WV(vb, vw + 1, p1x + miter_offset_x * thickness1, p1y + miter_offset_y * thickness1, u1, v1, col) -- 3
            vw = vw + 2; vtx_idx = vtx_idx + 2

            -- Connect prev to next
            ib[iw + 0] = base_idx + 0; ib[iw + 1] = base_idx + 2; ib[iw + 2] = base_idx + 3
            ib[iw + 3] = base_idx + 0; ib[iw + 4] = base_idx + 3; ib[iw + 5] = base_idx + 1
            iw = iw + 6

            base_idx = next_base_idx
        end
    else
        for pi = point_idx, point_last do
            local n0x, n0y = n1x, n1y
            local len_sqr0 = len_sqr1
            local p = points[pi]
            p1x, p1y = p.x, p.y
            n1x, n1y = normals_x[pi], normals_y[pi]
            len_sqr1 = sqr_lengths[pi]

            -- theta is the angle between two segments
            local cos_theta = n0x * n1x + n0y * n1y
            local sin_theta = n0y * n1x - n0x * n1y

            -- miter offset formula is derived here: https://www.angusj.com/clipper2/Docs/Trigonometry.htm
            local cos_theta_clamped = (IM_POLYLINE_MITER_ANGLE_LIMIT >= cos_theta) and IM_POLYLINE_MITER_ANGLE_LIMIT or cos_theta -- Avoid div by 0.
            local miter_scale_factor = 1.0 / (1.0 + cos_theta_clamped)
            if miter_scale_factor > 1000.0 then miter_scale_factor = 1000.0 end
            local miter_offset_x = (n0x + n1x) * miter_scale_factor
            local miter_offset_y = (n0y + n1y) * miter_scale_factor

            local miter_distance_sqr = miter_offset_x * miter_offset_x + miter_offset_y * miter_offset_y

            if miter_distance_sqr > miter_distance_limit_sqr then
                -- Clipped bevel

                -- Limit the inner miter offset to avoid overshooting.
                local ref_thickness = (sin_theta < 0.0) and thickness1 or thickness0
                local ref_thickness_sqr = ref_thickness * ref_thickness
                local limit_sqr = ImMax(ImMax(len_sqr0, len_sqr1), ref_thickness_sqr)
                local ref_miter_dist_sqr = miter_distance_sqr * ref_thickness_sqr
                if ref_miter_dist_sqr > limit_sqr then
                    local scale = ImSqrt(limit_sqr / ref_miter_dist_sqr)
                    miter_offset_x = miter_offset_x * scale
                    miter_offset_y = miter_offset_y * scale
                end

                local bn_x, bn_y = IM_NORMALIZE2F_OVER_ZERO(n0x + n1x, n0y + n1y)

                local side_offset = ((n0x * bn_x + n0y * bn_y) - 1.0) / (n0y * bn_x - n0x * bn_y)
                local sd_x = bn_y * side_offset
                local sd_y = -bn_x * side_offset

                -- Bevel
                local next_base_idx = vtx_idx + 2
                if sin_theta < 0.0 then
                    WV(vb, vw + 0, p1x - (bn_x + sd_x) * thickness0, p1y - (bn_y + sd_y) * thickness0, u0, v0, col) -- 2
                    WV(vb, vw + 1, p1x, p1y, u2, v2, col) -- 3
                    WV(vb, vw + 2, p1x - (bn_x - sd_x) * thickness0, p1y - (bn_y - sd_y) * thickness0, u0, v0, col) -- 4
                    WV(vb, vw + 3, p1x + miter_offset_x * thickness1, p1y + miter_offset_y * thickness1, u1, v1, col) -- 5

                    -- Connect prev to next
                    ib[iw + 0] = base_idx + 0; ib[iw + 1] = base_idx + 2; ib[iw + 2] = base_idx + 5
                    ib[iw + 3] = base_idx + 0; ib[iw + 4] = base_idx + 5; ib[iw + 5] = base_idx + 1
                    -- Bevel
                    ib[iw + 6] = base_idx + 3; ib[iw + 7] = base_idx + 5; ib[iw + 8] = base_idx + 2
                    ib[iw + 9] = base_idx + 3; ib[iw + 10] = base_idx + 2; ib[iw + 11] = base_idx + 4
                    ib[iw + 12] = base_idx + 3; ib[iw + 13] = base_idx + 4; ib[iw + 14] = base_idx + 5
                else
                    WV(vb, vw + 0, p1x + (bn_x + sd_x) * thickness1, p1y + (bn_y + sd_y) * thickness1, u1, v1, col) -- 2
                    WV(vb, vw + 1, p1x, p1y, u2, v2, col) -- 3
                    WV(vb, vw + 2, p1x - miter_offset_x * thickness0, p1y - miter_offset_y * thickness0, u0, v0, col) -- 4
                    WV(vb, vw + 3, p1x + (bn_x - sd_x) * thickness1, p1y + (bn_y - sd_y) * thickness1, u1, v1, col) -- 5

                    -- Connect prev to next
                    ib[iw + 0] = base_idx + 0; ib[iw + 1] = base_idx + 4; ib[iw + 2] = base_idx + 2
                    ib[iw + 3] = base_idx + 0; ib[iw + 4] = base_idx + 2; ib[iw + 5] = base_idx + 1
                    -- Bevel
                    ib[iw + 6] = base_idx + 3; ib[iw + 7] = base_idx + 2; ib[iw + 8] = base_idx + 4
                    ib[iw + 9] = base_idx + 3; ib[iw + 10] = base_idx + 4; ib[iw + 11] = base_idx + 5
                    ib[iw + 12] = base_idx + 3; ib[iw + 13] = base_idx + 5; ib[iw + 14] = base_idx + 2
                end
                vw = vw + 4; vtx_idx = vtx_idx + 4
                iw = iw + 15
                base_idx = next_base_idx
            else
                -- Miter
                local next_base_idx = vtx_idx
                WV(vb, vw + 0, p1x - miter_offset_x * thickness0, p1y - miter_offset_y * thickness0, u0, v0, col) -- 2
                WV(vb, vw + 1, p1x + miter_offset_x * thickness1, p1y + miter_offset_y * thickness1, u1, v1, col) -- 3
                vw = vw + 2; vtx_idx = vtx_idx + 2

                -- Connect prev to next
                ib[iw + 0] = base_idx + 0; ib[iw + 1] = base_idx + 2; ib[iw + 2] = base_idx + 3
                ib[iw + 3] = base_idx + 0; ib[iw + 4] = base_idx + 3; ib[iw + 5] = base_idx + 1
                iw = iw + 6
                base_idx = next_base_idx
            end
        end
    end

    -- End cap
    if not closed then
        local p = points[points_count]
        p1x, p1y = p.x, p.y
        n1x, n1y = normals_x[points_count], normals_y[points_count]

        -- End cap
        local dir_x = n1y
        local dir_y = -n1x
        if bit32.band(flags, ImDrawFlags.CapSquare) ~= 0 then
            p1x = p1x + dir_x * thickness * 0.5
            p1y = p1y + dir_y * thickness * 0.5
        end

        if not use_aa_ends then
            WV(vb, vw + 0, p1x - n1x * thickness0, p1y - n1y * thickness0, u0, v0, col)
            WV(vb, vw + 1, p1x + n1x * thickness1, p1y + n1y * thickness1, u1, v1, col)
            vw = vw + 2; vtx_idx = vtx_idx + 2

            -- Connect
            ib[iw + 0] = base_idx + 0; ib[iw + 1] = base_idx + 2; ib[iw + 2] = base_idx + 3
            ib[iw + 3] = base_idx + 0; ib[iw + 4] = base_idx + 3; ib[iw + 5] = base_idx + 1
            iw = iw + 6
        else
            local pa_x = p1x - dir_x * half_aa
            local pa_y = p1y - dir_y * half_aa
            local pb_x = p1x + dir_x * half_aa
            local pb_y = p1y + dir_y * half_aa

            local next_base_idx = vtx_idx
            WV(vb, vw + 0, pa_x - n1x * thickness0, pa_y - n1y * thickness0, u0, v0, col)
            WV(vb, vw + 1, pa_x + n1x * thickness1, pa_y + n1y * thickness1, u1, v1, col)

            WV(vb, vw + 2, pb_x - n1x * thickness0, pb_y - n1y * thickness0, u0, v0, col_trans)
            WV(vb, vw + 3, pb_x + n1x * thickness1, pb_y + n1y * thickness1, u1, v1, col_trans)
            vw = vw + 4; vtx_idx = vtx_idx + 4

            -- Connect
            ib[iw + 0] = base_idx + 0; ib[iw + 1] = base_idx + 2; ib[iw + 2] = base_idx + 3
            ib[iw + 3] = base_idx + 0; ib[iw + 4] = base_idx + 3; ib[iw + 5] = base_idx + 1
            base_idx = next_base_idx

            -- AA cap
            ib[iw + 6] = base_idx + 0; ib[iw + 7] = base_idx + 2; ib[iw + 8] = base_idx + 3
            ib[iw + 9] = base_idx + 0; ib[iw + 10] = base_idx + 3; ib[iw + 11] = base_idx + 1
            iw = iw + 12
        end
    else
        -- Connect the path.
        -- [Luau] VtxBuffer.Data[first_vtx_offset + 0..1] = VtxBuffer.Data[_CmdHeader.VtxOffset + base_idx + 0..1] (2 vertices of 36 bytes)
        buffer.copy(vb, (first_vtx_offset - 1) * 36, vb, (first_vtx_offset + (base_idx - first_vtx_idx) - 1) * 36, 2 * 36)
    end

    self._VtxWritePtr = vw
    self._IdxWritePtr = iw
    self._VtxCurrentIdx = vtx_idx

    -- Restore unused memory
    local remaining_idx_count = self.IdxBuffer.Size - (iw - 1)
    local remaining_vtx_count = self.VtxBuffer.Size - (vw - 1)
    IM_ASSERT_PARANOID(remaining_idx_count >= 0 and remaining_vtx_count >= 0)
    if remaining_idx_count > 0 or remaining_vtx_count > 0 then -- [Luau] skip the call when nothing is left
        self:PrimUnreserve(remaining_idx_count, remaining_vtx_count)
    end
end

-- - We intentionally avoid using ImVec2 and its math operators here to reduce cost to a minimum for debug/non-inlined builds.
-- - Filled shapes must always use clockwise winding order. The anti-aliasing fringe depends on it. Counter-clockwise shapes will have "inward" anti-aliasing.
--- @param points       ImVec2[] # 1-based
--- @param points_count int
--- @param col          ImU32
--- @param flags?       ImDrawFlags
@native
function MT.ImDrawList:AddConvexPolyFilled(points, points_count, col, flags)
    if points_count < 3 or bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end
    if flags == nil then flags = 0 end

    local uv = self._Data.TexUvWhitePixel
    local uv_x, uv_y = uv.x, uv.y
    flags = bit32.bor(flags, self.Flags)
    if bit32.band(flags, ImDrawFlags.AAFill) ~= 0 then
        local half_aa = self._FringeScale * 0.5
        local col_trans = bit32.band(col, bit32.bnot(IM_COL32_A_MASK))
        local miters_only = bit32.band(flags, ImDrawFlags.JoinMiter) ~= 0
        local miter_distance_limit_sqr = IM_POLYLINE_MITER_LIMIT * IM_POLYLINE_MITER_LIMIT

        local idx_count = ((points_count - 2) + points_count * 2 + IM_POLYLINE_CONVEX_POLY_MAX_BEVELS) * 3
        local vtx_count = points_count * 2 + IM_POLYLINE_CONVEX_POLY_MAX_BEVELS
        PrimReserve(self, idx_count, vtx_count)
        local vb = self.VtxBuffer.Buf
        local ib = self.IdxBuffer.Data
        local start_vtx_ptr = self._VtxWritePtr
        local start_idx_ptr = self._IdxWritePtr
        local iw = start_idx_ptr

        -- Compute normals and segment lengths
        local temp_normals_x, temp_normals_y, temp_sqr_lengths = poly_normals_x, poly_normals_y, poly_sqr_lengths
        local i0 = points_count
        for i1 = 1, points_count do
            local p0 = points[i0]
            local p1 = points[i1]
            local dx = p1.x - p0.x
            local dy = p1.y - p0.y
            local d2 = dx * dx + dy * dy
            if d2 > 0.0 then
                local inv_len = 1.0 / math.sqrt(d2) -- [Port] ImRsqrtPrecise()
                dx = dx * inv_len
                dy = dy * inv_len
            end
            temp_normals_x[i0] = dy
            temp_normals_y[i0] = -dx
            temp_sqr_lengths[i0] = d2
            i0 = i1
        end

        local vtx_inner_idx = self._VtxCurrentIdx
        local inner_vtx_ptr = start_vtx_ptr
        local vw = start_vtx_ptr + points_count
        local vtx_idx = vtx_inner_idx + points_count

        local prev_outer_idx = 0 -- This should be the index of the last vertex, but we don't know it yet. Will need to patch once we're done.
        if miters_only then
            i0 = points_count
            for i1 = 1, points_count do
                local p1 = points[i1]
                local p1x, p1y = p1.x, p1.y
                local n0x, n0y = temp_normals_x[i0], temp_normals_y[i0]
                local n1x, n1y = temp_normals_x[i1], temp_normals_y[i1]

                -- theta is the angle between two segments
                local cos_theta = n0x * n1x + n0y * n1y
                -- miter offset formula is derived here: https://www.angusj.com/clipper2/Docs/Trigonometry.htm
                local cos_theta_clamped = (IM_POLYLINE_MITER_ANGLE_LIMIT >= cos_theta) and IM_POLYLINE_MITER_ANGLE_LIMIT or cos_theta -- Avoid div by 0.
                local miter_scale_factor = 1.0 / (1.0 + cos_theta_clamped)
                if miter_scale_factor > 1000.0 then miter_scale_factor = 1000.0 end
                local miter_offset_x = (n0x + n1x) * miter_scale_factor * half_aa
                local miter_offset_y = (n0y + n1y) * miter_scale_factor * half_aa

                -- Inner
                WV(vb, inner_vtx_ptr, p1x - miter_offset_x, p1y - miter_offset_y, uv_x, uv_y, col)
                inner_vtx_ptr = inner_vtx_ptr + 1

                local prev_inner_idx = vtx_inner_idx + (i0 - 1)
                local inner_idx = vtx_inner_idx + (i1 - 1)
                local outer_idx = vtx_idx

                -- Outer
                WV(vb, vw, p1x + miter_offset_x, p1y + miter_offset_y, uv_x, uv_y, col_trans)
                vw = vw + 1; vtx_idx = vtx_idx + 1
                -- Connect with previous
                ib[iw + 0] = prev_outer_idx; ib[iw + 1] = outer_idx; ib[iw + 2] = inner_idx
                ib[iw + 3] = prev_outer_idx; ib[iw + 4] = inner_idx; ib[iw + 5] = prev_inner_idx
                iw = iw + 6

                prev_outer_idx = outer_idx
                i0 = i1
            end
        else
            local bevel_count = 0
            i0 = points_count
            for i1 = 1, points_count do
                local p1 = points[i1]
                local p1x, p1y = p1.x, p1.y
                local n0x, n0y = temp_normals_x[i0], temp_normals_y[i0]
                local n1x, n1y = temp_normals_x[i1], temp_normals_y[i1]

                -- theta is the angle between two segments
                local cos_theta = n0x * n1x + n0y * n1y
                -- miter offset formula is derived here: https://www.angusj.com/clipper2/Docs/Trigonometry.htm
                local cos_theta_clamped = (IM_POLYLINE_MITER_ANGLE_LIMIT >= cos_theta) and IM_POLYLINE_MITER_ANGLE_LIMIT or cos_theta -- Avoid div by 0.
                local miter_scale_factor = 1.0 / (1.0 + cos_theta_clamped)
                if miter_scale_factor > 1000.0 then miter_scale_factor = 1000.0 end
                local miter_offset_x = (n0x + n1x) * miter_scale_factor
                local miter_offset_y = (n0y + n1y) * miter_scale_factor

                local miter_distance_sqr = miter_offset_x * miter_offset_x + miter_offset_y * miter_offset_y
                local bevel = miter_distance_sqr > miter_distance_limit_sqr
                if bevel then
                    -- Limit inner bevel so that it is does not shoot out outside the polygon.
                    -- (using ImMax is intentional: using min limited too much in Mikko's tests when you have short edge next to long one.
                    -- The idea of that check is to keep that worst case overshoot no bigger than the polygon)
                    local ref_thickness_sqr = half_aa * half_aa
                    local limit_sqr = ImMax(temp_sqr_lengths[i0], temp_sqr_lengths[i1])
                    local ref_miter_dist_sqr = miter_distance_sqr * ref_thickness_sqr
                    if ref_miter_dist_sqr > limit_sqr then
                        local scale = ImSqrt(limit_sqr / ref_miter_dist_sqr)
                        miter_offset_x = miter_offset_x * scale
                        miter_offset_y = miter_offset_y * scale
                    end
                end

                miter_offset_x = miter_offset_x * half_aa
                miter_offset_y = miter_offset_y * half_aa

                -- Inner
                WV(vb, inner_vtx_ptr, p1x - miter_offset_x, p1y - miter_offset_y, uv_x, uv_y, col)
                inner_vtx_ptr = inner_vtx_ptr + 1

                local prev_inner_idx = vtx_inner_idx + (i0 - 1)
                local inner_idx = vtx_inner_idx + (i1 - 1)
                local outer_idx = vtx_idx

                -- Outer
                if bevel and bevel_count < IM_POLYLINE_CONVEX_POLY_MAX_BEVELS then
                    -- Because the polygon is convex, we know the maximum number of bevel corners we can hit (which is very small number).
                    -- We keep track of them just in case the calculations disagree.
                    bevel_count = bevel_count + 1

                    WV(vb, vw + 0, p1x + n0x * half_aa, p1y + n0y * half_aa, uv_x, uv_y, col_trans)
                    WV(vb, vw + 1, p1x + n1x * half_aa, p1y + n1y * half_aa, uv_x, uv_y, col_trans)
                    vw = vw + 2; vtx_idx = vtx_idx + 2
                    -- Connect with previous
                    ib[iw + 0] = prev_outer_idx; ib[iw + 1] = outer_idx; ib[iw + 2] = inner_idx
                    ib[iw + 3] = prev_outer_idx; ib[iw + 4] = inner_idx; ib[iw + 5] = prev_inner_idx
                    -- Fill bevel
                    ib[iw + 6] = outer_idx; ib[iw + 7] = outer_idx + 1; ib[iw + 8] = inner_idx
                    iw = iw + 9
                    outer_idx = outer_idx + 1
                else
                    WV(vb, vw, p1x + miter_offset_x, p1y + miter_offset_y, uv_x, uv_y, col_trans)
                    vw = vw + 1; vtx_idx = vtx_idx + 1
                    -- Connect with previous
                    ib[iw + 0] = prev_outer_idx; ib[iw + 1] = outer_idx; ib[iw + 2] = inner_idx
                    ib[iw + 3] = prev_outer_idx; ib[iw + 4] = inner_idx; ib[iw + 5] = prev_inner_idx
                    iw = iw + 6
                end

                prev_outer_idx = outer_idx
                i0 = i1
            end
        end

        -- Patch first segment to wrap around
        ib[start_idx_ptr + 0] = prev_outer_idx
        ib[start_idx_ptr + 3] = prev_outer_idx

        -- Add indices for fill
        for i = 2, points_count - 1 do
            ib[iw + 0] = vtx_inner_idx; ib[iw + 1] = vtx_inner_idx + i - 1; ib[iw + 2] = vtx_inner_idx + i
            iw = iw + 3
        end

        self._VtxWritePtr = vw
        self._IdxWritePtr = iw
        self._VtxCurrentIdx = vtx_idx

        local idx_used = iw - start_idx_ptr
        local vtx_used = vw - start_vtx_ptr
        IM_ASSERT(idx_used <= idx_count and vtx_used <= vtx_count)
        if idx_used < idx_count or vtx_used < vtx_count then
            self:PrimUnreserve(idx_count - idx_used, vtx_count - vtx_used)
        end
    else
        -- Non Anti-aliased Fill
        local idx_count = (points_count - 2) * 3
        local vtx_count = points_count
        PrimReserve(self, idx_count, vtx_count)
        local vb = self.VtxBuffer.Buf
        local ib = self.IdxBuffer.Data
        local vw = self._VtxWritePtr
        local iw = self._IdxWritePtr
        local base_idx = self._VtxCurrentIdx
        for i = 1, vtx_count do
            local p = points[i]
            WV(vb, vw, p.x, p.y, uv_x, uv_y, col)
            vw = vw + 1
        end
        for i = 2, points_count - 1 do
            ib[iw + 0] = base_idx; ib[iw + 1] = base_idx + i - 1; ib[iw + 2] = base_idx + i
            iw = iw + 3
        end
        self._VtxWritePtr = vw
        self._IdxWritePtr = iw
        self._VtxCurrentIdx = base_idx + vtx_count
    end
end

-- [Luau] scalar PathLineTo(): no temporary ImVec2 (the path slot is written in place)
local function PathLineToXY(self, x, y)
    local path = self._Path
    local n = path.Size + 1
    if n > path.Capacity then path:push_back(ImVec2(x, y)) return end
    local dest = path.Data[n]
    dest.x = x; dest.y = y
    path.Size = n
end

local _PathArcToFastExXY -- [Luau] forward declaration, defined below with _PathArcToFastEx()

-- [Luau] scalar PathRect (a = ax,ay; b = bx,by); PathRect() below wraps it
local function PathRectXY(self, ax, ay, bx, by, rounding, flags)
    if not rounding then rounding = 0.0 end
    if not flags    then flags    = 0   end

    local has_rounding = rounding >= 0.25 * self._FringeScale -- [Port] IM_HAS_ROUNDING(rounding)
    if has_rounding then
        if bit32.band(flags, ImDrawFlags.RoundMask_) == 0 then
            flags = bit32.bor(flags, ImDrawFlags.RoundAll)
        end

        rounding = ImMin(rounding, ImAbs(bx - ax) * (((bit32.band(flags, ImDrawFlags.RoundTop) == ImDrawFlags.RoundTop) or (bit32.band(flags, ImDrawFlags.RoundBottom) == ImDrawFlags.RoundBottom)) and 0.5 or 1.0) - 1.0)
        rounding = ImMin(rounding, ImAbs(by - ay) * (((bit32.band(flags, ImDrawFlags.RoundLeft) == ImDrawFlags.RoundLeft) or (bit32.band(flags, ImDrawFlags.RoundRight) == ImDrawFlags.RoundRight)) and 0.5 or 1.0) - 1.0)
    end
    if not has_rounding or (bit32.band(flags, ImDrawFlags.RoundMask_) == ImDrawFlags.RoundNone) then
        PathLineToXY(self, ax, ay)
        PathLineToXY(self, bx, ay)
        PathLineToXY(self, bx, by)
        PathLineToXY(self, ax, by)
    else
        local rounding_tl = (bit32.band(flags, ImDrawFlags.RoundTopLeft) ~= 0) and rounding or 0.0
        local rounding_tr = (bit32.band(flags, ImDrawFlags.RoundTopRight) ~= 0) and rounding or 0.0
        local rounding_br = (bit32.band(flags, ImDrawFlags.RoundBottomRight) ~= 0) and rounding or 0.0
        local rounding_bl = (bit32.band(flags, ImDrawFlags.RoundBottomLeft) ~= 0) and rounding or 0.0
        -- [Luau] inline PathArcToFast() (small radius handled by _PathArcToFastExXY())
        _PathArcToFastExXY(self, ax + rounding_tl, ay + rounding_tl, rounding_tl, 6 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 9 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 0)
        _PathArcToFastExXY(self, bx - rounding_tr, ay + rounding_tr, rounding_tr, 9 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 12 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 0)
        _PathArcToFastExXY(self, bx - rounding_br, by - rounding_br, rounding_br, 0 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 3 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 0)
        _PathArcToFastExXY(self, ax + rounding_bl, by - rounding_bl, rounding_bl, 3 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 6 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 0)
    end
end

function MT.ImDrawList:PathRect(a, b, rounding, flags)
    PathRectXY(self, a.x, a.y, b.x, b.y, rounding, flags)
end

-- [Luau] scalar _AddLine (p1 = p1x,p1y; p2 = p2x,p2y); _AddLine() below wraps it
@native
local function _AddLineXY(self, p1x, p1y, p2x, p2y, col, thickness, flags)
    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local screen_thickness = thickness * self._InvFringeScale
    if screen_thickness < 1.0 then
        if screen_thickness < 1.0 / 255.0 then
            return
        end
        col = ImAlphaMultiply(col, screen_thickness)
        screen_thickness = 1.0
        thickness = self._FringeScale
    end

    flags = bit32.bor(flags, self.Flags)
    local u0, v0, u1, v1, fringe = _SelectLineTexture(self, screen_thickness, flags)

    local dir_x = p2x - p1x
    local dir_y = p2y - p1y
    local d2 = dir_x * dir_x + dir_y * dir_y
    local inv_len = 0.0
    if d2 > 0.0 then inv_len = 1.0 / math.sqrt(d2) end -- [Port] ImRsqrtPrecise()
    dir_x = dir_x * inv_len
    dir_y = dir_y * inv_len
    local norm_x = -dir_y
    local norm_y = dir_x

    local col_trans = bit32.band(col, bit32.bnot(IM_COL32_A_MASK))

    local stroke_pos = _GetStrokePos(flags, ImDrawFlags.StrokeCenter)
    if stroke_pos == ImDrawFlags.StrokeLegacy then
        flags = bit32.band(bit32.bor(flags, ImDrawFlags.JoinMiter), bit32.bnot(ImDrawFlags.AALineEnds))
    end

    local thickness0 = (thickness + fringe) * 0.5 -- Center (or legacy)
    if stroke_pos == ImDrawFlags.StrokeOutside then
        thickness0 = thickness + fringe * 0.5
    elseif stroke_pos == ImDrawFlags.StrokeCenterBiased then
        thickness0 = _CalculateCenterBiasedOffset(self, thickness) + fringe * 0.5
    elseif stroke_pos == ImDrawFlags.StrokeInside then
        thickness0 = fringe * 0.5
    end
    local thickness1 = (thickness + fringe) - thickness0

    -- [Luau] uv2 (ratio) is unused by _AddLine(): not computed

    local half_aa = self._FringeScale * 0.5 -- Used for end caps, does not use "fringe" since end cap AA is not using the texture.
    local use_aa_ends = bit32.band(flags, bit32.bor(ImDrawFlags.AALines, ImDrawFlags.AALineEnds)) == bit32.bor(ImDrawFlags.AALines, ImDrawFlags.AALineEnds)

    if not use_aa_ends then
        PrimReserve(self, 2 * 3, 4)
    else
        PrimReserve(self, 6 * 3, 8)
    end

    local vb = self.VtxBuffer.Buf
    local ib = self.IdxBuffer.Data
    local vw = self._VtxWritePtr
    local iw = self._IdxWritePtr
    local base_idx = self._VtxCurrentIdx

    if bit32.band(flags, ImDrawFlags.CapSquare) ~= 0 then
        local half_thickness = thickness * 0.5
        p1x = p1x - dir_x * half_thickness
        p1y = p1y - dir_y * half_thickness
        p2x = p2x + dir_x * half_thickness
        p2y = p2y + dir_y * half_thickness
    end

    -- Start cap
    if not use_aa_ends then
        WV(vb, vw + 0, p1x - norm_x * thickness0, p1y - norm_y * thickness0, u0, v0, col)
        WV(vb, vw + 1, p1x + norm_x * thickness1, p1y + norm_y * thickness1, u1, v1, col)
        WV(vb, vw + 2, p2x - norm_x * thickness0, p2y - norm_y * thickness0, u0, v0, col)
        WV(vb, vw + 3, p2x + norm_x * thickness1, p2y + norm_y * thickness1, u1, v1, col)

        -- Connect
        ib[iw + 0] = base_idx + 0; ib[iw + 1] = base_idx + 2; ib[iw + 2] = base_idx + 3
        ib[iw + 3] = base_idx + 0; ib[iw + 4] = base_idx + 3; ib[iw + 5] = base_idx + 1
        self._VtxWritePtr = vw + 4
        self._IdxWritePtr = iw + 6
        self._VtxCurrentIdx = base_idx + 4
    else
        -- Start
        local pa_x = p1x - dir_x * half_aa
        local pa_y = p1y - dir_y * half_aa
        local pb_x = p1x + dir_x * half_aa
        local pb_y = p1y + dir_y * half_aa

        WV(vb, vw + 0, pa_x - norm_x * thickness0, pa_y - norm_y * thickness0, u0, v0, col_trans)
        WV(vb, vw + 1, pa_x + norm_x * thickness1, pa_y + norm_y * thickness1, u1, v1, col_trans)

        WV(vb, vw + 2, pb_x - norm_x * thickness0, pb_y - norm_y * thickness0, u0, v0, col)
        WV(vb, vw + 3, pb_x + norm_x * thickness1, pb_y + norm_y * thickness1, u1, v1, col)

        -- AA cap
        ib[iw + 0] = base_idx + 0; ib[iw + 1] = base_idx + 2; ib[iw + 2] = base_idx + 3
        ib[iw + 3] = base_idx + 0; ib[iw + 4] = base_idx + 3; ib[iw + 5] = base_idx + 1
        base_idx = base_idx + 2

        -- End
        pa_x = p2x - dir_x * half_aa
        pa_y = p2y - dir_y * half_aa
        pb_x = p2x + dir_x * half_aa
        pb_y = p2y + dir_y * half_aa

        WV(vb, vw + 4, pa_x - norm_x * thickness0, pa_y - norm_y * thickness0, u0, v0, col)
        WV(vb, vw + 5, pa_x + norm_x * thickness1, pa_y + norm_y * thickness1, u1, v1, col)
        WV(vb, vw + 6, pb_x - norm_x * thickness0, pb_y - norm_y * thickness0, u0, v0, col_trans)
        WV(vb, vw + 7, pb_x + norm_x * thickness1, pb_y + norm_y * thickness1, u1, v1, col_trans)

        -- Connect
        ib[iw + 6] = base_idx + 0; ib[iw + 7] = base_idx + 2; ib[iw + 8] = base_idx + 3
        ib[iw + 9] = base_idx + 0; ib[iw + 10] = base_idx + 3; ib[iw + 11] = base_idx + 1
        base_idx = base_idx + 2

        -- AA cap
        ib[iw + 12] = base_idx + 0; ib[iw + 13] = base_idx + 2; ib[iw + 14] = base_idx + 3
        ib[iw + 15] = base_idx + 0; ib[iw + 16] = base_idx + 3; ib[iw + 17] = base_idx + 1
        self._VtxWritePtr = vw + 8
        self._IdxWritePtr = iw + 18
        self._VtxCurrentIdx = base_idx + 4
    end
end

function MT.ImDrawList:_AddLine(p1, p2, col, thickness, flags)
    _AddLineXY(self, p1.x, p1.y, p2.x, p2.y, col, thickness, flags)
end

--- @param p1         ImVec2
--- @param p2         ImVec2
--- @param col        ImU32
--- @param thickness? float
--- @param flags?     ImDrawFlags
function MT.ImDrawList:AddLine(p1, p2, col, thickness, flags)
    if thickness == nil then thickness = 1.0 end
    if flags     == nil then flags     = 0   end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    flags = bit32.bor(flags, self.Flags)
    local stroke_pos = _GetStrokePos(flags, ImDrawFlags.StrokeCenter)
    if stroke_pos == ImDrawFlags.StrokeLegacy then
        _AddLineXY(self, p1.x + 0.5, p1.y + 0.5, p2.x + 0.5, p2.y + 0.5, col, thickness, flags)
        return
    end

    _AddLineXY(self, p1.x, p1.y, p2.x, p2.y, col, thickness, flags)
end

-- AddLineH(10, 20, 5, col, 1.0f) == AddLine( {10,5.5}, {20,5.5}, col, 1.0f)
--                                == AddLine( {10,5}, {20,5}, col, 1.0f, ImDrawFlags_StrokeLegacy); // or before 1.93.0
-- Thickness extend inside/bottom by default. Faster than equivalent AddLine() call.
--- @param min_x      float
--- @param max_x      float
--- @param y          float
--- @param col        ImU32
--- @param thickness? float
--- @param flags?     ImDrawFlags
@native
function MT.ImDrawList:AddLineH(min_x, max_x, y, col, thickness, flags)
    if thickness == nil then thickness = 1.0 end
    if flags     == nil then flags     = 0   end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    flags = bit32.bor(flags, self.Flags)
    local stroke_pos = _GetStrokePos(flags, ImDrawFlags.StrokeInside)
    if stroke_pos == ImDrawFlags.StrokeLegacy then
        _AddLineXY(self, min_x + 0.5, y + 0.5, max_x + 0.5, y + 0.5, col, thickness, flags)
        return
    end

    local top_y = y -- Inside
    if stroke_pos == ImDrawFlags.StrokeCenter then
        top_y = top_y - thickness * 0.5
    elseif stroke_pos == ImDrawFlags.StrokeCenterBiased then
        top_y = top_y - _CalculateCenterBiasedOffset(self, thickness)
    elseif stroke_pos == ImDrawFlags.StrokeOutside then
        top_y = top_y - thickness
    end

    local is_truncated = min_x % 1 == 0 and max_x % 1 == 0 and top_y % 1 == 0 and thickness % 1 == 0 -- [Port] IM_IS_TRUNCATED4()
    if self._FringeScaleIsInteger and is_truncated and bit32.band(flags, ImDrawFlags.CapSquare) == 0 then
        if thickness < self._FringeScale then
            if thickness < (1.0 / 255.0) * self._FringeScale then
                return
            end
            col = ImAlphaMultiply(col, thickness * self._InvFringeScale)
            thickness = self._FringeScale
        end

        -- For pixel aligned case, use simple rectangle.
        PrimReserve(self, 6, 4)
        PrimRectXY(self, min_x, top_y, max_x, top_y + thickness, col)
    else
        -- Replace stroke pos with the already calculated one, as AddPolyline() default is different.
        flags = bit32.bor(bit32.band(flags, bit32.bnot(ImDrawFlags.StrokeMask_)), stroke_pos)

        -- For generic case use line, since it needs less triangles than AA rectangle.
        _AddLineXY(self, min_x, y, max_x, y, col, thickness, flags)
    end
end

-- AddLineV(5, 10, 20, col, 1.0f) == AddLine( {5.5,10}, {5.5,20}, col, 1.0f)
--                                == AddLine( {5,10}, {5,20}, col, 1.0f, ImDrawFlags_StrokeLegacy); // or before 1.93.0
-- Thickness extend inside/right by default. Faster than equivalent AddLine() call.
--- @param x          float
--- @param min_y      float
--- @param max_y      float
--- @param col        ImU32
--- @param thickness? float
--- @param flags?     ImDrawFlags
@native
function MT.ImDrawList:AddLineV(x, min_y, max_y, col, thickness, flags)
    if thickness == nil then thickness = 1.0 end
    if flags     == nil then flags     = 0   end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    flags = bit32.bor(flags, self.Flags)
    local stroke_pos = _GetStrokePos(flags, ImDrawFlags.StrokeInside)
    if stroke_pos == ImDrawFlags.StrokeLegacy then
        _AddLineXY(self, x + 0.5, min_y + 0.5, x + 0.5, max_y + 0.5, col, thickness, flags)
        return
    end

    local left_x = x -- Inside
    if stroke_pos == ImDrawFlags.StrokeCenter then
        left_x = left_x - thickness * 0.5
    elseif stroke_pos == ImDrawFlags.StrokeCenterBiased then
        left_x = left_x - _CalculateCenterBiasedOffset(self, thickness)
    elseif stroke_pos == ImDrawFlags.StrokeOutside then
        left_x = left_x - thickness
    end

    local is_truncated = left_x % 1 == 0 and min_y % 1 == 0 and max_y % 1 == 0 and thickness % 1 == 0 -- [Port] IM_IS_TRUNCATED4()
    if self._FringeScaleIsInteger and is_truncated and bit32.band(flags, ImDrawFlags.CapSquare) == 0 then
        if thickness < self._FringeScale then
            if thickness < (1.0 / 255.0) * self._FringeScale then
                return
            end
            col = ImAlphaMultiply(col, thickness * self._InvFringeScale)
            thickness = self._FringeScale
        end

        -- For pixel aligned case, use simple rectangle.
        PrimReserve(self, 6, 4)
        PrimRectXY(self, left_x, min_y, left_x + thickness, max_y, col)
    else
        -- Replace stroke pos with the already calculated one, as AddPolyline() default is different.
        flags = bit32.bor(bit32.band(flags, bit32.bnot(ImDrawFlags.StrokeMask_)), stroke_pos)

        -- For generic case use line, since it needs less triangles than AA rectangle.
        -- Drawing for bottom to top, so that the inside stroke pos expands to right.
        _AddLineXY(self, x, max_y, x, min_y, col, thickness, flags)
    end
end

-- [Luau] IM_APPEND_VTX() x4 + IM_APPEND_TRI(idx + 0, idx + 1, idx + 2) + IM_APPEND_TRI(idx + 0, idx + 2, idx + 3)
local function AppendQuadUV(self, x0, y0, u0, v0, x1, y1, u1, v1, x2, y2, u2, v2, x3, y3, u3, v3, col)
    local vb = self.VtxBuffer.Buf
    local ib = self.IdxBuffer.Data
    local vw = self._VtxWritePtr
    local iw = self._IdxWritePtr
    local idx = self._VtxCurrentIdx
    WV(vb, vw + 0, x0, y0, u0, v0, col)
    WV(vb, vw + 1, x1, y1, u1, v1, col)
    WV(vb, vw + 2, x2, y2, u2, v2, col)
    WV(vb, vw + 3, x3, y3, u3, v3, col)
    ib[iw + 0] = idx + 0; ib[iw + 1] = idx + 1; ib[iw + 2] = idx + 2
    ib[iw + 3] = idx + 0; ib[iw + 4] = idx + 2; ib[iw + 5] = idx + 3
    self._VtxWritePtr = vw + 4
    self._IdxWritePtr = iw + 6
    self._VtxCurrentIdx = idx + 4
end

-- [Luau] _AddRectBaked() taking p_min/p_max as scalars
@native
local function _AddRectBakedXY(self, p_min_x, p_min_y, p_max_x, p_max_y, col, r, t, tex_uvs, flags)
    local uv_l, uv_t, uv_r, uv_b = tex_uvs.x, tex_uvs.y, tex_uvs.z, tex_uvs.w -- [Port] uv_tl = (l,t), uv_tr = (r,t), uv_br = (r,b), uv_bl = (l,b)

    local idx_allocated = 8 * 2 * 3
    local vtx_allocated = 8 * 4
    PrimReserve(self, idx_allocated, vtx_allocated)
    local start_vtx_ptr = self._VtxWritePtr
    local start_idx_ptr = self._IdxWritePtr

    local round_tl = bit32.band(flags, ImDrawFlags.RoundTopLeft) ~= 0
    local round_tr = bit32.band(flags, ImDrawFlags.RoundTopRight) ~= 0
    local round_br = bit32.band(flags, ImDrawFlags.RoundBottomRight) ~= 0
    local round_bl = bit32.band(flags, ImDrawFlags.RoundBottomLeft) ~= 0

    if round_tl then
        AppendQuadUV(self,
            p_min_x, p_min_y, uv_l, uv_t,
            p_min_x + r, p_min_y, uv_r, uv_t,
            p_min_x + r, p_min_y + r, uv_r, uv_b,
            p_min_x, p_min_y + r, uv_l, uv_b, col)
    end

    if round_tr then
        AppendQuadUV(self,
            p_max_x - r, p_min_y, uv_r, uv_t,
            p_max_x, p_min_y, uv_l, uv_t,
            p_max_x, p_min_y + r, uv_l, uv_b,
            p_max_x - r, p_min_y + r, uv_r, uv_b, col)
    end

    if round_br then
        AppendQuadUV(self,
            p_max_x - r, p_max_y - r, uv_r, uv_b,
            p_max_x, p_max_y - r, uv_l, uv_b,
            p_max_x, p_max_y, uv_l, uv_t,
            p_max_x - r, p_max_y, uv_r, uv_t, col)
    end

    if round_bl then
        AppendQuadUV(self,
            p_min_x, p_max_y - r, uv_l, uv_b,
            p_min_x + r, p_max_y - r, uv_r, uv_b,
            p_min_x + r, p_max_y, uv_r, uv_t,
            p_min_x, p_max_y, uv_l, uv_t, col)
    end

    local r_tl = round_tl and r or 0
    local r_tr = round_tr and r or 0
    local r_br = round_br and r or 0
    local r_bl = round_bl and r or 0
    local opaque_uv = self._Data.TexUvWhitePixel
    local ou, ov = opaque_uv.x, opaque_uv.y

    do
        -- Top
        local x0 = p_min_x + r_tl
        local x1 = p_max_x - r_tr
        AppendQuadUV(self, x0, p_min_y, ou, ov, x1, p_min_y, ou, ov, x1, p_min_y + t, ou, ov, x0, p_min_y + t, ou, ov, col)
    end
    do
        -- Left
        local y0 = p_min_y + ImMax(r_tl, t)
        local y1 = p_max_y - ImMax(r_bl, t)
        AppendQuadUV(self, p_min_x, y0, ou, ov, p_min_x + t, y0, ou, ov, p_min_x + t, y1, ou, ov, p_min_x, y1, ou, ov, col)
    end
    do
        -- Right
        local y0 = p_min_y + ImMax(r_tr, t)
        local y1 = p_max_y - ImMax(r_br, t)
        AppendQuadUV(self, p_max_x - t, y0, ou, ov, p_max_x, y0, ou, ov, p_max_x, y1, ou, ov, p_max_x - t, y1, ou, ov, col)
    end
    do
        -- Bottom
        local x0 = p_min_x + r_bl
        local x1 = p_max_x - r_br
        AppendQuadUV(self, x0, p_max_y - t, ou, ov, x1, p_max_y - t, ou, ov, x1, p_max_y, ou, ov, x0, p_max_y, ou, ov, col)
    end

    local idx_used = self._IdxWritePtr - start_idx_ptr
    local vtx_used = self._VtxWritePtr - start_vtx_ptr
    IM_ASSERT_PARANOID(idx_used <= idx_allocated and vtx_used <= vtx_allocated)
    if idx_used < idx_allocated or vtx_used < vtx_allocated then
        self:PrimUnreserve(idx_allocated - idx_used, vtx_allocated - vtx_used)
    end
end

--- @param p_min   ImVec2
--- @param p_max   ImVec2
--- @param col     ImU32
--- @param r       float
--- @param t       float
--- @param tex_uvs ImVec4
--- @param flags   ImDrawFlags
function MT.ImDrawList:_AddRectBaked(p_min, p_max, col, r, t, tex_uvs, flags)
    _AddRectBakedXY(self, p_min.x, p_min.y, p_max.x, p_max.y, col, r, t, tex_uvs, flags)
end

local corner_offset_x = { 1, -1, -1,  1 } -- [Port] static const ImVec2 corner_offset[4] = { {1,1}, {-1,1}, {-1,-1}, {1,-1} };
local corner_offset_y = { 1,  1, -1, -1 }
local corner_flags = { ImDrawFlags.RoundTopLeft, ImDrawFlags.RoundTopRight, ImDrawFlags.RoundBottomRight, ImDrawFlags.RoundBottomLeft }
local corner_pos_x, corner_pos_y = { 0, 0, 0, 0 }, { 0, 0, 0, 0 } -- [Luau] scratch

-- Draws rounded rectangle where thickness > rounding. If rendered using the regular polyline, the stroke will fold and leave artifacts on the corners if rendered with transparency.
-- The stroke is positioned inside the rectangle.
--- @param p_min     ImVec2
--- @param p_max     ImVec2
--- @param col       ImU32
--- @param rounding  float
--- @param thickness float
--- @param flags     ImDrawFlags
function MT.ImDrawList:_AddRectTinyRounding(p_min, p_max, col, rounding, thickness, flags)
    local screen_thickness = thickness * self._InvFringeScale
    if screen_thickness < 1.0 then
        if screen_thickness < 1.0 / 255.0 then
            return
        end
        col = ImAlphaMultiply(col, screen_thickness)
        screen_thickness = 1.0
        thickness = self._FringeScale
    end

    flags = bit32.bor(flags, self.Flags)
    local outer_u, outer_v, inner_u, inner_v, fringe = _SelectLineTexture(self, screen_thickness, flags)

    local auto_seg_count = self:_CalcCircleAutoSegmentCount(rounding)
    local arc_step, arc_step_count = CalcCornerArcStepAndCount(auto_seg_count)
    local arc_point_count = arc_step_count + 1

    local vtx_count = (2 + arc_point_count) * 4 + 3
    local idx_count = (4 + arc_point_count - 1) * 4 * 3

    PrimReserve(self, idx_count, vtx_count)
    local vb = self.VtxBuffer.Buf
    local ib = self.IdxBuffer.Data
    local start_vtx_ptr = self._VtxWritePtr
    local start_idx_ptr = self._IdxWritePtr
    local vw, iw = start_vtx_ptr, start_idx_ptr
    local vtx_idx = self._VtxCurrentIdx
    local first_vtx_idx = vtx_idx -- [Luau] VtxBuffer position of index 'n' is start_vtx_ptr + (n - first_vtx_idx)

    local half_fringe = fringe * 0.5
    corner_pos_x[1] = p_min.x - half_fringe; corner_pos_y[1] = p_min.y - half_fringe
    corner_pos_x[2] = p_max.x + half_fringe; corner_pos_y[2] = p_min.y - half_fringe
    corner_pos_x[3] = p_max.x + half_fringe; corner_pos_y[3] = p_max.y + half_fringe
    corner_pos_x[4] = p_min.x - half_fringe; corner_pos_y[4] = p_max.y + half_fringe
    thickness = thickness + fringe
    rounding = rounding + half_fringe

    local stem_offset = ImMin(rounding, thickness) -- The function might get called with rounding slightly bigger than thickness, which is ok, but we should keep the stem inside the shape.
    local ratio = stem_offset / thickness
    local stem_u, stem_v = outer_u + (inner_u - outer_u) * ratio, outer_v

    -- Previous vertices, copied from the last vertices.
    local base_idx = vtx_idx
    WV(vb, vw + 0, 0, 0, inner_u, inner_v, col)
    WV(vb, vw + 1, 0, 0, stem_u, stem_v, col)
    WV(vb, vw + 2, 0, 0, outer_u, outer_v, col)
    vw = vw + 3; vtx_idx = vtx_idx + 3

    local arc_fast_vtx = self._Data.ArcFastVtx -- 1-based
    for corner = 1, 4 do
        local outer_x = corner_pos_x[corner]
        local outer_y = corner_pos_y[corner]
        local cox, coy = corner_offset_x[corner], corner_offset_y[corner]
        local stem_x = outer_x + cox * stem_offset
        local stem_y = outer_y + coy * stem_offset
        local inner_x = outer_x + cox * thickness
        local inner_y = outer_y + coy * thickness
        local is_rounded = bit32.band(flags, corner_flags[corner]) ~= 0

        local arc_idx = vtx_idx
        if is_rounded then
            local center_x = outer_x + cox * rounding
            local center_y = outer_y + coy * rounding
            local a = (IM_DRAWLIST_ARCFAST_TABLE_SIZE / 4) * (corner - 1)
            for _ = 0, arc_point_count - 1 do
                local s = arc_fast_vtx[a + 1]
                WV(vb, vw, center_x - s.x * rounding, center_y - s.y * rounding, outer_u, outer_v, col)
                vw = vw + 1; vtx_idx = vtx_idx + 1
                a = (a + arc_step) % IM_DRAWLIST_ARCFAST_TABLE_SIZE
            end
        else
            WV(vb, vw, outer_x, outer_y, outer_u, outer_v, col)
            vw = vw + 1; vtx_idx = vtx_idx + 1
        end

        local stem_idx = vtx_idx
        WV(vb, vw, stem_x, stem_y, stem_u, stem_v, col)
        local inner_idx = vtx_idx + 1
        WV(vb, vw + 1, inner_x, inner_y, inner_u, inner_v, col)
        vw = vw + 2; vtx_idx = vtx_idx + 2

        -- Arc
        if is_rounded then
            for i = 0, arc_point_count - 2 do
                ib[iw + 0] = stem_idx; ib[iw + 1] = arc_idx + i; ib[iw + 2] = arc_idx + i + 1
                iw = iw + 3
            end
        end

        -- Connect with previous
        ib[iw + 0] = base_idx + 0; ib[iw + 1] = arc_idx; ib[iw + 2] = stem_idx
        ib[iw + 3] = base_idx + 0; ib[iw + 4] = stem_idx; ib[iw + 5] = base_idx + 1
        ib[iw + 6] = base_idx + 1; ib[iw + 7] = stem_idx; ib[iw + 8] = inner_idx
        ib[iw + 9] = base_idx + 1; ib[iw + 10] = inner_idx; ib[iw + 11] = base_idx + 2
        iw = iw + 12

        base_idx = stem_idx - 1
    end

    -- Close
    -- [Luau] start_vtx_ptr[0..2] = VtxBuffer.Data[_CmdHeader.VtxOffset + base_idx + 0..2] (3 vertices of 36 bytes)
    buffer.copy(vb, (start_vtx_ptr - 1) * 36, vb, (start_vtx_ptr + (base_idx - first_vtx_idx) - 1) * 36, 3 * 36)

    self._VtxWritePtr = vw
    self._IdxWritePtr = iw
    self._VtxCurrentIdx = vtx_idx

    local idx_used = iw - start_idx_ptr
    local vtx_used = vw - start_vtx_ptr
    IM_ASSERT_PARANOID(idx_used <= idx_count and vtx_used <= vtx_count)
    if idx_used < idx_count or vtx_used < vtx_count then
        self:PrimUnreserve(idx_count - idx_used, vtx_count - vtx_used)
    end
end

local prim_points = { ImVec2(), ImVec2(), ImVec2(), ImVec2() } -- [Luau] scratch for C++ 'const ImVec2 points[N]' locals (callees only read them)

-- p_min = upper-left, p_max = lower-right
--- @param p_min      ImVec2
--- @param p_max      ImVec2
--- @param col        ImU32
--- @param rounding?  float
--- @param thickness? float
--- @param flags?     ImDrawFlags
@native
function MT.ImDrawList:AddRect(p_min, p_max, col, rounding, thickness, flags)
    if rounding  == nil then rounding  = 0.0 end
    if thickness == nil then thickness = 1.0 end
    if flags     == nil then flags     = 0   end

    -- If this assert triggers on legacy code:
    -- - 1.92.8 (2025/05): swapped two last parameters order: flags, thickness --> thickness, flags. This should normally be caught by compile-time type-checking.
    -- - 1.92.8 (2025/05): changed value of ImDrawList_Closed which was previously guaranteed to be == 1. Hardcoded use of 1 or true should be replaced.
    -- - 1.82.0 (2021/03): changed ImDrawCornerFlags to ImDrawFlags_RoundXXX values.
    --   If you used hard-coded 1 to 15 or ~0 in flags to configure corner rounding use the new flags!
    --   - Hard coded support for ~0 == ImDrawFlags_RoundAll.
    --   - Hard coded support for values 0x01 to 0x0F (matching 15 out of 16 old flags combinations) --> see FixRectCornerFlags() in <1.90 code.
    --   - Hard coded 0x00 with 'float rounding > 0.0f' --> replace with ImDrawFlags_RoundNone or use 'float rounding = 0.0f'.
    --   See "API BREAKING CHANGES" section for 1.82, 1.90 and 1.92.8.
    IM_ASSERT_USER_ERROR_RET(bit32.band(flags, ImDrawFlags.InvalidMask_) == 0, "Incorrect parameter. Did you swap 'thickness' and 'flags'?") -- Or misuse of legacy hard-coded ImDrawCornerFlags values

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    -- [Port] reversed corners (min > max, e.g. a box selection dragged up/left): upstream's min_dim checks drop them, older ImGui drew them
    if p_min.x > p_max.x or p_min.y > p_max.y then
        p_min, p_max = ImVec2(ImMin(p_min.x, p_max.x), ImMin(p_min.y, p_max.y)), ImVec2(ImMax(p_min.x, p_max.x), ImMax(p_min.y, p_max.y))
    end
    flags = bit32.bor(flags, self.Flags)
    local stroke_pos = _GetStrokePos(flags, ImDrawFlags.StrokeInside)
    if stroke_pos == ImDrawFlags.StrokeLegacy then
        if bit32.band(flags, ImDrawFlags.AALines) ~= 0 then
            PathRectXY(self, p_min.x + 0.50, p_min.y + 0.50, p_max.x - 0.50, p_max.y - 0.50, rounding, flags) -- [Luau] scalar math, no temporary ImVec2
        else
            PathRectXY(self, p_min.x + 0.50, p_min.y + 0.50, p_max.x - 0.49, p_max.y - 0.49, rounding, flags) -- Better looking lower-right corner and rounded non-AA shapes.
        end
        self:PathStroke(col, thickness, bit32.bor(ImDrawFlags.Closed, ImDrawFlags.JoinMiter, ImDrawFlags.StrokeCenter, bit32.band(flags, bit32.bnot(ImDrawFlags.StrokeMask_))))
        return
    end

    local fringe_scale = self._FringeScale
    local has_rounding = rounding >= 0.25 * fringe_scale -- [Port] IM_HAS_ROUNDING(rounding)

    -- Calculate the outer boundary of the rectangle based on the stroke position.
    local offset = 0.0 -- Inside
    if stroke_pos == ImDrawFlags.StrokeCenter then
        offset = thickness * 0.5
    elseif stroke_pos == ImDrawFlags.StrokeCenterBiased then
        offset = _CalculateCenterBiasedOffset(self, thickness)
    elseif stroke_pos == ImDrawFlags.StrokeOutside then
        offset = thickness
    end
    local outer_min_x = p_min.x - offset
    local outer_min_y = p_min.y - offset
    local outer_max_x = p_max.x + offset
    local outer_max_y = p_max.y + offset
    local outer_rounding = rounding + (has_rounding and offset or 0.0)

    local width = outer_max_x - outer_min_x
    local height = outer_max_y - outer_min_y
    local half_min_dim = ImMin(width, height) * 0.5
    if half_min_dim <= thickness then
        -- Rectangle has collapsed into filled rectangle.
        self:AddRectFilled(ImVec2(outer_min_x, outer_min_y), ImVec2(outer_max_x, outer_max_y), col, outer_rounding, flags)
        return
    end

    if bit32.band(flags, ImDrawFlags.RoundMask_) == 0 then
        flags = bit32.bor(flags, ImDrawFlags.RoundAll)
    end
    if has_rounding then
        -- Constrain rounding to rect dimensions
        outer_rounding = ImMin(outer_rounding, ImAbs(width) * (((bit32.band(flags, ImDrawFlags.RoundTop) == ImDrawFlags.RoundTop) or (bit32.band(flags, ImDrawFlags.RoundBottom) == ImDrawFlags.RoundBottom)) and 0.5 or 1.0) - 1.0)
        outer_rounding = ImMin(outer_rounding, ImAbs(height) * (((bit32.band(flags, ImDrawFlags.RoundLeft) == ImDrawFlags.RoundLeft) or (bit32.band(flags, ImDrawFlags.RoundRight) == ImDrawFlags.RoundRight)) and 0.5 or 1.0) - 1.0)
    end

    local is_truncated = outer_min_x % 1 == 0 and outer_min_y % 1 == 0 and outer_max_x % 1 == 0 and outer_max_y % 1 == 0 and outer_rounding % 1 == 0 and thickness % 1 == 0 -- [Port] IM_IS_TRUNCATED4() x2
    if self._FringeScaleIsInteger and is_truncated then
        local s_rounding = ImTrunc64(outer_rounding * self._InvFringeScale)
        local s_thickness = ImTrunc64(thickness * self._InvFringeScale)
        if s_thickness <= 0 then
            return
        end

        if s_rounding <= 0 or bit32.band(flags, ImDrawFlags.RoundMask_) == ImDrawFlags.RoundNone then
            -- Pixel aligned non-rounded rect.
            local opaque_uv = self._Data.TexUvWhitePixel
            local u, v = opaque_uv.x, opaque_uv.y
            local t = s_thickness * fringe_scale

            PrimReserve(self, 8 * 3, 8)
            local vb = self.VtxBuffer.Buf
            local ib = self.IdxBuffer.Data
            local vw = self._VtxWritePtr
            local iw = self._IdxWritePtr
            local idx = self._VtxCurrentIdx
            WV(vb, vw + 0, outer_min_x, outer_min_y, u, v, col)
            WV(vb, vw + 1, outer_min_x + t, outer_min_y + t, u, v, col)
            WV(vb, vw + 2, outer_max_x, outer_min_y, u, v, col)
            WV(vb, vw + 3, outer_max_x - t, outer_min_y + t, u, v, col)
            WV(vb, vw + 4, outer_max_x, outer_max_y, u, v, col)
            WV(vb, vw + 5, outer_max_x - t, outer_max_y - t, u, v, col)
            WV(vb, vw + 6, outer_min_x, outer_max_y, u, v, col)
            WV(vb, vw + 7, outer_min_x + t, outer_max_y - t, u, v, col)

            ib[iw + 0] = idx + 0; ib[iw + 1] = idx + 3; ib[iw + 2] = idx + 1
            ib[iw + 3] = idx + 0; ib[iw + 4] = idx + 2; ib[iw + 5] = idx + 3

            ib[iw + 6] = idx + 2; ib[iw + 7] = idx + 5; ib[iw + 8] = idx + 3
            ib[iw + 9] = idx + 2; ib[iw + 10] = idx + 4; ib[iw + 11] = idx + 5

            ib[iw + 12] = idx + 4; ib[iw + 13] = idx + 7; ib[iw + 14] = idx + 5
            ib[iw + 15] = idx + 4; ib[iw + 16] = idx + 6; ib[iw + 17] = idx + 7

            ib[iw + 18] = idx + 6; ib[iw + 19] = idx + 1; ib[iw + 20] = idx + 7
            ib[iw + 21] = idx + 6; ib[iw + 22] = idx + 0; ib[iw + 23] = idx + 1

            self._VtxWritePtr = vw + 8
            self._IdxWritePtr = iw + 24
            self._VtxCurrentIdx = idx + 8
            return
        end
        -- Textured corners are baked with AA, do not use them if no-AA is requested.
        local allow_tex_corners_mask = bit32.bor(ImDrawFlags.AALines, ImDrawFlags.UseTexForRoundCorners, ImDrawFlags.AllowTexForRoundCorners_)
        local allow_tex_corners = bit32.band(flags, allow_tex_corners_mask) == allow_tex_corners_mask
        if allow_tex_corners and s_thickness < IM_DRAWLIST_TEX_CORNERS_THICKNESS_MAX and s_rounding <= IM_DRAWLIST_TEX_CORNERS_ROUNDING_MAX then
            -- Pixel aligned rect with round corners rendered using baked textures.
            IM_ASSERT_PARANOID(s_thickness > 0 and s_rounding > 0)
            local size = ImMax(s_rounding, s_thickness) -- This is matching the baking calculations.
            local idx = (s_thickness * IM_DRAWLIST_TEX_CORNERS_ROUNDING_MAX) + s_rounding - 1
            -- IM_ASSERT_PARANOID((_Data->Font->OwnerAtlas->Flags & ImFontAtlasFlags_NoBakedRoundCorners) == 0) -- [Luau] not evaluated (arguments are not compiled out)
            IM_ASSERT_PARANOID(idx >= 0 and idx < IM_DRAWLIST_TEX_CORNERS_ROUNDING_MAX * IM_DRAWLIST_TEX_CORNERS_THICKNESS_MAX)
            _AddRectBakedXY(self, outer_min_x, outer_min_y, outer_max_x, outer_max_y, col, size * fringe_scale, thickness, self._Data.TexUvCorners[idx], flags)
            return
        end
    end

    if not has_rounding or bit32.band(flags, ImDrawFlags.RoundMask_) == ImDrawFlags.RoundNone then
        local points = prim_points
        points[1].x = outer_min_x; points[1].y = outer_min_y
        points[2].x = outer_max_x; points[2].y = outer_min_y
        points[3].x = outer_max_x; points[3].y = outer_max_y
        points[4].x = outer_min_x; points[4].y = outer_max_y
        self:_AddPolyline(points, 4, col, thickness, bit32.bor(ImDrawFlags.Closed, ImDrawFlags.JoinMiter, ImDrawFlags.StrokeInside), half_min_dim)
        self._Path.Size = 0
    else
        -- Switch to specialized rendering a bit early to avoid overdraw visible in transparent shapes.
        if thickness + (0.75 * fringe_scale) > outer_rounding then
            -- Special case rendering to avoid rendering artifacts at the corners.
            -- If rendered using the regular polyline, the stroke will fold and leave artifacts on the corners if rendered with transparency.
            self:_AddRectTinyRounding(ImVec2(outer_min_x, outer_min_y), ImVec2(outer_max_x, outer_max_y), col, outer_rounding, thickness, flags)
            return
        end
        local rounding_tl = (bit32.band(flags, ImDrawFlags.RoundTopLeft) ~= 0) and outer_rounding or 0.0
        local rounding_tr = (bit32.band(flags, ImDrawFlags.RoundTopRight) ~= 0) and outer_rounding or 0.0
        local rounding_br = (bit32.band(flags, ImDrawFlags.RoundBottomRight) ~= 0) and outer_rounding or 0.0
        local rounding_bl = (bit32.band(flags, ImDrawFlags.RoundBottomLeft) ~= 0) and outer_rounding or 0.0
        -- [Luau] inline PathArcToFast()
        _PathArcToFastExXY(self, outer_min_x + rounding_tl, outer_min_y + rounding_tl, rounding_tl, 6 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 9 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 0)
        _PathArcToFastExXY(self, outer_max_x - rounding_tr, outer_min_y + rounding_tr, rounding_tr, 9 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 12 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 0)
        _PathArcToFastExXY(self, outer_max_x - rounding_br, outer_max_y - rounding_br, rounding_br, 0 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 3 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 0)
        _PathArcToFastExXY(self, outer_min_x + rounding_bl, outer_max_y - rounding_bl, rounding_bl, 3 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 6 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 0)

        self:_AddPolyline(self._Path.Data, self._Path.Size, col, thickness, bit32.bor(ImDrawFlags.Closed, ImDrawFlags.JoinMiter, ImDrawFlags.StrokeInside, bit32.band(flags, bit32.bnot(ImDrawFlags.StrokeMask_))), half_min_dim)
        self._Path.Size = 0
    end
end

-- [Luau] _AddRectFilledBaked() taking p_min/p_max as scalars
@native
local function _AddRectFilledBakedXY(self, p_min_x, p_min_y, p_max_x, p_max_y, col, r, tex_uvs, flags)
    -- 9-slice with corner mirroring
    local uv_l, uv_t, uv_r, uv_b = tex_uvs.x, tex_uvs.y, tex_uvs.z, tex_uvs.w -- [Port] uv_tl = (l,t), uv_tr = (r,t), uv_br = (r,b), uv_bl = (l,b)

    PrimReserve(self, 9 * 2 * 3, 4 * 4)

    local r_tl = (bit32.band(flags, ImDrawFlags.RoundTopLeft) ~= 0) and r or 0.0
    local r_tr = (bit32.band(flags, ImDrawFlags.RoundTopRight) ~= 0) and r or 0.0
    local r_br = (bit32.band(flags, ImDrawFlags.RoundBottomRight) ~= 0) and r or 0.0
    local r_bl = (bit32.band(flags, ImDrawFlags.RoundBottomLeft) ~= 0) and r or 0.0

    local vb = self.VtxBuffer.Buf
    local ib = self.IdxBuffer.Data
    local vw = self._VtxWritePtr
    local iw = self._IdxWritePtr
    local idx = self._VtxCurrentIdx
    WV(vb, vw + 0, p_min_x, p_min_y, uv_l, uv_t, col)
    WV(vb, vw + 1, p_min_x + r_tl, p_min_y, uv_r, uv_t, col)
    WV(vb, vw + 2, p_max_x - r_tr, p_min_y, uv_r, uv_t, col)
    WV(vb, vw + 3, p_max_x, p_min_y, uv_l, uv_t, col)

    WV(vb, vw + 4, p_min_x, p_min_y + r_tl, uv_l, uv_b, col)
    WV(vb, vw + 5, p_min_x + r_tl, p_min_y + r_tl, uv_r, uv_b, col)
    WV(vb, vw + 6, p_max_x - r_tr, p_min_y + r_tr, uv_r, uv_b, col)
    WV(vb, vw + 7, p_max_x, p_min_y + r_tr, uv_l, uv_b, col)

    WV(vb, vw + 8, p_min_x, p_max_y - r_bl, uv_l, uv_b, col)
    WV(vb, vw + 9, p_min_x + r_bl, p_max_y - r_bl, uv_r, uv_b, col)
    WV(vb, vw + 10, p_max_x - r_br, p_max_y - r_br, uv_r, uv_b, col)
    WV(vb, vw + 11, p_max_x, p_max_y - r_br, uv_l, uv_b, col)

    WV(vb, vw + 12, p_min_x, p_max_y, uv_l, uv_t, col)
    WV(vb, vw + 13, p_min_x + r_bl, p_max_y, uv_r, uv_t, col)
    WV(vb, vw + 14, p_max_x - r_br, p_max_y, uv_r, uv_t, col)
    WV(vb, vw + 15, p_max_x, p_max_y, uv_l, uv_t, col)

    for _ = 0, 2 do
        for _ = 0, 2 do
            ib[iw + 0] = idx + 4; ib[iw + 1] = idx + 0; ib[iw + 2] = idx + 1
            ib[iw + 3] = idx + 4; ib[iw + 4] = idx + 1; ib[iw + 5] = idx + 5
            iw = iw + 6
            idx = idx + 1
        end
        idx = idx + 1
    end
    self._VtxWritePtr = vw + 16
    self._IdxWritePtr = iw
    self._VtxCurrentIdx = self._VtxCurrentIdx + 16
end

--- @param p_min   ImVec2
--- @param p_max   ImVec2
--- @param col     ImU32
--- @param r       float
--- @param tex_uvs ImVec4
--- @param flags   ImDrawFlags
function MT.ImDrawList:_AddRectFilledBaked(p_min, p_max, col, r, tex_uvs, flags)
    _AddRectFilledBakedXY(self, p_min.x, p_min.y, p_max.x, p_max.y, col, r, tex_uvs, flags)
end

--- @param p_min     ImVec2
--- @param p_max     ImVec2
--- @param col       ImU32
--- @param rounding? float
--- @param flags?    ImDrawFlags
@native
function MT.ImDrawList:AddRectFilled(p_min, p_max, col, rounding, flags)
    if not rounding then rounding = 0.0 end
    if not flags    then flags    = 0   end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local ax, ay, bx, by = p_min.x, p_min.y, p_max.x, p_max.y
    if ax > bx then ax, bx = bx, ax end -- [Port] reversed corners: see AddRect
    if ay > by then ay, by = by, ay end
    local width = bx - ax
    local height = by - ay
    local min_dim = ImMin(width, height)
    flags = bit32.bor(flags, self.Flags)

    if bit32.band(flags, ImDrawFlags.StrokeMask_) == ImDrawFlags.StrokeLegacy and rounding < 0.5 then
        PrimReserve(self, 6, 4) -- [Luau] local calls
        PrimRectXY(self, ax, ay, bx, by, col)
        return
    end

    -- The rect is smaller than pixel in one dimension.
    local fringe_scale = self._FringeScale
    if min_dim < fringe_scale then
        if min_dim < (1.0 / 255.0) * fringe_scale then
            return
        end
        if width < fringe_scale then
            col = ImAlphaMultiply(col, width * self._InvFringeScale)
            width = fringe_scale
        end
        if height < fringe_scale then
            col = ImAlphaMultiply(col, height * self._InvFringeScale)
            height = fringe_scale
        end
        local points = prim_points
        points[1].x = ax;         points[1].y = ay
        points[2].x = ax + width; points[2].y = ay
        points[3].x = ax + width; points[3].y = ay + height
        points[4].x = ax;         points[4].y = ay + height
        self:AddConvexPolyFilled(points, 4, col, ImDrawFlags.JoinMiter)
        return
    end

    -- When rounding non-integer and under threshold, has_rounding may be false but still affect is_truncated. Likely not worth catering for.
    local has_rounding = bit32.band(flags, ImDrawFlags.RoundMask_) ~= ImDrawFlags.RoundNone and rounding >= 0.25 * fringe_scale -- [Port] IM_HAS_ROUNDING(rounding)
    local is_truncated = ax % 1 == 0 and ay % 1 == 0 and bx % 1 == 0 and by % 1 == 0 and rounding % 1 == 0 -- [Port] IM_IS_TRUNCATED4() && IM_IS_TRUNCATED()

    if self._FringeScaleIsInteger and is_truncated then
        -- Fast path for the non-AA non-rounded rect.
        if not has_rounding then
            PrimReserve(self, 6, 4)
            PrimRectXY(self, ax, ay, bx, by, col)
            return
        end

        if bit32.band(flags, ImDrawFlags.RoundMask_) == 0 then
            flags = bit32.bor(flags, ImDrawFlags.RoundAll)
        end

        rounding = ImMin(rounding, ImAbs(width) * (((bit32.band(flags, ImDrawFlags.RoundTop) == ImDrawFlags.RoundTop) or (bit32.band(flags, ImDrawFlags.RoundBottom) == ImDrawFlags.RoundBottom)) and 0.5 or 1.0) - 1.0)
        rounding = ImMin(rounding, ImAbs(height) * (((bit32.band(flags, ImDrawFlags.RoundLeft) == ImDrawFlags.RoundLeft) or (bit32.band(flags, ImDrawFlags.RoundRight) == ImDrawFlags.RoundRight)) and 0.5 or 1.0) - 1.0)

        local s_rounding = ImTrunc64(rounding * self._InvFringeScale)
        if s_rounding <= 0 then
            PrimReserve(self, 6, 4)
            PrimRectXY(self, ax, ay, bx, by, col)
            return
        end
        -- Textured corners are baked with AA, do not use them if no-AA is requested.
        local allow_tex_corners_mask = bit32.bor(ImDrawFlags.AAFill, ImDrawFlags.UseTexForRoundCorners, ImDrawFlags.AllowTexForRoundCorners_)
        local allow_tex_corners = bit32.band(flags, allow_tex_corners_mask) == allow_tex_corners_mask
        if allow_tex_corners and s_rounding <= IM_DRAWLIST_TEX_CORNERS_ROUNDING_MAX then
            -- IM_ASSERT_PARANOID((_Data->Font->OwnerAtlas->Flags & ImFontAtlasFlags_NoBakedRoundCorners) == 0) -- [Luau] not evaluated (arguments are not compiled out)
            -- This is matching the baking calculations. The rounding clamping above makes sure that there's enough space for the extra pixel.
            local corner_size = s_rounding + 1
            -- Check that the baked corners do not overlap (this could be made more accurate if tested for x and y separately).
            if corner_size * 2.0 * fringe_scale < min_dim then
                local idx = (s_rounding - 1)
                IM_ASSERT_PARANOID(idx >= 0 and idx < IM_DRAWLIST_TEX_CORNERS_ROUNDING_MAX)
                _AddRectFilledBakedXY(self, ax, ay, bx, by, col, corner_size * fringe_scale, self._Data.TexUvCorners[idx], flags)
                return
            end
        end
    end

    if not has_rounding then
        local points = prim_points
        points[1].x = ax; points[1].y = ay
        points[2].x = bx; points[2].y = ay
        points[3].x = bx; points[3].y = by
        points[4].x = ax; points[4].y = by
        self:AddConvexPolyFilled(points, 4, col, ImDrawFlags.JoinMiter)
    else
        PathRectXY(self, ax, ay, bx, by, rounding, flags)
        self:PathFillConvex(col, ImDrawFlags.JoinMiter)
    end
end

-- p_min = upper-left, p_max = lower-right
-- Note: this does not support anti-aliasing when provided non-integer vertices.
--- @param p_min         ImVec2
--- @param p_max         ImVec2
--- @param col_upr_left  ImU32
--- @param col_upr_right ImU32
--- @param col_bot_right ImU32
--- @param col_bot_left  ImU32
function MT.ImDrawList:AddRectFilledMultiColor(p_min, p_max, col_upr_left, col_upr_right, col_bot_right, col_bot_left)
    if bit32.band(bit32.bor(col_upr_left, col_upr_right, col_bot_right, col_bot_left), IM_COL32_A_MASK) == 0 then
        return
    end

    local uv = self._Data.TexUvWhitePixel
    PrimReserve(self, 6, 4)
    -- [Luau] inline PrimWriteIdx()/PrimWriteVtx(): direct writes, no temporary ImVec2
    local idx, idx_data, idx_write_ptr = self._VtxCurrentIdx, self.IdxBuffer.Data, self._IdxWritePtr
    idx_data[idx_write_ptr] = idx; idx_data[idx_write_ptr + 1] = idx + 1; idx_data[idx_write_ptr + 2] = idx + 2
    idx_data[idx_write_ptr + 3] = idx; idx_data[idx_write_ptr + 4] = idx + 2; idx_data[idx_write_ptr + 5] = idx + 3
    self._IdxWritePtr = idx_write_ptr + 6
    local vtx_data, vtx_write_ptr = self.VtxBuffer.Buf, self._VtxWritePtr
    WV(vtx_data, vtx_write_ptr + 0, p_min.x, p_min.y, uv.x, uv.y, col_upr_left)
    WV(vtx_data, vtx_write_ptr + 1, p_max.x, p_min.y, uv.x, uv.y, col_upr_right)
    WV(vtx_data, vtx_write_ptr + 2, p_max.x, p_max.y, uv.x, uv.y, col_bot_right)
    WV(vtx_data, vtx_write_ptr + 3, p_min.x, p_max.y, uv.x, uv.y, col_bot_left)
    self._VtxWritePtr = vtx_write_ptr + 4
    self._VtxCurrentIdx = idx + 4
end

--- @param thickness? float
--- @param flags?     ImDrawFlags
function MT.ImDrawList:AddQuad(p1, p2, p3, p4, col, thickness, flags)
    if thickness == nil then thickness = 1.0 end
    if flags     == nil then flags     = 0   end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    --flags |= Flags; // Not needed.
    local stroke_pos = _GetStrokePos(flags, ImDrawFlags.StrokeInside)
    flags = bit32.bor(bit32.band(flags, bit32.bnot(ImDrawFlags.StrokeMask_)), stroke_pos) -- As AddPolyline() default is different

    local points = prim_points
    ImVec2_Copy(points[1], p1); ImVec2_Copy(points[2], p2); ImVec2_Copy(points[3], p3); ImVec2_Copy(points[4], p4)
    self:_AddPolyline(points, 4, col, thickness, bit32.bor(flags, ImDrawFlags.Closed), FLT_MAX)
end

function MT.ImDrawList:AddQuadFilled(p1, p2, p3, p4, col)
    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local points = prim_points
    ImVec2_Copy(points[1], p1); ImVec2_Copy(points[2], p2); ImVec2_Copy(points[3], p3); ImVec2_Copy(points[4], p4)
    self:AddConvexPolyFilled(points, 4, col)
end

--- @param thickness? float
--- @param flags?     ImDrawFlags
function MT.ImDrawList:AddTriangle(p1, p2, p3, col, thickness, flags)
    if thickness == nil then thickness = 1.0 end
    if flags     == nil then flags     = 0   end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    --flags |= Flags; // Not needed.
    local stroke_pos = _GetStrokePos(flags, ImDrawFlags.StrokeInside)
    flags = bit32.bor(bit32.band(flags, bit32.bnot(ImDrawFlags.StrokeMask_)), stroke_pos) -- As AddPolyline() default is different

    local points = prim_points
    ImVec2_Copy(points[1], p1); ImVec2_Copy(points[2], p2); ImVec2_Copy(points[3], p3)
    self:_AddPolyline(points, 3, col, thickness, bit32.bor(flags, ImDrawFlags.Closed), FLT_MAX)
end

function MT.ImDrawList:AddTriangleFilled(p1, p2, p3, col)
    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local points = prim_points
    ImVec2_Copy(points[1], p1); ImVec2_Copy(points[2], p2); ImVec2_Copy(points[3], p3)
    self:AddConvexPolyFilled(points, 3, col)
end

--- @param center        ImVec2
--- @param radius        float
--- @param col           ImU32
--- @param num_segments? int
--- @param thickness?    float
--- @param flags?        ImDrawFlags
function MT.ImDrawList:AddCircle(center, radius, col, num_segments, thickness, flags)
    if num_segments == nil then num_segments = 0   end
    if thickness    == nil then thickness    = 1.0 end
    if flags        == nil then flags        = 0   end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    flags = bit32.bor(flags, self.Flags)
    local stroke_pos = _GetStrokePos(flags, ImDrawFlags.StrokeInside)
    if stroke_pos == ImDrawFlags.StrokeLegacy then
        radius = radius - 0.5
        stroke_pos = ImDrawFlags.StrokeCenter
    end
    radius = ImMax(0.01, radius)

    local outer_radius = radius
    if stroke_pos == ImDrawFlags.StrokeCenter then
        outer_radius = radius + thickness * 0.5
    elseif stroke_pos == ImDrawFlags.StrokeCenterBiased then
        outer_radius = radius + _CalculateCenterBiasedOffset(self, thickness)
    elseif stroke_pos == ImDrawFlags.StrokeInside then
        outer_radius = radius
    elseif stroke_pos == ImDrawFlags.StrokeOutside then
        outer_radius = radius + thickness
    end

    if outer_radius <= thickness then
        -- The circle has collapsed into a filled circle.
        self:AddCircleFilled(center, outer_radius, col, num_segments)
        return
    end

    if num_segments <= 0 and outer_radius <= self._Data.ArcFastRadiusCutoff then
        -- Use arc with automatic segment count
        local a_step = math.floor(IM_DRAWLIST_ARCFAST_SAMPLE_MAX / self:_CalcCircleAutoSegmentCount(outer_radius)) -- Use outer_radius for segment count to be consistent with rounded rect.
        _PathArcToFastExXY(self, center.x, center.y, radius, 0, IM_DRAWLIST_ARCFAST_SAMPLE_MAX, a_step)
        self._Path.Size = self._Path.Size - 1
    else
        -- Explicit segment count or above fast arc cutoff (still clamp to avoid drawing insanely tessellated shapes)
        if num_segments <= 0 then
            num_segments = self:_CalcCircleAutoSegmentCount(outer_radius)
        end
        num_segments = ImClamp(num_segments, 3, IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MAX)

        -- Because we are filling a closed shape we remove 1 from the count of segments/points
        local a_max = (IM_PI * 2.0) * (num_segments - 1.0) / num_segments
        self:PathArcTo(center, radius, 0.0, a_max, num_segments - 1)
    end

    if self._Path.Size >= 3 then
        -- Calculate distance to the edge of the polygon describing the circle.
        -- This will be used by _AddPolyline() to clamp the inner stroke expansion, to avoid creating rendering artifacts.
        local unit_apothem = ApproxApothem(self._Path.Size)
        local edge_dist = radius * unit_apothem
        self:_AddPolyline(self._Path.Data, self._Path.Size, col, thickness, bit32.bor(ImDrawFlags.Closed, ImDrawFlags.JoinMiter, stroke_pos), edge_dist)
    end
    self._Path.Size = 0
end

--- @param center        ImVec2
--- @param radius        float
--- @param col           ImU32
--- @param num_segments? int
function MT.ImDrawList:AddCircleFilled(center, radius, col, num_segments)
    if num_segments == nil then num_segments = 0 end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local diameter = radius * 2.0
    if diameter < self._FringeScale then
        if diameter < (1.0 / 255.0) * self._FringeScale then
            return
        end
        col = ImAlphaMultiply(col, diameter * self._InvFringeScale)
        radius = self._FringeScale * 0.5
    end

    if num_segments <= 0 and radius <= self._Data.ArcFastRadiusCutoff then
        -- Use arc with automatic segment count
        _PathArcToFastExXY(self, center.x, center.y, radius, 0, IM_DRAWLIST_ARCFAST_SAMPLE_MAX, 0)
        self._Path.Size = self._Path.Size - 1
    else
        -- Explicit segment count or above cutoff (still clamp to avoid drawing insanely tessellated shapes)
        if num_segments <= 0 then
            num_segments = self:_CalcCircleAutoSegmentCount(radius)
        end
        num_segments = ImClamp(num_segments, 3, IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MAX)

        -- Because we are filling a closed shape we remove 1 from the count of segments/points
        local a_max = (IM_PI * 2.0) * (num_segments - 1.0) / num_segments
        self:PathArcTo(center, radius, 0.0, a_max, num_segments - 1)
    end

    self:PathFillConvex(col, ImDrawFlags.JoinMiter)
end

-- Guaranteed to honor 'num_segments'
--- @param thickness? float
--- @param flags?     ImDrawFlags
function MT.ImDrawList:AddNgon(center, radius, col, num_segments, thickness, flags)
    if thickness == nil then thickness = 1.0 end
    if flags     == nil then flags     = 0   end

    if bit32.band(col, IM_COL32_A_MASK) == 0 or num_segments <= 2 then
        return
    end

    flags = bit32.bor(flags, self.Flags)
    local stroke_pos = _GetStrokePos(flags, ImDrawFlags.StrokeInside)
    if stroke_pos == ImDrawFlags.StrokeLegacy then
        radius = radius - 0.5
        stroke_pos = ImDrawFlags.StrokeCenter
    end
    radius = ImMax(0.01, radius)

    -- Calculate distance to the edge of the polygon describing the circle.
    -- This will be used by _AddPolyline() to clamp the inner stroke expansion, to avoid creating rendering artifacts.
    local unit_apothem = ApproxApothem(num_segments)
    local edge_dist = radius * unit_apothem

    -- Check overestimate first before testing details.
    if radius < thickness * 2.0 then
        local outer_radius = radius
        if stroke_pos == ImDrawFlags.StrokeCenter then
            outer_radius = radius + thickness * 0.5
        elseif stroke_pos == ImDrawFlags.StrokeCenterBiased then
            outer_radius = radius + _CalculateCenterBiasedOffset(self, thickness)
        elseif stroke_pos == ImDrawFlags.StrokeInside then
            outer_radius = radius
        elseif stroke_pos == ImDrawFlags.StrokeOutside then
            outer_radius = radius + thickness
        end
        if outer_radius * unit_apothem <= thickness then
            -- The polygon has collapsed into a filled polygon.
            self:AddNgonFilled(center, outer_radius, col, num_segments)
            return
        end
    end

    -- Because we are filling a closed shape we remove 1 from the count of segments/points
    local a_max = (IM_PI * 2.0) * (num_segments - 1.0) / num_segments
    self:PathArcTo(center, radius, 0.0, a_max, num_segments - 1)
    self:_AddPolyline(self._Path.Data, self._Path.Size, col, thickness, bit32.bor(ImDrawFlags.Closed, ImDrawFlags.JoinMiter, stroke_pos), edge_dist)
    self._Path.Size = 0
end

-- Guaranteed to honor 'num_segments'
function MT.ImDrawList:AddNgonFilled(center, radius, col, num_segments)
    if bit32.band(col, IM_COL32_A_MASK) == 0 or num_segments <= 2 then
        return
    end

    local diameter = radius * 2.0
    if diameter < self._FringeScale then
        if diameter < (1.0 / 255.0) * self._FringeScale then
            return
        end
        col = ImAlphaMultiply(col, diameter * self._InvFringeScale)
        radius = self._FringeScale * 0.5
    end

    -- Because we are filling a closed shape we remove 1 from the count of segments/points
    local a_max = (IM_PI * 2.0) * (num_segments - 1.0) / num_segments
    self:PathArcTo(center, radius, 0.0, a_max, num_segments - 1)
    self:PathFillConvex(col, ImDrawFlags.JoinMiter)
end

-- Ellipse
--- @param rot?          float
--- @param num_segments? int
--- @param thickness?    float
--- @param flags?        ImDrawFlags
function MT.ImDrawList:AddEllipse(center, radius, col, rot, num_segments, thickness, flags)
    if rot          == nil then rot          = 0.0 end
    if num_segments == nil then num_segments = 0   end
    if thickness    == nil then thickness    = 1.0 end
    if flags        == nil then flags        = 0   end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local stroke_pos = _GetStrokePos(flags, ImDrawFlags.StrokeInside)
    if stroke_pos == ImDrawFlags.StrokeLegacy then
        stroke_pos = ImDrawFlags.StrokeCenter
    end

    local rad = ImVec2(radius.x, radius.y)
    rad.x = ImMax(0.01, rad.x)
    rad.y = ImMax(0.01, rad.y)

    if num_segments <= 0 then
        num_segments = self:_CalcCircleAutoSegmentCount(ImMax(rad.x, rad.y)) -- A bit pessimistic, maybe there's a better computation to do here.
    end

    self._Path:reserve(self._Path.Size + (num_segments + 1))

    -- Because we are filling a closed shape we remove 1 from the count of segments/points
    local a_max = IM_PI * 2.0 * (num_segments - 1.0) / num_segments
    self:PathEllipticalArcTo(center, rad, rot, 0.0, a_max, num_segments - 1)

    -- Prevent the inside part of the stroke to be expanded too much to prevent some rendering artifacts.
    local max_inner_offset = ImMin(rad.x, rad.y)
    self:_AddPolyline(self._Path.Data, self._Path.Size, col, thickness, bit32.bor(ImDrawFlags.Closed, ImDrawFlags.JoinMiter, stroke_pos), max_inner_offset)
    self._Path.Size = 0
end

--- @param rot?          float
--- @param num_segments? int
function MT.ImDrawList:AddEllipseFilled(center, radius, col, rot, num_segments)
    if rot          == nil then rot          = 0.0 end
    if num_segments == nil then num_segments = 0   end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local rad = ImVec2(radius.x, radius.y)
    local diameter_x = rad.x * 2.0
    local diameter_y = rad.y * 2.0
    local min_dim = ImMin(diameter_x, diameter_y)

    -- The ellipse is smaller than pixel in one dimension.
    if min_dim < self._FringeScale then
        if min_dim < (1.0 / 255.0) * self._FringeScale then
            return
        end
        if diameter_x < self._FringeScale then
            col = ImAlphaMultiply(col, diameter_x * self._InvFringeScale)
            rad.x = self._FringeScale * 0.5
        end
        if diameter_y < self._FringeScale then
            col = ImAlphaMultiply(col, diameter_y * self._InvFringeScale)
            rad.y = self._FringeScale * 0.5
        end
    end

    if num_segments <= 0 then
        num_segments = self:_CalcCircleAutoSegmentCount(ImMax(radius.x, radius.y)) -- A bit pessimistic, maybe there's a better computation to do here.
    end

    -- Because we are filling a closed shape we remove 1 from the count of segments/points
    local a_max = IM_PI * 2.0 * (num_segments - 1.0) / num_segments
    self:PathEllipticalArcTo(center, radius, rot, 0.0, a_max, num_segments - 1) -- [Port] upstream passes 'radius' (not 'rad') here, kept as-is
    self:PathFillConvex(col)
end

-- Cubic Bezier takes 4 controls points
--- @param num_segments? int
--- @param flags?        ImDrawFlags
function MT.ImDrawList:AddBezierCubic(p1, p2, p3, p4, col, thickness, num_segments, flags)
    if num_segments == nil then num_segments = 0 end
    if flags        == nil then flags        = 0 end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    self:PathLineTo(p1)
    self:PathBezierCubicCurveTo(p2, p3, p4, num_segments)
    self:PathStroke(col, thickness, flags)
end

-- Quadratic Bezier takes 3 controls points
--- @param num_segments? int
--- @param flags?        ImDrawFlags
function MT.ImDrawList:AddBezierQuadratic(p1, p2, p3, col, thickness, num_segments, flags)
    if num_segments == nil then num_segments = 0 end
    if flags        == nil then flags        = 0 end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    self:PathLineTo(p1)
    self:PathBezierQuadraticCurveTo(p2, p3, num_segments)
    self:PathStroke(col, thickness, flags)
end

--- @param font                ImFont
--- @param font_size           float
--- @param pos                 ImVec2
--- @param col                 ImU32
--- @param text                string
--- @param text_begin?         int    # Defaults to 1
--- @param text_end            int
--- @param wrap_width          float
--- @param cpu_fine_clip_rect? ImVec4
local AddText_clip_rect = ImVec4()

@native
function MT.ImDrawList:AddText(font, font_size, pos, col, text, text_begin, text_end, wrap_width, cpu_fine_clip_rect)
    -- [Port] Overload: AddText(pos, col, text, text_end?)
    if type(font) == "table" and type(font[1]) == "number" then
        font, font_size, pos, col, text, text_begin, text_end, wrap_width, cpu_fine_clip_rect = nil, 0.0, font, font_size, pos, 1, col, 0.0, nil
        if text_end == nil then text_end = #text + 1 end
    end
    if text_begin == nil then text_begin = 1 end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then return end

    -- Accept null ranges
    if text_begin == text_end then
        return
    end
    -- No need to strlen() here: font:RenderText() will do it and may early out.

    -- Pull default font/size from the shared ImDrawListSharedData instance
    if font == nil then
        font = self._Data.Font
    end
    if font_size == 0.0 then
        font_size = self._Data.FontSize
    end

    local clip_rect = AddText_clip_rect -- Don't modify the clip rect! -- [Luau] scratch: ImFont:RenderText() only reads it
    local src = self._CmdHeader.ClipRect
    clip_rect.x = src.x; clip_rect.y = src.y; clip_rect.z = src.z; clip_rect.w = src.w
    if (cpu_fine_clip_rect) then
        clip_rect.x = math.max(clip_rect.x, cpu_fine_clip_rect.x)
        clip_rect.y = math.max(clip_rect.y, cpu_fine_clip_rect.y)
        clip_rect.z = math.min(clip_rect.z, cpu_fine_clip_rect.z)
        clip_rect.w = math.min(clip_rect.w, cpu_fine_clip_rect.w)
    end

    font:RenderText(self, font_size, pos, col, clip_rect, text, text_begin, text_end, wrap_width, (cpu_fine_clip_rect ~= nil) and ImDrawTextFlags.CpuFineClip or ImDrawTextFlags.None)
end

--- @param tex_ref ImTextureRef
--- @param p_min   ImVec2
--- @param p_max   ImVec2
--- @param uv_min? ImVec2
--- @param uv_max? ImVec2
--- @param col?    ImU32
function MT.ImDrawList:AddImage(tex_ref, p_min, p_max, uv_min, uv_max, col)
    if uv_min == nil then uv_min = ImVec2(0, 0)   end
    if uv_max == nil then uv_max = ImVec2(1, 1)   end
    if col    == nil then col    = IM_COL32_WHITE end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local push_texture_id = tex_ref ~= self._CmdHeader.TexRef
    if push_texture_id then
        self:PushTexture(tex_ref)
    end

    self:PrimReserve(6, 4)
    self:PrimRectUV(p_min, p_max, uv_min, uv_max, col)

    if push_texture_id then
        self:PopTexture()
    end
end

function MT.ImDrawList:AddImageQuad(tex_ref, p1, p2, p3, p4, uv1, uv2, uv3, uv4, col)
    if uv1 == nil then uv1 = ImVec2(0, 0) end
    if uv2 == nil then uv2 = ImVec2(1, 0) end
    if uv3 == nil then uv3 = ImVec2(1, 1) end
    if uv4 == nil then uv4 = ImVec2(0, 1) end
    if col == nil then col = IM_COL32_WHITE end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local push_texture_id = tex_ref ~= self._CmdHeader.TexRef
    if push_texture_id then
        self:PushTexture(tex_ref)
    end

    self:PrimReserve(6, 4)
    self:PrimQuadUV(p1, p2, p3, p4, uv1, uv2, uv3, uv4, col)

    if push_texture_id then
        self:PopTexture()
    end
end

--- @param tex_ref  ImTextureRef
--- @param p_min    ImVec2
--- @param p_max    ImVec2
--- @param uv_min   ImVec2
--- @param uv_max   ImVec2
--- @param col      ImU32
--- @param rounding float
--- @param flags    ImDrawFlags
function MT.ImDrawList:AddImageRounded(tex_ref, p_min, p_max, uv_min, uv_max, col, rounding, flags)
    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end
    if flags == nil then flags = 0 end

    IM_ASSERT(bit32.band(flags, 0x0F) == 0, "Misuse of legacy hardcoded ImDrawCornerFlags values!") -- If this assert triggers on legacy code: see comments in ImDrawList:PathRect().
    if bit32.band(flags, ImDrawFlags.RoundMask_) == 0 then
        flags = bit32.bor(flags, ImDrawFlags.RoundAll)
    end

    if rounding < 0.5 or bit32.band(flags, ImDrawFlags.RoundMask_) == ImDrawFlags.RoundNone then
        self:AddImage(tex_ref, p_min, p_max, uv_min, uv_max, col)
        return
    end

    local push_texture_id = (tex_ref ~= self._CmdHeader.TexRef)
    if push_texture_id then
        self:PushTexture(tex_ref)
    end

    local vert_start_idx = self.VtxBuffer.Size + 1
    self:PathRect(p_min, p_max, rounding, flags)
    self:PathFillConvex(col, ImDrawFlags.JoinMiter)
    local vert_end_idx = self.VtxBuffer.Size + 1
    ImGui.ShadeVertsLinearUV(self, vert_start_idx, vert_end_idx, p_min, p_max, uv_min, uv_max, true)

    if push_texture_id then
        self:PopTexture()
    end
end

--- @param radius float
function MT.ImDrawList:_CalcCircleAutoSegmentCount(radius)
    -- Automatic segment count
    local radius_idx = ImFloor(radius + 0.999) + 1 -- ceil to never reduce accuracy

    if radius_idx >= 1 and radius_idx <= 64 then -- [Port] IM_COUNTOF(_Data->CircleSegmentCounts)
        return self._Data.CircleSegmentCounts[radius_idx] -- Use cached value
    else
        return IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC(radius, self._Data.CircleTessellationMaxError)
    end
end

-- Render-level scissoring. This is passed down to your render function but not used for CPU-side coarse clipping. Prefer using higher-level ImGui.PushClipRect() to affect logic (hit-testing and widget culling)
@native
function MT.ImDrawList:PushClipRect(cr_min, cr_max, intersect_with_current_clip_rect)
    -- [Luau] reuse the stack slot's ImVec4 left from earlier frames (each slot stays uniquely owned by the stack)
    local stack = self._ClipRectStack
    local n = stack.Size + 1
    local cr = n <= stack.Capacity and stack.Data[n] or nil
    if cr then
        cr.x = cr_min.x; cr.y = cr_min.y; cr.z = cr_max.x; cr.w = cr_max.y
    else
        cr = ImVec4(cr_min.x, cr_min.y, cr_max.x, cr_max.y)
    end

    if intersect_with_current_clip_rect then
        local current = self._CmdHeader.ClipRect

        if cr.x < current.x then cr.x = current.x end -- = ClipWith(). Note that passing inverted range wouldn't be fixed here.
        if cr.y < current.y then cr.y = current.y end
        if cr.z > current.z then cr.z = current.z end
        if cr.w > current.w then cr.w = current.w end
    end

    cr.z = math.max(cr.x, cr.z)
    cr.w = math.max(cr.y, cr.w)

    -- [Luau] inline self._ClipRectStack:push_back(cr)
    if n > stack.Capacity then stack:push_back(cr) else stack.Data[n] = cr; stack.Size = n end
    ImVec4_Copy(self._CmdHeader.ClipRect, cr)
    self:_OnChangedClipRect()
end

function MT.ImDrawList:PushClipRectFullScreen()
    local cr = self._Data.ClipRectFullscreen
    self:PushClipRect(ImVec2(cr.x, cr.y), ImVec2(cr.z, cr.w))
end

@native
function MT.ImDrawList:PopClipRect()
    local stack = self._ClipRectStack
    IM_ASSERT(stack.Size > 0)
    stack.Size = stack.Size - 1 -- [Luau] inline pop_back()
    if (stack.Size == 0) then -- [Port] No "Ternary Operator"
        ImVec4_Copy(self._CmdHeader.ClipRect, self._Data.ClipRectFullscreen)
    else
        ImVec4_Copy(self._CmdHeader.ClipRect, stack.Data[stack.Size])
    end
    self:_OnChangedClipRect()
end

function MT.ImDrawList:GetClipRectMin() local cr = self._ClipRectStack:back(); return ImVec2(cr.x, cr.y) end
function MT.ImDrawList:GetClipRectMax() local cr = self._ClipRectStack:back(); return ImVec2(cr.z, cr.w) end

--- @param center       ImVec2
--- @param radius       float
--- @param a_min_sample int
--- @param a_max_sample int
--- @param a_step       int
-- [Luau] scalar center (cx, cy); assigned to the forward-declared local, _PathArcToFastEx() wraps it
@native
function _PathArcToFastExXY(self, cx, cy, radius, a_min_sample, a_max_sample, a_step)
    if not (radius >= 0.25 * self._FringeScale) then -- [Port] !IM_HAS_ROUNDING(radius)
        PathLineToXY(self, cx, cy)
        return
    end

    -- Calculate arc auto segment step size
    if a_step <= 0 then
        -- Calculate step size using the common function. No need to clamp, the step is already in range.
        local auto_seg_count = self:_CalcCircleAutoSegmentCount(radius)
        a_step = CalcCornerArcStepAndCount(auto_seg_count)
    else
        -- Make sure we never do steps larger than one quarter of the circle
        a_step = ImClamp(a_step, 1, math.floor(IM_DRAWLIST_ARCFAST_TABLE_SIZE / 4))
    end

    local sample_range = ImAbs(a_max_sample - a_min_sample)
    local a_next_step = a_step

    local samples = sample_range + 1
    local extra_max_sample = false
    if a_step > 1 then
        samples = math.floor(sample_range / a_step) + 1
        local overstep = sample_range % a_step

        if overstep > 0 then
            extra_max_sample = true
            samples = samples + 1

            -- When we have overstep to avoid awkwardly looking one long line and one tiny one at the end,
            -- distribute first step range evenly between them by reducing first step size.
            if sample_range > 0 then
                a_step = a_step - math.floor((a_step - overstep) / 2)
            end
        end
    end

    self._Path:resize(self._Path.Size + samples)
    local out_ptr = self._Path.Size - samples + 1

    local path_data, arc_fast_vtx = self._Path.Data, self._Data.ArcFastVtx -- [Luau] cache
    local sample_index = a_min_sample
    if sample_index < 0 or sample_index >= IM_DRAWLIST_ARCFAST_SAMPLE_MAX then
        sample_index = sample_index % IM_DRAWLIST_ARCFAST_SAMPLE_MAX
        if sample_index < 0 then
            sample_index = sample_index + IM_DRAWLIST_ARCFAST_SAMPLE_MAX
        end
    end

    if a_max_sample >= a_min_sample then
        local a = a_min_sample
        while a <= a_max_sample do
            -- a_step is clamped to IM_DRAWLIST_ARCFAST_SAMPLE_MAX, so we have guaranteed that it will not wrap over range twice or more
            if sample_index >= IM_DRAWLIST_ARCFAST_SAMPLE_MAX then
                sample_index = sample_index - IM_DRAWLIST_ARCFAST_SAMPLE_MAX
            end

            local s = arc_fast_vtx[sample_index + 1]
            local d = path_data[out_ptr]
            d.x = cx + s.x * radius; d.y = cy + s.y * radius
            out_ptr = out_ptr + 1

            a = a + a_step
            sample_index = sample_index + a_step
            a_step = a_next_step
        end
    else
        local a = a_min_sample
        while a >= a_max_sample do
            -- a_step is clamped to IM_DRAWLIST_ARCFAST_SAMPLE_MAX, so we have guaranteed that it will not wrap over range twice or more
            if sample_index < 0 then
                sample_index = sample_index + IM_DRAWLIST_ARCFAST_SAMPLE_MAX
            end

            local s = arc_fast_vtx[sample_index + 1]
            local d = path_data[out_ptr]
            d.x = cx + s.x * radius; d.y = cy + s.y * radius
            out_ptr = out_ptr + 1

            a = a - a_step
            sample_index = sample_index - a_step
            a_step = a_next_step
        end
    end

    if extra_max_sample then
        local normalized_max_sample = a_max_sample % IM_DRAWLIST_ARCFAST_SAMPLE_MAX
        if normalized_max_sample < 0 then
            normalized_max_sample = normalized_max_sample + IM_DRAWLIST_ARCFAST_SAMPLE_MAX
        end

        local s = arc_fast_vtx[normalized_max_sample + 1]
        local d = path_data[out_ptr]
        d.x = cx + s.x * radius; d.y = cy + s.y * radius
        out_ptr = out_ptr + 1
    end

    IM_ASSERT_PARANOID(self._Path.Size == out_ptr - 1)
end

function MT.ImDrawList:_PathArcToFastEx(center, radius, a_min_sample, a_max_sample, a_step)
    _PathArcToFastExXY(self, center.x, center.y, radius, a_min_sample, a_max_sample, a_step)
end

-- 0: East, 3: South, 6: West, 9: North, 12: East
@native
function MT.ImDrawList:PathArcToFast(center, radius, a_min_of_12, a_max_of_12)
    if not (radius >= 0.25 * self._FringeScale) then -- [Port] !IM_HAS_ROUNDING(radius)
        self._Path:push_back(center)
        return
    end

    _PathArcToFastExXY(self, center.x, center.y, radius, a_min_of_12 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, a_max_of_12 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 0)
end

--- @param center       ImVec2
--- @param radius       float
--- @param a_min        float
--- @param a_max        float
--- @param num_segments int
function MT.ImDrawList:_PathArcToN(center, radius, a_min, a_max, num_segments)
    if not (radius >= 0.25 * self._FringeScale) then -- [Port] !IM_HAS_ROUNDING(radius)
        self._Path:push_back(center)
        return
    end

    -- Note that we are adding a point at both a_min and a_max.
    -- If you are trying to draw a full closed circle you don't want the overlapping points!
    local path = self._Path
    path:reserve(path.Size + (num_segments + 1))
    -- [Luau] write into the reserved ImVec2 slots: no temporary ImVec2, no push_back() method lookups
    local data, size = path.Data, path.Size
    for i = 0, num_segments do
        local a = a_min + (i / num_segments) * (a_max - a_min)
        size = size + 1
        local p = data[size]
        p.x = center.x + ImCos(a) * radius; p.y = center.y + ImSin(a) * radius
    end
    path.Size = size
end

--- @param center        ImVec2
--- @param radius        float
--- @param a_min         float
--- @param a_max         float
--- @param num_segments? int
function MT.ImDrawList:PathArcTo(center, radius, a_min, a_max, num_segments)
    if num_segments == nil then num_segments = 0 end

    if not (radius >= 0.25 * self._FringeScale) then -- [Port] !IM_HAS_ROUNDING(radius)
        self._Path:push_back(center)
        return
    end

    if num_segments > 0 then
        self:_PathArcToN(center, radius, a_min, a_max, num_segments)
        return
    end

    -- Automatic segment count
    if radius <= self._Data.ArcFastRadiusCutoff then
        local a_is_reverse = a_max < a_min

        -- Calculate number of segments per circle.
        -- First we calculate the step count as usual, then match to the precomputed directions.
        -- This will give us the spacing between the samples (step), and how many segments to use in total for a full circle.
        local auto_seg_count = self:_CalcCircleAutoSegmentCount(radius)
        local arc_step, arc_step_count = CalcCornerArcStepAndCount(auto_seg_count)
        local arc_seg_count = arc_step_count * 4 -- Seg count for full circle.

        -- We are going to use precomputed values for mid samples.
        -- Determine first and last sample in lookup table that belong to the arc.
        -- In first step we use the coarser segment count, and after rounding, convert back to the precomputed array index.
        local a_min_sample_f = arc_seg_count * a_min / (IM_PI * 2.0)
        local a_max_sample_f = arc_seg_count * a_max / (IM_PI * 2.0)

        local a_min_sample = (a_is_reverse and ImFloor(a_min_sample_f) or ImCeil(a_min_sample_f)) * arc_step
        local a_max_sample = (a_is_reverse and ImCeil(a_max_sample_f) or ImFloor(a_max_sample_f)) * arc_step
        local a_mid_samples = a_is_reverse and ImMax(a_min_sample - a_max_sample, 0) or ImMax(a_max_sample - a_min_sample, 0)

        local a_min_segment_angle = a_min_sample * IM_PI * 2.0 / IM_DRAWLIST_ARCFAST_SAMPLE_MAX
        local a_max_segment_angle = a_max_sample * IM_PI * 2.0 / IM_DRAWLIST_ARCFAST_SAMPLE_MAX
        local a_emit_start = ImAbs(a_min_segment_angle - a_min) >= 1e-5
        local a_emit_end = ImAbs(a_max - a_max_segment_angle) >= 1e-5

        self._Path:reserve(self._Path.Size + (a_mid_samples + 1 + (a_emit_start and 1 or 0) + (a_emit_end and 1 or 0)))

        if a_emit_start      then PathLineToXY(self, center.x + ImCos(a_min) * radius, center.y + ImSin(a_min) * radius) end -- [Luau] no temporary ImVec2
        if a_mid_samples > 0 then _PathArcToFastExXY(self, center.x, center.y, radius, a_min_sample, a_max_sample, arc_step) end
        if a_emit_end        then PathLineToXY(self, center.x + ImCos(a_max) * radius, center.y + ImSin(a_max) * radius) end
    else
        local arc_length = ImAbs(a_max - a_min)
        local circle_segment_count = self:_CalcCircleAutoSegmentCount(radius)
        local arc_segment_count = ImMax(ImCeil(circle_segment_count * arc_length / (IM_PI * 2.0)), 1)

        self:_PathArcToN(center, radius, a_min, a_max, arc_segment_count)
    end
end

-- Note: as with every ImDrawList drawing function, this expects that the font atlas texture is bound.
-- DO NOT CALL DIRECTLY THIS WILL CHANGE WILDLY IN 2026. Use ImDrawList:AddText().
--- @param draw_list   ImDrawList
--- @param size        float
--- @param pos         ImVec2
--- @param col         ImU32
--- @param clip_rect   ImVec4
--- @param text        ImString
--- @param text_begin  int
--- @param text_end    int
--- @param wrap_width? float
--- @param flags?      ImDrawTextFlags
@native
function MT.ImFont:RenderText(draw_list, size, pos, col, clip_rect, text, text_begin, text_end, wrap_width, flags)
    if wrap_width == nil then wrap_width = .0 end
    if flags      == nil then flags      = 0  end

    -- Align to be pixel perfect
    local x = pos.x
    local y = pos.y
    if y > clip_rect.w then
        return
    end
    flags = bit32.bor(flags, draw_list.Flags)
    if bit32.band(flags, ImDrawFlags.TextNoPixelSnap) == 0 then
        x = IM_TRUNC(x)
        y = IM_TRUNC(y)
    end


    local line_height = size
    local baked = self.LastBaked -- [Luau] inline self:GetFontBaked(size) fast path
    if not (baked and baked.Size == math.floor(size + 0.5) and baked.RasterizerDensity == self.CurrentRasterizerDensity) then
        baked = self:GetFontBaked(size)
    end

    local scale = size / baked.Size
    local origin_x = x
    local word_wrap_enabled = (wrap_width > 0.0)

    -- Fast-forward to first visible line
    local s = text_begin
    if y + line_height < clip_rect.y then
        while y + line_height < clip_rect.y and s < text_end do
            local line_end = ImMemchr(text, '\n', s)
            if word_wrap_enabled then
                -- FIXME-OPT: This is not optimal as do first do a search for \n before calling CalcWordWrapPosition().
                -- If the specs for CalcWordWrapPosition() were reworked to optionally return on \n we could combine both.
                -- However it is still better than nothing performing the fast-forward!
                s = ImFontCalcWordWrapPositionEx(self, size, text, s, (line_end ~= nil) and line_end or text_end, wrap_width, flags)
                s = ImTextCalcWordWrapNextLineStart(text, s, text_end, flags)
            else
                s = (line_end ~= nil) and (line_end + 1) or text_end
            end

            y = y + line_height
        end
    end

    -- For large text, scan for the last visible line in order to avoid over-reserving in the call to PrimReserve()
    -- Note that very large horizontal line will still be affected by the issue (e.g. a one megabyte string buffer without a newline will likely crash atm)
    if text_end - s > 1e4 and not word_wrap_enabled then
        local s_end = s
        local y_end = y
        while (y_end < clip_rect.w and s_end < text_end) do
            local _end = ImMemchr(text, '\n', s_end)
            s_end = (_end ~= nil) and (_end + 1) or text_end
            y_end = y_end + line_height
        end

        text_end = s_end
    end

    if s == text_end then
        return
    end

    -- Reserve vertices for remaining worse case (over-reserving is useful and easily amortized)
    local vtx_count_max = (text_end - s) * 4
    local idx_count_max = (text_end - s) * 6
    local idx_expected_size = draw_list.IdxBuffer.Size + idx_count_max
    draw_list:PrimReserve(idx_count_max, vtx_count_max)
    local vtx_write = draw_list._VtxWritePtr
    local idx_write = draw_list._IdxWritePtr
    local vtx_index = draw_list._VtxCurrentIdx
    local cmd_count = draw_list.CmdBuffer.Size
    local cpu_fine_clip = bit32.band(flags, ImDrawTextFlags.CpuFineClip) ~= 0

    local idx_data = draw_list.IdxBuffer.Data; local vtx_data = draw_list.VtxBuffer.Buf

    local color_untinted = bit32.bor(col, bit32.bnot(IM_COL32_A_MASK))

    local word_wrap_eol
    local stop = false
    local text_is_str = type(text) == "string"
    local lookup, lookup_n, glyphs = baked.IndexLookup.Data, baked.IndexLookup.Size, baked.Glyphs.Data

    while s < text_end do
        repeat
        if word_wrap_enabled then
            -- Calculate how far we can render. Requires two passes on the string data but keeps the code simple and not intrusive for what's essentially an uncommon feature.
            if not word_wrap_eol then
                word_wrap_eol = ImFontCalcWordWrapPositionEx(self, size, text, s, text_end, wrap_width - (x - origin_x), flags)
                lookup, lookup_n, glyphs = baked.IndexLookup.Data, baked.IndexLookup.Size, baked.Glyphs.Data -- [Luau] may have loaded glyphs
            end

            if s >= word_wrap_eol then
                x = origin_x
                y = y + line_height
                if y > clip_rect.w then
                    stop = true; break -- break out of main loop
                end
                word_wrap_eol = nil
                s = ImTextCalcWordWrapNextLineStart(text, s, text_end, flags) -- Wrapping skips upcoming blanks

                break
            end
        end

        -- Decode and advance source
        local c
        if text_is_str then c = string.byte(text, s) else c = text[s] end
        if c < 0x80 then
            s = s + 1
        else
            local wanted, out_char = ImStd.ImTextCharFromUtf8(text, s, text_end)
            c = out_char
            s = s + wanted
        end

        if c < 32 then
            if c == 10 then -- '\n'
                x = origin_x
                y = y + line_height
                if y > clip_rect.w then
                    stop = true; break -- break out of main loop
                end

                break
            end

            if c == 13 then -- '\r'
                break
            end
        end

        local glyph
        local gi = (c < lookup_n) and lookup[c + 1] or nil
        if gi ~= nil and gi ~= IM_FONTGLYPH_INDEX_NOT_FOUND and gi ~= IM_FONTGLYPH_INDEX_UNUSED then
            glyph = glyphs[gi]
        else
            glyph = baked:FindGlyph(c) -- [Port] may load the glyph and grow the tables
            lookup, lookup_n, glyphs = baked.IndexLookup.Data, baked.IndexLookup.Size, baked.Glyphs.Data
        end

        local char_width = glyph.AdvanceX * scale
        if glyph.Visible then
            -- We don't do a second finer clipping test on the Y axis as we've already skipped anything before clip_rect.y and exit once we pass clip_rect.w
            local x1 = x + glyph.X0 * scale
            local x2 = x + glyph.X1 * scale
            local y1 = y + glyph.Y0 * scale
            local y2 = y + glyph.Y1 * scale
            if x1 <= clip_rect.z and x2 >= clip_rect.x then
                -- Render a character
                local u1 = glyph.U0
                local v1 = glyph.V0
                local u2 = glyph.U1
                local v2 = glyph.V1

                -- CPU side clipping used to fit text in their frame when the frame is too small. Only does clipping for axis aligned quads.
                if (cpu_fine_clip) then
                    if (x1 < clip_rect.x) then
                        u1 = u1 + (1.0 - (x2 - clip_rect.x) / (x2 - x1)) * (u2 - u1)
                        x1 = clip_rect.x
                    end
                    if (y1 < clip_rect.y) then
                        v1 = v1 + (1.0 - (y2 - clip_rect.y) / (y2 - y1)) * (v2 - v1)
                        y1 = clip_rect.y
                    end
                    if (x2 > clip_rect.z) then
                        u2 = u1 + ((clip_rect.z - x1) / (x2 - x1)) * (u2 - u1)
                        x2 = clip_rect.z
                    end
                    if (y2 > clip_rect.w) then
                        v2 = v1 + ((clip_rect.w - y1) / (y2 - y1)) * (v2 - v1)
                        y2 = clip_rect.w
                    end
                    if (y1 >= y2) then
                        x = x + char_width

                        break
                    end
                end

                -- Support for untinted glyphs
                local glyph_col = glyph.Colored and color_untinted or col

                -- We are NOT calling PrimRectUV() here because non-inlined causes too much overhead in a debug builds. Inlined here:
                do
                    local o = (vtx_write - 1) * 36
                    writef64(vtx_data, o, x1); writef64(vtx_data, o + 8, y1); writef64(vtx_data, o + 16, u1); writef64(vtx_data, o + 24, v1); writeu32(vtx_data, o + 32, glyph_col)
                    writef64(vtx_data, o + 36, x2); writef64(vtx_data, o + 44, y1); writef64(vtx_data, o + 52, u2); writef64(vtx_data, o + 60, v1); writeu32(vtx_data, o + 68, glyph_col)
                    writef64(vtx_data, o + 72, x2); writef64(vtx_data, o + 80, y2); writef64(vtx_data, o + 88, u2); writef64(vtx_data, o + 96, v2); writeu32(vtx_data, o + 104, glyph_col)
                    writef64(vtx_data, o + 108, x1); writef64(vtx_data, o + 116, y2); writef64(vtx_data, o + 124, u1); writef64(vtx_data, o + 132, v2); writeu32(vtx_data, o + 140, glyph_col)
                    idx_data[idx_write + 0] = vtx_index; idx_data[idx_write + 1] = vtx_index + 1; idx_data[idx_write + 2] = vtx_index + 2;
                    idx_data[idx_write + 3] = vtx_index; idx_data[idx_write + 4] = vtx_index + 2; idx_data[idx_write + 5] = vtx_index + 3;
                    vtx_write = vtx_write + 4
                    vtx_index = vtx_index + 4
                    idx_write = idx_write + 6
                end
            end
        end

        x = x + char_width

        until true
        if stop then break end
    end

    -- Edge case: calling RenderText() with unloaded glyphs triggering texture change. It doesn't happen via ImGui.* calls because CalcTextSize() is always used.
    if cmd_count ~= draw_list.CmdBuffer.Size then
        IM_ASSERT(draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size].ElemCount == 0)
        draw_list.CmdBuffer:pop_back()
        draw_list:PrimUnreserve(idx_count_max, vtx_count_max)
        draw_list:AddDrawCmd()

        return self:RenderText(draw_list, size, pos, col, clip_rect, text, text_begin, text_end, wrap_width, flags) -- [Port] was `goto begin`
    end

    -- Give back unused vertices (clipped ones, blanks) ~ this is essentially a PrimUnreserve() action.
    draw_list.VtxBuffer.Size = vtx_write - 1 -- Same as calling shrink()
    draw_list.IdxBuffer.Size = idx_write - 1
    draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size].ElemCount = draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size].ElemCount - (idx_expected_size - draw_list.IdxBuffer.Size)
    draw_list._VtxWritePtr = vtx_write
    draw_list._IdxWritePtr = idx_write
    draw_list._VtxCurrentIdx = vtx_index
end

-------------------------------------------------------------------------------
-- [SECTION] ImGui Internal Render Helpers
-------------------------------------------------------------------------------
-- Vaguely redesigned to stop accessing ImGui global state:
-- - RenderArrow()
-- - RenderBullet()
-- - RenderCheckMark()
-- - RenderArrowPointingAt()
-- - RenderRectFilledInRangeH()
-- - RenderRectFilledWithHole()
-------------------------------------------------------------------------------
-- Function in need of a redesign (legacy mess)
-- - RenderColorRectWithAlphaCheckerboard()
-------------------------------------------------------------------------------

-- Render an arrow aimed to be aligned with text (p_min is a position in the same space text would be positioned). To e.g. denote expanded/collapsed state
--- @param draw_list ImDrawList
--- @param pos       ImVec2
--- @param color     ImU32
--- @param dir       ImGuiDir
--- @param scale?    float
local arrow_a, arrow_b, arrow_c = ImVec2(), ImVec2(), ImVec2() -- [Port] scratch: the path is consumed by AddTriangleFilled before returning

function ImGui.RenderArrow(draw_list, pos, color, dir, scale)
    if scale == nil then scale = 1.0 end

    local h = draw_list._Data.FontSize * 1.00
    local r = h * 0.40 * scale

    local cx, cy = pos.x + h * 0.50, pos.y + h * 0.50 * scale

    local ax, ay, bx, by, qx, qy
    if dir == ImGuiDir.Up or dir == ImGuiDir.Down then
        if dir == ImGuiDir.Up then r = -r end
        ax, ay = 0.000 * r, 0.750 * r
        bx, by = -0.866 * r, -0.750 * r
        qx, qy = 0.866 * r, -0.750 * r
    elseif dir == ImGuiDir.Left or dir == ImGuiDir.Right then
        if dir == ImGuiDir.Left then r = -r end
        ax, ay = 0.750 * r, 0.000 * r
        bx, by = -0.750 * r, 0.866 * r
        qx, qy = -0.750 * r, -0.866 * r
    else
        IM_ASSERT(false)
    end

    arrow_a.x, arrow_a.y = cx + ax, cy + ay
    arrow_b.x, arrow_b.y = cx + bx, cy + by
    arrow_c.x, arrow_c.y = cx + qx, cy + qy
    draw_list:AddTriangleFilled(arrow_a, arrow_b, arrow_c, color)
end

--- @param draw_list ImDrawList
--- @param pos       ImVec2
--- @param col       ImU32
function ImGui.RenderBullet(draw_list, pos, col)
    -- FIXME-OPT: This should be baked in font now that it's easier.
    local font_size = draw_list._Data.FontSize
    draw_list:AddCircleFilled(pos, font_size * 0.20, col, (font_size < 22) and 8 or ((font_size < 40) and 12 or 0)) -- Hardcode optimal/nice tessellation threshold
end

--- @param draw_list ImDrawList
--- @param pos       ImVec2
--- @param col       ImU32
--- @param sz        float
local checkmark_p = ImVec2() -- [Luau] scratch: PathLineTo() copies the point

function ImGui.RenderCheckMark(draw_list, pos, col, sz)
    local thickness = math.max(sz / 5.0, 1.0)
    sz = sz - thickness * 0.5
    local pos_x, pos_y = pos.x + thickness * 0.25, pos.y + thickness * 0.25 -- [Luau] scalar pos

    local third = sz / 3.0
    local bx = pos_x + third
    local by = pos_y + sz - third * 0.5

    local p = checkmark_p
    p.x = bx - third; p.y = by - third
    draw_list:PathLineTo(p)
    p.x = bx; p.y = by
    draw_list:PathLineTo(p)
    p.x = bx + third * 2.0; p.y = by - third * 2.0
    draw_list:PathLineTo(p)
    draw_list:PathStroke(col, thickness, ImDrawFlags.AALineEnds)
end

-- Render an arrow. 'pos' is position of the arrow tip. half_sz.x is length from base to tip. half_sz.y is length on each side.
--- @param draw_list ImDrawList
--- @param pos       ImVec2
--- @param half_sz   ImVec2
--- @param direction ImGuiDir
--- @param col       ImU32
function ImGui.RenderArrowPointingAt(draw_list, pos, half_sz, direction, col)
    if direction == ImGuiDir.Left then
        draw_list:AddTriangleFilled(ImVec2(pos.x + half_sz.x, pos.y - half_sz.y), ImVec2(pos.x + half_sz.x, pos.y + half_sz.y), pos, col)
    elseif direction == ImGuiDir.Right then
        draw_list:AddTriangleFilled(ImVec2(pos.x - half_sz.x, pos.y + half_sz.y), ImVec2(pos.x - half_sz.x, pos.y - half_sz.y), pos, col)
    elseif direction == ImGuiDir.Up then
        draw_list:AddTriangleFilled(ImVec2(pos.x + half_sz.x, pos.y + half_sz.y), ImVec2(pos.x - half_sz.x, pos.y + half_sz.y), pos, col)
    elseif direction == ImGuiDir.Down then
        draw_list:AddTriangleFilled(ImVec2(pos.x - half_sz.x, pos.y - half_sz.y), ImVec2(pos.x + half_sz.x, pos.y - half_sz.y), pos, col)
    elseif direction == ImGuiDir.None or direction == ImGuiDir.COUNT then -- Fix warnings
    end
end

local function ImAcos01(x)
    if x <= 0.0 then return IM_PI * 0.5 end
    if x >= 1.0 then return 0.0 end
    return ImAcos(x)
    --return (-0.69813170079773212 * x * x - 0.87266462599716477) * x + 1.5707963267948966 -- Cheap approximation, may be enough for what we do.
end

-- FIXME: Cleanup and move code to ImDrawList.
-- - Before 2025-12-04: RenderRectFilledRangeH()   with 'float x_start_norm, float x_end_norm` <- normalized
-- - After  2025-12-04: RenderRectFilledInRangeH() with 'float x1, float x2'                   <- absolute coords!!
--- @param draw_list ImDrawList
--- @param rect      ImRect
--- @param col       ImU32
--- @param fill_x0   float
--- @param fill_x1   float
--- @param rounding  float
function ImGui.RenderRectFilledInRangeH(draw_list, rect, col, fill_x0, fill_x1, rounding)
    if fill_x0 > fill_x1 then
        return
    end

    local p0 = ImVec2(fill_x0, rect.Min.y)
    local p1 = ImVec2(fill_x1, rect.Max.y)

    if rounding == 0.0 then
        draw_list:AddRectFilled(p0, p1, col, 0.0)
        return
    end

    rounding = ImClamp(ImMin((rect.Max.x - rect.Min.x) * 0.5, (rect.Max.y - rect.Min.y) * 0.5) - 1.0, 0.0, rounding)
    local inv_rounding = 1.0 / rounding
    local arc0_b = ImAcos01(1.0 - (p0.x - rect.Min.x) * inv_rounding)
    local arc0_e = ImAcos01(1.0 - (p1.x - rect.Min.x) * inv_rounding)
    local half_pi = IM_PI * 0.5 -- We will == compare to this because we know this is the exact value ImAcos01 can return.
    local x0 = ImMax(p0.x, rect.Min.x + rounding)

    if arc0_b == arc0_e then
        draw_list:PathLineTo(ImVec2(x0, p1.y))
        draw_list:PathLineTo(ImVec2(x0, p0.y))
    elseif arc0_b == 0.0 and arc0_e == half_pi then
        draw_list:PathArcToFast(ImVec2(x0, p1.y - rounding), rounding, 3, 6) -- BL
        draw_list:PathArcToFast(ImVec2(x0, p0.y + rounding), rounding, 6, 9) -- TR
    else
        draw_list:PathArcTo(ImVec2(x0, p1.y - rounding), rounding, math.pi - arc0_e, math.pi - arc0_b) -- BL
        draw_list:PathArcTo(ImVec2(x0, p0.y + rounding), rounding, math.pi + arc0_b, math.pi + arc0_e) -- TR
    end

    if p1.x > rect.Min.x + rounding then
        local arc1_b = ImAcos01(1.0 - (rect.Max.x - p1.x) * inv_rounding)
        local arc1_e = ImAcos01(1.0 - (rect.Max.x - p0.x) * inv_rounding)
        local x1 = ImMin(p1.x, rect.Max.x - rounding)

        if arc1_b == arc1_e then
            draw_list:PathLineTo(ImVec2(x1, p0.y))
            draw_list:PathLineTo(ImVec2(x1, p1.y))
        elseif arc1_b == 0.0 and arc1_e == half_pi then
            draw_list:PathArcToFast(ImVec2(x1, p0.y + rounding), rounding, 9, 12) -- TR
            draw_list:PathArcToFast(ImVec2(x1, p1.y - rounding), rounding, 0, 3)  -- BR
        else
            draw_list:PathArcTo(ImVec2(x1, p0.y + rounding), rounding, -arc1_e, -arc1_b) -- TR
            draw_list:PathArcTo(ImVec2(x1, p1.y - rounding), rounding, arc1_b, arc1_e)   -- BR
        end
    end

    draw_list:PathFillConvex(col, ImDrawFlags.JoinMiter)
end

--- @param r_in      ImRect
--- @param r_outer   ImRect
--- @param threshold float
--- @return ImDrawFlags
function ImGui.CalcRoundingFlagsForRectInRect(r_in, r_outer, threshold)
    local round_l = r_in.Min.x <= r_outer.Min.x + threshold
    local round_r = r_in.Max.x >= r_outer.Max.x - threshold
    local round_t = r_in.Min.y <= r_outer.Min.y + threshold
    local round_b = r_in.Max.y >= r_outer.Max.y - threshold

    local flags = ImDrawFlags.RoundNone

    if round_t and round_l then
        flags = bit32.bor(flags, ImDrawFlags.RoundTopLeft)
    end
    if round_t and round_r then
        flags = bit32.bor(flags, ImDrawFlags.RoundTopRight)
    end
    if round_b and round_l then
        flags = bit32.bor(flags, ImDrawFlags.RoundBottomLeft)
    end
    if round_b and round_r then
        flags = bit32.bor(flags, ImDrawFlags.RoundBottomRight)
    end

    return flags
end

-- Helper for ColorPicker4()
-- NB: This is rather brittle and will show artifact when rounding this enabled if rounded corners overlap multiple cells. Caller currently responsible for avoiding that.
-- Spent a non reasonable amount of time trying to getting this right for ColorButton with rounding+anti-aliasing+ImGuiColorEditFlags_HalfAlphaPreview flag + various grid sizes and offsets, and eventually gave up... probably more reasonable to disable rounding altogether.
--- @param draw_list ImDrawList
--- @param p_min     ImVec2
--- @param p_max     ImVec2
--- @param col       ImU32
--- @param alpha     float
--- @param grid_step float
--- @param grid_off  ImVec2
--- @param rounding? float
--- @param flags?    ImDrawFlags
function ImGui.RenderColorRectWithAlphaCheckerboard(draw_list, p_min, p_max, col, alpha, grid_step, grid_off, rounding, flags)
    if rounding == nil then rounding = 0.0 end
    if flags    == nil then flags    = 0   end

    if bit32.band(flags, ImDrawFlags.RoundMask_) == 0 then
        flags = ImDrawFlags.RoundAll
    end

    if bit32.rshift(bit32.band(col, IM_COL32_A_MASK), IM_COL32_A_SHIFT) < 0xFF then
        IM_ASSERT(alpha >= 0.0 and alpha <= 1.0)
        local a_mask = bit32.lshift(ImTrunc(alpha * 255.0), IM_COL32_A_SHIFT)
        local col_bg1 = bit32.bor(bit32.band(ImStd.ImAlphaBlendColors(IM_COL32(128, 128, 128, 255), col), bit32.bnot(IM_COL32_A_MASK)), a_mask)
        local col_bg2 = bit32.bor(bit32.band(ImStd.ImAlphaBlendColors(IM_COL32(204, 204, 204, 255), col), bit32.bnot(IM_COL32_A_MASK)), a_mask)
        local dual_layer = (alpha == 1.0) -- Dual layer is faster but incorrect if blending.
        if dual_layer then
            draw_list:AddRectFilled(p_min, p_max, col_bg1, rounding, flags)
        end

        local yi = 0
        local y = p_min.y + grid_off.y
        while y < p_max.y do
            local y1 = ImClamp(ImTrunc(y), p_min.y, p_max.y)
            local y2 = ImMin(ImTrunc(y + grid_step), p_max.y)
            if y2 > y1 then
                local x_start_off = dual_layer and (((yi + 1) % 2) * grid_step) or 0.0
                local x_step = dual_layer and (grid_step * 2.0) or grid_step
                local xi = 0
                local x = p_min.x + grid_off.x + x_start_off
                while x < p_max.x do
                    local x1 = ImClamp(ImTrunc(x), p_min.x, p_max.x)
                    local x2 = ImMin(ImTrunc(x + grid_step), p_max.x)
                    if x2 > x1 then
                        local cell_flags = ImDrawFlags.RoundNone -- FIXME: Could use CalcRoundingFlagsForRectInRect()
                        if y1 <= p_min.y then
                            if x1 <= p_min.x then cell_flags = bit32.bor(cell_flags, ImDrawFlags.RoundTopLeft) end
                            if x2 >= p_max.x then cell_flags = bit32.bor(cell_flags, ImDrawFlags.RoundTopRight) end
                        end
                        if y2 >= p_max.y then
                            if x1 <= p_min.x then cell_flags = bit32.bor(cell_flags, ImDrawFlags.RoundBottomLeft) end
                            if x2 >= p_max.x then cell_flags = bit32.bor(cell_flags, ImDrawFlags.RoundBottomRight) end
                        end

                        -- Combine flags
                        if flags == ImDrawFlags.RoundNone or cell_flags == ImDrawFlags.RoundNone then
                            cell_flags = ImDrawFlags.RoundNone
                        else
                            cell_flags = bit32.band(cell_flags, flags)
                        end
                        local col_bg
                        if dual_layer then col_bg = col_bg2 elseif (yi + xi) % 2 == 1 then col_bg = col_bg2 else col_bg = col_bg1 end
                        draw_list:AddRectFilled(ImVec2(x1, y1), ImVec2(x2, y2), col_bg, rounding, cell_flags)
                    end
                    x = x + x_step
                    xi = xi + 1
                end
            end
            y = y + grid_step
            yi = yi + 1
        end
    else
        draw_list:AddRectFilled(p_min, p_max, col, rounding, flags)
    end
end



function ImGui.RenderRectFilledWithHole(draw_list, outer, inner, col, rounding)
    local fill_L = inner.Min.x > outer.Min.x
    local fill_R = inner.Max.x < outer.Max.x
    local fill_U = inner.Min.y > outer.Min.y
    local fill_D = inner.Max.y < outer.Max.y
    local D = ImDrawFlags
    local bor = bit32.bor
    local function f(c, v) return c and 0 or v end
    if fill_L then draw_list:AddRectFilled(ImVec2(outer.Min.x, inner.Min.y), ImVec2(inner.Min.x, inner.Max.y), col, rounding, bor(D.RoundNone, f(fill_U, D.RoundTopLeft), f(fill_D, D.RoundBottomLeft))) end
    if fill_R then draw_list:AddRectFilled(ImVec2(inner.Max.x, inner.Min.y), ImVec2(outer.Max.x, inner.Max.y), col, rounding, bor(D.RoundNone, f(fill_U, D.RoundTopRight), f(fill_D, D.RoundBottomRight))) end
    if fill_U then draw_list:AddRectFilled(ImVec2(inner.Min.x, outer.Min.y), ImVec2(inner.Max.x, inner.Min.y), col, rounding, bor(D.RoundNone, f(fill_L, D.RoundTopLeft), f(fill_R, D.RoundTopRight))) end
    if fill_D then draw_list:AddRectFilled(ImVec2(inner.Min.x, inner.Max.y), ImVec2(inner.Max.x, outer.Max.y), col, rounding, bor(D.RoundNone, f(fill_L, D.RoundBottomLeft), f(fill_R, D.RoundBottomRight))) end
    if fill_L and fill_U then draw_list:AddRectFilled(ImVec2(outer.Min.x, outer.Min.y), ImVec2(inner.Min.x, inner.Min.y), col, rounding, D.RoundTopLeft) end
    if fill_R and fill_U then draw_list:AddRectFilled(ImVec2(inner.Max.x, outer.Min.y), ImVec2(outer.Max.x, inner.Min.y), col, rounding, D.RoundTopRight) end
    if fill_L and fill_D then draw_list:AddRectFilled(ImVec2(outer.Min.x, inner.Max.y), ImVec2(inner.Min.x, outer.Max.y), col, rounding, D.RoundBottomLeft) end
    if fill_R and fill_D then draw_list:AddRectFilled(ImVec2(inner.Max.x, inner.Max.y), ImVec2(outer.Max.x, outer.Max.y), col, rounding, D.RoundBottomRight) end
end

-------------------------------------------------------------------------------
-- [Port] Extra path functions (elliptical arc, bezier curves) and concave fill
-------------------------------------------------------------------------------

function MT.ImDrawList:PathEllipticalArcTo(center, radius, rot, a_min, a_max, num_segments)
    if num_segments == nil or num_segments <= 0 then
        num_segments = self:_CalcCircleAutoSegmentCount(ImMax(radius.x, radius.y)) -- A bit pessimistic, maybe there's a better computation to do here.
    end
    local cos_rot, sin_rot = ImCos(rot), ImSin(rot)
    for i = 0, num_segments do
        local a = a_min + (i / num_segments) * (a_max - a_min)
        local px, py = ImCos(a) * radius.x, ImSin(a) * radius.y
        self._Path:push_back(ImVec2(px * cos_rot - py * sin_rot + center.x, px * sin_rot + py * cos_rot + center.y))
    end
end

function ImBezierCubicCalc(p1, p2, p3, p4, t)
    local u = 1.0 - t
    local w1, w2, w3, w4 = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
    return ImVec2(w1 * p1.x + w2 * p2.x + w3 * p3.x + w4 * p4.x, w1 * p1.y + w2 * p2.y + w3 * p3.y + w4 * p4.y)
end

function ImBezierQuadraticCalc(p1, p2, p3, t)
    local u = 1.0 - t
    local w1, w2, w3 = u * u, 2 * u * t, t * t
    return ImVec2(w1 * p1.x + w2 * p2.x + w3 * p3.x, w1 * p1.y + w2 * p2.y + w3 * p3.y)
end

-- Closely mimics ImBezierCubicClosestPointCasteljau() in imgui.cpp
local function PathBezierCubicCurveToCasteljau(path, x1, y1, x2, y2, x3, y3, x4, y4, tess_tol, level)
    local dx, dy = x4 - x1, y4 - y1
    local d2 = math.abs((x2 - x4) * dy - (y2 - y4) * dx)
    local d3 = math.abs((x3 - x4) * dy - (y3 - y4) * dx)
    if (d2 + d3) * (d2 + d3) < tess_tol * (dx * dx + dy * dy) then
        path:push_back(ImVec2(x4, y4))
    elseif level < 10 then
        local x12, y12 = (x1 + x2) * 0.5, (y1 + y2) * 0.5
        local x23, y23 = (x2 + x3) * 0.5, (y2 + y3) * 0.5
        local x34, y34 = (x3 + x4) * 0.5, (y3 + y4) * 0.5
        local x123, y123 = (x12 + x23) * 0.5, (y12 + y23) * 0.5
        local x234, y234 = (x23 + x34) * 0.5, (y23 + y34) * 0.5
        local x1234, y1234 = (x123 + x234) * 0.5, (y123 + y234) * 0.5
        PathBezierCubicCurveToCasteljau(path, x1, y1, x12, y12, x123, y123, x1234, y1234, tess_tol, level + 1)
        PathBezierCubicCurveToCasteljau(path, x1234, y1234, x234, y234, x34, y34, x4, y4, tess_tol, level + 1)
    end
end

local function PathBezierQuadraticCurveToCasteljau(path, x1, y1, x2, y2, x3, y3, tess_tol, level)
    local dx, dy = x3 - x1, y3 - y1
    local det = (x2 - x3) * dy - (y2 - y3) * dx
    if det * det * 4.0 < tess_tol * (dx * dx + dy * dy) then
        path:push_back(ImVec2(x3, y3))
    elseif level < 10 then
        local x12, y12 = (x1 + x2) * 0.5, (y1 + y2) * 0.5
        local x23, y23 = (x2 + x3) * 0.5, (y2 + y3) * 0.5
        local x123, y123 = (x12 + x23) * 0.5, (y12 + y23) * 0.5
        PathBezierQuadraticCurveToCasteljau(path, x1, y1, x12, y12, x123, y123, tess_tol, level + 1)
        PathBezierQuadraticCurveToCasteljau(path, x123, y123, x23, y23, x3, y3, tess_tol, level + 1)
    end
end

function MT.ImDrawList:PathBezierCubicCurveTo(p2, p3, p4, num_segments)
    local p1 = self._Path:back()
    if num_segments == nil or num_segments == 0 then
        IM_ASSERT(self._Data.CurveTessellationMaxError > 0.0)
        local max_error_sqr = (self._Data.CurveTessellationMaxError * self._FringeScale) * (self._Data.CurveTessellationMaxError * self._FringeScale)
        PathBezierCubicCurveToCasteljau(self._Path, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, p4.x, p4.y, max_error_sqr, 0) -- Auto-tessellated
    else
        local t_step = 1.0 / num_segments
        for i_step = 1, num_segments do self._Path:push_back(ImBezierCubicCalc(p1, p2, p3, p4, t_step * i_step)) end
    end
end

function MT.ImDrawList:PathBezierQuadraticCurveTo(p2, p3, num_segments)
    local p1 = self._Path:back()
    if num_segments == nil or num_segments == 0 then
        IM_ASSERT(self._Data.CurveTessellationMaxError > 0.0)
        local max_error_sqr = (self._Data.CurveTessellationMaxError * self._FringeScale) * (self._Data.CurveTessellationMaxError * self._FringeScale)
        PathBezierQuadraticCurveToCasteljau(self._Path, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, max_error_sqr, 0) -- Auto-tessellated
    else
        local t_step = 1.0 / num_segments
        for i_step = 1, num_segments do self._Path:push_back(ImBezierQuadraticCalc(p1, p2, p3, t_step * i_step)) end
    end
end

--------------------------------------------------------------------------------
-- [SECTION] ImTriangulator, ImDrawList concave polygon fill
--------------------------------------------------------------------------------
-- Triangulate concave polygons. Based on "Triangulation by Ear Clipping" paper, O(N^2) complexity.
-- Reference: https://www.geometrictools.com/Documentation/TriangulationByEarClipping.pdf
-- Provided as a convenience for user but not used by main library.
--------------------------------------------------------------------------------
-- - ImTriangulator [Internal]
-- - AddConcavePolyFilled()
--------------------------------------------------------------------------------

local ImTriangulatorNodeType =
{
    Convex = 0,
    Ear    = 1,
    Reflex = 2,
}

-- [Luau] No pointers: a node is an int handle (1-based slot) into the parallel arrays of its ImTriangulator
-- (tri.Type[n], tri.Index[n], tri.Pos[n], tri.Next[n], tri.Prev[n]). node->Index (0-based, as upstream) == n - 1.
local function ImTriangulatorNode_Unlink(tri, n) tri.Prev[tri.Next[n]] = tri.Prev[n]; tri.Next[tri.Prev[n]] = tri.Next[n] end

-- [Luau] Deviation: upstream classifies a node as reflex when '!ImTriangleIsClockwise()', i.e. also when its corner is
-- degenerate (collinear or duplicate points). A duplicate point then sits as a reflex on top of every candidate ear's vertex
-- and blocks it, ending in the degenerate fallback with overlapping triangles. Only strictly counter-clockwise corners are
-- reflex here: degenerate corners are clipped as zero-area ears.
local function ImTriangulator_IsReflex(a, b, c) return ((b.x - a.x) * (c.y - b.y)) - ((c.x - b.x) * (b.y - a.y)) < 0.0 end

local function ImTriangulatorNodeSpan()
    return { Data = {}, Size = 0 } -- [Port] Data: node handles, 1-based
end
MT.ImTriangulatorNodeSpan = {}
MT.ImTriangulatorNodeSpan.__index = MT.ImTriangulatorNodeSpan
function MT.ImTriangulatorNodeSpan:push_back(node) self.Size = self.Size + 1; self.Data[self.Size] = node end
function MT.ImTriangulatorNodeSpan:find_erase_unsorted(idx) for i = self.Size, 1, -1 do if self.Data[i] - 1 == idx then self.Data[i] = self.Data[self.Size]; self.Size = self.Size - 1; return end end end

-- [Luau] The node/ears/reflexes storage (upstream: carved out of _Data->TempBuffer via scratch_buffer) is owned by the
-- triangulator itself and only ever grows. AddConcavePolyFilled() reuses a single module-level instance (no per-call allocations).
local function ImTriangulator()
    return setmetatable({
        _TrianglesLeft = 0,
        _Nodes         = 0, -- [Port] node handle (head of the circular list)
        _Ears          = setmetatable(ImTriangulatorNodeSpan(), MT.ImTriangulatorNodeSpan),
        _Reflexes      = setmetatable(ImTriangulatorNodeSpan(), MT.ImTriangulatorNodeSpan),
        Type = {}, Index = {}, Pos = {}, Next = {}, Prev = {}, -- [Luau] ImTriangulatorNode fields, one array each
    }, MT.ImTriangulator)
end
MT.ImTriangulator = {}
MT.ImTriangulator.__index = MT.ImTriangulator

function MT.ImTriangulator.EstimateTriangleCount(points_count) return (points_count < 3) and 0 or points_count - 2 end
-- [Luau] In elements (nodes + ears + reflexes) rather than bytes. Unused by the port: arrays grow on demand.
function MT.ImTriangulator.EstimateScratchBufferSize(points_count) return points_count + points_count * 2 end

-- Distribute storage for nodes, ears and reflexes.
-- FIXME-OPT: if everything is convex, we could report it to caller and let it switch to an convex renderer
-- (this would require first building reflexes to bail to convex if empty, without even building nodes)
--- @param points ImVec2[] # 1-based
function MT.ImTriangulator:Init(points, points_count)
    IM_ASSERT(points_count >= 3)
    self._TrianglesLeft = MT.ImTriangulator.EstimateTriangleCount(points_count)
    self._Nodes         = 1
    self._Ears.Size     = 0
    self._Reflexes.Size = 0
    self:BuildNodes(points, points_count)

    -- [Luau] Deviation: upstream only flips the node list when no ear is found, so a counter-clockwise *concave* polygon
    -- (whose reflex corners look like ears) yields triangles outside of it. Normalize to clockwise order up-front (O(N)).
    local area2 = 0.0
    local p0 = points[points_count]
    for i = 1, points_count do
        local p1 = points[i]
        area2 = area2 + (p0.x * p1.y - p1.x * p0.y)
        p0 = p1
    end
    if area2 < 0.0 then
        self:FlipNodeList()
    end

    self:BuildReflexes()
    self:BuildEars()
end

function MT.ImTriangulator:BuildNodes(points, points_count)
    local Type, Index, Pos, Next, Prev = self.Type, self.Index, self.Pos, self.Next, self.Prev
    for i = 1, points_count do
        Type[i] = ImTriangulatorNodeType.Convex
        Index[i] = i - 1
        Pos[i] = points[i] -- [Luau] reference, not a copy (points are not modified while triangulating)
        Next[i] = i + 1
        Prev[i] = i - 1
    end
    Prev[1] = points_count
    Next[points_count] = 1
end

function MT.ImTriangulator:BuildReflexes()
    local Pos, Next, Prev = self.Pos, self.Next, self.Prev
    local n1 = self._Nodes
    for _ = self._TrianglesLeft, 0, -1 do
        if ImTriangulator_IsReflex(Pos[Prev[n1]], Pos[n1], Pos[Next[n1]]) then
            self.Type[n1] = ImTriangulatorNodeType.Reflex
            self._Reflexes:push_back(n1)
        end
        n1 = Next[n1]
    end
end

function MT.ImTriangulator:BuildEars()
    local Index, Pos, Next, Prev = self.Index, self.Pos, self.Next, self.Prev
    local n1 = self._Nodes
    for _ = self._TrianglesLeft, 0, -1 do
        if self.Type[n1] == ImTriangulatorNodeType.Convex then
            local n0, n2 = Prev[n1], Next[n1]
            if self:IsEar(Index[n0], Index[n1], Index[n2], Pos[n0], Pos[n1], Pos[n2]) then
                self.Type[n1] = ImTriangulatorNodeType.Ear
                self._Ears:push_back(n1)
            end
        end
        n1 = Next[n1]
    end
end

-- [Luau] out_triangle[3] is returned as 3 values (relative 0-based indexes)
function MT.ImTriangulator:GetNextTriangle()
    if self._Ears.Size == 0 then
        self:FlipNodeList()

        local node = self._Nodes
        for _ = self._TrianglesLeft, 0, -1 do
            self.Type[node] = ImTriangulatorNodeType.Convex
            node = self.Next[node]
        end
        self._Reflexes.Size = 0
        self:BuildReflexes()
        self:BuildEars()

        -- If we still don't have ears, it means geometry is degenerated.
        if self._Ears.Size == 0 then
            -- Return first triangle available, mimicking the behavior of convex fill.
            IM_ASSERT(self._TrianglesLeft > 0) -- Geometry is degenerated
            self._Ears.Data[1] = self._Nodes
            self._Ears.Size    = 1
        end
    end

    local ear = self._Ears.Data[self._Ears.Size]
    self._Ears.Size = self._Ears.Size - 1
    local Index, Next, Prev = self.Index, self.Next, self.Prev
    local t0, t1, t2 = Index[Prev[ear]], Index[ear], Index[Next[ear]]

    ImTriangulatorNode_Unlink(self, ear)
    if ear == self._Nodes then
        self._Nodes = Next[ear]
    end

    self:ReclassifyNode(Prev[ear])
    self:ReclassifyNode(Next[ear])
    self._TrianglesLeft = self._TrianglesLeft - 1
    return t0, t1, t2
end

function MT.ImTriangulator:FlipNodeList()
    local Next, Prev = self.Next, self.Prev
    local nodes = self._Nodes
    local prev = nodes
    local temp = nodes
    local current = Next[nodes]
    Next[prev] = prev
    Prev[prev] = prev
    while current ~= nodes do
        temp = Next[current]

        Next[current] = prev
        Prev[prev] = current
        Next[nodes] = current
        Prev[current] = nodes

        prev = current
        current = temp
    end
    self._Nodes = prev
end

-- A triangle is an ear is no other vertex is inside it. We can test reflexes vertices only (see reference algorithm)
function MT.ImTriangulator:IsEar(i0, i1, i2, v0, v1, v2)
    local Index, Pos = self.Index, self.Pos
    local data = self._Reflexes.Data
    for p = 1, self._Reflexes.Size do
        local reflex = data[p]
        local idx = Index[reflex]
        if idx ~= i0 and idx ~= i1 and idx ~= i2 then
            if ImStd.ImTriangleContainsPoint(v0, v1, v2, Pos[reflex]) then
                return false
            end
        end
    end
    return true
end

function MT.ImTriangulator:ReclassifyNode(n1)
    -- Classify node
    local type
    local n0 = self.Prev[n1]
    local n2 = self.Next[n1]
    local Index, Pos = self.Index, self.Pos
    if ImTriangulator_IsReflex(Pos[n0], Pos[n1], Pos[n2]) then
        type = ImTriangulatorNodeType.Reflex
    elseif self:IsEar(Index[n0], Index[n1], Index[n2], Pos[n0], Pos[n1], Pos[n2]) then
        type = ImTriangulatorNodeType.Ear
    else
        type = ImTriangulatorNodeType.Convex
    end

    -- Update lists when a type changes
    local n1_type = self.Type[n1]
    if type == n1_type then
        return
    end
    if n1_type == ImTriangulatorNodeType.Reflex then
        self._Reflexes:find_erase_unsorted(Index[n1])
    elseif n1_type == ImTriangulatorNodeType.Ear then
        self._Ears:find_erase_unsorted(Index[n1])
    end
    if type == ImTriangulatorNodeType.Reflex then
        self._Reflexes:push_back(n1)
    elseif type == ImTriangulatorNodeType.Ear then
        self._Ears:push_back(n1)
    end
    self.Type[n1] = type
end

local concave_triangulator = ImTriangulator() -- [Luau] reused scratch (see ImTriangulator())

-- Use ear-clipping algorithm to triangulate a simple polygon (no self-interaction, no holes).
-- (Reminder: we don't perform any coarse clipping/culling in ImDrawList layer!
-- It is up to caller to ensure not making costly calls that will be outside of visible area.
-- As concave fill is noticeably more expensive than other primitives, be mindful of this...
-- Caller can build AABB of points, and avoid filling if 'draw_list->_CmdHeader.ClipRect.Overlays(points_bb) == false')
--- @param points ImVec2[] # 1-based
--- @param points_count int
--- @param col ImU32
@native
function MT.ImDrawList:AddConcavePolyFilled(points, points_count, col)
    if points_count < 3 or bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local uv = self._Data.TexUvWhitePixel
    local uv_x, uv_y = uv.x, uv.y
    local triangulator = concave_triangulator
    if bit32.band(self.Flags, ImDrawFlags.AAFill) ~= 0 then
        -- Anti-aliased Fill
        local AA_SIZE = self._FringeScale
        local col_trans = bit32.band(col, bit32.bnot(IM_COL32_A_MASK))
        local idx_count = (points_count - 2) * 3 + points_count * 6
        local vtx_count = (points_count * 2)
        PrimReserve(self, idx_count, vtx_count)
        local vb = self.VtxBuffer.Buf
        local ib = self.IdxBuffer.Data
        local vw = self._VtxWritePtr
        local iw = self._IdxWritePtr

        -- Add indexes for fill
        local vtx_inner_idx = self._VtxCurrentIdx
        local vtx_outer_idx = self._VtxCurrentIdx + 1

        triangulator:Init(points, points_count)
        while triangulator._TrianglesLeft > 0 do
            local t0, t1, t2 = triangulator:GetNextTriangle()
            ib[iw + 0] = vtx_inner_idx + t0 * 2; ib[iw + 1] = vtx_inner_idx + t1 * 2; ib[iw + 2] = vtx_inner_idx + t2 * 2
            iw = iw + 3
        end

        -- Compute normals
        -- [Luau] scratch arrays (see AddPolyline) instead of _Data->TempBuffer. Indexes below are 1-based.
        local temp_normals_x, temp_normals_y = poly_normals_x, poly_normals_y
        local i0 = points_count
        for i1 = 1, points_count do
            local p0 = points[i0]
            local p1 = points[i1]
            local dx, dy = IM_NORMALIZE2F_OVER_ZERO(p1.x - p0.x, p1.y - p0.y)
            temp_normals_x[i0] = dy
            temp_normals_y[i0] = -dx
            i0 = i1
        end

        i0 = points_count
        for i1 = 1, points_count do
            -- Average normals
            local dm_x, dm_y = IM_FIXNORMAL2F((temp_normals_x[i0] + temp_normals_x[i1]) * 0.5, (temp_normals_y[i0] + temp_normals_y[i1]) * 0.5)
            dm_x = dm_x * AA_SIZE * 0.5
            dm_y = dm_y * AA_SIZE * 0.5

            -- Add vertices
            local p1 = points[i1]
            WV(vb, vw, p1.x - dm_x, p1.y - dm_y, uv_x, uv_y, col)           -- Inner
            WV(vb, vw + 1, p1.x + dm_x, p1.y + dm_y, uv_x, uv_y, col_trans) -- Outer
            vw = vw + 2

            -- Add indexes for fringes
            local e0, e1 = (i0 - 1) * 2, (i1 - 1) * 2
            ib[iw + 0] = vtx_inner_idx + e1; ib[iw + 1] = vtx_inner_idx + e0; ib[iw + 2] = vtx_outer_idx + e0
            ib[iw + 3] = vtx_outer_idx + e0; ib[iw + 4] = vtx_outer_idx + e1; ib[iw + 5] = vtx_inner_idx + e1
            iw = iw + 6
            i0 = i1
        end
        self._VtxWritePtr = vw
        self._IdxWritePtr = iw
        self._VtxCurrentIdx = self._VtxCurrentIdx + vtx_count
    else
        -- Non Anti-aliased Fill
        local idx_count = (points_count - 2) * 3
        local vtx_count = points_count
        PrimReserve(self, idx_count, vtx_count)
        local vb = self.VtxBuffer.Buf
        local ib = self.IdxBuffer.Data
        local vw = self._VtxWritePtr
        local iw = self._IdxWritePtr
        for i = 1, vtx_count do
            local p = points[i]
            WV(vb, vw, p.x, p.y, uv_x, uv_y, col)
            vw = vw + 1
        end
        local base_idx = self._VtxCurrentIdx
        triangulator:Init(points, points_count)
        while triangulator._TrianglesLeft > 0 do
            local t0, t1, t2 = triangulator:GetNextTriangle()
            ib[iw + 0] = base_idx + t0; ib[iw + 1] = base_idx + t1; ib[iw + 2] = base_idx + t2
            iw = iw + 3
        end
        self._VtxWritePtr = vw
        self._IdxWritePtr = iw
        self._VtxCurrentIdx = base_idx + vtx_count
    end
end

function MT.ImDrawList:PathFillConcave(col)
    self:AddConcavePolyFilled(self._Path.Data, self._Path.Size, col)
    self._Path.Size = 0
end

-------------------------------------------------------------------------------
-- [SECTION] Decompression code
-------------------------------------------------------------------------------
-- Compressed with stb_compress() then converted to a C array and encoded as base85.
-- Use the program in misc/fonts/binary_to_compressed_c.cpp to create the array from a TTF file.
-- The purpose of encoding as base85 instead of "0x00,0x01,..." style is only save on _source code_ size.
-- Decompression from stb.h (public domain) by Sean Barrett https://github.com/nothings/stb/blob/master/stb.h
-- [Luau] Input and output are buffers, pointers are 0-based byte offsets into them.
-------------------------------------------------------------------------------

do
local readu8 = buffer.readu8
local writeu8 = buffer.writeu8

--- @param input buffer
function stb_decompress_length(input)
    return readu8(input, 8) * 16777216 + readu8(input, 9) * 65536 + readu8(input, 10) * 256 + readu8(input, 11)
end

local stb__barrier_out_e, stb__barrier_out_b
local stb__barrier_in_b
local stb__dout
local stb__out, stb__in -- [Luau] buffers the offsets above point into
local function stb__match(data, length)
    -- INVERSE of memmove... write each byte before copying the next...
    IM_ASSERT(stb__dout + length <= stb__barrier_out_e)
    if stb__dout + length > stb__barrier_out_e then stb__dout = stb__dout + length; return end
    if data < stb__barrier_out_b then stb__dout = stb__barrier_out_e + 1; return end
    if stb__dout - data >= length then -- [Luau] no overlap: block copy
        buffer.copy(stb__out, stb__dout, stb__out, data, length)
        stb__dout = stb__dout + length
        return
    end
    local out = stb__out
    local dout = stb__dout
    for n = 0, length - 1 do writeu8(out, dout + n, readu8(out, data + n)) end
    stb__dout = dout + length
end

local function stb__lit(data, length)
    IM_ASSERT(stb__dout + length <= stb__barrier_out_e)
    if stb__dout + length > stb__barrier_out_e then stb__dout = stb__dout + length; return end
    if data < stb__barrier_in_b then stb__dout = stb__barrier_out_e + 1; return end
    buffer.copy(stb__out, stb__dout, stb__in, data, length)
    stb__dout = stb__dout + length
end

local function stb__in2(i, x) return readu8(stb__in, i + x) * 256 + readu8(stb__in, i + x + 1) end
local function stb__in3(i, x) return readu8(stb__in, i + x) * 65536 + stb__in2(i, x + 1) end
local function stb__in4(i, x) return readu8(stb__in, i + x) * 16777216 + stb__in3(i, x + 1) end

local function stb_decompress_token(i)
    local i0 = readu8(stb__in, i)
    if i0 >= 0x20 then -- use fewer if's for cases that expand small
        if i0 >= 0x80 then       stb__match(stb__dout - readu8(stb__in, i + 1) - 1, i0 - 0x80 + 1); i = i + 2
        elseif i0 >= 0x40 then   stb__match(stb__dout - (stb__in2(i, 0) - 0x4000 + 1), readu8(stb__in, i + 2) + 1); i = i + 3
        else --[[ *i >= 0x20 ]]  stb__lit(i + 1, i0 - 0x20 + 1); i = i + 1 + (i0 - 0x20 + 1)
        end
    else -- more ifs for cases that expand large, since overhead is amortized
        if i0 >= 0x18 then       stb__match(stb__dout - (stb__in3(i, 0) - 0x180000 + 1), readu8(stb__in, i + 3) + 1); i = i + 4
        elseif i0 >= 0x10 then   stb__match(stb__dout - (stb__in3(i, 0) - 0x100000 + 1), stb__in2(i, 3) + 1); i = i + 5
        elseif i0 >= 0x08 then   stb__lit(i + 2, stb__in2(i, 0) - 0x0800 + 1); i = i + 2 + (stb__in2(i, 0) - 0x0800 + 1)
        elseif i0 == 0x07 then   stb__lit(i + 3, stb__in2(i, 1) + 1); i = i + 3 + (stb__in2(i, 1) + 1)
        elseif i0 == 0x06 then   stb__match(stb__dout - (stb__in3(i, 1) + 1), readu8(stb__in, i + 4) + 1); i = i + 5
        elseif i0 == 0x04 then   stb__match(stb__dout - (stb__in3(i, 1) + 1), stb__in2(i, 4) + 1); i = i + 6
        end
    end
    return i
end

--- @param buf    buffer
--- @param buflen int
local function stb_adler32(adler32, buf, buflen)
    local ADLER_MOD = 65521
    local s1 = adler32 % 65536
    local s2 = math.floor(adler32 / 65536)
    local blocklen = buflen % 5552

    local p = 0
    while buflen > 0 do
        for _ = 1, blocklen do
            s1 = s1 + readu8(buf, p); s2 = s2 + s1
            p = p + 1
        end

        s1 = s1 % ADLER_MOD; s2 = s2 % ADLER_MOD
        buflen = buflen - blocklen
        blocklen = 5552
    end
    return s2 * 65536 + s1
end

--- @param output buffer
--- @param i      buffer
function stb_decompress(output, i, length)
    stb__in = i
    if stb__in4(0, 0) ~= 0x57bC0000 then return 0 end
    if stb__in4(0, 4) ~= 0 then return 0 end -- error! stream is > 4GB
    local olen = stb_decompress_length(i)
    stb__barrier_in_b = 0
    stb__barrier_out_e = olen
    stb__barrier_out_b = 0
    stb__out = output
    local p = 16

    stb__dout = 0
    while true do
        local old_p = p
        p = stb_decompress_token(p)
        if p == old_p then
            if readu8(i, p) == 0x05 and readu8(i, p + 1) == 0xfa then
                IM_ASSERT(stb__dout == olen)
                if stb__dout ~= olen then return 0 end
                if stb_adler32(1, output, olen) ~= stb__in4(p, 2) then
                    return 0
                end
                return olen
            else
                IM_ASSERT(false) -- NOTREACHED
                return 0
            end
        end
        IM_ASSERT(stb__dout <= olen)
        if stb__dout > olen then
            return 0
        end
    end
end
end

return true -- [Port] [Roblox] ModuleScripts must return exactly one value
