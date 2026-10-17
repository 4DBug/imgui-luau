-- ImGui backend for Roblox: platform, input, files, Init/Shutdown and the public API; rendering in render.lua.
-- Requires "Allow Mesh / Image APIs" (EditableImage) in game settings.
local Textures = IM_INCLUDE("roblox/textures.lua")
local Layers = IM_INCLUDE("roblox/layers.lua")
local Render = IM_INCLUDE("roblox/render.lua")
local Parallel = IM_INCLUDE("roblox/parallel.lua")

local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")

local floor, min = math.floor, math.min
local EditableImages, PB, PE = Textures.EditableImages, Textures.PB, Textures.PE
local ImGui_ImplRoblox_GetBackendData = Textures.GetBackendData
local ImGui_ImplRoblox_RenderDrawData = Render.RenderDrawData
local DestroyTiles = Layers.DestroyTiles

local KEY_MAP = {}
do
    local names = {
        Return = "Enter", Escape = "Escape", Backspace = "Backspace", Tab = "Tab", Space = "Space",
            KeypadEnter = "KeypadEnter",
        Up = "UpArrow", Down = "DownArrow", Left = "LeftArrow", Right = "RightArrow",
        Home = "Home", End = "End", PageUp = "PageUp", PageDown = "PageDown", Insert = "Insert", Delete = "Delete",
        LeftControl = "LeftCtrl", RightControl = "RightCtrl", LeftShift = "LeftShift", RightShift = "RightShift",
        LeftAlt = "LeftAlt", RightAlt = "RightAlt", LeftSuper = "LeftSuper", RightSuper = "RightSuper",
        Quote = "Apostrophe", Comma = "Comma", Minus = "Minus", Period = "Period", Slash = "Slash",
            Semicolon = "Semicolon",
        Equals = "Equal", LeftBracket = "LeftBracket", BackSlash = "Backslash", RightBracket = "RightBracket",
            Backquote = "GraveAccent",
        CapsLock = "CapsLock",
        KeypadPeriod = "KeypadDecimal", KeypadDivide = "KeypadDivide", KeypadMultiply = "KeypadMultiply",
        KeypadMinus = "KeypadSubtract", KeypadPlus = "KeypadAdd", KeypadEquals = "KeypadEqual",
    }
    local digits = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
    for i = 0, 9 do
        names[digits[i + 1]] = "K" .. i
        names["Keypad" .. digits[i + 1]] = "Keypad" .. i
    end
    for i = 1, 12 do names["F" .. i] = "F" .. i end
    for c in ("ABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do names[c] = c end

    for rbx_name, imgui_name in pairs(names) do
        KEY_MAP[Enum.KeyCode[rbx_name]] = ImGuiKey[imgui_name]
    end
end

-- No text input event: characters come from KeyCode.Value (printable ASCII) + a US layout shift table
local SHIFTED = {
    ["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%", ["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(",
        ["0"] = ")",
    ["-"] = "_", ["="] = "+", ["["] = "{", ["]"] = "}", ["\\"] = "|", [";"] = ":", ["'"] = "\"", [","] = "<",
        ["."] = ">", ["/"] = "?", ["`"] = "~",
}

local MOUSE_BUTTONS = {
    [Enum.UserInputType.MouseButton1] = 0,
    [Enum.UserInputType.MouseButton2] = 1,
    [Enum.UserInputType.MouseButton3] = 2,
}

local function ImGui_ImplRoblox_UpdateKeyModifiers()
    local io = ImGui.GetIO()
    local K = Enum.KeyCode
    local ctrl  = UserInputService:IsKeyDown(K.LeftControl) or UserInputService:IsKeyDown(K.RightControl)
    local shift = UserInputService:IsKeyDown(K.LeftShift) or UserInputService:IsKeyDown(K.RightShift)
    local alt   = UserInputService:IsKeyDown(K.LeftAlt) or UserInputService:IsKeyDown(K.RightAlt)
    io:AddKeyEvent(ImGuiMod_Ctrl, ctrl)
    io:AddKeyEvent(ImGuiMod_Shift, shift)
    io:AddKeyEvent(ImGuiMod_Alt, alt)
    io:AddKeyEvent(ImGuiMod_Super, UserInputService:IsKeyDown(K.LeftSuper) or UserInputService:IsKeyDown(K.RightSuper))
    return ctrl, shift, alt
end

local function ImGui_ImplRoblox_UpdateMonitors(w, h)
    local platform_io = ImGui.GetPlatformIO()
    platform_io.Monitors:resize(0)

    local imgui_monitor = ImGuiPlatformMonitor()
    ImVec2_Copy(imgui_monitor.MainSize, ImVec2(w, h))
    ImVec2_Copy(imgui_monitor.WorkSize, ImVec2(w, h))

    platform_io.Monitors:push_back(imgui_monitor)
end

-- Games can't touch the OS clipboard, so copy/paste only works inside ImGui
local Clipboard = ""
local function ImGui_ImplRoblox_PlatformSetClipboardText(ctx, text) Clipboard = text end
local ProxyFocused = false
local function ImGui_ImplRoblox_PlatformGetClipboardText(ctx) if ProxyFocused then return "" end return Clipboard end

local VFS = {}

local function ImGui_ImplRoblox_AddFile(path, bytes) VFS[path] = bytes end

for path, hex in pairs(IM_INCLUDE("imgui_impl_roblox_fonts.lua")) do
    VFS[path] = hex:gsub("%s", ""):gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end)
end

function ImStd.ImFileOpen(filename, mode)
    local data = VFS[filename]
    return data and { Data = data, Pos = 0 } or nil
end

function ImStd.ImFileClose(f) end

function ImStd.ImFileGetSize(f) return #f.Data end

function ImStd.ImFileRead(f, data, count)
    local s, pos = f.Data, f.Pos
    count = min(count, #s - pos)
    for i = 1, count do data[i] = string.byte(s, pos + i) end
    f.Pos = pos + count
    return count
end

function ImStd.ImFileLoadToMemory(filename, mode)
    local f = ImStd.ImFileOpen(filename, mode)
    if not f or #f.Data == 0 then return end
    local file_data = {}
    local size = ImStd.ImFileRead(f, file_data, #f.Data)
    return file_data, size
end

-- render_scale: imgui pixels per Roblox UI point (default 1; 1.5 on a 150% display = physical resolution)
function ImGui_ImplRoblox_Init(parent, render_scale)
    local io = ImGui.GetIO()

    local gui = Instance.new("ScreenGui")
    gui.Name = "ImGui"
    gui.IgnoreGuiInset = true -- so GetMouseLocation() and the tiles share the same origin
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- layers (one Frame per draw list) stack by ZIndex
    gui.Parent = parent or Players.LocalPlayer:WaitForChild("PlayerGui")

    local BackendData = {
        Time = os.clock(), Gui = gui, Connections = {},
        Textures = Textures.Records, MouseX = -1, MouseY = -1,
        Layers = {}, Overlays = {}, OverlayHolders = {}, OverlayShown = {}, FrameNo = 0, Scale = render_scale or 1,
            TilesActive = false, RenderRate = 60, BusyRenderRate = 0, RedrawBudget = 0, HeartbeatCount = 0,
            NextRender = 0, LastPrimCount = 0, ForceRedraw = true,
    }
    io.BackendPlatformUserData = BackendData
    EditableImages.Backends[BackendData] = true
    io.BackendPlatformName = "imgui_impl_roblox"
    io.BackendRendererName = "imgui_impl_roblox"

    io.BackendFlags = bit32.bor(io.BackendFlags, ImGuiBackendFlags.RendererHasTextures,
        ImGuiBackendFlags.RendererHasVtxOffset)

    local platform_io = ImGui.GetPlatformIO()
    platform_io.Platform_SetClipboardTextFn = ImGui_ImplRoblox_PlatformSetClipboardText
    platform_io.Platform_GetClipboardTextFn = ImGui_ImplRoblox_PlatformGetClipboardText

    local screen = gui.AbsoluteSize
    ImGui_ImplRoblox_UpdateMonitors(screen.X, screen.Y)

    local function connect(signal, fn) table.insert(BackendData.Connections, signal:Connect(fn)) end

    connect(UserInputService.InputBegan, function(input, game_processed)
        local io = ImGui.GetIO()
        local button = MOUSE_BUTTONS[input.UserInputType]
        if button then
            io:AddMouseSourceEvent(ImGuiMouseSource.Mouse)
            io:AddMouseButtonEvent(button, true)
        elseif input.UserInputType == Enum.UserInputType.Keyboard and (not game_processed or ProxyFocused) then
            local ctrl, shift, alt = ImGui_ImplRoblox_UpdateKeyModifiers()
            local key = KEY_MAP[input.KeyCode]
            if key then io:AddKeyEvent(key, true) end
            if ProxyFocused and (key == ImGuiKey.Backspace or key == ImGuiKey.Delete) then
                ImGui_ImplRoblox_GetBackendData().DeleteKeySeen = true
            end

            local v = input.KeyCode.Value
            if v >= 32 and v < 127 and not (ctrl or alt) then
                local c = string.char(v)
                if shift then c = SHIFTED[c] or c:upper() end
                -- while the proxy may own input, hold the char: NewFrame types it only if the proxy didn't deliver text
                if ProxyFocused then table.insert(ImGui_ImplRoblox_GetBackendData().PendingChars, string.byte(c))
                else io:AddInputCharacter(string.byte(c)) end
            end
        end
    end)

    connect(UserInputService.InputEnded, function(input, game_processed)
        local io = ImGui.GetIO()
        local button = MOUSE_BUTTONS[input.UserInputType]
        if button then
            io:AddMouseButtonEvent(button, false)
        elseif input.UserInputType == Enum.UserInputType.Keyboard then
            ImGui_ImplRoblox_UpdateKeyModifiers()
            local key = KEY_MAP[input.KeyCode]
            if key then io:AddKeyEvent(key, false) end
        end
    end)

    connect(UserInputService.InputChanged, function(input, game_processed)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            ImGui.GetIO():AddMouseWheelEvent(0, input.Position.Z)
        end
    end)

    BackendData.PendingChars = {}

    -- Render rate cap trailing edge: the last frame submitted is always drawn, even if the app then stopped rendering
    connect(game:GetService("RunService").Heartbeat, function()
        local d = BackendData.Pending
        if d and os.clock() + 0.002 >= BackendData.NextRender then
            BackendData.Pending = nil
            ImGui_ImplRoblox_RenderDrawData(d)
        elseif BackendData.Stale and BackendData.HeartbeatCount > BackendData.StaleHeartbeat then
            ImGui_ImplRoblox_RenderDrawData(BackendData.Stale)
        end
        BackendData.HeartbeatCount += 1
    end)

    connect(UserInputService.WindowFocused, function() ImGui.GetIO():AddFocusEvent(true) end)
    connect(UserInputService.WindowFocusReleased, function() ImGui.GetIO():AddFocusEvent(false) end)
end

-- Text proxy (opt-in): a hidden TextBox holds focus while a text field is active (OS typing, paste, copy/cut)
function ImGui_ImplRoblox_SetTextProxy(enabled)
    local BackendData = ImGui_ImplRoblox_GetBackendData()
    if not enabled then
        if BackendData.Proxy then
            BackendData.Proxy:Destroy()
            BackendData.Proxy = nil
        end
        ProxyFocused = false
        return
    end
    if BackendData.Proxy then return end
    local proxy = Instance.new("TextBox")
    proxy.Name = "TextProxy"
    proxy.BackgroundTransparency = 1
    proxy.TextTransparency = 0 -- kept opaque but parked off screen: a transparent TextBox may not get native paste
    proxy.BorderSizePixel = 0
    proxy.Size = UDim2.fromOffset(200, 20)
    proxy.Position = UDim2.fromOffset(-10000, -10000)
    proxy.MultiLine = true
    proxy.ClearTextOnFocus = false
    proxy.TextEditable = true
    proxy.Text = ""
    proxy.Parent = BackendData.Gui
    BackendData.Proxy, BackendData.ProxyText = proxy, ""
    -- Text is polled in NewFrame: TextBox change signals are deferred in Roblox
    proxy.FocusLost:Connect(function()
        if BackendData.ProxyReleasing then return end
        -- Roblox drops TextBox focus on any click, also inside imgui: only a click outside imgui ends the edit
        if ImGui.GetIO().WantCaptureMouse then
            BackendData.ProxyLostId = nil
            return
        end
        BackendData.ProxyLostId = BackendData.ProxyActiveId -- don't recapture for the same field
        local g = ImGui.GetCurrentContext()
        if g and g.ActiveId ~= 0 and g.ActiveId == BackendData.ProxyActiveId then
            ImGui.ClearActiveID()
            -- the key falls back to the focused window next: the "don't recapture" covers it too
            if g.NavWindow then BackendData.ProxyActiveId = g.NavWindow.ID; BackendData.ProxyLostId = g.NavWindow.ID end
        end
    end)
end

local function ImGui_ImplRoblox_Shutdown()
    local io = ImGui.GetIO()
    local BackendData = ImGui_ImplRoblox_GetBackendData()
    for _, c in ipairs(BackendData.Connections) do c:Disconnect() end
    DestroyTiles(BackendData)
    EditableImages.Backends[BackendData] = nil
    BackendData.Gui:Destroy()

    io.BackendPlatformUserData = nil
    io.BackendPlatformName = nil
    io.BackendRendererName = nil
    io.BackendFlags = bit32.band(io.BackendFlags, bit32.bnot(bit32.bor(
        ImGuiBackendFlags.RendererHasTextures,
        ImGuiBackendFlags.RendererHasVtxOffset
    )))
end


function ImGui_ImplRoblox_NewFrame()
    PB("ImGui NewFrame (backend)")
    local io = ImGui.GetIO()
    local BackendData = ImGui_ImplRoblox_GetBackendData()
    if BackendData.Pending then -- skipped frame superseded (its draw lists get reset)
        BackendData.Pending = nil
        table.clear(BackendData.Overlays)
    end
    BackendData.Stale = nil

    local screen = BackendData.Gui.AbsoluteSize
    local w, h = floor(screen.X * BackendData.Scale), floor(screen.Y * BackendData.Scale)
    if w ~= BackendData.ScreenW or h ~= BackendData.ScreenH then
        BackendData.ScreenW, BackendData.ScreenH = w, h
        ImGui_ImplRoblox_UpdateMonitors(w, h)
    end
    ImVec2_CopyV(io.DisplaySize, w, h)

    local current_time = os.clock()
    io.DeltaTime = (current_time > BackendData.Time) and (current_time - BackendData.Time) or (1.0 / 60.0)
    BackendData.Time = current_time

    local m = UserInputService:GetMouseLocation()
    if m.X ~= BackendData.MouseX or m.Y ~= BackendData.MouseY then
        BackendData.MouseX, BackendData.MouseY = m.X, m.Y
        io:AddMouseSourceEvent(ImGuiMouseSource.Mouse)
        io:AddMousePosEvent(m.X * BackendData.Scale, m.Y * BackendData.Scale)
    end

    local proxy = BackendData.Proxy
    local g = ImGui.GetCurrentContext()
    local focused_box = proxy and UserInputService:GetFocusedTextBox()
    -- key: the active item (InputText), else the focused window (custom widgets setting PlatformImeData.WantTextInput)
    local proxy_key = g.ActiveId
    if proxy_key == 0 and g.NavWindow then proxy_key = g.NavWindow.ID end
    if proxy_key ~= BackendData.ProxyActiveId then BackendData.ProxyLostId = nil end -- (a "don't recapture" never outlives its field)
    if not proxy then
    elseif io.WantTextInput and proxy_key ~= 0 then
        if proxy_key ~= BackendData.ProxyActiveId or (g.ActiveId ~= 0 and g.ActiveIdIsJustActivated) or g.IO.MouseClicked[0] then
            BackendData.ProxyActiveId = proxy_key
            BackendData.ProxyLostId = nil
        end
        local mouse_up = not (io.MouseDown[0] or io.MouseDown[1] or io.MouseDown[2])
        if focused_box ~= proxy and mouse_up and BackendData.ProxyLostId ~= proxy_key and proxy.Parent
            and (focused_box == nil or not focused_box:IsDescendantOf(game)) then
            -- what it already holds is not new input (else re-typing it would collapse imgui's selection)
            BackendData.ProxyText = proxy.Text
            proxy:CaptureFocus()
            focused_box = UserInputService:GetFocusedTextBox()
        end
    elseif focused_box == proxy then
        BackendData.ProxyReleasing = true
        proxy:ReleaseFocus()
        BackendData.ProxyReleasing = false
        focused_box = nil
    end
    ProxyFocused = proxy ~= nil and focused_box == proxy
    local used_proxy_text = false
    if ProxyFocused then
        local text = proxy.Text
        if text ~= BackendData.ProxyText and text ~= BackendData.ProxyLastRaw then
            BackendData.ProxyLastRaw = text
            -- InputText ignores chars while Ctrl is held; a paste arrives with Ctrl down, so release it around them
            local ctrl = io.KeyCtrl or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
            if ctrl then io:AddKeyEvent(ImGuiMod_Ctrl, false) end
            local prev = BackendData.ProxyText or ""
            if #text < #prev and prev:sub(1, #text) == text and text:sub(-1) ~= "\n" then
                -- the TextBox deleted from its own text (no real selection): one Backspace on imgui's selection
                if not BackendData.DeleteKeySeen then
                    io:AddKeyEvent(ImGuiKey.Backspace, true)
                    io:AddKeyEvent(ImGuiKey.Backspace, false)
                end
            elseif text ~= "\n" and text ~= "\r" and text ~= "\t" then -- Enter/Tab arrive as key events
                local prev = BackendData.ProxyText or ""
                if #text > 0 and (prev == "" or text:sub(1, #prev) ~= prev or #text <= #prev) then
                    for _, cp in utf8.codes(text) do io:AddInputCharacter(cp) end
                elseif #text > #prev then
                    for _, cp in utf8.codes(text:sub(#prev + 1)) do io:AddInputCharacter(cp) end
                end
            end
            -- re-press only if still physically held: the text can arrive after Ctrl's InputEnded, and re-pressing
            -- then left Ctrl stuck down in imgui (typing ignored, shortcuts broken until Ctrl was pressed again)
            if ctrl and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
                io:AddKeyEvent(ImGuiMod_Ctrl, true)
            end
            used_proxy_text = true
            BackendData.ProxyText = nil
        end
        local sel = g.PlatformImeData.SelectedText or "" -- (last frame's widget selection: ImGui.NewFrame() not run yet)
        if sel ~= BackendData.ProxyText then
            proxy.Text = sel
            BackendData.ProxyLastRaw = nil
            BackendData.ProxyText = sel
        end
        -- mirror imgui's selection, fully selected, so native Ctrl+C copies it and typing/Ctrl+V replaces it
        local want_sel, want_cur = (#sel > 0) and 1 or -1, #sel + 1
        if proxy.SelectionStart ~= want_sel then proxy.SelectionStart = want_sel end
        if proxy.CursorPosition ~= want_cur then proxy.CursorPosition = want_cur end
    end

    BackendData.DeleteKeySeen = false

    local pending = BackendData.PendingChars
    if used_proxy_text then
        table.clear(pending) -- the proxy delivered the text: the key-code copies would double it
        BackendData.PendingAge = 0
    elseif #pending > 0 then
        -- the TextBox's Text can update a frame or two after InputBegan: wait before falling back to key codes
        BackendData.PendingAge = (BackendData.PendingAge or 0) + 1
        if not ProxyFocused or BackendData.PendingAge > 3 then
            for _, c in ipairs(pending) do io:AddInputCharacter(c) end
            table.clear(pending)
            BackendData.PendingAge = 0
        end
    end

    -- Tiles Active while over imgui, so Roblox stops passing clicks/wheel to the game (camera zoom etc.)
    local want = io.WantCaptureMouse
    if want ~= BackendData.TilesActive then
        BackendData.TilesActive = want
        for _, set in pairs(BackendData.Layers) do
            for kind = 1, 3 do
                local layer = set[kind]
                if layer then for _, tile in pairs(layer.Tiles) do tile.Label.Active = want end end
            end
        end
    end
    PE()
end

-- Public API (documented in README.md)
function ImGui_ImplRoblox_SetRedrawBudget(ms)
    ImGui_ImplRoblox_GetBackendData().RedrawBudget = (ms or 0) / 1000
end

function ImGui_ImplRoblox_SetRenderRate(hz)
    ImGui_ImplRoblox_GetBackendData().RenderRate = hz or 0
end

function ImGui_ImplRoblox_SetBusyRenderRate(hz)
    ImGui_ImplRoblox_GetBackendData().BusyRenderRate = hz or 0
end

function ImGui_ImplRoblox_SetProfiling(enabled) Textures.SetProfiling(enabled) end
local ImGui_ImplRoblox_IsProfiling = Textures.IsProfiling

function ImGui_ImplRoblox_SetStageTiming(enabled)
    EditableImages.StageTiming = enabled and true or false
    if not EditableImages.StageTiming then EditableImages.StageFrame = nil end
end

function ImGui_ImplRoblox_SetRenderScale(scale)
    local BackendData = ImGui_ImplRoblox_GetBackendData()
    if scale == BackendData.Scale then return end
    BackendData.Scale = scale
    DestroyTiles(BackendData)
    BackendData.ForceRedraw = true
end

function ImGui_ImplRoblox_GetStats()
    local BackendData = ImGui_ImplRoblox_GetBackendData()
    local tiles = 0
    for _, set in pairs(BackendData.Layers) do
        for kind = 1, 3 do if set[kind] then for _ in pairs(set[kind].Tiles) do tiles += 1 end end end
    end
    return { Tiles = tiles, EditableImages = EditableImages.Count, EditableImageBytes = EditableImages.Bytes,
        EditableImageCap = EditableImages.Cap, Instances = #BackendData.Gui:GetDescendants(),
        Frame = BackendData.FrameStats, Renders = BackendData.FrameNo }
end

function ImGui_ImplRoblox_SetEditableImageCap(bytes)
    EditableImages.Cap = bytes or 64 * 1024 * 1024
    EditableImages.Evict(EditableImages.Bytes - EditableImages.Cap)
end

function ImGui_ImplRoblox_EnableParallel(opts) Parallel.Enable(opts) end

function ImGui_ImplRoblox_DisableParallel() Parallel.Disable() end

function ImGui_ImplRoblox_FinishParallel() Parallel.Finish() end

function ImGui_ImplRoblox_BeginParallelFrame() Parallel.BeginFrame() end

function ImGui_ImplRoblox_GetParallelStats() return Parallel.Stats end

function ImGui_ImplRoblox_GetParallelConfig() return Parallel.Config end

ImGui_ImplRoblox = {
    Init           = ImGui_ImplRoblox_Init,
    Shutdown       = ImGui_ImplRoblox_Shutdown,
    NewFrame       = ImGui_ImplRoblox_NewFrame,
    RenderDrawData = ImGui_ImplRoblox_RenderDrawData,
    AddFile        = ImGui_ImplRoblox_AddFile,
    CreateTexture  = ImGui_ImplRoblox_CreateTexture,
    DestroyTexture = ImGui_ImplRoblox_DestroyTexture,
    SetOverlay     = ImGui_ImplRoblox_SetOverlay,
    SetTextProxy   = ImGui_ImplRoblox_SetTextProxy,
    SetRenderScale = ImGui_ImplRoblox_SetRenderScale,
    GetRenderScale = function() return ImGui_ImplRoblox_GetBackendData().Scale end,
    SetRenderRate  = ImGui_ImplRoblox_SetRenderRate,
    SetBusyRenderRate = ImGui_ImplRoblox_SetBusyRenderRate,
    SetRedrawBudget = ImGui_ImplRoblox_SetRedrawBudget,
    SetProfiling   = ImGui_ImplRoblox_SetProfiling,
    IsProfiling    = ImGui_ImplRoblox_IsProfiling,
    SetStageTiming = ImGui_ImplRoblox_SetStageTiming,
    GetStats       = ImGui_ImplRoblox_GetStats,
    SetEditableImageCap = ImGui_ImplRoblox_SetEditableImageCap,
    EnableParallel = ImGui_ImplRoblox_EnableParallel,
    DisableParallel = ImGui_ImplRoblox_DisableParallel,
    FinishParallel = ImGui_ImplRoblox_FinishParallel,
    BeginParallelFrame = ImGui_ImplRoblox_BeginParallelFrame,
    GetParallelStats = ImGui_ImplRoblox_GetParallelStats,
    GetParallelConfig = ImGui_ImplRoblox_GetParallelConfig,
}

return true -- [Roblox] ModuleScripts must return exactly one value