--- Dear ImGui WIP
-- (widgets code)

--
-- Index of this file:
--
-- [SECTION] Widgets: Text, etc.
-- [SECTION] Widgets: Value helpers
-- [SECTION] Widgets: Main (Button, Image, Checkbox, RadioButton, ProgressBar, Bullet, etc.)
-- [SECTION] Widgets: Low-level Layout helpers (Spacing, Dummy, NewLine, Separator, etc.)
-- [SECTION] Widgets: ComboBox
-- [SECTION] Data Type and Data Formatting Helpers
-- [SECTION] Widgets: DragScalar, DragFloat, DragInt, etc.
-- [SECTION] Widgets: SliderScalar, SliderFloat, SliderInt, etc.
-- [SECTION] Widgets: InputScalar, InputFloat, InputInt, etc.
-- [SECTION] Widgets: InputText, InputTextMultiline
-- [SECTION] Widgets: ColorEdit, ColorPicker, ColorButton, etc.
-- [SECTION] Widgets: TreeNode, CollapsingHeader, etc.
-- [SECTION] Widgets: Selectable
-- [SECTION] Widgets: ListBox
-- [SECTION] Widgets: PlotLines, PlotHistogram
-- [SECTION] Widgets: MenuItem, BeginMenu, EndMenu, etc.
-- [SECTION] Widgets: BeginTabBar, EndTabBar, etc.
-- [SECTION] Widgets: BeginTabItem, EndTabItem, etc.
--

--- @type ImGuiContext?
local GImGui

-- [Port] Sets local `GImGui` in this file(imgui_widgets.lua).
-- This is currently only used in main code `ImGui.SetCurrentContext()`
--- @param ctx ImGuiContext?
function ImGui._SetCurrentContext_Widgets(ctx)
    GImGui = ctx
end

-------------------------------------------------------------------------------
-- Data
-------------------------------------------------------------------------------

-- Widgets
local DRAGDROP_HOLD_TO_OPEN_TIMER = 0.70 -- Time for drag-hold to activate items accepting the ImGuiButtonFlags.PressedOnDragDropHold button behavior.
local DRAG_MOUSE_THRESHOLD_FACTOR = 0.50 -- Multiplier for the default value of io.MouseDragThreshold to make DragFloat/DragInt react faster to mouse drags.

local IM_S8_MIN = -128
local IM_S8_MAX = 127
local IM_U8_MIN = 0
local IM_U8_MAX = 0xFF
local IM_S16_MIN = -32768
local IM_S16_MAX = 32767
local IM_U16_MIN = 0
local IM_U16_MAX = 0xFFFF
local IM_S32_MIN = INT_MIN -- (-2147483647 - 1), (0x80000000);
local IM_S32_MAX = INT_MAX -- (2147483647), (0x7FFFFFFF)
local IM_U32_MIN = 0
local IM_U32_MAX = UINT_MAX -- (0xFFFFFFFF)
-- [Luau] 64-bit limits as doubles: IM_S64_MAX/IM_U64_MAX round up to 2^63/2^64 (values are exact only within +-2^53)
local IM_S64_MIN = -9223372036854775808 -- (-9223372036854775807ll - 1ll)
local IM_S64_MAX = 9223372036854775807 -- (9223372036854775807ll)
local IM_U64_MIN = 0
local IM_U64_MAX = 18446744073709551615 -- (0xFFFFFFFFFFFFFFFFull)

-------------------------------------------------------------------------------
-- [SECTION] Widgets: Text, etc.
-------------------------------------------------------------------------------
-- - TextEx() [Internal]
-- - TextUnformatted()
-- - Text()
-- - TextV()
-- - TextColored()
-- - TextDisabled()
-- - TextWrapped()
-- - TextAligned()
-- - LabelText()
-- - BulletText()
-------------------------------------------------------------------------------

--- @param text      string
--- @param text_end? int
--- @param flags?    ImGuiTextFlags
local TextEx_bb = ImRect() -- [Luau] scratch, never escapes TextEx()
local LAYOUT_ZERO_SIZE = ImVec2(0, 0) -- [Luau] shared read-only: ItemSize()/CalcItemSize() only read it

@native
function ImGui.TextEx(text, text_end, flags)
    if not flags then flags = 0 end

    local g = GImGui
    local window = g.CurrentWindow
    if window.SkipItems then
        return
    end

    -- Accept null ranges
    if not text or text == "" then
        text = ""
        text_end = 1
    end

    -- Calculate length
    if text_end == nil then
        text_end = (type(text) == "string" and string.len(text) or #text) + 1 -- [Luau] `#` on a string isn't a native fast path
    end

    local dc = window.DC
    local wrap_pos_x = dc.TextWrapPos
    local wrap_enabled = (wrap_pos_x >= 0.0)
    if (text_end - 1 <= 2000) or wrap_enabled then
        -- Common case
        -- [Luau] scalar text_pos, scratch bb (ItemAdd() copies it, RenderTextWrapped() only reads it)
        local text_pos_x, text_pos_y = dc.CursorPos.x, dc.CursorPos.y + dc.CurrLineTextBaseOffset
        local wrap_width = wrap_enabled and ImGui.CalcWrapWidthForPos(dc.CursorPos, wrap_pos_x) or 0.0
        -- [Luau] inline ImGui.CalcTextSizeXY(text, 1, text_end, false, wrap_width)
        local text_size_x, text_size_y = 0.0, g.FontSize
        if text ~= "" and text_end > 1 then
            text_size_x, text_size_y = ImFontCalcTextSizeXY(g.Font, text_size_y, FLT_MAX, wrap_width, text, 1, text_end, text_end, nil, ImDrawTextFlags.None)
            text_size_x = math.ceil(text_size_x) -- Round (see CalcTextSize())
        end

        local bb = TextEx_bb
        local bb_min, bb_max = bb.Min, bb.Max
        bb_min.x = text_pos_x; bb_min.y = text_pos_y
        bb_max.x = text_pos_x + text_size_x; bb_max.y = text_pos_y + text_size_y
        ImGui.ItemSize(bb, 0.0) -- [Luau] the bb's size == text_size
        if not ImGui.ItemAdd(bb, 0) then
            return
        end

        -- Render (we don't hide text after ## in this end-user function)
        ImGui.RenderTextWrapped(bb_min, text, text_end, wrap_width)
    else
        local text_pos = ImVec2(dc.CursorPos.x, dc.CursorPos.y + dc.CurrLineTextBaseOffset)
        -- Long text!
        -- Perform manual coarse clipping to optimize for long multi-line text
        -- - From this point we will only compute the width of lines that are visible. Optimization only available when word-wrapping is disabled.
        -- - We also don't vertically center the text within the line full height, which is unlikely to matter because we are likely the biggest and only item on the line.
        local line = 1
        local line_height = ImGui.GetTextLineHeight()
        local text_size = ImVec2(0, 0)

        -- Lines to skip (can't skip when logging text)
        local pos = ImVec2(text_pos.x, text_pos.y)
        if not g.LogEnabled then
            local lines_skippable = ImFloor((window.ClipRect.Min.y - text_pos.y) / line_height)
            if lines_skippable > 0 then
                local lines_skipped = 0
                while line < text_end and lines_skipped < lines_skippable do
                    local line_end = ImMemchr(text, "\n", line)
                    if not line_end then
                        line_end = text_end
                    end
                    if bit32.band(flags, ImGuiTextFlags.NoWidthForLargeClippedText) == 0 then
                        local line_size = ImGui.CalcTextSizeEx(text, line, line_end)
                        text_size.x = ImMax(text_size.x, line_size.x)
                    end
                    line = line_end + 1
                    lines_skipped = lines_skipped + 1
                end
                pos.y = pos.y + lines_skipped * line_height
            end
        end

        -- Lines to render
        if line < text_end then
            local line_rect = ImRect(pos, pos + ImVec2(FLT_MAX, line_height))
            while line < text_end do
                if ImGui.IsClippedEx(line_rect, 0) then
                    break
                end

                local line_end = ImMemchr(text, "\n", line)
                if not line_end then
                    line_end = text_end
                end

                local line_size = ImGui.CalcTextSizeEx(text, line, line_end)
                text_size.x = ImMax(text_size.x, line_size.x)
                ImGui.RenderText(pos, text, line, line_end, false)
                line = line_end + 1
                line_rect.Min.y = line_rect.Min.y + line_height
                line_rect.Max.y = line_rect.Max.y + line_height
                pos.y = pos.y + line_height
            end

            -- Count remaining lines
            local lines_skipped = 0
            while line < text_end do
                local line_end = ImMemchr(text, "\n", line)
                if not line_end then
                    line_end = text_end
                end
                if bit32.band(flags, ImGuiTextFlags.NoWidthForLargeClippedText) == 0 then
                    local line_size = ImGui.CalcTextSizeEx(text, line, line_end)
                    text_size.x = ImMax(text_size.x, line_size.x)
                end
                line = line_end + 1
                lines_skipped = lines_skipped + 1
            end
            pos.y = pos.y + lines_skipped * line_height
        end
        text_size.y = pos.y - text_pos.y

        local bb = ImRect(text_pos, text_pos + text_size)
        ImGui.ItemSize(text_size, 0.0)
        ImGui.ItemAdd(bb, 0)
    end
end

--- @param text      string
--- @param text_end? int
function ImGui.TextUnformatted(text, text_end)
    ImGui.TextEx(text, text_end, ImGuiTextFlags.NoWidthForLargeClippedText)
end

--- @param fmt string
--- @param ... any
@native
function ImGui.TextV(fmt, ...)
    local window = GImGui.CurrentWindow -- [Luau] inline GetCurrentWindow()
    window.WriteAccessed = true
    if window.SkipItems then
        return
    end

    local text = ImFormatString(fmt, ...)
    ImGui.TextEx(text, nil, ImGuiTextFlags.NoWidthForLargeClippedText)
end

--- @param fmt string
--- @param ... any
@native
function ImGui.Text(fmt, ...)
    if select('#', ...) > 0 then
        -- [Luau] inline ImGui.TextV(fmt, ...) (saves a vararg call per Text())
        local window = GImGui.CurrentWindow -- [Luau] inline GetCurrentWindow()
        window.WriteAccessed = true
        if window.SkipItems then
            return
        end
        ImGui.TextEx(ImFormatString(fmt, ...), nil, ImGuiTextFlags.NoWidthForLargeClippedText)
    else
        ImGui.TextEx(fmt)
    end
end

--- @param col ImVec4
--- @param fmt string
--- @param ... any
function ImGui.TextColored(col, fmt, ...)
    ImGui.PushStyleColor(ImGuiCol.Text, col)
    ImGui.TextV(fmt, ...)
    ImGui.PopStyleColor()
end

--- @param fmt string
--- @param ... any
@native
function ImGui.TextDisabled(fmt, ...)
    local g = GImGui
    ImGui.PushStyleColor(ImGuiCol.Text, g.Style.Colors[ImGuiCol.TextDisabled])
    ImGui.TextV(fmt, ...)
    ImGui.PopStyleColor()
end

--- @param fmt string
--- @param ... any
@native
function ImGui.TextWrapped(fmt, ...)
    local g = GImGui
    local need_backup = (g.CurrentWindow.DC.TextWrapPos < 0.0) -- Keep existing wrap position if one is already set
    if need_backup then
        ImGui.PushTextWrapPos(0.0)
    end
    ImGui.TextV(fmt, ...)
    if need_backup then
        ImGui.PopTextWrapPos()
    end
end

-- align_x: 0.0f = left, 0.5f = center, 1.0f = right.
-- size_x < 0.0f (e.g. -FLT_MIN): shortcut for GetContentRegionAvail().x
-- FIXME-WIP: Works but API is likely to be reworked. This is designed for 1 item on the line. (#7024, #9455)
--- @param align_x float
--- @param size_x  float
--- @param fmt     string
--- @param ...     any
function ImGui.TextAligned(align_x, size_x, fmt, ...)
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return
    end

    local text = ImFormatString(fmt, ...)
    local text_end = #text + 1
    local text_size = ImGui.CalcTextSize(text, text_end)
    size_x = ImGui._CalcItemSizeXY(size_x, 0.0, 0.0, text_size.y)

    local pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y + window.DC.CurrLineTextBaseOffset)
    local pos_max = ImVec2(pos.x + size_x, window.ClipRect.Max.y)
    local size = ImVec2(ImMin(size_x, text_size.x), text_size.y)
    window.DC.CursorMaxPos.x = ImMax(window.DC.CursorMaxPos.x, pos.x + text_size.x)
    window.DC.IdealMaxPos.x = ImMax(window.DC.IdealMaxPos.x, pos.x + text_size.x)
    if align_x > 0.0 and text_size.x < size_x then
        pos.x = pos.x + ImTrunc((size_x - text_size.x) * align_x)
    end
    ImGui.RenderTextEllipsis(window.DrawList, pos, pos_max, pos_max.x, text, text_end, text_size)

    local backup_max_pos = ImVec2()
    ImVec2_Copy(backup_max_pos, window.DC.CursorMaxPos)
    ImGui.ItemSize(size)
    ImGui.ItemAdd(ImRect(pos, pos + size), 0)
    window.DC.CursorMaxPos.x = backup_max_pos.x -- Cancel out extending content to 'size' to use 'text_size' allowing auto-resize to function with align_x > 0.0f

    if size_x < text_size.x and ImGui.IsItemHovered(bit32.bor(ImGuiHoveredFlags.NoNavOverride, ImGuiHoveredFlags.AllowWhenDisabled, ImGuiHoveredFlags.ForTooltip)) then
        ImGui.SetTooltip("%.*s", text_end - 1, text)
    end
end

-- Add a label+text combo aligned to other label+value widgets
--- @param label string
--- @param fmt   string
--- @param ...   any
-- [Luau] scratch for LabelText(): only read by its callees (ItemAdd() copies total_bb), never escape
local LabelText_value_size, LabelText_value_bb, LabelText_total_bb, LabelText_pos = ImVec2(), ImRect(), ImRect(), ImVec2()
function ImGui.LabelText(label, fmt, ...)
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return
    end

    local g = GImGui
    local style = g.Style
    local w = ImGui.CalcItemWidth()

    local value_text = ImFormatString(fmt, ...)
    local value_text_end = #value_text + 1
    local value_size = LabelText_value_size
    value_size.x, value_size.y = ImGui.CalcTextSizeXY(value_text, 1, value_text_end, false)
    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size_x, label_size_y = ImGui.CalcTextSizeXY(label, 1, label_end, false) -- [Luau] scalar label_size

    local pos_x, pos_y = window.DC.CursorPos.x, window.DC.CursorPos.y -- [Luau] scalar pos
    local value_bb = LabelText_value_bb
    value_bb.Min.x, value_bb.Min.y, value_bb.Max.x, value_bb.Max.y = pos_x, pos_y, pos_x + w, pos_y + (value_size.y + style.FramePadding.y * 2)
    local total_bb = LabelText_total_bb
    total_bb.Min.x, total_bb.Min.y = pos_x, pos_y
    total_bb.Max.x = pos_x + (w + ((label_size_x > 0.0) and (style.ItemInnerSpacing.x + label_size_x) or 0.0))
    total_bb.Max.y = pos_y + (ImMax(value_size.y, label_size_y) + style.FramePadding.y * 2)
    ImGui.ItemSize(total_bb, style.FramePadding.y)
    if not ImGui.ItemAdd(total_bb, 0) then
        return
    end

    -- Render
    local text_pos = LabelText_pos
    text_pos.x, text_pos.y = value_bb.Min.x + style.FramePadding.x, value_bb.Min.y + style.FramePadding.y
    ImGui.RenderTextClipped(text_pos, value_bb.Max, value_text, value_text_end, value_size, LAYOUT_ZERO_SIZE)
    if label_size_x > 0.0 then
        text_pos.x, text_pos.y = value_bb.Max.x + style.ItemInnerSpacing.x, value_bb.Min.y + style.FramePadding.y
        ImGui.RenderText(text_pos, label, 1, label_end, false)
    end
end

-- Text with a little bullet aligned to the typical tree node.
--- @param fmt string
--- @param ... any
local BulletText_bb, BulletText_pos, BulletText_size = ImRect(), ImVec2(), ImVec2() -- [Luau] scratch, only read by callees

function ImGui.BulletText(fmt, ...)
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return
    end

    local g = GImGui
    local style = g.Style

    local text = ImFormatString(fmt, ...)
    local text_end = #text + 1
    local label_size_x, label_size_y = ImGui.CalcTextSizeXY(text, 1, text_end, false) -- [Luau] scalar label_size/total_size
    local total_size_x = g.FontSize + ((label_size_x > 0.0) and (label_size_x + style.FramePadding.x * 2) or 0.0) -- Empty text doesn't add padding
    -- [Luau] scalar pos, no temporary ImVec2
    local pos_x, pos_y = window.DC.CursorPos.x, window.DC.CursorPos.y + window.DC.CurrLineTextBaseOffset
    local bb = BulletText_bb
    bb.Min.x, bb.Min.y, bb.Max.x, bb.Max.y = pos_x, pos_y, pos_x + total_size_x, pos_y + label_size_y
    local total_size = BulletText_size
    total_size.x, total_size.y = total_size_x, label_size_y
    ImGui.ItemSize(total_size, 0.0)
    if not ImGui.ItemAdd(bb, 0) then
        return
    end

    -- Render
    local text_col = ImGui.GetColorU32(ImGuiCol.Text)
    local p = BulletText_pos
    p.x, p.y = bb.Min.x + (style.FramePadding.x + g.FontSize * 0.5), bb.Min.y + g.FontSize * 0.5
    ImGui.RenderBullet(window.DrawList, p, text_col)
    p.x, p.y = bb.Min.x + (g.FontSize + style.FramePadding.x * 2), bb.Min.y + 0.0
    ImGui.RenderText(p, text, 1, text_end, false)
end

-- [Port] va_list variants: identical to the varargs versions in Lua
ImGui.TextColoredV = ImGui.TextColored
ImGui.TextDisabledV = ImGui.TextDisabled
ImGui.TextWrappedV = ImGui.TextWrapped
ImGui.TextAlignedV = ImGui.TextAligned
ImGui.LabelTextV = ImGui.LabelText
ImGui.BulletTextV = ImGui.BulletText

-------------------------------------------------------------------------------
-- [SECTION] Widgets: Value helpers
-- Those is not very useful, legacy API.
-------------------------------------------------------------------------------
-- - Value()
-------------------------------------------------------------------------------

-- [Port] Value(prefix, b) / Value(prefix, int) / Value(prefix, float, float_format)
-- [Port] Lua can't tell int from float: integers without float_format print as %d, otherwise %.3f
function ImGui.Value(prefix, v, float_format)
    if type(v) == "boolean" then
        ImGui.Text("%s: %s", prefix, v and "true" or "false")
    elseif float_format then
        ImGui.Text("%s: " .. float_format, prefix, v)
    elseif math.floor(v) == v then
        ImGui.Text("%s: %d", prefix, v)
    else
        ImGui.Text("%s: %.3f", prefix, v)
    end
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: Main
-------------------------------------------------------------------------------
-- - ButtonBehavior() [Internal]
-- - Button()
-- - SmallButton()
-- - InvisibleButton()
-- - ArrowButton()
-- - CloseButton() [Internal]
-- - CollapseButton() [Internal]
-- - GetWindowScrollbarID() [Internal]
-- - GetWindowScrollbarRect() [Internal]
-- - Scrollbar() [Internal]
-- - ScrollbarEx() [Internal]
-- - Image()
-- - ImageButton()
-- - Checkbox()
-- - CheckboxFlagsT() [Internal]
-- - CheckboxFlags()
-- - RadioButton()
-- - ProgressBar()
-- - Bullet()
-- - Hyperlink()
-------------------------------------------------------------------------------

-- The ButtonBehavior() function is key to many interactions and used by many/most widgets.
-- Because we handle so many cases (keyboard/gamepad navigation, drag and drop) and many specific behavior (via ImGuiButtonFlags),
-- this code is a little complex.
-- By far the most common path is interacting with the Mouse using the default ImGuiButtonFlags.PressedOnClickRelease button behavior.
-- See the series of events below and the corresponding state reported by dear imgui:
-------------------------------------------------------------------------------
-- with PressedOnClickRelease:             return-value  IsItemHovered()  IsItemActive()  IsItemActivated()  IsItemDeactivated()  IsItemClicked()
--   Frame N+0 (mouse is outside bb)        -             -                -               -                  -                    -
--   Frame N+1 (mouse moves inside bb)      -             true             -               -                  -                    -
--   Frame N+2 (mouse button is down)       -             true             true            true               -                    true
--   Frame N+3 (mouse button is down)       -             true             true            -                  -                    -
--   Frame N+4 (mouse moves outside bb)     -             -                true            -                  -                    -
--   Frame N+5 (mouse moves inside bb)      -             true             true            -                  -                    -
--   Frame N+6 (mouse button is released)   true          true             -               -                  true                 -
--   Frame N+7 (mouse button is released)   -             true             -               -                  -                    -
--   Frame N+8 (mouse moves outside bb)     -             -                -               -                  -                    -
-------------------------------------------------------------------------------
-- with PressedOnClick:                    return-value  IsItemHovered()  IsItemActive()  IsItemActivated()  IsItemDeactivated()  IsItemClicked()
--   Frame N+2 (mouse button is down)       true          true             true            true               -                    true
--   Frame N+3 (mouse button is down)       -             true             true            -                  -                    -
--   Frame N+6 (mouse button is released)   -             true             -               -                  true                 -
--   Frame N+7 (mouse button is released)   -             true             -               -                  -                    -
-------------------------------------------------------------------------------
-- with PressedOnRelease:                  return-value  IsItemHovered()  IsItemActive()  IsItemActivated()  IsItemDeactivated()  IsItemClicked()
--   Frame N+2 (mouse button is down)       -             true             -               -                  -                    true
--   Frame N+3 (mouse button is down)       -             true             -               -                  -                    -
--   Frame N+6 (mouse button is released)   true          true             -               -                  -                    -
--   Frame N+7 (mouse button is released)   -             true             -               -                  -                    -
-------------------------------------------------------------------------------
-- with PressedOnDoubleClick:              return-value  IsItemHovered()  IsItemActive()  IsItemActivated()  IsItemDeactivated()  IsItemClicked()
--   Frame N+0 (mouse button is down)       -             true             -               -                  -                    true
--   Frame N+1 (mouse button is down)       -             true             -               -                  -                    -
--   Frame N+2 (mouse button is released)   -             true             -               -                  -                    -
--   Frame N+3 (mouse button is released)   -             true             -               -                  -                    -
--   Frame N+4 (mouse button is down)       true          true             true            true               -                    true
--   Frame N+5 (mouse button is down)       -             true             true            -                  -                    -
--   Frame N+6 (mouse button is released)   -             true             -               -                  true                 -
--   Frame N+7 (mouse button is released)   -             true             -               -                  -                    -
-------------------------------------------------------------------------------
-- Note that some combinations are supported,
-- - PressedOnDragDropHold can generally be associated with any flag.
-- - PressedOnDoubleClick can be associated by PressedOnClickRelease/PressedOnRelease, in which case the second release event won't be reported.
-------------------------------------------------------------------------------
-- The behavior of the return-value changes when ImGuiItemFlags.ButtonRepeat is set:
--                                         Repeat+                  Repeat+           Repeat+             Repeat+
--                                         PressedOnClickRelease    PressedOnClick    PressedOnRelease    PressedOnDoubleClick
-------------------------------------------------------------------------------
--   Frame N+0 (mouse button is down)       -                        true              -                   true
--   ...                                    -                        -                 -                   -
--   Frame N + RepeatDelay                  true                     true              -                   true
--   ...                                    -                        -                 -                   -
--   Frame N + RepeatDelay + RepeatRate*N   true                     true              -                   true
-------------------------------------------------------------------------------

-- - FIXME: For refactor we could output flags, incl mouse hovered vs nav keyboard vs nav triggered etc.
--   And better standardize how widgets use 'GetColor32((held && hovered) ? ... : hovered ? ...)' vs 'GetColor32(held ? ... : hovered ? ...);'
--   For mouse feedback we typically prefer the 'held && hovered' test, but for nav feedback not always. Outputting hovered=true on Activation may be misleading.
-- - Since v1.91.2 (Sept 2024) we included io.ConfigDebugHighlightIdConflicts feature.
--   One idiom which was previously valid which will now emit a warning is when using multiple overlaid ButtonBehavior()
--   with same ID and different MouseButton (see #8030). You can fix it by:
--       (1) switching to use a single ButtonBehavior() with multiple _MouseButton flags.
--    or (2) surrounding those calls with PushItemFlag(ImGuiItemFlags.AllowDuplicateId, true); ... PopItemFlag()
-- [Port] Returns (pressed, hovered, held).
--- @param bb     ImRect
--- @param id     ImGuiID
--- @param flags? ImGuiButtonFlags
@native
function ImGui.ButtonBehavior(bb, id, flags)
    if flags == nil then flags = 0 end

    local g = GImGui

    local window = g.CurrentWindow

    -- Default behavior inherited from item flags
    -- Note that _both_ ButtonFlags and ItemFlags are valid sources, so copy one into the item_flags and only check that.
    local item_flags = (g.LastItemData.ID == id) and g.LastItemData.ItemFlags or g.CurrentItemFlags
    if bit32.band(flags, ImGuiButtonFlags.AllowOverlap) ~= 0 then
        item_flags = bit32.bor(item_flags, ImGuiItemFlags.AllowOverlap)
    end
    if bit32.band(item_flags, ImGuiItemFlags.NoFocus) ~= 0 then
        flags = bit32.bor(flags, ImGuiButtonFlags.NoFocus, ImGuiButtonFlags.NoNavFocus)
    end

    -- Default only reacts to left mouse button
    if bit32.band(flags, ImGuiButtonFlags.MouseButtonMask_) == 0 then
        flags = bit32.bor(flags, ImGuiButtonFlags.MouseButtonLeft)
    end

    -- Default behavior requires click + release inside bounding box
    if bit32.band(flags, ImGuiButtonFlags.PressedOnMask_) == 0 then
        flags = bit32.bor(flags, (bit32.band(item_flags, ImGuiItemFlags.ButtonRepeat) ~= 0) and ImGuiButtonFlags.PressedOnClick or ImGuiButtonFlags.PressedOnDefault_)
    end

    local backup_hovered_window = g.HoveredWindow
    local flatten_hovered_children = (bit32.band(flags, ImGuiButtonFlags.FlattenChildren) ~= 0) and g.HoveredWindow and g.HoveredWindow.RootWindowDockTree == window.RootWindowDockTree
    if flatten_hovered_children then
        g.HoveredWindow = window
    end

    local pressed = false
    local hovered = ImGui.ItemHoverable(bb, id, item_flags)

    -- Special mode for Drag and Drop used by openables (tree nodes, tabs etc.)
    -- where holding the button pressed for a long time while drag a payload item triggers the button.
    if g.DragDropActive then
        if (bit32.band(flags, ImGuiButtonFlags.PressedOnDragDropHold) ~= 0) and (bit32.band(g.DragDropSourceFlags, ImGuiDragDropFlags.SourceNoHoldToOpenOthers) == 0) and ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByActiveItem) then
            hovered = true
            ImGui.SetHoveredID(id)

            if (g.HoveredIdTimer - g.IO.DeltaTime <= DRAGDROP_HOLD_TO_OPEN_TIMER) and (g.HoveredIdTimer >= DRAGDROP_HOLD_TO_OPEN_TIMER) then
                pressed = true
                g.DragDropHoldJustPressedId = id
                ImGui.FocusWindow(window)
            end
        end

        if (g.DragDropAcceptIdPrev == id) and (bit32.band(g.DragDropAcceptFlagsPrev, ImGuiDragDropFlags.AcceptDrawAsHovered) ~= 0) then
            hovered = true
        end
    end

    if (flatten_hovered_children) then
        g.HoveredWindow = backup_hovered_window
    end

    -- Mouse handling
    local test_owner_id = (bit32.band(flags, ImGuiButtonFlags.NoTestKeyOwner) ~= 0) and ImGuiKeyOwner_Any or id
    if hovered then
        IM_ASSERT(id ~= 0) -- Lazily check inside rare path.

        -- Poll mouse buttons
        -- - 'mouse_button_clicked' is generally carried into ActiveIdMouseButton when setting ActiveId.
        -- - Technically we only need some values in one code path, but since this is gated by hovered test this is fine.
        local mouse_button_clicked = -1
        local mouse_button_released = -1
        for button = 0, 2 do
            if bit32.band(flags, bit32.lshift(ImGuiButtonFlags.MouseButtonLeft, button)) ~= 0 then -- Handle ImGuiButtonFlags.MouseButtonRight and ImGuiButtonFlags.MouseButtonMiddle here.
                if (ImGui.IsMouseClickedEx(button, ImGuiInputFlags.None, test_owner_id) and mouse_button_clicked == -1) then mouse_button_clicked = button end
                if (ImGui.IsMouseReleased(button, test_owner_id) and mouse_button_released == -1) then mouse_button_released = button end
            end
        end

        -- Process initial action
        local mods_ok = (bit32.band(flags, ImGuiButtonFlags.NoKeyModsAllowed) == 0) or (not g.IO.KeyCtrl and not g.IO.KeyShift and not g.IO.KeyAlt)
        if mods_ok then
            if mouse_button_clicked ~= -1 and g.ActiveId ~= id then
                --- @cast mouse_button_clicked ImGuiMouseButton

                if bit32.band(flags, ImGuiButtonFlags.NoSetKeyOwner) == 0 then
                    ImGui.SetKeyOwner(ImGui.MouseButtonToKey(mouse_button_clicked), id)
                end

                if bit32.band(flags, bit32.bor(ImGuiButtonFlags.PressedOnClickRelease, ImGuiButtonFlags.PressedOnClickReleaseAnywhere)) ~= 0 then
                    ImGui.SetActiveID(id, window)
                    g.ActiveIdMouseButton = mouse_button_clicked

                    if bit32.band(flags, ImGuiButtonFlags.NoNavFocus) == 0 then
                        ImGui.SetFocusID(id, window)
                        ImGui.FocusWindow(window)
                    elseif bit32.band(flags, ImGuiButtonFlags.NoFocus) == 0 then
                        ImGui.FocusWindow(window, ImGuiFocusRequestFlags.RestoreFocusedChild) -- Still need to focus and bring to front, but try to avoid losing NavId when navigating a child
                    end
                end

                if (bit32.band(flags, ImGuiButtonFlags.PressedOnClick) ~= 0) or ((bit32.band(flags, ImGuiButtonFlags.PressedOnDoubleClick) ~= 0) and g.IO.MouseClickedCount[mouse_button_clicked] == 2) then
                    pressed = true

                    if bit32.band(flags, ImGuiButtonFlags.NoHoldingActiveId) ~= 0 then
                        ImGui.ClearActiveID()
                    else
                        ImGui.SetActiveID(id, window) -- Hold on ID
                    end

                    g.ActiveIdMouseButton = mouse_button_clicked

                    if bit32.band(flags, ImGuiButtonFlags.NoNavFocus) == 0 then
                        ImGui.SetFocusID(id, window)
                        ImGui.FocusWindow(window)
                    elseif bit32.band(flags, ImGuiButtonFlags.NoFocus) == 0 then
                        ImGui.FocusWindow(window, ImGuiFocusRequestFlags.RestoreFocusedChild) -- Still need to focus and bring to front, but try to avoid losing NavId when navigating a child
                    end
                end

                if bit32.band(flags, ImGuiButtonFlags.PressedOnRelease) ~= 0 then
                    -- FIXME: Traditionally ImGuiButtonFlags.PressedOnRelease never took ActiveId. Adding it in 2026-03-20 since ImGuiButtonFlags.NoHoldingActiveId can always be added.
                    -- We don't yet perform an explicit ClearActiveID() to reduce scope of change, but this possibility could be investigated.
                    if bit32.band(flags, ImGuiButtonFlags.NoHoldingActiveId) == 0 then
                        ImGui.SetActiveID(id, window) -- Hold on ID
                    end
                    g.ActiveIdMouseButton = mouse_button_clicked
                end
            end

            if bit32.band(flags, ImGuiButtonFlags.PressedOnRelease) ~= 0 then
                if mouse_button_released ~= -1 then
                    local has_repeated_at_least_once = (bit32.band(item_flags, ImGuiItemFlags.ButtonRepeat) ~= 0) and g.IO.MouseDownDurationPrev[mouse_button_released] >= g.IO.KeyRepeatDelay -- Repeat mode trumps on release behavior

                    if not has_repeated_at_least_once then
                        pressed = true
                    end

                    if bit32.band(flags, ImGuiButtonFlags.NoNavFocus) == 0 then
                        ImGui.SetFocusID(id, window) -- FIXME: Lack of FocusWindow() call here is inconsistent with other paths. Research why.
                    end

                    ImGui.ClearActiveID()
                end
            end

            -- 'Repeat' mode acts when held regardless of _PressedOn flags (see table above).
            -- Relies on repeat logic of IsMouseClicked() but we may as well do it ourselves if we end up exposing finer RepeatDelay/RepeatRate settings.
            if g.ActiveId == id and (bit32.band(item_flags, ImGuiItemFlags.ButtonRepeat) ~= 0) then
                if g.IO.MouseDownDuration[g.ActiveIdMouseButton] > 0.0 and ImGui.IsMouseClickedEx(g.ActiveIdMouseButton, ImGuiInputFlags.Repeat, test_owner_id) then
                    pressed = true
                end
            end
        end

        if pressed and g.IO.ConfigNavCursorVisibleAuto then
            g.NavCursorVisible = false
        end
    end

    -- Keyboard/Gamepad navigation handling
    -- We report navigated and navigation-activated items as hovered but we don't set g.HoveredId to not interfere with mouse.
    if bit32.band(item_flags, ImGuiItemFlags.Disabled) == 0 then
        if g.NavId == id and g.NavCursorVisible and g.NavHighlightItemUnderNav then
            if bit32.band(flags, ImGuiButtonFlags.NoHoveredOnFocus) == 0 then
                hovered = true
            end
        end
        if g.NavActivateDownId == id then
            local nav_activated_by_code = (g.NavActivateId == id)
            local nav_activated_by_inputs = (g.NavActivatePressedId == id)
            if not nav_activated_by_inputs and bit32.band(item_flags, ImGuiItemFlags.ButtonRepeat) ~= 0 then
                -- Avoid pressing multiple keys from triggering excessive amount of repeat events
                local key1 = ImGui.GetKeyData(g, ImGuiKey.Space)
                local key2 = ImGui.GetKeyData(g, ImGuiKey.Enter)
                local key3 = ImGui.GetKeyData(g, ImGuiKey.NavGamepadActivate)
                local t1 = ImMax(ImMax(key1.DownDuration, key2.DownDuration), key3.DownDuration)
                nav_activated_by_inputs = ImGui.CalcTypematicRepeatAmount(t1 - g.IO.DeltaTime, t1, g.IO.KeyRepeatDelay, g.IO.KeyRepeatRate) > 0
            end
            if nav_activated_by_code or nav_activated_by_inputs then
                -- Set active id so it can be queried by user via IsItemActive(), equivalent of holding the mouse button.
                pressed = true
                ImGui.SetActiveID(id, window)
                g.ActiveIdSource = g.NavInputSource
                if bit32.band(flags, ImGuiButtonFlags.NoNavFocus) == 0 and bit32.band(g.NavActivateFlags, ImGuiActivateFlags.FromShortcut) == 0 then
                    ImGui.SetFocusID(id, window)
                end
                if bit32.band(g.NavActivateFlags, ImGuiActivateFlags.FromShortcut) ~= 0 then
                    g.ActiveIdFromShortcut = true
                end
            end
        end
    end

    -- Process while held
    local held = false
    if g.ActiveId == id then
        if g.ActiveIdSource == ImGuiInputSource.Mouse then
            if g.ActiveIdIsJustActivated then
                g.ActiveIdClickOffset = g.IO.MousePos - bb.Min
            end

            local mouse_button = g.ActiveIdMouseButton
            if mouse_button == -1 then
                -- Fallback for the rare situation were g.ActiveId was set programmatically or from another widget (e.g. #6304).
                ImGui.ClearActiveID()
            elseif ImGui.IsMouseDown(mouse_button, test_owner_id) then
                held = true
            else
                local release_in = hovered and (bit32.band(flags, ImGuiButtonFlags.PressedOnClickRelease) ~= 0)
                local release_anywhere = (bit32.band(flags, ImGuiButtonFlags.PressedOnClickReleaseAnywhere) ~= 0)

                if (release_in or release_anywhere) and not g.DragDropActive then
                    -- Report as pressed when releasing the mouse (this is the most common path)
                    local is_double_click_release = (bit32.band(flags, ImGuiButtonFlags.PressedOnDoubleClick) ~= 0) and g.IO.MouseReleased[mouse_button] and g.IO.MouseClickedLastCount[mouse_button] == 2

                    local is_repeating_already = (bit32.band(item_flags, ImGuiItemFlags.ButtonRepeat) ~= 0) and g.IO.MouseDownDurationPrev[mouse_button] >= g.IO.KeyRepeatDelay -- Repeat mode trumps <on release>

                    local is_button_avail_or_owned = ImGui.TestKeyOwner(ImGui.MouseButtonToKey(mouse_button), test_owner_id)

                    if not is_double_click_release and not is_repeating_already and is_button_avail_or_owned then
                        pressed = true
                    end
                end

                ImGui.ClearActiveID()
            end

            if bit32.band(flags, ImGuiButtonFlags.NoNavFocus) == 0 and g.IO.ConfigNavCursorVisibleAuto then
                g.NavCursorVisible = false
            end
        elseif g.ActiveIdSource == ImGuiInputSource.Keyboard or g.ActiveIdSource == ImGuiInputSource.Gamepad then
            -- When activated using Nav, we hold on the ActiveID until activation button is released
            if g.NavActivateDownId == id then
                held = true -- hovered == true not true as we are already likely hovered on direct activation.
            else
                ImGui.ClearActiveID()
            end
        end

        if pressed then
            g.ActiveIdHasBeenPressedBefore = true
        end
    end

    -- Activation highlight (this may be a remote activation)
    if g.NavHighlightActivatedId == id and (bit32.band(item_flags, ImGuiItemFlags.Disabled) == 0) then
        hovered = true
    end

    return pressed, hovered, held
end

--- @param label     string
--- @param size_arg? ImVec2
--- @param flags?    ImGuiButtonFlags
--- @return bool
local ButtonEx_bb, ButtonEx_label_size, ButtonEx_size = ImRect(), ImVec2(), ImVec2()
local ButtonEx_text_min, ButtonEx_text_max = ImVec2(), ImVec2()

@native
function ImGui.ButtonEx(label, size_arg, flags)
    if size_arg == nil then size_arg = LAYOUT_ZERO_SIZE end -- [Luau] shared read-only: CalcItemSize() only reads it
    if flags    == nil then flags    = 0            end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local style = g.Style
    local id = window:GetID(label)
    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size = ButtonEx_label_size -- [Luau] scratch: only read below (RenderTextClipped text_size_if_known)
    label_size.x, label_size.y = ImGui.CalcTextSizeXY(label, 1, label_end, false)

    -- [Luau] scalar pos, no temporary ImVec2
    local pos_x, pos_y = window.DC.CursorPos.x, window.DC.CursorPos.y
    local frame_padding = style.FramePadding
    if bit32.band(flags, ImGuiButtonFlags.AlignTextBaseLine) ~= 0 and frame_padding.y < window.DC.CurrLineTextBaseOffset then -- Try to vertically align buttons that are smaller/have no padding so that text baseline matches (bit hacky, since it shouldn't be a flag)
        pos_y = pos_y + window.DC.CurrLineTextBaseOffset - frame_padding.y
    end
    local size = ButtonEx_size -- [Luau] scratch + scalar CalcItemSize(): ItemSize() only reads it
    size.x, size.y = ImGui._CalcItemSizeXY(size_arg.x, size_arg.y, label_size.x + frame_padding.x * 2.0, label_size.y + frame_padding.y * 2.0)

    local bb = ButtonEx_bb -- [Luau] scratch: ItemAdd() copies it, ButtonBehavior()/Render*() only read it
    bb.Min.x, bb.Min.y, bb.Max.x, bb.Max.y = pos_x, pos_y, pos_x + size.x, pos_y + size.y
    ImGui.ItemSize(size, frame_padding.y)
    if not ImGui.ItemAdd(bb, id) then
        return false
    end

    local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, flags)

    -- Render
    local col
    if held and hovered then
        col = ImGui.GetColorU32(ImGuiCol.ButtonActive)
    elseif hovered then
        col = ImGui.GetColorU32(ImGuiCol.ButtonHovered)
    else
        col = ImGui.GetColorU32(ImGuiCol.Button)
    end

    ImGui.RenderNavCursor(bb, id)
    ImGui.RenderFrame(bb.Min, bb.Max, col, true, style.FrameRounding)

    if g.LogEnabled then
        ImGui.LogSetNextTextDecoration("[", "]")
    end
    local text_min, text_max = ButtonEx_text_min, ButtonEx_text_max -- [Luau] scratch: RenderTextClipped() only reads them
    text_min.x = bb.Min.x + frame_padding.x; text_min.y = bb.Min.y + frame_padding.y
    text_max.x = bb.Max.x - frame_padding.x; text_max.y = bb.Max.y - frame_padding.y
    ImGui.RenderTextClipped(text_min, text_max, label, label_end, label_size, style.ButtonTextAlign, bb)

    -- Automatically close popups
    --if (pressed && !(flags & ImGuiButtonFlags.DontClosePopups) && (window->Flags & ImGuiWindowFlags.Popup))
    --    CloseCurrentPopup();

    -- IMGUI_TEST_ENGINE_ITEM_INFO(id, label, g.LastItemData.StatusFlags);
    return pressed
end

--- @param label     string
--- @param size_arg? ImVec2
--- @return bool
@native
function ImGui.Button(label, size_arg)
    return ImGui.ButtonEx(label, size_arg, ImGuiButtonFlags.None)
end

-- Small buttons fits within text without additional vertical spacing.
--- @param label string
--- @return bool
function ImGui.SmallButton(label)
    local g = GImGui
    local backup_padding_y = g.Style.FramePadding.y
    g.Style.FramePadding.y = 0.0
    local pressed = ImGui.ButtonEx(label, LAYOUT_ZERO_SIZE, ImGuiButtonFlags.AlignTextBaseLine) -- [Luau] shared read-only ImVec2(0, 0)
    g.Style.FramePadding.y = backup_padding_y
    return pressed
end

-- Tip: use ImGui.PushID()/PopID() to push indices or pointers in the ID stack.
-- Then you can keep 'str_id' empty or the same for all your buttons (instead of creating a string based on a non-string id)
--- @param str_id   string
--- @param size_arg ImVec2
--- @param flags?   ImGuiButtonFlags
local InvisibleButton_size, InvisibleButton_bb = ImVec2(), ImRect() -- [Luau] scratch for InvisibleButton(): only read by callees, never escape
function ImGui.InvisibleButton(str_id, size_arg, flags)
    if flags == nil then flags = 0 end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    -- Ensure zero-size fits to contents
    local size = InvisibleButton_size
    size.x, size.y = ImGui._CalcItemSizeXY(size_arg.x ~= 0.0 and size_arg.x or -FLT_MIN, size_arg.y ~= 0.0 and size_arg.y or -FLT_MIN, 0.0, 0.0)

    local id = window:GetID(str_id)
    local cursor = window.DC.CursorPos
    local bb = InvisibleButton_bb
    bb.Min.x, bb.Min.y, bb.Max.x, bb.Max.y = cursor.x, cursor.y, cursor.x + size.x, cursor.y + size.y
    ImGui.ItemSize(size)

    local item_flags = (bit32.band(flags, ImGuiButtonFlags.EnableNav) ~= 0) and ImGuiItemFlags.None or ImGuiItemFlags.NoNav
    if not ImGui.ItemAdd(bb, id, nil, item_flags) then
        return false
    end

    local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, flags)
    ImGui.RenderNavCursor(bb, id)

    -- IMGUI_TEST_ENGINE_ITEM_INFO(id, str_id, g.LastItemData.StatusFlags)
    return pressed
end

--- @param str_id string
--- @param dir    ImGuiDir
--- @param size   ImVec2
--- @param flags? ImGuiButtonFlags
local ArrowButton_bb, ArrowButton_pos, ArrowButton_size = ImRect(), ImVec2(), ImVec2() -- [Luau] scratch for ArrowButton[Ex](): only read by callees, never escape
function ImGui.ArrowButtonEx(str_id, dir, size, flags)
    if flags == nil then flags = 0 end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local id = window:GetID(str_id)
    local cursor = window.DC.CursorPos
    local bb = ArrowButton_bb
    bb.Min.x, bb.Min.y, bb.Max.x, bb.Max.y = cursor.x, cursor.y, cursor.x + size.x, cursor.y + size.y
    local default_size = ImGui.GetFrameHeight()
    ImGui.ItemSize(size, (size.y >= default_size) and g.Style.FramePadding.y or -1.0)
    if not ImGui.ItemAdd(bb, id) then
        return false
    end

    local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, flags)

    -- Render
    local bg_col = ImGui.GetColorU32((held and hovered) and ImGuiCol.ButtonActive or hovered and ImGuiCol.ButtonHovered or ImGuiCol.Button)
    local text_col = ImGui.GetColorU32(ImGuiCol.Text)
    ImGui.RenderNavCursor(bb, id)
    ImGui.RenderFrame(bb.Min, bb.Max, bg_col, true, g.Style.FrameRounding)
    local pos = ArrowButton_pos
    pos.x, pos.y = bb.Min.x + ImMax(0.0, (size.x - g.FontSize) * 0.5), bb.Min.y + ImMax(0.0, (size.y - g.FontSize) * 0.5)
    ImGui.RenderArrow(window.DrawList, pos, text_col, dir)

    -- IMGUI_TEST_ENGINE_ITEM_INFO(id, str_id, g.LastItemData.StatusFlags)
    return pressed
end

--- @param str_id string
--- @param dir    ImGuiDir
function ImGui.ArrowButton(str_id, dir)
    local sz = ImGui.GetFrameHeight()
    local size = ArrowButton_size; size.x = sz; size.y = sz -- [Luau] scratch, ArrowButtonEx() only reads it
    return ImGui.ArrowButtonEx(str_id, dir, size, ImGuiButtonFlags.None)
end

-- Button to close a window
--- @param id  ImGuiID
--- @param pos ImVec2
--- @return bool
function ImGui.CloseButton(id, pos)
    local g = GImGui

    local window = g.CurrentWindow

    -- Tweak 1: Shrink hit-testing area if button covers an abnormally large proportion of the visible region. That's in order to facilitate moving the window away. (#3825)
    -- This may better be applied as a general hit-rect reduction mechanism for all widgets to ensure the area to move window is always accessible?
    local bb = ImRect(pos, pos + ImVec2(g.FontSize, g.FontSize))
    local bb_interact = ImRect()
    ImRect_Copy(bb_interact, bb)

    local area_to_visible_ratio = window.OuterRectClipped:GetArea() / bb:GetArea()
    if area_to_visible_ratio < 1.5 then
        bb_interact:Expand(ImTrunc(bb_interact:GetSize() * -0.25))
    end

    -- Tweak 2: We intentionally allow interaction when clipped so that a mechanical Alt,Right,Activate sequence can always close a window.
    -- (this isn't the common behavior of buttons, but it doesn't affect the user because navigation tends to keep items visible in scrolling layer).
    local is_clipped = not ImGui.ItemAdd(bb_interact, id)

    local pressed, hovered, held = ImGui.ButtonBehavior(bb, id)
    if is_clipped then
        return pressed
    end

    -- Render
    local bg_col
    if held then
        bg_col = ImGui.GetColorU32(ImGuiCol.ButtonActive)
    else
        bg_col = ImGui.GetColorU32(ImGuiCol.ButtonHovered)
    end

    if hovered then
        window.DrawList:AddRectFilled(bb.Min, bb.Max, bg_col)
    end

    local cross_center = bb:GetCenter()
    local cross_extent = g.FontSize * 0.5 * 0.7071 - 1
    local cross_col = ImGui.GetColorU32(ImGuiCol.Text)
    local cross_thickness = 1.0 -- FIXME-DPI
    window.DrawList:AddLine(cross_center + ImVec2(cross_extent, cross_extent), cross_center + ImVec2(-cross_extent, -cross_extent), cross_col, cross_thickness)
    window.DrawList:AddLine(cross_center + ImVec2(cross_extent, -cross_extent), cross_center + ImVec2(-cross_extent, cross_extent), cross_col, cross_thickness)

    return pressed
end

--- @param window ImGuiWindow
--- @param axis   ImGuiAxis
--- @return ImGuiID
function ImGui.GetWindowScrollbarID(window, axis)
    if axis == ImGuiAxis.X then
        return window:GetID("#SCROLLX")
    else
        return window:GetID("#SCROLLY")
    end
end

-- Return scrollbar rectangle, must only be called for corresponding axis if window.ScrollbarX/Y is set.
--- @param window ImGuiWindow
--- @param axis   ImGuiAxis
--- @return ImRect
--- @nodiscard
function ImGui.GetWindowScrollbarRect(window, axis)
    local g = GImGui
    local outer_rect = window:Rect()
    local inner_rect = window.InnerRect

    -- (ScrollbarSizes.x = width of Y scrollbar; ScrollbarSizes.y = height of X scrollbar)
    local scrollbar_size = window.ScrollbarSizes[axis == ImGuiAxis.X and ImGuiAxis.Y or ImGuiAxis.X]
    IM_ASSERT(scrollbar_size >= 0.0)

    local border_size = IM_ROUND(window.WindowBorderSize * 0.5)
    local border_top = (bit32.band(window.Flags, ImGuiWindowFlags.MenuBar) ~= 0) and IM_ROUND(g.Style.FrameBorderSize * 0.5) or (bit32.band(window.Flags, ImGuiWindowFlags.NoTitleBar) ~= 0 and border_size or 0)

    if axis == ImGuiAxis.X then
        return ImRect(inner_rect.Min.x + border_size, ImMax(outer_rect.Min.y + border_size, outer_rect.Max.y - border_size - scrollbar_size), inner_rect.Max.x - border_size, outer_rect.Max.y - border_size)
    else
        return ImRect(ImMax(outer_rect.Min.x, outer_rect.Max.x - border_size - scrollbar_size), inner_rect.Min.y + border_top, outer_rect.Max.x - border_size, inner_rect.Max.y - border_size)
    end
end

--- @param window    ImGuiWindow
--- @param bb        ImRect
--- @param threshold float
--- @param axis      ImGuiAxis
function ImGui.ExtendHitBoxWhenNearViewportEdge(window, bb, threshold, axis)
    local window_rect = window.RootWindow:Rect()
    local viewport_rect = window.Viewport:GetMainRect()

    if window_rect.Min[axis] == viewport_rect.Min[axis] and bb.Min[axis] > window_rect.Min[axis] and bb.Min[axis] - threshold <= window_rect.Min[axis] then
        bb.Min[axis] = window_rect.Min[axis]
    end

    if window_rect.Max[axis] == viewport_rect.Max[axis] and bb.Max[axis] < window_rect.Max[axis] and bb.Max[axis] + threshold >= window_rect.Max[axis] then
        bb.Max[axis] = window_rect.Max[axis]
    end
end

-- Vertical/Horizontal scrollbar
-- The entire piece of code below is rather confusing because:
-- - We handle absolute seeking (when first clicking outside the grab) and relative manipulation (afterward or when clicking inside the grab)
-- - We store values as normalized ratio and in a form that allows the window content to change while we are holding on a scrollbar
-- - We handle both horizontal and vertical scrollbars, which makes the terminology not ideal.
-- Still, the code should probably be made simpler..
--- @param bb_frame            ImRect
--- @param id                  ImGuiID
--- @param axis                ImGuiAxis
--- @param p_scroll_v          number
--- @param size_visible_v      number
--- @param size_contents_v     number
--- @param draw_rounding_flags ImDrawFlags
--- @return bool   is_held
--- @return number scroll_v # Updated p_scroll_v
function ImGui.ScrollbarEx(bb_frame, id, axis, p_scroll_v, size_visible_v, size_contents_v, draw_rounding_flags)
    local g = GImGui
    local window = g.CurrentWindow
    if window.SkipItems then
        return false, p_scroll_v
    end

    local bb_frame_width = bb_frame:GetWidth()
    local bb_frame_height = bb_frame:GetHeight()
    if bb_frame_width <= 0.0 or bb_frame_height <= 0.0 then
        return false, p_scroll_v
    end

    -- When we are too small, start hiding and disabling the grab (this reduce visual noise on very small window and facilitate using the window resize grab)
    local alpha = 1.0
    if axis == ImGuiAxis.Y and bb_frame_height < bb_frame_width then
        alpha = ImSaturate(bb_frame_height / ImMax(bb_frame_width * 2.0, 1.0))
    end
    if alpha <= 0.0 then
        return false, p_scroll_v
    end

    local style = g.Style
    local allow_interaction = (alpha >= 1.0)

    local bb = ImRect()
    ImRect_Copy(bb, bb_frame)

    local padding = IM_TRUNC(ImMin(style.ScrollbarPadding, ImMin(bb_frame_width, bb_frame_height) * 0.5))
    bb:Expand(-padding)

    -- V denote the main, longer axis of the scrollbar (= height for a vertical scrollbar)
    local scrollbar_size_v
    if axis == ImGuiAxis.X then
        scrollbar_size_v = bb:GetWidth()
    else
        scrollbar_size_v = bb:GetHeight()
    end

    if scrollbar_size_v < 1.0 then
        return false, p_scroll_v
    end

    -- Calculate the height of our grabbable box. It generally represent the amount visible (vs the total scrollable amount)
    -- But we maintain a minimum size in pixel to allow for the user to still aim inside.
    IM_ASSERT(ImMax(size_contents_v, size_visible_v) > 0.0) -- Adding this assert to check if the ImMax(XXX,1.0f) is still needed. PLEASE CONTACT ME if this triggers.
    local win_size_v = ImMax(ImMax(size_contents_v, size_visible_v), 1)
    local grab_h_minsize = ImMin(bb:GetSize()[axis], style.GrabMinSize)
    local grab_h_pixels = ImTrunc(ImClamp(scrollbar_size_v * (size_visible_v / win_size_v), grab_h_minsize, scrollbar_size_v))
    local grab_h_norm = grab_h_pixels / scrollbar_size_v

    -- As a special thing, we allow scrollbar near the edge of a screen/viewport to be reachable with mouse at the extreme edge (#9276)
    local bb_hit = ImRect()
    ImRect_Copy(bb_hit, bb_frame)
    ImGui.ExtendHitBoxWhenNearViewportEdge(window, bb_hit, g.Style.WindowBorderSize, ImGuiAxis.X + ImGuiAxis.Y - axis) -- [Port] swap axis here

    -- Handle input right away. None of the code of Begin() is relying on scrolling position before calling Scrollbar().
    ImGui.ItemAdd(bb_frame, id, nil, ImGuiItemFlags.NoNav)
    local pressed, hovered, held = ImGui.ButtonBehavior(bb_hit, id, ImGuiButtonFlags.NoNavFocus)

    local scroll_max = ImMax(1, size_contents_v - size_visible_v)
    local scroll_ratio = ImSaturate(p_scroll_v / scroll_max)
    local grab_v_norm = scroll_ratio * (scrollbar_size_v - grab_h_pixels) / scrollbar_size_v -- Grab position in normalized space
    if held and allow_interaction and grab_h_norm < 1.0 then
        local scrollbar_pos_v = bb.Min[axis]
        local mouse_pos_v = g.IO.MousePos[axis]

        -- Click position in scrollbar normalized space (0.0f->1.0f)
        local clicked_v_norm = ImSaturate((mouse_pos_v - scrollbar_pos_v) / scrollbar_size_v)

        local held_dir
        if clicked_v_norm < grab_v_norm then
            held_dir = -1
        elseif clicked_v_norm > grab_v_norm + grab_h_norm then
            held_dir = 1
        else
            held_dir = 0
        end
        if g.ActiveIdIsJustActivated then
            -- On initial click when held_dir == 0 (clicked over grab): calculate the distance between mouse and the center of the grab
            local scroll_to_clicked_location = (g.IO.ConfigScrollbarScrollByPage == false) or g.IO.KeyShift or held_dir == 0

            if scroll_to_clicked_location then
                g.ScrollbarSeekMode = 0
            else
                g.ScrollbarSeekMode = held_dir
            end

            if held_dir == 0 and not g.IO.KeyShift then
                g.ScrollbarClickDeltaToGrabCenter = clicked_v_norm - grab_v_norm - grab_h_norm * 0.5
            else
                g.ScrollbarClickDeltaToGrabCenter = 0.0
            end
        end

        -- Apply scroll (p_scroll_v will generally point on one member of window.Scroll)
        -- It is ok to modify Scroll here because we are being called in Begin() after the calculation of ContentSize and before setting up our starting position
        if g.ScrollbarSeekMode == 0 then
            -- Absolute seeking
            scroll_v_norm = ImSaturate((clicked_v_norm - g.ScrollbarClickDeltaToGrabCenter - grab_h_norm * 0.5) / (1.0 - grab_h_norm))
            p_scroll_v = scroll_v_norm * scroll_max
        else
            -- Page by page
            if ImGui.IsMouseClickedEx(ImGuiMouseButton.Left, ImGuiInputFlags.Repeat) and held_dir == g.ScrollbarSeekMode then
                local page_dir
                if g.ScrollbarSeekMode > 0.0 then
                    page_dir = 1.0
                else
                    page_dir = -1.0
                end
                p_scroll_v = ImClamp(p_scroll_v + page_dir * size_visible_v, 0, scroll_max)
            end
        end

        -- Update values for rendering
        scroll_ratio = ImSaturate(p_scroll_v / scroll_max)
        grab_v_norm = scroll_ratio * (scrollbar_size_v - grab_h_pixels) / scrollbar_size_v

        -- Update distance to grab now that we have seek'ed and saturated
        --if (seek_absolute)
        --    g.ScrollbarClickDeltaToGrabCenter = clicked_v_norm - grab_v_norm - grab_h_norm * 0.5f;
    end

    -- Render
    local bg_col = ImGui.GetColorU32(ImGuiCol.ScrollbarBg)
    local grab_col
    if held then
        grab_col = ImGui.GetColorU32(ImGuiCol.ScrollbarGrabActive, alpha)
    elseif hovered then
        grab_col = ImGui.GetColorU32(ImGuiCol.ScrollbarGrabHovered, alpha)
    else
        grab_col = ImGui.GetColorU32(ImGuiCol.ScrollbarGrab, alpha)
    end
    window.DrawList:AddRectFilled(bb_frame.Min, bb_frame.Max, bg_col, window.WindowRounding, draw_rounding_flags)
    local grab_rect
    if axis == ImGuiAxis.X then
        local x1 = ImLerp(bb.Min.x, bb.Max.x, grab_v_norm)
        grab_rect = ImRect(x1, bb.Min.y, x1 + grab_h_pixels, bb.Max.y)
    else
        local y1 = ImLerp(bb.Min.y, bb.Max.y, grab_v_norm)
        grab_rect = ImRect(bb.Min.x, y1, bb.Max.x, y1 + grab_h_pixels)
    end

    window.DrawList:AddRectFilled(grab_rect.Min, grab_rect.Max, grab_col, style.ScrollbarRounding)

    return held, p_scroll_v
end

--- @param axis ImGuiAxis
function ImGui.Scrollbar(axis)
    local g = GImGui
    local window = g.CurrentWindow
    local id = ImGui.GetWindowScrollbarID(window, axis)

    -- Calculate scrollbar bounding box
    local bb = ImGui.GetWindowScrollbarRect(window, axis)
    local rounding_corners = ImGui.CalcRoundingFlagsForRectInRect(bb, window:Rect(), g.Style.WindowBorderSize)
    local k = (axis == ImGuiAxis.X) and "x" or "y" -- [Luau] named key: ImVec2[axis] goes through IM_VEC2.__index
    local size_visible = window.InnerRect.Max[k] - window.InnerRect.Min[k]
    local size_contents = window.ContentSize[k] + window.WindowPadding[k] * 2.0
    local scroll = window.Scroll[k]
    local held
    held, scroll = ImGui.ScrollbarEx(bb, id, axis, scroll, size_visible, size_contents, rounding_corners)
    window.Scroll[k] = scroll
end

-- - Read about ImTextureID/ImTextureRef here: https://github.com/ocornut/imgui/wiki/Image-Loading-and-Displaying-Examples
-- - 'uv0' and 'uv1' are texture coordinates. Read about them from the same link above.
--- @param tex_ref    ImTextureRef
--- @param image_size ImVec2
--- @param uv0?       ImVec2
--- @param uv1?       ImVec2
--- @param bg_col?    ImVec4
--- @param tint_col?  ImVec4
function ImGui.ImageWithBg(tex_ref, image_size, uv0, uv1, bg_col, tint_col)
    if uv0      == nil then uv0      = ImVec2(0, 0)       end
    if uv1      == nil then uv1      = ImVec2(1, 1)       end
    if bg_col   == nil then bg_col   = ImVec4(0, 0, 0, 0) end
    if tint_col == nil then tint_col = ImVec4(1, 1, 1, 1) end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return
    end

    local g = GImGui
    local padding = ImVec2(g.Style.ImageBorderSize, g.Style.ImageBorderSize)
    local bb = ImRect(window.DC.CursorPos, window.DC.CursorPos + image_size + padding * 2.0)
    ImGui.ItemSize(bb)
    if not ImGui.ItemAdd(bb, 0) then
        return
    end

    -- Render
    local rounding = g.Style.ImageRounding
    if bg_col.w > 0.0 then
        window.DrawList:AddRectFilled(bb.Min + padding, bb.Max - padding, ImGui.GetColorU32(bg_col), rounding)
    end
    if rounding > 0.0 then
        window.DrawList:AddImageRounded(tex_ref, bb.Min + padding, bb.Max - padding, uv0, uv1, ImGui.GetColorU32(tint_col), rounding)
    else
        window.DrawList:AddImage(tex_ref, bb.Min + padding, bb.Max - padding, uv0, uv1, ImGui.GetColorU32(tint_col))
    end
    if g.Style.ImageBorderSize > 0.0 then
        window.DrawList:AddRect(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.Border), rounding, g.Style.ImageBorderSize, ImDrawFlags.None)
    end
end

--- @param tex_ref    ImTextureRef
--- @param image_size ImVec2
--- @param uv0?       ImVec2
--- @param uv1?       ImVec2
function ImGui.Image(tex_ref, image_size, uv0, uv1)
    ImGui.ImageWithBg(tex_ref, image_size, uv0, uv1)
end

--- @param id         ImGuiID
--- @param tex_ref    ImTextureRef
--- @param image_size ImVec2
--- @param uv0        ImVec2
--- @param uv1        ImVec2
--- @param bg_col     ImVec4
--- @param tint_col   ImVec4
--- @param flags?     ImGuiButtonFlags
function ImGui.ImageButtonEx(id, tex_ref, image_size, uv0, uv1, bg_col, tint_col, flags)
    if flags == nil then flags = 0 end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local padding = g.Style.FramePadding
    local bb = ImRect(window.DC.CursorPos, window.DC.CursorPos + image_size + padding * 2.0)
    ImGui.ItemSize(bb)
    if not ImGui.ItemAdd(bb, id) then
        return false
    end

    local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, flags)

    -- Render
    local col = ImGui.GetColorU32((held and hovered) and ImGuiCol.ButtonActive or hovered and ImGuiCol.ButtonHovered or ImGuiCol.Button)
    ImGui.RenderNavCursor(bb, id)
    ImGui.RenderFrame(bb.Min, bb.Max, col, true, g.Style.FrameRounding)
    if bg_col.w > 0.0 then
        window.DrawList:AddRectFilled(bb.Min + padding, bb.Max - padding, ImGui.GetColorU32(bg_col))
    end
    local image_rounding = ImMax(g.Style.FrameRounding - ImMax(padding.x, padding.y), g.Style.ImageRounding)
    if image_rounding > 0.0 then
        window.DrawList:AddImageRounded(tex_ref, bb.Min + padding, bb.Max - padding, uv0, uv1, ImGui.GetColorU32(tint_col), image_rounding)
    else
        window.DrawList:AddImage(tex_ref, bb.Min + padding, bb.Max - padding, uv0, uv1, ImGui.GetColorU32(tint_col))
    end

    return pressed
end

-- - ImageButton() adds style.FramePadding*2.0f to provided size. This is in order to facilitate fitting an image in a button.
-- - ImageButton() draws a background based on regular Button() color + optionally an inner background if specified. (#8165) -- FIXME: Maybe that's not the best design?
--- @param str_id     string
--- @param tex_ref    ImTextureRef
--- @param image_size ImVec2
--- @param uv0        ImVec2
--- @param uv1        ImVec2
--- @param bg_col     ImVec4
--- @param tint_col   ImVec4
function ImGui.ImageButton(str_id, tex_ref, image_size, uv0, uv1, bg_col, tint_col)
    local g = GImGui
    local window = g.CurrentWindow
    if window.SkipItems then
        return false
    end

    return ImGui.ImageButtonEx(window:GetID(str_id), tex_ref, image_size, uv0, uv1, bg_col, tint_col)
end

--- @param label string
--- @param v     bool
--- @return bool is_pressed
--- @return bool is_checked # The updated `v` passed in
local Checkbox_total_bb, Checkbox_check_bb, Checkbox_label_pos, Checkbox_mark_pos = ImRect(), ImRect(), ImVec2(), ImVec2() -- [Luau] scratch, only read by callees

@native
function ImGui.Checkbox(label, v)
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false, v
    end

    local g = GImGui
    local style = g.Style
    local id = window:GetID(label)
    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size_x, label_size_y = ImGui.CalcTextSizeXY(label, 1, label_end, false) -- [Luau] scalar label_size

    local square_sz = g.FontSize + style.FramePadding.y * 2.0 -- [Luau] inline GetFrameHeight()
    local pos_x, pos_y = window.DC.CursorPos.x, window.DC.CursorPos.y -- [Luau] scalar pos, no temporary ImVec2

    local total_width
    if label_size_x > 0.0 then
        total_width = square_sz + style.ItemInnerSpacing.x + label_size_x
    else
        total_width = square_sz
    end
    local total_bb = Checkbox_total_bb
    total_bb.Min.x, total_bb.Min.y, total_bb.Max.x, total_bb.Max.y = pos_x, pos_y, pos_x + total_width, pos_y + (label_size_y + style.FramePadding.y * 2.0)
    ImGui.ItemSize(total_bb, style.FramePadding.y)
    local is_visible = ImGui.ItemAdd(total_bb, id)
    local is_multi_select = (bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.IsMultiSelect) ~= 0)
    if not is_visible then
        if not is_multi_select or not g.BoxSelectState.UnclipMode or not g.BoxSelectState.UnclipRect:Overlaps(total_bb) then -- Extra layer of "no logic clip" for box-select support
            -- IMGUI_TEST_ENGINE_ITEM_INFO(id, label, g.LastItemData.StatusFlags | ImGuiItemStatusFlags_Checkable | (*v ? ImGuiItemStatusFlags_Checked : 0))
            return false, v
        end
    end

    -- Range-Selection/Multi-selection support (header)
    local checked = v
    if is_multi_select then
        checked = ImGui.MultiSelectItemHeader(id, checked, nil)
    end

    local pressed, hovered, held = ImGui.ButtonBehavior(total_bb, id)

    -- Range-Selection/Multi-selection support (footer)
    if is_multi_select then
        checked, pressed = ImGui.MultiSelectItemFooter(id, checked, pressed, ImGuiMultiSelectFlags.CheckboxMode_)
    elseif pressed then
        checked = not checked
    end

    if v ~= checked then
        v = checked
        pressed = true -- return value
        ImGui.MarkItemEdited(id)
    end

    local check_bb = Checkbox_check_bb
    check_bb.Min.x, check_bb.Min.y, check_bb.Max.x, check_bb.Max.y = pos_x, pos_y, pos_x + square_sz, pos_y + square_sz
    local mixed_value = (bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue) ~= 0)
    if is_visible then
        ImGui.RenderNavCursor(total_bb, id)

        local bg_col = ImGui.GetColorU32((held and hovered) and ImGuiCol.FrameBgActive or (hovered and ImGuiCol.FrameBgHovered or ((mixed_value or checked) and ImGuiCol.CheckboxSelectedBg or ImGuiCol.FrameBg)))
        local check_col = ImGui.GetColorU32(ImGuiCol.CheckMark)
        ImGui.RenderFrame(check_bb.Min, check_bb.Max, bg_col, true, style.FrameRounding)

        if mixed_value then
            -- Undocumented tristate/mixed/indeterminate checkbox (#2644)
            -- This may seem awkwardly designed because the aim is to make ImGuiItemFlags.MixedValue supported by all widgets (not just checkbox)
            local pad_val = ImMax(1.0, IM_TRUNC(square_sz / 3.6))
            local pad = ImVec2(pad_val, pad_val)
            window.DrawList:AddRectFilled(check_bb.Min + pad, check_bb.Max - pad, check_col, style.FrameRounding)
        elseif v then
            local pad = ImMax(1.0, IM_TRUNC(square_sz / 6.0))
            local mark_pos = Checkbox_mark_pos -- [Luau] check_bb.Min + ImVec2(pad, pad) into scratch
            mark_pos.x, mark_pos.y = check_bb.Min.x + pad, check_bb.Min.y + pad
            ImGui.RenderCheckMark(window.DrawList, mark_pos, check_col, square_sz - pad * 2.0)
        end
    end

    if g.LogEnabled then
        ImGui.LogRenderedText(ImVec2(check_bb.Max.x + style.ItemInnerSpacing.x, check_bb.Min.y + style.FramePadding.y), mixed_value and "[~]" or (v and "[x]" or "[ ]")) -- label_pos
    end

    if is_visible and label_size_x > 0.0 then
        local label_pos = Checkbox_label_pos
        label_pos.x, label_pos.y = check_bb.Max.x + style.ItemInnerSpacing.x, check_bb.Min.y + style.FramePadding.y
        ImGui.RenderText(label_pos, label, 1, label_end, false)
    end

    -- IMGUI_TEST_ENGINE_ITEM_INFO(id, label, g.LastItemData.StatusFlags | ImGuiItemStatusFlags_Checkable | (*v ? ImGuiItemStatusFlags_Checked : 0))
    return pressed, v
end

--- @param label       string
--- @param flags       int
--- @param flags_value int
--- @return bool is_pressed
--- @return int  flags_new  # Updated `flags`
function ImGui.CheckboxFlags(label, flags, flags_value)
    local all_on = bit32.band(flags, flags_value) == flags_value
    local any_on = bit32.band(flags, flags_value) ~= 0
    local pressed
    if not all_on and any_on then
        local g = GImGui
        g.NextItemData.ItemFlagsSet = bit32.bor(g.NextItemData.ItemFlagsSet, ImGuiItemFlags.MixedValue)
        pressed, all_on = ImGui.Checkbox(label, all_on)
    else
        pressed, all_on = ImGui.Checkbox(label, all_on)
    end
    if pressed then
        if all_on then
            flags = bit32.bor(flags, flags_value)
        else
            flags = bit32.band(flags, bit32.bnot(flags_value))
        end
    end

    return pressed, flags
end
ImGui.CheckboxFlagsT = ImGui.CheckboxFlags

--- @param label  string
--- @param active bool
--- @return bool is_pressed
-- [Luau] scratch for RadioButtonEx(): only read by its callees (ItemAdd() copies total_bb), never escape
local RadioButton_total_bb, RadioButton_center, RadioButton_label_pos = ImRect(), ImVec2(), ImVec2()
function ImGui.RadioButtonEx(label, active)
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local style = g.Style
    local id = window:GetID(label)
    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size_x, label_size_y = ImGui.CalcTextSizeXY(label, 1, label_end, false) -- [Luau] scalar label_size

    local square_sz = g.FontSize + style.FramePadding.y * 2.0 -- [Luau] inline GetFrameHeight()
    local pos_x, pos_y = window.DC.CursorPos.x, window.DC.CursorPos.y -- [Luau] scalar pos, no temporary ImVec2
    local check_bb_min_x, check_bb_min_y, check_bb_max_x, check_bb_max_y = pos_x, pos_y, pos_x + square_sz, pos_y + square_sz -- [Luau] scalar check_bb
    local total_bb = RadioButton_total_bb
    total_bb.Min.x, total_bb.Min.y, total_bb.Max.x, total_bb.Max.y = pos_x, pos_y, pos_x + (square_sz + (label_size_x > 0.0 and style.ItemInnerSpacing.x + label_size_x or 0.0)), pos_y + (label_size_y + style.FramePadding.y * 2.0)
    ImGui.ItemSize(total_bb, style.FramePadding.y)
    if not ImGui.ItemAdd(total_bb, id) then
        return false
    end

    local center = RadioButton_center -- [Luau] check_bb:GetCenter() into scratch
    center.x = IM_ROUND((check_bb_min_x + check_bb_max_x) * 0.5)
    center.y = IM_ROUND((check_bb_min_y + check_bb_max_y) * 0.5)
    local radius = (square_sz - 1.0) * 0.5

    local pressed, hovered, held = ImGui.ButtonBehavior(total_bb, id)
    if (pressed) then
        ImGui.MarkItemEdited(id)
    end

    ImGui.RenderNavCursor(total_bb, id)
    local num_segment = window.DrawList:_CalcCircleAutoSegmentCount(radius)
    local col
    if held and hovered then
        col = ImGui.GetColorU32(ImGuiCol.FrameBgActive)
    else
        if hovered then
            col = ImGui.GetColorU32(ImGuiCol.FrameBgHovered)
        else
            col = ImGui.GetColorU32(ImGuiCol.FrameBg)
        end
    end
    window.DrawList:AddCircleFilled(center, radius, col, num_segment)
    if active then
        local pad = ImMax(1.0, IM_TRUNC(square_sz / 6.0))
        window.DrawList:AddCircleFilled(center, radius - pad, ImGui.GetColorU32(ImGuiCol.CheckMark))
    end
    if style.FrameBorderSize > 0.0 then
        window.DrawList:AddCircle(center + ImVec2(1, 1), radius, ImGui.GetColorU32(ImGuiCol.BorderShadow), num_segment, style.FrameBorderSize)
        window.DrawList:AddCircle(center, radius, ImGui.GetColorU32(ImGuiCol.Border), num_segment, style.FrameBorderSize)
    end
    local label_pos = RadioButton_label_pos
    label_pos.x, label_pos.y = check_bb_max_x + style.ItemInnerSpacing.x, check_bb_min_y + style.FramePadding.y
    if g.LogEnabled then
        ImGui.LogRenderedText(label_pos, active and "(x)" or "( )")
    end
    if label_size_x > 0.0 then
        ImGui.RenderText(label_pos, label, 1, label_end, false)
    end

    return pressed
end

-- [Port] `rawequal` is used here to check if v == v_button
--- @param label    string
--- @param v        any
--- @param v_button any
--- @return bool is_pressed
--- @return any  v          # Updated v
function ImGui.RadioButton(label, v, v_button)
    local pressed = ImGui.RadioButtonEx(label, rawequal(v, v_button))
    if pressed then
        v = v_button
    end
    return pressed, v
end

-- size_arg (for each axis) < 0.0f: align to end, 0.0f: auto, > 0.0f: specified size
--- @param fraction  float
--- @param size_arg? ImVec2
--- @param overlay?  string
local ProgressBar_size_arg_default = ImVec2(-FLT_MIN, 0) -- [Luau] shared read-only default (CalcItemSize() only reads it)
local ProgressBar_size, ProgressBar_overlay_pos, ProgressBar_overlay_align = ImVec2(), ImVec2(), ImVec2(0.0, 0.5) -- [Luau] scratch / shared read-only, only read by RenderTextClipped()
function ImGui.ProgressBar(fraction, size_arg, overlay)
    if size_arg == nil then size_arg = ProgressBar_size_arg_default end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return
    end

    local g = GImGui
    local style = g.Style

    local pos = window.DC.CursorPos -- [Luau] only read before ItemSize() moves the cursor
    local size_x, size_y = ImGui._CalcItemSizeXY(size_arg.x, size_arg.y, ImGui.CalcItemWidth(), g.FontSize + style.FramePadding.y * 2.0) -- [Luau] scalar size
    local bb = ImRect(pos.x, pos.y, pos.x + size_x, pos.y + size_y)
    local size = ProgressBar_size; size.x = size_x; size.y = size_y -- [Luau] scratch, ItemSize() only reads it
    ImGui.ItemSize(size, style.FramePadding.y)
    if not ImGui.ItemAdd(bb, 0) then
        return
    end

    -- Fraction < 0.0f will display an indeterminate progress bar animation
    -- The value must be animated along with time, so e.g. passing '-1.0f * ImGui.GetTime()' as fraction works.
    local is_indeterminate = (fraction < 0.0)
    if not is_indeterminate then
        fraction = ImSaturate(fraction)
    end

    -- Out of courtesy we accept a NaN fraction without crashing
    local fill_n0 = 0.0
    local fill_n1 = (fraction == fraction) and fraction or 0.0

    if is_indeterminate then
        local fill_width_n = 0.2
        fill_n0 = ImFmod(-fraction, 1.0) * (1.0 + fill_width_n) - fill_width_n
        fill_n1 = ImSaturate(fill_n0 + fill_width_n)
        fill_n0 = ImSaturate(fill_n0)
    end

    -- Render
    ImGui.RenderFrame(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.FrameBg), true, style.FrameRounding)
    bb:Expand(-style.FrameBorderSize) -- [Luau] == Expand(ImVec2(-style.FrameBorderSize, -style.FrameBorderSize))

    local fill_x0 = ImLerp(bb.Min.x, bb.Max.x, fill_n0)
    local fill_x1 = ImLerp(bb.Min.x, bb.Max.x, fill_n1)
    if fill_x0 < fill_x1 then
        ImGui.RenderRectFilledInRangeH(window.DrawList, bb, ImGui.GetColorU32(ImGuiCol.PlotHistogram), fill_x0, fill_x1, style.FrameRounding)
    end

    -- Default displaying the fraction as percentage string, but user can override it
    -- Don't display text for indeterminate bars by default
    if not is_indeterminate or overlay ~= nil then
        if overlay == nil then
            overlay = ImFormatString("%.0f%%", fraction * 100 + 0.01)
        end

        local overlay_size = ImGui.CalcTextSize(overlay, nil)
        if overlay_size.x > 0.0 then
            local text_x = is_indeterminate and ((bb.Min.x + bb.Max.x - overlay_size.x) * 0.5) or (fill_x1 + style.ItemSpacing.x)
            local overlay_pos = ProgressBar_overlay_pos
            overlay_pos.x, overlay_pos.y = ImClamp(text_x, bb.Min.x, bb.Max.x - overlay_size.x - style.ItemInnerSpacing.x), bb.Min.y
            ImGui.RenderTextClipped(overlay_pos, bb.Max, overlay, nil, overlay_size, ProgressBar_overlay_align, bb)
        end
    end
end

local Bullet_bb, Bullet_pos = ImRect(), ImVec2() -- [Luau] scratch for Bullet(): only read by its callees (ItemAdd() copies bb), never escape
function ImGui.Bullet()
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return
    end

    local g = GImGui
    local style = g.Style
    local line_height = ImMax(ImMin(window.DC.CurrLineSize.y, g.FontSize + style.FramePadding.y * 2), g.FontSize)
    local cursor = window.DC.CursorPos
    local bb = Bullet_bb
    bb.Min.x, bb.Min.y, bb.Max.x, bb.Max.y = cursor.x, cursor.y, cursor.x + g.FontSize, cursor.y + line_height
    ImGui.ItemSize(bb)
    if not ImGui.ItemAdd(bb, 0) then
        ImGui.SameLine(0, style.FramePadding.x * 2)
        return
    end

    -- Render and stay on same line
    local text_col = ImGui.GetColorU32(ImGuiCol.Text)
    local pos = Bullet_pos
    pos.x, pos.y = bb.Min.x + (style.FramePadding.x + g.FontSize * 0.5), bb.Min.y + line_height * 0.5
    ImGui.RenderBullet(window.DrawList, pos, text_col)
    ImGui.SameLine(0, style.FramePadding.x * 2.0)
end

-- This is provided as a convenience for being an often requested feature.
-- FIXME-STYLE: we delayed adding as there is a larger plan to revamp the styling system.
-- Because of this we currently don't provide many styling options for this widget
-- (e.g. hovered/active colors are automatically inferred from a single color).
--- @param label string
function ImGui.TextLink(label)
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local id = window:GetID(label)
    local label_end = ImGui.FindRenderedTextEnd(label)

    local pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y + window.DC.CurrLineTextBaseOffset)
    local size = ImGui.CalcTextSize(label, label_end, false)
    local bb = ImRect(pos, pos + size)
    ImGui.ItemSize(size, 0.0)
    if not ImGui.ItemAdd(bb, id) then
        return false
    end

    local pressed, hovered, held = ImGui.ButtonBehavior(bb, id)
    ImGui.RenderNavCursor(bb, id)

    if hovered then
        ImGui.SetMouseCursor(ImGuiMouseCursor.Hand)
    end

    local text_colf = ImVec4()
    ImVec4_Copy(text_colf, g.Style.Colors[ImGuiCol.TextLink])
    local line_colf = ImVec4()
    ImVec4_Copy(line_colf, text_colf)
    do
        -- FIXME-STYLE: Read comments above. This widget is NOT written in the same style as some earlier widgets,
        -- as we are currently experimenting/planning a different styling system.
        local h, s, v = ImGui.ColorConvertRGBtoHSV(text_colf.x, text_colf.y, text_colf.z)
        if held or hovered then
            v = ImSaturate(v + (held and 0.4 or 0.3))
            h = ImFmod(h + 0.02, 1.0)
        end
        text_colf.x, text_colf.y, text_colf.z = ImGui.ColorConvertHSVtoRGB(h, s, v)
        v = ImSaturate(v - 0.20)
        line_colf.x, line_colf.y, line_colf.z = ImGui.ColorConvertHSVtoRGB(h, s, v)
    end

    local line_y = bb.Max.y + ImFloor(g.FontBaked.Descent * g.FontBakedScale * 0.20)
    window.DrawList:AddLineH(bb.Min.x, bb.Max.x, line_y, ImGui.GetColorU32(line_colf), 1.0 * ImTrunc(g.Style._MainScale)) -- FIXME-TEXT: Underline mode -- FIXME-DPI

    ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(text_colf))
    ImGui.RenderText(bb.Min, label, 1, label_end, false)
    ImGui.PopStyleColor()

    -- IMGUI_TEST_ENGINE_ITEM_INFO(id, label, g.LastItemData.StatusFlags)
    return pressed
end

--- @param label string
--- @param url   string
function ImGui.TextLinkOpenURL(label, url)
    local g = GImGui
    if url == nil then
        url = label
    end
    local pressed = ImGui.TextLink(label)
    if pressed and g.PlatformIO.Platform_OpenInShellFn ~= nil then
        g.PlatformIO.Platform_OpenInShellFn(g, url)
    end

    ImGui.SetItemTooltip(ImGui.LocalizeGetMsg(ImGuiLocKey.OpenLink_s), url) -- It is more reassuring for user to _always_ display URL when it is the same as the label.

    if ImGui.BeginPopupContextItem() then
        if ImGui.MenuItem(ImGui.LocalizeGetMsg(ImGuiLocKey.CopyLink)) then
            ImGui.SetClipboardText(url)
        end
        ImGui.EndPopup()
    end

    return pressed
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: Low-level Layout helpers
-------------------------------------------------------------------------------
-- - Spacing()
-- - Dummy()
-- - NewLine()
-- - AlignTextToFramePadding()
-- - SeparatorEx() [Internal]
-- - Separator()
-------------------------------------------------------------------------------

local LayoutHelpers_size = ImVec2()   -- [Luau] scratch for ItemSize() arguments
local LayoutHelpers_bb = ImRect()     -- [Luau] scratch for ItemAdd() arguments (ItemAdd() copies it)

function ImGui.Spacing()
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return
    end
    ImGui.ItemSize(LAYOUT_ZERO_SIZE)
end

--- @param size ImVec2
function ImGui.Dummy(size)
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return
    end

    local cursor = window.DC.CursorPos
    local bb = LayoutHelpers_bb -- [Luau] scratch, no temporary ImVec2
    bb.Min.x, bb.Min.y, bb.Max.x, bb.Max.y = cursor.x, cursor.y, cursor.x + size.x, cursor.y + size.y
    ImGui.ItemSize(size)
    ImGui.ItemAdd(bb, 0)
end

function ImGui.NewLine()
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return
    end

    local g = GImGui
    local backup_layout_type = window.DC.LayoutType
    window.DC.LayoutType = ImGuiLayoutType.Vertical
    window.DC.IsSameLine = false

    if window.DC.CurrLineSize.y > 0.0 then -- In the event that we are on a line with items that is smaller that FontSize high, we will preserve its height.
        ImGui.ItemSize(LAYOUT_ZERO_SIZE)
    else
        local size = LayoutHelpers_size; size.x = 0.0; size.y = g.FontSize -- [Luau] scratch
        ImGui.ItemSize(size)
    end

    window.DC.LayoutType = backup_layout_type
end

function ImGui.AlignTextToFramePadding()
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return
    end

    local g = GImGui
    window.DC.CurrLineSize.y = ImMax(window.DC.CurrLineSize.y, g.FontSize + g.Style.FramePadding.y * 2)
    window.DC.CurrLineTextBaseOffset = ImMax(window.DC.CurrLineTextBaseOffset, g.Style.FramePadding.y)
end

-- Horizontal/vertical separating line
-- FIXME: Surprisingly, this seemingly trivial widget is a victim of many different legacy/tricky layout issues.
-- Note how thickness == 1.0f is handled specifically as not moving CursorPos by 'thickness', but other values are.
--- @param flags     ImGuiSeparatorFlags
--- @param thickness float
local SeparatorEx_bb = ImRect() -- [Luau] scratch for SeparatorEx(): only read by its callees (ItemAdd() copies it), never escapes
function ImGui.SeparatorEx(flags, thickness)
    if thickness == nil then thickness = 1.0 end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return
    end

    local g = GImGui
    IM_ASSERT(ImIsPowerOfTwo(bit32.band(flags, bit32.bor(ImGuiSeparatorFlags.Horizontal, ImGuiSeparatorFlags.Vertical)))) -- Check that only 1 option is selected
    IM_ASSERT(thickness > 0.0)

    if bit32.band(flags, ImGuiSeparatorFlags.Vertical) ~= 0 then
        -- Vertical separator, for menu bars (use current line height).
        local y1 = window.DC.CursorPos.y
        local y2 = window.DC.CursorPos.y + window.DC.CurrLineSize.y
        local bb = SeparatorEx_bb -- [Luau] scratch, no temporary ImVec2
        bb.Min.x, bb.Min.y, bb.Max.x, bb.Max.y = window.DC.CursorPos.x, y1, window.DC.CursorPos.x + thickness, y2
        local item_size = LayoutHelpers_size; item_size.x = thickness; item_size.y = 0.0
        ImGui.ItemSize(item_size)
        if not ImGui.ItemAdd(bb, 0) then
            return
        end

        -- Draw
        window.DrawList:AddRectFilled(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.Separator))
        if g.LogEnabled then
            ImGui.LogText(" |")
        end
    elseif bit32.band(flags, ImGuiSeparatorFlags.Horizontal) ~= 0 then
        -- Horizontal Separator
        local x1 = window.DC.CursorPos.x
        local x2 = window.WorkRect.Max.x

        -- Preserve legacy behavior inside Columns()
        -- Before Tables API happened, we relied on Separator() to span all columns of a Columns() set.
        -- We currently don't need to provide the same feature for tables because tables naturally have border features.
        local columns = (bit32.band(flags, ImGuiSeparatorFlags.SpanAllColumns) ~= 0) and window.DC.CurrentColumns or nil
        if columns then
            x1 = window.Pos.x + window.DC.Indent.x -- Used to be Pos.x before 2023/10/03
            x2 = window.Pos.x + window.Size.x
            ImGui.PushColumnsBackground()
        end

        -- We don't provide our width to the layout so that it doesn't get feed back into AutoFit
        -- FIXME: This prevents ->CursorMaxPos based bounding box evaluation from working (e.g. TableEndCell)

        -- Between 1.71 and 1.92.7, we maintained a hack where a 1.0f thin Separator() would not impact layout.
        -- This was mostly chosen to allow backward compatibility with user's code assuming zero-height when calculating height for layout (e.g. bottom alignment of a status bar).
        -- In order to handle scaling we need to scale separator thickness and it would not makes sense to have a disparity depending on height.
        ----float thickness_for_layout = (thickness == 1.0f) ? 0.0f : thickness; // FIXME: See 1.70/1.71 Separator() change: makes legacy 1-px separator not affect layout yet. Should change.
        local bb = SeparatorEx_bb -- [Luau] scratch, no temporary ImVec2
        bb.Min.x, bb.Min.y, bb.Max.x, bb.Max.y = x1, window.DC.CursorPos.y, x2, window.DC.CursorPos.y + thickness
        local item_size = LayoutHelpers_size; item_size.x = 0.0; item_size.y = thickness
        ImGui.ItemSize(item_size)

        if ImGui.ItemAdd(bb, 0) then
            -- Draw
            window.DrawList:AddRectFilled(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.Separator))
            if g.LogEnabled then
                ImGui.LogRenderedText(bb.Min, "--------------------------------\n")
            end
        end

        if columns then
            ImGui.PopColumnsBackground()
            columns.LineMinY = window.DC.CursorPos.y
        end
    end
end

function ImGui.Separator()
    local g = GImGui
    local window = g.CurrentWindow
    if window.SkipItems then
        return
    end

    -- Those flags should eventually be configurable by the user
    local flags
    if window.DC.LayoutType == ImGuiLayoutType.Horizontal then
        flags = ImGuiSeparatorFlags.Vertical
    else
        flags = ImGuiSeparatorFlags.Horizontal
    end

    -- Only applies to legacy Columns() api as they relied on Separator() a lot.
    if window.DC.CurrentColumns then
        flags = bit32.bor(flags, ImGuiSeparatorFlags.SpanAllColumns)
    end

    ImGui.SeparatorEx(flags, ImMax(g.Style.SeparatorSize, 1.0))
end

--- @param id         ImGuiID
--- @param label      string
--- @param label_end? int
--- @param extra_w    float
local SeparatorTextEx_label_size, SeparatorTextEx_min_size, SeparatorTextEx_bb, SeparatorTextEx_label_pos, SeparatorTextEx_clip_max = ImVec2(), ImVec2(), ImRect(), ImVec2(), ImVec2()

function ImGui.SeparatorTextEx(id, label, label_end, extra_w)
    local g = GImGui
    local window = g.CurrentWindow
    local style = g.Style

    -- [Luau] scratch vectors/rect (callees only read them or copy them), scalar pos
    local label_size = SeparatorTextEx_label_size
    label_size.x, label_size.y = ImGui.CalcTextSizeXY(label, 1, label_end, false)
    local pos_x, pos_y = window.DC.CursorPos.x, window.DC.CursorPos.y
    local padding = style.SeparatorTextPadding

    local separator_thickness = style.SeparatorTextBorderSize
    local min_size = SeparatorTextEx_min_size
    min_size.x = label_size.x + extra_w + padding.x * 2.0; min_size.y = ImMax(label_size.y + padding.y * 2.0, separator_thickness)

    local bb = SeparatorTextEx_bb
    bb.Min.x = pos_x; bb.Min.y = pos_y; bb.Max.x = window.WorkRect.Max.x; bb.Max.y = pos_y + min_size.y
    local text_baseline_y = ImTrunc((bb:GetHeight() - label_size.y) * style.SeparatorTextAlign.y + 0.999) --ImMax(padding.y, ImTrunc((style.SeparatorTextSize - label_size.y) * 0.5f))

    ImGui.ItemSize(min_size, text_baseline_y)
    if not ImGui.ItemAdd(bb, id) then
        return
    end

    local sep1_x1 = pos_x
    local sep2_x2 = bb.Max.x
    local seps_y = ImTrunc((bb.Min.y + bb.Max.y) * 0.5) + 1.0

    local label_avail_w = ImMax(0.0, sep2_x2 - sep1_x1 - padding.x * 2.0)
    local label_pos = SeparatorTextEx_label_pos
    label_pos.x = pos_x + padding.x + ImMax(0.0, (label_avail_w - label_size.x - extra_w) * style.SeparatorTextAlign.x); label_pos.y = pos_y + text_baseline_y -- FIXME-ALIGN

    -- This allows using SameLine() to position something in the 'extra_w'
    window.DC.CursorPosPrevLine.x = label_pos.x + label_size.x

    local separator_col = ImGui.GetColorU32(ImGuiCol.Separator)

    if label_size.x > 0.0 then
        local sep1_x2 = label_pos.x - style.ItemSpacing.x
        local sep2_x1 = label_pos.x + label_size.x + extra_w + style.ItemSpacing.x

        if sep1_x2 > sep1_x1 and separator_thickness > 0.0 then
            window.DrawList:AddLineH(sep1_x1, sep1_x2, seps_y, separator_col, separator_thickness, ImDrawFlags.StrokeCenterBiased)
        end

        if sep2_x2 > sep2_x1 and separator_thickness > 0.0 then
            window.DrawList:AddLineH(sep2_x1, sep2_x2, seps_y, separator_col, separator_thickness, ImDrawFlags.StrokeCenterBiased)
        end

        if g.LogEnabled then
            ImGui.LogSetNextTextDecoration("---", nil)
        end

        local clip_max = SeparatorTextEx_clip_max
        clip_max.x = bb.Max.x; clip_max.y = bb.Max.y + style.ItemSpacing.y
        ImGui.RenderTextEllipsis(window.DrawList, label_pos, clip_max, bb.Max.x, label, label_end, label_size)
    else
        if g.LogEnabled then
            ImGui.LogText("---")
        end

        if separator_thickness > 0.0 then
            window.DrawList:AddLineH(sep1_x1, sep2_x2, seps_y, separator_col, separator_thickness, ImDrawFlags.StrokeCenterBiased)
        end
    end
end

--- @param label string
function ImGui.SeparatorText(label)
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return
    end

    -- The SeparatorText() vs SeparatorTextEx() distinction is designed to be considerate that we may want:
    -- - allow separator-text to be draggable items (would require a stable ID + a noticeable highlight)
    -- - this high-level entry point to allow formatting? (which in turns may require ID separate from formatted string)
    -- - because of this we probably can't turn 'string label' into 'string fmt, ...'
    -- Otherwise, we can decide that users wanting to drag this would layout a dedicated drag-item,
    -- and then we can turn this into a format function.
    ImGui.SeparatorTextEx(0, label, ImGui.FindRenderedTextEnd(label), 0.0)
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: ComboBox
-------------------------------------------------------------------------------
-- - CalcMaxPopupHeightFromItemCount() [Internal]
-- - BeginCombo()
-- - BeginComboPopup() [Internal]
-- - EndCombo()
-- - BeginComboPreview() [Internal]
-- - EndComboPreview() [Internal]
-- - Combo()
-------------------------------------------------------------------------------

--- @param items_count float
--- @return float
local function CalcMaxPopupHeightFromItemCount(items_count)
    local g = GImGui
    if items_count <= 0 then
        return FLT_MAX
    end
    return (g.FontSize + g.Style.ItemSpacing.y) * items_count - g.Style.ItemSpacing.y + (g.Style.WindowPadding.y * 2)
end

--- @param label          string
--- @param preview_value? string
--- @param flags?         ImGuiComboFlags
-- [Luau] scratch for BeginCombo(): only read by its callees (ItemAdd() copies them), never escape
local BeginCombo_bb, BeginCombo_total_bb, BeginCombo_p0, BeginCombo_p1 = ImRect(), ImRect(), ImVec2(), ImVec2()
function ImGui.BeginCombo(label, preview_value, flags)
    if flags == nil then flags = 0 end

    local g = GImGui
    local window = ImGui.GetCurrentWindow()

    local backup_next_window_data_flags = g.NextWindowData.HasFlags
    g.NextWindowData:ClearFlags() -- We behave like Begin() and need to consume those values
    if window.SkipItems then
        return false
    end

    local style = g.Style
    local id = window:GetID(label)
    IM_ASSERT(bit32.band(flags, bit32.bor(ImGuiComboFlags.NoArrowButton, ImGuiComboFlags.NoPreview)) ~= bit32.bor(ImGuiComboFlags.NoArrowButton, ImGuiComboFlags.NoPreview)) -- Can't use both flags together
    if bit32.band(flags, ImGuiComboFlags.WidthFitPreview) ~= 0 then
        IM_ASSERT(bit32.band(flags, ImGuiComboFlags.NoPreview) == 0)
    end

    local arrow_size
    if (bit32.band(flags, ImGuiComboFlags.NoArrowButton) ~= 0) then
        arrow_size = 0.0
    else
        arrow_size = ImGui.GetFrameHeight()
    end

    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size_x, label_size_y = ImGui.CalcTextSizeXY(label, 1, label_end, false) -- [Luau] scalar label_size

    local preview_width
    if ((bit32.band(flags, ImGuiComboFlags.WidthFitPreview) ~= 0) and (preview_value ~= nil)) then
        preview_width = ImGui.CalcTextSize(preview_value, nil, false).x
    else
        preview_width = 0.0
    end

    local w
    if bit32.band(flags, ImGuiComboFlags.NoPreview) ~= 0 then
        w = arrow_size
    elseif bit32.band(flags, ImGuiComboFlags.WidthFitPreview) ~= 0 then
        w = arrow_size + preview_width + style.FramePadding.x * 2.0
    else
        w = ImGui.CalcItemWidth()
    end

    local cursor = window.DC.CursorPos
    local bb = BeginCombo_bb
    bb.Min.x, bb.Min.y, bb.Max.x, bb.Max.y = cursor.x, cursor.y, cursor.x + w, cursor.y + (label_size_y + style.FramePadding.y * 2.0)
    local label_offset = (label_size_x > 0.0) and (style.ItemInnerSpacing.x + label_size_x) or 0.0
    local total_bb = BeginCombo_total_bb
    total_bb.Min.x, total_bb.Min.y, total_bb.Max.x, total_bb.Max.y = bb.Min.x, bb.Min.y, bb.Max.x + label_offset, bb.Max.y + 0.0

    ImGui.ItemSize(total_bb, style.FramePadding.y)
    if not ImGui.ItemAdd(total_bb, id, bb) then
        return false
    end

    -- Open on click
    local pressed, hovered, held = ImGui.ButtonBehavior(bb, id)
    local popup_id = ImHashStr("##ComboPopup", nil, id)
    local popup_open = ImGui.IsPopupOpen(popup_id, ImGuiPopupFlags.None)
    if pressed and not popup_open then
        ImGui.OpenPopupEx(popup_id, ImGuiPopupFlags.None)
        popup_open = true
    end

    -- Render shape
    local frame_col = ImGui.GetColorU32(hovered and ImGuiCol.FrameBgHovered or ImGuiCol.FrameBg)
    local value_x2 = ImMax(bb.Min.x, bb.Max.x - arrow_size)

    ImGui.RenderNavCursor(bb, id)

    if bit32.band(flags, ImGuiComboFlags.NoPreview) == 0 then
        local p1 = BeginCombo_p1
        p1.x, p1.y = value_x2, bb.Max.y
        window.DrawList:AddRectFilled(bb.Min, p1, frame_col, style.FrameRounding, (bit32.band(flags, ImGuiComboFlags.NoArrowButton) ~= 0) and ImDrawFlags.RoundAll or ImDrawFlags.RoundLeft)
    end

    if bit32.band(flags, ImGuiComboFlags.NoArrowButton) == 0 then
        local bg_col = ImGui.GetColorU32((popup_open or hovered) and ImGuiCol.ButtonHovered or ImGuiCol.Button)
        local text_col = ImGui.GetColorU32(ImGuiCol.Text)

        local p0 = BeginCombo_p0
        p0.x, p0.y = value_x2, bb.Min.y
        window.DrawList:AddRectFilled(p0, bb.Max, bg_col, style.FrameRounding, (w <= arrow_size) and ImDrawFlags.RoundAll or ImDrawFlags.RoundRight)

        if value_x2 + arrow_size - style.FramePadding.x <= bb.Max.x then
            p0.x, p0.y = value_x2 + style.FramePadding.y, bb.Min.y + style.FramePadding.y
            ImGui.RenderArrow(window.DrawList, p0, text_col, ImGuiDir.Down, 1.0)
        end
    end

    ImGui.RenderFrameBorder(bb.Min, bb.Max, style.FrameRounding)

    -- Store geometry for BeginComboPreview() - only necessary when visible.
    -- [Luau] written in place (C++ assigns the struct)
    local preview_rect = g.ComboPreviewData.PreviewRect
    if bit32.band(flags, ImGuiComboFlags.NoPreview) ~= 0 then
        preview_rect.Min.x, preview_rect.Min.y, preview_rect.Max.x, preview_rect.Max.y = 0, 0, 0, 0
    else
        preview_rect.Min.x, preview_rect.Min.y, preview_rect.Max.x, preview_rect.Max.y = bb.Min.x, bb.Min.y, value_x2, bb.Max.y
    end

    -- Render preview and label
    if preview_value ~= nil and bit32.band(flags, ImGuiComboFlags.NoPreview) == 0 then
        if g.LogEnabled then
            ImGui.LogSetNextTextDecoration("{", "}")
        end
        local p0, p1 = BeginCombo_p0, BeginCombo_p1
        p0.x, p0.y = bb.Min.x + style.FramePadding.x, bb.Min.y + style.FramePadding.y
        p1.x, p1.y = value_x2, bb.Max.y
        ImGui.RenderTextClipped(p0, p1, preview_value, nil, nil)
    end

    if label_size_x > 0 then
        local p0 = BeginCombo_p0
        p0.x, p0.y = bb.Max.x + style.ItemInnerSpacing.x, bb.Min.y + style.FramePadding.y
        ImGui.RenderText(p0, label, 1, label_end, false)
    end

    if not popup_open then
        return false
    end

    g.NextWindowData.HasFlags = backup_next_window_data_flags
    return ImGui.BeginComboPopup(popup_id, bb, flags)
end

--- @param popup_id ImGuiID
--- @param bb       ImRect
--- @param flags    ImGuiComboFlags
function ImGui.BeginComboPopup(popup_id, bb, flags)
    local g = GImGui
    if not ImGui.IsPopupOpen(popup_id, ImGuiPopupFlags.None) then
        g.NextWindowData:ClearFlags()
        return false
    end

    -- Set popup size
    local w = bb:GetWidth()
    if bit32.band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSizeConstraint) ~= 0 then
        g.NextWindowData.SizeConstraintRect.Min.x = ImMax(g.NextWindowData.SizeConstraintRect.Min.x, w)
    else
        if bit32.band(flags, ImGuiComboFlags.HeightMask_) == 0 then
            flags = bit32.bor(flags, ImGuiComboFlags.HeightRegular)
        end
        IM_ASSERT(ImIsPowerOfTwo(bit32.band(flags, ImGuiComboFlags.HeightMask_))) -- Only one
        local popup_max_height_in_items = -1
        if bit32.band(flags, ImGuiComboFlags.HeightRegular) ~= 0 then
            popup_max_height_in_items = 8
        elseif bit32.band(flags, ImGuiComboFlags.HeightSmall) ~= 0 then
            popup_max_height_in_items = 4
        elseif bit32.band(flags, ImGuiComboFlags.HeightLarge) ~= 0 then
            popup_max_height_in_items = 20
        end
        local constraint_min = ImVec2(0.0, 0.0)
        local constraint_max = ImVec2(FLT_MAX, FLT_MAX)
        if bit32.band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSize) == 0 or g.NextWindowData.SizeVal.x <= 0.0 then -- Don't apply constraints if user specified a size
            constraint_min.x = w
        end
        if bit32.band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSize) == 0 or g.NextWindowData.SizeVal.y <= 0.0 then
            constraint_max.y = CalcMaxPopupHeightFromItemCount(popup_max_height_in_items)
        end
        ImGui.SetNextWindowSizeConstraints(constraint_min, constraint_max)
    end

    -- This is essentially a specialized version of BeginPopupEx()
    local name = ImFormatString("##Combo_%02d", g.BeginComboDepth) -- Recycle windows based on depth

    -- Set position given a custom constraint (peak into expected window size so we can position it)
    -- FIXME: This might be easier to express with an hypothetical SetNextWindowPosConstraints() function?
    -- FIXME: This might be moved to Begin() or at least around the same spot where Tooltips and other Popups are calling FindBestWindowPosForPopupEx()?
    local popup_window = ImGui.FindWindowByName(name)
    if popup_window then
        if popup_window.WasActive then
            -- Always override 'AutoPosLastDirection' to not leave a chance for a past value to affect us.
            local size_expected = ImGui.CalcWindowNextAutoFitSize(popup_window)
            popup_window.AutoPosLastDirection = (bit32.band(flags, ImGuiComboFlags.PopupAlignLeft) ~= 0) and ImGuiDir.Left or ImGuiDir.Down -- Left = "Below, Toward Left", Down = "Below, Toward Right (default)"
            local r_outer = ImGui.GetPopupAllowedExtentRect(popup_window)
            local pos
            pos, popup_window.AutoPosLastDirection = ImGui.FindBestWindowPosForPopupEx(bb:GetBL(), size_expected, popup_window.AutoPosLastDirection, r_outer, bb, ImGuiPopupPositionPolicy.ComboBox)
            ImGui.SetNextWindowPos(pos)
        end
    end

    -- We don't use BeginPopupEx() solely because we have a custom name string, which we could make an argument to BeginPopupEx()
    local window_flags = bit32.bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.Popup, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoSavedSettings, ImGuiWindowFlags.NoMove)
    ImGui.PushStyleVarX(ImGuiStyleVar.WindowPadding, g.Style.FramePadding.x) -- Horizontally align ourselves with the framed text
    local _, ret = ImGui.Begin(name, nil, window_flags)
    ImGui.PopStyleVar()
    if not ret then
        ImGui.EndPopup()
        if not g.IO.ConfigDebugBeginReturnValueOnce and not g.IO.ConfigDebugBeginReturnValueLoop then
            -- Begin may only return false with those debug tools activated.
            IM_ASSERT(false) -- This should never happen as we tested for IsPopupOpen() above
        end
        return false
    end

    g.BeginComboDepth = g.BeginComboDepth + 1
    ImRect_Copy(g.CurrentWindowStack:back().ParentLastComboPreviewRect, g.ComboPreviewData.PreviewRect)
    return true
end

function ImGui.EndCombo()
    local g = GImGui
    g.BeginComboDepth = g.BeginComboDepth - 1
    ImRect_Copy(g.ComboPreviewData.PreviewRect, g.CurrentWindowStack:back().ParentLastComboPreviewRect)

    local name = ImFormatString("##Combo_%02d", g.BeginComboDepth) -- FIXME: Move those to helpers?

    if g.CurrentWindow.Name ~= name then
        IM_ASSERT_USER_ERROR_RET(false, "Calling EndCombo() in wrong window!")
    end

    ImGui.EndPopup()
end

-- Submit preview contents for BeginCombo()/EndCombo(), to display contents that's more than just a text label.
-- - [BETA] See GitHub issues: #1658, #4168.
-- - Make sure you call this after EndCombo().
-- - The preview is designed to only host non-interactive elements.
-- - Not compatible with ImGuiComboFlags.WidthFitPreview.
-- - 2026-09-08 (1.93.0): removed ImGuiComboFlags.CustomPreview. You can use BeginComboPreview()/EndComboPreview() without an extra flag.
function ImGui.BeginComboPreview()
    local g = GImGui
    local window = g.CurrentWindow

    if window.SkipItems or bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible) == 0 then
        return false
    end
    local preview_data = g.ComboPreviewData
    if not window.ClipRect:Overlaps(preview_data.PreviewRect) or preview_data.PreviewRect:GetWidth() <= 0.0 then -- Narrower test (optional) + handle _NoPreview
        return false
    end
    if not (g.LastItemData.Rect.Min.x == preview_data.PreviewRect.Min.x and g.LastItemData.Rect.Min.y == preview_data.PreviewRect.Min.y) then -- IM_ASSERT_USER_ERROR_RETV()
        IM_ASSERT_USER_ERROR(false, "Call BeginComboPreview() after BeginCombo(), not after EndCombo()!") -- Calling after EndCombo() works only if you don't nest combos.
        return false
    end
    if preview_data.WithinPreview then
        IM_ASSERT_USER_ERROR(false, "Cannot recurse BeginComboPreview(): call EndComboPreview() before opening another combo.")
        return false
    end

    -- FIXME: This could be contained in a PushWorkRect() api
    ImVec2_Copy(preview_data.BackupCursorPos, window.DC.CursorPos)
    ImVec2_Copy(preview_data.BackupCursorMaxPos, window.DC.CursorMaxPos)
    ImVec2_Copy(preview_data.BackupCursorPosPrevLine, window.DC.CursorPosPrevLine)
    preview_data.BackupPrevLineTextBaseOffset = window.DC.PrevLineTextBaseOffset
    preview_data.BackupLayout = window.DC.LayoutType
    preview_data.WithinPreview = true
    preview_data.BackupWorkRectMaxX = window.WorkRect.Max.x
    preview_data.BackupContentRectMaxX = window.ContentRegionRect.Max.x
    window.WorkRect.Max.x = preview_data.PreviewRect.Max.x - g.Style.FramePadding.x
    window.ContentRegionRect.Max.x = window.WorkRect.Max.x
    ImVec2_Copy(window.DC.CursorPos, preview_data.PreviewRect.Min + g.Style.FramePadding)
    ImVec2_Copy(window.DC.CursorMaxPos, window.DC.CursorPos)
    window.DC.LayoutType = ImGuiLayoutType.Horizontal
    window.DC.IsSameLine = false

    ImGui.PushClipRect(preview_data.PreviewRect.Min, preview_data.PreviewRect.Max, true)

    return true
end

function ImGui.EndComboPreview()
    local g = GImGui
    local window = g.CurrentWindow
    local preview_data = g.ComboPreviewData

    -- FIXME: Using CursorMaxPos approximation instead of correct AABB which we will store in ImDrawCmd in the future
    local draw_list = window.DrawList
    if window.DC.CursorMaxPos.x < preview_data.PreviewRect.Max.x and window.DC.CursorMaxPos.y < preview_data.PreviewRect.Max.y then
        if draw_list.CmdBuffer.Size > 1 then -- Unlikely case that the PushClipRect() didn't create a command
            ImVec4_Copy(draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size].ClipRect, draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size - 1].ClipRect)
            ImVec4_Copy(draw_list._CmdHeader.ClipRect, draw_list.CmdBuffer.Data[draw_list.CmdBuffer.Size].ClipRect)
            draw_list:_TryMergeDrawCmds()
        end
    end

    ImGui.PopClipRect()

    ImVec2_Copy(window.DC.CursorPos, preview_data.BackupCursorPos)
    ImVec2_Copy(window.DC.CursorMaxPos, ImMax(window.DC.CursorMaxPos, preview_data.BackupCursorMaxPos)) -- No need to do the same with IdealMaxPos
    ImVec2_Copy(window.DC.CursorPosPrevLine, preview_data.BackupCursorPosPrevLine)
    window.DC.PrevLineTextBaseOffset = preview_data.BackupPrevLineTextBaseOffset
    window.WorkRect.Max.x = preview_data.BackupWorkRectMaxX
    window.ContentRegionRect.Max.x = preview_data.BackupContentRectMaxX
    window.DC.LayoutType = preview_data.BackupLayout
    window.DC.IsSameLine = false
    preview_data.WithinPreview = false
end

-- [Port] Getter for the old Combo() API: Lua array of strings (1-based), `idx` is 0-based
local function Items_ArrayGetter(data, idx)
    return data[idx + 1]
end

-- Getter for the old Combo() API: "item1\0item2\0item3\0"
local function Items_SingleStringGetter(data, idx)
    local items_count = 0
    local p = 1
    while p <= #data and string.byte(data, p) ~= 0 do
        local e = string.find(data, "\0", p, true) or (#data + 1)
        if idx == items_count then
            return string.sub(data, p, e - 1)
        end
        p = e + 1
        items_count = items_count + 1
    end
    return nil
end

local function Items_SingleStringCount(data)
    local items_count = 0
    local p = 1
    while p <= #data and string.byte(data, p) ~= 0 do
        p = (string.find(data, "\0", p, true) or #data) + 1
        items_count = items_count + 1
    end
    return items_count
end

-- [Port] Normalizes the 3 upstream overloads to (getter, user_data, items_count, height)
-- - (items: string[], items_count?, height?)
-- - (items_separated_by_zeros: string, height?)
-- - (getter: fun(user_data, idx): string?, user_data, items_count, height?)
local function Items_ResolveArgs(a, b, c, d)
    if type(a) == "function" then
        return a, b, c, d
    elseif type(a) == "string" then
        return Items_SingleStringGetter, a, Items_SingleStringCount(a), b
    else
        return Items_ArrayGetter, a, b or #a, c
    end
end

-- Old API, prefer using BeginCombo() nowadays if you can.
--- @param label        string
--- @param current_item int     # 0-based
--- @return int  current_item
--- @return bool value_changed
function ImGui.Combo(label, current_item, a, b, c, d)
    local g = GImGui
    local getter, user_data, items_count, popup_max_height_in_items = Items_ResolveArgs(a, b, c, d)
    if popup_max_height_in_items == nil then popup_max_height_in_items = -1 end

    -- Call the getter to obtain the preview string which is a parameter to BeginCombo()
    local preview_value = nil
    if bit32.band(bit32.bor(g.NextItemData.ItemFlagsSet, g.CurrentItemFlags), ImGuiItemFlags.MixedValue) ~= 0 then
        preview_value = ""
    elseif current_item >= 0 and current_item < items_count then
        preview_value = getter(user_data, current_item)
    end

    -- The old Combo() API exposed "popup_max_height_in_items". The new more general BeginCombo() API doesn't have/need it, but we emulate it here.
    if popup_max_height_in_items ~= -1 and bit32.band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSizeConstraint) == 0 then
        ImGui.SetNextWindowSizeConstraints(ImVec2(0, 0), ImVec2(FLT_MAX, CalcMaxPopupHeightFromItemCount(popup_max_height_in_items)))
    end

    if not ImGui.BeginCombo(label, preview_value, ImGuiComboFlags.None) then
        return current_item, false
    end

    -- Display items
    local value_changed = false
    local clipper = ImGuiListClipper()
    clipper:Begin(items_count)
    clipper:IncludeItemByIndex(current_item)
    while clipper:Step() do
        for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
            local item_text = getter(user_data, i)
            if item_text == nil then
                item_text = "*Unknown item*"
            end

            ImGui.PushID(i)
            local item_selected = (i == current_item)
            if ImGui.Selectable(item_text, item_selected) and current_item ~= i then
                value_changed = true
                current_item = i
            end
            if item_selected then
                ImGui.SetItemDefaultFocus()
            end
            ImGui.PopID()
        end
    end

    ImGui.EndCombo()
    if value_changed then
        ImGui.MarkItemEdited(g.LastItemData.ID)
    end

    return current_item, value_changed
end

-------------------------------------------------------------------------------
-- [SECTION] Data Type and Data Formatting Helpers [Internal]
-------------------------------------------------------------------------------
-- - DataTypeGetInfo()
-- - DataTypeFormatString()
-- - DataTypeApplyOp()
-- - DataTypeApplyFromText()
-- - DataTypeCompare()
-- - DataTypeClamp()
-- - GetMinimumStepAtDecimalPrecision
-- - RoundScalarWithFormat<>()
-------------------------------------------------------------------------------

local function float(val) return val end
local function double(val) return val end

local GDefaultRgbaColorMarkers = {
    IM_COL32(240, 20, 20, 255), IM_COL32(20, 240, 20, 255), IM_COL32(20, 20, 240, 255), IM_COL32(140, 140, 140, 255)
}

--- @param size      size_t
--- @param name      string
--- @param print_fmt string
--- @param scan_fmt  string
--- @return ImGuiDataTypeInfo
--- @nodiscard
--- @package
local function ImGuiDataTypeInfo(size, name, print_fmt, scan_fmt)
    return { Size = size, Name = name, PrintFmt = print_fmt, ScanFmt = scan_fmt }
end

local GDataTypeInfo = {
    ImGuiDataTypeInfo(1, "S8",     "%d",   "%d"), -- ImGuiDataType.S8
    ImGuiDataTypeInfo(1, "U8",     "%u",   "%u"),
    ImGuiDataTypeInfo(2, "S16",    "%d",   "%d"), -- ImGuiDataType.S16
    ImGuiDataTypeInfo(2, "U16",    "%u",   "%u"),
    ImGuiDataTypeInfo(4, "S32",    "%d",   "%d"), -- ImGuiDataType.S32
    ImGuiDataTypeInfo(4, "U32",    "%u",   "%u"),
    ImGuiDataTypeInfo(8, "S64",    "%lld", "%lld"), -- ImGuiDataType.S64
    ImGuiDataTypeInfo(8, "U64",    "%llu", "%llu"),
    ImGuiDataTypeInfo(4, "float",  "%.3f", "%f"), -- ImGuiDataType.Float
    ImGuiDataTypeInfo(8, "double", "%f",   "%lf"), -- ImGuiDataType.Double
    ImGuiDataTypeInfo(1, "bool",   "%d",   "%d"), -- ImGuiDataType.Bool
    ImGuiDataTypeInfo(0, "string", "%s",   "%s") -- ImGuiDataType.String
}

--- @param data_type ImGuiDataType
function ImGui.DataTypeGetInfo(data_type)
    IM_ASSERT(data_type >= 0 and data_type < ImGuiDataType.COUNT)
    return GDataTypeInfo[data_type + 1]
end

-- [Luau] string.format() has no length modifiers (%lld, %I64d...) and formats negative numbers as 64-bit for %u/%x/%X/%o:
-- [Port] strip modifiers and re-apply C's integer promotion/two's complement for signed types.
local DataTypeFormatStringCached do
local fmt_info_memo = {} -- [Port] format -> { stripped format, is unsigned conversion }
local function GetFormatInfo(format)
    local info = fmt_info_memo[format]
    if info == nil then
        local stripped = string.gsub(string.gsub(format, "(%%[-+ #0']*%d*%.?%d*)[hlLqjzt]+", "%1"), "(%%[-+ #0']*%d*%.?%d*)I64", "%1")
        local conv = string.match(stripped, "%%[-+ #0']*%d*%.?%d*([diouxXc])")
        info = { stripped, conv == "u" or conv == "x" or conv == "X" or conv == "o" }
        fmt_info_memo[format] = info
    end
    return info
end

--- [Port] Lua-string version of DataTypeFormatString() (memoized), used for display.
--- @param data_type ImGuiDataType
--- @param data      number
--- @param format    string
--- @return string
function DataTypeFormatStringCached(data_type, data, format)
    if data_type == ImGuiDataType.Float or data_type == ImGuiDataType.Double then
        return FormatCached(format, data)
    end
    local info = GetFormatInfo(format)
    if     data_type == ImGuiDataType.S8  then data = (ImS8)(data)
    elseif data_type == ImGuiDataType.U8  then data = (ImU8)(data)
    elseif data_type == ImGuiDataType.S16 then data = (ImS16)(data)
    elseif data_type == ImGuiDataType.U16 then data = (ImU16)(data)
    elseif data_type == ImGuiDataType.S32 then -- [Port] (signed values are already stored signed)
    elseif data_type == ImGuiDataType.U32 then data = (ImU32)(data)
    elseif data_type == ImGuiDataType.S64 or data_type == ImGuiDataType.U64 then
        -- [Port] (string.format() already prints negative numbers as 64-bit two's complement for %u/%x/%X/%o)
        if info[2] then
            if data >= 18446744073709551616 then data = -1 end -- [Port] (ImU64)-1 rounds to 2^64 in a double: print ULLONG_MAX
        elseif data >= 9223372036854775808 then
            data = 9223372036854774784 -- [Port] largest double below 2^63 (LLONG_MAX isn't representable)
        end
        return FormatCached(info[1], data)
    else
        IM_ASSERT(false)
    end
    if data < 0 and info[2] then data = data + 4294967296 end -- Signedness doesn't matter when pushing integer arguments
    return FormatCached(info[1], data)
end
end

--- @param buf       char[]
--- @param buf_size  int
--- @param data_type ImGuiDataType
--- @param data      number
--- @param format    string
--- @return int
function ImGui.DataTypeFormatString(buf, buf_size, data_type, data, format)
    local str = DataTypeFormatStringCached(data_type, data, format)
    local len = ImMin(#str, buf_size - 1) -- [Port] ImFormatString(): truncate and return the written length
    ImStd.ImStrncpy(buf, 1, { string.byte(str, 1, len) }, 1, len + 1)
    return len
end

--- @param data_type ImGuiDataType
--- @param op        int
--- @param arg1      number
--- @param arg2      number
function ImGui.DataTypeApplyOp(data_type, op, arg1, arg2)
    IM_ASSERT(op == 43 or op == 45) -- '+' or '-'

    if data_type == ImGuiDataType.S8 then
        if op == 43 then
            return ImAddClampOverflow(arg1, arg2, IM_S8_MIN, IM_S8_MAX)
        elseif op == 45 then
            return ImSubClampOverflow(arg1, arg2, IM_S8_MIN, IM_S8_MAX)
        end
    elseif data_type == ImGuiDataType.U8 then
        if op == 43 then
            return ImAddClampOverflow(arg1, arg2, IM_U8_MIN, IM_U8_MAX)
        elseif op == 45 then
            return ImSubClampOverflow(arg1, arg2, IM_U8_MIN, IM_U8_MAX)
        end
    elseif data_type == ImGuiDataType.S16 then
        if op == 43 then
            return ImAddClampOverflow((ImS16)(arg1), (ImS16)(arg2), IM_S16_MIN, IM_S16_MAX)
        elseif op == 45 then
            return ImSubClampOverflow((ImS16)(arg1), (ImS16)(arg2), IM_S16_MIN, IM_S16_MAX)
        end
    elseif data_type == ImGuiDataType.U16 then
        if op == 43 then
            return ImAddClampOverflow((ImU16)(arg1), (ImU16)(arg2), IM_U16_MIN, IM_U16_MAX)
        elseif op == 45 then
            return ImSubClampOverflow((ImU16)(arg1), (ImU16)(arg2), IM_U16_MIN, IM_U16_MAX)
        end
    elseif data_type == ImGuiDataType.S32 then
        if op == 43 then
            return ImAddClampOverflow(arg1, arg2, IM_S32_MIN, IM_S32_MAX)
        elseif op == 45 then
            return ImSubClampOverflow(arg1, arg2, IM_S32_MIN, IM_S32_MAX)
        end
    elseif data_type == ImGuiDataType.U32 then
        if op == 43 then
            return ImAddClampOverflow(arg1, arg2, IM_U32_MIN, IM_U32_MAX)
        elseif op == 45 then
            return ImSubClampOverflow(arg1, arg2, IM_U32_MIN, IM_U32_MAX)
        end
    elseif data_type == ImGuiDataType.S64 then
        if op == 43 then
            return ImAddClampOverflow(arg1, arg2, IM_S64_MIN, IM_S64_MAX)
        elseif op == 45 then
            return ImSubClampOverflow(arg1, arg2, IM_S64_MIN, IM_S64_MAX)
        end
    elseif data_type == ImGuiDataType.U64 then
        if op == 43 then
            return ImAddClampOverflow(arg1, arg2, IM_U64_MIN, IM_U64_MAX)
        elseif op == 45 then
            return ImSubClampOverflow(arg1, arg2, IM_U64_MIN, IM_U64_MAX)
        end
    elseif data_type == ImGuiDataType.Float then
        if op == 43 then
            return arg1 + arg2
        elseif op == 45 then
            return arg1 - arg2
        end
    elseif data_type == ImGuiDataType.Double then
        if op == 43 then
            return arg1 + arg2
        elseif op == 45 then
            return arg1 - arg2
        end
    end

    IM_ASSERT(false)
end

local ImParseFormatSanitizeForScanning

-- User can input math operators (e.g. +100) to edit a numerical values.
-- NB: This is _not_ a full expression evaluator. We should probably add one and replace this dumb mess..
--- @param buf              char[]
--- @param data_type        ImGuiDataType
--- @param data             number
--- @param format           string
--- @param data_when_empty? number
function ImGui.DataTypeApplyFromText(buf, data_type, data, format, data_when_empty)
    -- Copy the value so we can compare at the end of the function if it changed at all.
    local type_info = ImGui.DataTypeGetInfo(data_type)
    local data_backup = data

    local p = 1
    while ImCharIsBlankA(buf[p]) do
        p = p + 1
    end
    if buf[p] == 0 then
        if data_when_empty ~= nil then
            data = data_when_empty
            return data, data_backup ~= data
        end
        return data, false
    end

    -- Sanitize format
    -- - For float/double we have to ignore format with precision (e.g. "%.2f") because sscanf doesn't take them in, so force them into %f and %lf
    local format_sanitized, format_sanitized_size = {}, 32
    if (data_type == ImGuiDataType.Float or data_type == ImGuiDataType.Double) then
        format = type_info.ScanFmt
    else
        format = ImParseFormatSanitizeForScanning(format, format_sanitized, format_sanitized_size)
        if format[1] == 0 then
            format = type_info.ScanFmt -- Format doesn't want us to show the number currently, but we still need to parse the resulting input
        end
    end

    -- Small types need a 32-bit buffer to receive the result from scanf()
    local v32 = 0
    local res = {}
    if ImStd.sscanf(buf, 1, format, res) < 1 then
        return data, false
    end
    if type_info.Size >= 4 then
        data = res[1]
    else
        v32 = res[1]
    end

    if type_info.Size < 4 then
        if data_type == ImGuiDataType.S8 then
            data = (ImS8)(ImClamp(v32, IM_S8_MIN, IM_S8_MAX))
        elseif data_type == ImGuiDataType.U8 then
            data = (ImU8)(ImClamp(v32, IM_U8_MIN, IM_U8_MAX))
        elseif data_type == ImGuiDataType.S16 then
            data = (ImS16)(ImClamp(v32, IM_S16_MIN, IM_S16_MAX))
        elseif data_type == ImGuiDataType.U16 then
            data = (ImU16)(ImClamp(v32, IM_U16_MIN, IM_U16_MAX))
        else
            IM_ASSERT(false)
        end
    end

    return data, data_backup ~= data
end

--- @generic T : number
--- @param lhs T
--- @param rhs T
local function DataTypeCompareT(lhs, rhs)
    if lhs < rhs then return -1 end
    if lhs > rhs then return  1 end
    return 0
end

--- @param data_type ImGuiDataType
--- @param arg1      number
--- @param arg2      number
function ImGui.DataTypeCompare(data_type, arg1, arg2)
    if     data_type == ImGuiDataType.S8  then return DataTypeCompareT((ImS8)(arg1), (ImS8)(arg2))
    elseif data_type == ImGuiDataType.U8  then return DataTypeCompareT((ImU8)(arg1), (ImU8)(arg2))
    elseif data_type == ImGuiDataType.S16 then return DataTypeCompareT((ImS16)(arg1), (ImS16)(arg2))
    elseif data_type == ImGuiDataType.U16 then return DataTypeCompareT((ImU16)(arg1), (ImU16)(arg2))
    elseif data_type == ImGuiDataType.S32 then return DataTypeCompareT((ImS32)(arg1), (ImS32)(arg2))
    elseif data_type == ImGuiDataType.U32 then return DataTypeCompareT((ImU32)(arg1), (ImU32)(arg2))
    elseif data_type == ImGuiDataType.S64 then return DataTypeCompareT((ImS64)(arg1), (ImS64)(arg2))
    elseif data_type == ImGuiDataType.U64 then return DataTypeCompareT((ImU64)(arg1), (ImU64)(arg2))
    elseif data_type == ImGuiDataType.Float  then return DataTypeCompareT(arg1, arg2)
    elseif data_type == ImGuiDataType.Double then return DataTypeCompareT(arg1, arg2)
    end
    IM_ASSERT(false)
    return 0
end

--- @generic T : number
--- @param v      T
--- @param v_min? T
--- @param v_max? T
--- @return T, boolean
local function DataTypeClampT(v, v_min, v_max)
    -- Clamp, both sides are optional, return true if modified
    if v_min and v < v_min then return v_min, true end
    if v_max and v > v_max then return v_max, true end
    return v, false
end

--- @param data_type ImGuiDataType
--- @param data      number
--- @param min?      number
--- @param max?      number
function ImGui.DataTypeClamp(data_type, data, min, max)
    if     data_type == ImGuiDataType.S8  then return DataTypeClampT((ImS8)(data),  min and (ImS8)(min),  max and (ImS8)(max))
    elseif data_type == ImGuiDataType.U8  then return DataTypeClampT((ImU8)(data),  min and (ImU8)(min),  max and (ImU8)(max))
    elseif data_type == ImGuiDataType.S16 then return DataTypeClampT((ImS16)(data), min and (ImS16)(min), max and (ImS16)(max))
    elseif data_type == ImGuiDataType.U16 then return DataTypeClampT((ImU16)(data), min and (ImU16)(min), max and (ImU16)(max))
    elseif data_type == ImGuiDataType.S32 then return DataTypeClampT((ImS32)(data), min and (ImS32)(min), max and (ImS32)(max))
    elseif data_type == ImGuiDataType.U32 then return DataTypeClampT((ImU32)(data), min and (ImU32)(min), max and (ImU32)(max))
    elseif data_type == ImGuiDataType.S64 then return DataTypeClampT((ImS64)(data), min and (ImS64)(min), max and (ImS64)(max))
    elseif data_type == ImGuiDataType.U64 then return DataTypeClampT((ImU64)(data), min and (ImU64)(min), max and (ImU64)(max))
    elseif data_type == ImGuiDataType.Float  then return DataTypeClampT(data, min, max)
    elseif data_type == ImGuiDataType.Double then return DataTypeClampT(data, min, max)
    end
    IM_ASSERT(false)
    return data, false
end

--- @param data_type ImGuiDataType
--- @param data      number
function ImGui.DataTypeIsZero(data_type, data)
    local g = GImGui
    return ImGui.DataTypeCompare(data_type, data, g.DataTypeZeroValue) == 0
end

local GetMinimumStepAtDecimalPrecision do

local min_steps = { 1.0, 0.1, 0.01, 0.001, 0.0001, 0.00001, 0.000001, 0.0000001, 0.00000001, 0.000000001 }

--- @param decimal_precision int
--- @return float
function GetMinimumStepAtDecimalPrecision(decimal_precision)
    if decimal_precision < 0 then
        return FLT_MIN
    end
    if decimal_precision < #min_steps then
        return min_steps[decimal_precision + 1]
    else
        return ImPow(10.0, -decimal_precision)
    end
end

end

local ImParseFormatFindStart

--- @param format    string
--- @param data_type ImGuiDataType
--- @param v         number
function ImGui.RoundScalarWithFormatT(format, data_type, v)
    -- IM_UNUSED(data_type)
    IM_ASSERT(data_type == ImGuiDataType.Float or data_type == ImGuiDataType.Double)
    local fmt_start = ImParseFormatFindStart(format)
    if string.byte(format, fmt_start) ~= 37 or string.byte(format, fmt_start + 1) == 37 then
        return v -- Don't apply if the value is not visible in the format string
    end

    -- Sanitize format
    local fmt_sanitized = ImParseFormatSanitizeForPrinting(string.sub(format, fmt_start), nil, 32)

    -- Format value with our rounding, and read back
    local v_str = ImFormatString(fmt_sanitized, v)
    -- [Luau] leading spaces: ImAtof() skips them

    v = ImAtof(v_str) or v
    return v
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: InputScalar, InputFloat, InputInt, etc.
-------------------------------------------------------------------------------
-- - ImParseFormatFindStart() [Internal]
-- - ImParseFormatFindEnd() [Internal]
-- - ImParseFormatTrimDecorations() [Internal]
-- - ImParseFormatSanitizeForScanning() [Internal]
-- - ImParseFormatPrecision() [Internal]
-- - TempInputText() [Internal]
-- - TempInputScalar() [Internal]
-- - InputScalar()
-- - InputScalarN()
-- - InputFloat()
-- - InputFloat2()
-- - InputFloat3()
-- - InputFloat4()
-- - InputInt()
-- - InputInt2()
-- - InputInt3()
-- - InputInt4()
-- - InputDouble()
-------------------------------------------------------------------------------

-- We don't use strchr() because our strings are usually very short and often start with '%'
--- @param fmt string
function ImParseFormatFindStart(fmt)
    local len = #fmt
    local i = 1
    local c
    while i < len do
        c = string.byte(fmt, i)
        if c == 37 and string.byte(fmt, i + 1) ~= 37 then -- '%'
            return i
        elseif c == 37 then
            i = i + 1
        end
        i = i + 1
    end
    return nil
end

--- @param fmt string
--- @param pos int
local function ImParseFormatFindEnd(fmt, pos)
    -- Printf/scanf types modifiers: I/L/h/j/l/t/w/z. Other uppercase letters qualify as types aka end of the format.
    if string.byte(fmt, pos) ~= 37 then -- '%'
        return pos
    end
    local ignored_uppercase_mask = bit32.bor(bit32.lshift(1, 73 - 65), bit32.lshift(1, 76 - 65))
    local ignored_lowercase_mask = bit32.bor(bit32.lshift(1, 104 - 97), bit32.lshift(1, 106 - 97), bit32.lshift(1, 108 - 97), bit32.lshift(1, 116 - 97), bit32.lshift(1, 119 - 97), bit32.lshift(1, 122 - 97))
    local len = #fmt
    local c
    for i = pos, len do
        c = string.byte(fmt, i)
        if c >= 65 and c <= 90 and (bit32.band(bit32.lshift(1, c - 65), ignored_uppercase_mask) == 0) then
            return i + 1
        end
        if c >= 97 and c <= 122 and (bit32.band(bit32.lshift(1, c - 97), ignored_lowercase_mask) == 0) then
            return i + 1
        end
    end
    return len + 1
end

-- Extract the format out of a format string with leading or trailing decorations
--  fmt = "blah blah"  -> return ""
--  fmt = "%.3f"       -> return "%.3f"
--  fmt = "hello %.3f" -> return "%.3f"
--  fmt = "%.3f hello" -> return "%.3f"
--- @param fmt string
local function ImParseFormatTrimDecorations(fmt)
    local fmt_start = ImParseFormatFindStart(fmt)
    if fmt_start == nil or string.byte(fmt, fmt_start) ~= 37 then -- '%'
        return ""
    end
    local fmt_end = ImParseFormatFindEnd(fmt, fmt_start)
    if fmt_end > #fmt then -- If we only have leading decoration, we don't need to copy the data.
        return string.sub(fmt, fmt_start)
    end
    return string.sub(fmt, fmt_start, fmt_end - 1)
end

-- Sanitize format
-- - Zero terminate so extra characters after format (e.g. "%f123") don't confuse atof/atoi
-- - stb_sprintf.h supports several new modifiers which format numbers in a way that also makes them incompatible atof/atoi.
-- [Luau] fmt_out is a byte table (may be nil); returns the sanitized format as a string
--- @param fmt_in       string
--- @param fmt_out      char[]?
--- @param fmt_out_size size_t
function ImParseFormatSanitizeForPrinting(fmt_in, fmt_out, fmt_out_size)
    local fmt_end = ImParseFormatFindEnd(fmt_in, 1)
    -- IM_UNUSED(fmt_out_size)
    IM_ASSERT(fmt_end < fmt_out_size) -- Format is too long, let us know if this happens to you!
    fmt_out = fmt_out or {}
    local n = 0
    for i = 1, fmt_end - 1 do
        local c = string.byte(fmt_in, i)
        if c ~= 39 and c ~= 36 and c ~= 95 then -- Custom flags provided by stb_sprintf.h. POSIX 2008 also supports '.
            n = n + 1
            fmt_out[n] = c
        end
    end
    fmt_out[n + 1] = 0 -- Zero-terminate
    return string.char(unpack(fmt_out, 1, n))
end

-- - For scanning we need to remove all width and precision fields and flags "%+3.7f" -> "%f". BUT don't strip types like "%I64d" which includes digits. ! "%07I64d" -> "%I64d"
--- @param fmt_in       string
--- @param fmt_out      char[]
--- @param fmt_out_size size_t
function ImParseFormatSanitizeForScanning(fmt_in, fmt_out, fmt_out_size)
    local fmt_end = ImParseFormatFindEnd(fmt_in, 1)
    -- IM_UNUSED(fmt_out_size)
    IM_ASSERT(fmt_end < fmt_out_size) -- Format is too long, let us know if this happens to you!
    local has_type = false
    local fmt_in_begin = 1
    local fmt_out_begin = 1
    while fmt_in_begin < fmt_end do
        repeat
        local c = string.byte(fmt_in, fmt_in_begin, fmt_in_begin)
        fmt_in_begin = fmt_in_begin + 1

        if (not has_type and ((c >= 48 and c <= 57) or c == 46 or c == 43 or c == 35)) then
            break
        end

        has_type = has_type or ((c >= 97 and c <= 122) or (c >= 65 and c <= 90)) -- Stop skipping digits
        if c ~= 39 and c ~= 36 and c ~= 95 then -- Custom flags provided by stb_sprintf.h. POSIX 2008 also supports '.
            fmt_out[fmt_out_begin] = c
            fmt_out_begin = fmt_out_begin + 1
        end

        until true
    end
    -- fmt_out[fmt_out_begin] = 0 -- Zero-terminate
    return string.char(unpack(fmt_out)) -- FIXME: not ideal
end

--- @param str string
--- @param pos int
local function ImAtoi(str, pos)
    local negative = false
    if string.byte(str, pos) == 45 then -- '-'
        negative = true
        pos = pos + 1
    end
    if string.byte(str, pos) == 43 then -- '+'
        pos = pos + 1
    end
    local len = #str
    local v = 0
    local c = string.byte(str, pos)
    while c >= 48 and c <= 57 do
        v = v * 10 + c - 48
        pos = pos + 1
        c = string.byte(str, pos)
        if pos > len then break end
    end
    return negative and -v or v, pos
end

-- Parse display precision back from the display format string
-- FIXME: This is still used by some navigation code path to infer a minimum tweak step, but we should aim to rework widgets so it isn't needed.
--- @param fmt               string
--- @param default_precision int
local function ImParseFormatPrecision(fmt, default_precision)
    local pos = ImParseFormatFindStart(fmt)
    if not pos then
        return default_precision
    end
    pos = pos + 1
    local len = #fmt
    local c = string.byte(fmt, pos)
    while c >= 48 and c <= 57 do
        pos = pos + 1
        c = string.byte(fmt, pos)
        if pos > len then break end
    end
    local precision = INT_MAX
    if c == 46 then -- '.'
        precision, pos = ImAtoi(fmt, pos + 1)
        if precision < 0 or precision > 99 then
            precision = default_precision
        end
    end
    c = string.byte(fmt, pos)
    if c == 101 or c == 69 then -- Maximum precision with scientific notation
        precision = -1
    end
    if (c == 103 or c == 71) and precision == INT_MAX then
        precision = -1
    end
    return (precision == INT_MAX) and default_precision or precision
end

-- Create text input in place of another active widget (e.g. used when doing a Ctrl+Click on drag/slider widgets)
-- - This must be submitted right after the item it is overlaying.
-- FIXME: Facilitate using this in variety of other situations.
--- @param bb        ImRect
--- @param id        ImGuiID
--- @param label     string
--- @param buf       char[]
--- @param buf_size  int
--- @param flags?    ImGuiInputTextFlags
--- @param callback? ImGuiInputTextCallback
--- @param user_data any
function ImGui.TempInputText(bb, id, label, buf, buf_size, flags, callback, user_data)
    if flags == nil then flags = 0 end

    -- On the first frame, g.TempInputTextId == 0, then on subsequent frames it becomes == id.
    -- We clear ActiveID on the first frame to allow the InputText() taking it back.
    local g = GImGui
    local window = g.CurrentWindow

    local is_deactivated = (g.InputTextDeactivatedState.ID == id)
    local is_active = (g.TempInputId == id)
    if (not is_active and not is_deactivated) then
        ImGui.ClearActiveID()
    end

    local backup_pos = ImVec2()
    ImVec2_Copy(backup_pos, window.DC.CursorPos)
    ImVec2_Copy(window.DC.CursorPos, bb.Min)
    g.LastItemData.ItemFlags = bit32.bor(g.LastItemData.ItemFlags, ImGuiItemFlags.AllowDuplicateId) -- Using ImGuiInputTextFlags.MergedItem above will skip ItemAdd() so we poke here.
    local value_changed = ImGui.InputTextEx(label, nil, buf, buf_size, bb:GetSize(), bit32.bor(flags, ImGuiInputTextFlags.TempInput, ImGuiInputTextFlags.AutoSelectAll), callback, user_data)
    ImGui.KeepAliveID(id) -- Not done because of ImGuiInputTextFlags.TempInput
    if (not is_active and not is_deactivated) then
        -- First frame we started displaying the InputText widget, we expect it to take the active id.
        IM_ASSERT(g.ActiveId == id)
        g.TempInputId = g.ActiveId
    end
    if is_active and g.ActiveId ~= id then
        g.TempInputId = 0
    end
    ImVec2_Copy(window.DC.CursorPos, backup_pos)

    return value_changed
end

-- Note that Drag/Slider functions are only forwarding the min/max values clamping values if the ImGuiSliderFlags.AlwaysClamp flag is set!
-- This is intended: this way we allow Ctrl+Click manual input to set a value out of bounds, for maximum flexibility.
-- However this may not be ideal for all uses, as some user code may break on out of bound values.
--- @param bb         ImRect
--- @param id         ImGuiID
--- @param label      string
--- @param data_type  ImGuiDataType
--- @param data       number
--- @param format     string
--- @param clamp_min? number
--- @param clamp_max? number
function ImGui.TempInputScalar(bb, id, label, data_type, data, format, clamp_min, clamp_max)
    -- FIXME: May need to clarify display behavior if format doesn't contain %.
    -- "%d" -> "%d" / "There are %d items" -> "%d" / "items" -> "%d" (fallback). Also see #6405
    local g = GImGui
    local type_info = ImGui.DataTypeGetInfo(data_type)
    local data_buf, data_buf_size = {}, 32
    format = ImParseFormatTrimDecorations(format)
    if format == "" then
        format = type_info.PrintFmt
    end
    ImGui.DataTypeFormatString(data_buf, data_buf_size, data_type, data, format)
    ImStd.ImStrTrimBlanks(data_buf)

    local flags = bit32.bor(ImGuiInputTextFlags.AutoSelectAll, ImGuiInputTextFlags.LocalizeDecimalPoint)
    g.LastItemData.ItemFlags = bit32.bor(g.LastItemData.ItemFlags, ImGuiItemFlags.NoMarkEdited) -- Because TempInputText() uses ImGuiInputTextFlags.MergedItem it doesn't submit a new item, so we poke LastItemData.
    g.LastItemData.ItemFlags = (bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.LiveEditOnInputScalar) ~= 0) and bit32.bor(g.LastItemData.ItemFlags, ImGuiItemFlags.LiveEditOnInputText) or bit32.band(g.LastItemData.ItemFlags, bit32.bnot(ImGuiItemFlags.LiveEditOnInputText))
    if not ImGui.TempInputText(bb, id, label, data_buf, data_buf_size, flags) then
        return data, false
    end

    -- Backup old value
    local data_backup = data

    -- Apply new value (or operations) then clamp
    data = ImGui.DataTypeApplyFromText(data_buf, data_type, data, format, nil)
    if clamp_min or clamp_max then
        if clamp_min and clamp_max and ImGui.DataTypeCompare(data_type, clamp_min, clamp_max) > 0 then
            clamp_min, clamp_max = clamp_max, clamp_min
        end
        data = ImGui.DataTypeClamp(data_type, data, clamp_min, clamp_max)
    end

    -- Only mark as edited if new value is different
    g.LastItemData.ItemFlags = bit32.band(g.LastItemData.ItemFlags, bit32.bnot(ImGuiItemFlags.NoMarkEdited))
    local value_changed = data_backup ~= data
    if bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue) ~= 0 then
        local state = ImGui.GetInputTextState(g.LastItemData.ID)
        if state ~= nil then
            value_changed = value_changed or ((bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.LiveEditOnInputScalar) ~= 0) and (state.EditedThisFrame or state.ValidatedThisFrame) or state.ValidatedThisFrame)
        end
    end

    if value_changed then
        ImGui.MarkItemEdited(id)
    end

    return data, value_changed
end

-- [Port] Note: data is passed by value and the new value is returned: Returns (data, value_changed). For an Input widget, step and step_fast are optional.
-- Read code of e.g. InputFloat(), InputInt() etc. or examples in 'Demo->Widgets->Data Types' to understand how to use this function directly.
--- @param label      string
--- @param data_type  ImGuiDataType
--- @param data       number
--- @param step?      number
--- @param step_fast? number
--- @param format?    string
--- @param flags?     ImGuiInputTextFlags
local InputScalar_button_size = ImVec2() -- [Luau] scratch for the step buttons' size (ButtonEx() only reads it)
function ImGui.InputScalar(label, data_type, data, step, step_fast, format, flags)
    if flags == nil then flags = 0 end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return data, false
    end

    local g = GImGui
    local style = g.Style
    -- IM_ASSERT((flags & ImGuiInputTextFlags.EnterReturnsTrue) == 0) -- Not supported by InputScalar(). Please open an issue if you this would be useful to you. Otherwise use IsItemDeactivatedAfterEdit()!

    if format == nil then
        format = ImGui.DataTypeGetInfo(data_type).PrintFmt
    end

    local data_default = (bit32.band(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasRefVal) ~= 0) and g.NextItemData.RefVal or g.DataTypeZeroValue

    local buf, buf_size = {}, 64 -- [Port] char buf[64]; IM_COUNTOF(buf)
    if bit32.band(flags, ImGuiInputTextFlags.DisplayEmptyRefVal) ~= 0 and ImGui.DataTypeCompare(data_type, data, data_default) == 0 then
        buf[1] = 0
    else
        ImGui.DataTypeFormatString(buf, buf_size, data_type, data, format)
    end

    -- Disable the MarkItemEdited() call in InputText but keep ImGuiItemStatusFlags.Edited.
    -- We call MarkItemEdited() ourselves by comparing the actual data rather than the string.
    g.NextItemData.ItemFlagsSet = bit32.bor(g.NextItemData.ItemFlagsSet, ImGuiItemFlags.NoMarkEdited)
    flags = bit32.bor(flags, ImGuiInputTextFlags.AutoSelectAll, ImGuiInputTextFlags.LocalizeDecimalPoint)

    local has_step_buttons = (step ~= nil)
    local button_size = has_step_buttons and ImGui.GetFrameHeight() or 0.0
    local ret
    if has_step_buttons then
        -- With Step Buttons
        ImGui.BeginGroup() -- The only purpose of the group here is to allow the caller to query item data e.g. IsItemActive()
        ImGui.PushID(label)
        ImGui.SetNextItemWidth(ImMax(1.0, ImGui.CalcItemWidth() - (button_size + style.ItemInnerSpacing.x) * 2))
        ret = ImGui.InputText("", buf, buf_size, flags) -- PushID(label) + "" gives us the expected ID from outside point of view
        -- IMGUI_TEST_ENGINE_ITEM_INFO()
    else
        -- Without Step Buttons
        ret = ImGui.InputText(label, buf, buf_size, flags)
    end

    -- Apply
    local value_changed = false
    if bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.LiveEditOnInputScalar) ~= 0 then
        local input_edited = bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.EditedInternal) ~= 0 -- We would be using 'ret' if ImGuiInputTextFlags.EnterReturnsTrue was not involved.
        if input_edited then
            data, value_changed = ImGui.DataTypeApplyFromText(buf, data_type, data, format, bit32.band(flags, ImGuiInputTextFlags.ParseEmptyRefVal) ~= 0 and data_default or nil)
        end
    else
        -- g.LastItemData.StatusFlags &= ~ImGuiItemStatusFlags_Edited
        if (g.DeactivatedItemData.ID == g.LastItemData.ID) then
            -- g.DeactivatedItemData.HasBeenEditedBefore = false; // Will be set below by MarkItemEdited()
            -- if (IsItemDeactivated()) // Should be unnecessary
            data, value_changed = ImGui.DataTypeApplyFromText(buf, data_type, data, format, bit32.band(flags, ImGuiInputTextFlags.ParseEmptyRefVal) ~= 0 and data_default or nil)
        end
    end
    if bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue) ~= 0 then
        local state = ImGui.GetInputTextState(g.LastItemData.ID)
        if state ~= nil then
            value_changed = value_changed or ((bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.LiveEditOnInputScalar) ~= 0) and (state.EditedThisFrame or state.ValidatedThisFrame) or state.ValidatedThisFrame)
        end
    end

    -- Step buttons
    if has_step_buttons then
        local backup_frame_padding_x, backup_frame_padding_y = style.FramePadding.x, style.FramePadding.y -- [Luau] scalar backup
        style.FramePadding.x = style.FramePadding.y
        if bit32.band(flags, ImGuiInputTextFlags.ReadOnly) ~= 0 then
            ImGui.BeginDisabled()
        end
        ImGui.PushItemFlag(ImGuiItemFlags.ButtonRepeat, true)
        ImGui.SameLine(0, style.ItemInnerSpacing.x)
        --- @cast step number
        local step_button_size = InputScalar_button_size; step_button_size.x = button_size; step_button_size.y = button_size
        if ImGui.ButtonEx("-", step_button_size) then
            data = ImGui.DataTypeApplyOp(data_type, 45, data, ((g.IO.KeyCtrl and step_fast) and step_fast or step))
            value_changed = true
            ret = true
        end
        ImGui.SameLine(0, style.ItemInnerSpacing.x)
        if ImGui.ButtonEx("+", step_button_size) then
            data = ImGui.DataTypeApplyOp(data_type, 43, data, ((g.IO.KeyCtrl and step_fast) and step_fast or step))
            value_changed = true
            ret = true
        end
        ImGui.PopItemFlag()
        if bit32.band(flags, ImGuiInputTextFlags.ReadOnly) ~= 0 then
            ImGui.EndDisabled()
        end
        local label_end = ImGui.FindRenderedTextEnd(label)
        if label_end ~= 1 then
            ImGui.SameLine(0, style.ItemInnerSpacing.x)
            ImGui.TextEx(label, label_end)
        end
        ImVec2_CopyV(style.FramePadding, backup_frame_padding_x, backup_frame_padding_y)

        ImGui.PopID()
        ImGui.EndGroup()
    end

    g.LastItemData.ItemFlags = bit32.band(g.LastItemData.ItemFlags, bit32.bnot(ImGuiItemFlags.NoMarkEdited))
    if value_changed then
        ImGui.MarkItemEdited(g.LastItemData.ID)
    end

    if bit32.band(flags, ImGuiInputTextFlags.EnterReturnsTrue) ~= 0 then
        return data, ret
    end
    return data, value_changed
end

--- @param label      string
--- @param data_type  ImGuiDataType
--- @param data       number[]
--- @param components int
--- @param step?      number
--- @param step_fast? number
--- @param format?    string
--- @param flags?     ImGuiInputTextFlags
function ImGui.InputScalarN(label, data_type, data, components, step, step_fast, format, flags)
    if flags == nil then flags = 0 end
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local value_changed = false
    ImGui.BeginGroup()
    ImGui.PushID(label)
    ImGui.PushMultiItemsWidths(components, ImGui.CalcItemWidth())
    for i = 1, components do
        ImGui.PushID(i - 1)
        if i > 1 then
            ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)
        end
        local changed
        data[i], changed = ImGui.InputScalar("", data_type, data[i], step, step_fast, format, flags)
        if changed then
            value_changed = true
        end
        ImGui.PopID()
        ImGui.PopItemWidth()
    end
    ImGui.PopID()

    local label_end = ImGui.FindRenderedTextEnd(label)
    if label_end > 1 then
        ImGui.SameLine(0.0, g.Style.ItemInnerSpacing.x)
        ImGui.TextEx(label, label_end)
    end

    ImGui.EndGroup()
    return value_changed
end

--- @param label   string
--- @param v       [float, float, float]
--- @param format? string
--- @param flags?  ImGuiInputTextFlags
function ImGui.InputFloat3(label, v, format, flags)
    if format == nil then format = "%.3f" end

    return ImGui.InputScalarN(label, ImGuiDataType.Float, v, 3, nil, nil, format, flags)
end

function ImGui.InputFloat2(label, v, format, flags)
    return ImGui.InputScalarN(label, ImGuiDataType.Float, v, 2, nil, nil, format or "%.3f", flags)
end

function ImGui.InputFloat4(label, v, format, flags)
    return ImGui.InputScalarN(label, ImGuiDataType.Float, v, 4, nil, nil, format or "%.3f", flags)
end

function ImGui.InputInt2(label, v, flags)
    return ImGui.InputScalarN(label, ImGuiDataType.S32, v, 2, nil, nil, "%d", flags)
end

function ImGui.InputInt3(label, v, flags)
    return ImGui.InputScalarN(label, ImGuiDataType.S32, v, 3, nil, nil, "%d", flags)
end

function ImGui.InputInt4(label, v, flags)
    return ImGui.InputScalarN(label, ImGuiDataType.S32, v, 4, nil, nil, "%d", flags)
end

--- @param label      string
--- @param v          int
--- @param step?      int
--- @param step_fast? int
--- @param flags?     ImGuiInputTextFlags
function ImGui.InputInt(label, v, step, step_fast, flags)
    if step      == nil then step      = 1   end
    if step_fast == nil then step_fast = 100 end
    if flags     == nil then flags     = 0   end

    -- Hexadecimal input provided as a convenience but the flag name is awkward. Typically you'd use InputText() to parse your own data, if you want to handle prefixes.
    local format = (bit32.band(flags, ImGuiInputTextFlags.CharsHexadecimal) ~= 0) and "%08X" or "%d"
    return ImGui.InputScalar(label, ImGuiDataType.S32, v, (step > 0) and step or nil, (step_fast > 0) and step_fast or nil, format, flags)
end

--- @param label      string
--- @param v          float
--- @param step?      float
--- @param step_fast? float
--- @param format?    string
--- @param flags?     ImGuiInputTextFlags
function ImGui.InputFloat(label, v, step, step_fast, format, flags)
    if step      == nil then step      = .0     end
    if step_fast == nil then step_fast = .0     end
    if format    == nil then format    = "%.3f" end

    return ImGui.InputScalar(label, ImGuiDataType.Float, v, (step > 0.0 and step or nil), (step_fast > 0.0 and step_fast or nil), format, flags)
end

--- @param label      string
--- @param v          double
--- @param step?      double
--- @param step_fast? double
--- @param format?    string
--- @param flags?     ImGuiInputTextFlags
function ImGui.InputDouble(label, v, step, step_fast, format, flags)
    if step      == nil then step      = .0     end
    if step_fast == nil then step_fast = .0     end
    if format    == nil then format    = "%.6f" end

    return ImGui.InputScalar(label, ImGuiDataType.Double, v, (step > 0.0 and step or nil), (step_fast > 0.0 and step_fast or nil), format, flags)
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: DragScalar, DragFloat, DragInt, etc.
-------------------------------------------------------------------------------
-- - DragBehaviorT<>() [Internal]
-- - DragBehavior() [Internal]
-- - DragScalar()
-- - DragScalarN()
-- - DragFloat()
-- - DragFloat2()
-- - DragFloat3()
-- - DragFloat4()
-- - DragFloatRange2()
-- - DragInt()
-- - DragInt2()
-- - DragInt3()
-- - DragInt4()
-- - DragIntRange2()
-------------------------------------------------------------------------------

-- This is called by DragBehavior() when the widget is active (held by mouse or being manipulated with Nav controls)
--- @generic T : number
--- @param TYPE       fun(val: number): T
--- @param SIGNEDTYPE fun(val: number): T
--- @param data_type  ImGuiDataType
--- @param v          T
--- @param v_speed    float
--- @param v_min      T
--- @param v_max      T
--- @param format     string
--- @param flags      ImGuiSliderFlags
--- @return T    new_v   # Updated `v`
--- @return bool changed
function ImGui.DragBehaviorT(TYPE, SIGNEDTYPE, data_type, v, v_speed, v_min, v_max, format, flags)
    local g = GImGui
    local axis = (bit32.band(flags, ImGuiSliderFlags.Vertical) ~= 0) and ImGuiAxis.Y or ImGuiAxis.X
    local is_bounded = (v_min < v_max) or ((v_min == v_max) and (v_min ~= 0.0 or (bit32.band(flags, ImGuiSliderFlags.ClampZeroRange) ~= 0)))
    local is_wrapped = is_bounded and (bit32.band(flags, ImGuiSliderFlags.WrapAround) ~= 0)
    local is_logarithmic = bit32.band(flags, ImGuiSliderFlags.Logarithmic) ~= 0
    local is_floating_point = (data_type == ImGuiDataType.Float) or (data_type == ImGuiDataType.Double)

    -- Default tweak speed
    if v_speed == 0.0 and is_bounded and (v_max - v_min < math.huge) then
        v_speed = (v_max - v_min) * g.DragSpeedDefaultRatio
    end

    -- Inputs accumulates into g.DragCurrentAccum, which is flushed into the current value as soon as it makes a difference with our precision settings
    local adjust_delta = 0.0
    if g.ActiveIdSource == ImGuiInputSource.Mouse and ImGui.IsMousePosValid() and ImGui.IsMouseDragPastThreshold(0, g.IO.MouseDragThreshold * DRAG_MOUSE_THRESHOLD_FACTOR) then
        adjust_delta = g.IO.MouseDelta[axis]
        if g.IO.KeyAlt and bit32.band(flags, ImGuiSliderFlags.NoSpeedTweaks) == 0 then
            adjust_delta = adjust_delta / 100.0
        end
        if g.IO.KeyShift and bit32.band(flags, ImGuiSliderFlags.NoSpeedTweaks) == 0 then
            adjust_delta = adjust_delta * 10.0
        end
    elseif g.ActiveIdSource == ImGuiInputSource.Keyboard or g.ActiveIdSource == ImGuiInputSource.Gamepad then
        local decimal_precision
        if is_floating_point then
            decimal_precision = ImParseFormatPrecision(format, 3)
        else
            decimal_precision = 0
        end
        local slow_key = (g.NavInputSource == ImGuiInputSource.Gamepad) and ImGuiKey.NavGamepadTweakSlow or ImGuiKey.NavKeyboardTweakSlow
        local fast_key = (g.NavInputSource == ImGuiInputSource.Gamepad) and ImGuiKey.NavGamepadTweakFast or ImGuiKey.NavKeyboardTweakFast

        local tweak_factor
        if bit32.band(flags, ImGuiSliderFlags.NoSpeedTweaks) ~= 0 then
            tweak_factor = 1.0
        elseif ImGui.IsKeyDown(slow_key) then
            tweak_factor = 1.0 / 10.0
        elseif ImGui.IsKeyDown(fast_key) then
            tweak_factor = 10.0
        else
            tweak_factor = 1.0
        end

        adjust_delta = ImGui.GetNavTweakPressedAmount(axis) * tweak_factor
        v_speed = ImMax(v_speed, GetMinimumStepAtDecimalPrecision(decimal_precision))
    end
    adjust_delta = adjust_delta * v_speed

    -- For vertical drag we currently assume that Up=higher value (like we do with vertical sliders). This may become a parameter.
    if axis == ImGuiAxis.Y then
        adjust_delta = -adjust_delta
    end

    -- For logarithmic use our range is effectively 0..1 so scale the delta into that range
    if is_logarithmic and (v_max - v_min < FLT_MAX) and (v_max - v_min > 0.000001) then  -- Epsilon to avoid /0
        adjust_delta = adjust_delta / (v_max - v_min)
    end

    -- Clear current value on activation
    -- Avoid altering values and clamping when we are _already_ past the limits and heading in the same direction, so e.g. if range is 0..255, current value is 300 and we are pushing to the right side, keep the 300.
    local is_just_activated = g.ActiveIdIsJustActivated
    local is_already_past_limits_and_pushing_outward = is_bounded and not is_wrapped and ((v >= v_max and adjust_delta > 0.0) or (v <= v_min and adjust_delta < 0.0))
    if is_just_activated or is_already_past_limits_and_pushing_outward then
        g.DragCurrentAccum = 0.0
        g.DragCurrentAccumDirty = false
    elseif adjust_delta ~= 0.0 then
        g.DragCurrentAccum = g.DragCurrentAccum + adjust_delta
        g.DragCurrentAccumDirty = true
    end

    if not g.DragCurrentAccumDirty then
        return v, false
    end

    local v_cur = (TYPE)(v)
    local v_old_ref_for_accum_remainder = 0.0

    local logarithmic_zero_epsilon = 0.0 -- Only valid when is_logarithmic is true
    local zero_deadzone_halfsize = 0.0 -- Drag widgets have no deadzone (as it doesn't make sense)
    if is_logarithmic then
        -- When using logarithmic sliders, we need to clamp to avoid hitting zero, but our choice of clamp value greatly affects slider precision. We attempt to use the specified precision to estimate a good lower bound.
        local decimal_precision
        if is_floating_point then
            decimal_precision = ImParseFormatPrecision(format, 3)
        else
            decimal_precision = 1
        end
        logarithmic_zero_epsilon = ImPow(0.1, decimal_precision)

        -- Convert to parametric space, apply delta, convert back
        local v_old_parametric = ImGui.ScaleRatioFromValueT(data_type, v_cur, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
        local v_new_parametric = v_old_parametric + g.DragCurrentAccum
        v_cur = ImGui.ScaleValueFromRatioT(TYPE, SIGNEDTYPE, data_type, v_new_parametric, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
        v_old_ref_for_accum_remainder = v_old_parametric
    else
        v_cur = (TYPE)(v_cur + (SIGNEDTYPE)(g.DragCurrentAccum))
    end

    -- Round to user desired precision based on format string
    if is_floating_point and bit32.band(flags, ImGuiSliderFlags.NoRoundToFormat) == 0 then
        v_cur = ImGui.RoundScalarWithFormatT(format, data_type, v_cur)
    end

    -- Preserve remainder after rounding has been applied. This also allow slow tweaking of values.
    g.DragCurrentAccumDirty = false
    if is_logarithmic then
        -- Convert to parametric space, apply delta, convert back
        local v_new_parametric = ImGui.ScaleRatioFromValueT(data_type, v_cur, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
        g.DragCurrentAccum = g.DragCurrentAccum - (v_new_parametric - v_old_ref_for_accum_remainder)
    else
        g.DragCurrentAccum = g.DragCurrentAccum - ((SIGNEDTYPE)(v_cur) - (SIGNEDTYPE)(v))
    end

    -- Lose zero sign for float/double
    if v_cur == (TYPE)(-0) then
        v_cur = (TYPE)(0)
    end

    if v ~= v_cur and is_bounded then
        if is_wrapped then
            -- Wrap values
            if v_cur < v_min then
                v_cur = (TYPE)(v_cur + (TYPE)((TYPE)(v_max - v_min) + (is_floating_point and 0 or 1)))
            end
            if v_cur > v_max then
                v_cur = (TYPE)(v_cur - (TYPE)((TYPE)(v_max - v_min) - (is_floating_point and 0 or 1)))
            end
        else
            -- Clamp values + handle overflow/wrap-around for integer types.
            if v_cur < v_min or (v_cur > v and adjust_delta < 0.0 and not is_floating_point) then
                v_cur = (TYPE)(v_min)
            end
            if v_cur > v_max or (v_cur < v and adjust_delta > 0.0 and not is_floating_point) then
                v_cur = (TYPE)(v_max)
            end
        end
    end

    -- Apply result
    if v == v_cur then
        return v, false
    end
    v = v_cur
    return v, true
end

local function ShortcutsForCancel(id)
    local g = GImGui
    local is_cancel_with_keyboard = ImGui.Shortcut(ImGuiKey.Escape, ImGuiInputFlags.None, id)
    -- [Luau] ImGuiKey_NavGamepadCancel macro inlined (io.ConfigNavSwapGamepadButtons is not ported: always FaceRight)
    local is_cancel_with_gamepad = bit32.band(g.IO.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad) ~= 0 and bit32.band(g.IO.BackendFlags, ImGuiBackendFlags.HasGamepad) ~= 0 and ImGui.Shortcut(ImGuiKey.GamepadFaceRight, ImGuiInputFlags.None, id)
    local is_cancel_with_mouse = ImGui.IsMouseReleased(ImGuiMouseButton.Right, id)
    if is_cancel_with_mouse then
        ImGui.SetKeyOwner(ImGuiKey.MouseRight, id)
    end
    return is_cancel_with_keyboard or is_cancel_with_gamepad or is_cancel_with_mouse
end

--- @param id        ImGuiID
--- @param data_type ImGuiDataType
--- @param v         number
--- @param v_speed   float
--- @param min       number
--- @param max       number
--- @param format    string
--- @param flags     ImGuiSliderFlags
@native
function ImGui.DragBehavior(id, data_type, v, v_speed, min, max, format, flags)
    -- Read imgui.cpp "API BREAKING CHANGES" section for 1.78 if you hit this assert.
    IM_ASSERT((flags == 1 or bit32.band(flags, ImGuiSliderFlags.InvalidMask_) == 0), "Invalid ImGuiSliderFlags flags! Has the legacy 'float power' argument been mistakenly cast to flags? Call function with ImGuiSliderFlags_Logarithmic flags instead.")

    -- Things we can do easily outside the DragBehaviorT<> template, saves code generation.
    local g = GImGui
    if g.ActiveId == id then
        if g.ActiveIdSource == ImGuiInputSource.Mouse and not g.IO.MouseDown[0] then
            ImGui.ClearActiveID()
        elseif (g.ActiveIdSource == ImGuiInputSource.Keyboard or g.ActiveIdSource == ImGuiInputSource.Gamepad) and g.NavActivatePressedId == id and not g.ActiveIdIsJustActivated then
            ImGui.ClearActiveID()
        end
        if ShortcutsForCancel(id) and g.ActiveId == id then
            -- Canceling action reverts to initial value
            local value_changed = (v ~= g.ActiveIdValueOnActivation)
            v = g.ActiveIdValueOnActivation
            ImGui.ClearActiveID()
            return v, value_changed
        end
    end
    if g.ActiveId ~= id then
        return v, false
    end
    if bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.ReadOnly) ~= 0 or bit32.band(flags, ImGuiSliderFlags.ReadOnly) ~= 0 then
        return v, false
    end

    if data_type == ImGuiDataType.S8 then
        return ImGui.DragBehaviorT(ImS32, ImS32, ImGuiDataType.S32, v, v_speed, min and min or IM_S8_MIN, max and max or IM_S8_MAX, format, flags)
    elseif data_type == ImGuiDataType.U8 then
        return ImGui.DragBehaviorT(ImU32, ImS32, ImGuiDataType.U32, v, v_speed, min and min or IM_U8_MIN, max and max or IM_U8_MAX, format, flags)
    elseif data_type == ImGuiDataType.S16 then
        return ImGui.DragBehaviorT(ImS32, ImS32, ImGuiDataType.S32, v, v_speed, min and min or IM_S16_MIN, max and max or IM_S16_MAX, format, flags)
    elseif data_type == ImGuiDataType.U16 then
        return ImGui.DragBehaviorT(ImU32, ImS32, ImGuiDataType.U32, v, v_speed, min and min or IM_U16_MIN, max and max or IM_U16_MAX, format, flags)
    elseif data_type == ImGuiDataType.S32 then
        return ImGui.DragBehaviorT(ImS32, ImS32, data_type, v, v_speed, min and min or IM_S32_MIN, max and max or IM_S32_MAX, format, flags)
    elseif data_type == ImGuiDataType.U32 then
        return ImGui.DragBehaviorT(ImU32, ImS32, data_type, v, v_speed, min and min or IM_U32_MIN, max and max or IM_U32_MAX, format, flags)
    elseif data_type == ImGuiDataType.S64 then
        return ImGui.DragBehaviorT(ImS64, ImS64, data_type, v, v_speed, min and min or IM_S64_MIN, max and max or IM_S64_MAX, format, flags)
    elseif data_type == ImGuiDataType.U64 then
        return ImGui.DragBehaviorT(ImU64, ImS64, data_type, v, v_speed, min and min or IM_U64_MIN, max and max or IM_U64_MAX, format, flags)
    elseif data_type == ImGuiDataType.Float then
        return ImGui.DragBehaviorT(float, float, data_type, v, v_speed, min and min or -FLT_MAX, max and max or FLT_MAX, format, flags)
    elseif data_type == ImGuiDataType.Double then
        return ImGui.DragBehaviorT(double, double, data_type, v, v_speed, min and min or -DBL_MAX, max and max or DBL_MAX, format, flags)
    end

    IM_ASSERT(false)
    return v, false
end

-- Only clamp Ctrl+Click input when ImGuiSliderFlags.ClampOnInput is set (generally via ImGuiSliderFlags.AlwaysClamp)
--- @param flags     ImGuiSliderFlags
--- @param data_type ImGuiDataType
--- @param min       number
--- @param max       number
local function TempInputIsClampEnabled(flags, data_type, min, max)
    if bit32.band(flags, ImGuiSliderFlags.ClampOnInput) ~= 0 and (min ~= nil or max ~= nil) then
        local clamp_range_dir = 0
        if min ~= nil and max ~= nil then
            clamp_range_dir = ImGui.DataTypeCompare(data_type, min, max)
        end
        if min == nil or max == nil or clamp_range_dir < 0 then
            return true
        end
        if clamp_range_dir == 0 then
            return ImGui.DataTypeIsZero(data_type, min) and (bit32.band(flags, ImGuiSliderFlags.ClampZeroRange) ~= 0) or true
        end
    end
    return false
end

--- @param label     string
--- @param data_type ImGuiDataType
--- @param data      number
--- @param v_speed   float
--- @param min       number
--- @param max       number
--- @param format    string
--- @param flags     ImGuiSliderFlags
-- [Luau] memo of string.format(format, value) for drag/slider value text (same values are redrawn every frame).

local fmt_memo, fmt_memo_n = {}, 0
local SliderScalar_total_bb, SliderScalar_grab_bb, SliderScalar_frame_bb = ImRect(), ImRect(), ImRect() -- [Luau] scratch for SliderScalar()/DragScalar(), never escape
local SliderScalar_label_pos = ImVec2()
local DRAG_TEXT_ALIGN = ImVec2(0.5, 0.5)
function FormatCached(format, v)
    local m = fmt_memo[format]
    if m == nil then m = {}; fmt_memo[format] = m end
    local r = m[v]
    if r == nil then
        if fmt_memo_n >= 4096 then table.clear(fmt_memo); m = {}; fmt_memo[format] = m; fmt_memo_n = 0 end
        r = ImFormatString(format, v); m[v] = r; fmt_memo_n = fmt_memo_n + 1
    end
    return r
end

-- [Port] Note: data is passed by value and the new value is returned: Returns (data, value_changed). For a Drag widget, min and max are optional.
-- Read code of e.g. DragFloat(), DragInt() etc. or examples in 'Demo->Widgets->Data Types' to understand how to use this function directly.
@native
function ImGui.DragScalar(label, data_type, data, v_speed, min, max, format, flags)
    if v_speed == nil then v_speed = 1.0 end
    if flags == nil then flags = 0 end
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return data, false
    end

    local g = GImGui
    local style = g.Style
    local id = window:GetID(label)
    local w = ImGui.CalcItemWidth()
    local color_marker = (bit32.band(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasColorMarker) ~= 0) and g.NextItemData.ColorMarker or 0

    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size_x, label_size_y = ImGui.CalcTextSizeXY(label, 1, label_end, false) -- [Luau] scalar label_size
    local cursor = window.DC.CursorPos
    local frame_bb = SliderScalar_frame_bb -- [Luau] scratch: callees only read it
    frame_bb.Min.x, frame_bb.Min.y, frame_bb.Max.x, frame_bb.Max.y = cursor.x, cursor.y, cursor.x + w, cursor.y + (label_size_y + style.FramePadding.y * 2.0)
    local total_bb = SliderScalar_total_bb -- [Luau] scratch: ItemSize()/ItemAdd() only read it
    total_bb.Min.x = frame_bb.Min.x; total_bb.Min.y = frame_bb.Min.y
    total_bb.Max.x = frame_bb.Max.x + ((label_size_x > 0.0) and (style.ItemInnerSpacing.x + label_size_x) or 0.0); total_bb.Max.y = frame_bb.Max.y + 0.0

    local temp_input_allowed = (bit32.band(flags, ImGuiSliderFlags.NoInput) == 0)
    ImGui.ItemSize(total_bb, style.FramePadding.y)
    if not ImGui.ItemAdd(total_bb, id, frame_bb, temp_input_allowed and ImGuiItemFlags.Inputable or 0) then
        return data, false
    end

    -- Default format string when passing NULL
    if format == nil then
        format = ImGui.DataTypeGetInfo(data_type).PrintFmt
    end

    local hovered = ImGui.ItemHoverable(frame_bb, id, g.LastItemData.ItemFlags)
    local temp_input_is_active = temp_input_allowed and ImGui.TempInputIsActive(id)
    if not temp_input_is_active then
        -- Tabbing or Ctrl+Click on Drag turns it into an InputText
        local clicked = hovered and ImGui.IsMouseClickedEx(0, ImGuiInputFlags.None, id)
        local double_clicked = (hovered and g.IO.MouseClickedCount[0] == 2 and ImGui.TestKeyOwner(ImGuiKey.MouseLeft, id))
        local make_active = (clicked or double_clicked or g.NavActivateId == id)
        if make_active and (clicked or double_clicked) then
            ImGui.SetKeyOwner(ImGuiKey.MouseLeft, id)
        end
        if make_active and temp_input_allowed then
            if (clicked and g.IO.KeyCtrl) or double_clicked or (g.NavActivateId == id and bit32.band(g.NavActivateFlags, ImGuiActivateFlags.PreferInput) ~= 0) then
                temp_input_is_active = true
            end
        end

        -- (Optional) simple click (without moving) turns Drag into an InputText
        if g.IO.ConfigDragClickToInputText and temp_input_allowed and not temp_input_is_active then
            if g.ActiveId == id and hovered and g.IO.MouseReleased[0] and not ImGui.IsMouseDragPastThreshold(0, g.IO.MouseDragThreshold * DRAG_MOUSE_THRESHOLD_FACTOR) then
                g.NavActivateId = id
                g.NavActivateFlags = ImGuiActivateFlags.PreferInput
                temp_input_is_active = true
            end
        end

        -- Store initial value (not used by main lib but available as a convenience but some mods e.g. to revert)
        if make_active then
            g.ActiveIdValueOnActivation = data
        end

        if make_active and not temp_input_is_active then
            ImGui.SetActiveID(id, window)
            ImGui.SetFocusID(id, window)
            ImGui.FocusWindow(window)
            g.ActiveIdUsingNavDirMask = bit32.bor(bit32.lshift(1, ImGuiDir.Left), bit32.lshift(1, ImGuiDir.Right))
        end
    end

    if temp_input_is_active then
        local clamp_enabled = TempInputIsClampEnabled(flags, data_type, min, max)
        return ImGui.TempInputScalar(frame_bb, id, label, data_type, data, format, clamp_enabled and min or nil, clamp_enabled and max or nil)
    end

    -- Draw frame
    local frame_col = ImGui.GetColorU32(g.ActiveId == id and ImGuiCol.FrameBgActive or hovered and ImGuiCol.FrameBgHovered or ImGuiCol.FrameBg)
    ImGui.RenderNavCursor(frame_bb, id)
    ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, frame_col, false, style.FrameRounding)

    if color_marker ~= 0 and style.ColorMarkerSize > 0.0 then
        ImGui.RenderColorComponentMarker(frame_bb, ImGui.GetColorU32(color_marker, nil, true), style.FrameRounding)
    end

    ImGui.RenderFrameBorder(frame_bb.Min, frame_bb.Max, g.Style.FrameRounding)

    -- Drag behavior
    local value_changed
    data, value_changed = ImGui.DragBehavior(id, data_type, data, v_speed, min, max, format, flags)
    if value_changed then
        ImGui.MarkItemEdited(id)
    end

    -- Display value using user-provided display format so user can add prefix/suffix/decorations to the value.
    local is_mixed = bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue) ~= 0
    local value_buf = DataTypeFormatStringCached(data_type, data, (is_mixed and g.MixedValueLabel ~= nil) and g.MixedValueLabel or format)
    if g.LogEnabled then
        ImGui.LogSetNextTextDecoration("{", "}")
    end
    if is_mixed then
        ImGui.PushStyleColor(ImGuiCol.Text, g.Style.Colors[ImGuiCol.TextDisabled]) -- ImGuiCol_TextMixedValue
    end
    ImGui.RenderTextClipped(frame_bb.Min, frame_bb.Max, value_buf, nil, nil, DRAG_TEXT_ALIGN)
    if is_mixed then
        ImGui.PopStyleColor()
    end

    if label_size_x > 0.0 then
        local label_pos = SliderScalar_label_pos
        label_pos.x, label_pos.y = frame_bb.Max.x + style.ItemInnerSpacing.x, frame_bb.Min.y + style.FramePadding.y
        ImGui.RenderText(label_pos, label, 1, label_end, false)
    end

    return data, value_changed
end

--- @param label    string
--- @param v        float
--- @param v_speed? float
--- @param v_min?   float
--- @param v_max?   float
--- @param format?  string
--- @param flags?   ImGuiSliderFlags
function ImGui.DragFloat(label, v, v_speed, v_min, v_max, format, flags)
    if v_speed == nil then v_speed = 1.0    end
    if v_min   == nil then v_min   = 0.0    end
    if v_max   == nil then v_max   = 0.0    end
    if format  == nil then format  = "%.3f" end
    if flags   == nil then flags   = 0      end

    return ImGui.DragScalar(label, ImGuiDataType.Float, v, v_speed, v_min, v_max, format, flags)
end

-- NB: v_speed is float to allow adjusting the drag speed with more precision
--- @param label    string
--- @param v        int
--- @param v_speed? float
--- @param v_min?   int
--- @param v_max?   int
--- @param format?  string
--- @param flags?   ImGuiSliderFlags
@native
function ImGui.DragInt(label, v, v_speed, v_min, v_max, format, flags)
    if v_speed == nil then v_speed = 1.0  end
    if v_min   == nil then v_min   = 0    end
    if v_max   == nil then v_max   = 0    end
    if format  == nil then format  = "%d" end
    if flags   == nil then flags   = 0    end

    return ImGui.DragScalar(label, ImGuiDataType.S32, v, v_speed, v_min, v_max, format, flags)
end

-- [Port] `v` is mutated in place (1-based), returns value_changed
function ImGui.DragScalarN(label, data_type, v, components, v_speed, v_min, v_max, format, flags)
    if v_speed == nil then v_speed = 1.0 end
    if flags == nil then flags = 0 end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local value_changed = false
    ImGui.BeginGroup()
    ImGui.PushID(label)
    ImGui.PushMultiItemsWidths(components, ImGui.CalcItemWidth())
    for i = 1, components do
        ImGui.PushID(i - 1)
        if i > 1 then
            ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)
        end
        if bit32.band(flags, ImGuiSliderFlags.ColorMarkers) ~= 0 then
            ImGui.SetNextItemColorMarker(GDefaultRgbaColorMarkers[i])
        end
        local changed
        v[i], changed = ImGui.DragScalar("", data_type, v[i], v_speed, v_min, v_max, format, flags)
        value_changed = value_changed or changed
        ImGui.PopID()
        ImGui.PopItemWidth()
    end
    ImGui.PopID()

    local label_end = ImGui.FindRenderedTextEnd(label)
    if label_end > 1 then
        ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)
        ImGui.TextEx(label, label_end)
    end

    ImGui.EndGroup()
    return value_changed
end

local function DragFloatN(n)
    return function(label, v, v_speed, v_min, v_max, format, flags)
        return ImGui.DragScalarN(label, ImGuiDataType.Float, v, n, v_speed or 1.0, v_min or 0.0, v_max or 0.0, format or "%.3f", flags or 0)
    end
end
local function DragIntN(n)
    return function(label, v, v_speed, v_min, v_max, format, flags)
        return ImGui.DragScalarN(label, ImGuiDataType.S32, v, n, v_speed or 1.0, v_min or 0, v_max or 0, format or "%d", flags or 0)
    end
end
ImGui.DragFloat2 = DragFloatN(2)
ImGui.DragFloat3 = DragFloatN(3)
ImGui.DragFloat4 = DragFloatN(4)
ImGui.DragInt2 = DragIntN(2)
ImGui.DragInt3 = DragIntN(3)
ImGui.DragInt4 = DragIntN(4)

-- NB: You likely want to specify the ImGuiSliderFlags.AlwaysClamp when using this.
--- @return float v_current_min
--- @return float v_current_max
--- @return bool  value_changed
local function DragRange2(data_type, label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags)
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return v_current_min, v_current_max, false
    end

    local g = GImGui
    local lo = (data_type == ImGuiDataType.Float) and -FLT_MAX or INT_MIN
    local hi = (data_type == ImGuiDataType.Float) and FLT_MAX or INT_MAX
    ImGui.PushID(label)
    ImGui.BeginGroup()
    ImGui.PushMultiItemsWidths(2, ImGui.CalcItemWidth())

    local min_min = (v_min >= v_max) and lo or v_min
    local min_max = (v_min >= v_max) and v_current_max or ImMin(v_max, v_current_max)
    local min_flags = bit32.bor(flags, (min_min == min_max) and ImGuiSliderFlags.ReadOnly or 0)
    local value_changed, changed
    v_current_min, value_changed = ImGui.DragScalar("##min", data_type, v_current_min, v_speed, min_min, min_max, format, min_flags)
    ImGui.PopItemWidth()
    ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)

    local max_min = (v_min >= v_max) and v_current_min or ImMax(v_min, v_current_min)
    local max_max = (v_min >= v_max) and hi or v_max
    local max_flags = bit32.bor(flags, (max_min == max_max) and ImGuiSliderFlags.ReadOnly or 0)
    v_current_max, changed = ImGui.DragScalar("##max", data_type, v_current_max, v_speed, max_min, max_max, format_max or format, max_flags)
    value_changed = value_changed or changed
    ImGui.PopItemWidth()
    ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)

    ImGui.TextEx(label, ImGui.FindRenderedTextEnd(label))
    ImGui.EndGroup()
    ImGui.PopID()

    return v_current_min, v_current_max, value_changed
end

function ImGui.DragFloatRange2(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags)
    return DragRange2(ImGuiDataType.Float, label, v_current_min, v_current_max, v_speed or 1.0, v_min or 0.0, v_max or 0.0, format or "%.3f", format_max, flags or 0)
end

function ImGui.DragIntRange2(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, flags)
    return DragRange2(ImGuiDataType.S32, label, v_current_min, v_current_max, v_speed or 1.0, v_min or 0, v_max or 0, format or "%d", format_max, flags or 0)
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: SliderScalar, SliderFloat, SliderInt, etc.
-------------------------------------------------------------------------------
-- - ScaleRatioFromValueT<> [Internal]
-- - ScaleValueFromRatioT<> [Internal]
-- - SliderBehaviorT<>() [Internal]
-- - SliderBehavior() [Internal]
-- - SliderScalar()
-- - SliderScalarN()
-- - SliderFloat()
-- - SliderFloat2()
-- - SliderFloat3()
-- - SliderFloat4()
-- - SliderAngle()
-- - SliderInt()
-- - SliderInt2()
-- - SliderInt3()
-- - SliderInt4()
-- - VSliderScalar()
-- - VSliderFloat()
-- - VSliderInt()
-------------------------------------------------------------------------------

-- Convert a value v in the output space of a slider into a parametric position on the slider itself (the logical opposite of ScaleValueFromRatioT)
--- @param data_type                ImGuiDataType
--- @param v                        number
--- @param v_min                    number
--- @param v_max                    number
--- @param logarithmic_zero_epsilon float
--- @param zero_deadzone_halfsize   float
function ImGui.ScaleRatioFromValueT(data_type, v, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
    if v_min == v_max then
        return 0.0
    end
    -- IM_UNUSED(data_type)

    local v_clamped
    if v_min < v_max then
        v_clamped = ImClamp(v, v_min, v_max)
    else
        v_clamped = ImClamp(v, v_max, v_min)
    end
    if logarithmic_zero_epsilon > 0.0 then -- == is_logarithmic from caller
        local flipped = v_max < v_min
        if flipped then -- Handle the case where the range is backwards
            v_min, v_max = v_max, v_min
        end

        -- Fudge min/max to avoid getting close to log(0)
        local v_min_fudged
        if ImAbs(v_min) < logarithmic_zero_epsilon then
            v_min_fudged = (v_min < 0.0) and -logarithmic_zero_epsilon or logarithmic_zero_epsilon
        else
            v_min_fudged = v_min
        end
        local v_max_fudged
        if ImAbs(v_max) < logarithmic_zero_epsilon then
            v_max_fudged = (v_max < 0.0) and -logarithmic_zero_epsilon or logarithmic_zero_epsilon
        else
            v_max_fudged = v_max
        end

        -- Awkward special cases - we need ranges of the form (-100 .. 0) to convert to (-100 .. -epsilon), not (-100 .. epsilon)
        if v_min == 0.0 and v_max < 0.0 then
            v_min_fudged = -logarithmic_zero_epsilon
        elseif v_max == 0.0 and v_min < 0.0 then
            v_max_fudged = -logarithmic_zero_epsilon
        end

        local result
        if v_clamped <= v_min_fudged then
            result = 0.0 -- Workaround for values that are in-range but below our fudge
        elseif v_clamped >= v_max_fudged then
            result = 1.0 -- Workaround for values that are in-range but above our fudge
        elseif v_min * v_max < 0.0 then -- Range crosses zero, so split into two portions
            local zero_point_center = (-v_min) / (v_max - v_min) -- The zero point in parametric space.  There's an argument we should take the logarithmic nature into account when calculating this, but for now this should do (and the most common case of a symmetrical range works fine)
            local zero_point_snap_L = zero_point_center - zero_deadzone_halfsize
            local zero_point_snap_R = zero_point_center + zero_deadzone_halfsize
            if v == 0.0 then
                result = zero_point_center -- Special case for exactly zero
            elseif v < 0.0 then
                result = (1.0 - (ImLog(-v_clamped / logarithmic_zero_epsilon) / ImLog(-v_min_fudged / logarithmic_zero_epsilon))) * zero_point_snap_L
            else
                result = zero_point_snap_R + ((ImLog(v_clamped / logarithmic_zero_epsilon) / ImLog(v_max_fudged / logarithmic_zero_epsilon)) * (1.0 - zero_point_snap_R))
            end
        elseif v_min < 0.0 or v_max < 0.0 then -- Entirely negative slider
            result = 1.0 - (ImLog(-v_clamped / -v_max_fudged) / ImLog(-v_min_fudged / -v_max_fudged))
        else
            result = ImLog(v_clamped / v_min_fudged) / ImLog(v_max_fudged / v_min_fudged)
        end

        return flipped and (1.0 - result) or result
    else
        -- Linear slider
        return (v_clamped - v_min) / (v_max - v_min)
    end
end

-- Convert a parametric position on a slider into a value v in the output space (the logical opposite of ScaleRatioFromValueT)
--- @param TYPE                     fun(val: number): number
--- @param SIGNEDTYPE               fun(val: number): number
--- @param data_type                ImGuiDataType
--- @param t                        float
--- @param v_min                    number
--- @param v_max                    number
--- @param logarithmic_zero_epsilon float
--- @param zero_deadzone_halfsize   float
function ImGui.ScaleValueFromRatioT(TYPE, SIGNEDTYPE, data_type, t, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
    -- We special-case the extents because otherwise our logarithmic fudging can lead to "mathematically correct"
    -- but non-intuitive behaviors like a fully-left slider not actually reaching the minimum value. Also generally simpler.
    if t <= 0.0 or v_min == v_max then
        return v_min
    end
    if t >= 1.0 then
        return v_max
    end

    local result = 0
    if logarithmic_zero_epsilon > 0.0 then -- == is_logarithmic from caller
        -- Fudge min/max to avoid getting silly results close to zero
        local v_min_fudged
        if ImAbs(v_min) < logarithmic_zero_epsilon then
            v_min_fudged = (v_min < 0.0) and -logarithmic_zero_epsilon or logarithmic_zero_epsilon
        else
            v_min_fudged = v_min
        end
        local v_max_fudged
        if ImAbs(v_max) < logarithmic_zero_epsilon then
            v_max_fudged = (v_max < 0.0) and -logarithmic_zero_epsilon or logarithmic_zero_epsilon
        else
            v_max_fudged = v_max
        end

        local flipped = v_max < v_min -- Check if range is "backwards"
        if flipped then
            v_min_fudged, v_max_fudged = v_max_fudged, v_min_fudged
        end

        -- Awkward special case - we need ranges of the form (-100 .. 0) to convert to (-100 .. -epsilon), not (-100 .. epsilon)
        if v_max == 0.0 and v_min < 0.0 then
            v_max_fudged = -logarithmic_zero_epsilon
        end

        local t_with_flip = flipped and (1.0 - t) or t -- t, but flipped if necessary to account for us flipping the range

        if v_min * v_max < 0.0 then -- Range crosses zero, so we have to do this in two parts
            local zero_point_center = (-ImMin(v_min, v_max)) / ImAbs(v_max - v_min) -- The zero point in parametric space
            local zero_point_snap_L = zero_point_center - zero_deadzone_halfsize
            local zero_point_snap_R = zero_point_center + zero_deadzone_halfsize

            if t_with_flip >= zero_point_snap_L and t_with_flip <= zero_point_snap_R then
                result = (TYPE)(0.0) -- Special case to make getting exactly zero possible (the epsilon prevents it otherwise)
            elseif t_with_flip < zero_point_center then
                result = (TYPE)(-(logarithmic_zero_epsilon * ImPow(-v_min_fudged / logarithmic_zero_epsilon, 1.0 - (t_with_flip / zero_point_snap_L))))
            else
                result = (TYPE)(logarithmic_zero_epsilon * ImPow(v_max_fudged / logarithmic_zero_epsilon, (t_with_flip - zero_point_snap_R) / (1.0 - zero_point_snap_R)))
            end
        elseif v_min < 0.0 or v_max < 0.0 then  -- Entirely negative slider
            result = (TYPE)(-(-v_max_fudged * ImPow(-v_min_fudged / -v_max_fudged, 1.0 - t_with_flip)))
        else
            result = (TYPE)(v_min_fudged * ImPow(v_max_fudged / v_min_fudged, t_with_flip))
        end
    else
        -- Linear slider
        local is_floating_point = (data_type == ImGuiDataType.Float) or (data_type == ImGuiDataType.Double)
        if is_floating_point then
            result = ImLerp(v_min, v_max, t)
        elseif t < 1.0 then -- t is already < 1.0 here
            -- - For integer values we want the clicking position to match the grab box so we round above
            --   This code is carefully tuned to work with large values (e.g. high ranges of U64) while preserving this property..
            -- - Not doing a *1.0 multiply at the end of a range as it tends to be lossy. While absolute aiming at a large s64/u64
            --   range is going to be imprecise anyway, with this check we at least make the edge values matches expected limits.
            local v_new_off_f = (SIGNEDTYPE)((v_max - v_min)) * t
            result = (TYPE)((SIGNEDTYPE)(v_min) + (SIGNEDTYPE)(v_new_off_f + 0)) -- [Port] + 0 instead of + ((v_min > v_max) and -0.5 or 0.5)
        end
    end

    return result
end

-- FIXME: Try to move more of the code into shared SliderBehavior()
--- @generic T : number
--- @param TYPE        fun(val: number): T
--- @param SIGNEDTYPE  fun(val: number): T
--- @param bb          ImRect
--- @param id          ImGuiID
--- @param data_type   ImGuiDataType
--- @param v           T
--- @param v_min       T
--- @param v_max       T
--- @param format      string
--- @param flags       ImGuiSliderFlags
--- @param out_grab_bb ImRect
--- @return T    v             # updated `v` passed in
--- @return bool value_changed
@native
function ImGui.SliderBehaviorT(TYPE, SIGNEDTYPE, bb, id, data_type, v, v_min, v_max, format, flags, out_grab_bb)
    local g = GImGui
    local style = g.Style

    local axis = (bit32.band(flags, ImGuiSliderFlags.Vertical) ~= 0) and ImGuiAxis.Y or ImGuiAxis.X
    local axis_k = (axis == ImGuiAxis.X) and "x" or "y" -- [Luau] named key: ImVec2[axis] goes through IM_VEC2.__index
    local is_logarithmic = bit32.band(flags, ImGuiSliderFlags.Logarithmic) ~= 0
    local is_floating_point = (data_type == ImGuiDataType.Float) or (data_type == ImGuiDataType.Double)
    local v_range_f = (v_min < v_max) and (v_max - v_min) or (v_min - v_max) -- We don't need high precision for what we do with it.

    -- Calculate bounds
    local grab_padding = 2.0 -- FIXME: Should be part of style.
    local slider_sz = (bb.Max[axis_k] - bb.Min[axis_k]) - grab_padding * 2.0
    local grab_sz = style.GrabMinSize
    if not is_floating_point and v_range_f >= 0.0 then -- v_range_f < 0 may happen on integer overflows
        grab_sz = ImMax(slider_sz / (v_range_f + 1), style.GrabMinSize) -- For integer sliders: if possible have the grab size represent 1 unit
    end
    grab_sz = ImMin(grab_sz, slider_sz)
    local slider_usable_sz = slider_sz - grab_sz
    local slider_usable_pos_min = bb.Min[axis_k] + grab_padding + grab_sz * 0.5
    local slider_usable_pos_max = bb.Max[axis_k] - grab_padding - grab_sz * 0.5

    local logarithmic_zero_epsilon = 0.0 -- Only valid when is_logarithmic is true
    local zero_deadzone_halfsize = 0.0 -- Only valid when is_logarithmic is true
    if is_logarithmic then
        -- When using logarithmic sliders, we need to clamp to avoid hitting zero, but our choice of clamp value greatly affects slider precision. We attempt to use the specified precision to estimate a good lower bound.
        local decimal_precision = is_floating_point and ImParseFormatPrecision(format, 3) or 1
        logarithmic_zero_epsilon = ImPow(0.1, decimal_precision)
        zero_deadzone_halfsize = (style.LogSliderDeadzone * 0.5) / ImMax(slider_usable_sz, 1.0)
    end

    -- Process interacting with the slider
    local value_changed = false
    if g.ActiveId == id then
        local set_new_value = false
        local clicked_t = 0.0
        if g.ActiveIdSource == ImGuiInputSource.Mouse then
            do
                local mouse_abs_pos = g.IO.MousePos[axis_k]
                if g.ActiveIdIsJustActivated then
                    local grab_t = ImGui.ScaleRatioFromValueT(data_type, v, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
                    if axis == ImGuiAxis.Y then
                        grab_t = 1.0 - grab_t
                    end
                    local grab_pos = ImLerp(slider_usable_pos_min, slider_usable_pos_max, grab_t)
                    local clicked_around_grab = (mouse_abs_pos >= grab_pos - grab_sz * 0.5 - 1.0) and (mouse_abs_pos <= grab_pos + grab_sz * 0.5 + 1.0) -- No harm being extra generous here.
                    g.SliderGrabClickOffset = (clicked_around_grab and is_floating_point) and (mouse_abs_pos - grab_pos) or 0.0
                end
                if slider_usable_sz > 0.0 then
                    clicked_t = ImSaturate((mouse_abs_pos - g.SliderGrabClickOffset - slider_usable_pos_min) / slider_usable_sz)
                end
                if axis == ImGuiAxis.Y then
                    clicked_t = 1.0 - clicked_t
                end
                set_new_value = true
            end
        elseif g.ActiveIdSource == ImGuiInputSource.Keyboard or g.ActiveIdSource == ImGuiInputSource.Gamepad then
            local input_delta = (axis == ImGuiAxis.X) and ImGui.GetNavTweakPressedAmount(axis) or -ImGui.GetNavTweakPressedAmount(axis)
            if input_delta ~= 0.0 then
                local tweak_slow = ImGui.IsKeyDown((g.NavInputSource == ImGuiInputSource.Gamepad) and ImGuiKey.NavGamepadTweakSlow or ImGuiKey.NavKeyboardTweakSlow)
                local tweak_fast = ImGui.IsKeyDown((g.NavInputSource == ImGuiInputSource.Gamepad) and ImGuiKey.NavGamepadTweakFast or ImGuiKey.NavKeyboardTweakFast)
                local decimal_precision = is_floating_point and ImParseFormatPrecision(format, 3) or 0
                if decimal_precision > 0 then
                    input_delta = input_delta / 100.0 -- Keyboard/Gamepad tweak speeds in % of slider bounds
                    if tweak_slow then
                        input_delta = input_delta / 10.0
                    end
                else
                    if (v_range_f >= -100.0 and v_range_f <= 100.0 and v_range_f ~= 0.0) or tweak_slow then
                        input_delta = ((input_delta < 0.0) and -1.0 or 1.0) / v_range_f -- Keyboard/Gamepad tweak speeds in integer steps
                    else
                        input_delta = input_delta / 100.0
                    end
                end
                if tweak_fast then
                    input_delta = input_delta * 10.0
                end

                g.SliderCurrentAccum = g.SliderCurrentAccum + input_delta
                g.SliderCurrentAccumDirty = true
            end

            local delta = g.SliderCurrentAccum
            if g.SliderCurrentAccumDirty then
                clicked_t = ImGui.ScaleRatioFromValueT(data_type, v, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)

                if (clicked_t >= 1.0 and delta > 0.0) or (clicked_t <= 0.0 and delta < 0.0) then -- This is to avoid applying the saturation when already past the limits
                    set_new_value = false
                    g.SliderCurrentAccum = 0.0 -- If pushing up against the limits, don't continue to accumulate
                else
                    set_new_value = true
                    local old_clicked_t = clicked_t
                    clicked_t = ImSaturate(clicked_t + delta)

                    -- Calculate what our "new" clicked_t will be, and thus how far we actually moved the slider, and subtract this from the accumulator
                    local v_new = ImGui.ScaleValueFromRatioT(TYPE, SIGNEDTYPE, data_type, clicked_t, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
                    if is_floating_point and bit32.band(flags, ImGuiSliderFlags.NoRoundToFormat) == 0 then
                        v_new = ImGui.RoundScalarWithFormatT(format, data_type, v_new)
                    end
                    local new_clicked_t = ImGui.ScaleRatioFromValueT(data_type, v_new, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)

                    if delta > 0 then
                        g.SliderCurrentAccum = g.SliderCurrentAccum - ImMin(new_clicked_t - old_clicked_t, delta)
                    else
                        g.SliderCurrentAccum = g.SliderCurrentAccum - ImMax(new_clicked_t - old_clicked_t, delta)
                    end
                end

                g.SliderCurrentAccumDirty = false
            end
        end

        if set_new_value then
            if (bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.ReadOnly) ~= 0) or (bit32.band(flags, ImGuiSliderFlags.ReadOnly) ~= 0) then
                set_new_value = false
            end
        end

        if set_new_value then
            local v_new = ImGui.ScaleValueFromRatioT(TYPE, SIGNEDTYPE, data_type, clicked_t, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)

            -- Round to user desired precision based on format string
            if is_floating_point and bit32.band(flags, ImGuiSliderFlags.NoRoundToFormat) == 0 then
                v_new = ImGui.RoundScalarWithFormatT(format, data_type, v_new)
            end

            -- Apply result
            if v ~= v_new then
                v = v_new
                value_changed = true
            end
        end
    end

    -- [Luau] write out_grab_bb fields directly, no temporary ImRect
    local og_min, og_max = out_grab_bb.Min, out_grab_bb.Max
    if slider_sz < 1.0 then
        og_min.x = bb.Min.x; og_min.y = bb.Min.y; og_max.x = bb.Min.x; og_max.y = bb.Min.y
    else
        -- Output grab position so it can be displayed by the caller
        local grab_t = ImGui.ScaleRatioFromValueT(data_type, v, v_min, v_max, logarithmic_zero_epsilon, zero_deadzone_halfsize)
        if axis == ImGuiAxis.Y then
            grab_t = 1.0 - grab_t
        end
        local grab_pos = ImLerp(slider_usable_pos_min, slider_usable_pos_max, grab_t)
        if axis == ImGuiAxis.X then
            og_min.x = grab_pos - grab_sz * 0.5; og_min.y = bb.Min.y + grab_padding; og_max.x = grab_pos + grab_sz * 0.5; og_max.y = bb.Max.y - grab_padding
        else
            og_min.x = bb.Min.x + grab_padding; og_min.y = grab_pos - grab_sz * 0.5; og_max.x = bb.Max.x - grab_padding; og_max.y = grab_pos + grab_sz * 0.5
        end
    end

    return v, value_changed
end

-- For 32-bit and larger types, slider bounds are limited to half the natural type range.
-- So e.g. an integer Slider between INT_MAX-10 and INT_MAX will fail, but an integer Slider between INT_MAX/2-10 and INT_MAX/2 will be ok.
-- It would be possible to lift that limitation with some work but it doesn't seem to be worth it for sliders.
--- @generic T : number
--- @param bb          ImRect
--- @param id          ImGuiID
--- @param data_type   ImGuiDataType
--- @param v           T
--- @param min         T
--- @param max         T
--- @param format      string
--- @param flags       ImGuiSliderFlags
--- @param out_grab_bb ImRect
--- @return T    v
--- @return bool value_changed
@native
function ImGui.SliderBehavior(bb, id, data_type, v, min, max, format, flags, out_grab_bb)
    -- Read imgui.cpp "API BREAKING CHANGES" section for 1.78 if you hit this assert.
    IM_ASSERT((flags == 1 or bit32.band(flags, ImGuiSliderFlags.InvalidMask_) == 0), "Invalid ImGuiSliderFlags flags! Has the legacy 'float power' argument been mistakenly cast to flags? Call function with ImGuiSliderFlags_Logarithmic flags instead.")
    IM_ASSERT(bit32.band(flags, ImGuiSliderFlags.WrapAround) == 0) -- Not supported by SliderXXX(), only by DragXXX()

    -- Things we can do easily outside the SliderBehaviorT<> template, saves code generation.
    local g = GImGui
    if g.ActiveId == id then
        if g.ActiveIdSource == ImGuiInputSource.Mouse and not g.IO.MouseDown[0] then
            ImGui.ClearActiveID()
        end
        if g.ActiveIdSource == ImGuiInputSource.Keyboard or g.ActiveIdSource == ImGuiInputSource.Gamepad then
            if g.ActiveIdIsJustActivated then
                g.SliderCurrentAccum = 0.0 -- Reset any stored nav delta upon activation
                g.SliderCurrentAccumDirty = false
            end
            if g.NavActivatePressedId == id and not g.ActiveIdIsJustActivated then
                ImGui.ClearActiveID()
            end
        end
        if ShortcutsForCancel(id) and g.ActiveId == id then
            -- Canceling action reverts to initial value
            local value_changed = (v ~= g.ActiveIdValueOnActivation)
            v = g.ActiveIdValueOnActivation
            ImGui.ClearActiveID()
            return v, value_changed
        end
    end

    if     data_type == ImGuiDataType.S8 then
        local v32 = (ImS32)((ImS8)(v)); local r
        v32, r = ImGui.SliderBehaviorT(ImS32, ImS32, bb, id, ImGuiDataType.S32, v32, min, max, format, flags, out_grab_bb)
        if r then v = (ImS8)(v32) end
        return v, r
    elseif data_type == ImGuiDataType.U8 then
        local v32 = (ImU32)((ImU8)(v)); local r
        v32, r = ImGui.SliderBehaviorT(ImU32, ImS32, bb, id, ImGuiDataType.U32, v32, min, max, format, flags, out_grab_bb)
        if r then v = (ImU8)(v32) end
        return v, r
    elseif data_type == ImGuiDataType.S16 then
        local v32 = (ImS32)((ImS16)(v)); local r
        v32, r = ImGui.SliderBehaviorT(ImS32, ImS32, bb, id, ImGuiDataType.S32, v32, min, max, format, flags, out_grab_bb)
        if r then v = (ImS16)(v32) end
        return v, r
    elseif data_type == ImGuiDataType.U16 then
        local v32 = (ImU32)((ImU16)(v)); local r
        v32, r = ImGui.SliderBehaviorT(ImU32, ImS32, bb, id, ImGuiDataType.U32, v32, min, max, format, flags, out_grab_bb)
        if r then v = (ImU16)(v32) end
        return v, r
    elseif data_type == ImGuiDataType.S32 then
        IM_ASSERT(min >= math.floor(IM_S32_MIN / 2) and max <= math.floor(IM_S32_MAX / 2))
        return ImGui.SliderBehaviorT(ImS32, ImS32, bb, id, data_type, v, min, max, format, flags, out_grab_bb)
    elseif data_type == ImGuiDataType.U32 then
        IM_ASSERT(max <= math.floor(IM_U32_MAX / 2))
        return ImGui.SliderBehaviorT(ImU32, ImS32, bb, id, data_type, v, min, max, format, flags, out_grab_bb)
    elseif data_type == ImGuiDataType.S64 then
        IM_ASSERT(min >= IM_S64_MIN / 2 and max <= IM_S64_MAX / 2)
        return ImGui.SliderBehaviorT(ImS64, ImS64, bb, id, data_type, v, min, max, format, flags, out_grab_bb)
    elseif data_type == ImGuiDataType.U64 then
        IM_ASSERT(max <= IM_U64_MAX / 2)
        return ImGui.SliderBehaviorT(ImU64, ImS64, bb, id, data_type, v, min, max, format, flags, out_grab_bb)
    elseif data_type == ImGuiDataType.Float then
        IM_ASSERT(min >= -FLT_MAX / 2.0 and max <= FLT_MAX / 2.0)
        return ImGui.SliderBehaviorT(float, float, bb, id, data_type, v, min, max, format, flags, out_grab_bb)
    elseif data_type == ImGuiDataType.Double then
        IM_ASSERT(min >= -DBL_MAX / 2.0 and max <= DBL_MAX / 2.0)
        return ImGui.SliderBehaviorT(double, double, bb, id, data_type, v, min, max, format, flags, out_grab_bb)
    end

    IM_ASSERT(false)
    return v, false
end

-- [Port] Note: data is passed by value and the new value is returned: Returns (data, value_changed). For a slider, min and max are required.
-- Read code of e.g. SliderFloat(), SliderInt() etc. or examples in 'Demo->Widgets->Data Types' to understand how to use this function directly.
--- @generic T : number
--- @param label     string
--- @param data_type ImGuiDataType
--- @param data      T
--- @param min       T
--- @param max       T
--- @param format?   string
--- @param flags?    ImGuiSliderFlags
@native
function ImGui.SliderScalar(label, data_type, data, min, max, format, flags)
    if flags == nil then flags = 0 end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return data, false
    end

    local g = GImGui
    local style = g.Style
    local id = window:GetID(label)
    local w = ImGui.CalcItemWidth()
    local color_marker = (bit32.band(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasColorMarker) ~= 0) and g.NextItemData.ColorMarker or 0

    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size_x, label_size_y = ImGui.CalcTextSizeXY(label, 1, label_end, false) -- [Luau] scalar label_size
    local cursor = window.DC.CursorPos
    local frame_bb = SliderScalar_frame_bb -- [Luau] scratch: callees only read it
    frame_bb.Min.x, frame_bb.Min.y, frame_bb.Max.x, frame_bb.Max.y = cursor.x, cursor.y, cursor.x + w, cursor.y + (label_size_y + style.FramePadding.y * 2.0)
    local total_bb_x = frame_bb.Max.x + ((label_size_x > 0.0) and (style.ItemInnerSpacing.x + label_size_x) or 0.0)
    local total_bb = SliderScalar_total_bb -- [Luau] scratch: ItemSize()/ItemAdd() only read it
    total_bb.Min.x = frame_bb.Min.x; total_bb.Min.y = frame_bb.Min.y; total_bb.Max.x = total_bb_x; total_bb.Max.y = frame_bb.Max.y

    local temp_input_allowed = bit32.band(flags, ImGuiSliderFlags.NoInput) == 0
    ImGui.ItemSize(total_bb, style.FramePadding.y)
    local item_flags = temp_input_allowed and ImGuiItemFlags.Inputable or 0
    if not ImGui.ItemAdd(total_bb, id, frame_bb, item_flags) then
        return data, false
    end

    -- Default format string when passing NULL
    if format == nil then
        format = ImGui.DataTypeGetInfo(data_type).PrintFmt
    end

    local hovered = ImGui.ItemHoverable(frame_bb, id, g.LastItemData.ItemFlags)
    local temp_input_is_active = temp_input_allowed and ImGui.TempInputIsActive(id)
    if not temp_input_is_active then
        -- Tabbing or Ctrl+Click on Slider turns it into an input box
        local clicked = hovered and ImGui.IsMouseClickedEx(0, ImGuiInputFlags.None, id)
        local make_active = clicked or g.NavActivateId == id
        if make_active and clicked then
            ImGui.SetKeyOwner(ImGuiKey.MouseLeft, id)
        end
        if make_active and temp_input_allowed then
            if (clicked and g.IO.KeyCtrl) or (g.NavActivateId == id and bit32.band(g.NavActivateFlags, ImGuiActivateFlags.PreferInput) ~= 0) then
                temp_input_is_active = true
            end
        end

        -- Store initial value (not used by main lib but available as a convenience but some mods e.g. to revert)
        if make_active then
            g.ActiveIdValueOnActivation = data
        end

        if make_active and not temp_input_is_active then
            ImGui.SetActiveID(id, window)
            ImGui.SetFocusID(id, window)
            ImGui.FocusWindow(window)
            g.ActiveIdUsingNavDirMask = bit32.bor(g.ActiveIdUsingNavDirMask, bit32.lshift(1, ImGuiDir.Left), bit32.lshift(1, ImGuiDir.Right))
        end
    end

    if temp_input_is_active then
        -- Only clamp Ctrl+Click input when ImGuiSliderFlags.ClampOnInput is set (generally via ImGuiSliderFlags.AlwaysClamp)
        local clamp_enabled = bit32.band(flags, ImGuiSliderFlags.ClampOnInput) ~= 0 -- Don't use TempInputIsClampEnabled()
        return ImGui.TempInputScalar(frame_bb, id, label, data_type, data, format, clamp_enabled and min or nil, clamp_enabled and max or nil)
    end

    -- Draw frame
    local frame_col = ImGui.GetColorU32((g.ActiveId == id) and ImGuiCol.FrameBgActive or (hovered and ImGuiCol.FrameBgHovered or ImGuiCol.FrameBg))
    ImGui.RenderNavCursor(frame_bb, id)
    ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, frame_col, false, style.FrameRounding)
    if color_marker ~= 0 and style.ColorMarkerSize > 0.0 then
        ImGui.RenderColorComponentMarker(frame_bb, ImGui.GetColorU32(color_marker, nil, true), style.FrameRounding)
    end
    ImGui.RenderFrameBorder(frame_bb.Min, frame_bb.Max, g.Style.FrameRounding)

    -- Slider behavior
    local grab_bb = SliderScalar_grab_bb -- [Luau] scratch: fully written by SliderBehavior(), only read below
    local value_changed
    data, value_changed = ImGui.SliderBehavior(frame_bb, id, data_type, data, min, max, format, flags, grab_bb)
    if value_changed then
        ImGui.MarkItemEdited(id)
    end

    -- Render grab
    if grab_bb.Max.x > grab_bb.Min.x then
        window.DrawList:AddRectFilled(grab_bb.Min, grab_bb.Max, ImGui.GetColorU32((g.ActiveId == id) and ImGuiCol.SliderGrabActive or ImGuiCol.SliderGrab), style.GrabRounding)
    end

    -- Display value using user-provided display format so user can add prefix/suffix/decorations to the value.
    local is_mixed = bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue) ~= 0
    local value_buf = DataTypeFormatStringCached(data_type, data, (is_mixed and g.MixedValueLabel ~= nil) and g.MixedValueLabel or format)
    if g.LogEnabled then
        ImGui.LogSetNextTextDecoration("{", "}")
    end
    if is_mixed then
        ImGui.PushStyleColor(ImGuiCol.Text, g.Style.Colors[ImGuiCol.TextDisabled]) -- ImGuiCol_TextMixedValue
    end
    ImGui.RenderTextClipped(frame_bb.Min, frame_bb.Max, value_buf, nil, nil, DRAG_TEXT_ALIGN)
    if is_mixed then
        ImGui.PopStyleColor()
    end

    if label_size_x > 0.0 then
        local label_pos = SliderScalar_label_pos
        label_pos.x, label_pos.y = frame_bb.Max.x + style.ItemInnerSpacing.x, frame_bb.Min.y + style.FramePadding.y
        ImGui.RenderText(label_pos, label, 1, label_end, false)
    end

    -- IMGUI_TEST_ENGINE_ITEM_INFO()
    return data, value_changed
end

-- Add multiple sliders on 1 line for compact edition of multiple components
--- @param label      string
--- @param data_type  ImGuiDataType
--- @param v          table
--- @param components int
--- @param v_min      number
--- @param v_max      number
--- @param format?    string
--- @param flags?     ImGuiSliderFlags
function ImGui.SliderScalarN(label, data_type, v, components, v_min, v_max, format, flags)
    if flags == nil then flags = 0 end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local value_changed = false
    ImGui.BeginGroup()
    ImGui.PushID(label)
    ImGui.PushMultiItemsWidths(components, ImGui.CalcItemWidth())

    for i = 1, components do
        ImGui.PushID(i - 1)
        if i > 1 then
            ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)
        end
        if bit32.band(flags, ImGuiSliderFlags.ColorMarkers) ~= 0 then
            ImGui.SetNextItemColorMarker(GDefaultRgbaColorMarkers[i])
        end
        local changed
        v[i], changed = ImGui.SliderScalar("", data_type, v[i], v_min, v_max, format, flags)
        value_changed = value_changed or changed
        ImGui.PopID()
        ImGui.PopItemWidth()
    end
    ImGui.PopID()

    local label_end = ImGui.FindRenderedTextEnd(label)
    if label_end > 1 then
        ImGui.SameLine(0, g.Style.ItemInnerSpacing.x)
        ImGui.TextEx(label, label_end)
    end

    ImGui.EndGroup()
    return value_changed
end

--- @param label   string
--- @param v       [float, float]
--- @param v_min   float
--- @param v_max   float
--- @param format? string
--- @param flags?  ImGuiSliderFlags
function ImGui.SliderFloat2(label, v, v_min, v_max, format, flags)
    return ImGui.SliderScalarN(label, ImGuiDataType.Float, v, 2, v_min, v_max, format, flags)
end

--- @param label   string
--- @param v       [float, float, float]
--- @param v_min   float
--- @param v_max   float
--- @param format? string
--- @param flags?  ImGuiSliderFlags
function ImGui.SliderFloat3(label, v, v_min, v_max, format, flags)
    return ImGui.SliderScalarN(label, ImGuiDataType.Float, v, 3, v_min, v_max, format, flags)
end

--- @param label   string
--- @param v       [float, float, float, float]
--- @param v_min   float
--- @param v_max   float
--- @param format? string
--- @param flags?  ImGuiSliderFlags
function ImGui.SliderFloat4(label, v, v_min, v_max, format, flags)
    return ImGui.SliderScalarN(label, ImGuiDataType.Float, v, 4, v_min, v_max, format, flags)
end

--- @param label   string
--- @param v       float
--- @param v_min   float
--- @param v_max   float
--- @param format? string
--- @param flags?  ImGuiSliderFlags
@native
function ImGui.SliderFloat(label, v, v_min, v_max, format, flags)
    if format == nil then format = "%.3f" end
    if flags  == nil then flags  = 0      end

    return ImGui.SliderScalar(label, ImGuiDataType.Float, v, v_min, v_max, format, flags)
end

--- @param label          string
--- @param v_rad          float
--- @param v_degrees_min? float
--- @param v_degrees_max? float
--- @param format?        string
--- @param flags?         ImGuiSliderFlags
--- @return float v_rad         # updated `v_rad`
--- @return bool  value_changed
function ImGui.SliderAngle(label, v_rad, v_degrees_min, v_degrees_max, format, flags)
    if v_degrees_min == nil then v_degrees_min = -360.0     end
    if v_degrees_max == nil then v_degrees_max =  360.0     end
    if format        == nil then format        = "%.0f deg" end
    if flags         == nil then flags         = 0          end

    local v_deg = v_rad * 360.0 / (2 * IM_PI)
    local value_changed
    v_deg, value_changed = ImGui.SliderFloat(label, v_deg, v_degrees_min, v_degrees_max, format, flags)
    if value_changed then
        v_rad = v_deg * (2 * IM_PI) / 360.0
    end
    return v_rad, value_changed
end

--- @param label   string
--- @param v       int
--- @param v_min   int
--- @param v_max   int
--- @param format? string
--- @param flags?  ImGuiSliderFlags
function ImGui.SliderInt(label, v, v_min, v_max, format, flags)
    if format == nil then format = "%d" end
    if flags  == nil then flags  = 0    end

    return ImGui.SliderScalar(label, ImGuiDataType.S32, v, v_min, v_max, format, flags)
end

function ImGui.SliderInt2(label, v, v_min, v_max, format, flags)
    return ImGui.SliderScalarN(label, ImGuiDataType.S32, v, 2, v_min, v_max, format or "%d", flags)
end

function ImGui.SliderInt3(label, v, v_min, v_max, format, flags)
    return ImGui.SliderScalarN(label, ImGuiDataType.S32, v, 3, v_min, v_max, format or "%d", flags)
end

function ImGui.SliderInt4(label, v, v_min, v_max, format, flags)
    return ImGui.SliderScalarN(label, ImGuiDataType.S32, v, 4, v_min, v_max, format or "%d", flags)
end

--- @param label     string
--- @param size      ImVec2
--- @param data_type ImGuiDataType
--- @param data      number
--- @param min       number
--- @param max       number
--- @param format?   string
--- @param flags?    ImGuiSliderFlags
function ImGui.VSliderScalar(label, size, data_type, data, min, max, format, flags)
    if flags == nil then flags = 0 end
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return data, false
    end

    local g = GImGui
    local style = g.Style
    local id = window:GetID(label)

    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size = ImGui.CalcTextSize(label, label_end, false)
    local frame_bb = ImRect(window.DC.CursorPos, window.DC.CursorPos + size)
    local bb = ImRect(frame_bb.Min, ImVec2(frame_bb.Max.x + (label_size.x > 0.0 and (style.ItemInnerSpacing.x + label_size.x) or 0.0), frame_bb.Max.y))

    ImGui.ItemSize(bb, style.FramePadding.y)
    if not ImGui.ItemAdd(frame_bb, id) then
        return data, false
    end

    -- Default format string when passing NULL
    if format == nil then
        format = ImGui.DataTypeGetInfo(data_type).PrintFmt
    end

    local hovered = ImGui.ItemHoverable(frame_bb, id, g.LastItemData.ItemFlags)
    local clicked = hovered and ImGui.IsMouseClickedEx(0, ImGuiInputFlags.None, id)
    if clicked or g.NavActivateId == id then
        if clicked then
            ImGui.SetKeyOwner(ImGuiKey.MouseLeft, id)
        end
        ImGui.SetActiveID(id, window)
        ImGui.SetFocusID(id, window)
        ImGui.FocusWindow(window)
        g.ActiveIdUsingNavDirMask = bit32.bor(g.ActiveIdUsingNavDirMask, bit32.lshift(1, ImGuiDir.Up), bit32.lshift(1, ImGuiDir.Down))
    end

    -- Draw frame
    local frame_col = ImGui.GetColorU32((g.ActiveId == id) and ImGuiCol.FrameBgActive or (hovered and ImGuiCol.FrameBgHovered or ImGuiCol.FrameBg))
    ImGui.RenderNavCursor(frame_bb, id)
    ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, frame_col, true, g.Style.FrameRounding)

    -- Slider behavior
    local grab_bb = ImRect()
    local value_changed
    data, value_changed = ImGui.SliderBehavior(frame_bb, id, data_type, data, min, max, format, bit32.bor(flags or 0, ImGuiSliderFlags.Vertical), grab_bb)
    if value_changed then
        ImGui.MarkItemEdited(id)
    end

    -- Render grab
    if grab_bb.Max.y > grab_bb.Min.y then
        window.DrawList:AddRectFilled(grab_bb.Min, grab_bb.Max, ImGui.GetColorU32((g.ActiveId == id) and ImGuiCol.SliderGrabActive or ImGuiCol.SliderGrab), style.GrabRounding)
    end

    -- Display value using user-provided display format so user can add prefix/suffix/decorations to the value.
    -- For the vertical slider we allow centered text to overlap the frame padding
    local is_mixed = bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue) ~= 0
    local value_buf = DataTypeFormatStringCached(data_type, data, (is_mixed and g.MixedValueLabel ~= nil) and g.MixedValueLabel or format)
    if is_mixed then
        ImGui.PushStyleColor(ImGuiCol.Text, g.Style.Colors[ImGuiCol.TextDisabled]) -- ImGuiCol_TextMixedValue
    end
    ImGui.RenderTextClipped(ImVec2(frame_bb.Min.x, frame_bb.Min.y + style.FramePadding.y), frame_bb.Max, value_buf, nil, nil, ImVec2(0.5, 0.0))
    if is_mixed then
        ImGui.PopStyleColor()
    end
    if label_size.x > 0.0 then
        ImGui.RenderText(ImVec2(frame_bb.Max.x + style.ItemInnerSpacing.x, frame_bb.Min.y + style.FramePadding.y), label, 1, label_end, false)
    end

    -- IMGUI_TEST_ENGINE_ITEM_INFO()
    return data, value_changed
end

--- @param label   string
--- @param size    ImVec2
--- @param v       float
--- @param v_min   float
--- @param v_max   float
--- @param format? string
--- @param flags?  ImGuiSliderFlags
function ImGui.VSliderFloat(label, size, v, v_min, v_max, format, flags)
    if format == nil then format = "%.3f" end

    return ImGui.VSliderScalar(label, size, ImGuiDataType.Float, v, v_min, v_max, format, flags)
end

--- @param label   string
--- @param size    ImVec2
--- @param v       int
--- @param v_min   int
--- @param v_max   int
--- @param format? string
--- @param flags?  ImGuiSliderFlags
function ImGui.VSliderInt(label, size, v, v_min, v_max, format, flags)
    if format == nil then format = "%d" end

    return ImGui.VSliderScalar(label, size, ImGuiDataType.S32, v, v_min, v_max, format, flags)
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: InputText, InputTextMultiline, InputTextWithHint
-------------------------------------------------------------------------------
-- - imstb_textedit.h include
-- - InputText()
-- - InputTextWithHint()
-- - InputTextMultiline()
-- - InputTextEx() [Internal]
-- - DebugNodeInputTextState() [Internal]
-------------------------------------------------------------------------------

--- @param label     string
--- @param buf       char[]
--- @param buf_size  int
--- @param flags?    ImGuiInputTextFlags
--- @param callback? ImGuiInputTextCallback
--- @param user_data any
function ImGui.InputText(label, buf, buf_size, flags, callback, user_data)
    if flags == nil then flags = 0 end

    IM_ASSERT(bit32.band(flags, ImGuiInputTextFlags.Multiline) == 0) -- call InputTextMultiline()
    return ImGui.InputTextEx(label, nil, buf, buf_size, LAYOUT_ZERO_SIZE, flags, callback, user_data) -- [Luau] shared read-only ImVec2(0, 0)
end

-- [Luau] InputText edits a byte table in place (C++ char buf[N]). Helpers to make/read one:
--   local buf = ImGui.NewTextBuffer("Hello", 256); ImGui.InputText("label", buf, 256); print(ImGui.TextBufferToString(buf))
function ImGui.NewTextBuffer(str, size)
    local t = {}
    for i = 1, #str do t[i] = string.byte(str, i) end
    for i = #str + 1, math.max(size or 0, #str + 1) do t[i] = 0 end
    return t
end
function ImGui.TextBufferToString(buf)
    local n = 0
    while buf[n + 1] ~= nil and buf[n + 1] ~= 0 do n = n + 1 end
    return n == 0 and "" or ImGui._ByteArrayToString(buf, 1, n + 1)
end

--- @param size? ImVec2
function ImGui.InputTextMultiline(label, buf, buf_size, size, flags, callback, user_data)
    return ImGui.InputTextEx(label, nil, buf, buf_size, size or ImVec2(0, 0), bit32.bor(flags or 0, ImGuiInputTextFlags.Multiline), callback, user_data)
end

ImStb = {}

--- @module "imstb_textedit"
local stbte

local IMSTB_TEXTEDIT_GETWIDTH_NEWLINE = -1.0

ImStb.TEXTEDIT_memmove = ImStd.memmove

--- @param ctx  ImGuiContext
--- @param text             char[]
--- @param text_begin       int
--- @param text_end_display int
--- @param text_end         int
--- @param out_offset?      ImVec2
--- @param flags?           ImDrawTextFlags
local function InputTextCalcTextSize(ctx, text, text_begin, text_end_display, text_end, out_offset, flags)
    if flags == nil then flags = 0 end

    local g = ctx
    local obj = g.InputTextState
    IM_ASSERT(text_end_display >= text_begin and text_end_display <= text_end)
    return ImFontCalcTextSizeEx(g.Font, g.FontSize, FLT_MAX, obj.WrapWidth, text, text_begin, text_end_display, text_end, out_offset, flags)
end

-- Wrapper for stb_textedit.h to edit text (our wrapper is for: statically sized buffer, single-line, wchar characters. InputText converts between UTF-8 and wchar)
-- With our UTF-8 use of stb_textedit:
-- - STB_TEXTEDIT_GETCHAR is nothing more than a a "GETBYTE". It's only used to compare to ascii or to copy blocks of text so we are fine.
-- - One exception is the STB_TEXTEDIT_IS_SPACE feature which would expect a full char in order to handle full-width space such as 0x3000 (see ImCharIsBlankW).
-- - ...but we don't use that feature.
--- @param obj ImGuiInputTextState
--- @return int
function ImStb.TEXTEDIT_STRINGLEN(obj) return obj.TextLen end

--- @param obj ImGuiInputTextState
--- @param idx int                 # 1-based
function ImStb.TEXTEDIT_GETCHAR(obj, idx) IM_ASSERT(idx >= 1 and idx <= obj.TextLen + 1); return obj.TextSrc[idx] end

--- @param obj            ImGuiInputTextState
--- @param line_start_idx int                 # 1-based
--- @param char_idx       int                 # 1-based
--- @return float
function ImStb.TEXTEDIT_GETWIDTH(obj, line_start_idx, char_idx) local _, c = ImStd.ImTextCharFromUtf8(obj.TextSrc, line_start_idx + char_idx - 1, obj.TextLen + 1); if c == 10 then return IMSTB_TEXTEDIT_GETWIDTH_NEWLINE end; local g = obj.Ctx; return g.FontBaked:GetCharAdvance(c) * g.FontBakedScale end

--- @param r              StbTexteditRow
--- @param obj            ImGuiInputTextState
--- @param line_start_idx int                 # 1-based
function ImStb.TEXTEDIT_LAYOUTROW(r, obj, line_start_idx)
    local text = obj.TextSrc
    local size, text_remaining = InputTextCalcTextSize(obj.Ctx, text, line_start_idx, obj.TextLen + 1, obj.TextLen + 1, nil, bit32.bor(ImDrawTextFlags.StopOnNewLine, ImDrawTextFlags.WrapKeepBlanks))
    r.x0 = 0.0
    r.x1 = size.x
    r.baseline_y_delta = size.y
    r.ymin = 0.0
    r.ymax = size.y
    r.num_chars = text_remaining - line_start_idx
end

--- @param obj ImGuiInputTextState
--- @param idx int
function ImStb.TEXTEDIT_GETNEXTCHARINDEX(obj, idx)
    if idx >= obj.TextLen then
        return obj.TextLen + 1
    end
    return idx + ImStd.ImTextCharFromUtf8(obj.TextSrc, idx, obj.TextLen + 1)
end

--- @param obj ImGuiInputTextState
--- @param idx int
function ImStb.TEXTEDIT_GETPREVCHARINDEX(obj, idx)
    if idx <= 1 then
        return -1
    end
    local p = ImStd.ImTextFindPreviousUtf8Codepoint(obj.TextSrc, 1, idx)
    return p
end

local ImCharIsSeparatorW do

local separator_list = {
    44, 0x3001, 46, 0x3002, 59, 0xFF1B, 40, 0xFF08, 41, 0xFF09, 123, 0xFF5B, 125, 0xFF5D,
    91, 0x300C, 93, 0x300D, 124, 0xFF5C, 33, 0xFF01, 92, 0xFFE5, 47, 0x30FB, 0xFF0F,
    10, 13
}

--- @param c unsigned_int
function ImCharIsSeparatorW(c)
    for i = 1, #separator_list do
        if c == separator_list[i] then
            return true
        end
    end
    return false
end

end

--- @param obj ImGuiInputTextState
--- @param idx int
function ImStb.is_word_boundary_from_right(obj, idx)
    -- When ImGuiInputTextFlags.Password is set, we don't want actions such as Ctrl+Arrow to leak the fact that underlying data are blanks or separators.
    if bit32.band(obj.Flags, ImGuiInputTextFlags.Password) ~= 0 or idx <= 1 then
        return false
    end

    local prev = ImStd.ImTextFindPreviousUtf8Codepoint(obj.TextSrc, 1, idx)
    local _, curr_c = ImStd.ImTextCharFromUtf8(obj.TextSrc, idx, obj.TextLen + 1)
    local _, prev_c = ImStd.ImTextCharFromUtf8(obj.TextSrc, prev, obj.TextLen + 1)

    local prev_white = ImCharIsBlankW(prev_c)
    local prev_separ = ImCharIsSeparatorW(prev_c)
    local curr_white = ImCharIsBlankW(curr_c)
    local curr_separ = ImCharIsSeparatorW(curr_c)
    return ((prev_white or prev_separ) and not (curr_separ or curr_white)) or (curr_separ and not prev_separ)
end

--- @param obj ImGuiInputTextState
--- @param idx int
function ImStb.is_word_boundary_from_left(obj, idx)
    if bit32.band(obj.Flags, ImGuiInputTextFlags.Password) ~= 0 or idx <= 1 then
        return false
    end

    local prev = ImStd.ImTextFindPreviousUtf8Codepoint(obj.TextSrc, 1, idx)
    local _, prev_c = ImStd.ImTextCharFromUtf8(obj.TextSrc, idx, obj.TextLen + 1)
    local _, curr_c = ImStd.ImTextCharFromUtf8(obj.TextSrc, prev, obj.TextLen + 1)

    local prev_white = ImCharIsBlankW(prev_c)
    local prev_separ = ImCharIsSeparatorW(prev_c)
    local curr_white = ImCharIsBlankW(curr_c)
    local curr_separ = ImCharIsSeparatorW(curr_c)
    return (prev_white and not (curr_separ or curr_white)) or (curr_separ and not prev_separ)
end

--- @param obj ImGuiInputTextState
--- @param idx int
function ImStb.TEXTEDIT_MOVEWORDLEFT(obj, idx)
    idx = ImStb.TEXTEDIT_GETPREVCHARINDEX(obj, idx)
    while idx >= 1 and not ImStb.is_word_boundary_from_right(obj, idx) do
        idx = ImStb.TEXTEDIT_GETPREVCHARINDEX(obj, idx)
    end
    return (idx < 1) and 1 or idx
end

--- @param obj ImGuiInputTextState
--- @param idx int
function ImStb.TEXTEDIT_MOVEWORDRIGHT_MAC(obj, idx)
    local len = obj.TextLen
    idx = ImStb.TEXTEDIT_GETNEXTCHARINDEX(obj, idx)
    while idx <= len and not ImStb.is_word_boundary_from_left(obj, idx) do
        idx = ImStb.TEXTEDIT_GETNEXTCHARINDEX(obj, idx)
    end
    return (idx > len + 1) and len + 1 or idx
end

--- @param obj ImGuiInputTextState
--- @param idx int
function ImStb.TEXTEDIT_MOVEWORDRIGHT_WIN(obj, idx)
    idx = ImStb.TEXTEDIT_GETNEXTCHARINDEX(obj, idx)
    local len = obj.TextLen
    while idx <= len and not ImStb.is_word_boundary_from_right(obj, idx) do
        idx = ImStb.TEXTEDIT_GETNEXTCHARINDEX(obj, idx)
    end
    return (idx > len + 1) and len + 1 or idx
end

--- @param obj ImGuiInputTextState
--- @param idx int
function ImStb.TEXTEDIT_MOVEWORDRIGHT(obj, idx)
    local g = obj.Ctx
    if g.IO.ConfigMacOSXBehaviors then
        return ImStb.TEXTEDIT_MOVEWORDRIGHT_MAC(obj, idx)
    else
        return ImStb.TEXTEDIT_MOVEWORDRIGHT_WIN(obj, idx)
    end
end

-- Reimplementation of stb_textedit_move_line_start()/stb_textedit_move_line_end() which supports word-wrapping.
--- @param obj    ImGuiInputTextState
--- @param state  STB_TexteditState
--- @param cursor int
function ImStb.TEXTEDIT_MOVELINESTART(obj, state, cursor)
    if state.single_line then
        return 1
    end

    if obj.WrapWidth > 0.0 then
        local g = obj.Ctx
        local bol = ImStd.ImStrbol(obj.TextSrc, cursor, 1)
        local p = bol
        local text_end = obj.TextLen + 1 -- End of line would be enough
        while p >= bol do
            local eol = ImFontCalcWordWrapPositionEx(g.Font, g.FontSize, obj.TextSrc, p, text_end, obj.WrapWidth, ImDrawTextFlags.WrapKeepBlanks)
            if p == cursor then -- If we are already on a visible beginning-of-line, return real beginning-of-line (would be same as regular handler below)
                return bol
            end
            if eol == cursor and obj.TextA[cursor] ~= 10 and obj.LastMoveDirectionLR == ImGuiDir.Left then
                return bol
            end
            if eol >= cursor then
                return p
            end
            p = (obj.TextSrc[eol] == 10) and eol + 1 or eol
        end
    end

    -- Regular handler, same as stb_textedit_move_line_start()
    while cursor > 1 do
        local prev_cursor = ImStb.TEXTEDIT_GETPREVCHARINDEX(obj, cursor)
        if (ImStb.TEXTEDIT_GETCHAR(obj, prev_cursor) == STB_TEXTEDIT_NEWLINE) then
            break
        end
        cursor = prev_cursor
    end
    return cursor
end

--- @param obj    ImGuiInputTextState
--- @param state  STB_TexteditState
--- @param cursor int
function ImStb.TEXTEDIT_MOVELINEEND(obj, state, cursor)
    local n = ImStb.TEXTEDIT_STRINGLEN(obj)
    if state.single_line then
        return n + 1
    end

    if obj.WrapWidth > 0.0 then
        local g = obj.Ctx
        local p = ImStd.ImStrbol(obj.TextSrc, cursor, 1)
        local text_end = obj.TextLen + 1 -- End of line would be enough
        while p < text_end do
            local eol = ImFontCalcWordWrapPositionEx(g.Font, g.FontSize, obj.TextSrc, p, text_end, obj.WrapWidth, ImDrawTextFlags.WrapKeepBlanks)
            cursor = eol
            if eol == cursor and obj.LastMoveDirectionLR ~= ImGuiDir.Left then -- If we are already on a visible end-of-line, switch to regular handle
                break
            end
            if eol > cursor then
                return cursor
            end
            p = (obj.TextSrc[eol] == 10) and eol + 1 or eol
        end
    end

    -- Regular handler, same as stb_textedit_move_line_end()
    while (cursor < n and ImStb.TEXTEDIT_GETCHAR(obj, cursor) ~= STB_TEXTEDIT_NEWLINE) do
        cursor = ImStb.TEXTEDIT_GETNEXTCHARINDEX(obj, cursor)
    end
    return cursor
end

--- @param obj ImGuiInputTextState
--- @param pos int
--- @param n   int
function ImStb.TEXTEDIT_DELETECHARS(obj, pos, n)
    -- Offset remaining text (+ copy zero terminator)
    IM_ASSERT(obj.TextSrc == obj.TextA.Data)
    ImStd.memmove(obj.TextA.Data, pos, obj.TextA.Data, pos + n, obj.TextLen - n - pos + 2)
    obj.EditedBefore = true
    obj.EditedThisFrame = true
    obj.TextLen = obj.TextLen - n
end

--- @param obj          ImGuiInputTextState
--- @param pos          int
--- @param new_text     ImStringBuffer
--- @param new_text_pos int
--- @param new_text_len int
function ImStb.TEXTEDIT_INSERTCHARS(obj, pos, new_text, new_text_pos, new_text_len)
    local is_resizable = bit32.band(obj.Flags, ImGuiInputTextFlags.CallbackResize) ~= 0
    local text_len = obj.TextLen
    IM_ASSERT(pos <= text_len + 1)

    -- We support partial insertion (with a mod in stb_textedit.h)
    local avail = obj.BufCapacity - 1 - obj.TextLen
    if not is_resizable and new_text_len > avail then
        new_text_len = math.floor(ImStd.ImTextFindValidUtf8CodepointEnd(new_text, new_text_pos, new_text_len + 1, avail) - new_text_pos) -- Truncate to closest UTF-8 codepoint. Alternative: return 0 to cancel insertion.
    end
    if new_text_len == 0 then
        return 0
    end

    -- Grow internal buffer if needed
    IM_ASSERT(obj.TextSrc == obj.TextA.Data)
    if text_len + new_text_len + 1 > obj.TextA.Size and is_resizable then
        obj.TextA:resize(text_len + ImClamp(new_text_len, 32, ImMax(256, new_text_len)) + 1)
        obj.TextSrc = obj.TextA.Data
    end

    local text = obj.TextA.Data
    if pos ~= text_len + 1 then
        ImStd.memmove(text, pos + new_text_len, text, pos, text_len - pos + 1)
    end
    ImStd.memmove(text, pos, new_text, new_text_pos, new_text_len)

    obj.EditedBefore = true
    obj.EditedThisFrame = true
    obj.TextLen = obj.TextLen + new_text_len
    obj.TextA[obj.TextLen + 1] = 0

    return new_text_len
end

stbte = IM_INCLUDE"imstb_textedit.lua"

-- stb_textedit internally allows for a single undo record to do addition and deletion, but somehow, calling
-- the stb_textedit_paste() function creates two separate records, so we perform it manually. (FIXME: Report to nothings/stb?)
--- @param str      ImGuiInputTextState
--- @param state    STB_TexteditState
--- @param text     IMSTB_TEXTEDIT_CHARTYPE[]
--- @param text_len int
function ImStb.stb_textedit_replace(str, state, text, text_len)
    stbte.makeundo_replace(str, state, 1, str.TextLen, text_len)
    ImStb.TEXTEDIT_DELETECHARS(str, 1, str.TextLen)
    state.cursor = 1
    state.select_start = 1
    state.select_end = 1
    if text_len <= 0 then
        return
    end

    local text_len_inserted = ImStb.TEXTEDIT_INSERTCHARS(str, 1, text, 1, text_len)
    if text_len_inserted > 0 then
        state.cursor = text_len + 1
        state.select_start = text_len + 1
        state.select_end = text_len + 1
        state.has_preferred_x = false

        return
    end

    IM_ASSERT(false) -- Failed to insert character, normally shouldn't happen because of how we currently use stb_textedit_replace()
end

local MT = ImGui.GetMetatables()

do

--- @param key int
function MT.ImGuiInputTextState:OnKeyPressed(key)
    stbte.key(self, self.Stb, key)
    self.CursorFollow = true
    self:CursorAnimReset()
    local key_u = bit32.band(key, bit32.bnot(STB_TEXTEDIT_K_SHIFT))
    if key_u == STB_TEXTEDIT_K_LEFT or key_u == STB_TEXTEDIT_K_LINESTART or key_u == STB_TEXTEDIT_K_TEXTSTART or key_u == STB_TEXTEDIT_K_BACKSPACE or key_u == STB_TEXTEDIT_K_WORDLEFT then
        self.LastMoveDirectionLR = ImGuiDir.Left
    elseif key_u == STB_TEXTEDIT_K_RIGHT or key_u == STB_TEXTEDIT_K_LINEEND or key_u == STB_TEXTEDIT_K_TEXTEND or key_u == STB_TEXTEDIT_K_DELETE or key_u == STB_TEXTEDIT_K_WORDRIGHT then
        self.LastMoveDirectionLR = ImGuiDir.Right
    end
end

local utf8 = {0, 0, 0, 0, 0}

--- @param c unsigned_int
function MT.ImGuiInputTextState:OnCharPressed(c)
    for i = 1, 5 do utf8[i] = 0 end

    -- Convert the key to a UTF8 byte sequence.
    -- The changes we had to make to stb_textedit_key made it very much UTF-8 specific which is not too great.
    ImStd.ImTextCharToUtf8(utf8, c)
    stbte.text(self, self.Stb, utf8, ImStd.ImStrlen(utf8))
    self.CursorFollow = true
    self:CursorAnimReset()
end

-- Those functions are not inlined in imgui_internal.h, allowing us to hide ImStbTexteditState from that header.
function MT.ImGuiInputTextState:CursorAnimReset() self.CursorAnim = -0.30 end -- After a user-input the cursor stays on for a while without blinking

function MT.ImGuiInputTextState:CursorClamp()
    self.Stb.cursor = ImMin(self.Stb.cursor, self.TextLen + 1)
    self.Stb.select_start = ImMin(self.Stb.select_start, self.TextLen + 1)
    self.Stb.select_end = ImMin(self.Stb.select_end, self.TextLen + 1)
end

function MT.ImGuiInputTextState:HasSelection() return self.Stb.select_start ~= self.Stb.select_end end
function MT.ImGuiInputTextState:ClearSelection() self.Stb.select_start = self.Stb.cursor; self.Stb.select_end = self.Stb.cursor end
-- [Luau] positions are 1-based byte indices (upstream: 0-based)
function MT.ImGuiInputTextState:GetCursorPos() return self.Stb.cursor end
function MT.ImGuiInputTextState:GetSelectionStart() return self.Stb.select_start end
function MT.ImGuiInputTextState:GetSelectionEnd() return self.Stb.select_end end
function MT.ImGuiInputTextState:SetSelection(start, _end) self.Stb.select_start = start; self.Stb.cursor = _end; self.Stb.select_end = _end end
function MT.ImGuiInputTextState:GetPreferredOffsetX() if self.Stb.has_preferred_x then return self.Stb.preferred_x else return -1 end end

function MT.ImGuiInputTextState:SelectAll()
    self.Stb.select_start = 1
    self.Stb.cursor = self.TextLen + 1
    self.Stb.select_end = self.TextLen + 1
    self.Stb.has_preferred_x = false
end

function MT.ImGuiInputTextState:ReloadUserBufAndSelectAll() self.WantReloadUserBuf = true; self.ReloadSelectionStart = 1; self.ReloadSelectionEnd = INT_MAX end
function MT.ImGuiInputTextState:ReloadUserBufAndKeepSelection() self.WantReloadUserBuf = true; self.ReloadSelectionStart = self.Stb.select_start; self.ReloadSelectionEnd = self.Stb.select_end end
function MT.ImGuiInputTextState:ReloadUserBufAndMoveToEnd() self.WantReloadUserBuf = true; self.ReloadSelectionStart = INT_MAX; self.ReloadSelectionEnd = INT_MAX end

end

function ImGui.PushPasswordFont()
    local g = GImGui
    local backup = g.InputTextPasswordFontBackupBaked
    IM_ASSERT(backup.IndexAdvanceX.Size == 0 and backup.IndexLookup.Size == 0)
    local glyph = g.FontBaked:FindGlyph(42) -- '*'
    g.InputTextPasswordFontBackupFlags = g.Font.Flags
    backup.FallbackGlyphIndex = g.FontBaked.FallbackGlyphIndex
    backup.FallbackAdvanceX = g.FontBaked.FallbackAdvanceX
    backup.IndexLookup:swap(g.FontBaked.IndexLookup)
    backup.IndexAdvanceX:swap(g.FontBaked.IndexAdvanceX)
    g.Font.Flags = bit32.bor(g.Font.Flags, ImFontFlags.NoLoadGlyphs)
    g.FontBaked.FallbackGlyphIndex = g.FontBaked.Glyphs:index_from_ptr(glyph) + 1
    g.FontBaked.FallbackAdvanceX = glyph.AdvanceX
end

function ImGui.PopPasswordFont()
    local g = GImGui
    local backup = g.InputTextPasswordFontBackupBaked
    g.Font.Flags = g.InputTextPasswordFontBackupFlags
    g.FontBaked.FallbackGlyphIndex = backup.FallbackGlyphIndex
    g.FontBaked.FallbackAdvanceX = backup.FallbackAdvanceX
    g.FontBaked.IndexLookup:swap(backup.IndexLookup)
    g.FontBaked.IndexAdvanceX:swap(backup.IndexAdvanceX)
    IM_ASSERT(backup.IndexAdvanceX.Size == 0 and backup.IndexLookup.Size == 0)
end

-- Return false to discard a character. Returns (char, ok).
--- @param ctx                        ImGuiContext
--- @param state                      ImGuiInputTextState
--- @param char                       unsigned_int
--- @param callback?                  ImGuiInputTextCallback
--- @param user_data                  any
--- @param input_source_is_clipboard? bool
--- @return unsigned_int out_char
--- @return bool
local function InputTextFilterCharacter(ctx, state, char, callback, user_data, input_source_is_clipboard)
    if input_source_is_clipboard == nil then input_source_is_clipboard = false end

    IM_ASSERT(state ~= nil)

    local c = char
    local flags = state.Flags

    -- Filter non-printable (NB: isprint is unreliable! see #2467)
    local apply_named_filters = true
    if c < 0x20 then
        local pass = false
        pass = pass or (c == 10) and (bit32.band(flags, ImGuiInputTextFlags.Multiline) ~= 0) -- Note that an Enter KEY will emit \r and be ignored (we poll for KEY in InputText() code)
        if c == 10 and input_source_is_clipboard and (bit32.band(flags, ImGuiInputTextFlags.Multiline) == 0) then -- In single line mode, replace \n with a space
            char = 32
            c = 32
            pass = true
        end
        pass = pass or (c == 10) and (bit32.band(flags, ImGuiInputTextFlags.Multiline) ~= 0)
        pass = pass or (c == 9) and (bit32.band(flags, ImGuiInputTextFlags.AllowTabInput) ~= 0) -- tab
        if not pass then
            return char, false
        end
        apply_named_filters = false -- Override named filters below so newline and tabs can still be inserted.
    end

    if not input_source_is_clipboard then
        -- We ignore Ascii representation of delete (emitted from Backspace on OSX, see #2578, #2817)
        if c == 127 then
            return char, false
        end

        -- Filter private Unicode range. GLFW on OSX seems to send private characters for special keys like arrow keys (FIXME)
        if c >= 0xE000 and c <= 0xF8FF then
            return char, false
        end
    end

    -- Filter Unicode ranges we are not handling in this build
    if c > IM_UNICODE_CODEPOINT_MAX then
        return char, false
    end

    -- Generic named filters
    if apply_named_filters and (bit32.band(flags, bit32.bor(ImGuiInputTextFlags.CharsDecimal, ImGuiInputTextFlags.CharsHexadecimal, ImGuiInputTextFlags.CharsUppercase, ImGuiInputTextFlags.CharsNoBlank, ImGuiInputTextFlags.CharsScientific, ImGuiInputTextFlags.LocalizeDecimalPoint))) ~= 0 then
        -- The standard mandate that programs starts in the "C" locale where the decimal point is '.'.
        -- We don't really intend to provide widespread support for it, but out of empathy for people stuck with using odd API, we support the bare minimum aka overriding the decimal point.
        -- Change the default decimal_point with:
        --   ImGui::GetPlatformIO()->Platform_LocaleDecimalPoint = *localeconv()->decimal_point;
        -- Users of non-default decimal point (in particular ',') may be affected by word-selection logic (is_word_boundary_from_right/is_word_boundary_from_left) functions.
        local g = ctx
        local c_decimal_point = g.PlatformIO.Platform_LocaleDecimalPoint
        if bit32.band(flags, bit32.bor(ImGuiInputTextFlags.CharsDecimal, ImGuiInputTextFlags.CharsScientific, ImGuiInputTextFlags.LocalizeDecimalPoint)) ~= 0 then
            if c == 46 or c == 44 then -- '.' or ','
                c = c_decimal_point
            end
        end

        -- Full-width -> half-width conversion for numeric fields: https://en.wikipedia.org/wiki/Halfwidth_and_Fullwidth_Forms_(Unicode_block)
        -- While this is mostly convenient, this has the side-effect for uninformed users accidentally inputting full-width characters that they may
        -- scratch their head as to why it works in numerical fields vs in generic text fields it would require support in the font.
        if bit32.band(flags, bit32.bor(ImGuiInputTextFlags.CharsDecimal, ImGuiInputTextFlags.CharsScientific, ImGuiInputTextFlags.CharsHexadecimal)) ~= 0 then
            if c >= 0xFF01 and c <= 0xFF5E then
                c = c - 0xFF01 + 0x21
            end
        end

        -- Allow 0-9 . - + * /
        if bit32.band(flags, ImGuiInputTextFlags.CharsDecimal) ~= 0 then
            if not (c >= 48 and c <= 57) and (c ~= c_decimal_point) and (c ~= 45) and (c ~= 43) and (c ~= 42) and (c ~= 47) then -- 0-9 . - + * /
                return char, false
            end
        end

        -- Allow 0-9 . - + * / e E
        if bit32.band(flags, ImGuiInputTextFlags.CharsScientific) ~= 0 then
            if not (c >= 48 and c <= 57) and (c ~= c_decimal_point) and (c ~= 45) and (c ~= 43) and (c ~= 42) and (c ~= 47) and (c ~= 101) and (c ~= 69) then -- 0-9 . - + * / e E
                return char, false
            end
        end

        -- Allow 0-9 a-F A-F
        if bit32.band(flags, ImGuiInputTextFlags.CharsHexadecimal) ~= 0 then
            if not (c >= 48 and c <= 57) and not (c >= 97 and c <= 102) and not (c >= 65 and c <= 70) then -- 0-9 a-f A-F
                return char, false
            end
        end

        -- Turn a-z into A-Z
        if bit32.band(flags, ImGuiInputTextFlags.CharsUppercase) ~= 0 then
            if c >= 97 and c <= 122 then -- a-z
                c = c + (65 - 97) -- 'A' - 'a'
            end
        end

        if bit32.band(flags, ImGuiInputTextFlags.CharsNoBlank) ~= 0 then
            if ImStd.ImCharIsBlankW(c) then
                return char, false
            end
        end

        char = c
    end

    -- Custom callback filter
    if bit32.band(flags, ImGuiInputTextFlags.CallbackCharFilter) ~= 0 then
        local g = GImGui
        local callback_data = ImGuiInputTextCallbackData()
        callback_data.Ctx = g
        callback_data.ID = state.ID
        callback_data.Flags = flags
        callback_data.EventFlag = ImGuiInputTextFlags.CallbackCharFilter
        callback_data.EventChar = c
        callback_data.EventActivated = (state ~= nil and g.ActiveId == state.ID and g.ActiveIdIsJustActivated)
        callback_data.CursorPos = state.Stb.cursor - 1 -- [Luau] callback positions are 0-based
        callback_data.SelectionStart = state.Stb.select_start - 1
        callback_data.SelectionEnd = state.Stb.select_end - 1
        callback_data.UserData = user_data
        if callback(callback_data) ~= 0 then
            return char, false
        end
        char = callback_data.EventChar
        if not callback_data.EventChar then
            return char, false
        end
    end

    return char, true
end

-- Find the shortest single replacement we can make to get from old_buf to new_buf
-- Note that this doesn't directly alter state->TextA, state->TextLen. They are expected to be made valid separately.
-- FIXME: Ideally we should transition toward (1) making InsertChars()/DeleteChars() update undo-stack (2) discourage (and keep reconcile) or obsolete (and remove reconcile) accessing buffer directly.
--- @param state      ImGuiInputTextState
--- @param old_buf    ImStringBuffer
--- @param old_length int
--- @param new_buf    ImStringBuffer
--- @param new_length int
local function InputTextReconcileUndoState(state, old_buf, old_length, new_buf, new_length)
    local shorter_length = ImMin(old_length, new_length)
    local first_diff
    for i = 1, shorter_length do
        first_diff = i
        if old_buf[first_diff] ~= new_buf[first_diff] then
            break
        end
    end
    if first_diff == old_length + 1 and first_diff == new_length + 1 then
        return
    end

    local old_last_diff = old_length
    local new_last_diff = new_length
    while old_last_diff >= first_diff and new_last_diff >= first_diff do
        if old_buf[old_last_diff] ~= new_buf[new_last_diff] then
            break
        end

        old_last_diff = old_last_diff - 1
        new_last_diff = new_last_diff - 1
    end

    local insert_len = new_last_diff - first_diff + 1
    local delete_len = old_last_diff - first_diff + 1
    if insert_len > 0 or delete_len > 0 then
        local undostate = state.Stb.undostate
        local p = stbte.createundo(undostate, first_diff, delete_len, insert_len)
        if p then
            for i = 0, delete_len - 1 do
                undostate.undo_char[p + i] = old_buf[first_diff + i]
            end
        end
    end
end

-- As InputText() retain textual data and we currently provide a path for user to not retain it (via local variables)
-- we need some form of hook to reapply data back to user buffer on deactivation frame. (#4714)
-- It would be more desirable that we discourage users from taking advantage of the "user not retaining data" trick,
-- but that more likely be attractive when we do have _NoLiveEdit flag available.
--- @param id ImGuiID
function ImGui.InputTextDeactivateHook(id)
    local g = GImGui
    local state = g.InputTextState
    if id == 0 or state.ID ~= id or g.ActiveId ~= id then
        return
    end
    if not state.EditedBefore then
        return
    end
    -- IMGUI_DEBUG_LOG_ACTIVEID("InputTextDeactivateHook() id = 0x%08X\n", id);

    g.InputTextDeactivatedState.ID = state.ID
    g.InputTextDeactivatedState.ElapseFrame = g.FrameCount + 1
    if bit32.band(state.Flags, ImGuiInputTextFlags.ReadOnly) ~= 0 then
        g.InputTextDeactivatedState.TextA:resize(0) -- In theory this data won't be used, but clear to be neat.
    else
        IM_ASSERT(state.TextA.Data ~= nil)
        -- IM_ASSERT(state.TextA[state.TextLen + 1] == 0)
        g.InputTextDeactivatedState.TextA:resize(state.TextLen + 1)
        ImStd.memmove(g.InputTextDeactivatedState.TextA.Data, 1, state.TextA.Data, 1, state.TextLen) -- [Port] state.TextLen + 1
    end
end

-- FIXME-WORDWRAP: Bundle some of this into ImGuiTextIndex and/or extract as a different tool?
-- 'max_output_buffer_size' happens to be a meaningful optimization to avoid writing the full line_index when not necessarily needed (e.g. very large buffer, scrolled up, inactive)
--- @param flags                  ImGuiInputTextFlags
--- @param line_index             ImGuiTextIndex
--- @param buf                    char[]
--- @param buf_end?               int # nil: inactive multi-line path, end found with strchr()
--- @param wrap_width             float
--- @param max_output_buffer_size int
--- @param want_out_buf_end       boolean
--- @return int  size
--- @return int? out_buf_end # [Port] 'const char** out_buf_end' output parameter becomes a 2nd return value (nil when not requested)
local function InputTextLineIndexBuild(flags, line_index, buf, buf_end, wrap_width, max_output_buffer_size, want_out_buf_end)
    local g = GImGui
    local size = 0
    local s
    local trailing_line_already_counted = false
    -- [Port] 's' is a 1-based position in 'buf' (C++ s == buf + (s - 1)), Offsets store 0-based offsets like upstream.
    if bit32.band(flags, ImGuiInputTextFlags.WordWrap) ~= 0 then
        s = 1
        while s < buf_end do
            if size <= max_output_buffer_size then
                line_index.Offsets:push_back(s - 1)
            end
            size = size + 1
            s = ImFontCalcWordWrapPositionEx(g.Font, g.FontSize, buf, s, buf_end, wrap_width, ImDrawTextFlags.WrapKeepBlanks)
            if buf[s] == 10 then s = s + 1 end
        end
    elseif buf_end ~= nil then
        s = 1
        while s < buf_end do
            if size <= max_output_buffer_size then
                line_index.Offsets:push_back(s - 1)
            end
            size = size + 1
            s = ImMemchr(buf, 10, s)
            if s ~= nil and s >= buf_end then s = nil end -- [Port] ImMemchr() stops at the zero-terminator, not at buf_end
            if s then s = s + 1 else s = buf_end end
        end
    else
        -- Inactive path: we don't know buf_end ahead of time.
        local s_eol
        s = 1
        while true do
            if size <= max_output_buffer_size then
                line_index.Offsets:push_back(s - 1)
            end
            size = size + 1
            s_eol = ImMemchr(buf, 10, s)
            if s_eol == nil then
                s = s + ImStd.ImStrlen(buf, s)
                trailing_line_already_counted = true
                break
            end
            s = s_eol + 1
        end
    end
    local out_buf_end = nil
    if want_out_buf_end then
        out_buf_end = s
        buf_end = s
    end
    if size == 0 then
        line_index.Offsets:push_back(0)
        size = size + 1
    end
    if buf_end > 1 and buf[buf_end - 1] == 10 and not trailing_line_already_counted then
        local old_size = size
        size = size + 1
        if old_size <= max_output_buffer_size then
            line_index.Offsets:push_back(buf_end - 1)
        end
    end
    return size, out_buf_end
end

--- @param t        table
--- @param in_begin int
--- @param in_end   int
--- @param v        int
local function ImLowerBound(t, in_begin, in_end, v)
    local in_p = in_begin
    local count = in_end - in_begin

    local floor = math.floor
    local rshift = bit32.rshift
    while count > 0 do
        local count2 = floor(rshift(count, 1))
        local mid = in_p + count2

        if t[mid] < v then
            in_p = mid + 1
            count = count - count2 - 1
        else
            count = count2
        end
    end

    return in_p
end

--- @param g          ImGuiContext
--- @param state      ImGuiInputTextState
--- @param line_index ImGuiTextIndex
--- @param buf        char[]
--- @param buf_end    int
--- @param cursor_n   int
--- @return ImVec2
local function InputTextLineIndexGetPosOffset(g, state, line_index, buf, buf_end, cursor_n)
    -- [Port] 'cursor_n' is a 1-based position (Stb.cursor) == C++ cursor_ptr; Offsets hold 0-based offsets, compare with cursor_n - 1.
    local cursor_ptr = cursor_n
    local cursor_off = cursor_n - 1
    local offsets = line_index.Offsets
    local it_begin = 1
    local it_end = offsets.Size + 1
    local it = ImLowerBound(offsets.Data, it_begin, it_end, cursor_off)
    if it > it_begin then
        if it == it_end or offsets.Data[it] ~= cursor_off or (state ~= nil and state.WrapWidth > 0.0 and state.LastMoveDirectionLR == ImGuiDir.Right and buf[cursor_ptr - 1] ~= 10 and buf[cursor_ptr - 1] ~= 0) then
            it = it - 1
        end
    end

    local line_no = (it == it_begin) and 0 or (it - 1) -- [Port] 0-based (index_from_ptr)
    local line_start = line_index:get_line_begin(1, line_no)
    local offset = ImVec2()
    offset.x = InputTextCalcTextSize(g, buf, line_start, cursor_ptr, buf_end, nil, ImDrawTextFlags.WrapKeepBlanks).x
    offset.y = (line_no + 1) * g.FontSize
    return offset
end

-- Edit a string of text
-- - buf_size account for the zero-terminator, so a buf_size of 6 can hold "Hello" but not "Hello!".
-- - When active, hold on a privately held copy of the text (and apply back to 'buf'). So changing 'buf' while the InputText is active has no effect.
--- @param label              string
--- @param hint?              char[]
--- @param buf                char[]
--- @param buf_size           int
--- @param size_arg           ImVec2
--- @param flags              ImGuiInputTextFlags
--- @param callback?          ImGuiInputTextCallback
--- @param callback_user_data any
local InputTextEx_frame_bb, InputTextEx_total_bb = ImRect(), ImRect() -- [Luau] scratch, see InputTextEx()
local HintBufCache = setmetatable({}, { __mode = "k" })
local function HintToBuf(hint)
    local t = HintBufCache[hint]
    if t == nil then
        t = {}
        for i = 1, #hint do t[i] = string.byte(hint, i) end
        t[#hint + 1] = 0
        HintBufCache[hint] = t
    end
    return t
end

function ImGui.InputTextEx(label, hint, buf, buf_size, size_arg, flags, callback, callback_user_data)
    if type(hint) == "string" then hint = HintToBuf(hint) end
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    IM_ASSERT(buf ~= nil and buf_size >= 0)
    IM_ASSERT(not (bit32.band(flags, ImGuiInputTextFlags.CallbackHistory) ~= 0 and bit32.band(flags, ImGuiInputTextFlags.Multiline) ~= 0))        -- Can't use both together (they both use up/down keys)
    IM_ASSERT(not (bit32.band(flags, ImGuiInputTextFlags.CallbackCompletion) ~= 0 and bit32.band(flags, ImGuiInputTextFlags.AllowTabInput) ~= 0)) -- Can't use both together (they both use tab key)
    IM_ASSERT(not (bit32.band(flags, ImGuiInputTextFlags.ElideLeft) ~= 0 and bit32.band(flags, ImGuiInputTextFlags.Multiline) ~= 0))              -- Multiline does not work with left-trimming
    IM_ASSERT(bit32.band(flags, ImGuiInputTextFlags.WordWrap) == 0 or bit32.band(flags, ImGuiInputTextFlags.Password) == 0)  -- WordWrap does not work with Password mode.
    IM_ASSERT(bit32.band(flags, ImGuiInputTextFlags.WordWrap) == 0 or bit32.band(flags, ImGuiInputTextFlags.Multiline) ~= 0) -- WordWrap does not work in single-line mode.

    local g = GImGui --[[@as ImGuiContext]]
    local io = g.IO
    local style = g.Style

    local RENDER_SELECTION_WHEN_INACTIVE = false
    local is_multiline = bit32.band(flags, ImGuiInputTextFlags.Multiline) ~= 0

    if is_multiline then -- Open group before calling GetID() because groups tracks id created within their scope (including the scrollbar)
        ImGui.BeginGroup()
    end
    local id = window:GetID(label)
    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size_x, label_size_y = ImGui.CalcTextSizeXY(label, 1, label_end, false) -- [Luau] scalar label_size, frame_size, inner_size
    local frame_size_x, frame_size_y = ImGui._CalcItemSizeXY(size_arg.x, size_arg.y, ImGui.CalcItemWidth(), (is_multiline and g.FontSize * 8.0 or label_size_y) + style.FramePadding.y * 2.0)  -- Arbitrary default of 8 lines high for multi-line
    local total_size_x, total_size_y = frame_size_x + ((label_size_x > 0.0) and (style.ItemInnerSpacing.x + label_size_x) or 0.0), frame_size_y -- [Luau] scalar total_size

    -- [Luau] total_bb is a scratch rect (only ItemSize()/ItemAdd() read it); a single-line field's frame_bb too until ItemAdd() accepts it (clipped fields allocate nothing)
    local cursor = window.DC.CursorPos
    local frame_bb = is_multiline and ImRect() or InputTextEx_frame_bb
    frame_bb.Min.x = cursor.x; frame_bb.Min.y = cursor.y; frame_bb.Max.x = cursor.x + frame_size_x; frame_bb.Max.y = cursor.y + frame_size_y
    local total_bb = InputTextEx_total_bb
    total_bb.Min.x = frame_bb.Min.x; total_bb.Min.y = frame_bb.Min.y; total_bb.Max.x = frame_bb.Min.x + total_size_x; total_bb.Max.y = frame_bb.Min.y + total_size_y

    local draw_window = window
    local inner_size_x, inner_size_y = frame_size_x, frame_size_y
    local item_data_backup = is_multiline and ImGuiLastItemData() or nil -- [Luau] only used by the multi-line path
    if is_multiline then
        local backup_pos = ImVec2()
        ImVec2_Copy(backup_pos, window.DC.CursorPos)
        ImGui.ItemSize(total_bb, style.FramePadding.y)
        local no_clip = (g.InputTextDeactivatedState.ID == id) or (g.ActiveId == id) or (id == g.NavActivateId) -- Mimic some of ItemAdd() logic + add InputTextDeactivatedState.ID check.
        if not ImGui.ItemAdd(total_bb, id, frame_bb, ImGuiItemFlags.Inputable) and not no_clip then
            ImGui.EndGroup()
            return false
        end
        ImGuiLastItemData_Copy(item_data_backup, g.LastItemData)
        ImVec2_Copy(window.DC.CursorPos, backup_pos)

        -- Prevent NavActivation from explicit Tabbing when our widget accepts Tab inputs: this allows cycling through widgets without stopping.
        if g.NavActivateId == id and (bit32.band(g.NavActivateFlags, ImGuiActivateFlags.FromTabbing) ~= 0) and (bit32.band(g.NavActivateFlags, ImGuiActivateFlags.FromFocusApi) == 0) and (bit32.band(flags, ImGuiInputTextFlags.AllowTabInput) ~= 0) then
            g.NavActivateId = 0
        end

        -- Prevent NavActivate reactivating in BeginChild() when we are already active.
        local backup_activate_id = g.NavActivateId
        if g.ActiveId == id then -- Prevent reactivation
            g.NavActivateId = 0
        end

        -- We reproduce the contents of BeginChildFrame() in order to provide 'label' so our window internal data are easier to read/debug.
        ImGui.PushStyleColor(ImGuiCol.ChildBg, style.Colors[ImGuiCol.FrameBg])
        ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, style.FrameRounding)
        ImGui.PushStyleVar(ImGuiStyleVar.ChildBorderSize, style.FrameBorderSize)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(0, 0)) -- Ensure no clip rect so mouse hover can reach FramePadding edges
        local child_visible = ImGui.BeginChildEx(label, id, frame_bb:GetSize(), ImGuiChildFlags.Borders, ImGuiWindowFlags.NoMove)
        g.NavActivateId = backup_activate_id
        ImGui.PopStyleVar(3)
        ImGui.PopStyleColor()
        if not child_visible and not no_clip then
            ImGui.EndChild()
            ImGui.EndGroup()
            return false
        end
        draw_window = g.CurrentWindow -- Child window
        draw_window.DC.NavLayersActiveMaskNext = bit32.bor(draw_window.DC.NavLayersActiveMaskNext, bit32.lshift(1, draw_window.DC.NavLayerCurrent)) -- This is to ensure that EndChild() will display a navigation highlight so we can "enter" into it.
        ImVec2_Copy(draw_window.DC.CursorPos, draw_window.DC.CursorPos + style.FramePadding)
        inner_size_x = inner_size_x - draw_window.ScrollbarSizes.x

        -- FIXME: Could this be a ImGuiChildFlags to affect the SetLastItemDataForWindow() call?
        g.LastItemData.ID = id
        g.LastItemData.ItemFlags = item_data_backup.ItemFlags
        g.LastItemData.StatusFlags = item_data_backup.StatusFlags
    else
        -- Support for internal ImGuiInputTextFlags.MergedItem flag, which could be redesigned as an ItemFlags if needed (with test performed in ItemAdd)
        ImGui.ItemSize(total_bb, style.FramePadding.y)

        if bit32.band(flags, ImGuiInputTextFlags.TempInput) == 0 then
            if not ImGui.ItemAdd(total_bb, id, frame_bb, ImGuiItemFlags.Inputable) then
                return false
            end
        end
        frame_bb = ImRect(frame_bb.Min.x, frame_bb.Min.y, frame_bb.Max.x, frame_bb.Max.y) -- [Luau] own copy of the scratch from here on
    end

    -- Ensure mouse cursor is set even after switching to keyboard/gamepad mode. May generalize further? (#6417)
    local hovered = ImGui.ItemHoverable(frame_bb, id, bit32.bor(g.LastItemData.ItemFlags, ImGuiItemFlags.NoNavDisableMouseHover))
    if hovered then
        ImGui.SetMouseCursor(ImGuiMouseCursor.TextInput)
    end
    if hovered and g.NavHighlightItemUnderNav then
        hovered = false
    end

    -- We are only allowed to access the state if we are already the active widget.
    local state = ImGui.GetInputTextState(id)

    if bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.ReadOnly) ~= 0 then
        flags = bit32.bor(flags, ImGuiInputTextFlags.ReadOnly)
    end
    local is_readonly = bit32.band(flags, ImGuiInputTextFlags.ReadOnly) ~= 0
    local is_password = bit32.band(flags, ImGuiInputTextFlags.Password) ~= 0
    local is_undoable = bit32.band(flags, ImGuiInputTextFlags.NoUndoRedo) == 0
    local is_resizable = bit32.band(flags, ImGuiInputTextFlags.CallbackResize) ~= 0
    if is_resizable then
        IM_ASSERT(callback ~= nil) -- Must provide a callback if you set the ImGuiInputTextFlags.CallbackResize flag!
    end

    -- Word-wrapping: enforcing a fixed width not altered by vertical scrollbar makes things easier, notably to track cursor reliably and avoid one-frame glitches.
    -- Instead of using ImGuiWindowFlags_AlwaysVerticalScrollbar we account for that space if the scrollbar is not visible.
    local is_wordwrap = bit32.band(flags, ImGuiInputTextFlags.WordWrap) ~= 0
    local wrap_width = 0.0
    if is_wordwrap then
        wrap_width = ImMax(1.0, ImGui.GetContentRegionAvail().x + (draw_window.ScrollbarY and 0.0 or -g.Style.ScrollbarSize))
    end

    local user_clicked = hovered and io.MouseClicked[0]
    local input_requested_by_nav = (g.ActiveId ~= id) and (g.NavActivateId == id) and ((bit32.band(g.NavActivateFlags, ImGuiActivateFlags.PreferInput) ~= 0) or (g.NavInputSource == ImGuiInputSource.Keyboard))
    local input_requested_by_reactivate = (g.InputTextReactivateId == id) -- for io.ConfigInputTextEnterKeepActive
    local input_requested_by_user = (user_clicked) or (g.ActiveId == 0 and bit32.band(flags, ImGuiInputTextFlags.TempInput) ~= 0 and g.InputTextDeactivatedState.ID ~= id)
    local scrollbar_id = (is_multiline and state ~= nil) and ImGui.GetWindowScrollbarID(draw_window, ImGuiAxis.Y) or 0
    local user_scroll_finish = is_multiline and state ~= nil and g.ActiveId == 0 and g.ActiveIdPreviousFrame == scrollbar_id
    local user_scroll_active = is_multiline and state ~= nil and g.ActiveId == scrollbar_id
    local clear_active_id = false
    local select_all = false

    local scroll_y = is_multiline and draw_window.Scroll.y or FLT_MAX

    local init_reload_from_user_buf = (state ~= nil and state.WantReloadUserBuf)
    local init_changed_specs_multiline = (state ~= nil and (state.Stb.single_line ~= (not is_multiline))) -- state ~= nil means its our state.
    local init_changed_specs_readonly = (state ~= nil and (bit32.band(bit32.bxor(state.Flags, flags), ImGuiInputTextFlags.ReadOnly) ~= 0)) -- state ~= nil means its our state.
    local init_make_active = (input_requested_by_user or input_requested_by_nav or input_requested_by_reactivate or user_scroll_finish)
    if init_reload_from_user_buf then
        local new_len = ImStd.ImStrlen(buf)
        IM_ASSERT(new_len + 1 <= buf_size, "Is your input buffer properly zero-terminated?")
        state.WantReloadUserBuf = false
        --- @cast state ImGuiInputTextState
        InputTextReconcileUndoState(state, state.TextA.Data, state.TextLen, buf, new_len)
        state.TextA:resize(buf_size + 1) -- we use +1 to make sure that .Data is always pointing to at least an empty string.
        state.TextLen = new_len
        ImStd.memmove(state.TextA.Data, 1, buf, 1, state.TextLen + 1)
        state.Stb.select_start = state.ReloadSelectionStart
        state.Stb.cursor = state.ReloadSelectionEnd
        state.Stb.select_end = state.ReloadSelectionEnd -- will be clamped to bounds below
    elseif (init_make_active and g.ActiveId ~= id) or init_changed_specs_multiline or init_changed_specs_readonly then
        -- Access state even if we don't own it yet.
        state = g.InputTextState
        state:CursorAnimReset()

        -- Backup state of deactivating item so they'll have a chance to do a write to output buffer on the same frame they report IsItemDeactivatedAfterEdit (#4714)
        if (state.ID ~= id and state.ID == g.ActiveId and (init_make_active and g.ActiveId ~= id)) then
            ImGui.InputTextDeactivateHook(state.ID) -- <-- this is essentially an earlier call to what SetActiveID() would do below.
        end

        -- Take a copy of the initial buffer value.
        -- From the moment we focused we are normally ignoring the content of 'buf' (unless we are in read-only mode)
        local buf_len = ImStd.ImStrlen(buf)
        IM_ASSERT(((buf_len + 1 <= buf_size) or (buf_len == 0 and buf_size == 0)), "Is your input buffer properly zero-terminated?")
        if not user_scroll_finish then
            state.TextToRevertTo:resize(buf_len + 1) -- UTF-8. we use +1 to make sure that .Data is always pointing to at least an empty string.
            ImStd.memmove(state.TextToRevertTo.Data, 1, buf, 1, buf_len + 1)
        end

        -- Preserve cursor position and undo/redo stack if we come back to same widget
        -- FIXME: Since we reworked this on 2022/06, may want to differentiate recycle_cursor vs recycle_undostate?
        local recycle_state = (state.ID == id and not init_changed_specs_multiline)
        if (recycle_state and not init_changed_specs_readonly and (state.TextLen ~= buf_len or (state.TextA.Data == nil or ImStd.strncmp(state.TextA.Data, buf, buf_len) ~= 0))) then
            recycle_state = false
        end

        -- Start edition
        state.ID = id
        state.TextLen = buf_len
        state.EditedBefore = false
        if not is_readonly then
            state.TextA:resize(buf_size + 1) -- we use +1 to make sure that .Data is always pointing to at least an empty string.
            ImStd.memmove(state.TextA.Data, 1, buf, 1, state.TextLen + 1)
        end

        -- Find initial scroll position for right alignment
        ImVec2_Copy(state.Scroll, ImVec2(0.0, 0.0))
        if bit32.band(flags, ImGuiInputTextFlags.ElideLeft) ~= 0 then
            state.Scroll.x = state.Scroll.x + ImMax(0.0, ImGui.CalcTextSize(table.concat(buf)).x - frame_size_x + style.FramePadding.x * 2.0) -- [Port] FIXME: no table.concat here
        end

        -- Recycle existing cursor/selection/undo stack but clamp position
        -- Note a single mouse click will override the cursor/position immediately by calling stb_textedit_click handler.
        if not recycle_state then
            stbte.initialize_state(state.Stb, not is_multiline)
        end

        if not is_multiline then
            if bit32.band(flags, ImGuiInputTextFlags.AutoSelectAll) ~= 0 then
                select_all = true
            end
            if input_requested_by_nav and (not recycle_state or (bit32.band(g.NavActivateFlags, ImGuiActivateFlags.TryToPreserveState) == 0)) then
                select_all = true
            end
            if user_clicked and io.KeyCtrl then
                select_all = true
            end
        end

        if bit32.band(flags, ImGuiInputTextFlags.AlwaysOverwrite) ~= 0 then
            state.Stb.insert_mode = true -- stb field name is indeed incorrect (see #2863)
        end
    end

    local is_osx = io.ConfigMacOSXBehaviors

    if init_make_active and g.ActiveId ~= id then
        IM_ASSERT(state ~= nil and state.ID == id)
        ImGui.SetActiveID(id, window)
        ImGui.SetFocusID(id, window)
        ImGui.FocusWindow(window)
        if input_requested_by_nav then
            ImGui.SetNavCursorVisibleAfterMove()
        end
    end
    if g.ActiveId == id then
        -- Declare some inputs, the other are registered and polled via Shortcut() routing system.
        -- FIXME: The reason we don't use Shortcut() is we would need a routing flag to specify multiple mods, or to all mods combination into individual shortcuts.
        local always_owned_keys = { ImGuiKey.LeftArrow, ImGuiKey.RightArrow, ImGuiKey.Delete, ImGuiKey.Backspace, ImGuiKey.Home, ImGuiKey.End }
        for _, key in ipairs(always_owned_keys) do
            ImGui.SetKeyOwner(key, id)
        end
        if user_clicked then
            ImGui.SetKeyOwner(ImGuiKey.MouseLeft, id)
        end
        g.ActiveIdUsingNavDirMask = bit32.bor(g.ActiveIdUsingNavDirMask, bit32.lshift(1, ImGuiDir.Left), bit32.lshift(1, ImGuiDir.Right))
        if is_multiline or (bit32.band(flags, ImGuiInputTextFlags.CallbackHistory) ~= 0) then
            g.ActiveIdUsingNavDirMask = bit32.bor(g.ActiveIdUsingNavDirMask, bit32.lshift(1, ImGuiDir.Up), bit32.lshift(1, ImGuiDir.Down))
            ImGui.SetKeyOwner(ImGuiKey.UpArrow, id)
            ImGui.SetKeyOwner(ImGuiKey.DownArrow, id)
        end
        if is_multiline then
            ImGui.SetKeyOwner(ImGuiKey.PageUp, id)
            ImGui.SetKeyOwner(ImGuiKey.PageDown, id)
        end
        -- FIXME: May be a problem to always steal Alt on OSX, would ideally still allow an uninterrupted Alt down-up to toggle menu
        if is_osx then
            ImGui.SetKeyOwner(ImGuiMod_Alt, id)
        end

        -- Expose scroll in a manner that is agnostic to us using a child window
        if is_multiline and state ~= nil then
            state.Scroll.y = draw_window.Scroll.y
        end

        -- Read-only mode always ever read from source buffer. Refresh TextLen when active.
        if is_readonly and state ~= nil then
            state.TextLen = ImStd.ImStrlen(buf)
        end
        if state ~= nil then
            state:CursorClamp()
        end
        -- if is_readonly and state ~= nil then
        --     state.TextA:clear() -- Uncomment to facilitate debugging, but we otherwise prefer to keep/amortize th allocation.
        -- end
    end
    if state ~= nil then
        state.TextSrc = is_readonly and buf or state.TextA.Data
    end

    -- We have an edge case if ActiveId was set through another widget (e.g. widget being swapped), clear id immediately (don't wait until the end of the function)
    if g.ActiveId == id and state == nil then
        ImGui.ClearActiveID()
    end

    -- Release focus when we click outside
    if g.ActiveId == id and io.MouseClicked[0] and not init_make_active then
        clear_active_id = true
    end

    -- Lock the decision of whether we are going to take the path displaying the cursor or selection
    local render_cursor = (g.ActiveId == id) or (state and user_scroll_active) --[[@as bool]]
    local render_selection = state and (state:HasSelection() or select_all) and (RENDER_SELECTION_WHEN_INACTIVE or render_cursor)
    local value_changed = false
    local validated = false

    -- Select the buffer to render.
    local buf_display_from_state = (render_cursor or render_selection or g.ActiveId == id) and not is_readonly and state ~= nil
    local is_displaying_hint = (hint ~= nil and (buf_display_from_state and state.TextA.Data or buf)[1] == 0)

    -- Password pushes a temporary font with only a fallback glyph
    if is_password and not is_displaying_hint then
        ImGui.PushPasswordFont()
    end

    if state ~= nil and state.ID == id then
        state.Flags = flags
        state.EditedThisFrame = false; state.ValidatedThisFrame = false

        -- Word-wrapping: attempt to keep cursor in view while resizing frame/parent (FIXME-WORDWRAP: would be better to preserve same relative offset)
        if is_wordwrap and state.WrapWidth ~= wrap_width then
            state.CursorCenterY = true
            state.WrapWidth = wrap_width
            render_cursor = true
        end
    end

    -- Process mouse inputs and character inputs
    if g.ActiveId == id then
        --- @cast state ImGuiInputTextState
        IM_ASSERT(state ~= nil)
        state.BufCapacity = buf_size
        state.WrapWidth = wrap_width

        -- Although we are active we don't prevent mouse from hovering other elements unless we are interacting right now with the widget.
        -- Down the line we should have a cleaner library-wide concept of Selected vs Active.
        g.ActiveIdAllowOverlap = not io.MouseDown[0]

        -- Edit in progress
        local mouse_x = (io.MousePos.x - frame_bb.Min.x - style.FramePadding.x) + state.Scroll.x
        local mouse_y = (is_multiline and (io.MousePos.y - draw_window.DC.CursorPos.y) or (g.FontSize * 0.5))

        if select_all then
            state:SelectAll()
            state.SelectedAllMouseLock = true
        elseif hovered and io.MouseClickedCount[0] >= 2 and not io.KeyShift then
            stbte.click(state, state.Stb, mouse_x, mouse_y)
            local multiclick_count = (io.MouseClickedCount[0] - 2)
            if multiclick_count % 2 == 0 then
                -- Double-click: Select word
                -- We always use the "Mac" word advance for double-click select vs Ctrl+Right which use the platform dependent variant:
                -- FIXME: There are likely many ways to improve this behavior, but there's no "right" behavior (depends on use-case, software, OS)
                local is_bol = (state.Stb.cursor == 1) or ImStb.TEXTEDIT_GETCHAR(state, state.Stb.cursor - 1) == 10
                if stbte.HAS_SELECTION(state.Stb) or not is_bol then
                    state:OnKeyPressed(STB_TEXTEDIT_K_WORDLEFT)
                end
                -- state:OnKeyPressed(bit32.bor(STB_TEXTEDIT_K_WORDRIGHT, STB_TEXTEDIT_K_SHIFT))
                if not stbte.HAS_SELECTION(state.Stb) then
                    stbte.prep_selection_at_cursor(state.Stb)
                end
                state.Stb.cursor = ImStb.TEXTEDIT_MOVEWORDRIGHT_MAC(state, state.Stb.cursor)
                state.Stb.select_end = state.Stb.cursor
                stbte.clamp(state, state.Stb)
            else
                -- Triple-click: Select line
                local is_eol = ImStb.TEXTEDIT_GETCHAR(state, state.Stb.cursor) == 10
                state.WrapWidth = 0.0 -- Temporarily disable wrapping so we use real line start.
                state:OnKeyPressed(STB_TEXTEDIT_K_LINESTART)
                state:OnKeyPressed(bit32.bor(STB_TEXTEDIT_K_LINEEND, STB_TEXTEDIT_K_SHIFT))
                state:OnKeyPressed(bit32.bor(STB_TEXTEDIT_K_RIGHT, STB_TEXTEDIT_K_SHIFT))
                state.WrapWidth = wrap_width
                if not is_eol and is_multiline then
                    state.Stb.select_start, state.Stb.select_end = state.Stb.select_end, state.Stb.select_start
                    state.Stb.cursor = state.Stb.select_end
                end
                state.CursorFollow = false
            end
            state:CursorAnimReset()
        elseif io.MouseClicked[0] and not state.SelectedAllMouseLock then
            if hovered then
                if io.KeyShift then
                    stbte.drag(state, state.Stb, mouse_x, mouse_y)
                else
                    stbte.click(state, state.Stb, mouse_x, mouse_y)
                end
                state:CursorAnimReset()
            end
        elseif io.MouseDown[0] and not state.SelectedAllMouseLock and (io.MouseDelta.x ~= 0.0 or io.MouseDelta.y ~= 0.0) then
            stbte.drag(state, state.Stb, mouse_x, mouse_y)
            state:CursorAnimReset()
            state.CursorFollow = true
        end
        if state.SelectedAllMouseLock and not io.MouseDown[0] then
            state.SelectedAllMouseLock = false
        end

        -- We expect backends to emit a Tab key but some also emit a Tab character which we ignore (#2467, #1336)
        -- (For Tab and Enter: Win32/SFML/Allegro are sending both keys and chars, GLFW and SDL are only sending keys. For Space they all send all threes)
        if bit32.band(flags, ImGuiInputTextFlags.AllowTabInput) ~= 0 and not is_readonly then
            if ImGui.Shortcut(ImGuiKey.Tab, ImGuiInputFlags.Repeat, id) then
                local c = 9 -- Insert TAB
                local ret2
                c, ret2 = InputTextFilterCharacter(g, state, c, callback, callback_user_data)
                if ret2 then
                    state:OnCharPressed(c)
                end
            end

            -- FIXME: Implement Shift+Tab
            -- if ImGui.Shortcut(bit32.bor(ImGuiKey.Tab, ImGuiMod_Shift), ImGuiInputFlags.Repeat, id) then
            -- end
        end

        -- Process regular text input (before we check for Return because using some IME will effectively send a Return?)
        -- We ignore Ctrl inputs, but need to allow Alt+Ctrl as some keyboards (e.g. German) use AltGR (which _is_ Alt+Ctrl) to input certain characters.
        local ignore_char_inputs = io.KeyCtrl and not io.KeyAlt
        if io.InputQueueCharacters.Size > 0 then
            if not ignore_char_inputs and not is_readonly and not input_requested_by_nav then
                for n = 1, io.InputQueueCharacters.Size do
                    repeat
                    -- Insert character if they pass filtering
                    local c = io.InputQueueCharacters[n]
                    if c == 9 then -- Skip Tab, see above.
                        break
                    end

                    local ret2
                    c, ret2 = InputTextFilterCharacter(g, state, c, callback, callback_user_data)
                    if ret2 then
                        state:OnCharPressed(c)
                    end

                    until true
                end
            end

            -- Consume characters
            io.InputQueueCharacters:resize(0)
        end
    end

    -- Process other shortcuts/key-presses
    local revert_edit = false
    if g.ActiveId == id and not g.ActiveIdIsJustActivated and not clear_active_id then
        IM_ASSERT(state ~= nil)
        --- @cast state ImGuiInputTextState

        local row_count_per_page = ImMax(ImTrunc((inner_size_y - style.FramePadding.y) / g.FontSize), 1)
        state.Stb.row_count_per_page = row_count_per_page

        local k_mask = (io.KeyShift and STB_TEXTEDIT_K_SHIFT or 0)
        local is_wordmove_key_down = is_osx and io.KeyAlt or io.KeyCtrl -- OS X style: Text editing cursor movement using Alt instead of Ctrl
        local is_startend_key_down = is_osx and io.KeyCtrl and not io.KeySuper and not io.KeyAlt -- OS X style: Line/Text Start and End using Cmd+Arrows instead of Home/End

        -- Using Shortcut() with ImGuiInputFlags.RouteFocused (default policy) to allow routing operations for other code (e.g. calling window trying to use Ctrl+A and Ctrl+B: former would be handled by InputText)
        -- Otherwise we could simply assume that we own the keys as we are active.
        local f_repeat = ImGuiInputFlags.Repeat
        local is_cut   = (ImGui.Shortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.X), f_repeat, id) or ImGui.Shortcut(bit32.bor(ImGuiMod_Shift, ImGuiKey.Delete), f_repeat, id)) and not is_readonly and not is_password and (not is_multiline or state:HasSelection())
        local is_copy  = (ImGui.Shortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.C), 0,        id) or ImGui.Shortcut(bit32.bor(ImGuiMod_Ctrl,  ImGuiKey.Insert), 0,        id)) and not is_password and (not is_multiline or state:HasSelection())
        local is_paste = (ImGui.Shortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.V), f_repeat, id) or ImGui.Shortcut(bit32.bor(ImGuiMod_Shift, ImGuiKey.Insert), f_repeat, id)) and not is_readonly
        local is_undo  = (ImGui.Shortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.Z), f_repeat, id)) and not is_readonly and is_undoable
        local is_redo  = (ImGui.Shortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.Y), f_repeat, id) or ImGui.Shortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiMod_Shift, ImGuiKey.Z), f_repeat, id)) and not is_readonly and is_undoable
        local is_select_all = ImGui.Shortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.A), 0, id)

        -- We allow validate/cancel with Nav source (gamepad) to makes it easier to undo an accidental NavInput press with no keyboard wired, but otherwise it isn't very useful.
        local nav_gamepad_active  = (bit32.band(io.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad) ~= 0) and (bit32.band(io.BackendFlags, ImGuiBackendFlags.HasGamepad) ~= 0)
        local is_enter            = ImGui.Shortcut(ImGuiKey.Enter, f_repeat, id) or ImGui.Shortcut(ImGuiKey.KeypadEnter, f_repeat, id)
        local is_ctrl_enter       = ImGui.Shortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.Enter), f_repeat, id) or ImGui.Shortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.KeypadEnter), f_repeat, id)
        local is_shift_enter      = ImGui.Shortcut(bit32.bor(ImGuiMod_Shift, ImGuiKey.Enter), f_repeat, id) or ImGui.Shortcut(bit32.bor(ImGuiMod_Shift, ImGuiKey.KeypadEnter), f_repeat, id)
        local is_gamepad_validate = nav_gamepad_active and ImGui.IsKeyPressed(ImGuiKey.NavGamepadActivate, false)
        local is_cancel           = ImGui.Shortcut(ImGuiKey.Escape, f_repeat, id) or (nav_gamepad_active and ImGui.Shortcut(ImGuiKey.NavGamepadCancel, f_repeat, id))

        -- FIXME: Should use more Shortcut() and reduce IsKeyPressed()+SetKeyOwner(), but requires modifiers combination to be taken account of.
        -- FIXME-OSX: Missing support for Alt(option)+Right/Left = go to end of line, or next line if already in end of line.
        if ImGui.IsKeyPressed(ImGuiKey.LeftArrow) then
            state:OnKeyPressed(bit32.bor(is_startend_key_down and STB_TEXTEDIT_K_LINESTART or (is_wordmove_key_down and STB_TEXTEDIT_K_WORDLEFT or STB_TEXTEDIT_K_LEFT), k_mask))
        elseif ImGui.IsKeyPressed(ImGuiKey.RightArrow) then
            state:OnKeyPressed(bit32.bor(is_startend_key_down and STB_TEXTEDIT_K_LINEEND or (is_wordmove_key_down and STB_TEXTEDIT_K_WORDRIGHT or STB_TEXTEDIT_K_RIGHT), k_mask))
        elseif ImGui.IsKeyPressed(ImGuiKey.UpArrow) and is_multiline then
            if io.KeyCtrl then
                ImGui.SetScrollY(draw_window, ImMax(draw_window.Scroll.y - g.FontSize, 0.0))
            else
                state:OnKeyPressed(bit32.bor(is_startend_key_down and STB_TEXTEDIT_K_TEXTSTART or STB_TEXTEDIT_K_UP, k_mask))
            end
        elseif ImGui.IsKeyPressed(ImGuiKey.DownArrow) and is_multiline then
            if io.KeyCtrl then
                ImGui.SetScrollY(draw_window, ImMin(draw_window.Scroll.y + g.FontSize, ImGui.GetScrollMaxY()))
            else
                state:OnKeyPressed(bit32.bor(is_startend_key_down and STB_TEXTEDIT_K_TEXTEND or STB_TEXTEDIT_K_DOWN, k_mask))
            end
        elseif ImGui.IsKeyPressed(ImGuiKey.PageUp) and is_multiline then
            state:OnKeyPressed(bit32.bor(STB_TEXTEDIT_K_PGUP, k_mask))
            scroll_y = scroll_y - row_count_per_page * g.FontSize
        elseif ImGui.IsKeyPressed(ImGuiKey.PageDown) and is_multiline then
            state:OnKeyPressed(bit32.bor(STB_TEXTEDIT_K_PGDOWN, k_mask))
            scroll_y = scroll_y + row_count_per_page * g.FontSize
        elseif ImGui.IsKeyPressed(ImGuiKey.Home) then
            state:OnKeyPressed(io.KeyCtrl and bit32.bor(STB_TEXTEDIT_K_TEXTSTART, k_mask) or bit32.bor(STB_TEXTEDIT_K_LINESTART, k_mask))
        elseif ImGui.IsKeyPressed(ImGuiKey.End) then
            state:OnKeyPressed(io.KeyCtrl and bit32.bor(STB_TEXTEDIT_K_TEXTEND, k_mask) or bit32.bor(STB_TEXTEDIT_K_LINEEND, k_mask))
        elseif ImGui.IsKeyPressed(ImGuiKey.Delete) and not is_readonly and not is_cut then
            if not state:HasSelection() then
                -- OSX doesn't seem to have Super+Delete to delete until end-of-line, so we don't emulate that (as opposed to Super+Backspace)
                if is_wordmove_key_down then
                    state:OnKeyPressed(bit32.bor(STB_TEXTEDIT_K_WORDRIGHT, STB_TEXTEDIT_K_SHIFT))
                end
            end
            state:OnKeyPressed(bit32.bor(STB_TEXTEDIT_K_DELETE, k_mask))
        elseif ImGui.IsKeyPressed(ImGuiKey.Backspace) and not is_readonly then
            if not state:HasSelection() then
                if is_wordmove_key_down then
                    state:OnKeyPressed(bit32.bor(STB_TEXTEDIT_K_WORDLEFT, STB_TEXTEDIT_K_SHIFT))
                elseif is_osx and io.KeyCtrl and not io.KeyAlt and not io.KeySuper then
                    state:OnKeyPressed(bit32.bor(STB_TEXTEDIT_K_LINESTART, STB_TEXTEDIT_K_SHIFT))
                end
            end
            state:OnKeyPressed(bit32.bor(STB_TEXTEDIT_K_BACKSPACE, k_mask))
        elseif is_enter or is_ctrl_enter or is_shift_enter or is_gamepad_validate then
            -- Determine if we turn Enter into a \n character
            local ctrl_enter_for_new_line = bit32.band(flags, ImGuiInputTextFlags.CtrlEnterForNewLine) ~= 0
            local is_new_line = is_multiline and not is_gamepad_validate and (is_shift_enter or (is_enter and not ctrl_enter_for_new_line) or (is_ctrl_enter and ctrl_enter_for_new_line))
            if not is_new_line then
                validated = true
                clear_active_id = true
                if io.ConfigInputTextEnterKeepActive and not is_multiline and not is_ctrl_enter and not is_shift_enter then
                    -- Queue reactivation, so that e.g. IsItemDeactivatedAfterEdit() will work. (#9001)
                    state:SelectAll() -- No need to scroll
                    g.InputTextReactivateId = id -- Mark for reactivation on next frame
                end
            elseif not is_readonly then
                -- Insert new line
                local c = 10
                local ret2
                c, ret2 = InputTextFilterCharacter(g, state, c, callback, callback_user_data)
                if ret2 then
                    state:OnCharPressed(c)
                end
            end
        elseif is_cancel then
            if bit32.band(flags, ImGuiInputTextFlags.EscapeClearsAll) ~= 0 then
                if state.TextA.Data[1] ~= 0 then
                    revert_edit = true
                else
                    render_cursor = false
                    render_selection = false
                    clear_active_id = true
                end
            else
                clear_active_id = true
                revert_edit = true
                render_cursor = false
                render_selection = false
            end
        elseif is_undo or is_redo then
            state:OnKeyPressed(is_undo and STB_TEXTEDIT_K_UNDO or STB_TEXTEDIT_K_REDO)
            state:ClearSelection()
        elseif is_select_all then
            state:SelectAll()
            state.CursorFollow = true
        elseif is_cut or is_copy then
            -- Cut, Copy
            if g.PlatformIO.Platform_SetClipboardTextFn ~= nil then
                -- SetClipboardText() only takes null terminated strings + state.TextSrc may point to read-only user buffer, so we need to make a copy.
                local ib = state:HasSelection() and ImMin(state.Stb.select_start, state.Stb.select_end) or 1
                local ie = state:HasSelection() and ImMax(state.Stb.select_start, state.Stb.select_end) or state.TextLen + 1
                g.TempBuffer:reserve(ie - ib + 1)
                ImStd.memmove(g.TempBuffer.Data, 1, state.TextSrc, ib, ie - ib)
                g.TempBuffer.Data[ie - ib + 1] = 0
                ImGui.SetClipboardText(ImGui._ByteArrayToString(g.TempBuffer.Data, 1, ie - ib + 1))
            end
            if is_cut then
                if not state:HasSelection() then
                    state:SelectAll()
                end
                state.CursorFollow = true
                stbte.cut(state, state.Stb)
            end
        elseif is_paste then
            local clipboard = ImGui.GetClipboardText()
            if clipboard then
                -- Filter pasted buffer
                local clipboard_len = #clipboard
                local clipboard_end = clipboard_len + 1
                local clipboard_filtered = ImVector()
                clipboard_filtered:reserve(clipboard_len + 1)
                local s
                local i = 1
                while i <= clipboard_len do
                    repeat
                    s = string.byte(clipboard, i)
                    local c, ret2
                    local in_len
                    in_len, c = ImStd.ImTextCharFromUtf8(clipboard, i, clipboard_end)
                    i = i + in_len
                    c, ret2 = InputTextFilterCharacter(g, state, c, callback, callback_user_data, true)
                    if not ret2 then
                        break -- continue
                    end

                    local c_utf8 = {0, 0, 0, 0, 0}
                    ImStd.ImTextCharToUtf8(c_utf8, c)
                    local out_len = ImStd.ImStrlen(c_utf8)
                    clipboard_filtered:resize(clipboard_filtered.Size + out_len)
                    ImStd.memmove(clipboard_filtered.Data, clipboard_filtered.Size - out_len + 1, c_utf8, 1, out_len)

                    until true
                end
                if clipboard_filtered.Size > 0 then -- If everything was filtered, ignore the pasting operation
                    clipboard_filtered:push_back(0)
                    stbte.paste(state, state.Stb, clipboard_filtered.Data, clipboard_filtered.Size - 1)
                    state.CursorFollow = true
                end
            end
        end

        -- Update render selection flag after events have been handled, so selection highlight can be displayed during the same frame.
        render_selection = render_selection or (state:HasSelection() and (RENDER_SELECTION_WHEN_INACTIVE or render_cursor))
    end

    -- Process revert and user callbacks
    local apply_new_text = nil
    local apply_new_text_length = 0
    if g.ActiveId == id then
        IM_ASSERT(state ~= nil)
        --- @cast state ImGuiInputTextState

        if revert_edit and not is_readonly then
            if bit32.band(flags, ImGuiInputTextFlags.EscapeClearsAll) ~= 0 then
                -- Clear input
                IM_ASSERT(state.TextA.Data[1] ~= 0)
                apply_new_text = {0}
                apply_new_text_length = 0
                value_changed = true
                local empty_string = {0}
                ImStb.stb_textedit_replace(state, state.Stb, empty_string, 0)
            elseif ImStd.strcmp(state.TextA.Data, state.TextToRevertTo.Data) ~= 0 then
                apply_new_text = state.TextToRevertTo.Data
                apply_new_text_length = state.TextToRevertTo.Size - 1

                -- Restore initial value. Only return true if restoring to the initial value changes the current buffer contents.
                -- Push records into the undo stack so we can Ctrl+Z the revert operation itself
                value_changed = true
                ImStb.stb_textedit_replace(state, state.Stb, state.TextToRevertTo.Data, state.TextToRevertTo.Size - 1)
            end
        end

        -- User callback
        if bit32.band(flags, bit32.bor(ImGuiInputTextFlags.CallbackCompletion, ImGuiInputTextFlags.CallbackHistory, ImGuiInputTextFlags.CallbackEdit, ImGuiInputTextFlags.CallbackAlways)) ~= 0 then
            IM_ASSERT(callback ~= nil)

            -- The reason we specify the usage semantic (Completion/History) is that Completion needs to disable keyboard TABBING at the moment.

            local event_flag = 0
            local event_key = ImGuiKey.None
            if bit32.band(flags, ImGuiInputTextFlags.CallbackCompletion) ~= 0 and ImGui.Shortcut(ImGuiKey.Tab, 0, id) then
                event_flag = ImGuiInputTextFlags.CallbackCompletion
                event_key = ImGuiKey.Tab
            elseif bit32.band(flags, ImGuiInputTextFlags.CallbackHistory) ~= 0 and ImGui.IsKeyPressed(ImGuiKey.UpArrow) then
                event_flag = ImGuiInputTextFlags.CallbackHistory
                event_key = ImGuiKey.UpArrow
            elseif bit32.band(flags, ImGuiInputTextFlags.CallbackHistory) ~= 0 and ImGui.IsKeyPressed(ImGuiKey.DownArrow) then
                event_flag = ImGuiInputTextFlags.CallbackHistory
                event_key = ImGuiKey.DownArrow
            elseif bit32.band(flags, ImGuiInputTextFlags.CallbackEdit) ~= 0 and state.EditedThisFrame then
                event_flag = ImGuiInputTextFlags.CallbackEdit
            elseif bit32.band(flags, ImGuiInputTextFlags.CallbackAlways) ~= 0 then
                event_flag = ImGuiInputTextFlags.CallbackAlways
            end

            if event_flag ~= 0 then
                local callback_data = ImGuiInputTextCallbackData()
                callback_data.Ctx = g
                callback_data.ID = id
                callback_data.Flags = flags
                callback_data.EventFlag = event_flag
                callback_data.EventActivated = (g.ActiveId == state.ID and g.ActiveIdIsJustActivated)
                callback_data.UserData = callback_user_data

                -- FIXME-OPT: Undo stack reconcile needs a backup of the data until we rework API, see #7925
                local callback_buf = is_readonly and buf or state.TextA.Data
                IM_ASSERT(callback_buf == state.TextSrc)
                state.CallbackTextBackup:resize(state.TextLen + 1)
                ImStd.memmove(state.CallbackTextBackup.Data, 1, callback_buf, 1, state.TextLen + 1)

                callback_data.EventKey = event_key
                callback_data.Buf = callback_buf
                callback_data.BufTextLen = state.TextLen
                callback_data.BufSize = state.BufCapacity
                callback_data.BufDirty = false
                callback_data.CursorPos = state.Stb.cursor - 1 -- [Luau] callback positions are 0-based, stb ones 1-based
                callback_data.SelectionStart = state.Stb.select_start - 1
                callback_data.SelectionEnd = state.Stb.select_end - 1

                -- Call user code
                callback(callback_data)

                -- Read back what user may have modified
                callback_buf = is_readonly and buf or state.TextA.Data -- Pointer may have been invalidated by a resize callback
                IM_ASSERT(callback_data.Buf == callback_buf) -- Invalid to modify those fields
                IM_ASSERT(callback_data.BufSize == state.BufCapacity)
                IM_ASSERT(callback_data.Flags == flags)
                if callback_data.BufDirty or callback_data.CursorPos ~= state.Stb.cursor - 1 then
                    state.CursorFollow = true
                end
                state.Stb.cursor = ImClamp(callback_data.CursorPos, 0, callback_data.BufTextLen) + 1
                state.Stb.select_start = ImClamp(callback_data.SelectionStart, 0, callback_data.BufTextLen) + 1
                state.Stb.select_end = ImClamp(callback_data.SelectionEnd, 0, callback_data.BufTextLen) + 1
                if callback_data.BufDirty then
                    -- Callback may update buffer and thus set buf_dirty even in read-only mode.
                    IM_ASSERT(callback_data.BufTextLen == ImStd.ImStrlen(callback_data.Buf)) -- You need to maintain BufTextLen if you change the text!
                    InputTextReconcileUndoState(state, state.CallbackTextBackup.Data, state.CallbackTextBackup.Size - 1, callback_data.Buf, callback_data.BufTextLen)
                    state.TextLen = callback_data.BufTextLen -- Assume correct length and valid UTF-8 from user, saves us an extra strlen()
                    state.EditedBefore = true; state.EditedThisFrame = true
                    state:CursorAnimReset()
                end
            end
        end

        -- Write back result string if modified.
        -- FIXME-OPT: Could mark dirty state from the stb_textedit callbacks
        if not is_readonly then
            if bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.LiveEditOnInputText) ~= 0 then
                -- Apply when modified
                if (ImStd.strcmp(state.TextSrc, buf) ~= 0) then
                    apply_new_text = state.TextSrc
                    apply_new_text_length = state.TextLen
                    value_changed = true
                end
            else
                -- Apply on validation/deactivation, otherwise cancel out previous apply attempts (e.g. revert)
                value_changed = ((validated or clear_active_id or revert_edit) and ImStd.strcmp(state.TextSrc, buf) ~= 0)
                apply_new_text = value_changed and state.TextSrc or NULL
                apply_new_text_length = value_changed and state.TextLen or 0
            end
        end
    end

    -- Handle reapplying final data on deactivation (see InputTextDeactivateHook() for details)
    -- This is used when e.g. losing focus or tabbing out into another InputText() which may already be using the temp buffer.
    if g.InputTextDeactivatedState.ID == id then
        -- The state only exists after an Edit. IsItemDeactivatedAfterEdit() is not valid in every code path (see "widgets_inputtext_status_noliveedit" test).
        if ((g.ActiveId ~= id and ImGui.IsItemDeactivated()) or (g.ActiveId == id and bit32.band(flags, ImGuiInputTextFlags.TempInput) ~= 0)) then
            if (not is_readonly and ImStd.strcmp(g.InputTextDeactivatedState.TextA.Data, buf) ~= 0) then
                apply_new_text = g.InputTextDeactivatedState.TextA.Data
                apply_new_text_length = g.InputTextDeactivatedState.TextA.Size - 1
                value_changed = true
                -- IMGUI_DEBUG_LOG("InputText(): apply Deactivated data for 0x%08X: \"%.*s\".\n", id, apply_new_text_length, apply_new_text);
            end
        end
        g.InputTextDeactivatedState.ID = 0
    end

    -- Write back result to user buffer. This can currently only happen when (g.ActiveId == id) or when just deactivated.
    -- - As soon as the InputText() is active, our stored in-widget value gets priority over any underlying modification of the user buffer.
    -- - Make sure we always reapply the live buffer back to the input/user buffer before clearing ActiveId, even thought strictly speaking
    --   it was not modified on this frame. This allows the user to use InputText() without maintaining any user-side storage.
    --   (PS: if you use this property together with ImGuiInputTextFlags.CallbackResize, you are at the risk of recreating a temporary
    --    allocated/string object every frame. Which in the grand scheme of scheme is nothing, but isn't dear imgui vibe).
    if apply_new_text ~= nil then
        IM_ASSERT(apply_new_text_length >= 0)
        if is_resizable then
            local callback_data = ImGuiInputTextCallbackData()
            callback_data.Ctx = g
            callback_data.ID = id
            callback_data.Flags = flags
            callback_data.EventFlag = ImGuiInputTextFlags.CallbackResize
            callback_data.EventActivated = (g.ActiveId == state.ID and g.ActiveIdIsJustActivated)
            callback_data.Buf = buf
            callback_data.BufTextLen = apply_new_text_length
            callback_data.BufSize = ImMax(buf_size, apply_new_text_length + 1)
            callback_data.UserData = callback_user_data

            callback(callback_data)

            buf = callback_data.Buf
            buf_size = callback_data.BufSize
            apply_new_text_length = ImMin(callback_data.BufTextLen, buf_size - 1)
            IM_ASSERT(apply_new_text_length <= buf_size)
        end
        -- IMGUI_DEBUG_PRINT("InputText(\"%s\"): apply_new_text length %d\n", label, apply_new_text_length);

        -- If the underlying buffer resize was denied or not carried to the next frame, apply_new_text_length+1 may be >= buf_size.
        ImStd.ImStrncpy(buf, 1, apply_new_text, 1, ImMin(apply_new_text_length + 1, buf_size))
    end

    -- Release active ID at the end of the function (so e.g. pressing Return still does a final application of the value)
    -- Otherwise request text input ahead for next frame.
    if g.ActiveId == id and clear_active_id then
        state.ID = 0
        ImGui.ClearActiveID()
        state.ID = id
    end

    -- Render frame
    if not is_multiline then
        ImGui.RenderNavCursor(frame_bb, id)
        ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, ImGui.GetColorU32(ImGuiCol.FrameBg), true, style.FrameRounding)
    end

    local draw_pos = ImVec2()
    ImVec2_Copy(draw_pos, is_multiline and draw_window.DC.CursorPos or (frame_bb.Min + style.FramePadding))
    local clip_rect = ImRect(frame_bb.Min.x, frame_bb.Min.y, frame_bb.Min.x + inner_size_x, frame_bb.Min.y + inner_size_y) -- Not using frame_bb.Max because we have adjusted size
    if is_multiline then
        clip_rect:ClipWith(draw_window.ClipRect)
    end

    -- Set upper limit of single-line InputTextEx() at 2 million characters strings. The current pathological worst case is a long line
    -- without any carriage return, which would makes ImFont::RenderText() reserve too many vertices and probably crash. Avoid it altogether.
    -- Note that we only use this limit on single-line InputText(), so a pathologically large line on a InputTextMultiline() would still crash.
    local buf_display_max_length = 2 * 1024 * 1024
    local buf_display = buf_display_from_state and state.TextA.Data or buf
    local buf_display_end = nil -- We have specialized paths below for setting the length

    -- Display hint when contents is empty
    -- At this point we need to handle the possibility that a callback could have modified the underlying buffer (#8368)
    local new_is_displaying_hint = (hint ~= nil and (buf_display_from_state and state.TextA.Data or buf)[1] == 0)
    if new_is_displaying_hint ~= is_displaying_hint then
        if is_password and not is_displaying_hint then
            ImGui.PopPasswordFont()
        end
        is_displaying_hint = new_is_displaying_hint
        if is_password and not is_displaying_hint then
            ImGui.PushPasswordFont()
        end
    end
    if is_displaying_hint then
        --- @cast hint char[]
        buf_display = hint
        buf_display_end = ImStd.ImStrlen(hint) + 1
    else
        if render_cursor or render_selection or g.ActiveId == id then
            buf_display_end = state.TextLen + 1
        elseif is_multiline and not is_wordwrap then
            buf_display_end = nil -- Inactive multi-line: end of buffer will be output by InputTextLineIndexBuild() special strchr() path.
        else
            buf_display_end = ImStd.ImStrlen(buf_display) + 1
        end
    end

    -- Calculate visibility
    local line_visible_n0, line_visible_n1 = 0, 1 -- [Port] 0-based like upstream
    if is_multiline then
        line_visible_n0, line_visible_n1 = ImGui.CalcClipRectVisibleItemsY(clip_rect, draw_pos, g.FontSize)
    end

    -- Build line index for easy data access (makes code below simpler and faster)
    local line_index = g.InputTextLineIndex
    line_index.Offsets:resize(0)
    local line_count = 1
    if is_multiline then
        -- If scrolling is expected to change build full index.
        -- FIXME-OPT: Could append to index when new value of line_visible_n1 becomes bigger, see second call to CalcClipRectVisibleItemsY() below.
        local will_scroll_y = state and ((state.CursorFollow and render_cursor) or (state.CursorCenterY and (render_cursor or render_selection)))
        local out_buf_end
        line_count, out_buf_end = InputTextLineIndexBuild(flags, line_index, buf_display, buf_display_end, wrap_width, will_scroll_y and INT_MAX or (line_visible_n1 + 1), buf_display_end == nil)
        if buf_display_end == nil then
            buf_display_end = out_buf_end
        end
    end
    --- @cast buf_display_end int
    line_index.EndOffset = buf_display_end - 1
    line_visible_n1 = ImMin(line_visible_n1, line_count)

    -- Store text height (we don't need width)
    local text_size_y = line_count * g.FontSize
    -- ImGui.GetForegroundDrawList():AddRect(draw_pos + ImVec2(0, line_visible_n0 * g.FontSize), draw_pos + ImVec2(frame_size.x, line_visible_n1 * g.FontSize), IM_COL32(255, 0, 0, 255))

    -- Calculate blinking cursor position
    --- @cast buf_display_end int
    local cursor_offset = (render_cursor and state) and InputTextLineIndexGetPosOffset(g, state, line_index, buf_display, buf_display_end, state.Stb.cursor) or ImVec2(0.0, 0.0)
    local draw_scroll = ImVec2()

    -- Render text. We currently only render selection when the widget is active or while scrolling.
    local text_col = ImGui.GetColorU32(is_displaying_hint and ImGuiCol.TextDisabled or ImGuiCol.Text)
    if render_cursor or render_selection then
        -- Render text (with cursor and selection)
        -- This is going to be messy. We need to:
        -- - Display the text (this alone can be more easily clipped)
        -- - Handle scrolling, highlight selection, display cursor (those all requires some form of 1d->2d cursor position calculation)
        -- - Measure text height (for scrollbar)
        -- We are attempting to do most of that in **one main pass** to minimize the computation cost (non-negligible for large amount of text) + 2nd pass for selection rendering (we could merge them by an extra refactoring effort)
        -- FIXME: This should occur on buf_display but we'd need to maintain cursor/select_start/select_end for UTF-8.
        IM_ASSERT(state ~= nil)
        state.LineCount = line_count

        -- Scroll
        local new_scroll_y = scroll_y
        if render_cursor and state.CursorFollow then
            -- Horizontal scroll in chunks of quarter width
            if bit32.band(flags, ImGuiInputTextFlags.NoHorizontalScroll) == 0 then
                local scroll_increment_x = inner_size_x * 0.25
                local visible_width = inner_size_x - style.FramePadding.x
                if cursor_offset.x < state.Scroll.x then
                    state.Scroll.x = IM_TRUNC(ImMax(0.0, cursor_offset.x - scroll_increment_x))
                elseif cursor_offset.x - visible_width >= state.Scroll.x then
                    state.Scroll.x = IM_TRUNC(cursor_offset.x - visible_width + scroll_increment_x)
                end
            else
                state.Scroll.x = 0.0
            end

            -- Vertical scroll
            if is_multiline then
                -- Test if cursor is vertically visible
                if cursor_offset.y - g.FontSize < scroll_y then
                    new_scroll_y = ImMax(0.0, cursor_offset.y - g.FontSize)
                elseif cursor_offset.y - (inner_size_y - style.FramePadding.y * 2.0) >= scroll_y then
                    new_scroll_y = cursor_offset.y - inner_size_y + style.FramePadding.y * 2.0
                end
            end
            state.CursorFollow = false
        end
        if state.CursorCenterY then
            if is_multiline then
                new_scroll_y = cursor_offset.y - g.FontSize - (inner_size_y * 0.5 - style.FramePadding.y)
            end
            state.CursorCenterY = false
            render_cursor = false
        end
        if new_scroll_y ~= scroll_y then
            local scroll_max_y = ImMax((text_size_y + style.FramePadding.y * 2.0) - inner_size_y, 0.0)
            scroll_y = ImClamp(new_scroll_y, 0.0, scroll_max_y)
            draw_pos.y = draw_pos.y + (draw_window.Scroll.y - scroll_y) -- Manipulate cursor pos immediately avoid a frame of lag
            draw_window.Scroll.y = scroll_y
            line_visible_n0, line_visible_n1 = ImGui.CalcClipRectVisibleItemsY(clip_rect, draw_pos, g.FontSize)
            line_visible_n1 = ImMin(line_visible_n1, line_count)
        end

        -- Draw selection
        draw_scroll.x = state.Scroll.x
        if render_selection then
            local bg_color = ImGui.GetColorU32(ImGuiCol.TextSelectedBg, render_cursor and 1.0 or 0.6) -- FIXME: current code flow mandate that render_cursor is always true here, we are leaving the transparent one for tests.
            local bg_offy_up = is_multiline and 0.0 or -1.0 -- FIXME-DPI: those offsets should be part of the style? they don't play so well with multi-line selection.
            local bg_offy_dn = is_multiline and 0.0 or 2.0
            local bg_eol_width = IM_TRUNC(g.FontBaked:GetCharAdvance(32) * 0.50) -- So we can see selected empty lines

            local text_selected_begin = ImMin(state.Stb.select_start, state.Stb.select_end)
            local text_selected_end = ImMax(state.Stb.select_start, state.Stb.select_end)
            for line_n = line_visible_n0, line_visible_n1 - 1 do
                repeat
                local p = line_index:get_line_begin(1, line_n)
                local p_eol = line_index:get_line_end(1, line_n)
                local p_eol_is_wrap = (p_eol < buf_display_end and buf_display[p_eol] ~= 10)
                if p_eol_is_wrap then
                    p_eol = p_eol + 1
                end
                local line_selected_begin = (text_selected_begin > p) and text_selected_begin or p
                local line_selected_end = (text_selected_end < p_eol) and text_selected_end or p_eol

                local rect_width = 0.0
                if line_selected_begin < line_selected_end then
                    rect_width = rect_width + ImGui.CalcTextSizeEx(buf_display, line_selected_begin, line_selected_end).x
                end
                if text_selected_begin <= p_eol and text_selected_end > p_eol and not p_eol_is_wrap then
                    rect_width = rect_width + bg_eol_width -- So we can see selected empty lines
                end
                if rect_width == 0.0 then
                    break
                end

                local rect = ImRect()
                rect.Min.x = draw_pos.x - draw_scroll.x + ImGui.CalcTextSizeEx(buf_display, p, line_selected_begin).x
                rect.Min.y = draw_pos.y - draw_scroll.y + line_n * g.FontSize
                rect.Max.x = rect.Min.x + rect_width
                rect.Max.y = rect.Min.y + bg_offy_dn + g.FontSize
                rect.Min.y = rect.Min.y + bg_offy_up
                rect:ClipWith(clip_rect)
                draw_window.DrawList:AddRectFilled(rect.Min, rect.Max, bg_color)

                until true
            end
        end
    end

    -- Find render position for right alignment (single-line only)
    if g.ActiveId ~= id and bit32.band(flags, ImGuiInputTextFlags.ElideLeft) ~= 0 and not render_cursor and not render_selection then
        draw_pos.x = ImMin(draw_pos.x, frame_bb.Max.x - ImGui.CalcTextSize(buf_display, nil).x - style.FramePadding.x)
    end
    -- draw_scroll.x = state.Scroll.x -- Preserve scroll when inactive?

    -- Render text
    if (is_multiline or (buf_display_end - 1) < buf_display_max_length) and bit32.band(text_col, IM_COL32_A_MASK) ~= 0 and line_visible_n0 < line_visible_n1 then
        g.Font:RenderText(draw_window.DrawList, g.FontSize,
        draw_pos - draw_scroll + ImVec2(0.0, line_visible_n0 * g.FontSize),
        text_col, clip_rect:AsVec4(),
        buf_display,
        line_index:get_line_begin(1, line_visible_n0),
        line_index:get_line_end(1, line_visible_n1 - 1),
        wrap_width, bit32.bor(ImDrawTextFlags.WrapKeepBlanks, ImDrawTextFlags.CpuFineClip))
    end

    -- Render blinking cursor
    if render_cursor then
        state.CursorAnim = state.CursorAnim + io.DeltaTime
        local cursor_is_visible = (not g.IO.ConfigInputTextCursorBlink) or (state.CursorAnim <= 0.0) or (ImFmod(state.CursorAnim, 1.20) <= 0.80)

        local cursor_screen_pos = ImTrunc(draw_pos + cursor_offset - draw_scroll)
        local cursor_screen_rect = ImRect(cursor_screen_pos.x, cursor_screen_pos.y - g.FontSize + 1.0, cursor_screen_pos.x + 1.0, cursor_screen_pos.y - 1.0)

        if cursor_is_visible and cursor_screen_rect:Overlaps(clip_rect) then
            draw_window.DrawList:AddLineV(cursor_screen_rect.Min.x, cursor_screen_rect.Min.y, cursor_screen_rect.Max.y, ImGui.GetColorU32(ImGuiCol.InputTextCursor), style.InputTextCursorSize, ImDrawFlags.StrokeInside)
        end

        -- Notify OS of text input position for advanced IME (-1 x offset so that Windows IME can cover our cursor. Bit of an extra nicety.)
        -- This is required for some backends (SDL3) to start emitting character/text inputs.
        -- As per #6341, make sure we don't set that on the deactivating frame.
        if not is_readonly and g.ActiveId == id then
            local ime_data = g.PlatformImeData -- (this is a public struct, passed to io.Platform_SetImeDataFn() handler)
            ime_data.WantVisible = true
            ime_data.WantTextInput = true
            ImVec2_Copy(ime_data.InputPos, ImVec2(cursor_screen_pos.x - 1.0, cursor_screen_pos.y - g.FontSize))
            ime_data.InputLineHeight = g.FontSize
            ime_data.ViewportId = window.Viewport.ID
            -- [Port] selection for backends (stb positions are 1-based in this port)
            if state.Stb and state:HasSelection() then
                ime_data.SelectedText = ImGui._ByteArrayToString(state.TextA.Data, ImMin(state.Stb.select_start, state.Stb.select_end), ImMax(state.Stb.select_start, state.Stb.select_end))
            end
        end
    end

    if is_password and not is_displaying_hint then
        ImGui.PopPasswordFont()
    end

    if is_multiline then
        -- For focus requests to work on our multiline we need to ensure our child ItemAdd() call specifies the ImGuiItemFlags.Inputable (see #4761, #7870)...
        ImGui.Dummy(ImVec2(0.0, text_size_y + style.FramePadding.y))
        g.NextItemData.ItemFlagsSet = bit32.bor(g.NextItemData.ItemFlagsSet, ImGuiItemFlags.Inputable, ImGuiItemFlags.NoTabStop)
        ImGui.EndChild()
        item_data_backup.StatusFlags = bit32.bor(item_data_backup.StatusFlags, bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredWindow))

        -- ...and then we need to undo the group overriding last item data, which gets a bit messy as EndGroup() tries to forward scrollbar being active...
        -- FIXME: This quite messy/tricky, should attempt to get rid of the child window.
        ImGui.EndGroup()
        if g.LastItemData.ID == 0 or g.LastItemData.ID ~= ImGui.GetWindowScrollbarID(draw_window, ImGuiAxis.Y) then
            g.LastItemData.ID = id
            g.LastItemData.ItemFlags = item_data_backup.ItemFlags
            g.LastItemData.StatusFlags = item_data_backup.StatusFlags
        end
    end

    if state and is_readonly then
        state.TextSrc = nil
    end

    -- Log as text
    if g.LogEnabled and (not is_password or is_displaying_hint) then
        ImGui.LogSetNextTextDecoration("{", "}")
        ImGui.LogRenderedText(draw_pos, ImGui._ByteArrayToString(buf_display, 1, buf_display_end))
    end

    if label_size_x > 0.0 then
        ImGui.RenderText(ImVec2(frame_bb.Max.x + style.ItemInnerSpacing.x, frame_bb.Min.y + style.FramePadding.y), label, 1, label_end, false)
    end

    if state and validated then
        state.ValidatedThisFrame = true
    end
    if value_changed then
        ImGui.MarkItemEdited(id)
    end

    if bit32.band(flags, ImGuiInputTextFlags.EnterReturnsTrue) ~= 0 then
        return validated
    else
        return value_changed
    end
end

--- @param label      string
--- @param hint       char[]
--- @param buf        char[]
--- @param buf_size   size_t
--- @param flags?     ImGuiInputTextFlags
--- @param callback?  ImGuiInputTextCallback
--- @param user_data? any
function ImGui.InputTextWithHint(label, hint, buf, buf_size, flags, callback, user_data)
    if flags == nil then flags = 0 end

    IM_ASSERT(bit32.band(flags, ImGuiInputTextFlags.Multiline) == 0) -- call InputTextMultiline() or  InputTextEx() manually if you need multi-line + hint.
    return ImGui.InputTextEx(label, hint, buf, buf_size, LAYOUT_ZERO_SIZE, flags, callback, user_data) -- [Luau] shared read-only ImVec2(0, 0)
end

-- [Luau] stb positions/undo indices are 1-based in this port (displayed as-is)
--- @param state ImGuiInputTextState
function ImGui.DebugNodeInputTextState(state)
    local g = GImGui
    local stb_state = state.Stb
    local undo_state = stb_state.undostate
    ImGui.Text("ID: 0x%08X, ActiveID: 0x%08X", state.ID, g.ActiveId)
    ImGui.DebugLocateItemOnHover(state.ID)
    local wrap_dir = ""
    if bit32.band(state.Flags, ImGuiInputTextFlags.WordWrap) ~= 0 then
        if state.LastMoveDirectionLR == ImGuiDir.Left then wrap_dir = " (L)" else wrap_dir = " (R)" end
    end
    ImGui.Text("TextLen: %d, Cursor: %d%s, Selection: %d..%d", state.TextLen, stb_state.cursor, wrap_dir, stb_state.select_start, stb_state.select_end)
    ImGui.Text("BufCapacity: %d, LineCount: %d", state.BufCapacity, state.LineCount)
    ImGui.Text("(Internal Buffer: TextA Size: %d, Capacity: %d)", state.TextA.Size, state.TextA.Capacity)
    ImGui.Text("has_preferred_x: %d (%.2f)", stb_state.has_preferred_x and 1 or 0, stb_state.preferred_x)
    ImGui.Text("undo_point: %d, redo_point: %d, undo_char_point: %d, redo_char_point: %d", undo_state.undo_point, undo_state.redo_point, undo_state.undo_char_point, undo_state.redo_char_point)
    if ImGui.BeginChild("undopoints", ImVec2(0.0, ImGui.GetTextLineHeight() * 10), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeY)) then -- Visualize undo state
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
        for n = 1, IMSTB_TEXTEDIT_UNDOSTATECOUNT do
            local undo_rec = undo_state.undo_rec[n]
            local undo_rec_type = (n < undo_state.undo_point) and "u" or ((n >= undo_state.redo_point) and "r" or " ")
            if undo_rec_type == " " then
                ImGui.BeginDisabled()
            end
            local buf_preview_len = (undo_rec_type ~= " " and undo_rec.char_storage ~= -1) and undo_rec.insert_length or 0
            local buf_preview_str = ""
            if buf_preview_len > 0 then
                buf_preview_str = string.char(unpack(undo_state.undo_char, undo_rec.char_storage, undo_rec.char_storage + buf_preview_len - 1))
            end
            ImGui.Text("%s [%02d] where %03d, insert %03d, delete %03d, char_storage %03d \"%s\"",
                undo_rec_type, n, undo_rec.where, undo_rec.insert_length, undo_rec.delete_length, undo_rec.char_storage, buf_preview_str)
            if undo_rec_type == " " then
                ImGui.EndDisabled()
            end
        end
        ImGui.PopStyleVar()
    end
    ImGui.EndChild()
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: ColorEdit, ColorPicker, ColorButton, etc.
-------------------------------------------------------------------------------
-- - ColorEdit3()
-- - ColorEdit4()
-- - ColorPicker3()
-- - RenderColorRectWithAlphaCheckerboard() [Internal]
-- - ColorPicker4()
-- - ColorButton()
-- - ColorTooltip() [Internal]
-- - ColorEditOptionsPopup() [Internal]
-- - ColorPickerOptionsPopup() [Internal]
-------------------------------------------------------------------------------

--- @param col float[]
--- @param H   float
--- @return float
local function ColorEditRestoreH(col, H)
    local g = GImGui
    IM_ASSERT(g.ColorEditCurrentID ~= 0)
    if g.ColorEditSavedID ~= g.ColorEditCurrentID or g.ColorEditSavedColor ~= ImGui.ColorConvertFloat4ToU32(ImVec4(col[1], col[2], col[3], 0)) then
        return H
    end
    H = g.ColorEditSavedHue
    return H
end

-- ColorEdit supports RGB and HSV inputs. In case of RGB input resulting color may have undefined hue and/or saturation.
-- Since widget displays both RGB and HSV values we must preserve hue and saturation to prevent these values resetting.
--- @param col float[]
--- @param H float
--- @param S float
--- @param V float
--- @return float, float, float
local function ColorEditRestoreHS(col, H, S, V)
    local g = GImGui
    IM_ASSERT(g.ColorEditCurrentID ~= 0)

    if g.ColorEditSavedID ~= g.ColorEditCurrentID or g.ColorEditSavedColor ~= ImGui.ColorConvertFloat4ToU32(ImVec4(col[1], col[2], col[3], 0)) then
        return H, S, V
    end

    -- When S == 0, H is undefined.
    -- When H == 1 it wraps around to 0.
    if S == 0.0 or (H == 0.0 and g.ColorEditSavedHue == 1) then
        H = g.ColorEditSavedHue
    end

    -- When V == 0, S is undefined.
    if V == 0.0 then
        S = g.ColorEditSavedSat
    end

    return H, S, V
end

do --[[ColorEdit4]]

local ids = { "##X", "##Y", "##Z", "##W" }
local fmt_table_int = {
    {   "%3d",   "%3d",   "%3d",   "%3d" }, -- Short display
    { "R:%3d", "G:%3d", "B:%3d", "A:%3d" }, -- Long display for RGBA
    { "H:%3d", "S:%3d", "V:%3d", "A:%3d" }  -- Long display for HSVA
}
local fmt_table_float = {
    {   "%0.3f",   "%0.3f",   "%0.3f",   "%0.3f" }, -- Short display
    { "R:%0.3f", "G:%0.3f", "B:%0.3f", "A:%0.3f" }, -- Long display for RGBA
    { "H:%0.3f", "S:%0.3f", "V:%0.3f", "A:%0.3f" }  -- Long display for HSVA
}

-- Edit colors components (each component in 0.0f..1.0f range).
-- See enum ImGuiColorEditFlags_ for available options. e.g. Only access 3 floats if ImGuiColorEditFlags.NoAlpha flag is set.
-- With typical options: Left-click on color square to open color picker. Right-click to open option menu. Ctrl+Click over input fields to edit them and TAB to go to next item.
--- @param label string
--- @param col   float[]
--- @param flags ImGuiColorEditFlags
@native
function ImGui.ColorEdit4(label, col, flags)
    if flags == nil then flags = 0 end
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local style = g.Style
    local square_sz = ImGui.GetFrameHeight()
    local label_display_end = ImGui.FindRenderedTextEnd(label)
    local w_full = ImGui.CalcItemWidth()
    g.NextItemData:ClearFlags()

    -- [Luau] Fast path for a row that is entirely clipped (e.g. long lists such as Style Editor > Colors): nothing
    -- inside would draw, be hovered or receive input, so only reproduce the layout (same group size, baseline and
    -- last item rect as the full path). Not taken while anything could depend on the inner items: an active item
    -- or popup, keyboard navigation, logging, or the ID debug hook.
    if label_display_end == 1 and bit32.band(flags, bit32.bor(ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.NoSmallPreview)) == 0
        and g.ActiveId == 0 and g.OpenPopupStack.Size == 0 and not g.NavCursorVisible and not g.NavAnyRequest
        and not g.LogEnabled and g.DebugHookIdInfoId == 0 then
        local w_button = square_sz + style.ItemInnerSpacing.x
        local w = ImMax(w_full - w_button, 1.0) + w_button
        local p = window.DC.CursorPos
        local cr = window.ClipRect
        if p.y + square_sz < cr.Min.y or p.y > cr.Max.y or p.x + w < cr.Min.x or p.x > cr.Max.x then
            ImGui.BeginGroup()
            local bb = ImRect(p.x, p.y, p.x + w, p.y + square_sz)
            ImGui.ItemSize(ImVec2(w, square_sz), style.FramePadding.y)
            ImGui.ItemAdd(bb, 0)
            ImGui.EndGroup()
            return false
        end
    end

    ImGui.BeginGroup()
    ImGui.PushID(label)
    local set_current_color_edit_id = (g.ColorEditCurrentID == 0)
    if set_current_color_edit_id then
        g.ColorEditCurrentID = window.IDStack:back()
    end

    -- If we're not showing any slider there's no point in doing any HSV conversions
    local flags_untouched = flags
    if bit32.band(flags, ImGuiColorEditFlags.NoInputs) ~= 0 then
        flags = bit32.bor(bit32.band(flags, bit32.bnot(ImGuiColorEditFlags.DisplayMask_)), ImGuiColorEditFlags.DisplayRGB, ImGuiColorEditFlags.NoOptions)
    end

    -- Context menu: display and modify options (before defaults are applied)
    if bit32.band(flags, ImGuiColorEditFlags.NoOptions) == 0 then
        ImGui.ColorEditOptionsPopup(col, flags)
    end

    -- Read stored options
    if bit32.band(flags, ImGuiColorEditFlags.DisplayMask_) == 0 then
        flags = bit32.bor(flags, bit32.band(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.DisplayMask_))
    end
    if bit32.band(flags, ImGuiColorEditFlags.DataTypeMask_) == 0 then
        flags = bit32.bor(flags, bit32.band(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.DataTypeMask_))
    end
    if bit32.band(flags, ImGuiColorEditFlags.PickerMask_) == 0 then
        flags = bit32.bor(flags, bit32.band(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.PickerMask_))
    end
    if bit32.band(flags, ImGuiColorEditFlags.InputMask_) == 0 then
        flags = bit32.bor(flags, bit32.band(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.InputMask_))
    end
    flags = bit32.bor(flags, bit32.band(g.IO.ConfigColorEditFlags, bit32.bnot(bit32.bor(ImGuiColorEditFlags.DisplayMask_, ImGuiColorEditFlags.DataTypeMask_, ImGuiColorEditFlags.PickerMask_, ImGuiColorEditFlags.InputMask_))))
    IM_ASSERT(ImIsPowerOfTwo(bit32.band(flags, ImGuiColorEditFlags.DisplayMask_))) -- Check that only 1 is selected
    IM_ASSERT(ImIsPowerOfTwo(bit32.band(flags, ImGuiColorEditFlags.InputMask_)))   -- Check that only 1 is selected

    local alpha = bit32.band(flags, ImGuiColorEditFlags.NoAlpha) == 0
    local hdr = bit32.band(flags, ImGuiColorEditFlags.HDR) ~= 0
    local components = alpha and 4 or 3
    local w_button = (bit32.band(flags, ImGuiColorEditFlags.NoSmallPreview) ~= 0) and 0.0 or (square_sz + style.ItemInnerSpacing.x)
    local w_inputs = ImMax(w_full - w_button, 1.0)
    w_full = w_inputs + w_button

    -- Convert to the formats we need
    local f = { col[1], col[2], col[3], alpha and col[4] or 1.0 }
    if bit32.band(flags, ImGuiColorEditFlags.InputHSV) ~= 0 and bit32.band(flags, ImGuiColorEditFlags.DisplayRGB) ~= 0 then
        f[1], f[2], f[3] = ImGui.ColorConvertHSVtoRGB(f[1], f[2], f[3])
    elseif bit32.band(flags, ImGuiColorEditFlags.InputRGB) ~= 0 and bit32.band(flags, ImGuiColorEditFlags.DisplayHSV) ~= 0 then
        -- Hue is lost when converting from grayscale rgb (saturation=0). Restore it.
        f[1], f[2], f[3] = ImGui.ColorConvertRGBtoHSV(f[1], f[2], f[3])
        f[1], f[2], f[3] = ColorEditRestoreHS(col, f[1], f[2], f[3])
    end
    local i = { IM_F32_TO_INT8_UNBOUND(f[1]), IM_F32_TO_INT8_UNBOUND(f[2]), IM_F32_TO_INT8_UNBOUND(f[3]), IM_F32_TO_INT8_UNBOUND(f[4]) }

    local value_changed = false
    local value_changed_as_float = false

    local pos = ImVec2()
    ImVec2_Copy(pos, window.DC.CursorPos)
    local inputs_offset_x = (style.ColorButtonPosition == ImGuiDir.Left) and w_button or 0.0
    window.DC.CursorPos.x = pos.x + inputs_offset_x

    if bit32.band(flags, bit32.bor(ImGuiColorEditFlags.DisplayRGB, ImGuiColorEditFlags.DisplayHSV)) ~= 0 and bit32.band(flags, ImGuiColorEditFlags.NoInputs) == 0 then
        -- RGB/HSV 0..255 Sliders
        local w_items = w_inputs - style.ItemInnerSpacing.x * (components - 1)
        local w_per_component = IM_TRUNC(w_items / components)
        local draw_color_marker = bit32.band(flags, bit32.bor(ImGuiColorEditFlags.DisplayHSV, ImGuiColorEditFlags.NoColorMarkers)) == 0
        local hide_prefix = draw_color_marker or (w_per_component <= ImGui.CalcTextSize((bit32.band(flags, ImGuiColorEditFlags.Float) ~= 0) and "M:0.000" or "M:000").x)

        local fmt_idx
        if hide_prefix then
            fmt_idx = 1
        elseif bit32.band(flags, ImGuiColorEditFlags.DisplayHSV) ~= 0 then
            fmt_idx = 3
        else
            fmt_idx = 2
        end
        local drag_flags = draw_color_marker and ImGuiSliderFlags.ColorMarkers or ImGuiSliderFlags.None

        local prev_split = 0.0
        for n = 1, components do
            if n > 1 then
                ImGui.SameLine(0, style.ItemInnerSpacing.x)
            end
            local next_split = IM_TRUNC(w_items * n / components)
            ImGui.SetNextItemWidth(ImMax(next_split - prev_split, 1.0))
            prev_split = next_split
            if draw_color_marker then
                ImGui.SetNextItemColorMarker(GDefaultRgbaColorMarkers[n])
            end

            -- FIXME: When ImGuiColorEditFlags_HDR flag is passed HS values snap in weird ways when SV values go below 0.
            if bit32.band(flags, ImGuiColorEditFlags.Float) ~= 0 then
                local changed
                f[n], changed = ImGui.DragFloat(ids[n], f[n], 1.0 / 255.0, 0.0, hdr and 0.0 or 1.0, fmt_table_float[fmt_idx][n], drag_flags)
                value_changed = value_changed or changed
                value_changed_as_float = value_changed_as_float or value_changed
            else
                local changed
                i[n], changed = ImGui.DragInt(ids[n], i[n], 1.0, 0, hdr and 0 or 255, fmt_table_int[fmt_idx][n], drag_flags)
                value_changed = value_changed or changed
            end

            if bit32.band(flags, ImGuiColorEditFlags.NoOptions) == 0 then
                ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
            end
        end
    elseif bit32.band(flags, ImGuiColorEditFlags.DisplayHex) ~= 0 and bit32.band(flags, ImGuiColorEditFlags.NoInputs) == 0 then
        -- RGB Hexadecimal Input
        -- [Port] TODO: resolve sprintf, sscanf requirement. currently this section creates a lot of temp tables and strings...
        local buf, buf_size = nil, 64
        if alpha then
            local str = ImFormatString("#%02X%02X%02X%02X", ImClamp(i[1], 0, 255), ImClamp(i[2], 0, 255), ImClamp(i[3], 0, 255), ImClamp(i[4], 0, 255))
            buf = { string.byte(str, 1, #str) }
            buf[#buf + 1] = 0
        else
            local str = ImFormatString("#%02X%02X%02X", ImClamp(i[1], 0, 255), ImClamp(i[2], 0, 255), ImClamp(i[3], 0, 255))
            buf = { string.byte(str, 1, #str) }
            buf[#buf + 1] = 0
        end
        ImGui.SetNextItemWidth(w_inputs)

        if ImGui.InputText("##Text", buf, buf_size, ImGuiInputTextFlags.CharsUppercase) then
            value_changed = true
            local p = 1
            while buf[p] == 35 or ImCharIsBlankA(buf[p]) do
                p = p + 1
            end
            i[1], i[2], i[3] = 0, 0, 0
            i[4] = 0xFF -- alpha default to 255 is not parsed by scanf (e.g. inputting #FFFFFF omitting alpha)

            local r
            if alpha then
                r = ImStd.sscanf(buf, p, "%02X%02X%02X%02X", i) -- Treat at unsigned (%X is unsigned)
            else
                r = ImStd.sscanf(buf, p, "%02X%02X%02X", i)
            end
            -- IM_UNUSED(r) -- Fixes C6031: Return value ignored: 'sscanf'.
        end

        if bit32.band(flags, ImGuiColorEditFlags.NoOptions) == 0 then
            ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
        end
    end

    local picker_active_window = nil
    if bit32.band(flags, ImGuiColorEditFlags.NoSmallPreview) == 0 then
        local button_offset_x = (bit32.band(flags, ImGuiColorEditFlags.NoInputs) ~= 0 or style.ColorButtonPosition == ImGuiDir.Left) and 0.0 or (w_inputs + style.ItemInnerSpacing.x)
        ImVec2_Copy(window.DC.CursorPos, ImVec2(pos.x + button_offset_x, pos.y))

        local col_v4 = ImVec4(col[1], col[2], col[3], alpha and col[4] or 1.0)
        if ImGui.ColorButton("##ColorButton", col_v4, flags) then
            if bit32.band(flags, ImGuiColorEditFlags.NoPicker) == 0 then
                -- Store current color and open a picker
                ImVec4_Copy(g.ColorPickerRef, col_v4)
                ImGui.OpenPopup("picker")
                ImGui.SetNextWindowPos(g.LastItemData.Rect:GetBL() + ImVec2(0.0, style.ItemSpacing.y))
            end
        end
        if bit32.band(flags, ImGuiColorEditFlags.NoOptions) == 0 then
            ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
        end

        if ImGui.BeginPopup("picker") then
            if g.CurrentWindow.BeginCount == 1 then
                picker_active_window = g.CurrentWindow
                if label ~= "" and label_display_end > 1 then
                    ImGui.TextEx(label, label_display_end)
                    ImGui.Spacing()
                end
                local picker_flags_to_forward = bit32.bor(ImGuiColorEditFlags.DataTypeMask_, ImGuiColorEditFlags.PickerMask_, ImGuiColorEditFlags.InputMask_, ImGuiColorEditFlags.HDR, ImGuiColorEditFlags.NoAlpha, ImGuiColorEditFlags.AlphaBar)
                local picker_flags = bit32.bor(bit32.band(flags_untouched, picker_flags_to_forward), ImGuiColorEditFlags.DisplayMask_, ImGuiColorEditFlags.NoLabel, ImGuiColorEditFlags.AlphaPreviewHalf)
                ImGui.SetNextItemWidth(square_sz * 12.0) -- Use 256 + bar sizes?
                value_changed = value_changed or ImGui.ColorPicker4("##picker", col, picker_flags, g.ColorPickerRef)
            end
            ImGui.EndPopup()
        end
    end

    if label ~= "" and label_display_end > 1 and bit32.band(flags, ImGuiColorEditFlags.NoLabel) == 0 then
        -- Position not necessarily next to last submitted button (e.g. if style.ColorButtonPosition == ImGuiDir_Left),
        -- but we need to use SameLine() to setup baseline correctly. Might want to refactor SameLine() to simplify this.
        ImGui.SameLine(0.0, style.ItemInnerSpacing.x)
        window.DC.CursorPos.x = pos.x + ((bit32.band(flags, ImGuiColorEditFlags.NoInputs) ~= 0) and w_button or (w_full + style.ItemInnerSpacing.x))
        ImGui.TextEx(label, label_display_end)
    end

    -- Convert back
    if value_changed and picker_active_window == nil then
        if not value_changed_as_float then
            for n = 1, 4 do
                f[n] = i[n] / 255.0
            end
        end
        if bit32.band(flags, ImGuiColorEditFlags.DisplayHSV) ~= 0 and bit32.band(flags, ImGuiColorEditFlags.InputRGB) ~= 0 then
            g.ColorEditSavedHue = f[1]
            g.ColorEditSavedSat = f[2]
            f[1], f[2], f[3] = ImGui.ColorConvertHSVtoRGB(f[1], f[2], f[3])
            g.ColorEditSavedID = g.ColorEditCurrentID
            g.ColorEditSavedColor = ImGui.ColorConvertFloat4ToU32(ImVec4(f[1], f[2], f[3], 0))
        end
        if bit32.band(flags, ImGuiColorEditFlags.DisplayRGB) ~= 0 and bit32.band(flags, ImGuiColorEditFlags.InputHSV) ~= 0 then
            f[1], f[2], f[3] = ImGui.ColorConvertRGBtoHSV(f[1], f[2], f[3])
        end

        col[1] = f[1]
        col[2] = f[2]
        col[3] = f[3]
        if alpha then
            col[4] = f[4]
        end
    end

    if set_current_color_edit_id then
        g.ColorEditCurrentID = 0
    end
    ImGui.PopID()
    ImGui.EndGroup()

    -- Drag and Drop Target
    -- NB: The flag test is merely an optional micro-optimization, BeginDragDropTarget() does the same test.
    if bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredRect) ~= 0 and bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.ReadOnly) == 0 and bit32.band(flags, ImGuiColorEditFlags.NoDragDrop) == 0 and ImGui.BeginDragDropTarget() then
        local accepted_drag_drop = false
        local payload = ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_3F)
        if payload then
            local d = payload.Data
            col[1], col[2], col[3] = d[1], d[2], d[3] -- Preserve alpha if any
            value_changed = true; accepted_drag_drop = true
        end
        payload = ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_4F)
        if payload then
            local d = payload.Data
            for i = 1, components do col[i] = d[i] end
            value_changed = true; accepted_drag_drop = true
        end

        -- Drag-drop payloads are always RGB
        if accepted_drag_drop and bit32.band(flags, ImGuiColorEditFlags.InputHSV) ~= 0 then
            col[1], col[2], col[3] = ImGui.ColorConvertRGBtoHSV(col[1], col[2], col[3])
        end
        ImGui.EndDragDropTarget()
    end

    -- When picker is being actively used, use its active id so IsItemActive() will function on ColorEdit4().
    if picker_active_window and g.ActiveId ~= 0 and g.ActiveIdWindow == picker_active_window then
        g.LastItemData.ID = g.ActiveId
    end

    if value_changed and g.LastItemData.ID ~= 0 then -- In case of ID collision, the second EndGroup() won't catch g.ActiveId
        ImGui.MarkItemEdited(g.LastItemData.ID)
    end

    return value_changed
end

end

--- @param label  string
--- @param col    [float, float, float]
--- @param flags? ImGuiColorEditFlags
function ImGui.ColorEdit3(label, col, flags)
    if flags == nil then flags = 0 end
    if flags == nil then flags = 0 end

    return ImGui.ColorEdit4(label, col, bit32.bor(flags, ImGuiColorEditFlags.NoAlpha))
end

-- [Port] `col` mutated in place, returns value_changed
function ImGui.ColorPicker3(label, col, flags)
    if flags == nil then flags = 0 end
    local col4 = { col[1], col[2], col[3], 1.0 }
    if not ImGui.ColorPicker4(label, col4, bit32.bor(flags or 0, ImGuiColorEditFlags.NoAlpha)) then
        return false
    end
    col[1] = col4[1]; col[2] = col4[2]; col[3] = col4[3]
    return true
end

-- This allowed passing 0 to set default, whereas NewFrame() will assert if one of missing. Abide to old logic.
function ImGui.SetColorEditOptions(flags)
    local g = GImGui
    local def = ImGuiColorEditFlags.DefaultOptions_
    for _, mask in ipairs({ ImGuiColorEditFlags.DisplayMask_, ImGuiColorEditFlags.DataTypeMask_, ImGuiColorEditFlags.PickerMask_, ImGuiColorEditFlags.InputMask_ }) do
        if bit32.band(flags, mask) == 0 then
            flags = bit32.bor(flags, bit32.band(def, mask))
        end
    end
    g.IO.ConfigColorEditFlags = flags
end

-- Helper for ColorPicker4()
--- @param draw_list ImDrawList
--- @param pos       ImVec2
--- @param half_sz   ImVec2
--- @param bar_w     float
--- @param alpha     float
local function RenderArrowsForVerticalBar(draw_list, pos, half_sz, bar_w, alpha)
    local alpha8 = IM_F32_TO_INT8_SAT(alpha)
    ImGui.RenderArrowPointingAt(draw_list, ImVec2(pos.x + half_sz.x + 1,         pos.y), ImVec2(half_sz.x + 2, half_sz.y + 1), ImGuiDir.Right, IM_COL32(0, 0, 0, alpha8))
    ImGui.RenderArrowPointingAt(draw_list, ImVec2(pos.x + half_sz.x,             pos.y), half_sz,                              ImGuiDir.Right, IM_COL32(255, 255, 255, alpha8))
    ImGui.RenderArrowPointingAt(draw_list, ImVec2(pos.x + bar_w - half_sz.x - 1, pos.y), ImVec2(half_sz.x + 2, half_sz.y + 1), ImGuiDir.Left,  IM_COL32(0, 0, 0, alpha8))
    ImGui.RenderArrowPointingAt(draw_list, ImVec2(pos.x + bar_w - half_sz.x,     pos.y), half_sz,                              ImGuiDir.Left,  IM_COL32(255, 255, 255, alpha8))
end

do --[[ColorPicker4]]

local backup_initial_col = {0, 0, 0, 0}

-- Note: ColorPicker4() only accesses 3 floats if ImGuiColorEditFlags.NoAlpha flag is set.
-- FIXME: we adjust the big color square height based on item width, which may cause a flickering feedback loop (if automatic height makes a vertical scrollbar appears, affecting automatic width..)
-- FIXME: this is trying to be aware of style.Alpha but not fully correct. Also, the color wheel will have overlapping glitches with (style.Alpha < 1.0)
--- @param label    string
--- @param col      float[]
--- @param flags    ImGuiColorEditFlags
--- @param ref_col? float[]
function ImGui.ColorPicker4(label, col, flags, ref_col)
    if flags == nil then flags = 0 end
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local draw_list = window.DrawList
    local g = GImGui
    local style = g.Style
    local io = g.IO

    local width = ImGui.CalcItemWidth()
    local is_readonly = bit32.band(bit32.bor(g.NextItemData.ItemFlagsSet, g.CurrentItemFlags), ImGuiItemFlags.ReadOnly) ~= 0
    g.NextItemData:ClearFlags()

    ImGui.PushID(label)
    local set_current_color_edit_id = (g.ColorEditCurrentID == 0)
    if set_current_color_edit_id then
        g.ColorEditCurrentID = window.IDStack:back()
    end
    ImGui.BeginGroup()

    if bit32.band(flags, ImGuiColorEditFlags.NoSidePreview) == 0 then
        flags = bit32.bor(flags, ImGuiColorEditFlags.NoSmallPreview)
    end

    -- Context menu: display and store options.
    if bit32.band(flags, ImGuiColorEditFlags.NoOptions) == 0 then
        ImGui.ColorPickerOptionsPopup(col, flags)
    end

    -- Read stored options
    if bit32.band(flags, ImGuiColorEditFlags.PickerMask_) == 0 then
        local picker_flags = bit32.band(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.PickerMask_)
        if picker_flags ~= 0 then
            flags = bit32.bor(flags, picker_flags)
        else
            flags = bit32.bor(flags, bit32.band(ImGuiColorEditFlags.DefaultOptions_, ImGuiColorEditFlags.PickerMask_))
        end
    end
    if bit32.band(flags, ImGuiColorEditFlags.InputMask_) == 0 then
        local input_flags = bit32.band(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.InputMask_)
        if input_flags ~= 0 then
            flags = bit32.bor(flags, input_flags)
        else
            flags = bit32.bor(flags, bit32.band(ImGuiColorEditFlags.DefaultOptions_, ImGuiColorEditFlags.InputMask_))
        end
    end
    IM_ASSERT(ImIsPowerOfTwo(bit32.band(flags, ImGuiColorEditFlags.PickerMask_))) -- Check that only 1 is selected
    IM_ASSERT(ImIsPowerOfTwo(bit32.band(flags, ImGuiColorEditFlags.InputMask_)))  -- Check that only 1 is selected
    if bit32.band(flags, ImGuiColorEditFlags.NoOptions) == 0 then
        flags = bit32.bor(flags, bit32.band(g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.AlphaBar))
    end

    -- Setup
    local components = (bit32.band(flags, ImGuiColorEditFlags.NoAlpha) ~= 0) and 3 or 4
    local alpha_bar = (bit32.band(flags, ImGuiColorEditFlags.AlphaBar) ~= 0) and (bit32.band(flags, ImGuiColorEditFlags.NoAlpha) == 0)
    local picker_pos = ImVec2()
    ImVec2_Copy(picker_pos, window.DC.CursorPos)
    local square_sz = ImGui.GetFrameHeight()
    local bars_width = square_sz -- Arbitrary smallish width of Hue/Alpha picking bars
    local sv_picker_size = ImMax(bars_width * 1, width - (alpha_bar and 2 or 1) * (bars_width + style.ItemInnerSpacing.x)) -- Saturation/Value picking box
    local bar0_pos_x = picker_pos.x + sv_picker_size + style.ItemInnerSpacing.x
    local bar1_pos_x = bar0_pos_x + bars_width + style.ItemInnerSpacing.x
    local bars_triangles_half_sz = IM_TRUNC(bars_width * 0.20)

    backup_initial_col[1], backup_initial_col[2], backup_initial_col[3], backup_initial_col[4] = col[1], col[2], col[3], col[4]

    local wheel_thickness = sv_picker_size * 0.08
    local wheel_r_outer = sv_picker_size * 0.50
    local wheel_r_inner = wheel_r_outer - wheel_thickness
    local wheel_center = ImVec2(picker_pos.x + (sv_picker_size + bars_width) * 0.5, picker_pos.y + sv_picker_size * 0.5)

    -- Note: the triangle is displayed rotated with triangle_pa pointing to Hue, but most coordinates stays unrotated for logic.
    local triangle_rotate = bit32.band(flags, ImGuiColorEditFlags.PickerNoRotate) == 0
    local triangle_r = wheel_r_inner - math.floor(sv_picker_size * 0.027)
    local triangle_pa, triangle_pb, triangle_pc
    if triangle_rotate then triangle_pa = ImVec2(       triangle_r,                 0.0) else triangle_pa = ImVec2( triangle_r * 0.866, triangle_r * 0.5) end -- Hue point.
    if triangle_rotate then triangle_pb = ImVec2(triangle_r * -0.5, triangle_r * -0.866) else triangle_pb = ImVec2(                0.0,      -triangle_r) end -- Black point.
    if triangle_rotate then triangle_pc = ImVec2(triangle_r * -0.5, triangle_r *  0.866) else triangle_pc = ImVec2(triangle_r * -0.866, triangle_r * 0.5) end -- White point.

    local H = col[1]; local S = col[2]; local V = col[3]
    local R = col[1]; local G = col[2]; local B = col[3]
    if bit32.band(flags, ImGuiColorEditFlags.InputRGB) ~= 0 then
        -- Hue is lost when converting from grayscale rgb (saturation=0). Restore it.
        H, S, V = ImGui.ColorConvertRGBtoHSV(R, G, B)
        H, S, V = ColorEditRestoreHS(col, H, S, V)
    elseif bit32.band(flags, ImGuiColorEditFlags.InputHSV) ~= 0 then
        R, G, B = ImGui.ColorConvertHSVtoRGB(H, S, V)
    end

    local value_changed = false; local value_changed_h = false; local value_changed_sv = false

    ImGui.PushItemFlag(ImGuiItemFlags.NoNav, true)
    if bit32.band(flags, ImGuiColorEditFlags.PickerHueWheel) ~= 0 then
        -- Hue wheel + SV triangle logic
        ImGui.InvisibleButton("hsv", ImVec2(sv_picker_size + style.ItemInnerSpacing.x + bars_width, sv_picker_size))
        if ImGui.IsItemActive() and not is_readonly then
            local initial_off = g.IO.MouseClickedPos[0] - wheel_center
            local current_off = g.IO.MousePos - wheel_center
            local initial_dist2 = ImLengthSqr(initial_off)

            if initial_dist2 >= (wheel_r_inner - 1) * (wheel_r_inner - 1) and initial_dist2 <= (wheel_r_outer + 1) * (wheel_r_outer + 1) then
                -- Interactive with Hue wheel
                H = ImAtan2(current_off.y, current_off.x) / IM_PI * 0.5
                if H < 0.0 then
                    H = H + 1.0
                end
                value_changed = true
                value_changed_h = true
            end

            local cos_hue_angle = triangle_rotate and ImCos(-H * 2.0 * IM_PI) or 1.0
            local sin_hue_angle = triangle_rotate and ImSin(-H * 2.0 * IM_PI) or 0.0

            if ImStd.ImTriangleContainsPoint(triangle_pa, triangle_pb, triangle_pc, ImRotate(initial_off, cos_hue_angle, sin_hue_angle)) then
                -- Interacting with SV triangle
                local current_off_unrotated = ImRotate(current_off, cos_hue_angle, sin_hue_angle)
                if not ImStd.ImTriangleContainsPoint(triangle_pa, triangle_pb, triangle_pc, current_off_unrotated) then
                    current_off_unrotated = ImStd.ImTriangleClosestPoint(triangle_pa, triangle_pb, triangle_pc, current_off_unrotated)
                end
                local uu, vv, ww
                uu, vv, ww = ImStd.ImTriangleBarycentricCoords(triangle_pa, triangle_pb, triangle_pc, current_off_unrotated)
                V = ImClamp(1.0 - vv, 0.0001, 1.0)
                S = ImClamp(uu / V, 0.0001, 1.0)
                value_changed = true
                value_changed_sv = true
            end
        end

        if bit32.band(flags, ImGuiColorEditFlags.NoOptions) == 0 then
            ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
        end
    elseif bit32.band(flags, ImGuiColorEditFlags.PickerHueBar) ~= 0 then
        -- SV rectangle logic
        ImGui.InvisibleButton("sv", ImVec2(sv_picker_size, sv_picker_size))
        if ImGui.IsItemActive() and not is_readonly then
            S = ImSaturate((io.MousePos.x - picker_pos.x) / ImMax(sv_picker_size - 1, 0.0001))
            V = 1.0 - ImSaturate((io.MousePos.y - picker_pos.y) / ImMax(sv_picker_size - 1, 0.0001))
            H = ColorEditRestoreH(col, H) -- Greatly reduces hue jitter and reset to 0 when hue == 255 and color is rapidly modified using SV square.
            value_changed = true
            value_changed_sv = true
        end

        if bit32.band(flags, ImGuiColorEditFlags.NoOptions) == 0 then
            ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
        end

        -- Hue bar logic
        ImGui.SetCursorScreenPos(ImVec2(bar0_pos_x, picker_pos.y))
        ImGui.InvisibleButton("hue", ImVec2(bars_width, sv_picker_size))
        if ImGui.IsItemActive() and not is_readonly then
            H = ImSaturate((io.MousePos.y - picker_pos.y) / ImMax(sv_picker_size - 1, 0.0001))
            value_changed = true
            value_changed_h = true
        end
    end

    -- Alpha bar logic
    if alpha_bar then
        ImGui.SetCursorScreenPos(ImVec2(bar1_pos_x, picker_pos.y))
        ImGui.InvisibleButton("alpha", ImVec2(bars_width, sv_picker_size))
        if ImGui.IsItemActive() then
            col[4] = 1.0 - ImSaturate((io.MousePos.y - picker_pos.y) / ImMax(sv_picker_size - 1, 0.0001))
            value_changed = true
        end
    end
    ImGui.PopItemFlag() -- ImGuiItemFlags.NoNav

    if bit32.band(flags, ImGuiColorEditFlags.NoSidePreview) == 0 then
        ImGui.SameLine(0, style.ItemInnerSpacing.x)
        ImGui.BeginGroup()
    end

    if bit32.band(flags, ImGuiColorEditFlags.NoLabel) == 0 then
        local label_display_end = ImGui.FindRenderedTextEnd(label)
        if label ~= "" and label_display_end > 1 then
            if bit32.band(flags, ImGuiColorEditFlags.NoSidePreview) ~= 0 then
                ImGui.SameLine(0, style.ItemInnerSpacing.x)
            end
            ImGui.TextEx(label, label_display_end)
        end
    end

    if bit32.band(flags, ImGuiColorEditFlags.NoSidePreview) == 0 then
        ImGui.PushItemFlag(ImGuiItemFlags.NoNavDefaultFocus, true)
        local col_v4 = ImVec4(col[1], col[2], col[3], (bit32.band(flags, ImGuiColorEditFlags.NoAlpha) ~= 0) and 1.0 or col[4])

        if bit32.band(flags, ImGuiColorEditFlags.NoLabel) ~= 0 then
            ImGui.Text("Current")
        end

        local sub_flags_to_forward = bit32.bor(ImGuiColorEditFlags.InputMask_, ImGuiColorEditFlags.HDR, ImGuiColorEditFlags.AlphaMask_, ImGuiColorEditFlags.NoTooltip)

        ImGui.ColorButton("##current", col_v4, bit32.band(flags, sub_flags_to_forward), ImVec2(square_sz * 3, square_sz * 2))

        if ref_col ~= nil then
            ImGui.Text("Original")
            local ref_col_v4 = ImVec4(ref_col[1], ref_col[2], ref_col[3], (bit32.band(flags, ImGuiColorEditFlags.NoAlpha) ~= 0) and 1.0 or ref_col[4])
            if ImGui.ColorButton("##original", ref_col_v4, bit32.band(flags, sub_flags_to_forward), ImVec2(square_sz * 3, square_sz * 2)) then
                for i = 1, components do
                    col[i] = ref_col[i]
                end
                value_changed = true
            end
        end

        ImGui.PopItemFlag()
        ImGui.EndGroup()
    end

    -- Convert back color to RGB
    if value_changed_h or value_changed_sv then
        if bit32.band(flags, ImGuiColorEditFlags.InputRGB) ~= 0 then
            col[1], col[2], col[3] = ImGui.ColorConvertHSVtoRGB(H, S, V)  -- [Port] Lua 1-based indexing
            g.ColorEditSavedHue = H
            g.ColorEditSavedSat = S
            g.ColorEditSavedID = g.ColorEditCurrentID
            g.ColorEditSavedColor = ImGui.ColorConvertFloat4ToU32(ImVec4(col[1], col[2], col[3], 0))
        elseif bit32.band(flags, ImGuiColorEditFlags.InputHSV) ~= 0 then
            col[1] = H
            col[2] = S
            col[3] = V
        end
    end

    -- R,G,B and H,S,V slider color editor
    local value_changed_fix_hue_wrap = false
    if bit32.band(flags, ImGuiColorEditFlags.NoInputs) == 0 then
        ImGui.PushItemWidth((alpha_bar and bar1_pos_x or bar0_pos_x) + bars_width - picker_pos.x)

        local sub_flags_to_forward = bit32.bor(ImGuiColorEditFlags.DataTypeMask_, ImGuiColorEditFlags.InputMask_, ImGuiColorEditFlags.HDR, ImGuiColorEditFlags.AlphaMask_, ImGuiColorEditFlags.NoOptions, ImGuiColorEditFlags.NoTooltip, ImGuiColorEditFlags.NoSmallPreview)
        local sub_flags = bit32.bor(bit32.band(flags, sub_flags_to_forward), ImGuiColorEditFlags.NoPicker)

        if bit32.band(flags, ImGuiColorEditFlags.DisplayRGB) ~= 0 or bit32.band(flags, ImGuiColorEditFlags.DisplayMask_) == 0 then
            if ImGui.ColorEdit4("##rgb", col, bit32.bor(sub_flags, ImGuiColorEditFlags.DisplayRGB)) then
                -- FIXME: Hackily differentiating using the DragInt (ActiveId != 0 && !ActiveIdAllowOverlap) vs. using the InputText or DropTarget.
                -- For the later we don't want to run the hue-wrap canceling code. If you are well versed in HSV picker please provide your input! (See #2050)
                value_changed_fix_hue_wrap = (g.ActiveId ~= 0 and not g.ActiveIdAllowOverlap)
                value_changed = true
            end
        end

        if bit32.band(flags, ImGuiColorEditFlags.DisplayHSV) ~= 0 or bit32.band(flags, ImGuiColorEditFlags.DisplayMask_) == 0 then
            if ImGui.ColorEdit4("##hsv", col, bit32.bor(sub_flags, ImGuiColorEditFlags.DisplayHSV)) then
                value_changed = true
            end
        end

        if bit32.band(flags, ImGuiColorEditFlags.DisplayHex) ~= 0 or bit32.band(flags, ImGuiColorEditFlags.DisplayMask_) == 0 then
            if ImGui.ColorEdit4("##hex", col, bit32.bor(sub_flags, ImGuiColorEditFlags.DisplayHex)) then
                value_changed = true
            end
        end

        ImGui.PopItemWidth()
    end

    -- Try to cancel hue wrap (after ColorEdit4 call), if any
    if value_changed_fix_hue_wrap and bit32.band(flags, ImGuiColorEditFlags.InputRGB) ~= 0 then
        local new_H, new_S, new_V = ImGui.ColorConvertRGBtoHSV(col[1], col[2], col[3])  -- [Port] Lua 1-based indexing

        if new_H <= 0 and H > 0 then
            if new_V <= 0 and V ~= new_V then
                col[1], col[2], col[3] = ImGui.ColorConvertHSVtoRGB(H, S, (new_V <= 0) and (V * 0.5) or new_V)
            elseif new_S <= 0 then
                col[1], col[2], col[3] = ImGui.ColorConvertHSVtoRGB(H, (new_S <= 0) and (S * 0.5) or new_S, new_V)
            end
        end
    end

    if value_changed then
        if bit32.band(flags, ImGuiColorEditFlags.InputRGB) ~= 0 then
            R = col[1]
            G = col[2]
            B = col[3]
            H, S, V = ImGui.ColorConvertRGBtoHSV(R, G, B)
            H, S, V = ColorEditRestoreHS(col, H, S, V) -- Fix local Hue as display below will use it immediately.
        elseif bit32.band(flags, ImGuiColorEditFlags.InputHSV) ~= 0 then
            H = col[1]
            S = col[2]
            V = col[3]
            R, G, B = ImGui.ColorConvertHSVtoRGB(H, S, V)
        end
    end

    local style_alpha8 = IM_F32_TO_INT8_SAT(style.Alpha)
    local col_black = IM_COL32(0, 0, 0, style_alpha8)
    local col_white = IM_COL32(255, 255, 255, style_alpha8)
    local col_midgrey = IM_COL32(128, 128, 128, style_alpha8)
    local col_hues = { IM_COL32(255, 0, 0, style_alpha8), IM_COL32(255, 255, 0, style_alpha8), IM_COL32(0, 255, 0, style_alpha8), IM_COL32(0, 255, 255, style_alpha8), IM_COL32(0, 0, 255, style_alpha8), IM_COL32(255, 0, 255, style_alpha8), IM_COL32(255, 0, 0, style_alpha8) }

    local hue_color_f = ImVec4(1, 1, 1, style.Alpha)
    hue_color_f.x, hue_color_f.y, hue_color_f.z = ImGui.ColorConvertHSVtoRGB(H, 1, 1)
    local hue_color32 = ImGui.ColorConvertFloat4ToU32(hue_color_f)
    local user_col32_striped_of_alpha = ImGui.ColorConvertFloat4ToU32(ImVec4(R, G, B, style.Alpha)) -- Important: this is still including the main rendering/style alpha!!

    local sv_cursor_pos = ImVec2()

    if bit32.band(flags, ImGuiColorEditFlags.PickerHueWheel) ~= 0 then
        -- Render Hue Wheel
        local aeps = 0.5 / wheel_r_outer -- Half a pixel arc length in radians (2pi cancels out).
        local segment_per_arc = ImMax(4, math.floor(wheel_r_outer / 12))

        for n = 1, 6 do
            local a0 = (n - 1) / 6.0 * 2.0 * IM_PI - aeps
            local a1 = n / 6.0 * 2.0 * IM_PI + aeps
            local vert_start_idx = draw_list.VtxBuffer.Size + 1

            draw_list:PathArcTo(wheel_center, (wheel_r_inner + wheel_r_outer) * 0.5, a0, a1, segment_per_arc)
            draw_list:PathStroke(col_white, wheel_thickness)

            local vert_end_idx = draw_list.VtxBuffer.Size + 1

            -- Paint colors over existing vertices
            local gradient_p0 = ImVec2(wheel_center.x + ImCos(a0) * wheel_r_inner, wheel_center.y + ImSin(a0) * wheel_r_inner)
            local gradient_p1 = ImVec2(wheel_center.x + ImCos(a1) * wheel_r_inner, wheel_center.y + ImSin(a1) * wheel_r_inner)
            ImGui.ShadeVertsLinearColorGradientKeepAlpha(draw_list, vert_start_idx, vert_end_idx, gradient_p0, gradient_p1, col_hues[n], col_hues[n + 1])
        end

        -- Render Cursor + preview on Hue Wheel
        local cos_hue_angle = ImCos(H * 2.0 * IM_PI)
        local sin_hue_angle = ImSin(H * 2.0 * IM_PI)

        local hue_cursor_pos = ImVec2(wheel_center.x + cos_hue_angle * (wheel_r_inner + wheel_r_outer) * 0.5, wheel_center.y + sin_hue_angle * (wheel_r_inner + wheel_r_outer) * 0.5)

        local hue_cursor_rad = value_changed_h and (wheel_thickness * 0.65) or (wheel_thickness * 0.55)
        local hue_cursor_segments = draw_list:_CalcCircleAutoSegmentCount(hue_cursor_rad) -- Lock segment count so the +1 one matches others.

        draw_list:AddCircleFilled(hue_cursor_pos, hue_cursor_rad, hue_color32, hue_cursor_segments)
        draw_list:AddCircle(hue_cursor_pos, hue_cursor_rad + 1, col_midgrey, hue_cursor_segments)
        draw_list:AddCircle(hue_cursor_pos, hue_cursor_rad, col_white, hue_cursor_segments)

        if triangle_rotate == false then
            cos_hue_angle = 1.0
            sin_hue_angle = 0.0
        end

        -- Render SV triangle (rotated according to hue)
        local tra = wheel_center + ImRotate(triangle_pa, cos_hue_angle, sin_hue_angle)
        local trb = wheel_center + ImRotate(triangle_pb, cos_hue_angle, sin_hue_angle)
        local trc = wheel_center + ImRotate(triangle_pc, cos_hue_angle, sin_hue_angle)

        local uv_white = ImGui.GetFontTexUvWhitePixel()
        draw_list:PrimReserve(3, 3)
        draw_list:PrimVtx(tra, uv_white, hue_color32)
        draw_list:PrimVtx(trb, uv_white, col_black)
        draw_list:PrimVtx(trc, uv_white, col_white)
        draw_list:AddTriangle(tra, trb, trc, col_midgrey, 1.5)

        sv_cursor_pos = ImLerp(ImLerp(trc, tra, ImSaturate(S)), trb, ImSaturate(1 - V))
    elseif bit32.band(flags, ImGuiColorEditFlags.PickerHueBar) ~= 0 then
        -- Render SV Square
        draw_list:AddRectFilledMultiColor(picker_pos, picker_pos + ImVec2(sv_picker_size, sv_picker_size), col_white, hue_color32, hue_color32, col_white)
        draw_list:AddRectFilledMultiColor(picker_pos, picker_pos + ImVec2(sv_picker_size, sv_picker_size), 0, 0, col_black, col_black)
        ImGui.RenderFrameBorder(picker_pos, picker_pos + ImVec2(sv_picker_size, sv_picker_size), 0.0)

        sv_cursor_pos.x = ImClamp(IM_ROUND(picker_pos.x + ImSaturate(S) * sv_picker_size), picker_pos.x + 2, picker_pos.x + sv_picker_size - 2) -- Sneakily prevent the circle to stick out too much
        sv_cursor_pos.y = ImClamp(IM_ROUND(picker_pos.y + ImSaturate(1 - V) * sv_picker_size), picker_pos.y + 2, picker_pos.y + sv_picker_size - 2)

        -- Render Hue Bar
        for i = 1, 6 do
            draw_list:AddRectFilledMultiColor(ImVec2(bar0_pos_x, picker_pos.y + (i - 1) * (sv_picker_size / 6)), ImVec2(bar0_pos_x + bars_width, picker_pos.y + i * (sv_picker_size / 6)), col_hues[i], col_hues[i], col_hues[i + 1], col_hues[i + 1])
        end

        local bar0_line_y = IM_ROUND(picker_pos.y + H * sv_picker_size)
        ImGui.RenderFrameBorder(ImVec2(bar0_pos_x, picker_pos.y), ImVec2(bar0_pos_x + bars_width, picker_pos.y + sv_picker_size), 0.0)
        RenderArrowsForVerticalBar(draw_list, ImVec2(bar0_pos_x - 1, bar0_line_y), ImVec2(bars_triangles_half_sz + 1, bars_triangles_half_sz), bars_width + 2.0, style.Alpha)
    end

    -- Render cursor/preview circle (clamp S/V within 0..1 range because floating points colors may lead HSV values to be out of range)
    local sv_cursor_rad = value_changed_sv and (wheel_thickness * 0.55) or (wheel_thickness * 0.40)
    local sv_cursor_segments = draw_list:_CalcCircleAutoSegmentCount(sv_cursor_rad) -- Lock segment count so the +1 one matches others.
    draw_list:AddCircleFilled(sv_cursor_pos, sv_cursor_rad, user_col32_striped_of_alpha, sv_cursor_segments)
    draw_list:AddCircle(sv_cursor_pos, sv_cursor_rad + 1, col_midgrey, sv_cursor_segments)
    draw_list:AddCircle(sv_cursor_pos, sv_cursor_rad, col_white, sv_cursor_segments)

    -- Render alpha bar
    if alpha_bar then
        local alpha = ImSaturate(col[4])
        local bar1_bb = ImRect(bar1_pos_x, picker_pos.y, bar1_pos_x + bars_width, picker_pos.y + sv_picker_size)
        ImGui.RenderColorRectWithAlphaCheckerboard(draw_list, bar1_bb.Min, bar1_bb.Max, IM_COL32(0, 0, 0, 0), style.Alpha, bar1_bb:GetWidth() / 2.0, ImVec2(0.0, 0.0))
        draw_list:AddRectFilledMultiColor(bar1_bb.Min, bar1_bb.Max, user_col32_striped_of_alpha, user_col32_striped_of_alpha, bit32.band(user_col32_striped_of_alpha, bit32.bnot(IM_COL32_A_MASK)), bit32.band(user_col32_striped_of_alpha, bit32.bnot(IM_COL32_A_MASK)))

        local bar1_line_y = IM_ROUND(picker_pos.y + (1.0 - alpha) * sv_picker_size)
        ImGui.RenderFrameBorder(bar1_bb.Min, bar1_bb.Max, 0.0)
        RenderArrowsForVerticalBar(draw_list, ImVec2(bar1_pos_x - 1, bar1_line_y), ImVec2(bars_triangles_half_sz + 1, bars_triangles_half_sz), bars_width + 2.0, style.Alpha)
    end

    ImGui.EndGroup()

    if value_changed then
        for i = 1, components do
            if backup_initial_col[i] ~= col[i] then
                break
            end
            if i == components then
                value_changed = false
            end
        end
    end

    if value_changed and g.LastItemData.ID ~= 0 then -- In case of ID collision, the second EndGroup() won't catch g.ActiveId
        ImGui.MarkItemEdited(g.LastItemData.ID)
    end

    if set_current_color_edit_id then
        g.ColorEditCurrentID = 0
    end

    ImGui.PopID()

    return value_changed
end

end

-- A little color square. Return true when clicked.
-- FIXME: May want to display/ignore the alpha component in the color display? Yet show it in the tooltip.
-- 'desc_id' is not called 'label' because we don't display it next to the button, but only in the tooltip.
-- Note that 'col' may be encoded in HSV if ImGuiColorEditFlags.InputHSV is set.
--- @param desc_id   string
--- @param col       ImVec4
--- @param flags?    ImGuiColorEditFlags
--- @param size_arg? ImVec2
@native
function ImGui.ColorButton(desc_id, col, flags, size_arg)
    if flags    == nil then flags    = 0            end
    if size_arg == nil then size_arg = ImVec2(0, 0) end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local id = window:GetID(desc_id)
    local default_size = ImGui.GetFrameHeight()
    local size = ImVec2(size_arg.x == 0.0 and default_size or size_arg.x, size_arg.y == 0.0 and default_size or size_arg.y)
    local bb = ImRect(window.DC.CursorPos, window.DC.CursorPos + size)
    ImGui.ItemSize(bb, (size.y >= default_size) and g.Style.FramePadding.y or 0.0)
    if not ImGui.ItemAdd(bb, id) then
        return false
    end

    local pressed, hovered, _ = ImGui.ButtonBehavior(bb, id)

    if bit32.band(flags, bit32.bor(ImGuiColorEditFlags.NoAlpha, ImGuiColorEditFlags.AlphaOpaque)) ~= 0 then
        flags = bit32.band(flags, bit32.bnot(bit32.bor(ImGuiColorEditFlags.AlphaNoBg, ImGuiColorEditFlags.AlphaPreviewHalf)))
    end

    local col_rgb = ImVec4(col.x, col.y, col.z, col.w)
    if bit32.band(flags, ImGuiColorEditFlags.InputHSV) ~= 0 then
        col_rgb.x, col_rgb.y, col_rgb.z = ImGui.ColorConvertHSVtoRGB(col_rgb.x, col_rgb.y, col_rgb.z)
    end

    local col_rgb_without_alpha = ImVec4(col_rgb.x, col_rgb.y, col_rgb.z, 1.0)
    local grid_step = ImMin(size.x, size.y) / 2.99
    local rounding = ImMin(g.Style.FrameRounding, grid_step * 0.5)
    local is_mixed = bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.MixedValue) ~= 0

    local backup_alpha = g.Style.Alpha
    if g.DisabledStackSize > 0 then
        g.Style.Alpha = g.DisabledAlphaBackup -- Cancel out effect of BeginDisabled() for color swatches.
    end
    if is_mixed then
        window.DrawList:AddRectFilled(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.FrameBg), rounding)
        ImGui.PushStyleColor(ImGuiCol.Text, g.Style.Colors[ImGuiCol.TextDisabled]) -- ImGuiCol_TextMixedValue
        if g.MixedValueLabel ~= nil then
            ImGui.RenderTextClipped(ImVec2(bb.Min.x, bb.Min.y + g.Style.FramePadding.y), bb.Max, g.MixedValueLabel, nil, nil, ImVec2(0.5, 0.0))
        end
        ImGui.PopStyleColor()
    elseif bit32.band(flags, ImGuiColorEditFlags.AlphaPreviewHalf) ~= 0 and col_rgb.w < 1.0 then
        local mid_x = IM_ROUND((bb.Min.x + bb.Max.x) * 0.5)
        if bit32.band(flags, ImGuiColorEditFlags.AlphaNoBg) == 0 then
            ImGui.RenderColorRectWithAlphaCheckerboard(window.DrawList, ImVec2(bb.Min.x + grid_step, bb.Min.y), bb.Max, ImGui.ColorConvertFloat4ToU32(col_rgb), g.Style.Alpha, grid_step, ImVec2(-grid_step, 0.0), rounding, ImDrawFlags.RoundRight)
        else
            window.DrawList:AddRectFilled(ImVec2(bb.Min.x + grid_step, bb.Min.y), bb.Max, ImGui.GetColorU32(col_rgb), rounding, ImDrawFlags.RoundRight)
        end
        window.DrawList:AddRectFilled(bb.Min, ImVec2(mid_x, bb.Max.y), ImGui.GetColorU32(col_rgb_without_alpha), rounding, ImDrawFlags.RoundLeft)
    else
        -- Because GetColorU32() multiplies by the global style Alpha and we don't want to display a checkerboard if the source code had no alpha
        local col_source = (bit32.band(flags, ImGuiColorEditFlags.AlphaOpaque) ~= 0) and col_rgb_without_alpha or col_rgb
        if col_source.w < 1.0 and bit32.band(flags, ImGuiColorEditFlags.AlphaNoBg) == 0 then
            ImGui.RenderColorRectWithAlphaCheckerboard(window.DrawList, bb.Min, bb.Max, ImGui.ColorConvertFloat4ToU32(col_source), g.Style.Alpha, grid_step, ImVec2(0.0, 0.0), rounding)
        else
            window.DrawList:AddRectFilled(bb.Min, bb.Max, ImGui.GetColorU32(col_source), rounding)
        end
    end
    if g.DisabledStackSize > 0 then
        g.Style.Alpha = backup_alpha
    end
    ImGui.RenderNavCursor(bb, id)
    if bit32.band(flags, ImGuiColorEditFlags.NoBorder) == 0 then
        if g.Style.FrameBorderSize > 0.0 then
            ImGui.RenderFrameBorder(bb.Min, bb.Max, rounding)
        else
            window.DrawList:AddRect(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.FrameBg), rounding, 1.0 * ImTrunc(g.Style._MainScale)) -- Color buttons are often in need of some sort of border -- FIXME-DPI
        end
    end

    -- Drag and Drop Source
    -- NB: The ActiveId test is merely an optional micro-optimization, BeginDragDropSource() does the same test.
    -- [Port] payload.Data is a 1-based float array copy { r, g, b [, a] } (C++ memcpy of float[3]/float[4])
    if g.ActiveId == id and bit32.band(flags, ImGuiColorEditFlags.NoDragDrop) == 0 and ImGui.BeginDragDropSource() then
        if bit32.band(flags, ImGuiColorEditFlags.NoAlpha) ~= 0 then
            ImGui.SetDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_3F, { col_rgb.x, col_rgb.y, col_rgb.z }, 3, ImGuiCond.Once)
        else
            ImGui.SetDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_4F, { col_rgb.x, col_rgb.y, col_rgb.z, col_rgb.w }, 4, ImGuiCond.Once)
        end
        ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, false)
        ImGui.ColorButton(desc_id, col, flags)
        ImGui.PopItemFlag()
        ImGui.SameLine()
        ImGui.TextEx("Color")
        ImGui.EndDragDropSource()
    end

    -- Tooltip
    if bit32.band(flags, ImGuiColorEditFlags.NoTooltip) == 0 and hovered and ImGui.IsItemHovered(ImGuiHoveredFlags.ForTooltip) then
        ImGui.ColorTooltip(desc_id, col, bit32.band(flags, bit32.bor(ImGuiColorEditFlags.InputMask_, ImGuiColorEditFlags.AlphaMask_)))
    end

    return pressed
end

-- Note: only access 3 floats if ImGuiColorEditFlags.NoAlpha flag is set.
--- @param text? string
--- @param col   ImVec4
--- @param flags ImGuiColorEditFlags
function ImGui.ColorTooltip(text, col, flags)
    local g = GImGui

    if not ImGui.BeginTooltipEx(ImGuiTooltipFlags.OverridePrevious, ImGuiWindowFlags.None) then
        return
    end

    local text_end = text and ImGui.FindRenderedTextEnd(text, nil) or 1
    if text_end > 1 then
        --- @cast text string
        ImGui.TextEx(text, text_end)
        ImGui.Separator()
    end

    local sz = ImVec2(g.FontSize * 3 + g.Style.FramePadding.y * 2, g.FontSize * 3 + g.Style.FramePadding.y * 2)
    local cf = ImVec4(col.x, col.y, col.z, (bit32.band(flags, ImGuiColorEditFlags.NoAlpha) ~= 0) and 1.0 or col.w)
    local cr = IM_F32_TO_INT8_SAT(col.x)
    local cg = IM_F32_TO_INT8_SAT(col.y)
    local cb = IM_F32_TO_INT8_SAT(col.z)
    local ca = (bit32.band(flags, ImGuiColorEditFlags.NoAlpha) ~= 0) and 255 or IM_F32_TO_INT8_SAT(col.w)

    local flags_to_forward = bit32.bor(ImGuiColorEditFlags.InputMask_, ImGuiColorEditFlags.AlphaMask_)
    ImGui.ColorButton("##preview", cf, bit32.bor(bit32.band(flags, flags_to_forward), ImGuiColorEditFlags.NoTooltip), sz)
    ImGui.SameLine()

    if bit32.band(flags, ImGuiColorEditFlags.InputRGB) ~= 0 or bit32.band(flags, ImGuiColorEditFlags.InputMask_) == 0 then
        if bit32.band(flags, ImGuiColorEditFlags.NoAlpha) ~= 0 then
            ImGui.Text("#%02X%02X%02X\nR: %d, G: %d, B: %d\n(%.3f, %.3f, %.3f)", cr, cg, cb, cr, cg, cb, col.x, col.y, col.z)
        else
            ImGui.Text("#%02X%02X%02X%02X\nR:%d, G:%d, B:%d, A:%d\n(%.3f, %.3f, %.3f, %.3f)", cr, cg, cb, ca, cr, cg, cb, ca, col.x, col.y, col.z, col.w)
        end
    elseif bit32.band(flags, ImGuiColorEditFlags.InputHSV) ~= 0 then
        if bit32.band(flags, ImGuiColorEditFlags.NoAlpha) ~= 0 then
            ImGui.Text("H: %.3f, S: %.3f, V: %.3f", col.x, col.y, col.z)
        else
            ImGui.Text("H: %.3f, S: %.3f, V: %.3f, A: %.3f", col.x, col.y, col.z, col.w)
        end
    end

    ImGui.EndTooltip()
end

--- @param col   float[]
--- @param flags ImGuiColorEditFlags
function ImGui.ColorEditOptionsPopup(col, flags)
    local allow_opt_inputs = bit32.band(flags, ImGuiColorEditFlags.DisplayMask_) == 0
    local allow_opt_datatype = bit32.band(flags, ImGuiColorEditFlags.DataTypeMask_) == 0

    if (not allow_opt_inputs and not allow_opt_datatype) or not ImGui.BeginPopup("context") then
        return
    end

    local g = GImGui
    ImGui.PushItemFlag(ImGuiItemFlags.NoMarkEdited, true)
    local opts = g.IO.ConfigColorEditFlags
    if allow_opt_inputs then
        if ImGui.RadioButtonEx("RGB", bit32.band(opts, ImGuiColorEditFlags.DisplayRGB) ~= 0) then
            opts = bit32.bor(bit32.band(opts, bit32.bnot(ImGuiColorEditFlags.DisplayMask_)), ImGuiColorEditFlags.DisplayRGB)
        end
        if ImGui.RadioButtonEx("HSV", bit32.band(opts, ImGuiColorEditFlags.DisplayHSV) ~= 0) then
            opts = bit32.bor(bit32.band(opts, bit32.bnot(ImGuiColorEditFlags.DisplayMask_)), ImGuiColorEditFlags.DisplayHSV)
        end
        if ImGui.RadioButtonEx("Hex", bit32.band(opts, ImGuiColorEditFlags.DisplayHex) ~= 0) then
            opts = bit32.bor(bit32.band(opts, bit32.bnot(ImGuiColorEditFlags.DisplayMask_)), ImGuiColorEditFlags.DisplayHex)
        end
    end
    if allow_opt_datatype then
        if allow_opt_inputs then ImGui.Separator() end
        if ImGui.RadioButtonEx("0..255", bit32.band(opts, ImGuiColorEditFlags.Uint8) ~= 0) then
            opts = bit32.bor(bit32.band(opts, bit32.bnot(ImGuiColorEditFlags.DataTypeMask_)), ImGuiColorEditFlags.Uint8)
        end
        if ImGui.RadioButtonEx("0.00..1.00", bit32.band(opts, ImGuiColorEditFlags.Float) ~= 0) then
            opts = bit32.bor(bit32.band(opts, bit32.bnot(ImGuiColorEditFlags.DataTypeMask_)), ImGuiColorEditFlags.Float)
        end
    end

    if allow_opt_inputs or allow_opt_datatype then
        ImGui.Separator()
    end
    if ImGui.Button("Copy as..", ImVec2(-1, 0)) then
        ImGui.OpenPopup("Copy")
    end
    if ImGui.BeginPopup("Copy") then
        local cr = IM_F32_TO_INT8_SAT(col[1])
        local cg = IM_F32_TO_INT8_SAT(col[2])
        local cb = IM_F32_TO_INT8_SAT(col[3])
        local ca = (bit32.band(flags, ImGuiColorEditFlags.NoAlpha) ~= 0) and 255 or IM_F32_TO_INT8_SAT(col[4])

        local buf1 = ImFormatString("(%.3ff, %.3ff, %.3ff, %.3ff)", col[1], col[2], col[3], (bit32.band(flags, ImGuiColorEditFlags.NoAlpha) ~= 0) and 1.0 or col[4])
        if ImGui.Selectable(buf1) then
            ImGui.SetClipboardText(buf1)
        end

        local buf2 = ImFormatString("(%d,%d,%d,%d)", cr, cg, cb, ca)
        if ImGui.Selectable(buf2) then
            ImGui.SetClipboardText(buf2)
        end

        local buf3 = ImFormatString("#%02X%02X%02X", cr, cg, cb)
        if ImGui.Selectable(buf3) then
            ImGui.SetClipboardText(buf3)
        end

        if bit32.band(flags, ImGuiColorEditFlags.NoAlpha) == 0 then
            local buf4 = ImFormatString("#%02X%02X%02X%02X", cr, cg, cb, ca)
            if ImGui.Selectable(buf4) then
                ImGui.SetClipboardText(buf4)
            end
        end

        ImGui.EndPopup()
    end

    g.IO.ConfigColorEditFlags = opts
    ImGui.PopItemFlag()
    ImGui.EndPopup()
end

--- @param ref_col float[]
--- @param flags   ImGuiColorEditFlags
function ImGui.ColorPickerOptionsPopup(ref_col, flags)
    local allow_opt_picker = bit32.band(flags, ImGuiColorEditFlags.PickerMask_) == 0
    local allow_opt_alpha_bar = (bit32.band(flags, ImGuiColorEditFlags.NoAlpha) == 0) and (bit32.band(flags, ImGuiColorEditFlags.AlphaBar) == 0)

    if (not allow_opt_picker and not allow_opt_alpha_bar) or not ImGui.BeginPopup("context") then
        return
    end

    local g = GImGui
    ImGui.PushItemFlag(ImGuiItemFlags.NoMarkEdited, true)
    if allow_opt_picker then
        local picker_size = ImVec2(g.FontSize * 8, ImMax(g.FontSize * 8 - (ImGui.GetFrameHeight() + g.Style.ItemInnerSpacing.x), 1.0)) -- FIXME: Picker size copied from main picker function
        ImGui.PushItemWidth(picker_size.x)
        for picker_type = 0, 1 do
            -- Draw small/thumbnail version of each picker type (over an invisible button for selection)
            if picker_type > 0 then
                ImGui.Separator()
            end
            ImGui.PushID(picker_type)
            local picker_flags = bit32.bor(ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.NoOptions, ImGuiColorEditFlags.NoLabel, ImGuiColorEditFlags.NoSidePreview, bit32.band(flags, ImGuiColorEditFlags.NoAlpha))
            if picker_type == 0 then
                picker_flags = bit32.bor(picker_flags, ImGuiColorEditFlags.PickerHueBar)
            end
            if picker_type == 1 then
                picker_flags = bit32.bor(picker_flags, ImGuiColorEditFlags.PickerHueWheel)
            end
            local backup_pos = ImGui.GetCursorScreenPos()
            if ImGui.Selectable("##selectable", false, 0, picker_size) then -- By default, Selectable() is closing popup
                g.IO.ConfigColorEditFlags = bit32.bor(bit32.band(g.IO.ConfigColorEditFlags, bit32.bnot(ImGuiColorEditFlags.PickerMask_)), bit32.band(picker_flags, ImGuiColorEditFlags.PickerMask_))
            end
            ImGui.SetCursorScreenPos(backup_pos)
            local previewing_ref_col = ImVec4()
            for i = 1, (bit32.band(picker_flags, ImGuiColorEditFlags.NoAlpha) ~= 0 and 3 or 4) do
                previewing_ref_col[i] = ref_col[i]
            end
            ImGui.ColorPicker4("##previewing_picker", previewing_ref_col, picker_flags)
            ImGui.PopID()
        end
        ImGui.PopItemWidth()
    end
    if allow_opt_alpha_bar then
        if allow_opt_picker then
            ImGui.Separator()
        end
        _, g.IO.ConfigColorEditFlags = ImGui.CheckboxFlags("Alpha Bar", g.IO.ConfigColorEditFlags, ImGuiColorEditFlags.AlphaBar)
    end
    ImGui.PopItemFlag()
    ImGui.EndPopup()
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: TreeNode, CollapsingHeader, etc.
-------------------------------------------------------------------------------
-- - TreeNode()
-- - TreeNodeV()
-- - TreeNodeEx()
-- - TreeNodeExV()
-- - TreeNodeStoreStackData() [Internal]
-- - TreeNodeBehavior() [Internal]
-- - TreePush()
-- - TreePop()
-- - GetTreeNodeToLabelSpacing()
-- - SetNextItemOpen()
-- - CollapsingHeader()
-------------------------------------------------------------------------------

-- [Port] va_list variants: identical in Lua (varargs)
ImGui.TextColoredV = function(...) return ImGui.TextColored(...) end
ImGui.TextDisabledV = function(...) return ImGui.TextDisabled(...) end
ImGui.TextWrappedV = function(...) return ImGui.TextWrapped(...) end
ImGui.TextAlignedV = function(...) return ImGui.TextAligned(...) end
ImGui.LabelTextV = function(...) return ImGui.LabelText(...) end
ImGui.BulletTextV = function(...) return ImGui.BulletText(...) end

--- @param data_type ImGuiDataType
--- @param v         number
function ImGui.SetNextItemRefVal(data_type, v)
    local g = GImGui
    g.NextItemData.HasFlags = bit32.bor(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasRefVal)
    g.NextItemData.RefVal = v
end

-- [Port] Overloads: TreeNode(label) / TreeNode(str_id, fmt, ...)
--- @param label string
@native
function ImGui.TreeNode(label, fmt, ...)
    if fmt ~= nil then
        return ImGui.TreeNodeEx(label, 0, fmt, ...)
    end
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end
    local id = window:GetID(label)
    return ImGui.TreeNodeBehavior(id, ImGuiTreeNodeFlags.None, label, nil)
end

function ImGui.TreeNodeV(str_id, fmt, ...)
    return ImGui.TreeNodeExV(str_id, 0, fmt, ...)
end

-- [Port] Overloads: TreeNodeEx(label, flags) / TreeNodeEx(str_id, flags, fmt, ...)
--- @param label  string
--- @param flags? ImGuiTreeNodeFlags
function ImGui.TreeNodeEx(label, flags, fmt, ...)
    if flags == nil then flags = 0 end
    if fmt ~= nil then
        return ImGui.TreeNodeExV(label, flags, fmt, ...)
    end
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end
    local id = window:GetID(label)
    return ImGui.TreeNodeBehavior(id, flags, label, nil)
end

--- @param str_id string|ImGuiID
function ImGui.TreeNodeExV(str_id, flags, fmt, ...)
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end
    local id = window:GetID(str_id)
    local label = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
    return ImGui.TreeNodeBehavior(id, flags, label, #label + 1)
end

-- The reason those two functions are not yet in public API is because I would like to design a more feature-full and generic API for this.
-- They are otherwise function (cc: #3823, #9251, #7553, #6754, #5423, #2958, #2079, #1947, #1131, #722)
--- @param storage_id ImGuiID
function ImGui.TreeNodeGetOpen(storage_id)
    local g = GImGui
    local storage = g.CurrentWindow.DC.StateStorage
    return (storage[storage_id]) and true or false
end

--- @param storage_id ImGuiID
--- @param is_open    bool
@native
function ImGui.TreeNodeSetOpen(storage_id, is_open)
    local g = GImGui
    local storage = g.CurrentWindow.DC.StateStorage
    storage[storage_id] = is_open
end

--- @param storage_id ImGuiID
--- @param flags      ImGuiTreeNodeFlags
@native
function ImGui.TreeNodeUpdateNextOpen(storage_id, flags)
    -- Leaf node always open a new tree/id scope. If you never use it, add ImGuiTreeNodeFlags.NoTreePushOnOpen.
    if bit32.band(flags, ImGuiTreeNodeFlags.Leaf) ~= 0 then
        return true
    end

    -- We only write to the tree storage if the user clicks, or explicitly use the SetNextItemOpen function
    local g = GImGui
    local window = g.CurrentWindow
    local storage = window.DC.StateStorage

    local is_open
    if bit32.band(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasOpen) ~= 0 then
        if bit32.band(g.NextItemData.OpenCond, ImGuiCond.Always) ~= 0 then
            is_open = g.NextItemData.OpenVal
            ImGui.TreeNodeSetOpen(storage_id, is_open)
        else
            -- We treat ImGuiCond.Once and ImGuiCond.FirstUseEver the same because tree node state are not saved persistently.
            local stored_value = storage[storage_id]
            if stored_value == nil then
                is_open = g.NextItemData.OpenVal
                ImGui.TreeNodeSetOpen(storage_id, is_open)
            else
                is_open = stored_value and true or false
            end
        end
    else
        is_open = (storage[storage_id] == nil) and (bit32.band(flags, ImGuiTreeNodeFlags.DefaultOpen) ~= 0) or storage[storage_id]
    end

    -- When logging is enabled, we automatically expand tree nodes (but *NOT* collapsing headers.. seems like sensible behavior).
    -- NB- If we are above max depth we still allow manually opened nodes to be logged.
    if g.LogEnabled and bit32.band(flags, ImGuiTreeNodeFlags.NoAutoOpenOnLog) == 0 and (window.DC.TreeDepth - g.LogDepthRef) < g.LogDepthToExpand then
        is_open = true
    end

    return is_open
end

-- Store ImGuiTreeNodeStackData for just submitted node.
-- Currently only supports 32 level deep. Easy to increase to e.g. 64.
--- @param flags ImGuiTreeNodeFlags
--- @param x1    float
local function TreeNodeStoreStackData(flags, x1)
    local g = GImGui
    local window = g.CurrentWindow

    g.TreeNodeStack:resize(g.TreeNodeStack.Size + 1)
    local tree_node_data = g.TreeNodeStack.Data[g.TreeNodeStack.Size]
    tree_node_data.ID = g.LastItemData.ID
    tree_node_data.TreeFlags = flags
    tree_node_data.ItemFlags = g.LastItemData.ItemFlags
    ImRect_Copy(tree_node_data.NavRect, g.LastItemData.NavRect)

    -- Initially I tried to latch value for GetColorU32(ImGuiCol.TreeLines) but it's not a good trade-off for very large trees.
    local draw_lines = bit32.band(flags, bit32.bor(ImGuiTreeNodeFlags.DrawLinesFull, ImGuiTreeNodeFlags.DrawLinesToNodes)) ~= 0
    tree_node_data.DrawLinesX1 = draw_lines and (x1 + g.FontSize * 0.5 + g.Style.FramePadding.x) or FLT_MAX
    tree_node_data.DrawLinesTableColumn = (draw_lines and g.CurrentTable) and g.CurrentTable.CurrentColumn or -1
    tree_node_data.DrawLinesToNodesY2 = -FLT_MAX
    window.DC.TreeHasStackDataDepthMask = bit32.bor(window.DC.TreeHasStackDataDepthMask, bit32.lshift(1, window.DC.TreeDepth))
    if bit32.band(flags, ImGuiTreeNodeFlags.DrawLinesToNodes) ~= 0 then
        window.DC.TreeRecordsClippedNodesY2Mask = bit32.bor(window.DC.TreeRecordsClippedNodesY2Mask, bit32.lshift(1, window.DC.TreeDepth))
    end
end

--- @param id         ImGuiID
--- @param flags      ImGuiTreeNodeFlags
--- @param label      string
--- @param label_end? int
local TreeNode_frame_bb, TreeNode_interact_bb = ImRect(), ImRect() -- [Luau] scratch for TreeNodeBehavior(), never escape
local TreeNode_label_size, TreeNode_text_pos, TreeNode_tmp = ImVec2(), ImVec2(), ImVec2()
local function TreeNode_tmp_pos(x, y) local v = TreeNode_tmp; v.x = x; v.y = y; return v end -- [Luau] scratch pos for Render*() args

@native
function ImGui.TreeNodeBehavior(id, flags, label, label_end)
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local style = g.Style

    -- When not framed, we vertically increase height up to typical framed widget height
    local display_frame = bit32.band(flags, ImGuiTreeNodeFlags.Framed) ~= 0
    local use_frame_padding = display_frame or (bit32.band(flags, ImGuiTreeNodeFlags.FramePadding) ~= 0)
    -- [Luau] scalar padding, no temporary ImVec2
    local padding_x, padding_y
    if use_frame_padding then
        padding_x, padding_y = style.FramePadding.x, style.FramePadding.y
    else
        padding_x, padding_y = style.FramePadding.x, math.min(window.DC.CurrLineTextBaseOffset, style.FramePadding.y)
    end

    if label_end == nil then
        label_end = ImGui.FindRenderedTextEnd(label)
    end
    local label_size = TreeNode_label_size -- [Luau] scratch: only read below (RenderTextClipped text_size_if_known)
    label_size.x, label_size.y = ImGui.CalcTextSizeXY(label, 1, label_end, false)

    local text_offset_x = g.FontSize + (display_frame and (padding_x * 3) or (padding_x * 2)) -- Collapsing arrow width + Spacing
    local text_offset_y = use_frame_padding and ImMax(style.FramePadding.y, window.DC.CurrLineTextBaseOffset) or window.DC.CurrLineTextBaseOffset -- Latch before ItemSize changes it
    local text_width = g.FontSize + label_size.x + padding_x * 2 -- Include collapsing arrow

    local frame_height = label_size.y + padding_y * 2
    local span_all_columns = bit32.band(flags, ImGuiTreeNodeFlags.SpanAllColumns) ~= 0 and (g.CurrentTable ~= nil)
    local span_all_columns_label = bit32.band(flags, ImGuiTreeNodeFlags.LabelSpanAllColumns) ~= 0 and (g.CurrentTable ~= nil)
    local frame_bb = TreeNode_frame_bb -- [Luau] scratch, fully written here; callees copy or only read it
    frame_bb.Min.x = span_all_columns and window.ParentWorkRect.Min.x or (bit32.band(flags, ImGuiTreeNodeFlags.SpanFullWidth) ~= 0 and window.WorkRect.Min.x or window.DC.CursorPos.x)
    frame_bb.Min.y = window.DC.CursorPos.y + (text_offset_y - padding_y)
    frame_bb.Max.x = span_all_columns and window.ParentWorkRect.Max.x or (bit32.band(flags, ImGuiTreeNodeFlags.SpanLabelWidth) ~= 0 and window.DC.CursorPos.x + text_width + padding_x or window.WorkRect.Max.x)
    frame_bb.Max.y = window.DC.CursorPos.y + (text_offset_y - padding_y) + frame_height
    if display_frame then
        local outer_extend = IM_TRUNC(window.WindowPadding.x * 0.5) -- Framed header expand a little outside of current limits
        frame_bb.Min.x = frame_bb.Min.x - outer_extend
        frame_bb.Max.x = frame_bb.Max.x + outer_extend
    end

    local text_pos = TreeNode_text_pos -- [Luau] scratch
    text_pos.x, text_pos.y = window.DC.CursorPos.x + text_offset_x, window.DC.CursorPos.y + text_offset_y
    local item_size = LayoutHelpers_size; item_size.x = text_width; item_size.y = frame_height -- [Luau] scratch, ItemSize() only reads it
    ImGui.ItemSize(item_size, padding_y)

    -- For regular tree nodes, we arbitrary allow to click past 2 worth of ItemSpacing
    local interact_bb = TreeNode_interact_bb -- [Luau] scratch, ItemAdd()/ButtonBehavior()/SetNavID() copy or only read it
    ImRect_Copy(interact_bb, frame_bb)
    if bit32.band(flags, bit32.bor(ImGuiTreeNodeFlags.Framed, ImGuiTreeNodeFlags.SpanAvailWidth, ImGuiTreeNodeFlags.SpanFullWidth, ImGuiTreeNodeFlags.SpanLabelWidth, ImGuiTreeNodeFlags.SpanAllColumns)) == 0 then
        interact_bb.Max.x = frame_bb.Min.x + text_width + (label_size.x > 0.0 and (style.ItemSpacing.x * 2.0) or 0.0)
    end

    -- Compute open and multi-select states before ItemAdd() as it clear NextItem data.
    local storage_id = (bit32.band(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasStorageID) ~= 0) and g.NextItemData.StorageId or id
    local is_open = ImGui.TreeNodeUpdateNextOpen(storage_id, flags)

    local is_visible
    if span_all_columns or span_all_columns_label then
        -- Modify ClipRect for the ItemAdd(), faster than doing a PushColumnsBackground/PushTableBackgroundChannel for every Selectable..
        local backup_clip_rect_min_x = window.ClipRect.Min.x
        local backup_clip_rect_max_x = window.ClipRect.Max.x
        window.ClipRect.Min.x = window.ParentWorkRect.Min.x
        window.ClipRect.Max.x = window.ParentWorkRect.Max.x
        is_visible = ImGui.ItemAdd(interact_bb, id)
        window.ClipRect.Min.x = backup_clip_rect_min_x
        window.ClipRect.Max.x = backup_clip_rect_max_x
    else
        is_visible = ImGui.ItemAdd(interact_bb, id)
    end
    g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasDisplayRect)
    ImRect_Copy(g.LastItemData.DisplayRect, frame_bb)

    -- If a NavLeft request is happening and ImGuiTreeNodeFlags.NavLeftJumpsToParent enabled:
    -- Store data for the current depth to allow returning to this node from any child item.
    -- For this purpose we essentially compare if g.NavIdIsAlive went from 0 to 1 between TreeNode() and TreePop().
    -- It will become tempting to enable ImGuiTreeNodeFlags.NavLeftJumpsToParent by default or move it to ImGuiStyle.
    local store_tree_node_stack_data = false
    if bit32.band(flags, ImGuiTreeNodeFlags.DrawLinesMask_) == 0 then
        flags = bit32.bor(flags, g.Style.TreeLinesFlags)
    end
    local draw_tree_lines = (bit32.band(flags, bit32.bor(ImGuiTreeNodeFlags.DrawLinesFull, ImGuiTreeNodeFlags.DrawLinesToNodes)) ~= 0) and (frame_bb.Min.y < window.ClipRect.Max.y) and (g.Style.TreeLinesSize > 0.0)
    if bit32.band(flags, ImGuiTreeNodeFlags.NoTreePushOnOpen) == 0 then
        store_tree_node_stack_data = draw_tree_lines
        if bit32.band(flags, ImGuiTreeNodeFlags.NavLeftJumpsToParent) ~= 0 and not g.NavIdIsAlive then
            if g.NavMoveDir == ImGuiDir.Left and g.NavWindow == window and ImGui.NavMoveRequestButNoResultYet() then
                store_tree_node_stack_data = true
            end
        end
    end

    local is_leaf = bit32.band(flags, ImGuiTreeNodeFlags.Leaf) ~= 0
    if not is_visible then
        if bit32.band(flags, ImGuiTreeNodeFlags.DrawLinesToNodes) ~= 0 and bit32.band(window.DC.TreeRecordsClippedNodesY2Mask, bit32.lshift(1, (window.DC.TreeDepth - 1))) ~= 0 then
            local parent_data = g.TreeNodeStack.Data[g.TreeNodeStack.Size]
            parent_data.DrawLinesToNodesY2 = ImMax(parent_data.DrawLinesToNodesY2, window.DC.CursorPos.y) -- Don't need to aim to mid Y position as we are clipped anyway.
            if frame_bb.Min.y >= window.ClipRect.Max.y then
                window.DC.TreeRecordsClippedNodesY2Mask = bit32.band(window.DC.TreeRecordsClippedNodesY2Mask, bit32.bnot(bit32.lshift(1, (window.DC.TreeDepth - 1)))) -- Done
            end
        end
        if is_open and store_tree_node_stack_data then
            TreeNodeStoreStackData(flags, text_pos.x - text_offset_x) -- Call before TreePushOverrideID()
        end
        if is_open and bit32.band(flags, ImGuiTreeNodeFlags.NoTreePushOnOpen) == 0 then
            ImGui.TreePushOverrideID(id)
        end
        -- IMGUI_TEST_ENGINE_ITEM_INFO(g.LastItemData.ID, label, g.LastItemData.StatusFlags | (is_leaf ? 0 : ImGuiItemStatusFlags_Openable) | (is_open ? ImGuiItemStatusFlags_Opened : 0))
        return is_open
    end

    if span_all_columns or span_all_columns_label then
        ImGui.TablePushBackgroundChannel()
        g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasClipRect)
        ImRect_Copy(g.LastItemData.ClipRect, window.ClipRect)
    end

    local button_flags = ImGuiTreeNodeFlags.None
    if bit32.band(flags, ImGuiTreeNodeFlags.AllowOverlap) ~= 0 or bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.AllowOverlap) ~= 0 then
        button_flags = bit32.bor(button_flags, ImGuiButtonFlags.AllowOverlap)
    end
    if not is_leaf then
        button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnDragDropHold)
    end

    -- We allow clicking on the arrow section with keyboard modifiers held, in order to easily
    -- allow browsing a tree while preserving selection with code implementing multi-selection patterns.
    -- When clicking on the rest of the tree node we always disallow keyboard modifiers.
    local arrow_hit_x1 = (text_pos.x - text_offset_x) - style.TouchExtraPadding.x
    local arrow_hit_x2 = (text_pos.x - text_offset_x) + (g.FontSize + padding_x * 2.0) + style.TouchExtraPadding.x
    local is_mouse_x_over_arrow = (g.IO.MousePos.x >= arrow_hit_x1 and g.IO.MousePos.x < arrow_hit_x2)

    local is_multi_select = bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.IsMultiSelect) ~= 0
    if is_multi_select then -- We absolutely need to distinguish open vs select so _OpenOnArrow comes by default
        flags = bit32.bor(flags, (bit32.band(flags, ImGuiTreeNodeFlags.OpenOnMask_) == 0) and bit32.bor(ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick) or ImGuiTreeNodeFlags.OpenOnArrow)
    end

    -- Open behaviors can be altered with the _OpenOnArrow and _OnOnDoubleClick flags.
    -- Some alteration have subtle effects (e.g. toggle on MouseUp vs MouseDown events) due to requirements for multi-selection and drag and drop support.
    -- - Single-click on label = Toggle on MouseUp (default, when _OpenOnArrow=0)
    -- - Single-click on arrow = Toggle on MouseDown (when _OpenOnArrow=0)
    -- - Single-click on arrow = Toggle on MouseDown (when _OpenOnArrow=1)
    -- - Double-click on label = Toggle on MouseDoubleClick (when _OpenOnDoubleClick=1)
    -- - Double-click on arrow = Toggle on MouseDoubleClick (when _OpenOnDoubleClick=1 and _OpenOnArrow=0)
    -- It is rather standard that arrow click react on Down rather than Up.
    -- We set ImGuiButtonFlags.PressedOnClickRelease on OpenOnDoubleClick because we want the item to be active on the initial MouseDown in order for drag and drop to work.
    if is_mouse_x_over_arrow then
        button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnClick)
    elseif bit32.band(flags, ImGuiTreeNodeFlags.OpenOnDoubleClick) ~= 0 then
        button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnClickRelease, ImGuiButtonFlags.PressedOnDoubleClick)
    else
        button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnClickRelease)
    end
    if bit32.band(flags, ImGuiTreeNodeFlags.NoNavFocus) ~= 0 then
        button_flags = bit32.bor(button_flags, ImGuiButtonFlags.NoNavFocus)
    end

    local selected = bit32.band(flags, ImGuiTreeNodeFlags.Selected) ~= 0
    local was_selected = selected

    -- Multi-selection support (header)
    if is_multi_select then
        -- Handle multi-select + alter button flags for it
        selected, button_flags = ImGui.MultiSelectItemHeader(id, selected, button_flags)
        if is_mouse_x_over_arrow then
            button_flags = bit32.band(bit32.bor(button_flags, ImGuiButtonFlags.PressedOnClick), bit32.bnot(ImGuiButtonFlags.PressedOnClickRelease))
        end
    else
        if window ~= g.HoveredWindow or not is_mouse_x_over_arrow then
            button_flags = bit32.bor(button_flags, ImGuiButtonFlags.NoKeyModsAllowed)
        end
    end

    local pressed, hovered, held = ImGui.ButtonBehavior(interact_bb, id, button_flags)
    local toggled = false
    if not is_leaf then
        if pressed and g.DragDropHoldJustPressedId ~= id then
            if bit32.band(flags, ImGuiTreeNodeFlags.OpenOnMask_) == 0 or (g.NavActivateId == id and not is_multi_select) then
                toggled = true -- Single click
            end
            if bit32.band(flags, ImGuiTreeNodeFlags.OpenOnArrow) ~= 0 then
                toggled = toggled or (is_mouse_x_over_arrow and not g.NavHighlightItemUnderNav) -- Lightweight equivalent of IsMouseHoveringRect() since ButtonBehavior() already did the job
            end
            if bit32.band(flags, ImGuiTreeNodeFlags.OpenOnDoubleClick) ~= 0 and g.IO.MouseClickedCount[0] == 2 then
                toggled = true -- Double click
            end
        elseif pressed and g.DragDropHoldJustPressedId == id then
            IM_ASSERT(bit32.band(button_flags, ImGuiButtonFlags.PressedOnDragDropHold) ~= 0)
            if not is_open then -- When using Drag and Drop "hold to open" we keep the node highlighted after opening, but never close it again.
                toggled = true
            else
                pressed = false -- Cancel press so it doesn't trigger selection.
            end
        end

        if g.NavId == id and g.NavMoveDir == ImGuiDir.Left and is_open then
            toggled = true
            ImGui.NavClearPreferredPosForAxis(ImGuiAxis.X)
            ImGui.NavMoveRequestCancel()
        end
        if g.NavId == id and g.NavMoveDir == ImGuiDir.Right and not is_open then -- If there's something upcoming on the line we may want to give it the priority?
            toggled = true
            ImGui.NavClearPreferredPosForAxis(ImGuiAxis.X)
            ImGui.NavMoveRequestCancel()
        end

        if toggled then
            is_open = not is_open
            window.DC.StateStorage[storage_id] = is_open
            g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.ToggledOpen)
        end
    end

    -- Multi-selection support (footer)
    if is_multi_select then
        local pressed_copy = pressed and not toggled
        selected, pressed_copy = ImGui.MultiSelectItemFooter(id, selected, pressed_copy)
        if pressed then
            ImGui.SetNavID(id, window.DC.NavLayerCurrent, g.CurrentFocusScopeId, interact_bb)
        end
    end

    if selected ~= was_selected then
        g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.ToggledSelection)
    end

    -- Render
    do
        local text_col = ImGui.GetColorU32(ImGuiCol.Text)
        local nav_render_cursor_flags = ImGuiNavRenderCursorFlags.Compact
        if is_multi_select then
            nav_render_cursor_flags = bit32.bor(nav_render_cursor_flags, ImGuiNavRenderCursorFlags.AlwaysDraw) -- Always show the nav rectangle
        end
        if display_frame then
            -- Framed type
            local bg_col = ImGui.GetColorU32((held and hovered) and ImGuiCol.HeaderActive or (hovered and ImGuiCol.HeaderHovered or ImGuiCol.Header))
            ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, bg_col, true, style.FrameRounding)
            ImGui.RenderNavCursor(frame_bb, id, nav_render_cursor_flags)
            if span_all_columns and not span_all_columns_label then
                ImGui.TablePopBackgroundChannel()
            end
            if bit32.band(flags, ImGuiTreeNodeFlags.Bullet) ~= 0 then
                ImGui.RenderBullet(window.DrawList, TreeNode_tmp_pos(text_pos.x - text_offset_x * 0.60, text_pos.y + g.FontSize * 0.5), text_col)
            elseif not is_leaf then
                ImGui.RenderArrow(window.DrawList, TreeNode_tmp_pos(text_pos.x - text_offset_x + padding_x, text_pos.y), text_col, is_open and ((bit32.band(flags, ImGuiTreeNodeFlags.UpsideDownArrow) ~= 0) and ImGuiDir.Up or ImGuiDir.Down) or ImGuiDir.Right, 1.0)
            else -- Leaf without bullet, left-adjusted text
                text_pos.x = text_pos.x - (text_offset_x - padding_x)
            end
            if bit32.band(flags, ImGuiTreeNodeFlags.ClipLabelForTrailingButton) ~= 0 then
                frame_bb.Max.x = frame_bb.Max.x - (g.FontSize + style.FramePadding.x)
            end
            if g.LogEnabled then
                ImGui.LogSetNextTextDecoration("###", "###")
            end
        else
            -- Unframed typed for tree nodes
            if hovered or selected then
                local bg_col = ImGui.GetColorU32((held and hovered) and ImGuiCol.HeaderActive or (hovered and ImGuiCol.HeaderHovered or ImGuiCol.Header))
                ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, bg_col, false, 0.0)
            end
            ImGui.RenderNavCursor(frame_bb, id, nav_render_cursor_flags, 0.0)
            if span_all_columns and not span_all_columns_label then
                ImGui.TablePopBackgroundChannel()
            end
            if bit32.band(flags, ImGuiTreeNodeFlags.Bullet) ~= 0 then
                ImGui.RenderBullet(window.DrawList, TreeNode_tmp_pos(text_pos.x - text_offset_x * 0.5, text_pos.y + g.FontSize * 0.5), text_col)
            elseif not is_leaf then
                ImGui.RenderArrow(window.DrawList, TreeNode_tmp_pos(text_pos.x - text_offset_x + padding_x, text_pos.y + g.FontSize * 0.15), text_col, is_open and ((bit32.band(flags, ImGuiTreeNodeFlags.UpsideDownArrow) ~= 0) and ImGuiDir.Up or ImGuiDir.Down) or ImGuiDir.Right, 0.70)
            end
            if g.LogEnabled then
                ImGui.LogSetNextTextDecoration(">", nil)
            end
        end

        if draw_tree_lines then
            ImGui.TreeNodeDrawLineToChildNode(TreeNode_tmp_pos(text_pos.x - text_offset_x + padding_x, text_pos.y + g.FontSize * 0.5))
        end

        -- Label
        if display_frame then
            ImGui.RenderTextClipped(text_pos, frame_bb.Max, label, label_end, label_size)
        else
            ImGui.RenderText(text_pos, label, 1, label_end, false)
        end

        if span_all_columns_label then
            ImGui.TablePopBackgroundChannel()
        end
    end

    if is_open and store_tree_node_stack_data then
        TreeNodeStoreStackData(flags, text_pos.x - text_offset_x) -- Call before TreePushOverrideID()
    end
    if is_open and bit32.band(flags, ImGuiTreeNodeFlags.NoTreePushOnOpen) == 0 then
        ImGui.TreePushOverrideID(id) -- Could use TreePush(label) but this avoid computing twice
    end

    -- IMGUI_TEST_ENGINE_ITEM_INFO(id, label, g.LastItemData.StatusFlags | (is_leaf ? 0 : ImGuiItemStatusFlags_Openable) | (is_open ? ImGuiItemStatusFlags_Opened : 0));
    return is_open
end

-- Draw horizontal line from our parent node
-- This is only called for visible child nodes so we are not too fussy anymore about performances
--- @param target_pos ImVec2
function ImGui.TreeNodeDrawLineToChildNode(target_pos)
    local g = GImGui
    local window = g.CurrentWindow
    if window.DC.TreeDepth == 0 or bit32.band(window.DC.TreeHasStackDataDepthMask, bit32.lshift(1, window.DC.TreeDepth - 1)) == 0 then
        return
    end

    -- FIXME: Could this be simplified using new stroke flags?
    local parent_data = g.TreeNodeStack.Data[g.TreeNodeStack.Size]
    local half_size = g.Style.TreeLinesSize * 0.5
    local x1 = ImTrunc(parent_data.DrawLinesX1 - half_size) + half_size -- Draw line centered at X1, but snap to pixels boundary.
    local x2 = ImTrunc(target_pos.x - g.Style.ItemInnerSpacing.x)
    local y = ImTrunc(target_pos.y - half_size) + half_size
    local rounding = (g.Style.TreeLinesRounding > 0.0) and ImMin(x2 - x1, g.Style.TreeLinesRounding) or 0.0
    parent_data.DrawLinesToNodesY2 = ImMax(parent_data.DrawLinesToNodesY2, y - rounding)
    if x1 >= x2 then
        return
    end
    if rounding > 0.0 and rounding > half_size then
        x1 = x1 + rounding
        window.DrawList:PathArcToFast(ImVec2(x1, y - rounding), rounding, 6, 3)
        if x1 < x2 then
            window.DrawList:PathLineTo(ImVec2(x2, y))
        end
        window.DrawList:PathStroke(ImGui.GetColorU32(ImGuiCol.TreeLines), g.Style.TreeLinesSize)
    else
        -- We use AddLine() instead of AddLineH() as we provide coordinates for line center,
        -- in order to make the code use same coordinates for both rounded and non-rounded version. (FIXME-OPT)
        x1 = x1 + half_size -- Avoid overdraw
        window.DrawList:AddLine(ImVec2(x1, y), ImVec2(x2, y), ImGui.GetColorU32(ImGuiCol.TreeLines), g.Style.TreeLinesSize)
    end
end

-- Draw vertical line of the hierarchy
--- @param data ImGuiTreeNodeStackData
function ImGui.TreeNodeDrawLineToTreePop(data)
    local g = GImGui
    local window = g.CurrentWindow
    local y1 = ImMax(data.NavRect.Max.y, window.ClipRect.Min.y)
    local y2 = data.DrawLinesToNodesY2
    if bit32.band(data.TreeFlags, ImGuiTreeNodeFlags.DrawLinesFull) ~= 0 then
        local y2_full = window.DC.CursorPos.y
        if g.CurrentTable then
            y2_full = ImMax(g.CurrentTable.RowPosY2, y2_full)
        end
        y2_full = ImTrunc(y2_full - g.Style.ItemSpacing.y - g.FontSize * 0.5)
        if y2 + (g.Style.ItemSpacing.y + g.Style.TreeLinesRounding) < y2_full then -- FIXME: threshold to use ToNodes Y2 instead of Full Y2 when close by ItemSpacing.y
            y2 = y2_full
        end
    end
    y2 = ImMin(y2, window.ClipRect.Max.y)
    if y2 <= y1 then
        return
    end
    local x = ImTrunc(data.DrawLinesX1 - g.Style.TreeLinesSize * 0.5) + g.Style.TreeLinesSize * 0.5 -- Draw line centered at X1, but snap to pixels boundary.
    if data.DrawLinesTableColumn ~= -1 then
        ImGui.TablePushColumnChannel(data.DrawLinesTableColumn)
    end

    -- We use AddLine() instead of AddLineV() as we provide coordinates for line center (FIXME-OPT)
    window.DrawList:AddLine(ImVec2(x, y1), ImVec2(x, y2), ImGui.GetColorU32(ImGuiCol.TreeLines), g.Style.TreeLinesSize)
    if data.DrawLinesTableColumn ~= -1 then
        ImGui.TablePopColumnChannel()
    end
end

--- @param str_id string|ImGuiID
function ImGui.TreePush(str_id)
    local window = ImGui.GetCurrentWindow()
    ImGui.Indent()
    window.DC.TreeDepth = window.DC.TreeDepth + 1
    ImGui.PushID(str_id)
end

--- @param id ImGuiID
@native
function ImGui.TreePushOverrideID(id)
    local g = GImGui
    local window = g.CurrentWindow
    ImGui.Indent()
    window.DC.TreeDepth = window.DC.TreeDepth + 1
    ImGui.PushOverrideID(id)
end

@native
function ImGui.TreePop()
    local g = GImGui
    local window = g.CurrentWindow
    ImGui.Unindent()

    window.DC.TreeDepth = window.DC.TreeDepth - 1
    local tree_depth_mask = bit32.lshift(1, window.DC.TreeDepth)

    if bit32.band(window.DC.TreeHasStackDataDepthMask, tree_depth_mask) ~= 0 then
        local data = g.TreeNodeStack.Data[g.TreeNodeStack.Size]
        IM_ASSERT(data.ID == window.IDStack:back())

        -- Handle Left arrow to move to parent tree node (when ImGuiTreeNodeFlags.NavLeftJumpsToParent is enabled)
        if bit32.band(data.TreeFlags, ImGuiTreeNodeFlags.NavLeftJumpsToParent) ~= 0 then
            if g.NavIdIsAlive and g.NavMoveDir == ImGuiDir.Left and g.NavWindow == window and ImGui.NavMoveRequestButNoResultYet() then
                ImGui.NavMoveRequestResolveWithPastTreeNode(g.NavMoveResultLocal, data)
            end
        end

        -- Draw hierarchy lines
        if data.DrawLinesX1 ~= FLT_MAX and window.DC.CursorPos.y >= window.ClipRect.Min.y then
            ImGui.TreeNodeDrawLineToTreePop(data)
        end

        g.TreeNodeStack:pop_back()
        window.DC.TreeHasStackDataDepthMask = bit32.band(window.DC.TreeHasStackDataDepthMask, bit32.bnot(tree_depth_mask))
        window.DC.TreeRecordsClippedNodesY2Mask = bit32.band(window.DC.TreeRecordsClippedNodesY2Mask, bit32.bnot(tree_depth_mask))
    end

    IM_ASSERT(window.IDStack.Size > 1) -- There should always be 1 element in the IDStack (pushed during window creation). If this triggers you called TreePop/PopID too much.
    ImGui.PopID()
end

-- Set next TreeNode/CollapsingHeader open state.
--- @param is_open bool
--- @param cond?   ImGuiCond
@native
function ImGui.SetNextItemOpen(is_open, cond)
    if cond == nil then cond = 0 end

    local g = GImGui
    if g.CurrentWindow.SkipItems then
        return
    end
    g.NextItemData.HasFlags = bit32.bor(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasOpen)
    g.NextItemData.OpenVal = is_open
    g.NextItemData.OpenCond = (cond ~= 0) and cond or ImGuiCond.Always
end

-- Horizontal distance preceding label when using TreeNode() or Bullet()
function ImGui.GetTreeNodeToLabelSpacing()
    local g = GImGui
    return g.FontSize + (g.Style.FramePadding.x * 2.0)
end

-- Set next TreeNode/CollapsingHeader storage id.
--- @param storage_id ImGuiID
function ImGui.SetNextItemStorageID(storage_id)
    local g = GImGui
    if g.CurrentWindow.SkipItems then
        return
    end
    g.NextItemData.HasFlags = bit32.bor(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasStorageID)
    g.NextItemData.StorageId = storage_id
end

-- CollapsingHeader returns true when opened but do not indent nor push into the ID stack (because of the ImGuiTreeNodeFlags.NoTreePushOnOpen flag).
-- This is basically the same as calling TreeNodeEx(label, ImGuiTreeNodeFlags.CollapsingHeader). You can remove the _NoTreePushOnOpen flag if you want behavior closer to normal TreeNode().
-- [Port] Overloads: CollapsingHeader(label, flags?) -> is_open
--            CollapsingHeader(label, p_visible: bool, flags?) -> is_open, p_visible
-- p_visible == nil   : regular collapsing header
-- p_visible == true  : show a small close button on the corner of the header, clicking the button will set p_visible = false (returned as 2nd value)
-- p_visible == false : do not show the header at all
-- Do not mistake this with the Open state of the header itself, which you can adjust with SetNextItemOpen() or ImGuiTreeNodeFlags.DefaultOpen.
--- @param label  string
@native
function ImGui.CollapsingHeader(label, a, b)
    local p_visible, flags
    if type(a) == "boolean" then p_visible, flags = a, b else flags = a end
    if flags == nil then flags = 0 end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false, p_visible
    end

    if p_visible == false then
        return false, p_visible
    end

    local id = window:GetID(label)
    flags = bit32.bor(flags, ImGuiTreeNodeFlags.CollapsingHeader)
    if p_visible ~= nil then
        flags = bit32.bor(flags, ImGuiTreeNodeFlags.AllowOverlap, ImGuiTreeNodeFlags.ClipLabelForTrailingButton)
    end
    local is_open = ImGui.TreeNodeBehavior(id, flags, label)
    if p_visible ~= nil then
        -- Create a small overlapping close button
        -- FIXME: We can evolve this into user accessible helpers to add extra buttons on title bars, headers, etc.
        -- FIXME: CloseButton can overlap into text, need find a way to clip the text somehow.
        local g = GImGui
        local last_item_backup = ImGuiLastItemData()
        ImGuiLastItemData_Copy(last_item_backup, g.LastItemData)
        local button_size = g.FontSize
        local button_x = ImMax(g.LastItemData.Rect.Min.x, g.LastItemData.Rect.Max.x - g.Style.FramePadding.x - button_size)
        local button_y = g.LastItemData.Rect.Min.y + g.Style.FramePadding.y
        local close_button_id = ImGui.GetIDWithSeed("#CLOSE", nil, id)
        if ImGui.CloseButton(close_button_id, ImVec2(button_x, button_y)) then
            p_visible = false
        end
        ImGuiLastItemData_Copy(g.LastItemData, last_item_backup)
    end

    return is_open, p_visible
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: Selectable
-------------------------------------------------------------------------------
-- - Selectable()
-------------------------------------------------------------------------------

-- Tip: pass a non-visible label (e.g. "##hello") then you can use the space to draw other text or image.
-- But you need to make sure the ID is unique, e.g. enclose calls in PushID/PopID or use ##unique_id.
-- With this scheme, ImGuiSelectableFlags.SpanAllColumns and ImGuiSelectableFlags.AllowOverlap are also frequently used flags.
-- FIXME: Selectable() with (size.x == 0.0f) and (SelectableTextAlign.x > 0.0f) followed by SameLine() is currently not supported.
--- @param label     string
--- @param selected? bool
--- @param flags?    ImGuiSelectableFlags
--- @param size_arg? any
--- @return bool is_pressed
--- @return bool is_selected # Updated `selected`
-- [Luau] scratch for Selectable(): only read by its callees (ItemAdd() copies bb), never escape
local Selectable_label_size, Selectable_size, Selectable_pos, Selectable_pos_max, Selectable_bb = ImVec2(), ImVec2(), ImVec2(), ImVec2(), ImRect()
@native
function ImGui.Selectable(label, selected, flags, size_arg)
    if selected == nil then selected = false        end
    if flags    == nil then flags    = 0            end
    if size_arg == nil then size_arg = LAYOUT_ZERO_SIZE end -- [Luau] shared read-only default (only read below)

    local window = ImGui.GetCurrentWindow()
    if (window.SkipItems) then
        return false, selected
    end

    local g = GImGui
    local style = g.Style

    -- Submit label or explicit size to ItemSize(), whereas ItemAdd() will submit a larger/spanning rectangle.
    local id = window:GetID(label)
    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size = Selectable_label_size
    label_size.x, label_size.y = ImGui.CalcTextSizeXY(label, 1, label_end, false)
    local size = Selectable_size
    size.x = (size_arg.x ~= 0.0) and size_arg.x or label_size.x
    size.y = (size_arg.y ~= 0.0) and size_arg.y or label_size.y

    local pos = Selectable_pos
    ImVec2_Copy(pos, window.DC.CursorPos)
    pos.y = pos.y + window.DC.CurrLineTextBaseOffset

    ImGui.ItemSize(size, 0.0)

    -- Fill horizontal space
    -- We don't support (size < 0.0) in Selectable() because the ItemSpacing extension would make explicitly right-aligned sizes not visibly match other widgets.
    local span_all_columns = bit32.band(flags, ImGuiSelectableFlags.SpanAllColumns) ~= 0
    local min_x = span_all_columns and window.ParentWorkRect.Min.x or pos.x
    local max_x = span_all_columns and window.ParentWorkRect.Max.x or window.WorkRect.Max.x
    if size_arg.x == 0.0 or bit32.band(flags, ImGuiSelectableFlags.SpanAvailWidth) ~= 0 then
        size.x = ImMax(label_size.x, max_x - min_x)
    end

    -- Selectables are meant to be tightly packed together with no click-gap, so we extend their box to cover spacing between selectable.
    -- FIXME: Not part of layout so not included in clipper calculation, but ItemSize currently doesn't allow offsetting CursorPos.
    local bb = Selectable_bb
    bb.Min.x = min_x; bb.Min.y = pos.y; bb.Max.x = min_x + size.x; bb.Max.y = pos.y + size.y
    if bit32.band(flags, ImGuiSelectableFlags.NoPadWithHalfSpacing) == 0 then
        local spacing_x = span_all_columns and 0.0 or style.ItemSpacing.x
        local spacing_y = style.ItemSpacing.y
        local spacing_L = IM_TRUNC(spacing_x * 0.50)
        local spacing_U = IM_TRUNC(spacing_y * 0.50)

        bb.Min.x = bb.Min.x - spacing_L
        bb.Min.y = bb.Min.y - spacing_U
        bb.Max.x = bb.Max.x + (spacing_x - spacing_L)
        bb.Max.y = bb.Max.y + (spacing_y - spacing_U)
    end
    -- if g.IO.KeyCtrl then ImGui.GetForegroundDrawList():AddRect(bb.Min, bb.Max, IM_COL32(0, 255, 0, 255)) end

    local disabled_item = bit32.band(flags, ImGuiSelectableFlags.Disabled) ~= 0
    local extra_item_flags = disabled_item and ImGuiItemFlags.Disabled or ImGuiItemFlags.None

    local is_visible
    if span_all_columns then
        -- Modify ClipRect for the ItemAdd(), faster than doing a PushColumnsBackground/PushTableBackgroundChannel for every Selectable..
        local backup_clip_rect_min_x = window.ClipRect.Min.x
        local backup_clip_rect_max_x = window.ClipRect.Max.x

        window.ClipRect.Min.x = window.ParentWorkRect.Min.x
        window.ClipRect.Max.x = window.ParentWorkRect.Max.x

        is_visible = ImGui.ItemAdd(bb, id, nil, extra_item_flags)

        window.ClipRect.Min.x = backup_clip_rect_min_x
        window.ClipRect.Max.x = backup_clip_rect_max_x
    else
        is_visible = ImGui.ItemAdd(bb, id, nil, extra_item_flags)
    end

    local is_multi_select = bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.IsMultiSelect) ~= 0

    if not is_visible then
        if not is_multi_select or not g.BoxSelectState.UnclipMode or not g.BoxSelectState.UnclipRect:Overlaps(bb) then -- Extra layer of "no logic clip" for box-select support (would be more overhead to add to ItemAdd)
            return false, selected
        end
    end

    local disabled_global = bit32.band(g.CurrentItemFlags, ImGuiItemFlags.Disabled) ~= 0

    if disabled_item and not disabled_global then -- Only testing this as an optimization
        ImGui.BeginDisabled()
    end

    -- FIXME: We can standardize the behavior of those two, we could also keep the fast path of override ClipRect + full push on render only,
    -- which would be advantageous since most selectable are not selected.
    if span_all_columns then
        if g.CurrentTable then
            ImGui.TablePushBackgroundChannel()
        elseif window.DC.CurrentColumns then
            ImGui.PushColumnsBackground()
        end

        g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasClipRect)
        ImRect_Copy(g.LastItemData.ClipRect, window.ClipRect)
    end

    -- We use NoHoldingActiveID on menus so user can click and _hold_ on a menu then drag to browse child entries
    local button_flags = 0
    if bit32.band(flags, ImGuiSelectableFlags.NoHoldingActiveID) ~= 0 then button_flags = bit32.bor(button_flags, ImGuiButtonFlags.NoHoldingActiveId) end
    if bit32.band(flags, ImGuiSelectableFlags.NoSetKeyOwner)     ~= 0 then button_flags = bit32.bor(button_flags, ImGuiButtonFlags.NoSetKeyOwner) end
    if bit32.band(flags, ImGuiSelectableFlags.SelectOnClick)     ~= 0 then button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnClick) end
    if bit32.band(flags, ImGuiSelectableFlags.SelectOnRelease)   ~= 0 then button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnRelease) end
    if bit32.band(flags, ImGuiSelectableFlags.AllowDoubleClick)  ~= 0 then button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnClickRelease, ImGuiButtonFlags.PressedOnDoubleClick) end
    if bit32.band(flags, ImGuiSelectableFlags.AllowOverlap) ~= 0 or bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.AllowOverlap) ~= 0 then button_flags = bit32.bor(button_flags, ImGuiButtonFlags.AllowOverlap) end

    -- Multi-selection support (header)
    local was_selected = selected
    if is_multi_select then
        -- Handle multi-select + alter button flags for it
        selected, button_flags = ImGui.MultiSelectItemHeader(id, selected, button_flags)
    end

    local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, button_flags)
    local auto_selected = false

    -- Multi-selection support (footer)
    if is_multi_select then
        selected, pressed = ImGui.MultiSelectItemFooter(id, selected, pressed)
    else
        -- Auto-select when moved into
        -- - This will be more fully fleshed in the range-select branch
        -- - This is not exposed as it won't nicely work with some user side handling of shift/control
        -- - We cannot do 'if (g.NavJustMovedToId != id) { selected = false; pressed = was_selected; }' for two reasons
        --   - (1) it would require focus scope to be set, need exposing PushFocusScope() or equivalent (e.g. BeginSelection() calling PushFocusScope())
        --   - (2) usage will fail with clipped items
        --   The multi-select API aim to fix those issues, e.g. may be replaced with a BeginSelection() API.
        if bit32.band(flags, ImGuiSelectableFlags.SelectOnNav) ~= 0 and g.NavJustMovedToId ~= 0 and g.NavJustMovedToFocusScopeId == g.CurrentFocusScopeId then
            if g.NavJustMovedToId == id and bit32.band(g.NavJustMovedToKeyMods, ImGuiMod_Ctrl) == 0 then
                selected = true
                pressed = true
                auto_selected = true
            end
        end
    end

    -- Update NavId when clicking or when Hovering (this doesn't happen on most widgets), so navigation can be resumed with keyboard/gamepad
    if pressed or (hovered and bit32.band(flags, ImGuiSelectableFlags.SetNavIdOnHover) ~= 0) then
        if not g.NavHighlightItemUnderNav and g.NavWindow == window and g.NavLayer == window.DC.NavLayerCurrent then
            ImGui.SetNavID(id, window.DC.NavLayerCurrent, g.CurrentFocusScopeId, ImGui.WindowRectAbsToRel(window, bb)) -- (bb == NavRect)
            if g.IO.ConfigNavCursorVisibleAuto then
                g.NavCursorVisible = false
            end
        end
    end
    if pressed then
        ImGui.MarkItemEdited(id)
    end

    if selected ~= was_selected then
        g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.ToggledSelection)
    end
    if g.ActiveId == id and g.ActiveIdIsJustActivated then
        g.ActiveIdWasSelected = was_selected
        g.ActiveIdWasSoleSelected = was_selected and (not is_multi_select or g.CurrentMultiSelect.IsSoleOrUnknownSelectionSize)
    end

    -- Render
    if is_visible then
        local highlighted = hovered or (bit32.band(flags, ImGuiSelectableFlags.Highlight) ~= 0)

        if highlighted or selected then
            -- Between 1.91.0 and 1.91.4 we made selected Selectable use an arbitrary lerp between _Header and _HeaderHovered. Removed that now. (#8106)
            local col
            if held and highlighted then
                col = ImGui.GetColorU32(ImGuiCol.HeaderActive)
            elseif highlighted then
                col = ImGui.GetColorU32(ImGuiCol.HeaderHovered)
            else
                col = ImGui.GetColorU32(ImGuiCol.Header)
            end
            ImGui.RenderFrame(bb.Min, bb.Max, col, false, style.SelectableRounding)
        end

        if g.NavId == id then
            local nav_render_cursor_flags = ImGuiNavRenderCursorFlags.Compact
            if is_multi_select then
                nav_render_cursor_flags = bit32.bor(nav_render_cursor_flags, ImGuiNavRenderCursorFlags.AlwaysDraw) -- Always show the nav rectangle
            end
            ImGui.RenderNavCursor(bb, id, nav_render_cursor_flags, style.SelectableRounding)
        end
    end

    if span_all_columns then
        if g.CurrentTable then
            ImGui.TablePopBackgroundChannel()
        elseif window.DC.CurrentColumns then
            ImGui.PopColumnsBackground()
        end
    end

    -- Text stays at the submission position. Alignment/clipping extents ignore SpanAllColumns.
    if is_visible then
        local pos_max = Selectable_pos_max
        pos_max.x = ImMin(pos.x + size.x, window.WorkRect.Max.x); pos_max.y = pos.y + size.y
        ImGui.RenderTextClipped(pos, pos_max, label, label_end, label_size, style.SelectableTextAlign, bb)
    end

    -- Automatically close popups
    if pressed and not auto_selected and bit32.band(window.Flags, ImGuiWindowFlags.Popup) ~= 0 and bit32.band(flags, ImGuiSelectableFlags.NoAutoClosePopups) == 0 and bit32.band(g.LastItemData.ItemFlags, ImGuiItemFlags.AutoClosePopups) ~= 0 then
        ImGui.CloseCurrentPopup()
    end

    if disabled_item and not disabled_global then
        ImGui.EndDisabled()
    end

    -- Selectable() always returns a pressed state!
    -- Users of BeginMultiSelect()/EndMultiSelect() scope: you may call ImGui.IsItemToggledSelection() to retrieve
    -- selection toggle, only useful if you need that state updated (e.g. for rendering purpose) before reaching EndMultiSelect().
    return pressed, selected
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: Typing-Select support
-------------------------------------------------------------------------------

do -- [Port] Typing-Select, Box-Select, Multi-Select sections: locals kept private

local MT = ImGui.GetMetatables()

local TypingSelectCharBuf = { 0, 0, 0, 0, 0 } -- [Luau] scratch for ImTextCharToUtf8() (C++: char w_buf[5])

-- [Experimental] Currently not exposed in public API.
-- Consume character inputs and return search request, if any.
-- This would typically only be called on the focused window or location you want to grab inputs for, e.g.
--   if ImGui.IsWindowFocused(...) then
--       local req = ImGui.GetTypingSelectRequest()
--       if req then focus_idx = ImGui.TypingSelectFindMatch(req, #my_items, function(user_data, n) return my_items[n + 1].Name end, my_items, -1) end
-- However the code is written in a way where calling it from multiple locations is safe (e.g. to obtain buffer).
-- [Port] Item indices passed to get_item_name_func(user_data, idx) and returned by TypingSelectFind*() are 0-based like upstream (-1 = none).
--- @param flags? ImGuiTypingSelectFlags
--- @return ImGuiTypingSelectRequest?
function ImGui.GetTypingSelectRequest(flags)
    if flags == nil then flags = ImGuiTypingSelectFlags.None end
    local g = GImGui
    local data = g.TypingSelectState
    local out_request = data.Request

    -- Clear buffer
    local TYPING_SELECT_RESET_TIMER = 1.80           -- FIXME: Potentially move to IO config.
    local TYPING_SELECT_SINGLE_CHAR_COUNT_FOR_LOCK = 4 -- Lock single char matching when repeating same char 4 times
    if #data.SearchBuffer ~= 0 then
        local clear_buffer = false
        clear_buffer = clear_buffer or (g.NavFocusScopeId ~= data.FocusScope)
        clear_buffer = clear_buffer or (data.LastRequestTime + TYPING_SELECT_RESET_TIMER < g.Time)
        clear_buffer = clear_buffer or g.NavAnyRequest
        clear_buffer = clear_buffer or (g.ActiveId ~= 0 and g.NavActivateId == 0) -- Allow temporary SPACE activation to not interfere
        clear_buffer = clear_buffer or ImGui.IsKeyPressed(ImGuiKey.Escape) or ImGui.IsKeyPressed(ImGuiKey.Enter)
        clear_buffer = clear_buffer or (ImGui.IsKeyPressed(ImGuiKey.Backspace) and bit32.band(flags, ImGuiTypingSelectFlags.AllowBackspace) == 0)
        --if clear_buffer then IMGUI_DEBUG_LOG("GetTypingSelectRequest(): Clear SearchBuffer.\n") end
        if clear_buffer then
            data:Clear()
        end
    end

    -- Append to buffer
    local buffer_max_len = 64 - 1 -- [Port] IM_COUNTOF(data->SearchBuffer) - 1
    local buffer_len = #data.SearchBuffer
    local select_request = false
    local input_queue = g.IO.InputQueueCharacters
    for n = 1, input_queue.Size do
        repeat
            local w = input_queue.Data[n]
            local w_buf = TypingSelectCharBuf
            local w_len = ImStd.ImTextCharToUtf8(w_buf, w) -- [Port] also gives ImTextCountUtf8BytesFromStr(&w, &w + 1)
            if w < 32 or (buffer_len == 0 and ImCharIsBlankW(w)) or (buffer_len + w_len > buffer_max_len) then -- Ignore leading blanks
                break -- continue
            end
            local w_str = string.char(table.unpack(w_buf, 1, w_len))
            if data.SingleCharModeLock and w_len == out_request.SingleCharSize and string.sub(data.SearchBuffer, 1, w_len) == w_str then
                select_request = true -- Same character: don't need to append to buffer.
                break -- continue
            end
            if data.SingleCharModeLock then
                data:Clear() -- Different character: clear
                buffer_len = 0
            end
            data.SearchBuffer = string.sub(data.SearchBuffer, 1, buffer_len) .. w_str -- Append
            buffer_len = buffer_len + w_len
            select_request = true
        until true
    end
    input_queue:resize(0)

    -- Handle backspace
    if bit32.band(flags, ImGuiTypingSelectFlags.AllowBackspace) ~= 0 and ImGui.IsKeyPressedEx(ImGuiKey.Backspace, ImGuiInputFlags.Repeat) then
        local p = ImStd.ImTextFindPreviousUtf8Codepoint(data.SearchBuffer, 1, buffer_len + 1) -- [Port] 1-based byte position
        data.SearchBuffer = string.sub(data.SearchBuffer, 1, p - 1)
        buffer_len = p - 1
    end

    -- Return request if any
    if buffer_len == 0 then
        return nil
    end
    if select_request then
        data.FocusScope = g.NavFocusScopeId
        data.LastRequestFrame = g.FrameCount
        data.LastRequestTime = g.Time
    end
    out_request.Flags = flags
    out_request.SearchBufferLen = buffer_len
    out_request.SearchBuffer = data.SearchBuffer
    out_request.SelectRequest = (data.LastRequestFrame == g.FrameCount)
    out_request.SingleCharMode = false
    out_request.SingleCharSize = 0

    -- Calculate if buffer contains the same character repeated.
    -- - This can be used to implement a special search mode on first character.
    -- - Performed on UTF-8 codepoint for correctness.
    -- - SingleCharMode is always set for first input character, because it usually leads to a "next".
    if bit32.band(flags, ImGuiTypingSelectFlags.AllowSingleCharMode) ~= 0 then
        local buf = out_request.SearchBuffer
        local buf_begin = 1
        local buf_end = buf_begin + out_request.SearchBufferLen
        local c0_len = ImStd.ImTextCountUtf8BytesFromChar(buf, buf_begin, buf_end)
        local c0 = string.sub(buf, buf_begin, buf_begin + c0_len - 1)
        local p = buf_begin + c0_len
        while p < buf_end do
            if string.sub(buf, p, p + c0_len - 1) ~= c0 then -- memcmp(buf_begin, p, c0_len) != 0
                break
            end
            p = p + c0_len
        end
        local single_char_count = (p == buf_end) and math.floor(out_request.SearchBufferLen / c0_len) or 0
        out_request.SingleCharMode = (single_char_count > 0 or data.SingleCharModeLock)
        out_request.SingleCharSize = c0_len
        data.SingleCharModeLock = data.SingleCharModeLock or (single_char_count >= TYPING_SELECT_SINGLE_CHAR_COUNT_FOR_LOCK) -- From now on we stop search matching to lock to single char mode.
    end

    return out_request
end

-- [Port] s1 is the byte range [s1_begin, s1_end) of string s1, s2 is a whole string (out of range bytes read as 0 like a C terminator).
local function ImStrimatchlen(s1, s1_begin, s1_end, s2)
    local match_len = 0
    local s2_p = 1
    while s1_begin < s1_end and ImToUpper(string.byte(s1, s1_begin)) == ImToUpper(string.byte(s2, s2_p) or 0) do
        s1_begin = s1_begin + 1
        s2_p = s2_p + 1
        match_len = match_len + 1
    end
    return match_len
end

-- Default handler for finding a result for typing-select. You may implement your own.
-- You might want to display a tooltip to visualize the current request SearchBuffer
-- When SingleCharMode is set:
-- - it is better to NOT display a tooltip of other on-screen display indicator.
-- - the index of the currently focused item is required.
--   if your SetNextItemSelectionUserData() values are indices, you can obtain it from ImGuiMultiSelectIO.NavIdItem, otherwise from g.NavLastValidSelectionUserData.
--- @param req                ImGuiTypingSelectRequest?
--- @param items_count        int
--- @param get_item_name_func fun(user_data: any, idx: int): string # idx is 0-based
--- @param user_data          any
--- @param nav_item_idx       int # 0-based, -1 if unknown
--- @return int # 0-based, -1 if none
function ImGui.TypingSelectFindMatch(req, items_count, get_item_name_func, user_data, nav_item_idx)
    if req == nil or req.SelectRequest == false then -- Support NULL parameter so both calls can be done from same spot.
        return -1
    end
    local idx = -1
    if req.SingleCharMode and bit32.band(req.Flags, ImGuiTypingSelectFlags.AllowSingleCharMode) ~= 0 then
        idx = ImGui.TypingSelectFindNextSingleCharMatch(req, items_count, get_item_name_func, user_data, nav_item_idx)
    else
        idx = ImGui.TypingSelectFindBestLeadingMatch(req, items_count, get_item_name_func, user_data)
    end
    if idx ~= -1 then
        ImGui.SetNavCursorVisibleAfterMove()
    end
    return idx
end

-- Special handling when a single character is repeated: perform search on a single letter and goes to next.
function ImGui.TypingSelectFindNextSingleCharMatch(req, items_count, get_item_name_func, user_data, nav_item_idx)
    -- FIXME: Assume selection user data is index. Would be extremely practical.
    --if nav_item_idx == -1 then
    --    nav_item_idx = g.NavLastValidSelectionUserData
    --end

    local first_match_idx = -1
    local return_next_match = false
    for idx = 0, items_count - 1 do
        repeat
            local item_name = get_item_name_func(user_data, idx)
            if ImStrimatchlen(req.SearchBuffer, 1, 1 + req.SingleCharSize, item_name) < req.SingleCharSize then
                break -- continue
            end
            if return_next_match then                           -- Return next matching item after current item.
                return idx
            end
            if first_match_idx == -1 and nav_item_idx == -1 then -- Return first match immediately if we don't have a nav_item_idx value.
                return idx
            end
            if first_match_idx == -1 then                       -- Record first match for wrapping.
                first_match_idx = idx
            end
            if nav_item_idx == idx then                         -- Record that we encountering nav_item so we can return next match.
                return_next_match = true
            end
        until true
    end
    return first_match_idx -- First result
end

function ImGui.TypingSelectFindBestLeadingMatch(req, items_count, get_item_name_func, user_data)
    local longest_match_idx = -1
    local longest_match_len = 0
    for idx = 0, items_count - 1 do
        local item_name = get_item_name_func(user_data, idx)
        local match_len = ImStrimatchlen(req.SearchBuffer, 1, 1 + req.SearchBufferLen, item_name)
        if match_len > longest_match_len then -- [Port] inverted 'if (match_len <= longest_match_len) continue;'
            longest_match_idx = idx
            longest_match_len = match_len
            if match_len == req.SearchBufferLen then
                break
            end
        end
    end
    return longest_match_idx
end

--- @param data ImGuiTypingSelectState
function ImGui.DebugNodeTypingSelectState(data)
    ImGui.Text("SearchBuffer = \"%s\"", data.SearchBuffer)
    ImGui.Text("SingleCharMode = %d, Size = %d, Lock = %d", data.Request.SingleCharMode and 1 or 0, data.Request.SingleCharSize, data.SingleCharModeLock and 1 or 0)
    ImGui.Text("LastRequest = time: %.2f, frame: %d", data.LastRequestTime, data.LastRequestFrame)
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: Box-Select support
-- This has been extracted away from Multi-Select logic in the hope that it could eventually be used elsewhere, but hasn't been yet.
-------------------------------------------------------------------------------
-- Extra logic in MultiSelectItemFooter() and ImGuiListClipper:Step()
-------------------------------------------------------------------------------
-- - BoxSelectPreStartDrag() [Internal]
-- - BoxSelectActivateDrag() [Internal]
-- - BoxSelectDeactivateDrag() [Internal]
-- - BoxSelectScrollWithMouseDrag() [Internal]
-- - BeginBoxSelect() [Internal]
-- - EndBoxSelect() [Internal]
-------------------------------------------------------------------------------

-- Call on the initial click.
local function BoxSelectPreStartDrag(id, clicked_item)
    local g = GImGui
    local bs = g.BoxSelectState
    bs.ID = id
    bs.IsStarting = true -- Consider starting box-select.
    bs.IsStartedFromVoid = (clicked_item == ImGuiSelectionUserData_Invalid)
    bs.IsStartedSetNavIdOnce = bs.IsStartedFromVoid
    bs.KeyMods = g.IO.KeyMods
    local off = g.CurrentWindow.DC.CursorStartPos -- [Luau] inline WindowPosAbsToRel(g.CurrentWindow, g.IO.MousePos)
    ImVec2_CopyV(bs.StartPosRel, g.IO.MousePos.x - off.x, g.IO.MousePos.y - off.y)
    ImVec2_Copy(bs.EndPosRel, bs.StartPosRel)
    ImVec2_CopyV(bs.ScrollAccum, 0.0, 0.0)
end

local function BoxSelectActivateDrag(bs, window)
    local g = GImGui
    IMGUI_DEBUG_LOG_SELECTION("[selection] BeginBoxSelect() 0X%08X: Activate\n", bs.ID)
    bs.IsActive = true
    bs.Window = window
    bs.IsStarting = false
    ImGui.SetActiveID(bs.ID, window)
    ImGui.SetActiveIdUsingAllKeyboardKeys()
    if bs.IsStartedFromVoid and bit32.band(bs.KeyMods, bit32.bor(ImGuiMod_Ctrl, ImGuiMod_Shift)) == 0 then
        bs.RequestClear = true
    end
end

local function BoxSelectDeactivateDrag(bs)
    local g = GImGui
    bs.IsActive = false; bs.IsStarting = false
    if g.ActiveId == bs.ID then
        IMGUI_DEBUG_LOG_SELECTION("[selection] BeginBoxSelect() 0X%08X: Deactivate\n", bs.ID)
        ImGui.ClearActiveID()
    end
    bs.ID = 0
end

local function BoxSelectScrollWithMouseDrag(bs, window, inner_r)
    local g = GImGui
    IM_ASSERT(bs.Window == window)
    for n = 1, 2 do -- each axis -- [Port] 1 = X, 2 = Y
        repeat
            local k = (n == 1) and "x" or "y"
            local mouse_pos = g.IO.MousePos[k]
            local dist = (mouse_pos > inner_r.Max[k]) and mouse_pos - inner_r.Max[k] or (mouse_pos < inner_r.Min[k]) and mouse_pos - inner_r.Min[k] or 0.0
            local scroll_curr = window.Scroll[k]
            if dist == 0.0 or (dist < 0.0 and scroll_curr < 0.0) or (dist > 0.0 and scroll_curr >= window.ScrollMax[k]) then
                break -- continue
            end

            local speed_multiplier = ImLinearRemapClamp(g.FontSize, g.FontSize * 5.0, 1.0, 4.0, ImAbs(dist)) -- x1 to x4 depending on distance
            local scroll_step = g.FontSize * 35.0 * speed_multiplier * ImSign(dist) * g.IO.DeltaTime
            bs.ScrollAccum[k] = bs.ScrollAccum[k] + scroll_step

            -- Accumulate into a stored value so we can handle high-framerate
            local scroll_step_i = ImFloor(bs.ScrollAccum[k])
            if scroll_step_i == 0.0 then
                break -- continue
            end
            if n == 1 then
                ImGui.SetScrollX(window, scroll_curr + scroll_step_i)
            else
                ImGui.SetScrollY(window, scroll_curr + scroll_step_i)
            end
            bs.ScrollAccum[k] = bs.ScrollAccum[k] - scroll_step_i
        until true
    end
end

--- @param scope_rect    ImRect
--- @param window        ImGuiWindow
--- @param box_select_id ImGuiID
--- @param ms_flags      ImGuiMultiSelectFlags
--- @return bool
function ImGui.BeginBoxSelect(scope_rect, window, box_select_id, ms_flags)
    local g = GImGui
    local bs = g.BoxSelectState
    ImGui.KeepAliveID(box_select_id)
    if bs.ID ~= box_select_id then
        return false
    end

    -- IsStarting is set by MultiSelectItemFooter() when considering a possible box-select. We validate it here and lock geometry.
    bs.UnclipMode = false
    bs.RequestClear = false
    if bs.IsStarting and ImGui.IsMouseDragPastThreshold(0) then
        BoxSelectActivateDrag(bs, window)
    elseif (bs.IsStarting or bs.IsActive) and g.IO.MouseDown[0] == false then
        BoxSelectDeactivateDrag(bs)
    end
    if not bs.IsActive then
        return false
    end

    -- Current frame absolute prev/current rectangles are used to toggle selection.
    -- They are derived from positions relative to scrolling space, so "previous" rectangle is reprojected for current frame coordinates.
    -- [Luau] scalar versions of WindowPosRelToAbs()/ImClamp()/ImMin()/ImMax() (no temporary ImVec2)
    local off = window.DC.CursorStartPos
    local start_pos_abs_x, start_pos_abs_y = bs.StartPosRel.x + off.x, bs.StartPosRel.y + off.y
    local prev_end_pos_abs_x, prev_end_pos_abs_y = bs.EndPosRel.x + off.x, bs.EndPosRel.y + off.y -- Clamped already
    local curr_end_pos_abs_x, curr_end_pos_abs_y = g.IO.MousePos.x, g.IO.MousePos.y
    if bit32.band(ms_flags, ImGuiMultiSelectFlags.ScopeWindow) ~= 0 then -- Box-select scrolling only happens with ScopeWindow
        curr_end_pos_abs_x = ImClamp(curr_end_pos_abs_x, scope_rect.Min.x, scope_rect.Max.x)
        curr_end_pos_abs_y = ImClamp(curr_end_pos_abs_y, scope_rect.Min.y, scope_rect.Max.y)
    end
    ImVec2_CopyV(bs.BoxSelectRectPrev.Min, ImMin(start_pos_abs_x, prev_end_pos_abs_x), ImMin(start_pos_abs_y, prev_end_pos_abs_y))
    ImVec2_CopyV(bs.BoxSelectRectPrev.Max, ImMax(start_pos_abs_x, prev_end_pos_abs_x), ImMax(start_pos_abs_y, prev_end_pos_abs_y))
    ImVec2_CopyV(bs.BoxSelectRectCurr.Min, ImMin(start_pos_abs_x, curr_end_pos_abs_x), ImMin(start_pos_abs_y, curr_end_pos_abs_y))
    ImVec2_CopyV(bs.BoxSelectRectCurr.Max, ImMax(start_pos_abs_x, curr_end_pos_abs_x), ImMax(start_pos_abs_y, curr_end_pos_abs_y))
    --IMGUI_DEBUG_LOG("StartPosRel (%.2f,%.2f) EndPosRel (%.2f,%.2f) -> (%.2f,%.2f)\n", bs.StartPosRel.x, bs.StartPosRel.y, bs.EndPosRel.x, bs.EndPosRel.y, WindowPosAbsToRel(window, g.IO.MousePos).x, WindowPosAbsToRel(window, g.IO.MousePos).y)

    -- Box-select 2D mode detects change of the rectangle.
    -- Storing unclip rects which will be tested by widgets supporting box-select. Always update rectangles when active (even if we don't use them).
    -- To facilitate understanding this: enable IMGUI_DEBUG_BOXSELECT and visualize all geometry.
    if bit32.band(ms_flags, bit32.bor(ImGuiMultiSelectFlags.BoxSelect1d, ImGuiMultiSelectFlags.BoxSelect2d)) ~= 0 then
        -- For both sides, compute the area differing between Prev and Curr rectangles.
        local unclip_x, unclip_y = bs.UnclipRects[1], bs.UnclipRects[2] -- [Port] UnclipRects[0], UnclipRects[1]
        ImVec2_CopyV(unclip_x.Min, FLT_MAX, FLT_MAX); ImVec2_CopyV(unclip_x.Max, -FLT_MAX, -FLT_MAX)
        ImVec2_CopyV(unclip_y.Min, FLT_MAX, FLT_MAX); ImVec2_CopyV(unclip_y.Max, -FLT_MAX, -FLT_MAX)
        local curr, prev = bs.BoxSelectRectCurr, bs.BoxSelectRectPrev
        for side = 0, 1 do
            local a = (side == 0) and curr.Min or curr.Max
            local b = (side == 0) and prev.Min or prev.Max
            local d_min_x, d_min_y = ImMin(a.x, b.x), ImMin(a.y, b.y)
            local d_max_x, d_max_y = ImMax(a.x, b.x), ImMax(a.y, b.y)
            if d_min_x ~= d_max_x then
                unclip_x:AddX(d_min_x)
                unclip_x:AddX(d_max_x)
            end
            if d_min_y ~= d_max_y then
                unclip_y:AddY(d_min_y)
                unclip_y:AddY(d_max_y)
            end
        end

        -- [Port] box_select_intersection = BoxSelectRectPrev + BoxSelectRectCurr
        local box_select_intersection_min_x, box_select_intersection_min_y = ImMin(prev.Min.x, curr.Min.x), ImMin(prev.Min.y, curr.Min.y)
        local box_select_intersection_max_x, box_select_intersection_max_y = ImMax(prev.Max.x, curr.Max.x), ImMax(prev.Max.y, curr.Max.y)
        if bit32.band(ms_flags, ImGuiMultiSelectFlags.BoxSelect2d) ~= 0 then
            if prev.Min.x ~= curr.Min.x or prev.Max.x ~= curr.Max.x then
                unclip_x:AddY(box_select_intersection_min_y)
                unclip_x:AddY(box_select_intersection_max_y)
            end
        end
        if bit32.band(ms_flags, bit32.bor(ImGuiMultiSelectFlags.BoxSelect1d, ImGuiMultiSelectFlags.BoxSelect2d)) ~= 0 then
            if prev.Min.y ~= curr.Min.y or prev.Max.y ~= curr.Max.y then
                unclip_y:AddX(box_select_intersection_min_x)
                unclip_y:AddX(box_select_intersection_max_x)
            end
        end

        -- Merge both rectangles into one.
        -- FIXME-OPT: When UnclipRect.Area() is much larger than the sum of UnclipRects[0]/[1] Areas, widgets should
        -- ideally first use UnclipRect as a first coarse cull layer + the individual ones as a second validation.
        ImRect_Copy(bs.UnclipRect, unclip_x)
        bs.UnclipRect:Add(unclip_y)
        if not bs.UnclipRect:IsInverted() and (not window.ClipRect:Contains(bs.UnclipRect.Min) or not window.ClipRect:Contains(bs.UnclipRect.Max)) then -- !! Don't use Contains(ImRect)
            bs.UnclipMode = true
        end
        if bs.UnclipMode and g.CurrentTable ~= nil then
            ImGui.TableApplyExternalUnclipRect(g.CurrentTable, bs.UnclipRect) -- No need submitting both
        end
    end

    -- [Port] IMGUI_DEBUG_BOXSELECT visualization not ported (compile-time debug option, disabled upstream).
    return true
end

--- @param scope_rect ImRect
--- @param ms_flags   ImGuiMultiSelectFlags
function ImGui.EndBoxSelect(scope_rect, ms_flags)
    local g = GImGui
    local window = g.CurrentWindow
    local bs = g.BoxSelectState
    IM_ASSERT(bs.IsActive)
    bs.UnclipMode = false

    -- Render selection rectangle
    bs.EndPosRel = ImGui.WindowPosAbsToRel(window, ImClamp(g.IO.MousePos, scope_rect.Min, scope_rect.Max)) -- Clamp stored position according to current scrolling view
    local box_select_r = ImRect(bs.BoxSelectRectCurr.Min, bs.BoxSelectRectCurr.Max)
    box_select_r:ClipWith(scope_rect)
    local draw_window = ImGui.FindFrontMostVisibleChildWindow(window)
    draw_window.DrawList:AddRectFilled(box_select_r.Min, box_select_r.Max, ImGui.GetColorU32(ImGuiCol.SeparatorHovered, 0.30)) -- FIXME-MULTISELECT: Styling
    draw_window.DrawList:AddRect(box_select_r.Min, box_select_r.Max, ImGui.GetColorU32(ImGuiCol.NavCursor)) -- FIXME-MULTISELECT FIXME-DPI: Styling

    -- Scroll
    local enable_scroll = bit32.band(ms_flags, ImGuiMultiSelectFlags.ScopeWindow) ~= 0 and bit32.band(ms_flags, ImGuiMultiSelectFlags.BoxSelectNoScroll) == 0
    if enable_scroll then
        local scroll_r = ImRect(scope_rect.Min, scope_rect.Max)
        scroll_r:Expand(-g.FontSize)
        --GetForegroundDrawList():AddRect(scroll_r.Min, scroll_r.Max, IM_COL32(0, 255, 0, 255))
        if not scroll_r:Contains(g.IO.MousePos) then
            BoxSelectScrollWithMouseDrag(bs, window, scroll_r)
        end
    end
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: Multi-Select support
-------------------------------------------------------------------------------
-- - DebugLogMultiSelectRequests() [Internal]
-- - CalcScopeRect() [Internal]
-- - BeginMultiSelect()
-- - EndMultiSelect()
-- - SetNextItemSelectionUserData()
-- - MultiSelectItemHeader() [Internal]
-- - MultiSelectItemFooter() [Internal]
-- - DebugNodeMultiSelectState() [Internal]
-------------------------------------------------------------------------------

-- [Luau] reused scratch request: ImVector:push_back() copies it into the preallocated element (ImGuiSelectionRequest_Copy)
local MultiSelectScratchRequest = { Type = 0, Selected = false, RangeDirection = 0, RangeFirstItem = -1, RangeLastItem = -1 }
local MultiSelectScratchItemRect = ImRect() -- [Luau] scratch for MultiSelectItemFooter()'s item_rect

local function DebugLogMultiSelectRequests(func, io)
    local g = GImGui
    for _, req in io.Requests:iter() do
        if req.Type == ImGuiSelectionRequestType.SetAll then IMGUI_DEBUG_LOG_SELECTION("[selection] %s: Request: SetAll %d (= %s)\n", func, req.Selected and 1 or 0, req.Selected and "SelectAll" or "Clear") end
        if req.Type == ImGuiSelectionRequestType.SetRange then IMGUI_DEBUG_LOG_SELECTION("[selection] %s: Request: SetRange %s..%s = %d (dir %d)\n", func, tostring(req.RangeFirstItem), tostring(req.RangeLastItem), req.Selected and 1 or 0, req.RangeDirection) end
    end
end

local function CalcScopeRect(ms, window)
    if bit32.band(ms.Flags, ImGuiMultiSelectFlags.ScopeRect) ~= 0 then
        -- Warning: this depends on CursorMaxPos so it means to be called by EndMultiSelect() only
        -- This probably doesn't work inside a table as there are ample ambiguities related to exact time of calling BeginMultiSelect()/EndMultiSelect().
        return ImRect(ms.ScopeRectMin.x, ms.ScopeRectMin.y, ImMax(window.DC.CursorMaxPos.x, ms.ScopeRectMin.x), ImMax(window.DC.CursorMaxPos.y, ms.ScopeRectMin.y))
    else
        --// When a table, pull HostClipRect, which allows us to predict ClipRect before first row/layout is performed. (#7970)
        local scope_rect = ImRect(window.InnerClipRect.Min, window.InnerClipRect.Max)
        --if g.CurrentTable ~= nil then
        --    scope_rect = g.CurrentTable.HostClipRect
        --end

        -- Add inner table decoration (#7821) // FIXME: Why not baking in InnerClipRect?
        scope_rect.Min.x = ImMin(scope_rect.Min.x + window.DecoInnerSizeX1, scope_rect.Max.x)
        scope_rect.Min.y = ImMin(scope_rect.Min.y + window.DecoInnerSizeY1, scope_rect.Max.y)
        return scope_rect
    end
end

-- Return ImGuiMultiSelectIO structure.
-- Lifetime: don't hold on ImGuiMultiSelectIO references over multiple frames or past any subsequent call to BeginMultiSelect() or EndMultiSelect().
-- Passing 'selection_size' and 'items_count' parameters is currently optional.
-- - 'selection_size' is useful to disable some shortcut routing: e.g. ImGuiMultiSelectFlags.ClearOnEscape won't claim Escape key when selection_size 0,
--    allowing a first press to clear selection THEN the second press to leave child window and return to parent.
-- - 'items_count' is stored in ImGuiMultiSelectIO which makes it a convenient way to pass the information to your ApplyRequest() handler (but you may pass it differently).
-- - If they are costly for you to compute (e.g. external intrusive selection without maintaining size), you may avoid them and pass -1.
--   - If you can easily tell if your selection is empty or not, you may pass 0/1, or you may enable ImGuiMultiSelectFlags.ClearOnEscape flag dynamically.
--- @param flags           ImGuiMultiSelectFlags
--- @param selection_size? int
--- @param items_count?    int
--- @return ImGuiMultiSelectIO
function ImGui.BeginMultiSelect(flags, selection_size, items_count)
    if selection_size == nil then selection_size = -1 end
    if items_count == nil then items_count = -1 end
    local g = GImGui
    local window = g.CurrentWindow

    g.MultiSelectTempDataStacked = g.MultiSelectTempDataStacked + 1
    while g.MultiSelectTempDataStacked > g.MultiSelectTempData.Size do -- [Port] resize(n, ImGuiMultiSelectTempData()) would share one instance
        g.MultiSelectTempData:push_back(ImGuiMultiSelectTempData())
    end
    local ms = g.MultiSelectTempData.Data[g.MultiSelectTempDataStacked]
    g.CurrentMultiSelect = ms
    if bit32.band(flags, bit32.bor(ImGuiMultiSelectFlags.ScopeWindow, ImGuiMultiSelectFlags.ScopeRect)) == 0 then
        flags = bit32.bor(flags, ImGuiMultiSelectFlags.ScopeWindow)
    end
    if bit32.band(flags, ImGuiMultiSelectFlags.SingleSelect) ~= 0 then
        flags = bit32.band(flags, bit32.bnot(bit32.bor(ImGuiMultiSelectFlags.BoxSelect2d, ImGuiMultiSelectFlags.BoxSelect1d)))
    end
    if bit32.band(flags, ImGuiMultiSelectFlags.BoxSelect2d) ~= 0 then
        flags = bit32.band(flags, bit32.bnot(ImGuiMultiSelectFlags.BoxSelect1d))
    end

    -- FIXME: Workaround to the fact we override CursorMaxPos, meaning size measurement are lost. (#8250)
    -- They should perhaps be stacked properly?
    local table_ = g.CurrentTable
    if table_ then
        if not table_.IsLayoutLocked then
            ImGui.TableUpdateLayout(table_)
        elseif table_.CurrentColumn ~= -1 then
            ImGui.TableEndCell(table_) -- This is currently safe to call multiple time. If that properly is lost we can extract the "save measurement" part of it.
        end
    end

    -- FIXME: BeginFocusScope()
    local id = window.IDStack.Data[window.IDStack.Size] -- window.IDStack:back()
    ms:Clear()
    ms.FocusScopeId = id
    ms.Flags = flags
    ImVec2_Copy(ms.BackupCursorMaxPos, window.DC.CursorMaxPos)
    ImVec2_Copy(ms.ScopeRectMin, window.DC.CursorPos)
    if bit32.band(flags, ImGuiMultiSelectFlags.ScopeRect) ~= 0 then
        ImVec2_Copy(window.DC.CursorMaxPos, ms.ScopeRectMin) -- CalcScopeRect() for ImGuiMultiSelectFlags.ScopeRect will measure in EndMultiSelect().
    end
    ImGui.PushFocusScope(ms.FocusScopeId)
    ms.IsFocused = ImGui.IsInNavFocusRoute(g.CurrentFocusScopeId)
    if bit32.band(flags, ImGuiMultiSelectFlags.ScopeWindow) ~= 0 then -- Mark parent child window as navigable into, with highlight. Assume user will always submit interactive items.
        window.DC.NavLayersActiveMask = bit32.bor(window.DC.NavLayersActiveMask, bit32.lshift(1, ImGuiNavLayer.Main))
    end

    -- Use copy of keyboard mods at the time of the request, otherwise we would requires mods to be held for an extra frame.
    if g.NavJustMovedToId ~= 0 then
        ms.KeyMods = g.NavJustMovedToIsTabbing and 0 or g.NavJustMovedToKeyMods
    else
        ms.KeyMods = g.IO.KeyMods
    end
    if bit32.band(flags, ImGuiMultiSelectFlags.NoRangeSelect) ~= 0 then
        ms.KeyMods = bit32.band(ms.KeyMods, bit32.bnot(ImGuiMod_Shift))
    end

    -- Bind storage
    local storage = g.MultiSelectStorage:GetOrAddByKey(id)
    storage.ID = id
    storage.LastFrameActive = g.FrameCount
    storage.LastSelectionSize = selection_size
    storage.Window = window
    ms.Storage = storage

    -- Output to user
    ms.IO.Requests:resize(0)
    ms.IO.RangeSrcItem = storage.RangeSrcItem
    ms.IO.NavIdItem = storage.NavIdItem
    ms.IO.NavIdSelected = (storage.NavIdSelected == 1)
    ms.IO.ItemsCount = items_count

    -- Clear when using Navigation to move within the scope
    -- (we compare FocusScopeId so it possible to use multiple selections inside a same window)
    local request_clear = false
    local request_select_all = false
    if g.NavJustMovedToId ~= 0 and g.NavJustMovedToFocusScopeId == ms.FocusScopeId and g.NavJustMovedToHasSelectionData then
        if bit32.band(ms.KeyMods, ImGuiMod_Shift) ~= 0 then
            ms.IsKeyboardSetRange = true
        end
        if ms.IsKeyboardSetRange then
            IM_ASSERT(storage.RangeSrcItem ~= ImGuiSelectionUserData_Invalid) -- Not ready -> could clear?
        end
        if bit32.band(ms.KeyMods, bit32.bor(ImGuiMod_Ctrl, ImGuiMod_Shift)) == 0 and bit32.band(flags, bit32.bor(ImGuiMultiSelectFlags.NoAutoClear, ImGuiMultiSelectFlags.NoAutoSelect)) == 0 then
            request_clear = true
        end
    elseif g.NavJustMovedFromFocusScopeId == ms.FocusScopeId then
        -- Also clear on leaving scope (may be optional?)
        if bit32.band(ms.KeyMods, bit32.bor(ImGuiMod_Ctrl, ImGuiMod_Shift)) == 0 and bit32.band(flags, bit32.bor(ImGuiMultiSelectFlags.NoAutoClear, ImGuiMultiSelectFlags.NoAutoSelect)) == 0 then
            request_clear = true
        end
    end

    -- Box-select handling: update active state.
    local bs = g.BoxSelectState
    if bit32.band(flags, bit32.bor(ImGuiMultiSelectFlags.BoxSelect1d, ImGuiMultiSelectFlags.BoxSelect2d)) ~= 0 then
        ms.BoxSelectId = ImGui.GetID("##BoxSelect")
        if ImGui.BeginBoxSelect(CalcScopeRect(ms, window), window, ms.BoxSelectId, flags) then
            request_clear = request_clear or bs.RequestClear
        end
    end

    if ms.IsFocused then
        -- Shortcut: Clear selection (Escape)
        -- - Only claim shortcut if selection is not empty, allowing further presses on Escape to e.g. leave current child window.
        -- - Box select also handle Escape and needs to pass an id to bypass ActiveIdUsingAllKeyboardKeys lock.
        if bit32.band(flags, ImGuiMultiSelectFlags.ClearOnEscape) ~= 0 then
            if selection_size ~= 0 or bs.IsActive then
                if ImGui.Shortcut(ImGuiKey.Escape, ImGuiInputFlags.None, bs.IsActive and bs.ID or 0) then
                    request_clear = true
                    if bs.IsActive then
                        BoxSelectDeactivateDrag(bs)
                    end
                end
            end
        end

        -- Shortcut: Select all (Ctrl+A)
        if bit32.band(flags, ImGuiMultiSelectFlags.SingleSelect) == 0 and bit32.band(flags, ImGuiMultiSelectFlags.NoSelectAll) == 0 then
            if ImGui.Shortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.A)) then
                request_select_all = true
            end
        end
    end

    if request_clear or request_select_all then
        ImGui.MultiSelectAddSetAll(ms, request_select_all)
        if not request_select_all then
            storage.LastSelectionSize = 0
        end
    end
    ms.LoopRequestSetAll = request_select_all and 1 or (request_clear and 0 or -1)
    ms.IsSoleOrUnknownSelectionSize = (storage.LastSelectionSize == 1) or (storage.LastSelectionSize == -1)
    --ms.PrevSubmittedItem = ImGuiSelectionUserData_Invalid

    if bit32.band(g.DebugLogFlags, ImGuiDebugLogFlags.EventSelection) ~= 0 then
        DebugLogMultiSelectRequests("BeginMultiSelect", ms.IO)
    end

    return ms.IO
end

-- Return updated ImGuiMultiSelectIO structure.
-- Lifetime: don't hold on ImGuiMultiSelectIO references over multiple frames or past any subsequent call to BeginMultiSelect() or EndMultiSelect().
--- @return ImGuiMultiSelectIO
function ImGui.EndMultiSelect()
    local g = GImGui
    local ms = g.CurrentMultiSelect
    local storage = ms.Storage
    local window = g.CurrentWindow
    IM_ASSERT_USER_ERROR(ms.FocusScopeId == g.CurrentFocusScopeId, "EndMultiSelect() FocusScope mismatch!")
    IM_ASSERT(g.CurrentMultiSelect ~= nil and storage.Window == g.CurrentWindow)
    IM_ASSERT(g.MultiSelectTempDataStacked > 0 and g.MultiSelectTempData.Data[g.MultiSelectTempDataStacked] == g.CurrentMultiSelect)

    local scope_rect = CalcScopeRect(ms, window)
    if ms.IsFocused then
        -- We currently don't allow user code to modify RangeSrcItem by writing to BeginIO's version, but that would be an easy change here.
        if ms.IO.RangeSrcReset or (ms.RangeSrcPassedBy == false and ms.IO.RangeSrcItem ~= ImGuiSelectionUserData_Invalid) then -- Can't read storage.RangeSrcItem here -> we want the state at beginning of the scope (see tests for easy failure)
            IMGUI_DEBUG_LOG_SELECTION("[selection] EndMultiSelect: Reset RangeSrcItem.\n") -- Will set be to NavId.
            storage.RangeSrcItem = ImGuiSelectionUserData_Invalid
        end
        if ms.NavIdPassedBy == false and storage.NavIdItem ~= ImGuiSelectionUserData_Invalid then
            IMGUI_DEBUG_LOG_SELECTION("[selection] EndMultiSelect: Reset NavIdItem.\n")
            storage.NavIdItem = ImGuiSelectionUserData_Invalid
            storage.NavIdSelected = -1
        end

        if bit32.band(ms.Flags, bit32.bor(ImGuiMultiSelectFlags.BoxSelect1d, ImGuiMultiSelectFlags.BoxSelect2d)) ~= 0 and ImGui.GetBoxSelectState(ms.BoxSelectId) then
            ImGui.EndBoxSelect(scope_rect, ms.Flags)
        end
    end

    if ms.IsEndIO == false then
        ms.IO.Requests:resize(0)
    end

    -- Clear selection when clicking void?
    -- We specifically test for IsMouseDragPastThreshold(0) == false to allow box-selection!
    -- The InnerRect test is necessary for non-child/decorated windows.
    local scope_hovered = window.InnerRect:Contains(g.IO.MousePos) and ImGui.IsWindowHovered(ImGuiHoveredFlags.ChildWindows)
    if scope_hovered and bit32.band(ms.Flags, ImGuiMultiSelectFlags.ScopeRect) ~= 0 then
        scope_hovered = scope_hovered and scope_rect:Contains(g.IO.MousePos)
    end
    if scope_hovered and g.HoveredId == 0 and g.ActiveId == 0 then
        if bit32.band(ms.Flags, bit32.bor(ImGuiMultiSelectFlags.BoxSelect1d, ImGuiMultiSelectFlags.BoxSelect2d)) ~= 0 then
            if not g.BoxSelectState.IsActive and not g.BoxSelectState.IsStarting and g.IO.MouseClickedCount[0] == 1 then
                BoxSelectPreStartDrag(ms.BoxSelectId, ImGuiSelectionUserData_Invalid)
                ImGui.FocusWindow(window, ImGuiFocusRequestFlags.UnlessBelowModal)
                ImGui.SetHoveredID(ms.BoxSelectId)
                if bit32.band(ms.Flags, ImGuiMultiSelectFlags.ScopeRect) ~= 0 then
                    ImGui.SetNavID(0, ImGuiNavLayer.Main, ms.FocusScopeId, ImRect(g.IO.MousePos.x, g.IO.MousePos.y, g.IO.MousePos.x, g.IO.MousePos.y)) -- Automatically switch FocusScope for initial click from void to box-select.
                end
            end
        end

        if bit32.band(ms.Flags, ImGuiMultiSelectFlags.ClearOnClickVoid) ~= 0 then
            if ImGui.IsMouseReleased(0) and ImGui.IsMouseDragPastThreshold(0) == false and g.IO.KeyMods == ImGuiMod_None then
                ImGui.MultiSelectAddSetAll(ms, false)
            end
        end
    end

    -- Courtesy nav wrapping helper flag
    if bit32.band(ms.Flags, ImGuiMultiSelectFlags.NavWrapX) ~= 0 then
        IM_ASSERT(bit32.band(ms.Flags, ImGuiMultiSelectFlags.ScopeWindow) ~= 0) -- Only supported at window scope
        ImGui.NavMoveRequestTryWrapping(ImGui.GetCurrentWindow(), ImGuiNavMoveFlags.WrapX)
    end

    -- Unwind
    local table_ = g.CurrentTable
    if table_ then
        if table_.IsInsideRow then
            ImGui.TableEndRow(table_)
        end
    end
    ImVec2_CopyV(window.DC.CursorMaxPos, ImMax(ms.BackupCursorMaxPos.x, window.DC.CursorMaxPos.x), ImMax(ms.BackupCursorMaxPos.y, window.DC.CursorMaxPos.y))
    ImGui.PopFocusScope()

    if bit32.band(g.DebugLogFlags, ImGuiDebugLogFlags.EventSelection) ~= 0 then
        DebugLogMultiSelectRequests("EndMultiSelect", ms.IO)
    end

    ms.FocusScopeId = 0
    ms.Flags = ImGuiMultiSelectFlags.None
    g.MultiSelectTempDataStacked = g.MultiSelectTempDataStacked - 1
    if g.MultiSelectTempDataStacked > 0 then
        g.CurrentMultiSelect = g.MultiSelectTempData.Data[g.MultiSelectTempDataStacked]
    else
        g.CurrentMultiSelect = nil
    end

    return ms.IO
end

--- @param selection_user_data ImGuiSelectionUserData
function ImGui.SetNextItemSelectionUserData(selection_user_data)
    -- Note that flags will be cleared by ItemAdd(), so it's only useful for Navigation code!
    -- This designed so widgets can also cheaply set this before calling ItemAdd(), so we are not tied to MultiSelect api.
    local g = GImGui
    local next_item_data = g.NextItemData
    next_item_data.SelectionUserData = selection_user_data
    next_item_data.FocusScopeId = g.CurrentFocusScopeId

    local ms = g.CurrentMultiSelect
    if ms then
        -- Auto updating RangeSrcPassedBy for cases were clipper is not used (done before ItemAdd() clipping)
        next_item_data.ItemFlagsSet = bit32.bor(next_item_data.ItemFlagsSet, ImGuiItemFlags.HasSelectionUserData, ImGuiItemFlags.IsMultiSelect)
        if ms.IO.RangeSrcItem == selection_user_data then
            ms.RangeSrcPassedBy = true
        end
        --ms.PrevSubmittedItem = ms.CurrSubmittedItem -- Can't rely on previous g.NextItemData.SelectionUserData because NextItemData is not restored on nested multi-select.
        --ms.CurrSubmittedItem = selection_user_data
    else
        next_item_data.ItemFlagsSet = bit32.bor(next_item_data.ItemFlagsSet, ImGuiItemFlags.HasSelectionUserData)
    end
end

-- In charge of:
-- - Applying SetAll for submitted items.
-- - Applying SetRange for submitted items and record end points.
-- - Altering button behavior flags to facilitate use with drag and drop.
-- [Port] out-params as return values: `selected, button_flags = MultiSelectItemHeader(id, selected, button_flags)` (button_flags may be nil: C++ p_button_flags == NULL)
--- @param id           ImGuiID
--- @param selected     bool
--- @param button_flags ImGuiButtonFlags?
--- @return bool, ImGuiButtonFlags?
function ImGui.MultiSelectItemHeader(id, selected, button_flags)
    local g = GImGui
    local ms = g.CurrentMultiSelect

    if ms.IsFocused then
        local storage = ms.Storage
        local item_data = g.NextItemData.SelectionUserData
        IM_ASSERT(g.NextItemData.FocusScopeId == g.CurrentFocusScopeId, "Forgot to call SetNextItemSelectionUserData() prior to item, required in BeginMultiSelect()/EndMultiSelect() scope")

        -- Apply SetAll (Clear/SelectAll) requests requested by BeginMultiSelect().
        -- This is only useful if the user hasn't processed them already, and this only works if the user isn't using the clipper.
        -- If you are using a clipper you need to process the SetAll request after calling BeginMultiSelect()
        if ms.LoopRequestSetAll ~= -1 then
            selected = (ms.LoopRequestSetAll == 1)
        end

        -- When using Shift+Nav: because it can incur scrolling we cannot afford a frame of lag with the selection highlight (otherwise scrolling would happen before selection)
        -- For this to work, we need someone to set 'RangeSrcPassedBy = true' at some point (either clipper either SetNextItemSelectionUserData() function)
        if ms.IsKeyboardSetRange then
            IM_ASSERT(id ~= 0 and bit32.band(ms.KeyMods, ImGuiMod_Shift) ~= 0)
            local is_range_dst = (ms.RangeDstPassedBy == false) and g.NavJustMovedToId == id -- Assume that g.NavJustMovedToId is not clipped.
            if is_range_dst then
                ms.RangeDstPassedBy = true
            end
            if is_range_dst and storage.RangeSrcItem == ImGuiSelectionUserData_Invalid then -- If we don't have RangeSrc, assign RangeSrc = RangeDst
                storage.RangeSrcItem = item_data
                storage.RangeSelected = selected and 1 or 0
            end
            local is_range_src = storage.RangeSrcItem == item_data
            if is_range_src or is_range_dst or ms.RangeSrcPassedBy ~= ms.RangeDstPassedBy then
                -- Apply range-select value to visible items
                IM_ASSERT(storage.RangeSrcItem ~= ImGuiSelectionUserData_Invalid and storage.RangeSelected ~= -1)
                selected = (storage.RangeSelected ~= 0)
            elseif bit32.band(ms.KeyMods, ImGuiMod_Ctrl) == 0 and bit32.band(ms.Flags, ImGuiMultiSelectFlags.NoAutoClear) == 0 then
                -- Clear other items
                selected = false
            end
        end
    end

    -- Alter button behavior flags
    -- To handle drag and drop of multiple items we need to avoid clearing selection on click.
    -- Enabling this test makes actions using Ctrl+Shift delay their effect on MouseUp which is annoying, but it allows drag and drop of multiple items.
    if button_flags ~= nil then
        button_flags = bit32.bor(button_flags, ImGuiButtonFlags.NoHoveredOnFocus)
        button_flags = bit32.band(button_flags, bit32.bnot(bit32.bor(ImGuiButtonFlags.PressedOnClick, ImGuiButtonFlags.PressedOnClickRelease)))
        if bit32.band(ms.Flags, ImGuiMultiSelectFlags.SelectOnClickAlways) ~= 0 then
            button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnClick)
        elseif bit32.band(ms.Flags, ImGuiMultiSelectFlags.SelectOnClickRelease) ~= 0 then
            button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnClickRelease)
        else -- ImGuiMultiSelectFlags.SelectOnAuto
            button_flags = bit32.bor(button_flags, (not selected or (g.ActiveId == id and g.ActiveIdHasBeenPressedBefore)) and ImGuiButtonFlags.PressedOnClick or ImGuiButtonFlags.PressedOnClickRelease)
        end
    end
    return selected, button_flags
end

-- In charge of:
-- - Auto-select on navigation.
-- - Box-select toggle handling.
-- - Right-click handling.
-- - Altering selection based on Ctrl/Shift modifiers, both for keyboard and mouse.
-- - Record current selection state for RangeSrc
-- This is all rather complex, best to run and refer to "widgets_multiselect_xxx" tests in imgui_test_suite.
-- [Port] out-params as return values: `selected, pressed = MultiSelectItemFooter(id, selected, pressed, extra_flags)`
--- @param id           ImGuiID
--- @param selected     bool
--- @param pressed      bool
--- @param extra_flags? ImGuiMultiSelectFlags
--- @return bool, bool
function ImGui.MultiSelectItemFooter(id, selected, pressed, extra_flags)
    if extra_flags == nil then extra_flags = 0 end
    local g = GImGui
    local window = g.CurrentWindow

    local ms = g.CurrentMultiSelect
    local storage = ms.Storage
    if pressed then
        ms.IsFocused = true
    end

    local hovered = false
    if bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredRect) ~= 0 then
        hovered = ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup)
    end
    if not ms.IsFocused and not hovered then
        return selected, pressed
    end

    local item_data = g.NextItemData.SelectionUserData

    local flags = bit32.bor(ms.Flags, extra_flags)
    local is_singleselect = bit32.band(flags, ImGuiMultiSelectFlags.SingleSelect) ~= 0
    local is_ctrl = bit32.band(ms.KeyMods, ImGuiMod_Ctrl) ~= 0
    local is_shift = bit32.band(ms.KeyMods, ImGuiMod_Shift) ~= 0

    local apply_to_range_src = false

    if g.NavId == id and storage.RangeSrcItem == ImGuiSelectionUserData_Invalid then
        apply_to_range_src = true
    end
    if ms.IsEndIO == false then
        ms.IO.Requests:resize(0)
        ms.IsEndIO = true
    end

    -- Auto-select as you navigate a list
    if g.NavJustMovedToId == id then
        if bit32.band(flags, ImGuiMultiSelectFlags.NoAutoSelect) == 0 then
            if is_ctrl and is_shift then
                pressed = true
            elseif not is_ctrl then
                selected = true; pressed = true
            end
        else
            -- With NoAutoSelect, using Shift+keyboard performs a write/copy
            if is_shift then
                pressed = true
            elseif not is_ctrl then
                apply_to_range_src = true -- Since if (pressed) {} main block is not running we update this
            end
        end
    end

    if apply_to_range_src then
        storage.RangeSrcItem = item_data
        storage.RangeSelected = selected and 1 or 0 -- Will be updated at the end of this function anyway.
    end

    -- Box-select toggle handling
    if ms.BoxSelectId ~= 0 then
        local bs = ImGui.GetBoxSelectState(ms.BoxSelectId)
        if bs then
            local item_rect = MultiSelectScratchItemRect
            ImRect_Copy(item_rect, g.LastItemData.Rect)
            if not window.DC.NavIsScrollPushableX then -- FIXME: Rename to be more generic.
                local table_ = g.CurrentTable
                if table_ and table_.CurrentColumn ~= -1 then
                    -- FIXME: We cannot solely use current ClipRect as it includes HostClipRect.
                    -- However we account for ClipRect being larger than current column (e.g. when using SpanAllColumns)
                    -- A more generic version would be nice, but window.WorkRect.Min/Max exclude CellPadding. (#7994, #9383)
                    local column = table_.Columns[table_.CurrentColumn]
                    -- [Port] upstream tests ItemFlags against ImGuiItemStatusFlags_HasClipRect (sic), reproduced as-is.
                    local has_clip_rect = bit32.band(g.LastItemData.ItemFlags, ImGuiItemStatusFlags.HasClipRect) ~= 0
                    local clip_min_x = has_clip_rect and g.LastItemData.ClipRect.Min.x or window.ClipRect.Min.x
                    local clip_max_x = has_clip_rect and g.LastItemData.ClipRect.Max.x or window.ClipRect.Max.x
                    if clip_min_x ~= clip_max_x then -- When zero sized we expect that bounds have been clamped and thus are unreliable
                        item_rect.Min.x = ImMax(item_rect.Min.x, ImMin(column.MinX, clip_min_x))
                        item_rect.Max.x = ImMin(item_rect.Max.x, ImMax(column.MaxX, clip_max_x))
                    else
                        item_rect.Min.x = ImMax(item_rect.Min.x, column.MinX)
                        item_rect.Max.x = ImMin(item_rect.Max.x, column.MaxX)
                    end
                    --GetForegroundDrawList():AddRect(item_rect.Min, item_rect.Max, IM_COL32(255, 0, 255, 255))
                end
            end
            local rect_overlap_curr = bs.BoxSelectRectCurr:Overlaps(item_rect)
            local rect_overlap_prev = bs.BoxSelectRectPrev:Overlaps(item_rect)
            if (rect_overlap_curr and not rect_overlap_prev and not selected) or (rect_overlap_prev and not rect_overlap_curr) then
                if storage.LastSelectionSize <= 0 and bs.IsStartedSetNavIdOnce then
                    pressed = true -- First item act as a pressed: code below will emit selection request and set NavId (whatever we emit here will be overridden anyway)
                    bs.IsStartedSetNavIdOnce = false
                else
                    selected = not selected
                    ImGui.MultiSelectAddSetRange(ms, selected, 1, item_data, item_data)
                end
                storage.LastSelectionSize = ImMax(storage.LastSelectionSize + 1, 1)
            end
        end
    end

    -- Right-click handling.
    -- FIXME-MULTISELECT: Maybe should be moved to Selectable()? Also see #5816, #8200, #9015
    if hovered and ImGui.IsMouseClicked(1) and bit32.band(flags, bit32.bor(ImGuiMultiSelectFlags.NoAutoSelect, ImGuiMultiSelectFlags.NoSelectOnRightClick)) == 0 then
        if g.ActiveId ~= 0 and g.ActiveId ~= id then
            ImGui.ClearActiveID()
        end
        ImGui.SetFocusID(id, window)
        if not pressed and not selected then
            pressed = true
            is_ctrl = false; is_shift = false
        end
    end

    -- Unlike Space, Enter doesn't alter selection (but can still return a press) unless current item is not selected.
    -- The later, "unless current item is not select", may become optional? It seems like a better default if Enter doesn't necessarily open something
    -- (unlike e.g. Windows explorer). For use case where Enter always open something, we might decide to make this optional?
    local enter_pressed = pressed and (g.NavActivateId == id) and bit32.band(g.NavActivateFlags, ImGuiActivateFlags.PreferInput) ~= 0

    -- Alter selection
    if pressed and (not enter_pressed or not selected) then
        -- Box-select
        local input_source = (g.NavJustMovedToId == id or g.NavActivateId == id) and g.NavInputSource or ImGuiInputSource.Mouse
        if bit32.band(flags, bit32.bor(ImGuiMultiSelectFlags.BoxSelect1d, ImGuiMultiSelectFlags.BoxSelect2d)) ~= 0 then
            if not g.BoxSelectState.IsActive and not g.BoxSelectState.IsStarting and input_source == ImGuiInputSource.Mouse and g.IO.MouseClickedCount[0] == 1 then
                BoxSelectPreStartDrag(ms.BoxSelectId, item_data)
            end
        end

        ------------------------------------------------------------------------------------------
        -- ACTION                      | Begin  | Pressed/Activated  | End
        ------------------------------------------------------------------------------------------
        -- Keys Navigated:             | Clear  | Src=item, Sel=1               SetRange 1
        -- Keys Navigated: Ctrl        | n/a    | n/a
        -- Keys Navigated:      Shift  | n/a    | Dst=item, Sel=1,   => Clear + SetRange 1
        -- Keys Navigated: Ctrl+Shift  | n/a    | Dst=item, Sel=Src  => Clear + SetRange Src-Dst
        -- Keys Activated:             | n/a    | Src=item, Sel=1    => Clear + SetRange 1
        -- Keys Activated: Ctrl        | n/a    | Src=item, Sel=!Sel =>         SetSange 1
        -- Keys Activated:      Shift  | n/a    | Dst=item, Sel=1    => Clear + SetSange 1
        ------------------------------------------------------------------------------------------
        -- Mouse Pressed:              | n/a    | Src=item, Sel=1,   => Clear + SetRange 1
        -- Mouse Pressed:  Ctrl        | n/a    | Src=item, Sel=!Sel =>         SetRange 1
        -- Mouse Pressed:       Shift  | n/a    | Dst=item, Sel=1,   => Clear + SetRange 1
        -- Mouse Pressed:  Ctrl+Shift  | n/a    | Dst=item, Sel=!Sel =>         SetRange Src-Dst
        ------------------------------------------------------------------------------------------

        if bit32.band(flags, ImGuiMultiSelectFlags.NoAutoClear) == 0 then
            local request_clear = false
            if is_singleselect then
                request_clear = true
            elseif (input_source == ImGuiInputSource.Mouse or g.NavActivateId == id) and not is_ctrl then
                if bit32.band(flags, ImGuiMultiSelectFlags.NoAutoClearOnReselect) ~= 0 then request_clear = not selected else request_clear = true end
            elseif (input_source == ImGuiInputSource.Keyboard or input_source == ImGuiInputSource.Gamepad) and is_shift and not is_ctrl then
                request_clear = true -- With is_shift==false the RequestClear was done in BeginIO, not necessary to do again.
            end
            if request_clear then
                ImGui.MultiSelectAddSetAll(ms, false)
            end
        end

        local range_direction
        local range_selected
        if is_shift and not is_singleselect then
            --IM_ASSERT(storage.HasRangeSrc and storage.HasRangeValue)
            if storage.RangeSrcItem == ImGuiSelectionUserData_Invalid then
                storage.RangeSrcItem = item_data
            end
            if bit32.band(flags, ImGuiMultiSelectFlags.CheckboxMode_) == 0 then
                -- Shift+Arrow always select
                -- Ctrl+Shift+Arrow copy source selection state (already stored by BeginMultiSelect() in storage.RangeSelected)
                if is_ctrl and storage.RangeSelected ~= -1 then range_selected = (storage.RangeSelected ~= 0) else range_selected = true end
            else
                -- Shift+Arrow copy source selection state
                -- Shift+Click always copy from target selection state
                if ms.IsKeyboardSetRange then
                    if storage.RangeSelected ~= -1 then range_selected = (storage.RangeSelected ~= 0) else range_selected = true end
                else
                    range_selected = not selected
                end
            end
            range_direction = ms.RangeSrcPassedBy and 1 or -1
        else
            -- Ctrl inverts selection, otherwise always select
            if bit32.band(flags, ImGuiMultiSelectFlags.CheckboxMode_) == 0 then
                if is_ctrl then selected = not selected else selected = true end
            else
                selected = not selected
            end
            storage.RangeSrcItem = item_data
            range_selected = selected
            range_direction = 1
        end
        ImGui.MultiSelectAddSetRange(ms, range_selected, range_direction, storage.RangeSrcItem, item_data)
    end

    -- Update/store the selection state of the Source item (used by Ctrl+Shift, when Source is unselected we perform a range unselect)
    if storage.RangeSrcItem == item_data then
        storage.RangeSelected = selected and 1 or 0
    end

    -- Update/store the selection state of focused item
    if g.NavId == id then
        storage.NavIdItem = item_data
        storage.NavIdSelected = selected and 1 or 0
    end
    if storage.NavIdItem == item_data then
        ms.NavIdPassedBy = true
    end

    return selected, pressed
end

--- @param ms       ImGuiMultiSelectTempData
--- @param selected bool
function ImGui.MultiSelectAddSetAll(ms, selected)
    local req = MultiSelectScratchRequest -- ImGuiSelectionRequest req = { ImGuiSelectionRequestType_SetAll, selected, 0, ImGuiSelectionUserData_Invalid, ImGuiSelectionUserData_Invalid }
    req.Type = ImGuiSelectionRequestType.SetAll; req.Selected = selected; req.RangeDirection = 0; req.RangeFirstItem = ImGuiSelectionUserData_Invalid; req.RangeLastItem = ImGuiSelectionUserData_Invalid
    ms.IO.Requests:resize(0)      -- Can always clear previous requests
    ms.IO.Requests:push_back(req) -- Add new request
end

--- @param ms         ImGuiMultiSelectTempData
--- @param selected   bool
--- @param range_dir  int
--- @param first_item ImGuiSelectionUserData
--- @param last_item  ImGuiSelectionUserData
function ImGui.MultiSelectAddSetRange(ms, selected, range_dir, first_item, last_item)
    -- Merge contiguous spans into same request (unless NoRangeSelect is set which guarantees single-item ranges)
    -- FIXME-OPT: Disabled on 2026/04/09 as this would break with any form of coarse clipping that we don't know about (e.g. TableNextColumn() return value).
    -- The low-hanging fruit would be to know that ImGuiSelectionUserData are sequential indices, in which case we can trivially compare PrevSubmittedItem + RangeDir == FirstItem.
    -- User can always perform this merge if required.
    -- [Port] (#if 0 block not ported)

    local req = MultiSelectScratchRequest -- ImGuiSelectionRequest req = { ImGuiSelectionRequestType_SetRange, selected, (ImS8)range_dir, (range_dir > 0) ? first_item : last_item, (range_dir > 0) ? last_item : first_item }
    req.Type = ImGuiSelectionRequestType.SetRange; req.Selected = selected; req.RangeDirection = range_dir
    if range_dir > 0 then
        req.RangeFirstItem = first_item; req.RangeLastItem = last_item
    else
        req.RangeFirstItem = last_item; req.RangeLastItem = first_item
    end
    ms.IO.Requests:push_back(req) -- Add new request
end

--- @param storage ImGuiMultiSelectState
function ImGui.DebugNodeMultiSelectState(storage)
    local is_active = (storage.LastFrameActive >= ImGui.GetFrameCount() - 2) -- Note that fully clipped early out scrolling tables will appear as inactive here.
    if not is_active then ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetStyleColorVec4(ImGuiCol.TextDisabled)) end
    local open = ImGui.TreeNode(storage.ID, "MultiSelect 0x%08X in '%s'%s", storage.ID, storage.Window and storage.Window.Name or "N/A", is_active and "" or " *Inactive*")
    if not is_active then ImGui.PopStyleColor() end
    if not open then
        return
    end
    -- [Port] ImGuiSelectionUserData may be any Lua value: printed with tostring() instead of %lld (0x%llX)
    ImGui.Text("RangeSrcItem = %s, RangeSelected = %d", tostring(storage.RangeSrcItem), storage.RangeSelected)
    ImGui.Text("NavIdItem = %s, NavIdSelected = %d", tostring(storage.NavIdItem), storage.NavIdSelected)
    ImGui.Text("LastSelectionSize = %d", storage.LastSelectionSize) -- Provided by user
    ImGui.TreePop()
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: Multi-Select helpers
-------------------------------------------------------------------------------
-- - ImGuiSelectionBasicStorage
-- - ImGuiSelectionExternalStorage
-------------------------------------------------------------------------------
-- [Port] Storage representation:
-- - Upstream _Storage is an ImGuiStorage (vector of {ImGuiID key, int val_i} pairs sorted by key, val_i = selection order
--   or 0 when unselected). Here _Storage is a plain Lua table: [id] = selection order (always > 0); unselected ids are
--   removed (nil) instead of being kept with val_i == 0. Contains()/SetItemSelected() are O(1).
-- - Iteration: `local it, id = nil, 0; local has_more; while true do has_more, it, id = selection:GetNextSelectedItem(it) if not has_more then break end ... end`
--   (C++: void* it = NULL; ImGuiID id; while (selection.GetNextSelectedItem(&it, &id)) {...}). The opaque iterator is an
--   integer position into _IterKeys, a snapshot of the selected ids sorted by key (or by selection order when
--   PreserveOrder is set), rebuilt when an iteration starts (it == nil). Ids unselected during an iteration are skipped.
--   A storage supports one iteration at a time (starting a new one rebuilds the shared snapshot).
-- - Keys returned by AdapterIndexToStorageId must be mutually comparable with '<' (numbers by default) for the sort.

--- @class ImGuiSelectionBasicStorage
--- @field Size                    int     # Number of selected items, maintained by this helper.
--- @field PreserveOrder           bool    # = false  // GetNextSelectedItem() will return ordered selection (currently implemented by two additional sorts of selection. Could be improved)
--- @field UserData                any     # = nil   // User data for use by adapter function        // e.g. selection.UserData = my_items
--- @field AdapterIndexToStorageId fun(self: ImGuiSelectionBasicStorage, idx: int): ImGuiID # e.g. selection.AdapterIndexToStorageId = function(self, idx) return self.UserData[idx + 1].ID end
--- @field _SelectionOrder         int     # [Internal] Increasing counter to store selection order
--- @field _Storage                table   # [Internal] Selection set. Think of this as similar to e.g. std::set<ImGuiID>. Prefer not accessing directly: iterate with GetNextSelectedItem().
MT.ImGuiSelectionBasicStorage = {}
MT.ImGuiSelectionBasicStorage.__index = MT.ImGuiSelectionBasicStorage

local function ImGuiSelectionBasicStorage_DefaultAdapterIndexToStorageId(_, idx) return idx end

--- @return ImGuiSelectionBasicStorage
function ImGuiSelectionBasicStorage()
    local this = setmetatable({}, MT.ImGuiSelectionBasicStorage)
    this.Size = 0
    this.PreserveOrder = false
    this.UserData = nil
    this.AdapterIndexToStorageId = ImGuiSelectionBasicStorage_DefaultAdapterIndexToStorageId -- [](ImGuiSelectionBasicStorage*, int idx) { return (ImGuiID)idx; }
    this._SelectionOrder = 1 -- Always >0
    this._Storage = {}
    this._IterKeys = {} -- [Port] GetNextSelectedItem() snapshot
    return this
end

function MT.ImGuiSelectionBasicStorage:Clear()
    self.Size = 0
    self._SelectionOrder = 1 -- Always >0
    table.clear(self._Storage)
end

--- @param r ImGuiSelectionBasicStorage
function MT.ImGuiSelectionBasicStorage:Swap(r)
    self.Size, r.Size = r.Size, self.Size
    self._SelectionOrder, r._SelectionOrder = r._SelectionOrder, self._SelectionOrder
    self._Storage, r._Storage = r._Storage, self._Storage
end

--- @param id ImGuiID
--- @return bool
function MT.ImGuiSelectionBasicStorage:Contains(id)
    return self._Storage[id] ~= nil
end

local PairComparerStorage = nil
local function PairComparerByValueInt(lhs, rhs)
    return PairComparerStorage[lhs] < PairComparerStorage[rhs]
end

-- GetNextSelectedItem() is an abstraction allowing us to change our underlying actual storage system without impacting user.
-- (e.g. store unselected vs compact down, compact down on demand, use raw ImVector<ImGuiID> instead of ImGuiStorage...)
-- [Port] `has_more, opaque_it, out_id = selection:GetNextSelectedItem(opaque_it)`: pass nil to start, then the returned opaque_it.
--- @param opaque_it any
--- @return bool, any, ImGuiID
function MT.ImGuiSelectionBasicStorage:GetNextSelectedItem(opaque_it)
    local storage = self._Storage
    local keys = self._IterKeys
    local it = opaque_it
    if it == nil then
        table.clear(keys)
        local n = 0
        for id in pairs(storage) do n = n + 1; keys[n] = id end
        if self.PreserveOrder then
            PairComparerStorage = storage
            table.sort(keys, PairComparerByValueInt) -- ~ImGuiStorage::BuildSortByValueInt()
            PairComparerStorage = nil
        else
            table.sort(keys) -- [Port] ImGuiStorage is sorted by key
        end
        it = 1
    end
    local it_end = #keys + 1
    IM_ASSERT(it >= 1 and it <= it_end)
    while it < it_end and storage[keys[it]] == nil do
        it = it + 1
    end
    local has_more = (it ~= it_end)
    if has_more then
        return true, it + 1, keys[it]
    end
    return false, it, 0
end

--- @param id       ImGuiID
--- @param selected bool
function MT.ImGuiSelectionBasicStorage:SetItemSelected(id, selected)
    local storage = self._Storage
    local p_int = storage[id]
    if selected and p_int == nil then storage[id] = self._SelectionOrder; self._SelectionOrder = self._SelectionOrder + 1; self.Size = self.Size + 1
    elseif not selected and p_int ~= nil then storage[id] = nil; self.Size = self.Size - 1 end
end

--- @param idx int
--- @return ImGuiID
function MT.ImGuiSelectionBasicStorage:GetStorageIdFromIndex(idx) return self.AdapterIndexToStorageId(self, idx) end -- Convert index to item id based on provided adapter.

-- Optimized for batch edits (with same value of 'selected')
-- [Port] With a hash table there is nothing to defer: insert/remove in place. size_before_amends is unused.
local function ImGuiSelectionBasicStorage_BatchSetItemSelected(selection, id, selected, size_before_amends, selection_order)
    local storage = selection._Storage
    local is_contained = storage[id] ~= nil
    if selected == is_contained then
        return
    end
    if selected then
        storage[id] = selection_order
    else
        storage[id] = nil
    end
    selection.Size = selection.Size + (selected and 1 or -1)
end

-- [Port] Upstream sorts the ImGuiStorage vector here (BuildSortByKey). The Lua table needs no sorting: GetNextSelectedItem() sorts its snapshot.
local function ImGuiSelectionBasicStorage_BatchFinish(selection, selected, size_before_amends)
end

-- Apply requests coming from BeginMultiSelect() and EndMultiSelect().
-- - Enable 'Demo->Tools->Debug Log->Selection' to see selection requests as they happen.
-- - Honoring SetRange requests requires that you can iterate/interpolate between RangeFirstItem and RangeLastItem.
--   - In this demo we often submit indices to SetNextItemSelectionUserData() + store the same indices in persistent selection.
--   - Your code may do differently. If you store pointers or objects ID in ImGuiSelectionUserData you may need to perform
--     a lookup in order to have some way to iterate/interpolate between two items.
-- - A full-featured application is likely to allow search/filtering which is likely to lead to using indices
--   and constructing a view index <> object id/ptr data structure anyway.
-- WHEN YOUR APPLICATION SETTLES ON A CHOICE, YOU WILL PROBABLY PREFER TO GET RID OF THIS UNNECESSARY 'ImGuiSelectionBasicStorage' INDIRECTION LOGIC.
-- Notice that with the simplest adapter (using indices everywhere), all functions return their parameters.
-- The most simple implementation (using indices everywhere) would look like:
--   for _, req in ms_io.Requests:iter() do
--      if req.Type == ImGuiSelectionRequestType.SetAll then Clear(); if req.Selected then for n = 0, items_count - 1 do SetItemSelected(n, true) end end end
--      if req.Type == ImGuiSelectionRequestType.SetRange then for n = req.RangeFirstItem, req.RangeLastItem do SetItemSelected(n, req.Selected) end end
--   end
--- @param ms_io ImGuiMultiSelectIO
function MT.ImGuiSelectionBasicStorage:ApplyRequests(ms_io)
    -- For convenience we obtain ItemsCount as passed to BeginMultiSelect(), which is optional.
    -- It makes sense when using ImGuiSelectionBasicStorage to simply pass your items count to BeginMultiSelect().
    -- Other scheme may handle SetAll differently.
    IM_ASSERT(ms_io.ItemsCount ~= -1, "Missing value for items_count in BeginMultiSelect() call!")
    IM_ASSERT(self.AdapterIndexToStorageId ~= nil)

    -- This is optimized/specialized to cope with very large selections (e.g. 100k+ items)
    -- - A simpler version could call SetItemSelected() directly instead of ImGuiSelectionBasicStorage_BatchSetItemSelected() + ImGuiSelectionBasicStorage_BatchFinish().
    -- - Optimized select can append unsorted, then sort in a second pass. Optimized unselect can clear in-place then compact in a second pass.
    -- - A more optimal version wouldn't even use ImGuiStorage but directly a ImVector<ImGuiID> to reduce bandwidth, but this is a reasonable trade off to reuse code.
    -- - There are many ways this could be better optimized. The worse case scenario being: using BoxSelect2d in a grid, box-select scrolling down while wiggling
    --   left and right: it affects coarse clipping + can emit multiple SetRange with 1 item each.
    -- FIXME-OPT: For each block of consecutive SetRange request:
    -- - add all requests to a sorted list, store ID, selected, offset in ImGuiStorage.
    -- - rewrite sorted storage a single time.
    for _, req in ms_io.Requests:iter() do
        if req.Type == ImGuiSelectionRequestType.SetAll then
            self:Clear()
            if req.Selected then
                local size_before_amends = self.Size -- [Port] _Storage.Data.Size (0 after Clear())
                for idx = 0, ms_io.ItemsCount - 1 do
                    ImGuiSelectionBasicStorage_BatchSetItemSelected(self, self:GetStorageIdFromIndex(idx), req.Selected, size_before_amends, self._SelectionOrder)
                    self._SelectionOrder = self._SelectionOrder + 1
                end
                ImGuiSelectionBasicStorage_BatchFinish(self, req.Selected, size_before_amends)
            end
        elseif req.Type == ImGuiSelectionRequestType.SetRange then
            local selection_changes = req.RangeLastItem - req.RangeFirstItem + 1
            --local g = GImGui; IMGUI_DEBUG_LOG_SELECTION("Req %d/%d: set %d to %d\n", ms_io.Requests:index_from_ptr(req), ms_io.Requests.Size, selection_changes, req.Selected)
            if selection_changes == 1 or (selection_changes < math.floor(self.Size / 100)) then
                -- Multiple sorted insertion + copy likely to be faster.
                -- Technically we could do a single copy with a little more work (sort sequential SetRange requests)
                for idx = req.RangeFirstItem, req.RangeLastItem do
                    self:SetItemSelected(self:GetStorageIdFromIndex(idx), req.Selected)
                end
            else
                -- Append insertion + single sort likely be faster.
                -- Use req.RangeDirection to set order field so that Shift+Clicking from 1 to 5 is different than Shift+Clicking from 5 to 1
                local size_before_amends = self.Size
                local selection_order = self._SelectionOrder + ((req.RangeDirection < 0) and selection_changes - 1 or 0)
                for idx = req.RangeFirstItem, req.RangeLastItem do
                    ImGuiSelectionBasicStorage_BatchSetItemSelected(self, self:GetStorageIdFromIndex(idx), req.Selected, size_before_amends, selection_order)
                    selection_order = selection_order + req.RangeDirection
                end
                if req.Selected then
                    self._SelectionOrder = self._SelectionOrder + selection_changes
                end
                ImGuiSelectionBasicStorage_BatchFinish(self, req.Selected, size_before_amends)
            end
        end
    end
end

-------------------------------------------------------------------------------

-- Optional helper to apply multi-selection requests to existing randomly accessible storage.
-- Convenient if you want to quickly wire multi-select API on e.g. an array of bool or items storing their own selection state.
--- @class ImGuiSelectionExternalStorage
--- @field UserData               any # User data for use by adapter function                                // e.g. selection.UserData = my_items
--- @field AdapterSetItemSelected fun(self: ImGuiSelectionExternalStorage, idx: int, selected: bool) # e.g. AdapterSetItemSelected = function(self, idx, selected) self.UserData[idx + 1].Selected = selected end
MT.ImGuiSelectionExternalStorage = {}
MT.ImGuiSelectionExternalStorage.__index = MT.ImGuiSelectionExternalStorage

--- @return ImGuiSelectionExternalStorage
function ImGuiSelectionExternalStorage()
    local this = setmetatable({}, MT.ImGuiSelectionExternalStorage)
    this.UserData = nil
    this.AdapterSetItemSelected = nil
    return this
end

-- Apply requests coming from BeginMultiSelect() and EndMultiSelect().
-- We also pull 'ms_io.ItemsCount' as passed for BeginMultiSelect() for consistency with ImGuiSelectionBasicStorage
-- This makes no assumption about underlying storage.
--- @param ms_io ImGuiMultiSelectIO
function MT.ImGuiSelectionExternalStorage:ApplyRequests(ms_io)
    IM_ASSERT(self.AdapterSetItemSelected)
    for _, req in ms_io.Requests:iter() do
        if req.Type == ImGuiSelectionRequestType.SetAll then
            for idx = 0, ms_io.ItemsCount - 1 do
                self.AdapterSetItemSelected(self, idx, req.Selected)
            end
        end
        if req.Type == ImGuiSelectionRequestType.SetRange then
            for idx = req.RangeFirstItem, req.RangeLastItem do
                self.AdapterSetItemSelected(self, idx, req.Selected)
            end
        end
    end
end

end -- [Port] do (Typing-Select, Box-Select, Multi-Select)

-------------------------------------------------------------------------------
-- [SECTION] Widgets: ListBox
-------------------------------------------------------------------------------
-- - BeginListBox()
-- - EndListBox()
-- - ListBox()
-------------------------------------------------------------------------------

-- This is essentially a thin wrapper to using BeginChild/EndChild with the ImGuiChildFlags.FrameStyle flag for stylistic changes + displaying a label.
-- This handle some subtleties with capturing info from the label.
-- If you don't need a label you can pretty much directly use ImGui.BeginChild() with ImGuiChildFlags.FrameStyle.
-- Tip: To have a list filling the entire window width, use size.x = -FLT_MIN and pass an non-visible label e.g. "##empty"
-- Tip: If your vertical size is calculated from an item count (e.g. 10 * item_height) consider adding a fractional part to facilitate seeing scrolling boundaries (e.g. 10.5f * item_height).
--- @param label     string
--- @param size_arg? ImVec2
function ImGui.BeginListBox(label, size_arg)
    if size_arg == nil then size_arg = ImVec2(0, 0) end
    local g = GImGui
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local style = g.Style
    local id = ImGui.GetID(label)
    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size = ImGui.CalcTextSize(label, label_end, false)

    -- Size default to hold ~7.25 items.
    -- Fractional number of items helps seeing that we can scroll down/up without looking at scrollbar.
    local size = ImTrunc(ImGui.CalcItemSize(size_arg, ImGui.CalcItemWidth(), ImGui.GetTextLineHeightWithSpacing() * 7.25 + style.FramePadding.y * 2.0))
    local frame_size = ImVec2(size.x, ImMax(size.y, label_size.y))
    local frame_bb = ImRect(window.DC.CursorPos, window.DC.CursorPos + frame_size)
    local bb = ImRect(frame_bb.Min, frame_bb.Max + ImVec2((label_size.x > 0.0) and (style.ItemInnerSpacing.x + label_size.x) or 0.0, 0.0))
    g.NextItemData:ClearFlags()

    if not ImGui.IsRectVisible(bb.Min, bb.Max) then
        ImGui.ItemSize(bb:GetSize(), style.FramePadding.y)
        ImGui.ItemAdd(bb, 0, frame_bb)
        g.NextWindowData:ClearFlags() -- We behave like Begin() and need to consume those values
        return false
    end

    -- FIXME-OPT: We could omit the BeginGroup() if label_size.x == 0.0f but would need to omit the EndGroup() as well.
    ImGui.BeginGroup()
    if label_size.x > 0.0 then
        local label_pos = ImVec2(frame_bb.Max.x + style.ItemInnerSpacing.x, frame_bb.Min.y + style.FramePadding.y)
        ImGui.RenderText(label_pos, label, 1, label_end, false)
        ImVec2_Copy(window.DC.CursorMaxPos, ImMax(window.DC.CursorMaxPos, label_pos + label_size))
        ImGui.AlignTextToFramePadding()
    end

    ImGui.BeginChild(id, frame_bb:GetSize(), ImGuiChildFlags.FrameStyle)
    return true
end

function ImGui.EndListBox()
    local g = GImGui
    local window = g.CurrentWindow
    IM_ASSERT(bit32.band(window.Flags, ImGuiWindowFlags.ChildWindow) ~= 0, "Mismatched BeginListBox/EndListBox calls. Did you test the return value of BeginListBox?")

    ImGui.EndChild()
    ImGui.EndGroup() -- This is only required to be able to do IsItemXXX query on the whole ListBox including label
end

-- This is merely a helper around BeginListBox(), EndListBox().
-- Considering using those directly to submit custom data or store selection differently.
-- [Port] Overloads: (label, current_item, items[], items_count?, height_in_items?) or (label, current_item, getter, user_data, items_count, height_in_items?)
--- @param current_item int # 0-based
--- @return int  current_item
--- @return bool value_changed
function ImGui.ListBox(label, current_item, a, b, c, d)
    local g = GImGui
    local getter, user_data, items_count, height_in_items = Items_ResolveArgs(a, b, c, d)
    if height_in_items == nil then height_in_items = -1 end

    -- Calculate size from "height_in_items"
    if height_in_items < 0 then
        height_in_items = ImMin(items_count, 7)
    end
    local height_in_items_f = height_in_items + 0.25
    local size = ImVec2(0.0, ImTrunc(ImGui.GetTextLineHeightWithSpacing() * height_in_items_f + g.Style.FramePadding.y * 2.0))

    if not ImGui.BeginListBox(label, size) then
        return current_item, false
    end

    -- Assume all items have even height (= 1 line of text). If you need items of different height,
    -- you can create a custom version of ListBox() in your code without using the clipper.
    local value_changed = false
    local clipper = ImGuiListClipper()
    clipper:Begin(items_count, ImGui.GetTextLineHeightWithSpacing()) -- We know exactly our line height here so we pass it as a minor optimization, but generally you don't need to.
    clipper:IncludeItemByIndex(current_item)
    while clipper:Step() do
        for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
            local item_text = getter(user_data, i)
            if item_text == nil then
                item_text = "*Unknown item*"
            end

            ImGui.PushID(i)
            local item_selected = (i == current_item)
            if ImGui.Selectable(item_text, item_selected) then
                current_item = i
                value_changed = true
            end
            if item_selected then
                ImGui.SetItemDefaultFocus()
            end
            ImGui.PopID()
        end
    end
    ImGui.EndListBox()

    if value_changed then
        ImGui.MarkItemEdited(g.LastItemData.ID)
    end

    return current_item, value_changed
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: PlotLines, PlotHistogram
-------------------------------------------------------------------------------
-- - PlotEx() [Internal]
-- - PlotLines()
-- - PlotHistogram()
-------------------------------------------------------------------------------
-- Plot/Graph widgets are not very good.
-- Consider using ImPlot (https://github.com/epezent/implot) which is much better!
-------------------------------------------------------------------------------

local PlotEx_pos0, PlotEx_pos1 = ImVec2(), ImVec2() -- [Luau] scratch line/bar corners

--- @param plot_type     ImGuiPlotType
--- @param label         string
--- @param values_getter fun(data?: table, idx: int): float
--- @param data?         table                              # 1-based table
--- @param values_count  int
--- @param values_offset int
--- @param overlay_text? string
--- @param scale_min     float
--- @param scale_max     float
--- @param size_arg      ImVec2
--- @return int
@native
function ImGui.PlotEx(plot_type, label, values_getter, data, values_count, values_offset, overlay_text, scale_min, scale_max, size_arg)
    local g = GImGui
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return -1
    end

    local style = g.Style
    local id = window:GetID(label)

    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size = ImGui.CalcTextSize(label, label_end, false)
    local frame_size = ImGui.CalcItemSize(size_arg, ImGui.CalcItemWidth(), label_size.y + style.FramePadding.y * 2.0)

    local cursor, pad = window.DC.CursorPos, style.FramePadding -- [Luau] scalar forms: no temporary ImVec2s
    local frame_bb = ImRect(cursor.x, cursor.y, cursor.x + frame_size.x, cursor.y + frame_size.y)
    local inner_bb = ImRect(frame_bb.Min.x + pad.x, frame_bb.Min.y + pad.y, frame_bb.Max.x - pad.x, frame_bb.Max.y - pad.y)
    local total_bb = ImRect(frame_bb.Min.x, frame_bb.Min.y, frame_bb.Max.x + (label_size.x > 0.0 and style.ItemInnerSpacing.x + label_size.x or 0.0), frame_bb.Max.y + 0)
    ImGui.ItemSize(total_bb, style.FramePadding.y)
    if not ImGui.ItemAdd(total_bb, id, frame_bb, ImGuiItemFlags.NoNav) then
        return -1
    end

    local _, hovered, _ = ImGui.ButtonBehavior(frame_bb, id)

    -- Determine scale from values if not specified
    if scale_min == FLT_MAX or scale_max == FLT_MAX then
        local v_min = FLT_MAX
        local v_max = -FLT_MAX
        for i = 1, values_count do
            local v = values_getter(data, i) -- [Port] NaN isn't checked here

            v_min = ImMin(v_min, v)
            v_max = ImMax(v_max, v)
        end
        if scale_min == FLT_MAX then
            scale_min = v_min
        end
        if scale_max == FLT_MAX then
            scale_max = v_max
        end
    end

    ImGui.RenderFrame(frame_bb.Min, frame_bb.Max, ImGui.GetColorU32(ImGuiCol.FrameBg), true, style.FrameRounding)

    local values_count_min = (plot_type == ImGuiPlotType.Lines) and 2 or 1
    local idx_hovered = -1

    if values_count >= values_count_min then
        local res_w = ImMin(math.floor(frame_size.x), values_count) + ((plot_type == ImGuiPlotType.Lines) and -1 or 0)
        local item_count = values_count + ((plot_type == ImGuiPlotType.Lines) and -1 or 0)

        -- Tooltip on hover
        if hovered and inner_bb:Contains(g.IO.MousePos) then
            local t = ImClamp((g.IO.MousePos.x - inner_bb.Min.x) / (inner_bb.Max.x - inner_bb.Min.x), 0.0, 0.999)
            local v_idx = math.floor(t * item_count) + 1
            IM_ASSERT(v_idx >= 1 and v_idx <= values_count)

            local v0 = values_getter(data, (v_idx - 1 + values_offset) % values_count + 1)
            local v1 = values_getter(data, (v_idx - 1 + 1 + values_offset) % values_count + 1)
            if plot_type == ImGuiPlotType.Lines then
                ImGui.SetTooltip("%d: %8.4g\n%d: %8.4g", v_idx, v0, v_idx + 1, v1)
            elseif plot_type == ImGuiPlotType.Histogram then
                ImGui.SetTooltip("%d: %8.4g", v_idx, v0)
            end
            idx_hovered = v_idx
        end

        local t_step = 1.0 / res_w
        local inv_scale = (scale_min == scale_max) and 0.0 or (1.0 / (scale_max - scale_min))

        local v0 = values_getter(data, (0 + values_offset) % values_count + 1)
        local t0 = 0.0
        local tp0_x, tp0_y = t0, 1.0 - ImSaturate((v0 - scale_min) * inv_scale) -- Point in the normalized space of our target rectangle -- [Luau] scalar tp0/tp1
        local histogram_zero_line_t = (scale_min * scale_max < 0.0) and (1 + scale_min * inv_scale) or (scale_min < 0.0 and 0.0 or 1.0) -- Where does the zero line stands

        local col_base = ImGui.GetColorU32((plot_type == ImGuiPlotType.Lines) and ImGuiCol.PlotLines or ImGuiCol.PlotHistogram)
        local col_hovered = ImGui.GetColorU32((plot_type == ImGuiPlotType.Lines) and ImGuiCol.PlotLinesHovered or ImGuiCol.PlotHistogramHovered)
        local inner_min_x, inner_min_y, inner_max_x, inner_max_y = inner_bb.Min.x, inner_bb.Min.y, inner_bb.Max.x, inner_bb.Max.y
        local draw_list = window.DrawList

        for _ = 0, res_w - 1 do
            local t1 = t0 + t_step
            local v1_idx = math.floor(t0 * item_count + 0.5) + 1
            IM_ASSERT(v1_idx >= 1 and v1_idx <= values_count)
            local v1 = values_getter(data, (v1_idx - 1 + values_offset + 1) % values_count + 1)
            local tp1_x, tp1_y = t1, 1.0 - ImSaturate((v1 - scale_min) * inv_scale)

            -- NB: Draw calls are merged together by the DrawList system. Still, we should render our batch are lower level to save a bit of CPU.
            -- [Luau] ImLerp() on scalars into scratch vectors, only read by AddLine()/AddRectFilled()
            local pos0, pos1 = PlotEx_pos0, PlotEx_pos1
            pos0.x = inner_min_x + (inner_max_x - inner_min_x) * tp0_x; pos0.y = inner_min_y + (inner_max_y - inner_min_y) * tp0_y
            pos1.x = inner_min_x + (inner_max_x - inner_min_x) * tp1_x
            if plot_type == ImGuiPlotType.Lines then
                pos1.y = inner_min_y + (inner_max_y - inner_min_y) * tp1_y
            else
                pos1.y = inner_min_y + (inner_max_y - inner_min_y) * histogram_zero_line_t
            end

            if plot_type == ImGuiPlotType.Lines then
                draw_list:AddLine(pos0, pos1, idx_hovered == v1_idx and col_hovered or col_base)
            elseif plot_type == ImGuiPlotType.Histogram then
                if pos1.x >= pos0.x + 2.0 then
                    pos1.x = pos1.x - 1.0
                end
                draw_list:AddRectFilled(pos0, pos1, idx_hovered == v1_idx and col_hovered or col_base)
            end

            t0 = t1
            tp0_x, tp0_y = tp1_x, tp1_y
        end
    end

    -- Text overlay
    if overlay_text then
        ImGui.RenderTextClipped(ImVec2(frame_bb.Min.x, frame_bb.Min.y + style.FramePadding.y), frame_bb.Max, overlay_text, nil, nil, ImVec2(0.5, 0.0))
    end

    if label_size.x > 0.0 then
        ImGui.RenderText(ImVec2(frame_bb.Max.x + style.ItemInnerSpacing.x, inner_bb.Min.y), label, 1, label_end, false)
    end

    -- Return hovered index or -1 if none are hovered.
    -- This is currently not exposed in the public API because we need a larger redesign of the whole thing, but in the short-term we are making it available in PlotEx().
    return idx_hovered
end

--- @class ImGuiPlotArrayGetterData
--- @field Values float[]
--- @field Stride int

--- @param values float[]
--- @param stride int
--- @return ImGuiPlotArrayGetterData
--- @nodiscard
function ImGuiPlotArrayGetterData(values, stride)
    return {
        Values = values,
        Stride = stride
    }
end

--- @param data ImGuiPlotArrayGetterData
--- @param idx int
--- @return float
--- @package
local function Plot_ArrayGetter(data, idx)
    return data.Values[idx * data.Stride]
end

--- @param label            string
--- @param values_or_getter table|fun(data:table, i:int)  # 1-based table or a function
--- @param data?            table                         # 1-based table
--- @param values_count     int
--- @param values_offset?   int                           # Defaults to 0
--- @param overlay_text?    string
--- @param scale_min?       float                         # Defaults to FLT_MAX
--- @param scale_max?       float                         # Defaults to FLT_MAX
--- @param graph_size?      ImVec2                        # Defaults to ImVec2(0, 0)
--- @param stride?          int                           # Defaults to 1
function ImGui.PlotLines(label, values_or_getter, data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size, stride)
    if values_offset == nil then values_offset = 0         end
    if scale_min     == nil then scale_min  = FLT_MAX      end
    if scale_max     == nil then scale_max  = FLT_MAX      end
    if graph_size    == nil then graph_size = ImVec2(0, 0) end
    if stride        == nil then stride     = 1            end

    if type(values_or_getter) == "function" then
        ImGui.PlotEx(ImGuiPlotType.Lines, label, values_or_getter, data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size)
    else
        data = ImGuiPlotArrayGetterData(values_or_getter, stride)
        ImGui.PlotEx(ImGuiPlotType.Lines, label, Plot_ArrayGetter, data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size)
    end
end

-- Plot Histogram (the data provided _is_ histogram data. it doesn't compute the histogram of your data)
--- @param label            string
--- @param values_or_getter table|fun(data:table, i:int)  # 1-based table or a function
--- @param data?            table                         # 1-based table
--- @param values_count     int
--- @param values_offset?   int                           # Defaults to 0
--- @param overlay_text?    string
--- @param scale_min?       float                         # Defaults to FLT_MAX
--- @param scale_max?       float                         # Defaults to FLT_MAX
--- @param graph_size?      ImVec2                        # Defaults to ImVec2(0, 0)
--- @param stride?          int                           # Defaults to 1
function ImGui.PlotHistogram(label, values_or_getter, data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size, stride)
    if values_offset == nil then values_offset = 0         end
    if scale_min     == nil then scale_min  = FLT_MAX      end
    if scale_max     == nil then scale_max  = FLT_MAX      end
    if graph_size    == nil then graph_size = ImVec2(0, 0) end
    if stride        == nil then stride     = 1            end

    if type(values_or_getter) == "function" then
        ImGui.PlotEx(ImGuiPlotType.Histogram, label, values_or_getter, data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size)
    else
        data = ImGuiPlotArrayGetterData(values_or_getter, stride)
        ImGui.PlotEx(ImGuiPlotType.Histogram, label, Plot_ArrayGetter, data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size)
    end
end

-------------------------------------------------------------------------------
-- [SECTION] MenuItem, BeginMenu, EndMenu, etc.
-------------------------------------------------------------------------------
-- - ImGuiMenuColumns [Internal]
-- - BeginMenuBar()
-- - EndMenuBar()
-- - BeginMainMenuBar()
-- - EndMainMenuBar()
-- - BeginMenu()
-- - EndMenu()
-- - MenuItemEx() [Internal]
-- - MenuItem()
-------------------------------------------------------------------------------

-- Helpers for internal use
--- @param spacing            float
--- @param window_reappearing bool
function MT.ImGuiMenuColumns:Update(spacing, window_reappearing)
    if window_reappearing then
        for i = 1, #self.Widths do self.Widths[i] = 0 end
    end
    self.Spacing = spacing
    self:CalcNextTotalWidth(true)
    for i = 1, #self.Widths do self.Widths[i] = 0 end
    self.TotalWidth = self.NextTotalWidth
    self.NextTotalWidth = 0
end

--- @param update_offsets bool
function MT.ImGuiMenuColumns:CalcNextTotalWidth(update_offsets)
    local offset = 0
    local want_spacing = false
    for i = 1, #self.Widths do
        local width = self.Widths[i]
        if want_spacing and width > 0 then
            offset = offset + self.Spacing
        end
        want_spacing = want_spacing or (width > 0)
        if update_offsets then
            if i == 2 then self.OffsetLabel = offset end
            if i == 3 then self.OffsetShortcut = offset end
            if i == 4 then self.OffsetMark = offset end
        end
        offset = offset + width
    end
    self.NextTotalWidth = offset
end

--- @param w_icon     float
--- @param w_label    float
--- @param w_shortcut float
--- @param w_mark     float
function MT.ImGuiMenuColumns:DeclColumns(w_icon, w_label, w_shortcut, w_mark)
    self.Widths[1] = ImMax(self.Widths[1], (ImU16)(w_icon))
    self.Widths[2] = ImMax(self.Widths[2], (ImU16)(w_label))
    self.Widths[3] = ImMax(self.Widths[3], (ImU16)(w_shortcut))
    self.Widths[4] = ImMax(self.Widths[4], (ImU16)(w_mark))
    self:CalcNextTotalWidth(false)
    return ImMax(self.TotalWidth, self.NextTotalWidth)
end

-- FIXME: Provided a rectangle perhaps e.g. a BeginMenuBarEx() could be used anywhere..
-- Currently the main responsibility of this function being to setup clip-rect + horizontal layout + menu navigation layer.
-- Ideally we also want this to be responsible for claiming space out of the main window scrolling rectangle, in which case ImGuiWindowFlags.MenuBar will become unnecessary.
-- Then later the same system could be used for multiple menu-bars, scrollbars, side-bars.
function ImGui.BeginMenuBar()
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end
    if bit32.band(window.Flags, ImGuiWindowFlags.MenuBar) == 0 then
        return false
    end

    IM_ASSERT(not window.DC.MenuBarAppending)
    ImGui.BeginGroup() -- Backup position on layer 0 // FIXME: Misleading to use a group for that backup/restore
    ImGui.PushID("##MenuBar")

    -- We don't clip with current window clipping rectangle as it is already set to the area below. However we clip with window full rect.
    -- We remove 1 worth of rounding to Max.x to that text in long menus and small windows don't tend to display over the lower-right rounded area, which looks particularly glitchy.
    local border_top = ImMax(IM_ROUND(window.WindowBorderSize * 0.5 - window.TitleBarHeight), 0.0)
    local border_half = IM_ROUND(window.WindowBorderSize * 0.5)
    local bar_rect = window:MenuBarRect()
    local clip_rect = ImRect(ImFloor(bar_rect.Min.x + border_half), ImFloor(bar_rect.Min.y + border_top), ImFloor(ImMax(bar_rect.Min.x, bar_rect.Max.x - ImMax(window.WindowRounding, border_half))), ImFloor(bar_rect.Max.y))
    clip_rect:ClipWith(window.OuterRectClipped)
    ImGui.PushClipRect(clip_rect.Min, clip_rect.Max, false)

    -- We overwrite CursorMaxPos because BeginGroup sets it to CursorPos (essentially the .EmitItem hack in EndMenuBar() would need something analogous here, maybe a BeginGroupEx() with flags).
    ImVec2_Copy(window.DC.CursorPos, ImVec2(bar_rect.Min.x + window.DC.MenuBarOffset.x, bar_rect.Min.y + window.DC.MenuBarOffset.y))
    ImVec2_Copy(window.DC.CursorMaxPos, window.DC.CursorPos)
    window.DC.LayoutType = ImGuiLayoutType.Horizontal
    window.DC.IsSameLine = false
    window.DC.NavLayerCurrent = ImGuiNavLayer.Menu
    window.DC.MenuBarAppending = true
    ImGui.AlignTextToFramePadding()

    return true
end

function ImGui.EndMenuBar()
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end
    local g = GImGui

    IM_ASSERT(bit32.band(window.Flags, ImGuiWindowFlags.MenuBar) ~= 0)
    IM_ASSERT(window.DC.MenuBarAppending)

    -- Nav: When a move request within one of our child menu failed, capture the request to navigate among our siblings.
    if ImGui.NavMoveRequestButNoResultYet() and (g.NavMoveDir == ImGuiDir.Left or g.NavMoveDir == ImGuiDir.Right) and bit32.band(g.NavWindow.Flags, ImGuiWindowFlags.ChildMenu) ~= 0 then
        -- Try to find out if the request is for one of our child menu
        local nav_earliest_child = g.NavWindow
        while nav_earliest_child.ParentWindow and bit32.band(nav_earliest_child.ParentWindow.Flags, ImGuiWindowFlags.ChildMenu) ~= 0 do
            nav_earliest_child = nav_earliest_child.ParentWindow
        end
        if nav_earliest_child.ParentWindow == window and nav_earliest_child.DC.ParentLayoutType == ImGuiLayoutType.Horizontal and bit32.band(g.NavMoveFlags, ImGuiNavMoveFlags.Forwarded) == 0 then
            -- To do so we claim focus back, restore NavId and then process the movement request for yet another frame.
            -- This involve a one-frame delay which isn't very problematic in this situation. We could remove it by scoring in advance for multiple window (probably not worth bothering)
            local layer = ImGuiNavLayer.Menu
            IM_ASSERT(bit32.band(window.DC.NavLayersActiveMaskNext, bit32.lshift(1, layer)) ~= 0) -- Sanity check (FIXME: Seems unnecessary)
            ImGui.FocusWindow(window)
            ImGui.SetNavID(window.NavLastIds[layer], layer, 0, window.NavRectRel[layer])
            -- FIXME-NAV: How to deal with this when not using g.IO.ConfigNavCursorVisibleAuto?
            if g.NavCursorVisible then
                g.NavCursorVisible = false -- Hide nav cursor for the current frame so we don't see the intermediary selection. Will be set again
                g.NavCursorHideFrames = 2
            end
            g.NavHighlightItemUnderNav = true
            g.NavMousePosDirty = true
            ImGui.NavMoveRequestForward(g.NavMoveDir, g.NavMoveClipDir, g.NavMoveFlags, g.NavMoveScrollFlags) -- Repeat
        end
    else
        ImGui.NavMoveRequestTryWrapping(window, ImGuiNavMoveFlags.WrapX)
    end

    ImGui.PopClipRect()
    ImGui.PopID()
    window.DC.MenuBarOffset.x = window.DC.CursorPos.x - window.Pos.x -- Save horizontal position so next append can reuse it. This is kinda equivalent to a per-layer CursorPos.

    -- FIXME: Extremely confusing, cleanup by (a) working on WorkRect stack system (b) not using a Group confusingly here.
    local group_data = g.GroupStack:back()
    group_data.EmitItem = false
    local restore_cursor_max_pos = ImVec2()
    ImVec2_Copy(restore_cursor_max_pos, group_data.BackupCursorMaxPos)
    window.DC.IdealMaxPos.x = ImMax(window.DC.IdealMaxPos.x, window.DC.CursorMaxPos.x - window.Scroll.x) -- Convert ideal extents for scrolling layer equivalent.
    ImGui.EndGroup() -- Restore position on layer 0 // FIXME: Misleading to use a group for that backup/restore
    window.DC.LayoutType = ImGuiLayoutType.Vertical
    window.DC.IsSameLine = false
    window.DC.NavLayerCurrent = ImGuiNavLayer.Main
    window.DC.MenuBarAppending = false
    ImVec2_Copy(window.DC.CursorMaxPos, restore_cursor_max_pos)
end

-- Important: calling order matters!
-- FIXME: Somehow overlapping with docking tech.
-- FIXME: The "rect-cut" aspect of this could be formalized into a lower-level helper (rect-cut: https://halt.software/dead-simple-layouts)
--- @param name        string
--- @param viewport_p? ImGuiViewport
--- @param dir         ImGuiDir
--- @param axis_size   float
--- @param window_flags ImGuiWindowFlags
function ImGui.BeginViewportSideBar(name, viewport_p, dir, axis_size, window_flags)
    IM_ASSERT(dir ~= ImGuiDir.None)

    local bar_window = ImGui.FindWindowByName(name)
    local viewport = viewport_p or ImGui.GetMainViewport()
    if bar_window == nil or bar_window.BeginCount == 0 then
        -- Calculate and set window size/position
        local avail_rect = viewport:GetBuildWorkRect()
        local axis = (dir == ImGuiDir.Up or dir == ImGuiDir.Down) and ImGuiAxis.Y or ImGuiAxis.X
        local pos = ImVec2(avail_rect.Min.x, avail_rect.Min.y)
        if dir == ImGuiDir.Right or dir == ImGuiDir.Down then
            pos[axis] = avail_rect.Max[axis] - axis_size
        end
        local size = avail_rect:GetSize()
        size[axis] = axis_size
        ImGui.SetNextWindowPos(pos)
        ImGui.SetNextWindowSize(size)

        -- Report our size into work area (for next frame) using actual window size
        if dir == ImGuiDir.Up or dir == ImGuiDir.Left then
            viewport.BuildWorkInsetMin[axis] = viewport.BuildWorkInsetMin[axis] + axis_size
        elseif dir == ImGuiDir.Down or dir == ImGuiDir.Right then
            viewport.BuildWorkInsetMax[axis] = viewport.BuildWorkInsetMax[axis] + axis_size
        end
    end

    window_flags = bit32.bor(window_flags or 0, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoDocking)
    ImGui.SetNextWindowViewport(viewport.ID)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 0.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowMinSize, ImVec2(0, 0)) -- Lift normal size constraint
    local _, is_open = ImGui.Begin(name, nil, window_flags)
    ImGui.PopStyleVar(2)

    return is_open
end

function ImGui.BeginMainMenuBar()
    local g = GImGui
    local viewport = ImGui.GetMainViewport()

    -- Notify of viewport change so GetFrameHeight() can be accurate in case of DPI change
    ImGui.SetCurrentViewport(nil, viewport)

    -- For the main menu bar, which cannot be moved, we honor g.Style.DisplaySafeAreaPadding to ensure text can be visible on a TV set.
    -- FIXME: This could be generalized as an opt-in way to clamp window.DC.CursorStartPos to avoid SafeArea?
    -- FIXME: Consider removing support for safe area down the line... it's messy. Nowadays consoles have support for TV calibration in OS settings.
    g.NextWindowData.MenuBarOffsetMinVal = ImVec2(g.Style.DisplaySafeAreaPadding.x, ImMax(g.Style.DisplaySafeAreaPadding.y - g.Style.FramePadding.y, 0.0))
    local window_flags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoSavedSettings, ImGuiWindowFlags.MenuBar)
    local height = ImGui.GetFrameHeight()
    local is_open = ImGui.BeginViewportSideBar("##MainMenuBar", viewport, ImGuiDir.Up, height, window_flags)
    g.NextWindowData.MenuBarOffsetMinVal = ImVec2(0.0, 0.0)
    if not is_open then
        ImGui.End()
        return false
    end

    -- Temporarily disable _NoSavedSettings, in the off-chance that tables or child windows submitted within the menu-bar may want to use settings. (#8356)
    g.CurrentWindow.Flags = bit32.band(g.CurrentWindow.Flags, bit32.bnot(ImGuiWindowFlags.NoSavedSettings))
    ImGui.BeginMenuBar()
    return is_open
end

function ImGui.EndMainMenuBar()
    local g = GImGui
    IM_ASSERT_USER_ERROR_RET(g.CurrentWindow.DC.MenuBarAppending, "Calling EndMainMenuBar() not from a menu-bar!") -- Not technically testing that it is the main menu bar

    ImGui.EndMenuBar()
    g.CurrentWindow.Flags = bit32.bor(g.CurrentWindow.Flags, ImGuiWindowFlags.NoSavedSettings) -- Restore _NoSavedSettings (#8356)

    -- When the user has left the menu layer (typically: closed menus through activation of an item), we restore focus to the previous window
    -- FIXME: With this strategy we won't be able to restore a nil focus.
    if g.CurrentWindow == g.NavWindow and g.NavLayer == ImGuiNavLayer.Main and not g.NavAnyRequest and g.ActiveId == 0 then
        ImGui.FocusTopMostWindowUnderOne(g.NavWindow, nil, nil, bit32.bor(ImGuiFocusRequestFlags.UnlessBelowModal, ImGuiFocusRequestFlags.RestoreFocusedChild))
    end

    ImGui.End()
end

local function IsRootOfOpenMenuSet()
    local g = GImGui
    local window = g.CurrentWindow
    if (g.OpenPopupStack.Size <= g.BeginPopupStack.Size) or (bit32.band(window.Flags, ImGuiWindowFlags.ChildMenu) ~= 0) then
        return false
    end

    -- Initially we used 'upper_popup.OpenParentId == window.IDStack:back()' to differentiate multiple menu sets from each others
    -- (e.g. inside menu bar vs loose menu items) based on parent ID.
    -- This would however prevent the use of e.g. PushID() user code submitting menus.
    -- Previously this worked between popup and a first child menu because the first child menu always had the _ChildWindow flag,
    -- making hovering on parent popup possible while first child menu was focused - but this was generally a bug with other side effects.
    -- Instead we don't treat Popup specifically (in order to consistently support menu features in them), maybe the first child menu of a Popup
    -- doesn't have the _ChildWindow flag, and we rely on this IsRootOfOpenMenuSet() check to allow hovering between root window/popup and first child menu.
    -- In the end, lack of ID check made it so we could no longer differentiate between separate menu sets. To compensate for that, we at least check parent window nav layer.
    -- This fixes the most common case of menu opening on hover when moving between window content and menu bar. Multiple different menu sets in same nav layer would still
    -- open on hover, but that should be a lesser problem, because if such menus are close in proximity in window content then it won't feel weird and if they are far apart
    -- it likely won't be a problem anyone runs into.
    local upper_popup = g.OpenPopupStack.Data[g.BeginPopupStack.Size + 1]
    if window.DC.NavLayerCurrent ~= upper_popup.ParentNavLayer then
        return false
    end
    return upper_popup.Window and (bit32.band(upper_popup.Window.Flags, ImGuiWindowFlags.ChildMenu) ~= 0) and ImGui.IsWindowChildOf(upper_popup.Window, window, true, false)
end

--- @param label   string
--- @param icon?   string
--- @param enabled bool
function ImGui.BeginMenuEx(label, icon, enabled)
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local style = g.Style
    local id = window:GetID(label)
    local menu_is_open = ImGui.IsPopupOpen(id, ImGuiPopupFlags.None)

    -- Sub-menus are ChildWindow so that mouse can be hovering across them (otherwise top-most popup menu would steal focus and not allow hovering on parent menu)
    -- The first menu in a hierarchy isn't so hovering doesn't get across (otherwise e.g. resizing borders with ImGuiButtonFlags.FlattenChildren would react), but top-most BeginMenu() will bypass that limitation.
    local window_flags = bit32.bor(ImGuiWindowFlags.ChildMenu, ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoSavedSettings, ImGuiWindowFlags.NoNavFocus)
    if bit32.band(window.Flags, ImGuiWindowFlags.ChildMenu) ~= 0 then
        window_flags = bit32.bor(window_flags, ImGuiWindowFlags.ChildWindow)
    end

    -- If a menu with same the ID was already submitted, we will append to it, matching the behavior of Begin().
    -- We are relying on a O(N) search - so O(N log N) over the frame - which seems like the most efficient for the expected small amount of BeginMenu() calls per frame.
    -- If somehow this is ever becoming a problem we can switch to use e.g. ImGuiStorage mapping key to last frame used.
    if g.MenusIdSubmittedThisFrame:contains(id) then
        if menu_is_open then
            menu_is_open = ImGui.BeginPopupMenuEx(id, label, window_flags) -- menu_is_open can be 'false' when the popup is completely clipped (e.g. zero size display)
        else
            g.NextWindowData:ClearFlags() -- we behave like Begin() and need to consume those values
        end
        return menu_is_open
    end

    -- Tag menu as used. Next time BeginMenu() with same ID is called it will append to existing menu
    g.MenusIdSubmittedThisFrame:push_back(id)

    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size = ImGui.CalcTextSize(label, label_end, false)

    -- Odd hack to allow hovering across menus of a same menu-set (otherwise we wouldn't be able to hover parent without always being a Child window)
    -- This is only done for items for the menu set and not the full parent window.
    local menuset_is_open = IsRootOfOpenMenuSet()
    if menuset_is_open then
        g.NextItemData.ItemFlagsSet = bit32.bor(g.NextItemData.ItemFlagsSet, ImGuiItemFlags.NoWindowHoverableCheck)
    end

    -- The reference position stored in popup_pos will be used by Begin() to find a suitable position for the child menu,
    -- However the final position is going to be different! It is chosen by FindBestWindowPosForPopup().
    -- e.g. Menus tend to overlap each other horizontally to amplify relative Z-ordering.
    local popup_pos
    local pos = ImVec2()
    ImVec2_Copy(pos, window.DC.CursorPos)
    ImGui.PushID(label)
    if not enabled then
        ImGui.BeginDisabled()
    end

    local pressed

    local backup_rounding = style.SelectableRounding
    style.SelectableRounding = style.MenuItemRounding
    local selectable_flags = bit32.bor(ImGuiSelectableFlags.SelectOnClick, ImGuiSelectableFlags.NoAutoClosePopups)
    local offsets = window.DC.MenuColumns
    if window.DC.LayoutType == ImGuiLayoutType.Horizontal then
        -- Menu inside a horizontal menu bar
        -- Selectable extend their highlight by half ItemSpacing in each direction.
        -- For ChildMenu, the popup position will be overwritten by the call to FindBestWindowPosForPopup() in Begin()
        window.DC.CursorPos.x = window.DC.CursorPos.x + IM_TRUNC(style.ItemSpacing.x * 0.5)
        ImGui.PushStyleVarX(ImGuiStyleVar.ItemSpacing, style.ItemSpacing.x * 2.0)
        local text_pos = ImVec2(window.DC.CursorPos.x + offsets.OffsetLabel, pos.y + window.DC.CurrLineTextBaseOffset)
        pressed = ImGui.Selectable("", menu_is_open, selectable_flags, label_size)
        ImGui.LogSetNextTextDecoration("[", "]")
        ImGui.RenderText(text_pos, label, 1, label_end, false)
        ImGui.PopStyleVar()
        window.DC.CursorPos.x = window.DC.CursorPos.x + IM_TRUNC(style.ItemSpacing.x * (-1.0 + 0.5)) -- -1 spacing to compensate the spacing added when Selectable() did a SameLine(). It would also work to call SameLine() ourselves after the PopStyleVar().
        popup_pos = ImVec2(pos.x - 1.0 - IM_TRUNC(style.ItemSpacing.x * 0.5), text_pos.y - style.FramePadding.y + window.MenuBarHeight)
    else
        -- Menu inside a regular/vertical menu
        -- (In a typical menu window where all items are BeginMenu() or MenuItem() calls, extra_w will always be 0.0f.
        --  Only when they are other items sticking out we're going to add spacing, yet only register minimum width into the layout system.)
        local icon_w
        if (icon and icon ~= "") then icon_w = ImGui.CalcTextSize(icon, nil).x else icon_w = 0.0 end
        local checkmark_w = IM_TRUNC(g.FontSize * 1.20)
        local min_w = offsets:DeclColumns(icon_w, label_size.x, 0.0, checkmark_w) -- Feedback to next frame
        local extra_w = ImMax(0.0, ImGui.GetContentRegionAvail().x - min_w)
        local text_pos = ImVec2(window.DC.CursorPos.x, pos.y + window.DC.CurrLineTextBaseOffset)
        pressed = ImGui.Selectable("", menu_is_open, bit32.bor(selectable_flags, ImGuiSelectableFlags.SpanAvailWidth), ImVec2(min_w, label_size.y))
        ImGui.LogSetNextTextDecoration("", ">")
        ImGui.RenderText(ImVec2(text_pos.x + offsets.OffsetLabel, text_pos.y), label, 1, label_end, false)
        if icon_w > 0.0 then
            --- @cast icon string
            ImGui.RenderText(ImVec2(text_pos.x + offsets.OffsetIcon, text_pos.y), icon)
        end
        ImGui.RenderArrow(window.DrawList, ImVec2(text_pos.x + offsets.OffsetMark + extra_w + g.FontSize * 0.30, text_pos.y), ImGui.GetColorU32(ImGuiCol.Text), ImGuiDir.Right)
        popup_pos = ImVec2(pos.x, text_pos.y - style.WindowPadding.y)
    end
    style.SelectableRounding = backup_rounding

    if not enabled then
        ImGui.EndDisabled()
    end

    -- Once dragged, release ActiveId + key ownership. This is to allow the idiom of mouse down a menu, dragging elsewhere, up on some other MenuItem(). (#8233, #9394)
    -- Could move logic into lower-level ImGuiButtonFlags.AutoReleaseActiveId + ImGuiButtonFlags.AutoReleaseKeyOwner? Easier once we get rid of the Selectable() middle-man here.
    if g.ActiveId == id and g.HoveredId ~= id and g.ActiveIdSource == ImGuiInputSource.Mouse and ImGui.IsMouseDragging(0) then
        ImGui.ClearActiveID()
        ImGui.SetKeyOwner(ImGuiKey.MouseLeft, ImGuiKeyOwner_NoOwner)
    end

    local hovered = g.HoveredId == id and enabled and not g.NavHighlightItemUnderNav

    local want_open = false
    local want_open_nav_init = false
    local want_close = false
    if window.DC.LayoutType == ImGuiLayoutType.Vertical then -- (window.Flags & (ImGuiWindowFlags.Popup|ImGuiWindowFlags.ChildMenu))
        -- Close menu when not hovering it anymore unless we are moving roughly in the direction of the menu
        -- Implement http://bjk5.com/post/44698559168/breaking-down-amazons-mega-dropdown to avoid using timers, so menus feels more reactive.
        local moving_toward_child_menu = false
        local child_popup = (g.BeginPopupStack.Size < g.OpenPopupStack.Size) and g.OpenPopupStack[g.BeginPopupStack.Size + 1] or nil -- Popup candidate (testing below)
        local child_menu_window = (child_popup and child_popup.Window and child_popup.Window.ParentWindow == window) and child_popup.Window or nil
        if g.HoveredWindow == window and child_menu_window ~= nil then
            local ref_unit = g.FontSize -- FIXME-DPI
            local child_dir = (window.Pos.x < child_menu_window.Pos.x) and 1.0 or -1.0
            local next_window_rect = child_menu_window:Rect()
            local ta = (g.IO.MousePos - g.IO.MouseDelta)
            local tb
            local tc
            if child_dir > 0.0 then
                tb = next_window_rect:GetTL()
                tc = next_window_rect:GetBL()
            else
                tb = next_window_rect:GetTR()
                tc = next_window_rect:GetBR()
            end
            local pad_farmost_h = ImClamp(ImFabs(ta.x - tb.x) * 0.30, ref_unit * 0.5, ref_unit * 2.5) -- Add a bit of extra slack.
            ta.x = ta.x + child_dir * -0.5
            tb.x = tb.x + child_dir * ref_unit
            tc.x = tc.x + child_dir * ref_unit
            tb.y = ta.y + ImMax((tb.y - pad_farmost_h) - ta.y, -ref_unit * 8.0) -- Triangle has maximum height to limit the slope and the bias toward large sub-menus
            tc.y = ta.y + ImMin((tc.y + pad_farmost_h) - ta.y, ref_unit * 8.0)
            moving_toward_child_menu = ImStd.ImTriangleContainsPoint(ta, tb, tc, g.IO.MousePos)
            -- ImGui.GetForegroundDrawList():AddTriangleFilled(ta, tb, tc, moving_toward_child_menu and IM_COL32(0, 128, 0, 128) or IM_COL32(128, 0, 0, 128)) -- [DEBUG]
        end

        -- The 'HovereWindow == window' check creates an inconsistency (e.g. moving away from menu slowly tends to hit same window, whereas moving away fast does not)
        -- But we also need to not close the top-menu menu when moving over void. Perhaps we should extend the triangle check to a larger polygon.
        -- (Remember to test this on BeginPopup("A")->BeginMenu("B") sequence which behaves slightly differently as B isn't a Child of A and hovering isn't shared.)
        if menu_is_open and not hovered and g.HoveredWindow == window and not moving_toward_child_menu and not g.NavHighlightItemUnderNav and g.ActiveId == 0 then
            want_close = true
        end

        -- Open
        -- (note: at this point 'hovered' actually includes the NavDisableMouseHover == false test)
        if not menu_is_open and pressed then -- Click/activate to open
            want_open = true
        elseif not menu_is_open and hovered and not moving_toward_child_menu then -- Hover to open
            want_open = true
        elseif not menu_is_open and hovered and g.HoveredIdTimer >= 0.30 and g.MouseStationaryTimer >= 0.30 then -- Hover to open (timer fallback)
            want_open = true
        end
        if g.NavId == id and g.NavMoveDir == ImGuiDir.Right then -- Nav-Right to open
            want_open = true
            want_open_nav_init = true
            ImGui.NavMoveRequestCancel()
            ImGui.SetNavCursorVisibleAfterMove()
        end
    else
        -- Menu bar
        if menu_is_open and pressed and menuset_is_open then -- Click an open menu again to close it
            want_close = true
            want_open = false
            menu_is_open = false
        elseif pressed or (hovered and menuset_is_open and not menu_is_open) then -- First click to open, then hover to open others
            want_open = true
        elseif g.NavId == id and g.NavMoveDir == ImGuiDir.Down then -- Nav-Down to open
            want_open = true
            ImGui.NavMoveRequestCancel()
        end
    end

    if not enabled then -- explicitly close if an open menu becomes disabled, facilitate users code a lot in pattern such as 'if (BeginMenu("options", has_object)) { ..use object.. }'
        want_close = true
    end
    if want_close and ImGui.IsPopupOpen(id, ImGuiPopupFlags.None) then
        ImGui.ClosePopupToLevel(g.BeginPopupStack.Size, true)
    end

    -- IMGUI_TEST_ENGINE_ITEM_INFO(id, label, g.LastItemData.StatusFlags | ImGuiItemStatusFlags_Openable | (menu_is_open ? ImGuiItemStatusFlags_Opened : 0))
    ImGui.PopID()

    if g.ActiveId == id and want_open then
        g.ActiveIdNoClearOnFocusLoss = true
    end

    if want_open and not menu_is_open and g.OpenPopupStack.Size > g.BeginPopupStack.Size then
        -- Don't reopen/recycle same menu level in the same frame if it is a different menu ID, first close the other menu and yield for a frame.
        ImGui.OpenPopup(label)
    elseif want_open then
        menu_is_open = true
        ImGui.OpenPopup(label, ImGuiPopupFlags.NoReopen) -- | (want_open_nav_init ? ImGuiPopupFlags.NoReopenAlwaysNavInit : 0))
    end

    if menu_is_open then
        local last_item_in_parent = ImGuiLastItemData()
        ImGuiLastItemData_Copy(last_item_in_parent, g.LastItemData)

        ImGui.SetNextWindowPos(popup_pos, ImGuiCond.Always) -- Note: misleading: the value will serve as reference for FindBestWindowPosForPopup(), not actual pos.
        ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, style.PopupRounding) -- First level will use _PopupRounding, subsequent will use _ChildRounding
        menu_is_open = ImGui.BeginPopupMenuEx(id, label, window_flags) -- menu_is_open may be 'false' when the popup is completely clipped (e.g. zero size display)
        ImGui.PopStyleVar()
        if menu_is_open then
            -- Implement what ImGuiPopupFlags.NoReopenAlwaysNavInit would do:
            -- Perform an init request in the case the popup was already open (via a previous mouse hover)
            if want_open and want_open_nav_init and not g.NavInitRequest then
                ImGui.FocusWindow(g.CurrentWindow, ImGuiFocusRequestFlags.UnlessBelowModal)
                ImGui.NavInitWindow(g.CurrentWindow, false)
            end

            -- Restore LastItemData so IsItemXXXX functions can work after BeginMenu()/EndMenu()
            -- (This fixes using IsItemClicked() and IsItemHovered(), but IsItemHovered() also relies on its support for ImGuiItemFlags.NoWindowHoverableCheck)
            ImGuiLastItemData_Copy(g.LastItemData, last_item_in_parent)
            if g.HoveredWindow == window then
                g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredWindow)
            end
        end
    else
        g.NextWindowData:ClearFlags() -- We behave like Begin() and need to consume those values
    end

    return menu_is_open
end

--- @param label    string
--- @param enabled? bool
function ImGui.BeginMenu(label, enabled)
    if enabled == nil then enabled = true end

    return ImGui.BeginMenuEx(label, nil, enabled)
end

function ImGui.EndMenu()
    -- Nav: When a left move request our menu failed, close ourselves.
    local g = GImGui
    local window = g.CurrentWindow
    IM_ASSERT_USER_ERROR_RET(bit32.band(window.Flags, bit32.bor(ImGuiWindowFlags.Popup, ImGuiWindowFlags.ChildMenu)) == bit32.bor(ImGuiWindowFlags.Popup, ImGuiWindowFlags.ChildMenu), "Calling EndMenu() in wrong window!")

    local parent_window = window.ParentWindow -- Should always be ~= nil is we passed assert.
    if window.BeginCount == window.BeginCountPreviousFrame then
        if g.NavMoveDir == ImGuiDir.Left and ImGui.NavMoveRequestButNoResultYet() then
            if g.NavWindow and g.NavWindow.RootWindowForNav == window and parent_window.DC.LayoutType == ImGuiLayoutType.Vertical then
                ImGui.ClosePopupToLevel(g.BeginPopupStack.Size - 1, true)
                ImGui.NavMoveRequestCancel()
            end
        end
    end

    ImGui.EndPopup()
end

--- @param label     string
--- @param icon?     string
--- @param shortcut? string
--- @param selected? bool
--- @param enabled?  bool
-- [Luau] scratch for MenuItemEx(): only read by its callees (Selectable() only reads size_arg), never escape
local MenuItem_text_pos, MenuItem_size, MenuItem_p = ImVec2(), ImVec2(), ImVec2()
function ImGui.MenuItemEx(label, icon, shortcut, selected, enabled)
    if selected == nil then selected = false end
    if enabled  == nil then enabled  = true  end

    local window = ImGui.GetCurrentWindow()
    if window.SkipItems then
        return false
    end

    local g = GImGui
    local style = g.Style
    local pos_x, pos_y = window.DC.CursorPos.x, window.DC.CursorPos.y -- [Luau] scalar pos
    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size_x, label_size_y = ImGui.CalcTextSizeXY(label, 1, label_end, false) -- [Luau] scalar label_size

    -- See BeginMenuEx() for comments about this.
    local menuset_is_open = IsRootOfOpenMenuSet()
    if menuset_is_open then
        g.NextItemData.ItemFlagsSet = bit32.bor(g.NextItemData.ItemFlagsSet, ImGuiItemFlags.NoWindowHoverableCheck)
    end

    -- We've been using the equivalent of ImGuiSelectableFlags.SetNavIdOnHover on all Selectable() since early Nav system days (commit 43ee5d73),
    -- but I am unsure whether this should be kept at all. For now moved it to be an opt-in feature used by menus only.
    ImGui.PushID(label)
    if not enabled then
        ImGui.BeginDisabled()
    end

    local pressed

    -- We use ImGuiSelectableFlags.NoSetKeyOwner to allow down on one menu item, move, up on another.
    local backup_rounding = style.SelectableRounding
    style.SelectableRounding = style.MenuItemRounding
    local selectable_flags = bit32.bor(ImGuiSelectableFlags.SelectOnRelease, ImGuiSelectableFlags.SetNavIdOnHover)
    local offsets = window.DC.MenuColumns
    if window.DC.LayoutType == ImGuiLayoutType.Horizontal then
        -- Mimic the exact layout spacing of BeginMenu() to allow MenuItem() inside a menu bar, which is a little misleading but may be useful
        -- Note that in this situation: we don't render the shortcut, we render a highlight instead of the selected tick mark.
        window.DC.CursorPos.x = window.DC.CursorPos.x + IM_TRUNC(style.ItemSpacing.x * 0.5)
        local text_pos = MenuItem_text_pos
        text_pos.x, text_pos.y = window.DC.CursorPos.x + offsets.OffsetLabel, window.DC.CursorPos.y + window.DC.CurrLineTextBaseOffset
        ImGui.PushStyleVarX(ImGuiStyleVar.ItemSpacing, style.ItemSpacing.x * 2.0)
        local size = MenuItem_size; size.x = label_size_x; size.y = 0.0
        pressed = ImGui.Selectable("", selected, selectable_flags, size)
        ImGui.PopStyleVar()
        if bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible) ~= 0 then
            ImGui.RenderText(text_pos, label, 1, label_end, false)
        end
        window.DC.CursorPos.x = window.DC.CursorPos.x + IM_TRUNC(style.ItemSpacing.x * (-1.0 + 0.5)) -- -1 spacing to compensate the spacing added when Selectable() did a SameLine(). It would also work to call SameLine() ourselves after the PopStyleVar().
    else
        -- Menu item inside a vertical menu
        -- (In a typical menu window where all items are BeginMenu() or MenuItem() calls, extra_w will always be 0.0f.
        --  Only when they are other items sticking out we're going to add spacing, yet only register minimum width into the layout system.)
        local icon_w = 0.0
        if icon and icon ~= "" then
            icon_w = ImGui.CalcTextSize(icon, nil).x
        end
        local shortcut_w = 0.0
        if shortcut and shortcut ~= "" then
            shortcut_w = ImGui.CalcTextSize(shortcut, nil).x
        end
        local checkmark_w = IM_TRUNC(g.FontSize * 1.20) -- FIXME: Always accounted for, even in a menu with none, because 'selected' has no neutral setting.
        local min_w = offsets:DeclColumns(icon_w, label_size_x, shortcut_w, checkmark_w) -- Feedback for next frame
        local stretch_w = ImMax(0.0, ImGui.GetContentRegionAvail().x - min_w)
        local text_pos_x, text_pos_y = pos_x, pos_y + window.DC.CurrLineTextBaseOffset -- [Luau] scalar text_pos
        local size = MenuItem_size; size.x = min_w; size.y = label_size_y
        pressed = ImGui.Selectable("", false, bit32.bor(selectable_flags, ImGuiSelectableFlags.SpanAvailWidth), size)
        if bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible) ~= 0 then
            local p = MenuItem_p -- [Luau] text_pos + ImVec2(...) into scratch (RenderText()/RenderCheckMark() only read it)
            p.x, p.y = text_pos_x + offsets.OffsetLabel, text_pos_y + 0.0
            ImGui.RenderText(p, label, 1, label_end, false)
            if icon_w > 0.0 then
                --- @cast icon string
                p.x, p.y = text_pos_x + offsets.OffsetIcon, text_pos_y + 0.0
                ImGui.RenderText(p, icon)
            end
            if shortcut_w > 0.0 then
                ImGui.PushStyleColor(ImGuiCol.Text, style.Colors[ImGuiCol.TextDisabled])
                ImGui.LogSetNextTextDecoration("(", ")")
                --- @cast shortcut string
                p.x, p.y = text_pos_x + (offsets.OffsetShortcut + stretch_w), text_pos_y + 0.0
                ImGui.RenderText(p, shortcut, nil, nil, false)
                ImGui.PopStyleColor()
            end
            if selected then
                p.x, p.y = text_pos_x + (offsets.OffsetMark + stretch_w + g.FontSize * 0.40), text_pos_y + g.FontSize * 0.134 * 0.5
                ImGui.RenderCheckMark(window.DrawList, p, ImGui.GetColorU32(ImGuiCol.Text), g.FontSize * 0.866)
            end
        end
    end
    style.SelectableRounding = backup_rounding

    -- Once dragged, release ActiveId + key ownership. This is to allow the idiom of mouse down a menu, dragging elsewhere, up on some other MenuItem(). (#8233, #9394)
    -- Could move logic into lower-level ImGuiButtonFlags_AutoReleaseActiveId + ImGuiButtonFlags_AutoReleaseKeyOwner? Easier once we get rid of the Selectable() middle-man here.
    local id = g.LastItemData.ID
    if g.ActiveId == id and g.HoveredId ~= id and g.ActiveIdSource == ImGuiInputSource.Mouse and ImGui.IsMouseDragging(0) then
        ImGui.ClearActiveID()
        ImGui.SetKeyOwner(ImGuiKey.MouseLeft, ImGuiKeyOwner_NoOwner)
    end

    -- IMGUI_TEST_ENGINE_ITEM_INFO()

    if not enabled then
        ImGui.EndDisabled()
    end
    ImGui.PopID()

    return pressed
end

--- @param label     string
--- @param shortcut? string
--- @param selected? bool
--- @param enabled?  bool
function ImGui.MenuItem(label, shortcut, selected, enabled)
    if ImGui.MenuItemEx(label, nil, shortcut, selected, enabled) then
        if selected ~= nil then
            selected = not selected
        end

        return true, selected
    end

    return false, selected
end



do --[[ [SECTION] Widgets: BeginTabBar, EndTabBar, etc. (was imgui_tabs.lua) ]]
--- Dear ImGui
-- [Port] Tab bars & tab items: 1:1 port of imgui_widgets.cpp [SECTION] Widgets: BeginTabBar/BeginTabItem (docking branch)
--
-- Port notes:
-- - tab_bar.Tabs is an ImVector of ImGuiTabItem tables (references). C++ pointer arithmetic on the array is replaced by
--   index lookups. tab_bar.LastTabItemIdx and tab orders are 0-based like upstream.
-- - Tab names are stored on the tab itself (tab.Name) instead of tab_bar.TabsNames.
-- - ImGui.BeginTabItem(label, p_open, flags) returns `visible, p_open`.

local MT = ImGui.GetMetatables()

local GImGui
local function SyncContext() GImGui = ImGui.GetCurrentContext() end

local function ImLinearSweep(current, target, speed)
    if current < target then return ImMin(current + speed, target) end
    if current > target then return ImMax(current - speed, target) end
    return current
end

local function TabItemGetSectionIdx(tab)
    if bit32.band(tab.Flags, ImGuiTabItemFlags.Leading) ~= 0 then return 0 end
    if bit32.band(tab.Flags, ImGuiTabItemFlags.Trailing) ~= 0 then return 2 end
    return 1
end

-- [Luau] comparers return a boolean "less than" for table.sort (upstream: ImQsort int comparers)
local function TabItemComparerBySection(a, b)
    if a == nil or b == nil then return false end
    local a_section = TabItemGetSectionIdx(a)
    local b_section = TabItemGetSectionIdx(b)
    if a_section ~= b_section then
        return a_section < b_section
    end
    return a.IndexDuringLayout < b.IndexDuringLayout
end

local function TabItemComparerByBeginOrder(a, b)
    return a.BeginOrder < b.BeginOrder
end

local function GetTabBarFromTabBarRef(ref)
    local g = GImGui
    if ref.Ptr then return ref.Ptr else return g.TabBars:GetByIndex(ref.Index) end
end

local function GetTabBarRefFromTabBar(tab_bar)
    local g = GImGui
    if g.TabBars:Contains(tab_bar) then
        return ImGuiPtrOrIndex(g.TabBars:GetIndex(tab_bar))
    end
    return ImGuiPtrOrIndex(tab_bar)
end

-- [Port] Stable sorts (C++ ImQsort is not stable, but the comparers are total orders in practice)
local function SortTabsBySection(tab_bar)
    table.sort(tab_bar.Tabs.Data, TabItemComparerBySection)
end

local function SortTabsByBeginOrder(tab_bar)
    local data = tab_bar.Tabs.Data
    if not data then return end
    local arr = {}
    for i = 1, tab_bar.Tabs.Size do arr[i] = data[i] end
    table.sort(arr, TabItemComparerByBeginOrder)
    for i = 1, tab_bar.Tabs.Size do data[i] = arr[i] end
end

-- Scrolling happens only in the central section (leading/trailing sections are not scrolling)
local function TabBarCalcScrollableWidth(tab_bar, sections)
    return tab_bar.BarRect:GetWidth() - sections[1].Width - sections[3].Width - sections[2].Spacing
end

-- TabCount: Number of tabs in this section.
-- Width: Sum of width of tabs in this section (after shrinking down)
-- Spacing: Horizontal spacing at the end of the section.
local function ImGuiTabBarSection() return { TabCount = 0, Width = 0.0, WidthAfterShrinkMinWidth = 0.0, Spacing = 0.0 } end

-- [Luau] boolean "less than" for table.sort. Width compared exactly: upstream's (int) truncation isn't a strict weak order, which table.sort rejects
local function ShrinkWidthItemComparer(a, b)
    if a.Width ~= b.Width then return a.Width > b.Width end
    return a.Index > b.Index -- b->Index - a->Index
end

-- Shrink excess width from a set of item, by removing width from the larger items first.
-- Set items Width to -1.0f to disable shrinking this item.
-- [Port] items: 1-based array of ImGuiShrinkWidthItem, `first` = 1-based index of first item, `count` items
function ImGui.ShrinkWidths(items, first, count, width_excess, width_min)
    if count <= 0 then return end
    if count == 1 then
        local it = items[first]
        if it.Width >= 0.0 then it.Width = ImMax(it.Width - width_excess, width_min) end
        return
    end
    -- Sort largest first, smallest last.
    local slice = {}
    for n = 1, count do slice[n] = items[first + n - 1] end
    table.sort(slice, ShrinkWidthItemComparer)
    for n = 1, count do items[first + n - 1] = slice[n] end
    local it = slice
    local count_same_width = 1
    while width_excess > 0.001 and count_same_width < count do
        while count_same_width < count and it[1].Width <= it[count_same_width + 1].Width do
            count_same_width = count_same_width + 1
        end
        local max_width_to_remove_per_item = (count_same_width < count and it[count_same_width + 1].Width >= 0.0)
            and (it[1].Width - it[count_same_width + 1].Width) or (it[1].Width - 1.0)
        max_width_to_remove_per_item = ImMin(it[1].Width - width_min, max_width_to_remove_per_item)
        if max_width_to_remove_per_item <= 0.0 then break end
        local base_width_to_remove_per_item = ImMin(width_excess / count_same_width, max_width_to_remove_per_item)
        for item_n = 1, count_same_width do
            local w = ImMin(base_width_to_remove_per_item, it[item_n].Width - width_min)
            it[item_n].Width = it[item_n].Width - w
            width_excess = width_excess - w
        end
    end

    -- Round width and redistribute remainder
    -- Ensure that e.g. the right-most tab of a shrunk tab-bar always reaches exactly at the same distance from the right-most edge of the tab bar separator.
    width_excess = 0.0
    for n = 1, count do
        local width_rounded = ImTrunc(it[n].Width)
        width_excess = width_excess + it[n].Width - width_rounded
        it[n].Width = width_rounded
    end
    local guard = 0
    while width_excess > 0.0 and guard < 10000 do
        guard = guard + 1
        local progressed = false
        for n = 1, count do
            if width_excess <= 0.0 then break end
            local width_to_add = ImMin(it[n].InitialWidth - it[n].Width, 1.0)
            if width_to_add > 0 then progressed = true end
            it[n].Width = it[n].Width + width_to_add
            width_excess = width_excess - width_to_add
        end
        if not progressed then break end
    end
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: BeginTabBar, EndTabBar, etc.
-------------------------------------------------------------------------------
-- - BeginTabBar()
-- - BeginTabBarEx() [Internal]
-- - EndTabBar()
-- - TabBarLayout() [Internal]
-- - TabBarCalcTabID() [Internal]
-- - TabBarCalcMaxTabWidth() [Internal]
-- - TabBarFindTabById() [Internal]
-- - TabBarFindTabByOrder() [Internal]
-- - TabBarFindMostRecentlySelectedTabForActiveWindow() [Internal]
-- - TabBarGetCurrentTab() [Internal]
-- - TabBarGetTabName() [Internal]
-- - TabBarAddTab() [Internal]
-- - TabBarRemoveTab() [Internal]
-- - TabBarCloseTab() [Internal]
-- - TabBarScrollClamp() [Internal]
-- - TabBarScrollToTab() [Internal]
-- - TabBarQueueFocus() [Internal]
-- - TabBarQueueReorder() [Internal]
-- - TabBarProcessReorderFromMousePos() [Internal]
-- - TabBarProcessReorder() [Internal]
-- - TabBarScrollingButtons() [Internal]
-- - TabBarTabListPopupButton() [Internal]
-------------------------------------------------------------------------------

function ImGui.TabBarFindByID(id)
    SyncContext()
    return GImGui.TabBars:GetByKey(id)
end

-- Remove TabBar data (currently only used by TestEngine)
function ImGui.TabBarRemove(tab_bar)
    SyncContext()
    GImGui.TabBars:Remove(tab_bar.ID, tab_bar)
end

function ImGui.BeginTabBar(str_id, flags)
    if flags == nil then flags = 0 end
    SyncContext()
    local g = GImGui
    local window = g.CurrentWindow
    if window.SkipItems then return false end

    local id = window:GetID(str_id)
    local tab_bar = g.TabBars:GetOrAddByKey(id)
    local tab_bar_bb = ImRect(window.DC.CursorPos.x, window.DC.CursorPos.y, window.WorkRect.Max.x, window.DC.CursorPos.y + g.FontSize + g.Style.FramePadding.y * 2)
    tab_bar.ID = id
    tab_bar.SeparatorMinX = tab_bar_bb.Min.x - IM_TRUNC(window.WindowPadding.x * 0.5)
    tab_bar.SeparatorMaxX = tab_bar_bb.Max.x + IM_TRUNC(window.WindowPadding.x * 0.5)
    -- if (g.NavWindow and ImGui.IsWindowChildOf(g.NavWindow, window, false, false))
    flags = bit32.bor(flags, ImGuiTabBarFlags.IsFocused)
    return ImGui.BeginTabBarEx(tab_bar, tab_bar_bb, flags)
end

function ImGui.BeginTabBarEx(tab_bar, tab_bar_bb, flags)
    SyncContext()
    local g = GImGui
    local window = g.CurrentWindow
    if window.SkipItems then return false end

    IM_ASSERT(tab_bar.ID ~= 0)
    if bit32.band(flags, ImGuiTabBarFlags.DockNode) == 0 then -- Already done
        ImGui.PushOverrideID(tab_bar.ID)
    end

    -- Add to stack
    g.CurrentTabBarStack:push_back(GetTabBarRefFromTabBar(tab_bar))
    g.CurrentTabBar = tab_bar
    tab_bar.Window = window

    -- Append with multiple BeginTabBar()/EndTabBar() pairs.
    ImVec2_Copy(tab_bar.BackupCursorPos, window.DC.CursorPos)
    if tab_bar.CurrFrameVisible == g.FrameCount then
        ImVec2_CopyV(window.DC.CursorPos, tab_bar.BarRect.Min.x, tab_bar.BarRect.Max.y + tab_bar.ItemSpacingY)
        tab_bar.BeginCount = tab_bar.BeginCount + 1
        return true
    end

    -- Ensure correct ordering when toggling ImGuiTabBarFlags.Reorderable flag, or when a new tab was added while being not reorderable
    if bit32.band(flags, ImGuiTabBarFlags.Reorderable) ~= bit32.band(tab_bar.Flags, ImGuiTabBarFlags.Reorderable)
        or (tab_bar.TabsAddedNew and bit32.band(flags, ImGuiTabBarFlags.Reorderable) == 0) then
        if bit32.band(flags, ImGuiTabBarFlags.DockNode) == 0 then -- FIXME: TabBar with DockNode can now be hybrid
            SortTabsByBeginOrder(tab_bar)
        end
    end
    tab_bar.TabsAddedNew = false

    -- Flags
    if bit32.band(flags, ImGuiTabBarFlags.FittingPolicyMask_) == 0 then
        flags = bit32.bor(flags, ImGuiTabBarFlags.FittingPolicyDefault_)
    end

    tab_bar.Flags = flags
    tab_bar.BarRect = ImRect(tab_bar_bb.Min, tab_bar_bb.Max)
    tab_bar.WantLayout = true -- Layout will be done on the first call to ItemTab()
    tab_bar.PrevFrameVisible = tab_bar.CurrFrameVisible
    tab_bar.CurrFrameVisible = g.FrameCount
    tab_bar.PrevTabsContentsHeight = tab_bar.CurrTabsContentsHeight
    tab_bar.CurrTabsContentsHeight = 0.0
    tab_bar.ItemSpacingY = g.Style.ItemSpacing.y
    ImVec2_Copy(tab_bar.FramePadding, g.Style.FramePadding)
    tab_bar.TabsActiveCount = 0
    tab_bar.LastTabItemIdx = -1
    tab_bar.BeginCount = 1

    -- Set cursor pos in a way which only be used in the off-chance the user erroneously submits item before BeginTabItem(): items will overlap
    ImVec2_CopyV(window.DC.CursorPos, tab_bar.BarRect.Min.x, tab_bar.BarRect.Max.y + tab_bar.ItemSpacingY)

    -- Draw separator
    -- (it would be misleading to draw this in EndTabBar() suggesting that it may be drawn over tabs, as tab bar are appendable)
    local col = ImGui.GetColorU32(bit32.band(flags, ImGuiTabBarFlags.IsFocused) ~= 0 and ImGuiCol.TabSelected or ImGuiCol.TabDimmedSelected)
    if g.Style.TabBarBorderSize > 0.0 then
        local y = tab_bar.BarRect.Max.y
        window.DrawList:AddRectFilled(ImVec2(tab_bar.SeparatorMinX, y - g.Style.TabBarBorderSize), ImVec2(tab_bar.SeparatorMaxX, y), col)
    end
    return true
end

function ImGui.EndTabBar()
    SyncContext()
    local g = GImGui
    local window = g.CurrentWindow
    if window.SkipItems then return end

    local tab_bar = g.CurrentTabBar
    IM_ASSERT(tab_bar ~= nil, "Mismatched BeginTabBar()/EndTabBar()!")

    -- Fallback in case no TabItem have been submitted
    if tab_bar.WantLayout then ImGui.TabBarLayout(tab_bar) end

    -- Restore the last visible height if no tab is visible, this reduce vertical flicker/movement when a tabs gets removed without calling SetTabItemClosed().
    local tab_bar_appearing = (tab_bar.PrevFrameVisible + 1 < g.FrameCount)
    if tab_bar.VisibleTabWasSubmitted or tab_bar.VisibleTabId == 0 or tab_bar_appearing then
        tab_bar.CurrTabsContentsHeight = ImMax(window.DC.CursorPos.y - tab_bar.BarRect.Max.y, tab_bar.CurrTabsContentsHeight)
        window.DC.CursorPos.y = tab_bar.BarRect.Max.y + tab_bar.CurrTabsContentsHeight
    else
        window.DC.CursorPos.y = tab_bar.BarRect.Max.y + tab_bar.PrevTabsContentsHeight
    end
    if tab_bar.BeginCount > 1 then
        ImVec2_Copy(window.DC.CursorPos, tab_bar.BackupCursorPos)
    end

    tab_bar.LastTabItemIdx = -1
    if bit32.band(tab_bar.Flags, ImGuiTabBarFlags.DockNode) == 0 then -- Already done
        ImGui.PopID()
    end

    g.CurrentTabBarStack:pop_back()
    if g.CurrentTabBarStack.Size == 0 then g.CurrentTabBar = nil else g.CurrentTabBar = GetTabBarFromTabBarRef(g.CurrentTabBarStack:back()) end
end

-- This is called only once a frame before by the first call to ItemTab()
-- The reason we're not calling it in BeginTabBar() is to leave a chance to the user to call the SetTabItemClosed() functions.
function ImGui.TabBarLayout(tab_bar)
    SyncContext()
    local g = GImGui
    tab_bar.WantLayout = false

    -- Track selected tab when resizing our parent down
    local scroll_to_selected_tab = (tab_bar.BarRectPrevWidth > tab_bar.BarRect:GetWidth())
    tab_bar.BarRectPrevWidth = tab_bar.BarRect:GetWidth()

    -- Garbage collect by compacting list
    -- Detect if we need to sort out tab list (e.g. in rare case where a tab changed section)
    local tabs = tab_bar.Tabs
    local tab_dst_n = 0
    local need_sort_by_section = false
    local sections = { ImGuiTabBarSection(), ImGuiTabBarSection(), ImGuiTabBarSection() } -- [Port] Layout sections: Leading, Central, Trailing (1-based: [1]=Leading,[2]=Central,[3]=Trailing)
    for tab_src_n = 0, tabs.Size - 1 do
        local tab = tabs.Data[tab_src_n + 1]
        if tab.LastFrameVisible < tab_bar.PrevFrameVisible or tab.WantClose then
            -- Remove tab
            if tab_bar.VisibleTabId == tab.ID then tab_bar.VisibleTabId = 0 end
            if tab_bar.SelectedTabId == tab.ID then tab_bar.SelectedTabId = 0 end
            if tab_bar.NextSelectedTabId == tab.ID then tab_bar.NextSelectedTabId = 0 end
        else
            if tab_dst_n ~= tab_src_n then tabs.Data[tab_dst_n + 1] = tab end
            tab.IndexDuringLayout = tab_dst_n

            -- We will need sorting if tabs have changed section (e.g. moved from one of Leading/Central/Trailing to another)
            local curr_tab_section_n = TabItemGetSectionIdx(tab)
            if tab_dst_n > 0 then
                local prev_tab = tabs.Data[tab_dst_n]
                local prev_tab_section_n = TabItemGetSectionIdx(prev_tab)
                if curr_tab_section_n == 0 and prev_tab_section_n ~= 0 then need_sort_by_section = true end
                if prev_tab_section_n == 2 and curr_tab_section_n ~= 2 then need_sort_by_section = true end
            end
            sections[curr_tab_section_n + 1].TabCount = sections[curr_tab_section_n + 1].TabCount + 1
            tab_dst_n = tab_dst_n + 1
        end
    end
    if tabs.Size ~= tab_dst_n then
        for i = tab_dst_n + 1, tabs.Size do tabs.Data[i] = nil end
        tabs.Size = tab_dst_n
    end

    if need_sort_by_section then SortTabsBySection(tab_bar) end

    -- Calculate spacing between sections
    local tab_spacing = g.Style.ItemInnerSpacing.x
    sections[1].Spacing = (sections[1].TabCount > 0 and (sections[2].TabCount + sections[3].TabCount) > 0) and tab_spacing or 0.0
    sections[2].Spacing = (sections[2].TabCount > 0 and sections[3].TabCount > 0) and tab_spacing or 0.0

    -- Setup next selected tab
    local scroll_to_tab_id = 0
    if tab_bar.NextScrollToTabId ~= 0 then
        scroll_to_tab_id = tab_bar.NextScrollToTabId
        tab_bar.NextScrollToTabId = 0
    end
    if tab_bar.NextSelectedTabId ~= 0 then
        tab_bar.SelectedTabId = tab_bar.NextSelectedTabId
        tab_bar.NextSelectedTabId = 0
        scroll_to_tab_id = tab_bar.SelectedTabId
    end

    -- Process order change request (we could probably process it when requested but it's just saner to do it in a single spot).
    if tab_bar.ReorderRequestTabId ~= 0 then
        if ImGui.TabBarProcessReorder(tab_bar) then
            if tab_bar.ReorderRequestTabId == tab_bar.SelectedTabId then
                scroll_to_tab_id = tab_bar.ReorderRequestTabId
            end
        end
        tab_bar.ReorderRequestTabId = 0
    end

    -- Tab List Popup (will alter tab_bar.BarRect and therefore the available width!)
    local tab_list_popup_button = bit32.band(tab_bar.Flags, ImGuiTabBarFlags.TabListPopupButton) ~= 0
    if tab_list_popup_button then
        local tab_to_select = ImGui.TabBarTabListPopupButton(tab_bar) -- NB: Will alter BarRect.Min.x!
        if tab_to_select then
            tab_bar.SelectedTabId = tab_to_select.ID
            scroll_to_tab_id = tab_to_select.ID
        end
    end

    -- Leading/Trailing tabs will be shrink only if central one aren't visible anymore, so layout the shrink data as: leading, trailing, central
    -- (whereas our tabs are stored as: leading, central, trailing)
    -- [Port] (shrink_buffer_indexes holds 0-based offsets)
    local shrink_buffer_indexes = { 0, sections[1].TabCount + sections[3].TabCount, sections[1].TabCount }
    local swb = g.ShrinkWidthBuffer
    swb:resize(tabs.Size)
    for i = 1, tabs.Size do if swb.Data[i] == nil then swb.Data[i] = ImGuiShrinkWidthItem() end end

    -- Minimum shrink width
    local shrink_min_width = (bit32.band(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyMixed) ~= 0) and g.Style.TabMinWidthShrink or 1.0

    -- Compute ideal tabs widths + store them into shrink buffer
    local most_recently_selected_tab = nil
    local curr_section_n = -1
    local found_selected_tab_id = false
    for tab_n = 0, tabs.Size - 1 do
        local tab = tabs.Data[tab_n + 1]
        IM_ASSERT(tab.LastFrameVisible >= tab_bar.PrevFrameVisible)

        if (most_recently_selected_tab == nil or most_recently_selected_tab.LastFrameSelected < tab.LastFrameSelected) and bit32.band(tab.Flags, ImGuiTabItemFlags.Button) == 0 then
            most_recently_selected_tab = tab
        end
        if tab.ID == tab_bar.SelectedTabId then found_selected_tab_id = true end
        if scroll_to_tab_id == 0 and g.NavJustMovedToId == tab.ID then scroll_to_tab_id = tab.ID end

        -- Refresh tab width immediately, otherwise changes of style e.g. style.FramePadding.x would noticeably lag in the tab bar.
        -- Additionally, when using TabBarAddTab() to manipulate tab bar order we occasionally insert new tabs that don't have a width yet,
        -- and we cannot wait for the next BeginTabItem() call. We cannot compute this width within TabBarAddTab() because font size depends on the active window.
        local tab_name = ImGui.TabBarGetTabName(tab_bar, tab)
        local has_close_button_or_unsaved_marker = bit32.band(tab.Flags, ImGuiTabItemFlags.NoCloseButton) == 0 or bit32.band(tab.Flags, ImGuiTabItemFlags.UnsavedDocument) ~= 0
        tab.ContentWidth = (tab.RequestedWidth >= 0.0) and tab.RequestedWidth or ImGui.TabItemCalcSize(tab_name, has_close_button_or_unsaved_marker).x
        if bit32.band(tab.Flags, ImGuiTabItemFlags.Button) == 0 then
            tab.ContentWidth = ImMax(tab.ContentWidth, g.Style.TabMinWidthBase)
        end

        local section_n = TabItemGetSectionIdx(tab)
        local section = sections[section_n + 1]
        section.Width = section.Width + tab.ContentWidth + ((section_n == curr_section_n) and tab_spacing or 0.0)
        section.WidthAfterShrinkMinWidth = section.WidthAfterShrinkMinWidth + ImMin(tab.ContentWidth, shrink_min_width) + ((section_n == curr_section_n) and tab_spacing or 0.0)
        curr_section_n = section_n

        -- Store data so we can build an array sorted by width if we need to shrink tabs down
        local item = swb.Data[shrink_buffer_indexes[section_n + 1] + 1]
        shrink_buffer_indexes[section_n + 1] = shrink_buffer_indexes[section_n + 1] + 1
        item.Index = tab_n
        item.Width = tab.ContentWidth
        item.InitialWidth = tab.ContentWidth
        tab.Width = ImMax(tab.ContentWidth, 1.0)
    end

    -- Compute total ideal width (used for e.g. auto-resizing a window)
    local width_all_tabs_after_min_width_shrink = 0.0
    tab_bar.WidthAllTabsIdeal = 0.0
    for section_n = 1, 3 do
        tab_bar.WidthAllTabsIdeal = tab_bar.WidthAllTabsIdeal + sections[section_n].Width + sections[section_n].Spacing
        width_all_tabs_after_min_width_shrink = width_all_tabs_after_min_width_shrink + sections[section_n].WidthAfterShrinkMinWidth + sections[section_n].Spacing
    end

    -- Horizontal scrolling buttons
    -- - Important: note that TabBarScrollButtons() will alter BarRect.Max.x.
    -- - Selection skips buttons and might cross through sections if there are Tabs in Leading/Trailing sections.
    local can_scroll = bit32.band(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyScroll) ~= 0 or bit32.band(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyMixed) ~= 0
    local width_all_tabs_to_use_for_scroll = (bit32.band(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyScroll) ~= 0) and tab_bar.WidthAllTabs or width_all_tabs_after_min_width_shrink
    tab_bar.ScrollButtonEnabled = (width_all_tabs_to_use_for_scroll > tab_bar.BarRect:GetWidth() and tabs.Size > 1)
        and bit32.band(tab_bar.Flags, ImGuiTabBarFlags.NoTabListScrollingButtons) == 0 and can_scroll
    if tab_bar.ScrollButtonEnabled then
        local scroll_and_select_tab = ImGui.TabBarScrollingButtons(tab_bar)
        if scroll_and_select_tab then
            if bit32.band(scroll_and_select_tab.Flags, ImGuiTabItemFlags.Button) == 0 then
                tab_bar.SelectedTabId = scroll_and_select_tab.ID
            end
            scroll_to_tab_id = scroll_and_select_tab.ID
        end
    end
    if scroll_to_tab_id == 0 and scroll_to_selected_tab then
        scroll_to_tab_id = tab_bar.SelectedTabId
    end

    -- Shrink widths if full tabs don't fit in their allocated space
    local section_0_w = sections[1].Width + sections[1].Spacing
    local section_1_w = sections[2].Width + sections[2].Spacing
    local section_2_w = sections[3].Width + sections[3].Spacing
    local central_section_is_visible = (section_0_w + section_2_w) < tab_bar.BarRect:GetWidth()
    local width_excess
    if central_section_is_visible then
        width_excess = ImMax(section_1_w - (tab_bar.BarRect:GetWidth() - section_0_w - section_2_w), 0.0) -- Excess used to shrink central section
    else
        width_excess = (section_0_w + section_2_w) - tab_bar.BarRect:GetWidth() -- Excess used to shrink leading/trailing section
    end

    -- With ImGuiTabBarFlags.FittingPolicyScroll policy, we will only shrink leading/trailing if the central section is not visible anymore
    local can_shrink = bit32.band(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyShrink) ~= 0 or bit32.band(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyMixed) ~= 0
    if width_excess >= 1.0 and (can_shrink or not central_section_is_visible) then
        local shrink_data_count = central_section_is_visible and sections[2].TabCount or (sections[1].TabCount + sections[3].TabCount)
        local shrink_data_offset = central_section_is_visible and (sections[1].TabCount + sections[3].TabCount) or 0
        ImGui.ShrinkWidths(swb.Data, shrink_data_offset + 1, shrink_data_count, width_excess, shrink_min_width)

        -- Apply shrunk values into tabs and sections
        for tab_n = shrink_data_offset, shrink_data_offset + shrink_data_count - 1 do
            local item = swb.Data[tab_n + 1]
            local tab = tabs.Data[item.Index + 1]
            local shrinked_width = IM_TRUNC(item.Width)
            if shrinked_width >= 0.0 then
                shrinked_width = ImMax(1.0, shrinked_width)
                local section_n = TabItemGetSectionIdx(tab)
                sections[section_n + 1].Width = sections[section_n + 1].Width - (tab.Width - shrinked_width)
                tab.Width = shrinked_width
            end
        end
    end

    -- Layout all active tabs
    local section_tab_index = 0
    local tab_offset = 0.0
    tab_bar.WidthAllTabs = 0.0
    for section_n = 0, 2 do
        local section = sections[section_n + 1]
        if section_n == 2 then
            tab_offset = ImMin(ImMax(0.0, tab_bar.BarRect:GetWidth() - section.Width), tab_offset)
        end
        for tab_n = 0, section.TabCount - 1 do
            local tab = tabs.Data[section_tab_index + tab_n + 1]
            tab.Offset = tab_offset
            tab.NameOffset = -1
            tab_offset = tab_offset + tab.Width + ((tab_n < section.TabCount - 1) and g.Style.ItemInnerSpacing.x or 0.0)
        end
        tab_bar.WidthAllTabs = tab_bar.WidthAllTabs + ImMax(section.Width + section.Spacing, 0.0)
        tab_offset = tab_offset + section.Spacing
        section_tab_index = section_tab_index + section.TabCount
    end

    -- If we have lost the selected tab, select the next most recently active one
    local tab_bar_appearing = (tab_bar.PrevFrameVisible + 1 < g.FrameCount)
    if found_selected_tab_id == false and not tab_bar_appearing then
        tab_bar.SelectedTabId = 0
    end
    if tab_bar.SelectedTabId == 0 and tab_bar.NextSelectedTabId == 0 and most_recently_selected_tab ~= nil then
        tab_bar.SelectedTabId = most_recently_selected_tab.ID
        scroll_to_tab_id = tab_bar.SelectedTabId
    end

    -- Lock in visible tab
    tab_bar.VisibleTabId = tab_bar.SelectedTabId
    tab_bar.VisibleTabWasSubmitted = false

    -- CTRL+TAB can override visible tab temporarily
    if g.NavWindowingTarget ~= nil and g.NavWindowingTarget.DockNode and g.NavWindowingTarget.DockNode.TabBar == tab_bar then
        tab_bar.VisibleTabId = g.NavWindowingTarget.TabId
        scroll_to_tab_id = tab_bar.VisibleTabId
    end

    -- Apply request requests
    if scroll_to_tab_id ~= 0 then
        ImGui.TabBarScrollToTab(tab_bar, scroll_to_tab_id, sections)
    elseif tab_bar.ScrollButtonEnabled and ImGui.IsMouseHoveringRect(tab_bar.BarRect.Min, tab_bar.BarRect.Max, true) and ImGui.IsWindowContentHoverable(g.CurrentWindow) then
        local wheel = g.IO.MouseWheelRequestAxisSwap and g.IO.MouseWheel or g.IO.MouseWheelH
        local wheel_key = g.IO.MouseWheelRequestAxisSwap and ImGuiKey.MouseWheelY or ImGuiKey.MouseWheelX
        if ImGui.TestKeyOwner(wheel_key, tab_bar.ID) and wheel ~= 0.0 then
            local scroll_step = wheel * TabBarCalcScrollableWidth(tab_bar, sections) / 3.0
            tab_bar.ScrollingTargetDistToVisibility = 0.0
            tab_bar.ScrollingTarget = ImGui.TabBarScrollClamp(tab_bar, tab_bar.ScrollingTarget - scroll_step)
        end
        ImGui.SetKeyOwner(wheel_key, tab_bar.ID)
    end

    -- Update scrolling
    tab_bar.ScrollingAnim = ImGui.TabBarScrollClamp(tab_bar, tab_bar.ScrollingAnim)
    tab_bar.ScrollingTarget = ImGui.TabBarScrollClamp(tab_bar, tab_bar.ScrollingTarget)
    if tab_bar.ScrollingAnim ~= tab_bar.ScrollingTarget then
        -- Scrolling speed adjust itself so we can always reach our target in 1/3 seconds.
        -- Teleport if we are aiming far off the visible line
        tab_bar.ScrollingSpeed = ImMax(tab_bar.ScrollingSpeed, 70.0 * g.FontSize)
        tab_bar.ScrollingSpeed = ImMax(tab_bar.ScrollingSpeed, math.abs(tab_bar.ScrollingTarget - tab_bar.ScrollingAnim) / 0.3)
        local teleport = (tab_bar.PrevFrameVisible + 1 < g.FrameCount) or (tab_bar.ScrollingTargetDistToVisibility > 10.0 * g.FontSize)
        tab_bar.ScrollingAnim = teleport and tab_bar.ScrollingTarget or ImLinearSweep(tab_bar.ScrollingAnim, tab_bar.ScrollingTarget, g.IO.DeltaTime * tab_bar.ScrollingSpeed)
    else
        tab_bar.ScrollingSpeed = 0.0
    end
    tab_bar.ScrollingRectMinX = tab_bar.BarRect.Min.x + sections[1].Width + sections[1].Spacing
    tab_bar.ScrollingRectMaxX = tab_bar.BarRect.Max.x - sections[3].Width - sections[2].Spacing

    -- Actual layout in host window (we don't do it in BeginTabBar() so as not to waste an extra frame)
    local window = g.CurrentWindow
    ImVec2_Copy(window.DC.CursorPos, tab_bar.BarRect.Min)
    ImGui.ItemSize(ImVec2(tab_bar.WidthAllTabs, tab_bar.BarRect:GetHeight()), tab_bar.FramePadding.y)
    window.DC.IdealMaxPos.x = ImMax(window.DC.IdealMaxPos.x, tab_bar.BarRect.Min.x + tab_bar.WidthAllTabsIdeal)
end

-- Dockable windows uses Name/ID in the global namespace. Non-dockable items use the ID stack.
function ImGui.TabBarCalcTabID(tab_bar, label, docked_window)
    if docked_window ~= nil then
        IM_ASSERT(bit32.band(tab_bar.Flags, ImGuiTabBarFlags.DockNode) ~= 0)
        local id = docked_window.TabId
        ImGui.KeepAliveID(id)
        return id
    end
    return ImGui.GetCurrentContext().CurrentWindow:GetID(label)
end

function ImGui.TabBarCalcMaxTabWidth()
    return ImGui.GetCurrentContext().FontSize * 20.0
end

function ImGui.TabBarFindTabByID(tab_bar, tab_id)
    if tab_id ~= 0 then
        for n = 1, tab_bar.Tabs.Size do
            local tab = tab_bar.Tabs.Data[n]
            if tab.ID == tab_id then return tab end
        end
    end
    return nil
end

-- Order = visible order, not submission order! (which is tab.BeginOrder)
--- @param order int # 0-based visible order
function ImGui.TabBarFindTabByOrder(tab_bar, order)
    if order < 0 or order >= tab_bar.Tabs.Size then return nil end
    return tab_bar.Tabs.Data[order + 1]
end

--- @return int # 0-based order
function ImGui.TabBarGetTabOrder(tab_bar, tab)
    local i = tab_bar.Tabs:find_index(tab)
    return i and (i - 1) or -1
end

-- FIXME: See references to #2304 in TODO.txt
function ImGui.TabBarFindMostRecentlySelectedTabForActiveWindow(tab_bar)
    local most_recently_selected_tab = nil
    for n = 1, tab_bar.Tabs.Size do
        local tab = tab_bar.Tabs.Data[n]
        if most_recently_selected_tab == nil or most_recently_selected_tab.LastFrameSelected < tab.LastFrameSelected then
            if tab.Window and tab.Window.WasActive then most_recently_selected_tab = tab end
        end
    end
    return most_recently_selected_tab
end

function ImGui.TabBarGetCurrentTab(tab_bar)
    if tab_bar.LastTabItemIdx < 0 or tab_bar.LastTabItemIdx >= tab_bar.Tabs.Size then return nil end
    return tab_bar.Tabs.Data[tab_bar.LastTabItemIdx + 1]
end

function ImGui.TabBarGetTabName(tab_bar, tab)
    if tab.Window then return tab.Window.Name end
    if tab.Name == nil then return "N/A" end
    return tab.Name
end

function ImGui.TabBarGetTabPos(tab_bar, tab)
    if bit32.band(tab.Flags, ImGuiTabItemFlags.SectionMask_) == 0 then
        return tab_bar.BarRect.Min + ImVec2(IM_TRUNC(tab.Offset - tab_bar.ScrollingAnim), 0.0)
    end
    return tab_bar.BarRect.Min + ImVec2(tab.Offset, 0.0)
end

-- The purpose of this call is to register tab in advance so we can control their order at the time they appear.
-- Otherwise calling this is unnecessary as tabs are appending as needed by the BeginTabItem() function.
function ImGui.TabBarAddTab(tab_bar, tab_flags, window)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(ImGui.TabBarFindTabByID(tab_bar, window.TabId) == nil)
    IM_ASSERT(g.CurrentTabBar ~= tab_bar) -- Can't work while the tab bar is active as our tab doesn't have an X offset yet, in theory we could/should test something like (tab_bar.CurrFrameVisible < g.FrameCount) but we'd need to solve why triggers the commented early-out assert in BeginTabBarEx() (probably dock node going from implicit to explicit in same frame)
    if not window.HasCloseButton then
        tab_flags = bit32.bor(tab_flags, ImGuiTabItemFlags.NoCloseButton) -- Set _NoCloseButton immediately because it will be used for first-frame width calculation.
    end
    local new_tab = ImGuiTabItem()
    new_tab.ID = window.TabId
    new_tab.Flags = tab_flags
    new_tab.LastFrameVisible = tab_bar.CurrFrameVisible -- Required so BeginTabBar() doesn't ditch the tab
    if new_tab.LastFrameVisible == -1 then new_tab.LastFrameVisible = g.FrameCount - 1 end
    new_tab.Window = window -- Required so tab bar layout can compute the tab width before tab submission
    tab_bar.Tabs:push_back(new_tab)
end

-- The *TabId fields are already set by the docking system _before_ the actual TabItem was created, so we clear them regardless.
function ImGui.TabBarRemoveTab(tab_bar, tab_id)
    local tab = ImGui.TabBarFindTabByID(tab_bar, tab_id)
    if tab then tab_bar.Tabs:erase(tab_bar.Tabs:find_index(tab)) end
    if tab_bar.VisibleTabId == tab_id then tab_bar.VisibleTabId = 0 end
    if tab_bar.SelectedTabId == tab_id then tab_bar.SelectedTabId = 0 end
    if tab_bar.NextSelectedTabId == tab_id then tab_bar.NextSelectedTabId = 0 end
end

-- Called on manual closure attempt
function ImGui.TabBarCloseTab(tab_bar, tab)
    if bit32.band(tab.Flags, ImGuiTabItemFlags.Button) ~= 0 then return end -- A button appended with TabItemButton().

    if bit32.band(tab.Flags, bit32.bor(ImGuiTabItemFlags.UnsavedDocument, ImGuiTabItemFlags.NoAssumedClosure)) == 0 then
        -- This will remove a frame of lag for selecting another tab on closure.
        -- However we don't run it in the case where the 'Unsaved' flag is set, so user gets a chance to fully undo the closure
        tab.WantClose = true
        if tab_bar.VisibleTabId == tab.ID then
            tab.LastFrameVisible = -1
            tab_bar.SelectedTabId = 0
            tab_bar.NextSelectedTabId = 0
        end
    else
        -- Actually select before expecting closure attempt (on an UnsavedDocument tab user is expect to e.g. show a popup)
        if tab_bar.VisibleTabId ~= tab.ID then ImGui.TabBarQueueFocus(tab_bar, tab) end
    end
end

function ImGui.TabBarScrollClamp(tab_bar, scrolling)
    scrolling = ImMin(scrolling, tab_bar.WidthAllTabs - tab_bar.BarRect:GetWidth())
    return ImMax(scrolling, 0.0)
end

-- Note: we may scroll to tab that are not selected! e.g. using keyboard arrow keys
function ImGui.TabBarScrollToTab(tab_bar, tab_id, sections)
    local tab = ImGui.TabBarFindTabByID(tab_bar, tab_id)
    if tab == nil then return end

    -- Clamp attempt to scroll to leading/trailing sections items.
    -- This could be done at the TabBarScrollingButtons() call site as well, but here works.
    if bit32.band(tab.Flags, ImGuiTabItemFlags.Leading) ~= 0 then
        tab = tab_bar.Tabs.Data[sections[1].TabCount + 1]
    elseif bit32.band(tab.Flags, ImGuiTabItemFlags.Trailing) ~= 0 then
        tab = tab_bar.Tabs.Data[sections[1].TabCount + sections[2].TabCount + 1]
    end
    if tab == nil or bit32.band(tab.Flags, ImGuiTabItemFlags.SectionMask_) ~= 0 then return end

    -- When scrolling to make Tab N+1 visible always make a bit of N visible to suggest more scrolling area (since we don't have a scrollbar)
    -- Disable the margin if the scrolling section is too small for the target tab: prefer displaying a maximum of the label.
    local g = ImGui.GetCurrentContext()
    local margin = ImClamp(tab_bar.ScrollingRectMaxX - tab_bar.ScrollingRectMinX - tab.Width, g.Style.ItemInnerSpacing.x, g.FontSize * 1.0)
    local order = ImGui.TabBarGetTabOrder(tab_bar, tab)

    -- Scrolling happens only in the central section (leading/trailing sections are not scrolling)
    local scrollable_width = TabBarCalcScrollableWidth(tab_bar, sections)

    -- We make all tabs positions all relative Sections[0].Width to make code simpler
    local tab_x1 = tab.Offset - sections[1].Width + ((order > sections[1].TabCount - 1) and -margin or 0.0)
    local tab_x2 = tab.Offset - sections[1].Width + tab.Width + ((order + 1 < tab_bar.Tabs.Size - sections[3].TabCount) and margin or 1.0)
    tab_bar.ScrollingTargetDistToVisibility = 0.0
    if tab_bar.ScrollingTarget > tab_x1 or (tab_x2 - tab_x1 >= scrollable_width) then
        -- Scroll to the left
        tab_bar.ScrollingTargetDistToVisibility = ImMax(tab_bar.ScrollingAnim - tab_x2, 0.0)
        tab_bar.ScrollingTarget = tab_x1
    elseif tab_bar.ScrollingTarget < tab_x2 - scrollable_width then
        -- Scroll to the right
        tab_bar.ScrollingTargetDistToVisibility = ImMax((tab_x1 - scrollable_width) - tab_bar.ScrollingAnim, 0.0)
        tab_bar.ScrollingTarget = tab_x2 - scrollable_width
    end
end

--- TabBarQueueFocus(tab_bar, tab) or TabBarQueueFocus(tab_bar, tab_name)
function ImGui.TabBarQueueFocus(tab_bar, tab)
    if type(tab) == "string" then
        IM_ASSERT(bit32.band(tab_bar.Flags, ImGuiTabBarFlags.DockNode) == 0) -- Only supported for manual/explicit tab bars
        tab_bar.NextSelectedTabId = ImGui.TabBarCalcTabID(tab_bar, tab, nil)
        return
    end
    tab_bar.NextSelectedTabId = tab.ID
end

function ImGui.TabBarQueueReorder(tab_bar, tab, offset)
    IM_ASSERT(offset ~= 0)
    IM_ASSERT(tab_bar.ReorderRequestTabId == 0)
    tab_bar.ReorderRequestTabId = tab.ID
    tab_bar.ReorderRequestOffset = offset
end

function ImGui.TabBarQueueReorderFromMousePos(tab_bar, src_tab, mouse_pos)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(tab_bar.ReorderRequestTabId == 0)
    if bit32.band(tab_bar.Flags, ImGuiTabBarFlags.Reorderable) == 0 then return end

    local tab_spacing = g.Style.ItemInnerSpacing.x
    local is_central_section = bit32.band(src_tab.Flags, ImGuiTabItemFlags.SectionMask_) == 0
    local bar_offset = tab_bar.BarRect.Min.x - (is_central_section and tab_bar.ScrollingTarget or 0)

    -- Count number of contiguous tabs we are crossing over
    local dir = ((bar_offset + src_tab.Offset) > mouse_pos.x) and -1 or 1
    local src_idx = ImGui.TabBarGetTabOrder(tab_bar, src_tab)
    local dst_idx = src_idx
    local i = src_idx
    while i >= 0 and i < tab_bar.Tabs.Size do
        -- Reordered tabs must share the same section
        local dst_tab = tab_bar.Tabs.Data[i + 1]
        if bit32.band(dst_tab.Flags, ImGuiTabItemFlags.NoReorder) ~= 0 then break end
        if bit32.band(dst_tab.Flags, ImGuiTabItemFlags.SectionMask_) ~= bit32.band(src_tab.Flags, ImGuiTabItemFlags.SectionMask_) then break end
        dst_idx = i

        -- Include spacing after tab, so when mouse cursor is between tabs we would not continue checking further tabs that are not hovered.
        local x1 = bar_offset + dst_tab.Offset - tab_spacing
        local x2 = bar_offset + dst_tab.Offset + dst_tab.Width + tab_spacing
        -- ImGui.GetForegroundDrawList():AddRect(ImVec2(x1, tab_bar.BarRect.Min.y), ImVec2(x2, tab_bar.BarRect.Max.y), IM_COL32(255, 0, 0, 255))
        if (dir < 0 and mouse_pos.x > x1) or (dir > 0 and mouse_pos.x < x2) then break end
        i = i + dir
    end

    if dst_idx ~= src_idx then
        ImGui.TabBarQueueReorder(tab_bar, src_tab, dst_idx - src_idx)
    end
end

function ImGui.TabBarProcessReorder(tab_bar)
    local tab1 = ImGui.TabBarFindTabByID(tab_bar, tab_bar.ReorderRequestTabId)
    if tab1 == nil or bit32.band(tab1.Flags, ImGuiTabItemFlags.NoReorder) ~= 0 then return false end

    -- IM_ASSERT(bit32.band(tab_bar.Flags, ImGuiTabBarFlags.Reorderable) ~= 0) -- <- this may happen when using debug tools
    local tab1_order = ImGui.TabBarGetTabOrder(tab_bar, tab1)
    local tab2_order = tab1_order + tab_bar.ReorderRequestOffset
    if tab2_order < 0 or tab2_order >= tab_bar.Tabs.Size then return false end

    -- Reordered tabs must share the same section
    -- (Note: TabBarQueueReorderFromMousePos() also has a similar test but since we allow direct calls to TabBarQueueReorder() we do it here too)
    local tab2 = tab_bar.Tabs.Data[tab2_order + 1]
    if bit32.band(tab2.Flags, ImGuiTabItemFlags.NoReorder) ~= 0 then return false end
    if bit32.band(tab1.Flags, ImGuiTabItemFlags.SectionMask_) ~= bit32.band(tab2.Flags, ImGuiTabItemFlags.SectionMask_) then return false end

    -- [Port] Move tab1 to tab2's position, shifting the tabs in between
    table.remove(tab_bar.Tabs.Data, tab1_order + 1)
    table.insert(tab_bar.Tabs.Data, tab2_order + 1, tab1)

    if bit32.band(tab_bar.Flags, ImGuiTabBarFlags.SaveSettings) ~= 0 then ImGui.MarkIniSettingsDirty() end
    return true
end

function ImGui.TabBarScrollingButtons(tab_bar)
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow

    local arrow_button_size = ImVec2(g.FontSize - 2.0, g.FontSize + g.Style.FramePadding.y * 2.0)
    local scrolling_buttons_width = arrow_button_size.x * 2.0

    local backup_cursor_pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y)
    -- window.DrawList:AddRect(ImVec2(tab_bar.BarRect.Max.x - scrolling_buttons_width, tab_bar.BarRect.Min.y), ImVec2(tab_bar.BarRect.Max.x, tab_bar.BarRect.Max.y), IM_COL32(255,0,0,255))

    local select_dir = 0
    local tc = g.Style.Colors[ImGuiCol.Text]
    local arrow_col = ImVec4(tc.x, tc.y, tc.z, tc.w * 0.5)

    ImGui.PushStyleColor(ImGuiCol.Text, arrow_col)
    ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
    ImGui.PushItemFlag(bit32.bor(ImGuiItemFlags.ButtonRepeat, ImGuiItemFlags.NoNav), true)
    local backup_repeat_delay = g.IO.KeyRepeatDelay
    local backup_repeat_rate = g.IO.KeyRepeatRate
    g.IO.KeyRepeatDelay = 0.250
    g.IO.KeyRepeatRate = 0.200
    local x = ImMax(tab_bar.BarRect.Min.x, tab_bar.BarRect.Max.x - scrolling_buttons_width)
    ImVec2_CopyV(window.DC.CursorPos, x, tab_bar.BarRect.Min.y)
    if ImGui.ArrowButtonEx("##<", ImGuiDir.Left, arrow_button_size, ImGuiButtonFlags.PressedOnClick) then select_dir = -1 end
    ImVec2_CopyV(window.DC.CursorPos, x + arrow_button_size.x, tab_bar.BarRect.Min.y)
    if ImGui.ArrowButtonEx("##>", ImGuiDir.Right, arrow_button_size, ImGuiButtonFlags.PressedOnClick) then select_dir = 1 end
    ImGui.PopItemFlag()
    ImGui.PopStyleColor(2)
    g.IO.KeyRepeatRate = backup_repeat_rate
    g.IO.KeyRepeatDelay = backup_repeat_delay

    local tab_to_scroll_to = nil
    if select_dir ~= 0 then
        local tab_item = ImGui.TabBarFindTabByID(tab_bar, tab_bar.SelectedTabId)
        if tab_item then
            local selected_order = ImGui.TabBarGetTabOrder(tab_bar, tab_item)
            local target_order = selected_order + select_dir

            -- Skip tab item buttons until another tab item is found or end is reached
            while tab_to_scroll_to == nil do
                -- If we are at the end of the list, still scroll to make our tab visible
                local idx = (target_order >= 0 and target_order < tab_bar.Tabs.Size) and target_order or selected_order
                tab_to_scroll_to = tab_bar.Tabs.Data[idx + 1]

                -- Cross through buttons
                -- (even if first/last item is a button, return it so we can update the scroll)
                if bit32.band(tab_to_scroll_to.Flags, ImGuiTabItemFlags.Button) ~= 0 then
                    target_order = target_order + select_dir
                    selected_order = selected_order + select_dir
                    if not (target_order < 0 or target_order >= tab_bar.Tabs.Size) then tab_to_scroll_to = nil end
                end
            end
        end
    end
    ImVec2_Copy(window.DC.CursorPos, backup_cursor_pos)
    tab_bar.BarRect.Max.x = tab_bar.BarRect.Max.x - (scrolling_buttons_width + 1.0)

    return tab_to_scroll_to
end

function ImGui.TabBarTabListPopupButton(tab_bar)
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow

    -- We use g.Style.FramePadding.y to match the square ArrowButton size
    local tab_list_popup_button_width = g.FontSize + g.Style.FramePadding.y
    local backup_cursor_pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y)
    ImVec2_CopyV(window.DC.CursorPos, tab_bar.BarRect.Min.x - g.Style.FramePadding.y, tab_bar.BarRect.Min.y)
    tab_bar.BarRect.Min.x = tab_bar.BarRect.Min.x + tab_list_popup_button_width

    local tc = g.Style.Colors[ImGuiCol.Text]
    ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(tc.x, tc.y, tc.z, tc.w * 0.5))
    ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
    local open = ImGui.BeginCombo("##v", nil, bit32.bor(ImGuiComboFlags.NoPreview, ImGuiComboFlags.HeightLargest))
    ImGui.PopStyleColor(2)

    local tab_to_select = nil
    if open then
        for n = 1, tab_bar.Tabs.Size do
            local tab = tab_bar.Tabs.Data[n]
            if bit32.band(tab.Flags, ImGuiTabItemFlags.Button) == 0 then
                local tab_name = ImGui.TabBarGetTabName(tab_bar, tab)
                if ImGui.Selectable(tab_name, tab_bar.SelectedTabId == tab.ID) then
                    tab_to_select = tab
                end
            end
        end
        ImGui.EndCombo()
    end

    ImVec2_Copy(window.DC.CursorPos, backup_cursor_pos)
    return tab_to_select
end

-------------------------------------------------------------------------------
-- [SECTION] Widgets: BeginTabItem, EndTabItem, etc.
-------------------------------------------------------------------------------
-- - BeginTabItem()
-- - EndTabItem()
-- - TabItemButton()
-- - TabItemEx() [Internal]
-- - SetTabItemClosed()
-- - TabItemCalcSize() [Internal]
-- - TabItemBackground() [Internal]
-- - TabItemLabelAndCloseButton() [Internal]
-------------------------------------------------------------------------------

--- @return bool visible, bool? p_open
function ImGui.BeginTabItem(label, p_open, flags)
    if flags == nil then flags = 0 end
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow
    if window.SkipItems then return false, p_open end

    local tab_bar = g.CurrentTabBar
    IM_ASSERT(tab_bar ~= nil, "Needs to be called between BeginTabBar() and EndTabBar()!")
    IM_ASSERT(bit32.band(flags, ImGuiTabItemFlags.Button) == 0) -- BeginTabItem() Can't be used with button flags, use TabItemButton() instead!

    local ret
    ret, p_open = ImGui.TabItemEx(tab_bar, label, p_open, flags, nil)
    if ret and bit32.band(flags, ImGuiTabItemFlags.NoPushId) == 0 then
        local tab = tab_bar.Tabs.Data[tab_bar.LastTabItemIdx + 1]
        ImGui.PushOverrideID(tab.ID) -- We already hashed 'label' so push into the ID stack directly instead of doing another hash through PushID(label)
    end
    return ret, p_open
end

function ImGui.EndTabItem()
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow
    if window.SkipItems then return end

    local tab_bar = g.CurrentTabBar
    IM_ASSERT(tab_bar ~= nil, "Needs to be called between BeginTabBar() and EndTabBar()!")
    IM_ASSERT(tab_bar.LastTabItemIdx >= 0)
    local tab = tab_bar.Tabs.Data[tab_bar.LastTabItemIdx + 1]
    if bit32.band(tab.Flags, ImGuiTabItemFlags.NoPushId) == 0 then
        ImGui.PopID()
    end
end

function ImGui.TabItemButton(label, flags)
    if flags == nil then flags = 0 end
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow
    if window.SkipItems then return false end
    local tab_bar = g.CurrentTabBar
    IM_ASSERT(tab_bar ~= nil, "Needs to be called between BeginTabBar() and EndTabBar()!")
    return (ImGui.TabItemEx(tab_bar, label, nil, bit32.bor(flags, ImGuiTabItemFlags.Button, ImGuiTabItemFlags.NoReorder), nil))
end

function ImGui.TabItemSpacing(str_id, flags, width)
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow
    if window.SkipItems then return end
    local tab_bar = g.CurrentTabBar
    IM_ASSERT(tab_bar ~= nil, "Needs to be called between BeginTabBar() and EndTabBar()!")
    ImGui.SetNextItemWidth(width)
    ImGui.TabItemEx(tab_bar, str_id, nil, bit32.bor(flags or 0, ImGuiTabItemFlags.Button, ImGuiTabItemFlags.NoReorder, ImGuiTabItemFlags.Invisible), nil)
end

--- @return bool ret, bool? p_open
function ImGui.TabItemEx(tab_bar, label, p_open, flags, docked_window)
    -- Layout whole tab bar if not already done
    local g = ImGui.GetCurrentContext()
    if tab_bar.WantLayout then
        local backup_next_item_data = {}
        for k, v in pairs(g.NextItemData) do backup_next_item_data[k] = v end
        ImGui.TabBarLayout(tab_bar)
        for k, v in pairs(backup_next_item_data) do g.NextItemData[k] = v end
    end
    local window = g.CurrentWindow
    if window.SkipItems then return false, p_open end

    local style = g.Style
    local id = ImGui.TabBarCalcTabID(tab_bar, label, docked_window)

    -- If the user called us with p_open == false, we early out and don't render.
    -- We make a call to ItemAdd() so that attempts to use a contextual popup menu with an implicit ID won't use an older ID.
    if p_open ~= nil and not p_open then
        ImGui.ItemAdd(ImRect(), id, nil, ImGuiItemFlags.NoNav)
        return false, p_open
    end

    IM_ASSERT(p_open == nil or bit32.band(flags, ImGuiTabItemFlags.Button) == 0)
    IM_ASSERT(bit32.band(flags, bit32.bor(ImGuiTabItemFlags.Leading, ImGuiTabItemFlags.Trailing)) ~= bit32.bor(ImGuiTabItemFlags.Leading, ImGuiTabItemFlags.Trailing)) -- Can't use both Leading and Trailing

    -- Store into ImGuiTabItemFlags.NoCloseButton, also honor ImGuiTabItemFlags.NoCloseButton passed by user (although not documented)
    local has_p_open = (p_open ~= nil)
    if bit32.band(flags, ImGuiTabItemFlags.NoCloseButton) ~= 0 then
        has_p_open = false
    elseif not has_p_open then
        flags = bit32.bor(flags, ImGuiTabItemFlags.NoCloseButton)
    end

    -- Acquire tab data
    local tab = ImGui.TabBarFindTabByID(tab_bar, id)
    local tab_is_new = false
    if tab == nil then
        tab = ImGuiTabItem()
        tab_bar.Tabs:push_back(tab)
        tab.ID = id
        tab_bar.TabsAddedNew = true
        tab_is_new = true
    end
    tab_bar.LastTabItemIdx = ImGui.TabBarGetTabOrder(tab_bar, tab)

    -- Calculate tab contents size
    local size = ImGui.TabItemCalcSize(label, has_p_open or bit32.band(flags, ImGuiTabItemFlags.UnsavedDocument) ~= 0)
    tab.RequestedWidth = -1.0
    if bit32.band(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasWidth) ~= 0 then
        size.x = g.NextItemData.Width
        tab.RequestedWidth = size.x
    end
    if tab_is_new then tab.Width = ImMax(1.0, size.x) end
    tab.ContentWidth = size.x
    tab.BeginOrder = tab_bar.TabsActiveCount
    tab_bar.TabsActiveCount = tab_bar.TabsActiveCount + 1

    local tab_bar_appearing = (tab_bar.PrevFrameVisible + 1 < g.FrameCount)
    local tab_bar_focused = bit32.band(tab_bar.Flags, ImGuiTabBarFlags.IsFocused) ~= 0
    local tab_appearing = (tab.LastFrameVisible + 1 < g.FrameCount)
    local tab_just_unsaved = bit32.band(flags, ImGuiTabItemFlags.UnsavedDocument) ~= 0 and bit32.band(tab.Flags, ImGuiTabItemFlags.UnsavedDocument) == 0
    local is_tab_button = bit32.band(flags, ImGuiTabItemFlags.Button) ~= 0
    tab.LastFrameVisible = g.FrameCount
    tab.Flags = flags
    tab.Window = docked_window

    -- Append name (port: stored on tab.Name)
    -- (regular tabs are permitted in a DockNode tab bar, but window tabs not permitted in a non-DockNode tab bar)
    if docked_window ~= nil then
        IM_ASSERT(bit32.band(tab_bar.Flags, ImGuiTabBarFlags.DockNode) ~= 0)
        tab.NameOffset = -1
        tab.Name = nil
    else
        tab.NameOffset = 0
        tab.Name = label
    end

    -- Update selected tab
    if not is_tab_button then
        if tab_appearing and bit32.band(tab_bar.Flags, ImGuiTabBarFlags.AutoSelectNewTabs) ~= 0 and tab_bar.NextSelectedTabId == 0 then
            if not tab_bar_appearing or tab_bar.SelectedTabId == 0 then
                ImGui.TabBarQueueFocus(tab_bar, tab) -- New tabs gets activated
            end
        end
        if bit32.band(flags, ImGuiTabItemFlags.SetSelected) ~= 0 and tab_bar.SelectedTabId ~= id then -- _SetSelected can only be passed on explicit tab bar
            ImGui.TabBarQueueFocus(tab_bar, tab)
        end
    end

    -- Lock visibility
    -- (Note: tab_contents_visible ~= tab_selected... because Ctrl+Tab operations may preview some tabs without selecting them!)
    local tab_contents_visible = (tab_bar.VisibleTabId == id)
    if tab_contents_visible then tab_bar.VisibleTabWasSubmitted = true end

    -- On the very first frame of a tab bar we let first tab contents be visible to minimize appearing glitches
    if not tab_contents_visible and tab_bar.SelectedTabId == 0 and tab_bar_appearing and docked_window == nil then
        if tab_bar.Tabs.Size == 1 and bit32.band(tab_bar.Flags, ImGuiTabBarFlags.AutoSelectNewTabs) == 0 then
            tab_contents_visible = true
        end
    end

    -- Note that tab_is_new is not necessarily the same as tab_appearing! When a tab bar stops being submitted
    -- and then gets submitted again, the tabs will have 'tab_appearing=true' but 'tab_is_new=false'.
    if tab_appearing and (not tab_bar_appearing or tab_is_new) then
        ImGui.ItemAdd(ImRect(), id, nil, ImGuiItemFlags.NoNav)
        if is_tab_button then return false, p_open end
        return tab_contents_visible, p_open
    end

    if tab_bar.SelectedTabId == id then tab.LastFrameSelected = g.FrameCount end

    -- Backup current layout position
    local backup_main_cursor_pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y)

    -- Layout
    local is_central_section = bit32.band(tab.Flags, ImGuiTabItemFlags.SectionMask_) == 0
    size.x = tab.Width
    local pos = ImGui.TabBarGetTabPos(tab_bar, tab)
    ImVec2_Copy(window.DC.CursorPos, pos)
    local bb = ImRect(pos, pos + size)

    -- We don't have CPU clipping primitives to clip the CloseButton (until it becomes a texture), so need to add an extra draw call (temporary in the case of vertical animation)
    local want_clip_rect = is_central_section and (bb.Min.x < tab_bar.ScrollingRectMinX or bb.Max.x > tab_bar.ScrollingRectMaxX)
    if want_clip_rect then
        ImGui.PushClipRect(ImVec2(ImClamp(bb.Min.x, tab_bar.ScrollingRectMinX, tab_bar.ScrollingRectMaxX), bb.Min.y - 1), ImVec2(tab_bar.ScrollingRectMaxX, bb.Max.y), true)
    end

    local backup_cursor_max_pos = ImVec2(window.DC.CursorMaxPos.x, window.DC.CursorMaxPos.y)
    ImGui.ItemSize(bb:GetSize(), style.FramePadding.y)
    ImVec2_Copy(window.DC.CursorMaxPos, backup_cursor_max_pos)

    if not ImGui.ItemAdd(bb, id) then
        if want_clip_rect then ImGui.PopClipRect() end
        ImVec2_Copy(window.DC.CursorPos, backup_main_cursor_pos)
        return tab_contents_visible, p_open
    end

    -- Click to Select a tab
    local button_flags = bit32.bor(is_tab_button and ImGuiButtonFlags.PressedOnClickRelease or ImGuiButtonFlags.PressedOnClick, ImGuiButtonFlags.AllowOverlap)
    if g.DragDropActive and not ImGuiPayload_IsDataType(g.DragDropPayload, IMGUI_PAYLOAD_TYPE_WINDOW) then -- FIXME: May be an opt-in property of the payload to disable this
        button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnDragDropHold)
    end
    local hovered, held, pressed
    if bit32.band(flags, ImGuiTabItemFlags.Invisible) ~= 0 then
        hovered, held, pressed = false, false, false
    else
        pressed, hovered, held = ImGui.ButtonBehavior(bb, id, button_flags)
    end
    if pressed and not is_tab_button then ImGui.TabBarQueueFocus(tab_bar, tab) end

    -- Transfer active id window so the active id is not owned by the dock host (as StartMouseMovingWindow()
    -- will only do it on the drag). This allows FocusWindow() to be more conservative in how it clears active id.
    if held and docked_window and g.ActiveId == id and g.ActiveIdIsJustActivated then
        g.ActiveIdWindow = docked_window
    end

    -- Drag and drop a single floating window node moves it
    local node = docked_window and docked_window.DockNode or nil
    local single_floating_window_node = node and node:IsFloatingNode() and (node.Windows.Size == 1)
    if held and single_floating_window_node and ImGui.IsMouseDragging(0, 0.0) then
        -- Move
        ImGui.StartMouseMovingWindow(docked_window)
    elseif held and not tab_appearing and ImGui.IsMouseDragging(0) then
        -- Drag and drop: re-order tabs
        local drag_dir = 0
        local drag_distance_from_edge_x = 0.0
        if not g.DragDropActive and (bit32.band(tab_bar.Flags, ImGuiTabBarFlags.Reorderable) ~= 0 or docked_window ~= nil) then
            -- While moving a tab it will jump on the other side of the mouse, so we also test for MouseDelta.x
            if g.IO.MouseDelta.x < 0.0 and g.IO.MousePos.x < bb.Min.x then
                drag_dir = -1
                drag_distance_from_edge_x = bb.Min.x - g.IO.MousePos.x
                ImGui.TabBarQueueReorderFromMousePos(tab_bar, tab, g.IO.MousePos)
            elseif g.IO.MouseDelta.x > 0.0 and g.IO.MousePos.x > bb.Max.x then
                drag_dir = 1
                drag_distance_from_edge_x = g.IO.MousePos.x - bb.Max.x
                ImGui.TabBarQueueReorderFromMousePos(tab_bar, tab, g.IO.MousePos)
            end
        end

        -- Extract a Dockable window out of it's tab bar
        local can_undock = docked_window ~= nil and bit32.band(docked_window.Flags, ImGuiWindowFlags.NoMove) == 0 and bit32.band(node.MergedFlags, ImGuiDockNodeFlags.NoUndocking) == 0
        if can_undock then
            -- We use a variable threshold to distinguish dragging tabs within a tab bar and extracting them out of the tab bar
            local undocking_tab = (g.DragDropActive and g.DragDropPayload.SourceId == id)
            if not undocking_tab then -- and (not g.IO.ConfigDockingWithShift or g.IO.KeyShift)
                local threshold_base = g.FontSize
                local threshold_x = threshold_base * 2.2
                local threshold_y = (threshold_base * 1.5) + ImClamp((math.abs(g.IO.MouseDragMaxDistanceAbs[0].x) - threshold_base * 2.0) * 0.20, 0.0, threshold_base * 4.0)
                -- ImGui.GetForegroundDrawList():AddRect(ImVec2(bb.Min.x - threshold_x, bb.Min.y - threshold_y), ImVec2(bb.Max.x + threshold_x, bb.Max.y + threshold_y), IM_COL32_WHITE) -- [DEBUG]

                local distance_from_edge_y = ImMax(bb.Min.y - g.IO.MousePos.y, g.IO.MousePos.y - bb.Max.y)
                if distance_from_edge_y >= threshold_y then undocking_tab = true end
                if drag_distance_from_edge_x > threshold_x then
                    if (drag_dir < 0 and ImGui.TabBarGetTabOrder(tab_bar, tab) == 0) or (drag_dir > 0 and ImGui.TabBarGetTabOrder(tab_bar, tab) == tab_bar.Tabs.Size - 1) then
                        undocking_tab = true
                    end
                end
            end

            if undocking_tab then
                -- Undock
                -- FIXME: refactor to share more code with e.g. StartMouseMovingWindow
                ImGui.DockContextQueueUndockWindow(g, docked_window)
                g.MovingWindow = docked_window
                ImGui.SetActiveID(g.MovingWindow.MoveId, g.MovingWindow)
                ImVec2_Copy(g.ActiveIdClickOffset, g.ActiveIdClickOffset - (g.MovingWindow.Pos - bb.Min))
                g.ActiveIdNoClearOnFocusLoss = true
                ImGui.SetActiveIdUsingAllKeyboardKeys()
            end
        end
    end

    -- Render tab shape
    local is_visible = bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible) ~= 0 and bit32.band(flags, ImGuiTabItemFlags.Invisible) == 0
    if is_visible then
        local display_draw_list = window.DrawList
        local col_idx
        if held or hovered then col_idx = ImGuiCol.TabHovered
        elseif tab_contents_visible then col_idx = tab_bar_focused and ImGuiCol.TabSelected or ImGuiCol.TabDimmedSelected
        else col_idx = tab_bar_focused and ImGuiCol.Tab or ImGuiCol.TabDimmed end
        ImGui.TabItemBackground(display_draw_list, bb, flags, ImGui.GetColorU32(col_idx))
        if tab_contents_visible and bit32.band(tab_bar.Flags, ImGuiTabBarFlags.DrawSelectedOverline) ~= 0 and style.TabBarOverlineSize > 0.0 then
            -- Might be moved to TabItemBackground() ?
            local tl = ImVec2(bb.Min.x, bb.Min.y + style.TabBarOverlineSize * 0.5)
            local tr = ImVec2(bb.Max.x, bb.Min.y + style.TabBarOverlineSize * 0.5)
            local overline_col = ImGui.GetColorU32(tab_bar_focused and ImGuiCol.TabSelectedOverline or ImGuiCol.TabDimmedSelectedOverline)
            if style.TabRounding > 0.0 then
                local rounding = style.TabRounding
                display_draw_list:PathArcToFast(tl + ImVec2(rounding, rounding), rounding, 7, 9)
                display_draw_list:PathArcToFast(tr + ImVec2(-rounding, rounding), rounding, 9, 11)
                display_draw_list:PathStroke(overline_col, style.TabBarOverlineSize)
            else
                display_draw_list:AddLine(tl, tr, overline_col, style.TabBarOverlineSize)
            end
        end
        ImGui.RenderNavCursor(bb, id)

        -- Select with right mouse button. This is so the common idiom for context menu automatically highlight the current widget.
        local hovered_unblocked = ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup)
        if tab_bar.SelectedTabId ~= tab.ID and hovered_unblocked and (ImGui.IsMouseClicked(1) or ImGui.IsMouseReleased(1)) and not is_tab_button then
            ImGui.TabBarQueueFocus(tab_bar, tab)
        end

        if bit32.band(tab_bar.Flags, ImGuiTabBarFlags.NoCloseWithMiddleMouseButton) ~= 0 then
            flags = bit32.bor(flags, ImGuiTabItemFlags.NoCloseWithMiddleMouseButton)
        end

        -- Render tab label, process close button
        local close_button_id = has_p_open and ImGui.GetIDWithSeed("#CLOSE", nil, docked_window and docked_window.ID or id) or 0
        local label_flags = tab_just_unsaved and bit32.band(flags, bit32.bnot(ImGuiTabItemFlags.UnsavedDocument)) or flags
        local just_closed, text_clipped = ImGui.TabItemLabelAndCloseButton(display_draw_list, bb, label_flags, tab_bar.FramePadding, label, id, close_button_id, tab_contents_visible)
        if just_closed and has_p_open then
            p_open = false
            ImGui.TabBarCloseTab(tab_bar, tab)
        end

        -- Forward Hovered state so IsItemHovered() after Begin() can work (even though we are technically hovering our parent)
        -- That state is copied to window.DockTabItemStatusFlags by our caller.
        if docked_window and (hovered or g.HoveredId == close_button_id) then
            g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredWindow)
        end

        -- Tooltip
        -- (Won't work over the close button because ItemOverlap systems messes up with HoveredIdTimer-> seems ok)
        -- (We test IsItemHovered() to discard e.g. when another item is active or drag and drop over the tab bar, which g.HoveredId ignores)
        -- FIXME: This is a mess.
        -- FIXME: We may want disabled tab to still display the tooltip?
        if text_clipped and g.HoveredId == id and not held then
            if bit32.band(tab_bar.Flags, ImGuiTabBarFlags.NoTooltip) == 0 and bit32.band(tab.Flags, ImGuiTabItemFlags.NoTooltip) == 0 then
                local label_end = ImGui.FindRenderedTextEnd(label)
                ImGui.SetItemTooltip("%s", string.sub(label, 1, label_end - 1))
            end
        end
    end

    -- Restore main window position so user can draw there
    if want_clip_rect then ImGui.PopClipRect() end
    ImVec2_Copy(window.DC.CursorPos, backup_main_cursor_pos)

    if is_tab_button then return pressed, p_open end
    return tab_contents_visible, p_open
end

-- [Public] This is call is 100% optional but it allows to remove some one-frame glitches when a tab has been unexpectedly removed.
-- To use it to need to call the function SetTabItemClosed() between BeginTabBar() and EndTabBar().
-- Tabs closed by the close button will automatically be flagged to avoid this issue.
function ImGui.SetTabItemClosed(label)
    local g = ImGui.GetCurrentContext()
    local is_within_manual_tab_bar = g.CurrentTabBar and bit32.band(g.CurrentTabBar.Flags, ImGuiTabBarFlags.DockNode) == 0
    if is_within_manual_tab_bar then
        local tab_bar = g.CurrentTabBar
        local tab_id = ImGui.TabBarCalcTabID(tab_bar, label, nil)
        local tab = ImGui.TabBarFindTabByID(tab_bar, tab_id)
        if tab then tab.WantClose = true end -- Will be processed by next call to TabBarLayout()
    else
        local window = ImGui.FindWindowByName(label)
        if window and window.DockIsActive then
            local node = window.DockNode
            if node then
                local tab_id = ImGui.TabBarCalcTabID(node.TabBar, label, window)
                ImGui.TabBarRemoveTab(node.TabBar, tab_id)
                window.DockTabWantClose = true
            end
        end
    end
end

--- TabItemCalcSize(label, has_close_button_or_unsaved_marker) or TabItemCalcSize(window)
function ImGui.TabItemCalcSize(label, has_close_button_or_unsaved_marker)
    if type(label) == "table" then
        local window = label
        return ImGui.TabItemCalcSize(window.Name, window.HasCloseButton or bit32.band(window.Flags, ImGuiWindowFlags.UnsavedDocument) ~= 0)
    end
    local g = ImGui.GetCurrentContext()
    local label_size = ImGui.CalcTextSize(label, nil, true)
    local size = ImVec2(label_size.x + g.Style.FramePadding.x, label_size.y + g.Style.FramePadding.y * 2.0)
    if has_close_button_or_unsaved_marker then
        size.x = size.x + g.Style.FramePadding.x + (g.Style.ItemInnerSpacing.x + g.FontSize) -- We use Y intentionally to fit the close button circle.
    else
        size.x = size.x + g.Style.FramePadding.x + 1.0
    end
    return ImVec2(ImMin(size.x, ImGui.TabBarCalcMaxTabWidth()), size.y)
end

function ImGui.TabItemBackground(draw_list, bb, flags, col)
    -- While rendering tabs, we trim 1 pixel off the top of our bounding box so they can fit within a regular frame height while looking "detached" from it.
    local g = ImGui.GetCurrentContext()
    local width = bb:GetWidth()
    IM_ASSERT(width > 0.0)
    local rounding = ImMax(0.0, ImMin(bit32.band(flags, ImGuiTabItemFlags.Button) ~= 0 and g.Style.FrameRounding or g.Style.TabRounding, width * 0.5 - 1.0))
    local y1 = bb.Min.y + 1.0 -- Leave a bit of room in title bars.
    local y2 = bb.Max.y - g.Style.TabBarBorderSize
    draw_list:AddRectFilled(ImVec2(bb.Min.x, y1), ImVec2(bb.Max.x, y2), col, rounding, ImDrawFlags.RoundTop)
    if g.Style.TabBorderSize > 0.0 then
        draw_list:PathLineTo(ImVec2(bb.Min.x, y2))
        draw_list:PathArcToFast(ImVec2(bb.Min.x + rounding, y1 + rounding), rounding, 6, 9)
        draw_list:PathArcToFast(ImVec2(bb.Max.x - rounding, y1 + rounding), rounding, 9, 12)
        draw_list:PathLineTo(ImVec2(bb.Max.x, y2))
        draw_list:PathStroke(ImGui.GetColorU32(ImGuiCol.Border), g.Style.TabBorderSize, ImDrawFlags.StrokeCenterBiased) -- Use _StrokeInside?
    end
end

-- Render text label (with custom clipping) + Unsaved Document marker + Close Button logic
-- We tend to lock style.FramePadding for a given tab-bar, hence the 'frame_padding' parameter.
--- @return bool just_closed, bool text_clipped
function ImGui.TabItemLabelAndCloseButton(draw_list, bb, flags, frame_padding, label, tab_id, close_button_id, is_contents_visible)
    local g = ImGui.GetCurrentContext()
    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size = ImGui.CalcTextSize(label, label_end, false)

    if bb:GetWidth() <= 1.0 then return false, false end

    -- Render text label (with clipping + alpha gradient) + unsaved marker
    local text_ellipsis_clip_bb = ImRect(bb.Min.x + frame_padding.x, bb.Min.y + frame_padding.y, bb.Max.x - frame_padding.x, bb.Max.y)

    -- Return clipped state ignoring the close button
    local text_clipped = (text_ellipsis_clip_bb.Min.x + label_size.x) > text_ellipsis_clip_bb.Max.x
    -- draw_list:AddCircle(text_ellipsis_clip_bb.Min, 3.0, text_clipped and IM_COL32(255, 0, 0, 255) or IM_COL32(0, 255, 0, 255))

    local button_sz = g.FontSize
    local button_pos = ImVec2(ImMax(bb.Min.x, bb.Max.x - frame_padding.x - button_sz), bb.Min.y + frame_padding.y)

    -- Close Button & Unsaved Marker
    -- We are relying on a subtle and confusing distinction between 'hovered' and 'g.HoveredId' which happens because we are using ImGuiButtonFlags_AllowOverlapMode + SetItemAllowOverlap()
    --  'hovered' will be true when hovering the Tab but NOT when hovering the close button
    --  'g.HoveredId==id' will be true when hovering the Tab including when hovering the close button
    --  'g.ActiveId==close_button_id' will be true when we are holding on the close button, in which case both hovered booleans are false
    local close_button_pressed = false
    local close_button_visible = false
    local is_hovered = g.HoveredId == tab_id or g.HoveredId == close_button_id or g.ActiveId == tab_id or g.ActiveId == close_button_id -- Any interaction account for this too.

    if close_button_id ~= 0 then
        if is_contents_visible then
            close_button_visible = (g.Style.TabCloseButtonMinWidthSelected < 0.0) or (is_hovered and bb:GetWidth() >= ImMax(button_sz, g.Style.TabCloseButtonMinWidthSelected))
        else
            close_button_visible = (g.Style.TabCloseButtonMinWidthUnselected < 0.0) or (is_hovered and bb:GetWidth() >= ImMax(button_sz, g.Style.TabCloseButtonMinWidthUnselected))
        end
    end

    -- When tabs/document is unsaved, the unsaved marker takes priority over the close button.
    local unsaved_marker_visible = bit32.band(flags, ImGuiTabItemFlags.UnsavedDocument) ~= 0 and (button_pos.x + button_sz <= bb.Max.x) and (not close_button_visible or not is_hovered)
    if unsaved_marker_visible then
        local bullet_pos = button_pos + ImVec2(button_sz, button_sz) * 0.5
        ImGui.RenderBullet(draw_list, bullet_pos, ImGui.GetColorU32(ImGuiCol.UnsavedMarker))
    elseif close_button_visible then
        local last_item_backup = ImGuiLastItemData()
        ImGuiLastItemData_Copy(last_item_backup, g.LastItemData)
        if ImGui.CloseButton(close_button_id, button_pos) then close_button_pressed = true end
        ImGuiLastItemData_Copy(g.LastItemData, last_item_backup)

        -- Close with middle mouse button
        if is_hovered and bit32.band(flags, ImGuiTabItemFlags.NoCloseWithMiddleMouseButton) == 0 and ImGui.IsMouseClicked(2) then
            close_button_pressed = true
        end
    end

    -- This is all rather complicated
    -- (the main idea is that because the close button only appears on hover, we don't want it to alter the ellipsis position)
    -- FIXME: if FramePadding is noticeably large, ellipsis_max_x will be wrong here (e.g. #3497), maybe for consistency that parameter of RenderTextEllipsis() shouldn't exist..
    local ellipsis_max_x = text_ellipsis_clip_bb.Max.x
    if close_button_visible or unsaved_marker_visible then
        local visible_without_hover = unsaved_marker_visible or ((is_contents_visible and g.Style.TabCloseButtonMinWidthSelected or g.Style.TabCloseButtonMinWidthUnselected) < 0.0)
        if visible_without_hover then
            text_ellipsis_clip_bb.Max.x = text_ellipsis_clip_bb.Max.x - button_sz * 0.90
            ellipsis_max_x = ellipsis_max_x - button_sz * 0.90
        else
            text_ellipsis_clip_bb.Max.x = text_ellipsis_clip_bb.Max.x - button_sz * 1.00
        end
    end
    ImGui.LogSetNextTextDecoration("/", "\\")
    ImGui.RenderTextEllipsis(draw_list, text_ellipsis_clip_bb.Min, text_ellipsis_clip_bb.Max, ellipsis_max_x, label, label_end, label_size)

    return close_button_pressed, text_clipped
end
end --[[ [SECTION] Widgets: BeginTabBar, EndTabBar, etc. (was imgui_tabs.lua) ]]

return true -- [Roblox] ModuleScripts must return exactly one value
