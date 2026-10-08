-- LocalScript. Build the library first: `python3 tools/bundle.py` -> build/ImGui.luau (see default.project.json)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local G = require(ReplicatedStorage:WaitForChild("ImGui"))

local ImGui, ImVec4, ImGuiConfigFlags, ImGui_ImplRoblox = G.ImGui, G.ImVec4, G.ImGuiConfigFlags, G.ImGui_ImplRoblox

local main_scale = 1.0
-- Roblox UI points are multiplied by the OS display scale (e.g. 150%), which makes imgui look large.
-- Set this to your display scale to render imgui at physical-pixel resolution (same size as a desktop imgui app).
local render_scale = 1.0
local clear_color = ImVec4(0.45, 0.55, 0.60, 1.00)
local show_demo_window = true
local show_another_window = false
local f = 0.0
local counter = 0

ImGui.CreateContext()

local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard, ImGuiConfigFlags.DockingEnable)

-- Catppuccin Mocha, Mauve accent (https://catppuccin.com/palette)
local function StyleColorsCatppuccinMocha(style)
    local function hex(h, a)
        return ImVec4(bit32.extract(h, 16, 8) / 255, bit32.extract(h, 8, 8) / 255, bit32.extract(h, 0, 8) / 255, a or 1.0)
    end
    local crust, mantle, base = 0x11111b, 0x181825, 0x1e1e2e
    local surface0, surface1, surface2 = 0x313244, 0x45475a, 0x585b70
    local overlay0, overlay2, text = 0x6c7086, 0x9399b2, 0xcdd6f4
    local mauve, lavender = 0xcba6f7, 0xb4befe
    local C, c = G.ImGuiCol, style.Colors
    local function set(idx, h, a) c[idx] = hex(h, a) end
    set(C.Text, text);                      set(C.TextDisabled, overlay0)
    set(C.WindowBg, base);                  set(C.ChildBg, base, 0.0)
    set(C.PopupBg, mantle, 0.98);           set(C.Border, surface1);          set(C.BorderShadow, crust, 0.0)
    set(C.FrameBg, surface0);               set(C.FrameBgHovered, surface1);  set(C.FrameBgActive, surface2)
    set(C.TitleBg, mantle);                 set(C.TitleBgActive, crust);      set(C.TitleBgCollapsed, mantle, 0.75)
    set(C.MenuBarBg, mantle)
    set(C.ScrollbarBg, mantle);             set(C.ScrollbarGrab, surface1)
    set(C.ScrollbarGrabHovered, surface2);  set(C.ScrollbarGrabActive, overlay0)
    set(C.CheckMark, mauve);                set(C.SliderGrab, mauve, 0.8);    set(C.SliderGrabActive, mauve)
    set(C.Button, surface0);                set(C.ButtonHovered, surface1);   set(C.ButtonActive, mauve, 0.6)
    set(C.Header, surface0);                set(C.HeaderHovered, surface1);   set(C.HeaderActive, mauve, 0.5)
    set(C.Separator, surface1);             set(C.SeparatorHovered, mauve, 0.7); set(C.SeparatorActive, mauve)
    set(C.ResizeGrip, mauve, 0.2);          set(C.ResizeGripHovered, mauve, 0.6); set(C.ResizeGripActive, mauve, 0.9)
    set(C.InputTextCursor, text)
    set(C.TabHovered, surface2);            set(C.Tab, surface0)
    set(C.TabSelected, surface1);           set(C.TabSelectedOverline, mauve)
    set(C.TabDimmed, mantle);               set(C.TabDimmedSelected, surface0); set(C.TabDimmedSelectedOverline, overlay0)
    set(C.DockingPreview, mauve, 0.7);      set(C.DockingEmptyBg, crust)
    set(C.PlotLines, overlay2);             set(C.PlotLinesHovered, mauve)
    set(C.PlotHistogram, mauve, 0.8);       set(C.PlotHistogramHovered, lavender)
    set(C.TableHeaderBg, surface0);         set(C.TableBorderStrong, surface1); set(C.TableBorderLight, surface0)
    set(C.TableRowBg, base, 0.0);           set(C.TableRowBgAlt, surface0, 0.3)
    set(C.TextLink, mauve);                 set(C.TextSelectedBg, mauve, 0.35)
    set(C.TreeLines, surface2)
    set(C.DragDropTarget, mauve, 0.9)
    set(C.NavCursor, lavender);             set(C.NavWindowingHighlight, lavender, 0.7)
    set(C.NavWindowingDimBg, crust, 0.5);   set(C.ModalWindowDimBg, crust, 0.6)
end

local style = ImGui.GetStyle()
StyleColorsCatppuccinMocha(style)
style:ScaleAllSizes(main_scale)
style.FontScaleDpi = main_scale

-- Fonts: ProggyClean stays the default (added first); the rest show up in Style Editor > Fonts
io.Fonts:AddFontDefault()
for _, name in ipairs({ "Cousine-Regular", "DroidSans", "Karla-Regular", "ProggyTiny", "Roboto-Medium" }) do
    io.Fonts:AddFontFromFileTTF("resource/fonts/" .. name .. ".ttf", 13.0)
end

ImGui_ImplRoblox.Init(nil, render_scale)
ImGui_ImplRoblox.SetRenderRate(60) -- tile redraws per second; imgui logic + your code still run every frame
ImGui_ImplRoblox.SetProfiling(true) -- MicroProfiler (Ctrl+F6) labels; turn off when not profiling

local function P(name) if ImGui_ImplRoblox.IsProfiling() then debug.profilebegin(name) end end
local function PE() if ImGui_ImplRoblox.IsProfiling() then debug.profileend() end end

RunService.Stepped:Connect(function()
    P("ImGui frame")
    ImGui_ImplRoblox.NewFrame()
    P("ImGui.NewFrame"); ImGui.NewFrame(); PE()
    P("ImGui UI")

    -- Dockspace covering the whole screen; the centre stays transparent so the game shows through
    ImGui.DockSpaceOverViewport(0, nil, G.ImGuiDockNodeFlags.PassthruCentralNode)

    if show_demo_window then
        ImGui.ShowDemoWindow()
    end

    do
        ImGui.Begin("Hello, world!")

        ImGui.Text("This is some useful text.")
        local _
        _, show_demo_window = ImGui.Checkbox("Demo Window", show_demo_window)
        _, show_another_window = ImGui.Checkbox("Another Window", show_another_window)

        f = ImGui.SliderFloat("float", f, 0.0, 1.0)
        ImGui.ColorEdit3("clear color", clear_color)

        if ImGui.Button("Button") then
            counter = counter + 1
        end
        ImGui.SameLine()
        ImGui.Text("counter = %d", counter)

        ImGui.Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / io.Framerate, io.Framerate)

        ImGui.End()
    end

    if show_another_window then
        show_another_window = ImGui.Begin("Another Window", show_another_window)

        ImGui.Text("Hello from another window!")
        if ImGui.Button("Close Me") then
            show_another_window = false
        end

        ImGui.End()
    end

    PE()
    P("ImGui.Render"); ImGui.EndFrame(); ImGui.Render(); PE()
    ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    PE()
end)
