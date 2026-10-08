--- ImGui Sincerely
-- Tab bars & tab items: 1:1 port of imgui_widgets.cpp [SECTION] Widgets: BeginTabBar/BeginTabItem (docking branch)
--
-- Port notes:
-- - tab_bar.Tabs is an ImVector of ImGuiTabItem tables (references). C++ pointer arithmetic on the array is replaced by
--   index lookups. tab_bar.LastTabItemIdx and tab orders are 0-based like upstream.
-- - Tab names are stored on the tab itself (tab.Name) instead of tab_bar.TabsNames.
-- - ImGui.BeginTabItem(label, p_open, flags) returns `visible, p_open`.

local MT = ImGui.GetMetatables()

local GImGui
local function SyncContext() GImGui = ImGui.GetCurrentContext() end

local function ImLinearSweep(current, target, speed)
    if current < target then return ImMin(current + speed, target) end
    if current > target then return ImMax(current - speed, target) end
    return current
end

local function TabItemGetSectionIdx(tab)
    if bit32.band(tab.Flags, ImGuiTabItemFlags.Leading) ~= 0 then return 0 end
    if bit32.band(tab.Flags, ImGuiTabItemFlags.Trailing) ~= 0 then return 2 end
    return 1
end

-- Stable sorts (C++ ImQsort is not stable, but the comparers are total orders in practice)
local function SortTabsBySection(tab_bar)
    table.sort(tab_bar.Tabs.Data, function(a, b)
        if a == nil or b == nil then return false end
        local sa, sb = TabItemGetSectionIdx(a), TabItemGetSectionIdx(b)
        if sa ~= sb then return sa < sb end
        return a.IndexDuringLayout < b.IndexDuringLayout
    end)
end

local function SortTabsByBeginOrder(tab_bar)
    local data = tab_bar.Tabs.Data
    if not data then return end
    local arr = {}
    for i = 1, tab_bar.Tabs.Size do arr[i] = data[i] end
    table.sort(arr, function(a, b) return a.BeginOrder < b.BeginOrder end)
    for i = 1, tab_bar.Tabs.Size do data[i] = arr[i] end
end

local function TabBarCalcScrollableWidth(tab_bar, sections)
    return tab_bar.BarRect:GetWidth() - sections[1].Width - sections[3].Width - sections[2].Spacing
end

local function ImGuiTabBarSection() return { TabCount = 0, Width = 0.0, WidthAfterShrinkMinWidth = 0.0, Spacing = 0.0 } end

-- items: 1-based array of ImGuiShrinkWidthItem, `first` = 1-based index of first item, `count` items
function ImGui.ShrinkWidths(items, first, count, width_excess, width_min)
    if count <= 0 then return end
    if count == 1 then
        local it = items[first]
        if it.Width >= 0.0 then it.Width = ImMax(it.Width - width_excess, width_min) end
        return
    end
    local slice = {}
    for n = 1, count do slice[n] = items[first + n - 1] end
    table.sort(slice, function(a, b)
        if a.Width ~= b.Width then return a.Width > b.Width end
        return a.Index < b.Index
    end)
    for n = 1, count do items[first + n - 1] = slice[n] end
    local it = slice
    local count_same_width = 1
    while width_excess > 0.001 and count_same_width < count do
        while count_same_width < count and it[1].Width <= it[count_same_width + 1].Width do
            count_same_width = count_same_width + 1
        end
        local max_width_to_remove_per_item = (count_same_width < count and it[count_same_width + 1].Width >= 0.0)
            and (it[1].Width - it[count_same_width + 1].Width) or (it[1].Width - 1.0)
        max_width_to_remove_per_item = ImMin(it[1].Width - width_min, max_width_to_remove_per_item)
        if max_width_to_remove_per_item <= 0.0 then break end
        local base_width_to_remove_per_item = ImMin(width_excess / count_same_width, max_width_to_remove_per_item)
        for item_n = 1, count_same_width do
            local w = ImMin(base_width_to_remove_per_item, it[item_n].Width - width_min)
            it[item_n].Width = it[item_n].Width - w
            width_excess = width_excess - w
        end
    end
    width_excess = 0.0
    for n = 1, count do
        local width_rounded = ImTrunc(it[n].Width)
        width_excess = width_excess + it[n].Width - width_rounded
        it[n].Width = width_rounded
    end
    local guard = 0
    while width_excess > 0.0 and guard < 10000 do
        guard = guard + 1
        local progressed = false
        for n = 1, count do
            if width_excess <= 0.0 then break end
            local width_to_add = ImMin(it[n].InitialWidth - it[n].Width, 1.0)
            if width_to_add > 0 then progressed = true end
            it[n].Width = it[n].Width + width_to_add
            width_excess = width_excess - width_to_add
        end
        if not progressed then break end
    end
end

---------------------------------------------------------------------------------------
-- [SECTION] Widgets: BeginTabBar, EndTabBar, etc.
---------------------------------------------------------------------------------------

function ImGui.TabBarFindByID(id)
    SyncContext()
    return GImGui.TabBars:GetByKey(id)
end

function ImGui.TabBarRemove(tab_bar)
    SyncContext()
    GImGui.TabBars:Remove(tab_bar.ID, tab_bar)
end

function ImGui.BeginTabBar(str_id, flags)
    if flags == nil then flags = 0 end
    SyncContext()
    local g = GImGui
    local window = g.CurrentWindow
    if window.SkipItems then return false end

    local id = window:GetID(str_id)
    local tab_bar = g.TabBars:GetOrAddByKey(id)
    local tab_bar_bb = ImRect(window.DC.CursorPos.x, window.DC.CursorPos.y, window.WorkRect.Max.x, window.DC.CursorPos.y + g.FontSize + g.Style.FramePadding.y * 2)
    tab_bar.ID = id
    tab_bar.SeparatorMinX = tab_bar_bb.Min.x - IM_TRUNC(window.WindowPadding.x * 0.5)
    tab_bar.SeparatorMaxX = tab_bar_bb.Max.x + IM_TRUNC(window.WindowPadding.x * 0.5)
    flags = bit32.bor(flags, ImGuiTabBarFlags.IsFocused)
    return ImGui.BeginTabBarEx(tab_bar, tab_bar_bb, flags)
end

function ImGui.BeginTabBarEx(tab_bar, tab_bar_bb, flags)
    SyncContext()
    local g = GImGui
    local window = g.CurrentWindow
    if window.SkipItems then return false end

    IM_ASSERT(tab_bar.ID ~= 0)
    if bit32.band(flags, ImGuiTabBarFlags.DockNode) == 0 then
        ImGui.PushOverrideID(tab_bar.ID)
    end

    g.CurrentTabBarStack:push_back(tab_bar)
    g.CurrentTabBar = tab_bar
    tab_bar.Window = window

    ImVec2_Copy(tab_bar.BackupCursorPos, window.DC.CursorPos)
    if tab_bar.CurrFrameVisible == g.FrameCount then
        ImVec2_CopyV(window.DC.CursorPos, tab_bar.BarRect.Min.x, tab_bar.BarRect.Max.y + tab_bar.ItemSpacingY)
        tab_bar.BeginCount = tab_bar.BeginCount + 1
        return true
    end

    if bit32.band(flags, ImGuiTabBarFlags.Reorderable) ~= bit32.band(tab_bar.Flags, ImGuiTabBarFlags.Reorderable)
        or (tab_bar.TabsAddedNew and bit32.band(flags, ImGuiTabBarFlags.Reorderable) == 0) then
        if bit32.band(flags, ImGuiTabBarFlags.DockNode) == 0 then
            SortTabsByBeginOrder(tab_bar)
        end
    end
    tab_bar.TabsAddedNew = false

    if bit32.band(flags, ImGuiTabBarFlags.FittingPolicyMask_) == 0 then
        flags = bit32.bor(flags, ImGuiTabBarFlags.FittingPolicyDefault_)
    end

    tab_bar.Flags = flags
    tab_bar.BarRect = ImRect(tab_bar_bb.Min, tab_bar_bb.Max)
    tab_bar.WantLayout = true
    tab_bar.PrevFrameVisible = tab_bar.CurrFrameVisible
    tab_bar.CurrFrameVisible = g.FrameCount
    tab_bar.PrevTabsContentsHeight = tab_bar.CurrTabsContentsHeight
    tab_bar.CurrTabsContentsHeight = 0.0
    tab_bar.ItemSpacingY = g.Style.ItemSpacing.y
    ImVec2_Copy(tab_bar.FramePadding, g.Style.FramePadding)
    tab_bar.TabsActiveCount = 0
    tab_bar.LastTabItemIdx = -1
    tab_bar.BeginCount = 1

    ImVec2_CopyV(window.DC.CursorPos, tab_bar.BarRect.Min.x, tab_bar.BarRect.Max.y + tab_bar.ItemSpacingY)

    local col = ImGui.GetColorU32(bit32.band(flags, ImGuiTabBarFlags.IsFocused) ~= 0 and ImGuiCol.TabSelected or ImGuiCol.TabDimmedSelected)
    if g.Style.TabBarBorderSize > 0.0 then
        local y = tab_bar.BarRect.Max.y
        window.DrawList:AddRectFilled(ImVec2(tab_bar.SeparatorMinX, y - g.Style.TabBarBorderSize), ImVec2(tab_bar.SeparatorMaxX, y), col)
    end
    return true
end

function ImGui.EndTabBar()
    SyncContext()
    local g = GImGui
    local window = g.CurrentWindow
    if window.SkipItems then return end

    local tab_bar = g.CurrentTabBar
    IM_ASSERT(tab_bar ~= nil, "Mismatched BeginTabBar()/EndTabBar()!")

    if tab_bar.WantLayout then ImGui.TabBarLayout(tab_bar) end

    local tab_bar_appearing = (tab_bar.PrevFrameVisible + 1 < g.FrameCount)
    if tab_bar.VisibleTabWasSubmitted or tab_bar.VisibleTabId == 0 or tab_bar_appearing then
        tab_bar.CurrTabsContentsHeight = ImMax(window.DC.CursorPos.y - tab_bar.BarRect.Max.y, tab_bar.CurrTabsContentsHeight)
        window.DC.CursorPos.y = tab_bar.BarRect.Max.y + tab_bar.CurrTabsContentsHeight
    else
        window.DC.CursorPos.y = tab_bar.BarRect.Max.y + tab_bar.PrevTabsContentsHeight
    end
    if tab_bar.BeginCount > 1 then
        ImVec2_Copy(window.DC.CursorPos, tab_bar.BackupCursorPos)
    end

    tab_bar.LastTabItemIdx = -1
    if bit32.band(tab_bar.Flags, ImGuiTabBarFlags.DockNode) == 0 then
        ImGui.PopID()
    end

    g.CurrentTabBarStack:pop_back()
    if g.CurrentTabBarStack.Size == 0 then g.CurrentTabBar = nil else g.CurrentTabBar = g.CurrentTabBarStack.Data[g.CurrentTabBarStack.Size] end
end

function ImGui.TabBarLayout(tab_bar)
    SyncContext()
    local g = GImGui
    tab_bar.WantLayout = false

    local scroll_to_selected_tab = (tab_bar.BarRectPrevWidth > tab_bar.BarRect:GetWidth())
    tab_bar.BarRectPrevWidth = tab_bar.BarRect:GetWidth()

    -- Garbage collect by compacting list
    local tabs = tab_bar.Tabs
    local tab_dst_n = 0
    local need_sort_by_section = false
    local sections = { ImGuiTabBarSection(), ImGuiTabBarSection(), ImGuiTabBarSection() } -- 1-based: [1]=Leading,[2]=Central,[3]=Trailing
    for tab_src_n = 0, tabs.Size - 1 do
        local tab = tabs.Data[tab_src_n + 1]
        if tab.LastFrameVisible < tab_bar.PrevFrameVisible or tab.WantClose then
            if tab_bar.VisibleTabId == tab.ID then tab_bar.VisibleTabId = 0 end
            if tab_bar.SelectedTabId == tab.ID then tab_bar.SelectedTabId = 0 end
            if tab_bar.NextSelectedTabId == tab.ID then tab_bar.NextSelectedTabId = 0 end
        else
            if tab_dst_n ~= tab_src_n then tabs.Data[tab_dst_n + 1] = tab end
            tab.IndexDuringLayout = tab_dst_n

            local curr_tab_section_n = TabItemGetSectionIdx(tab)
            if tab_dst_n > 0 then
                local prev_tab = tabs.Data[tab_dst_n]
                local prev_tab_section_n = TabItemGetSectionIdx(prev_tab)
                if curr_tab_section_n == 0 and prev_tab_section_n ~= 0 then need_sort_by_section = true end
                if prev_tab_section_n == 2 and curr_tab_section_n ~= 2 then need_sort_by_section = true end
            end
            sections[curr_tab_section_n + 1].TabCount = sections[curr_tab_section_n + 1].TabCount + 1
            tab_dst_n = tab_dst_n + 1
        end
    end
    if tabs.Size ~= tab_dst_n then
        for i = tab_dst_n + 1, tabs.Size do tabs.Data[i] = nil end
        tabs.Size = tab_dst_n
    end

    if need_sort_by_section then SortTabsBySection(tab_bar) end

    local tab_spacing = g.Style.ItemInnerSpacing.x
    sections[1].Spacing = (sections[1].TabCount > 0 and (sections[2].TabCount + sections[3].TabCount) > 0) and tab_spacing or 0.0
    sections[2].Spacing = (sections[2].TabCount > 0 and sections[3].TabCount > 0) and tab_spacing or 0.0

    local scroll_to_tab_id = 0
    if tab_bar.NextScrollToTabId ~= 0 then
        scroll_to_tab_id = tab_bar.NextScrollToTabId
        tab_bar.NextScrollToTabId = 0
    end
    if tab_bar.NextSelectedTabId ~= 0 then
        tab_bar.SelectedTabId = tab_bar.NextSelectedTabId
        tab_bar.NextSelectedTabId = 0
        scroll_to_tab_id = tab_bar.SelectedTabId
    end

    if tab_bar.ReorderRequestTabId ~= 0 then
        if ImGui.TabBarProcessReorder(tab_bar) then
            if tab_bar.ReorderRequestTabId == tab_bar.SelectedTabId then
                scroll_to_tab_id = tab_bar.ReorderRequestTabId
            end
        end
        tab_bar.ReorderRequestTabId = 0
    end

    local tab_list_popup_button = bit32.band(tab_bar.Flags, ImGuiTabBarFlags.TabListPopupButton) ~= 0
    if tab_list_popup_button then
        local tab_to_select = ImGui.TabBarTabListPopupButton(tab_bar)
        if tab_to_select then
            tab_bar.SelectedTabId = tab_to_select.ID
            scroll_to_tab_id = tab_to_select.ID
        end
    end

    -- shrink buffer layout: leading, trailing, central (0-based offsets)
    local shrink_buffer_indexes = { 0, sections[1].TabCount + sections[3].TabCount, sections[1].TabCount }
    local swb = g.ShrinkWidthBuffer
    swb:resize(tabs.Size)
    for i = 1, tabs.Size do if swb.Data[i] == nil then swb.Data[i] = ImGuiShrinkWidthItem() end end

    local shrink_min_width = (bit32.band(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyMixed) ~= 0) and g.Style.TabMinWidthShrink or 1.0

    local most_recently_selected_tab = nil
    local curr_section_n = -1
    local found_selected_tab_id = false
    for tab_n = 0, tabs.Size - 1 do
        local tab = tabs.Data[tab_n + 1]
        IM_ASSERT(tab.LastFrameVisible >= tab_bar.PrevFrameVisible)

        if (most_recently_selected_tab == nil or most_recently_selected_tab.LastFrameSelected < tab.LastFrameSelected) and bit32.band(tab.Flags, ImGuiTabItemFlags.Button) == 0 then
            most_recently_selected_tab = tab
        end
        if tab.ID == tab_bar.SelectedTabId then found_selected_tab_id = true end
        if scroll_to_tab_id == 0 and g.NavJustMovedToId == tab.ID then scroll_to_tab_id = tab.ID end

        local tab_name = ImGui.TabBarGetTabName(tab_bar, tab)
        local has_close_button_or_unsaved_marker = bit32.band(tab.Flags, ImGuiTabItemFlags.NoCloseButton) == 0 or bit32.band(tab.Flags, ImGuiTabItemFlags.UnsavedDocument) ~= 0
        tab.ContentWidth = (tab.RequestedWidth >= 0.0) and tab.RequestedWidth or ImGui.TabItemCalcSize(tab_name, has_close_button_or_unsaved_marker).x
        if bit32.band(tab.Flags, ImGuiTabItemFlags.Button) == 0 then
            tab.ContentWidth = ImMax(tab.ContentWidth, g.Style.TabMinWidthBase)
        end

        local section_n = TabItemGetSectionIdx(tab)
        local section = sections[section_n + 1]
        section.Width = section.Width + tab.ContentWidth + ((section_n == curr_section_n) and tab_spacing or 0.0)
        section.WidthAfterShrinkMinWidth = section.WidthAfterShrinkMinWidth + ImMin(tab.ContentWidth, shrink_min_width) + ((section_n == curr_section_n) and tab_spacing or 0.0)
        curr_section_n = section_n

        local item = swb.Data[shrink_buffer_indexes[section_n + 1] + 1]
        shrink_buffer_indexes[section_n + 1] = shrink_buffer_indexes[section_n + 1] + 1
        item.Index = tab_n
        item.Width = tab.ContentWidth
        item.InitialWidth = tab.ContentWidth
        tab.Width = ImMax(tab.ContentWidth, 1.0)
    end

    local width_all_tabs_after_min_width_shrink = 0.0
    tab_bar.WidthAllTabsIdeal = 0.0
    for section_n = 1, 3 do
        tab_bar.WidthAllTabsIdeal = tab_bar.WidthAllTabsIdeal + sections[section_n].Width + sections[section_n].Spacing
        width_all_tabs_after_min_width_shrink = width_all_tabs_after_min_width_shrink + sections[section_n].WidthAfterShrinkMinWidth + sections[section_n].Spacing
    end

    local can_scroll = bit32.band(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyScroll) ~= 0 or bit32.band(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyMixed) ~= 0
    local width_all_tabs_to_use_for_scroll = (bit32.band(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyScroll) ~= 0) and tab_bar.WidthAllTabs or width_all_tabs_after_min_width_shrink
    tab_bar.ScrollButtonEnabled = (width_all_tabs_to_use_for_scroll > tab_bar.BarRect:GetWidth() and tabs.Size > 1)
        and bit32.band(tab_bar.Flags, ImGuiTabBarFlags.NoTabListScrollingButtons) == 0 and can_scroll
    if tab_bar.ScrollButtonEnabled then
        local scroll_and_select_tab = ImGui.TabBarScrollingButtons(tab_bar)
        if scroll_and_select_tab then
            if bit32.band(scroll_and_select_tab.Flags, ImGuiTabItemFlags.Button) == 0 then
                tab_bar.SelectedTabId = scroll_and_select_tab.ID
            end
            scroll_to_tab_id = scroll_and_select_tab.ID
        end
    end
    if scroll_to_tab_id == 0 and scroll_to_selected_tab then
        scroll_to_tab_id = tab_bar.SelectedTabId
    end

    local section_0_w = sections[1].Width + sections[1].Spacing
    local section_1_w = sections[2].Width + sections[2].Spacing
    local section_2_w = sections[3].Width + sections[3].Spacing
    local central_section_is_visible = (section_0_w + section_2_w) < tab_bar.BarRect:GetWidth()
    local width_excess
    if central_section_is_visible then
        width_excess = ImMax(section_1_w - (tab_bar.BarRect:GetWidth() - section_0_w - section_2_w), 0.0)
    else
        width_excess = (section_0_w + section_2_w) - tab_bar.BarRect:GetWidth()
    end

    local can_shrink = bit32.band(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyShrink) ~= 0 or bit32.band(tab_bar.Flags, ImGuiTabBarFlags.FittingPolicyMixed) ~= 0
    if width_excess >= 1.0 and (can_shrink or not central_section_is_visible) then
        local shrink_data_count = central_section_is_visible and sections[2].TabCount or (sections[1].TabCount + sections[3].TabCount)
        local shrink_data_offset = central_section_is_visible and (sections[1].TabCount + sections[3].TabCount) or 0
        ImGui.ShrinkWidths(swb.Data, shrink_data_offset + 1, shrink_data_count, width_excess, shrink_min_width)

        for tab_n = shrink_data_offset, shrink_data_offset + shrink_data_count - 1 do
            local item = swb.Data[tab_n + 1]
            local tab = tabs.Data[item.Index + 1]
            local shrinked_width = IM_TRUNC(item.Width)
            if shrinked_width >= 0.0 then
                shrinked_width = ImMax(1.0, shrinked_width)
                local section_n = TabItemGetSectionIdx(tab)
                sections[section_n + 1].Width = sections[section_n + 1].Width - (tab.Width - shrinked_width)
                tab.Width = shrinked_width
            end
        end
    end

    -- Layout all active tabs
    local section_tab_index = 0
    local tab_offset = 0.0
    tab_bar.WidthAllTabs = 0.0
    for section_n = 0, 2 do
        local section = sections[section_n + 1]
        if section_n == 2 then
            tab_offset = ImMin(ImMax(0.0, tab_bar.BarRect:GetWidth() - section.Width), tab_offset)
        end
        for tab_n = 0, section.TabCount - 1 do
            local tab = tabs.Data[section_tab_index + tab_n + 1]
            tab.Offset = tab_offset
            tab.NameOffset = -1
            tab_offset = tab_offset + tab.Width + ((tab_n < section.TabCount - 1) and g.Style.ItemInnerSpacing.x or 0.0)
        end
        tab_bar.WidthAllTabs = tab_bar.WidthAllTabs + ImMax(section.Width + section.Spacing, 0.0)
        tab_offset = tab_offset + section.Spacing
        section_tab_index = section_tab_index + section.TabCount
    end

    local tab_bar_appearing = (tab_bar.PrevFrameVisible + 1 < g.FrameCount)
    if found_selected_tab_id == false and not tab_bar_appearing then
        tab_bar.SelectedTabId = 0
    end
    if tab_bar.SelectedTabId == 0 and tab_bar.NextSelectedTabId == 0 and most_recently_selected_tab ~= nil then
        tab_bar.SelectedTabId = most_recently_selected_tab.ID
        scroll_to_tab_id = tab_bar.SelectedTabId
    end

    tab_bar.VisibleTabId = tab_bar.SelectedTabId
    tab_bar.VisibleTabWasSubmitted = false

    -- CTRL+TAB can override visible tab temporarily
    if g.NavWindowingTarget ~= nil and g.NavWindowingTarget.DockNode and g.NavWindowingTarget.DockNode.TabBar == tab_bar then
        tab_bar.VisibleTabId = g.NavWindowingTarget.TabId
        scroll_to_tab_id = tab_bar.VisibleTabId
    end

    if scroll_to_tab_id ~= 0 then
        ImGui.TabBarScrollToTab(tab_bar, scroll_to_tab_id, sections)
    elseif tab_bar.ScrollButtonEnabled and ImGui.IsMouseHoveringRect(tab_bar.BarRect.Min, tab_bar.BarRect.Max, true) and ImGui.IsWindowContentHoverable(g.CurrentWindow) then
        local wheel = g.IO.MouseWheelRequestAxisSwap and g.IO.MouseWheel or g.IO.MouseWheelH
        local wheel_key = g.IO.MouseWheelRequestAxisSwap and ImGuiKey.MouseWheelY or ImGuiKey.MouseWheelX
        if ImGui.TestKeyOwner(wheel_key, tab_bar.ID) and wheel ~= 0.0 then
            local scroll_step = wheel * TabBarCalcScrollableWidth(tab_bar, sections) / 3.0
            tab_bar.ScrollingTargetDistToVisibility = 0.0
            tab_bar.ScrollingTarget = ImGui.TabBarScrollClamp(tab_bar, tab_bar.ScrollingTarget - scroll_step)
        end
        ImGui.SetKeyOwner(wheel_key, tab_bar.ID)
    end

    tab_bar.ScrollingAnim = ImGui.TabBarScrollClamp(tab_bar, tab_bar.ScrollingAnim)
    tab_bar.ScrollingTarget = ImGui.TabBarScrollClamp(tab_bar, tab_bar.ScrollingTarget)
    if tab_bar.ScrollingAnim ~= tab_bar.ScrollingTarget then
        tab_bar.ScrollingSpeed = ImMax(tab_bar.ScrollingSpeed, 70.0 * g.FontSize)
        tab_bar.ScrollingSpeed = ImMax(tab_bar.ScrollingSpeed, math.abs(tab_bar.ScrollingTarget - tab_bar.ScrollingAnim) / 0.3)
        local teleport = (tab_bar.PrevFrameVisible + 1 < g.FrameCount) or (tab_bar.ScrollingTargetDistToVisibility > 10.0 * g.FontSize)
        tab_bar.ScrollingAnim = teleport and tab_bar.ScrollingTarget or ImLinearSweep(tab_bar.ScrollingAnim, tab_bar.ScrollingTarget, g.IO.DeltaTime * tab_bar.ScrollingSpeed)
    else
        tab_bar.ScrollingSpeed = 0.0
    end
    tab_bar.ScrollingRectMinX = tab_bar.BarRect.Min.x + sections[1].Width + sections[1].Spacing
    tab_bar.ScrollingRectMaxX = tab_bar.BarRect.Max.x - sections[3].Width - sections[2].Spacing

    local window = g.CurrentWindow
    ImVec2_Copy(window.DC.CursorPos, tab_bar.BarRect.Min)
    ImGui.ItemSize(ImVec2(tab_bar.WidthAllTabs, tab_bar.BarRect:GetHeight()), tab_bar.FramePadding.y)
    window.DC.IdealMaxPos.x = ImMax(window.DC.IdealMaxPos.x, tab_bar.BarRect.Min.x + tab_bar.WidthAllTabsIdeal)
end

function ImGui.TabBarCalcTabID(tab_bar, label, docked_window)
    if docked_window ~= nil then
        IM_ASSERT(bit32.band(tab_bar.Flags, ImGuiTabBarFlags.DockNode) ~= 0)
        local id = docked_window.TabId
        ImGui.KeepAliveID(id)
        return id
    end
    return ImGui.GetCurrentContext().CurrentWindow:GetID(label)
end

function ImGui.TabBarCalcMaxTabWidth()
    return ImGui.GetCurrentContext().FontSize * 20.0
end

function ImGui.TabBarFindTabByID(tab_bar, tab_id)
    if tab_id ~= 0 then
        for n = 1, tab_bar.Tabs.Size do
            local tab = tab_bar.Tabs.Data[n]
            if tab.ID == tab_id then return tab end
        end
    end
    return nil
end

--- @param order int # 0-based visible order
function ImGui.TabBarFindTabByOrder(tab_bar, order)
    if order < 0 or order >= tab_bar.Tabs.Size then return nil end
    return tab_bar.Tabs.Data[order + 1]
end

--- @return int # 0-based order
function ImGui.TabBarGetTabOrder(tab_bar, tab)
    local i = tab_bar.Tabs:find_index(tab)
    return i and (i - 1) or -1
end

function ImGui.TabBarFindMostRecentlySelectedTabForActiveWindow(tab_bar)
    local most_recently_selected_tab = nil
    for n = 1, tab_bar.Tabs.Size do
        local tab = tab_bar.Tabs.Data[n]
        if most_recently_selected_tab == nil or most_recently_selected_tab.LastFrameSelected < tab.LastFrameSelected then
            if tab.Window and tab.Window.WasActive then most_recently_selected_tab = tab end
        end
    end
    return most_recently_selected_tab
end

function ImGui.TabBarGetCurrentTab(tab_bar)
    if tab_bar.LastTabItemIdx < 0 or tab_bar.LastTabItemIdx >= tab_bar.Tabs.Size then return nil end
    return tab_bar.Tabs.Data[tab_bar.LastTabItemIdx + 1]
end

function ImGui.TabBarGetTabName(tab_bar, tab)
    if tab.Window then return tab.Window.Name end
    if tab.Name == nil then return "N/A" end
    return tab.Name
end

function ImGui.TabBarGetTabPos(tab_bar, tab)
    if bit32.band(tab.Flags, ImGuiTabItemFlags.SectionMask_) == 0 then
        return tab_bar.BarRect.Min + ImVec2(IM_TRUNC(tab.Offset - tab_bar.ScrollingAnim), 0.0)
    end
    return tab_bar.BarRect.Min + ImVec2(tab.Offset, 0.0)
end

function ImGui.TabBarAddTab(tab_bar, tab_flags, window)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(ImGui.TabBarFindTabByID(tab_bar, window.TabId) == nil)
    IM_ASSERT(g.CurrentTabBar ~= tab_bar)
    if not window.HasCloseButton then
        tab_flags = bit32.bor(tab_flags, ImGuiTabItemFlags.NoCloseButton)
    end
    local new_tab = ImGuiTabItem()
    new_tab.ID = window.TabId
    new_tab.Flags = tab_flags
    new_tab.LastFrameVisible = tab_bar.CurrFrameVisible
    if new_tab.LastFrameVisible == -1 then new_tab.LastFrameVisible = g.FrameCount - 1 end
    new_tab.Window = window
    tab_bar.Tabs:push_back(new_tab)
end

function ImGui.TabBarRemoveTab(tab_bar, tab_id)
    local tab = ImGui.TabBarFindTabByID(tab_bar, tab_id)
    if tab then tab_bar.Tabs:erase(tab_bar.Tabs:find_index(tab)) end
    if tab_bar.VisibleTabId == tab_id then tab_bar.VisibleTabId = 0 end
    if tab_bar.SelectedTabId == tab_id then tab_bar.SelectedTabId = 0 end
    if tab_bar.NextSelectedTabId == tab_id then tab_bar.NextSelectedTabId = 0 end
end

function ImGui.TabBarCloseTab(tab_bar, tab)
    if bit32.band(tab.Flags, ImGuiTabItemFlags.Button) ~= 0 then return end
    if bit32.band(tab.Flags, bit32.bor(ImGuiTabItemFlags.UnsavedDocument, ImGuiTabItemFlags.NoAssumedClosure)) == 0 then
        tab.WantClose = true
        if tab_bar.VisibleTabId == tab.ID then
            tab.LastFrameVisible = -1
            tab_bar.SelectedTabId = 0
            tab_bar.NextSelectedTabId = 0
        end
    else
        if tab_bar.VisibleTabId ~= tab.ID then ImGui.TabBarQueueFocus(tab_bar, tab) end
    end
end

function ImGui.TabBarScrollClamp(tab_bar, scrolling)
    scrolling = ImMin(scrolling, tab_bar.WidthAllTabs - tab_bar.BarRect:GetWidth())
    return ImMax(scrolling, 0.0)
end

function ImGui.TabBarScrollToTab(tab_bar, tab_id, sections)
    local tab = ImGui.TabBarFindTabByID(tab_bar, tab_id)
    if tab == nil then return end

    if bit32.band(tab.Flags, ImGuiTabItemFlags.Leading) ~= 0 then
        tab = tab_bar.Tabs.Data[sections[1].TabCount + 1]
    elseif bit32.band(tab.Flags, ImGuiTabItemFlags.Trailing) ~= 0 then
        tab = tab_bar.Tabs.Data[sections[1].TabCount + sections[2].TabCount + 1]
    end
    if tab == nil or bit32.band(tab.Flags, ImGuiTabItemFlags.SectionMask_) ~= 0 then return end

    local g = ImGui.GetCurrentContext()
    local margin = ImClamp(tab_bar.ScrollingRectMaxX - tab_bar.ScrollingRectMinX - tab.Width, g.Style.ItemInnerSpacing.x, g.FontSize * 1.0)
    local order = ImGui.TabBarGetTabOrder(tab_bar, tab)
    local scrollable_width = TabBarCalcScrollableWidth(tab_bar, sections)

    local tab_x1 = tab.Offset - sections[1].Width + ((order > sections[1].TabCount - 1) and -margin or 0.0)
    local tab_x2 = tab.Offset - sections[1].Width + tab.Width + ((order + 1 < tab_bar.Tabs.Size - sections[3].TabCount) and margin or 1.0)
    tab_bar.ScrollingTargetDistToVisibility = 0.0
    if tab_bar.ScrollingTarget > tab_x1 or (tab_x2 - tab_x1 >= scrollable_width) then
        tab_bar.ScrollingTargetDistToVisibility = ImMax(tab_bar.ScrollingAnim - tab_x2, 0.0)
        tab_bar.ScrollingTarget = tab_x1
    elseif tab_bar.ScrollingTarget < tab_x2 - scrollable_width then
        tab_bar.ScrollingTargetDistToVisibility = ImMax((tab_x1 - scrollable_width) - tab_bar.ScrollingAnim, 0.0)
        tab_bar.ScrollingTarget = tab_x2 - scrollable_width
    end
end

--- TabBarQueueFocus(tab_bar, tab) or TabBarQueueFocus(tab_bar, tab_name)
function ImGui.TabBarQueueFocus(tab_bar, tab)
    if type(tab) == "string" then
        IM_ASSERT(bit32.band(tab_bar.Flags, ImGuiTabBarFlags.DockNode) == 0)
        tab_bar.NextSelectedTabId = ImGui.TabBarCalcTabID(tab_bar, tab, nil)
        return
    end
    tab_bar.NextSelectedTabId = tab.ID
end

function ImGui.TabBarQueueReorder(tab_bar, tab, offset)
    IM_ASSERT(offset ~= 0)
    IM_ASSERT(tab_bar.ReorderRequestTabId == 0)
    tab_bar.ReorderRequestTabId = tab.ID
    tab_bar.ReorderRequestOffset = offset
end

function ImGui.TabBarQueueReorderFromMousePos(tab_bar, src_tab, mouse_pos)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(tab_bar.ReorderRequestTabId == 0)
    if bit32.band(tab_bar.Flags, ImGuiTabBarFlags.Reorderable) == 0 then return end

    local tab_spacing = g.Style.ItemInnerSpacing.x
    local is_central_section = bit32.band(src_tab.Flags, ImGuiTabItemFlags.SectionMask_) == 0
    local bar_offset = tab_bar.BarRect.Min.x - (is_central_section and tab_bar.ScrollingTarget or 0)

    local dir = ((bar_offset + src_tab.Offset) > mouse_pos.x) and -1 or 1
    local src_idx = ImGui.TabBarGetTabOrder(tab_bar, src_tab)
    local dst_idx = src_idx
    local i = src_idx
    while i >= 0 and i < tab_bar.Tabs.Size do
        local dst_tab = tab_bar.Tabs.Data[i + 1]
        if bit32.band(dst_tab.Flags, ImGuiTabItemFlags.NoReorder) ~= 0 then break end
        if bit32.band(dst_tab.Flags, ImGuiTabItemFlags.SectionMask_) ~= bit32.band(src_tab.Flags, ImGuiTabItemFlags.SectionMask_) then break end
        dst_idx = i
        local x1 = bar_offset + dst_tab.Offset - tab_spacing
        local x2 = bar_offset + dst_tab.Offset + dst_tab.Width + tab_spacing
        if (dir < 0 and mouse_pos.x > x1) or (dir > 0 and mouse_pos.x < x2) then break end
        i = i + dir
    end

    if dst_idx ~= src_idx then
        ImGui.TabBarQueueReorder(tab_bar, src_tab, dst_idx - src_idx)
    end
end

function ImGui.TabBarProcessReorder(tab_bar)
    local tab1 = ImGui.TabBarFindTabByID(tab_bar, tab_bar.ReorderRequestTabId)
    if tab1 == nil or bit32.band(tab1.Flags, ImGuiTabItemFlags.NoReorder) ~= 0 then return false end

    local tab1_order = ImGui.TabBarGetTabOrder(tab_bar, tab1)
    local tab2_order = tab1_order + tab_bar.ReorderRequestOffset
    if tab2_order < 0 or tab2_order >= tab_bar.Tabs.Size then return false end

    local tab2 = tab_bar.Tabs.Data[tab2_order + 1]
    if bit32.band(tab2.Flags, ImGuiTabItemFlags.NoReorder) ~= 0 then return false end
    if bit32.band(tab1.Flags, ImGuiTabItemFlags.SectionMask_) ~= bit32.band(tab2.Flags, ImGuiTabItemFlags.SectionMask_) then return false end

    -- Move tab1 to tab2's position, shifting the tabs in between
    table.remove(tab_bar.Tabs.Data, tab1_order + 1)
    table.insert(tab_bar.Tabs.Data, tab2_order + 1, tab1)

    if bit32.band(tab_bar.Flags, ImGuiTabBarFlags.SaveSettings) ~= 0 then ImGui.MarkIniSettingsDirty() end
    return true
end

function ImGui.TabBarScrollingButtons(tab_bar)
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow

    local arrow_button_size = ImVec2(g.FontSize - 2.0, g.FontSize + g.Style.FramePadding.y * 2.0)
    local scrolling_buttons_width = arrow_button_size.x * 2.0

    local backup_cursor_pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y)

    local select_dir = 0
    local tc = g.Style.Colors[ImGuiCol.Text]
    local arrow_col = ImVec4(tc.x, tc.y, tc.z, tc.w * 0.5)

    ImGui.PushStyleColor(ImGuiCol.Text, arrow_col)
    ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
    ImGui.PushItemFlag(bit32.bor(ImGuiItemFlags.ButtonRepeat, ImGuiItemFlags.NoNav), true)
    local backup_repeat_delay = g.IO.KeyRepeatDelay
    local backup_repeat_rate = g.IO.KeyRepeatRate
    g.IO.KeyRepeatDelay = 0.250
    g.IO.KeyRepeatRate = 0.200
    local x = ImMax(tab_bar.BarRect.Min.x, tab_bar.BarRect.Max.x - scrolling_buttons_width)
    ImVec2_CopyV(window.DC.CursorPos, x, tab_bar.BarRect.Min.y)
    if ImGui.ArrowButtonEx("##<", ImGuiDir.Left, arrow_button_size, ImGuiButtonFlags.PressedOnClick) then select_dir = -1 end
    ImVec2_CopyV(window.DC.CursorPos, x + arrow_button_size.x, tab_bar.BarRect.Min.y)
    if ImGui.ArrowButtonEx("##>", ImGuiDir.Right, arrow_button_size, ImGuiButtonFlags.PressedOnClick) then select_dir = 1 end
    ImGui.PopItemFlag()
    ImGui.PopStyleColor(2)
    g.IO.KeyRepeatRate = backup_repeat_rate
    g.IO.KeyRepeatDelay = backup_repeat_delay

    local tab_to_scroll_to = nil
    if select_dir ~= 0 then
        local tab_item = ImGui.TabBarFindTabByID(tab_bar, tab_bar.SelectedTabId)
        if tab_item then
            local selected_order = ImGui.TabBarGetTabOrder(tab_bar, tab_item)
            local target_order = selected_order + select_dir
            while tab_to_scroll_to == nil do
                local idx = (target_order >= 0 and target_order < tab_bar.Tabs.Size) and target_order or selected_order
                tab_to_scroll_to = tab_bar.Tabs.Data[idx + 1]
                if bit32.band(tab_to_scroll_to.Flags, ImGuiTabItemFlags.Button) ~= 0 then
                    target_order = target_order + select_dir
                    selected_order = selected_order + select_dir
                    if not (target_order < 0 or target_order >= tab_bar.Tabs.Size) then tab_to_scroll_to = nil end
                end
            end
        end
    end
    ImVec2_Copy(window.DC.CursorPos, backup_cursor_pos)
    tab_bar.BarRect.Max.x = tab_bar.BarRect.Max.x - (scrolling_buttons_width + 1.0)

    return tab_to_scroll_to
end

function ImGui.TabBarTabListPopupButton(tab_bar)
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow

    local tab_list_popup_button_width = g.FontSize + g.Style.FramePadding.y
    local backup_cursor_pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y)
    ImVec2_CopyV(window.DC.CursorPos, tab_bar.BarRect.Min.x - g.Style.FramePadding.y, tab_bar.BarRect.Min.y)
    tab_bar.BarRect.Min.x = tab_bar.BarRect.Min.x + tab_list_popup_button_width

    local tc = g.Style.Colors[ImGuiCol.Text]
    ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(tc.x, tc.y, tc.z, tc.w * 0.5))
    ImGui.PushStyleColor(ImGuiCol.Button, ImVec4(0, 0, 0, 0))
    local open = ImGui.BeginCombo("##v", nil, bit32.bor(ImGuiComboFlags.NoPreview, ImGuiComboFlags.HeightLargest))
    ImGui.PopStyleColor(2)

    local tab_to_select = nil
    if open then
        for n = 1, tab_bar.Tabs.Size do
            local tab = tab_bar.Tabs.Data[n]
            if bit32.band(tab.Flags, ImGuiTabItemFlags.Button) == 0 then
                local tab_name = ImGui.TabBarGetTabName(tab_bar, tab)
                if ImGui.Selectable(tab_name, tab_bar.SelectedTabId == tab.ID) then
                    tab_to_select = tab
                end
            end
        end
        ImGui.EndCombo()
    end

    ImVec2_Copy(window.DC.CursorPos, backup_cursor_pos)
    return tab_to_select
end

---------------------------------------------------------------------------------------
-- [SECTION] Widgets: BeginTabItem, EndTabItem, etc.
---------------------------------------------------------------------------------------

--- @return bool visible, bool? p_open
function ImGui.BeginTabItem(label, p_open, flags)
    if flags == nil then flags = 0 end
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow
    if window.SkipItems then return false, p_open end

    local tab_bar = g.CurrentTabBar
    IM_ASSERT(tab_bar ~= nil, "Needs to be called between BeginTabBar() and EndTabBar()!")
    IM_ASSERT(bit32.band(flags, ImGuiTabItemFlags.Button) == 0)

    local ret
    ret, p_open = ImGui.TabItemEx(tab_bar, label, p_open, flags, nil)
    if ret and bit32.band(flags, ImGuiTabItemFlags.NoPushId) == 0 then
        local tab = tab_bar.Tabs.Data[tab_bar.LastTabItemIdx + 1]
        ImGui.PushOverrideID(tab.ID)
    end
    return ret, p_open
end

function ImGui.EndTabItem()
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow
    if window.SkipItems then return end

    local tab_bar = g.CurrentTabBar
    IM_ASSERT(tab_bar ~= nil, "Needs to be called between BeginTabBar() and EndTabBar()!")
    IM_ASSERT(tab_bar.LastTabItemIdx >= 0)
    local tab = tab_bar.Tabs.Data[tab_bar.LastTabItemIdx + 1]
    if bit32.band(tab.Flags, ImGuiTabItemFlags.NoPushId) == 0 then
        ImGui.PopID()
    end
end

function ImGui.TabItemButton(label, flags)
    if flags == nil then flags = 0 end
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow
    if window.SkipItems then return false end
    local tab_bar = g.CurrentTabBar
    IM_ASSERT(tab_bar ~= nil, "Needs to be called between BeginTabBar() and EndTabBar()!")
    return (ImGui.TabItemEx(tab_bar, label, nil, bit32.bor(flags, ImGuiTabItemFlags.Button, ImGuiTabItemFlags.NoReorder), nil))
end

function ImGui.TabItemSpacing(str_id, flags, width)
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow
    if window.SkipItems then return end
    local tab_bar = g.CurrentTabBar
    IM_ASSERT(tab_bar ~= nil, "Needs to be called between BeginTabBar() and EndTabBar()!")
    ImGui.SetNextItemWidth(width)
    ImGui.TabItemEx(tab_bar, str_id, nil, bit32.bor(flags or 0, ImGuiTabItemFlags.Button, ImGuiTabItemFlags.NoReorder, ImGuiTabItemFlags.Invisible), nil)
end

--- @return bool ret, bool? p_open
function ImGui.TabItemEx(tab_bar, label, p_open, flags, docked_window)
    local g = ImGui.GetCurrentContext()
    if tab_bar.WantLayout then
        local backup_next_item_data = {}
        for k, v in pairs(g.NextItemData) do backup_next_item_data[k] = v end
        ImGui.TabBarLayout(tab_bar)
        for k, v in pairs(backup_next_item_data) do g.NextItemData[k] = v end
    end
    local window = g.CurrentWindow
    if window.SkipItems then return false, p_open end

    local style = g.Style
    local id = ImGui.TabBarCalcTabID(tab_bar, label, docked_window)

    if p_open ~= nil and not p_open then
        ImGui.ItemAdd(ImRect(), id, nil, ImGuiItemFlags.NoNav)
        return false, p_open
    end

    IM_ASSERT(p_open == nil or bit32.band(flags, ImGuiTabItemFlags.Button) == 0)
    IM_ASSERT(bit32.band(flags, bit32.bor(ImGuiTabItemFlags.Leading, ImGuiTabItemFlags.Trailing)) ~= bit32.bor(ImGuiTabItemFlags.Leading, ImGuiTabItemFlags.Trailing))

    local has_p_open = (p_open ~= nil)
    if bit32.band(flags, ImGuiTabItemFlags.NoCloseButton) ~= 0 then
        has_p_open = false
    elseif not has_p_open then
        flags = bit32.bor(flags, ImGuiTabItemFlags.NoCloseButton)
    end

    local tab = ImGui.TabBarFindTabByID(tab_bar, id)
    local tab_is_new = false
    if tab == nil then
        tab = ImGuiTabItem()
        tab_bar.Tabs:push_back(tab)
        tab.ID = id
        tab_bar.TabsAddedNew = true
        tab_is_new = true
    end
    tab_bar.LastTabItemIdx = ImGui.TabBarGetTabOrder(tab_bar, tab)

    local size = ImGui.TabItemCalcSize(label, has_p_open or bit32.band(flags, ImGuiTabItemFlags.UnsavedDocument) ~= 0)
    tab.RequestedWidth = -1.0
    if bit32.band(g.NextItemData.HasFlags, ImGuiNextItemDataFlags.HasWidth) ~= 0 then
        size.x = g.NextItemData.Width
        tab.RequestedWidth = size.x
    end
    if tab_is_new then tab.Width = ImMax(1.0, size.x) end
    tab.ContentWidth = size.x
    tab.BeginOrder = tab_bar.TabsActiveCount
    tab_bar.TabsActiveCount = tab_bar.TabsActiveCount + 1

    local tab_bar_appearing = (tab_bar.PrevFrameVisible + 1 < g.FrameCount)
    local tab_bar_focused = bit32.band(tab_bar.Flags, ImGuiTabBarFlags.IsFocused) ~= 0
    local tab_appearing = (tab.LastFrameVisible + 1 < g.FrameCount)
    local tab_just_unsaved = bit32.band(flags, ImGuiTabItemFlags.UnsavedDocument) ~= 0 and bit32.band(tab.Flags, ImGuiTabItemFlags.UnsavedDocument) == 0
    local is_tab_button = bit32.band(flags, ImGuiTabItemFlags.Button) ~= 0
    tab.LastFrameVisible = g.FrameCount
    tab.Flags = flags
    tab.Window = docked_window

    if docked_window ~= nil then
        IM_ASSERT(bit32.band(tab_bar.Flags, ImGuiTabBarFlags.DockNode) ~= 0)
        tab.NameOffset = -1
        tab.Name = nil
    else
        tab.NameOffset = 0
        tab.Name = label
    end

    if not is_tab_button then
        if tab_appearing and bit32.band(tab_bar.Flags, ImGuiTabBarFlags.AutoSelectNewTabs) ~= 0 and tab_bar.NextSelectedTabId == 0 then
            if not tab_bar_appearing or tab_bar.SelectedTabId == 0 then
                ImGui.TabBarQueueFocus(tab_bar, tab)
            end
        end
        if bit32.band(flags, ImGuiTabItemFlags.SetSelected) ~= 0 and tab_bar.SelectedTabId ~= id then
            ImGui.TabBarQueueFocus(tab_bar, tab)
        end
    end

    local tab_contents_visible = (tab_bar.VisibleTabId == id)
    if tab_contents_visible then tab_bar.VisibleTabWasSubmitted = true end

    if not tab_contents_visible and tab_bar.SelectedTabId == 0 and tab_bar_appearing and docked_window == nil then
        if tab_bar.Tabs.Size == 1 and bit32.band(tab_bar.Flags, ImGuiTabBarFlags.AutoSelectNewTabs) == 0 then
            tab_contents_visible = true
        end
    end

    if tab_appearing and (not tab_bar_appearing or tab_is_new) then
        ImGui.ItemAdd(ImRect(), id, nil, ImGuiItemFlags.NoNav)
        if is_tab_button then return false, p_open end
        return tab_contents_visible, p_open
    end

    if tab_bar.SelectedTabId == id then tab.LastFrameSelected = g.FrameCount end

    local backup_main_cursor_pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y)

    local is_central_section = bit32.band(tab.Flags, ImGuiTabItemFlags.SectionMask_) == 0
    size.x = tab.Width
    local pos = ImGui.TabBarGetTabPos(tab_bar, tab)
    ImVec2_Copy(window.DC.CursorPos, pos)
    local bb = ImRect(pos, pos + size)

    local want_clip_rect = is_central_section and (bb.Min.x < tab_bar.ScrollingRectMinX or bb.Max.x > tab_bar.ScrollingRectMaxX)
    if want_clip_rect then
        ImGui.PushClipRect(ImVec2(ImClamp(bb.Min.x, tab_bar.ScrollingRectMinX, tab_bar.ScrollingRectMaxX), bb.Min.y - 1), ImVec2(tab_bar.ScrollingRectMaxX, bb.Max.y), true)
    end

    local backup_cursor_max_pos = ImVec2(window.DC.CursorMaxPos.x, window.DC.CursorMaxPos.y)
    ImGui.ItemSize(bb:GetSize(), style.FramePadding.y)
    ImVec2_Copy(window.DC.CursorMaxPos, backup_cursor_max_pos)

    if not ImGui.ItemAdd(bb, id) then
        if want_clip_rect then ImGui.PopClipRect() end
        ImVec2_Copy(window.DC.CursorPos, backup_main_cursor_pos)
        return tab_contents_visible, p_open
    end

    local button_flags = bit32.bor(is_tab_button and ImGuiButtonFlags.PressedOnClickRelease or ImGuiButtonFlags.PressedOnClick, ImGuiButtonFlags.AllowOverlap)
    if g.DragDropActive and not ImGuiPayload_IsDataType(g.DragDropPayload, IMGUI_PAYLOAD_TYPE_WINDOW) then
        button_flags = bit32.bor(button_flags, ImGuiButtonFlags.PressedOnDragDropHold)
    end
    local hovered, held, pressed
    if bit32.band(flags, ImGuiTabItemFlags.Invisible) ~= 0 then
        hovered, held, pressed = false, false, false
    else
        pressed, hovered, held = ImGui.ButtonBehavior(bb, id, button_flags)
    end
    if pressed and not is_tab_button then ImGui.TabBarQueueFocus(tab_bar, tab) end

    if held and docked_window and g.ActiveId == id and g.ActiveIdIsJustActivated then
        g.ActiveIdWindow = docked_window
    end

    local node = docked_window and docked_window.DockNode or nil
    local single_floating_window_node = node and node:IsFloatingNode() and (node.Windows.Size == 1)
    if held and single_floating_window_node and ImGui.IsMouseDragging(0, 0.0) then
        ImGui.StartMouseMovingWindow(docked_window)
    elseif held and not tab_appearing and ImGui.IsMouseDragging(0) then
        local drag_dir = 0
        local drag_distance_from_edge_x = 0.0
        if not g.DragDropActive and (bit32.band(tab_bar.Flags, ImGuiTabBarFlags.Reorderable) ~= 0 or docked_window ~= nil) then
            if g.IO.MouseDelta.x < 0.0 and g.IO.MousePos.x < bb.Min.x then
                drag_dir = -1
                drag_distance_from_edge_x = bb.Min.x - g.IO.MousePos.x
                ImGui.TabBarQueueReorderFromMousePos(tab_bar, tab, g.IO.MousePos)
            elseif g.IO.MouseDelta.x > 0.0 and g.IO.MousePos.x > bb.Max.x then
                drag_dir = 1
                drag_distance_from_edge_x = g.IO.MousePos.x - bb.Max.x
                ImGui.TabBarQueueReorderFromMousePos(tab_bar, tab, g.IO.MousePos)
            end
        end

        local can_undock = docked_window ~= nil and bit32.band(docked_window.Flags, ImGuiWindowFlags.NoMove) == 0 and bit32.band(node.MergedFlags, ImGuiDockNodeFlags.NoUndocking) == 0
        if can_undock then
            local undocking_tab = (g.DragDropActive and g.DragDropPayload.SourceId == id)
            if not undocking_tab then
                local threshold_base = g.FontSize
                local threshold_x = threshold_base * 2.2
                local threshold_y = (threshold_base * 1.5) + ImClamp((math.abs(g.IO.MouseDragMaxDistanceAbs[0].x) - threshold_base * 2.0) * 0.20, 0.0, threshold_base * 4.0)
                local distance_from_edge_y = ImMax(bb.Min.y - g.IO.MousePos.y, g.IO.MousePos.y - bb.Max.y)
                if distance_from_edge_y >= threshold_y then undocking_tab = true end
                if drag_distance_from_edge_x > threshold_x then
                    if (drag_dir < 0 and ImGui.TabBarGetTabOrder(tab_bar, tab) == 0) or (drag_dir > 0 and ImGui.TabBarGetTabOrder(tab_bar, tab) == tab_bar.Tabs.Size - 1) then
                        undocking_tab = true
                    end
                end
            end

            if undocking_tab then
                ImGui.DockContextQueueUndockWindow(g, docked_window)
                g.MovingWindow = docked_window
                ImGui.SetActiveID(g.MovingWindow.MoveId, g.MovingWindow)
                ImVec2_Copy(g.ActiveIdClickOffset, g.ActiveIdClickOffset - (g.MovingWindow.Pos - bb.Min))
                g.ActiveIdNoClearOnFocusLoss = true
                ImGui.SetActiveIdUsingAllKeyboardKeys()
            end
        end
    end

    local is_visible = bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible) ~= 0 and bit32.band(flags, ImGuiTabItemFlags.Invisible) == 0
    if is_visible then
        local display_draw_list = window.DrawList
        local col_idx
        if held or hovered then col_idx = ImGuiCol.TabHovered
        elseif tab_contents_visible then col_idx = tab_bar_focused and ImGuiCol.TabSelected or ImGuiCol.TabDimmedSelected
        else col_idx = tab_bar_focused and ImGuiCol.Tab or ImGuiCol.TabDimmed end
        ImGui.TabItemBackground(display_draw_list, bb, flags, ImGui.GetColorU32(col_idx))
        if tab_contents_visible and bit32.band(tab_bar.Flags, ImGuiTabBarFlags.DrawSelectedOverline) ~= 0 and style.TabBarOverlineSize > 0.0 then
            local tl = ImVec2(bb.Min.x, bb.Min.y + style.TabBarOverlineSize * 0.5)
            local tr = ImVec2(bb.Max.x, bb.Min.y + style.TabBarOverlineSize * 0.5)
            local overline_col = ImGui.GetColorU32(tab_bar_focused and ImGuiCol.TabSelectedOverline or ImGuiCol.TabDimmedSelectedOverline)
            if style.TabRounding > 0.0 then
                local rounding = style.TabRounding
                display_draw_list:PathArcToFast(tl + ImVec2(rounding, rounding), rounding, 7, 9)
                display_draw_list:PathArcToFast(tr + ImVec2(-rounding, rounding), rounding, 9, 11)
                display_draw_list:PathStroke(overline_col, style.TabBarOverlineSize)
            else
                display_draw_list:AddLine(tl, tr, overline_col, style.TabBarOverlineSize)
            end
        end
        ImGui.RenderNavCursor(bb, id)

        local hovered_unblocked = ImGui.IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByPopup)
        if tab_bar.SelectedTabId ~= tab.ID and hovered_unblocked and (ImGui.IsMouseClicked(1) or ImGui.IsMouseReleased(1)) and not is_tab_button then
            ImGui.TabBarQueueFocus(tab_bar, tab)
        end

        if bit32.band(tab_bar.Flags, ImGuiTabBarFlags.NoCloseWithMiddleMouseButton) ~= 0 then
            flags = bit32.bor(flags, ImGuiTabItemFlags.NoCloseWithMiddleMouseButton)
        end

        local close_button_id = has_p_open and ImGui.GetIDWithSeed("#CLOSE", nil, docked_window and docked_window.ID or id) or 0
        local label_flags = tab_just_unsaved and bit32.band(flags, bit32.bnot(ImGuiTabItemFlags.UnsavedDocument)) or flags
        local just_closed, text_clipped = ImGui.TabItemLabelAndCloseButton(display_draw_list, bb, label_flags, tab_bar.FramePadding, label, id, close_button_id, tab_contents_visible)
        if just_closed and has_p_open then
            p_open = false
            ImGui.TabBarCloseTab(tab_bar, tab)
        end

        if docked_window and (hovered or g.HoveredId == close_button_id) then
            g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredWindow)
        end

        if text_clipped and g.HoveredId == id and not held then
            if bit32.band(tab_bar.Flags, ImGuiTabBarFlags.NoTooltip) == 0 and bit32.band(tab.Flags, ImGuiTabItemFlags.NoTooltip) == 0 then
                local label_end = ImGui.FindRenderedTextEnd(label)
                ImGui.SetItemTooltip("%s", string.sub(label, 1, label_end - 1))
            end
        end
    end

    if want_clip_rect then ImGui.PopClipRect() end
    ImVec2_Copy(window.DC.CursorPos, backup_main_cursor_pos)

    if is_tab_button then return pressed, p_open end
    return tab_contents_visible, p_open
end

function ImGui.SetTabItemClosed(label)
    local g = ImGui.GetCurrentContext()
    local is_within_manual_tab_bar = g.CurrentTabBar and bit32.band(g.CurrentTabBar.Flags, ImGuiTabBarFlags.DockNode) == 0
    if is_within_manual_tab_bar then
        local tab_bar = g.CurrentTabBar
        local tab_id = ImGui.TabBarCalcTabID(tab_bar, label, nil)
        local tab = ImGui.TabBarFindTabByID(tab_bar, tab_id)
        if tab then tab.WantClose = true end
    else
        local window = ImGui.FindWindowByName(label)
        if window and window.DockIsActive then
            local node = window.DockNode
            if node then
                local tab_id = ImGui.TabBarCalcTabID(node.TabBar, label, window)
                ImGui.TabBarRemoveTab(node.TabBar, tab_id)
                window.DockTabWantClose = true
            end
        end
    end
end

--- TabItemCalcSize(label, has_close_button_or_unsaved_marker) or TabItemCalcSize(window)
function ImGui.TabItemCalcSize(label, has_close_button_or_unsaved_marker)
    if type(label) == "table" then
        local window = label
        return ImGui.TabItemCalcSize(window.Name, window.HasCloseButton or bit32.band(window.Flags, ImGuiWindowFlags.UnsavedDocument) ~= 0)
    end
    local g = ImGui.GetCurrentContext()
    local label_size = ImGui.CalcTextSize(label, nil, true)
    local size = ImVec2(label_size.x + g.Style.FramePadding.x, label_size.y + g.Style.FramePadding.y * 2.0)
    if has_close_button_or_unsaved_marker then
        size.x = size.x + g.Style.FramePadding.x + (g.Style.ItemInnerSpacing.x + g.FontSize)
    else
        size.x = size.x + g.Style.FramePadding.x + 1.0
    end
    return ImVec2(ImMin(size.x, ImGui.TabBarCalcMaxTabWidth()), size.y)
end

function ImGui.TabItemBackground(draw_list, bb, flags, col)
    local g = ImGui.GetCurrentContext()
    local width = bb:GetWidth()
    IM_ASSERT(width > 0.0)
    local rounding = ImMax(0.0, ImMin(bit32.band(flags, ImGuiTabItemFlags.Button) ~= 0 and g.Style.FrameRounding or g.Style.TabRounding, width * 0.5 - 1.0))
    local y1 = bb.Min.y + 1.0
    local y2 = bb.Max.y - g.Style.TabBarBorderSize
    draw_list:AddRectFilled(ImVec2(bb.Min.x, y1), ImVec2(bb.Max.x, y2), col, rounding, ImDrawFlags.RoundCornersTop)
    if g.Style.TabBorderSize > 0.0 then
        draw_list:PathLineTo(ImVec2(bb.Min.x, y2))
        draw_list:PathArcToFast(ImVec2(bb.Min.x + rounding, y1 + rounding), rounding, 6, 9)
        draw_list:PathArcToFast(ImVec2(bb.Max.x - rounding, y1 + rounding), rounding, 9, 12)
        draw_list:PathLineTo(ImVec2(bb.Max.x, y2))
        draw_list:PathStroke(ImGui.GetColorU32(ImGuiCol.Border), g.Style.TabBorderSize)
    end
end

--- @return bool just_closed, bool text_clipped
function ImGui.TabItemLabelAndCloseButton(draw_list, bb, flags, frame_padding, label, tab_id, close_button_id, is_contents_visible)
    local g = ImGui.GetCurrentContext()
    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size = ImGui.CalcTextSize(label, label_end, false)

    if bb:GetWidth() <= 1.0 then return false, false end

    local text_ellipsis_clip_bb = ImRect(bb.Min.x + frame_padding.x, bb.Min.y + frame_padding.y, bb.Max.x - frame_padding.x, bb.Max.y)
    local text_clipped = (text_ellipsis_clip_bb.Min.x + label_size.x) > text_ellipsis_clip_bb.Max.x

    local button_sz = g.FontSize
    local button_pos = ImVec2(ImMax(bb.Min.x, bb.Max.x - frame_padding.x - button_sz), bb.Min.y + frame_padding.y)

    local close_button_pressed = false
    local close_button_visible = false
    local is_hovered = g.HoveredId == tab_id or g.HoveredId == close_button_id or g.ActiveId == tab_id or g.ActiveId == close_button_id

    if close_button_id ~= 0 then
        if is_contents_visible then
            close_button_visible = (g.Style.TabCloseButtonMinWidthSelected < 0.0) or (is_hovered and bb:GetWidth() >= ImMax(button_sz, g.Style.TabCloseButtonMinWidthSelected))
        else
            close_button_visible = (g.Style.TabCloseButtonMinWidthUnselected < 0.0) or (is_hovered and bb:GetWidth() >= ImMax(button_sz, g.Style.TabCloseButtonMinWidthUnselected))
        end
    end

    local unsaved_marker_visible = bit32.band(flags, ImGuiTabItemFlags.UnsavedDocument) ~= 0 and (button_pos.x + button_sz <= bb.Max.x) and (not close_button_visible or not is_hovered)
    if unsaved_marker_visible then
        local bullet_pos = button_pos + ImVec2(button_sz, button_sz) * 0.5
        ImGui.RenderBullet(draw_list, bullet_pos, ImGui.GetColorU32(ImGuiCol.UnsavedMarker))
    elseif close_button_visible then
        local last_item_backup = ImGuiLastItemData()
        ImGuiLastItemData_Copy(last_item_backup, g.LastItemData)
        if ImGui.CloseButton(close_button_id, button_pos) then close_button_pressed = true end
        ImGuiLastItemData_Copy(g.LastItemData, last_item_backup)

        if is_hovered and bit32.band(flags, ImGuiTabItemFlags.NoCloseWithMiddleMouseButton) == 0 and ImGui.IsMouseClicked(2) then
            close_button_pressed = true
        end
    end

    local ellipsis_max_x = text_ellipsis_clip_bb.Max.x
    if close_button_visible or unsaved_marker_visible then
        local visible_without_hover = unsaved_marker_visible or ((is_contents_visible and g.Style.TabCloseButtonMinWidthSelected or g.Style.TabCloseButtonMinWidthUnselected) < 0.0)
        if visible_without_hover then
            text_ellipsis_clip_bb.Max.x = text_ellipsis_clip_bb.Max.x - button_sz * 0.90
            ellipsis_max_x = ellipsis_max_x - button_sz * 0.90
        else
            text_ellipsis_clip_bb.Max.x = text_ellipsis_clip_bb.Max.x - button_sz * 1.00
        end
    end
    ImGui.LogSetNextTextDecoration("/", "\\")
    ImGui.RenderTextEllipsis(draw_list, text_ellipsis_clip_bb.Min, text_ellipsis_clip_bb.Max, ellipsis_max_x, label, label_end, label_size)

    return close_button_pressed, text_clipped
end

return true
