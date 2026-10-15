-- Multi-select / box-select / typing-select: ImGuiSelectionBasicStorage + Selectable list (click, Ctrl+click, Shift+click, Ctrl+A,
-- Escape, box-select drag, keyboard nav + Shift, typing-select), ImGuiListClipper + IncludeItemByIndex(RangeSrcItem),
-- ImGuiSelectionExternalStorage on a bool array, checkboxes and tree nodes inside a multi-select scope.
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local MSF = G.ImGuiMultiSelectFlags
ImGui.CreateContext(); G.ImGui_ImplRoblox.Init()
local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.NavEnableKeyboard)
local failed = {}
local function check(ok, msg) if not ok then table.insert(failed, msg); print("FAIL " .. msg) end end

local NAMES = { "Apple", "Apricot", "Banana", "Blueberry", "Cherry", "Coconut", "Date", "Durian", "Elderberry", "Fig",
    "Grape", "Guava", "Kiwi", "Lemon", "Lime", "Mango", "Melon", "Orange", "Papaya", "Peach" }
local N = #NAMES

-- Iterate with GetNextSelectedItem() (sorted by key) -> "a,b,c"
local function sel_str(sel)
    local out, it, id, has_more = {}, nil, 0, false
    while true do
        has_more, it, id = sel:GetNextSelectedItem(it)
        if not has_more then break end
        table.insert(out, tostring(id))
    end
    return table.concat(out, ",")
end
local function bools_str(t, n)
    local out = {}
    for i = 1, n do if t[i] then table.insert(out, tostring(i - 1)) end end
    return table.concat(out, ",")
end

local sel_list = G.ImGuiSelectionBasicStorage()
local sel_clip = G.ImGuiSelectionBasicStorage()
local sel_tree = G.ImGuiSelectionBasicStorage()
local ext_bools = {}
local sel_ext = G.ImGuiSelectionExternalStorage()
sel_ext.UserData = ext_bools
sel_ext.AdapterSetItemSelected = function(self, idx, selected) self.UserData[idx + 1] = selected end
local chk_bools = {}
local sel_chk = G.ImGuiSelectionExternalStorage()
sel_chk.UserData = chk_bools
sel_chk.AdapterSetItemSelected = function(self, idx, selected) self.UserData[idx + 1] = selected end

local rects = {}  -- [name] = { min, max } (copies)
local ids = {}    -- [name] = item id
local function rect() local a, b = ImGui.GetItemRectMin(), ImGui.GetItemRectMax(); return { ImVec2(a.x, a.y), ImVec2(b.x, b.y) } end
local function center(name) local r = rects[name]; return (r[1].x + r[2].x) / 2, (r[1].y + r[2].y) / 2 end
local function key(k) io:AddKeyEvent(k, true); io:AddKeyEvent(k, false) end
local function mods(ctrl, shift) io:AddKeyEvent(G.ImGuiMod_Ctrl, ctrl == true); io:AddKeyEvent(G.ImGuiMod_Shift, shift == true) end

-- Schedule: each step = { input = fn (before NewFrame), check = fn (after Render) }. Steps run on consecutive frames.
local steps = {}
local function step(input, chk) table.insert(steps, { input = input, check = chk }) end
local function idle(n) for _ = 1, n or 1 do step(nil, nil) end end
-- click: press (+mods) on frame A, release on frame B, then one idle frame for EndMultiSelect requests to be applied
local function click(name, ctrl, shift)
    step(function() mods(ctrl, shift); io:AddMousePosEvent(center(name)); io:AddMouseButtonEvent(0, true) end)
    step(function() io:AddMouseButtonEvent(0, false) end)
    step(function() mods(false, false) end)
end

local typed_focus_idx = -1
local clip_scroll_request = false
local f = 0

idle(3)
-- 1. List: click selects one
click("L2"); step(nil, function() check(sel_str(sel_list) == "2", "click: " .. sel_str(sel_list)) end)
-- 2. Ctrl+click toggles
click("L5", true); step(nil, function() check(sel_str(sel_list) == "2,5", "ctrl+click add: " .. sel_str(sel_list)) end)
click("L2", true); step(nil, function() check(sel_str(sel_list) == "5", "ctrl+click remove: " .. sel_str(sel_list)) end)
-- 3. Shift+click range (from RangeSrc = 2, the last Ctrl+clicked item)
click("L8", false, true); step(nil, function() check(sel_str(sel_list) == "2,3,4,5,6,7,8", "shift+click range: " .. sel_str(sel_list)) end)
-- 4. Ctrl+A
step(function() io:AddKeyEvent(G.ImGuiMod_Ctrl, true); io:AddKeyEvent(G.ImGuiKey.A, true) end)
step(function() io:AddKeyEvent(G.ImGuiKey.A, false); io:AddKeyEvent(G.ImGuiMod_Ctrl, false) end)
step(nil, function() check(sel_list.Size == N, "ctrl+A size " .. sel_list.Size) end)
-- 5. Escape clears (ClearOnEscape)
step(function() key(G.ImGuiKey.Escape) end)
step(nil, function() check(sel_list.Size == 0 and sel_str(sel_list) == "", "escape clear: " .. sel_str(sel_list)) end)
-- 6. Box-select drag (BoxSelect1d) from item 2 to item 5
step(function() io:AddMousePosEvent(center("L2")); io:AddMouseButtonEvent(0, true) end)
step(function() local x, y = center("L2"); io:AddMousePosEvent(x + 2, y + 10) end)
step(function() local x, y = center("L4"); io:AddMousePosEvent(x + 4, y) end)
step(function() local x, y = center("L5"); io:AddMousePosEvent(x + 4, y) end,
    function() check(ImGui.GetCurrentContext().BoxSelectState.IsActive, "box-select active while dragging") end)
step(nil)
step(function() io:AddMouseButtonEvent(0, false) end)
step(nil, function() check(sel_str(sel_list) == "2,3,4,5", "box-select: " .. sel_str(sel_list)); check(not ImGui.GetCurrentContext().BoxSelectState.IsActive, "box-select ended") end)
-- 7. Keyboard nav: click 3, Down -> 4 (auto-select), Shift+Down x2 -> 4..6
click("L3"); step(nil, function() check(sel_str(sel_list) == "3", "click before nav: " .. sel_str(sel_list)) end)
step(function() key(G.ImGuiKey.DownArrow) end); idle(2)
step(nil, function() check(sel_str(sel_list) == "4", "nav down auto-select: " .. sel_str(sel_list)) end)
step(function() io:AddKeyEvent(G.ImGuiMod_Shift, true); key(G.ImGuiKey.DownArrow) end); idle(1)
step(function() key(G.ImGuiKey.DownArrow) end); idle(1)
step(function() io:AddKeyEvent(G.ImGuiMod_Shift, false) end); idle(1)
step(nil, function() check(sel_str(sel_list) == "4,5,6", "shift+nav range: " .. sel_str(sel_list)) end)
-- 8. Typing-select: "ch" -> Cherry (5), then single-char mode "b" "b" -> Banana (2) then Blueberry (3)
step(function() io:AddInputCharacter(string.byte("c")); io:AddInputCharacter(string.byte("h")) end); idle(2)
step(nil, function() check(ImGui.GetCurrentContext().NavId == ids.L4, "typing 'ch' -> Cherry"); check(sel_str(sel_list) == "4", "typing focus selects: " .. sel_str(sel_list)) end)
idle(120) -- TYPING_SELECT_RESET_TIMER
step(function() io:AddInputCharacter(string.byte("b")) end); idle(2)
step(nil, function() check(ImGui.GetCurrentContext().NavId == ids.L2, "typing 'b' -> Banana") end)
step(function() io:AddInputCharacter(string.byte("b")) end); idle(2)
step(nil, function() check(ImGui.GetCurrentContext().NavId == ids.L3, "typing 'bb' -> Blueberry") end)
idle(120)

-- 9. Clipper (1000 items): click 5, scroll down, Shift+click item 40 -> 5..40 (RangeSrcItem 5 kept submitted by IncludeItemByIndex)
click("C5")
-- move NavId away with Ctrl+Down (no selection change, RangeSrc stays 5) so the clipper doesn't keep item 5 alive as the nav item
step(function() io:AddKeyEvent(G.ImGuiMod_Ctrl, true); key(G.ImGuiKey.DownArrow) end); idle(1)
step(function() key(G.ImGuiKey.DownArrow) end); idle(1)
step(function() key(G.ImGuiKey.DownArrow) end); idle(1)
step(function() io:AddKeyEvent(G.ImGuiMod_Ctrl, false) end)
step(nil, function() check(sel_str(sel_clip) == "5", "clipper ctrl+nav keeps selection: " .. sel_str(sel_clip)) end)
step(function() clip_scroll_request = true end); idle(2)
step(nil, function() check(rects.C40 ~= nil and rects.C5 == nil, "clipper scrolled (item 5 not visible)") end)
click("C40", false, true)
step(nil, function() check(sel_clip.Size == 36, "clipper shift+click range size " .. sel_clip.Size); check(sel_clip:Contains(5) and sel_clip:Contains(40) and not sel_clip:Contains(4) and not sel_clip:Contains(41), "clipper range bounds") end)

-- 10. External storage on bool array: click 1, Shift+click 3, Ctrl+click 2
click("E1"); click("E3", false, true)
step(nil, function() check(bools_str(ext_bools, 10) == "1,2,3", "external storage range: " .. bools_str(ext_bools, 10)) end)
click("E2", true)
step(nil, function() check(bools_str(ext_bools, 10) == "1,3", "external storage ctrl+click: " .. bools_str(ext_bools, 10)) end)

-- 11. Checkboxes (NoAutoSelect|NoAutoClear): click 1 toggles on, Shift+click 4 -> 1..4 on, click 2 toggles off
click("K1"); step(nil, function() check(bools_str(chk_bools, 8) == "1", "checkbox click: " .. bools_str(chk_bools, 8)) end)
click("K4", false, true); step(nil, function() check(bools_str(chk_bools, 8) == "1,2,3,4", "checkbox shift+click: " .. bools_str(chk_bools, 8)) end)
click("K2"); step(nil, function() check(bools_str(chk_bools, 8) == "1,3,4", "checkbox toggle off: " .. bools_str(chk_bools, 8)) end)

-- 12. Tree nodes: click 0, Ctrl+click 2, Shift+click 4 (range from 2)
click("T0"); click("T2", true)
step(nil, function() check(sel_str(sel_tree) == "0,2", "tree ctrl+click: " .. sel_str(sel_tree)) end)
click("T4", false, true)
step(nil, function() check(sel_str(sel_tree) == "2,3,4", "tree shift+click: " .. sel_str(sel_tree)) end)

-- 13. Metrics window renders the TypingSelect / MultiSelect debug nodes
local show_metrics = false
step(function() show_metrics = true end); idle(3)
step(nil, function() if #failed == 0 then print("MULTISELECT OK") end end)

local function list_window()
    ImGui.SetNextWindowPos(ImVec2(10, 10)); ImGui.SetNextWindowSize(ImVec2(200, 420))
    ImGui.Begin("L")
    local flags = bit32.bor(MSF.ClearOnEscape, MSF.BoxSelect1d)
    local ms_io = ImGui.BeginMultiSelect(flags, sel_list.Size, N)
    sel_list:ApplyRequests(ms_io)
    -- typing-select
    local focus_idx = -1
    if ImGui.IsWindowFocused() then
        local req = ImGui.GetTypingSelectRequest(G.ImGuiTypingSelectFlags.AllowSingleCharMode)
        local nav_idx = (type(ms_io.NavIdItem) == "number") and ms_io.NavIdItem or -1
        focus_idx = ImGui.TypingSelectFindMatch(req, N, function(_, idx) return NAMES[idx + 1] end, nil, nav_idx)
    end
    for n = 0, N - 1 do
        if n == focus_idx then ImGui.SetKeyboardFocusHere() end
        ImGui.SetNextItemSelectionUserData(n)
        ImGui.Selectable(NAMES[n + 1], sel_list:Contains(n))
        rects["L" .. n] = rect(); ids["L" .. n] = ImGui.GetItemID()
    end
    ms_io = ImGui.EndMultiSelect()
    sel_list:ApplyRequests(ms_io)
    ImGui.End()
end

local function clipper_window()
    ImGui.SetNextWindowPos(ImVec2(220, 10)); ImGui.SetNextWindowSize(ImVec2(200, 300))
    ImGui.Begin("C")
    if clip_scroll_request then ImGui.SetScrollY(ImGui.GetTextLineHeightWithSpacing() * 30); clip_scroll_request = false end
    local COUNT = 1000
    local ms_io = ImGui.BeginMultiSelect(MSF.ClearOnEscape, sel_clip.Size, COUNT)
    sel_clip:ApplyRequests(ms_io)
    local clipper = G.ImGuiListClipper()
    clipper:Begin(COUNT)
    if ms_io.RangeSrcItem ~= -1 then clipper:IncludeItemByIndex(ms_io.RangeSrcItem) end -- Ensure RangeSrc item is not clipped.
    for k in rects do if string.sub(k, 1, 1) == "C" then rects[k] = nil end end
    while clipper:Step() do
        for n = clipper.DisplayStart, clipper.DisplayEnd - 1 do
            ImGui.SetNextItemSelectionUserData(n)
            ImGui.Selectable(("Object %04d"):format(n), sel_clip:Contains(n))
            if ImGui.IsItemVisible() then rects["C" .. n] = rect() end
        end
    end
    ms_io = ImGui.EndMultiSelect()
    sel_clip:ApplyRequests(ms_io)
    ImGui.End()
end

local function external_window()
    ImGui.SetNextWindowPos(ImVec2(430, 10)); ImGui.SetNextWindowSize(ImVec2(180, 220))
    ImGui.Begin("E")
    local ms_io = ImGui.BeginMultiSelect(MSF.None, -1, 10)
    sel_ext:ApplyRequests(ms_io)
    for n = 0, 9 do
        ImGui.SetNextItemSelectionUserData(n)
        ImGui.Selectable("Ext " .. n, ext_bools[n + 1] == true)
        rects["E" .. n] = rect()
    end
    ms_io = ImGui.EndMultiSelect()
    sel_ext:ApplyRequests(ms_io)
    ImGui.End()
end

local function checkbox_window()
    ImGui.SetNextWindowPos(ImVec2(430, 240)); ImGui.SetNextWindowSize(ImVec2(180, 200))
    ImGui.Begin("K")
    local ms_io = ImGui.BeginMultiSelect(bit32.bor(MSF.NoAutoSelect, MSF.NoAutoClear, MSF.ClearOnEscape), -1, 8)
    sel_chk:ApplyRequests(ms_io)
    for n = 0, 7 do
        ImGui.SetNextItemSelectionUserData(n)
        local _, v = ImGui.Checkbox("Check " .. n, chk_bools[n + 1] == true)
        rects["K" .. n] = rect()
        local _ = v -- the selection is updated through requests (ApplyRequests), like upstream's demo
    end
    ms_io = ImGui.EndMultiSelect()
    sel_chk:ApplyRequests(ms_io)
    ImGui.End()
end

local function tree_window()
    ImGui.SetNextWindowPos(ImVec2(220, 320)); ImGui.SetNextWindowSize(ImVec2(200, 160))
    ImGui.Begin("T")
    local ms_io = ImGui.BeginMultiSelect(MSF.None, sel_tree.Size, 5)
    sel_tree:ApplyRequests(ms_io)
    for n = 0, 4 do
        local flags = bit32.bor(G.ImGuiTreeNodeFlags.Leaf, G.ImGuiTreeNodeFlags.NoTreePushOnOpen, G.ImGuiTreeNodeFlags.SpanAvailWidth)
        if sel_tree:Contains(n) then flags = bit32.bor(flags, G.ImGuiTreeNodeFlags.Selected) end
        ImGui.SetNextItemSelectionUserData(n)
        ImGui.TreeNodeEx("Node " .. n, flags)
        rects["T" .. n] = rect()
    end
    ms_io = ImGui.EndMultiSelect()
    sel_tree:ApplyRequests(ms_io)
    ImGui.End()
end

game:GetService("RunService").Stepped:Connect(function()
    f += 1
    G.ImGui_ImplRoblox.NewFrame()
    local s = steps[f]
    if s and s.input then s.input() end
    ImGui.NewFrame()
    list_window()
    clipper_window()
    external_window()
    checkbox_window()
    tree_window()
    if show_metrics then
        ImGui.SetNextWindowPos(ImVec2(620, 10)); ImGui.SetNextWindowSize(ImVec2(400, 600))
        ImGui.ShowMetricsWindow()
        local ctx = ImGui.GetCurrentContext()
        ImGui.Begin("DebugNodes")
        ImGui.DebugNodeTypingSelectState(ctx.TypingSelectState)
        for n = 0, ctx.MultiSelectStorage:GetMapSize() - 1 do
            local st = ctx.MultiSelectStorage:GetByIndex(n)
            if st then ImGui.SetNextItemOpen(true); ImGui.DebugNodeMultiSelectState(st) end
        end
        ImGui.End()
    end
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if s and s.check then s.check() end
end)
print(("t_multiselect: %d steps"):format(#steps))
