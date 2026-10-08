--- ImGui Sincerely WIP
-- (Demo Code, part 2): DemoWindowLayout(), DemoWindowPopups(), DemoWindowTables(), DemoWindowColumns(),
-- DemoWindowInputs() and all ShowExampleAppXXX() example apps.
-- Port of imgui_demo.cpp (docking branch). Globals are shared with imgui_demo.lua (HelpMarker, ShowExampleMenuFile, ...)

local IM_MIN = math.min
local IM_MAX = math.max
local function IM_CLAMP(V, MN, MX) return (V < MN) and MN or (V > MX) and MX or V end
local _
local function IMGUI_DEMO_MARKER(_) end -- upstream hook, no-op here

--- `char buf[size] = "str"` -> zero-terminated byte table
local function Buf(str, size)
    local t = {}
    for i = 1, #str do t[i] = string.byte(str, i) end
    t[#str + 1] = 0
    if size then for i = #str + 2, size do t[i] = 0 end end
    return t
end
--- byte table -> Lua string (up to the zero terminator)
local function BufStr(buf)
    local n = 0
    while buf[n + 1] ~= nil and buf[n + 1] ~= 0 do n = n + 1 end
    return ImGui._ByteArrayToString(buf, 1, n + 1)
end
local function BufSet(buf, str)
    for i = 1, #str do buf[i] = string.byte(str, i) end
    buf[#str + 1] = 0
end

--- ImColor::HSV() as ImVec4
local function HSV(h, s, v, a)
    local r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
    return ImVec4(r, g, b, a or 1.0)
end
local function B2I(b) return b and 1 or 0 end

local function Has(flags, f) return bit32.band(flags, f) ~= 0 end
local function NotSupported() ImGui.TextDisabled("(not supported on Roblox)") end
local function NotPorted(what) ImGui.TextDisabled("(not ported yet%s)", what and (": " .. what) or "") end

local function DemoHelpMarker(desc)
    if HelpMarker then HelpMarker(desc) return end
    ImGui.TextDisabled("(?)")
    if ImGui.BeginItemTooltip() then
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
        ImGui.TextUnformatted(desc)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end
local function DemoMenuFile() if ShowExampleMenuFile then ShowExampleMenuFile() end end

--- Minimal ImGuiTextFilter stand-in when the library one isn't available
local function MakeTextFilter()
    if ImGuiTextFilter then return ImGuiTextFilter() end
    local f = { InputBuf = Buf("", 256) }
    function f:Draw(label, width)
        if width and width ~= 0 then ImGui.SetNextItemWidth(width) end
        return ImGui.InputText(label or "Filter (inc,-exc)", self.InputBuf, 256)
    end
    function f:IsActive() return self.InputBuf[1] ~= 0 end
    function f:Clear() self.InputBuf[1] = 0 end
    function f:Build() end
    function f:PassFilter(text, text_end)
        if text_end then text = string.sub(text, 1, text_end - 1) end
        local s = BufStr(self.InputBuf)
        if s == "" then return true end
        local any_inc, pass_inc = false, false
        for tok in string.gmatch(s, "[^,]+") do
            tok = string.match(tok, "^%s*(.-)%s*$")
            if tok ~= "" then
                if string.sub(tok, 1, 1) == "-" then
                    if #tok > 1 and string.find(string.lower(text), string.lower(string.sub(tok, 2)), 1, true) then return false end
                else
                    any_inc = true
                    if string.find(string.lower(text), string.lower(tok), 1, true) then pass_inc = true end
                end
            end
        end
        return (not any_inc) or pass_inc
    end
    return f
end

-- ImGuiInputTextCallbackData helpers (the port's callback data has no methods). Buf is a 1-based zero-terminated
-- byte table, positions are 0-based like C++.
local function CB_DeleteChars(data, pos, bytes_count)
    local buf = data.Buf
    local len = data.BufTextLen
    for i = pos + 1, len - bytes_count + 1 do buf[i] = buf[i + bytes_count] end
    for i = len - bytes_count + 2, len + 1 do buf[i] = 0 end
    if data.CursorPos >= pos + bytes_count then data.CursorPos = data.CursorPos - bytes_count
    elseif data.CursorPos >= pos then data.CursorPos = pos end
    data.SelectionStart = data.CursorPos; data.SelectionEnd = data.CursorPos
    data.BufDirty = true
    data.BufTextLen = len - bytes_count
end
local function CB_InsertChars(data, pos, text)
    local n = #text
    if n == 0 then return end
    if data.BufTextLen + n >= data.BufSize then return end
    local buf = data.Buf
    for i = data.BufTextLen + 1, pos + 1, -1 do buf[i + n] = buf[i] end
    for i = 1, n do buf[pos + i] = string.byte(text, i) end
    if data.CursorPos >= pos then data.CursorPos = data.CursorPos + n end
    data.SelectionStart = data.CursorPos; data.SelectionEnd = data.CursorPos
    data.BufDirty = true
    data.BufTextLen = data.BufTextLen + n
end
local function CB_SelectAll(data) data.SelectionStart = 0; data.SelectionEnd = data.BufTextLen end

--- ImGui::BeginChild() wrapper accepting upstream args
local function BeginChild(id, size, child_flags, window_flags)
    return ImGui.BeginChild(id, size or ImVec2(0, 0), child_flags or 0, window_flags or 0)
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowLayout()
-------------------------------------------------------------------------------

local SL = {
    disable_mouse_wheel = false, disable_menu = false,
    draw_lines = 3, max_height_in_lines = 10,
    offset_x = 0, override_bg_color = true, child_flags = nil,
    f = 0.0, show_indented_items = true,
    c1 = false, c2 = false, c3 = false, c4 = false,
    f0 = 1.0, f1 = 2.0, f2 = 3.0, item = -1, selection = { 0, 1, 2, 3 },
    track_item = 50, enable_track = true, enable_extra_decorations = false, scroll_to_off_px = 0.0, scroll_to_pos_px = 200.0,
    lines = 7, show_horizontal_contents_size_demo_window = false,
    show_h_scrollbar = true, show_button = true, show_tree_nodes = true, show_text_wrapped = false, show_columns = true,
    show_tab_bar = true, show_child = false, explicit_content_size = false, contents_size_x = 300.0,
    clip_size = nil, clip_offset = nil,
    enable_allow_overlap = true,
}

local function DemoWindowLayout_ChildWindows()
    IMGUI_DEMO_MARKER("Layout/Child windows")
    ImGui.SeparatorText("Child windows")

    DemoHelpMarker("Use child windows to begin into a self-contained independent scrolling/clipping regions within a host window.")
    _, SL.disable_mouse_wheel = ImGui.Checkbox("Disable Mouse Wheel", SL.disable_mouse_wheel)
    _, SL.disable_menu = ImGui.Checkbox("Disable Menu", SL.disable_menu)

    -- Child 1: no border, enable horizontal scrollbar
    do
        local window_flags = ImGuiWindowFlags.HorizontalScrollbar
        if SL.disable_mouse_wheel then
            window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoScrollWithMouse)
        end
        BeginChild("ChildL", ImVec2(ImGui.GetContentRegionAvail().x * 0.5, 260), ImGuiChildFlags.None, window_flags)
        for i = 0, 99 do
            ImGui.Text("%04d: scrollable region", i)
        end
        ImGui.EndChild()
    end

    ImGui.SameLine()

    -- Child 2: rounded border
    do
        local window_flags = ImGuiWindowFlags.None
        if SL.disable_mouse_wheel then
            window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoScrollWithMouse)
        end
        if not SL.disable_menu then
            window_flags = bit32.bor(window_flags, ImGuiWindowFlags.MenuBar)
        end
        ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, 5.0)
        BeginChild("ChildR", ImVec2(0, 260), ImGuiChildFlags.Borders, window_flags)
        if not SL.disable_menu and ImGui.BeginMenuBar() then
            if ImGui.BeginMenu("Menu") then
                DemoMenuFile()
                ImGui.EndMenu()
            end
            ImGui.EndMenuBar()
        end
        if ImGui.BeginTable("split", 2, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.NoSavedSettings)) then
            for i = 0, 99 do
                local buf = string.format("%03d", i)
                ImGui.TableNextColumn()
                ImGui.Button(buf, ImVec2(-FLT_MIN, 0.0))
            end
            ImGui.EndTable()
        end
        ImGui.EndChild()
        ImGui.PopStyleVar()
    end

    -- Child 3: manual-resize
    ImGui.SeparatorText("Manual-resize")
    do
        DemoHelpMarker("Drag bottom border to resize. Double-click bottom border to auto-fit to vertical contents.")
        ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetStyleColorVec4(ImGuiCol.FrameBg))
        if BeginChild("ResizableChild", ImVec2(-FLT_MIN, ImGui.GetTextLineHeightWithSpacing() * 8), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeY)) then
            for n = 0, 9 do
                ImGui.Text("Line %04d", n)
            end
        end
        ImGui.PopStyleColor()
        ImGui.EndChild()
    end

    -- Child 4: auto-resizing height with a limit
    ImGui.SeparatorText("Auto-resize with constraints")
    do
        ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
        SL.draw_lines = ImGui.DragInt("Lines Count", SL.draw_lines, 0.2)
        ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
        SL.max_height_in_lines = ImGui.DragInt("Max Height (in Lines)", SL.max_height_in_lines, 0.2)

        ImGui.SetNextWindowSizeConstraints(ImVec2(0.0, ImGui.GetTextLineHeightWithSpacing() * 1), ImVec2(FLT_MAX, ImGui.GetTextLineHeightWithSpacing() * SL.max_height_in_lines))
        if BeginChild("ConstrainedChild", ImVec2(-FLT_MIN, 0.0), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.AutoResizeY)) then
            for n = 0, SL.draw_lines - 1 do
                ImGui.Text("Line %04d", n)
            end
        end
        ImGui.EndChild()
    end

    ImGui.SeparatorText("Misc/Advanced")

    do
        if SL.child_flags == nil then SL.child_flags = bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeX, ImGuiChildFlags.ResizeY) end
        ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
        SL.offset_x = ImGui.DragInt("Offset X", SL.offset_x, 1.0, -1000, 1000)
        _, SL.override_bg_color = ImGui.Checkbox("Override ChildBg color", SL.override_bg_color)
        _, SL.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_Borders", SL.child_flags, ImGuiChildFlags.Borders)
        _, SL.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_AlwaysUseWindowPadding", SL.child_flags, ImGuiChildFlags.AlwaysUseWindowPadding)
        _, SL.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_ResizeX", SL.child_flags, ImGuiChildFlags.ResizeX)
        _, SL.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_ResizeY", SL.child_flags, ImGuiChildFlags.ResizeY)
        _, SL.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_FrameStyle", SL.child_flags, ImGuiChildFlags.FrameStyle)
        ImGui.SameLine(); DemoHelpMarker("Style the child window like a framed item: use FrameBg, FrameRounding, FrameBorderSize, FramePadding instead of ChildBg, ChildRounding, ChildBorderSize, WindowPadding.")
        if Has(SL.child_flags, ImGuiChildFlags.FrameStyle) then
            SL.override_bg_color = false
        end

        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + SL.offset_x)
        if SL.override_bg_color then
            ImGui.PushStyleColor(ImGuiCol.ChildBg, IM_COL32(255, 0, 0, 100))
        end
        BeginChild("Red", ImVec2(200, 100), SL.child_flags, ImGuiWindowFlags.None)
        if SL.override_bg_color then
            ImGui.PopStyleColor()
        end

        for n = 0, 49 do
            ImGui.Text("Some test %d", n)
        end
        ImGui.EndChild()
        local child_is_hovered = ImGui.IsItemHovered()
        local child_rect_min = ImGui.GetItemRectMin()
        local child_rect_max = ImGui.GetItemRectMax()
        ImGui.Text("Hovered: %d", B2I(child_is_hovered))
        ImGui.Text("Rect of child window is: (%.0f,%.0f) (%.0f,%.0f)", child_rect_min.x, child_rect_min.y, child_rect_max.x, child_rect_max.y)
    end
end

local function DemoWindowLayout_WidgetsWidth()
    IMGUI_DEMO_MARKER("Layout/Widgets Width")
    _, SL.show_indented_items = ImGui.Checkbox("Show indented items", SL.show_indented_items)

    local function block(text, help, width, l1, l2)
        ImGui.Text(text)
        if help then ImGui.SameLine(); DemoHelpMarker(help) end
        ImGui.PushItemWidth(width)
        SL.f = ImGui.DragFloat(l1, SL.f)
        if SL.show_indented_items then
            ImGui.Indent()
            SL.f = ImGui.DragFloat(l2, SL.f)
            ImGui.Unindent()
        end
        ImGui.PopItemWidth()
    end
    block("SetNextItemWidth/PushItemWidth(100)", "Fixed width.", 100, "float##1b", "float (indented)##1b")
    block("SetNextItemWidth/PushItemWidth(-100)", "Align to right edge minus 100", -100, "float##2a", "float (indented)##2b")
    block("SetNextItemWidth/PushItemWidth(GetContentRegionAvail().x * 0.5f)", "Half of available width.\n(~ right-cursor_pos)\n(works within a column set)", ImGui.GetContentRegionAvail().x * 0.5, "float##3a", "float (indented)##3b")
    block("SetNextItemWidth/PushItemWidth(-GetContentRegionAvail().x * 0.5f)", "Align to right edge minus half", -ImGui.GetContentRegionAvail().x * 0.5, "float##4a", "float (indented)##4b")
    block("SetNextItemWidth/PushItemWidth(-Min(GetContentRegionAvail().x * 0.40f, GetFontSize() * 12))", nil, -IM_MIN(ImGui.GetFontSize() * 12, ImGui.GetContentRegionAvail().x * 0.40), "float##5a", "float (indented)##5b")
    -- Demonstrate using PushItemWidth to surround three items.
    block("SetNextItemWidth/PushItemWidth(-FLT_MIN)", "Align to right edge", -FLT_MIN, "##float6a", "float (indented)##6b")
end

local function DemoWindowLayout_BasicHorizontal()
    IMGUI_DEMO_MARKER("Layout/Basic Horizontal Layout")
    ImGui.TextWrapped("(Use ImGui::SameLine() to keep adding items to the right of the preceding item)")

    -- Text
    IMGUI_DEMO_MARKER("Layout/Basic Horizontal Layout/SameLine")
    ImGui.Text("Two items: Hello"); ImGui.SameLine()
    ImGui.TextColored(ImVec4(1, 1, 0, 1), "Sailor")

    -- Adjust spacing
    ImGui.Text("More spacing: Hello"); ImGui.SameLine(0, 20)
    ImGui.TextColored(ImVec4(1, 1, 0, 1), "Sailor")

    -- Button
    ImGui.AlignTextToFramePadding()
    ImGui.Text("Normal buttons"); ImGui.SameLine()
    ImGui.Button("Banana"); ImGui.SameLine()
    ImGui.Button("Apple"); ImGui.SameLine()
    ImGui.Button("Corniflower")

    -- Button
    ImGui.Text("Small buttons"); ImGui.SameLine()
    ImGui.SmallButton("Like this one"); ImGui.SameLine()
    ImGui.Text("can fit within a text block.")

    -- Aligned to arbitrary position. Easy/cheap column.
    IMGUI_DEMO_MARKER("Layout/Basic Horizontal Layout/SameLine (with offset)")
    ImGui.Text("Aligned")
    ImGui.SameLine(150); ImGui.Text("x=150")
    ImGui.SameLine(300); ImGui.Text("x=300")
    ImGui.Text("Aligned")
    ImGui.SameLine(150); ImGui.SmallButton("x=150")
    ImGui.SameLine(300); ImGui.SmallButton("x=300")

    -- Checkbox
    IMGUI_DEMO_MARKER("Layout/Basic Horizontal Layout/SameLine (more)")
    _, SL.c1 = ImGui.Checkbox("My", SL.c1); ImGui.SameLine()
    _, SL.c2 = ImGui.Checkbox("Tailor", SL.c2); ImGui.SameLine()
    _, SL.c3 = ImGui.Checkbox("Is", SL.c3); ImGui.SameLine()
    _, SL.c4 = ImGui.Checkbox("Rich", SL.c4)

    -- Various
    ImGui.PushItemWidth(ImGui.CalcTextSize("AAAAAAA").x)
    local items = { "AAAA", "BBBB", "CCCC", "DDDD" }
    if ImGui.Combo then
        SL.item = ImGui.Combo("Combo", SL.item, items, #items)
    else
        NotPorted("Combo")
    end
    ImGui.SameLine()
    SL.f0 = ImGui.SliderFloat("X", SL.f0, 0.0, 5.0); ImGui.SameLine()
    SL.f1 = ImGui.SliderFloat("Y", SL.f1, 0.0, 5.0); ImGui.SameLine()
    SL.f2 = ImGui.SliderFloat("Z", SL.f2, 0.0, 5.0)

    ImGui.Text("Lists:")
    for i = 1, 4 do
        if i > 1 then ImGui.SameLine() end
        ImGui.PushID(i - 1)
        if ImGui.ListBox then
            SL.selection[i] = ImGui.ListBox("", SL.selection[i], items, #items)
        else
            NotPorted("ListBox")
        end
        ImGui.PopID()
    end
    ImGui.PopItemWidth()

    -- Dummy
    IMGUI_DEMO_MARKER("Layout/Basic Horizontal Layout/Dummy")
    local button_sz = ImVec2(40, 40)
    ImGui.Button("A", button_sz); ImGui.SameLine()
    ImGui.Dummy(button_sz); ImGui.SameLine()
    ImGui.Button("B", button_sz)

    -- Manually wrapping
    IMGUI_DEMO_MARKER("Layout/Basic Horizontal Layout/Manual wrapping")
    ImGui.Text("Manual wrapping:")
    local style = ImGui.GetStyle()
    local buttons_count = 20
    local window_visible_x2 = ImGui.GetCursorScreenPos().x + ImGui.GetContentRegionAvail().x
    for n = 0, buttons_count - 1 do
        ImGui.PushID(n)
        ImGui.Button("Box", button_sz)
        local last_button_x2 = ImGui.GetItemRectMax().x
        local next_button_x2 = last_button_x2 + style.ItemSpacing.x + button_sz.x -- Expected position if next button was on same line
        if n + 1 < buttons_count and next_button_x2 < window_visible_x2 then
            ImGui.SameLine()
        end
        ImGui.PopID()
    end
end

local function DemoWindowLayout_Groups()
    IMGUI_DEMO_MARKER("Layout/Groups")
    DemoHelpMarker(
        "BeginGroup() basically locks the horizontal position for new line. " ..
        "EndGroup() bundles the whole group so that you can use \"item\" functions such as " ..
        "IsItemHovered()/IsItemActive() or SameLine() etc. on the whole group.")
    ImGui.BeginGroup()
    do
        ImGui.BeginGroup()
        ImGui.Button("AAA")
        ImGui.SameLine()
        ImGui.Button("BBB")
        ImGui.SameLine()
        ImGui.BeginGroup()
        ImGui.Button("CCC")
        ImGui.Button("DDD")
        ImGui.EndGroup()
        ImGui.SameLine()
        ImGui.Button("EEE")
        ImGui.EndGroup()
        ImGui.SetItemTooltip("First group hovered")
    end
    -- Capture the group size and create widgets using the same size
    local size = ImGui.GetItemRectSize()
    local values = { 0.5, 0.20, 0.80, 0.60, 0.25 }
    ImGui.PlotHistogram("##values", values, nil, #values, 0, nil, 0.0, 1.0, size)

    ImGui.Button("ACTION", ImVec2((size.x - ImGui.GetStyle().ItemSpacing.x) * 0.5, size.y))
    ImGui.SameLine()
    ImGui.Button("REACTION", ImVec2((size.x - ImGui.GetStyle().ItemSpacing.x) * 0.5, size.y))
    ImGui.EndGroup()
    ImGui.SameLine()

    ImGui.Button("LEVERAGE\nBUZZWORD", size)
    ImGui.SameLine()

    if ImGui.BeginListBox and ImGui.BeginListBox("List", size) then
        ImGui.Selectable("Selected", true)
        ImGui.Selectable("Not Selected", false)
        ImGui.EndListBox()
    end
end

local function DemoWindowLayout_TextBaseline()
    IMGUI_DEMO_MARKER("Layout/Text Baseline Alignment")
    do
        ImGui.BulletText("Text baseline:")
        ImGui.SameLine(); DemoHelpMarker(
            "This is testing the vertical alignment that gets applied on text to keep it aligned with widgets. " ..
            "Lines only composed of text or \"small\" widgets use less vertical space than lines with framed widgets.")
        ImGui.Indent()

        ImGui.Text("KO Blahblah"); ImGui.SameLine()
        ImGui.Button("Some framed item"); ImGui.SameLine()
        DemoHelpMarker("Baseline of button will look misaligned with text..")

        ImGui.AlignTextToFramePadding()
        ImGui.Text("OK Blahblah"); ImGui.SameLine()
        ImGui.Button("Some framed item##2"); ImGui.SameLine()
        DemoHelpMarker("We call AlignTextToFramePadding() to vertically align the text baseline by +FramePadding.y")

        -- SmallButton() uses the same vertical padding as Text
        ImGui.Button("TEST##1"); ImGui.SameLine()
        ImGui.Text("TEST"); ImGui.SameLine()
        ImGui.SmallButton("TEST##2")

        ImGui.AlignTextToFramePadding()
        ImGui.Text("Text aligned to framed item"); ImGui.SameLine()
        ImGui.Button("Item##1"); ImGui.SameLine()
        ImGui.Text("Item"); ImGui.SameLine()
        ImGui.SmallButton("Item##2"); ImGui.SameLine()
        ImGui.Button("Item##3")

        ImGui.Unindent()
    end

    ImGui.Spacing()

    do
        ImGui.BulletText("Multi-line text:")
        ImGui.Indent()
        ImGui.Text("One\nTwo\nThree"); ImGui.SameLine()
        ImGui.Text("Hello\nWorld"); ImGui.SameLine()
        ImGui.Text("Banana")

        ImGui.Text("Banana"); ImGui.SameLine()
        ImGui.Text("Hello\nWorld"); ImGui.SameLine()
        ImGui.Text("One\nTwo\nThree")

        ImGui.Button("HOP##1"); ImGui.SameLine()
        ImGui.Text("Banana"); ImGui.SameLine()
        ImGui.Text("Hello\nWorld"); ImGui.SameLine()
        ImGui.Text("Banana")

        ImGui.Button("HOP##2"); ImGui.SameLine()
        ImGui.Text("Hello\nWorld"); ImGui.SameLine()
        ImGui.Text("Banana")
        ImGui.Unindent()
    end

    ImGui.Spacing()

    do
        ImGui.BulletText("Misc items:")
        ImGui.Indent()

        ImGui.Button("80x80", ImVec2(80, 80))
        ImGui.SameLine()
        ImGui.Button("50x50", ImVec2(50, 50))
        ImGui.SameLine()
        ImGui.Button("Button()")
        ImGui.SameLine()
        ImGui.SmallButton("SmallButton()")

        -- Tree
        local spacing = ImGui.GetStyle().ItemInnerSpacing.x
        ImGui.Button("Button##1") -- Will make line higher
        ImGui.SameLine(0.0, spacing)
        if ImGui.TreeNodeEx("Node##1", ImGuiTreeNodeFlags.DrawLinesNone) then
            for i = 0, 5 do
                ImGui.BulletText("Item %d..", i)
            end
            ImGui.TreePop()
        end

        local padding = math.floor(ImGui.GetFontSize() * 1.20) -- Large padding
        ImGui.PushStyleVarY(ImGuiStyleVar.FramePadding, padding)
        ImGui.Button("Button##2")
        ImGui.PopStyleVar()
        ImGui.SameLine(0.0, spacing)
        if ImGui.TreeNodeEx("Node##2", ImGuiTreeNodeFlags.DrawLinesNone) then
            ImGui.TreePop()
        end

        ImGui.AlignTextToFramePadding()

        local node_open = ImGui.TreeNode("Node##3")
        ImGui.SameLine(0.0, spacing); ImGui.Button("Button##3")
        if node_open then
            for i = 0, 5 do
                ImGui.BulletText("Item %d..", i)
            end
            ImGui.TreePop()
        end

        -- Bullet
        ImGui.Button("Button##4")
        ImGui.SameLine(0.0, spacing)
        ImGui.BulletText("Bullet text")

        ImGui.AlignTextToFramePadding()
        ImGui.BulletText("Node")
        ImGui.SameLine(0.0, spacing); ImGui.Button("Button##5")
        ImGui.Unindent()
    end
end

local function DemoWindowLayout_HorizontalContentsSizeWindow()
    if SL.explicit_content_size then
        ImGui.SetNextWindowContentSize(ImVec2(SL.contents_size_x, 0.0))
    end
    SL.show_horizontal_contents_size_demo_window = ImGui.Begin("Horizontal contents size demo window", SL.show_horizontal_contents_size_demo_window, SL.show_h_scrollbar and ImGuiWindowFlags.HorizontalScrollbar or 0)
    IMGUI_DEMO_MARKER("Layout/Scrolling/Horizontal contents size demo window")
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(2, 0))
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(2, 0))
    DemoHelpMarker(
        "Test how different widgets react and impact the work rectangle growing when horizontal scrolling is enabled.\n\n" ..
        "Use 'Metrics->Tools->Show windows rectangles' to visualize rectangles.")
    _, SL.show_h_scrollbar = ImGui.Checkbox("H-scrollbar", SL.show_h_scrollbar)
    _, SL.show_button = ImGui.Checkbox("Button", SL.show_button)
    _, SL.show_tree_nodes = ImGui.Checkbox("Tree nodes", SL.show_tree_nodes)
    _, SL.show_text_wrapped = ImGui.Checkbox("Text wrapped", SL.show_text_wrapped)
    _, SL.show_columns = ImGui.Checkbox("Columns", SL.show_columns)
    _, SL.show_tab_bar = ImGui.Checkbox("Tab bar", SL.show_tab_bar)
    _, SL.show_child = ImGui.Checkbox("Child", SL.show_child)
    _, SL.explicit_content_size = ImGui.Checkbox("Explicit content size", SL.explicit_content_size)
    ImGui.Text("Scroll %.1f/%.1f %.1f/%.1f", ImGui.GetScrollX(), ImGui.GetScrollMaxX(), ImGui.GetScrollY(), ImGui.GetScrollMaxY())
    if SL.explicit_content_size then
        ImGui.SameLine()
        ImGui.SetNextItemWidth(ImGui.CalcTextSize("123456").x)
        SL.contents_size_x = ImGui.DragFloat("##csx", SL.contents_size_x)
        local p = ImGui.GetCursorScreenPos()
        ImGui.GetWindowDrawList():AddRectFilled(p, ImVec2(p.x + 10, p.y + 10), IM_COL32_WHITE)
        ImGui.GetWindowDrawList():AddRectFilled(ImVec2(p.x + SL.contents_size_x - 10, p.y), ImVec2(p.x + SL.contents_size_x, p.y + 10), IM_COL32_WHITE)
        ImGui.Dummy(ImVec2(0, 10))
    end
    ImGui.PopStyleVar(2)
    ImGui.Separator()
    if SL.show_button then
        ImGui.Button("this is a 300-wide button", ImVec2(300, 0))
    end
    if SL.show_tree_nodes then
        local open = true
        if ImGui.TreeNode("this is a tree node") then
            if ImGui.TreeNode("another one of those tree node...") then
                ImGui.Text("Some tree contents")
                ImGui.TreePop()
            end
            ImGui.TreePop()
        end
        ImGui.CollapsingHeader("CollapsingHeader", open)
    end
    if SL.show_text_wrapped then
        ImGui.TextWrapped("This text should automatically wrap on the edge of the work rectangle.")
    end
    if SL.show_columns then
        ImGui.Text("Tables:")
        if ImGui.BeginTable("table", 4, ImGuiTableFlags.Borders) then
            for n = 0, 3 do
                ImGui.TableNextColumn()
                ImGui.Text("Width %.2f", ImGui.GetContentRegionAvail().x)
            end
            ImGui.EndTable()
        end
        ImGui.Text("Columns:")
        if ImGui.Columns then
            ImGui.Columns(4)
            for n = 0, 3 do
                ImGui.Text("Width %.2f", ImGui.GetColumnWidth())
                ImGui.NextColumn()
            end
            ImGui.Columns(1)
        else
            NotPorted("Columns")
        end
    end
    if SL.show_tab_bar and ImGui.BeginTabBar and ImGui.BeginTabBar("Hello") then
        if ImGui.BeginTabItem("OneOneOne") then ImGui.EndTabItem() end
        if ImGui.BeginTabItem("TwoTwoTwo") then ImGui.EndTabItem() end
        if ImGui.BeginTabItem("ThreeThreeThree") then ImGui.EndTabItem() end
        if ImGui.BeginTabItem("FourFourFour") then ImGui.EndTabItem() end
        ImGui.EndTabBar()
    end
    if SL.show_child then
        BeginChild("child", ImVec2(0, 0), ImGuiChildFlags.Borders)
        ImGui.EndChild()
    end
    ImGui.End()
end

local function DemoWindowLayout_Scrolling()
    IMGUI_DEMO_MARKER("Layout/Scrolling/Vertical")
    DemoHelpMarker("Use SetScrollHereY() or SetScrollFromPosY() to scroll to a given vertical position.")

    _, SL.enable_extra_decorations = ImGui.Checkbox("Decoration", SL.enable_extra_decorations)

    ImGui.PushItemWidth(ImGui.GetFontSize() * 10)
    local changed
    SL.track_item, changed = ImGui.DragInt("##item", SL.track_item, 0.25, 0, 99, "Item = %d")
    SL.enable_track = SL.enable_track or changed
    ImGui.SameLine()
    _, SL.enable_track = ImGui.Checkbox("Track", SL.enable_track)

    local scroll_to_off
    SL.scroll_to_off_px, scroll_to_off = ImGui.DragFloat("##off", SL.scroll_to_off_px, 1.00, 0, FLT_MAX, "+%.0f px")
    ImGui.SameLine()
    scroll_to_off = ImGui.Button("Scroll Offset") or scroll_to_off

    local scroll_to_pos
    SL.scroll_to_pos_px, scroll_to_pos = ImGui.DragFloat("##pos", SL.scroll_to_pos_px, 1.00, -10, FLT_MAX, "X/Y = %.0f px")
    ImGui.SameLine()
    scroll_to_pos = ImGui.Button("Scroll To Pos") or scroll_to_pos
    ImGui.PopItemWidth()

    if scroll_to_off or scroll_to_pos then
        SL.enable_track = false
    end

    local style = ImGui.GetStyle()
    local child_w = (ImGui.GetContentRegionAvail().x - 4 * style.ItemSpacing.x) / 5
    if child_w < 1.0 then
        child_w = 1.0
    end
    ImGui.PushID("##VerticalScrolling")
    local vnames = { "Top", "25%", "Center", "75%", "Bottom" }
    for i = 0, 4 do
        if i > 0 then ImGui.SameLine() end
        ImGui.BeginGroup()
        ImGui.TextUnformatted(vnames[i + 1])

        local child_flags = SL.enable_extra_decorations and ImGuiWindowFlags.MenuBar or 0
        local child_id = ImGui.GetID(i)
        local child_is_visible = BeginChild(child_id, ImVec2(child_w, 200.0), ImGuiChildFlags.Borders, child_flags)
        if ImGui.BeginMenuBar() then
            ImGui.TextUnformatted("abc")
            ImGui.EndMenuBar()
        end
        if scroll_to_off then
            ImGui.SetScrollY(SL.scroll_to_off_px)
        end
        if scroll_to_pos then
            ImGui.SetScrollFromPosY(ImGui.GetCursorStartPos().y + SL.scroll_to_pos_px, i * 0.25)
        end
        if child_is_visible then -- Avoid calling SetScrollHereY when running with culled items
            for item = 0, 99 do
                if SL.enable_track and item == SL.track_item then
                    ImGui.TextColored(ImVec4(1, 1, 0, 1), "Item %d", item)
                    ImGui.SetScrollHereY(i * 0.25) -- 0.0f:top, 0.5f:center, 1.0f:bottom
                else
                    ImGui.Text("Item %d", item)
                end
            end
        end
        local scroll_y = ImGui.GetScrollY()
        local scroll_max_y = ImGui.GetScrollMaxY()
        ImGui.EndChild()
        ImGui.Text("%.0f/%.0f", scroll_y, scroll_max_y)
        ImGui.EndGroup()
    end
    ImGui.PopID()

    -- Horizontal scroll functions
    IMGUI_DEMO_MARKER("Layout/Scrolling/Horizontal")
    ImGui.Spacing()
    DemoHelpMarker(
        "Use SetScrollHereX() or SetScrollFromPosX() to scroll to a given horizontal position.\n\n" ..
        "Because the clipping rectangle of most window hides half worth of WindowPadding on the " ..
        "left/right, using SetScrollFromPosX(+1) will usually result in clipped text whereas the " ..
        "equivalent SetScrollFromPosY(+1) wouldn't.")
    ImGui.PushID("##HorizontalScrolling")
    local hnames = { "Left", "25%", "Center", "75%", "Right" }
    for i = 0, 4 do
        local child_height = ImGui.GetTextLineHeight() + style.ScrollbarSize + style.WindowPadding.y * 2.0
        local child_flags = bit32.bor(ImGuiWindowFlags.HorizontalScrollbar, SL.enable_extra_decorations and ImGuiWindowFlags.AlwaysVerticalScrollbar or 0)
        local child_id = ImGui.GetID(i)
        local child_is_visible = BeginChild(child_id, ImVec2(-100, child_height), ImGuiChildFlags.Borders, child_flags)
        if scroll_to_off then
            ImGui.SetScrollX(SL.scroll_to_off_px)
        end
        if scroll_to_pos then
            ImGui.SetScrollFromPosX(ImGui.GetCursorStartPos().x + SL.scroll_to_pos_px, i * 0.25)
        end
        if child_is_visible then
            for item = 0, 99 do
                if item > 0 then
                    ImGui.SameLine()
                end
                if SL.enable_track and item == SL.track_item then
                    ImGui.TextColored(ImVec4(1, 1, 0, 1), "Item %d", item)
                    ImGui.SetScrollHereX(i * 0.25) -- 0.0f:left, 0.5f:center, 1.0f:right
                else
                    ImGui.Text("Item %d", item)
                end
            end
        end
        local scroll_x = ImGui.GetScrollX()
        local scroll_max_x = ImGui.GetScrollMaxX()
        ImGui.EndChild()
        ImGui.SameLine()
        ImGui.Text("%s\n%.0f/%.0f", hnames[i + 1], scroll_x, scroll_max_x)
        ImGui.Spacing()
    end
    ImGui.PopID()

    -- Miscellaneous Horizontal Scrolling Demo
    IMGUI_DEMO_MARKER("Layout/Scrolling/Horizontal (more)")
    DemoHelpMarker(
        "Horizontal scrolling for a window is enabled via the ImGuiWindowFlags_HorizontalScrollbar flag.\n\n" ..
        "You may want to also explicitly specify content width by using SetNextWindowContentWidth() before Begin().")
    SL.lines = ImGui.SliderInt("Lines", SL.lines, 1, 15)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 3.0)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(2.0, 1.0))
    local scrolling_child_size = ImVec2(0, ImGui.GetFrameHeightWithSpacing() * 7 + 30)
    BeginChild("scrolling", scrolling_child_size, ImGuiChildFlags.Borders, ImGuiWindowFlags.HorizontalScrollbar)
    for line = 0, SL.lines - 1 do
        local num_buttons = 10 + ((line % 2 == 1) and line * 9 or line * 3)
        local base_w = ImGui.GetFontSize() * 3
        for n = 0, num_buttons - 1 do
            if n > 0 then ImGui.SameLine() end
            ImGui.PushID(n + line * 1000)
            local label = (n % 15 == 0) and "FizzBuzz" or (n % 3 == 0) and "Fizz" or (n % 5 == 0) and "Buzz" or tostring(n)
            local hue = n * 0.05
            ImGui.PushStyleColor(ImGuiCol.Button, HSV(hue, 0.6, 0.6))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, HSV(hue, 0.7, 0.7))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, HSV(hue, 0.8, 0.8))
            ImGui.Button(label, ImVec2(base_w + math.sin(line + n) * base_w * 0.5, 0.0))
            ImGui.PopStyleColor(3)
            ImGui.PopID()
        end
    end
    local scroll_x = ImGui.GetScrollX()
    local scroll_max_x = ImGui.GetScrollMaxX()
    ImGui.EndChild()
    ImGui.PopStyleVar(2)
    local scroll_x_delta = 0.0
    ImGui.SmallButton("<<")
    if ImGui.IsItemActive() then
        scroll_x_delta = -ImGui.GetIO().DeltaTime * 1000.0
    end
    ImGui.SameLine()
    ImGui.Text("Scroll from code"); ImGui.SameLine()
    ImGui.SmallButton(">>")
    if ImGui.IsItemActive() then
        scroll_x_delta = ImGui.GetIO().DeltaTime * 1000.0
    end
    ImGui.SameLine()
    ImGui.Text("%.0f/%.0f", scroll_x, scroll_max_x)
    if scroll_x_delta ~= 0.0 then
        -- Demonstrate a trick: you can use Begin to set yourself in the context of another window
        BeginChild("scrolling")
        ImGui.SetScrollX(ImGui.GetScrollX() + scroll_x_delta)
        ImGui.EndChild()
    end
    ImGui.Spacing()

    _, SL.show_horizontal_contents_size_demo_window = ImGui.Checkbox("Show Horizontal contents size demo window", SL.show_horizontal_contents_size_demo_window)

    if SL.show_horizontal_contents_size_demo_window then
        DemoWindowLayout_HorizontalContentsSizeWindow()
    end
end

local function DemoWindowLayout_TextClipping()
    IMGUI_DEMO_MARKER("Layout/Text Clipping")
    if SL.clip_size == nil then SL.clip_size = { 100.0, 100.0 }; SL.clip_offset = ImVec2(30.0, 30.0) end
    ImGui.DragFloat2("size", SL.clip_size, 0.5, 1.0, 200.0, "%.0f")
    ImGui.TextWrapped("(Click and drag to scroll)")

    DemoHelpMarker(
        "(Left) Using ImGui::PushClipRect():\n" ..
        "Will alter ImGui hit-testing logic + ImDrawList rendering.\n" ..
        "(use this if you want your clipping rectangle to affect interactions)\n\n" ..
        "(Center) Using ImDrawList::PushClipRect():\n" ..
        "Will alter ImDrawList rendering only.\n" ..
        "(use this as a shortcut if you are only using ImDrawList calls)\n\n" ..
        "(Right) Using ImDrawList::AddText() with a fine ClipRect:\n" ..
        "Will alter only this specific ImDrawList::AddText() rendering.\n" ..
        "This is often used internally to avoid altering the clipping rectangle and minimize draw calls.")

    local size = ImVec2(SL.clip_size[1], SL.clip_size[2])
    local offset = SL.clip_offset
    for n = 0, 2 do repeat
        if n > 0 then
            ImGui.SameLine()
        end

        ImGui.PushID(n)
        ImGui.InvisibleButton("##canvas", size)
        if ImGui.IsItemActive() and ImGui.IsMouseDragging(ImGuiMouseButton.Left) then
            offset.x = offset.x + ImGui.GetIO().MouseDelta.x
            offset.y = offset.y + ImGui.GetIO().MouseDelta.y
        end
        ImGui.PopID()
        if not ImGui.IsItemVisible() then -- Skip rendering as ImDrawList elements are not clipped.
            break
        end

        local p0 = ImGui.GetItemRectMin()
        local p1 = ImGui.GetItemRectMax()
        local text_str = "Line 1 hello\nLine 2 clip me!"
        local text_pos = ImVec2(p0.x + offset.x, p0.y + offset.y)
        local draw_list = ImGui.GetWindowDrawList()
        if n == 0 then
            ImGui.PushClipRect(p0, p1, true)
            draw_list:AddRectFilled(p0, p1, IM_COL32(90, 90, 120, 255))
            draw_list:AddText(text_pos, IM_COL32_WHITE, text_str)
            ImGui.PopClipRect()
        elseif n == 1 then
            draw_list:PushClipRect(p0, p1, true)
            draw_list:AddRectFilled(p0, p1, IM_COL32(90, 90, 120, 255))
            draw_list:AddText(text_pos, IM_COL32_WHITE, text_str)
            draw_list:PopClipRect()
        else
            local clip_rect = ImVec4(p0.x, p0.y, p1.x, p1.y)
            draw_list:AddRectFilled(p0, p1, IM_COL32(90, 90, 120, 255))
            draw_list:AddText(ImGui.GetFont(), ImGui.GetFontSize(), text_pos, IM_COL32_WHITE, text_str, nil, 0.0, clip_rect)
        end
    until true end
end

local function DemoWindowLayout_OverlapMode()
    IMGUI_DEMO_MARKER("Layout/Overlap Mode")
    DemoHelpMarker(
        "Hit-testing is by default performed in item submission order, which generally is perceived as 'back-to-front'.\n\n" ..
        "By using SetNextItemAllowOverlap() you can notify that an item may be overlapped by another. " ..
        "Doing so alters the hovering logic: items using AllowOverlap mode requires an extra frame to accept hovered state.")
    _, SL.enable_allow_overlap = ImGui.Checkbox("Enable AllowOverlap", SL.enable_allow_overlap)

    local button1_pos = ImGui.GetCursorScreenPos()
    local button2_pos = ImVec2(button1_pos.x + 50.0, button1_pos.y + 50.0)
    if SL.enable_allow_overlap then
        ImGui.SetNextItemAllowOverlap()
    end
    ImGui.Button("Button 1", ImVec2(80, 80))
    ImGui.SetCursorScreenPos(button2_pos)
    ImGui.Button("Button 2", ImVec2(80, 80))

    if SL.enable_allow_overlap then
        ImGui.SetNextItemAllowOverlap()
    end
    ImGui.Selectable("Some Selectable", false)
    ImGui.SameLine()
    ImGui.SmallButton("++")
end

function DemoWindowLayout()
    if not ImGui.CollapsingHeader("Layout & Scrolling") then
        return
    end
    if ImGui.TreeNode("Child windows") then DemoWindowLayout_ChildWindows(); ImGui.TreePop() end
    if ImGui.TreeNode("Widgets Width") then DemoWindowLayout_WidgetsWidth(); ImGui.TreePop() end
    if ImGui.TreeNode("Basic Horizontal Layout") then DemoWindowLayout_BasicHorizontal(); ImGui.TreePop() end
    if ImGui.TreeNode("Groups") then DemoWindowLayout_Groups(); ImGui.TreePop() end
    if ImGui.TreeNode("Text Baseline Alignment") then DemoWindowLayout_TextBaseline(); ImGui.TreePop() end
    if ImGui.TreeNode("Scrolling") then DemoWindowLayout_Scrolling(); ImGui.TreePop() end
    if ImGui.TreeNode("Text Clipping") then DemoWindowLayout_TextClipping(); ImGui.TreePop() end
    if ImGui.TreeNode("Overlap Mode") then DemoWindowLayout_OverlapMode(); ImGui.TreePop() end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowPopups()
-------------------------------------------------------------------------------

local SP = {
    selected_fish = -1, toggles = { true, false, false, false, false },
    ctx_selected = -1, value = 0.5, name = nil,
    dont_ask_me_next_time = false, item = 1, color = { 0.4, 0.7, 0.0, 0.5 },
}

local function DemoWindowPopups_Popups()
    IMGUI_DEMO_MARKER("Popups/Popups")
    ImGui.TextWrapped(
        "When a popup is active, it inhibits interacting with windows that are behind the popup. " ..
        "Clicking outside the popup closes it.")

    local names = { "Bream", "Haddock", "Mackerel", "Pollock", "Tilefish" }
    local toggles = SP.toggles

    if ImGui.Button("Select..") then
        ImGui.OpenPopup("my_select_popup")
    end
    ImGui.SameLine()
    ImGui.TextUnformatted(SP.selected_fish == -1 and "<None>" or names[SP.selected_fish + 1])
    if ImGui.BeginPopup("my_select_popup") then
        ImGui.SeparatorText("Aquarium")
        for i = 1, #names do
            if ImGui.Selectable(names[i]) then
                SP.selected_fish = i - 1
            end
        end
        ImGui.EndPopup()
    end

    -- Showing a menu with toggles
    if ImGui.Button("Toggle..") then
        ImGui.OpenPopup("my_toggle_popup")
    end
    if ImGui.BeginPopup("my_toggle_popup") then
        for i = 1, #names do
            _, toggles[i] = ImGui.MenuItem(names[i], "", toggles[i])
        end
        if ImGui.BeginMenu("Sub-menu") then
            ImGui.MenuItem("Click me")
            ImGui.EndMenu()
        end

        ImGui.Separator()
        ImGui.Text("Tooltip here")
        ImGui.SetItemTooltip("I am a tooltip over a popup")

        if ImGui.Button("Stacked Popup") then
            ImGui.OpenPopup("another popup")
        end
        if ImGui.BeginPopup("another popup") then
            for i = 1, #names do
                _, toggles[i] = ImGui.MenuItem(names[i], "", toggles[i])
            end
            if ImGui.BeginMenu("Sub-menu") then
                ImGui.MenuItem("Click me")
                if ImGui.Button("Stacked Popup") then
                    ImGui.OpenPopup("another popup")
                end
                if ImGui.BeginPopup("another popup") then
                    ImGui.Text("I am the last one here.")
                    ImGui.EndPopup()
                end
                ImGui.EndMenu()
            end
            ImGui.EndPopup()
        end
        ImGui.EndPopup()
    end

    -- Call the more complete ShowExampleMenuFile which we use in various places of this demo
    if ImGui.Button("With a menu..") then
        ImGui.OpenPopup("my_file_popup")
    end
    if ImGui.BeginPopup("my_file_popup", ImGuiWindowFlags.MenuBar) then
        if ImGui.BeginMenuBar() then
            if ImGui.BeginMenu("File") then
                DemoMenuFile()
                ImGui.EndMenu()
            end
            if ImGui.BeginMenu("Edit") then
                ImGui.MenuItem("Dummy")
                ImGui.EndMenu()
            end
            ImGui.EndMenuBar()
        end
        ImGui.Text("Hello from popup!")
        ImGui.Button("This is a dummy button..")
        ImGui.EndPopup()
    end
end

local function DemoWindowPopups_ContextMenus()
    IMGUI_DEMO_MARKER("Popups/Context menus")
    DemoHelpMarker("\"Context\" functions are simple helpers to associate a Popup to a given Item or Window identifier.")

    -- Example 1
    do
        local names = { "Label1", "Label2", "Label3", "Label4", "Label5" }
        for n = 0, 4 do
            if ImGui.Selectable(names[n + 1], SP.ctx_selected == n) then
                SP.ctx_selected = n
            end
            if ImGui.BeginPopupContextItem() then -- <-- use last item id as popup id
                SP.ctx_selected = n
                ImGui.Text("This is a popup for \"%s\"!", names[n + 1])
                if ImGui.Button("Close") then
                    ImGui.CloseCurrentPopup()
                end
                ImGui.EndPopup()
            end
            ImGui.SetItemTooltip("Right-click to open popup")
        end
    end

    -- Example 2
    do
        DemoHelpMarker("Text() elements don't have stable identifiers so we need to provide one.")
        ImGui.Text("Value = %.3f <-- (1) right-click this text", SP.value)
        if ImGui.BeginPopupContextItem("my popup") then
            if ImGui.Selectable("Set to zero") then SP.value = 0.0 end
            if ImGui.Selectable("Set to PI") then SP.value = 3.1415 end
            ImGui.SetNextItemWidth(-FLT_MIN)
            SP.value = ImGui.DragFloat("##Value", SP.value, 0.1, 0.0, 0.0)
            ImGui.EndPopup()
        end

        ImGui.Text("(2) Or right-click this text")
        ImGui.OpenPopupOnItemClick("my popup", ImGuiPopupFlags.MouseButtonRight)

        if ImGui.Button("(3) Or click this button") then
            ImGui.OpenPopup("my popup")
        end
    end

    -- Example 3
    do
        DemoHelpMarker("Showcase using a popup ID linked to item ID, with the item having a changing label + stable ID using the ### operator.")
        if SP.name == nil then SP.name = Buf("Label1", 32) end
        local buf = string.format("Button: %s###Button", BufStr(SP.name)) -- ### operator override ID ignoring the preceding label
        ImGui.Button(buf)
        if ImGui.BeginPopupContextItem() then
            ImGui.Text("Edit name:")
            ImGui.InputText("##edit", SP.name, 32)
            if ImGui.Button("Close") then
                ImGui.CloseCurrentPopup()
            end
            ImGui.EndPopup()
        end
        ImGui.SameLine(); ImGui.Text("(<-- right-click here)")
    end
end

local function DemoWindowPopups_Modals()
    IMGUI_DEMO_MARKER("Popups/Modals")
    ImGui.TextWrapped("Modal windows are like popups but the user cannot close them by clicking outside.")

    if ImGui.Button("Delete..") then
        ImGui.OpenPopup("Delete?")
    end

    -- Always center this window when appearing
    local center = ImGui.GetMainViewport():GetCenter()
    ImGui.SetNextWindowPos(center, ImGuiCond.Appearing, ImVec2(0.5, 0.5))

    if ImGui.BeginPopupModal("Delete?", nil, ImGuiWindowFlags.AlwaysAutoResize) then
        ImGui.Text("All those beautiful files will be deleted.\nThis operation cannot be undone!")
        ImGui.Separator()

        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(0, 0))
        _, SP.dont_ask_me_next_time = ImGui.Checkbox("Don't ask me next time", SP.dont_ask_me_next_time)
        ImGui.PopStyleVar()

        if ImGui.Button("OK", ImVec2(120, 0)) then ImGui.CloseCurrentPopup() end
        ImGui.SetItemDefaultFocus()
        ImGui.SameLine()
        if ImGui.Button("Cancel", ImVec2(120, 0)) then ImGui.CloseCurrentPopup() end
        ImGui.EndPopup()
    end

    if ImGui.Button("Stacked modals..") then
        ImGui.OpenPopup("Stacked 1")
    end
    if ImGui.BeginPopupModal("Stacked 1", nil, ImGuiWindowFlags.MenuBar) then
        if ImGui.BeginMenuBar() then
            if ImGui.BeginMenu("File") then
                if ImGui.MenuItem("Some menu item") then end
                ImGui.EndMenu()
            end
            ImGui.EndMenuBar()
        end
        ImGui.Text("Hello from Stacked The First\nUsing style.Colors[ImGuiCol_ModalWindowDimBg] behind it.")

        -- Testing behavior of widgets stacking their own regular popups over the modal.
        if ImGui.Combo then
            SP.item = ImGui.Combo("Combo", SP.item, { "aaaa", "bbbb", "cccc", "dddd", "eeee" }, 5)
        else
            NotPorted("Combo")
        end
        ImGui.ColorEdit4("Color", SP.color)

        if ImGui.Button("Add another modal..") then
            ImGui.OpenPopup("Stacked 2")
        end

        local unused_open = true
        if ImGui.BeginPopupModal("Stacked 2", unused_open) then
            ImGui.Text("Hello from Stacked The Second!")
            ImGui.ColorEdit4("Color", SP.color) -- Allow opening another nested popup
            if ImGui.Button("Close") then
                ImGui.CloseCurrentPopup()
            end
            ImGui.EndPopup()
        end

        if ImGui.Button("Close") then
            ImGui.CloseCurrentPopup()
        end
        ImGui.EndPopup()
    end
end

function DemoWindowPopups()
    if not ImGui.CollapsingHeader("Popups & Modal windows") then
        return
    end

    if ImGui.TreeNode("Popups") then DemoWindowPopups_Popups(); ImGui.TreePop() end
    if ImGui.TreeNode("Context menus") then DemoWindowPopups_ContextMenus(); ImGui.TreePop() end
    if ImGui.TreeNode("Modals") then
        if ImGui.BeginPopupModal then DemoWindowPopups_Modals() else NotPorted("BeginPopupModal") end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Menus inside a regular window") then
        IMGUI_DEMO_MARKER("Popups/Menus inside a regular window")
        ImGui.TextWrapped("Below we are testing adding menu items to a regular window. It's rather unusual but should work!")
        ImGui.Separator()

        ImGui.MenuItem("Menu item", "Ctrl+M")
        if ImGui.BeginMenu("Menu inside a regular window") then
            DemoMenuFile()
            ImGui.EndMenu()
        end
        ImGui.Separator()
        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowTables()
-------------------------------------------------------------------------------

-- MyItemColumnID
local MyItemColumnID_ID, MyItemColumnID_Name, MyItemColumnID_Action, MyItemColumnID_Quantity, MyItemColumnID_Description = 0, 1, 2, 3, 4

local function MyItem(id, name, quantity) return { ID = id, Name = name, Quantity = quantity } end

--- Sort a Lua array (1-based) of MyItem with ImGuiTableSortSpecs (Specs is 1-based array or ImVector)
local function MyItem_SortWithSortSpecs(sort_specs, items, items_count)
    if items_count <= 1 then return end
    local specs = sort_specs.Specs
    local function get_spec(n) -- n: 0-based
        if specs.Data then return specs.Data[n + 1] end
        return specs[n + 1]
    end
    local function cmp(a, b) -- returns <0, 0, >0
        for n = 0, sort_specs.SpecsCount - 1 do
            local sort_spec = get_spec(n)
            local delta = 0
            local uid = sort_spec.ColumnUserID
            if uid == MyItemColumnID_ID then delta = a.ID - b.ID
            elseif uid == MyItemColumnID_Name then delta = (a.Name < b.Name) and -1 or (a.Name > b.Name) and 1 or 0
            elseif uid == MyItemColumnID_Quantity then delta = a.Quantity - b.Quantity
            elseif uid == MyItemColumnID_Description then delta = (a.Name < b.Name) and -1 or (a.Name > b.Name) and 1 or 0
            else IM_ASSERT(false) end
            if delta > 0 then
                return (sort_spec.SortDirection == ImGuiSortDirection.Ascending) and 1 or -1
            end
            if delta < 0 then
                return (sort_spec.SortDirection == ImGuiSortDirection.Ascending) and -1 or 1
            end
        end
        return a.ID - b.ID
    end
    local arr = items.Data or items
    if items.Data then
        -- ImVector: sort only the used range
        local tmp = {}
        for i = 1, items_count do tmp[i] = arr[i] end
        table.sort(tmp, function(a, b) return cmp(a, b) < 0 end)
        for i = 1, items_count do arr[i] = tmp[i] end
    else
        table.sort(arr, function(a, b) return cmp(a, b) < 0 end)
    end
end

-- Make the UI compact because there are so many fields
local function PushStyleCompact()
    local style = ImGui.GetStyle()
    ImGui.PushStyleVarY(ImGuiStyleVar.FramePadding, math.floor(style.FramePadding.y * 0.60))
    ImGui.PushStyleVarY(ImGuiStyleVar.ItemSpacing, math.floor(style.ItemSpacing.y * 0.60))
end

local function PopStyleCompact()
    ImGui.PopStyleVar(2)
end

local table_sizing_policies = nil
-- Show a combo box with a choice of sizing policies
local function EditTableSizingFlags(flags)
    if table_sizing_policies == nil then
        table_sizing_policies = {
            { Value = ImGuiTableFlags.None,              Name = "Default",                           Tooltip = "Use default sizing policy:\n- ImGuiTableFlags_SizingFixedFit if ScrollX is on or if host window has ImGuiWindowFlags_AlwaysAutoResize.\n- ImGuiTableFlags_SizingStretchSame otherwise." },
            { Value = ImGuiTableFlags.SizingFixedFit,    Name = "ImGuiTableFlags_SizingFixedFit",    Tooltip = "Columns default to _WidthFixed (if resizable) or _WidthAuto (if not resizable), matching contents width." },
            { Value = ImGuiTableFlags.SizingFixedSame,   Name = "ImGuiTableFlags_SizingFixedSame",   Tooltip = "Columns are all the same width, matching the maximum contents width.\nImplicitly disable ImGuiTableFlags_Resizable and enable ImGuiTableFlags_NoKeepColumnsVisible." },
            { Value = ImGuiTableFlags.SizingStretchProp, Name = "ImGuiTableFlags_SizingStretchProp", Tooltip = "Columns default to _WidthStretch with weights proportional to their widths." },
            { Value = ImGuiTableFlags.SizingStretchSame, Name = "ImGuiTableFlags_SizingStretchSame", Tooltip = "Columns default to _WidthStretch with same weights." },
        }
    end
    local policies = table_sizing_policies
    local idx = 1
    while idx <= #policies do
        if policies[idx].Value == bit32.band(flags, ImGuiTableFlags.SizingMask_) then break end
        idx = idx + 1
    end
    local preview_text = (idx <= #policies) and (idx > 1 and string.sub(policies[idx].Name, #"ImGuiTableFlags" + 1) or policies[idx].Name) or ""
    if ImGui.BeginCombo("Sizing Policy", preview_text) then
        for n = 1, #policies do
            if ImGui.Selectable(policies[n].Name, idx == n) then
                flags = bit32.bor(bit32.band(flags, bit32.bnot(ImGuiTableFlags.SizingMask_)), policies[n].Value)
            end
        end
        ImGui.EndCombo()
    end
    ImGui.SameLine()
    ImGui.TextDisabled("(?)")
    if ImGui.BeginItemTooltip() then
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 50.0)
        for m = 1, #policies do
            ImGui.Separator()
            ImGui.Text("%s:", policies[m].Name)
            ImGui.Separator()
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ImGui.GetStyle().IndentSpacing * 0.5)
            ImGui.TextUnformatted(policies[m].Tooltip)
        end
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
    return flags
end

local function EditTableColumnsFlags(f)
    local p
    local F = ImGuiTableColumnFlags
    _, f = ImGui.CheckboxFlags("_Disabled", f, F.Disabled); ImGui.SameLine(); DemoHelpMarker("Master disable flag (also hide from context menu)")
    _, f = ImGui.CheckboxFlags("_DefaultHide", f, F.DefaultHide)
    _, f = ImGui.CheckboxFlags("_DefaultSort", f, F.DefaultSort)
    p, f = ImGui.CheckboxFlags("_WidthStretch", f, F.WidthStretch)
    if p then f = bit32.band(f, bit32.bnot(bit32.bxor(F.WidthMask_, F.WidthStretch))) end
    p, f = ImGui.CheckboxFlags("_WidthFixed", f, F.WidthFixed)
    if p then f = bit32.band(f, bit32.bnot(bit32.bxor(F.WidthMask_, F.WidthFixed))) end
    _, f = ImGui.CheckboxFlags("_NoResize", f, F.NoResize)
    _, f = ImGui.CheckboxFlags("_NoReorder", f, F.NoReorder)
    _, f = ImGui.CheckboxFlags("_NoHide", f, F.NoHide)
    _, f = ImGui.CheckboxFlags("_NoClip", f, F.NoClip)
    _, f = ImGui.CheckboxFlags("_NoSort", f, F.NoSort)
    _, f = ImGui.CheckboxFlags("_NoSortAscending", f, F.NoSortAscending)
    _, f = ImGui.CheckboxFlags("_NoSortDescending", f, F.NoSortDescending)
    _, f = ImGui.CheckboxFlags("_NoHeaderLabel", f, F.NoHeaderLabel)
    _, f = ImGui.CheckboxFlags("_NoHeaderWidth", f, F.NoHeaderWidth)
    _, f = ImGui.CheckboxFlags("_PreferSortAscending", f, F.PreferSortAscending)
    _, f = ImGui.CheckboxFlags("_PreferSortDescending", f, F.PreferSortDescending)
    _, f = ImGui.CheckboxFlags("_IndentEnable", f, F.IndentEnable); ImGui.SameLine(); DemoHelpMarker("Default for column 0")
    _, f = ImGui.CheckboxFlags("_IndentDisable", f, F.IndentDisable); ImGui.SameLine(); DemoHelpMarker("Default for column >0")
    _, f = ImGui.CheckboxFlags("_AngledHeader", f, F.AngledHeader)
    return f
end

local function ShowTableColumnsStatusFlags(flags)
    ImGui.CheckboxFlags("_IsEnabled", flags, ImGuiTableColumnFlags.IsEnabled)
    ImGui.CheckboxFlags("_IsVisible", flags, ImGuiTableColumnFlags.IsVisible)
    ImGui.CheckboxFlags("_IsSorted", flags, ImGuiTableColumnFlags.IsSorted)
    ImGui.CheckboxFlags("_IsHovered", flags, ImGuiTableColumnFlags.IsHovered)
end

local function bor(...) return bit32.bor(...) end
local TF = setmetatable({}, { __index = function(_, k) return ImGuiTableFlags[k] end })

local ST = {} -- statics for DemoWindowTables (one sub-table per section)
local TEXT_BASE_WIDTH, TEXT_BASE_HEIGHT = 0, 0

local function Tables_Basic()
    IMGUI_DEMO_MARKER("Tables/Basic")
    -- [Method 1] Using TableNextRow() to create a new row, and TableSetColumnIndex() to select the column.
    DemoHelpMarker("Using TableNextRow() + calling TableSetColumnIndex() _before_ each cell, in a loop.")
    if ImGui.BeginTable("table1", 3) then
        for row = 0, 3 do
            ImGui.TableNextRow()
            for column = 0, 2 do
                ImGui.TableSetColumnIndex(column)
                ImGui.Text("Row %d Column %d", row, column)
            end
        end
        ImGui.EndTable()
    end

    -- [Method 2] Using TableNextColumn() called multiple times, instead of using a for loop + TableSetColumnIndex().
    DemoHelpMarker("Using TableNextRow() + calling TableNextColumn() _before_ each cell, manually.")
    if ImGui.BeginTable("table2", 3) then
        for row = 0, 3 do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text("Row %d", row)
            ImGui.TableNextColumn()
            ImGui.Text("Some contents")
            ImGui.TableNextColumn()
            ImGui.Text("123.456")
        end
        ImGui.EndTable()
    end

    -- [Method 3] We call TableNextColumn() _before_ each cell. We never call TableNextRow(),
    DemoHelpMarker(
        "Only using TableNextColumn(), which tends to be convenient for tables where every cell contains " ..
        "the same type of contents.\n This is also more similar to the old NextColumn() function of the " ..
        "Columns API, and provided to facilitate the Columns->Tables API transition.")
    if ImGui.BeginTable("table3", 3) then
        for item = 0, 13 do
            ImGui.TableNextColumn()
            ImGui.Text("Item %d", item)
        end
        ImGui.EndTable()
    end
end

local function Tables_BordersBackground()
    IMGUI_DEMO_MARKER("Tables/Borders, background")
    local CT_Text, CT_FillButton = 0, 1
    local s = ST.borders
    if s == nil then s = { flags = bor(TF.Borders, TF.RowBg), display_headers = false, contents_type = CT_Text }; ST.borders = s end

    PushStyleCompact()
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_RowBg", s.flags, TF.RowBg)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Borders", s.flags, TF.Borders)
    ImGui.SameLine(); DemoHelpMarker("ImGuiTableFlags_Borders\n = ImGuiTableFlags_BordersInnerV\n | ImGuiTableFlags_BordersOuterV\n | ImGuiTableFlags_BordersInnerH\n | ImGuiTableFlags_BordersOuterH")
    ImGui.Indent()

    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersH", s.flags, TF.BordersH)
    ImGui.Indent()
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterH", s.flags, TF.BordersOuterH)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerH", s.flags, TF.BordersInnerH)
    ImGui.Unindent()

    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersV", s.flags, TF.BordersV)
    ImGui.Indent()
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterV", s.flags, TF.BordersOuterV)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerV", s.flags, TF.BordersInnerV)
    ImGui.Unindent()

    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuter", s.flags, TF.BordersOuter)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInner", s.flags, TF.BordersInner)
    ImGui.Unindent()

    ImGui.AlignTextToFramePadding(); ImGui.Text("Cell contents:")
    ImGui.SameLine(); _, s.contents_type = ImGui.RadioButton("Text", s.contents_type, CT_Text)
    ImGui.SameLine(); _, s.contents_type = ImGui.RadioButton("FillButton", s.contents_type, CT_FillButton)
    _, s.display_headers = ImGui.Checkbox("Display headers", s.display_headers)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBody", s.flags, TF.NoBordersInBody); ImGui.SameLine(); DemoHelpMarker("Disable vertical borders in columns Body (borders will always appear in Headers)")
    PopStyleCompact()

    if ImGui.BeginTable("table1", 3, s.flags) then
        if s.display_headers then
            ImGui.TableSetupColumn("One")
            ImGui.TableSetupColumn("Two")
            ImGui.TableSetupColumn("Three")
            ImGui.TableHeadersRow()
        end

        for row = 0, 4 do
            ImGui.TableNextRow()
            for column = 0, 2 do
                ImGui.TableSetColumnIndex(column)
                local buf = string.format("Hello %d,%d", column, row)
                if s.contents_type == CT_Text then
                    ImGui.TextUnformatted(buf)
                elseif s.contents_type == CT_FillButton then
                    ImGui.Button(buf, ImVec2(-FLT_MIN, 0.0))
                end
            end
        end
        ImGui.EndTable()
    end
end

local function Tables_HelloGrid(id, flags, rows, cols, fmt)
    if ImGui.BeginTable(id, cols, flags) then
        for row = 0, rows - 1 do
            ImGui.TableNextRow()
            for column = 0, cols - 1 do
                ImGui.TableSetColumnIndex(column)
                ImGui.Text(fmt or "Hello %d,%d", column, row)
            end
        end
        ImGui.EndTable()
    end
end

local function Tables_ResizableStretch()
    IMGUI_DEMO_MARKER("Tables/Resizable, stretch")
    local s = ST.rstretch
    if s == nil then s = { flags = bor(TF.SizingStretchSame, TF.Resizable, TF.BordersOuter, TF.BordersV, TF.ContextMenuInBody) }; ST.rstretch = s end
    PushStyleCompact()
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags, TF.Resizable)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersV", s.flags, TF.BordersV)
    ImGui.SameLine(); DemoHelpMarker(
        "Using the _Resizable flag automatically enables the _BordersInnerV flag as well, " ..
        "this is why the resize borders are still showing when unchecking this.")
    PopStyleCompact()

    Tables_HelloGrid("table1", s.flags, 5, 3)
end

local function Tables_ResizableFixed()
    IMGUI_DEMO_MARKER("Tables/Resizable, fixed")
    DemoHelpMarker(
        "Using _Resizable + _SizingFixedFit flags.\n" ..
        "Fixed-width columns generally makes more sense if you want to use horizontal scrolling.\n\n" ..
        "Double-click a column border to auto-fit the column to its contents.")
    PushStyleCompact()
    local s = ST.rfixed
    if s == nil then s = { flags = bor(TF.SizingFixedFit, TF.Resizable, TF.BordersOuter, TF.BordersV, TF.ContextMenuInBody) }; ST.rfixed = s end
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendX", s.flags, TF.NoHostExtendX)
    PopStyleCompact()

    Tables_HelloGrid("table1", s.flags, 5, 3)
end

local function Tables_ResizableMixed()
    IMGUI_DEMO_MARKER("Tables/Resizable, mixed")
    DemoHelpMarker(
        "Using TableSetupColumn() to alter resizing policy on a per-column basis.\n\n" ..
        "When combining Fixed and Stretch columns, generally you only want one, maybe two trailing columns to use _WidthStretch.")
    local flags = bor(TF.SizingFixedFit, TF.RowBg, TF.Borders, TF.Resizable, TF.Reorderable, TF.Hideable)
    local CF = ImGuiTableColumnFlags

    if ImGui.BeginTable("table1", 3, flags) then
        ImGui.TableSetupColumn("AAA", CF.WidthFixed)
        ImGui.TableSetupColumn("BBB", CF.WidthFixed)
        ImGui.TableSetupColumn("CCC", CF.WidthStretch)
        ImGui.TableHeadersRow()
        for row = 0, 4 do
            ImGui.TableNextRow()
            for column = 0, 2 do
                ImGui.TableSetColumnIndex(column)
                ImGui.Text("%s %d,%d", (column == 2) and "Stretch" or "Fixed", column, row)
            end
        end
        ImGui.EndTable()
    end
    if ImGui.BeginTable("table2", 6, flags) then
        ImGui.TableSetupColumn("AAA", CF.WidthFixed)
        ImGui.TableSetupColumn("BBB", CF.WidthFixed)
        ImGui.TableSetupColumn("CCC", bor(CF.WidthFixed, CF.DefaultHide))
        ImGui.TableSetupColumn("DDD", CF.WidthStretch)
        ImGui.TableSetupColumn("EEE", CF.WidthStretch)
        ImGui.TableSetupColumn("FFF", bor(CF.WidthStretch, CF.DefaultHide))
        ImGui.TableHeadersRow()
        for row = 0, 4 do
            ImGui.TableNextRow()
            for column = 0, 5 do
                ImGui.TableSetColumnIndex(column)
                ImGui.Text("%s %d,%d", (column >= 3) and "Stretch" or "Fixed", column, row)
            end
        end
        ImGui.EndTable()
    end
end

local function Tables_Reorderable()
    IMGUI_DEMO_MARKER("Tables/Reorderable, hideable, with headers")
    DemoHelpMarker(
        "Click and drag column headers to reorder columns.\n\n" ..
        "Right-click on a header to open a context menu.")
    local s = ST.reorder
    if s == nil then s = { flags = bor(TF.Resizable, TF.Reorderable, TF.Hideable, TF.BordersOuter, TF.BordersV) }; ST.reorder = s end
    PushStyleCompact()
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags, TF.Resizable)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Reorderable", s.flags, TF.Reorderable)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Hideable", s.flags, TF.Hideable)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBody", s.flags, TF.NoBordersInBody)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBodyUntilResize", s.flags, TF.NoBordersInBodyUntilResize); ImGui.SameLine(); DemoHelpMarker("Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers)")
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_HighlightHoveredColumn", s.flags, TF.HighlightHoveredColumn)
    PopStyleCompact()

    if ImGui.BeginTable("table1", 3, s.flags) then
        ImGui.TableSetupColumn("One")
        ImGui.TableSetupColumn("Two")
        ImGui.TableSetupColumn("Three")
        ImGui.TableHeadersRow()
        for row = 0, 5 do
            ImGui.TableNextRow()
            for column = 0, 2 do
                ImGui.TableSetColumnIndex(column)
                ImGui.Text("Hello %d,%d", column, row)
            end
        end
        ImGui.EndTable()
    end

    -- Use outer_size.x == 0.0f instead of default to make the table as tight as possible
    if ImGui.BeginTable("table2", 3, bor(s.flags, TF.SizingFixedFit), ImVec2(0.0, 0.0)) then
        ImGui.TableSetupColumn("One")
        ImGui.TableSetupColumn("Two")
        ImGui.TableSetupColumn("Three")
        ImGui.TableHeadersRow()
        for row = 0, 5 do
            ImGui.TableNextRow()
            for column = 0, 2 do
                ImGui.TableSetColumnIndex(column)
                ImGui.Text("Fixed %d,%d", column, row)
            end
        end
        ImGui.EndTable()
    end
end

local function Tables_Padding()
    IMGUI_DEMO_MARKER("Tables/Padding")
    DemoHelpMarker(
        "We often want outer padding activated when any using features which makes the edges of a column visible:\n" ..
        "e.g.:\n" ..
        "- BorderOuterV\n" ..
        "- any form of row selection\n" ..
        "Because of this, activating BorderOuterV sets the default to PadOuterX. " ..
        "Using PadOuterX or NoPadOuterX you can override the default.\n\n" ..
        "Actual padding values are using style.CellPadding.\n\n" ..
        "In this demo we don't show horizontal borders to emphasize how they don't affect default horizontal padding.")

    local s = ST.padding
    if s == nil then
        s = { flags1 = TF.BordersV, show_headers = false, flags2 = bor(TF.Borders, TF.RowBg), cell_padding = ImVec2(0.0, 0.0),
              show_widget_frame_bg = true, text_bufs = {}, init = true }
        ST.padding = s
    end
    PushStyleCompact()
    _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_PadOuterX", s.flags1, TF.PadOuterX)
    ImGui.SameLine(); DemoHelpMarker("Enable outer-most padding (default if ImGuiTableFlags_BordersOuterV is set)")
    _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_NoPadOuterX", s.flags1, TF.NoPadOuterX)
    ImGui.SameLine(); DemoHelpMarker("Disable outer-most padding (default if ImGuiTableFlags_BordersOuterV is not set)")
    _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_NoPadInnerX", s.flags1, TF.NoPadInnerX)
    ImGui.SameLine(); DemoHelpMarker("Disable inner padding between columns (double inner padding if BordersOuterV is on, single inner padding if BordersOuterV is off)")
    _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterV", s.flags1, TF.BordersOuterV)
    _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerV", s.flags1, TF.BordersInnerV)
    _, s.show_headers = ImGui.Checkbox("show_headers", s.show_headers)
    PopStyleCompact()

    if ImGui.BeginTable("table_padding", 3, s.flags1) then
        if s.show_headers then
            ImGui.TableSetupColumn("One")
            ImGui.TableSetupColumn("Two")
            ImGui.TableSetupColumn("Three")
            ImGui.TableHeadersRow()
        end

        for row = 0, 4 do
            ImGui.TableNextRow()
            for column = 0, 2 do
                ImGui.TableSetColumnIndex(column)
                if row == 0 then
                    ImGui.Text("Avail %.2f", ImGui.GetContentRegionAvail().x)
                else
                    local buf = string.format("Hello %d,%d", column, row)
                    ImGui.Button(buf, ImVec2(-FLT_MIN, 0.0))
                end
            end
        end
        ImGui.EndTable()
    end

    -- Second example: set style.CellPadding to (0.0) or a custom value.
    DemoHelpMarker("Setting style.CellPadding to (0,0) or a custom value.")

    PushStyleCompact()
    _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_Borders", s.flags2, TF.Borders)
    _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersH", s.flags2, TF.BordersH)
    _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersV", s.flags2, TF.BordersV)
    _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInner", s.flags2, TF.BordersInner)
    _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuter", s.flags2, TF.BordersOuter)
    _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_RowBg", s.flags2, TF.RowBg)
    _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags2, TF.Resizable)
    _, s.show_widget_frame_bg = ImGui.Checkbox("show_widget_frame_bg", s.show_widget_frame_bg)
    ImGui.SliderFloat2("CellPadding", s.cell_padding, 0.0, 10.0, "%.0f")
    PopStyleCompact()

    ImGui.PushStyleVar(ImGuiStyleVar.CellPadding, s.cell_padding)
    if ImGui.BeginTable("table_padding_2", 3, s.flags2) then
        if not s.show_widget_frame_bg then
            ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)
        end
        for cell = 0, 3 * 5 - 1 do
            ImGui.TableNextColumn()
            if s.init then
                s.text_bufs[cell + 1] = Buf("edit me", 16)
            end
            ImGui.SetNextItemWidth(-FLT_MIN)
            ImGui.PushID(cell)
            ImGui.InputText("##cell", s.text_bufs[cell + 1], 16)
            ImGui.PopID()
        end
        if not s.show_widget_frame_bg then
            ImGui.PopStyleColor()
        end
        s.init = false
        ImGui.EndTable()
    end
    ImGui.PopStyleVar()
end

local function Tables_SizingPolicies()
    IMGUI_DEMO_MARKER("Tables/Explicit widths")
    local s = ST.sizing
    if s == nil then
        s = { flags1 = bor(TF.BordersV, TF.BordersOuterH, TF.RowBg, TF.ContextMenuInBody),
              sizing_policy_flags = { TF.SizingFixedFit, TF.SizingFixedSame, TF.SizingStretchProp, TF.SizingStretchSame },
              flags = bor(TF.ScrollY, TF.Borders, TF.RowBg, TF.Resizable), contents_type = 0, column_count = 3, text_buf = Buf("", 32) }
        ST.sizing = s
    end
    PushStyleCompact()
    _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags1, TF.Resizable)
    _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendX", s.flags1, TF.NoHostExtendX)
    PopStyleCompact()

    for table_n = 0, 3 do
        ImGui.PushID(table_n)
        ImGui.SetNextItemWidth(TEXT_BASE_WIDTH * 30)
        s.sizing_policy_flags[table_n + 1] = EditTableSizingFlags(s.sizing_policy_flags[table_n + 1])

        if ImGui.BeginTable("table1", 3, bor(s.sizing_policy_flags[table_n + 1], s.flags1)) then
            for row = 0, 2 do
                ImGui.TableNextRow()
                ImGui.TableNextColumn(); ImGui.Text("Oh dear")
                ImGui.TableNextColumn(); ImGui.Text("Oh dear")
                ImGui.TableNextColumn(); ImGui.Text("Oh dear")
            end
            ImGui.EndTable()
        end
        if ImGui.BeginTable("table2", 3, bor(s.sizing_policy_flags[table_n + 1], s.flags1)) then
            for row = 0, 2 do
                ImGui.TableNextRow()
                ImGui.TableNextColumn(); ImGui.Text("AAAA")
                ImGui.TableNextColumn(); ImGui.Text("BBBBBBBB")
                ImGui.TableNextColumn(); ImGui.Text("CCCCCCCCCCCC")
            end
            ImGui.EndTable()
        end
        ImGui.PopID()
    end

    ImGui.Spacing()
    ImGui.TextUnformatted("Advanced")
    ImGui.SameLine()
    DemoHelpMarker(
        "This section allows you to interact and see the effect of various sizing policies " ..
        "depending on whether Scroll is enabled and the contents of your columns.")

    local CT_ShowWidth, CT_ShortText, CT_LongText, CT_Button, CT_FillButton, CT_InputText = 0, 1, 2, 3, 4, 5

    PushStyleCompact()
    ImGui.PushID("Advanced")
    ImGui.PushItemWidth(TEXT_BASE_WIDTH * 30)
    s.flags = EditTableSizingFlags(s.flags)
    if ImGui.Combo then
        s.contents_type = ImGui.Combo("Contents", s.contents_type, { "Show width", "Short Text", "Long Text", "Button", "Fill Button", "InputText" }, 6)
    else
        NotPorted("Combo")
    end
    if s.contents_type == CT_FillButton then
        ImGui.SameLine()
        DemoHelpMarker(
            "Be mindful that using right-alignment (e.g. size.x = -FLT_MIN) creates a feedback loop " ..
            "where contents width can feed into auto-column width can feed into contents width.")
    end
    s.column_count = ImGui.DragInt("Columns", s.column_count, 0.1, 1, 64, "%d", ImGuiSliderFlags.AlwaysClamp)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags, TF.Resizable)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_PreciseWidths", s.flags, TF.PreciseWidths)
    ImGui.SameLine(); DemoHelpMarker("Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.")
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollX", s.flags, TF.ScrollX)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", s.flags, TF.ScrollY)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoClip", s.flags, TF.NoClip)
    ImGui.PopItemWidth()
    ImGui.PopID()
    PopStyleCompact()

    if ImGui.BeginTable("table2", s.column_count, s.flags, ImVec2(0.0, TEXT_BASE_HEIGHT * 7)) then
        for cell = 0, 10 * s.column_count - 1 do
            ImGui.TableNextColumn()
            local column = ImGui.TableGetColumnIndex()
            local row = ImGui.TableGetRowIndex()

            ImGui.PushID(cell)
            local label = string.format("Hello %d,%d", column, row)
            local ct = s.contents_type
            if ct == CT_ShortText then ImGui.TextUnformatted(label)
            elseif ct == CT_LongText then ImGui.Text("Some %s text %d,%d\nOver two lines..", column == 0 and "long" or "longeeer", column, row)
            elseif ct == CT_ShowWidth then ImGui.Text("W: %.1f", ImGui.GetContentRegionAvail().x)
            elseif ct == CT_Button then ImGui.Button(label)
            elseif ct == CT_FillButton then ImGui.Button(label, ImVec2(-FLT_MIN, 0.0))
            elseif ct == CT_InputText then ImGui.SetNextItemWidth(-FLT_MIN); ImGui.InputText("##", s.text_buf, 32)
            end
            ImGui.PopID()
        end
        ImGui.EndTable()
    end
end

local function Tables_VerticalScrolling()
    IMGUI_DEMO_MARKER("Tables/Vertical scrolling, with clipping")
    DemoHelpMarker(
        "Here we activate ScrollY, which will create a child window container to allow hosting scrollable contents.\n\n" ..
        "We also demonstrate using ImGuiListClipper to virtualize the submission of many items.")
    local s = ST.vscroll
    if s == nil then s = { flags = bor(TF.ScrollY, TF.RowBg, TF.BordersOuter, TF.BordersV, TF.Resizable, TF.Reorderable, TF.Hideable) }; ST.vscroll = s end

    PushStyleCompact()
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", s.flags, TF.ScrollY)
    PopStyleCompact()

    local outer_size = ImVec2(0.0, TEXT_BASE_HEIGHT * 8)
    if ImGui.BeginTable("table_scrolly", 3, s.flags, outer_size) then
        ImGui.TableSetupScrollFreeze(0, 1) -- Make top row always visible
        ImGui.TableSetupColumn("One", ImGuiTableColumnFlags.None)
        ImGui.TableSetupColumn("Two", ImGuiTableColumnFlags.None)
        ImGui.TableSetupColumn("Three", ImGuiTableColumnFlags.None)
        ImGui.TableHeadersRow()

        -- Demonstrate using clipper for large vertical lists
        local clipper = ImGuiListClipper()
        clipper:Begin(1000)
        while clipper:Step() do
            for row = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                ImGui.TableNextRow()
                for column = 0, 2 do
                    ImGui.TableSetColumnIndex(column)
                    ImGui.Text("Hello %d,%d", column, row)
                end
            end
        end
        ImGui.EndTable()
    end
end

local function Tables_HorizontalScrolling()
    IMGUI_DEMO_MARKER("Tables/Horizontal scrolling")
    DemoHelpMarker(
        "When ScrollX is enabled, the default sizing policy becomes ImGuiTableFlags_SizingFixedFit, " ..
        "as automatically stretching columns doesn't make much sense with horizontal scrolling.\n\n" ..
        "Also note that as of the current version, you will almost always want to enable ScrollY along with ScrollX, " ..
        "because the container window won't automatically extend vertically to fix contents " ..
        "(this may be improved in future versions).")
    local s = ST.hscroll
    if s == nil then
        s = { flags = bor(TF.ScrollX, TF.ScrollY, TF.RowBg, TF.BordersOuter, TF.BordersV, TF.Resizable, TF.Reorderable, TF.Hideable),
              freeze_cols = 1, freeze_rows = 1,
              flags2 = bor(TF.SizingStretchSame, TF.ScrollX, TF.ScrollY, TF.BordersOuter, TF.RowBg, TF.ContextMenuInBody), inner_width = 1000.0 }
        ST.hscroll = s
    end

    PushStyleCompact()
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags, TF.Resizable)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollX", s.flags, TF.ScrollX)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", s.flags, TF.ScrollY)
    ImGui.SetNextItemWidth(ImGui.GetFrameHeight())
    s.freeze_cols = ImGui.DragInt("freeze_cols", s.freeze_cols, 0.2, 0, 9, nil, ImGuiSliderFlags.NoInput)
    ImGui.SetNextItemWidth(ImGui.GetFrameHeight())
    s.freeze_rows = ImGui.DragInt("freeze_rows", s.freeze_rows, 0.2, 0, 9, nil, ImGuiSliderFlags.NoInput)
    PopStyleCompact()

    local outer_size = ImVec2(0.0, TEXT_BASE_HEIGHT * 8)
    if ImGui.BeginTable("table_scrollx", 7, s.flags, outer_size) then
        ImGui.TableSetupScrollFreeze(s.freeze_cols, s.freeze_rows)
        ImGui.TableSetupColumn("Line #", ImGuiTableColumnFlags.NoHide) -- Make the first column not hideable to match our use of TableSetupScrollFreeze()
        ImGui.TableSetupColumn("One")
        ImGui.TableSetupColumn("Two")
        ImGui.TableSetupColumn("Three")
        ImGui.TableSetupColumn("Four")
        ImGui.TableSetupColumn("Five")
        ImGui.TableSetupColumn("Six")
        ImGui.TableHeadersRow()
        for row = 0, 19 do
            ImGui.TableNextRow()
            for column = 0, 6 do repeat
                if not ImGui.TableSetColumnIndex(column) and column > 0 then
                    break -- continue
                end
                if column == 0 then
                    ImGui.Text("Line %d", row)
                else
                    ImGui.Text("Hello world %d,%d", column, row)
                end
            until true end
        end
        ImGui.EndTable()
    end

    ImGui.Spacing()
    ImGui.TextUnformatted("Stretch + ScrollX")
    ImGui.SameLine()
    DemoHelpMarker(
        "Showcase using Stretch columns + ScrollX together: " ..
        "this is rather unusual and only makes sense when specifying an 'inner_width' for the table!\n" ..
        "Without an explicit value, inner_width is == outer_size.x and therefore using Stretch columns " ..
        "along with ScrollX doesn't make sense.")
    PushStyleCompact()
    ImGui.PushID("flags3")
    ImGui.PushItemWidth(TEXT_BASE_WIDTH * 30)
    _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollX", s.flags2, TF.ScrollX)
    s.inner_width = ImGui.DragFloat("inner_width", s.inner_width, 1.0, 0.0, FLT_MAX, "%.1f")
    ImGui.PopItemWidth()
    ImGui.PopID()
    PopStyleCompact()
    if ImGui.BeginTable("table2", 7, s.flags2, outer_size, s.inner_width) then
        for cell = 0, 20 * 7 - 1 do
            ImGui.TableNextColumn()
            ImGui.Text("Hello world %d,%d", ImGui.TableGetColumnIndex(), ImGui.TableGetRowIndex())
        end
        ImGui.EndTable()
    end
end

local function Tables_ColumnsFlags()
    IMGUI_DEMO_MARKER("Tables/Columns flags")
    local column_count = 3
    local column_names = { "One", "Two", "Three" }
    local s = ST.colflags
    if s == nil then
        s = { column_flags = { ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.None, ImGuiTableColumnFlags.DefaultHide }, column_flags_out = { 0, 0, 0 } }
        ST.colflags = s
    end

    if ImGui.BeginTable("table_columns_flags_checkboxes", column_count, ImGuiTableFlags.None) then
        PushStyleCompact()
        for column = 1, column_count do
            ImGui.TableNextColumn()
            ImGui.PushID(column - 1)
            ImGui.AlignTextToFramePadding() -- FIXME-TABLE: Workaround for wrong text baseline propagation across columns
            ImGui.Text("'%s'", column_names[column])
            ImGui.Spacing()
            ImGui.Text("Input flags:")
            s.column_flags[column] = EditTableColumnsFlags(s.column_flags[column])
            ImGui.Spacing()
            ImGui.Text("Output flags:")
            ImGui.BeginDisabled()
            ShowTableColumnsStatusFlags(s.column_flags_out[column])
            ImGui.EndDisabled()
            ImGui.PopID()
        end
        PopStyleCompact()
        ImGui.EndTable()
    end

    local flags = bor(TF.SizingFixedFit, TF.ScrollX, TF.ScrollY, TF.RowBg, TF.BordersOuter, TF.BordersV, TF.Resizable, TF.Reorderable, TF.Hideable, TF.Sortable)
    local outer_size = ImVec2(0.0, TEXT_BASE_HEIGHT * 9)
    if ImGui.BeginTable("table_columns_flags", column_count, flags, outer_size) then
        local has_angled_header = false
        for column = 1, column_count do
            has_angled_header = has_angled_header or Has(s.column_flags[column], ImGuiTableColumnFlags.AngledHeader)
            ImGui.TableSetupColumn(column_names[column], s.column_flags[column])
        end
        if has_angled_header then
            ImGui.TableAngledHeadersRow()
        end
        ImGui.TableHeadersRow()
        for column = 1, column_count do
            s.column_flags_out[column] = ImGui.TableGetColumnFlags(column - 1)
        end
        local indent_step = math.floor(math.floor(TEXT_BASE_WIDTH) / 2)
        for row = 0, 7 do
            -- Add some indentation to demonstrate usage of per-column IndentEnable/IndentDisable flags.
            ImGui.Indent(indent_step)
            ImGui.TableNextRow()
            for column = 0, column_count - 1 do
                ImGui.TableSetColumnIndex(column)
                ImGui.Text("%s %s", (column == 0) and "Indented" or "Hello", ImGui.TableGetColumnName(column))
            end
        end
        ImGui.Unindent(indent_step * 8.0)

        ImGui.EndTable()
    end
end

local function Tables_ColumnsWidths()
    IMGUI_DEMO_MARKER("Tables/Columns widths")
    DemoHelpMarker("Using TableSetupColumn() to setup default width.")
    local s = ST.colwidths
    if s == nil then s = { flags1 = bor(TF.Borders, TF.NoBordersInBodyUntilResize), flags2 = TF.None }; ST.colwidths = s end
    local CF = ImGuiTableColumnFlags

    PushStyleCompact()
    _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags1, TF.Resizable)
    _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBodyUntilResize", s.flags1, TF.NoBordersInBodyUntilResize)
    PopStyleCompact()
    if ImGui.BeginTable("table1", 3, s.flags1) then
        ImGui.TableSetupColumn("one", CF.WidthFixed, 100.0) -- Default to 100.0f
        ImGui.TableSetupColumn("two", CF.WidthFixed, 200.0) -- Default to 200.0f
        ImGui.TableSetupColumn("three", CF.WidthFixed)      -- Default to auto
        ImGui.TableHeadersRow()
        for row = 0, 3 do
            ImGui.TableNextRow()
            for column = 0, 2 do
                ImGui.TableSetColumnIndex(column)
                if row == 0 then
                    ImGui.Text("(w: %5.1f)", ImGui.GetContentRegionAvail().x)
                else
                    ImGui.Text("Hello %d,%d", column, row)
                end
            end
        end
        ImGui.EndTable()
    end

    DemoHelpMarker(
        "Using TableSetupColumn() to setup explicit width.\n\nUnless _NoKeepColumnsVisible is set, " ..
        "fixed columns with set width may still be shrunk down if there's not enough space in the host.")

    PushStyleCompact()
    _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_NoKeepColumnsVisible", s.flags2, TF.NoKeepColumnsVisible)
    _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerV", s.flags2, TF.BordersInnerV)
    _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterV", s.flags2, TF.BordersOuterV)
    PopStyleCompact()
    if ImGui.BeginTable("table2", 4, s.flags2) then
        ImGui.TableSetupColumn("", CF.WidthFixed, 100.0)
        ImGui.TableSetupColumn("", CF.WidthFixed, TEXT_BASE_WIDTH * 15.0)
        ImGui.TableSetupColumn("", CF.WidthFixed, TEXT_BASE_WIDTH * 30.0)
        ImGui.TableSetupColumn("", CF.WidthFixed, TEXT_BASE_WIDTH * 15.0)
        for row = 0, 4 do
            ImGui.TableNextRow()
            for column = 0, 3 do
                ImGui.TableSetColumnIndex(column)
                if row == 0 then
                    ImGui.Text("(w: %5.1f)", ImGui.GetContentRegionAvail().x)
                else
                    ImGui.Text("Hello %d,%d", column, row)
                end
            end
        end
        ImGui.EndTable()
    end
end

local function Tables_Nested()
    IMGUI_DEMO_MARKER("Tables/Nested tables")
    DemoHelpMarker("This demonstrates embedding a table into another table cell.")

    if ImGui.BeginTable("table_nested1", 2, bor(TF.Borders, TF.Resizable, TF.Reorderable, TF.Hideable)) then
        ImGui.TableSetupColumn("A0")
        ImGui.TableSetupColumn("A1")
        ImGui.TableHeadersRow()

        ImGui.TableNextColumn()
        ImGui.Text("A0 Row 0")
        do
            local rows_height = (TEXT_BASE_HEIGHT * 2.0) + (ImGui.GetStyle().CellPadding.y * 2.0)
            if ImGui.BeginTable("table_nested2", 2, bor(TF.Borders, TF.Resizable, TF.Reorderable, TF.Hideable)) then
                ImGui.TableSetupColumn("B0")
                ImGui.TableSetupColumn("B1")
                ImGui.TableHeadersRow()

                ImGui.TableNextRow(ImGuiTableRowFlags.None, rows_height)
                ImGui.TableNextColumn()
                ImGui.Text("B0 Row 0")
                ImGui.TableNextColumn()
                ImGui.Text("B1 Row 0")
                ImGui.TableNextRow(ImGuiTableRowFlags.None, rows_height)
                ImGui.TableNextColumn()
                ImGui.Text("B0 Row 1")
                ImGui.TableNextColumn()
                ImGui.Text("B1 Row 1")

                ImGui.EndTable()
            end
        end
        ImGui.TableNextColumn(); ImGui.Text("A1 Row 0")
        ImGui.TableNextColumn(); ImGui.Text("A0 Row 1")
        ImGui.TableNextColumn(); ImGui.Text("A1 Row 1")
        ImGui.EndTable()
    end
end

local function Tables_RowHeight()
    IMGUI_DEMO_MARKER("Tables/Row height")
    DemoHelpMarker(
        "You can pass a 'min_row_height' to TableNextRow().\n\nRows are padded with 'style.CellPadding.y' on top and bottom, " ..
        "so effectively the minimum row height will always be >= 'style.CellPadding.y * 2.0f'.\n\n" ..
        "We cannot honor a _maximum_ row height as that would require a unique clipping rectangle per row.")
    if ImGui.BeginTable("table_row_height", 1, TF.Borders) then
        for row = 0, 7 do
            local min_row_height = math.floor(TEXT_BASE_HEIGHT * 0.30 * row + ImGui.GetStyle().CellPadding.y * 2.0)
            ImGui.TableNextRow(ImGuiTableRowFlags.None, min_row_height)
            ImGui.TableNextColumn()
            ImGui.Text("min_row_height = %.2f", min_row_height)
        end
        ImGui.EndTable()
    end

    DemoHelpMarker(
        "Showcase using SameLine(0,0) to share Current Line Height between cells.\n\n" ..
        "Please note that Tables Row Height is not the same thing as Current Line Height, " ..
        "as a table cell may contains multiple lines.")
    if ImGui.BeginTable("table_share_lineheight", 2, TF.Borders) then
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        ImGui.ColorButton("##1", ImVec4(0.13, 0.26, 0.40, 1.0), ImGuiColorEditFlags.None, ImVec2(40, 40))
        ImGui.TableNextColumn()
        ImGui.Text("Line 1")
        ImGui.Text("Line 2")

        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        ImGui.ColorButton("##2", ImVec4(0.13, 0.26, 0.40, 1.0), ImGuiColorEditFlags.None, ImVec2(40, 40))
        ImGui.TableNextColumn()
        ImGui.SameLine(0.0, 0.0) -- Reuse line height from previous column
        ImGui.Text("Line 1, with SameLine(0,0)")
        ImGui.Text("Line 2")

        ImGui.EndTable()
    end

    DemoHelpMarker("Showcase altering CellPadding.y between rows. Note that CellPadding.x is locked for the entire table.")
    if ImGui.BeginTable("table_changing_cellpadding_y", 1, TF.Borders) then
        local style = ImGui.GetStyle()
        for row = 0, 7 do
            if (row % 3) == 2 then
                ImGui.PushStyleVarY(ImGuiStyleVar.CellPadding, 20.0)
            end
            ImGui.TableNextRow(ImGuiTableRowFlags.None)
            ImGui.TableNextColumn()
            ImGui.Text("CellPadding.y = %.2f", style.CellPadding.y)
            if (row % 3) == 2 then
                ImGui.PopStyleVar()
            end
        end
        ImGui.EndTable()
    end
end

local function Tables_OuterSize()
    IMGUI_DEMO_MARKER("Tables/Outer size")
    ImGui.Text("Using NoHostExtendX and NoHostExtendY:")
    PushStyleCompact()
    local s = ST.outer
    if s == nil then s = { flags = bor(TF.Borders, TF.Resizable, TF.ContextMenuInBody, TF.RowBg, TF.SizingFixedFit, TF.NoHostExtendX) }; ST.outer = s end
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendX", s.flags, TF.NoHostExtendX)
    ImGui.SameLine(); DemoHelpMarker("Make outer width auto-fit to columns, overriding outer_size.x value.\n\nOnly available when ScrollX/ScrollY are disabled and Stretch columns are not used.")
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendY", s.flags, TF.NoHostExtendY)
    ImGui.SameLine(); DemoHelpMarker("Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit).\n\nOnly available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.")
    PopStyleCompact()

    local outer_size = ImVec2(0.0, TEXT_BASE_HEIGHT * 5.5)
    if ImGui.BeginTable("table1", 3, s.flags, outer_size) then
        for row = 0, 9 do
            ImGui.TableNextRow()
            for column = 0, 2 do
                ImGui.TableNextColumn()
                ImGui.Text("Cell %d,%d", column, row)
            end
        end
        ImGui.EndTable()
    end
    ImGui.SameLine()
    ImGui.Text("Hello!")

    ImGui.Spacing()

    ImGui.Text("Using explicit size:")
    if ImGui.BeginTable("table2", 3, bor(TF.Borders, TF.RowBg), ImVec2(TEXT_BASE_WIDTH * 30, 0.0)) then
        for row = 0, 4 do
            ImGui.TableNextRow()
            for column = 0, 2 do
                ImGui.TableNextColumn()
                ImGui.Text("Cell %d,%d", column, row)
            end
        end
        ImGui.EndTable()
    end
    ImGui.SameLine()
    if ImGui.BeginTable("table3", 3, bor(TF.Borders, TF.RowBg), ImVec2(TEXT_BASE_WIDTH * 30, 0.0)) then
        local rows_height = TEXT_BASE_HEIGHT * 1.5 + ImGui.GetStyle().CellPadding.y * 2.0
        for row = 0, 2 do
            ImGui.TableNextRow(0, rows_height)
            for column = 0, 2 do
                ImGui.TableNextColumn()
                ImGui.Text("Cell %d,%d", column, row)
            end
        end
        ImGui.EndTable()
    end
end

local function Tables_BackgroundColor()
    IMGUI_DEMO_MARKER("Tables/Background color")
    local s = ST.bgcolor
    if s == nil then s = { flags = TF.RowBg, row_bg_type = 1, row_bg_target = 1, cell_bg_type = 1 }; ST.bgcolor = s end

    PushStyleCompact()
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Borders", s.flags, TF.Borders)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_RowBg", s.flags, TF.RowBg)
    ImGui.SameLine(); DemoHelpMarker("ImGuiTableFlags_RowBg automatically sets RowBg0 to alternative colors pulled from the Style.")
    if ImGui.Combo then
        s.row_bg_type = ImGui.Combo("row bg type", s.row_bg_type, { "None", "Red", "Gradient" }, 3)
        s.row_bg_target = ImGui.Combo("row bg target", s.row_bg_target, { "RowBg0", "RowBg1" }, 2); ImGui.SameLine(); DemoHelpMarker("Target RowBg0 to override the alternating odd/even colors,\nTarget RowBg1 to blend with them.")
        s.cell_bg_type = ImGui.Combo("cell bg type", s.cell_bg_type, { "None", "Blue" }, 2); ImGui.SameLine(); DemoHelpMarker("We are colorizing cells to B1->C2 here.")
    else
        NotPorted("Combo")
    end
    IM_ASSERT(s.row_bg_type >= 0 and s.row_bg_type <= 2)
    IM_ASSERT(s.row_bg_target >= 0 and s.row_bg_target <= 1)
    IM_ASSERT(s.cell_bg_type >= 0 and s.cell_bg_type <= 1)
    PopStyleCompact()

    if ImGui.BeginTable("table1", 5, s.flags) then
        for row = 0, 5 do
            ImGui.TableNextRow()

            if s.row_bg_type ~= 0 then
                local row_bg_color = ImGui.GetColorU32(s.row_bg_type == 1 and ImVec4(0.7, 0.3, 0.3, 0.65) or ImVec4(0.2 + row * 0.1, 0.2, 0.2, 0.65)) -- Flat or Gradient?
                ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0 + s.row_bg_target, row_bg_color)
            end

            -- Fill cells
            for column = 0, 4 do
                ImGui.TableSetColumnIndex(column)
                ImGui.Text("%s%s", string.char(65 + row), string.char(48 + column))

                if row >= 1 and row <= 2 and column >= 1 and column <= 2 and s.cell_bg_type == 1 then
                    local cell_bg_color = ImGui.GetColorU32(ImVec4(0.3, 0.3, 0.7, 0.65))
                    ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, cell_bg_color)
                end
            end
        end
        ImGui.EndTable()
    end
end

local tree_view_nodes = {
    { Name = "Root with Long Name",           Type = "Folder",      Size = -1,     ChildIdx = 1,  ChildCount = 3  }, -- 0
    { Name = "Music",                         Type = "Folder",      Size = -1,     ChildIdx = 4,  ChildCount = 2  }, -- 1
    { Name = "Textures",                      Type = "Folder",      Size = -1,     ChildIdx = 6,  ChildCount = 3  }, -- 2
    { Name = "desktop.ini",                   Type = "System file", Size = 1024,   ChildIdx = -1, ChildCount = -1 }, -- 3
    { Name = "File1_a.wav",                   Type = "Audio file",  Size = 123000, ChildIdx = -1, ChildCount = -1 }, -- 4
    { Name = "File1_b.wav",                   Type = "Audio file",  Size = 456000, ChildIdx = -1, ChildCount = -1 }, -- 5
    { Name = "Image001.png",                  Type = "Image file",  Size = 203128, ChildIdx = -1, ChildCount = -1 }, -- 6
    { Name = "Copy of Image001.png",          Type = "Image file",  Size = 203256, ChildIdx = -1, ChildCount = -1 }, -- 7
    { Name = "Copy of Image001 (Final2).png", Type = "Image file",  Size = 203512, ChildIdx = -1, ChildCount = -1 }, -- 8
}

local function MyTreeNode_DisplayNode(node, all_nodes, tree_node_flags_base)
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    local is_folder = (node.ChildCount > 0)

    local node_flags = tree_node_flags_base
    if node ~= all_nodes[1] then
        node_flags = bit32.band(node_flags, bit32.bnot(ImGuiTreeNodeFlags.LabelSpanAllColumns)) -- Only demonstrate this on the root node.
    end

    if is_folder then
        local open = ImGui.TreeNodeEx(node.Name, node_flags)
        if bit32.band(node_flags, ImGuiTreeNodeFlags.LabelSpanAllColumns) == 0 then
            ImGui.TableNextColumn()
            ImGui.TextDisabled("--")
            ImGui.TableNextColumn()
            ImGui.TextUnformatted(node.Type)
        end
        if open then
            for child_n = 0, node.ChildCount - 1 do
                MyTreeNode_DisplayNode(all_nodes[node.ChildIdx + child_n + 1], all_nodes, tree_node_flags_base)
            end
            ImGui.TreePop()
        end
    else
        ImGui.TreeNodeEx(node.Name, bor(node_flags, ImGuiTreeNodeFlags.Leaf, ImGuiTreeNodeFlags.Bullet, ImGuiTreeNodeFlags.NoTreePushOnOpen))
        ImGui.TableNextColumn()
        ImGui.Text("%d", node.Size)
        ImGui.TableNextColumn()
        ImGui.TextUnformatted(node.Type)
    end
end

local function Tables_TreeView()
    IMGUI_DEMO_MARKER("Tables/Tree view")
    local s = ST.treeview
    if s == nil then
        s = { table_flags = bor(TF.BordersV, TF.BordersOuterH, TF.Resizable, TF.RowBg, TF.NoBordersInBody),
              tree_node_flags_base = bor(ImGuiTreeNodeFlags.SpanAllColumns, ImGuiTreeNodeFlags.DefaultOpen, ImGuiTreeNodeFlags.DrawLinesFull) }
        ST.treeview = s
    end
    _, s.tree_node_flags_base = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanFullWidth", s.tree_node_flags_base, ImGuiTreeNodeFlags.SpanFullWidth)
    _, s.tree_node_flags_base = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanLabelWidth", s.tree_node_flags_base, ImGuiTreeNodeFlags.SpanLabelWidth)
    _, s.tree_node_flags_base = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanAllColumns", s.tree_node_flags_base, ImGuiTreeNodeFlags.SpanAllColumns)
    _, s.tree_node_flags_base = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_LabelSpanAllColumns", s.tree_node_flags_base, ImGuiTreeNodeFlags.LabelSpanAllColumns)
    ImGui.SameLine(); DemoHelpMarker("Useful if you know that you aren't displaying contents in other columns")

    DemoHelpMarker("See \"Columns flags\" section to configure how indentation is applied to individual columns.")
    if ImGui.BeginTable("3ways", 3, s.table_flags) then
        ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.NoHide)
        ImGui.TableSetupColumn("Size", ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 12.0)
        ImGui.TableSetupColumn("Type", ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 18.0)
        ImGui.TableHeadersRow()

        MyTreeNode_DisplayNode(tree_view_nodes[1], tree_view_nodes, s.tree_node_flags_base)

        ImGui.EndTable()
    end
end

local function Tables_ItemWidth()
    IMGUI_DEMO_MARKER("Tables/Item width")
    DemoHelpMarker(
        "Showcase using PushItemWidth() and how it is preserved on a per-column basis.\n\n" ..
        "Note that on auto-resizing non-resizable fixed columns, querying the content width for " ..
        "e.g. right-alignment doesn't make sense.")
    if ImGui.BeginTable("table_item_width", 3, TF.Borders) then
        ImGui.TableSetupColumn("small")
        ImGui.TableSetupColumn("half")
        ImGui.TableSetupColumn("right-align")
        ImGui.TableHeadersRow()

        for row = 0, 2 do
            ImGui.TableNextRow()
            if row == 0 then
                -- Setup ItemWidth once (instead of setting up every time, which is also possible but less efficient)
                ImGui.TableSetColumnIndex(0)
                ImGui.PushItemWidth(TEXT_BASE_WIDTH * 3.0) -- Small
                ImGui.TableSetColumnIndex(1)
                ImGui.PushItemWidth(-ImGui.GetContentRegionAvail().x * 0.5)
                ImGui.TableSetColumnIndex(2)
                ImGui.PushItemWidth(-FLT_MIN) -- Right-aligned
            end

            -- Draw our contents
            ImGui.PushID(row)
            ImGui.TableSetColumnIndex(0)
            ST.dummy_f = ImGui.SliderFloat("float0", ST.dummy_f or 0.0, 0.0, 1.0)
            ImGui.TableSetColumnIndex(1)
            ST.dummy_f = ImGui.SliderFloat("float1", ST.dummy_f, 0.0, 1.0)
            ImGui.TableSetColumnIndex(2)
            ST.dummy_f = ImGui.SliderFloat("##float2", ST.dummy_f, 0.0, 1.0) -- No visible label since right-aligned
            ImGui.PopID()
        end
        ImGui.EndTable()
    end
end

local function Tables_CustomHeaders()
    IMGUI_DEMO_MARKER("Tables/Custom headers")
    local COLUMNS_COUNT = 3
    if ImGui.BeginTable("table_custom_headers", COLUMNS_COUNT, bor(TF.Borders, TF.Reorderable, TF.Hideable)) then
        ImGui.TableSetupColumn("Apricot")
        ImGui.TableSetupColumn("Banana")
        ImGui.TableSetupColumn("Cherry")

        -- Dummy entire-column selection storage
        if ST.column_selected == nil then ST.column_selected = { false, false, false } end
        local column_selected = ST.column_selected

        ImGui.TableNextRow(ImGuiTableRowFlags.Headers)
        for column = 0, COLUMNS_COUNT - 1 do
            ImGui.TableSetColumnIndex(column)
            local column_name = ImGui.TableGetColumnName(column) -- Retrieve name passed to TableSetupColumn()
            ImGui.PushID(column)
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(0, 0))
            _, column_selected[column + 1] = ImGui.Checkbox("##checkall", column_selected[column + 1])
            ImGui.PopStyleVar()
            ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
            ImGui.TableHeader(column_name)
            ImGui.PopID()
        end

        -- Submit table contents
        for row = 0, 4 do
            ImGui.TableNextRow()
            for column = 0, 2 do
                local buf = string.format("Cell %d,%d", column, row)
                ImGui.TableSetColumnIndex(column)
                ImGui.Selectable(buf, column_selected[column + 1])
            end
        end
        ImGui.EndTable()
    end
end

local function Tables_AngledHeaders()
    IMGUI_DEMO_MARKER("Tables/Angled headers")
    local column_names = { "Track", "cabasa", "ride", "smash", "tom-hi", "tom-mid", "tom-low", "hihat-o", "hihat-c", "snare-s", "snare-c", "clap", "rim", "kick" }
    local columns_count = #column_names
    local rows_count = 12

    local s = ST.angled
    if s == nil then
        s = { table_flags = bor(TF.SizingFixedFit, TF.ScrollX, TF.ScrollY, TF.BordersOuter, TF.BordersInnerH, TF.Hideable, TF.Resizable, TF.Reorderable, TF.HighlightHoveredColumn),
              column_flags = bor(ImGuiTableColumnFlags.AngledHeader, ImGuiTableColumnFlags.WidthFixed),
              bools = {}, frozen_cols = 1, frozen_rows = 2 }
        for i = 1, columns_count * rows_count do s.bools[i] = false end
        ST.angled = s
    end
    _, s.table_flags = ImGui.CheckboxFlags("_ScrollX", s.table_flags, TF.ScrollX)
    _, s.table_flags = ImGui.CheckboxFlags("_ScrollY", s.table_flags, TF.ScrollY)
    _, s.table_flags = ImGui.CheckboxFlags("_Resizable", s.table_flags, TF.Resizable)
    _, s.table_flags = ImGui.CheckboxFlags("_Sortable", s.table_flags, TF.Sortable)
    _, s.table_flags = ImGui.CheckboxFlags("_NoBordersInBody", s.table_flags, TF.NoBordersInBody)
    _, s.table_flags = ImGui.CheckboxFlags("_HighlightHoveredColumn", s.table_flags, TF.HighlightHoveredColumn)
    ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
    s.frozen_cols = ImGui.SliderInt("Frozen columns", s.frozen_cols, 0, 2)
    ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
    s.frozen_rows = ImGui.SliderInt("Frozen rows", s.frozen_rows, 0, 2)
    _, s.column_flags = ImGui.CheckboxFlags("Disable header contributing to column width", s.column_flags, ImGuiTableColumnFlags.NoHeaderWidth)

    if ImGui.TreeNode("Style settings") then
        ImGui.SameLine()
        DemoHelpMarker("Giving access to some ImGuiStyle value in this demo for convenience.")
        ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
        local style = ImGui.GetStyle()
        style.TableAngledHeadersAngle = ImGui.SliderAngle("style.TableAngledHeadersAngle", style.TableAngledHeadersAngle, -50.0, 50.0)
        ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
        ImGui.SliderFloat2("style.TableAngledHeadersTextAlign", style.TableAngledHeadersTextAlign, 0.0, 1.0, "%.2f")
        ImGui.TreePop()
    end

    if ImGui.BeginTable("table_angled_headers", columns_count, s.table_flags, ImVec2(0.0, TEXT_BASE_HEIGHT * 12)) then
        ImGui.TableSetupColumn(column_names[1], bor(ImGuiTableColumnFlags.NoHide, ImGuiTableColumnFlags.NoReorder))
        for n = 2, columns_count do
            ImGui.TableSetupColumn(column_names[n], s.column_flags)
        end
        ImGui.TableSetupScrollFreeze(s.frozen_cols, s.frozen_rows)

        ImGui.TableAngledHeadersRow() -- Draw angled headers for all columns with the ImGuiTableColumnFlags_AngledHeader flag.
        ImGui.TableHeadersRow()       -- Draw remaining headers and allow access to context-menu and other functions.
        for row = 0, rows_count - 1 do
            ImGui.PushID(row)
            ImGui.TableNextRow()
            ImGui.TableSetColumnIndex(0)
            ImGui.AlignTextToFramePadding()
            ImGui.Text("Track %d", row)
            for column = 1, columns_count - 1 do
                if ImGui.TableSetColumnIndex(column) then
                    ImGui.PushID(column)
                    local idx = row * columns_count + column + 1
                    _, s.bools[idx] = ImGui.Checkbox("", s.bools[idx])
                    ImGui.PopID()
                end
            end
            ImGui.PopID()
        end
        ImGui.EndTable()
    end
end

local function Tables_ContextMenus()
    IMGUI_DEMO_MARKER("Tables/Context menus")
    DemoHelpMarker(
        "By default, right-clicking over a TableHeadersRow()/TableHeader() line will open the default context-menu.\n" ..
        "Using ImGuiTableFlags_ContextMenuInBody we also allow right-clicking over columns body.")
    local s = ST.ctxmenu
    if s == nil then s = { flags1 = bor(TF.Resizable, TF.Reorderable, TF.Hideable, TF.Borders, TF.ContextMenuInBody) }; ST.ctxmenu = s end

    PushStyleCompact()
    _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_ContextMenuInBody", s.flags1, TF.ContextMenuInBody)
    PopStyleCompact()

    local COLUMNS_COUNT = 3
    if ImGui.BeginTable("table_context_menu", COLUMNS_COUNT, s.flags1) then
        ImGui.TableSetupColumn("One")
        ImGui.TableSetupColumn("Two")
        ImGui.TableSetupColumn("Three")

        -- [1.1]] Right-click on the TableHeadersRow() line to open the default table context menu.
        ImGui.TableHeadersRow()

        -- Submit dummy contents
        for row = 0, 3 do
            ImGui.TableNextRow()
            for column = 0, COLUMNS_COUNT - 1 do
                ImGui.TableSetColumnIndex(column)
                ImGui.Text("Cell %d,%d", column, row)
            end
        end
        ImGui.EndTable()
    end

    DemoHelpMarker(
        "Demonstrate mixing table context menu (over header), item context button (over button) " ..
        "and custom per-column context menu (over column body).")
    local flags2 = bor(TF.Resizable, TF.SizingFixedFit, TF.Reorderable, TF.Hideable, TF.Borders)
    if ImGui.BeginTable("table_context_menu_2", COLUMNS_COUNT, flags2) then
        ImGui.TableSetupColumn("One")
        ImGui.TableSetupColumn("Two")
        ImGui.TableSetupColumn("Three")

        -- [2.1] Right-click on the TableHeadersRow() line to open the default table context menu.
        ImGui.TableHeadersRow()
        for row = 0, 3 do
            ImGui.TableNextRow()
            for column = 0, COLUMNS_COUNT - 1 do
                -- Submit dummy contents
                ImGui.TableSetColumnIndex(column)
                ImGui.Text("Cell %d,%d", column, row)
                ImGui.SameLine()

                -- [2.2] Right-click on the ".." to open a custom popup
                ImGui.PushID(row * COLUMNS_COUNT + column)
                ImGui.SmallButton("..")
                if ImGui.BeginPopupContextItem() then
                    ImGui.Text("This is the popup for Button(\"..\") in Cell %d,%d", column, row)
                    if ImGui.Button("Close") then
                        ImGui.CloseCurrentPopup()
                    end
                    ImGui.EndPopup()
                end
                ImGui.PopID()
            end
        end

        -- [2.3] Right-click anywhere in columns to open another custom popup
        local hovered_column = -1
        for column = 0, COLUMNS_COUNT do
            ImGui.PushID(column)
            if Has(ImGui.TableGetColumnFlags(column), ImGuiTableColumnFlags.IsHovered) then
                hovered_column = column
            end
            if hovered_column == column and not ImGui.IsAnyItemHovered() and ImGui.IsMouseReleased(1) then
                ImGui.OpenPopup("MyPopup")
            end
            if ImGui.BeginPopup("MyPopup") then
                if column == COLUMNS_COUNT then
                    ImGui.Text("This is a custom popup for unused space after the last column.")
                else
                    ImGui.Text("This is a custom popup for Column %d", column)
                end
                if ImGui.Button("Close") then
                    ImGui.CloseCurrentPopup()
                end
                ImGui.EndPopup()
            end
            ImGui.PopID()
        end

        ImGui.EndTable()
        ImGui.Text("Hovered column: %d", hovered_column)
    end
end

local function Tables_SyncedInstances()
    IMGUI_DEMO_MARKER("Tables/Synced instances")
    DemoHelpMarker("Multiple tables with the same identifier will share their settings, width, visibility, order etc.")

    local s = ST.synced
    if s == nil then s = { flags = bor(TF.Resizable, TF.Reorderable, TF.Hideable, TF.Borders, TF.SizingFixedFit, TF.NoSavedSettings) }; ST.synced = s end
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags, TF.Resizable)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", s.flags, TF.ScrollY)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SizingFixedFit", s.flags, TF.SizingFixedFit)
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_HighlightHoveredColumn", s.flags, TF.HighlightHoveredColumn)
    for n = 0, 2 do
        local buf = string.format("Synced Table %d", n)
        local open = ImGui.CollapsingHeader(buf, ImGuiTreeNodeFlags.DefaultOpen)
        if open and ImGui.BeginTable("Table", 3, s.flags, ImVec2(0.0, ImGui.GetTextLineHeightWithSpacing() * 5)) then
            ImGui.TableSetupColumn("One")
            ImGui.TableSetupColumn("Two")
            ImGui.TableSetupColumn("Three")
            ImGui.TableHeadersRow()
            local cell_count = (n == 1) and 27 or 9 -- Make second table have a scrollbar to verify that additional decoration is not affecting column positions.
            for cell = 0, cell_count - 1 do
                ImGui.TableNextColumn()
                ImGui.Text("this cell %d", cell)
            end
            ImGui.EndTable()
        end
    end
end

local template_items_names = {
    "Banana", "Apple", "Cherry", "Watermelon", "Grapefruit", "Strawberry", "Mango",
    "Kiwi", "Orange", "Pineapple", "Blueberry", "Plum", "Coconut", "Pear", "Apricot"
}

local function Tables_Sorting()
    IMGUI_DEMO_MARKER("Tables/Sorting")
    local s = ST.sorting
    if s == nil then
        s = { items = {},
              flags = bor(TF.Resizable, TF.Reorderable, TF.Hideable, TF.Sortable, TF.SortMulti, TF.RowBg, TF.BordersOuter, TF.BordersV, TF.NoBordersInBody, TF.ScrollY) }
        for n = 0, 49 do
            local template_n = n % #template_items_names
            s.items[n + 1] = MyItem(n, template_items_names[template_n + 1], (n * n - n) % 20) -- Assign default quantities
        end
        ST.sorting = s
    end
    local items = s.items

    PushStyleCompact()
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SortMulti", s.flags, TF.SortMulti)
    ImGui.SameLine(); DemoHelpMarker("When sorting is enabled: hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).")
    _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SortTristate", s.flags, TF.SortTristate)
    ImGui.SameLine(); DemoHelpMarker("When sorting is enabled: allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).")
    PopStyleCompact()

    if ImGui.BeginTable("table_sorting", 4, s.flags, ImVec2(0.0, TEXT_BASE_HEIGHT * 15), 0.0) then
        local CF = ImGuiTableColumnFlags
        ImGui.TableSetupColumn("ID",       bor(CF.DefaultSort, CF.WidthFixed),            0.0, MyItemColumnID_ID)
        ImGui.TableSetupColumn("Name",     CF.WidthFixed,                                 0.0, MyItemColumnID_Name)
        ImGui.TableSetupColumn("Action",   bor(CF.NoSort, CF.WidthFixed),                 0.0, MyItemColumnID_Action)
        ImGui.TableSetupColumn("Quantity", bor(CF.PreferSortDescending, CF.WidthStretch), 0.0, MyItemColumnID_Quantity)
        ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible
        ImGui.TableHeadersRow()

        -- Sort our data if sort specs have been changed!
        local sort_specs = ImGui.TableGetSortSpecs()
        if sort_specs and sort_specs.SpecsDirty then
            MyItem_SortWithSortSpecs(sort_specs, items, #items)
            sort_specs.SpecsDirty = false
        end

        -- Demonstrate using clipper for large vertical lists
        local clipper = ImGuiListClipper()
        clipper:Begin(#items)
        while clipper:Step() do
            for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                -- Display a data item
                local item = items[row_n + 1]
                ImGui.PushID(item.ID)
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                ImGui.Text("%04d", item.ID)
                ImGui.TableNextColumn()
                ImGui.TextUnformatted(item.Name)
                ImGui.TableNextColumn()
                ImGui.SmallButton("None")
                ImGui.TableNextColumn()
                ImGui.Text("%d", item.Quantity)
                ImGui.PopID()
            end
        end
        ImGui.EndTable()
    end
end

local function Tables_AdvancedOptions(s)
    -- Make the UI compact because there are so many fields
    PushStyleCompact()
    ImGui.PushItemWidth(TEXT_BASE_WIDTH * 28.0)

    if ImGui.TreeNodeEx("Features:", ImGuiTreeNodeFlags.DefaultOpen) then
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags, TF.Resizable)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Reorderable", s.flags, TF.Reorderable)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Hideable", s.flags, TF.Hideable)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Sortable", s.flags, TF.Sortable)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoSavedSettings", s.flags, TF.NoSavedSettings)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ContextMenuInBody", s.flags, TF.ContextMenuInBody)
        ImGui.TreePop()
    end

    if ImGui.TreeNodeEx("Decorations:", ImGuiTreeNodeFlags.DefaultOpen) then
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_RowBg", s.flags, TF.RowBg)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersV", s.flags, TF.BordersV)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterV", s.flags, TF.BordersOuterV)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerV", s.flags, TF.BordersInnerV)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersH", s.flags, TF.BordersH)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterH", s.flags, TF.BordersOuterH)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerH", s.flags, TF.BordersInnerH)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBody", s.flags, TF.NoBordersInBody); ImGui.SameLine(); DemoHelpMarker("Disable vertical borders in columns Body (borders will always appear in Headers)")
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBodyUntilResize", s.flags, TF.NoBordersInBodyUntilResize); ImGui.SameLine(); DemoHelpMarker("Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers)")
        ImGui.TreePop()
    end

    if ImGui.TreeNodeEx("Sizing:", ImGuiTreeNodeFlags.DefaultOpen) then
        s.flags = EditTableSizingFlags(s.flags)
        ImGui.SameLine(); DemoHelpMarker("In the Advanced demo we override the policy of each column so those table-wide settings have less effect that typical.")
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendX", s.flags, TF.NoHostExtendX)
        ImGui.SameLine(); DemoHelpMarker("Make outer width auto-fit to columns, overriding outer_size.x value.\n\nOnly available when ScrollX/ScrollY are disabled and Stretch columns are not used.")
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendY", s.flags, TF.NoHostExtendY)
        ImGui.SameLine(); DemoHelpMarker("Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit).\n\nOnly available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.")
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoKeepColumnsVisible", s.flags, TF.NoKeepColumnsVisible)
        ImGui.SameLine(); DemoHelpMarker("Only available if ScrollX is disabled.")
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_PreciseWidths", s.flags, TF.PreciseWidths)
        ImGui.SameLine(); DemoHelpMarker("Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.")
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoClip", s.flags, TF.NoClip)
        ImGui.SameLine(); DemoHelpMarker("Disable clipping rectangle for every individual columns (reduce draw command count, items will be able to overflow into other columns). Generally incompatible with ScrollFreeze options.")
        ImGui.TreePop()
    end

    if ImGui.TreeNodeEx("Padding:", ImGuiTreeNodeFlags.DefaultOpen) then
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_PadOuterX", s.flags, TF.PadOuterX)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoPadOuterX", s.flags, TF.NoPadOuterX)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoPadInnerX", s.flags, TF.NoPadInnerX)
        ImGui.TreePop()
    end

    if ImGui.TreeNodeEx("Scrolling:", ImGuiTreeNodeFlags.DefaultOpen) then
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollX", s.flags, TF.ScrollX)
        ImGui.SameLine()
        ImGui.SetNextItemWidth(ImGui.GetFrameHeight())
        s.freeze_cols = ImGui.DragInt("freeze_cols", s.freeze_cols, 0.2, 0, 9, nil, ImGuiSliderFlags.NoInput)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", s.flags, TF.ScrollY)
        ImGui.SameLine()
        ImGui.SetNextItemWidth(ImGui.GetFrameHeight())
        s.freeze_rows = ImGui.DragInt("freeze_rows", s.freeze_rows, 0.2, 0, 9, nil, ImGuiSliderFlags.NoInput)
        ImGui.TreePop()
    end

    if ImGui.TreeNodeEx("Sorting:", ImGuiTreeNodeFlags.DefaultOpen) then
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SortMulti", s.flags, TF.SortMulti)
        ImGui.SameLine(); DemoHelpMarker("When sorting is enabled: hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).")
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SortTristate", s.flags, TF.SortTristate)
        ImGui.SameLine(); DemoHelpMarker("When sorting is enabled: allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).")
        ImGui.TreePop()
    end

    if ImGui.TreeNodeEx("Headers:", ImGuiTreeNodeFlags.DefaultOpen) then
        _, s.show_headers = ImGui.Checkbox("show_headers", s.show_headers)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_HighlightHoveredColumn", s.flags, TF.HighlightHoveredColumn)
        _, s.columns_base_flags = ImGui.CheckboxFlags("ImGuiTableColumnFlags_AngledHeader", s.columns_base_flags, ImGuiTableColumnFlags.AngledHeader)
        ImGui.SameLine(); DemoHelpMarker("Enable AngledHeader on all columns. Best enabled on selected narrow columns (see \"Angled headers\" section of the demo).")
        ImGui.TreePop()
    end

    if ImGui.TreeNodeEx("Other:", ImGuiTreeNodeFlags.DefaultOpen) then
        _, s.show_wrapped_text = ImGui.Checkbox("show_wrapped_text", s.show_wrapped_text)

        ImGui.DragFloat2("##OuterSize", s.outer_size_value)
        ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
        _, s.outer_size_enabled = ImGui.Checkbox("outer_size", s.outer_size_enabled)
        ImGui.SameLine()
        DemoHelpMarker("If scrolling is disabled (ScrollX and ScrollY not set):\n" ..
            "- The table is output directly in the parent window.\n" ..
            "- OuterSize.x < 0.0f will right-align the table.\n" ..
            "- OuterSize.x = 0.0f will narrow fit the table unless there are any Stretch columns.\n" ..
            "- OuterSize.y then becomes the minimum size for the table, which will extend vertically if there are more rows (unless NoHostExtendY is set).")

        s.inner_width_with_scroll = ImGui.DragFloat("inner_width (when ScrollX active)", s.inner_width_with_scroll, 1.0, 0.0, FLT_MAX)

        s.row_min_height = ImGui.DragFloat("row_min_height", s.row_min_height, 1.0, 0.0, FLT_MAX)
        ImGui.SameLine(); DemoHelpMarker("Specify height of the Selectable item.")

        s.items_count = ImGui.DragInt("items_count", s.items_count, 0.1, 0, 9999)
        local contents_type_names = { "Text", "Button", "SmallButton", "FillButton", "Selectable", "Selectable (span row)" }
        if ImGui.Combo then
            s.contents_type = ImGui.Combo("items_type (first column)", s.contents_type, contents_type_names, #contents_type_names)
        else
            NotPorted("Combo")
        end
        ImGui.TreePop()
    end

    ImGui.PopItemWidth()
    PopStyleCompact()
    ImGui.Spacing()
end

local function Tables_Advanced()
    IMGUI_DEMO_MARKER("Tables/Advanced")
    local CT_Text, CT_Button, CT_SmallButton, CT_FillButton, CT_Selectable, CT_SelectableSpanRow = 0, 1, 2, 3, 4, 5
    local s = ST.advanced
    if s == nil then
        s = { flags = bor(TF.Resizable, TF.Reorderable, TF.Hideable, TF.Sortable, TF.SortMulti, TF.RowBg, TF.Borders, TF.NoBordersInBody, TF.ScrollX, TF.ScrollY, TF.SizingFixedFit),
              columns_base_flags = ImGuiTableColumnFlags.None, contents_type = CT_SelectableSpanRow,
              freeze_cols = 1, freeze_rows = 1, items_count = #template_items_names * 2,
              outer_size_value = ImVec2(0.0, TEXT_BASE_HEIGHT * 12), row_min_height = 0.0, inner_width_with_scroll = 0.0,
              outer_size_enabled = true, show_headers = true, show_wrapped_text = false,
              items = {}, selection = {}, items_need_sort = false, show_debug_details = false }
        ST.advanced = s
    end
    if ImGui.TreeNode("Options") then
        Tables_AdvancedOptions(s)
        ImGui.TreePop()
    end

    -- Update item list if we changed the number of items
    local items = s.items
    local selection = s.selection
    if #items ~= s.items_count then
        for n = #items, s.items_count + 1, -1 do items[n] = nil end
        for n = 0, s.items_count - 1 do
            local template_n = n % #template_items_names
            items[n + 1] = MyItem(n, template_items_names[template_n + 1], (template_n == 3) and 10 or (template_n == 4) and 20 or 0) -- Assign default quantities
        end
    end

    local parent_draw_list = ImGui.GetWindowDrawList()
    local parent_draw_list_draw_cmd_count = parent_draw_list.CmdBuffer.Size
    local table_scroll_cur, table_scroll_max -- For debug display
    local table_draw_list = nil

    -- Submit table
    local flags = s.flags
    local columns_base_flags = s.columns_base_flags
    local inner_width_to_use = Has(flags, TF.ScrollX) and s.inner_width_with_scroll or 0.0
    local CF = ImGuiTableColumnFlags
    if ImGui.BeginTable("table_advanced", 6, flags, s.outer_size_enabled and s.outer_size_value or ImVec2(0, 0), inner_width_to_use) then
        ImGui.TableSetupColumn("ID",          bor(columns_base_flags, CF.DefaultSort, CF.WidthFixed, CF.NoHide), 0.0, MyItemColumnID_ID)
        ImGui.TableSetupColumn("Name",        bor(columns_base_flags, CF.WidthFixed), 0.0, MyItemColumnID_Name)
        ImGui.TableSetupColumn("Action",      bor(columns_base_flags, CF.NoSort, CF.WidthFixed), 0.0, MyItemColumnID_Action)
        ImGui.TableSetupColumn("Quantity",    bor(columns_base_flags, CF.PreferSortDescending), 0.0, MyItemColumnID_Quantity)
        ImGui.TableSetupColumn("Description", bor(columns_base_flags, Has(flags, TF.NoHostExtendX) and 0 or CF.WidthStretch), 0.0, MyItemColumnID_Description)
        ImGui.TableSetupColumn("Hidden",      bor(columns_base_flags, CF.DefaultHide, CF.NoSort))
        ImGui.TableSetupScrollFreeze(s.freeze_cols, s.freeze_rows)

        -- Sort our data if sort specs have been changed!
        local sort_specs = ImGui.TableGetSortSpecs()
        if sort_specs and sort_specs.SpecsDirty then
            s.items_need_sort = true
        end
        if sort_specs and s.items_need_sort and #items > 1 then
            MyItem_SortWithSortSpecs(sort_specs, items, #items)
            sort_specs.SpecsDirty = false
        end
        s.items_need_sort = false

        local sorts_specs_using_quantity = Has(ImGui.TableGetColumnFlags(3), CF.IsSorted)

        -- Show headers
        if s.show_headers and Has(columns_base_flags, CF.AngledHeader) then
            ImGui.TableAngledHeadersRow()
        end
        if s.show_headers then
            ImGui.TableHeadersRow()
        end

        -- Demonstrate using clipper for large vertical lists
        local clipper = ImGuiListClipper()
        clipper:Begin(#items)
        while clipper:Step() do
            for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                local item = items[row_n + 1]

                local item_is_selected = table.find(selection, item.ID) ~= nil
                ImGui.PushID(item.ID)
                ImGui.TableNextRow(ImGuiTableRowFlags.None, s.row_min_height)

                -- For the demo purpose we can select among different type of items submitted in the first column
                ImGui.TableSetColumnIndex(0)
                local label = string.format("%04d", item.ID)
                local ct = s.contents_type
                if ct == CT_Text then
                    ImGui.TextUnformatted(label)
                elseif ct == CT_Button then
                    ImGui.Button(label)
                elseif ct == CT_SmallButton then
                    ImGui.SmallButton(label)
                elseif ct == CT_FillButton then
                    ImGui.Button(label, ImVec2(-FLT_MIN, 0.0))
                elseif ct == CT_Selectable or ct == CT_SelectableSpanRow then
                    local selectable_flags = (ct == CT_SelectableSpanRow) and bor(ImGuiSelectableFlags.SpanAllColumns, ImGuiSelectableFlags.AllowOverlap) or ImGuiSelectableFlags.None
                    if ImGui.Selectable(label, item_is_selected, selectable_flags, ImVec2(0, s.row_min_height)) then
                        if ImGui.GetIO().KeyCtrl then
                            if item_is_selected then
                                table.remove(selection, table.find(selection, item.ID))
                            else
                                table.insert(selection, item.ID)
                            end
                        else
                            table.clear(selection)
                            table.insert(selection, item.ID)
                        end
                    end
                end

                if ImGui.TableSetColumnIndex(1) then
                    ImGui.TextUnformatted(item.Name)
                end

                if ImGui.TableSetColumnIndex(2) then
                    if ImGui.SmallButton("Chop") then item.Quantity = item.Quantity + 1 end
                    if sorts_specs_using_quantity and ImGui.IsItemDeactivated() then s.items_need_sort = true end
                    ImGui.SameLine()
                    if ImGui.SmallButton("Eat") then item.Quantity = item.Quantity - 1 end
                    if sorts_specs_using_quantity and ImGui.IsItemDeactivated() then s.items_need_sort = true end
                end

                if ImGui.TableSetColumnIndex(3) then
                    ImGui.Text("%d", item.Quantity)
                end

                ImGui.TableSetColumnIndex(4)
                if s.show_wrapped_text then
                    ImGui.TextWrapped("Lorem ipsum dolor sit amet")
                else
                    ImGui.Text("Lorem ipsum dolor sit amet")
                end

                if ImGui.TableSetColumnIndex(5) then
                    ImGui.Text("1234")
                end

                ImGui.PopID()
            end
        end

        -- Store some info to display debug details below
        table_scroll_cur = ImVec2(ImGui.GetScrollX(), ImGui.GetScrollY())
        table_scroll_max = ImVec2(ImGui.GetScrollMaxX(), ImGui.GetScrollMaxY())
        table_draw_list = ImGui.GetWindowDrawList()
        ImGui.EndTable()
    end
    _, s.show_debug_details = ImGui.Checkbox("Debug details", s.show_debug_details)
    if s.show_debug_details and table_draw_list then
        ImGui.SameLine(0.0, 0.0)
        local table_draw_list_draw_cmd_count = table_draw_list.CmdBuffer.Size
        if table_draw_list == parent_draw_list then
            ImGui.Text(": DrawCmd: +%d (in same window)",
                table_draw_list_draw_cmd_count - parent_draw_list_draw_cmd_count)
        else
            ImGui.Text(": DrawCmd: +%d (in child window), Scroll: (%.f/%.f) (%.f/%.f)",
                table_draw_list_draw_cmd_count - 1, table_scroll_cur.x, table_scroll_max.x, table_scroll_cur.y, table_scroll_max.y)
        end
    end
end

local tables_sections = {
    { "Basic", Tables_Basic },
    { "Borders, background", Tables_BordersBackground },
    { "Resizable, stretch", Tables_ResizableStretch },
    { "Resizable, fixed", Tables_ResizableFixed },
    { "Resizable, mixed", Tables_ResizableMixed },
    { "Reorderable, hideable, with headers", Tables_Reorderable },
    { "Padding", Tables_Padding },
    { "Sizing policies", Tables_SizingPolicies },
    { "Vertical scrolling, with clipping", Tables_VerticalScrolling },
    { "Horizontal scrolling", Tables_HorizontalScrolling },
    { "Columns flags", Tables_ColumnsFlags },
    { "Columns widths", Tables_ColumnsWidths },
    { "Nested tables", Tables_Nested },
    { "Row height", Tables_RowHeight },
    { "Outer size", Tables_OuterSize },
    { "Background color", Tables_BackgroundColor },
    { "Tree view", Tables_TreeView },
    { "Item width", Tables_ItemWidth },
    { "Custom headers", Tables_CustomHeaders },
    { "Angled headers", Tables_AngledHeaders },
    { "Context menus", Tables_ContextMenus },
    { "Synced instances", Tables_SyncedInstances },
    { "Sorting", Tables_Sorting },
    { "Advanced", Tables_Advanced },
}

function DemoWindowTables()
    if not ImGui.CollapsingHeader("Tables & Columns") then
        return
    end

    -- Using those as a base value to create width/height that are factor of the size of our font
    TEXT_BASE_WIDTH = ImGui.CalcTextSize("A").x
    TEXT_BASE_HEIGHT = ImGui.GetTextLineHeightWithSpacing()

    ImGui.PushID("Tables")

    local open_action = -1
    if ImGui.Button("Expand all") then
        open_action = 1
    end
    ImGui.SameLine()
    if ImGui.Button("Collapse all") then
        open_action = 0
    end
    ImGui.SameLine()

    -- Options
    _, ST.disable_indent = ImGui.Checkbox("Disable tree indentation", ST.disable_indent or false)
    ImGui.SameLine()
    DemoHelpMarker("Disable the indenting of tree nodes so demo tables can use the full window width.")
    ImGui.Separator()
    local disable_indent = ST.disable_indent
    if disable_indent then
        ImGui.PushStyleVar(ImGuiStyleVar.IndentSpacing, 0.0)
    end

    -- Demos
    for _, sec in ipairs(tables_sections) do
        if open_action ~= -1 then
            ImGui.SetNextItemOpen(open_action ~= 0)
        end
        if ImGui.TreeNode(sec[1]) then
            sec[2]()
            ImGui.TreePop()
        end
    end

    ImGui.PopID()

    DemoWindowColumns()

    if disable_indent then
        ImGui.PopStyleVar()
    end
end

--@@COLUMNS@@
