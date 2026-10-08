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

----------------------------------------------------------------
-- [SECTION] Metrics/Debugger window
----------------------------------------------------------------

local function B(v) return v and 1 or 0 end
local function FG(window) return ImGui.GetForegroundDrawList(window and window.Viewport or ImGui.GetMainViewport()) end
local function YellowRect(window, min, max) FG(window):AddRect(min, max, IM_COL32(255, 255, 0, 255)) end

function ImGui.DebugNodeColumns(columns)
    if not ImGui.TreeNode(columns.ID, "Columns Id: 0x%08X, Count: %d, Flags: 0x%04X", columns.ID, columns.Count, columns.Flags) then return end
    ImGui.BulletText("Width: %.1f (MinX: %.1f, MaxX: %.1f)", columns.OffMaxX - columns.OffMinX, columns.OffMinX, columns.OffMaxX)
    for i, column in columns.Columns:iter() do
        ImGui.BulletText("Column %02d: OffsetNorm %.3f (= %.1f px)", i - 1, column.OffsetNorm, ImGui.GetColumnOffsetFromNorm(columns, column.OffsetNorm))
    end
    ImGui.TreePop()
end

function ImGui.DebugNodeStorage(storage, label)
    local n = 0
    for _ in pairs(storage) do n = n + 1 end
    if not ImGui.TreeNode(label, "%s: %d entries", label, n) then return end
    for k, v in pairs(storage) do
        ImGui.BulletText("Key 0x%08X Value { %s }", tonumber(k) or 0, tostring(v))
    end
    ImGui.TreePop()
end

function ImGui.DebugNodeDrawList(window, viewport, draw_list, label)
    local g = ImGui.GetCurrentContext()
    local cfg = g.DebugMetricsConfig
    local cmd_count = draw_list.CmdBuffer.Size
    if cmd_count > 0 and draw_list.CmdBuffer.Data[cmd_count].ElemCount == 0 and draw_list.CmdBuffer.Data[cmd_count].UserCallback == nil then
        cmd_count = cmd_count - 1
    end
    local node_open = ImGui.TreeNode(tostring(draw_list), "%s: '%s' %d vtx, %d indices, %d cmds", label, draw_list._OwnerName or "", draw_list.VtxBuffer.Size, draw_list.IdxBuffer.Size, cmd_count)
    if draw_list == ImGui.GetWindowDrawList() then
        ImGui.SameLine()
        ImGui.TextColored(ImVec4(1.0, 0.4, 0.4, 1.0), "CURRENTLY APPENDING")
        if node_open then ImGui.TreePop() end
        return
    end
    local fg_draw_list = viewport and ImGui.GetForegroundDrawList(viewport) or nil
    if window and ImGui.IsItemHovered() and fg_draw_list then
        fg_draw_list:AddRect(window.Pos, window.Pos + window.Size, IM_COL32(255, 255, 0, 255))
    end
    if not node_open then return end
    if window and not window.WasActive then ImGui.TextDisabled("Warning: owning Window is inactive. This DrawList is not being rendered!") end

    local vtx, idx = draw_list.VtxBuffer.Data, draw_list.IdxBuffer.Data
    for cmd_n = 1, cmd_count do
        local pcmd = draw_list.CmdBuffer.Data[cmd_n]
        if pcmd.UserCallback then
            ImGui.BulletText("Callback %s", tostring(pcmd.UserCallback))
        else
            local cr = pcmd.ClipRect
            local open = ImGui.TreeNode(cmd_n, "DrawCmd:%5d tris, Tex %s, ClipRect (%4.0f,%4.0f)-(%4.0f,%4.0f)", math.floor(pcmd.ElemCount / 3), tostring(pcmd.TexRef and (pcmd.TexRef._TexID or pcmd.TexRef._TexData)), cr.x, cr.y, cr.z, cr.w)
            local function ShowMesh(show_mesh, show_aabb)
                if not fg_draw_list then return end
                local clip_rect = ImRect(cr.x, cr.y, cr.z, cr.w)
                local vtxs_rect = ImRect(FLT_MAX, FLT_MAX, -FLT_MAX, -FLT_MAX)
                local base = pcmd.IdxOffset
                for i = base, base + pcmd.ElemCount - 1, 3 do
                    local tri = {}
                    for n = 0, 2 do
                        local v = vtx[idx[i + n + 1] + pcmd.VtxOffset + 1]
                        if v == nil then return end
                        tri[n + 1] = ImVec2(v.pos.x, v.pos.y)
                        vtxs_rect:Add(tri[n + 1])
                    end
                    if show_mesh then fg_draw_list:AddPolyline(tri, 3, IM_COL32(255, 255, 0, 255), 1.0, ImDrawFlags.Closed) end
                end
                if show_aabb then
                    fg_draw_list:AddRect(ImTrunc(clip_rect.Min), ImTrunc(clip_rect.Max), IM_COL32(255, 0, 255, 255))
                    fg_draw_list:AddRect(ImTrunc(vtxs_rect.Min), ImTrunc(vtxs_rect.Max), IM_COL32(0, 255, 255, 255))
                end
            end
            if ImGui.IsItemHovered() and (cfg.ShowDrawCmdMesh or cfg.ShowDrawCmdBoundingBoxes) then ShowMesh(cfg.ShowDrawCmdMesh, cfg.ShowDrawCmdBoundingBoxes) end
            if open then
                ImGui.Selectable(string.format("Mesh: ElemCount: %d, VtxOffset: +%d, IdxOffset: +%d", pcmd.ElemCount, pcmd.VtxOffset, pcmd.IdxOffset))
                if ImGui.IsItemHovered() then ShowMesh(true, false) end
                ImGui.TreePop()
            end
        end
    end
    ImGui.TreePop()
end

function ImGui.DebugNodeTabBar(tab_bar, label)
    local g = ImGui.GetCurrentContext()
    local is_active = (tab_bar.PrevFrameVisible >= ImGui.GetFrameCount() - 2)
    local names = {}
    for tab_n = 1, math.min(tab_bar.Tabs.Size, 3) do
        local tab = tab_bar.Tabs.Data[tab_n]
        names[#names + 1] = "'" .. (ImGui.TabBarGetTabName and ImGui.TabBarGetTabName(tab_bar, tab) or "?") .. "'"
    end
    local buf = string.format("%s 0x%08X (%d tabs)%s  { %s%s", label, tab_bar.ID, tab_bar.Tabs.Size, is_active and "" or " *Inactive*", table.concat(names, ", "), (tab_bar.Tabs.Size > 3) and " ... }" or " } ")
    if not is_active then ImGui.PushStyleColor(ImGuiCol.Text, g.Style.Colors[ImGuiCol.TextDisabled]) end
    local open = ImGui.TreeNode(label, "%s", buf)
    if not is_active then ImGui.PopStyleColor() end
    if is_active and ImGui.IsItemHovered() then
        local dl = FG(tab_bar.Window)
        dl:AddRect(tab_bar.BarRect.Min, tab_bar.BarRect.Max, IM_COL32(255, 255, 0, 255))
        dl:AddLine(ImVec2(tab_bar.ScrollingRectMinX, tab_bar.BarRect.Min.y), ImVec2(tab_bar.ScrollingRectMinX, tab_bar.BarRect.Max.y), IM_COL32(0, 255, 0, 255))
        dl:AddLine(ImVec2(tab_bar.ScrollingRectMaxX, tab_bar.BarRect.Min.y), ImVec2(tab_bar.ScrollingRectMaxX, tab_bar.BarRect.Max.y), IM_COL32(0, 255, 0, 255))
    end
    if open then
        for tab_n, tab in tab_bar.Tabs:iter() do
            ImGui.PushID(tab_n)
            if ImGui.SmallButton("<") and ImGui.TabBarQueueReorder then ImGui.TabBarQueueReorder(tab_bar, tab, -1) end ImGui.SameLine(0, 2)
            if ImGui.SmallButton(">") and ImGui.TabBarQueueReorder then ImGui.TabBarQueueReorder(tab_bar, tab, 1) end ImGui.SameLine()
            ImGui.Text("%02d%s Tab 0x%08X '%s' Offset: %.2f, Width: %.2f/%.2f", tab_n - 1, (tab.ID == tab_bar.SelectedTabId) and "*" or " ", tab.ID,
                ImGui.TabBarGetTabName and ImGui.TabBarGetTabName(tab_bar, tab) or "?", tab.Offset, tab.Width, tab.ContentWidth)
            ImGui.PopID()
        end
        ImGui.TreePop()
    end
end

local function SizingDesc(f)
    local TF = ImGuiTableFlags
    f = bit32.band(f, TF.SizingMask_)
    if f == TF.SizingFixedFit then return "FixedFit" elseif f == TF.SizingFixedSame then return "FixedSame"
    elseif f == TF.SizingStretchProp then return "StretchProp" elseif f == TF.SizingStretchSame then return "StretchSame" end
    return "N/A"
end

function ImGui.DebugNodeTableSettings(settings, tbl)
    local open = ImGui.TreeNode(tostring(settings), "Settings 0x%08X (%d columns)", settings.ID, settings.ColumnsCount)
    local hovered = ImGui.IsItemHovered()
    if hovered and tbl == nil and settings.ID ~= 0 then tbl = ImGui.TableFindByID(settings.ID) end
    if hovered and tbl ~= nil then YellowRect(tbl.OuterWindow, tbl.OuterRect.Min, tbl.OuterRect.Max) end
    if open then
        ImGui.BulletText("SaveFlags: 0x%08X", settings.SaveFlags)
        ImGui.BulletText("ColumnsCount: %d (max %d)", settings.ColumnsCount, settings.ColumnsCountMax)
        for n = 0, settings.ColumnsCount - 1 do
            local c = settings.Columns[n]
            local dir = (c.SortOrder ~= -1) and c.SortDirection or ImGuiSortDirection.None
            ImGui.BulletText("Column %d Order %d SortOrder %2d %s Vis %d %s %7.3f ID 0x%08X", n, c.DisplayOrder, c.SortOrder,
                (dir == ImGuiSortDirection.Ascending) and "Asc" or ((dir == ImGuiSortDirection.Descending) and "Des" or "---"), c.IsEnabled, (c.IsStretch ~= 0) and "Weight" or "Width ", c.WidthOrWeight, c.ID)
        end
        ImGui.TreePop()
    end
end

function ImGui.DebugNodeTable(tbl)
    local g = ImGui.GetCurrentContext()
    local is_active = (tbl.LastFrameActive >= g.FrameCount - 2)
    if not is_active then ImGui.PushStyleColor(ImGuiCol.Text, g.Style.Colors[ImGuiCol.TextDisabled]) end
    local open = ImGui.TreeNode(tostring(tbl), "Table 0x%08X (%d columns, in '%s')%s", tbl.ID, tbl.ColumnsCount, tbl.OuterWindow and tbl.OuterWindow.Name or "?", is_active and "" or " *Inactive*")
    if not is_active then ImGui.PopStyleColor() end
    if ImGui.IsItemHovered() then YellowRect(tbl.OuterWindow, tbl.OuterRect.Min, tbl.OuterRect.Max) end
    if not open then return end
    if tbl.InstanceCurrent > 0 then ImGui.Text("** %d instances of same table! Some data below will refer to last instance.", tbl.InstanceCurrent + 1) end
    local clear_settings = ImGui.SmallButton("Clear settings")
    ImGui.BulletText("OuterRect: Pos: (%.1f,%.1f) Size: (%.1f,%.1f) Sizing: '%s'", tbl.OuterRect.Min.x, tbl.OuterRect.Min.y, tbl.OuterRect:GetWidth(), tbl.OuterRect:GetHeight(), SizingDesc(tbl.Flags))
    ImGui.BulletText("ColumnsGivenWidth: %.1f, ColumnsAutoFitWidth: %.1f, InnerWidth: %.1f%s", tbl.ColumnsGivenWidth, tbl.ColumnsAutoFitWidth, tbl.InnerWidth, (tbl.InnerWidth == 0.0) and " (auto)" or "")
    ImGui.BulletText("CellPaddingX: %.1f, CellSpacingX: %.1f/%.1f, OuterPaddingX: %.1f", tbl.CellPaddingX, tbl.CellSpacingX1, tbl.CellSpacingX2, tbl.OuterPaddingX)
    ImGui.BulletText("HoveredColumnBody: %d, HoveredColumnBorder: %d", tbl.HoveredColumnBody, tbl.HoveredColumnBorder)
    ImGui.BulletText("ResizedColumn: %d, HeldHeaderColumn: %d, ReorderColumn: %d", tbl.LastResizedColumn, tbl.LastHeldHeaderColumn, tbl.ReorderColumn)
    for n = 0, tbl.InstanceCurrent do
        local inst = ImGui.TableGetInstanceData(tbl, n)
        ImGui.BulletText("Instance %d: HoveredRow: %d, LastOuterHeight: %.2f", n, inst.HoveredRowLast, inst.LastOuterHeight)
    end
    local sum_weights = 0.0
    for n = 0, tbl.ColumnsCount - 1 do
        if bit32.band(tbl.Columns[n].Flags, ImGuiTableColumnFlags.WidthStretch) ~= 0 then sum_weights = sum_weights + tbl.Columns[n].StretchWeight end
    end
    for n = 0, tbl.ColumnsCount - 1 do
        local c = tbl.Columns[n]
        local CF = ImGuiTableColumnFlags
        local buf = string.format(
            "Column %d order %d '%s': offset %+.2f to %+.2f%s\nEnabled: %d, VisibleX/Y: %d/%d, RequestOutput: %d, SkipItems: %d, DrawChannels: %d,%d\n" ..
            "WidthGiven: %.1f, Request/Auto: %.1f/%.1f, StretchWeight: %.3f (%.1f%%)\nMinX: %.1f, MaxX: %.1f (%+.1f), ClipRect: %.1f to %.1f (+%.1f)\n" ..
            "ContentWidth: %.1f,%.1f, HeadersUsed/Ideal %.1f/%.1f\nSort: %d%s, UserData: 0x%08X, Flags: 0x%04X: %s%s%s..",
            n, c.DisplayOrder, ImGui.TableGetColumnName(tbl, n) or "", c.MinX - tbl.WorkRect.Min.x, c.MaxX - tbl.WorkRect.Min.x, (n < tbl.FreezeColumnsRequest) and " (Frozen)" or "",
            B(c.IsEnabled), B(c.IsVisibleX), B(c.IsVisibleY), B(c.IsRequestOutput), B(c.IsSkipItems), c.DrawChannelFrozen, c.DrawChannelUnfrozen,
            c.WidthGiven, c.WidthRequest, c.WidthAuto, c.StretchWeight, (c.StretchWeight > 0.0 and sum_weights > 0) and (c.StretchWeight / sum_weights) * 100.0 or 0.0,
            c.MinX, c.MaxX, c.MaxX - c.MinX, c.ClipRect.Min.x, c.ClipRect.Max.x, c.ClipRect.Max.x - c.ClipRect.Min.x,
            c.ContentMaxXFrozen - c.WorkMinX, c.ContentMaxXUnfrozen - c.WorkMinX, c.ContentMaxXHeadersUsed - c.WorkMinX, c.ContentMaxXHeadersIdeal - c.WorkMinX,
            c.SortOrder, (c.SortDirection == ImGuiSortDirection.Ascending) and " (Asc)" or ((c.SortDirection == ImGuiSortDirection.Descending) and " (Des)" or ""), tonumber(c.UserData) or 0, c.Flags,
            (bit32.band(c.Flags, CF.WidthStretch) ~= 0) and "WidthStretch " or "", (bit32.band(c.Flags, CF.WidthFixed) ~= 0) and "WidthFixed " or "", (bit32.band(c.Flags, CF.NoResize) ~= 0) and "NoResize " or "")
        ImGui.Bullet()
        ImGui.Selectable(buf)
        if ImGui.IsItemHovered() then YellowRect(tbl.OuterWindow, ImVec2(c.MinX, tbl.OuterRect.Min.y), ImVec2(c.MaxX, tbl.OuterRect.Max.y)) end
    end
    local settings = ImGui.TableGetBoundSettings(tbl)
    if settings then ImGui.DebugNodeTableSettings(settings, tbl) end
    if clear_settings then tbl.IsResetAllRequest = true end
    ImGui.TreePop()
end

local function DebugNodeDockNodeFlags(flags, label, enabled)
    local D = ImGuiDockNodeFlags
    ImGui.PushID(label)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, ImVec2(0.0, 0.0))
    ImGui.Text("%s:", label)
    if not enabled then ImGui.BeginDisabled() end
    for _, n in ipairs({ "NoResize", "NoResizeX", "NoResizeY", "NoTabBar", "HiddenTabBar", "NoWindowMenuButton", "NoCloseButton", "DockedWindowsInFocusRoute",
        "NoDocking", "NoDockingSplit", "NoDockingSplitOther", "NoDockingOverMe", "NoDockingOverOther", "NoDockingOverEmpty", "NoUndocking" }) do
        if D[n] then _, flags = ImGui.CheckboxFlags(n, flags, D[n]) end
    end
    if not enabled then ImGui.EndDisabled() end
    ImGui.PopStyleVar()
    ImGui.PopID()
    return flags
end

function ImGui.DebugNodeDockNode(node, label)
    local g = ImGui.GetCurrentContext()
    local is_alive = (g.FrameCount - node.LastFrameAlive < 2)
    local is_active = (g.FrameCount - node.LastFrameActive < 2)
    if not is_alive then ImGui.PushStyleColor(ImGuiCol.Text, g.Style.Colors[ImGuiCol.TextDisabled]) end
    local tree_node_flags = node.IsFocused and ImGuiTreeNodeFlags.Selected or ImGuiTreeNodeFlags.None
    local open
    if node.Windows.Size > 0 then
        open = ImGui.TreeNodeEx(node.ID, tree_node_flags, "%s 0x%04X%s: %d windows (vis: '%s')", label, node.ID, node.IsVisible and "" or " (hidden)", node.Windows.Size, node.VisibleWindow and node.VisibleWindow.Name or "NULL")
    else
        local kind = (node.SplitAxis == ImGuiAxis.X) and "horizontal split" or ((node.SplitAxis == ImGuiAxis.Y) and "vertical split" or "empty")
        open = ImGui.TreeNodeEx(node.ID, tree_node_flags, "%s 0x%04X%s: %s (vis: '%s')", label, node.ID, node.IsVisible and "" or " (hidden)", kind, node.VisibleWindow and node.VisibleWindow.Name or "NULL")
    end
    if not is_alive then ImGui.PopStyleColor() end
    if is_active and ImGui.IsItemHovered() then
        local window = node.HostWindow or node.VisibleWindow
        if window then YellowRect(window, node.Pos, node.Pos + node.Size) end
    end
    if open then
        ImGui.BulletText("Pos (%.0f,%.0f), Size (%.0f, %.0f) Ref (%.0f, %.0f)", node.Pos.x, node.Pos.y, node.Size.x, node.Size.y, node.SizeRef.x, node.SizeRef.y)
        ImGui.DebugNodeWindow(node.HostWindow, "HostWindow")
        ImGui.DebugNodeWindow(node.VisibleWindow, "VisibleWindow")
        ImGui.BulletText("SelectedTabID: 0x%08X, LastFocusedNodeID: 0x%08X", node.SelectedTabId, node.LastFocusedNodeId)
        ImGui.BulletText("Misc:%s%s%s%s%s%s%s", node:IsDockSpace() and " IsDockSpace" or "", node:IsCentralNode() and " IsCentralNode" or "",
            is_alive and " IsAlive" or "", is_active and " IsActive" or "", node.IsFocused and " IsFocused" or "", node.WantLockSizeOnce and " WantLockSizeOnce" or "", node.HasCentralNodeChild and " HasCentralNodeChild" or "")
        if ImGui.TreeNode("flags", "Flags Merged: 0x%04X, Local: 0x%04X, InWindows: 0x%04X, Shared: 0x%04X", node.MergedFlags, node.LocalFlags, node.LocalFlagsInWindows, node.SharedFlags) then
            if ImGui.BeginTable("flags", 4) then
                ImGui.TableNextColumn(); DebugNodeDockNodeFlags(node.MergedFlags, "MergedFlags", false)
                ImGui.TableNextColumn(); node.LocalFlags = DebugNodeDockNodeFlags(node.LocalFlags, "LocalFlags", true)
                ImGui.TableNextColumn(); DebugNodeDockNodeFlags(node.LocalFlagsInWindows, "LocalFlagsInWindows", false)
                ImGui.TableNextColumn(); node.SharedFlags = DebugNodeDockNodeFlags(node.SharedFlags, "SharedFlags", true)
                ImGui.EndTable()
            end
            ImGui.TreePop()
        end
        if node.ParentNode then ImGui.DebugNodeDockNode(node.ParentNode, "ParentNode") end
        if node.ChildNodes[0] then ImGui.DebugNodeDockNode(node.ChildNodes[0], "Child[0]") end
        if node.ChildNodes[1] then ImGui.DebugNodeDockNode(node.ChildNodes[1], "Child[1]") end
        if node.TabBar then ImGui.DebugNodeTabBar(node.TabBar, "TabBar") end
        ImGui.DebugNodeWindowsList(node.Windows, "Windows")
        ImGui.TreePop()
    end
end

function ImGui.DebugNodeWindow(window, label)
    if window == nil then
        ImGui.BulletText("%s: NULL", label)
        return
    end
    local g = ImGui.GetCurrentContext()
    local is_active = window.WasActive
    local tree_node_flags = (window == g.NavWindow) and ImGuiTreeNodeFlags.Selected or ImGuiTreeNodeFlags.None
    if not is_active then ImGui.PushStyleColor(ImGuiCol.Text, g.Style.Colors[ImGuiCol.TextDisabled]) end
    local open = ImGui.TreeNodeEx(label, tree_node_flags, "%s '%s'%s", label, window.Name, is_active and "" or " *Inactive*")
    if not is_active then ImGui.PopStyleColor() end
    if ImGui.IsItemHovered() and is_active then YellowRect(window, window.Pos, window.Pos + window.Size) end
    if not open then return end
    if window.MemoryCompacted then ImGui.TextDisabled("Note: some memory buffers have been compacted/freed.") end
    local W = ImGuiWindowFlags
    local flags = window.Flags
    local function F(f, s) return (bit32.band(flags, f) ~= 0) and s or "" end
    ImGui.DebugNodeDrawList(window, window.Viewport, window.DrawList, "DrawList")
    ImGui.BulletText("Pos: (%.1f,%.1f), Size: (%.1f,%.1f), ContentSize (%.1f,%.1f) Ideal (%.1f,%.1f)", window.Pos.x, window.Pos.y, window.Size.x, window.Size.y, window.ContentSize.x, window.ContentSize.y, window.ContentSizeIdeal.x, window.ContentSizeIdeal.y)
    ImGui.BulletText("Flags: 0x%08X (%s%s%s%s%s%s%s%s%s..)", flags, F(W.ChildWindow, "Child "), F(W.Tooltip, "Tooltip "), F(W.Popup, "Popup "), F(W.Modal, "Modal "), F(W.ChildMenu, "ChildMenu "),
        F(W.NoSavedSettings, "NoSavedSettings "), F(W.NoMouseInputs, "NoMouseInputs"), F(W.NoNavInputs, "NoNavInputs"), F(W.AlwaysAutoResize, "AlwaysAutoResize"))
    if bit32.band(flags, W.ChildWindow) ~= 0 then
        local cf = window.ChildFlags or 0
        local C = ImGuiChildFlags
        ImGui.BulletText("ChildFlags: 0x%08X (%s%s%s%s..)", cf, (bit32.band(cf, C.Borders) ~= 0) and "Borders " or "", (bit32.band(cf, C.ResizeX) ~= 0) and "ResizeX " or "",
            (bit32.band(cf, C.ResizeY) ~= 0) and "ResizeY " or "", (bit32.band(cf, C.NavFlattened) ~= 0) and "NavFlattened " or "")
    end
    ImGui.BulletText("WindowClassId: 0x%08X", window.WindowClass and window.WindowClass.ClassId or 0)
    ImGui.BulletText("Scroll: (%.2f/%.2f,%.2f/%.2f) Scrollbar:%s%s", window.Scroll.x, window.ScrollMax.x, window.Scroll.y, window.ScrollMax.y, window.ScrollbarX and "X" or "", window.ScrollbarY and "Y" or "")
    ImGui.BulletText("Active: %d/%d, WriteAccessed: %d, BeginOrderWithinContext: %d", B(window.Active), B(window.WasActive), B(window.WriteAccessed), (window.Active or window.WasActive) and window.BeginOrderWithinContext or -1)
    ImGui.BulletText("Appearing: %d, Hidden: %d (CanSkip %d Cannot %d), SkipItems: %d", B(window.Appearing), B(window.Hidden), window.HiddenFramesCanSkipItems, window.HiddenFramesCannotSkipItems, B(window.SkipItems))
    for layer = 0, 1 do
        local r = window.NavRectRel[layer]
        if r.Min.x >= r.Max.x and r.Min.y >= r.Max.y then
            ImGui.BulletText("NavLastIds[%d]: 0x%08X", layer, window.NavLastIds[layer])
        else
            ImGui.BulletText("NavLastIds[%d]: 0x%08X at +(%.1f,%.1f)(%.1f,%.1f)", layer, window.NavLastIds[layer], r.Min.x, r.Min.y, r.Max.x, r.Max.y)
        end
    end
    ImGui.BulletText("NavLayersActiveMask: %X, NavLastChildNavWindow: %s", window.DC.NavLayersActiveMask, window.NavLastChildNavWindow and window.NavLastChildNavWindow.Name or "NULL")
    ImGui.BulletText("Viewport: %d%s, ViewportId: 0x%08X, ViewportPos: (%.1f,%.1f)", window.Viewport and (window.Viewport.Idx or 0) or -1, window.ViewportOwned and " (Owned)" or "", window.ViewportId or 0, window.ViewportPos.x, window.ViewportPos.y)
    ImGui.BulletText("DockId: 0x%04X, DockOrder: %d, Act: %d, Vis: %d", window.DockId or 0, window.DockOrder or -1, B(window.DockIsActive), B(window.DockTabIsVisible))
    if window.DockNode or window.DockNodeAsHost then
        ImGui.DebugNodeDockNode(window.DockNodeAsHost or window.DockNode, window.DockNodeAsHost and "DockNodeAsHost" or "DockNode")
    end
    if window.RootWindow ~= window then ImGui.DebugNodeWindow(window.RootWindow, "RootWindow") end
    if window.RootWindowDockTree and window.RootWindowDockTree ~= window.RootWindow then ImGui.DebugNodeWindow(window.RootWindowDockTree, "RootWindowDockTree") end
    if window.ParentWindow ~= nil then ImGui.DebugNodeWindow(window.ParentWindow, "ParentWindow") end
    if window.ParentWindowForFocusRoute ~= nil then ImGui.DebugNodeWindow(window.ParentWindowForFocusRoute, "ParentWindowForFocusRoute") end
    if window.DC.ChildWindows.Size > 0 then ImGui.DebugNodeWindowsList(window.DC.ChildWindows, "ChildWindows") end
    if window.ColumnsStorage.Size > 0 and ImGui.TreeNode("Columns", "Columns sets (%d)", window.ColumnsStorage.Size) then
        for _, columns in window.ColumnsStorage:iter() do ImGui.DebugNodeColumns(columns) end
        ImGui.TreePop()
    end
    ImGui.DebugNodeStorage(window.StateStorage, "Storage")
    ImGui.TreePop()
end

function ImGui.DebugNodeWindowSettings(settings)
    if settings.WantDelete then ImGui.BeginDisabled() end
    ImGui.BulletText("0x%08X \"%s\" Pos (%d,%d) Size (%d,%d) Collapsed=%d", settings.ID, settings.Name or "", settings.Pos.x, settings.Pos.y, settings.Size.x, settings.Size.y, B(settings.Collapsed))
    if settings.WantDelete then ImGui.EndDisabled() end
end

function ImGui.DebugNodeWindowsList(windows, label)
    if not ImGui.TreeNode(label, "%s (%d)", label, windows.Size) then return end
    for i = windows.Size, 1, -1 do
        ImGui.PushID(tostring(windows.Data[i]))
        ImGui.DebugNodeWindow(windows.Data[i], "Window")
        ImGui.PopID()
    end
    ImGui.TreePop()
end

function ImGui.DebugNodeWindowsListByBeginStackParent(windows, first, last, parent_in_begin_stack)
    for i = first, last do
        local window = windows[i]
        if window.ParentWindowInBeginStack == parent_in_begin_stack then
            local buf = string.format("[%04d] Window", window.BeginOrderWithinContext)
            ImGui.DebugNodeWindow(window, buf)
            ImGui.TreePush(buf)
            ImGui.DebugNodeWindowsListByBeginStackParent(windows, i + 1, last, window)
            ImGui.TreePop()
        end
    end
end

function ImGui.DebugNodeViewport(viewport)
    local g = ImGui.GetCurrentContext()
    ImGui.SetNextItemOpen(true, ImGuiCond.Once)
    local open = ImGui.TreeNode(viewport.ID, "Viewport #%d, ID: 0x%08X, Parent: 0x%08X, Window: \"%s\"", viewport.Idx or 0, viewport.ID, viewport.ParentViewportId or 0, viewport.Window and viewport.Window.Name or "N/A")
    if ImGui.IsItemHovered() then g.DebugMetricsConfig.HighlightViewportID = viewport.ID end
    if open then
        ImGui.BulletText("Main Pos: (%.0f,%.0f), Size: (%.0f,%.0f)\nFrameBufferScale: (%.2f,%.2f)\nWorkArea Inset Left: %.0f Top: %.0f, Right: %.0f, Bottom: %.0f\nMonitor: %d, DpiScale: %.0f%%",
            viewport.Pos.x, viewport.Pos.y, viewport.Size.x, viewport.Size.y, viewport.FramebufferScale and viewport.FramebufferScale.x or 1, viewport.FramebufferScale and viewport.FramebufferScale.y or 1,
            viewport.WorkInsetMin.x, viewport.WorkInsetMin.y, viewport.WorkInsetMax.x, viewport.WorkInsetMax.y, viewport.PlatformMonitor or 0, (viewport.DpiScale or 1) * 100.0)
        ImGui.BulletText("Flags: 0x%04X", viewport.Flags or 0)
        if viewport.DrawDataP then
            for _, draw_list in viewport.DrawDataP.CmdLists:iter() do ImGui.DebugNodeDrawList(nil, viewport, draw_list, "DrawList") end
        end
        ImGui.TreePop()
    end
end

function ImGui.DebugTextEncoding(str)
    ImGui.Text("Text: \"%s\"", str)
    if not ImGui.BeginTable("##DebugTextEncoding", 4, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg, ImGuiTableFlags.SizingFixedFit, ImGuiTableFlags.Resizable)) then return end
    ImGui.TableSetupColumn("Offset")
    ImGui.TableSetupColumn("UTF-8")
    ImGui.TableSetupColumn("Glyph")
    ImGui.TableSetupColumn("Codepoint")
    ImGui.TableHeadersRow()
    for pos, c in utf8.codes(str) do
        local nxt = utf8.offset(str, 2, pos) or (#str + 1)
        ImGui.TableNextColumn()
        ImGui.Text("%d", pos - 1)
        ImGui.TableNextColumn()
        for b = pos, nxt - 1 do
            if b > pos then ImGui.SameLine() end
            ImGui.Text("0x%02X", string.byte(str, b))
        end
        ImGui.TableNextColumn()
        ImGui.TextUnformatted(string.sub(str, pos, nxt - 1))
        ImGui.TableNextColumn()
        ImGui.Text("U+%04X", c)
    end
    ImGui.EndTable()
end

local WRT_Names = { "OuterRect", "OuterRectClipped", "InnerRect", "InnerClipRect", "WorkRect", "Content", "ContentIdeal", "ContentRegionRect" }
local TRT_Names = { "OuterRect", "InnerRect", "WorkRect", "HostClipRect", "InnerClipRect", "BackgroundClipRect", "ColumnsRect", "ColumnsWorkRect", "ColumnsClipRect",
    "ColumnsContentHeadersUsed", "ColumnsContentHeadersIdeal", "ColumnsContentFrozen", "ColumnsContentUnfrozen" }
local TRT_ColumnsRect = 6

local function GetWindowRect(window, t)
    if t == 0 then return window:Rect()
    elseif t == 1 then return window.OuterRectClipped
    elseif t == 2 then return window.InnerRect
    elseif t == 3 then return window.InnerClipRect
    elseif t == 4 then return window.WorkRect
    elseif t == 5 then local m = window.InnerRect.Min - window.Scroll + window.WindowPadding; return ImRect(m, m + window.ContentSize)
    elseif t == 6 then local m = window.InnerRect.Min - window.Scroll + window.WindowPadding; return ImRect(m, m + window.ContentSizeIdeal)
    else return window.ContentRegionRect end
end

local function GetTableRect(tbl, t, n)
    local inst = ImGui.TableGetInstanceData(tbl, tbl.InstanceCurrent)
    if t == 0 then return tbl.OuterRect elseif t == 1 then return tbl.InnerRect elseif t == 2 then return tbl.WorkRect
    elseif t == 3 then return tbl.HostClipRect elseif t == 4 then return tbl.InnerClipRect elseif t == 5 then return tbl.BgClipRect end
    local c = tbl.Columns[n]
    if t == 6 then return ImRect(c.MinX, tbl.InnerClipRect.Min.y, c.MaxX, tbl.InnerClipRect.Min.y + inst.LastOuterHeight)
    elseif t == 7 then return ImRect(c.WorkMinX, tbl.WorkRect.Min.y, c.WorkMaxX, tbl.WorkRect.Max.y)
    elseif t == 8 then return c.ClipRect
    elseif t == 9 then return ImRect(c.WorkMinX, tbl.InnerClipRect.Min.y, c.ContentMaxXHeadersUsed, tbl.InnerClipRect.Min.y + inst.LastTopHeadersRowHeight)
    elseif t == 10 then return ImRect(c.WorkMinX, tbl.InnerClipRect.Min.y, c.ContentMaxXHeadersIdeal, tbl.InnerClipRect.Min.y + inst.LastTopHeadersRowHeight)
    elseif t == 11 then return ImRect(c.WorkMinX, tbl.InnerClipRect.Min.y, c.ContentMaxXFrozen, tbl.InnerClipRect.Min.y + inst.LastFrozenHeight)
    else return ImRect(c.WorkMinX, tbl.InnerClipRect.Min.y + inst.LastFrozenHeight, c.ContentMaxXUnfrozen, tbl.InnerClipRect.Max.y) end
end

local function ForEachTable(g, fn)
    for i = 0, g.Tables:GetMapSize() - 1 do
        local t = g.Tables:GetByIndex(i)
        if t then fn(t) end
    end
end

local MetricsEncodingBuf = nil
local MetricsDockRootOnly = true
function ImGui.ShowMetricsWindow(p_open)
    local g = ImGui.GetCurrentContext()
    local io = g.IO
    local cfg = g.DebugMetricsConfig
    if cfg.ShowDebugLog then cfg.ShowDebugLog = ImGui.ShowDebugLogWindow(cfg.ShowDebugLog) end
    if cfg.ShowIDStackTool then cfg.ShowIDStackTool = ImGui.ShowIDStackToolWindow(cfg.ShowIDStackTool) end

    local visible
    p_open, visible = ImGui.Begin("ImGui Sincerely Metrics/Debugger", p_open)
    if not visible or ImGui.GetCurrentWindow().BeginCount > 1 then
        ImGui.End()
        return p_open
    end

    ImGui.Text("Dear ImGui %s (%d)", IMGUI_VERSION, IMGUI_VERSION_NUM)
    ImGui.Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / math.max(io.Framerate, 0.0001), io.Framerate)
    ImGui.Text("%d vertices, %d indices (%d triangles)", io.MetricsRenderVertices, io.MetricsRenderIndices, math.floor(io.MetricsRenderIndices / 3))
    ImGui.Text("%d visible windows, %d current allocations", io.MetricsRenderWindows, g.DebugAllocInfo.TotalAllocCount - g.DebugAllocInfo.TotalFreeCount)
    ImGui.Separator()

    if cfg.ShowWindowsRectsType == nil or cfg.ShowWindowsRectsType < 0 then cfg.ShowWindowsRectsType = 4 end
    if cfg.ShowTablesRectsType == nil or cfg.ShowTablesRectsType < 0 then cfg.ShowTablesRectsType = 2 end

    -- Tools
    if ImGui.TreeNode("Tools") then
        ImGui.SeparatorText("Visualize")
        _, cfg.ShowDebugLog = ImGui.Checkbox("Show Debug Log", cfg.ShowDebugLog == true)
        ImGui.SameLine(); MetricsHelpMarker("You can also call ImGui::ShowDebugLogWindow() from your code.")
        _, cfg.ShowIDStackTool = ImGui.Checkbox("Show ID Stack Tool", cfg.ShowIDStackTool == true)
        ImGui.SameLine(); MetricsHelpMarker("You can also call ImGui::ShowIDStackToolWindow() from your code.")
        _, cfg.ShowWindowsBeginOrder = ImGui.Checkbox("Show windows begin order", cfg.ShowWindowsBeginOrder == true)
        _, cfg.ShowWindowsRects = ImGui.Checkbox("Show windows rectangles", cfg.ShowWindowsRects == true)
        ImGui.SameLine()
        ImGui.SetNextItemWidth(ImGui.GetFontSize() * 12)
        local changed
        cfg.ShowWindowsRectsType, changed = ImGui.Combo("##show_windows_rect_type", cfg.ShowWindowsRectsType, WRT_Names, #WRT_Names, #WRT_Names)
        cfg.ShowWindowsRects = cfg.ShowWindowsRects or changed
        if cfg.ShowWindowsRects and g.NavWindow ~= nil then
            ImGui.BulletText("'%s':", g.NavWindow.Name)
            ImGui.Indent()
            for rect_n = 0, #WRT_Names - 1 do
                local r = GetWindowRect(g.NavWindow, rect_n)
                ImGui.Text("(%6.1f,%6.1f) (%6.1f,%6.1f) Size (%6.1f,%6.1f) %s", r.Min.x, r.Min.y, r.Max.x, r.Max.y, r:GetWidth(), r:GetHeight(), WRT_Names[rect_n + 1])
            end
            ImGui.Unindent()
        end
        _, cfg.ShowTablesRects = ImGui.Checkbox("Show tables rectangles", cfg.ShowTablesRects == true)
        ImGui.SameLine()
        ImGui.SetNextItemWidth(ImGui.GetFontSize() * 12)
        cfg.ShowTablesRectsType, changed = ImGui.Combo("##show_table_rects_type", cfg.ShowTablesRectsType, TRT_Names, #TRT_Names, #TRT_Names)
        cfg.ShowTablesRects = cfg.ShowTablesRects or changed
        _, g.DebugShowGroupRects = ImGui.Checkbox("Show groups rectangles", g.DebugShowGroupRects == true)

        ImGui.SeparatorText("Validate")
        _, io.ConfigDebugBeginReturnValueLoop = ImGui.Checkbox("Debug Begin/BeginChild return value", io.ConfigDebugBeginReturnValueLoop == true)
        ImGui.SameLine(); MetricsHelpMarker("Some calls to Begin()/BeginChild() will return false.\n\nWill cycle through window depths then repeat. Windows should be flickering while running.")
        _, cfg.ShowTextEncodingViewer = ImGui.Checkbox("UTF-8 Encoding viewer", cfg.ShowTextEncodingViewer == true)
        ImGui.SameLine(); MetricsHelpMarker("You can also call ImGui::DebugTextEncoding() from your code with a given string to test that your UTF-8 encoding settings are correct.")
        if cfg.ShowTextEncodingViewer then
            MetricsEncodingBuf = MetricsEncodingBuf or DemoBuf("", 64)
            ImGui.SetNextItemWidth(-FLT_MIN)
            ImGui.InputText("##DebugTextEncodingBuf", MetricsEncodingBuf, 64)
            local str = DemoBufStr(MetricsEncodingBuf)
            if str ~= "" then ImGui.DebugTextEncoding(str) end
        end
        ImGui.TreePop()
    end

    -- Windows
    if ImGui.TreeNode("Windows", "Windows (%d)", g.Windows.Size) then
        ImGui.DebugNodeWindowsList(g.Windows, "By display order")
        ImGui.DebugNodeWindowsList(g.WindowsFocusOrder, "By focus order (root windows)")
        if ImGui.TreeNode("By submission order (begin stack)") then
            local tmp = {}
            for _, window in g.Windows:iter() do
                if window.LastFrameActive + 1 >= g.FrameCount then tmp[#tmp + 1] = window end
            end
            table.sort(tmp, function(a, b) return a.BeginOrderWithinContext < b.BeginOrderWithinContext end)
            ImGui.DebugNodeWindowsListByBeginStackParent(tmp, 1, #tmp, nil)
            ImGui.TreePop()
        end
        ImGui.TreePop()
    end

    -- DrawLists
    local drawlist_count = 0
    for _, viewport in g.Viewports:iter() do drawlist_count = drawlist_count + viewport.DrawDataP.CmdLists.Size end
    if ImGui.TreeNode("DrawLists", "DrawLists (%d)", drawlist_count) then
        _, cfg.ShowDrawCmdMesh = ImGui.Checkbox("Show ImDrawCmd mesh when hovering", cfg.ShowDrawCmdMesh ~= false)
        _, cfg.ShowDrawCmdBoundingBoxes = ImGui.Checkbox("Show ImDrawCmd bounding boxes when hovering", cfg.ShowDrawCmdBoundingBoxes ~= false)
        for _, viewport in g.Viewports:iter() do
            local has = false
            for _, draw_list in viewport.DrawDataP.CmdLists:iter() do
                if not has then ImGui.Text("Active DrawLists in Viewport #%d, ID: 0x%08X", viewport.Idx or 0, viewport.ID) end
                has = true
                ImGui.DebugNodeDrawList(nil, viewport, draw_list, "DrawList")
            end
        end
        ImGui.TreePop()
    end

    -- Viewports
    if ImGui.TreeNode("Viewports", "Viewports (%d)", g.Viewports.Size) then
        ImGui.SetNextItemOpen(true, ImGuiCond.Once)
        if ImGui.TreeNode("Windows Minimap") then
            ImGui.RenderViewportsThumbnails()
            ImGui.TreePop()
        end
        cfg.HighlightViewportID = 0
        for _, viewport in g.Viewports:iter() do ImGui.DebugNodeViewport(viewport) end
        ImGui.TreePop()
    end

    -- Fonts
    for i, atlas in g.FontAtlases:iter() do
        if ImGui.TreeNode(tostring(atlas), "Fonts (%d), Textures (%d)", atlas.Fonts.Size, atlas.TexList.Size) then
            ImGui.ShowFontAtlas(atlas)
            ImGui.TreePop()
        end
    end

    -- Popups
    if ImGui.TreeNode("Popups", "Popups (%d)", g.OpenPopupStack.Size) then
        for _, popup_data in g.OpenPopupStack:iter() do
            local window = popup_data.Window
            local W = ImGuiWindowFlags
            ImGui.BulletText("PopupID: %08x, Window: '%s' (%s%s), RestoreNavWindow '%s', ParentWindow '%s'", popup_data.PopupId, window and window.Name or "NULL",
                (window and bit32.band(window.Flags, W.ChildWindow) ~= 0) and "Child;" or "", (window and bit32.band(window.Flags, W.ChildMenu) ~= 0) and "Menu;" or "",
                popup_data.RestoreNavWindow and popup_data.RestoreNavWindow.Name or "NULL", (window and window.ParentWindow) and window.ParentWindow.Name or "NULL")
        end
        ImGui.TreePop()
    end

    -- TabBars
    if ImGui.TreeNode("TabBars", "Tab Bars (%d)", g.TabBars.AliveCount) then
        for n = 0, g.TabBars:GetMapSize() - 1 do
            local tab_bar = g.TabBars:GetByIndex(n)
            if tab_bar then
                ImGui.PushID(n)
                ImGui.DebugNodeTabBar(tab_bar, "TabBar")
                ImGui.PopID()
            end
        end
        ImGui.TreePop()
    end

    -- Tables
    if ImGui.TreeNode("Tables", "Tables (%d)", g.Tables.AliveCount) then
        ForEachTable(g, ImGui.DebugNodeTable)
        ImGui.TreePop()
    end

    -- Docking
    if ImGui.TreeNode("Docking") then
        local dc = g.DockContext
        _, MetricsDockRootOnly = ImGui.Checkbox("List root nodes", MetricsDockRootOnly)
        _, cfg.ShowDockingNodes = ImGui.Checkbox("Ctrl shows window dock info", cfg.ShowDockingNodes == true)
        if ImGui.SmallButton("Clear nodes") then ImGui.DockContextClearNodes(g, 0, true) end
        ImGui.SameLine()
        if ImGui.SmallButton("Rebuild all") then dc.WantFullRebuild = true end
        local ids = {}
        for id in pairs(dc.Nodes) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local node = dc.Nodes[id]
            if node and (not MetricsDockRootOnly or node:IsRootNode()) then ImGui.DebugNodeDockNode(node, "Node") end
        end
        ImGui.TreePop()
    end

    -- Settings
    if ImGui.TreeNode("Settings") then
        if ImGui.SmallButton("Clear") then ImGui.ClearIniSettings() end
        ImGui.SameLine()
        if ImGui.SmallButton("Save to memory") then ImGui.SaveIniSettingsToMemory() end
        ImGui.SameLine()
        ImGui.TextUnformatted(io.IniFilename and ("\"" .. io.IniFilename .. "\"") or "<NULL>")
        ImGui.Text("SettingsDirtyTimer %.2f", g.SettingsDirtyTimer)
        if ImGui.TreeNode("SettingsHandlers", "Settings handlers: (%d)", g.SettingsHandlers.Size) then
            for _, handler in g.SettingsHandlers:iter() do ImGui.BulletText("\"%s\"", handler.TypeName) end
            ImGui.TreePop()
        end
        if ImGui.TreeNode("SettingsWindows", "Settings packed data: Windows: %d entries", g.SettingsWindows.Size) then
            for _, settings in g.SettingsWindows:iter() do ImGui.DebugNodeWindowSettings(settings) end
            ImGui.TreePop()
        end
        if ImGui.TreeNode("SettingsTables", "Settings packed data: Tables: %d entries", g.SettingsTables.Size) then
            for _, settings in g.SettingsTables:iter() do ImGui.DebugNodeTableSettings(settings, nil) end
            ImGui.TreePop()
        end
        if ImGui.TreeNode("SettingsDocking", "Settings packed data: Docking") then
            local dc = g.DockContext
            ImGui.Text("In SettingsWindows:")
            for _, settings in g.SettingsWindows:iter() do
                if (settings.DockId or 0) ~= 0 then ImGui.BulletText("Window '%s' -> DockId %08X DockOrder=%d", settings.Name or "", settings.DockId, settings.DockOrder or -1) end
            end
            ImGui.Text("In SettingsNodes:")
            for _, settings in dc.NodesSettings:iter() do
                local selected_tab_name = nil
                if (settings.SelectedTabId or 0) ~= 0 then
                    local window = ImGui.FindWindowByID(settings.SelectedTabId)
                    selected_tab_name = window and window.Name or nil
                end
                ImGui.BulletText("Node %08X, Parent %08X, SelectedTab %08X ('%s')", settings.ID, settings.ParentNodeId or 0, settings.SelectedTabId or 0, selected_tab_name or ((settings.SelectedTabId or 0) ~= 0 and "N/A" or ""))
            end
            ImGui.TreePop()
        end
        local ini = g.SettingsIniData or ""
        if ImGui.TreeNode("SettingsIniData", "Settings unpacked data (.ini): %d bytes", #ini) then
            ImGui.InputTextMultiline("##Ini", DemoBuf(ini, #ini + 1), #ini + 1, ImVec2(-FLT_MIN, ImGui.GetTextLineHeight() * 20), ImGuiInputTextFlags.ReadOnly)
            ImGui.TreePop()
        end
        ImGui.TreePop()
    end

    -- Inputs
    if ImGui.TreeNode("Inputs") then
        ImGui.Text("KEYBOARD/GAMEPAD/MOUSE KEYS")
        ImGui.Indent()
        ImGui.Text("Keys down:")
        for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
            if ImGui.IsKeyDown(key) then ImGui.SameLine(); ImGui.Text("\"%s\"", ImGui.GetKeyName(key)) end
        end
        ImGui.Text("Keys pressed:")
        for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
            if ImGui.IsKeyPressed(key) then ImGui.SameLine(); ImGui.Text("\"%s\"", ImGui.GetKeyName(key)) end
        end
        ImGui.Text("Keys released:")
        for key = ImGuiKey.NamedKey_BEGIN, ImGuiKey.NamedKey_END - 1 do
            if ImGui.IsKeyReleased(key) then ImGui.SameLine(); ImGui.Text("\"%s\"", ImGui.GetKeyName(key)) end
        end
        ImGui.Text("Keys mods: %s%s%s%s", io.KeyCtrl and "Ctrl " or "", io.KeyShift and "Shift " or "", io.KeyAlt and "Alt " or "", io.KeySuper and "Super " or "")
        ImGui.Unindent()
        ImGui.Text("MOUSE STATE")
        ImGui.Indent()
        if ImGui.IsMousePosValid() then ImGui.Text("Mouse pos: (%g, %g)", io.MousePos.x, io.MousePos.y) else ImGui.Text("Mouse pos: <INVALID>") end
        ImGui.Text("Mouse delta: (%g, %g)", io.MouseDelta.x, io.MouseDelta.y)
        ImGui.Text("Mouse down:")
        for i = 0, 2 do if ImGui.IsMouseDown(i) then ImGui.SameLine(); ImGui.Text("b%d (%.02f secs)", i, io.MouseDownDuration[i]) end end
        ImGui.Text("Mouse clicked:")
        for i = 0, 2 do if ImGui.IsMouseClicked(i) then ImGui.SameLine(); ImGui.Text("b%d (%d)", i, io.MouseClickedCount[i]) end end
        ImGui.Text("Mouse released:")
        for i = 0, 2 do if ImGui.IsMouseReleased(i) then ImGui.SameLine(); ImGui.Text("b%d", i) end end
        ImGui.Text("Mouse wheel: %.1f", io.MouseWheel)
        ImGui.Text("MouseStationaryTimer: %.2f", g.MouseStationaryTimer)
        ImGui.Unindent()
        ImGui.Text("MOUSE WHEELING")
        ImGui.Indent()
        ImGui.Text("WheelingWindow: '%s'", g.WheelingWindow and g.WheelingWindow.Name or "NULL")
        ImGui.Text("WheelingWindowReleaseTimer: %.2f", g.WheelingWindowReleaseTimer or 0)
        ImGui.Text("WheelingAxisAvg[] = { %.3f, %.3f }", g.WheelingAxisAvg.x, g.WheelingAxisAvg.y)
        ImGui.Unindent()
        ImGui.TreePop()
    end

    -- Internal state
    if ImGui.TreeNode("Internal state") then
        local function N(w) return w and w.Name or "NULL" end
        ImGui.Text("WINDOWING")
        ImGui.Indent()
        ImGui.Text("HoveredWindow: '%s'", N(g.HoveredWindow))
        ImGui.Text("HoveredWindow->Root: '%s'", g.HoveredWindow and N(g.HoveredWindow.RootWindowDockTree) or "NULL")
        ImGui.Text("HoveredWindowUnderMovingWindow: '%s'", N(g.HoveredWindowUnderMovingWindow))
        ImGui.Text("HoveredDockNode: 0x%08X", g.DebugHoveredDockNode and g.DebugHoveredDockNode.ID or 0)
        ImGui.Text("MovingWindow: '%s'", N(g.MovingWindow))
        ImGui.Unindent()
        ImGui.Text("ITEMS")
        ImGui.Indent()
        ImGui.Text("ActiveId: 0x%08X/0x%08X (%.2f sec), AllowOverlap: %d", g.ActiveId, g.ActiveIdPreviousFrame, g.ActiveIdTimer, B(g.ActiveIdAllowOverlap))
        ImGui.Text("ActiveIdWindow: '%s'", N(g.ActiveIdWindow))
        ImGui.Text("HoveredId: 0x%08X (%.2f sec), AllowOverlap: %d", g.HoveredIdPreviousFrame, g.HoveredIdTimer, B(g.HoveredIdAllowOverlap))
        ImGui.Text("HoverItemDelayId: 0x%08X, Timer: %.2f, ClearTimer: %.2f", g.HoverItemDelayId or 0, g.HoverItemDelayTimer or 0, g.HoverItemDelayClearTimer or 0)
        ImGui.Text("DragDrop: %d, SourceId = 0x%08X, Payload \"%s\"", B(g.DragDropActive), g.DragDropPayload.SourceId or 0, tostring(g.DragDropPayload.DataType or ""))
        ImGui.Unindent()
        ImGui.Text("NAV,FOCUS")
        ImGui.Indent()
        ImGui.Text("NavWindow: '%s'", N(g.NavWindow))
        ImGui.Text("NavId: 0x%08X, NavLayer: %d", g.NavId, g.NavLayer)
        ImGui.Text("NavActive: %d, NavVisible: %d", B(io.NavActive), B(io.NavVisible))
        ImGui.Text("NavActivateId/DownId/PressedId: %08X/%08X/%08X", g.NavActivateId, g.NavActivateDownId or 0, g.NavActivatePressedId or 0)
        ImGui.Text("NavActivateFlags: %04X", g.NavActivateFlags or 0)
        ImGui.Text("NavCursorVisible: %d, NavHighlightItemUnderNav: %d", B(g.NavCursorVisible), B(g.NavHighlightItemUnderNav))
        ImGui.Text("NavFocusScopeId = 0x%08X", g.NavFocusScopeId or 0)
        ImGui.Text("NavWindowingTarget: '%s'", N(g.NavWindowingTarget))
        ImGui.Unindent()
        ImGui.TreePop()
    end

    -- Overlays
    if cfg.ShowWindowsRects or cfg.ShowWindowsBeginOrder then
        for _, window in g.Windows:iter() do
            if window.WasActive then
                local draw_list = FG(window)
                if cfg.ShowWindowsRects then
                    local r = GetWindowRect(window, cfg.ShowWindowsRectsType)
                    draw_list:AddRect(r.Min, r.Max, IM_COL32(255, 0, 128, 255))
                end
                if cfg.ShowWindowsBeginOrder and bit32.band(window.Flags, ImGuiWindowFlags.ChildWindow) == 0 then
                    local font_size = ImGui.GetFontSize()
                    draw_list:AddRectFilled(window.Pos, window.Pos + ImVec2(font_size, font_size), IM_COL32(200, 100, 100, 255))
                    draw_list:AddText(window.Pos, IM_COL32(255, 255, 255, 255), tostring(window.BeginOrderWithinContext))
                end
            end
        end
    end
    if cfg.ShowTablesRects then
        ForEachTable(g, function(tbl)
            if tbl.LastFrameActive < g.FrameCount - 1 then return end
            local draw_list = FG(tbl.OuterWindow)
            if cfg.ShowTablesRectsType >= TRT_ColumnsRect then
                for column_n = 0, tbl.ColumnsCount - 1 do
                    local r = GetTableRect(tbl, cfg.ShowTablesRectsType, column_n)
                    local hot = (tbl.HoveredColumnBody == column_n)
                    draw_list:AddRect(r.Min, r.Max, hot and IM_COL32(255, 255, 128, 255) or IM_COL32(255, 0, 128, 255), 0.0, hot and 3.0 or 1.0)
                end
            else
                local r = GetTableRect(tbl, cfg.ShowTablesRectsType, -1)
                draw_list:AddRect(r.Min, r.Max, IM_COL32(255, 0, 128, 255))
            end
        end)
    end

    ImGui.End()
    return p_open
end

return true
