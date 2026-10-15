-- Regressions vs upstream: clipboard paste filter (InputTextEx), ImParseFormatTrimDecorations (Ctrl+click temp input), ShrinkWidths tie order,
-- CalcItemSize by value, PushClipRectFullScreen (drop target outside clip rect)
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
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10)); ImGui.SetNextWindowSize(ImVec2(300, 200))
    ImGui.Begin("T")
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
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if f == 8 then check(edit_text() == "abc\u{e9}", "paste: '" .. edit_text() .. "'") end
    if f == 13 then check(edit_text() == "45", "SliderFloat temp input: '" .. edit_text() .. "'") end
    if f == 18 then check(edit_text() == "50", "DragInt temp input: '" .. edit_text() .. "'") end
    if f == 20 and #failed == 0 then print("FIXES OK") end
end)
