-- Demo: Example apps (port of imgui_demo.cpp "Example App" sections). Each ShowExampleAppXXX(p_open) returns the new p_open.
local _
local Buf, BufStr = DemoBuf, DemoBufStr

local function BufSet(buf, str)
    for i = 1, #str do buf[i] = string.byte(str, i) end
    buf[#str + 1] = 0
end

----------------------------------------------------------------
-- [SECTION] Example App: Debug Console / ShowExampleAppConsole()
----------------------------------------------------------------

local Console = nil
local function ConsoleNew()
    local c = { InputBuf = Buf("", 256), Items = {}, Commands = { "HELP", "HISTORY", "CLEAR", "CLASSIFY" }, History = {},
        HistoryPos = -1, Filter = ImGuiTextFilter(), AutoScroll = true, ScrollToBottom = false }
    function c:ClearLog() self.Items = {} end
    function c:AddLog(fmt, ...)
        local s = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
        self.Items[#self.Items + 1] = s
    end
    function c:ExecCommand(command_line)
        self:AddLog("# %s\n", command_line)
        self.HistoryPos = -1
        for i = #self.History, 1, -1 do
            if string.upper(self.History[i]) == string.upper(command_line) then table.remove(self.History, i); break end
        end
        self.History[#self.History + 1] = command_line
        local cmd = string.upper(command_line)
        if cmd == "CLEAR" then
            self:ClearLog()
        elseif cmd == "HELP" then
            self:AddLog("Commands:")
            for i = 1, #self.Commands do self:AddLog("- %s", self.Commands[i]) end
        elseif cmd == "HISTORY" then
            local first = #self.History - 10
            for i = math.max(first, 0), #self.History - 1 do self:AddLog("%3d: %s\n", i, self.History[i + 1]) end
        else
            self:AddLog("Unknown command: '%s'\n", command_line)
        end
        self.ScrollToBottom = true
    end
    function c:TextEditCallback(data)
        if data.EventFlag == ImGuiInputTextFlags.CallbackCompletion then
            -- Locate beginning of current word (positions are 0-based offsets into data.Buf)
            local word_end = data.CursorPos
            local word_start = word_end
            while word_start > 0 do
                local ch = data.Buf[word_start]
                if ch == 32 or ch == 9 or ch == 44 or ch == 59 then break end
                word_start = word_start - 1
            end
            local word = ""
            for i = word_start + 1, word_end do word = word .. string.char(data.Buf[i]) end
            local candidates = {}
            for i = 1, #self.Commands do
                if string.upper(string.sub(self.Commands[i], 1, #word)) == string.upper(word) then candidates[#candidates + 1] = self.Commands[i] end
            end
            if #candidates == 0 then
                self:AddLog("No match for \"%s\"!\n", word)
            elseif #candidates == 1 then
                data:DeleteChars(word_start, word_end - word_start)
                data:InsertChars(data.CursorPos, candidates[1])
                data:InsertChars(data.CursorPos, " ")
            else
                local match_len = word_end - word_start
                while true do
                    local ch, all_match = nil, true
                    for i = 1, #candidates do
                        local cc = string.upper(string.sub(candidates[i], match_len + 1, match_len + 1))
                        if i == 1 then ch = cc elseif ch == "" or ch ~= cc then all_match = false; break end
                    end
                    if not all_match or ch == "" then break end
                    match_len = match_len + 1
                end
                if match_len > 0 then
                    data:DeleteChars(word_start, word_end - word_start)
                    data:InsertChars(data.CursorPos, string.sub(candidates[1], 1, match_len))
                end
                self:AddLog("Possible matches:\n")
                for i = 1, #candidates do self:AddLog("- %s\n", candidates[i]) end
            end
        elseif data.EventFlag == ImGuiInputTextFlags.CallbackHistory then
            local prev_history_pos = self.HistoryPos
            if data.EventKey == ImGuiKey.UpArrow then
                if self.HistoryPos == -1 then self.HistoryPos = #self.History - 1
                elseif self.HistoryPos > 0 then self.HistoryPos = self.HistoryPos - 1 end
            elseif data.EventKey == ImGuiKey.DownArrow then
                if self.HistoryPos ~= -1 then
                    self.HistoryPos = self.HistoryPos + 1
                    if self.HistoryPos >= #self.History then self.HistoryPos = -1 end
                end
            end
            if prev_history_pos ~= self.HistoryPos then
                local history_str = (self.HistoryPos >= 0) and self.History[self.HistoryPos + 1] or ""
                data:DeleteChars(0, data.BufTextLen)
                data:InsertChars(0, history_str)
            end
        end
        return 0
    end
    function c:Draw(title, p_open)
        ImGui.SetNextWindowSize(ImVec2(520, 600), ImGuiCond.FirstUseEver)
        local visible
        p_open, visible = ImGui.Begin(title, p_open)
        if not visible then ImGui.End(); return p_open end

        if ImGui.BeginPopupContextItem() then
            if ImGui.MenuItem("Close Console") then p_open = false end
            ImGui.EndPopup()
        end
        ImGui.TextWrapped("This example implements a console with basic coloring, completion (TAB key) and history (Up/Down keys). A more elaborate implementation may want to store entries along with extra data such as timestamp, emitter, etc.")
        ImGui.TextWrapped("Enter 'HELP' for help.")
        if ImGui.SmallButton("Add Debug Text") then self:AddLog("%d some text", #self.Items); self:AddLog("some more text"); self:AddLog("display very important message here!") end
        ImGui.SameLine()
        if ImGui.SmallButton("Add Debug Error") then self:AddLog("[error] something went wrong") end
        ImGui.SameLine()
        if ImGui.SmallButton("Clear") then self:ClearLog() end
        ImGui.SameLine()
        local copy_to_clipboard = ImGui.SmallButton("Copy")
        ImGui.Separator()

        if ImGui.BeginPopup("Options") then
            _, self.AutoScroll = ImGui.Checkbox("Auto-scroll", self.AutoScroll)
            ImGui.EndPopup()
        end
        ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.O), ImGuiInputFlags.Tooltip)
        if ImGui.Button("Options") then ImGui.OpenPopup("Options") end
        ImGui.SameLine()
        ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.F), ImGuiInputFlags.Tooltip)
        ImGui.SetNextItemWidth(-FLT_MIN)
        self.Filter:DrawWithHint("##Filter", "Filter (incl -excl)")
        ImGui.Separator()

        local style = ImGui.GetStyle()
        local footer_height_to_reserve = (style.SeparatorSize or 1.0) + style.ItemSpacing.y + ImGui.GetFrameHeightWithSpacing()
        if ImGui.BeginChild("ScrollingRegion", ImVec2(0, -footer_height_to_reserve), ImGuiChildFlags.NavFlattened, ImGuiWindowFlags.HorizontalScrollbar) then
            if ImGui.BeginPopupContextWindow() then
                if ImGui.Selectable("Clear") then self:ClearLog() end
                ImGui.EndPopup()
            end
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(4, 1))
            if copy_to_clipboard then ImGui.LogToClipboard() end
            for _, item in ipairs(self.Items) do
                if self.Filter:PassFilter(item) then
                    local color
                    if string.find(item, "[error]", 1, true) then color = ImVec4(1.0, 0.4, 0.4, 1.0)
                    elseif string.sub(item, 1, 2) == "# " then color = ImVec4(1.0, 0.8, 0.6, 1.0) end
                    if color then ImGui.PushStyleColor(ImGuiCol.Text, color) end
                    ImGui.TextUnformatted(item)
                    if color then ImGui.PopStyleColor() end
                end
            end
            if copy_to_clipboard then ImGui.LogFinish() end
            if self.ScrollToBottom or (self.AutoScroll and ImGui.GetScrollY() >= ImGui.GetScrollMaxY()) then ImGui.SetScrollHereY(1.0) end
            self.ScrollToBottom = false
            ImGui.PopStyleVar()
        end
        ImGui.EndChild()
        ImGui.Separator()

        local reclaim_focus = false
        local IT = ImGuiInputTextFlags
        local input_text_flags = bit32.bor(IT.EnterReturnsTrue, IT.EscapeClearsAll, IT.CallbackCompletion, IT.CallbackHistory)
        if ImGui.InputText("Input", self.InputBuf, 256, input_text_flags, function(data) return self:TextEditCallback(data) end) then
            local s = string.gsub(BufStr(self.InputBuf), " +$", "")
            if s ~= "" then self:ExecCommand(s) end
            self.InputBuf[1] = 0
            reclaim_focus = true
        end
        ImGui.SetItemDefaultFocus()
        if reclaim_focus then ImGui.SetKeyboardFocusHere(-1) end
        ImGui.End()
        return p_open
    end
    c:AddLog("Welcome to Dear ImGui!")
    return c
end

function ShowExampleAppConsole(p_open)
    Console = Console or ConsoleNew()
    return Console:Draw("Example: Console", p_open)
end

----------------------------------------------------------------
-- [SECTION] Example App: Debug Log / ShowExampleAppLog()
----------------------------------------------------------------

-- Lines are stored as a Lua array (equivalent of Buf + LineOffsets)
local function ExampleAppLog()
    local l = { Lines = { "" }, Filter = ImGuiTextFilter(), AutoScroll = true }
    function l:Clear() self.Lines = { "" } end
    function l:AddLog(fmt, ...)
        local s = (select("#", ...) > 0) and string.format(fmt, ...) or fmt
        local lines = self.Lines
        for part, nl in string.gmatch(s, "([^\n]*)(\n?)") do
            lines[#lines] = lines[#lines] .. part
            if nl ~= "" then lines[#lines + 1] = "" end
            if part == "" and nl == "" then break end
        end
    end
    function l:Draw(title, p_open)
        local visible
        p_open, visible = ImGui.Begin(title, p_open)
        if not visible then ImGui.End(); return p_open end
        if ImGui.BeginPopup("Options") then
            _, self.AutoScroll = ImGui.Checkbox("Auto-scroll", self.AutoScroll)
            ImGui.EndPopup()
        end
        if ImGui.Button("Options") then ImGui.OpenPopup("Options") end
        ImGui.SameLine()
        local clear = ImGui.Button("Clear")
        ImGui.SameLine()
        local copy = ImGui.Button("Copy")
        ImGui.SameLine()
        ImGui.SetNextItemWidth(-FLT_MIN)
        self.Filter:DrawWithHint("##Filter", "Filter (incl -excl)")
        ImGui.Separator()
        if ImGui.BeginChild("scrolling", ImVec2(0, 0), ImGuiChildFlags.None, ImGuiWindowFlags.HorizontalScrollbar) then
            if clear then self:Clear() end
            if copy then ImGui.LogToClipboard() end
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
            local lines = self.Lines
            if self.Filter:IsActive() then
                for line_no = 1, #lines do
                    if self.Filter:PassFilter(lines[line_no]) then ImGui.TextUnformatted(lines[line_no]) end
                end
            else
                local clipper = ImGuiListClipper()
                clipper:Begin(#lines)
                while clipper:Step() do
                    for line_no = clipper.DisplayStart, clipper.DisplayEnd - 1 do ImGui.TextUnformatted(lines[line_no + 1]) end
                end
                clipper:End()
            end
            ImGui.PopStyleVar()
            if copy then ImGui.LogFinish() end
            if self.AutoScroll and ImGui.GetScrollY() >= ImGui.GetScrollMaxY() then ImGui.SetScrollHereY(1.0) end
        end
        ImGui.EndChild()
        ImGui.End()
        return p_open
    end
    return l
end

local AppLog, AppLogCounter = nil, 0
function ShowExampleAppLog(p_open)
    AppLog = AppLog or ExampleAppLog()
    ImGui.SetNextWindowSize(ImVec2(500, 400), ImGuiCond.FirstUseEver)
    p_open = ImGui.Begin("Example: Log", p_open)
    if ImGui.SmallButton("[Debug] Add 5 entries") then
        local categories = { "info", "warn", "error" }
        local words = { "Bumfuzzled", "Cattywampus", "Snickersnee", "Abibliophobia", "Absquatulate", "Nincompoop", "Pauciloquent" }
        for _ = 1, 5 do
            local category = categories[AppLogCounter % #categories + 1]
            local word = words[AppLogCounter % #words + 1]
            AppLog:AddLog("[%05d] [%s] Hello, current time is %.1f, here's a word: '%s'\n", ImGui.GetFrameCount(), category, ImGui.GetTime(), word)
            AppLogCounter = AppLogCounter + 1
        end
    end
    ImGui.End()
    return AppLog:Draw("Example: Log", p_open)
end

----------------------------------------------------------------
-- [SECTION] Example App: Simple Layout / ShowExampleAppLayout()
----------------------------------------------------------------

local LayoutSelected = 0
function ShowExampleAppLayout(p_open)
    ImGui.SetNextWindowSize(ImVec2(500, 440), ImGuiCond.FirstUseEver)
    local visible
    p_open, visible = ImGui.Begin("Example: Simple layout", p_open, ImGuiWindowFlags.MenuBar)
    if visible then
        if ImGui.BeginMenuBar() then
            if ImGui.BeginMenu("File") then
                if ImGui.MenuItem("Close", "Ctrl+W") then p_open = false end
                ImGui.EndMenu()
            end
            ImGui.EndMenuBar()
        end
        ImGui.BeginChild("left pane", ImVec2(150, 0), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeX))
        for i = 0, 99 do
            if ImGui.Selectable(string.format("MyObject %d", i), LayoutSelected == i, ImGuiSelectableFlags.SelectOnNav) then LayoutSelected = i end
        end
        ImGui.EndChild()
        ImGui.SameLine()
        ImGui.BeginGroup()
        ImGui.BeginChild("item view", ImVec2(0, -ImGui.GetFrameHeightWithSpacing()))
        ImGui.Text("MyObject: %d", LayoutSelected)
        ImGui.Separator()
        if ImGui.BeginTabBar("##Tabs", ImGuiTabBarFlags.None) then
            if ImGui.BeginTabItem("Description") then
                ImGui.TextWrapped("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ")
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Details") then
                ImGui.Text("ID: 0123456789")
                ImGui.EndTabItem()
            end
            ImGui.EndTabBar()
        end
        ImGui.EndChild()
        if ImGui.Button("Revert") then end
        ImGui.SameLine()
        if ImGui.Button("Save") then end
        ImGui.EndGroup()
    end
    ImGui.End()
    return p_open
end

----------------------------------------------------------------
-- [SECTION] Example App: Property Editor / ShowExampleAppPropertyEditor()
----------------------------------------------------------------

-- ExampleMemberInfo equivalent: field name, data type, component count
local ExampleTreeNodeMemberInfos = {
    { Name = "MyName", DataType = ImGuiDataType.String, DataCount = 1, Field = "Name" },
    { Name = "MyBool", DataType = ImGuiDataType.Bool,   DataCount = 1, Field = "DataMyBool" },
    { Name = "MyInt",  DataType = ImGuiDataType.S32,    DataCount = 1, Field = "DataMyInt" },
    { Name = "MyVec2", DataType = ImGuiDataType.Float,  DataCount = 2, Field = "DataMyVec2" },
}

local PropEd = { Filter = nil, SelectedNode = nil, UseClipper = false, NameBufs = setmetatable({}, { __mode = "k" }) }

function PropEd:IsNodePassingFilter(node)
    return node.Parent.Parent ~= nil or self.Filter:PassFilter(node.Name)
end

function PropEd:DrawTreeNode(node)
    local TN = ImGuiTreeNodeFlags
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    local tree_flags = bit32.bor(TN.OpenOnArrow, TN.OpenOnDoubleClick, TN.NavLeftJumpsToParent, TN.SpanFullWidth, TN.DrawLinesToNodes)
    if node == self.SelectedNode then tree_flags = bit32.bor(tree_flags, TN.Selected) end
    if #node.Childs == 0 then tree_flags = bit32.bor(tree_flags, TN.Leaf, TN.Bullet, TN.NoTreePushOnOpen) end
    if node.DataMyBool == false then ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetStyle().Colors[ImGuiCol.TextDisabled]) end
    ImGui.SetNextItemStorageID(node.UID)
    local is_open = ImGui.TreeNodeEx(node.UID, tree_flags, "%s", node.Name)
    if #node.Childs == 0 then is_open = false end
    if node.DataMyBool == false then ImGui.PopStyleColor() end
    if ImGui.IsItemFocused() then self.SelectedNode = node end
    return is_open
end

function PropEd:DrawTree(node)
    for _, child in ipairs(node.Childs) do
        if self:IsNodePassingFilter(child) and self:DrawTreeNode(child) then
            self:DrawTree(child)
            ImGui.TreePop()
        end
    end
end

function PropEd:DrawClippedTreeNodeAndAdvanceToNext(clipper, node)
    if self:IsNodePassingFilter(node) then
        local is_open
        if clipper.UserIndex >= clipper.DisplayStart and clipper.UserIndex < clipper.DisplayEnd then
            is_open = self:DrawTreeNode(node)
        else
            is_open = (#node.Childs > 0 and ImGui.TreeNodeGetOpen(node.UID))
            if is_open then ImGui.TreePush(node.Name) end
        end
        clipper.UserIndex = clipper.UserIndex + 1
        if is_open then return node.Childs[1] end
    end
    while node ~= nil do
        if node.IndexInParent + 1 < #node.Parent.Childs then
            return node.Parent.Childs[node.IndexInParent + 2]
        end
        node = node.Parent
        if node.Parent == nil then break end
        ImGui.TreePop()
    end
    return nil
end

function PropEd:DrawClippedTree(root_node)
    local node = root_node.Childs[1]
    local clipper = ImGuiListClipper()
    clipper:Begin(INT_MAX)
    while clipper:Step() do
        while clipper.UserIndex < clipper.DisplayEnd and node ~= nil do
            node = self:DrawClippedTreeNodeAndAdvanceToNext(clipper, node)
        end
    end
    while node ~= nil do
        node = self:DrawClippedTreeNodeAndAdvanceToNext(clipper, node)
    end
    clipper:SeekCursorForItem(clipper.UserIndex)
end

function PropEd:Draw(root_node)
    self.Filter = self.Filter or ImGuiTextFilter()
    if ImGui.BeginChild("##tree", ImVec2(300, 0), bit32.bor(ImGuiChildFlags.ResizeX, ImGuiChildFlags.Borders, ImGuiChildFlags.NavFlattened)) then
        ImGui.PushItemFlag(ImGuiItemFlags.NoNavDefaultFocus, true)
        _, self.UseClipper = ImGui.Checkbox("Use Clipper", self.UseClipper)
        ImGui.SameLine()
        ImGui.Text("(%d root nodes)", #root_node.Childs)
        ImGui.SetNextItemWidth(-FLT_MIN)
        ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.F), ImGuiInputFlags.Tooltip)
        if ImGui.InputTextWithHint("##Filter", "incl -excl", self.Filter.InputBuf, 256, ImGuiInputTextFlags.EscapeClearsAll) then
            self.Filter:Build()
        end
        ImGui.PopItemFlag()
        if ImGui.BeginTable("##list", 1, ImGuiTableFlags.RowBg) then
            if self.UseClipper then self:DrawClippedTree(root_node) else self:DrawTree(root_node) end
            ImGui.EndTable()
        end
    end
    ImGui.EndChild()

    ImGui.SameLine()
    ImGui.BeginGroup()
    local node = self.SelectedNode
    if node then
        ImGui.Text("%s", node.Name)
        ImGui.TextDisabled("UID: 0x%08X", node.UID)
        ImGui.Separator()
        if ImGui.BeginTable("##properties", 2, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.ScrollY)) then
            ImGui.PushID(node.UID)
            ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed)
            ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthStretch, 2.0)
            if node.HasData then
                for _, field_desc in ipairs(ExampleTreeNodeMemberInfos) do
                    ImGui.TableNextRow()
                    ImGui.PushID(field_desc.Name)
                    ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    ImGui.TextUnformatted(field_desc.Name)
                    ImGui.TableNextColumn()
                    local DT = ImGuiDataType
                    if field_desc.DataType == DT.Bool then
                        _, node[field_desc.Field] = ImGui.Checkbox("##Editor", node[field_desc.Field])
                    elseif field_desc.DataType == DT.S32 then
                        ImGui.SetNextItemWidth(-FLT_MIN)
                        node[field_desc.Field] = ImGui.DragScalar("##Editor", DT.S32, node[field_desc.Field], 1.0, INT_MIN or -2147483648, INT_MAX)
                    elseif field_desc.DataType == DT.Float then
                        ImGui.SetNextItemWidth(-FLT_MIN)
                        ImGui.SliderScalarN("##Editor", DT.Float, node[field_desc.Field], field_desc.DataCount, 0.0, 1.0)
                    elseif field_desc.DataType == DT.String then
                        local b = self.NameBufs[node]
                        if b == nil then b = Buf(node.Name, 28); self.NameBufs[node] = b end
                        if ImGui.InputText("##Editor", b, 28) then node.Name = BufStr(b) end
                    end
                    ImGui.PopID()
                end
            end
            ImGui.PopID()
            ImGui.EndTable()
        end
    end
    ImGui.EndGroup()
end

local DemoTree = nil
function ShowExampleAppPropertyEditor(p_open, demo_data)
    ImGui.SetNextWindowSize(ImVec2(430, 450), ImGuiCond.FirstUseEver)
    local visible
    p_open, visible = ImGui.Begin("Example: Property editor", p_open)
    if not visible then ImGui.End(); return p_open end
    if demo_data and demo_data.DemoTree == nil then demo_data.DemoTree = ExampleTree_CreateDemoTree() end
    DemoTree = (demo_data and demo_data.DemoTree) or DemoTree or ExampleTree_CreateDemoTree()
    PropEd:Draw(DemoTree)
    ImGui.End()
    return p_open
end

----------------------------------------------------------------
-- [SECTION] Example App: Long Text / ShowExampleAppLongText()
----------------------------------------------------------------

local LT = { test_type = 0, log = {}, lines = 0, bytes = 0 }
function ShowExampleAppLongText(p_open)
    ImGui.SetNextWindowSize(ImVec2(520, 600), ImGuiCond.FirstUseEver)
    local visible
    p_open, visible = ImGui.Begin("Example: Long text display", p_open)
    if not visible then ImGui.End(); return p_open end
    ImGui.Text("Printing unusually long amount of text.")
    LT.test_type = ImGui.Combo("Test type", LT.test_type, "Single call to TextUnformatted()\0Multiple calls to Text(), clipped\0Multiple calls to Text(), not clipped (slow)\0")
    ImGui.Text("Buffer contents: %d lines, %d bytes", LT.lines, LT.bytes)
    if ImGui.Button("Clear") then LT.log = {}; LT.lines = 0; LT.bytes = 0; LT.text = nil end
    ImGui.SameLine()
    if ImGui.Button("Add 1000 lines") then
        for i = 0, 999 do
            local line = string.format("%i The quick brown fox jumps over the lazy dog\n", LT.lines + i)
            LT.log[#LT.log + 1] = line
            LT.bytes = LT.bytes + #line
        end
        LT.lines = LT.lines + 1000
        LT.text = nil
    end
    ImGui.BeginChild("Log")
    if LT.test_type == 0 then
        LT.text = LT.text or table.concat(LT.log)
        ImGui.TextUnformatted(LT.text)
    elseif LT.test_type == 1 then
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
        local clipper = ImGuiListClipper()
        clipper:Begin(LT.lines)
        while clipper:Step() do
            for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do ImGui.Text("%i The quick brown fox jumps over the lazy dog", i) end
        end
        ImGui.PopStyleVar()
    else
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
        for i = 0, LT.lines - 1 do ImGui.Text("%i The quick brown fox jumps over the lazy dog", i) end
        ImGui.PopStyleVar()
    end
    ImGui.EndChild()
    ImGui.End()
    return p_open
end

----------------------------------------------------------------
-- [SECTION] Example App: Auto Resize / ShowExampleAppAutoResize()
----------------------------------------------------------------

local AutoResizeLines = 10
function ShowExampleAppAutoResize(p_open)
    local visible
    p_open, visible = ImGui.Begin("Example: Auto-resizing window", p_open, ImGuiWindowFlags.AlwaysAutoResize)
    if not visible then ImGui.End(); return p_open end
    ImGui.TextUnformatted("Window will resize every-frame to the size of its content.\nNote that you probably don't want to query the window size to\noutput your content because that would create a feedback loop.")
    AutoResizeLines = ImGui.SliderInt("Number of lines", AutoResizeLines, 1, 20)
    for i = 0, AutoResizeLines - 1 do ImGui.Text("%sThis is line %d", string.rep(" ", i * 4), i) end
    ImGui.End()
    return p_open
end

----------------------------------------------------------------
-- [SECTION] Example App: Constrained Resize / ShowExampleAppConstrainedResize()
----------------------------------------------------------------

local CR = { auto_resize = false, window_padding = true, type = 6, display_lines = 10 }
function ShowExampleAppConstrainedResize(p_open)
    local function AspectRatio(data) data.DesiredSize.y = math.floor(data.DesiredSize.x / data.UserData) end
    local function Square(data) local m = math.max(data.DesiredSize.x, data.DesiredSize.y); data.DesiredSize.x = m; data.DesiredSize.y = m end
    local function Step(data)
        local step = data.UserData
        data.DesiredSize = ImVec2(math.floor(data.DesiredSize.x / step + 0.5) * step, math.floor(data.DesiredSize.y / step + 0.5) * step)
    end
    local test_desc = { "Between 100x100 and 500x500", "At least 100x100", "Resize vertical + lock current width", "Resize horizontal + lock current height",
        "Width Between 400 and 500", "Height at least 400", "Custom: Aspect Ratio 16:9", "Custom: Always Square", "Custom: Fixed Steps (100)" }
    local t = CR.type
    if t == 0 then ImGui.SetNextWindowSizeConstraints(ImVec2(100, 100), ImVec2(500, 500)) end
    if t == 1 then ImGui.SetNextWindowSizeConstraints(ImVec2(100, 100), ImVec2(FLT_MAX, FLT_MAX)) end
    if t == 2 then ImGui.SetNextWindowSizeConstraints(ImVec2(-1, 0), ImVec2(-1, FLT_MAX)) end
    if t == 3 then ImGui.SetNextWindowSizeConstraints(ImVec2(0, -1), ImVec2(FLT_MAX, -1)) end
    if t == 4 then ImGui.SetNextWindowSizeConstraints(ImVec2(400, -1), ImVec2(500, -1)) end
    if t == 5 then ImGui.SetNextWindowSizeConstraints(ImVec2(-1, 400), ImVec2(-1, FLT_MAX)) end
    if t == 6 then ImGui.SetNextWindowSizeConstraints(ImVec2(0, 0), ImVec2(FLT_MAX, FLT_MAX), AspectRatio, 16.0 / 9.0) end
    if t == 7 then ImGui.SetNextWindowSizeConstraints(ImVec2(0, 0), ImVec2(FLT_MAX, FLT_MAX), Square) end
    if t == 8 then ImGui.SetNextWindowSizeConstraints(ImVec2(0, 0), ImVec2(FLT_MAX, FLT_MAX), Step, 100.0) end

    if not CR.window_padding then ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(0.0, 0.0)) end
    local window_flags = CR.auto_resize and ImGuiWindowFlags.AlwaysAutoResize or 0
    local window_open
    p_open, window_open = ImGui.Begin("Example: Constrained Resize", p_open, window_flags)
    if not CR.window_padding then ImGui.PopStyleVar() end
    if window_open then
        if ImGui.GetIO().KeyShift then
            local avail_size = ImGui.GetContentRegionAvail()
            local pos = ImGui.GetCursorScreenPos()
            ImGui.ColorButton("viewport", ImVec4(0.5, 0.2, 0.5, 1.0), bit32.bor(ImGuiColorEditFlags.NoTooltip, ImGuiColorEditFlags.NoDragDrop), avail_size)
            ImGui.SetCursorScreenPos(ImVec2(pos.x + 10, pos.y + 10))
            ImGui.Text("%.2f x %.2f", avail_size.x, avail_size.y)
        else
            ImGui.Text("(Hold Shift to display a dummy viewport)")
            if ImGui.IsWindowDocked() then ImGui.Text("Warning: Sizing Constraints won't work if the window is docked!") end
            if ImGui.Button("Set 200x200") then ImGui.SetWindowSize(ImVec2(200, 200)) end ImGui.SameLine()
            if ImGui.Button("Set 500x500") then ImGui.SetWindowSize(ImVec2(500, 500)) end ImGui.SameLine()
            if ImGui.Button("Set 800x200") then ImGui.SetWindowSize(ImVec2(800, 200)) end
            ImGui.SetNextItemWidth(ImGui.GetFontSize() * 20)
            CR.type = ImGui.Combo("Constraint", CR.type, test_desc, #test_desc)
            ImGui.SetNextItemWidth(ImGui.GetFontSize() * 20)
            CR.display_lines = ImGui.DragInt("Lines", CR.display_lines, 0.2, 1, 100)
            _, CR.auto_resize = ImGui.Checkbox("Auto-resize", CR.auto_resize)
            _, CR.window_padding = ImGui.Checkbox("Window padding", CR.window_padding)
            for i = 0, CR.display_lines - 1 do ImGui.Text("%sHello, sailor! Making this line long enough for the example.", string.rep(" ", i * 4)) end
        end
    end
    ImGui.End()
    return p_open
end

----------------------------------------------------------------
-- [SECTION] Example App: Simple overlay / ShowExampleAppSimpleOverlay()
----------------------------------------------------------------

local OverlayLocation = 0
function ShowExampleAppSimpleOverlay(p_open)
    local io = ImGui.GetIO()
    local W = ImGuiWindowFlags
    local window_flags = bit32.bor(W.NoDecoration, W.NoDocking, W.AlwaysAutoResize, W.NoSavedSettings, W.NoFocusOnAppearing, W.NoNav)
    if OverlayLocation >= 0 then
        local PAD = 10.0
        local viewport = ImGui.GetMainViewport()
        local work_pos, work_size = viewport.WorkPos, viewport.WorkSize
        local right, bottom = OverlayLocation % 2 == 1, OverlayLocation >= 2
        local window_pos = ImVec2(right and (work_pos.x + work_size.x - PAD) or (work_pos.x + PAD), bottom and (work_pos.y + work_size.y - PAD) or (work_pos.y + PAD))
        local window_pos_pivot = ImVec2(right and 1.0 or 0.0, bottom and 1.0 or 0.0)
        ImGui.SetNextWindowPos(window_pos, ImGuiCond.Always, window_pos_pivot)
        ImGui.SetNextWindowViewport(viewport.ID)
        window_flags = bit32.bor(window_flags, W.NoMove)
    elseif OverlayLocation == -2 then
        ImGui.SetNextWindowPos(ImGui.GetMainViewport():GetCenter(), ImGuiCond.Always, ImVec2(0.5, 0.5))
        window_flags = bit32.bor(window_flags, W.NoMove)
    end
    ImGui.SetNextWindowBgAlpha(0.35)
    local visible
    p_open, visible = ImGui.Begin("Example: Simple overlay", p_open, window_flags)
    if visible then
        ImGui.Text("Simple overlay\n(right-click to change position)")
        ImGui.Separator()
        if ImGui.IsMousePosValid() then ImGui.Text("Mouse Position: (%.1f,%.1f)", io.MousePos.x, io.MousePos.y) else ImGui.Text("Mouse Position: <invalid>") end
        if ImGui.BeginPopupContextWindow() then
            if ImGui.MenuItem("Custom", nil, OverlayLocation == -1) then OverlayLocation = -1 end
            if ImGui.MenuItem("Center", nil, OverlayLocation == -2) then OverlayLocation = -2 end
            if ImGui.MenuItem("Top-left", nil, OverlayLocation == 0) then OverlayLocation = 0 end
            if ImGui.MenuItem("Top-right", nil, OverlayLocation == 1) then OverlayLocation = 1 end
            if ImGui.MenuItem("Bottom-left", nil, OverlayLocation == 2) then OverlayLocation = 2 end
            if ImGui.MenuItem("Bottom-right", nil, OverlayLocation == 3) then OverlayLocation = 3 end
            if p_open ~= nil and ImGui.MenuItem("Close") then p_open = false end
            ImGui.EndPopup()
        end
    end
    ImGui.End()
    return p_open
end

----------------------------------------------------------------
-- [SECTION] Example App: Fullscreen window / ShowExampleAppFullscreen()
----------------------------------------------------------------

local FS = { use_work_area = true, flags = bit32.bor(ImGuiWindowFlags.NoDecoration, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoSavedSettings) }
function ShowExampleAppFullscreen(p_open)
    local viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(FS.use_work_area and viewport.WorkPos or viewport.Pos)
    ImGui.SetNextWindowSize(FS.use_work_area and viewport.WorkSize or viewport.Size)
    local visible
    p_open, visible = ImGui.Begin("Example: Fullscreen window", p_open, FS.flags)
    if visible then
        _, FS.use_work_area = ImGui.Checkbox("Use work area instead of main area", FS.use_work_area)
        ImGui.SameLine()
        HelpMarker("Main Area = entire viewport,\nWork Area = entire viewport minus sections used by the main menu bars, task bars etc.\n\nEnable the main-menu bar in Examples menu to see the difference.")
        local W = ImGuiWindowFlags
        _, FS.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoBackground", FS.flags, W.NoBackground)
        _, FS.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoDecoration", FS.flags, W.NoDecoration)
        ImGui.Indent()
        _, FS.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoTitleBar", FS.flags, W.NoTitleBar)
        _, FS.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoCollapse", FS.flags, W.NoCollapse)
        _, FS.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoScrollbar", FS.flags, W.NoScrollbar)
        ImGui.Unindent()
        if p_open ~= nil and ImGui.Button("Close this window") then p_open = false end
    end
    ImGui.End()
    return p_open
end

----------------------------------------------------------------
-- [SECTION] Example App: Manipulating window titles / ShowExampleAppWindowTitles()
----------------------------------------------------------------

function ShowExampleAppWindowTitles(p_open)
    local viewport = ImGui.GetMainViewport()
    local base_pos = viewport.Pos
    ImGui.SetNextWindowPos(ImVec2(base_pos.x + 100, base_pos.y + 100), ImGuiCond.FirstUseEver)
    ImGui.Begin("Same title as another window##1")
    ImGui.Text("This is window 1.\nMy title is the same as window 2, but my identifier is unique.")
    ImGui.End()
    ImGui.SetNextWindowPos(ImVec2(base_pos.x + 100, base_pos.y + 200), ImGuiCond.FirstUseEver)
    ImGui.Begin("Same title as another window##2")
    ImGui.Text("This is window 2.\nMy title is the same as window 1, but my identifier is unique.")
    ImGui.End()
    local spin = "|/-\\"
    local k = math.floor(ImGui.GetTime() / 0.25) % 4 + 1
    local buf = string.format("Animated title %s %d###AnimatedTitle", string.sub(spin, k, k), ImGui.GetFrameCount())
    ImGui.SetNextWindowPos(ImVec2(base_pos.x + 100, base_pos.y + 300), ImGuiCond.FirstUseEver)
    ImGui.Begin(buf)
    ImGui.Text("This window has a changing title.")
    ImGui.End()
    return p_open
end

----------------------------------------------------------------
-- [SECTION] Example App: Custom Rendering using ImDrawList API / ShowExampleAppCustomRendering()
----------------------------------------------------------------

local CRS = { sz = 42.0, base_rounding = 8.0, base_thickness = 3.0, animate_rounding = false, animate_thickness = false, ngon_segments = 6,
    circle_override = false, circle_override_v = 12, curve_override = false, curve_override_v = 8,
    colf_stroke = ImVec4(1.000, 0.384, 0.169, 1.000), colf_fill = ImVec4(0.416, 0.378, 0.420, 1.000),
    points = {}, scrolling = ImVec2(0.0, 0.0), opt_enable_grid = true, opt_enable_context_menu = true, adding_line = false,
    draw_bg = true, draw_fg = true }

local function CustomRenderingPrimitives()
    local s = CRS
    ImGui.PushItemWidth(-ImGui.GetFontSize() * 15)
    ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInput, true)
    local draw_list = ImGui.GetWindowDrawList()

    ImGui.Text("Gradients")
    local gradient_size = ImVec2(ImGui.CalcItemWidth(), ImGui.GetFrameHeight())
    ImGui.InvisibleButton("##gradient1", gradient_size)
    local col_a, col_b = ImGui.GetColorU32(IM_COL32(0, 0, 0, 255), nil, true), ImGui.GetColorU32(IM_COL32(255, 255, 255, 255), nil, true)
    draw_list:AddRectFilledMultiColor(ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), col_a, col_b, col_b, col_a)
    ImGui.InvisibleButton("##gradient2", gradient_size)
    col_a, col_b = ImGui.GetColorU32(IM_COL32(0, 255, 0, 255), nil, true), ImGui.GetColorU32(IM_COL32(255, 0, 0, 255), nil, true)
    draw_list:AddRectFilledMultiColor(ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), col_a, col_b, col_b, col_a)

    ImGui.Text("All primitives")
    s.sz = ImGui.DragFloat("Size", s.sz, 0.2, 0.2, 100.0, "%.0f")
    local t = ImGui.GetTime()
    local rounding_wave = 1.0 - math.abs((t % 3.0) * (2.0 / 3.0) - 1.0)
    local rounding = s.animate_rounding and (math.floor(rounding_wave * s.base_rounding * 10.0) / 10.0) or s.base_rounding
    s.base_rounding = ImGui.DragFloat("Rounding", s.base_rounding, 0.02, 0.0, 32.0, "%.1f"); ImGui.SameLine()
    _, s.animate_rounding = ImGui.Checkbox("Animate##rounding", s.animate_rounding); ImGui.SameLine()
    ImGui.Text("%.2f", rounding)
    local thickness_wave = 1.0 - math.abs((t % 5.0) * (2.0 / 5.0) - 1.0)
    local thickness = s.animate_thickness and (thickness_wave * s.base_thickness) or s.base_thickness
    s.base_thickness = ImGui.DragFloat("Thickness", s.base_thickness, 0.02, 0.0, 32.0, "%.02f"); ImGui.SameLine()
    _, s.animate_thickness = ImGui.Checkbox("Animate##thickness", s.animate_thickness); ImGui.SameLine()
    ImGui.Text("%.2f", thickness)
    s.ngon_segments = ImGui.SliderInt("N-gon sides", s.ngon_segments, 3, 12)
    local changed
    _, s.circle_override = ImGui.Checkbox("##CircleSegmentOverride", s.circle_override)
    ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
    s.circle_override_v, changed = ImGui.SliderInt("Circle segments override", s.circle_override_v, 3, 30)
    s.circle_override = s.circle_override or changed
    _, s.curve_override = ImGui.Checkbox("##CurvesSegmentOverride", s.curve_override)
    ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
    s.curve_override_v, changed = ImGui.SliderInt("Curves segments override", s.curve_override_v, 3, 30)
    s.curve_override = s.curve_override or changed
    ImGui.ColorEdit4("Stroke Color", s.colf_stroke)
    ImGui.ColorEdit4("Fill Color", s.colf_fill)
    ImGui.SeparatorText("Per primitive flags (AddXXX functions)")
    ImGui.TextDisabled("(stroke placement/AA flags: not ported, this port uses the 1.92 stroker)")
    ImGui.Spacing()

    local sz = s.sz
    local start_pos = ImGui.GetCursorScreenPos()
    local pi = 3.141592
    local step = sz + 10.0
    local corners_tl_br = bit32.bor(ImDrawFlags.RoundCornersTopLeft, ImDrawFlags.RoundCornersBottomRight)
    local half_sz = sz * 0.5
    local circle_segments = s.circle_override and s.circle_override_v or 0
    local curve_segments = s.curve_override and s.curve_override_v or 0
    local cp3 = { ImVec2(0.0, sz * 0.6), ImVec2(sz * 0.5, -sz * 0.4), ImVec2(sz, sz) }
    local cp4 = { ImVec2(0.0, 0.0), ImVec2(sz * 1.3, sz * 0.3), ImVec2(sz - sz * 1.3, sz - sz * 0.3), ImVec2(sz, sz) }
    local concave_shape = { { 0.0, 0.0 }, { 0.3, 0.0 }, { 0.3, 0.7 }, { 0.7, 0.7 }, { 0.7, 0.0 }, { 1.0, 0.0 }, { 1.0, 1.0 }, { 0.0, 1.0 } }
    local zigzag_shape = { { 0.0, 0.0 }, { 0.9, 0.0 }, { 1.0, 0.1 }, { 1.0, 0.9 }, { 0.9, 1.0 }, { 0.3, 1.0 }, { 0.3, 0.4 }, { 0.9, 0.4 } }
    local rotating_square = {}
    for side = 0, 3 do
        local a = t * 0.1 + side * pi * 0.5
        rotating_square[side + 1] = ImVec2(math.cos(a) * half_sz, math.sin(a) * half_sz)
    end
    local function Shape(shape, x, y)
        for _, p in ipairs(shape) do draw_list:PathLineTo(ImVec2(x + math.floor(sz * p[1]), y + math.floor(sz * p[2]))) end
    end

    local y = start_pos.y
    for row = 0, 3 do
        local x = start_pos.x
        local draw_fill = (row == 2 or row == 3)
        local draw_strokes = (row == 0 or row == 1 or row == 3)
        if draw_fill then
            local col = ImGui.ColorConvertFloat4ToU32(s.colf_fill)
            draw_list:AddNgonFilled(ImVec2(x + half_sz, y + half_sz), half_sz, col, s.ngon_segments); x = x + step
            draw_list:AddCircleFilled(ImVec2(x + half_sz, y + half_sz), half_sz, col, circle_segments); x = x + step
            draw_list:AddEllipseFilled(ImVec2(x + half_sz, y + half_sz), ImVec2(half_sz, sz * 0.3), col, -0.3, circle_segments); x = x + step
            draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + sz, y + sz), col); x = x + step
            draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + sz, y + sz), col, rounding); x = x + step
            draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + sz, y + sz), col, rounding, corners_tl_br); x = x + step
            draw_list:AddTriangleFilled(ImVec2(x + sz * 0.5, y), ImVec2(x + sz, y + sz), ImVec2(x, y + sz), col); x = x + step
            draw_list:AddTriangleFilled(ImVec2(x + sz * 0.2, y), ImVec2(x + sz * 0.4, y + sz), ImVec2(x, y + sz), col); x = x + step - math.floor(sz * 0.6)
            Shape(concave_shape, x, y); draw_list:PathFillConcave(col); x = x + step
            Shape(zigzag_shape, x, y); draw_list:PathFillConcave(col); x = x + step
            draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + sz, y + thickness), col); x = x + step
            draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + thickness, y + sz), col); x = x + step - math.floor(half_sz)
            if not (draw_fill and draw_strokes) then
                local block_sz, off = 1, 0
                while block_sz < 16 and off + block_sz <= sz do
                    draw_list:AddRectFilled(ImVec2(x, y + off), ImVec2(x + block_sz, y + off + block_sz), col)
                    off = off + block_sz + 1
                    block_sz = block_sz + 1
                end
            end
            x = x + step - math.floor(half_sz)
            for n = 1, 4 do draw_list:PathLineTo(ImVec2(x + half_sz + rotating_square[n].x, y + half_sz + rotating_square[n].y)) end
            draw_list:PathFillConvex(col); x = x + step
            draw_list:PathArcTo(ImVec2(x + half_sz, y + half_sz), half_sz, pi * -0.5, pi * 1.1)
            draw_list:PathFillConvex(col); x = x + step
            draw_list:PathLineTo(ImVec2(x + cp3[1].x, y + cp3[1].y))
            draw_list:PathBezierQuadraticCurveTo(ImVec2(x + cp3[2].x, y + cp3[2].y), ImVec2(x + cp3[3].x, y + cp3[3].y), curve_segments)
            draw_list:PathFillConvex(col); x = x + step
            if not (draw_fill and draw_strokes) then
                draw_list:AddRectFilledMultiColor(ImVec2(x, y), ImVec2(x + sz, y + sz), IM_COL32(0, 0, 0, 255), IM_COL32(255, 0, 0, 255), IM_COL32(255, 255, 0, 255), IM_COL32(0, 255, 0, 255))
                x = x + step
            end
        end
        if draw_fill and draw_strokes then x = start_pos.x end
        if draw_strokes then
            local col = ImGui.ColorConvertFloat4ToU32(s.colf_stroke)
            local th = (row == 0) and 1.0 or thickness
            draw_list:AddNgon(ImVec2(x + half_sz, y + half_sz), half_sz, col, s.ngon_segments, th); x = x + step
            draw_list:AddCircle(ImVec2(x + half_sz, y + half_sz), half_sz, col, circle_segments, th); x = x + step
            draw_list:AddEllipse(ImVec2(x + half_sz, y + half_sz), ImVec2(half_sz, sz * 0.3), col, -0.3, circle_segments, th); x = x + step
            draw_list:AddRect(ImVec2(x, y), ImVec2(x + sz, y + sz), col, 0.0, th); x = x + step
            draw_list:AddRect(ImVec2(x, y), ImVec2(x + sz, y + sz), col, rounding, th); x = x + step
            draw_list:AddRect(ImVec2(x, y), ImVec2(x + sz, y + sz), col, rounding, th, corners_tl_br); x = x + step
            draw_list:AddTriangle(ImVec2(x + sz * 0.5, y), ImVec2(x + sz, y + sz), ImVec2(x, y + sz), col, th); x = x + step
            draw_list:AddTriangle(ImVec2(x + sz * 0.2, y), ImVec2(x + sz * 0.4, y + sz), ImVec2(x, y + sz), col, th); x = x + step - math.floor(sz * 0.6)
            Shape(concave_shape, x, y); draw_list:PathStroke(col, th, ImDrawFlags.Closed); x = x + step
            Shape(zigzag_shape, x, y); draw_list:PathStroke(col, th, ImDrawFlags.Closed); x = x + step
            local off = math.floor(sz * 0.4)
            draw_list:AddLine(ImVec2(x, y), ImVec2(x + sz, y), col, th)
            draw_list:AddLine(ImVec2(x, y + off), ImVec2(x + sz, y + off), col, th); x = x + step
            draw_list:AddLine(ImVec2(x, y), ImVec2(x, y + sz), col, th)
            draw_list:AddLine(ImVec2(x + off, y + sz), ImVec2(x + off, y), col, th); x = x + step - math.floor(half_sz)
            if not (draw_fill and draw_strokes) then
                draw_list:AddLine(ImVec2(x, y), ImVec2(x + half_sz, y + sz), col, th)
                draw_list:AddLine(ImVec2(x, y + sz), ImVec2(x + half_sz, y), col, th)
            end
            x = x + step - math.floor(half_sz)
            for n = 1, 4 do draw_list:PathLineTo(ImVec2(x + half_sz + rotating_square[n].x, y + half_sz + rotating_square[n].y)) end
            draw_list:PathStroke(col, th, ImDrawFlags.Closed); x = x + step
            draw_list:PathArcTo(ImVec2(x + half_sz, y + half_sz), half_sz, pi * -0.5, pi * 1.1)
            draw_list:PathStroke(col, th); x = x + step
            draw_list:AddBezierQuadratic(ImVec2(x + cp3[1].x, y + cp3[1].y), ImVec2(x + cp3[2].x, y + cp3[2].y), ImVec2(x + cp3[3].x, y + cp3[3].y), col, th, curve_segments); x = x + step
            if not (draw_fill and draw_strokes) then
                draw_list:AddBezierCubic(ImVec2(x + cp4[1].x, y + cp4[1].y), ImVec2(x + cp4[2].x, y + cp4[2].y), ImVec2(x + cp4[3].x, y + cp4[3].y), ImVec2(x + cp4[4].x, y + cp4[4].y), col, th, curve_segments)
                x = x + step
            end
        end
        y = y + step
    end
    ImGui.Dummy(ImVec2(step * 15.5, step * 4.0))
    ImGui.Text("ImDrawList Vector Rendering Reference:")
    ImGui.TextLinkOpenURL("https://github.com/ocornut/imgui/wiki/Draw-List")
    ImGui.PopItemFlag()
    ImGui.PopItemWidth()
end

local function CustomRenderingCanvas()
    local s = CRS
    _, s.opt_enable_grid = ImGui.Checkbox("Enable grid", s.opt_enable_grid)
    _, s.opt_enable_context_menu = ImGui.Checkbox("Enable context menu", s.opt_enable_context_menu)
    ImGui.Text("Mouse Left: drag to add lines,\nMouse Right: drag to scroll, click for context menu.")
    local canvas_p0 = ImGui.GetCursorScreenPos()
    local canvas_sz = ImGui.GetContentRegionAvail()
    if canvas_sz.x < 50.0 then canvas_sz.x = 50.0 end
    if canvas_sz.y < 50.0 then canvas_sz.y = 50.0 end
    local canvas_p1 = ImVec2(canvas_p0.x + canvas_sz.x, canvas_p0.y + canvas_sz.y)
    local io = ImGui.GetIO()
    local draw_list = ImGui.GetWindowDrawList()
    draw_list:AddRectFilled(canvas_p0, canvas_p1, IM_COL32(50, 50, 50, 255))
    draw_list:AddRect(canvas_p0, canvas_p1, IM_COL32(255, 255, 255, 255))

    ImGui.InvisibleButton("canvas", canvas_sz, bit32.bor(ImGuiButtonFlags.MouseButtonLeft, ImGuiButtonFlags.MouseButtonRight))
    local is_hovered = ImGui.IsItemHovered()
    local is_active = ImGui.IsItemActive()
    local origin = ImVec2(canvas_p0.x + s.scrolling.x, canvas_p0.y + s.scrolling.y)
    local mouse_pos_in_canvas = ImVec2(io.MousePos.x - origin.x, io.MousePos.y - origin.y)
    local points = s.points
    if is_hovered and not s.adding_line and ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
        points[#points + 1] = ImVec2(mouse_pos_in_canvas.x, mouse_pos_in_canvas.y)
        points[#points + 1] = ImVec2(mouse_pos_in_canvas.x, mouse_pos_in_canvas.y)
        s.adding_line = true
    end
    if s.adding_line then
        points[#points] = ImVec2(mouse_pos_in_canvas.x, mouse_pos_in_canvas.y)
        if not ImGui.IsMouseDown(ImGuiMouseButton.Left) then s.adding_line = false end
    end
    local mouse_threshold_for_pan = s.opt_enable_context_menu and -1.0 or 0.0
    if is_active and ImGui.IsMouseDragging(ImGuiMouseButton.Right, mouse_threshold_for_pan) then
        s.scrolling.x = s.scrolling.x + io.MouseDelta.x
        s.scrolling.y = s.scrolling.y + io.MouseDelta.y
    end
    local drag_delta = ImGui.GetMouseDragDelta(ImGuiMouseButton.Right)
    if s.opt_enable_context_menu and drag_delta.x == 0.0 and drag_delta.y == 0.0 then
        ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
    end
    if ImGui.BeginPopup("context") then
        if s.adding_line then points[#points] = nil; points[#points] = nil end
        s.adding_line = false
        if ImGui.MenuItem("Remove one", nil, false, #points > 0) then points[#points] = nil; points[#points] = nil end
        if ImGui.MenuItem("Remove all", nil, false, #points > 0) then table.clear(points) end
        ImGui.EndPopup()
    end
    draw_list:PushClipRect(canvas_p0, canvas_p1, true)
    if s.opt_enable_grid then
        local GRID_STEP = 64.0
        local x = math.fmod(s.scrolling.x, GRID_STEP)
        while x < canvas_sz.x do draw_list:AddLine(ImVec2(canvas_p0.x + x, canvas_p0.y), ImVec2(canvas_p0.x + x, canvas_p1.y), IM_COL32(200, 200, 200, 40)); x = x + GRID_STEP end
        local y = math.fmod(s.scrolling.y, GRID_STEP)
        while y < canvas_sz.y do draw_list:AddLine(ImVec2(canvas_p0.x, canvas_p0.y + y), ImVec2(canvas_p1.x, canvas_p0.y + y), IM_COL32(200, 200, 200, 40)); y = y + GRID_STEP end
    end
    for n = 1, #points - 1, 2 do
        draw_list:AddLine(ImVec2(origin.x + points[n].x, origin.y + points[n].y), ImVec2(origin.x + points[n + 1].x, origin.y + points[n + 1].y), IM_COL32(255, 255, 0, 255), 2.0)
    end
    draw_list:PopClipRect()
end

function ShowExampleAppCustomRendering(p_open)
    local visible
    p_open, visible = ImGui.Begin("Example: Custom rendering", p_open)
    if not visible then ImGui.End(); return p_open end
    local s = CRS
    if ImGui.BeginTabBar("##TabBar") then
        if ImGui.BeginTabItem("Primitives") then CustomRenderingPrimitives(); ImGui.EndTabItem() end
        if ImGui.BeginTabItem("Canvas") then CustomRenderingCanvas(); ImGui.EndTabItem() end
        if ImGui.BeginTabItem("BG/FG draw lists") then
            _, s.draw_bg = ImGui.Checkbox("Draw in Background draw list", s.draw_bg)
            ImGui.SameLine(); HelpMarker("The Background draw list will be rendered below every Dear ImGui windows.")
            _, s.draw_fg = ImGui.Checkbox("Draw in Foreground draw list", s.draw_fg)
            ImGui.SameLine(); HelpMarker("The Foreground draw list will be rendered over every Dear ImGui windows.")
            local window_pos, window_size = ImGui.GetWindowPos(), ImGui.GetWindowSize()
            local window_center = ImVec2(window_pos.x + window_size.x * 0.5, window_pos.y + window_size.y * 0.5)
            if s.draw_bg then ImGui.GetBackgroundDrawList():AddCircle(window_center, window_size.x * 0.6, IM_COL32(255, 0, 0, 200), 0, 10 + 4) end
            if s.draw_fg then ImGui.GetForegroundDrawList():AddCircle(window_center, window_size.y * 0.6, IM_COL32(0, 255, 0, 200), 0, 10) end
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem("Draw Channels") then
            local draw_list = ImGui.GetWindowDrawList()
            ImGui.Text("Blue shape is drawn first: appears in back")
            ImGui.Text("Red shape is drawn after: appears in front")
            local p0 = ImGui.GetCursorScreenPos()
            draw_list:AddRectFilled(ImVec2(p0.x, p0.y), ImVec2(p0.x + 50, p0.y + 50), IM_COL32(0, 0, 255, 255))
            draw_list:AddRectFilled(ImVec2(p0.x + 25, p0.y + 25), ImVec2(p0.x + 75, p0.y + 75), IM_COL32(255, 0, 0, 255))
            ImGui.Dummy(ImVec2(75, 75))
            ImGui.Separator()
            ImGui.Text("Blue shape is drawn first, into channel 1: appears in front")
            ImGui.Text("Red shape is drawn after, into channel 0: appears in back")
            local p1 = ImGui.GetCursorScreenPos()
            draw_list:ChannelsSplit(2)
            draw_list:ChannelsSetCurrent(1)
            draw_list:AddRectFilled(ImVec2(p1.x, p1.y), ImVec2(p1.x + 50, p1.y + 50), IM_COL32(0, 0, 255, 255))
            draw_list:ChannelsSetCurrent(0)
            draw_list:AddRectFilled(ImVec2(p1.x + 25, p1.y + 25), ImVec2(p1.x + 75, p1.y + 75), IM_COL32(255, 0, 0, 255))
            draw_list:ChannelsMerge()
            ImGui.Dummy(ImVec2(75, 75))
            ImGui.Text("After reordering, contents of channel 0 appears below channel 1.")
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
    ImGui.End()
    return p_open
end

return true
