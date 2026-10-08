--- Dear ImGui WIP
-- (Tables and Columns Code)
-- 1:1 port of imgui_tables.cpp (docking branch, 1.93 WIP)
--
-- Port notes:
-- - Column indices / display orders / draw channel indices are 0-based VALUES like upstream.
--   Per-column arrays (table.Columns, table.DisplayOrderToIndex, table.RowCellData) are Lua tables with 0-based keys.
--   table.ColumnsSize mirrors upstream `table->Columns.size()`.
-- - ImBitArray masks are Lua tables { [n] = true }.
-- - table.ColumnsNames is a Lua array of strings, column.NameOffset is a 0-based index into it (-1 = none).
-- - g.SettingsTables is a plain vector of ImGuiTableSettings; table.SettingsOffset is a 1-based index into it (-1 = none).
--   Each settings entry owns `Columns` (0-based Lua table of ImGuiTableColumnSettings).
-- - ImGuiTableSortSpecs.Specs is a 1-based Lua array of ImGuiTableColumnSortSpecs.

--- @type ImGuiContext?
local GImGui

local MT = ImGui.GetMetatables()

-- Sets local `GImGui` in this file(imgui_tables.lua).
-- This is currently only used in main code `ImGui.SetCurrentContext()`
--- @param ctx ImGuiContext?
function ImGui._SetCurrentContext_Tables(ctx)
    GImGui = ctx
end

local bit32 = bit32
local band, bor, bnot, lshift, rshift = bit32.band, bit32.bor, bit32.bnot, bit32.lshift, bit32.rshift

IM_COL32_DISABLE = IM_COL32(0, 0, 0, 1)
IMGUI_TABLE_MAX_COLUMNS = 512

local function IMGUI_DEBUG_LOG_TABLE(fmt, ...)
    local g = GImGui
    if band(g.DebugLogFlags, ImGuiDebugLogFlags.EventTable) ~= 0 then ImGui.DebugLog(fmt, ...) end
end

----------------------------------------------------------------
-- [SECTION] Structs
----------------------------------------------------------------

local function BitArrayClearAll(arr) table.clear(arr) end
local function BitArraySet(arr, n) arr[n] = true end
local function BitTest(arr, n) return arr[n] == true end

--- @class ImGuiTableColumnSortSpecs
function ImGuiTableColumnSortSpecs()
    return { ColumnUserID = 0, ColumnIndex = 0, SortOrder = 0, SortDirection = ImGuiSortDirection.None }
end

--- @class ImGuiTableSortSpecs
function ImGuiTableSortSpecs()
    return { Specs = nil, SpecsCount = 0, SpecsDirty = false }
end

--- @class ImGuiTableColumn
function ImGuiTableColumn()
    return {
        Flags = 0, WidthGiven = 0.0, MinX = 0.0, MaxX = 0.0, WidthRequest = -1.0, WidthAuto = 0.0, WidthMax = 0.0,
        StretchWeight = -1.0, InitStretchWeightOrWidth = 0.0, ClipRect = ImRect(), ID = 0, UserData = 0,
        WorkMinX = 0.0, WorkMaxX = 0.0, ItemWidth = 0.0, ContentMaxXFrozen = 0.0, ContentMaxXUnfrozen = 0.0,
        ContentMaxXHeadersUsed = 0.0, ContentMaxXHeadersIdeal = 0.0, NameOffset = -1, DisplayOrder = -1,
        IndexWithinEnabledSet = -1, PrevEnabledColumn = -1, NextEnabledColumn = -1, SortOrder = -1,
        DrawChannelCurrent = -1, DrawChannelFrozen = -1, DrawChannelUnfrozen = -1,
        IsEnabled = false, IsUserEnabled = false, IsUserEnabledNextFrame = false, IsVisibleX = false, IsVisibleY = false,
        IsRequestOutput = false, IsSkipItems = false, IsPreserveWidthAuto = false, IsJustCreated = true,
        IsLoadedSettings = false, IsNeedReconcileSrc = false, IsNeedReconcileDst = false,
        NavLayerCurrent = 0, AutoFitQueue = 0, CannotSkipItemsQueue = 0, SortDirection = ImGuiSortDirection.None,
        SortDirectionsAvailCount = 0, SortDirectionsAvailMask = 0, SortDirectionsAvailList = 0,
    }
end

--- `*dst = *src`
local function TableColumnCopy(dst, src)
    for k, v in pairs(src) do
        if k ~= "ClipRect" then dst[k] = v end
    end
    ImRect_Copy(dst.ClipRect, src.ClipRect)
    return dst
end

local function TableColumnClone(src)
    return TableColumnCopy(ImGuiTableColumn(), src)
end

--- @class ImGuiTableInstanceData
function ImGuiTableInstanceData()
    return { TableInstanceID = 0, LastOuterHeight = 0.0, LastTopHeadersRowHeight = 0.0, LastFrozenHeight = 0.0, HoveredRowLast = -1, HoveredRowNext = -1 }
end

--- @class ImGuiTableTempData
function ImGuiTableTempData()
    return {
        WindowID = 0, TableIndex = 0, LastTimeActive = -1.0, AngledHeadersExtraWidth = 0.0,
        AngledHeadersRequests = ImVector(), ReconcileColumnsRequests = ImVector(),
        OldColumnsRawData = nil, OldColumnsData = nil, OldColumnsDataSize = 0,
        UserOuterSize = ImVec2(), DrawSplitter = ImDrawListSplitter(),
        HostBackupWorkRect = ImRect(), HostBackupParentWorkRect = ImRect(),
        HostBackupPrevLineSize = ImVec2(), HostBackupCurrLineSize = ImVec2(), HostBackupCursorMaxPos = ImVec2(),
        HostBackupColumnsOffset = 0.0, HostBackupItemWidth = 0.0, HostBackupItemWidthStackSize = 0,
    }
end

--- @class ImGuiTable
function ImGuiTable()
    return {
        ID = 0, Flags = 0, RawData = nil, TempData = nil,
        Columns = {}, ColumnsSize = 0, DisplayOrderToIndex = {}, RowCellData = {},
        EnabledMaskByDisplayOrder = {}, EnabledMaskByIndex = {}, VisibleMaskByIndex = {},
        SettingsLoadedFlags = 0, SettingsOffset = 0, LastFrameActive = -1, ColumnsCount = 0, CurrentRow = 0, CurrentColumn = 0,
        InstanceCurrent = 0, InstanceInteracted = 0, RowPosY1 = 0.0, RowPosY2 = 0.0, RowMinHeight = 0.0, RowCellPaddingY = 0.0,
        RowTextBaseline = 0.0, RowIndentOffsetX = 0.0, RowFlags = 0, LastRowFlags = 0, RowBgColorCounter = 0,
        RowBgColor = { [0] = 0, [1] = 0 }, BorderColorStrong = 0, BorderColorLight = 0, BorderX1 = 0.0, BorderX2 = 0.0,
        HostIndentX = 0.0, MinColumnWidth = 0.0, OuterPaddingX = 0.0, CellPaddingX = 0.0, CellSpacingX1 = 0.0, CellSpacingX2 = 0.0,
        InnerWidth = 0.0, ColumnsGivenWidth = 0.0, ColumnsAutoFitWidth = 0.0, ColumnsStretchSumWeights = 0.0,
        ResizedColumnNextWidth = 0.0, ResizeLockMinContentsX2 = 0.0, RefScale = 0.0, AngledHeadersHeight = 0.0, AngledHeadersSlope = 0.0,
        OuterRect = ImRect(), InnerRect = ImRect(), WorkRect = ImRect(), InnerClipRect = ImRect(), BgClipRect = ImRect(),
        Bg0ClipRectForDrawCmd = ImRect(), Bg2ClipRectForDrawCmd = ImRect(), HostClipRect = ImRect(), HostBackupInnerClipRect = ImRect(),
        OuterWindow = nil, InnerWindow = nil, ColumnsNames = {}, DrawSplitter = nil,
        InstanceDataFirst = ImGuiTableInstanceData(), InstanceDataExtra = ImVector(),
        SortSpecs = ImGuiTableSortSpecs(), SortSpecsMulti = {}, SortSpecsSingle = ImGuiTableColumnSortSpecs(),
        SortSpecsCount = 0, ColumnsEnabledCount = 0, ColumnsEnabledFixedCount = 0, DeclColumnsCount = 0, AngledHeadersCount = 0,
        HoveredColumnBody = 0, HoveredColumnBorder = 0, HighlightColumnHeader = 0, AutoFitSingleColumn = 0, ResizedColumn = 0,
        LastResizedColumn = 0, HeldHeaderColumn = 0, LastHeldHeaderColumn = 0, ReorderColumn = 0, ReorderColumnDstOrder = 0,
        LeftMostEnabledColumn = 0, RightMostEnabledColumn = 0, LeftMostStretchedColumn = 0, RightMostStretchedColumn = 0,
        ContextPopupColumn = 0, FreezeRowsRequest = 0, FreezeRowsCount = 0, FreezeColumnsRequest = 0, FreezeColumnsCount = 0,
        RowCellDataCurrent = 0, DummyDrawChannel = 0, Bg2DrawChannelCurrent = 0, Bg2DrawChannelUnfrozen = 0, NavLayer = 0,
        IsLayoutLocked = false, IsInsideRow = false, IsNewTable = false, IsInitializing = false, IsReconcileMode = false,
        IsSortSpecsDirty = false, IsUsingHeaders = false, IsContextPopupOpen = false, DisableDefaultContextMenu = false,
        IsSettingsRequestLoad = false, IsSettingsDirty = false, IsDefaultDisplayOrder = false, IsDefaultVisibility = false,
        IsResetAllRequest = false, IsResetDisplayOrderRequest = false, IsResetVisibilityRequest = false, IsUnfrozenRows = false,
        IsDefaultSizingPolicy = false, IsActiveIdAliveBeforeTable = false, IsActiveIdInTable = false,
        HasScrollbarYCurr = false, HasScrollbarYPrev = false, MemoryCompacted = false, HostSkipItems = false,
    }
end

--- @class ImGuiTableColumnSettings
function ImGuiTableColumnSettings()
    return { WidthOrWeight = 0.0, ID = 0, Index = -1, DisplayOrder = -1, SortOrder = -1, SortDirection = ImGuiSortDirection.None,
             IsEnabled = -1, IsStretch = 0, IsLoaded = false }
end

--- @class ImGuiTableSettings
function ImGuiTableSettings()
    return { ID = 0, SaveFlags = 0, RefScale = 0.0, ColumnsCount = 0, ColumnsCountMax = 0, LastUsedDate = 0, WantApply = false, Columns = {} }
end

--- @class ImGuiOldColumnData
function ImGuiOldColumnData()
    return { OffsetNorm = 0.0, OffsetNormBeforeResize = 0.0, Flags = 0, ClipRect = ImRect() }
end

--- @class ImGuiOldColumns
function ImGuiOldColumns()
    return { ID = 0, Flags = 0, IsFirstFrame = false, IsBeingResized = false, Current = 0, Count = 0, OffMinX = 0.0, OffMaxX = 0.0,
             LineMinY = 0.0, LineMaxY = 0.0, HostCursorPosY = 0.0, HostCursorMaxPosX = 0.0, HostInitialClipRect = ImRect(),
             HostBackupClipRect = ImRect(), HostBackupParentWorkRect = ImRect(), Columns = ImVector(), Splitter = ImDrawListSplitter() }
end

ImGuiOldColumnFlags = ImGuiOldColumnFlags or {
    None                   = 0,
    NoBorder               = lshift(1, 0),
    NoResize               = lshift(1, 1),
    NoPreserveWidths       = lshift(1, 2),
    NoForceWithinWindow    = lshift(1, 3),
    GrowParentContentsSize = lshift(1, 4),
}

ImGuiTableColumnFlags.NoDirectResize_ = ImGuiTableColumnFlags.NoDirectResize_ or lshift(1, 30)

local function Rect(r) return ImRect(r.Min.x, r.Min.y, r.Max.x, r.Max.y) end
local function V2(v) return ImVec2(v.x, v.y) end

----------------------------------------------------------------
-- [SECTION] Tables: Main code
----------------------------------------------------------------

-- Configuration
local TABLE_DRAW_CHANNEL_BG0 = 0
local TABLE_DRAW_CHANNEL_BG2_FROZEN = 1
local TABLE_DRAW_CHANNEL_NOCLIP = 2                    -- When using ImGuiTableFlags_NoClip (this becomes the last visible channel)
local TABLE_BORDER_SIZE = 1.0                          -- FIXME-TABLE: Currently hard-coded because of clipping assumptions with outer borders rendering.
local TABLE_RESIZE_SEPARATOR_HALF_THICKNESS = 4.0      -- Extend outside inner borders.
local TABLE_RESIZE_SEPARATOR_FEEDBACK_TIMER = 0.06     -- Delay/timer before making the hover feedback (color+cursor) visible because tables/columns tends to be more cramped.

-- Helper
local function TableFixFlags(flags, outer_window)
    -- Adjust flags: set default sizing policy
    if band(flags, ImGuiTableFlags.SizingMask_) == 0 then
        flags = bor(flags, (band(flags, ImGuiTableFlags.ScrollX) ~= 0 or band(outer_window.Flags, ImGuiWindowFlags.AlwaysAutoResize) ~= 0) and ImGuiTableFlags.SizingFixedFit or ImGuiTableFlags.SizingStretchSame)
    end

    -- Adjust flags: enable NoKeepColumnsVisible when using ImGuiTableFlags_SizingFixedSame
    if band(flags, ImGuiTableFlags.SizingMask_) == ImGuiTableFlags.SizingFixedSame then
        flags = bor(flags, ImGuiTableFlags.NoKeepColumnsVisible)
    end

    -- Adjust flags: enforce borders when resizable
    if band(flags, ImGuiTableFlags.Resizable) ~= 0 then
        flags = bor(flags, ImGuiTableFlags.BordersInnerV)
    end

    -- Adjust flags: disable NoHostExtendX/NoHostExtendY if we have any scrolling going on
    if band(flags, bor(ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY)) ~= 0 then
        flags = band(flags, bnot(bor(ImGuiTableFlags.NoHostExtendX, ImGuiTableFlags.NoHostExtendY)))
    end

    -- Adjust flags: NoBordersInBodyUntilResize takes priority over NoBordersInBody
    if band(flags, ImGuiTableFlags.NoBordersInBodyUntilResize) ~= 0 then
        flags = band(flags, bnot(ImGuiTableFlags.NoBordersInBody))
    end

    -- Adjust flags: disable saved settings if there's nothing to save
    if band(flags, bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Hideable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Sortable)) == 0 then
        flags = bor(flags, ImGuiTableFlags.NoSavedSettings)
    end

    -- Inherit _NoSavedSettings from top-level window (child windows always have _NoSavedSettings set)
    if band(outer_window.RootWindow.Flags, ImGuiWindowFlags.NoSavedSettings) ~= 0 then
        flags = bor(flags, ImGuiTableFlags.NoSavedSettings)
    end

    return flags
end

function ImGui.TableFindByID(id)
    local g = GImGui
    return g.Tables:GetByKey(id)
end

--- @param table_ ImGuiTable
--- @param instance_no int
function ImGui.TableGetInstanceData(table_, instance_no)
    if instance_no == 0 then
        return table_.InstanceDataFirst
    end
    return table_.InstanceDataExtra.Data[instance_no]
end

function ImGui.TableGetInstanceID(table_, instance_no)
    return ImGui.TableGetInstanceData(table_, instance_no).TableInstanceID
end

-- Read about "TABLE SIZING" at the top of this file.
--- @param str_id        string
--- @param columns_count int
--- @param flags?        ImGuiTableFlags
--- @param outer_size?   ImVec2
--- @param inner_width?  float
function ImGui.BeginTable(str_id, columns_count, flags, outer_size, inner_width)
    local id = ImGui.GetID(str_id)
    return ImGui.BeginTableEx(str_id, id, columns_count, flags, outer_size, inner_width)
end

function ImGui.BeginTableEx(name, id, columns_count, flags, outer_size, inner_width)
    if flags       == nil then flags       = 0                end
    if outer_size  == nil then outer_size  = ImVec2(0.0, 0.0) end
    if inner_width == nil then inner_width = 0.0              end

    local g = GImGui
    local outer_window = ImGui.GetCurrentWindow()
    if outer_window.SkipItems then -- Consistent with other tables + beneficial side effect that assert on miscalling EndTable() will be more visible.
        return false
    end

    -- Sanity checks
    IM_ASSERT(columns_count > 0 and columns_count < IMGUI_TABLE_MAX_COLUMNS)
    if band(flags, ImGuiTableFlags.ScrollX) ~= 0 then
        IM_ASSERT(inner_width >= 0.0)
    end

    -- If an outer size is specified ahead we will be able to early out when not visible. Exact clipping criteria may evolve.
    local use_child_window = band(flags, bor(ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY)) ~= 0
    local avail_size = ImGui.GetContentRegionAvail()
    local actual_outer_size = ImTrunc(ImGui.CalcItemSize(outer_size, ImMax(avail_size.x, IMGUI_WINDOW_HARD_MIN_SIZE), use_child_window and ImMax(avail_size.y, IMGUI_WINDOW_HARD_MIN_SIZE) or 0.0))
    local outer_rect = ImRect(outer_window.DC.CursorPos, outer_window.DC.CursorPos + actual_outer_size)
    local outer_window_is_measuring_size = (outer_window.AutoFitFramesX > 0) or (outer_window.AutoFitFramesY > 0) -- Doesn't apply to AlwaysAutoResize windows!
    if use_child_window and ImGui.IsClippedEx(outer_rect, 0) and not outer_window_is_measuring_size then
        ImGui.ItemSize(outer_rect)
        ImGui.ItemAdd(outer_rect, id)
        g.NextWindowData:ClearFlags()
        return false
    end

    -- Acquire storage for the table
    local table_ = g.Tables:GetOrAddByKey(id)
    if table_.Columns == nil then -- pool created a plain table
        for k, v in pairs(ImGuiTable()) do table_[k] = v end
    end

    -- Acquire temporary buffers
    local table_idx = g.Tables:GetIndex(table_)
    g.TablesTempDataStacked = g.TablesTempDataStacked + 1
    while g.TablesTempDataStacked > g.TablesTempData.Size do
        g.TablesTempData:push_back(ImGuiTableTempData())
    end
    local temp_data = g.TablesTempData.Data[g.TablesTempDataStacked]
    table_.TempData = temp_data
    temp_data.TableIndex = table_idx
    temp_data.ReconcileColumnsRequests:resize(0)
    table_.DrawSplitter = table_.TempData.DrawSplitter
    table_.DrawSplitter:Clear()

    -- Fix flags
    table_.IsDefaultSizingPolicy = band(flags, ImGuiTableFlags.SizingMask_) == 0
    flags = TableFixFlags(flags, outer_window)

    -- Initialize
    local previous_frame_active = table_.LastFrameActive
    local instance_no = (previous_frame_active ~= g.FrameCount) and 0 or (table_.InstanceCurrent + 1)
    local previous_flags = table_.Flags
    table_.ID = id
    table_.Flags = flags
    table_.LastFrameActive = g.FrameCount
    table_.OuterWindow = outer_window
    table_.InnerWindow = outer_window
    table_.ColumnsCount = columns_count
    table_.IsLayoutLocked = false
    table_.InnerWidth = inner_width
    table_.NavLayer = outer_window.DC.NavLayerCurrent
    table_.IsNewTable = (previous_frame_active == -1)
    ImVec2_Copy(temp_data.UserOuterSize, outer_size)

    -- Instance data (for instance 0, TableID == TableInstanceID)
    local instance_id
    table_.InstanceCurrent = instance_no
    if instance_no > 0 then
        IM_ASSERT(table_.ColumnsCount == columns_count, "BeginTable(): Cannot change columns count mid-frame while preserving same ID")
        if table_.InstanceDataExtra.Size < instance_no then
            table_.InstanceDataExtra:push_back(ImGuiTableInstanceData())
        end
        instance_id = ImGui.GetIDWithSeed(instance_no, ImGui.GetIDWithSeed("##Instances", nil, id)) -- Push "##Instances" followed by (int)instance_no in ID stack.
    else
        instance_id = id
    end
    local table_instance = ImGui.TableGetInstanceData(table_, table_.InstanceCurrent)
    table_instance.TableInstanceID = instance_id

    -- When not using a child window, WorkRect.Max will grow as we append contents.
    if use_child_window then
        -- Ensure no vertical scrollbar appears if we only want horizontal one, to make flag consistent
        local override_content_size = ImVec2(FLT_MAX, FLT_MAX)
        if band(flags, ImGuiTableFlags.ScrollX) ~= 0 and band(flags, ImGuiTableFlags.ScrollY) == 0 then
            override_content_size.y = FLT_MIN
        end

        -- Ensure specified width (when not specified, Stretched columns will act as if the width == OuterWidth and never lead to any scrolling).
        if band(flags, ImGuiTableFlags.ScrollX) ~= 0 and inner_width > 0.0 then
            override_content_size.x = inner_width
        end

        if override_content_size.x ~= FLT_MAX or override_content_size.y ~= FLT_MAX then
            ImGui.SetNextWindowContentSize(ImVec2((override_content_size.x ~= FLT_MAX) and override_content_size.x or 0.0, (override_content_size.y ~= FLT_MAX) and override_content_size.y or 0.0))
        end

        -- Reset scroll if we are reactivating it
        if band(previous_flags, bor(ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY)) == 0 then
            if band(g.NextWindowData.HasFlags, ImGuiNextWindowDataFlags.HasScroll) == 0 then
                ImGui.SetNextWindowScroll(ImVec2(0.0, 0.0))
            end
        end

        -- Create scrolling region (without border and zero window padding)
        local child_window_flags = (band(flags, ImGuiTableFlags.ScrollX) ~= 0) and ImGuiWindowFlags.HorizontalScrollbar or ImGuiWindowFlags.None
        ImGui.BeginChildEx(name, instance_id, outer_rect:GetSize(), ImGuiChildFlags.None, child_window_flags)
        table_.InnerWindow = g.CurrentWindow
        ImRect_Copy(table_.WorkRect, table_.InnerWindow.WorkRect)
        ImRect_Copy(table_.OuterRect, table_.InnerWindow:Rect())
        ImRect_Copy(table_.InnerRect, table_.InnerWindow.InnerRect)
        IM_ASSERT(table_.InnerWindow.WindowPadding.x == 0.0 and table_.InnerWindow.WindowPadding.y == 0.0 and table_.InnerWindow.WindowBorderSize == 0.0)

        -- Allow submitting when host is measuring
        if table_.InnerWindow.SkipItems and outer_window_is_measuring_size then
            table_.InnerWindow.SkipItems = false
        end

        -- When using multiple instances, ensure they have the same amount of horizontal decorations (aka vertical scrollbar) so stretched columns can be aligned
        if instance_no == 0 then
            table_.HasScrollbarYPrev = table_.HasScrollbarYCurr
            table_.HasScrollbarYCurr = false
        end
        table_.HasScrollbarYCurr = table_.HasScrollbarYCurr or table_.InnerWindow.ScrollbarY
    else
        -- For non-scrolling tables, WorkRect == OuterRect == InnerRect.
        ImRect_Copy(table_.WorkRect, outer_rect)
        ImRect_Copy(table_.OuterRect, outer_rect)
        ImRect_Copy(table_.InnerRect, outer_rect)
        table_.HasScrollbarYPrev = false
        table_.HasScrollbarYCurr = false
        table_.InnerWindow.DC.TreeDepth = table_.InnerWindow.DC.TreeDepth + 1 -- This is designed to always linking ImGuiTreeNodeFlags_DrawLines linking across a table
    end

    -- Push a standardized ID for both child-using and not-child-using tables
    ImGui.PushOverrideID(id)
    if instance_no > 0 then
        ImGui.PushOverrideID(instance_id)
    end

    -- Backup a copy of host window members we will modify
    local inner_window = table_.InnerWindow
    table_.HostIndentX = inner_window.DC.Indent.x
    ImRect_Copy(table_.HostClipRect, inner_window.ClipRect)
    table_.HostSkipItems = inner_window.SkipItems
    temp_data.WindowID = inner_window.ID
    ImRect_Copy(temp_data.HostBackupWorkRect, inner_window.WorkRect)
    ImRect_Copy(temp_data.HostBackupParentWorkRect, inner_window.ParentWorkRect)
    temp_data.HostBackupColumnsOffset = outer_window.DC.ColumnsOffset.x
    ImVec2_Copy(temp_data.HostBackupPrevLineSize, inner_window.DC.PrevLineSize)
    ImVec2_Copy(temp_data.HostBackupCurrLineSize, inner_window.DC.CurrLineSize)
    ImVec2_Copy(temp_data.HostBackupCursorMaxPos, inner_window.DC.CursorMaxPos)
    temp_data.HostBackupItemWidth = outer_window.DC.ItemWidth
    temp_data.HostBackupItemWidthStackSize = outer_window.DC.ItemWidthStack.Size
    inner_window.DC.PrevLineSize.x = 0.0; inner_window.DC.PrevLineSize.y = 0.0
    inner_window.DC.CurrLineSize.x = 0.0; inner_window.DC.CurrLineSize.y = 0.0

    -- Make borders not overlap our contents by offsetting HostClipRect (#6765, #7428, #3752)
    if inner_window ~= outer_window then
        local border_size = TABLE_BORDER_SIZE
        if band(flags, ImGuiTableFlags.BordersOuterV) ~= 0 then
            table_.HostClipRect.Min.x = ImMin(table_.HostClipRect.Min.x + border_size, table_.HostClipRect.Max.x)
            if inner_window.DecoOuterSizeX2 == 0.0 then
                table_.HostClipRect.Max.x = ImMax(table_.HostClipRect.Max.x - border_size, table_.HostClipRect.Min.x)
            end
        end
        if band(flags, ImGuiTableFlags.BordersOuterH) ~= 0 then
            table_.HostClipRect.Min.y = ImMin(table_.HostClipRect.Min.y + border_size, table_.HostClipRect.Max.y)
            if inner_window.DecoOuterSizeY2 == 0.0 then
                table_.HostClipRect.Max.y = ImMax(table_.HostClipRect.Max.y - border_size, table_.HostClipRect.Min.y)
            end
        end
    end

    -- Padding and Spacing
    local pad_outer_x
    if band(flags, ImGuiTableFlags.NoPadOuterX) ~= 0 then pad_outer_x = false
    elseif band(flags, ImGuiTableFlags.PadOuterX) ~= 0 then pad_outer_x = true
    else pad_outer_x = band(flags, ImGuiTableFlags.BordersOuterV) ~= 0 end
    local pad_inner_x = band(flags, ImGuiTableFlags.NoPadInnerX) == 0
    local inner_spacing_for_border = (band(flags, ImGuiTableFlags.BordersInnerV) ~= 0) and TABLE_BORDER_SIZE or 0.0
    local inner_spacing_explicit = (pad_inner_x and band(flags, ImGuiTableFlags.BordersInnerV) == 0) and g.Style.CellPadding.x or 0.0
    local inner_padding_explicit = (pad_inner_x and band(flags, ImGuiTableFlags.BordersInnerV) ~= 0) and g.Style.CellPadding.x or 0.0
    table_.CellSpacingX1 = inner_spacing_explicit + inner_spacing_for_border
    table_.CellSpacingX2 = inner_spacing_explicit
    table_.CellPaddingX = inner_padding_explicit

    local outer_padding_for_border = (band(flags, ImGuiTableFlags.BordersOuterV) ~= 0) and TABLE_BORDER_SIZE or 0.0
    local outer_padding_explicit = pad_outer_x and g.Style.CellPadding.x or 0.0
    table_.OuterPaddingX = (outer_padding_for_border + outer_padding_explicit) - table_.CellPaddingX

    table_.CurrentColumn = -1
    table_.CurrentRow = -1
    table_.RowBgColorCounter = 0
    table_.LastRowFlags = ImGuiTableRowFlags.None
    ImRect_Copy(table_.InnerClipRect, (inner_window == outer_window) and table_.WorkRect or inner_window.ClipRect)
    table_.InnerClipRect:ClipWith(table_.WorkRect)     -- We need this to honor inner_width
    table_.InnerClipRect:ClipWithFull(table_.HostClipRect)
    table_.InnerClipRect.Max.y = (band(flags, ImGuiTableFlags.NoHostExtendY) ~= 0) and ImMin(table_.InnerClipRect.Max.y, inner_window.WorkRect.Max.y) or table_.HostClipRect.Max.y

    table_.RowPosY1 = table_.WorkRect.Min.y -- This is needed somehow
    table_.RowPosY2 = table_.WorkRect.Min.y
    table_.RowTextBaseline = 0.0 -- This will be cleared again by TableBeginRow()
    table_.RowCellPaddingY = 0.0
    table_.FreezeRowsRequest = 0; table_.FreezeRowsCount = 0 -- This will be setup by TableSetupScrollFreeze(), if any
    table_.FreezeColumnsRequest = 0; table_.FreezeColumnsCount = 0
    table_.IsUnfrozenRows = true
    table_.DeclColumnsCount = 0; table_.AngledHeadersCount = 0
    if previous_frame_active + 1 < g.FrameCount then
        table_.IsActiveIdInTable = false
    end
    table_.AngledHeadersHeight = 0.0
    temp_data.AngledHeadersExtraWidth = 0.0

    -- Using opaque colors facilitate overlapping lines of the grid, otherwise we'd need to improve TableDrawBorders()
    table_.BorderColorStrong = ImGui.GetColorU32(ImGuiCol.TableBorderStrong)
    table_.BorderColorLight = ImGui.GetColorU32(ImGuiCol.TableBorderLight)

    -- Make table current
    g.CurrentTable = table_
    inner_window.DC.NavIsScrollPushableX = false -- Shortcut for NavUpdateCurrentWindowIsScrollPushableX();
    outer_window.DC.CurrentTableIdx = table_idx
    if inner_window ~= outer_window then -- So EndChild() within the inner window can restore the table properly.
        inner_window.DC.CurrentTableIdx = table_idx
    end

    if band(previous_flags, ImGuiTableFlags.Reorderable) ~= 0 and band(flags, ImGuiTableFlags.Reorderable) == 0 then
        table_.IsResetDisplayOrderRequest = true
    end

    -- Mark as used to avoid GC
    while table_idx >= g.TablesLastTimeActive.Size do
        g.TablesLastTimeActive:push_back(-1.0)
    end
    g.TablesLastTimeActive.Data[table_idx + 1] = g.Time
    temp_data.LastTimeActive = g.Time
    table_.MemoryCompacted = false

    -- Setup memory buffer (clear data if columns count changed)
    local old_columns_count = table_.ColumnsSize
    if old_columns_count ~= 0 and old_columns_count ~= columns_count then
        -- Attempt to preserve width and other settings on column count/specs change (#4046, #9108)
        IMGUI_DEBUG_LOG_TABLE("[table] Table 0x%08X column count %d -> %d, recreating storage.\n", table_.ID, old_columns_count, columns_count)
        IM_ASSERT(temp_data.OldColumnsRawData == nil)
        temp_data.OldColumnsRawData = table_.RawData -- Freed during layout
        temp_data.OldColumnsData = table_.Columns
        temp_data.OldColumnsDataSize = table_.ColumnsSize
        for n = 0, temp_data.OldColumnsDataSize - 1 do
            temp_data.OldColumnsData[n].IsNeedReconcileSrc = true
        end
        table_.RawData = nil
    end
    if table_.RawData == nil then
        ImGui.TableBeginInitMemory(table_, columns_count)
        table_.IsInitializing = true
    end
    if table_.IsResetAllRequest then
        ImGui.TableResetSettings(table_)
    end
    if table_.IsInitializing then
        -- Initialize
        if table_.IsNewTable then
            table_.SettingsOffset = -1
            table_.IsSettingsRequestLoad = true
        end
        table_.IsSortSpecsDirty = true
        table_.IsSettingsDirty = true -- Records itself into .ini file even when in default state (#7934)
        table_.IsReconcileMode = false
        table_.InstanceInteracted = -1
        table_.ContextPopupColumn = -1
        table_.ReorderColumn = -1; table_.ReorderColumnDstOrder = -1; table_.ResizedColumn = -1; table_.LastResizedColumn = -1
        table_.AutoFitSingleColumn = -1
        table_.HoveredColumnBody = -1; table_.HoveredColumnBorder = -1
        for n = 0, columns_count - 1 do
            local column = table_.Columns[n]
            if temp_data.OldColumnsData and n < temp_data.OldColumnsDataSize then
                TableColumnCopy(column, temp_data.OldColumnsData[n])
            else
                local width_auto = column.WidthAuto
                TableColumnCopy(column, ImGuiTableColumn())
                column.WidthAuto = width_auto
                column.IsPreserveWidthAuto = true -- Preserve WidthAuto when reinitializing a live table: not technically necessary but remove a visible flicker
                column.IsEnabled = true; column.IsUserEnabled = true; column.IsUserEnabledNextFrame = true
                column.DisplayOrder = n
            end
            table_.DisplayOrderToIndex[n] = column.DisplayOrder
        end
    end

    -- Load settings
    if table_.IsSettingsRequestLoad then
        ImGui.TableLoadSettings(table_)
    end

    -- Disable output until user calls TableNextRow() or TableNextColumn() leading to the TableUpdateLayout() call..
    inner_window.SkipItems = true

    -- Clear names
    if #table_.ColumnsNames > 0 then
        table.clear(table_.ColumnsNames)
    end

    return true
end

function ImGui.TableBeginInitMemory(table_, columns_count)
    table_.RawData = true
    table_.Columns = {}
    table_.DisplayOrderToIndex = {}
    table_.RowCellData = {}
    for n = 0, columns_count - 1 do
        table_.Columns[n] = ImGuiTableColumn()
        table_.Columns[n].WidthAuto = 0.0
        table_.DisplayOrderToIndex[n] = 0
        table_.RowCellData[n] = { BgColor = 0, Column = 0 }
    end
    table_.ColumnsSize = columns_count
    table_.EnabledMaskByDisplayOrder = {}
    table_.EnabledMaskByIndex = {}
    table_.VisibleMaskByIndex = {}
end

-- Apply queued resizing/reordering/hiding requests
function ImGui.TableApplyQueuedRequests(table_)
    -- Handle resizing request
    if table_.InstanceCurrent == 0 then
        if table_.ResizedColumn ~= -1 and table_.ResizedColumnNextWidth ~= FLT_MAX then
            ImGui.TableSetColumnWidth(table_.ResizedColumn, table_.ResizedColumnNextWidth)
        end
        table_.LastResizedColumn = table_.ResizedColumn
        table_.ResizedColumnNextWidth = FLT_MAX
        table_.ResizedColumn = -1

        -- Process auto-fit for single column, which is a special case for stretch columns and fixed columns with FixedSame policy.
        if table_.AutoFitSingleColumn ~= -1 then
            ImGui.TableSetColumnWidth(table_.AutoFitSingleColumn, table_.Columns[table_.AutoFitSingleColumn].WidthAuto)
            table_.AutoFitSingleColumn = -1
        end
    end

    -- Handle reordering request
    if table_.InstanceCurrent == 0 then
        table_.LastHeldHeaderColumn = table_.HeldHeaderColumn
        table_.HeldHeaderColumn = -1
        if table_.ReorderColumn ~= -1 and table_.ReorderColumnDstOrder ~= -1 then
            ImGui.TableSetColumnDisplayOrder(table_, table_.ReorderColumn, table_.ReorderColumnDstOrder)
            table_.ReorderColumnDstOrder = -1
        end

        -- Release
        local g = GImGui
        if g.ActiveId == 0 then -- FIXME: Need to revisit. See 38f5e5a.
            table_.ReorderColumn = -1
        end
    end

    -- Handle display order / visibility reset requests
    if table_.IsResetDisplayOrderRequest then
        for n = 0, table_.ColumnsCount - 1 do
            table_.Columns[n].DisplayOrder = n
            table_.DisplayOrderToIndex[n] = n
        end
        table_.IsResetDisplayOrderRequest = false
        table_.IsSettingsDirty = true
    end
    if table_.IsResetVisibilityRequest then
        for n = 0, table_.ColumnsSize - 1 do
            local column = table_.Columns[n]
            local v = band(column.Flags, ImGuiTableColumnFlags.DefaultHide) == 0
            column.IsUserEnabled = v; column.IsUserEnabledNextFrame = v
        end
        table_.IsResetVisibilityRequest = false
        table_.IsSettingsDirty = true
    end
end

-- Apply immediately. See TableQueueSetColumnDisplayOrder() for additional checks/constraints.
function ImGui.TableSetColumnDisplayOrder(table_, column_n, dst_order)
    IM_ASSERT(column_n >= 0 and column_n < table_.ColumnsCount)
    IM_ASSERT(dst_order >= 0 and dst_order < table_.ColumnsCount)

    local src_column = table_.Columns[column_n]
    local src_order = src_column.DisplayOrder
    if src_order == dst_order then
        return
    end
    local reorder_dir = (dst_order < src_order) and -1 or 1

    src_column.DisplayOrder = dst_order
    local order_n = src_order + reorder_dir
    while order_n ~= dst_order + reorder_dir do
        local c = table_.Columns[table_.DisplayOrderToIndex[order_n]]
        c.DisplayOrder = c.DisplayOrder - reorder_dir
        order_n = order_n + reorder_dir
    end

    -- Display order is stored in both columns->IndexDisplayOrder and table->DisplayOrder[]. Rebuild later from the former.
    for n = 0, table_.ColumnsCount - 1 do
        table_.DisplayOrderToIndex[table_.Columns[n].DisplayOrder] = n
    end
    table_.IsSettingsDirty = true
end

local function TableGetMaxDisplayOrderAllowed(table_, src_order, dst_order)
    dst_order = ImClamp(dst_order, 0, table_.ColumnsCount - 1)
    if src_order == dst_order then
        return dst_order
    end

    -- Cannot cross over the frozen column limit when interactively reordering.
    if table_.FreezeColumnsRequest > 0 then
        dst_order = (src_order < table_.FreezeColumnsRequest) and ImMin(dst_order, table_.FreezeColumnsRequest - 1) or ImMax(dst_order, table_.FreezeColumnsRequest)
    end

    -- Cannot cross over a column with the ImGuiTableColumnFlags_NoReorder flag.
    local reorder_dir = (src_order < dst_order) and 1 or -1
    local order_n = src_order
    while (src_order < dst_order and order_n <= dst_order) or (dst_order < src_order and order_n >= dst_order) do
        if band(table_.Columns[table_.DisplayOrderToIndex[order_n]].Flags, ImGuiTableColumnFlags.NoReorder) ~= 0 then
            dst_order = (order_n == src_order) and src_order or (order_n - reorder_dir)
            break
        end
        order_n = order_n + reorder_dir
    end
    return dst_order
end

-- Reorder requested by user interaction.
function ImGui.TableQueueSetColumnDisplayOrder(table_, column_n, dst_order)
    local src_order = table_.Columns[column_n].DisplayOrder
    table_.ReorderColumn = column_n
    table_.ReorderColumnDstOrder = -1
    dst_order = TableGetMaxDisplayOrderAllowed(table_, src_order, dst_order)
    if table_.IsLayoutLocked and dst_order == src_order then -- We allow calling the function before layout w/ reconcile so don't early out.
        return
    end
    table_.ReorderColumnDstOrder = dst_order
end

-- Adjust flags: default width mode + stretch columns are not allowed when auto extending
local function TableSetupColumnFlags(table_, column, column_n, flags_in)
    local flags = flags_in

    -- Sizing Policy
    if band(flags, ImGuiTableColumnFlags.WidthMask_) == 0 then
        local table_sizing_policy = band(table_.Flags, ImGuiTableFlags.SizingMask_)
        if table_sizing_policy == ImGuiTableFlags.SizingFixedFit or table_sizing_policy == ImGuiTableFlags.SizingFixedSame then
            flags = bor(flags, ImGuiTableColumnFlags.WidthFixed)
        else
            flags = bor(flags, ImGuiTableColumnFlags.WidthStretch)
        end
    else
        IM_ASSERT(ImIsPowerOfTwo(band(flags, ImGuiTableColumnFlags.WidthMask_))) -- Check that only 1 of each set is used.
    end

    -- Resize
    if band(table_.Flags, ImGuiTableFlags.Resizable) == 0 then
        flags = bor(flags, ImGuiTableColumnFlags.NoResize)
    end

    -- Sorting
    if band(flags, ImGuiTableColumnFlags.NoSortAscending) ~= 0 and band(flags, ImGuiTableColumnFlags.NoSortDescending) ~= 0 then
        flags = bor(flags, ImGuiTableColumnFlags.NoSort)
    end

    -- Indentation
    if band(flags, ImGuiTableColumnFlags.IndentMask_) == 0 then
        flags = bor(flags, (column_n == 0) and ImGuiTableColumnFlags.IndentEnable or ImGuiTableColumnFlags.IndentDisable)
    end

    -- Preserve status flags
    column.Flags = bor(flags, band(column.Flags, ImGuiTableColumnFlags.StatusMask_))

    -- Build an ordered list of available sort directions
    column.SortDirectionsAvailCount = 0; column.SortDirectionsAvailMask = 0; column.SortDirectionsAvailList = 0
    if band(table_.Flags, ImGuiTableFlags.Sortable) ~= 0 then
        local count, mask, list = 0, 0, 0
        local Asc, Desc = ImGuiSortDirection.Ascending, ImGuiSortDirection.Descending
        if band(flags, ImGuiTableColumnFlags.PreferSortAscending) ~= 0 and band(flags, ImGuiTableColumnFlags.NoSortAscending) == 0 then mask = bor(mask, lshift(1, Asc)); list = bor(list, lshift(Asc, lshift(count, 1))); count = count + 1 end
        if band(flags, ImGuiTableColumnFlags.PreferSortDescending) ~= 0 and band(flags, ImGuiTableColumnFlags.NoSortDescending) == 0 then mask = bor(mask, lshift(1, Desc)); list = bor(list, lshift(Desc, lshift(count, 1))); count = count + 1 end
        if band(flags, ImGuiTableColumnFlags.PreferSortAscending) == 0 and band(flags, ImGuiTableColumnFlags.NoSortAscending) == 0 then mask = bor(mask, lshift(1, Asc)); list = bor(list, lshift(Asc, lshift(count, 1))); count = count + 1 end
        if band(flags, ImGuiTableColumnFlags.PreferSortDescending) == 0 and band(flags, ImGuiTableColumnFlags.NoSortDescending) == 0 then mask = bor(mask, lshift(1, Desc)); list = bor(list, lshift(Desc, lshift(count, 1))); count = count + 1 end
        if band(table_.Flags, ImGuiTableFlags.SortTristate) ~= 0 or count == 0 then mask = bor(mask, lshift(1, ImGuiSortDirection.None)); count = count + 1 end
        column.SortDirectionsAvailList = band(list, 0xFF)
        column.SortDirectionsAvailMask = band(mask, 0xFF)
        column.SortDirectionsAvailCount = count
        ImGui.TableFixColumnSortDirection(table_, column)
    end
end

-- Layout columns for the frame. This is in essence the followup to BeginTable() and this is our largest function.
-- Runs on the first call to TableNextRow(), to give a chance for TableSetupColumn() and other TableSetupXXXXX() functions to be called first.
function ImGui.TableUpdateLayout(table_)
    local g = GImGui
    local temp_data = table_.TempData
    IM_ASSERT(table_.IsLayoutLocked == false)
    local columns_count = table_.ColumnsCount

    -- Reconcile moved columns
    if temp_data.ReconcileColumnsRequests.Size > 0 then
        ImGui.TableReconcileColumns(table_)
    end
    if temp_data.OldColumnsRawData then
        temp_data.OldColumnsRawData = nil
        temp_data.OldColumnsData = nil
        temp_data.OldColumnsDataSize = 0
    end

    -- Apply columns settings
    if table_.IsSettingsRequestLoad then
        ImGui.TableLoadSettingsForColumns(table_)
    end
    if table_.IsInitializing or table_.IsSettingsRequestLoad then
        for n = 0, table_.ColumnsSize - 1 do
            local column = table_.Columns[n]
            local init_flags
            if table_.IsSettingsRequestLoad then
                init_flags = column.IsLoadedSettings and bnot(table_.SettingsLoadedFlags) or bnot(0)
            else
                init_flags = column.IsJustCreated and bnot(0) or 0
            end
            ImGui.TableInitColumnDefaults(table_, column, n, init_flags)
        end
        ImGui.TableFixDisplayOrder(table_) -- Call even for non _Reorderable table as we loaded .ini data.
        table_.IsSettingsRequestLoad = false
    end

    -- Apply queued resizing/reordering/hiding requests
    ImGui.TableApplyQueuedRequests(table_)

    -- Handle DPI/font resize
    local new_ref_scale_unit = g.FontSize
    if table_.RefScale ~= 0.0 and table_.RefScale ~= new_ref_scale_unit then
        local scale_factor = new_ref_scale_unit / table_.RefScale
        for n = 0, columns_count - 1 do
            table_.Columns[n].WidthRequest = table_.Columns[n].WidthRequest * scale_factor
        end
    end
    table_.RefScale = new_ref_scale_unit

    local table_sizing_policy = band(table_.Flags, ImGuiTableFlags.SizingMask_)
    table_.IsDefaultDisplayOrder = true; table_.IsDefaultVisibility = true
    table_.ColumnsEnabledCount = 0
    BitArrayClearAll(table_.EnabledMaskByIndex)
    BitArrayClearAll(table_.EnabledMaskByDisplayOrder)
    table_.LeftMostEnabledColumn = -1
    table_.MinColumnWidth = ImMax(1.0, g.Style.FramePadding.x * 1.0) -- g.Style.ColumnsMinSpacing; // FIXME-TABLE

    -- [Part 1] Apply/lock Enabled and Order states. Calculate auto/ideal width for columns. Count fixed/stretch columns.
    local count_fixed = 0
    local count_stretch = 0
    local prev_visible_column_idx = -1
    local has_auto_fit_request = false
    local has_resizable = false
    local stretch_sum_width_auto = 0.0
    local fixed_max_width_auto = 0.0
    for order_n = 0, columns_count - 1 do
        local column_n = table_.DisplayOrderToIndex[order_n]
        local column = table_.Columns[column_n]

        -- Clear column setup if not submitted by user. Currently we make it mandatory to call TableSetupColumn() every frame.
        if table_.DeclColumnsCount <= column_n then
            TableSetupColumnFlags(table_, column, column_n, ImGuiTableColumnFlags.None)
            column.NameOffset = -1
            column.ID = 0; column.UserData = 0
            column.InitStretchWeightOrWidth = -1.0
        end

        -- Update Enabled state, mark settings and sort specs dirty
        if band(table_.Flags, ImGuiTableFlags.Hideable) == 0 or band(column.Flags, ImGuiTableColumnFlags.NoHide) ~= 0 then
            column.IsUserEnabledNextFrame = true
        end
        if column.IsUserEnabled ~= column.IsUserEnabledNextFrame then
            column.IsUserEnabled = column.IsUserEnabledNextFrame
            table_.IsSettingsDirty = true
        end
        column.IsEnabled = column.IsUserEnabled and band(column.Flags, ImGuiTableColumnFlags.Disabled) == 0
        column.IsJustCreated = false

        if column.IsEnabled ~= (band(column.Flags, ImGuiTableColumnFlags.DefaultHide) == 0) then
            table_.IsDefaultVisibility = false
        end
        if column_n ~= order_n then
            table_.IsDefaultDisplayOrder = false
        end

        if column.SortOrder ~= -1 and not column.IsEnabled then
            table_.IsSortSpecsDirty = true
        end
        if column.SortOrder > 0 and band(table_.Flags, ImGuiTableFlags.SortMulti) == 0 then
            table_.IsSortSpecsDirty = true
        end

        -- Auto-fit unsized columns
        local start_auto_fit
        if band(column.Flags, ImGuiTableColumnFlags.WidthFixed) ~= 0 then
            start_auto_fit = column.WidthRequest < 0.0
        else
            start_auto_fit = column.StretchWeight < 0.0
        end
        if start_auto_fit then
            column.AutoFitQueue = lshift(1, 3) - 1 -- Fit for three frames
            column.CannotSkipItemsQueue = lshift(1, 3) - 1
        end

        if not column.IsEnabled then
            column.IndexWithinEnabledSet = -1
        else
            -- Mark as enabled and link to previous/next enabled column
            column.PrevEnabledColumn = prev_visible_column_idx
            column.NextEnabledColumn = -1
            if prev_visible_column_idx ~= -1 then
                table_.Columns[prev_visible_column_idx].NextEnabledColumn = column_n
            else
                table_.LeftMostEnabledColumn = column_n
            end
            column.IndexWithinEnabledSet = table_.ColumnsEnabledCount
            table_.ColumnsEnabledCount = table_.ColumnsEnabledCount + 1
            BitArraySet(table_.EnabledMaskByIndex, column_n)
            BitArraySet(table_.EnabledMaskByDisplayOrder, column.DisplayOrder)
            prev_visible_column_idx = column_n
            IM_ASSERT(column.IndexWithinEnabledSet <= column.DisplayOrder)

            -- Calculate ideal/auto column width (that's the width required for all contents to be visible without clipping)
            if not column.IsPreserveWidthAuto and table_.InstanceCurrent == 0 then
                column.WidthAuto = ImGui.TableGetColumnWidthAuto(table_, column)
            end

            -- Non-resizable columns keep their requested width (apply user value regardless of IsPreserveWidthAuto)
            local column_is_resizable = band(column.Flags, ImGuiTableColumnFlags.NoResize) == 0
            if column_is_resizable then
                has_resizable = true
            end
            if band(column.Flags, ImGuiTableColumnFlags.WidthFixed) ~= 0 and column.InitStretchWeightOrWidth > 0.0 and not column_is_resizable then
                column.WidthAuto = column.InitStretchWeightOrWidth
            end

            if column.AutoFitQueue ~= 0x00 then
                has_auto_fit_request = true
            end
            if band(column.Flags, ImGuiTableColumnFlags.WidthStretch) ~= 0 then
                stretch_sum_width_auto = stretch_sum_width_auto + column.WidthAuto
                count_stretch = count_stretch + 1
            else
                fixed_max_width_auto = ImMax(fixed_max_width_auto, column.WidthAuto)
                count_fixed = count_fixed + 1
            end
        end
    end
    if band(table_.Flags, ImGuiTableFlags.Sortable) ~= 0 and table_.SortSpecsCount == 0 and band(table_.Flags, ImGuiTableFlags.SortTristate) == 0 then
        table_.IsSortSpecsDirty = true
    end
    table_.RightMostEnabledColumn = prev_visible_column_idx
    IM_ASSERT(table_.LeftMostEnabledColumn >= 0 and table_.RightMostEnabledColumn >= 0)

    -- [Part 2] Disable child window clipping while fitting columns.
    if has_auto_fit_request and table_.OuterWindow ~= table_.InnerWindow then
        table_.InnerWindow.SkipItems = false
    end
    if has_auto_fit_request then
        table_.IsSettingsDirty = true
    end

    -- [Part 3] Fix column flags and record a few extra information.
    local sum_width_requests = 0.0
    local stretch_sum_weights = 0.0
    table_.LeftMostStretchedColumn = -1; table_.RightMostStretchedColumn = -1
    for column_n = 0, columns_count - 1 do
        if BitTest(table_.EnabledMaskByIndex, column_n) then
            local column = table_.Columns[column_n]

            local column_is_resizable = band(column.Flags, ImGuiTableColumnFlags.NoResize) == 0
            if band(column.Flags, ImGuiTableColumnFlags.WidthFixed) ~= 0 then
                -- Apply same widths policy
                local width_auto = column.WidthAuto
                if table_sizing_policy == ImGuiTableFlags.SizingFixedSame and (column.AutoFitQueue ~= 0x00 or not column_is_resizable) then
                    width_auto = fixed_max_width_auto
                end

                -- Apply automatic width
                if column.AutoFitQueue ~= 0x00 then
                    column.WidthRequest = width_auto
                elseif band(column.Flags, ImGuiTableColumnFlags.WidthFixed) ~= 0 and not column_is_resizable and column.IsRequestOutput then
                    column.WidthRequest = width_auto
                end

                -- FIXME-TABLE: Increase minimum size during init frame to avoid biasing auto-fitting widgets
                if column.AutoFitQueue > 0x01 and table_.IsInitializing and not column.IsPreserveWidthAuto then
                    column.WidthRequest = ImMax(column.WidthRequest, table_.MinColumnWidth * 4.0) -- FIXME-TABLE: Another constant/scale?
                end
                sum_width_requests = sum_width_requests + column.WidthRequest
            else
                -- Initialize stretch weight
                if column.AutoFitQueue ~= 0x00 or column.StretchWeight < 0.0 or not column_is_resizable then
                    if column.InitStretchWeightOrWidth > 0.0 then
                        column.StretchWeight = column.InitStretchWeightOrWidth
                    elseif table_sizing_policy == ImGuiTableFlags.SizingStretchProp then
                        column.StretchWeight = (column.WidthAuto / stretch_sum_width_auto) * count_stretch
                    else
                        column.StretchWeight = 1.0
                    end
                end

                stretch_sum_weights = stretch_sum_weights + column.StretchWeight
                if table_.LeftMostStretchedColumn == -1 or table_.Columns[table_.LeftMostStretchedColumn].DisplayOrder > column.DisplayOrder then
                    table_.LeftMostStretchedColumn = column_n
                end
                if table_.RightMostStretchedColumn == -1 or table_.Columns[table_.RightMostStretchedColumn].DisplayOrder < column.DisplayOrder then
                    table_.RightMostStretchedColumn = column_n
                end
            end
            column.IsPreserveWidthAuto = false
            sum_width_requests = sum_width_requests + table_.CellPaddingX * 2.0
        end
    end
    table_.ColumnsEnabledFixedCount = count_fixed
    table_.ColumnsStretchSumWeights = stretch_sum_weights

    -- [Part 4] Apply final widths based on requested widths
    local work_rect = Rect(table_.WorkRect)
    local width_spacings = (table_.OuterPaddingX * 2.0) + (table_.CellSpacingX1 + table_.CellSpacingX2) * (table_.ColumnsEnabledCount - 1)
    local width_removed = (table_.HasScrollbarYPrev and not table_.InnerWindow.ScrollbarY) and g.Style.ScrollbarSize or 0.0 -- To synchronize decoration width of synced tables with mismatching scrollbar state (#5920)
    local width_avail = ImMax(1.0, ((band(table_.Flags, ImGuiTableFlags.ScrollX) ~= 0 and table_.InnerWidth == 0.0) and table_.InnerClipRect:GetWidth() or work_rect:GetWidth()) - width_removed)
    local width_avail_for_stretched_columns = width_avail - width_spacings - sum_width_requests
    local width_remaining_for_stretched_columns = width_avail_for_stretched_columns
    table_.ColumnsGivenWidth = width_spacings + (table_.CellPaddingX * 2.0) * table_.ColumnsEnabledCount
    for column_n = 0, columns_count - 1 do
        if BitTest(table_.EnabledMaskByIndex, column_n) then
            local column = table_.Columns[column_n]

            -- Allocate width for stretched/weighted columns (StretchWeight gets converted into WidthRequest)
            if band(column.Flags, ImGuiTableColumnFlags.WidthStretch) ~= 0 then
                local weight_ratio = column.StretchWeight / stretch_sum_weights
                column.WidthRequest = IM_TRUNC(ImMax(width_avail_for_stretched_columns * weight_ratio, table_.MinColumnWidth) + 0.01)
                width_remaining_for_stretched_columns = width_remaining_for_stretched_columns - column.WidthRequest
            end

            -- [Resize Rule 1] The right-most Visible column is not resizable if there is at least one Stretch column
            if column.NextEnabledColumn == -1 and table_.LeftMostStretchedColumn ~= -1 then
                column.Flags = bor(column.Flags, ImGuiTableColumnFlags.NoDirectResize_)
            end

            -- Assign final width, record width in case we will need to shrink
            column.WidthGiven = ImTrunc(ImMax(column.WidthRequest, table_.MinColumnWidth))
            table_.ColumnsGivenWidth = table_.ColumnsGivenWidth + column.WidthGiven
        end
    end

    -- [Part 5] Redistribute stretch remainder width due to rounding (remainder width is < 1.0f * number of Stretch column).
    if width_remaining_for_stretched_columns >= 1.0 and band(table_.Flags, ImGuiTableFlags.PreciseWidths) == 0 then
        local order_n = columns_count - 1
        while stretch_sum_weights > 0.0 and width_remaining_for_stretched_columns >= 1.0 and order_n >= 0 do
            if BitTest(table_.EnabledMaskByDisplayOrder, order_n) then
                local column = table_.Columns[table_.DisplayOrderToIndex[order_n]]
                if band(column.Flags, ImGuiTableColumnFlags.WidthStretch) ~= 0 then
                    column.WidthRequest = column.WidthRequest + 1.0
                    column.WidthGiven = column.WidthGiven + 1.0
                    width_remaining_for_stretched_columns = width_remaining_for_stretched_columns - 1.0
                end
            end
            order_n = order_n - 1
        end
    end

    -- Determine if table is hovered which will be used to flag columns as hovered.
    local table_instance = ImGui.TableGetInstanceData(table_, table_.InstanceCurrent)
    table_instance.HoveredRowLast = table_instance.HoveredRowNext
    table_instance.HoveredRowNext = -1
    table_.HoveredColumnBody = -1; table_.HoveredColumnBorder = -1
    local mouse_hit_rect = ImRect(table_.OuterRect.Min.x, table_.OuterRect.Min.y, table_.OuterRect.Max.x, ImMax(table_.OuterRect.Max.y, table_.OuterRect.Min.y + table_instance.LastOuterHeight))
    local backup_active_id = g.ActiveId
    g.ActiveId = 0
    local is_hovering_table = ImGui.ItemHoverable(mouse_hit_rect, 0, ImGuiItemFlags.None)
    g.ActiveId = backup_active_id

    -- Determine skewed MousePos.x to support angled headers.
    local mouse_skewed_x = g.IO.MousePos.x
    if table_.AngledHeadersHeight > 0.0 then
        if g.IO.MousePos.y >= table_.OuterRect.Min.y and g.IO.MousePos.y <= table_.OuterRect.Min.y + table_.AngledHeadersHeight then
            mouse_skewed_x = mouse_skewed_x + ImTrunc((table_.OuterRect.Min.y + table_.AngledHeadersHeight - g.IO.MousePos.y) * table_.AngledHeadersSlope)
        end
    end

    -- [Part 6] Setup final position, offset, skip/clip states and clipping rectangles, detect hovered column
    local has_at_least_one_column_requesting_output = false
    local offset_x_frozen = (table_.FreezeColumnsCount > 0)
    local offset_x = ((table_.FreezeColumnsCount > 0) and table_.OuterRect.Min.x or work_rect.Min.x) + table_.OuterPaddingX - table_.CellSpacingX1
    local host_clip_rect = Rect(table_.InnerClipRect)
    BitArrayClearAll(table_.VisibleMaskByIndex)
    for order_n = 0, columns_count - 1 do
        local column_n = table_.DisplayOrderToIndex[order_n]
        local column = table_.Columns[column_n]

        -- Initial nav layer: using FreezeRowsCount, NOT FreezeRowsRequest, so Header line changes layer when frozen
        column.NavLayerCurrent = (table_.FreezeRowsCount > 0) and ImGuiNavLayer.Menu or table_.NavLayer

        if offset_x_frozen and table_.FreezeColumnsCount == order_n then
            offset_x = offset_x + work_rect.Min.x - table_.OuterRect.Min.x
            offset_x_frozen = false
        end

        -- Clear status flags
        column.Flags = band(column.Flags, bnot(ImGuiTableColumnFlags.StatusMask_))

        if not BitTest(table_.EnabledMaskByDisplayOrder, order_n) then
            -- Hidden column: clear a few fields and we are done with it for the remainder of the function.
            column.MinX = offset_x; column.MaxX = offset_x; column.WorkMinX = offset_x
            column.ClipRect.Min.x = offset_x; column.ClipRect.Max.x = offset_x
            column.WidthGiven = 0.0
            column.ClipRect.Min.y = work_rect.Min.y
            column.ClipRect.Max.y = FLT_MAX
            column.ClipRect:ClipWithFull(host_clip_rect)
            column.IsVisibleX = false; column.IsVisibleY = false; column.IsRequestOutput = false
            column.IsSkipItems = true
            column.ItemWidth = 1.0
        else
            -- Lock start position
            column.MinX = offset_x

            -- Lock width based on start position and minimum/maximum width for this position
            column.WidthMax = ImGui.TableCalcMaxColumnWidth(table_, column_n)
            column.WidthGiven = ImMin(column.WidthGiven, column.WidthMax)
            column.WidthGiven = ImMax(column.WidthGiven, ImMin(column.WidthRequest, table_.MinColumnWidth))
            column.MaxX = offset_x + column.WidthGiven + table_.CellSpacingX1 + table_.CellSpacingX2 + table_.CellPaddingX * 2.0

            -- Lock other positions
            local previous_instance_work_min_x = column.WorkMinX
            column.WorkMinX = column.MinX + table_.CellPaddingX + table_.CellSpacingX1
            column.WorkMaxX = column.MaxX - table_.CellPaddingX - table_.CellSpacingX2 -- Expected max
            column.ItemWidth = ImTrunc(column.WidthGiven * 0.65)
            column.ClipRect.Min.x = column.MinX
            column.ClipRect.Min.y = work_rect.Min.y
            column.ClipRect.Max.x = column.MaxX --column->WorkMaxX;
            column.ClipRect.Max.y = FLT_MAX
            column.ClipRect:ClipWithFull(host_clip_rect)

            -- Mark column as Clipped (not in sight)
            column.IsVisibleX = (column.ClipRect.Max.x > column.ClipRect.Min.x)
            column.IsVisibleY = true -- (column->ClipRect.Max.y > column->ClipRect.Min.y);
            local is_visible = column.IsVisibleX --&& column->IsVisibleY;
            if is_visible then
                BitArraySet(table_.VisibleMaskByIndex, column_n)
            end

            -- Mark column as requesting output from user. Note that fixed + non-resizable sets are auto-fitting at all times and therefore always request output.
            column.IsRequestOutput = is_visible or column.AutoFitQueue ~= 0 or column.CannotSkipItemsQueue ~= 0

            -- Mark column as SkipItems (ignoring all items/layout)
            column.IsSkipItems = not column.IsEnabled or table_.HostSkipItems
            if column.IsSkipItems then
                IM_ASSERT(not is_visible)
            end
            if column.IsRequestOutput and not column.IsSkipItems then
                has_at_least_one_column_requesting_output = true
            end

            -- Update status flags
            column.Flags = bor(column.Flags, ImGuiTableColumnFlags.IsEnabled)
            if is_visible then
                column.Flags = bor(column.Flags, ImGuiTableColumnFlags.IsVisible)
            end
            if column.SortOrder ~= -1 then
                column.Flags = bor(column.Flags, ImGuiTableColumnFlags.IsSorted)
            end

            -- Detect hovered column
            if is_hovering_table and mouse_skewed_x >= column.ClipRect.Min.x and mouse_skewed_x < column.ClipRect.Max.x then
                column.Flags = bor(column.Flags, ImGuiTableColumnFlags.IsHovered)
                table_.HoveredColumnBody = column_n
            end

            -- Reset content width variables
            if table_.InstanceCurrent == 0 then
                column.ContentMaxXFrozen = column.WorkMinX
                column.ContentMaxXUnfrozen = column.WorkMinX
                column.ContentMaxXHeadersUsed = column.WorkMinX
                column.ContentMaxXHeadersIdeal = column.WorkMinX
            else
                -- As we store an absolute value to make per-cell updates faster, we need to offset values used for width computation.
                local offset_from_previous_instance = column.WorkMinX - previous_instance_work_min_x
                column.ContentMaxXFrozen = column.ContentMaxXFrozen + offset_from_previous_instance
                column.ContentMaxXUnfrozen = column.ContentMaxXUnfrozen + offset_from_previous_instance
                column.ContentMaxXHeadersUsed = column.ContentMaxXHeadersUsed + offset_from_previous_instance
                column.ContentMaxXHeadersIdeal = column.ContentMaxXHeadersIdeal + offset_from_previous_instance
            end

            -- Don't decrement auto-fit counters until container window got a chance to submit its items
            if table_.HostSkipItems == false and table_.InstanceCurrent == 0 then
                column.AutoFitQueue = rshift(column.AutoFitQueue, 1)
                column.CannotSkipItemsQueue = rshift(column.CannotSkipItemsQueue, 1)
            end

            if order_n < table_.FreezeColumnsCount then
                host_clip_rect.Min.x = ImClamp(column.MaxX + TABLE_BORDER_SIZE, host_clip_rect.Min.x, host_clip_rect.Max.x)
            end

            offset_x = offset_x + column.WidthGiven + table_.CellSpacingX1 + table_.CellSpacingX2 + table_.CellPaddingX * 2.0
        end
    end

    -- In case the table is visible (e.g. decorations) but all columns clipped, we keep a column visible.
    if has_at_least_one_column_requesting_output == false then
        table_.Columns[table_.LeftMostEnabledColumn].IsRequestOutput = true
        table_.Columns[table_.LeftMostEnabledColumn].IsSkipItems = false
    end

    -- [Part 7] Detect/store when we are hovering the unused space after the right-most column (so e.g. context menus can react on it)
    local unused_x1 = ImMax(table_.WorkRect.Min.x, table_.Columns[table_.RightMostEnabledColumn].ClipRect.Max.x)
    if is_hovering_table and table_.HoveredColumnBody == -1 then
        if mouse_skewed_x >= unused_x1 then
            table_.HoveredColumnBody = columns_count
        end
    end
    if has_resizable == false and band(table_.Flags, ImGuiTableFlags.Resizable) ~= 0 then
        table_.Flags = band(table_.Flags, bnot(ImGuiTableFlags.Resizable))
    end

    table_.IsActiveIdAliveBeforeTable = (g.ActiveIdIsAlive ~= 0)

    -- [Part 8] Lock actual OuterRect/WorkRect right-most position.
    if table_.RightMostStretchedColumn ~= -1 then
        table_.Flags = band(table_.Flags, bnot(ImGuiTableFlags.NoHostExtendX))
    end
    if band(table_.Flags, ImGuiTableFlags.NoHostExtendX) ~= 0 then
        table_.OuterRect.Max.x = unused_x1; table_.WorkRect.Max.x = unused_x1
        table_.InnerClipRect.Max.x = ImMin(table_.InnerClipRect.Max.x, unused_x1)
    end
    ImRect_Copy(table_.InnerWindow.ParentWorkRect, table_.WorkRect)
    table_.BorderX1 = table_.InnerClipRect.Min.x
    table_.BorderX2 = table_.InnerClipRect.Max.x

    -- Setup window's WorkRect.Max.y for GetContentRegionAvail(). Other values will be updated in each TableBeginCell() call.
    local window_content_max_y
    if band(table_.Flags, ImGuiTableFlags.NoHostExtendY) ~= 0 then
        window_content_max_y = table_.OuterRect.Max.y
    else
        window_content_max_y = ImMax(table_.InnerWindow.ContentRegionRect.Max.y, (band(table_.Flags, ImGuiTableFlags.ScrollY) ~= 0) and 0.0 or table_.OuterRect.Max.y)
    end
    table_.InnerWindow.WorkRect.Max.y = ImClamp(window_content_max_y - g.Style.CellPadding.y, table_.InnerWindow.WorkRect.Min.y, table_.InnerWindow.WorkRect.Max.y)

    -- [Part 9] Allocate draw channels and setup background cliprect
    ImGui.TableSetupDrawChannels(table_)

    -- [Part 10] Hit testing on borders
    if band(table_.Flags, ImGuiTableFlags.Resizable) ~= 0 then
        ImGui.TableUpdateBorders(table_)
    end
    table_instance.LastTopHeadersRowHeight = 0.0
    table_.IsLayoutLocked = true
    table_.IsUsingHeaders = false

    -- Highlight header
    table_.HighlightColumnHeader = -1
    if table_.IsContextPopupOpen and table_.ContextPopupColumn ~= -1 and table_.InstanceInteracted == table_.InstanceCurrent then
        table_.HighlightColumnHeader = table_.ContextPopupColumn
    elseif band(table_.Flags, ImGuiTableFlags.HighlightHoveredColumn) ~= 0 and table_.HoveredColumnBody ~= -1 and table_.HoveredColumnBody ~= columns_count and table_.HoveredColumnBorder == -1 then
        if g.ActiveId == 0 or (table_.IsActiveIdInTable or g.DragDropActive) then
            table_.HighlightColumnHeader = table_.HoveredColumnBody
        end
    end

    -- [Part 11] Default context menu
    if table_.DisableDefaultContextMenu == false and ImGui.TableBeginContextMenuPopup(table_) then
        ImGui.TableDrawDefaultContextMenu(table_, table_.Flags)
        ImGui.EndPopup()
    end

    -- [Part 12] Sanitize and build sort specs before we have a chance to use them for display.
    if table_.IsSortSpecsDirty and band(table_.Flags, ImGuiTableFlags.Sortable) ~= 0 then
        ImGui.TableSortSpecsBuild(table_)
    end

    -- [Part 13] Setup inner window decoration size (for scrolling / nav tracking to properly take account of frozen rows/columns)
    if table_.FreezeColumnsRequest > 0 then
        table_.InnerWindow.DecoInnerSizeX1 = table_.Columns[table_.DisplayOrderToIndex[table_.FreezeColumnsRequest - 1]].MaxX - table_.OuterRect.Min.x -- FIXME-FROZEN
    end
    if table_.FreezeRowsRequest > 0 then
        table_.InnerWindow.DecoInnerSizeY1 = table_instance.LastFrozenHeight
    end
    table_instance.LastFrozenHeight = 0.0

    local inner_window = table_.InnerWindow
    local bs = g.BoxSelectState
    if bs and bs.Window == inner_window and bs.UnclipMode then
        ImGui.TableApplyExternalUnclipRect(table_, bs.UnclipRect)
    end

    -- Initial state
    if band(table_.Flags, ImGuiTableFlags.NoClip) ~= 0 then
        table_.DrawSplitter:SetCurrentChannel(inner_window.DrawList, TABLE_DRAW_CHANNEL_NOCLIP)
    else
        inner_window.DrawList:PushClipRect(inner_window.InnerClipRect.Min, inner_window.InnerClipRect.Max, false) -- FIXME: use table->InnerClipRect?
    end
end

-- When starting a BeginMultiSelect() after table has been layout we update IsRequestOutput fields.
function ImGui.TableApplyExternalUnclipRect(table_, rect)
    if rect:IsInverted() then
        return
    end
    for column_n = 0, table_.ColumnsCount - 1 do
        local column = table_.Columns[column_n]
        if not column.IsRequestOutput then
            if rect:Overlaps(ImRect(column.MinX, table_.WorkRect.Min.y, column.MaxX, FLT_MAX)) then
                column.IsRequestOutput = true
            end
        end
    end
end

-- Process hit-testing on resizing borders. Actual size change will be applied in EndTable()
function ImGui.TableUpdateBorders(table_)
    local g = GImGui
    IM_ASSERT(band(table_.Flags, ImGuiTableFlags.Resizable) ~= 0)

    local table_instance = ImGui.TableGetInstanceData(table_, table_.InstanceCurrent)
    local hit_half_width = ImTrunc(TABLE_RESIZE_SEPARATOR_HALF_THICKNESS * g.CurrentDpiScale)
    local hit_y1 = ((table_.FreezeRowsCount >= 1) and table_.OuterRect.Min.y or table_.WorkRect.Min.y) + table_.AngledHeadersHeight
    local hit_y2_body = ImMax(table_.OuterRect.Max.y, hit_y1 + table_instance.LastOuterHeight - table_.AngledHeadersHeight)
    local hit_y2_head = hit_y1 + table_instance.LastTopHeadersRowHeight

    for order_n = 0, table_.ColumnsCount - 1 do
        repeat
            if not BitTest(table_.EnabledMaskByDisplayOrder, order_n) then
                break
            end

            local column_n = table_.DisplayOrderToIndex[order_n]
            local column = table_.Columns[column_n]
            if band(column.Flags, bor(ImGuiTableColumnFlags.NoResize, ImGuiTableColumnFlags.NoDirectResize_)) ~= 0 then
                break
            end

            -- ImGuiTableFlags_NoBordersInBodyUntilResize will be honored in TableDrawBorders()
            local border_y2_hit = (band(table_.Flags, ImGuiTableFlags.NoBordersInBody) ~= 0) and hit_y2_head or hit_y2_body
            if band(table_.Flags, ImGuiTableFlags.NoBordersInBody) ~= 0 and table_.IsUsingHeaders == false then
                break
            end

            if not column.IsVisibleX and table_.LastResizedColumn ~= column_n then
                break
            end

            local column_id = ImGui.TableGetColumnResizeID(table_, column_n, table_.InstanceCurrent)
            local hit_rect = ImRect(column.MaxX - hit_half_width, hit_y1, column.MaxX + hit_half_width, border_y2_hit)
            ImGui.ItemAdd(hit_rect, column_id, nil, ImGuiItemFlags.NoNav)

            local pressed, hovered, held = ImGui.ButtonBehavior(hit_rect, column_id, bor(ImGuiButtonFlags.FlattenChildren, ImGuiButtonFlags.PressedOnClick, ImGuiButtonFlags.PressedOnDoubleClick, ImGuiButtonFlags.NoNavFocus))
            if pressed and ImGui.IsMouseDoubleClicked(0) then
                ImGui.TableSetColumnWidthAutoSingle(table_, column_n)
                ImGui.ClearActiveID()
                held = false
            end
            if held then
                if table_.LastResizedColumn == -1 then
                    table_.ResizeLockMinContentsX2 = (table_.RightMostEnabledColumn ~= -1) and table_.Columns[table_.RightMostEnabledColumn].MaxX or -FLT_MAX
                end
                table_.ResizedColumn = column_n
                table_.InstanceInteracted = table_.InstanceCurrent
            end
            if (hovered and g.HoveredIdTimer > TABLE_RESIZE_SEPARATOR_FEEDBACK_TIMER) or held then
                table_.HoveredColumnBorder = column_n
                ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeEW)
            end
        until true
    end
end

function ImGui.EndTable()
    local g = GImGui
    local table_ = g.CurrentTable
    IM_ASSERT_USER_ERROR_RET(table_ ~= nil, "EndTable() call should only be done while in BeginTable() scope!")

    -- If the user never got to call TableNextRow() or TableNextColumn(), we call layout ourselves.
    if not table_.IsLayoutLocked then
        ImGui.TableUpdateLayout(table_)
    end

    local flags = table_.Flags
    local inner_window = table_.InnerWindow
    local outer_window = table_.OuterWindow
    local temp_data = table_.TempData
    IM_ASSERT(inner_window == g.CurrentWindow and inner_window.ID == temp_data.WindowID)
    IM_ASSERT(outer_window == inner_window or outer_window == inner_window.ParentWindow)

    if table_.IsInsideRow then
        ImGui.TableEndRow(table_)
    end

    -- Context menu in columns body
    if band(flags, ImGuiTableFlags.ContextMenuInBody) ~= 0 then
        if table_.HoveredColumnBody ~= -1 and not ImGui.IsAnyItemHovered() and ImGui.IsMouseReleased(ImGuiMouseButton.Right) then
            ImGui.TableOpenContextMenu(table_.HoveredColumnBody)
        end
    end

    -- Finalize table height
    local table_instance = ImGui.TableGetInstanceData(table_, table_.InstanceCurrent)
    ImVec2_Copy(inner_window.DC.PrevLineSize, temp_data.HostBackupPrevLineSize)
    ImVec2_Copy(inner_window.DC.CurrLineSize, temp_data.HostBackupCurrLineSize)
    ImVec2_Copy(inner_window.DC.CursorMaxPos, temp_data.HostBackupCursorMaxPos)
    local inner_content_max_y = ImCeil(table_.RowPosY2) -- Rounding final position is important as we currently don't round row height
    IM_ASSERT(table_.RowPosY2 == inner_window.DC.CursorPos.y)
    if inner_window ~= outer_window then
        inner_window.DC.CursorMaxPos.y = inner_content_max_y
    elseif band(flags, ImGuiTableFlags.NoHostExtendY) == 0 then
        local v = ImMax(table_.OuterRect.Max.y, inner_content_max_y) -- Patch OuterRect/InnerRect height
        table_.OuterRect.Max.y = v; table_.InnerRect.Max.y = v
    end
    table_.WorkRect.Max.y = ImMax(table_.WorkRect.Max.y, table_.OuterRect.Max.y)
    table_instance.LastOuterHeight = table_.OuterRect:GetHeight()

    -- Setup inner scrolling range
    if band(table_.Flags, ImGuiTableFlags.ScrollX) ~= 0 then
        local outer_padding_for_border = (band(table_.Flags, ImGuiTableFlags.BordersOuterV) ~= 0) and TABLE_BORDER_SIZE or 0.0
        local max_pos_x = inner_window.DC.CursorMaxPos.x
        if table_.RightMostEnabledColumn ~= -1 then
            max_pos_x = ImMax(max_pos_x, table_.Columns[table_.RightMostEnabledColumn].WorkMaxX + table_.CellPaddingX + table_.OuterPaddingX - outer_padding_for_border)
        end
        if table_.ResizedColumn ~= -1 then
            max_pos_x = ImMax(max_pos_x, table_.ResizeLockMinContentsX2)
        end
        inner_window.DC.CursorMaxPos.x = max_pos_x + table_.TempData.AngledHeadersExtraWidth
    end

    -- Pop clipping rect
    if band(flags, ImGuiTableFlags.NoClip) == 0 then
        inner_window.DrawList:PopClipRect()
    end
    ImRect_CopyFromV4(inner_window.ClipRect, inner_window.DrawList._ClipRectStack:back())

    -- Draw borders
    if band(flags, ImGuiTableFlags.Borders) ~= 0 then
        ImGui.TableDrawBorders(table_)
    end

    -- Flatten channels and merge draw calls
    local splitter = table_.DrawSplitter
    splitter:SetCurrentChannel(inner_window.DrawList, 0)
    if band(table_.Flags, ImGuiTableFlags.NoClip) == 0 then
        ImGui.TableMergeDrawChannels(table_)
    end
    splitter:Merge(inner_window.DrawList)

    -- Update ColumnsAutoFitWidth to get us ahead for host using our size to auto-resize without waiting for next BeginTable()
    local auto_fit_width_for_fixed = 0.0
    local auto_fit_width_for_stretched = 0.0
    local auto_fit_width_for_stretched_min = 0.0
    for column_n = 0, table_.ColumnsCount - 1 do
        if BitTest(table_.EnabledMaskByIndex, column_n) then
            local column = table_.Columns[column_n]
            local column_width_request
            if band(column.Flags, ImGuiTableColumnFlags.WidthFixed) ~= 0 and band(column.Flags, ImGuiTableColumnFlags.NoResize) == 0 then
                column_width_request = column.WidthRequest
            else
                column_width_request = ImGui.TableGetColumnWidthAuto(table_, column)
            end
            if band(column.Flags, ImGuiTableColumnFlags.WidthFixed) ~= 0 then
                auto_fit_width_for_fixed = auto_fit_width_for_fixed + column_width_request
            else
                auto_fit_width_for_stretched = auto_fit_width_for_stretched + column_width_request
            end
            if band(column.Flags, ImGuiTableColumnFlags.WidthStretch) ~= 0 and band(column.Flags, ImGuiTableColumnFlags.NoResize) ~= 0 then
                auto_fit_width_for_stretched_min = ImMax(auto_fit_width_for_stretched_min, column_width_request / (column.StretchWeight / table_.ColumnsStretchSumWeights))
            end
        end
    end
    local width_spacings = (table_.OuterPaddingX * 2.0) + (table_.CellSpacingX1 + table_.CellSpacingX2) * (table_.ColumnsEnabledCount - 1)
    table_.ColumnsAutoFitWidth = width_spacings + (table_.CellPaddingX * 2.0) * table_.ColumnsEnabledCount + auto_fit_width_for_fixed + ImMax(auto_fit_width_for_stretched, auto_fit_width_for_stretched_min)

    -- Update scroll
    if band(table_.Flags, ImGuiTableFlags.ScrollX) == 0 and inner_window ~= outer_window then
        inner_window.Scroll.x = 0.0
    elseif table_.LastResizedColumn ~= -1 and table_.ResizedColumn == -1 and inner_window.ScrollbarX and table_.InstanceInteracted == table_.InstanceCurrent then
        -- When releasing a column being resized, scroll to keep the resulting column in sight
        local neighbor_width_to_keep_visible = table_.MinColumnWidth + table_.CellPaddingX * 2.0
        local column = table_.Columns[table_.LastResizedColumn]
        if column.MaxX < table_.InnerClipRect.Min.x then
            ImGui.SetScrollFromPosX(inner_window, column.MaxX - inner_window.Pos.x - neighbor_width_to_keep_visible, 1.0)
        elseif column.MaxX > table_.InnerClipRect.Max.x then
            ImGui.SetScrollFromPosX(inner_window, column.MaxX - inner_window.Pos.x + neighbor_width_to_keep_visible, 1.0)
        end
    end

    -- Apply resizing/dragging at the end of the frame
    if table_.ResizedColumn ~= -1 and table_.InstanceCurrent == table_.InstanceInteracted then
        local column = table_.Columns[table_.ResizedColumn]
        local new_x2 = (g.IO.MousePos.x - g.ActiveIdClickOffset.x + ImTrunc(TABLE_RESIZE_SEPARATOR_HALF_THICKNESS * g.CurrentDpiScale))
        local new_width = ImTrunc(new_x2 - column.MinX - table_.CellSpacingX1 - table_.CellPaddingX * 2.0)
        table_.ResizedColumnNextWidth = new_width
    end

    table_.IsActiveIdInTable = (g.ActiveIdIsAlive ~= 0 and table_.IsActiveIdAliveBeforeTable == false)

    -- Pop from id stack
    IM_ASSERT_USER_ERROR(inner_window.IDStack:back() == table_instance.TableInstanceID, "Mismatching PushID/PopID!")
    IM_ASSERT_USER_ERROR(outer_window.DC.ItemWidthStack.Size >= temp_data.HostBackupItemWidthStackSize, "Too many PopItemWidth!")
    if table_.InstanceCurrent > 0 then
        ImGui.PopID()
    end
    ImGui.PopID()

    -- Restore window data that we modified
    local backup_outer_max_pos = V2(outer_window.DC.CursorMaxPos)
    ImRect_Copy(inner_window.WorkRect, temp_data.HostBackupWorkRect)
    ImRect_Copy(inner_window.ParentWorkRect, temp_data.HostBackupParentWorkRect)
    inner_window.SkipItems = table_.HostSkipItems
    ImVec2_Copy(outer_window.DC.CursorPos, table_.OuterRect.Min)
    outer_window.DC.ItemWidth = temp_data.HostBackupItemWidth
    outer_window.DC.ItemWidthStack:resize(temp_data.HostBackupItemWidthStackSize)
    outer_window.DC.ColumnsOffset.x = temp_data.HostBackupColumnsOffset

    -- Layout in outer window
    if inner_window ~= outer_window then
        local backup_nav_layers_active_mask = inner_window.DC.NavLayersActiveMask
        inner_window.DC.NavLayersActiveMask = bor(inner_window.DC.NavLayersActiveMask, lshift(1, table_.NavLayer)) -- So empty table don't appear to navigate differently.
        g.CurrentTable = nil -- To avoid error recovery recursing
        ImGui.EndChild()
        g.CurrentTable = table_
        inner_window.DC.NavLayersActiveMask = backup_nav_layers_active_mask
    else
        inner_window.DC.TreeDepth = inner_window.DC.TreeDepth - 1
        ImGui.ItemSize(table_.OuterRect:GetSize())
        ImGui.ItemAdd(table_.OuterRect, 0)
    end

    -- Override declared contents width/height to enable auto-resize while not needlessly adding a scrollbar
    if band(table_.Flags, ImGuiTableFlags.NoHostExtendX) ~= 0 then
        IM_ASSERT(band(table_.Flags, ImGuiTableFlags.ScrollX) == 0)
        outer_window.DC.CursorMaxPos.x = ImMax(backup_outer_max_pos.x, table_.OuterRect.Min.x + table_.ColumnsAutoFitWidth)
    elseif temp_data.UserOuterSize.x <= 0.0 then
        local outer_content_max_x = table_.OuterRect.Min.x + table_.ColumnsAutoFitWidth
        local decoration_size = table_.TempData.AngledHeadersExtraWidth + ((inner_window ~= outer_window) and inner_window.ScrollbarSizes.x or 0.0)
        outer_window.DC.IdealMaxPos.x = ImMax(outer_window.DC.IdealMaxPos.x, outer_content_max_x + decoration_size - temp_data.UserOuterSize.x)
        outer_window.DC.CursorMaxPos.x = ImMax(backup_outer_max_pos.x, ImMin(table_.OuterRect.Max.x, outer_content_max_x + decoration_size))
    else
        outer_window.DC.CursorMaxPos.x = ImMax(backup_outer_max_pos.x, table_.OuterRect.Max.x)
    end
    if temp_data.UserOuterSize.y <= 0.0 then
        local outer_content_size_y = (inner_window == outer_window) and (inner_content_max_y - table_.InnerRect.Min.y) or (inner_content_max_y - inner_window.DC.CursorStartPos.y)
        local outer_content_max_y = table_.OuterRect.Min.y + outer_content_size_y
        local decoration_size = (inner_window ~= outer_window) and inner_window.ScrollbarSizes.y or 0.0
        outer_window.DC.IdealMaxPos.y = ImMax(outer_window.DC.IdealMaxPos.y, outer_content_max_y + decoration_size - temp_data.UserOuterSize.y)
        outer_window.DC.CursorMaxPos.y = ImMax(backup_outer_max_pos.y, ImMin(table_.OuterRect.Max.y, outer_content_max_y + decoration_size))
    else
        -- OuterRect.Max.y may already have been pushed downward from the initial value (unless ImGuiTableFlags_NoHostExtendY is set)
        outer_window.DC.CursorMaxPos.y = ImMax(backup_outer_max_pos.y, table_.OuterRect.Max.y)
    end

    -- Save settings
    if table_.IsSettingsDirty then
        ImGui.TableSaveSettings(table_)
    end
    table_.IsInitializing = false

    -- Clear or restore current table, if any
    IM_ASSERT(g.CurrentWindow == outer_window and g.CurrentTable == table_)
    IM_ASSERT(g.TablesTempDataStacked > 0)
    g.TablesTempDataStacked = g.TablesTempDataStacked - 1
    temp_data = (g.TablesTempDataStacked > 0) and g.TablesTempData.Data[g.TablesTempDataStacked] or nil
    g.CurrentTable = (temp_data and (temp_data.WindowID == outer_window.ID)) and g.Tables:GetByIndex(temp_data.TableIndex) or nil
    if g.CurrentTable then
        g.CurrentTable.TempData = temp_data
        g.CurrentTable.DrawSplitter = temp_data.DrawSplitter
    end
    outer_window.DC.CurrentTableIdx = g.CurrentTable and g.Tables:GetIndex(g.CurrentTable) or -1
    ImGui.NavUpdateCurrentWindowIsScrollPushableX()
end

-- Called in TableUpdateLayout() when initializing/after loading settings.
-- 'init_mask' specify which fields to initialize.
--- @param column_n int # index of `column` (C++: Columns.index_from_ptr(column))
function ImGui.TableInitColumnDefaults(table_, column, column_n, init_mask)
    local flags = column.Flags
    if band(init_mask, ImGuiTableFlags.Resizable) ~= 0 then
        local init_width_or_weight = column.InitStretchWeightOrWidth
        column.WidthRequest = (band(flags, ImGuiTableColumnFlags.WidthFixed) ~= 0 and init_width_or_weight > 0.0) and init_width_or_weight or -1.0
        column.StretchWeight = (init_width_or_weight > 0.0 and band(flags, ImGuiTableColumnFlags.WidthStretch) ~= 0) and init_width_or_weight or -1.0
        if init_width_or_weight > 0.0 then -- Disable auto-fit if an explicit width/weight has been specified
            column.AutoFitQueue = 0x00
        end
    end
    if band(init_mask, ImGuiTableFlags.Reorderable) ~= 0 then
        column.DisplayOrder = (band(table_.Flags, ImGuiTableFlags.Reorderable) ~= 0) and -1 or column_n
    end
    if band(init_mask, ImGuiTableFlags.Hideable) ~= 0 then
        local v = band(flags, ImGuiTableColumnFlags.DefaultHide) == 0
        column.IsUserEnabled = v; column.IsUserEnabledNextFrame = v
    end
    if band(init_mask, ImGuiTableFlags.Sortable) ~= 0 then
        -- Multiple columns using _DefaultSort will be reassigned unique SortOrder values when building the sort specs.
        column.SortOrder = (band(flags, ImGuiTableColumnFlags.DefaultSort) ~= 0) and 0 or -1
        if band(flags, ImGuiTableColumnFlags.DefaultSort) ~= 0 then
            column.SortDirection = (band(flags, ImGuiTableColumnFlags.PreferSortDescending) ~= 0) and ImGuiSortDirection.Descending or ImGuiSortDirection.Ascending
        else
            column.SortDirection = ImGuiSortDirection.None
        end
    end
end

-- See "COLUMNS SIZING POLICIES" comments at the top of this file
-- If (init_width_or_weight <= 0.0f) it is ignored
local function TableSetupColumnApply(table_, idx, id, name_offset, flags, init_width_or_weight, user_data)
    local column = table_.Columns[idx]

    -- Assert when passing a width or weight if policy is entirely left to default, to avoid storing width into weight and vice-versa.
    if table_.IsDefaultSizingPolicy and band(flags, ImGuiTableColumnFlags.WidthMask_) == 0 and band(flags, ImGuiTableFlags.ScrollX) == 0 then
        IM_ASSERT_USER_ERROR_RET(init_width_or_weight <= 0.0, "TableSetupColumn(): can only specify width/weight if sizing policy is set explicitly in either Table or Column.")
    end

    -- When passing a width automatically enforce WidthFixed policy
    if band(flags, ImGuiTableColumnFlags.WidthMask_) == 0 and init_width_or_weight > 0.0 then
        if band(table_.Flags, ImGuiTableFlags.SizingMask_) == ImGuiTableFlags.SizingFixedFit or band(table_.Flags, ImGuiTableFlags.SizingMask_) == ImGuiTableFlags.SizingFixedSame then
            flags = bor(flags, ImGuiTableColumnFlags.WidthFixed)
        end
    end
    if band(flags, ImGuiTableColumnFlags.AngledHeader) ~= 0 then
        flags = bor(flags, ImGuiTableColumnFlags.NoHeaderLabel)
        table_.AngledHeadersCount = table_.AngledHeadersCount + 1
    end

    TableSetupColumnFlags(table_, column, idx, flags)
    column.ID = id
    column.UserData = user_data
    column.NameOffset = name_offset
    column.InitStretchWeightOrWidth = init_width_or_weight
end

--- @param label                 string?
--- @param flags?                ImGuiTableColumnFlags
--- @param init_width_or_weight? float
--- @param user_data?            ImGuiID
function ImGui.TableSetupColumn(label, flags, init_width_or_weight, user_data)
    if flags == nil then flags = 0 end
    if init_width_or_weight == nil then init_width_or_weight = 0.0 end
    if user_data == nil then user_data = 0 end

    local g = GImGui
    local table_ = g.CurrentTable
    IM_ASSERT_USER_ERROR_RET(table_ ~= nil, "Call should only be done while in BeginTable() scope!")
    IM_ASSERT_USER_ERROR_RET(table_.DeclColumnsCount < table_.ColumnsCount, "TableSetupColumn(): called too many times!")
    IM_ASSERT_USER_ERROR_RET(table_.IsLayoutLocked == false, "TableSetupColumn(): need to call before first row!")
    IM_ASSERT(band(flags, ImGuiTableColumnFlags.StatusMask_) == 0, "Illegal to pass StatusMask values to TableSetupColumn()")

    -- Store name
    local name_offset = -1
    if label ~= nil and label ~= "" then
        name_offset = #table_.ColumnsNames
        table_.ColumnsNames[name_offset + 1] = label
    end
    local column_id = (label ~= nil and label ~= "") and ImHashStr(label) or 0

    -- When ID changed or a column moved: defer the request until layout where we will process full reconcile.
    local column_idx = table_.DeclColumnsCount
    table_.DeclColumnsCount = table_.DeclColumnsCount + 1
    local column = table_.Columns[column_idx]

    -- If topology change goes into reconcile mode
    if table_.IsReconcileMode == false and column.ID ~= column_id and not table_.IsNewTable then
        table_.IsReconcileMode = true
    end

    -- Fast/common path
    if table_.IsReconcileMode == false then
        TableSetupColumnApply(table_, column_idx, column_id, name_offset, flags, init_width_or_weight, user_data)
        column.IsNeedReconcileSrc = false; column.IsNeedReconcileDst = false
        local old = table_.TempData.OldColumnsData
        if old and column_idx < table_.TempData.OldColumnsDataSize then
            old[column_idx].IsNeedReconcileSrc = false
        end
        return
    end

    -- Reconcile path: defer applying data to TableUpdateLayout() -> TableReconcileMovedColumns() -> TableSetupColumnApply().
    local reconcile_data = {
        ID = column_id, NameOffset = name_offset, Flags = flags, InitWidthOrWeight = init_width_or_weight, UserData = user_data,
        ColumnNewIdx = column_idx, ColumnOldIdx = -1, ColumnOldData = ImGuiTableColumn(),
    }
    table_.TempData.ReconcileColumnsRequests:push_back(reconcile_data)
    column.NameOffset = name_offset -- Allow TableGetColumnName() to work before layout
    column.IsNeedReconcileSrc = true; column.IsNeedReconcileDst = true
end

-- NB: This was written to be similar to the logic in TableLoadSettingsForColumns().
function ImGui.TableReconcileColumns(table_)
    local temp_data = table_.TempData
    IMGUI_DEBUG_LOG_TABLE("[table] Reconcile columns for table 0x%08X\n", table_.ID)

    local dst_columns = table_.Columns
    local src_columns, src_count
    if temp_data.OldColumnsData == nil then
        src_columns, src_count = table_.Columns, table_.ColumnsSize
    else
        src_columns, src_count = temp_data.OldColumnsData, temp_data.OldColumnsDataSize
    end

    -- Find matches for named columns.
    local matches = 0
    local reconcile_requests = temp_data.ReconcileColumnsRequests
    for _, reconcile_data in reconcile_requests:iter() do
        if reconcile_data.ID ~= 0 then
            for src_n = 0, src_count - 1 do
                local src_column = src_columns[src_n]
                if src_column.ID == reconcile_data.ID and src_column.IsNeedReconcileSrc then
                    local dst_column = dst_columns[reconcile_data.ColumnNewIdx]
                    IM_ASSERT(src_column.IsNeedReconcileSrc and dst_column.IsNeedReconcileDst)
                    src_column.IsNeedReconcileSrc = false; dst_column.IsNeedReconcileDst = false
                    reconcile_data.ColumnOldIdx = src_n
                    reconcile_data.ColumnOldData = TableColumnClone(src_column)
                    matches = matches + 1
                    break
                end
            end
        end
    end

    -- Remaining entries are matched sequentially.
    local dst_idx = 1 -- index in reconcile array (1-based)
    if matches ~= reconcile_requests.Size then
        for src_n = 0, src_count - 1 do
            local src_column = src_columns[src_n]
            if src_column.IsNeedReconcileSrc then
                while dst_idx <= reconcile_requests.Size and reconcile_requests.Data[dst_idx].ColumnOldIdx ~= -1 do
                    dst_idx = dst_idx + 1
                end
                if dst_idx > reconcile_requests.Size then
                    break
                end
                local reconcile_data = reconcile_requests.Data[dst_idx]
                local dst_column = dst_columns[reconcile_data.ColumnNewIdx]
                IM_ASSERT(src_column.IsNeedReconcileSrc and dst_column.IsNeedReconcileDst)
                src_column.IsNeedReconcileSrc = false; dst_column.IsNeedReconcileDst = false
                reconcile_data.ColumnOldIdx = src_n
                reconcile_data.ColumnOldData = TableColumnClone(src_column)
            end
        end
    end

    -- Apply in the final pass. Because it is possible that src_columns == table->Columns we went through a temporary copy.
    for _, reconcile_data in reconcile_requests:iter() do
        TableColumnCopy(table_.Columns[reconcile_data.ColumnNewIdx], reconcile_data.ColumnOldData)
        TableSetupColumnApply(table_, reconcile_data.ColumnNewIdx, reconcile_data.ID, reconcile_data.NameOffset, reconcile_data.Flags, reconcile_data.InitWidthOrWeight, reconcile_data.UserData)
    end
    ImGui.TableFixDisplayOrder(table_)
    table_.IsSettingsDirty = true -- FIXME-RECONCILE: Necessary?
    table_.IsReconcileMode = false
    reconcile_requests:resize(0) -- GC-ed once in NewFrame()
end

-- [Public]
function ImGui.TableSetupScrollFreeze(columns, rows)
    local g = GImGui
    local table_ = g.CurrentTable
    IM_ASSERT_USER_ERROR_RET(table_ ~= nil, "Call should only be done while in BeginTable() scope!")
    IM_ASSERT(table_.IsLayoutLocked == false, "TableSetupColumn(): need to call before first row!")
    IM_ASSERT(columns >= 0 and columns < IMGUI_TABLE_MAX_COLUMNS)
    IM_ASSERT(rows >= 0 and rows < 128) -- Arbitrary limit

    table_.FreezeColumnsRequest = (band(table_.Flags, ImGuiTableFlags.ScrollX) ~= 0) and ImMin(columns, table_.ColumnsCount) or 0
    table_.FreezeColumnsCount = (table_.InnerWindow.Scroll.x ~= 0.0) and table_.FreezeColumnsRequest or 0
    table_.FreezeRowsRequest = (band(table_.Flags, ImGuiTableFlags.ScrollY) ~= 0) and rows or 0
    table_.FreezeRowsCount = (table_.InnerWindow.Scroll.y ~= 0.0) and table_.FreezeRowsRequest or 0
    table_.IsUnfrozenRows = (table_.FreezeRowsCount == 0) -- Make sure this is set before TableUpdateLayout() so ImGuiListClipper can benefit from it.
end

----------------------------------------------------------------
-- [SECTION] Tables: Simple accessors
----------------------------------------------------------------

function ImGui.SetWindowClipRectBeforeSetChannel(window, clip_rect)
    local clip_rect_vec4 = clip_rect:ToVec4()
    ImRect_Copy(window.ClipRect, clip_rect)
    ImVec4_Copy(window.DrawList._CmdHeader.ClipRect, clip_rect_vec4)
    window.DrawList._ClipRectStack.Data[window.DrawList._ClipRectStack.Size] = clip_rect_vec4
end

function ImGui.TableGetColumnCount()
    local g = GImGui
    local table_ = g.CurrentTable
    return table_ and table_.ColumnsCount or 0
end

-- Overloads: TableGetColumnName(column_n?) / TableGetColumnName(table, column_n)
function ImGui.TableGetColumnName(a, b)
    local table_, column_n
    if type(a) == "table" then
        table_, column_n = a, b
    else
        local g = GImGui
        table_ = g.CurrentTable
        if not table_ then
            return nil
        end
        column_n = a or -1
        if column_n < 0 then
            column_n = table_.CurrentColumn
        end
    end
    if table_.IsLayoutLocked == false and column_n >= table_.DeclColumnsCount then
        return "" -- NameOffset is invalid at this point
    end
    local column = table_.Columns[column_n]
    if column.NameOffset == -1 then
        return ""
    end
    return table_.ColumnsNames[column.NameOffset + 1]
end

-- Change user accessible enabled/disabled state of a column (often perceived as "showing/hiding" from users point of view)
function ImGui.TableSetColumnEnabled(column_n, enabled)
    local g = GImGui
    local table_ = g.CurrentTable
    IM_ASSERT_USER_ERROR_RET(table_ ~= nil, "Call should only be done while in BeginTable() scope!")
    IM_ASSERT(band(table_.Flags, ImGuiTableFlags.Hideable) ~= 0) -- See comments above
    if column_n < 0 then
        column_n = table_.CurrentColumn
    end
    IM_ASSERT(column_n >= 0 and column_n < table_.ColumnsCount)
    local column = table_.Columns[column_n]
    column.IsUserEnabledNextFrame = enabled
end

-- We allow querying for an extra column in order to poll the IsHovered state of the right-most section
function ImGui.TableGetColumnFlags(column_n)
    if column_n == nil then column_n = -1 end
    local g = GImGui
    local table_ = g.CurrentTable
    if not table_ then
        return ImGuiTableColumnFlags.None
    end
    if column_n < 0 then
        column_n = table_.CurrentColumn
    end
    if column_n == table_.ColumnsCount then
        return (table_.HoveredColumnBody == column_n) and ImGuiTableColumnFlags.IsHovered or ImGuiTableColumnFlags.None
    end
    return table_.Columns[column_n].Flags
end

-- Return the cell rectangle based on currently known height.
function ImGui.TableGetCellBgRect(table_, column_n)
    local column = table_.Columns[column_n]
    local x1 = column.MinX
    local x2 = column.MaxX
    x1 = ImMax(x1, table_.WorkRect.Min.x)
    x2 = ImMin(x2, table_.WorkRect.Max.x)
    return ImRect(x1, table_.RowPosY1, x2, table_.RowPosY2)
end

-- Return the resizing ID for the right-side of the given column.
function ImGui.TableGetColumnResizeID(table_, column_n, instance_no)
    if instance_no == nil then instance_no = 0 end
    IM_ASSERT(column_n >= 0 and column_n < table_.ColumnsCount)
    local instance_id = ImGui.TableGetInstanceID(table_, instance_no)
    return band(instance_id + 1 + column_n, 0xFFFFFFFF) -- FIXME: #6140: still not ideal
end

-- Return -1 when table is not hovered. return columns_count if hovering the unused space at the right of the right-most visible column.
function ImGui.TableGetHoveredColumn()
    local g = GImGui
    local table_ = g.CurrentTable
    if not table_ then
        return -1
    end
    return table_.HoveredColumnBody
end

-- Return -1 when table is not hovered. Return maxrow+1 if in table but below last submitted row.
function ImGui.TableGetHoveredRow()
    local g = GImGui
    local table_ = g.CurrentTable
    if not table_ then
        return -1
    end
    local table_instance = ImGui.TableGetInstanceData(table_, table_.InstanceCurrent)
    return table_instance.HoveredRowLast
end

function ImGui.TableSetBgColor(target, color, column_n)
    if column_n == nil then column_n = -1 end
    local g = GImGui
    local table_ = g.CurrentTable
    IM_ASSERT_USER_ERROR_RET(table_ ~= nil, "Call should only be done while in BeginTable() scope!")
    IM_ASSERT(target ~= ImGuiTableBgTarget.None)

    if color == IM_COL32_DISABLE then
        color = 0
    end

    -- We cannot draw neither the cell or row background immediately as we don't know the row height at this point in time.
    if target == ImGuiTableBgTarget.CellBg then
        if table_.RowPosY1 > table_.InnerClipRect.Max.y then -- Discard
            return
        end
        if column_n == -1 then
            column_n = table_.CurrentColumn
        end
        if not BitTest(table_.VisibleMaskByIndex, column_n) then
            return
        end
        if table_.RowCellDataCurrent < 0 or table_.RowCellData[table_.RowCellDataCurrent].Column ~= column_n then
            table_.RowCellDataCurrent = table_.RowCellDataCurrent + 1
        end
        local cell_data = table_.RowCellData[table_.RowCellDataCurrent]
        cell_data.BgColor = color
        cell_data.Column = column_n
    elseif target == ImGuiTableBgTarget.RowBg0 or target == ImGuiTableBgTarget.RowBg1 then
        if table_.RowPosY1 > table_.InnerClipRect.Max.y then -- Discard
            return
        end
        IM_ASSERT(column_n == -1)
        local bg_idx = (target == ImGuiTableBgTarget.RowBg1) and 1 or 0
        table_.RowBgColor[bg_idx] = color
    else
        IM_ASSERT(false)
    end
end

----------------------------------------------------------------
-- [SECTION] Tables: Row changes
----------------------------------------------------------------

-- [Public] Note: for row coloring we use ->RowBgColorCounter which is the same value without counting header rows
function ImGui.TableGetRowIndex()
    local g = GImGui
    local table_ = g.CurrentTable
    if not table_ then
        return 0
    end
    return table_.CurrentRow
end

-- [Public] Starts into the first cell of a new row
--- @param row_flags?      ImGuiTableRowFlags
--- @param row_min_height? float
function ImGui.TableNextRow(row_flags, row_min_height)
    if row_flags == nil then row_flags = 0 end
    if row_min_height == nil then row_min_height = 0.0 end

    local g = GImGui
    local table_ = g.CurrentTable

    if not table_.IsLayoutLocked then
        ImGui.TableUpdateLayout(table_)
    end
    if table_.IsInsideRow then
        ImGui.TableEndRow(table_)
    end

    table_.LastRowFlags = table_.RowFlags
    table_.RowFlags = row_flags
    table_.RowCellPaddingY = g.Style.CellPadding.y
    table_.RowMinHeight = row_min_height
    ImGui.TableBeginRow(table_)

    -- We honor min_row_height requested by user, but cannot guarantee per-row maximum height,
    -- because that would essentially require a unique clipping rectangle per-cell.
    table_.RowPosY2 = table_.RowPosY2 + table_.RowCellPaddingY * 2.0
    table_.RowPosY2 = ImMax(table_.RowPosY2, table_.RowPosY1 + row_min_height)

    -- Disable output until user calls TableNextColumn()
    table_.InnerWindow.SkipItems = true
end

-- [Internal] Only called by TableNextRow()
function ImGui.TableBeginRow(table_)
    local window = table_.InnerWindow
    IM_ASSERT(not table_.IsInsideRow)

    -- New row
    table_.CurrentRow = table_.CurrentRow + 1
    table_.CurrentColumn = -1
    table_.RowBgColor[0] = IM_COL32_DISABLE; table_.RowBgColor[1] = IM_COL32_DISABLE
    table_.RowCellDataCurrent = -1
    table_.IsInsideRow = true

    -- Begin frozen rows
    local next_y1 = table_.RowPosY2
    if table_.CurrentRow == 0 and table_.FreezeRowsCount > 0 then
        next_y1 = table_.OuterRect.Min.y
        window.DC.CursorPos.y = next_y1
    end

    table_.RowPosY1 = next_y1; table_.RowPosY2 = next_y1
    table_.RowTextBaseline = 0.0
    table_.RowIndentOffsetX = window.DC.Indent.x - table_.HostIndentX -- Lock indent

    window.DC.PrevLineTextBaseOffset = 0.0
    window.DC.CursorPosPrevLine.x = window.DC.CursorPos.x
    window.DC.CursorPosPrevLine.y = window.DC.CursorPos.y + table_.RowCellPaddingY -- This allows users to call SameLine() to share LineSize between columns.
    window.DC.PrevLineSize.x = 0.0; window.DC.PrevLineSize.y = 0.0
    window.DC.CurrLineSize.x = 0.0; window.DC.CurrLineSize.y = 0.0
    window.DC.IsSameLine = false; window.DC.IsSetPos = false
    window.DC.CursorMaxPos.y = next_y1

    -- Making the header BG color non-transparent will allow us to overlay it multiple times when handling smooth dragging.
    if band(table_.RowFlags, ImGuiTableRowFlags.Headers) ~= 0 then
        ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0, ImGui.GetColorU32(ImGuiCol.TableHeaderBg))
        if table_.CurrentRow == 0 then
            table_.IsUsingHeaders = true
        end
    end
end

-- [Internal] Called by TableNextRow()
function ImGui.TableEndRow(table_)
    local g = GImGui
    local window = g.CurrentWindow
    IM_ASSERT(window == table_.InnerWindow)
    IM_ASSERT(table_.IsInsideRow)

    if table_.CurrentColumn ~= -1 then
        ImGui.TableEndCell(table_)
        table_.CurrentColumn = -1
    end

    -- Logging
    if g.LogEnabled then
        ImGui.LogRenderedText(nil, "|")
    end

    -- Position cursor at the bottom of our row so it can be used for e.g. clipping calculation.
    window.DC.CursorPos.y = table_.RowPosY2

    -- Row background fill
    local bg_y1 = table_.RowPosY1
    local bg_y2 = table_.RowPosY2
    local unfreeze_rows_actual = (table_.CurrentRow + 1 == table_.FreezeRowsCount)
    local unfreeze_rows_request = (table_.CurrentRow + 1 == table_.FreezeRowsRequest)
    local table_instance = ImGui.TableGetInstanceData(table_, table_.InstanceCurrent)
    if band(table_.RowFlags, ImGuiTableRowFlags.Headers) ~= 0 and (table_.CurrentRow == 0 or band(table_.LastRowFlags, ImGuiTableRowFlags.Headers) ~= 0) then
        table_instance.LastTopHeadersRowHeight = table_instance.LastTopHeadersRowHeight + bg_y2 - bg_y1
    end

    local is_visible = (bg_y2 >= table_.InnerClipRect.Min.y and bg_y1 <= table_.InnerClipRect.Max.y)
    if is_visible then
        -- Update data for TableGetHoveredRow()
        if table_.HoveredColumnBody ~= -1 and g.IO.MousePos.y >= bg_y1 and g.IO.MousePos.y < bg_y2 and table_instance.HoveredRowNext < 0 then
            table_instance.HoveredRowNext = table_.CurrentRow
        end

        -- Decide of background color for the row
        local bg_col0 = 0
        local bg_col1 = 0
        if table_.RowBgColor[0] ~= IM_COL32_DISABLE then
            bg_col0 = table_.RowBgColor[0]
        elseif band(table_.Flags, ImGuiTableFlags.RowBg) ~= 0 then
            bg_col0 = ImGui.GetColorU32((band(table_.RowBgColorCounter, 1) ~= 0) and ImGuiCol.TableRowBgAlt or ImGuiCol.TableRowBg)
        end
        if table_.RowBgColor[1] ~= IM_COL32_DISABLE then
            bg_col1 = table_.RowBgColor[1]
        end

        -- Decide of top border color
        local top_border_col = 0
        local border_size = TABLE_BORDER_SIZE
        if table_.CurrentRow > 0 and band(table_.Flags, ImGuiTableFlags.BordersInnerH) ~= 0 then
            top_border_col = (band(table_.LastRowFlags, ImGuiTableRowFlags.Headers) ~= 0) and table_.BorderColorStrong or table_.BorderColorLight
        end

        local draw_cell_bg_color = table_.RowCellDataCurrent >= 0
        local draw_strong_bottom_border = unfreeze_rows_actual
        if bor(bg_col0, bg_col1, top_border_col) ~= 0 or draw_strong_bottom_border or draw_cell_bg_color then
            -- In theory we could call SetWindowClipRectBeforeSetChannel() but since we know TableEndRow() is
            -- always followed by a change of clipping rectangle we perform the smallest overwrite possible here.
            if band(table_.Flags, ImGuiTableFlags.NoClip) == 0 then
                ImVec4_Copy(window.DrawList._CmdHeader.ClipRect, table_.Bg0ClipRectForDrawCmd:ToVec4())
            end
            table_.DrawSplitter:SetCurrentChannel(window.DrawList, TABLE_DRAW_CHANNEL_BG0)
        end

        -- Draw row background
        -- We soft/cpu clip this so all backgrounds and borders can share the same clipping rectangle
        if bg_col0 ~= 0 or bg_col1 ~= 0 then
            local row_rect = ImRect(table_.WorkRect.Min.x, bg_y1, table_.WorkRect.Max.x, bg_y2)
            row_rect:ClipWith(table_.BgClipRect)
            if bg_col0 ~= 0 and row_rect.Min.y < row_rect.Max.y then
                window.DrawList:AddRectFilled(row_rect.Min, row_rect.Max, bg_col0)
            end
            if bg_col1 ~= 0 and row_rect.Min.y < row_rect.Max.y then
                window.DrawList:AddRectFilled(row_rect.Min, row_rect.Max, bg_col1)
            end
        end

        -- Draw cell background color
        if draw_cell_bg_color then
            for cell_n = 0, table_.RowCellDataCurrent do
                local cell_data = table_.RowCellData[cell_n]
                -- As we render the BG here we need to clip things (for layout we would not)
                local column = table_.Columns[cell_data.Column]
                local cell_bg_rect = ImGui.TableGetCellBgRect(table_, cell_data.Column)
                cell_bg_rect:ClipWith(table_.BgClipRect)
                cell_bg_rect.Min.x = ImMax(cell_bg_rect.Min.x, column.ClipRect.Min.x) -- So that first column after frozen one gets clipped when scrolling
                cell_bg_rect.Max.x = ImMin(cell_bg_rect.Max.x, column.MaxX)
                if cell_bg_rect.Min.y < cell_bg_rect.Max.y then
                    window.DrawList:AddRectFilled(cell_bg_rect.Min, cell_bg_rect.Max, cell_data.BgColor)
                end
            end
        end

        -- Draw top border
        if top_border_col ~= 0 and bg_y1 >= table_.BgClipRect.Min.y and bg_y1 < table_.BgClipRect.Max.y then
            window.DrawList:AddLineH(table_.BorderX1, table_.BorderX2, bg_y1, top_border_col, border_size)
        end

        -- Draw bottom border at the row unfreezing mark (always strong)
        if draw_strong_bottom_border and bg_y2 >= table_.BgClipRect.Min.y and bg_y2 < table_.BgClipRect.Max.y then
            window.DrawList:AddLineH(table_.BorderX1, table_.BorderX2, bg_y2, table_.BorderColorStrong, border_size)
        end
    end

    -- End frozen rows (when we are past the last frozen row line, teleport cursor and alter clipping rectangle)
    if unfreeze_rows_request then
        IM_ASSERT(table_.FreezeRowsRequest > 0)
        for column_n = 0, table_.ColumnsCount - 1 do
            table_.Columns[column_n].NavLayerCurrent = table_.NavLayer
        end
        local y0 = ImMax(table_.RowPosY2 + 1, table_.InnerClipRect.Min.y)
        table_instance.LastFrozenHeight = y0 - table_.OuterRect.Min.y

        if unfreeze_rows_actual then
            IM_ASSERT(table_.IsUnfrozenRows == false)
            table_.IsUnfrozenRows = true

            -- BgClipRect starts as table->InnerClipRect, reduce it now and make BgClipRectForDrawCmd == BgClipRect
            local min_y = ImMin(y0, table_.InnerClipRect.Max.y)
            table_.BgClipRect.Min.y = min_y; table_.Bg2ClipRectForDrawCmd.Min.y = min_y
            table_.BgClipRect.Max.y = table_.InnerClipRect.Max.y; table_.Bg2ClipRectForDrawCmd.Max.y = table_.InnerClipRect.Max.y
            table_.Bg2DrawChannelCurrent = table_.Bg2DrawChannelUnfrozen
            IM_ASSERT(table_.Bg2ClipRectForDrawCmd.Min.y <= table_.Bg2ClipRectForDrawCmd.Max.y)

            local row_height = table_.RowPosY2 - table_.RowPosY1
            table_.RowPosY2 = table_.WorkRect.Min.y + table_.RowPosY2 - table_.OuterRect.Min.y
            window.DC.CursorPos.y = table_.RowPosY2
            table_.RowPosY1 = table_.RowPosY2 - row_height
            for column_n = 0, table_.ColumnsCount - 1 do
                local column = table_.Columns[column_n]
                column.DrawChannelCurrent = column.DrawChannelUnfrozen
                column.ClipRect.Min.y = table_.Bg2ClipRectForDrawCmd.Min.y
            end

            -- Update cliprect ahead of TableBeginCell() so clipper can access to new ClipRect->Min.y
            ImGui.SetWindowClipRectBeforeSetChannel(window, table_.Columns[0].ClipRect)
            table_.DrawSplitter:SetCurrentChannel(window.DrawList, table_.Columns[0].DrawChannelCurrent)
        end
    end

    if band(table_.RowFlags, ImGuiTableRowFlags.Headers) == 0 then
        table_.RowBgColorCounter = table_.RowBgColorCounter + 1
    end
    table_.IsInsideRow = false
end

----------------------------------------------------------------
-- [SECTION] Tables: Columns changes
----------------------------------------------------------------

function ImGui.TableGetColumnIndex()
    local g = GImGui
    local table_ = g.CurrentTable
    if not table_ then
        return 0
    end
    return table_.CurrentColumn
end

-- [Public] Append into a specific column
function ImGui.TableSetColumnIndex(column_n)
    local g = GImGui
    local table_ = g.CurrentTable
    if not table_ then
        return false
    end

    if table_.CurrentColumn ~= column_n then
        if table_.CurrentColumn ~= -1 then
            ImGui.TableEndCell(table_)
        end
        if not (column_n >= 0 and column_n < table_.ColumnsCount) then
            IM_ASSERT_USER_ERROR(false, "TableSetColumnIndex() invalid column index!")
            return false
        end
        ImGui.TableBeginCell(table_, column_n)
    end

    -- Return whether the column is visible. User may choose to skip submitting items based on this return value,
    -- however they shouldn't skip submitting for columns that may have the tallest contribution to row height.
    return table_.Columns[column_n].IsRequestOutput
end

-- [Public] Append into the next column, wrap and create a new row when already on last column
function ImGui.TableNextColumn()
    local g = GImGui
    local table_ = g.CurrentTable
    if not table_ then
        return false
    end

    if table_.IsInsideRow and table_.CurrentColumn + 1 < table_.ColumnsCount then
        if table_.CurrentColumn ~= -1 then
            ImGui.TableEndCell(table_)
        end
        ImGui.TableBeginCell(table_, table_.CurrentColumn + 1)
    else
        ImGui.TableNextRow()
        ImGui.TableBeginCell(table_, 0)
    end

    -- Return whether the column is visible. User may choose to skip submitting items based on this return value,
    -- however they shouldn't skip submitting for columns that may have the tallest contribution to row height.
    return table_.Columns[table_.CurrentColumn].IsRequestOutput
end

-- [Internal] Called by TableSetColumnIndex()/TableNextColumn()
-- This is called very frequently, so we need to be mindful of unnecessary overhead.
function ImGui.TableBeginCell(table_, column_n)
    local g = GImGui
    local column = table_.Columns[column_n]
    local window = table_.InnerWindow
    table_.CurrentColumn = column_n

    -- Start position is roughly ~~ CellRect.Min + CellPadding + Indent
    local start_x = column.WorkMinX
    if band(column.Flags, ImGuiTableColumnFlags.IndentEnable) ~= 0 then
        start_x = start_x + table_.RowIndentOffsetX -- ~~ += window.DC.Indent.x - table->HostIndentX, except we locked it for the row.
    end

    window.DC.CursorPos.x = start_x
    window.DC.CursorPos.y = table_.RowPosY1 + table_.RowCellPaddingY
    window.DC.CursorMaxPos.x = window.DC.CursorPos.x
    window.DC.ColumnsOffset.x = start_x - window.Pos.x - window.DC.Indent.x -- FIXME-WORKRECT
    window.DC.CursorPosPrevLine.x = window.DC.CursorPos.x -- PrevLine.y is preserved. This allows users to call SameLine() to share LineSize between columns.
    window.DC.CurrLineTextBaseOffset = table_.RowTextBaseline
    window.DC.NavLayerCurrent = column.NavLayerCurrent

    -- Note how WorkRect.Max.y is only set once during layout
    window.WorkRect.Min.y = window.DC.CursorPos.y
    window.WorkRect.Min.x = column.WorkMinX
    window.WorkRect.Max.x = column.WorkMaxX
    window.DC.ItemWidth = column.ItemWidth

    window.SkipItems = column.IsSkipItems
    if column.IsSkipItems then
        g.LastItemData.ID = 0
        g.LastItemData.StatusFlags = 0
    end

    -- Also see TablePushColumnChannel()
    if band(table_.Flags, ImGuiTableFlags.NoClip) ~= 0 then
        -- FIXME: if we end up drawing all borders/bg in EndTable, could remove this and just assert that channel hasn't changed.
        table_.DrawSplitter:SetCurrentChannel(window.DrawList, TABLE_DRAW_CHANNEL_NOCLIP)
    else
        -- FIXME-TABLE: Could avoid this if draw channel is dummy channel?
        ImGui.SetWindowClipRectBeforeSetChannel(window, column.ClipRect)
        table_.DrawSplitter:SetCurrentChannel(window.DrawList, column.DrawChannelCurrent)
    end

    -- Logging
    if g.LogEnabled and not column.IsSkipItems then
        ImGui.LogRenderedText(window.DC.CursorPos, "|")
        g.LogLinePosY = FLT_MAX
    end
end

-- [Internal] Called by TableNextRow()/TableSetColumnIndex()/TableNextColumn()
function ImGui.TableEndCell(table_)
    local column = table_.Columns[table_.CurrentColumn]
    local window = table_.InnerWindow

    if window.DC.IsSetPos then
        ImGui.ErrorCheckUsingSetCursorPosToExtendParentBoundaries()
    end

    -- Report maximum position so we can infer content size per column.
    local x = window.DC.CursorMaxPos.x
    if band(table_.RowFlags, ImGuiTableRowFlags.Headers) ~= 0 then
        column.ContentMaxXHeadersUsed = ImMax(column.ContentMaxXHeadersUsed, x) -- Useful in case user submit contents in header row that is not a TableHeader() call
    elseif table_.IsUnfrozenRows then
        column.ContentMaxXUnfrozen = ImMax(column.ContentMaxXUnfrozen, x)
    else
        column.ContentMaxXFrozen = ImMax(column.ContentMaxXFrozen, x)
    end
    if column.IsEnabled then
        table_.RowPosY2 = ImMax(table_.RowPosY2, window.DC.CursorMaxPos.y + table_.RowCellPaddingY)
    end
    column.ItemWidth = window.DC.ItemWidth

    -- Propagate text baseline for the entire row
    table_.RowTextBaseline = ImMax(table_.RowTextBaseline, window.DC.PrevLineTextBaseOffset)
end

----------------------------------------------------------------
-- [SECTION] Tables: Columns width management
----------------------------------------------------------------

-- Maximum column content width given current layout. Use column->MinX so this value differs on a per-column basis.
function ImGui.TableCalcMaxColumnWidth(table_, column_n)
    local column = table_.Columns[column_n]
    local max_width = FLT_MAX
    local min_column_distance = table_.MinColumnWidth + table_.CellPaddingX * 2.0 + table_.CellSpacingX1 + table_.CellSpacingX2
    if band(table_.Flags, ImGuiTableFlags.ScrollX) ~= 0 then
        -- Frozen columns can't reach beyond visible width else scrolling will naturally break.
        if column.DisplayOrder < table_.FreezeColumnsRequest then
            max_width = (table_.InnerClipRect.Max.x - (table_.FreezeColumnsRequest - column.DisplayOrder) * min_column_distance) - column.MinX
            max_width = max_width - table_.OuterPaddingX - table_.CellPaddingX - table_.CellSpacingX2
        end
    elseif band(table_.Flags, ImGuiTableFlags.NoKeepColumnsVisible) == 0 then
        -- If horizontal scrolling if disabled, we apply a final lossless shrinking of columns in order to make sure they are all visible.
        max_width = table_.WorkRect.Max.x - (table_.ColumnsEnabledCount - column.IndexWithinEnabledSet - 1) * min_column_distance - column.MinX
        max_width = max_width - table_.CellSpacingX2
        max_width = max_width - table_.CellPaddingX * 2.0
        max_width = max_width - table_.OuterPaddingX
    end
    return max_width
end

-- Note this is meant to be stored in column->WidthAuto, please generally use the WidthAuto field
function ImGui.TableGetColumnWidthAuto(table_, column)
    local content_width_body = ImMax(column.ContentMaxXFrozen, column.ContentMaxXUnfrozen) - column.WorkMinX
    local content_width_headers = column.ContentMaxXHeadersIdeal - column.WorkMinX
    local width_auto = content_width_body
    if band(column.Flags, ImGuiTableColumnFlags.NoHeaderWidth) == 0 then
        width_auto = ImMax(width_auto, content_width_headers)
    end

    -- Non-resizable fixed columns preserve their requested width
    if band(column.Flags, ImGuiTableColumnFlags.WidthFixed) ~= 0 and column.InitStretchWeightOrWidth > 0.0 then
        if band(table_.Flags, ImGuiTableFlags.Resizable) == 0 or band(column.Flags, ImGuiTableColumnFlags.NoResize) ~= 0 then
            width_auto = column.InitStretchWeightOrWidth
        end
    end

    return ImMax(width_auto, table_.MinColumnWidth)
end

-- 'width' = inner column width, without padding
function ImGui.TableSetColumnWidth(column_n, width)
    local g = GImGui
    local table_ = g.CurrentTable
    IM_ASSERT(table_ ~= nil and table_.IsLayoutLocked == false)
    IM_ASSERT(column_n >= 0 and column_n < table_.ColumnsCount)
    local column_0 = table_.Columns[column_n]
    local column_0_width = width

    -- Apply constraints early
    IM_ASSERT(table_.MinColumnWidth > 0.0)
    local min_width = table_.MinColumnWidth
    local max_width = ImMax(min_width, column_0.WidthMax) -- Don't use TableCalcMaxColumnWidth() here as it would rely on MinX from last instance (#7933)
    column_0_width = ImClamp(column_0_width, min_width, max_width)
    if column_0.WidthGiven == column_0_width or column_0.WidthRequest == column_0_width then
        return
    end

    local column_1 = (column_0.NextEnabledColumn ~= -1) and table_.Columns[column_0.NextEnabledColumn] or nil

    -- If we have all Fixed columns OR resizing a Fixed column that doesn't come after a Stretch one, we can do an offsetting resize.
    -- This is the preferred resize path
    if band(column_0.Flags, ImGuiTableColumnFlags.WidthFixed) ~= 0 then
        if not column_1 or table_.LeftMostStretchedColumn == -1 or table_.Columns[table_.LeftMostStretchedColumn].DisplayOrder >= column_0.DisplayOrder then
            column_0.WidthRequest = column_0_width
            table_.IsSettingsDirty = true
            return
        end
    end

    -- We can also use previous column if there's no next one (this is used when doing an auto-fit on the right-most stretch column)
    if column_1 == nil then
        column_1 = (column_0.PrevEnabledColumn ~= -1) and table_.Columns[column_0.PrevEnabledColumn] or nil
    end
    if column_1 == nil then
        return
    end

    -- Resizing from right-side of a Stretch column before a Fixed column forward sizing to left-side of fixed column.
    -- (old_a + old_b == new_a + new_b) --> (new_a == old_a + old_b - new_b)
    local column_1_width = ImMax(column_1.WidthRequest - (column_0_width - column_0.WidthRequest), min_width)
    column_0_width = column_0.WidthRequest + column_1.WidthRequest - column_1_width
    IM_ASSERT(column_0_width > 0.0 and column_1_width > 0.0)
    column_0.WidthRequest = column_0_width
    column_1.WidthRequest = column_1_width
    if band(bor(column_0.Flags, column_1.Flags), ImGuiTableColumnFlags.WidthStretch) ~= 0 then
        ImGui.TableUpdateColumnsWeightFromWidth(table_)
    end
    table_.IsSettingsDirty = true
end

-- Disable clipping then auto-fit, will take 2 frames
function ImGui.TableSetColumnWidthAutoSingle(table_, column_n)
    -- Single auto width uses auto-fit
    local column = table_.Columns[column_n]
    if not column.IsEnabled then
        return
    end
    column.CannotSkipItemsQueue = lshift(1, 0)
    table_.AutoFitSingleColumn = column_n
end

function ImGui.TableSetColumnWidthAutoAll(table_)
    for column_n = 0, table_.ColumnsCount - 1 do
        local column = table_.Columns[column_n]
        if column.IsEnabled or band(column.Flags, ImGuiTableColumnFlags.WidthStretch) ~= 0 then -- Cannot reset weight of hidden stretch column
            column.CannotSkipItemsQueue = lshift(1, 0)
            column.AutoFitQueue = lshift(1, 1)
        end
    end
end

function ImGui.TableUpdateColumnsWeightFromWidth(table_)
    IM_ASSERT(table_.LeftMostStretchedColumn ~= -1 and table_.RightMostStretchedColumn ~= -1)

    -- Measure existing quantities
    local visible_weight = 0.0
    local visible_width = 0.0
    for column_n = 0, table_.ColumnsCount - 1 do
        local column = table_.Columns[column_n]
        if column.IsEnabled and band(column.Flags, ImGuiTableColumnFlags.WidthStretch) ~= 0 then
            IM_ASSERT(column.StretchWeight > 0.0)
            visible_weight = visible_weight + column.StretchWeight
            visible_width = visible_width + column.WidthRequest
        end
    end
    IM_ASSERT(visible_weight > 0.0 and visible_width > 0.0)

    -- Apply new weights
    for column_n = 0, table_.ColumnsCount - 1 do
        local column = table_.Columns[column_n]
        if column.IsEnabled and band(column.Flags, ImGuiTableColumnFlags.WidthStretch) ~= 0 then
            column.StretchWeight = (column.WidthRequest / visible_width) * visible_weight
            IM_ASSERT(column.StretchWeight > 0.0)
        end
    end
end

----------------------------------------------------------------
-- [SECTION] Tables: Drawing
----------------------------------------------------------------

-- Bg2 is used by Selectable (and possibly other widgets) to render to the background.
function ImGui.TablePushBackgroundChannel()
    local g = GImGui
    local window = g.CurrentWindow
    local table_ = g.CurrentTable

    -- Optimization: avoid SetCurrentChannel() + PushClipRect()
    ImRect_Copy(table_.HostBackupInnerClipRect, window.ClipRect)
    ImGui.SetWindowClipRectBeforeSetChannel(window, table_.Bg2ClipRectForDrawCmd)
    table_.DrawSplitter:SetCurrentChannel(window.DrawList, table_.Bg2DrawChannelCurrent)
end

function ImGui.TablePopBackgroundChannel()
    local g = GImGui
    local window = g.CurrentWindow
    local table_ = g.CurrentTable

    -- Optimization: avoid PopClipRect() + SetCurrentChannel()
    ImGui.SetWindowClipRectBeforeSetChannel(window, table_.HostBackupInnerClipRect)
    table_.DrawSplitter:SetCurrentChannel(window.DrawList, table_.Columns[table_.CurrentColumn].DrawChannelCurrent)
end

-- Also see TableBeginCell()
function ImGui.TablePushColumnChannel(column_n)
    local g = GImGui
    local table_ = g.CurrentTable

    -- Optimization: avoid SetCurrentChannel() + PushClipRect()
    if band(table_.Flags, ImGuiTableFlags.NoClip) ~= 0 then
        return
    end
    local window = g.CurrentWindow
    local column = table_.Columns[column_n]
    ImGui.SetWindowClipRectBeforeSetChannel(window, column.ClipRect)
    table_.DrawSplitter:SetCurrentChannel(window.DrawList, column.DrawChannelCurrent)
end

function ImGui.TablePopColumnChannel()
    local g = GImGui
    local table_ = g.CurrentTable

    -- Optimization: avoid PopClipRect() + SetCurrentChannel()
    if band(table_.Flags, ImGuiTableFlags.NoClip) ~= 0 or (table_.CurrentColumn == -1) then -- Calling TreePop() after TableNextRow() is supported.
        return
    end
    local window = g.CurrentWindow
    local column = table_.Columns[table_.CurrentColumn]
    ImGui.SetWindowClipRectBeforeSetChannel(window, column.ClipRect)
    table_.DrawSplitter:SetCurrentChannel(window.DrawList, column.DrawChannelCurrent)
end

-- Allocate draw channels. Called by TableUpdateLayout()
function ImGui.TableSetupDrawChannels(table_)
    local freeze_row_multiplier = (table_.FreezeRowsCount > 0) and 2 or 1
    local channels_for_row = (band(table_.Flags, ImGuiTableFlags.NoClip) ~= 0) and 1 or table_.ColumnsEnabledCount
    local channels_for_bg = 1 + 1 * freeze_row_multiplier
    local masks_differ = false
    for n = 0, table_.ColumnsCount - 1 do
        if (table_.VisibleMaskByIndex[n] == true) ~= (table_.EnabledMaskByIndex[n] == true) then
            masks_differ = true
            break
        end
    end
    local channels_for_dummy = (table_.ColumnsEnabledCount < table_.ColumnsCount or masks_differ) and 1 or 0
    local channels_total = channels_for_bg + (channels_for_row * freeze_row_multiplier) + channels_for_dummy
    table_.DrawSplitter:Split(table_.InnerWindow.DrawList, channels_total)
    table_.DummyDrawChannel = (channels_for_dummy > 0) and (channels_total - 1) or -1
    table_.Bg2DrawChannelCurrent = TABLE_DRAW_CHANNEL_BG2_FROZEN
    table_.Bg2DrawChannelUnfrozen = (table_.FreezeRowsCount > 0) and (2 + channels_for_row) or TABLE_DRAW_CHANNEL_BG2_FROZEN

    local draw_channel_current = 2
    for column_n = 0, table_.ColumnsCount - 1 do
        local column = table_.Columns[column_n]
        if column.IsVisibleX and column.IsVisibleY then
            column.DrawChannelFrozen = draw_channel_current
            column.DrawChannelUnfrozen = draw_channel_current + ((table_.FreezeRowsCount > 0) and (channels_for_row + 1) or 0)
            if band(table_.Flags, ImGuiTableFlags.NoClip) == 0 then
                draw_channel_current = draw_channel_current + 1
            end
        else
            column.DrawChannelFrozen = table_.DummyDrawChannel
            column.DrawChannelUnfrozen = table_.DummyDrawChannel
        end
        column.DrawChannelCurrent = column.DrawChannelFrozen
    end

    -- Initial draw cmd starts with a BgClipRect that matches the one of its host, to facilitate merge draw commands by default.
    ImRect_Copy(table_.BgClipRect, table_.InnerClipRect)
    ImRect_Copy(table_.Bg0ClipRectForDrawCmd, table_.OuterWindow.ClipRect)
    ImRect_Copy(table_.Bg2ClipRectForDrawCmd, table_.HostClipRect)
    IM_ASSERT(table_.BgClipRect.Min.y <= table_.BgClipRect.Max.y)
end

-- This function reorder draw channels based on matching clip rectangle, to facilitate merging them. Called by EndTable().
-- (Lua: splitter channel n lives in splitter._Channels.Data[n + 1]; bit arrays are Lua sets)
function ImGui.TableMergeDrawChannels(table_)
    local splitter = table_.DrawSplitter
    local channels = splitter._Channels.Data
    local has_freeze_v = (table_.FreezeRowsCount > 0)
    local has_freeze_h = (table_.FreezeColumnsCount > 0)
    IM_ASSERT(splitter._Current == 0)

    -- Track which groups we are going to attempt to merge, and which channels goes into each group.
    local merge_group_mask = 0x00
    local merge_groups = {}
    for n = 0, 3 do
        merge_groups[n] = { ClipRect = ImRect(), ChannelsCount = 0, ChannelsMask = {} }
    end
    local max_draw_channels = (4 + table_.ColumnsCount * 2)
    local remaining_mask = {}

    -- 1. Scan channels and take note of those which can be merged
    for column_n = 0, table_.ColumnsCount - 1 do
        if BitTest(table_.VisibleMaskByIndex, column_n) then
            local column = table_.Columns[column_n]

            local merge_group_sub_count = has_freeze_v and 2 or 1
            for merge_group_sub_n = 0, merge_group_sub_count - 1 do
                repeat
                    local channel_no = (merge_group_sub_n == 0) and column.DrawChannelFrozen or column.DrawChannelUnfrozen

                    -- Don't attempt to merge if there are multiple draw calls within the column
                    local src_channel = channels[channel_no + 1]
                    local cmds = src_channel._CmdBuffer
                    if cmds.Size > 0 and cmds.Data[cmds.Size].ElemCount == 0 and cmds.Data[cmds.Size].UserCallback == nil then -- Equivalent of PopUnusedDrawCmd()
                        cmds:pop_back()
                    end
                    if cmds.Size ~= 1 then
                        break
                    end

                    -- Find out the width of this merge group and check if it will fit in our column
                    if band(column.Flags, ImGuiTableColumnFlags.NoClip) == 0 then
                        local content_max_x
                        if not has_freeze_v then
                            content_max_x = ImMax(column.ContentMaxXUnfrozen, column.ContentMaxXHeadersUsed) -- No row freeze
                        elseif merge_group_sub_n == 0 then
                            content_max_x = ImMax(column.ContentMaxXFrozen, column.ContentMaxXHeadersUsed)   -- Row freeze: use width before freeze
                        else
                            content_max_x = column.ContentMaxXUnfrozen                                        -- Row freeze: use width after freeze
                        end
                        if content_max_x > column.ClipRect.Max.x then
                            break
                        end
                    end

                    local merge_group_n = ((has_freeze_h and column_n < table_.FreezeColumnsCount) and 0 or 1) + ((has_freeze_v and merge_group_sub_n == 0) and 0 or 2)
                    IM_ASSERT(channel_no < max_draw_channels)
                    local merge_group = merge_groups[merge_group_n]
                    if merge_group.ChannelsCount == 0 then
                        merge_group.ClipRect = ImRect(FLT_MAX, FLT_MAX, -FLT_MAX, -FLT_MAX)
                    end
                    merge_group.ChannelsMask[channel_no] = true
                    merge_group.ChannelsCount = merge_group.ChannelsCount + 1
                    local cr = cmds.Data[1].ClipRect
                    merge_group.ClipRect:Add(ImRect(cr.x, cr.y, cr.z, cr.w))
                    merge_group_mask = bor(merge_group_mask, lshift(1, merge_group_n))
                until true
            end

            -- Invalidate current draw channel
            column.DrawChannelCurrent = -1
        end
    end

    -- 2. Rewrite channel list in our preferred order
    if merge_group_mask ~= 0 then
        -- We skip channel 0 (Bg0/Bg1) and 1 (Bg2 frozen) from the shuffling since they won't move - see channels allocation in TableSetupDrawChannels().
        local LEADING_DRAW_CHANNELS = 2
        local dst_tmp = {}
        for n = LEADING_DRAW_CHANNELS, splitter._Count - 1 do
            remaining_mask[n] = true
        end
        remaining_mask[table_.Bg2DrawChannelUnfrozen] = nil
        IM_ASSERT(has_freeze_v == false or table_.Bg2DrawChannelUnfrozen ~= TABLE_DRAW_CHANNEL_BG2_FROZEN)
        local remaining_count = splitter._Count - (has_freeze_v and (LEADING_DRAW_CHANNELS + 1) or LEADING_DRAW_CHANNELS)
        local host_rect = table_.HostClipRect
        for merge_group_n = 0, 3 do
            local merge_channels_count = merge_groups[merge_group_n].ChannelsCount
            if merge_channels_count ~= 0 then
                local merge_group = merge_groups[merge_group_n]
                local merge_clip_rect = Rect(merge_group.ClipRect)

                -- Extend outer-most clip limits to match those of host, so draw calls can be merged even if
                -- outer-most columns have some outer padding offsetting them from their parent ClipRect.
                if band(merge_group_n, 1) == 0 or not has_freeze_h then
                    merge_clip_rect.Min.x = ImMin(merge_clip_rect.Min.x, host_rect.Min.x)
                end
                if band(merge_group_n, 2) == 0 or not has_freeze_v then
                    merge_clip_rect.Min.y = ImMin(merge_clip_rect.Min.y, host_rect.Min.y)
                end
                if band(merge_group_n, 1) ~= 0 then
                    merge_clip_rect.Max.x = ImMax(merge_clip_rect.Max.x, host_rect.Max.x)
                end
                if band(merge_group_n, 2) ~= 0 and band(table_.Flags, ImGuiTableFlags.NoHostExtendY) == 0 then
                    merge_clip_rect.Max.y = ImMax(merge_clip_rect.Max.y, host_rect.Max.y)
                end
                remaining_count = remaining_count - merge_group.ChannelsCount
                for n in pairs(merge_group.ChannelsMask) do
                    remaining_mask[n] = nil
                end
                local n = 0
                while n < splitter._Count and merge_channels_count ~= 0 do
                    -- Copy + overwrite new clip rect
                    if merge_group.ChannelsMask[n] then
                        merge_group.ChannelsMask[n] = nil
                        merge_channels_count = merge_channels_count - 1

                        local channel = channels[n + 1]
                        IM_ASSERT(channel._CmdBuffer.Size == 1)
                        ImVec4_Copy(channel._CmdBuffer.Data[1].ClipRect, merge_clip_rect:ToVec4())
                        dst_tmp[#dst_tmp + 1] = channel
                    end
                    n = n + 1
                end
            end

            -- Make sure Bg2DrawChannelUnfrozen appears in the middle of our groups (whereas Bg0/Bg1 and Bg2 frozen are fixed to 0 and 1)
            if merge_group_n == 1 and has_freeze_v then
                dst_tmp[#dst_tmp + 1] = channels[table_.Bg2DrawChannelUnfrozen + 1]
            end
        end

        -- Append unmergeable channels that we didn't reorder at the end of the list
        local n = 0
        while n < splitter._Count and remaining_count ~= 0 do
            if remaining_mask[n] then
                dst_tmp[#dst_tmp + 1] = channels[n + 1]
                remaining_count = remaining_count - 1
            end
            n = n + 1
        end
        IM_ASSERT(#dst_tmp == splitter._Count - LEADING_DRAW_CHANNELS)
        for i = 1, #dst_tmp do
            channels[LEADING_DRAW_CHANNELS + i] = dst_tmp[i]
        end
    end
end

local function TableGetColumnBorderCol(table_, order_n, column_n)
    local is_hovered = (table_.HoveredColumnBorder == column_n)
    local is_resized = (table_.ResizedColumn == column_n) and (table_.InstanceInteracted == table_.InstanceCurrent)
    local is_frozen_separator = (table_.FreezeColumnsCount == order_n + 1)
    if is_resized or is_hovered then
        return ImGui.GetColorU32(is_resized and ImGuiCol.SeparatorActive or ImGuiCol.SeparatorHovered)
    end
    if is_frozen_separator or band(table_.Flags, bor(ImGuiTableFlags.NoBordersInBody, ImGuiTableFlags.NoBordersInBodyUntilResize)) ~= 0 then
        return table_.BorderColorStrong
    end
    return table_.BorderColorLight
end

-- FIXME-TABLE: This is a mess, need to redesign how we render borders (as some are also done in TableEndRow)
function ImGui.TableDrawBorders(table_)
    local inner_window = table_.InnerWindow
    if not table_.OuterWindow.ClipRect:Overlaps(table_.OuterRect) then
        return
    end

    local inner_drawlist = inner_window.DrawList
    table_.DrawSplitter:SetCurrentChannel(inner_drawlist, TABLE_DRAW_CHANNEL_BG0)
    inner_drawlist:PushClipRect(table_.Bg0ClipRectForDrawCmd.Min, table_.Bg0ClipRectForDrawCmd.Max, false)

    -- Draw inner border and resizing feedback
    local table_instance = ImGui.TableGetInstanceData(table_, table_.InstanceCurrent)
    local border_size = TABLE_BORDER_SIZE
    local draw_y1 = ImMax(table_.InnerRect.Min.y, ((table_.FreezeRowsCount >= 1) and table_.InnerRect.Min.y or table_.WorkRect.Min.y) + table_.AngledHeadersHeight) + ((band(table_.Flags, ImGuiTableFlags.BordersOuterH) ~= 0) and border_size or 0.0)
    local draw_y2_body = table_.InnerRect.Max.y
    local draw_y2_head = table_.IsUsingHeaders and ImMin(table_.InnerRect.Max.y, ((table_.FreezeRowsCount >= 1) and table_.InnerRect.Min.y or table_.WorkRect.Min.y) + table_instance.LastTopHeadersRowHeight) or draw_y1
    if band(table_.Flags, ImGuiTableFlags.BordersInnerV) ~= 0 then
        for order_n = 0, table_.ColumnsCount - 1 do
            repeat
                if not BitTest(table_.EnabledMaskByDisplayOrder, order_n) then
                    break
                end

                local column_n = table_.DisplayOrderToIndex[order_n]
                local column = table_.Columns[column_n]
                local is_hovered = (table_.HoveredColumnBorder == column_n)
                local is_resized = (table_.ResizedColumn == column_n) and (table_.InstanceInteracted == table_.InstanceCurrent)
                local is_resizable = band(column.Flags, bor(ImGuiTableColumnFlags.NoResize, ImGuiTableColumnFlags.NoDirectResize_)) == 0
                local is_frozen_separator = (table_.FreezeColumnsCount == order_n + 1)
                if column.MaxX > table_.InnerClipRect.Max.x and not is_resized then
                    break
                end

                -- Decide whether right-most column is visible
                if column.NextEnabledColumn == -1 and not is_resizable then
                    if band(table_.Flags, ImGuiTableFlags.SizingMask_) ~= ImGuiTableFlags.SizingFixedSame or band(table_.Flags, ImGuiTableFlags.NoHostExtendX) ~= 0 then
                        break
                    end
                end
                if column.MaxX <= column.ClipRect.Min.x then -- FIXME-TABLE FIXME-STYLE: Assume BorderSize==1, this is problematic if we want to increase the border size..
                    break
                end

                -- Draw in outer window so right-most column won't be clipped
                local draw_y2 = draw_y2_head
                if is_frozen_separator then
                    draw_y2 = draw_y2_body
                elseif band(table_.Flags, ImGuiTableFlags.NoBordersInBodyUntilResize) ~= 0 and (is_hovered or is_resized) then
                    draw_y2 = draw_y2_body
                elseif band(table_.Flags, bor(ImGuiTableFlags.NoBordersInBodyUntilResize, ImGuiTableFlags.NoBordersInBody)) == 0 then
                    draw_y2 = draw_y2_body
                end
                if draw_y2 > draw_y1 then
                    inner_drawlist:AddLineV(column.MaxX, draw_y1, draw_y2, TableGetColumnBorderCol(table_, order_n, column_n), border_size)
                end
            until true
        end
    end

    -- Draw outer border
    if band(table_.Flags, ImGuiTableFlags.BordersOuter) ~= 0 then
        local outer_border = table_.OuterRect
        local outer_col = table_.BorderColorStrong
        if band(table_.Flags, ImGuiTableFlags.BordersOuter) == ImGuiTableFlags.BordersOuter then
            inner_drawlist:AddRect(outer_border.Min, outer_border.Max, outer_col, 0.0, border_size)
        elseif band(table_.Flags, ImGuiTableFlags.BordersOuterV) ~= 0 then
            inner_drawlist:AddLineV(outer_border.Min.x, outer_border.Min.y, outer_border.Max.y, outer_col, border_size)
            inner_drawlist:AddLineV(outer_border.Max.x - border_size, outer_border.Min.y, outer_border.Max.y, outer_col, border_size)
        elseif band(table_.Flags, ImGuiTableFlags.BordersOuterH) ~= 0 then
            inner_drawlist:AddLineH(outer_border.Min.x, outer_border.Max.x, outer_border.Min.y, outer_col, border_size)
            inner_drawlist:AddLineH(outer_border.Min.x, outer_border.Max.x, outer_border.Max.y - border_size, outer_col, border_size)
        end
    end
    if band(table_.Flags, ImGuiTableFlags.BordersInnerH) ~= 0 and table_.RowPosY2 < table_.OuterRect.Max.y then
        -- Draw bottom-most row border between it is above outer border.
        local h_inset = (band(table_.Flags, ImGuiTableFlags.BordersOuterV) ~= 0) and border_size or 0.0
        local border_y = table_.RowPosY2
        if border_y >= table_.BgClipRect.Min.y and border_y < table_.BgClipRect.Max.y then
            inner_drawlist:AddLineH(table_.BorderX1 + h_inset, table_.BorderX2 - h_inset, border_y, table_.BorderColorLight, border_size)
        end
    end

    inner_drawlist:PopClipRect()
end

----------------------------------------------------------------
-- [SECTION] Tables: Sorting
----------------------------------------------------------------

-- Return nil if no sort specs (most often when ImGuiTableFlags_Sortable is not set)
-- When 'sort_specs.SpecsDirty == true' you should sort your data. Specs is a 1-based Lua array.
function ImGui.TableGetSortSpecs()
    local g = GImGui
    local table_ = g.CurrentTable
    if table_ == nil or band(table_.Flags, ImGuiTableFlags.Sortable) == 0 then
        return nil
    end

    -- Require layout (in case TableHeadersRow() hasn't been called) as it may alter IsSortSpecsDirty in some paths.
    if not table_.IsLayoutLocked then
        ImGui.TableUpdateLayout(table_)
    end

    ImGui.TableSortSpecsBuild(table_)
    return table_.SortSpecs
end

local function TableGetColumnAvailSortDirection(column, n)
    IM_ASSERT(n < column.SortDirectionsAvailCount)
    return band(rshift(column.SortDirectionsAvailList, lshift(n, 1)), 0x03)
end

-- Fix sort direction if currently set on a value which is unavailable (e.g. activating NoSortAscending/NoSortDescending)
function ImGui.TableFixColumnSortDirection(table_, column)
    if column.SortOrder == -1 or band(column.SortDirectionsAvailMask, lshift(1, column.SortDirection)) ~= 0 then
        return
    end
    column.SortDirection = TableGetColumnAvailSortDirection(column, 0)
    table_.IsSortSpecsDirty = true
end

-- Calculate next sort direction that would be set after clicking the column
function ImGui.TableGetColumnNextSortDirection(column)
    IM_ASSERT(column.SortDirectionsAvailCount > 0)
    if column.SortOrder == -1 then
        return TableGetColumnAvailSortDirection(column, 0)
    end
    for n = 0, 2 do
        if column.SortDirection == TableGetColumnAvailSortDirection(column, n) then
            return TableGetColumnAvailSortDirection(column, (n + 1) % column.SortDirectionsAvailCount)
        end
    end
    IM_ASSERT(false)
    return ImGuiSortDirection.None
end

-- Note that the NoSortAscending/NoSortDescending flags are processed in TableSortSpecsSanitize(), and they may change/revert
-- the value of SortDirection. We could technically also do it here but it would be unnecessary and duplicate code.
function ImGui.TableSetColumnSortDirection(column_n, sort_direction, append_to_sort_specs)
    local g = GImGui
    local table_ = g.CurrentTable

    if band(table_.Flags, ImGuiTableFlags.SortMulti) == 0 then
        append_to_sort_specs = false
    end
    if band(table_.Flags, ImGuiTableFlags.SortTristate) == 0 then
        IM_ASSERT(sort_direction ~= ImGuiSortDirection.None)
    end

    local sort_order_max = 0
    if append_to_sort_specs then
        for other_column_n = 0, table_.ColumnsCount - 1 do
            sort_order_max = ImMax(sort_order_max, table_.Columns[other_column_n].SortOrder)
        end
    end

    local column = table_.Columns[column_n]
    column.SortDirection = sort_direction
    if column.SortDirection == ImGuiSortDirection.None then
        column.SortOrder = -1
    elseif column.SortOrder == -1 or not append_to_sort_specs then
        column.SortOrder = append_to_sort_specs and (sort_order_max + 1) or 0
    end

    for other_column_n = 0, table_.ColumnsCount - 1 do
        local other_column = table_.Columns[other_column_n]
        if other_column ~= column and not append_to_sort_specs then
            other_column.SortOrder = -1
        end
        ImGui.TableFixColumnSortDirection(table_, other_column)
    end
    table_.IsSettingsDirty = true
    table_.IsSortSpecsDirty = true
end

function ImGui.TableSortSpecsSanitize(table_)
    IM_ASSERT(band(table_.Flags, ImGuiTableFlags.Sortable) ~= 0)

    -- Clear SortOrder from hidden column and verify that there's no gap or duplicate.
    local sort_order_count = 0
    local sort_order_set = {} -- C++: ImU64 sort_order_mask
    local sort_order_dup = false
    for column_n = 0, table_.ColumnsCount - 1 do
        local column = table_.Columns[column_n]
        if column.SortOrder ~= -1 and not column.IsEnabled then
            column.SortOrder = -1
        end
        if column.SortOrder ~= -1 then
            sort_order_count = sort_order_count + 1
            if sort_order_set[column.SortOrder] then sort_order_dup = true end
            sort_order_set[column.SortOrder] = true
            IM_ASSERT(sort_order_count < 64)
        end
    end

    -- need_fix_linearize: (1 << count) != (mask + 1) <=> the set of sort orders isn't exactly {0..count-1}
    local need_fix_linearize = sort_order_dup
    for n = 0, sort_order_count - 1 do
        if not sort_order_set[n] then need_fix_linearize = true end
    end
    local need_fix_single_sort_order = (sort_order_count > 1) and band(table_.Flags, ImGuiTableFlags.SortMulti) == 0
    if need_fix_linearize or need_fix_single_sort_order then
        local fixed_mask = {}
        for sort_n = 0, sort_order_count - 1 do
            -- Fix: Rewrite sort order fields if needed so they have no gap or duplicate.
            local column_with_smallest_sort_order = -1
            for column_n = 0, table_.ColumnsCount - 1 do
                if not fixed_mask[column_n] and table_.Columns[column_n].SortOrder ~= -1 then
                    if column_with_smallest_sort_order == -1 or table_.Columns[column_n].SortOrder < table_.Columns[column_with_smallest_sort_order].SortOrder then
                        column_with_smallest_sort_order = column_n
                    end
                end
            end
            IM_ASSERT(column_with_smallest_sort_order ~= -1)
            fixed_mask[column_with_smallest_sort_order] = true
            table_.Columns[column_with_smallest_sort_order].SortOrder = sort_n

            -- Fix: Make sure only one column has a SortOrder if ImGuiTableFlags_MultiSortable is not set.
            if need_fix_single_sort_order then
                sort_order_count = 1
                for column_n = 0, table_.ColumnsCount - 1 do
                    if column_n ~= column_with_smallest_sort_order then
                        table_.Columns[column_n].SortOrder = -1
                    end
                end
                break
            end
        end
    end

    -- Fallback default sort order (if no column with the ImGuiTableColumnFlags_DefaultSort flag)
    if sort_order_count == 0 and band(table_.Flags, ImGuiTableFlags.SortTristate) == 0 then
        for column_n = 0, table_.ColumnsCount - 1 do
            local column = table_.Columns[column_n]
            if column.IsEnabled and band(column.Flags, ImGuiTableColumnFlags.NoSort) == 0 then
                sort_order_count = 1
                column.SortOrder = 0
                column.SortDirection = TableGetColumnAvailSortDirection(column, 0)
                break
            end
        end
    end

    table_.SortSpecsCount = sort_order_count
end

function ImGui.TableSortSpecsBuild(table_)
    local dirty = table_.IsSortSpecsDirty
    if dirty then
        ImGui.TableSortSpecsSanitize(table_)
        local multi = table_.SortSpecsMulti
        local want = (table_.SortSpecsCount <= 1) and 0 or table_.SortSpecsCount
        for n = #multi + 1, want do multi[n] = ImGuiTableColumnSortSpecs() end
        for n = #multi, want + 1, -1 do multi[n] = nil end
        table_.SortSpecs.SpecsDirty = true -- Mark as dirty for user
        table_.IsSortSpecsDirty = false -- Mark as not dirty for us
    end

    -- Write output
    local sort_specs
    if table_.SortSpecsCount == 0 then
        sort_specs = nil
    elseif table_.SortSpecsCount == 1 then
        table_.SortSpecsSingleArray = table_.SortSpecsSingleArray or { table_.SortSpecsSingle }
        sort_specs = table_.SortSpecsSingleArray
    else
        sort_specs = table_.SortSpecsMulti
    end
    if dirty and sort_specs ~= nil then
        for column_n = 0, table_.ColumnsCount - 1 do
            local column = table_.Columns[column_n]
            if column.SortOrder ~= -1 then
                IM_ASSERT(column.SortOrder < table_.SortSpecsCount)
                local sort_spec = sort_specs[column.SortOrder + 1]
                sort_spec.ColumnUserID = column.UserData
                sort_spec.ColumnIndex = column_n
                sort_spec.SortOrder = column.SortOrder
                sort_spec.SortDirection = column.SortDirection
            end
        end
    end

    table_.SortSpecs.Specs = sort_specs
    table_.SortSpecs.SpecsCount = table_.SortSpecsCount
end

----------------------------------------------------------------
-- [SECTION] Tables: Headers
----------------------------------------------------------------

function ImGui.TableGetHeaderRowHeight()
    -- Calculate row height, for the unlikely case that some labels may be taller than others.
    local g = GImGui
    local table_ = g.CurrentTable
    local row_height = g.FontSize
    for column_n = 0, table_.ColumnsCount - 1 do
        if BitTest(table_.EnabledMaskByIndex, column_n) then
            if band(table_.Columns[column_n].Flags, ImGuiTableColumnFlags.NoHeaderLabel) == 0 then
                row_height = ImMax(row_height, ImGui.CalcTextSize(ImGui.TableGetColumnName(table_, column_n)).y)
            end
        end
    end
    return row_height + g.Style.CellPadding.y * 2.0
end

function ImGui.TableGetHeaderAngledMaxLabelWidth()
    local g = GImGui
    local table_ = g.CurrentTable
    local width = 0.0
    for column_n = 0, table_.ColumnsCount - 1 do
        if BitTest(table_.EnabledMaskByIndex, column_n) then
            if band(table_.Columns[column_n].Flags, ImGuiTableColumnFlags.AngledHeader) ~= 0 then
                width = ImMax(width, ImGui.CalcTextSize(ImGui.TableGetColumnName(table_, column_n), nil, true).x)
            end
        end
    end
    return width + g.Style.CellPadding.y * 2.0 -- Swap padding
end

-- [Public] This is a helper to output TableHeader() calls based on the column names declared in TableSetupColumn().
function ImGui.TableHeadersRow()
    local g = GImGui
    local table_ = g.CurrentTable
    IM_ASSERT_USER_ERROR_RET(table_ ~= nil, "Call should only be done while in BeginTable() scope!")

    -- Call layout if not already done. This is automatically done by TableNextRow: we do it here _only_ to make
    -- it easier to debug-step in TableUpdateLayout(). Your own version of this function doesn't need this.
    if not table_.IsLayoutLocked then
        ImGui.TableUpdateLayout(table_)
    end

    -- Open row
    local row_height = ImGui.TableGetHeaderRowHeight()
    ImGui.TableNextRow(ImGuiTableRowFlags.Headers, row_height)
    local row_y1 = ImGui.GetCursorScreenPos().y
    if table_.HostSkipItems then -- Merely an optimization, you may skip in your own code.
        return
    end

    local columns_count = ImGui.TableGetColumnCount()
    for column_n = 0, columns_count - 1 do
        if ImGui.TableSetColumnIndex(column_n) or table_.LastHeldHeaderColumn == column_n then
            -- Push an id to allow empty/unnamed headers. This is also idiomatic as it ensure there is a consistent ID path to access columns (for e.g. automation)
            local name = (band(ImGui.TableGetColumnFlags(column_n), ImGuiTableColumnFlags.NoHeaderLabel) ~= 0) and "" or ImGui.TableGetColumnName(column_n)
            ImGui.PushID(column_n)
            ImGui.TableHeader(name)
            ImGui.PopID()
        end
    end

    -- Allow opening popup from the right-most section after the last column.
    local mouse_pos = ImGui.GetMousePos()
    if ImGui.IsMouseReleased(1) and ImGui.TableGetHoveredColumn() == columns_count then
        if mouse_pos.y >= row_y1 and mouse_pos.y < row_y1 + row_height then
            ImGui.TableOpenContextMenu(columns_count) -- Will open a non-column-specific popup.
        end
    end
end

-- Emit a column header (text + optional sort order)
-- We cpu-clip text here so that all columns headers can be merged into a same draw call.
function ImGui.TableHeader(label)
    local g = GImGui
    local window = g.CurrentWindow
    if window.SkipItems then
        return
    end

    local table_ = g.CurrentTable
    IM_ASSERT_USER_ERROR_RET(table_ ~= nil, "Call should only be done while in BeginTable() scope!")
    IM_ASSERT(table_.CurrentColumn ~= -1)
    local column_n = table_.CurrentColumn
    local column = table_.Columns[column_n]

    -- Label
    if label == nil then
        label = ""
    end
    local label_end = ImGui.FindRenderedTextEnd(label)
    local label_size = ImGui.CalcTextSize(label, label_end, false)
    local label_pos = V2(window.DC.CursorPos)

    -- If we already got a row height, there's use that.
    local cell_r = ImGui.TableGetCellBgRect(table_, column_n)
    local label_height = ImMax(label_size.y, table_.RowMinHeight - table_.RowCellPaddingY * 2.0)

    -- Calculate ideal size for sort order arrow
    local w_arrow = 0.0
    local w_sort_text = 0.0
    local sort_arrow = false
    local sort_order_suf = ""
    local ARROW_SCALE = 0.65
    if band(table_.Flags, ImGuiTableFlags.Sortable) ~= 0 and band(column.Flags, ImGuiTableColumnFlags.NoSort) == 0 then
        w_arrow = ImTrunc(g.FontSize * ARROW_SCALE + g.Style.FramePadding.x)
        if column.SortOrder ~= -1 then
            sort_arrow = true
        end
        if column.SortOrder > 0 then
            sort_order_suf = string.format("%d", column.SortOrder + 1)
            w_sort_text = g.Style.ItemInnerSpacing.x + ImGui.CalcTextSize(sort_order_suf).x
        end
    end

    -- We feed our unclipped width to the column without writing on CursorMaxPos, so that column is still considered for merging.
    local max_pos_x = label_pos.x + label_size.x + w_sort_text + w_arrow
    column.ContentMaxXHeadersUsed = ImMax(column.ContentMaxXHeadersUsed, sort_arrow and cell_r.Max.x or ImMin(max_pos_x, cell_r.Max.x))
    column.ContentMaxXHeadersIdeal = ImMax(column.ContentMaxXHeadersIdeal, max_pos_x)

    -- Keep header highlighted when context menu is open.
    local id = window:GetID(label)
    local bb = ImRect(cell_r.Min.x, cell_r.Min.y, cell_r.Max.x, ImMax(cell_r.Max.y, cell_r.Min.y + label_height + g.Style.CellPadding.y * 2.0))
    ImGui.ItemSize(ImVec2(0.0, label_height)) -- Don't declare unclipped width, it'll be fed ContentMaxPosHeadersIdeal
    if not ImGui.ItemAdd(bb, id) then
        return
    end

    -- Using AllowOverlap mode because we cover the whole cell, and we want user to be able to submit subsequent items.
    local highlight = (table_.HighlightColumnHeader == column_n)
    local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, ImGuiButtonFlags.AllowOverlap)
    if held or hovered or highlight then
        local col = ImGui.GetColorU32(held and ImGuiCol.HeaderActive or (hovered and ImGuiCol.HeaderHovered or ImGuiCol.Header))
        ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, col, table_.CurrentColumn)
    else
        -- Submit single cell bg color in the case we didn't submit a full header row
        if band(table_.RowFlags, ImGuiTableRowFlags.Headers) == 0 then
            ImGui.TableSetBgColor(ImGuiTableBgTarget.CellBg, ImGui.GetColorU32(ImGuiCol.TableHeaderBg), table_.CurrentColumn)
        end
    end
    ImGui.RenderNavCursor(bb, id, ImGuiNavRenderCursorFlags.Compact, 0.0)
    if held then
        table_.HeldHeaderColumn = column_n
    end
    window.DC.CursorPos.y = window.DC.CursorPos.y - g.Style.ItemSpacing.y * 0.5

    -- Drag and drop to re-order columns.
    if held and band(table_.Flags, ImGuiTableFlags.Reorderable) ~= 0 and ImGui.IsMouseDragging(0) and not g.DragDropActive then
        table_.InstanceInteracted = table_.InstanceCurrent
        if g.IO.MouseDelta.x < 0.0 and g.IO.MousePos.x < cell_r.Min.x then
            local prev_column = (column.PrevEnabledColumn ~= -1) and table_.Columns[column.PrevEnabledColumn] or nil
            if prev_column then
                ImGui.TableQueueSetColumnDisplayOrder(table_, column_n, prev_column.DisplayOrder)
            end
        end
        if g.IO.MouseDelta.x > 0.0 and g.IO.MousePos.x > cell_r.Max.x then
            local next_column = (column.NextEnabledColumn ~= -1) and table_.Columns[column.NextEnabledColumn] or nil
            if next_column then
                ImGui.TableQueueSetColumnDisplayOrder(table_, column_n, next_column.DisplayOrder)
            end
        end
    end

    -- Sort order arrow
    local ellipsis_max = ImMax(cell_r.Max.x - (sort_arrow and (w_arrow + w_sort_text) or 0.0), label_pos.x)
    if band(table_.Flags, ImGuiTableFlags.Sortable) ~= 0 and band(column.Flags, ImGuiTableColumnFlags.NoSort) == 0 then
        if column.SortOrder ~= -1 then
            local x = ImMax(cell_r.Min.x, cell_r.Max.x - w_arrow - w_sort_text)
            local y = label_pos.y
            if column.SortOrder > 0 then
                ImGui.PushStyleColor(ImGuiCol.Text, ImGui.GetColorU32(ImGuiCol.Text, 0.70))
                ImGui.RenderText(ImVec2(x + g.Style.ItemInnerSpacing.x, y), sort_order_suf)
                ImGui.PopStyleColor()
                x = x + w_sort_text
            end
            ImGui.RenderArrow(window.DrawList, ImVec2(x, y), ImGui.GetColorU32(ImGuiCol.Text), (column.SortDirection == ImGuiSortDirection.Ascending) and ImGuiDir.Up or ImGuiDir.Down, ARROW_SCALE)
        end

        -- Handle clicking on column header to adjust Sort Order
        if pressed and table_.ReorderColumn ~= column_n then
            local sort_direction = ImGui.TableGetColumnNextSortDirection(column)
            ImGui.TableSetColumnSortDirection(column_n, sort_direction, g.IO.KeyShift)
        end
    end

    -- Render clipped label. Clipping here ensure that in the majority of situations, all our header cells will
    -- be merged into a single draw call.
    ImGui.RenderTextEllipsis(window.DrawList, label_pos, ImVec2(ellipsis_max, bb.Max.y), ellipsis_max, label, label_end, label_size)

    local text_clipped = label_size.x > (ellipsis_max - label_pos.x)
    if text_clipped and hovered and g.ActiveId == 0 then
        ImGui.SetItemTooltip("%s", string.sub(label, 1, label_end - 1))
    end

    -- We don't use BeginPopupContextItem() because we want the popup to stay up even after the column is hidden
    if ImGui.IsPopupOpenRequestForItem(ImGuiPopupFlags.None, id) then
        ImGui.TableOpenContextMenu(column_n)
    end
end

-- Unlike TableHeadersRow() it is not expected that you can reimplement or customize this with custom widgets.
function ImGui.TableAngledHeadersRow()
    local g = GImGui
    local table_ = g.CurrentTable
    local temp_data = table_.TempData
    temp_data.AngledHeadersRequests:resize(0)

    -- Which column needs highlight?
    local row_id = ImGui.GetID("##AngledHeaders")
    local table_instance = ImGui.TableGetInstanceData(table_, table_.InstanceCurrent)
    local highlight_column_n = (table_.LastHeldHeaderColumn ~= -1) and table_.LastHeldHeaderColumn or table_.HighlightColumnHeader
    if highlight_column_n == -1 and table_.HoveredColumnBody ~= -1 then
        if table_instance.HoveredRowLast == 0 and table_.HoveredColumnBorder == -1 and (g.ActiveId == 0 or g.ActiveId == row_id or (table_.IsActiveIdInTable or g.DragDropActive)) then
            highlight_column_n = table_.HoveredColumnBody
        end
    end

    -- Build up request
    local col_header_bg = ImGui.GetColorU32(ImGuiCol.TableHeaderBg)
    local col_text = ImGui.GetColorU32(ImGuiCol.Text)
    for order_n = 0, table_.ColumnsCount - 1 do
        if BitTest(table_.EnabledMaskByDisplayOrder, order_n) then
            local column_n = table_.DisplayOrderToIndex[order_n]
            local column = table_.Columns[column_n]
            if band(column.Flags, ImGuiTableColumnFlags.AngledHeader) ~= 0 then -- Note: can't rely on ImGuiTableColumnFlags_IsVisible test here.
                temp_data.AngledHeadersRequests:push_back({ Index = column_n, TextColor = col_text, BgColor0 = col_header_bg, BgColor1 = (column_n == highlight_column_n) and ImGui.GetColorU32(ImGuiCol.Header) or 0 })
            end
        end
    end

    -- Render row
    ImGui.TableAngledHeadersRowEx(row_id, g.Style.TableAngledHeadersAngle, 0.0, temp_data.AngledHeadersRequests.Data, temp_data.AngledHeadersRequests.Size)
end

local function ImTextCountLines(text, text_begin, text_end)
    local count = 0
    local p = text_begin
    while p < text_end do
        local line_end = string.find(text, "\n", p, true)
        if line_end == nil or line_end >= text_end then p = text_end else p = line_end + 1 end
        count = count + 1
    end
    return count
end

-- Important: data must be fed left to right
--- @param data       ImGuiTableHeaderData[] # 1-based array
--- @param data_count int
function ImGui.TableAngledHeadersRowEx(row_id, angle, max_label_width, data, data_count)
    local g = GImGui
    local table_ = g.CurrentTable
    local window = g.CurrentWindow
    local draw_list = window.DrawList
    IM_ASSERT_USER_ERROR_RET(table_ ~= nil, "Call should only be done while in BeginTable() scope!")
    IM_ASSERT(table_.CurrentRow == -1, "Must be first row")

    if max_label_width == 0.0 then
        max_label_width = ImGui.TableGetHeaderAngledMaxLabelWidth()
    end

    -- Angle argument expressed in (-IM_PI/2 .. +IM_PI/2) as it is easier to think about for user.
    local flip_label = (angle < 0.0)
    angle = angle - IM_PI * 0.5
    local cos_a = ImCos(angle)
    local sin_a = ImSin(angle)
    local label_cos_a = flip_label and ImCos(angle + IM_PI) or cos_a
    local label_sin_a = flip_label and ImSin(angle + IM_PI) or sin_a
    local unit_right = ImVec2(cos_a, sin_a)

    -- Calculate our base metrics and set angled headers data _before_ the first call to TableNextRow()
    local header_height = g.FontSize + g.Style.CellPadding.x * 2.0
    local row_height = ImTrunc(ImAbs(ImRotate(ImVec2(max_label_width, flip_label and header_height or -header_height), cos_a, sin_a).y))
    table_.AngledHeadersHeight = row_height
    table_.AngledHeadersSlope = (sin_a ~= 0.0) and (cos_a / sin_a) or 0.0
    local header_angled_vector = unit_right * (row_height / -sin_a) -- vector from bottom-left to top-left, and from bottom-right to top-right

    -- Declare row, override and draw our own background
    ImGui.TableNextRow(ImGuiTableRowFlags.Headers, row_height)
    ImGui.TableNextColumn()
    local row_r = ImRect(table_.WorkRect.Min.x, table_.BgClipRect.Min.y, table_.WorkRect.Max.x, table_.RowPosY2)
    table_.DrawSplitter:SetCurrentChannel(draw_list, TABLE_DRAW_CHANNEL_BG0)
    local clip_rect_min_x = table_.BgClipRect.Min.x
    if table_.FreezeColumnsCount > 0 then
        clip_rect_min_x = ImMax(clip_rect_min_x, table_.Columns[table_.DisplayOrderToIndex[table_.FreezeColumnsCount - 1]].MaxX)
    end
    ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0, 0) -- Cancel
    ImGui.PushClipRect(table_.BgClipRect.Min, table_.BgClipRect.Max, false) -- Span all columns
    draw_list:AddRectFilled(ImVec2(table_.BgClipRect.Min.x, row_r.Min.y), ImVec2(table_.BgClipRect.Max.x, row_r.Max.y), ImGui.GetColorU32(ImGuiCol.TableHeaderBg, 0.25)) -- FIXME-STYLE: Change row background with an arbitrary color.
    ImGui.PushClipRect(ImVec2(clip_rect_min_x, table_.BgClipRect.Min.y), table_.BgClipRect.Max, true) -- Span all columns

    ImGui.ButtonBehavior(row_r, row_id)
    ImGui.KeepAliveID(row_id)

    local ascent_scaled = g.FontBaked.Ascent * g.FontBakedScale -- FIXME: Standardize those scaling factors better
    local line_off_for_ascent_x = (ImMax((g.FontSize - ascent_scaled) * 0.5, 0.0) / -sin_a) * (flip_label and -1.0 or 1.0)
    local padding = g.Style.CellPadding -- We will always use swapped component
    local align = g.Style.TableAngledHeadersTextAlign

    -- Draw background and labels in first pass, then all borders.
    local max_x = -FLT_MAX
    for pass = 0, 1 do
        for order_n = 0, data_count - 1 do
            local request = data[order_n + 1]
            local column_n = request.Index
            local column = table_.Columns[column_n]

            local bg_shape = {}
            bg_shape[0] = ImVec2(column.MaxX, row_r.Max.y)
            bg_shape[1] = ImVec2(column.MinX, row_r.Max.y)
            bg_shape[2] = bg_shape[1] + header_angled_vector
            bg_shape[3] = bg_shape[0] + header_angled_vector
            if pass == 0 then
                -- Draw shape
                draw_list:AddQuadFilled(bg_shape[0], bg_shape[1], bg_shape[2], bg_shape[3], request.BgColor0)
                draw_list:AddQuadFilled(bg_shape[0], bg_shape[1], bg_shape[2], bg_shape[3], request.BgColor1) -- Optional highlight
                max_x = ImMax(max_x, bg_shape[3].x)

                -- Draw label
                local label_name = ImGui.TableGetColumnName(table_, column_n)
                local label_name_end = ImGui.FindRenderedTextEnd(label_name)
                local line_off_step_x = (g.FontSize / -sin_a)
                local label_lines = ImTextCountLines(label_name, 1, label_name_end)

                -- Left<>Right alignment
                local line_off_curr_x = flip_label and ((label_lines - 1) * line_off_step_x) or 0.0
                local line_off_for_align_x = ImFloor(ImMax((((column.MaxX - column.MinX) - padding.x * 2.0) - (label_lines * line_off_step_x)), 0.0) * align.x)
                line_off_curr_x = line_off_curr_x + line_off_for_align_x - line_off_for_ascent_x

                -- Register header width
                local w = column.WorkMinX + ImCeil(label_lines * line_off_step_x - line_off_for_align_x)
                column.ContentMaxXHeadersUsed = w; column.ContentMaxXHeadersIdeal = w

                local p = 1
                while p < label_name_end do
                    local label_name_eol = string.find(label_name, "\n", p, true)
                    if label_name_eol == nil or label_name_eol > label_name_end then
                        label_name_eol = label_name_end
                    end
                    local line = string.sub(label_name, p, label_name_eol - 1)

                    -- FIXME: Individual line clipping for right-most column is broken for negative angles.
                    local label_size = ImGui.CalcTextSize(line)
                    local clip_width = max_label_width - padding.y -- Using padding.y*2.0f would be symmetrical but hide more text.
                    local clip_height = ImMin(label_size.y, column.ClipRect.Max.x - column.WorkMinX - line_off_curr_x)
                    local clip_r = ImRect(window.ClipRect.Min, window.ClipRect.Min + ImVec2(clip_width, clip_height))
                    local vtx_idx_begin = draw_list._VtxCurrentIdx
                    ImGui.PushStyleColor(ImGuiCol.Text, request.TextColor)
                    ImGui.RenderTextEllipsis(draw_list, clip_r.Min, clip_r.Max, clip_r.Max.x, line, #line + 1, label_size)
                    ImGui.PopStyleColor()
                    local vtx_idx_end = draw_list._VtxCurrentIdx

                    -- Up<>Down alignment
                    local available_space = ImMax(clip_width - label_size.x + ImAbs(padding.x * cos_a) * 2.0 - ImAbs(padding.y * sin_a) * 2.0, 0.0)
                    local vertical_offset = available_space * align.y * (flip_label and -1.0 or 1.0)

                    -- Rotate and offset label
                    local pivot_in = ImVec2(window.ClipRect.Min.x - vertical_offset, window.ClipRect.Min.y + label_size.y)
                    local pivot_out = ImVec2(column.WorkMinX, row_r.Max.y)
                    line_off_curr_x = line_off_curr_x + (flip_label and -line_off_step_x or line_off_step_x)
                    pivot_out = pivot_out + unit_right * padding.y
                    if flip_label then
                        pivot_out = pivot_out + unit_right * (clip_width - ImMax(0.0, clip_width - label_size.x))
                    end
                    pivot_out.x = pivot_out.x + (flip_label and (line_off_curr_x + line_off_step_x) or line_off_curr_x)
                    ImGui.ShadeVertsTransformPos(draw_list, vtx_idx_begin, vtx_idx_end, pivot_in, label_cos_a, label_sin_a, pivot_out) -- Rotate and offset

                    p = label_name_eol + 1
                end
            end
            if pass == 1 then
                -- Draw border
                local border_size = TABLE_BORDER_SIZE
                draw_list:AddLine(bg_shape[0] + ImVec2(border_size * 0.5, 0.0), bg_shape[3] + ImVec2(border_size * 0.5, 0.0), TableGetColumnBorderCol(table_, order_n, column_n), border_size)
            end
        end
    end
    ImGui.PopClipRect()
    ImGui.PopClipRect()
    table_.TempData.AngledHeadersExtraWidth = ImMax(0.0, max_x - table_.Columns[table_.RightMostEnabledColumn].MaxX)
end

----------------------------------------------------------------
-- [SECTION] Tables: Context Menu
----------------------------------------------------------------

-- Use -1 to open menu not specific to a given column.
function ImGui.TableOpenContextMenu(column_n)
    if column_n == nil then column_n = -1 end
    local g = GImGui
    local table_ = g.CurrentTable
    if column_n == -1 and table_.CurrentColumn ~= -1 then -- When called within a column automatically use this one (for consistency)
        column_n = table_.CurrentColumn
    end
    if column_n == table_.ColumnsCount then -- To facilitate using with TableGetHoveredColumn()
        column_n = -1
    end
    IM_ASSERT(column_n >= -1 and column_n < table_.ColumnsCount)
    if band(table_.Flags, bor(ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable)) ~= 0 then
        table_.IsContextPopupOpen = true
        table_.ContextPopupColumn = column_n
        table_.InstanceInteracted = table_.InstanceCurrent
        local context_menu_id = ImHashStr("##ContextMenu", nil, table_.ID)
        ImGui.OpenPopupEx(context_menu_id, ImGuiPopupFlags.None)
    end
end

function ImGui.TableBeginContextMenuPopup(table_)
    if not table_.IsContextPopupOpen or table_.InstanceCurrent ~= table_.InstanceInteracted then
        return false
    end
    local context_menu_id = ImHashStr("##ContextMenu", nil, table_.ID)
    if ImGui.BeginPopupEx(context_menu_id, bor(ImGuiWindowFlags.AlwaysAutoResize, ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoSavedSettings)) then
        return true
    end
    table_.IsContextPopupOpen = false
    return false
end

-- FIXME: Copied from MenuItem() for the purpose of being able to pass _SelectOnRelease (#9312)
local function MenuItemForColumnReorder(label, selected, enabled)
    local g = GImGui
    local window = g.CurrentWindow

    local label_size = ImGui.CalcTextSize(label, nil, true)
    local offsets = window.DC.MenuColumns
    local checkmark_w = IM_TRUNC(g.FontSize * 1.20)
    local min_w = offsets:DeclColumns(0.0, label_size.x, 0.0, checkmark_w) -- Feedback for next frame
    local stretch_w = ImMax(0.0, ImGui.GetContentRegionAvail().x - min_w)
    local text_pos = ImVec2(window.DC.CursorPos.x, window.DC.CursorPos.y + window.DC.CurrLineTextBaseOffset)

    local id = ImGui.GetID(label)
    local selectable_flags = bor(ImGuiSelectableFlags.SelectOnRelease, ImGuiSelectableFlags.SpanAvailWidth)
    if g.ActiveId == id then
        selectable_flags = bor(selectable_flags, ImGuiSelectableFlags.Highlight) -- Stays highlighted while dragging.
    end
    local has_been_moved = (g.ActiveId == id) and g.ActiveIdHasBeenEditedBefore -- But disable toggling once moved.

    ImGui.BeginDisabled(not enabled) -- Don't use ImGuiSelectableFlags_Disabled so that Check mark is also affected.
    local ret = ImGui.Selectable(label, false, selectable_flags, ImVec2(min_w, label_size.y)) and not has_been_moved
    if band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible) ~= 0 and selected then
        ImGui.RenderCheckMark(window.DrawList, text_pos + ImVec2(offsets.OffsetMark + stretch_w + g.FontSize * 0.40, g.FontSize * 0.134 * 0.5), ImGui.GetColorU32(ImGuiCol.Text), g.FontSize * 0.866)
    end
    ImGui.EndDisabled()

    return ret
end

-- Output context menu into current window (generally a popup)
function ImGui.TableDrawDefaultContextMenu(table_, flags_for_section_to_display)
    local g = GImGui
    local window = g.CurrentWindow
    if window.SkipItems then
        return
    end

    local want_separator = false
    local context_column_n = (table_.ContextPopupColumn >= 0 and table_.ContextPopupColumn < table_.ColumnsCount) and table_.ContextPopupColumn or -1
    local context_column = (context_column_n ~= -1) and table_.Columns[context_column_n] or nil

    -- Sizing
    if band(flags_for_section_to_display, ImGuiTableFlags.Resizable) ~= 0 then
        if context_column ~= nil then
            local can_resize = band(context_column.Flags, ImGuiTableColumnFlags.NoResize) == 0 and context_column.IsEnabled
            if ImGui.MenuItem(ImGui.LocalizeGetMsg(ImGuiLocKey.TableSizeOne), nil, false, can_resize) then -- "###SizeOne"
                ImGui.TableSetColumnWidthAutoSingle(table_, context_column_n)
            end
        end

        local size_all_desc
        if table_.ColumnsEnabledFixedCount == table_.ColumnsEnabledCount and band(table_.Flags, ImGuiTableFlags.SizingMask_) ~= ImGuiTableFlags.SizingFixedSame then
            size_all_desc = ImGui.LocalizeGetMsg(ImGuiLocKey.TableSizeAllFit)        -- "###SizeAll" All fixed
        else
            size_all_desc = ImGui.LocalizeGetMsg(ImGuiLocKey.TableSizeAllDefault)    -- "###SizeAll" All stretch or mixed
        end
        if ImGui.MenuItem(size_all_desc, nil) then
            ImGui.TableSetColumnWidthAutoAll(table_)
        end
        want_separator = true
    end

    -- Reset Order/Visibility etc.
    if band(flags_for_section_to_display, bor(ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable)) ~= 0 then
        if ImGui.BeginMenu(ImGui.LocalizeGetMsg(ImGuiLocKey.TableReset)) then
            if band(flags_for_section_to_display, ImGuiTableFlags.Reorderable) ~= 0 then
                if ImGui.MenuItem(ImGui.LocalizeGetMsg(ImGuiLocKey.TableResetOrder), nil, false, not table_.IsDefaultDisplayOrder) then -- PS: cannot be hidden because it would mess with drag reordering.
                    table_.IsResetDisplayOrderRequest = true
                end
            end
            if band(flags_for_section_to_display, ImGuiTableFlags.Hideable) ~= 0 then
                if ImGui.MenuItem(ImGui.LocalizeGetMsg(ImGuiLocKey.TableResetVisibility), nil, false, not table_.IsDefaultVisibility) then
                    table_.IsResetVisibilityRequest = true
                end
            end
            ImGui.EndMenu()
        end
    end

    -- Hiding / Visibility
    if band(flags_for_section_to_display, ImGuiTableFlags.Hideable) ~= 0 then
        if want_separator then
            ImGui.Separator()
        end
        want_separator = true

        -- While reordering: we calculate min/max allowed range once here so we can avoid a O(N log N) in the loop.
        local is_reordering = (g.ActiveId ~= 0 and g.ActiveIdWindow == g.CurrentWindow and table_.ReorderColumn ~= -1 and g.ActiveIdHasBeenEditedBefore) -- FIXME: This is a bit of a hack.
        local reorder_src_order = is_reordering and table_.Columns[table_.ReorderColumn].DisplayOrder or -1
        local reorder_min_order = is_reordering and TableGetMaxDisplayOrderAllowed(table_, reorder_src_order, 0) or 0
        local reorder_max_order = is_reordering and TableGetMaxDisplayOrderAllowed(table_, reorder_src_order, table_.ColumnsCount - 1) or (table_.ColumnsCount - 1)
        ImGui.PushItemFlag(ImGuiItemFlags.AutoClosePopups, false)
        for order_n = 0, table_.ColumnsCount - 1 do
            local column_n = table_.DisplayOrderToIndex[order_n]
            local column = table_.Columns[column_n]
            if band(column.Flags, ImGuiTableColumnFlags.Disabled) == 0 then
                local name = ImGui.TableGetColumnName(table_, column_n)
                if name == nil or name == "" then
                    name = "<Unknown>"
                end

                -- Make sure we can't hide the last active column
                local menu_item_enabled = band(column.Flags, ImGuiTableColumnFlags.NoHide) == 0
                if column.IsUserEnabled and table_.ColumnsEnabledCount <= 1 then
                    menu_item_enabled = false
                end
                if is_reordering and (column.DisplayOrder < reorder_min_order or column.DisplayOrder > reorder_max_order) then
                    menu_item_enabled = false
                end
                if MenuItemForColumnReorder(name, column.IsUserEnabled, menu_item_enabled) then
                    column.IsUserEnabledNextFrame = not column.IsUserEnabled
                end

                -- Drag to reorder
                if ImGui.IsItemActive() and ImGui.IsMouseDragging(0) and g.ActiveIdSource == ImGuiInputSource.Mouse and band(table_.Flags, ImGuiTableFlags.Reorderable) ~= 0 then
                    g.ActiveIdHasBeenEditedBefore = true -- Disable toggle in MenuItemForColumnReorder() + start dimming to display allowed reorder targets.
                    table_.ReorderColumn = column_n
                    if not ImGui.IsItemHovered() then
                        local reorder_dir = (g.IO.MousePos.y < (g.LastItemData.Rect.Min.y + g.LastItemData.Rect.Max.y) * 0.5) and -1 or 1
                        local reorder_amount = ((reorder_dir < 0) and (g.LastItemData.Rect.Min.y - g.IO.MousePos.y) or (g.IO.MousePos.y - g.LastItemData.Rect.Max.y)) / g.LastItemData.Rect:GetHeight()
                        local dst_order = column.DisplayOrder + ImTrunc(ImCeil(reorder_amount)) * reorder_dir -- Estimated target order, will be validated and clamped.
                        ImGui.TableQueueSetColumnDisplayOrder(table_, column_n, dst_order)
                    end
                end
            end
        end
        ImGui.PopItemFlag()
    end
end

----------------------------------------------------------------
-- [SECTION] Tables: Settings (.ini data)
----------------------------------------------------------------

-- Clear and initialize empty settings instance
local function TableSettingsInit(settings, id, columns_count, columns_count_max)
    for k, v in pairs(ImGuiTableSettings()) do settings[k] = v end
    for n = 0, columns_count_max - 1 do
        settings.Columns[n] = ImGuiTableColumnSettings()
    end
    settings.ID = id
    settings.ColumnsCount = columns_count
    settings.ColumnsCountMax = columns_count_max
    settings.WantApply = true
end

function ImGui.TableSettingsCreate(id, columns_count)
    local g = GImGui
    local settings = ImGui.TableSettingsFindByID(id)
    if settings then
        if settings.ColumnsCountMax >= columns_count then
            TableSettingsInit(settings, id, columns_count, settings.ColumnsCountMax) -- Recycle
            return settings
        end
        settings.ID = 0 -- Invalidate storage, we won't fit because of a count change
    end
    settings = ImGuiTableSettings()
    g.SettingsTables:push_back(settings)
    TableSettingsInit(settings, id, columns_count, columns_count)
    return settings
end

-- Find existing settings
function ImGui.TableSettingsFindByID(id)
    local g = GImGui
    for _, settings in g.SettingsTables:iter() do
        if settings.ID == id then
            return settings
        end
    end
    return nil
end

local function SettingsTablesOffsetFromPtr(settings)
    local g = GImGui
    return g.SettingsTables:find_index(settings) or -1
end

-- Get settings for a given table, NULL if none
function ImGui.TableGetBoundSettings(table_)
    if table_.SettingsOffset == -1 then
        return nil
    end
    local g = GImGui
    local settings = g.SettingsTables.Data[table_.SettingsOffset]
    IM_ASSERT(settings.ID == table_.ID)
    return settings
end

-- Restore initial state of table (with or without saved settings)
function ImGui.TableResetSettings(table_)
    table_.IsInitializing = true; table_.IsSettingsDirty = true
    table_.IsResetAllRequest = false
    table_.IsSettingsRequestLoad = false                    -- Don't reload from ini
    table_.SettingsLoadedFlags = ImGuiTableFlags.None       -- Mark as nothing loaded so our initialized data becomes authoritative
end

function ImGui.TableSaveSettings(table_)
    table_.IsSettingsDirty = false
    if band(table_.Flags, ImGuiTableFlags.NoSavedSettings) ~= 0 then
        return
    end

    -- Bind or create settings data
    local settings = ImGui.TableGetBoundSettings(table_)
    if settings ~= nil and table_.ColumnsCount > settings.ColumnsCountMax then
        settings.ID = 0 -- Invalidate storage, we won't fit because of a count change
        settings = nil
    end
    if settings == nil then
        settings = ImGui.TableSettingsCreate(table_.ID, table_.ColumnsCount)
        table_.SettingsOffset = SettingsTablesOffsetFromPtr(settings)
    end
    settings.ColumnsCount = table_.ColumnsCount

    -- Serialize ImGuiTable/ImGuiTableColumn into ImGuiTableSettings/ImGuiTableColumnSettings
    IM_ASSERT(settings.ID == table_.ID)
    IM_ASSERT(settings.ColumnsCount == table_.ColumnsCount and settings.ColumnsCountMax >= settings.ColumnsCount)

    local save_ref_scale = false
    settings.SaveFlags = ImGuiTableFlags.None
    for n = 0, table_.ColumnsCount - 1 do
        local column = table_.Columns[n]
        local column_settings = settings.Columns[n]
        local width_or_weight = (band(column.Flags, ImGuiTableColumnFlags.WidthStretch) ~= 0) and column.StretchWeight or column.WidthRequest
        column_settings.ID = column.ID
        column_settings.WidthOrWeight = width_or_weight
        column_settings.Index = n
        column_settings.DisplayOrder = column.DisplayOrder
        column_settings.SortOrder = column.SortOrder
        column_settings.SortDirection = column.SortDirection
        column_settings.IsEnabled = column.IsUserEnabled and 1 or 0
        column_settings.IsStretch = (band(column.Flags, ImGuiTableColumnFlags.WidthStretch) ~= 0) and 1 or 0
        if band(column.Flags, ImGuiTableColumnFlags.WidthStretch) == 0 then
            save_ref_scale = true
        end

        -- We skip saving some data in the .ini file when they are unnecessary to restore our state.
        if width_or_weight ~= column.InitStretchWeightOrWidth then
            settings.SaveFlags = bor(settings.SaveFlags, ImGuiTableFlags.Resizable)
        end
        if column.DisplayOrder ~= n then
            settings.SaveFlags = bor(settings.SaveFlags, ImGuiTableFlags.Reorderable)
        end
        if column.SortOrder ~= -1 then
            settings.SaveFlags = bor(settings.SaveFlags, ImGuiTableFlags.Sortable, ImGuiTableFlags.Reorderable) -- Because SortOrder saving itself is gated, make sure every column is saved (#9519)
        end
        if column.IsUserEnabled ~= (band(column.Flags, ImGuiTableColumnFlags.DefaultHide) == 0) then
            settings.SaveFlags = bor(settings.SaveFlags, ImGuiTableFlags.Hideable)
        end
    end
    settings.SaveFlags = band(settings.SaveFlags, table_.Flags)
    settings.RefScale = save_ref_scale and table_.RefScale or 0.0

    ImGui.MarkIniSettingsDirty()
end

function ImGui.TableLoadSettings(table_)
    if band(table_.Flags, ImGuiTableFlags.NoSavedSettings) ~= 0 then
        table_.IsSettingsRequestLoad = false -- Done
        return
    end

    -- Bind settings
    local settings
    if table_.SettingsOffset == -1 then
        settings = ImGui.TableSettingsFindByID(table_.ID)
        if settings == nil then
            return
        end
        if settings.ColumnsCount ~= table_.ColumnsCount then -- Allow settings if columns count changed. We could otherwise decide to return...
            table_.IsSettingsDirty = true
        end
        table_.SettingsOffset = SettingsTablesOffsetFromPtr(settings)
    else
        settings = ImGui.TableGetBoundSettings(table_)
    end

    table_.SettingsLoadedFlags = settings.SaveFlags
    table_.RefScale = settings.RefScale
    -- TableUpdateLayout() will then call TableLoadSettingsForColumns() to apply the data.
end

-- NB: This was written to be similar to the logic in TableReconcileColumns().
function ImGui.TableLoadSettingsForColumns(table_)
    for n = 0, table_.ColumnsSize - 1 do
        table_.Columns[n].IsLoadedSettings = false
    end
    local settings = ImGui.TableGetBoundSettings(table_)
    if settings == nil then
        return
    end

    table_.SettingsLoadedFlags = bor(table_.SettingsLoadedFlags, ImGuiTableFlags.Reorderable) -- We handle above in code above.

    -- Serialize ImGuiTableSettings/ImGuiTableColumnSettings into ImGuiTable/ImGuiTableColumn
    local column_settings = settings.Columns

    -- Fast path
    local matches = 0
    for n = 0, table_.ColumnsCount - 1 do
        if n >= settings.ColumnsCount or column_settings[n].ID ~= table_.Columns[n].ID then
            break
        end
        ImGui.TableLoadSettingsForColumn(table_.Columns[n], column_settings[n], settings.SaveFlags)
        matches = matches + 1
    end
    if matches == settings.ColumnsCount then
        return
    end
    local settings_start_n = matches -- Small optimization
    for n = settings_start_n, settings.ColumnsCount - 1 do
        column_settings[n].IsLoaded = false
    end

    -- Find matches for named columns
    for c = 0, table_.ColumnsSize - 1 do
        local column = table_.Columns[c]
        if column.ID ~= 0 and not column.IsLoadedSettings then
            for n = settings_start_n, settings.ColumnsCount - 1 do
                if column_settings[n].ID == column.ID and not column_settings[n].IsLoaded then
                    ImGui.TableLoadSettingsForColumn(column, column_settings[n], settings.SaveFlags)
                    matches = matches + 1
                    break
                end
            end
        end
    end

    -- Remaining entries are matched sequentially
    local dst_idx = 0
    for n = settings_start_n, settings.ColumnsCount - 1 do
        if not column_settings[n].IsLoaded then
            while dst_idx < table_.ColumnsCount and table_.Columns[dst_idx].IsLoadedSettings do
                dst_idx = dst_idx + 1
            end
            if dst_idx >= table_.ColumnsCount then
                break
            end
            ImGui.TableLoadSettingsForColumn(table_.Columns[dst_idx], column_settings[n], settings.SaveFlags)
            dst_idx = dst_idx + 1
        end
    end
end

function ImGui.TableLoadSettingsForColumn(column, column_settings, load_flags)
    column.IsLoadedSettings = true
    column_settings.IsLoaded = true
    if band(load_flags, ImGuiTableFlags.Resizable) ~= 0 then
        if column_settings.IsStretch ~= 0 then
            column.StretchWeight = column_settings.WidthOrWeight
        else
            column.WidthRequest = column_settings.WidthOrWeight
        end
        column.AutoFitQueue = 0x00
    end
    if band(load_flags, ImGuiTableFlags.Reorderable) ~= 0 then
        column.DisplayOrder = column_settings.DisplayOrder
    else
        column.DisplayOrder = column_settings.Index -- Because default depends on previous Index, we need to set that up and cannot rely on TableInitColumnDefaults()
    end
    if band(load_flags, ImGuiTableFlags.Hideable) ~= 0 and column_settings.IsEnabled ~= -1 then
        local v = (column_settings.IsEnabled == 1)
        column.IsUserEnabled = v; column.IsUserEnabledNextFrame = v
    end
    column.SortOrder = column_settings.SortOrder
    column.SortDirection = column_settings.SortDirection
end

-- Fix invalid display order data: compact values (0,1,3 -> 0,1,2); preserve relative order (0,3,1 -> 0,2,1); deduplicate (0,4,1,1 -> 0,3,1,2)
function ImGui.TableFixDisplayOrder(table_)
    if band(table_.Flags, ImGuiTableFlags.Reorderable) == 0 then
        for n = 0, table_.ColumnsCount - 1 do
            table_.Columns[n].DisplayOrder = n
            table_.DisplayOrderToIndex[n] = n
        end
        return
    end
    local fdo_columns = {}
    for n = 0, table_.ColumnsCount - 1 do
        fdo_columns[n + 1] = n
    end
    -- Sort by DisplayOrder and then Index. -1 (unsigned short 0xFFFF) always sorts after.
    local function key(idx)
        local o = table_.Columns[idx].DisplayOrder
        if o < 0 then o = o + 0x10000 end
        return o
    end
    table.sort(fdo_columns, function(lhs_idx, rhs_idx)
        local a, b = key(lhs_idx), key(rhs_idx)
        if a ~= b then return a < b end
        return lhs_idx < rhs_idx
    end)
    for n = 0, table_.ColumnsCount - 1 do
        table_.Columns[fdo_columns[n + 1]].DisplayOrder = n
    end
    for n = 0, table_.ColumnsCount - 1 do
        table_.DisplayOrderToIndex[table_.Columns[n].DisplayOrder] = n
    end
end

local function ForEachTable(g, fn)
    for i = 0, g.Tables:GetMapSize() - 1 do
        local t = g.Tables:GetByIndex(i)
        if t then fn(t) end
    end
end

local function TableSettingsHandler_ClearAll(ctx, handler)
    local g = ctx
    ForEachTable(g, function(t) t.SettingsOffset = -1 end)
    g.SettingsTables:clear()
end

-- Apply to existing windows (if any)
local function TableSettingsHandler_ApplyAll(ctx, handler)
    local g = ctx
    ForEachTable(g, function(t)
        t.IsSettingsRequestLoad = true
        t.SettingsOffset = -1
    end)
end

local function TableSettingsHandler_ReadOpen(ctx, handler, name)
    local id, columns_count = string.match(name, "^0x(%x+),(%-?%d+)")
    if id == nil then
        return nil
    end
    id = tonumber(id, 16); columns_count = tonumber(columns_count)
    if columns_count <= 0 or columns_count >= IMGUI_TABLE_MAX_COLUMNS then
        return nil
    end
    return ImGui.TableSettingsCreate(id, columns_count)
end

local function TableSettingsHandler_ReadLine(ctx, handler, settings, line)
    -- "Column 0  UserID=0x42AD2D21 Width=100 Visible=1 Order=0 Sort=0v"
    if settings == nil then return end
    local f = string.match(line, "^RefScale=([%-%d%.eE+]+)")
    if f then settings.RefScale = tonumber(f); return end
    local n = string.match(line, "^LastUsed=(%d+)")
    if n then settings.LastUsedDate = tonumber(n); return end

    local column_n, rest = string.match(line, "^Column (%-?%d+)(.*)$")
    if column_n then
        column_n = tonumber(column_n)
        if column_n < 0 or column_n >= settings.ColumnsCount then
            return
        end
        local column = settings.Columns[column_n]
        column.Index = column_n
        local function take(pattern)
            local a, b, r = string.match(rest, "^%s*" .. pattern .. "()")
            if a == nil then return nil end
            if r == nil then r = b; b = nil end
            rest = string.sub(rest, r)
            return a, b
        end
        take("UserID=0x(%x+)") -- FIXME-LEGACY: Removed 2025/11/12, was never properly set.
        local v = take("Width=(%-?%d+)")
        if v then column.WidthOrWeight = tonumber(v); column.IsStretch = 0; settings.SaveFlags = bor(settings.SaveFlags, ImGuiTableFlags.Resizable) end
        v = take("Weight=([%-%d%.eE+]+)")
        if v then column.WidthOrWeight = tonumber(v); column.IsStretch = 1; settings.SaveFlags = bor(settings.SaveFlags, ImGuiTableFlags.Resizable) end
        v = take("Visible=(%-?%d+)")
        if v then column.IsEnabled = tonumber(v); settings.SaveFlags = bor(settings.SaveFlags, ImGuiTableFlags.Hideable) end
        v = take("Order=(%-?%d+)")
        if v then column.DisplayOrder = tonumber(v); settings.SaveFlags = bor(settings.SaveFlags, ImGuiTableFlags.Reorderable) end
        local c
        v, c = take("Sort=(%-?%d+)(.)")
        if v then column.SortOrder = tonumber(v); column.SortDirection = (c == "^") and ImGuiSortDirection.Descending or ImGuiSortDirection.Ascending; settings.SaveFlags = bor(settings.SaveFlags, ImGuiTableFlags.Sortable) end
        v = take("ID=0x(%x+)")
        if v then column.ID = tonumber(v, 16) end
    end
end

local function TableSettingsHandler_WriteAll(ctx, handler, buf)
    local g = ctx
    for _, settings in g.SettingsTables:iter() do
        if settings.ID ~= 0 then -- Skip ditched settings
            local save_size    = band(settings.SaveFlags, ImGuiTableFlags.Resizable) ~= 0
            local save_visible = band(settings.SaveFlags, ImGuiTableFlags.Hideable) ~= 0
            local save_order   = band(settings.SaveFlags, ImGuiTableFlags.Reorderable) ~= 0
            local save_sort    = band(settings.SaveFlags, ImGuiTableFlags.Sortable) ~= 0
            -- We need to save the [Table] entry even if all the bools are false, since this records a table with "default settings".

            buf:appendf("[%s][0x%08X,%d]\n", handler.TypeName, settings.ID, settings.ColumnsCount)
            if settings.RefScale ~= 0.0 then
                buf:appendf("RefScale=%g\n", settings.RefScale)
            end
            for column_n = 0, settings.ColumnsCount - 1 do
                local column = settings.Columns[column_n]
                local save_column = save_size or save_visible or save_order or (save_sort and column.SortOrder ~= -1)
                if save_column then
                    buf:appendf("Column %-2d", column_n)
                    if save_size and column.IsStretch ~= 0 then buf:appendf(" Weight=%.4f", column.WidthOrWeight) end
                    if save_size and column.IsStretch == 0 then buf:appendf(" Width=%d", ImTrunc(column.WidthOrWeight)) end
                    if save_visible then buf:appendf(" Visible=%d", column.IsEnabled) end
                    if save_order then buf:appendf(" Order=%d", column.DisplayOrder) end
                    if save_sort and column.SortOrder ~= -1 then buf:appendf(" Sort=%d%s", column.SortOrder, (column.SortDirection == ImGuiSortDirection.Ascending) and "v" or "^") end
                    if column.ID ~= 0 then buf:appendf(" ID=0x%08X", column.ID) end
                    buf:append("\n")
                end
            end
            if g.IO.ConfigIniSettingsSaveLastUsedDate and settings.LastUsedDate ~= 0 then
                buf:appendf("LastUsed=%08d\n", settings.LastUsedDate)
            end
            buf:append("\n")
        end
    end
end

function ImGui.TableSettingsAddSettingsHandler()
    local ini_handler = ImGuiSettingsHandler()
    ini_handler.TypeName = "Table"
    ini_handler.TypeHash = ImHashStr("Table")
    ini_handler.ClearAllFn = TableSettingsHandler_ClearAll
    ini_handler.ReadOpenFn = TableSettingsHandler_ReadOpen
    ini_handler.ReadLineFn = TableSettingsHandler_ReadLine
    ini_handler.ApplyAllFn = TableSettingsHandler_ApplyAll
    ini_handler.WriteAllFn = TableSettingsHandler_WriteAll
    ImGui.AddSettingsHandler(ini_handler)
end

----------------------------------------------------------------
-- [SECTION] Tables: Garbage Collection
----------------------------------------------------------------

-- Remove Table data (currently only used by TestEngine)
function ImGui.TableRemove(table_)
    local g = GImGui
    local table_idx = g.Tables:GetIndex(table_)
    g.Tables:Remove(table_.ID, table_)
    g.TablesLastTimeActive.Data[table_idx + 1] = -1.0
end

-- Free up/compact internal Table buffers for when it gets unused
-- Overloads: (ImGuiTable) / (ImGuiTableTempData)
function ImGui.TableGcCompactTransientBuffers(t)
    if not t then return end
    if t.TableIndex ~= nil then -- ImGuiTableTempData
        t.AngledHeadersRequests:clear()
        t.DrawSplitter:ClearFreeMemory()
        t.LastTimeActive = -1.0
        return
    end
    local g = GImGui
    local table_ = t
    IM_ASSERT(table_.MemoryCompacted == false)
    table_.SortSpecs.Specs = nil
    table.clear(table_.SortSpecsMulti)
    table_.IsSortSpecsDirty = true -- FIXME: In theory shouldn't have to leak into user performing a sort on resume.
    table.clear(table_.ColumnsNames)
    table_.MemoryCompacted = true
    for n = 0, table_.ColumnsCount - 1 do
        table_.Columns[n].NameOffset = -1
    end
    g.TablesLastTimeActive.Data[g.Tables:GetIndex(table_) + 1] = -1.0
end

-- Compact and remove unused or resize settings data
function ImGui.TableGcCompactSettings()
    local g = GImGui
    local has_dead = false
    for _, settings in g.SettingsTables:iter() do
        if settings.ID == 0 then has_dead = true end
    end
    if not has_dead then
        return
    end
    local new_list = ImVector()
    for _, settings in g.SettingsTables:iter() do
        if settings.ID ~= 0 then new_list:push_back(settings) end
    end
    g.SettingsTables = new_list
    ForEachTable(g, function(t) t.SettingsOffset = -1 end)
end

----------------------------------------------------------------
-- [SECTION] Columns, BeginColumns, EndColumns, etc.
-- (This is a legacy API, prefer using BeginTable/EndTable!)
----------------------------------------------------------------
-- (Lua: columns.Columns is an ImVector, column n lives in .Data[n + 1])

function ImGui.GetColumnIndex()
    local window = ImGui.GetCurrentWindowRead()
    return window.DC.CurrentColumns and window.DC.CurrentColumns.Current or 0
end

function ImGui.GetColumnsCount()
    local window = ImGui.GetCurrentWindowRead()
    return window.DC.CurrentColumns and window.DC.CurrentColumns.Count or 1
end

function ImGui.GetColumnOffsetFromNorm(columns, offset_norm)
    return offset_norm * (columns.OffMaxX - columns.OffMinX)
end

function ImGui.GetColumnNormFromOffset(columns, offset)
    return offset / (columns.OffMaxX - columns.OffMinX)
end

local COLUMNS_HIT_RECT_HALF_THICKNESS = 4.0

local function GetDraggedColumnOffset(columns, column_index)
    -- Active (dragged) column always follow mouse.
    local g = GImGui
    local window = g.CurrentWindow
    IM_ASSERT(column_index > 0) -- We are not supposed to drag column 0.
    IM_ASSERT(g.ActiveId == band(columns.ID + column_index, 0xFFFFFFFF))

    local x = g.IO.MousePos.x - g.ActiveIdClickOffset.x + ImTrunc(COLUMNS_HIT_RECT_HALF_THICKNESS * g.CurrentDpiScale) - window.Pos.x
    x = ImMax(x, ImGui.GetColumnOffset(column_index - 1) + g.Style.ColumnsMinSpacing)
    if band(columns.Flags, ImGuiOldColumnFlags.NoPreserveWidths) ~= 0 then
        x = ImMin(x, ImGui.GetColumnOffset(column_index + 1) - g.Style.ColumnsMinSpacing)
    end

    return x
end

function ImGui.GetColumnOffset(column_index)
    if column_index == nil then column_index = -1 end
    local window = ImGui.GetCurrentWindowRead()
    local columns = window.DC.CurrentColumns
    if columns == nil then
        return 0.0
    end

    if column_index < 0 then
        column_index = columns.Current
    end
    IM_ASSERT(column_index < columns.Columns.Size)

    local t = columns.Columns.Data[column_index + 1].OffsetNorm
    local x_offset = ImLerp(columns.OffMinX, columns.OffMaxX, t)
    return x_offset
end

local function GetColumnWidthEx(columns, column_index, before_resize)
    if column_index < 0 then
        column_index = columns.Current
    end

    local d = columns.Columns.Data
    local offset_norm
    if before_resize then
        offset_norm = d[column_index + 2].OffsetNormBeforeResize - d[column_index + 1].OffsetNormBeforeResize
    else
        offset_norm = d[column_index + 2].OffsetNorm - d[column_index + 1].OffsetNorm
    end
    return ImGui.GetColumnOffsetFromNorm(columns, offset_norm)
end

function ImGui.GetColumnWidth(column_index)
    if column_index == nil then column_index = -1 end
    local g = GImGui
    local window = g.CurrentWindow
    local columns = window.DC.CurrentColumns
    if columns == nil then
        return ImGui.GetContentRegionAvail().x
    end

    if column_index < 0 then
        column_index = columns.Current
    end
    local d = columns.Columns.Data
    return ImGui.GetColumnOffsetFromNorm(columns, d[column_index + 2].OffsetNorm - d[column_index + 1].OffsetNorm)
end

function ImGui.SetColumnOffset(column_index, offset)
    local g = GImGui
    local window = g.CurrentWindow
    local columns = window.DC.CurrentColumns
    IM_ASSERT(columns ~= nil)

    if column_index < 0 then
        column_index = columns.Current
    end
    IM_ASSERT(column_index < columns.Columns.Size)

    local preserve_width = band(columns.Flags, ImGuiOldColumnFlags.NoPreserveWidths) == 0 and (column_index < columns.Count - 1)
    local width = preserve_width and GetColumnWidthEx(columns, column_index, columns.IsBeingResized) or 0.0

    if band(columns.Flags, ImGuiOldColumnFlags.NoForceWithinWindow) == 0 then
        offset = ImMin(offset, columns.OffMaxX - g.Style.ColumnsMinSpacing * (columns.Count - column_index))
    end
    columns.Columns.Data[column_index + 1].OffsetNorm = ImGui.GetColumnNormFromOffset(columns, offset - columns.OffMinX)

    if preserve_width then
        ImGui.SetColumnOffset(column_index + 1, offset + ImMax(g.Style.ColumnsMinSpacing, width))
    end
end

function ImGui.SetColumnWidth(column_index, width)
    local window = ImGui.GetCurrentWindowRead()
    local columns = window.DC.CurrentColumns
    IM_ASSERT(columns ~= nil)

    if column_index < 0 then
        column_index = columns.Current
    end
    ImGui.SetColumnOffset(column_index + 1, ImGui.GetColumnOffset(column_index) + width)
end

function ImGui.PushColumnClipRect(column_index)
    local window = ImGui.GetCurrentWindowRead()
    local columns = window.DC.CurrentColumns
    if column_index < 0 then
        column_index = columns.Current
    end

    local column = columns.Columns.Data[column_index + 1]
    ImGui.PushClipRect(column.ClipRect.Min, column.ClipRect.Max, false)
end

-- Get into the columns background draw command (which is generally the same draw command as before we called BeginColumns)
function ImGui.PushColumnsBackground()
    local window = ImGui.GetCurrentWindowRead()
    local columns = window.DC.CurrentColumns
    if columns.Count == 1 then
        return
    end

    -- Optimization: avoid SetCurrentChannel() + PushClipRect()
    ImRect_Copy(columns.HostBackupClipRect, window.ClipRect)
    ImGui.SetWindowClipRectBeforeSetChannel(window, columns.HostInitialClipRect)
    columns.Splitter:SetCurrentChannel(window.DrawList, 0)
end

function ImGui.PopColumnsBackground()
    local window = ImGui.GetCurrentWindowRead()
    local columns = window.DC.CurrentColumns
    if columns.Count == 1 then
        return
    end

    -- Optimization: avoid PopClipRect() + SetCurrentChannel()
    ImGui.SetWindowClipRectBeforeSetChannel(window, columns.HostBackupClipRect)
    columns.Splitter:SetCurrentChannel(window.DrawList, columns.Current + 1)
end

function ImGui.FindOrCreateColumns(window, id)
    -- We have few columns per window so for now we don't need bother much with turning this into a faster lookup.
    for _, c in window.ColumnsStorage:iter() do
        if c.ID == id then
            return c
        end
    end

    local columns = ImGuiOldColumns()
    window.ColumnsStorage:push_back(columns)
    columns.ID = id
    return columns
end

function ImGui.GetColumnsID(str_id, columns_count)
    local window = ImGui.GetCurrentWindow()

    -- Differentiate column ID with an arbitrary prefix for cases where users name their columns set the same as another widget.
    ImGui.PushID(0x11223347 + (str_id and 0 or columns_count))
    local id = window:GetID(str_id or "columns")
    ImGui.PopID()

    return id
end

function ImGui.BeginColumns(str_id, columns_count, flags)
    if flags == nil then flags = 0 end
    local g = GImGui
    local window = ImGui.GetCurrentWindow()

    IM_ASSERT(columns_count >= 1)
    IM_ASSERT(window.DC.CurrentColumns == nil) -- Nested columns are currently not supported

    -- Acquire storage for the columns set
    local id = ImGui.GetColumnsID(str_id, columns_count)
    local columns = ImGui.FindOrCreateColumns(window, id)
    IM_ASSERT(columns.ID == id)
    columns.Current = 0
    columns.Count = columns_count
    columns.Flags = flags
    window.DC.CurrentColumns = columns
    window.DC.NavIsScrollPushableX = false -- Shortcut for NavUpdateCurrentWindowIsScrollPushableX();

    columns.HostCursorPosY = window.DC.CursorPos.y
    columns.HostCursorMaxPosX = window.DC.CursorMaxPos.x
    ImRect_Copy(columns.HostInitialClipRect, window.ClipRect)
    ImRect_Copy(columns.HostBackupParentWorkRect, window.ParentWorkRect)
    ImRect_Copy(window.ParentWorkRect, window.WorkRect)

    -- Set state for first column
    local column_padding = g.Style.ItemSpacing.x
    local half_clip_extend_x = ImTrunc(ImMax(window.WindowPadding.x * 0.5, window.WindowBorderSize))
    local max_1 = window.WorkRect.Max.x + column_padding - ImMax(column_padding - window.WindowPadding.x, 0.0)
    local max_2 = window.WorkRect.Max.x + half_clip_extend_x
    columns.OffMinX = window.DC.Indent.x - column_padding + ImMax(column_padding - window.WindowPadding.x, 0.0)
    columns.OffMaxX = ImMax(ImMin(max_1, max_2) - window.Pos.x, columns.OffMinX + 1.0)
    columns.LineMinY = window.DC.CursorPos.y; columns.LineMaxY = window.DC.CursorPos.y

    -- Clear data if columns count changed
    if columns.Columns.Size ~= 0 and columns.Columns.Size ~= columns_count + 1 then
        columns.Columns:resize(0)
    end

    -- Initialize default widths
    columns.IsFirstFrame = (columns.Columns.Size == 0)
    if columns.Columns.Size == 0 then
        for n = 0, columns_count do
            local column = ImGuiOldColumnData()
            column.OffsetNorm = n / columns_count
            columns.Columns:push_back(column)
        end
    end

    for n = 0, columns_count - 1 do
        -- Compute clipping rectangle
        local column = columns.Columns.Data[n + 1]
        local clip_x1 = IM_ROUND(window.Pos.x + ImGui.GetColumnOffset(n))
        local clip_x2 = IM_ROUND(window.Pos.x + ImGui.GetColumnOffset(n + 1) - 1.0)
        column.ClipRect = ImRect(clip_x1, -FLT_MAX, clip_x2, FLT_MAX)
        column.ClipRect:ClipWithFull(window.ClipRect)
    end

    if columns.Count > 1 then
        columns.Splitter:Split(window.DrawList, 1 + columns.Count)
        columns.Splitter:SetCurrentChannel(window.DrawList, 1)
        ImGui.PushColumnClipRect(0)
    end

    -- We don't generally store Indent.x inside ColumnsOffset because it may be manipulated by the user.
    local offset_0 = ImGui.GetColumnOffset(columns.Current)
    local offset_1 = ImGui.GetColumnOffset(columns.Current + 1)
    local width = offset_1 - offset_0
    ImGui.PushItemWidth(width * 0.65)
    window.DC.ColumnsOffset.x = ImMax(column_padding - window.WindowPadding.x, 0.0)
    window.DC.CursorPos.x = IM_TRUNC(window.Pos.x + window.DC.Indent.x + window.DC.ColumnsOffset.x)
    window.WorkRect.Max.x = window.Pos.x + offset_1 - column_padding
    window.WorkRect.Max.y = window.ContentRegionRect.Max.y
end

function ImGui.NextColumn()
    local window = ImGui.GetCurrentWindow()
    if window.SkipItems or window.DC.CurrentColumns == nil then
        return
    end

    local g = GImGui
    local columns = window.DC.CurrentColumns

    if columns.Count == 1 then
        window.DC.CursorPos.x = IM_TRUNC(window.Pos.x + window.DC.Indent.x + window.DC.ColumnsOffset.x)
        IM_ASSERT(columns.Current == 0)
        return
    end

    -- Next column
    columns.Current = columns.Current + 1
    if columns.Current == columns.Count then
        columns.Current = 0
    end

    ImGui.PopItemWidth()

    -- Optimization: avoid PopClipRect() + SetCurrentChannel() + PushClipRect()
    local column = columns.Columns.Data[columns.Current + 1]
    ImGui.SetWindowClipRectBeforeSetChannel(window, column.ClipRect)
    columns.Splitter:SetCurrentChannel(window.DrawList, columns.Current + 1)

    local column_padding = g.Style.ItemSpacing.x
    columns.LineMaxY = ImMax(columns.LineMaxY, window.DC.CursorPos.y)
    if columns.Current > 0 then
        -- Columns 1+ ignore IndentX (by canceling it out)
        window.DC.ColumnsOffset.x = ImGui.GetColumnOffset(columns.Current) - window.DC.Indent.x + column_padding
    else
        -- New row/line: column 0 honor IndentX.
        window.DC.ColumnsOffset.x = ImMax(column_padding - window.WindowPadding.x, 0.0)
        window.DC.IsSameLine = false
        columns.LineMinY = columns.LineMaxY
    end
    window.DC.CursorPos.x = IM_TRUNC(window.Pos.x + window.DC.Indent.x + window.DC.ColumnsOffset.x)
    window.DC.CursorPos.y = columns.LineMinY
    window.DC.CurrLineSize.x = 0.0; window.DC.CurrLineSize.y = 0.0
    window.DC.CurrLineTextBaseOffset = 0.0

    local offset_0 = ImGui.GetColumnOffset(columns.Current)
    local offset_1 = ImGui.GetColumnOffset(columns.Current + 1)
    local width = offset_1 - offset_0
    ImGui.PushItemWidth(width * 0.65)
    window.WorkRect.Max.x = window.Pos.x + offset_1 - column_padding
end

function ImGui.EndColumns()
    local g = GImGui
    local window = ImGui.GetCurrentWindow()
    local columns = window.DC.CurrentColumns
    IM_ASSERT(columns ~= nil)

    ImGui.PopItemWidth()
    if columns.Count > 1 then
        ImGui.PopClipRect()
        columns.Splitter:Merge(window.DrawList)
    end

    local flags = columns.Flags
    columns.LineMaxY = ImMax(columns.LineMaxY, window.DC.CursorPos.y)
    window.DC.CursorPos.y = columns.LineMaxY
    if band(flags, ImGuiOldColumnFlags.GrowParentContentsSize) == 0 then
        window.DC.CursorMaxPos.x = columns.HostCursorMaxPosX -- Restore cursor max pos, as columns don't grow parent
    end

    -- Draw columns borders and handle resize
    local is_being_resized = false
    if band(flags, ImGuiOldColumnFlags.NoBorder) == 0 and not window.SkipItems then
        -- We clip Y boundaries CPU side because very long triangles are mishandled by some GPU drivers.
        local y1 = ImMax(columns.HostCursorPosY, window.ClipRect.Min.y)
        local y2 = ImMin(window.DC.CursorPos.y, window.ClipRect.Max.y)
        local dragging_column = -1
        for n = 1, columns.Count - 1 do
            local column = columns.Columns.Data[n + 1]
            local x = window.Pos.x + ImGui.GetColumnOffset(n)
            local column_id = band(columns.ID + n, 0xFFFFFFFF)
            local column_hit_hw = ImTrunc(COLUMNS_HIT_RECT_HALF_THICKNESS * g.CurrentDpiScale)
            local column_hit_rect = ImRect(ImVec2(x - column_hit_hw, y1), ImVec2(x + column_hit_hw, y2))
            if ImGui.ItemAdd(column_hit_rect, column_id, nil, ImGuiItemFlags.NoNav) then
                local hovered, held = false, false
                if band(flags, ImGuiOldColumnFlags.NoResize) == 0 then
                    local _
                    _, hovered, held = ImGui.ButtonBehavior(column_hit_rect, column_id)
                    if hovered or held then
                        ImGui.SetMouseCursor(ImGuiMouseCursor.ResizeEW)
                    end
                    if held and band(column.Flags, ImGuiOldColumnFlags.NoResize) == 0 then
                        dragging_column = n
                    end
                end

                -- Draw column
                local col = ImGui.GetColorU32(held and ImGuiCol.SeparatorActive or (hovered and ImGuiCol.SeparatorHovered or ImGuiCol.Separator))
                local xi = IM_TRUNC(x)
                window.DrawList:AddLineV(xi, y1 + 1.0, y2, col)
            end
        end

        -- Apply dragging after drawing the column lines, so our rendered lines are in sync with how items were displayed during the frame.
        if dragging_column ~= -1 then
            if not columns.IsBeingResized then
                for n = 0, columns.Count do
                    local c = columns.Columns.Data[n + 1]
                    c.OffsetNormBeforeResize = c.OffsetNorm
                end
            end
            columns.IsBeingResized = true; is_being_resized = true
            local x = GetDraggedColumnOffset(columns, dragging_column)
            ImGui.SetColumnOffset(dragging_column, x)
        end
    end
    columns.IsBeingResized = is_being_resized

    ImRect_Copy(window.WorkRect, window.ParentWorkRect)
    ImRect_Copy(window.ParentWorkRect, columns.HostBackupParentWorkRect)
    window.DC.CurrentColumns = nil
    window.DC.ColumnsOffset.x = 0.0
    window.DC.CursorPos.x = IM_TRUNC(window.Pos.x + window.DC.Indent.x + window.DC.ColumnsOffset.x)
    ImGui.NavUpdateCurrentWindowIsScrollPushableX()
end

--- @param columns_count? int
--- @param id?            string
--- @param borders?       bool
function ImGui.Columns(columns_count, id, borders)
    if columns_count == nil then columns_count = 1 end
    if borders == nil then borders = true end
    local window = ImGui.GetCurrentWindow()
    IM_ASSERT(columns_count >= 1)

    local flags = borders and 0 or ImGuiOldColumnFlags.NoBorder
    local columns = window.DC.CurrentColumns
    if columns ~= nil and columns.Count == columns_count and columns.Flags == flags then
        return
    end

    if columns ~= nil then
        ImGui.EndColumns()
    end

    if columns_count ~= 1 then
        ImGui.BeginColumns(id, columns_count, flags)
    end
end

return true -- [Roblox] ModuleScripts must return exactly one value
