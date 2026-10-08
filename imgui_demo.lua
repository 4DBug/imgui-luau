-- dear imgui demo (Luau port of imgui_demo.cpp). Optional: the library never calls into this file.

do --[[ imgui_demo.lua ]]
--- Dear ImGui WIP
-- (Demo Code) Port of imgui_demo.cpp (docking branch)
-- This file: shared demo helpers, ShowDemoWindow(), DemoWindowMenuBar(), DemoWindowWidgets() dispatcher, example tree/image viewer helpers.
-- Other parts (all global functions, loaded from the same bundle):

local _

----------------------------------------------------------------
-- Shared helpers (globals)
----------------------------------------------------------------

function IMGUI_DEMO_MARKER(_) end -- upstream hook, no-op here

--- Helper to display a little (?) mark which shows a tooltip when hovered.
function HelpMarker(desc)
    ImGui.TextDisabled("(?)")
    if ImGui.BeginItemTooltip() then
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
        ImGui.TextUnformatted(desc)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

function ShowDockingDisabledMessage()
    local io = ImGui.GetIO()
    ImGui.Text("ERROR: Docking is not enabled! See Demo > Configuration.")
    ImGui.Text("Set io.ConfigFlags |= ImGuiConfigFlags_DockingEnable in your code, or ")
    ImGui.SameLine(0.0, 0.0)
    if ImGui.SmallButton("click here") then
        io.ConfigFlags = bit32.bor(io.ConfigFlags, ImGuiConfigFlags.DockingEnable)
    end
end

function DemoNotSupported() ImGui.TextDisabled("(not supported on Roblox)") end
function DemoNotPorted(what) ImGui.TextDisabled("(not ported yet%s)", what and (": " .. what) or "") end
function DemoB2I(b) return b and 1 or 0 end
function DemoHas(flags, f) return bit32.band(flags, f) ~= 0 end
function DemoClamp(v, mn, mx) return (v < mn) and mn or (v > mx) and mx or v end

--- `char buf[size] = "str"` -> zero-terminated byte table
function DemoBuf(str, size)
    local t = {}
    for i = 1, #str do t[i] = string.byte(str, i) end
    t[#str + 1] = 0
    if size then for i = #str + 2, size do t[i] = 0 end end
    return t
end
--- byte table -> Lua string (up to the zero terminator)
function DemoBufStr(buf)
    local n = 0
    while buf[n + 1] ~= nil and buf[n + 1] ~= 0 do n = n + 1 end
    if n == 0 then return "" end
    return ImGui._ByteArrayToString(buf, 1, n + 1)
end

--- "a\0b\0c\0\0" -> { "a", "b", "c" }
function DemoItems(s)
    if type(s) == "table" then return s end
    local t = {}
    for item in string.gmatch(s, "([^%z]+)") do t[#t + 1] = item end
    return t
end

--- Combo() one-liner. `idx` is 0-based; `items` is a table of strings (1-based) or a "\0"-separated string.
--- Uses ImGui.Combo if it exists, falls back to BeginCombo/Selectable.
--- @return int idx, bool changed
function DemoCombo(label, idx, items, popup_max_height_in_items)
    items = DemoItems(items)
    if ImGui.Combo then
        return ImGui.Combo(label, idx, items, #items, popup_max_height_in_items or -1)
    end
    local changed = false
    local preview = (idx >= 0 and idx < #items) and items[idx + 1] or ""
    if ImGui.BeginCombo(label, preview) then
        for n = 0, #items - 1 do
            local is_selected = (idx == n)
            if ImGui.Selectable(items[n + 1], is_selected) then
                idx = n
                changed = true
            end
            if is_selected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndCombo()
    end
    return idx, changed
end

--- ListBox() one-liner (see DemoCombo)
function DemoListBox(label, idx, items, height_in_items)
    items = DemoItems(items)
    if ImGui.ListBox then
        return ImGui.ListBox(label, idx, items, #items, height_in_items or -1)
    end
    local changed = false
    if height_in_items == nil or height_in_items < 0 then height_in_items = math.min(#items, 7) end
    local height_in_items_f = height_in_items + 0.25
    local height_in_pixels = math.floor(ImGui.GetTextLineHeightWithSpacing() * height_in_items_f + ImGui.GetStyle().FramePadding.y * 2.0)
    if ImGui.BeginListBox and ImGui.BeginListBox(label, ImVec2(0.0, height_in_pixels)) then
        for n = 0, #items - 1 do
            local is_selected = (idx == n)
            if ImGui.Selectable(items[n + 1], is_selected) then
                idx = n
                changed = true
            end
            if is_selected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndListBox()
    elseif not ImGui.BeginListBox then
        DemoNotPorted("ListBox")
    end
    return idx, changed
end

--- Closable header: CollapsingHeader(label, &p_open). Returns visible, open.
function DemoCollapsingHeaderClosable(label, open)
    return ImGui.CollapsingHeader(label, open)
end

--- ImColor::HSV() as ImVec4
function DemoHSV(h, s, v, a)
    local r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
    return ImVec4(r, g, b, a or 1.0)
end

--- Minimal ImGuiTextFilter when the library one isn't available (Draw/DrawWithHint/PassFilter/Clear/IsActive)
function DemoTextFilter()
    if ImGuiTextFilter then return ImGuiTextFilter() end
    local f = { InputBuf = DemoBuf("", 256) }
    local function parse(self)
        local inc, exc = {}, {}
        for tok in string.gmatch(string.lower(DemoBufStr(self.InputBuf)), "[^,%s]+") do
            if string.sub(tok, 1, 1) == "-" then
                if #tok > 1 then exc[#exc + 1] = string.sub(tok, 2) end
            else
                inc[#inc + 1] = tok
            end
        end
        return inc, exc
    end
    function f:Draw(label, width)
        if width and width ~= 0 then ImGui.SetNextItemWidth(width) end
        return ImGui.InputText(label or "Filter (inc,-exc)", self.InputBuf, 256)
    end
    function f:DrawWithHint(label, hint, width)
        if width and width ~= 0 then ImGui.SetNextItemWidth(width) end
        return ImGui.InputTextWithHint(label, hint, self.InputBuf, 256)
    end
    function f:Clear() self.InputBuf[1] = 0 end
    function f:IsActive() return self.InputBuf[1] ~= 0 and self.InputBuf[1] ~= nil end
    function f:PassFilter(text)
        local inc, exc = parse(self)
        text = string.lower(text)
        for _, e in ipairs(exc) do if string.find(text, e, 1, true) then return false end end
        if #inc == 0 then return true end
        for _, i in ipairs(inc) do if string.find(text, i, 1, true) then return true end end
        return false
    end
    return f
end

----------------------------------------------------------------
-- [SECTION] Demo Window data
----------------------------------------------------------------

--- Data to be shared across different functions of the demo.
function ImGuiDemoWindowData()
    return {
        -- Examples Apps (accessible from the "Examples" menu)
        ShowMainMenuBar = false,
        ShowAppAssetsBrowser = false,
        ShowAppConsole = false,
        ShowAppCustomRendering = false,
        ShowAppDocuments = false,
        ShowAppDockSpace = false,
        ShowAppImageViewer = false,
        ShowAppLog = false,
        ShowAppLayout = false,
        ShowAppPropertyEditor = false,
        ShowAppSimpleOverlay = false,
        ShowAppAutoResize = false,
        ShowAppConstrainedResize = false,
        ShowAppFullscreen = false,
        ShowAppLongText = false,
        ShowAppWindowTitles = false,

        -- Dear ImGui Tools (accessible from the "Tools" menu)
        ShowMetrics = false,
        ShowDebugLog = false,
        ShowIDStackTool = false,
        ShowStyleEditor = false,
        ShowAbout = false,

        -- Other data
        DisableSections = false,
        LiveEditOverride = false,
        LiveEditFlags = ImGuiItemFlags.LiveEditOnInputText or 0,
        DemoTree = nil,
    }
end

----------------------------------------------------------------
-- [SECTION] Helpers: ExampleTreeNode, ExampleMemberInfo (for use by Property Editor & Multi-Select demos)
----------------------------------------------------------------

function ExampleTreeNode()
    return {
        -- Tree structure
        Name = "",
        UID = 0,
        Parent = nil,
        Childs = {},         -- 1-based
        IndexInParent = 0,   -- 0-based

        -- Leaf Data
        HasData = false,     -- All leaves have data
        DataMyBool = true,
        DataMyInt = 128,
        DataMyVec2 = ImVec2(0.0, 3.141592),
    }
end

function ExampleTree_CreateNode(name, uid, parent)
    local node = ExampleTreeNode()
    node.Name = string.sub(name, 1, 27)
    node.UID = uid
    node.Parent = parent
    node.IndexInParent = parent and #parent.Childs or 0
    if parent then
        parent.Childs[#parent.Childs + 1] = node
    end
    return node
end

function ExampleTree_DestroyNode(node) end -- GC

--- Create example tree data
function ExampleTree_CreateDemoTree()
    local ROOT_ITEMS_COUNT = 20
    local category_names = { "Apple", "Banana", "Cherry", "Kiwi", "Mango", "Orange", "Pear", "Pineapple", "Strawberry", "Watermelon" }
    local category_count = #category_names
    local uid = 0
    uid = uid + 1
    local node_L0 = ExampleTree_CreateNode("<ROOT>", uid, nil)
    for idx_L0 = 0, ROOT_ITEMS_COUNT - 1 do
        local name_buf = string.format("%s %d", category_names[math.floor(idx_L0 / math.floor(ROOT_ITEMS_COUNT / category_count)) + 1], idx_L0 % math.floor(ROOT_ITEMS_COUNT / category_count))
        uid = uid + 1
        local node_L1 = ExampleTree_CreateNode(name_buf, uid, node_L0)
        local number_of_childs = #node_L1.Name
        for idx_L1 = 0, number_of_childs - 1 do
            uid = uid + 1
            local node_L2 = ExampleTree_CreateNode(string.format("Child %d", idx_L1), uid, node_L1)
            node_L2.HasData = true
            if idx_L1 == 0 then
                uid = uid + 1
                local node_L3 = ExampleTree_CreateNode(string.format("Sub-child %d", 0), uid, node_L2)
                node_L3.HasData = true
            end
        end
    end
    return node_L0
end

----------------------------------------------------------------
-- [SECTION] Helpers: ExampleImageViewer
----------------------------------------------------------------

function ExampleImageViewerData()
    return {
        ImageBgColor = IM_COL32(100, 100, 100, 255),
        GridColor    = IM_COL32(255, 255, 255, 100),
        GridEnabled  = true,
        ViewReset    = true,
        ViewOffset   = ImVec2(0, 0), -- in image space
        Zoom         = 10.0,
        ZoomMin      = 1.0,
        ZoomMax      = 10000.0,
    }
end

function ExampleImageViewer_DrawOptions(data)
    ImGui.SetNextItemShortcut(ImGuiKey.G, ImGuiInputFlags.Tooltip)
    _, data.GridEnabled = ImGui.Checkbox("Grid", data.GridEnabled)
    ImGui.SameLine()
    ImGui.SetNextItemWidth(ImGui.GetFontSize() * 10.0)
    local zoom_100 = data.Zoom * 100.0
    local changed
    zoom_100, changed = ImGui.DragFloat("##Zoom", zoom_100, 5.0, data.ZoomMin * 100.0, data.ZoomMax * 100.0, "%.0f%%", ImGuiSliderFlags.AlwaysClamp)
    if changed then
        data.Zoom = zoom_100 / 100.0
    end
end

function ExampleImageViewer_DrawCanvas(data, canvas_size, image_tex_ref, image_w, image_h)
    local io = ImGui.GetIO()
    local platform_io = ImGui.GetPlatformIO()
    local draw_list = ImGui.GetWindowDrawList()
    IM_ASSERT(canvas_size.x >= 0.0 and canvas_size.y >= 0.0)

    -- Layout canvas
    ImGui.InvisibleButton("##Canvas", canvas_size)
    local canvas_min = ImGui.GetItemRectMin()
    local canvas_max = ImGui.GetItemRectMax()

    if data.ViewReset then
        data.ViewOffset = ImVec2((canvas_size.x * 0.5 / data.Zoom) - 0.5, (canvas_size.y * 0.5 / data.Zoom) - 0.5) -- Add half a pixel padding
    end
    data.ViewReset = false

    -- Handle inputs
    if ImGui.SetItemKeyOwner(ImGuiKey.MouseWheelY) then
        if io.MouseWheel ~= 0.0 then
            data.Zoom = DemoClamp(data.Zoom * (1.0 + io.MouseWheel * 0.10), data.ZoomMin, data.ZoomMax)
        end
    end
    local zoom = data.Zoom
    if ImGui.IsItemActive() and ImGui.IsMouseDragging(0) then
        data.ViewOffset.x = data.ViewOffset.x - io.MouseDelta.x / zoom
        data.ViewOffset.y = data.ViewOffset.y - io.MouseDelta.y / zoom
    end

    -- Display image
    local image_min = ImVec2(); local image_max = ImVec2()
    image_min.x = math.floor((canvas_min.x - (data.ViewOffset.x * zoom)) + (canvas_size.x * 0.5))
    image_min.y = math.floor((canvas_min.y - (data.ViewOffset.y * zoom)) + (canvas_size.y * 0.5))
    image_max.x = math.floor(image_min.x + image_w * zoom)
    image_max.y = math.floor(image_min.y + image_h * zoom)
    draw_list:AddRect(ImVec2(canvas_min.x - 1.0, canvas_min.y - 1.0), ImVec2(canvas_max.x + 1.0, canvas_max.y + 1.0), IM_COL32(255, 255, 255, 255))
    draw_list:PushClipRect(canvas_min, canvas_max, true)
    draw_list:AddRectFilled(image_min, image_max, data.ImageBgColor)
    if platform_io.DrawCallback_SetSamplerNearest ~= nil then
        draw_list:AddCallback(platform_io.DrawCallback_SetSamplerNearest)
    end
    draw_list:AddImage(image_tex_ref, image_min, image_max)
    if platform_io.DrawCallback_SetSamplerLinear ~= nil then
        draw_list:AddCallback(ImGui.GetPlatformIO().DrawCallback_SetSamplerLinear)
    end

    -- Display grid lines for visible pixels
    if data.GridEnabled and zoom > 6.0 then
        local step = zoom
        for px = math.floor((canvas_min.x - image_min.x) / step), math.floor((canvas_max.x - image_min.x) / step) do
            draw_list:AddLineV(image_min.x + px * step, canvas_min.y, canvas_max.y, data.GridColor, 1.0)
        end
        for py = math.floor((canvas_min.y - image_min.y) / step), math.floor((canvas_max.y - image_min.y) / step) do
            draw_list:AddLineH(canvas_min.x, canvas_max.x, image_min.y + py * step, data.GridColor, 1.0)
        end
    end
    draw_list:PopClipRect()
end

----------------------------------------------------------------
-- [SECTION] Demo Window / ShowDemoWindow()
----------------------------------------------------------------

local demo_data = ImGuiDemoWindowData()

local no_titlebar       = false
local no_scrollbar      = false
local no_menu           = false
local no_move           = false
local no_resize         = false
local no_collapse       = false
local no_close          = false
local no_nav            = false
local no_background     = false
local no_bring_to_front = false
local no_docking        = false
local unsaved_document  = false

--- Shows an example app: `if X then X.open = X(open) end`. Example apps return the new p_open.
local function RunApp(fn, key, ...)
    if fn then
        demo_data[key] = fn(demo_data[key], ...)
        if demo_data[key] == nil then demo_data[key] = false end
    else
        demo_data[key] = false
    end
end

local function DemoWindowMenuBar(data)
    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu("Menu") then
            IMGUI_DEMO_MARKER("Menu/File")
            ShowExampleMenuFile()
            ImGui.EndMenu()
        end
        if ImGui.BeginMenu("Examples") then
            IMGUI_DEMO_MARKER("Menu/Examples")
            _, data.ShowMainMenuBar = ImGui.MenuItem("Main menu bar", nil, data.ShowMainMenuBar)

            ImGui.SeparatorText("Mini apps")
            _, data.ShowAppAssetsBrowser = ImGui.MenuItem("Assets Browser", nil, data.ShowAppAssetsBrowser)
            _, data.ShowAppConsole = ImGui.MenuItem("Console", nil, data.ShowAppConsole)
            _, data.ShowAppCustomRendering = ImGui.MenuItem("Custom rendering", nil, data.ShowAppCustomRendering)
            _, data.ShowAppDocuments = ImGui.MenuItem("Documents", nil, data.ShowAppDocuments)
            _, data.ShowAppDockSpace = ImGui.MenuItem("Dockspace", nil, data.ShowAppDockSpace)
            _, data.ShowAppImageViewer = ImGui.MenuItem("Image Viewer", nil, data.ShowAppImageViewer)
            _, data.ShowAppLog = ImGui.MenuItem("Log", nil, data.ShowAppLog)
            _, data.ShowAppPropertyEditor = ImGui.MenuItem("Property editor", nil, data.ShowAppPropertyEditor)
            _, data.ShowAppLayout = ImGui.MenuItem("Simple layout", nil, data.ShowAppLayout)
            _, data.ShowAppSimpleOverlay = ImGui.MenuItem("Simple overlay", nil, data.ShowAppSimpleOverlay)

            ImGui.SeparatorText("Concepts")
            _, data.ShowAppAutoResize = ImGui.MenuItem("Auto-resizing window", nil, data.ShowAppAutoResize)
            _, data.ShowAppConstrainedResize = ImGui.MenuItem("Constrained-resizing window", nil, data.ShowAppConstrainedResize)
            _, data.ShowAppFullscreen = ImGui.MenuItem("Fullscreen window", nil, data.ShowAppFullscreen)
            _, data.ShowAppLongText = ImGui.MenuItem("Long text display", nil, data.ShowAppLongText)
            _, data.ShowAppWindowTitles = ImGui.MenuItem("Manipulating window titles", nil, data.ShowAppWindowTitles)

            ImGui.EndMenu()
        end
        if ImGui.BeginMenu("Tools") then
            IMGUI_DEMO_MARKER("Menu/Tools")
            local io = ImGui.GetIO()
            local has_debug_tools = not IMGUI_DISABLE_DEBUG_TOOLS
            _, data.ShowMetrics = ImGui.MenuItem("Metrics/Debugger", nil, data.ShowMetrics, has_debug_tools and ImGui.ShowMetricsWindow ~= nil)
            if ImGui.BeginMenu("Debug Options") then
                ImGui.BeginDisabled(not has_debug_tools)
                _, io.ConfigDebugHighlightIdConflicts = ImGui.Checkbox("Highlight ID Conflicts", io.ConfigDebugHighlightIdConflicts)
                ImGui.EndDisabled()
                _, io.ConfigErrorRecoveryEnableAssert = ImGui.Checkbox("Assert on error recovery", io.ConfigErrorRecoveryEnableAssert)
                ImGui.TextDisabled("(see Demo->Configuration for more)")
                ImGui.EndMenu()
            end
            _, data.ShowDebugLog = ImGui.MenuItem("Debug Log", nil, data.ShowDebugLog, has_debug_tools and ImGui.ShowDebugLogWindow ~= nil)
            _, data.ShowIDStackTool = ImGui.MenuItem("ID Stack Tool", nil, data.ShowIDStackTool, has_debug_tools and ImGui.ShowIDStackToolWindow ~= nil)
            local is_debugger_present = io.ConfigDebugIsDebuggerPresent
            if ImGui.MenuItem("Item Picker", nil, false, has_debug_tools and ImGui.DebugStartItemPicker ~= nil) then
                ImGui.DebugStartItemPicker()
            end
            if not is_debugger_present then
                ImGui.SetItemTooltip("Requires io.ConfigDebugIsDebuggerPresent=true to be set.\n\nWe otherwise disable some extra features to avoid casual users crashing the application.")
            end
            _, data.ShowStyleEditor = ImGui.MenuItem("Style Editor", nil, data.ShowStyleEditor)
            _, data.ShowAbout = ImGui.MenuItem("About Dear ImGui", nil, data.ShowAbout)

            ImGui.EndMenu()
        end
        ImGui.EndMenuBar()
    end
end

--- Configuration header contents (split from ShowDemoWindow to keep the function small)
local function DemoWindowConfiguration(io)
    local F = ImGuiConfigFlags
    local function CF(label, flag)
        local pressed
        pressed, io.ConfigFlags = ImGui.CheckboxFlags(label, io.ConfigFlags, flag)
        return pressed
    end
    local function CB(label, field)
        local pressed
        pressed, io[field] = ImGui.Checkbox(label, io[field])
        return pressed
    end
    local function HM(desc) ImGui.SameLine(); HelpMarker(desc) end

    if ImGui.TreeNode("Configuration##2") then
        IMGUI_DEMO_MARKER("Configuration")
        ImGui.SeparatorText("General")
        CF("io.ConfigFlags: NavEnableKeyboard", F.NavEnableKeyboard)
        HM("Enable keyboard controls.")
        CF("io.ConfigFlags: NavEnableGamepad", F.NavEnableGamepad)
        HM("Enable gamepad controls. Require backend to set io.BackendFlags |= ImGuiBackendFlags_HasGamepad.\n\nRead instructions in imgui.cpp for details.")
        CF("io.ConfigFlags: NoMouse", F.NoMouse)
        HM("Instruct dear imgui to disable mouse inputs and interactions.")

        -- The "NoMouse" option can get us stuck with a disabled mouse! Let's provide an alternative way to fix it:
        if DemoHas(io.ConfigFlags, F.NoMouse) then
            if (ImGui.GetTime() % 0.40) < 0.20 then
                ImGui.SameLine()
                ImGui.Text("<<PRESS SPACE TO DISABLE>>")
            end
            -- Prevent both being checked
            if ImGui.IsKeyPressed(ImGuiKey.Space) or DemoHas(io.ConfigFlags, F.NoKeyboard) then
                io.ConfigFlags = bit32.band(io.ConfigFlags, bit32.bnot(F.NoMouse))
            end
        end

        CF("io.ConfigFlags: NoMouseCursorChange", F.NoMouseCursorChange)
        HM("Instruct backend to not alter mouse cursor shape and visibility.")
        CF("io.ConfigFlags: NoKeyboard", F.NoKeyboard)
        HM("Instruct dear imgui to disable keyboard inputs and interactions.")

        CB("io.ConfigInputTrickleEventQueue", "ConfigInputTrickleEventQueue")
        HM("Enable input queue trickling: some types of events submitted during the same frame (e.g. button down + up) will be spread over multiple frames, improving interactions with low framerates.")
        CB("io.MouseDrawCursor", "MouseDrawCursor")
        HM("Instruct Dear ImGui to render a mouse cursor itself. Note that a mouse cursor rendered via your application GPU rendering path will feel more laggy than hardware cursor, but will be more in sync with your other visuals.\n\nSome desktop applications may use both kinds of cursors (e.g. enable software cursor only when resizing/dragging something).")

        ImGui.SeparatorText("Keyboard/Gamepad Navigation")
        CB("io.ConfigNavSwapGamepadButtons", "ConfigNavSwapGamepadButtons")
        CB("io.ConfigNavMoveSetMousePos", "ConfigNavMoveSetMousePos")
        HM("Directional/tabbing navigation teleports the mouse cursor. May be useful on TV/console systems where moving a virtual mouse is difficult")
        CB("io.ConfigNavCaptureKeyboard", "ConfigNavCaptureKeyboard")
        CB("io.ConfigNavEscapeClearFocusItem", "ConfigNavEscapeClearFocusItem")
        HM("Pressing Escape clears focused item.")
        CB("io.ConfigNavEscapeClearFocusWindow", "ConfigNavEscapeClearFocusWindow")
        HM("Pressing Escape clears focused window.")
        CB("io.ConfigNavCursorVisibleAuto", "ConfigNavCursorVisibleAuto")
        HM("Using directional navigation key makes the cursor visible. Mouse click hides the cursor.")
        CB("io.ConfigNavCursorVisibleAlways", "ConfigNavCursorVisibleAlways")
        HM("Navigation cursor is always visible.")

        ImGui.SeparatorText("Docking")
        CF("io.ConfigFlags: DockingEnable", F.DockingEnable)
        ImGui.SameLine()
        if io.ConfigDockingWithShift then
            HelpMarker("Drag from window title bar or their tab to dock/undock. Hold SHIFT to enable docking.\n\nDrag from window menu button (upper-left button) to undock an entire node (all windows).")
        else
            HelpMarker("Drag from window title bar or their tab to dock/undock. Hold SHIFT to disable docking.\n\nDrag from window menu button (upper-left button) to undock an entire node (all windows).")
        end
        if DemoHas(io.ConfigFlags, F.DockingEnable) then
            ImGui.Indent()
            CB("io.ConfigDockingNoSplit", "ConfigDockingNoSplit")
            HM("Simplified docking mode: disable window splitting, so docking is limited to merging multiple windows together into tab-bars.")
            CB("io.ConfigDockingNoDockingOver", "ConfigDockingNoDockingOver")
            HM("Simplified docking mode: disable window merging into a same tab-bar, so docking is limited to splitting windows.")
            CB("io.ConfigDockingWithShift", "ConfigDockingWithShift")
            HM("Enable docking when holding Shift only (allow to drop in wider space, reduce visual noise)")
            CB("io.ConfigDockingAlwaysTabBar", "ConfigDockingAlwaysTabBar")
            HM("Create a docking node and tab-bar on single floating windows.")
            CB("io.ConfigDockingTransparentPayload", "ConfigDockingTransparentPayload")
            HM("Make window or viewport transparent when docking and only display docking boxes on the target viewport. Useful if rendering of multiple viewport cannot be synced. Best used with ConfigViewportsNoAutoMerge.")
            ImGui.Unindent()
        end

        ImGui.SeparatorText("Multi-viewports")
        CF("io.ConfigFlags: ViewportsEnable", F.ViewportsEnable)
        HM("[beta] Enable beta multi-viewports support. See ImGuiPlatformIO for details.")
        if DemoHas(io.ConfigFlags, F.ViewportsEnable) then
            ImGui.Indent()
            DemoNotSupported()
            ImGui.Unindent()
        end

        ImGui.SeparatorText("Windows")
        CB("io.ConfigWindowsResizeFromEdges", "ConfigWindowsResizeFromEdges")
        HM("Enable resizing of windows from their edges and from the lower-left corner.\nThis requires ImGuiBackendFlags_HasMouseCursors for better mouse cursor feedback.")
        CB("io.ConfigWindowsMoveFromTitleBarOnly", "ConfigWindowsMoveFromTitleBarOnly")
        CB("io.ConfigWindowsCopyContentsWithCtrlC", "ConfigWindowsCopyContentsWithCtrlC") -- [EXPERIMENTAL]
        HM("*EXPERIMENTAL* Ctrl+C copy the contents of focused window into the clipboard.\n\nExperimental because:\n- (1) has known issues with nested Begin/End pairs.\n- (2) text output quality varies.\n- (3) text output is in submission order rather than spatial order.")
        CB("io.ConfigScrollbarScrollByPage", "ConfigScrollbarScrollByPage")
        HM("Enable scrolling page by page when clicking outside the scrollbar grab.\nWhen disabled, always scroll to clicked location.\nWhen enabled, Shift+Click scrolls to clicked location.")

        ImGui.SeparatorText("Widgets")
        CB("io.ConfigInputTextCursorBlink", "ConfigInputTextCursorBlink")
        HM("Enable blinking cursor (optional as some users consider it to be distracting).")
        CB("io.ConfigInputTextEnterKeepActive", "ConfigInputTextEnterKeepActive")
        HM("Pressing Enter will reactivate item and select all text (single-line only).")
        CB("io.ConfigDragClickToInputText", "ConfigDragClickToInputText")
        HM("Enable turning DragXXX widgets into text input with a simple mouse click-release (without moving).")
        CB("io.ConfigMacOSXBehaviors", "ConfigMacOSXBehaviors")
        HM("Swap Cmd<>Ctrl keys, enable various MacOS style behaviors.")
        ImGui.Text("Also see Style->Rendering for rendering options.")

        ImGui.SeparatorText("Settings")
        CB("io.ConfigIniSettingsSaveLastUsedDate", "ConfigIniSettingsSaveLastUsedDate")

        -- Also read: https://github.com/ocornut/imgui/wiki/Error-Handling
        ImGui.SeparatorText("Error Handling")

        CB("io.ConfigErrorRecovery", "ConfigErrorRecovery")
        HM(
            "Options to configure how we handle recoverable errors.\n" ..
            "- Error recovery is not perfect nor guaranteed! It is a feature to ease development.\n" ..
            "- You not are not supposed to rely on it in the course of a normal application run.\n" ..
            "- Possible usage: facilitate recovery from errors triggered from a scripting language or after specific exceptions handlers.\n" ..
            "- Always ensure that on programmers seat you have at minimum Asserts or Tooltips enabled when making direct imgui API call! " ..
            "Otherwise it would severely hinder your ability to catch and correct mistakes!")
        CB("io.ConfigErrorRecoveryEnableAssert", "ConfigErrorRecoveryEnableAssert")
        CB("io.ConfigErrorRecoveryEnableDebugLog", "ConfigErrorRecoveryEnableDebugLog")
        CB("io.ConfigErrorRecoveryEnableTooltip", "ConfigErrorRecoveryEnableTooltip")
        if not io.ConfigErrorRecoveryEnableAssert and not io.ConfigErrorRecoveryEnableDebugLog and not io.ConfigErrorRecoveryEnableTooltip then
            io.ConfigErrorRecoveryEnableAssert = true
            io.ConfigErrorRecoveryEnableDebugLog = true
            io.ConfigErrorRecoveryEnableTooltip = true
        end

        -- Also read: https://github.com/ocornut/imgui/wiki/Debug-Tools
        ImGui.SeparatorText("Debug")
        CB("io.ConfigDebugIsDebuggerPresent", "ConfigDebugIsDebuggerPresent")
        HM("Enable various tools calling IM_DEBUG_BREAK().\n\nRequires a debugger being attached, otherwise IM_DEBUG_BREAK() options will appear to crash your application.")
        CB("io.ConfigDebugHighlightIdConflicts", "ConfigDebugHighlightIdConflicts")
        HM("Highlight and show an error message when multiple items have conflicting identifiers.")
        ImGui.BeginDisabled()
        CB("io.ConfigDebugBeginReturnValueOnce", "ConfigDebugBeginReturnValueOnce")
        ImGui.EndDisabled()
        HM("First calls to Begin()/BeginChild() will return false.\n\nTHIS OPTION IS DISABLED because it needs to be set at application boot-time to make sense. Showing the disabled option is a way to make this feature easier to discover.")
        CB("io.ConfigDebugBeginReturnValueLoop", "ConfigDebugBeginReturnValueLoop")
        HM("Some calls to Begin()/BeginChild() will return false.\n\nWill cycle through window depths then repeat. Windows should be flickering while running.")
        CB("io.ConfigDebugIgnoreFocusLoss", "ConfigDebugIgnoreFocusLoss")
        HM("Option to deactivate io.AddFocusEvent(false) handling. May facilitate interactions with a debugger when focus loss leads to clearing inputs data.")
        CB("io.ConfigDebugDrawListDefaultsToStrokeLegacy", "ConfigDebugDrawListDefaultsToStrokeLegacy")
        HM("Option to default all ImDrawList to ImDrawFlags_StrokeLegacy mode, mimicking pre-1.93.0 rendering.")
        CB("io.ConfigDebugIniSettings", "ConfigDebugIniSettings")
        HM("Option to save .ini data with extra comments (particularly helpful for Docking, but makes saving slower).")

        ImGui.TreePop()
        ImGui.Spacing()
    end

    if ImGui.TreeNode("Backend Flags") then
        IMGUI_DEMO_MARKER("Configuration/Backend Flags")
        HelpMarker(
            "Those flags are set by the backends (imgui_impl_xxx files) to specify their capabilities.\n" ..
            "Here we expose them as read-only fields to avoid breaking interactions with your backend.")

        -- Make a local copy to avoid modifying actual backend flags.
        local B = ImGuiBackendFlags
        local backend_flags = io.BackendFlags
        ImGui.BeginDisabled()
        _, backend_flags = ImGui.CheckboxFlags("io.BackendFlags: HasGamepad", backend_flags, B.HasGamepad)
        _, backend_flags = ImGui.CheckboxFlags("io.BackendFlags: HasMouseCursors", backend_flags, B.HasMouseCursors)
        _, backend_flags = ImGui.CheckboxFlags("io.BackendFlags: HasSetMousePos", backend_flags, B.HasSetMousePos)
        _, backend_flags = ImGui.CheckboxFlags("io.BackendFlags: PlatformHasViewports", backend_flags, B.PlatformHasViewports)
        _, backend_flags = ImGui.CheckboxFlags("io.BackendFlags: HasMouseHoveredViewport", backend_flags, B.HasMouseHoveredViewport)
        _, backend_flags = ImGui.CheckboxFlags("io.BackendFlags: HasParentViewport", backend_flags, B.HasParentViewport)
        _, backend_flags = ImGui.CheckboxFlags("io.BackendFlags: RendererHasVtxOffset", backend_flags, B.RendererHasVtxOffset)
        _, backend_flags = ImGui.CheckboxFlags("io.BackendFlags: RendererHasTextures", backend_flags, B.RendererHasTextures)
        _, backend_flags = ImGui.CheckboxFlags("io.BackendFlags: RendererHasViewports", backend_flags, B.RendererHasViewports)
        ImGui.EndDisabled()

        ImGui.TreePop()
        ImGui.Spacing()
    end

    if ImGui.TreeNode("Style, Fonts") then
        IMGUI_DEMO_MARKER("Configuration/Style, Fonts")
        _, demo_data.ShowStyleEditor = ImGui.Checkbox("Style Editor", demo_data.ShowStyleEditor)
        ImGui.SameLine()
        HelpMarker("The same contents can be accessed in 'Tools->Style Editor' or by calling the ShowStyleEditor() function.")
        ImGui.TreePop()
        ImGui.Spacing()
    end

    if ImGui.TreeNode("Capture/Logging") then
        IMGUI_DEMO_MARKER("Configuration/Capture, Logging")
        HelpMarker(
            "The logging API redirects all text output so you can easily capture the content of " ..
            "a window or a block. Tree nodes can be automatically expanded.\n" ..
            "Try opening any of the contents below in this window and then click one of the \"Log To\" button.")
        if ImGui.LogButtons then
            ImGui.LogButtons()
        else
            DemoNotPorted("LogButtons")
        end

        HelpMarker("You can also call ImGui::LogText() to output directly to the log without a visual output.")
        if ImGui.Button("Copy \"Hello, world!\" to clipboard") then
            if ImGui.LogToClipboard then
                ImGui.LogToClipboard()
                ImGui.LogText("Hello, world!")
                ImGui.LogFinish()
            else
                ImGui.SetClipboardText("Hello, world!") -- internal clipboard only on Roblox
            end
        end
        ImGui.TreePop()
    end
end

--- Demonstrate most Dear ImGui features (this is big function!)
--- @param p_open? bool
--- @return bool? p_open
function ImGui.ShowDemoWindow(p_open)
    IM_ASSERT(ImGui.GetCurrentContext() ~= nil, "Missing Dear ImGui context. Refer to examples app!")

    local data = demo_data

    -- Examples Apps (accessible from the "Examples" menu)
    if data.ShowMainMenuBar then
        if ShowExampleAppMainMenuBar then ShowExampleAppMainMenuBar() end
    end
    if data.ShowAppDockSpace then RunApp(ShowExampleAppDockSpace, "ShowAppDockSpace") end -- Important: Process the Docking app first, as explicit DockSpace() nodes needs to be submitted early (read comments near the DockSpace function)
    if data.ShowAppDocuments then RunApp(ShowExampleAppDocuments, "ShowAppDocuments") end -- ...process the Document app next, as it may also use a DockSpace()
    if data.ShowAppAssetsBrowser then RunApp(ShowExampleAppAssetsBrowser, "ShowAppAssetsBrowser") end
    if data.ShowAppConsole then RunApp(ShowExampleAppConsole, "ShowAppConsole") end
    if data.ShowAppCustomRendering then RunApp(ShowExampleAppCustomRendering, "ShowAppCustomRendering") end
    if data.ShowAppImageViewer then RunApp(ShowExampleAppImageViewer, "ShowAppImageViewer") end
    if data.ShowAppLog then RunApp(ShowExampleAppLog, "ShowAppLog") end
    if data.ShowAppLayout then RunApp(ShowExampleAppLayout, "ShowAppLayout") end
    if data.ShowAppPropertyEditor then RunApp(ShowExampleAppPropertyEditor, "ShowAppPropertyEditor", data) end
    if data.ShowAppSimpleOverlay then RunApp(ShowExampleAppSimpleOverlay, "ShowAppSimpleOverlay") end
    if data.ShowAppAutoResize then RunApp(ShowExampleAppAutoResize, "ShowAppAutoResize") end
    if data.ShowAppConstrainedResize then RunApp(ShowExampleAppConstrainedResize, "ShowAppConstrainedResize") end
    if data.ShowAppFullscreen then RunApp(ShowExampleAppFullscreen, "ShowAppFullscreen") end
    if data.ShowAppLongText then RunApp(ShowExampleAppLongText, "ShowAppLongText") end
    if data.ShowAppWindowTitles then RunApp(ShowExampleAppWindowTitles, "ShowAppWindowTitles") end

    -- Dear ImGui Tools (accessible from the "Tools" menu)
    if data.ShowMetrics then RunApp(ImGui.ShowMetricsWindow, "ShowMetrics") end
    if data.ShowDebugLog then RunApp(ImGui.ShowDebugLogWindow, "ShowDebugLog") end
    if data.ShowIDStackTool then RunApp(ImGui.ShowIDStackToolWindow, "ShowIDStackTool") end
    if data.ShowAbout then RunApp(ImGui.ShowAboutWindow, "ShowAbout") end
    if data.ShowStyleEditor then
        local visible
        data.ShowStyleEditor, visible = ImGui.Begin("Dear ImGui Style Editor", data.ShowStyleEditor)
        if visible then
            ImGui.ShowStyleEditor()
        end
        ImGui.End()
    end

    -- Demonstrate the various window flags. Typically you would just use the default!
    local W = ImGuiWindowFlags
    local window_flags = 0
    if no_titlebar       then window_flags = bit32.bor(window_flags, W.NoTitleBar) end
    if no_scrollbar      then window_flags = bit32.bor(window_flags, W.NoScrollbar) end
    if not no_menu       then window_flags = bit32.bor(window_flags, W.MenuBar) end
    if no_move           then window_flags = bit32.bor(window_flags, W.NoMove) end
    if no_resize         then window_flags = bit32.bor(window_flags, W.NoResize) end
    if no_collapse       then window_flags = bit32.bor(window_flags, W.NoCollapse) end
    if no_nav            then window_flags = bit32.bor(window_flags, W.NoNav) end
    if no_background     then window_flags = bit32.bor(window_flags, W.NoBackground) end
    if no_bring_to_front then window_flags = bit32.bor(window_flags, W.NoBringToFrontOnFocus) end
    if no_docking        then window_flags = bit32.bor(window_flags, W.NoDocking) end
    if unsaved_document  then window_flags = bit32.bor(window_flags, W.UnsavedDocument) end
    if no_close          then p_open = nil end -- Don't pass our bool* to Begin

    -- We specify a default position/size in case there's no data in the .ini file.
    local main_viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(ImVec2(main_viewport.WorkPos.x + 650, main_viewport.WorkPos.y + 20), ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(ImVec2(550, 680), ImGuiCond.FirstUseEver)

    -- Main body of the Demo window starts here.
    local visible
    p_open, visible = ImGui.Begin("Dear ImGui Demo", p_open, window_flags)
    if no_close then p_open = nil end
    if not visible then
        -- Early out if the window is collapsed, as an optimization.
        ImGui.End()
        return p_open
    end

    -- Most framed widgets share a common width settings. Remaining width is used for the label.
    local label_width_base = ImGui.GetFontSize() * 12                  -- Some amount of width for label, based on font size.
    local label_width_max = ImGui.GetContentRegionAvail().x * 0.40     -- ...but always leave some room for framed widgets.
    local label_width = math.min(label_width_base, label_width_max)
    ImGui.PushItemWidth(-label_width)                                  -- Right-align: framed items will leave 'label_width' available for the label.

    -- Menu Bar
    DemoWindowMenuBar(data)

    ImGui.Text("Dear ImGui says hello! (%s) (%d)", IMGUI_VERSION or "WIP", IMGUI_VERSION_NUM or 0)
    ImGui.Spacing()

    if ImGui.CollapsingHeader("Help") then
        IMGUI_DEMO_MARKER("Help")
        ImGui.SeparatorText("ABOUT THIS DEMO:")
        ImGui.BulletText("Sections below are demonstrating many aspects of the library.")
        ImGui.BulletText("The \"Examples\" menu above leads to more demo contents.")
        ImGui.BulletText("The \"Tools\" menu above gives access to: About Box, Style Editor,\n" ..
                         "and Metrics/Debugger (general purpose Dear ImGui debugging tool).")
        ImGui.BulletText("Web demo (w/ source code browser): ")
        ImGui.SameLine(0, 0)
        ImGui.TextLinkOpenURL("https://pthom.github.io/imgui_explorer")

        ImGui.SeparatorText("PROGRAMMER GUIDE:")
        ImGui.BulletText("See the ShowDemoWindow() code in imgui_demo.lua. <- you are here!")
        ImGui.BulletText("See comments in imgui.lua.")
        ImGui.BulletText("See example applications in the examples/ folder.")
        ImGui.BulletText("Read the FAQ at ")
        ImGui.SameLine(0, 0)
        ImGui.TextLinkOpenURL("https://www.dearimgui.com/faq/")
        ImGui.BulletText("Set 'io.ConfigFlags |= NavEnableKeyboard' for keyboard controls.")
        ImGui.BulletText("Set 'io.ConfigFlags |= NavEnableGamepad' for gamepad controls.")

        ImGui.SeparatorText("USER GUIDE:")
        ImGui.ShowUserGuide()
    end

    if ImGui.CollapsingHeader("Configuration") then
        DemoWindowConfiguration(ImGui.GetIO())
    end

    if ImGui.CollapsingHeader("Window options") then
        IMGUI_DEMO_MARKER("Window options")
        if ImGui.BeginTable("split", 3) then
            ImGui.TableNextColumn(); _, no_titlebar       = ImGui.Checkbox("No titlebar", no_titlebar)
            ImGui.TableNextColumn(); _, no_scrollbar      = ImGui.Checkbox("No scrollbar", no_scrollbar)
            ImGui.TableNextColumn(); _, no_menu           = ImGui.Checkbox("No menu", no_menu)
            ImGui.TableNextColumn(); _, no_move           = ImGui.Checkbox("No move", no_move)
            ImGui.TableNextColumn(); _, no_resize         = ImGui.Checkbox("No resize", no_resize)
            ImGui.TableNextColumn(); _, no_collapse       = ImGui.Checkbox("No collapse", no_collapse)
            ImGui.TableNextColumn(); _, no_close          = ImGui.Checkbox("No close", no_close)
            ImGui.TableNextColumn(); _, no_nav            = ImGui.Checkbox("No nav", no_nav)
            ImGui.TableNextColumn(); _, no_background     = ImGui.Checkbox("No background", no_background)
            ImGui.TableNextColumn(); _, no_bring_to_front = ImGui.Checkbox("No bring to front", no_bring_to_front)
            ImGui.TableNextColumn(); _, no_docking        = ImGui.Checkbox("No docking", no_docking)
            ImGui.TableNextColumn(); _, unsaved_document  = ImGui.Checkbox("Unsaved document", unsaved_document)
            ImGui.EndTable()
        end
    end

    -- All demo contents
    DemoWindowWidgets(data)
    if DemoWindowLayout then DemoWindowLayout() end
    if DemoWindowPopups then DemoWindowPopups() end
    if DemoWindowTables then DemoWindowTables() end
    if DemoWindowInputs then DemoWindowInputs() end

    -- End of ShowDemoWindow()
    ImGui.PopItemWidth()
    ImGui.End()
    return p_open
end

----------------------------------------------------------------
-- [SECTION] DemoWindowWidgets()
----------------------------------------------------------------

--- Calls a (global) demo section if it exists, otherwise shows a placeholder
local function Sub(fn, title, ...)
    if fn then fn(...) else
        if ImGui.TreeNode(title) then DemoNotPorted(title) ImGui.TreePop() end
    end
end

function DemoWindowWidgets(data)
    if not ImGui.CollapsingHeader("Widgets") then
        return
    end
    -- IMGUI_DEMO_MARKER("Widgets")

    local disable_all = data.DisableSections -- The Checkbox for that is inside the "Disabled" section at the bottom
    local override_liveedit = data.LiveEditOverride
    if disable_all then
        ImGui.BeginDisabled()
    end
    if override_liveedit then
        ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputText, DemoHas(data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputText))
        ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputScalar, DemoHas(data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputScalar))
    end

    Sub(DemoWindowWidgetsBasic, "Basic")
    Sub(DemoWindowWidgetsBullets, "Bullets")
    Sub(DemoWindowWidgetsCollapsingHeaders, "Collapsing Headers")
    Sub(DemoWindowWidgetsComboBoxes, "Combo")
    Sub(DemoWindowWidgetsColorAndPickers, "Color/Picker Widgets")
    Sub(DemoWindowWidgetsDataTypes, "Data Types")

    if disable_all then
        ImGui.EndDisabled()
    end
    Sub(DemoWindowWidgetsDisableBlocks, "Disable Blocks", data)
    if disable_all then
        ImGui.BeginDisabled()
    end

    Sub(DemoWindowWidgetsDragAndDrop, "Drag and Drop")
    Sub(DemoWindowWidgetsDragsAndSliders, "Drag/Slider Flags")
    Sub(DemoWindowWidgetsFonts, "Fonts")
    Sub(DemoWindowWidgetsImages, "Images")
    Sub(DemoWindowWidgetsListBoxes, "List Boxes")
    Sub(DemoWindowWidgetsLiveEdit, "Live Edit Flags", data)
    Sub(DemoWindowWidgetsMixedValues, "Mixed Values")
    Sub(DemoWindowWidgetsMultiComponents, "Multi-component Widgets")
    Sub(DemoWindowWidgetsPlotting, "Plotting")
    Sub(DemoWindowWidgetsProgressBars, "Progress Bars")
    Sub(DemoWindowWidgetsQueryingStatuses, "Querying Item Status (Edited/Active/Hovered etc.)")
    Sub(DemoWindowWidgetsSelectables, "Selectables")
    Sub(DemoWindowWidgetsSelectionAndMultiSelect, "Selection State & Multi-Select", data)
    Sub(DemoWindowWidgetsTabs, "Tabs")
    Sub(DemoWindowWidgetsText, "Text")
    Sub(DemoWindowWidgetsTextFilter, "Text Filter")
    Sub(DemoWindowWidgetsTextInput, "Text Input")
    Sub(DemoWindowWidgetsTooltips, "Tooltips")
    Sub(DemoWindowWidgetsTreeNodes, "Tree Nodes")
    Sub(DemoWindowWidgetsVerticalSliders, "Vertical Sliders")

    if override_liveedit then
        ImGui.PopItemFlag()
        ImGui.PopItemFlag()
    end
    if disable_all then
        ImGui.EndDisabled()
    end
end

----------------------------------------------------------------
-- [SECTION] User Guide / ShowUserGuide()
----------------------------------------------------------------

function ImGui.ShowUserGuide()
    local io = ImGui.GetIO()
    ImGui.BulletText("Double-click on title bar to collapse window.")
    ImGui.BulletText(
        "Click and drag on lower corner or border to resize window.\n" ..
        "(double-click to auto fit window to its contents)")
    ImGui.BulletText("Ctrl+Click on a slider or drag box to input value as text.")
    ImGui.BulletText("Tab/Shift+Tab to cycle through keyboard editable fields.")
    ImGui.BulletText("Ctrl+Tab/Ctrl+Shift+Tab to focus windows.")
    if io.FontAllowUserScaling then
        ImGui.BulletText("Ctrl+Mouse Wheel to zoom window contents.")
    end
    ImGui.BulletText("While inputting text:\n")
    ImGui.Indent()
    ImGui.BulletText("Ctrl+Left/Right to word jump.")
    ImGui.BulletText("Ctrl+A or double-click to select all.")
    ImGui.BulletText("Ctrl+X/C/V to use clipboard cut/copy/paste.")
    ImGui.BulletText("Ctrl+Z to undo, Ctrl+Y/Ctrl+Shift+Z to redo.")
    ImGui.BulletText("Escape to revert.")
    ImGui.Unindent()
    ImGui.BulletText("With Keyboard controls enabled:")
    ImGui.Indent()
    ImGui.BulletText("Arrow keys or Home/End/PageUp/PageDown to navigate.")
    ImGui.BulletText("Space to activate a widget.")
    ImGui.BulletText("Return to input text into a widget.")
    ImGui.BulletText("Escape to deactivate a widget, close popup,\nexit a child window or the menu layer, clear focus.")
    ImGui.BulletText("Alt to jump to the menu layer of a window.")
    ImGui.BulletText("Menu or Shift+F10 to open a context menu.")
    ImGui.Unindent()
    ImGui.BulletText("With Gamepad controls enabled:")
    ImGui.Indent()
    ImGui.BulletText("D-Pad: Navigate / Tweak / Resize (in Windowing mode).")
    ImGui.BulletText("%s Face button: Activate / Open / Toggle. Hold: activate with text input.", io.ConfigNavSwapGamepadButtons and "East" or "South")
    ImGui.BulletText("%s Face button: Cancel / Close / Exit.", io.ConfigNavSwapGamepadButtons and "South" or "East")
    ImGui.BulletText("West Face button: Toggle Menu. Hold for Windowing mode (Focus/Move/Resize windows).")
    ImGui.BulletText("North Face button: Open Context Menu.")
    ImGui.BulletText("L1/R1: Tweak Slower/Faster, Focus Previous/Next (in Windowing Mode).")
    ImGui.Unindent()
end
end --[[ imgui_demo.lua ]]

do --[[ imgui_demo_2.lua ]]
--- Dear ImGui WIP
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
            draw_list:AddText(ImGui.GetFont(), ImGui.GetFontSize(), text_pos, IM_COL32_WHITE, text_str, 1, #text_str + 1, 0.0, clip_rect)
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

local DCS = { selected = -1, h_borders = true, v_borders = true, columns_count = 4, foo = 1.0, bar = 1.0 }

local function DemoWindowColumns()
    local open = ImGui.TreeNode("Legacy Columns API")
    ImGui.SameLine()
    DemoHelpMarker("Columns() is an old API! Prefer using the more flexible and powerful BeginTable() API!")
    if not open then
        return
    end

    -- Basic columns
    if ImGui.TreeNode("Basic") then
        IMGUI_DEMO_MARKER("Columns (legacy API)/Basic")
        ImGui.Text("Without border:")
        ImGui.Columns(3, "mycolumns3", false) -- 3-ways, no border
        ImGui.Separator()
        for n = 0, 13 do
            local label = string.format("Item %d", n)
            if ImGui.Selectable(label) then end
            ImGui.NextColumn()
        end
        ImGui.Columns(1)
        ImGui.Separator()

        ImGui.Text("With border:")
        ImGui.Columns(4, "mycolumns") -- 4-ways, with border
        ImGui.Separator()
        ImGui.Text("ID"); ImGui.NextColumn()
        ImGui.Text("Name"); ImGui.NextColumn()
        ImGui.Text("Path"); ImGui.NextColumn()
        ImGui.Text("Hovered"); ImGui.NextColumn()
        ImGui.Separator()
        local names = { "One", "Two", "Three" }
        local paths = { "/path/one", "/path/two", "/path/three" }
        for i = 0, 2 do
            local label = string.format("%04d", i)
            if ImGui.Selectable(label, DCS.selected == i, ImGuiSelectableFlags.SpanAllColumns) then
                DCS.selected = i
            end
            local hovered = ImGui.IsItemHovered()
            ImGui.NextColumn()
            ImGui.Text(names[i + 1]); ImGui.NextColumn()
            ImGui.Text(paths[i + 1]); ImGui.NextColumn()
            ImGui.Text("%d", hovered and 1 or 0); ImGui.NextColumn()
        end
        ImGui.Columns(1)
        ImGui.Separator()
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Borders") then
        IMGUI_DEMO_MARKER("Columns (legacy API)/Borders")
        -- NB: Future columns API should allow automatic horizontal borders.
        local lines_count = 3
        ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
        DCS.columns_count = ImGui.DragInt("##columns_count", DCS.columns_count, 0.1, 2, 10, "%d columns")
        if DCS.columns_count < 2 then
            DCS.columns_count = 2
        end
        ImGui.SameLine()
        _, DCS.h_borders = ImGui.Checkbox("horizontal", DCS.h_borders)
        ImGui.SameLine()
        _, DCS.v_borders = ImGui.Checkbox("vertical", DCS.v_borders)
        ImGui.Columns(DCS.columns_count, nil, DCS.v_borders)
        for i = 0, DCS.columns_count * lines_count - 1 do
            if DCS.h_borders and ImGui.GetColumnIndex() == 0 then
                ImGui.Separator()
            end
            ImGui.PushID(i)
            local c = string.char(string.byte("a") + i)
            ImGui.Text("%s%s%s", c, c, c)
            ImGui.Text("Width %.2f", ImGui.GetColumnWidth())
            ImGui.Text("Avail %.2f", ImGui.GetContentRegionAvail().x)
            ImGui.Text("Offset %.2f", ImGui.GetColumnOffset())
            ImGui.Text("Long text that is likely to clip")
            ImGui.Button("Button", ImVec2(-FLT_MIN, 0.0))
            ImGui.PopID()
            ImGui.NextColumn()
        end
        ImGui.Columns(1)
        if DCS.h_borders then
            ImGui.Separator()
        end
        ImGui.TreePop()
    end

    -- Create multiple items in a same cell before switching to next column
    if ImGui.TreeNode("Mixed items") then
        IMGUI_DEMO_MARKER("Columns (legacy API)/Mixed items")
        ImGui.Columns(3, "mixed")
        ImGui.Separator()

        ImGui.Text("Hello")
        ImGui.Button("Banana")
        ImGui.NextColumn()

        ImGui.Text("ImGui")
        ImGui.Button("Apple")
        DCS.foo = ImGui.InputFloat("red", DCS.foo, 0.05, 0, "%.3f")
        ImGui.Text("An extra line here.")
        ImGui.NextColumn()

        ImGui.Text("Sailor")
        ImGui.Button("Corniflower")
        DCS.bar = ImGui.InputFloat("blue", DCS.bar, 0.05, 0, "%.3f")
        ImGui.NextColumn()

        if ImGui.CollapsingHeader("Category A") then ImGui.Text("Blah blah blah") end ImGui.NextColumn()
        if ImGui.CollapsingHeader("Category B") then ImGui.Text("Blah blah blah") end ImGui.NextColumn()
        if ImGui.CollapsingHeader("Category C") then ImGui.Text("Blah blah blah") end ImGui.NextColumn()
        ImGui.Columns(1)
        ImGui.Separator()
        ImGui.TreePop()
    end

    -- Word wrapping
    if ImGui.TreeNode("Word-wrapping") then
        IMGUI_DEMO_MARKER("Columns (legacy API)/Word-wrapping")
        ImGui.Columns(2, "word-wrapping")
        ImGui.Separator()
        ImGui.TextWrapped("The quick brown fox jumps over the lazy dog.")
        ImGui.TextWrapped("Hello Left")
        ImGui.NextColumn()
        ImGui.TextWrapped("The quick brown fox jumps over the lazy dog.")
        ImGui.TextWrapped("Hello Right")
        ImGui.Columns(1)
        ImGui.Separator()
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Horizontal Scrolling") then
        IMGUI_DEMO_MARKER("Columns (legacy API)/Horizontal Scrolling")
        ImGui.SetNextWindowContentSize(ImVec2(1500.0, 0.0))
        local child_size = ImVec2(0, ImGui.GetFontSize() * 20.0)
        ImGui.BeginChild("##ScrollingRegion", child_size, ImGuiChildFlags.None, ImGuiWindowFlags.HorizontalScrollbar)
        ImGui.Columns(10)

        -- Also demonstrate using clipper for large vertical lists
        local ITEMS_COUNT = 2000
        local clipper = ImGuiListClipper()
        clipper:Begin(ITEMS_COUNT)
        while clipper:Step() do
            for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                for j = 0, 9 do
                    ImGui.Text("Line %d Column %d...", i, j)
                    ImGui.NextColumn()
                end
            end
        end
        ImGui.Columns(1)
        ImGui.EndChild()
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Tree") then
        IMGUI_DEMO_MARKER("Columns (legacy API)/Tree")
        ImGui.Columns(2, "tree", true)
        for x = 0, 2 do
            local open1 = ImGui.TreeNode(x, "Node%d", x)
            ImGui.NextColumn()
            ImGui.Text("Node contents")
            ImGui.NextColumn()
            if open1 then
                for y = 0, 2 do
                    local open2 = ImGui.TreeNode(y, "Node%d.%d", x, y)
                    ImGui.NextColumn()
                    ImGui.Text("Node contents")
                    if open2 then
                        ImGui.Text("Even more contents")
                        if ImGui.TreeNode("Tree in column") then
                            ImGui.Text("The quick brown fox jumps over the lazy dog")
                            ImGui.TreePop()
                        end
                    end
                    ImGui.NextColumn()
                    if open2 then
                        ImGui.TreePop()
                    end
                end
                ImGui.TreePop()
            end
        end
        ImGui.Columns(1)
        ImGui.TreePop()
    end

    ImGui.TreePop()
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
end --[[ imgui_demo_2.lua ]]

do --[[ imgui_demo_apps.lua ]]
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

----------------------------------------------------------------
-- [SECTION] Example App: Docking, DockSpace / ShowExampleAppDockSpace()
----------------------------------------------------------------

local DSA = { IsFullscreen = true, KeepWindowPadding = false, DockSpaceFlags = 0, opt_demo_mode = 0, opt_demo_mode_changed = false }

local function ShowExampleAppDockSpaceAdvanced(args, p_open)
    local dockspace_flags = args.DockSpaceFlags
    local W = ImGuiWindowFlags
    local window_flags = W.NoDocking
    if args.IsFullscreen then
        local viewport = ImGui.GetMainViewport()
        ImGui.SetNextWindowPos(viewport.WorkPos)
        ImGui.SetNextWindowSize(viewport.WorkSize)
        ImGui.SetNextWindowViewport(viewport.ID)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 0.0)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 0.0)
        window_flags = bit32.bor(window_flags, W.NoTitleBar, W.NoCollapse, W.NoResize, W.NoMove, W.NoBringToFrontOnFocus, W.NoNavFocus, W.NoBackground)
    else
        dockspace_flags = bit32.band(dockspace_flags, bit32.bnot(ImGuiDockNodeFlags.PassthruCentralNode))
    end
    if not args.KeepWindowPadding then ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(0.0, 0.0)) end
    p_open = ImGui.Begin("Window with a DockSpace", p_open, window_flags)
    if not args.KeepWindowPadding then ImGui.PopStyleVar() end
    if args.IsFullscreen then ImGui.PopStyleVar(2) end
    local dockspace_id = ImGui.GetID("MyDockSpace")
    ImGui.DockSpace(dockspace_id, ImVec2(0.0, 0.0), dockspace_flags)
    ImGui.End()
    return p_open
end

function ShowExampleAppDockSpace(p_open)
    local args = DSA
    if args.opt_demo_mode == 0 then
        ImGui.DockSpaceOverViewport(0, nil, args.DockSpaceFlags)
    else
        p_open = ShowExampleAppDockSpaceAdvanced(args, p_open)
    end
    if args.opt_demo_mode_changed then ImGui.SetNextWindowFocus() end
    p_open = ImGui.Begin("Examples: Dockspace", p_open, ImGuiWindowFlags.MenuBar)
    local c1, c2
    c1, args.opt_demo_mode = ImGui.RadioButton("Basic demo mode", args.opt_demo_mode, 0)
    c2, args.opt_demo_mode = ImGui.RadioButton("Advanced demo mode", args.opt_demo_mode, 1)
    args.opt_demo_mode_changed = c1 or c2
    ImGui.SeparatorText("Options")
    local D = ImGuiDockNodeFlags
    if bit32.band(ImGui.GetIO().ConfigFlags, ImGuiConfigFlags.DockingEnable) == 0 then
        ShowDockingDisabledMessage()
    elseif args.opt_demo_mode == 0 then
        args.DockSpaceFlags = bit32.band(args.DockSpaceFlags, D.PassthruCentralNode)
        _, args.DockSpaceFlags = ImGui.CheckboxFlags("Flag: PassthruCentralNode", args.DockSpaceFlags, D.PassthruCentralNode)
    else
        _, args.IsFullscreen = ImGui.Checkbox("Fullscreen", args.IsFullscreen)
        _, args.KeepWindowPadding = ImGui.Checkbox("Keep Window Padding", args.KeepWindowPadding)
        ImGui.SameLine()
        HelpMarker("This is mostly exposed to facilitate understanding that a DockSpace() is _inside_ a window.")
        ImGui.BeginDisabled(args.IsFullscreen == false)
        _, args.DockSpaceFlags = ImGui.CheckboxFlags("Flag: PassthruCentralNode", args.DockSpaceFlags, D.PassthruCentralNode)
        ImGui.EndDisabled()
        for _, n in ipairs({ "NoDockingOverCentralNode", "NoDockingSplit", "NoUndocking", "NoResize", "AutoHideTabBar" }) do
            if D[n] then _, args.DockSpaceFlags = ImGui.CheckboxFlags("Flag: " .. n, args.DockSpaceFlags, D[n]) end
        end
    end
    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu("Help") then
            ImGui.TextUnformatted("This demonstrates the use of ImGui::DockSpace() which allows you to manually\ncreate a docking node _within_ another window.\nThe \"Basic\" version uses the ImGui::DockSpaceOverViewport() helper. Most applications can probably use this.")
            ImGui.Separator()
            ImGui.TextUnformatted("When docking is enabled, you can ALWAYS dock MOST window into another! Try it now!\n- Drag from window title bar or their tab to dock/undock.\n- Drag from window menu button (upper-left button) to undock an entire node (all windows).\n- Hold SHIFT to disable docking (if io.ConfigDockingWithShift == false, default)\n- Hold SHIFT to enable docking (if io.ConfigDockingWithShift == true)")
            ImGui.Separator()
            ImGui.TextUnformatted("More details:"); ImGui.Bullet(); ImGui.SameLine(); ImGui.TextLinkOpenURL("Docking Wiki page", "https://github.com/ocornut/imgui/wiki/Docking")
            ImGui.BulletText("Read comments in ShowExampleAppDockSpace()")
            ImGui.EndMenu()
        end
        ImGui.EndMenuBar()
    end
    ImGui.End()
    return p_open
end

----------------------------------------------------------------
-- [SECTION] Example App: Documents Handling / ShowExampleAppDocuments()
----------------------------------------------------------------

local function MyDocument(uid, name, open, color)
    if open == nil then open = true end
    local d = { UID = uid, NameBuf = Buf(name, 32), Open = open, OpenPrev = open, Dirty = false, Color = color or ImVec4(1.0, 1.0, 1.0, 1.0) }
    function d:Name() return BufStr(self.NameBuf) end
    function d:DoOpen() self.Open = true end
    function d:DoForceClose() self.Open = false; self.Dirty = false end
    function d:DoSave() self.Dirty = false end
    return d
end

local Docs = nil
local function DocsInit()
    local app = { Documents = {
        MyDocument(0, "Lettuce", true, ImVec4(0.4, 0.8, 0.4, 1.0)),
        MyDocument(1, "Eggplant", true, ImVec4(0.8, 0.5, 1.0, 1.0)),
        MyDocument(2, "Carrot", true, ImVec4(1.0, 0.8, 0.5, 1.0)),
        MyDocument(3, "Tomato", false, ImVec4(1.0, 0.3, 0.4, 1.0)),
        MyDocument(4, "A Rather Long Title", false, ImVec4(0.4, 0.8, 0.8, 1.0)),
        MyDocument(5, "Some Document", false, ImVec4(0.8, 0.8, 1.0, 1.0)),
    }, CloseQueue = {}, RenamingDoc = nil, RenamingStarted = false,
    opt_target = 1, opt_reorderable = true, opt_fitting_flags = ImGuiTabBarFlags.FittingPolicyDefault_ }
    function app:QueueClose(doc)
        for _, d in ipairs(self.CloseQueue) do if d == doc then return end end
        self.CloseQueue[#self.CloseQueue + 1] = doc
    end
    function app:GetTabName(doc) return string.format("%s###doc%d", doc:Name(), doc.UID) end
    function app:DisplayDocContents(doc)
        ImGui.PushID("doc" .. doc.UID)
        ImGui.Text("Document \"%s\"", doc:Name())
        ImGui.PushStyleColor(ImGuiCol.Text, doc.Color)
        ImGui.TextWrapped("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
        ImGui.PopStyleColor()
        ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.R), ImGuiInputFlags.Tooltip)
        if ImGui.Button("Rename..") then self.RenamingDoc = doc; self.RenamingStarted = true end
        ImGui.SameLine()
        ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.M), ImGuiInputFlags.Tooltip)
        if ImGui.Button("Modify") then doc.Dirty = true end
        ImGui.SameLine()
        ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.S), ImGuiInputFlags.Tooltip)
        if ImGui.Button("Save") then doc:DoSave() end
        ImGui.SameLine()
        ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.W), ImGuiInputFlags.Tooltip)
        if ImGui.Button("Close") then self:QueueClose(doc) end
        ImGui.ColorEdit3("color", doc.Color)
        ImGui.PopID()
    end
    function app:DisplayDocContextMenu(doc)
        if not ImGui.BeginPopupContextItem() then return end
        if ImGui.MenuItem("Save " .. doc:Name(), "Ctrl+S", false, doc.Open) then doc:DoSave() end
        if ImGui.MenuItem("Rename...", "Ctrl+R", false, doc.Open) then self.RenamingDoc = doc end
        if ImGui.MenuItem("Close", "Ctrl+W", false, doc.Open) then self:QueueClose(doc) end
        ImGui.EndPopup()
    end
    function app:NotifyOfDocumentsClosedElsewhere()
        for _, doc in ipairs(self.Documents) do
            if not doc.Open and doc.OpenPrev then ImGui.SetTabItemClosed(doc:Name()) end
            doc.OpenPrev = doc.Open
        end
    end
    return app
end

function ShowExampleAppDocuments(p_open)
    Docs = Docs or DocsInit()
    local app = Docs
    local Target_Tab, Target_DockSpaceAndWindow = 1, 2
    local window_contents_visible
    p_open, window_contents_visible = ImGui.Begin("Example: Documents", p_open, ImGuiWindowFlags.MenuBar)
    if not window_contents_visible and app.opt_target ~= Target_DockSpaceAndWindow then
        ImGui.End()
        return p_open
    end

    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu("File") then
            local open_count = 0
            for _, doc in ipairs(app.Documents) do if doc.Open then open_count = open_count + 1 end end
            if ImGui.BeginMenu("Open", open_count < #app.Documents) then
                for _, doc in ipairs(app.Documents) do
                    if not doc.Open and ImGui.MenuItem(doc:Name()) then doc:DoOpen() end
                end
                ImGui.EndMenu()
            end
            if ImGui.MenuItem("Close All Documents", nil, false, open_count > 0) then
                for _, doc in ipairs(app.Documents) do app:QueueClose(doc) end
            end
            if ImGui.MenuItem("Exit") and p_open ~= nil then p_open = false end
            ImGui.EndMenu()
        end
        ImGui.EndMenuBar()
    end

    for doc_n, doc in ipairs(app.Documents) do
        if doc_n > 1 then ImGui.SameLine() end
        ImGui.PushID("doc" .. doc.UID)
        local pressed
        pressed, doc.Open = ImGui.Checkbox(doc:Name(), doc.Open)
        if pressed and not doc.Open then doc:DoForceClose() end
        ImGui.PopID()
    end
    ImGui.PushItemWidth(ImGui.GetFontSize() * 12)
    app.opt_target = ImGui.Combo("Output", app.opt_target, "None\0TabBar+Tabs\0DockSpace+Window\0")
    ImGui.PopItemWidth()
    local redock_all = false
    if app.opt_target == Target_Tab then ImGui.SameLine(); _, app.opt_reorderable = ImGui.Checkbox("Reorderable Tabs", app.opt_reorderable) end
    if app.opt_target == Target_DockSpaceAndWindow then ImGui.SameLine(); redock_all = ImGui.Button("Redock all") end
    ImGui.Separator()

    if app.opt_target == Target_Tab then
        local tab_bar_flags = bit32.bor(app.opt_fitting_flags, app.opt_reorderable and ImGuiTabBarFlags.Reorderable or 0, ImGuiTabBarFlags.DrawSelectedOverline)
        if ImGui.BeginTabBar("##tabs", tab_bar_flags) then
            if app.opt_reorderable then app:NotifyOfDocumentsClosedElsewhere() end
            for _, doc in ipairs(app.Documents) do
                if doc.Open then
                    local tab_flags = doc.Dirty and ImGuiTabItemFlags.UnsavedDocument or 0
                    local visible
                    visible, doc.Open = ImGui.BeginTabItem(app:GetTabName(doc), doc.Open, tab_flags)
                    if not doc.Open and doc.Dirty then
                        doc.Open = true
                        app:QueueClose(doc)
                    end
                    app:DisplayDocContextMenu(doc)
                    if visible then
                        app:DisplayDocContents(doc)
                        ImGui.EndTabItem()
                    end
                end
            end
            ImGui.EndTabBar()
        end
    elseif app.opt_target == Target_DockSpaceAndWindow then
        if bit32.band(ImGui.GetIO().ConfigFlags, ImGuiConfigFlags.DockingEnable) ~= 0 then
            app:NotifyOfDocumentsClosedElsewhere()
            local dockspace_id = ImGui.GetID("MyDockSpace")
            ImGui.DockSpace(dockspace_id)
            for _, doc in ipairs(app.Documents) do
                if doc.Open then
                    ImGui.SetNextWindowDockID(dockspace_id, redock_all and ImGuiCond.Always or ImGuiCond.FirstUseEver)
                    local window_flags = doc.Dirty and ImGuiWindowFlags.UnsavedDocument or 0
                    local visible
                    doc.Open, visible = ImGui.Begin(doc:Name(), doc.Open, window_flags)
                    if not doc.Open and doc.Dirty then
                        doc.Open = true
                        app:QueueClose(doc)
                    end
                    app:DisplayDocContextMenu(doc)
                    if visible then app:DisplayDocContents(doc) end
                    ImGui.End()
                end
            end
        else
            ShowDockingDisabledMessage()
        end
    end

    if not window_contents_visible then
        ImGui.End()
        return p_open
    end

    if app.RenamingDoc ~= nil then
        if app.RenamingStarted then ImGui.OpenPopup("Rename") end
        if ImGui.BeginPopup("Rename") then
            ImGui.SetNextItemWidth(ImGui.GetFontSize() * 30)
            if ImGui.InputText("###Name", app.RenamingDoc.NameBuf, 32, ImGuiInputTextFlags.EnterReturnsTrue) then
                ImGui.CloseCurrentPopup()
                app.RenamingDoc = nil
            end
            if app.RenamingStarted then ImGui.SetKeyboardFocusHere(-1) end
            ImGui.EndPopup()
        else
            app.RenamingDoc = nil
        end
        app.RenamingStarted = false
    end

    if #app.CloseQueue > 0 then
        local close_queue_unsaved_documents = 0
        for _, doc in ipairs(app.CloseQueue) do if doc.Dirty then close_queue_unsaved_documents = close_queue_unsaved_documents + 1 end end
        if close_queue_unsaved_documents == 0 then
            for _, doc in ipairs(app.CloseQueue) do doc:DoForceClose() end
            app.CloseQueue = {}
        else
            if not ImGui.IsPopupOpen("Save?") then ImGui.OpenPopup("Save?") end
            if ImGui.BeginPopupModal("Save?", nil, ImGuiWindowFlags.AlwaysAutoResize) then
                ImGui.Text("Save change to the following items?")
                local item_height = ImGui.GetTextLineHeightWithSpacing()
                if ImGui.BeginChild(ImGui.GetID("frame"), ImVec2(-FLT_MIN, 6.25 * item_height), ImGuiChildFlags.FrameStyle) then
                    for _, doc in ipairs(app.CloseQueue) do if doc.Dirty then ImGui.Text("%s", doc:Name()) end end
                end
                ImGui.EndChild()
                local button_size = ImVec2(ImGui.GetFontSize() * 7.0, 0.0)
                if ImGui.Button("Yes", button_size) then
                    for _, doc in ipairs(app.CloseQueue) do
                        if doc.Dirty then doc:DoSave() end
                        doc:DoForceClose()
                    end
                    app.CloseQueue = {}
                    ImGui.CloseCurrentPopup()
                end
                ImGui.SameLine()
                if ImGui.Button("No", button_size) then
                    for _, doc in ipairs(app.CloseQueue) do doc:DoForceClose() end
                    app.CloseQueue = {}
                    ImGui.CloseCurrentPopup()
                end
                ImGui.SameLine()
                if ImGui.Button("Cancel", button_size) then
                    app.CloseQueue = {}
                    ImGui.CloseCurrentPopup()
                end
                ImGui.EndPopup()
            end
        end
    end
    ImGui.End()
    return p_open
end
end --[[ imgui_demo_apps.lua ]]

do --[[ imgui_demo_widgets.lua ]]
-- Demo: DemoWindowWidgets*() sections (port of imgui_demo.cpp). Globals picked up by DemoWindowWidgets() in imgui_demo.lua.
local _
local function HSV(h, s, v, a) local r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v) return ImVec4(r, g, b, a or 1.0) end
local Buf, BufStr = DemoBuf, DemoBufStr
local S = {} -- statics, one subtable per section

local ExampleNames = {
    "Artichoke", "Arugula", "Asparagus", "Avocado", "Bamboo Shoots", "Bean Sprouts", "Beans", "Beet", "Belgian Endive", "Bell Pepper",
    "Bitter Gourd", "Bok Choy", "Broccoli", "Brussels Sprouts", "Burdock Root", "Cabbage", "Calabash", "Capers", "Carrot", "Cassava",
    "Cauliflower", "Celery", "Celery Root", "Celcuce", "Chayote", "Chinese Broccoli", "Corn", "Cucumber" }

S.basic = { clicked = 0, check = true, e = 0, counter = 0, str0 = Buf("Hello, world!", 128), str1 = Buf("", 128),
    i0 = 123, f0 = 0.001, d0 = 999999.00000001, f1 = 1.e10, vec4a = { 0.10, 0.20, 0.30, 0.44 },
    di1 = 50, di2 = 42, di3 = 128, df1 = 1.0, df2 = 0.0067, si1 = 0, sf1 = 0.123, sf2 = 0.0, angle = 0.0, elem = 0,
    col1 = { 1.0, 0.0, 0.2 }, col2 = { 0.4, 0.7, 0.0, 0.5 }, combo = 0, listbox = 1 }

function DemoWindowWidgetsBasic()
    if not ImGui.TreeNode("Basic") then return end
    local s = S.basic
    ImGui.SeparatorText("General")
    if ImGui.Button("Button") then s.clicked = s.clicked + 1 end
    if s.clicked % 2 == 1 then ImGui.SameLine(); ImGui.Text("Thanks for clicking me!") end
    _, s.check = ImGui.Checkbox("checkbox", s.check)
    _, s.e = ImGui.RadioButton("radio a", s.e, 0); ImGui.SameLine()
    _, s.e = ImGui.RadioButton("radio b", s.e, 1); ImGui.SameLine()
    _, s.e = ImGui.RadioButton("radio c", s.e, 2)
    ImGui.AlignTextToFramePadding()
    ImGui.TextLinkOpenURL("Hyperlink", "https://github.com/ocornut/imgui/wiki/Error-Handling")
    for i = 0, 6 do
        if i > 0 then ImGui.SameLine() end
        ImGui.PushID(i)
        ImGui.PushStyleColor(ImGuiCol.Button, HSV(i / 7.0, 0.6, 0.6))
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, HSV(i / 7.0, 0.7, 0.7))
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, HSV(i / 7.0, 0.8, 0.8))
        ImGui.Button("Click")
        ImGui.PopStyleColor(3)
        ImGui.PopID()
    end
    ImGui.AlignTextToFramePadding()
    ImGui.Text("Hold to repeat:")
    ImGui.SameLine()
    local spacing = ImGui.GetStyle().ItemInnerSpacing.x
    ImGui.PushItemFlag(ImGuiItemFlags.ButtonRepeat, true)
    if ImGui.ArrowButton("##left", ImGuiDir.Left) then s.counter = s.counter - 1 end
    ImGui.SameLine(0.0, spacing)
    if ImGui.ArrowButton("##right", ImGuiDir.Right) then s.counter = s.counter + 1 end
    ImGui.PopItemFlag()
    ImGui.SameLine()
    ImGui.Text("%d", s.counter)
    ImGui.Button("Tooltip")
    ImGui.SetItemTooltip("I am a tooltip")
    ImGui.LabelText("label", "Value")

    ImGui.SeparatorText("Inputs")
    ImGui.InputText("input text", s.str0, 128)
    ImGui.SameLine(); HelpMarker("USER:\nHold Shift or use mouse to select text.\nCtrl+Left/Right to word jump.\nCtrl+A or Double-Click to select all.\nCtrl+X,Ctrl+C,Ctrl+V for clipboard.\nCtrl+Z to undo, Ctrl+Y/Ctrl+Shift+Z to redo.\nEscape to revert.")
    ImGui.InputTextWithHint("input text (w/ hint)", "enter text here", s.str1, 128)
    s.i0 = ImGui.InputInt("input int", s.i0)
    s.f0 = ImGui.InputFloat("input float", s.f0, 0.01, 1.0, "%.3f")
    s.d0 = ImGui.InputDouble("input double", s.d0, 0.01, 1.0, "%.8f")
    s.f1 = ImGui.InputFloat("input scientific", s.f1, 0.0, 0.0, "%e")
    ImGui.SameLine(); HelpMarker("You can input value using the scientific notation,\n  e.g. \"1e+8\" becomes \"100000000\".")
    ImGui.InputFloat3("input float3", s.vec4a)

    ImGui.SeparatorText("Drags")
    s.di1 = ImGui.DragInt("drag int", s.di1, 1)
    ImGui.SameLine(); HelpMarker("Click and drag to edit value.\nHold Shift/Alt for faster/slower edit.\nDouble-Click or Ctrl+Click to input value.")
    s.di2 = ImGui.DragInt("drag int 0..100", s.di2, 1, 0, 100, "%d%%", ImGuiSliderFlags.AlwaysClamp)
    s.di3 = ImGui.DragInt("drag int wrap 100..200", s.di3, 1, 100, 200, "%d", ImGuiSliderFlags.WrapAround)
    s.df1 = ImGui.DragFloat("drag float", s.df1, 0.005)
    s.df2 = ImGui.DragFloat("drag small float", s.df2, 0.0001, 0.0, 0.0, "%.06f ns")

    ImGui.SeparatorText("Sliders")
    s.si1 = ImGui.SliderInt("slider int", s.si1, -1, 3)
    ImGui.SameLine(); HelpMarker("Ctrl+Click to input value.")
    s.sf1 = ImGui.SliderFloat("slider float", s.sf1, 0.0, 1.0, "ratio = %.3f")
    s.sf2 = ImGui.SliderFloat("slider float (log)", s.sf2, -10.0, 10.0, "%.4f", ImGuiSliderFlags.Logarithmic)
    s.angle = ImGui.SliderAngle("slider angle", s.angle)
    local elems_names = { "Fire", "Earth", "Air", "Water" }
    local elem_name = elems_names[s.elem + 1] or "Unknown"
    s.elem = ImGui.SliderInt("slider enum", s.elem, 0, 3, elem_name)
    ImGui.SameLine(); HelpMarker("Using the format string parameter to display a name instead of the underlying integer.")

    ImGui.SeparatorText("Selectors/Pickers")
    ImGui.ColorEdit3("color 1", s.col1)
    ImGui.SameLine(); HelpMarker("Click on the color square to open a color picker.\nClick and hold to use drag and drop.\nRight-Click on the color square to show options.\nCtrl+Click on individual component to input value.\n")
    ImGui.ColorEdit4("color 2", s.col2)
    s.combo = ImGui.Combo("combo", s.combo, { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIIIIII", "JJJJ", "KKKKKKK" })
    ImGui.SameLine(); HelpMarker("Using the simplified one-liner Combo API here.")
    s.listbox = ImGui.ListBox("listbox", s.listbox, { "Apple", "Banana", "Cherry", "Kiwi", "Mango", "Orange", "Pineapple", "Strawberry", "Watermelon" }, 9, 4)
    ImGui.SameLine(); HelpMarker("Using the simplified one-liner ListBox API here.")
    ImGui.TreePop()
end

S.chdr = { closable_group = true }
function DemoWindowWidgetsBullets()
    if not ImGui.TreeNode("Bullets") then return end
    ImGui.BulletText("Bullet point 1")
    ImGui.BulletText("Bullet point 2\nOn multiple lines")
    if ImGui.TreeNode("Tree node") then ImGui.BulletText("Another bullet point"); ImGui.TreePop() end
    ImGui.Bullet(); ImGui.Text("Bullet point 3 (two calls)")
    ImGui.Bullet(); ImGui.SmallButton("Button")
    ImGui.TreePop()
end

function DemoWindowWidgetsCollapsingHeaders()
    if not ImGui.TreeNode("Collapsing Headers") then return end
    local s = S.chdr
    _, s.closable_group = ImGui.Checkbox("Show 2nd header", s.closable_group)
    if ImGui.CollapsingHeader("Header", ImGuiTreeNodeFlags.None) then
        ImGui.Text("IsItemHovered: %d", ImGui.IsItemHovered() and 1 or 0)
        for i = 0, 4 do ImGui.Text("Some content %d", i) end
    end
    local open
    open, s.closable_group = ImGui.CollapsingHeader("Header with a close button", s.closable_group)
    if open then
        ImGui.Text("IsItemHovered: %d", ImGui.IsItemHovered() and 1 or 0)
        for i = 0, 4 do ImGui.Text("More content %d", i) end
    end
    ImGui.TreePop()
end

IMGUI_PAYLOAD_TYPE_COLOR_3F = IMGUI_PAYLOAD_TYPE_COLOR_3F or "_COL3F"
IMGUI_PAYLOAD_TYPE_COLOR_4F = IMGUI_PAYLOAD_TYPE_COLOR_4F or "_COL4F"

S.color = { color = ImVec4(114.0 / 255.0, 144.0 / 255.0, 154.0 / 255.0, 200.0 / 255.0), base_flags = 0, palette = nil,
    backup = ImVec4(), no_border = false, ref_color = false, ref_color_v = ImVec4(1.0, 0.0, 1.0, 0.5), picker_mode = 0,
    display_mode = 0, picker_flags = ImGuiColorEditFlags.AlphaBar, hsv = ImVec4(0.23, 1.0, 1.0, 1.0) }

function DemoWindowWidgetsColorAndPickers()
    if not ImGui.TreeNode("Color/Picker Widgets") then return end
    local s = S.color
    local CE = ImGuiColorEditFlags
    local color = s.color

    ImGui.SeparatorText("Options")
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoAlpha", s.base_flags, CE.NoAlpha)
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaOpaque", s.base_flags, CE.AlphaOpaque)
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaNoBg", s.base_flags, CE.AlphaNoBg)
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaPreviewHalf", s.base_flags, CE.AlphaPreviewHalf)
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoOptions", s.base_flags, CE.NoOptions); ImGui.SameLine(); HelpMarker("Right-click on the individual color widget to show options.")
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoDragDrop", s.base_flags, CE.NoDragDrop)
    if CE.NoColorMarkers then _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoColorMarkers", s.base_flags, CE.NoColorMarkers) end
    _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_HDR", s.base_flags, CE.HDR); ImGui.SameLine(); HelpMarker("Currently all this does is to lift the 0..1 limits on dragging widgets.")
    local base_flags = s.base_flags

    ImGui.SeparatorText("Inline color editor")
    ImGui.Text("Color widget:")
    ImGui.SameLine(); HelpMarker("Click on the color square to open a color picker.\nCtrl+Click on individual component to input value.\n")
    ImGui.ColorEdit3("MyColor##1", color, base_flags)
    ImGui.Text("Color widget HSV with Alpha:")
    ImGui.ColorEdit4("MyColor##2", color, bit32.bor(CE.DisplayHSV, base_flags))
    ImGui.Text("Color widget with Float Display:")
    ImGui.ColorEdit4("MyColor##2f", color, bit32.bor(CE.Float, base_flags))
    ImGui.Text("Color button with Picker:")
    ImGui.SameLine(); HelpMarker("With the ImGuiColorEditFlags_NoInputs flag you can hide all the slider/text inputs.\nWith the ImGuiColorEditFlags_NoLabel flag you can pass a non-empty label which will only be used for the tooltip and picker popup.")
    ImGui.ColorEdit4("MyColor##3", color, bit32.bor(CE.NoInputs, CE.NoLabel, base_flags))

    ImGui.Text("Color button with Custom Picker Popup:")
    if s.palette == nil then
        s.palette = {}
        for n = 0, 31 do s.palette[n] = HSV(n / 31.0, 0.8, 0.8, 1.0) end
    end
    local open_popup = ImGui.ColorButton("MyColor##3b", color, base_flags)
    ImGui.SameLine(0, ImGui.GetStyle().ItemInnerSpacing.x)
    open_popup = ImGui.Button("Palette") or open_popup
    if open_popup then
        ImGui.OpenPopup("mypicker")
        ImVec4_Copy(s.backup, color)
    end
    if ImGui.BeginPopup("mypicker") then
        ImGui.Text("MY CUSTOM COLOR PICKER WITH AN AMAZING PALETTE!")
        ImGui.Separator()
        ImGui.ColorPicker4("##picker", color, bit32.bor(base_flags, CE.NoSidePreview, CE.NoSmallPreview))
        ImGui.SameLine()
        ImGui.BeginGroup()
        ImGui.Text("Current")
        ImGui.ColorButton("##current", color, bit32.bor(CE.NoPicker, CE.AlphaPreviewHalf), ImVec2(60, 40))
        ImGui.Text("Previous")
        if ImGui.ColorButton("##previous", s.backup, bit32.bor(CE.NoPicker, CE.AlphaPreviewHalf), ImVec2(60, 40)) then
            ImVec4_Copy(color, s.backup)
        end
        ImGui.Separator()
        ImGui.Text("Palette")
        for n = 0, 31 do
            ImGui.PushID(n)
            if n % 8 ~= 0 then ImGui.SameLine(0.0, ImGui.GetStyle().ItemSpacing.y) end
            local pal = s.palette[n]
            if ImGui.ColorButton("##palette", pal, bit32.bor(CE.NoAlpha, CE.NoPicker, CE.NoTooltip), ImVec2(20, 20)) then
                color.x = pal.x; color.y = pal.y; color.z = pal.z -- Preserve alpha!
            end
            if ImGui.BeginDragDropTarget() then
                local payload = ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_3F)
                if payload and payload.Data then pal.x, pal.y, pal.z = payload.Data[1], payload.Data[2], payload.Data[3] end
                payload = ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_4F)
                if payload and payload.Data then pal.x, pal.y, pal.z, pal.w = payload.Data[1], payload.Data[2], payload.Data[3], payload.Data[4] end
                ImGui.EndDragDropTarget()
            end
            ImGui.PopID()
        end
        ImGui.EndGroup()
        ImGui.EndPopup()
    end

    ImGui.Text("Color button only:")
    _, s.no_border = ImGui.Checkbox("ImGuiColorEditFlags_NoBorder", s.no_border)
    ImGui.ColorButton("MyColor##3c", color, bit32.bor(base_flags, s.no_border and CE.NoBorder or 0), ImVec2(80, 80))

    ImGui.SeparatorText("Color picker")
    ImGui.PushID("Color picker")
    _, s.picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoAlpha", s.picker_flags, CE.NoAlpha)
    _, s.picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaBar", s.picker_flags, CE.AlphaBar)
    _, s.picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoSidePreview", s.picker_flags, CE.NoSidePreview)
    if bit32.band(s.picker_flags, CE.NoSidePreview) ~= 0 then
        ImGui.SameLine()
        _, s.ref_color = ImGui.Checkbox("With Ref Color", s.ref_color)
        if s.ref_color then
            ImGui.SameLine()
            ImGui.ColorEdit4("##RefColor", s.ref_color_v, bit32.bor(CE.NoInputs, base_flags))
        end
    end
    _, s.picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_PickerNoRotate", s.picker_flags, CE.PickerNoRotate)
    s.picker_mode = ImGui.Combo("Picker Mode", s.picker_mode, "Auto/Current\0ImGuiColorEditFlags_PickerHueBar\0ImGuiColorEditFlags_PickerHueWheel\0")
    ImGui.SameLine(); HelpMarker("When not specified explicitly, user can right-click the picker to change mode.")
    s.display_mode = ImGui.Combo("Display Mode", s.display_mode, "Auto/Current\0ImGuiColorEditFlags_NoInputs\0ImGuiColorEditFlags_DisplayRGB\0ImGuiColorEditFlags_DisplayHSV\0ImGuiColorEditFlags_DisplayHex\0")
    ImGui.SameLine(); HelpMarker("ColorEdit defaults to displaying RGB inputs if you don't specify a display mode, but the user can change it with a right-click on those inputs.\n\nColorPicker defaults to displaying RGB+HSV+Hex if you don't specify a display mode.\n\nYou can change the defaults using io.ConfigColorEditFlags.")
    local flags = bit32.bor(base_flags, s.picker_flags)
    if s.picker_mode == 1 then flags = bit32.bor(flags, CE.PickerHueBar) end
    if s.picker_mode == 2 then flags = bit32.bor(flags, CE.PickerHueWheel) end
    if s.display_mode == 1 then flags = bit32.bor(flags, CE.NoInputs) end
    if s.display_mode == 2 then flags = bit32.bor(flags, CE.DisplayRGB) end
    if s.display_mode == 3 then flags = bit32.bor(flags, CE.DisplayHSV) end
    if s.display_mode == 4 then flags = bit32.bor(flags, CE.DisplayHex) end
    ImGui.ColorPicker4("MyColor##4", color, flags, s.ref_color and s.ref_color_v or nil)

    ImGui.Text("Set defaults in code:")
    ImGui.SameLine(); HelpMarker("io.ConfigColorEditFlags is designed to allow you to set boot-time default.")
    if ImGui.Button("Overwrite default: Uint8 + HSV + Hue Bar") then
        ImGui.GetIO().ConfigColorEditFlags = bit32.bor(CE.Uint8, CE.DisplayHSV, CE.PickerHueBar, CE.InputRGB) -- [port] + InputRGB: upstream omits it and then trips its own InputMask_ assert
    end
    if ImGui.Button("Overwrite default: Float + HDR + Hue Wheel") then
        ImGui.GetIO().ConfigColorEditFlags = bit32.bor(CE.Float, CE.HDR, CE.PickerHueWheel, CE.DisplayRGB, CE.InputRGB)
    end

    ImGui.Text("Both types:")
    local w = (ImGui.GetContentRegionAvail().x - ImGui.GetStyle().ItemSpacing.y) * 0.40
    ImGui.SetNextItemWidth(w)
    ImGui.ColorPicker3("##MyColor##5", color, bit32.bor(CE.PickerHueBar, CE.NoSidePreview, CE.NoInputs, CE.NoAlpha))
    ImGui.SameLine()
    ImGui.SetNextItemWidth(w)
    ImGui.ColorPicker3("##MyColor##6", color, bit32.bor(CE.PickerHueWheel, CE.NoSidePreview, CE.NoInputs, CE.NoAlpha))
    ImGui.PopID()

    ImGui.Spacing()
    ImGui.Text("HSV encoded colors")
    ImGui.SameLine(); HelpMarker("By default, colors are given to ColorEdit and ColorPicker in RGB, but ImGuiColorEditFlags_InputHSV allows you to store colors as HSV and pass them to ColorEdit and ColorPicker as HSV.")
    ImGui.Text("Color widget with InputHSV:")
    ImGui.ColorEdit4("HSV shown as RGB##1", s.hsv, bit32.bor(CE.DisplayRGB, CE.InputHSV, CE.Float))
    ImGui.ColorEdit4("HSV shown as HSV##1", s.hsv, bit32.bor(CE.DisplayHSV, CE.InputHSV, CE.Float))
    ImGui.DragFloat4("Raw HSV values", s.hsv, 0.01, 0.0, 1.0)
    ImGui.TreePop()
end

S.combo = { flags = 0, sel = 0, filter = nil, c2 = 0, c3 = -1, c4 = 0 }
function DemoWindowWidgetsComboBoxes()
    if not ImGui.TreeNode("Combo") then return end
    local s = S.combo
    local CF = ImGuiComboFlags
    local p
    _, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_PopupAlignLeft", s.flags, CF.PopupAlignLeft)
    ImGui.SameLine(); HelpMarker("Only makes a difference if the popup is larger than the combo")
    p, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_NoArrowButton", s.flags, CF.NoArrowButton)
    if p then s.flags = bit32.band(s.flags, bit32.bnot(CF.NoPreview)) end
    p, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_NoPreview", s.flags, CF.NoPreview)
    if p then s.flags = bit32.band(s.flags, bit32.bnot(bit32.bor(CF.NoArrowButton, CF.WidthFitPreview))) end
    p, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_WidthFitPreview", s.flags, CF.WidthFitPreview)
    if p then s.flags = bit32.band(s.flags, bit32.bnot(CF.NoPreview)) end
    for _, h in ipairs({ "HeightSmall", "HeightRegular", "HeightLargest" }) do
        p, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_" .. h, s.flags, CF[h])
        if p then s.flags = bit32.band(s.flags, bit32.bnot(bit32.band(CF.HeightMask_, bit32.bnot(CF[h])))) end
    end

    local items = { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIII", "JJJJ", "KKKK", "LLLLLLL", "MMMM", "OOOOOOO" }
    local combo_preview_value = items[s.sel + 1]
    if ImGui.BeginCombo("combo 1", combo_preview_value, s.flags) then
        for n = 0, #items - 1 do
            local is_selected = (s.sel == n)
            if ImGui.Selectable(items[n + 1], is_selected) then s.sel = n end
            if is_selected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndCombo()
    end

    if ImGui.BeginCombo("combo 2 (w/ filter)", combo_preview_value, s.flags) then
        s.filter = s.filter or ImGuiTextFilter()
        if ImGui.IsWindowAppearing() then
            ImGui.SetKeyboardFocusHere()
            s.filter:Clear()
        end
        ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.F))
        ImGui.SetNextItemWidth(-FLT_MIN)
        s.filter:DrawWithHint("##Filter", "Filter (incl -excl)")
        for n = 0, #items - 1 do
            local is_selected = (s.sel == n)
            if s.filter:PassFilter(items[n + 1]) then
                if ImGui.Selectable(items[n + 1], is_selected) then s.sel = n end
            end
        end
        ImGui.EndCombo()
    end

    ImGui.Spacing()
    ImGui.SeparatorText("One-liner variants")
    HelpMarker("The Combo() function is not greatly useful apart from cases were you want to embed all options in a single strings.\nFlags above don't apply to this section.")
    s.c2 = ImGui.Combo("combo 3 (one-liner)", s.c2, "aaaa\0bbbb\0cccc\0dddd\0eeee\0\0")
    s.c3 = ImGui.Combo("combo 4 (array)", s.c3, items, #items)
    s.c4 = ImGui.Combo("combo 5 (function)", s.c4, function(data, n) return data[n + 1] end, items, #items)
    ImGui.TreePop()
end

S.dt = { s8 = 127, u8 = 255, s16 = 32767, u16 = 65535, s32 = -1, u32 = 0xFFFFFFFF, s64 = -1, u64 = 0, f32 = 0.123, f64 = 90000.01234567890123456789,
    drag_clamp = false, inputs_step = true, flags = 0 }
function DemoWindowWidgetsDataTypes()
    if not ImGui.TreeNode("Data Types") then return end
    local s = S.dt
    local DT = ImGuiDataType
    -- ponytail: Luau numbers are doubles, so S64/U64 are shown with S32/Double here (no 64-bit integer type)
    local s32_min, s32_max = math.floor(-2147483648 / 2), math.floor(2147483647 / 2)
    local u32_max = math.floor(4294967295 / 2)
    local drag_speed = 0.2
    ImGui.SeparatorText("Drags")
    _, s.drag_clamp = ImGui.Checkbox("Clamp integers to 0..50", s.drag_clamp)
    ImGui.SameLine(); HelpMarker("As with every widget in dear imgui, we never modify values unless there is a user interaction.\nYou can override the clamping limits by using Ctrl+Click to input a value.")
    local lo, hi = s.drag_clamp and 0 or nil, s.drag_clamp and 50 or nil
    s.s8  = ImGui.DragScalar("drag s8",      DT.S8,  s.s8,  drag_speed, lo, hi)
    s.u8  = ImGui.DragScalar("drag u8",      DT.U8,  s.u8,  drag_speed, lo, hi, "%u ms")
    s.s16 = ImGui.DragScalar("drag s16",     DT.S16, s.s16, drag_speed, lo, hi)
    s.u16 = ImGui.DragScalar("drag u16",     DT.U16, s.u16, drag_speed, lo, hi, "%u ms")
    s.s32 = ImGui.DragScalar("drag s32",     DT.S32, s.s32, drag_speed, lo, hi)
    s.s32 = ImGui.DragScalar("drag s32 hex", DT.S32, s.s32, drag_speed, lo, hi, "0x%08X")
    s.u32 = ImGui.DragScalar("drag u32",     DT.U32, s.u32, drag_speed, lo, hi, "%u ms")
    s.f32 = ImGui.DragScalar("drag float",     DT.Float,  s.f32, 0.005, 0.0, 1.0, "%f")
    s.f32 = ImGui.DragScalar("drag float log", DT.Float,  s.f32, 0.005, 0.0, 1.0, "%f", ImGuiSliderFlags.Logarithmic)
    s.f64 = ImGui.DragScalar("drag double",    DT.Double, s.f64, 0.0005, 0.0, nil, "%.10f grams")
    s.f64 = ImGui.DragScalar("drag double log",DT.Double, s.f64, 0.0005, 0.0, 1.0, "0 < %.10f < 1", ImGuiSliderFlags.Logarithmic)

    ImGui.SeparatorText("Sliders")
    s.s8  = ImGui.SliderScalar("slider s8 full",  DT.S8,  s.s8,  -128, 127, "%d")
    s.u8  = ImGui.SliderScalar("slider u8 full",  DT.U8,  s.u8,  0, 255, "%u")
    s.s16 = ImGui.SliderScalar("slider s16 full", DT.S16, s.s16, -32768, 32767, "%d")
    s.u16 = ImGui.SliderScalar("slider u16 full", DT.U16, s.u16, 0, 65535, "%u")
    s.s32 = ImGui.SliderScalar("slider s32 low",  DT.S32, s.s32, 0, 50, "%d")
    s.s32 = ImGui.SliderScalar("slider s32 high", DT.S32, s.s32, s32_max - 100, s32_max, "%d")
    s.s32 = ImGui.SliderScalar("slider s32 full", DT.S32, s.s32, s32_min, s32_max, "%d")
    s.s32 = ImGui.SliderScalar("slider s32 hex",  DT.S32, s.s32, 0, 50, "0x%04X")
    s.u32 = ImGui.SliderScalar("slider u32 low",  DT.U32, s.u32, 0, 50, "%u")
    s.u32 = ImGui.SliderScalar("slider u32 high", DT.U32, s.u32, u32_max - 100, u32_max, "%u")
    s.u32 = ImGui.SliderScalar("slider u32 full", DT.U32, s.u32, 0, u32_max, "%u")
    s.f32 = ImGui.SliderScalar("slider float low",      DT.Float, s.f32, 0.0, 1.0)
    s.f32 = ImGui.SliderScalar("slider float low log",  DT.Float, s.f32, 0.0, 1.0, "%.10f", ImGuiSliderFlags.Logarithmic)
    s.f32 = ImGui.SliderScalar("slider float high",     DT.Float, s.f32, -10000000000.0, 10000000000.0, "%e")
    s.f64 = ImGui.SliderScalar("slider double low",     DT.Double, s.f64, 0.0, 1.0, "%.10f grams")
    s.f64 = ImGui.SliderScalar("slider double low log", DT.Double, s.f64, 0.0, 1.0, "%.10f", ImGuiSliderFlags.Logarithmic)
    s.f64 = ImGui.SliderScalar("slider double high",    DT.Double, s.f64, -1000000000000000.0, 1000000000000000.0, "%e grams")

    ImGui.SeparatorText("Sliders (reverse)")
    s.s8  = ImGui.SliderScalar("slider s8 reverse",  DT.S8,  s.s8,  127, -128, "%d")
    s.u8  = ImGui.SliderScalar("slider u8 reverse",  DT.U8,  s.u8,  255, 0, "%u")
    s.s32 = ImGui.SliderScalar("slider s32 reverse", DT.S32, s.s32, 50, 0, "%d")
    s.u32 = ImGui.SliderScalar("slider u32 reverse", DT.U32, s.u32, 50, 0, "%u")

    ImGui.SeparatorText("Inputs")
    _, s.inputs_step = ImGui.Checkbox("Show step buttons", s.inputs_step)
    _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ReadOnly", s.flags, ImGuiInputTextFlags.ReadOnly)
    if ImGuiInputTextFlags.ParseEmptyRefVal then _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ParseEmptyRefVal", s.flags, ImGuiInputTextFlags.ParseEmptyRefVal) end
    if ImGuiInputTextFlags.DisplayEmptyRefVal then _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_DisplayEmptyRefVal", s.flags, ImGuiInputTextFlags.DisplayEmptyRefVal) end
    local one = s.inputs_step and 1 or nil
    s.s8  = ImGui.InputScalar("input s8",      DT.S8,  s.s8,  one, nil, "%d", s.flags)
    s.u8  = ImGui.InputScalar("input u8",      DT.U8,  s.u8,  one, nil, "%u", s.flags)
    s.s16 = ImGui.InputScalar("input s16",     DT.S16, s.s16, one, nil, "%d", s.flags)
    s.u16 = ImGui.InputScalar("input u16",     DT.U16, s.u16, one, nil, "%u", s.flags)
    s.s32 = ImGui.InputScalar("input s32",     DT.S32, s.s32, one, nil, "%d", s.flags)
    s.s32 = ImGui.InputScalar("input s32 hex", DT.S32, s.s32, one, nil, "%04X", s.flags)
    s.u32 = ImGui.InputScalar("input u32",     DT.U32, s.u32, one, nil, "%u", s.flags)
    s.u32 = ImGui.InputScalar("input u32 hex", DT.U32, s.u32, one, nil, "%08X", s.flags)
    s.f32 = ImGui.InputScalar("input float",   DT.Float,  s.f32, s.inputs_step and 1.0 or nil, nil, nil, s.flags)
    s.f64 = ImGui.InputScalar("input double",  DT.Double, s.f64, s.inputs_step and 1.0 or nil, nil, nil, s.flags)
    ImGui.TreePop()
end

function DemoWindowWidgetsDisableBlocks(demo_data)
    if not ImGui.TreeNode("Disable Blocks") then return end
    _, demo_data.DisableSections = ImGui.Checkbox("Disable entire section above", demo_data.DisableSections)
    ImGui.SameLine(); HelpMarker("Demonstrate using BeginDisabled()/EndDisabled() across other sections.")
    ImGui.TreePop()
end

S.dnd = { col1 = { 1.0, 0.0, 0.2 }, col2 = { 0.4, 0.7, 0.0, 0.5 }, mode = 0,
    names = { "Bobby", "Beatrice", "Betty", "Brianna", "Barry", "Bernard", "Bibi", "Blaine", "Bryn" },
    item_names = { "Item One", "Item Two", "Item Three", "Item Four", "Item Five" }, col4 = ImVec4(1.0, 0.0, 0.2, 1.0) }
function DemoWindowWidgetsDragAndDrop()
    if not ImGui.TreeNode("Drag and Drop") then return end
    local s = S.dnd
    if ImGui.TreeNode("Drag and drop in standard widgets") then
        HelpMarker("You can drag from the color squares.")
        ImGui.ColorEdit3("color 1", s.col1)
        ImGui.ColorEdit4("color 2", s.col2)
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Drag and drop to copy/swap items") then
        local Mode_Copy, Mode_Move, Mode_Swap = 0, 1, 2
        if ImGui.RadioButtonEx("Copy", s.mode == Mode_Copy) then s.mode = Mode_Copy end ImGui.SameLine()
        if ImGui.RadioButtonEx("Move", s.mode == Mode_Move) then s.mode = Mode_Move end ImGui.SameLine()
        if ImGui.RadioButtonEx("Swap", s.mode == Mode_Swap) then s.mode = Mode_Swap end
        local names = s.names
        for n = 0, #names - 1 do
            ImGui.PushID(n)
            if n % 3 ~= 0 then ImGui.SameLine() end
            ImGui.Button(names[n + 1], ImVec2(60, 60))
            if ImGui.BeginDragDropSource(ImGuiDragDropFlags.None) then
                ImGui.SetDragDropPayload("DND_DEMO_CELL", n, 4)
                if s.mode == Mode_Copy then ImGui.Text("Copy %s", names[n + 1]) end
                if s.mode == Mode_Move then ImGui.Text("Move %s", names[n + 1]) end
                if s.mode == Mode_Swap then ImGui.Text("Swap %s", names[n + 1]) end
                ImGui.EndDragDropSource()
            end
            if ImGui.BeginDragDropTarget() then
                local payload = ImGui.AcceptDragDropPayload("DND_DEMO_CELL")
                if payload then
                    local payload_n = payload.Data
                    if s.mode == Mode_Copy then names[n + 1] = names[payload_n + 1] end
                    if s.mode == Mode_Move then names[n + 1] = names[payload_n + 1]; names[payload_n + 1] = "" end
                    if s.mode == Mode_Swap then names[n + 1], names[payload_n + 1] = names[payload_n + 1], names[n + 1] end
                end
                ImGui.EndDragDropTarget()
            end
            ImGui.PopID()
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Drag to reorder items (simple)") then
        ImGui.PushItemFlag(ImGuiItemFlags.AllowDuplicateId, true)
        HelpMarker("We don't use the drag and drop api at all here! Instead we query when the item is held but not hovered, and order items accordingly.")
        local item_names = s.item_names
        for n = 1, #item_names do
            local item = item_names[n]
            ImGui.Selectable(item)
            if ImGui.IsItemActive() and not ImGui.IsItemHovered() then
                local n_next = n + ((ImGui.GetMouseDragDelta(0).y < 0.0) and -1 or 1)
                if n_next >= 1 and n_next <= #item_names then
                    item_names[n] = item_names[n_next]
                    item_names[n_next] = item
                    ImGui.ResetMouseDragDelta()
                end
            end
        end
        ImGui.PopItemFlag()
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Tooltip at target location") then
        for n = 0, 1 do
            ImGui.Button((n == 1) and "drop here##1" or "drop here##0")
            if ImGui.BeginDragDropTarget() then
                local drop_target_flags = bit32.bor(ImGuiDragDropFlags.AcceptBeforeDelivery, ImGuiDragDropFlags.AcceptNoPreviewTooltip)
                if ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_4F, drop_target_flags) then
                    ImGui.SetMouseCursor(ImGuiMouseCursor.NotAllowed)
                    ImGui.SetTooltip("Cannot drop here!")
                end
                ImGui.EndDragDropTarget()
            end
            if n == 0 then ImGui.ColorButton("drag me", s.col4) end
        end
        ImGui.TreePop()
    end
    ImGui.TreePop()
end

S.ds = { flags = 0, drag_f = 0.5, drag_f4 = { 0, 0, 0, 0 }, drag_i = 50, slider_f = 0.5, slider_f4 = { 0, 0, 0, 0 }, slider_i = 50 }
function DemoWindowWidgetsDragsAndSliders()
    if not ImGui.TreeNode("Drag/Slider Flags") then return end
    local s = S.ds
    local SF = ImGuiSliderFlags
    local function F(name, help)
        if SF[name] == nil then return end
        _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_" .. name, s.flags, SF[name])
        if help then ImGui.SameLine(); HelpMarker(help) end
    end
    F("AlwaysClamp")
    F("ClampOnInput", "Clamp value to min/max bounds when input manually with Ctrl+Click. By default Ctrl+Click allows going out of bounds.")
    F("ClampZeroRange", "Clamp even if min==max==0.0f. Otherwise DragXXX functions don't clamp.")
    F("Logarithmic", "Enable logarithmic editing (more precision for small values).")
    F("NoRoundToFormat", "Disable rounding underlying value to match precision of the format string (e.g. %.3f values are rounded to those 3 digits).")
    F("NoInput", "Disable Ctrl+Click or Enter key allowing to input text directly into the widget.")
    F("NoSpeedTweaks", "Disable keyboard modifiers altering tweak speed. Useful if you want to alter tweak speed yourself based on your own logic.")
    F("WrapAround", "Enable wrapping around from max to min and from min to max (only supported by DragXXX() functions)")
    F("ColorMarkers")
    local flags = s.flags

    ImGui.Text("Underlying float value: %f", s.drag_f)
    s.drag_f = ImGui.DragFloat("DragFloat (0 -> 1)", s.drag_f, 0.005, 0.0, 1.0, "%.3f", flags)
    s.drag_f = ImGui.DragFloat("DragFloat (0 -> +inf)", s.drag_f, 0.005, 0.0, FLT_MAX, "%.3f", flags)
    s.drag_f = ImGui.DragFloat("DragFloat (-inf -> 1)", s.drag_f, 0.005, -FLT_MAX, 1.0, "%.3f", flags)
    s.drag_f = ImGui.DragFloat("DragFloat (-inf -> +inf)", s.drag_f, 0.005, -FLT_MAX, FLT_MAX, "%.3f", flags)
    s.drag_i = ImGui.DragInt("DragInt (0 -> 100)", s.drag_i, 0.5, 0, 100, "%d", flags)
    ImGui.DragFloat4("DragFloat4 (0 -> 1)", s.drag_f4, 0.005, 0.0, 1.0, "%.3f", flags)

    local flags_for_sliders = bit32.band(flags, bit32.bnot(SF.WrapAround))
    ImGui.Text("Underlying float value: %f", s.slider_f)
    s.slider_f = ImGui.SliderFloat("SliderFloat (0 -> 1)", s.slider_f, 0.0, 1.0, "%.3f", flags_for_sliders)
    s.slider_i = ImGui.SliderInt("SliderInt (0 -> 100)", s.slider_i, 0, 100, "%d", flags_for_sliders)
    ImGui.SliderFloat4("SliderFloat4 (0 -> 1)", s.slider_f4, 0.0, 1.0, "%.3f", flags_for_sliders)
    ImGui.TreePop()
end

function DemoWindowWidgetsFonts()
    if not ImGui.TreeNode("Fonts") then return end
    if ImGui.ShowFontAtlas then ImGui.ShowFontAtlas(ImGui.GetIO().Fonts) else DemoNotPorted("ShowFontAtlas") end
    ImGui.TreePop()
end

S.img = { viewer = nil, pressed_count = 0 }
function DemoWindowWidgetsImages()
    if not ImGui.TreeNode("Images") then return end
    local s = S.img
    local io = ImGui.GetIO()
    ImGui.TextWrapped("Below we are displaying the font texture (which is the only texture we have access to in this demo). Use the 'ImTextureID' type as storage to pass pointers or identifier to your own texture data. Hover the texture for a zoomed view!")
    local atlas = io.Fonts
    local my_tex_id = atlas.TexRef
    local my_tex_w = atlas.TexData and atlas.TexData.Width or 0
    local my_tex_h = atlas.TexData and atlas.TexData.Height or 0
    ImGui.Text("%.0fx%.0f", my_tex_w, my_tex_h)

    ImGui.SeparatorText("Image()/ImageWithBg() function")
    ImGui.PushStyleVar(ImGuiStyleVar.ImageBorderSize, math.max(1.0, ImGui.GetStyle().ImageBorderSize))
    ImGui.ImageWithBg(my_tex_id, ImVec2(my_tex_w, my_tex_h), ImVec2(0.0, 0.0), ImVec2(1.0, 1.0), ImVec4(0.0, 0.0, 0.0, 1.0))
    ImGui.PopStyleVar()

    ImGui.SeparatorText("Interactive Image Viewer")
    s.viewer = s.viewer or ExampleImageViewerData()
    local canvas_size = ImVec2(ImGui.GetContentRegionAvail().x, my_tex_h * 2.0)
    ExampleImageViewer_DrawOptions(s.viewer)
    ExampleImageViewer_DrawCanvas(s.viewer, canvas_size, my_tex_id, my_tex_w, my_tex_h)

    ImGui.SeparatorText("Textured Buttons")
    ImGui.TextWrapped("And now some textured buttons..")
    for i = 0, 7 do
        ImGui.PushID(i)
        if i > 0 then ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(i - 1.0, i - 1.0)) end
        local size = ImVec2(32.0, 32.0)
        local uv0 = ImVec2(0.0, 0.0)
        local uv1 = ImVec2(32.0 / my_tex_w, 32.0 / my_tex_h)
        if ImGui.ImageButton("", my_tex_id, size, uv0, uv1, ImVec4(0.0, 0.0, 0.0, 1.0), ImVec4(1.0, 1.0, 1.0, 1.0)) then
            s.pressed_count = s.pressed_count + 1
        end
        if i > 0 then ImGui.PopStyleVar() end
        ImGui.PopID()
        ImGui.SameLine()
    end
    ImGui.NewLine()
    ImGui.Text("Pressed %d times.", s.pressed_count)
    ImGui.TreePop()
end

S.lb = { sel = 0, highlight = false }
function DemoWindowWidgetsListBoxes()
    if not ImGui.TreeNode("List Boxes") then return end
    local s = S.lb
    local items = { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIII", "JJJJ", "KKKK", "LLLLLLL", "MMMM", "OOOOOOO" }
    local item_highlighted_idx = -1
    _, s.highlight = ImGui.Checkbox("Highlight hovered item in second listbox", s.highlight)
    if ImGui.BeginListBox("listbox 1") then
        for n = 0, #items - 1 do
            local is_selected = (s.sel == n)
            if ImGui.Selectable(items[n + 1], is_selected) then s.sel = n end
            if s.highlight and ImGui.IsItemHovered() then item_highlighted_idx = n end
            if is_selected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndListBox()
    end
    ImGui.SameLine(); HelpMarker("Here we are sharing selection state between both boxes.")
    ImGui.Text("Full-width:")
    if ImGui.BeginListBox("##listbox 2", ImVec2(-FLT_MIN, 5 * ImGui.GetTextLineHeightWithSpacing())) then
        for n = 0, #items - 1 do
            local is_selected = (s.sel == n)
            local flags = (item_highlighted_idx == n) and ImGuiSelectableFlags.Highlight or 0
            if ImGui.Selectable(items[n + 1], is_selected, flags) then s.sel = n end
            if is_selected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndListBox()
    end
    ImGui.TreePop()
end

S.le = { str = Buf("", 32), i = 0, f = 0.0 }
function DemoWindowWidgetsLiveEdit(demo_data)
    if not ImGui.TreeNode("Live Edit Flags") then return end
    local s = S.le
    ImGui.TextWrapped("Select whether to apply keyboard edits to backing variables _while_ typing.")
    _, demo_data.LiveEditOverride = ImGui.Checkbox("Override Live Edit Flags in Demo Window", demo_data.LiveEditOverride)
    if not demo_data.LiveEditOverride then demo_data.LiveEditFlags = ImGui.GetItemFlags() end
    ImGui.BeginDisabled(demo_data.LiveEditOverride == false)
    ImGui.Indent()
    _, demo_data.LiveEditFlags = ImGui.CheckboxFlags("ImGuiItemFlags_LiveEditOnInputText", demo_data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputText)
    _, demo_data.LiveEditFlags = ImGui.CheckboxFlags("ImGuiItemFlags_LiveEditOnInputScalar", demo_data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputScalar)
    ImGui.Unindent()
    ImGui.EndDisabled()
    ImGui.Text("Try typing '123' and seeing effect on backing value:")
    ImGui.InputText("str", s.str, 32)
    ImGui.Text("Backing value: \"%s\"", BufStr(s.str))
    s.i = ImGui.InputInt("int", s.i, 0, 0)
    ImGui.Text("Backing value: %d", s.i)
    s.f = ImGui.SliderFloat("float", s.f, 0.0, 100.0)
    ImGui.Text("Backing value: %f", s.f)
    ImGui.TreePop()
end

S.mv = { use_liveedit = false, items = { 12.0, 0.0, 0.0 } }
function DemoWindowWidgetsMixedValues()
    if not ImGui.TreeNode("Mixed Values") then return end
    local s = S.mv
    local items = s.items
    HelpMarker("Using ImGuiItemFlags_MixedValue.")
    _, s.use_liveedit = ImGui.Checkbox("ImGuiItemFlags_LiveEditOnInput", s.use_liveedit)
    ImGui.SeparatorText("Scalar/Text Widgets")
    local is_mixed = items[1] ~= items[2] or items[1] ~= items[3]
    ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInput, s.use_liveedit)
    ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, is_mixed)
    local edited, e = false, false
    items[1], e = ImGui.DragFloat("DragFloat", items[1]); edited = edited or e
    items[1], e = ImGui.SliderFloat("SliderFloat", items[1], 0.0, 100.0); edited = edited or e
    items[1], e = ImGui.InputFloat("InputFloat", items[1], 1.0); edited = edited or e
    if edited then items[2] = items[1]; items[3] = items[1] end
    ImGui.PopItemFlag()
    ImGui.Text("Underlying data:")
    items[1] = ImGui.InputFloat("item 0 (ref)", items[1])
    items[2] = ImGui.InputFloat("item 1", items[2])
    items[3] = ImGui.InputFloat("item 2", items[3])
    ImGui.PopItemFlag()

    ImGui.SeparatorText("Others Widgets")
    ImGui.Text("(note: edits are not applied in this demo)")
    ImGui.Checkbox("Checkbox On", true)
    ImGui.Checkbox("Checkbox Off", false)
    ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, true)
    ImGui.Checkbox("Checkbox Mixed", false)
    ImGui.RadioButtonEx("RadioButton Mixed", true)
    ImGui.SameLine()
    ImGui.RadioButtonEx("RadioButton Mixed##2", true)
    ImGui.Combo("Combo", 0, "One\0Two\0Three\0")
    ImGui.ColorEdit4("ColorEdit4", ImVec4(0.5, 0.5, 0.5, 0.5))
    ImGui.PopItemFlag()
    ImGui.TreePop()
end

S.mc = { vec4f = { 0.10, 0.20, 0.30, 0.44 }, vec4i = { 1, 5, 100, 255 }, flags = 0, b = 10, e = 90, bi = 100, ei = 1000 }
function DemoWindowWidgetsMultiComponents()
    if not ImGui.TreeNode("Multi-component Widgets") then return end
    local s = S.mc
    local f, i = s.vec4f, s.vec4i
    if ImGuiSliderFlags.ColorMarkers then _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_ColorMarkers", s.flags, ImGuiSliderFlags.ColorMarkers) end
    local flags = s.flags
    for _, n in ipairs({ 2, 3, 4 }) do
        ImGui.SeparatorText(n .. "-wide")
        ImGui["InputFloat" .. n]("input float" .. n, f)
        ImGui["InputInt" .. n]("input int" .. n, i)
        ImGui["DragFloat" .. n]("drag float" .. n, f, 0.01, 0.0, 1.0, nil, flags)
        ImGui["DragInt" .. n]("drag int" .. n, i, 1, 0, 255, nil, flags)
        ImGui["SliderFloat" .. n]("slider float" .. n, f, 0.0, 1.0, nil, flags)
        ImGui["SliderInt" .. n]("slider int" .. n, i, 0, 255, nil, flags)
    end
    ImGui.SeparatorText("Ranges")
    s.b, s.e = ImGui.DragFloatRange2("range float", s.b, s.e, 0.25, 0.0, 100.0, "Min: %.1f %%", "Max: %.1f %%", ImGuiSliderFlags.AlwaysClamp)
    s.bi, s.ei = ImGui.DragIntRange2("range int", s.bi, s.ei, 5, 0, 1000, "Min: %d units", "Max: %d units")
    s.bi, s.ei = ImGui.DragIntRange2("range int (no bounds)", s.bi, s.ei, 5, 0, 0, "Min: %d units", "Max: %d units")
    ImGui.TreePop()
end

S.plot = { animate = true, arr = { 0.6, 0.1, 1.0, 0.5, 0.92, 0.1, 0.2 }, values = {}, values_offset = 0, refresh_time = 0.0, phase = 0.0,
    func_type = 0, display_count = 70 }
for n = 1, 90 do S.plot.values[n] = 0.0 end
function DemoWindowWidgetsPlotting()
    if not ImGui.TreeNode("Plotting") then return end
    local s = S.plot
    ImGui.Text("Need better plotting and graphing? Consider using ImPlot:")
    ImGui.TextLinkOpenURL("https://github.com/epezent/implot")
    ImGui.Separator()
    _, s.animate = ImGui.Checkbox("Animate", s.animate)
    ImGui.PlotLines("Frame Times", s.arr, nil, #s.arr)
    ImGui.PlotHistogram("Histogram", s.arr, nil, #s.arr, 0, nil, 0.0, 1.0, ImVec2(0, 80.0))

    local values = s.values
    if not s.animate or s.refresh_time == 0.0 then s.refresh_time = ImGui.GetTime() end
    while s.refresh_time < ImGui.GetTime() do
        values[s.values_offset + 1] = math.cos(s.phase)
        s.values_offset = (s.values_offset + 1) % #values
        s.phase = s.phase + 0.10 * s.values_offset
        s.refresh_time = s.refresh_time + 1.0 / 60.0
    end
    local average = 0.0
    for n = 1, #values do average = average + values[n] end
    average = average / #values
    ImGui.PlotLines("Lines", values, nil, #values, s.values_offset, string.format("avg %f", average), -1.0, 1.0, ImVec2(0, 80.0))

    -- Getters receive a 1-based index in this port
    local function Sin(_, i) return math.sin((i - 1) * 0.1) end
    local function Saw(_, i) return ((i - 1) % 2 == 1) and 1.0 or -1.0 end
    ImGui.SeparatorText("Functions")
    ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
    s.func_type = ImGui.Combo("func", s.func_type, "Sin\0Saw\0")
    ImGui.SameLine()
    s.display_count = ImGui.SliderInt("Sample count", s.display_count, 1, 400)
    local func = (s.func_type == 0) and Sin or Saw
    ImGui.PlotLines("Lines##2", func, nil, s.display_count, 0, nil, -1.0, 1.0, ImVec2(0, 80))
    ImGui.PlotHistogram("Histogram##2", func, nil, s.display_count, 0, nil, -1.0, 1.0, ImVec2(0, 80))
    ImGui.TreePop()
end

S.pb = { accum = 0.0, dir = 1.0 }
function DemoWindowWidgetsProgressBars()
    if not ImGui.TreeNode("Progress Bars") then return end
    local s = S.pb
    s.accum = s.accum + s.dir * 0.4 * ImGui.GetIO().DeltaTime
    if s.accum >= 1.1 then s.accum = 1.1; s.dir = -s.dir end
    if s.accum <= -0.1 then s.accum = -0.1; s.dir = -s.dir end
    local progress = DemoClamp(s.accum, 0.0, 1.0)
    ImGui.ProgressBar(progress, ImVec2(0.0, 0.0))
    ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
    ImGui.Text("Progress Bar")
    ImGui.ProgressBar(progress, ImVec2(0.0, 0.0), string.format("%d/%d", math.floor(progress * 1753), 1753))
    ImGui.ProgressBar(-1.0 * ImGui.GetTime(), ImVec2(0.0, 0.0), "Searching..")
    ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
    ImGui.Text("Indeterminate")
    ImGui.TreePop()
end

-- Selectable(label, bool* p_selected) overload: toggles on press
local function SelectableP(label, sel, flags, size)
    local pressed = ImGui.Selectable(label, sel, flags, size)
    if pressed then sel = not sel end
    return pressed, sel
end

local function B(v) return v and 1 or 0 end

S.qs = { item_type = 4, item_disabled = false, item_mixedvalue = false, liveedit_override = false, liveedit_flags = 0,
    b = false, col4f = { 1.0, 0.5, 0.0, 1.0 }, str = Buf("", 16), combo = 1, listbox = 1, unused = Buf("", 1),
    embed = false, test_window = false }
function DemoWindowWidgetsQueryingStatuses()
    local s = S.qs
    if ImGui.TreeNode("Querying Item Status (Edited/Active/Hovered etc.)") then
        local item_names = { "Text", "Button", "Button (w/ repeat)", "Checkbox", "SliderFloat", "InputText", "InputTextMultiline", "InputFloat",
            "InputFloat3", "ColorEdit4", "Selectable", "MenuItem", "TreeNode", "TreeNode (w/ double-click)", "Combo", "ListBox" }
        s.item_type = ImGui.Combo("Item Type", s.item_type, item_names, #item_names, #item_names)
        ImGui.SameLine()
        HelpMarker("Testing how various types of items are interacting with the IsItemXXX functions. Note that the bool return value of most ImGui function is generally equivalent to calling ImGui::IsItemHovered().")
        _, s.item_disabled = ImGui.Checkbox("Item Disabled", s.item_disabled)
        _, s.item_mixedvalue = ImGui.Checkbox("Item MixedValue", s.item_mixedvalue)
        _, s.liveedit_override = ImGui.Checkbox("Override LiveEdit:", s.liveedit_override)
        ImGui.SameLine()
        if not s.liveedit_override then s.liveedit_flags = ImGui.GetItemFlags() end
        ImGui.BeginDisabled(s.liveedit_override == false)
        _, s.liveedit_flags = ImGui.CheckboxFlags("_LiveEditOnInput", s.liveedit_flags, ImGuiItemFlags.LiveEditOnInput)
        ImGui.SameLine()
        _, s.liveedit_flags = ImGui.CheckboxFlags("_LiveEditOnInputText", s.liveedit_flags, ImGuiItemFlags.LiveEditOnInputText)
        ImGui.SameLine()
        _, s.liveedit_flags = ImGui.CheckboxFlags("_LiveEditOnInputScalar", s.liveedit_flags, ImGuiItemFlags.LiveEditOnInputScalar)
        ImGui.EndDisabled()
        if s.liveedit_override then
            ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputText, bit32.band(s.liveedit_flags, ImGuiItemFlags.LiveEditOnInputText) ~= 0)
            ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputScalar, bit32.band(s.liveedit_flags, ImGuiItemFlags.LiveEditOnInputScalar) ~= 0)
        end

        local ret = false
        local t = s.item_type
        if s.item_disabled then ImGui.BeginDisabled(true) end
        if s.item_mixedvalue then ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, true) end
        if t == 0 then ImGui.Text("ITEM: Text") end
        if t == 1 then ret = ImGui.Button("ITEM: Button") end
        if t == 2 then ImGui.PushItemFlag(ImGuiItemFlags.ButtonRepeat, true); ret = ImGui.Button("ITEM: Button"); ImGui.PopItemFlag() end
        if t == 3 then ret, s.b = ImGui.Checkbox("ITEM: Checkbox", s.b) end
        if t == 4 then s.col4f[1], ret = ImGui.SliderFloat("ITEM: SliderFloat", s.col4f[1], 0.0, 1.0) end
        if t == 5 then ret = ImGui.InputText("ITEM: InputText", s.str, 16) end
        if t == 6 then ret = ImGui.InputTextMultiline("ITEM: InputTextMultiline", s.str, 16) end
        if t == 7 then s.col4f[1], ret = ImGui.InputFloat("ITEM: InputFloat", s.col4f[1], 1.0) end
        if t == 8 then ret = ImGui.InputFloat3("ITEM: InputFloat3", s.col4f) end
        if t == 9 then ret = ImGui.ColorEdit4("ITEM: ColorEdit4", s.col4f) end
        if t == 10 then ret = ImGui.Selectable("ITEM: Selectable") end
        if t == 11 then ret = ImGui.MenuItem("ITEM: MenuItem") end
        if t == 12 then ret = ImGui.TreeNode("ITEM: TreeNode"); if ret then ImGui.TreePop() end end
        if t == 13 then ret = ImGui.TreeNodeEx("ITEM: TreeNode w/ ImGuiTreeNodeFlags_OpenOnDoubleClick", bit32.bor(ImGuiTreeNodeFlags.OpenOnDoubleClick, ImGuiTreeNodeFlags.NoTreePushOnOpen)) end
        if t == 14 then s.combo, ret = ImGui.Combo("ITEM: Combo", s.combo, { "Apple", "Banana", "Cherry", "Kiwi" }) end
        if t == 15 then s.listbox, ret = ImGui.ListBox("ITEM: ListBox", s.listbox, { "Apple", "Banana", "Cherry", "Kiwi" }, 4, 4) end

        local HF = ImGuiHoveredFlags
        local hovered_delay_none = ImGui.IsItemHovered()
        local hovered_delay_stationary = ImGui.IsItemHovered(HF.Stationary)
        local hovered_delay_short = ImGui.IsItemHovered(HF.DelayShort)
        local hovered_delay_normal = ImGui.IsItemHovered(HF.DelayNormal)
        local hovered_delay_tooltip = ImGui.IsItemHovered(HF.ForTooltip)
        local rmin, rmax, rsize = ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), ImGui.GetItemRectSize()
        ImGui.BulletText(
            "Return value = %d\nIsItemFocused() = %d\nIsItemHovered() = %d\nIsItemHovered(_AllowWhenBlockedByPopup) = %d\n" ..
            "IsItemHovered(_AllowWhenBlockedByActiveItem) = %d\nIsItemHovered(_AllowWhenOverlappedByItem) = %d\n" ..
            "IsItemHovered(_AllowWhenOverlappedByWindow) = %d\nIsItemHovered(_AllowWhenDisabled) = %d\nIsItemHovered(_RectOnly) = %d\n" ..
            "IsItemActive() = %d\nIsItemEdited() = %d\nIsItemActivated() = %d\nIsItemDeactivated() = %d\nIsItemDeactivatedAfterEdit() = %d\n" ..
            "IsItemVisible() = %d\nIsItemClicked() = %d\nIsItemToggledOpen() = %d\n" ..
            "GetItemRectMin() = (%.1f, %.1f)\nGetItemRectMax() = (%.1f, %.1f)\nGetItemRectSize() = (%.1f, %.1f)",
            B(ret), B(ImGui.IsItemFocused()), B(ImGui.IsItemHovered()), B(ImGui.IsItemHovered(HF.AllowWhenBlockedByPopup)),
            B(ImGui.IsItemHovered(HF.AllowWhenBlockedByActiveItem)), B(ImGui.IsItemHovered(HF.AllowWhenOverlappedByItem)),
            B(ImGui.IsItemHovered(HF.AllowWhenOverlappedByWindow)), B(ImGui.IsItemHovered(HF.AllowWhenDisabled)), B(ImGui.IsItemHovered(HF.RectOnly)),
            B(ImGui.IsItemActive()), B(ImGui.IsItemEdited()), B(ImGui.IsItemActivated()), B(ImGui.IsItemDeactivated()), B(ImGui.IsItemDeactivatedAfterEdit()),
            B(ImGui.IsItemVisible()), B(ImGui.IsItemClicked()), B(ImGui.IsItemToggledOpen()),
            rmin.x, rmin.y, rmax.x, rmax.y, rsize.x, rsize.y)
        ImGui.BulletText(
            "with Hovering Delay or Stationary test:\nIsItemHovered() = %d\nIsItemHovered(_Stationary) = %d\nIsItemHovered(_DelayShort) = %d\nIsItemHovered(_DelayNormal) = %d\nIsItemHovered(_Tooltip) = %d",
            B(hovered_delay_none), B(hovered_delay_stationary), B(hovered_delay_short), B(hovered_delay_normal), B(hovered_delay_tooltip))

        if s.liveedit_override then ImGui.PopItemFlag(); ImGui.PopItemFlag() end
        if s.item_mixedvalue then ImGui.PopItemFlag() end
        if s.item_disabled then ImGui.EndDisabled() end

        ImGui.InputText("unused", s.unused, 1, ImGuiInputTextFlags.ReadOnly)
        ImGui.SameLine()
        HelpMarker("This widget is only here to be able to tab-out of the widgets above and see e.g. Deactivated() status.")
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Querying Window Status (Focused/Hovered etc.)") then
        _, s.embed = ImGui.Checkbox("Embed everything inside a child window for testing _RootWindow flag.", s.embed)
        if s.embed then ImGui.BeginChild("outer_child", ImVec2(0, ImGui.GetFontSize() * 20.0), ImGuiChildFlags.Borders) end
        local FF, HF = ImGuiFocusedFlags, ImGuiHoveredFlags
        local bor = bit32.bor
        ImGui.BulletText(
            "IsWindowFocused() = %d\nIsWindowFocused(_ChildWindows) = %d\nIsWindowFocused(_ChildWindows|_NoPopupHierarchy) = %d\n" ..
            "IsWindowFocused(_ChildWindows|_DockHierarchy) = %d\nIsWindowFocused(_ChildWindows|_RootWindow) = %d\n" ..
            "IsWindowFocused(_ChildWindows|_RootWindow|_NoPopupHierarchy) = %d\nIsWindowFocused(_ChildWindows|_RootWindow|_DockHierarchy) = %d\n" ..
            "IsWindowFocused(_RootWindow) = %d\nIsWindowFocused(_RootWindow|_NoPopupHierarchy) = %d\nIsWindowFocused(_RootWindow|_DockHierarchy) = %d\n" ..
            "IsWindowFocused(_AnyWindow) = %d\n",
            B(ImGui.IsWindowFocused()), B(ImGui.IsWindowFocused(FF.ChildWindows)), B(ImGui.IsWindowFocused(bor(FF.ChildWindows, FF.NoPopupHierarchy))),
            B(ImGui.IsWindowFocused(bor(FF.ChildWindows, FF.DockHierarchy))), B(ImGui.IsWindowFocused(bor(FF.ChildWindows, FF.RootWindow))),
            B(ImGui.IsWindowFocused(bor(FF.ChildWindows, FF.RootWindow, FF.NoPopupHierarchy))), B(ImGui.IsWindowFocused(bor(FF.ChildWindows, FF.RootWindow, FF.DockHierarchy))),
            B(ImGui.IsWindowFocused(FF.RootWindow)), B(ImGui.IsWindowFocused(bor(FF.RootWindow, FF.NoPopupHierarchy))), B(ImGui.IsWindowFocused(bor(FF.RootWindow, FF.DockHierarchy))),
            B(ImGui.IsWindowFocused(FF.AnyWindow)))
        ImGui.BulletText(
            "IsWindowHovered() = %d\nIsWindowHovered(_AllowWhenBlockedByPopup) = %d\nIsWindowHovered(_AllowWhenBlockedByActiveItem) = %d\n" ..
            "IsWindowHovered(_ChildWindows) = %d\nIsWindowHovered(_ChildWindows|_NoPopupHierarchy) = %d\nIsWindowHovered(_ChildWindows|_DockHierarchy) = %d\n" ..
            "IsWindowHovered(_ChildWindows|_RootWindow) = %d\nIsWindowHovered(_ChildWindows|_RootWindow|_NoPopupHierarchy) = %d\n" ..
            "IsWindowHovered(_ChildWindows|_RootWindow|_DockHierarchy) = %d\nIsWindowHovered(_RootWindow) = %d\nIsWindowHovered(_RootWindow|_NoPopupHierarchy) = %d\n" ..
            "IsWindowHovered(_RootWindow|_DockHierarchy) = %d\nIsWindowHovered(_ChildWindows|_AllowWhenBlockedByPopup) = %d\nIsWindowHovered(_AnyWindow) = %d\n" ..
            "IsWindowHovered(_Stationary) = %d\n",
            B(ImGui.IsWindowHovered()), B(ImGui.IsWindowHovered(HF.AllowWhenBlockedByPopup)), B(ImGui.IsWindowHovered(HF.AllowWhenBlockedByActiveItem)),
            B(ImGui.IsWindowHovered(HF.ChildWindows)), B(ImGui.IsWindowHovered(bor(HF.ChildWindows, HF.NoPopupHierarchy))), B(ImGui.IsWindowHovered(bor(HF.ChildWindows, HF.DockHierarchy))),
            B(ImGui.IsWindowHovered(bor(HF.ChildWindows, HF.RootWindow))), B(ImGui.IsWindowHovered(bor(HF.ChildWindows, HF.RootWindow, HF.NoPopupHierarchy))),
            B(ImGui.IsWindowHovered(bor(HF.ChildWindows, HF.RootWindow, HF.DockHierarchy))), B(ImGui.IsWindowHovered(HF.RootWindow)), B(ImGui.IsWindowHovered(bor(HF.RootWindow, HF.NoPopupHierarchy))),
            B(ImGui.IsWindowHovered(bor(HF.RootWindow, HF.DockHierarchy))), B(ImGui.IsWindowHovered(bor(HF.ChildWindows, HF.AllowWhenBlockedByPopup))), B(ImGui.IsWindowHovered(HF.AnyWindow)),
            B(ImGui.IsWindowHovered(HF.Stationary)))
        ImGui.BeginChild("child", ImVec2(0, 50), ImGuiChildFlags.Borders)
        ImGui.Text("This is another child window for testing the _ChildWindows flag.")
        ImGui.EndChild()
        if s.embed then ImGui.EndChild() end

        _, s.test_window = ImGui.Checkbox("Hovered/Active tests after Begin() for title bar testing", s.test_window)
        if s.test_window then
            s.test_window = ImGui.Begin("Title bar Hovered/Active tests", s.test_window)
            if ImGui.BeginPopupContextItem() then
                if ImGui.MenuItem("Close") then s.test_window = false end
                ImGui.EndPopup()
            end
            ImGui.Text("IsItemHovered() after begin = %d (== is title bar hovered)\nIsItemActive() after begin = %d (== is window being clicked/moved)\n",
                B(ImGui.IsItemHovered()), B(ImGui.IsItemActive()))
            ImGui.End()
        end
        ImGui.TreePop()
    end
end

S.sel = { basic = { false, true, false, false }, multi = { false, false, false }, checked = { false, false, false, false, false }, selected_n = 0,
    tables = {}, grid = { { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 0, 1 } },
    align = { true, false, true, false, true, false, true, false, true } }
for i = 1, 10 do S.sel.tables[i] = false end
function DemoWindowWidgetsSelectables()
    if not ImGui.TreeNode("Selectables") then return end
    local s = S.sel
    if ImGui.TreeNode("Basic") then
        local b = s.basic
        _, b[1] = SelectableP("1. I am selectable", b[1])
        _, b[2] = SelectableP("2. I am selectable", b[2])
        _, b[3] = SelectableP("3. I am selectable", b[3])
        if ImGui.Selectable("4. I am double clickable", b[4], ImGuiSelectableFlags.AllowDoubleClick) then
            if ImGui.IsMouseDoubleClicked(0) then b[4] = not b[4] end
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Multiple items on the same line") then
        local m = s.multi
        ImGui.SetNextItemAllowOverlap(); _, m[1] = SelectableP("main.c", m[1]); ImGui.SameLine(); ImGui.SmallButton("Link 1")
        ImGui.SetNextItemAllowOverlap(); _, m[2] = SelectableP("hello.cpp", m[2]); ImGui.SameLine(); ImGui.SmallButton("Link 2")
        ImGui.SetNextItemAllowOverlap(); _, m[3] = SelectableP("hello.h", m[3]); ImGui.SameLine(); ImGui.SmallButton("Link 3")
        ImGui.Spacing()
        local color_marker_w = ImGui.CalcTextSize("x").x
        for n = 0, 4 do
            ImGui.PushID(n)
            ImGui.AlignTextToFramePadding()
            if ImGui.Selectable("##selectable", s.selected_n == n, ImGuiSelectableFlags.AllowOverlap) then s.selected_n = n end
            ImGui.SameLine(0, 0)
            _, s.checked[n + 1] = ImGui.Checkbox("##check", s.checked[n + 1])
            ImGui.SameLine()
            local color = ImVec4((n % 2 == 1) and 1.0 or 0.2, (math.floor(n / 2) % 2 == 1) and 1.0 or 0.2, 0.2, 1.0)
            ImGui.ColorButton("##color", color, ImGuiColorEditFlags.NoTooltip, ImVec2(color_marker_w, 0))
            ImGui.SameLine()
            ImGui.Text("Some label")
            ImGui.PopID()
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("In Tables") then
        local sel = s.tables
        local TF = ImGuiTableFlags
        if ImGui.BeginTable("split1", 3, bit32.bor(TF.Resizable, TF.NoSavedSettings, TF.Borders)) then
            for i = 0, 9 do
                ImGui.TableNextColumn()
                _, sel[i + 1] = SelectableP(string.format("Item %d", i), sel[i + 1])
            end
            ImGui.EndTable()
        end
        ImGui.Spacing()
        if ImGui.BeginTable("split2", 3, bit32.bor(TF.Resizable, TF.NoSavedSettings, TF.Borders)) then
            for i = 0, 9 do
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                _, sel[i + 1] = SelectableP(string.format("Item %d", i), sel[i + 1], ImGuiSelectableFlags.SpanAllColumns)
                ImGui.TableNextColumn()
                ImGui.Text("Some other contents")
                ImGui.TableNextColumn()
                ImGui.Text("123456")
            end
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Grid") then
        local g = s.grid
        local time = ImGui.GetTime()
        local winning_state = true
        for y = 1, 4 do for x = 1, 4 do if g[y][x] == 0 then winning_state = false end end end
        if winning_state then
            ImGui.PushStyleVar(ImGuiStyleVar.SelectableTextAlign, ImVec2(0.5 + 0.5 * math.cos(time * 2.0), 0.5 + 0.5 * math.sin(time * 3.0)))
        end
        local size = ImGui.CalcTextSize("Sailor").x
        for y = 1, 4 do
            for x = 1, 4 do
                if x > 1 then ImGui.SameLine() end
                ImGui.PushID((y - 1) * 4 + (x - 1))
                if ImGui.Selectable("Sailor", g[y][x] ~= 0, 0, ImVec2(size, size)) then
                    g[y][x] = 1 - g[y][x]
                    if x > 1 then g[y][x - 1] = 1 - g[y][x - 1] end
                    if x < 4 then g[y][x + 1] = 1 - g[y][x + 1] end
                    if y > 1 then g[y - 1][x] = 1 - g[y - 1][x] end
                    if y < 4 then g[y + 1][x] = 1 - g[y + 1][x] end
                end
                ImGui.PopID()
            end
        end
        if winning_state then ImGui.PopStyleVar() end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Alignment") then
        HelpMarker("By default, Selectables uses style.SelectableTextAlign but it can be overridden on a per-item basis using PushStyleVar(). You'll probably want to always keep your default situation to left-align otherwise it becomes difficult to layout multiple items on a same line")
        local size = ImGui.CalcTextSize("(1.0,1.0)").x
        for y = 0, 2 do
            for x = 0, 2 do
                local alignment = ImVec2(x / 2.0, y / 2.0)
                local name = string.format("(%.1f,%.1f)", alignment.x, alignment.y)
                if x > 0 then ImGui.SameLine() end
                ImGui.PushStyleVar(ImGuiStyleVar.SelectableTextAlign, alignment)
                _, s.align[3 * y + x + 1] = SelectableP(name, s.align[3 * y + x + 1], ImGuiSelectableFlags.None, ImVec2(size, size))
                ImGui.PopStyleVar()
            end
        end
        ImGui.TreePop()
    end
    ImGui.TreePop()
end

local function EditTabBarFittingPolicyFlags(flags)
    local TB = ImGuiTabBarFlags
    if bit32.band(flags, TB.FittingPolicyMask_) == 0 then flags = bit32.bor(flags, TB.FittingPolicyDefault_) end
    for _, n in ipairs({ "FittingPolicyMixed", "FittingPolicyShrink", "FittingPolicyScroll" }) do
        local p
        p, flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_" .. n, flags, TB[n])
        if p then flags = bit32.band(flags, bit32.bnot(bit32.bxor(TB.FittingPolicyMask_, TB[n]))) end
    end
    return flags
end

S.tabs = { adv_flags = ImGuiTabBarFlags.Reorderable, opened = { true, true, true, true }, active_tabs = {}, next_tab_id = 0,
    show_leading = true, show_trailing = true, show_lt_tabs = false,
    tib_flags = bit32.bor(ImGuiTabBarFlags.AutoSelectNewTabs, ImGuiTabBarFlags.Reorderable, ImGuiTabBarFlags.FittingPolicyMixed) }
function DemoWindowWidgetsTabs()
    if not ImGui.TreeNode("Tabs") then return end
    local s = S.tabs
    local TB, TI = ImGuiTabBarFlags, ImGuiTabItemFlags
    if ImGui.TreeNode("Basic") then
        if ImGui.BeginTabBar("MyTabBar", TB.None) then
            if ImGui.BeginTabItem("Avocado") then ImGui.Text("This is the Avocado tab!\nblah blah blah blah blah"); ImGui.EndTabItem() end
            if ImGui.BeginTabItem("Broccoli") then ImGui.Text("This is the Broccoli tab!\nblah blah blah blah blah"); ImGui.EndTabItem() end
            if ImGui.BeginTabItem("Cucumber") then ImGui.Text("This is the Cucumber tab!\nblah blah blah blah blah"); ImGui.EndTabItem() end
            ImGui.EndTabBar()
        end
        ImGui.Separator()
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Advanced & Close Button") then
        for _, n in ipairs({ "Reorderable", "AutoSelectNewTabs", "TabListPopupButton", "NoCloseWithMiddleMouseButton", "DrawSelectedOverline" }) do
            _, s.adv_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_" .. n, s.adv_flags, TB[n])
        end
        s.adv_flags = EditTabBarFittingPolicyFlags(s.adv_flags)
        ImGui.AlignTextToFramePadding()
        ImGui.Text("Opened:")
        local names = { "Artichoke", "Beetroot", "Celery", "Daikon" }
        for n = 1, 4 do
            ImGui.SameLine()
            _, s.opened[n] = ImGui.Checkbox(names[n], s.opened[n])
        end
        if ImGui.BeginTabBar("MyTabBar", s.adv_flags) then
            for n = 1, 4 do
                if s.opened[n] then
                    local visible
                    visible, s.opened[n] = ImGui.BeginTabItem(names[n], s.opened[n], TI.None)
                    if visible then
                        ImGui.Text("This is the %s tab!", names[n])
                        if (n - 1) % 2 == 1 then ImGui.Text("I am an odd tab.") end
                        ImGui.EndTabItem()
                    end
                end
            end
            ImGui.EndTabBar()
        end
        ImGui.Separator()
        ImGui.TreePop()
    end

    if ImGui.TreeNode("TabItemButton & Leading/Trailing flags") then
        if s.next_tab_id == 0 then
            for _ = 1, 3 do s.active_tabs[#s.active_tabs + 1] = s.next_tab_id; s.next_tab_id = s.next_tab_id + 1 end
        end
        _, s.show_leading = ImGui.Checkbox("Show Leading TabItemButton()", s.show_leading)
        _, s.show_trailing = ImGui.Checkbox("Show Trailing TabItemButton()", s.show_trailing)
        _, s.show_lt_tabs = ImGui.Checkbox("Show Leading+Trailing TabItem()", s.show_lt_tabs)
        s.tib_flags = EditTabBarFittingPolicyFlags(s.tib_flags)
        if ImGui.BeginTabBar("MyTabBar", s.tib_flags) then
            if s.show_leading then
                if ImGui.TabItemButton("?", bit32.bor(TI.Leading, TI.NoTooltip)) then ImGui.OpenPopup("MyHelpMenu") end
            end
            if ImGui.BeginPopup("MyHelpMenu") then
                ImGui.Selectable("Hello!")
                ImGui.EndPopup()
            end
            if s.show_lt_tabs then
                if ImGui.BeginTabItem("Leading", nil, TI.Leading) then ImGui.EndTabItem() end
                if ImGui.BeginTabItem("Trailing", nil, TI.Trailing) then ImGui.EndTabItem() end
            end
            if s.show_trailing then
                if ImGui.TabItemButton("+", bit32.bor(TI.Trailing, TI.NoTooltip)) then
                    s.active_tabs[#s.active_tabs + 1] = s.next_tab_id; s.next_tab_id = s.next_tab_id + 1
                end
            end
            local n = 1
            while n <= #s.active_tabs do
                local name = string.format("%04d", s.active_tabs[n])
                local visible, open = ImGui.BeginTabItem(name, true, TI.None)
                if visible then
                    ImGui.Text("This is the %s tab!", name)
                    ImGui.EndTabItem()
                end
                if open == false then table.remove(s.active_tabs, n) else n = n + 1 end
            end
            ImGui.EndTabBar()
        end
        ImGui.Separator()
        ImGui.TreePop()
    end
    ImGui.TreePop()
end

S.text = { custom_size = 16.0, custom_scale = 1.0, wrap_width = 200.0, utf8 = Buf("\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e", 32) }
function DemoWindowWidgetsText()
    if not ImGui.TreeNode("Text") then return end
    local s = S.text
    if ImGui.TreeNode("Colorful Text") then
        ImGui.TextColored(ImVec4(1.0, 0.0, 1.0, 1.0), "Pink")
        ImGui.TextColored(ImVec4(1.0, 1.0, 0.0, 1.0), "Yellow")
        ImGui.TextDisabled("Disabled")
        ImGui.SameLine(); HelpMarker("The TextDisabled color is stored in ImGuiStyle.")
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Font Size") then
        local style = ImGui.GetStyle()
        local global_scale = style.FontScaleMain * style.FontScaleDpi
        ImGui.Text("style.FontScaleMain = %0.2f", style.FontScaleMain)
        ImGui.Text("style.FontScaleDpi = %0.2f", style.FontScaleDpi)
        ImGui.Text("global_scale = ~%0.2f", global_scale)
        ImGui.Text("FontSize = %0.2f", ImGui.GetFontSize())
        ImGui.SeparatorText("")
        s.custom_size = ImGui.SliderFloat("custom_size", s.custom_size, 10.0, 100.0, "%.0f")
        ImGui.Text("ImGui::PushFont(nullptr, custom_size);")
        ImGui.PushFont(nil, s.custom_size)
        ImGui.Text("FontSize = %.2f (== %.2f * global_scale)", ImGui.GetFontSize(), s.custom_size)
        ImGui.PopFont()
        ImGui.SeparatorText("")
        s.custom_scale = ImGui.SliderFloat("custom_scale", s.custom_scale, 0.5, 4.0, "%.2f")
        ImGui.Text("ImGui::PushFont(nullptr, style.FontSizeBase * custom_scale);")
        ImGui.PushFont(nil, style.FontSizeBase * s.custom_scale)
        ImGui.Text("FontSize = %.2f (== style.FontSizeBase * %.2f * global_scale)", ImGui.GetFontSize(), s.custom_scale)
        ImGui.PopFont()
        ImGui.SeparatorText("")
        local scaling = 0.5
        while scaling <= 4.0 do
            ImGui.PushFont(nil, style.FontSizeBase * scaling)
            ImGui.Text("FontSize = %.2f (== style.FontSizeBase * %.2f * global_scale)", ImGui.GetFontSize(), scaling)
            ImGui.PopFont()
            scaling = scaling + 0.5
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Word Wrapping") then
        ImGui.TextWrapped("This text should automatically wrap on the edge of the window. The current implementation for text wrapping follows simple rules suitable for English and possibly other languages.")
        ImGui.Spacing()
        s.wrap_width = ImGui.SliderFloat("Wrap width", s.wrap_width, -20, 600, "%.0f")
        local draw_list = ImGui.GetWindowDrawList()
        for n = 0, 1 do
            ImGui.Text("Test paragraph %d:", n)
            local pos = ImGui.GetCursorScreenPos()
            local marker_min = ImVec2(pos.x + s.wrap_width, pos.y)
            local marker_max = ImVec2(pos.x + s.wrap_width + 10, pos.y + ImGui.GetTextLineHeight())
            ImGui.PushTextWrapPos(ImGui.GetCursorPos().x + s.wrap_width)
            if n == 0 then
                ImGui.Text("The lazy dog is a good dog. This paragraph should fit within %.0f pixels. Testing a 1 character word. The quick brown fox jumps over the lazy dog.", s.wrap_width)
            else
                ImGui.Text("aaaaaaaa bbbbbbbb, c cccccccc,dddddddd. d eeeeeeee   ffffffff. gggggggg!hhhhhhhh")
            end
            draw_list:AddRect(ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), IM_COL32(255, 255, 0, 255))
            draw_list:AddRectFilled(marker_min, marker_max, IM_COL32(255, 0, 255, 255))
            ImGui.PopTextWrapPos()
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("UTF-8 Text") then
        ImGui.TextWrapped("CJK text will only appear if the font was loaded with the appropriate CJK character ranges. Call io.Fonts->AddFontFromFileTTF() manually to load extra character ranges. Read docs/FONTS.md for details.")
        ImGui.Text("Hiragana: \xe3\x81\x8b\xe3\x81\x8d\xe3\x81\x8f\xe3\x81\x91\xe3\x81\x93 (kakikukeko)")
        ImGui.Text("Kanjis: \xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e (nihongo)")
        ImGui.InputText("UTF-8 input", s.utf8, 32)
        ImGui.TreePop()
    end
    ImGui.TreePop()
end

S.tf = { filter = nil }
function DemoWindowWidgetsTextFilter()
    if not ImGui.TreeNode("Text Filter") then return end
    S.tf.filter = S.tf.filter or ImGuiTextFilter()
    local filter = S.tf.filter
    HelpMarker("Not a widget per-se, but ImGuiTextFilter is a helper to perform simple filtering on text strings.")
    ImGui.Text("Filter usage:\n  \"\"         display all lines\n  xxx        display lines containing \"xxx\"\n  xxx yyy    display lines containing \"xxx\" and \"yyy\"\n  \"xxx yyy\"  display lines containing \"xxx yyy\"\n  xxx,yyy    display lines containing \"xxx\" or \"yyy\"\n  -xxx       hide lines containing \"xxx\"")
    ImGui.SetNextItemWidth(-FLT_MIN)
    filter:DrawWithHint("##Filter", "Filter (incl -excl)")
    if ImGui.BeginChild("##items", ImVec2(-FLT_MIN, ImGui.GetTextLineHeightWithSpacing() * 15), ImGuiChildFlags.FrameStyle) then
        for _, item in ipairs({ "aaa1.c", "bbb1.c", "ccc1.c", "aaa2.cpp", "bbb2.cpp", "ccc2.cpp", "abc.h", "hello, world" }) do
            if filter:PassFilter(item) then ImGui.TextUnformatted(item) end
        end
        for _, item in ipairs(ExampleNames) do
            if filter:PassFilter(item) then ImGui.TextUnformatted(item) end
        end
    end
    ImGui.EndChild()
    ImGui.TreePop()
end

S.ti = {
    text = Buf("/*\n The Pentium F00F bug, shorthand for F0 0F C7 C8,\n the hexadecimal encoding of one offending instruction,\n more formally, the invalid operand with locked CMPXCHG8B\n instruction bug, is a design flaw in the majority of\n Intel Pentium, Pentium MMX, and Pentium OverDrive\n processors (all in the P5 microarchitecture).\n*/\n\nlabel:\n\tlock cmpxchg8b eax\n", 1024 * 16),
    ml_flags = ImGuiInputTextFlags.AllowTabInput,
    f = { Buf("", 32), Buf("", 32), Buf("", 32), Buf("", 32), Buf("", 32), Buf("", 32), Buf("", 32) },
    password = Buf("password123", 64), cb1 = Buf("", 64), cb2 = Buf("", 64), cb3 = Buf("", 64), edit_count = { 0 },
    rs_flags = 0, rs = Buf("", 1024),
    elide = Buf("/path/to/some/folder/with/long/filename.cpp", 128), elide_flags = ImGuiInputTextFlags.ElideLeft,
    misc = Buf("", 16), misc_flags = ImGuiInputTextFlags.EscapeClearsAll }
function DemoWindowWidgetsTextInput()
    if not ImGui.TreeNode("Text Input") then return end
    local s = S.ti
    local IT = ImGuiInputTextFlags
    local function FlagBox(key, name)
        if IT[name] then _, s[key] = ImGui.CheckboxFlags("ImGuiInputTextFlags_" .. name, s[key], IT[name]) end
    end
    if ImGui.TreeNode("Multi-line Text Input") then
        HelpMarker("You can use the ImGuiInputTextFlags_CallbackResize facility if you need to wire InputTextMultiline() to a dynamic string type.")
        FlagBox("ml_flags", "ReadOnly")
        FlagBox("ml_flags", "WordWrap")
        ImGui.SameLine(); HelpMarker("Feature is currently in Beta. Please read comments in imgui.h")
        FlagBox("ml_flags", "AllowTabInput")
        ImGui.SameLine(); HelpMarker("When _AllowTabInput is set, passing through the widget with Tabbing doesn't automatically activate it, in order to also cycling through subsequent widgets.")
        FlagBox("ml_flags", "CtrlEnterForNewLine")
        ImGui.InputTextMultiline("##source", s.text, 1024 * 16, ImVec2(-FLT_MIN, ImGui.GetTextLineHeight() * 16), s.ml_flags)
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Filtered Text Input") then
        local a, z, A, Z = string.byte("a"), string.byte("z"), string.byte("A"), string.byte("Z")
        local function FilterCasingSwap(data)
            local c = data.EventChar
            if c >= a and c <= z then data.EventChar = c - (a - A)
            elseif c >= A and c <= Z then data.EventChar = c + (a - A) end
            return 0
        end
        local function FilterImGuiLetters(data)
            local c = data.EventChar
            if c < 256 and string.find("imgui", string.char(c), 1, true) then return 0 end
            return 1
        end
        local f = s.f
        ImGui.InputText("default", f[1], 32)
        ImGui.InputText("decimal", f[2], 32, IT.CharsDecimal)
        ImGui.InputText("hexadecimal", f[3], 32, bit32.bor(IT.CharsHexadecimal, IT.CharsUppercase))
        ImGui.InputText("uppercase", f[4], 32, IT.CharsUppercase)
        ImGui.InputText("no blank", f[5], 32, IT.CharsNoBlank)
        ImGui.InputText("casing swap", f[6], 32, IT.CallbackCharFilter, FilterCasingSwap)
        ImGui.InputText("\"imgui\"", f[7], 32, IT.CallbackCharFilter, FilterImGuiLetters)
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Password Input") then
        ImGui.InputText("password", s.password, 64, IT.Password)
        ImGui.SameLine(); HelpMarker("Display all characters as '*'.\nDisable clipboard cut and copy.\nDisable logging.\n")
        ImGui.InputTextWithHint("password (w/ hint)", "<password>", s.password, 64, IT.Password)
        ImGui.InputText("password (clear)", s.password, 64)
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Completion, History, Edit Callbacks") then
        local function MyCallback(data)
            if data.EventFlag == IT.CallbackCompletion then
                data:InsertChars(data.CursorPos, "..")
            elseif data.EventFlag == IT.CallbackHistory then
                if data.EventKey == ImGuiKey.UpArrow then
                    data:DeleteChars(0, data.BufTextLen)
                    data:InsertChars(0, "Pressed Up!")
                    data:SelectAll()
                elseif data.EventKey == ImGuiKey.DownArrow then
                    data:DeleteChars(0, data.BufTextLen)
                    data:InsertChars(0, "Pressed Down!")
                    data:SelectAll()
                end
            elseif data.EventFlag == IT.CallbackEdit then
                local c = data.Buf[1]
                if (c >= 97 and c <= 122) or (c >= 65 and c <= 90) then data.Buf[1] = bit32.bxor(c, 32) end
                data.BufDirty = true
                local p_int = data.UserData
                p_int[1] = p_int[1] + 1
            end
            return 0
        end
        ImGui.InputText("Completion", s.cb1, 64, IT.CallbackCompletion, MyCallback)
        ImGui.SameLine(); HelpMarker("Here we append \"..\" each time Tab is pressed. See 'Examples>Console' for a more meaningful demonstration of using this callback.")
        ImGui.InputText("History", s.cb2, 64, IT.CallbackHistory, MyCallback)
        ImGui.SameLine(); HelpMarker("Here we replace and select text each time Up/Down are pressed. See 'Examples>Console' for a more meaningful demonstration of using this callback.")
        ImGui.InputText("Edit", s.cb3, 64, IT.CallbackEdit, MyCallback, s.edit_count)
        ImGui.SameLine(); HelpMarker("Here we toggle the casing of the first character on every edit + count edits.")
        ImGui.SameLine(); ImGui.Text("(%d)", s.edit_count[1])
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Resize Callback") then
        HelpMarker("Using ImGuiInputTextFlags_CallbackResize to wire your custom string type to InputText().\n\n(Lua port: fixed 1024 byte buffer, CallbackResize growth not supported)")
        FlagBox("rs_flags", "WordWrap")
        ImGui.InputTextMultiline("##MyStr", s.rs, 1024, ImVec2(-FLT_MIN, ImGui.GetTextLineHeight() * 16), s.rs_flags)
        ImGui.Text("Size: %d\nCapacity: %d", #BufStr(s.rs) + 1, 1024)
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Eliding, Alignment") then
        FlagBox("elide_flags", "ElideLeft")
        ImGui.InputText("Path", s.elide, 128, s.elide_flags)
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Miscellaneous") then
        FlagBox("misc_flags", "EscapeClearsAll")
        FlagBox("misc_flags", "ReadOnly")
        FlagBox("misc_flags", "NoUndoRedo")
        ImGui.InputText("Hello", s.misc, 16, s.misc_flags)
        ImGui.TreePop()
    end
    ImGui.TreePop()
end

S.tt = { arr = { 0.6, 0.1, 1.0, 0.5, 0.92, 0.1, 0.2 }, always_on = 0 }
function DemoWindowWidgetsTooltips()
    if not ImGui.TreeNode("Tooltips") then return end
    local s = S.tt
    local HF = ImGuiHoveredFlags
    ImGui.SeparatorText("General")
    HelpMarker("Tooltip are typically created by using a IsItemHovered() + SetTooltip() sequence.\n\nWe provide a helper SetItemTooltip() function to perform the two with standards flags.")
    local sz = ImVec2(-FLT_MIN, 0.0)
    ImGui.Button("Basic", sz)
    ImGui.SetItemTooltip("I am a tooltip")
    ImGui.Button("Fancy", sz)
    if ImGui.BeginItemTooltip() then
        ImGui.Text("I am a fancy tooltip")
        ImGui.PlotLines("Curve", s.arr, nil, #s.arr)
        ImGui.Text("Sin(time) = %f", math.sin(ImGui.GetTime()))
        ImGui.EndTooltip()
    end

    ImGui.SeparatorText("Always On")
    _, s.always_on = ImGui.RadioButton("Off", s.always_on, 0)
    ImGui.SameLine()
    _, s.always_on = ImGui.RadioButton("Always On (Simple)", s.always_on, 1)
    ImGui.SameLine()
    _, s.always_on = ImGui.RadioButton("Always On (Advanced)", s.always_on, 2)
    if s.always_on == 1 then
        ImGui.SetTooltip("I am following you around.")
    elseif s.always_on == 2 and ImGui.BeginTooltip() then
        ImGui.ProgressBar(math.sin(ImGui.GetTime()) * 0.5 + 0.5, ImVec2(ImGui.GetFontSize() * 25, 0.0))
        ImGui.EndTooltip()
    end

    ImGui.SeparatorText("Custom")
    HelpMarker("Passing ImGuiHoveredFlags_ForTooltip to IsItemHovered() is the preferred way to standardize tooltip activation details across your application. You may however decide to use custom flags for a specific tooltip instance.")
    ImGui.Button("Manual", sz)
    if ImGui.IsItemHovered(HF.ForTooltip) then ImGui.SetTooltip("I am a manually emitted tooltip.") end
    ImGui.Button("DelayNone", sz)
    if ImGui.IsItemHovered(HF.DelayNone) then ImGui.SetTooltip("I am a tooltip with no delay.") end
    ImGui.Button("DelayShort", sz)
    if ImGui.IsItemHovered(bit32.bor(HF.DelayShort, HF.NoSharedDelay)) then ImGui.SetTooltip("I am a tooltip with a short delay (%0.2f sec).", ImGui.GetStyle().HoverDelayShort) end
    ImGui.Button("DelayLong", sz)
    if ImGui.IsItemHovered(bit32.bor(HF.DelayNormal, HF.NoSharedDelay)) then ImGui.SetTooltip("I am a tooltip with a long delay (%0.2f sec).", ImGui.GetStyle().HoverDelayNormal) end
    ImGui.Button("Stationary", sz)
    if ImGui.IsItemHovered(HF.Stationary) then ImGui.SetTooltip("I am a tooltip requiring mouse to be stationary before activating.") end
    ImGui.BeginDisabled()
    ImGui.Button("Disabled item", sz)
    if ImGui.IsItemHovered(HF.ForTooltip) then ImGui.SetTooltip("I am a tooltip for a disabled item.") end
    ImGui.EndDisabled()
    ImGui.TreePop()
end

S.tn = { lines_flags = bit32.bor(ImGuiTreeNodeFlags.DrawLinesFull, ImGuiTreeNodeFlags.DefaultOpen), selection_mask = 0,
    adv_flags = bit32.bor(ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick, ImGuiTreeNodeFlags.SpanAvailWidth),
    align_label = false, use_dnd = false }
function DemoWindowWidgetsTreeNodes()
    if not ImGui.TreeNode("Tree Nodes") then return end
    local s = S.tn
    local TN = ImGuiTreeNodeFlags
    if ImGui.TreeNode("Basic Trees") then
        for i = 0, 4 do
            if i == 0 then ImGui.SetNextItemOpen(true, ImGuiCond.Once) end
            ImGui.PushID(i)
            if ImGui.TreeNode("", "Child %d", i) then
                ImGui.Text("blah blah")
                ImGui.SameLine()
                if ImGui.SmallButton("button") then end
                ImGui.TreePop()
            end
            ImGui.PopID()
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Hierarchy Lines") then
        HelpMarker("Default option for DrawLinesXXX is stored in style.TreeLinesFlags")
        _, s.lines_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesNone", s.lines_flags, TN.DrawLinesNone)
        _, s.lines_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesFull", s.lines_flags, TN.DrawLinesFull)
        _, s.lines_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesToNodes", s.lines_flags, TN.DrawLinesToNodes)
        local f = s.lines_flags
        if ImGui.TreeNodeEx("Parent", f) then
            if ImGui.TreeNodeEx("Child 1", f) then ImGui.Button("Button for Child 1"); ImGui.TreePop() end
            if ImGui.TreeNodeEx("Child 2", f) then ImGui.Button("Button for Child 2"); ImGui.TreePop() end
            ImGui.Text("Remaining contents")
            ImGui.Text("Remaining contents")
            ImGui.TreePop()
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Clipping Large Trees") then
        ImGui.TextWrapped("- Using ImGuiListClipper with trees is a less easy than on arrays or grids.\n- Refer to 'Demo->Examples->Property Editor' for an example of how to do that.\n- Discuss in #3823")
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Selectable Nodes") then
        HelpMarker("Manually implemented selectable nodes.\nClick to select, Ctrl+Click to toggle, click on arrows or double-click to open.")
        local node_clicked_idx = -1
        for node_n = 0, 5 do
            local flags = bit32.bor(TN.OpenOnArrow, TN.OpenOnDoubleClick, TN.SpanAvailWidth)
            if bit32.band(s.selection_mask, bit32.lshift(1, node_n)) ~= 0 then flags = bit32.bor(flags, TN.Selected) end
            local is_open = ImGui.TreeNodeEx(node_n, flags, "Selectable Node %d", node_n)
            if ImGui.IsItemClicked() and not ImGui.IsItemToggledOpen() then node_clicked_idx = node_n end
            if is_open then
                ImGui.BulletText("<Node contents here>")
                ImGui.TreePop()
            end
        end
        if node_clicked_idx ~= -1 then
            if ImGui.GetIO().KeyCtrl then
                s.selection_mask = bit32.bxor(s.selection_mask, bit32.lshift(1, node_clicked_idx))
            else
                s.selection_mask = bit32.lshift(1, node_clicked_idx)
            end
        end
        ImGui.TreePop()
    end

    if ImGui.TreeNode("Advanced") then
        local function FB(name, help)
            _, s.adv_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_" .. name, s.adv_flags, TN[name])
            if help then ImGui.SameLine(); HelpMarker(help) end
        end
        FB("OpenOnArrow"); FB("OpenOnDoubleClick")
        FB("SpanAvailWidth", "Extend hit area to all available width instead of allowing more items to be laid out after the node.")
        FB("SpanFullWidth")
        FB("SpanLabelWidth", "Reduce hit area to the text label and a bit of margin.")
        FB("SpanAllColumns", "For use in Tables only.")
        FB("AllowOverlap")
        FB("Framed", "Draw frame with background (e.g. for CollapsingHeader)")
        FB("FramePadding"); FB("NavLeftJumpsToParent")
        HelpMarker("Default option for DrawLinesXXX is stored in style.TreeLinesFlags")
        FB("DrawLinesNone"); FB("DrawLinesFull"); FB("DrawLinesToNodes")
        _, s.align_label = ImGui.Checkbox("Align label with current X position", s.align_label)
        _, s.use_dnd = ImGui.Checkbox("Make Tree Nodes as drag & drop sources", s.use_dnd)
        if s.align_label then ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing()) end
        for node_n = 0, 5 do
            local node_flags = s.adv_flags
            if node_n < 3 then
                local is_open = ImGui.TreeNodeEx(node_n, node_flags, "Selectable Node %d", node_n)
                if s.use_dnd and ImGui.BeginDragDropSource() then
                    ImGui.SetDragDropPayload("MY_TREENODE_PAYLOAD_TYPE", nil, 0)
                    ImGui.Text("This is a drag and drop source")
                    ImGui.EndDragDropSource()
                end
                if node_n == 2 and bit32.band(s.adv_flags, TN.SpanLabelWidth) ~= 0 then
                    ImGui.SameLine()
                    if ImGui.SmallButton("button") then end
                end
                if is_open then
                    ImGui.BulletText("Blah blah\nBlah Blah")
                    ImGui.SameLine()
                    ImGui.SmallButton("Button")
                    ImGui.TreePop()
                end
            else
                node_flags = bit32.bor(node_flags, TN.Leaf, TN.NoTreePushOnOpen)
                ImGui.TreeNodeEx(node_n, node_flags, "Selectable Leaf %d", node_n)
                if s.use_dnd and ImGui.BeginDragDropSource() then
                    ImGui.SetDragDropPayload("MY_TREENODE_PAYLOAD_TYPE", nil, 0)
                    ImGui.Text("This is a drag and drop source")
                    ImGui.EndDragDropSource()
                end
            end
        end
        if s.align_label then ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing()) end
        ImGui.TreePop()
    end
    ImGui.TreePop()
end

S.vs = { int_value = 0, values = { 0.0, 0.60, 0.35, 0.9, 0.70, 0.20, 0.0 }, values2 = { 0.20, 0.80, 0.40, 0.25 } }
function DemoWindowWidgetsVerticalSliders()
    if not ImGui.TreeNode("Vertical Sliders") then return end
    local s = S.vs
    local spacing = 4
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(spacing, spacing))
    s.int_value = ImGui.VSliderInt("##int", ImVec2(18, 160), s.int_value, 0, 5)
    ImGui.SameLine()
    local values = s.values
    ImGui.PushID("set1")
    for i = 0, 6 do
        if i > 0 then ImGui.SameLine() end
        ImGui.PushID(i)
        ImGui.PushStyleColor(ImGuiCol.FrameBg, HSV(i / 7.0, 0.5, 0.5))
        ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, HSV(i / 7.0, 0.6, 0.5))
        ImGui.PushStyleColor(ImGuiCol.FrameBgActive, HSV(i / 7.0, 0.7, 0.5))
        ImGui.PushStyleColor(ImGuiCol.SliderGrab, HSV(i / 7.0, 0.9, 0.9))
        values[i + 1] = ImGui.VSliderFloat("##v", ImVec2(18, 160), values[i + 1], 0.0, 1.0, "")
        if ImGui.IsItemActive() or ImGui.IsItemHovered() then ImGui.SetTooltip("%.3f", values[i + 1]) end
        ImGui.PopStyleColor(4)
        ImGui.PopID()
    end
    ImGui.PopID()

    ImGui.SameLine()
    ImGui.PushID("set2")
    local rows = 3
    local small_slider_size = ImVec2(18, math.floor((160.0 - (rows - 1) * spacing) / rows))
    for nx = 0, 3 do
        if nx > 0 then ImGui.SameLine() end
        ImGui.BeginGroup()
        for ny = 0, rows - 1 do
            ImGui.PushID(nx * rows + ny)
            s.values2[nx + 1] = ImGui.VSliderFloat("##v", small_slider_size, s.values2[nx + 1], 0.0, 1.0, "")
            if ImGui.IsItemActive() or ImGui.IsItemHovered() then ImGui.SetTooltip("%.3f", s.values2[nx + 1]) end
            ImGui.PopID()
        end
        ImGui.EndGroup()
    end
    ImGui.PopID()

    ImGui.SameLine()
    ImGui.PushID("set3")
    for i = 0, 3 do
        if i > 0 then ImGui.SameLine() end
        ImGui.PushID(i)
        ImGui.PushStyleVar(ImGuiStyleVar.GrabMinSize, 40)
        values[i + 1] = ImGui.VSliderFloat("##v", ImVec2(40, 160), values[i + 1], 0.0, 1.0, "%.2f\nsec")
        ImGui.PopStyleVar()
        ImGui.PopID()
    end
    ImGui.PopID()
    ImGui.PopStyleVar()
    ImGui.TreePop()
end

----------------------------------------------------------------
-- [SECTION] Example App: Main Menu Bar / ShowExampleAppMainMenuBar()
----------------------------------------------------------------

S.menu = { enabled = true, f = 0.5, n = 0, b = true }
function ShowExampleMenuFile()
    local s = S.menu
    ImGui.MenuItem("(demo menu)", nil, false, false)
    if ImGui.MenuItem("New") then end
    if ImGui.MenuItem("Open", "Ctrl+O") then end
    if ImGui.BeginMenu("Open Recent") then
        ImGui.MenuItem("fish_hat.c")
        ImGui.MenuItem("fish_hat.inl")
        ImGui.MenuItem("fish_hat.h")
        if ImGui.BeginMenu("More..") then
            ImGui.MenuItem("Hello")
            ImGui.MenuItem("Sailor")
            if ImGui.BeginMenu("Recurse..") then
                ShowExampleMenuFile()
                ImGui.EndMenu()
            end
            ImGui.EndMenu()
        end
        ImGui.EndMenu()
    end
    if ImGui.MenuItem("Save", "Ctrl+S") then end
    if ImGui.MenuItem("Save As..") then end

    ImGui.Separator()
    if ImGui.BeginMenu("Options") then
        _, s.enabled = ImGui.MenuItem("Enabled", "", s.enabled)
        ImGui.BeginChild("child", ImVec2(0, ImGui.GetTextLineHeightWithSpacing() * 5.0), ImGuiChildFlags.Borders)
        for i = 0, 9 do ImGui.Text("Scrolling Text %d", i) end
        ImGui.EndChild()
        s.f = ImGui.SliderFloat("Value", s.f, 0.0, 1.0)
        s.f = ImGui.InputFloat("Input", s.f, 0.1)
        s.n = ImGui.Combo("Combo", s.n, "Yes\0No\0Maybe\0\0")
        ImGui.EndMenu()
    end

    if ImGui.BeginMenu("Colors") then
        local sz = ImGui.GetTextLineHeight()
        for i = 0, ImGuiCol.COUNT - 1 do
            local name = ImGui.GetStyleColorName(i)
            local p = ImGui.GetCursorScreenPos()
            ImGui.GetWindowDrawList():AddRectFilled(p, ImVec2(p.x + sz, p.y + sz), ImGui.GetColorU32(i))
            ImGui.Dummy(ImVec2(sz, sz))
            ImGui.SameLine()
            ImGui.MenuItem(name)
        end
        ImGui.EndMenu()
    end

    -- Here we demonstrate appending again to the "Options" menu (which we already created above)
    if ImGui.BeginMenu("Options") then
        _, s.b = ImGui.Checkbox("SomeOption", s.b)
        ImGui.EndMenu()
    end

    if ImGui.BeginMenu("Disabled", false) then
        IM_ASSERT(false)
    end
    if ImGui.MenuItem("Checked", nil, true) then end
    ImGui.Separator()
    if ImGui.MenuItem("Quit", "Alt+F4") then end
end

function ShowExampleAppMainMenuBar()
    if ImGui.BeginMainMenuBar() then
        if ImGui.BeginMenu("File") then
            ShowExampleMenuFile()
            ImGui.EndMenu()
        end
        if ImGui.BeginMenu("Edit") then
            if ImGui.MenuItem("Undo", "Ctrl+Z") then end
            if ImGui.MenuItem("Redo", "Ctrl+Y", false, false) then end
            ImGui.Separator()
            if ImGui.MenuItem("Cut", "Ctrl+X") then end
            if ImGui.MenuItem("Copy", "Ctrl+C") then end
            if ImGui.MenuItem("Paste", "Ctrl+V") then end
            ImGui.EndMenu()
        end
        ImGui.EndMainMenuBar()
    end
end

----------------------------------------------------------------
-- [SECTION] Style Editor / ShowStyleEditor()
----------------------------------------------------------------

-- Deep copy of an ImGuiStyle (ImVec2/ImVec4 fields and Colors[] are copied by value)
local function StyleCopy(dst, src)
    for k, v in pairs(src) do
        if k == "Colors" then
            dst.Colors = dst.Colors or {}
            for i, c in pairs(v) do
                if type(c) == "table" then dst.Colors[i] = dst.Colors[i] or ImVec4(); ImVec4_Copy(dst.Colors[i], c) else dst.Colors[i] = c end
            end
        elseif type(v) == "table" and getmetatable(v) ~= nil and type(v[1]) == "number" then
            local c = dst[k]
            if type(c) ~= "table" then c = setmetatable({}, getmetatable(v)); dst[k] = c end
            for _, key in ipairs({ "x", "y", "z", "w" }) do if rawget(v, key) ~= nil then rawset(c, key, rawget(v, key)) end end
        else
            dst[k] = v
        end
    end
    if getmetatable(dst) == nil then setmetatable(dst, getmetatable(src)) end
    return dst
end

local function ColorsEqual(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] end

S.ss = { style_idx = -1 }
function ImGui.ShowStyleSelector(label)
    local s = S.ss
    local style_names = { "Dark", "Light", "Classic" }
    local ret = false
    if ImGui.BeginCombo(label, style_names[s.style_idx + 1] or "") then
        for n = 0, 2 do
            if ImGui.Selectable(style_names[n + 1], s.style_idx == n, ImGuiSelectableFlags.SelectOnNav) then
                s.style_idx = n
                ret = true
                if n == 0 then ImGui.StyleColorsDark() elseif n == 1 then ImGui.StyleColorsLight() else ImGui.StyleColorsClassic() end
            elseif s.style_idx == n then
                ImGui.SetItemDefaultFocus()
            end
        end
        ImGui.EndCombo()
    end
    return ret
end

local function GetTreeLinesFlagsName(flags)
    local TN = ImGuiTreeNodeFlags
    if flags == TN.DrawLinesNone then return "DrawLinesNone" end
    if flags == TN.DrawLinesFull then return "DrawLinesFull" end
    if flags == TN.DrawLinesToNodes then return "DrawLinesToNodes" end
    return ""
end

S.se = { ref_saved_style = nil, init = true, output_dest = 0, output_only_modified = true, alpha_flags = 0, filter = nil }
function ImGui.ShowStyleEditor(ref)
    local se = S.se
    local style = ImGui.GetStyle()
    if se.ref_saved_style == nil then se.ref_saved_style = {} end
    if se.init and ref == nil then StyleCopy(se.ref_saved_style, style) end
    se.init = false
    if ref == nil then ref = se.ref_saved_style end

    local default_border_size = math.floor(style._MainScale or 1.0)
    local max_border_size = math.max(default_border_size, 2.0)
    local function SF(name, mn, mx, fmt) if style[name] ~= nil then style[name] = ImGui.SliderFloat(name, style[name], mn, mx, fmt or "%.0f") end end
    local function SF2(name, mn, mx, fmt) if style[name] ~= nil then ImGui.SliderFloat2(name, style[name], mn, mx, fmt or "%.0f") end end
    local function DF(name, speed, mn, mx, fmt, flags) if style[name] ~= nil then style[name] = ImGui.DragFloat(name, style[name], speed, mn, mx, fmt or "%.0f", flags) end end

    ImGui.PushItemWidth(ImGui.GetWindowWidth() * 0.50)

    ImGui.SeparatorText("General")
    if bit32.band(ImGui.GetIO().BackendFlags, ImGuiBackendFlags.RendererHasTextures) == 0 then
        ImGui.BulletText("Warning: Font scaling will NOT be smooth, because\nImGuiBackendFlags_RendererHasTextures is not set!")
        ImGui.BulletText("For instructions, see:")
        ImGui.SameLine()
        ImGui.TextLinkOpenURL("docs/BACKENDS.md", "https://github.com/ocornut/imgui/blob/master/docs/BACKENDS.md")
    end
    if ImGui.ShowStyleSelector("Colors##Selector") then StyleCopy(se.ref_saved_style, style) end
    if ImGui.ShowFontSelector then ImGui.ShowFontSelector("Fonts##Selector") end
    local changed
    style.FontSizeBase, changed = ImGui.DragFloat("FontSizeBase", style.FontSizeBase, 0.20, 5.0, 100.0, "%.0f")
    if changed then style._NextFrameFontSizeBase = style.FontSizeBase end
    ImGui.SameLine(0.0, 0.0); ImGui.Text(" (out %.2f)", ImGui.GetFontSize())
    style.FontScaleMain = ImGui.DragFloat("FontScaleMain", style.FontScaleMain, 0.02, 0.5, 4.0)
    ImGui.BeginDisabled(ImGui.GetIO().ConfigDpiScaleFonts == true)
    style.FontScaleDpi = ImGui.DragFloat("FontScaleDpi", style.FontScaleDpi, 0.02, 0.5, 4.0)
    ImGui.SetItemTooltip("When io.ConfigDpiScaleFonts is set, this value is automatically overwritten.")
    ImGui.EndDisabled()

    style.FrameRounding, changed = ImGui.SliderFloat("FrameRounding", style.FrameRounding, 0.0, 12.0, "%.0f")
    if changed then style.GrabRounding = style.FrameRounding end
    local p, border
    p, border = ImGui.Checkbox("WindowBorder", style.WindowBorderSize > 0.0); if p then style.WindowBorderSize = border and default_border_size or 0.0 end
    ImGui.SameLine()
    p, border = ImGui.Checkbox("FrameBorder", style.FrameBorderSize > 0.0); if p then style.FrameBorderSize = border and default_border_size or 0.0 end
    ImGui.SameLine()
    p, border = ImGui.Checkbox("PopupBorder", style.PopupBorderSize > 0.0); if p then style.PopupBorderSize = border and default_border_size or 0.0 end

    if ImGui.Button("Save Ref") then StyleCopy(se.ref_saved_style, style); if ref ~= se.ref_saved_style then StyleCopy(ref, style) end end
    ImGui.SameLine()
    if ImGui.Button("Revert Ref") then StyleCopy(style, ref) end
    ImGui.SameLine()
    HelpMarker("Save/Revert in local non-persistent storage. Default Colors definition are not affected. Use \"Export\" below to save them somewhere.")

    ImGui.SeparatorText("Details")
    if ImGui.BeginTabBar("##tabs", ImGuiTabBarFlags.None) then
        if ImGui.BeginTabItem("Sizes") then
            ImGui.SeparatorText("Main")
            SF2("WindowPadding", 0.0, 20.0); SF2("FramePadding", 0.0, 20.0); SF2("ItemSpacing", 0.0, 20.0)
            SF2("ItemInnerSpacing", 0.0, 20.0); SF2("TouchExtraPadding", 0.0, 10.0)
            SF("IndentSpacing", 0.0, 30.0); SF("GrabMinSize", 1.0, 20.0)

            ImGui.SeparatorText("Borders")
            SF("WindowBorderSize", 0.0, max_border_size); SF("ChildBorderSize", 0.0, max_border_size)
            SF("PopupBorderSize", 0.0, max_border_size); SF("FrameBorderSize", 0.0, max_border_size)

            ImGui.SeparatorText("Rounding")
            SF("WindowRounding", 0.0, 12.0); SF("ChildRounding", 0.0, 12.0); SF("FrameRounding", 0.0, 12.0)
            SF("PopupRounding", 0.0, 12.0); SF("GrabRounding", 0.0, 12.0); SF("MenuItemRounding", 0.0, 12.0)

            ImGui.SeparatorText("Scrollbar")
            SF("ScrollbarSize", 1.0, 20.0); SF("ScrollbarRounding", 0.0, 12.0); SF("ScrollbarPadding", 0.0, 10.0)

            ImGui.SeparatorText("Tabs")
            SF("TabBorderSize", 0.0, max_border_size); SF("TabBarBorderSize", 0.0, max_border_size)
            SF("TabBarOverlineSize", 0.0, math.max(3.0, max_border_size))
            ImGui.SameLine(); HelpMarker("Overline is only drawn over the selected tab when ImGuiTabBarFlags_DrawSelectedOverline is set.")
            DF("TabMinWidthBase", 0.5, 1.0, 500.0); DF("TabMinWidthShrink", 0.5, 1.0, 500.0, "%0.f")
            if style.TabCloseButtonMinWidthSelected ~= nil then
                DF("TabCloseButtonMinWidthSelected", 0.5, -1.0, 100.0, (style.TabCloseButtonMinWidthSelected < 0.0) and "%.0f (Always)" or "%.0f")
                DF("TabCloseButtonMinWidthUnselected", 0.5, -1.0, 100.0, (style.TabCloseButtonMinWidthUnselected < 0.0) and "%.0f (Always)" or "%.0f")
            end
            SF("TabRounding", 0.0, 12.0)

            ImGui.SeparatorText("Tables")
            SF2("CellPadding", 0.0, 20.0)
            style.TableAngledHeadersAngle = ImGui.SliderAngle("TableAngledHeadersAngle", style.TableAngledHeadersAngle, -50.0, 50.0)
            SF2("TableAngledHeadersTextAlign", 0.0, 1.0, "%.2f")

            ImGui.SeparatorText("Trees")
            local combo_open = ImGui.BeginCombo("TreeLinesFlags", GetTreeLinesFlagsName(style.TreeLinesFlags))
            ImGui.SameLine()
            HelpMarker("[Experimental] Tree lines may not work in all situations (e.g. using a clipper) and may incurs slight traversal overhead.\n\nImGuiTreeNodeFlags_DrawLinesFull is faster than ImGuiTreeNodeFlags_DrawLinesToNode.")
            if combo_open then
                local TN = ImGuiTreeNodeFlags
                for _, option in ipairs({ TN.DrawLinesNone, TN.DrawLinesFull, TN.DrawLinesToNodes }) do
                    if ImGui.Selectable(GetTreeLinesFlagsName(option), style.TreeLinesFlags == option) then style.TreeLinesFlags = option end
                end
                ImGui.EndCombo()
            end
            SF("TreeLinesSize", 0.0, max_border_size); SF("TreeLinesRounding", 0.0, 12.0)

            ImGui.SeparatorText("Windows")
            SF2("WindowTitleAlign", 0.0, 1.0, "%.2f"); SF("WindowBorderHoverPadding", 1.0, 20.0)
            local window_menu_button_position = style.WindowMenuButtonPosition + 1
            window_menu_button_position, changed = ImGui.Combo("WindowMenuButtonPosition", window_menu_button_position, "None\0Left\0Right\0")
            if changed then style.WindowMenuButtonPosition = window_menu_button_position - 1 end

            ImGui.SeparatorText("Widgets")
            SF("ColorMarkerSize", 0.0, 8.0)
            style.ColorButtonPosition = ImGui.Combo("ColorButtonPosition", style.ColorButtonPosition, "Left\0Right\0")
            SF2("ButtonTextAlign", 0.0, 1.0, "%.2f")
            ImGui.SameLine(); HelpMarker("Alignment applies when a button is larger than its text content.")
            SF2("SelectableTextAlign", 0.0, 1.0, "%.2f")
            ImGui.SameLine(); HelpMarker("Alignment applies when a selectable is larger than its text content.")
            SF("SeparatorSize", 0.0, 10.0); SF("SeparatorTextBorderSize", 0.0, 10.0)
            SF2("SeparatorTextAlign", 0.0, 1.0, "%.2f"); SF2("SeparatorTextPadding", 0.0, 40.0)
            SF("LogSliderDeadzone", 0.0, 12.0); SF("ImageRounding", 0.0, 12.0); SF("ImageBorderSize", 0.0, max_border_size)

            ImGui.SeparatorText("Docking")
            _, style.DockingNodeHasCloseButton = ImGui.Checkbox("DockingNodeHasCloseButton", style.DockingNodeHasCloseButton)
            SF("DockingSeparatorSize", 0.0, 12.0)

            ImGui.SeparatorText("Tooltips")
            for n = 0, 1 do
                local key = (n == 0) and "HoverFlagsForTooltipMouse" or "HoverFlagsForTooltipNav"
                if ImGui.TreeNodeEx(key) then
                    for _, f in ipairs({ "DelayNone", "DelayShort", "DelayNormal", "Stationary", "NoSharedDelay" }) do
                        _, style[key] = ImGui.CheckboxFlags("ImGuiHoveredFlags_" .. f, style[key], ImGuiHoveredFlags[f])
                    end
                    ImGui.TreePop()
                end
            end

            ImGui.SeparatorText("Misc")
            SF2("DisplayWindowPadding", 0.0, 30.0); ImGui.SameLine(); HelpMarker("Apply to regular windows: amount which we enforce to keep visible when moving near edges of your screen.")
            SF2("DisplaySafeAreaPadding", 0.0, 30.0); ImGui.SameLine(); HelpMarker("Apply to every windows, menus, popups, tooltips: amount where we avoid displaying contents. Adjust if you cannot see the edges of your screen (e.g. on a TV where scaling has not been configured).")
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Colors") then
            if ImGui.Button("Export") then
                if se.output_dest == 0 then ImGui.LogToClipboard() else ImGui.LogToTTY() end
                ImGui.LogText("ImVec4* colors = GetStyle().Colors;\n")
                for i = 0, ImGuiCol.COUNT - 1 do
                    local col = style.Colors[i]
                    local name = ImGui.GetStyleColorName(i)
                    if not se.output_only_modified or not ColorsEqual(col, ref.Colors[i]) then
                        ImGui.LogText("colors[ImGuiCol_%s]%s= ImVec4(%.2ff, %.2ff, %.2ff, %.2ff);\n", name, string.rep(" ", math.max(0, 23 - #name)), col.x, col.y, col.z, col.w)
                    end
                end
                ImGui.LogFinish()
            end
            ImGui.SameLine(); ImGui.SetNextItemWidth(ImGui.GetFontSize() * 10)
            se.output_dest = ImGui.Combo("##output_type", se.output_dest, "To Clipboard\0To TTY\0")
            ImGui.SameLine(); _, se.output_only_modified = ImGui.Checkbox("Only Modified Colors", se.output_only_modified)

            local CE = ImGuiColorEditFlags
            if ImGui.RadioButtonEx("Opaque", se.alpha_flags == CE.AlphaOpaque) then se.alpha_flags = CE.AlphaOpaque end ImGui.SameLine()
            if ImGui.RadioButtonEx("Alpha", se.alpha_flags == CE.None) then se.alpha_flags = CE.None end ImGui.SameLine()
            if ImGui.RadioButtonEx("Both", se.alpha_flags == CE.AlphaPreviewHalf) then se.alpha_flags = CE.AlphaPreviewHalf end ImGui.SameLine()
            HelpMarker("In the color list:\nLeft-click on color square to open color picker,\nRight-click to open edit options menu.")

            se.filter = se.filter or ImGuiTextFilter()
            ImGui.SetNextItemWidth(-FLT_MIN)
            se.filter:DrawWithHint("##FilterColors", "Filter Colors (incl -excl)")

            ImGui.SetNextWindowSizeConstraints(ImVec2(0.0, ImGui.GetTextLineHeightWithSpacing() * 10), ImVec2(FLT_MAX, FLT_MAX))
            ImGui.BeginChild("##colors", ImVec2(0, 0), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.NavFlattened), bit32.bor(ImGuiWindowFlags.AlwaysVerticalScrollbar, ImGuiWindowFlags.AlwaysHorizontalScrollbar))
            ImGui.PushItemWidth(ImGui.GetFontSize() * -12)
            -- [Luau] clipped: only visible rows are submitted (upstream submits every color)
            local visible_cols = {}
            for i = 0, ImGuiCol.COUNT - 1 do
                if se.filter:PassFilter(ImGui.GetStyleColorName(i)) then visible_cols[#visible_cols + 1] = i end
            end
            local clipper = ImGuiListClipper()
            clipper:Begin(#visible_cols)
            while clipper:Step() do for row = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                local i = visible_cols[row + 1]
                local name = ImGui.GetStyleColorName(i)
                do
                    ImGui.PushID(i)
                    if ImGui.DebugFlashStyleColor then
                        if ImGui.Button("?") then ImGui.DebugFlashStyleColor(i) end
                        ImGui.SetItemTooltip("Flash given color to identify places where it is used.")
                        ImGui.SameLine()
                    end
                    ImGui.ColorEdit4("##color", style.Colors[i], bit32.bor(CE.AlphaBar, se.alpha_flags))
                    if not ColorsEqual(style.Colors[i], ref.Colors[i]) then
                        ImGui.SameLine(0.0, style.ItemInnerSpacing.x); if ImGui.Button("Save") then ImVec4_Copy(ref.Colors[i], style.Colors[i]) end
                        ImGui.SameLine(0.0, style.ItemInnerSpacing.x); if ImGui.Button("Revert") then ImVec4_Copy(style.Colors[i], ref.Colors[i]) end
                    end
                    ImGui.SameLine(0.0, style.ItemInnerSpacing.x)
                    ImGui.TextUnformatted(name)
                    ImGui.PopID()
                end
            end end
            clipper:End()
            ImGui.PopItemWidth()
            ImGui.EndChild()
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Fonts") then
            if ImGui.ShowFontAtlas then ImGui.ShowFontAtlas(ImGui.GetIO().Fonts) else DemoNotPorted("ShowFontAtlas") end
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Rendering") then
            _, style.AntiAliasedLines = ImGui.Checkbox("Anti-aliased lines", style.AntiAliasedLines)
            ImGui.SameLine()
            HelpMarker("When disabling anti-aliasing lines, you'll probably want to disable borders in your style as well.")
            ImGui.BeginDisabled(style.AntiAliasedLines == false)
            _, style.AntiAliasedLineEnds = ImGui.Checkbox("Anti-aliased line ends", style.AntiAliasedLineEnds)
            ImGui.EndDisabled()
            _, style.AntiAliasedFill = ImGui.Checkbox("Anti-aliased fill", style.AntiAliasedFill)
            local io = ImGui.GetIO()
            _, io.ConfigDebugDrawListDefaultsToStrokeLegacy = ImGui.Checkbox("Debug: DrawList Defaults to _StrokeLegacy", io.ConfigDebugDrawListDefaultsToStrokeLegacy == true)

            ImGui.PushItemWidth(ImGui.GetFontSize() * 8)
            -- [port] library still stores the pre-1.93 CurveTessellationTol (== MaxError * MaxError)
            local curve_err = ImGui.DragFloat("Curve Tessellation Max Error", math.sqrt(style.CurveTessellationTol), 0.02, 0.10, 10.0, "%.2f")
            if curve_err < 0.10 then curve_err = 0.10 end
            style.CurveTessellationTol = curve_err * curve_err

            style.CircleTessellationMaxError = ImGui.DragFloat("Circle Tessellation Max Error", style.CircleTessellationMaxError, 0.005, 0.10, 5.0, "%.2f", ImGuiSliderFlags.AlwaysClamp)
            local show_samples = ImGui.IsItemActive()
            if show_samples then ImGui.SetNextWindowPos(ImGui.GetCursorScreenPos()) end
            if show_samples and ImGui.BeginTooltip() then
                ImGui.TextUnformatted("(R = radius, N = approx number of segments)")
                ImGui.Spacing()
                local draw_list = ImGui.GetWindowDrawList()
                local min_widget_width = ImGui.CalcTextSize("R: MMM\nN: MMM").x
                for n = 0, 7 do
                    local RAD_MIN, RAD_MAX = 5.0, 70.0
                    local rad = RAD_MIN + (RAD_MAX - RAD_MIN) * n / (8.0 - 1.0)
                    ImGui.BeginGroup()
                    ImGui.Text("R: %.f\nN: %d", rad, draw_list:_CalcCircleAutoSegmentCount(rad))
                    local canvas_width = math.max(min_widget_width, rad * 2.0)
                    local offset_x = math.floor(canvas_width * 0.5)
                    local offset_y = math.floor(RAD_MAX)
                    local p1 = ImGui.GetCursorScreenPos()
                    draw_list:AddCircle(ImVec2(p1.x + offset_x, p1.y + offset_y), rad, ImGui.GetColorU32(ImGuiCol.Text))
                    ImGui.Dummy(ImVec2(canvas_width, RAD_MAX * 2))
                    ImGui.EndGroup()
                    ImGui.SameLine()
                end
                ImGui.EndTooltip()
            end
            ImGui.SameLine()
            HelpMarker("When drawing circle primitives with \"num_segments == 0\" tessellation will be calculated automatically.")
            style.Alpha = ImGui.DragFloat("Global Alpha", style.Alpha, 0.005, 0.20, 1.0, "%.2f")
            style.DisabledAlpha = ImGui.DragFloat("Disabled Alpha", style.DisabledAlpha, 0.005, 0.0, 1.0, "%.2f")
            ImGui.SameLine(); HelpMarker("Additional alpha multiplier for disabled items (multiply over current value of Alpha).")
            ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
    ImGui.PopItemWidth()
end
end --[[ imgui_demo_widgets.lua ]]

do --[[ About window ]]
-- Demo tools: ShowAboutWindow(), ShowFontAtlas(), ShowFontSelector(), ShowDebugLogWindow(), ShowIDStackToolWindow()
local _

----------------------------------------------------------------
-- [SECTION] About Window / ShowAboutWindow()
----------------------------------------------------------------

local show_config_info = false
function ImGui.ShowAboutWindow(p_open)
    local visible
    p_open, visible = ImGui.Begin("About Dear ImGui", p_open, ImGuiWindowFlags.AlwaysAutoResize)
    if not visible then ImGui.End(); return p_open end
    ImGui.Text("Dear ImGui %s (%d)", IMGUI_VERSION, IMGUI_VERSION_NUM)
    ImGui.TextLinkOpenURL("Homepage", "https://github.com/ocornut/imgui"); ImGui.SameLine()
    ImGui.TextLinkOpenURL("FAQ", "https://github.com/ocornut/imgui/blob/master/docs/FAQ.md"); ImGui.SameLine()
    ImGui.TextLinkOpenURL("Wiki", "https://github.com/ocornut/imgui/wiki"); ImGui.SameLine()
    ImGui.TextLinkOpenURL("Extensions", "https://github.com/ocornut/imgui/wiki/Useful-Extensions"); ImGui.SameLine()
    ImGui.TextLinkOpenURL("Releases", "https://github.com/ocornut/imgui/releases"); ImGui.SameLine()
    ImGui.TextLinkOpenURL("Funding", "https://github.com/ocornut/imgui/wiki/Funding")
    ImGui.Separator()
    ImGui.Text("(c) 2014-2026 Omar Cornut")
    ImGui.Text("Developed by Omar Cornut and all Dear ImGui contributors.")
    ImGui.Text("Dear ImGui is licensed under the MIT License, see LICENSE for more information.")
    ImGui.Text("If your company uses this, please consider funding the project.")
    ImGui.Text("Luau/Roblox port: imgui_impl_roblox (software rasterizer into EditableImage tiles).")

    _, show_config_info = ImGui.Checkbox("Config/Build Information", show_config_info)
    if show_config_info then
        local io = ImGui.GetIO()
        local style = ImGui.GetStyle()
        local copy_to_clipboard = ImGui.Button("Copy to clipboard")
        local child_size = ImVec2(0, ImGui.GetTextLineHeightWithSpacing() * 18)
        ImGui.BeginChild(ImGui.GetID("cfg_infos"), child_size, ImGuiChildFlags.FrameStyle)
        if copy_to_clipboard then
            ImGui.LogToClipboard()
            ImGui.LogText("// (Copy from the next line. Keep the ``` markers for formatting.)\n")
            ImGui.LogText("```cpp\n")
        end
        ImGui.Text("Dear ImGui %s (%d)", IMGUI_VERSION, IMGUI_VERSION_NUM)
        ImGui.Separator()
        ImGui.Text("define: IMGUI_HAS_VIEWPORT")
        ImGui.Text("define: IMGUI_HAS_DOCK")
        ImGui.Text("runtime: Luau (%s)", _VERSION or "?")
        ImGui.Separator()
        ImGui.Text("io.BackendPlatformName: %s", io.BackendPlatformName or "NULL")
        ImGui.Text("io.BackendRendererName: %s", io.BackendRendererName or "NULL")
        ImGui.Text("io.ConfigFlags: 0x%08X", io.ConfigFlags)
        local CF = ImGuiConfigFlags
        for _, n in ipairs({ "NavEnableKeyboard", "NavEnableGamepad", "NoMouse", "NoMouseCursorChange", "NoKeyboard", "DockingEnable", "ViewportsEnable" }) do
            if CF[n] and bit32.band(io.ConfigFlags, CF[n]) ~= 0 then ImGui.Text(" %s", n) end
        end
        for _, n in ipairs({ "MouseDrawCursor", "ConfigDpiScaleFonts", "ConfigDpiScaleViewports", "ConfigViewportsNoAutoMerge", "ConfigViewportsNoTaskBarIcon",
            "ConfigViewportsNoDecoration", "ConfigViewportsNoDefaultParent", "ConfigDockingNoSplit", "ConfigDockingNoDockingOver", "ConfigDockingWithShift",
            "ConfigDockingAlwaysTabBar", "ConfigDockingTransparentPayload", "ConfigMacOSXBehaviors", "ConfigNavMoveSetMousePos", "ConfigNavCaptureKeyboard",
            "ConfigInputTextCursorBlink", "ConfigWindowsResizeFromEdges", "ConfigWindowsMoveFromTitleBarOnly" }) do
            if io[n] == true then ImGui.Text("io.%s", n) end
        end
        if (io.ConfigMemoryCompactTimer or -1) >= 0.0 then ImGui.Text("io.ConfigMemoryCompactTimer = %.1f", io.ConfigMemoryCompactTimer) end
        ImGui.Text("io.BackendFlags: 0x%08X", io.BackendFlags)
        local BF = ImGuiBackendFlags
        for _, n in ipairs({ "HasGamepad", "HasMouseCursors", "HasSetMousePos", "PlatformHasViewports", "HasMouseHoveredViewport", "HasParentViewport",
            "RendererHasVtxOffset", "RendererHasTextures", "RendererHasViewports" }) do
            if BF[n] and bit32.band(io.BackendFlags, BF[n]) ~= 0 then ImGui.Text(" %s", n) end
        end
        ImGui.Separator()
        local atlas = io.Fonts
        ImGui.Text("io.Fonts: %d fonts, Flags: 0x%08X, TexSize: %d,%d", atlas.Fonts.Size, atlas.Flags or 0, atlas.TexData and atlas.TexData.Width or 0, atlas.TexData and atlas.TexData.Height or 0)
        ImGui.Text("io.Fonts->FontLoaderName: %s", atlas.FontLoaderName or "NULL")
        ImGui.Text("io.DisplaySize: %.2f,%.2f", io.DisplaySize.x, io.DisplaySize.y)
        ImGui.Text("io.DisplayFramebufferScale: %.2f,%.2f", io.DisplayFramebufferScale.x, io.DisplayFramebufferScale.y)
        ImGui.Separator()
        ImGui.Text("style.WindowPadding: %.2f,%.2f", style.WindowPadding.x, style.WindowPadding.y)
        ImGui.Text("style.WindowBorderSize: %.2f", style.WindowBorderSize)
        ImGui.Text("style.FramePadding: %.2f,%.2f", style.FramePadding.x, style.FramePadding.y)
        ImGui.Text("style.FrameRounding: %.2f", style.FrameRounding)
        ImGui.Text("style.FrameBorderSize: %.2f", style.FrameBorderSize)
        ImGui.Text("style.ItemSpacing: %.2f,%.2f", style.ItemSpacing.x, style.ItemSpacing.y)
        ImGui.Text("style.ItemInnerSpacing: %.2f,%.2f", style.ItemInnerSpacing.x, style.ItemInnerSpacing.y)
        if copy_to_clipboard then
            ImGui.LogText("\n```\n")
            ImGui.LogFinish()
        end
        ImGui.EndChild()
    end
    ImGui.End()
    return p_open
end
end --[[ About window ]]

return true
