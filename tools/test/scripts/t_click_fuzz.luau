-- Click fuzzer for the demo: records every visible item rect (by wrapping ImGui.ItemAdd) and clicks/drags/scrolls/types on random ones.
-- Usage: python3 tools/test/run.py --main tools/test/scripts/t_click_fuzz.luau --frames 3000 --quiet
-- Change SEED to explore other paths.
local SEED = tonumber(_G.FUZZ_SEED) or 1
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.NavEnableKeyboard, G.ImGuiConfigFlags.DockingEnable)
G.ImGui_ImplRoblox.Init()
math.randomseed(SEED)

local items, prev_items = {}, {}
local orig_ItemAdd = ImGui.ItemAdd
ImGui.ItemAdd = function(bb, id, nav_bb, extra)
    local r = orig_ItemAdd(bb, id, nav_bb, extra)
    if r and id ~= 0 then
        local g = ImGui.GetCurrentContext()
        local w = g.CurrentWindow
        local c = w.ClipRect
        local x1, y1 = math.max(bb.Min.x, c.Min.x), math.max(bb.Min.y, c.Min.y)
        local x2, y2 = math.min(bb.Max.x, c.Max.x), math.min(bb.Max.y, c.Max.y)
        if x2 - x1 >= 2 and y2 - y1 >= 2 then
            items[#items + 1] = { x1, y1, x2, y2, w.Name }
        end
    end
    return r
end

local log = {}
local function note(s) log[#log + 1] = s; if #log > 12 then table.remove(log, 1) end end

-- action queue: list of {x, y, down, key, char, wheel}
local queue = {}
local mx, my, down = 500, 500, false
local function plan()
    local list = prev_items
    if #list == 0 then queue = { { 500, 500, false } }; return end
    local it = list[math.random(#list)]
    local x = it[1] + math.random() * (it[3] - it[1])
    local y = it[2] + math.random() * (it[4] - it[2])
    local r = math.random()
    if r < 0.65 then
        note(string.format("click %.0f,%.0f in %s", x, y, it[5]))
        queue = { { x, y, false }, { x, y, true }, { x, y, false }, { x, y, false } }
    elseif r < 0.8 then
        local dx, dy = math.random(-150, 150), math.random(-80, 80)
        note(string.format("drag %.0f,%.0f by %d,%d in %s", x, y, dx, dy, it[5]))
        queue = { { x, y, false }, { x, y, true } }
        for i = 1, 6 do queue[#queue + 1] = { x + dx * i / 6, y + dy * i / 6, true } end
        queue[#queue + 1] = { x + dx, y + dy, false }
    elseif r < 0.9 then
        note(string.format("wheel %.0f,%.0f in %s", x, y, it[5]))
        queue = { { x, y, false, wheel = (math.random() < 0.5) and -3 or 3 } }
    elseif r < 0.95 then
        note(string.format("dblclick %.0f,%.0f in %s", x, y, it[5]))
        queue = { { x, y, false }, { x, y, true }, { x, y, false }, { x, y, true }, { x, y, false }, { x, y, false } }
    else
        local keys = { G.ImGuiKey.Enter, G.ImGuiKey.Escape, G.ImGuiKey.Tab, G.ImGuiKey.UpArrow, G.ImGuiKey.DownArrow, G.ImGuiKey.Backspace }
        local k = keys[math.random(#keys)]
        note("key " .. tostring(k) .. " + text")
        queue = { { mx, my, down, key = k }, { mx, my, down, char = "a1" } }
    end
end

local frame = 0
RunService.Stepped:Connect(function()
    frame += 1
    local ok, err = xpcall(function()
        G.ImGui_ImplRoblox.NewFrame()
        if #queue == 0 then plan() end
        local a = table.remove(queue, 1)
        mx, my = a[1], a[2]
        io:AddMousePosEvent(mx, my)
        if a[3] ~= down then down = a[3]; io:AddMouseButtonEvent(0, down) end
        if a.wheel then io:AddMouseWheelEvent(0, a.wheel) end
        if a.key then io:AddKeyEvent(a.key, true); io:AddKeyEvent(a.key, false) end
        if a.char then for i = 1, #a.char do io:AddInputCharacter(string.byte(a.char, i)) end end

        prev_items = items
        items = {}
        ImGui.NewFrame()
        ImGui.DockSpaceOverViewport(0, nil, G.ImGuiDockNodeFlags.PassthruCentralNode)
        if frame % 400 == 1 then
            ImGui.SetNextWindowCollapsed(false)
            ImGui.SetNextWindowPos(ImVec2(650, 20))
            ImGui.SetNextWindowSize(ImVec2(700, 1000))
        end
        ImGui.ShowDemoWindow()
        ImGui.Render()
        G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    end, debug.traceback)
    if not ok then
        print("FUZZ FAIL at frame " .. frame .. " seed " .. SEED)
        for _, l in ipairs(log) do print("  " .. l) end
        error(err, 0)
    end
    if frame % 500 == 0 then print("frame", frame, "items", #prev_items) end
end)
