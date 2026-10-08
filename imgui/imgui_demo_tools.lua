-- Demo tools: ShowAboutWindow(), ShowFontAtlas(), ShowFontSelector(), ShowDebugLogWindow(), ShowIDStackToolWindow()
local _

----------------------------------------------------------------
-- [SECTION] About Window / ShowAboutWindow()
----------------------------------------------------------------

local show_config_info = false
function ImGui.ShowAboutWindow(p_open)
    local visible
    p_open, visible = ImGui.Begin("About ImGui Sincerely", p_open, ImGuiWindowFlags.AlwaysAutoResize)
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

----------------------------------------------------------------
-- [SECTION] Font atlas / font debugging
----------------------------------------------------------------

local function MetricsHelpMarker(desc)
    ImGui.TextDisabled("(?)")
    if ImGui.BeginItemTooltip() then
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
        ImGui.TextUnformatted(desc)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end
ImGui.MetricsHelpMarker = MetricsHelpMarker

local function U8(c) return (c and c > 0) and utf8.char(c) or "" end

function ImGui.ShowFontSelector(label)
    local io = ImGui.GetIO()
    local font_current = ImGui.GetFont()
    if ImGui.BeginCombo(label, font_current:GetDebugName()) then
        for i, font in io.Fonts.Fonts:iter() do
            ImGui.PushID(i)
            if ImGui.Selectable(font:GetDebugName(), font == font_current, ImGuiSelectableFlags.SelectOnNav) then io.FontDefault = font end
            if font == font_current then ImGui.SetItemDefaultFocus() end
            ImGui.PopID()
        end
        ImGui.EndCombo()
    end
    ImGui.SameLine()
    MetricsHelpMarker("- Load additional fonts with io.Fonts->AddFontXXX() functions.\n- On Roblox: register the .ttf bytes with ImGui_ImplRoblox.AddFile() first.\n- Read FAQ and docs/FONTS.md for more details.")
end

function ImGui.DebugNodeFontGlyph(font, glyph)
    ImGui.Text("Codepoint: U+%04X", glyph.Codepoint)
    ImGui.Separator()
    ImGui.Text("Visible: %d", glyph.Visible and 1 or 0)
    ImGui.Text("AdvanceX: %.1f", glyph.AdvanceX)
    ImGui.Text("Pos: (%.2f,%.2f)->(%.2f,%.2f)", glyph.X0, glyph.Y0, glyph.X1, glyph.Y1)
    ImGui.Text("UV: (%.3f,%.3f)->(%.3f,%.3f)", glyph.U0, glyph.V0, glyph.U1, glyph.V1)
    if glyph.PackId >= 0 then
        local r = ImFontAtlasPackGetRect(font.OwnerAtlas, glyph.PackId)
        if r then ImGui.Text("PackId: 0x%X (%dx%d rect at %d,%d)", glyph.PackId, r.w, r.h, r.x, r.y) end
    end
    ImGui.Text("SourceIdx: %d", glyph.SourceIdx)
end

function ImGui.DebugNodeFontGlyphsForSrcMask(font, baked, src_mask)
    local draw_list = ImGui.GetWindowDrawList()
    local glyph_col = ImGui.GetColorU32(ImGuiCol.Text)
    local cell_size = baked.Size * 1
    local cell_spacing = ImGui.GetStyle().ItemSpacing.y
    -- [port] only scans loaded codepoints (IndexLookup range) instead of the whole 0..0xFFFF range
    local max_c = baked.IndexLookup.Size - 1
    local base = 0
    while base <= max_c do
        local count = 0
        for n = 0, 255 do
            local c = base + n
            if baked:IsGlyphLoaded(c) then
                local glyph = baked:FindGlyphNoFallback(c)
                if glyph and bit32.band(src_mask, bit32.lshift(1, glyph.SourceIdx)) ~= 0 then count = count + 1 end
            end
        end
        if count > 0 and ImGui.TreeNode(base, "U+%04X..U+%04X (%d %s)", base, base + 255, count, (count > 1) and "glyphs" or "glyph") then
            local base_pos = ImGui.GetCursorScreenPos()
            for n = 0, 255 do
                local c = base + n
                local cell_p1 = ImVec2(base_pos.x + (n % 16) * (cell_size + cell_spacing), base_pos.y + math.floor(n / 16) * (cell_size + cell_spacing))
                local cell_p2 = ImVec2(cell_p1.x + cell_size, cell_p1.y + cell_size)
                local glyph = baked:IsGlyphLoaded(c) and baked:FindGlyphNoFallback(c) or nil
                draw_list:AddRect(cell_p1, cell_p2, glyph and IM_COL32(255, 255, 255, 100) or IM_COL32(255, 255, 255, 50))
                if glyph and bit32.band(src_mask, bit32.lshift(1, glyph.SourceIdx)) ~= 0 then
                    font:RenderChar(draw_list, cell_size, cell_p1, glyph_col, c)
                    if ImGui.IsMouseHoveringRect(cell_p1, cell_p2) and ImGui.BeginTooltip() then
                        ImGui.DebugNodeFontGlyph(font, glyph)
                        ImGui.EndTooltip()
                    end
                end
            end
            ImGui.Dummy(ImVec2((cell_size + cell_spacing) * 16, (cell_size + cell_spacing) * 16))
            ImGui.TreePop()
        end
        base = base + 256
    end
end

function ImGui.DebugNodeFont(font)
    local g = ImGui.GetCurrentContext()
    local cfg = g.DebugMetricsConfig
    local atlas = font.OwnerAtlas
    local opened = ImGui.TreeNode(tostring(font), "Font: \"%s\": %d sources(s)", font:GetDebugName(), font.Sources.Size)
    if not opened then ImGui.Indent() end
    ImGui.Indent()
    if cfg.ShowFontPreview then
        ImGui.PushFont(font, 0.0)
        ImGui.Text("The quick brown fox jumps over the lazy dog")
        ImGui.PopFont()
    end
    if not opened then
        ImGui.Unindent()
        ImGui.Unindent()
        return
    end
    if ImGui.SmallButton("Set as default") then ImGui.GetIO().FontDefault = font end
    ImGui.SameLine()
    ImGui.BeginDisabled(atlas.Fonts.Size <= 1 or atlas.Locked == true or atlas.RemoveFont == nil)
    if ImGui.SmallButton("Remove") and atlas.RemoveFont then atlas:RemoveFont(font) end
    ImGui.EndDisabled()
    ImGui.SameLine()
    if ImGui.SmallButton("Clear bakes") then ImFontAtlasFontDiscardBakes(atlas, font, 0) end
    ImGui.SameLine()
    if ImGui.SmallButton("Clear unused") then ImFontAtlasFontDiscardBakes(atlas, font, 2) end

    ImGui.Text("Fallback character: '%s' (U+%04X)", U8(font.FallbackChar), font.FallbackChar or 0)
    ImGui.Text("Ellipsis character: '%s' (U+%04X)", U8(font.EllipsisChar), font.EllipsisChar or 0)
    for src_n, src in font.Sources:iter() do
        if ImGui.TreeNode(tostring(src), "Input %d: '%s' [%d], Oversample: %d,%d, PixelSnapH: %d, Offset: (%.1f,%.1f)",
            src_n - 1, src.Name or "", src.FontNo or 0, src.OversampleH or 0, src.OversampleV or 0, src.PixelSnapH and 1 or 0, src.GlyphOffset.x, src.GlyphOffset.y) then
            local loader = src.FontLoader or atlas.FontLoader
            ImGui.Text("Loader: '%s'", (loader and loader.Name) or "N/A")
            ImGui.TreePop()
        end
    end

    local builder = atlas.Builder
    if builder then
        for _, baked in builder.BakedPool:iter() do
            if baked.OwnerFont == font then
                ImGui.PushID(baked.BakedId)
                if ImGui.TreeNode("Glyphs", "Baked at { %.2fpx, d.%.2f }: %d glyphs%s", baked.Size, baked.RasterizerDensity, baked.Glyphs.Size,
                    (baked.LastUsedFrame < (builder.FrameCount or 0) - 1) and " *Unused*" or "") then
                    if ImGui.SmallButton("Load all") then
                        for c = 0, 0x7F do baked:FindGlyph(c) end -- [port] ASCII only: loading the whole BMP in Luau stalls for seconds
                    end
                    local surface_sqrt = math.floor(math.sqrt(baked.MetricsTotalSurface))
                    ImGui.Text("Ascent: %f, Descent: %f, Ascent-Descent: %f", baked.Ascent, baked.Descent, baked.Ascent - baked.Descent)
                    ImGui.Text("Texture Area: about %d px ~%dx%d px", baked.MetricsTotalSurface, surface_sqrt, surface_sqrt)
                    for src_n, src in font.Sources:iter() do
                        ImGui.BulletText("Input %d: '%s', Oversample: (%d,%d), PixelSnapH: %d, Offset: (%.1f,%.1f)",
                            src_n - 1, src.Name or "", src.OversampleH or 0, src.OversampleV or 0, src.PixelSnapH and 1 or 0, src.GlyphOffset.x, src.GlyphOffset.y)
                    end
                    ImGui.DebugNodeFontGlyphsForSrcMask(font, baked, bit32.bnot(0))
                    ImGui.TreePop()
                end
                ImGui.PopID()
            end
        end
    end
    ImGui.TreePop()
    ImGui.Unindent()
end

local StatusNames = { [0] = "OK", "Destroyed", "WantCreate", "WantUpdates", "WantDestroy" }
local FormatNames = { [0] = "RGBA32", "Alpha8" }

function ImGui.DebugNodeTexture(tex, int_id, highlight_rect)
    local g = ImGui.GetCurrentContext()
    ImGui.PushID(int_id)
    if ImGui.TreeNode("", "Texture #%03d (%dx%d pixels)", tex.UniqueID or 0, tex.Width, tex.Height) then
        local cfg = g.DebugMetricsConfig
        _, cfg.ShowTextureUsedRect = ImGui.Checkbox("Show used rect", cfg.ShowTextureUsedRect)
        ImGui.PushStyleVar(ImGuiStyleVar.ImageBorderSize, math.max(1.0, g.Style.ImageBorderSize))
        local p = ImGui.GetCursorScreenPos()
        if tex.Status == ImTextureStatus.WantDestroy or tex.Status == ImTextureStatus.Destroyed then
            ImGui.Dummy(ImVec2(tex.Width, tex.Height))
        else
            local ref = ImTextureRef(); ref._TexData = tex
            ImGui.ImageWithBg(ref, ImVec2(tex.Width, tex.Height), ImVec2(0.0, 0.0), ImVec2(1.0, 1.0), ImVec4(0.0, 0.0, 0.0, 1.0))
        end
        if cfg.ShowTextureUsedRect and tex.UsedRect then
            local u = tex.UsedRect
            ImGui.GetWindowDrawList():AddRect(ImVec2(p.x + u.x, p.y + u.y), ImVec2(p.x + u.x + u.w, p.y + u.y + u.h), IM_COL32(255, 0, 255, 255))
        end
        if highlight_rect ~= nil then
            local r_outer = ImRect(p.x, p.y, p.x + tex.Width, p.y + tex.Height)
            local r_inner = ImRect(p.x + highlight_rect.x, p.y + highlight_rect.y, p.x + highlight_rect.x + highlight_rect.w, p.y + highlight_rect.y + highlight_rect.h)
            ImGui.RenderRectFilledWithHole(ImGui.GetWindowDrawList(), r_outer, r_inner, IM_COL32(0, 0, 0, 100), 0.0)
            ImGui.GetWindowDrawList():AddRect(r_inner.Min - ImVec2(1, 1), r_inner.Max + ImVec2(1, 1), IM_COL32(255, 255, 0, 255))
        end
        ImGui.PopStyleVar()
        ImGui.Text("Status = %s (%d), Format = %s (%d), UseColors = %d", StatusNames[tex.Status] or "?", tex.Status, FormatNames[tex.Format] or "?", tex.Format, tex.UseColors and 1 or 0)
        ImGui.Text("TexID = %s", tostring(tex.TexID))
        ImGui.TreePop()
    end
    ImGui.PopID()
end

function ImGui.ShowFontAtlas(atlas)
    local g = ImGui.GetCurrentContext()
    local io = g.IO
    local style = g.Style
    ImGui.BeginDisabled()
    ImGui.CheckboxFlags("io.BackendFlags: RendererHasTextures", io.BackendFlags, ImGuiBackendFlags.RendererHasTextures)
    ImGui.EndDisabled()
    ImGui.ShowFontSelector("Font")
    local changed
    style.FontSizeBase, changed = ImGui.DragFloat("FontSizeBase", style.FontSizeBase, 0.20, 5.0, 100.0, "%.0f")
    if changed then style._NextFrameFontSizeBase = style.FontSizeBase end
    ImGui.SameLine(0.0, 0.0); ImGui.Text(" (out %.2f)", ImGui.GetFontSize())
    ImGui.SameLine(); MetricsHelpMarker("- This is scaling font only. General scaling will come later.")
    style.FontScaleMain = ImGui.DragFloat("FontScaleMain", style.FontScaleMain, 0.02, 0.5, 4.0)
    style.FontScaleDpi = ImGui.DragFloat("FontScaleDpi", style.FontScaleDpi, 0.02, 0.5, 4.0)
    ImGui.BulletText("Load a nice font for better results!")
    ImGui.BulletText("Please submit feedback:")
    ImGui.SameLine(); ImGui.TextLinkOpenURL("#8465", "https://github.com/ocornut/imgui/issues/8465")
    ImGui.BulletText("Read FAQ for more details:")
    ImGui.SameLine(); ImGui.TextLinkOpenURL("dearimgui.com/faq", "https://www.dearimgui.com/faq/")

    ImGui.SeparatorText("Font List")
    local cfg = g.DebugMetricsConfig
    _, cfg.ShowFontPreview = ImGui.Checkbox("Show font preview", cfg.ShowFontPreview == true)
    if ImGui.TreeNode("Loader", "Loader: '%s'", atlas.FontLoaderName or "NULL") then
        ImGui.BeginDisabled()
        ImGui.RadioButtonEx("stb_truetype", true)
        ImGui.SameLine()
        ImGui.RadioButtonEx("FreeType", false)
        ImGui.SetItemTooltip("Not available on Roblox.")
        ImGui.EndDisabled()
        ImGui.TreePop()
    end
    for i, font in atlas.Fonts:iter() do
        ImGui.PushID(i)
        ImGui.DebugNodeFont(font)
        ImGui.PopID()
    end

    ImGui.SeparatorText("Font Atlas")
    if ImGui.Button("Compact") then atlas:CompactCache() end
    ImGui.SameLine()
    if ImGui.Button("Grow") then ImFontAtlasTextureGrow(atlas) end
    ImGui.SameLine()
    if ImGui.Button("Clear All") then ImFontAtlasBuildClear(atlas) end
    ImGui.SetItemTooltip("Destroy cache and custom rectangles.")
    for tex_n, tex in atlas.TexList:iter() do
        if tex_n > 1 then ImGui.SameLine() end
        ImGui.Text("Tex: %dx%d", tex.Width, tex.Height)
    end
    local b = atlas.Builder
    if b then
        local packed_sqrt = math.floor(math.sqrt(b.RectsPackedSurface or 0))
        local discarded_sqrt = math.floor(math.sqrt(b.RectsDiscardedSurface or 0))
        ImGui.Text("Packed rects: %d, area: about %d px ~%dx%d px", b.RectsPackedCount or 0, b.RectsPackedSurface or 0, packed_sqrt, packed_sqrt)
        ImGui.Text("incl. Discarded rects: %d, area: about %d px ~%dx%d px", b.RectsDiscardedCount or 0, b.RectsDiscardedSurface or 0, discarded_sqrt, discarded_sqrt)
    end
    for tex_n, tex in atlas.TexList:iter() do
        if tex_n == atlas.TexList.Size then ImGui.SetNextItemOpen(true, ImGuiCond.Once) end
        ImGui.DebugNodeTexture(tex, atlas.TexList.Size - tex_n, nil)
    end
end

----------------------------------------------------------------
-- [SECTION] Debug Log window
----------------------------------------------------------------

local function SameLineOrWrap(size)
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow
    local pos = ImVec2(window.DC.CursorPosPrevLine.x + g.Style.ItemSpacing.x, window.DC.CursorPosPrevLine.y)
    if window.WorkRect:Contains(ImRect(pos, pos + size)) then ImGui.SameLine() end
end

local function ShowDebugLogFlag(name, flags)
    local g = ImGui.GetCurrentContext()
    local size = ImVec2(ImGui.GetFrameHeight() + g.Style.ItemInnerSpacing.x + ImGui.CalcTextSize(name).x, ImGui.GetFrameHeight())
    SameLineOrWrap(size)
    local pressed
    pressed, g.DebugLogFlags = ImGui.CheckboxFlags(name, g.DebugLogFlags, flags)
    if pressed and g.IO.KeyShift and bit32.band(g.DebugLogFlags, flags) ~= 0 then
        g.DebugLogAutoDisableFrames = 2
        g.DebugLogAutoDisableFlags = bit32.bor(g.DebugLogAutoDisableFlags or 0, flags)
    end
    ImGui.SetItemTooltip("Hold Shift when clicking to enable for 2 frames only (useful for spammy log entries)")
end

function ImGui.ShowDebugLogWindow(p_open)
    local g = ImGui.GetCurrentContext()
    if bit32.band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSize) == 0 then
        ImGui.SetNextWindowSize(ImVec2(0.0, ImGui.GetFontSize() * 12.0), ImGuiCond.FirstUseEver)
    end
    local visible
    p_open, visible = ImGui.Begin("ImGui Sincerely Debug Log", p_open)
    if not visible or ImGui.GetCurrentWindow().BeginCount > 1 then
        ImGui.End()
        return p_open
    end
    local L = ImGuiDebugLogFlags
    local all_enable_flags = bit32.band(L.EventMask_, bit32.bnot(L.EventInputRouting))
    _, g.DebugLogFlags = ImGui.CheckboxFlags("All", g.DebugLogFlags, all_enable_flags)
    ImGui.SetItemTooltip("(except InputRouting which is spammy)")
    for _, e in ipairs({ { "Errors", L.EventError }, { "ActiveId", L.EventActiveId }, { "Clipper", L.EventClipper }, { "Docking", L.EventDocking },
        { "Focus", L.EventFocus }, { "IO", L.EventIO }, { "Font", L.EventFont }, { "Nav", L.EventNav }, { "Popup", L.EventPopup },
        { "Selection", L.EventSelection }, { "Table", L.EventTable }, { "Viewport", L.EventViewport }, { "InputRouting", L.EventInputRouting } }) do
        ShowDebugLogFlag(e[1], e[2])
    end
    if ImGui.SmallButton("Clear") then
        if g.DebugLogBuf then g.DebugLogBuf:clear() end
        g.DebugLogLines = { "" }
    end
    ImGui.SameLine()
    if ImGui.SmallButton("Copy") then ImGui.SetClipboardText(g.DebugLogBuf and g.DebugLogBuf:c_str() or "") end
    ImGui.SameLine()
    if ImGui.SmallButton("Configure Outputs..") then ImGui.OpenPopup("Outputs") end
    if ImGui.BeginPopup("Outputs") then
        _, g.DebugLogFlags = ImGui.CheckboxFlags("OutputToTTY", g.DebugLogFlags, L.OutputToTTY)
        ImGui.BeginDisabled()
        _, g.DebugLogFlags = ImGui.CheckboxFlags("OutputToDebugger", g.DebugLogFlags, L.OutputToDebugger)
        _, g.DebugLogFlags = ImGui.CheckboxFlags("OutputToTestEngine", g.DebugLogFlags, L.OutputToTestEngine)
        ImGui.EndDisabled()
        ImGui.EndPopup()
    end

    ImGui.BeginChild("##log", ImVec2(0.0, 0.0), ImGuiChildFlags.Borders, bit32.bor(ImGuiWindowFlags.AlwaysVerticalScrollbar, ImGuiWindowFlags.AlwaysHorizontalScrollbar))
    local backup_log_flags = g.DebugLogFlags
    g.DebugLogFlags = bit32.band(g.DebugLogFlags, bit32.bnot(L.EventClipper))
    local lines = g.DebugLogLines or { "" }
    local count = #lines
    if lines[count] == "" then count = count - 1 end -- trailing partial line
    local clipper = ImGuiListClipper()
    clipper:Begin(count)
    while clipper:Step() do
        for line_no = clipper.DisplayStart, clipper.DisplayEnd - 1 do ImGui.TextUnformatted(lines[line_no + 1]) end
    end
    g.DebugLogFlags = backup_log_flags
    if ImGui.GetScrollY() >= ImGui.GetScrollMaxY() then ImGui.SetScrollHereY(1.0) end
    ImGui.EndChild()
    ImGui.End()
    return p_open
end

----------------------------------------------------------------
-- [SECTION] ID Stack Tool
----------------------------------------------------------------

local function PathQuery(g)
    local q = g.DebugItemPathQuery
    if q == nil then
        q = { MainID = 0, Active = false, Complete = false, Step = -1, Results = {} }
        g.DebugItemPathQuery = q
        g.DebugIDStackTool = { LastActiveFrame = -1, OptHexEncodeNonAsciiChars = true, OptCopyToClipboardOnCtrlC = false, CopyToClipboardLastTime = -FLT_MAX }
    end
    return q
end

-- Update queries. The steps are: -1: query Stack, >= 0: query each stack item
local function DebugItemPathQuery_UpdateAndGetHookId(query, id)
    if query.MainID ~= id then
        query.MainID = id
        query.Step = -1
        query.Complete = false
        query.Results = {}
    end
    query.Active = false
    if id == 0 then return 0 end
    local res = query.Results
    if query.Step >= 0 and query.Step < #res then
        if res[query.Step + 1].QuerySuccess or res[query.Step + 1].QueryFrameCount > 2 then query.Step = query.Step + 1 end
    end
    query.Complete = (query.Step == #res)
    if query.Step == -1 then
        query.Active = true
        return id
    elseif query.Step >= 0 and query.Step < #res then
        res[query.Step + 1].QueryFrameCount = res[query.Step + 1].QueryFrameCount + 1
        query.Active = true
        return res[query.Step + 1].ID
    end
    return 0
end

function ImGui.UpdateDebugToolItemPathQuery()
    local g = ImGui.GetCurrentContext()
    local q = PathQuery(g)
    local id = 0
    if g.DebugIDStackTool.LastActiveFrame + 1 == g.FrameCount then
        id = (g.HoveredIdPreviousFrame ~= 0 and g.HoveredIdPreviousFrame) or g.ActiveId
    end
    g.DebugHookIdInfoId = DebugItemPathQuery_UpdateAndGetHookId(q, id)
end

-- Hooks called by GetID() family functions. `data_id` is the string/number that was hashed.
function ImGui.DebugHookIdInfo(id, data_type, data_id)
    local g = ImGui.GetCurrentContext()
    local query = PathQuery(g)
    if not query.Active then return end
    local window = g.CurrentWindow
    if query.Step == -1 then
        query.Step = 0
        query.Results = {}
        for n = 0, window.IDStack.Size do
            query.Results[n + 1] = { ID = (n < window.IDStack.Size) and window.IDStack.Data[n + 1] or id, QueryFrameCount = 0, QuerySuccess = false, DataType = -1, Desc = nil }
        end
        return
    end
    if query.Step ~= window.IDStack.Size then return end
    local info = query.Results[query.Step + 1]
    if info == nil or info.ID ~= id then return end
    if info.Desc == nil then
        if data_type == ImGuiDataType.S32 then info.Desc = string.format("%d", data_id)
        elseif data_type == ImGuiDataType.String then info.Desc = tostring(data_id)
        else info.Desc = string.format("0x%08X [override]", id) end
    end
    info.QuerySuccess = true
    if info.DataType == -1 then info.DataType = data_type end
end

local function SkipUncontributingPrefix(label)
    local p = string.find(label, "###", 1, true)
    if p then return string.sub(label, p) end
    return label
end

local function FormatLevelInfo(g, query, n, format_for_ui)
    local info = query.Results[n + 1]
    local window = (info.Desc == nil and n == 0) and ImGui.FindWindowByID(info.ID) or nil
    if window then return string.format(format_for_ui and "\"%s\" [window]" or "%s", SkipUncontributingPrefix(window.Name)) end
    if info.QuerySuccess then return string.format((format_for_ui and info.DataType == ImGuiDataType.String) and "\"%s\"" or "%s", SkipUncontributingPrefix(info.Desc)) end
    if query.Step < #query.Results then return "" end
    return "???"
end

local function GetResultAsPath(g, query, hex_encode_non_ascii_chars)
    local out = {}
    for n = 0, #query.Results - 1 do
        local desc = FormatLevelInfo(g, query, n, false)
        out[#out + 1] = (n == 0) and "//" or "/"
        desc = string.gsub(desc, "/", "\\/")
        if hex_encode_non_ascii_chars then
            desc = string.gsub(desc, "[\128-\255]", function(c) return string.format("\\x%02x", string.byte(c)) end)
        end
        out[#out + 1] = desc
    end
    return table.concat(out)
end

function ImGui.ShowIDStackToolWindow(p_open)
    local g = ImGui.GetCurrentContext()
    if bit32.band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasSize) == 0 then
        ImGui.SetNextWindowSize(ImVec2(0.0, ImGui.GetFontSize() * 8.0), ImGuiCond.FirstUseEver)
    end
    local visible
    p_open, visible = ImGui.Begin("ImGui Sincerely ID Stack Tool", p_open)
    if not visible or ImGui.GetCurrentWindow().BeginCount > 1 then
        ImGui.End()
        return p_open
    end
    local query = PathQuery(g)
    local tool = g.DebugIDStackTool
    tool.LastActiveFrame = g.FrameCount
    local result_path = GetResultAsPath(g, query, tool.OptHexEncodeNonAsciiChars)
    ImGui.Text("0x%08X", query.MainID)
    ImGui.SameLine()
    MetricsHelpMarker("Hover an item with the mouse to display elements of the ID Stack leading to the item's final ID.\nEach level of the stack correspond to a PushID() call.\nAll levels of the stack are hashed together to make the final ID of a widget (ID displayed at the bottom level of the stack).\nRead FAQ entry about the ID stack for details.")
    local time_since_copy = g.Time - tool.CopyToClipboardLastTime
    ImGui.PushStyleVarY(ImGuiStyleVar.FramePadding, 0.0)
    _, tool.OptHexEncodeNonAsciiChars = ImGui.Checkbox("Hex-encode non-ASCII", tool.OptHexEncodeNonAsciiChars)
    ImGui.SameLine()
    _, tool.OptCopyToClipboardOnCtrlC = ImGui.Checkbox("Ctrl+C: copy path", tool.OptCopyToClipboardOnCtrlC)
    ImGui.PopStyleVar()
    ImGui.SameLine()
    ImGui.TextColored((time_since_copy >= 0.0 and time_since_copy < 0.75 and math.fmod(time_since_copy, 0.25) < 0.25 * 0.5) and ImVec4(1.0, 1.0, 0.3, 1.0) or ImVec4(), "*COPIED*")
    if tool.OptCopyToClipboardOnCtrlC and ImGui.Shortcut(bit32.bor(ImGuiMod_Ctrl, ImGuiKey.C), bit32.bor(ImGuiInputFlags.RouteGlobal, ImGuiInputFlags.RouteOverFocused)) then
        tool.CopyToClipboardLastTime = g.Time
        ImGui.SetClipboardText(result_path)
    end
    ImGui.Text("- Path \"%s\"", query.Complete and result_path or "")
    ImGui.Separator()
    if #query.Results > 0 and ImGui.BeginTable("##table", 3, ImGuiTableFlags.Borders) then
        local id_width = ImGui.CalcTextSize("0xDDDDDDDD").x
        ImGui.TableSetupColumn("Seed", ImGuiTableColumnFlags.WidthFixed, id_width)
        ImGui.TableSetupColumn("PushID", ImGuiTableColumnFlags.WidthStretch)
        ImGui.TableSetupColumn("Result", ImGuiTableColumnFlags.WidthFixed, id_width)
        ImGui.TableHeadersRow()
        for n = 0, #query.Results - 1 do
            local info = query.Results[n + 1]
            ImGui.TableNextColumn()
            ImGui.Text("0x%08X", (n > 0) and query.Results[n].ID or 0)
            ImGui.TableNextColumn()
            ImGui.TextUnformatted(FormatLevelInfo(g, query, n, true))
            ImGui.TableNextColumn()
            ImGui.Text("0x%08X", info.ID)
            if n == #query.Results - 1 then ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, ImGui.GetColorU32(ImGuiCol.Header)) end
        end
        ImGui.EndTable()
    end
    ImGui.End()
    return p_open
end

return true
