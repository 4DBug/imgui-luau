debug = setmetatable({ profilebegin = function() end, profileend = function() end }, { __index = debug })
-- Minimal Roblox mock for running the imgui Roblox backend + the real CanvasDraw module in the Luau CLI.
local realG = {} -- (no getfenv: it would mark the global env unsafe and deoptimize everything)
FAKE_TIME = 0
local SCREEN_W, SCREEN_H = 1920, 1080
local NFRAMES = tonumber(ARG_FRAMES) or 400
local FORCE = ARG_FORCE == true
local DUMP_FRAMES = { [60] = true, [200] = true, [NFRAMES] = true }

local function Signal()
    local s = { conns = {} }
    function s:Connect(fn)
        local c = { fn = fn, Connected = true }
        function c:Disconnect() c.Connected = false end
        table.insert(s.conns, c)
        return c
    end
    function s:Fire(...) for _, c in ipairs(s.conns) do if c.Connected then c.fn(...) end end end
    return s
end

local V2 = {}
V2.__index = V2
local function v2(x, y) return setmetatable({ X = x or 0, Y = y or 0 }, V2) end
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b) if type(b) == "number" then return v2(a.X * b, a.Y * b) end return v2(a.X * b.X, a.Y * b.Y) end
V2.__div = function(a, b) if type(b) == "number" then return v2(a.X / b, a.Y / b) end return v2(a.X / b.X, a.Y / b.Y) end
V2.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
local Vector2 = { new = v2, zero = v2(0, 0), one = v2(1, 1) }

-- Enums: KeyCode values as in Roblox; unknown KeyCode names error (catches typos in the backend)
local KEYCODES = {
    Unknown = 0, Backspace = 8, Tab = 9, Return = 13, Escape = 27, Space = 32, Quote = 39, Comma = 44, Minus = 45, Period = 46, Slash = 47,
    Semicolon = 59, Equals = 61, LeftBracket = 91, BackSlash = 92, RightBracket = 93, Backquote = 96, Delete = 127,
    KeypadPeriod = 266, KeypadDivide = 267, KeypadMultiply = 268, KeypadMinus = 269, KeypadPlus = 270, KeypadEnter = 271, KeypadEquals = 272,
    Up = 273, Down = 274, Right = 275, Left = 276, Insert = 277, Home = 278, End = 279, PageUp = 280, PageDown = 281,
    CapsLock = 301, RightShift = 303, LeftShift = 304, RightControl = 305, LeftControl = 306, RightAlt = 307, LeftAlt = 308,
    LeftSuper = 311, RightSuper = 312,
}
local digits = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
for i = 0, 9 do KEYCODES[digits[i + 1]] = 48 + i; KEYCODES["Keypad" .. digits[i + 1]] = 256 + i end
for i = 0, 25 do KEYCODES[string.char(65 + i)] = 97 + i end
for i = 1, 15 do KEYCODES["F" .. i] = 281 + i end

local Enum = setmetatable({}, { __index = function(t, enum_name)
    local e = setmetatable({}, { __index = function(e, item)
        local value = 0
        if enum_name == "KeyCode" then value = KEYCODES[item]; assert(value, "invalid KeyCode " .. item) end
        local it = { Name = item, Value = value, EnumType = enum_name }
        rawset(e, item, it)
        return it
    end })
    rawset(t, enum_name, e)
    return e
end })

-- Instances
local InstMethods = {}
local InstMT = {}
InstMT.__index = function(t, k)
    if k == "Parent" then return rawget(t, "_parent") end
    local m = InstMethods[k]; if m then return m end
    for _, c in ipairs(rawget(t, "_children")) do if c.Name == k then return c end end
    return nil
end
InstMT.__newindex = function(t, k, v)
    if k == "Parent" then
        local old = rawget(t, "_parent")
        if old then local ch = rawget(old, "_children"); for i, c in ipairs(ch) do if c == t then table.remove(ch, i) break end end end
        rawset(t, "_parent", v)
        if v then table.insert(rawget(v, "_children"), t) end
    else
        rawset(t, k, v)
    end
end
local function newInst(class, name, parent)
    local o = setmetatable({ ClassName = class, Name = name or class, _children = {} }, InstMT)
    if class == "ScreenGui" or class == "Frame" or class == "ImageLabel" then o.AbsoluteSize = v2(SCREEN_W, SCREEN_H) end
    o.Visible = true
    if class == "BindableEvent" then local sig = Signal(); rawset(o, "Event", sig); rawset(o, "Fire", function(_, ...) sig:Fire(...) end) end
    if parent then o.Parent = parent end
    return o
end
function InstMethods:FindFirstChild(name, recursive)
    for _, c in ipairs(rawget(self, "_children")) do if c.Name == name then return c end end
    if recursive then for _, c in ipairs(rawget(self, "_children")) do local r = c:FindFirstChild(name, true); if r then return r end end end
    return nil
end
function InstMethods:WaitForChild(name) return assert(self:FindFirstChild(name), "WaitForChild would hang: " .. name) end
function InstMethods:FindFirstChildOfClass(class) for _, c in ipairs(rawget(self, "_children")) do if c.ClassName == class then return c end end end
function InstMethods:GetChildren() return table.clone(rawget(self, "_children")) end
function InstMethods:IsA(class)
    if class == "GuiObject" then return self.ClassName == "Frame" or self.ClassName == "ImageLabel" end
    return self.ClassName == class
end
function InstMethods:Destroy() self.Parent = nil end

-- Services
local mouse = v2(0, 0)
local keys_down = {}
local UIS = {
    InputBegan = Signal(), InputEnded = Signal(), InputChanged = Signal(), WindowFocused = Signal(), WindowFocusReleased = Signal(),
}
function UIS:GetMouseLocation() return mouse end
function UIS:IsKeyDown(kc) return keys_down[kc] == true end

local RunService = { Heartbeat = Signal(), Stepped = Signal(), PreAnimation = Signal(), RenderStepped = Signal() }
local last_pixels -- last buffer written to an EditableImage
local AssetService = {}
function AssetService:CreateEditableImage(opts)
    local img = { Size = opts.Size, Pixels = buffer.create(opts.Size.X * opts.Size.Y * 4) }
    UPLOADS = 0
    function img:WritePixelsBuffer(origin, size, buf)
        assert(buffer.len(buf) == size.X * size.Y * 4, "WritePixelsBuffer: buffer size mismatch")
        assert(origin.X >= 0 and origin.Y >= 0 and origin.X + size.X <= opts.Size.X and origin.Y + size.Y <= opts.Size.Y, "WritePixelsBuffer: out of bounds")
        for y = 0, size.Y - 1 do buffer.copy(img.Pixels, ((origin.Y + y) * opts.Size.X + origin.X) * 4, buf, y * size.X * 4, size.X * 4) end
        _G_UPLOADS = (_G_UPLOADS or 0) + 1; _G_UPLOAD_PX = (_G_UPLOAD_PX or 0) + size.X * size.Y
    end
    function img:Destroy() end
    return img
end
local ReplicatedStorage = newInst("ReplicatedStorage")
local PlayerGui = newInst("PlayerGui")
local LocalPlayer = newInst("Player"); PlayerGui.Parent = LocalPlayer
local services = {
    UserInputService = UIS, RunService = RunService, AssetService = AssetService, ReplicatedStorage = ReplicatedStorage,
    Players = { LocalPlayer = LocalPlayer }, HttpService = {}, GuiService = { GetGuiInset = function() return v2(0, 0), v2(0, 0) end },
}
local game = {}
function game:GetService(name) services[name] = services[name] or {}; return services[name] end

local fakeG = {} -- Roblox's shared _G
local cache = {}
local ROBLOX
local function makeEnv(inst) return setmetatable({ script = inst }, { __index = ROBLOX }) end
local GLOBAL_NAMES = { "game", "workspace", "Instance", "Enum", "Vector2", "Vector3", "UDim2", "Color3", "Content", "warn", "require", "script", "os" }
-- Load like Roblox does but WITHOUT setfenv (which would disable Luau optimizations): Roblox globals become chunk locals.
local function loadAsScript(src_name, inst)
    local fn = SOURCE_FNS[src_name]
    local vals = {}
    for i, n in ipairs(GLOBAL_NAMES) do vals[i] = (n == "script") and inst or ROBLOX[n] end
    return function() return fn(table.unpack(vals, 1, #GLOBAL_NAMES)) end
end
local function rbxrequire(inst)
    assert(type(inst) == "table" and inst.ClassName == "ModuleScript", "require() expects a ModuleScript")
    if cache[inst] then return cache[inst].v end
    local r = table.pack(loadAsScript(rawget(inst, "_src"), inst)())
    assert(r.n == 1, "Module code did not return exactly one value")
    cache[inst] = { v = r[1] }
    return r[1]
end

ROBLOX = setmetatable({
    game = game, workspace = { CurrentCamera = { ViewportSize = v2(SCREEN_W, SCREEN_H) } }, require = rbxrequire, _G = fakeG,
    Instance = { new = function(class) return newInst(class) end },
    Enum = Enum, Vector2 = Vector2,
    Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end },
    UDim2 = { new = function(...) return { ... } end, fromScale = function(...) return { ... } end, fromOffset = function(x, y) return { X = x, Y = y } end },
    Color3 = { new = function(r, g, b) return { R = r or 0, G = g or 0, B = b or 0 } end },
    Content = { fromObject = function(o) return { Object = o } end },
    warn = function(...) print("WARN", ...) end,
    os = { clock = function() return FAKE_TIME end, time = os.time, realclock = os.clock },
}, { __index = realG })

local mod = newInst("ModuleScript", "ImGui", ReplicatedStorage); rawset(mod, "_src", "ImGui.luau")
-- Run main.lua as a LocalScript
local main = loadAsScript("main.client.luau", newInst("LocalScript", "main"))
main()
local G = cache[mod].v
local render_time = 0
local realDemo = G.ImGui.ShowDemoWindow
local realCH = G.ImGui.CollapsingHeader
G.ImGui.CollapsingHeader = function(...)
    if ARG_OPEN == true or (type(ARG_OPEN) == "table" and ARG_OPEN[(...)]) then G.ImGui.SetNextItemOpen(true, G.ImGuiCond.Always) end
    return realCH(...)
end
local realTN = G.ImGui.TreeNode
G.ImGui.TreeNode = function(...)
    if ARG_OPEN == true or (type(ARG_OPEN) == "table" and ARG_OPEN[(...)]) then G.ImGui.SetNextItemOpen(true, G.ImGuiCond.Always) end
    return realTN(...)
end
if realDemo then G.ImGui.ShowDemoWindow = function(...)
    if ARG_BIG then G.ImGui.SetNextWindowSize(G.ImVec2(900, 1000), G.ImGuiCond.Always) end
    return realDemo(...)
end end
local realRender = G.ImGui_ImplRoblox.RenderDrawData
G.ImGui_ImplRoblox.RenderDrawData = function(dd)
    if FORCE then G.ImGui.GetIO().BackendPlatformUserData.ForceRedraw = true end
    local t0 = os.clock(); realRender(dd); render_time = render_time + os.clock() - t0
end

-- Drive frames with scripted (deterministic) input
local seed = 12345
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n end
local function input(t, kc, pos) return { UserInputType = Enum.UserInputType[t], KeyCode = Enum.KeyCode[kc or "Unknown"], Position = pos or { X = 0, Y = 0, Z = 0 } } end
local held = false
local typing = { "H", "E", "L", "L", "O", "Space", "One", "Two", "Minus", "Backspace", "Left", "Return" }
local hex = {}
for i = 0, 255 do hex[i] = string.format("%02x", i) end

local total = 0
for frame = 1, NFRAMES do
    local r = ARG_QUIET and 100 or rnd(100)
    if r < 40 then
        mouse = v2(math.clamp(mouse.X + rnd(81) - 40, 0, SCREEN_W - 1), math.clamp(mouse.Y + rnd(81) - 40, 0, SCREEN_H - 1))
    elseif r < 55 then
        held = not held
        if held then UIS.InputBegan:Fire(input("MouseButton1"), false) else UIS.InputEnded:Fire(input("MouseButton1"), false) end
    elseif r < 60 then
        UIS.InputChanged:Fire(input("MouseWheel", nil, { X = 0, Y = 0, Z = rnd(3) - 1 }), false)
    elseif r < 75 then
        local k = typing[rnd(#typing) + 1]
        local shift = rnd(4) == 0
        if shift then keys_down[Enum.KeyCode.LeftShift] = true; UIS.InputBegan:Fire(input("Keyboard", "LeftShift"), false) end
        UIS.InputBegan:Fire(input("Keyboard", k), false)
        UIS.InputEnded:Fire(input("Keyboard", k), false)
        if shift then keys_down[Enum.KeyCode.LeftShift] = nil; UIS.InputEnded:Fire(input("Keyboard", "LeftShift"), false) end
    elseif r < 90 then
        mouse = v2(rnd(700), rnd(500))
    end

    FAKE_TIME = frame / 60
    local t0 = os.clock()
    RunService.Stepped:Fire(frame / 60, 1 / 60)
    local dt = os.clock() - t0
    if frame > 10 then total = total + dt end

    if frame == 10 then render_time = 0; _G_UPLOADS = 0 end
end
print(string.format("avg frame total %.2f ms, of which render %.2f ms, uploads/frame %.2f, upload KB/frame %.0f", total / (NFRAMES - 10) * 1000, render_time / (NFRAMES - 10) * 1000, _G_UPLOADS / (NFRAMES - 10), (_G_UPLOAD_PX or 0) * 4 / 1024 / (NFRAMES - 10)))
