-- Demo: DemoWindowWidgets*() sections (port of imgui_demo.cpp). Globals picked up by DemoWindowWidgets() in imgui_demo.lua.
local _
local function HSV(h, s, v, a) local r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v) return ImVec4(r, g, b, a or 1.0) end
local Buf, BufStr = DemoBuf, DemoBufStr
local S = {} -- statics, one subtable per section

local ExampleNames = {
    "Artichoke", "Arugula", "Asparagus", "Avocado", "Bamboo Shoots", "Bean Sprouts", "Beans", "Beet", "Belgian Endive", "Bell Pepper",
    "Bitter Gourd", "Bok Choy", "Broccoli", "Brussels Sprouts", "Burdock Root", "Cabbage", "Calabash", "Capers", "Carrot", "Cassava",
    "Cauliflower", "Celery", "Celery Root", "Celcuce", "Chayote", "Chinese Broccoli", "Corn", "Cucumber" }

S.basic = { clicked = 0, check = true, e = 0, counter = 0, str0 = Buf("Hello, world!", 128), str1 = Buf("", 128),
    i0 = 123, f0 = 0.001, d0 = 999999.00000001, f1 = 1.e10, vec4a = { 0.10, 0.20, 0.30, 0.44 },
    di1 = 50, di2 = 42, di3 = 128, df1 = 1.0, df2 = 0.0067, si1 = 0, sf1 = 0.123, sf2 = 0.0, angle = 0.0, elem = 0,
    col1 = { 1.0, 0.0, 0.2 }, col2 = { 0.4, 0.7, 0.0, 0.5 }, combo = 0, listbox = 1 }

function DemoWindowWidgetsBasic()
    if not ImGui.TreeNode("Basic") then return end
    local s = S.basic
    ImGui.SeparatorText("General")
    if ImGui.Button("Button") then s.clicked = s.clicked + 1 end
    if s.clicked % 2 == 1 then ImGui.SameLine(); ImGui.Text("Thanks for clicking me!") end
    _, s.check = ImGui.Checkbox("checkbox", s.check)
    _, s.e = ImGui.RadioButton("radio a", s.e, 0); ImGui.SameLine()
    _, s.e = ImGui.RadioButton("radio b", s.e, 1); ImGui.SameLine()
    _, s.e = ImGui.RadioButton("radio c", s.e, 2)
    ImGui.AlignTextToFramePadding()
    ImGui.TextLinkOpenURL("Hyperlink", "https://github.com/ocornut/imgui/wiki/Error-Handling")
    for i = 0, 6 do
        if i > 0 then ImGui.SameLine() end
        ImGui.PushID(i)
        ImGui.PushStyleColor(ImGuiCol.Button, HSV(i / 7.0, 0.6, 0.6))
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, HSV(i / 7.0, 0.7, 0.7))
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, HSV(i / 7.0, 0.8, 0.8))
        ImGui.Button("Click")
        ImGui.PopStyleColor(3)
        ImGui.PopID()
    end
    ImGui.AlignTextToFramePadding()
    ImGui.Text("Hold to repeat:")
    ImGui.SameLine()
    local spacing = ImGui.GetStyle().ItemInnerSpacing.x
    ImGui.PushItemFlag(ImGuiItemFlags.ButtonRepeat, true)
    if ImGui.ArrowButton("##left", ImGuiDir.Left) then s.counter = s.counter - 1 end
    ImGui.SameLine(0.0, spacing)
    if ImGui.ArrowButton("##right", ImGuiDir.Right) then s.counter = s.counter + 1 end
    ImGui.PopItemFlag()
    ImGui.SameLine()
    ImGui.Text("%d", s.counter)
    ImGui.Button("Tooltip")
    ImGui.SetItemTooltip("I am a tooltip")
    ImGui.LabelText("label", "Value")

    ImGui.SeparatorText("Inputs")
    ImGui.InputText("input text", s.str0, 128)
    ImGui.SameLine(); HelpMarker("USER:\nHold Shift or use mouse to select text.\nCtrl+Left/Right to word jump.\nCtrl+A or Double-Click to select all.\nCtrl+X,Ctrl+C,Ctrl+V for clipboard.\nCtrl+Z to undo, Ctrl+Y/Ctrl+Shift+Z to redo.\nEscape to revert.")
    ImGui.InputTextWithHint("input text (w/ hint)", "enter text here", s.str1, 128)
    s.i0 = ImGui.InputInt("input int", s.i0)
    s.f0 = ImGui.InputFloat("input float", s.f0, 0.01, 1.0, "%.3f")
    s.d0 = ImGui.InputDouble("input double", s.d0, 0.01, 1.0, "%.8f")
    s.f1 = ImGui.InputFloat("input scientific", s.f1, 0.0, 0.0, "%e")
    ImGui.SameLine(); HelpMarker("You can input value using the scientific notation,\n  e.g. \"1e+8\" becomes \"100000000\".")
    ImGui.InputFloat3("input float3", s.vec4a)

    ImGui.SeparatorText("Drags")
    s.di1 = ImGui.DragInt("drag int", s.di1, 1)
    ImGui.SameLine(); HelpMarker("Click and drag to edit value.\nHold Shift/Alt for faster/slower edit.\nDouble-Click or Ctrl+Click to input value.")
    s.di2 = ImGui.DragInt("drag int 0..100", s.di2, 1, 0, 100, "%d%%", ImGuiSliderFlags.AlwaysClamp)
    s.di3 = ImGui.DragInt("drag int wrap 100..200", s.di3, 1, 100, 200, "%d", ImGuiSliderFlags.WrapAround)
    s.df1 = ImGui.DragFloat("drag float", s.df1, 0.005)
    s.df2 = ImGui.DragFloat("drag small float", s.df2, 0.0001, 0.0, 0.0, "%.06f ns")

    ImGui.SeparatorText("Sliders")
    s.si1 = ImGui.SliderInt("slider int", s.si1, -1, 3)
    ImGui.SameLine(); HelpMarker("Ctrl+Click to input value.")
    s.sf1 = ImGui.SliderFloat("slider float", s.sf1, 0.0, 1.0, "ratio = %.3f")
    s.sf2 = ImGui.SliderFloat("slider float (log)", s.sf2, -10.0, 10.0, "%.4f", ImGuiSliderFlags.Logarithmic)
    s.angle = ImGui.SliderAngle("slider angle", s.angle)
    local elems_names = { "Fire", "Earth", "Air", "Water" }
    local elem_name = elems_names[s.elem + 1] or "Unknown"
    s.elem = ImGui.SliderInt("slider enum", s.elem, 0, 3, elem_name)
    ImGui.SameLine(); HelpMarker("Using the format string parameter to display a name instead of the underlying integer.")

    ImGui.SeparatorText("Selectors/Pickers")
    ImGui.ColorEdit3("color 1", s.col1)
    ImGui.SameLine(); HelpMarker("Click on the color square to open a color picker.\nClick and hold to use drag and drop.\nRight-Click on the color square to show options.\nCtrl+Click on individual component to input value.\n")
    ImGui.ColorEdit4("color 2", s.col2)
    s.combo = ImGui.Combo("combo", s.combo, { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIIIIII", "JJJJ", "KKKKKKK" })
    ImGui.SameLine(); HelpMarker("Using the simplified one-liner Combo API here.")
    s.listbox = ImGui.ListBox("listbox", s.listbox, { "Apple", "Banana", "Cherry", "Kiwi", "Mango", "Orange", "Pineapple", "Strawberry", "Watermelon" }, 9, 4)
    ImGui.SameLine(); HelpMarker("Using the simplified one-liner ListBox API here.")
    ImGui.TreePop()
end

S.chdr = { closable_group = true }
function DemoWindowWidgetsBullets()
    if not ImGui.TreeNode("Bullets") then return end
    ImGui.BulletText("Bullet point 1")
    ImGui.BulletText("Bullet point 2\nOn multiple lines")
    if ImGui.TreeNode("Tree node") then ImGui.BulletText("Another bullet point"); ImGui.TreePop() end
    ImGui.Bullet(); ImGui.Text("Bullet point 3 (two calls)")
    ImGui.Bullet(); ImGui.SmallButton("Button")
    ImGui.TreePop()
end

function DemoWindowWidgetsCollapsingHeaders()
    if not ImGui.TreeNode("Collapsing Headers") then return end
    local s = S.chdr
    _, s.closable_group = ImGui.Checkbox("Show 2nd header", s.closable_group)
    if ImGui.CollapsingHeader("Header", ImGuiTreeNodeFlags.None) then
        ImGui.Text("IsItemHovered: %d", ImGui.IsItemHovered() and 1 or 0)
        for i = 0, 4 do ImGui.Text("Some content %d", i) end
    end
    local open
    open, s.closable_group = ImGui.CollapsingHeader("Header with a close button", s.closable_group)
    if open then
        ImGui.Text("IsItemHovered: %d", ImGui.IsItemHovered() and 1 or 0)
        for i = 0, 4 do ImGui.Text("More content %d", i) end
    end
    ImGui.TreePop()
end

IMGUI_PAYLOAD_TYPE_COLOR_3F = IMGUI_PAYLOAD_TYPE_COLOR_3F or "_COL3F"
IMGUI_PAYLOAD_TYPE_COLOR_4F = IMGUI_PAYLOAD_TYPE_COLOR_4F or "_COL4F"

S.color = { color = ImVec4(114.0 / 255.0, 144.0 / 255.0, 154.0 / 255.0, 200.0 / 255.0), base_flags = 0, palette = nil,
    backup = ImVec4(), no_border = false, ref_color = false, ref_color_v = ImVec4(1.0, 0.0, 1.0, 0.5), picker_mode = 0,
    display_mode = 0, picker_flags = ImGuiColorEditFlags.AlphaBar, hsv = ImVec4(0.23, 1.0, 1.0, 1.0) }

function DemoWindowWidgetsColorAndPickers()
    if not ImGui.TreeNode("Color/Picker Widgets") then return end
    local s = S.color
    local CE = ImGuiColorEditFlags
    local color = s.color

    ImGui.SeparatorText("Options")
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoAlpha", s.base_flags, CE.NoAlpha)
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaOpaque", s.base_flags, CE.AlphaOpaque)
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaNoBg", s.base_flags, CE.AlphaNoBg)
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaPreviewHalf", s.base_flags, CE.AlphaPreviewHalf)
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoOptions", s.base_flags, CE.NoOptions); ImGui.SameLine(); HelpMarker("Right-click on the individual color widget to show options.")
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoDragDrop", s.base_flags, CE.NoDragDrop)
    if CE.NoColorMarkers then _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoColorMarkers", s.base_flags, CE.NoColorMarkers) end
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_HDR", s.base_flags, CE.HDR); ImGui.SameLine(); HelpMarker("Currently all this does is to lift the 0..1 limits on dragging widgets.")
    local base_flags = s.base_flags

    ImGui.SeparatorText("Inline color editor")
    ImGui.Text("Color widget:")
    ImGui.SameLine(); HelpMarker("Click on the color square to open a color picker.\nCtrl+Click on individual component to input value.\n")
    ImGui.ColorEdit3("MyColor##1", color, base_flags)
    ImGui.Text("Color widget HSV with Alpha:")
    ImGui.ColorEdit4("MyColor##2", color, bit32.bor(CE.DisplayHSV, base_flags))
    ImGui.Text("Color widget with Float Display:")
    ImGui.ColorEdit4("MyColor##2f", color, bit32.bor(CE.Float, base_flags))
    ImGui.Text("Color button with Picker:")
    ImGui.SameLine(); HelpMarker("With the ImGuiColorEditFlags_NoInputs flag you can hide all the slider/text inputs.\nWith the ImGuiColorEditFlags_NoLabel flag you can pass a non-empty label which will only be used for the tooltip and picker popup.")
    ImGui.ColorEdit4("MyColor##3", color, bit32.bor(CE.NoInputs, CE.NoLabel, base_flags))

    ImGui.Text("Color button with Custom Picker Popup:")
    if s.palette == nil then
        s.palette = {}
        for n = 0, 31 do s.palette[n] = HSV(n / 31.0, 0.8, 0.8, 1.0) end
    end
    local open_popup = ImGui.ColorButton("MyColor##3b", color, base_flags)
    ImGui.SameLine(0, ImGui.GetStyle().ItemInnerSpacing.x)
    open_popup = ImGui.Button("Palette") or open_popup
    if open_popup then
        ImGui.OpenPopup("mypicker")
        ImVec4_Copy(s.backup, color)
    end
    if ImGui.BeginPopup("mypicker") then
        ImGui.Text("MY CUSTOM COLOR PICKER WITH AN AMAZING PALETTE!")
        ImGui.Separator()
        ImGui.ColorPicker4("##picker", color, bit32.bor(base_flags, CE.NoSidePreview, CE.NoSmallPreview))
        ImGui.SameLine()
        ImGui.BeginGroup()
        ImGui.Text("Current")
        ImGui.ColorButton("##current", color, bit32.bor(CE.NoPicker, CE.AlphaPreviewHalf), ImVec2(60, 40))
        ImGui.Text("Previous")
        if ImGui.ColorButton("##previous", s.backup, bit32.bor(CE.NoPicker, CE.AlphaPreviewHalf), ImVec2(60, 40)) then
            ImVec4_Copy(color, s.backup)
        end
        ImGui.Separator()
        ImGui.Text("Palette")
        for n = 0, 31 do
            ImGui.PushID(n)
            if n % 8 ~= 0 then ImGui.SameLine(0.0, ImGui.GetStyle().ItemSpacing.y) end
            local pal = s.palette[n]
            if ImGui.ColorButton("##palette", pal, bit32.bor(CE.NoAlpha, CE.NoPicker, CE.NoTooltip), ImVec2(20, 20)) then
                color.x = pal.x; color.y = pal.y; color.z = pal.z -- Preserve alpha!
            end
            if ImGui.BeginDragDropTarget() then
                local payload = ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_3F)
                if payload and payload.Data then pal.x, pal.y, pal.z = payload.Data[1], payload.Data[2], payload.Data[3] end
                payload = ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_4F)
                if payload and payload.Data then pal.x, pal.y, pal.z, pal.w = payload.Data[1], payload.Data[2], payload.Data[3], payload.Data[4] end
                ImGui.EndDragDropTarget()
            end
            ImGui.PopID()
        end
        ImGui.EndGroup()
        ImGui.EndPopup()
    end

    ImGui.Text("Color button only:")
    _, s.no_border = ImGui.Checkbox("ImGuiColorEditFlags_NoBorder", s.no_border)
    ImGui.ColorButton("MyColor##3c", color, bit32.bor(base_flags, s.no_border and CE.NoBorder or 0), ImVec2(80, 80))

    ImGui.SeparatorText("Color picker")
    ImGui.PushID("Color picker")
    _, s.picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoAlpha", s.picker_flags, CE.NoAlpha)
    _, s.picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaBar", s.picker_flags, CE.AlphaBar)
    _, s.picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoSidePreview", s.picker_flags, CE.NoSidePreview)
    if bit32.band(s.picker_flags, CE.NoSidePreview) ~= 0 then
        ImGui.SameLine()
        _, s.ref_color = ImGui.Checkbox("With Ref Color", s.ref_color)
        if s.ref_color then
            ImGui.SameLine()
            ImGui.ColorEdit4("##RefColor", s.ref_color_v, bit32.bor(CE.NoInputs, base_flags))
        end
    end
    _, s.picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_PickerNoRotate", s.picker_flags, CE.PickerNoRotate)
    s.picker_mode = ImGui.Combo("Picker Mode", s.picker_mode, "Auto/Current\0ImGuiColorEditFlags_PickerHueBar\0ImGuiColorEditFlags_PickerHueWheel\0")
    ImGui.SameLine(); HelpMarker("When not specified explicitly, user can right-click the picker to change mode.")
    s.display_mode = ImGui.Combo("Display Mode", s.display_mode, "Auto/Current\0ImGuiColorEditFlags_NoInputs\0ImGuiColorEditFlags_DisplayRGB\0ImGuiColorEditFlags_DisplayHSV\0ImGuiColorEditFlags_DisplayHex\0")
    ImGui.SameLine(); HelpMarker("ColorEdit defaults to displaying RGB inputs if you don't specify a display mode, but the user can change it with a right-click on those inputs.\n\nColorPicker defaults to displaying RGB+HSV+Hex if you don't specify a display mode.\n\nYou can change the defaults using io.ConfigColorEditFlags.")
    local flags = bit32.bor(base_flags, s.picker_flags)
    if s.picker_mode == 1 then flags = bit32.bor(flags, CE.PickerHueBar) end
    if s.picker_mode == 2 then flags = bit32.bor(flags, CE.PickerHueWheel) end
    if s.display_mode == 1 then flags = bit32.bor(flags, CE.NoInputs) end
    if s.display_mode == 2 then flags = bit32.bor(flags, CE.DisplayRGB) end
    if s.display_mode == 3 then flags = bit32.bor(flags, CE.DisplayHSV) end
    if s.display_mode == 4 then flags = bit32.bor(flags, CE.DisplayHex) end
    ImGui.ColorPicker4("MyColor##4", color, flags, s.ref_color and s.ref_color_v or nil)

    ImGui.Text("Set defaults in code:")
    ImGui.SameLine(); HelpMarker("io.ConfigColorEditFlags is designed to allow you to set boot-time default.")
    if ImGui.Button("Overwrite default: Uint8 + HSV + Hue Bar") then
        ImGui.GetIO().ConfigColorEditFlags = bit32.bor(CE.Uint8, CE.DisplayHSV, CE.PickerHueBar, CE.InputRGB) -- [port] + InputRGB: upstream omits it and then trips its own InputMask_ assert
    end
    if ImGui.Button("Overwrite default: Float + HDR + Hue Wheel") then
        ImGui.GetIO().ConfigColorEditFlags = bit32.bor(CE.Float, CE.HDR, CE.PickerHueWheel, CE.DisplayRGB, CE.InputRGB)
    end

    ImGui.Text("Both types:")
    local w = (ImGui.GetContentRegionAvail().x - ImGui.GetStyle().ItemSpacing.y) * 0.40
    ImGui.SetNextItemWidth(w)
    ImGui.ColorPicker3("##MyColor##5", color, bit32.bor(CE.PickerHueBar, CE.NoSidePreview, CE.NoInputs, CE.NoAlpha))
    ImGui.SameLine()
    ImGui.SetNextItemWidth(w)
    ImGui.ColorPicker3("##MyColor##6", color, bit32.bor(CE.PickerHueWheel, CE.NoSidePreview, CE.NoInputs, CE.NoAlpha))
    ImGui.PopID()

    ImGui.Spacing()
    ImGui.Text("HSV encoded colors")
    ImGui.SameLine(); HelpMarker("By default, colors are given to ColorEdit and ColorPicker in RGB, but ImGuiColorEditFlags_InputHSV allows you to store colors as HSV and pass them to ColorEdit and ColorPicker as HSV.")
    ImGui.Text("Color widget with InputHSV:")
    ImGui.ColorEdit4("HSV shown as RGB##1", s.hsv, bit32.bor(CE.DisplayRGB, CE.InputHSV, CE.Float))
    ImGui.ColorEdit4("HSV shown as HSV##1", s.hsv, bit32.bor(CE.DisplayHSV, CE.InputHSV, CE.Float))
    ImGui.DragFloat4("Raw HSV values", s.hsv, 0.01, 0.0, 1.0)
    ImGui.TreePop()
end

S.combo = { flags = 0, sel = 0, filter = nil, c2 = 0, c3 = -1, c4 = 0 }
function DemoWindowWidgetsComboBoxes()
    if not ImGui.TreeNode("Combo") then return end
    local s = S.combo
    local CF = ImGuiComboFlags
    local p
    _, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_PopupAlignLeft", s.flags, CF.PopupAlignLeft)
    ImGui.SameLine(); HelpMarker("Only makes a difference if the popup is larger than the combo")
    p, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_NoArrowButton", s.flags, CF.NoArrowButton)
    if p then s.flags = bit32.band(s.flags, bit32.bnot(CF.NoPreview)) end
    p, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_NoPreview", s.flags, CF.NoPreview)
    if p then s.flags = bit32.band(s.flags, bit32.bnot(bit32.bor(CF.NoArrowButton, CF.WidthFitPreview))) end
    p, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_WidthFitPreview", s.flags, CF.WidthFitPreview)
    if p then s.flags = bit32.band(s.flags, bit32.bnot(CF.NoPreview)) end
    for _, h in ipairs({ "HeightSmall", "HeightRegular", "HeightLargest" }) do
        p, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_" .. h, s.flags, CF[h])
        if p then s.flags = bit32.band(s.flags, bit32.bnot(bit32.band(CF.HeightMask_, bit32.bnot(CF[h])))) end
    end

    local items = { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIII", "JJJJ", "KKKK", "LLLLLLL", "MMMM", "OOOOOOO" }
    local combo_preview_value = items[s.sel + 1]
    if ImGui.BeginCombo("combo 1", combo_preview_value, s.flags) then
        for n = 0, #items - 1 do
            local is_selected = (s.sel == n)
            if ImGui.Selectable(items[n + 1], is_selected) then s.sel = n end
            if is_selected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndCombo()
    end

    if ImGui.BeginCombo("combo 2 (w/ filter)", combo_preview_value, s.flags) then
        s.filter = s.filter or ImGuiTextFilter()
        if ImGui.IsWindowAppearing() then
            ImGui.SetKeyboardFocusHere()
            s.filter:Clear()
        end
        ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.F))
        ImGui.SetNextItemWidth(-FLT_MIN)
        s.filter:DrawWithHint("##Filter", "Filter (incl -excl)")
        for n = 0, #items - 1 do
            local is_selected = (s.sel == n)
            if s.filter:PassFilter(items[n + 1]) then
                if ImGui.Selectable(items[n + 1], is_selected) then s.sel = n end
            end
        end
        ImGui.EndCombo()
    end

    ImGui.Spacing()
    ImGui.SeparatorText("One-liner variants")
    HelpMarker("The Combo() function is not greatly useful apart from cases were you want to embed all options in a single strings.\nFlags above don't apply to this section.")
    s.c2 = ImGui.Combo("combo 3 (one-liner)", s.c2, "aaaa\0bbbb\0cccc\0dddd\0eeee\0\0")
    s.c3 = ImGui.Combo("combo 4 (array)", s.c3, items, #items)
    s.c4 = ImGui.Combo("combo 5 (function)", s.c4, function(data, n) return data[n + 1] end, items, #items)
    ImGui.TreePop()
end

S.dt = { s8 = 127, u8 = 255, s16 = 32767, u16 = 65535, s32 = -1, u32 = 0xFFFFFFFF, s64 = -1, u64 = 0, f32 = 0.123, f64 = 90000.01234567890123456789,
    drag_clamp = false, inputs_step = true, flags = 0 }
function DemoWindowWidgetsDataTypes()
    if not ImGui.TreeNode("Data Types") then return end
    local s = S.dt
    local DT = ImGuiDataType
    -- ponytail: Luau numbers are doubles, so S64/U64 are shown with S32/Double here (no 64-bit integer type)
    local s32_min, s32_max = math.floor(-2147483648 / 2), math.floor(2147483647 / 2)
    local u32_max = math.floor(4294967295 / 2)
    local drag_speed = 0.2
    ImGui.SeparatorText("Drags")
    _, s.drag_clamp = ImGui.Checkbox("Clamp integers to 0..50", s.drag_clamp)
    ImGui.SameLine(); HelpMarker("As with every widget in dear imgui, we never modify values unless there is a user interaction.\nYou can override the clamping limits by using Ctrl+Click to input a value.")
    local lo, hi = s.drag_clamp and 0 or nil, s.drag_clamp and 50 or nil
    s.s8  = ImGui.DragScalar("drag s8",      DT.S8,  s.s8,  drag_speed, lo, hi)
    s.u8  = ImGui.DragScalar("drag u8",      DT.U8,  s.u8,  drag_speed, lo, hi, "%u ms")
    s.s16 = ImGui.DragScalar("drag s16",     DT.S16, s.s16, drag_speed, lo, hi)
    s.u16 = ImGui.DragScalar("drag u16",     DT.U16, s.u16, drag_speed, lo, hi, "%u ms")
    s.s32 = ImGui.DragScalar("drag s32",     DT.S32, s.s32, drag_speed, lo, hi)
    s.s32 = ImGui.DragScalar("drag s32 hex", DT.S32, s.s32, drag_speed, lo, hi, "0x%08X")
    s.u32 = ImGui.DragScalar("drag u32",     DT.U32, s.u32, drag_speed, lo, hi, "%u ms")
    s.f32 = ImGui.DragScalar("drag float",     DT.Float,  s.f32, 0.005, 0.0, 1.0, "%f")
    s.f32 = ImGui.DragScalar("drag float log", DT.Float,  s.f32, 0.005, 0.0, 1.0, "%f", ImGuiSliderFlags.Logarithmic)
    s.f64 = ImGui.DragScalar("drag double",    DT.Double, s.f64, 0.0005, 0.0, nil, "%.10f grams")
    s.f64 = ImGui.DragScalar("drag double log",DT.Double, s.f64, 0.0005, 0.0, 1.0, "0 < %.10f < 1", ImGuiSliderFlags.Logarithmic)

    ImGui.SeparatorText("Sliders")
    s.s8  = ImGui.SliderScalar("slider s8 full",  DT.S8,  s.s8,  -128, 127, "%d")
    s.u8  = ImGui.SliderScalar("slider u8 full",  DT.U8,  s.u8,  0, 255, "%u")
    s.s16 = ImGui.SliderScalar("slider s16 full", DT.S16, s.s16, -32768, 32767, "%d")
    s.u16 = ImGui.SliderScalar("slider u16 full", DT.U16, s.u16, 0, 65535, "%u")
    s.s32 = ImGui.SliderScalar("slider s32 low",  DT.S32, s.s32, 0, 50, "%d")
    s.s32 = ImGui.SliderScalar("slider s32 high", DT.S32, s.s32, s32_max - 100, s32_max, "%d")
    s.s32 = ImGui.SliderScalar("slider s32 full", DT.S32, s.s32, s32_min, s32_max, "%d")
    s.s32 = ImGui.SliderScalar("slider s32 hex",  DT.S32, s.s32, 0, 50, "0x%04X")
    s.u32 = ImGui.SliderScalar("slider u32 low",  DT.U32, s.u32, 0, 50, "%u")
    s.u32 = ImGui.SliderScalar("slider u32 high", DT.U32, s.u32, u32_max - 100, u32_max, "%u")
    s.u32 = ImGui.SliderScalar("slider u32 full", DT.U32, s.u32, 0, u32_max, "%u")
    s.f32 = ImGui.SliderScalar("slider float low",      DT.Float, s.f32, 0.0, 1.0)
    s.f32 = ImGui.SliderScalar("slider float low log",  DT.Float, s.f32, 0.0, 1.0, "%.10f", ImGuiSliderFlags.Logarithmic)
    s.f32 = ImGui.SliderScalar("slider float high",     DT.Float, s.f32, -10000000000.0, 10000000000.0, "%e")
    s.f64 = ImGui.SliderScalar("slider double low",     DT.Double, s.f64, 0.0, 1.0, "%.10f grams")
    s.f64 = ImGui.SliderScalar("slider double low log", DT.Double, s.f64, 0.0, 1.0, "%.10f", ImGuiSliderFlags.Logarithmic)
    s.f64 = ImGui.SliderScalar("slider double high",    DT.Double, s.f64, -1000000000000000.0, 1000000000000000.0, "%e grams")

    ImGui.SeparatorText("Sliders (reverse)")
    s.s8  = ImGui.SliderScalar("slider s8 reverse",  DT.S8,  s.s8,  127, -128, "%d")
    s.u8  = ImGui.SliderScalar("slider u8 reverse",  DT.U8,  s.u8,  255, 0, "%u")
    s.s32 = ImGui.SliderScalar("slider s32 reverse", DT.S32, s.s32, 50, 0, "%d")
    s.u32 = ImGui.SliderScalar("slider u32 reverse", DT.U32, s.u32, 50, 0, "%u")

    ImGui.SeparatorText("Inputs")
    _, s.inputs_step = ImGui.Checkbox("Show step buttons", s.inputs_step)
    _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ReadOnly", s.flags, ImGuiInputTextFlags.ReadOnly)
    if ImGuiInputTextFlags.ParseEmptyRefVal then _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ParseEmptyRefVal", s.flags, ImGuiInputTextFlags.ParseEmptyRefVal) end
    if ImGuiInputTextFlags.DisplayEmptyRefVal then _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_DisplayEmptyRefVal", s.flags, ImGuiInputTextFlags.DisplayEmptyRefVal) end
    local one = s.inputs_step and 1 or nil
    s.s8  = ImGui.InputScalar("input s8",      DT.S8,  s.s8,  one, nil, "%d", s.flags)
    s.u8  = ImGui.InputScalar("input u8",      DT.U8,  s.u8,  one, nil, "%u", s.flags)
    s.s16 = ImGui.InputScalar("input s16",     DT.S16, s.s16, one, nil, "%d", s.flags)
    s.u16 = ImGui.InputScalar("input u16",     DT.U16, s.u16, one, nil, "%u", s.flags)
    s.s32 = ImGui.InputScalar("input s32",     DT.S32, s.s32, one, nil, "%d", s.flags)
    s.s32 = ImGui.InputScalar("input s32 hex", DT.S32, s.s32, one, nil, "%04X", s.flags)
    s.u32 = ImGui.InputScalar("input u32",     DT.U32, s.u32, one, nil, "%u", s.flags)
    s.u32 = ImGui.InputScalar("input u32 hex", DT.U32, s.u32, one, nil, "%08X", s.flags)
    s.f32 = ImGui.InputScalar("input float",   DT.Float,  s.f32, s.inputs_step and 1.0 or nil, nil, nil, s.flags)
    s.f64 = ImGui.InputScalar("input double",  DT.Double, s.f64, s.inputs_step and 1.0 or nil, nil, nil, s.flags)
    ImGui.TreePop()
end

function DemoWindowWidgetsDisableBlocks(demo_data)
    if not ImGui.TreeNode("Disable Blocks") then return end
    _, demo_data.DisableSections = ImGui.Checkbox("Disable entire section above", demo_data.DisableSections)
    ImGui.SameLine(); HelpMarker("Demonstrate using BeginDisabled()/EndDisabled() across other sections.")
    ImGui.TreePop()
end

S.dnd = { col1 = { 1.0, 0.0, 0.2 }, col2 = { 0.4, 0.7, 0.0, 0.5 }, mode = 0,
    names = { "Bobby", "Beatrice", "Betty", "Brianna", "Barry", "Bernard", "Bibi", "Blaine", "Bryn" },
    item_names = { "Item One", "Item Two", "Item Three", "Item Four", "Item Five" }, col4 = ImVec4(1.0, 0.0, 0.2, 1.0) }
function DemoWindowWidgetsDragAndDrop()
    if not ImGui.TreeNode("Drag and Drop") then return end
    local s = S.dnd
    if ImGui.TreeNode("Drag and drop in standard widgets") then
        HelpMarker("You can drag from the color squares.")
        ImGui.ColorEdit3("color 1", s.col1)
        ImGui.ColorEdit4("color 2", s.col2)
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Drag and drop to copy/swap items") then
        local Mode_Copy, Mode_Move, Mode_Swap = 0, 1, 2
        if ImGui.RadioButtonEx("Copy", s.mode == Mode_Copy) then s.mode = Mode_Copy end ImGui.SameLine()
        if ImGui.RadioButtonEx("Move", s.mode == Mode_Move) then s.mode = Mode_Move end ImGui.SameLine()
        if ImGui.RadioButtonEx("Swap", s.mode == Mode_Swap) then s.mode = Mode_Swap end
        local names = s.names
        for n = 0, #names - 1 do
            ImGui.PushID(n)
            if n % 3 ~= 0 then ImGui.SameLine() end
            ImGui.Button(names[n + 1], ImVec2(60, 60))
            if ImGui.BeginDragDropSource(ImGuiDragDropFlags.None) then
                ImGui.SetDragDropPayload("DND_DEMO_CELL", n, 4)
                if s.mode == Mode_Copy then ImGui.Text("Copy %s", names[n + 1]) end
                if s.mode == Mode_Move then ImGui.Text("Move %s", names[n + 1]) end
                if s.mode == Mode_Swap then ImGui.Text("Swap %s", names[n + 1]) end
                ImGui.EndDragDropSource()
            end
            if ImGui.BeginDragDropTarget() then
                local payload = ImGui.AcceptDragDropPayload("DND_DEMO_CELL")
                if payload then
                    local payload_n = payload.Data
                    if s.mode == Mode_Copy then names[n + 1] = names[payload_n + 1] end
                    if s.mode == Mode_Move then names[n + 1] = names[payload_n + 1]; names[payload_n + 1] = "" end
                    if s.mode == Mode_Swap then names[n + 1], names[payload_n + 1] = names[payload_n + 1], names[n + 1] end
                end
                ImGui.EndDragDropTarget()
            end
            ImGui.PopID()
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Drag to reorder items (simple)") then
        ImGui.PushItemFlag(ImGuiItemFlags.AllowDuplicateId, true)
        HelpMarker("We don't use the drag and drop api at all here! Instead we query when the item is held but not hovered, and order items accordingly.")
        local item_names = s.item_names
        for n = 1, #item_names do
            local item = item_names[n]
            ImGui.Selectable(item)
            if ImGui.IsItemActive() and not ImGui.IsItemHovered() then
                local n_next = n + ((ImGui.GetMouseDragDelta(0).y < 0.0) and -1 or 1)
                if n_next >= 1 and n_next <= #item_names then
                    item_names[n] = item_names[n_next]
                    item_names[n_next] = item
                    ImGui.ResetMouseDragDelta()
                end
            end
        end
        ImGui.PopItemFlag()
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Tooltip at target location") then
        for n = 0, 1 do
            ImGui.Button((n == 1) and "drop here##1" or "drop here##0")
            if ImGui.BeginDragDropTarget() then
                local drop_target_flags = bit32.bor(ImGuiDragDropFlags.AcceptBeforeDelivery, ImGuiDragDropFlags.AcceptNoPreviewTooltip)
                if ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_4F, drop_target_flags) then
                    ImGui.SetMouseCursor(ImGuiMouseCursor.NotAllowed)
                    ImGui.SetTooltip("Cannot drop here!")
                end
                ImGui.EndDragDropTarget()
            end
            if n == 0 then ImGui.ColorButton("drag me", s.col4) end
        end
        ImGui.TreePop()
    end
    ImGui.TreePop()
end

S.ds = { flags = 0, drag_f = 0.5, drag_f4 = { 0, 0, 0, 0 }, drag_i = 50, slider_f = 0.5, slider_f4 = { 0, 0, 0, 0 }, slider_i = 50 }
function DemoWindowWidgetsDragsAndSliders()
    if not ImGui.TreeNode("Drag/Slider Flags") then return end
    local s = S.ds
    local SF = ImGuiSliderFlags
    local function F(name, help)
        if SF[name] == nil then return end
        _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_" .. name, s.flags, SF[name])
        if help then ImGui.SameLine(); HelpMarker(help) end
    end
    F("AlwaysClamp")
    F("ClampOnInput", "Clamp value to min/max bounds when input manually with Ctrl+Click. By default Ctrl+Click allows going out of bounds.")
    F("ClampZeroRange", "Clamp even if min==max==0.0f. Otherwise DragXXX functions don't clamp.")
    F("Logarithmic", "Enable logarithmic editing (more precision for small values).")
    F("NoRoundToFormat", "Disable rounding underlying value to match precision of the format string (e.g. %.3f values are rounded to those 3 digits).")
    F("NoInput", "Disable Ctrl+Click or Enter key allowing to input text directly into the widget.")
    F("NoSpeedTweaks", "Disable keyboard modifiers altering tweak speed. Useful if you want to alter tweak speed yourself based on your own logic.")
    F("WrapAround", "Enable wrapping around from max to min and from min to max (only supported by DragXXX() functions)")
    F("ColorMarkers")
    local flags = s.flags

    ImGui.Text("Underlying float value: %f", s.drag_f)
    s.drag_f = ImGui.DragFloat("DragFloat (0 -> 1)", s.drag_f, 0.005, 0.0, 1.0, "%.3f", flags)
    s.drag_f = ImGui.DragFloat("DragFloat (0 -> +inf)", s.drag_f, 0.005, 0.0, FLT_MAX, "%.3f", flags)
    s.drag_f = ImGui.DragFloat("DragFloat (-inf -> 1)", s.drag_f, 0.005, -FLT_MAX, 1.0, "%.3f", flags)
    s.drag_f = ImGui.DragFloat("DragFloat (-inf -> +inf)", s.drag_f, 0.005, -FLT_MAX, FLT_MAX, "%.3f", flags)
    s.drag_i = ImGui.DragInt("DragInt (0 -> 100)", s.drag_i, 0.5, 0, 100, "%d", flags)
    ImGui.DragFloat4("DragFloat4 (0 -> 1)", s.drag_f4, 0.005, 0.0, 1.0, "%.3f", flags)

    local flags_for_sliders = bit32.band(flags, bit32.bnot(SF.WrapAround))
    ImGui.Text("Underlying float value: %f", s.slider_f)
    s.slider_f = ImGui.SliderFloat("SliderFloat (0 -> 1)", s.slider_f, 0.0, 1.0, "%.3f", flags_for_sliders)
    s.slider_i = ImGui.SliderInt("SliderInt (0 -> 100)", s.slider_i, 0, 100, "%d", flags_for_sliders)
    ImGui.SliderFloat4("SliderFloat4 (0 -> 1)", s.slider_f4, 0.0, 1.0, "%.3f", flags_for_sliders)
    ImGui.TreePop()
end

function DemoWindowWidgetsFonts()
    if not ImGui.TreeNode("Fonts") then return end
    if ImGui.ShowFontAtlas then ImGui.ShowFontAtlas(ImGui.GetIO().Fonts) else DemoNotPorted("ShowFontAtlas") end
    ImGui.TreePop()
end

S.img = { viewer = nil, pressed_count = 0 }
function DemoWindowWidgetsImages()
    if not ImGui.TreeNode("Images") then return end
    local s = S.img
    local io = ImGui.GetIO()
    ImGui.TextWrapped("Below we are displaying the font texture (which is the only texture we have access to in this demo). Use the 'ImTextureID' type as storage to pass pointers or identifier to your own texture data. Hover the texture for a zoomed view!")
    local atlas = io.Fonts
    local my_tex_id = atlas.TexRef
    local my_tex_w = atlas.TexData and atlas.TexData.Width or 0
    local my_tex_h = atlas.TexData and atlas.TexData.Height or 0
    ImGui.Text("%.0fx%.0f", my_tex_w, my_tex_h)

    ImGui.SeparatorText("Image()/ImageWithBg() function")
    ImGui.PushStyleVar(ImGuiStyleVar.ImageBorderSize, math.max(1.0, ImGui.GetStyle().ImageBorderSize))
    ImGui.ImageWithBg(my_tex_id, ImVec2(my_tex_w, my_tex_h), ImVec2(0.0, 0.0), ImVec2(1.0, 1.0), ImVec4(0.0, 0.0, 0.0, 1.0))
    ImGui.PopStyleVar()

    ImGui.SeparatorText("Interactive Image Viewer")
    s.viewer = s.viewer or ExampleImageViewerData()
    local canvas_size = ImVec2(ImGui.GetContentRegionAvail().x, my_tex_h * 2.0)
    ExampleImageViewer_DrawOptions(s.viewer)
    ExampleImageViewer_DrawCanvas(s.viewer, canvas_size, my_tex_id, my_tex_w, my_tex_h)

    ImGui.SeparatorText("Textured Buttons")
    ImGui.TextWrapped("And now some textured buttons..")
    for i = 0, 7 do
        ImGui.PushID(i)
        if i > 0 then ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(i - 1.0, i - 1.0)) end
        local size = ImVec2(32.0, 32.0)
        local uv0 = ImVec2(0.0, 0.0)
        local uv1 = ImVec2(32.0 / my_tex_w, 32.0 / my_tex_h)
        if ImGui.ImageButton("", my_tex_id, size, uv0, uv1, ImVec4(0.0, 0.0, 0.0, 1.0), ImVec4(1.0, 1.0, 1.0, 1.0)) then
            s.pressed_count = s.pressed_count + 1
        end
        if i > 0 then ImGui.PopStyleVar() end
        ImGui.PopID()
        ImGui.SameLine()
    end
    ImGui.NewLine()
    ImGui.Text("Pressed %d times.", s.pressed_count)
    ImGui.TreePop()
end

S.lb = { sel = 0, highlight = false }
function DemoWindowWidgetsListBoxes()
    if not ImGui.TreeNode("List Boxes") then return end
    local s = S.lb
    local items = { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIII", "JJJJ", "KKKK", "LLLLLLL", "MMMM", "OOOOOOO" }
    local item_highlighted_idx = -1
    _, s.highlight = ImGui.Checkbox("Highlight hovered item in second listbox", s.highlight)
    if ImGui.BeginListBox("listbox 1") then
        for n = 0, #items - 1 do
            local is_selected = (s.sel == n)
            if ImGui.Selectable(items[n + 1], is_selected) then s.sel = n end
            if s.highlight and ImGui.IsItemHovered() then item_highlighted_idx = n end
            if is_selected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndListBox()
    end
    ImGui.SameLine(); HelpMarker("Here we are sharing selection state between both boxes.")
    ImGui.Text("Full-width:")
    if ImGui.BeginListBox("##listbox 2", ImVec2(-FLT_MIN, 5 * ImGui.GetTextLineHeightWithSpacing())) then
        for n = 0, #items - 1 do
            local is_selected = (s.sel == n)
            local flags = (item_highlighted_idx == n) and ImGuiSelectableFlags.Highlight or 0
            if ImGui.Selectable(items[n + 1], is_selected, flags) then s.sel = n end
            if is_selected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndListBox()
    end
    ImGui.TreePop()
end

S.le = { str = Buf("", 32), i = 0, f = 0.0 }
function DemoWindowWidgetsLiveEdit(demo_data)
    if not ImGui.TreeNode("Live Edit Flags") then return end
    local s = S.le
    ImGui.TextWrapped("Select whether to apply keyboard edits to backing variables _while_ typing.")
    _, demo_data.LiveEditOverride = ImGui.Checkbox("Override Live Edit Flags in Demo Window", demo_data.LiveEditOverride)
    if not demo_data.LiveEditOverride then demo_data.LiveEditFlags = ImGui.GetItemFlags() end
    ImGui.BeginDisabled(demo_data.LiveEditOverride == false)
    ImGui.Indent()
    _, demo_data.LiveEditFlags = ImGui.CheckboxFlags("ImGuiItemFlags_LiveEditOnInputText", demo_data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputText)
    _, demo_data.LiveEditFlags = ImGui.CheckboxFlags("ImGuiItemFlags_LiveEditOnInputScalar", demo_data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputScalar)
    ImGui.Unindent()
    ImGui.EndDisabled()
    ImGui.Text("Try typing '123' and seeing effect on backing value:")
    ImGui.InputText("str", s.str, 32)
    ImGui.Text("Backing value: \"%s\"", BufStr(s.str))
    s.i = ImGui.InputInt("int", s.i, 0, 0)
    ImGui.Text("Backing value: %d", s.i)
    s.f = ImGui.SliderFloat("float", s.f, 0.0, 100.0)
    ImGui.Text("Backing value: %f", s.f)
    ImGui.TreePop()
end

S.mv = { use_liveedit = false, items = { 12.0, 0.0, 0.0 } }
function DemoWindowWidgetsMixedValues()
    if not ImGui.TreeNode("Mixed Values") then return end
    local s = S.mv
    local items = s.items
    HelpMarker("Using ImGuiItemFlags_MixedValue.")
    _, s.use_liveedit = ImGui.Checkbox("ImGuiItemFlags_LiveEditOnInput", s.use_liveedit)
    ImGui.SeparatorText("Scalar/Text Widgets")
    local is_mixed = items[1] ~= items[2] or items[1] ~= items[3]
    ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInput, s.use_liveedit)
    ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, is_mixed)
    local edited, e = false, false
    items[1], e = ImGui.DragFloat("DragFloat", items[1]); edited = edited or e
    items[1], e = ImGui.SliderFloat("SliderFloat", items[1], 0.0, 100.0); edited = edited or e
    items[1], e = ImGui.InputFloat("InputFloat", items[1], 1.0); edited = edited or e
    if edited then items[2] = items[1]; items[3] = items[1] end
    ImGui.PopItemFlag()
    ImGui.Text("Underlying data:")
    items[1] = ImGui.InputFloat("item 0 (ref)", items[1])
    items[2] = ImGui.InputFloat("item 1", items[2])
    items[3] = ImGui.InputFloat("item 2", items[3])
    ImGui.PopItemFlag()

    ImGui.SeparatorText("Others Widgets")
    ImGui.Text("(note: edits are not applied in this demo)")
    ImGui.Checkbox("Checkbox On", true)
    ImGui.Checkbox("Checkbox Off", false)
    ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, true)
    ImGui.Checkbox("Checkbox Mixed", false)
    ImGui.RadioButtonEx("RadioButton Mixed", true)
    ImGui.SameLine()
    ImGui.RadioButtonEx("RadioButton Mixed##2", true)
    ImGui.Combo("Combo", 0, "One\0Two\0Three\0")
    ImGui.ColorEdit4("ColorEdit4", ImVec4(0.5, 0.5, 0.5, 0.5))
    ImGui.PopItemFlag()
    ImGui.TreePop()
end

S.mc = { vec4f = { 0.10, 0.20, 0.30, 0.44 }, vec4i = { 1, 5, 100, 255 }, flags = 0, b = 10, e = 90, bi = 100, ei = 1000 }
function DemoWindowWidgetsMultiComponents()
    if not ImGui.TreeNode("Multi-component Widgets") then return end
    local s = S.mc
    local f, i = s.vec4f, s.vec4i
    if ImGuiSliderFlags.ColorMarkers then _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_ColorMarkers", s.flags, ImGuiSliderFlags.ColorMarkers) end
    local flags = s.flags
    for _, n in ipairs({ 2, 3, 4 }) do
        ImGui.SeparatorText(n .. "-wide")
        ImGui["InputFloat" .. n]("input float" .. n, f)
        ImGui["InputInt" .. n]("input int" .. n, i)
        ImGui["DragFloat" .. n]("drag float" .. n, f, 0.01, 0.0, 1.0, nil, flags)
        ImGui["DragInt" .. n]("drag int" .. n, i, 1, 0, 255, nil, flags)
        ImGui["SliderFloat" .. n]("slider float" .. n, f, 0.0, 1.0, nil, flags)
        ImGui["SliderInt" .. n]("slider int" .. n, i, 0, 255, nil, flags)
    end
    ImGui.SeparatorText("Ranges")
    s.b, s.e = ImGui.DragFloatRange2("range float", s.b, s.e, 0.25, 0.0, 100.0, "Min: %.1f %%", "Max: %.1f %%", ImGuiSliderFlags.AlwaysClamp)
    s.bi, s.ei = ImGui.DragIntRange2("range int", s.bi, s.ei, 5, 0, 1000, "Min: %d units", "Max: %d units")
    s.bi, s.ei = ImGui.DragIntRange2("range int (no bounds)", s.bi, s.ei, 5, 0, 0, "Min: %d units", "Max: %d units")
    ImGui.TreePop()
end

S.plot = { animate = true, arr = { 0.6, 0.1, 1.0, 0.5, 0.92, 0.1, 0.2 }, values = {}, values_offset = 0, refresh_time = 0.0, phase = 0.0,
    func_type = 0, display_count = 70 }
for n = 1, 90 do S.plot.values[n] = 0.0 end
function DemoWindowWidgetsPlotting()
    if not ImGui.TreeNode("Plotting") then return end
    local s = S.plot
    ImGui.Text("Need better plotting and graphing? Consider using ImPlot:")
    ImGui.TextLinkOpenURL("https://github.com/epezent/implot")
    ImGui.Separator()
    _, s.animate = ImGui.Checkbox("Animate", s.animate)
    ImGui.PlotLines("Frame Times", s.arr, nil, #s.arr)
    ImGui.PlotHistogram("Histogram", s.arr, nil, #s.arr, 0, nil, 0.0, 1.0, ImVec2(0, 80.0))

    local values = s.values
    if not s.animate or s.refresh_time == 0.0 then s.refresh_time = ImGui.GetTime() end
    while s.refresh_time < ImGui.GetTime() do
        values[s.values_offset + 1] = math.cos(s.phase)
        s.values_offset = (s.values_offset + 1) % #values
        s.phase = s.phase + 0.10 * s.values_offset
        s.refresh_time = s.refresh_time + 1.0 / 60.0
    end
    local average = 0.0
    for n = 1, #values do average = average + values[n] end
    average = average / #values
    ImGui.PlotLines("Lines", values, nil, #values, s.values_offset, string.format("avg %f", average), -1.0, 1.0, ImVec2(0, 80.0))

    -- Getters receive a 1-based index in this port
    local function Sin(_, i) return math.sin((i - 1) * 0.1) end
    local function Saw(_, i) return ((i - 1) % 2 == 1) and 1.0 or -1.0 end
    ImGui.SeparatorText("Functions")
    ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
    s.func_type = ImGui.Combo("func", s.func_type, "Sin\0Saw\0")
    ImGui.SameLine()
    s.display_count = ImGui.SliderInt("Sample count", s.display_count, 1, 400)
    local func = (s.func_type == 0) and Sin or Saw
    ImGui.PlotLines("Lines##2", func, nil, s.display_count, 0, nil, -1.0, 1.0, ImVec2(0, 80))
    ImGui.PlotHistogram("Histogram##2", func, nil, s.display_count, 0, nil, -1.0, 1.0, ImVec2(0, 80))
    ImGui.TreePop()
end

S.pb = { accum = 0.0, dir = 1.0 }
function DemoWindowWidgetsProgressBars()
    if not ImGui.TreeNode("Progress Bars") then return end
    local s = S.pb
    s.accum = s.accum + s.dir * 0.4 * ImGui.GetIO().DeltaTime
    if s.accum >= 1.1 then s.accum = 1.1; s.dir = -s.dir end
    if s.accum <= -0.1 then s.accum = -0.1; s.dir = -s.dir end
    local progress = DemoClamp(s.accum, 0.0, 1.0)
    ImGui.ProgressBar(progress, ImVec2(0.0, 0.0))
    ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
    ImGui.Text("Progress Bar")
    ImGui.ProgressBar(progress, ImVec2(0.0, 0.0), string.format("%d/%d", math.floor(progress * 1753), 1753))
    ImGui.ProgressBar(-1.0 * ImGui.GetTime(), ImVec2(0.0, 0.0), "Searching..")
    ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
    ImGui.Text("Indeterminate")
    ImGui.TreePop()
end

-- Selectable(label, bool* p_selected) overload: toggles on press
local function SelectableP(label, sel, flags, size)
    local pressed = ImGui.Selectable(label, sel, flags, size)
    if pressed then sel = not sel end
    return pressed, sel
end

local function B(v) return v and 1 or 0 end

S.qs = { item_type = 4, item_disabled = false, item_mixedvalue = false, liveedit_override = false, liveedit_flags = 0,
    b = false, col4f = { 1.0, 0.5, 0.0, 1.0 }, str = Buf("", 16), combo = 1, listbox = 1, unused = Buf("", 1),
    embed = false, test_window = false }
function DemoWindowWidgetsQueryingStatuses()
    local s = S.qs
    if ImGui.TreeNode("Querying Item Status (Edited/Active/Hovered etc.)") then
        local item_names = { "Text", "Button", "Button (w/ repeat)", "Checkbox", "SliderFloat", "InputText", "InputTextMultiline", "InputFloat",
            "InputFloat3", "ColorEdit4", "Selectable", "MenuItem", "TreeNode", "TreeNode (w/ double-click)", "Combo", "ListBox" }
        s.item_type = ImGui.Combo("Item Type", s.item_type, item_names, #item_names, #item_names)
        ImGui.SameLine()
        HelpMarker("Testing how various types of items are interacting with the IsItemXXX functions. Note that the bool return value of most ImGui function is generally equivalent to calling ImGui::IsItemHovered().")
        _, s.item_disabled = ImGui.Checkbox("Item Disabled", s.item_disabled)
        _, s.item_mixedvalue = ImGui.Checkbox("Item MixedValue", s.item_mixedvalue)
        _, s.liveedit_override = ImGui.Checkbox("Override LiveEdit:", s.liveedit_override)
        ImGui.SameLine()
        if not s.liveedit_override then s.liveedit_flags = ImGui.GetItemFlags() end
        ImGui.BeginDisabled(s.liveedit_override == false)
        _, s.liveedit_flags = ImGui.CheckboxFlags("_LiveEditOnInput", s.liveedit_flags, ImGuiItemFlags.LiveEditOnInput)
        ImGui.SameLine()
        _, s.liveedit_flags = ImGui.CheckboxFlags("_LiveEditOnInputText", s.liveedit_flags, ImGuiItemFlags.LiveEditOnInputText)
        ImGui.SameLine()
        _, s.liveedit_flags = ImGui.CheckboxFlags("_LiveEditOnInputScalar", s.liveedit_flags, ImGuiItemFlags.LiveEditOnInputScalar)
        ImGui.EndDisabled()
        if s.liveedit_override then
            ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputText, bit32.band(s.liveedit_flags, ImGuiItemFlags.LiveEditOnInputText) ~= 0)
            ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputScalar, bit32.band(s.liveedit_flags, ImGuiItemFlags.LiveEditOnInputScalar) ~= 0)
        end

        local ret = false
        local t = s.item_type
        if s.item_disabled then ImGui.BeginDisabled(true) end
        if s.item_mixedvalue then ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, true) end
        if t == 0 then ImGui.Text("ITEM: Text") end
        if t == 1 then ret = ImGui.Button("ITEM: Button") end
        if t == 2 then ImGui.PushItemFlag(ImGuiItemFlags.ButtonRepeat, true); ret = ImGui.Button("ITEM: Button"); ImGui.PopItemFlag() end
        if t == 3 then ret, s.b = ImGui.Checkbox("ITEM: Checkbox", s.b) end
        if t == 4 then s.col4f[1], ret = ImGui.SliderFloat("ITEM: SliderFloat", s.col4f[1], 0.0, 1.0) end
        if t == 5 then ret = ImGui.InputText("ITEM: InputText", s.str, 16) end
        if t == 6 then ret = ImGui.InputTextMultiline("ITEM: InputTextMultiline", s.str, 16) end
        if t == 7 then s.col4f[1], ret = ImGui.InputFloat("ITEM: InputFloat", s.col4f[1], 1.0) end
        if t == 8 then ret = ImGui.InputFloat3("ITEM: InputFloat3", s.col4f) end
        if t == 9 then ret = ImGui.ColorEdit4("ITEM: ColorEdit4", s.col4f) end
        if t == 10 then ret = ImGui.Selectable("ITEM: Selectable") end
        if t == 11 then ret = ImGui.MenuItem("ITEM: MenuItem") end
        if t == 12 then ret = ImGui.TreeNode("ITEM: TreeNode"); if ret then ImGui.TreePop() end end
        if t == 13 then ret = ImGui.TreeNodeEx("ITEM: TreeNode w/ ImGuiTreeNodeFlags_OpenOnDoubleClick", bit32.bor(ImGuiTreeNodeFlags.OpenOnDoubleClick, ImGuiTreeNodeFlags.NoTreePushOnOpen)) end
        if t == 14 then s.combo, ret = ImGui.Combo("ITEM: Combo", s.combo, { "Apple", "Banana", "Cherry", "Kiwi" }) end
        if t == 15 then s.listbox, ret = ImGui.ListBox("ITEM: ListBox", s.listbox, { "Apple", "Banana", "Cherry", "Kiwi" }, 4, 4) end

        local HF = ImGuiHoveredFlags
        local hovered_delay_none = ImGui.IsItemHovered()
        local hovered_delay_stationary = ImGui.IsItemHovered(HF.Stationary)
        local hovered_delay_short = ImGui.IsItemHovered(HF.DelayShort)
        local hovered_delay_normal = ImGui.IsItemHovered(HF.DelayNormal)
        local hovered_delay_tooltip = ImGui.IsItemHovered(HF.ForTooltip)
        local rmin, rmax, rsize = ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), ImGui.GetItemRectSize()
        ImGui.BulletText(
            "Return value = %d\nIsItemFocused() = %d\nIsItemHovered() = %d\nIsItemHovered(_AllowWhenBlockedByPopup) = %d\n" ..
            "IsItemHovered(_AllowWhenBlockedByActiveItem) = %d\nIsItemHovered(_AllowWhenOverlappedByItem) = %d\n" ..
            "IsItemHovered(_AllowWhenOverlappedByWindow) = %d\nIsItemHovered(_AllowWhenDisabled) = %d\nIsItemHovered(_RectOnly) = %d\n" ..
            "IsItemActive() = %d\nIsItemEdited() = %d\nIsItemActivated() = %d\nIsItemDeactivated() = %d\nIsItemDeactivatedAfterEdit() = %d\n" ..
            "IsItemVisible() = %d\nIsItemClicked() = %d\nIsItemToggledOpen() = %d\n" ..
            "GetItemRectMin() = (%.1f, %.1f)\nGetItemRectMax() = (%.1f, %.1f)\nGetItemRectSize() = (%.1f, %.1f)",
            B(ret), B(ImGui.IsItemFocused()), B(ImGui.IsItemHovered()), B(ImGui.IsItemHovered(HF.AllowWhenBlockedByPopup)),
            B(ImGui.IsItemHovered(HF.AllowWhenBlockedByActiveItem)), B(ImGui.IsItemHovered(HF.AllowWhenOverlappedByItem)),
            B(ImGui.IsItemHovered(HF.AllowWhenOverlappedByWindow)), B(ImGui.IsItemHovered(HF.AllowWhenDisabled)), B(ImGui.IsItemHovered(HF.RectOnly)),
            B(ImGui.IsItemActive()), B(ImGui.IsItemEdited()), B(ImGui.IsItemActivated()), B(ImGui.IsItemDeactivated()), B(ImGui.IsItemDeactivatedAfterEdit()),
            B(ImGui.IsItemVisible()), B(ImGui.IsItemClicked()), B(ImGui.IsItemToggledOpen()),
            rmin.x, rmin.y, rmax.x, rmax.y, rsize.x, rsize.y)
        ImGui.BulletText(
            "with Hovering Delay or Stationary test:\nIsItemHovered() = %d\nIsItemHovered(_Stationary) = %d\nIsItemHovered(_DelayShort) = %d\nIsItemHovered(_DelayNormal) = %d\nIsItemHovered(_Tooltip) = %d",
            B(hovered_delay_none), B(hovered_delay_stationary), B(hovered_delay_short), B(hovered_delay_normal), B(hovered_delay_tooltip))

        if s.liveedit_override then ImGui.PopItemFlag(); ImGui.PopItemFlag() end
        if s.item_mixedvalue then ImGui.PopItemFlag() end
        if s.item_disabled then ImGui.EndDisabled() end

        ImGui.InputText("unused", s.unused, 1, ImGuiInputTextFlags.ReadOnly)
        ImGui.SameLine()
        HelpMarker("This widget is only here to be able to tab-out of the widgets above and see e.g. Deactivated() status.")
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Querying Window Status (Focused/Hovered etc.)") then
        _, s.embed = ImGui.Checkbox("Embed everything inside a child window for testing _RootWindow flag.", s.embed)
        if s.embed then ImGui.BeginChild("outer_child", ImVec2(0, ImGui.GetFontSize() * 20.0), ImGuiChildFlags.Borders) end
        local FF, HF = ImGuiFocusedFlags, ImGuiHoveredFlags
        local bor = bit32.bor
        ImGui.BulletText(
            "IsWindowFocused() = %d\nIsWindowFocused(_ChildWindows) = %d\nIsWindowFocused(_ChildWindows|_NoPopupHierarchy) = %d\n" ..
            "IsWindowFocused(_ChildWindows|_DockHierarchy) = %d\nIsWindowFocused(_ChildWindows|_RootWindow) = %d\n" ..
            "IsWindowFocused(_ChildWindows|_RootWindow|_NoPopupHierarchy) = %d\nIsWindowFocused(_ChildWindows|_RootWindow|_DockHierarchy) = %d\n" ..
            "IsWindowFocused(_RootWindow) = %d\nIsWindowFocused(_RootWindow|_NoPopupHierarchy) = %d\nIsWindowFocused(_RootWindow|_DockHierarchy) = %d\n" ..
            "IsWindowFocused(_AnyWindow) = %d\n",
            B(ImGui.IsWindowFocused()), B(ImGui.IsWindowFocused(FF.ChildWindows)), B(ImGui.IsWindowFocused(bor(FF.ChildWindows, FF.NoPopupHierarchy))),
            B(ImGui.IsWindowFocused(bor(FF.ChildWindows, FF.DockHierarchy))), B(ImGui.IsWindowFocused(bor(FF.ChildWindows, FF.RootWindow))),
            B(ImGui.IsWindowFocused(bor(FF.ChildWindows, FF.RootWindow, FF.NoPopupHierarchy))), B(ImGui.IsWindowFocused(bor(FF.ChildWindows, FF.RootWindow, FF.DockHierarchy))),
            B(ImGui.IsWindowFocused(FF.RootWindow)), B(ImGui.IsWindowFocused(bor(FF.RootWindow, FF.NoPopupHierarchy))), B(ImGui.IsWindowFocused(bor(FF.RootWindow, FF.DockHierarchy))),
            B(ImGui.IsWindowFocused(FF.AnyWindow)))
        ImGui.BulletText(
            "IsWindowHovered() = %d\nIsWindowHovered(_AllowWhenBlockedByPopup) = %d\nIsWindowHovered(_AllowWhenBlockedByActiveItem) = %d\n" ..
            "IsWindowHovered(_ChildWindows) = %d\nIsWindowHovered(_ChildWindows|_NoPopupHierarchy) = %d\nIsWindowHovered(_ChildWindows|_DockHierarchy) = %d\n" ..
            "IsWindowHovered(_ChildWindows|_RootWindow) = %d\nIsWindowHovered(_ChildWindows|_RootWindow|_NoPopupHierarchy) = %d\n" ..
            "IsWindowHovered(_ChildWindows|_RootWindow|_DockHierarchy) = %d\nIsWindowHovered(_RootWindow) = %d\nIsWindowHovered(_RootWindow|_NoPopupHierarchy) = %d\n" ..
            "IsWindowHovered(_RootWindow|_DockHierarchy) = %d\nIsWindowHovered(_ChildWindows|_AllowWhenBlockedByPopup) = %d\nIsWindowHovered(_AnyWindow) = %d\n" ..
            "IsWindowHovered(_Stationary) = %d\n",
            B(ImGui.IsWindowHovered()), B(ImGui.IsWindowHovered(HF.AllowWhenBlockedByPopup)), B(ImGui.IsWindowHovered(HF.AllowWhenBlockedByActiveItem)),
            B(ImGui.IsWindowHovered(HF.ChildWindows)), B(ImGui.IsWindowHovered(bor(HF.ChildWindows, HF.NoPopupHierarchy))), B(ImGui.IsWindowHovered(bor(HF.ChildWindows, HF.DockHierarchy))),
            B(ImGui.IsWindowHovered(bor(HF.ChildWindows, HF.RootWindow))), B(ImGui.IsWindowHovered(bor(HF.ChildWindows, HF.RootWindow, HF.NoPopupHierarchy))),
            B(ImGui.IsWindowHovered(bor(HF.ChildWindows, HF.RootWindow, HF.DockHierarchy))), B(ImGui.IsWindowHovered(HF.RootWindow)), B(ImGui.IsWindowHovered(bor(HF.RootWindow, HF.NoPopupHierarchy))),
            B(ImGui.IsWindowHovered(bor(HF.RootWindow, HF.DockHierarchy))), B(ImGui.IsWindowHovered(bor(HF.ChildWindows, HF.AllowWhenBlockedByPopup))), B(ImGui.IsWindowHovered(HF.AnyWindow)),
            B(ImGui.IsWindowHovered(HF.Stationary)))
        ImGui.BeginChild("child", ImVec2(0, 50), ImGuiChildFlags.Borders)
        ImGui.Text("This is another child window for testing the _ChildWindows flag.")
        ImGui.EndChild()
        if s.embed then ImGui.EndChild() end

        _, s.test_window = ImGui.Checkbox("Hovered/Active tests after Begin() for title bar testing", s.test_window)
        if s.test_window then
            s.test_window = ImGui.Begin("Title bar Hovered/Active tests", s.test_window)
            if ImGui.BeginPopupContextItem() then
                if ImGui.MenuItem("Close") then s.test_window = false end
                ImGui.EndPopup()
            end
            ImGui.Text("IsItemHovered() after begin = %d (== is title bar hovered)\nIsItemActive() after begin = %d (== is window being clicked/moved)\n",
                B(ImGui.IsItemHovered()), B(ImGui.IsItemActive()))
            ImGui.End()
        end
        ImGui.TreePop()
    end
end

S.sel = { basic = { false, true, false, false }, multi = { false, false, false }, checked = { false, false, false, false, false }, selected_n = 0,
    tables = {}, grid = { { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 0, 1 } },
    align = { true, false, true, false, true, false, true, false, true } }
for i = 1, 10 do S.sel.tables[i] = false end
function DemoWindowWidgetsSelectables()
    if not ImGui.TreeNode("Selectables") then return end
    local s = S.sel
    if ImGui.TreeNode("Basic") then
        local b = s.basic
        _, b[1] = SelectableP("1. I am selectable", b[1])
        _, b[2] = SelectableP("2. I am selectable", b[2])
        _, b[3] = SelectableP("3. I am selectable", b[3])
        if ImGui.Selectable("4. I am double clickable", b[4], ImGuiSelectableFlags.AllowDoubleClick) then
            if ImGui.IsMouseDoubleClicked(0) then b[4] = not b[4] end
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Multiple items on the same line") then
        local m = s.multi
        ImGui.SetNextItemAllowOverlap(); _, m[1] = SelectableP("main.c", m[1]); ImGui.SameLine(); ImGui.SmallButton("Link 1")
        ImGui.SetNextItemAllowOverlap(); _, m[2] = SelectableP("hello.cpp", m[2]); ImGui.SameLine(); ImGui.SmallButton("Link 2")
        ImGui.SetNextItemAllowOverlap(); _, m[3] = SelectableP("hello.h", m[3]); ImGui.SameLine(); ImGui.SmallButton("Link 3")
        ImGui.Spacing()
        local color_marker_w = ImGui.CalcTextSize("x").x
        for n = 0, 4 do
            ImGui.PushID(n)
            ImGui.AlignTextToFramePadding()
            if ImGui.Selectable("##selectable", s.selected_n == n, ImGuiSelectableFlags.AllowOverlap) then s.selected_n = n end
            ImGui.SameLine(0, 0)
            _, s.checked[n + 1] = ImGui.Checkbox("##check", s.checked[n + 1])
            ImGui.SameLine()
            local color = ImVec4((n % 2 == 1) and 1.0 or 0.2, (math.floor(n / 2) % 2 == 1) and 1.0 or 0.2, 0.2, 1.0)
            ImGui.ColorButton("##color", color, ImGuiColorEditFlags.NoTooltip, ImVec2(color_marker_w, 0))
            ImGui.SameLine()
            ImGui.Text("Some label")
            ImGui.PopID()
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("In Tables") then
        local sel = s.tables
        local TF = ImGuiTableFlags
        if ImGui.BeginTable("split1", 3, bit32.bor(TF.Resizable, TF.NoSavedSettings, TF.Borders)) then
            for i = 0, 9 do
                ImGui.TableNextColumn()
                _, sel[i + 1] = SelectableP(string.format("Item %d", i), sel[i + 1])
            end
            ImGui.EndTable()
        end
        ImGui.Spacing()
        if ImGui.BeginTable("split2", 3, bit32.bor(TF.Resizable, TF.NoSavedSettings, TF.Borders)) then
            for i = 0, 9 do
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                _, sel[i + 1] = SelectableP(string.format("Item %d", i), sel[i + 1], ImGuiSelectableFlags.SpanAllColumns)
                ImGui.TableNextColumn()
                ImGui.Text("Some other contents")
                ImGui.TableNextColumn()
                ImGui.Text("123456")
            end
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Grid") then
        local g = s.grid
        local time = ImGui.GetTime()
        local winning_state = true
        for y = 1, 4 do for x = 1, 4 do if g[y][x] == 0 then winning_state = false end end end
        if winning_state then
            ImGui.PushStyleVar(ImGuiStyleVar.SelectableTextAlign, ImVec2(0.5 + 0.5 * math.cos(time * 2.0), 0.5 + 0.5 * math.sin(time * 3.0)))
        end
        local size = ImGui.CalcTextSize("Sailor").x
        for y = 1, 4 do
            for x = 1, 4 do
                if x > 1 then ImGui.SameLine() end
                ImGui.PushID((y - 1) * 4 + (x - 1))
                if ImGui.Selectable("Sailor", g[y][x] ~= 0, 0, ImVec2(size, size)) then
                    g[y][x] = 1 - g[y][x]
                    if x > 1 then g[y][x - 1] = 1 - g[y][x - 1] end
                    if x < 4 then g[y][x + 1] = 1 - g[y][x + 1] end
                    if y > 1 then g[y - 1][x] = 1 - g[y - 1][x] end
                    if y < 4 then g[y + 1][x] = 1 - g[y + 1][x] end
                end
                ImGui.PopID()
            end
        end
        if winning_state then ImGui.PopStyleVar() end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Alignment") then
        HelpMarker("By default, Selectables uses style.SelectableTextAlign but it can be overridden on a per-item basis using PushStyleVar(). You'll probably want to always keep your default situation to left-align otherwise it becomes difficult to layout multiple items on a same line")
        local size = ImGui.CalcTextSize("(1.0,1.0)").x
        for y = 0, 2 do
            for x = 0, 2 do
                local alignment = ImVec2(x / 2.0, y / 2.0)
                local name = string.format("(%.1f,%.1f)", alignment.x, alignment.y)
                if x > 0 then ImGui.SameLine() end
                ImGui.PushStyleVar(ImGuiStyleVar.SelectableTextAlign, alignment)
                _, s.align[3 * y + x + 1] = SelectableP(name, s.align[3 * y + x + 1], ImGuiSelectableFlags.None, ImVec2(size, size))
                ImGui.PopStyleVar()
            end
        end
        ImGui.TreePop()
    end
    ImGui.TreePop()
end

local function EditTabBarFittingPolicyFlags(flags)
    local TB = ImGuiTabBarFlags
    if bit32.band(flags, TB.FittingPolicyMask_) == 0 then flags = bit32.bor(flags, TB.FittingPolicyDefault_) end
    for _, n in ipairs({ "FittingPolicyMixed", "FittingPolicyShrink", "FittingPolicyScroll" }) do
        local p
        p, flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_" .. n, flags, TB[n])
        if p then flags = bit32.band(flags, bit32.bnot(bit32.bxor(TB.FittingPolicyMask_, TB[n]))) end
    end
    return flags
end

S.tabs = { adv_flags = ImGuiTabBarFlags.Reorderable, opened = { true, true, true, true }, active_tabs = {}, next_tab_id = 0,
    show_leading = true, show_trailing = true, show_lt_tabs = false,
    tib_flags = bit32.bor(ImGuiTabBarFlags.AutoSelectNewTabs, ImGuiTabBarFlags.Reorderable, ImGuiTabBarFlags.FittingPolicyMixed) }
function DemoWindowWidgetsTabs()
    if not ImGui.TreeNode("Tabs") then return end
    local s = S.tabs
    local TB, TI = ImGuiTabBarFlags, ImGuiTabItemFlags
    if ImGui.TreeNode("Basic") then
        if ImGui.BeginTabBar("MyTabBar", TB.None) then
            if ImGui.BeginTabItem("Avocado") then ImGui.Text("This is the Avocado tab!\nblah blah blah blah blah"); ImGui.EndTabItem() end
            if ImGui.BeginTabItem("Broccoli") then ImGui.Text("This is the Broccoli tab!\nblah blah blah blah blah"); ImGui.EndTabItem() end
            if ImGui.BeginTabItem("Cucumber") then ImGui.Text("This is the Cucumber tab!\nblah blah blah blah blah"); ImGui.EndTabItem() end
            ImGui.EndTabBar()
        end
        ImGui.Separator()
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Advanced & Close Button") then
        for _, n in ipairs({ "Reorderable", "AutoSelectNewTabs", "TabListPopupButton", "NoCloseWithMiddleMouseButton", "DrawSelectedOverline" }) do
            _, s.adv_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_" .. n, s.adv_flags, TB[n])
        end
        s.adv_flags = EditTabBarFittingPolicyFlags(s.adv_flags)
        ImGui.AlignTextToFramePadding()
        ImGui.Text("Opened:")
        local names = { "Artichoke", "Beetroot", "Celery", "Daikon" }
        for n = 1, 4 do
            ImGui.SameLine()
            _, s.opened[n] = ImGui.Checkbox(names[n], s.opened[n])
        end
        if ImGui.BeginTabBar("MyTabBar", s.adv_flags) then
            for n = 1, 4 do
                if s.opened[n] then
                    local visible
                    visible, s.opened[n] = ImGui.BeginTabItem(names[n], s.opened[n], TI.None)
                    if visible then
                        ImGui.Text("This is the %s tab!", names[n])
                        if (n - 1) % 2 == 1 then ImGui.Text("I am an odd tab.") end
                        ImGui.EndTabItem()
                    end
                end
            end
            ImGui.EndTabBar()
        end
        ImGui.Separator()
        ImGui.TreePop()
    end

    if ImGui.TreeNode("TabItemButton & Leading/Trailing flags") then
        if s.next_tab_id == 0 then
            for _ = 1, 3 do s.active_tabs[#s.active_tabs + 1] = s.next_tab_id; s.next_tab_id = s.next_tab_id + 1 end
        end
        _, s.show_leading = ImGui.Checkbox("Show Leading TabItemButton()", s.show_leading)
        _, s.show_trailing = ImGui.Checkbox("Show Trailing TabItemButton()", s.show_trailing)
        _, s.show_lt_tabs = ImGui.Checkbox("Show Leading+Trailing TabItem()", s.show_lt_tabs)
        s.tib_flags = EditTabBarFittingPolicyFlags(s.tib_flags)
        if ImGui.BeginTabBar("MyTabBar", s.tib_flags) then
            if s.show_leading then
                if ImGui.TabItemButton("?", bit32.bor(TI.Leading, TI.NoTooltip)) then ImGui.OpenPopup("MyHelpMenu") end
            end
            if ImGui.BeginPopup("MyHelpMenu") then
                ImGui.Selectable("Hello!")
                ImGui.EndPopup()
            end
            if s.show_lt_tabs then
                if ImGui.BeginTabItem("Leading", nil, TI.Leading) then ImGui.EndTabItem() end
                if ImGui.BeginTabItem("Trailing", nil, TI.Trailing) then ImGui.EndTabItem() end
            end
            if s.show_trailing then
                if ImGui.TabItemButton("+", bit32.bor(TI.Trailing, TI.NoTooltip)) then
                    s.active_tabs[#s.active_tabs + 1] = s.next_tab_id; s.next_tab_id = s.next_tab_id + 1
                end
            end
            local n = 1
            while n <= #s.active_tabs do
                local name = string.format("%04d", s.active_tabs[n])
                local visible, open = ImGui.BeginTabItem(name, true, TI.None)
                if visible then
                    ImGui.Text("This is the %s tab!", name)
                    ImGui.EndTabItem()
                end
                if open == false then table.remove(s.active_tabs, n) else n = n + 1 end
            end
            ImGui.EndTabBar()
        end
        ImGui.Separator()
        ImGui.TreePop()
    end
    ImGui.TreePop()
end

S.text = { custom_size = 16.0, custom_scale = 1.0, wrap_width = 200.0, utf8 = Buf("\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e", 32) }
function DemoWindowWidgetsText()
    if not ImGui.TreeNode("Text") then return end
    local s = S.text
    if ImGui.TreeNode("Colorful Text") then
        ImGui.TextColored(ImVec4(1.0, 0.0, 1.0, 1.0), "Pink")
        ImGui.TextColored(ImVec4(1.0, 1.0, 0.0, 1.0), "Yellow")
        ImGui.TextDisabled("Disabled")
        ImGui.SameLine(); HelpMarker("The TextDisabled color is stored in ImGuiStyle.")
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Font Size") then
        local style = ImGui.GetStyle()
        local global_scale = style.FontScaleMain * style.FontScaleDpi
        ImGui.Text("style.FontScaleMain = %0.2f", style.FontScaleMain)
        ImGui.Text("style.FontScaleDpi = %0.2f", style.FontScaleDpi)
        ImGui.Text("global_scale = ~%0.2f", global_scale)
        ImGui.Text("FontSize = %0.2f", ImGui.GetFontSize())
        ImGui.SeparatorText("")
        s.custom_size = ImGui.SliderFloat("custom_size", s.custom_size, 10.0, 100.0, "%.0f")
        ImGui.Text("ImGui::PushFont(nullptr, custom_size);")
        ImGui.PushFont(nil, s.custom_size)
        ImGui.Text("FontSize = %.2f (== %.2f * global_scale)", ImGui.GetFontSize(), s.custom_size)
        ImGui.PopFont()
        ImGui.SeparatorText("")
        s.custom_scale = ImGui.SliderFloat("custom_scale", s.custom_scale, 0.5, 4.0, "%.2f")
        ImGui.Text("ImGui::PushFont(nullptr, style.FontSizeBase * custom_scale);")
        ImGui.PushFont(nil, style.FontSizeBase * s.custom_scale)
        ImGui.Text("FontSize = %.2f (== style.FontSizeBase * %.2f * global_scale)", ImGui.GetFontSize(), s.custom_scale)
        ImGui.PopFont()
        ImGui.SeparatorText("")
        local scaling = 0.5
        while scaling <= 4.0 do
            ImGui.PushFont(nil, style.FontSizeBase * scaling)
            ImGui.Text("FontSize = %.2f (== style.FontSizeBase * %.2f * global_scale)", ImGui.GetFontSize(), scaling)
            ImGui.PopFont()
            scaling = scaling + 0.5
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Word Wrapping") then
        ImGui.TextWrapped("This text should automatically wrap on the edge of the window. The current implementation for text wrapping follows simple rules suitable for English and possibly other languages.")
        ImGui.Spacing()
        s.wrap_width = ImGui.SliderFloat("Wrap width", s.wrap_width, -20, 600, "%.0f")
        local draw_list = ImGui.GetWindowDrawList()
        for n = 0, 1 do
            ImGui.Text("Test paragraph %d:", n)
            local pos = ImGui.GetCursorScreenPos()
            local marker_min = ImVec2(pos.x + s.wrap_width, pos.y)
            local marker_max = ImVec2(pos.x + s.wrap_width + 10, pos.y + ImGui.GetTextLineHeight())
            ImGui.PushTextWrapPos(ImGui.GetCursorPos().x + s.wrap_width)
            if n == 0 then
                ImGui.Text("The lazy dog is a good dog. This paragraph should fit within %.0f pixels. Testing a 1 character word. The quick brown fox jumps over the lazy dog.", s.wrap_width)
            else
                ImGui.Text("aaaaaaaa bbbbbbbb, c cccccccc,dddddddd. d eeeeeeee   ffffffff. gggggggg!hhhhhhhh")
            end
            draw_list:AddRect(ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), IM_COL32(255, 255, 0, 255))
            draw_list:AddRectFilled(marker_min, marker_max, IM_COL32(255, 0, 255, 255))
            ImGui.PopTextWrapPos()
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("UTF-8 Text") then
        ImGui.TextWrapped("CJK text will only appear if the font was loaded with the appropriate CJK character ranges. Call io.Fonts->AddFontFromFileTTF() manually to load extra character ranges. Read docs/FONTS.md for details.")
        ImGui.Text("Hiragana: \xe3\x81\x8b\xe3\x81\x8d\xe3\x81\x8f\xe3\x81\x91\xe3\x81\x93 (kakikukeko)")
        ImGui.Text("Kanjis: \xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e (nihongo)")
        ImGui.InputText("UTF-8 input", s.utf8, 32)
        ImGui.TreePop()
    end
    ImGui.TreePop()
end

S.tf = { filter = nil }
function DemoWindowWidgetsTextFilter()
    if not ImGui.TreeNode("Text Filter") then return end
    S.tf.filter = S.tf.filter or ImGuiTextFilter()
    local filter = S.tf.filter
    HelpMarker("Not a widget per-se, but ImGuiTextFilter is a helper to perform simple filtering on text strings.")
    ImGui.Text("Filter usage:\n  \"\"         display all lines\n  xxx        display lines containing \"xxx\"\n  xxx yyy    display lines containing \"xxx\" and \"yyy\"\n  \"xxx yyy\"  display lines containing \"xxx yyy\"\n  xxx,yyy    display lines containing \"xxx\" or \"yyy\"\n  -xxx       hide lines containing \"xxx\"")
    ImGui.SetNextItemWidth(-FLT_MIN)
    filter:DrawWithHint("##Filter", "Filter (incl -excl)")
    if ImGui.BeginChild("##items", ImVec2(-FLT_MIN, ImGui.GetTextLineHeightWithSpacing() * 15), ImGuiChildFlags.FrameStyle) then
        for _, item in ipairs({ "aaa1.c", "bbb1.c", "ccc1.c", "aaa2.cpp", "bbb2.cpp", "ccc2.cpp", "abc.h", "hello, world" }) do
            if filter:PassFilter(item) then ImGui.TextUnformatted(item) end
        end
        for _, item in ipairs(ExampleNames) do
            if filter:PassFilter(item) then ImGui.TextUnformatted(item) end
        end
    end
    ImGui.EndChild()
    ImGui.TreePop()
end

S.ti = {
    text = Buf("/*\n The Pentium F00F bug, shorthand for F0 0F C7 C8,\n the hexadecimal encoding of one offending instruction,\n more formally, the invalid operand with locked CMPXCHG8B\n instruction bug, is a design flaw in the majority of\n Intel Pentium, Pentium MMX, and Pentium OverDrive\n processors (all in the P5 microarchitecture).\n*/\n\nlabel:\n\tlock cmpxchg8b eax\n", 1024 * 16),
    ml_flags = ImGuiInputTextFlags.AllowTabInput,
    f = { Buf("", 32), Buf("", 32), Buf("", 32), Buf("", 32), Buf("", 32), Buf("", 32), Buf("", 32) },
    password = Buf("password123", 64), cb1 = Buf("", 64), cb2 = Buf("", 64), cb3 = Buf("", 64), edit_count = { 0 },
    rs_flags = 0, rs = Buf("", 1024),
    elide = Buf("/path/to/some/folder/with/long/filename.cpp", 128), elide_flags = ImGuiInputTextFlags.ElideLeft,
    misc = Buf("", 16), misc_flags = ImGuiInputTextFlags.EscapeClearsAll }
function DemoWindowWidgetsTextInput()
    if not ImGui.TreeNode("Text Input") then return end
    local s = S.ti
    local IT = ImGuiInputTextFlags
    local function FlagBox(key, name)
        if IT[name] then _, s[key] = ImGui.CheckboxFlags("ImGuiInputTextFlags_" .. name, s[key], IT[name]) end
    end
    if ImGui.TreeNode("Multi-line Text Input") then
        HelpMarker("You can use the ImGuiInputTextFlags_CallbackResize facility if you need to wire InputTextMultiline() to a dynamic string type.")
        FlagBox("ml_flags", "ReadOnly")
        FlagBox("ml_flags", "WordWrap")
        ImGui.SameLine(); HelpMarker("Feature is currently in Beta. Please read comments in imgui.h")
        FlagBox("ml_flags", "AllowTabInput")
        ImGui.SameLine(); HelpMarker("When _AllowTabInput is set, passing through the widget with Tabbing doesn't automatically activate it, in order to also cycling through subsequent widgets.")
        FlagBox("ml_flags", "CtrlEnterForNewLine")
        ImGui.InputTextMultiline("##source", s.text, 1024 * 16, ImVec2(-FLT_MIN, ImGui.GetTextLineHeight() * 16), s.ml_flags)
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Filtered Text Input") then
        local a, z, A, Z = string.byte("a"), string.byte("z"), string.byte("A"), string.byte("Z")
        local function FilterCasingSwap(data)
            local c = data.EventChar
            if c >= a and c <= z then data.EventChar = c - (a - A)
            elseif c >= A and c <= Z then data.EventChar = c + (a - A) end
            return 0
        end
        local function FilterImGuiLetters(data)
            local c = data.EventChar
            if c < 256 and string.find("imgui", string.char(c), 1, true) then return 0 end
            return 1
        end
        local f = s.f
        ImGui.InputText("default", f[1], 32)
        ImGui.InputText("decimal", f[2], 32, IT.CharsDecimal)
        ImGui.InputText("hexadecimal", f[3], 32, bit32.bor(IT.CharsHexadecimal, IT.CharsUppercase))
        ImGui.InputText("uppercase", f[4], 32, IT.CharsUppercase)
        ImGui.InputText("no blank", f[5], 32, IT.CharsNoBlank)
        ImGui.InputText("casing swap", f[6], 32, IT.CallbackCharFilter, FilterCasingSwap)
        ImGui.InputText("\"imgui\"", f[7], 32, IT.CallbackCharFilter, FilterImGuiLetters)
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Password Input") then
        ImGui.InputText("password", s.password, 64, IT.Password)
        ImGui.SameLine(); HelpMarker("Display all characters as '*'.\nDisable clipboard cut and copy.\nDisable logging.\n")
        ImGui.InputTextWithHint("password (w/ hint)", "<password>", s.password, 64, IT.Password)
        ImGui.InputText("password (clear)", s.password, 64)
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Completion, History, Edit Callbacks") then
        local function MyCallback(data)
            if data.EventFlag == IT.CallbackCompletion then
                data:InsertChars(data.CursorPos, "..")
            elseif data.EventFlag == IT.CallbackHistory then
                if data.EventKey == ImGuiKey.UpArrow then
                    data:DeleteChars(0, data.BufTextLen)
                    data:InsertChars(0, "Pressed Up!")
                    data:SelectAll()
                elseif data.EventKey == ImGuiKey.DownArrow then
                    data:DeleteChars(0, data.BufTextLen)
                    data:InsertChars(0, "Pressed Down!")
                    data:SelectAll()
                end
            elseif data.EventFlag == IT.CallbackEdit then
                local c = data.Buf[1]
                if (c >= 97 and c <= 122) or (c >= 65 and c <= 90) then data.Buf[1] = bit32.bxor(c, 32) end
                data.BufDirty = true
                local p_int = data.UserData
                p_int[1] = p_int[1] + 1
            end
            return 0
        end
        ImGui.InputText("Completion", s.cb1, 64, IT.CallbackCompletion, MyCallback)
        ImGui.SameLine(); HelpMarker("Here we append \"..\" each time Tab is pressed. See 'Examples>Console' for a more meaningful demonstration of using this callback.")
        ImGui.InputText("History", s.cb2, 64, IT.CallbackHistory, MyCallback)
        ImGui.SameLine(); HelpMarker("Here we replace and select text each time Up/Down are pressed. See 'Examples>Console' for a more meaningful demonstration of using this callback.")
        ImGui.InputText("Edit", s.cb3, 64, IT.CallbackEdit, MyCallback, s.edit_count)
        ImGui.SameLine(); HelpMarker("Here we toggle the casing of the first character on every edit + count edits.")
        ImGui.SameLine(); ImGui.Text("(%d)", s.edit_count[1])
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Resize Callback") then
        HelpMarker("Using ImGuiInputTextFlags_CallbackResize to wire your custom string type to InputText().\n\n(Lua port: fixed 1024 byte buffer, CallbackResize growth not supported)")
        FlagBox("rs_flags", "WordWrap")
        ImGui.InputTextMultiline("##MyStr", s.rs, 1024, ImVec2(-FLT_MIN, ImGui.GetTextLineHeight() * 16), s.rs_flags)
        ImGui.Text("Size: %d\nCapacity: %d", #BufStr(s.rs) + 1, 1024)
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Eliding, Alignment") then
        FlagBox("elide_flags", "ElideLeft")
        ImGui.InputText("Path", s.elide, 128, s.elide_flags)
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Miscellaneous") then
        FlagBox("misc_flags", "EscapeClearsAll")
        FlagBox("misc_flags", "ReadOnly")
        FlagBox("misc_flags", "NoUndoRedo")
        ImGui.InputText("Hello", s.misc, 16, s.misc_flags)
        ImGui.TreePop()
    end
    ImGui.TreePop()
end

S.tt = { arr = { 0.6, 0.1, 1.0, 0.5, 0.92, 0.1, 0.2 }, always_on = 0 }
function DemoWindowWidgetsTooltips()
    if not ImGui.TreeNode("Tooltips") then return end
    local s = S.tt
    local HF = ImGuiHoveredFlags
    ImGui.SeparatorText("General")
    HelpMarker("Tooltip are typically created by using a IsItemHovered() + SetTooltip() sequence.\n\nWe provide a helper SetItemTooltip() function to perform the two with standards flags.")
    local sz = ImVec2(-FLT_MIN, 0.0)
    ImGui.Button("Basic", sz)
    ImGui.SetItemTooltip("I am a tooltip")
    ImGui.Button("Fancy", sz)
    if ImGui.BeginItemTooltip() then
        ImGui.Text("I am a fancy tooltip")
        ImGui.PlotLines("Curve", s.arr, nil, #s.arr)
        ImGui.Text("Sin(time) = %f", math.sin(ImGui.GetTime()))
        ImGui.EndTooltip()
    end

    ImGui.SeparatorText("Always On")
    _, s.always_on = ImGui.RadioButton("Off", s.always_on, 0)
    ImGui.SameLine()
    _, s.always_on = ImGui.RadioButton("Always On (Simple)", s.always_on, 1)
    ImGui.SameLine()
    _, s.always_on = ImGui.RadioButton("Always On (Advanced)", s.always_on, 2)
    if s.always_on == 1 then
        ImGui.SetTooltip("I am following you around.")
    elseif s.always_on == 2 and ImGui.BeginTooltip() then
        ImGui.ProgressBar(math.sin(ImGui.GetTime()) * 0.5 + 0.5, ImVec2(ImGui.GetFontSize() * 25, 0.0))
        ImGui.EndTooltip()
    end

    ImGui.SeparatorText("Custom")
    HelpMarker("Passing ImGuiHoveredFlags_ForTooltip to IsItemHovered() is the preferred way to standardize tooltip activation details across your application. You may however decide to use custom flags for a specific tooltip instance.")
    ImGui.Button("Manual", sz)
    if ImGui.IsItemHovered(HF.ForTooltip) then ImGui.SetTooltip("I am a manually emitted tooltip.") end
    ImGui.Button("DelayNone", sz)
    if ImGui.IsItemHovered(HF.DelayNone) then ImGui.SetTooltip("I am a tooltip with no delay.") end
    ImGui.Button("DelayShort", sz)
    if ImGui.IsItemHovered(bit32.bor(HF.DelayShort, HF.NoSharedDelay)) then ImGui.SetTooltip("I am a tooltip with a short delay (%0.2f sec).", ImGui.GetStyle().HoverDelayShort) end
    ImGui.Button("DelayLong", sz)
    if ImGui.IsItemHovered(bit32.bor(HF.DelayNormal, HF.NoSharedDelay)) then ImGui.SetTooltip("I am a tooltip with a long delay (%0.2f sec).", ImGui.GetStyle().HoverDelayNormal) end
    ImGui.Button("Stationary", sz)
    if ImGui.IsItemHovered(HF.Stationary) then ImGui.SetTooltip("I am a tooltip requiring mouse to be stationary before activating.") end
    ImGui.BeginDisabled()
    ImGui.Button("Disabled item", sz)
    if ImGui.IsItemHovered(HF.ForTooltip) then ImGui.SetTooltip("I am a tooltip for a disabled item.") end
    ImGui.EndDisabled()
    ImGui.TreePop()
end

S.tn = { lines_flags = bit32.bor(ImGuiTreeNodeFlags.DrawLinesFull, ImGuiTreeNodeFlags.DefaultOpen), selection_mask = 0,
    adv_flags = bit32.bor(ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick, ImGuiTreeNodeFlags.SpanAvailWidth),
    align_label = false, use_dnd = false }
function DemoWindowWidgetsTreeNodes()
    if not ImGui.TreeNode("Tree Nodes") then return end
    local s = S.tn
    local TN = ImGuiTreeNodeFlags
    if ImGui.TreeNode("Basic Trees") then
        for i = 0, 4 do
            if i == 0 then ImGui.SetNextItemOpen(true, ImGuiCond.Once) end
            ImGui.PushID(i)
            if ImGui.TreeNode("", "Child %d", i) then
                ImGui.Text("blah blah")
                ImGui.SameLine()
                if ImGui.SmallButton("button") then end
                ImGui.TreePop()
            end
            ImGui.PopID()
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Hierarchy Lines") then
        HelpMarker("Default option for DrawLinesXXX is stored in style.TreeLinesFlags")
        _, s.lines_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesNone", s.lines_flags, TN.DrawLinesNone)
        _, s.lines_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesFull", s.lines_flags, TN.DrawLinesFull)
        _, s.lines_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesToNodes", s.lines_flags, TN.DrawLinesToNodes)
        local f = s.lines_flags
        if ImGui.TreeNodeEx("Parent", f) then
            if ImGui.TreeNodeEx("Child 1", f) then ImGui.Button("Button for Child 1"); ImGui.TreePop() end
            if ImGui.TreeNodeEx("Child 2", f) then ImGui.Button("Button for Child 2"); ImGui.TreePop() end
            ImGui.Text("Remaining contents")
            ImGui.Text("Remaining contents")
            ImGui.TreePop()
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Clipping Large Trees") then
        ImGui.TextWrapped("- Using ImGuiListClipper with trees is a less easy than on arrays or grids.\n- Refer to 'Demo->Examples->Property Editor' for an example of how to do that.\n- Discuss in #3823")
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Selectable Nodes") then
        HelpMarker("Manually implemented selectable nodes.\nClick to select, Ctrl+Click to toggle, click on arrows or double-click to open.")
        local node_clicked_idx = -1
        for node_n = 0, 5 do
            local flags = bit32.bor(TN.OpenOnArrow, TN.OpenOnDoubleClick, TN.SpanAvailWidth)
            if bit32.band(s.selection_mask, bit32.lshift(1, node_n)) ~= 0 then flags = bit32.bor(flags, TN.Selected) end
            local is_open = ImGui.TreeNodeEx(node_n, flags, "Selectable Node %d", node_n)
            if ImGui.IsItemClicked() and not ImGui.IsItemToggledOpen() then node_clicked_idx = node_n end
            if is_open then
                ImGui.BulletText("<Node contents here>")
                ImGui.TreePop()
            end
        end
        if node_clicked_idx ~= -1 then
            if ImGui.GetIO().KeyCtrl then
                s.selection_mask = bit32.bxor(s.selection_mask, bit32.lshift(1, node_clicked_idx))
            else
                s.selection_mask = bit32.lshift(1, node_clicked_idx)
            end
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Advanced") then
        local function FB(name, help)
            _, s.adv_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_" .. name, s.adv_flags, TN[name])
            if help then ImGui.SameLine(); HelpMarker(help) end
        end
        FB("OpenOnArrow"); FB("OpenOnDoubleClick")
        FB("SpanAvailWidth", "Extend hit area to all available width instead of allowing more items to be laid out after the node.")
        FB("SpanFullWidth")
        FB("SpanLabelWidth", "Reduce hit area to the text label and a bit of margin.")
        FB("SpanAllColumns", "For use in Tables only.")
        FB("AllowOverlap")
        FB("Framed", "Draw frame with background (e.g. for CollapsingHeader)")
        FB("FramePadding"); FB("NavLeftJumpsToParent")
        HelpMarker("Default option for DrawLinesXXX is stored in style.TreeLinesFlags")
        FB("DrawLinesNone"); FB("DrawLinesFull"); FB("DrawLinesToNodes")
        _, s.align_label = ImGui.Checkbox("Align label with current X position", s.align_label)
        _, s.use_dnd = ImGui.Checkbox("Make Tree Nodes as drag & drop sources", s.use_dnd)
        if s.align_label then ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing()) end
        for node_n = 0, 5 do
            local node_flags = s.adv_flags
            if node_n < 3 then
                local is_open = ImGui.TreeNodeEx(node_n, node_flags, "Selectable Node %d", node_n)
                if s.use_dnd and ImGui.BeginDragDropSource() then
                    ImGui.SetDragDropPayload("MY_TREENODE_PAYLOAD_TYPE", nil, 0)
                    ImGui.Text("This is a drag and drop source")
                    ImGui.EndDragDropSource()
                end
                if node_n == 2 and bit32.band(s.adv_flags, TN.SpanLabelWidth) ~= 0 then
                    ImGui.SameLine()
                    if ImGui.SmallButton("button") then end
                end
                if is_open then
                    ImGui.BulletText("Blah blah\nBlah Blah")
                    ImGui.SameLine()
                    ImGui.SmallButton("Button")
                    ImGui.TreePop()
                end
            else
                node_flags = bit32.bor(node_flags, TN.Leaf, TN.NoTreePushOnOpen)
                ImGui.TreeNodeEx(node_n, node_flags, "Selectable Leaf %d", node_n)
                if s.use_dnd and ImGui.BeginDragDropSource() then
                    ImGui.SetDragDropPayload("MY_TREENODE_PAYLOAD_TYPE", nil, 0)
                    ImGui.Text("This is a drag and drop source")
                    ImGui.EndDragDropSource()
                end
            end
        end
        if s.align_label then ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing()) end
        ImGui.TreePop()
    end
    ImGui.TreePop()
end

S.vs = { int_value = 0, values = { 0.0, 0.60, 0.35, 0.9, 0.70, 0.20, 0.0 }, values2 = { 0.20, 0.80, 0.40, 0.25 } }
function DemoWindowWidgetsVerticalSliders()
    if not ImGui.TreeNode("Vertical Sliders") then return end
    local s = S.vs
    local spacing = 4
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(spacing, spacing))
    s.int_value = ImGui.VSliderInt("##int", ImVec2(18, 160), s.int_value, 0, 5)
    ImGui.SameLine()
    local values = s.values
    ImGui.PushID("set1")
    for i = 0, 6 do
        if i > 0 then ImGui.SameLine() end
        ImGui.PushID(i)
        ImGui.PushStyleColor(ImGuiCol.FrameBg, HSV(i / 7.0, 0.5, 0.5))
        ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, HSV(i / 7.0, 0.6, 0.5))
        ImGui.PushStyleColor(ImGuiCol.FrameBgActive, HSV(i / 7.0, 0.7, 0.5))
        ImGui.PushStyleColor(ImGuiCol.SliderGrab, HSV(i / 7.0, 0.9, 0.9))
        values[i + 1] = ImGui.VSliderFloat("##v", ImVec2(18, 160), values[i + 1], 0.0, 1.0, "")
        if ImGui.IsItemActive() or ImGui.IsItemHovered() then ImGui.SetTooltip("%.3f", values[i + 1]) end
        ImGui.PopStyleColor(4)
        ImGui.PopID()
    end
    ImGui.PopID()

    ImGui.SameLine()
    ImGui.PushID("set2")
    local rows = 3
    local small_slider_size = ImVec2(18, math.floor((160.0 - (rows - 1) * spacing) / rows))
    for nx = 0, 3 do
        if nx > 0 then ImGui.SameLine() end
        ImGui.BeginGroup()
        for ny = 0, rows - 1 do
            ImGui.PushID(nx * rows + ny)
            s.values2[nx + 1] = ImGui.VSliderFloat("##v", small_slider_size, s.values2[nx + 1], 0.0, 1.0, "")
            if ImGui.IsItemActive() or ImGui.IsItemHovered() then ImGui.SetTooltip("%.3f", s.values2[nx + 1]) end
            ImGui.PopID()
        end
        ImGui.EndGroup()
    end
    ImGui.PopID()

    ImGui.SameLine()
    ImGui.PushID("set3")
    for i = 0, 3 do
        if i > 0 then ImGui.SameLine() end
        ImGui.PushID(i)
        ImGui.PushStyleVar(ImGuiStyleVar.GrabMinSize, 40)
        values[i + 1] = ImGui.VSliderFloat("##v", ImVec2(40, 160), values[i + 1], 0.0, 1.0, "%.2f\nsec")
        ImGui.PopStyleVar()
        ImGui.PopID()
    end
    ImGui.PopID()
    ImGui.PopStyleVar()
    ImGui.TreePop()
end

----------------------------------------------------------------
-- [SECTION] Example App: Main Menu Bar / ShowExampleAppMainMenuBar()
----------------------------------------------------------------

S.menu = { enabled = true, f = 0.5, n = 0, b = true }
function ShowExampleMenuFile()
    local s = S.menu
    ImGui.MenuItem("(demo menu)", nil, false, false)
    if ImGui.MenuItem("New") then end
    if ImGui.MenuItem("Open", "Ctrl+O") then end
    if ImGui.BeginMenu("Open Recent") then
        ImGui.MenuItem("fish_hat.c")
        ImGui.MenuItem("fish_hat.inl")
        ImGui.MenuItem("fish_hat.h")
        if ImGui.BeginMenu("More..") then
            ImGui.MenuItem("Hello")
            ImGui.MenuItem("Sailor")
            if ImGui.BeginMenu("Recurse..") then
                ShowExampleMenuFile()
                ImGui.EndMenu()
            end
            ImGui.EndMenu()
        end
        ImGui.EndMenu()
    end
    if ImGui.MenuItem("Save", "Ctrl+S") then end
    if ImGui.MenuItem("Save As..") then end

    ImGui.Separator()
    if ImGui.BeginMenu("Options") then
        _, s.enabled = ImGui.MenuItem("Enabled", "", s.enabled)
        ImGui.BeginChild("child", ImVec2(0, ImGui.GetTextLineHeightWithSpacing() * 5.0), ImGuiChildFlags.Borders)
        for i = 0, 9 do ImGui.Text("Scrolling Text %d", i) end
        ImGui.EndChild()
        s.f = ImGui.SliderFloat("Value", s.f, 0.0, 1.0)
        s.f = ImGui.InputFloat("Input", s.f, 0.1)
        s.n = ImGui.Combo("Combo", s.n, "Yes\0No\0Maybe\0\0")
        ImGui.EndMenu()
    end

    if ImGui.BeginMenu("Colors") then
        local sz = ImGui.GetTextLineHeight()
        for i = 0, ImGuiCol.COUNT - 1 do
            local name = ImGui.GetStyleColorName(i)
            local p = ImGui.GetCursorScreenPos()
            ImGui.GetWindowDrawList():AddRectFilled(p, ImVec2(p.x + sz, p.y + sz), ImGui.GetColorU32(i))
            ImGui.Dummy(ImVec2(sz, sz))
            ImGui.SameLine()
            ImGui.MenuItem(name)
        end
        ImGui.EndMenu()
    end

    -- Here we demonstrate appending again to the "Options" menu (which we already created above)
    if ImGui.BeginMenu("Options") then
        _, s.b = ImGui.Checkbox("SomeOption", s.b)
        ImGui.EndMenu()
    end

    if ImGui.BeginMenu("Disabled", false) then
        IM_ASSERT(false)
    end
    if ImGui.MenuItem("Checked", nil, true) then end
    ImGui.Separator()
    if ImGui.MenuItem("Quit", "Alt+F4") then end
end

function ShowExampleAppMainMenuBar()
    if ImGui.BeginMainMenuBar() then
        if ImGui.BeginMenu("File") then
            ShowExampleMenuFile()
            ImGui.EndMenu()
        end
        if ImGui.BeginMenu("Edit") then
            if ImGui.MenuItem("Undo", "Ctrl+Z") then end
            if ImGui.MenuItem("Redo", "Ctrl+Y", false, false) then end
            ImGui.Separator()
            if ImGui.MenuItem("Cut", "Ctrl+X") then end
            if ImGui.MenuItem("Copy", "Ctrl+C") then end
            if ImGui.MenuItem("Paste", "Ctrl+V") then end
            ImGui.EndMenu()
        end
        ImGui.EndMainMenuBar()
    end
end

----------------------------------------------------------------
-- [SECTION] Style Editor / ShowStyleEditor()
----------------------------------------------------------------

-- Deep copy of an ImGuiStyle (ImVec2/ImVec4 fields and Colors[] are copied by value)
local function StyleCopy(dst, src)
    for k, v in pairs(src) do
        if k == "Colors" then
            dst.Colors = dst.Colors or {}
            for i, c in pairs(v) do
                if type(c) == "table" then dst.Colors[i] = dst.Colors[i] or ImVec4(); ImVec4_Copy(dst.Colors[i], c) else dst.Colors[i] = c end
            end
        elseif type(v) == "table" and getmetatable(v) ~= nil and type(v[1]) == "number" then
            local c = dst[k]
            if type(c) ~= "table" then c = setmetatable({}, getmetatable(v)); dst[k] = c end
            for _, key in ipairs({ "x", "y", "z", "w" }) do if rawget(v, key) ~= nil then rawset(c, key, rawget(v, key)) end end
        else
            dst[k] = v
        end
    end
    if getmetatable(dst) == nil then setmetatable(dst, getmetatable(src)) end
    return dst
end

local function ColorsEqual(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] end

S.ss = { style_idx = -1 }
function ImGui.ShowStyleSelector(label)
    local s = S.ss
    local style_names = { "Dark", "Light", "Classic" }
    local ret = false
    if ImGui.BeginCombo(label, style_names[s.style_idx + 1] or "") then
        for n = 0, 2 do
            if ImGui.Selectable(style_names[n + 1], s.style_idx == n, ImGuiSelectableFlags.SelectOnNav) then
                s.style_idx = n
                ret = true
                if n == 0 then ImGui.StyleColorsDark() elseif n == 1 then ImGui.StyleColorsLight() else ImGui.StyleColorsClassic() end
            elseif s.style_idx == n then
                ImGui.SetItemDefaultFocus()
            end
        end
        ImGui.EndCombo()
    end
    return ret
end

local function GetTreeLinesFlagsName(flags)
    local TN = ImGuiTreeNodeFlags
    if flags == TN.DrawLinesNone then return "DrawLinesNone" end
    if flags == TN.DrawLinesFull then return "DrawLinesFull" end
    if flags == TN.DrawLinesToNodes then return "DrawLinesToNodes" end
    return ""
end

S.se = { ref_saved_style = nil, init = true, output_dest = 0, output_only_modified = true, alpha_flags = 0, filter = nil }
function ImGui.ShowStyleEditor(ref)
    local se = S.se
    local style = ImGui.GetStyle()
    if se.ref_saved_style == nil then se.ref_saved_style = {} end
    if se.init and ref == nil then StyleCopy(se.ref_saved_style, style) end
    se.init = false
    if ref == nil then ref = se.ref_saved_style end

    local default_border_size = math.floor(style._MainScale or 1.0)
    local max_border_size = math.max(default_border_size, 2.0)
    local function SF(name, mn, mx, fmt) if style[name] ~= nil then style[name] = ImGui.SliderFloat(name, style[name], mn, mx, fmt or "%.0f") end end
    local function SF2(name, mn, mx, fmt) if style[name] ~= nil then ImGui.SliderFloat2(name, style[name], mn, mx, fmt or "%.0f") end end
    local function DF(name, speed, mn, mx, fmt, flags) if style[name] ~= nil then style[name] = ImGui.DragFloat(name, style[name], speed, mn, mx, fmt or "%.0f", flags) end end

    ImGui.PushItemWidth(ImGui.GetWindowWidth() * 0.50)

    ImGui.SeparatorText("General")
    if bit32.band(ImGui.GetIO().BackendFlags, ImGuiBackendFlags.RendererHasTextures) == 0 then
        ImGui.BulletText("Warning: Font scaling will NOT be smooth, because\nImGuiBackendFlags_RendererHasTextures is not set!")
        ImGui.BulletText("For instructions, see:")
        ImGui.SameLine()
        ImGui.TextLinkOpenURL("docs/BACKENDS.md", "https://github.com/ocornut/imgui/blob/master/docs/BACKENDS.md")
    end
    if ImGui.ShowStyleSelector("Colors##Selector") then StyleCopy(se.ref_saved_style, style) end
    if ImGui.ShowFontSelector then ImGui.ShowFontSelector("Fonts##Selector") end
    local changed
    style.FontSizeBase, changed = ImGui.DragFloat("FontSizeBase", style.FontSizeBase, 0.20, 5.0, 100.0, "%.0f")
    if changed then style._NextFrameFontSizeBase = style.FontSizeBase end
    ImGui.SameLine(0.0, 0.0); ImGui.Text(" (out %.2f)", ImGui.GetFontSize())
    style.FontScaleMain = ImGui.DragFloat("FontScaleMain", style.FontScaleMain, 0.02, 0.5, 4.0)
    ImGui.BeginDisabled(ImGui.GetIO().ConfigDpiScaleFonts == true)
    style.FontScaleDpi = ImGui.DragFloat("FontScaleDpi", style.FontScaleDpi, 0.02, 0.5, 4.0)
    ImGui.SetItemTooltip("When io.ConfigDpiScaleFonts is set, this value is automatically overwritten.")
    ImGui.EndDisabled()

    style.FrameRounding, changed = ImGui.SliderFloat("FrameRounding", style.FrameRounding, 0.0, 12.0, "%.0f")
    if changed then style.GrabRounding = style.FrameRounding end
    local p, border
    p, border = ImGui.Checkbox("WindowBorder", style.WindowBorderSize > 0.0); if p then style.WindowBorderSize = border and default_border_size or 0.0 end
    ImGui.SameLine()
    p, border = ImGui.Checkbox("FrameBorder", style.FrameBorderSize > 0.0); if p then style.FrameBorderSize = border and default_border_size or 0.0 end
    ImGui.SameLine()
    p, border = ImGui.Checkbox("PopupBorder", style.PopupBorderSize > 0.0); if p then style.PopupBorderSize = border and default_border_size or 0.0 end

    if ImGui.Button("Save Ref") then StyleCopy(se.ref_saved_style, style); if ref ~= se.ref_saved_style then StyleCopy(ref, style) end end
    ImGui.SameLine()
    if ImGui.Button("Revert Ref") then StyleCopy(style, ref) end
    ImGui.SameLine()
    HelpMarker("Save/Revert in local non-persistent storage. Default Colors definition are not affected. Use \"Export\" below to save them somewhere.")

    ImGui.SeparatorText("Details")
    if ImGui.BeginTabBar("##tabs", ImGuiTabBarFlags.None) then
        if ImGui.BeginTabItem("Sizes") then
            ImGui.SeparatorText("Main")
            SF2("WindowPadding", 0.0, 20.0); SF2("FramePadding", 0.0, 20.0); SF2("ItemSpacing", 0.0, 20.0)
            SF2("ItemInnerSpacing", 0.0, 20.0); SF2("TouchExtraPadding", 0.0, 10.0)
            SF("IndentSpacing", 0.0, 30.0); SF("GrabMinSize", 1.0, 20.0)

            ImGui.SeparatorText("Borders")
            SF("WindowBorderSize", 0.0, max_border_size); SF("ChildBorderSize", 0.0, max_border_size)
            SF("PopupBorderSize", 0.0, max_border_size); SF("FrameBorderSize", 0.0, max_border_size)

            ImGui.SeparatorText("Rounding")
            SF("WindowRounding", 0.0, 12.0); SF("ChildRounding", 0.0, 12.0); SF("FrameRounding", 0.0, 12.0)
            SF("PopupRounding", 0.0, 12.0); SF("GrabRounding", 0.0, 12.0); SF("MenuItemRounding", 0.0, 12.0)

            ImGui.SeparatorText("Scrollbar")
            SF("ScrollbarSize", 1.0, 20.0); SF("ScrollbarRounding", 0.0, 12.0); SF("ScrollbarPadding", 0.0, 10.0)

            ImGui.SeparatorText("Tabs")
            SF("TabBorderSize", 0.0, max_border_size); SF("TabBarBorderSize", 0.0, max_border_size)
            SF("TabBarOverlineSize", 0.0, math.max(3.0, max_border_size))
            ImGui.SameLine(); HelpMarker("Overline is only drawn over the selected tab when ImGuiTabBarFlags_DrawSelectedOverline is set.")
            DF("TabMinWidthBase", 0.5, 1.0, 500.0); DF("TabMinWidthShrink", 0.5, 1.0, 500.0, "%0.f")
            if style.TabCloseButtonMinWidthSelected ~= nil then
                DF("TabCloseButtonMinWidthSelected", 0.5, -1.0, 100.0, (style.TabCloseButtonMinWidthSelected < 0.0) and "%.0f (Always)" or "%.0f")
                DF("TabCloseButtonMinWidthUnselected", 0.5, -1.0, 100.0, (style.TabCloseButtonMinWidthUnselected < 0.0) and "%.0f (Always)" or "%.0f")
            end
            SF("TabRounding", 0.0, 12.0)

            ImGui.SeparatorText("Tables")
            SF2("CellPadding", 0.0, 20.0)
            style.TableAngledHeadersAngle = ImGui.SliderAngle("TableAngledHeadersAngle", style.TableAngledHeadersAngle, -50.0, 50.0)
            SF2("TableAngledHeadersTextAlign", 0.0, 1.0, "%.2f")

            ImGui.SeparatorText("Trees")
            local combo_open = ImGui.BeginCombo("TreeLinesFlags", GetTreeLinesFlagsName(style.TreeLinesFlags))
            ImGui.SameLine()
            HelpMarker("[Experimental] Tree lines may not work in all situations (e.g. using a clipper) and may incurs slight traversal overhead.\n\nImGuiTreeNodeFlags_DrawLinesFull is faster than ImGuiTreeNodeFlags_DrawLinesToNode.")
            if combo_open then
                local TN = ImGuiTreeNodeFlags
                for _, option in ipairs({ TN.DrawLinesNone, TN.DrawLinesFull, TN.DrawLinesToNodes }) do
                    if ImGui.Selectable(GetTreeLinesFlagsName(option), style.TreeLinesFlags == option) then style.TreeLinesFlags = option end
                end
                ImGui.EndCombo()
            end
            SF("TreeLinesSize", 0.0, max_border_size); SF("TreeLinesRounding", 0.0, 12.0)

            ImGui.SeparatorText("Windows")
            SF2("WindowTitleAlign", 0.0, 1.0, "%.2f"); SF("WindowBorderHoverPadding", 1.0, 20.0)
            local window_menu_button_position = style.WindowMenuButtonPosition + 1
            window_menu_button_position, changed = ImGui.Combo("WindowMenuButtonPosition", window_menu_button_position, "None\0Left\0Right\0")
            if changed then style.WindowMenuButtonPosition = window_menu_button_position - 1 end

            ImGui.SeparatorText("Widgets")
            SF("ColorMarkerSize", 0.0, 8.0)
            style.ColorButtonPosition = ImGui.Combo("ColorButtonPosition", style.ColorButtonPosition, "Left\0Right\0")
            SF2("ButtonTextAlign", 0.0, 1.0, "%.2f")
            ImGui.SameLine(); HelpMarker("Alignment applies when a button is larger than its text content.")
            SF2("SelectableTextAlign", 0.0, 1.0, "%.2f")
            ImGui.SameLine(); HelpMarker("Alignment applies when a selectable is larger than its text content.")
            SF("SeparatorSize", 0.0, 10.0); SF("SeparatorTextBorderSize", 0.0, 10.0)
            SF2("SeparatorTextAlign", 0.0, 1.0, "%.2f"); SF2("SeparatorTextPadding", 0.0, 40.0)
            SF("LogSliderDeadzone", 0.0, 12.0); SF("ImageRounding", 0.0, 12.0); SF("ImageBorderSize", 0.0, max_border_size)

            ImGui.SeparatorText("Docking")
            _, style.DockingNodeHasCloseButton = ImGui.Checkbox("DockingNodeHasCloseButton", style.DockingNodeHasCloseButton)
            SF("DockingSeparatorSize", 0.0, 12.0)

            ImGui.SeparatorText("Tooltips")
            for n = 0, 1 do
                local key = (n == 0) and "HoverFlagsForTooltipMouse" or "HoverFlagsForTooltipNav"
                if ImGui.TreeNodeEx(key) then
                    for _, f in ipairs({ "DelayNone", "DelayShort", "DelayNormal", "Stationary", "NoSharedDelay" }) do
                        _, style[key] = ImGui.CheckboxFlags("ImGuiHoveredFlags_" .. f, style[key], ImGuiHoveredFlags[f])
                    end
                    ImGui.TreePop()
                end
            end

            ImGui.SeparatorText("Misc")
            SF2("DisplayWindowPadding", 0.0, 30.0); ImGui.SameLine(); HelpMarker("Apply to regular windows: amount which we enforce to keep visible when moving near edges of your screen.")
            SF2("DisplaySafeAreaPadding", 0.0, 30.0); ImGui.SameLine(); HelpMarker("Apply to every windows, menus, popups, tooltips: amount where we avoid displaying contents. Adjust if you cannot see the edges of your screen (e.g. on a TV where scaling has not been configured).")
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Colors") then
            if ImGui.Button("Export") then
                if se.output_dest == 0 then ImGui.LogToClipboard() else ImGui.LogToTTY() end
                ImGui.LogText("ImVec4* colors = GetStyle().Colors;\n")
                for i = 0, ImGuiCol.COUNT - 1 do
                    local col = style.Colors[i]
                    local name = ImGui.GetStyleColorName(i)
                    if not se.output_only_modified or not ColorsEqual(col, ref.Colors[i]) then
                        ImGui.LogText("colors[ImGuiCol_%s]%s= ImVec4(%.2ff, %.2ff, %.2ff, %.2ff);\n", name, string.rep(" ", math.max(0, 23 - #name)), col.x, col.y, col.z, col.w)
                    end
                end
                ImGui.LogFinish()
            end
            ImGui.SameLine(); ImGui.SetNextItemWidth(ImGui.GetFontSize() * 10)
            se.output_dest = ImGui.Combo("##output_type", se.output_dest, "To Clipboard\0To TTY\0")
            ImGui.SameLine(); _, se.output_only_modified = ImGui.Checkbox("Only Modified Colors", se.output_only_modified)

            local CE = ImGuiColorEditFlags
            if ImGui.RadioButtonEx("Opaque", se.alpha_flags == CE.AlphaOpaque) then se.alpha_flags = CE.AlphaOpaque end ImGui.SameLine()
            if ImGui.RadioButtonEx("Alpha", se.alpha_flags == CE.None) then se.alpha_flags = CE.None end ImGui.SameLine()
            if ImGui.RadioButtonEx("Both", se.alpha_flags == CE.AlphaPreviewHalf) then se.alpha_flags = CE.AlphaPreviewHalf end ImGui.SameLine()
            HelpMarker("In the color list:\nLeft-click on color square to open color picker,\nRight-click to open edit options menu.")

            se.filter = se.filter or ImGuiTextFilter()
            ImGui.SetNextItemWidth(-FLT_MIN)
            se.filter:DrawWithHint("##FilterColors", "Filter Colors (incl -excl)")

            ImGui.SetNextWindowSizeConstraints(ImVec2(0.0, ImGui.GetTextLineHeightWithSpacing() * 10), ImVec2(FLT_MAX, FLT_MAX))
            ImGui.BeginChild("##colors", ImVec2(0, 0), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.NavFlattened), bit32.bor(ImGuiWindowFlags.AlwaysVerticalScrollbar, ImGuiWindowFlags.AlwaysHorizontalScrollbar))
            ImGui.PushItemWidth(ImGui.GetFontSize() * -12)
            -- [Luau] clipped: only visible rows are submitted (upstream submits every color)
            local visible_cols = {}
            for i = 0, ImGuiCol.COUNT - 1 do
                if se.filter:PassFilter(ImGui.GetStyleColorName(i)) then visible_cols[#visible_cols + 1] = i end
            end
            local clipper = ImGuiListClipper()
            clipper:Begin(#visible_cols)
            while clipper:Step() do for row = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                local i = visible_cols[row + 1]
                local name = ImGui.GetStyleColorName(i)
                do
                    ImGui.PushID(i)
                    if ImGui.DebugFlashStyleColor then
                        if ImGui.Button("?") then ImGui.DebugFlashStyleColor(i) end
                        ImGui.SetItemTooltip("Flash given color to identify places where it is used.")
                        ImGui.SameLine()
                    end
                    ImGui.ColorEdit4("##color", style.Colors[i], bit32.bor(CE.AlphaBar, se.alpha_flags))
                    if not ColorsEqual(style.Colors[i], ref.Colors[i]) then
                        ImGui.SameLine(0.0, style.ItemInnerSpacing.x); if ImGui.Button("Save") then ImVec4_Copy(ref.Colors[i], style.Colors[i]) end
                        ImGui.SameLine(0.0, style.ItemInnerSpacing.x); if ImGui.Button("Revert") then ImVec4_Copy(style.Colors[i], ref.Colors[i]) end
                    end
                    ImGui.SameLine(0.0, style.ItemInnerSpacing.x)
                    ImGui.TextUnformatted(name)
                    ImGui.PopID()
                end
            end end
            clipper:End()
            ImGui.PopItemWidth()
            ImGui.EndChild()
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Fonts") then
            if ImGui.ShowFontAtlas then ImGui.ShowFontAtlas(ImGui.GetIO().Fonts) else DemoNotPorted("ShowFontAtlas") end
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Rendering") then
            _, style.AntiAliasedLines = ImGui.Checkbox("Anti-aliased lines", style.AntiAliasedLines)
            ImGui.SameLine()
            HelpMarker("When disabling anti-aliasing lines, you'll probably want to disable borders in your style as well.")
            ImGui.BeginDisabled(style.AntiAliasedLines == false)
            _, style.AntiAliasedLineEnds = ImGui.Checkbox("Anti-aliased line ends", style.AntiAliasedLineEnds)
            ImGui.EndDisabled()
            _, style.AntiAliasedFill = ImGui.Checkbox("Anti-aliased fill", style.AntiAliasedFill)
            local io = ImGui.GetIO()
            _, io.ConfigDebugDrawListDefaultsToStrokeLegacy = ImGui.Checkbox("Debug: DrawList Defaults to _StrokeLegacy", io.ConfigDebugDrawListDefaultsToStrokeLegacy == true)

            ImGui.PushItemWidth(ImGui.GetFontSize() * 8)
            -- [port] library still stores the pre-1.93 CurveTessellationTol (== MaxError * MaxError)
            local curve_err = ImGui.DragFloat("Curve Tessellation Max Error", math.sqrt(style.CurveTessellationTol), 0.02, 0.10, 10.0, "%.2f")
            if curve_err < 0.10 then curve_err = 0.10 end
            style.CurveTessellationTol = curve_err * curve_err

            style.CircleTessellationMaxError = ImGui.DragFloat("Circle Tessellation Max Error", style.CircleTessellationMaxError, 0.005, 0.10, 5.0, "%.2f", ImGuiSliderFlags.AlwaysClamp)
            local show_samples = ImGui.IsItemActive()
            if show_samples then ImGui.SetNextWindowPos(ImGui.GetCursorScreenPos()) end
            if show_samples and ImGui.BeginTooltip() then
                ImGui.TextUnformatted("(R = radius, N = approx number of segments)")
                ImGui.Spacing()
                local draw_list = ImGui.GetWindowDrawList()
                local min_widget_width = ImGui.CalcTextSize("R: MMM\nN: MMM").x
                for n = 0, 7 do
                    local RAD_MIN, RAD_MAX = 5.0, 70.0
                    local rad = RAD_MIN + (RAD_MAX - RAD_MIN) * n / (8.0 - 1.0)
                    ImGui.BeginGroup()
                    ImGui.Text("R: %.f\nN: %d", rad, draw_list:_CalcCircleAutoSegmentCount(rad))
                    local canvas_width = math.max(min_widget_width, rad * 2.0)
                    local offset_x = math.floor(canvas_width * 0.5)
                    local offset_y = math.floor(RAD_MAX)
                    local p1 = ImGui.GetCursorScreenPos()
                    draw_list:AddCircle(ImVec2(p1.x + offset_x, p1.y + offset_y), rad, ImGui.GetColorU32(ImGuiCol.Text))
                    ImGui.Dummy(ImVec2(canvas_width, RAD_MAX * 2))
                    ImGui.EndGroup()
                    ImGui.SameLine()
                end
                ImGui.EndTooltip()
            end
            ImGui.SameLine()
            HelpMarker("When drawing circle primitives with \"num_segments == 0\" tessellation will be calculated automatically.")
            style.Alpha = ImGui.DragFloat("Global Alpha", style.Alpha, 0.005, 0.20, 1.0, "%.2f")
            style.DisabledAlpha = ImGui.DragFloat("Disabled Alpha", style.DisabledAlpha, 0.005, 0.0, 1.0, "%.2f")
            ImGui.SameLine(); HelpMarker("Additional alpha multiplier for disabled items (multiply over current value of Alpha).")
            ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
    ImGui.PopItemWidth()
end

return true
