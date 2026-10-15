-- Debug tools + misc imgui.cpp ports: item picker, DebugFlashStyleColor, DebugLocateItem, context hooks, AddInputCharactersUTF8, ImBezierCubicClosestPoint
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local ctx = ImGui.CreateContext(); G.ImGui_ImplRoblox.Init()
local io = ImGui.GetIO()
local failed = {}
local function check(ok, msg) if not ok then table.insert(failed, msg); print("FAIL " .. msg) end end

-- ImBezierCubicClosestPoint: straight-line cubic (0,0)-(30,0)-(60,0)-(90,0): closest point to (45,10) is (45,0)
local p1, p2, p3, p4 = ImVec2(0, 0), ImVec2(30, 0), ImVec2(60, 0), ImVec2(90, 0)
local cp = G.ImBezierCubicClosestPoint(p1, p2, p3, p4, ImVec2(45, 10), 20)
check(math.abs(cp.x - 45) < 1e-3 and math.abs(cp.y) < 1e-6, ("ImBezierCubicClosestPoint %g,%g"):format(cp.x, cp.y))
-- Curved: result must lie on the curve (distance to a dense sampling of the curve ~0) and beat the endpoints
local q1, q2, q3, q4 = ImVec2(0, 0), ImVec2(0, 100), ImVec2(100, 100), ImVec2(100, 0)
local target = ImVec2(50, 120)
for _, r in { G.ImBezierCubicClosestPoint(q1, q2, q3, q4, target, 64), G.ImBezierCubicClosestPointCasteljau(q1, q2, q3, q4, target, 0.25) } do
    check(math.abs(r.x - 50) < 0.5 and math.abs(r.y - 75) < 0.5, ("closest point on curve %g,%g (expected ~50,75)"):format(r.x, r.y))
end

-- AddInputCharactersUTF8 queues one Text event per codepoint
io:AddInputCharactersUTF8("a\u{e9}\u{20ac}\u{1F600}")
local chars = {}
for _, e in ctx.InputEventsQueue.Data do if e.Type == G.ImGuiInputEventType.Text then table.insert(chars, e.Text.Char) end end
-- (this build has IM_UNICODE_CODEPOINT_MAX = 0xFFFF like upstream's default ImWchar16: U+1F600 becomes IM_UNICODE_CODEPOINT_INVALID)
check(#chars == 4 and chars[1] == 0x61 and chars[2] == 0xE9 and chars[3] == 0x20AC and chars[4] == ((G.IM_UNICODE_CODEPOINT_MAX >= 0x1F600) and 0x1F600 or 0xFFFD), "AddInputCharactersUTF8 " .. table.concat(chars, ","))

-- Context hooks
local log = {}
local function hook(t, name)
    local h = G.ImGuiContextHook(); h.Type = t; h.Callback = function(c, hk) table.insert(log, name) end
    return ImGui.AddContextHook(ctx, h)
end
local T = G.ImGuiContextHookType
hook(T.NewFramePre, "nfpre"); hook(T.NewFramePost, "nfpost"); hook(T.RenderPre, "rpre"); local rpost = hook(T.RenderPost, "rpost")

-- Style color flash
local col = ImGui.GetStyle().Colors[G.ImGuiCol.Button]
local orig = { col.x, col.y, col.z, col.w }

local f, rect, picked, broke, button_id = 0, nil, nil, 0, 0
ctx.DebugBreakCallback = function() broke += 1 end
game:GetService("RunService").Stepped:Connect(function()
    f += 1
    G.ImGui_ImplRoblox.NewFrame()
    if rect and f == 5 then io:AddMousePosEvent((rect[1].x + rect[2].x) / 2, (rect[1].y + rect[2].y) / 2) end
    if f == 6 then ImGui.DebugStartItemPicker() end
    if f == 8 then io:AddMouseButtonEvent(0, true) elseif f == 9 then io:AddMouseButtonEvent(0, false) end
    ImGui.NewFrame()
    if f == 1 then check(table.concat(log, " ") == "nfpre nfpost", "hooks after NewFrame: " .. table.concat(log, " ")) end
    if f == 8 then picked = ctx.DebugItemPickerBreakId end
    if f == 3 then ImGui.DebugFlashStyleColor(G.ImGuiCol.Button) end
    ImGui.SetNextWindowPos(ImVec2(10, 10), G.ImGuiCond.Always)
    ImGui.Begin("DebugTools")
    ImGui.Button("Target")
    if f == 2 then local a, b = ImGui.GetItemRectMin(), ImGui.GetItemRectMax(); rect = { ImVec2(a.x, a.y), ImVec2(b.x, b.y) } end
    local target_id = ctx.LastItemData.ID
    button_id = target_id
    if f == 12 then ImGui.DebugLocateItem(target_id) end
    if f == 13 then check(ctx.DebugLocateId == 0, "DebugLocateItem resolved by ItemAdd()") end
    ImGui.DebugDrawItemRect(); ImGui.DebugDrawCursorPos(); ImGui.DebugDrawLineExtents()
    ImGui.DebugTextUnformattedWithLocateItem(("id 0x%08X here"):format(target_id))
    ImGui.End()
    ImGui.SetNextWindowPos(ImVec2(400, 10), G.ImGuiCond.Always); ImGui.ShowMetricsWindow()
    ImGui.SetNextWindowPos(ImVec2(400, 300), G.ImGuiCond.Always); ImGui.ShowDebugLogWindow()
    if f == 4 then
        local c = ImGui.GetStyle().Colors[G.ImGuiCol.Button]
        check(c.w == 1.0 and ctx.DebugFlashStyleColorIdx == G.ImGuiCol.Button, "flash active")
    end
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if f == 1 then check(table.concat(log, " ") == "nfpre nfpost rpre rpost", "hooks after Render: " .. table.concat(log, " ")); ImGui.RemoveContextHook(ctx, rpost) end
    if f == 2 then check(table.concat(log, " ") == "nfpre nfpost rpre rpost nfpre nfpost rpre", "RemoveContextHook: " .. table.concat(log, " ")) end
    if f == 60 then
        local c = ImGui.GetStyle().Colors[G.ImGuiCol.Button]
        check(c.x == orig[1] and c.y == orig[2] and c.z == orig[3] and c.w == orig[4] and ctx.DebugFlashStyleColorIdx == nil, "flash restored color exactly")
        check(picked ~= nil and picked ~= 0 and picked == button_id, ("item picker set DebugItemPickerBreakId (%s vs %s)"):format(tostring(picked), tostring(button_id)))
        check(not ctx.DebugItemPickerActive and broke >= 1, ("item picker break hook called (%d)"):format(broke))
        if #failed == 0 then print("DEBUGTOOLS OK") end
    end
end)
