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
    io.Fonts:AddFontFromFileTTF("fonts/" .. name .. ".ttf", 13.0)
end

ImGui_ImplRoblox.Init(nil, render_scale)
ImGui_ImplRoblox.SetRenderRate(60) -- tile redraws per second; imgui logic + your code still run every frame
-- ImGui_ImplRoblox.SetBusyRenderRate(30) -- optional: lower redraw rate while scrolling/resizing/moving windows
ImGui_ImplRoblox.SetProfiling(true) -- MicroProfiler (Ctrl+F6) labels; turn off when not profiling

local function P(name) if ImGui_ImplRoblox.IsProfiling() then debug.profilebegin(name) end end
local function PE() if ImGui_ImplRoblox.IsProfiling() then debug.profileend() end end

--------------------------------------------------------------------------------------------------------------------
-- Custom widget: ImGui.Embed(id, size, flags, init) -> Frame
-- Reserves a widget-sized area in the current window and shows a real Frame there, so any Instances (UI, a
-- ViewportFrame, ...) can live inside an imgui window. Immediate-mode friendly:
--   * one Frame per id (per window, through the ID stack, like any widget); `init(frame)` runs only when it is created
--   * call it every frame the Frame should be visible; when it isn't called (window closed/collapsed, tab or tree node
--     closed, scrolled fully out of view) the Frame is hidden, never destroyed, so your Instances keep their state
--   * size uses imgui sizing (ImVec2(-1, h) = fill width, 0 = default), style gives padding/rounding/background/border
--   * returns the Frame: edit properties, add or remove children any time
-- ImGui.DestroyEmbed(id) removes it for good (call while the same window is current, like the widget itself).
--------------------------------------------------------------------------------------------------------------------
local EmbedFlags = {
    None         = 0,
    NoClip       = 1,  -- don't clip to the window's content area (still moves/hides/stacks with the window)
    NoBackground = 2,  -- no FrameBg behind the Frame
    NoBorder     = 4,  -- no style border
    NoPadding    = 8,  -- no FramePadding inside the Frame (UIPadding)
    NoRounding   = 16, -- no FrameRounding corners (UICorner)
}
G.ImGuiEmbedFlags = EmbedFlags

local embeds = {} -- [ImGuiID] = { Frame, Padding, Corner }

function ImGui.Embed(id, size, flags, init)
    flags = flags or EmbedFlags.None
    local window = ImGui.GetCurrentWindow()
    local gid = window:GetID(id)
    local e = embeds[gid]
    if not e then
        local frame = Instance.new("Frame")
        frame.Name = tostring(id)
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.Visible = false
        e = { Frame = frame, Padding = Instance.new("UIPadding"), Corner = Instance.new("UICorner") }
        e.Padding.Parent = frame
        e.Corner.Parent = frame
        embeds[gid] = e
        if init then init(frame) end
    end
    if window.SkipItems then return e.Frame end

    local style = ImGui.GetStyle()
    local sz = ImGui.CalcItemSize(size or G.ImVec2(0, 0), ImGui.CalcItemWidth(), ImGui.GetFrameHeight() * 4)
    local p = window.DC.CursorPos
    local bb = G.ImRect(p.x, p.y, p.x + sz.x, p.y + sz.y)
    ImGui.ItemSize(sz)
    if not ImGui.ItemAdd(bb, gid) then return e.Frame end -- fully clipped: not submitted -> hidden this frame

    local rounding = bit32.band(flags, EmbedFlags.NoRounding) == 0 and style.FrameRounding or 0
    if bit32.band(flags, EmbedFlags.NoBackground) == 0 then
        ImGui.RenderFrame(bb.Min, bb.Max, ImGui.GetColorU32(G.ImGuiCol.FrameBg), bit32.band(flags, EmbedFlags.NoBorder) == 0, rounding)
    elseif bit32.band(flags, EmbedFlags.NoBorder) == 0 then
        ImGui.RenderFrameBorder(bb.Min, bb.Max, rounding)
    end

    -- style -> Instances (only written when changed)
    local scale = ImGui_ImplRoblox.GetRenderScale()
    local px, py = 0, 0
    if bit32.band(flags, EmbedFlags.NoPadding) == 0 then px, py = style.FramePadding.x / scale, style.FramePadding.y / scale end
    if e.PX ~= px or e.PY ~= py then
        e.PX, e.PY = px, py
        e.Padding.PaddingLeft, e.Padding.PaddingRight = UDim.new(0, px), UDim.new(0, px)
        e.Padding.PaddingTop, e.Padding.PaddingBottom = UDim.new(0, py), UDim.new(0, py)
    end
    if e.R ~= rounding then e.R = rounding; e.Corner.CornerRadius = UDim.new(0, rounding / scale) end

    ImGui_ImplRoblox.SetOverlay(e.Frame, bb.Min.x, bb.Min.y, sz.x, sz.y, bit32.band(flags, EmbedFlags.NoClip) == 0)
    return e.Frame
end

function ImGui.DestroyEmbed(id)
    local gid = ImGui.GetCurrentWindow():GetID(id)
    local e = embeds[gid]
    if e then e.Frame:Destroy(); embeds[gid] = nil end
end

-- Example: a ViewportFrame with a spinning part, edited live from imgui widgets
local spin_speed = 1.0
local part_color = ImVec4(0.80, 0.65, 0.97, 1.0)
local spin_angle = 0.0
local show_viewport_window = true

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
    if show_viewport_window then
        show_viewport_window = ImGui.Begin("Viewport", show_viewport_window)
        spin_speed = ImGui.SliderFloat("speed", spin_speed, 0.0, 5.0)
        ImGui.ColorEdit3("color", part_color)
        local frame = ImGui.Embed("viewport", G.ImVec2(-1, 220), G.ImGuiEmbedFlags.None, function(f)
            -- runs once
            local vpf = Instance.new("ViewportFrame")
            vpf.Size = UDim2.fromScale(1, 1)
            vpf.BackgroundTransparency = 1
            vpf.Parent = f
            local cam = Instance.new("Camera")
            cam.CFrame = CFrame.lookAt(Vector3.new(0, 2, 6), Vector3.new(0, 0, 0))
            cam.Parent = vpf
            vpf.CurrentCamera = cam
            local part = Instance.new("Part")
            part.Name = "Spinner"
            part.Size = Vector3.new(2, 2, 2)
            part.Parent = vpf
        end)
        -- every frame: edit what was created once
        spin_angle += spin_speed * io.DeltaTime
        local part = frame.ViewportFrame.Spinner
        part.CFrame = CFrame.Angles(0.4, spin_angle, 0)
        part.Color = Color3.new(part_color.x, part_color.y, part_color.z)
        ImGui.Text("Frames created: 1 (same Frame every frame)")
        ImGui.End()
    end

    P("ImGui.Render"); ImGui.EndFrame(); ImGui.Render(); PE()
    ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    PE()
end)
