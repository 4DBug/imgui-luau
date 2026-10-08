--- ImGui Sincerely WIP
-- (Demo Code) Port of imgui_demo.cpp (docking branch)
-- This file: shared demo helpers, ShowDemoWindow(), DemoWindowMenuBar(), DemoWindowWidgets() dispatcher, example tree/image viewer helpers.
-- Other parts (all global functions, loaded from the same bundle):
--   imgui_demo_w1.lua    : DemoWindowWidgets{Basic,Bullets,CollapsingHeaders,ColorAndPickers,ComboBoxes,DataTypes,...}
--   imgui_demo_w2.lua    : DemoWindowWidgets{QueryingStatuses,Selectables,SelectionAndMultiSelect}
--   imgui_demo_w3.lua    : DemoWindowWidgets{Tabs,Text,TextInput,Tooltips,TreeNodes,VerticalSliders}
--   imgui_demo_style.lua : ShowAboutWindow, ShowStyleEditor, ShowUserGuide, ShowExampleMenuFile, ...
--   imgui_demo_2.lua     : Layout, Popups, Tables, Columns, Inputs + example apps

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
    if not open then return false, open end
    local visible = ImGui.CollapsingHeader(label, open)
    -- ponytail: until CollapsingHeader(label, p_open) lands, a boolean 2nd arg is treated as flags=None by the library
    if type(visible) == "table" then visible = visible[1] end
    return visible, open
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
        local name_buf = string.format("%s %d", category_names[idx_L0 // (ROOT_ITEMS_COUNT // category_count) + 1], idx_L0 % (ROOT_ITEMS_COUNT // category_count))
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
            _, data.ShowAbout = ImGui.MenuItem("About ImGui Sincerely", nil, data.ShowAbout)

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
        data.ShowStyleEditor, visible = ImGui.Begin("ImGui Sincerely Style Editor", data.ShowStyleEditor)
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
    p_open, visible = ImGui.Begin("ImGui Sincerely Demo", p_open, window_flags)
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

    ImGui.Text("ImGui Sincerely says hello! (%s) (%d)", IMGUI_VERSION or "WIP", IMGUI_VERSION_NUM or 0)
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

return true -- [Roblox] ModuleScripts must return exactly one value
