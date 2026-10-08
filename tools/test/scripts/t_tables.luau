-- Tables: basic, borders/rowbg, resizable+reorderable+hideable+sortable headers, scroll freeze + clipper, angled headers, legacy Columns, ini round trip
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local TF, CF = G.ImGuiTableFlags, G.ImGuiTableColumnFlags
local bor = bit32.bor
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()
local frame = 0
local sorted_specs = nil
local visible_rows = 0
local hovered_col = nil
RunService.Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    local io = ImGui.GetIO()
    -- drag the border between column 0 and 1 of "sortable" on frames 10..20
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(700, 900), G.ImGuiCond.Always)
    ImGui.Begin("Tables")

    if ImGui.BeginTable("basic", 3) then
        for row = 0, 3 do
            ImGui.TableNextRow()
            for col = 0, 2 do
                ImGui.TableSetColumnIndex(col)
                ImGui.Text("Row %d Column %d", row, col)
            end
        end
        ImGui.EndTable()
    end

    if ImGui.BeginTable("borders", 3, bor(TF.Borders, TF.RowBg)) then
        for row = 0, 4 do
            ImGui.TableNextRow()
            for col = 0, 2 do
                ImGui.TableNextColumn()
                ImGui.Text("Hello %d,%d", col, row)
                if row == 2 and col == 1 then ImGui.TableSetBgColor(G.ImGuiTableBgTarget.CellBg, G.IM_COL32(255, 0, 0, 255)) end
            end
        end
        ImGui.EndTable()
    end

    if ImGui.BeginTable("sortable", 4, bor(TF.Resizable, TF.Reorderable, TF.Hideable, TF.Sortable, TF.SortMulti, TF.BordersOuter, TF.BordersV)) then
        ImGui.TableSetupColumn("ID", bor(CF.DefaultSort, CF.WidthFixed), 0.0, 0)
        ImGui.TableSetupColumn("Name", CF.WidthFixed, 0.0, 1)
        ImGui.TableSetupColumn("Action", bor(CF.NoSort, CF.WidthFixed), 0.0, 2)
        ImGui.TableSetupColumn("Quantity", bor(CF.PreferSortDescending, CF.WidthStretch), 0.0, 3)
        ImGui.TableHeadersRow()
        local specs = ImGui.TableGetSortSpecs()
        if specs and specs.SpecsDirty then sorted_specs = specs.SpecsCount; specs.SpecsDirty = false end
        for row = 0, 5 do
            ImGui.TableNextRow()
            ImGui.TableNextColumn(); ImGui.Text("%04d", row)
            ImGui.TableNextColumn(); ImGui.TextUnformatted("Item " .. row)
            ImGui.TableNextColumn(); ImGui.SmallButton("None##" .. row)
            ImGui.TableNextColumn(); ImGui.Text("%d", row * 3)
        end
        hovered_col = ImGui.TableGetHoveredColumn()
        ImGui.EndTable()
    end

    if ImGui.BeginTable("scroll", 3, bor(TF.ScrollY, TF.ScrollX, TF.RowBg, TF.BordersOuter, TF.BordersV, TF.Resizable, TF.SizingFixedFit), ImVec2(0, 200)) then
        ImGui.TableSetupScrollFreeze(1, 1)
        ImGui.TableSetupColumn("One", CF.None, 100)
        ImGui.TableSetupColumn("Two", CF.None, 200)
        ImGui.TableSetupColumn("Three", CF.None, 300)
        ImGui.TableHeadersRow()
        local clipper = G.ImGuiListClipper()
        clipper:Begin(1000)
        visible_rows = 0
        while clipper:Step() do
            for row = clipper.DisplayStart, clipper.DisplayEnd - 1 do
                visible_rows += 1
                ImGui.TableNextRow()
                for column = 0, 2 do
                    ImGui.TableSetColumnIndex(column)
                    ImGui.Text("Hello %d,%d", column, row)
                end
            end
        end
        if frame == 4 then ImGui.SetScrollY(500) end
        ImGui.EndTable()
    end

    if ImGui.BeginTable("angled", 4, bor(TF.Borders, TF.SizingFixedFit, TF.ScrollX), ImVec2(0, 150)) then
        ImGui.TableSetupColumn("Name", CF.NoHide)
        for i = 1, 3 do ImGui.TableSetupColumn("Angled " .. i, bor(CF.AngledHeader, CF.WidthFixed)) end
        ImGui.TableAngledHeadersRow()
        ImGui.TableHeadersRow()
        for row = 0, 3 do
            ImGui.TableNextRow()
            ImGui.TableNextColumn(); ImGui.Text("Track %d", row)
            for i = 1, 3 do ImGui.TableNextColumn(); ImGui.Checkbox("##c" .. row .. i, false) end
        end
        ImGui.EndTable()
    end

    -- nested + tree in table
    if ImGui.BeginTable("tree", 2, bor(TF.BordersV, TF.Resizable, TF.RowBg)) then
        ImGui.TableSetupColumn("Name", CF.NoHide)
        ImGui.TableSetupColumn("Size", CF.WidthFixed, 80)
        ImGui.TableHeadersRow()
        ImGui.TableNextRow(); ImGui.TableNextColumn()
        if ImGui.TreeNodeEx("Root", bor(G.ImGuiTreeNodeFlags.SpanAllColumns, G.ImGuiTreeNodeFlags.DefaultOpen)) then
            ImGui.TableNextColumn(); ImGui.TextDisabled("--")
            ImGui.TableNextRow(); ImGui.TableNextColumn()
            ImGui.TreeNodeEx("Leaf", bor(G.ImGuiTreeNodeFlags.Leaf, G.ImGuiTreeNodeFlags.NoTreePushOnOpen, G.ImGuiTreeNodeFlags.SpanAllColumns))
            ImGui.TableNextColumn(); ImGui.Text("123")
            ImGui.TreePop()
        end
        ImGui.EndTable()
    end

    ImGui.Columns(3, "legacy")
    for i = 0, 5 do ImGui.Text("col item %d", i); ImGui.NextColumn() end
    ImGui.Columns(1)

    ImGui.End()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())

    if frame == 8 then
        assert(sorted_specs == 1, "sort specs " .. tostring(sorted_specs))
        assert(visible_rows > 3 and visible_rows < 30, "clipped rows " .. visible_rows)
        local ini = ImGui.SaveIniSettingsToMemory()
        assert(string.find(ini, "[Table][", 1, true), "table ini missing")
        print(ini)
        ImGui.LoadIniSettingsFromMemory(ini)
        assert(ImGui.SaveIniSettingsToMemory() == ini, "ini round trip")
        print("visible rows", visible_rows, "TABLES OK")
    end
end)
