-- Regressions vs upstream: clipboard paste filter (InputTextEx), ImParseFormatTrimDecorations (Ctrl+click temp input), ShrinkWidths tie order,
-- CalcItemSize by value, PushClipRectFullScreen (drop target outside clip rect), InputTextMultiline line index (render/scroll/edit), Shortcut() default
-- args, IsWindowAppearing() on frame 1 (FrameCount starts at 0), ColorButton -> ColorEdit4 drag and drop
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext(); G.ImGui_ImplRoblox.Init()
local io = ImGui.GetIO()
local failed = {}
local function check(ok, msg) if not ok then table.insert(failed, msg); print("FAIL " .. msg) end end

-- ShrinkWidths: equal widths sort by Index descending (upstream ShrinkWidthItemComparer), so the rounding remainder goes to the highest Index first
local items = {}
for i = 1, 4 do local it = G.ImGuiShrinkWidthItem(); it.Index = i - 1; it.Width = 100; it.InitialWidth = 100; items[i] = it end
ImGui.ShrinkWidths(items, 1, 4, 2.0, 10.0)
local w = {}
for _, it in items do w[it.Index] = it.Width end
check(w[3] == 100 and w[2] == 100 and w[1] == 99 and w[0] == 99, ("ShrinkWidths widths %s %s %s %s"):format(w[0], w[1], w[2], w[3]))

check(G.ImFloor(-1.5) == -2 and G.ImFloor(-0.2) == -1 and G.ImFloor(2.7) == 2, "ImFloor negative")

local function edit_text()
    local st = ImGui.GetCurrentContext().InputTextState
    return G.ImGui._ByteArrayToString(st.TextA.Data, 1, st.TextLen + 1)
end
local buf = ImGui.NewTextBuffer("", 64)
local f, sf, di = 0, 45.0, 50
local rects = {}
local function rect() local a, b = ImGui.GetItemRectMin(), ImGui.GetItemRectMax(); return { ImVec2(a.x, a.y), ImVec2(b.x, b.y) } end -- copies: GetItemRectMin() returns the live LastItemData.Rect.Min
local function click(name, ctrl)
    local r = rects[name]
    io:AddMousePosEvent((r[1].x + r[2].x) / 2, (r[1].y + r[2].y) / 2)
    if ctrl then io:AddKeyEvent(G.ImGuiMod_Ctrl, true) end
    io:AddMouseButtonEvent(0, true)
end
local function release() io:AddMouseButtonEvent(0, false); io:AddKeyEvent(G.ImGuiMod_Ctrl, false) end
local function key(k) io:AddKeyEvent(k, true); io:AddKeyEvent(k, false) end
local function center(name) local r = rects[name]; return (r[1].x + r[2].x) / 2, (r[1].y + r[2].y) / 2 end
local ml_text = "line1\nline2\nline3\nline4\nline5\nline6"
local mbuf = ImGui.NewTextBuffer(ml_text, 256)
local wbuf = ImGui.NewTextBuffer("a long line that has to be word wrapped several times inside the narrow box\nsecond", 256)
local shortcut_frames = {}
local cb_col, ce_col = G.ImVec4(1, 0, 0, 1), { 0, 0, 0, 1 }

game:GetService("RunService").Stepped:Connect(function()
    f += 1
    G.ImGui_ImplRoblox.NewFrame()
    if f == 3 then click("t") elseif f == 4 then release() end
    -- clipboard: tab is filtered out (single line, no AllowTabInput), é is 2 bytes
    if f == 6 then ImGui.SetClipboardText("ab\tc\u{e9}"); io:AddKeyEvent(G.ImGuiMod_Ctrl, true); io:AddKeyEvent(G.ImGuiKey.V, true) end
    if f == 7 then io:AddKeyEvent(G.ImGuiKey.V, false); io:AddKeyEvent(G.ImGuiMod_Ctrl, false) end
    if f == 9 then key(G.ImGuiKey.Escape) end
    if f == 11 then click("s", true) elseif f == 12 then release() end
    if f == 14 then key(G.ImGuiKey.Escape) end
    if f == 16 then click("d", true) elseif f == 17 then release() end
    -- multi-line: click, Ctrl+End, type "x", Enter, "y"
    if f == 21 then click("m") elseif f == 22 then release() end
    if f == 23 then io:AddKeyEvent(G.ImGuiMod_Ctrl, true); io:AddKeyEvent(G.ImGuiKey.End, true) end
    if f == 24 then io:AddKeyEvent(G.ImGuiKey.End, false); io:AddKeyEvent(G.ImGuiMod_Ctrl, false) end
    if f == 25 then io:AddInputCharacter(string.byte("x")) end
    if f == 26 then key(G.ImGuiKey.Enter) end
    if f == 28 then io:AddInputCharacter(string.byte("y")) end
    if f == 29 then io:AddKeyEvent(G.ImGuiMod_Ctrl, true); io:AddKeyEvent(G.ImGuiKey.A, true) end -- select all: renders the multi-line selection
    if f == 30 then io:AddKeyEvent(G.ImGuiKey.A, false); io:AddKeyEvent(G.ImGuiMod_Ctrl, false) end
    if f == 31 then key(G.ImGuiKey.Escape) end
    -- Shortcut(chord) with default flags/owner
    if f == 33 then io:AddKeyEvent(G.ImGuiMod_Ctrl, true); io:AddKeyEvent(G.ImGuiKey.S, true) end
    if f == 34 then io:AddKeyEvent(G.ImGuiKey.S, false); io:AddKeyEvent(G.ImGuiMod_Ctrl, false) end
    -- drag the ColorButton onto the ColorEdit4
    if f == 36 then io:AddMousePosEvent(center("cb")) end
    if f == 37 then io:AddMouseButtonEvent(0, true) end
    if f == 38 then local x, y = center("cb"); io:AddMousePosEvent(x + 10, y + 5) end
    if f == 39 then io:AddMousePosEvent(center("ce")) end
    if f == 42 then io:AddMouseButtonEvent(0, false) end
    -- word-wrapped multi-line: click, Ctrl+End, type "z"
    if f == 45 then click("w") elseif f == 46 then release() end
    if f == 47 then io:AddKeyEvent(G.ImGuiMod_Ctrl, true); io:AddKeyEvent(G.ImGuiKey.End, true) end
    if f == 48 then io:AddKeyEvent(G.ImGuiKey.End, false); io:AddKeyEvent(G.ImGuiMod_Ctrl, false) end
    if f == 49 then io:AddInputCharacter(string.byte("z")) end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10)); ImGui.SetNextWindowSize(ImVec2(300, 200))
    ImGui.Begin("T")
    if f == 1 then check(ImGui.GetFrameCount() == 1 and ImGui.IsWindowAppearing(), "IsWindowAppearing() on frame 1") end
    if f == 2 then check(not ImGui.IsWindowAppearing(), "IsWindowAppearing() on frame 2") end
    ImGui.InputText("##t", buf, 64); rects.t = rect()
    sf = ImGui.SliderFloat("##s", sf, 0.0, 100.0, "%.0f deg"); rects.s = rect()
    di = ImGui.DragInt("##d", di, 1, 0, 100, "%d%%"); rects.d = rect()
    -- CalcItemSize takes 'size' by value: the caller's ImVec2 must not be written to
    local bsz, csz = ImVec2(0, 0), ImVec2(-1, 40)
    ImGui.Button("sz", bsz); check(bsz.x == 0 and bsz.y == 0, "Button wrote size_arg")
    ImGui.BeginChild("c", csz); ImGui.EndChild(); check(csz.x == -1 and csz.y == 40, "BeginChild wrote size_arg")
    -- drop target rect sticking out of the window clip rect pushes a full-screen clip rect
    ImGui.RenderDragDropTargetRectForItem(G.ImRect(-50, -50, 900, 900))
    ImGui.End()
    ImGui.SetNextWindowPos(ImVec2(320, 10)); ImGui.SetNextWindowSize(ImVec2(300, 200))
    ImGui.Begin("M")
    ImGui.InputTextMultiline("##m", mbuf, 256, ImVec2(200, ImGui.GetTextLineHeight() * 3)); rects.m = rect()
    if f == 30 then
        local st = ImGui.GetCurrentContext().InputTextState
        check(st.LineCount == 7, "multiline LineCount " .. tostring(st.LineCount))
        local cw -- the multi-line child window: cursor on the last line scrolled it
        for _, w in ImGui.GetCurrentContext().Windows.Data do if w.Name:find("^M/##m_") then cw = w end end
        check(cw ~= nil and cw.Scroll.y > 0, "multiline scroll " .. tostring(cw and cw.Scroll.y))
    end
    ImGui.InputTextMultiline("##w", wbuf, 256, ImVec2(120, 80), G.ImGuiInputTextFlags.WordWrap); rects.w = rect()
    if f == 30 then check(ImGui.GetCurrentContext().InputTextState:HasSelection(), "multiline select all") end
    if ImGui.Shortcut(bit32.bor(G.ImGuiMod_Ctrl, G.ImGuiKey.S)) then shortcut_frames[f] = true end
    ImGui.End()
    ImGui.SetNextWindowPos(ImVec2(10, 220)); ImGui.SetNextWindowSize(ImVec2(300, 150))
    ImGui.Begin("D")
    ImGui.ColorButton("cb", cb_col); rects.cb = rect()
    ImGui.ColorEdit4("##ce", ce_col); rects.ce = rect()
    ImGui.End()
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if f == 8 then check(edit_text() == "abc\u{e9}", "paste: '" .. edit_text() .. "'") end
    if f == 13 then check(edit_text() == "45", "SliderFloat temp input: '" .. edit_text() .. "'") end
    if f == 18 then check(edit_text() == "50", "DragInt temp input: '" .. edit_text() .. "'") end
    if f == 30 then check(ImGui.TextBufferToString(mbuf) == ml_text .. "x\ny", "multiline buffer: '" .. ImGui.TextBufferToString(mbuf) .. "'") end
    if f == 35 then check(shortcut_frames[33] and not shortcut_frames[32] and not shortcut_frames[34], "Shortcut(Ctrl+S) default args") end
    if f == 44 then check(ce_col[1] == 1 and ce_col[2] == 0 and ce_col[3] == 0 and ce_col[4] == 1, ("color drop: %s %s %s %s"):format(ce_col[1], ce_col[2], ce_col[3], ce_col[4])) end
    if f == 51 then check(ImGui.TextBufferToString(wbuf):sub(-7) == "secondz", "word-wrap buffer: '" .. ImGui.TextBufferToString(wbuf) .. "'") end
    if f == 52 and #failed == 0 then print("FIXES OK") end
end)
