-- dear imgui demo (Luau port of imgui_demo.cpp). Optional: the library never calls into this file.
-- dear imgui, v1.93.0 WIP
-- (demo code)

-- Help:
-- - Read FAQ at http://dearimgui.com/faq
-- - Call and read ImGui.ShowDemoWindow() in imgui_demo.cpp. All applications in examples/ are doing that.
-- - Need help integrating Dear ImGui in your codebase?
--   - Read Getting Started https://github.com/ocornut/imgui/wiki/Getting-Started
--   - Read 'Programmer guide' in imgui.cpp for notes on how to setup Dear ImGui in your codebase.
-- Read top of imgui.cpp and imgui.h for many details, documentation, comments, links.
-- Get the latest version at https://github.com/ocornut/imgui

-- How to easily locate code?
-- - Use Tools->Item Picker to debug break in code by clicking any widgets: https://github.com/ocornut/imgui/wiki/Debug-Tools
-- - Browse pthom's online imgui_explorer: web version the demo w/ source code browser: https://pthom.github.io/imgui_explorer
-- - Find a visible string and search for it in the code!

-----------------------------------------------------
-- PLEASE DO NOT REMOVE THIS FILE FROM YOUR PROJECT!
-----------------------------------------------------
-- Message to the person tempted to delete this file when integrating Dear ImGui into their codebase:
-- Think again! It is the most useful reference code that you and other coders will want to refer to and call.
-- Have the ImGui.ShowDemoWindow() function wired in an always-available debug menu of your game/app!
-- Also include Metrics! ItemPicker! DebugLog! and other debug features.
-- Removing this file from your project is hindering access to documentation for everyone in your team,
-- likely leading you to poorer usage of the library.
-- Everything in this file will be stripped out by the linker if you don't call ImGui.ShowDemoWindow().
-- If you want to link core Dear ImGui in your shipped builds but want a thorough guarantee that the demo will not be
-- linked, you can setup your imconfig.h with #define IMGUI_DISABLE_DEMO_WINDOWS and those functions will be empty.
-- [Port] There is no linker here: build the bundle with `tools/bundle.py --no-demo` to leave this file out.
-- In another situation, whenever you have Dear ImGui available you probably want this to be available for reference.
-- Thank you,
-- -Your beloved friend, imgui_demo.cpp (which you won't delete)

----------------------------------------------
-- ABOUT THE MEANING OF THE 'static' KEYWORD:
----------------------------------------------
-- In this demo code, we frequently use 'static' variables inside functions.
-- A static variable persists across calls. It is essentially a global variable but declared inside the scope of the function.
-- Think of "static int n = 0;" as "global int n = 0;" !
-- We do this IN THE DEMO because we want:
-- - to gather code and data in the same place.
-- - to make the demo source code faster to read, faster to change, smaller in size.
-- - it is also a convenient way of storing simple UI related information as long as your function
--   doesn't need to be reentrant or used in multiple threads.
-- This might be a pattern you will want to use in your code, but most of the data you would be working
-- with in a complex codebase is likely going to be stored outside your functions.
-- [Port] Lua has no function-level 'static': they are fields of the file-level table S (S.FunctionName.x).

-------------------------------------------
-- ABOUT THE CODING STYLE OF OUR DEMO CODE
-------------------------------------------
-- The Demo code in this file is designed to be easy to copy-and-paste into your application!
-- Because of this:
-- - We never omit the ImGui. prefix when calling functions, even though most code here is in the same namespace.
-- - We try to declare static variables in the local scope, as close as possible to the code using them.
-- - We never use any of the helpers/facilities used internally by Dear ImGui, unless available in the public API.
-- - We never use maths operators on ImVec2/ImVec4. For our other sources files we use them, and they are provided
--   by imgui.h using the IMGUI_DEFINE_MATH_OPERATORS define. For your own sources file they are optional
--   and require you either enable those, either provide your own via IM_VEC2_CLASS_EXTRA in imconfig.h.
--   Because we can't assume anything about your support of maths operators, we cannot use them in imgui_demo.cpp.

-- Navigating this file:
-- - In Visual Studio: Ctrl+Comma ("Edit.GoToAll") can follow symbols inside comments, whereas Ctrl+F12 ("Edit.GoToImplementation") cannot.
-- - In Visual Studio w/ Visual Assist installed: Alt+G ("VAssistX.GoToImplementation") can also follow symbols inside comments.
-- - In VS Code, CLion, etc.: Ctrl+Click can follow symbols inside comments.
-- - You can search/grep for all sections listed in the index to find the section.

--[[

Index of this file:

// [SECTION] Forward Declarations
// [SECTION] Helpers
// [SECTION] Demo Window / ShowDemoWindow()
// [SECTION] DemoWindowMenuBar()
// [SECTION] Helpers: ExampleTreeNode, ExampleMemberInfo (for use by Property Editor & Multi-Select demos)
// [SECTION] Helpers: ExampleImageViewer
// [SECTION] DemoWindowWidgetsBasic()
// [SECTION] DemoWindowWidgetsBullets()
// [SECTION] DemoWindowWidgetsCollapsingHeaders()
// [SECTION] DemoWindowWidgetsComboBoxes()
// [SECTION] DemoWindowWidgetsColorAndPickers()
// [SECTION] DemoWindowWidgetsDataTypes()
// [SECTION] DemoWindowWidgetsDisableBlocks()
// [SECTION] DemoWindowWidgetsDragAndDrop()
// [SECTION] DemoWindowWidgetsDragsAndSliders()
// [SECTION] DemoWindowWidgetsFonts()
// [SECTION] DemoWindowWidgetsImages()
// [SECTION] DemoWindowWidgetsListBoxes()
// [SECTION] DemoWindowWidgetsLiveEdit()
// [SECTION] DemoWindowWidgetsMixedValues()
// [SECTION] DemoWindowWidgetsMultiComponents()
// [SECTION] DemoWindowWidgetsPlotting()
// [SECTION] DemoWindowWidgetsProgressBars()
// [SECTION] DemoWindowWidgetsQueryingStatuses()
// [SECTION] DemoWindowWidgetsSelectables()
// [SECTION] DemoWindowWidgetsSelectionAndMultiSelect()
// [SECTION] DemoWindowWidgetsTabs()
// [SECTION] DemoWindowWidgetsText()
// [SECTION] DemoWindowWidgetsTextFilter()
// [SECTION] DemoWindowWidgetsTextInput()
// [SECTION] DemoWindowWidgetsTooltips()
// [SECTION] DemoWindowWidgetsTreeNodes()
// [SECTION] DemoWindowWidgetsVerticalSliders()
// [SECTION] DemoWindowWidgets()
// [SECTION] DemoWindowLayout()
// [SECTION] DemoWindowPopups()
// [SECTION] DemoWindowTables()
// [SECTION] DemoWindowInputs()
// [SECTION] About Window / ShowAboutWindow()
// [SECTION] Style Editor / ShowStyleEditor()
// [SECTION] User Guide / ShowUserGuide()
// [SECTION] Example App: Main Menu Bar / ShowExampleAppMainMenuBar()
// [SECTION] Example App: Debug Console / ShowExampleAppConsole()
// [SECTION] Example App: Image Viewer / ShowExampleAppImageViewer()
// [SECTION] Example App: Debug Log / ShowExampleAppLog()
// [SECTION] Example App: Simple Layout / ShowExampleAppLayout()
// [SECTION] Example App: Property Editor / ShowExampleAppPropertyEditor()
// [SECTION] Example App: Long Text / ShowExampleAppLongText()
// [SECTION] Example App: Auto Resize / ShowExampleAppAutoResize()
// [SECTION] Example App: Constrained Resize / ShowExampleAppConstrainedResize()
// [SECTION] Example App: Simple overlay / ShowExampleAppSimpleOverlay()
// [SECTION] Example App: Fullscreen window / ShowExampleAppFullscreen()
// [SECTION] Example App: Manipulating window titles / ShowExampleAppWindowTitles()
// [SECTION] Example App: Custom Rendering using ImDrawList API / ShowExampleAppCustomRendering()
// [SECTION] Example App: Docking, DockSpace / ShowExampleAppDockSpace()
// [SECTION] Example App: Documents Handling / ShowExampleAppDocuments()
// [SECTION] Example App: Assets Browser / ShowExampleAppAssetsBrowser()

]]

-- [Port] C includes, compiler warning pragmas, snprintf/PRId64/IMGUI_CDECL defines dropped (C only).

-- Play it nice with Windows users (Update: May 2018, Notepad now supports Unix-style carriage returns!)
-- [Port] IM_NEWLINE is always "\n" here.

-- Helpers macros
-- We normally try to not use many helpers in imgui_demo.cpp in order to make code easier to copy and paste,
-- but making an exception here as those are largely simplifying code...
-- In other imgui sources we can use nicer internal functions from imgui_internal.h (ImMin/ImMax) but not in the demo.
-- [Port] IM_MIN/IM_MAX/IM_CLAMP -> the library globals ImMin/ImMax/ImClamp.

-------------------------------------------------------------------------------
-- [SECTION] Forward Declarations
-------------------------------------------------------------------------------

-- Forward Declarations
-- [Port] Not needed in Lua (globals are resolved at call time). Upstream list kept for reference:
-- struct ImGuiDemoWindowData;
-- static void ShowExampleAppMainMenuBar();
-- static void ShowExampleAppAssetsBrowser(bool* p_open);
-- static void ShowExampleAppConsole(bool* p_open);
-- static void ShowExampleAppCustomRendering(bool* p_open);
-- static void ShowExampleAppDockSpace(bool* p_open);
-- static void ShowExampleAppDocuments(bool* p_open);
-- static void ShowExampleAppImageViewer(bool* p_open);
-- static void ShowExampleAppLog(bool* p_open);
-- static void ShowExampleAppLayout(bool* p_open);
-- static void ShowExampleAppPropertyEditor(bool* p_open, ImGuiDemoWindowData* demo_data);
-- static void ShowExampleAppSimpleOverlay(bool* p_open);
-- static void ShowExampleAppAutoResize(bool* p_open);
-- static void ShowExampleAppConstrainedResize(bool* p_open);
-- static void ShowExampleAppFullscreen(bool* p_open);
-- static void ShowExampleAppLongText(bool* p_open);
-- static void ShowExampleAppWindowTitles(bool* p_open);
-- static void ShowExampleMenuFile();

-- We split the contents of the big ShowDemoWindow() function into smaller functions
-- (because the link time of very large functions tends to grow non-linearly)
-- static void DemoWindowMenuBar(ImGuiDemoWindowData* demo_data);
-- static void DemoWindowWidgets(ImGuiDemoWindowData* demo_data);
-- static void DemoWindowLayout();
-- static void DemoWindowPopups();
-- static void DemoWindowTables();
-- static void DemoWindowColumns();
-- static void DemoWindowInputs();

-- Helper tree functions used by Property Editor & Multi-Select demos
-- struct ExampleTreeNode;
-- static ExampleTreeNode* ExampleTree_CreateNode(const char* name, int uid, ExampleTreeNode* parent);
-- static void             ExampleTree_DestroyNode(ExampleTreeNode* node);

-------------------------------------------------------------------------------
-- [SECTION] Helpers
-------------------------------------------------------------------------------

-- [Port] Storage for C++ function-level `static` variables: one sub-table per upstream function (S.FunctionName),
-- declared right above the function. Shared by every part of this file.
local S = {}
local _ -- [Port] discard target for unused return values (`_, v = ImGui.Checkbox(...)`)

-- Helper to display a little (?) mark which shows a tooltip when hovered.
-- In your own code you may want to display an actual icon if you are using a merged icon fonts (see docs/FONTS.md)
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

-- Helper to wire demo markers located in code to an interactive browser (e.g. https://pthom.github.io/imgui_explorer)
function IMGUI_DEMO_MARKER(section) end -- [Port] no ImGui.DemoMarker() hook in this port: no-op

-- Sneakily forward declare functions which aren't worth putting in public API yet
-- [Port] ImGui.ShowFontAtlas(atlas) and ImGui.TreeNodeSetOpen(storage_id, is_open) are already public here.

-------------------------------------------------------------------------------
-- [SECTION] Demo Window / ShowDemoWindow()
-------------------------------------------------------------------------------

-- Data to be shared across different functions of the demo.
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
        LiveEditFlags = ImGuiItemFlags.LiveEditOnInputText,
        DemoTree = nil,

        -- [Port] no destructor: DemoTree is garbage collected (upstream calls ExampleTree_DestroyNode(DemoTree)).
    }
end

S.ShowDemoWindow = {
    -- Stored data
    demo_data = ImGuiDemoWindowData(),

    -- Demonstrate the various window flags. Typically you would just use the default!
    no_titlebar = false,
    no_scrollbar = false,
    no_menu = false,
    no_move = false,
    no_resize = false,
    no_collapse = false,
    no_close = false,
    no_nav = false,
    no_background = false,
    no_bring_to_front = false,
    no_docking = false,
    unsaved_document = false,
}

-- Demonstrate most Dear ImGui features (this is big function!)
-- You may execute this function to experiment with the UI and understand what it does.
-- You may then search for keywords in the code when you are interested by a specific feature.
-- [Port] p_open: true/false/nil (nil = no close button). Returns the new p_open value.
function ImGui.ShowDemoWindow(p_open)
    local s = S.ShowDemoWindow

    -- Exceptionally add an extra assert here for people confused about initial Dear ImGui setup
    -- Most functions would normally just assert/crash if the context is missing.
    IM_ASSERT(ImGui.GetCurrentContext() ~= nil, "Missing Dear ImGui context. Refer to examples app!")

    -- Verify ABI compatibility between caller code and compiled version of Dear ImGui. This helps detects some build issues.
    -- [Port] IMGUI_CHECKVERSION() dropped: no ABI to verify.

    -- Stored data
    local demo_data = s.demo_data

    -- Examples Apps (accessible from the "Examples" menu)
    if demo_data.ShowMainMenuBar          then ShowExampleAppMainMenuBar() end
    if demo_data.ShowAppDockSpace         then demo_data.ShowAppDockSpace = ShowExampleAppDockSpace(demo_data.ShowAppDockSpace) end -- Important: Process the Docking app first, as explicit DockSpace() nodes needs to be submitted early (read comments near the DockSpace function)
    if demo_data.ShowAppDocuments         then demo_data.ShowAppDocuments = ShowExampleAppDocuments(demo_data.ShowAppDocuments) end -- ...process the Document app next, as it may also use a DockSpace()
    if demo_data.ShowAppAssetsBrowser     then demo_data.ShowAppAssetsBrowser = ShowExampleAppAssetsBrowser(demo_data.ShowAppAssetsBrowser) end
    if demo_data.ShowAppConsole           then demo_data.ShowAppConsole = ShowExampleAppConsole(demo_data.ShowAppConsole) end
    if demo_data.ShowAppCustomRendering   then demo_data.ShowAppCustomRendering = ShowExampleAppCustomRendering(demo_data.ShowAppCustomRendering) end
    if demo_data.ShowAppImageViewer       then demo_data.ShowAppImageViewer = ShowExampleAppImageViewer(demo_data.ShowAppImageViewer) end
    if demo_data.ShowAppLog               then demo_data.ShowAppLog = ShowExampleAppLog(demo_data.ShowAppLog) end
    if demo_data.ShowAppLayout            then demo_data.ShowAppLayout = ShowExampleAppLayout(demo_data.ShowAppLayout) end
    if demo_data.ShowAppPropertyEditor    then demo_data.ShowAppPropertyEditor = ShowExampleAppPropertyEditor(demo_data.ShowAppPropertyEditor, demo_data) end
    if demo_data.ShowAppSimpleOverlay     then demo_data.ShowAppSimpleOverlay = ShowExampleAppSimpleOverlay(demo_data.ShowAppSimpleOverlay) end
    if demo_data.ShowAppAutoResize        then demo_data.ShowAppAutoResize = ShowExampleAppAutoResize(demo_data.ShowAppAutoResize) end
    if demo_data.ShowAppConstrainedResize then demo_data.ShowAppConstrainedResize = ShowExampleAppConstrainedResize(demo_data.ShowAppConstrainedResize) end
    if demo_data.ShowAppFullscreen        then demo_data.ShowAppFullscreen = ShowExampleAppFullscreen(demo_data.ShowAppFullscreen) end
    if demo_data.ShowAppLongText          then demo_data.ShowAppLongText = ShowExampleAppLongText(demo_data.ShowAppLongText) end
    if demo_data.ShowAppWindowTitles      then demo_data.ShowAppWindowTitles = ShowExampleAppWindowTitles(demo_data.ShowAppWindowTitles) end

    -- Dear ImGui Tools (accessible from the "Tools" menu)
    if demo_data.ShowMetrics              then demo_data.ShowMetrics = ImGui.ShowMetricsWindow(demo_data.ShowMetrics) end
    if demo_data.ShowDebugLog             then demo_data.ShowDebugLog = ImGui.ShowDebugLogWindow(demo_data.ShowDebugLog) end
    if demo_data.ShowIDStackTool          then demo_data.ShowIDStackTool = ImGui.ShowIDStackToolWindow(demo_data.ShowIDStackTool) end
    if demo_data.ShowAbout                then demo_data.ShowAbout = ImGui.ShowAboutWindow(demo_data.ShowAbout) end
    if demo_data.ShowStyleEditor then
        demo_data.ShowStyleEditor = ImGui.Begin("Dear ImGui Style Editor", demo_data.ShowStyleEditor)
        ImGui.ShowStyleEditor()
        ImGui.End()
    end

    -- Demonstrate the various window flags. Typically you would just use the default!
    local window_flags = 0
    if s.no_titlebar        then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoTitleBar) end
    if s.no_scrollbar       then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoScrollbar) end
    if not s.no_menu        then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.MenuBar) end
    if s.no_move            then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoMove) end
    if s.no_resize          then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoResize) end
    if s.no_collapse        then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoCollapse) end
    if s.no_nav             then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoNav) end
    if s.no_background      then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoBackground) end
    if s.no_bring_to_front  then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoBringToFrontOnFocus) end
    if s.no_docking         then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoDocking) end
    if s.unsaved_document   then window_flags = bit32.bor(window_flags, ImGuiWindowFlags.UnsavedDocument) end
    local begin_p_open = p_open -- [Port] keep the caller's value intact when not passed to Begin()
    if s.no_close           then begin_p_open = nil end -- Don't pass our bool* to Begin

    -- We specify a default position/size in case there's no data in the .ini file.
    -- We only do it to make the demo applications a little more welcoming, but typically this isn't required.
    local main_viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(ImVec2(main_viewport.WorkPos.x + 650, main_viewport.WorkPos.y + 20), ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(ImVec2(550, 680), ImGuiCond.FirstUseEver)

    -- Main body of the Demo window starts here.
    local open, visible = ImGui.Begin("Dear ImGui Demo", begin_p_open, window_flags)
    if begin_p_open ~= nil then p_open = open end -- [Port] write back the bool* output
    if not visible then
        -- Early out if the window is collapsed, as an optimization.
        ImGui.End()
        return p_open
    end

    -- Most framed widgets share a common width settings. Remaining width is used for the label.
    -- The width of the frame may be changed with PushItemWidth() or SetNextItemWidth().
    -- - Positive value for absolute size, negative value for right-alignment.
    -- - The default value is about GetWindowWidth() * 0.65f.
    -- - See 'Demo->Layout->Widgets Width' for details.
    -- Here we change the frame width based on how much width we want to give to the label.
    local label_width_base = ImGui.GetFontSize() * 12               -- Some amount of width for label, based on font size.
    local label_width_max = ImGui.GetContentRegionAvail().x * 0.40  -- ...but always leave some room for framed widgets.
    local label_width = ImMin(label_width_base, label_width_max)
    ImGui.PushItemWidth(-label_width)                               -- Right-align: framed items will leave 'label_width' available for the label.
    --ImGui.PushItemWidth(ImGui.GetContentRegionAvail().x * 0.40)   -- e.g. Use 40% width for framed widgets, leaving 60% width for labels.
    --ImGui.PushItemWidth(-ImGui.GetContentRegionAvail().x * 0.40)  -- e.g. Use 40% width for labels, leaving 60% width for framed widgets.
    --ImGui.PushItemWidth(ImGui.GetFontSize() * -12)                -- e.g. Use XXX width for labels, leaving the rest for framed widgets.

    -- Menu Bar
    DemoWindowMenuBar(demo_data)

    ImGui.Text("dear imgui says hello! (%s) (%d)", IMGUI_VERSION, IMGUI_VERSION_NUM)
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
        ImGui.BulletText("See the ShowDemoWindow() code in imgui_demo.cpp. <- you are here!")
        ImGui.BulletText("See comments in imgui.cpp.")
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
        local io = ImGui.GetIO()

        if ImGui.TreeNode("Configuration##2") then
            IMGUI_DEMO_MARKER("Configuration")
            ImGui.SeparatorText("General")
            _, io.ConfigFlags = ImGui.CheckboxFlags("io.ConfigFlags: NavEnableKeyboard",    io.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard)
            ImGui.SameLine(); HelpMarker("Enable keyboard controls.")
            _, io.ConfigFlags = ImGui.CheckboxFlags("io.ConfigFlags: NavEnableGamepad",     io.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad)
            ImGui.SameLine(); HelpMarker("Enable gamepad controls. Require backend to set io.BackendFlags |= ImGuiBackendFlags_HasGamepad.\n\nRead instructions in imgui.cpp for details.")
            _, io.ConfigFlags = ImGui.CheckboxFlags("io.ConfigFlags: NoMouse",              io.ConfigFlags, ImGuiConfigFlags.NoMouse)
            ImGui.SameLine(); HelpMarker("Instruct dear imgui to disable mouse inputs and interactions.")

            -- The "NoMouse" option can get us stuck with a disabled mouse! Let's provide an alternative way to fix it:
            if bit32.band(io.ConfigFlags, ImGuiConfigFlags.NoMouse) ~= 0 then
                if math.fmod(ImGui.GetTime(), 0.40) < 0.20 then
                    ImGui.SameLine()
                    ImGui.Text("<<PRESS SPACE TO DISABLE>>")
                end
                -- Prevent both being checked
                if ImGui.IsKeyPressed(ImGuiKey.Space) or bit32.band(io.ConfigFlags, ImGuiConfigFlags.NoKeyboard) ~= 0 then
                    io.ConfigFlags = bit32.band(io.ConfigFlags, bit32.bnot(ImGuiConfigFlags.NoMouse))
                end
            end

            _, io.ConfigFlags = ImGui.CheckboxFlags("io.ConfigFlags: NoMouseCursorChange",  io.ConfigFlags, ImGuiConfigFlags.NoMouseCursorChange)
            ImGui.SameLine(); HelpMarker("Instruct backend to not alter mouse cursor shape and visibility.")
            _, io.ConfigFlags = ImGui.CheckboxFlags("io.ConfigFlags: NoKeyboard", io.ConfigFlags, ImGuiConfigFlags.NoKeyboard)
            ImGui.SameLine(); HelpMarker("Instruct dear imgui to disable keyboard inputs and interactions.")

            _, io.ConfigInputTrickleEventQueue = ImGui.Checkbox("io.ConfigInputTrickleEventQueue", io.ConfigInputTrickleEventQueue)
            ImGui.SameLine(); HelpMarker("Enable input queue trickling: some types of events submitted during the same frame (e.g. button down + up) will be spread over multiple frames, improving interactions with low framerates.")
            _, io.MouseDrawCursor = ImGui.Checkbox("io.MouseDrawCursor", io.MouseDrawCursor)
            ImGui.SameLine(); HelpMarker("Instruct Dear ImGui to render a mouse cursor itself. Note that a mouse cursor rendered via your application GPU rendering path will feel more laggy than hardware cursor, but will be more in sync with your other visuals.\n\nSome desktop applications may use both kinds of cursors (e.g. enable software cursor only when resizing/dragging something).")

            ImGui.SeparatorText("Keyboard/Gamepad Navigation")
            _, io.ConfigNavSwapGamepadButtons = ImGui.Checkbox("io.ConfigNavSwapGamepadButtons", io.ConfigNavSwapGamepadButtons)
            _, io.ConfigNavMoveSetMousePos = ImGui.Checkbox("io.ConfigNavMoveSetMousePos", io.ConfigNavMoveSetMousePos)
            ImGui.SameLine(); HelpMarker("Directional/tabbing navigation teleports the mouse cursor. May be useful on TV/console systems where moving a virtual mouse is difficult")
            _, io.ConfigNavCaptureKeyboard = ImGui.Checkbox("io.ConfigNavCaptureKeyboard", io.ConfigNavCaptureKeyboard)
            _, io.ConfigNavEscapeClearFocusItem = ImGui.Checkbox("io.ConfigNavEscapeClearFocusItem", io.ConfigNavEscapeClearFocusItem)
            ImGui.SameLine(); HelpMarker("Pressing Escape clears focused item.")
            _, io.ConfigNavEscapeClearFocusWindow = ImGui.Checkbox("io.ConfigNavEscapeClearFocusWindow", io.ConfigNavEscapeClearFocusWindow)
            ImGui.SameLine(); HelpMarker("Pressing Escape clears focused window.")
            _, io.ConfigNavCursorVisibleAuto = ImGui.Checkbox("io.ConfigNavCursorVisibleAuto", io.ConfigNavCursorVisibleAuto)
            ImGui.SameLine(); HelpMarker("Using directional navigation key makes the cursor visible. Mouse click hides the cursor.")
            _, io.ConfigNavCursorVisibleAlways = ImGui.Checkbox("io.ConfigNavCursorVisibleAlways", io.ConfigNavCursorVisibleAlways)
            ImGui.SameLine(); HelpMarker("Navigation cursor is always visible.")

            ImGui.SeparatorText("Docking")
            _, io.ConfigFlags = ImGui.CheckboxFlags("io.ConfigFlags: DockingEnable", io.ConfigFlags, ImGuiConfigFlags.DockingEnable)
            ImGui.SameLine()
            if io.ConfigDockingWithShift then
                HelpMarker("Drag from window title bar or their tab to dock/undock. Hold SHIFT to enable docking.\n\nDrag from window menu button (upper-left button) to undock an entire node (all windows).")
            else
                HelpMarker("Drag from window title bar or their tab to dock/undock. Hold SHIFT to disable docking.\n\nDrag from window menu button (upper-left button) to undock an entire node (all windows).")
            end
            if bit32.band(io.ConfigFlags, ImGuiConfigFlags.DockingEnable) ~= 0 then
                ImGui.Indent()
                _, io.ConfigDockingNoSplit = ImGui.Checkbox("io.ConfigDockingNoSplit", io.ConfigDockingNoSplit)
                ImGui.SameLine(); HelpMarker("Simplified docking mode: disable window splitting, so docking is limited to merging multiple windows together into tab-bars.")
                _, io.ConfigDockingNoDockingOver = ImGui.Checkbox("io.ConfigDockingNoDockingOver", io.ConfigDockingNoDockingOver)
                ImGui.SameLine(); HelpMarker("Simplified docking mode: disable window merging into a same tab-bar, so docking is limited to splitting windows.")
                _, io.ConfigDockingWithShift = ImGui.Checkbox("io.ConfigDockingWithShift", io.ConfigDockingWithShift)
                ImGui.SameLine(); HelpMarker("Enable docking when holding Shift only (allow to drop in wider space, reduce visual noise)")
                _, io.ConfigDockingAlwaysTabBar = ImGui.Checkbox("io.ConfigDockingAlwaysTabBar", io.ConfigDockingAlwaysTabBar)
                ImGui.SameLine(); HelpMarker("Create a docking node and tab-bar on single floating windows.")
                _, io.ConfigDockingTransparentPayload = ImGui.Checkbox("io.ConfigDockingTransparentPayload", io.ConfigDockingTransparentPayload)
                ImGui.SameLine(); HelpMarker("Make window or viewport transparent when docking and only display docking boxes on the target viewport. Useful if rendering of multiple viewport cannot be synced. Best used with ConfigViewportsNoAutoMerge.")
                ImGui.Unindent()
            end

            ImGui.SeparatorText("Multi-viewports")
            _, io.ConfigFlags = ImGui.CheckboxFlags("io.ConfigFlags: ViewportsEnable", io.ConfigFlags, ImGuiConfigFlags.ViewportsEnable)
            ImGui.SameLine(); HelpMarker("[beta] Enable beta multi-viewports support. See ImGuiPlatformIO for details.")
            if bit32.band(io.ConfigFlags, ImGuiConfigFlags.ViewportsEnable) ~= 0 then
                ImGui.Indent()
                _, io.ConfigViewportsNoAutoMerge = ImGui.Checkbox("io.ConfigViewportsNoAutoMerge", io.ConfigViewportsNoAutoMerge)
                ImGui.SameLine(); HelpMarker("Set to make all floating imgui windows always create their own viewport. Otherwise, they are merged into the main host viewports when overlapping it.")
                _, io.ConfigViewportsNoTaskBarIcon = ImGui.Checkbox("io.ConfigViewportsNoTaskBarIcon", io.ConfigViewportsNoTaskBarIcon)
                ImGui.SameLine(); HelpMarker("(note: some platform backends may not reflect a change of this value for existing viewports, and may need the viewport to be recreated)")
                _, io.ConfigViewportsNoDecoration = ImGui.Checkbox("io.ConfigViewportsNoDecoration", io.ConfigViewportsNoDecoration)
                ImGui.SameLine(); HelpMarker("(note: some platform backends may not reflect a change of this value for existing viewports, and may need the viewport to be recreated)")
                _, io.ConfigViewportsNoDefaultParent = ImGui.Checkbox("io.ConfigViewportsNoDefaultParent", io.ConfigViewportsNoDefaultParent)
                ImGui.SameLine(); HelpMarker("(note: some platform backends may not reflect a change of this value for existing viewports, and may need the viewport to be recreated)")
                _, io.ConfigViewportsPlatformFocusSetsImGuiFocus = ImGui.Checkbox("io.ConfigViewportsPlatformFocusSetsImGuiFocus", io.ConfigViewportsPlatformFocusSetsImGuiFocus)
                ImGui.SameLine(); HelpMarker("When a platform window is focused (e.g. using Alt+Tab, clicking Platform Title Bar), apply corresponding focus on imgui windows (may clear focus/active id from imgui windows location in other platform windows). In principle this is better enabled but we provide an opt-out, because some Linux window managers tend to eagerly focus windows (e.g. on mouse hover, or even a simple window pos/size change).")
                ImGui.Unindent()
            end

            --ImGui.SeparatorText("DPI/Scaling")
            --_, io.ConfigDpiScaleFonts = ImGui.Checkbox("io.ConfigDpiScaleFonts", io.ConfigDpiScaleFonts)
            --ImGui.SameLine(); HelpMarker("Experimental: Automatically update style.FontScaleDpi when Monitor DPI changes. This will scale fonts but NOT style sizes/padding for now.")
            --_, io.ConfigDpiScaleViewports = ImGui.Checkbox("io.ConfigDpiScaleViewports", io.ConfigDpiScaleViewports)
            --ImGui.SameLine(); HelpMarker("Experimental: Scale Dear ImGui and Platform Windows when Monitor DPI changes.")

            ImGui.SeparatorText("Windows")
            _, io.ConfigWindowsResizeFromEdges = ImGui.Checkbox("io.ConfigWindowsResizeFromEdges", io.ConfigWindowsResizeFromEdges)
            ImGui.SameLine(); HelpMarker("Enable resizing of windows from their edges and from the lower-left corner.\nThis requires ImGuiBackendFlags_HasMouseCursors for better mouse cursor feedback.")
            _, io.ConfigWindowsMoveFromTitleBarOnly = ImGui.Checkbox("io.ConfigWindowsMoveFromTitleBarOnly", io.ConfigWindowsMoveFromTitleBarOnly)
            _, io.ConfigWindowsCopyContentsWithCtrlC = ImGui.Checkbox("io.ConfigWindowsCopyContentsWithCtrlC", io.ConfigWindowsCopyContentsWithCtrlC) -- [EXPERIMENTAL]
            ImGui.SameLine(); HelpMarker("*EXPERIMENTAL* Ctrl+C copy the contents of focused window into the clipboard.\n\nExperimental because:\n- (1) has known issues with nested Begin/End pairs.\n- (2) text output quality varies.\n- (3) text output is in submission order rather than spatial order.")
            _, io.ConfigScrollbarScrollByPage = ImGui.Checkbox("io.ConfigScrollbarScrollByPage", io.ConfigScrollbarScrollByPage)
            ImGui.SameLine(); HelpMarker("Enable scrolling page by page when clicking outside the scrollbar grab.\nWhen disabled, always scroll to clicked location.\nWhen enabled, Shift+Click scrolls to clicked location.")

            ImGui.SeparatorText("Widgets")
            _, io.ConfigInputTextCursorBlink = ImGui.Checkbox("io.ConfigInputTextCursorBlink", io.ConfigInputTextCursorBlink)
            ImGui.SameLine(); HelpMarker("Enable blinking cursor (optional as some users consider it to be distracting).")
            _, io.ConfigInputTextEnterKeepActive = ImGui.Checkbox("io.ConfigInputTextEnterKeepActive", io.ConfigInputTextEnterKeepActive)
            ImGui.SameLine(); HelpMarker("Pressing Enter will reactivate item and select all text (single-line only).")
            _, io.ConfigDragClickToInputText = ImGui.Checkbox("io.ConfigDragClickToInputText", io.ConfigDragClickToInputText)
            ImGui.SameLine(); HelpMarker("Enable turning DragXXX widgets into text input with a simple mouse click-release (without moving).")
            _, io.ConfigMacOSXBehaviors = ImGui.Checkbox("io.ConfigMacOSXBehaviors", io.ConfigMacOSXBehaviors)
            ImGui.SameLine(); HelpMarker("Swap Cmd<>Ctrl keys, enable various MacOS style behaviors.")
            ImGui.Text("Also see Style->Rendering for rendering options.")

            ImGui.SeparatorText("Settings")
            _, io.ConfigIniSettingsSaveLastUsedDate = ImGui.Checkbox("io.ConfigIniSettingsSaveLastUsedDate", io.ConfigIniSettingsSaveLastUsedDate)

            -- Also read: https://github.com/ocornut/imgui/wiki/Error-Handling
            ImGui.SeparatorText("Error Handling")

            _, io.ConfigErrorRecovery = ImGui.Checkbox("io.ConfigErrorRecovery", io.ConfigErrorRecovery)
            ImGui.SameLine(); HelpMarker(
                "Options to configure how we handle recoverable errors.\n" ..
                "- Error recovery is not perfect nor guaranteed! It is a feature to ease development.\n" ..
                "- You not are not supposed to rely on it in the course of a normal application run.\n" ..
                "- Possible usage: facilitate recovery from errors triggered from a scripting language or after specific exceptions handlers.\n" ..
                "- Always ensure that on programmers seat you have at minimum Asserts or Tooltips enabled when making direct imgui API call! " ..
                "Otherwise it would severely hinder your ability to catch and correct mistakes!")
            _, io.ConfigErrorRecoveryEnableAssert = ImGui.Checkbox("io.ConfigErrorRecoveryEnableAssert", io.ConfigErrorRecoveryEnableAssert)
            _, io.ConfigErrorRecoveryEnableDebugLog = ImGui.Checkbox("io.ConfigErrorRecoveryEnableDebugLog", io.ConfigErrorRecoveryEnableDebugLog)
            _, io.ConfigErrorRecoveryEnableTooltip = ImGui.Checkbox("io.ConfigErrorRecoveryEnableTooltip", io.ConfigErrorRecoveryEnableTooltip)
            if not io.ConfigErrorRecoveryEnableAssert and not io.ConfigErrorRecoveryEnableDebugLog and not io.ConfigErrorRecoveryEnableTooltip then
                io.ConfigErrorRecoveryEnableAssert = true; io.ConfigErrorRecoveryEnableDebugLog = true; io.ConfigErrorRecoveryEnableTooltip = true
            end

            -- Also read: https://github.com/ocornut/imgui/wiki/Debug-Tools
            ImGui.SeparatorText("Debug")
            _, io.ConfigDebugIsDebuggerPresent = ImGui.Checkbox("io.ConfigDebugIsDebuggerPresent", io.ConfigDebugIsDebuggerPresent)
            ImGui.SameLine(); HelpMarker("Enable various tools calling IM_DEBUG_BREAK().\n\nRequires a debugger being attached, otherwise IM_DEBUG_BREAK() options will appear to crash your application.")
            _, io.ConfigDebugHighlightIdConflicts = ImGui.Checkbox("io.ConfigDebugHighlightIdConflicts", io.ConfigDebugHighlightIdConflicts)
            ImGui.SameLine(); HelpMarker("Highlight and show an error message when multiple items have conflicting identifiers.")
            ImGui.BeginDisabled()
            _, io.ConfigDebugBeginReturnValueOnce = ImGui.Checkbox("io.ConfigDebugBeginReturnValueOnce", io.ConfigDebugBeginReturnValueOnce)
            ImGui.EndDisabled()
            ImGui.SameLine(); HelpMarker("First calls to Begin()/BeginChild() will return false.\n\nTHIS OPTION IS DISABLED because it needs to be set at application boot-time to make sense. Showing the disabled option is a way to make this feature easier to discover.")
            _, io.ConfigDebugBeginReturnValueLoop = ImGui.Checkbox("io.ConfigDebugBeginReturnValueLoop", io.ConfigDebugBeginReturnValueLoop)
            ImGui.SameLine(); HelpMarker("Some calls to Begin()/BeginChild() will return false.\n\nWill cycle through window depths then repeat. Windows should be flickering while running.")
            _, io.ConfigDebugIgnoreFocusLoss = ImGui.Checkbox("io.ConfigDebugIgnoreFocusLoss", io.ConfigDebugIgnoreFocusLoss)
            ImGui.SameLine(); HelpMarker("Option to deactivate io.AddFocusEvent(false) handling. May facilitate interactions with a debugger when focus loss leads to clearing inputs data.")
            _, io.ConfigDebugDrawListDefaultsToStrokeLegacy = ImGui.Checkbox("io.ConfigDebugDrawListDefaultsToStrokeLegacy", io.ConfigDebugDrawListDefaultsToStrokeLegacy)
            ImGui.SameLine(); HelpMarker("Option to default all ImDrawList to ImDrawFlags_StrokeLegacy mode, mimicking pre-1.93.0 rendering.")
            _, io.ConfigDebugIniSettings = ImGui.Checkbox("io.ConfigDebugIniSettings", io.ConfigDebugIniSettings)
            ImGui.SameLine(); HelpMarker("Option to save .ini data with extra comments (particularly helpful for Docking, but makes saving slower).")

            ImGui.TreePop()
            ImGui.Spacing()
        end

        if ImGui.TreeNode("Backend Flags") then
            IMGUI_DEMO_MARKER("Configuration/Backend Flags")
            HelpMarker(
                "Those flags are set by the backends (imgui_impl_xxx files) to specify their capabilities.\n" ..
                "Here we expose them as read-only fields to avoid breaking interactions with your backend.")

            -- Make a local copy to avoid modifying actual backend flags.
            -- FIXME: Maybe we need a BeginReadonly() equivalent to keep label bright?
            ImGui.BeginDisabled()
            _, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: HasGamepad",             io.BackendFlags, ImGuiBackendFlags.HasGamepad)
            _, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: HasMouseCursors",        io.BackendFlags, ImGuiBackendFlags.HasMouseCursors)
            _, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: HasSetMousePos",         io.BackendFlags, ImGuiBackendFlags.HasSetMousePos)
            _, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: PlatformHasViewports",   io.BackendFlags, ImGuiBackendFlags.PlatformHasViewports)
            _, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: HasMouseHoveredViewport",io.BackendFlags, ImGuiBackendFlags.HasMouseHoveredViewport)
            _, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: HasParentViewport",      io.BackendFlags, ImGuiBackendFlags.HasParentViewport)
            _, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: RendererHasVtxOffset",   io.BackendFlags, ImGuiBackendFlags.RendererHasVtxOffset)
            _, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: RendererHasTextures",    io.BackendFlags, ImGuiBackendFlags.RendererHasTextures)
            _, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: RendererHasViewports",   io.BackendFlags, ImGuiBackendFlags.RendererHasViewports)
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
            ImGui.LogButtons()

            HelpMarker("You can also call ImGui::LogText() to output directly to the log without a visual output.")
            if ImGui.Button("Copy \"Hello, world!\" to clipboard") then
                ImGui.LogToClipboard()
                ImGui.LogText("Hello, world!")
                ImGui.LogFinish()
            end
            ImGui.TreePop()
        end
    end

    if ImGui.CollapsingHeader("Window options") then
        IMGUI_DEMO_MARKER("Window options")
        if ImGui.BeginTable("split", 3) then
            ImGui.TableNextColumn(); _, s.no_titlebar = ImGui.Checkbox("No titlebar", s.no_titlebar)
            ImGui.TableNextColumn(); _, s.no_scrollbar = ImGui.Checkbox("No scrollbar", s.no_scrollbar)
            ImGui.TableNextColumn(); _, s.no_menu = ImGui.Checkbox("No menu", s.no_menu)
            ImGui.TableNextColumn(); _, s.no_move = ImGui.Checkbox("No move", s.no_move)
            ImGui.TableNextColumn(); _, s.no_resize = ImGui.Checkbox("No resize", s.no_resize)
            ImGui.TableNextColumn(); _, s.no_collapse = ImGui.Checkbox("No collapse", s.no_collapse)
            ImGui.TableNextColumn(); _, s.no_close = ImGui.Checkbox("No close", s.no_close)
            ImGui.TableNextColumn(); _, s.no_nav = ImGui.Checkbox("No nav", s.no_nav)
            ImGui.TableNextColumn(); _, s.no_background = ImGui.Checkbox("No background", s.no_background)
            ImGui.TableNextColumn(); _, s.no_bring_to_front = ImGui.Checkbox("No bring to front", s.no_bring_to_front)
            ImGui.TableNextColumn(); _, s.no_docking = ImGui.Checkbox("No docking", s.no_docking)
            ImGui.TableNextColumn(); _, s.unsaved_document = ImGui.Checkbox("Unsaved document", s.unsaved_document)
            ImGui.EndTable()
        end
    end

    -- All demo contents
    DemoWindowWidgets(demo_data)
    DemoWindowLayout()
    DemoWindowPopups()
    DemoWindowTables()
    DemoWindowInputs()

    -- End of ShowDemoWindow()
    ImGui.PopItemWidth()
    ImGui.End()
    return p_open
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowMenuBar()
-------------------------------------------------------------------------------

function DemoWindowMenuBar(demo_data)
    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu("Menu") then
            IMGUI_DEMO_MARKER("Menu/File")
            ShowExampleMenuFile()
            ImGui.EndMenu()
        end
        if ImGui.BeginMenu("Examples") then
            IMGUI_DEMO_MARKER("Menu/Examples")
            _, demo_data.ShowMainMenuBar = ImGui.MenuItem("Main menu bar", nil, demo_data.ShowMainMenuBar)

            ImGui.SeparatorText("Mini apps")
            _, demo_data.ShowAppAssetsBrowser = ImGui.MenuItem("Assets Browser", nil, demo_data.ShowAppAssetsBrowser)
            _, demo_data.ShowAppConsole = ImGui.MenuItem("Console", nil, demo_data.ShowAppConsole)
            _, demo_data.ShowAppCustomRendering = ImGui.MenuItem("Custom rendering", nil, demo_data.ShowAppCustomRendering)
            _, demo_data.ShowAppDocuments = ImGui.MenuItem("Documents", nil, demo_data.ShowAppDocuments)
            _, demo_data.ShowAppDockSpace = ImGui.MenuItem("Dockspace", nil, demo_data.ShowAppDockSpace)
            _, demo_data.ShowAppImageViewer = ImGui.MenuItem("Image Viewer", nil, demo_data.ShowAppImageViewer)
            _, demo_data.ShowAppLog = ImGui.MenuItem("Log", nil, demo_data.ShowAppLog)
            _, demo_data.ShowAppPropertyEditor = ImGui.MenuItem("Property editor", nil, demo_data.ShowAppPropertyEditor)
            _, demo_data.ShowAppLayout = ImGui.MenuItem("Simple layout", nil, demo_data.ShowAppLayout)
            _, demo_data.ShowAppSimpleOverlay = ImGui.MenuItem("Simple overlay", nil, demo_data.ShowAppSimpleOverlay)

            ImGui.SeparatorText("Concepts")
            _, demo_data.ShowAppAutoResize = ImGui.MenuItem("Auto-resizing window", nil, demo_data.ShowAppAutoResize)
            _, demo_data.ShowAppConstrainedResize = ImGui.MenuItem("Constrained-resizing window", nil, demo_data.ShowAppConstrainedResize)
            _, demo_data.ShowAppFullscreen = ImGui.MenuItem("Fullscreen window", nil, demo_data.ShowAppFullscreen)
            _, demo_data.ShowAppLongText = ImGui.MenuItem("Long text display", nil, demo_data.ShowAppLongText)
            _, demo_data.ShowAppWindowTitles = ImGui.MenuItem("Manipulating window titles", nil, demo_data.ShowAppWindowTitles)

            ImGui.EndMenu()
        end
        --if ImGui.MenuItem("MenuItem") then end -- You can also use MenuItem() inside a menu bar!
        if ImGui.BeginMenu("Tools") then
            IMGUI_DEMO_MARKER("Menu/Tools")
            local io = ImGui.GetIO()
            local has_debug_tools = true -- [Port] IMGUI_DISABLE_DEBUG_TOOLS is never defined here
            _, demo_data.ShowMetrics = ImGui.MenuItem("Metrics/Debugger", nil, demo_data.ShowMetrics, has_debug_tools)
            if ImGui.BeginMenu("Debug Options") then
                ImGui.BeginDisabled(not has_debug_tools)
                _, io.ConfigDebugHighlightIdConflicts = ImGui.Checkbox("Highlight ID Conflicts", io.ConfigDebugHighlightIdConflicts)
                ImGui.EndDisabled()
                _, io.ConfigErrorRecoveryEnableAssert = ImGui.Checkbox("Assert on error recovery", io.ConfigErrorRecoveryEnableAssert)
                ImGui.TextDisabled("(see Demo->Configuration for more)")
                ImGui.EndMenu()
            end
            _, demo_data.ShowDebugLog = ImGui.MenuItem("Debug Log", nil, demo_data.ShowDebugLog, has_debug_tools)
            _, demo_data.ShowIDStackTool = ImGui.MenuItem("ID Stack Tool", nil, demo_data.ShowIDStackTool, has_debug_tools)
            local is_debugger_present = io.ConfigDebugIsDebuggerPresent
            local has_item_picker = ImGui.DebugStartItemPicker ~= nil -- [Port] ImGui.DebugStartItemPicker() is not ported yet: menu item disabled until it is
            if ImGui.MenuItem("Item Picker", nil, false, has_debug_tools and has_item_picker) then -- and is_debugger_present
                ImGui.DebugStartItemPicker()
            end
            if not is_debugger_present then
                ImGui.SetItemTooltip("Requires io.ConfigDebugIsDebuggerPresent=true to be set.\n\nWe otherwise disable some extra features to avoid casual users crashing the application.")
            end
            _, demo_data.ShowStyleEditor = ImGui.MenuItem("Style Editor", nil, demo_data.ShowStyleEditor)
            _, demo_data.ShowAbout = ImGui.MenuItem("About Dear ImGui", nil, demo_data.ShowAbout)

            ImGui.EndMenu()
        end
        ImGui.EndMenuBar()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] Helpers: ExampleTreeNode, ExampleMemberInfo (for use by Property Editor & Multi-Select demos)
-------------------------------------------------------------------------------

-- Simple representation for a tree
-- (this is designed to be simple to understand for our demos, not to be fancy or efficient etc.)
function ExampleTreeNode()
    return {
        -- Tree structure
        Name = "",              -- [Port] Lua string (upstream char Name[28]), max 27 bytes
        UID = 0,
        Parent = nil,
        Childs = {},            -- [Port] plain 1-based Lua array (upstream ImVector<ExampleTreeNode*>): #Childs, Childs[n + 1]
        IndexInParent = 0,      -- Maintaining this allows us to implement linear traversal more easily (0-based)

        -- Leaf Data
        HasData = false,        -- All leaves have data
        DataMyBool = true,
        DataMyInt = 128,
        DataMyVec2 = ImVec2(0.0, 3.141592),
    }
end

-- Simple representation of struct metadata/serialization data.
-- (this is a minimal version of what a typical advanced application may provide)
function ExampleMemberInfo(name, data_type, data_count, offset)
    return {
        Name = name,            -- Member name
        DataType = data_type,   -- Member type
        DataCount = data_count, -- Member count (1 when scalar)
        Offset = offset,        -- Offset inside parent structure -- [Port] field key in the node table (no offsetof)
    }
end

-- Metadata description of ExampleTreeNode struct.
ExampleTreeNodeMemberInfos =
{
    ExampleMemberInfo("MyName",     ImGuiDataType.String,  1, "Name"),
    ExampleMemberInfo("MyBool",     ImGuiDataType.Bool,    1, "DataMyBool"),
    ExampleMemberInfo("MyInt",      ImGuiDataType.S32,     1, "DataMyInt"),
    ExampleMemberInfo("MyVec2",     ImGuiDataType.Float,   2, "DataMyVec2"),
}

function ExampleTree_CreateNode(name, uid, parent)
    local node = ExampleTreeNode()
    node.Name = string.sub(name, 1, 27) -- [Port] snprintf() into char[28]
    node.UID = uid
    node.Parent = parent
    node.IndexInParent = parent and #parent.Childs or 0
    if parent then
        parent.Childs[#parent.Childs + 1] = node
    end
    return node
end

function ExampleTree_DestroyNode(node)
    for _, child_node in ipairs(node.Childs) do
        ExampleTree_DestroyNode(child_node)
    end
    -- [Port] IM_DELETE(node): nothing to do, garbage collected
end

S.ExampleTree_CreateDemoTree = {
    category_names = { "Apple", "Banana", "Cherry", "Kiwi", "Mango", "Orange", "Pear", "Pineapple", "Strawberry", "Watermelon" },
}

-- Create example tree data
-- (warning: this can allocates MANY MANY more times than other code in all of Dear ImGui + demo combined)
-- (a real application managing one million nodes would likely store its tree data differently)
function ExampleTree_CreateDemoTree()
    local s = S.ExampleTree_CreateDemoTree

    --     20 root nodes ->    211 total nodes,   ~261 allocs.
    --   1000 root nodes ->   ~11K total nodes,   ~14K allocs.
    --  10000 root nodes ->  ~123K total nodes,  ~154K allocs.
    -- 100000 root nodes -> ~1338K total nodes, ~1666K allocs.
    local ROOT_ITEMS_COUNT = 20

    local category_names = s.category_names
    local category_count = #category_names
    local name_buf -- [Port] Lua string, truncated to sizeof(ExampleTreeNode::Name) by ExampleTree_CreateNode()
    local uid = 0
    uid = uid + 1
    local node_L0 = ExampleTree_CreateNode("<ROOT>", uid, nil)
    for idx_L0 = 0, ROOT_ITEMS_COUNT - 1 do
        name_buf = string.format("%s %d", category_names[math.floor(idx_L0 / math.floor(ROOT_ITEMS_COUNT / category_count)) + 1], idx_L0 % math.floor(ROOT_ITEMS_COUNT / category_count))
        uid = uid + 1
        local node_L1 = ExampleTree_CreateNode(name_buf, uid, node_L0)
        local number_of_childs = #node_L1.Name
        for idx_L1 = 0, number_of_childs - 1 do
            name_buf = string.format("Child %d", idx_L1)
            uid = uid + 1
            local node_L2 = ExampleTree_CreateNode(name_buf, uid, node_L1)
            node_L2.HasData = true
            if idx_L1 == 0 then
                name_buf = string.format("Sub-child %d", 0)
                uid = uid + 1
                local node_L3 = ExampleTree_CreateNode(name_buf, uid, node_L2)
                node_L3.HasData = true
            end
        end
    end
    return node_L0
end

-------------------------------------------------------------------------------
-- [SECTION] Helpers: ExampleImageViewer
-------------------------------------------------------------------------------

function ExampleImageViewerData()
    return {
        ImageBgColor = IM_COL32(100, 100, 100, 255),
        GridColor = IM_COL32(255, 255, 255, 100),
        GridEnabled = true,
        ViewReset = true,
        ViewOffset = ImVec2(0.0, 0.0), -- in image space
        Zoom = 10.0,
        ZoomMin = 1.0,
        ZoomMax = 10000.0,
    }
end

function ExampleImageViewer_DrawOptions(data)
    ImGui.SetNextItemShortcut(ImGuiKey.G, ImGuiInputFlags.Tooltip) -- | ImGuiInputFlags.RouteGlobal
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
            data.Zoom = ImClamp(data.Zoom * (1.0 + io.MouseWheel * 0.10), data.ZoomMin, data.ZoomMax)
        end
    end
    local zoom = data.Zoom -- (float)(int)ViewZoom;
    if ImGui.IsItemActive() and ImGui.IsMouseDragging(0) then
        data.ViewOffset.x = data.ViewOffset.x - io.MouseDelta.x / zoom
        data.ViewOffset.y = data.ViewOffset.y - io.MouseDelta.y / zoom
    end

    -- Display image
    local image_min, image_max = ImVec2(), ImVec2()
    image_min.x = ImTrunc((canvas_min.x - (data.ViewOffset.x * zoom)) + (canvas_size.x * 0.5))
    image_min.y = ImTrunc((canvas_min.y - (data.ViewOffset.y * zoom)) + (canvas_size.y * 0.5))
    image_max.x = ImTrunc(image_min.x + image_w * zoom)
    image_max.y = ImTrunc(image_min.y + image_h * zoom)
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
        for px = ImTrunc((canvas_min.x - image_min.x) / step), ImTrunc((canvas_max.x - image_min.x) / step) do
            draw_list:AddLineV(image_min.x + px * step, canvas_min.y, canvas_max.y, data.GridColor, 1.0)
        end
        for py = ImTrunc((canvas_min.y - image_min.y) / step), ImTrunc((canvas_max.y - image_min.y) / step) do
            draw_list:AddLineH(canvas_min.x, canvas_max.x, image_min.y + py * step, data.GridColor, 1.0)
        end
    end
    draw_list:PopClipRect()
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsBasic()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsBasic = {
    clicked = 0,
    check = true,
    e = 0,
    counter = 0,
    inputs = {
        str0 = ImGui.NewTextBuffer("Hello, world!", 128),
        str1 = ImGui.NewTextBuffer("", 128),
        i0 = 123,
        f0 = 0.001,
        d0 = 999999.00000001,
        f1 = 1.e10,
        vec4a = { 0.10, 0.20, 0.30, 0.44 },
    },
    drags = { i1 = 50, i2 = 42, i3 = 128, f1 = 1.00, f2 = 0.0067 },
    sliders = { i1 = 0, f1 = 0.123, f2 = 0.0, angle = 0.0, elem = 0 },
    pickers = { col1 = { 1.0, 0.0, 0.2 }, col2 = { 0.4, 0.7, 0.0, 0.5 } },
    combo = { item_current = 0 },
    listbox = { item_current = 1 },
}

function DemoWindowWidgetsBasic()
    local _
    if ImGui.TreeNode("Basic") then
        local s = S.DemoWindowWidgetsBasic
        IMGUI_DEMO_MARKER("Widgets/Basic")
        ImGui.SeparatorText("General")

        IMGUI_DEMO_MARKER("Widgets/Basic/Button")
        if ImGui.Button("Button") then
            s.clicked = s.clicked + 1
        end
        if bit32.band(s.clicked, 1) ~= 0 then
            ImGui.SameLine()
            ImGui.Text("Thanks for clicking me!")
        end

        IMGUI_DEMO_MARKER("Widgets/Basic/Checkbox")
        _, s.check = ImGui.Checkbox("checkbox", s.check)

        IMGUI_DEMO_MARKER("Widgets/Basic/RadioButton")
        _, s.e = ImGui.RadioButton("radio a", s.e, 0); ImGui.SameLine()
        _, s.e = ImGui.RadioButton("radio b", s.e, 1); ImGui.SameLine()
        _, s.e = ImGui.RadioButton("radio c", s.e, 2)

        ImGui.AlignTextToFramePadding()
        ImGui.TextLinkOpenURL("Hyperlink", "https://github.com/ocornut/imgui/wiki/Error-Handling")

        -- Color buttons, demonstrate using PushID() to add unique identifier in the ID stack, and changing style.
        IMGUI_DEMO_MARKER("Widgets/Basic/Buttons (Colored)")
        for i = 0, 6 do
            if i > 0 then
                ImGui.SameLine()
            end
            ImGui.PushID(i)
            ImGui.PushStyleColor(ImGuiCol.Button, ImColor.HSV(i / 7.0, 0.6, 0.6).Value)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImColor.HSV(i / 7.0, 0.7, 0.7).Value)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImColor.HSV(i / 7.0, 0.8, 0.8).Value)
            ImGui.Button("Click")
            ImGui.PopStyleColor(3)
            ImGui.PopID()
        end

        -- Use AlignTextToFramePadding() to align text baseline to the baseline of framed widgets elements
        -- (otherwise a Text+SameLine+Button sequence will have the text a little too high by default!)
        -- See 'Demo->Layout->Text Baseline Alignment' for details.
        ImGui.AlignTextToFramePadding()
        ImGui.Text("Hold to repeat:")
        ImGui.SameLine()

        -- Arrow buttons with Repeater
        IMGUI_DEMO_MARKER("Widgets/Basic/Buttons (Repeating)")
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

        do
            local s = S.DemoWindowWidgetsBasic.inputs
            -- If you want to use InputText() with std::string or any custom dynamic string type:
            -- - For std::string: use the wrapper in misc/cpp/imgui_stdlib.h/.cpp
            -- - Otherwise, see the 'Dear ImGui Demo->Widgets->Text Input->Resize Callback' for using ImGuiInputTextFlags_CallbackResize.
            IMGUI_DEMO_MARKER("Widgets/Basic/InputText")
            ImGui.InputText("input text", s.str0, 128)
            ImGui.SameLine(); HelpMarker(
                "USER:\n" ..
                "Hold Shift or use mouse to select text.\n" ..
                "Ctrl+Left/Right to word jump.\n" ..
                "Ctrl+A or Double-Click to select all.\n" ..
                "Ctrl+X,Ctrl+C,Ctrl+V for clipboard.\n" ..
                "Ctrl+Z to undo, Ctrl+Y/Ctrl+Shift+Z to redo.\n" ..
                "Escape to revert.\n\n" ..
                "PROGRAMMER:\n" ..
                "You can use the ImGuiInputTextFlags_CallbackResize facility if you need to wire InputText() " ..
                "to a dynamic string type. See misc/cpp/imgui_stdlib.h for an example (this is not demonstrated " ..
                "in imgui_demo.cpp).")

            ImGui.InputTextWithHint("input text (w/ hint)", "enter text here", s.str1, 128)

            IMGUI_DEMO_MARKER("Widgets/Basic/InputInt, InputFloat")
            s.i0 = ImGui.InputInt("input int", s.i0)

            s.f0 = ImGui.InputFloat("input float", s.f0, 0.01, 1.0, "%.3f")

            s.d0 = ImGui.InputDouble("input double", s.d0, 0.01, 1.0, "%.8f")

            s.f1 = ImGui.InputFloat("input scientific", s.f1, 0.0, 0.0, "%e")
            ImGui.SameLine(); HelpMarker(
                "You can input value using the scientific notation,\n" ..
                "  e.g. \"1e+8\" becomes \"100000000\".")

            ImGui.InputFloat3("input float3", s.vec4a)
        end

        ImGui.SeparatorText("Drags")

        do
            local s = S.DemoWindowWidgetsBasic.drags
            IMGUI_DEMO_MARKER("Widgets/Basic/DragInt, DragFloat")
            s.i1 = ImGui.DragInt("drag int", s.i1, 1)
            ImGui.SameLine(); HelpMarker(
                "Click and drag to edit value.\n" ..
                "Hold Shift/Alt for faster/slower edit.\n" ..
                "Double-Click or Ctrl+Click to input value.")
            s.i2 = ImGui.DragInt("drag int 0..100", s.i2, 1, 0, 100, "%d%%", ImGuiSliderFlags.AlwaysClamp)
            s.i3 = ImGui.DragInt("drag int wrap 100..200", s.i3, 1, 100, 200, "%d", ImGuiSliderFlags.WrapAround)

            s.f1 = ImGui.DragFloat("drag float", s.f1, 0.005)
            s.f2 = ImGui.DragFloat("drag small float", s.f2, 0.0001, 0.0, 0.0, "%.06f ns")
            --ImGui.DragFloat("drag wrap -1..1", f3, 0.005, -1.0, 1.0, nil, ImGuiSliderFlags.WrapAround)
        end

        ImGui.SeparatorText("Sliders")

        do
            local s = S.DemoWindowWidgetsBasic.sliders
            IMGUI_DEMO_MARKER("Widgets/Basic/SliderInt, SliderFloat")
            s.i1 = ImGui.SliderInt("slider int", s.i1, -1, 3)
            ImGui.SameLine(); HelpMarker("Ctrl+Click to input value.")

            s.f1 = ImGui.SliderFloat("slider float", s.f1, 0.0, 1.0, "ratio = %.3f")
            s.f2 = ImGui.SliderFloat("slider float (log)", s.f2, -10.0, 10.0, "%.4f", ImGuiSliderFlags.Logarithmic)

            IMGUI_DEMO_MARKER("Widgets/Basic/SliderAngle")
            s.angle = ImGui.SliderAngle("slider angle", s.angle)

            -- Using the format string to display a name instead of an integer.
            -- Here we completely omit '%d' from the format string, so it'll only display a name.
            -- This technique can also be used with DragInt().
            IMGUI_DEMO_MARKER("Widgets/Basic/Slider (enum)")
            local Element_Fire, Element_Earth, Element_Air, Element_Water, Element_COUNT = 0, 1, 2, 3, 4
            local elems_names = { "Fire", "Earth", "Air", "Water" }
            local elem_name = (s.elem >= 0 and s.elem < Element_COUNT) and elems_names[s.elem + 1] or "Unknown"
            s.elem = ImGui.SliderInt("slider enum", s.elem, 0, Element_COUNT - 1, elem_name) -- Use ImGuiSliderFlags_NoInput flag to disable Ctrl+Click here.
            ImGui.SameLine(); HelpMarker("Using the format string parameter to display a name instead of the underlying integer.")
        end

        ImGui.SeparatorText("Selectors/Pickers")

        do
            local s = S.DemoWindowWidgetsBasic.pickers
            IMGUI_DEMO_MARKER("Widgets/Basic/ColorEdit3, ColorEdit4")
            ImGui.ColorEdit3("color 1", s.col1)
            ImGui.SameLine(); HelpMarker(
                "Click on the color square to open a color picker.\n" ..
                "Click and hold to use drag and drop.\n" ..
                "Right-Click on the color square to show options.\n" ..
                "Ctrl+Click on individual component to input value.\n")

            ImGui.ColorEdit4("color 2", s.col2)
        end

        do
            local s = S.DemoWindowWidgetsBasic.combo
            -- Using the _simplified_ one-liner Combo() api here
            -- See "Combo" section for examples of how to use the more flexible BeginCombo()/EndCombo() api.
            IMGUI_DEMO_MARKER("Widgets/Basic/Combo")
            local items = { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIIIIII", "JJJJ", "KKKKKKK" }
            s.item_current = ImGui.Combo("combo", s.item_current, items, #items)
            ImGui.SameLine(); HelpMarker(
                "Using the simplified one-liner Combo API here.\n" ..
                "Refer to the \"Combo\" section below for an explanation of how to use the more flexible and general BeginCombo/EndCombo API.")
        end

        do
            local s = S.DemoWindowWidgetsBasic.listbox
            -- Using the _simplified_ one-liner ListBox() api here
            -- See "List boxes" section for examples of how to use the more flexible BeginListBox()/EndListBox() api.
            IMGUI_DEMO_MARKER("Widgets/Basic/ListBox")
            local items = { "Apple", "Banana", "Cherry", "Kiwi", "Mango", "Orange", "Pineapple", "Strawberry", "Watermelon" }
            s.item_current = ImGui.ListBox("listbox", s.item_current, items, #items, 4)
            ImGui.SameLine(); HelpMarker(
                "Using the simplified one-liner ListBox API here.\n" ..
                "Refer to the \"List boxes\" section below for an explanation of how to use the more flexible and general BeginListBox/EndListBox API.")
        end

        -- Testing ImGuiOnceUponAFrame helper.
        --static ImGuiOnceUponAFrame once;
        --for (int i = 0; i < 5; i++)
        --    if (once)
        --        ImGui.Text("This will be displayed only once.");

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsBullets()
-------------------------------------------------------------------------------

function DemoWindowWidgetsBullets()
    if ImGui.TreeNode("Bullets") then
        IMGUI_DEMO_MARKER("Widgets/Bullets")
        ImGui.BulletText("Bullet point 1")
        ImGui.BulletText("Bullet point 2\nOn multiple lines")
        if ImGui.TreeNode("Tree node") then
            ImGui.BulletText("Another bullet point")
            ImGui.TreePop()
        end
        ImGui.Bullet(); ImGui.Text("Bullet point 3 (two calls)")
        ImGui.Bullet(); ImGui.SmallButton("Button")
        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsCollapsingHeaders()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsCollapsingHeaders = {
    closable_group = true,
}

function DemoWindowWidgetsCollapsingHeaders()
    local _
    if ImGui.TreeNode("Collapsing Headers") then
        local s = S.DemoWindowWidgetsCollapsingHeaders
        IMGUI_DEMO_MARKER("Widgets/Collapsing Headers")
        _, s.closable_group = ImGui.Checkbox("Show 2nd header", s.closable_group)
        if ImGui.CollapsingHeader("Header", ImGuiTreeNodeFlags.None) then
            ImGui.Text("IsItemHovered: %d", ImGui.IsItemHovered() and 1 or 0)
            for i = 0, 4 do
                ImGui.Text("Some content %d", i)
            end
        end
        local open
        open, s.closable_group = ImGui.CollapsingHeader("Header with a close button", s.closable_group)
        if open then
            ImGui.Text("IsItemHovered: %d", ImGui.IsItemHovered() and 1 or 0)
            for i = 0, 4 do
                ImGui.Text("More content %d", i)
            end
        end
        --[[
        if ImGui.CollapsingHeader("Header with a bullet", ImGuiTreeNodeFlags.Bullet) then
            ImGui.Text("IsItemHovered: %d", ImGui.IsItemHovered())
        end
        ]]
        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsColorAndPickers()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsColorAndPickers = {
    color = ImVec4(114.0 / 255.0, 144.0 / 255.0, 154.0 / 255.0, 200.0 / 255.0),
    base_flags = ImGuiColorEditFlags.None,
    saved_palette_init = true,
    saved_palette = {}, -- 32 x ImVec4, 1-based
    backup_color = ImVec4(),
    no_border = false,
    ref_color = false,
    ref_color_v = ImVec4(1.0, 0.0, 1.0, 0.5),
    picker_mode = 0,
    display_mode = 0,
    color_picker_flags = ImGuiColorEditFlags.AlphaBar,
    color_hsv = ImVec4(0.23, 1.0, 1.0, 1.0), -- Stored as HSV!
}

function DemoWindowWidgetsColorAndPickers()
    local _
    if ImGui.TreeNode("Color/Picker Widgets") then
        local s = S.DemoWindowWidgetsColorAndPickers
        IMGUI_DEMO_MARKER("Widgets/Color")
        local color = s.color

        ImGui.SeparatorText("Options")
        _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoAlpha", s.base_flags, ImGuiColorEditFlags.NoAlpha)
        _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaOpaque", s.base_flags, ImGuiColorEditFlags.AlphaOpaque)
        _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaNoBg", s.base_flags, ImGuiColorEditFlags.AlphaNoBg)
        _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaPreviewHalf", s.base_flags, ImGuiColorEditFlags.AlphaPreviewHalf)
        _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoOptions", s.base_flags, ImGuiColorEditFlags.NoOptions); ImGui.SameLine(); HelpMarker("Right-click on the individual color widget to show options.")
        _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoDragDrop", s.base_flags, ImGuiColorEditFlags.NoDragDrop)
        _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoColorMarkers", s.base_flags, ImGuiColorEditFlags.NoColorMarkers)
        _, s.base_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_HDR", s.base_flags, ImGuiColorEditFlags.HDR); ImGui.SameLine(); HelpMarker("Currently all this does is to lift the 0..1 limits on dragging widgets.")
        local base_flags = s.base_flags

        IMGUI_DEMO_MARKER("Widgets/Color/ColorEdit")
        ImGui.SeparatorText("Inline color editor")
        ImGui.Text("Color widget:")
        ImGui.SameLine(); HelpMarker(
            "Click on the color square to open a color picker.\n" ..
            "Ctrl+Click on individual component to input value.\n")
        ImGui.ColorEdit3("MyColor##1", color, base_flags)

        IMGUI_DEMO_MARKER("Widgets/Color/ColorEdit (HSV, with Alpha)")
        ImGui.Text("Color widget HSV with Alpha:")
        ImGui.ColorEdit4("MyColor##2", color, bit32.bor(ImGuiColorEditFlags.DisplayHSV, base_flags))

        IMGUI_DEMO_MARKER("Widgets/Color/ColorEdit (float display)")
        ImGui.Text("Color widget with Float Display:")
        ImGui.ColorEdit4("MyColor##2f", color, bit32.bor(ImGuiColorEditFlags.Float, base_flags))

        IMGUI_DEMO_MARKER("Widgets/Color/ColorButton (with Picker)")
        ImGui.Text("Color button with Picker:")
        ImGui.SameLine(); HelpMarker(
            "With the ImGuiColorEditFlags_NoInputs flag you can hide all the slider/text inputs.\n" ..
            "With the ImGuiColorEditFlags_NoLabel flag you can pass a non-empty label which will only " ..
            "be used for the tooltip and picker popup.")
        ImGui.ColorEdit4("MyColor##3", color, bit32.bor(ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.NoLabel, base_flags))

        IMGUI_DEMO_MARKER("Widgets/Color/ColorButton (with custom Picker popup)")
        ImGui.Text("Color button with Custom Picker Popup:")

        -- Generate a default palette. The palette will persist and can be edited.
        local saved_palette = s.saved_palette
        if s.saved_palette_init then
            for n = 0, 32 - 1 do
                saved_palette[n + 1] = ImVec4()
                saved_palette[n + 1].x, saved_palette[n + 1].y, saved_palette[n + 1].z = ImGui.ColorConvertHSVtoRGB(n / 31.0, 0.8, 0.8)
                saved_palette[n + 1].w = 1.0 -- Alpha
            end
            s.saved_palette_init = false
        end

        local open_popup = ImGui.ColorButton("MyColor##3b", color, base_flags)
        ImGui.SameLine(0, ImGui.GetStyle().ItemInnerSpacing.x)
        open_popup = ImGui.Button("Palette") or open_popup
        if open_popup then
            ImGui.OpenPopup("mypicker")
            ImVec4_Copy(s.backup_color, color)
        end
        if ImGui.BeginPopup("mypicker") then
            ImGui.Text("MY CUSTOM COLOR PICKER WITH AN AMAZING PALETTE!")
            ImGui.Separator()
            ImGui.ColorPicker4("##picker", color, bit32.bor(base_flags, ImGuiColorEditFlags.NoSidePreview, ImGuiColorEditFlags.NoSmallPreview))
            ImGui.SameLine()

            ImGui.BeginGroup() -- Lock X position
            ImGui.Text("Current")
            ImGui.ColorButton("##current", color, bit32.bor(ImGuiColorEditFlags.NoPicker, ImGuiColorEditFlags.AlphaPreviewHalf), ImVec2(60, 40))
            ImGui.Text("Previous")
            if ImGui.ColorButton("##previous", s.backup_color, bit32.bor(ImGuiColorEditFlags.NoPicker, ImGuiColorEditFlags.AlphaPreviewHalf), ImVec2(60, 40)) then
                ImVec4_Copy(color, s.backup_color)
            end
            ImGui.Separator()
            ImGui.Text("Palette")
            for n = 0, #saved_palette - 1 do
                ImGui.PushID(n)
                if (n % 8) ~= 0 then
                    ImGui.SameLine(0.0, ImGui.GetStyle().ItemSpacing.y)
                end

                local palette_button_flags = bit32.bor(ImGuiColorEditFlags.NoAlpha, ImGuiColorEditFlags.NoPicker, ImGuiColorEditFlags.NoTooltip)
                if ImGui.ColorButton("##palette", saved_palette[n + 1], palette_button_flags, ImVec2(20, 20)) then
                    color.x, color.y, color.z = saved_palette[n + 1].x, saved_palette[n + 1].y, saved_palette[n + 1].z -- Preserve alpha!
                end

                -- Allow user to drop colors into each palette entry. Note that ColorButton() is already a
                -- drag source by default, unless specifying the ImGuiColorEditFlags_NoDragDrop flag.
                if ImGui.BeginDragDropTarget() then
                    local payload = ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_3F)
                    if payload then
                        local d = payload.Data -- [Port] memcpy -> copy components (Data is a 1-based float array)
                        saved_palette[n + 1].x, saved_palette[n + 1].y, saved_palette[n + 1].z = d[1], d[2], d[3]
                    end
                    payload = ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_4F)
                    if payload then
                        local d = payload.Data -- [Port] memcpy -> copy components
                        saved_palette[n + 1].x, saved_palette[n + 1].y, saved_palette[n + 1].z, saved_palette[n + 1].w = d[1], d[2], d[3], d[4]
                    end
                    ImGui.EndDragDropTarget()
                end

                ImGui.PopID()
            end
            ImGui.EndGroup()
            ImGui.EndPopup()
        end

        IMGUI_DEMO_MARKER("Widgets/Color/ColorButton (simple)")
        ImGui.Text("Color button only:")
        _, s.no_border = ImGui.Checkbox("ImGuiColorEditFlags_NoBorder", s.no_border)
        ImGui.ColorButton("MyColor##3c", color, bit32.bor(base_flags, s.no_border and ImGuiColorEditFlags.NoBorder or 0), ImVec2(80, 80))

        IMGUI_DEMO_MARKER("Widgets/Color/ColorPicker")
        ImGui.SeparatorText("Color picker")

        ImGui.PushID("Color picker")
        _, s.color_picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoAlpha", s.color_picker_flags, ImGuiColorEditFlags.NoAlpha)
        _, s.color_picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_AlphaBar", s.color_picker_flags, ImGuiColorEditFlags.AlphaBar)
        _, s.color_picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_NoSidePreview", s.color_picker_flags, ImGuiColorEditFlags.NoSidePreview)
        if bit32.band(s.color_picker_flags, ImGuiColorEditFlags.NoSidePreview) ~= 0 then
            ImGui.SameLine()
            _, s.ref_color = ImGui.Checkbox("With Ref Color", s.ref_color)
            if s.ref_color then
                ImGui.SameLine()
                ImGui.ColorEdit4("##RefColor", s.ref_color_v, bit32.bor(ImGuiColorEditFlags.NoInputs, base_flags))
            end
        end
        _, s.color_picker_flags = ImGui.CheckboxFlags("ImGuiColorEditFlags_PickerNoRotate", s.color_picker_flags, ImGuiColorEditFlags.PickerNoRotate)

        s.picker_mode = ImGui.Combo("Picker Mode", s.picker_mode, "Auto/Current\0ImGuiColorEditFlags_PickerHueBar\0ImGuiColorEditFlags_PickerHueWheel\0")
        ImGui.SameLine(); HelpMarker("When not specified explicitly, user can right-click the picker to change mode.")

        s.display_mode = ImGui.Combo("Display Mode", s.display_mode, "Auto/Current\0ImGuiColorEditFlags_NoInputs\0ImGuiColorEditFlags_DisplayRGB\0ImGuiColorEditFlags_DisplayHSV\0ImGuiColorEditFlags_DisplayHex\0")
        ImGui.SameLine(); HelpMarker(
            "ColorEdit defaults to displaying RGB inputs if you don't specify a display mode, " ..
            "but the user can change it with a right-click on those inputs.\n\nColorPicker defaults to displaying RGB+HSV+Hex " ..
            "if you don't specify a display mode.\n\nYou can change the defaults using io.ConfigColorEditFlags.")

        local flags = bit32.bor(base_flags, s.color_picker_flags)
        if s.picker_mode == 1 then  flags = bit32.bor(flags, ImGuiColorEditFlags.PickerHueBar) end
        if s.picker_mode == 2 then  flags = bit32.bor(flags, ImGuiColorEditFlags.PickerHueWheel) end
        if s.display_mode == 1 then flags = bit32.bor(flags, ImGuiColorEditFlags.NoInputs) end       -- Disable all RGB/HSV/Hex displays
        if s.display_mode == 2 then flags = bit32.bor(flags, ImGuiColorEditFlags.DisplayRGB) end     -- Override display mode
        if s.display_mode == 3 then flags = bit32.bor(flags, ImGuiColorEditFlags.DisplayHSV) end
        if s.display_mode == 4 then flags = bit32.bor(flags, ImGuiColorEditFlags.DisplayHex) end
        ImGui.ColorPicker4("MyColor##4", color, flags, s.ref_color and s.ref_color_v or nil)

        ImGui.Text("Set defaults in code:")
        ImGui.SameLine(); HelpMarker(
            "io.ConfigColorEditFlags is designed to allow you to set boot-time default.\n" ..
            "We don't have Push/Pop functions because you can force options on a per-widget basis if needed, " ..
            "and the user can change non-forced ones with the options menu.\nWe don't have a getter to avoid " ..
            "encouraging you to persistently save values that aren't forward-compatible.")
        if ImGui.Button("Overwrite default: Uint8 + HSV + Hue Bar") then
            ImGui.GetIO().ConfigColorEditFlags = bit32.bor(ImGuiColorEditFlags.Uint8, ImGuiColorEditFlags.DisplayHSV, ImGuiColorEditFlags.PickerHueBar, ImGuiColorEditFlags.InputRGB) -- [Port] + InputRGB: without it ColorEdit4's InputMask_ power-of-two assert trips
        end
        if ImGui.Button("Overwrite default: Float + HDR + Hue Wheel") then
            ImGui.GetIO().ConfigColorEditFlags = bit32.bor(ImGuiColorEditFlags.Float, ImGuiColorEditFlags.HDR, ImGuiColorEditFlags.PickerHueWheel, ImGuiColorEditFlags.DisplayRGB, ImGuiColorEditFlags.InputRGB) -- [Port] + DisplayRGB + InputRGB: same asserts (DisplayMask_/InputMask_)
        end

        -- Always display a small version of both types of pickers
        -- (that's in order to make it more visible in the demo to people who are skimming quickly through it)
        ImGui.Text("Both types:")
        local w = (ImGui.GetContentRegionAvail().x - ImGui.GetStyle().ItemSpacing.y) * 0.40
        ImGui.SetNextItemWidth(w)
        ImGui.ColorPicker3("##MyColor##5", color, bit32.bor(ImGuiColorEditFlags.PickerHueBar, ImGuiColorEditFlags.NoSidePreview, ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.NoAlpha))
        ImGui.SameLine()
        ImGui.SetNextItemWidth(w)
        ImGui.ColorPicker3("##MyColor##6", color, bit32.bor(ImGuiColorEditFlags.PickerHueWheel, ImGuiColorEditFlags.NoSidePreview, ImGuiColorEditFlags.NoInputs, ImGuiColorEditFlags.NoAlpha))
        ImGui.PopID()

        -- HSV encoded support (to avoid RGB<>HSV round trips and singularities when S==0 or V==0)
        local color_hsv = s.color_hsv -- Stored as HSV!
        ImGui.Spacing()
        ImGui.Text("HSV encoded colors")
        ImGui.SameLine(); HelpMarker(
            "By default, colors are given to ColorEdit and ColorPicker in RGB, but ImGuiColorEditFlags_InputHSV " ..
            "allows you to store colors as HSV and pass them to ColorEdit and ColorPicker as HSV. This comes with the " ..
            "added benefit that you can manipulate hue values with the picker even when saturation or value are zero.")
        ImGui.Text("Color widget with InputHSV:")
        ImGui.ColorEdit4("HSV shown as RGB##1", color_hsv, bit32.bor(ImGuiColorEditFlags.DisplayRGB, ImGuiColorEditFlags.InputHSV, ImGuiColorEditFlags.Float))
        ImGui.ColorEdit4("HSV shown as HSV##1", color_hsv, bit32.bor(ImGuiColorEditFlags.DisplayHSV, ImGuiColorEditFlags.InputHSV, ImGuiColorEditFlags.Float))
        ImGui.DragFloat4("Raw HSV values", color_hsv, 0.01, 0.0, 1.0)

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsComboBoxes()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsComboBoxes = {
    flags = 0,
    item_selected_idx = 0, -- Here we store our selection data as an index.
    filter = nil, -- ImGuiTextFilter, created lazily
    item_current_2 = 0,
    item_current_3 = -1, -- If the selection isn't within 0..count, Combo won't display a preview
    item_current_4 = 0,
}

function DemoWindowWidgetsComboBoxes()
    local _, pressed
    if ImGui.TreeNode("Combo") then
        local s = S.DemoWindowWidgetsComboBoxes
        IMGUI_DEMO_MARKER("Widgets/Combo")
        -- Combo Boxes are also called "Dropdown" in other systems
        -- Expose flags as checkbox for the demo
        _, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_PopupAlignLeft", s.flags, ImGuiComboFlags.PopupAlignLeft)
        ImGui.SameLine(); HelpMarker("Only makes a difference if the popup is larger than the combo")
        pressed, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_NoArrowButton", s.flags, ImGuiComboFlags.NoArrowButton)
        if pressed then
            s.flags = bit32.band(s.flags, bit32.bnot(ImGuiComboFlags.NoPreview))     -- Clear incompatible flags
        end
        pressed, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_NoPreview", s.flags, ImGuiComboFlags.NoPreview)
        if pressed then
            s.flags = bit32.band(s.flags, bit32.bnot(bit32.bor(ImGuiComboFlags.NoArrowButton, ImGuiComboFlags.WidthFitPreview))) -- Clear incompatible flags
        end
        pressed, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_WidthFitPreview", s.flags, ImGuiComboFlags.WidthFitPreview)
        if pressed then
            s.flags = bit32.band(s.flags, bit32.bnot(ImGuiComboFlags.NoPreview))
        end

        -- Override default popup height
        pressed, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_HeightSmall", s.flags, ImGuiComboFlags.HeightSmall)
        if pressed then
            s.flags = bit32.band(s.flags, bit32.bnot(bit32.band(ImGuiComboFlags.HeightMask_, bit32.bnot(ImGuiComboFlags.HeightSmall))))
        end
        pressed, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_HeightRegular", s.flags, ImGuiComboFlags.HeightRegular)
        if pressed then
            s.flags = bit32.band(s.flags, bit32.bnot(bit32.band(ImGuiComboFlags.HeightMask_, bit32.bnot(ImGuiComboFlags.HeightRegular))))
        end
        pressed, s.flags = ImGui.CheckboxFlags("ImGuiComboFlags_HeightLargest", s.flags, ImGuiComboFlags.HeightLargest)
        if pressed then
            s.flags = bit32.band(s.flags, bit32.bnot(bit32.band(ImGuiComboFlags.HeightMask_, bit32.bnot(ImGuiComboFlags.HeightLargest))))
        end

        -- Using the generic BeginCombo() API, you have full control over how to display the combo contents.
        -- (your selection data could be an index, a pointer to the object, an id for the object, a flag intrusively
        -- stored in the object itself, etc.)
        local items = { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIII", "JJJJ", "KKKK", "LLLLLLL", "MMMM", "OOOOOOO" }

        -- Pass in the preview value visible before opening the combo (it could technically be different contents or not pulled from items[])
        local combo_preview_value = items[s.item_selected_idx + 1]
        if ImGui.BeginCombo("combo 1", combo_preview_value, s.flags) then
            for n = 0, #items - 1 do
                local is_selected = (s.item_selected_idx == n)
                if ImGui.Selectable(items[n + 1], is_selected) then
                    s.item_selected_idx = n
                end

                -- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
                if is_selected then
                    ImGui.SetItemDefaultFocus()
                end
            end
            ImGui.EndCombo()
        end

        -- Show case embedding a filter using a simple trick: displaying the filter inside combo contents.
        -- See https://github.com/ocornut/imgui/issues/718 for advanced/esoteric alternatives.
        if ImGui.BeginCombo("combo 2 (w/ filter)", combo_preview_value, s.flags) then
            if s.filter == nil then s.filter = ImGuiTextFilter() end
            local filter = s.filter
            if ImGui.IsWindowAppearing() then
                ImGui.SetKeyboardFocusHere()
                filter:Clear()
            end
            ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.F))
            ImGui.SetNextItemWidth(-FLT_MIN)
            filter:DrawWithHint("##Filter", "Filter (incl -excl)")

            for n = 0, #items - 1 do
                local is_selected = (s.item_selected_idx == n)
                if filter:PassFilter(items[n + 1]) then
                    if ImGui.Selectable(items[n + 1], is_selected) then
                        s.item_selected_idx = n
                    end
                end
            end
            ImGui.EndCombo()
        end

        ImGui.Spacing()
        ImGui.SeparatorText("One-liner variants")
        HelpMarker("The Combo() function is not greatly useful apart from cases were you want to embed all options in a single strings.\nFlags above don't apply to this section.")

        -- Simplified one-liner Combo() API, using values packed in a single constant string
        -- This is a convenience for when the selection set is small and known at compile-time.
        s.item_current_2 = ImGui.Combo("combo 3 (one-liner)", s.item_current_2, "aaaa\0bbbb\0cccc\0dddd\0eeee\0\0")

        -- Simplified one-liner Combo() using an array of const char*
        -- This is not very useful (may obsolete): prefer using BeginCombo()/EndCombo() for full control.
        s.item_current_3 = ImGui.Combo("combo 4 (array)", s.item_current_3, items, #items)

        -- Simplified one-liner Combo() using an accessor function
        s.item_current_4 = ImGui.Combo("combo 5 (function)", s.item_current_4, function(data, n) return data[n + 1] end, items, #items)

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsDataTypes()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsDataTypes = {
    -- State
    s8_v  = 127,
    u8_v  = 255,
    s16_v = 32767,
    u16_v = 65535,
    s32_v = -1,
    u32_v = 4294967295, -- (ImU32)-1
    -- [Port] s64_v / u64_v: 64-bit integer types are not supported (Lua numbers are doubles)
    f32_v = 0.123,
    f64_v = 90000.01234567890123456789,
    drag_clamp = false,
    inputs_step = true,
    flags = ImGuiInputTextFlags.None,
}

function DemoWindowWidgetsDataTypes()
    local _
    if ImGui.TreeNode("Data Types") then
        local s = S.DemoWindowWidgetsDataTypes
        IMGUI_DEMO_MARKER("Widgets/Data Types")
        -- DragScalar/InputScalar/SliderScalar functions allow various data types
        -- - signed/unsigned
        -- - 8/16/32/64-bits
        -- - integer/float/double
        -- To avoid polluting the public API with all possible combinations, we use the ImGuiDataType enum
        -- to pass the type, and passing all arguments by pointer.
        -- This is the reason the test code below creates local variables to hold "zero" "one" etc. for each type.
        -- In practice, if you frequently use a given type that is not covered by the normal API entry points,
        -- you can wrap it yourself inside a 1 line function which can take typed argument as value instead of void*,
        -- and then pass their address to the generic function. For example:
        --   bool MySliderU64(const char *label, u64* value, u64 min = 0, u64 max = 0, const char* format = "%lld")
        --   {
        --      return SliderScalar(label, ImGuiDataType_U64, value, &min, &max, format);
        --   }
        -- [Port] in this port the value is passed and returned by value: `v = ImGui.SliderScalar(label, data_type, v, min, max, format)`

        -- Setup limits (as helper variables so we can take their address, as explained above)
        -- Note: SliderScalar() functions have a maximum usable range of half the natural type maximum, hence the /2.
        -- [Port] LLONG_MIN/LLONG_MAX/ULLONG_MAX fallback block dropped: no 64-bit integer types
        local s8_zero,  s8_one,  s8_fifty,  s8_min,  s8_max  = 0, 1, 50, -128, 127
        local u8_zero,  u8_one,  u8_fifty,  u8_min,  u8_max  = 0, 1, 50, 0, 255
        local s16_zero, s16_one, s16_fifty, s16_min, s16_max = 0, 1, 50, -32768, 32767
        local u16_zero, u16_one, u16_fifty, u16_min, u16_max = 0, 1, 50, 0, 65535
        local s32_zero, s32_one, s32_fifty, s32_min, s32_max, s32_hi_a, s32_hi_b = 0, 1, 50, -1073741824, 1073741823, 1073741823 - 100, 1073741823 -- INT_MIN/2, INT_MAX/2
        local u32_zero, u32_one, u32_fifty, u32_min, u32_max, u32_hi_a, u32_hi_b = 0, 1, 50, 0, 2147483647, 2147483647 - 100, 2147483647 -- UINT_MAX/2
        -- [Port] s64_* / u64_* limits: ImGuiDataType.S64/U64 are not supported
        local f32_zero, f32_one, f32_lo_a, f32_hi_a = 0.0, 1.0, -10000000000.0, 10000000000.0
        local f64_zero, f64_one, f64_lo_a, f64_hi_a = 0.0, 1.0, -1000000000000000.0, 1000000000000000.0

        -- State
        -- (see S.DemoWindowWidgetsDataTypes)

        local drag_speed = 0.2
        IMGUI_DEMO_MARKER("Widgets/Data Types/Drags")
        ImGui.SeparatorText("Drags")
        _, s.drag_clamp = ImGui.Checkbox("Clamp integers to 0..50", s.drag_clamp)
        ImGui.SameLine(); HelpMarker(
            "As with every widget in dear imgui, we never modify values unless there is a user interaction.\n" ..
            "You can override the clamping limits by using Ctrl+Click to input a value.")
        local drag_clamp = s.drag_clamp
        s.s8_v  = ImGui.DragScalar("drag s8",        ImGuiDataType.S8,     s.s8_v,  drag_speed, drag_clamp and s8_zero  or nil, drag_clamp and s8_fifty  or nil)
        s.u8_v  = ImGui.DragScalar("drag u8",        ImGuiDataType.U8,     s.u8_v,  drag_speed, drag_clamp and u8_zero  or nil, drag_clamp and u8_fifty  or nil, "%u ms")
        s.s16_v = ImGui.DragScalar("drag s16",       ImGuiDataType.S16,    s.s16_v, drag_speed, drag_clamp and s16_zero or nil, drag_clamp and s16_fifty or nil)
        s.u16_v = ImGui.DragScalar("drag u16",       ImGuiDataType.U16,    s.u16_v, drag_speed, drag_clamp and u16_zero or nil, drag_clamp and u16_fifty or nil, "%u ms")
        s.s32_v = ImGui.DragScalar("drag s32",       ImGuiDataType.S32,    s.s32_v, drag_speed, drag_clamp and s32_zero or nil, drag_clamp and s32_fifty or nil)
        s.s32_v = ImGui.DragScalar("drag s32 hex",   ImGuiDataType.S32,    s.s32_v, drag_speed, drag_clamp and s32_zero or nil, drag_clamp and s32_fifty or nil, "0x%08X")
        s.u32_v = ImGui.DragScalar("drag u32",       ImGuiDataType.U32,    s.u32_v, drag_speed, drag_clamp and u32_zero or nil, drag_clamp and u32_fifty or nil, "%u ms")
        -- [Port] ImGui.DragScalar("drag s64",       ImGuiDataType.S64,    s64_v, ...) -- 64-bit types not supported
        -- [Port] ImGui.DragScalar("drag u64",       ImGuiDataType.U64,    u64_v, ...) -- 64-bit types not supported
        s.f32_v = ImGui.DragScalar("drag float",     ImGuiDataType.Float,  s.f32_v, 0.005,  f32_zero, f32_one, "%f")
        s.f32_v = ImGui.DragScalar("drag float log", ImGuiDataType.Float,  s.f32_v, 0.005,  f32_zero, f32_one, "%f", ImGuiSliderFlags.Logarithmic)
        s.f64_v = ImGui.DragScalar("drag double",    ImGuiDataType.Double, s.f64_v, 0.0005, f64_zero, nil,     "%.10f grams")
        s.f64_v = ImGui.DragScalar("drag double log",ImGuiDataType.Double, s.f64_v, 0.0005, f64_zero, f64_one, "0 < %.10f < 1", ImGuiSliderFlags.Logarithmic)

        IMGUI_DEMO_MARKER("Widgets/Data Types/Sliders")
        ImGui.SeparatorText("Sliders")
        s.s8_v  = ImGui.SliderScalar("slider s8 full",       ImGuiDataType.S8,     s.s8_v,  s8_min,   s8_max,   "%d")
        s.u8_v  = ImGui.SliderScalar("slider u8 full",       ImGuiDataType.U8,     s.u8_v,  u8_min,   u8_max,   "%u")
        s.s16_v = ImGui.SliderScalar("slider s16 full",      ImGuiDataType.S16,    s.s16_v, s16_min,  s16_max,  "%d")
        s.u16_v = ImGui.SliderScalar("slider u16 full",      ImGuiDataType.U16,    s.u16_v, u16_min,  u16_max,  "%u")
        s.s32_v = ImGui.SliderScalar("slider s32 low",       ImGuiDataType.S32,    s.s32_v, s32_zero, s32_fifty,"%d")
        s.s32_v = ImGui.SliderScalar("slider s32 high",      ImGuiDataType.S32,    s.s32_v, s32_hi_a, s32_hi_b, "%d")
        s.s32_v = ImGui.SliderScalar("slider s32 full",      ImGuiDataType.S32,    s.s32_v, s32_min,  s32_max,  "%d")
        s.s32_v = ImGui.SliderScalar("slider s32 hex",       ImGuiDataType.S32,    s.s32_v, s32_zero, s32_fifty, "0x%04X")
        s.u32_v = ImGui.SliderScalar("slider u32 low",       ImGuiDataType.U32,    s.u32_v, u32_zero, u32_fifty,"%u")
        s.u32_v = ImGui.SliderScalar("slider u32 high",      ImGuiDataType.U32,    s.u32_v, u32_hi_a, u32_hi_b, "%u")
        s.u32_v = ImGui.SliderScalar("slider u32 full",      ImGuiDataType.U32,    s.u32_v, u32_min,  u32_max,  "%u")
        -- [Port] "slider s64 low" / "slider s64 high" / "slider s64 full" (ImGuiDataType.S64): 64-bit types not supported
        -- [Port] "slider u64 low" / "slider u64 high" / "slider u64 full" (ImGuiDataType.U64): 64-bit types not supported
        s.f32_v = ImGui.SliderScalar("slider float low",     ImGuiDataType.Float,  s.f32_v, f32_zero, f32_one)
        s.f32_v = ImGui.SliderScalar("slider float low log", ImGuiDataType.Float,  s.f32_v, f32_zero, f32_one,  "%.10f", ImGuiSliderFlags.Logarithmic)
        s.f32_v = ImGui.SliderScalar("slider float high",    ImGuiDataType.Float,  s.f32_v, f32_lo_a, f32_hi_a, "%e")
        s.f64_v = ImGui.SliderScalar("slider double low",    ImGuiDataType.Double, s.f64_v, f64_zero, f64_one,  "%.10f grams")
        s.f64_v = ImGui.SliderScalar("slider double low log",ImGuiDataType.Double, s.f64_v, f64_zero, f64_one,  "%.10f", ImGuiSliderFlags.Logarithmic)
        s.f64_v = ImGui.SliderScalar("slider double high",   ImGuiDataType.Double, s.f64_v, f64_lo_a, f64_hi_a, "%e grams")

        ImGui.SeparatorText("Sliders (reverse)")
        s.s8_v  = ImGui.SliderScalar("slider s8 reverse",    ImGuiDataType.S8,   s.s8_v,  s8_max,    s8_min,   "%d")
        s.u8_v  = ImGui.SliderScalar("slider u8 reverse",    ImGuiDataType.U8,   s.u8_v,  u8_max,    u8_min,   "%u")
        s.s32_v = ImGui.SliderScalar("slider s32 reverse",   ImGuiDataType.S32,  s.s32_v, s32_fifty, s32_zero, "%d")
        s.u32_v = ImGui.SliderScalar("slider u32 reverse",   ImGuiDataType.U32,  s.u32_v, u32_fifty, u32_zero, "%u")
        -- [Port] "slider s64 reverse" / "slider u64 reverse": 64-bit types not supported

        IMGUI_DEMO_MARKER("Widgets/Data Types/Inputs")
        ImGui.SeparatorText("Inputs")
        _, s.inputs_step = ImGui.Checkbox("Show step buttons", s.inputs_step)
        _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ReadOnly", s.flags, ImGuiInputTextFlags.ReadOnly)
        _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ParseEmptyRefVal", s.flags, ImGuiInputTextFlags.ParseEmptyRefVal)
        _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_DisplayEmptyRefVal", s.flags, ImGuiInputTextFlags.DisplayEmptyRefVal)
        local inputs_step, flags = s.inputs_step, s.flags
        s.s8_v  = ImGui.InputScalar("input s8",      ImGuiDataType.S8,     s.s8_v,  inputs_step and s8_one  or nil, nil, "%d", flags)
        s.u8_v  = ImGui.InputScalar("input u8",      ImGuiDataType.U8,     s.u8_v,  inputs_step and u8_one  or nil, nil, "%u", flags)
        s.s16_v = ImGui.InputScalar("input s16",     ImGuiDataType.S16,    s.s16_v, inputs_step and s16_one or nil, nil, "%d", flags)
        s.u16_v = ImGui.InputScalar("input u16",     ImGuiDataType.U16,    s.u16_v, inputs_step and u16_one or nil, nil, "%u", flags)
        s.s32_v = ImGui.InputScalar("input s32",     ImGuiDataType.S32,    s.s32_v, inputs_step and s32_one or nil, nil, "%d", flags)
        s.s32_v = ImGui.InputScalar("input s32 hex", ImGuiDataType.S32,    s.s32_v, inputs_step and s32_one or nil, nil, "%04X", flags)
        s.u32_v = ImGui.InputScalar("input u32",     ImGuiDataType.U32,    s.u32_v, inputs_step and u32_one or nil, nil, "%u", flags)
        s.u32_v = ImGui.InputScalar("input u32 hex", ImGuiDataType.U32,    s.u32_v, inputs_step and u32_one or nil, nil, "%08X", flags)
        -- [Port] ImGui.InputScalar("input s64",     ImGuiDataType.S64, ...) -- 64-bit types not supported
        -- [Port] ImGui.InputScalar("input u64",     ImGuiDataType.U64, ...) -- 64-bit types not supported
        s.f32_v = ImGui.InputScalar("input float",   ImGuiDataType.Float,  s.f32_v, inputs_step and f32_one or nil, nil, nil, flags)
        s.f64_v = ImGui.InputScalar("input double",  ImGuiDataType.Double, s.f64_v, inputs_step and f64_one or nil, nil, nil, flags)

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsDisableBlocks()
-------------------------------------------------------------------------------

function DemoWindowWidgetsDisableBlocks(demo_data)
    local _
    if ImGui.TreeNode("Disable Blocks") then
        IMGUI_DEMO_MARKER("Widgets/Disable Blocks")
        _, demo_data.DisableSections = ImGui.Checkbox("Disable entire section above", demo_data.DisableSections)
        ImGui.SameLine(); HelpMarker("Demonstrate using BeginDisabled()/EndDisabled() across other sections.")
        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsDragAndDrop()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsDragAndDrop = {
    col1 = { 1.0, 0.0, 0.2 },
    col2 = { 0.4, 0.7, 0.0, 0.5 },
    mode = 0,
    names = { -- 1-based
        "Bobby", "Beatrice", "Betty",
        "Brianna", "Barry", "Bernard",
        "Bibi", "Blaine", "Bryn"
    },
    item_names = { "Item One", "Item Two", "Item Three", "Item Four", "Item Five" }, -- 1-based
    col4 = ImVec4(1.0, 0.0, 0.2, 1.0),
}

function DemoWindowWidgetsDragAndDrop()
    if ImGui.TreeNode("Drag and Drop") then
        local s = S.DemoWindowWidgetsDragAndDrop
        IMGUI_DEMO_MARKER("Widgets/Drag and drop")
        if ImGui.TreeNode("Drag and drop in standard widgets") then
            IMGUI_DEMO_MARKER("Widgets/Drag and drop/Standard widgets")
            -- ColorEdit widgets automatically act as drag source and drag target.
            -- They are using standardized payload strings IMGUI_PAYLOAD_TYPE_COLOR_3F and IMGUI_PAYLOAD_TYPE_COLOR_4F
            -- to allow your own widgets to use colors in their drag and drop interaction.
            -- Also see 'Demo->Widgets->Color/Picker Widgets->Palette' demo.
            HelpMarker("You can drag from the color squares.")
            ImGui.ColorEdit3("color 1", s.col1)
            ImGui.ColorEdit4("color 2", s.col2)
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Drag and drop to copy/swap items") then
            IMGUI_DEMO_MARKER("Widgets/Drag and drop/Copy-swap items")
            local Mode_Copy, Mode_Move, Mode_Swap = 0, 1, 2
            if ImGui.RadioButtonEx("Copy", s.mode == Mode_Copy) then s.mode = Mode_Copy end ImGui.SameLine()
            if ImGui.RadioButtonEx("Move", s.mode == Mode_Move) then s.mode = Mode_Move end ImGui.SameLine()
            if ImGui.RadioButtonEx("Swap", s.mode == Mode_Swap) then s.mode = Mode_Swap end
            local names = s.names
            for n = 0, #names - 1 do
                ImGui.PushID(n)
                if (n % 3) ~= 0 then
                    ImGui.SameLine()
                end
                ImGui.Button(names[n + 1], ImVec2(60, 60))

                -- Our buttons are both drag sources and drag targets here!
                if ImGui.BeginDragDropSource(ImGuiDragDropFlags.None) then
                    -- Set payload to carry the index of our item (could be anything)
                    ImGui.SetDragDropPayload("DND_DEMO_CELL", n, 4) -- [Port] sizeof(int) -> 4, payload carries the Lua value

                    -- Display preview (could be anything, e.g. when dragging an image we could decide to display
                    -- the filename and a small preview of the image, etc.)
                    if s.mode == Mode_Copy then ImGui.Text("Copy %s", names[n + 1]) end
                    if s.mode == Mode_Move then ImGui.Text("Move %s", names[n + 1]) end
                    if s.mode == Mode_Swap then ImGui.Text("Swap %s", names[n + 1]) end
                    ImGui.EndDragDropSource()
                end
                if ImGui.BeginDragDropTarget() then
                    local payload = ImGui.AcceptDragDropPayload("DND_DEMO_CELL")
                    if payload then
                        IM_ASSERT(payload.DataSize == 4)
                        local payload_n = payload.Data
                        if s.mode == Mode_Copy then
                            names[n + 1] = names[payload_n + 1]
                        end
                        if s.mode == Mode_Move then
                            names[n + 1] = names[payload_n + 1]
                            names[payload_n + 1] = ""
                        end
                        if s.mode == Mode_Swap then
                            local tmp = names[n + 1]
                            names[n + 1] = names[payload_n + 1]
                            names[payload_n + 1] = tmp
                        end
                    end
                    ImGui.EndDragDropTarget()
                end
                ImGui.PopID()
            end
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Drag to reorder items (simple)") then
            IMGUI_DEMO_MARKER("Widgets/Drag and Drop/Drag to reorder items (simple)")
            -- FIXME: there is temporary (usually single-frame) ID Conflict during reordering as a same item may be submitting twice.
            -- This code was always slightly faulty but in a way which was not easily noticeable.
            -- Until we fix this, enable ImGuiItemFlags_AllowDuplicateId to disable detecting the issue.
            ImGui.PushItemFlag(ImGuiItemFlags.AllowDuplicateId, true)

            -- Simple reordering
            HelpMarker(
                "We don't use the drag and drop api at all here! " ..
                "Instead we query when the item is held but not hovered, and order items accordingly.")
            local item_names = s.item_names
            for n = 0, #item_names - 1 do
                local item = item_names[n + 1]
                ImGui.Selectable(item)

                if ImGui.IsItemActive() and not ImGui.IsItemHovered() then
                    local n_next = n + ((ImGui.GetMouseDragDelta(0).y < 0.0) and -1 or 1)
                    if n_next >= 0 and n_next < #item_names then
                        item_names[n + 1] = item_names[n_next + 1]
                        item_names[n_next + 1] = item
                        ImGui.ResetMouseDragDelta()
                    end
                end
            end

            ImGui.PopItemFlag()
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Tooltip at target location") then
            IMGUI_DEMO_MARKER("Widgets/Drag and Drop/Tooltip at target location")
            for n = 0, 1 do
                -- Drop targets
                ImGui.Button((n ~= 0) and "drop here##1" or "drop here##0")
                if ImGui.BeginDragDropTarget() then
                    local drop_target_flags = bit32.bor(ImGuiDragDropFlags.AcceptBeforeDelivery, ImGuiDragDropFlags.AcceptNoPreviewTooltip)
                    local payload = ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_COLOR_4F, drop_target_flags)
                    if payload then
                        -- IM_UNUSED(payload)
                        ImGui.SetMouseCursor(ImGuiMouseCursor.NotAllowed)
                        ImGui.SetTooltip("Cannot drop here!")
                    end
                    ImGui.EndDragDropTarget()
                end

                -- Drop source
                if n == 0 then
                    ImGui.ColorButton("drag me", s.col4)
                end

            end
            ImGui.TreePop()
        end

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsDragsAndSliders()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsDragsAndSliders = {
    flags = ImGuiSliderFlags.None,
    -- Drags
    drag_f = 0.5,
    drag_f4 = { 0.0, 0.0, 0.0, 0.0 },
    drag_i = 50,
    -- Sliders
    slider_f = 0.5,
    slider_f4 = { 0.0, 0.0, 0.0, 0.0 },
    slider_i = 50,
}

function DemoWindowWidgetsDragsAndSliders()
    local _
    if ImGui.TreeNode("Drag/Slider Flags") then
        local s = S.DemoWindowWidgetsDragsAndSliders
        IMGUI_DEMO_MARKER("Widgets/Drag and Slider Flags")
        -- Demonstrate using advanced flags for DragXXX and SliderXXX functions. Note that the flags are the same!
        _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_AlwaysClamp", s.flags, ImGuiSliderFlags.AlwaysClamp)
        _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_ClampOnInput", s.flags, ImGuiSliderFlags.ClampOnInput)
        ImGui.SameLine(); HelpMarker("Clamp value to min/max bounds when input manually with Ctrl+Click. By default Ctrl+Click allows going out of bounds.")
        _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_ClampZeroRange", s.flags, ImGuiSliderFlags.ClampZeroRange)
        ImGui.SameLine(); HelpMarker("Clamp even if min==max==0.0f. Otherwise DragXXX functions don't clamp.")
        _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_Logarithmic", s.flags, ImGuiSliderFlags.Logarithmic)
        ImGui.SameLine(); HelpMarker("Enable logarithmic editing (more precision for small values).")
        _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_NoRoundToFormat", s.flags, ImGuiSliderFlags.NoRoundToFormat)
        ImGui.SameLine(); HelpMarker("Disable rounding underlying value to match precision of the format string (e.g. %.3f values are rounded to those 3 digits).")
        _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_NoInput", s.flags, ImGuiSliderFlags.NoInput)
        ImGui.SameLine(); HelpMarker("Disable Ctrl+Click or Enter key allowing to input text directly into the widget.")
        _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_NoSpeedTweaks", s.flags, ImGuiSliderFlags.NoSpeedTweaks)
        ImGui.SameLine(); HelpMarker("Disable keyboard modifiers altering tweak speed. Useful if you want to alter tweak speed yourself based on your own logic.")
        _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_WrapAround", s.flags, ImGuiSliderFlags.WrapAround)
        ImGui.SameLine(); HelpMarker("Enable wrapping around from max to min and from min to max (only supported by DragXXX() functions)")
        _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_ColorMarkers", s.flags, ImGuiSliderFlags.ColorMarkers)
        local flags = s.flags

        -- Drags
        ImGui.Text("Underlying float value: %f", s.drag_f)
        s.drag_f = ImGui.DragFloat("DragFloat (0 -> 1)", s.drag_f, 0.005, 0.0, 1.0, "%.3f", flags)
        s.drag_f = ImGui.DragFloat("DragFloat (0 -> +inf)", s.drag_f, 0.005, 0.0, FLT_MAX, "%.3f", flags)
        s.drag_f = ImGui.DragFloat("DragFloat (-inf -> 1)", s.drag_f, 0.005, -FLT_MAX, 1.0, "%.3f", flags)
        s.drag_f = ImGui.DragFloat("DragFloat (-inf -> +inf)", s.drag_f, 0.005, -FLT_MAX, FLT_MAX, "%.3f", flags)
        --ImGui.DragFloat("DragFloat (0 -> 0)", drag_f, 0.005, 0.0, 0.0, "%.3f", flags)           -- To test ClampZeroRange
        --ImGui.DragFloat("DragFloat (100 -> 100)", drag_f, 0.005, 100.0, 100.0, "%.3f", flags)
        s.drag_i = ImGui.DragInt("DragInt (0 -> 100)", s.drag_i, 0.5, 0, 100, "%d", flags)
        ImGui.DragFloat4("DragFloat4 (0 -> 1)", s.drag_f4, 0.005, 0.0, 1.0, "%.3f", flags) -- Multi-component item, mostly here to document the effect of ImGuiSliderFlags_ColorMarkers.

        -- Sliders
        local flags_for_sliders = bit32.band(flags, bit32.bnot(ImGuiSliderFlags.WrapAround))
        ImGui.Text("Underlying float value: %f", s.slider_f)
        s.slider_f = ImGui.SliderFloat("SliderFloat (0 -> 1)", s.slider_f, 0.0, 1.0, "%.3f", flags_for_sliders)
        s.slider_i = ImGui.SliderInt("SliderInt (0 -> 100)", s.slider_i, 0, 100, "%d", flags_for_sliders)
        ImGui.SliderFloat4("SliderFloat4 (0 -> 1)", s.slider_f4, 0.0, 1.0, "%.3f", flags_for_sliders) -- Multi-component item, mostly here to document the effect of ImGuiSliderFlags_ColorMarkers. -- [Port] flags_for_sliders: upstream passes `flags`, which trips SliderScalar's WrapAround assert

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsFonts()
-------------------------------------------------------------------------------

function DemoWindowWidgetsFonts()
    if ImGui.TreeNode("Fonts") then
        IMGUI_DEMO_MARKER("Widgets/Fonts")
        local atlas = ImGui.GetIO().Fonts
        ImGui.ShowFontAtlas(atlas)
        -- FIXME-NEWATLAS: Provide a demo to add/create a procedural font?
        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsImages()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsImages = {
    image_viewer = ExampleImageViewerData(),
    pressed_count = 0,
}
function DemoWindowWidgetsImages()
    local s = S.DemoWindowWidgetsImages
    if ImGui.TreeNode("Images") then
        IMGUI_DEMO_MARKER("Widgets/Images")
        local io = ImGui.GetIO()
        ImGui.TextWrapped(
            "Below we are displaying the font texture (which is the only texture we have access to in this demo). " ..
            "Use the 'ImTextureID' type as storage to pass pointers or identifier to your own texture data. " ..
            "Hover the texture for a zoomed view!")

        -- Below we are displaying the font texture because it is the only texture we have access to inside the demo!
        -- Read description about ImTextureID/ImTextureRef and FAQ for details about texture identifiers.
        -- If you use one of the default imgui_impl_XXXX.cpp rendering backend, they all have comments at the top
        -- of their respective source file to specify what they are using as texture identifier, for example:
        -- - The imgui_impl_dx11.cpp renderer expect a 'ID3D11ShaderResourceView*' pointer.
        -- - The imgui_impl_opengl3.cpp renderer expect a GLuint OpenGL texture identifier, etc.
        -- So with the DirectX11 backend, you call ImGui.Image() with a 'ID3D11ShaderResourceView*' cast to ImTextureID.
        -- - If you decided that ImTextureID = MyEngineTexture*, then you can pass your MyEngineTexture* pointers
        --   to ImGui.Image(), and gather width/height through your own functions, etc.
        -- - You can use ShowMetricsWindow() to inspect the draw data that are being passed to your renderer,
        --   it will help you debug issues if you are confused about it.
        -- - Consider using the lower-level ImDrawList::AddImage() API, via ImGui.GetWindowDrawList():AddImage().
        -- - Read https://github.com/ocornut/imgui/blob/master/docs/FAQ.md
        -- - Read https://github.com/ocornut/imgui/wiki/Image-Loading-and-Displaying-Examples

        -- Grab the current texture identifier used by the font atlas.
        local atlas = io.Fonts
        local my_tex_id = atlas.TexRef
        local my_tex_w = atlas.TexData.Width -- Regular user code should never have to care about TexData-> fields, but since we want to display the entire texture here, we pull Width/Height from it.
        local my_tex_h = atlas.TexData.Height
        ImGui.Text("%.0fx%.0f", my_tex_w, my_tex_h)

        -- Basic drawing
        ImGui.SeparatorText("Image()/ImageWithBg() function")
        local uv_min = ImVec2(0.0, 0.0) -- Top-left
        local uv_max = ImVec2(1.0, 1.0) -- Lower-right
        ImGui.PushStyleVar(ImGuiStyleVar.ImageBorderSize, ImMax(1.0, ImGui.GetStyle().ImageBorderSize))
        ImGui.ImageWithBg(my_tex_id, ImVec2(my_tex_w, my_tex_h), uv_min, uv_max, ImVec4(0.0, 0.0, 0.0, 1.0))
        ImGui.PopStyleVar()

        -- Fancy widget
        ImGui.SeparatorText("Interactive Image Viewer")
        local canvas_size = ImVec2(ImGui.GetContentRegionAvail().x, my_tex_h * 2.0)
        ExampleImageViewer_DrawOptions(s.image_viewer)
        ExampleImageViewer_DrawCanvas(s.image_viewer, canvas_size, my_tex_id, math.floor(my_tex_w), math.floor(my_tex_h))

        IMGUI_DEMO_MARKER("Widgets/Images/Textured buttons")
        ImGui.SeparatorText("Textured Buttons")
        ImGui.TextWrapped("And now some textured buttons..")
        for i = 0, 7 do
            -- UV coordinates are often (0.0, 0.0) and (1.0, 1.0) to display an entire textures.
            -- Here are trying to display only a 32x32 pixels area of the texture, hence the UV computation.
            -- Read about UV coordinates here: https://github.com/ocornut/imgui/wiki/Image-Loading-and-Displaying-Examples
            ImGui.PushID(i)
            if i > 0 then
                ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(i - 1.0, i - 1.0))
            end
            local size = ImVec2(32.0, 32.0)                         -- Size of the image we want to make visible
            local uv0 = ImVec2(0.0, 0.0)                            -- UV coordinates for lower-left
            local uv1 = ImVec2(32.0 / my_tex_w, 32.0 / my_tex_h)    -- UV coordinates for (32,32) in our texture
            local bg_col = ImVec4(0.0, 0.0, 0.0, 1.0)               -- Black background
            local tint_col = ImVec4(1.0, 1.0, 1.0, 1.0)             -- No tint
            if ImGui.ImageButton("", my_tex_id, size, uv0, uv1, bg_col, tint_col) then
                s.pressed_count = s.pressed_count + 1
            end
            if i > 0 then
                ImGui.PopStyleVar()
            end
            ImGui.PopID()
            ImGui.SameLine()
        end
        ImGui.NewLine()
        ImGui.Text("Pressed %d times.", s.pressed_count)
        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsListBoxes()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsListBoxes = {
    item_selected_idx = 0, -- Here we store our selected data as an index.
    item_highlight = false,
}
function DemoWindowWidgetsListBoxes()
    local s = S.DemoWindowWidgetsListBoxes
    if ImGui.TreeNode("List Boxes") then
        IMGUI_DEMO_MARKER("Widgets/List Boxes")
        -- BeginListBox() is essentially a thin wrapper to using BeginChild()/EndChild()
        -- using the ImGuiChildFlags_FrameStyle flag for stylistic changes + displaying a label.
        -- You may be tempted to simply use BeginChild() directly. However note that BeginChild() requires EndChild()
        -- to always be called (inconsistent with BeginListBox()/EndListBox()).

        -- Using the generic BeginListBox() API, you have full control over how to display the combo contents.
        -- (your selection data could be an index, a pointer to the object, an id for the object, a flag intrusively
        -- stored in the object itself, etc.)
        local items = { "AAAA", "BBBB", "CCCC", "DDDD", "EEEE", "FFFF", "GGGG", "HHHH", "IIII", "JJJJ", "KKKK", "LLLLLLL", "MMMM", "OOOOOOO" }
        -- static int item_selected_idx = 0; // Here we store our selected data as an index.

        local item_highlighted_idx = -1 -- Here we store our highlighted data as an index.
        _, s.item_highlight = ImGui.Checkbox("Highlight hovered item in second listbox", s.item_highlight)

        if ImGui.BeginListBox("listbox 1") then
            for n = 0, #items - 1 do
                local is_selected = (s.item_selected_idx == n)
                if ImGui.Selectable(items[n + 1], is_selected) then
                    s.item_selected_idx = n
                end

                if s.item_highlight and ImGui.IsItemHovered() then
                    item_highlighted_idx = n
                end

                -- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
                if is_selected then
                    ImGui.SetItemDefaultFocus()
                end
            end
            ImGui.EndListBox()
        end
        ImGui.SameLine(); HelpMarker("Here we are sharing selection state between both boxes.")

        -- Custom size: use all width, 5 items tall
        ImGui.Text("Full-width:")
        if ImGui.BeginListBox("##listbox 2", ImVec2(-FLT_MIN, 5 * ImGui.GetTextLineHeightWithSpacing())) then
            for n = 0, #items - 1 do
                local is_selected = (s.item_selected_idx == n)
                local flags = 0
                if item_highlighted_idx == n then flags = ImGuiSelectableFlags.Highlight end
                if ImGui.Selectable(items[n + 1], is_selected, flags) then
                    s.item_selected_idx = n
                end

                -- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
                if is_selected then
                    ImGui.SetItemDefaultFocus()
                end
            end
            ImGui.EndListBox()
        end

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsLiveEdit()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsLiveEdit = {
    str = ImGui.NewTextBuffer("", 32),
    i = 0,
    f = 0.0,
}
function DemoWindowWidgetsLiveEdit(demo_data)
    local s = S.DemoWindowWidgetsLiveEdit
    if ImGui.TreeNode("Live Edit Flags") then
        IMGUI_DEMO_MARKER("Widgets/Live Edit Flags")

        ImGui.TextWrapped("Select whether to apply keyboard edits to backing variables _while_ typing.")

        _, demo_data.LiveEditOverride = ImGui.Checkbox("Override Live Edit Flags in Demo Window", demo_data.LiveEditOverride)
        if not demo_data.LiveEditOverride then
            demo_data.LiveEditFlags = ImGui.GetItemFlags()
        end

        ImGui.BeginDisabled(demo_data.LiveEditOverride == false)
        ImGui.Indent()
        _, demo_data.LiveEditFlags = ImGui.CheckboxFlags("ImGuiItemFlags_LiveEditOnInputText", demo_data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputText)
        _, demo_data.LiveEditFlags = ImGui.CheckboxFlags("ImGuiItemFlags_LiveEditOnInputScalar", demo_data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputScalar)
        ImGui.Unindent()
        ImGui.EndDisabled()

        ImGui.Text("Try typing '123' and seeing effect on backing value:")
        ImGui.InputText("str", s.str, 32)
        ImGui.Text("Backing value: \"%s\"", ImGui.TextBufferToString(s.str))
        s.i = ImGui.InputInt("int", s.i, 0, 0)
        ImGui.Text("Backing value: %d", s.i)
        s.f = ImGui.SliderFloat("float", s.f, 0.0, 100.0)
        ImGui.Text("Backing value: %f", s.f)

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsMixedValues()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsMixedValues = {
    use_liveedit = false,
    items = { 12.0, 0.0, 0.0 },
}
function DemoWindowWidgetsMixedValues()
    local s = S.DemoWindowWidgetsMixedValues
    if ImGui.TreeNode("Mixed Values") then
        -- This is designed for advanced property editors which are generally reusable and data-driven.
        HelpMarker("Using ImGuiItemFlags_MixedValue.")

        local items = s.items
        local item_ref = 1 -- [Port] index of the reference item (C++: float* item_ref = &items[0])
        _, s.use_liveedit = ImGui.Checkbox("ImGuiItemFlags_LiveEditOnInput", s.use_liveedit)

        ImGui.SeparatorText("Scalar/Text Widgets")
        local is_mixed = items[1] ~= items[2] or items[1] ~= items[3]

        -- Demonstrate Drags, Sliders, Inputs
        ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInput, s.use_liveedit)
        ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, is_mixed)
        local edited = false
        local changed
        items[item_ref], changed = ImGui.DragFloat("DragFloat", items[item_ref]); edited = edited or changed
        items[item_ref], changed = ImGui.SliderFloat("SliderFloat", items[item_ref], 0.0, 100.0); edited = edited or changed
        items[item_ref], changed = ImGui.InputFloat("InputFloat", items[item_ref], 1.0); edited = edited or changed
        if edited then
            for n = 1, #items do
                if n ~= item_ref then
                    items[n] = items[item_ref]
                end
            end
        end
        ImGui.PopItemFlag()

        ImGui.Text("Underlying data:")
        items[1] = ImGui.InputFloat("item 0 (ref)", items[1])
        items[2] = ImGui.InputFloat("item 1", items[2])
        items[3] = ImGui.InputFloat("item 2", items[3])
        ImGui.PopItemFlag()

        -- Demonstrate Checkbox(), RadioButton(), Combo(), ColorEdit4()
        ImGui.SeparatorText("Others Widgets")
        ImGui.Text("(note: edits are not applied in this demo)") -- <-- Would need more state tracking.
        local b_on, b_off = true, false
        _, b_on = ImGui.Checkbox("Checkbox On", b_on)
        _, b_off = ImGui.Checkbox("Checkbox Off", b_off)
        ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, true)
        _, b_off = ImGui.Checkbox("Checkbox Mixed", b_off)
        ImGui.RadioButtonEx("RadioButton Mixed", true) -- [Port] RadioButton(label, bool active) overload is RadioButtonEx
        ImGui.SameLine()
        ImGui.RadioButtonEx("RadioButton Mixed##2", true) -- Showing 2 radio buttons makes the example more clear
        local combo_idx = 0
        combo_idx = ImGui.Combo("Combo", combo_idx, "One\0Two\0Three\0")
        local color = ImVec4(0.5, 0.5, 0.5, 0.5)
        ImGui.ColorEdit4("ColorEdit4", color)
        ImGui.PopItemFlag()

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsMultiComponents()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsMultiComponents = {
    vec4f = { 0.10, 0.20, 0.30, 0.44 },
    vec4i = { 1, 5, 100, 255 },
    flags = 0,
    begin = 10, ["end"] = 90,
    begin_i = 100, end_i = 1000,
}
function DemoWindowWidgetsMultiComponents()
    local s = S.DemoWindowWidgetsMultiComponents
    if ImGui.TreeNode("Multi-component Widgets") then
        IMGUI_DEMO_MARKER("Widgets/Multi-component Widgets")
        local vec4f = s.vec4f
        local vec4i = s.vec4i

        _, s.flags = ImGui.CheckboxFlags("ImGuiSliderFlags_ColorMarkers", s.flags, ImGuiSliderFlags.ColorMarkers) -- Only passing this to Drag/Sliders
        local flags = s.flags

        ImGui.SeparatorText("2-wide")
        ImGui.InputFloat2("input float2", vec4f)
        ImGui.InputInt2("input int2", vec4i)
        ImGui.DragFloat2("drag float2", vec4f, 0.01, 0.0, 1.0, nil, flags)
        ImGui.DragInt2("drag int2", vec4i, 1, 0, 255, nil, flags)
        ImGui.SliderFloat2("slider float2", vec4f, 0.0, 1.0, nil, flags)
        ImGui.SliderInt2("slider int2", vec4i, 0, 255, nil, flags)

        ImGui.SeparatorText("3-wide")
        ImGui.InputFloat3("input float3", vec4f)
        ImGui.InputInt3("input int3", vec4i)
        ImGui.DragFloat3("drag float3", vec4f, 0.01, 0.0, 1.0, nil, flags)
        ImGui.DragInt3("drag int3", vec4i, 1, 0, 255, nil, flags)
        ImGui.SliderFloat3("slider float3", vec4f, 0.0, 1.0, nil, flags)
        ImGui.SliderInt3("slider int3", vec4i, 0, 255, nil, flags)

        ImGui.SeparatorText("4-wide")
        ImGui.InputFloat4("input float4", vec4f)
        ImGui.InputInt4("input int4", vec4i)
        ImGui.DragFloat4("drag float4", vec4f, 0.01, 0.0, 1.0, nil, flags)
        ImGui.DragInt4("drag int4", vec4i, 1, 0, 255, nil, flags)
        ImGui.SliderFloat4("slider float4", vec4f, 0.0, 1.0, nil, flags)
        ImGui.SliderInt4("slider int4", vec4i, 0, 255, nil, flags)

        ImGui.SeparatorText("Ranges")
        s.begin, s["end"] = ImGui.DragFloatRange2("range float", s.begin, s["end"], 0.25, 0.0, 100.0, "Min: %.1f %%", "Max: %.1f %%", ImGuiSliderFlags.AlwaysClamp)
        s.begin_i, s.end_i = ImGui.DragIntRange2("range int", s.begin_i, s.end_i, 5, 0, 1000, "Min: %d units", "Max: %d units")
        s.begin_i, s.end_i = ImGui.DragIntRange2("range int (no bounds)", s.begin_i, s.end_i, 5, 0, 0, "Min: %d units", "Max: %d units")

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsPlotting()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsPlotting = {
    animate = true,
    arr = { 0.6, 0.1, 1.0, 0.5, 0.92, 0.1, 0.2 },
    values = {}, -- 90 zeros, filled below
    values_offset = 0,
    refresh_time = 0.0,
    phase = 0.0,
    func_type = 0, display_count = 70,
}
for n = 1, 90 do S.DemoWindowWidgetsPlotting.values[n] = 0.0 end

-- Use functions to generate output
-- [Port] struct Funcs hoisted out of the function to avoid per-frame closures.
-- Plot getters receive a 1-based index in this port: convert back to upstream's 0-based i.
local DemoPlottingFuncs = {
    Sin = function(_, idx) local i = idx - 1; return math.sin(i * 0.1) end,
    Saw = function(_, idx) local i = idx - 1; if bit32.band(i, 1) ~= 0 then return 1.0 end return -1.0 end,
}

function DemoWindowWidgetsPlotting()
    local s = S.DemoWindowWidgetsPlotting
    -- Plot/Graph widgets are not very good.
    -- Consider using a third-party library such as ImPlot: https://github.com/epezent/implot
    -- (see others https://github.com/ocornut/imgui/wiki/Useful-Extensions)
    if ImGui.TreeNode("Plotting") then
        IMGUI_DEMO_MARKER("Widgets/Plotting")
        ImGui.Text("Need better plotting and graphing? Consider using ImPlot:")
        ImGui.TextLinkOpenURL("https://github.com/epezent/implot")
        ImGui.Separator()

        _, s.animate = ImGui.Checkbox("Animate", s.animate)

        -- Plot as lines and plot as histogram
        local arr = s.arr
        ImGui.PlotLines("Frame Times", arr, nil, #arr)
        ImGui.PlotHistogram("Histogram", arr, nil, #arr, 0, nil, 0.0, 1.0, ImVec2(0, 80.0))
        -- ImGui.SameLine(); HelpMarker("Consider using ImPlot instead!")

        -- Fill an array of contiguous float values to plot
        -- Tip: If your float aren't contiguous but part of a structure, you can pass a pointer to your first float
        -- and the sizeof() of your structure in the "stride" parameter.
        local values = s.values
        if not s.animate or s.refresh_time == 0.0 then
            s.refresh_time = ImGui.GetTime()
        end
        while s.refresh_time < ImGui.GetTime() do -- Create data at fixed 60 Hz rate for the demo
            values[s.values_offset + 1] = math.cos(s.phase)
            s.values_offset = (s.values_offset + 1) % #values
            s.phase = s.phase + 0.10 * s.values_offset
            s.refresh_time = s.refresh_time + 1.0 / 60.0
        end

        -- Plots can display overlay texts
        -- (in this example, we will display an average value)
        do
            local average = 0.0
            for n = 0, #values - 1 do
                average = average + values[n + 1]
            end
            average = average / #values
            local overlay = string.format("avg %f", average)
            ImGui.PlotLines("Lines", values, nil, #values, s.values_offset, overlay, -1.0, 1.0, ImVec2(0, 80.0))
        end

        -- Use functions to generate output
        -- FIXME: This is actually VERY awkward because current plot API only pass in indices.
        -- We probably want an API passing floats and user provide sample rate/count.
        local Funcs = DemoPlottingFuncs
        ImGui.SeparatorText("Functions")
        ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
        s.func_type = ImGui.Combo("func", s.func_type, "Sin\0Saw\0")
        ImGui.SameLine()
        s.display_count = ImGui.SliderInt("Sample count", s.display_count, 1, 400)
        local func = Funcs.Saw
        if s.func_type == 0 then func = Funcs.Sin end
        ImGui.PlotLines("Lines##2", func, nil, s.display_count, 0, nil, -1.0, 1.0, ImVec2(0, 80))
        ImGui.PlotHistogram("Histogram##2", func, nil, s.display_count, 0, nil, -1.0, 1.0, ImVec2(0, 80))

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsProgressBars()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsProgressBars = {
    progress_accum = 0.0, progress_dir = 1.0,
}
function DemoWindowWidgetsProgressBars()
    local s = S.DemoWindowWidgetsProgressBars
    if ImGui.TreeNode("Progress Bars") then
        IMGUI_DEMO_MARKER("Widgets/Progress Bars")
        -- Animate a simple progress bar
        s.progress_accum = s.progress_accum + s.progress_dir * 0.4 * ImGui.GetIO().DeltaTime
        if s.progress_accum >= 1.1 then s.progress_accum = 1.1; s.progress_dir = s.progress_dir * -1.0 end
        if s.progress_accum <= -0.1 then s.progress_accum = -0.1; s.progress_dir = s.progress_dir * -1.0 end

        local progress = ImClamp(s.progress_accum, 0.0, 1.0)

        -- Typically we would use ImVec2(-1.0,0.0) or ImVec2(-FLT_MIN,0.0) to use all available width,
        -- or ImVec2(width,0.0) for a specified width. ImVec2(0.0,0.0) uses ItemWidth.
        ImGui.ProgressBar(progress, ImVec2(0.0, 0.0))
        ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
        ImGui.Text("Progress Bar")

        local buf = string.format("%d/%d", math.floor(progress * 1753), 1753)
        ImGui.ProgressBar(progress, ImVec2(0.0, 0.0), buf)

        -- Pass an animated negative value, e.g. -1.0 * ImGui.GetTime() is the recommended value.
        -- Adjust the factor if you want to adjust the animation speed.
        ImGui.ProgressBar(-1.0 * ImGui.GetTime(), ImVec2(0.0, 0.0), "Searching..")
        ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
        ImGui.Text("Indeterminate")

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsQueryingStatuses()
-------------------------------------------------------------------------------

-- [Port] C++ passes bools to "%d"; string.format needs numbers.
local function DemoBoolToInt(b) if b then return 1 end return 0 end

S.DemoWindowWidgetsQueryingStatuses = {
    item_type = 4,
    item_disabled = false,
    item_mixedvalue = false,
    liveedit_flags_override = false,
    liveedit_flags = 0,
    b = false,
    col4f = { 1.0, 0.5, 0.0, 1.0 },
    str = ImGui.NewTextBuffer("", 16),
    current = 1,   -- item_type == 14
    current_2 = 1, -- item_type == 15
    embed_all_inside_a_child_window = false,
    test_window = false,
}
function DemoWindowWidgetsQueryingStatuses()
    local s = S.DemoWindowWidgetsQueryingStatuses
    local B = DemoBoolToInt
    if ImGui.TreeNode("Querying Item Status (Edited/Active/Hovered etc.)") then
        IMGUI_DEMO_MARKER("Widgets/Querying Item Status (Edited,Active,Hovered etc.)")
        -- Select an item type
        local item_names =
        {
            "Text", "Button", "Button (w/ repeat)", "Checkbox", "SliderFloat", "InputText", "InputTextMultiline", "InputFloat",
            "InputFloat3", "ColorEdit4", "Selectable", "MenuItem", "TreeNode", "TreeNode (w/ double-click)", "Combo", "ListBox"
        }
        s.item_type = ImGui.Combo("Item Type", s.item_type, item_names, #item_names, #item_names)
        ImGui.SameLine()
        HelpMarker("Testing how various types of items are interacting with the IsItemXXX functions. Note that the bool return value of most ImGui function is generally equivalent to calling ImGui::IsItemHovered().")
        _, s.item_disabled = ImGui.Checkbox("Item Disabled", s.item_disabled)
        _, s.item_mixedvalue = ImGui.Checkbox("Item MixedValue", s.item_mixedvalue)
        _, s.liveedit_flags_override = ImGui.Checkbox("Override LiveEdit:", s.liveedit_flags_override)
        ImGui.SameLine()
        if not s.liveedit_flags_override then
            s.liveedit_flags = ImGui.GetItemFlags()
        end
        ImGui.BeginDisabled(s.liveedit_flags_override == false)
        _, s.liveedit_flags = ImGui.CheckboxFlags("_LiveEditOnInput", s.liveedit_flags, ImGuiItemFlags.LiveEditOnInput)
        ImGui.SameLine()
        _, s.liveedit_flags = ImGui.CheckboxFlags("_LiveEditOnInputText", s.liveedit_flags, ImGuiItemFlags.LiveEditOnInputText)
        ImGui.SameLine()
        _, s.liveedit_flags = ImGui.CheckboxFlags("_LiveEditOnInputScalar", s.liveedit_flags, ImGuiItemFlags.LiveEditOnInputScalar)
        ImGui.EndDisabled()
        if s.liveedit_flags_override then
            ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputText, bit32.band(s.liveedit_flags, ImGuiItemFlags.LiveEditOnInputText) ~= 0)
            ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputScalar, bit32.band(s.liveedit_flags, ImGuiItemFlags.LiveEditOnInputScalar) ~= 0)
        end

        -- Submit selected items so we can query their status in the code following it.
        local ret = false
        local item_type = s.item_type
        local col4f = s.col4f
        if s.item_disabled then
            ImGui.BeginDisabled(true)
        end
        if s.item_mixedvalue then
            ImGui.PushItemFlag(ImGuiItemFlags.MixedValue, true)
        end
        if item_type == 0 then ImGui.Text("ITEM: Text") end                                               -- Testing text items with no identifier/interaction
        if item_type == 1 then ret = ImGui.Button("ITEM: Button") end                                     -- Testing button
        if item_type == 2 then ImGui.PushItemFlag(ImGuiItemFlags.ButtonRepeat, true); ret = ImGui.Button("ITEM: Button"); ImGui.PopItemFlag() end -- Testing button (with repeater)
        if item_type == 3 then ret, s.b = ImGui.Checkbox("ITEM: Checkbox", s.b) end                       -- Testing checkbox
        if item_type == 4 then col4f[1], ret = ImGui.SliderFloat("ITEM: SliderFloat", col4f[1], 0.0, 1.0) end -- Testing basic item
        if item_type == 5 then ret = ImGui.InputText("ITEM: InputText", s.str, 16) end                    -- Testing input text (which handles tabbing)
        if item_type == 6 then ret = ImGui.InputTextMultiline("ITEM: InputTextMultiline", s.str, 16) end  -- Testing input text (which uses a child window)
        if item_type == 7 then col4f[1], ret = ImGui.InputFloat("ITEM: InputFloat", col4f[1], 1.0) end    -- Testing +/- buttons on scalar input
        if item_type == 8 then ret = ImGui.InputFloat3("ITEM: InputFloat3", col4f) end                    -- Testing multi-component items (IsItemXXX flags are reported merged)
        if item_type == 9 then ret = ImGui.ColorEdit4("ITEM: ColorEdit4", col4f) end                      -- Testing multi-component items (IsItemXXX flags are reported merged)
        if item_type == 10 then ret = ImGui.Selectable("ITEM: Selectable") end                            -- Testing selectable item
        if item_type == 11 then ret = ImGui.MenuItem("ITEM: MenuItem") end                                -- Testing menu item (they use ImGuiButtonFlags_PressedOnRelease button policy)
        if item_type == 12 then ret = ImGui.TreeNode("ITEM: TreeNode"); if ret then ImGui.TreePop() end end -- Testing tree node
        if item_type == 13 then ret = ImGui.TreeNodeEx("ITEM: TreeNode w/ ImGuiTreeNodeFlags_OpenOnDoubleClick", bit32.bor(ImGuiTreeNodeFlags.OpenOnDoubleClick, ImGuiTreeNodeFlags.NoTreePushOnOpen)) end -- Testing tree node with ImGuiButtonFlags_PressedOnDoubleClick button policy.
        if item_type == 14 then local items = { "Apple", "Banana", "Cherry", "Kiwi" }; s.current, ret = ImGui.Combo("ITEM: Combo", s.current, items, #items) end
        if item_type == 15 then local items = { "Apple", "Banana", "Cherry", "Kiwi" }; s.current_2, ret = ImGui.ListBox("ITEM: ListBox", s.current_2, items, #items, #items) end

        local hovered_delay_none = ImGui.IsItemHovered()
        local hovered_delay_stationary = ImGui.IsItemHovered(ImGuiHoveredFlags.Stationary)
        local hovered_delay_short = ImGui.IsItemHovered(ImGuiHoveredFlags.DelayShort)
        local hovered_delay_normal = ImGui.IsItemHovered(ImGuiHoveredFlags.DelayNormal)
        local hovered_delay_tooltip = ImGui.IsItemHovered(ImGuiHoveredFlags.ForTooltip) -- = Normal + Stationary

        -- Display the values of IsItemHovered() and other common item state functions.
        -- Note that the ImGuiHoveredFlags_XXX flags can be combined.
        -- Because BulletText is an item itself and that would affect the output of IsItemXXX functions,
        -- we query every state in a single call to avoid storing them and to simplify the code.
        ImGui.BulletText(
            "Return value = %d\n" ..
            "IsItemFocused() = %d\n" ..
            "IsItemHovered() = %d\n" ..
            "IsItemHovered(_AllowWhenBlockedByPopup) = %d\n" ..
            "IsItemHovered(_AllowWhenBlockedByActiveItem) = %d\n" ..
            "IsItemHovered(_AllowWhenOverlappedByItem) = %d\n" ..
            "IsItemHovered(_AllowWhenOverlappedByWindow) = %d\n" ..
            "IsItemHovered(_AllowWhenDisabled) = %d\n" ..
            "IsItemHovered(_RectOnly) = %d\n" ..
            "IsItemActive() = %d\n" ..
            "IsItemEdited() = %d\n" ..
            "IsItemActivated() = %d\n" ..
            "IsItemDeactivated() = %d\n" ..
            "IsItemDeactivatedAfterEdit() = %d\n" ..
            "IsItemVisible() = %d\n" ..
            "IsItemClicked() = %d\n" ..
            "IsItemToggledOpen() = %d\n" ..
            "GetItemRectMin() = (%.1f, %.1f)\n" ..
            "GetItemRectMax() = (%.1f, %.1f)\n" ..
            "GetItemRectSize() = (%.1f, %.1f)",
            B(ret),
            B(ImGui.IsItemFocused()),
            B(ImGui.IsItemHovered()),
            B(ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup)),
            B(ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByActiveItem)),
            B(ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenOverlappedByItem)),
            B(ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenOverlappedByWindow)),
            B(ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenDisabled)),
            B(ImGui.IsItemHovered(ImGuiHoveredFlags.RectOnly)),
            B(ImGui.IsItemActive()),
            B(ImGui.IsItemEdited()),
            B(ImGui.IsItemActivated()),
            B(ImGui.IsItemDeactivated()),
            B(ImGui.IsItemDeactivatedAfterEdit()),
            B(ImGui.IsItemVisible()),
            B(ImGui.IsItemClicked()),
            B(ImGui.IsItemToggledOpen()),
            ImGui.GetItemRectMin().x, ImGui.GetItemRectMin().y,
            ImGui.GetItemRectMax().x, ImGui.GetItemRectMax().y,
            ImGui.GetItemRectSize().x, ImGui.GetItemRectSize().y
        )
        ImGui.BulletText(
            "with Hovering Delay or Stationary test:\n" ..
            "IsItemHovered() = %d\n" ..
            "IsItemHovered(_Stationary) = %d\n" ..
            "IsItemHovered(_DelayShort) = %d\n" ..
            "IsItemHovered(_DelayNormal) = %d\n" ..
            "IsItemHovered(_Tooltip) = %d",
            B(hovered_delay_none), B(hovered_delay_stationary), B(hovered_delay_short), B(hovered_delay_normal), B(hovered_delay_tooltip))

        if s.liveedit_flags_override then
            ImGui.PopItemFlag()
            ImGui.PopItemFlag()
        end
        if s.item_mixedvalue then
            ImGui.PopItemFlag()
        end
        if s.item_disabled then
            ImGui.EndDisabled()
        end

        local buf = ImGui.NewTextBuffer("", 1)
        ImGui.InputText("unused", buf, 1, ImGuiInputTextFlags.ReadOnly)
        ImGui.SameLine()
        HelpMarker("This widget is only here to be able to tab-out of the widgets above and see e.g. Deactivated() status.")

        ImGui.TreePop()
    end

    if ImGui.TreeNode("Querying Window Status (Focused/Hovered etc.)") then
        IMGUI_DEMO_MARKER("Widgets/Querying Window Status (Focused,Hovered etc.)")
        _, s.embed_all_inside_a_child_window = ImGui.Checkbox("Embed everything inside a child window for testing _RootWindow flag.", s.embed_all_inside_a_child_window)
        if s.embed_all_inside_a_child_window then
            ImGui.BeginChild("outer_child", ImVec2(0, ImGui.GetFontSize() * 20.0), ImGuiChildFlags.Borders)
        end

        -- Testing IsWindowFocused() function with its various flags.
        ImGui.BulletText(
            "IsWindowFocused() = %d\n" ..
            "IsWindowFocused(_ChildWindows) = %d\n" ..
            "IsWindowFocused(_ChildWindows|_NoPopupHierarchy) = %d\n" ..
            "IsWindowFocused(_ChildWindows|_DockHierarchy) = %d\n" ..
            "IsWindowFocused(_ChildWindows|_RootWindow) = %d\n" ..
            "IsWindowFocused(_ChildWindows|_RootWindow|_NoPopupHierarchy) = %d\n" ..
            "IsWindowFocused(_ChildWindows|_RootWindow|_DockHierarchy) = %d\n" ..
            "IsWindowFocused(_RootWindow) = %d\n" ..
            "IsWindowFocused(_RootWindow|_NoPopupHierarchy) = %d\n" ..
            "IsWindowFocused(_RootWindow|_DockHierarchy) = %d\n" ..
            "IsWindowFocused(_AnyWindow) = %d\n",
            B(ImGui.IsWindowFocused()),
            B(ImGui.IsWindowFocused(ImGuiFocusedFlags.ChildWindows)),
            B(ImGui.IsWindowFocused(bit32.bor(ImGuiFocusedFlags.ChildWindows, ImGuiFocusedFlags.NoPopupHierarchy))),
            B(ImGui.IsWindowFocused(bit32.bor(ImGuiFocusedFlags.ChildWindows, ImGuiFocusedFlags.DockHierarchy))),
            B(ImGui.IsWindowFocused(bit32.bor(ImGuiFocusedFlags.ChildWindows, ImGuiFocusedFlags.RootWindow))),
            B(ImGui.IsWindowFocused(bit32.bor(ImGuiFocusedFlags.ChildWindows, ImGuiFocusedFlags.RootWindow, ImGuiFocusedFlags.NoPopupHierarchy))),
            B(ImGui.IsWindowFocused(bit32.bor(ImGuiFocusedFlags.ChildWindows, ImGuiFocusedFlags.RootWindow, ImGuiFocusedFlags.DockHierarchy))),
            B(ImGui.IsWindowFocused(ImGuiFocusedFlags.RootWindow)),
            B(ImGui.IsWindowFocused(bit32.bor(ImGuiFocusedFlags.RootWindow, ImGuiFocusedFlags.NoPopupHierarchy))),
            B(ImGui.IsWindowFocused(bit32.bor(ImGuiFocusedFlags.RootWindow, ImGuiFocusedFlags.DockHierarchy))),
            B(ImGui.IsWindowFocused(ImGuiFocusedFlags.AnyWindow)))

        -- Testing IsWindowHovered() function with its various flags.
        ImGui.BulletText(
            "IsWindowHovered() = %d\n" ..
            "IsWindowHovered(_AllowWhenBlockedByPopup) = %d\n" ..
            "IsWindowHovered(_AllowWhenBlockedByActiveItem) = %d\n" ..
            "IsWindowHovered(_ChildWindows) = %d\n" ..
            "IsWindowHovered(_ChildWindows|_NoPopupHierarchy) = %d\n" ..
            "IsWindowHovered(_ChildWindows|_DockHierarchy) = %d\n" ..
            "IsWindowHovered(_ChildWindows|_RootWindow) = %d\n" ..
            "IsWindowHovered(_ChildWindows|_RootWindow|_NoPopupHierarchy) = %d\n" ..
            "IsWindowHovered(_ChildWindows|_RootWindow|_DockHierarchy) = %d\n" ..
            "IsWindowHovered(_RootWindow) = %d\n" ..
            "IsWindowHovered(_RootWindow|_NoPopupHierarchy) = %d\n" ..
            "IsWindowHovered(_RootWindow|_DockHierarchy) = %d\n" ..
            "IsWindowHovered(_ChildWindows|_AllowWhenBlockedByPopup) = %d\n" ..
            "IsWindowHovered(_AnyWindow) = %d\n" ..
            "IsWindowHovered(_Stationary) = %d\n",
            B(ImGui.IsWindowHovered()),
            B(ImGui.IsWindowHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup)),
            B(ImGui.IsWindowHovered(ImGuiHoveredFlags.AllowWhenBlockedByActiveItem)),
            B(ImGui.IsWindowHovered(ImGuiHoveredFlags.ChildWindows)),
            B(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.ChildWindows, ImGuiHoveredFlags.NoPopupHierarchy))),
            B(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.ChildWindows, ImGuiHoveredFlags.DockHierarchy))),
            B(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.ChildWindows, ImGuiHoveredFlags.RootWindow))),
            B(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.ChildWindows, ImGuiHoveredFlags.RootWindow, ImGuiHoveredFlags.NoPopupHierarchy))),
            B(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.ChildWindows, ImGuiHoveredFlags.RootWindow, ImGuiHoveredFlags.DockHierarchy))),
            B(ImGui.IsWindowHovered(ImGuiHoveredFlags.RootWindow)),
            B(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.RootWindow, ImGuiHoveredFlags.NoPopupHierarchy))),
            B(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.RootWindow, ImGuiHoveredFlags.DockHierarchy))),
            B(ImGui.IsWindowHovered(bit32.bor(ImGuiHoveredFlags.ChildWindows, ImGuiHoveredFlags.AllowWhenBlockedByPopup))),
            B(ImGui.IsWindowHovered(ImGuiHoveredFlags.AnyWindow)),
            B(ImGui.IsWindowHovered(ImGuiHoveredFlags.Stationary)))

        ImGui.BeginChild("child", ImVec2(0, 50), ImGuiChildFlags.Borders)
        ImGui.Text("This is another child window for testing the _ChildWindows flag.")
        ImGui.EndChild()
        if s.embed_all_inside_a_child_window then
            ImGui.EndChild()
        end

        -- Calling IsItemHovered() after begin returns the hovered status of the title bar.
        -- This is useful in particular if you want to create a context menu associated to the title bar of a window.
        -- This will also work when docked into a Tab (the Tab replace the Title Bar and guarantee the same properties).
        _, s.test_window = ImGui.Checkbox("Hovered/Active tests after Begin() for title bar testing", s.test_window)
        if s.test_window then
            -- FIXME-DOCK: This window cannot be docked within the ImGui Demo window, this will cause a feedback loop and get them stuck.
            -- Could we fix this through an ImGuiWindowClass feature? Or an API call to tag our parent as "don't skip items"?
            s.test_window = ImGui.Begin("Title bar Hovered/Active tests", s.test_window)
            if ImGui.BeginPopupContextItem() then -- <-- This is using IsItemHovered()
                if ImGui.MenuItem("Close") then s.test_window = false end
                ImGui.EndPopup()
            end
            ImGui.Text(
                "IsItemHovered() after begin = %d (== is title bar hovered)\n" ..
                "IsItemActive() after begin = %d (== is window being clicked/moved)\n",
                B(ImGui.IsItemHovered()), B(ImGui.IsItemActive()))
            ImGui.End()
        end

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsSelectables()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsSelectables = {
    selection = { false, true, false, false, false },                   -- Basic
    selected_multi = { false, false, false },                           -- Multiple items on the same line (1)
    checked = { false, false, false, false, false },                    -- Multiple items on the same line (2)
    selected_n = 0,
    selected_tables = { false, false, false, false, false, false, false, false, false, false }, -- In Tables
    selected_grid = { { 1, 0, 0, 0 }, { 0, 1, 0, 0 }, { 0, 0, 1, 0 }, { 0, 0, 0, 1 } },        -- Grid
    selected_align = { true, false, true, false, true, false, true, false, true },              -- Alignment
}
-- [Port] The Selectable(label, bool* p_selected) overload doesn't exist in this port (Selectable returns pressed, selected
-- without toggling): written as `if ImGui.Selectable(label, sel) then sel = not sel end`.
function DemoWindowWidgetsSelectables()
    local s = S.DemoWindowWidgetsSelectables
    -- ImGui.SetNextItemOpen(true, ImGuiCond.Once)
    if ImGui.TreeNode("Selectables") then
        IMGUI_DEMO_MARKER("Widgets/Selectables")
        -- Selectable() has 2 overloads:
        -- - The one taking "bool selected" as a read-only selection information.
        --   When Selectable() has been clicked it returns true and you can alter selection state accordingly.
        -- - The one taking "bool* p_selected" as a read-write selection information (convenient in some cases)
        -- The earlier is more flexible, as in real application your selection may be stored in many different ways
        -- and not necessarily inside a bool value (e.g. in flags within objects, as an external list, etc).
        IMGUI_DEMO_MARKER("Widgets/Selectables/Basic")
        if ImGui.TreeNode("Basic") then
            local selection = s.selection
            if ImGui.Selectable("1. I am selectable", selection[1]) then selection[1] = not selection[1] end
            if ImGui.Selectable("2. I am selectable", selection[2]) then selection[2] = not selection[2] end
            if ImGui.Selectable("3. I am selectable", selection[3]) then selection[3] = not selection[3] end
            if ImGui.Selectable("4. I am double clickable", selection[4], ImGuiSelectableFlags.AllowDoubleClick) then
                if ImGui.IsMouseDoubleClicked(0) then
                    selection[4] = not selection[4]
                end
            end
            ImGui.TreePop()
        end

        IMGUI_DEMO_MARKER("Widgets/Selectables/Rendering more items on the same line")
        if ImGui.TreeNode("Multiple items on the same line") then
            IMGUI_DEMO_MARKER("Widgets/Selectables/Multiple items on the same line")
            -- - Using SetNextItemAllowOverlap()
            -- - Using the Selectable() override that takes "bool* p_selected" parameter, the bool value is toggled automatically.
            do
                local selected = s.selected_multi
                ImGui.SetNextItemAllowOverlap(); if ImGui.Selectable("main.c", selected[1]) then selected[1] = not selected[1] end; ImGui.SameLine(); ImGui.SmallButton("Link 1")
                ImGui.SetNextItemAllowOverlap(); if ImGui.Selectable("hello.cpp", selected[2]) then selected[2] = not selected[2] end; ImGui.SameLine(); ImGui.SmallButton("Link 2")
                ImGui.SetNextItemAllowOverlap(); if ImGui.Selectable("hello.h", selected[3]) then selected[3] = not selected[3] end; ImGui.SameLine(); ImGui.SmallButton("Link 3")
            end

            -- (2)
            -- - Using ImGuiSelectableFlags_AllowOverlap is a shortcut for calling SetNextItemAllowOverlap()
            -- - No visible label, display contents inside the selectable bounds.
            -- - We don't maintain actual selection in this example to keep things simple.
            ImGui.Spacing()
            do
                local checked = s.checked
                local color_marker_w = ImGui.CalcTextSize("x").x
                for n = 0, 4 do
                    ImGui.PushID(n)
                    ImGui.AlignTextToFramePadding()
                    if ImGui.Selectable("##selectable", s.selected_n == n, ImGuiSelectableFlags.AllowOverlap) then
                        s.selected_n = n
                    end
                    ImGui.SameLine(0, 0)
                    _, checked[n + 1] = ImGui.Checkbox("##check", checked[n + 1])
                    ImGui.SameLine()
                    local color = ImVec4(bit32.band(n, 1) ~= 0 and 1.0 or 0.2, bit32.band(n, 2) ~= 0 and 1.0 or 0.2, 0.2, 1.0)
                    ImGui.ColorButton("##color", color, ImGuiColorEditFlags.NoTooltip, ImVec2(color_marker_w, 0))
                    ImGui.SameLine()
                    ImGui.Text("Some label")
                    ImGui.PopID()
                end
            end

            ImGui.TreePop()
        end

        if ImGui.TreeNode("In Tables") then
            IMGUI_DEMO_MARKER("Widgets/Selectables/In Tables")
            local selected = s.selected_tables

            if ImGui.BeginTable("split1", 3, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.NoSavedSettings, ImGuiTableFlags.Borders)) then
                for i = 0, 9 do
                    local label = string.format("Item %d", i)
                    ImGui.TableNextColumn()
                    if ImGui.Selectable(label, selected[i + 1]) then selected[i + 1] = not selected[i + 1] end -- FIXME-TABLE: Selection overlap
                end
                ImGui.EndTable()
            end
            ImGui.Spacing()
            if ImGui.BeginTable("split2", 3, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.NoSavedSettings, ImGuiTableFlags.Borders)) then
                for i = 0, 9 do
                    local label = string.format("Item %d", i)
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    if ImGui.Selectable(label, selected[i + 1], ImGuiSelectableFlags.SpanAllColumns) then selected[i + 1] = not selected[i + 1] end
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
            IMGUI_DEMO_MARKER("Widgets/Selectables/Grid")
            local selected = s.selected_grid

            -- Add in a bit of silly fun...
            local time = ImGui.GetTime()
            local winning_state = true -- If all cells are selected...
            for y = 1, 4 do for x = 1, 4 do if selected[y][x] == 0 then winning_state = false end end end -- [Port] memchr(selected, 0, sizeof(selected)) == NULL
            if winning_state then
                ImGui.PushStyleVar(ImGuiStyleVar.SelectableTextAlign, ImVec2(0.5 + 0.5 * math.cos(time * 2.0), 0.5 + 0.5 * math.sin(time * 3.0)))
            end

            local size = ImGui.CalcTextSize("Sailor").x
            for y = 0, 3 do
                for x = 0, 3 do
                    if x > 0 then
                        ImGui.SameLine()
                    end
                    ImGui.PushID(y * 4 + x)
                    if ImGui.Selectable("Sailor", selected[y + 1][x + 1] ~= 0, 0, ImVec2(size, size)) then
                        -- Toggle clicked cell + toggle neighbors
                        selected[y + 1][x + 1] = bit32.bxor(selected[y + 1][x + 1], 1)
                        if x > 0 then selected[y + 1][x] = bit32.bxor(selected[y + 1][x], 1) end
                        if x < 3 then selected[y + 1][x + 2] = bit32.bxor(selected[y + 1][x + 2], 1) end
                        if y > 0 then selected[y][x + 1] = bit32.bxor(selected[y][x + 1], 1) end
                        if y < 3 then selected[y + 2][x + 1] = bit32.bxor(selected[y + 2][x + 1], 1) end
                    end
                    ImGui.PopID()
                end
            end

            if winning_state then
                ImGui.PopStyleVar()
            end
            ImGui.TreePop()
        end
        if ImGui.TreeNode("Alignment") then
            IMGUI_DEMO_MARKER("Widgets/Selectables/Alignment")
            HelpMarker(
                "By default, Selectables uses style.SelectableTextAlign but it can be overridden on a per-item " ..
                "basis using PushStyleVar(). You'll probably want to always keep your default situation to " ..
                "left-align otherwise it becomes difficult to layout multiple items on a same line")

            local selected = s.selected_align
            local size = ImGui.CalcTextSize("(1.0,1.0)").x
            for y = 0, 2 do
                for x = 0, 2 do
                    local alignment = ImVec2(x / 2.0, y / 2.0)
                    local name = string.format("(%.1f,%.1f)", alignment.x, alignment.y)
                    if x > 0 then ImGui.SameLine() end
                    ImGui.PushStyleVar(ImGuiStyleVar.SelectableTextAlign, alignment)
                    local idx = 3 * y + x + 1
                    if ImGui.Selectable(name, selected[idx], ImGuiSelectableFlags.None, ImVec2(size, size)) then selected[idx] = not selected[idx] end
                    ImGui.PopStyleVar()
                end
            end
            ImGui.TreePop()
        end
        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsSelectionAndMultiSelect()
-------------------------------------------------------------------------------
-- Multi-selection demos
-- Also read: https://github.com/ocornut/imgui/wiki/Multi-Select
-------------------------------------------------------------------------------

ExampleNames =
{
    "Artichoke", "Arugula", "Asparagus", "Avocado", "Bamboo Shoots", "Bean Sprouts", "Beans", "Beet", "Belgian Endive", "Bell Pepper",
    "Bitter Gourd", "Bok Choy", "Broccoli", "Brussels Sprouts", "Burdock Root", "Cabbage", "Calabash", "Capers", "Carrot", "Cassava",
    "Cauliflower", "Celery", "Celery Root", "Celcuce", "Chayote", "Chinese Broccoli", "Corn", "Cucumber"
}

-- Extra functions to add deletion support to ImGuiSelectionBasicStorage
-- [Port] "struct ExampleSelectionWithDeletion : ImGuiSelectionBasicStorage": an ImGuiSelectionBasicStorage() object whose
-- metatable chains to the library's ImGuiSelectionBasicStorage methods.
ExampleSelectionWithDeletionMT = {}
ExampleSelectionWithDeletionMT.__index = ExampleSelectionWithDeletionMT
function ExampleSelectionWithDeletion()
    local self = ImGuiSelectionBasicStorage()
    if getmetatable(ExampleSelectionWithDeletionMT) == nil then
        setmetatable(ExampleSelectionWithDeletionMT, { __index = getmetatable(self) }) -- [Port] inherit ImGuiSelectionBasicStorage methods
    end
    return setmetatable(self, ExampleSelectionWithDeletionMT)
end

-- Find which item should be Focused after deletion.
-- Call _before_ item submission. Return an index in the before-deletion item list, your item loop should call SetKeyboardFocusHere() on it.
-- The subsequent ApplyDeletionPostLoop() code will use it to apply Selection.
-- - We cannot provide this logic in core Dear ImGui because we don't have access to selection data.
-- - We don't actually manipulate the ImVector<> here, only in ApplyDeletionPostLoop(), but using similar API for consistency and flexibility.
-- - Important: Deletion only works if the underlying ImGuiID for your items are stable: aka not depend on their index, but on e.g. item id/ptr.
-- FIXME-MULTISELECT: Doesn't take account of the possibility focus target will be moved during deletion. Need refocus or scroll offset.
function ExampleSelectionWithDeletionMT:ApplyDeletionPreLoop(ms_io, items_count)
    if self.Size == 0 then
        return -1
    end

    -- If focused item is not selected...
    local focused_idx = ms_io.NavIdItem  -- Index of currently focused item
    if ms_io.NavIdSelected == false then  -- This is merely a shortcut, == Contains(adapter->IndexToStorage(items, focused_idx))
        ms_io.RangeSrcReset = true    -- Request to recover RangeSrc from NavId next frame. Would be ok to reset even when NavIdSelected==true, but it would take an extra frame to recover RangeSrc when deleting a selected item.
        return focused_idx            -- Request to focus same item after deletion.
    end

    -- If focused item is selected: land on first unselected item after focused item.
    for idx = focused_idx + 1, items_count - 1 do
        if not self:Contains(self:GetStorageIdFromIndex(idx)) then
            return idx
        end
    end

    -- If focused item is selected: otherwise return last unselected item before focused item.
    for idx = ImMin(focused_idx, items_count) - 1, 0, -1 do
        if not self:Contains(self:GetStorageIdFromIndex(idx)) then
            return idx
        end
    end

    return -1
end

-- Rewrite item list (delete items) + update selection.
-- - Call after EndMultiSelect()
-- - We cannot provide this logic in core Dear ImGui because we don't have access to your items, nor to selection data.
-- [Port] items: ImVector (1-based .Data), swapped in place with the rebuilt list.
function ExampleSelectionWithDeletionMT:ApplyDeletionPostLoop(ms_io, items, item_curr_idx_to_select)
    -- Rewrite item list (delete items) + convert old selection index (before deletion) to new selection index (after selection).
    -- If NavId was not part of selection, we will stay on same item.
    local new_items = ImVector()
    new_items:reserve(items.Size - self.Size)
    local item_next_idx_to_select = -1
    for idx = 0, items.Size - 1 do
        if not self:Contains(self:GetStorageIdFromIndex(idx)) then
            new_items:push_back(items.Data[idx + 1])
        end
        if item_curr_idx_to_select == idx then
            item_next_idx_to_select = new_items.Size - 1
        end
    end
    items:swap(new_items)

    -- Update selection
    self:Clear()
    if item_next_idx_to_select ~= -1 and ms_io.NavIdSelected then
        self:SetItemSelected(self:GetStorageIdFromIndex(item_next_idx_to_select), true)
    end
end

-- Example: Implement dual list box storage and interface
ExampleDualListBoxMT = {}
ExampleDualListBoxMT.__index = ExampleDualListBoxMT
function ExampleDualListBox()
    local self = setmetatable({}, ExampleDualListBoxMT)
    self.Items = { ImVector(), ImVector() }                                           -- ID is index into ExampleName[] -- [Port] 1-based: Items[side + 1]
    self.Selections = { ImGuiSelectionBasicStorage(), ImGuiSelectionBasicStorage() }  -- Store ExampleItemId into selection -- [Port] 1-based: Selections[side + 1]
    self.OptKeepSorted = true
    return self
end

function ExampleDualListBoxMT:MoveAll(src, dst)
    IM_ASSERT((src == 0 and dst == 1) or (src == 1 and dst == 0))
    for _, item_id in self.Items[src + 1]:iter() do
        self.Items[dst + 1]:push_back(item_id)
    end
    self.Items[src + 1]:clear()
    self:SortItems(dst)
    self.Selections[src + 1]:Swap(self.Selections[dst + 1])
    self.Selections[src + 1]:Clear()
end
function ExampleDualListBoxMT:MoveSelected(src, dst)
    local src_n = 0 -- [Port] while loop: the C++ for loop decrements src_n
    while src_n < self.Items[src + 1].Size do
        repeat
            local item_id = self.Items[src + 1].Data[src_n + 1]
            if not self.Selections[src + 1]:Contains(item_id) then
                break -- continue
            end
            self.Items[src + 1]:erase(src_n + 1) -- FIXME-OPT: Could be implemented more optimally (rebuild src items and swap)
            self.Items[dst + 1]:push_back(item_id)
            src_n = src_n - 1
        until true
        src_n = src_n + 1
    end
    if self.OptKeepSorted then
        self:SortItems(dst)
    end
    self.Selections[src + 1]:Swap(self.Selections[dst + 1])
    self.Selections[src + 1]:Clear()
end
function ExampleDualListBoxMT:ApplySelectionRequests(ms_io, side)
    -- In this example we store item id in selection (instead of item index)
    self.Selections[side + 1].UserData = self.Items[side + 1].Data
    self.Selections[side + 1].AdapterIndexToStorageId = function(self_, idx) local items = self_.UserData; return items[idx + 1] end
    self.Selections[side + 1]:ApplyRequests(ms_io)
end
-- [Port] table.sort() comparator: returns 'lhs < rhs' instead of '*a - *b'
function ExampleDualListBoxMT.CompareItemsByValue(lhs, rhs)
    return lhs < rhs
end
function ExampleDualListBoxMT:SortItems(n)
    if self.Items[n + 1].Size > 0 then -- [Port] .Data is nil for an empty ImVector
        table.sort(self.Items[n + 1].Data, ExampleDualListBoxMT.CompareItemsByValue) -- [Port] .Data holds exactly .Size items here (only push_back/erase/clear are used)
    end
end
function ExampleDualListBoxMT:Show()
    --if (ImGui::Checkbox("Sorted", &OptKeepSorted) && OptKeepSorted) { SortItems(0); SortItems(1); }
    if ImGui.BeginTable("split", 3, ImGuiTableFlags.None) then
        ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthStretch)    -- Left side
        ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed)      -- Buttons
        ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthStretch)    -- Right side
        ImGui.TableNextRow()

        local request_move_selected = -1
        local request_move_all = -1
        local child_height_0 = 0.0
        for side = 0, 1 do
            -- FIXME-MULTISELECT: Dual List Box: Add context menus
            -- FIXME-NAV: Using ImGuiWindowFlags_NavFlattened exhibit many issues.
            local items = self.Items[side + 1]
            local selection = self.Selections[side + 1]

            ImGui.TableSetColumnIndex((side == 0) and 0 or 2)
            ImGui.Text("%s (%d)", (side == 0) and "Available" or "Basket", items.Size)

            -- Submit scrolling range to avoid glitches on moving/deletion
            local items_height = ImGui.GetTextLineHeightWithSpacing()
            ImGui.SetNextWindowContentSize(ImVec2(0.0, items.Size * items_height))

            local child_visible
            if side == 0 then
                -- Left child is resizable
                ImGui.SetNextWindowSizeConstraints(ImVec2(0.0, ImGui.GetFrameHeightWithSpacing() * 4), ImVec2(FLT_MAX, FLT_MAX))
                child_visible = ImGui.BeginChild("0", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY))
                child_height_0 = ImGui.GetWindowSize().y
            else
                -- Right child use same height as left one
                child_visible = ImGui.BeginChild("1", ImVec2(-FLT_MIN, child_height_0), ImGuiChildFlags.FrameStyle)
            end
            if child_visible then
                local flags = ImGuiMultiSelectFlags.BoxSelect1d
                local ms_io = ImGui.BeginMultiSelect(flags, selection.Size, items.Size)
                self:ApplySelectionRequests(ms_io, side)

                for item_n = 0, items.Size - 1 do
                    local item_id = items.Data[item_n + 1]
                    local item_is_selected = selection:Contains(item_id)
                    ImGui.SetNextItemSelectionUserData(item_n)
                    ImGui.Selectable(ExampleNames[item_id + 1], item_is_selected, ImGuiSelectableFlags.AllowDoubleClick)
                    if ImGui.IsItemFocused() then
                        -- FIXME-MULTISELECT: Dual List Box: Transfer focus
                        if ImGui.IsKeyPressed(ImGuiKey.Enter) or ImGui.IsKeyPressed(ImGuiKey.KeypadEnter) then
                            request_move_selected = side
                        end
                        if ImGui.IsMouseDoubleClicked(0) then -- FIXME-MULTISELECT: Double-click on multi-selection?
                            request_move_selected = side
                        end
                    end
                end

                ms_io = ImGui.EndMultiSelect()
                self:ApplySelectionRequests(ms_io, side)
            end
            ImGui.EndChild()
        end

        -- Buttons columns
        ImGui.TableSetColumnIndex(1)
        ImGui.NewLine()
        --ImVec2 button_sz = { ImGui::CalcTextSize(">>").x + ImGui::GetStyle().FramePadding.x * 2.0f, ImGui::GetFrameHeight() + padding.y * 2.0f };
        local button_sz = ImVec2(ImGui.GetFrameHeight(), ImGui.GetFrameHeight())

        -- (Using BeginDisabled()/EndDisabled() works but feels distracting given how it is currently visualized)
        if ImGui.Button(">>", button_sz) then
            request_move_all = 0
        end
        if ImGui.Button(">", button_sz) then
            request_move_selected = 0
        end
        if ImGui.Button("<", button_sz) then
            request_move_selected = 1
        end
        if ImGui.Button("<<", button_sz) then
            request_move_all = 1
        end

        -- Process requests
        if request_move_all ~= -1 then
            self:MoveAll(request_move_all, bit32.bxor(request_move_all, 1))
        end
        if request_move_selected ~= -1 then
            self:MoveSelected(request_move_selected, bit32.bxor(request_move_selected, 1))
        end

        -- FIXME-MULTISELECT: Support action from outside
        --[[
        if (OptKeepSorted == false)
        {
            ImGui::NewLine();
            if (ImGui::ArrowButton("MoveUp", ImGuiDir_Up)) {}
            if (ImGui::ArrowButton("MoveDown", ImGuiDir_Down)) {}
        }
        ]]

        ImGui.EndTable()
    end
end

-- [Port] struct ExampleTreeFuncs is local to DemoWindowWidgetsSelectionAndMultiSelect() upstream ("Multi-Select (trees)"):
-- hoisted to file level (global table) so its functions are not re-created every frame.
ExampleTreeFuncs = {}

function ExampleTreeFuncs.DrawNode(node, selection)
    local tree_node_flags = bit32.bor(ImGuiTreeNodeFlags.SpanAvailWidth, ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick)
    tree_node_flags = bit32.bor(tree_node_flags, ImGuiTreeNodeFlags.NavLeftJumpsToParent) -- Enable pressing left to jump to parent
    if #node.Childs == 0 then
        tree_node_flags = bit32.bor(tree_node_flags, ImGuiTreeNodeFlags.Bullet, ImGuiTreeNodeFlags.Leaf)
    end
    if selection:Contains(node.UID) then
        tree_node_flags = bit32.bor(tree_node_flags, ImGuiTreeNodeFlags.Selected)
    end

    -- Using SetNextItemStorageID() to specify storage id, so we can easily peek into
    -- the storage holding open/close stage, using our TreeNodeGetOpen/TreeNodeSetOpen() functions.
    ImGui.SetNextItemSelectionUserData(node) -- [Port] the node table itself is the selection user data (C++ casts the pointer)
    ImGui.SetNextItemStorageID(node.UID)
    if ImGui.TreeNodeEx(node.Name, tree_node_flags) then
        for _, child in ipairs(node.Childs) do
            ExampleTreeFuncs.DrawNode(child, selection)
        end
        ImGui.TreePop()
    elseif ImGui.IsItemToggledOpen() then
        ExampleTreeFuncs.TreeCloseAndUnselectChildNodes(node, selection)
    end
end

-- When closing a node: 1) close and unselect all child nodes, 2) select parent if any child was selected.
-- FIXME: This is currently handled by user logic but I'm hoping to eventually provide tree node
-- features to do this automatically, e.g. a ImGuiTreeNodeFlags_AutoCloseChildNodes etc.
function ExampleTreeFuncs.TreeCloseAndUnselectChildNodes(node, selection, depth)
    if depth == nil then depth = 0 end
    -- Recursive close (the test for depth == 0 is because we call this on a node that was just closed!)
    local unselected_count = selection:Contains(node.UID) and 1 or 0
    if depth == 0 or ImGui.TreeNodeGetOpen(node.UID) then
        for _, child in ipairs(node.Childs) do
            unselected_count = unselected_count + ExampleTreeFuncs.TreeCloseAndUnselectChildNodes(child, selection, depth + 1)
        end
        ImGui.TreeNodeSetOpen(node.UID, false)
    end

    -- Select root node if any of its child was selected, otherwise unselect
    selection:SetItemSelected(node.UID, (depth == 0 and unselected_count > 0))
    return unselected_count
end

-- Apply multi-selection requests
function ExampleTreeFuncs.ApplySelectionRequests(ms_io, tree, selection)
    for _, req in ms_io.Requests:iter() do
        if req.Type == ImGuiSelectionRequestType.SetAll then
            if req.Selected then
                ExampleTreeFuncs.TreeSetAllInOpenNodes(tree, selection, req.Selected)
            else
                selection:Clear()
            end
        elseif req.Type == ImGuiSelectionRequestType.SetRange then
            local first_node = req.RangeFirstItem
            local last_node = req.RangeLastItem
            local node = first_node
            while node ~= nil do
                selection:SetItemSelected(node.UID, req.Selected)
                node = ExampleTreeFuncs.TreeGetNextNodeInVisibleOrder(node, last_node)
            end
        end
    end
end

function ExampleTreeFuncs.TreeSetAllInOpenNodes(node, selection, selected)
    if node.Parent ~= nil then -- Root node isn't visible nor selectable in our scheme
        selection:SetItemSelected(node.UID, selected)
    end
    if node.Parent == nil or ImGui.TreeNodeGetOpen(node.UID) then
        for _, child in ipairs(node.Childs) do
            ExampleTreeFuncs.TreeSetAllInOpenNodes(child, selection, selected)
        end
    end
end

-- Interpolate in *user-visible order* AND only *over opened nodes*.
-- If you have a sequential mapping tables (e.g. generated after a filter/search pass) this would be simpler.
-- Here the tricks are that:
-- - we store/maintain ExampleTreeNode::IndexInParent which allows implementing a linear iterator easily, without searches, without recursion.
--   this could be replaced by a search in parent, aka 'int index_in_parent = curr_node->Parent->Childs.find_index(curr_node)'
--   which would only be called when crossing from child to a parent, aka not too much.
-- - we call SetNextItemStorageID() before our TreeNode() calls with an ID which doesn't relate to UI stack,
--   making it easier to call TreeNodeGetOpen()/TreeNodeSetOpen() from any location.
function ExampleTreeFuncs.TreeGetNextNodeInVisibleOrder(curr_node, last_node)
    -- Reached last node
    if curr_node == last_node then
        return nil
    end

    -- Recurse into childs. Query storage to tell if the node is open.
    if #curr_node.Childs > 0 and ImGui.TreeNodeGetOpen(curr_node.UID) then
        return curr_node.Childs[1]
    end

    -- Next sibling, then into our own parent
    while curr_node.Parent ~= nil do
        if curr_node.IndexInParent + 1 < #curr_node.Parent.Childs then
            return curr_node.Parent.Childs[curr_node.IndexInParent + 1 + 1] -- [Port] Childs is 1-based, IndexInParent 0-based
        end
        curr_node = curr_node.Parent
    end
    return nil
end

S.DemoWindowWidgetsSelectionAndMultiSelect = {
    single_select = { selected = -1 },
    manual = { selection = { false, false, false, false, false } },
    multi_select = { selection = ImGuiSelectionBasicStorage() },
    with_clipper = { selection = ImGuiSelectionBasicStorage() },
    with_deletion = { items = ImVector(), selection = ExampleSelectionWithDeletion(), items_next_id = 0 },
    dual_list_box = { dlb = ExampleDualListBox() },
    in_a_table = { selection = ImGuiSelectionBasicStorage() },
    checkboxes = {
        items = { false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false },
        flags = bit32.bor(ImGuiMultiSelectFlags.NoAutoSelect, ImGuiMultiSelectFlags.NoAutoClear, ImGuiMultiSelectFlags.ClearOnEscape),
    },
    multiple_scopes = {
        selections_data = { ImGuiSelectionBasicStorage(), ImGuiSelectionBasicStorage(), ImGuiSelectionBasicStorage() }, -- [Port] 1-based
        flags = bit32.bor(ImGuiMultiSelectFlags.ScopeRect, ImGuiMultiSelectFlags.ClearOnEscape), -- | ImGuiMultiSelectFlags_ClearOnClickVoid;
    },
    trees = { selection = ImGuiSelectionBasicStorage() },
    advanced = {
        use_clipper = true,
        use_deletion = true,
        use_drag_drop = true,
        show_in_table = false,
        show_color_button = true,
        flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.BoxSelect1d),
        widget_type = 0, -- WidgetType_Selectable
        items = ImVector(),
        items_next_id = 0,
        selection = ExampleSelectionWithDeletion(),
        request_deletion_from_menu = false, -- Queue deletion triggered from context menu
        item_category_bufs = {}, -- [Port] read-only InputText() byte buffers, per ExampleNames[] entry
    },
}

function DemoWindowWidgetsSelectionAndMultiSelect(demo_data)
    local s = S.DemoWindowWidgetsSelectionAndMultiSelect
    if ImGui.TreeNode("Selection State & Multi-Select") then
        IMGUI_DEMO_MARKER("Widgets/Selection State & Multi-Select")
        HelpMarker("Selections can be built using Selectable(), TreeNode() or other widgets. Selection state is owned by application code/data.")

        ImGui.BulletText("Wiki page:")
        ImGui.SameLine()
        ImGui.TextLinkOpenURL("imgui/wiki/Multi-Select", "https://github.com/ocornut/imgui/wiki/Multi-Select")

        -- Without any fancy API: manage single-selection yourself.
        if ImGui.TreeNode("Single-Select") then
            IMGUI_DEMO_MARKER("Widgets/Selection State/Single-Select")
            local st = s.single_select
            for n = 0, 4 do
                local buf = string.format("Object %d", n)
                if ImGui.Selectable(buf, st.selected == n) then
                    st.selected = n
                end
            end
            ImGui.TreePop()
        end

        -- Demonstrate implementation a most-basic form of multi-selection manually
        -- This doesn't support the Shift modifier which requires BeginMultiSelect()!
        if ImGui.TreeNode("Multi-Select (manual/simplified, without BeginMultiSelect)") then
            IMGUI_DEMO_MARKER("Widgets/Selection State/Multi-Select (manual/simplified, without BeginMultiSelect)")
            HelpMarker("Hold Ctrl and Click to select multiple items.")
            local selection = s.manual.selection
            for n = 0, 4 do
                local buf = string.format("Object %d", n)
                if ImGui.Selectable(buf, selection[n + 1]) then
                    if not ImGui.GetIO().KeyCtrl then -- Clear selection when Ctrl is not held
                        for i = 1, 5 do selection[i] = false end
                    end
                    selection[n + 1] = not selection[n + 1] -- Toggle current item
                end
            end
            ImGui.TreePop()
        end

        -- Demonstrate handling proper multi-selection using the BeginMultiSelect/EndMultiSelect API.
        -- Shift+Click w/ Ctrl and other standard features are supported.
        -- We use the ImGuiSelectionBasicStorage helper which you may freely reimplement.
        if ImGui.TreeNode("Multi-Select") then
            IMGUI_DEMO_MARKER("Widgets/Selection State/Multi-Select")
            ImGui.Text("Supported features:")
            ImGui.BulletText("Keyboard navigation (arrows, page up/down, home/end, space).")
            ImGui.BulletText("Ctrl modifier to preserve and toggle selection.")
            ImGui.BulletText("Shift modifier for range selection.")
            ImGui.BulletText("Ctrl+A to select all.")
            ImGui.BulletText("Escape to clear selection.")
            ImGui.BulletText("Click and drag to box-select.")
            ImGui.Text("Tip: Use 'Demo->Tools->Debug Log->Selection' to see selection requests as they happen.")

            -- Use default selection.Adapter: Pass index to SetNextItemSelectionUserData(), store index in Selection
            local ITEMS_COUNT = 50
            local selection = s.multi_select.selection
            ImGui.Text("Selection: %d/%d", selection.Size, ITEMS_COUNT)

            -- The BeginChild() has no purpose for selection logic, other that offering a scrolling region.
            if ImGui.BeginChild("##Basket", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY)) then
                local flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.BoxSelect1d)
                local ms_io = ImGui.BeginMultiSelect(flags, selection.Size, ITEMS_COUNT)
                selection:ApplyRequests(ms_io)

                for n = 0, ITEMS_COUNT - 1 do
                    local label = string.format("Object %05d: %s", n, ExampleNames[n % #ExampleNames + 1])
                    local item_is_selected = selection:Contains(n)
                    ImGui.SetNextItemSelectionUserData(n)
                    ImGui.Selectable(label, item_is_selected)
                end

                ms_io = ImGui.EndMultiSelect()
                selection:ApplyRequests(ms_io)
            end
            ImGui.EndChild()
            ImGui.TreePop()
        end

        -- Demonstrate using the clipper with BeginMultiSelect()/EndMultiSelect()
        if ImGui.TreeNode("Multi-Select (with clipper)") then
            IMGUI_DEMO_MARKER("Widgets/Selection State/Multi-Select (with clipper)")
            -- Use default selection.Adapter: Pass index to SetNextItemSelectionUserData(), store index in Selection
            local selection = s.with_clipper.selection

            ImGui.Text("Added features:")
            ImGui.BulletText("Using ImGuiListClipper.")

            local ITEMS_COUNT = 10000
            ImGui.Text("Selection: %d/%d", selection.Size, ITEMS_COUNT)
            if ImGui.BeginChild("##Basket", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY)) then
                local flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.BoxSelect1d)
                local ms_io = ImGui.BeginMultiSelect(flags, selection.Size, ITEMS_COUNT)
                selection:ApplyRequests(ms_io)

                local clipper = ImGuiListClipper()
                clipper:Begin(ITEMS_COUNT)
                if ms_io.RangeSrcItem ~= -1 then
                    clipper:IncludeItemByIndex(ms_io.RangeSrcItem) -- Ensure RangeSrc item is not clipped.
                end
                while clipper:Step() do
                    for n = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                        local label = string.format("Object %05d: %s", n, ExampleNames[n % #ExampleNames + 1])
                        local item_is_selected = selection:Contains(n)
                        ImGui.SetNextItemSelectionUserData(n)
                        ImGui.Selectable(label, item_is_selected)
                    end
                end

                ms_io = ImGui.EndMultiSelect()
                selection:ApplyRequests(ms_io)
            end
            ImGui.EndChild()
            ImGui.TreePop()
        end

        -- Demonstrate dynamic item list + deletion support using the BeginMultiSelect/EndMultiSelect API.
        -- In order to support Deletion without any glitches you need to:
        -- - (1) If items are submitted in their own scrolling area, submit contents size SetNextWindowContentSize() ahead of time to prevent one-frame readjustment of scrolling.
        -- - (2) Items needs to have persistent ID Stack identifier = ID needs to not depends on their index. PushID(index) = KO. PushID(item_id) = OK. This is in order to focus items reliably after a selection.
        -- - (3) BeginXXXX process
        -- - (4) Focus process
        -- - (5) EndXXXX process
        if ImGui.TreeNode("Multi-Select (with deletion)") then
            IMGUI_DEMO_MARKER("Widgets/Selection State/Multi-Select (with deletion)")
            -- Storing items data separately from selection data.
            -- (you may decide to store selection data inside your item (aka intrusive storage) if you don't need multiple views over same items)
            -- Use a custom selection.Adapter: store item identifier in Selection (instead of index)
            local st = s.with_deletion
            local items = st.items
            local selection = st.selection
            selection.UserData = items
            selection.AdapterIndexToStorageId = function(self, idx) local p_items = self.UserData; return p_items.Data[idx + 1] end -- Index -> ID

            ImGui.Text("Added features:")
            ImGui.BulletText("Dynamic list with Delete key support.")
            ImGui.Text("Selection size: %d/%d", selection.Size, items.Size)

            -- Initialize default list with 50 items + button to add/remove items.
            if st.items_next_id == 0 then
                for _ = 0, 49 do
                    items:push_back(st.items_next_id); st.items_next_id = st.items_next_id + 1
                end
            end
            if ImGui.SmallButton("Add 20 items") then for _ = 0, 19 do items:push_back(st.items_next_id); st.items_next_id = st.items_next_id + 1 end end
            ImGui.SameLine()
            if ImGui.SmallButton("Remove 20 items") then for _ = ImMin(20, items.Size), 1, -1 do selection:SetItemSelected(items:back(), false); items:pop_back() end end

            -- (1) Extra to support deletion: Submit scrolling range to avoid glitches on deletion
            local items_height = ImGui.GetTextLineHeightWithSpacing()
            ImGui.SetNextWindowContentSize(ImVec2(0.0, items.Size * items_height))

            if ImGui.BeginChild("##Basket", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY)) then
                local flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.BoxSelect1d)
                local ms_io = ImGui.BeginMultiSelect(flags, selection.Size, items.Size)
                selection:ApplyRequests(ms_io)

                local want_delete = ImGui.Shortcut(ImGuiKey.Delete, ImGuiInputFlags.Repeat) and (selection.Size > 0)
                local item_curr_idx_to_focus = -1
                if want_delete then item_curr_idx_to_focus = selection:ApplyDeletionPreLoop(ms_io, items.Size) end

                for n = 0, items.Size - 1 do
                    local item_id = items.Data[n + 1]
                    local label = string.format("Object %05d: %s", item_id, ExampleNames[item_id % #ExampleNames + 1]) -- [Port] %05u -> %05d

                    local item_is_selected = selection:Contains(item_id)
                    ImGui.SetNextItemSelectionUserData(n)
                    ImGui.Selectable(label, item_is_selected)
                    if item_curr_idx_to_focus == n then
                        ImGui.SetKeyboardFocusHere(-1)
                    end
                end

                -- Apply multi-select requests
                ms_io = ImGui.EndMultiSelect()
                selection:ApplyRequests(ms_io)
                if want_delete then
                    selection:ApplyDeletionPostLoop(ms_io, items, item_curr_idx_to_focus)
                end
            end
            ImGui.EndChild()
            ImGui.TreePop()
        end

        -- Implement a Dual List Box (#6648)
        if ImGui.TreeNode("Multi-Select (dual list box)") then
            IMGUI_DEMO_MARKER("Widgets/Selection State/Multi-Select (dual list box)")
            -- Init default state
            local dlb = s.dual_list_box.dlb
            if dlb.Items[1].Size == 0 and dlb.Items[2].Size == 0 then
                for item_id = 0, #ExampleNames - 1 do
                    dlb.Items[1]:push_back(item_id)
                end
            end

            -- Show
            dlb:Show()

            ImGui.TreePop()
        end

        -- Demonstrate using the clipper with BeginMultiSelect()/EndMultiSelect()
        if ImGui.TreeNode("Multi-Select (in a table)") then
            IMGUI_DEMO_MARKER("Widgets/Selection State/Multi-Select (in a table)")
            local selection = s.in_a_table.selection

            local ITEMS_COUNT = 10000
            ImGui.Text("Selection: %d/%d", selection.Size, ITEMS_COUNT)
            if ImGui.BeginTable("##Basket", 2, bit32.bor(ImGuiTableFlags.ScrollY, ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter), ImVec2(0.0, ImGui.GetFontSize() * 20)) then
                ImGui.TableSetupColumn("Object")
                ImGui.TableSetupColumn("Action")
                ImGui.TableSetupScrollFreeze(0, 1)
                ImGui.TableHeadersRow()

                local flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.BoxSelect1d)
                local ms_io = ImGui.BeginMultiSelect(flags, selection.Size, ITEMS_COUNT)
                selection:ApplyRequests(ms_io)

                local clipper = ImGuiListClipper()
                clipper:Begin(ITEMS_COUNT)
                if ms_io.RangeSrcItem ~= -1 then
                    clipper:IncludeItemByIndex(ms_io.RangeSrcItem) -- Ensure RangeSrc item is not clipped.
                end
                while clipper:Step() do
                    for n = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                        ImGui.TableNextRow()
                        ImGui.TableNextColumn()
                        ImGui.PushID(n)
                        local label = string.format("Object %05d: %s", n, ExampleNames[n % #ExampleNames + 1])
                        local item_is_selected = selection:Contains(n)
                        ImGui.SetNextItemSelectionUserData(n)
                        ImGui.Selectable(label, item_is_selected, bit32.bor(ImGuiSelectableFlags.SpanAllColumns, ImGuiSelectableFlags.AllowOverlap))
                        ImGui.TableNextColumn()
                        ImGui.SmallButton("hello")
                        ImGui.PopID()
                    end
                end

                ms_io = ImGui.EndMultiSelect()
                selection:ApplyRequests(ms_io)
                ImGui.EndTable()
            end
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Multi-Select (checkboxes)") then
            IMGUI_DEMO_MARKER("Widgets/Selection State/Multi-Select (checkboxes)")
            ImGui.Text("In a list of checkboxes (not selectable):")
            ImGui.BulletText("Using _NoAutoSelect + _NoAutoClear flags.")
            ImGui.BulletText("Shift+Click to check multiple boxes.")
            ImGui.BulletText("Shift+Keyboard to copy current value to other boxes.")

            -- If you have an array of checkboxes, you may want to use NoAutoSelect + NoAutoClear and the ImGuiSelectionExternalStorage helper.
            local st = s.checkboxes
            local items = st.items
            _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoAutoSelect", st.flags, ImGuiMultiSelectFlags.NoAutoSelect)
            _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoAutoClear", st.flags, ImGuiMultiSelectFlags.NoAutoClear)
            _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_BoxSelect2d", st.flags, ImGuiMultiSelectFlags.BoxSelect2d) -- Cannot use ImGuiMultiSelectFlags_BoxSelect1d as checkboxes are varying width.

            if ImGui.BeginChild("##Basket", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeY)) then
                local ms_io = ImGui.BeginMultiSelect(st.flags, -1, #items)
                local storage_wrapper = ImGuiSelectionExternalStorage()
                storage_wrapper.UserData = items
                storage_wrapper.AdapterSetItemSelected = function(self, n, selected) local array = self.UserData; array[n + 1] = selected end
                storage_wrapper:ApplyRequests(ms_io)
                for n = 0, 19 do
                    local label = string.format("Item %d", n)
                    ImGui.SetNextItemSelectionUserData(n)
                    _, items[n + 1] = ImGui.Checkbox(label, items[n + 1])
                end
                ms_io = ImGui.EndMultiSelect()
                storage_wrapper:ApplyRequests(ms_io)
            end
            ImGui.EndChild()

            ImGui.TreePop()
        end

        -- Demonstrate individual selection scopes in same window
        if ImGui.TreeNode("Multi-Select (multiple scopes)") then
            IMGUI_DEMO_MARKER("Widgets/Selection State/Multi-Select (multiple scopes)")
            -- Use default select: Pass index to SetNextItemSelectionUserData(), store index in Selection
            local SCOPES_COUNT = 3
            local ITEMS_COUNT = 8 -- Per scope
            local st = s.multiple_scopes
            local selections_data = st.selections_data

            -- Use ImGuiMultiSelectFlags_ScopeRect to not affect other selections in same window.
            local pressed
            pressed, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ScopeWindow", st.flags, ImGuiMultiSelectFlags.ScopeWindow)
            if pressed and bit32.band(st.flags, ImGuiMultiSelectFlags.ScopeWindow) ~= 0 then
                st.flags = bit32.band(st.flags, bit32.bnot(ImGuiMultiSelectFlags.ScopeRect))
            end
            pressed, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ScopeRect", st.flags, ImGuiMultiSelectFlags.ScopeRect)
            if pressed and bit32.band(st.flags, ImGuiMultiSelectFlags.ScopeRect) ~= 0 then
                st.flags = bit32.band(st.flags, bit32.bnot(ImGuiMultiSelectFlags.ScopeWindow))
            end
            _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ClearOnClickVoid", st.flags, ImGuiMultiSelectFlags.ClearOnClickVoid)
            _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_BoxSelect1d", st.flags, ImGuiMultiSelectFlags.BoxSelect1d)

            for selection_scope_n = 0, SCOPES_COUNT - 1 do
                ImGui.PushID(selection_scope_n)
                local selection = selections_data[selection_scope_n + 1]
                local ms_io = ImGui.BeginMultiSelect(st.flags, selection.Size, ITEMS_COUNT)
                selection:ApplyRequests(ms_io)

                ImGui.SeparatorText("Selection scope")
                ImGui.Text("Selection size: %d/%d", selection.Size, ITEMS_COUNT)

                for n = 0, ITEMS_COUNT - 1 do
                    local label = string.format("Object %05d: %s", n, ExampleNames[n % #ExampleNames + 1])
                    local item_is_selected = selection:Contains(n)
                    ImGui.SetNextItemSelectionUserData(n)
                    ImGui.Selectable(label, item_is_selected)
                end

                -- Apply multi-select requests
                ms_io = ImGui.EndMultiSelect()
                selection:ApplyRequests(ms_io)
                ImGui.PopID()
            end
            ImGui.TreePop()
        end

        -- See ShowExampleAppAssetsBrowser()
        if ImGui.TreeNode("Multi-Select (tiled assets browser)") then
            _, demo_data.ShowAppAssetsBrowser = ImGui.Checkbox("Assets Browser", demo_data.ShowAppAssetsBrowser)
            ImGui.Text("(also access from 'Examples->Assets Browser' in menu)")
            ImGui.TreePop()
        end

        -- Demonstrate supporting multiple-selection in a tree.
        -- - We don't use linear indices for selection user data, but our ExampleTreeNode* pointer directly!
        --   This showcase how SetNextItemSelectionUserData() never assume indices!
        -- - The difficulty here is to "interpolate" from RangeSrcItem to RangeDstItem in the SetAll/SetRange request.
        --   We want this interpolation to match what the user sees: in visible order, skipping closed nodes.
        --   This is implemented by our TreeGetNextNodeInVisibleOrder() user-space helper.
        -- - Important: In a real codebase aiming to implement full-featured selectable tree with custom filtering, you
        --   are more likely to build an array mapping sequential indices to visible tree nodes, since your
        --   filtering/search + clipping process will benefit from it. Having this will make this interpolation much easier.
        -- - Consider this a prototype: we are working toward simplifying some of it.
        if ImGui.TreeNode("Multi-Select (trees)") then
            IMGUI_DEMO_MARKER("Widgets/Selection State/Multi-Select (trees)")
            HelpMarker(
                "This is rather advanced and experimental. If you are getting started with multi-select, " ..
                "please don't start by looking at how to use it for a tree!\n\n" ..
                "Future versions will try to simplify and formalize some of this.")

            -- struct ExampleTreeFuncs { ... }; -- [Port] defined at file level above S.DemoWindowWidgetsSelectionAndMultiSelect

            local selection = s.trees.selection
            if demo_data.DemoTree == nil then
                demo_data.DemoTree = ExampleTree_CreateDemoTree() -- Create tree once
            end
            ImGui.Text("Selection size: %d", selection.Size)

            if ImGui.BeginChild("##Tree", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY)) then
                local tree = demo_data.DemoTree
                local ms_flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.BoxSelect2d)
                local ms_io = ImGui.BeginMultiSelect(ms_flags, selection.Size, -1)
                ExampleTreeFuncs.ApplySelectionRequests(ms_io, tree, selection)
                for _, node in ipairs(tree.Childs) do
                    ExampleTreeFuncs.DrawNode(node, selection)
                end
                ms_io = ImGui.EndMultiSelect()
                ExampleTreeFuncs.ApplySelectionRequests(ms_io, tree, selection)
            end
            ImGui.EndChild()

            ImGui.TreePop()
        end

        -- Advanced demonstration of BeginMultiSelect()
        -- - Showcase clipping.
        -- - Showcase deletion.
        -- - Showcase basic drag and drop.
        -- - Showcase TreeNode variant (note that tree node don't expand in the demo: supporting expanding tree nodes + clipping a separate thing).
        -- - Showcase using inside a table.
        --ImGui::SetNextItemOpen(true, ImGuiCond_Once);
        if ImGui.TreeNode("Multi-Select (advanced)") then
            IMGUI_DEMO_MARKER("Widgets/Selection State/Multi-Select (advanced)")
            -- Options
            local WidgetType_Selectable, WidgetType_TreeNode = 0, 1 -- enum WidgetType
            local st = s.advanced

            if ImGui.TreeNode("Options") then
                if ImGui.RadioButtonEx("Selectables", st.widget_type == WidgetType_Selectable) then st.widget_type = WidgetType_Selectable end -- [Port] RadioButton(label, bool) -> RadioButtonEx
                ImGui.SameLine()
                if ImGui.RadioButtonEx("Tree nodes", st.widget_type == WidgetType_TreeNode) then st.widget_type = WidgetType_TreeNode end
                ImGui.SameLine()
                HelpMarker("TreeNode() is technically supported but... using this correctly is more complicated (you need some sort of linear/random access to your tree, which is suited to advanced trees setups already implementing filters and clipper. We will work toward simplifying and demoing this.\n\nFor now the tree demo is actually a little bit meaningless because it is an empty tree with only root nodes.")
                _, st.use_clipper = ImGui.Checkbox("Enable clipper", st.use_clipper)
                _, st.use_deletion = ImGui.Checkbox("Enable deletion", st.use_deletion)
                _, st.use_drag_drop = ImGui.Checkbox("Enable drag & drop", st.use_drag_drop)
                _, st.show_in_table = ImGui.Checkbox("Show in a table", st.show_in_table)
                _, st.show_color_button = ImGui.Checkbox("Show color button", st.show_color_button)
                _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_SingleSelect", st.flags, ImGuiMultiSelectFlags.SingleSelect)
                _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoSelectAll", st.flags, ImGuiMultiSelectFlags.NoSelectAll)
                _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoRangeSelect", st.flags, ImGuiMultiSelectFlags.NoRangeSelect)
                _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoAutoSelect", st.flags, ImGuiMultiSelectFlags.NoAutoSelect)
                _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoAutoClear", st.flags, ImGuiMultiSelectFlags.NoAutoClear)
                _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoAutoClearOnReselect", st.flags, ImGuiMultiSelectFlags.NoAutoClearOnReselect)
                _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_NoSelectOnRightClick", st.flags, ImGuiMultiSelectFlags.NoSelectOnRightClick)
                _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_BoxSelect1d", st.flags, ImGuiMultiSelectFlags.BoxSelect1d)
                _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_BoxSelect2d", st.flags, ImGuiMultiSelectFlags.BoxSelect2d)
                _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_BoxSelectNoScroll", st.flags, ImGuiMultiSelectFlags.BoxSelectNoScroll)
                _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ClearOnEscape", st.flags, ImGuiMultiSelectFlags.ClearOnEscape)
                _, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ClearOnClickVoid", st.flags, ImGuiMultiSelectFlags.ClearOnClickVoid)
                local pressed
                pressed, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ScopeWindow", st.flags, ImGuiMultiSelectFlags.ScopeWindow)
                if pressed and bit32.band(st.flags, ImGuiMultiSelectFlags.ScopeWindow) ~= 0 then
                    st.flags = bit32.band(st.flags, bit32.bnot(ImGuiMultiSelectFlags.ScopeRect))
                end
                pressed, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_ScopeRect", st.flags, ImGuiMultiSelectFlags.ScopeRect)
                if pressed and bit32.band(st.flags, ImGuiMultiSelectFlags.ScopeRect) ~= 0 then
                    st.flags = bit32.band(st.flags, bit32.bnot(ImGuiMultiSelectFlags.ScopeWindow))
                end
                pressed, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_SelectOnAuto", st.flags, ImGuiMultiSelectFlags.SelectOnAuto)
                if pressed then
                    st.flags = bit32.band(st.flags, bit32.bnot(bit32.bxor(ImGuiMultiSelectFlags.SelectOnMask_, ImGuiMultiSelectFlags.SelectOnAuto)))
                end
                ImGui.SameLine(); HelpMarker("Apply selection on mouse down when clicking on unselected item, on mouse up when clicking on selected item. (Default)")
                pressed, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_SelectOnClickAlways", st.flags, ImGuiMultiSelectFlags.SelectOnClickAlways)
                if pressed then
                    st.flags = bit32.band(st.flags, bit32.bnot(bit32.bxor(ImGuiMultiSelectFlags.SelectOnMask_, ImGuiMultiSelectFlags.SelectOnClickAlways)))
                end
                ImGui.SameLine(); HelpMarker("Prevents Drag and Drop from being used on multi-selection, but allows e.g. BoxSelect to always reselect even when clicking inside an existing selection. (Excel style behavior)")
                pressed, st.flags = ImGui.CheckboxFlags("ImGuiMultiSelectFlags_SelectOnClickRelease", st.flags, ImGuiMultiSelectFlags.SelectOnClickRelease)
                if pressed then
                    st.flags = bit32.band(st.flags, bit32.bnot(bit32.bxor(ImGuiMultiSelectFlags.SelectOnMask_, ImGuiMultiSelectFlags.SelectOnClickRelease)))
                end
                ImGui.SameLine(); HelpMarker("Allow dragging an unselected item without altering selection.")
                ImGui.TreePop()
            end

            -- Initialize default list with 1000 items.
            -- Use default selection.Adapter: Pass index to SetNextItemSelectionUserData(), store index in Selection
            local items = st.items
            if st.items_next_id == 0 then for _ = 0, 999 do items:push_back(st.items_next_id); st.items_next_id = st.items_next_id + 1 end end
            local selection = st.selection

            ImGui.Text("Selection size: %d/%d", selection.Size, items.Size)

            local items_height = (st.widget_type == WidgetType_TreeNode) and ImGui.GetTextLineHeight() or ImGui.GetTextLineHeightWithSpacing()
            ImGui.SetNextWindowContentSize(ImVec2(0.0, items.Size * items_height))
            if ImGui.BeginChild("##Basket", ImVec2(-FLT_MIN, ImGui.GetFontSize() * 20), bit32.bor(ImGuiChildFlags.FrameStyle, ImGuiChildFlags.ResizeY)) then
                local color_button_sz = ImVec2(ImGui.GetFontSize(), ImGui.GetFontSize())
                if st.widget_type == WidgetType_TreeNode then
                    ImGui.PushStyleVarY(ImGuiStyleVar.ItemSpacing, 0.0)
                end

                local ms_io = ImGui.BeginMultiSelect(st.flags, selection.Size, items.Size)
                selection:ApplyRequests(ms_io)

                local want_delete = (ImGui.Shortcut(ImGuiKey.Delete, ImGuiInputFlags.Repeat) and (selection.Size > 0)) or st.request_deletion_from_menu
                local item_curr_idx_to_focus = -1
                if want_delete then item_curr_idx_to_focus = selection:ApplyDeletionPreLoop(ms_io, items.Size) end
                st.request_deletion_from_menu = false

                if st.show_in_table then
                    if st.widget_type == WidgetType_TreeNode then
                        ImGui.PushStyleVar(ImGuiStyleVar.CellPadding, ImVec2(0.0, 0.0))
                    end
                    ImGui.BeginTable("##Split", 2, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.NoSavedSettings, ImGuiTableFlags.NoPadOuterX))
                    ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthStretch, 0.70)
                    ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthStretch, 0.30)
                    --ImGui::PushStyleVarY(ImGuiStyleVar_ItemSpacing, 0.0f);
                end

                local clipper = ImGuiListClipper()
                if st.use_clipper then
                    clipper:Begin(items.Size)
                    if item_curr_idx_to_focus ~= -1 then
                        clipper:IncludeItemByIndex(item_curr_idx_to_focus) -- Ensure focused item is not clipped.
                    end
                    if ms_io.RangeSrcItem ~= -1 then
                        clipper:IncludeItemByIndex(ms_io.RangeSrcItem) -- Ensure RangeSrc item is not clipped.
                    end
                end

                while not st.use_clipper or clipper:Step() do
                    local item_begin = st.use_clipper and clipper.DisplayStart or 0
                    local item_end = st.use_clipper and clipper.DisplayEnd or items.Size
                    for n = item_begin, item_end - 1 do
                        if st.show_in_table then
                            ImGui.TableNextColumn()
                        end

                        local item_id = items.Data[n + 1]
                        local item_category = ExampleNames[item_id % #ExampleNames + 1]
                        local label = string.format("Object %05d: %s", item_id, item_category)

                        -- IMPORTANT: for deletion refocus to work we need object ID to be stable,
                        -- aka not depend on their index in the list. Here we use our persistent item_id
                        -- instead of index to build a unique ID that will persist.
                        -- (If we used PushID(index) instead, focus wouldn't be restored correctly after deletion).
                        ImGui.PushID(item_id)

                        -- Emit a color button, to test that Shift+LeftArrow landing on an item that is not part
                        -- of the selection scope doesn't erroneously alter our selection.
                        if st.show_color_button then
                            local dummy_col = bit32.bor((n * 0xC250B74B) % 4294967296, IM_COL32_A_MASK) -- [Port] unsigned 32-bit wrap-around
                            ImGui.ColorButton("##", ImColor(dummy_col).Value, ImGuiColorEditFlags.NoTooltip, color_button_sz)
                            ImGui.SameLine()
                        end

                        -- Submit item
                        local item_is_selected = selection:Contains(n)
                        local item_is_open = false
                        ImGui.SetNextItemSelectionUserData(n)
                        if st.widget_type == WidgetType_Selectable then
                            ImGui.Selectable(label, item_is_selected, ImGuiSelectableFlags.None)
                        elseif st.widget_type == WidgetType_TreeNode then
                            local tree_node_flags = bit32.bor(ImGuiTreeNodeFlags.SpanAvailWidth, ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick)
                            if item_is_selected then
                                tree_node_flags = bit32.bor(tree_node_flags, ImGuiTreeNodeFlags.Selected)
                            end
                            item_is_open = ImGui.TreeNodeEx(label, tree_node_flags)
                        end

                        -- Focus (for after deletion)
                        if item_curr_idx_to_focus == n then
                            ImGui.SetKeyboardFocusHere(-1)
                        end

                        -- Drag and Drop
                        if st.use_drag_drop and ImGui.BeginDragDropSource() then
                            -- Create payload with full selection OR single unselected item.
                            -- (the later is only possible when using ImGuiMultiSelectFlags_SelectOnClickRelease)
                            if ImGui.GetDragDropPayload() == nil then
                                local payload_items = ImVector()
                                local it = nil
                                local id = 0
                                if not item_is_selected then
                                    payload_items:push_back(item_id)
                                else
                                    local has_more
                                    while true do
                                        has_more, it, id = selection:GetNextSelectedItem(it)
                                        if not has_more then break end
                                        payload_items:push_back(id)
                                    end
                                end
                                ImGui.SetDragDropPayload("MULTISELECT_DEMO_ITEMS", payload_items.Data, payload_items.Size * 4) -- [Port] size_in_bytes() = Size * sizeof(int), payload carries the Lua array
                            end

                            -- Display payload content in tooltip
                            local payload = ImGui.GetDragDropPayload()
                            local payload_items = payload.Data
                            local payload_count = math.floor(payload.DataSize / 4) -- [Port] sizeof(int) = 4
                            if payload_count == 1 then
                                ImGui.Text("Object %05d: %s", payload_items[1], ExampleNames[payload_items[1] % #ExampleNames + 1])
                            else
                                ImGui.Text("Dragging %d objects", payload_count)
                            end

                            ImGui.EndDragDropSource()
                        end

                        if st.widget_type == WidgetType_TreeNode and item_is_open then
                            ImGui.TreePop()
                        end

                        -- Right-click: context menu
                        if ImGui.BeginPopupContextItem() then
                            ImGui.BeginDisabled(not st.use_deletion or selection.Size == 0)
                            label = string.format("Delete %d item(s)###DeleteSelected", selection.Size)
                            if ImGui.Selectable(label) then
                                st.request_deletion_from_menu = true
                            end
                            ImGui.EndDisabled()
                            ImGui.Selectable("Close")
                            ImGui.EndPopup()
                        end

                        -- Demo content within a table
                        if st.show_in_table then
                            ImGui.TableNextColumn()
                            ImGui.SetNextItemWidth(-FLT_MIN)
                            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(0, 0))
                            -- [Port] InputText() needs a byte buffer: one cached read-only buffer per category (buf_size includes the terminator)
                            local category_buf = st.item_category_bufs[item_category]
                            if category_buf == nil then category_buf = ImGui.NewTextBuffer(item_category, #item_category + 1); st.item_category_bufs[item_category] = category_buf end
                            ImGui.InputText("##NoLabel", category_buf, #item_category + 1, ImGuiInputTextFlags.ReadOnly)
                            ImGui.PopStyleVar()
                        end

                        ImGui.PopID()
                    end
                    if not st.use_clipper then
                        break
                    end
                end

                if st.show_in_table then
                    ImGui.EndTable()
                    if st.widget_type == WidgetType_TreeNode then
                        ImGui.PopStyleVar()
                    end
                end

                -- Apply multi-select requests
                ms_io = ImGui.EndMultiSelect()
                selection:ApplyRequests(ms_io)
                if want_delete then
                    selection:ApplyDeletionPostLoop(ms_io, items, item_curr_idx_to_focus)
                end

                if st.widget_type == WidgetType_TreeNode then
                    ImGui.PopStyleVar()
                end
            end
            ImGui.EndChild()
            ImGui.TreePop()
        end
        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsTabs()
-------------------------------------------------------------------------------

-- [Port] ImGuiTabBarFlags* p_flags -> takes flags, returns the new flags
function EditTabBarFittingPolicyFlags(p_flags)
    if bit32.band(p_flags, ImGuiTabBarFlags.FittingPolicyMask_) == 0 then
        p_flags = bit32.bor(p_flags, ImGuiTabBarFlags.FittingPolicyDefault_)
    end
    local pressed
    pressed, p_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_FittingPolicyMixed", p_flags, ImGuiTabBarFlags.FittingPolicyMixed)
    if pressed then
        p_flags = bit32.band(p_flags, bit32.bnot(bit32.bxor(ImGuiTabBarFlags.FittingPolicyMask_, ImGuiTabBarFlags.FittingPolicyMixed)))
    end
    pressed, p_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_FittingPolicyShrink", p_flags, ImGuiTabBarFlags.FittingPolicyShrink)
    if pressed then
        p_flags = bit32.band(p_flags, bit32.bnot(bit32.bxor(ImGuiTabBarFlags.FittingPolicyMask_, ImGuiTabBarFlags.FittingPolicyShrink)))
    end
    pressed, p_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_FittingPolicyScroll", p_flags, ImGuiTabBarFlags.FittingPolicyScroll)
    if pressed then
        p_flags = bit32.band(p_flags, bit32.bnot(bit32.bxor(ImGuiTabBarFlags.FittingPolicyMask_, ImGuiTabBarFlags.FittingPolicyScroll)))
    end
    return p_flags
end

S.DemoWindowWidgetsTabs = {
    tab_bar_flags = ImGuiTabBarFlags.Reorderable,
    opened = { true, true, true, true }, -- Persistent user state
    active_tabs = ImVector(),
    next_tab_id = 0,
    show_leading_button = true,
    show_trailing_button = true,
    show_leading_trailing_tabs = false,
    tab_bar_flags_2 = bit32.bor(ImGuiTabBarFlags.AutoSelectNewTabs, ImGuiTabBarFlags.Reorderable, ImGuiTabBarFlags.FittingPolicyMixed),
}
function DemoWindowWidgetsTabs()
    local s = S.DemoWindowWidgetsTabs
    if ImGui.TreeNode("Tabs") then
        IMGUI_DEMO_MARKER("Widgets/Tabs")
        if ImGui.TreeNode("Basic") then
            IMGUI_DEMO_MARKER("Widgets/Tabs/Basic")
            local tab_bar_flags = ImGuiTabBarFlags.None
            if ImGui.BeginTabBar("MyTabBar", tab_bar_flags) then
                if ImGui.BeginTabItem("Avocado") then
                    ImGui.Text("This is the Avocado tab!\nblah blah blah blah blah")
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem("Broccoli") then
                    ImGui.Text("This is the Broccoli tab!\nblah blah blah blah blah")
                    ImGui.EndTabItem()
                end
                if ImGui.BeginTabItem("Cucumber") then
                    ImGui.Text("This is the Cucumber tab!\nblah blah blah blah blah")
                    ImGui.EndTabItem()
                end
                ImGui.EndTabBar()
            end
            ImGui.Separator()
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Advanced & Close Button") then
            IMGUI_DEMO_MARKER("Widgets/Tabs/Advanced & Close Button")
            -- Expose a couple of the available flags. In most cases you may just call BeginTabBar() with no flags (0).
            _, s.tab_bar_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_Reorderable", s.tab_bar_flags, ImGuiTabBarFlags.Reorderable)
            _, s.tab_bar_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_AutoSelectNewTabs", s.tab_bar_flags, ImGuiTabBarFlags.AutoSelectNewTabs)
            _, s.tab_bar_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_TabListPopupButton", s.tab_bar_flags, ImGuiTabBarFlags.TabListPopupButton)
            _, s.tab_bar_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_NoCloseWithMiddleMouseButton", s.tab_bar_flags, ImGuiTabBarFlags.NoCloseWithMiddleMouseButton)
            _, s.tab_bar_flags = ImGui.CheckboxFlags("ImGuiTabBarFlags_DrawSelectedOverline", s.tab_bar_flags, ImGuiTabBarFlags.DrawSelectedOverline)
            s.tab_bar_flags = EditTabBarFittingPolicyFlags(s.tab_bar_flags)

            -- Tab Bar
            ImGui.AlignTextToFramePadding()
            ImGui.Text("Opened:")
            local names = { "Artichoke", "Beetroot", "Celery", "Daikon" }
            local opened = s.opened -- Persistent user state
            for n = 0, #opened - 1 do
                ImGui.SameLine()
                _, opened[n + 1] = ImGui.Checkbox(names[n + 1], opened[n + 1])
            end

            -- Passing a bool* to BeginTabItem() is similar to passing one to Begin():
            -- the underlying bool will be set to false when the tab is closed.
            if ImGui.BeginTabBar("MyTabBar", s.tab_bar_flags) then
                for n = 0, #opened - 1 do
                    if opened[n + 1] then
                        local visible
                        visible, opened[n + 1] = ImGui.BeginTabItem(names[n + 1], opened[n + 1], ImGuiTabItemFlags.None)
                        if visible then
                            ImGui.Text("This is the %s tab!", names[n + 1])
                            if bit32.band(n, 1) ~= 0 then
                                ImGui.Text("I am an odd tab.")
                            end
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
            IMGUI_DEMO_MARKER("Widgets/Tabs/TabItemButton & Leading-Trailing flags")
            local active_tabs = s.active_tabs
            if s.next_tab_id == 0 then -- Initialize with some default tabs
                for i = 0, 2 do
                    active_tabs:push_back(s.next_tab_id); s.next_tab_id = s.next_tab_id + 1
                end
            end

            -- TabItemButton() and Leading/Trailing flags are distinct features which we will demo together.
            -- (It is possible to submit regular tabs with Leading/Trailing flags, or TabItemButton tabs without Leading/Trailing flags...
            -- but they tend to make more sense together)
            _, s.show_leading_button = ImGui.Checkbox("Show Leading TabItemButton()", s.show_leading_button)
            _, s.show_trailing_button = ImGui.Checkbox("Show Trailing TabItemButton()", s.show_trailing_button)
            _, s.show_leading_trailing_tabs = ImGui.Checkbox("Show Leading+Trailing TabItem()", s.show_leading_trailing_tabs)

            -- Expose some other flags which are useful to showcase how they interact with Leading/Trailing tabs
            s.tab_bar_flags_2 = EditTabBarFittingPolicyFlags(s.tab_bar_flags_2)

            if ImGui.BeginTabBar("MyTabBar", s.tab_bar_flags_2) then
                -- Demo a Leading TabItemButton(): click the "?" button to open a menu
                if s.show_leading_button then
                    if ImGui.TabItemButton("?", bit32.bor(ImGuiTabItemFlags.Leading, ImGuiTabItemFlags.NoTooltip)) then
                        ImGui.OpenPopup("MyHelpMenu")
                    end
                end
                if ImGui.BeginPopup("MyHelpMenu") then
                    ImGui.Selectable("Hello!")
                    ImGui.EndPopup()
                end

                -- Demo Leading/Trailing Tabs
                if s.show_leading_trailing_tabs then
                    if ImGui.BeginTabItem("Leading", nil, ImGuiTabItemFlags.Leading) then
                        ImGui.EndTabItem()
                    end
                    if ImGui.BeginTabItem("Trailing", nil, ImGuiTabItemFlags.Trailing) then
                        ImGui.EndTabItem()
                    end
                end

                -- Demo Trailing Tabs: click the "+" button to add a new tab.
                -- (In your app you may want to use a font icon instead of the "+")
                -- We submit it before the regular tabs, but thanks to the ImGuiTabItemFlags_Trailing flag it will always appear at the end.
                if s.show_trailing_button then
                    if ImGui.TabItemButton("+", bit32.bor(ImGuiTabItemFlags.Trailing, ImGuiTabItemFlags.NoTooltip)) then
                        active_tabs:push_back(s.next_tab_id); s.next_tab_id = s.next_tab_id + 1 -- Add new tab
                    end
                end

                -- Submit our regular tabs
                local n = 0
                while n < active_tabs.Size do
                    local open = true
                    local name = string.format("%04d", active_tabs.Data[n + 1])
                    local visible
                    visible, open = ImGui.BeginTabItem(name, open, ImGuiTabItemFlags.None)
                    if visible then
                        ImGui.Text("This is the %s tab!", name)
                        ImGui.EndTabItem()
                    end

                    if not open then
                        active_tabs:erase(n + 1)
                    else
                        n = n + 1
                    end
                end

                ImGui.EndTabBar()
            end
            ImGui.Separator()
            ImGui.TreePop()
        end
        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsText()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsText = {
    custom_size = 16.0,
    custom_scale = 1.0,
    wrap_width = 200.0,
    buf = ImGui.NewTextBuffer("\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e", 32),
}
function DemoWindowWidgetsText()
    local s = S.DemoWindowWidgetsText
    if ImGui.TreeNode("Text") then
        IMGUI_DEMO_MARKER("Widgets/Text")
        if ImGui.TreeNode("Colorful Text") then
            IMGUI_DEMO_MARKER("Widgets/Text/Colored Text")
            -- Using shortcut. You can use PushStyleColor()/PopStyleColor() for more flexibility.
            ImGui.TextColored(ImVec4(1.0, 0.0, 1.0, 1.0), "Pink")
            ImGui.TextColored(ImVec4(1.0, 1.0, 0.0, 1.0), "Yellow")
            ImGui.TextDisabled("Disabled")
            ImGui.SameLine(); HelpMarker("The TextDisabled color is stored in ImGuiStyle.")
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Font Size") then
            IMGUI_DEMO_MARKER("Widgets/Text/Font Size")
            local style = ImGui.GetStyle()
            local global_scale = style.FontScaleMain * style.FontScaleDpi
            ImGui.Text("style.FontScaleMain = %0.2f", style.FontScaleMain)
            ImGui.Text("style.FontScaleDpi = %0.2f", style.FontScaleDpi)
            ImGui.Text("global_scale = ~%0.2f", global_scale) -- This is not technically accurate as internal scales may apply, but conceptually let's pretend it is.
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
            IMGUI_DEMO_MARKER("Widgets/Text/Word Wrapping")
            -- Using shortcut. You can use PushTextWrapPos()/PopTextWrapPos() for more flexibility.
            ImGui.TextWrapped(
                "This text should automatically wrap on the edge of the window. The current implementation " ..
                "for text wrapping follows simple rules suitable for English and possibly other languages.")
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

                -- Draw actual text bounding box, following by marker of our expected limit (should not overlap!)
                draw_list:AddRect(ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), IM_COL32(255, 255, 0, 255))
                draw_list:AddRectFilled(marker_min, marker_max, IM_COL32(255, 0, 255, 255))
                ImGui.PopTextWrapPos()
            end

            ImGui.TreePop()
        end

        if ImGui.TreeNode("UTF-8 Text") then
            IMGUI_DEMO_MARKER("Widgets/Text/UTF-8 Text")
            -- UTF-8 test with Japanese characters
            -- (Needs a suitable font? Try "Google Noto" or "Arial Unicode". See docs/FONTS.md for details.)
            -- - From C++11 you can use the u8"my text" syntax to encode literal strings as UTF-8
            -- - For earlier compiler, you may be able to encode your sources as UTF-8 (e.g. in Visual Studio, you
            --   can save your source files as 'UTF-8 without signature').
            -- - FOR THIS DEMO FILE ONLY, BECAUSE WE WANT TO SUPPORT OLD COMPILERS, WE ARE *NOT* INCLUDING RAW UTF-8
            --   CHARACTERS IN THIS SOURCE FILE. Instead we are encoding a few strings with hexadecimal constants.
            --   Don't do this in your application! Please use u8"text in any language" in your application!
            -- Note that characters values are preserved even by InputText() if the font cannot be displayed,
            -- so you can safely copy & paste garbled characters into another application.
            ImGui.TextWrapped(
                "CJK text will only appear if the font was loaded with the appropriate CJK character ranges. " ..
                "Call io.Fonts->AddFontFromFileTTF() manually to load extra character ranges. " ..
                "Read docs/FONTS.md for details.")
            ImGui.Text("Hiragana: \xe3\x81\x8b\xe3\x81\x8d\xe3\x81\x8f\xe3\x81\x91\xe3\x81\x93 (kakikukeko)")
            ImGui.Text("Kanjis: \xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e (nihongo)")
            --static char buf[32] = u8"NIHONGO"; -- <- this is how you would write it with C++11, using real kanjis
            ImGui.InputText("UTF-8 input", s.buf, 32)
            ImGui.TreePop()
        end
        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsTextFilter()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsTextFilter = {
    filter = ImGuiTextFilter(),
}
function DemoWindowWidgetsTextFilter()
    local s = S.DemoWindowWidgetsTextFilter
    if ImGui.TreeNode("Text Filter") then
        IMGUI_DEMO_MARKER("Widgets/Text Filter")
        -- Helper class to easy setup a text filter.
        -- You may want to implement a more feature-full filtering scheme in your own application.
        HelpMarker("Not a widget per-se, but ImGuiTextFilter is a helper to perform simple filtering on text strings.")
        local filter = s.filter
        ImGui.Text("Filter usage:\n" ..
            "  \"\"         display all lines\n" ..
            "  xxx        display lines containing \"xxx\"\n" ..
            "  xxx yyy    display lines containing \"xxx\" and \"yyy\"\n" ..
            "  \"xxx yyy\"  display lines containing \"xxx yyy\"\n" ..
            "  xxx,yyy    display lines containing \"xxx\" or \"yyy\"\n" ..
            "  -xxx       hide lines containing \"xxx\"")
        ImGui.SetNextItemWidth(-FLT_MIN)
        filter:DrawWithHint("##Filter", "Filter (incl -excl)")
        if ImGui.BeginChild("##items", ImVec2(-FLT_MIN, ImGui.GetTextLineHeightWithSpacing() * 15), ImGuiChildFlags.FrameStyle) then
            local lines = { "aaa1.c", "bbb1.c", "ccc1.c", "aaa2.cpp", "bbb2.cpp", "ccc2.cpp", "abc.h", "hello, world" }
            for _, item in ipairs(lines) do
                if filter:PassFilter(item) then
                    ImGui.TextUnformatted(item)
                end
            end
            for _, item in ipairs(ExampleNames) do
                if filter:PassFilter(item) then
                    ImGui.TextUnformatted(item)
                end
            end
        end
        ImGui.EndChild()
        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsTextInput()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsTextInput = {
    -- "Multi-line Text Input"
    ml = {
        text = ImGui.NewTextBuffer(
            "/*\n" ..
            " The Pentium F00F bug, shorthand for F0 0F C7 C8,\n" ..
            " the hexadecimal encoding of one offending instruction,\n" ..
            " more formally, the invalid operand with locked CMPXCHG8B\n" ..
            " instruction bug, is a design flaw in the majority of\n" ..
            " Intel Pentium, Pentium MMX, and Pentium OverDrive\n" ..
            " processors (all in the P5 microarchitecture).\n" ..
            "*/\n\n" ..
            "label:\n" ..
            "\tlock cmpxchg8b eax\n", 1024 * 16),
        flags = ImGuiInputTextFlags.AllowTabInput,
    },
    -- "Filtered Text Input"
    filtered = {
        buf1 = ImGui.NewTextBuffer("", 32), buf2 = ImGui.NewTextBuffer("", 32), buf3 = ImGui.NewTextBuffer("", 32),
        buf4 = ImGui.NewTextBuffer("", 32), buf5 = ImGui.NewTextBuffer("", 32), buf6 = ImGui.NewTextBuffer("", 32),
        buf7 = ImGui.NewTextBuffer("", 32),
    },
    -- "Password Input"
    password = { password = ImGui.NewTextBuffer("password123", 64) },
    -- "Completion, History, Edit Callbacks"
    callbacks = {
        buf1 = ImGui.NewTextBuffer("", 64), buf2 = ImGui.NewTextBuffer("", 64), buf3 = ImGui.NewTextBuffer("", 64),
        edit_count = 0,
    },
    -- "Resize Callback"
    resize = { flags = ImGuiInputTextFlags.None, my_str = ImVector() },
    -- "Eliding, Alignment"
    eliding = { buf1 = ImGui.NewTextBuffer("/path/to/some/folder/with/long/filename.cpp", 128), flags = ImGuiInputTextFlags.ElideLeft },
    -- "Miscellaneous"
    misc = { buf1 = ImGui.NewTextBuffer("", 16), flags = ImGuiInputTextFlags.EscapeClearsAll },
}
function DemoWindowWidgetsTextInput()
    local S_ti = S.DemoWindowWidgetsTextInput
    -- To wire InputText() with std::string or any other custom string type,
    -- see the "Text Input > Resize Callback" section of this demo, and the misc/cpp/imgui_stdlib.h file.
    if ImGui.TreeNode("Text Input") then
        IMGUI_DEMO_MARKER("Widgets/Text Input")
        if ImGui.TreeNode("Multi-line Text Input") then
            IMGUI_DEMO_MARKER("Widgets/Text Input/Multi-line Text Input")
            local s = S_ti.ml
            -- WE ARE USING A FIXED-SIZE BUFFER FOR SIMPLICITY HERE.
            -- If you want to use InputText() with std::string or any custom dynamic string type:
            -- - For std::string: use the wrapper in misc/cpp/imgui_stdlib.h/.cpp
            -- - Otherwise, see the 'Dear ImGui Demo->Widgets->Text Input->Resize Callback' for using ImGuiInputTextFlags_CallbackResize.
            HelpMarker("You can use the ImGuiInputTextFlags_CallbackResize facility if you need to wire InputTextMultiline() to a dynamic string type. See misc/cpp/imgui_stdlib.h for an example. (This is not demonstrated in imgui_demo.cpp because we don't want to include <string> in here)")
            _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ReadOnly", s.flags, ImGuiInputTextFlags.ReadOnly)
            _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_WordWrap", s.flags, ImGuiInputTextFlags.WordWrap)
            ImGui.SameLine(); HelpMarker("Feature is currently in Beta. Please read comments in imgui.h")
            _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_AllowTabInput", s.flags, ImGuiInputTextFlags.AllowTabInput)
            ImGui.SameLine(); HelpMarker("When _AllowTabInput is set, passing through the widget with Tabbing doesn't automatically activate it, in order to also cycling through subsequent widgets.")
            _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_CtrlEnterForNewLine", s.flags, ImGuiInputTextFlags.CtrlEnterForNewLine)
            ImGui.InputTextMultiline("##source", s.text, 1024 * 16, ImVec2(-FLT_MIN, ImGui.GetTextLineHeight() * 16), s.flags)
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Filtered Text Input") then
            IMGUI_DEMO_MARKER("Widgets/Text Input/Filtered Text Input")
            local s = S_ti.filtered
            local TextFilters = {}
            -- Modify character input by altering 'data->Eventchar' (ImGuiInputTextFlags_CallbackCharFilter callback)
            function TextFilters.FilterCasingSwap(data)
                if data.EventChar >= string.byte('a') and data.EventChar <= string.byte('z') then data.EventChar = data.EventChar - (string.byte('a') - string.byte('A')) -- Lowercase becomes uppercase
                elseif data.EventChar >= string.byte('A') and data.EventChar <= string.byte('Z') then data.EventChar = data.EventChar + (string.byte('a') - string.byte('A')) end -- Uppercase becomes lowercase
                return 0
            end

            -- Return 0 (pass) if the character is 'i' or 'm' or 'g' or 'u' or 'i', otherwise return 1 (filter out)
            function TextFilters.FilterImGuiLetters(data)
                if data.EventChar < 256 and string.find("imgui", string.char(data.EventChar), 1, true) then
                    return 0
                end
                return 1
            end

            ImGui.InputText("default", s.buf1, 32)
            ImGui.InputText("decimal", s.buf2, 32, ImGuiInputTextFlags.CharsDecimal)
            ImGui.InputText("hexadecimal", s.buf3, 32, bit32.bor(ImGuiInputTextFlags.CharsHexadecimal, ImGuiInputTextFlags.CharsUppercase))
            ImGui.InputText("uppercase", s.buf4, 32, ImGuiInputTextFlags.CharsUppercase)
            ImGui.InputText("no blank", s.buf5, 32, ImGuiInputTextFlags.CharsNoBlank)
            ImGui.InputText("casing swap", s.buf6, 32, ImGuiInputTextFlags.CallbackCharFilter, TextFilters.FilterCasingSwap) -- Use CharFilter callback to replace characters.
            ImGui.InputText("\"imgui\"", s.buf7, 32, ImGuiInputTextFlags.CallbackCharFilter, TextFilters.FilterImGuiLetters) -- Use CharFilter callback to disable some characters.
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Password Input") then
            IMGUI_DEMO_MARKER("Widgets/Text Input/Password input")
            local s = S_ti.password
            ImGui.InputText("password", s.password, 64, ImGuiInputTextFlags.Password)
            ImGui.SameLine(); HelpMarker("Display all characters as '*'.\nDisable clipboard cut and copy.\nDisable logging.\n")
            ImGui.InputTextWithHint("password (w/ hint)", "<password>", s.password, 64, ImGuiInputTextFlags.Password)
            ImGui.InputText("password (clear)", s.password, 64)
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Completion, History, Edit Callbacks") then
            IMGUI_DEMO_MARKER("Widgets/Text Input/Completion, History, Edit Callbacks")
            local s = S_ti.callbacks
            local Funcs = {}
            function Funcs.MyCallback(data)
                if data.EventFlag == ImGuiInputTextFlags.CallbackCompletion then
                    data:InsertChars(data.CursorPos, "..")
                elseif data.EventFlag == ImGuiInputTextFlags.CallbackHistory then
                    if data.EventKey == ImGuiKey.UpArrow then
                        data:DeleteChars(0, data.BufTextLen)
                        data:InsertChars(0, "Pressed Up!")
                        data:SelectAll()
                    elseif data.EventKey == ImGuiKey.DownArrow then
                        data:DeleteChars(0, data.BufTextLen)
                        data:InsertChars(0, "Pressed Down!")
                        data:SelectAll()
                    end
                elseif data.EventFlag == ImGuiInputTextFlags.CallbackEdit then
                    -- Toggle casing of first character
                    local c = data.Buf[1]
                    if (c >= string.byte('a') and c <= string.byte('z')) or (c >= string.byte('A') and c <= string.byte('Z')) then data.Buf[1] = bit32.bxor(data.Buf[1], 32) end
                    data.BufDirty = true

                    -- Increment a counter
                    local p_int = data.UserData -- [Port] int* -> the statics table, counter in .edit_count
                    p_int.edit_count = p_int.edit_count + 1
                end
                return 0
            end
            ImGui.InputText("Completion", s.buf1, 64, ImGuiInputTextFlags.CallbackCompletion, Funcs.MyCallback)
            ImGui.SameLine(); HelpMarker(
                "Here we append \"..\" each time Tab is pressed. " ..
                "See 'Examples>Console' for a more meaningful demonstration of using this callback.")

            ImGui.InputText("History", s.buf2, 64, ImGuiInputTextFlags.CallbackHistory, Funcs.MyCallback)
            ImGui.SameLine(); HelpMarker(
                "Here we replace and select text each time Up/Down are pressed. " ..
                "See 'Examples>Console' for a more meaningful demonstration of using this callback.")

            ImGui.InputText("Edit", s.buf3, 64, ImGuiInputTextFlags.CallbackEdit, Funcs.MyCallback, s) -- [Port] (void*)&edit_count -> s
            ImGui.SameLine(); HelpMarker(
                "Here we toggle the casing of the first character on every edit + count edits.")
            ImGui.SameLine(); ImGui.Text("(%d)", s.edit_count)

            ImGui.TreePop()
        end

        if ImGui.TreeNode("Resize Callback") then
            IMGUI_DEMO_MARKER("Widgets/Text Input/Resize Callback")
            local s = S_ti.resize
            -- To wire InputText() with std::string or any other custom string type,
            -- you can use the ImGuiInputTextFlags_CallbackResize flag + create a custom ImGui::InputText() wrapper
            -- using your preferred type. See misc/cpp/imgui_stdlib.h for an implementation of this using std::string.
            HelpMarker(
                "Using ImGuiInputTextFlags_CallbackResize to wire your custom string type to InputText().\n\n" ..
                "See misc/cpp/imgui_stdlib.h for an implementation of this for std::string.")
            local Funcs = {}
            function Funcs.MyResizeCallback(data)
                if data.EventFlag == ImGuiInputTextFlags.CallbackResize then
                    local my_str = data.UserData
                    IM_ASSERT(my_str.Data == data.Buf)
                    my_str:resize(data.BufSize, 0) -- NB: On resizing calls, generally data->BufSize == data->BufTextLen + 1 -- [Port] new bytes filled with 0
                    data.Buf = my_str.Data
                end
                return 0
            end

            -- Note: Because ImGui:: is a namespace you would typically add your own function into the namespace.
            -- For example, you code may declare a function 'ImGui::InputText(const char* label, MyString* my_str)'
            function Funcs.MyInputTextMultiline(label, my_str, size, flags)
                if size == nil then size = ImVec2(0, 0) end
                if flags == nil then flags = 0 end
                IM_ASSERT(bit32.band(flags, ImGuiInputTextFlags.CallbackResize) == 0)
                return ImGui.InputTextMultiline(label, my_str.Data, my_str.Size, size, bit32.bor(flags, ImGuiInputTextFlags.CallbackResize), Funcs.MyResizeCallback, my_str)
            end

            -- For this demo we are using ImVector as a string container.
            -- Note that because we need to store a terminating zero character, our size/capacity are 1 more
            -- than usually reported by a typical string class.
            _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_WordWrap", s.flags, ImGuiInputTextFlags.WordWrap)

            local my_str = s.my_str
            if my_str:empty() then
                my_str:push_back(0)
            end
            Funcs.MyInputTextMultiline("##MyStr", my_str, ImVec2(-FLT_MIN, ImGui.GetTextLineHeight() * 16), s.flags)
            ImGui.Text("Data: %s\nSize: %d\nCapacity: %d", tostring(my_str.Data), my_str.Size, my_str.Capacity) -- [Port] %p -> %s + tostring
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Eliding, Alignment") then
            IMGUI_DEMO_MARKER("Widgets/Text Input/Eliding, Alignment")
            local s = S_ti.eliding
            _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ElideLeft", s.flags, ImGuiInputTextFlags.ElideLeft)
            ImGui.InputText("Path", s.buf1, 128, s.flags)
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Miscellaneous") then
            IMGUI_DEMO_MARKER("Widgets/Text Input/Miscellaneous")
            local s = S_ti.misc
            _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_EscapeClearsAll", s.flags, ImGuiInputTextFlags.EscapeClearsAll)
            _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_ReadOnly", s.flags, ImGuiInputTextFlags.ReadOnly)
            _, s.flags = ImGui.CheckboxFlags("ImGuiInputTextFlags_NoUndoRedo", s.flags, ImGuiInputTextFlags.NoUndoRedo)
            ImGui.InputText("Hello", s.buf1, 16, s.flags)
            ImGui.TreePop()
        end

        ImGui.TreePop()
    end

end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsTooltips()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsTooltips = {
    arr = { 0.6, 0.1, 1.0, 0.5, 0.92, 0.1, 0.2 },
    always_on = 0,
}
function DemoWindowWidgetsTooltips()
    local s = S.DemoWindowWidgetsTooltips
    if ImGui.TreeNode("Tooltips") then
        IMGUI_DEMO_MARKER("Widgets/Tooltips")
        -- Tooltips are windows following the mouse. They do not take focus away.
        ImGui.SeparatorText("General")

        -- Typical use cases:
        -- - Short-form (text only):      SetItemTooltip("Hello");
        -- - Short-form (any contents):   if (BeginItemTooltip()) { Text("Hello"); EndTooltip(); }

        -- - Full-form (text only):       if (IsItemHovered(...)) { SetTooltip("Hello"); }
        -- - Full-form (any contents):    if (IsItemHovered(...) && BeginTooltip()) { Text("Hello"); EndTooltip(); }

        HelpMarker(
            "Tooltip are typically created by using a IsItemHovered() + SetTooltip() sequence.\n\n" ..
            "We provide a helper SetItemTooltip() function to perform the two with standards flags.")

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

        -- Showcase NOT relying on a IsItemHovered() to emit a tooltip.
        -- Here the tooltip is always emitted when 'always_on == true'.
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

        HelpMarker(
            "Passing ImGuiHoveredFlags_ForTooltip to IsItemHovered() is the preferred way to standardize " ..
            "tooltip activation details across your application. You may however decide to use custom " ..
            "flags for a specific tooltip instance.")

        -- The following examples are passed for documentation purpose but may not be useful to most users.
        -- Passing ImGuiHoveredFlags_ForTooltip to IsItemHovered() will pull ImGuiHoveredFlags flags values from
        -- 'style.HoverFlagsForTooltipMouse' or 'style.HoverFlagsForTooltipNav' depending on whether mouse or keyboard/gamepad is being used.
        -- With default settings, ImGuiHoveredFlags_ForTooltip is equivalent to ImGuiHoveredFlags_DelayShort + ImGuiHoveredFlags_Stationary.
        ImGui.Button("Manual", sz)
        if ImGui.IsItemHovered(ImGuiHoveredFlags.ForTooltip) then
            ImGui.SetTooltip("I am a manually emitted tooltip.")
        end

        ImGui.Button("DelayNone", sz)
        if ImGui.IsItemHovered(ImGuiHoveredFlags.DelayNone) then
            ImGui.SetTooltip("I am a tooltip with no delay.")
        end

        ImGui.Button("DelayShort", sz)
        if ImGui.IsItemHovered(bit32.bor(ImGuiHoveredFlags.DelayShort, ImGuiHoveredFlags.NoSharedDelay)) then
            ImGui.SetTooltip("I am a tooltip with a short delay (%0.2f sec).", ImGui.GetStyle().HoverDelayShort)
        end

        ImGui.Button("DelayLong", sz)
        if ImGui.IsItemHovered(bit32.bor(ImGuiHoveredFlags.DelayNormal, ImGuiHoveredFlags.NoSharedDelay)) then
            ImGui.SetTooltip("I am a tooltip with a long delay (%0.2f sec).", ImGui.GetStyle().HoverDelayNormal)
        end

        ImGui.Button("Stationary", sz)
        if ImGui.IsItemHovered(ImGuiHoveredFlags.Stationary) then
            ImGui.SetTooltip("I am a tooltip requiring mouse to be stationary before activating.")
        end

        -- Using ImGuiHoveredFlags_ForTooltip will pull flags from 'style.HoverFlagsForTooltipMouse' or 'style.HoverFlagsForTooltipNav',
        -- which default value include the ImGuiHoveredFlags_AllowWhenDisabled flag.
        ImGui.BeginDisabled()
        ImGui.Button("Disabled item", sz)
        if ImGui.IsItemHovered(ImGuiHoveredFlags.ForTooltip) then
            ImGui.SetTooltip("I am a tooltip for a disabled item.")
        end
        ImGui.EndDisabled()

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsTreeNodes()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsTreeNodes = {
    base_flags = bit32.bor(ImGuiTreeNodeFlags.DrawLinesFull, ImGuiTreeNodeFlags.DefaultOpen), -- "Hierarchy Lines"
    selection_mask = 0x00,
    base_flags_2 = bit32.bor(ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick, ImGuiTreeNodeFlags.SpanAvailWidth), -- "Advanced"
    align_label_with_current_x_position = false,
    use_drag_and_drop = false,
}
function DemoWindowWidgetsTreeNodes()
    local s = S.DemoWindowWidgetsTreeNodes
    if ImGui.TreeNode("Tree Nodes") then
        IMGUI_DEMO_MARKER("Widgets/Tree Nodes")
        -- See see "Examples -> Property Editor" (ShowExampleAppPropertyEditor() function) for a fancier, data-driven tree.
        if ImGui.TreeNode("Basic Trees") then
            IMGUI_DEMO_MARKER("Widgets/Tree Nodes/Basic Trees")
            for i = 0, 4 do
                -- Use SetNextItemOpen() so set the default state of a node to be open. We could
                -- also use TreeNodeEx() with the ImGuiTreeNodeFlags_DefaultOpen flag to achieve the same thing!
                if i == 0 then
                    ImGui.SetNextItemOpen(true, ImGuiCond.Once)
                end

                -- Here we use PushID() to generate a unique base ID, and then the "" used as TreeNode id won't conflict.
                -- An alternative to using 'PushID() + TreeNode("", ...)' to generate a unique ID is to use 'TreeNode((void*)(intptr_t)i, ...)',
                -- aka generate a dummy pointer-sized value to be hashed. The demo below uses that technique. Both are fine.
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
            IMGUI_DEMO_MARKER("Widgets/Tree Nodes/Hierarchy Lines")
            HelpMarker("Default option for DrawLinesXXX is stored in style.TreeLinesFlags")
            _, s.base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesNone", s.base_flags, ImGuiTreeNodeFlags.DrawLinesNone)
            _, s.base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesFull", s.base_flags, ImGuiTreeNodeFlags.DrawLinesFull)
            _, s.base_flags = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesToNodes", s.base_flags, ImGuiTreeNodeFlags.DrawLinesToNodes)

            if ImGui.TreeNodeEx("Parent", s.base_flags) then
                if ImGui.TreeNodeEx("Child 1", s.base_flags) then
                    ImGui.Button("Button for Child 1")
                    ImGui.TreePop()
                end
                if ImGui.TreeNodeEx("Child 2", s.base_flags) then
                    ImGui.Button("Button for Child 2")
                    ImGui.TreePop()
                end
                ImGui.Text("Remaining contents")
                ImGui.Text("Remaining contents")
                ImGui.TreePop()
            end

            ImGui.TreePop()
        end

        if ImGui.TreeNode("Clipping Large Trees") then
            IMGUI_DEMO_MARKER("Widgets/Tree Nodes/Clipping Large Trees")
            ImGui.TextWrapped(
                "- Using ImGuiListClipper with trees is a less easy than on arrays or grids.\n" ..
                "- Refer to 'Demo->Examples->Property Editor' for an example of how to do that.\n" ..
                "- Discuss in #3823")
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Selectable Nodes") then
            IMGUI_DEMO_MARKER("Widgets/Tree Nodes/Selectable Nodes")
            HelpMarker(
                "Manually implemented selectable nodes.\n" ..
                "Click to select, Ctrl+Click to toggle, click on arrows or double-click to open.\n\n" ..
                "You may also use the multi-select API (see 'Demo->Widgets->Selection State & Multi-Select') for more advanced multi-selection features.")

            -- Hold in 'selection_mask' a simple representation of what may be user-side selection state.
            -- - You may retain selection state inside or outside your objects in whatever format you see fit.
            --   You may use ImGuiSelectionBasicStorage which is conceptually close to a set<> of identifiers.
            -- - We record which node was clicked and then apply selection at the end of the loop.
            -- - This is a manual and simplified reimplementation of multi-selection, which the full
            --   BeginMultiSelect() API implements better, but which is not trivial to wire for trees.
            local node_clicked_idx = -1
            for node_n = 0, 5 do
                -- Disable the default "open on single-click behavior" + set Selected flag according to our selection.
                -- To alter selection we use if 'IsItemClicked() && !IsItemToggledOpen()', so clicking on an arrow doesn't alter selection.
                -- In a BeginMultiSelect()/EndMultiSelect() we could use IsItemToggledSelection() but here we reimplement and use our own logic.
                local flags = bit32.bor(ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick, ImGuiTreeNodeFlags.SpanAvailWidth)
                if bit32.band(s.selection_mask, bit32.lshift(1, node_n)) ~= 0 then
                    flags = bit32.bor(flags, ImGuiTreeNodeFlags.Selected)
                end

                local is_open = ImGui.TreeNodeEx(node_n, flags, "Selectable Node %d", node_n) -- [Port] (void*)(intptr_t)node_n -> node_n
                if ImGui.IsItemClicked() and not ImGui.IsItemToggledOpen() then
                    node_clicked_idx = node_n
                end
                if is_open then
                    ImGui.BulletText("<Node contents here>")
                    ImGui.TreePop()
                end
            end
            if node_clicked_idx ~= -1 then
                -- Update selection state (process outside of tree loop to avoid visual inconsistencies during the clicking frame)
                if ImGui.GetIO().KeyCtrl then
                    s.selection_mask = bit32.bxor(s.selection_mask, bit32.lshift(1, node_clicked_idx)) -- Ctrl+Click to toggle
                else --if (!(selection_mask & (1 << node_clicked_idx))) -- Depending on selection behavior you want, may want to preserve selection when clicking on item that is part of the selection
                    s.selection_mask = bit32.lshift(1, node_clicked_idx)                               -- Click to single-select
                end
            end
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Advanced") then
            IMGUI_DEMO_MARKER("Widgets/Tree Nodes/Advanced")
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_OpenOnArrow", s.base_flags_2, ImGuiTreeNodeFlags.OpenOnArrow)
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_OpenOnDoubleClick", s.base_flags_2, ImGuiTreeNodeFlags.OpenOnDoubleClick)
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanAvailWidth", s.base_flags_2, ImGuiTreeNodeFlags.SpanAvailWidth); ImGui.SameLine(); HelpMarker("Extend hit area to all available width instead of allowing more items to be laid out after the node.")
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanFullWidth", s.base_flags_2, ImGuiTreeNodeFlags.SpanFullWidth)
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanLabelWidth", s.base_flags_2, ImGuiTreeNodeFlags.SpanLabelWidth); ImGui.SameLine(); HelpMarker("Reduce hit area to the text label and a bit of margin.")
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanAllColumns", s.base_flags_2, ImGuiTreeNodeFlags.SpanAllColumns); ImGui.SameLine(); HelpMarker("For use in Tables only.")
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_AllowOverlap", s.base_flags_2, ImGuiTreeNodeFlags.AllowOverlap)
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_Framed", s.base_flags_2, ImGuiTreeNodeFlags.Framed); ImGui.SameLine(); HelpMarker("Draw frame with background (e.g. for CollapsingHeader)")
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_FramePadding", s.base_flags_2, ImGuiTreeNodeFlags.FramePadding)
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_NavLeftJumpsToParent", s.base_flags_2, ImGuiTreeNodeFlags.NavLeftJumpsToParent)

            HelpMarker("Default option for DrawLinesXXX is stored in style.TreeLinesFlags")
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesNone", s.base_flags_2, ImGuiTreeNodeFlags.DrawLinesNone)
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesFull", s.base_flags_2, ImGuiTreeNodeFlags.DrawLinesFull)
            _, s.base_flags_2 = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_DrawLinesToNodes", s.base_flags_2, ImGuiTreeNodeFlags.DrawLinesToNodes)

            _, s.align_label_with_current_x_position = ImGui.Checkbox("Align label with current X position", s.align_label_with_current_x_position)
            _, s.use_drag_and_drop = ImGui.Checkbox("Make Tree Nodes as drag & drop sources", s.use_drag_and_drop)
            if s.align_label_with_current_x_position then
                ImGui.Unindent(ImGui.GetTreeNodeToLabelSpacing())
            end

            for node_n = 0, 5 do
                local node_flags = s.base_flags_2
                if node_n < 3 then
                    -- Items 0..2 are Tree Node
                    local is_open = ImGui.TreeNodeEx(node_n, node_flags, "Selectable Node %d", node_n)
                    if s.use_drag_and_drop and ImGui.BeginDragDropSource() then
                        ImGui.SetDragDropPayload("MY_TREENODE_PAYLOAD_TYPE", nil, 0)
                        ImGui.Text("This is a drag and drop source")
                        ImGui.EndDragDropSource()
                    end
                    if node_n == 2 and bit32.band(s.base_flags_2, ImGuiTreeNodeFlags.SpanLabelWidth) ~= 0 then
                        -- Item 2 has an additional inline button to help demonstrate SpanLabelWidth.
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
                    -- Items 3..5 are Tree Leaves
                    -- The only reason we use TreeNode at all is to allow selection of the leaf. Otherwise we can
                    -- use BulletText() or advance the cursor by GetTreeNodeToLabelSpacing() and call Text().
                    node_flags = bit32.bor(node_flags, ImGuiTreeNodeFlags.Leaf, ImGuiTreeNodeFlags.NoTreePushOnOpen) -- ImGuiTreeNodeFlags_Bullet
                    ImGui.TreeNodeEx(node_n, node_flags, "Selectable Leaf %d", node_n)
                    if s.use_drag_and_drop and ImGui.BeginDragDropSource() then
                        ImGui.SetDragDropPayload("MY_TREENODE_PAYLOAD_TYPE", nil, 0)
                        ImGui.Text("This is a drag and drop source")
                        ImGui.EndDragDropSource()
                    end
                end
            end
            if s.align_label_with_current_x_position then
                ImGui.Indent(ImGui.GetTreeNodeToLabelSpacing())
            end
            ImGui.TreePop()
        end
        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgetsVerticalSliders()
-------------------------------------------------------------------------------

S.DemoWindowWidgetsVerticalSliders = {
    int_value = 0,
    values = { 0.0, 0.60, 0.35, 0.9, 0.70, 0.20, 0.0 },
    values2 = { 0.20, 0.80, 0.40, 0.25 },
}
function DemoWindowWidgetsVerticalSliders()
    local s = S.DemoWindowWidgetsVerticalSliders
    if ImGui.TreeNode("Vertical Sliders") then
        IMGUI_DEMO_MARKER("Widgets/Vertical Sliders")
        local spacing = 4
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(spacing, spacing))

        s.int_value = ImGui.VSliderInt("##int", ImVec2(18, 160), s.int_value, 0, 5)
        ImGui.SameLine()

        local values = s.values
        ImGui.PushID("set1")
        for i = 0, 6 do
            if i > 0 then ImGui.SameLine() end
            ImGui.PushID(i)
            ImGui.PushStyleColor(ImGuiCol.FrameBg, ImColor.HSV(i / 7.0, 0.5, 0.5).Value)
            ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, ImColor.HSV(i / 7.0, 0.6, 0.5).Value)
            ImGui.PushStyleColor(ImGuiCol.FrameBgActive, ImColor.HSV(i / 7.0, 0.7, 0.5).Value)
            ImGui.PushStyleColor(ImGuiCol.SliderGrab, ImColor.HSV(i / 7.0, 0.9, 0.9).Value)
            values[i + 1] = ImGui.VSliderFloat("##v", ImVec2(18, 160), values[i + 1], 0.0, 1.0, "")
            if ImGui.IsItemActive() or ImGui.IsItemHovered() then
                ImGui.SetTooltip("%.3f", values[i + 1])
            end
            ImGui.PopStyleColor(4)
            ImGui.PopID()
        end
        ImGui.PopID()

        ImGui.SameLine()
        ImGui.PushID("set2")
        local values2 = s.values2
        local rows = 3
        local small_slider_size = ImVec2(18, math.floor((160.0 - (rows - 1) * spacing) / rows))
        for nx = 0, 3 do
            if nx > 0 then ImGui.SameLine() end
            ImGui.BeginGroup()
            for ny = 0, rows - 1 do
                ImGui.PushID(nx * rows + ny)
                values2[nx + 1] = ImGui.VSliderFloat("##v", small_slider_size, values2[nx + 1], 0.0, 1.0, "")
                if ImGui.IsItemActive() or ImGui.IsItemHovered() then
                    ImGui.SetTooltip("%.3f", values2[nx + 1])
                end
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
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowWidgets()
-------------------------------------------------------------------------------

function DemoWindowWidgets(demo_data)
    --ImGui.SetNextItemOpen(true, ImGuiCond.Once)
    if not ImGui.CollapsingHeader("Widgets") then
        return
    end
    -- IMGUI_DEMO_MARKER("Widgets");

    local disable_all = demo_data.DisableSections -- The Checkbox for that is inside the "Disabled" section at the bottom
    local override_liveedit = demo_data.LiveEditOverride
    if disable_all then
        ImGui.BeginDisabled()
    end
    if override_liveedit then
        ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputText, bit32.band(demo_data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputText) ~= 0)
        ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInputScalar, bit32.band(demo_data.LiveEditFlags, ImGuiItemFlags.LiveEditOnInputScalar) ~= 0)
    end

    DemoWindowWidgetsBasic()
    DemoWindowWidgetsBullets()
    DemoWindowWidgetsCollapsingHeaders()
    DemoWindowWidgetsComboBoxes()
    DemoWindowWidgetsColorAndPickers()
    DemoWindowWidgetsDataTypes()

    if disable_all then
        ImGui.EndDisabled()
    end
    DemoWindowWidgetsDisableBlocks(demo_data)
    if disable_all then
        ImGui.BeginDisabled()
    end

    DemoWindowWidgetsDragAndDrop()
    DemoWindowWidgetsDragsAndSliders()
    DemoWindowWidgetsFonts()
    DemoWindowWidgetsImages()
    DemoWindowWidgetsListBoxes()
    DemoWindowWidgetsLiveEdit(demo_data)
    DemoWindowWidgetsMixedValues()
    DemoWindowWidgetsMultiComponents()
    DemoWindowWidgetsPlotting()
    DemoWindowWidgetsProgressBars()
    DemoWindowWidgetsQueryingStatuses()
    DemoWindowWidgetsSelectables()
    DemoWindowWidgetsSelectionAndMultiSelect(demo_data)
    DemoWindowWidgetsTabs()
    DemoWindowWidgetsText()
    DemoWindowWidgetsTextFilter()
    DemoWindowWidgetsTextInput()
    DemoWindowWidgetsTooltips()
    DemoWindowWidgetsTreeNodes()
    DemoWindowWidgetsVerticalSliders()

    if override_liveedit then
        ImGui.PopItemFlag()
        ImGui.PopItemFlag()
    end
    if disable_all then
        ImGui.EndDisabled()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowLayout()
-------------------------------------------------------------------------------

S.DemoWindowLayout = {
    -- Child windows
    disable_mouse_wheel = false,
    disable_menu = false,
    draw_lines = 3,
    max_height_in_lines = 10,
    offset_x = 0,
    override_bg_color = true,
    child_flags = bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeX, ImGuiChildFlags.ResizeY),
    -- Widgets Width
    f = 0.0,
    show_indented_items = true,
    -- Basic Horizontal Layout
    c1 = false, c2 = false, c3 = false, c4 = false,
    f0 = 1.0, f1 = 2.0, f2 = 3.0,
    item = -1,
    selection = { 0, 1, 2, 3 },
    -- Scrolling
    track_item = 50,
    enable_track = true,
    enable_extra_decorations = false,
    scroll_to_off_px = 0.0,
    scroll_to_pos_px = 200.0,
    lines = 7,
    show_horizontal_contents_size_demo_window = false,
    show_h_scrollbar = true,
    show_button = true,
    show_tree_nodes = true,
    show_text_wrapped = false,
    show_columns = true,
    show_tab_bar = true,
    show_child = false,
    explicit_content_size = false,
    contents_size_x = 300.0,
    -- Text Clipping
    size = ImVec2(100.0, 100.0),
    offset = ImVec2(30.0, 30.0),
    -- Overlap Mode
    enable_allow_overlap = true,
}

function DemoWindowLayout()
    local s = S.DemoWindowLayout
    if not ImGui.CollapsingHeader("Layout & Scrolling") then
        return
    end

    if ImGui.TreeNode("Child windows") then
        IMGUI_DEMO_MARKER("Layout/Child windows")
        ImGui.SeparatorText("Child windows")

        HelpMarker("Use child windows to begin into a self-contained independent scrolling/clipping regions within a host window.")
        _, s.disable_mouse_wheel = ImGui.Checkbox("Disable Mouse Wheel", s.disable_mouse_wheel)
        _, s.disable_menu = ImGui.Checkbox("Disable Menu", s.disable_menu)

        -- Child 1: no border, enable horizontal scrollbar
        do
            local window_flags = ImGuiWindowFlags.HorizontalScrollbar
            if s.disable_mouse_wheel then
                window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoScrollWithMouse)
            end
            ImGui.BeginChild("ChildL", ImVec2(ImGui.GetContentRegionAvail().x * 0.5, 260), ImGuiChildFlags.None, window_flags)
            for i = 0, 99 do
                ImGui.Text("%04d: scrollable region", i)
            end
            ImGui.EndChild()
        end

        ImGui.SameLine()

        -- Child 2: rounded border
        do
            local window_flags = ImGuiWindowFlags.None
            if s.disable_mouse_wheel then
                window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoScrollWithMouse)
            end
            if not s.disable_menu then
                window_flags = bit32.bor(window_flags, ImGuiWindowFlags.MenuBar)
            end
            ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, 5.0)
            ImGui.BeginChild("ChildR", ImVec2(0, 260), ImGuiChildFlags.Borders, window_flags)
            if not s.disable_menu and ImGui.BeginMenuBar() then
                if ImGui.BeginMenu("Menu") then
                    ShowExampleMenuFile()
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
            HelpMarker("Drag bottom border to resize. Double-click bottom border to auto-fit to vertical contents.")
            --if (ImGui.Button("Set Height to 200"))
            --    ImGui.SetNextWindowSize(ImVec2(-FLT_MIN, 200.0f));

            ImGui.PushStyleColor(ImGuiCol.ChildBg, ImGui.GetStyleColorVec4(ImGuiCol.FrameBg))
            if ImGui.BeginChild("ResizableChild", ImVec2(-FLT_MIN, ImGui.GetTextLineHeightWithSpacing() * 8), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeY)) then
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
            s.draw_lines = ImGui.DragInt("Lines Count", s.draw_lines, 0.2)
            ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
            s.max_height_in_lines = ImGui.DragInt("Max Height (in Lines)", s.max_height_in_lines, 0.2)

            ImGui.SetNextWindowSizeConstraints(ImVec2(0.0, ImGui.GetTextLineHeightWithSpacing() * 1), ImVec2(FLT_MAX, ImGui.GetTextLineHeightWithSpacing() * s.max_height_in_lines))
            if ImGui.BeginChild("ConstrainedChild", ImVec2(-FLT_MIN, 0.0), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.AutoResizeY)) then
                for n = 0, s.draw_lines - 1 do
                    ImGui.Text("Line %04d", n)
                end
            end
            ImGui.EndChild()
        end

        ImGui.SeparatorText("Misc/Advanced")

        -- Demonstrate a few extra things
        -- - Changing ImGuiCol.ChildBg (which is transparent black in default styles)
        -- - Using SetCursorPos() to position child window (the child window is an item from the POV of parent window)
        --   You can also call SetNextWindowPos() to position the child window. The parent window will effectively
        --   layout from this position.
        -- - Using ImGui.GetItemRectMin/Max() to query the "item" state (because the child window is an item from
        --   the POV of the parent window). See 'Demo->Querying Status (Edited/Active/Hovered etc.)' for details.
        do
            ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
            s.offset_x = ImGui.DragInt("Offset X", s.offset_x, 1.0, -1000, 1000)
            _, s.override_bg_color = ImGui.Checkbox("Override ChildBg color", s.override_bg_color)
            _, s.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_Borders", s.child_flags, ImGuiChildFlags.Borders)
            _, s.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_AlwaysUseWindowPadding", s.child_flags, ImGuiChildFlags.AlwaysUseWindowPadding)
            _, s.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_ResizeX", s.child_flags, ImGuiChildFlags.ResizeX)
            _, s.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_ResizeY", s.child_flags, ImGuiChildFlags.ResizeY)
            _, s.child_flags = ImGui.CheckboxFlags("ImGuiChildFlags_FrameStyle", s.child_flags, ImGuiChildFlags.FrameStyle)
            ImGui.SameLine(); HelpMarker("Style the child window like a framed item: use FrameBg, FrameRounding, FrameBorderSize, FramePadding instead of ChildBg, ChildRounding, ChildBorderSize, WindowPadding.")
            if bit32.band(s.child_flags, ImGuiChildFlags.FrameStyle) ~= 0 then
                s.override_bg_color = false
            end

            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + s.offset_x)
            if s.override_bg_color then
                ImGui.PushStyleColor(ImGuiCol.ChildBg, IM_COL32(255, 0, 0, 100))
            end
            ImGui.BeginChild("Red", ImVec2(200, 100), s.child_flags, ImGuiWindowFlags.None)
            if s.override_bg_color then
                ImGui.PopStyleColor()
            end

            for n = 0, 49 do
                ImGui.Text("Some test %d", n)
            end
            ImGui.EndChild()
            local child_is_hovered = ImGui.IsItemHovered()
            local child_rect_min = ImGui.GetItemRectMin()
            local child_rect_max = ImGui.GetItemRectMax()
            ImGui.Text("Hovered: %d", child_is_hovered and 1 or 0)
            ImGui.Text("Rect of child window is: (%.0f,%.0f) (%.0f,%.0f)", child_rect_min.x, child_rect_min.y, child_rect_max.x, child_rect_max.y)
        end

        ImGui.TreePop()
    end

    if ImGui.TreeNode("Widgets Width") then
        IMGUI_DEMO_MARKER("Layout/Widgets Width")
        _, s.show_indented_items = ImGui.Checkbox("Show indented items", s.show_indented_items)

        -- Use SetNextItemWidth() to set the width of a single upcoming item.
        -- Use PushItemWidth()/PopItemWidth() to set the width of a group of items.
        -- In real code use you'll probably want to choose width values that are proportional to your font size
        -- e.g. Using '20.0f * GetFontSize()' as width instead of '200.0f', etc.

        ImGui.Text("SetNextItemWidth/PushItemWidth(100)")
        ImGui.SameLine(); HelpMarker("Fixed width.")
        ImGui.PushItemWidth(100)
        s.f = ImGui.DragFloat("float##1b", s.f)
        if s.show_indented_items then
            ImGui.Indent()
            s.f = ImGui.DragFloat("float (indented)##1b", s.f)
            ImGui.Unindent()
        end
        ImGui.PopItemWidth()

        ImGui.Text("SetNextItemWidth/PushItemWidth(-100)")
        ImGui.SameLine(); HelpMarker("Align to right edge minus 100")
        ImGui.PushItemWidth(-100)
        s.f = ImGui.DragFloat("float##2a", s.f)
        if s.show_indented_items then
            ImGui.Indent()
            s.f = ImGui.DragFloat("float (indented)##2b", s.f)
            ImGui.Unindent()
        end
        ImGui.PopItemWidth()

        ImGui.Text("SetNextItemWidth/PushItemWidth(GetContentRegionAvail().x * 0.5f)")
        ImGui.SameLine(); HelpMarker("Half of available width.\n(~ right-cursor_pos)\n(works within a column set)")
        ImGui.PushItemWidth(ImGui.GetContentRegionAvail().x * 0.5)
        s.f = ImGui.DragFloat("float##3a", s.f)
        if s.show_indented_items then
            ImGui.Indent()
            s.f = ImGui.DragFloat("float (indented)##3b", s.f)
            ImGui.Unindent()
        end
        ImGui.PopItemWidth()

        ImGui.Text("SetNextItemWidth/PushItemWidth(-GetContentRegionAvail().x * 0.5f)")
        ImGui.SameLine(); HelpMarker("Align to right edge minus half")
        ImGui.PushItemWidth(-ImGui.GetContentRegionAvail().x * 0.5)
        s.f = ImGui.DragFloat("float##4a", s.f)
        if s.show_indented_items then
            ImGui.Indent()
            s.f = ImGui.DragFloat("float (indented)##4b", s.f)
            ImGui.Unindent()
        end
        ImGui.PopItemWidth()

        ImGui.Text("SetNextItemWidth/PushItemWidth(-Min(GetContentRegionAvail().x * 0.40f, GetFontSize() * 12))")
        ImGui.PushItemWidth(-ImMin(ImGui.GetFontSize() * 12, ImGui.GetContentRegionAvail().x * 0.40))
        s.f = ImGui.DragFloat("float##5a", s.f)
        if s.show_indented_items then
            ImGui.Indent()
            s.f = ImGui.DragFloat("float (indented)##5b", s.f)
            ImGui.Unindent()
        end
        ImGui.PopItemWidth()

        -- Demonstrate using PushItemWidth to surround three items.
        -- Calling SetNextItemWidth() before each of them would have the same effect.
        ImGui.Text("SetNextItemWidth/PushItemWidth(-FLT_MIN)")
        ImGui.SameLine(); HelpMarker("Align to right edge")
        ImGui.PushItemWidth(-FLT_MIN)
        s.f = ImGui.DragFloat("##float6a", s.f)
        if s.show_indented_items then
            ImGui.Indent()
            s.f = ImGui.DragFloat("float (indented)##6b", s.f)
            ImGui.Unindent()
        end
        ImGui.PopItemWidth()

        ImGui.TreePop()
    end

    if ImGui.TreeNode("Basic Horizontal Layout") then
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
        _, s.c1 = ImGui.Checkbox("My", s.c1); ImGui.SameLine()
        _, s.c2 = ImGui.Checkbox("Tailor", s.c2); ImGui.SameLine()
        _, s.c3 = ImGui.Checkbox("Is", s.c3); ImGui.SameLine()
        _, s.c4 = ImGui.Checkbox("Rich", s.c4)

        -- Various
        ImGui.PushItemWidth(ImGui.CalcTextSize("AAAAAAA").x)
        local items = { "AAAA", "BBBB", "CCCC", "DDDD" }
        s.item = ImGui.Combo("Combo", s.item, items, #items); ImGui.SameLine()
        s.f0 = ImGui.SliderFloat("X", s.f0, 0.0, 5.0); ImGui.SameLine()
        s.f1 = ImGui.SliderFloat("Y", s.f1, 0.0, 5.0); ImGui.SameLine()
        s.f2 = ImGui.SliderFloat("Z", s.f2, 0.0, 5.0)

        ImGui.Text("Lists:")
        for i = 0, 3 do
            if i > 0 then ImGui.SameLine() end
            ImGui.PushID(i)
            s.selection[i + 1] = ImGui.ListBox("", s.selection[i + 1], items, #items)
            ImGui.PopID()
            --ImGui.SetItemTooltip("ListBox %d hovered", i);
        end
        ImGui.PopItemWidth()

        -- Dummy
        IMGUI_DEMO_MARKER("Layout/Basic Horizontal Layout/Dummy")
        local button_sz = ImVec2(40, 40)
        ImGui.Button("A", button_sz); ImGui.SameLine()
        ImGui.Dummy(button_sz); ImGui.SameLine()
        ImGui.Button("B", button_sz)

        -- Manually wrapping
        -- (we should eventually provide this as an automatic layout feature, but for now you can do it manually)
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

        ImGui.TreePop()
    end

    if ImGui.TreeNode("Groups") then
        IMGUI_DEMO_MARKER("Layout/Groups")
        HelpMarker(
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

        if ImGui.BeginListBox("List", size) then
            ImGui.Selectable("Selected", true)
            ImGui.Selectable("Not Selected", false)
            ImGui.EndListBox()
        end

        ImGui.TreePop()
    end

    if ImGui.TreeNode("Text Baseline Alignment") then
        IMGUI_DEMO_MARKER("Layout/Text Baseline Alignment")
        do
            ImGui.BulletText("Text baseline:")
            ImGui.SameLine(); HelpMarker(
                "This is testing the vertical alignment that gets applied on text to keep it aligned with widgets. " ..
                "Lines only composed of text or \"small\" widgets use less vertical space than lines with framed widgets.")
            ImGui.Indent()

            ImGui.Text("KO Blahblah"); ImGui.SameLine()
            ImGui.Button("Some framed item"); ImGui.SameLine()
            HelpMarker("Baseline of button will look misaligned with text..")

            -- If your line starts with text, call AlignTextToFramePadding() to align text to upcoming widgets.
            -- (because we don't know what's coming after the Text() statement, we need to move the text baseline
            -- down by FramePadding.y ahead of time)
            ImGui.AlignTextToFramePadding()
            ImGui.Text("OK Blahblah"); ImGui.SameLine()
            ImGui.Button("Some framed item##2"); ImGui.SameLine()
            HelpMarker("We call AlignTextToFramePadding() to vertically align the text baseline by +FramePadding.y")

            -- SmallButton() uses the same vertical padding as Text
            ImGui.Button("TEST##1"); ImGui.SameLine()
            ImGui.Text("TEST"); ImGui.SameLine()
            ImGui.SmallButton("TEST##2")

            -- If your line starts with text, call AlignTextToFramePadding() to align text to upcoming widgets.
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

            -- SmallButton() sets FramePadding to zero. Text baseline is aligned to match baseline of previous Button.
            ImGui.Button("80x80", ImVec2(80, 80))
            ImGui.SameLine()
            ImGui.Button("50x50", ImVec2(50, 50))
            ImGui.SameLine()
            ImGui.Button("Button()")
            ImGui.SameLine()
            ImGui.SmallButton("SmallButton()")

            -- Tree
            -- (here the node appears after a button and has odd intent, so we use ImGuiTreeNodeFlags.DrawLinesNone to disable hierarchy outline)
            local spacing = ImGui.GetStyle().ItemInnerSpacing.x
            ImGui.Button("Button##1") -- Will make line higher
            ImGui.SameLine(0.0, spacing)
            if ImGui.TreeNodeEx("Node##1", ImGuiTreeNodeFlags.DrawLinesNone) then
                -- Placeholder tree data
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

            -- Vertically align text node a bit lower so it'll be vertically centered with upcoming widget.
            -- Otherwise you can use SmallButton() (smaller fit).
            ImGui.AlignTextToFramePadding()

            -- Common mistake to avoid: if we want to SameLine after TreeNode we need to do it before we add
            -- other contents "inside" the node.
            local node_open = ImGui.TreeNode("Node##3")
            ImGui.SameLine(0.0, spacing); ImGui.Button("Button##3")
            if node_open then
                -- Placeholder tree data
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

        ImGui.TreePop()
    end

    if ImGui.TreeNode("Scrolling") then
        IMGUI_DEMO_MARKER("Layout/Scrolling/Vertical")
        -- Vertical scroll functions
        HelpMarker("Use SetScrollHereY() or SetScrollFromPosY() to scroll to a given vertical position.")

        _, s.enable_extra_decorations = ImGui.Checkbox("Decoration", s.enable_extra_decorations)

        ImGui.PushItemWidth(ImGui.GetFontSize() * 10)
        local track_changed
        s.track_item, track_changed = ImGui.DragInt("##item", s.track_item, 0.25, 0, 99, "Item = %d")
        s.enable_track = s.enable_track or track_changed
        ImGui.SameLine()
        _, s.enable_track = ImGui.Checkbox("Track", s.enable_track)

        local scroll_to_off
        s.scroll_to_off_px, scroll_to_off = ImGui.DragFloat("##off", s.scroll_to_off_px, 1.00, 0, FLT_MAX, "+%.0f px")
        ImGui.SameLine()
        scroll_to_off = ImGui.Button("Scroll Offset") or scroll_to_off

        local scroll_to_pos
        s.scroll_to_pos_px, scroll_to_pos = ImGui.DragFloat("##pos", s.scroll_to_pos_px, 1.00, -10, FLT_MAX, "X/Y = %.0f px")
        ImGui.SameLine()
        scroll_to_pos = ImGui.Button("Scroll To Pos") or scroll_to_pos
        ImGui.PopItemWidth()

        if scroll_to_off or scroll_to_pos then
            s.enable_track = false
        end

        local style = ImGui.GetStyle()
        local child_w = (ImGui.GetContentRegionAvail().x - 4 * style.ItemSpacing.x) / 5
        if child_w < 1.0 then
            child_w = 1.0
        end
        ImGui.PushID("##VerticalScrolling")
        for i = 0, 4 do
            if i > 0 then ImGui.SameLine() end
            ImGui.BeginGroup()
            local names = { "Top", "25%", "Center", "75%", "Bottom" }
            ImGui.TextUnformatted(names[i + 1])

            local child_flags = 0
            if s.enable_extra_decorations then child_flags = ImGuiWindowFlags.MenuBar end
            local child_id = ImGui.GetID(i)
            local child_is_visible = ImGui.BeginChild(child_id, ImVec2(child_w, 200.0), ImGuiChildFlags.Borders, child_flags)
            if ImGui.BeginMenuBar() then
                ImGui.TextUnformatted("abc")
                ImGui.EndMenuBar()
            end
            if scroll_to_off then
                ImGui.SetScrollY(s.scroll_to_off_px)
            end
            if scroll_to_pos then
                ImGui.SetScrollFromPosY(ImGui.GetCursorStartPos().y + s.scroll_to_pos_px, i * 0.25)
            end
            if child_is_visible then -- Avoid calling SetScrollHereY when running with culled items
                for item = 0, 99 do
                    if s.enable_track and item == s.track_item then
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
        HelpMarker(
            "Use SetScrollHereX() or SetScrollFromPosX() to scroll to a given horizontal position.\n\n" ..
            "Because the clipping rectangle of most window hides half worth of WindowPadding on the " ..
            "left/right, using SetScrollFromPosX(+1) will usually result in clipped text whereas the " ..
            "equivalent SetScrollFromPosY(+1) wouldn't.")
        ImGui.PushID("##HorizontalScrolling")
        for i = 0, 4 do
            local child_height = ImGui.GetTextLineHeight() + style.ScrollbarSize + style.WindowPadding.y * 2.0
            local child_flags = ImGuiWindowFlags.HorizontalScrollbar
            if s.enable_extra_decorations then child_flags = bit32.bor(child_flags, ImGuiWindowFlags.AlwaysVerticalScrollbar) end
            local child_id = ImGui.GetID(i)
            local child_is_visible = ImGui.BeginChild(child_id, ImVec2(-100, child_height), ImGuiChildFlags.Borders, child_flags)
            if scroll_to_off then
                ImGui.SetScrollX(s.scroll_to_off_px)
            end
            if scroll_to_pos then
                ImGui.SetScrollFromPosX(ImGui.GetCursorStartPos().x + s.scroll_to_pos_px, i * 0.25)
            end
            if child_is_visible then -- Avoid calling SetScrollHereY when running with culled items
                for item = 0, 99 do
                    if item > 0 then
                        ImGui.SameLine()
                    end
                    if s.enable_track and item == s.track_item then
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
            local names = { "Left", "25%", "Center", "75%", "Right" }
            ImGui.Text("%s\n%.0f/%.0f", names[i + 1], scroll_x, scroll_max_x)
            ImGui.Spacing()
        end
        ImGui.PopID()

        -- Miscellaneous Horizontal Scrolling Demo
        IMGUI_DEMO_MARKER("Layout/Scrolling/Horizontal (more)")
        HelpMarker(
            "Horizontal scrolling for a window is enabled via the ImGuiWindowFlags_HorizontalScrollbar flag.\n\n" ..
            "You may want to also explicitly specify content width by using SetNextWindowContentWidth() before Begin().")
        s.lines = ImGui.SliderInt("Lines", s.lines, 1, 15)
        ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 3.0)
        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(2.0, 1.0))
        local scrolling_child_size = ImVec2(0, ImGui.GetFrameHeightWithSpacing() * 7 + 30)
        ImGui.BeginChild("scrolling", scrolling_child_size, ImGuiChildFlags.Borders, ImGuiWindowFlags.HorizontalScrollbar)
        for line = 0, s.lines - 1 do
            -- Display random stuff. For the sake of this trivial demo we are using basic Button() + SameLine()
            -- If you want to create your own time line for a real application you may be better off manipulating
            -- the cursor position yourself, aka using SetCursorPos/SetCursorScreenPos to position the widgets
            -- yourself. You may also want to use the lower-level ImDrawList API.
            local num_buttons = 10 + ((line % 2 == 1) and line * 9 or line * 3)
            local base_w = ImGui.GetFontSize() * 3
            for n = 0, num_buttons - 1 do
                if n > 0 then ImGui.SameLine() end
                ImGui.PushID(n + line * 1000)
                local num_buf = string.format("%d", n)
                local label = num_buf
                if n % 15 == 0 then label = "FizzBuzz" elseif n % 3 == 0 then label = "Fizz" elseif n % 5 == 0 then label = "Buzz" end
                local hue = n * 0.05
                ImGui.PushStyleColor(ImGuiCol.Button, ImColor.HSV(hue, 0.6, 0.6).Value)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImColor.HSV(hue, 0.7, 0.7).Value)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, ImColor.HSV(hue, 0.8, 0.8).Value)
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
            -- (here we are already out of your child window)
            ImGui.BeginChild("scrolling")
            ImGui.SetScrollX(ImGui.GetScrollX() + scroll_x_delta)
            ImGui.EndChild()
        end
        ImGui.Spacing()

        _, s.show_horizontal_contents_size_demo_window = ImGui.Checkbox("Show Horizontal contents size demo window", s.show_horizontal_contents_size_demo_window)

        if s.show_horizontal_contents_size_demo_window then
            if s.explicit_content_size then
                ImGui.SetNextWindowContentSize(ImVec2(s.contents_size_x, 0.0))
            end
            local window_flags = 0
            if s.show_h_scrollbar then window_flags = ImGuiWindowFlags.HorizontalScrollbar end
            s.show_horizontal_contents_size_demo_window = ImGui.Begin("Horizontal contents size demo window", s.show_horizontal_contents_size_demo_window, window_flags)
            IMGUI_DEMO_MARKER("Layout/Scrolling/Horizontal contents size demo window")
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(2, 0))
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(2, 0))
            HelpMarker(
                "Test how different widgets react and impact the work rectangle growing when horizontal scrolling is enabled.\n\n" ..
                "Use 'Metrics->Tools->Show windows rectangles' to visualize rectangles.")
            _, s.show_h_scrollbar = ImGui.Checkbox("H-scrollbar", s.show_h_scrollbar)
            _, s.show_button = ImGui.Checkbox("Button", s.show_button)            -- Will grow contents size (unless explicitly overwritten)
            _, s.show_tree_nodes = ImGui.Checkbox("Tree nodes", s.show_tree_nodes)    -- Will grow contents size and display highlight over full width
            _, s.show_text_wrapped = ImGui.Checkbox("Text wrapped", s.show_text_wrapped)-- Will grow and use contents size
            _, s.show_columns = ImGui.Checkbox("Columns", s.show_columns)          -- Will use contents size
            _, s.show_tab_bar = ImGui.Checkbox("Tab bar", s.show_tab_bar)          -- Will use contents size
            _, s.show_child = ImGui.Checkbox("Child", s.show_child)              -- Will grow and use contents size
            _, s.explicit_content_size = ImGui.Checkbox("Explicit content size", s.explicit_content_size)
            ImGui.Text("Scroll %.1f/%.1f %.1f/%.1f", ImGui.GetScrollX(), ImGui.GetScrollMaxX(), ImGui.GetScrollY(), ImGui.GetScrollMaxY())
            if s.explicit_content_size then
                ImGui.SameLine()
                ImGui.SetNextItemWidth(ImGui.CalcTextSize("123456").x)
                s.contents_size_x = ImGui.DragFloat("##csx", s.contents_size_x)
                local p = ImGui.GetCursorScreenPos()
                ImGui.GetWindowDrawList():AddRectFilled(p, ImVec2(p.x + 10, p.y + 10), IM_COL32_WHITE)
                ImGui.GetWindowDrawList():AddRectFilled(ImVec2(p.x + s.contents_size_x - 10, p.y), ImVec2(p.x + s.contents_size_x, p.y + 10), IM_COL32_WHITE)
                ImGui.Dummy(ImVec2(0, 10))
            end
            ImGui.PopStyleVar(2)
            ImGui.Separator()
            if s.show_button then
                ImGui.Button("this is a 300-wide button", ImVec2(300, 0))
            end
            if s.show_tree_nodes then
                local open = true
                if ImGui.TreeNode("this is a tree node") then
                    if ImGui.TreeNode("another one of those tree node...") then
                        ImGui.Text("Some tree contents")
                        ImGui.TreePop()
                    end
                    ImGui.TreePop()
                end
                _, open = ImGui.CollapsingHeader("CollapsingHeader", open)
            end
            if s.show_text_wrapped then
                ImGui.TextWrapped("This text should automatically wrap on the edge of the work rectangle.")
            end
            if s.show_columns then
                ImGui.Text("Tables:")
                if ImGui.BeginTable("table", 4, ImGuiTableFlags.Borders) then
                    for n = 0, 3 do
                        ImGui.TableNextColumn()
                        ImGui.Text("Width %.2f", ImGui.GetContentRegionAvail().x)
                    end
                    ImGui.EndTable()
                end
                ImGui.Text("Columns:")
                ImGui.Columns(4)
                for n = 0, 3 do
                    ImGui.Text("Width %.2f", ImGui.GetColumnWidth())
                    ImGui.NextColumn()
                end
                ImGui.Columns(1)
            end
            if s.show_tab_bar and ImGui.BeginTabBar("Hello") then
                if ImGui.BeginTabItem("OneOneOne") then ImGui.EndTabItem() end
                if ImGui.BeginTabItem("TwoTwoTwo") then ImGui.EndTabItem() end
                if ImGui.BeginTabItem("ThreeThreeThree") then ImGui.EndTabItem() end
                if ImGui.BeginTabItem("FourFourFour") then ImGui.EndTabItem() end
                ImGui.EndTabBar()
            end
            if s.show_child then
                ImGui.BeginChild("child", ImVec2(0, 0), ImGuiChildFlags.Borders)
                ImGui.EndChild()
            end
            ImGui.End()
        end

        ImGui.TreePop()
    end

    if ImGui.TreeNode("Text Clipping") then
        IMGUI_DEMO_MARKER("Layout/Text Clipping")
        local size = s.size
        local offset = s.offset
        ImGui.DragFloat2("size", size, 0.5, 1.0, 200.0, "%.0f")
        ImGui.TextWrapped("(Click and drag to scroll)")

        HelpMarker(
            "(Left) Using ImGui::PushClipRect():\n" ..
            "Will alter ImGui hit-testing logic + ImDrawList rendering.\n" ..
            "(use this if you want your clipping rectangle to affect interactions)\n\n" ..
            "(Center) Using ImDrawList::PushClipRect():\n" ..
            "Will alter ImDrawList rendering only.\n" ..
            "(use this as a shortcut if you are only using ImDrawList calls)\n\n" ..
            "(Right) Using ImDrawList::AddText() with a fine ClipRect:\n" ..
            "Will alter only this specific ImDrawList::AddText() rendering.\n" ..
            "This is often used internally to avoid altering the clipping rectangle and minimize draw calls.")

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
                break -- continue
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
            elseif n == 2 then
                local clip_rect = ImVec4(p0.x, p0.y, p1.x, p1.y) -- AddText() takes a ImVec4* here so let's convert.
                draw_list:AddRectFilled(p0, p1, IM_COL32(90, 90, 120, 255))
                draw_list:AddText(ImGui.GetFont(), ImGui.GetFontSize(), text_pos, IM_COL32_WHITE, text_str, 1, #text_str + 1, 0.0, clip_rect) -- [Port] explicit text_begin/text_end (port's AddText needs text_end)
            end
        until true end

        ImGui.TreePop()
    end

    if ImGui.TreeNode("Overlap Mode") then
        IMGUI_DEMO_MARKER("Layout/Overlap Mode")

        HelpMarker(
            "Hit-testing is by default performed in item submission order, which generally is perceived as 'back-to-front'.\n\n" ..
            "By using SetNextItemAllowOverlap() you can notify that an item may be overlapped by another. " ..
            "Doing so alters the hovering logic: items using AllowOverlap mode requires an extra frame to accept hovered state.")
        _, s.enable_allow_overlap = ImGui.Checkbox("Enable AllowOverlap", s.enable_allow_overlap)

        local button1_pos = ImGui.GetCursorScreenPos()
        local button2_pos = ImVec2(button1_pos.x + 50.0, button1_pos.y + 50.0)
        if s.enable_allow_overlap then
            ImGui.SetNextItemAllowOverlap()
        end
        ImGui.Button("Button 1", ImVec2(80, 80))
        ImGui.SetCursorScreenPos(button2_pos)
        ImGui.Button("Button 2", ImVec2(80, 80))

        -- This is typically used with width-spanning items.
        -- (note that Selectable() has a dedicated flag ImGuiSelectableFlags.AllowOverlap, which is a shortcut
        -- for using SetNextItemAllowOverlap(). For demo purpose we use SetNextItemAllowOverlap() here.)
        if s.enable_allow_overlap then
            ImGui.SetNextItemAllowOverlap()
        end
        ImGui.Selectable("Some Selectable", false)
        ImGui.SameLine()
        ImGui.SmallButton("++")

        ImGui.TreePop()
    end
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowPopups()
-------------------------------------------------------------------------------

S.DemoWindowPopups = {
    selected_fish = -1,                                 -- static int selected_fish = -1;
    toggles = { true, false, false, false, false },     -- static bool toggles[] = { true, false, false, false, false };
    selected = -1,                                      -- static int selected = -1;
    value = 0.5,                                        -- static float value = 0.5f;
    name = ImGui.NewTextBuffer("Label1", 32),           -- static char name[32] = "Label1";
    dont_ask_me_next_time = false,                      -- static bool dont_ask_me_next_time = false;
    item = 1,                                           -- static int item = 1;
    color = { 0.4, 0.7, 0.0, 0.5 },                     -- static float color[4] = { 0.4f, 0.7f, 0.0f, 0.5f };
}
function DemoWindowPopups()
    local s = S.DemoWindowPopups
    if not ImGui.CollapsingHeader("Popups & Modal windows") then
        return
    end

    -- The properties of popups windows are:
    -- - They block normal mouse hovering detection outside them. (*)
    -- - Unless modal, they can be closed by clicking anywhere outside them, or by pressing ESCAPE.
    -- - Their visibility state (~bool) is held internally by Dear ImGui instead of being held by the programmer as
    --   we are used to with regular Begin() calls. User can manipulate the visibility state by calling OpenPopup().
    -- (*) One can use IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup) to bypass it and detect hovering even
    --     when normally blocked by a popup.
    -- Those three properties are connected. The library needs to hold their visibility state BECAUSE it can close
    -- popups at any time.

    -- Typical use for regular windows:
    --   bool my_tool_is_active = false; if (ImGui.Button("Open")) my_tool_is_active = true; [...] if (my_tool_is_active) Begin("My Tool", my_tool_is_active) { [...] } End();
    -- Typical use for popups:
    --   if (ImGui.Button("Open")) ImGui.OpenPopup("MyPopup"); if (ImGui.BeginPopup("MyPopup")) { [...] EndPopup(); }

    -- With popups we have to go through a library call (here OpenPopup) to manipulate the visibility state.
    -- This may be a bit confusing at first but it should quickly make sense. Follow on the examples below.

    if ImGui.TreeNode("Popups") then
        IMGUI_DEMO_MARKER("Popups/Popups")
        ImGui.TextWrapped(
            "When a popup is active, it inhibits interacting with windows that are behind the popup. " ..
            "Clicking outside the popup closes it.")

        local names = { "Bream", "Haddock", "Mackerel", "Pollock", "Tilefish" }
        local toggles = s.toggles

        -- Simple selection popup (if you want to show the current selection inside the Button itself,
        -- you may want to build a string using the "###" operator to preserve a constant ID with a variable label)
        if ImGui.Button("Select..") then
            ImGui.OpenPopup("my_select_popup")
        end
        ImGui.SameLine()
        local fish_name = "<None>"
        if s.selected_fish ~= -1 then fish_name = names[s.selected_fish + 1] end
        ImGui.TextUnformatted(fish_name)
        if ImGui.BeginPopup("my_select_popup") then
            ImGui.SeparatorText("Aquarium")
            for i = 0, #names - 1 do
                if ImGui.Selectable(names[i + 1]) then
                    s.selected_fish = i
                end
            end
            ImGui.EndPopup()
        end

        -- Showing a menu with toggles
        if ImGui.Button("Toggle..") then
            ImGui.OpenPopup("my_toggle_popup")
        end
        if ImGui.BeginPopup("my_toggle_popup") then
            for i = 0, #names - 1 do
                _, toggles[i + 1] = ImGui.MenuItem(names[i + 1], "", toggles[i + 1])
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
                for i = 0, #names - 1 do
                    _, toggles[i + 1] = ImGui.MenuItem(names[i + 1], "", toggles[i + 1])
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
                    ShowExampleMenuFile()
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

        ImGui.TreePop()
    end

    if ImGui.TreeNode("Context menus") then
        IMGUI_DEMO_MARKER("Popups/Context menus")
        HelpMarker("\"Context\" functions are simple helpers to associate a Popup to a given Item or Window identifier.")

        -- BeginPopupContextItem() is a helper to provide common/simple popup behavior of essentially doing:
        --     if (id == 0)
        --         id = GetItemID(); -- Use last item id
        --     if (IsItemHovered() && IsMouseReleased(ImGuiMouseButton.Right))
        --         OpenPopup(id);
        --     return BeginPopup(id);
        -- For advanced uses you may want to replicate and customize this code.
        -- See more details in BeginPopupContextItem().

        -- Example 1
        -- When used after an item that has an ID (e.g. Button), we can skip providing an ID to BeginPopupContextItem(),
        -- and BeginPopupContextItem() will use the last item ID as the popup ID.
        do
            local names = { "Label1", "Label2", "Label3", "Label4", "Label5" }
            for n = 0, 4 do
                if ImGui.Selectable(names[n + 1], s.selected == n) then
                    s.selected = n
                end
                if ImGui.BeginPopupContextItem() then -- <-- use last item id as popup id
                    s.selected = n
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
        -- Popup on a Text() element which doesn't have an identifier: we need to provide an identifier to BeginPopupContextItem().
        -- Using an explicit identifier is also convenient if you want to activate the popups from different locations.
        do
            HelpMarker("Text() elements don't have stable identifiers so we need to provide one.")
            ImGui.Text("Value = %.3f <-- (1) right-click this text", s.value)
            if ImGui.BeginPopupContextItem("my popup") then
                if ImGui.Selectable("Set to zero") then s.value = 0.0 end
                if ImGui.Selectable("Set to PI") then s.value = 3.1415 end
                ImGui.SetNextItemWidth(-FLT_MIN)
                s.value = ImGui.DragFloat("##Value", s.value, 0.1, 0.0, 0.0)
                ImGui.EndPopup()
            end

            -- We can also use OpenPopupOnItemClick() to toggle the visibility of a given popup.
            -- Here we make it that right-clicking this other text element opens the same popup as above.
            -- The popup itself will be submitted by the code above.
            ImGui.Text("(2) Or right-click this text")
            ImGui.OpenPopupOnItemClick("my popup", ImGuiPopupFlags.MouseButtonRight)

            -- Back to square one: manually open the same popup.
            if ImGui.Button("(3) Or click this button") then
                ImGui.OpenPopup("my popup")
            end
        end

        -- Example 3
        -- When using BeginPopupContextItem() with an implicit identifier (nil == use last item ID),
        -- we need to make sure your item identifier is stable.
        -- In this example we showcase altering the item label while preserving its identifier, using the ### operator (see FAQ).
        do
            HelpMarker("Showcase using a popup ID linked to item ID, with the item having a changing label + stable ID using the ### operator.")
            local buf = string.format("Button: %s###Button", ImGui.TextBufferToString(s.name)) -- ### operator override ID ignoring the preceding label
            ImGui.Button(buf)
            if ImGui.BeginPopupContextItem() then
                ImGui.Text("Edit name:")
                ImGui.InputText("##edit", s.name, 32)
                if ImGui.Button("Close") then
                    ImGui.CloseCurrentPopup()
                end
                ImGui.EndPopup()
            end
            ImGui.SameLine(); ImGui.Text("(<-- right-click here)")
        end

        ImGui.TreePop()
    end

    if ImGui.TreeNode("Modals") then
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

            --static int unused_i = 0;
            --ImGui.Combo("Combo", unused_i, "Delete\0Delete harder\0");

            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(0, 0))
            _, s.dont_ask_me_next_time = ImGui.Checkbox("Don't ask me next time", s.dont_ask_me_next_time)
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
            s.item = ImGui.Combo("Combo", s.item, "aaaa\0bbbb\0cccc\0dddd\0eeee\0\0")
            ImGui.ColorEdit4("Color", s.color)

            if ImGui.Button("Add another modal..") then
                ImGui.OpenPopup("Stacked 2")
            end

            -- Also demonstrate passing a bool* to BeginPopupModal(), this will create a regular close button which
            -- will close the popup. Note that the visibility state of popups is owned by imgui, so the input value
            -- of the bool actually doesn't matter here.
            local unused_open = true
            local visible
            visible, unused_open = ImGui.BeginPopupModal("Stacked 2", unused_open)
            if visible then
                ImGui.Text("Hello from Stacked The Second!")
                ImGui.ColorEdit4("Color", s.color) -- Allow opening another nested popup
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

        ImGui.TreePop()
    end

    if ImGui.TreeNode("Menus inside a regular window") then
        IMGUI_DEMO_MARKER("Popups/Menus inside a regular window")
        ImGui.TextWrapped("Below we are testing adding menu items to a regular window. It's rather unusual but should work!")
        ImGui.Separator()

        ImGui.MenuItem("Menu item", "Ctrl+M")
        if ImGui.BeginMenu("Menu inside a regular window") then
            ShowExampleMenuFile()
            ImGui.EndMenu()
        end
        ImGui.Separator()
        ImGui.TreePop()
    end
end

-- Dummy data structure that we use for the Table demo.
-- (pre-C++11 doesn't allow us to instantiate ImVector<MyItem> template if this structure is defined inside the demo function)
-- [Port] namespace { ... } -> globals with a MyItem prefix (part 08_tables uses them).
-- We are passing our own identifier to TableSetupColumn() to facilitate identifying columns in the sorting code.
-- This identifier will be passed down into ImGuiTableSortSpec::ColumnUserID.
-- But it is possible to omit the user id parameter of TableSetupColumn() and just use the column index instead! (ImGuiTableSortSpec::ColumnIndex)
-- If you don't use sorting, you will generally never care about giving column an ID!
-- enum MyItemColumnID
MyItemColumnID_ID = 0
MyItemColumnID_Name = 1
MyItemColumnID_Action = 2
MyItemColumnID_Quantity = 3
MyItemColumnID_Description = 4

-- struct MyItem: [Port] constructor; fields ID (int), Name (string), Quantity (int)
function MyItem(ID, Name, Quantity)
    return { ID = ID, Name = Name, Quantity = Quantity }
end

-- We have a problem which is affecting _only this demo_ and should not affect your code:
-- As we don't rely on std:: or other third-party library to compile dear imgui, we only have reliable access to qsort(),
-- however qsort doesn't allow passing user data to comparing function.
-- As a workaround, we are storing the sort specs in a static/global for the comparing function to access.
-- In your own use case you would probably pass the sort specs to your sorting/comparing functions directly and not use a global.
-- We could technically call ImGui.TableGetSortSpecs() in CompareWithSortSpecs(), but considering that this function is called
-- very often by the sorting algorithm it would be a little wasteful.
MyItem_s_current_sort_specs = nil

-- [Port] items: 1-based Lua array of MyItem (e.g. ImVector .Data), sorted in place over [1, items_count].
local function MyItem_Less(a, b) return MyItem_CompareWithSortSpecs(a, b) < 0 end -- [Port] table.sort wants a "less than" predicate
function MyItem_SortWithSortSpecs(sort_specs, items, items_count)
    MyItem_s_current_sort_specs = sort_specs -- Store in variable accessible by the sort function.
    if items_count > 1 then
        if items_count == #items then
            table.sort(items, MyItem_Less)
        else -- [Port] sort only the used range
            local tmp = {}
            for i = 1, items_count do tmp[i] = items[i] end
            table.sort(tmp, MyItem_Less)
            for i = 1, items_count do items[i] = tmp[i] end
        end
    end
    MyItem_s_current_sort_specs = nil
end

-- Compare function to be used by qsort()
-- [Port] strcmp -> Lua string comparison; returns <0, 0, >0 like upstream (strict weak order via the ID fallback).
function MyItem_CompareWithSortSpecs(a, b)
    for n = 0, MyItem_s_current_sort_specs.SpecsCount - 1 do
        -- Here we identify columns using the ColumnUserID value that we ourselves passed to TableSetupColumn()
        -- We could also choose to identify columns based on their index (sort_spec.ColumnIndex), which is simpler!
        local sort_spec = MyItem_s_current_sort_specs.Specs[n + 1] -- [Port] Specs is a 1-based array
        local delta = 0
        local id = sort_spec.ColumnUserID
        if id == MyItemColumnID_ID then             delta = (a.ID - b.ID)
        elseif id == MyItemColumnID_Name then       delta = (a.Name < b.Name and -1 or (a.Name > b.Name and 1 or 0))
        elseif id == MyItemColumnID_Quantity then   delta = (a.Quantity - b.Quantity)
        elseif id == MyItemColumnID_Description then delta = (a.Name < b.Name and -1 or (a.Name > b.Name and 1 or 0))
        else IM_ASSERT(false) end
        if delta > 0 then
            return (sort_spec.SortDirection == ImGuiSortDirection.Ascending) and 1 or -1
        end
        if delta < 0 then
            return (sort_spec.SortDirection == ImGuiSortDirection.Ascending) and -1 or 1
        end
    end

    -- qsort() is instable so always return a way to differentiate items.
    -- Your own compare function may want to avoid fallback on implicit sort specs.
    -- e.g. a Name compare if it wasn't already part of the sort specs.
    return a.ID - b.ID
end

-- Make the UI compact because there are so many fields
function PushStyleCompact()
    local style = ImGui.GetStyle()
    ImGui.PushStyleVarY(ImGuiStyleVar.FramePadding, math.floor(style.FramePadding.y * 0.60))
    ImGui.PushStyleVarY(ImGuiStyleVar.ItemSpacing, math.floor(style.ItemSpacing.y * 0.60))
end

function PopStyleCompact()
    ImGui.PopStyleVar(2)
end

S.EditTableSizingFlags = { policies = nil }
-- Show a combo box with a choice of sizing policies
-- [Port] p_flags -> takes flags, returns the new flags.
function EditTableSizingFlags(p_flags)
    local s = S.EditTableSizingFlags
    -- struct EnumDesc { ImGuiTableFlags Value; const char* Name; const char* Tooltip; };
    if s.policies == nil then
        s.policies =
        {
            { Value = ImGuiTableFlags.None,               Name = "Default",                            Tooltip = "Use default sizing policy:\n- ImGuiTableFlags_SizingFixedFit if ScrollX is on or if host window has ImGuiWindowFlags_AlwaysAutoResize.\n- ImGuiTableFlags_SizingStretchSame otherwise." },
            { Value = ImGuiTableFlags.SizingFixedFit,     Name = "ImGuiTableFlags_SizingFixedFit",     Tooltip = "Columns default to _WidthFixed (if resizable) or _WidthAuto (if not resizable), matching contents width." },
            { Value = ImGuiTableFlags.SizingFixedSame,    Name = "ImGuiTableFlags_SizingFixedSame",    Tooltip = "Columns are all the same width, matching the maximum contents width.\nImplicitly disable ImGuiTableFlags_Resizable and enable ImGuiTableFlags_NoKeepColumnsVisible." },
            { Value = ImGuiTableFlags.SizingStretchProp,  Name = "ImGuiTableFlags_SizingStretchProp",  Tooltip = "Columns default to _WidthStretch with weights proportional to their widths." },
            { Value = ImGuiTableFlags.SizingStretchSame,  Name = "ImGuiTableFlags_SizingStretchSame",  Tooltip = "Columns default to _WidthStretch with same weights." },
        }
    end
    local policies = s.policies
    local idx = 0
    while idx < #policies do
        if policies[idx + 1].Value == bit32.band(p_flags, ImGuiTableFlags.SizingMask_) then
            break
        end
        idx = idx + 1
    end
    local preview_text = ""
    if idx < #policies then
        preview_text = policies[idx + 1].Name
        if idx > 0 then preview_text = string.sub(preview_text, #"ImGuiTableFlags" + 1) end
    end
    if ImGui.BeginCombo("Sizing Policy", preview_text) then
        for n = 0, #policies - 1 do
            if ImGui.Selectable(policies[n + 1].Name, idx == n) then
                p_flags = bit32.bor(bit32.band(p_flags, bit32.bnot(ImGuiTableFlags.SizingMask_)), policies[n + 1].Value)
            end
        end
        ImGui.EndCombo()
    end
    ImGui.SameLine()
    ImGui.TextDisabled("(?)")
    if ImGui.BeginItemTooltip() then
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 50.0)
        for m = 0, #policies - 1 do
            ImGui.Separator()
            ImGui.Text("%s:", policies[m + 1].Name)
            ImGui.Separator()
            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ImGui.GetStyle().IndentSpacing * 0.5)
            ImGui.TextUnformatted(policies[m + 1].Tooltip)
        end
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
    return p_flags
end

-- [Port] p_flags -> takes flags, returns the new flags.
function EditTableColumnsFlags(p_flags)
    local pressed
    _, p_flags = ImGui.CheckboxFlags("_Disabled", p_flags, ImGuiTableColumnFlags.Disabled); ImGui.SameLine(); HelpMarker("Master disable flag (also hide from context menu)")
    _, p_flags = ImGui.CheckboxFlags("_DefaultHide", p_flags, ImGuiTableColumnFlags.DefaultHide)
    _, p_flags = ImGui.CheckboxFlags("_DefaultSort", p_flags, ImGuiTableColumnFlags.DefaultSort)
    pressed, p_flags = ImGui.CheckboxFlags("_WidthStretch", p_flags, ImGuiTableColumnFlags.WidthStretch)
    if pressed then
        p_flags = bit32.band(p_flags, bit32.bnot(bit32.bxor(ImGuiTableColumnFlags.WidthMask_, ImGuiTableColumnFlags.WidthStretch)))
    end
    pressed, p_flags = ImGui.CheckboxFlags("_WidthFixed", p_flags, ImGuiTableColumnFlags.WidthFixed)
    if pressed then
        p_flags = bit32.band(p_flags, bit32.bnot(bit32.bxor(ImGuiTableColumnFlags.WidthMask_, ImGuiTableColumnFlags.WidthFixed)))
    end
    _, p_flags = ImGui.CheckboxFlags("_NoResize", p_flags, ImGuiTableColumnFlags.NoResize)
    _, p_flags = ImGui.CheckboxFlags("_NoReorder", p_flags, ImGuiTableColumnFlags.NoReorder)
    _, p_flags = ImGui.CheckboxFlags("_NoHide", p_flags, ImGuiTableColumnFlags.NoHide)
    _, p_flags = ImGui.CheckboxFlags("_NoClip", p_flags, ImGuiTableColumnFlags.NoClip)
    _, p_flags = ImGui.CheckboxFlags("_NoSort", p_flags, ImGuiTableColumnFlags.NoSort)
    _, p_flags = ImGui.CheckboxFlags("_NoSortAscending", p_flags, ImGuiTableColumnFlags.NoSortAscending)
    _, p_flags = ImGui.CheckboxFlags("_NoSortDescending", p_flags, ImGuiTableColumnFlags.NoSortDescending)
    _, p_flags = ImGui.CheckboxFlags("_NoHeaderLabel", p_flags, ImGuiTableColumnFlags.NoHeaderLabel)
    _, p_flags = ImGui.CheckboxFlags("_NoHeaderWidth", p_flags, ImGuiTableColumnFlags.NoHeaderWidth)
    _, p_flags = ImGui.CheckboxFlags("_PreferSortAscending", p_flags, ImGuiTableColumnFlags.PreferSortAscending)
    _, p_flags = ImGui.CheckboxFlags("_PreferSortDescending", p_flags, ImGuiTableColumnFlags.PreferSortDescending)
    _, p_flags = ImGui.CheckboxFlags("_IndentEnable", p_flags, ImGuiTableColumnFlags.IndentEnable); ImGui.SameLine(); HelpMarker("Default for column 0")
    _, p_flags = ImGui.CheckboxFlags("_IndentDisable", p_flags, ImGuiTableColumnFlags.IndentDisable); ImGui.SameLine(); HelpMarker("Default for column >0")
    _, p_flags = ImGui.CheckboxFlags("_AngledHeader", p_flags, ImGuiTableColumnFlags.AngledHeader)
    return p_flags
end

function ShowTableColumnsStatusFlags(flags)
    ImGui.CheckboxFlags("_IsEnabled", flags, ImGuiTableColumnFlags.IsEnabled)
    ImGui.CheckboxFlags("_IsVisible", flags, ImGuiTableColumnFlags.IsVisible)
    ImGui.CheckboxFlags("_IsSorted", flags, ImGuiTableColumnFlags.IsSorted)
    ImGui.CheckboxFlags("_IsHovered", flags, ImGuiTableColumnFlags.IsHovered)
end

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowTables()
-------------------------------------------------------------------------------

S.DemoWindowTables = {                  -- statics of DemoWindowTables(), one sub-table per TreeNode
    disable_indent = false,
    BordersBackground = {
        flags = bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg),
        display_headers = false,
        contents_type = 0,              -- CT_Text
    },
    ResizableStretch = {
        flags = bit32.bor(ImGuiTableFlags.SizingStretchSame, ImGuiTableFlags.Resizable, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.ContextMenuInBody),
    },
    ResizableFixed = {
        flags = bit32.bor(ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.Resizable, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.ContextMenuInBody),
    },
    ResizableMixed = {
        flags = bit32.bor(ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.RowBg, ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable),
    },
    Reorderable = {
        flags = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV),
    },
    Padding = {
        flags1 = ImGuiTableFlags.BordersV,
        show_headers = false,
        flags2 = bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg),
        cell_padding = ImVec2(0.0, 0.0),
        show_widget_frame_bg = true,
        text_bufs = {},                 -- 1-based, cell + 1
        init = true,
    },
    SizingPolicies = {
        flags1 = bit32.bor(ImGuiTableFlags.BordersV, ImGuiTableFlags.BordersOuterH, ImGuiTableFlags.RowBg, ImGuiTableFlags.ContextMenuInBody),
        sizing_policy_flags = { ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.SizingFixedSame, ImGuiTableFlags.SizingStretchProp, ImGuiTableFlags.SizingStretchSame },
        flags = bit32.bor(ImGuiTableFlags.ScrollY, ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg, ImGuiTableFlags.Resizable),
        contents_type = 0,              -- CT_ShowWidth
        column_count = 3,
        text_buf = ImGui.NewTextBuffer("", 32),
    },
    VerticalScrolling = {
        flags = bit32.bor(ImGuiTableFlags.ScrollY, ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable),
    },
    HorizontalScrolling = {
        flags = bit32.bor(ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY, ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable),
        freeze_cols = 1,
        freeze_rows = 1,
        flags2 = bit32.bor(ImGuiTableFlags.SizingStretchSame, ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.RowBg, ImGuiTableFlags.ContextMenuInBody),
        inner_width = 1000.0,
    },
    ColumnsFlags = {
        column_flags = { ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.None, ImGuiTableColumnFlags.DefaultHide },
        column_flags_out = { 0, 0, 0 }, -- Output from TableGetColumnFlags()
    },
    ColumnsWidths = {
        flags1 = bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.NoBordersInBodyUntilResize),
        flags2 = ImGuiTableFlags.None,
    },
    OuterSize = {
        flags = bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.ContextMenuInBody, ImGuiTableFlags.RowBg, ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.NoHostExtendX),
    },
    BackgroundColor = {
        flags = ImGuiTableFlags.RowBg,
        row_bg_type = 1,
        row_bg_target = 1,
        cell_bg_type = 1,
    },
    TreeView = {
        table_flags = bit32.bor(ImGuiTableFlags.BordersV, ImGuiTableFlags.BordersOuterH, ImGuiTableFlags.Resizable, ImGuiTableFlags.RowBg, ImGuiTableFlags.NoBordersInBody),
        tree_node_flags_base = bit32.bor(ImGuiTreeNodeFlags.SpanAllColumns, ImGuiTreeNodeFlags.DefaultOpen, ImGuiTreeNodeFlags.DrawLinesFull),
        MyTreeNode = nil,               -- [Port] local struct, created once on first use
        nodes = {                       -- 1-based; ChildIdx stays 0-based like upstream
            { Name = "Root with Long Name",           Type = "Folder",      Size = -1,     ChildIdx = 1,  ChildCount = 3  }, -- 0
            { Name = "Music",                         Type = "Folder",      Size = -1,     ChildIdx = 4,  ChildCount = 2  }, -- 1
            { Name = "Textures",                      Type = "Folder",      Size = -1,     ChildIdx = 6,  ChildCount = 3  }, -- 2
            { Name = "desktop.ini",                   Type = "System file", Size = 1024,   ChildIdx = -1, ChildCount = -1 }, -- 3
            { Name = "File1_a.wav",                   Type = "Audio file",  Size = 123000, ChildIdx = -1, ChildCount = -1 }, -- 4
            { Name = "File1_b.wav",                   Type = "Audio file",  Size = 456000, ChildIdx = -1, ChildCount = -1 }, -- 5
            { Name = "Image001.png",                  Type = "Image file",  Size = 203128, ChildIdx = -1, ChildCount = -1 }, -- 6
            { Name = "Copy of Image001.png",          Type = "Image file",  Size = 203256, ChildIdx = -1, ChildCount = -1 }, -- 7
            { Name = "Copy of Image001 (Final2).png", Type = "Image file",  Size = 203512, ChildIdx = -1, ChildCount = -1 }, -- 8
        },
    },
    ItemWidth = {
        dummy_f = 0.0,
    },
    CustomHeaders = {
        column_selected = { false, false, false },
    },
    AngledHeaders = {
        table_flags = bit32.bor(ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersInnerH, ImGuiTableFlags.Hideable, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.HighlightHoveredColumn),
        column_flags = bit32.bor(ImGuiTableColumnFlags.AngledHeader, ImGuiTableColumnFlags.WidthFixed),
        bools = {},                     -- 1-based, filled with false on first use
        frozen_cols = 1,
        frozen_rows = 2,
    },
    ContextMenus = {
        flags1 = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Borders, ImGuiTableFlags.ContextMenuInBody),
    },
    SyncedInstances = {
        flags = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Borders, ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.NoSavedSettings),
    },
    template_items_names = {
        "Banana", "Apple", "Cherry", "Watermelon", "Grapefruit", "Strawberry", "Mango",
        "Kiwi", "Orange", "Pineapple", "Blueberry", "Plum", "Coconut", "Pear", "Apricot"
    },
    Sorting = {
        items = ImVector(),
        flags = bit32.bor(
            ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Sortable, ImGuiTableFlags.SortMulti,
            ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV, ImGuiTableFlags.NoBordersInBody,
            ImGuiTableFlags.ScrollY),
    },
    Advanced = {
        flags = bit32.bor(
            ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable,
            ImGuiTableFlags.Sortable, ImGuiTableFlags.SortMulti,
            ImGuiTableFlags.RowBg, ImGuiTableFlags.Borders, ImGuiTableFlags.NoBordersInBody,
            ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY,
            ImGuiTableFlags.SizingFixedFit),
        columns_base_flags = ImGuiTableColumnFlags.None,
        contents_type = 5,              -- CT_SelectableSpanRow
        freeze_cols = 1,
        freeze_rows = 1,
        items_count = 0,                -- IM_COUNTOF(template_items_names) * 2, set below
        outer_size_value = nil,         -- ImVec2(0.0f, TEXT_BASE_HEIGHT * 12), set lazily (needs font)
        row_min_height = 0.0,           -- Auto
        inner_width_with_scroll = 0.0,  -- Auto-extend
        outer_size_enabled = true,
        show_headers = true,
        show_wrapped_text = false,
        items = ImVector(),
        selection = ImVector(),
        items_need_sort = false,
        show_debug_details = false,
    },
}
S.DemoWindowTables.Advanced.items_count = #S.DemoWindowTables.template_items_names * 2

function DemoWindowTables()
    local _
    local s = S.DemoWindowTables
    --ImGui.SetNextItemOpen(true, ImGuiCond.Once)
    if not ImGui.CollapsingHeader("Tables & Columns") then
        return
    end

    -- Using those as a base value to create width/height that are factor of the size of our font
    local TEXT_BASE_WIDTH = ImGui.CalcTextSize("A").x
    local TEXT_BASE_HEIGHT = ImGui.GetTextLineHeightWithSpacing()

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
    _, s.disable_indent = ImGui.Checkbox("Disable tree indentation", s.disable_indent)
    ImGui.SameLine()
    HelpMarker("Disable the indenting of tree nodes so demo tables can use the full window width.")
    ImGui.Separator()
    if s.disable_indent then
        ImGui.PushStyleVar(ImGuiStyleVar.IndentSpacing, 0.0)
    end

    -- About Styling of tables
    -- Most settings are configured on a per-table basis via the flags passed to BeginTable() and TableSetupColumns APIs.
    -- There are however a few settings that a shared and part of the ImGuiStyle structure:
    --   style.CellPadding                          -- Padding within each cell
    --   style.Colors[ImGuiCol.TableHeaderBg]       -- Table header background
    --   style.Colors[ImGuiCol.TableBorderStrong]   -- Table outer and header borders
    --   style.Colors[ImGuiCol.TableBorderLight]    -- Table inner borders
    --   style.Colors[ImGuiCol.TableRowBg]          -- Table row background when ImGuiTableFlags_RowBg is enabled (even rows)
    --   style.Colors[ImGuiCol.TableRowBgAlt]       -- Table row background when ImGuiTableFlags_RowBg is enabled (odds rows)

    -- Demos
    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Basic") then
        IMGUI_DEMO_MARKER("Tables/Basic")
        -- Here we will showcase three different ways to output a table.
        -- They are very simple variations of a same thing!

        -- [Method 1] Using TableNextRow() to create a new row, and TableSetColumnIndex() to select the column.
        -- In many situations, this is the most flexible and easy to use pattern.
        HelpMarker("Using TableNextRow() + calling TableSetColumnIndex() _before_ each cell, in a loop.")
        if ImGui.BeginTable("table1", 3) then
            for row = 0, 4 - 1 do
                ImGui.TableNextRow()
                for column = 0, 3 - 1 do
                    ImGui.TableSetColumnIndex(column)
                    ImGui.Text("Row %d Column %d", row, column)
                end
            end
            ImGui.EndTable()
        end

        -- [Method 2] Using TableNextColumn() called multiple times, instead of using a for loop + TableSetColumnIndex().
        -- This is generally more convenient when you have code manually submitting the contents of each column.
        HelpMarker("Using TableNextRow() + calling TableNextColumn() _before_ each cell, manually.")
        if ImGui.BeginTable("table2", 3) then
            for row = 0, 4 - 1 do
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
        -- as TableNextColumn() will automatically wrap around and create new rows as needed.
        -- This is generally more convenient when your cells all contains the same type of data.
        HelpMarker(
            "Only using TableNextColumn(), which tends to be convenient for tables where every cell contains " ..
            "the same type of contents.\n This is also more similar to the old NextColumn() function of the " ..
            "Columns API, and provided to facilitate the Columns->Tables API transition.")
        if ImGui.BeginTable("table3", 3) then
            for item = 0, 14 - 1 do
                ImGui.TableNextColumn()
                ImGui.Text("Item %d", item)
            end
            ImGui.EndTable()
        end

        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Borders, background") then
        IMGUI_DEMO_MARKER("Tables/Borders, background")
        -- Expose a few Borders related flags interactively
        local CT_Text, CT_FillButton = 0, 1 -- enum ContentsType
        local s = s.BordersBackground

        PushStyleCompact()
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_RowBg", s.flags, ImGuiTableFlags.RowBg)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Borders", s.flags, ImGuiTableFlags.Borders)
        ImGui.SameLine(); HelpMarker("ImGuiTableFlags_Borders\n = ImGuiTableFlags_BordersInnerV\n | ImGuiTableFlags_BordersOuterV\n | ImGuiTableFlags_BordersInnerH\n | ImGuiTableFlags_BordersOuterH")
        ImGui.Indent()

        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersH", s.flags, ImGuiTableFlags.BordersH)
        ImGui.Indent()
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterH", s.flags, ImGuiTableFlags.BordersOuterH)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerH", s.flags, ImGuiTableFlags.BordersInnerH)
        ImGui.Unindent()

        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersV", s.flags, ImGuiTableFlags.BordersV)
        ImGui.Indent()
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterV", s.flags, ImGuiTableFlags.BordersOuterV)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerV", s.flags, ImGuiTableFlags.BordersInnerV)
        ImGui.Unindent()

        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuter", s.flags, ImGuiTableFlags.BordersOuter)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInner", s.flags, ImGuiTableFlags.BordersInner)
        ImGui.Unindent()

        ImGui.AlignTextToFramePadding(); ImGui.Text("Cell contents:")
        ImGui.SameLine(); _, s.contents_type = ImGui.RadioButton("Text", s.contents_type, CT_Text)
        ImGui.SameLine(); _, s.contents_type = ImGui.RadioButton("FillButton", s.contents_type, CT_FillButton)
        _, s.display_headers = ImGui.Checkbox("Display headers", s.display_headers)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBody", s.flags, ImGuiTableFlags.NoBordersInBody); ImGui.SameLine(); HelpMarker("Disable vertical borders in columns Body (borders will always appear in Headers)")
        PopStyleCompact()

        if ImGui.BeginTable("table1", 3, s.flags) then
            -- Display headers so we can inspect their interaction with borders
            -- (Headers are not the main purpose of this section of the demo, so we are not elaborating on them now. See other sections for details)
            if s.display_headers then
                ImGui.TableSetupColumn("One")
                ImGui.TableSetupColumn("Two")
                ImGui.TableSetupColumn("Three")
                ImGui.TableHeadersRow()
            end

            for row = 0, 5 - 1 do
                ImGui.TableNextRow()
                for column = 0, 3 - 1 do
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
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Resizable, stretch") then
        IMGUI_DEMO_MARKER("Tables/Resizable, stretch")
        -- By default, if we don't enable ScrollX the sizing policy for each column is "Stretch"
        -- All columns maintain a sizing weight, and they will occupy all available width.
        local s = s.ResizableStretch
        PushStyleCompact()
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags, ImGuiTableFlags.Resizable)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersV", s.flags, ImGuiTableFlags.BordersV)
        ImGui.SameLine(); HelpMarker(
            "Using the _Resizable flag automatically enables the _BordersInnerV flag as well, " ..
            "this is why the resize borders are still showing when unchecking this.")
        PopStyleCompact()

        if ImGui.BeginTable("table1", 3, s.flags) then
            for row = 0, 5 - 1 do
                ImGui.TableNextRow()
                for column = 0, 3 - 1 do
                    ImGui.TableSetColumnIndex(column)
                    ImGui.Text("Hello %d,%d", column, row)
                end
            end
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Resizable, fixed") then
        IMGUI_DEMO_MARKER("Tables/Resizable, fixed")
        -- Here we use ImGuiTableFlags_SizingFixedFit (even though _ScrollX is not set)
        -- So columns will adopt the "Fixed" policy and will maintain a fixed width regardless of the whole available width (unless table is small)
        -- If there is not enough available width to fit all columns, they will however be resized down.
        -- FIXME-TABLE: Providing a stretch-on-init would make sense especially for tables which don't have saved settings
        HelpMarker(
            "Using _Resizable + _SizingFixedFit flags.\n" ..
            "Fixed-width columns generally makes more sense if you want to use horizontal scrolling.\n\n" ..
            "Double-click a column border to auto-fit the column to its contents.")
        PushStyleCompact()
        local s = s.ResizableFixed
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendX", s.flags, ImGuiTableFlags.NoHostExtendX)
        PopStyleCompact()

        if ImGui.BeginTable("table1", 3, s.flags) then
            for row = 0, 5 - 1 do
                ImGui.TableNextRow()
                for column = 0, 3 - 1 do
                    ImGui.TableSetColumnIndex(column)
                    ImGui.Text("Hello %d,%d", column, row)
                end
            end
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Resizable, mixed") then
        IMGUI_DEMO_MARKER("Tables/Resizable, mixed")
        HelpMarker(
            "Using TableSetupColumn() to alter resizing policy on a per-column basis.\n\n" ..
            "When combining Fixed and Stretch columns, generally you only want one, maybe two trailing columns to use _WidthStretch.")
        local s = s.ResizableMixed

        if ImGui.BeginTable("table1", 3, s.flags) then
            ImGui.TableSetupColumn("AAA", ImGuiTableColumnFlags.WidthFixed)
            ImGui.TableSetupColumn("BBB", ImGuiTableColumnFlags.WidthFixed)
            ImGui.TableSetupColumn("CCC", ImGuiTableColumnFlags.WidthStretch)
            ImGui.TableHeadersRow()
            for row = 0, 5 - 1 do
                ImGui.TableNextRow()
                for column = 0, 3 - 1 do
                    ImGui.TableSetColumnIndex(column)
                    ImGui.Text("%s %d,%d", (column == 2) and "Stretch" or "Fixed", column, row)
                end
            end
            ImGui.EndTable()
        end
        if ImGui.BeginTable("table2", 6, s.flags) then
            ImGui.TableSetupColumn("AAA", ImGuiTableColumnFlags.WidthFixed)
            ImGui.TableSetupColumn("BBB", ImGuiTableColumnFlags.WidthFixed)
            ImGui.TableSetupColumn("CCC", bit32.bor(ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.DefaultHide))
            ImGui.TableSetupColumn("DDD", ImGuiTableColumnFlags.WidthStretch)
            ImGui.TableSetupColumn("EEE", ImGuiTableColumnFlags.WidthStretch)
            ImGui.TableSetupColumn("FFF", bit32.bor(ImGuiTableColumnFlags.WidthStretch, ImGuiTableColumnFlags.DefaultHide))
            ImGui.TableHeadersRow()
            for row = 0, 5 - 1 do
                ImGui.TableNextRow()
                for column = 0, 6 - 1 do
                    ImGui.TableSetColumnIndex(column)
                    ImGui.Text("%s %d,%d", (column >= 3) and "Stretch" or "Fixed", column, row)
                end
            end
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Reorderable, hideable, with headers") then
        IMGUI_DEMO_MARKER("Tables/Reorderable, hideable, with headers")
        HelpMarker(
            "Click and drag column headers to reorder columns.\n\n" ..
            "Right-click on a header to open a context menu.")
        local s = s.Reorderable
        PushStyleCompact()
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags, ImGuiTableFlags.Resizable)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Reorderable", s.flags, ImGuiTableFlags.Reorderable)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Hideable", s.flags, ImGuiTableFlags.Hideable)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBody", s.flags, ImGuiTableFlags.NoBordersInBody)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBodyUntilResize", s.flags, ImGuiTableFlags.NoBordersInBodyUntilResize); ImGui.SameLine(); HelpMarker("Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers)")
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_HighlightHoveredColumn", s.flags, ImGuiTableFlags.HighlightHoveredColumn)
        PopStyleCompact()

        if ImGui.BeginTable("table1", 3, s.flags) then
            -- Submit columns name with TableSetupColumn() and call TableHeadersRow() to create a row with a header in each column.
            -- (Later we will show how TableSetupColumn() has other uses, optional flags, sizing weight etc.)
            ImGui.TableSetupColumn("One")
            ImGui.TableSetupColumn("Two")
            ImGui.TableSetupColumn("Three")
            ImGui.TableHeadersRow()
            for row = 0, 6 - 1 do
                ImGui.TableNextRow()
                for column = 0, 3 - 1 do
                    ImGui.TableSetColumnIndex(column)
                    ImGui.Text("Hello %d,%d", column, row)
                end
            end
            ImGui.EndTable()
        end

        -- Use outer_size.x == 0.0f instead of default to make the table as tight as possible
        -- (only valid when no scrolling and no stretch column)
        if ImGui.BeginTable("table2", 3, bit32.bor(s.flags, ImGuiTableFlags.SizingFixedFit), ImVec2(0.0, 0.0)) then
            ImGui.TableSetupColumn("One")
            ImGui.TableSetupColumn("Two")
            ImGui.TableSetupColumn("Three")
            ImGui.TableHeadersRow()
            for row = 0, 6 - 1 do
                ImGui.TableNextRow()
                for column = 0, 3 - 1 do
                    ImGui.TableSetColumnIndex(column)
                    ImGui.Text("Fixed %d,%d", column, row)
                end
            end
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Padding") then
        IMGUI_DEMO_MARKER("Tables/Padding")
        -- First example: showcase use of padding flags and effect of BorderOuterV/BorderInnerV on X padding.
        -- We don't expose BorderOuterH/BorderInnerH here because they have no effect on X padding.
        HelpMarker(
            "We often want outer padding activated when any using features which makes the edges of a column visible:\n" ..
            "e.g.:\n" ..
            "- BorderOuterV\n" ..
            "- any form of row selection\n" ..
            "Because of this, activating BorderOuterV sets the default to PadOuterX. " ..
            "Using PadOuterX or NoPadOuterX you can override the default.\n\n" ..
            "Actual padding values are using style.CellPadding.\n\n" ..
            "In this demo we don't show horizontal borders to emphasize how they don't affect default horizontal padding.")

        local s = s.Padding
        PushStyleCompact()
        _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_PadOuterX", s.flags1, ImGuiTableFlags.PadOuterX)
        ImGui.SameLine(); HelpMarker("Enable outer-most padding (default if ImGuiTableFlags_BordersOuterV is set)")
        _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_NoPadOuterX", s.flags1, ImGuiTableFlags.NoPadOuterX)
        ImGui.SameLine(); HelpMarker("Disable outer-most padding (default if ImGuiTableFlags_BordersOuterV is not set)")
        _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_NoPadInnerX", s.flags1, ImGuiTableFlags.NoPadInnerX)
        ImGui.SameLine(); HelpMarker("Disable inner padding between columns (double inner padding if BordersOuterV is on, single inner padding if BordersOuterV is off)")
        _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterV", s.flags1, ImGuiTableFlags.BordersOuterV)
        _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerV", s.flags1, ImGuiTableFlags.BordersInnerV)
        _, s.show_headers = ImGui.Checkbox("show_headers", s.show_headers)
        PopStyleCompact()

        if ImGui.BeginTable("table_padding", 3, s.flags1) then
            if s.show_headers then
                ImGui.TableSetupColumn("One")
                ImGui.TableSetupColumn("Two")
                ImGui.TableSetupColumn("Three")
                ImGui.TableHeadersRow()
            end

            for row = 0, 5 - 1 do
                ImGui.TableNextRow()
                for column = 0, 3 - 1 do
                    ImGui.TableSetColumnIndex(column)
                    if row == 0 then
                        ImGui.Text("Avail %.2f", ImGui.GetContentRegionAvail().x)
                    else
                        local buf = string.format("Hello %d,%d", column, row)
                        ImGui.Button(buf, ImVec2(-FLT_MIN, 0.0))
                    end
                    --if bit32.band(ImGui.TableGetColumnFlags(), ImGuiTableColumnFlags.IsHovered) ~= 0 then
                    --    ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, IM_COL32(0, 100, 0, 255)) end
                end
            end
            ImGui.EndTable()
        end

        -- Second example: set style.CellPadding to (0.0) or a custom value.
        -- FIXME-TABLE: Vertical border effectively not displayed the same way as horizontal one...
        HelpMarker("Setting style.CellPadding to (0,0) or a custom value.")

        PushStyleCompact()
        _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_Borders", s.flags2, ImGuiTableFlags.Borders)
        _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersH", s.flags2, ImGuiTableFlags.BordersH)
        _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersV", s.flags2, ImGuiTableFlags.BordersV)
        _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInner", s.flags2, ImGuiTableFlags.BordersInner)
        _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuter", s.flags2, ImGuiTableFlags.BordersOuter)
        _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_RowBg", s.flags2, ImGuiTableFlags.RowBg)
        _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags2, ImGuiTableFlags.Resizable)
        _, s.show_widget_frame_bg = ImGui.Checkbox("show_widget_frame_bg", s.show_widget_frame_bg)
        ImGui.SliderFloat2("CellPadding", s.cell_padding, 0.0, 10.0, "%.0f")
        PopStyleCompact()

        ImGui.PushStyleVar(ImGuiStyleVar.CellPadding, s.cell_padding)
        if ImGui.BeginTable("table_padding_2", 3, s.flags2) then
            -- static char text_bufs[3 * 5][16] -- Mini text storage for 3x5 cells
            if not s.show_widget_frame_bg then
                ImGui.PushStyleColor(ImGuiCol.FrameBg, 0)
            end
            for cell = 0, 3 * 5 - 1 do
                ImGui.TableNextColumn()
                if s.init then
                    s.text_bufs[cell + 1] = ImGui.NewTextBuffer("edit me", 16) -- [Port] strcpy() -> new buffer
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

        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Sizing policies") then
        IMGUI_DEMO_MARKER("Tables/Explicit widths")
        local s = s.SizingPolicies
        PushStyleCompact()
        _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags1, ImGuiTableFlags.Resizable)
        _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendX", s.flags1, ImGuiTableFlags.NoHostExtendX)
        PopStyleCompact()

        local sizing_policy_flags = s.sizing_policy_flags -- 1-based
        for table_n = 0, 4 - 1 do
            ImGui.PushID(table_n)
            ImGui.SetNextItemWidth(TEXT_BASE_WIDTH * 30)
            sizing_policy_flags[table_n + 1] = EditTableSizingFlags(sizing_policy_flags[table_n + 1])

            -- To make it easier to understand the different sizing policy,
            -- For each policy: we display one table where the columns have equal contents width,
            -- and one where the columns have different contents width.
            if ImGui.BeginTable("table1", 3, bit32.bor(sizing_policy_flags[table_n + 1], s.flags1)) then
                for row = 0, 3 - 1 do
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn(); ImGui.Text("Oh dear")
                    ImGui.TableNextColumn(); ImGui.Text("Oh dear")
                    ImGui.TableNextColumn(); ImGui.Text("Oh dear")
                end
                ImGui.EndTable()
            end
            if ImGui.BeginTable("table2", 3, bit32.bor(sizing_policy_flags[table_n + 1], s.flags1)) then
                for row = 0, 3 - 1 do
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
        HelpMarker(
            "This section allows you to interact and see the effect of various sizing policies " ..
            "depending on whether Scroll is enabled and the contents of your columns.")

        local CT_ShowWidth, CT_ShortText, CT_LongText, CT_Button, CT_FillButton, CT_InputText = 0, 1, 2, 3, 4, 5 -- enum ContentsType

        PushStyleCompact()
        ImGui.PushID("Advanced")
        ImGui.PushItemWidth(TEXT_BASE_WIDTH * 30)
        s.flags = EditTableSizingFlags(s.flags)
        s.contents_type = ImGui.Combo("Contents", s.contents_type, "Show width\0Short Text\0Long Text\0Button\0Fill Button\0InputText\0")
        if s.contents_type == CT_FillButton then
            ImGui.SameLine()
            HelpMarker(
                "Be mindful that using right-alignment (e.g. size.x = -FLT_MIN) creates a feedback loop " ..
                "where contents width can feed into auto-column width can feed into contents width.")
        end
        s.column_count = ImGui.DragInt("Columns", s.column_count, 0.1, 1, 64, "%d", ImGuiSliderFlags.AlwaysClamp)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags, ImGuiTableFlags.Resizable)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_PreciseWidths", s.flags, ImGuiTableFlags.PreciseWidths)
        ImGui.SameLine(); HelpMarker("Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.")
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollX", s.flags, ImGuiTableFlags.ScrollX)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", s.flags, ImGuiTableFlags.ScrollY)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoClip", s.flags, ImGuiTableFlags.NoClip)
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
                local contents_type = s.contents_type
                if contents_type == CT_ShortText then      ImGui.TextUnformatted(label)
                elseif contents_type == CT_LongText then   ImGui.Text("Some %s text %d,%d\nOver two lines..", (column == 0) and "long" or "longeeer", column, row)
                elseif contents_type == CT_ShowWidth then  ImGui.Text("W: %.1f", ImGui.GetContentRegionAvail().x)
                elseif contents_type == CT_Button then     ImGui.Button(label)
                elseif contents_type == CT_FillButton then ImGui.Button(label, ImVec2(-FLT_MIN, 0.0))
                elseif contents_type == CT_InputText then  ImGui.SetNextItemWidth(-FLT_MIN); ImGui.InputText("##", s.text_buf, 32)
                end
                ImGui.PopID()
            end
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Vertical scrolling, with clipping") then
        IMGUI_DEMO_MARKER("Tables/Vertical scrolling, with clipping")
        HelpMarker(
            "Here we activate ScrollY, which will create a child window container to allow hosting scrollable contents.\n\n" ..
            "We also demonstrate using ImGuiListClipper to virtualize the submission of many items.")
        local s = s.VerticalScrolling

        PushStyleCompact()
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", s.flags, ImGuiTableFlags.ScrollY)
        PopStyleCompact()

        -- When using ScrollX or ScrollY we need to specify a size for our table container!
        -- Otherwise by default the table will fit all available space, like a BeginChild() call.
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
                    for column = 0, 3 - 1 do
                        ImGui.TableSetColumnIndex(column)
                        ImGui.Text("Hello %d,%d", column, row)
                    end
                end
            end
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Horizontal scrolling") then
        IMGUI_DEMO_MARKER("Tables/Horizontal scrolling")
        HelpMarker(
            "When ScrollX is enabled, the default sizing policy becomes ImGuiTableFlags_SizingFixedFit, " ..
            "as automatically stretching columns doesn't make much sense with horizontal scrolling.\n\n" ..
            "Also note that as of the current version, you will almost always want to enable ScrollY along with ScrollX, " ..
            "because the container window won't automatically extend vertically to fix contents " ..
            "(this may be improved in future versions).")
        local s = s.HorizontalScrolling

        PushStyleCompact()
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags, ImGuiTableFlags.Resizable)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollX", s.flags, ImGuiTableFlags.ScrollX)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", s.flags, ImGuiTableFlags.ScrollY)
        ImGui.SetNextItemWidth(ImGui.GetFrameHeight())
        s.freeze_cols = ImGui.DragInt("freeze_cols", s.freeze_cols, 0.2, 0, 9, nil, ImGuiSliderFlags.NoInput)
        ImGui.SetNextItemWidth(ImGui.GetFrameHeight())
        s.freeze_rows = ImGui.DragInt("freeze_rows", s.freeze_rows, 0.2, 0, 9, nil, ImGuiSliderFlags.NoInput)
        PopStyleCompact()

        -- When using ScrollX or ScrollY we need to specify a size for our table container!
        -- Otherwise by default the table will fit all available space, like a BeginChild() call.
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
            for row = 0, 20 - 1 do
                ImGui.TableNextRow()
                for column = 0, 7 - 1 do repeat
                    -- Both TableNextColumn() and TableSetColumnIndex() return true when a column is visible or performing width measurement.
                    -- Because here we know that:
                    -- - A) all our columns are contributing the same to row height
                    -- - B) column 0 is always visible,
                    -- We only always submit this one column and can skip others.
                    -- More advanced per-column clipping behaviors may benefit from polling the status flags via TableGetColumnFlags().
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
        HelpMarker(
            "Showcase using Stretch columns + ScrollX together: " ..
            "this is rather unusual and only makes sense when specifying an 'inner_width' for the table!\n" ..
            "Without an explicit value, inner_width is == outer_size.x and therefore using Stretch columns " ..
            "along with ScrollX doesn't make sense.")
        PushStyleCompact()
        ImGui.PushID("flags3")
        ImGui.PushItemWidth(TEXT_BASE_WIDTH * 30)
        _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollX", s.flags2, ImGuiTableFlags.ScrollX)
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
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Columns flags") then
        IMGUI_DEMO_MARKER("Tables/Columns flags")
        -- Create a first table just to show all the options/flags we want to make visible in our example!
        local column_count = 3
        local column_names = { "One", "Two", "Three" } -- 1-based
        local column_flags = s.ColumnsFlags.column_flags -- 1-based
        local column_flags_out = s.ColumnsFlags.column_flags_out -- Output from TableGetColumnFlags()

        if ImGui.BeginTable("table_columns_flags_checkboxes", column_count, ImGuiTableFlags.None) then
            PushStyleCompact()
            for column = 0, column_count - 1 do
                ImGui.TableNextColumn()
                ImGui.PushID(column)
                ImGui.AlignTextToFramePadding() -- FIXME-TABLE: Workaround for wrong text baseline propagation across columns
                ImGui.Text("'%s'", column_names[column + 1])
                ImGui.Spacing()
                ImGui.Text("Input flags:")
                column_flags[column + 1] = EditTableColumnsFlags(column_flags[column + 1])
                ImGui.Spacing()
                ImGui.Text("Output flags:")
                ImGui.BeginDisabled()
                ShowTableColumnsStatusFlags(column_flags_out[column + 1])
                ImGui.EndDisabled()
                ImGui.PopID()
            end
            PopStyleCompact()
            ImGui.EndTable()
        end

        -- Create the real table we care about for the example!
        -- We use a scrolling table to be able to showcase the difference between the _IsEnabled and _IsVisible flags above,
        -- otherwise in a non-scrolling table columns are always visible (unless using ImGuiTableFlags_NoKeepColumnsVisible
        -- + resizing the parent window down).
        local flags
            = bit32.bor(ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY
            , ImGuiTableFlags.RowBg, ImGuiTableFlags.BordersOuter, ImGuiTableFlags.BordersV
            , ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Sortable)
        local outer_size = ImVec2(0.0, TEXT_BASE_HEIGHT * 9)
        if ImGui.BeginTable("table_columns_flags", column_count, flags, outer_size) then
            local has_angled_header = false
            for column = 0, column_count - 1 do
                has_angled_header = has_angled_header or (bit32.band(column_flags[column + 1], ImGuiTableColumnFlags.AngledHeader) ~= 0)
                ImGui.TableSetupColumn(column_names[column + 1], column_flags[column + 1])
            end
            if has_angled_header then
                ImGui.TableAngledHeadersRow()
            end
            ImGui.TableHeadersRow()
            for column = 0, column_count - 1 do
                column_flags_out[column + 1] = ImGui.TableGetColumnFlags(column)
            end
            local indent_step = math.floor(math.floor(TEXT_BASE_WIDTH) / 2)
            for row = 0, 8 - 1 do
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
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Columns widths") then
        IMGUI_DEMO_MARKER("Tables/Columns widths")
        HelpMarker("Using TableSetupColumn() to setup default width.")

        local s = s.ColumnsWidths
        PushStyleCompact()
        _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags1, ImGuiTableFlags.Resizable)
        _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBodyUntilResize", s.flags1, ImGuiTableFlags.NoBordersInBodyUntilResize)
        PopStyleCompact()
        if ImGui.BeginTable("table1", 3, s.flags1) then
            -- We could also set ImGuiTableFlags_SizingFixedFit on the table and all columns will default to ImGuiTableColumnFlags_WidthFixed.
            ImGui.TableSetupColumn("one", ImGuiTableColumnFlags.WidthFixed, 100.0) -- Default to 100.0f
            ImGui.TableSetupColumn("two", ImGuiTableColumnFlags.WidthFixed, 200.0) -- Default to 200.0f
            ImGui.TableSetupColumn("three", ImGuiTableColumnFlags.WidthFixed)       -- Default to auto
            ImGui.TableHeadersRow()
            for row = 0, 4 - 1 do
                ImGui.TableNextRow()
                for column = 0, 3 - 1 do
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

        HelpMarker(
            "Using TableSetupColumn() to setup explicit width.\n\nUnless _NoKeepColumnsVisible is set, " ..
            "fixed columns with set width may still be shrunk down if there's not enough space in the host.")

        PushStyleCompact()
        _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_NoKeepColumnsVisible", s.flags2, ImGuiTableFlags.NoKeepColumnsVisible)
        _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerV", s.flags2, ImGuiTableFlags.BordersInnerV)
        _, s.flags2 = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterV", s.flags2, ImGuiTableFlags.BordersOuterV)
        PopStyleCompact()
        if ImGui.BeginTable("table2", 4, s.flags2) then
            -- We could also set ImGuiTableFlags_SizingFixedFit on the table and then all columns
            -- will default to ImGuiTableColumnFlags_WidthFixed.
            ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed, 100.0)
            ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 15.0)
            ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 30.0)
            ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 15.0)
            for row = 0, 5 - 1 do
                ImGui.TableNextRow()
                for column = 0, 4 - 1 do
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
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Nested tables") then
        IMGUI_DEMO_MARKER("Tables/Nested tables")
        HelpMarker("This demonstrates embedding a table into another table cell.")

        if ImGui.BeginTable("table_nested1", 2, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable)) then
            ImGui.TableSetupColumn("A0")
            ImGui.TableSetupColumn("A1")
            ImGui.TableHeadersRow()

            ImGui.TableNextColumn()
            ImGui.Text("A0 Row 0")
            do
                local rows_height = (TEXT_BASE_HEIGHT * 2.0) + (ImGui.GetStyle().CellPadding.y * 2.0)
                if ImGui.BeginTable("table_nested2", 2, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable)) then
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
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Row height") then
        IMGUI_DEMO_MARKER("Tables/Row height")
        HelpMarker(
            "You can pass a 'min_row_height' to TableNextRow().\n\nRows are padded with 'style.CellPadding.y' on top and bottom, " ..
            "so effectively the minimum row height will always be >= 'style.CellPadding.y * 2.0f'.\n\n" ..
            "We cannot honor a _maximum_ row height as that would require a unique clipping rectangle per row.")
        if ImGui.BeginTable("table_row_height", 1, ImGuiTableFlags.Borders) then
            for row = 0, 8 - 1 do
                local min_row_height = math.floor(TEXT_BASE_HEIGHT * 0.30 * row + ImGui.GetStyle().CellPadding.y * 2.0)
                ImGui.TableNextRow(ImGuiTableRowFlags.None, min_row_height)
                ImGui.TableNextColumn()
                ImGui.Text("min_row_height = %.2f", min_row_height)
            end
            ImGui.EndTable()
        end

        HelpMarker(
            "Showcase using SameLine(0,0) to share Current Line Height between cells.\n\n" ..
            "Please note that Tables Row Height is not the same thing as Current Line Height, " ..
            "as a table cell may contains multiple lines.")
        if ImGui.BeginTable("table_share_lineheight", 2, ImGuiTableFlags.Borders) then
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

        HelpMarker("Showcase altering CellPadding.y between rows. Note that CellPadding.x is locked for the entire table.")
        if ImGui.BeginTable("table_changing_cellpadding_y", 1, ImGuiTableFlags.Borders) then
            local style = ImGui.GetStyle()
            for row = 0, 8 - 1 do
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

        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Outer size") then
        IMGUI_DEMO_MARKER("Tables/Outer size")
        -- Showcasing use of ImGuiTableFlags_NoHostExtendX and ImGuiTableFlags_NoHostExtendY
        -- Important to that note how the two flags have slightly different behaviors!
        ImGui.Text("Using NoHostExtendX and NoHostExtendY:")
        PushStyleCompact()
        local s = s.OuterSize
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendX", s.flags, ImGuiTableFlags.NoHostExtendX)
        ImGui.SameLine(); HelpMarker("Make outer width auto-fit to columns, overriding outer_size.x value.\n\nOnly available when ScrollX/ScrollY are disabled and Stretch columns are not used.")
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendY", s.flags, ImGuiTableFlags.NoHostExtendY)
        ImGui.SameLine(); HelpMarker("Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit).\n\nOnly available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.")
        PopStyleCompact()

        local outer_size = ImVec2(0.0, TEXT_BASE_HEIGHT * 5.5)
        if ImGui.BeginTable("table1", 3, s.flags, outer_size) then
            for row = 0, 10 - 1 do
                ImGui.TableNextRow()
                for column = 0, 3 - 1 do
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
        if ImGui.BeginTable("table2", 3, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg), ImVec2(TEXT_BASE_WIDTH * 30, 0.0)) then
            for row = 0, 5 - 1 do
                ImGui.TableNextRow()
                for column = 0, 3 - 1 do
                    ImGui.TableNextColumn()
                    ImGui.Text("Cell %d,%d", column, row)
                end
            end
            ImGui.EndTable()
        end
        ImGui.SameLine()
        if ImGui.BeginTable("table3", 3, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg), ImVec2(TEXT_BASE_WIDTH * 30, 0.0)) then
            local rows_height = TEXT_BASE_HEIGHT * 1.5 + ImGui.GetStyle().CellPadding.y * 2.0
            for row = 0, 3 - 1 do
                ImGui.TableNextRow(0, rows_height)
                for column = 0, 3 - 1 do
                    ImGui.TableNextColumn()
                    ImGui.Text("Cell %d,%d", column, row)
                end
            end
            ImGui.EndTable()
        end

        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Background color") then
        IMGUI_DEMO_MARKER("Tables/Background color")
        local s = s.BackgroundColor

        PushStyleCompact()
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Borders", s.flags, ImGuiTableFlags.Borders)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_RowBg", s.flags, ImGuiTableFlags.RowBg)
        ImGui.SameLine(); HelpMarker("ImGuiTableFlags_RowBg automatically sets RowBg0 to alternative colors pulled from the Style.")
        s.row_bg_type = ImGui.Combo("row bg type", s.row_bg_type, "None\0Red\0Gradient\0")
        s.row_bg_target = ImGui.Combo("row bg target", s.row_bg_target, "RowBg0\0RowBg1\0"); ImGui.SameLine(); HelpMarker("Target RowBg0 to override the alternating odd/even colors,\nTarget RowBg1 to blend with them.")
        s.cell_bg_type = ImGui.Combo("cell bg type", s.cell_bg_type, "None\0Blue\0"); ImGui.SameLine(); HelpMarker("We are colorizing cells to B1->C2 here.")
        IM_ASSERT(s.row_bg_type >= 0 and s.row_bg_type <= 2)
        IM_ASSERT(s.row_bg_target >= 0 and s.row_bg_target <= 1)
        IM_ASSERT(s.cell_bg_type >= 0 and s.cell_bg_type <= 1)
        PopStyleCompact()

        if ImGui.BeginTable("table1", 5, s.flags) then
            for row = 0, 6 - 1 do
                ImGui.TableNextRow()

                -- Demonstrate setting a row background color with 'ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBgX, ...)'
                -- We use a transparent color so we can see the one behind in case our target is RowBg1 and RowBg0 was already targeted by the ImGuiTableFlags_RowBg flag.
                if s.row_bg_type ~= 0 then
                    local row_bg_color = ImGui.GetColorU32((s.row_bg_type == 1) and ImVec4(0.7, 0.3, 0.3, 0.65) or ImVec4(0.2 + row * 0.1, 0.2, 0.2, 0.65)) -- Flat or Gradient?
                    ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0 + s.row_bg_target, row_bg_color)
                end

                -- Fill cells
                for column = 0, 5 - 1 do
                    ImGui.TableSetColumnIndex(column)
                    ImGui.Text("%c%c", string.byte("A") + row, string.byte("0") + column)

                    -- Change background of Cells B1->C2
                    -- Demonstrate setting a cell background color with 'ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, ...)'
                    -- (the CellBg color will be blended over the RowBg and ColumnBg colors)
                    -- We can also pass a column number as a third parameter to TableSetBgColor() and do this outside the column loop.
                    if row >= 1 and row <= 2 and column >= 1 and column <= 2 and s.cell_bg_type == 1 then
                        local cell_bg_color = ImGui.GetColorU32(ImVec4(0.3, 0.3, 0.7, 0.65))
                        ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, cell_bg_color)
                    end
                end
            end
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Tree view") then
        IMGUI_DEMO_MARKER("Tables/Tree view")
        local s = s.TreeView

        _, s.tree_node_flags_base = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanFullWidth",  s.tree_node_flags_base, ImGuiTreeNodeFlags.SpanFullWidth)
        _, s.tree_node_flags_base = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanLabelWidth",  s.tree_node_flags_base, ImGuiTreeNodeFlags.SpanLabelWidth)
        _, s.tree_node_flags_base = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_SpanAllColumns", s.tree_node_flags_base, ImGuiTreeNodeFlags.SpanAllColumns)
        _, s.tree_node_flags_base = ImGui.CheckboxFlags("ImGuiTreeNodeFlags_LabelSpanAllColumns", s.tree_node_flags_base, ImGuiTreeNodeFlags.LabelSpanAllColumns)
        ImGui.SameLine(); HelpMarker("Useful if you know that you aren't displaying contents in other columns")

        HelpMarker("See \"Columns flags\" section to configure how indentation is applied to individual columns.")
        if ImGui.BeginTable("3ways", 3, s.table_flags) then
            -- The first column will use the default _WidthStretch when ScrollX is Off and _WidthFixed when ScrollX is On
            ImGui.TableSetupColumn("Name", ImGuiTableColumnFlags.NoHide)
            ImGui.TableSetupColumn("Size", ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 12.0)
            ImGui.TableSetupColumn("Type", ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 18.0)
            ImGui.TableHeadersRow()

            -- Simple storage to output a dummy file-system.
            -- struct MyTreeNode { Name, Type, Size, ChildIdx, ChildCount } (see s.nodes)
            local MyTreeNode = s.MyTreeNode
            if MyTreeNode == nil then -- [Port] local struct with a static method, created once and kept in statics
                MyTreeNode = {}
                function MyTreeNode.DisplayNode(node, all_nodes)
                    ImGui.TableNextRow()
                    ImGui.TableNextColumn()
                    local is_folder = (node.ChildCount > 0)

                    local node_flags = s.tree_node_flags_base
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
                                MyTreeNode.DisplayNode(all_nodes[node.ChildIdx + child_n + 1], all_nodes)
                            end
                            ImGui.TreePop()
                        end
                    else
                        ImGui.TreeNodeEx(node.Name, bit32.bor(node_flags, ImGuiTreeNodeFlags.Leaf, ImGuiTreeNodeFlags.Bullet, ImGuiTreeNodeFlags.NoTreePushOnOpen))
                        ImGui.TableNextColumn()
                        ImGui.Text("%d", node.Size)
                        ImGui.TableNextColumn()
                        ImGui.TextUnformatted(node.Type)
                    end
                end
                s.MyTreeNode = MyTreeNode
            end
            local nodes = s.nodes

            MyTreeNode.DisplayNode(nodes[1], nodes)

            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Item width") then
        IMGUI_DEMO_MARKER("Tables/Item width")
        HelpMarker(
            "Showcase using PushItemWidth() and how it is preserved on a per-column basis.\n\n" ..
            "Note that on auto-resizing non-resizable fixed columns, querying the content width for " ..
            "e.g. right-alignment doesn't make sense.")
        if ImGui.BeginTable("table_item_width", 3, ImGuiTableFlags.Borders) then
            ImGui.TableSetupColumn("small")
            ImGui.TableSetupColumn("half")
            ImGui.TableSetupColumn("right-align")
            ImGui.TableHeadersRow()

            for row = 0, 3 - 1 do
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
                local s = s.ItemWidth
                ImGui.PushID(row)
                ImGui.TableSetColumnIndex(0)
                s.dummy_f = ImGui.SliderFloat("float0", s.dummy_f, 0.0, 1.0)
                ImGui.TableSetColumnIndex(1)
                s.dummy_f = ImGui.SliderFloat("float1", s.dummy_f, 0.0, 1.0)
                ImGui.TableSetColumnIndex(2)
                s.dummy_f = ImGui.SliderFloat("##float2", s.dummy_f, 0.0, 1.0) -- No visible label since right-aligned
                ImGui.PopID()
            end
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    -- Demonstrate using TableHeader() calls instead of TableHeadersRow()
    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Custom headers") then
        IMGUI_DEMO_MARKER("Tables/Custom headers")
        local COLUMNS_COUNT = 3
        if ImGui.BeginTable("table_custom_headers", COLUMNS_COUNT, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable)) then
            ImGui.TableSetupColumn("Apricot")
            ImGui.TableSetupColumn("Banana")
            ImGui.TableSetupColumn("Cherry")

            -- Dummy entire-column selection storage
            -- FIXME: It would be nice to actually demonstrate full-featured selection using those checkbox.
            local column_selected = s.CustomHeaders.column_selected -- 1-based

            -- Instead of calling TableHeadersRow() we'll submit custom headers ourselves.
            -- (A different approach is also possible:
            --    - Specify ImGuiTableColumnFlags_NoHeaderLabel in some TableSetupColumn() call.
            --    - Call TableHeadersRow() normally. This will submit TableHeader() with no name.
            --    - Then call TableSetColumnIndex() to position yourself in the column and submit your stuff e.g. Checkbox().)
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
            for row = 0, 5 - 1 do
                ImGui.TableNextRow()
                for column = 0, 3 - 1 do
                    local buf = string.format("Cell %d,%d", column, row)
                    ImGui.TableSetColumnIndex(column)
                    ImGui.Selectable(buf, column_selected[column + 1])
                end
            end
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    -- Demonstrate using ImGuiTableColumnFlags_AngledHeader flag to create angled headers
    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Angled headers") then
        IMGUI_DEMO_MARKER("Tables/Angled headers")
        local column_names = { "Track", "cabasa", "ride", "smash", "tom-hi", "tom-mid", "tom-low", "hihat-o", "hihat-c", "snare-s", "snare-c", "clap", "rim", "kick" } -- 1-based
        local columns_count = #column_names
        local rows_count = 12

        local s = s.AngledHeaders
        -- static bool bools[columns_count * rows_count] = {} -- Dummy storage selection storage
        local bools = s.bools -- 1-based
        if #bools == 0 then
            for n = 1, columns_count * rows_count do bools[n] = false end
        end
        _, s.table_flags = ImGui.CheckboxFlags("_ScrollX", s.table_flags, ImGuiTableFlags.ScrollX)
        _, s.table_flags = ImGui.CheckboxFlags("_ScrollY", s.table_flags, ImGuiTableFlags.ScrollY)
        _, s.table_flags = ImGui.CheckboxFlags("_Resizable", s.table_flags, ImGuiTableFlags.Resizable)
        _, s.table_flags = ImGui.CheckboxFlags("_Sortable", s.table_flags, ImGuiTableFlags.Sortable)
        _, s.table_flags = ImGui.CheckboxFlags("_NoBordersInBody", s.table_flags, ImGuiTableFlags.NoBordersInBody)
        _, s.table_flags = ImGui.CheckboxFlags("_HighlightHoveredColumn", s.table_flags, ImGuiTableFlags.HighlightHoveredColumn)
        ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
        s.frozen_cols = ImGui.SliderInt("Frozen columns", s.frozen_cols, 0, 2)
        ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
        s.frozen_rows = ImGui.SliderInt("Frozen rows", s.frozen_rows, 0, 2)
        _, s.column_flags = ImGui.CheckboxFlags("Disable header contributing to column width", s.column_flags, ImGuiTableColumnFlags.NoHeaderWidth)

        if ImGui.TreeNode("Style settings") then
            ImGui.SameLine()
            HelpMarker("Giving access to some ImGuiStyle value in this demo for convenience.")
            ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
            ImGui.GetStyle().TableAngledHeadersAngle = ImGui.SliderAngle("style.TableAngledHeadersAngle", ImGui.GetStyle().TableAngledHeadersAngle, -50.0, 50.0)
            ImGui.SetNextItemWidth(ImGui.GetFontSize() * 8)
            ImGui.SliderFloat2("style.TableAngledHeadersTextAlign", ImGui.GetStyle().TableAngledHeadersTextAlign, 0.0, 1.0, "%.2f")
            ImGui.TreePop()
        end

        if ImGui.BeginTable("table_angled_headers", columns_count, s.table_flags, ImVec2(0.0, TEXT_BASE_HEIGHT * 12)) then
            ImGui.TableSetupColumn(column_names[1], bit32.bor(ImGuiTableColumnFlags.NoHide, ImGuiTableColumnFlags.NoReorder))
            for n = 1, columns_count - 1 do
                ImGui.TableSetupColumn(column_names[n + 1], s.column_flags)
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
                        _, bools[row * columns_count + column + 1] = ImGui.Checkbox("", bools[row * columns_count + column + 1])
                        ImGui.PopID()
                    end
                end
                ImGui.PopID()
            end
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end

    -- Demonstrate creating custom context menus inside columns,
    -- while playing it nice with context menus provided by TableHeadersRow()/TableHeader()
    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Context menus") then
        IMGUI_DEMO_MARKER("Tables/Context menus")
        HelpMarker(
            "By default, right-clicking over a TableHeadersRow()/TableHeader() line will open the default context-menu.\n" ..
            "Using ImGuiTableFlags_ContextMenuInBody we also allow right-clicking over columns body.")
        local s = s.ContextMenus

        PushStyleCompact()
        _, s.flags1 = ImGui.CheckboxFlags("ImGuiTableFlags_ContextMenuInBody", s.flags1, ImGuiTableFlags.ContextMenuInBody)
        PopStyleCompact()

        -- Context Menus: first example
        -- [1.1] Right-click on the TableHeadersRow() line to open the default table context menu.
        -- [1.2] Right-click in columns also open the default table context menu (if ImGuiTableFlags_ContextMenuInBody is set)
        local COLUMNS_COUNT = 3
        if ImGui.BeginTable("table_context_menu", COLUMNS_COUNT, s.flags1) then
            ImGui.TableSetupColumn("One")
            ImGui.TableSetupColumn("Two")
            ImGui.TableSetupColumn("Three")

            -- [1.1]] Right-click on the TableHeadersRow() line to open the default table context menu.
            ImGui.TableHeadersRow()

            -- Submit dummy contents
            for row = 0, 4 - 1 do
                ImGui.TableNextRow()
                for column = 0, COLUMNS_COUNT - 1 do
                    ImGui.TableSetColumnIndex(column)
                    ImGui.Text("Cell %d,%d", column, row)
                end
            end
            ImGui.EndTable()
        end

        -- Context Menus: second example
        -- [2.1] Right-click on the TableHeadersRow() line to open the default table context menu.
        -- [2.2] Right-click on the ".." to open a custom popup
        -- [2.3] Right-click in columns to open another custom popup
        HelpMarker(
            "Demonstrate mixing table context menu (over header), item context button (over button) " ..
            "and custom per-column context menu (over column body).")
        local flags2 = bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Borders)
        if ImGui.BeginTable("table_context_menu_2", COLUMNS_COUNT, flags2) then
            ImGui.TableSetupColumn("One")
            ImGui.TableSetupColumn("Two")
            ImGui.TableSetupColumn("Three")

            -- [2.1] Right-click on the TableHeadersRow() line to open the default table context menu.
            ImGui.TableHeadersRow()
            for row = 0, 4 - 1 do
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
            -- (instead of testing for !IsAnyItemHovered() we could also call OpenPopup() with ImGuiPopupFlags_NoOpenOverExistingPopup
            -- to manage popup priority as the popups triggers, here "are we hovering a column" are overlapping)
            local hovered_column = -1
            for column = 0, COLUMNS_COUNT + 1 - 1 do
                ImGui.PushID(column)
                if bit32.band(ImGui.TableGetColumnFlags(column), ImGuiTableColumnFlags.IsHovered) ~= 0 then
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
        ImGui.TreePop()
    end

    -- Demonstrate creating multiple tables with the same ID
    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Synced instances") then
        IMGUI_DEMO_MARKER("Tables/Synced instances")
        HelpMarker("Multiple tables with the same identifier will share their settings, width, visibility, order etc.")

        local s = s.SyncedInstances
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags, ImGuiTableFlags.Resizable)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", s.flags, ImGuiTableFlags.ScrollY)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SizingFixedFit", s.flags, ImGuiTableFlags.SizingFixedFit)
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_HighlightHoveredColumn", s.flags, ImGuiTableFlags.HighlightHoveredColumn)
        for n = 0, 3 - 1 do
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
        ImGui.TreePop()
    end

    -- Demonstrate using Sorting facilities
    -- This is a simplified version of the "Advanced" example, where we mostly focus on the code necessary to handle sorting.
    -- Note that the "Advanced" example also showcase manually triggering a sort (e.g. if item quantities have been modified)
    local template_items_names = s.template_items_names -- 1-based
    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Sorting") then
        IMGUI_DEMO_MARKER("Tables/Sorting")
        local s = s.Sorting
        -- Create item list
        local items = s.items
        if items.Size == 0 then
            items:resize(50)
            for n = 0, items.Size - 1 do
                local template_n = n % #template_items_names
                local item = MyItem(); items.Data[n + 1] = item -- [Port] resize(50, MyItem()) would share one table
                item.ID = n
                item.Name = template_items_names[template_n + 1]
                item.Quantity = (n * n - n) % 20 -- Assign default quantities
            end
        end

        -- Options
        PushStyleCompact()
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SortMulti", s.flags, ImGuiTableFlags.SortMulti)
        ImGui.SameLine(); HelpMarker("When sorting is enabled: hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).")
        _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SortTristate", s.flags, ImGuiTableFlags.SortTristate)
        ImGui.SameLine(); HelpMarker("When sorting is enabled: allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).")
        PopStyleCompact()

        if ImGui.BeginTable("table_sorting", 4, s.flags, ImVec2(0.0, TEXT_BASE_HEIGHT * 15), 0.0) then
            -- Declare columns
            -- We use the "user_id" parameter of TableSetupColumn() to specify a user id that will be stored in the sort specifications.
            -- This is so our sort function can identify a column given our own identifier. We could also identify them based on their index!
            -- Demonstrate using a mixture of flags among available sort-related flags:
            -- - ImGuiTableColumnFlags_DefaultSort
            -- - ImGuiTableColumnFlags_NoSort / ImGuiTableColumnFlags_NoSortAscending / ImGuiTableColumnFlags_NoSortDescending
            -- - ImGuiTableColumnFlags_PreferSortAscending / ImGuiTableColumnFlags_PreferSortDescending
            ImGui.TableSetupColumn("ID",       bit32.bor(ImGuiTableColumnFlags.DefaultSort,          ImGuiTableColumnFlags.WidthFixed),   0.0, MyItemColumnID_ID)
            ImGui.TableSetupColumn("Name",                                                           ImGuiTableColumnFlags.WidthFixed,    0.0, MyItemColumnID_Name)
            ImGui.TableSetupColumn("Action",   bit32.bor(ImGuiTableColumnFlags.NoSort,               ImGuiTableColumnFlags.WidthFixed),   0.0, MyItemColumnID_Action)
            ImGui.TableSetupColumn("Quantity", bit32.bor(ImGuiTableColumnFlags.PreferSortDescending, ImGuiTableColumnFlags.WidthStretch), 0.0, MyItemColumnID_Quantity)
            ImGui.TableSetupScrollFreeze(0, 1) -- Make row always visible
            ImGui.TableHeadersRow()

            -- Sort our data if sort specs have been changed!
            local sort_specs = ImGui.TableGetSortSpecs()
            if sort_specs then
                if sort_specs.SpecsDirty then
                    MyItem_SortWithSortSpecs(sort_specs, items.Data, items.Size)
                    sort_specs.SpecsDirty = false
                end
            end

            -- Demonstrate using clipper for large vertical lists
            local clipper = ImGuiListClipper()
            clipper:Begin(items.Size)
            while clipper:Step() do
                for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                    -- Display a data item
                    local item = items.Data[row_n + 1]
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
        ImGui.TreePop()
    end

    -- In this example we'll expose most table flags and settings.
    -- For specific flags and settings refer to the corresponding section for more detailed explanation.
    -- This section is mostly useful to experiment with combining certain flags or settings with each others.
    --ImGui.SetNextItemOpen(true, ImGuiCond.Once) -- [DEBUG]
    if open_action ~= -1 then
        ImGui.SetNextItemOpen(open_action ~= 0)
    end
    if ImGui.TreeNode("Advanced") then
        IMGUI_DEMO_MARKER("Tables/Advanced")
        local s = s.Advanced

        local CT_Text, CT_Button, CT_SmallButton, CT_FillButton, CT_Selectable, CT_SelectableSpanRow = 0, 1, 2, 3, 4, 5 -- enum ContentsType
        local contents_type_names = { "Text", "Button", "SmallButton", "FillButton", "Selectable", "Selectable (span row)" }
        if s.outer_size_value == nil then s.outer_size_value = ImVec2(0.0, TEXT_BASE_HEIGHT * 12) end
        -- static float row_min_height = 0.0f -- Auto
        -- static float inner_width_with_scroll = 0.0f -- Auto-extend
        --static ImGuiTextFilter filter
        --ImGui.SetNextItemOpen(true, ImGuiCond.Once) -- FIXME-TABLE: Enabling this results in initial clipped first pass on table which tend to affect column sizing
        if ImGui.TreeNode("Options") then
            -- Make the UI compact because there are so many fields
            PushStyleCompact()
            ImGui.PushItemWidth(TEXT_BASE_WIDTH * 28.0)

            if ImGui.TreeNodeEx("Features:", ImGuiTreeNodeFlags.DefaultOpen) then
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Resizable", s.flags, ImGuiTableFlags.Resizable)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Reorderable", s.flags, ImGuiTableFlags.Reorderable)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Hideable", s.flags, ImGuiTableFlags.Hideable)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_Sortable", s.flags, ImGuiTableFlags.Sortable)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoSavedSettings", s.flags, ImGuiTableFlags.NoSavedSettings)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ContextMenuInBody", s.flags, ImGuiTableFlags.ContextMenuInBody)
                ImGui.TreePop()
            end

            if ImGui.TreeNodeEx("Decorations:", ImGuiTreeNodeFlags.DefaultOpen) then
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_RowBg", s.flags, ImGuiTableFlags.RowBg)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersV", s.flags, ImGuiTableFlags.BordersV)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterV", s.flags, ImGuiTableFlags.BordersOuterV)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerV", s.flags, ImGuiTableFlags.BordersInnerV)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersH", s.flags, ImGuiTableFlags.BordersH)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersOuterH", s.flags, ImGuiTableFlags.BordersOuterH)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_BordersInnerH", s.flags, ImGuiTableFlags.BordersInnerH)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBody", s.flags, ImGuiTableFlags.NoBordersInBody); ImGui.SameLine(); HelpMarker("Disable vertical borders in columns Body (borders will always appear in Headers)")
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoBordersInBodyUntilResize", s.flags, ImGuiTableFlags.NoBordersInBodyUntilResize); ImGui.SameLine(); HelpMarker("Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers)")
                ImGui.TreePop()
            end

            if ImGui.TreeNodeEx("Sizing:", ImGuiTreeNodeFlags.DefaultOpen) then
                s.flags = EditTableSizingFlags(s.flags)
                ImGui.SameLine(); HelpMarker("In the Advanced demo we override the policy of each column so those table-wide settings have less effect that typical.")
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendX", s.flags, ImGuiTableFlags.NoHostExtendX)
                ImGui.SameLine(); HelpMarker("Make outer width auto-fit to columns, overriding outer_size.x value.\n\nOnly available when ScrollX/ScrollY are disabled and Stretch columns are not used.")
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoHostExtendY", s.flags, ImGuiTableFlags.NoHostExtendY)
                ImGui.SameLine(); HelpMarker("Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit).\n\nOnly available when ScrollX/ScrollY are disabled. Data below the limit will be clipped and not visible.")
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoKeepColumnsVisible", s.flags, ImGuiTableFlags.NoKeepColumnsVisible)
                ImGui.SameLine(); HelpMarker("Only available if ScrollX is disabled.")
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_PreciseWidths", s.flags, ImGuiTableFlags.PreciseWidths)
                ImGui.SameLine(); HelpMarker("Disable distributing remainder width to stretched columns (width allocation on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this flag: 33,33,33). With larger number of columns, resizing will appear to be less smooth.")
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoClip", s.flags, ImGuiTableFlags.NoClip)
                ImGui.SameLine(); HelpMarker("Disable clipping rectangle for every individual columns (reduce draw command count, items will be able to overflow into other columns). Generally incompatible with ScrollFreeze options.")
                ImGui.TreePop()
            end

            if ImGui.TreeNodeEx("Padding:", ImGuiTreeNodeFlags.DefaultOpen) then
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_PadOuterX", s.flags, ImGuiTableFlags.PadOuterX)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoPadOuterX", s.flags, ImGuiTableFlags.NoPadOuterX)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_NoPadInnerX", s.flags, ImGuiTableFlags.NoPadInnerX)
                ImGui.TreePop()
            end

            if ImGui.TreeNodeEx("Scrolling:", ImGuiTreeNodeFlags.DefaultOpen) then
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollX", s.flags, ImGuiTableFlags.ScrollX)
                ImGui.SameLine()
                ImGui.SetNextItemWidth(ImGui.GetFrameHeight())
                s.freeze_cols = ImGui.DragInt("freeze_cols", s.freeze_cols, 0.2, 0, 9, nil, ImGuiSliderFlags.NoInput)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_ScrollY", s.flags, ImGuiTableFlags.ScrollY)
                ImGui.SameLine()
                ImGui.SetNextItemWidth(ImGui.GetFrameHeight())
                s.freeze_rows = ImGui.DragInt("freeze_rows", s.freeze_rows, 0.2, 0, 9, nil, ImGuiSliderFlags.NoInput)
                ImGui.TreePop()
            end

            if ImGui.TreeNodeEx("Sorting:", ImGuiTreeNodeFlags.DefaultOpen) then
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SortMulti", s.flags, ImGuiTableFlags.SortMulti)
                ImGui.SameLine(); HelpMarker("When sorting is enabled: hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).")
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_SortTristate", s.flags, ImGuiTableFlags.SortTristate)
                ImGui.SameLine(); HelpMarker("When sorting is enabled: allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).")
                ImGui.TreePop()
            end

            if ImGui.TreeNodeEx("Headers:", ImGuiTreeNodeFlags.DefaultOpen) then
                _, s.show_headers = ImGui.Checkbox("show_headers", s.show_headers)
                _, s.flags = ImGui.CheckboxFlags("ImGuiTableFlags_HighlightHoveredColumn", s.flags, ImGuiTableFlags.HighlightHoveredColumn)
                _, s.columns_base_flags = ImGui.CheckboxFlags("ImGuiTableColumnFlags_AngledHeader", s.columns_base_flags, ImGuiTableColumnFlags.AngledHeader)
                ImGui.SameLine(); HelpMarker("Enable AngledHeader on all columns. Best enabled on selected narrow columns (see \"Angled headers\" section of the demo).")
                ImGui.TreePop()
            end

            if ImGui.TreeNodeEx("Other:", ImGuiTreeNodeFlags.DefaultOpen) then
                _, s.show_wrapped_text = ImGui.Checkbox("show_wrapped_text", s.show_wrapped_text)

                ImGui.DragFloat2("##OuterSize", s.outer_size_value)
                ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
                _, s.outer_size_enabled = ImGui.Checkbox("outer_size", s.outer_size_enabled)
                ImGui.SameLine()
                HelpMarker("If scrolling is disabled (ScrollX and ScrollY not set):\n" ..
                    "- The table is output directly in the parent window.\n" ..
                    "- OuterSize.x < 0.0f will right-align the table.\n" ..
                    "- OuterSize.x = 0.0f will narrow fit the table unless there are any Stretch columns.\n" ..
                    "- OuterSize.y then becomes the minimum size for the table, which will extend vertically if there are more rows (unless NoHostExtendY is set).")

                -- From a user point of view we will tend to use 'inner_width' differently depending on whether our table is embedding scrolling.
                -- To facilitate toying with this demo we will actually pass 0.0f to the BeginTable() when ScrollX is disabled.
                s.inner_width_with_scroll = ImGui.DragFloat("inner_width (when ScrollX active)", s.inner_width_with_scroll, 1.0, 0.0, FLT_MAX)

                s.row_min_height = ImGui.DragFloat("row_min_height", s.row_min_height, 1.0, 0.0, FLT_MAX)
                ImGui.SameLine(); HelpMarker("Specify height of the Selectable item.")

                s.items_count = ImGui.DragInt("items_count", s.items_count, 0.1, 0, 9999)
                s.contents_type = ImGui.Combo("items_type (first column)", s.contents_type, contents_type_names, #contents_type_names)
                --filter.Draw("filter")
                ImGui.TreePop()
            end

            ImGui.PopItemWidth()
            PopStyleCompact()
            ImGui.Spacing()
            ImGui.TreePop()
        end

        -- Update item list if we changed the number of items
        local items = s.items
        local selection = s.selection
        if items.Size ~= s.items_count then
            items:resize(s.items_count)
            for n = 0, s.items_count - 1 do
                local template_n = n % #template_items_names
                local item = items.Data[n + 1]
                if item == nil then item = MyItem(); items.Data[n + 1] = item end -- [Port] resize(n, MyItem()) would share one table
                item.ID = n
                item.Name = template_items_names[template_n + 1]
                item.Quantity = (template_n == 3) and 10 or (template_n == 4) and 20 or 0 -- Assign default quantities
            end
        end

        local parent_draw_list = ImGui.GetWindowDrawList()
        local parent_draw_list_draw_cmd_count = parent_draw_list.CmdBuffer.Size
        local table_scroll_cur, table_scroll_max -- For debug display
        local table_draw_list = nil  -- "

        -- Submit table
        local flags = s.flags
        local columns_base_flags = s.columns_base_flags
        local inner_width_to_use = (bit32.band(flags, ImGuiTableFlags.ScrollX) ~= 0) and s.inner_width_with_scroll or 0.0
        if ImGui.BeginTable("table_advanced", 6, flags, s.outer_size_enabled and s.outer_size_value or ImVec2(0, 0), inner_width_to_use) then
            -- Declare columns
            -- We use the "user_id" parameter of TableSetupColumn() to specify a user id that will be stored in the sort specifications.
            -- This is so our sort function can identify a column given our own identifier. We could also identify them based on their index!
            ImGui.TableSetupColumn("ID",           bit32.bor(columns_base_flags, ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.WidthFixed, ImGuiTableColumnFlags.NoHide), 0.0, MyItemColumnID_ID)
            ImGui.TableSetupColumn("Name",         bit32.bor(columns_base_flags, ImGuiTableColumnFlags.WidthFixed), 0.0, MyItemColumnID_Name)
            ImGui.TableSetupColumn("Action",       bit32.bor(columns_base_flags, ImGuiTableColumnFlags.NoSort, ImGuiTableColumnFlags.WidthFixed), 0.0, MyItemColumnID_Action)
            ImGui.TableSetupColumn("Quantity",     bit32.bor(columns_base_flags, ImGuiTableColumnFlags.PreferSortDescending), 0.0, MyItemColumnID_Quantity)
            ImGui.TableSetupColumn("Description",  bit32.bor(columns_base_flags, (bit32.band(flags, ImGuiTableFlags.NoHostExtendX) ~= 0) and 0 or ImGuiTableColumnFlags.WidthStretch), 0.0, MyItemColumnID_Description)
            ImGui.TableSetupColumn("Hidden",       bit32.bor(columns_base_flags,  ImGuiTableColumnFlags.DefaultHide, ImGuiTableColumnFlags.NoSort))
            ImGui.TableSetupScrollFreeze(s.freeze_cols, s.freeze_rows)

            -- Sort our data if sort specs have been changed!
            local sort_specs = ImGui.TableGetSortSpecs()
            if sort_specs and sort_specs.SpecsDirty then
                s.items_need_sort = true
            end
            if sort_specs and s.items_need_sort and items.Size > 1 then
                MyItem_SortWithSortSpecs(sort_specs, items.Data, items.Size)
                sort_specs.SpecsDirty = false
            end
            s.items_need_sort = false

            -- Take note of whether we are currently sorting based on the Quantity field,
            -- we will use this to trigger sorting when we know the data of this column has been modified.
            local sorts_specs_using_quantity = bit32.band(ImGui.TableGetColumnFlags(3), ImGuiTableColumnFlags.IsSorted) ~= 0

            -- Show headers
            if s.show_headers and bit32.band(columns_base_flags, ImGuiTableColumnFlags.AngledHeader) ~= 0 then
                ImGui.TableAngledHeadersRow()
            end
            if s.show_headers then
                ImGui.TableHeadersRow()
            end

            -- Show data
            -- FIXME-TABLE FIXME-NAV: How we can get decent up/down even though we have the buttons here?
            -- Demonstrate using clipper for large vertical lists
            local clipper = ImGuiListClipper()
            clipper:Begin(items.Size)
            while clipper:Step() do
                for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                    local item = items.Data[row_n + 1]
                    --if not filter:PassFilter(item.Name) then
                    --    continue

                    local item_is_selected = selection:contains(item.ID)
                    ImGui.PushID(item.ID)
                    ImGui.TableNextRow(ImGuiTableRowFlags.None, s.row_min_height)

                    -- For the demo purpose we can select among different type of items submitted in the first column
                    ImGui.TableSetColumnIndex(0)
                    local label = string.format("%04d", item.ID)
                    local contents_type = s.contents_type
                    if contents_type == CT_Text then
                        ImGui.TextUnformatted(label)
                    elseif contents_type == CT_Button then
                        ImGui.Button(label)
                    elseif contents_type == CT_SmallButton then
                        ImGui.SmallButton(label)
                    elseif contents_type == CT_FillButton then
                        ImGui.Button(label, ImVec2(-FLT_MIN, 0.0))
                    elseif contents_type == CT_Selectable or contents_type == CT_SelectableSpanRow then
                        local selectable_flags = (contents_type == CT_SelectableSpanRow) and bit32.bor(ImGuiSelectableFlags.SpanAllColumns, ImGuiSelectableFlags.AllowOverlap) or ImGuiSelectableFlags.None
                        if ImGui.Selectable(label, item_is_selected, selectable_flags, ImVec2(0, s.row_min_height)) then
                            if ImGui.GetIO().KeyCtrl then
                                if item_is_selected then
                                    selection:find_erase_unsorted(item.ID)
                                else
                                    selection:push_back(item.ID)
                                end
                            else
                                selection:clear()
                                selection:push_back(item.ID)
                            end
                        end
                    end

                    if ImGui.TableSetColumnIndex(1) then
                        ImGui.TextUnformatted(item.Name)
                    end

                    -- Here we demonstrate marking our data set as needing to be sorted again if we modified a quantity,
                    -- and we are currently sorting on the column showing the Quantity.
                    -- To avoid triggering a sort while holding the button, we only trigger it when the button has been released.
                    -- You will probably need some extra logic if you want to automatically sort when a specific entry changes.
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
        ImGui.TreePop()
    end

    ImGui.PopID()

    DemoWindowColumns()

    if s.disable_indent then
        ImGui.PopStyleVar()
    end
end

S.DemoWindowColumns = {
    selected = -1,
    h_borders = true,
    v_borders = true,
    columns_count = 4,
    foo = 1.0,
    bar = 1.0,
}
function DemoWindowColumns()
    local s = S.DemoWindowColumns
    local open = ImGui.TreeNode("Legacy Columns API")
    ImGui.SameLine()
    HelpMarker("Columns() is an old API! Prefer using the more flexible and powerful BeginTable() API!")
    if not open then
        return
    end

    -- Basic columns
    if ImGui.TreeNode("Basic") then
        IMGUI_DEMO_MARKER("Columns (legacy API)/Basic")
        ImGui.Text("Without border:")
        ImGui.Columns(3, "mycolumns3", false)  -- 3-ways, no border
        ImGui.Separator()
        for n = 0, 13 do
            local label = string.format("Item %d", n)
            if ImGui.Selectable(label) then end
            --if (ImGui.Button(label, ImVec2(-FLT_MIN,0.0))) {}
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
            if ImGui.Selectable(label, s.selected == i, ImGuiSelectableFlags.SpanAllColumns) then
                s.selected = i
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
        s.columns_count = ImGui.DragInt("##columns_count", s.columns_count, 0.1, 2, 10, "%d columns")
        if s.columns_count < 2 then
            s.columns_count = 2
        end
        ImGui.SameLine()
        _, s.h_borders = ImGui.Checkbox("horizontal", s.h_borders)
        ImGui.SameLine()
        _, s.v_borders = ImGui.Checkbox("vertical", s.v_borders)
        ImGui.Columns(s.columns_count, nil, s.v_borders)
        for i = 0, s.columns_count * lines_count - 1 do
            if s.h_borders and ImGui.GetColumnIndex() == 0 then
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
        if s.h_borders then
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
        s.foo = ImGui.InputFloat("red", s.foo, 0.05, 0, "%.3f")
        ImGui.Text("An extra line here.")
        ImGui.NextColumn()

        ImGui.Text("Sailor")
        ImGui.Button("Corniflower")
        s.bar = ImGui.InputFloat("blue", s.bar, 0.05, 0, "%.3f")
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

-------------------------------------------------------------------------------
-- [SECTION] DemoWindowInputs()
-------------------------------------------------------------------------------

S.DemoWindowInputs = {
    funcs = { IsLegacyNativeDupe = function(key) return false end }, -- struct funcs (hoisted to avoid a per-frame closure) -- [Port]
    capture_override_mouse = -1,
    capture_override_keyboard = -1,
    route_options = ImGuiInputFlags.Repeat,
    route_type = ImGuiInputFlags.RouteFocused,
    f = 0.5,
    tabbing_buf = ImGui.NewTextBuffer("hello", 32),
    focus_buf = ImGui.NewTextBuffer("click on a button to set focus", 128),
    f3 = { 0.0, 0.0, 0.0 },
}
S.DemoWindowInputs.mouse_cursors_names = { "Arrow", "TextInput", "ResizeAll", "ResizeNS", "ResizeEW", "ResizeNESW", "ResizeNWSE", "Hand", "Wait", "Progress", "NotAllowed" }
function DemoWindowInputs()
    local s = S.DemoWindowInputs
    if ImGui.CollapsingHeader("Inputs & Focus") then
        local io = ImGui.GetIO()

        -- Display inputs submitted to ImGuiIO
        ImGui.SetNextItemOpen(true, ImGuiCond.Once)
        local inputs_opened = ImGui.TreeNode("Inputs")
        ImGui.SameLine()
        HelpMarker(
            "This is a simplified view. See more detailed input state:\n" ..
            "- in 'Tools->Metrics/Debugger->Inputs'.\n" ..
            "- in 'Tools->Debug Log->IO'.")
        if inputs_opened then
            IMGUI_DEMO_MARKER("Inputs & Focus/Inputs")
            if ImGui.IsMousePosValid() then
                ImGui.Text("Mouse pos: (%g, %g)", io.MousePos.x, io.MousePos.y)
            else
                ImGui.Text("Mouse pos: <INVALID>")
            end
            ImGui.Text("Mouse delta: (%g, %g)", io.MouseDelta.x, io.MouseDelta.y)
            ImGui.Text("Mouse down:")
            for i = 0, 2 do if ImGui.IsMouseDown(i) then ImGui.SameLine(); ImGui.Text("b%d (%.02f secs)", i, io.MouseDownDuration[i]) end end -- IM_COUNTOF(io.MouseDown) == 3, 0-based
            ImGui.Text("Mouse wheel: %.1f", io.MouseWheel)
            ImGui.Text("Mouse clicked count:")
            for i = 0, 2 do if io.MouseClickedCount[i] > 0 then ImGui.SameLine(); ImGui.Text("b%d: %d", i, io.MouseClickedCount[i]) end end

            -- We iterate both legacy native range and named ImGuiKey ranges. This is a little unusual/odd but this allows
            -- displaying the data for old/new backends.
            -- User code should never have to go through such hoops!
            -- You can generally iterate between ImGuiKey.NamedKey_BEGIN and ImGuiKey.NamedKey_END.
            local funcs = s.funcs
            local start_key = ImGuiKey.NamedKey_BEGIN
            ImGui.Text("Keys down:")         for key = start_key, ImGuiKey.NamedKey_END - 1 do repeat if funcs.IsLegacyNativeDupe(key) or not ImGui.IsKeyDown(key) then break end ImGui.SameLine(); if key < ImGuiKey.NamedKey_BEGIN then ImGui.Text("\"%s\"", ImGui.GetKeyName(key)) else ImGui.Text("\"%s\" %d", ImGui.GetKeyName(key), key) end until true end
            ImGui.Text("Keys mods: %s%s%s%s", io.KeyCtrl and "CTRL " or "", io.KeyShift and "SHIFT " or "", io.KeyAlt and "ALT " or "", io.KeySuper and "SUPER " or "")
            ImGui.Text("Chars queue:")       for i = 0, io.InputQueueCharacters.Size - 1 do local c = io.InputQueueCharacters.Data[i + 1]; ImGui.SameLine();  ImGui.Text("\'%s\' (0x%04X)", (c > 32 and c <= 255) and string.char(c) or '?', c) end -- FIXME: We should convert 'c' to UTF-8 here but the functions are not public.

            ImGui.TreePop()
        end

        -- Display ImGuiIO output flags
        ImGui.SetNextItemOpen(true, ImGuiCond.Once)
        local outputs_opened = ImGui.TreeNode("Outputs")
        ImGui.SameLine()
        HelpMarker(
            "The value of io.WantCaptureMouse and io.WantCaptureKeyboard are normally set by Dear ImGui " ..
            "to instruct your application of how to route inputs. Typically, when a value is true, it means " ..
            "Dear ImGui wants the corresponding inputs and we expect the underlying application to ignore them.\n\n" ..
            "The most typical case is: when hovering a window, Dear ImGui set io.WantCaptureMouse to true, " ..
            "and underlying application should ignore mouse inputs (in practice there are many and more subtle " ..
            "rules leading to how those flags are set).")
        if outputs_opened then
            IMGUI_DEMO_MARKER("Inputs & Focus/Outputs")
            ImGui.Text("io.WantCaptureMouse: %d", io.WantCaptureMouse and 1 or 0)
            ImGui.Text("io.WantCaptureMouseUnlessPopupClose: %d", io.WantCaptureMouseUnlessPopupClose and 1 or 0)
            ImGui.Text("io.WantCaptureKeyboard: %d", io.WantCaptureKeyboard and 1 or 0)
            ImGui.Text("io.WantTextInput: %d", io.WantTextInput and 1 or 0)
            ImGui.Text("io.WantSetMousePos: %d", io.WantSetMousePos and 1 or 0)
            ImGui.Text("io.NavActive: %d, io.NavVisible: %d", io.NavActive and 1 or 0, io.NavVisible and 1 or 0)

            IMGUI_DEMO_MARKER("Inputs & Focus/Outputs/WantCapture override")
            if ImGui.TreeNode("WantCapture override") then
                HelpMarker(
                    "Hovering the colored canvas will override io.WantCaptureXXX fields.\n" ..
                    "Notice how normally (when set to none), the value of io.WantCaptureKeyboard would be false when hovering " ..
                    "and true when clicking.")
                local capture_override_desc = { "None", "Set to false", "Set to true" }
                ImGui.SetNextItemWidth(ImGui.GetFontSize() * 15)
                s.capture_override_mouse = ImGui.SliderInt("SetNextFrameWantCaptureMouse() on hover", s.capture_override_mouse, -1, 1, capture_override_desc[s.capture_override_mouse + 2], ImGuiSliderFlags.AlwaysClamp)
                ImGui.SetNextItemWidth(ImGui.GetFontSize() * 15)
                s.capture_override_keyboard = ImGui.SliderInt("SetNextFrameWantCaptureKeyboard() on hover", s.capture_override_keyboard, -1, 1, capture_override_desc[s.capture_override_keyboard + 2], ImGuiSliderFlags.AlwaysClamp)

                ImGui.ColorButton("##panel", ImVec4(0.7, 0.1, 0.7, 1.0), bit32.bor(ImGuiColorEditFlags.NoTooltip, ImGuiColorEditFlags.NoDragDrop), ImVec2(128.0, 96.0)) -- Dummy item
                if ImGui.IsItemHovered() and s.capture_override_mouse ~= -1 then
                    ImGui.SetNextFrameWantCaptureMouse(s.capture_override_mouse == 1)
                end
                if ImGui.IsItemHovered() and s.capture_override_keyboard ~= -1 then
                    ImGui.SetNextFrameWantCaptureKeyboard(s.capture_override_keyboard == 1)
                end

                ImGui.TreePop()
            end
            ImGui.TreePop()
        end

        -- Demonstrate using Shortcut() and Routing Policies.
        -- The general flow is:
        -- - Code interested in a chord (e.g. "Ctrl+A") declares their intent.
        -- - Multiple locations may be interested in same chord! Routing helps find a winner.
        -- - Every frame, we resolve all claims and assign one owner if the modifiers are matching.
        -- - The lower-level function is 'bool SetShortcutRouting()', returns true when caller got the route.
        -- - Most of the times, SetShortcutRouting() is not called directly. User mostly calls Shortcut() with routing flags.
        -- - If you call Shortcut() WITHOUT any routing option, it uses ImGuiInputFlags.RouteFocused.
        -- TL;DR: Most uses will simply be:
        -- - Shortcut(ImGuiMod_Ctrl | ImGuiKey.A); -- Use ImGuiInputFlags.RouteFocused policy.
        if ImGui.TreeNode("Shortcuts") then
            IMGUI_DEMO_MARKER("Inputs & Focus/Shortcuts")
            _, s.route_options = ImGui.CheckboxFlags("ImGuiInputFlags_Repeat", s.route_options, ImGuiInputFlags.Repeat)
            _, s.route_type = ImGui.RadioButton("ImGuiInputFlags_RouteActive", s.route_type, ImGuiInputFlags.RouteActive)
            _, s.route_type = ImGui.RadioButton("ImGuiInputFlags_RouteFocused (default)", s.route_type, ImGuiInputFlags.RouteFocused)
            ImGui.Indent()
            ImGui.BeginDisabled(s.route_type ~= ImGuiInputFlags.RouteFocused)
            _, s.route_options = ImGui.CheckboxFlags("ImGuiInputFlags_RouteOverActive##0", s.route_options, ImGuiInputFlags.RouteOverActive)
            ImGui.EndDisabled()
            ImGui.Unindent()
            _, s.route_type = ImGui.RadioButton("ImGuiInputFlags_RouteGlobal", s.route_type, ImGuiInputFlags.RouteGlobal)
            ImGui.Indent()
            ImGui.BeginDisabled(s.route_type ~= ImGuiInputFlags.RouteGlobal)
            _, s.route_options = ImGui.CheckboxFlags("ImGuiInputFlags_RouteOverFocused", s.route_options, ImGuiInputFlags.RouteOverFocused)
            _, s.route_options = ImGui.CheckboxFlags("ImGuiInputFlags_RouteOverActive", s.route_options, ImGuiInputFlags.RouteOverActive)
            _, s.route_options = ImGui.CheckboxFlags("ImGuiInputFlags_RouteUnlessBgFocused", s.route_options, ImGuiInputFlags.RouteUnlessBgFocused)
            ImGui.EndDisabled()
            ImGui.Unindent()
            _, s.route_type = ImGui.RadioButton("ImGuiInputFlags_RouteAlways", s.route_type, ImGuiInputFlags.RouteAlways)
            local flags = bit32.bor(s.route_type, s.route_options) -- Merged flags
            if s.route_type ~= ImGuiInputFlags.RouteGlobal then
                flags = bit32.band(flags, bit32.bnot(bit32.bor(ImGuiInputFlags.RouteOverFocused, ImGuiInputFlags.RouteOverActive, ImGuiInputFlags.RouteUnlessBgFocused)))
            end

            ImGui.SeparatorText("Using SetNextItemShortcut()")
            ImGui.Text("Ctrl+S")
            ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.S), bit32.bor(flags, ImGuiInputFlags.Tooltip))
            ImGui.Button("Save")
            ImGui.Text("Alt+F")
            ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Alt, ImGuiKey.F), bit32.bor(flags, ImGuiInputFlags.Tooltip))
            s.f = ImGui.SliderFloat("Factor", s.f, 0.0, 1.0)

            ImGui.SeparatorText("Using Shortcut()")
            local line_height = ImGui.GetTextLineHeightWithSpacing()
            local key_chord = bit32.bor(ImGuiMod_Ctrl, ImGuiKey.A)

            ImGui.Text("Ctrl+A")
            ImGui.Text("IsWindowFocused: %d, Shortcut: %s", ImGui.IsWindowFocused() and 1 or 0, ImGui.Shortcut(key_chord, flags) and "PRESSED" or "...")

            ImGui.PushStyleColor(ImGuiCol.ChildBg, ImVec4(1.0, 0.0, 1.0, 0.1))

            ImGui.BeginChild("WindowA", ImVec2(-FLT_MIN, line_height * 14), true)
            ImGui.Text("Press Ctrl+A and see who receives it!")
            ImGui.Separator()

            -- 1: Window polling for Ctrl+A
            ImGui.Text("(in WindowA)")
            ImGui.Text("IsWindowFocused: %d, Shortcut: %s", ImGui.IsWindowFocused() and 1 or 0, ImGui.Shortcut(key_chord, flags) and "PRESSED" or "...")

            -- 2: InputText also polling for Ctrl+A: it always uses _RouteFocused internally (gets priority when active)
            -- (Commented because the owner-aware version of Shortcut() is still in imgui_internal.h)
            --char str[16] = "Press Ctrl+A";
            --ImGui.Spacing();
            --ImGui.InputText("InputTextB", str, IM_COUNTOF(str), ImGuiInputTextFlags.ReadOnly);
            --ImGuiID item_id = ImGui.GetItemID();
            --ImGui.SameLine(); HelpMarker("Internal widgets always use _RouteFocused");
            --ImGui.Text("IsWindowFocused: %d, Shortcut: %s", ImGui.IsWindowFocused(), ImGui.Shortcut(key_chord, flags, item_id) ? "PRESSED" : "...");

            -- 3: Dummy child is not claiming the route: focusing them shouldn't steal route away from WindowA
            ImGui.BeginChild("ChildD", ImVec2(-FLT_MIN, line_height * 4), true)
            ImGui.Text("(in ChildD: not using same Shortcut)")
            ImGui.Text("IsWindowFocused: %d", ImGui.IsWindowFocused() and 1 or 0)
            ImGui.EndChild()

            -- 4: Child window polling for Ctrl+A. It is deeper than WindowA and gets priority when focused.
            ImGui.BeginChild("ChildE", ImVec2(-FLT_MIN, line_height * 4), true)
            ImGui.Text("(in ChildE: using same Shortcut)")
            ImGui.Text("IsWindowFocused: %d, Shortcut: %s", ImGui.IsWindowFocused() and 1 or 0, ImGui.Shortcut(key_chord, flags) and "PRESSED" or "...")
            ImGui.EndChild()

            -- 5: In a popup
            if ImGui.Button("Open Popup") then
                ImGui.OpenPopup("PopupF")
            end
            if ImGui.BeginPopup("PopupF") then
                ImGui.Text("(in PopupF)")
                ImGui.Text("IsWindowFocused: %d, Shortcut: %s", ImGui.IsWindowFocused() and 1 or 0, ImGui.Shortcut(key_chord, flags) and "PRESSED" or "...")
                -- (Commented because the owner-aware version of Shortcut() is still in imgui_internal.h)
                --ImGui.InputText("InputTextG", str, IM_COUNTOF(str), ImGuiInputTextFlags.ReadOnly);
                --ImGui.Text("IsWindowFocused: %d, Shortcut: %s", ImGui.IsWindowFocused(), ImGui.Shortcut(key_chord, flags, ImGui.GetItemID()) ? "PRESSED" : "...");
                ImGui.EndPopup()
            end
            ImGui.EndChild()
            ImGui.PopStyleColor()

            ImGui.TreePop()
        end

        -- Display mouse cursors
        if ImGui.TreeNode("Mouse Cursors") then
            IMGUI_DEMO_MARKER("Inputs & Focus/Mouse Cursors")
            local mouse_cursors_names = s.mouse_cursors_names -- 1-based
            IM_ASSERT(#mouse_cursors_names == ImGuiMouseCursor.COUNT)

            local current = ImGui.GetMouseCursor()
            local cursor_name = "N/A"
            if (current >= ImGuiMouseCursor.Arrow) and (current < ImGuiMouseCursor.COUNT) then cursor_name = mouse_cursors_names[current + 1] end
            ImGui.Text("Current mouse cursor = %d: %s", current, cursor_name)
            ImGui.BeginDisabled(true)
            _, io.BackendFlags = ImGui.CheckboxFlags("io.BackendFlags: HasMouseCursors", io.BackendFlags, ImGuiBackendFlags.HasMouseCursors)
            ImGui.EndDisabled()

            ImGui.Text("Hover to see mouse cursors:")
            ImGui.SameLine(); HelpMarker(
                "Your application can render a different mouse cursor based on what ImGui::GetMouseCursor() returns. " ..
                "If software cursor rendering (io.MouseDrawCursor) is set ImGui will draw the right cursor for you, " ..
                "otherwise your backend needs to handle it.")
            for i = 0, ImGuiMouseCursor.COUNT - 1 do
                local label = string.format("Mouse cursor %d: %s", i, mouse_cursors_names[i + 1])
                ImGui.Bullet(); ImGui.Selectable(label, false)
                if ImGui.IsItemHovered() then
                    ImGui.SetMouseCursor(i)
                end
            end
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Tabbing") then
            IMGUI_DEMO_MARKER("Inputs & Focus/Tabbing")
            ImGui.Text("Use Tab/Shift+Tab to cycle through keyboard editable fields.")
            local buf = s.tabbing_buf
            ImGui.InputText("1", buf, 32)
            ImGui.InputText("2", buf, 32)
            ImGui.InputText("3", buf, 32)
            ImGui.PushItemFlag(ImGuiItemFlags.NoTabStop, true)
            ImGui.InputText("4 (tab skip)", buf, 32)
            ImGui.SameLine(); HelpMarker("Item won't be cycled through when using TAB or Shift+Tab.")
            ImGui.PopItemFlag()
            ImGui.InputText("5", buf, 32)
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Focus from code") then
            IMGUI_DEMO_MARKER("Inputs & Focus/Focus from code")
            local focus_1 = ImGui.Button("Focus on 1"); ImGui.SameLine()
            local focus_2 = ImGui.Button("Focus on 2"); ImGui.SameLine()
            local focus_3 = ImGui.Button("Focus on 3")
            local has_focus = 0
            local buf = s.focus_buf

            if focus_1 then ImGui.SetKeyboardFocusHere() end
            ImGui.InputText("1", buf, 128)
            if ImGui.IsItemActive() then has_focus = 1 end

            if focus_2 then ImGui.SetKeyboardFocusHere() end
            ImGui.InputText("2", buf, 128)
            if ImGui.IsItemActive() then has_focus = 2 end

            ImGui.PushItemFlag(ImGuiItemFlags.NoTabStop, true)
            if focus_3 then ImGui.SetKeyboardFocusHere() end
            ImGui.InputText("3 (tab skip)", buf, 128)
            if ImGui.IsItemActive() then has_focus = 3 end
            ImGui.SameLine(); HelpMarker("Item won't be cycled through when using TAB or Shift+Tab.")
            ImGui.PopItemFlag()

            if has_focus ~= 0 then
                ImGui.Text("Item with focus: %d", has_focus)
            else
                ImGui.Text("Item with focus: <none>")
            end

            -- Use >= 0 parameter to SetKeyboardFocusHere() to focus an upcoming item
            local f3 = s.f3
            local focus_ahead = -1
            if ImGui.Button("Focus on X") then focus_ahead = 0 end ImGui.SameLine()
            if ImGui.Button("Focus on Y") then focus_ahead = 1 end ImGui.SameLine()
            if ImGui.Button("Focus on Z") then focus_ahead = 2 end
            if focus_ahead ~= -1 then ImGui.SetKeyboardFocusHere(focus_ahead) end
            ImGui.SliderFloat3("Float3", f3, 0.0, 1.0)

            ImGui.TextWrapped("NB: Cursor & selection are preserved when refocusing last used item in code.")
            ImGui.TreePop()
        end

        if ImGui.TreeNode("Dragging") then
            IMGUI_DEMO_MARKER("Inputs & Focus/Dragging")
            ImGui.TextWrapped("You can use ImGui::GetMouseDragDelta(0) to query for the dragged amount on any widget.")
            for button = 0, 2 do
                ImGui.Text("IsMouseDragging(%d):", button)
                ImGui.Text("  w/ default threshold: %d,", ImGui.IsMouseDragging(button) and 1 or 0)
                ImGui.Text("  w/ zero threshold: %d,", ImGui.IsMouseDragging(button, 0.0) and 1 or 0)
                ImGui.Text("  w/ large threshold: %d,", ImGui.IsMouseDragging(button, 20.0) and 1 or 0)
            end

            ImGui.Button("Drag Me")
            if ImGui.IsItemActive() then
                ImGui.GetForegroundDrawList():AddLine(io.MouseClickedPos[0], io.MousePos, ImGui.GetColorU32(ImGuiCol.Button), 4.0) -- Draw a line between the button and the mouse cursor
            end

            -- Drag operations gets "unlocked" when the mouse has moved past a certain threshold
            -- (the default threshold is stored in io.MouseDragThreshold). You can request a lower or higher
            -- threshold using the second parameter of IsMouseDragging() and GetMouseDragDelta().
            local value_raw = ImGui.GetMouseDragDelta(0, 0.0)
            local value_with_lock_threshold = ImGui.GetMouseDragDelta(0)
            local mouse_delta = io.MouseDelta
            ImGui.Text("GetMouseDragDelta(0):")
            ImGui.Text("  w/ default threshold: (%.1f, %.1f)", value_with_lock_threshold.x, value_with_lock_threshold.y)
            ImGui.Text("  w/ zero threshold: (%.1f, %.1f)", value_raw.x, value_raw.y)
            ImGui.Text("io.MouseDelta: (%.1f, %.1f)", mouse_delta.x, mouse_delta.y)
            ImGui.TreePop()
        end
    end
end

-------------------------------------------------------------------------------
-- [SECTION] About Window / ShowAboutWindow()
-- Access from Dear ImGui Demo -> Tools -> About
-------------------------------------------------------------------------------

S.ShowAboutWindow = {
    show_config_info = false,
}
function ImGui.ShowAboutWindow(p_open)
    local s = S.ShowAboutWindow
    local _, visible
    p_open, visible = ImGui.Begin("About Dear ImGui", p_open, ImGuiWindowFlags.AlwaysAutoResize)
    if not visible then
        ImGui.End()
        return p_open
    end
    IMGUI_DEMO_MARKER("Tools/About Dear ImGui")
    ImGui.Text("Dear ImGui %s (%d)", IMGUI_VERSION, IMGUI_VERSION_NUM)

    ImGui.TextLinkOpenURL("Homepage", "https://github.com/ocornut/imgui")
    ImGui.SameLine()
    ImGui.TextLinkOpenURL("FAQ", "https://github.com/ocornut/imgui/blob/master/docs/FAQ.md")
    ImGui.SameLine()
    ImGui.TextLinkOpenURL("Wiki", "https://github.com/ocornut/imgui/wiki")
    ImGui.SameLine()
    ImGui.TextLinkOpenURL("Extensions", "https://github.com/ocornut/imgui/wiki/Useful-Extensions")
    ImGui.SameLine()
    ImGui.TextLinkOpenURL("Releases", "https://github.com/ocornut/imgui/releases")
    ImGui.SameLine()
    ImGui.TextLinkOpenURL("Funding", "https://github.com/ocornut/imgui/wiki/Funding")

    ImGui.Separator()
    ImGui.Text("(c) 2014-2026 Omar Cornut")
    ImGui.Text("Developed by Omar Cornut and all Dear ImGui contributors.")
    ImGui.Text("Dear ImGui is licensed under the MIT License, see LICENSE for more information.")
    ImGui.Text("If your company uses this, please consider funding the project.")

    _, s.show_config_info = ImGui.Checkbox("Config/Build Information", s.show_config_info)
    if s.show_config_info then
        local io = ImGui.GetIO()
        local style = ImGui.GetStyle()

        local copy_to_clipboard = ImGui.Button("Copy to clipboard")
        local child_size = ImVec2(0, ImGui.GetTextLineHeightWithSpacing() * 18)
        ImGui.BeginChild(ImGui.GetID("cfg_infos"), child_size, ImGuiChildFlags.FrameStyle)
        if copy_to_clipboard then
            ImGui.LogToClipboard()
            ImGui.LogText("// (Copy from the next line. Keep the ``` markers for formatting.)\n")
            ImGui.LogText("```cpp\n") -- Back quotes will make text appears without formatting when pasting on GitHub
        end

        ImGui.Text("Dear ImGui %s (%d)", IMGUI_VERSION, IMGUI_VERSION_NUM)
        ImGui.Separator()
        -- [Port] no sizeof()/__cplusplus/compiler/OS #defines in Lua: report the Lua runtime instead
        ImGui.Text("runtime: %s", tostring(_VERSION))
        ImGui.Text("define: IMGUI_HAS_VIEWPORT")
        ImGui.Text("define: IMGUI_HAS_DOCK")

        -- Heuristic to detect no-op IM_ASSERT() macros
        -- - This is designed so people opening bug reports would convey and notice that they have disabled asserts for Dear ImGui code.
        -- - 16 is > strlen("((void)(_EXPR))") which we suggested in our imconfig.h template as a possible way to disable.
        local assert_runs_expression = 0
        IM_ASSERT((function() assert_runs_expression = assert_runs_expression + 1; return assert_runs_expression end)()) -- [Port] no ++ in expressions
        local assert_expand_len = 17 -- [Port] IM_ASSERT is a function, not a macro: nothing to stringify, it cannot be expanded to a no-op
        local assert_maybe_disabled = (assert_runs_expression == 0 or assert_expand_len <= 16)
        ImGui.Text("IM_ASSERT: runs expression: %s. expand size: %s%s",
            (assert_runs_expression ~= 0) and "OK" or "KO", (assert_expand_len > 16) and "OK" or "KO", assert_maybe_disabled and " (MAYBE DISABLED?!)" or "")
        if assert_maybe_disabled then
            ImGui.SameLine()
            HelpMarker("IM_ASSERT() calls assert() by default. Compiling with NDEBUG will usually strip out assert() to nothing, which is NOT recommended because we use asserts to notify of programmer mistakes!")
        end

        ImGui.Separator()
        ImGui.Text("io.BackendPlatformName: %s", io.BackendPlatformName or "NULL")
        ImGui.Text("io.BackendRendererName: %s", io.BackendRendererName or "NULL")
        ImGui.Text("io.ConfigFlags: 0x%08X", io.ConfigFlags)
        if bit32.band(io.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard) ~= 0        then ImGui.Text(" NavEnableKeyboard") end
        if bit32.band(io.ConfigFlags, ImGuiConfigFlags.NavEnableGamepad) ~= 0         then ImGui.Text(" NavEnableGamepad") end
        if bit32.band(io.ConfigFlags, ImGuiConfigFlags.NoMouse) ~= 0                  then ImGui.Text(" NoMouse") end
        if bit32.band(io.ConfigFlags, ImGuiConfigFlags.NoMouseCursorChange) ~= 0      then ImGui.Text(" NoMouseCursorChange") end
        if bit32.band(io.ConfigFlags, ImGuiConfigFlags.NoKeyboard) ~= 0               then ImGui.Text(" NoKeyboard") end
        if bit32.band(io.ConfigFlags, ImGuiConfigFlags.DockingEnable) ~= 0            then ImGui.Text(" DockingEnable") end
        if bit32.band(io.ConfigFlags, ImGuiConfigFlags.ViewportsEnable) ~= 0          then ImGui.Text(" ViewportsEnable") end
        if io.MouseDrawCursor                                                         then ImGui.Text("io.MouseDrawCursor") end
        if io.ConfigDpiScaleFonts                                                     then ImGui.Text("io.ConfigDpiScaleFonts") end
        if io.ConfigDpiScaleViewports                                                 then ImGui.Text("io.ConfigDpiScaleViewports") end
        if io.ConfigViewportsNoAutoMerge                                              then ImGui.Text("io.ConfigViewportsNoAutoMerge") end
        if io.ConfigViewportsNoTaskBarIcon                                            then ImGui.Text("io.ConfigViewportsNoTaskBarIcon") end
        if io.ConfigViewportsNoDecoration                                             then ImGui.Text("io.ConfigViewportsNoDecoration") end
        if io.ConfigViewportsNoDefaultParent                                          then ImGui.Text("io.ConfigViewportsNoDefaultParent") end
        if io.ConfigDockingNoSplit                                                    then ImGui.Text("io.ConfigDockingNoSplit") end
        if io.ConfigDockingNoDockingOver                                              then ImGui.Text("io.ConfigDockingNoDockingOver") end
        if io.ConfigDockingWithShift                                                  then ImGui.Text("io.ConfigDockingWithShift") end
        if io.ConfigDockingAlwaysTabBar                                               then ImGui.Text("io.ConfigDockingAlwaysTabBar") end
        if io.ConfigDockingTransparentPayload                                         then ImGui.Text("io.ConfigDockingTransparentPayload") end
        if io.ConfigMacOSXBehaviors                                                   then ImGui.Text("io.ConfigMacOSXBehaviors") end
        if io.ConfigNavMoveSetMousePos                                                then ImGui.Text("io.ConfigNavMoveSetMousePos") end
        if io.ConfigNavCaptureKeyboard                                                then ImGui.Text("io.ConfigNavCaptureKeyboard") end
        if io.ConfigInputTextCursorBlink                                              then ImGui.Text("io.ConfigInputTextCursorBlink") end
        if io.ConfigWindowsResizeFromEdges                                            then ImGui.Text("io.ConfigWindowsResizeFromEdges") end
        if io.ConfigWindowsMoveFromTitleBarOnly                                       then ImGui.Text("io.ConfigWindowsMoveFromTitleBarOnly") end
        if io.ConfigMemoryCompactTimer >= 0.0                                         then ImGui.Text("io.ConfigMemoryCompactTimer = %.1f", io.ConfigMemoryCompactTimer) end
        ImGui.Text("io.BackendFlags: 0x%08X", io.BackendFlags)
        if bit32.band(io.BackendFlags, ImGuiBackendFlags.HasGamepad) ~= 0             then ImGui.Text(" HasGamepad") end
        if bit32.band(io.BackendFlags, ImGuiBackendFlags.HasMouseCursors) ~= 0        then ImGui.Text(" HasMouseCursors") end
        if bit32.band(io.BackendFlags, ImGuiBackendFlags.HasSetMousePos) ~= 0         then ImGui.Text(" HasSetMousePos") end
        if bit32.band(io.BackendFlags, ImGuiBackendFlags.PlatformHasViewports) ~= 0   then ImGui.Text(" PlatformHasViewports") end
        if bit32.band(io.BackendFlags, ImGuiBackendFlags.HasMouseHoveredViewport) ~= 0 then ImGui.Text(" HasMouseHoveredViewport") end
        if bit32.band(io.BackendFlags, ImGuiBackendFlags.HasParentViewport) ~= 0      then ImGui.Text(" HasParentViewport") end
        if bit32.band(io.BackendFlags, ImGuiBackendFlags.RendererHasVtxOffset) ~= 0   then ImGui.Text(" RendererHasVtxOffset") end
        if bit32.band(io.BackendFlags, ImGuiBackendFlags.RendererHasTextures) ~= 0    then ImGui.Text(" RendererHasTextures") end
        if bit32.band(io.BackendFlags, ImGuiBackendFlags.RendererHasViewports) ~= 0   then ImGui.Text(" RendererHasViewports") end
        ImGui.Separator()
        ImGui.Text("io.Fonts: %d fonts, Flags: 0x%08X, TexSize: %d,%d", io.Fonts.Fonts.Size, io.Fonts.Flags, io.Fonts.TexData.Width, io.Fonts.TexData.Height)
        ImGui.Text("io.Fonts->FontLoaderName: %s", io.Fonts.FontLoaderName or "NULL")
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

-------------------------------------------------------------------------------
-- [SECTION] Style Editor / ShowStyleEditor()
-------------------------------------------------------------------------------
-- - ShowStyleSelector()
-- - ShowStyleEditor()
-------------------------------------------------------------------------------

-- [Port] C++ copies ImGuiStyle by value (`dst = src`). Copy fields in place so ImVec2/ImVec4 objects of `dst` keep
-- their identity (the live style's vectors may be referenced elsewhere) and are never aliased with `src`.
function ImGuiStyle_Copy(dst, src)
    for k, v in pairs(src) do
        if k == "Colors" then
            local dst_colors = dst.Colors
            for i, col in pairs(v) do
                if dst_colors[i] then ImVec4_Copy(dst_colors[i], col) else dst_colors[i] = ImVec4(col.x, col.y, col.z, col.w) end
            end
        elseif type(v) == "table" then -- ImVec2
            if dst[k] then ImVec2_Copy(dst[k], v) else dst[k] = ImVec2(v.x, v.y) end
        else
            dst[k] = v
        end
    end
    return dst
end

S.ShowStyleSelector = {
    style_idx = -1,
}
-- Demo helper function to select among default colors. See ShowStyleEditor() for more advanced options.
function ImGui.ShowStyleSelector(label)
    -- FIXME: This is a bit tricky to get right as style are functions, they don't register a name nor the fact that one is active.
    -- So we keep track of last active one among our limited selection.
    local s = S.ShowStyleSelector
    local style_names = { "Dark", "Light", "Classic" }
    local ret = false
    if ImGui.BeginCombo(label, (s.style_idx >= 0 and s.style_idx < #style_names) and style_names[s.style_idx + 1] or "") then
        for n = 0, #style_names - 1 do
            if ImGui.Selectable(style_names[n + 1], s.style_idx == n, ImGuiSelectableFlags.SelectOnNav) then
                s.style_idx = n
                ret = true
                if s.style_idx == 0 then ImGui.StyleColorsDark()
                elseif s.style_idx == 1 then ImGui.StyleColorsLight()
                elseif s.style_idx == 2 then ImGui.StyleColorsClassic()
                end
            elseif s.style_idx == n then
                ImGui.SetItemDefaultFocus()
            end
        end
        ImGui.EndCombo()
    end
    return ret
end

function GetTreeLinesFlagsName(flags)
    if flags == ImGuiTreeNodeFlags.DrawLinesNone then return "DrawLinesNone" end
    if flags == ImGuiTreeNodeFlags.DrawLinesFull then return "DrawLinesFull" end
    if flags == ImGuiTreeNodeFlags.DrawLinesToNodes then return "DrawLinesToNodes" end
    return ""
end

S.ShowStyleEditor = {
    ref_saved_style = nil, -- static ImGuiStyle ref_saved_style; (created lazily)
    init = true,
    output_dest = 0,
    output_only_modified = true,
    alpha_flags = 0,
    filter = nil, -- static ImGuiTextFilter filter; (created lazily)
}
-- We omit the ImGui:: prefix in this function, as we don't expect user to be copy and pasting this code.
-- [Port] Lua has no `using namespace`: calls keep the ImGui. prefix
function ImGui.ShowStyleEditor(ref)
    local s = S.ShowStyleEditor
    local _, changed
    IMGUI_DEMO_MARKER("Tools/Style Editor")
    -- You can pass in a reference ImGuiStyle structure to compare to, revert to and save to
    -- (without a reference style pointer, we will use one compared locally as a reference)
    local style = ImGui.GetStyle()
    if s.ref_saved_style == nil then s.ref_saved_style = ImGuiStyle() end

    -- Default to using internal storage as reference
    if s.init and ref == nil then
        ImGuiStyle_Copy(s.ref_saved_style, style)
    end
    s.init = false
    if ref == nil then
        ref = s.ref_saved_style
    end

    -- The logic behind dynamically changing 'max_border_size' is to not encourage people to increase border size too much: it'll likely reveal lots of subtle rendering artifacts and this isn't a priority right now.
    -- Note that _MainScale is currently internal PLEASE DO NOT USE IN YOUR CODE.
    local default_border_size = math.floor(style._MainScale)
    local max_border_size = ImMax(default_border_size, 2.0)

    ImGui.PushItemWidth(ImGui.GetWindowWidth() * 0.50)

    do
        -- General
        ImGui.SeparatorText("General")
        if bit32.band(ImGui.GetIO().BackendFlags, ImGuiBackendFlags.RendererHasTextures) == 0 then
            ImGui.BulletText("Warning: Font scaling will NOT be smooth, because\nImGuiBackendFlags_RendererHasTextures is not set!")
            ImGui.BulletText("For instructions, see:")
            ImGui.SameLine()
            ImGui.TextLinkOpenURL("docs/BACKENDS.md", "https://github.com/ocornut/imgui/blob/master/docs/BACKENDS.md")
        end

        if ImGui.ShowStyleSelector("Colors##Selector") then
            ImGuiStyle_Copy(s.ref_saved_style, style)
        end
        ImGui.ShowFontSelector("Fonts##Selector")
        style.FontSizeBase, changed = ImGui.DragFloat("FontSizeBase", style.FontSizeBase, 0.20, 5.0, 100.0, "%.0f")
        if changed then
            style._NextFrameFontSizeBase = style.FontSizeBase -- FIXME: Temporary hack until we finish remaining work.
        end
        ImGui.SameLine(0.0, 0.0); ImGui.Text(" (out %.2f)", ImGui.GetFontSize())
        style.FontScaleMain = ImGui.DragFloat("FontScaleMain", style.FontScaleMain, 0.02, 0.5, 4.0)
        ImGui.BeginDisabled(ImGui.GetIO().ConfigDpiScaleFonts)
        style.FontScaleDpi = ImGui.DragFloat("FontScaleDpi", style.FontScaleDpi, 0.02, 0.5, 4.0)
        ImGui.SetItemTooltip("When io.ConfigDpiScaleFonts is set, this value is automatically overwritten.")
        ImGui.EndDisabled()

        -- Simplified Settings (expose floating-pointer border sizes as boolean representing 0.0f or 1.0f)
        style.FrameRounding, changed = ImGui.SliderFloat("FrameRounding", style.FrameRounding, 0.0, 12.0, "%.0f")
        if changed then
            style.GrabRounding = style.FrameRounding -- Make GrabRounding always the same value as FrameRounding
        end
        do local pressed, border = ImGui.Checkbox("WindowBorder", style.WindowBorderSize > 0.0); if pressed then if border then style.WindowBorderSize = default_border_size else style.WindowBorderSize = 0.0 end end end
        ImGui.SameLine()
        do local pressed, border = ImGui.Checkbox("FrameBorder", style.FrameBorderSize > 0.0); if pressed then if border then style.FrameBorderSize = default_border_size else style.FrameBorderSize = 0.0 end end end
        ImGui.SameLine()
        do local pressed, border = ImGui.Checkbox("PopupBorder", style.PopupBorderSize > 0.0); if pressed then if border then style.PopupBorderSize = default_border_size else style.PopupBorderSize = 0.0 end end end
    end

    -- Save/Revert button
    if ImGui.Button("Save Ref") then
        ImGuiStyle_Copy(ref, ImGuiStyle_Copy(s.ref_saved_style, style))
    end
    ImGui.SameLine()
    if ImGui.Button("Revert Ref") then
        ImGuiStyle_Copy(style, ref)
    end
    ImGui.SameLine()
    HelpMarker(
        "Save/Revert in local non-persistent storage. Default Colors definition are not affected. " ..
        "Use \"Export\" below to save them somewhere.")

    ImGui.SeparatorText("Details")
    if ImGui.BeginTabBar("##tabs", ImGuiTabBarFlags.None) then
        if ImGui.BeginTabItem("Sizes") then
            ImGui.SeparatorText("Main")
            ImGui.SliderFloat2("WindowPadding", style.WindowPadding, 0.0, 20.0, "%.0f")
            ImGui.SliderFloat2("FramePadding", style.FramePadding, 0.0, 20.0, "%.0f")
            ImGui.SliderFloat2("ItemSpacing", style.ItemSpacing, 0.0, 20.0, "%.0f")
            ImGui.SliderFloat2("ItemInnerSpacing", style.ItemInnerSpacing, 0.0, 20.0, "%.0f")
            ImGui.SliderFloat2("TouchExtraPadding", style.TouchExtraPadding, 0.0, 10.0, "%.0f")
            style.IndentSpacing = ImGui.SliderFloat("IndentSpacing", style.IndentSpacing, 0.0, 30.0, "%.0f")
            style.GrabMinSize = ImGui.SliderFloat("GrabMinSize", style.GrabMinSize, 1.0, 20.0, "%.0f")

            ImGui.SeparatorText("Borders")
            style.WindowBorderSize = ImGui.SliderFloat("WindowBorderSize", style.WindowBorderSize, 0.0, max_border_size, "%.0f")
            style.ChildBorderSize = ImGui.SliderFloat("ChildBorderSize", style.ChildBorderSize, 0.0, max_border_size, "%.0f")
            style.PopupBorderSize = ImGui.SliderFloat("PopupBorderSize", style.PopupBorderSize, 0.0, max_border_size, "%.0f")
            style.FrameBorderSize = ImGui.SliderFloat("FrameBorderSize", style.FrameBorderSize, 0.0, max_border_size, "%.0f")

            ImGui.SeparatorText("Rounding")
            style.WindowRounding = ImGui.SliderFloat("WindowRounding", style.WindowRounding, 0.0, 12.0, "%.0f")
            style.ChildRounding = ImGui.SliderFloat("ChildRounding", style.ChildRounding, 0.0, 12.0, "%.0f")
            style.FrameRounding = ImGui.SliderFloat("FrameRounding", style.FrameRounding, 0.0, 12.0, "%.0f")
            style.PopupRounding = ImGui.SliderFloat("PopupRounding", style.PopupRounding, 0.0, 12.0, "%.0f")
            style.GrabRounding = ImGui.SliderFloat("GrabRounding", style.GrabRounding, 0.0, 12.0, "%.0f")
            style.MenuItemRounding = ImGui.SliderFloat("MenuItemRounding", style.MenuItemRounding, 0.0, 12.0, "%.0f")
            -- NB: SelectableRounding is intentionally NOT made visible here. We don't want to encourage people using that.

            ImGui.SeparatorText("Scrollbar")
            style.ScrollbarSize = ImGui.SliderFloat("ScrollbarSize", style.ScrollbarSize, 1.0, 20.0, "%.0f")
            style.ScrollbarRounding = ImGui.SliderFloat("ScrollbarRounding", style.ScrollbarRounding, 0.0, 12.0, "%.0f")
            style.ScrollbarPadding = ImGui.SliderFloat("ScrollbarPadding", style.ScrollbarPadding, 0.0, 10.0, "%.0f")

            ImGui.SeparatorText("Tabs")
            style.TabBorderSize = ImGui.SliderFloat("TabBorderSize", style.TabBorderSize, 0.0, max_border_size, "%.0f")
            style.TabBarBorderSize = ImGui.SliderFloat("TabBarBorderSize", style.TabBarBorderSize, 0.0, max_border_size, "%.0f")
            style.TabBarOverlineSize = ImGui.SliderFloat("TabBarOverlineSize", style.TabBarOverlineSize, 0.0, ImMax(3.0, max_border_size), "%.0f")
            ImGui.SameLine(); HelpMarker("Overline is only drawn over the selected tab when ImGuiTabBarFlags_DrawSelectedOverline is set.")
            style.TabMinWidthBase = ImGui.DragFloat("TabMinWidthBase", style.TabMinWidthBase, 0.5, 1.0, 500.0, "%.0f")
            style.TabMinWidthShrink = ImGui.DragFloat("TabMinWidthShrink", style.TabMinWidthShrink, 0.5, 1.0, 500.0, "%0.f")
            style.TabCloseButtonMinWidthSelected = ImGui.DragFloat("TabCloseButtonMinWidthSelected", style.TabCloseButtonMinWidthSelected, 0.5, -1.0, 100.0, (style.TabCloseButtonMinWidthSelected < 0.0) and "%.0f (Always)" or "%.0f")
            style.TabCloseButtonMinWidthUnselected = ImGui.DragFloat("TabCloseButtonMinWidthUnselected", style.TabCloseButtonMinWidthUnselected, 0.5, -1.0, 100.0, (style.TabCloseButtonMinWidthUnselected < 0.0) and "%.0f (Always)" or "%.0f")
            style.TabRounding = ImGui.SliderFloat("TabRounding", style.TabRounding, 0.0, 12.0, "%.0f")

            ImGui.SeparatorText("Tables")
            ImGui.SliderFloat2("CellPadding", style.CellPadding, 0.0, 20.0, "%.0f")
            style.TableAngledHeadersAngle = ImGui.SliderAngle("TableAngledHeadersAngle", style.TableAngledHeadersAngle, -50.0, 50.0)
            ImGui.SliderFloat2("TableAngledHeadersTextAlign", style.TableAngledHeadersTextAlign, 0.0, 1.0, "%.2f")

            ImGui.SeparatorText("Trees")
            local combo_open = ImGui.BeginCombo("TreeLinesFlags", GetTreeLinesFlagsName(style.TreeLinesFlags))
            ImGui.SameLine()
            HelpMarker("[Experimental] Tree lines may not work in all situations (e.g. using a clipper) and may incurs slight traversal overhead.\n\nImGuiTreeNodeFlags_DrawLinesFull is faster than ImGuiTreeNodeFlags_DrawLinesToNode.")
            if combo_open then
                local options = { ImGuiTreeNodeFlags.DrawLinesNone, ImGuiTreeNodeFlags.DrawLinesFull, ImGuiTreeNodeFlags.DrawLinesToNodes }
                for _, option in ipairs(options) do
                    if ImGui.Selectable(GetTreeLinesFlagsName(option), style.TreeLinesFlags == option) then
                        style.TreeLinesFlags = option
                    end
                end
                ImGui.EndCombo()
            end
            style.TreeLinesSize = ImGui.SliderFloat("TreeLinesSize", style.TreeLinesSize, 0.0, max_border_size, "%.0f")
            style.TreeLinesRounding = ImGui.SliderFloat("TreeLinesRounding", style.TreeLinesRounding, 0.0, 12.0, "%.0f")

            ImGui.SeparatorText("Windows")
            ImGui.SliderFloat2("WindowTitleAlign", style.WindowTitleAlign, 0.0, 1.0, "%.2f")
            style.WindowBorderHoverPadding = ImGui.SliderFloat("WindowBorderHoverPadding", style.WindowBorderHoverPadding, 1.0, 20.0, "%.0f")
            local window_menu_button_position = style.WindowMenuButtonPosition + 1
            window_menu_button_position, changed = ImGui.Combo("WindowMenuButtonPosition", window_menu_button_position, "None\0Left\0Right\0")
            if changed then
                style.WindowMenuButtonPosition = window_menu_button_position - 1
            end

            ImGui.SeparatorText("Widgets")
            style.ColorMarkerSize = ImGui.SliderFloat("ColorMarkerSize", style.ColorMarkerSize, 0.0, 8.0, "%.0f")
            style.ColorButtonPosition = ImGui.Combo("ColorButtonPosition", style.ColorButtonPosition, "Left\0Right\0")
            ImGui.SliderFloat2("ButtonTextAlign", style.ButtonTextAlign, 0.0, 1.0, "%.2f")
            ImGui.SameLine(); HelpMarker("Alignment applies when a button is larger than its text content.")
            ImGui.SliderFloat2("SelectableTextAlign", style.SelectableTextAlign, 0.0, 1.0, "%.2f")
            ImGui.SameLine(); HelpMarker("Alignment applies when a selectable is larger than its text content.")
            style.SeparatorSize = ImGui.SliderFloat("SeparatorSize", style.SeparatorSize, 0.0, 10.0, "%.0f")
            style.SeparatorTextBorderSize = ImGui.SliderFloat("SeparatorTextBorderSize", style.SeparatorTextBorderSize, 0.0, 10.0, "%.0f")
            ImGui.SliderFloat2("SeparatorTextAlign", style.SeparatorTextAlign, 0.0, 1.0, "%.2f")
            ImGui.SliderFloat2("SeparatorTextPadding", style.SeparatorTextPadding, 0.0, 40.0, "%.0f")
            style.LogSliderDeadzone = ImGui.SliderFloat("LogSliderDeadzone", style.LogSliderDeadzone, 0.0, 12.0, "%.0f")
            style.ImageRounding = ImGui.SliderFloat("ImageRounding", style.ImageRounding, 0.0, 12.0, "%.0f")
            style.ImageBorderSize = ImGui.SliderFloat("ImageBorderSize", style.ImageBorderSize, 0.0, max_border_size, "%.0f")

            ImGui.SeparatorText("Docking")
            --SetCursorPosX(GetCursorPosX() + CalcItemWidth() - GetFrameHeight());
            _, style.DockingNodeHasCloseButton = ImGui.Checkbox("DockingNodeHasCloseButton", style.DockingNodeHasCloseButton)
            style.DockingSeparatorSize = ImGui.SliderFloat("DockingSeparatorSize", style.DockingSeparatorSize, 0.0, 12.0, "%.0f")

            ImGui.SeparatorText("Tooltips")
            for n = 0, 1 do
                if ImGui.TreeNodeEx(n == 0 and "HoverFlagsForTooltipMouse" or "HoverFlagsForTooltipNav") then
                    local p = (n == 0) and "HoverFlagsForTooltipMouse" or "HoverFlagsForTooltipNav" -- [Port] pointer -> field name
                    _, style[p] = ImGui.CheckboxFlags("ImGuiHoveredFlags_DelayNone", style[p], ImGuiHoveredFlags.DelayNone)
                    _, style[p] = ImGui.CheckboxFlags("ImGuiHoveredFlags_DelayShort", style[p], ImGuiHoveredFlags.DelayShort)
                    _, style[p] = ImGui.CheckboxFlags("ImGuiHoveredFlags_DelayNormal", style[p], ImGuiHoveredFlags.DelayNormal)
                    _, style[p] = ImGui.CheckboxFlags("ImGuiHoveredFlags_Stationary", style[p], ImGuiHoveredFlags.Stationary)
                    _, style[p] = ImGui.CheckboxFlags("ImGuiHoveredFlags_NoSharedDelay", style[p], ImGuiHoveredFlags.NoSharedDelay)
                    ImGui.TreePop()
                end
            end

            ImGui.SeparatorText("Misc")
            ImGui.SliderFloat2("DisplayWindowPadding", style.DisplayWindowPadding, 0.0, 30.0, "%.0f"); ImGui.SameLine(); HelpMarker("Apply to regular windows: amount which we enforce to keep visible when moving near edges of your screen.")
            ImGui.SliderFloat2("DisplaySafeAreaPadding", style.DisplaySafeAreaPadding, 0.0, 30.0, "%.0f"); ImGui.SameLine(); HelpMarker("Apply to every windows, menus, popups, tooltips: amount where we avoid displaying contents. Adjust if you cannot see the edges of your screen (e.g. on a TV where scaling has not been configured).")

            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Colors") then
            if ImGui.Button("Export") then
                if s.output_dest == 0 then
                    ImGui.LogToClipboard()
                else
                    ImGui.LogToTTY()
                end
                ImGui.LogText("ImVec4* colors = GetStyle().Colors;" .. "\n") -- [Port] IM_NEWLINE == "\n"
                for i = 0, ImGuiCol.COUNT - 1 do
                    local col = style.Colors[i]
                    local name = ImGui.GetStyleColorName(i)
                    if not s.output_only_modified or col ~= ref.Colors[i] then -- [Port] memcmp -> ImVec4 __eq
                        ImGui.LogText("colors[ImGuiCol_%s]%s= ImVec4(%.2ff, %.2ff, %.2ff, %.2ff);" .. "\n",
                            name, string.rep(" ", 23 - #name), col.x, col.y, col.z, col.w) -- [Port] "%*s" -> string.rep
                    end
                end
                ImGui.LogFinish()
            end
            ImGui.SameLine(); ImGui.SetNextItemWidth(ImGui.GetFontSize() * 10); s.output_dest = ImGui.Combo("##output_type", s.output_dest, "To Clipboard\0To TTY\0")
            ImGui.SameLine(); _, s.output_only_modified = ImGui.Checkbox("Only Modified Colors", s.output_only_modified)

            -- [Port] RadioButton(label, bool active) overload is RadioButtonEx() in the port
            if ImGui.RadioButtonEx("Opaque", s.alpha_flags == ImGuiColorEditFlags.AlphaOpaque)          then s.alpha_flags = ImGuiColorEditFlags.AlphaOpaque end ImGui.SameLine()
            if ImGui.RadioButtonEx("Alpha",  s.alpha_flags == ImGuiColorEditFlags.None)                 then s.alpha_flags = ImGuiColorEditFlags.None end ImGui.SameLine()
            if ImGui.RadioButtonEx("Both",   s.alpha_flags == ImGuiColorEditFlags.AlphaPreviewHalf)     then s.alpha_flags = ImGuiColorEditFlags.AlphaPreviewHalf end ImGui.SameLine()
            HelpMarker(
                "In the color list:\n" ..
                "Left-click on color square to open color picker,\n" ..
                "Right-click to open edit options menu.")

            if s.filter == nil then s.filter = ImGuiTextFilter() end
            ImGui.SetNextItemWidth(-FLT_MIN)
            s.filter:DrawWithHint("##FilterColors", "Filter Colors (incl -excl)")

            ImGui.SetNextWindowSizeConstraints(ImVec2(0.0, ImGui.GetTextLineHeightWithSpacing() * 10), ImVec2(FLT_MAX, FLT_MAX))
            ImGui.BeginChild("##colors", ImVec2(0, 0), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.NavFlattened), bit32.bor(ImGuiWindowFlags.AlwaysVerticalScrollbar, ImGuiWindowFlags.AlwaysHorizontalScrollbar))
            ImGui.PushItemWidth(ImGui.GetFontSize() * -12)
            for i = 0, ImGuiCol.COUNT - 1 do repeat
                local name = ImGui.GetStyleColorName(i)
                if not s.filter:PassFilter(name) then
                    break -- continue
                end
                ImGui.PushID(i)
                if ImGui.Button("?") then
                    if ImGui.DebugFlashStyleColor then ImGui.DebugFlashStyleColor(i) end -- [Port] DebugFlashStyleColor() is not in the library yet
                end
                ImGui.SetItemTooltip("Flash given color to identify places where it is used.")
                ImGui.SameLine()
                ImGui.ColorEdit4("##color", style.Colors[i], bit32.bor(ImGuiColorEditFlags.AlphaBar, s.alpha_flags))
                if style.Colors[i] ~= ref.Colors[i] then -- [Port] memcmp -> ImVec4 __eq
                    -- Tips: in a real user application, you may want to merge and use an icon font into the main font,
                    -- so instead of "Save"/"Revert" you'd use icons!
                    -- Read the FAQ and docs/FONTS.md about using icon fonts. It's really easy and super convenient!
                    ImGui.SameLine(0.0, style.ItemInnerSpacing.x); if ImGui.Button("Save") then ImVec4_Copy(ref.Colors[i], style.Colors[i]) end
                    ImGui.SameLine(0.0, style.ItemInnerSpacing.x); if ImGui.Button("Revert") then ImVec4_Copy(style.Colors[i], ref.Colors[i]) end
                end
                ImGui.SameLine(0.0, style.ItemInnerSpacing.x)
                ImGui.TextUnformatted(name)
                ImGui.PopID()
            until true end
            ImGui.PopItemWidth()
            ImGui.EndChild()

            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Fonts") then
            local io = ImGui.GetIO()
            local atlas = io.Fonts
            ImGui.ShowFontAtlas(atlas)

            -- Post-baking font scaling. Note that this is NOT the nice way of scaling fonts, read below.
            -- (we enforce hard clamping manually as by default DragFloat/SliderFloat allows Ctrl+Click text to get out of bounds).
            --[[
            SeparatorText("Legacy Scaling");
            const float MIN_SCALE = 0.3f;
            const float MAX_SCALE = 2.0f;
            HelpMarker(
                "Those are old settings provided for convenience.\n"
                "However, the _correct_ way of scaling your UI is currently to reload your font at the designed size, "
                "rebuild the font atlas, and call style.ScaleAllSizes() on a reference ImGuiStyle structure.\n"
                "Using those settings here will give you poor quality results.");
            PushItemWidth(GetFontSize() * 8);
            DragFloat("global scale", &io.FontGlobalScale, 0.005f, MIN_SCALE, MAX_SCALE, "%.2f", ImGuiSliderFlags_AlwaysClamp); // Scale everything
            //static float window_scale = 1.0f;
            //if (DragFloat("window scale", &window_scale, 0.005f, MIN_SCALE, MAX_SCALE, "%.2f", ImGuiSliderFlags_AlwaysClamp)) // Scale only this window
            //    SetWindowFontScale(window_scale);
            PopItemWidth();
            ]]

            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Rendering") then
            _, style.AntiAliasedLines = ImGui.Checkbox("Anti-aliased lines", style.AntiAliasedLines)
            ImGui.SameLine()
            HelpMarker("When disabling anti-aliasing lines, you'll probably want to disable borders in your style as well.")
            ImGui.BeginDisabled(style.AntiAliasedLines == false)
            _, style.AntiAliasedLineEnds = ImGui.Checkbox("Anti-aliased line ends", style.AntiAliasedLineEnds)
            ImGui.EndDisabled()

            ImGui.BeginDisabled()
            _, style.AntiAliasedLinesUseTex = ImGui.Checkbox("Anti-aliased lines use texture", style.AntiAliasedLinesUseTex)
            ImGui.SameLine()
            HelpMarker("Faster lines using texture data. Require backend to render with bilinear filtering (not point/nearest filtering).")
            ImGui.EndDisabled()

            _, style.AntiAliasedFill = ImGui.Checkbox("Anti-aliased fill", style.AntiAliasedFill)
            local io = ImGui.GetIO()
            _, io.ConfigDebugDrawListDefaultsToStrokeLegacy = ImGui.Checkbox("Debug: DrawList Defaults to _StrokeLegacy", io.ConfigDebugDrawListDefaultsToStrokeLegacy)

            ImGui.PushItemWidth(ImGui.GetFontSize() * 8)
            style.CurveTessellationMaxError = ImGui.DragFloat("Curve Tessellation Max Error", style.CurveTessellationMaxError, 0.02, 0.10, 10.0, "%.2f")
            if style.CurveTessellationMaxError < 0.10 then
                style.CurveTessellationMaxError = 0.10
            end

            -- When editing the "Circle Segment Max Error" value, draw a preview of its effect on auto-tessellated circles.
            style.CircleTessellationMaxError = ImGui.DragFloat("Circle Tessellation Max Error", style.CircleTessellationMaxError, 0.005, 0.10, 5.0, "%.2f", ImGuiSliderFlags.AlwaysClamp)
            local show_samples = ImGui.IsItemActive()
            if show_samples then
                ImGui.SetNextWindowPos(ImGui.GetCursorScreenPos())
            end
            if show_samples and ImGui.BeginTooltip() then
                ImGui.TextUnformatted("(R = radius, N = approx number of segments)")
                ImGui.Spacing()
                local draw_list = ImGui.GetWindowDrawList()
                local min_widget_width = ImGui.CalcTextSize("R: MMM\nN: MMM").x
                for n = 0, 7 do
                    local RAD_MIN = 5.0
                    local RAD_MAX = 70.0
                    local rad = RAD_MIN + (RAD_MAX - RAD_MIN) * n / (8.0 - 1.0)

                    ImGui.BeginGroup()

                    -- N is not always exact here due to how PathArcTo() function work internally
                    ImGui.Text("R: %.f\nN: %d", rad, draw_list:_CalcCircleAutoSegmentCount(rad))

                    local canvas_width = ImMax(min_widget_width, rad * 2.0)
                    local offset_x     = math.floor(canvas_width * 0.5)
                    local offset_y     = math.floor(RAD_MAX)

                    local p1 = ImGui.GetCursorScreenPos()
                    draw_list:AddCircle(ImVec2(p1.x + offset_x, p1.y + offset_y), rad, ImGui.GetColorU32(ImGuiCol.Text))
                    ImGui.Dummy(ImVec2(canvas_width, RAD_MAX * 2))

                    --[[
                    const ImVec2 p2 = GetCursorScreenPos();
                    draw_list->AddCircleFilled(ImVec2(p2.x + offset_x, p2.y + offset_y), rad, GetColorU32(ImGuiCol_Text));
                    Dummy(ImVec2(canvas_width, RAD_MAX * 2));
                    ]]

                    ImGui.EndGroup()
                    ImGui.SameLine()
                end
                ImGui.EndTooltip()
            end
            ImGui.SameLine()
            HelpMarker("When drawing circle primitives with \"num_segments == 0\" tessellation will be calculated automatically.")

            style.Alpha = ImGui.DragFloat("Global Alpha", style.Alpha, 0.005, 0.20, 1.0, "%.2f") -- Not exposing zero here so user doesn't "lose" the UI (zero alpha clips all widgets). But application code could have a toggle to switch between zero and non-zero.
            style.DisabledAlpha = ImGui.DragFloat("Disabled Alpha", style.DisabledAlpha, 0.005, 0.0, 1.0, "%.2f"); ImGui.SameLine(); HelpMarker("Additional alpha multiplier for disabled items (multiply over current value of Alpha).")
            ImGui.PopItemWidth()

            ImGui.EndTabItem()
        end

        ImGui.EndTabBar()
    end
    ImGui.PopItemWidth()
end

-------------------------------------------------------------------------------
-- [SECTION] User Guide / ShowUserGuide()
-------------------------------------------------------------------------------

-- We omit the ImGui:: prefix in this function, as we don't expect user to be copy and pasting this code.
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

-------------------------------------------------------------------------------
-- [SECTION] Example App: Main Menu Bar / ShowExampleAppMainMenuBar()
-------------------------------------------------------------------------------
-- - ShowExampleAppMainMenuBar()
-- - ShowExampleMenuFile()
-------------------------------------------------------------------------------

-- Demonstrate creating a "main" fullscreen menu bar and populating it.
-- Note the difference between BeginMainMenuBar() and BeginMenuBar():
-- - BeginMenuBar() = menu-bar inside current window (which needs the ImGuiWindowFlags.MenuBar flag!)
-- - BeginMainMenuBar() = helper to create menu-bar-sized window at the top of the main viewport + call BeginMenuBar() into it.
function ShowExampleAppMainMenuBar()
    if ImGui.BeginMainMenuBar() then
        if ImGui.BeginMenu("File") then
            IMGUI_DEMO_MARKER("Menu/File")
            ShowExampleMenuFile()
            ImGui.EndMenu()
        end
        if ImGui.BeginMenu("Edit") then
            IMGUI_DEMO_MARKER("Menu/Edit")
            if ImGui.MenuItem("Undo", "Ctrl+Z") then end
            if ImGui.MenuItem("Redo", "Ctrl+Y", false, false) then end -- Disabled item
            ImGui.Separator()
            if ImGui.MenuItem("Cut", "Ctrl+X") then end
            if ImGui.MenuItem("Copy", "Ctrl+C") then end
            if ImGui.MenuItem("Paste", "Ctrl+V") then end
            ImGui.EndMenu()
        end
        ImGui.EndMainMenuBar()
    end
end

-- Note that shortcuts are currently provided for display only
-- (future version will add explicit flags to BeginMenu() to request processing shortcuts)
S.ShowExampleMenuFile = {
    enabled = true,
    f = 0.5,
    n = 0,
    b = true,
}
function ShowExampleMenuFile()
    local s = S.ShowExampleMenuFile
    IMGUI_DEMO_MARKER("Examples/Menu")
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
        IMGUI_DEMO_MARKER("Examples/Menu/Options")
        _, s.enabled = ImGui.MenuItem("Enabled", "", s.enabled)
        ImGui.BeginChild("child", ImVec2(0, ImGui.GetTextLineHeightWithSpacing() * 5.0), ImGuiChildFlags.Borders)
        for i = 0, 10 - 1 do
            ImGui.Text("Scrolling Text %d", i)
        end
        ImGui.EndChild()
        s.f = ImGui.SliderFloat("Value", s.f, 0.0, 1.0)
        s.f = ImGui.InputFloat("Input", s.f, 0.1)
        s.n = ImGui.Combo("Combo", s.n, "Yes\0No\0Maybe\0\0")
        ImGui.EndMenu()
    end

    if ImGui.BeginMenu("Colors") then
        IMGUI_DEMO_MARKER("Examples/Menu/Colors")
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
    -- Of course in this demo it is a little bit silly that this function calls BeginMenu("Options") twice.
    -- In a real code-base using it would make senses to use this feature from very different code locations.
    if ImGui.BeginMenu("Options") then -- <-- Append!
        IMGUI_DEMO_MARKER("Examples/Menu/Append to an existing menu")
        _, s.b = ImGui.Checkbox("SomeOption", s.b)
        ImGui.EndMenu()
    end

    if ImGui.BeginMenu("Disabled", false) then -- Disabled
        IM_ASSERT(false)
    end
    if ImGui.MenuItem("Checked", nil, true) then end
    ImGui.Separator()
    if ImGui.MenuItem("Quit", "Alt+F4") then end
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Debug Console / ShowExampleAppConsole()
-------------------------------------------------------------------------------

-- Demonstrate creating a simple console window, with scrolling, filtering, completion and history.
-- For the console example, we are using a more C++ like approach of declaring a class to hold both data and functions.
ExampleAppConsoleMT = {}
ExampleAppConsoleMT.__index = ExampleAppConsoleMT
function ExampleAppConsole()
    local self = setmetatable({}, ExampleAppConsoleMT)
    self.InputBuf = nil          -- char InputBuf[256]
    self.Items = ImVector()      -- ImVector<char*>
    self.Commands = ImVector()   -- ImVector<const char*>
    self.History = ImVector()    -- ImVector<char*>
    self.HistoryPos = 0          -- -1: new line, 0..History.Size-1 browsing history.
    self.Filter = ImGuiTextFilter()
    self.AutoScroll = false
    self.ScrollToBottom = false

    self:ClearLog()
    self.InputBuf = ImGui.NewTextBuffer("", 256) -- memset(InputBuf, 0, sizeof(InputBuf))
    self.HistoryPos = -1

    -- "CLASSIFY" is here to provide the test case where "C"+[tab] completes to "CL" and display multiple matches.
    self.Commands:push_back("HELP")
    self.Commands:push_back("HISTORY")
    self.Commands:push_back("CLEAR")
    self.Commands:push_back("CLASSIFY")
    self.AutoScroll = true
    self.ScrollToBottom = false
    self:AddLog("Welcome to Dear ImGui!")
    return self
end
-- [Port] ~ExampleAppConsole(): nothing to free (GC)

-- Portable helpers
do
    local function toupper(c) if c >= 97 and c <= 122 then return c - 32 end return c end -- [Port] C toupper() on bytes
    function ExampleAppConsoleMT.Stricmp(s1, s2)         local i = 1; local d; while true do local c1 = string.byte(s1, i) or 0; d = toupper(string.byte(s2, i) or 0) - toupper(c1); if d ~= 0 or c1 == 0 then break end; i = i + 1 end; return d end
    function ExampleAppConsoleMT.Strnicmp(s1, s2, n)     local i = 1; local d = 0; while n > 0 do local c1 = string.byte(s1, i) or 0; d = toupper(string.byte(s2, i) or 0) - toupper(c1); if d ~= 0 or c1 == 0 then break end; i = i + 1; n = n - 1 end; return d end
    function ExampleAppConsoleMT.Strdup(s)               IM_ASSERT(s); return s end -- [Port] Lua strings are immutable values
    function ExampleAppConsoleMT.Strtrimblanks(s)        local str_end = 0; while s[str_end + 1] ~= nil and s[str_end + 1] ~= 0 do str_end = str_end + 1 end; while str_end > 0 and s[str_end] == 32 do str_end = str_end - 1 end; s[str_end + 1] = 0 end
    ExampleAppConsoleMT.toupper = toupper -- [Port] used by TextEditCallback()
end

function ExampleAppConsoleMT:ClearLog()
    -- [Port] ImGui::MemFree(Items[i]) not needed (GC)
    self.Items:clear()
end

function ExampleAppConsoleMT:AddLog(fmt, ...)
    -- FIXME-OPT
    local buf = string.format(fmt, ...)
    buf = string.sub(buf, 1, 1024 - 1) -- [Port] vsnprintf() into char buf[1024]
    self.Items:push_back(ExampleAppConsoleMT.Strdup(buf))
end

function ExampleAppConsoleMT:Draw(title, p_open)
    ImGui.SetNextWindowSize(ImVec2(520, 600), ImGuiCond.FirstUseEver)
    local visible
    p_open, visible = ImGui.Begin(title, p_open)
    if not visible then
        ImGui.End()
        return p_open
    end
    IMGUI_DEMO_MARKER("Examples/Console")

    -- As a specific feature guaranteed by the library, after calling Begin() the last Item represent the title bar.
    -- So e.g. IsItemHovered() will return true when hovering the title bar.
    -- Here we create a context menu only available from the title bar.
    if ImGui.BeginPopupContextItem() then
        if ImGui.MenuItem("Close Console") then
            p_open = false
        end
        ImGui.EndPopup()
    end

    ImGui.TextWrapped(
        "This example implements a console with basic coloring, completion (TAB key) and history (Up/Down keys). A more elaborate " ..
        "implementation may want to store entries along with extra data such as timestamp, emitter, etc.")
    ImGui.TextWrapped("Enter 'HELP' for help.")

    -- TODO: display items starting from the bottom

    if ImGui.SmallButton("Add Debug Text") then self:AddLog("%d some text", self.Items.Size); self:AddLog("some more text"); self:AddLog("display very important message here!") end
    ImGui.SameLine()
    if ImGui.SmallButton("Add Debug Error") then self:AddLog("[error] something went wrong") end
    ImGui.SameLine()
    if ImGui.SmallButton("Clear") then self:ClearLog() end
    ImGui.SameLine()
    local copy_to_clipboard = ImGui.SmallButton("Copy")
    --static float t = 0.0f; if (ImGui.GetTime() - t > 0.02f) { t = ImGui.GetTime(); AddLog("Spam %f", t); }

    ImGui.Separator()

    -- Options menu
    if ImGui.BeginPopup("Options") then
        _, self.AutoScroll = ImGui.Checkbox("Auto-scroll", self.AutoScroll)
        ImGui.EndPopup()
    end

    -- Options, Filter
    ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.O), ImGuiInputFlags.Tooltip)
    if ImGui.Button("Options") then
        ImGui.OpenPopup("Options")
    end
    ImGui.SameLine()

    ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.F), ImGuiInputFlags.Tooltip)
    ImGui.SetNextItemWidth(-FLT_MIN)
    self.Filter:DrawWithHint("##Filter", "Filter (incl -excl)")
    ImGui.Separator()

    -- Reserve enough left-over height for 1 separator + 1 input text
    local style = ImGui.GetStyle()
    local footer_height_to_reserve = style.SeparatorSize + style.ItemSpacing.y + ImGui.GetFrameHeightWithSpacing()
    if ImGui.BeginChild("ScrollingRegion", ImVec2(0, -footer_height_to_reserve), ImGuiChildFlags.NavFlattened, ImGuiWindowFlags.HorizontalScrollbar) then
        if ImGui.BeginPopupContextWindow() then
            if ImGui.Selectable("Clear") then self:ClearLog() end
            ImGui.EndPopup()
        end

        -- Display every line as a separate entry so we can change their color or add custom widgets.
        -- If you only want raw text you can use ImGui.TextUnformatted(log.begin(), log.end());
        -- NB- if you have thousands of entries this approach may be too inefficient and may require user-side clipping
        -- to only process visible items. The clipper will automatically measure the height of your first item and then
        -- "seek" to display only items in the visible area.
        -- To use the clipper we can replace your standard loop:
        --      for (int i = 0; i < Items.Size; i++)
        --   With:
        --      ImGuiListClipper clipper;
        --      clipper.Begin(Items.Size);
        --      while (clipper.Step())
        --         for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++)
        -- - That your items are evenly spaced (same height)
        -- - That you have cheap random access to your elements (you can access them given their index,
        --   without processing all the ones before)
        -- You cannot this code as-is if a filter is active because it breaks the 'cheap random-access' property.
        -- We would need random-access on the post-filtered list.
        -- A typical application wanting coarse clipping and filtering may want to pre-compute an array of indices
        -- or offsets of items that passed the filtering test, recomputing this array when user changes the filter,
        -- and appending newly elements as they are inserted. This is left as a task to the user until we can manage
        -- to improve this example code!
        -- If your items are of variable height:
        -- - Split them into same height items would be simpler and facilitate random-seeking into your list.
        -- - Consider using manual call to IsRectVisible() and skipping extraneous decoration from your items.
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(4, 1)) -- Tighten spacing
        if copy_to_clipboard then
            ImGui.LogToClipboard()
        end
        for _, item in self.Items:iter() do repeat
            if not self.Filter:PassFilter(item) then
                break -- continue
            end

            -- Normally you would store more information in your item than just a string.
            -- (e.g. make Items[] an array of structure, store color/type etc.)
            local color
            local has_color = false
            if string.find(item, "[error]", 1, true) then color = ImVec4(1.0, 0.4, 0.4, 1.0); has_color = true
            elseif string.sub(item, 1, 2) == "# " then color = ImVec4(1.0, 0.8, 0.6, 1.0); has_color = true end
            if has_color then
                ImGui.PushStyleColor(ImGuiCol.Text, color)
            end
            ImGui.TextUnformatted(item)
            if has_color then
                ImGui.PopStyleColor()
            end
        until true end
        if copy_to_clipboard then
            ImGui.LogFinish()
        end

        -- Keep up at the bottom of the scroll region if we were already at the bottom at the beginning of the frame.
        -- Using a scrollbar or mouse-wheel will take away from the bottom edge.
        if self.ScrollToBottom or (self.AutoScroll and ImGui.GetScrollY() >= ImGui.GetScrollMaxY()) then
            ImGui.SetScrollHereY(1.0)
        end
        self.ScrollToBottom = false

        ImGui.PopStyleVar()
    end
    ImGui.EndChild()
    ImGui.Separator()

    -- Command-line
    local reclaim_focus = false
    local input_text_flags = bit32.bor(ImGuiInputTextFlags.EnterReturnsTrue, ImGuiInputTextFlags.EscapeClearsAll, ImGuiInputTextFlags.CallbackCompletion, ImGuiInputTextFlags.CallbackHistory)
    if ImGui.InputText("Input", self.InputBuf, 256, input_text_flags, ExampleAppConsoleMT.TextEditCallbackStub, self) then
        local s = self.InputBuf
        ExampleAppConsoleMT.Strtrimblanks(s)
        if s[1] ~= 0 then
            self:ExecCommand(ImGui.TextBufferToString(s))
        end
        s[1] = 0
        reclaim_focus = true
    end

    -- Auto-focus on window apparition
    ImGui.SetItemDefaultFocus()
    if reclaim_focus then
        ImGui.SetKeyboardFocusHere(-1) -- Auto focus previous widget
    end

    ImGui.End()
    return p_open
end

function ExampleAppConsoleMT:ExecCommand(command_line)
    local Stricmp = ExampleAppConsoleMT.Stricmp
    self:AddLog("# %s\n", command_line)

    -- Insert into history. First find match and delete it so it can be pushed to the back.
    -- This isn't trying to be smart or optimal.
    self.HistoryPos = -1
    for i = self.History.Size - 1, 0, -1 do
        if Stricmp(self.History.Data[i + 1], command_line) == 0 then
            self.History:erase(i + 1)
            break
        end
    end
    self.History:push_back(ExampleAppConsoleMT.Strdup(command_line))

    -- Process command
    if Stricmp(command_line, "CLEAR") == 0 then
        self:ClearLog()
    elseif Stricmp(command_line, "HELP") == 0 then
        self:AddLog("Commands:")
        for i = 0, self.Commands.Size - 1 do
            self:AddLog("- %s", self.Commands.Data[i + 1])
        end
    elseif Stricmp(command_line, "HISTORY") == 0 then
        local first = self.History.Size - 10
        for i = (first > 0) and first or 0, self.History.Size - 1 do
            self:AddLog("%3d: %s\n", i, self.History.Data[i + 1])
        end
    else
        self:AddLog("Unknown command: '%s'\n", command_line)
    end

    -- On command input, we scroll to bottom even if AutoScroll==false
    self.ScrollToBottom = true
end

-- In C++11 you'd be better off using lambdas for this sort of forwarding callbacks
function ExampleAppConsoleMT.TextEditCallbackStub(data)
    local console = data.UserData
    return console:TextEditCallback(data)
end

-- [Port] data.Buf is a 1-based byte table; positions (CursorPos, word_start, word_end) are 0-based offsets like upstream.
function ExampleAppConsoleMT:TextEditCallback(data)
    local toupper = ExampleAppConsoleMT.toupper
    --AddLog("cursor: %d, selection: %d-%d", data.CursorPos, data.SelectionStart, data.SelectionEnd)
    if data.EventFlag == ImGuiInputTextFlags.CallbackCompletion then
        -- Example of TEXT COMPLETION

        -- Locate beginning of current word
        local word_end = data.CursorPos
        local word_start = word_end
        while word_start > 0 do
            local c = data.Buf[word_start] -- word_start[-1]
            if c == 32 or c == 9 or c == 44 or c == 59 then -- ' ', '\t', ',', ';'
                break
            end
            word_start = word_start - 1
        end
        local word = string.char(table.unpack(data.Buf, word_start + 1, word_end)) -- [Port] word_start..word_end as a string

        -- Build a list of candidates
        local candidates = ImVector()
        for i = 0, self.Commands.Size - 1 do
            if ExampleAppConsoleMT.Strnicmp(self.Commands.Data[i + 1], word, word_end - word_start) == 0 then
                candidates:push_back(self.Commands.Data[i + 1])
            end
        end

        if candidates.Size == 0 then
            -- No match
            self:AddLog("No match for \"%s\"!\n", word) -- [Port] "%.*s" -> "%s"
        elseif candidates.Size == 1 then
            -- Single match. Delete the beginning of the word and replace it entirely so we've got nice casing.
            data:DeleteChars(word_start, word_end - word_start)
            data:InsertChars(data.CursorPos, candidates.Data[1])
            data:InsertChars(data.CursorPos, " ")
        else
            -- Multiple matches. Complete as much as we can..
            -- So inputting "C"+Tab will complete to "CL" then display "CLEAR" and "CLASSIFY" as matches.
            local match_len = word_end - word_start
            while true do
                local c = 0
                local all_candidates_matches = true
                local i = 0
                while i < candidates.Size and all_candidates_matches do
                    if i == 0 then
                        c = toupper(string.byte(candidates.Data[i + 1], match_len + 1) or 0)
                    elseif c == 0 or c ~= toupper(string.byte(candidates.Data[i + 1], match_len + 1) or 0) then
                        all_candidates_matches = false
                    end
                    i = i + 1
                end
                if not all_candidates_matches then
                    break
                end
                match_len = match_len + 1
            end

            if match_len > 0 then
                data:DeleteChars(word_start, word_end - word_start)
                data:InsertChars(data.CursorPos, string.sub(candidates.Data[1], 1, match_len)) -- [Port] InsertChars() has no text_end parameter
            end

            -- List matches
            self:AddLog("Possible matches:\n")
            for i = 0, candidates.Size - 1 do
                self:AddLog("- %s\n", candidates.Data[i + 1])
            end
        end

    elseif data.EventFlag == ImGuiInputTextFlags.CallbackHistory then
        -- Example of HISTORY
        local prev_history_pos = self.HistoryPos
        if data.EventKey == ImGuiKey.UpArrow then
            if self.HistoryPos == -1 then
                self.HistoryPos = self.History.Size - 1
            elseif self.HistoryPos > 0 then
                self.HistoryPos = self.HistoryPos - 1
            end
        elseif data.EventKey == ImGuiKey.DownArrow then
            if self.HistoryPos ~= -1 then
                self.HistoryPos = self.HistoryPos + 1
                if self.HistoryPos >= self.History.Size then
                    self.HistoryPos = -1
                end
            end
        end

        -- A better implementation would preserve the data on the current input line along with cursor position.
        if prev_history_pos ~= self.HistoryPos then
            local history_str = ""
            if self.HistoryPos >= 0 then history_str = self.History.Data[self.HistoryPos + 1] end
            data:DeleteChars(0, data.BufTextLen)
            data:InsertChars(0, history_str)
        end
    end
    return 0
end

S.ShowExampleAppConsole = {
    console = nil, -- ExampleAppConsole, created on first use
}
function ShowExampleAppConsole(p_open)
    local s = S.ShowExampleAppConsole
    if s.console == nil then s.console = ExampleAppConsole() end
    return s.console:Draw("Example: Console", p_open)
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Image Viewer / ShowExampleAppImageViewer()
-------------------------------------------------------------------------------

S.ShowExampleAppImageViewer = {
    image_viewer = nil, -- ExampleImageViewerData, created on first use
}
function ShowExampleAppImageViewer(p_open)
    local s = S.ShowExampleAppImageViewer
    local atlas = ImGui.GetIO().Fonts
    local tex_ref = atlas.TexRef -- We don't have access to other textures in this demo!
    local tex_w = atlas.TexData.Width
    local tex_h = atlas.TexData.Height
    local visible
    p_open, visible = ImGui.Begin("Example: Image Viewer", p_open)
    if visible then
        if s.image_viewer == nil then s.image_viewer = ExampleImageViewerData() end
        ExampleImageViewer_DrawOptions(s.image_viewer)
        local canvas_size = ImGui.GetContentRegionAvail()
        local canvas_min_size
        if ImGui.IsWindowAppearing() then canvas_min_size = ImVec2(3.0 * tex_w, 4.0 * tex_h) else canvas_min_size = ImVec2(1.0, 1.0) end
        canvas_size = ImVec2(ImMax(canvas_size.x, canvas_min_size.x), ImMax(canvas_size.y, canvas_min_size.y))
        ExampleImageViewer_DrawCanvas(s.image_viewer, canvas_size, tex_ref, tex_w, tex_h)
    end
    ImGui.End()
    return p_open
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Debug Log / ShowExampleAppLog()
-------------------------------------------------------------------------------

-- Usage:
--  static ExampleAppLog my_log;
--  my_log.AddLog("Hello %d world\n", 123);
--  my_log.Draw("title");
ExampleAppLogMT = {}
ExampleAppLogMT.__index = ExampleAppLogMT
function ExampleAppLog()
    local self = setmetatable({}, ExampleAppLogMT)
    self.Buf = ImGuiTextBuffer()
    self.Filter = ImGuiTextFilter()
    self.LineOffsets = ImVector() -- Index to lines offset. We maintain this with AddLog() calls.
    self.AutoScroll = false       -- Keep scrolling if already at the bottom.

    self.AutoScroll = true
    self:Clear()
    return self
end

function ExampleAppLogMT:Clear()
    self.Buf:clear()
    self.LineOffsets:clear()
    self.LineOffsets:push_back(0)
end

function ExampleAppLogMT:AddLog(fmt, ...)
    local old_size = self.Buf:size()
    self.Buf:appendf(fmt, ...)
    local buf = self.Buf:c_str() -- [Port] Buf[] byte access
    local new_size = #buf
    while old_size < new_size do
        if string.byte(buf, old_size + 1) == 10 then -- '\n'
            self.LineOffsets:push_back(old_size + 1)
        end
        old_size = old_size + 1
    end
end

-- [Port] line offsets are 0-based like upstream; a line is string.sub(buf, line_start + 1, line_end) (TextUnformatted()/PassFilter() have no text_begin)
function ExampleAppLogMT:Draw(title, p_open)
    local visible
    p_open, visible = ImGui.Begin(title, p_open)
    if not visible then
        ImGui.End()
        return p_open
    end

    -- Options menu
    if ImGui.BeginPopup("Options") then
        _, self.AutoScroll = ImGui.Checkbox("Auto-scroll", self.AutoScroll)
        ImGui.EndPopup()
    end

    -- Main window
    if ImGui.Button("Options") then
        ImGui.OpenPopup("Options")
    end
    ImGui.SameLine()
    local clear = ImGui.Button("Clear")
    ImGui.SameLine()
    local copy = ImGui.Button("Copy")
    ImGui.SameLine()
    ImGui.SetNextItemWidth(-FLT_MIN)
    self.Filter:DrawWithHint("##Filter", "Filter (incl -excl)")

    ImGui.Separator()

    if ImGui.BeginChild("scrolling", ImVec2(0, 0), ImGuiChildFlags.None, ImGuiWindowFlags.HorizontalScrollbar) then
        if clear then
            self:Clear()
        end
        if copy then
            ImGui.LogToClipboard()
        end

        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
        local buf = self.Buf:c_str()
        local buf_end = #buf
        local LineOffsets = self.LineOffsets
        if self.Filter:IsActive() then
            -- In this example we don't use the clipper when Filter is enabled.
            -- This is because we don't have random access to the result of our filter.
            -- A real application processing logs with ten of thousands of entries may want to store the result of
            -- search/filter.. especially if the filtering function is not trivial (e.g. reg-exp).
            for line_no = 0, LineOffsets.Size - 1 do
                local line_start = LineOffsets.Data[line_no + 1]
                local line_end
                if line_no + 1 < LineOffsets.Size then line_end = LineOffsets.Data[line_no + 2] - 1 else line_end = buf_end end
                local line = string.sub(buf, line_start + 1, line_end)
                if self.Filter:PassFilter(line) then
                    ImGui.TextUnformatted(line)
                end
            end
        else
            -- The simplest and easy way to display the entire buffer:
            --   ImGui.TextUnformatted(buf_begin, buf_end);
            -- And it'll just work. TextUnformatted() has specialization for large blob of text and will fast-forward
            -- to skip non-visible lines. Here we instead demonstrate using the clipper to only process lines that are
            -- within the visible area.
            -- If you have tens of thousands of items and their processing cost is non-negligible, coarse clipping them
            -- on your side is recommended. Using ImGuiListClipper requires
            -- - A) random access into your data
            -- - B) items all being the  same height,
            -- both of which we can handle since we have an array pointing to the beginning of each line of text.
            -- When using the filter (in the block of code above) we don't have random access into the data to display
            -- anymore, which is why we don't use the clipper. Storing or skimming through the search result would make
            -- it possible (and would be recommended if you want to search through tens of thousands of entries).
            local clipper = ImGuiListClipper()
            clipper:Begin(LineOffsets.Size)
            while clipper:Step() do
                for line_no = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                    local line_start = LineOffsets.Data[line_no + 1]
                    local line_end
                    if line_no + 1 < LineOffsets.Size then line_end = LineOffsets.Data[line_no + 2] - 1 else line_end = buf_end end
                    ImGui.TextUnformatted(string.sub(buf, line_start + 1, line_end))
                end
            end
            clipper:End()
        end
        ImGui.PopStyleVar()

        -- Keep up at the bottom of the scroll region if we were already at the bottom at the beginning of the frame.
        -- Using a scrollbar or mouse-wheel will take away from the bottom edge.
        if self.AutoScroll and ImGui.GetScrollY() >= ImGui.GetScrollMaxY() then
            ImGui.SetScrollHereY(1.0)
        end
    end
    ImGui.EndChild()
    ImGui.End()
    return p_open
end

-- Demonstrate creating a simple log window with basic filtering.
S.ShowExampleAppLog = {
    log = nil, -- ExampleAppLog, created on first use
    counter = 0,
}
function ShowExampleAppLog(p_open)
    local s = S.ShowExampleAppLog
    if s.log == nil then s.log = ExampleAppLog() end

    -- For the demo: add a debug button _BEFORE_ the normal log window contents
    -- We take advantage of a rarely used feature: multiple calls to Begin()/End() are appending to the _same_ window.
    -- Most of the contents of the window will be added by the log.Draw() call.
    ImGui.SetNextWindowSize(ImVec2(500, 400), ImGuiCond.FirstUseEver)
    p_open = ImGui.Begin("Example: Log", p_open)
    IMGUI_DEMO_MARKER("Examples/Log")
    if ImGui.SmallButton("[Debug] Add 5 entries") then
        local categories = { "info", "warn", "error" }
        local words = { "Bumfuzzled", "Cattywampus", "Snickersnee", "Abibliophobia", "Absquatulate", "Nincompoop", "Pauciloquent" }
        for n = 0, 5 - 1 do
            local category = categories[s.counter % #categories + 1]
            local word = words[s.counter % #words + 1]
            s.log:AddLog("[%05d] [%s] Hello, current time is %.1f, here's a word: '%s'\n",
                ImGui.GetFrameCount(), category, ImGui.GetTime(), word)
            s.counter = s.counter + 1
        end
    end
    ImGui.End()

    -- Actually call in the regular Log helper (which will Begin() into the same window as we just did)
    return s.log:Draw("Example: Log", p_open)
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Simple Layout / ShowExampleAppLayout()
-------------------------------------------------------------------------------

-- Demonstrate create a window with multiple child windows.
S.ShowExampleAppLayout = {
    selected = 0,
}
function ShowExampleAppLayout(p_open)
    local s = S.ShowExampleAppLayout
    ImGui.SetNextWindowSize(ImVec2(500, 440), ImGuiCond.FirstUseEver)
    local visible
    p_open, visible = ImGui.Begin("Example: Simple layout", p_open, ImGuiWindowFlags.MenuBar)
    if visible then
        IMGUI_DEMO_MARKER("Examples/Simple layout")
        if ImGui.BeginMenuBar() then
            if ImGui.BeginMenu("File") then
                if ImGui.MenuItem("Close", "Ctrl+W") then p_open = false end
                ImGui.EndMenu()
            end
            ImGui.EndMenuBar()
        end

        -- Left
        do
            ImGui.BeginChild("left pane", ImVec2(150, 0), bit32.bor(ImGuiChildFlags.Borders, ImGuiChildFlags.ResizeX))
            for i = 0, 100 - 1 do
                local label = string.format("MyObject %d", i)
                if ImGui.Selectable(label, s.selected == i, ImGuiSelectableFlags.SelectOnNav) then
                    s.selected = i
                end
            end
            ImGui.EndChild()
        end
        ImGui.SameLine()

        -- Right
        do
            ImGui.BeginGroup()
            ImGui.BeginChild("item view", ImVec2(0, -ImGui.GetFrameHeightWithSpacing())) -- Leave room for 1 line below us
            ImGui.Text("MyObject: %d", s.selected)
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
    end
    ImGui.End()
    return p_open
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Property Editor / ShowExampleAppPropertyEditor()
-------------------------------------------------------------------------------
-- Some of the interactions are a bit lack-luster:
-- - We would want pressing validating or leaving the filter to somehow restore focus.
-- - We may want more advanced filtering (child nodes) and clipper support: both will need extra work.
-- - We would want to customize some keyboard interactions to easily keyboard navigate between the tree and the properties.
-------------------------------------------------------------------------------

ExampleAppPropertyEditorMT = {}
ExampleAppPropertyEditorMT.__index = ExampleAppPropertyEditorMT
function ExampleAppPropertyEditor()
    local self = setmetatable({}, ExampleAppPropertyEditorMT)
    self.Filter = ImGuiTextFilter()
    self.SelectedNode = nil
    self.UseClipper = false
    self.StringBufs = setmetatable({}, { __mode = "k" }) -- [Port] node -> 28-byte edit buffer for ImGuiDataType.String fields (node.Name is a Lua string)
    return self
end

function ExampleAppPropertyEditorMT:Draw(root_node)
    IMGUI_DEMO_MARKER("Examples/Property editor")

    -- Left side: draw tree
    -- - Currently using a table to benefit from RowBg feature
    -- - Our tree node are all of equal height, facilitating the use of a clipper.
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
            if self.UseClipper then
                self:DrawClippedTree(root_node)
            else
                self:DrawTree(root_node)
            end
            ImGui.EndTable()
        end
    end
    ImGui.EndChild()

    -- Right side: draw properties
    ImGui.SameLine()

    ImGui.BeginGroup() -- Lock X position
    local node = self.SelectedNode
    if node then
        ImGui.Text("%s", node.Name)
        ImGui.TextDisabled("UID: 0x%08X", node.UID)
        ImGui.Separator()
        if ImGui.BeginTable("##properties", 2, bit32.bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.ScrollY)) then
            -- Push object ID after we entered the table, so table is shared for all objects
            ImGui.PushID(node.UID)
            ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthFixed)
            ImGui.TableSetupColumn("", ImGuiTableColumnFlags.WidthStretch, 2.0) -- Default twice larger
            if node.HasData then
                -- In a typical application, the structure description would be derived from a data-driven system.
                -- - We try to mimic this with our ExampleMemberInfo structure and the ExampleTreeNodeMemberInfos[] array.
                -- - Limits and some details are hard-coded to simplify the demo.
                for _, field_desc in ipairs(ExampleTreeNodeMemberInfos) do
                    ImGui.TableNextRow()
                    ImGui.PushID(field_desc.Name)
                    ImGui.TableNextColumn()
                    ImGui.AlignTextToFramePadding()
                    ImGui.TextUnformatted(field_desc.Name)
                    ImGui.TableNextColumn()
                    local field_ptr = field_desc.Offset -- [Port] Offset is the field name inside ExampleTreeNode
                    if field_desc.DataType == ImGuiDataType.Bool then
                        IM_ASSERT(field_desc.DataCount == 1)
                        _, node[field_ptr] = ImGui.Checkbox("##Editor", node[field_ptr])
                    elseif field_desc.DataType == ImGuiDataType.S32 then
                        local v_min, v_max = INT_MIN, INT_MAX
                        ImGui.SetNextItemWidth(-FLT_MIN)
                        if field_desc.DataCount == 1 then -- [Port] scalar fields are plain Lua values: DragScalar() returns the new value
                            node[field_ptr] = ImGui.DragScalar("##Editor", field_desc.DataType, node[field_ptr], 1.0, v_min, v_max)
                        else
                            ImGui.DragScalarN("##Editor", field_desc.DataType, node[field_ptr], field_desc.DataCount, 1.0, v_min, v_max)
                        end
                    elseif field_desc.DataType == ImGuiDataType.Float then
                        local v_min, v_max = 0.0, 1.0
                        ImGui.SetNextItemWidth(-FLT_MIN)
                        ImGui.SliderScalarN("##Editor", field_desc.DataType, node[field_ptr], field_desc.DataCount, v_min, v_max)
                    elseif field_desc.DataType == ImGuiDataType.String then
                        local buf = self.StringBufs[node] -- [Port] edit the Lua string through a 28-byte buffer
                        if buf == nil then buf = ImGui.NewTextBuffer(node[field_ptr], 28); self.StringBufs[node] = buf end
                        if ImGui.InputText("##Editor", buf, 28) then node[field_ptr] = ImGui.TextBufferToString(buf) end
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

-- Custom search filter
-- - Here we apply on root node only.
-- - This does a case insensitive stristr which is pretty heavy. In a real large-scale app you would likely store a filtered list which in turns would be trivial to linearize.
function ExampleAppPropertyEditorMT:IsNodePassingFilter(node)
    return node.Parent.Parent ~= nil or self.Filter:PassFilter(node.Name)
end

-- Basic version, recursive. This is how you would generally draw a tree.
-- - Simple but going to be noticeably costly if you have a large amount of nodes as DrawTreeNode() is called for all of them.
-- - On my desktop PC (2020), for 10K nodes in an optimized build this takes ~1.2 ms
-- - Unlike arrays or grids which are very easy to clip, trees are currently more difficult to clip.
function ExampleAppPropertyEditorMT:DrawTree(node)
    for _, child in ipairs(node.Childs) do
        if self:IsNodePassingFilter(child) and self:DrawTreeNode(child) then
            self:DrawTree(child)
            ImGui.TreePop()
        end
    end
end

-- More advanced version. Use a alternative clipping technique: fast-forwarding through non-visible chunks.
-- - On my desktop PC (2020), for 10K nodes in an optimized build this takes ~0.1 ms
--   (in ExampleTree_CreateDemoTree(), change 'int ROOT_ITEMS_COUNT = 10000' to try with this amount of root nodes).
-- - 1. Use clipper with indeterminate count (items_count = INT_MAX): we need to call SeekCursorForItem() at the end once we know the count.
-- - 2. Use SetNextItemStorageID() to specify ID used for open/close storage, making it easy to call TreeNodeGetOpen() on any arbitrary node.
-- - 3. Linearize tree during traversal: our tree data structure makes it easy to access sibling and parents.
-- - Unlike clipping for a regular array or grid which may be done using random access limited to visible areas,
--   this technique requires traversing most accessible nodes. This could be made more optimal with extra work,
--   but this is a decent simplicity<>speed trade-off.
-- See https://github.com/ocornut/imgui/issues/3823 for discussions about this.
function ExampleAppPropertyEditorMT:DrawClippedTree(root_node)
    local node = root_node.Childs[1] -- First node
    local clipper = ImGuiListClipper()
    clipper:Begin(INT_MAX)
    while clipper:Step() do
        while clipper.UserIndex < clipper.DisplayEnd and node ~= nil do
            node = self:DrawClippedTreeNodeAndAdvanceToNext(clipper, node)
        end
    end

    -- Keep going to count nodes and submit final count so we have a reliable scrollbar.
    -- - One could consider caching this value and only refreshing it occasionally e.g. window is focused and an action occurs.
    -- - Incorrect but cheap approximation would be to use 'clipper_current_idx = IM_MAX(clipper_current_idx, root_node.Childs.Size)' instead.
    -- - If either of those is implemented, the general cost will approach zero when scrolling is at the top of the tree.
    while node ~= nil do
        node = self:DrawClippedTreeNodeAndAdvanceToNext(clipper, node)
    end
    --clipper.UserIndex = IM_MAX(clipper.UserIndex, root_node.Childs.Size); // <-- Cheap approximation instead of while() loop above.
    clipper:SeekCursorForItem(clipper.UserIndex)
end

function ExampleAppPropertyEditorMT:DrawClippedTreeNodeAndAdvanceToNext(clipper, node)
    if self:IsNodePassingFilter(node) then
        -- Draw node if within visible range
        local is_open = false
        if clipper.UserIndex >= clipper.DisplayStart and clipper.UserIndex < clipper.DisplayEnd then
            is_open = self:DrawTreeNode(node)
        else
            is_open = (#node.Childs > 0 and ImGui.TreeNodeGetOpen(node.UID))
            if is_open then
                ImGui.TreePush(node.Name)
            end
        end
        clipper.UserIndex = clipper.UserIndex + 1

        -- Next node: recurse into childs
        if is_open then
            return node.Childs[1]
        end
    end

    -- Next node: next sibling, otherwise move back to parent
    while node ~= nil do
        if node.IndexInParent + 1 < #node.Parent.Childs then
            return node.Parent.Childs[node.IndexInParent + 1 + 1] -- [Port] Childs is 1-based, IndexInParent 0-based
        end
        node = node.Parent
        if node.Parent == nil then
            break
        end
        ImGui.TreePop()
    end
    return nil
end

-- To support node with same name we incorporate node.UID into the item ID.
-- (this would more naturally be done using PushID(node.UID) + TreeNodeEx(node.Name, tree_flags),
--   but it would require in DrawClippedTreeNodeAndAdvanceToNext() to add PushID() before TreePush(), and PopID() after TreePop(),
--   so instead we use TreeNodeEx(node.UID, tree_flags, "%s", node.Name) here)
function ExampleAppPropertyEditorMT:DrawTreeNode(node)
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    local tree_flags = ImGuiTreeNodeFlags.None
    tree_flags = bit32.bor(tree_flags, ImGuiTreeNodeFlags.OpenOnArrow, ImGuiTreeNodeFlags.OpenOnDoubleClick) -- Standard opening mode as we are likely to want to add selection afterwards
    tree_flags = bit32.bor(tree_flags, ImGuiTreeNodeFlags.NavLeftJumpsToParent)  -- Left arrow support
    tree_flags = bit32.bor(tree_flags, ImGuiTreeNodeFlags.SpanFullWidth)         -- Span full width for easier mouse reach
    tree_flags = bit32.bor(tree_flags, ImGuiTreeNodeFlags.DrawLinesToNodes)      -- Always draw hierarchy outlines
    if node == self.SelectedNode then
        tree_flags = bit32.bor(tree_flags, ImGuiTreeNodeFlags.Selected)          -- Draw selection highlight
    end
    if #node.Childs == 0 then
        tree_flags = bit32.bor(tree_flags, ImGuiTreeNodeFlags.Leaf, ImGuiTreeNodeFlags.Bullet, ImGuiTreeNodeFlags.NoTreePushOnOpen) -- Use _NoTreePushOnOpen + set is_open=false to avoid unnecessarily push/pop on leaves.
    end
    if node.DataMyBool == false then
        ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetStyle().Colors[ImGuiCol.TextDisabled])
    end
    ImGui.SetNextItemStorageID(node.UID)        -- Use node.UID as storage id
    local is_open = ImGui.TreeNodeEx(node.UID, tree_flags, "%s", node.Name)
    if #node.Childs == 0 then
        is_open = false
    end
    if node.DataMyBool == false then
        ImGui.PopStyleColor()
    end
    if ImGui.IsItemFocused() then
        self.SelectedNode = node
    end
    return is_open
end

-- Demonstrate creating a simple property editor.
S.ShowExampleAppPropertyEditor = {
    property_editor = nil, -- ExampleAppPropertyEditor, created on first use
    demo_data = nil,       -- [Port] fallback when called without demo_data
}
function ShowExampleAppPropertyEditor(p_open, demo_data)
    local s = S.ShowExampleAppPropertyEditor
    ImGui.SetNextWindowSize(ImVec2(430, 450), ImGuiCond.FirstUseEver)
    local visible
    p_open, visible = ImGui.Begin("Example: Property editor", p_open)
    if not visible then
        ImGui.End()
        return p_open
    end

    IMGUI_DEMO_MARKER("Examples/Property Editor")
    if s.property_editor == nil then s.property_editor = ExampleAppPropertyEditor() end
    if demo_data == nil then -- [Port] tolerate callers without demo_data (test harness)
        if s.demo_data == nil then s.demo_data = {} end
        demo_data = s.demo_data
    end
    if demo_data.DemoTree == nil then
        demo_data.DemoTree = ExampleTree_CreateDemoTree()
    end
    s.property_editor:Draw(demo_data.DemoTree)

    ImGui.End()
    return p_open
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Long Text / ShowExampleAppLongText()
-------------------------------------------------------------------------------

-- Demonstrate/test rendering huge amount of text, and the incidence of clipping.
S.ShowExampleAppLongText = {
    test_type = 0,
    log = ImGuiTextBuffer(),
    lines = 0,
}
function ShowExampleAppLongText(p_open)
    local s = S.ShowExampleAppLongText
    ImGui.SetNextWindowSize(ImVec2(520, 600), ImGuiCond.FirstUseEver)
    local visible
    p_open, visible = ImGui.Begin("Example: Long text display", p_open)
    if not visible then
        ImGui.End()
        return p_open
    end
    IMGUI_DEMO_MARKER("Examples/Long text display")

    ImGui.Text("Printing unusually long amount of text.")
    s.test_type = ImGui.Combo("Test type", s.test_type,
        "Single call to TextUnformatted()\0" ..
        "Multiple calls to Text(), clipped\0" ..
        "Multiple calls to Text(), not clipped (slow)\0")
    ImGui.Text("Buffer contents: %d lines, %d bytes", s.lines, s.log:size())
    if ImGui.Button("Clear") then s.log:clear(); s.lines = 0 end
    ImGui.SameLine()
    if ImGui.Button("Add 1000 lines") then
        for i = 0, 1000 - 1 do
            s.log:appendf("%i The quick brown fox jumps over the lazy dog\n", s.lines + i)
        end
        s.lines = s.lines + 1000
    end
    ImGui.BeginChild("Log")
    if s.test_type == 0 then
        -- Single call to TextUnformatted() with a big buffer
        ImGui.TextUnformatted(s.log:c_str()) -- [Port] ImGuiTextBuffer is a chunk list: c_str() instead of begin()/end()
    elseif s.test_type == 1 then
        -- Multiple calls to Text(), manually coarsely clipped - demonstrate how to use the ImGuiListClipper helper.
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
        local clipper = ImGuiListClipper()
        clipper:Begin(s.lines)
        while clipper:Step() do
            for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                ImGui.Text("%i The quick brown fox jumps over the lazy dog", i)
            end
        end
        ImGui.PopStyleVar()
    elseif s.test_type == 2 then
        -- Multiple calls to Text(), not clipped (slow)
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
        for i = 0, s.lines - 1 do
            ImGui.Text("%i The quick brown fox jumps over the lazy dog", i)
        end
        ImGui.PopStyleVar()
    end
    ImGui.EndChild()
    ImGui.End()
    return p_open
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Auto Resize / ShowExampleAppAutoResize()
-------------------------------------------------------------------------------

-- Demonstrate creating a window which gets auto-resized according to its content.
S.ShowExampleAppAutoResize = {
    lines = 10,
}
function ShowExampleAppAutoResize(p_open)
    local s = S.ShowExampleAppAutoResize
    local visible
    p_open, visible = ImGui.Begin("Example: Auto-resizing window", p_open, ImGuiWindowFlags.AlwaysAutoResize)
    if not visible then
        ImGui.End()
        return p_open
    end
    IMGUI_DEMO_MARKER("Examples/Auto-resizing window")

    ImGui.TextUnformatted(
        "Window will resize every-frame to the size of its content.\n" ..
        "Note that you probably don't want to query the window size to\n" ..
        "output your content because that would create a feedback loop.")
    s.lines = ImGui.SliderInt("Number of lines", s.lines, 1, 20)
    for i = 0, s.lines - 1 do
        ImGui.Text("%sThis is line %d", string.rep(" ", i * 4), i) -- Pad with space to extend size horizontally -- [Port] "%*s" -> string.rep
    end
    ImGui.End()
    return p_open
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Constrained Resize / ShowExampleAppConstrainedResize()
-------------------------------------------------------------------------------

-- Demonstrate creating a window with custom resize constraints.
-- Note that size constraints currently don't work on a docked window (when in 'docking' branch)
CustomConstraints = {}
-- Helper functions to demonstrate programmatic constraints
-- FIXME: This doesn't take account of decoration size (e.g. title bar), library should make this easier.
-- FIXME: None of the three demos works consistently when resizing from borders.
function CustomConstraints.AspectRatio(data)
    local aspect_ratio = data.UserData -- [Port] UserData is the number itself (no float*)
    data.DesiredSize.y = math.floor(data.DesiredSize.x / aspect_ratio)
end
function CustomConstraints.Square(data)
    local m = ImMax(data.DesiredSize.x, data.DesiredSize.y) -- [Port] IM_MAX -> ImMax
    data.DesiredSize.x = m; data.DesiredSize.y = m
end
function CustomConstraints.Step(data)
    local step = data.UserData
    data.DesiredSize = ImVec2(math.floor(data.DesiredSize.x / step + 0.5) * step, math.floor(data.DesiredSize.y / step + 0.5) * step)
end

S.ShowExampleAppConstrainedResize = {
    -- Options
    auto_resize = false,
    window_padding = true,
    type = 6, -- Aspect Ratio
    display_lines = 10,
}
function ShowExampleAppConstrainedResize(p_open)
    local s = S.ShowExampleAppConstrainedResize
    local test_desc =
    {
        "Between 100x100 and 500x500",
        "At least 100x100",
        "Resize vertical + lock current width",
        "Resize horizontal + lock current height",
        "Width Between 400 and 500",
        "Height at least 400",
        "Custom: Aspect Ratio 16:9",
        "Custom: Always Square",
        "Custom: Fixed Steps (100)",
    }

    -- Submit constraint
    local aspect_ratio = 16.0 / 9.0
    local fixed_step = 100.0
    if s.type == 0 then ImGui.SetNextWindowSizeConstraints(ImVec2(100, 100), ImVec2(500, 500)) end         -- Between 100x100 and 500x500
    if s.type == 1 then ImGui.SetNextWindowSizeConstraints(ImVec2(100, 100), ImVec2(FLT_MAX, FLT_MAX)) end -- Width > 100, Height > 100
    if s.type == 2 then ImGui.SetNextWindowSizeConstraints(ImVec2(-1, 0),    ImVec2(-1, FLT_MAX)) end      -- Resize vertical + lock current width
    if s.type == 3 then ImGui.SetNextWindowSizeConstraints(ImVec2(0, -1),    ImVec2(FLT_MAX, -1)) end      -- Resize horizontal + lock current height
    if s.type == 4 then ImGui.SetNextWindowSizeConstraints(ImVec2(400, -1),  ImVec2(500, -1)) end          -- Width Between and 400 and 500
    if s.type == 5 then ImGui.SetNextWindowSizeConstraints(ImVec2(-1, 400),  ImVec2(-1, FLT_MAX)) end      -- Height at least 400
    if s.type == 6 then ImGui.SetNextWindowSizeConstraints(ImVec2(0, 0),     ImVec2(FLT_MAX, FLT_MAX), CustomConstraints.AspectRatio, aspect_ratio) end   -- Aspect ratio
    if s.type == 7 then ImGui.SetNextWindowSizeConstraints(ImVec2(0, 0),     ImVec2(FLT_MAX, FLT_MAX), CustomConstraints.Square) end                      -- Always Square
    if s.type == 8 then ImGui.SetNextWindowSizeConstraints(ImVec2(0, 0),     ImVec2(FLT_MAX, FLT_MAX), CustomConstraints.Step, fixed_step) end            -- Fixed Step

    -- Submit window
    if not s.window_padding then
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(0.0, 0.0))
    end
    local window_flags = s.auto_resize and ImGuiWindowFlags.AlwaysAutoResize or 0
    local window_open
    p_open, window_open = ImGui.Begin("Example: Constrained Resize", p_open, window_flags)
    if not s.window_padding then
        ImGui.PopStyleVar()
    end
    IMGUI_DEMO_MARKER("Examples/Constrained Resizing window")
    if window_open then
        if ImGui.GetIO().KeyShift then
            -- Display a dummy viewport (in your real app you would likely use ImageButton() to display a texture)
            local avail_size = ImGui.GetContentRegionAvail()
            local pos = ImGui.GetCursorScreenPos()
            ImGui.ColorButton("viewport", ImVec4(0.5, 0.2, 0.5, 1.0), bit32.bor(ImGuiColorEditFlags.NoTooltip, ImGuiColorEditFlags.NoDragDrop), avail_size)
            ImGui.SetCursorScreenPos(ImVec2(pos.x + 10, pos.y + 10))
            ImGui.Text("%.2f x %.2f", avail_size.x, avail_size.y)
        else
            ImGui.Text("(Hold Shift to display a dummy viewport)")
            if ImGui.IsWindowDocked() then
                ImGui.Text("Warning: Sizing Constraints won't work if the window is docked!")
            end
            if ImGui.Button("Set 200x200") then ImGui.SetWindowSize(ImVec2(200, 200)) end ImGui.SameLine()
            if ImGui.Button("Set 500x500") then ImGui.SetWindowSize(ImVec2(500, 500)) end ImGui.SameLine()
            if ImGui.Button("Set 800x200") then ImGui.SetWindowSize(ImVec2(800, 200)) end
            ImGui.SetNextItemWidth(ImGui.GetFontSize() * 20)
            s.type = ImGui.Combo("Constraint", s.type, test_desc, #test_desc)
            ImGui.SetNextItemWidth(ImGui.GetFontSize() * 20)
            s.display_lines = ImGui.DragInt("Lines", s.display_lines, 0.2, 1, 100)
            _, s.auto_resize = ImGui.Checkbox("Auto-resize", s.auto_resize)
            _, s.window_padding = ImGui.Checkbox("Window padding", s.window_padding)
            for i = 0, s.display_lines - 1 do
                ImGui.Text("%sHello, sailor! Making this line long enough for the example.", string.rep(" ", i * 4)) -- [Port] "%*s" -> string.rep
            end
        end
    end
    ImGui.End()
    return p_open
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Simple overlay / ShowExampleAppSimpleOverlay()
-------------------------------------------------------------------------------

-- Demonstrate creating a simple static window with no decoration
-- + a context-menu to choose which corner of the screen to use.
S.ShowExampleAppSimpleOverlay = {
    location = 0,
}
function ShowExampleAppSimpleOverlay(p_open)
    local s = S.ShowExampleAppSimpleOverlay
    local io = ImGui.GetIO()
    local window_flags = bit32.bor(ImGuiWindowFlags.NoDecoration, ImGuiWindowFlags.NoDocking, ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoSavedSettings, ImGuiWindowFlags.NoFocusOnAppearing, ImGuiWindowFlags.NoNav)
    if s.location >= 0 then
        local PAD = 10.0
        local viewport = ImGui.GetMainViewport()
        local work_pos = viewport.WorkPos -- Use work area to avoid menu-bar/task-bar, if any!
        local work_size = viewport.WorkSize
        local window_pos, window_pos_pivot = ImVec2(), ImVec2()
        window_pos.x = (bit32.band(s.location, 1) ~= 0) and (work_pos.x + work_size.x - PAD) or (work_pos.x + PAD)
        window_pos.y = (bit32.band(s.location, 2) ~= 0) and (work_pos.y + work_size.y - PAD) or (work_pos.y + PAD)
        window_pos_pivot.x = (bit32.band(s.location, 1) ~= 0) and 1.0 or 0.0
        window_pos_pivot.y = (bit32.band(s.location, 2) ~= 0) and 1.0 or 0.0
        ImGui.SetNextWindowPos(window_pos, ImGuiCond.Always, window_pos_pivot)
        ImGui.SetNextWindowViewport(viewport.ID)
        window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoMove)
    elseif s.location == -2 then
        -- Center window
        ImGui.SetNextWindowPos(ImGui.GetMainViewport():GetCenter(), ImGuiCond.Always, ImVec2(0.5, 0.5))
        window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoMove)
    end
    ImGui.SetNextWindowBgAlpha(0.35) -- Transparent background
    local visible
    p_open, visible = ImGui.Begin("Example: Simple overlay", p_open, window_flags)
    if visible then
        IMGUI_DEMO_MARKER("Examples/Simple overlay") -- Scroll up to the beginning of this function to see overlay flags
        ImGui.Text("Simple overlay\n" .. "(right-click to change position)")
        ImGui.Separator()
        if ImGui.IsMousePosValid() then
            ImGui.Text("Mouse Position: (%.1f,%.1f)", io.MousePos.x, io.MousePos.y)
        else
            ImGui.Text("Mouse Position: <invalid>")
        end
        if ImGui.BeginPopupContextWindow() then
            if ImGui.MenuItem("Custom",       nil, s.location == -1) then s.location = -1 end
            if ImGui.MenuItem("Center",       nil, s.location == -2) then s.location = -2 end
            if ImGui.MenuItem("Top-left",     nil, s.location == 0) then s.location = 0 end
            if ImGui.MenuItem("Top-right",    nil, s.location == 1) then s.location = 1 end
            if ImGui.MenuItem("Bottom-left",  nil, s.location == 2) then s.location = 2 end
            if ImGui.MenuItem("Bottom-right", nil, s.location == 3) then s.location = 3 end
            if p_open ~= nil and ImGui.MenuItem("Close") then p_open = false end
            ImGui.EndPopup()
        end
    end
    ImGui.End()
    return p_open
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Fullscreen window / ShowExampleAppFullscreen()
-------------------------------------------------------------------------------

-- Demonstrate creating a window covering the entire screen/viewport
S.ShowExampleAppFullscreen = {
    use_work_area = true,
    flags = bit32.bor(ImGuiWindowFlags.NoDecoration, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoSavedSettings),
}
function ShowExampleAppFullscreen(p_open)
    local s = S.ShowExampleAppFullscreen

    -- We demonstrate using the full viewport area or the work area (without menu-bars, task-bars etc.)
    -- Based on your use case you may want one or the other.
    local viewport = ImGui.GetMainViewport()
    ImGui.SetNextWindowPos(s.use_work_area and viewport.WorkPos or viewport.Pos)
    ImGui.SetNextWindowSize(s.use_work_area and viewport.WorkSize or viewport.Size)

    local visible
    p_open, visible = ImGui.Begin("Example: Fullscreen window", p_open, s.flags)
    if visible then
        IMGUI_DEMO_MARKER("Examples/Fullscreen window")
        _, s.use_work_area = ImGui.Checkbox("Use work area instead of main area", s.use_work_area)
        ImGui.SameLine()
        HelpMarker("Main Area = entire viewport,\nWork Area = entire viewport minus sections used by the main menu bars, task bars etc.\n\nEnable the main-menu bar in Examples menu to see the difference.")

        _, s.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoBackground", s.flags, ImGuiWindowFlags.NoBackground)
        _, s.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoDecoration", s.flags, ImGuiWindowFlags.NoDecoration)
        ImGui.Indent()
        _, s.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoTitleBar", s.flags, ImGuiWindowFlags.NoTitleBar)
        _, s.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoCollapse", s.flags, ImGuiWindowFlags.NoCollapse)
        _, s.flags = ImGui.CheckboxFlags("ImGuiWindowFlags_NoScrollbar", s.flags, ImGuiWindowFlags.NoScrollbar)
        ImGui.Unindent()

        if p_open ~= nil and ImGui.Button("Close this window") then
            p_open = false
        end
    end
    ImGui.End()
    return p_open
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Manipulating Window Titles / ShowExampleAppWindowTitles()
-------------------------------------------------------------------------------

-- Demonstrate the use of "##" and "###" in identifiers to manipulate ID generation.
-- This applies to all regular items as well.
-- Read FAQ section "How can I have multiple widgets with the same label?" for details.
function ShowExampleAppWindowTitles(p_open)
    local viewport = ImGui.GetMainViewport()
    local base_pos = viewport.Pos

    -- By default, Windows are uniquely identified by their title.
    -- You can use the "##" and "###" markers to manipulate the display/ID.

    -- Using "##" to display same title but have unique identifier.
    ImGui.SetNextWindowPos(ImVec2(base_pos.x + 100, base_pos.y + 100), ImGuiCond.FirstUseEver)
    ImGui.Begin("Same title as another window##1")
    IMGUI_DEMO_MARKER("Examples/Manipulating window titles##1")
    ImGui.Text("This is window 1.\nMy title is the same as window 2, but my identifier is unique.")
    ImGui.End()

    ImGui.SetNextWindowPos(ImVec2(base_pos.x + 100, base_pos.y + 200), ImGuiCond.FirstUseEver)
    ImGui.Begin("Same title as another window##2")
    IMGUI_DEMO_MARKER("Examples/Manipulating window titles##2")
    ImGui.Text("This is window 2.\nMy title is the same as window 1, but my identifier is unique.")
    ImGui.End()

    -- Using "###" to display a changing title but keep a static identifier "AnimatedTitle"
    local spin_i = bit32.band(math.floor(ImGui.GetTime() / 0.25), 3) + 1
    local buf = string.format("Animated title %s %d###AnimatedTitle", string.sub("|/-\\", spin_i, spin_i), ImGui.GetFrameCount())
    ImGui.SetNextWindowPos(ImVec2(base_pos.x + 100, base_pos.y + 300), ImGuiCond.FirstUseEver)
    ImGui.Begin(buf)
    IMGUI_DEMO_MARKER("Examples/Manipulating window titles##3")
    ImGui.Text("This window has a changing title.")
    ImGui.End()
    return p_open
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Custom Rendering using ImDrawList API / ShowExampleAppCustomRendering()
-------------------------------------------------------------------------------

-- See our Wiki guides:
-- - ImDrawList Vector Rendering Reference: https://github.com/ocornut/imgui/wiki/Draw-List
-- - Pixel Perfect Anti-aliased Rendering: https://github.com/ocornut/imgui/wiki/Pixel-Perfect-Rendering
-- - How Anti-aliased Polyline Rendering is Implemented: https://github.com/ocornut/imgui/wiki/Polyline-Rendering

-- Demonstrate using the low-level ImDrawList to draw custom shapes.
S.ShowExampleAppCustomRendering = {
    -- Primitives
    sz = 42.0,
    base_rounding = 8.0,
    base_thickness = 3.0,
    animate_rounding = false,
    animate_thickness = false,
    ngon_segments = 6,
    circle_segments_override = false,
    circle_segments_override_v = 12,
    curve_segments_override = false,
    curve_segments_override_v = 8,
    colf_stroke = ImVec4(1.000, 0.384, 0.169, 1.000),
    colf_fill = ImVec4(0.416, 0.378, 0.420, 1.000),
    prim_stroke_flags = ImDrawFlags.None,
    prim_other_flags = ImDrawFlags.AALineEnds,
    scope_flags = nil, -- First init copy current state (see below).
    -- Canvas
    points = ImVector(),
    scrolling = ImVec2(0.0, 0.0),
    opt_enable_grid = true,
    opt_enable_context_menu = true,
    adding_line = false,
    -- BG/FG draw lists
    draw_bg = true,
    draw_fg = true,
}
function ShowExampleAppCustomRendering(p_open)
    local s = S.ShowExampleAppCustomRendering
    local visible
    p_open, visible = ImGui.Begin("Example: Custom rendering", p_open)
    if not visible then
        ImGui.End()
        return p_open
    end
    IMGUI_DEMO_MARKER("Examples/Custom rendering")

    -- Tip: If you do a lot of custom rendering, you probably want to use your own geometrical types and benefit of
    -- overloaded operators, etc. Define IM_VEC2_CLASS_EXTRA in imconfig.h to create implicit conversions between your
    -- types and ImVec2/ImVec4. Dear ImGui defines overloaded operators but they are internal to imgui.cpp and not
    -- exposed outside (to avoid messing with your types) In this example we are not using the maths operators!

    if ImGui.BeginTabBar("##TabBar") then
        if ImGui.BeginTabItem("Primitives") then
            IMGUI_DEMO_MARKER("Examples/Custom rendering/Primitives")
            ImGui.PushItemWidth(-ImGui.GetFontSize() * 15)
            ImGui.PushItemFlag(ImGuiItemFlags.LiveEditOnInput, true)
            local draw_list = ImGui.GetWindowDrawList()

            -- Draw gradients
            -- (note that those are currently exacerbating our sRGB/Linear issues)
            -- Calling ImGui.GetColorU32() multiplies the given colors by the current Style Alpha, but you may pass the IM_COL32() directly as well..
            -- [Port] GetColorU32(u32, nil, true): the ImU32 overload is selected explicitly
            ImGui.Text("Gradients")
            local gradient_size = ImVec2(ImGui.CalcItemWidth(), ImGui.GetFrameHeight())
            do
                ImGui.InvisibleButton("##gradient1", gradient_size)
                local col_a = ImGui.GetColorU32(IM_COL32(0, 0, 0, 255), nil, true)
                local col_b = ImGui.GetColorU32(IM_COL32(255, 255, 255, 255), nil, true)
                draw_list:AddRectFilledMultiColor(ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), col_a, col_b, col_b, col_a)
            end
            do
                ImGui.InvisibleButton("##gradient2", gradient_size)
                local col_a = ImGui.GetColorU32(IM_COL32(0, 255, 0, 255), nil, true)
                local col_b = ImGui.GetColorU32(IM_COL32(255, 0, 0, 255), nil, true)
                draw_list:AddRectFilledMultiColor(ImGui.GetItemRectMin(), ImGui.GetItemRectMax(), col_a, col_b, col_b, col_a)
            end

            -- Draw a bunch of primitives
            ImGui.Text("All primitives")

            s.sz = ImGui.DragFloat("Size", s.sz, 0.2, 0.2, 100.0, "%.0f")

            local rounding_anim_period = 3.0
            local rounding_wave = 1.0 - math.abs(math.fmod(ImGui.GetTime(), rounding_anim_period) * (2.0 / rounding_anim_period) - 1.0)
            local rounding = s.animate_rounding and math.floor(rounding_wave * s.base_rounding * 10.0) / 10.0 or s.base_rounding -- Sub-integer rounding works but has discontinuities in small values, so best disable we
            s.base_rounding = ImGui.DragFloat("Rounding", s.base_rounding, 0.02, 0.0, 32.0, "%.1f"); ImGui.SameLine()
            _, s.animate_rounding = ImGui.Checkbox("Animate##rounding", s.animate_rounding); ImGui.SameLine()
            ImGui.Text("%.2f", rounding)

            local thickness_anim_period = 5.0
            local thickness_wave = 1.0 - math.abs(math.fmod(ImGui.GetTime(), thickness_anim_period) * (2.0 / thickness_anim_period) - 1.0)
            local thickness = s.animate_thickness and thickness_wave * s.base_thickness or s.base_thickness
            s.base_thickness = ImGui.DragFloat("Thickness", s.base_thickness, 0.02, 0.0, 32.0, "%.02f"); ImGui.SameLine()
            _, s.animate_thickness = ImGui.Checkbox("Animate##thickness", s.animate_thickness); ImGui.SameLine()
            ImGui.Text("%.2f", thickness)

            local changed
            s.ngon_segments = ImGui.SliderInt("N-gon sides", s.ngon_segments, 3, 12)
            _, s.circle_segments_override = ImGui.Checkbox("##CircleSegmentOverride", s.circle_segments_override)
            ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
            s.circle_segments_override_v, changed = ImGui.SliderInt("Circle segments override", s.circle_segments_override_v, 3, 30)
            s.circle_segments_override = s.circle_segments_override or changed
            _, s.curve_segments_override = ImGui.Checkbox("##CurvesSegmentOverride", s.curve_segments_override)
            ImGui.SameLine(0.0, ImGui.GetStyle().ItemInnerSpacing.x)
            s.curve_segments_override_v, changed = ImGui.SliderInt("Curves segments override", s.curve_segments_override_v, 3, 30)
            s.curve_segments_override = s.curve_segments_override or changed
            ImGui.ColorEdit4("Stroke Color", s.colf_stroke)
            ImGui.ColorEdit4("Fill Color", s.colf_fill)

            ImGui.SeparatorText("Per primitive flags (AddXXX functions)")
            _, s.prim_stroke_flags = ImGui.RadioButton("Default", s.prim_stroke_flags, ImDrawFlags.None); ImGui.SameLine()
            _, s.prim_stroke_flags = ImGui.RadioButton("Inside", s.prim_stroke_flags, ImDrawFlags.StrokeInside); ImGui.SameLine()
            _, s.prim_stroke_flags = ImGui.RadioButton("Center", s.prim_stroke_flags, ImDrawFlags.StrokeCenter); ImGui.SameLine()
            _, s.prim_stroke_flags = ImGui.RadioButton("CenterBiased", s.prim_stroke_flags, ImDrawFlags.StrokeCenterBiased); ImGui.SameLine()
            _, s.prim_stroke_flags = ImGui.RadioButton("Outside", s.prim_stroke_flags, ImDrawFlags.StrokeOutside); ImGui.SameLine()
            _, s.prim_stroke_flags = ImGui.RadioButton("Legacy", s.prim_stroke_flags, ImDrawFlags.StrokeLegacy)
            _, s.prim_other_flags = ImGui.CheckboxFlags("AAFill", s.prim_other_flags, ImDrawFlags.AAFill); ImGui.SameLine() -- Note: Only for functions taking flags.
            _, s.prim_other_flags = ImGui.CheckboxFlags("AALines", s.prim_other_flags, ImDrawFlags.AALines); ImGui.SameLine() -- Note: Only for functions taking flags.
            _, s.prim_other_flags = ImGui.CheckboxFlags("AALineEnds", s.prim_other_flags, ImDrawFlags.AALineEnds); ImGui.SameLine()
            _, s.prim_other_flags = ImGui.CheckboxFlags("JoinMiter", s.prim_other_flags, ImDrawFlags.JoinMiter); ImGui.SameLine()
            _, s.prim_other_flags = ImGui.CheckboxFlags("CapSquare", s.prim_other_flags, ImDrawFlags.CapSquare)
            --ImGui.CheckboxFlags("UseTexForRoundCorners", &prim_other_flags, ImDrawFlags_UseTexForRoundCorners);

            if s.scope_flags == nil then s.scope_flags = bit32.band(draw_list.Flags, ImDrawFlags.AllowInPushScope_) end -- First init copy current state.
            ImGui.SeparatorText("Current ImDrawList flags (e.g. PushDrawFlag function)")
            ImGui.PushID("ScopeFlags")
            _, s.scope_flags = ImGui.CheckboxFlags("AAFill", s.scope_flags, ImDrawFlags.AAFill); ImGui.SameLine()
            _, s.scope_flags = ImGui.CheckboxFlags("AALines", s.scope_flags, ImDrawFlags.AALines); ImGui.SameLine()
            _, s.scope_flags = ImGui.CheckboxFlags("AALineEnds", s.scope_flags, ImDrawFlags.AALineEnds); ImGui.SameLine()
            _, s.scope_flags = ImGui.CheckboxFlags("StrokeLegacy", s.scope_flags, ImDrawFlags.StrokeLegacy)
            --ImGui.CheckboxFlags("UseTexForRoundCorners", &scope_flags, ImDrawFlags_UseTexForRoundCorners);
            ImGui.PopID()
            ImGui.Spacing()

            draw_list:PushDrawFlag(ImDrawFlags.AllowInPushScope_, false) -- Reset all existing (very unusual: done for this demo)
            draw_list:PushDrawFlag(s.scope_flags, true)
            local flags = bit32.bor(s.prim_stroke_flags, s.prim_other_flags)

            local sz = s.sz
            local start_pos = ImGui.GetCursorScreenPos()
            local pi = 3.141592
            local step = sz + 10.0
            local corners_tl_br = bit32.bor(ImDrawFlags.RoundTopLeft, ImDrawFlags.RoundBottomRight)
            local half_sz = sz * 0.5
            local circle_segments = s.circle_segments_override and s.circle_segments_override_v or 0
            local curve_segments = s.curve_segments_override and s.curve_segments_override_v or 0
            local cp3 = { ImVec2(0.0, sz * 0.6), ImVec2(sz * 0.5, -sz * 0.4), ImVec2(sz, sz) } -- Control points for curves
            local cp4 = { ImVec2(0.0, 0.0), ImVec2(sz * 1.3, sz * 0.3), ImVec2(sz - sz * 1.3, sz - sz * 0.3), ImVec2(sz, sz) }
            local concave_shape = { ImVec2(0.0, 0.0), ImVec2(0.3, 0.0), ImVec2(0.3, 0.7), ImVec2(0.7, 0.7), ImVec2(0.7, 0.0), ImVec2(1.0, 0.0), ImVec2(1.0, 1.0), ImVec2(0.0, 1.0) } -- |_| looking shape. Normalized.
            local zigzag_shape = { ImVec2(0.0, 0.0), ImVec2(0.9, 0.0), ImVec2(1.0, 0.1), ImVec2(1.0, 0.9), ImVec2(0.9, 1.0), ImVec2(0.3, 1.0), ImVec2(0.3, 0.4), ImVec2(0.9, 0.4) }
            local rotating_square = {} -- 1-based
            for side = 0, 4 - 1 do
                local t = ImGui.GetTime() * 0.1 + side * pi * 0.5
                rotating_square[side + 1] = ImVec2(math.cos(t) * half_sz, math.sin(t) * half_sz)
            end

            local x = start_pos.x
            local y = start_pos.y
            for row = 0, 4 - 1 do
                x = start_pos.x
                local draw_fill = (row == 2 or row == 3)
                local draw_strokes = (row == 0 or row == 1 or row == 3)
                if draw_fill then
                    -- FILLED SHAPES
                    local col = ImColor(s.colf_fill):U32()
                    draw_list:AddNgonFilled(ImVec2(x + half_sz, y + half_sz), half_sz, col, s.ngon_segments);                x = x + step  -- N-gon
                    draw_list:AddCircleFilled(ImVec2(x + half_sz, y + half_sz), half_sz, col, circle_segments);              x = x + step  -- Circle
                    draw_list:AddEllipseFilled(ImVec2(x + half_sz, y + half_sz), ImVec2(half_sz, sz * 0.3), col, -0.3, circle_segments); x = x + step -- Ellipse
                    draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + sz, y + sz), col, 0.0, flags);                          x = x + step  -- Square
                    draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + sz, y + sz), col, rounding, flags);                     x = x + step  -- Square with all rounded corners
                    draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + sz, y + sz), col, rounding, bit32.bor(flags, corners_tl_br)); x = x + step  -- Square with two rounded corners
                    draw_list:AddTriangleFilled(ImVec2(x + sz * 0.5, y), ImVec2(x + sz, y + sz), ImVec2(x, y + sz), col);    x = x + step  -- Triangle
                    draw_list:AddTriangleFilled(ImVec2(x + sz * 0.2, y), ImVec2(x + sz * 0.4, y + sz), ImVec2(x, y + sz), col); x = x + step - math.floor(sz * 0.6) -- Thin triangle

                    -- Concave shape: U
                    for _, p in ipairs(concave_shape) do
                        draw_list:PathLineTo(ImVec2(x + math.floor(sz * p.x), y + math.floor(sz * p.y)))
                    end
                    draw_list:PathFillConcave(col)
                    x = x + step

                    -- Concave shape: Zig-Zag with sharp angles (see difference with/without JoinMiter)
                    for _, p in ipairs(zigzag_shape) do
                        draw_list:PathLineTo(ImVec2(x + math.floor(sz * p.x), y + math.floor(sz * p.y)))
                    end
                    draw_list:PathFillConcave(col)
                    x = x + step

                    -- Horizontal/Vertical lines
                    -- (here for consistency with the strokes section. AddRectFilled() is roughly close to AddLineH(), AddLineV()
                    draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + sz, y + thickness), col); x = x + step
                    draw_list:AddRectFilled(ImVec2(x, y), ImVec2(x + thickness, y + sz), col); x = x + step - math.floor(half_sz)
                    if not (draw_fill and draw_strokes) then -- -V560
                        local block_sz, off = 1, 0
                        while block_sz < 16 and off + block_sz <= sz do
                            draw_list:AddRectFilled(ImVec2(x, y + off), ImVec2(x + block_sz, y + off + block_sz), col)
                            off = off + block_sz + 1; block_sz = block_sz + 1
                        end
                    end
                    x = x + step - math.floor(half_sz)

                    -- Rotating square
                    for n = 0, 4 - 1 do
                        draw_list:PathLineTo(ImVec2(x + half_sz + rotating_square[n + 1].x, y + half_sz + rotating_square[n + 1].y))
                    end
                    draw_list:PathFillConvex(col, flags)
                    x = x + step

                    -- Path
                    draw_list:PathArcTo(ImVec2(x + half_sz, y + half_sz), half_sz, pi * -0.5, pi * 1.1)
                    draw_list:PathFillConvex(col)
                    x = x + step

                    -- Quadratic Bezier Curve (3 control points)
                    draw_list:PathLineTo(ImVec2(x + cp3[1].x, y + cp3[1].y))
                    draw_list:PathBezierQuadraticCurveTo(ImVec2(x + cp3[2].x, y + cp3[2].y), ImVec2(x + cp3[3].x, y + cp3[3].y), curve_segments)
                    draw_list:PathFillConvex(col)
                    x = x + step

                    if not (draw_fill and draw_strokes) then -- -V560
                        draw_list:AddRectFilledMultiColor(ImVec2(x, y), ImVec2(x + sz, y + sz), IM_COL32(0, 0, 0, 255), IM_COL32(255, 0, 0, 255), IM_COL32(255, 255, 0, 255), IM_COL32(0, 255, 0, 255))
                        x = x + step
                    end
                end
                if draw_fill and draw_strokes then
                    x = start_pos.x
                end
                if draw_strokes then
                    -- STROKES
                    -- First row uses a thickness of 1.0f, second row uses the configurable thickness
                    local col = ImColor(s.colf_stroke):U32()
                    local th = (row == 0) and 1.0 or thickness
                    draw_list:AddNgon(ImVec2(x + half_sz, y + half_sz), half_sz, col, s.ngon_segments, th, flags);                 x = x + step  -- N-gon
                    draw_list:AddCircle(ImVec2(x + half_sz, y + half_sz), half_sz, col, circle_segments, th, flags);               x = x + step  -- Circle
                    draw_list:AddEllipse(ImVec2(x + half_sz, y + half_sz), ImVec2(half_sz, sz * 0.3), col, -0.3, circle_segments, th, flags); x = x + step  -- Ellipse
                    draw_list:AddRect(ImVec2(x, y), ImVec2(x + sz, y + sz), col, 0.0, th, flags);                           x = x + step  -- Square
                    draw_list:AddRect(ImVec2(x, y), ImVec2(x + sz, y + sz), col, rounding, th, flags);                      x = x + step  -- Square with all rounded corners
                    draw_list:AddRect(ImVec2(x, y), ImVec2(x + sz, y + sz), col, rounding, th, bit32.bor(flags, corners_tl_br)); x = x + step  -- Square with two rounded corners
                    draw_list:AddTriangle(ImVec2(x + sz * 0.5, y), ImVec2(x + sz, y + sz), ImVec2(x, y + sz), col, th, flags); x = x + step  -- Triangle
                    draw_list:AddTriangle(ImVec2(x + sz * 0.2, y), ImVec2(x + sz * 0.4, y + sz), ImVec2(x, y + sz), col, th, flags); x = x + step - math.floor(sz * 0.6) -- Thin triangle

                    -- Concave shape: U
                    for _, p in ipairs(concave_shape) do
                        draw_list:PathLineTo(ImVec2(x + math.floor(sz * p.x), y + math.floor(sz * p.y)))
                    end
                    draw_list:PathStroke(col, th, bit32.bor(flags, ImDrawFlags.Closed))
                    x = x + step

                    -- Concave shape: Zig-Zag with sharp angles (see difference with/without JoinMiter)
                    for _, p in ipairs(zigzag_shape) do
                        draw_list:PathLineTo(ImVec2(x + math.floor(sz * p.x), y + math.floor(sz * p.y)))
                    end
                    draw_list:PathStroke(col, th, bit32.bor(flags, ImDrawFlags.Closed))
                    x = x + step

                    -- Horizontal/Vertical/Diagonal lines
                    local off = math.floor(sz * 0.4)
                    draw_list:AddLineH(x, x + sz, y, col, th, flags)
                    draw_list:AddLine(ImVec2(x, y + off), ImVec2(x + sz, y + off), col, th, flags)
                    x = x + step
                    draw_list:AddLineV(x, y, y + sz, col, th, flags)
                    draw_list:AddLine(ImVec2(x + off, y + sz), ImVec2(x + off, y), col, th, flags)
                    x = x + step - math.floor(half_sz)
                    if not (draw_fill and draw_strokes) then -- -V560
                        draw_list:AddLine(ImVec2(x, y), ImVec2(x + half_sz, y + sz), col, th, flags)
                        draw_list:AddLine(ImVec2(x, y + sz), ImVec2(x + half_sz, y), col, th, flags)
                    end
                    x = x + step - math.floor(half_sz)

                    -- Rotating square
                    for n = 0, 4 - 1 do
                        draw_list:PathLineTo(ImVec2(x + half_sz + rotating_square[n + 1].x, y + half_sz + rotating_square[n + 1].y))
                    end
                    draw_list:PathStroke(col, th, bit32.bor(flags, ImDrawFlags.Closed))
                    --for (int n = 0; n < 4; n++) // ...made of individual line
                    --    draw_list->AddLine({ x + half_sz + rotating_square[n].x, y + half_sz + rotating_square[n].y }, { x + half_sz + rotating_square[(n + 1) & 3].x, y + half_sz + rotating_square[(n + 1) & 3].y }, col, th, flags);
                    x = x + step

                    -- Path
                    draw_list:PathArcTo(ImVec2(x + half_sz, y + half_sz), half_sz, pi * -0.5, pi * 1.1)
                    draw_list:PathStroke(col, th, flags)
                    x = x + step

                    -- Quadratic Bezier Curve (3 control points)
                    draw_list:AddBezierQuadratic(ImVec2(x + cp3[1].x, y + cp3[1].y), ImVec2(x + cp3[2].x, y + cp3[2].y), ImVec2(x + cp3[3].x, y + cp3[3].y), col, th, curve_segments, flags)
                    x = x + step

                    -- Cubic Bezier Curve (4 control points)
                    if not (draw_fill and draw_strokes) then -- -V560
                        draw_list:AddBezierCubic(ImVec2(x + cp4[1].x, y + cp4[1].y), ImVec2(x + cp4[2].x, y + cp4[2].y), ImVec2(x + cp4[3].x, y + cp4[3].y), ImVec2(x + cp4[4].x, y + cp4[4].y), col, th, curve_segments, flags)
                        x = x + step
                    end
                end
                y = y + step
            end

            ImGui.Dummy(ImVec2(step * 15.5, step * 4.0))
            draw_list:PopDrawFlag()
            draw_list:PopDrawFlag()

            ImGui.Text("ImDrawList Vector Rendering Reference:")
            ImGui.TextLinkOpenURL("https://github.com/ocornut/imgui/wiki/Draw-List")

            ImGui.PopItemFlag()
            ImGui.PopItemWidth()
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Canvas") then
            IMGUI_DEMO_MARKER("Examples/Custom rendering/Canvas")
            local points = s.points
            local scrolling = s.scrolling

            _, s.opt_enable_grid = ImGui.Checkbox("Enable grid", s.opt_enable_grid)
            _, s.opt_enable_context_menu = ImGui.Checkbox("Enable context menu", s.opt_enable_context_menu)
            ImGui.Text("Mouse Left: drag to add lines,\nMouse Right: drag to scroll, click for context menu.")

            -- Typically you would use a BeginChild()/EndChild() pair to benefit from a clipping region + own scrolling.
            -- Here we demonstrate that this can be replaced by simple offsetting + custom drawing + PushClipRect/PopClipRect() calls.
            -- To use a child window instead we could use, e.g:
            --      ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(0, 0))      -- Disable padding
            --      ImGui.PushStyleColor(ImGuiCol.ChildBg, IM_COL32(50, 50, 50, 255))  -- Set a background color
            --      ImGui.BeginChild("canvas", ImVec2(0.0, 0.0), ImGuiChildFlags.Borders, ImGuiWindowFlags.NoMove)
            --      ImGui.PopStyleColor()
            --      ImGui.PopStyleVar()
            --      [...]
            --      ImGui.EndChild()

            -- Using InvisibleButton() as a convenience 1) it will advance the layout cursor and 2) allows us to use IsItemHovered()/IsItemActive()
            local canvas_p0 = ImGui.GetCursorScreenPos()      -- ImDrawList API uses screen coordinates!
            local canvas_sz = ImGui.GetContentRegionAvail()   -- Resize canvas to what's available
            if canvas_sz.x < 50.0 then canvas_sz.x = 50.0 end
            if canvas_sz.y < 50.0 then canvas_sz.y = 50.0 end
            local canvas_p1 = ImVec2(canvas_p0.x + canvas_sz.x, canvas_p0.y + canvas_sz.y)

            -- Draw border and background color
            local io = ImGui.GetIO()
            local draw_list = ImGui.GetWindowDrawList()
            draw_list:AddRectFilled(canvas_p0, canvas_p1, IM_COL32(50, 50, 50, 255))
            draw_list:AddRect(canvas_p0, canvas_p1, IM_COL32(255, 255, 255, 255))

            -- This will catch our interactions
            ImGui.InvisibleButton("canvas", canvas_sz, bit32.bor(ImGuiButtonFlags.MouseButtonLeft, ImGuiButtonFlags.MouseButtonRight))
            local is_hovered = ImGui.IsItemHovered() -- Hovered
            local is_active = ImGui.IsItemActive()   -- Held
            local origin = ImVec2(canvas_p0.x + scrolling.x, canvas_p0.y + scrolling.y) -- Lock scrolled origin
            local mouse_pos_in_canvas = ImVec2(io.MousePos.x - origin.x, io.MousePos.y - origin.y)

            -- Add first and second point
            if is_hovered and not s.adding_line and ImGui.IsMouseClicked(ImGuiMouseButton.Left) then
                points:push_back(ImVec2(mouse_pos_in_canvas.x, mouse_pos_in_canvas.y)) -- [Port] copies: ImVector stores references
                points:push_back(ImVec2(mouse_pos_in_canvas.x, mouse_pos_in_canvas.y))
                s.adding_line = true
            end
            if s.adding_line then
                ImVec2_Copy(points:back(), mouse_pos_in_canvas)
                if not ImGui.IsMouseDown(ImGuiMouseButton.Left) then
                    s.adding_line = false
                end
            end

            -- Pan (we use a zero mouse threshold when there's no context menu)
            -- You may decide to make that threshold dynamic based on whether the mouse is hovering something etc.
            local mouse_threshold_for_pan = s.opt_enable_context_menu and -1.0 or 0.0
            if is_active and ImGui.IsMouseDragging(ImGuiMouseButton.Right, mouse_threshold_for_pan) then
                scrolling.x = scrolling.x + io.MouseDelta.x
                scrolling.y = scrolling.y + io.MouseDelta.y
            end

            -- Context menu (under default mouse threshold)
            local drag_delta = ImGui.GetMouseDragDelta(ImGuiMouseButton.Right)
            if s.opt_enable_context_menu and drag_delta.x == 0.0 and drag_delta.y == 0.0 then
                ImGui.OpenPopupOnItemClick("context", ImGuiPopupFlags.MouseButtonRight)
            end
            if ImGui.BeginPopup("context") then
                if s.adding_line then
                    points:resize(points.Size - 2)
                end
                s.adding_line = false
                if ImGui.MenuItem("Remove one", nil, false, points.Size > 0) then points:resize(points.Size - 2) end
                if ImGui.MenuItem("Remove all", nil, false, points.Size > 0) then points:clear() end
                ImGui.EndPopup()
            end

            -- Draw grid + all lines in the canvas
            draw_list:PushClipRect(canvas_p0, canvas_p1, true)
            if s.opt_enable_grid then
                local GRID_STEP = 64.0
                local x = math.fmod(scrolling.x, GRID_STEP)
                while x < canvas_sz.x do
                    draw_list:AddLineV(canvas_p0.x + x, canvas_p0.y, canvas_p1.y, IM_COL32(200, 200, 200, 40))
                    x = x + GRID_STEP
                end
                local y = math.fmod(scrolling.y, GRID_STEP)
                while y < canvas_sz.y do
                    draw_list:AddLineH(canvas_p0.x, canvas_p1.x, canvas_p0.y + y, IM_COL32(200, 200, 200, 40))
                    y = y + GRID_STEP
                end
            end
            for n = 0, points.Size - 1, 2 do
                draw_list:AddLine(ImVec2(origin.x + points.Data[n + 1].x, origin.y + points.Data[n + 1].y), ImVec2(origin.x + points.Data[n + 2].x, origin.y + points.Data[n + 2].y), IM_COL32(255, 255, 0, 255), 2.0)
            end
            draw_list:PopClipRect()

            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("BG/FG draw lists") then
            IMGUI_DEMO_MARKER("Examples/Custom rendering/BG & FG draw lists")
            _, s.draw_bg = ImGui.Checkbox("Draw in Background draw list", s.draw_bg)
            ImGui.SameLine(); HelpMarker("The Background draw list will be rendered below every Dear ImGui windows.")
            _, s.draw_fg = ImGui.Checkbox("Draw in Foreground draw list", s.draw_fg)
            ImGui.SameLine(); HelpMarker("The Foreground draw list will be rendered over every Dear ImGui windows.")
            local window_pos = ImGui.GetWindowPos()
            local window_size = ImGui.GetWindowSize()
            local window_center = ImVec2(window_pos.x + window_size.x * 0.5, window_pos.y + window_size.y * 0.5)
            if s.draw_bg then
                ImGui.GetBackgroundDrawList():AddCircle(window_center, window_size.x * 0.6, IM_COL32(255, 0, 0, 200), 0, 10 + 4)
            end
            if s.draw_fg then
                ImGui.GetForegroundDrawList():AddCircle(window_center, window_size.y * 0.6, IM_COL32(0, 255, 0, 200), 0, 10)
            end
            ImGui.EndTabItem()
        end

        -- Demonstrate out-of-order rendering via channels splitting
        -- We use functions in ImDrawList as each draw list contains a convenience splitter,
        -- but you can also instantiate your own ImDrawListSplitter if you need to nest them.
        if ImGui.BeginTabItem("Draw Channels") then
            IMGUI_DEMO_MARKER("Examples/Custom rendering/Draw Channels")
            local draw_list = ImGui.GetWindowDrawList()
            do
                ImGui.Text("Blue shape is drawn first: appears in back")
                ImGui.Text("Red shape is drawn after: appears in front")
                local p0 = ImGui.GetCursorScreenPos()
                draw_list:AddRectFilled(ImVec2(p0.x, p0.y), ImVec2(p0.x + 50, p0.y + 50), IM_COL32(0, 0, 255, 255)) -- Blue
                draw_list:AddRectFilled(ImVec2(p0.x + 25, p0.y + 25), ImVec2(p0.x + 75, p0.y + 75), IM_COL32(255, 0, 0, 255)) -- Red
                ImGui.Dummy(ImVec2(75, 75))
            end
            ImGui.Separator()
            do
                ImGui.Text("Blue shape is drawn first, into channel 1: appears in front")
                ImGui.Text("Red shape is drawn after, into channel 0: appears in back")
                local p1 = ImGui.GetCursorScreenPos()

                -- Create 2 channels and draw a Blue shape THEN a Red shape.
                -- You can create any number of channels. Tables API use 1 channel per column in order to better batch draw calls.
                draw_list:ChannelsSplit(2)
                draw_list:ChannelsSetCurrent(1)
                draw_list:AddRectFilled(ImVec2(p1.x, p1.y), ImVec2(p1.x + 50, p1.y + 50), IM_COL32(0, 0, 255, 255)) -- Blue
                draw_list:ChannelsSetCurrent(0)
                draw_list:AddRectFilled(ImVec2(p1.x + 25, p1.y + 25), ImVec2(p1.x + 75, p1.y + 75), IM_COL32(255, 0, 0, 255)) -- Red

                -- Flatten/reorder channels. Red shape is in channel 0 and it appears below the Blue shape in channel 1.
                -- This works by copying draw indices only (vertices are not copied).
                draw_list:ChannelsMerge()
                ImGui.Dummy(ImVec2(75, 75))
                ImGui.Text("After reordering, contents of channel 0 appears below channel 1.")
            end
            ImGui.EndTabItem()
        end

        ImGui.EndTabBar()
    end

    ImGui.End()
    return p_open
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Docking, DockSpace / ShowExampleAppDockSpace()
-------------------------------------------------------------------------------

function ImGuiDemoDockspaceArgs()
    return {
        IsFullscreen = true,
        KeepWindowPadding = false, -- Keep WindowPadding to help understand that DockSpace() is a widget inside the window.
        DockSpaceFlags = ImGuiDockNodeFlags.None,
    }
end

-- THIS IS A DEMO FOR ADVANCED USAGE OF DockSpace().
-- MOST REGULAR APPLICATIONS WANTING TO ALLOW DOCKING WINDOWS ON THE EDGE OF YOUR SCREEN CAN SIMPLY USE:
--    ImGui.NewFrame(); + ImGui.DockSpaceOverViewport();                                                   -- Create a dockspace in main viewport
-- OR:
--    ImGui.NewFrame(); + ImGui.DockSpaceOverViewport(0, nil, ImGuiDockNodeFlags.PassthruCentralNode); -- Create a dockspace in main viewport, where central node is transparent.
-- Demonstrate using DockSpace() to create an explicit docking node within an existing window, with various options.
-- Read https://github.com/ocornut/imgui/wiki/Docking for details.
-- The reasons we do not use DockSpaceOverViewport() in this demo is because:
-- - (1) we allow the host window to be floating/moveable instead of filling the viewport (when args.IsFullscreen == false)
--       which is mostly to showcase the idea that DockSpace() may be submitted anywhere.
--       Also see 'Demo->Examples->Documents' for a less abstract version of this.
-- - (2) we allow the host window to have padding (when args.UsePadding == true)
-- - (3) we expose variety of other flags.
function ShowExampleAppDockSpaceAdvanced(args, p_open)
    local dockspace_flags = args.DockSpaceFlags

    -- We are using the ImGuiWindowFlags.NoDocking flag to make the parent window not dockable into,
    -- because it would be confusing to have two docking targets within each others.
    local window_flags = ImGuiWindowFlags.NoDocking
    if args.IsFullscreen then
        -- Fullscreen dockspace: practically the same as calling DockSpaceOverViewport();
        local viewport = ImGui.GetMainViewport()
        ImGui.SetNextWindowPos(viewport.WorkPos)
        ImGui.SetNextWindowSize(viewport.WorkSize)
        ImGui.SetNextWindowViewport(viewport.ID)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 0.0)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 0.0)
        window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoMove)
        window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoBringToFrontOnFocus, ImGuiWindowFlags.NoNavFocus)
        window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoBackground)
    else
        -- Floating dockspace
        dockspace_flags = bit32.band(dockspace_flags, bit32.bnot(ImGuiDockNodeFlags.PassthruCentralNode))
    end

    -- Important: note that we proceed even if Begin() returns false (aka window is collapsed).
    -- This is because we want to keep our DockSpace() active. If a DockSpace() is inactive,
    -- all active windows docked into it will lose their parent and become undocked.
    -- We cannot preserve the docking relationship between an active window and an inactive docking, otherwise
    -- any change of dockspace/settings would lead to windows being stuck in limbo and never being visible.
    if not args.KeepWindowPadding then
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(0.0, 0.0))
    end
    p_open = ImGui.Begin("Window with a DockSpace", p_open, window_flags)
    if not args.KeepWindowPadding then
        ImGui.PopStyleVar()
    end

    if args.IsFullscreen then
        ImGui.PopStyleVar(2)
    end

    -- Submit the DockSpace widget inside our window
    -- - Note that the id here is different from the one used by DockSpaceOverViewport(), so docking state won't get transfered between "Basic" and "Advanced" demos.
    -- - If we made the ShowExampleAppDockSpaceBasic() calculate its own ID and pass it to DockSpaceOverViewport() the ID could easily match.
    local dockspace_id = ImGui.GetID("MyDockSpace")
    ImGui.DockSpace(dockspace_id, ImVec2(0.0, 0.0), dockspace_flags)

    ImGui.End()
    return p_open
end

function ShowExampleAppDockSpaceBasic(flags)
    -- Basic version which you can use in many apps:
    -- e.g:
    --   ImGui.DockSpaceOverViewport();
    -- or:
    --   ImGui.DockSpaceOverViewport(0, nil, ImGuiDockNodeFlags.PassthruCentralNode); -- Central node will be transparent
    -- or:
    --   local viewport = ImGui.GetMainViewport();
    --   ImGui.DockSpaceOverViewport(0, viewport, ImGuiDockNodeFlags.None);

    ImGui.DockSpaceOverViewport(0, nil, flags)
end

S.ShowExampleAppDockSpace = {
    opt_demo_mode = 0,
    opt_demo_mode_changed = false,
    args = ImGuiDemoDockspaceArgs(),
}
function ShowExampleAppDockSpace(p_open)
    local s = S.ShowExampleAppDockSpace
    local args = s.args

    if s.opt_demo_mode == 0 then
        ShowExampleAppDockSpaceBasic(args.DockSpaceFlags)
    else
        p_open = ShowExampleAppDockSpaceAdvanced(args, p_open)
    end

    -- Refocus our window to minimize perceived loss of focus when changing mode (caused by the fact that each use a different window, which would not happen in a real app)
    if s.opt_demo_mode_changed then
        ImGui.SetNextWindowFocus()
    end
    p_open = ImGui.Begin("Examples: Dockspace", p_open, ImGuiWindowFlags.MenuBar)
    s.opt_demo_mode_changed = false
    local pressed
    pressed, s.opt_demo_mode = ImGui.RadioButton("Basic demo mode", s.opt_demo_mode, 0)
    s.opt_demo_mode_changed = s.opt_demo_mode_changed or pressed
    pressed, s.opt_demo_mode = ImGui.RadioButton("Advanced demo mode", s.opt_demo_mode, 1)
    s.opt_demo_mode_changed = s.opt_demo_mode_changed or pressed

    ImGui.SeparatorText("Options")

    if bit32.band(ImGui.GetIO().ConfigFlags, ImGuiConfigFlags.DockingEnable) == 0 then
        ShowDockingDisabledMessage()
    elseif s.opt_demo_mode == 0 then
        args.DockSpaceFlags = bit32.band(args.DockSpaceFlags, ImGuiDockNodeFlags.PassthruCentralNode) -- Allowed flags
        _, args.DockSpaceFlags = ImGui.CheckboxFlags("Flag: PassthruCentralNode", args.DockSpaceFlags, ImGuiDockNodeFlags.PassthruCentralNode)
    elseif s.opt_demo_mode == 1 then
        _, args.IsFullscreen = ImGui.Checkbox("Fullscreen", args.IsFullscreen)
        _, args.KeepWindowPadding = ImGui.Checkbox("Keep Window Padding", args.KeepWindowPadding)
        ImGui.SameLine()
        HelpMarker("This is mostly exposed to facilitate understanding that a DockSpace() is _inside_ a window.")
        ImGui.BeginDisabled(args.IsFullscreen == false)
        _, args.DockSpaceFlags = ImGui.CheckboxFlags("Flag: PassthruCentralNode",      args.DockSpaceFlags, ImGuiDockNodeFlags.PassthruCentralNode)
        ImGui.EndDisabled()
        _, args.DockSpaceFlags = ImGui.CheckboxFlags("Flag: NoDockingOverCentralNode", args.DockSpaceFlags, ImGuiDockNodeFlags.NoDockingOverCentralNode)
        _, args.DockSpaceFlags = ImGui.CheckboxFlags("Flag: NoDockingSplit",           args.DockSpaceFlags, ImGuiDockNodeFlags.NoDockingSplit)
        _, args.DockSpaceFlags = ImGui.CheckboxFlags("Flag: NoUndocking",              args.DockSpaceFlags, ImGuiDockNodeFlags.NoUndocking)
        _, args.DockSpaceFlags = ImGui.CheckboxFlags("Flag: NoResize",                 args.DockSpaceFlags, ImGuiDockNodeFlags.NoResize)
        _, args.DockSpaceFlags = ImGui.CheckboxFlags("Flag: AutoHideTabBar",           args.DockSpaceFlags, ImGuiDockNodeFlags.AutoHideTabBar)
    end

    -- Show demo options and help
    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu("Help") then
            ImGui.TextUnformatted(
                "This demonstrates the use of ImGui::DockSpace() which allows you to manually\ncreate a docking node _within_ another window." .. "\n" ..
                "The \"Basic\" version uses the ImGui::DockSpaceOverViewport() helper. Most applications can probably use this.")
            ImGui.Separator()
            ImGui.TextUnformatted("When docking is enabled, you can ALWAYS dock MOST window into another! Try it now!" .. "\n" ..
                "- Drag from window title bar or their tab to dock/undock." .. "\n" ..
                "- Drag from window menu button (upper-left button) to undock an entire node (all windows)." .. "\n" ..
                "- Hold SHIFT to disable docking (if io.ConfigDockingWithShift == false, default)" .. "\n" ..
                "- Hold SHIFT to enable docking (if io.ConfigDockingWithShift == true)")
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

-------------------------------------------------------------------------------
-- [SECTION] Example App: Documents Handling / ShowExampleAppDocuments()
-------------------------------------------------------------------------------

-- Simplified structure to mimic a Document model
--   Name      Document title -- [Port] char[32] text buffer, read with ImGui.TextBufferToString()
--   UID       Unique ID (necessary as we can change title)
--   Open      Set when open (we keep an array of all available documents to simplify demo code!)
--   OpenPrev  Copy of Open from last update.
--   Dirty     Set when the document has been modified
--   Color     An arbitrary variable associated to the document
local MyDocumentMT = {}
MyDocumentMT.__index = MyDocumentMT
function MyDocument(uid, name, open, color)
    if open == nil then open = true end
    if color == nil then color = ImVec4(1.0, 1.0, 1.0, 1.0) end
    local self = setmetatable({}, MyDocumentMT)
    self.UID = uid
    self.Name = ImGui.NewTextBuffer(name, 32)
    self.Open = open; self.OpenPrev = open
    self.Dirty = false
    self.Color = color
    return self
end
function MyDocumentMT:DoOpen()       self.Open = true end
function MyDocumentMT:DoForceClose() self.Open = false; self.Dirty = false end
function MyDocumentMT:DoSave()       self.Dirty = false end

local ExampleAppDocumentsMT = {}
ExampleAppDocumentsMT.__index = ExampleAppDocumentsMT
function ExampleAppDocuments()
    local self = setmetatable({}, ExampleAppDocumentsMT)
    self.Documents = ImVector()
    self.CloseQueue = ImVector()
    self.RenamingDoc = nil
    self.RenamingStarted = false

    self.Documents:push_back(MyDocument(0, "Lettuce",             true,  ImVec4(0.4, 0.8, 0.4, 1.0)))
    self.Documents:push_back(MyDocument(1, "Eggplant",            true,  ImVec4(0.8, 0.5, 1.0, 1.0)))
    self.Documents:push_back(MyDocument(2, "Carrot",              true,  ImVec4(1.0, 0.8, 0.5, 1.0)))
    self.Documents:push_back(MyDocument(3, "Tomato",              false, ImVec4(1.0, 0.3, 0.4, 1.0)))
    self.Documents:push_back(MyDocument(4, "A Rather Long Title", false, ImVec4(0.4, 0.8, 0.8, 1.0)))
    self.Documents:push_back(MyDocument(5, "Some Document",       false, ImVec4(0.8, 0.8, 1.0, 1.0)))
    return self
end

-- As we allow to change document name, we append a never-changing document ID so tabs are stable
function ExampleAppDocumentsMT:GetTabName(doc) -- [Port] returns the string instead of filling out_buf
    return string.format("%s###doc%d", ImGui.TextBufferToString(doc.Name), doc.UID)
end

-- Display placeholder contents for the Document
function ExampleAppDocumentsMT:DisplayDocContents(doc)
    ImGui.PushID(doc.UID) -- [Port] PushID(doc): no pointer IDs, UID is unique
    ImGui.Text("Document \"%s\"", ImGui.TextBufferToString(doc.Name))
    ImGui.PushStyleColor(ImGuiCol.Text, doc.Color)
    ImGui.TextWrapped("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
    ImGui.PopStyleColor()

    ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.R), ImGuiInputFlags.Tooltip)
    if ImGui.Button("Rename..") then
        self.RenamingDoc = doc
        self.RenamingStarted = true
    end
    ImGui.SameLine()

    ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.M), ImGuiInputFlags.Tooltip)
    if ImGui.Button("Modify") then
        doc.Dirty = true
    end

    ImGui.SameLine()
    ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.S), ImGuiInputFlags.Tooltip)
    if ImGui.Button("Save") then
        doc:DoSave()
    end

    ImGui.SameLine()
    ImGui.SetNextItemShortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.W), ImGuiInputFlags.Tooltip)
    if ImGui.Button("Close") then
        self.CloseQueue:push_back(doc)
    end
    ImGui.ColorEdit3("color", doc.Color)  -- Useful to test drag and drop and hold-dragged-to-open-tab behavior.
    ImGui.PopID()
end

-- Display context menu for the Document
function ExampleAppDocumentsMT:DisplayDocContextMenu(doc)
    if not ImGui.BeginPopupContextItem() then
        return
    end

    local buf = string.format("Save %s", ImGui.TextBufferToString(doc.Name))
    if ImGui.MenuItem(buf, "Ctrl+S", false, doc.Open) then
        doc:DoSave()
    end
    if ImGui.MenuItem("Rename...", "Ctrl+R", false, doc.Open) then
        self.RenamingDoc = doc
    end
    if ImGui.MenuItem("Close", "Ctrl+W", false, doc.Open) then
        self.CloseQueue:push_back(doc)
    end
    ImGui.EndPopup()
end

-- [Optional] Notify the system of Tabs/Windows closure that happened outside the regular tab interface.
-- If a tab has been closed programmatically (aka closed from another source such as the Checkbox() in the demo,
-- as opposed to clicking on the regular tab closing button) and stops being submitted, it will take a frame for
-- the tab bar to notice its absence. During this frame there will be a gap in the tab bar, and if the tab that has
-- disappeared was the selected one, the tab bar will report no selected tab during the frame. This will effectively
-- give the impression of a flicker for one frame.
-- We call SetTabItemClosed() to manually notify the Tab Bar or Docking system of removed tabs to avoid this glitch.
-- Note that this completely optional, and only affect tab bars with the ImGuiTabBarFlags.Reorderable flag.
function ExampleAppDocumentsMT:NotifyOfDocumentsClosedElsewhere()
    for _, doc in self.Documents:iter() do
        if not doc.Open and doc.OpenPrev then
            ImGui.SetTabItemClosed(ImGui.TextBufferToString(doc.Name))
        end
        doc.OpenPrev = doc.Open
    end
end

S.ShowExampleAppDocuments = {
    app = ExampleAppDocuments(),
    opt_target = nil,           -- set below to Target_Tab
    opt_reorderable = true,
    opt_fitting_flags = nil,    -- set below to ImGuiTabBarFlags.FittingPolicyDefault_
}
function ShowExampleAppDocuments(p_open)
    local s = S.ShowExampleAppDocuments
    local app = s.app

    -- Options
    local Target_None = 0
    local Target_Tab = 1                -- Create documents as local tab into a local tab bar
    local Target_DockSpaceAndWindow = 2 -- Create documents as regular windows, and create an embedded dockspace
    if s.opt_target == nil then s.opt_target = Target_Tab end
    if s.opt_fitting_flags == nil then s.opt_fitting_flags = ImGuiTabBarFlags.FittingPolicyDefault_ end

    -- When (opt_target == Target_DockSpaceAndWindow) there is the possibily that one of our child Document window (e.g. "Eggplant")
    -- that we emit gets docked into the same spot as the parent window ("Example: Documents").
    -- This would create a problematic feedback loop because selecting the "Eggplant" tab would make the "Example: Documents" tab
    -- not visible, which in turn would stop submitting the "Eggplant" window.
    -- We avoid this problem by submitting our documents window even if our parent window is not currently visible.
    -- Another solution may be to make the "Example: Documents" window use the ImGuiWindowFlags.NoDocking.

    local window_contents_visible
    p_open, window_contents_visible = ImGui.Begin("Example: Documents", p_open, ImGuiWindowFlags.MenuBar)
    if not window_contents_visible and s.opt_target ~= Target_DockSpaceAndWindow then
        ImGui.End()
        return p_open
    end
    IMGUI_DEMO_MARKER("Examples/Documents")

    -- Menu
    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu("File") then
            local open_count = 0
            for _, doc in app.Documents:iter() do
                open_count = open_count + (doc.Open and 1 or 0)
            end

            if ImGui.BeginMenu("Open", open_count < app.Documents.Size) then
                for _, doc in app.Documents:iter() do
                    if not doc.Open and ImGui.MenuItem(ImGui.TextBufferToString(doc.Name)) then
                        doc:DoOpen()
                    end
                end
                ImGui.EndMenu()
            end
            if ImGui.MenuItem("Close All Documents", nil, false, open_count > 0) then
                for _, doc in app.Documents:iter() do
                    app.CloseQueue:push_back(doc)
                end
            end
            if ImGui.MenuItem("Exit") and p_open ~= nil then
                p_open = false
            end
            ImGui.EndMenu()
        end
        ImGui.EndMenuBar()
    end

    -- [Debug] List documents with one checkbox for each
    for doc_n = 0, app.Documents.Size - 1 do
        local doc = app.Documents.Data[doc_n + 1]
        if doc_n > 0 then
            ImGui.SameLine()
        end
        ImGui.PushID(doc.UID) -- [Port] PushID(&doc): no pointer IDs, UID is unique
        local pressed
        pressed, doc.Open = ImGui.Checkbox(ImGui.TextBufferToString(doc.Name), doc.Open)
        if pressed then
            if not doc.Open then
                doc:DoForceClose()
            end
        end
        ImGui.PopID()
    end
    ImGui.PushItemWidth(ImGui.GetFontSize() * 12)
    s.opt_target = ImGui.Combo("Output", s.opt_target, "None\0TabBar+Tabs\0DockSpace+Window\0")
    ImGui.PopItemWidth()
    local redock_all = false
    if s.opt_target == Target_Tab                then ImGui.SameLine(); _, s.opt_reorderable = ImGui.Checkbox("Reorderable Tabs", s.opt_reorderable) end
    if s.opt_target == Target_DockSpaceAndWindow then ImGui.SameLine(); redock_all = ImGui.Button("Redock all") end

    ImGui.Separator()

    -- About the ImGuiWindowFlags.UnsavedDocument / ImGuiTabItemFlags.UnsavedDocument flags.
    -- They have multiple effects:
    -- - Display a dot next to the title.
    -- - Tab is selected when clicking the X close button.
    -- - Closure is not assumed (will wait for user to stop submitting the tab).
    --   Otherwise closure is assumed when pressing the X, so if you keep submitting the tab may reappear at end of tab bar.
    --   We need to assume closure by default otherwise waiting for "lack of submission" on the next frame would leave an empty
    --   hole for one-frame, both in the tab-bar and in tab-contents when closing a tab/window.
    --   The rarely used SetTabItemClosed() function is a way to notify of programmatic closure to avoid the one-frame hole.

    -- Tabs
    if s.opt_target == Target_Tab then
        local tab_bar_flags = bit32.bor(s.opt_fitting_flags, s.opt_reorderable and ImGuiTabBarFlags.Reorderable or 0)
        tab_bar_flags = bit32.bor(tab_bar_flags, ImGuiTabBarFlags.DrawSelectedOverline)
        if ImGui.BeginTabBar("##tabs", tab_bar_flags) then
            if s.opt_reorderable then
                app:NotifyOfDocumentsClosedElsewhere()
            end

            -- [DEBUG] Stress tests
            --if ((ImGui.GetFrameCount() % 30) == 0) docs[1].Open ^= 1;            -- [DEBUG] Automatically show/hide a tab. Test various interactions e.g. dragging with this on.
            --if (ImGui.GetIO().KeyCtrl) ImGui.SetTabItemSelected(docs[1].Name);  -- [DEBUG] Test SetTabItemSelected(), probably not very useful as-is anyway..

            -- Submit Tabs
            for _, doc in app.Documents:iter() do repeat
                if not doc.Open then
                    break -- continue
                end

                -- As we allow to change document name, we append a never-changing document id so tabs are stable
                local doc_name_buf = app:GetTabName(doc)
                local tab_flags = (doc.Dirty and ImGuiTabItemFlags.UnsavedDocument or 0)
                local visible
                visible, doc.Open = ImGui.BeginTabItem(doc_name_buf, doc.Open, tab_flags)

                -- Cancel attempt to close when unsaved add to save queue so we can display a popup.
                if not doc.Open and doc.Dirty then
                    doc.Open = true
                    app.CloseQueue:push_back(doc)
                end

                app:DisplayDocContextMenu(doc)
                if visible then
                    app:DisplayDocContents(doc)
                    ImGui.EndTabItem()
                end
            until true end

            ImGui.EndTabBar()
        end
    elseif s.opt_target == Target_DockSpaceAndWindow then
        if bit32.band(ImGui.GetIO().ConfigFlags, ImGuiConfigFlags.DockingEnable) ~= 0 then
            app:NotifyOfDocumentsClosedElsewhere()

            -- Create a DockSpace node where any window can be docked
            local dockspace_id = ImGui.GetID("MyDockSpace")
            ImGui.DockSpace(dockspace_id)

            -- Create Windows
            for doc_n = 0, app.Documents.Size - 1 do repeat
                local doc = app.Documents.Data[doc_n + 1]
                if not doc.Open then
                    break -- continue
                end

                ImGui.SetNextWindowDockID(dockspace_id, redock_all and ImGuiCond.Always or ImGuiCond.FirstUseEver)
                local window_flags = (doc.Dirty and ImGuiWindowFlags.UnsavedDocument or 0)
                local visible
                doc.Open, visible = ImGui.Begin(ImGui.TextBufferToString(doc.Name), doc.Open, window_flags)

                -- Cancel attempt to close when unsaved add to save queue so we can display a popup.
                if not doc.Open and doc.Dirty then
                    doc.Open = true
                    app.CloseQueue:push_back(doc)
                end

                app:DisplayDocContextMenu(doc)
                if visible then
                    app:DisplayDocContents(doc)
                end

                ImGui.End()
            until true end
        else
            ShowDockingDisabledMessage()
        end
    end

    -- Early out other contents
    if not window_contents_visible then
        ImGui.End()
        return p_open
    end

    -- Display renaming UI
    if app.RenamingDoc ~= nil then
        if app.RenamingStarted then
            ImGui.OpenPopup("Rename")
        end
        if ImGui.BeginPopup("Rename") then
            ImGui.SetNextItemWidth(ImGui.GetFontSize() * 30)
            if ImGui.InputText("###Name", app.RenamingDoc.Name, 32, ImGuiInputTextFlags.EnterReturnsTrue) then
                ImGui.CloseCurrentPopup()
                app.RenamingDoc = nil
            end
            if app.RenamingStarted then
                ImGui.SetKeyboardFocusHere(-1)
            end
            ImGui.EndPopup()
        else
            app.RenamingDoc = nil
        end
        app.RenamingStarted = false
    end

    -- Display closing confirmation UI
    if not app.CloseQueue:empty() then
        local close_queue_unsaved_documents = 0
        for n = 0, app.CloseQueue.Size - 1 do
            if app.CloseQueue.Data[n + 1].Dirty then
                close_queue_unsaved_documents = close_queue_unsaved_documents + 1
            end
        end

        if close_queue_unsaved_documents == 0 then
            -- Close documents when all are unsaved
            for n = 0, app.CloseQueue.Size - 1 do
                app.CloseQueue.Data[n + 1]:DoForceClose()
            end
            app.CloseQueue:clear()
        else
            if not ImGui.IsPopupOpen("Save?") then
                ImGui.OpenPopup("Save?")
            end
            if ImGui.BeginPopupModal("Save?", nil, ImGuiWindowFlags.AlwaysAutoResize) then
                ImGui.Text("Save change to the following items?")
                local item_height = ImGui.GetTextLineHeightWithSpacing()
                if ImGui.BeginChild(ImGui.GetID("frame"), ImVec2(-FLT_MIN, 6.25 * item_height), ImGuiChildFlags.FrameStyle) then
                    for _, doc in app.CloseQueue:iter() do
                        if doc.Dirty then
                            ImGui.Text("%s", ImGui.TextBufferToString(doc.Name))
                        end
                    end
                end
                ImGui.EndChild()

                local button_size = ImVec2(ImGui.GetFontSize() * 7.0, 0.0)
                if ImGui.Button("Yes", button_size) then
                    for _, doc in app.CloseQueue:iter() do
                        if doc.Dirty then
                            doc:DoSave()
                        end
                        doc:DoForceClose()
                    end
                    app.CloseQueue:clear()
                    ImGui.CloseCurrentPopup()
                end
                ImGui.SameLine()
                if ImGui.Button("No", button_size) then
                    for _, doc in app.CloseQueue:iter() do
                        doc:DoForceClose()
                    end
                    app.CloseQueue:clear()
                    ImGui.CloseCurrentPopup()
                end
                ImGui.SameLine()
                if ImGui.Button("Cancel", button_size) then
                    app.CloseQueue:clear()
                    ImGui.CloseCurrentPopup()
                end
                ImGui.EndPopup()
            end
        end
    end

    ImGui.End()
    return p_open
end

-------------------------------------------------------------------------------
-- [SECTION] Example App: Assets Browser / ShowExampleAppAssetsBrowser()
-------------------------------------------------------------------------------

--#include "imgui_internal.h" -- NavMoveRequestTryWrapping()

function ExampleAsset(id, type_)
    local self = {}
    self.ID = id   -- ImGuiID
    self.Type = type_ -- int
    return self
end

ExampleAsset_s_current_sort_specs = nil

-- [Port] items: 1-based Lua array (ImVector .Data), sorted in place over [1, items_count].
local function ExampleAsset_Less(a, b) return ExampleAsset_CompareWithSortSpecs(a, b) < 0 end -- [Port] table.sort wants a "less than" predicate
function ExampleAsset_SortWithSortSpecs(sort_specs, items, items_count)
    ExampleAsset_s_current_sort_specs = sort_specs -- Store in variable accessible by the sort function.
    if items_count > 1 then
        if items_count == #items then
            table.sort(items, ExampleAsset_Less)
        else -- [Port] sort only the used range
            local tmp = {}
            for i = 1, items_count do tmp[i] = items[i] end
            table.sort(tmp, ExampleAsset_Less)
            for i = 1, items_count do items[i] = tmp[i] end
        end
    end
    ExampleAsset_s_current_sort_specs = nil
end

-- Compare function to be used by qsort()
function ExampleAsset_CompareWithSortSpecs(a, b)
    for n = 0, ExampleAsset_s_current_sort_specs.SpecsCount - 1 do
        local sort_spec = ExampleAsset_s_current_sort_specs.Specs[n + 1] -- [Port] Specs is a 1-based array
        local delta = 0
        if sort_spec.ColumnIndex == 0 then
            delta = (a.ID - b.ID)
        elseif sort_spec.ColumnIndex == 1 then
            delta = (a.Type - b.Type)
        end
        if delta > 0 then
            return (sort_spec.SortDirection == ImGuiSortDirection.Ascending) and 1 or -1
        end
        if delta < 0 then
            return (sort_spec.SortDirection == ImGuiSortDirection.Ascending) and -1 or 1
        end
    end
    return a.ID - b.ID
end

local ExampleAssetsBrowserMT = {}
ExampleAssetsBrowserMT.__index = ExampleAssetsBrowserMT
function ExampleAssetsBrowser()
    local self = setmetatable({}, ExampleAssetsBrowserMT)
    -- Options
    self.ShowTypeOverlay = true
    self.AllowSorting = true
    self.AllowBoxSelect = true                  -- Will set ImGuiMultiSelectFlags.BoxSelect2d
    self.AllowBoxSelectInsideSelection = false  -- Will set ImGuiMultiSelectFlags.SelectOnClickAlways
    self.AllowDragUnselected = false            -- Will set ImGuiMultiSelectFlags.SelectOnClickRelease
    self.IconSize = 0
    self.IconSpacing = 10
    self.IconHitSpacing = 4                     -- Increase hit-spacing if you want to make it possible to clear or box-select from gaps. Some spacing is required to able to amend with Shift+box-select. Value is small in Explorer.
    self.StretchSpacing = true
    self.UseScrollX = false                     -- Debug: submit twice the number of items per line (overflow horizontally to exercise ScrollX + box-select)

    -- State
    self.Items = ImVector()                     -- Our items
    self.Selection = ExampleSelectionWithDeletion() -- Our selection (ImGuiSelectionBasicStorage + helper funcs to handle deletion)
    self.NextItemId = 0                         -- Unique identifier when creating new items
    self.RequestDelete = false                  -- Deferred deletion request
    self.RequestSort = false                    -- Deferred sort request
    self.ZoomWheelAccum = 0.0                   -- Mouse wheel accumulator to handle smooth wheels better

    -- Calculated sizes for layout, output of UpdateLayoutSizes(). Could be locals but our code is simpler this way.
    self.LayoutItemSize = ImVec2()
    self.LayoutItemStep = ImVec2()              -- == LayoutItemSize + LayoutItemSpacing
    self.LayoutItemSpacing = 0.0
    self.LayoutSelectableSpacing = 0.0
    self.LayoutOuterPadding = 0.0
    self.LayoutColumnCount = 0
    self.LayoutLineCount = 0

    -- Functions
    self:AddItems(10000)
    return self
end
function ExampleAssetsBrowserMT:AddItems(count)
    if self.Items.Size == 0 then
        self.NextItemId = 0
    end
    self.Items:reserve(self.Items.Size + count)
    for n = 0, count - 1 do
        self.Items:push_back(ExampleAsset(self.NextItemId, (self.NextItemId % 20) < 15 and 0 or ((self.NextItemId % 20) < 18 and 1 or 2)))
        self.NextItemId = self.NextItemId + 1
    end
    self.RequestSort = true
end
function ExampleAssetsBrowserMT:ClearItems()
    self.Items:clear()
    self.Selection:Clear()
end

-- Logic would be written in the main code BeginChild() and outputting to local variables.
-- We extracted it into a function so we can call it easily from multiple places.
function ExampleAssetsBrowserMT:UpdateLayoutSizes(avail_width)
    -- Layout: when not stretching: allow extending into right-most spacing.
    self.LayoutItemSpacing = self.IconSpacing
    if self.StretchSpacing == false then
        avail_width = avail_width + math.floor(self.LayoutItemSpacing * 0.5)
    end

    -- Layout: calculate number of icon per line and number of lines
    self.LayoutItemSize = ImVec2(math.floor(self.IconSize), math.floor(self.IconSize))
    self.LayoutColumnCount = ImMax(ImTrunc(avail_width / (self.LayoutItemSize.x + self.LayoutItemSpacing)), 1)

    -- Layout: when stretching: allocate remaining space to more spacing. Round before division, so item_spacing may be non-integer.
    if self.StretchSpacing and self.LayoutColumnCount > 1 then
        self.LayoutItemSpacing = math.floor(avail_width - self.LayoutItemSize.x * self.LayoutColumnCount) / self.LayoutColumnCount
    end

    if self.UseScrollX then
        self.LayoutColumnCount = self.LayoutColumnCount * 2
    end
    self.LayoutLineCount = math.floor((self.Items.Size + self.LayoutColumnCount - 1) / self.LayoutColumnCount)

    self.LayoutItemStep = ImVec2(self.LayoutItemSize.x + self.LayoutItemSpacing, self.LayoutItemSize.y + self.LayoutItemSpacing)
    self.LayoutSelectableSpacing = ImMax(math.floor(self.LayoutItemSpacing) - self.IconHitSpacing, 0.0)
    self.LayoutOuterPadding = math.floor(self.LayoutItemSpacing * 0.5)
end

-- [Port] the non-capturing C++ lambda assigned every frame, hoisted to a single function (no per-frame closure)
local function ExampleAssetsBrowser_AdapterIndexToStorageId(self_, idx) local self = self_.UserData; return self.Items.Data[idx + 1].ID end

-- [Port] returns the new p_open
function ExampleAssetsBrowserMT:Draw(title, p_open)
    if self.IconSize <= 0.0 then
        self.IconSize = ImGui.CalcTextSize("99999").x
    end

    ImGui.SetNextWindowSize(ImVec2(self.IconSize * 25, self.IconSize * 15), ImGuiCond.FirstUseEver)
    local visible
    p_open, visible = ImGui.Begin(title, p_open, ImGuiWindowFlags.MenuBar)
    if not visible then
        ImGui.End()
        return p_open
    end
    IMGUI_DEMO_MARKER("Examples/Assets Browser")

    local Selection = self.Selection
    -- Menu bar
    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu("File") then
            if ImGui.MenuItem("Add 10000 items") then
                self:AddItems(10000)
            end
            if ImGui.MenuItem("Clear items") then
                self:ClearItems()
            end
            ImGui.Separator()
            if ImGui.MenuItem("Close", nil, false, p_open ~= nil) then
                p_open = false
            end
            ImGui.EndMenu()
        end
        if ImGui.BeginMenu("Edit") then
            if ImGui.MenuItem("Delete", "Del", false, Selection.Size > 0) then
                self.RequestDelete = true
            end
            ImGui.EndMenu()
        end
        if ImGui.BeginMenu("Options") then
            ImGui.PushItemWidth(ImGui.GetFontSize() * 10)

            ImGui.SeparatorText("Contents")
            _, self.ShowTypeOverlay = ImGui.Checkbox("Show Type Overlay", self.ShowTypeOverlay)
            _, self.AllowSorting = ImGui.Checkbox("Allow Sorting", self.AllowSorting)

            ImGui.SeparatorText("Selection Behavior")
            _, self.AllowBoxSelect = ImGui.Checkbox("Allow box-selection", self.AllowBoxSelect)
            local pressed
            pressed, self.AllowBoxSelectInsideSelection = ImGui.Checkbox("Allow box-selection from selected items", self.AllowBoxSelectInsideSelection)
            if pressed and self.AllowBoxSelectInsideSelection then
                self.AllowDragUnselected = false
            end
            pressed, self.AllowDragUnselected = ImGui.Checkbox("Allow dragging unselected item", self.AllowDragUnselected)
            if pressed and self.AllowDragUnselected then
                self.AllowBoxSelectInsideSelection = false
            end

            ImGui.SeparatorText("Layout")
            self.IconSize = ImGui.SliderFloat("Icon Size", self.IconSize, 16.0, 128.0, "%.0f")
            ImGui.SameLine(); HelpMarker("Use Ctrl+Wheel to zoom")
            self.IconSpacing = ImGui.SliderInt("Icon Spacing", self.IconSpacing, 0, 32)
            self.IconHitSpacing = ImGui.SliderInt("Icon Hit Spacing", self.IconHitSpacing, 0, 32)
            _, self.StretchSpacing = ImGui.Checkbox("Stretch Spacing", self.StretchSpacing)
            _, self.UseScrollX = ImGui.Checkbox("Use ScrollX", self.UseScrollX)
            ImGui.PopItemWidth()
            ImGui.EndMenu()
        end
        ImGui.EndMenuBar()
    end

    -- Show a table with ONLY one header row to showcase the idea/possibility of using this to provide a sorting UI
    if self.AllowSorting then
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(0, 0))
        local table_flags_for_sort_specs = bit32.bor(ImGuiTableFlags.Sortable, ImGuiTableFlags.SortMulti, ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.Borders)
        if ImGui.BeginTable("for_sort_specs_only", 2, table_flags_for_sort_specs, ImVec2(0.0, ImGui.GetFrameHeight())) then
            ImGui.TableSetupColumn("Index")
            ImGui.TableSetupColumn("Type")
            ImGui.TableHeadersRow()
            local sort_specs = ImGui.TableGetSortSpecs()
            if sort_specs then
                if sort_specs.SpecsDirty or self.RequestSort then
                    ExampleAsset_SortWithSortSpecs(sort_specs, self.Items.Data, self.Items.Size)
                    sort_specs.SpecsDirty = false; self.RequestSort = false
                end
            end
            ImGui.EndTable()
        end
        ImGui.PopStyleVar()
    end

    local io = ImGui.GetIO()
    ImGui.SetNextWindowContentSize(ImVec2(0.0, self.LayoutOuterPadding + self.LayoutLineCount * (self.LayoutItemSize.y + self.LayoutItemSpacing)))
    if ImGui.BeginChild("Assets", ImVec2(0.0, -ImGui.GetTextLineHeightWithSpacing()), ImGuiChildFlags.Borders, bit32.bor(ImGuiWindowFlags.NoMove, ImGuiWindowFlags.HorizontalScrollbar)) then
        local draw_list = ImGui.GetWindowDrawList()

        local avail_width = ImGui.GetContentRegionAvail().x
        self:UpdateLayoutSizes(avail_width)

        -- Calculate and store start position.
        local start_pos = ImGui.GetCursorScreenPos()
        start_pos = ImVec2(start_pos.x + self.LayoutOuterPadding, start_pos.y + self.LayoutOuterPadding)
        ImGui.SetCursorScreenPos(start_pos)

        -- Multi-select
        local ms_flags = bit32.bor(ImGuiMultiSelectFlags.ClearOnEscape, ImGuiMultiSelectFlags.ClearOnClickVoid)

        -- - Enable box-select (in 2D mode, so that changing box-select rectangle X1/X2 boundaries will affect clipped items)
        if self.AllowBoxSelect then
            ms_flags = bit32.bor(ms_flags, ImGuiMultiSelectFlags.BoxSelect2d)
        end

        -- - Selection mode
        if self.AllowDragUnselected then
            ms_flags = bit32.bor(ms_flags, ImGuiMultiSelectFlags.SelectOnClickRelease) -- Rarely used: Allows dragging an unselected item without selecting it(rarely used)
        elseif self.AllowBoxSelectInsideSelection then
            ms_flags = bit32.bor(ms_flags, ImGuiMultiSelectFlags.SelectOnClickAlways) -- Rarely used: Prevents Drag and Drop from being used on multiple-selection, but allows e.g. BoxSelect to always reselect even when clicking inside an existing selection.
        end

        -- - Enable keyboard wrapping on X axis
        -- (FIXME-MULTISELECT: We haven't designed/exposed a general nav wrapping api yet, so this flag is provided as a courtesy to avoid doing:
        --    ImGui.NavMoveRequestTryWrapping(ImGui.GetCurrentWindow(), ImGuiNavMoveFlags.WrapX);
        -- When we finish implementing a more general API for this, we will obsolete this flag in favor of the new system)
        ms_flags = bit32.bor(ms_flags, ImGuiMultiSelectFlags.NavWrapX)

        local ms_io = ImGui.BeginMultiSelect(ms_flags, Selection.Size, self.Items.Size)

        -- Use custom selection adapter: store ID in selection (recommended)
        Selection.UserData = self
        Selection.AdapterIndexToStorageId = ExampleAssetsBrowser_AdapterIndexToStorageId
        Selection:ApplyRequests(ms_io)

        local want_delete = (ImGui.Shortcut(ImGuiKey.Delete, ImGuiInputFlags.Repeat) and (Selection.Size > 0)) or self.RequestDelete
        local item_curr_idx_to_focus = want_delete and Selection:ApplyDeletionPreLoop(ms_io, self.Items.Size) or -1
        self.RequestDelete = false

        -- Push LayoutSelectableSpacing (which is LayoutItemSpacing minus hit-spacing, if we decide to have hit gaps between items)
        -- Altering style ItemSpacing may seem unnecessary as we position every items using SetCursorScreenPos()...
        -- But it is necessary for two reasons:
        -- - Selectables uses it by default to visually fill the space between two items.
        -- - The vertical spacing would be measured by Clipper to calculate line height if we didn't provide it explicitly (here we do).
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, ImVec2(self.LayoutSelectableSpacing, self.LayoutSelectableSpacing))

        -- Rendering parameters
        local icon_type_overlay_colors = { 0, IM_COL32(200, 70, 70, 255), IM_COL32(70, 170, 70, 255) }
        local icon_bg_color = ImGui.GetColorU32(IM_COL32(35, 35, 35, 220), nil, true) -- [Port] ImU32 overload selected explicitly
        local icon_type_overlay_size = ImVec2(4.0, 4.0)
        local display_label = (self.LayoutItemSize.x >= ImGui.CalcTextSize("999").x)

        local column_count = self.LayoutColumnCount
        local clipper = ImGuiListClipper()
        clipper:Begin(self.LayoutLineCount, self.LayoutItemStep.y)
        if item_curr_idx_to_focus ~= -1 then
            clipper:IncludeItemByIndex(math.floor(item_curr_idx_to_focus / column_count)) -- Ensure focused item line is not clipped.
        end
        if ms_io.RangeSrcItem ~= -1 then
            clipper:IncludeItemByIndex(math.floor(ms_io.RangeSrcItem / column_count)) -- Ensure RangeSrc item line is not clipped.
        end
        while clipper:Step() do
            for line_idx = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                local item_min_idx_for_current_line = line_idx * column_count
                local item_max_idx_for_current_line = ImMin((line_idx + 1) * column_count, self.Items.Size)
                for item_idx = item_min_idx_for_current_line, item_max_idx_for_current_line - 1 do
                    local item_data = self.Items.Data[item_idx + 1]
                    ImGui.PushID(item_data.ID)

                    -- Position item
                    local pos = ImVec2(start_pos.x + (item_idx % column_count) * self.LayoutItemStep.x, start_pos.y + line_idx * self.LayoutItemStep.y)
                    ImGui.SetCursorScreenPos(pos)

                    ImGui.SetNextItemSelectionUserData(item_idx)
                    local item_is_selected = Selection:Contains(item_data.ID)
                    local item_is_visible = ImGui.IsRectVisible(self.LayoutItemSize)
                    ImGui.Selectable("", item_is_selected, ImGuiSelectableFlags.None, self.LayoutItemSize)

                    -- Update our selection state immediately (without waiting for EndMultiSelect() requests)
                    -- because we use this to alter the color of our text/icon.
                    if ImGui.IsItemToggledSelection() then
                        item_is_selected = not item_is_selected
                    end

                    -- Focus (for after deletion)
                    if item_curr_idx_to_focus == item_idx then
                        ImGui.SetKeyboardFocusHere(-1)
                    end

                    -- Drag and drop
                    if ImGui.BeginDragDropSource() then
                        -- Create payload with full selection OR single unselected item.
                        -- (the later is only possible when using ImGuiMultiSelectFlags.SelectOnClickRelease)
                        if ImGui.GetDragDropPayload() == nil then
                            local payload_items = ImVector()
                            local it = nil
                            local id = 0
                            if not item_is_selected then
                                payload_items:push_back(item_data.ID)
                            else
                                while true do
                                    local has_more
                                    has_more, it, id = Selection:GetNextSelectedItem(it)
                                    if not has_more then break end
                                    payload_items:push_back(id)
                                end
                            end
                            ImGui.SetDragDropPayload("ASSETS_BROWSER_ITEMS", payload_items.Data, payload_items.Size * 4) -- [Port] size_in_bytes() with sizeof(ImGuiID) == 4, payload carries the Lua array
                        end

                        -- Display payload content in tooltip, by extracting it from the payload data
                        -- (we could read from selection, but it is more correct and reusable to read from payload)
                        local payload = ImGui.GetDragDropPayload()
                        local payload_count = math.floor(payload.DataSize / 4) -- [Port] sizeof(ImGuiID) == 4
                        ImGui.Text("%d assets", payload_count)

                        ImGui.EndDragDropSource()
                    end

                    -- Render icon (a real app would likely display an image/thumbnail here)
                    -- Because we use ImGuiMultiSelectFlags.BoxSelect2d, clipping vertical may occasionally be larger, so we coarse-clip our rendering as well.
                    if item_is_visible then
                        local box_min = ImVec2(pos.x - 1, pos.y - 1)
                        local box_max = ImVec2(box_min.x + self.LayoutItemSize.x + 2, box_min.y + self.LayoutItemSize.y + 2) -- Dubious
                        draw_list:AddRectFilled(box_min, box_max, icon_bg_color) -- Background color
                        if self.ShowTypeOverlay and item_data.Type ~= 0 then
                            local type_col = icon_type_overlay_colors[(item_data.Type % #icon_type_overlay_colors) + 1]
                            draw_list:AddRectFilled(ImVec2(box_max.x - 2 - icon_type_overlay_size.x, box_min.y + 2), ImVec2(box_max.x - 2, box_min.y + 2 + icon_type_overlay_size.y), type_col)
                        end
                        if display_label then
                            local label_col = ImGui.GetColorU32(item_is_selected and ImGuiCol.Text or ImGuiCol.TextDisabled)
                            local label = string.format("%d", item_data.ID)
                            draw_list:AddText(ImVec2(box_min.x, box_max.y - ImGui.GetFontSize()), label_col, label)
                        end
                    end

                    ImGui.PopID()
                end
            end
        end
        clipper:End()
        if self.Items.Size == 0 then
            ImGui.Dummy(ImVec2(0, 0))
        end
        ImGui.PopStyleVar() -- ImGuiStyleVar.ItemSpacing

        -- Context menu
        if ImGui.BeginPopupContextWindow() then
            ImGui.Text("Selection: %d items", Selection.Size)
            ImGui.Separator()
            if ImGui.MenuItem("Delete", "Del", false, Selection.Size > 0) then
                self.RequestDelete = true
            end
            ImGui.EndPopup()
        end

        ms_io = ImGui.EndMultiSelect()
        Selection:ApplyRequests(ms_io)
        if want_delete then
            Selection:ApplyDeletionPostLoop(ms_io, self.Items, item_curr_idx_to_focus)
        end

        -- Zooming with Ctrl+Wheel
        if ImGui.IsWindowAppearing() then
            self.ZoomWheelAccum = 0.0
        end
        if ImGui.IsWindowHovered() and io.MouseWheel ~= 0.0 and ImGui.IsKeyDown(ImGuiMod_Ctrl) and ImGui.IsAnyItemActive() == false then
            self.ZoomWheelAccum = self.ZoomWheelAccum + io.MouseWheel
            if math.abs(self.ZoomWheelAccum) >= 1.0 then
                -- Calculate hovered item index from mouse location
                -- FIXME: Locking aiming on 'hovered_item_idx' (with a cool-down timer) would ensure zoom keeps on it.
                local hovered_item_nx = (io.MousePos.x - start_pos.x + self.LayoutItemSpacing * 0.5) / self.LayoutItemStep.x
                local hovered_item_ny = (io.MousePos.y - start_pos.y + self.LayoutItemSpacing * 0.5) / self.LayoutItemStep.y
                local hovered_item_idx = (ImTrunc(hovered_item_ny) * self.LayoutColumnCount) + ImTrunc(hovered_item_nx)
                --ImGui.SetTooltip("%f,%f -> item %d", hovered_item_nx, hovered_item_ny, hovered_item_idx); -- Move those 4 lines in block above for easy debugging

                -- Zoom
                self.IconSize = self.IconSize * (1.1 ^ ImTrunc(self.ZoomWheelAccum))
                self.IconSize = ImClamp(self.IconSize, 16.0, 128.0)
                self.ZoomWheelAccum = self.ZoomWheelAccum - ImTrunc(self.ZoomWheelAccum)
                self:UpdateLayoutSizes(avail_width)

                -- Manipulate scroll to that we will land at the same Y location of currently hovered item.
                -- - Calculate next frame position of item under mouse
                -- - Set new scroll position to be used in next ImGui.BeginChild() call.
                local hovered_item_rel_pos_y = (ImTrunc(hovered_item_idx / self.LayoutColumnCount) + math.fmod(hovered_item_ny, 1.0)) * self.LayoutItemStep.y
                hovered_item_rel_pos_y = hovered_item_rel_pos_y + ImGui.GetStyle().WindowPadding.y
                local mouse_local_y = io.MousePos.y - ImGui.GetWindowPos().y
                ImGui.SetScrollY(hovered_item_rel_pos_y - mouse_local_y)
            end
        end
    end
    ImGui.EndChild()

    ImGui.Text("Selected: %d/%d items", Selection.Size, self.Items.Size)
    ImGui.End()
    return p_open
end

S.ShowExampleAppAssetsBrowser = {
    assets_browser = nil, -- static ExampleAssetsBrowser assets_browser; -- [Port] created lazily on first call (10000 items)
}
function ShowExampleAppAssetsBrowser(p_open)
    IMGUI_DEMO_MARKER("Examples/Assets Browser")
    local s = S.ShowExampleAppAssetsBrowser
    if s.assets_browser == nil then s.assets_browser = ExampleAssetsBrowser() end
    return s.assets_browser:Draw("Example: Assets Browser", p_open)
end

return true
