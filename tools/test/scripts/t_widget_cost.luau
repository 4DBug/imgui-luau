-- Per-widget cost: wraps every ImGui.* function with self-time timing, shows the Style Editor on its Colors tab
-- (or the demo with --open-only ...), prints a table sorted by total self time and by cost per call.
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
local io = ImGui.GetIO()
local STYLE = type(ARG_OPEN) ~= "table"

local realBTI = ImGui.BeginTabItem
ImGui.BeginTabItem = function(label, p_open, flags)
    if label == "Colors" and STYLE then flags = bit32.bor(flags or 0, G.ImGuiTabItemFlags.SetSelected) end
    return realBTI(label, p_open, flags)
end

local self_t, calls = {}, {}
local stack_child = {} -- time spent in nested wrapped calls, per depth
local depth, enabled = 0, false
local clock = os.realclock or os.clock -- harness fakes os.clock; realclock is the real one
for name, fn in pairs(ImGui) do
    if type(fn) == "function" and name ~= "NewFrame" and name ~= "Render" and name ~= "EndFrame" then
        ImGui[name] = function(...)
            if not enabled then return fn(...) end
            depth += 1; stack_child[depth] = 0
            local t0 = clock()
            local r = table.pack(fn(...))
            local dt = clock() - t0
            local own = dt - stack_child[depth]
            depth -= 1
            if depth > 0 then stack_child[depth] += dt end
            self_t[name] = (self_t[name] or 0) + own; calls[name] = (calls[name] or 0) + 1
            return table.unpack(r, 1, r.n)
        end
    end
end

local frame = 0
game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io:AddMousePosEvent(5, 5)
    ImGui.NewFrame()
    enabled = frame > 10
    if STYLE then
        ImGui.SetNextWindowPos(ImVec2(20, 20)); ImGui.SetNextWindowSize(ImVec2(550, 900))
        ImGui.Begin("Style Editor"); ImGui.ShowStyleEditor(); ImGui.End()
    else
        ImGui.ShowDemoWindow(true)
    end
    enabled = false
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == ARG_FRAMES - 1 then
        local nf = frame - 10
        local names = {}
        local total = 0
        for k, v in pairs(self_t) do table.insert(names, k); total += v end
        table.sort(names, function(a, b) return self_t[a] > self_t[b] end)
        print(string.format("TOTAL %.3f ms/frame (wrapped calls, incl. wrapper overhead)", total / nf * 1000))
        print("== by self time per frame")
        for i = 1, math.min(20, #names) do local k = names[i]
            print(string.format("%7.3f ms %6.1f%%  %5d calls  %6.1f us/call  %s", self_t[k] / nf * 1000, 100 * self_t[k] / total, calls[k] / nf, self_t[k] / calls[k] * 1e6, k)) end
        table.sort(names, function(a, b) return self_t[a] / calls[a] > self_t[b] / calls[b] end)
        print("== by cost per call (>= 1 call/frame)")
        local shown = 0
        for _, k in ipairs(names) do
            if calls[k] >= nf and shown < 15 then shown += 1
                print(string.format("%6.1f us/call  %5d calls  %s", self_t[k] / calls[k] * 1e6, calls[k] / nf, k)) end
        end
    end
end)
