--- ImGui Sincerely
-- Docking: 1:1 port of imgui.cpp [SECTION] DOCKING (docking branch, 1.93 WIP)
--
-- Port notes:
-- - Main viewport only (no multi-viewports on Roblox): viewport creation/merging code paths are kept where cheap, but
--   windows always live in the main viewport.
-- - ImGuiDockContext.Nodes (ImGuiStorage in C++) is a Lua table ID -> node. Iterations that upstream does over the
--   sorted storage are done over a sorted snapshot of the IDs (DockContextNodesSorted) for deterministic order.
-- - node.ChildNodes is a table indexed [0] and [1] like upstream.
-- - ImGuiDockPreviewData.DropRectsDraw is indexed [dir + 1] with dir in -1..3 (so keys 0..4), like upstream.

local MT = ImGui.GetMetatables()

IMGUI_PAYLOAD_TYPE_WINDOW = "_IMWINDOW"

local DOCKING_HOST_DRAW_CHANNEL_BG = 0 -- Dock host: background fill
local DOCKING_HOST_DRAW_CHANNEL_FG = 1 -- Dock host: decorations and contents

local DOCKING_SPLITTER_SIZE = 2.0

---------------------------------------------------------------------------------------
-- Docking: flags & enums
---------------------------------------------------------------------------------------

ImGuiDockNodeFlags = {
    None                         = 0,
    KeepAliveOnly                = bit32.lshift(1, 0),
    NoDockingOverCentralNode     = bit32.lshift(1, 2),
    PassthruCentralNode          = bit32.lshift(1, 3),
    NoDockingSplit               = bit32.lshift(1, 4),
    NoResize                     = bit32.lshift(1, 5),
    AutoHideTabBar               = bit32.lshift(1, 6),
    NoUndocking                  = bit32.lshift(1, 7),
    -- [Internal]
    DockSpace                    = bit32.lshift(1, 10),
    CentralNode                  = bit32.lshift(1, 11),
    NoTabBar                     = bit32.lshift(1, 12),
    HiddenTabBar                 = bit32.lshift(1, 13),
    NoWindowMenuButton           = bit32.lshift(1, 14),
    NoCloseButton                = bit32.lshift(1, 15),
    NoResizeX                    = bit32.lshift(1, 16),
    NoResizeY                    = bit32.lshift(1, 17),
    DockedWindowsInFocusRoute    = bit32.lshift(1, 18),
    NoDockingSplitOther          = bit32.lshift(1, 19),
    NoDockingOverMe              = bit32.lshift(1, 20),
    NoDockingOverOther           = bit32.lshift(1, 21),
    NoDockingOverEmpty           = bit32.lshift(1, 22),
}
do
    local F = ImGuiDockNodeFlags
    F.NoSplit = F.NoDockingSplit
    F.NoDockingInCentralNode = F.NoDockingOverCentralNode
    F.NoDocking = bit32.bor(F.NoDockingOverMe, F.NoDockingOverOther, F.NoDockingOverEmpty, F.NoDockingSplit, F.NoDockingSplitOther)
    F.SharedFlagsInheritMask_ = 0xFFFFFFFF
    F.NoResizeFlagsMask_ = bit32.bor(F.NoResize, F.NoResizeX, F.NoResizeY)
    F.LocalFlagsTransferMask_ = bit32.bor(F.NoDockingSplit, F.NoResizeFlagsMask_, F.AutoHideTabBar, F.CentralNode, F.NoTabBar, F.HiddenTabBar, F.NoWindowMenuButton, F.NoCloseButton)
    F.SavedFlagsMask_ = bit32.bor(F.NoResizeFlagsMask_, F.DockSpace, F.CentralNode, F.NoTabBar, F.HiddenTabBar, F.NoWindowMenuButton, F.NoCloseButton)
end

ImGuiDataAuthority = { Auto = 0, DockNode = 1, Window = 2 }

ImGuiDockNodeState = {
    Unknown = 0,
    HostWindowHiddenBecauseSingleWindow = 1,
    HostWindowHiddenBecauseWindowsAreResizing = 2,
    HostWindowVisible = 3,
}

ImGuiWindowDockStyleCol = {
    Text = 0, TabHovered = 1, TabFocused = 2, TabSelected = 3, TabSelectedOverline = 4,
    TabDimmed = 5, TabDimmedSelected = 6, TabDimmedSelectedOverline = 7, UnsavedMarker = 8, COUNT = 9,
}

local ImGuiDockRequestType = { None = 0, Dock = 1, Undock = 2, Split = 3 }

---------------------------------------------------------------------------------------
-- Docking: Internal Types
---------------------------------------------------------------------------------------

local function ImGuiDockRequest()
    return {
        Type = ImGuiDockRequestType.None,
        DockTargetWindow = nil, DockTargetNode = nil, DockPayload = nil,
        DockSplitDir = ImGuiDir.None, DockSplitRatio = 0.5, DockSplitOuter = false,
        UndockTargetWindow = nil, UndockTargetNode = nil,
    }
end

local function ImGuiDockNodeSettings()
    return {
        ID = 0, ParentNodeId = 0, ParentWindowId = 0, SelectedTabId = 0,
        SplitAxis = ImGuiAxis.None, Depth = 0, Flags = 0,
        Pos = ImVec2(0, 0), Size = ImVec2(0, 0), SizeRef = ImVec2(0, 0),
    }
end

function ImGuiDockContext()
    return { Nodes = {}, Requests = ImVector(), NodesSettings = ImVector(), WantFullRebuild = false }
end

MT.ImGuiDockNode = {}
MT.ImGuiDockNode.__index = MT.ImGuiDockNode
local DN = MT.ImGuiDockNode

function ImGuiDockNode(id)
    return setmetatable({
        ID = id,
        SharedFlags = 0, LocalFlags = 0, LocalFlagsInWindows = 0, MergedFlags = 0,
        State = ImGuiDockNodeState.Unknown,
        ParentNode = nil,
        ChildNodes = { [0] = nil, [1] = nil },
        Windows = ImVector(),
        TabBar = nil,
        Pos = ImVec2(0, 0), Size = ImVec2(0, 0), SizeRef = ImVec2(0, 0),
        SplitAxis = ImGuiAxis.None,
        LastBgColor = IM_COL32_WHITE,
        WindowClass = ImGuiWindowClass(),
        HostWindow = nil, VisibleWindow = nil,
        CentralNode = nil, OnlyNodeWithWindows = nil,
        CountNodeWithWindows = 0,
        LastFrameAlive = -1, LastFrameActive = -1, LastFrameFocused = -1,
        LastFocusedNodeId = 0, SelectedTabId = 0, WantCloseTabId = 0, RefViewportId = 0,
        AuthorityForPos = ImGuiDataAuthority.DockNode, AuthorityForSize = ImGuiDataAuthority.DockNode,
        AuthorityForViewport = ImGuiDataAuthority.Auto,
        IsVisible = true, IsFocused = false, IsBgDrawnThisFrame = false,
        HasCloseButton = false, HasWindowMenuButton = false, HasCentralNodeChild = false,
        WantCloseAll = false, WantLockSizeOnce = false, WantMouseMove = false,
        WantHiddenTabBarUpdate = false, WantHiddenTabBarToggle = false,
    }, DN)
end

function DN:IsRootNode()     return self.ParentNode == nil end
function DN:IsDockSpace()    return bit32.band(self.MergedFlags, ImGuiDockNodeFlags.DockSpace) ~= 0 end
function DN:IsFloatingNode() return self.ParentNode == nil and bit32.band(self.MergedFlags, ImGuiDockNodeFlags.DockSpace) == 0 end
function DN:IsCentralNode()  return bit32.band(self.MergedFlags, ImGuiDockNodeFlags.CentralNode) ~= 0 end
function DN:IsHiddenTabBar() return bit32.band(self.MergedFlags, ImGuiDockNodeFlags.HiddenTabBar) ~= 0 end
function DN:IsNoTabBar()     return bit32.band(self.MergedFlags, ImGuiDockNodeFlags.NoTabBar) ~= 0 end
function DN:IsSplitNode()    return self.ChildNodes[0] ~= nil end
function DN:IsLeafNode()     return self.ChildNodes[0] == nil end
function DN:IsEmpty()        return self.ChildNodes[0] == nil and self.Windows.Size == 0 end
function DN:Rect()           return ImRect(self.Pos.x, self.Pos.y, self.Pos.x + self.Size.x, self.Pos.y + self.Size.y) end
function DN:SetLocalFlags(flags) self.LocalFlags = flags; self:UpdateMergedFlags() end
function DN:UpdateMergedFlags() self.MergedFlags = bit32.bor(self.SharedFlags, self.LocalFlags, self.LocalFlagsInWindows) end

local function ImGuiDockPreviewData()
    local d = {
        FutureNode = ImGuiDockNode(0),
        IsDropAllowed = false, IsCenterAvailable = false, IsSidesAvailable = false, IsSplitDirExplicit = false,
        SplitNode = nil, SplitDir = ImGuiDir.None, SplitRatio = 0.0,
        DropRectsDraw = {},
    }
    for n = 0, 4 do d.DropRectsDraw[n] = ImRect(FLT_MAX, FLT_MAX, -FLT_MAX, -FLT_MAX) end
    return d
end

local function DockNodeGetHostWindowTitle(node)
    return string.format("##DockNode_%02X", node.ID)
end

local function IsRectInverted(r) return r.Min.x > r.Max.x or r.Min.y > r.Max.y end

--- Sorted snapshot of node IDs (upstream iterates ImGuiStorage which is sorted by key)
local function DockContextNodesSorted(ctx)
    local ids = {}
    for id in pairs(ctx.DockContext.Nodes) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end
ImGui.DockContextNodesSorted = DockContextNodesSorted

---------------------------------------------------------------------------------------
-- Docking: ImGuiDockContext
---------------------------------------------------------------------------------------

local DockSettingsHandler_ClearAll, DockSettingsHandler_ApplyAll, DockSettingsHandler_ReadOpen, DockSettingsHandler_ReadLine, DockSettingsHandler_WriteAll
local DockSettingsRenameNodeReferences, DockSettingsRemoveNodeReferences, DockSettingsFindNodeSettings

function ImGui.DockContextInitialize(ctx)
    local g = ctx
    local ini_handler = ImGuiSettingsHandler()
    ini_handler.TypeName = "Docking"
    ini_handler.TypeHash = ImHashStr("Docking")
    ini_handler.ClearAllFn = DockSettingsHandler_ClearAll
    ini_handler.ReadInitFn = DockSettingsHandler_ClearAll
    ini_handler.ReadOpenFn = DockSettingsHandler_ReadOpen
    ini_handler.ReadLineFn = DockSettingsHandler_ReadLine
    ini_handler.ApplyAllFn = DockSettingsHandler_ApplyAll
    ini_handler.WriteAllFn = DockSettingsHandler_WriteAll
    g.SettingsHandlers:push_back(ini_handler)

    g.DockNodeWindowMenuHandler = ImGui.DockNodeWindowMenuHandler_Default
end

function ImGui.DockContextShutdown(ctx)
    for _, id in ipairs(DockContextNodesSorted(ctx)) do
        local node = ctx.DockContext.Nodes[id]
        if node then ImGui.DockContextDeleteNode(ctx, node) end
    end
end

function ImGui.DockContextClearNodes(ctx, root_id, clear_settings_refs)
    ImGui.DockBuilderRemoveNodeDockedWindows(root_id, clear_settings_refs)
    ImGui.DockBuilderRemoveNodeChildNodes(root_id)
end

function ImGui.DockContextRebuildNodes(ctx)
    local dc = ctx.DockContext
    ImGui.SaveIniSettingsToMemory()
    local root_id = 0
    ImGui.DockContextClearNodes(ctx, root_id, false)
    ImGui.DockContextBuildNodesFromSettings(ctx, dc.NodesSettings.Data, dc.NodesSettings.Size)
    ImGui.DockContextBuildAddWindowsToNodes(ctx, root_id)
end

function ImGui.DockContextNewFrameUpdateUndocking(ctx)
    local g = ctx
    local dc = ctx.DockContext
    if bit32.band(g.IO.ConfigFlags, ImGuiConfigFlags.DockingEnable) == 0 then
        if next(dc.Nodes) ~= nil or dc.Requests.Size > 0 then
            ImGui.DockContextClearNodes(ctx, 0, true)
        end
        return
    end

    if g.IO.ConfigDockingNoSplit then
        for _, id in ipairs(DockContextNodesSorted(ctx)) do
            local node = dc.Nodes[id]
            if node and node:IsRootNode() and node:IsSplitNode() then
                ImGui.DockBuilderRemoveNodeChildNodes(node.ID)
            end
        end
    end

    if dc.WantFullRebuild then
        ImGui.DockContextRebuildNodes(ctx)
        dc.WantFullRebuild = false
    end

    for _, req in dc.Requests:iter() do
        if req.Type == ImGuiDockRequestType.Undock and req.UndockTargetWindow then
            ImGui.DockContextProcessUndockWindow(ctx, req.UndockTargetWindow)
        elseif req.Type == ImGuiDockRequestType.Undock and req.UndockTargetNode then
            ImGui.DockContextProcessUndockNode(ctx, req.UndockTargetNode)
        end
    end
end

function ImGui.DockContextNewFrameUpdateDocking(ctx)
    local g = ctx
    local dc = ctx.DockContext
    if bit32.band(g.IO.ConfigFlags, ImGuiConfigFlags.DockingEnable) == 0 then return end

    g.DebugHoveredDockNode = nil
    local hovered_window = g.HoveredWindowUnderMovingWindow
    if hovered_window then
        if hovered_window.DockNodeAsHost then
            g.DebugHoveredDockNode = ImGui.DockNodeTreeFindVisibleNodeByPos(hovered_window.DockNodeAsHost, g.IO.MousePos)
        elseif hovered_window.RootWindow.DockNode then
            g.DebugHoveredDockNode = hovered_window.RootWindow.DockNode
        end
    end

    for _, req in dc.Requests:iter() do
        if req.Type == ImGuiDockRequestType.Dock then
            ImGui.DockContextProcessDock(ctx, req)
        end
    end
    dc.Requests:resize(0)

    for _, id in ipairs(DockContextNodesSorted(ctx)) do
        local node = dc.Nodes[id]
        if node and node:IsFloatingNode() then
            ImGui.DockNodeUpdate(node)
        end
    end
end

function ImGui.DockContextEndFrame(ctx)
    local g = ctx
    local dc = g.DockContext
    for _, id in ipairs(DockContextNodesSorted(ctx)) do
        local node = dc.Nodes[id]
        if node and node.LastFrameActive == g.FrameCount and node.IsVisible and node.HostWindow and node:IsLeafNode() and not node.IsBgDrawnThisFrame then
            local bg_rect = ImRect(node.Pos + ImVec2(0.0, ImGui.GetFrameHeight()), node.Pos + node.Size)
            local bg_rounding_flags = ImGui.CalcRoundingFlagsForRectInRect(bg_rect, node.HostWindow:Rect(), g.Style.DockingSeparatorSize)
            node.HostWindow.DrawList:ChannelsSetCurrent(DOCKING_HOST_DRAW_CHANNEL_BG)
            node.HostWindow.DrawList:AddRectFilled(bg_rect.Min, bg_rect.Max, node.LastBgColor, node.HostWindow.WindowRounding, bg_rounding_flags)
        end
    end
end

function ImGui.DockContextFindNodeByID(ctx, id)
    return ctx.DockContext.Nodes[id]
end

function ImGui.DockContextGenNodeID(ctx)
    local id = 0x0001
    while ImGui.DockContextFindNodeByID(ctx, id) ~= nil do id = id + 1 end
    return id
end

function ImGui.DockContextAddNode(ctx, id)
    if id == 0 then
        id = ImGui.DockContextGenNodeID(ctx)
    else
        IM_ASSERT(ImGui.DockContextFindNodeByID(ctx, id) == nil)
    end
    local node = ImGuiDockNode(id)
    ctx.DockContext.Nodes[node.ID] = node
    return node
end

function ImGui.DockContextRemoveNode(ctx, node, merge_sibling_into_parent_node)
    IM_ASSERT(ImGui.DockContextFindNodeByID(ctx, node.ID) == node)
    IM_ASSERT(node.ChildNodes[0] == nil and node.ChildNodes[1] == nil)
    IM_ASSERT(node.Windows.Size == 0)

    if node.HostWindow then node.HostWindow.DockNodeAsHost = nil end

    local parent_node = node.ParentNode
    local merge = (merge_sibling_into_parent_node and parent_node ~= nil)
    if merge then
        IM_ASSERT(parent_node.ChildNodes[0] == node or parent_node.ChildNodes[1] == node)
        local sibling_node = (parent_node.ChildNodes[0] == node) and parent_node.ChildNodes[1] or parent_node.ChildNodes[0]
        ImGui.DockNodeTreeMerge(ctx, parent_node, sibling_node)
    else
        if parent_node then
            for n = 0, 1 do
                if parent_node.ChildNodes[n] == node then node.ParentNode.ChildNodes[n] = nil end
            end
        end
        ImGui.DockContextDeleteNode(ctx, node)
    end
end

function ImGui.DockContextDeleteNode(ctx, node)
    local dc = ctx.DockContext
    node.TabBar = nil
    dc.Nodes[node.ID] = nil
end

function ImGui.DockContextPruneUnusedSettingsNodes(ctx)
    local g = ctx
    local dc = ctx.DockContext
    IM_ASSERT(g.Windows.Size == 0)

    local pool = {}
    local function GetOrAdd(id)
        local d = pool[id]
        if not d then d = { CountWindows = 0, CountChildWindows = 0, CountChildNodes = 0, RootId = 0 }; pool[id] = d end
        return d
    end

    for _, settings in dc.NodesSettings:iter() do
        if pool[settings.ID] ~= nil then
            settings.ID = 0
        else
            local parent_data = (settings.ParentNodeId ~= 0) and pool[settings.ParentNodeId] or nil
            GetOrAdd(settings.ID).RootId = parent_data and parent_data.RootId or settings.ID
            if settings.ParentNodeId ~= 0 then
                local p = GetOrAdd(settings.ParentNodeId)
                p.CountChildNodes = p.CountChildNodes + 1
            end
        end
    end

    for _, settings in dc.NodesSettings:iter() do
        if settings.ParentWindowId ~= 0 then
            local window_settings = ImGui.FindWindowSettingsByID(settings.ParentWindowId)
            if window_settings and window_settings.DockId ~= 0 then
                local data = pool[window_settings.DockId]
                if data then data.CountChildNodes = data.CountChildNodes + 1 end
            end
        end
    end

    for _, settings in g.SettingsWindows:iter() do
        local dock_id = settings.DockId
        if dock_id and dock_id ~= 0 then
            local data = pool[dock_id]
            if data then
                data.CountWindows = data.CountWindows + 1
                local data_root = (data.RootId == dock_id) and data or pool[data.RootId]
                if data_root then data_root.CountChildWindows = data_root.CountChildWindows + 1 end
            end
        end
    end

    for _, settings in dc.NodesSettings:iter() do
        local data = pool[settings.ID]
        if data ~= nil and data.CountWindows <= 1 then
            local data_root = (settings.ID == data.RootId) and data or pool[data.RootId]
            local data_parent = (settings.ParentNodeId ~= 0) and pool[settings.ParentNodeId] or nil

            local remove = false
            remove = remove or (data.CountWindows == 1 and settings.ParentNodeId == 0 and data.CountChildNodes == 0 and bit32.band(settings.Flags, ImGuiDockNodeFlags.CentralNode) == 0)
            remove = remove or (data.CountWindows == 0 and settings.ParentNodeId == 0 and data.CountChildNodes == 0)
            remove = remove or (data_root == nil or data_root.CountChildWindows == 0)
            if remove then
                DockSettingsRemoveNodeReferences({ settings.ID }, 1)
                settings.ID = 0
            elseif data_parent and data_parent.CountChildNodes == 1 then
                DockSettingsRenameNodeReferences(settings.ID, settings.ParentNodeId)
                settings.ID = 0
            end
        end
    end
end

--- @param node_settings_array table # 1-based array
function ImGui.DockContextBuildNodesFromSettings(ctx, node_settings_array, node_settings_count)
    for node_n = 1, node_settings_count do
        local settings = node_settings_array[node_n]
        if settings.ID ~= 0 and ImGui.DockContextFindNodeByID(ctx, settings.ID) == nil then
            local node = ImGui.DockContextAddNode(ctx, settings.ID)
            node.ParentNode = (settings.ParentNodeId ~= 0) and ImGui.DockContextFindNodeByID(ctx, settings.ParentNodeId) or nil
            node.Pos = ImVec2(settings.Pos.x, settings.Pos.y)
            node.Size = ImVec2(settings.Size.x, settings.Size.y)
            node.SizeRef = ImVec2(settings.SizeRef.x, settings.SizeRef.y)
            node.AuthorityForPos = ImGuiDataAuthority.DockNode
            node.AuthorityForSize = ImGuiDataAuthority.DockNode
            node.AuthorityForViewport = ImGuiDataAuthority.DockNode
            if node.ParentNode and node.ParentNode.ChildNodes[0] == nil then
                node.ParentNode.ChildNodes[0] = node
            elseif node.ParentNode and node.ParentNode.ChildNodes[1] == nil then
                node.ParentNode.ChildNodes[1] = node
            end
            node.SelectedTabId = settings.SelectedTabId
            node.SplitAxis = settings.SplitAxis
            node:SetLocalFlags(bit32.band(settings.Flags, ImGuiDockNodeFlags.SavedFlagsMask_))

            local root_node = ImGui.DockNodeGetRootNode(node)
            node.HostWindow = ImGui.FindWindowByName(DockNodeGetHostWindowTitle(root_node))
        end
    end
end

function ImGui.DockContextBuildAddWindowsToNodes(ctx, root_id)
    local g = ctx
    for _, window in g.Windows:iter() do
        if window.DockId ~= 0 and window.LastFrameActive >= g.FrameCount - 1 and window.DockNode == nil then
            local node = ImGui.DockContextFindNodeByID(ctx, window.DockId)
            IM_ASSERT(node ~= nil)
            if root_id == 0 or ImGui.DockNodeGetRootNode(node).ID == root_id then
                ImGui.DockNodeAddWindow(node, window, true)
            end
        end
    end
end

---------------------------------------------------------------------------------------
-- Docking: ImGuiDockContext Docking/Undocking functions
---------------------------------------------------------------------------------------

function ImGui.DockContextQueueDock(ctx, target, target_node, payload, split_dir, split_ratio, split_outer)
    IM_ASSERT(target ~= payload)
    local req = ImGuiDockRequest()
    req.Type = ImGuiDockRequestType.Dock
    req.DockTargetWindow = target
    req.DockTargetNode = target_node
    req.DockPayload = payload
    req.DockSplitDir = split_dir
    req.DockSplitRatio = split_ratio
    req.DockSplitOuter = split_outer
    ctx.DockContext.Requests:push_back(req)
end

function ImGui.DockContextQueueUndockWindow(ctx, window)
    local req = ImGuiDockRequest()
    req.Type = ImGuiDockRequestType.Undock
    req.UndockTargetWindow = window
    ctx.DockContext.Requests:push_back(req)
end

function ImGui.DockContextQueueUndockNode(ctx, node)
    local req = ImGuiDockRequest()
    req.Type = ImGuiDockRequestType.Undock
    req.UndockTargetNode = node
    ctx.DockContext.Requests:push_back(req)
end

function ImGui.DockContextQueueNotifyRemovedNode(ctx, node)
    for _, req in ctx.DockContext.Requests:iter() do
        if req.DockTargetNode == node then req.Type = ImGuiDockRequestType.None end
    end
end

function ImGui.DockContextProcessDock(ctx, req)
    IM_ASSERT((req.Type == ImGuiDockRequestType.Dock and req.DockPayload ~= nil) or (req.Type == ImGuiDockRequestType.Split and req.DockPayload == nil))
    IM_ASSERT(req.DockTargetWindow ~= nil or req.DockTargetNode ~= nil)
    local g = ctx

    local payload_window = req.DockPayload
    local target_window = req.DockTargetWindow
    local node = req.DockTargetNode

    local next_selected_id = 0
    local payload_node = nil
    if payload_window then
        payload_node = payload_window.DockNodeAsHost
        payload_window.DockNodeAsHost = nil
        if payload_node and payload_node:IsLeafNode() then
            next_selected_id = (payload_node.TabBar.NextSelectedTabId ~= 0) and payload_node.TabBar.NextSelectedTabId or payload_node.TabBar.SelectedTabId
        end
        if payload_node == nil then next_selected_id = payload_window.TabId end
    end

    if node then IM_ASSERT(node.LastFrameAlive <= g.FrameCount) end
    if node and target_window and node == target_window.DockNodeAsHost then
        IM_ASSERT(node.Windows.Size > 0 or node:IsSplitNode() or node:IsCentralNode())
    end

    if node == nil then
        node = ImGui.DockContextAddNode(ctx, 0)
        node.Pos = ImVec2(target_window.Pos.x, target_window.Pos.y)
        node.Size = ImVec2(target_window.Size.x, target_window.Size.y)
        if target_window.DockNodeAsHost == nil then
            ImGui.DockNodeAddWindow(node, target_window, true)
            local t0 = node.TabBar.Tabs.Data[1]
            t0.Flags = bit32.band(t0.Flags, bit32.bnot(ImGuiTabItemFlags.Unsorted))
            target_window.DockIsActive = true
        end
    end

    local split_dir = req.DockSplitDir
    if split_dir ~= ImGuiDir.None then
        local split_axis = (split_dir == ImGuiDir.Left or split_dir == ImGuiDir.Right) and ImGuiAxis.X or ImGuiAxis.Y
        local split_inheritor_child_idx = (split_dir == ImGuiDir.Left or split_dir == ImGuiDir.Up) and 1 or 0
        local split_ratio = req.DockSplitRatio
        ImGui.DockNodeTreeSplit(ctx, node, split_axis, split_inheritor_child_idx, split_ratio, payload_node)
        local new_node = node.ChildNodes[bit32.bxor(split_inheritor_child_idx, 1)]
        new_node.HostWindow = node.HostWindow
        node = new_node
    end
    node:SetLocalFlags(bit32.band(node.LocalFlags, bit32.bnot(ImGuiDockNodeFlags.HiddenTabBar)))

    if node ~= payload_node then
        if node.Windows.Size > 0 and node.TabBar == nil then
            ImGui.DockNodeAddTabBar(node)
            for n = 1, node.Windows.Size do
                ImGui.TabBarAddTab(node.TabBar, ImGuiTabItemFlags.None, node.Windows.Data[n])
            end
        end

        if payload_node ~= nil then
            if payload_node:IsSplitNode() then
                if node.Windows.Size > 0 then
                    IM_ASSERT(payload_node.OnlyNodeWithWindows ~= nil)
                    local visible_node = payload_node.OnlyNodeWithWindows
                    if visible_node.TabBar then IM_ASSERT(visible_node.TabBar.Tabs.Size > 0) end
                    ImGui.DockNodeMoveWindows(node, visible_node)
                    ImGui.DockNodeMoveWindows(visible_node, node)
                    DockSettingsRenameNodeReferences(node.ID, visible_node.ID)
                end
                if node:IsCentralNode() then
                    local last_focused_node = ImGui.DockContextFindNodeByID(ctx, payload_node.LastFocusedNodeId)
                    IM_ASSERT(last_focused_node ~= nil)
                    local last_focused_root_node = ImGui.DockNodeGetRootNode(last_focused_node)
                    IM_ASSERT(last_focused_root_node == ImGui.DockNodeGetRootNode(payload_node))
                    last_focused_node:SetLocalFlags(bit32.bor(last_focused_node.LocalFlags, ImGuiDockNodeFlags.CentralNode))
                    node:SetLocalFlags(bit32.band(node.LocalFlags, bit32.bnot(ImGuiDockNodeFlags.CentralNode)))
                    last_focused_root_node.CentralNode = last_focused_node
                end

                IM_ASSERT(node.Windows.Size == 0)
                ImGui.DockNodeMoveChildNodes(node, payload_node)
            else
                local payload_dock_id = payload_node.ID
                ImGui.DockNodeMoveWindows(node, payload_node)
                DockSettingsRenameNodeReferences(payload_dock_id, node.ID)
            end
            ImGui.DockContextRemoveNode(ctx, payload_node, true)
        elseif payload_window then
            local payload_dock_id = payload_window.DockId
            node.VisibleWindow = payload_window
            ImGui.DockNodeAddWindow(node, payload_window, true)
            if payload_dock_id ~= 0 then
                DockSettingsRenameNodeReferences(payload_dock_id, node.ID)
            end
        end
    else
        node.WantHiddenTabBarUpdate = true
    end

    local tab_bar = node.TabBar
    if tab_bar then tab_bar.NextSelectedTabId = next_selected_id end
    ImGui.MarkIniSettingsDirty()
end

local function FixLargeWindowsWhenUndocking(size, ref_viewport)
    if ref_viewport == nil then return size end
    local max_size = ImTrunc(ref_viewport.WorkSize * 0.90)
    return ImVec2(ImMin(size.x, max_size.x), ImMin(size.y, max_size.y))
end

function ImGui.DockContextProcessUndockWindow(ctx, window, clear_persistent_docking_ref)
    if clear_persistent_docking_ref == nil then clear_persistent_docking_ref = true end -- C++ default argument
    if window.DockNode then
        ImGui.DockNodeRemoveWindow(window.DockNode, window, clear_persistent_docking_ref and 0 or window.DockId)
    else
        window.DockId = 0
    end
    window.Collapsed = false
    window.DockIsActive = false
    window.DockNodeIsVisible = false
    window.DockTabIsVisible = false
    local sz = FixLargeWindowsWhenUndocking(window.SizeFull, window.Viewport)
    ImVec2_Copy(window.Size, sz)
    ImVec2_Copy(window.SizeFull, sz)
    ImGui.MarkIniSettingsDirty()
end

function ImGui.DockContextProcessUndockNode(ctx, node)
    IM_ASSERT(node:IsLeafNode())
    IM_ASSERT(node.Windows.Size >= 1)

    if node:IsRootNode() or node:IsCentralNode() then
        local new_node = ImGui.DockContextAddNode(ctx, 0)
        new_node.Pos = ImVec2(node.Pos.x, node.Pos.y)
        new_node.Size = ImVec2(node.Size.x, node.Size.y)
        new_node.SizeRef = ImVec2(node.SizeRef.x, node.SizeRef.y)
        ImGui.DockNodeMoveWindows(new_node, node)
        DockSettingsRenameNodeReferences(node.ID, new_node.ID)
        node = new_node
    else
        IM_ASSERT(node.ParentNode.ChildNodes[0] == node or node.ParentNode.ChildNodes[1] == node)
        local index_in_parent = (node.ParentNode.ChildNodes[0] == node) and 0 or 1
        node.ParentNode.ChildNodes[index_in_parent] = nil
        ImGui.DockNodeTreeMerge(ctx, node.ParentNode, node.ParentNode.ChildNodes[bit32.bxor(index_in_parent, 1)])
        node.ParentNode.AuthorityForViewport = ImGuiDataAuthority.Window
        node.ParentNode = nil
    end
    for _, window in node.Windows:iter() do
        window.Flags = bit32.band(window.Flags, bit32.bnot(ImGuiWindowFlags.ChildWindow))
        if window.ParentWindow then window.ParentWindow.DC.ChildWindows:find_erase(window) end
        ImGui.UpdateWindowParentAndRootLinks(window, window.Flags, nil)
    end
    node.AuthorityForPos = ImGuiDataAuthority.DockNode
    node.AuthorityForSize = ImGuiDataAuthority.DockNode
    node.Size = FixLargeWindowsWhenUndocking(node.Size, node.Windows.Data[1].Viewport)
    node.WantMouseMove = true
    ImGui.MarkIniSettingsDirty()
end

--- @return bool ok, ImVec2? out_pos
function ImGui.DockContextCalcDropPosForDocking(target, target_node, payload_window, payload_node, split_dir, split_outer)
    if target ~= nil and target_node == nil then target_node = target.DockNode end
    if target_node and target_node.ParentNode == nil and target_node:IsCentralNode() and split_dir ~= ImGuiDir.None then
        split_outer = true
    end
    local split_data = ImGuiDockPreviewData()
    ImGui.DockNodePreviewDockSetup(target, target_node, payload_window, payload_node, split_data, false, split_outer)
    local r = split_data.DropRectsDraw[split_dir + 1]
    if IsRectInverted(r) then return false, nil end
    return true, r:GetCenter()
end

---------------------------------------------------------------------------------------
-- Docking: ImGuiDockNode
---------------------------------------------------------------------------------------

function ImGui.DockNodeGetTabOrder(window)
    local tab_bar = window.DockNode.TabBar
    if tab_bar == nil then return -1 end
    local tab = ImGui.TabBarFindTabByID(tab_bar, window.TabId)
    return tab and ImGui.TabBarGetTabOrder(tab_bar, tab) or -1
end

local function DockNodeHideWindowDuringHostWindowCreation(window)
    window.Hidden = true
    window.HiddenFramesCanSkipItems = window.Active and 1 or 2
end

function ImGui.DockNodeAddWindow(node, window, add_to_tab_bar)
    if window.DockNode then
        IM_ASSERT(window.DockNode.ID ~= node.ID)
        ImGui.DockNodeRemoveWindow(window.DockNode, window, 0)
    end
    IM_ASSERT(window.DockNode == nil or window.DockNodeAsHost == nil)

    if node.HostWindow == nil and node.Windows.Size == 1 and node.Windows.Data[1].WasActive == false then
        DockNodeHideWindowDuringHostWindowCreation(node.Windows.Data[1])
    end

    node.Windows:push_back(window)
    node.WantHiddenTabBarUpdate = true
    window.DockNode = node
    window.DockId = node.ID
    window.DockIsActive = (node.Windows.Size > 1)
    window.DockTabWantClose = false

    if node.HostWindow == nil and node:IsFloatingNode() then
        if node.AuthorityForPos == ImGuiDataAuthority.Auto then node.AuthorityForPos = ImGuiDataAuthority.Window end
        if node.AuthorityForSize == ImGuiDataAuthority.Auto then node.AuthorityForSize = ImGuiDataAuthority.Window end
        if node.AuthorityForViewport == ImGuiDataAuthority.Auto then node.AuthorityForViewport = ImGuiDataAuthority.Window end
    end

    if add_to_tab_bar then
        if node.TabBar == nil then
            ImGui.DockNodeAddTabBar(node)
            node.TabBar.SelectedTabId = node.SelectedTabId
            node.TabBar.NextSelectedTabId = node.SelectedTabId
            for n = 1, node.Windows.Size - 1 do
                ImGui.TabBarAddTab(node.TabBar, ImGuiTabItemFlags.None, node.Windows.Data[n])
            end
        end
        ImGui.TabBarAddTab(node.TabBar, ImGuiTabItemFlags.Unsorted, window)
    end

    ImGui.DockNodeUpdateVisibleFlag(node)

    if node.HostWindow then
        ImGui.UpdateWindowParentAndRootLinks(window, bit32.bor(window.Flags, ImGuiWindowFlags.ChildWindow), node.HostWindow)
    end
end

function ImGui.DockNodeRemoveWindow(node, window, save_dock_id)
    IM_ASSERT(window.DockNode == node)
    IM_ASSERT(save_dock_id == 0 or save_dock_id == node.ID)

    window.DockNode = nil
    window.DockIsActive = false
    window.DockTabWantClose = false
    window.DockId = save_dock_id
    window.Flags = bit32.band(window.Flags, bit32.bnot(ImGuiWindowFlags.ChildWindow))
    if window.ParentWindow then window.ParentWindow.DC.ChildWindows:find_erase(window) end
    ImGui.UpdateWindowParentAndRootLinks(window, window.Flags, nil)

    if node.HostWindow and node.HostWindow.ViewportOwned then
        window.Viewport = nil
        window.ViewportId = 0
        window.ViewportOwned = false
        window.Hidden = true
    end

    local idx = node.Windows:find_index(window)
    IM_ASSERT(idx ~= nil)
    node.Windows:erase(idx)
    if node.VisibleWindow == window then node.VisibleWindow = nil end

    node.WantHiddenTabBarUpdate = true
    if node.TabBar then
        ImGui.TabBarRemoveTab(node.TabBar, window.TabId)
        local tab_count_threshold_for_tab_bar = node:IsCentralNode() and 1 or 2
        if node.Windows.Size < tab_count_threshold_for_tab_bar then
            ImGui.DockNodeRemoveTabBar(node)
        end
    end
    if node.Windows.Size == 0 and not node:IsCentralNode() and not node:IsDockSpace() and window.DockId ~= node.ID then
        ImGui.DockContextRemoveNode(ImGui.GetCurrentContext(), node, true)
        return
    end

    if node.Windows.Size == 1 and not node:IsCentralNode() and node.HostWindow then
        local remaining_window = node.Windows.Data[1]
        remaining_window.Collapsed = node.HostWindow.Collapsed
    end

    ImGui.DockNodeUpdateVisibleFlag(node)
end

function ImGui.DockNodeMoveChildNodes(dst_node, src_node)
    IM_ASSERT(dst_node.Windows.Size == 0)
    dst_node.ChildNodes[0] = src_node.ChildNodes[0]
    dst_node.ChildNodes[1] = src_node.ChildNodes[1]
    if dst_node.ChildNodes[0] then dst_node.ChildNodes[0].ParentNode = dst_node end
    if dst_node.ChildNodes[1] then dst_node.ChildNodes[1].ParentNode = dst_node end
    dst_node.SplitAxis = src_node.SplitAxis
    dst_node.SizeRef = ImVec2(src_node.SizeRef.x, src_node.SizeRef.y)
    src_node.ChildNodes[0] = nil
    src_node.ChildNodes[1] = nil
end

function ImGui.DockNodeMoveWindows(dst_node, src_node)
    IM_ASSERT(src_node and dst_node and dst_node ~= src_node)
    local src_tab_bar = src_node.TabBar
    if src_tab_bar ~= nil then IM_ASSERT(src_node.Windows.Size <= src_node.TabBar.Tabs.Size) end

    local move_tab_bar = (src_tab_bar ~= nil) and (dst_node.TabBar == nil)
    if move_tab_bar then
        dst_node.TabBar = src_node.TabBar
        src_node.TabBar = nil
    end

    -- Snapshot: DockNodeAddWindow() won't touch src_node.Windows since window.DockNode is cleared first
    local windows = {}
    for i = 1, src_node.Windows.Size do windows[i] = src_node.Windows.Data[i] end
    for _, window in ipairs(windows) do
        window.DockNode = nil
        window.DockIsActive = false
        ImGui.DockNodeAddWindow(dst_node, window, not move_tab_bar)
    end
    src_node.Windows:clear()

    if not move_tab_bar and src_node.TabBar then
        if dst_node.TabBar then dst_node.TabBar.SelectedTabId = src_node.TabBar.SelectedTabId end
        ImGui.DockNodeRemoveTabBar(src_node)
    end
end

function ImGui.DockNodeApplyPosSizeToWindows(node)
    for _, window in node.Windows:iter() do
        ImGui.SetWindowPos(window, node.Pos, ImGuiCond.Always)
        ImGui.SetWindowSize(window, node.Size, ImGuiCond.Always)
    end
end

function ImGui.DockNodeHideHostWindow(node)
    if node.HostWindow then
        if node.HostWindow.DockNodeAsHost == node then node.HostWindow.DockNodeAsHost = nil end
        node.HostWindow = nil
    end
    if node.Windows.Size == 1 then
        node.VisibleWindow = node.Windows.Data[1]
        node.Windows.Data[1].DockIsActive = false
    end
    if node.TabBar then ImGui.DockNodeRemoveTabBar(node) end
end

local function DockNodeFindInfo(node, info)
    if node.Windows.Size > 0 then
        if info.FirstNodeWithWindows == nil then info.FirstNodeWithWindows = node end
        info.CountNodesWithWindows = info.CountNodesWithWindows + 1
    end
    if node:IsCentralNode() then
        IM_ASSERT(info.CentralNode == nil)
        IM_ASSERT(node:IsLeafNode(), "If you get this assert: please submit .ini file + repro of actions leading to this.")
        info.CentralNode = node
    end
    if info.CountNodesWithWindows > 1 and info.CentralNode ~= nil then return end
    if node.ChildNodes[0] then DockNodeFindInfo(node.ChildNodes[0], info) end
    if node.ChildNodes[1] then DockNodeFindInfo(node.ChildNodes[1], info) end
end

function ImGui.DockNodeFindWindowByID(node, id)
    IM_ASSERT(id ~= 0)
    for _, window in node.Windows:iter() do
        if window.ID == id then return window end
    end
    return nil
end

function ImGui.DockNodeUpdateFlagsAndCollapse(node)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(node.ParentNode == nil or node.ParentNode.ChildNodes[0] == node or node.ParentNode.ChildNodes[1] == node)

    if node.ParentNode then
        node.SharedFlags = bit32.band(node.ParentNode.SharedFlags, ImGuiDockNodeFlags.SharedFlagsInheritMask_)
    end

    node.HasCentralNodeChild = false
    if node.ChildNodes[0] then ImGui.DockNodeUpdateFlagsAndCollapse(node.ChildNodes[0]) end
    if node.ChildNodes[1] then ImGui.DockNodeUpdateFlagsAndCollapse(node.ChildNodes[1]) end

    node.LocalFlagsInWindows = ImGuiDockNodeFlags.None
    local window_n = 1
    while window_n <= node.Windows.Size do
        local window = node.Windows.Data[window_n]
        IM_ASSERT(window.DockNode == node)

        local node_was_active = (node.LastFrameActive + 1 == g.FrameCount)
        local remove = false
        remove = remove or (node_was_active and (window.WasActive == false))
        remove = remove or (node_was_active and (node.WantCloseAll or node.WantCloseTabId == window.TabId) and window.HasCloseButton and bit32.band(window.Flags, ImGuiWindowFlags.UnsavedDocument) == 0)
        remove = remove or window.DockTabWantClose
        if remove then
            window.DockTabWantClose = false
            if node.Windows.Size == 1 and not node:IsCentralNode() then
                ImGui.DockNodeHideHostWindow(node)
                node.State = ImGuiDockNodeState.HostWindowHiddenBecauseSingleWindow
                ImGui.DockNodeRemoveWindow(node, window, node.ID)
                return
            end
            ImGui.DockNodeRemoveWindow(node, window, node.ID)
        else
            node.LocalFlagsInWindows = bit32.bor(node.LocalFlagsInWindows, window.WindowClass.DockNodeFlagsOverrideSet)
            window_n = window_n + 1
        end
    end
    node:UpdateMergedFlags()

    local node_flags = node.MergedFlags
    if node.WantHiddenTabBarUpdate and node.Windows.Size == 1 and bit32.band(node_flags, ImGuiDockNodeFlags.AutoHideTabBar) ~= 0 and not node:IsHiddenTabBar() then
        node.WantHiddenTabBarToggle = true
    end
    node.WantHiddenTabBarUpdate = false

    if node.WantHiddenTabBarToggle and node.VisibleWindow and bit32.band(node.VisibleWindow.WindowClass.DockNodeFlagsOverrideSet, ImGuiDockNodeFlags.HiddenTabBar) ~= 0 then
        node.WantHiddenTabBarToggle = false
    end

    local prev_local_flags = node.LocalFlags
    if node.Windows.Size > 1 then
        node:SetLocalFlags(bit32.band(node.LocalFlags, bit32.bnot(ImGuiDockNodeFlags.HiddenTabBar)))
    elseif node.WantHiddenTabBarToggle then
        node:SetLocalFlags(bit32.bxor(node.LocalFlags, ImGuiDockNodeFlags.HiddenTabBar))
    end
    if bit32.band(bit32.bxor(node.LocalFlags, prev_local_flags), ImGuiDockNodeFlags.SavedFlagsMask_) ~= 0 then
        ImGui.MarkIniSettingsDirty()
    end
    node.WantHiddenTabBarToggle = false

    ImGui.DockNodeUpdateVisibleFlag(node)
end

function ImGui.DockNodeUpdateHasCentralNodeChild(node)
    node.HasCentralNodeChild = false
    if node.ChildNodes[0] then ImGui.DockNodeUpdateHasCentralNodeChild(node.ChildNodes[0]) end
    if node.ChildNodes[1] then ImGui.DockNodeUpdateHasCentralNodeChild(node.ChildNodes[1]) end
    if node:IsRootNode() then
        local mark_node = node.CentralNode
        while mark_node do
            mark_node.HasCentralNodeChild = true
            mark_node = mark_node.ParentNode
        end
    end
end

function ImGui.DockNodeUpdateVisibleFlag(node)
    local is_visible = (node.ParentNode == nil) and node:IsDockSpace() or node:IsCentralNode()
    is_visible = is_visible or (node.Windows.Size > 0)
    is_visible = is_visible or (node.ChildNodes[0] ~= nil and node.ChildNodes[0].IsVisible)
    is_visible = is_visible or (node.ChildNodes[1] ~= nil and node.ChildNodes[1].IsVisible)
    node.IsVisible = is_visible and true or false
end

function ImGui.DockNodeStartMouseMovingWindow(node, window)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(node.WantMouseMove == true)
    ImGui.StartMouseMovingWindow(window)
    ImVec2_Copy(g.ActiveIdClickOffset, g.IO.MouseClickedPos[0] - node.Pos)
    g.MovingWindow = window
    node.WantMouseMove = false
end

function ImGui.DockNodeUpdateForRootNode(node)
    ImGui.DockNodeUpdateFlagsAndCollapse(node)

    local info = { CentralNode = nil, FirstNodeWithWindows = nil, CountNodesWithWindows = 0 }
    DockNodeFindInfo(node, info)
    node.CentralNode = info.CentralNode
    node.OnlyNodeWithWindows = (info.CountNodesWithWindows == 1) and info.FirstNodeWithWindows or nil
    node.CountNodeWithWindows = info.CountNodesWithWindows
    if node.LastFocusedNodeId == 0 and info.FirstNodeWithWindows ~= nil then
        node.LastFocusedNodeId = info.FirstNodeWithWindows.ID
    end

    local first_node_with_windows = info.FirstNodeWithWindows
    if first_node_with_windows then
        node.WindowClass = first_node_with_windows.Windows.Data[1].WindowClass
        for n = 2, first_node_with_windows.Windows.Size do
            if first_node_with_windows.Windows.Data[n].WindowClass.DockingAllowUnclassed == false then
                node.WindowClass = first_node_with_windows.Windows.Data[n].WindowClass
                break
            end
        end
    end

    local mark_node = node.CentralNode
    while mark_node do
        mark_node.HasCentralNodeChild = true
        mark_node = mark_node.ParentNode
    end
end

local function DockNodeSetupHostWindow(node, host_window)
    if node.HostWindow and node.HostWindow ~= host_window and node.HostWindow.DockNodeAsHost == node then
        node.HostWindow.DockNodeAsHost = nil
    end
    host_window.DockNodeAsHost = node
    node.HostWindow = host_window
end

function ImGui.DockNodeUpdate(node)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(node.LastFrameActive ~= g.FrameCount)
    node.LastFrameAlive = g.FrameCount
    node.IsBgDrawnThisFrame = false

    node.CentralNode = nil
    node.OnlyNodeWithWindows = nil
    if node:IsRootNode() then ImGui.DockNodeUpdateForRootNode(node) end

    if node.TabBar and node:IsNoTabBar() then ImGui.DockNodeRemoveTabBar(node) end

    local want_to_hide_host_window = false
    if node:IsFloatingNode() then
        if node.Windows.Size <= 1 and node:IsLeafNode() then
            if not g.IO.ConfigDockingAlwaysTabBar and (node.Windows.Size == 0 or not node.Windows.Data[1].WindowClass.DockingAlwaysTabBar) then
                want_to_hide_host_window = true
            end
        end
        if node.CountNodeWithWindows == 0 then want_to_hide_host_window = true end
    end
    if want_to_hide_host_window then
        if node.Windows.Size == 1 then
            local single_window = node.Windows.Data[1]
            node.Pos = ImVec2(single_window.Pos.x, single_window.Pos.y)
            node.Size = ImVec2(single_window.SizeFull.x, single_window.SizeFull.y)
            node.AuthorityForPos = ImGuiDataAuthority.Window
            node.AuthorityForSize = ImGuiDataAuthority.Window
            node.AuthorityForViewport = ImGuiDataAuthority.Window

            if node.HostWindow and g.NavWindow == node.HostWindow then
                ImGui.FocusWindow(single_window)
            end
            if node.HostWindow then
                single_window.Viewport = node.HostWindow.Viewport
                single_window.ViewportId = node.HostWindow.ViewportId
            end
            node.RefViewportId = single_window.ViewportId or 0
        end

        ImGui.DockNodeHideHostWindow(node)
        node.State = ImGuiDockNodeState.HostWindowHiddenBecauseSingleWindow
        node.WantCloseAll = false
        node.WantCloseTabId = 0
        node.HasCloseButton = false
        node.HasWindowMenuButton = false
        node.LastFrameActive = g.FrameCount

        if node.WantMouseMove and node.Windows.Size == 1 then
            ImGui.DockNodeStartMouseMovingWindow(node, node.Windows.Data[1])
        end
        return
    end

    if node.IsVisible and node.HostWindow == nil and node:IsFloatingNode() and node:IsLeafNode() then
        IM_ASSERT(node.Windows.Size > 0)
        local ref_window = nil
        if node.SelectedTabId ~= 0 then ref_window = ImGui.DockNodeFindWindowByID(node, node.SelectedTabId) end
        if ref_window == nil then ref_window = node.Windows.Data[1] end
        if ref_window.AutoFitFramesX > 0 or ref_window.AutoFitFramesY > 0 then
            node.State = ImGuiDockNodeState.HostWindowHiddenBecauseWindowsAreResizing
            return
        end
    end

    local node_flags = node.MergedFlags

    node.HasWindowMenuButton = (node.Windows.Size > 0) and bit32.band(node_flags, ImGuiDockNodeFlags.NoWindowMenuButton) == 0
    node.HasCloseButton = false
    for _, window in node.Windows:iter() do
        node.HasCloseButton = node.HasCloseButton or window.HasCloseButton
        window.DockIsActive = (node.Windows.Size > 1)
    end
    if bit32.band(node_flags, ImGuiDockNodeFlags.NoCloseButton) ~= 0 or not g.Style.DockingNodeHasCloseButton then
        node.HasCloseButton = false
    end

    local host_window = nil
    local beginned_into_host_window = false
    if node:IsDockSpace() then
        IM_ASSERT(node.HostWindow)
        host_window = node.HostWindow
    else
        if node:IsRootNode() and node.IsVisible then
            local ref_window = (node.Windows.Size > 0) and node.Windows.Data[1] or nil

            if node.AuthorityForPos == ImGuiDataAuthority.Window and ref_window then
                ImGui.SetNextWindowPos(ref_window.Pos)
            elseif node.AuthorityForPos == ImGuiDataAuthority.DockNode then
                ImGui.SetNextWindowPos(node.Pos)
            end

            if node.AuthorityForSize == ImGuiDataAuthority.Window and ref_window then
                ImGui.SetNextWindowSize(ref_window.SizeFull)
            elseif node.AuthorityForSize == ImGuiDataAuthority.DockNode then
                ImGui.SetNextWindowSize(node.Size)
            end

            if node.AuthorityForSize == ImGuiDataAuthority.Window and ref_window then
                ImGui.SetNextWindowCollapsed(ref_window.Collapsed)
            end

            ImGui.SetNextWindowClass(node.WindowClass)

            local window_label = DockNodeGetHostWindowTitle(node)
            local window_flags = bit32.bor(ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse, ImGuiWindowFlags.DockNodeHost)
            window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoFocusOnAppearing)
            window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoSavedSettings, ImGuiWindowFlags.NoNavFocus, ImGuiWindowFlags.NoCollapse)
            window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoTitleBar)

            ImGui.SetNextWindowBgAlpha(0.0)
            ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(0, 0))
            ImGui.Begin(window_label, nil, window_flags)
            ImGui.PopStyleVar()
            beginned_into_host_window = true

            host_window = g.CurrentWindow
            DockNodeSetupHostWindow(node, host_window)
            ImVec2_Copy(host_window.DC.CursorPos, host_window.Pos)
            node.Pos = ImVec2(host_window.Pos.x, host_window.Pos.y)
            node.Size = ImVec2(host_window.Size.x, host_window.Size.y)

            if node.HostWindow.Appearing then ImGui.BringWindowToDisplayFront(node.HostWindow) end

            node.AuthorityForPos = ImGuiDataAuthority.Auto
            node.AuthorityForSize = ImGuiDataAuthority.Auto
            node.AuthorityForViewport = ImGuiDataAuthority.Auto
        elseif node.ParentNode then
            host_window = node.ParentNode.HostWindow
            node.HostWindow = host_window
            node.AuthorityForPos = ImGuiDataAuthority.Auto
            node.AuthorityForSize = ImGuiDataAuthority.Auto
            node.AuthorityForViewport = ImGuiDataAuthority.Auto
        end
        if node.WantMouseMove and node.HostWindow then
            ImGui.DockNodeStartMouseMovingWindow(node, node.HostWindow)
        end
    end
    node.RefViewportId = 0

    if node:IsSplitNode() then IM_ASSERT(node.TabBar == nil) end
    if node:IsRootNode() then
        local p_window = g.NavWindow and g.NavWindow.RootWindow or nil
        while p_window ~= nil and p_window.DockNode ~= nil do
            local p_node = ImGui.DockNodeGetRootNode(p_window.DockNode)
            if p_node == node then
                node.LastFocusedNodeId = p_window.DockNode.ID
                break
            end
            p_window = p_node.HostWindow and p_node.HostWindow.RootWindow or nil
        end
    end

    local central_node = node.CentralNode
    local central_node_hole = node:IsRootNode() and host_window ~= nil and bit32.band(node_flags, ImGuiDockNodeFlags.PassthruCentralNode) ~= 0 and central_node ~= nil and central_node:IsEmpty()
    local central_node_hole_register_hit_test_hole = central_node_hole
    if central_node_hole then
        local payload = ImGui.GetDragDropPayload()
        if payload and ImGuiPayload_IsDataType(payload, IMGUI_PAYLOAD_TYPE_WINDOW) and ImGui.DockNodeIsDropAllowed(host_window, payload.Data) then
            central_node_hole_register_hit_test_hole = false
        end
    end
    if central_node_hole_register_hit_test_hole then
        IM_ASSERT(node:IsDockSpace())
        local root_node = ImGui.DockNodeGetRootNode(central_node)
        local root_rect = ImRect(root_node.Pos, root_node.Pos + root_node.Size)
        local hole_rect = ImRect(central_node.Pos, central_node.Pos + central_node.Size)
        if hole_rect.Min.x > root_rect.Min.x then hole_rect.Min.x = hole_rect.Min.x + g.WindowsBorderHoverPadding end
        if hole_rect.Max.x < root_rect.Max.x then hole_rect.Max.x = hole_rect.Max.x - g.WindowsBorderHoverPadding end
        if hole_rect.Min.y > root_rect.Min.y then hole_rect.Min.y = hole_rect.Min.y + g.WindowsBorderHoverPadding end
        if hole_rect.Max.y < root_rect.Max.y then hole_rect.Max.y = hole_rect.Max.y - g.WindowsBorderHoverPadding end
        if central_node_hole and not IsRectInverted(hole_rect) then
            ImGui.SetWindowHitTestHole(host_window, hole_rect.Min, hole_rect.Max - hole_rect.Min)
            if host_window.ParentWindow then
                ImGui.SetWindowHitTestHole(host_window.ParentWindow, hole_rect.Min, hole_rect.Max - hole_rect.Min)
            end
        end
    end

    if node:IsRootNode() and host_window then
        ImGui.DockNodeTreeUpdatePosSize(node, host_window.Pos, host_window.Size)
        ImGui.PushStyleColor(ImGuiCol.Separator, g.Style.Colors[ImGuiCol.Border])
        ImGui.PushStyleColor(ImGuiCol.SeparatorActive, g.Style.Colors[ImGuiCol.ResizeGripActive])
        ImGui.PushStyleColor(ImGuiCol.SeparatorHovered, g.Style.Colors[ImGuiCol.ResizeGripHovered])
        ImGui.DockNodeTreeUpdateSplitter(node)
        ImGui.PopStyleColor(3)
    end

    if host_window and node:IsEmpty() and node.IsVisible then
        host_window.DrawList:ChannelsSetCurrent(DOCKING_HOST_DRAW_CHANNEL_BG)
        node.LastBgColor = (bit32.band(node_flags, ImGuiDockNodeFlags.PassthruCentralNode) ~= 0) and 0 or ImGui.GetColorU32(ImGuiCol.DockingEmptyBg)
        if node.LastBgColor ~= 0 then
            host_window.DrawList:AddRectFilled(node.Pos, node.Pos + node.Size, node.LastBgColor)
        end
        node.IsBgDrawnThisFrame = true
    end

    local render_dockspace_bg = node:IsRootNode() and host_window ~= nil and bit32.band(node_flags, ImGuiDockNodeFlags.PassthruCentralNode) ~= 0
    if render_dockspace_bg and node.IsVisible then
        host_window.DrawList:ChannelsSetCurrent(DOCKING_HOST_DRAW_CHANNEL_BG)
        if central_node_hole then
            ImGui.RenderRectFilledWithHole(host_window.DrawList, node:Rect(), central_node:Rect(), ImGui.GetColorU32(ImGuiCol.WindowBg), 0.0)
        else
            host_window.DrawList:AddRectFilled(node.Pos, node.Pos + node.Size, ImGui.GetColorU32(ImGuiCol.WindowBg), 0.0)
        end
    end

    if host_window then host_window.DrawList:ChannelsSetCurrent(DOCKING_HOST_DRAW_CHANNEL_FG) end
    if host_window and node.Windows.Size > 0 then
        ImGui.DockNodeUpdateTabBar(node, host_window)
    else
        node.WantCloseAll = false
        node.WantCloseTabId = 0
        node.IsFocused = false
    end
    if node.TabBar and node.TabBar.SelectedTabId ~= 0 then
        node.SelectedTabId = node.TabBar.SelectedTabId
    elseif node.Windows.Size > 0 then
        node.SelectedTabId = node.Windows.Data[1].TabId
    end

    if host_window and node.IsVisible then
        if node:IsRootNode() and (g.MovingWindow == nil or g.MovingWindow.RootWindowDockTree ~= host_window) then
            ImGui.BeginDockableDragDropTarget(host_window)
        end
    end

    node.LastFrameActive = g.FrameCount

    if host_window then
        if node.ChildNodes[0] then ImGui.DockNodeUpdate(node.ChildNodes[0]) end
        if node.ChildNodes[1] then ImGui.DockNodeUpdate(node.ChildNodes[1]) end
        if node:IsRootNode() then ImGui.RenderWindowOuterBorders(host_window) end
    end

    if beginned_into_host_window then ImGui.End() end
end

local GWindowDockStyleColors = {
    [0] = ImGuiCol.Text, ImGuiCol.TabHovered, ImGuiCol.Tab, ImGuiCol.TabSelected, ImGuiCol.TabSelectedOverline,
    ImGuiCol.TabDimmed, ImGuiCol.TabDimmedSelected, ImGuiCol.TabDimmedSelectedOverline, ImGuiCol.UnsavedMarker,
}
ImGui.GWindowDockStyleColors = GWindowDockStyleColors

local function TabItemComparerByDockOrder(ta, tb)
    local a, b = ta.Window, tb.Window
    local ao = (a.DockOrder == -1) and INT_MAX or a.DockOrder
    local bo = (b.DockOrder == -1) and INT_MAX or b.DockOrder
    if ao ~= bo then return ao < bo end
    return a.BeginOrderWithinContext < b.BeginOrderWithinContext
end

function ImGui.DockNodeWindowMenuHandler_Default(ctx, node, tab_bar)
    if tab_bar.Tabs.Size == 1 then
        if ImGui.MenuItem(ImGui.LocalizeGetMsg(ImGuiLocKey.DockingHideTabBar), nil, node:IsHiddenTabBar()) then
            node.WantHiddenTabBarToggle = true
        end
    else
        for tab_n = 1, tab_bar.Tabs.Size do
            local tab = tab_bar.Tabs.Data[tab_n]
            if bit32.band(tab.Flags, ImGuiTabItemFlags.Button) == 0 then
                if ImGui.Selectable(ImGui.TabBarGetTabName(tab_bar, tab), tab.ID == tab_bar.SelectedTabId) then
                    ImGui.TabBarQueueFocus(tab_bar, tab)
                end
                ImGui.SameLine()
                ImGui.Text("   ")
            end
        end
    end
end

function ImGui.DockNodeWindowMenuUpdate(node, tab_bar)
    local g = ImGui.GetCurrentContext()
    if g.Style.WindowMenuButtonPosition == ImGuiDir.Left then
        ImGui.SetNextWindowPos(ImVec2(node.Pos.x, node.Pos.y + ImGui.GetFrameHeight()), ImGuiCond.Always, ImVec2(0.0, 0.0))
    else
        ImGui.SetNextWindowPos(ImVec2(node.Pos.x + node.Size.x, node.Pos.y + ImGui.GetFrameHeight()), ImGuiCond.Always, ImVec2(1.0, 0.0))
    end
    if ImGui.BeginPopup("#WindowMenu") then
        node.IsFocused = true
        g.DockNodeWindowMenuHandler(g, node, tab_bar)
        ImGui.EndPopup()
    end
end

function ImGui.DockNodeBeginAmendTabBar(node)
    if node.TabBar == nil or node.HostWindow == nil then return false end
    if bit32.band(node.MergedFlags, ImGuiDockNodeFlags.KeepAliveOnly) ~= 0 then return false end
    if node.TabBar.ID == 0 then return false end
    ImGui.Begin(node.HostWindow.Name)
    ImGui.PushOverrideID(node.ID)
    local ret = ImGui.BeginTabBarEx(node.TabBar, node.TabBar.BarRect, node.TabBar.Flags)
    IM_ASSERT(ret)
    return true
end

function ImGui.DockNodeEndAmendTabBar()
    ImGui.EndTabBar()
    ImGui.PopID()
    ImGui.End()
end

local function IsDockNodeTitleBarHighlighted(node, root_node)
    local g = ImGui.GetCurrentContext()
    if g.NavWindowingTarget then
        return g.NavWindowingTarget.DockNode == node
    end
    if g.NavWindow and root_node.LastFocusedNodeId == node.ID then
        local parent_window = g.NavWindow.RootWindow
        while bit32.band(parent_window.Flags, ImGuiWindowFlags.ChildMenu) ~= 0 do
            parent_window = parent_window.ParentWindow.RootWindow
        end
        local parent_node = parent_window.DockNodeAsHost or parent_window.DockNode
        while parent_node ~= nil do
            parent_node = ImGui.DockNodeGetRootNode(parent_node)
            if parent_node == root_node then return true end
            parent_node = parent_node.HostWindow and parent_node.HostWindow.RootWindow.DockNode or nil
        end
    end
    return false
end

function ImGui.DockNodeUpdateTabBar(node, host_window)
    local g = ImGui.GetCurrentContext()
    local style = g.Style

    local node_was_active = (node.LastFrameActive + 1 == g.FrameCount)
    node.WantCloseAll = false
    node.WantCloseTabId = 0

    local is_focused = false
    local root_node = ImGui.DockNodeGetRootNode(node)
    if IsDockNodeTitleBarHighlighted(node, root_node) then is_focused = true end

    if node:IsHiddenTabBar() or node:IsNoTabBar() then
        node.VisibleWindow = (node.Windows.Size > 0) and node.Windows.Data[1] or nil
        node.IsFocused = is_focused
        if is_focused then node.LastFrameFocused = g.FrameCount end
        if node.VisibleWindow then
            if is_focused or root_node.VisibleWindow == nil then root_node.VisibleWindow = node.VisibleWindow end
            if node.TabBar then node.TabBar.VisibleTabId = node.VisibleWindow.TabId end
        end
        return
    end

    local backup_skip_item = host_window.SkipItems
    if not node:IsDockSpace() then
        host_window.SkipItems = false
        host_window.DC.NavLayerCurrent = ImGuiNavLayer.Menu
    end

    ImGui.PushOverrideID(node.ID)
    local tab_bar = node.TabBar
    local tab_bar_is_recreated = (tab_bar == nil)
    if tab_bar == nil then
        ImGui.DockNodeAddTabBar(node)
        tab_bar = node.TabBar
    end

    local focus_tab_id = 0
    node.IsFocused = is_focused

    local node_flags = node.MergedFlags
    local has_window_menu_button = bit32.band(node_flags, ImGuiDockNodeFlags.NoWindowMenuButton) == 0 and (style.WindowMenuButtonPosition ~= ImGuiDir.None)

    if has_window_menu_button and ImGui.IsPopupOpen("#WindowMenu") then
        local next_selected_tab_id = tab_bar.NextSelectedTabId
        ImGui.DockNodeWindowMenuUpdate(node, tab_bar)
        if tab_bar.NextSelectedTabId ~= 0 and tab_bar.NextSelectedTabId ~= next_selected_tab_id then
            focus_tab_id = tab_bar.NextSelectedTabId
        end
        is_focused = is_focused or node.IsFocused
    end

    local title_bar_rect, tab_bar_rect, window_menu_button_pos, close_button_pos = ImGui.DockNodeCalcTabBarLayout(node)

    local tabs_count_old = tab_bar.Tabs.Size
    for window_n = 1, node.Windows.Size do
        local window = node.Windows.Data[window_n]
        if ImGui.TabBarFindTabByID(tab_bar, window.TabId) == nil then
            ImGui.TabBarAddTab(tab_bar, ImGuiTabItemFlags.Unsorted, window)
        end
    end

    if is_focused then node.LastFrameFocused = g.FrameCount end
    local title_bar_col = ImGui.GetColorU32(host_window.Collapsed and ImGuiCol.TitleBgCollapsed or (is_focused and ImGuiCol.TitleBgActive or ImGuiCol.TitleBg))
    local rounding_flags = ImGui.CalcRoundingFlagsForRectInRect(title_bar_rect, host_window:Rect(), g.Style.DockingSeparatorSize)
    host_window.DrawList:AddRectFilled(title_bar_rect.Min, title_bar_rect.Max, title_bar_col, host_window.WindowRounding, rounding_flags)

    if has_window_menu_button then
        if ImGui.CollapseButton(host_window:GetID("#COLLAPSE"), window_menu_button_pos, node) then
            ImGui.OpenPopup("#WindowMenu")
        end
        if ImGui.IsItemActive() then focus_tab_id = tab_bar.SelectedTabId end
        if ImGui.IsItemHovered(bit32.bor(ImGuiHoveredFlags.ForTooltip, ImGuiHoveredFlags.DelayNormal)) and g.HoveredIdTimer > 0.5 then
            ImGui.SetTooltip("%s", ImGui.LocalizeGetMsg(ImGuiLocKey.DockingDragToUndockOrMoveNode))
        end
    end

    local tabs_unsorted_start = tab_bar.Tabs.Size -- 0-based
    local tab_n = tab_bar.Tabs.Size - 1
    while tab_n >= 0 and bit32.band(tab_bar.Tabs.Data[tab_n + 1].Flags, ImGuiTabItemFlags.Unsorted) ~= 0 do
        local t = tab_bar.Tabs.Data[tab_n + 1]
        t.Flags = bit32.band(t.Flags, bit32.bnot(ImGuiTabItemFlags.Unsorted))
        tabs_unsorted_start = tab_n
        tab_n = tab_n - 1
    end
    if tab_bar.Tabs.Size > tabs_unsorted_start + 1 then
        local slice = {}
        for i = tabs_unsorted_start + 1, tab_bar.Tabs.Size do slice[#slice + 1] = tab_bar.Tabs.Data[i] end
        table.sort(slice, TabItemComparerByDockOrder)
        for i, t in ipairs(slice) do tab_bar.Tabs.Data[tabs_unsorted_start + i] = t end
    end

    if g.NavWindow and g.NavWindow.RootWindow.DockNode == node then
        tab_bar.SelectedTabId = g.NavWindow.RootWindow.TabId
    end

    if tab_bar_is_recreated and ImGui.TabBarFindTabByID(tab_bar, node.SelectedTabId) ~= nil then
        tab_bar.SelectedTabId = node.SelectedTabId
        tab_bar.NextSelectedTabId = node.SelectedTabId
    elseif tab_bar.Tabs.Size > tabs_count_old then
        tab_bar.SelectedTabId = tab_bar.Tabs.Data[tab_bar.Tabs.Size].Window.TabId
        tab_bar.NextSelectedTabId = tab_bar.SelectedTabId
    end

    local tab_bar_flags = bit32.bor(ImGuiTabBarFlags.Reorderable, ImGuiTabBarFlags.AutoSelectNewTabs)
    tab_bar_flags = bit32.bor(tab_bar_flags, ImGuiTabBarFlags.SaveSettings, ImGuiTabBarFlags.DockNode)
    tab_bar_flags = bit32.bor(tab_bar_flags, ImGuiTabBarFlags.FittingPolicyMixed)
    tab_bar_flags = bit32.bor(tab_bar_flags, ImGuiTabBarFlags.DrawSelectedOverline)
    if not host_window.Collapsed and is_focused then
        tab_bar_flags = bit32.bor(tab_bar_flags, ImGuiTabBarFlags.IsFocused)
    end
    tab_bar.ID = node.ID
    tab_bar.SeparatorMinX = node.Pos.x + host_window.WindowBorderSize
    tab_bar.SeparatorMaxX = node.Pos.x + node.Size.x - host_window.WindowBorderSize
    ImGui.BeginTabBarEx(tab_bar, tab_bar_rect, tab_bar_flags)

    local backup_style_cols = {}
    for color_n = 0, ImGuiWindowDockStyleCol.COUNT - 1 do
        local c = g.Style.Colors[GWindowDockStyleColors[color_n]]
        backup_style_cols[color_n] = ImVec4(c.x, c.y, c.z, c.w)
    end

    node.VisibleWindow = nil
    for window_n = 1, node.Windows.Size do
        local window = node.Windows.Data[window_n]
        if not (window.LastFrameActive + 1 < g.FrameCount and node_was_active) then
            local tab_item_flags = 0
            tab_item_flags = bit32.bor(tab_item_flags, window.WindowClass.TabItemFlagsOverrideSet or 0)
            if bit32.band(window.Flags, ImGuiWindowFlags.UnsavedDocument) ~= 0 then
                tab_item_flags = bit32.bor(tab_item_flags, ImGuiTabItemFlags.UnsavedDocument)
            end
            if bit32.band(tab_bar.Flags, ImGuiTabBarFlags.NoCloseWithMiddleMouseButton) ~= 0 then
                tab_item_flags = bit32.bor(tab_item_flags, ImGuiTabItemFlags.NoCloseWithMiddleMouseButton)
            end

            for color_n = 0, ImGuiWindowDockStyleCol.COUNT - 1 do
                ImVec4_Copy(g.Style.Colors[GWindowDockStyleColors[color_n]], ImGui.ColorConvertU32ToFloat4(window.DockStyle.Colors[color_n]))
            end

            local _, tab_open = ImGui.TabItemEx(tab_bar, window.Name, window.HasCloseButton and true or nil, tab_item_flags, window)
            if tab_open == false then node.WantCloseTabId = window.TabId end
            if tab_bar.VisibleTabId == window.TabId then node.VisibleWindow = window end

            window.DC.DockTabItemStatusFlags = g.LastItemData.StatusFlags
            window.DC.DockTabItemRect = ImRect(g.LastItemData.Rect.Min, g.LastItemData.Rect.Max)

            if g.NavWindow and g.NavWindow.RootWindow == window and bit32.band(window.DC.NavLayersActiveMask, bit32.lshift(1, ImGuiNavLayer.Menu)) == 0 then
                host_window.NavLastIds[1] = window.TabId
            end
        end
    end

    for color_n = 0, ImGuiWindowDockStyleCol.COUNT - 1 do
        ImVec4_Copy(g.Style.Colors[GWindowDockStyleColors[color_n]], backup_style_cols[color_n])
    end

    if node.VisibleWindow then
        if is_focused or root_node.VisibleWindow == nil then root_node.VisibleWindow = node.VisibleWindow end
    end

    local close_button_is_enabled = node.HasCloseButton and node.VisibleWindow and node.VisibleWindow.HasCloseButton
    local close_button_is_visible = node.HasCloseButton
    if close_button_is_visible then
        if not close_button_is_enabled then
            ImGui.PushItemFlag(ImGuiItemFlags.Disabled, true)
            local tc = style.Colors[ImGuiCol.Text]
            ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(tc.x, tc.y, tc.z, tc.w * 0.4))
        end
        if ImGui.CloseButton(host_window:GetID("#CLOSE"), close_button_pos) then
            node.WantCloseAll = true
            for n = 1, tab_bar.Tabs.Size do ImGui.TabBarCloseTab(tab_bar, tab_bar.Tabs.Data[n]) end
        end
        if not close_button_is_enabled then
            ImGui.PopStyleColor()
            ImGui.PopItemFlag()
        end
    end

    local title_bar_id = host_window:GetID("#TITLEBAR")
    if g.HoveredId == 0 or g.HoveredId == title_bar_id or g.ActiveId == title_bar_id then
        ImGui.KeepAliveID(title_bar_id)
        local _, _, held = ImGui.ButtonBehavior(title_bar_rect, title_bar_id, ImGuiButtonFlags.AllowOverlap)
        if g.HoveredId == title_bar_id then g.LastItemData.ID = title_bar_id end
        if held then
            if ImGui.IsMouseClicked(0) then focus_tab_id = tab_bar.SelectedTabId end
            local tab = ImGui.TabBarFindTabByID(tab_bar, tab_bar.SelectedTabId)
            if tab then
                ImGui.StartMouseMovingWindowOrNode(tab.Window or node.HostWindow, node, false)
            end
        end
    end

    if tab_bar.NextSelectedTabId ~= 0 then focus_tab_id = tab_bar.NextSelectedTabId end

    if focus_tab_id ~= 0 then
        local tab = ImGui.TabBarFindTabByID(tab_bar, focus_tab_id)
        if tab and tab.Window then
            ImGui.FocusWindow(tab.Window)
            if g.NavId == 0 then ImGui.NavInitWindow(tab.Window, false) end
        end
    end

    ImGui.EndTabBar()
    ImGui.PopID()

    if not node:IsDockSpace() then
        host_window.DC.NavLayerCurrent = ImGuiNavLayer.Main
        host_window.SkipItems = backup_skip_item
    end
end

function ImGui.DockNodeAddTabBar(node)
    IM_ASSERT(node.TabBar == nil)
    node.TabBar = ImGuiTabBar()
end

function ImGui.DockNodeRemoveTabBar(node)
    if node.TabBar == nil then return end
    node.TabBar = nil
end
local function DockNodeIsDropAllowedOne(payload, host_window)
    if host_window.DockNodeAsHost and host_window.DockNodeAsHost:IsDockSpace() and payload.BeginOrderWithinContext < host_window.BeginOrderWithinContext then
        return false
    end

    local host_class = host_window.DockNodeAsHost and host_window.DockNodeAsHost.WindowClass or host_window.WindowClass
    local payload_class = payload.WindowClass
    if host_class.ClassId ~= payload_class.ClassId then
        local pass = false
        if host_class.ClassId ~= 0 and host_class.DockingAllowUnclassed and payload_class.ClassId == 0 then pass = true end
        if payload_class.ClassId ~= 0 and payload_class.DockingAllowUnclassed and host_class.ClassId == 0 then pass = true end
        if not pass then return false end
    end

    local g = ImGui.GetCurrentContext()
    for i = g.OpenPopupStack.Size, 1, -1 do
        local popup_window = g.OpenPopupStack.Data[i].Window
        if popup_window and ImGui.IsWindowWithinBeginStackOf(payload, popup_window) then
            return false
        end
    end
    return true
end

function ImGui.DockNodeIsDropAllowed(host_window, root_payload)
    if root_payload.DockNodeAsHost and root_payload.DockNodeAsHost:IsSplitNode() then return true end
    local payload_count = root_payload.DockNodeAsHost and root_payload.DockNodeAsHost.Windows.Size or 1
    for payload_n = 1, payload_count do
        local payload = root_payload.DockNodeAsHost and root_payload.DockNodeAsHost.Windows.Data[payload_n] or root_payload
        if DockNodeIsDropAllowedOne(payload, host_window) then return true end
    end
    return false
end

--- @return ImRect title_rect, ImRect tab_bar_rect, ImVec2 window_menu_button_pos, ImVec2? close_button_pos
function ImGui.DockNodeCalcTabBarLayout(node)
    local g = ImGui.GetCurrentContext()
    local style = g.Style

    local r = ImRect(node.Pos.x, node.Pos.y, node.Pos.x + node.Size.x, node.Pos.y + g.FontSize + g.Style.FramePadding.y * 2.0)
    local out_title_rect = ImRect(r.Min, r.Max)

    r.Min.x = r.Min.x + style.WindowBorderSize
    r.Max.x = r.Max.x - style.WindowBorderSize

    local button_sz = g.FontSize
    r.Min.x = r.Min.x + style.FramePadding.x
    r.Max.x = r.Max.x - style.FramePadding.x
    local window_menu_button_pos = ImVec2(r.Min.x, r.Min.y + style.FramePadding.y)
    local out_close_button_pos = nil
    if node.HasCloseButton then
        out_close_button_pos = ImVec2(r.Max.x - button_sz, r.Min.y + style.FramePadding.y)
        r.Max.x = r.Max.x - (button_sz + style.ItemInnerSpacing.x)
    end
    if node.HasWindowMenuButton and style.WindowMenuButtonPosition == ImGuiDir.Left then
        r.Min.x = r.Min.x + button_sz + style.ItemInnerSpacing.x
    elseif node.HasWindowMenuButton and style.WindowMenuButtonPosition == ImGuiDir.Right then
        window_menu_button_pos = ImVec2(r.Max.x - button_sz, r.Min.y + style.FramePadding.y)
        r.Max.x = r.Max.x - (button_sz + style.ItemInnerSpacing.x)
    end
    return out_title_rect, r, window_menu_button_pos, out_close_button_pos
end

--- Modifies pos_old/size_old/pos_new/size_new in place (ImVec2 tables)
function ImGui.DockNodeCalcSplitRects(pos_old, size_old, pos_new, size_new, dir, size_new_desired)
    local g = ImGui.GetCurrentContext()
    local dock_spacing = g.Style.ItemInnerSpacing.x
    local axis = (dir == ImGuiDir.Left or dir == ImGuiDir.Right) and ImGuiAxis.X or ImGuiAxis.Y
    local a, o = axis, 3 - axis -- the port's ImGuiAxis is 1-based (X=1,Y=2): it is directly the ImVec2 index
    pos_new[o] = pos_old[o]
    size_new[o] = size_old[o]

    local w_avail = size_old[a] - dock_spacing
    if size_new_desired[a] > 0.0 and size_new_desired[a] <= w_avail * 0.5 then
        size_new[a] = size_new_desired[a]
        size_old[a] = IM_TRUNC(w_avail - size_new[a])
    else
        size_new[a] = IM_TRUNC(w_avail * 0.5)
        size_old[a] = IM_TRUNC(w_avail - size_new[a])
    end

    if dir == ImGuiDir.Right or dir == ImGuiDir.Down then
        pos_new[a] = pos_old[a] + size_old[a] + dock_spacing
    elseif dir == ImGuiDir.Left or dir == ImGuiDir.Up then
        pos_new[a] = pos_old[a]
        pos_old[a] = pos_new[a] + size_new[a] + dock_spacing
    end
end

local function ImGetDirQuadrantFromDeltaLocal(dx, dy)
    if math.abs(dx) > math.abs(dy) then
        return (dx > 0.0) and ImGuiDir.Right or ImGuiDir.Left
    end
    return (dy > 0.0) and ImGuiDir.Down or ImGuiDir.Up
end

--- @return bool hit, ImRect out_r
function ImGui.DockNodeCalcDropRectsAndTestMousePos(parent, dir, outer_docking, test_mouse_pos)
    local g = ImGui.GetCurrentContext()

    local parent_smaller_axis = ImMin(parent:GetWidth(), parent:GetHeight())
    local hs_for_central_nodes = ImMin(g.FontSize * 1.5, ImMax(g.FontSize * 0.5, parent_smaller_axis / 8.0))
    local hs_w, hs_h, off
    if outer_docking then
        hs_w = ImTrunc(hs_for_central_nodes * 1.50)
        hs_h = ImTrunc(hs_for_central_nodes * 0.80)
        off = ImVec2(ImTrunc(parent:GetWidth() * 0.5 - hs_h), ImTrunc(parent:GetHeight() * 0.5 - hs_h))
    else
        hs_w = ImTrunc(hs_for_central_nodes)
        hs_h = ImTrunc(hs_for_central_nodes * 0.90)
        off = ImVec2(ImTrunc(hs_w * 2.40), ImTrunc(hs_w * 2.40))
    end

    local pc = parent:GetCenter()
    local c = ImVec2(ImTrunc(pc.x), ImTrunc(pc.y))
    local out_r
    if dir == ImGuiDir.None then out_r = ImRect(c.x - hs_w, c.y - hs_w, c.x + hs_w, c.y + hs_w)
    elseif dir == ImGuiDir.Up then out_r = ImRect(c.x - hs_w, c.y - off.y - hs_h, c.x + hs_w, c.y - off.y + hs_h)
    elseif dir == ImGuiDir.Down then out_r = ImRect(c.x - hs_w, c.y + off.y - hs_h, c.x + hs_w, c.y + off.y + hs_h)
    elseif dir == ImGuiDir.Left then out_r = ImRect(c.x - off.x - hs_h, c.y - hs_w, c.x - off.x + hs_h, c.y + hs_w)
    elseif dir == ImGuiDir.Right then out_r = ImRect(c.x + off.x - hs_h, c.y - hs_w, c.x + off.x + hs_h, c.y + hs_w) end

    if test_mouse_pos == nil then return false, out_r end

    local hit_r = ImRect(out_r.Min, out_r.Max)
    if not outer_docking then
        hit_r:Expand(ImTrunc(hs_w * 0.30))
        local mdx, mdy = test_mouse_pos.x - c.x, test_mouse_pos.y - c.y
        local mouse_delta_len2 = mdx * mdx + mdy * mdy
        local r_threshold_center = hs_w * 1.4
        local r_threshold_sides = hs_w * (1.4 + 1.2)
        if mouse_delta_len2 < r_threshold_center * r_threshold_center then
            return (dir == ImGuiDir.None), out_r
        end
        if mouse_delta_len2 < r_threshold_sides * r_threshold_sides then
            return (dir == ImGetDirQuadrantFromDeltaLocal(mdx, mdy)), out_r
        end
    end
    return hit_r:Contains(test_mouse_pos), out_r
end

function ImGui.DockNodePreviewDockSetup(host_window, host_node, payload_window, payload_node, data, is_explicit_target, is_outer_docking)
    local g = ImGui.GetCurrentContext()

    if payload_node == nil then payload_node = payload_window.DockNodeAsHost end
    local ref_node_for_rect = (host_node and not host_node.IsVisible) and ImGui.DockNodeGetRootNode(host_node) or host_node
    if ref_node_for_rect then IM_ASSERT(ref_node_for_rect.IsVisible == true) end

    local src_node_flags = payload_node and payload_node.MergedFlags or payload_window.WindowClass.DockNodeFlagsOverrideSet
    local dst_node_flags = host_node and host_node.MergedFlags or host_window.WindowClass.DockNodeFlagsOverrideSet
    data.IsCenterAvailable = true
    if is_outer_docking then
        data.IsCenterAvailable = false
    elseif g.IO.ConfigDockingNoDockingOver then
        data.IsCenterAvailable = false
    elseif bit32.band(dst_node_flags, ImGuiDockNodeFlags.NoDockingOverMe) ~= 0 then
        data.IsCenterAvailable = false
    elseif host_node and bit32.band(dst_node_flags, ImGuiDockNodeFlags.NoDockingOverCentralNode) ~= 0 and host_node:IsCentralNode() then
        data.IsCenterAvailable = false
    elseif (not host_node or not host_node:IsEmpty()) and payload_node and payload_node:IsSplitNode() and (payload_node.OnlyNodeWithWindows == nil) then
        data.IsCenterAvailable = false
    elseif bit32.band(src_node_flags, ImGuiDockNodeFlags.NoDockingOverOther) ~= 0 and (not host_node or not host_node:IsEmpty()) then
        data.IsCenterAvailable = false
    elseif bit32.band(src_node_flags, ImGuiDockNodeFlags.NoDockingOverEmpty) ~= 0 and host_node and host_node:IsEmpty() then
        data.IsCenterAvailable = false
    end

    data.IsSidesAvailable = true
    if bit32.band(dst_node_flags, ImGuiDockNodeFlags.NoDockingSplit) ~= 0 or g.IO.ConfigDockingNoSplit then
        data.IsSidesAvailable = false
    elseif not is_outer_docking and host_node and host_node.ParentNode == nil and host_node:IsCentralNode() then
        data.IsSidesAvailable = false
    elseif bit32.band(src_node_flags, ImGuiDockNodeFlags.NoDockingSplitOther) ~= 0 then
        data.IsSidesAvailable = false
    end

    data.FutureNode.HasCloseButton = (host_node and host_node.HasCloseButton or (not host_node and host_window.HasCloseButton)) or payload_window.HasCloseButton
    data.FutureNode.HasWindowMenuButton = host_node and true or (bit32.band(host_window.Flags, ImGuiWindowFlags.NoCollapse) == 0)
    local rp = ref_node_for_rect and ref_node_for_rect.Pos or host_window.Pos
    local rs = ref_node_for_rect and ref_node_for_rect.Size or host_window.Size
    data.FutureNode.Pos = ImVec2(rp.x, rp.y)
    data.FutureNode.Size = ImVec2(rs.x, rs.y)

    data.SplitNode = host_node
    data.SplitDir = ImGuiDir.None
    data.IsSplitDirExplicit = false
    if not host_window.Collapsed then
        for dir = ImGuiDir.None, ImGuiDir.COUNT - 1 do
            if not ((dir == ImGuiDir.None and not data.IsCenterAvailable) or (dir ~= ImGuiDir.None and not data.IsSidesAvailable)) then
                local hit, r = ImGui.DockNodeCalcDropRectsAndTestMousePos(data.FutureNode:Rect(), dir, is_outer_docking, g.IO.MousePos)
                data.DropRectsDraw[dir + 1] = r
                if hit then
                    data.SplitDir = dir
                    data.IsSplitDirExplicit = true
                end
            end
        end
    end

    data.IsDropAllowed = (data.SplitDir ~= ImGuiDir.None) or data.IsCenterAvailable
    if not is_explicit_target and not data.IsSplitDirExplicit and not g.IO.ConfigDockingWithShift then
        data.IsDropAllowed = false
    end

    data.SplitRatio = 0.0
    if data.SplitDir ~= ImGuiDir.None then
        local split_dir = data.SplitDir
        local split_axis = (split_dir == ImGuiDir.Left or split_dir == ImGuiDir.Right) and ImGuiAxis.X or ImGuiAxis.Y
        local pos_new, pos_old = ImVec2(0, 0), ImVec2(data.FutureNode.Pos.x, data.FutureNode.Pos.y)
        local size_new, size_old = ImVec2(0, 0), ImVec2(data.FutureNode.Size.x, data.FutureNode.Size.y)
        ImGui.DockNodeCalcSplitRects(pos_old, size_old, pos_new, size_new, split_dir, payload_window.Size)

        local split_ratio = ImSaturate(size_new[split_axis] / data.FutureNode.Size[split_axis])
        data.FutureNode.Pos = pos_new
        data.FutureNode.Size = size_new
        data.SplitRatio = (split_dir == ImGuiDir.Right or split_dir == ImGuiDir.Down) and (1.0 - split_ratio) or split_ratio
    end
end

function ImGui.DockNodePreviewDockRender(host_window, host_node, root_payload, data)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(g.CurrentWindow == host_window)

    local is_transparent_payload = g.IO.ConfigDockingTransparentPayload

    local overlay_draw_lists = { ImGui.GetForegroundDrawList(host_window.Viewport) }

    local overlay_col_main = ImGui.GetColorU32(ImGuiCol.DockingPreview, is_transparent_payload and 0.60 or 0.40)
    local overlay_col_drop = ImGui.GetColorU32(ImGuiCol.DockingPreview, is_transparent_payload and 0.90 or 0.70)
    local overlay_col_drop_hovered = ImGui.GetColorU32(ImGuiCol.DockingPreview, is_transparent_payload and 1.20 or 1.00)
    local overlay_col_lines = ImGui.GetColorU32(ImGuiCol.NavWindowingHighlight, is_transparent_payload and 0.80 or 0.60)

    local can_preview_tabs = (root_payload.DockNodeAsHost == nil or root_payload.DockNodeAsHost.Windows.Size > 0)
    if data.IsDropAllowed then
        local overlay_rect = data.FutureNode:Rect()
        if data.SplitDir == ImGuiDir.None and can_preview_tabs then
            overlay_rect.Min.y = overlay_rect.Min.y + ImGui.GetFrameHeight()
        end
        if data.SplitDir ~= ImGuiDir.None or data.IsCenterAvailable then
            for _, dl in ipairs(overlay_draw_lists) do
                dl:AddRectFilled(overlay_rect.Min, overlay_rect.Max, overlay_col_main, host_window.WindowRounding, ImGui.CalcRoundingFlagsForRectInRect(overlay_rect, host_window:Rect(), g.Style.DockingSeparatorSize))
            end
        end
    end

    if data.IsDropAllowed and can_preview_tabs and data.SplitDir == ImGuiDir.None and data.IsCenterAvailable then
        local _, tab_bar_rect = ImGui.DockNodeCalcTabBarLayout(data.FutureNode)
        local tab_pos = ImVec2(tab_bar_rect.Min.x, tab_bar_rect.Min.y)
        if host_node and host_node.TabBar then
            if not host_node:IsHiddenTabBar() and not host_node:IsNoTabBar() then
                tab_pos.x = tab_pos.x + host_node.TabBar.WidthAllTabs + g.Style.ItemInnerSpacing.x
            else
                tab_pos.x = tab_pos.x + g.Style.ItemInnerSpacing.x + ImGui.TabItemCalcSize(host_node.Windows.Data[1]).x
            end
        elseif bit32.band(host_window.Flags, ImGuiWindowFlags.DockNodeHost) == 0 then
            tab_pos.x = tab_pos.x + g.Style.ItemInnerSpacing.x + ImGui.TabItemCalcSize(host_window).x
        end

        if root_payload.DockNodeAsHost then
            IM_ASSERT(root_payload.DockNodeAsHost.Windows.Size <= root_payload.DockNodeAsHost.TabBar.Tabs.Size)
        end
        local tab_bar_with_payload = root_payload.DockNodeAsHost and root_payload.DockNodeAsHost.TabBar or nil
        local payload_count = tab_bar_with_payload and tab_bar_with_payload.Tabs.Size or 1
        for payload_n = 1, payload_count do
            local payload_window = tab_bar_with_payload and tab_bar_with_payload.Tabs.Data[payload_n].Window or root_payload
            if not (tab_bar_with_payload and payload_window == nil) and DockNodeIsDropAllowedOne(payload_window, host_window) then
                local tab_size = ImGui.TabItemCalcSize(payload_window)
                local tab_bb = ImRect(tab_pos.x, tab_pos.y, tab_pos.x + tab_size.x, tab_pos.y + tab_size.y)
                tab_pos.x = tab_pos.x + tab_size.x + g.Style.ItemInnerSpacing.x
                local overlay_col_text = ImGui.GetColorU32(payload_window.DockStyle.Colors[ImGuiWindowDockStyleCol.Text], 1.0, true)
                local overlay_col_tabs = ImGui.GetColorU32(payload_window.DockStyle.Colors[ImGuiWindowDockStyleCol.TabSelected], 1.0, true)
                local overlay_col_unsaved_marker = ImGui.GetColorU32(payload_window.DockStyle.Colors[ImGuiWindowDockStyleCol.UnsavedMarker], 1.0, true)
                ImGui.PushStyleColor(ImGuiCol.Text, ImGui.ColorConvertU32ToFloat4(overlay_col_text))
                ImGui.PushStyleColor(ImGuiCol.UnsavedMarker, ImGui.ColorConvertU32ToFloat4(overlay_col_unsaved_marker))
                for _, dl in ipairs(overlay_draw_lists) do
                    local tab_flags = bit32.band(payload_window.Flags, ImGuiWindowFlags.UnsavedDocument) ~= 0 and ImGuiTabItemFlags.UnsavedDocument or 0
                    local contains = tab_bar_rect:Contains(tab_bb)
                    if not contains then dl:PushClipRect(tab_bar_rect.Min, tab_bar_rect.Max) end
                    ImGui.TabItemBackground(dl, tab_bb, tab_flags, overlay_col_tabs)
                    ImGui.TabItemLabelAndCloseButton(dl, tab_bb, tab_flags, g.Style.FramePadding, payload_window.Name, 0, 0, false)
                    if not contains then dl:PopClipRect() end
                end
                ImGui.PopStyleColor(2)
            end
        end
    end

    local scale = g.Style._MainScale or 1.0
    local overlay_rounding = ImMax(math.floor(3.0 * scale), g.Style.FrameRounding)
    for dir = ImGuiDir.None, ImGuiDir.COUNT - 1 do
        local draw_r = data.DropRectsDraw[dir + 1]
        if not IsRectInverted(draw_r) then
            local draw_r_in = ImRect(draw_r.Min, draw_r.Max)
            draw_r_in:Expand(math.floor(-2.0 * scale))
            local overlay_col = (data.SplitDir == dir and data.IsSplitDirExplicit) and overlay_col_drop_hovered or overlay_col_drop
            local thickness = math.floor(1.0 * scale)
            for _, dl in ipairs(overlay_draw_lists) do
                local cc = draw_r_in:GetCenter()
                local center = ImVec2(math.floor(cc.x), math.floor(cc.y))
                dl:AddRectFilled(draw_r.Min, draw_r.Max, overlay_col, overlay_rounding)
                dl:AddRect(draw_r_in.Min, draw_r_in.Max, overlay_col_lines, overlay_rounding, thickness)
                if dir == ImGuiDir.Left or dir == ImGuiDir.Right then
                    dl:AddLineV(center.x, draw_r_in.Min.y, draw_r_in.Max.y, overlay_col_lines, thickness)
                end
                if dir == ImGuiDir.Up or dir == ImGuiDir.Down then
                    dl:AddLineH(draw_r_in.Min.x, draw_r_in.Max.x, center.y, overlay_col_lines, thickness)
                end
            end
        end
        if (host_node and bit32.band(host_node.MergedFlags, ImGuiDockNodeFlags.NoDockingSplit) ~= 0) or g.IO.ConfigDockingNoSplit then
            return
        end
    end
end

---------------------------------------------------------------------------------------
-- Docking: ImGuiDockNode Tree manipulation functions
---------------------------------------------------------------------------------------

function ImGui.DockNodeTreeSplit(ctx, parent_node, split_axis, split_inheritor_child_idx, split_ratio, new_node)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(split_axis ~= ImGuiAxis.None)

    local child_0 = (new_node and split_inheritor_child_idx ~= 0) and new_node or ImGui.DockContextAddNode(ctx, 0)
    child_0.ParentNode = parent_node

    local child_1 = (new_node and split_inheritor_child_idx ~= 1) and new_node or ImGui.DockContextAddNode(ctx, 0)
    child_1.ParentNode = parent_node

    local child_inheritor = (split_inheritor_child_idx == 0) and child_0 or child_1
    ImGui.DockNodeMoveChildNodes(child_inheritor, parent_node)
    parent_node.ChildNodes[0] = child_0
    parent_node.ChildNodes[1] = child_1
    parent_node.ChildNodes[split_inheritor_child_idx].VisibleWindow = parent_node.VisibleWindow
    parent_node.SplitAxis = split_axis
    parent_node.VisibleWindow = nil
    parent_node.AuthorityForPos = ImGuiDataAuthority.DockNode
    parent_node.AuthorityForSize = ImGuiDataAuthority.DockNode

    local a = split_axis
    local size_avail = parent_node.Size[a] - g.Style.DockingSeparatorSize
    size_avail = ImMax(size_avail, g.Style.WindowMinSize[a] * 2.0)
    IM_ASSERT(size_avail > 0.0)
    child_0.SizeRef = ImVec2(parent_node.Size.x, parent_node.Size.y)
    child_1.SizeRef = ImVec2(parent_node.Size.x, parent_node.Size.y)
    child_0.SizeRef[a] = ImTrunc(size_avail * split_ratio)
    child_1.SizeRef[a] = ImTrunc(size_avail - child_0.SizeRef[a])

    ImGui.DockNodeMoveWindows(parent_node.ChildNodes[split_inheritor_child_idx], parent_node)
    DockSettingsRenameNodeReferences(parent_node.ID, parent_node.ChildNodes[split_inheritor_child_idx].ID)
    ImGui.DockNodeUpdateHasCentralNodeChild(ImGui.DockNodeGetRootNode(parent_node))
    ImGui.DockNodeTreeUpdatePosSize(parent_node, parent_node.Pos, parent_node.Size)

    child_0.SharedFlags = bit32.band(parent_node.SharedFlags, ImGuiDockNodeFlags.SharedFlagsInheritMask_)
    child_1.SharedFlags = bit32.band(parent_node.SharedFlags, ImGuiDockNodeFlags.SharedFlagsInheritMask_)
    child_inheritor.LocalFlags = bit32.band(parent_node.LocalFlags, ImGuiDockNodeFlags.LocalFlagsTransferMask_)
    parent_node.LocalFlags = bit32.band(parent_node.LocalFlags, bit32.bnot(ImGuiDockNodeFlags.LocalFlagsTransferMask_))
    child_0:UpdateMergedFlags()
    child_1:UpdateMergedFlags()
    parent_node:UpdateMergedFlags()
    if child_inheritor:IsCentralNode() then
        ImGui.DockNodeGetRootNode(parent_node).CentralNode = child_inheritor
    end
end

function ImGui.DockNodeTreeMerge(ctx, parent_node, merge_lead_child)
    local child_0 = parent_node.ChildNodes[0]
    local child_1 = parent_node.ChildNodes[1]
    IM_ASSERT(child_0 or child_1)
    IM_ASSERT(merge_lead_child == child_0 or merge_lead_child == child_1)
    if (child_0 and child_0.Windows.Size > 0) or (child_1 and child_1.Windows.Size > 0) then
        IM_ASSERT(parent_node.TabBar == nil)
        IM_ASSERT(parent_node.Windows.Size == 0)
    end

    local backup_last_explicit_size = ImVec2(parent_node.SizeRef.x, parent_node.SizeRef.y)
    ImGui.DockNodeMoveChildNodes(parent_node, merge_lead_child)
    if child_0 then
        ImGui.DockNodeMoveWindows(parent_node, child_0)
        DockSettingsRenameNodeReferences(child_0.ID, parent_node.ID)
    end
    if child_1 then
        ImGui.DockNodeMoveWindows(parent_node, child_1)
        DockSettingsRenameNodeReferences(child_1.ID, parent_node.ID)
    end
    ImGui.DockNodeApplyPosSizeToWindows(parent_node)
    parent_node.AuthorityForPos = ImGuiDataAuthority.Auto
    parent_node.AuthorityForSize = ImGuiDataAuthority.Auto
    parent_node.AuthorityForViewport = ImGuiDataAuthority.Auto
    parent_node.VisibleWindow = merge_lead_child.VisibleWindow
    parent_node.SizeRef = backup_last_explicit_size

    local M = ImGuiDockNodeFlags.LocalFlagsTransferMask_
    parent_node.LocalFlags = bit32.band(parent_node.LocalFlags, bit32.bnot(M))
    parent_node.LocalFlags = bit32.bor(parent_node.LocalFlags, bit32.band(child_0 and child_0.LocalFlags or 0, M))
    parent_node.LocalFlags = bit32.bor(parent_node.LocalFlags, bit32.band(child_1 and child_1.LocalFlags or 0, M))
    parent_node.LocalFlagsInWindows = bit32.bor(child_0 and child_0.LocalFlagsInWindows or 0, child_1 and child_1.LocalFlagsInWindows or 0)
    parent_node:UpdateMergedFlags()

    if child_0 then ImGui.DockContextDeleteNode(ctx, child_0) end
    if child_1 then ImGui.DockContextDeleteNode(ctx, child_1) end
end

function ImGui.DockNodeTreeUpdatePosSize(node, pos, size, only_write_to_single_node)
    local g = ImGui.GetCurrentContext()
    local write_to_node = only_write_to_single_node == nil or only_write_to_single_node == node
    if write_to_node then
        node.Pos = ImVec2(pos.x, pos.y)
        node.Size = ImVec2(size.x, size.y)
    end

    if node:IsLeafNode() then return end

    local child_0 = node.ChildNodes[0]
    local child_1 = node.ChildNodes[1]
    local child_0_pos, child_1_pos = ImVec2(pos.x, pos.y), ImVec2(pos.x, pos.y)
    local child_0_size, child_1_size = ImVec2(size.x, size.y), ImVec2(size.x, size.y)

    local child_0_is_toward_single_node = (only_write_to_single_node ~= nil and ImGui.DockNodeIsInHierarchyOf(only_write_to_single_node, child_0))
    local child_1_is_toward_single_node = (only_write_to_single_node ~= nil and ImGui.DockNodeIsInHierarchyOf(only_write_to_single_node, child_1))
    local child_0_is_or_will_be_visible = child_0.IsVisible or child_0_is_toward_single_node
    local child_1_is_or_will_be_visible = child_1.IsVisible or child_1_is_toward_single_node

    if child_0_is_or_will_be_visible and child_1_is_or_will_be_visible then
        local spacing = g.Style.DockingSeparatorSize
        local a = node.SplitAxis
        local size_avail = ImMax(size[a] - spacing, 0.0)

        local size_min_each = ImTrunc(ImMin(size_avail, g.Style.WindowMinSize[a] * 2.0) * 0.5)

        if child_0.WantLockSizeOnce and not child_1.WantLockSizeOnce then
            child_0_size[a] = ImMin(size_avail - 1.0, child_0.Size[a]); child_0.SizeRef[a] = child_0_size[a]
            child_1_size[a] = size_avail - child_0_size[a]; child_1.SizeRef[a] = child_1_size[a]
        elseif child_1.WantLockSizeOnce and not child_0.WantLockSizeOnce then
            child_1_size[a] = ImMin(size_avail - 1.0, child_1.Size[a]); child_1.SizeRef[a] = child_1_size[a]
            child_0_size[a] = size_avail - child_1_size[a]; child_0.SizeRef[a] = child_0_size[a]
        elseif child_0.WantLockSizeOnce and child_1.WantLockSizeOnce then
            local split_ratio = child_0_size[a] / (child_0_size[a] + child_1_size[a])
            child_0_size[a] = ImTrunc(size_avail * split_ratio); child_0.SizeRef[a] = child_0_size[a]
            child_1_size[a] = size_avail - child_0_size[a]; child_1.SizeRef[a] = child_1_size[a]
        elseif child_0.SizeRef[a] ~= 0.0 and child_1.HasCentralNodeChild then
            child_0_size[a] = ImMin(size_avail - size_min_each, child_0.SizeRef[a])
            child_1_size[a] = size_avail - child_0_size[a]
        elseif child_1.SizeRef[a] ~= 0.0 and child_0.HasCentralNodeChild then
            child_1_size[a] = ImMin(size_avail - size_min_each, child_1.SizeRef[a])
            child_0_size[a] = size_avail - child_1_size[a]
        else
            local split_ratio = child_0.SizeRef[a] / (child_0.SizeRef[a] + child_1.SizeRef[a])
            child_0_size[a] = ImMax(size_min_each, ImTrunc(size_avail * split_ratio + 0.5))
            child_1_size[a] = size_avail - child_0_size[a]
        end

        child_1_pos[a] = child_1_pos[a] + spacing + child_0_size[a]
    end

    if only_write_to_single_node == nil then
        child_0.WantLockSizeOnce = false
        child_1.WantLockSizeOnce = false
    end
    local child_0_recurse = only_write_to_single_node and child_0_is_toward_single_node or (not only_write_to_single_node and child_0.IsVisible)
    local child_1_recurse = only_write_to_single_node and child_1_is_toward_single_node or (not only_write_to_single_node and child_1.IsVisible)
    if child_0_recurse then ImGui.DockNodeTreeUpdatePosSize(child_0, child_0_pos, child_0_size) end
    if child_1_recurse then ImGui.DockNodeTreeUpdatePosSize(child_1, child_1_pos, child_1_size) end
end

local function DockNodeTreeUpdateSplitterFindTouchingNode(node, axis, side, touching_nodes)
    if node:IsLeafNode() then
        table.insert(touching_nodes, node)
        return
    end
    if node.ChildNodes[0].IsVisible then
        if node.SplitAxis ~= axis or side == 0 or not node.ChildNodes[1].IsVisible then
            DockNodeTreeUpdateSplitterFindTouchingNode(node.ChildNodes[0], axis, side, touching_nodes)
        end
    end
    if node.ChildNodes[1].IsVisible then
        if node.SplitAxis ~= axis or side == 1 or not node.ChildNodes[0].IsVisible then
            DockNodeTreeUpdateSplitterFindTouchingNode(node.ChildNodes[1], axis, side, touching_nodes)
        end
    end
end

local WINDOWS_RESIZE_FROM_EDGES_FEEDBACK_TIMER = 0.04

function ImGui.DockNodeTreeUpdateSplitter(node)
    if node:IsLeafNode() then return end

    local g = ImGui.GetCurrentContext()

    local child_0 = node.ChildNodes[0]
    local child_1 = node.ChildNodes[1]
    if child_0.IsVisible and child_1.IsVisible then
        local axis = node.SplitAxis
        IM_ASSERT(axis ~= ImGuiAxis.None)
        local a, o = axis, 3 - axis -- the port's ImGuiAxis is 1-based (X=1,Y=2): it is directly the ImVec2 index
        local bb = ImRect(ImVec2(child_0.Pos.x, child_0.Pos.y), ImVec2(child_1.Pos.x, child_1.Pos.y))
        bb.Min[a] = bb.Min[a] + child_0.Size[a]
        bb.Max[o] = bb.Max[o] + child_1.Size[o]

        local merged_flags = bit32.bor(child_0.MergedFlags, child_1.MergedFlags)
        local no_resize_axis_flag = (axis == ImGuiAxis.X) and ImGuiDockNodeFlags.NoResizeX or ImGuiDockNodeFlags.NoResizeY
        if bit32.band(merged_flags, ImGuiDockNodeFlags.NoResize) ~= 0 or bit32.band(merged_flags, no_resize_axis_flag) ~= 0 then
            local window = g.CurrentWindow
            window.DrawList:AddRectFilled(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.Separator), g.Style.FrameRounding)
        else
            ImGui.PushID(node.ID)

            local touching_nodes = { [0] = {}, [1] = {} }
            local min_size = g.Style.WindowMinSize[a]
            local resize_limits = { [0] = node.ChildNodes[0].Pos[a] + min_size, [1] = node.ChildNodes[1].Pos[a] + node.ChildNodes[1].Size[a] - min_size }

            local splitter_id = ImGui.GetID("##Splitter")
            if g.ActiveId == splitter_id then
                DockNodeTreeUpdateSplitterFindTouchingNode(child_0, axis, 1, touching_nodes[0])
                DockNodeTreeUpdateSplitterFindTouchingNode(child_1, axis, 0, touching_nodes[1])
                for _, tn in ipairs(touching_nodes[0]) do
                    resize_limits[0] = ImMax(resize_limits[0], tn:Rect().Min[a] + min_size)
                end
                for _, tn in ipairs(touching_nodes[1]) do
                    resize_limits[1] = ImMin(resize_limits[1], tn:Rect().Max[a] - min_size)
                end
            end

            local cur_size_0 = child_0.Size[a]
            local cur_size_1 = child_1.Size[a]
            local min_size_0 = resize_limits[0] - child_0.Pos[a]
            local min_size_1 = child_1.Pos[a] + child_1.Size[a] - resize_limits[1]
            local bg_col = ImGui.GetColorU32(ImGuiCol.WindowBg)
            local changed
            changed, cur_size_0, cur_size_1 = ImGui.SplitterBehavior(bb, ImGui.GetID("##Splitter"), axis, cur_size_0, cur_size_1, min_size_0, min_size_1, g.WindowsBorderHoverPadding, WINDOWS_RESIZE_FROM_EDGES_FEEDBACK_TIMER, bg_col)
            if changed then
                if #touching_nodes[0] > 0 and #touching_nodes[1] > 0 then
                    child_0.Size[a] = cur_size_0; child_0.SizeRef[a] = cur_size_0
                    child_1.Pos[a] = child_1.Pos[a] - (cur_size_1 - child_1.Size[a])
                    child_1.Size[a] = cur_size_1; child_1.SizeRef[a] = cur_size_1

                    for side_n = 0, 1 do
                        for _, touching_node in ipairs(touching_nodes[side_n]) do
                            while touching_node.ParentNode ~= node do
                                if touching_node.ParentNode.SplitAxis == axis then
                                    local node_to_preserve = touching_node.ParentNode.ChildNodes[side_n]
                                    node_to_preserve.WantLockSizeOnce = true
                                end
                                touching_node = touching_node.ParentNode
                            end
                        end
                    end

                    ImGui.DockNodeTreeUpdatePosSize(child_0, child_0.Pos, child_0.Size)
                    ImGui.DockNodeTreeUpdatePosSize(child_1, child_1.Pos, child_1.Size)
                    ImGui.MarkIniSettingsDirty()
                end
            end
            ImGui.PopID()
        end
    end

    if child_0.IsVisible then ImGui.DockNodeTreeUpdateSplitter(child_0) end
    if child_1.IsVisible then ImGui.DockNodeTreeUpdateSplitter(child_1) end
end

function ImGui.DockNodeTreeFindFallbackLeafNode(node)
    if node:IsLeafNode() then return node end
    local leaf_node = ImGui.DockNodeTreeFindFallbackLeafNode(node.ChildNodes[0])
    if leaf_node then return leaf_node end
    leaf_node = ImGui.DockNodeTreeFindFallbackLeafNode(node.ChildNodes[1])
    if leaf_node then return leaf_node end
    return nil
end

function ImGui.DockNodeTreeFindVisibleNodeByPos(node, pos)
    if not node.IsVisible then return nil end
    local r = ImRect(node.Pos, node.Pos + node.Size)
    if not r:Contains(pos) then return nil end
    if node:IsLeafNode() then return node end
    local hovered_node = ImGui.DockNodeTreeFindVisibleNodeByPos(node.ChildNodes[0], pos)
    if hovered_node then return hovered_node end
    hovered_node = ImGui.DockNodeTreeFindVisibleNodeByPos(node.ChildNodes[1], pos)
    if hovered_node then return hovered_node end
    return node
end

---------------------------------------------------------------------------------------
-- Docking: Public Functions (SetWindowDock, DockSpace, DockSpaceOverViewport)
---------------------------------------------------------------------------------------

function ImGui.SetWindowDock(window, dock_id, cond)
    if cond and cond ~= 0 and bit32.band(window.SetWindowDockAllowFlags, cond) == 0 then return end
    window.SetWindowDockAllowFlags = bit32.band(window.SetWindowDockAllowFlags, bit32.bnot(bit32.bor(ImGuiCond.Once, ImGuiCond.FirstUseEver, ImGuiCond.Appearing)))

    if window.DockId == dock_id then return end

    local g = ImGui.GetCurrentContext()
    local new_node = ImGui.DockContextFindNodeByID(g, dock_id)
    if new_node and new_node:IsSplitNode() then
        new_node = ImGui.DockNodeGetRootNode(new_node)
        if new_node.CentralNode then
            IM_ASSERT(new_node.CentralNode:IsCentralNode())
            dock_id = new_node.CentralNode.ID
        else
            dock_id = new_node.LastFocusedNodeId
        end
    end

    if window.DockId == dock_id then return end

    if window.DockNode then ImGui.DockNodeRemoveWindow(window.DockNode, window, 0) end
    window.DockId = dock_id
end

function ImGui.DockSpace(dockspace_id, size_arg, flags, window_class)
    if size_arg == nil then size_arg = ImVec2(0, 0) end
    if flags == nil then flags = 0 end
    local g = ImGui.GetCurrentContext()
    local window = ImGui.GetCurrentWindowRead()
    if bit32.band(g.IO.ConfigFlags, ImGuiConfigFlags.DockingEnable) == 0 then return 0 end

    if window.SkipItems then flags = bit32.bor(flags, ImGuiDockNodeFlags.KeepAliveOnly) end
    if bit32.band(flags, ImGuiDockNodeFlags.KeepAliveOnly) == 0 then window = ImGui.GetCurrentWindow() end

    IM_ASSERT(bit32.band(flags, ImGuiDockNodeFlags.DockSpace) == 0)
    IM_ASSERT(bit32.band(flags, ImGuiDockNodeFlags.CentralNode) == 0)

    IM_ASSERT(dockspace_id ~= 0)
    local node = ImGui.DockContextFindNodeByID(g, dockspace_id)
    if node == nil then
        node = ImGui.DockContextAddNode(g, dockspace_id)
        node:SetLocalFlags(ImGuiDockNodeFlags.CentralNode)
    end
    node.SharedFlags = flags
    node.WindowClass = window_class or ImGuiWindowClass()

    if node.LastFrameActive == g.FrameCount and bit32.band(flags, ImGuiDockNodeFlags.KeepAliveOnly) == 0 then
        IM_ASSERT(node:IsDockSpace() == false, "Cannot call DockSpace() twice a frame with the same ID")
        node:SetLocalFlags(bit32.bor(node.LocalFlags, ImGuiDockNodeFlags.DockSpace))
        return dockspace_id
    end
    node:SetLocalFlags(bit32.bor(node.LocalFlags, ImGuiDockNodeFlags.DockSpace))

    if bit32.band(flags, ImGuiDockNodeFlags.KeepAliveOnly) ~= 0 then
        node.LastFrameAlive = g.FrameCount
        return dockspace_id
    end

    local content_avail = ImGui.GetContentRegionAvail()
    local size = ImVec2(ImTrunc(size_arg.x), ImTrunc(size_arg.y))
    if size.x <= 0.0 then size.x = ImMax(content_avail.x + size.x, 4.0) end
    if size.y <= 0.0 then size.y = ImMax(content_avail.y + size.y, 4.0) end
    IM_ASSERT(size.x > 0.0 and size.y > 0.0)

    node.Pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y)
    node.Size = ImVec2(size.x, size.y)
    node.SizeRef = ImVec2(size.x, size.y)
    ImGui.SetNextWindowPos(node.Pos)
    ImGui.SetNextWindowSize(node.Size)
    g.NextWindowData.PosUndock = false

    local window_flags = bit32.bor(ImGuiWindowFlags.ChildWindow, ImGuiWindowFlags.DockNodeHost)
    window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoSavedSettings, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoTitleBar)
    window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoScrollbar, ImGuiWindowFlags.NoScrollWithMouse)
    window_flags = bit32.bor(window_flags, ImGuiWindowFlags.NoBackground)

    local title = string.format("%s/DockSpace_%08X", window.Name, dockspace_id)

    ImGui.PushStyleVar(ImGuiStyleVar.ChildBorderSize, 0.0)
    ImGui.Begin(title, nil, window_flags)
    ImGui.PopStyleVar()

    local host_window = g.CurrentWindow
    DockNodeSetupHostWindow(node, host_window)
    host_window.ChildId = window:GetID(title)
    node.OnlyNodeWithWindows = nil

    IM_ASSERT(node:IsRootNode())

    if node:IsLeafNode() and not node:IsCentralNode() then
        node:SetLocalFlags(bit32.bor(node.LocalFlags, ImGuiDockNodeFlags.CentralNode))
    end

    ImGui.DockNodeUpdate(node)

    ImGui.End()

    local bb = ImRect(node.Pos, node.Pos + size)
    ImGui.ItemSize(size)
    ImGui.ItemAdd(bb, dockspace_id, nil, ImGuiItemFlags.NoNav)
    if bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredRect) ~= 0 and ImGui.IsWindowChildOf(g.HoveredWindow, host_window, false, true) then
        g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredWindow)
    end

    return dockspace_id
end

function ImGui.DockSpaceOverViewport(dockspace_id, viewport, dockspace_flags, window_class)
    if dockspace_id == nil then dockspace_id = 0 end
    if dockspace_flags == nil then dockspace_flags = 0 end
    if viewport == nil then viewport = ImGui.GetMainViewport() end

    ImGui.SetNextWindowPos(viewport.WorkPos)
    ImGui.SetNextWindowSize(viewport.WorkSize)
    ImGui.SetNextWindowViewport(viewport.ID)

    local host_window_flags = 0
    host_window_flags = bit32.bor(host_window_flags, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoCollapse, ImGuiWindowFlags.NoResize, ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoDocking)
    host_window_flags = bit32.bor(host_window_flags, ImGuiWindowFlags.NoBringToFrontOnFocus, ImGuiWindowFlags.NoNavFocus)
    if bit32.band(dockspace_flags, ImGuiDockNodeFlags.PassthruCentralNode) ~= 0 then
        host_window_flags = bit32.bor(host_window_flags, ImGuiWindowFlags.NoBackground)
    end
    if bit32.band(dockspace_flags, ImGuiDockNodeFlags.KeepAliveOnly) ~= 0 then
        host_window_flags = bit32.bor(host_window_flags, ImGuiWindowFlags.NoMouseInputs)
    end

    local label = string.format("WindowOverViewport_%08X", viewport.ID)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 0.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 0.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, ImVec2(0.0, 0.0))
    ImGui.Begin(label, nil, host_window_flags)
    ImGui.PopStyleVar(3)

    if dockspace_id == 0 then dockspace_id = ImGui.GetID("DockSpace") end
    ImGui.DockSpace(dockspace_id, ImVec2(0.0, 0.0), dockspace_flags, window_class)

    ImGui.End()

    return dockspace_id
end

---------------------------------------------------------------------------------------
-- Docking: Builder Functions
---------------------------------------------------------------------------------------

function ImGui.DockBuilderDockWindow(window_name, node_id)
    local window_id = ImHashStr(window_name)
    local window = ImGui.FindWindowByID(window_id)
    if window then
        local prev_node_id = window.DockId
        ImGui.SetWindowDock(window, node_id, ImGuiCond.Always)
        if window.DockId ~= prev_node_id then window.DockOrder = -1 end
    else
        local settings = ImGui.FindWindowSettingsByID(window_id)
        if settings == nil then settings = ImGui.CreateNewWindowSettings(window_name) end
        if settings.DockId ~= node_id then settings.DockOrder = -1 end
        settings.DockId = node_id
    end
end

function ImGui.DockBuilderGetNode(node_id)
    return ImGui.DockContextFindNodeByID(ImGui.GetCurrentContext(), node_id)
end

function ImGui.DockBuilderGetCentralNode(node_id)
    local node = ImGui.DockBuilderGetNode(node_id)
    if not node then return nil end
    return ImGui.DockNodeGetRootNode(node).CentralNode
end

function ImGui.DockBuilderSetNodePos(node_id, pos)
    local node = ImGui.DockContextFindNodeByID(ImGui.GetCurrentContext(), node_id)
    if node == nil then return end
    node.Pos = ImVec2(pos.x, pos.y)
    node.AuthorityForPos = ImGuiDataAuthority.DockNode
end

function ImGui.DockBuilderSetNodeSize(node_id, size)
    local node = ImGui.DockContextFindNodeByID(ImGui.GetCurrentContext(), node_id)
    if node == nil then return end
    IM_ASSERT(size.x > 0.0 and size.y > 0.0)
    node.Size = ImVec2(size.x, size.y)
    node.SizeRef = ImVec2(size.x, size.y)
    node.AuthorityForSize = ImGuiDataAuthority.DockNode
end

function ImGui.DockBuilderAddNode(node_id, flags)
    if node_id == nil then node_id = 0 end
    if flags == nil then flags = 0 end
    local g = ImGui.GetCurrentContext()
    if node_id ~= 0 then ImGui.DockBuilderRemoveNode(node_id) end

    local node
    if bit32.band(flags, ImGuiDockNodeFlags.DockSpace) ~= 0 then
        ImGui.DockSpace(node_id, ImVec2(0, 0), bit32.bor(bit32.band(flags, bit32.bnot(ImGuiDockNodeFlags.DockSpace)), ImGuiDockNodeFlags.KeepAliveOnly))
        node = ImGui.DockContextFindNodeByID(g, node_id)
    else
        node = ImGui.DockContextAddNode(g, node_id)
        node:SetLocalFlags(flags)
    end
    node.LastFrameAlive = g.FrameCount
    return node.ID
end

function ImGui.DockBuilderRemoveNode(node_id)
    local g = ImGui.GetCurrentContext()
    local node = ImGui.DockContextFindNodeByID(g, node_id)
    if node == nil then return end
    ImGui.DockBuilderRemoveNodeDockedWindows(node_id, true)
    ImGui.DockBuilderRemoveNodeChildNodes(node_id)
    node = ImGui.DockContextFindNodeByID(g, node_id)
    if node == nil then return end
    if node:IsCentralNode() and node.ParentNode then
        node.ParentNode:SetLocalFlags(bit32.bor(node.ParentNode.LocalFlags, ImGuiDockNodeFlags.CentralNode))
    end
    ImGui.DockContextRemoveNode(g, node, true)
end

function ImGui.DockBuilderRemoveNodeChildNodes(root_id)
    local g = ImGui.GetCurrentContext()
    local dc = g.DockContext

    local root_node = (root_id ~= 0) and ImGui.DockContextFindNodeByID(g, root_id) or nil
    if root_id ~= 0 and root_node == nil then return end
    local has_central_node = false

    local backup_root_node_authority_for_pos = root_node and root_node.AuthorityForPos or ImGuiDataAuthority.Auto
    local backup_root_node_authority_for_size = root_node and root_node.AuthorityForSize or ImGuiDataAuthority.Auto

    local nodes_to_remove = {}
    for _, id in ipairs(DockContextNodesSorted(g)) do
        local node = dc.Nodes[id]
        if node then
            local want_removal = (root_id == 0) or (node.ID ~= root_id and ImGui.DockNodeGetRootNode(node).ID == root_id)
            if want_removal then
                if node:IsCentralNode() then has_central_node = true end
                if root_id ~= 0 then ImGui.DockContextQueueNotifyRemovedNode(g, node) end
                if root_node then
                    ImGui.DockNodeMoveWindows(root_node, node)
                    DockSettingsRenameNodeReferences(node.ID, root_node.ID)
                end
                table.insert(nodes_to_remove, node)
            end
        end
    end

    if root_node then
        root_node.AuthorityForPos = backup_root_node_authority_for_pos
        root_node.AuthorityForSize = backup_root_node_authority_for_size
    end

    for _, settings in g.SettingsWindows:iter() do
        local window_settings_dock_id = settings.DockId
        if window_settings_dock_id and window_settings_dock_id ~= 0 then
            for _, n in ipairs(nodes_to_remove) do
                if n.ID == window_settings_dock_id then
                    settings.DockId = root_id
                    break
                end
            end
        end
    end

    if #nodes_to_remove > 1 then
        local depth = {}
        for _, n in ipairs(nodes_to_remove) do depth[n] = ImGui.DockNodeGetDepth(n) end
        table.sort(nodes_to_remove, function(a, b) return depth[a] > depth[b] end)
    end
    for _, n in ipairs(nodes_to_remove) do
        ImGui.DockContextRemoveNode(g, n, false)
    end

    if root_id == 0 then
        dc.Nodes = {}
        dc.Requests:clear()
    elseif has_central_node then
        root_node.CentralNode = root_node
        root_node:SetLocalFlags(bit32.bor(root_node.LocalFlags, ImGuiDockNodeFlags.CentralNode))
    end
end

function ImGui.DockBuilderRemoveNodeDockedWindows(root_id, clear_settings_refs)
    if clear_settings_refs == nil then clear_settings_refs = true end
    local g = ImGui.GetCurrentContext()
    if clear_settings_refs then
        for _, settings in g.SettingsWindows:iter() do
            local want_removal = (root_id == 0) or (settings.DockId == root_id)
            if not want_removal and settings.DockId ~= 0 then
                local node = ImGui.DockContextFindNodeByID(g, settings.DockId)
                if node and ImGui.DockNodeGetRootNode(node).ID == root_id then want_removal = true end
            end
            if want_removal then settings.DockId = 0 end
        end
    end

    for n = 1, g.Windows.Size do
        local window = g.Windows.Data[n]
        local want_removal = (root_id == 0) or (window.DockNode and ImGui.DockNodeGetRootNode(window.DockNode).ID == root_id) or (window.DockNodeAsHost and window.DockNodeAsHost.ID == root_id)
        if want_removal then
            local backup_dock_id = window.DockId
            ImGui.DockContextProcessUndockWindow(g, window, clear_settings_refs)
            if not clear_settings_refs then IM_ASSERT(window.DockId == backup_dock_id) end
        end
    end
end

--- @return ImGuiID id_at_dir, ImGuiID id_at_opposite_dir
function ImGui.DockBuilderSplitNode(id, split_dir, size_ratio_for_node_at_dir)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(split_dir ~= ImGuiDir.None)

    local node = ImGui.DockContextFindNodeByID(g, id)
    if node == nil then
        IM_ASSERT(node ~= nil)
        return 0, 0
    end

    local req = ImGuiDockRequest()
    req.Type = ImGuiDockRequestType.Split
    req.DockTargetWindow = nil
    req.DockTargetNode = node
    req.DockPayload = nil
    req.DockSplitDir = split_dir
    req.DockSplitRatio = ImSaturate((split_dir == ImGuiDir.Left or split_dir == ImGuiDir.Up) and size_ratio_for_node_at_dir or (1.0 - size_ratio_for_node_at_dir))
    req.DockSplitOuter = false
    ImGui.DockContextProcessDock(g, req)

    local first = (split_dir == ImGuiDir.Left or split_dir == ImGuiDir.Up)
    local id_at_dir = node.ChildNodes[first and 0 or 1].ID
    local id_at_opposite_dir = node.ChildNodes[first and 1 or 0].ID
    return id_at_dir, id_at_opposite_dir
end

local function DockBuilderCopyNodeRec(src_node, dst_node_id_if_known, out_node_remap_pairs)
    local g = ImGui.GetCurrentContext()
    local dst_node = ImGui.DockContextAddNode(g, dst_node_id_if_known)
    dst_node.SharedFlags = src_node.SharedFlags
    dst_node.LocalFlags = src_node.LocalFlags
    dst_node.LocalFlagsInWindows = ImGuiDockNodeFlags.None
    dst_node.Pos = ImVec2(src_node.Pos.x, src_node.Pos.y)
    dst_node.Size = ImVec2(src_node.Size.x, src_node.Size.y)
    dst_node.SizeRef = ImVec2(src_node.SizeRef.x, src_node.SizeRef.y)
    dst_node.SplitAxis = src_node.SplitAxis
    dst_node:UpdateMergedFlags()

    table.insert(out_node_remap_pairs, src_node.ID)
    table.insert(out_node_remap_pairs, dst_node.ID)

    for child_n = 0, 1 do
        if src_node.ChildNodes[child_n] then
            dst_node.ChildNodes[child_n] = DockBuilderCopyNodeRec(src_node.ChildNodes[child_n], 0, out_node_remap_pairs)
            dst_node.ChildNodes[child_n].ParentNode = dst_node
        end
    end
    return dst_node
end

--- @param out_node_remap_pairs table # 1-based array, cleared and filled with (src_id, dst_id) pairs
function ImGui.DockBuilderCopyNode(src_node_id, dst_node_id, out_node_remap_pairs)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(src_node_id ~= 0)
    IM_ASSERT(dst_node_id ~= 0)
    IM_ASSERT(out_node_remap_pairs ~= nil)

    ImGui.DockBuilderRemoveNode(dst_node_id)

    local src_node = ImGui.DockContextFindNodeByID(g, src_node_id)
    IM_ASSERT(src_node ~= nil)

    for k in pairs(out_node_remap_pairs) do out_node_remap_pairs[k] = nil end
    DockBuilderCopyNodeRec(src_node, dst_node_id, out_node_remap_pairs)
    IM_ASSERT((#out_node_remap_pairs % 2) == 0)
end

function ImGui.DockBuilderCopyWindowSettings(src_name, dst_name)
    local src_window = ImGui.FindWindowByName(src_name)
    if src_window == nil then return end
    local dst_window = ImGui.FindWindowByName(dst_name)
    if dst_window then
        ImVec2_Copy(dst_window.Pos, src_window.Pos)
        ImVec2_Copy(dst_window.Size, src_window.Size)
        ImVec2_Copy(dst_window.SizeFull, src_window.SizeFull)
        dst_window.Collapsed = src_window.Collapsed
    else
        local dst_settings = ImGui.FindWindowSettingsByID(ImHashStr(dst_name))
        if not dst_settings then dst_settings = ImGui.CreateNewWindowSettings(dst_name) end
        local wx, wy = ImTrunc(src_window.Pos.x), ImTrunc(src_window.Pos.y)
        if src_window.ViewportId ~= 0 and src_window.ViewportId ~= 0x11111111 then
            ImVec2_CopyV(dst_settings.ViewportPos, wx, wy)
            dst_settings.ViewportId = src_window.ViewportId
            ImVec2_CopyV(dst_settings.Pos, 0, 0)
        else
            ImVec2_CopyV(dst_settings.Pos, wx, wy)
        end
        ImVec2_CopyV(dst_settings.Size, ImTrunc(src_window.SizeFull.x), ImTrunc(src_window.SizeFull.y))
        dst_settings.Collapsed = src_window.Collapsed
    end
end

--- @param in_window_remap_pairs table # 1-based array of window names: src0, dst0, src1, dst1, ...
function ImGui.DockBuilderCopyDockSpace(src_dockspace_id, dst_dockspace_id, in_window_remap_pairs)
    IM_ASSERT(src_dockspace_id ~= 0)
    IM_ASSERT(dst_dockspace_id ~= 0)
    IM_ASSERT(in_window_remap_pairs ~= nil)
    IM_ASSERT((#in_window_remap_pairs % 2) == 0)

    local node_remap_pairs = {}
    ImGui.DockBuilderCopyNode(src_dockspace_id, dst_dockspace_id, node_remap_pairs)

    local src_windows = {}
    for remap_window_n = 1, #in_window_remap_pairs, 2 do
        local src_window_name = in_window_remap_pairs[remap_window_n]
        local dst_window_name = in_window_remap_pairs[remap_window_n + 1]
        local src_window_id = ImHashStr(src_window_name)
        src_windows[src_window_id] = true

        local src_dock_id = 0
        local src_window = ImGui.FindWindowByID(src_window_id)
        if src_window then
            src_dock_id = src_window.DockId
        else
            local src_window_settings = ImGui.FindWindowSettingsByID(src_window_id)
            if src_window_settings then src_dock_id = src_window_settings.DockId end
        end
        local dst_dock_id = 0
        for dock_remap_n = 1, #node_remap_pairs, 2 do
            if node_remap_pairs[dock_remap_n] == src_dock_id then
                dst_dock_id = node_remap_pairs[dock_remap_n + 1]
                break
            end
        end

        if dst_dock_id ~= 0 then
            ImGui.DockBuilderDockWindow(dst_window_name, dst_dock_id)
        else
            ImGui.DockBuilderCopyWindowSettings(src_window_name, dst_window_name)
        end
    end

    local dock_remaining_windows = {}
    for dock_remap_n = 1, #node_remap_pairs, 2 do
        local src_dock_id = node_remap_pairs[dock_remap_n]
        if src_dock_id ~= 0 then
            local dst_dock_id = node_remap_pairs[dock_remap_n + 1]
            local node = ImGui.DockBuilderGetNode(src_dock_id)
            for _, window in node.Windows:iter() do
                if not src_windows[window.ID] then
                    table.insert(dock_remaining_windows, { Window = window, DockId = dst_dock_id })
                end
            end
        end
    end
    for _, task in ipairs(dock_remaining_windows) do
        ImGui.DockBuilderDockWindow(task.Window.Name, task.DockId)
    end
end

function ImGui.DockBuilderFinish(root_id)
    ImGui.DockContextBuildAddWindowsToNodes(ImGui.GetCurrentContext(), root_id)
end

---------------------------------------------------------------------------------------
-- Docking: Begin/End Support Functions (called from Begin/End)
---------------------------------------------------------------------------------------

function ImGui.GetWindowAlwaysWantOwnTabBar(window)
    local g = ImGui.GetCurrentContext()
    if g.IO.ConfigDockingAlwaysTabBar or window.WindowClass.DockingAlwaysTabBar then
        if bit32.band(window.Flags, bit32.bor(ImGuiWindowFlags.ChildWindow, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoDocking)) == 0 then
            if not window.IsFallbackWindow then return true end
        end
    end
    return false
end

function ImGui.DockContextBindNodeToWindow(ctx, window)
    local g = ctx
    local node = ImGui.DockContextFindNodeByID(ctx, window.DockId)
    IM_ASSERT(window.DockNode == nil)

    if node and node:IsSplitNode() then
        ImGui.DockContextProcessUndockWindow(ctx, window)
        return nil
    end

    if node == nil then
        node = ImGui.DockContextAddNode(ctx, window.DockId)
        node.AuthorityForPos = ImGuiDataAuthority.Window
        node.AuthorityForSize = ImGuiDataAuthority.Window
        node.AuthorityForViewport = ImGuiDataAuthority.Window
        node.LastFrameAlive = g.FrameCount
    end

    if not node.IsVisible then
        local ancestor_node = node
        while not ancestor_node.IsVisible and ancestor_node.ParentNode do
            ancestor_node = ancestor_node.ParentNode
        end
        IM_ASSERT(ancestor_node.Size.x > 0.0 and ancestor_node.Size.y > 0.0)
        ImGui.DockNodeUpdateHasCentralNodeChild(ImGui.DockNodeGetRootNode(ancestor_node))
        ImGui.DockNodeTreeUpdatePosSize(ancestor_node, ancestor_node.Pos, ancestor_node.Size, node)
    end

    local node_was_visible = node.IsVisible
    ImGui.DockNodeAddWindow(node, window, true)
    node.IsVisible = node_was_visible
    IM_ASSERT(node == window.DockNode)
    return node
end

local function StoreDockStyleForWindow(window)
    local g = ImGui.GetCurrentContext()
    for color_n = 0, ImGuiWindowDockStyleCol.COUNT - 1 do
        window.DockStyle.Colors[color_n] = ImGui.ColorConvertFloat4ToU32(g.Style.Colors[GWindowDockStyleColors[color_n]])
    end
end
ImGui.StoreDockStyleForWindow = StoreDockStyleForWindow

--- @return bool? p_open
function ImGui.BeginDocked(window, p_open)
    local g = ImGui.GetCurrentContext()

    if window.IsFallbackWindow and not window.WasActive then
        DockNodeHideWindowDuringHostWindowCreation(window)
        return p_open
    end

    local auto_dock_node = ImGui.GetWindowAlwaysWantOwnTabBar(window)
    if auto_dock_node then
        if window.DockId == 0 then
            IM_ASSERT(window.DockNode == nil)
            window.DockId = ImGui.DockContextGenNodeID(g)
        end
    else
        local want_undock = false
        want_undock = want_undock or bit32.band(window.Flags, ImGuiWindowFlags.NoDocking) ~= 0
        want_undock = want_undock or (bit32.band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasPos) ~= 0 and bit32.band(window.SetWindowPosAllowFlags, g.NextWindowData.PosCond) ~= 0 and g.NextWindowData.PosUndock)
        if want_undock then
            ImGui.DockContextProcessUndockWindow(g, window)
            return p_open
        end
    end

    local node = window.DockNode
    if node ~= nil then IM_ASSERT(window.DockId == node.ID) end
    if window.DockId ~= 0 and node == nil then
        node = ImGui.DockContextBindNodeToWindow(g, window)
        if node == nil then return p_open end
    end

    if node.LastFrameAlive < g.FrameCount then
        local root_node = ImGui.DockNodeGetRootNode(node)
        if root_node.LastFrameAlive < g.FrameCount then
            ImGui.DockContextProcessUndockWindow(g, window)
        else
            window.DockIsActive = true
        end
        return p_open
    end

    StoreDockStyleForWindow(window)

    if node.HostWindow == nil then
        if node.State == ImGuiDockNodeState.HostWindowHiddenBecauseWindowsAreResizing then
            window.DockIsActive = true
        end
        if node.Windows.Size > 1 and window.Appearing then
            DockNodeHideWindowDuringHostWindowCreation(window)
        end
        return p_open
    end

    IM_ASSERT(node.HostWindow)
    IM_ASSERT(node:IsLeafNode())
    IM_ASSERT(node.Size.x >= 0.0 and node.Size.y >= 0.0)
    node.State = ImGuiDockNodeState.HostWindowVisible

    if bit32.band(node.MergedFlags, ImGuiDockNodeFlags.KeepAliveOnly) == 0 and window.BeginOrderWithinContext < node.HostWindow.BeginOrderWithinContext then
        ImGui.DockContextProcessUndockWindow(g, window)
        return p_open
    end

    ImGui.SetNextWindowPos(node.Pos)
    ImGui.SetNextWindowSize(node.Size)
    g.NextWindowData.PosUndock = false
    window.DockIsActive = true
    window.DockNodeIsVisible = true
    window.DockTabIsVisible = false
    if bit32.band(node.MergedFlags, ImGuiDockNodeFlags.KeepAliveOnly) ~= 0 then return p_open end

    if node.VisibleWindow == window then window.DockTabIsVisible = true end

    IM_ASSERT(bit32.band(window.Flags, ImGuiWindowFlags.ChildWindow) == 0)
    window.Flags = bit32.bor(window.Flags, ImGuiWindowFlags.ChildWindow, ImGuiWindowFlags.NoResize)
    window.ChildFlags = bit32.bor(window.ChildFlags, ImGuiChildFlags.AlwaysUseWindowPadding)
    if node:IsHiddenTabBar() or node:IsNoTabBar() then
        window.Flags = bit32.bor(window.Flags, ImGuiWindowFlags.NoTitleBar)
    else
        window.Flags = bit32.band(window.Flags, bit32.bnot(ImGuiWindowFlags.NoTitleBar))
    end

    if node.TabBar and window.WasActive then
        window.DockOrder = ImGui.DockNodeGetTabOrder(window)
    end

    if (node.WantCloseAll or node.WantCloseTabId == window.TabId) and p_open ~= nil then
        p_open = false
    end

    local parent_window = window.DockNode.HostWindow
    window.ChildId = parent_window:GetID(window.Name)
    return p_open
end

function ImGui.BeginDockableDragDropSource(window)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(g.ActiveId == window.MoveId)
    IM_ASSERT(g.MovingWindow == window)
    IM_ASSERT(g.CurrentWindow == window)

    if g.IO.ConfigDockingWithShift ~= g.IO.KeyShift then
        if g.IO.ConfigDockingWithShift and g.MouseStationaryTimer >= 1.0 and g.ActiveId >= 1 then
            ImGui.SetTooltip("%s", ImGui.LocalizeGetMsg(ImGuiLocKey.DockingHoldShiftToDock))
        end
        return
    end

    g.LastItemData.ID = window.MoveId
    window = window.RootWindowDockTree
    IM_ASSERT(bit32.band(window.Flags, ImGuiWindowFlags.NoDocking) == 0)
    local is_drag_docking = g.IO.ConfigDockingWithShift or ImRect(0, 0, window.SizeFull.x, ImGui.GetFrameHeight()):Contains(g.ActiveIdClickOffset)
    local drag_drop_flags = bit32.bor(ImGuiDragDropFlags.SourceNoPreviewTooltip, ImGuiDragDropFlags.SourceNoHoldToOpenOthers, ImGuiDragDropFlags.PayloadAutoExpire, ImGuiDragDropFlags.PayloadNoCrossContext, ImGuiDragDropFlags.PayloadNoCrossProcess)
    if is_drag_docking and ImGui.BeginDragDropSource(drag_drop_flags) then
        ImGui.SetDragDropPayload(IMGUI_PAYLOAD_TYPE_WINDOW, window)
        ImGui.EndDragDropSource()
        StoreDockStyleForWindow(window)
    end
end

function ImGui.BeginDockableDragDropTarget(window)
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(bit32.band(window.Flags, ImGuiWindowFlags.NoDocking) == 0)
    if not g.DragDropActive then return end
    if not ImGui.BeginDragDropTargetCustom(window:Rect(), window.ID) then return end

    local payload = g.DragDropPayload
    if not ImGuiPayload_IsDataType(payload, IMGUI_PAYLOAD_TYPE_WINDOW) or not ImGui.DockNodeIsDropAllowed(window, payload.Data) then
        ImGui.EndDragDropTarget()
        return
    end

    local payload_window = payload.Data
    if ImGui.AcceptDragDropPayload(IMGUI_PAYLOAD_TYPE_WINDOW, bit32.bor(ImGuiDragDropFlags.AcceptBeforeDelivery, ImGuiDragDropFlags.AcceptNoDrawDefaultRect)) then
        local dock_into_floating_window = false
        local node = nil
        if window.DockNodeAsHost then
            node = ImGui.DockNodeTreeFindVisibleNodeByPos(window.DockNodeAsHost, g.IO.MousePos)
            if node and node:IsDockSpace() and node:IsRootNode() then
                node = (node.CentralNode and node:IsLeafNode()) and node.CentralNode or ImGui.DockNodeTreeFindFallbackLeafNode(node)
            end
        else
            if window.DockNode then
                node = window.DockNode
            else
                dock_into_floating_window = true
            end
        end

        local explicit_target_rect
        if node and node.TabBar and not node:IsHiddenTabBar() and not node:IsNoTabBar() then
            explicit_target_rect = node.TabBar.BarRect
        else
            explicit_target_rect = ImRect(window.Pos, window.Pos + ImVec2(window.Size.x, ImGui.GetFrameHeight()))
        end
        local is_explicit_target = g.IO.ConfigDockingWithShift or ImGui.IsMouseHoveringRect(explicit_target_rect.Min, explicit_target_rect.Max)

        local do_preview = ImGuiPayload_IsPreview(payload) or ImGuiPayload_IsDelivery(payload)
        if do_preview and (node ~= nil or dock_into_floating_window) then
            local split_inner = ImGuiDockPreviewData()
            local split_outer = ImGuiDockPreviewData()
            local split_data = split_inner
            if node and (node.ParentNode or node:IsCentralNode() or not node:IsLeafNode()) then
                local root_node = ImGui.DockNodeGetRootNode(node)
                if root_node then
                    ImGui.DockNodePreviewDockSetup(window, root_node, payload_window, nil, split_outer, is_explicit_target, true)
                    if split_outer.IsSplitDirExplicit then split_data = split_outer end
                end
            end
            if not node or node:IsLeafNode() then
                ImGui.DockNodePreviewDockSetup(window, node, payload_window, nil, split_inner, is_explicit_target, false)
            end
            if split_data == split_outer then split_inner.IsDropAllowed = false end

            ImGui.DockNodePreviewDockRender(window, node, payload_window, split_inner)
            ImGui.DockNodePreviewDockRender(window, node, payload_window, split_outer)

            if split_data.IsDropAllowed and ImGuiPayload_IsDelivery(payload) then
                ImGui.DockContextQueueDock(g, window, split_data.SplitNode, payload_window, split_data.SplitDir, split_data.SplitRatio, split_data == split_outer)
            end
        end
    end
    ImGui.EndDragDropTarget()
end

---------------------------------------------------------------------------------------
-- Docking: Settings
---------------------------------------------------------------------------------------

DockSettingsRenameNodeReferences = function(old_node_id, new_node_id)
    local g = ImGui.GetCurrentContext()
    for _, window in g.Windows:iter() do
        if window.DockId == old_node_id and window.DockNode == nil then window.DockId = new_node_id end
    end
    for _, settings in g.SettingsWindows:iter() do
        if settings.DockId == old_node_id then settings.DockId = new_node_id end
    end
end

--- @param node_ids table # 1-based array
DockSettingsRemoveNodeReferences = function(node_ids, node_ids_count)
    local g = ImGui.GetCurrentContext()
    local found = 0
    for _, settings in g.SettingsWindows:iter() do
        for node_n = 1, node_ids_count do
            if settings.DockId == node_ids[node_n] then
                settings.DockId = 0
                settings.DockOrder = -1
                found = found + 1
                if found < node_ids_count then break end
                return
            end
        end
    end
end

DockSettingsFindNodeSettings = function(ctx, id)
    for _, s in ctx.DockContext.NodesSettings:iter() do
        if s.ID == id then return s end
    end
    return nil
end

DockSettingsHandler_ClearAll = function(ctx, handler)
    local dc = ctx.DockContext
    dc.NodesSettings:clear()
    ImGui.DockContextClearNodes(ctx, 0, true)
end

DockSettingsHandler_ApplyAll = function(ctx, handler)
    local dc = ctx.DockContext
    if ctx.Windows.Size == 0 then ImGui.DockContextPruneUnusedSettingsNodes(ctx) end
    ImGui.DockContextBuildNodesFromSettings(ctx, dc.NodesSettings.Data or {}, dc.NodesSettings.Size)
    ImGui.DockContextBuildAddWindowsToNodes(ctx, 0)
end

DockSettingsHandler_ReadOpen = function(ctx, handler, name)
    if name ~= "Data" then return nil end
    return true
end

DockSettingsHandler_ReadLine = function(ctx, handler, entry, line)
    local node = ImGuiDockNodeSettings()
    line = line:gsub("^[ \t]+", "")
    if line:sub(1, 8) == "DockNode" then
        line = line:sub(9)
    elseif line:sub(1, 9) == "DockSpace" then
        line = line:sub(10)
        node.Flags = bit32.bor(node.Flags, ImGuiDockNodeFlags.DockSpace)
    else
        return
    end
    line = line:gsub("^[ \t]+", "")
    local function take(pattern)
        local caps = { line:match("^" .. pattern .. "()") }
        if #caps == 0 then return nil end
        line = line:sub(caps[#caps])
        caps[#caps] = nil
        return table.unpack(caps)
    end
    local v = take("ID=0x(%x+)")
    if not v then return end
    node.ID = tonumber(v, 16)
    v = take(" Parent=0x(%x+)")
    if v then node.ParentNodeId = tonumber(v, 16); if node.ParentNodeId == 0 then return end end
    v = take(" Window=0x(%x+)")
    if v then node.ParentWindowId = tonumber(v, 16); if node.ParentWindowId == 0 then return end end
    if node.ParentNodeId == 0 then
        local x, y = take(" Pos=(%-?%d+),(%-?%d+)")
        if not x then return end
        node.Pos = ImVec2(tonumber(x), tonumber(y))
        x, y = take(" Size=(%-?%d+),(%-?%d+)")
        if not x then return end
        node.Size = ImVec2(tonumber(x), tonumber(y))
    else
        local x, y = take(" SizeRef=(%-?%d+),(%-?%d+)")
        if x then node.SizeRef = ImVec2(tonumber(x), tonumber(y)) end
    end
    local c = take(" Split=(%a)")
    if c then
        if c == "X" then node.SplitAxis = ImGuiAxis.X elseif c == "Y" then node.SplitAxis = ImGuiAxis.Y end
    end
    local function flag(name, f)
        local x = take(" " .. name .. "=(%-?%d+)")
        if x and tonumber(x) ~= 0 then node.Flags = bit32.bor(node.Flags, f) end
    end
    flag("NoResize", ImGuiDockNodeFlags.NoResize)
    flag("CentralNode", ImGuiDockNodeFlags.CentralNode)
    flag("NoTabBar", ImGuiDockNodeFlags.NoTabBar)
    flag("HiddenTabBar", ImGuiDockNodeFlags.HiddenTabBar)
    flag("NoWindowMenuButton", ImGuiDockNodeFlags.NoWindowMenuButton)
    flag("NoCloseButton", ImGuiDockNodeFlags.NoCloseButton)
    v = take(" Selected=0x(%x+)")
    if v then node.SelectedTabId = tonumber(v, 16) end
    if node.ParentNodeId ~= 0 then
        local parent_settings = DockSettingsFindNodeSettings(ctx, node.ParentNodeId)
        if parent_settings then node.Depth = parent_settings.Depth + 1 end
    end
    ctx.DockContext.NodesSettings:push_back(node)
end

local function DockSettingsHandler_DockNodeToSettings(dc, node, depth)
    local node_settings = ImGuiDockNodeSettings()
    node_settings.ID = node.ID
    node_settings.ParentNodeId = node.ParentNode and node.ParentNode.ID or 0
    node_settings.ParentWindowId = (node:IsDockSpace() and node.HostWindow and node.HostWindow.ParentWindow) and node.HostWindow.ParentWindow.ID or 0
    node_settings.SelectedTabId = node.SelectedTabId
    node_settings.SplitAxis = node:IsSplitNode() and node.SplitAxis or ImGuiAxis.None
    node_settings.Depth = depth
    node_settings.Flags = bit32.band(node.LocalFlags, ImGuiDockNodeFlags.SavedFlagsMask_)
    node_settings.Pos = ImVec2(ImTrunc(node.Pos.x), ImTrunc(node.Pos.y))
    node_settings.Size = ImVec2(ImTrunc(node.Size.x), ImTrunc(node.Size.y))
    node_settings.SizeRef = ImVec2(ImTrunc(node.SizeRef.x), ImTrunc(node.SizeRef.y))
    dc.NodesSettings:push_back(node_settings)
    if node.ChildNodes[0] then DockSettingsHandler_DockNodeToSettings(dc, node.ChildNodes[0], depth + 1) end
    if node.ChildNodes[1] then DockSettingsHandler_DockNodeToSettings(dc, node.ChildNodes[1], depth + 1) end
end

DockSettingsHandler_WriteAll = function(ctx, handler, buf)
    local g = ctx
    local dc = ctx.DockContext
    if bit32.band(g.IO.ConfigFlags, ImGuiConfigFlags.DockingEnable) == 0 then return end

    dc.NodesSettings:resize(0)
    for _, id in ipairs(DockContextNodesSorted(ctx)) do
        local node = dc.Nodes[id]
        if node and node:IsRootNode() then
            DockSettingsHandler_DockNodeToSettings(dc, node, 0)
        end
    end

    local max_depth = 0
    for _, s in dc.NodesSettings:iter() do max_depth = ImMax(s.Depth, max_depth) end

    buf:appendf("[%s][Data]\n", handler.TypeName)
    for _, s in dc.NodesSettings:iter() do
        buf:append(string.rep(" ", s.Depth * 2) .. ((bit32.band(s.Flags, ImGuiDockNodeFlags.DockSpace) ~= 0) and "DockSpace" or "DockNode ") .. string.rep(" ", (max_depth - s.Depth) * 2))
        buf:appendf(" ID=0x%08X", s.ID)
        if s.ParentNodeId ~= 0 then
            buf:appendf(" Parent=0x%08X SizeRef=%d,%d", s.ParentNodeId, s.SizeRef.x, s.SizeRef.y)
        else
            if s.ParentWindowId ~= 0 then buf:appendf(" Window=0x%08X", s.ParentWindowId) end
            buf:appendf(" Pos=%d,%d Size=%d,%d", s.Pos.x, s.Pos.y, s.Size.x, s.Size.y)
        end
        if s.SplitAxis ~= ImGuiAxis.None then buf:appendf(" Split=%s", (s.SplitAxis == ImGuiAxis.X) and "X" or "Y") end
        if bit32.band(s.Flags, ImGuiDockNodeFlags.NoResize) ~= 0 then buf:append(" NoResize=1") end
        if bit32.band(s.Flags, ImGuiDockNodeFlags.CentralNode) ~= 0 then buf:append(" CentralNode=1") end
        if bit32.band(s.Flags, ImGuiDockNodeFlags.NoTabBar) ~= 0 then buf:append(" NoTabBar=1") end
        if bit32.band(s.Flags, ImGuiDockNodeFlags.HiddenTabBar) ~= 0 then buf:append(" HiddenTabBar=1") end
        if bit32.band(s.Flags, ImGuiDockNodeFlags.NoWindowMenuButton) ~= 0 then buf:append(" NoWindowMenuButton=1") end
        if bit32.band(s.Flags, ImGuiDockNodeFlags.NoCloseButton) ~= 0 then buf:append(" NoCloseButton=1") end
        if s.SelectedTabId ~= 0 then buf:appendf(" Selected=0x%08X", s.SelectedTabId) end
        buf:append("\n")
    end
    buf:append("\n")
end

---------------------------------------------------------------------------------------
-- Docking: helpers (imgui_internal.h inlines) + widgets used by docking
---------------------------------------------------------------------------------------

function ImGui.DockNodeGetRootNode(node)
    while node.ParentNode do node = node.ParentNode end
    return node
end

function ImGui.DockNodeIsInHierarchyOf(node, parent)
    while node do
        if node == parent then return true end
        node = node.ParentNode
    end
    return false
end

function ImGui.DockNodeGetDepth(node)
    local depth = 0
    while node.ParentNode do node = node.ParentNode; depth = depth + 1 end
    return depth
end

function ImGui.DockNodeGetWindowMenuButtonId(node)
    return ImHashStr("#COLLAPSE", nil, node.ID)
end

function ImGui.GetWindowDockID()
    return ImGui.GetCurrentContext().CurrentWindow.DockId
end

function ImGui.IsWindowDocked()
    return ImGui.GetCurrentContext().CurrentWindow.DockIsActive
end

function ImGui.SetNextWindowDockID(id, cond)
    local g = ImGui.GetCurrentContext()
    g.NextWindowData.HasFlags = bit32.bor(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasDock)
    g.NextWindowData.DockCond = (cond and cond ~= 0) and cond or ImGuiCond.Always
    g.NextWindowData.DockId = id
end

function ImGui.StartMouseMovingWindowOrNode(window, node, undock)
    local g = ImGui.GetCurrentContext()
    local can_undock_node = false
    if undock and node ~= nil and node.VisibleWindow and bit32.band(node.VisibleWindow.Flags, ImGuiWindowFlags.NoMove) == 0 and bit32.band(node.MergedFlags, ImGuiDockNodeFlags.NoUndocking) == 0 then
        local root_node = ImGui.DockNodeGetRootNode(node)
        if root_node.OnlyNodeWithWindows ~= node or root_node.CentralNode ~= nil then
            can_undock_node = true
        end
    end

    local clicked = ImGui.IsMouseClicked(0)
    local dragging = ImGui.IsMouseDragging(0)
    if can_undock_node and dragging then
        ImGui.DockContextQueueUndockNode(g, node)
    elseif not can_undock_node and (clicked or dragging) and g.MovingWindow ~= window then
        ImGui.StartMouseMovingWindow(window)
    end
end

function ImGui.RenderArrowDockMenu(draw_list, p_min, sz, col)
    draw_list:AddRectFilled(p_min + ImVec2(sz * 0.20, sz * 0.15), p_min + ImVec2(sz * 0.80, sz * 0.30), col)
    ImGui.RenderArrowPointingAt(draw_list, p_min + ImVec2(sz * 0.50, sz * 0.85), ImVec2(sz * 0.30, sz * 0.40), ImGuiDir.Down, col)
end

-- Upstream CollapseButton (docking branch): replaces the port's simpler version
function ImGui.CollapseButton(id, pos, dock_node)
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow

    local bb = ImRect(pos, pos + ImVec2(g.FontSize, g.FontSize))
    local is_clipped = not ImGui.ItemAdd(bb, id)
    local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, ImGuiButtonFlags.None)
    if is_clipped then return pressed end

    local bg_col = ImGui.GetColorU32((held and hovered) and ImGuiCol.ButtonActive or (hovered and ImGuiCol.ButtonHovered or ImGuiCol.Button))
    local text_col = ImGui.GetColorU32(ImGuiCol.Text)
    if hovered or held then
        window.DrawList:AddRectFilled(bb.Min, bb.Max, bg_col)
    end
    ImGui.RenderNavCursor(bb, id, ImGuiNavRenderCursorFlags and ImGuiNavRenderCursorFlags.Compact or nil)

    if dock_node then
        ImGui.RenderArrowDockMenu(window.DrawList, bb.Min, g.FontSize, text_col)
    else
        ImGui.RenderArrow(window.DrawList, bb.Min, text_col, window.Collapsed and ImGuiDir.Right or ImGuiDir.Down, 1.0)
    end

    if ImGui.IsItemActive() and ImGui.IsMouseDragging(0) then
        ImGui.StartMouseMovingWindowOrNode(window, dock_node, true)
    end

    return pressed
end

--- @return bool held, float size1, float size2
function ImGui.SplitterBehavior(bb, id, axis, size1, size2, min_size1, min_size2, hover_extend, hover_visibility_delay, bg_col)
    hover_extend = hover_extend or 0.0
    hover_visibility_delay = hover_visibility_delay or 0.0
    bg_col = bg_col or 0
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow

    if not ImGui.ItemAdd(bb, id, nil, ImGuiItemFlags.NoNav) then return false, size1, size2 end

    local button_flags = bit32.bor(ImGuiButtonFlags.FlattenChildren, ImGuiButtonFlags.AllowOverlap)

    local bb_interact = ImRect(bb.Min, bb.Max)
    bb_interact:Expand(axis == ImGuiAxis.Y and ImVec2(0.0, hover_extend) or ImVec2(hover_extend, 0.0))
    local _, hovered, held = ImGui.ButtonBehavior(bb_interact, id, button_flags)
    if hovered then
        g.LastItemData.StatusFlags = bit32.bor(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredRect)
    end

    if held or (hovered and g.HoveredIdPreviousFrame == id and g.HoveredIdTimer >= hover_visibility_delay) then
        ImGui.SetMouseCursor(axis == ImGuiAxis.Y and ImGuiMouseCursor.ResizeNS or ImGuiMouseCursor.ResizeEW)
    end

    local bb_render = ImRect(bb.Min, bb.Max)
    if held then
        local d = g.IO.MousePos - g.ActiveIdClickOffset - bb_interact.Min
        local mouse_delta = d[axis]

        local size_1_maximum_delta = ImMax(0.0, size1 - min_size1)
        local size_2_maximum_delta = ImMax(0.0, size2 - min_size2)
        if mouse_delta < -size_1_maximum_delta then mouse_delta = -size_1_maximum_delta end
        if mouse_delta > size_2_maximum_delta then mouse_delta = size_2_maximum_delta end

        if mouse_delta ~= 0.0 then
            size1 = ImMax(size1 + mouse_delta, min_size1)
            size2 = ImMax(size2 - mouse_delta, min_size2)
            bb_render:Translate(axis == ImGuiAxis.X and ImVec2(mouse_delta, 0.0) or ImVec2(0.0, mouse_delta))
            ImGui.MarkItemEdited(id)
        end
    end

    if bit32.band(bg_col, IM_COL32_A_MASK) ~= 0 then
        window.DrawList:AddRectFilled(bb_render.Min, bb_render.Max, bg_col, 0.0)
    end
    local col = ImGui.GetColorU32(held and ImGuiCol.SeparatorActive or ((hovered and g.HoveredIdTimer >= hover_visibility_delay) and ImGuiCol.SeparatorHovered or ImGuiCol.Separator))
    window.DrawList:AddRectFilled(bb_render.Min, bb_render.Max, col, 0.0)

    return held, size1, size2
end

return true
