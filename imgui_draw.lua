--- Dear ImGui WIP
-- (Draw Code)

FONT_ATLAS_DEFAULT_TEX_DATA_W = 122
FONT_ATLAS_DEFAULT_TEX_DATA_H = 27

local IM_DRAWLIST_TEX_LINES_WIDTH_MAX = 32

local writef64, writeu32, readf64, readu32 = buffer.writef64, buffer.writeu32, buffer.readf64, buffer.readu32
-- Write vertex i (1-based) of a VtxBuffer.Buf
local function WV(b, i, x, y, u, v, col)
    local o = (i - 1) * 36
    writef64(b, o, x); writef64(b, o + 8, y); writef64(b, o + 16, u); writef64(b, o + 24, v); writeu32(b, o + 32, col)
end
local function WVP(b, i, p, uv, col) WV(b, i, p.x, p.y, uv.x, uv.y, col) end

local IM_FONTGLYPH_INDEX_UNUSED    = 0xFFFF
local IM_FONTGLYPH_INDEX_NOT_FOUND = 0xFFFE

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
local function write_u32(buf, base, u32)
    buf[base + 0] = bit32.band(u32, 0xFF)
    buf[base + 1] = bit32.band(bit32.rshift(u32, 8), 0xFF)
    buf[base + 2] = bit32.band(bit32.rshift(u32, 16), 0xFF)
    buf[base + 3] = bit32.band(bit32.rshift(u32, 24), 0xFF)
end

--- Original ImGui pixel art!
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

--- @module "imstb_rectpack"
local stbrp = IM_INCLUDE("imstb_rectpack.lua")

--- @module "imstb_truetype"
local stbtt = IM_INCLUDE("imstb_truetype.lua")

---------------------------------------------------------------------------------------
-- [SECTION] STYLE FUNCTIONS
---------------------------------------------------------------------------------------

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
    colors[ImGuiCol.TableBorderStrong]         = ImVec4(0.31, 0.31, 0.35, 1.00)
    colors[ImGuiCol.TableBorderLight]          = ImVec4(0.23, 0.23, 0.25, 1.00)
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
    colors[ImGuiCol.TableBorderStrong]         = ImVec4(0.31, 0.31, 0.45, 1.00)
    colors[ImGuiCol.TableBorderLight]          = ImVec4(0.26, 0.26, 0.28, 1.00)
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
    colors[ImGuiCol.TableBorderStrong]         = ImVec4(0.57, 0.57, 0.64, 1.00)
    colors[ImGuiCol.TableBorderLight]          = ImVec4(0.68, 0.68, 0.74, 1.00)
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

-- Rotate and translate vertices [vert_start_idx, vert_end_idx) (1-based, like _VtxCurrentIdx)
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
local ImFontAtlasBuildUpdateTexDataBasic
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

function MT.ImFontAtlas:Clear()
    IMGUI_DEBUG_LOG_FONT("[font] ImFontAtlas:Clear()")
    local backup_renderer_has_textures = self.RendererHasTextures
    self.RendererHasTextures = false
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
        font.Sources:clear()
        font.Flags = bit32.bor(font.Flags, ImFontFlags.NoLoadGlyphs)
    end
    self.Sources:clear()
end

function MT.ImFontAtlas:ClearTexData()
    IM_ASSERT(not self.Locked, "Cannot modify a locked ImFontAtlas!")
    IM_ASSERT(self.RendererHasTextures == false, "Not supported for dynamic atlases, but you may call Clear().")

    for _, tex in self.TexList:iter() do
        tex:DestroyPixels()
    end
end

function MT.ImFontAtlas:CompactCache()
    ImFontAtlasTextureCompact(self)
end

function MT.ImFontAtlas:ClearFonts()
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

--- @param tex ImTextureData
function ImTextureDataUpdateNewFrame(tex)
    local remove_from_list = false
    if tex.Status == ImTextureStatus.OK then
        tex.Updates:resize(0)
        tex.UpdateRect.x = 65535 tex.UpdateRect.y = 65535
        tex.UpdateRect.w = 0     tex.UpdateRect.h = 0
    end

    if (tex.WantDestroyNextFrame and tex.Status ~= ImTextureStatus.Destroyed and tex.Status ~= ImTextureStatus.WantDestroy) then
        IM_ASSERT(tex.Status == ImTextureStatus.OK or tex.Status == ImTextureStatus.WantCreate or tex.Status == ImTextureStatus.WantUpdates)
        tex.Status = ImTextureStatus.WantDestroy
    end

    if (tex.Status == ImTextureStatus.WantDestroy and tex.TexID == ImTextureID_Invalid and tex.BackendUserData == nil and tex.QueueUserData == nil) then
        tex.Status = ImTextureStatus.Destroyed
    end

    if (tex.Status == ImTextureStatus.Destroyed) then
        IM_ASSERT(tex.TexID == ImTextureID_Invalid and tex.BackendUserData == nil, "Backend set texture Status to Destroyed but did not clear TexID/BackendUserData!")
        IM_ASSERT(tex.QueueUserData == nil, "Texture queue set Status to Destroyed but did not clear QueueUserData!")
        if (tex.WantDestroyNextFrame) then
            remove_from_list = true
        else
            tex.Status = ImTextureStatus.WantCreate
        end
    end

    if (tex.Status == ImTextureStatus.WantDestroy) then
        tex.UnusedFrames = tex.UnusedFrames + 1
    end

    return remove_from_list
end

--- @param atlas                 ImFontAtlas
--- @param frame_count           int
--- @param renderer_has_textures any
function ImFontAtlasUpdateNewFrame(atlas, frame_count, renderer_has_textures)
    IM_ASSERT(atlas.Builder == nil or atlas.Builder.FrameCount < frame_count)
    atlas.RendererHasTextures = renderer_has_textures

    local tex_n = 1
    while tex_n <= atlas.TexList.Size do
        local tex = atlas.TexList.Data[tex_n]

        if (tex.Status == ImTextureStatus.WantCreate and atlas.RendererHasTextures) then
            IM_ASSERT(tex.TexID == ImTextureID_Invalid and tex.BackendUserData == nil, "Backend set texture's TexID/BackendUserData but did not update Status to OK.")
        end

        local remove_from_list = ImTextureDataUpdateNewFrame(tex)

        if remove_from_list then
            IM_ASSERT(atlas.TexData ~= tex)
            tex:DestroyPixels()
            atlas.TexList:erase(tex_n)
            tex_n = tex_n - 1
        end

        tex_n = tex_n + 1
    end

    if (atlas.RendererHasTextures) then
        atlas.TexIsBuilt = true
        if (atlas.Builder == nil) then
            ImFontAtlasBuildMain(atlas)
        end
    end

    if (not atlas.RendererHasTextures) then
        IM_ASSERT_USER_ERROR(atlas.TexIsBuilt, "Backend does not support ImGuiBackendFlags.RendererHasTextures, and font atlas is not built! Update backend OR make sure you called ImGui_ImplXXXX_NewFrame() function for renderer backend, which should call io.Fonts->GetTexDataAsRGBA32() / GetTexDataAsAlpha8().")
    end
    if (atlas.TexIsBuilt and atlas.Builder.PreloadedAllGlyphsRanges) then
        IM_ASSERT_USER_ERROR(atlas.RendererHasTextures == false, "Called ImFontAtlas::Build() before ImGuiBackendFlags.RendererHasTextures got set! With new backends: you don't need to call Build().")
    end

    local builder = atlas.Builder
    builder.FrameCount = frame_count
    for _, font in atlas.Fonts:iter() do
        font.LastBaked = nil
    end

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

                write_u32(dst_pixels, dst_pixels_base, IM_COL32(255, 255, 255, alpha))
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

--- @param data ImFontAtlasPostProcessData
function ImFontAtlasTextureBlockPostProcess(data)
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

    ImFontAtlasPackInit(atlas)
    local old_rects = ImVector()
    local old_index = builder.RectsIndex:copy()
    old_rects:swap(builder.Rects)

    for _, index_entry in builder.RectsIndex:iter() do
        repeat
        if index_entry.IsUsed == false then
            break
        end

        local old_r = old_rects[index_entry.TargetIndex + 1]
        if (old_r.w == 0 and old_r.h == 0) then
            break
        end

        local new_r_id = ImFontAtlasPackAddRect(atlas, old_r.w, old_r.h, index_entry)
        if new_r_id == ImFontAtlasRectId_Invalid then
            IMGUI_DEBUG_LOG_FONT("[font] Texture #%03d: resize failed. Will grow.", new_tex.UniqueID)

            new_tex.WantDestroyNextFrame = true
            builder.Rects:swap(old_rects)
            builder.RectsIndex = old_index
            ImFontAtlasBuildSetTexture(atlas, old_tex)
            ImFontAtlasTextureGrow(atlas, w, h)

            return
        end

        IM_ASSERT(ImFontAtlasRectId_GetIndex(new_r_id) == builder.RectsIndex:index_from_ptr(index_entry))

        local new_r = ImFontAtlasPackGetRect(atlas, new_r_id)
        ImFontAtlasTextureBlockCopy(old_tex, old_r.x, old_r.y, new_tex, new_r.x, new_r.y, new_r.w, new_r.h)

        until true
    end
    IM_ASSERT(old_rects.Size == builder.Rects.Size + builder.RectsDiscardedCount)
    builder.RectsDiscardedCount = 0
    builder.RectsDiscardedSurface = 0

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

    ImFontAtlasBuildUpdateTexData(atlas)

    builder.LockDisableResize = false
    ImFontAtlasUpdateDrawListsSharedData(atlas)
    -- ImFontAtlasDebugWriteTexToDisk(new_tex, "After Pack");
end

function ImFontAtlasTextureGrow(atlas, old_tex_w, old_tex_h)
    local builder = atlas.Builder

    old_tex_w = old_tex_w or -1
    old_tex_h = old_tex_h or -1

    if (old_tex_w == -1) then
        old_tex_w = atlas.TexData.Width
    end
    if (old_tex_h == -1) then
        old_tex_h = atlas.TexData.Height
    end

    IM_ASSERT(ImIsPowerOfTwo(old_tex_w) and ImIsPowerOfTwo(old_tex_h))
    IM_ASSERT(ImIsPowerOfTwo(atlas.TexMinWidth) and ImIsPowerOfTwo(atlas.TexMaxWidth) and ImIsPowerOfTwo(atlas.TexMinHeight) and ImIsPowerOfTwo(atlas.TexMaxHeight))

    local new_tex_w = (old_tex_h <= old_tex_w) and old_tex_w or old_tex_w * 2
    local new_tex_h = (old_tex_h <= old_tex_w) and old_tex_h * 2 or old_tex_h

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
    local builder = atlas.Builder
    ImFontAtlasBuildDiscardBakes(atlas, 2)

    if (builder.RectsDiscardedSurface < builder.RectsPackedSurface * 0.20) then
        ImFontAtlasTextureGrow(atlas)
    else
        ImFontAtlasTextureRepack(atlas, atlas.TexData.Width, atlas.TexData.Height)
    end
end

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
        IM_ASSERT(index_entry.IsUsed == false and index_entry.Generation > 0)
        builder.RectsIndexFreeListStart = index_entry.TargetIndex
    end

    index_entry.TargetIndex = rect_idx
    index_entry.IsUsed = true

    return ImFontAtlasRectId_Make(index_idx, index_entry.Generation)
end

--- @param atlas       ImFontAtlas
--- @param index_entry ImFontAtlasRectEntry
local function ImFontAtlasPackReuseRectEntry(atlas, index_entry)
    IM_ASSERT(index_entry.IsUsed)
    index_entry.TargetIndex = atlas.Builder.Rects.Size - 1
    local index_idx = atlas.Builder.RectsIndex:index_from_ptr(index_entry)
    return ImFontAtlasRectId_Make(index_idx, index_entry.Generation)
end

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
        index_entry.Generation = index_entry.Generation + 1
    end

    local pack_padding = atlas.TexGlyphPadding
    builder.RectsIndexFreeListStart = index_idx
    builder.RectsDiscardedCount = builder.RectsDiscardedCount + 1
    builder.RectsDiscardedSurface = builder.RectsDiscardedSurface + ((rect.w + pack_padding) * (rect.h + pack_padding))
    rect.w = 0 rect.h = 0
end

function ImFontAtlasPackAddRect(atlas, w, h, overwrite_entry)
    IM_ASSERT(w > 0 and w <= 0xFFFF)
    IM_ASSERT(h > 0 and h <= 0xFFFF)

    local builder = atlas.Builder
    local pack_padding = atlas.TexGlyphPadding
    builder.MaxRectSize.x = ImMax(builder.MaxRectSize.x, w)
    builder.MaxRectSize.y = ImMax(builder.MaxRectSize.y, h)

    local r = ImTextureRect(0, 0, w, h)
    for attempts_remaining = 3, 0, -1 do
        local pack_r = stbrp.rect()
        pack_r.w = w + pack_padding
        pack_r.h = h + pack_padding
        stbrp.pack_rects(builder.PackContext, {pack_r}, 1)
        r.x = pack_r.x -- (unsigned short)
        r.y = pack_r.y -- (unsigned short)
        if pack_r.was_packed == 1 then
            break
        end

        if (attempts_remaining == 0 or builder.LockDisableResize) then
            IMGUI_DEBUG_LOG_FONT("[font] Failed packing %dx%d rectangle. Returning fallback.", w, h)

            return ImFontAtlasRectId_Invalid
        end

        ImFontAtlasTextureMakeSpace(atlas)
    end

    builder.MaxRectBounds.x = ImMax(builder.MaxRectBounds.x, r.x + r.w + pack_padding)
    builder.MaxRectBounds.y = ImMax(builder.MaxRectBounds.y, r.y + r.h + pack_padding)
    builder.RectsPackedCount = builder.RectsPackedCount + 1
    builder.RectsPackedSurface = builder.RectsPackedSurface + (w + pack_padding) * (h + pack_padding)

    builder.Rects:push_back(r)
    if (overwrite_entry ~= nil) then
        return ImFontAtlasPackReuseRectEntry(atlas, overwrite_entry)
    else
        return ImFontAtlasPackAllocRectEntry(atlas, builder.Rects.Size - 1)
    end
end

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

-- Need this in Lua since I don't want to include 'stbrp' just for context constructor
-- in ImFontAtlasBuilder def code. The cpp code has 'stbrp_context_opaque' which I don't/can't have here
--- @param atlas ImFontAtlas
local function ImGui_ImplStbTrueType_LoaderInit(atlas)
    atlas.Builder.PackContext = atlas.Builder.PackContext or stbrp.context()
end

local function ImGui_ImplStbTrueType_FontSrcInit(atlas, src)
    -- IM_UNUSED(atlas)

    --- @type ImGui_ImplStbTrueType_FontSrcData?
    local bd_font_data = ImGui_ImplStbTrueType_FontSrcData()
    IM_ASSERT(src.FontLoaderData == nil)

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
        bd_font_data.ScaleFactor = bd_font_data.ScaleFactor * (src.SizePixels / ref_size)
    end
    bd_font_data.ScaleFactor = bd_font_data.ScaleFactor * src.ExtraSizeScale

    return true
end

local function ImGui_ImplStbTrueType_FontSrcDestroy(atlas, src)
    -- IM_UNUSED(atlas)
    src.FontLoaderData = nil
end

local function ImGui_ImplStbTrueType_FontSrcContainsGlyph(atlas, src, codepoint)
    -- IM_UNUSED(atlas)
    local bd_font_data = src.FontLoaderData
    IM_ASSERT(bd_font_data ~= nil)

    local glyph_index = stbtt.FindGlyphIndex(bd_font_data.FontInfo, codepoint)
    return (glyph_index ~= 0)
end

local function ImGui_ImplStbTrueType_FontBakedInit(atlas, src, baked)
    -- IM_UNUSED(atlas)

    local bd_font_data = src.FontLoaderData
    if (src.MergeMode == false) then
        local scale_for_layout = bd_font_data.ScaleFactor * baked.Size / src.ExtraSizeScale
        local unscaled_ascent, unscaled_descent, unscaled_line_gap = stbtt.GetFontVMetrics(bd_font_data.FontInfo)

        baked.Ascent = ImCeil(unscaled_ascent * scale_for_layout)
        baked.Descent = ImFloor(unscaled_descent * scale_for_layout)
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
    local bd_font_data = src.FontLoaderData
    IM_ASSERT(bd_font_data ~= nil)
    local glyph_index = stbtt.FindGlyphIndex(bd_font_data.FontInfo, codepoint)
    if (glyph_index == 0) then
        return false, advance_x
    end

    local oversample_h, oversample_v = ImFontAtlasBuildGetOversampleFactors(src, baked)
    local scale_for_layout = bd_font_data.ScaleFactor * baked.Size
    local rasterizer_density = src.RasterizerDensity * baked.RasterizerDensity
    local scale_for_raster_x = bd_font_data.ScaleFactor * baked.Size * rasterizer_density * oversample_h
    local scale_for_raster_y = bd_font_data.ScaleFactor * baked.Size * rasterizer_density * oversample_v

    local x0, y0, x1, y1 = stbtt.GetGlyphBitmapBoxSubpixel(bd_font_data.FontInfo, glyph_index, scale_for_raster_x, scale_for_raster_y, 0, 0)
    local advance, lsb = stbtt.GetGlyphHMetrics(bd_font_data.FontInfo, glyph_index)

    if (advance_x ~= nil) then
        IM_ASSERT(out_glyph == nil)
        advance_x = advance * scale_for_layout

        return true, advance_x
    end

    out_glyph.Codepoint = codepoint
    out_glyph.AdvanceX = advance * scale_for_layout

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

        x0, y0, x1, y1 = stbtt.GetGlyphBitmapBox(bd_font_data.FontInfo, glyph_index, scale_for_raster_x, scale_for_raster_y)
        local builder = atlas.Builder
        builder.TempBuffer:resize(w * h * 1)
        local bitmap_pixels = builder.TempBuffer.Data
        ImStd.memset(bitmap_pixels, 0, w * h * 1)
        local sub_x, sub_y = stbtt.MakeGlyphBitmapSubpixelPrefilter(bd_font_data.FontInfo, bitmap_pixels, w, h, w,
            scale_for_raster_x, scale_for_raster_y, 0, 0, oversample_h, oversample_v, glyph_index)

        local ref_size = baked.OwnerFont.Sources[1].SizePixels
        local offsets_scale = (ref_size ~= 0.0) and (baked.Size / ref_size) or 1.0
        local font_off_x = ImFloor(src.GlyphOffset.x * offsets_scale + 0.5)
        local font_off_y = ImFloor(src.GlyphOffset.y * offsets_scale + 0.5)
        font_off_x = font_off_x + sub_x
        font_off_y = font_off_y + (sub_y + IM_ROUND(baked.Ascent))
        local recip_h = 1.0 / (oversample_h * rasterizer_density)
        local recip_v = 1.0 / (oversample_v * rasterizer_density)

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
    local space_glyph = baked:FindGlyphNoFallback(32)
    if space_glyph ~= nil then
        space_glyph.Visible = false
    end

    if baked:FindGlyphNoFallback(9) == nil and space_glyph ~= nil then
        local tab_glyph = ImFontGlyph()
        tab_glyph.Codepoint = 9
        tab_glyph.AdvanceX = space_glyph.AdvanceX * IM_TABSIZE
        ImFontAtlasBakedAddFontGlyph(atlas, baked, nil, tab_glyph)
    end
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

    local loader_data_size = 0
    for _, src in font.Sources:iter() do
        local loader = src.FontLoader and src.FontLoader or atlas.FontLoader
        loader_data_size = loader_data_size + loader.FontBakedSrcLoaderDataSize
    end
    -- baked.FontLoaderDatas = (loader_data_size > 0) and IM_ALLOC(loader_data_size) or nil
    -- local loader_data_p = baked->FontLoaderDatas
    for _, src in font.Sources:iter() do
        local loader = src.FontLoader and src.FontLoader or atlas.FontLoader
        if (loader.FontBakedInit) then
            loader.FontBakedInit(atlas, src, baked--[[, loader_data_p--]])
        end
        -- loader_data_p += loader->FontBakedSrcLoaderDataSize
    end

    ImFontAtlasBuildSetupFontBakedBlanks(atlas, baked)
    return baked
end

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

            if (step_n == 0 and baked.RasterizerDensity ~= font_rasterizer_density) then
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

    -- char* loader_data_p = (char*)baked->FontLoaderDatas
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

function ImFontAtlasFontDiscardBakes(atlas, font, unused_frames)
    local builder = atlas.Builder
    if builder then
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

function ImFontAtlasFontInitOutput(atlas, font)
    local ret = true
    for _, src in font.Sources:iter() do
        if not ImFontAtlasFontSourceInit(atlas, src) then
            ret = false
        end
    end
    IM_ASSERT(ret)
    return ret
end

function ImFontAtlasFontDestroyOutput(atlas, font)
    font:ClearOutputData()
    for _, src in font.Sources:iter() do
        local loader = src.FontLoader and src.FontLoader or atlas.FontLoader
        if loader and loader.FontSrcDestroy ~= nil then
            loader.FontSrcDestroy(atlas, src)
        end
    end
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
        font.OwnerAtlas = atlas
        IM_ASSERT(font.Sources[1] == src)
    end
    atlas.TexIsBuilt = false
    ImFontAtlasBuildSetupFontSpecialGlyphs(atlas, font, src)
end

--- @param atlas ImFontAtlas
--- @param src ImFontConfig
function ImFontAtlasFontDestroySourceData(atlas, src)
    -- IM_UNUSED(atlas)

    -- if src.FontDataOwnedByAtlas then
    --     IM_FREE(src.FontData)
    -- end
    src.FontData = nil
    -- if src.GlyphExcludeRanges then
    --     IM_FREE(src.GlyphExcludeRanges)
    -- end
    src.GlyphExcludeRanges = nil
end

--- @param atlas ImFontAtlas
--- @param font ImFont
--- @param src ImFontConfig
function ImFontAtlasBuildSetupFontSpecialGlyphs(atlas, font, src)
    -- IM_UNUSED(atlas)
    IM_ASSERT(font.Sources:contains(src))

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
    local dot_r_id = dot_glyph.PackId
    local dot_r = ImFontAtlasPackGetRect(atlas, dot_r_id)
    local dot_spacing = 1
    local dot_step = (dot_glyph.X1 - dot_glyph.X0) + dot_spacing

    local pack_id = ImFontAtlasPackAddRect(atlas, (dot_r.w * 3 + dot_spacing * 2), dot_r.h)
    local r = ImFontAtlasPackGetRect(atlas, pack_id)

    local glyph = ImFontGlyph()
    glyph.Codepoint = font.EllipsisChar
    glyph.AdvanceX = ImMax(dot_glyph.AdvanceX, dot_glyph.X0 + dot_step * 3.0 - dot_spacing)
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
    baked.FallbackGlyphIndex = baked.Glyphs:index_from_ptr(fallback_glyph) + 1
    baked.FallbackAdvanceX = fallback_glyph.AdvanceX
end

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
    for _, shared_data in atlas.DrawListSharedDatas:iter() do
        local imgui_ctx = shared_data.Context
        if (imgui_ctx) then
            atlas.RendererHasTextures = bit32.band(imgui_ctx.IO.BackendFlags, ImGuiBackendFlags.RendererHasTextures) ~= 0

            break
        end
    end
end

local function ImFontAtlasBuildUpdatePointers(atlas)
    -- for _, font in atlas.Fonts:iter() do
    --     font.Sources:resize(0)
    -- end
    -- for _, src in atlas.Sources:iter() do
    --     src.DstFont.Sources:push_back(src)
    -- end
end

--- @param atlas   ImFontAtlas
--- @param old_tex ImTextureRef
--- @param new_tex ImTextureRef
local function ImFontAtlasUpdateDrawListsTextures(atlas, old_tex, new_tex)
    for _, shared_data in atlas.DrawListSharedDatas:iter() do
        repeat
        if (shared_data.Context and not shared_data.Context.WithinFrameScope) then
            break
        end

        for _, draw_list in shared_data.DrawLists:iter() do
            if (draw_list.CmdBuffer.Size > 0 and draw_list._CmdHeader.TexRef == old_tex) then
                draw_list:_SetTexture(new_tex)
            end

            for i, stacked_tex in draw_list._TextureStack:iter() do
                if (stacked_tex == old_tex) then
                    draw_list._TextureStack.Data[i] = new_tex
                end
            end
        end

        until true
    end
end

function ImFontAtlasBuildSetTexture(atlas, tex)
    local old_tex_ref = atlas.TexRef
    atlas.TexData = tex
    atlas.TexUvScale = ImVec2(1.0 / tex.Width, 1.0 / tex.Height)
    atlas.TexRef._TexData = tex
    -- atlas->TexRef._TexID = tex->TexID; <-- We intentionally don't do that. It would be misleading and betray promise that both fields aren't set.
    ImFontAtlasUpdateDrawListsTextures(atlas, old_tex_ref, atlas.TexRef)
end

--- @param atlas ImFontAtlas
function ImFontAtlasBuildUpdateTexData(atlas)
    ImFontAtlasBuildUpdateTexDataLines(atlas)
    ImFontAtlasBuildUpdateTexDataBasic(atlas)
end

function ImFontAtlasTextureAdd(atlas, w, h)
    local old_tex = atlas.TexData
    local new_tex

    -- FIXME: Cannot reuse texture because old UV may have been used already (unless we remap UV).
    new_tex = ImTextureData()
    new_tex.UniqueID = atlas.TexNextUniqueID
    atlas.TexNextUniqueID = atlas.TexNextUniqueID + 1
    atlas.TexList:push_back(new_tex)

    if old_tex ~= nil then
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
    local surface_approx = builder.RectsPackedSurface - builder.RectsDiscardedSurface
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
function ImFontAtlasBuildUpdateTexDataLines(atlas)
    if bit32.band(atlas.Flags, ImFontAtlasFlags.NoBakedLines) ~= 0 then
        return
    end

    local tex = atlas.TexData
    local builder = atlas.Builder

    local r = ImFontAtlasRect()
    local add_and_draw = (atlas:GetCustomRect(builder.PackIdLinesTexData, r) == false)
    if add_and_draw then
        local pack_size = ImVec2(IM_DRAWLIST_TEX_LINES_WIDTH_MAX + 2, IM_DRAWLIST_TEX_LINES_WIDTH_MAX + 1) -- ImVec2i
        builder.PackIdLinesTexData = atlas:AddCustomRect(pack_size.x, pack_size.y, r)
        IM_ASSERT(builder.PackIdLinesTexData ~= ImFontAtlasRectId_Invalid)
    end

    for n = 0, IM_DRAWLIST_TEX_LINES_WIDTH_MAX do
        local y = n
        local line_width = n

        --- @type int # If not floored, will cause black and purple horizontal stripes appearing on the right of the arrow(triangle) in the upper-left most area of the atlas
        local pad_left = math.floor((r.w - line_width) / 2)
        --- @type int
        local pad_right = r.w - (pad_left + line_width)

        IM_ASSERT(pad_left + line_width + pad_right == r.w and y < r.h)

        if (add_and_draw and tex.Format == ImTextureFormat.Alpha8) then
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
        elseif (add_and_draw and tex.Format == ImTextureFormat.RGBA32) then
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

        local uv0 = ImVec2(r.x + pad_left - 1, r.y + y) * atlas.TexUvScale
        local uv1 = ImVec2(r.x + pad_left + line_width + 1, r.y + y + 1) * atlas.TexUvScale
        local half_v = (uv0.y + uv1.y) * 0.5
        atlas.TexUvLines[n] = ImVec4(uv0.x, half_v, uv1.x, half_v)
    end
end

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
    local builder = atlas.Builder
    local pack_size = (bit32.band(atlas.Flags, ImFontAtlasFlags.NoMouseCursors) ~= 0) and ImVec2(2, 2) or ImVec2(FONT_ATLAS_DEFAULT_TEX_DATA_W * 2 + 1, FONT_ATLAS_DEFAULT_TEX_DATA_H)

    local r = ImFontAtlasRect()
    local add_and_draw = (atlas:GetCustomRect(builder.PackIdMouseCursors, r) == false)
    if (add_and_draw) then
        builder.PackIdMouseCursors = atlas:AddCustomRect(pack_size.x, pack_size.y, r)
        IM_ASSERT(builder.PackIdMouseCursors ~= ImFontAtlasRectId_Invalid)

        if bit32.band(atlas.Flags, ImFontAtlasFlags.NoMouseCursors) ~= 0 then
            ImFontAtlasBuildRenderBitmapFromString(atlas, r.x, r.y, 2, 2, {"X", "X", "X", "X"}, "X")
        else
            local x_for_white = r.x
            local x_for_black = r.x + FONT_ATLAS_DEFAULT_TEX_DATA_W + 1
            ImFontAtlasBuildRenderBitmapFromString(atlas, x_for_white, r.y, FONT_ATLAS_DEFAULT_TEX_DATA_W, FONT_ATLAS_DEFAULT_TEX_DATA_H, FONT_ATLAS_DEFAULT_TEX_DATA_PIXELS, ".")
            ImFontAtlasBuildRenderBitmapFromString(atlas, x_for_black, r.y, FONT_ATLAS_DEFAULT_TEX_DATA_W, FONT_ATLAS_DEFAULT_TEX_DATA_H, FONT_ATLAS_DEFAULT_TEX_DATA_PIXELS, "X")
        end
    end

    atlas.TexUvWhitePixel = ImVec2((r.x + 0.5) * atlas.TexUvScale.x, (r.y + 0.5) * atlas.TexUvScale.y)
end

function ImFontAtlasUpdateDrawListsSharedData(atlas)
    for _, shared_data in atlas.DrawListSharedDatas:iter() do
        if (shared_data.FontAtlas == atlas) then
            shared_data.TexUvWhitePixel = atlas.TexUvWhitePixel
            shared_data.TexUvLines = atlas.TexUvLines
        end
    end
end

function ImFontAtlasBuildInit(atlas)
    if atlas.FontLoader == nil then
        -- IMGUI_ENABLE_STB_TRUETYPE
        atlas:SetFontLoader(ImFontAtlasGetFontLoaderForStbTruetype())
    end

    if atlas.TexData == nil or atlas.TexData.Pixels == nil then
        ImFontAtlasTextureAdd(atlas, ImUpperPowerOfTwo(atlas.TexMinWidth), ImUpperPowerOfTwo(atlas.TexMinHeight))
    end
    atlas.Builder = ImFontAtlasBuilder()
    if atlas.FontLoader.LoaderInit then
        atlas.FontLoader.LoaderInit(atlas)
    end

    ImFontAtlasBuildUpdateRendererHasTexturesFromContext(atlas)

    ImFontAtlasPackInit(atlas)

    ImFontAtlasBuildUpdateTexData(atlas)

    ImFontAtlasBuildUpdatePointers(atlas)

    ImFontAtlasUpdateDrawListsSharedData(atlas)

    ImTextInitClassifiers()
end

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
            if old_font == nil and ctx.Font == nil and ctx.FontSizeBase == 0.0 then
                -- While this should work either way, we save ourselves the bother / debugging confusion of running ImGui code so early when it is not needed.
                -- Also fixes erroneously rewriting style.FontSizeBase during init if adding default fonts.

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
    -- ImFontAtlasBuildUpdateRendererHasTexturesFromContext(atlas);
    -- if atlas.RendererHasTextures == false then
    --     ImFontAtlasBuildLegacyPreloadAllGlyphRanges(atlas)
    -- end

    atlas.TexIsBuilt = true
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
    self.Pixels = {}
    ImStd.memset(self.Pixels, 0, self.Width * self.Height * self.BytesPerPixel)
    self.UsedRect.x = 0
    self.UsedRect.y = 0
    self.UsedRect.w = 0
    self.UsedRect.h = 0
    self.UpdateRect.x = 65535
    self.UpdateRect.y = 65535
    self.UpdateRect.w = 0
    self.UpdateRect.h = 0
end

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

--- @param c ImWchar
--- @return ImFontGlyph?
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

--- @param c ImWchar
--- @return ImFontGlyph?
function MT.ImFontBaked:FindGlyphNoFallback(c)
    if c < self.IndexLookup.Size then -- IM_LIKELY
        local i = self.IndexLookup.Data[c + 1]
        if i == IM_FONTGLYPH_INDEX_NOT_FOUND then
            return nil
        end
        if i ~= IM_FONTGLYPH_INDEX_UNUSED then
            return self.Glyphs.Data[i]
        end
    end

    self.LoadNoFallback = true
    local glyph = ImFontBaked_BuildLoadGlyph(self, c, nil)
    self.LoadNoFallback = false
    return glyph
end

function MT.ImFont:ClearOutputData()
    local atlas = self.OwnerAtlas
    if atlas ~= nil then
        ImFontAtlasFontDiscardBakes(atlas, self, 0)
    end

    for i = 1, (IM_UNICODE_CODEPOINT_MAX + 1) / 8192 / 8 do self.Used8kPagesMap[i] = 0 end
    self.LastBaked = nil
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
    IM_ASSERT(font_size > 0.0 and font_rasterizer_density > 0.0)
    local baked_id = ImFontAtlasBakedGetId(font.FontId, font_size, font_rasterizer_density)
    local builder = atlas.Builder
    local baked = builder.BakedMap[baked_id]
    if baked ~= nil then
        IM_ASSERT(baked.Size == font_size and baked.OwnerFont == font and baked.BakedId == baked_id)

        return baked
    end

    if (bit32.band(font.Flags, ImFontFlags.LockBakedSizes) ~= 0 or atlas.Locked) then
        baked = ImFontAtlasBakedGetClosestMatch(atlas, font, font_size, font_rasterizer_density)
        if baked ~= nil then
            return baked
        end
        if atlas.Locked then
            IM_ASSERT(not atlas.Locked, "Cannot use dynamic font size with a locked ImFontAtlas!")
            return nil
        end
    end

    baked = ImFontAtlasBakedAdd(atlas, font, font_size, font_rasterizer_density, baked_id)
    builder.BakedMap[baked_id] = baked

    return baked
end

--- @param atlas    ImFontAtlas
--- @param baked    ImFontBaked
--- @param src?     ImFontConfig
--- @param in_glyph ImFontGlyph
--- @return ImFontGlyph
function ImFontAtlasBakedAddFontGlyph(atlas, baked, src, in_glyph)
    local glyph_idx = baked.Glyphs.Size + 1
    baked.Glyphs:push_back(in_glyph)
    local glyph = baked.Glyphs.Data[glyph_idx]
    IM_ASSERT(baked.Glyphs.Size < 0xFFFE)

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
        local ref_size = baked.OwnerFont.Sources[1].SizePixels
        local offsets_scale = (ref_size ~= 0.0) and (baked.Size / ref_size) or 1.0
        local advance_x = ImClamp(glyph.AdvanceX, src.GlyphMinAdvanceX * offsets_scale, src.GlyphMaxAdvanceX * offsets_scale)
        if (advance_x ~= glyph.AdvanceX) then
            local char_off_x = src.PixelSnapH and ImTrunc((advance_x - glyph.AdvanceX) * 0.5) or (advance_x - glyph.AdvanceX) * 0.5
            glyph.X0 = glyph.X0 + char_off_x
            glyph.X1 = glyph.X1 + char_off_x
        end

        if (src.PixelSnapH) then
            advance_x = IM_ROUND(advance_x)
        end

        glyph.AdvanceX = advance_x + src.GlyphExtraAdvanceX
    end
    if (glyph.Colored) then
        atlas.TexData.UseColors  = true
        atlas.TexPixelsUseColors = true
    end

    local codepoint = glyph.Codepoint
    ImFontBaked_BuildGrowIndex(baked, codepoint + 1)
    baked.IndexAdvanceX.Data[codepoint + 1] = glyph.AdvanceX
    baked.IndexLookup.Data[codepoint + 1] = glyph_idx -- (ImU16)
    local page_n = math.floor(codepoint / 8192)
    baked.OwnerFont.Used8kPagesMap[bit32.rshift(page_n, 3) + 1] = bit32.bor(baked.OwnerFont.Used8kPagesMap[bit32.rshift(page_n, 3) + 1], bit32.lshift(1, bit32.band(page_n, 7)))

    return glyph
end

--- @param atlas     ImFontAtlas
--- @param baked     ImFontBaked
--- @param src?      ImFontConfig
--- @param codepoint ImWchar
--- @param advance_x float
function ImFontAtlasBakedAddFontGlyphAdvancedX(atlas, baked, src, codepoint, advance_x)
    -- IM_UNUSED(atlas)
    if (src ~= nil) then
        local ref_size = baked.OwnerFont.Sources[1].SizePixels
        local offsets_scale = (ref_size ~= 0.0) and (baked.Size / ref_size) or 1.0
        advance_x = ImClamp(advance_x, src.GlyphMinAdvanceX * offsets_scale, src.GlyphMaxAdvanceX * offsets_scale)

        if (src.PixelSnapH) then
            advance_x = IM_ROUND(advance_x)
        end

        advance_x = advance_x + src.GlyphExtraAdvanceX
    end

    ImFontBaked_BuildGrowIndex(baked, codepoint + 1)
    baked.IndexAdvanceX.Data[codepoint + 1] = advance_x
end

--- @param size    float
--- @param density float?
--- @return ImFontBaked?
function MT.ImFont:GetFontBaked(size, density)
    if not density then density = -1.0 end

    --- @type ImFontBaked?
    local baked = self.LastBaked

    size = ImGui.GetRoundedFontSize(size)

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

--- @param atlas ImFontAtlas
--- @param font  ImFont
--- @param c     ImWchar
--- @return ImWchar
--- @nodiscard
local function ImFontAtlas_FontHookRemapCodepoint(atlas, font, c)
    -- IM_UNUSED(atlas)
    if #font.RemapPairs > 0 then
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
        if baked.FallbackGlyphIndex == -1 and baked.LoadNoFallback == false then
            ImFontAtlasBuildSetupFontBakedFallback(baked)
        end

        return nil, only_load_advance_x
    end

    local src_codepoint = codepoint
    codepoint = ImFontAtlas_FontHookRemapCodepoint(atlas, font, codepoint)

    if (codepoint == font.EllipsisChar and font.EllipsisAutoBake) then
        local glyph = ImFontAtlasBuildSetupFontBakedEllipsis(atlas, baked)
        if (glyph) then
            return glyph, only_load_advance_x
        end
    end

    local loader_user_data_p = baked.FontLoaderDatas
    local src_n = 1
    for _, src in font.Sources:iter() do
        local loader = src.FontLoader and src.FontLoader or atlas.FontLoader

        if (not src.GlyphExcludeRanges or ImFontAtlasBuildAcceptCodepointForSource(src, codepoint)) then
            if only_load_advance_x == nil then
                local glyph_buf = ImFontGlyph()

                if loader.FontBakedLoadGlyph(atlas, src, baked, loader_user_data_p, codepoint, glyph_buf, nil) then
                    glyph_buf.Codepoint = src_codepoint
                    glyph_buf.SourceIdx = src_n

                    return ImFontAtlasBakedAddFontGlyph(atlas, baked, src, glyph_buf)
                end
            else
                local ret --[[@as bool]]
                ret, only_load_advance_x = loader.FontBakedLoadGlyph(atlas, src, baked, loader_user_data_p, codepoint, nil, only_load_advance_x)
                if ret then
                    --- @cast only_load_advance_x float
                    ImFontAtlasBakedAddFontGlyphAdvancedX(atlas, baked, src, codepoint, only_load_advance_x)

                    return nil, only_load_advance_x
                end
            end
        end

        -- loader_user_data_p = loader_user_data_p + loader.FontBakedSrcLoaderDataSize
        src_n = src_n + 1
    end

    if (baked.LoadNoFallback) then
        return nil, only_load_advance_x
    end
    if (baked.FallbackGlyphIndex == -1) then
        ImFontAtlasBuildSetupFontBakedFallback(baked)
    end

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

--- @param c ImWchar
--- @return float
function MT.ImFontBaked:GetCharAdvance(c)
    if c < self.IndexAdvanceX.Size then
        local x = self.IndexAdvanceX.Data[c + 1]
        if x >= 0.0 then
            return x
        end
    end
    return ImFontBaked_BuildLoadGlyphAdvanceX(self, c)
end

function BuildLoadGlyphGetAdvanceOrFallback(baked, codepoint)
    return ImFontBaked_BuildLoadGlyphAdvanceX(baked, codepoint)
end

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
    -- IM_UNUSED(codepoint_end)
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

local g_CharClassifierIsSeparator_0000_007f = {} for i = 1, 128 / 16 do g_CharClassifierIsSeparator_0000_007f[i] = 0 end
local g_CharClassifierIsSeparator_3000_300f = {} for i = 1, 16 / 16 do g_CharClassifierIsSeparator_3000_300f[i] = 0 end

function ImTextInitClassifiers()
    if (ImTextClassifierGet(g_CharClassifierIsSeparator_0000_007f, 44) ~= 0) then
        return
    end

    ImTextClassifierClear(g_CharClassifierIsSeparator_0000_007f, 0, 128, ImWcharClass.Other)
    ImTextClassifierSetCharClassFromStr(g_CharClassifierIsSeparator_0000_007f, 0, 128, ImWcharClass.Blank, " \t")
    ImTextClassifierSetCharClassFromStr(g_CharClassifierIsSeparator_0000_007f, 0, 128, ImWcharClass.Punct, ".,;!?\"")

    ImTextClassifierClear(g_CharClassifierIsSeparator_3000_300f, 0x3000, 0x300F, ImWcharClass.Other)
    ImTextClassifierSetCharClass(g_CharClassifierIsSeparator_3000_300f, 0x3000, 0x300F, ImWcharClass.Blank, 0x3000)
    ImTextClassifierSetCharClass(g_CharClassifierIsSeparator_3000_300f, 0x3000, 0x300F, ImWcharClass.Punct, 0x3001)
    ImTextClassifierSetCharClass(g_CharClassifierIsSeparator_3000_300f, 0x3000, 0x300F, ImWcharClass.Punct, 0x3002)
end

--- @param font       ImFont
--- @param size       float
--- @param text       ImString
--- @param pos        int
--- @param text_end   int
--- @param wrap_width float
--- @param flags      ImDrawTextFlags
--- @return int
function ImFontCalcWordWrapPositionEx(font, size, text, pos, text_end, wrap_width, flags)
    local baked = font:GetFontBaked(size)
    local scale = size / baked.Size

    local line_width = 0.0
    local blank_width = 0.0
    wrap_width = wrap_width / scale

    local s = pos
    IM_ASSERT(text_end ~= nil)

    local prev_type = ImWcharClass.Other
    local keep_blanks = bit32.band(flags, ImDrawTextFlags.WrapKeepBlanks) ~= 0

    local span_end = s
    local span_width = 0.0

    local stop = false
    while s < text_end do
        repeat
        --- @type unsigned_int
        local c = ImStrByte(text, s)
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
                return s
            end
            if c == 13 then -- '\r'
                s = next_s

                break
            end
        end

        local char_width = (c < baked.IndexAdvanceX.Size) and baked.IndexAdvanceX.Data[c + 1] or -1.0
        if char_width < 0.0 then
            char_width = BuildLoadGlyphGetAdvanceOrFallback(baked, c)
        end

        local curr_type
        if c < 128 then
            curr_type = ImTextClassifierGet(g_CharClassifierIsSeparator_0000_007f, c)
        elseif (c >= 0x3000 and c < 0x3010) then
            curr_type = ImTextClassifierGet(g_CharClassifierIsSeparator_3000_300f, bit32.band(c, 15))
        else
            curr_type = ImWcharClass.Other
        end

        if curr_type == ImWcharClass.Blank then
            if (prev_type ~= ImWcharClass.Blank and not keep_blanks) then
                span_end = s
                line_width = line_width + span_width
                span_width = 0.0
            end

            blank_width = blank_width + char_width
        else
            if (prev_type == ImWcharClass.Punct and curr_type ~= ImWcharClass.Punct and not (c >= 48 and c <= 57)) then
                span_end = s
                line_width = line_width + (span_width + blank_width)
                blank_width = 0.0
                span_width = 0.0
            elseif (prev_type == ImWcharClass.Blank and keep_blanks) then
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

            return span_end
        end

        prev_type = curr_type
        s = next_s

        until true
        if stop then break end
    end

    if s == pos and s < text_end then
        local bytes = ImStd.ImTextCountUtf8BytesFromChar(text, s, text_end)

        return s + bytes
    end

    return s
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
function ImFontCalcTextSizeEx(font, size, max_width, wrap_width, text, text_begin, text_end_display, text_end, out_offset, flags)
    -- [Luau] cache for the common case (whole string, single pass, no wrap/limit): per baked font, text -> unscaled width, line count.
    -- Advances of a baked font never change once loaded, so entries stay valid. ponytail: whole-cache reset at TEXT_SIZE_CACHE_MAX entries, LRU if dynamic text churns it
    local cache_key = nil
    if text_begin == 1 and out_offset == nil and wrap_width <= 0.0 and max_width >= FLT_MAX and type(text) == "string"
        and (text_end == nil or text_end == #text + 1) and (text_end_display == nil or text_end_display == #text + 1) and (flags == nil or bit32.band(flags, ImDrawTextFlags.StopOnNewLine) == 0) then
        local baked = font:GetFontBaked(size)
        local cache = baked._TextSizeCache
        if cache == nil or baked._TextSizeCacheN >= TEXT_SIZE_CACHE_MAX then
            cache = {}; baked._TextSizeCache = cache; baked._TextSizeCacheN = 0
        end
        local e = cache[text]
        if e then
            return ImVec2(e[1] * (size / baked.Size), e[2] * size), #text + 1
        end
        cache_key = text
    end
    if not text_end then
        text_end = #text + 1
    end
    if not text_end_display then
        text_end_display = text_end
    end

    local baked = font:GetFontBaked(size)
    local line_height = size
    local scale = line_height / baked.Size

    local text_size = ImVec2()
    local line_width = 0.0

    local word_wrap_enabled = (wrap_width > 0.0)
    local word_wrap_eol

    local s = text_begin
    local stop = false
    while s < text_end_display do
        repeat
        if word_wrap_enabled then
            if not word_wrap_eol then
                word_wrap_eol = ImFontCalcWordWrapPositionEx(font, size, text, s, text_end, wrap_width - line_width, flags)
            end

            if s >= word_wrap_eol then
                if text_size.x < line_width then
                    text_size.x = line_width
                end
                text_size.y = text_size.y + line_height
                line_width = 0.0
                s = ImTextCalcWordWrapNextLineStart(text, s, text_end, flags)
                if bit32.band(flags, ImDrawTextFlags.StopOnNewLine) ~= 0 then
                    stop = true; break
                end
                word_wrap_eol = nil

                break
            end
        end

        local prev_s = s
        local c = ImStrByte(text, s)
        if c < 0x80 then
            s = s + 1
        else
            local wanted, out_char = ImStd.ImTextCharFromUtf8(text, s, text_end)
            c = out_char
            s = s + wanted
        end

        if c == 10 then -- '\n'
            text_size.x = ImMax(text_size.x, line_width)
            text_size.y = text_size.y + line_height
            line_width = 0.0
            if bit32.band(flags, ImDrawTextFlags.StopOnNewLine) ~= 0 then
                stop = true; break
            end

            break
        end

        if c == 13 then -- '\r'
            break
        end

        local char_width = (c < baked.IndexAdvanceX.Size) and baked.IndexAdvanceX.Data[c + 1] or -1.0
        if (char_width < 0.0) then
            char_width = BuildLoadGlyphGetAdvanceOrFallback(baked, c)
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

    if (text_size.x < line_width) then
        text_size.x = line_width
    end

    if out_offset then
        out_offset.x = line_width
        out_offset.y = text_size.y + line_height
    end

    if (line_width > 0 or text_size.y == 0.0) then
        text_size.y = text_size.y + line_height
    end

    local out_remaining = s

    if cache_key then
        baked._TextSizeCache[cache_key] = { text_size.x / scale, text_size.y / line_height }
        baked._TextSizeCacheN += 1
    end

    return text_size, out_remaining
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
    if bit32.band(draw_list.Flags, ImDrawListFlags.TextNoPixelSnap) == 0 then
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
    draw_list:PrimRectUV(ImVec2(x1, y1), ImVec2(x2, y2), ImVec2(u1, v1), ImVec2(u2, v2), col)
end

function MT.ImFontAtlas:AddFont(font_cfg_in)
    IM_ASSERT(not self.Locked, "Cannot modify a locked ImFontAtlas!")
    IM_ASSERT((font_cfg_in.FontData ~= nil and font_cfg_in.FontDataSize > 0) or (font_cfg_in.FontLoader ~= nil))
    IM_ASSERT(font_cfg_in.SizePixels > 0.0, "Is ImFontConfig struct correctly initialized?")
    IM_ASSERT(font_cfg_in.RasterizerDensity > 0.0, "Is ImFontConfig struct correctly initialized?")

    if font_cfg_in.GlyphOffset.x ~= 0.0 or font_cfg_in.GlyphOffset.y ~= 0.0 or
        font_cfg_in.GlyphMinAdvanceX ~= 0.0 or font_cfg_in.GlyphMaxAdvanceX ~= FLT_MAX then
        IM_ASSERT(font_cfg_in.SizePixels ~= 0.0,
            "Specifying glyph offset/advances requires a reference size to base it on.")
    end

    if self.Builder == nil then
        ImFontAtlasBuildInit(self)
    end

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
        IM_ASSERT(self.Fonts.Size > 0, "Cannot use MergeMode for the first font!")
        font = (font_cfg_in.DstFont ~= nil) and font_cfg_in.DstFont or self.Fonts:back()
        ImFontAtlasFontDiscardBakes(self, font, 0)
    end

    self.Sources:push_back(font_cfg_in)
    local font_cfg = self.Sources:back()
    if (font_cfg.DstFont == nil) then
        font_cfg.DstFont = font
    end
    font.Sources:push_back(font_cfg)
    ImFontAtlasBuildUpdatePointers(self)

    if font_cfg.GlyphExcludeRanges ~= nil then
        local size = 0
        for _, v in ipairs(font_cfg.GlyphExcludeRanges) do if v == 0 then break end size = size + 1 end
        IM_ASSERT(bit32.band(size, 1) == 0, "GlyphExcludeRanges[] size must be multiple of two!")
        IM_ASSERT(size <= 64, "GlyphExcludeRanges[] size must be small!")
    end

    if font_cfg.FontLoader ~= nil then
        IM_ASSERT(font_cfg.FontLoader.FontBakedLoadGlyph ~= nil)
        IM_ASSERT(font_cfg.FontLoader.LoaderInit == nil and font_cfg.FontLoader.LoaderShutdown == nil)
    end
    if font_cfg_in.MergeMode and font_cfg_in.SizePixels > 0 then
        IM_ASSERT(bit32.band(font.Flags, ImFontFlags.ImplicitRefSize) == 0, "Cannot use MergeMode with an explicit reference size when the destination font used an implicit reference size!")
    end
    IM_ASSERT(font_cfg.FontLoaderData == nil)

    if not ImFontAtlasFontSourceInit(self, font_cfg) then
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

--- @param ctx ImGuiContext
--- @return float
local function GetExpectedContextFontSize(ctx)
    return ((ctx.Style.FontSizeBase > 0.0) and ctx.Style.FontSizeBase or 13.0) * ctx.Style.FontScaleMain * ctx.Style.FontScaleDpi
end

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
    IM_ASSERT(font_data_size > 100, "Incorrect value for font_data_size!")
    font_cfg.FontData = font_data
    font_cfg.FontDataSize = font_data_size
    font_cfg.SizePixels = (size_pixels > 0.0) and size_pixels or font_cfg.SizePixels
    if glyph_ranges then
        font_cfg.GlyphRanges = glyph_ranges
    end
    return self:AddFont(font_cfg)
end

-- TODO: GetDefaultCompressedFontDataProggyClean, GetDefaultCompressedFontDataProggyForever
function MT.ImFontAtlas:AddFontFromMemoryCompressedTTF()
    -- TODO:
end

function MT.ImFontAtlas:AddFontFromFileTTF(filename, size_pixels, font_cfg_template, glyph_ranges)
    IM_ASSERT(not self.Locked, "Cannot modify a locked ImFontAtlas!")

    local data, data_size = ImStd.ImFileLoadToMemory(filename, "rb")
    if not data then
        if (font_cfg_template == nil or (bit32.band(font_cfg_template.Flags, ImFontFlags.NoLoadError) == 0)) then
            -- IMGUI_DEBUG_LOG("While loading '%s'\n", filename)
            IM_ASSERT_USER_ERROR(0, "Could not load font file!")
        end

        return nil
    end

    local font_cfg = font_cfg_template and font_cfg_template or ImFontConfig()
    if not font_cfg.Name or font_cfg.Name == "" then
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
--- @param font_cfg_template ImFontConfig
function MT.ImFontAtlas:AddFontDefaultBitmap(font_cfg_template)
    local font_cfg = font_cfg_template and font_cfg_template or ImFontConfig()
    if not font_cfg_template then
        font_cfg.PixelSnapH = true
    end
    if font_cfg.SizePixels <= 0.0 then
        font_cfg.SizePixels = 13.0
        font_cfg.Flags = bit32.bor(font_cfg.Flags, ImFontFlags.ImplicitRefSize)
    end
    if not font_cfg.Name or font_cfg.Name == "" then
        font_cfg.Name = "ProggyClean.ttf"
    end
    font_cfg.EllipsisChar = 0x0085
    font_cfg.GlyphOffset.y = font_cfg.GlyphOffset.y +  1.0 * (font_cfg.SizePixels / 13.0)

    local ttf_data, ttf_data_size = GetDefaultFontDataProggyClean()
    return self:AddFontFromMemoryTTF(ttf_data, ttf_data_size, font_cfg.SizePixels, font_cfg)
end

--- @param font_cfg_template ImFontConfig
function MT.ImFontAtlas:AddFontDefaultVector(font_cfg_template)
    local font_cfg = font_cfg_template and font_cfg_template or ImFontConfig()
    if not font_cfg_template then
        font_cfg.PixelSnapH = true
    end
    if font_cfg.SizePixels <= 0.0 then
        font_cfg.SizePixels = 13.0
        font_cfg.Flags = bit32.bor(font_cfg.Flags, ImFontFlags.ImplicitRefSize)
    end
    if not font_cfg.Name or font_cfg.Name == "" then
        font_cfg.Name = "ProggyForever.ttf"
    end
    font_cfg.ExtraSizeScale = font_cfg.ExtraSizeScale * 1.015
    font_cfg.GlyphOffset.y = font_cfg.GlyphOffset.y + 0.5 * (font_cfg.SizePixels / 16.0)

    local ttf_data, ttf_data_size = GetDefaultFontDataProggyForever()
    return self:AddFontFromMemoryTTF(ttf_data, ttf_data_size, font_cfg.SizePixels, font_cfg)
end

function MT.ImFontAtlas:GetCustomRect(id, out_r)
    local r = ImFontAtlasPackGetRectSafe(self, id)
    if r == nil then
        return false
    end
    IM_ASSERT(self.TexData.Width > 0 and self.TexData.Height > 0)
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
    local IM_FIXNORMAL2F_MAX_INVLEN2 = 100

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

function MT.ImDrawData:Clear()
    self.Valid = false
    self.FrameCount = 0; self.TotalIdxCount = 0; self.TotalVtxCount = 0
    self.CmdLists:resize(0)
    self.DisplayPos       = ImVec2(0.0, 0.0)
    self.DisplaySize      = ImVec2(0.0, 0.0)
    self.FramebufferScale = ImVec2(0.0, 0.0)
    self.OwnerViewport    = nil
    self.Textures         = nil
end

function ImGui.AddDrawListToDrawDataEx(draw_data, out_list, draw_list)
    if draw_list.CmdBuffer.Size == 0 then
        return
    end
    if draw_list.CmdBuffer.Size == 1 and draw_list.CmdBuffer.Data[1].ElemCount == 0 and draw_list.CmdBuffer.Data[1].UserCallback == nil then
        return
    end

    IM_ASSERT(draw_list.VtxBuffer.Size == 0 or draw_list._VtxWritePtr == draw_list.VtxBuffer.Size + 1)
    IM_ASSERT(draw_list.IdxBuffer.Size == 0 or draw_list._IdxWritePtr == draw_list.IdxBuffer.Size + 1)
    if (bit32.band(draw_list.Flags, ImDrawListFlags.AllowVtxOffset) == 0) then
        IM_ASSERT(draw_list._VtxCurrentIdx == draw_list.VtxBuffer.Size + 1)
    end

    out_list:push_back(draw_list)
    draw_data.TotalVtxCount = draw_data.TotalVtxCount + draw_list.VtxBuffer.Size
    draw_data.TotalIdxCount = draw_data.TotalIdxCount + draw_list.IdxBuffer.Size
end

function MT.ImDrawData:AddDrawList(draw_list)
    draw_list:_PopUnusedDrawCmd()
    ImGui.AddDrawListToDrawDataEx(self, self.CmdLists, draw_list)
end

local IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MIN = 4
local IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MAX = 512

local function IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC(_RAD, _MAXERROR) return ImClamp(IM_ROUNDUP_TO_EVEN(ImCeil(IM_PI / ImAcos(1 - ImMin(_MAXERROR, _RAD) / _RAD))), IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MIN, IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MAX) end
local function IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC_R(_N, _MAXERROR) return (_MAXERROR / (1 - ImCos(IM_PI / ImMax(_N, IM_PI)))) end
local function IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC_ERROR(_N, _RAD)  return ((1 - ImCos(IM_PI / ImMax(_N, IM_PI))) / _RAD) end

function MT.ImDrawListSharedData:SetCircleTessellationMaxError(max_error)
    if self.CircleTessellationMaxError == max_error then
        return
    end

    IM_ASSERT(max_error > 0)

    self.CircleTessellationMaxError = max_error
    for i = 1, 64 do -- IM_COUNTOF(CircleSegmentCounts)
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

-- TODO:
function MT.ImDrawList:_ResetForNewFrame()
    self._ContentClipX0 = nil -- set again by Begin() (Roblox backend scroll reuse)
    if self._Splitter._Count > 1 then
        self._Splitter:Merge(self)
    end
    self._Splitter._Current = 0 -- [Lua] recover from an error thrown mid-split
    self._Splitter._Count = 1

    self.CmdBuffer:resize(0)
    self.IdxBuffer:resize(0)
    self.VtxBuffer:resize(0)
    self.Flags = self._Data.InitialFlags

    self._CmdHeader = ImDrawCmdHeader() -- memset(&_CmdHeader, 0, sizeof(_CmdHeader))

    self._VtxCurrentIdx = 1
    self._VtxWritePtr = 1
    self._IdxWritePtr = 1
    self._ClipRectStack:resize(0)
    self._TextureStack:resize(0)
    self._Path:resize(0)

    self.CmdBuffer:push_back(ImDrawCmd())

    self._FringeScale = self._Data.InitialFringeScale
end

function MT.ImDrawList:_ClearFreeMemory()
    self.CmdBuffer:clear()
    self.IdxBuffer:clear()
    self.VtxBuffer:clear()

    self.Flags = ImDrawListFlags.None

    self._VtxCurrentIdx = 1
    self._VtxWritePtr = 1
    self._IdxWritePtr = 1

    self._ClipRectStack:clear()
    self._TextureStack:clear()
    -- self._CallbacksDataBuf:clear()
    self._Path:clear()
    self._Splitter:ClearFreeMemory()
end

function MT.ImDrawList:AddDrawCmd()
    local draw_cmd = ImDrawCmd()

    ImVec4_Copy(draw_cmd.ClipRect, self._CmdHeader.ClipRect) -- Same as calling ImDrawCmd_HeaderCopy()?
    draw_cmd.TexRef = self._CmdHeader.TexRef
    draw_cmd.VtxOffset = self._CmdHeader.VtxOffset
    draw_cmd.IdxOffset = self.IdxBuffer.Size

    IM_ASSERT(draw_cmd.ClipRect.x <= draw_cmd.ClipRect.z and draw_cmd.ClipRect.y <= draw_cmd.ClipRect.w)
    self.CmdBuffer:push_back(draw_cmd)
end

function MT.ImDrawList:_PopUnusedDrawCmd()
    while self.CmdBuffer.Size > 0 do
        local curr_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
        if curr_cmd.ElemCount ~= 0 or curr_cmd.UserCallback ~= nil then
            break
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
    -- TODO: _CallbacksDataBuf?
    if userdata_size == 0 then
        curr_cmd.UserCallbackData = userdata

    else
        IM_ASSERT(userdata ~= nil)
        IM_ASSERT(userdata_size < bit32.lshift(1, 31))

    end

    self:AddDrawCmd()
end

--- Compare ClipRect, TexRef, VtxOffset
--- @param CMD_LHS ImDrawCmd|ImDrawCmdHeader
--- @param CMD_RHS ImDrawCmd|ImDrawCmdHeader
--- @return bool
local function ImDrawCmd_HeaderCompare(CMD_LHS, CMD_RHS)
    if CMD_LHS.ClipRect.x ~= CMD_RHS.ClipRect.x or
        CMD_LHS.ClipRect.y ~= CMD_RHS.ClipRect.y or
        CMD_LHS.ClipRect.z ~= CMD_RHS.ClipRect.z or
        CMD_LHS.ClipRect.w ~= CMD_RHS.ClipRect.w then
        return false
    end

    if CMD_LHS.TexRef._TexData ~= CMD_RHS.TexRef._TexData or
        CMD_LHS.TexRef._TexID ~= CMD_RHS.TexRef._TexID then
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

function MT.ImDrawList:_TryMergeDrawCmds()
    IM_ASSERT_PARANOID(self.CmdBuffer.Size > 0)
    local curr_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    local prev_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size - 1]
    if ImDrawCmd_HeaderCompare(curr_cmd, prev_cmd) and ImDrawCmd_AreSequentialIdxOffset(prev_cmd, curr_cmd) and curr_cmd.UserCallback == nil and prev_cmd.UserCallback == nil then
        prev_cmd.ElemCount = prev_cmd.ElemCount + curr_cmd.ElemCount
        self.CmdBuffer:pop_back()
    end
end

function MT.ImDrawList:_OnChangedClipRect()
    IM_ASSERT_PARANOID(self.CmdBuffer.Size > 0)
    local curr_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    if (curr_cmd.ElemCount ~= 0 and self._CmdHeader.ClipRect ~= curr_cmd.ClipRect) then
        self:AddDrawCmd()

        return
    end

    IM_ASSERT(curr_cmd.UserCallback == nil)

    local prev_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size - 1]
    if (curr_cmd.ElemCount == 0 and self.CmdBuffer.Size > 1 and ImDrawCmd_HeaderCompare(self._CmdHeader, prev_cmd) and ImDrawCmd_AreSequentialIdxOffset(prev_cmd, curr_cmd) and prev_cmd.UserCallback == nil) then
        self.CmdBuffer:pop_back()

        return
    end

    ImVec4_Copy(curr_cmd.ClipRect, self._CmdHeader.ClipRect)
end

function MT.ImDrawList:_OnChangedTexture()
    IM_ASSERT_PARANOID(self.CmdBuffer.Size > 0)
    local curr_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    if curr_cmd.ElemCount ~= 0 and curr_cmd.TexRef ~= self._CmdHeader.TexRef then
        self:AddDrawCmd()

        return
    end

    if curr_cmd.UserCallback ~= nil then
        return
    end

    local prev_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size - 1]
    if curr_cmd.ElemCount == 0 and self.CmdBuffer.Size > 1 and ImDrawCmd_HeaderCompare(self._CmdHeader, prev_cmd) and ImDrawCmd_AreSequentialIdxOffset(prev_cmd, curr_cmd) and prev_cmd.UserCallback == nil then
        self.CmdBuffer:pop_back()

        return
    end

    curr_cmd.TexRef = self._CmdHeader.TexRef
end

function MT.ImDrawList:_OnChangedVtxOffset()
    self._VtxCurrentIdx = 1
    IM_ASSERT_PARANOID(self.CmdBuffer.Size > 0)

    local curr_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    if curr_cmd.ElemCount ~= 0 then
        self:AddDrawCmd()
        return
    end
    IM_ASSERT(curr_cmd.UserCallback == nil)
    curr_cmd.VtxOffset = self._CmdHeader.VtxOffset
end

----------------------------------------------------------------
-- [SECTION] ImDrawListSplitter
----------------------------------------------------------------
-- Lua: channels swap ImVector objects with the draw list (C++ memcpy of the vector headers).
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
        self._Channels:reserve(channels_count)
        self._Channels:resize(channels_count)
    end
    self._Count = channels_count

    -- Channel 0 is the draw list itself (memset to 0 in C++)
    local channels = self._Channels.Data
    channels[1] = { _CmdBuffer = nil, _IdxBuffer = nil }
    for i = 2, channels_count do
        if i > old_channels_count or channels[i] == nil then
            channels[i] = ImDrawChannel()
        else
            channels[i]._CmdBuffer:resize(0)
            channels[i]._IdxBuffer:resize(0)
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
                cmds:erase(1) -- FIXME-OPT: Improve for multiple merges.
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
        local src_cmds = ch._CmdBuffer.Data
        for n = 1, ch._CmdBuffer.Size do
            dst_cmds[cmd_write] = src_cmds[n]
            src_cmds[n] = nil -- ownership moved to the draw list
            cmd_write = cmd_write + 1
        end
        local src_idx = ch._IdxBuffer.Data
        for n = 1, ch._IdxBuffer.Size do
            dst_idx[idx_write] = src_idx[n]
            idx_write = idx_write + 1
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
    draw_list.CmdBuffer = ch._CmdBuffer
    draw_list.IdxBuffer = ch._IdxBuffer
    draw_list._IdxWritePtr = draw_list.IdxBuffer.Size + 1

    -- If current command is used with different settings we need to add a new command
    local curr_cmd = nil
    if draw_list.CmdBuffer.Size > 0 then curr_cmd = draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size] end
    if curr_cmd == nil then
        draw_list:AddDrawCmd()
    elseif curr_cmd.ElemCount == 0 then
        ImDrawCmd_HeaderCopyRef(curr_cmd, draw_list._CmdHeader) -- Copy ClipRect, TexRef, VtxOffset
    elseif not ImDrawCmd_HeaderCompare(curr_cmd, draw_list._CmdHeader) then
        draw_list:AddDrawCmd()
    end
end

--- @param count int
function MT.ImDrawList:ChannelsSplit(count) self._Splitter:Split(self, count) end
function MT.ImDrawList:ChannelsMerge() self._Splitter:Merge(self) end
--- @param n int # 0-based
function MT.ImDrawList:ChannelsSetCurrent(n) self._Splitter:SetCurrentChannel(self, n) end

--- @param points       ImVec2[]
--- @param points_count int
--- @param col          ImU32
@native
function MT.ImDrawList:AddConvexPolyFilled(points, points_count, col)
    if points_count < 3 or bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local uv = self._Data.TexUvWhitePixel

    if bit32.band(self.Flags, ImDrawListFlags.AntiAliasedFill) ~= 0 then
        local AA_SIZE = self._FringeScale
        local col_trans = bit32.band(col, bit32.bnot(IM_COL32_A_MASK))
        local idx_count = (points_count - 2) * 3 + points_count * 6
        local vtx_count = points_count * 2
        self:PrimReserve(idx_count, vtx_count)

        local vtx_inner_idx = self._VtxCurrentIdx
        local vtx_outer_idx = self._VtxCurrentIdx + 1
        local idx_data = self.IdxBuffer.Data
        for i = 2, points_count - 1 do
            local idx_write_ptr = self._IdxWritePtr
            idx_data[idx_write_ptr + 0] = vtx_inner_idx; idx_data[idx_write_ptr + 1] = vtx_inner_idx + ((i - 1) * 2); idx_data[idx_write_ptr + 2] = vtx_inner_idx + (i * 2)
            self._IdxWritePtr = idx_write_ptr + 3
        end

        self._Data.TempBuffer:reserve_discard(points_count)
        local temp_normals = self._Data.TempBuffer.Data

        local i0 = points_count
        for i1 = 1, points_count do
            local p0 = points[i0]
            local p1 = points[i1]
            local dx = p1.x - p0.x
            local dy = p1.y - p0.y
            dx, dy = IM_NORMALIZE2F_OVER_ZERO(dx, dy)
            temp_normals[i0].x = dy
            temp_normals[i0].y = -dx

            i0 = i1
        end

        local vtx_data = self.VtxBuffer.Buf
        i0 = points_count
        for i1 = 1, points_count do
            local n0 = temp_normals[i0]
            local n1 = temp_normals[i1]
            local dm_x = (n0.x + n1.x) * 0.5
            local dm_y = (n0.y + n1.y) * 0.5
            dm_x, dm_y = IM_FIXNORMAL2F(dm_x, dm_y)
            dm_x = dm_x * AA_SIZE * 0.5
            dm_y = dm_y * AA_SIZE * 0.5

            local vtx_write_ptr = self._VtxWritePtr
            WV(vtx_data, vtx_write_ptr + 0, points[i1].x - dm_x, points[i1].y - dm_y, uv.x, uv.y, col)
            WV(vtx_data, vtx_write_ptr + 1, points[i1].x + dm_x, points[i1].y + dm_y, uv.x, uv.y, col_trans)
            self._VtxWritePtr = vtx_write_ptr + 2

            local idx_write_ptr = self._IdxWritePtr
            idx_data[idx_write_ptr + 0] = vtx_inner_idx + ((i1 - 1) * 2); idx_data[idx_write_ptr + 1] = vtx_inner_idx + ((i0 - 1) * 2); idx_data[idx_write_ptr + 2] = vtx_outer_idx + ((i0 - 1) * 2)
            idx_data[idx_write_ptr + 3] = vtx_outer_idx + ((i0 - 1) * 2); idx_data[idx_write_ptr + 4] = vtx_outer_idx + ((i1 - 1) * 2); idx_data[idx_write_ptr + 5] = vtx_inner_idx + ((i1 - 1) * 2)
            self._IdxWritePtr = idx_write_ptr + 6

            i0 = i1
        end
        self._VtxCurrentIdx = self._VtxCurrentIdx + vtx_count
    else
        local idx_count = (points_count - 2) * 3
        local vtx_count = points_count
        self:PrimReserve(idx_count, vtx_count)

        local idx_data = self.IdxBuffer.Data; local vtx_data = self.VtxBuffer.Buf
        for i = 1, vtx_count do
            local vtx_write_ptr = self._VtxWritePtr
            WVP(vtx_data, vtx_write_ptr + 0, points[i], uv, col)
            self._VtxWritePtr = vtx_write_ptr + 1
        end
        for i = 3, points_count do
            local idx_write_ptr = self._IdxWritePtr
            idx_data[idx_write_ptr + 0] = self._VtxCurrentIdx; idx_data[idx_write_ptr + 1] = self._VtxCurrentIdx + i - 2; idx_data[idx_write_ptr + 2] = self._VtxCurrentIdx + i - 1
            self._IdxWritePtr = idx_write_ptr + 3
        end

        self._VtxCurrentIdx = self._VtxCurrentIdx + vtx_count
    end
end

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

function MT.ImDrawList:_SetTexture(tex_ref)
    if (self._CmdHeader.TexRef == tex_ref) then
        return
    end
    self._CmdHeader.TexRef = tex_ref
    self._TextureStack.Data[self._TextureStack.Size] = tex_ref
    self:_OnChangedTexture()
end

@native
function MT.ImDrawList:PrimReserve(idx_count, vtx_count)
    IM_ASSERT_PARANOID(idx_count >= 0 and vtx_count >= 0)

    if (self._VtxCurrentIdx + vtx_count >= bit32.lshift(1, 16)) and (bit32.band(self.Flags, ImDrawListFlags.AllowVtxOffset) ~= 0) then
        self._CmdHeader.VtxOffset = self.VtxBuffer.Size + 1
        self:_OnChangedVtxOffset()
    end

    local draw_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    draw_cmd.ElemCount = draw_cmd.ElemCount + idx_count

    local vtx_buffer_old_size = self.VtxBuffer.Size
    self.VtxBuffer:resize(vtx_buffer_old_size + vtx_count)
    self._VtxWritePtr = vtx_buffer_old_size + 1

    local idx_buffer_old_size = self.IdxBuffer.Size
    self.IdxBuffer:resize(idx_buffer_old_size + idx_count)
    self._IdxWritePtr = idx_buffer_old_size + 1
end

function MT.ImDrawList:PrimUnreserve(idx_count, vtx_count)
    IM_ASSERT_PARANOID(idx_count >= 0 and vtx_count >= 0)

    local draw_cmd = self.CmdBuffer.Data[self.CmdBuffer.Size]
    draw_cmd.ElemCount = draw_cmd.ElemCount - idx_count

    self.VtxBuffer:shrink(self.VtxBuffer.Size - vtx_count)
    self.IdxBuffer:shrink(self.IdxBuffer.Size - idx_count)

    self._VtxWritePtr = self.VtxBuffer.Size + 1
    self._IdxWritePtr = self.IdxBuffer.Size + 1
end

--- @param a   ImVec2
--- @param c   ImVec2
--- @param col ImU32
@native
function MT.ImDrawList:PrimRect(a, c, col)
    local uv = self._Data.TexUvWhitePixel

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
    local ax, ay, cx, cy, u, v = a.x, a.y, c.x, c.y, uv.x, uv.y
    WV(vtx_data, vtx_write_ptr + 0, ax, ay, u, v, col)
    WV(vtx_data, vtx_write_ptr + 1, cx, ay, u, v, col)
    WV(vtx_data, vtx_write_ptr + 2, cx, cy, u, v, col)
    WV(vtx_data, vtx_write_ptr + 3, ax, cy, u, v, col)

    self._VtxWritePtr = vtx_write_ptr + 4
    self._VtxCurrentIdx = idx + 4
    self._IdxWritePtr = idx_write_ptr + 6
end

--- @param a    ImVec2
--- @param c    ImVec2
--- @param uv_a ImVec2
--- @param uv_c ImVec2
--- @param col  any
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

--- @param points       ImVec2[]
--- @param points_count int
--- @param col          ImU32
--- @param thickness    float
--- @param flags?       ImDrawFlags
@native
function MT.ImDrawList:AddPolyline(points, points_count, col, thickness, flags)
    if flags == nil then flags = 0 end

    if points_count < 2 or bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    local closed = bit32.band(flags, ImDrawFlags.Closed) ~= 0
    local opaque_uv = self._Data.TexUvWhitePixel
    local count = closed and points_count or points_count - 1 -- Number of line segments
    local thick_line = thickness > self._FringeScale
    IM_ASSERT_USER_ERROR_RET(bit32.band(flags, ImDrawFlags.InvalidMask_) == 0, "Incorrect parameter. Did you swap 'thickness' and 'flags'?")

    if bit32.band(self.Flags, ImDrawListFlags.AntiAliasedLines) ~= 0 then
        -- Anti-aliased stroke
        local AA_SIZE = self._FringeScale
        local col_trans = bit32.band(col, bit32.bnot(IM_COL32_A_MASK))

        -- Thicknesses <1.0 should behave like thickness 1.0
        thickness = ImMax(thickness, 1.0)
        local integer_thickness = ImFloor(thickness)
        local fractional_thickness = thickness - integer_thickness

        -- Do we want to draw this line using a texture?
        local use_texture = bit32.band(self.Flags, ImDrawListFlags.AntiAliasedLinesUseTex) ~= 0 and integer_thickness < IM_DRAWLIST_TEX_LINES_WIDTH_MAX and fractional_thickness <= 0.00001 and AA_SIZE == 1.0

        IM_ASSERT_PARANOID((not use_texture) or bit32.band(self._Data.Font.OwnerAtlas.Flags, ImFontAtlasFlags.NoBakedLines) == 0)

        local idx_count = use_texture and (count * 6) or (thick_line and count * 18 or count * 12)
        local vtx_count = use_texture and (points_count * 2) or (thick_line and points_count * 4 or points_count * 3)
        self:PrimReserve(idx_count, vtx_count)

        -- Temporary buffer
        local temp_buffer_size = points_count * ((use_texture or not thick_line) and 3 or 5)
        self._Data.TempBuffer:reserve_discard(temp_buffer_size)
        local temp_normals = self._Data.TempBuffer.Data
        local temp_points = self._Data.TempBuffer.Data; local temp_points_start = points_count + 1

        -- Calculate normals for each line segment
        for i1 = 1, count do
            local i2 = (i1 == points_count) and 1 or i1 + 1
            local p1 = points[i1]
            local p2 = points[i2]
            local dx = p2.x - p1.x
            local dy = p2.y - p1.y
            dx, dy = IM_NORMALIZE2F_OVER_ZERO(dx, dy)
            temp_normals[i1].x = dy
            temp_normals[i1].y = -dx
        end
        if not closed then
            ImVec2_Copy(temp_normals[points_count], temp_normals[points_count - 1])
        end

        -- If we are drawing a one-pixel-wide line without a texture, or a textured line of any width
        if use_texture or not thick_line then
            -- [PATH 1] Texture-based lines (thick or non-thick)
            -- [PATH 2] Non texture-based lines (non-thick)
            local half_draw_size = use_texture and (thickness * 0.5 + 1) or AA_SIZE

            -- If line is not closed, the first and last points need to be generated differently
            if not closed then
                ImVec2_CopyV(temp_points[temp_points_start + 0], ImVec2_AddVA(points[1], ImVec2_MulVX(temp_normals[1], half_draw_size)))
                ImVec2_CopyV(temp_points[temp_points_start + 1], ImVec2_SubVA(points[1], ImVec2_MulVX(temp_normals[1], half_draw_size)))
                ImVec2_CopyV(temp_points[temp_points_start + (points_count - 1) * 2 + 0], ImVec2_AddVA(points[points_count], ImVec2_MulVX(temp_normals[points_count], half_draw_size)))
                ImVec2_CopyV(temp_points[temp_points_start + (points_count - 1) * 2 + 1], ImVec2_SubVA(points[points_count], ImVec2_MulVX(temp_normals[points_count], half_draw_size)))
            end

            -- Generate indices and vertices
            local idx1 = self._VtxCurrentIdx
            local idx_data = self.IdxBuffer.Data; local vtx_data = self.VtxBuffer.Buf
            for i1 = 1, count do
                local i2 = (i1 == points_count) and 1 or i1 + 1
                local idx2 = (i1 == points_count) and self._VtxCurrentIdx or (idx1 + (use_texture and 2 or 3))

                -- Average normals
                local dm_x = (temp_normals[i1].x + temp_normals[i2].x) * 0.5
                local dm_y = (temp_normals[i1].y + temp_normals[i2].y) * 0.5
                dm_x, dm_y = IM_FIXNORMAL2F(dm_x, dm_y)
                dm_x = dm_x * half_draw_size
                dm_y = dm_y * half_draw_size

                -- Add temporary vertices for the outer edges
                local out_off = (i2 - 1) * 2
                temp_points[temp_points_start + out_off + 0].x = points[i2].x + dm_x
                temp_points[temp_points_start + out_off + 0].y = points[i2].y + dm_y
                temp_points[temp_points_start + out_off + 1].x = points[i2].x - dm_x
                temp_points[temp_points_start + out_off + 1].y = points[i2].y - dm_y

                if use_texture then
                    -- Add indices for two triangles
                    local idx_write_ptr = self._IdxWritePtr
                    idx_data[idx_write_ptr + 0] = idx2 + 0; idx_data[idx_write_ptr + 1] = idx1 + 0; idx_data[idx_write_ptr + 2] = idx1 + 1
                    idx_data[idx_write_ptr + 3] = idx2 + 1; idx_data[idx_write_ptr + 4] = idx1 + 1; idx_data[idx_write_ptr + 5] = idx2 + 0
                    self._IdxWritePtr = idx_write_ptr + 6
                else
                    -- Add indices for four triangles
                    local idx_write_ptr = self._IdxWritePtr
                    idx_data[idx_write_ptr + 0] = idx2 + 0; idx_data[idx_write_ptr + 1] = idx1 + 0; idx_data[idx_write_ptr + 2] = idx1 + 2
                    idx_data[idx_write_ptr + 3] = idx1 + 2; idx_data[idx_write_ptr + 4] = idx2 + 2; idx_data[idx_write_ptr + 5] = idx2 + 0
                    idx_data[idx_write_ptr + 6] = idx2 + 1; idx_data[idx_write_ptr + 7] = idx1 + 1; idx_data[idx_write_ptr + 8] = idx1 + 0
                    idx_data[idx_write_ptr + 9] = idx1 + 0; idx_data[idx_write_ptr + 10] = idx2 + 0; idx_data[idx_write_ptr + 11] = idx2 + 1
                    self._IdxWritePtr = idx_write_ptr + 12
                end

                idx1 = idx2
            end

            -- Add vertices
            if use_texture then
                -- Texture-based: need to implement TexUvLines lookup
                local tex_uvs = self._Data.TexUvLines[integer_thickness]
                local tex_uv0 = ImVec2(tex_uvs.x, tex_uvs.y)
                local tex_uv1 = ImVec2(tex_uvs.z, tex_uvs.w)
                for i = 0, points_count - 1 do
                    local vtx_write_ptr = self._VtxWritePtr
                    WVP(vtx_data, vtx_write_ptr + 0, temp_points[temp_points_start + i * 2 + 0], tex_uv0, col)
                    WVP(vtx_data, vtx_write_ptr + 1, temp_points[temp_points_start + i * 2 + 1], tex_uv1, col)
                    self._VtxWritePtr = vtx_write_ptr + 2
                end
            else
                -- If we're not using a texture, we need the center vertex as well
                for i = 0, points_count - 1 do
                    local vtx_write_ptr = self._VtxWritePtr
                    WVP(vtx_data, vtx_write_ptr + 0, points[i + 1], opaque_uv, col)
                    WVP(vtx_data, vtx_write_ptr + 1, temp_points[temp_points_start + i * 2 + 0], opaque_uv, col_trans)
                    WVP(vtx_data, vtx_write_ptr + 2, temp_points[temp_points_start + i * 2 + 1], opaque_uv, col_trans)
                    self._VtxWritePtr = vtx_write_ptr + 3
                end
            end
        else
            -- [PATH 3] Non texture-based lines (thick)
            local half_inner_thickness = (thickness - AA_SIZE) * 0.5

            -- If line is not closed, handle first and last points
            if not closed then
                local points_last = points_count - 1
                ImVec2_CopyV(temp_points[temp_points_start + 0], ImVec2_AddVA(points[1], ImVec2_MulVX(temp_normals[1], (half_inner_thickness + AA_SIZE))))
                ImVec2_CopyV(temp_points[temp_points_start + 1], ImVec2_AddVA(points[1], ImVec2_MulVX(temp_normals[1], half_inner_thickness)))
                ImVec2_CopyV(temp_points[temp_points_start + 2], ImVec2_SubVA(points[1], ImVec2_MulVX(temp_normals[1], half_inner_thickness)))
                ImVec2_CopyV(temp_points[temp_points_start + 3], ImVec2_SubVA(points[1], ImVec2_MulVX(temp_normals[1], (half_inner_thickness + AA_SIZE))))
                ImVec2_CopyV(temp_points[temp_points_start + points_last * 4 + 0], ImVec2_AddVA(points[points_count], ImVec2_MulVX(temp_normals[points_last + 1], (half_inner_thickness + AA_SIZE))))
                ImVec2_CopyV(temp_points[temp_points_start + points_last * 4 + 1], ImVec2_AddVA(points[points_count], ImVec2_MulVX(temp_normals[points_last + 1], half_inner_thickness)))
                ImVec2_CopyV(temp_points[temp_points_start + points_last * 4 + 2], ImVec2_SubVA(points[points_count], ImVec2_MulVX(temp_normals[points_last + 1], half_inner_thickness)))
                ImVec2_CopyV(temp_points[temp_points_start + points_last * 4 + 3], ImVec2_SubVA(points[points_count], ImVec2_MulVX(temp_normals[points_last + 1], (half_inner_thickness + AA_SIZE))))
            end

            -- Generate indices and vertices
            local idx1 = self._VtxCurrentIdx
            local idx_data = self.IdxBuffer.Data; local vtx_data = self.VtxBuffer.Buf
            for i1 = 1, count do
                local i2 = (i1 == points_count) and 1 or i1 + 1
                local idx2 = (i1 == points_count) and self._VtxCurrentIdx or (idx1 + 4)

                -- Average normals
                local dm_x = (temp_normals[i1].x + temp_normals[i2].x) * 0.5
                local dm_y = (temp_normals[i1].y + temp_normals[i2].y) * 0.5
                dm_x, dm_y = IM_FIXNORMAL2F(dm_x, dm_y)
                local dm_out_x = dm_x * (half_inner_thickness + AA_SIZE)
                local dm_out_y = dm_y * (half_inner_thickness + AA_SIZE)
                local dm_in_x = dm_x * half_inner_thickness
                local dm_in_y = dm_y * half_inner_thickness

                -- Add temporary vertices
                local out_off = (i2 - 1) * 4
                temp_points[temp_points_start + out_off + 0].x = points[i2].x + dm_out_x
                temp_points[temp_points_start + out_off + 0].y = points[i2].y + dm_out_y
                temp_points[temp_points_start + out_off + 1].x = points[i2].x + dm_in_x
                temp_points[temp_points_start + out_off + 1].y = points[i2].y + dm_in_y
                temp_points[temp_points_start + out_off + 2].x = points[i2].x - dm_in_x
                temp_points[temp_points_start + out_off + 2].y = points[i2].y - dm_in_y
                temp_points[temp_points_start + out_off + 3].x = points[i2].x - dm_out_x
                temp_points[temp_points_start + out_off + 3].y = points[i2].y - dm_out_y

                -- Add indices
                local idx_write_ptr = self._IdxWritePtr
                idx_data[idx_write_ptr + 0] = idx2 + 1; idx_data[idx_write_ptr + 1] = idx1 + 1; idx_data[idx_write_ptr + 2] = idx1 + 2
                idx_data[idx_write_ptr + 3] = idx1 + 2; idx_data[idx_write_ptr + 4] = idx2 + 2; idx_data[idx_write_ptr + 5] = idx2 + 1
                idx_data[idx_write_ptr + 6] = idx2 + 1; idx_data[idx_write_ptr + 7] = idx1 + 1; idx_data[idx_write_ptr + 8] = idx1 + 0
                idx_data[idx_write_ptr + 9] = idx1 + 0; idx_data[idx_write_ptr + 10] = idx2 + 0; idx_data[idx_write_ptr + 11] = idx2 + 1
                idx_data[idx_write_ptr + 12] = idx2 + 2; idx_data[idx_write_ptr + 13] = idx1 + 2; idx_data[idx_write_ptr + 14] = idx1 + 3
                idx_data[idx_write_ptr + 15] = idx1 + 3; idx_data[idx_write_ptr + 16] = idx2 + 3; idx_data[idx_write_ptr + 17] = idx2 + 2
                self._IdxWritePtr = idx_write_ptr + 18

                idx1 = idx2
            end

            -- Add vertices
            for i = 0, points_count - 1 do
                local vtx_write_ptr = self._VtxWritePtr
                WVP(vtx_data, vtx_write_ptr + 0, temp_points[temp_points_start + i * 4 + 0], opaque_uv, col_trans)
                WVP(vtx_data, vtx_write_ptr + 1, temp_points[temp_points_start + i * 4 + 1], opaque_uv, col)
                WVP(vtx_data, vtx_write_ptr + 2, temp_points[temp_points_start + i * 4 + 2], opaque_uv, col)
                WVP(vtx_data, vtx_write_ptr + 3, temp_points[temp_points_start + i * 4 + 3], opaque_uv, col_trans)
                self._VtxWritePtr = vtx_write_ptr + 4
            end
        end
        self._VtxCurrentIdx = self._VtxCurrentIdx + vtx_count
    else
        -- [PATH 4] Non texture-based, Non anti-aliased lines
        local idx_count = count * 6
        local vtx_count = count * 4
        self:PrimReserve(idx_count, vtx_count)

        local idx_data = self.IdxBuffer.Data; local vtx_data = self.VtxBuffer.Buf
        for i1 = 1, count do
            local i2 = (i1 == points_count) and 1 or i1 + 1
            local p1 = points[i1]
            local p2 = points[i2]

            local dx = p2.x - p1.x
            local dy = p2.y - p1.y
            dx, dy = IM_NORMALIZE2F_OVER_ZERO(dx, dy)
            dx = dx * (thickness * 0.5)
            dy = dy * (thickness * 0.5)

            local vtx_write_ptr = self._VtxWritePtr
            WV(vtx_data, vtx_write_ptr + 0, p1.x + dy, p1.y - dx, opaque_uv.x, opaque_uv.y, col)
            WV(vtx_data, vtx_write_ptr + 1, p2.x + dy, p2.y - dx, opaque_uv.x, opaque_uv.y, col)
            WV(vtx_data, vtx_write_ptr + 2, p2.x - dy, p2.y + dx, opaque_uv.x, opaque_uv.y, col)
            WV(vtx_data, vtx_write_ptr + 3, p1.x - dy, p1.y + dx, opaque_uv.x, opaque_uv.y, col)
            self._VtxWritePtr = vtx_write_ptr + 4

            local idx_write_ptr = self._IdxWritePtr
            idx_data[idx_write_ptr + 0] = self._VtxCurrentIdx + 0; idx_data[idx_write_ptr + 1] = self._VtxCurrentIdx + 1; idx_data[idx_write_ptr + 2] = self._VtxCurrentIdx + 2
            idx_data[idx_write_ptr + 3] = self._VtxCurrentIdx + 0; idx_data[idx_write_ptr + 4] = self._VtxCurrentIdx + 2; idx_data[idx_write_ptr + 5] = self._VtxCurrentIdx + 3
            self._IdxWritePtr = idx_write_ptr + 6
            self._VtxCurrentIdx = self._VtxCurrentIdx + 4
        end
    end
end

function MT.ImDrawList:PathRect(a, b, rounding, flags)
    if not rounding then rounding = 0.0 end
    if not flags    then flags    = 0   end

    if rounding >= 0.5 then
        IM_ASSERT(bit32.band(flags, 0x0F) == 0, "Misuse of legacy hardcoded ImDrawCornerFlags values!")
        if bit32.band(flags, ImDrawFlags.RoundCornersMask_) == 0 then
            flags = bit32.bor(flags, ImDrawFlags.RoundCornersAll)
        end
        rounding = ImMin(rounding, ImAbs(b.x - a.x) * (((bit32.band(flags, ImDrawFlags.RoundCornersTop) == ImDrawFlags.RoundCornersTop) or (bit32.band(flags, ImDrawFlags.RoundCornersBottom) == ImDrawFlags.RoundCornersBottom)) and 0.5 or 1.0) - 1.0)
        rounding = ImMin(rounding, ImAbs(b.y - a.y) * (((bit32.band(flags, ImDrawFlags.RoundCornersLeft) == ImDrawFlags.RoundCornersLeft) or (bit32.band(flags, ImDrawFlags.RoundCornersRight) == ImDrawFlags.RoundCornersRight)) and 0.5 or 1.0) - 1.0)
    end
    if rounding < 0.5 or (bit32.band(flags, ImDrawFlags.RoundCornersMask_) == ImDrawFlags.RoundCornersNone) then
        self:PathLineTo(a)
        self:PathLineTo(ImVec2(b.x, a.y))
        self:PathLineTo(b)
        self:PathLineTo(ImVec2(a.x, b.y))
    else
        local rounding_tl = (bit32.band(flags, ImDrawFlags.RoundCornersTopLeft) ~= 0) and rounding or 0.0
        local rounding_tr = (bit32.band(flags, ImDrawFlags.RoundCornersTopRight) ~= 0) and rounding or 0.0
        local rounding_br = (bit32.band(flags, ImDrawFlags.RoundCornersBottomRight) ~= 0) and rounding or 0.0
        local rounding_bl = (bit32.band(flags, ImDrawFlags.RoundCornersBottomLeft) ~= 0) and rounding or 0.0
        self:PathArcToFast(ImVec2(a.x + rounding_tl, a.y + rounding_tl), rounding_tl, 6, 9)
        self:PathArcToFast(ImVec2(b.x - rounding_tr, a.y + rounding_tr), rounding_tr, 9, 12)
        self:PathArcToFast(ImVec2(b.x - rounding_br, b.y - rounding_br), rounding_br, 0, 3)
        self:PathArcToFast(ImVec2(a.x + rounding_bl, b.y - rounding_bl), rounding_bl, 3, 6)
    end
end

@native
function MT.ImDrawList:AddRectFilled(p_min, p_max, col, rounding, flags)
    if not rounding then rounding = 0.0 end
    if not flags    then flags    = 0   end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then return end

    if rounding < 0.5 or (bit32.band(flags, ImDrawFlags.RoundCornersMask_) == ImDrawFlags.RoundCornersNone) then
        self:PrimReserve(6, 4)
        self:PrimRect(p_min, p_max, col)
    else
        self:PathRect(p_min, p_max, rounding, flags)
        self:PathFillConvex(col)
    end
end

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
    self:PrimReserve(6, 4)
    self:PrimWriteIdx(self._VtxCurrentIdx); self:PrimWriteIdx(self._VtxCurrentIdx + 1); self:PrimWriteIdx(self._VtxCurrentIdx + 2)
    self:PrimWriteIdx(self._VtxCurrentIdx); self:PrimWriteIdx(self._VtxCurrentIdx + 2); self:PrimWriteIdx(self._VtxCurrentIdx + 3)
    self:PrimWriteVtx(p_min, uv, col_upr_left)
    self:PrimWriteVtx(ImVec2(p_max.x, p_min.y), uv, col_upr_right)
    self:PrimWriteVtx(p_max, uv, col_bot_right)
    self:PrimWriteVtx(ImVec2(p_min.x, p_max.y), uv, col_bot_left)
end

--- @param p_min      ImVec2
--- @param p_max      ImVec2
--- @param col        ImU32
--- @param rounding   float
--- @param thickness? float
--- @param flags?     ImDrawFlags
@native
function MT.ImDrawList:AddRect(p_min, p_max, col, rounding, thickness, flags)
    if thickness == nil then thickness = 1.0 end
    if flags     == nil then flags     = 0   end

    IM_ASSERT_USER_ERROR_RET(bit32.band(flags, ImDrawFlags.InvalidMask_) == 0, "Incorrect parameter. Did you swap 'thickness' and 'flags'?")

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end
    -- [Luau] square corners + whole-pixel thickness: 4 filled rects instead of a stroked path (same pixels, far cheaper here)
    if (rounding == nil or rounding < 0.5 or bit32.band(flags, ImDrawFlags.RoundCornersMask_) == ImDrawFlags.RoundCornersNone)
        and thickness >= 1.0 and thickness % 1 == 0 and p_max.x - p_min.x > 2 * thickness and p_max.y - p_min.y > 2 * thickness then
        local x0, y0, x1, y1, t = p_min.x, p_min.y, p_max.x, p_max.y, thickness
        self:PrimReserve(24, 16)
        self:PrimRect(ImVec2(x0, y0), ImVec2(x1, y0 + t), col)
        self:PrimRect(ImVec2(x0, y1 - t), ImVec2(x1, y1), col)
        self:PrimRect(ImVec2(x0, y0 + t), ImVec2(x0 + t, y1 - t), col)
        self:PrimRect(ImVec2(x1 - t, y0 + t), ImVec2(x1, y1 - t), col)
        return
    end
    if bit32.band(self.Flags, ImDrawListFlags.AntiAliasedLines) ~= 0 then
        self:PathRect(p_min + ImVec2(0.50, 0.50), p_max - ImVec2(0.50, 0.50), rounding, flags)
    else
        self:PathRect(p_min + ImVec2(0.50, 0.50), p_max - ImVec2(0.49, 0.49), rounding, flags)
    end

    self:PathStroke(col, thickness, ImDrawFlags.Closed)
end

function MT.ImDrawList:AddLine(p1, p2, col, thickness)
    if bit32.band(col, IM_COL32_A_MASK) == 0 then return end

    self:PathLineTo(p1 + ImVec2(0.5, 0.5))
    self:PathLineTo(p2 + ImVec2(0.5, 0.5))
    self:PathStroke(col, thickness)
end

--- @param min_x      float
--- @param max_x      float
--- @param y          float
--- @param col        ImU32
--- @param thickness? float
function MT.ImDrawList:AddLineH(min_x, max_x, y, col, thickness)
    if thickness == nil then thickness = 1.0 end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end
    self:PathLineTo(ImVec2(min_x + 0.5, y + 0.5))
    self:PathLineTo(ImVec2(max_x + 0.5, y + 0.5))
    self:PathStroke(col, thickness)
end

--- @param x          float
--- @param min_y      float
--- @param max_y      float
--- @param col        ImU32
--- @param thickness? float
function MT.ImDrawList:AddLineV(x, min_y, max_y, col, thickness)
    if thickness == nil then thickness = 1.0 end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end
    self:PathLineTo(ImVec2(x + 0.5, min_y + 0.5))
    self:PathLineTo(ImVec2(x + 0.5, max_y + 0.5))
    self:PathStroke(col, thickness)
end

function MT.ImDrawList:AddTriangle(p1, p2, p3, col, thickness)
    if bit32.band(col, IM_COL32_A_MASK) == 0 then
        return
    end

    self:PathLineTo(p1)
    self:PathLineTo(p2)
    self:PathLineTo(p3)
    self:PathStroke(col, thickness, ImDrawFlags.Closed)
end

function MT.ImDrawList:AddQuad(p1, p2, p3, p4, col, thickness)
    if thickness == nil then thickness = 1.0 end
    if bit32.band(col, IM_COL32_A_MASK) == 0 then return end

    self:PathLineTo(p1)
    self:PathLineTo(p2)
    self:PathLineTo(p3)
    self:PathLineTo(p4)
    self:PathStroke(col, thickness, ImDrawFlags.Closed)
end

function MT.ImDrawList:AddQuadFilled(p1, p2, p3, p4, col)
    if bit32.band(col, IM_COL32_A_MASK) == 0 then return end

    self:PathLineTo(p1)
    self:PathLineTo(p2)
    self:PathLineTo(p3)
    self:PathLineTo(p4)
    self:PathFillConvex(col)
end

function MT.ImDrawList:AddTriangleFilled(p1, p2, p3, col)
    if bit32.band(col, IM_COL32_A_MASK) == 0 then return end

    self:PathLineTo(p1)
    self:PathLineTo(p2)
    self:PathLineTo(p3)
    self:PathFillConvex(col)
end

--- @param center       ImVec2
--- @param radius       float
--- @param col          ImU32
--- @param num_segments int
--- @param thickness    float
function MT.ImDrawList:AddCircle(center, radius, col, num_segments, thickness)
    if num_segments == nil then num_segments = 0   end
    if thickness    == nil then thickness    = 1.0 end

    if bit32.band(col, IM_COL32_A_MASK) == 0 or radius < 0.5 then
        return
    end

    if num_segments <= 0 then
        -- Use arc with automatic segment count
        self:_PathArcToFastEx(center, radius - 0.5, 0, IM_DRAWLIST_ARCFAST_SAMPLE_MAX, 0)
        self._Path.Size = self._Path.Size - 1
    else
        -- Explicit segment count (still clamp to avoid drawing insanely tessellated shapes)
        num_segments = ImClamp(num_segments, 3, IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MAX)

        -- Because we are filling a closed shape we remove 1 from the count of segments/points
        local a_max = (IM_PI * 2.0) * (num_segments - 1) / num_segments
        self:PathArcTo(center, radius - 0.5, 0.0, a_max, num_segments - 1)
    end

    self:PathStroke(col, thickness, ImDrawFlags.Closed)
end

--- @param center       ImVec2
--- @param radius       float
--- @param col          ImU32
--- @param num_segments int
function MT.ImDrawList:AddCircleFilled(center, radius, col, num_segments)
    if num_segments == nil then num_segments = 0 end

    if bit32.band(col, IM_COL32_A_MASK) == 0 or radius < 0.5 then
        return
    end

    if num_segments <= 0 then
        -- Use arc with automatic segment count
        self:_PathArcToFastEx(center, radius, 0, IM_DRAWLIST_ARCFAST_SAMPLE_MAX, 0)
        self._Path.Size = self._Path.Size - 1
    else
        -- Explicit segment count (still clamp to avoid drawing insanely tessellated shapes)
        num_segments = ImClamp(num_segments, 3, IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_MAX)

        -- Because we are filling a closed shape we remove 1 from the count of segments/points
        local a_max = (IM_PI * 2.0) * (num_segments - 1) / num_segments
        self:PathArcTo(center, radius, 0.0, a_max, num_segments - 1)
    end

    self:PathFillConvex(col)
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
@native
function MT.ImDrawList:AddText(font, font_size, pos, col, text, text_begin, text_end, wrap_width, cpu_fine_clip_rect)
    -- Overload: AddText(pos, col, text, text_end?)
    if type(font) == "table" and type(font[1]) == "number" then
        font, font_size, pos, col, text, text_begin, text_end, wrap_width, cpu_fine_clip_rect = nil, 0.0, font, font_size, pos, 1, col, 0.0, nil
        if text_end == nil then text_end = #text + 1 end
    end
    if text_begin == nil then text_begin = 1 end

    if bit32.band(col, IM_COL32_A_MASK) == 0 then return end

    if text_begin == text_end then
        return
    end

    if font == nil then
        font = self._Data.Font
    end
    if font_size == 0.0 then
        font_size = self._Data.FontSize
    end

    local clip_rect = ImVec4() -- Don't modify the clip rect!
    ImVec4_Copy(clip_rect, self._CmdHeader.ClipRect)
    if (cpu_fine_clip_rect) then
        clip_rect.x = ImMax(clip_rect.x, cpu_fine_clip_rect.x)
        clip_rect.y = ImMax(clip_rect.y, cpu_fine_clip_rect.y)
        clip_rect.z = ImMin(clip_rect.z, cpu_fine_clip_rect.z)
        clip_rect.w = ImMin(clip_rect.w, cpu_fine_clip_rect.w)
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

    IM_ASSERT(bit32.band(flags, 0x0F) == 0, "Misuse of legacy hardcoded ImDrawCornerFlags values!")
    if bit32.band(flags, ImDrawFlags.RoundCornersMask_) == 0 then
        flags = bit32.bor(flags, ImDrawFlags.RoundCornersAll)
    end

    if rounding < 0.5 or bit32.band(flags, ImDrawFlags.RoundCornersMask_) == ImDrawFlags.RoundCornersNone then
        self:AddImage(tex_ref, p_min, p_max, uv_min, uv_max, col)
        return
    end

    local push_texture_id = (tex_ref ~= self._CmdHeader.TexRef)
    if push_texture_id then
        self:PushTexture(tex_ref)
    end

    local vert_start_idx = self.VtxBuffer.Size + 1
    self:PathRect(p_min, p_max, rounding, flags)
    self:PathFillConvex(col)
    local vert_end_idx = self.VtxBuffer.Size + 1
    ImGui.ShadeVertsLinearUV(self, vert_start_idx, vert_end_idx, p_min, p_max, uv_min, uv_max, true)

    if push_texture_id then
        self:PopTexture()
    end
end

--- @param radius float
function MT.ImDrawList:_CalcCircleAutoSegmentCount(radius)
    local radius_idx = ImFloor(radius + 0.999) + 1

    if radius_idx >= 1 and radius_idx <= 64 then -- IM_COUNTOF(_Data->CircleSegmentCounts)
        return self._Data.CircleSegmentCounts[radius_idx]
    else
        return IM_DRAWLIST_CIRCLE_AUTO_SEGMENT_CALC(radius, self._Data.CircleTessellationMaxError)
    end
end

function MT.ImDrawList:PushClipRect(cr_min, cr_max, intersect_with_current_clip_rect)
    local cr = ImVec4(cr_min.x, cr_min.y, cr_max.x, cr_max.y)

    if intersect_with_current_clip_rect then
        local current = self._CmdHeader.ClipRect

        if cr.x < current.x then cr.x = current.x end
        if cr.y < current.y then cr.y = current.y end
        if cr.z > current.z then cr.z = current.z end
        if cr.w > current.w then cr.w = current.w end
    end

    cr.z = ImMax(cr.x, cr.z)
    cr.w = ImMax(cr.y, cr.w)

    self._ClipRectStack:push_back(cr)
    ImVec4_Copy(self._CmdHeader.ClipRect, cr)
    self:_OnChangedClipRect()
end

function MT.ImDrawList:PopClipRect()
    self._ClipRectStack:pop_back()
    if (self._ClipRectStack.Size == 0) then -- LUA: No "Ternary Operator"
        ImVec4_Copy(self._CmdHeader.ClipRect, self._Data.ClipRectFullscreen)
    else
        ImVec4_Copy(self._CmdHeader.ClipRect, self._ClipRectStack.Data[self._ClipRectStack.Size])
    end
    self:_OnChangedClipRect()
end

--- @param center       ImVec2
--- @param radius       float
--- @param a_min_sample int
--- @param a_max_sample int
--- @param a_step       int
@native
function MT.ImDrawList:_PathArcToFastEx(center, radius, a_min_sample, a_max_sample, a_step)
    if radius < 0.5 then
        self._Path:push_back(center)
        return
    end

    if a_step <= 0 then
        a_step = math.floor(IM_DRAWLIST_ARCFAST_SAMPLE_MAX / self:_CalcCircleAutoSegmentCount(radius))
    end

    a_step = ImClamp(a_step, 1, math.floor(IM_DRAWLIST_ARCFAST_TABLE_SIZE / 4))

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

            if sample_range > 0 then
                a_step = a_step - math.floor((a_step - overstep) / 2)
            end
        end
    end

    self._Path:resize(self._Path.Size + samples)
    local out_ptr = self._Path.Size - samples + 1

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
            if sample_index >= IM_DRAWLIST_ARCFAST_SAMPLE_MAX then
                sample_index = sample_index - IM_DRAWLIST_ARCFAST_SAMPLE_MAX
            end

            local s = self._Data.ArcFastVtx[sample_index + 1]
            ImVec2_CopyV(self._Path.Data[out_ptr], center.x + s.x * radius, center.y + s.y * radius)
            out_ptr = out_ptr + 1

            a = a + a_step
            sample_index = sample_index + a_step
            a_step = a_next_step
        end
    else
        local a = a_min_sample
        while a >= a_max_sample do
            if sample_index < 0 then
                sample_index = sample_index + IM_DRAWLIST_ARCFAST_SAMPLE_MAX
            end

            local s = self._Data.ArcFastVtx[sample_index + 1]
            ImVec2_CopyV(self._Path.Data[out_ptr], center.x + s.x * radius, center.y + s.y * radius)
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

        local s = self._Data.ArcFastVtx[normalized_max_sample + 1]
        ImVec2_CopyV(self._Path.Data[out_ptr], center.x + s.x * radius, center.y + s.y * radius)
        out_ptr = out_ptr + 1
    end

    IM_ASSERT_PARANOID(self._Path.Size == out_ptr - 1)
end

@native
function MT.ImDrawList:PathArcToFast(center, radius, a_min_of_12, a_max_of_12)
    if radius < 0.5 then
        self._Path:push_back(center)
        return
    end

    self:_PathArcToFastEx(center, radius, a_min_of_12 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, a_max_of_12 * IM_DRAWLIST_ARCFAST_SAMPLE_MAX / 12, 0)
end

--- @param center       ImVec2
--- @param radius       float
--- @param a_min        float
--- @param a_max        float
--- @param num_segments int
function MT.ImDrawList:_PathArcToN(center, radius, a_min, a_max, num_segments)
    if radius < 0.5 then
        self._Path:push_back(center)
        return
    end

    -- Note that we are adding a point at both a_min and a_max.
    -- If you are trying to draw a full closed circle you don't want the overlapping points!
    self._Path:reserve(self._Path.Size + (num_segments + 1))
    for i = 0, num_segments do
        local a = a_min + (i / num_segments) * (a_max - a_min)
        self._Path:push_back(ImVec2(center.x + ImCos(a) * radius, center.y + ImSin(a) * radius))
    end
end

--- @param center        ImVec2
--- @param radius        float
--- @param a_min         float
--- @param a_max         float
--- @param num_segments? int
function MT.ImDrawList:PathArcTo(center, radius, a_min, a_max, num_segments)
    if num_segments == nil then num_segments = 0 end

    if radius < 0.5 then
        self._Path:push_back(center)
        return
    end

    if num_segments > 0 then
        self:_PathArcToN(center, radius, a_min, a_max, num_segments)
        return
    end

    if radius <= self._Data.ArcFastRadiusCutoff then
        local a_is_reverse = a_max < a_min

        local a_min_sample_f = IM_DRAWLIST_ARCFAST_SAMPLE_MAX * a_min / (IM_PI * 2.0)
        local a_max_sample_f = IM_DRAWLIST_ARCFAST_SAMPLE_MAX * a_max / (IM_PI * 2.0)

        local a_min_sample = a_is_reverse and ImFloor(a_min_sample_f) or ImCeil(a_min_sample_f)
        local a_max_sample = a_is_reverse and ImCeil(a_max_sample_f) or ImFloor(a_max_sample_f)
        local a_mid_samples = a_is_reverse and ImMax(a_min_sample - a_max_sample, 0) or ImMax(a_max_sample - a_min_sample, 0)

        local a_min_segment_angle = a_min_sample * IM_PI * 2.0 / IM_DRAWLIST_ARCFAST_SAMPLE_MAX
        local a_max_segment_angle = a_max_sample * IM_PI * 2.0 / IM_DRAWLIST_ARCFAST_SAMPLE_MAX
        local a_emit_start = ImAbs(a_min_segment_angle - a_min) >= 1e-5
        local a_emit_end = ImAbs(a_max - a_max_segment_angle) >= 1e-5

        self._Path:reserve(self._Path.Size + (a_mid_samples + 1 + (a_emit_start and 1 or 0) + (a_emit_end and 1 or 0)))

        if a_emit_start      then self._Path:push_back(ImVec2(center.x + ImCos(a_min) * radius, center.y + ImSin(a_min) * radius)) end
        if a_mid_samples > 0 then self:_PathArcToFastEx(center, radius, a_min_sample, a_max_sample, 0) end
        if a_emit_end        then self._Path:push_back(ImVec2(center.x + ImCos(a_max) * radius, center.y + ImSin(a_max) * radius)) end
    else
        local arc_length = ImAbs(a_max - a_min)
        local circle_segment_count = self:_CalcCircleAutoSegmentCount(radius)
        local arc_segment_count = ImMax(ImCeil(circle_segment_count * arc_length / (IM_PI * 2.0)), 1)

        self:_PathArcToN(center, radius, a_min, a_max, arc_segment_count)
    end
end

-- Not recommended to call this directly!
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

    local x = pos.x
    local y = pos.y
    if y > clip_rect.w then
        return
    end
    if bit32.band(draw_list.Flags, ImDrawListFlags.TextNoPixelSnap) == 0 then
        x = IM_TRUNC(x)
        y = IM_TRUNC(y)
    end

    -- if not text_end then
    -- end

    local line_height = size
    local baked = self:GetFontBaked(size)

    local scale = size / baked.Size
    local origin_x = x
    local word_wrap_enabled = (wrap_width > 0.0)

    local s = text_begin
    if y + line_height < clip_rect.y then
        while y + line_height < clip_rect.y and s < text_end do
            local line_end = ImMemchr(text, '\n', s)
            if word_wrap_enabled then
                s = ImFontCalcWordWrapPositionEx(self, size, text, s, (line_end ~= nil) and line_end or text_end, wrap_width, flags)
                s = ImTextCalcWordWrapNextLineStart(text, s, text_end, flags)
            else
                s = (line_end ~= nil) and (line_end + 1) or text_end
            end

            y = y + line_height
        end
    end

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
            if not word_wrap_eol then
                word_wrap_eol = ImFontCalcWordWrapPositionEx(self, size, text, s, text_end, wrap_width - (x - origin_x), flags)
            end

            if s >= word_wrap_eol then
                x = origin_x
                y = y + line_height
                if y > clip_rect.w then
                    stop = true; break
                end
                word_wrap_eol = nil
                s = ImTextCalcWordWrapNextLineStart(text, s, text_end, flags)

                break
            end
        end

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
                    stop = true; break
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
            glyph = baked:FindGlyph(c) -- may load the glyph and grow the tables
            lookup, lookup_n, glyphs = baked.IndexLookup.Data, baked.IndexLookup.Size, baked.Glyphs.Data
        end

        local char_width = glyph.AdvanceX * scale
        if glyph.Visible then
            local x1 = x + glyph.X0 * scale
            local x2 = x + glyph.X1 * scale
            local y1 = y + glyph.Y0 * scale
            local y2 = y + glyph.Y1 * scale
            if x1 <= clip_rect.z and x2 >= clip_rect.x then
                local u1 = glyph.U0
                local v1 = glyph.V0
                local u2 = glyph.U1
                local v2 = glyph.V1

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

                local glyph_col = glyph.Colored and color_untinted or col

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

    -- Edge case: calling RenderText() with unloaded glyphs triggering texture change. It doesn't happen via ImGui.* calls because CalcTextSize() is always used
    if cmd_count ~= draw_list.CmdBuffer.Size then
        IM_ASSERT(draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size].ElemCount == 0)
        draw_list.CmdBuffer:pop_back()
        draw_list:PrimUnreserve(idx_count_max, vtx_count_max)
        draw_list:AddDrawCmd()

        return self:RenderText(draw_list, size, pos, col, clip_rect, text, text_begin, text_end, wrap_width, flags) -- was `goto begin`
    end

    draw_list.VtxBuffer.Size = vtx_write - 1
    draw_list.IdxBuffer.Size = idx_write - 1
    draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size].ElemCount = draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size].ElemCount - (idx_expected_size - draw_list.IdxBuffer.Size)
    draw_list._VtxWritePtr = vtx_write
    draw_list._IdxWritePtr = idx_write
    draw_list._VtxCurrentIdx = vtx_index
end

--- @param draw_list ImDrawList
--- @param pos       ImVec2
--- @param color     ImU32
--- @param dir       ImGuiDir
--- @param scale?    float
local arrow_a, arrow_b, arrow_c = ImVec2(), ImVec2(), ImVec2() -- scratch: the path is consumed by AddTriangleFilled before returning

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
    -- FIXME-OPT: This should be baked in font now that it's easier
    local font_size = draw_list._Data.FontSize
    draw_list:AddCircleFilled(pos, font_size * 0.20, col, (font_size < 22) and 8 or ((font_size < 40) and 12 or 0)) -- Hardcode optimal/nice tessellation threshold
end

--- @param draw_list ImDrawList
--- @param pos       ImVec2
--- @param col       ImU32
--- @param sz        float
function ImGui.RenderCheckMark(draw_list, pos, col, sz)
    local thickness = ImMax(sz / 5.0, 1.0)
    sz = sz - thickness * 0.5
    pos = pos + ImVec2(thickness * 0.25, thickness * 0.25)

    local third = sz / 3.0
    local bx = pos.x + third
    local by = pos.y + sz - third * 0.5

    draw_list:PathLineTo(ImVec2(bx - third, by - third))
    draw_list:PathLineTo(ImVec2(bx, by))
    draw_list:PathLineTo(ImVec2(bx + third * 2.0, by - third * 2.0))
    draw_list:PathStroke(col, thickness)
end

-- Render an arrow. 'pos' is position of the arrow tip. half_sz.x is length from base to tip. half_sz.y is length on each side
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
    elseif direction == ImGuiDir.None or direction == ImGuiDir.COUNT then
    end
end

local function ImAcos01(x)
    if x <= 0.0 then return IM_PI * 0.5 end
    if x >= 1.0 then return 0.0 end
    return ImAcos(x)
end

-- FIXME: Cleanup and move code to ImDrawList
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

    draw_list:PathFillConvex(col)
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

    local flags = ImDrawFlags.RoundCornersNone

    if round_t and round_l then
        flags = bit32.bor(flags, ImDrawFlags.RoundCornersTopLeft)
    end
    if round_t and round_r then
        flags = bit32.bor(flags, ImDrawFlags.RoundCornersTopRight)
    end
    if round_b and round_l then
        flags = bit32.bor(flags, ImDrawFlags.RoundCornersBottomLeft)
    end
    if round_b and round_r then
        flags = bit32.bor(flags, ImDrawFlags.RoundCornersBottomRight)
    end

    return flags
end

-- Helper for ColorPicker4()
-- NB: This is rather brittle and will show artifact when rounding this enabled if rounded corners overlap multiple cells. Caller currently responsible for avoiding that.
-- Spent a non reasonable amount of time trying to getting this right for ColorButton with rounding+anti-aliasing+ImGuiColorEditFlags_HalfAlphaPreview flag + various grid sizes and offsets, and eventually gave up... probably more reasonable to disable rounding altogether.
-- FIXME: uses ImGui.GetColorU32
--- @param draw_list ImDrawList
--- @param p_min     ImVec2
--- @param p_max     ImVec2
--- @param col       ImU32
--- @param grid_step float
--- @param grid_off  ImVec2
--- @param rounding? float
--- @param flags?    ImDrawFlags
function ImGui.RenderColorRectWithAlphaCheckerboard(draw_list, p_min, p_max, col, grid_step, grid_off, rounding, flags)
    if rounding == nil then rounding = 0.0 end
    if flags    == nil then flags    = 0   end

    if bit32.band(flags, ImDrawFlags.RoundCornersMask_) == 0 then
        flags = ImDrawFlags.RoundCornersDefault_
    end

    if bit32.rshift(bit32.band(col, IM_COL32_A_MASK), IM_COL32_A_SHIFT) < 0xFF then
        local col_bg1 = ImGui.GetColorU32(ImStd.ImAlphaBlendColors(IM_COL32(128, 128, 128, 255), col), nil, true)
        local col_bg2 = ImGui.GetColorU32(ImStd.ImAlphaBlendColors(IM_COL32(204, 204, 204, 255), col), nil, true)
        draw_list:AddRectFilled(p_min, p_max, col_bg1, rounding, flags)

        local yi = 0
        local y = p_min.y + grid_off.y
        local x_start
        local x
        local cell_flags
        while y < p_max.y do
            repeat
            local y1 = ImClamp(y, p_min.y, p_max.y)
            local y2 = ImMin(y + grid_step, p_max.y)

            if y2 <= y1 then
                break
            end

            x_start = p_min.x + grid_off.x + ((yi + 1) % 2) * grid_step
            x = x_start
            while x < p_max.x do
                repeat
                local x1 = ImClamp(x, p_min.x, p_max.x)
                local x2 = ImMin(x + grid_step, p_max.x)

                if x2 <= x1 then
                    break
                end

                cell_flags = ImDrawFlags.RoundCornersNone
                if y1 <= p_min.y then
                    if x1 <= p_min.x then cell_flags = bit32.bor(cell_flags, ImDrawFlags.RoundCornersTopLeft) end
                    if x2 >= p_max.x then cell_flags = bit32.bor(cell_flags, ImDrawFlags.RoundCornersTopRight) end
                end
                if y2 >= p_max.y then
                    if x1 <= p_min.x then cell_flags = bit32.bor(cell_flags, ImDrawFlags.RoundCornersBottomLeft) end
                    if x2 >= p_max.x then cell_flags = bit32.bor(cell_flags, ImDrawFlags.RoundCornersBottomRight) end
                end

                -- Combine flags
                if flags == ImDrawFlags.RoundCornersNone or cell_flags == ImDrawFlags.RoundCornersNone then
                    cell_flags = ImDrawFlags.RoundCornersNone
                else
                    cell_flags = bit32.band(cell_flags, flags)
                end
                draw_list:AddRectFilled(ImVec2(x1, y1), ImVec2(x2, y2), col_bg2, rounding, cell_flags)

                until true

                x = x + grid_step * 2.0
            end

            until true

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
    if fill_L then draw_list:AddRectFilled(ImVec2(outer.Min.x, inner.Min.y), ImVec2(inner.Min.x, inner.Max.y), col, rounding, bor(D.RoundCornersNone, f(fill_U, D.RoundCornersTopLeft), f(fill_D, D.RoundCornersBottomLeft))) end
    if fill_R then draw_list:AddRectFilled(ImVec2(inner.Max.x, inner.Min.y), ImVec2(outer.Max.x, inner.Max.y), col, rounding, bor(D.RoundCornersNone, f(fill_U, D.RoundCornersTopRight), f(fill_D, D.RoundCornersBottomRight))) end
    if fill_U then draw_list:AddRectFilled(ImVec2(inner.Min.x, outer.Min.y), ImVec2(inner.Max.x, inner.Min.y), col, rounding, bor(D.RoundCornersNone, f(fill_L, D.RoundCornersTopLeft), f(fill_R, D.RoundCornersTopRight))) end
    if fill_D then draw_list:AddRectFilled(ImVec2(inner.Min.x, inner.Max.y), ImVec2(inner.Max.x, outer.Max.y), col, rounding, bor(D.RoundCornersNone, f(fill_L, D.RoundCornersBottomLeft), f(fill_R, D.RoundCornersBottomRight))) end
    if fill_L and fill_U then draw_list:AddRectFilled(ImVec2(outer.Min.x, outer.Min.y), ImVec2(inner.Min.x, inner.Min.y), col, rounding, D.RoundCornersTopLeft) end
    if fill_R and fill_U then draw_list:AddRectFilled(ImVec2(inner.Max.x, outer.Min.y), ImVec2(outer.Max.x, inner.Min.y), col, rounding, D.RoundCornersTopRight) end
    if fill_L and fill_D then draw_list:AddRectFilled(ImVec2(outer.Min.x, inner.Max.y), ImVec2(inner.Min.x, outer.Max.y), col, rounding, D.RoundCornersBottomLeft) end
    if fill_R and fill_D then draw_list:AddRectFilled(ImVec2(inner.Max.x, inner.Max.y), ImVec2(outer.Max.x, outer.Max.y), col, rounding, D.RoundCornersBottomRight) end
end

----------------------------------------------------------------
-- Extra primitives (Ngon, Ellipse, Bezier, concave fill)
----------------------------------------------------------------
-- [port] These follow the 1.92 stroker this port uses (no ImDrawFlags_StrokeXXX placement flags).

function MT.ImDrawList:PathEllipticalArcTo(center, radius, rot, a_min, a_max, num_segments)
    if num_segments == nil or num_segments <= 0 then
        num_segments = self:_CalcCircleAutoSegmentCount(ImMax(radius.x, radius.y))
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
        PathBezierCubicCurveToCasteljau(self._Path, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, p4.x, p4.y, self._Data.CurveTessellationTol, 0)
    else
        local t_step = 1.0 / num_segments
        for i_step = 1, num_segments do self._Path:push_back(ImBezierCubicCalc(p1, p2, p3, p4, t_step * i_step)) end
    end
end

function MT.ImDrawList:PathBezierQuadraticCurveTo(p2, p3, num_segments)
    local p1 = self._Path:back()
    if num_segments == nil or num_segments == 0 then
        PathBezierQuadraticCurveToCasteljau(self._Path, p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, self._Data.CurveTessellationTol, 0)
    else
        local t_step = 1.0 / num_segments
        for i_step = 1, num_segments do self._Path:push_back(ImBezierQuadraticCalc(p1, p2, p3, t_step * i_step)) end
    end
end

function MT.ImDrawList:AddNgon(center, radius, col, num_segments, thickness)
    if thickness == nil then thickness = 1.0 end
    if bit32.band(col, IM_COL32_A_MASK) == 0 or num_segments <= 2 then return end
    local a_max = (IM_PI * 2.0) * (num_segments - 1.0) / num_segments
    self:PathArcTo(center, radius - 0.5, 0.0, a_max, num_segments - 1)
    self:PathStroke(col, thickness, ImDrawFlags.Closed)
end

function MT.ImDrawList:AddNgonFilled(center, radius, col, num_segments)
    if bit32.band(col, IM_COL32_A_MASK) == 0 or num_segments <= 2 then return end
    local a_max = (IM_PI * 2.0) * (num_segments - 1.0) / num_segments
    self:PathArcTo(center, radius, 0.0, a_max, num_segments - 1)
    self:PathFillConvex(col)
end

function MT.ImDrawList:AddEllipse(center, radius, col, rot, num_segments, thickness)
    if rot == nil then rot = 0.0 end
    if thickness == nil then thickness = 1.0 end
    if bit32.band(col, IM_COL32_A_MASK) == 0 then return end
    if num_segments == nil or num_segments <= 0 then num_segments = self:_CalcCircleAutoSegmentCount(ImMax(radius.x, radius.y)) end
    local a_max = IM_PI * 2.0 * (num_segments - 1.0) / num_segments
    self:PathEllipticalArcTo(center, radius, rot, 0.0, a_max, num_segments - 1)
    self:PathStroke(col, thickness, ImDrawFlags.Closed)
end

function MT.ImDrawList:AddEllipseFilled(center, radius, col, rot, num_segments)
    if rot == nil then rot = 0.0 end
    if bit32.band(col, IM_COL32_A_MASK) == 0 then return end
    if num_segments == nil or num_segments <= 0 then num_segments = self:_CalcCircleAutoSegmentCount(ImMax(radius.x, radius.y)) end
    local a_max = IM_PI * 2.0 * (num_segments - 1.0) / num_segments
    self:PathEllipticalArcTo(center, radius, rot, 0.0, a_max, num_segments - 1)
    self:PathFillConvex(col)
end

function MT.ImDrawList:AddBezierCubic(p1, p2, p3, p4, col, thickness, num_segments)
    if bit32.band(col, IM_COL32_A_MASK) == 0 then return end
    self:PathLineTo(p1)
    self:PathBezierCubicCurveTo(p2, p3, p4, num_segments or 0)
    self:PathStroke(col, thickness or 1.0)
end

function MT.ImDrawList:AddBezierQuadratic(p1, p2, p3, col, thickness, num_segments)
    if bit32.band(col, IM_COL32_A_MASK) == 0 then return end
    self:PathLineTo(p1)
    self:PathBezierQuadraticCurveTo(p2, p3, num_segments or 0)
    self:PathStroke(col, thickness or 1.0)
end

-- ponytail: ear-clipping, no anti-aliased fringe (upstream's AA triangulator not ported). O(n^2) is fine for UI polygons.
--- @param points ImVec2[] # 1-based
function MT.ImDrawList:AddConcavePolyFilled(points, points_count, col)
    if points_count < 3 or bit32.band(col, IM_COL32_A_MASK) == 0 then return end
    local idx = {}
    local area = 0.0
    for i = 1, points_count do
        idx[i] = i
        local a, b = points[i], points[i % points_count + 1]
        area = area + (a.x * b.y - b.x * a.y)
    end
    local sign = (area >= 0) and 1 or -1
    local function cross(o, a, b) return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) end
    local guard = 0
    while #idx > 3 and guard < points_count * points_count do
        guard = guard + 1
        local n = #idx
        local clipped = false
        for i = 1, n do
            local ia, ib, ic = idx[(i - 2) % n + 1], idx[i], idx[i % n + 1]
            local a, b, c = points[ia], points[ib], points[ic]
            if cross(a, b, c) * sign > 0 then
                local inside = false
                for j = 1, n do
                    local p = idx[j]
                    if p ~= ia and p ~= ib and p ~= ic then
                        local q = points[p]
                        if cross(a, b, q) * sign >= 0 and cross(b, c, q) * sign >= 0 and cross(c, a, q) * sign >= 0 then inside = true; break end
                    end
                end
                if not inside then
                    self:AddTriangleFilled(a, b, c, col)
                    table.remove(idx, i)
                    clipped = true
                    break
                end
            end
        end
        if not clipped then break end
    end
    if #idx == 3 then self:AddTriangleFilled(points[idx[1]], points[idx[2]], points[idx[3]], col) end
end

function MT.ImDrawList:PathFillConcave(col)
    self:AddConcavePolyFilled(self._Path.Data, self._Path.Size, col)
    self._Path.Size = 0
end

return true -- [Roblox] ModuleScripts must return exactly one value
