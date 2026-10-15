-- Small upstream helpers: ImGuiInputTextState selection API + ReloadUserBuf*, ImGuiInputTextCallbackData:SetSelection, ImDrawList AddImageQuad/PrimQuadUV/
-- CloneOutput, ImDrawData DeIndexAllBuffers/ScaleClipRects, ImBitVector/ImBitArray*, ImGuiPackedDate, ImParseFormatSanitizeForPrinting, drag cancel (ShortcutsForCancel)
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext(); G.ImGui_ImplRoblox.Init()
local io = ImGui.GetIO()
local failed = {}
local function check(ok, msg) if not ok then table.insert(failed, msg); print("FAIL " .. msg) end end

-- Pure helpers
check(G.ImParseFormatSanitizeForPrinting("%.3f%%", nil, 32) == "%.3f", "sanitize %.3f%%")
check(G.ImParseFormatSanitizeForPrinting("%'_5.2f units", nil, 32) == "%5.2f", "sanitize stb flags: " .. G.ImParseFormatSanitizeForPrinting("%'_5.2f units", nil, 32))
local d = G.ImGuiPackedDate(20260315)
check(d:IsValid() and d:Unpack() == 20260315, "PackedDate round trip " .. d:Unpack())
d:SubtractMonths(3)
check(d:Unpack() == 20251215, "PackedDate SubtractMonths " .. d:Unpack())
check(not G.ImGuiPackedDate():IsValid() and G.ImGuiPackedDate():Unpack() == 0, "PackedDate empty")
local bv = G.ImBitVector()
bv:Create(70)
check(bv.Storage.Size == 3, "ImBitVector size")
bv:SetBit(1); bv:SetBit(70); bv:SetBit(33)
check(bv:TestBit(1) and bv:TestBit(70) and bv:TestBit(33) and not bv:TestBit(2) and not bv:TestBit(69), "ImBitVector SetBit/TestBit")
bv:ClearBit(33)
check(not bv:TestBit(33) and bv:TestBit(70), "ImBitVector ClearBit")
local arr = {}
G.ImBitArrayClearAllBits(arr, 96)
G.ImBitArraySetBitRange(arr, 3, 70) -- [3..70)
local ok_range = true
for n = 1, 96 do if G.ImBitArrayTestBit(arr, n) ~= (n >= 3 and n < 70) then ok_range = false end end
check(ok_range, "ImBitArraySetBitRange")
check(G.ImBitArrayGetStorageSizeInBytes(70) == 12, "ImBitArrayGetStorageSizeInBytes")
check(G.ImModPositive(-1, 5) == 4 and G.ImRoundSigned64(-1.5) == -2 and G.ImCharIsXdigitA(string.byte("F")), "math helpers")

local buf = ImGui.NewTextBuffer("hello world", 64)
local cbuf = ImGui.NewTextBuffer("abcdef", 64)
local cb_calls = 0
local function cb(data)
    cb_calls += 1
    if cb_calls == 1 then data:SetSelection(1, 3) end
    return 0
end
local df, rect_df = 10.0, nil
local f = 0
local function center(r) return (r[1].x + r[2].x) / 2, (r[1].y + r[2].y) / 2 end

local function vtx(dl, i) -- 1-based vertex
    local b, o = dl.VtxBuffer.Buf, (i - 1) * G.VTX_STRIDE
    return buffer.readf64(b, o), buffer.readf64(b, o + 8), buffer.readf64(b, o + 16), buffer.readf64(b, o + 24), buffer.readu32(b, o + 32)
end

game:GetService("RunService").Stepped:Connect(function()
    f += 1
    G.ImGui_ImplRoblox.NewFrame()
    -- drag + Escape cancels and reverts (ShortcutsForCancel)
    if f == 20 then io:AddMousePosEvent(center(rect_df)) end
    if f == 21 then io:AddMouseButtonEvent(0, true) end
    if f == 22 then local x, y = center(rect_df); io:AddMousePosEvent(x + 40, y) end
    if f == 24 then io:AddKeyEvent(G.ImGuiKey.Escape, true) end
    if f == 25 then io:AddKeyEvent(G.ImGuiKey.Escape, false) end
    if f == 26 then io:AddMouseButtonEvent(0, false) end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10)); ImGui.SetNextWindowSize(ImVec2(400, 300))
    ImGui.Begin("H")
    if f == 2 then ImGui.SetKeyboardFocusHere() end
    ImGui.InputText("##t", buf, 64)
    local id = ImGui.GetItemID()
    local st = ImGui.GetInputTextState(id)
    if f == 5 then
        check(st ~= nil, "InputText active")
        if st then
            st:SetSelection(3, 6)
            check(st:GetSelectionStart() == 3 and st:GetSelectionEnd() == 6 and st:GetCursorPos() == 6 and st:HasSelection(), "SetSelection/Get*")
            st:ClearSelection()
            check(st:GetSelectionStart() == 6 and st:GetSelectionEnd() == 6 and not st:HasSelection(), "ClearSelection")
            check(st:GetPreferredOffsetX() == -1, "GetPreferredOffsetX")
            -- modify the user buffer externally then reload
            local s = "bye"; for i = 1, #s do buf[i] = string.byte(s, i) end; buf[#s + 1] = 0
            st:ReloadUserBufAndSelectAll()
        end
    end
    if f == 7 and st then
        check(G.ImGui._ByteArrayToString(st:GetText(), 1, st.TextLen + 1) == "bye", "ReloadUserBufAndSelectAll text")
        check(st:GetSelectionStart() == 1 and st:GetSelectionEnd() == 4, ("ReloadUserBufAndSelectAll sel %d..%d"):format(st:GetSelectionStart(), st:GetSelectionEnd()))
        st:SetSelection(2, 3); st:ReloadUserBufAndKeepSelection()
    end
    if f == 9 and st then
        check(st:GetSelectionStart() == 2 and st:GetSelectionEnd() == 3, "ReloadUserBufAndKeepSelection")
        st:ReloadUserBufAndMoveToEnd()
    end
    if f == 11 and st then
        check(st:GetCursorPos() == 4 and not st:HasSelection(), "ReloadUserBufAndMoveToEnd " .. st:GetCursorPos())
    end
    -- callback SetSelection (0-based callback positions -> 1-based stb)
    if f == 12 then ImGui.SetKeyboardFocusHere() end
    ImGui.InputText("##c", cbuf, 64, G.ImGuiInputTextFlags.CallbackAlways, cb)
    if f == 15 then
        local cst = ImGui.GetInputTextState(ImGui.GetItemID())
        check(cst ~= nil and cb_calls > 0 and cst:GetSelectionStart() == 2 and cst:GetSelectionEnd() == 4, "callback SetSelection " .. (cst and (cst:GetSelectionStart() .. ".." .. cst:GetSelectionEnd()) or "nil"))
    end
    df = ImGui.DragFloat("##df", df, 1.0)
    local a, b = ImGui.GetItemRectMin(), ImGui.GetItemRectMax(); rect_df = { ImVec2(a.x, a.y), ImVec2(b.x, b.y) }
    if f == 23 then check(df ~= 10.0, "drag changed value " .. df) end
    if f == 25 then check(df == 10.0 and ImGui.GetActiveID() == 0, "Escape reverts drag " .. df) end

    if f == 30 then
        local dl = ImGui.GetWindowDrawList()
        local v0, i0 = dl.VtxBuffer.Size, dl.IdxBuffer.Size
        local tex = G.ImTextureRef(1234)
        dl:AddImageQuad(tex, ImVec2(10, 10), ImVec2(50, 12), ImVec2(48, 60), ImVec2(8, 58), ImVec2(0, 0), ImVec2(1, 0), ImVec2(1, 1), ImVec2(0, 1), 0xFF00FF00)
        check(dl.VtxBuffer.Size == v0 + 4 and dl.IdxBuffer.Size == i0 + 6, "AddImageQuad counts")
        local x, y, u, v, col = vtx(dl, v0 + 3)
        check(x == 48 and y == 60 and u == 1 and v == 1 and col == 0xFF00FF00, ("PrimQuadUV vertex %s %s %s %s %x"):format(x, y, u, v, col))
        local idx = dl.IdxBuffer.Data
        check(idx[i0 + 1] == v0 + 1 and idx[i0 + 5] == v0 + 3 and idx[i0 + 6] == v0 + 4, "PrimQuadUV indices")
        local cmin, cmax = dl:GetClipRectMin(), dl:GetClipRectMax()
        check(cmax.x > cmin.x and cmax.y > cmin.y, "GetClipRectMin/Max")

        local clone = dl:CloneOutput()
        check(clone.VtxBuffer.Size == dl.VtxBuffer.Size and clone.IdxBuffer.Size == dl.IdxBuffer.Size and clone.CmdBuffer.Size == dl.CmdBuffer.Size
            and clone.VtxBuffer.Buf ~= dl.VtxBuffer.Buf and clone.CmdBuffer.Data[1] ~= dl.CmdBuffer.Data[1], "CloneOutput copies buffers")
        local cx = vtx(clone, v0 + 3)
        check(cx == 48, "CloneOutput vertex data")

        local dd = G.ImDrawData()
        dd.CmdLists:push_back(clone)
        local n_idx = clone.IdxBuffer.Size
        local ex, ey = vtx(clone, clone.IdxBuffer.Data[n_idx])
        dd:DeIndexAllBuffers()
        check(clone.IdxBuffer.Size == 0 and clone.VtxBuffer.Size == n_idx and dd.TotalVtxCount == n_idx and dd.TotalIdxCount == 0, "DeIndexAllBuffers counts")
        local lx, ly = vtx(clone, n_idx)
        check(lx == ex and ly == ey, "DeIndexAllBuffers vertex data")

        local cr = clone.CmdBuffer.Data[1].ClipRect
        local x1, y1, z1, w1 = cr.x, cr.y, cr.z, cr.w
        dd:ScaleClipRects(ImVec2(2, 3))
        local cr2 = clone.CmdBuffer.Data[1].ClipRect
        check(cr2.x == x1 * 2 and cr2.y == y1 * 3 and cr2.z == z1 * 2 and cr2.w == w1 * 3 and dl.CmdBuffer.Data[1].ClipRect.z == z1, "ScaleClipRects")
    end

    if f == 31 then
        local g = ImGui.GetCurrentContext()
        local style = ImGui.GetStyle()
        local window = ImGui.GetCurrentWindow()
        check(G.ImGuiKey["0"] == G.ImGuiKey.K0 and G.ImGuiKey["9"] == G.ImGuiKey.K9, "ImGuiKey digit aliases")

        -- Style vars (enum values must match GStyleVarsInfo order)
        local sv = G.ImGuiStyleVar
        local b1, b2, b3 = style.SeparatorSize, style.SeparatorTextBorderSize, style.DockingSeparatorSize
        ImGui.PushStyleVar(sv.SeparatorSize, 5); ImGui.PushStyleVar(sv.SeparatorTextBorderSize, 6); ImGui.PushStyleVar(sv.DockingSeparatorSize, 7)
        check(style.SeparatorSize == 5 and style.SeparatorTextBorderSize == 6 and style.DockingSeparatorSize == 7, "PushStyleVar SeparatorSize/SeparatorTextBorderSize/DockingSeparatorSize")
        ImGui.PushStyleVar(sv.SeparatorTextPadding, ImVec2(3, 4))
        check(style.SeparatorTextPadding.x == 3 and style.SeparatorTextPadding.y == 4, "PushStyleVar SeparatorTextPadding")
        ImGui.PopStyleVar(4)
        check(style.SeparatorSize == b1 and style.SeparatorTextBorderSize == b2 and style.DockingSeparatorSize == b3, "PopStyleVar restores")

        -- Log flags
        ImGui.LogToBuffer()
        check(g.LogEnabled and g.LogFlags == G.ImGuiLogFlags.OutputBuffer, "LogToBuffer sets ImGuiLogFlags.OutputBuffer")
        ImGui.Text("logged")
        check(string.find(g.LogBuffer:c_str(), "logged", 1, true) ~= nil, "LogToBuffer captures text")
        ImGui.LogFinish()
        check(g.LogFlags == G.ImGuiLogFlags.None and not g.LogEnabled, "LogFinish clears LogFlags")

        -- Combo preview (no ImGuiComboFlags.CustomPreview needed since 1.93)
        if ImGui.BeginCombo("##cb", "") then ImGui.EndCombo() end
        local pd = g.ComboPreviewData
        local work_max_x, content_max_x = window.WorkRect.Max.x, window.ContentRegionRect.Max.x
        local opened = ImGui.BeginComboPreview()
        check(opened and pd.WithinPreview and window.WorkRect.Max.x == pd.PreviewRect.Max.x - style.FramePadding.x and window.ContentRegionRect.Max.x == window.WorkRect.Max.x, "BeginComboPreview sets WorkRect")
        if opened then
            ImGui.Text("preview")
            ImGui.EndComboPreview()
        end
        check(not pd.WithinPreview and window.WorkRect.Max.x == work_max_x and window.ContentRegionRect.Max.x == content_max_x, "EndComboPreview restores WorkRect")
        if ImGui.BeginCombo("##cb2", "x", G.ImGuiComboFlags.NoPreview) then ImGui.EndCombo() end
        check(not ImGui.BeginComboPreview(), "BeginComboPreview with NoPreview returns false")

        -- ListClipper in a table: ImGuiListClipperFlags.NoSetTableRowCounters
        local rows = {}
        ImGui.SetNextWindowPos(ImVec2(500, 10)); ImGui.SetNextWindowSize(ImVec2(300, 400))
        ImGui.Begin("Clip")
        for pass = 1, 2 do
            if ImGui.BeginTable("##clip" .. pass, 1, G.ImGuiTableFlags.ScrollY, ImVec2(0, 60)) then
                local clipper = G.ImGuiListClipper()
                if pass == 2 then clipper.Flags = G.ImGuiListClipperFlags.NoSetTableRowCounters end
                clipper:Begin(1000)
                while clipper:Step() do
                    for i = clipper.DisplayStart, clipper.DisplayEnd - 1 do ImGui.TableNextRow(); ImGui.TableNextColumn(); ImGui.Text("%d", i) end
                end
                clipper:End()
                rows[pass] = ImGui.GetCurrentTable().CurrentRow
                local tbl = ImGui.GetCurrentTable()
                ImGui.EndTable()
                if pass == 1 then ImGui.SetNextItemOpen(true); ImGui.DebugNodeTable(tbl) end -- DebugNodeTableGetSizingPolicyDesc()
            end
        end
        ImGui.End()
        check(rows[1] ~= nil and rows[2] ~= nil and rows[1] >= 990 and rows[2] < 100, ("clipper row counters %s / NoSetTableRowCounters %s"):format(tostring(rows[1]), tostring(rows[2])))

        -- .ini LastUsed dates + CleanupIniSettings()
        local pio = ImGui.GetPlatformIO()
        pio.Platform_SessionDate = 20261015
        g.SessionDate = G.ImGuiPackedDate(pio.Platform_SessionDate) -- (normally done by NewFrame())
        io.ConfigIniSettingsAutoDiscardMonths = 6
        ImGui.LoadIniSettingsFromMemory("[Window][Old]\nPos=1,1\nLastUsed=20250101\n\n[Window][NoDate]\nPos=2,2\n\n[Window][Recent]\nPos=3,3\nLastUsed=20260901\n\n")
        io.ConfigIniSettingsAutoDiscardMonths = 0
        local function ws(name) for _, st in g.SettingsWindows.Data do if st.Name == name then return st end end; return nil end
        check(ws("Old").WantDelete and ws("NoDate").WantDelete and not ws("Recent").WantDelete and ws("Recent").LastUsedDate == 20260901, "ConfigIniSettingsAutoDiscardMonths discards old/undated entries")
        local args = G.ImGuiSettingsCleanupArgs()
        args.SetCurrentSessionDateToAll = true
        args.TypeHashFilter = G.ImHashStr("Window")
        ImGui.CleanupIniSettings(args)
        check(ws("Recent").LastUsedDate == 20261015, "CleanupIniSettings SetCurrentSessionDateToAll")
        local ini = ImGui.SaveIniSettingsToMemory()
        check(not string.find(ini, "[Window][Old]", 1, true) and string.find(ini, "[Window][Recent]\nPos=3,3\nCollapsed=0\nLastUsed=20261015\n", 1, true) ~= nil
            and string.find(ini, "[Window][H]\nPos=10,10\nSize=400,300\nCollapsed=0\nLastUsed=20261015\n", 1, true) ~= nil, "LastUsed written to .ini:\n" .. ini)
        io.ConfigIniSettingsSaveLastUsedDate = false
        check(not string.find(ImGui.SaveIniSettingsToMemory(), "LastUsed", 1, true), "ConfigIniSettingsSaveLastUsedDate = false")
        io.ConfigIniSettingsSaveLastUsedDate = true
        pio.Platform_SessionDate = 0
    end
    ImGui.End()
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if f == 32 and #failed == 0 then print("HELPERS OK") end
end)
