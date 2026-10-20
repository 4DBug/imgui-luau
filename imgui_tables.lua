--- Dear ImGui WIP
-- (tables and columns code)
-- 1:1 port of imgui_tables.cpp (docking branch, 1.93 WIP)

-- Index of this file:
--
-- [SECTION] Commentary
-- [SECTION] Structs (port: struct constructors from imgui_internal.h / imgui.h)
-- [SECTION] Tables: Main code
-- [SECTION] Tables: Simple accessors
-- [SECTION] Tables: Row changes
-- [SECTION] Tables: Columns changes
-- [SECTION] Tables: Columns width management
-- [SECTION] Tables: Drawing
-- [SECTION] Tables: Sorting
-- [SECTION] Tables: Headers
-- [SECTION] Tables: Context Menu
-- [SECTION] Tables: Settings (.ini data)
-- [SECTION] Tables: Garbage Collection
-- [SECTION] Columns, BeginColumns, EndColumns, etc.

-------------------------------------------------------------------------------
-- [SECTION] Commentary
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Typical tables call flow: (root level is generally public API):
-------------------------------------------------------------------------------
-- - BeginTable()                               user begin into a table
--    | BeginChild()                            - (if ScrollX/ScrollY is set)
--    | TableBeginInitMemory()                  - first time table is used
--    | TableResetSettings()                    - on settings reset
--    | TableLoadSettings()                     - on settings load
-------------------------------------------------------------------------------
-- - TableSetupColumn()                         user submit columns details (optional)
-- - TableSetupScrollFreeze()                   user submit scroll freeze information (optional)
-------------------------------------------------------------------------------
-- - TableUpdateLayout() [Internal]             followup to BeginTable(): setup everything: widths, columns positions, clipping rectangles. Automatically called by the FIRST call to TableNextRow() or TableHeadersRow().
--    | TableApplyQueuedRequests()              - apply queued resizing/reordering/hiding requests
--    | - TableSetColumnWidth()                 - apply resizing width (for mouse resize, often requested by previous frame)
--    |    - TableUpdateColumnsWeightFromWidth()- recompute columns weights (of stretch columns) from their respective width
--    | - TableSetColumnDisplayOrder()          - apply reordering a column
--    | TableSetupDrawChannels()                - setup ImDrawList channels
--    | TableUpdateBorders()                    - detect hovering columns for resize, ahead of contents submission
--    | TableBeginContextMenuPopup()
--    | - TableDrawDefaultContextMenu()         - draw right-click context menu contents
-------------------------------------------------------------------------------
-- - TableHeadersRow() or TableHeader()         user submit a headers row (optional)
--    | TableSortSpecsClickColumn()             - when left-clicked: alter sort order and sort direction
--    | TableOpenContextMenu()                  - when right-clicked: trigger opening of the default context menu
-- - TableGetSortSpecs()                        user queries updated sort specs (optional, generally after submitting headers)
-- - TableNextRow()                             user begin into a new row (also automatically called by TableHeadersRow())
--    | TableEndRow()                           - finish existing row
--    | TableBeginRow()                         - add a new row
-- - TableSetColumnIndex() / TableNextColumn()  user begin into a cell
--    | TableEndCell()                          - close existing column/cell
--    | TableBeginCell()                        - enter into current column/cell
-- - [...]                                      user emit contents
-------------------------------------------------------------------------------
-- - EndTable()                                 user ends the table
--    | TableDrawBorders()                      - draw outer borders, inner vertical borders
--    | TableMergeDrawChannels()                - merge draw channels if clipping isn't required
--    | EndChild()                              - (if ScrollX/ScrollY is set)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TABLE SIZING
-------------------------------------------------------------------------------
-- (Read carefully because this is subtle but it does make sense!)
-------------------------------------------------------------------------------
-- About 'outer_size':
-- Its meaning needs to differ slightly depending on if we are using ScrollX/ScrollY flags.
-- Default value is ImVec2(0.0, 0.0).
--   X
--   - outer_size.x <= 0.0  ->  Right-align from window/work-rect right-most edge. With -FLT_MIN or 0.0 will align exactly on right-most edge.
--   - outer_size.x  > 0.0  ->  Set Fixed width.
--   Y with ScrollX/ScrollY disabled: we output table directly in current window
--   - outer_size.y  < 0.0  ->  Bottom-align (but will auto extend, unless _NoHostExtendY is set). Not meaningful if parent window can vertically scroll.
--   - outer_size.y  = 0.0  ->  No minimum height (but will auto extend, unless _NoHostExtendY is set)
--   - outer_size.y  > 0.0  ->  Set Minimum height (but will auto extend, unless _NoHostExtendY is set)
--   Y with ScrollX/ScrollY enabled: using a child window for scrolling
--   - outer_size.y  < 0.0  ->  Bottom-align. Not meaningful if parent window can vertically scroll.
--   - outer_size.y  = 0.0  ->  Bottom-align, consistent with BeginChild(). Not recommended unless table is last item in parent window.
--   - outer_size.y  > 0.0  ->  Set Exact height. Recommended when using Scrolling on any axis.
-------------------------------------------------------------------------------
-- Outer size is also affected by the NoHostExtendX/NoHostExtendY flags.
-- Important to note how the two flags have slightly different behaviors!
--   - ImGuiTableFlags.NoHostExtendX -> Make outer width auto-fit to columns (overriding outer_size.x value). Only available when ScrollX/ScrollY are disabled and Stretch columns are not used.
--   - ImGuiTableFlags.NoHostExtendY -> Make outer height stop exactly at outer_size.y (prevent auto-extending table past the limit). Only available when ScrollX/ScrollY is disabled. Data below the limit will be clipped and not visible.
-- In theory ImGuiTableFlags.NoHostExtendY could be the default and any non-scrolling tables with outer_size.y ~= 0.0 would use exact height.
-- This would be consistent but perhaps less useful and more confusing (as vertically clipped items are not useful and not easily noticeable).
-------------------------------------------------------------------------------
-- About 'inner_width':
--   With ScrollX disabled:
--   - inner_width          ->  *ignored*
--   With ScrollX enabled:
--   - inner_width  < 0.0  ->  *illegal* fit in known width (right align from outer_size.x) <-- weird
--   - inner_width  = 0.0  ->  fit in outer_width: Fixed size columns will take space they need (if avail, otherwise shrink down), Stretch columns becomes Fixed columns.
--   - inner_width  > 0.0  ->  override scrolling width, generally to be larger than outer_size.x. Fixed column take space they need (if avail, otherwise shrink down), Stretch columns share remaining space!
-------------------------------------------------------------------------------
-- Details:
-- - If you want to use Stretch columns with ScrollX, you generally need to specify 'inner_width' otherwise the concept
--   of "available space" doesn't make sense.
-- - Even if not really useful, we allow 'inner_width < outer_size.x' for consistency and to facilitate understanding
--   of what the value does.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- COLUMNS SIZING POLICIES
-- (Reference: ImGuiTableFlags.SizingXXX flags and ImGuiTableColumnFlags.WidthXXX flags)
-------------------------------------------------------------------------------
-- About overriding column sizing policy and width/weight with TableSetupColumn():
-- We use a default parameter of -1 for 'init_width'/'init_weight'.
--   - with ImGuiTableColumnFlags.WidthFixed,    init_width  <= 0 (default)  --> width is automatic
--   - with ImGuiTableColumnFlags.WidthFixed,    init_width  >  0 (explicit) --> width is custom
--   - with ImGuiTableColumnFlags.WidthStretch,  init_weight <= 0 (default)  --> weight is 1.0
--   - with ImGuiTableColumnFlags.WidthStretch,  init_weight >  0 (explicit) --> weight is custom
-- Widths are specified _without_ CellPadding. If you specify a width of 100.0, the column will be cover (100.0 + Padding * 2.0)
-- and you can fit a 100.0 wide item in it without clipping and with padding honored.
-------------------------------------------------------------------------------
-- About default sizing policy (if you don't specify a ImGuiTableColumnFlags.WidthXXXX flag)
--   - with Table policy ImGuiTableFlags.SizingFixedFit      --> default Column policy is ImGuiTableColumnFlags.WidthFixed, default Width is equal to contents width
--   - with Table policy ImGuiTableFlags.SizingFixedSame     --> default Column policy is ImGuiTableColumnFlags.WidthFixed, default Width is max of all contents width
--   - with Table policy ImGuiTableFlags.SizingStretchSame   --> default Column policy is ImGuiTableColumnFlags.WidthStretch, default Weight is 1.0
--   - with Table policy ImGuiTableFlags.SizingStretchWeight --> default Column policy is ImGuiTableColumnFlags.WidthStretch, default Weight is proportional to contents
-- Default Width and default Weight can be overridden when calling TableSetupColumn().
-------------------------------------------------------------------------------
-- About mixing Fixed/Auto and Stretch columns together:
--   - the typical use of mixing sizing policies is: any number of LEADING Fixed columns, followed by one or two TRAILING Stretch columns.
--   - using mixed policies with ScrollX does not make much sense, as using Stretch columns with ScrollX does not make much sense in the first place!
--     that is, unless 'inner_width' is passed to BeginTable() to explicitly provide a total width to layout columns in.
--   - when using ImGuiTableFlags.SizingFixedSame with mixed columns, only the Fixed/Auto columns will match their widths to the width of the maximum contents.
--   - when using ImGuiTableFlags.SizingStretchSame with mixed columns, only the Stretch columns will match their weights/widths.
-------------------------------------------------------------------------------
-- About using column width:
-- If a column is manually resizable or has a width specified with TableSetupColumn():
--   - you may use GetContentRegionAvail().x to query the width available in a given column.
--   - right-side alignment features such as SetNextItemWidth(-x) or PushItemWidth(-x) will rely on this width.
-- If the column is not resizable and has no width specified with TableSetupColumn():
--   - its width will be automatic and be set to the max of items submitted.
--   - therefore you generally cannot have ALL items of the columns use e.g. SetNextItemWidth(-FLT_MIN).
--   - but if the column has one or more items of known/fixed size, this will become the reference width used by SetNextItemWidth(-FLT_MIN).
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- TABLES CLIPPING/CULLING
-------------------------------------------------------------------------------
-- About clipping/culling of Rows in Tables:
-- - For large numbers of rows, it is recommended you use ImGuiListClipper to submit only visible rows.
--   ImGuiListClipper is reliant on the fact that rows are of equal height.
--   See 'Demo->Tables->Vertical Scrolling' or 'Demo->Tables->Advanced' for a demo of using the clipper.
-- - Note that auto-resizing columns don't play well with using the clipper.
--   By default a table with _ScrollX but without _Resizable will have column auto-resize.
--   So, if you want to use the clipper, make sure to either enable _Resizable, either setup columns width explicitly with _WidthFixed.
-------------------------------------------------------------------------------
-- About clipping/culling of Columns in Tables:
-- - Both TableSetColumnIndex() and TableNextColumn() return true when the column is visible or performing
--   width measurements. Otherwise, you may skip submitting the contents of a cell/column, BUT ONLY if you know
--   it is not going to contribute to row height.
--   In many situations, you may skip submitting contents for every column but one (e.g. the first one).
-- - Case A: column is not hidden by user, and at least partially in sight (most common case).
-- - Case B: column is clipped / out of sight (because of scrolling or parent ClipRect): TableNextColumn() return false as a hint but we still allow layout output.
-- - Case C: column is hidden explicitly by the user (e.g. via the context menu, or _DefaultHide column flag, etc.).
--
--                        [A]         [B]          [C]
--  TableNextColumn():    true        false        false       -> [userland] when TableNextColumn() / TableSetColumnIndex() returns false, user can skip submitting items but only if the column doesn't contribute to row height.
--          SkipItems:    false       false        true        -> [internal] when SkipItems is true, most widgets will early out if submitted, resulting is no layout output.
--           ClipRect:    normal      zero-width   zero-width  -> [internal] when ClipRect is zero, ItemAdd() will return false and most widgets will early out mid-way.
--  ImDrawList output:    normal      dummy        dummy       -> [internal] when using the dummy channel, ImDrawList submissions (if any) will be wasted (because cliprect is zero-width anyway).
--
-- - We need to distinguish those cases because non-hidden columns that are clipped outside of scrolling bounds should still contribute their height to the row.
--   However, in the majority of cases, the contribution to row height is the same for all columns, or the tallest cells are known by the programmer.
-------------------------------------------------------------------------------
-- About clipping/culling of whole Tables:
-- - Scrolling tables with a known outer size can be clipped earlier as BeginTable() will return false.
-------------------------------------------------------------------------------

-- [Port] Port notes:
-- [Port] - Column indices / display orders / draw channel indices are 0-based VALUES like upstream.
-- [Port]   Per-column arrays (table.Columns, table.DisplayOrderToIndex, table.RowCellData) are Lua tables with 0-based keys.
-- [Port]   table.ColumnsSize mirrors upstream `table->Columns.size()`.
-- [Port] - ImBitArray masks are Lua tables { [n] = true }.
-- [Port] - table.ColumnsNames is a Lua array of strings, column.NameOffset is a 0-based index into it (-1 = none).
-- [Port] - g.SettingsTables is a plain vector of ImGuiTableSettings; table.SettingsOffset is a 1-based index into it (-1 = none).
-- [Port]   Each settings entry owns `Columns` (0-based Lua table of ImGuiTableColumnSettings).
-- [Port] - ImGuiTableSortSpecs.Specs is a 1-based Lua array of ImGuiTableColumnSortSpecs.

--- @type ImGuiContext?
local GImGui

local MT = ImGui.GetMetatables()

-- [Port] Sets local `GImGui` in this file(imgui_tables.lua).
-- This is currently only used in main code `ImGui.SetCurrentContext()`
--- @param ctx ImGuiContext?
function ImGui._SetCurrentContext_Tables(ctx)
    GImGui = ctx
end

local bit32 = bit32
local band, bor, bnot, lshift, rshift = bit32.band, bit32.bor, bit32.bnot, bit32.lshift, bit32.rshift
local mathMax, mathMin = math.max, math.min -- [Luau] scalar ImMax()/ImMin() in table code are written as mathMax()/mathMin() (no call through the vector-aware helper)

IM_COL32_DISABLE = IM_COL32(0, 0, 0, 1) -- Special sentinel code which cannot be used as a regular color.
IMGUI_TABLE_MAX_COLUMNS = 512 -- Arbitrary "safety" maximum, may be lifted in the future if needed. Must fit in ImGuiTableColumnIdx/ImGuiTableDrawChannelIdx.

local function IMGUI_DEBUG_LOG_TABLE(fmt, ...)
    local g = GImGui
    if band(g.DebugLogFlags, ImGuiDebugLogFlags.EventTable) ~= 0 then ImGui.DebugLog(fmt, ...) end
end

-------------------------------------------------------------------------------
-- [SECTION] Structs
-------------------------------------------------------------------------------

local function BitArrayClearAll(arr) table.clear(arr) end
local function BitArraySet(arr, n) arr[n] = true end
local function BitTest(arr, n) return arr[n] == true end

-- Sorting specification for one column of a table
--- @class ImGuiTableColumnSortSpecs
function ImGuiTableColumnSortSpecs()
    return { ColumnUserID = 0, ColumnIndex = 0, SortOrder = 0, SortDirection = ImGuiSortDirection.None }
end

-- Sorting specifications for a table (often handling sort specs for a single column, occasionally more)
-- Obtained by calling TableGetSortSpecs().
-- When 'SpecsDirty == true' you can sort your data. It will be true with sorting specs have changed since last call, or the first time.
-- Make sure to set 'SpecsDirty = false' after sorting, else you may wastefully sort your data every frame!
--- @class ImGuiTableSortSpecs
function ImGuiTableSortSpecs()
    return { Specs = nil, SpecsCount = 0, SpecsDirty = false }
end

-- We use the terminology "Enabled" to refer to a column that is not Hidden by user/api.
-- We use the terminology "Clipped" to refer to a column that is out of sight because of scrolling/clipping.
-- This is in contrast with some user-facing api such as IsItemVisible() / IsRectVisible() which use "Visible" to mean "not clipped".
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

-- Per-instance data that needs preserving across frames (seemingly most others do not need to be preserved aside from debug needs. Does that means they could be moved to ImGuiTableTempData?)
--- @class ImGuiTableInstanceData
function ImGuiTableInstanceData()
    return { TableInstanceID = 0, LastOuterHeight = 0.0, LastTopHeadersRowHeight = 0.0, LastFrozenHeight = 0.0, HoveredRowLast = -1, HoveredRowNext = -1 }
end

-- Transient data that are only needed between BeginTable() and EndTable(), those buffers are shared (1 per level of stacked table).
-- - Accessing those requires chasing an extra pointer so for very frequently used data we leave them in the main table structure.
-- - We also leave out of this structure data that tend to be particularly useful for debugging/metrics.
-- FIXME-TABLE: more transient data could be stored in a stacked ImGuiTableTempData: e.g. SortSpecs.
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

-- Storage for a table
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

-- Storage for a table .ini settings
--- @class ImGuiTableSettings
MT.ImGuiTableSettings = {}
MT.ImGuiTableSettings.__index = MT.ImGuiTableSettings
function ImGuiTableSettings()
    return setmetatable({ ID = 0, SaveFlags = 0, RefScale = 0.0, ColumnsCount = 0, ColumnsCountMax = 0, LastUsedDate = 0, WantApply = false, Columns = {} }, MT.ImGuiTableSettings)
end
-- [Luau] column settings are stored in a 0-based .Columns table (upstream: allocated right after the struct)
function MT.ImGuiTableSettings:GetColumnSettings() return self.Columns end

-- Storage data for a single column for legacy Columns() api
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

ImGuiTableColumnFlags.NoDirectResize_ = ImGuiTableColumnFlags.NoDirectResize_ or lshift(1, 30) -- [Internal] Disable user resizing this column directly (it may however we resized indirectly from its left edge)

local function Rect(r) return ImRect(r.Min.x, r.Min.y, r.Max.x, r.Max.y) end
local function V2(v) return ImVec2(v.x, v.y) end

-------------------------------------------------------------------------------
-- [SECTION] Tables: Main code
-------------------------------------------------------------------------------
-- - TableFixFlags() [Internal]
-- - TableFindByID() [Internal]
-- - BeginTable()
-- - BeginTableEx() [Internal]
-- - TableBeginInitMemory() [Internal]
-- - TableApplyQueuedRequests() [Internal]
-- - TableSetupColumnFlags() [Internal]
-- - TableUpdateLayout() [Internal]
-- - TableUpdateBorders() [Internal]
-- - EndTable()
-- - TableSetupColumn()
-- - TableSetupScrollFreeze()
-------------------------------------------------------------------------------

-- Configuration
local TABLE_DRAW_CHANNEL_BG0 = 0
local TABLE_DRAW_CHANNEL_BG2_FROZEN = 1
local TABLE_DRAW_CHANNEL_NOCLIP = 2                    -- When using ImGuiTableFlags.NoClip (this becomes the last visible channel)
local TABLE_BORDER_SIZE = 1.0                          -- FIXME-TABLE: Currently hard-coded because of clipping assumptions with outer borders rendering.
local TABLE_RESIZE_SEPARATOR_HALF_THICKNESS = 4.0      -- Extend outside inner borders.
local TABLE_RESIZE_SEPARATOR_FEEDBACK_TIMER = 0.06     -- Delay/timer before making the hover feedback (color+cursor) visible because tables/columns tends to be more cramped.

-- Helper
local function TableFixFlags(flags, outer_window)
    -- Adjust flags: set default sizing policy
    if band(flags, ImGuiTableFlags.SizingMask_) == 0 then
        flags = bor(flags, (band(flags, ImGuiTableFlags.ScrollX) ~= 0 or band(outer_window.Flags, ImGuiWindowFlags.AlwaysAutoResize) ~= 0) and ImGuiTableFlags.SizingFixedFit or ImGuiTableFlags.SizingStretchSame)
    end

    -- Adjust flags: enable NoKeepColumnsVisible when using ImGuiTableFlags.SizingFixedSame
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
    -- FIXME: coarse clipping because access to table data causes two issues:
    -- - instance numbers varying/unstable. may not be a direct problem for users, but could make outside access broken or confusing, e.g. TestEngine.
    -- - can't implement support for ImGuiChildFlags.ResizeY as we need to somehow pull the height data from somewhere. this also needs stable instance numbers.
    -- The side-effects of accessing table data on coarse clip would be:
    -- - always reserving the pooled ImGuiTable data ahead for a fully clipped table (minor IMHO). Also the 'outer_window_is_measuring_size' criteria may already be defeating this in some situations.
    -- - always performing the GetOrAddByKey() O(log N) query in g.Tables.Map[].
    local use_child_window = band(flags, bor(ImGuiTableFlags.ScrollX, ImGuiTableFlags.ScrollY)) ~= 0
    local avail_size = ImGui.GetContentRegionAvail()
    local actual_outer_size = ImTrunc(ImGui.CalcItemSize(outer_size, mathMax(avail_size.x, IMGUI_WINDOW_HARD_MIN_SIZE), use_child_window and mathMax(avail_size.y, IMGUI_WINDOW_HARD_MIN_SIZE) or 0.0))
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
    if table_.Columns == nil then -- [Port] pool created a plain table
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
    temp_data.ReconcileColumnsRequests:resize(0) -- FIXME: Use shrink(0) everywhere?
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
        -- (we have no other way to disable vertical scrollbar of a window while keeping the horizontal one showing)
        local override_content_size = ImVec2(FLT_MAX, FLT_MAX)
        if band(flags, ImGuiTableFlags.ScrollX) ~= 0 and band(flags, ImGuiTableFlags.ScrollY) == 0 then
            override_content_size.y = FLT_MIN
        end

        -- Ensure specified width (when not specified, Stretched columns will act as if the width == OuterWidth and
        -- never lead to any scrolling). We don't handle inner_width < 0.0, we could potentially use it to right-align
        -- based on the right side of the child window work rect, which would require knowing ahead if we are going to
        -- have decoration taking horizontal spaces (typically a vertical scrollbar).
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
        -- But at this point we do NOT have a correct value for .Max.y (unless a height has been explicitly passed in). It will only be updated in EndTable().
        ImRect_Copy(table_.WorkRect, outer_rect)
        ImRect_Copy(table_.OuterRect, outer_rect)
        ImRect_Copy(table_.InnerRect, outer_rect)
        table_.HasScrollbarYPrev = false
        table_.HasScrollbarYCurr = false
        table_.InnerWindow.DC.TreeDepth = table_.InnerWindow.DC.TreeDepth + 1 -- This is designed to always linking ImGuiTreeNodeFlags.DrawLines linking across a table
    end

    -- Push a standardized ID for both child-using and not-child-using tables
    ImGui.PushOverrideID(id)
    if instance_no > 0 then
        ImGui.PushOverrideID(instance_id) -- FIXME: Somehow this is not resolved by stack-tool, even tho GetIDWithSeed() submitted the symbol.
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
    -- (we normally shouldn't alter HostClipRect as we rely on TableMergeDrawChannels() expanding non-clipped column toward the
    -- limits of that rectangle, in order for ImDrawListSplitter::Merge() to merge the draw commands. However since the overlap
    -- problem only affect scrolling tables in this case we can get away with doing it without extra cost).
    if inner_window ~= outer_window then
        -- FIXME: Because inner_window's Scrollbar doesn't know about border size, since it's not encoded in window.WindowBorderSize,
        -- it already overlaps it and doesn't need an extra offset. Ideally we should be able to pass custom border size with
        -- different x/y values to BeginChild().
        local border_size = TABLE_BORDER_SIZE
        if band(flags, ImGuiTableFlags.BordersOuterV) ~= 0 then
            table_.HostClipRect.Min.x = mathMin(table_.HostClipRect.Min.x + border_size, table_.HostClipRect.Max.x)
            if inner_window.DecoOuterSizeX2 == 0.0 then
                table_.HostClipRect.Max.x = mathMax(table_.HostClipRect.Max.x - border_size, table_.HostClipRect.Min.x)
            end
        end
        if band(flags, ImGuiTableFlags.BordersOuterH) ~= 0 then
            table_.HostClipRect.Min.y = mathMin(table_.HostClipRect.Min.y + border_size, table_.HostClipRect.Max.y)
            if inner_window.DecoOuterSizeY2 == 0.0 then
                table_.HostClipRect.Max.y = mathMax(table_.HostClipRect.Max.y - border_size, table_.HostClipRect.Min.y)
            end
        end
    end

    -- Padding and Spacing
    -- - None               ........Content..... Pad .....Content........
    -- - PadOuter           | Pad ..Content..... Pad .....Content.. Pad |
    -- - PadInner           ........Content.. Pad | Pad ..Content........
    -- - PadOuter+PadInner  | Pad ..Content.. Pad | Pad ..Content.. Pad |
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
    table_.InnerClipRect.Max.y = (band(flags, ImGuiTableFlags.NoHostExtendY) ~= 0) and mathMin(table_.InnerClipRect.Max.y, inner_window.WorkRect.Max.y) or table_.HostClipRect.Max.y

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
    -- This is not strictly necessary but will reduce cases were "out of table" output will be misleading to the user.
    -- Because we cannot safely assert in EndTable() when no rows have been created, this seems like our best option.
    inner_window.SkipItems = true

    -- Clear names
    -- At this point the .NameOffset field of each column will be invalid until TableUpdateLayout() or the first call to TableSetupColumn()
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
    -- (We process this in the TableBegin() of the first instance of each table)
    -- FIXME-TABLE: Contains columns if our work area doesn't allow for scrolling?
    if table_.InstanceCurrent == 0 then
        if table_.ResizedColumn ~= -1 and table_.ResizedColumnNextWidth ~= FLT_MAX then
            ImGui.TableSetColumnWidth(table_.ResizedColumn, table_.ResizedColumnNextWidth)
        end
        table_.LastResizedColumn = table_.ResizedColumn
        table_.ResizedColumnNextWidth = FLT_MAX
        table_.ResizedColumn = -1

        -- Process auto-fit for single column, which is a special case for stretch columns and fixed columns with FixedSame policy.
        -- FIXME-TABLE: Would be nice to redistribute available stretch space accordingly to other weights, instead of giving it all to siblings.
        if table_.AutoFitSingleColumn ~= -1 then
            ImGui.TableSetColumnWidth(table_.AutoFitSingleColumn, table_.Columns[table_.AutoFitSingleColumn].WidthAuto)
            table_.AutoFitSingleColumn = -1
        end
    end

    -- Handle reordering request
    -- Note: we don't clear ReorderColumn after handling the request (FIXME: clarify why or add a test).
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
        --if (table.HeldHeaderColumn == -1 and table.ReorderColumn ~= -1)
        --    table.ReorderColumn = -1
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
    --IM_ASSERT(dst_column.DisplayOrder == dst_order - reorder_dir)

    -- Display order is stored in both columns.IndexDisplayOrder and table.DisplayOrder[]. Rebuild later from the former.
    -- FIXME-OPT: If this is called multiple times we'd effectively have a O(N^2) thing going on.
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
    -- TableSetupScrollFreeze() enforce a display order range for frozen columns. Reordering across the frozen column barrier is illegal and will be undone.
    if table_.FreezeColumnsRequest > 0 then
        dst_order = (src_order < table_.FreezeColumnsRequest) and ImMin(dst_order, table_.FreezeColumnsRequest - 1) or ImMax(dst_order, table_.FreezeColumnsRequest)
    end

    -- Cannot cross over a column with the ImGuiTableColumnFlags.NoReorder flag.
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

    -- Alignment
    --if (flags & ImGuiTableColumnFlags.AlignMask_) == 0 then
    --    flags = bor(flags, ImGuiTableColumnFlags.AlignCenter)
    --IM_ASSERT(ImIsPowerOfTwo(flags & ImGuiTableColumnFlags.AlignMask_)) -- Check that only 1 of each set is used.

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
-- FIXME-TABLE: Our width (and therefore our WorkRect) will be minimal in the first frame for _WidthAuto columns.
-- Increase feedback side-effect with widgets relying on WorkRect.Max.x... Maybe provide a default distribution for _WidthAuto columns?
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
    -- This is designed to facilitate DPI changes with the assumption that e.g. style.CellPadding has been scaled as well.
    -- It will also react to changing fonts with mixed results. It doesn't need to be perfect but merely provide a decent transition.
    -- FIXME-DPI: Provide consistent standards for reference size. Perhaps using g.CurrentDpiScale would be more self explanatory.
    -- This is will lead us to non-rounded WidthRequest in columns, which should work but is a poorly tested path.
    local new_ref_scale_unit = g.FontSize -- g.Font.GetCharAdvance('A') ?
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
    table_.MinColumnWidth = mathMax(1.0, g.Style.FramePadding.x * 1.0) -- g.Style.ColumnsMinSpacing -- FIXME-TABLE

    -- [Part 1] Apply/lock Enabled and Order states. Calculate auto/ideal width for columns. Count fixed/stretch columns.
    -- Process columns in their visible orders as we are building the Prev/Next indices.
    local count_fixed = 0                -- Number of columns that have fixed sizing policies
    local count_stretch = 0              -- Number of columns that have stretch sizing policies
    local prev_visible_column_idx = -1
    local has_auto_fit_request = false
    local has_resizable = false
    local stretch_sum_width_auto = 0.0
    local fixed_max_width_auto = 0.0
    for order_n = 0, columns_count - 1 do
        local column_n = table_.DisplayOrderToIndex[order_n]
        local column = table_.Columns[column_n]

        -- Clear column setup if not submitted by user. Currently we make it mandatory to call TableSetupColumn() every frame.
        -- It would easily work without but we're not ready to guarantee it since e.g. names need resubmission anyway.
        -- We take a slight shortcut but in theory we could be calling TableSetupColumn() here with dummy values, it should yield the same effect.
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
            -- Combine width from regular rows + width from headers unless requested not to.
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
                fixed_max_width_auto = mathMax(fixed_max_width_auto, column.WidthAuto)
                count_fixed = count_fixed + 1
            end
        end
    end
    if band(table_.Flags, ImGuiTableFlags.Sortable) ~= 0 and table_.SortSpecsCount == 0 and band(table_.Flags, ImGuiTableFlags.SortTristate) == 0 then
        table_.IsSortSpecsDirty = true
    end
    table_.RightMostEnabledColumn = prev_visible_column_idx
    IM_ASSERT(table_.LeftMostEnabledColumn >= 0 and table_.RightMostEnabledColumn >= 0)

    -- [Part 2] Disable child window clipping while fitting columns. This is not strictly necessary but makes it possible to avoid
    -- the column fitting having to wait until the first visible frame of the child container (may or not be a good thing). Also see #6510.
    -- FIXME-TABLE: for always auto-resizing columns may not want to do that all the time.
    if has_auto_fit_request and table_.OuterWindow ~= table_.InnerWindow then
        table_.InnerWindow.SkipItems = false
    end
    if has_auto_fit_request then
        table_.IsSettingsDirty = true
    end

    -- [Part 3] Fix column flags and record a few extra information.
    local sum_width_requests = 0.0    -- Sum of all width for fixed and auto-resize columns, excluding width contributed by Stretch columns but including spacing/padding.
    local stretch_sum_weights = 0.0   -- Sum of all weights for stretch columns.
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
                -- Latch initial size for fixed columns and update it constantly for auto-resizing column (unless clipped!)
                if column.AutoFitQueue ~= 0x00 then
                    column.WidthRequest = width_auto
                elseif band(column.Flags, ImGuiTableColumnFlags.WidthFixed) ~= 0 and not column_is_resizable and column.IsRequestOutput then
                    column.WidthRequest = width_auto
                end

                -- FIXME-TABLE: Increase minimum size during init frame to avoid biasing auto-fitting widgets
                -- (e.g. TextWrapped) too much. Otherwise what tends to happen is that TextWrapped would output a very
                -- large height (= first frame scrollbar display very off + clipper would skip lots of items).
                -- This is merely making the side-effect less extreme, but doesn't properly fixes it.
                -- FIXME: Move this to .WidthGiven to avoid temporary lossyness?
                -- FIXME: This break IsPreserveWidthAuto from not flickering if the stored WidthAuto was smaller.
                if column.AutoFitQueue > 0x01 and table_.IsInitializing and not column.IsPreserveWidthAuto then
                    column.WidthRequest = mathMax(column.WidthRequest, table_.MinColumnWidth * 4.0) -- FIXME-TABLE: Another constant/scale?
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
    local width_avail = mathMax(1.0, ((band(table_.Flags, ImGuiTableFlags.ScrollX) ~= 0 and table_.InnerWidth == 0.0) and table_.InnerClipRect:GetWidth() or work_rect:GetWidth()) - width_removed)
    local width_avail_for_stretched_columns = width_avail - width_spacings - sum_width_requests
    local width_remaining_for_stretched_columns = width_avail_for_stretched_columns
    table_.ColumnsGivenWidth = width_spacings + (table_.CellPaddingX * 2.0) * table_.ColumnsEnabledCount
    for column_n = 0, columns_count - 1 do
        if BitTest(table_.EnabledMaskByIndex, column_n) then
            local column = table_.Columns[column_n]

            -- Allocate width for stretched/weighted columns (StretchWeight gets converted into WidthRequest)
            if band(column.Flags, ImGuiTableColumnFlags.WidthStretch) ~= 0 then
                local weight_ratio = column.StretchWeight / stretch_sum_weights
                column.WidthRequest = IM_TRUNC(mathMax(width_avail_for_stretched_columns * weight_ratio, table_.MinColumnWidth) + 0.01)
                width_remaining_for_stretched_columns = width_remaining_for_stretched_columns - column.WidthRequest
            end

            -- [Resize Rule 1] The right-most Visible column is not resizable if there is at least one Stretch column
            -- See additional comments in TableSetColumnWidth().
            if column.NextEnabledColumn == -1 and table_.LeftMostStretchedColumn ~= -1 then
                column.Flags = bor(column.Flags, ImGuiTableColumnFlags.NoDirectResize_)
            end

            -- Assign final width, record width in case we will need to shrink
            column.WidthGiven = ImTrunc(mathMax(column.WidthRequest, table_.MinColumnWidth))
            table_.ColumnsGivenWidth = table_.ColumnsGivenWidth + column.WidthGiven
        end
    end

    -- [Part 5] Redistribute stretch remainder width due to rounding (remainder width is < 1.0 * number of Stretch column).
    -- Using right-to-left distribution (more likely to match resizing cursor).
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
    -- - In principle we'd like to use the equivalent of IsItemHovered(ImGuiHoveredFlags.AllowWhenBlockedByActiveItem),
    --   but because our item is partially submitted at this point we use ItemHoverable() and a workaround (temporarily
    --   clear ActiveId, which is equivalent to the change provided by _AllowWhenBLockedByActiveItem).
    -- - This allows columns to be marked as hovered when e.g. clicking a button inside the column, or using drag and drop.
    local table_instance = ImGui.TableGetInstanceData(table_, table_.InstanceCurrent)
    table_instance.HoveredRowLast = table_instance.HoveredRowNext
    table_instance.HoveredRowNext = -1
    table_.HoveredColumnBody = -1; table_.HoveredColumnBorder = -1
    local mouse_hit_rect = ImRect(table_.OuterRect.Min.x, table_.OuterRect.Min.y, table_.OuterRect.Max.x, mathMax(table_.OuterRect.Max.y, table_.OuterRect.Min.y + table_instance.LastOuterHeight))
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
    -- Process columns in their visible orders as we are comparing the visible order and adjusting host_clip_rect while looping.
    local has_at_least_one_column_requesting_output = false
    local offset_x_frozen = (table_.FreezeColumnsCount > 0)
    local offset_x = ((table_.FreezeColumnsCount > 0) and table_.OuterRect.Min.x or work_rect.Min.x) + table_.OuterPaddingX - table_.CellSpacingX1
    local host_clip_rect = Rect(table_.InnerClipRect)
    --host_clip_rect.Max.x += table.CellPaddingX + table.CellSpacingX2
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
            -- We set a zero-width clip rect but set Min.y/Max.y properly to not interfere with the clipper.
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
            column.WidthGiven = mathMin(column.WidthGiven, column.WidthMax)
            column.WidthGiven = mathMax(column.WidthGiven, mathMin(column.WidthRequest, table_.MinColumnWidth))
            column.MaxX = offset_x + column.WidthGiven + table_.CellSpacingX1 + table_.CellSpacingX2 + table_.CellPaddingX * 2.0

            -- Lock other positions
            -- - ClipRect.Min.x: Because merging draw commands doesn't compare min boundaries, we make ClipRect.Min.x match left bounds to be consistent regardless of merging.
            -- - ClipRect.Max.x: using WorkMaxX instead of MaxX (aka including padding) makes things more consistent when resizing down, tho slightly detrimental to visibility in very-small column.
            -- - ClipRect.Max.x: using MaxX makes it easier for header to receive hover highlight with no discontinuity and display sorting arrow.
            -- - FIXME-TABLE: We want equal width columns to have equal (ClipRect.Max.x - WorkMinX) width, which means ClipRect.max.x cannot stray off host_clip_rect.Max.x else right-most column may appear shorter.
            local previous_instance_work_min_x = column.WorkMinX
            column.WorkMinX = column.MinX + table_.CellPaddingX + table_.CellSpacingX1
            column.WorkMaxX = column.MaxX - table_.CellPaddingX - table_.CellSpacingX2 -- Expected max
            column.ItemWidth = ImTrunc(column.WidthGiven * 0.65)
            column.ClipRect.Min.x = column.MinX
            column.ClipRect.Min.y = work_rect.Min.y
            column.ClipRect.Max.x = column.MaxX --column.WorkMaxX
            column.ClipRect.Max.y = FLT_MAX
            column.ClipRect:ClipWithFull(host_clip_rect)

            -- Mark column as Clipped (not in sight)
            -- Note that scrolling tables (where inner_window ~= outer_window) handle Y clipped earlier in BeginTable() so IsVisibleY really only applies to non-scrolling tables.
            -- FIXME-TABLE: Because InnerClipRect.Max.y is conservatively ==outer_window.ClipRect.Max.y, we never can mark columns _Above_ the scroll line as not IsVisibleY.
            -- Taking advantage of LastOuterHeight would yield good results there...
            -- FIXME-TABLE: Y clipping is disabled because it effectively means not submitting will reduce contents width which is fed to outer_window.DC.CursorMaxPos.x,
            -- and this may be used (e.g. typically by outer_window using AlwaysAutoResize or outer_window's horizontal scrollbar, but could be something else).
            -- Possible solution to preserve last known content width for clipped column. Test 'table_reported_size' fails when enabling Y clipping and window is resized small.
            column.IsVisibleX = (column.ClipRect.Max.x > column.ClipRect.Min.x)
            column.IsVisibleY = true -- (column.ClipRect.Max.y > column.ClipRect.Min.y)
            local is_visible = column.IsVisibleX --and column.IsVisibleY
            if is_visible then
                BitArraySet(table_.VisibleMaskByIndex, column_n)
            end

            -- Mark column as requesting output from user. Note that fixed + non-resizable sets are auto-fitting at all times and therefore always request output.
            column.IsRequestOutput = is_visible or column.AutoFitQueue ~= 0 or column.CannotSkipItemsQueue ~= 0

            -- Mark column as SkipItems (ignoring all items/layout)
            -- (table.HostSkipItems is a copy of inner_window.SkipItems before we cleared it above in Part 2)
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

            -- Alignment
            -- FIXME-TABLE: This align based on the whole column width, not per-cell, and therefore isn't useful in
            -- many cases (to be able to honor this we might be able to store a log of cells width, per row, for
            -- visible rows, but nav/programmatic scroll would have visible artifacts.)
            --if (column.Flags & ImGuiTableColumnFlags.AlignRight)
            --    column.WorkMinX = ImMax(column.WorkMinX, column.MaxX - column.ContentWidthRowsUnfrozen)
            --else if (column.Flags & ImGuiTableColumnFlags.AlignCenter)
            --    column.WorkMinX = ImLerp(column.WorkMinX, ImMax(column.StartX, column.MaxX - column.ContentWidthRowsUnfrozen), 0.5)

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
    -- Else if give no chance to a clipper-savvy user to submit rows and therefore total contents height used by scrollbar.
    if has_at_least_one_column_requesting_output == false then
        table_.Columns[table_.LeftMostEnabledColumn].IsRequestOutput = true
        table_.Columns[table_.LeftMostEnabledColumn].IsSkipItems = false
    end

    -- [Part 7] Detect/store when we are hovering the unused space after the right-most column (so e.g. context menus can react on it)
    -- Clear Resizable flag if none of our column are actually resizable (either via an explicit _NoResize flag, either
    -- because of using _WidthAuto/_WidthStretch). This will hide the resizing option from the context menu.
    local unused_x1 = mathMax(table_.WorkRect.Min.x, table_.Columns[table_.RightMostEnabledColumn].ClipRect.Max.x)
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
    -- This is done late to handle the case of fixed-columns tables not claiming more widths that they need.
    -- Because of this we are careful with uses of WorkRect and InnerClipRect before this point.
    if table_.RightMostStretchedColumn ~= -1 then
        table_.Flags = band(table_.Flags, bnot(ImGuiTableFlags.NoHostExtendX))
    end
    if band(table_.Flags, ImGuiTableFlags.NoHostExtendX) ~= 0 then
        table_.OuterRect.Max.x = unused_x1; table_.WorkRect.Max.x = unused_x1
        table_.InnerClipRect.Max.x = mathMin(table_.InnerClipRect.Max.x, unused_x1)
    end
    ImRect_Copy(table_.InnerWindow.ParentWorkRect, table_.WorkRect)
    table_.BorderX1 = table_.InnerClipRect.Min.x
    table_.BorderX2 = table_.InnerClipRect.Max.x

    -- Setup window's WorkRect.Max.y for GetContentRegionAvail(). Other values will be updated in each TableBeginCell() call.
    local window_content_max_y
    if band(table_.Flags, ImGuiTableFlags.NoHostExtendY) ~= 0 then
        window_content_max_y = table_.OuterRect.Max.y
    else
        window_content_max_y = mathMax(table_.InnerWindow.ContentRegionRect.Max.y, (band(table_.Flags, ImGuiTableFlags.ScrollY) ~= 0) and 0.0 or table_.OuterRect.Max.y)
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
    -- - To append to this menu: you can call TableBeginContextMenuPopup()/.../EndPopup().
    -- - To modify or replace this: set table.DisableDefaultContextMenu = true, then call TableBeginContextMenuPopup()/.../EndPopup().
    -- - You may call TableDrawDefaultContextMenu() with selected flags to display specific sections of the default menu,
    --   e.g. TableDrawDefaultContextMenu(table, table.Flags & ~ImGuiTableFlags.Hideable) will display everything EXCEPT columns visibility options.
    if table_.DisableDefaultContextMenu == false and ImGui.TableBeginContextMenuPopup(table_) then
        ImGui.TableDrawDefaultContextMenu(table_, table_.Flags)
        ImGui.EndPopup()
    end

    -- [Part 12] Sanitize and build sort specs before we have a chance to use them for display.
    -- This path will only be exercised when sort specs are modified before header rows (e.g. init or visibility change)
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
    if bs.Window == inner_window and bs.UnclipMode then
        ImGui.TableApplyExternalUnclipRect(table_, bs.UnclipRect)
    end

    -- Initial state
    if band(table_.Flags, ImGuiTableFlags.NoClip) ~= 0 then
        table_.DrawSplitter:SetCurrentChannel(inner_window.DrawList, TABLE_DRAW_CHANNEL_NOCLIP)
    else
        inner_window.DrawList:PushClipRect(inner_window.InnerClipRect.Min, inner_window.InnerClipRect.Max, false) -- FIXME: use table.InnerClipRect?
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
-- - Set table.HoveredColumnBorder with a short delay/timer to reduce visual feedback noise.
function ImGui.TableUpdateBorders(table_)
    local g = GImGui
    IM_ASSERT(band(table_.Flags, ImGuiTableFlags.Resizable) ~= 0)

    -- At this point OuterRect height may be zero or under actual final height, so we rely on temporal coherency and
    -- use the final height from last frame. Because this is only affecting _interaction_ with columns, it is not
    -- really problematic (whereas the actual visual will be displayed in EndTable() and using the current frame height).
    -- Actual columns highlight/render will be performed in EndTable() and not be affected.
    local table_instance = ImGui.TableGetInstanceData(table_, table_.InstanceCurrent)
    local hit_half_width = ImTrunc(TABLE_RESIZE_SEPARATOR_HALF_THICKNESS * g.CurrentDpiScale)
    local hit_y1 = ((table_.FreezeRowsCount >= 1) and table_.OuterRect.Min.y or table_.WorkRect.Min.y) + table_.AngledHeadersHeight
    local hit_y2_body = mathMax(table_.OuterRect.Max.y, hit_y1 + table_instance.LastOuterHeight - table_.AngledHeadersHeight)
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

            -- ImGuiTableFlags.NoBordersInBodyUntilResize will be honored in TableDrawBorders()
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
            --ImGui.GetForegroundDrawList():AddRect(hit_rect.Min, hit_rect.Max, IM_COL32(255, 0, 0, 100))

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

    -- This assert would be very useful to catch a common error... unfortunately it would probably trigger in some
    -- cases, and for consistency user may sometimes output empty tables (and still benefit from e.g. outer border)
    --IM_ASSERT(table.IsLayoutLocked, "Table unused: never called TableNextRow(), is that the intent?")

    -- If the user never got to call TableNextRow() or TableNextColumn(), we call layout ourselves to ensure all our
    -- code paths are consistent (instead of just hoping that TableBegin/TableEnd will work), get borders drawn, etc.
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
    local inner_content_max_y = ImCeil(table_.RowPosY2) -- Rounding final position is important as we currently don't round row height ('Demo->Tables->Outer Size' demo uses non-integer heights)
    IM_ASSERT(table_.RowPosY2 == inner_window.DC.CursorPos.y)
    if inner_window ~= outer_window then
        inner_window.DC.CursorMaxPos.y = inner_content_max_y
    elseif band(flags, ImGuiTableFlags.NoHostExtendY) == 0 then
        local v = mathMax(table_.OuterRect.Max.y, inner_content_max_y) -- Patch OuterRect/InnerRect height
        table_.OuterRect.Max.y = v; table_.InnerRect.Max.y = v
    end
    table_.WorkRect.Max.y = mathMax(table_.WorkRect.Max.y, table_.OuterRect.Max.y)
    table_instance.LastOuterHeight = table_.OuterRect:GetHeight()

    -- Setup inner scrolling range
    -- FIXME: This ideally should be done earlier, in BeginTable() SetNextWindowContentSize call, just like writing to inner_window.DC.CursorMaxPos.y,
    -- but since the later is likely to be impossible to do we'd rather update both axes together.
    if band(table_.Flags, ImGuiTableFlags.ScrollX) ~= 0 then
        local outer_padding_for_border = (band(table_.Flags, ImGuiTableFlags.BordersOuterV) ~= 0) and TABLE_BORDER_SIZE or 0.0
        local max_pos_x = inner_window.DC.CursorMaxPos.x
        if table_.RightMostEnabledColumn ~= -1 then
            max_pos_x = mathMax(max_pos_x, table_.Columns[table_.RightMostEnabledColumn].WorkMaxX + table_.CellPaddingX + table_.OuterPaddingX - outer_padding_for_border)
        end
        if table_.ResizedColumn ~= -1 then
            max_pos_x = mathMax(max_pos_x, table_.ResizeLockMinContentsX2)
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
                auto_fit_width_for_stretched_min = mathMax(auto_fit_width_for_stretched_min, column_width_request / (column.StretchWeight / table_.ColumnsStretchSumWeights))
            end
        end
    end
    local width_spacings = (table_.OuterPaddingX * 2.0) + (table_.CellSpacingX1 + table_.CellSpacingX2) * (table_.ColumnsEnabledCount - 1)
    table_.ColumnsAutoFitWidth = width_spacings + (table_.CellPaddingX * 2.0) * table_.ColumnsEnabledCount + auto_fit_width_for_fixed + mathMax(auto_fit_width_for_stretched, auto_fit_width_for_stretched_min)

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
    -- (FIXME: To allow auto-fit and allow desirable effect of SameLine() we dissociate 'used' vs 'ideal' size by overriding
    -- CursorPosPrevLine and CursorMaxPos manually. That should be a more general layout feature, see same problem e.g. #3414)
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
        -- FIXME-TABLE: Could we remove this section?
        -- ColumnsAutoFitWidth may be one frame ahead here since for Fixed+NoResize is calculated from latest contents
        IM_ASSERT(band(table_.Flags, ImGuiTableFlags.ScrollX) == 0)
        outer_window.DC.CursorMaxPos.x = mathMax(backup_outer_max_pos.x, table_.OuterRect.Min.x + table_.ColumnsAutoFitWidth)
    elseif temp_data.UserOuterSize.x <= 0.0 then
        -- Some references for this: #7651 + tests "table_reported_size", "table_reported_size_outer" equivalent Y block, #9352
        -- - FIXME-TABLE: Would make sense to pre-compute expected scrollbar visibility/sizes to generally save a frame of feedback? See broken test in 'table_reported_size_outer'
        local outer_content_max_x = table_.OuterRect.Min.x + table_.ColumnsAutoFitWidth
        local decoration_size = table_.TempData.AngledHeadersExtraWidth + ((inner_window ~= outer_window) and inner_window.ScrollbarSizes.x or 0.0)
        outer_window.DC.IdealMaxPos.x = mathMax(outer_window.DC.IdealMaxPos.x, outer_content_max_x + decoration_size - temp_data.UserOuterSize.x)
        outer_window.DC.CursorMaxPos.x = mathMax(backup_outer_max_pos.x, mathMin(table_.OuterRect.Max.x, outer_content_max_x + decoration_size))
    else
        outer_window.DC.CursorMaxPos.x = mathMax(backup_outer_max_pos.x, table_.OuterRect.Max.x)
    end
    if temp_data.UserOuterSize.y <= 0.0 then
        -- (same comment as above)
        local outer_content_size_y = (inner_window == outer_window) and (inner_content_max_y - table_.InnerRect.Min.y) or (inner_content_max_y - inner_window.DC.CursorStartPos.y)
        local outer_content_max_y = table_.OuterRect.Min.y + outer_content_size_y
        local decoration_size = (inner_window ~= outer_window) and inner_window.ScrollbarSizes.y or 0.0
        outer_window.DC.IdealMaxPos.y = mathMax(outer_window.DC.IdealMaxPos.y, outer_content_max_y + decoration_size - temp_data.UserOuterSize.y)
        outer_window.DC.CursorMaxPos.y = mathMax(backup_outer_max_pos.y, mathMin(table_.OuterRect.Max.y, outer_content_max_y + decoration_size))
    else
        -- OuterRect.Max.y may already have been pushed downward from the initial value (unless ImGuiTableFlags.NoHostExtendY is set)
        outer_window.DC.CursorMaxPos.y = mathMax(backup_outer_max_pos.y, table_.OuterRect.Max.y)
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
-- If (init_width_or_weight <= 0.0) it is ignored
local function TableSetupColumnApply(table_, idx, id, name_offset, flags, init_width_or_weight, user_data)
    local column = table_.Columns[idx]

    -- Assert when passing a width or weight if policy is entirely left to default, to avoid storing width into weight and vice-versa.
    -- Give a grace to users of ImGuiTableFlags.ScrollX.
    if table_.IsDefaultSizingPolicy and band(flags, ImGuiTableColumnFlags.WidthMask_) == 0 and band(flags, ImGuiTableFlags.ScrollX) == 0 then
        IM_ASSERT_USER_ERROR_RET(init_width_or_weight <= 0.0, "TableSetupColumn(): can only specify width/weight if sizing policy is set explicitly in either Table or Column.")
    end

    -- When passing a width automatically enforce WidthFixed policy
    -- (whereas TableSetupColumnFlags would default to WidthAuto if table is not resizable)
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
    IM_ASSERT_USER_ERROR_RET(table_.IsLayoutLocked == false, "TableSetupColumn(): need to call before first row!") -- Table layout is locked when submitting a row or when calling BeginMultiSelect() with box-select.
    IM_ASSERT(band(flags, ImGuiTableColumnFlags.StatusMask_) == 0, "Illegal to pass StatusMask values to TableSetupColumn()")

    -- Store name
    -- FIXME: If we recorded the number of \n in names we could compute header row height
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
    -- On column count change: search the previous columns:
    -- - the live Columns[] array is truncated on shrink, so a moved column may only exist in old data.
    -- - the live Columns[] array may already be partially reset.
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
    local dst_idx = 1 -- [Port] index in reconcile array (1-based)
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

    -- Apply in the final pass. Because it is possible that src_columns == table.Columns we went through a temporary copy.
    for _, reconcile_data in reconcile_requests:iter() do
        TableColumnCopy(table_.Columns[reconcile_data.ColumnNewIdx], reconcile_data.ColumnOldData) -- When old column was not found clear anyway with default-constructed data (which will set IsJustCreated=true)
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

    table_.FreezeColumnsRequest = (band(table_.Flags, ImGuiTableFlags.ScrollX) ~= 0) and mathMin(columns, table_.ColumnsCount) or 0
    table_.FreezeColumnsCount = (table_.InnerWindow.Scroll.x ~= 0.0) and table_.FreezeColumnsRequest or 0
    table_.FreezeRowsRequest = (band(table_.Flags, ImGuiTableFlags.ScrollY) ~= 0) and rows or 0
    table_.FreezeRowsCount = (table_.InnerWindow.Scroll.y ~= 0.0) and table_.FreezeRowsRequest or 0
    table_.IsUnfrozenRows = (table_.FreezeRowsCount == 0) -- Make sure this is set before TableUpdateLayout() so ImGuiListClipper can benefit from it.
end

-------------------------------------------------------------------------------
-- [SECTION] Tables: Simple accessors
-------------------------------------------------------------------------------
-- - TableGetColumnCount()
-- - TableGetColumnName()
-- - TableGetColumnName() [Internal]
-- - TableSetColumnEnabled()
-- - TableGetColumnFlags()
-- - TableGetCellBgRect() [Internal]
-- - TableGetColumnResizeID() [Internal]
-- - TableGetHoveredColumn() [Internal]
-- - TableGetHoveredRow() [Internal]
-- - TableSetBgColor()
-------------------------------------------------------------------------------

-- [Internal] Small optimization to avoid calls to PopClipRect/SetCurrentChannel/PushClipRect in sequences,
-- they would meddle many times with the underlying ImDrawCmd.
-- Instead, we do a preemptive overwrite of clipping rectangle _without_ altering the command-buffer and let
-- the subsequent single call to SetCurrentChannel() does it things once.
@native
function ImGui.SetWindowClipRectBeforeSetChannel(window, clip_rect)
    -- [Luau] scalar copies, no temporary ImVec4: the clip rect stack top is a uniquely owned ImVec4 (PushClipRect always pushes a fresh one), so overwrite it in place
    local min, max = clip_rect.Min, clip_rect.Max
    local x1, y1, x2, y2 = min.x, min.y, max.x, max.y
    local wcr = window.ClipRect
    wcr.Min.x = x1; wcr.Min.y = y1; wcr.Max.x = x2; wcr.Max.y = y2
    local draw_list = window.DrawList
    local hcr = draw_list._CmdHeader.ClipRect
    hcr.x = x1; hcr.y = y1; hcr.z = x2; hcr.w = y2
    local stack = draw_list._ClipRectStack
    local top = stack.Data[stack.Size]
    if top ~= nil then
        top.x = x1; top.y = y1; top.z = x2; top.w = y2
    else
        stack.Data[stack.Size] = ImVec4(x1, y1, x2, y2)
    end
end

function ImGui.TableGetColumnCount()
    local g = GImGui
    local table_ = g.CurrentTable
    return table_ and table_.ColumnsCount or 0
end

-- [Port] Overloads: TableGetColumnName(column_n?) / TableGetColumnName(table, column_n)
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
-- Note that end-user can use the context menu to change this themselves (right-click in headers, or right-click in columns body with ImGuiTableFlags.ContextMenuInBody)
-- - Require table to have the ImGuiTableFlags.Hideable flag because we are manipulating user accessible state.
-- - Request will be applied during next layout, which happens on the first call to TableNextRow() after BeginTable().
-- - For the getter you can test (TableGetColumnFlags() & ImGuiTableColumnFlags.IsEnabled) ~= 0.
-- - Alternative: the ImGuiTableColumnFlags.Disabled is an overriding/master disable flag which will also hide the column from context menu.
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
-- - Important: we generally don't know our row height until the end of the row, so Max.y will be incorrect in many situations.
--   The only case where this is correct is if we provided a min_row_height to TableNextRow() and don't go below it, or in TableEndRow() when we locked that height.
-- - Important: if ImGuiTableFlags.PadOuterX is set but ImGuiTableFlags.PadInnerX is not set, the outer-most left and right
--   columns report a small offset so their CellBgRect can extend up to the outer border.
--   FIXME: But the rendering code in TableEndRow() nullifies that with clamping required for scrolling.
function ImGui.TableGetCellBgRect(table_, column_n)
    local column = table_.Columns[column_n]
    local x1 = column.MinX
    local x2 = column.MaxX
    --if column.PrevEnabledColumn == -1 then
    --    x1 = x1 - table.OuterPaddingX
    --if column.NextEnabledColumn == -1 then
    --    x2 = x2 + table.OuterPaddingX
    x1 = mathMax(x1, table_.WorkRect.Min.x)
    x2 = mathMin(x2, table_.WorkRect.Max.x)
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
-- *IMPORTANT* Unlike TableGetHoveredColumn(), this has a one frame latency in updating the value.
-- This difference with is the reason why this is not public yet.
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

-------------------------------------------------------------------------------
-- [SECTION] Tables: Row changes
-------------------------------------------------------------------------------
-- - TableGetRowIndex()
-- - TableNextRow()
-- - TableBeginRow() [Internal]
-- - TableEndRow() [Internal]
-------------------------------------------------------------------------------

-- [Public] Note: for row coloring we use .RowBgColorCounter which is the same value without counting header rows
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
@native
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
    table_.RowPosY2 = mathMax(table_.RowPosY2 + table_.RowCellPaddingY * 2.0, table_.RowPosY1 + row_min_height) -- [Luau] inline ImMax

    -- Disable output until user calls TableNextColumn()
    table_.InnerWindow.SkipItems = true
end

-- [Internal] Only called by TableNextRow()
@native
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
    local dc = window.DC -- [Luau] cache
    table_.RowIndentOffsetX = dc.Indent.x - table_.HostIndentX -- Lock indent

    dc.PrevLineTextBaseOffset = 0.0
    dc.CursorPosPrevLine.x = dc.CursorPos.x
    dc.CursorPosPrevLine.y = dc.CursorPos.y + table_.RowCellPaddingY -- This allows users to call SameLine() to share LineSize between columns.
    dc.PrevLineSize.x = 0.0; dc.PrevLineSize.y = 0.0 -- This allows users to call SameLine() to share LineSize between columns, and to call it from first column too.
    dc.CurrLineSize.x = 0.0; dc.CurrLineSize.y = 0.0
    dc.IsSameLine = false; dc.IsSetPos = false
    dc.CursorMaxPos.y = next_y1

    -- Making the header BG color non-transparent will allow us to overlay it multiple times when handling smooth dragging.
    if band(table_.RowFlags, ImGuiTableRowFlags.Headers) ~= 0 then
        ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0, ImGui.GetColorU32(ImGuiCol.TableHeaderBg))
        if table_.CurrentRow == 0 then
            table_.IsUsingHeaders = true
        end
    end
end

-- [Luau] scratch vectors for TableEndRow() row background (never escape)
local TableEndRow_RowMin, TableEndRow_RowMax = ImVec2(), ImVec2()

-- [Internal] Called by TableNextRow()
@native
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

    -- Position cursor at the bottom of our row so it can be used for e.g. clipping calculation. However it is
    -- likely that the next call to TableBeginCell() will reposition the cursor to take account of vertical padding.
    window.DC.CursorPos.y = table_.RowPosY2

    -- Row background fill
    local bg_y1 = table_.RowPosY1
    local bg_y2 = table_.RowPosY2
    local unfreeze_rows_actual = (table_.CurrentRow + 1 == table_.FreezeRowsCount)
    local unfreeze_rows_request = (table_.CurrentRow + 1 == table_.FreezeRowsRequest)
    local table_instance = (table_.InstanceCurrent == 0) and table_.InstanceDataFirst or ImGui.TableGetInstanceData(table_, table_.InstanceCurrent) -- [Luau] inline common case
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
                -- [Luau] scalar copy, no temporary ImVec4
                local src, dst = table_.Bg0ClipRectForDrawCmd, window.DrawList._CmdHeader.ClipRect
                dst.x = src.Min.x; dst.y = src.Min.y; dst.z = src.Max.x; dst.w = src.Max.y
            end
            table_.DrawSplitter:SetCurrentChannel(window.DrawList, TABLE_DRAW_CHANNEL_BG0)
        end

        -- Draw row background
        -- We soft/cpu clip this so all backgrounds and borders can share the same clipping rectangle
        if bg_col0 ~= 0 or bg_col1 ~= 0 then
            -- [Luau] row_rect = ImRect(WorkRect.Min.x, bg_y1, WorkRect.Max.x, bg_y2); row_rect:ClipWith(BgClipRect), in scratch vectors (only read by AddRectFilled)
            local bg_clip_rect = table_.BgClipRect
            local row_min, row_max = TableEndRow_RowMin, TableEndRow_RowMax
            row_min.x = mathMax(table_.WorkRect.Min.x, bg_clip_rect.Min.x); row_min.y = mathMax(bg_y1, bg_clip_rect.Min.y)
            row_max.x = mathMin(table_.WorkRect.Max.x, bg_clip_rect.Max.x); row_max.y = mathMin(bg_y2, bg_clip_rect.Max.y)
            if bg_col0 ~= 0 and row_min.y < row_max.y then
                window.DrawList:AddRectFilled(row_min, row_max, bg_col0)
            end
            if bg_col1 ~= 0 and row_min.y < row_max.y then
                window.DrawList:AddRectFilled(row_min, row_max, bg_col1)
            end
        end

        -- Draw cell background color
        if draw_cell_bg_color then
            for cell_n = 0, table_.RowCellDataCurrent do
                local cell_data = table_.RowCellData[cell_n]
                -- As we render the BG here we need to clip things (for layout we would not)
                -- FIXME: This cancels the OuterPadding addition done by TableGetCellBgRect(), need to keep it while rendering correctly while scrolling.
                local column = table_.Columns[cell_data.Column]
                local cell_bg_rect = ImGui.TableGetCellBgRect(table_, cell_data.Column)
                cell_bg_rect:ClipWith(table_.BgClipRect)
                cell_bg_rect.Min.x = mathMax(cell_bg_rect.Min.x, column.ClipRect.Min.x) -- So that first column after frozen one gets clipped when scrolling
                cell_bg_rect.Max.x = mathMin(cell_bg_rect.Max.x, column.MaxX)
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
    -- - We need to do that in TableEndRow() instead of TableBeginRow() so the list clipper can mark
    --   end of row and get the new cursor position.
    if unfreeze_rows_request then
        IM_ASSERT(table_.FreezeRowsRequest > 0)
        for column_n = 0, table_.ColumnsCount - 1 do
            table_.Columns[column_n].NavLayerCurrent = table_.NavLayer
        end
        local y0 = mathMax(table_.RowPosY2 + 1, table_.InnerClipRect.Min.y)
        table_instance.LastFrozenHeight = y0 - table_.OuterRect.Min.y

        if unfreeze_rows_actual then
            IM_ASSERT(table_.IsUnfrozenRows == false)
            table_.IsUnfrozenRows = true

            -- BgClipRect starts as table.InnerClipRect, reduce it now and make BgClipRectForDrawCmd == BgClipRect
            local min_y = mathMin(y0, table_.InnerClipRect.Max.y)
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

            -- Update cliprect ahead of TableBeginCell() so clipper can access to new ClipRect.Min.y
            ImGui.SetWindowClipRectBeforeSetChannel(window, table_.Columns[0].ClipRect)
            table_.DrawSplitter:SetCurrentChannel(window.DrawList, table_.Columns[0].DrawChannelCurrent)
        end
    end

    if band(table_.RowFlags, ImGuiTableRowFlags.Headers) == 0 then
        table_.RowBgColorCounter = table_.RowBgColorCounter + 1
    end
    table_.IsInsideRow = false
end

-------------------------------------------------------------------------------
-- [SECTION] Tables: Columns changes
-------------------------------------------------------------------------------
-- - TableGetColumnIndex()
-- - TableSetColumnIndex()
-- - TableNextColumn()
-- - TableBeginCell() [Internal]
-- - TableEndCell() [Internal]
-------------------------------------------------------------------------------

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
@native
function ImGui.TableNextColumn()
    local g = GImGui
    local table_ = g.CurrentTable
    if not table_ then
        return false
    end

    local current_column = table_.CurrentColumn
    local next_column
    if table_.IsInsideRow and current_column + 1 < table_.ColumnsCount then
        if current_column ~= -1 then
            ImGui.TableEndCell(table_)
        end
        next_column = current_column + 1
    else
        ImGui.TableNextRow()
        next_column = 0
    end
    ImGui.TableBeginCell(table_, next_column)

    -- Return whether the column is visible. User may choose to skip submitting items based on this return value,
    -- however they shouldn't skip submitting for columns that may have the tallest contribution to row height.
    return table_.Columns[next_column].IsRequestOutput
end

-- [Internal] Called by TableSetColumnIndex()/TableNextColumn()
-- This is called very frequently, so we need to be mindful of unnecessary overhead.
-- FIXME-TABLE FIXME-OPT: Could probably shortcut some things for non-active or clipped columns.
@native
function ImGui.TableBeginCell(table_, column_n)
    local g = GImGui
    local column = table_.Columns[column_n]
    local window = table_.InnerWindow
    local dc = window.DC -- [Luau] cache
    table_.CurrentColumn = column_n

    -- Start position is roughly ~~ CellRect.Min + CellPadding + Indent
    local start_x = column.WorkMinX
    if band(column.Flags, ImGuiTableColumnFlags.IndentEnable) ~= 0 then
        start_x = start_x + table_.RowIndentOffsetX -- ~~ += window.DC.Indent.x - table.HostIndentX, except we locked it for the row.
    end

    local start_y = table_.RowPosY1 + table_.RowCellPaddingY
    dc.CursorPos.x = start_x
    dc.CursorPos.y = start_y
    dc.CursorMaxPos.x = start_x
    dc.ColumnsOffset.x = start_x - window.Pos.x - dc.Indent.x -- FIXME-WORKRECT
    dc.CursorPosPrevLine.x = start_x -- PrevLine.y is preserved. This allows users to call SameLine() to share LineSize between columns.
    dc.CurrLineTextBaseOffset = table_.RowTextBaseline
    dc.NavLayerCurrent = column.NavLayerCurrent

    -- Note how WorkRect.Max.y is only set once during layout
    local work_rect = window.WorkRect
    work_rect.Min.y = start_y
    work_rect.Min.x = column.WorkMinX
    work_rect.Max.x = column.WorkMaxX
    dc.ItemWidth = column.ItemWidth

    local skip_items = column.IsSkipItems
    window.SkipItems = skip_items
    if skip_items then
        g.LastItemData.ID = 0
        g.LastItemData.StatusFlags = 0
    end

    -- Also see TablePushColumnChannel()
    -- [Luau] inline the SetCurrentChannel() early-out (same channel) to skip the method call
    local splitter = table_.DrawSplitter
    if band(table_.Flags, ImGuiTableFlags.NoClip) ~= 0 then
        -- FIXME: if we end up drawing all borders/bg in EndTable, could remove this and just assert that channel hasn't changed.
        if splitter._Current ~= TABLE_DRAW_CHANNEL_NOCLIP then
            splitter:SetCurrentChannel(window.DrawList, TABLE_DRAW_CHANNEL_NOCLIP)
        end
        --IM_ASSERT(table.DrawSplitter._Current == TABLE_DRAW_CHANNEL_NOCLIP)
    else
        -- FIXME-TABLE: Could avoid this if draw channel is dummy channel?
        -- [Luau] inline ImGui.SetWindowClipRectBeforeSetChannel(window, column.ClipRect)
        local cr = column.ClipRect
        local x1, y1, x2, y2 = cr.Min.x, cr.Min.y, cr.Max.x, cr.Max.y
        local wcr = window.ClipRect
        wcr.Min.x = x1; wcr.Min.y = y1; wcr.Max.x = x2; wcr.Max.y = y2
        local draw_list = window.DrawList
        local hcr = draw_list._CmdHeader.ClipRect
        hcr.x = x1; hcr.y = y1; hcr.z = x2; hcr.w = y2
        local stack = draw_list._ClipRectStack
        local top = stack.Data[stack.Size]
        if top ~= nil then
            top.x = x1; top.y = y1; top.z = x2; top.w = y2
        else
            stack.Data[stack.Size] = ImVec4(x1, y1, x2, y2)
        end
        local channel = column.DrawChannelCurrent
        if splitter._Current ~= channel then
            splitter:SetCurrentChannel(window.DrawList, channel)
        end
    end

    -- Logging
    if g.LogEnabled and not column.IsSkipItems then
        ImGui.LogRenderedText(window.DC.CursorPos, "|")
        g.LogLinePosY = FLT_MAX
    end
end

-- [Internal] Called by TableNextRow()/TableSetColumnIndex()/TableNextColumn()
@native
function ImGui.TableEndCell(table_)
    local column = table_.Columns[table_.CurrentColumn]
    local window = table_.InnerWindow
    local dc = window.DC -- [Luau] cache; mathMax() inlined as math.max below

    if dc.IsSetPos then
        ImGui.ErrorCheckUsingSetCursorPosToExtendParentBoundaries()
    end

    -- Report maximum position so we can infer content size per column.
    local cursor_max_pos = dc.CursorMaxPos
    local x = cursor_max_pos.x
    if band(table_.RowFlags, ImGuiTableRowFlags.Headers) ~= 0 then
        column.ContentMaxXHeadersUsed = mathMax(column.ContentMaxXHeadersUsed, x) -- Useful in case user submit contents in header row that is not a TableHeader() call
    elseif table_.IsUnfrozenRows then
        column.ContentMaxXUnfrozen = mathMax(column.ContentMaxXUnfrozen, x)
    else
        column.ContentMaxXFrozen = mathMax(column.ContentMaxXFrozen, x)
    end
    if column.IsEnabled then
        table_.RowPosY2 = mathMax(table_.RowPosY2, cursor_max_pos.y + table_.RowCellPaddingY)
    end
    column.ItemWidth = dc.ItemWidth

    -- Propagate text baseline for the entire row
    -- FIXME-TABLE: Here we propagate text baseline from the last line of the cell.. instead of the first one.
    table_.RowTextBaseline = mathMax(table_.RowTextBaseline, dc.PrevLineTextBaseOffset)
end

-------------------------------------------------------------------------------
-- [SECTION] Tables: Columns width management
-------------------------------------------------------------------------------
-- - TableGetMaxColumnWidth() [Internal]
-- - TableGetColumnWidthAuto() [Internal]
-- - TableSetColumnWidth()
-- - TableSetColumnWidthAutoSingle() [Internal]
-- - TableSetColumnWidthAutoAll() [Internal]
-- - TableUpdateColumnsWeightFromWidth() [Internal]
-------------------------------------------------------------------------------
-- Note that actual columns widths are computed in TableUpdateLayout().
-------------------------------------------------------------------------------

-- Maximum column content width given current layout. Use column.MinX so this value differs on a per-column basis.
function ImGui.TableCalcMaxColumnWidth(table_, column_n)
    local column = table_.Columns[column_n]
    local max_width = FLT_MAX
    local min_column_distance = table_.MinColumnWidth + table_.CellPaddingX * 2.0 + table_.CellSpacingX1 + table_.CellSpacingX2
    if band(table_.Flags, ImGuiTableFlags.ScrollX) ~= 0 then
        -- Frozen columns can't reach beyond visible width else scrolling will naturally break.
        -- (we use DisplayOrder as within a set of multiple frozen column reordering is possible)
        if column.DisplayOrder < table_.FreezeColumnsRequest then
            max_width = (table_.InnerClipRect.Max.x - (table_.FreezeColumnsRequest - column.DisplayOrder) * min_column_distance) - column.MinX
            max_width = max_width - table_.OuterPaddingX - table_.CellPaddingX - table_.CellSpacingX2
        end
    elseif band(table_.Flags, ImGuiTableFlags.NoKeepColumnsVisible) == 0 then
        -- If horizontal scrolling if disabled, we apply a final lossless shrinking of columns in order to make
        -- sure they are all visible. Because of this we also know that all of the columns will always fit in
        -- table.WorkRect and therefore in table.InnerRect (because ScrollX is off)
        -- FIXME-TABLE: This is solved incorrectly but also quite a difficult problem to fix as we also want ClipRect width to match.
        -- See "table_width_distrib" and "table_width_keep_visible" tests
        max_width = table_.WorkRect.Max.x - (table_.ColumnsEnabledCount - column.IndexWithinEnabledSet - 1) * min_column_distance - column.MinX
        --max_width = max_width - table.CellSpacingX1
        max_width = max_width - table_.CellSpacingX2
        max_width = max_width - table_.CellPaddingX * 2.0
        max_width = max_width - table_.OuterPaddingX
    end
    return max_width
end

-- Note this is meant to be stored in column.WidthAuto, please generally use the WidthAuto field
function ImGui.TableGetColumnWidthAuto(table_, column)
    local content_width_body = mathMax(column.ContentMaxXFrozen, column.ContentMaxXUnfrozen) - column.WorkMinX
    local content_width_headers = column.ContentMaxXHeadersIdeal - column.WorkMinX
    local width_auto = content_width_body
    if band(column.Flags, ImGuiTableColumnFlags.NoHeaderWidth) == 0 then
        width_auto = mathMax(width_auto, content_width_headers)
    end

    -- Non-resizable fixed columns preserve their requested width
    if band(column.Flags, ImGuiTableColumnFlags.WidthFixed) ~= 0 and column.InitStretchWeightOrWidth > 0.0 then
        if band(table_.Flags, ImGuiTableFlags.Resizable) == 0 or band(column.Flags, ImGuiTableColumnFlags.NoResize) ~= 0 then
            width_auto = column.InitStretchWeightOrWidth
        end
    end

    return mathMax(width_auto, table_.MinColumnWidth)
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
    -- Compare both requested and actual given width to avoid overwriting requested width when column is stuck (minimum size, bounded)
    IM_ASSERT(table_.MinColumnWidth > 0.0)
    local min_width = table_.MinColumnWidth
    local max_width = mathMax(min_width, column_0.WidthMax) -- Don't use TableCalcMaxColumnWidth() here as it would rely on MinX from last instance (#7933)
    column_0_width = ImClamp(column_0_width, min_width, max_width)
    if column_0.WidthGiven == column_0_width or column_0.WidthRequest == column_0_width then
        return
    end

    --IMGUI_DEBUG_PRINT("TableSetColumnWidth(%d, %.1f->%.1f)\n", column_0_idx, column_0.WidthGiven, column_0_width)
    local column_1 = (column_0.NextEnabledColumn ~= -1) and table_.Columns[column_0.NextEnabledColumn] or nil

    -- In this surprisingly not simple because of how we support mixing Fixed and multiple Stretch columns.
    -- - All fixed: easy.
    -- - All stretch: easy.
    -- - One or more fixed + one stretch: easy.
    -- - One or more fixed + more than one stretch: tricky.
    -- Qt when manual resize is enabled only supports a single _trailing_ stretch column, we support more cases here.

    -- When forwarding resize from Wn| to Fn+1| we need to be considerate of the _NoResize flag on Fn+1.
    -- FIXME-TABLE: Find a way to rewrite all of this so interactions feel more consistent for the user.
    -- Scenarios:
    -- - F1 F2 F3  resize from F1| or F2|   --> ok: alter .WidthRequested of Fixed column. Subsequent columns will be offset.
    -- - F1 F2 F3  resize from F3|          --> ok: alter .WidthRequested of Fixed column. If active, ScrollX extent can be altered.
    -- - F1 F2 W3  resize from F1| or F2|   --> ok: alter .WidthRequested of Fixed column. If active, ScrollX extent can be altered, but it doesn't make much sense as the Stretch column will always be minimal size.
    -- - F1 F2 W3  resize from W3|          --> ok: no-op (disabled by Resize Rule 1)
    -- - W1 W2 W3  resize from W1| or W2|   --> ok
    -- - W1 W2 W3  resize from W3|          --> ok: no-op (disabled by Resize Rule 1)
    -- - W1 F2 F3  resize from F3|          --> ok: no-op (disabled by Resize Rule 1)
    -- - W1 F2     resize from F2|          --> ok: no-op (disabled by Resize Rule 1)
    -- - W1 W2 F3  resize from W1| or W2|   --> ok
    -- - W1 F2 W3  resize from W1| or F2|   --> ok
    -- - F1 W2 F3  resize from W2|          --> ok
    -- - F1 W3 F2  resize from W3|          --> ok
    -- - W1 F2 F3  resize from W1|          --> ok: equivalent to resizing |F2. F3 will not move.
    -- - W1 F2 F3  resize from F2|          --> ok
    -- All resizes from a Wx columns are locking other columns.

    -- Possible improvements:
    -- - W1 W2 W3  resize W1|               --> to not be stuck, both W2 and W3 would stretch down. Seems possible to fix. Would be most beneficial to simplify resize of all-weighted columns.
    -- - W3 F1 F2  resize W3|               --> to not be stuck past F1|, both F1 and F2 would need to stretch down, which would be lossy or ambiguous. Seems hard to fix.

    -- [Resize Rule 1] Can't resize from right of right-most visible column if there is any Stretch column. Implemented in TableUpdateLayout().

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
    local column_1_width = mathMax(column_1.WidthRequest - (column_0_width - column_0.WidthRequest), min_width)
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
-- (we don't take a shortcut for unclipped columns to reduce inconsistencies when e.g. resizing multiple columns)
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

-------------------------------------------------------------------------------
-- [SECTION] Tables: Drawing
-------------------------------------------------------------------------------
-- - TablePushBackgroundChannel() [Internal]
-- - TablePopBackgroundChannel() [Internal]
-- - TableSetupDrawChannels() [Internal]
-- - TableMergeDrawChannels() [Internal]
-- - TableGetColumnBorderCol() [Internal]
-- - TableDrawBorders() [Internal]
-------------------------------------------------------------------------------


-- FIXME: This could be abstracted and merged with PushColumnsBackground(), by creating a generic struct
-- with storage for backup cliprect + backup channel + storage for splitter pointer, new clip rect.
-- This would slightly simplify caller code.

-- Bg2 is used by Selectable (and possibly other widgets) to render to the background.
-- Unlike our Bg0/1 channel which we uses for RowBg/CellBg/Borders and where we guarantee all shapes to be CPU-clipped, the Bg2 channel being widgets-facing will rely on regular ClipRect.
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
-- - We allocate them following storage order instead of display order so reordering columns won't needlessly
--   increase overall dormant memory cost.
-- - We isolate headers draw commands in their own channels instead of just altering clip rects.
--   This is in order to facilitate merging of draw commands.
-- - After crossing FreezeRowsCount, all columns see their current draw channel changed to a second set of channels.
-- - We only use the dummy draw channel so we can push a null clipping rectangle into it without affecting other
--   channels, while simplifying per-row/per-cell overhead. It will be empty and discarded when merged.
-- - We allocate 1 or 2 background draw channels. This is because we know TablePushBackgroundChannel() is only used for
--   horizontal spanning. If we allowed vertical spanning we'd need one background draw channel per merge group (1-4).
-- Draw channel allocation (before merging):
-- - NoClip                       --> 2+D+1 channels: bg0/1 + bg2 + foreground (same clip rect == always 1 draw call)
-- - Clip                         --> 2+D+N channels
-- - FreezeRows                   --> 2+D+N*2 (unless scrolling value is zero)
-- - FreezeRows || FreezeColumns  --> 3+D+N*2 (unless scrolling value is zero)
-- Where D is 1 if any column is clipped or hidden (dummy channel) otherwise 0.
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
    -- All our cell highlight are manually clipped with BgClipRect. When unfreezing it will be made smaller to fit scrolling rect.
    -- (This technically isn't part of setting up draw channels, but is reasonably related to be done here)
    ImRect_Copy(table_.BgClipRect, table_.InnerClipRect)
    ImRect_Copy(table_.Bg0ClipRectForDrawCmd, table_.OuterWindow.ClipRect)
    ImRect_Copy(table_.Bg2ClipRectForDrawCmd, table_.HostClipRect)
    IM_ASSERT(table_.BgClipRect.Min.y <= table_.BgClipRect.Max.y)
end

-- This function reorder draw channels based on matching clip rectangle, to facilitate merging them. Called by EndTable().
-- For simplicity we call it TableMergeDrawChannels() but in fact it only reorder channels + overwrite ClipRect,
-- actual merging is done by table.DrawSplitter:Merge() which is called right after TableMergeDrawChannels().
--
-- Columns where the contents didn't stray off their local clip rectangle can be merged. To achieve
-- this we merge their clip rect and make them contiguous in the channel list, so they can be merged
-- by the call to DrawSplitter:Merge() following to the call to this function.
-- We reorder draw commands by arranging them into a maximum of 4 distinct groups:
--
--   1 group:               2 groups:              2 groups:              4 groups:
--   [ 0. ] no freeze       [ 0. ] row freeze      [ 01 ] col freeze      [ 01 ] row+col freeze
--   [ .. ]  or no scroll   [ 2. ]  and v-scroll   [ .. ]  and h-scroll   [ 23 ]  and v+h-scroll
--
-- Each column itself can use 1 channel (row freeze disabled) or 2 channels (row freeze enabled).
-- When the contents of a column didn't stray off its limit, we move its channels into the corresponding group
-- based on its position (within frozen rows/columns groups or not).
-- At the end of the operation our 1-4 groups will each have a ImDrawCmd using the same ClipRect.
-- This function assume that each column are pointing to a distinct draw channel,
-- otherwise merge_group.ChannelsCount will not match set bit count of merge_group.ChannelsMask.
--
-- Column channels will not be merged into one of the 1-4 groups in the following cases:
-- - The contents stray off its clipping rectangle (we only compare the MaxX value, not the MinX value).
--   Direct ImDrawList calls won't be taken into account by default, if you use them make sure the ImGui.* bounds
--   matches, by e.g. calling SetCursorScreenPos().
-- - The channel uses more than one draw command itself. We drop all our attempt at merging stuff here..
--   we could do better but it's going to be rare and probably not worth the hassle.
-- Columns for which the draw channel(s) haven't been merged with other will use their own ImDrawCmd.
--
-- This function is particularly tricky to understand.. take a breath.
-- [Port] (Lua: splitter channel n lives in splitter._Channels.Data[n + 1]; bit arrays are Lua sets)
local TableMergeDrawChannels_MergeGroups = {}
for n = 0, 3 do
    TableMergeDrawChannels_MergeGroups[n] = { ClipRect = ImRect(), ChannelsCount = 0, ChannelsMask = {} }
end
local TableMergeDrawChannels_RemainingMask = {}
local TableMergeDrawChannels_DstTmp = {}
function ImGui.TableMergeDrawChannels(table_)
    local splitter = table_.DrawSplitter
    local channels = splitter._Channels.Data
    local has_freeze_v = (table_.FreezeRowsCount > 0)
    local has_freeze_h = (table_.FreezeColumnsCount > 0)
    IM_ASSERT(splitter._Current == 0)

    -- Track which groups we are going to attempt to merge, and which channels goes into each group.
    local merge_group_mask = 0x00
    -- [Luau] reuse file-level scratch storage (function is not re-entrant, nothing escapes)
    local merge_groups = TableMergeDrawChannels_MergeGroups
    for n = 0, 3 do
        local merge_group = merge_groups[n]
        local cr = merge_group.ClipRect
        cr.Min.x = 0.0; cr.Min.y = 0.0; cr.Max.x = 0.0; cr.Max.y = 0.0
        merge_group.ChannelsCount = 0
        table.clear(merge_group.ChannelsMask)
    end
    local max_draw_channels = (4 + table_.ColumnsCount * 2)
    local remaining_mask = TableMergeDrawChannels_RemainingMask
    table.clear(remaining_mask)

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
                    -- (note that we assume that rendering didn't stray on the left direction. we should need a CursorMinPos to detect it)
                    if band(column.Flags, ImGuiTableColumnFlags.NoClip) == 0 then
                        local content_max_x
                        if not has_freeze_v then
                            content_max_x = mathMax(column.ContentMaxXUnfrozen, column.ContentMaxXHeadersUsed) -- No row freeze
                        elseif merge_group_sub_n == 0 then
                            content_max_x = mathMax(column.ContentMaxXFrozen, column.ContentMaxXHeadersUsed)   -- Row freeze: use width before freeze
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
                        local gcr = merge_group.ClipRect -- [Luau] in place (merge_groups are local to this call)
                        gcr.Min.x = FLT_MAX; gcr.Min.y = FLT_MAX; gcr.Max.x = -FLT_MAX; gcr.Max.y = -FLT_MAX
                    end
                    merge_group.ChannelsMask[channel_no] = true
                    merge_group.ChannelsCount = merge_group.ChannelsCount + 1
                    local cr = cmds.Data[1].ClipRect
                    -- [Luau] scalar version of merge_group.ClipRect:Add(ImRect(cr.x, cr.y, cr.z, cr.w))
                    local gmin, gmax = merge_group.ClipRect.Min, merge_group.ClipRect.Max
                    if gmin.x > cr.x then gmin.x = cr.x end
                    if gmin.y > cr.y then gmin.y = cr.y end
                    if gmax.x < cr.z then gmax.x = cr.z end
                    if gmax.y < cr.w then gmax.y = cr.w end
                    merge_group_mask = bor(merge_group_mask, lshift(1, merge_group_n))
                until true
            end

            -- Invalidate current draw channel
            -- (we don't clear DrawChannelFrozen/DrawChannelUnfrozen solely to facilitate debugging/later inspection of data)
            column.DrawChannelCurrent = -1
        end
    end

    -- 2. Rewrite channel list in our preferred order
    if merge_group_mask ~= 0 then
        -- We skip channel 0 (Bg0/Bg1) and 1 (Bg2 frozen) from the shuffling since they won't move - see channels allocation in TableSetupDrawChannels().
        local LEADING_DRAW_CHANNELS = 2
        local dst_tmp = TableMergeDrawChannels_DstTmp -- [Luau] scratch
        table.clear(dst_tmp)
        for n = LEADING_DRAW_CHANNELS, splitter._Count - 1 do
            remaining_mask[n] = true
        end
        remaining_mask[table_.Bg2DrawChannelUnfrozen] = nil
        IM_ASSERT(has_freeze_v == false or table_.Bg2DrawChannelUnfrozen ~= TABLE_DRAW_CHANNEL_BG2_FROZEN)
        local remaining_count = splitter._Count - (has_freeze_v and (LEADING_DRAW_CHANNELS + 1) or LEADING_DRAW_CHANNELS)
        --local host_rect = (table.InnerWindow == table.OuterWindow) and table.InnerClipRect or table.HostClipRect
        local host_rect = table_.HostClipRect
        for merge_group_n = 0, 3 do
            local merge_channels_count = merge_groups[merge_group_n].ChannelsCount
            if merge_channels_count ~= 0 then
                local merge_group = merge_groups[merge_group_n]
                local merge_clip_rect = Rect(merge_group.ClipRect)

                -- Extend outer-most clip limits to match those of host, so draw calls can be merged even if
                -- outer-most columns have some outer padding offsetting them from their parent ClipRect.
                -- The principal cases this is dealing with are:
                -- - On a same-window table (not scrolling = single group), all fitting columns ClipRect -> will extend and match host ClipRect -> will merge
                -- - Columns can use padding and have left-most ClipRect.Min.x and right-most ClipRect.Max.x != from host ClipRect -> will extend and match host ClipRect -> will merge
                -- FIXME-TABLE FIXME-WORKRECT: We are wasting a merge opportunity on tables without scrolling if column doesn't fit
                -- within host clip rect, solely because of the half-padding difference between window.WorkRect and window.InnerClipRect.
                if band(merge_group_n, 1) == 0 or not has_freeze_h then
                    merge_clip_rect.Min.x = mathMin(merge_clip_rect.Min.x, host_rect.Min.x)
                end
                if band(merge_group_n, 2) == 0 or not has_freeze_v then
                    merge_clip_rect.Min.y = mathMin(merge_clip_rect.Min.y, host_rect.Min.y)
                end
                if band(merge_group_n, 1) ~= 0 then
                    merge_clip_rect.Max.x = mathMax(merge_clip_rect.Max.x, host_rect.Max.x)
                end
                if band(merge_group_n, 2) ~= 0 and band(table_.Flags, ImGuiTableFlags.NoHostExtendY) == 0 then
                    merge_clip_rect.Max.y = mathMax(merge_clip_rect.Max.y, host_rect.Max.y)
                end
                --ImGui.GetForegroundDrawList():AddRect(merge_group.ClipRect.Min, merge_group.ClipRect.Max, IM_COL32(255, 0, 0, 200), 0.0, 0, 1.0) -- [DEBUG]
                --ImGui.GetForegroundDrawList():AddLine(merge_group.ClipRect.Min, merge_clip_rect.Min, IM_COL32(255, 100, 0, 200))
                --ImGui.GetForegroundDrawList():AddLine(merge_group.ClipRect.Max, merge_clip_rect.Max, IM_COL32(255, 100, 0, 200))
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
                        local dst = channel._CmdBuffer.Data[1].ClipRect -- [Luau] scalar copy, no temporary ImVec4
                        dst.x = merge_clip_rect.Min.x; dst.y = merge_clip_rect.Min.y; dst.z = merge_clip_rect.Max.x; dst.w = merge_clip_rect.Max.y
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
        table.clear(dst_tmp) -- [Luau] don't keep channel references alive in the scratch
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
    local draw_y1 = mathMax(table_.InnerRect.Min.y, ((table_.FreezeRowsCount >= 1) and table_.InnerRect.Min.y or table_.WorkRect.Min.y) + table_.AngledHeadersHeight) + ((band(table_.Flags, ImGuiTableFlags.BordersOuterH) ~= 0) and border_size or 0.0)
    local draw_y2_body = table_.InnerRect.Max.y
    local draw_y2_head = table_.IsUsingHeaders and mathMin(table_.InnerRect.Max.y, ((table_.FreezeRowsCount >= 1) and table_.InnerRect.Min.y or table_.WorkRect.Min.y) + table_instance.LastTopHeadersRowHeight) or draw_y1
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
    -- FIXME: could use AddRect or explicit VLine/HLine helper?
    if band(table_.Flags, ImGuiTableFlags.BordersOuter) ~= 0 then
        -- Display outer border offset by 1 which is a simple way to display it without adding an extra draw call
        -- (Without the offset, in outer_window it would be rendered behind cells, because child windows are above their
        -- parent. In inner_window, it won't reach out over scrollbars. Another weird solution would be to display part
        -- of it in inner window, and the part that's over scrollbars in the outer window..)
        -- Either solution currently won't allow us to use a larger border size: the border would clipped.
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

-------------------------------------------------------------------------------
-- [SECTION] Tables: Sorting
-------------------------------------------------------------------------------
-- - TableGetSortSpecs()
-- - TableFixColumnSortDirection() [Internal]
-- - TableGetColumnNextSortDirection() [Internal]
-- - TableSetColumnSortDirection() [Internal]
-- - TableSortSpecsSanitize() [Internal]
-- - TableSortSpecsBuild() [Internal]
-------------------------------------------------------------------------------

-- Return nil if no sort specs (most often when ImGuiTableFlags.Sortable is not set)
-- When 'sort_specs.SpecsDirty == true' you should sort your data. It will be true when sorting specs have
-- changed since last call, or the first time. Make sure to set 'SpecsDirty = false' after sorting,
-- else you may wastefully sort your data every frame!
-- Lifetime: don't hold on this table over multiple frames or past any subsequent call to BeginTable()!
-- [Port] Specs is a 1-based Lua array.
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
-- - If the PreferSortDescending flag is set, we will default to a Descending direction on the first click.
-- - Note that the PreferSortAscending flag is never checked, it is essentially the default and therefore a no-op.
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
            sort_order_max = mathMax(sort_order_max, table_.Columns[other_column_n].SortOrder)
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
    local sort_order_set = {} -- [Port] C++: ImU64 sort_order_mask
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

    -- [Port] need_fix_linearize: (1 << count) != (mask + 1) <=> the set of sort orders isn't exactly {0..count-1}
    local need_fix_linearize = sort_order_dup
    for n = 0, sort_order_count - 1 do
        if not sort_order_set[n] then need_fix_linearize = true end
    end
    local need_fix_single_sort_order = (sort_order_count > 1) and band(table_.Flags, ImGuiTableFlags.SortMulti) == 0
    if need_fix_linearize or need_fix_single_sort_order then
        local fixed_mask = {}
        for sort_n = 0, sort_order_count - 1 do
            -- Fix: Rewrite sort order fields if needed so they have no gap or duplicate.
            -- (e.g. SortOrder 0 disappeared, SortOrder 1..2 exists --> rewrite then as SortOrder 0..1)
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

            -- Fix: Make sure only one column has a SortOrder if ImGuiTableFlags.MultiSortable is not set.
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

    -- Fallback default sort order (if no column with the ImGuiTableColumnFlags.DefaultSort flag)
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
    -- May be able to move all SortSpecs data from table (48 bytes) to ImGuiTableTempData if we decide to write it back on every BeginTable()
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

-------------------------------------------------------------------------------
-- [SECTION] Tables: Headers
-------------------------------------------------------------------------------
-- - TableGetHeaderRowHeight() [Internal]
-- - TableGetHeaderAngledMaxLabelWidth() [Internal]
-- - TableHeadersRow()
-- - TableHeader()
-- - TableAngledHeadersRow()
-- - TableAngledHeadersRowEx() [Internal]
-------------------------------------------------------------------------------

function ImGui.TableGetHeaderRowHeight()
    -- Caring for a minor edge case:
    -- Calculate row height, for the unlikely case that some labels may be taller than others.
    -- If we didn't do that, uneven header height would highlight but smaller one before the tallest wouldn't catch input for all height.
    -- In your custom header row you may omit this all together and just call TableNextRow() without a height...
    local g = GImGui
    local table_ = g.CurrentTable
    local row_height = g.FontSize
    for column_n = 0, table_.ColumnsCount - 1 do
        if BitTest(table_.EnabledMaskByIndex, column_n) then
            if band(table_.Columns[column_n].Flags, ImGuiTableColumnFlags.NoHeaderLabel) == 0 then
                row_height = mathMax(row_height, ImGui.CalcTextSize(ImGui.TableGetColumnName(table_, column_n)).y)
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
                width = mathMax(width, ImGui.CalcTextSize(ImGui.TableGetColumnName(table_, column_n), nil, true).x)
            end
        end
    end
    return width + g.Style.CellPadding.y * 2.0 -- Swap padding
end

-- [Public] This is a helper to output TableHeader() calls based on the column names declared in TableSetupColumn().
-- The intent is that advanced users willing to create customized headers would not need to use this helper
-- and can create their own! For example: TableHeader() may be preceded by Checkbox() or other custom widgets.
-- See 'Demo->Tables->Custom headers' for a demonstration of implementing a custom version of this.
-- This code is intentionally written to not make much use of internal functions, to give you better direction
-- if you need to write your own.
-- FIXME-TABLE: TableOpenContextMenu() and TableGetHeaderRowHeight() are not public.
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
-- Note that because of how we cpu-clip and display sorting indicators, you _cannot_ use SameLine() after a TableHeader()
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
    -- FIXME-TABLE: Padding problem if the correct outer-padding CellBgRect strays off our ClipRect?
    -- [Luau] scalar version of: cell_r = TableGetCellBgRect(table_, column_n) (Min.x/Min.y/Max.x/Max.y -> cell_x1/cell_y1/cell_x2/cell_y2)
    local cell_x1 = mathMax(column.MinX, table_.WorkRect.Min.x)
    local cell_x2 = mathMin(column.MaxX, table_.WorkRect.Max.x)
    local cell_y1, cell_y2 = table_.RowPosY1, table_.RowPosY2
    local label_height = mathMax(label_size.y, table_.RowMinHeight - table_.RowCellPaddingY * 2.0)

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
    column.ContentMaxXHeadersUsed = mathMax(column.ContentMaxXHeadersUsed, sort_arrow and cell_x2 or mathMin(max_pos_x, cell_x2))
    column.ContentMaxXHeadersIdeal = mathMax(column.ContentMaxXHeadersIdeal, max_pos_x)

    -- Keep header highlighted when context menu is open.
    local id = window:GetID(label)
    local bb = ImRect(cell_x1, cell_y1, cell_x2, mathMax(cell_y2, cell_y1 + label_height + g.Style.CellPadding.y * 2.0))
    ImGui.ItemSize(ImVec2(0.0, label_height)) -- Don't declare unclipped width, it'll be fed ContentMaxPosHeadersIdeal
    if not ImGui.ItemAdd(bb, id) then
        return
    end

    --GetForegroundDrawList():AddRect(cell_r.Min, cell_r.Max, IM_COL32(255, 0, 0, 255)) -- [DEBUG]
    --GetForegroundDrawList():AddRect(bb.Min, bb.Max, IM_COL32(255, 0, 0, 255)) -- [DEBUG]

    -- Using AllowOverlap mode because we cover the whole cell, and we want user to be able to submit subsequent items.
    local highlight = (table_.HighlightColumnHeader == column_n)
    local pressed, hovered, held = ImGui.ButtonBehavior(bb, id, ImGuiButtonFlags.AllowOverlap)
    if held or hovered or highlight then
        local col = ImGui.GetColorU32(held and ImGuiCol.HeaderActive or (hovered and ImGuiCol.HeaderHovered or ImGuiCol.Header))
        --RenderFrame(bb.Min, bb.Max, col, false, 0.0)
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
    -- FIXME-TABLE: Scroll request while reordering a column and it lands out of the scrolling zone.
    if held and band(table_.Flags, ImGuiTableFlags.Reorderable) ~= 0 and ImGui.IsMouseDragging(0) and not g.DragDropActive then
        -- - While moving a column it will jump on the other side of the mouse, so we also test for MouseDelta.x
        -- - We need to handle reordering across hidden columns.
        --   In the configuration below, moving C to the right of E will lead to:
        --      ... C [D] E  --->  ... [D] E  C   (Column name/index)
        --      ... 2  3  4        ...  2  3  4   (Display order)
        -- - The other constraints are enforced by TableQueueSetColumnDisplayOrder() which might early out.
        table_.InstanceInteracted = table_.InstanceCurrent
        if g.IO.MouseDelta.x < 0.0 and g.IO.MousePos.x < cell_x1 then
            local prev_column = (column.PrevEnabledColumn ~= -1) and table_.Columns[column.PrevEnabledColumn] or nil
            if prev_column then
                ImGui.TableQueueSetColumnDisplayOrder(table_, column_n, prev_column.DisplayOrder)
            end
        end
        if g.IO.MouseDelta.x > 0.0 and g.IO.MousePos.x > cell_x2 then
            local next_column = (column.NextEnabledColumn ~= -1) and table_.Columns[column.NextEnabledColumn] or nil
            if next_column then
                ImGui.TableQueueSetColumnDisplayOrder(table_, column_n, next_column.DisplayOrder)
            end
        end
    end

    -- Sort order arrow
    -- - Only clip label for a visible arrow. Auto-fit still accounts for a possible arrow, but when
    --   manually sized smaller we don't clip the label for the sake of an arrow that isn't displayed.
    local ellipsis_max = mathMax(cell_x2 - (sort_arrow and (w_arrow + w_sort_text) or 0.0), label_pos.x)
    if band(table_.Flags, ImGuiTableFlags.Sortable) ~= 0 and band(column.Flags, ImGuiTableColumnFlags.NoSort) == 0 then
        if column.SortOrder ~= -1 then
            local x = mathMax(cell_x1, cell_x2 - w_arrow - w_sort_text)
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
    --window.DrawList:AddCircleFilled(ImVec2(ellipsis_max, label_pos.y), 40, IM_COL32_WHITE)
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
-- FIXME: No hit-testing/button on the angled header.
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
            if band(column.Flags, ImGuiTableColumnFlags.AngledHeader) ~= 0 then -- Note: can't rely on ImGuiTableColumnFlags.IsVisible test here.
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
    -- FIXME-STYLE: Would it be better for user to submit 'max_label_width' or 'row_height' ? One can be derived from the other.
    local header_height = g.FontSize + g.Style.CellPadding.x * 2.0
    local row_height = ImTrunc(ImAbs(ImRotate(ImVec2(max_label_width, flip_label and header_height or -header_height), cos_a, sin_a).y))
    table_.AngledHeadersHeight = row_height
    table_.AngledHeadersSlope = (sin_a ~= 0.0) and (cos_a / sin_a) or 0.0
    local header_angled_vector = unit_right * (row_height / -sin_a) -- vector from bottom-left to top-left, and from bottom-right to top-right

    -- Declare row, override and draw our own background
    -- FIXME-TABLE: Generally broken when overlapping frozen columns limit.
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
                -- - First draw at an offset where RenderTextXXX() function won't meddle with applying current ClipRect, then transform to final offset.
                -- - Handle multiple lines manually, as we want each lines to follow on the horizontal border, rather than see a whole block rotated.
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
                    --if g.IO.KeyShift then local fg_dl = GetForegroundDrawList(); vtx_idx_begin = fg_dl._VtxCurrentIdx; fg_dl:AddRect(clip_r.Min, clip_r.Max, IM_COL32(0, 255, 0, 255), 0.0, 0, 1.0); ShadeVertsTransformPos(fg_dl, vtx_idx_begin, fg_dl._VtxCurrentIdx, pivot_in, label_cos_a, label_sin_a, pivot_out) end

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

-------------------------------------------------------------------------------
-- [SECTION] Tables: Context Menu
-------------------------------------------------------------------------------
-- - TableOpenContextMenu() [Internal]
-- - TableBeginContextMenuPopup() [Internal]
-- - TableDrawDefaultContextMenu() [Internal]
-------------------------------------------------------------------------------

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

    ImGui.BeginDisabled(not enabled) -- Don't use ImGuiSelectableFlags.Disabled so that Check mark is also affected.
    local ret = ImGui.Selectable(label, false, selectable_flags, ImVec2(min_w, label_size.y)) and not has_been_moved -- Can't use IsMouseDragging(0) as button is released already.
    if band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.Visible) ~= 0 and selected then
        ImGui.RenderCheckMark(window.DrawList, text_pos + ImVec2(offsets.OffsetMark + stretch_w + g.FontSize * 0.40, g.FontSize * 0.134 * 0.5), ImGui.GetColorU32(ImGuiCol.Text), g.FontSize * 0.866)
    end
    ImGui.EndDisabled()

    return ret
end

-- Output context menu into current window (generally a popup)
-- FIXME-TABLE: Ideally this should be writable by the user. Full programmatic access to that data?
-- Sections to display are pulled from 'flags_for_section_to_display', which is typically == table.Flags.
-- - ImGuiTableFlags.Resizable   -> display Sizing menu items
-- - ImGuiTableFlags.Reorderable -> display "Reset Order"
---- ImGuiTableFlags.Sortable   -> display sorting options (disabled)
-- - ImGuiTableFlags.Hideable    -> display columns visibility menu items
-- It means if you have a custom context menus you can call this section and omit some sections, and add your own.
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
            --if ImGui.MenuItem(ImGui.LocalizeGetMsg(ImGuiLocKey.TableResetAll)) then -- FIXME: Hiding because altering Sort Order + requesting auto-fit simultaneously has a tendency to exhibit a sizing glitch.
            --    table_.IsResetAllRequest = true
            --end
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

    -- Sorting
    -- (modify TableOpenContextMenu() to add _Sortable flag if enabling this)
    -- #if 0
    --if band(flags_for_section_to_display, ImGuiTableFlags.Sortable) ~= 0 and column ~= nil and band(column.Flags, ImGuiTableColumnFlags.NoSort) == 0 then
    --    if want_separator then ImGui.Separator() end
    --    want_separator = true
    --    local append_to_sort_specs = g.IO.KeyShift
    --    if ImGui.MenuItem("Sort in Ascending Order", nil, column.SortOrder ~= -1 and column.SortDirection == ImGuiSortDirection.Ascending, band(column.Flags, ImGuiTableColumnFlags.NoSortAscending) == 0) then
    --        ImGui.TableSetColumnSortDirection(table_, column_n, ImGuiSortDirection.Ascending, append_to_sort_specs)
    --    end
    --    if ImGui.MenuItem("Sort in Descending Order", nil, column.SortOrder ~= -1 and column.SortDirection == ImGuiSortDirection.Descending, band(column.Flags, ImGuiTableColumnFlags.NoSortDescending) == 0) then
    --        ImGui.TableSetColumnSortDirection(table_, column_n, ImGuiSortDirection.Descending, append_to_sort_specs)
    --    end
    --end
    -- #endif

    -- Hiding / Visibility
    if band(flags_for_section_to_display, ImGuiTableFlags.Hideable) ~= 0 then
        if want_separator then
            ImGui.Separator()
        end
        want_separator = true

        -- While reordering: we calculate min/max allowed range once here so we can avoid a O(N log N) in the loop (because the query itself does a sweep scan).
        -- This assume that reordering constraints output a single range, otherwise would need to either call TableGetMaxDisplayOrderAllowed() for each item below, or cache this once per frame into columns.
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
                -- FIXME: It is currently not possible to reorder columns marked with ImGuiTableColumnFlags.NoHide.
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

-------------------------------------------------------------------------------
-- [SECTION] Tables: Settings (.ini data)
-------------------------------------------------------------------------------
-- FIXME: The binding/finding/creating flow are too confusing.
-------------------------------------------------------------------------------
-- - TableSettingsInit() [Internal]
-- - TableSettingsCreate() [Internal]
-- - TableSettingsFindByID() [Internal]
-- - TableGetBoundSettings() [Internal]
-- - TableResetSettings()
-- - TableSaveSettings() [Internal]
-- - TableLoadSettings() [Internal]
-- - TableLoadSettingsForColumns() [Internal]
-- - TableSettingsHandler_ClearAll() [Internal]
-- - TableSettingsHandler_ApplyAll() [Internal]
-- - TableSettingsHandler_ReadOpen() [Internal]
-- - TableSettingsHandler_ReadLine() [Internal]
-- - TableSettingsHandler_WriteAll() [Internal]
-- - TableSettingsAddSettingsHandler() [Internal]
-------------------------------------------------------------------------------
-- [Init] 1: TableSettingsHandler_ReadXXXX()   Load and parse .ini file into TableSettings.
-- [Main] 2: TableLoadSettings()               When table is created, bind Table to TableSettings, serialize TableSettings data into Table.
-- [Main] 3: TableSaveSettings()               When table properties are modified, serialize Table data into bound or new TableSettings, mark .ini as dirty.
-- [Main] 4: TableSettingsHandler_WriteAll()   When .ini file is dirty (which can come from other source), save TableSettings into .ini file.
-------------------------------------------------------------------------------

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
    -- FIXME-OPT: Might want to store a lookup map for this?
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

-- Get settings for a given table, nil if none
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
    settings.LastUsedDate = GImGui.SessionDate:Unpack()

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
        -- Note that fixed width where initial width was derived from auto-fit will always be saved as InitStretchWeightOrWidth will be 0.0f.
        -- FIXME-TABLE: We don't have logic to easily compare SortOrder to DefaultSortOrder yet so it's always saved when present.
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
    settings.LastUsedDate = GImGui.SessionDate:Unpack()
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

-- [Luau] boolean "less than" for table.sort; takes (table, lhs column idx, rhs column idx) instead of ImGuiTableFixDisplayOrderColumnData
local function TableFixDisplayOrderComparer(table_, lhs_idx, rhs_idx)
    -- Assume ImGuiTableColumnIdx == signed short, to turn -1 into a large value so that it always sort after.
    local lhs_order, rhs_order = table_.Columns[lhs_idx].DisplayOrder, table_.Columns[rhs_idx].DisplayOrder
    if lhs_order < 0 then lhs_order = lhs_order + 0x10000 end
    if rhs_order < 0 then rhs_order = rhs_order + 0x10000 end
    local order_delta = lhs_order - rhs_order
    if order_delta ~= 0 then return order_delta < 0 end
    return lhs_idx < rhs_idx
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
    -- Sort by DisplayOrder and then Index
    table.sort(fdo_columns, function(lhs_idx, rhs_idx) return TableFixDisplayOrderComparer(table_, lhs_idx, rhs_idx) end)
    for n = 0, table_.ColumnsCount - 1 do
        table_.Columns[fdo_columns[n + 1]].DisplayOrder = n
    end
    for n = 0, table_.ColumnsCount - 1 do
        table_.DisplayOrderToIndex[table_.Columns[n].DisplayOrder] = n
    end
end

local function TableSettingsHandler_Cleanup(ctx, handler, args)
    local g = ctx
    for i = 0, g.Tables:GetMapSize() - 1 do
        local table_ = g.Tables:GetByIndex(i)
        if table_ then
            table_.SettingsOffset = -1
        end
    end
    -- [Luau] settings.LastUsedDate is stored unpacked (YYYYMMDD int, 0 = none); g.SessionDate is an ImGuiPackedDate
    for _, settings in g.SettingsTables:iter() do
        local is_valid = ImGuiPackedDate(settings.LastUsedDate):IsValid()
        if args._DiscardOlderThanDate ~= 0 and settings.LastUsedDate < args._DiscardOlderThanDate then
            settings.ID = 0
        elseif args.DiscardWhenMissingDate and not is_valid then
            settings.ID = 0
        elseif args.SetCurrentSessionDateToAll or (args.SetCurrentSessionDateWhenMissingDate and not is_valid) then
            settings.LastUsedDate = g.SessionDate:Unpack()
        end
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
    -- FIXME: As topology changes are allowed, strictly speaking a >= IMGUI_TABLE_MAX_COLUMNS tables stored in .ini file
    -- that was emitted with a higher max count could still be meaningful in some unlikely cases.
    -- We might want to use another MAX defined as (1<<(sizeof(ImGuiTableColumnIdx)*8-1))-1.
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
    if n then settings.LastUsedDate = ImGuiPackedDate(tonumber(n)):Unpack(); return end

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
            -- TableSaveSettings() may clear some of those flags when we establish that the data can be stripped
            -- (e.g. Order was unchanged)
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
                -- "Column 0  UserID=0x42AD2D21 Width=100 Visible=1 Order=0 Sort=0v"
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
    ini_handler.CleanupFn  = TableSettingsHandler_Cleanup
    ImGui.AddSettingsHandler(ini_handler)
end

-------------------------------------------------------------------------------
-- [SECTION] Tables: Garbage Collection
-------------------------------------------------------------------------------
-- - TableRemove() [Internal]
-- - TableGcCompactTransientBuffers() [Internal]
-- - TableGcCompactSettings() [Internal]
-------------------------------------------------------------------------------

-- Remove Table data (currently only used by TestEngine)
function ImGui.TableRemove(table_)
    --IMGUI_DEBUG_PRINT("TableRemove() id=0x%08X\n", table_.ID)
    local g = GImGui
    local table_idx = g.Tables:GetIndex(table_)
    g.Tables:Remove(table_.ID, table_)
    g.TablesLastTimeActive.Data[table_idx + 1] = -1.0
end

-- Free up/compact internal Table buffers for when it gets unused
-- [Port] Overloads: (ImGuiTable) / (ImGuiTableTempData)
function ImGui.TableGcCompactTransientBuffers(t)
    if not t then return end
    if t.TableIndex ~= nil then -- ImGuiTableTempData
        t.AngledHeadersRequests:clear()
        t.DrawSplitter:ClearFreeMemory()
        t.LastTimeActive = -1.0
        return
    end
    --IMGUI_DEBUG_PRINT("TableGcCompactTransientBuffers() id=0x%08X\n", t.ID)
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

-- Compact and remove unused or resize settings data (only TestEngine mark unused, but resizing table down can lead to compaction)
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

-------------------------------------------------------------------------------
-- [SECTION] Tables: Debugging
-------------------------------------------------------------------------------
-- [Luau] global (upstream: static) so ImGui.DebugNodeTable() in imgui.lua can use it

function DebugNodeTableGetSizingPolicyDesc(sizing_policy)
    sizing_policy = band(sizing_policy, ImGuiTableFlags.SizingMask_)
    if sizing_policy == ImGuiTableFlags.SizingFixedFit then return "FixedFit" end
    if sizing_policy == ImGuiTableFlags.SizingFixedSame then return "FixedSame" end
    if sizing_policy == ImGuiTableFlags.SizingStretchProp then return "StretchProp" end
    if sizing_policy == ImGuiTableFlags.SizingStretchSame then return "StretchSame" end
    return "N/A"
end

-------------------------------------------------------------------------------
-- [SECTION] Columns, BeginColumns, EndColumns, etc.
-- (This is a legacy API, prefer using BeginTable/EndTable!)
-------------------------------------------------------------------------------
-- FIXME: sizing is lossy when columns width is very small (default width may turn negative etc.)
-------------------------------------------------------------------------------
-- - GetColumnIndex()
-- - GetColumnsCount()
-- - GetColumnOffset()
-- - GetColumnWidth()
-- - SetColumnOffset()
-- - SetColumnWidth()
-- - PushColumnClipRect() [Internal]
-- - PushColumnsBackground() [Internal]
-- - PopColumnsBackground() [Internal]
-- - FindOrCreateColumns() [Internal]
-- - GetColumnsID() [Internal]
-- - BeginColumns()
-- - NextColumn()
-- - EndColumns()
-- - Columns()
-------------------------------------------------------------------------------
-- [Port] (Lua: columns.Columns is an ImVector, column n lives in .Data[n + 1])

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
    -- Active (dragged) column always follow mouse. The reason we need this is that dragging a column to the right edge of an auto-resizing
    -- window creates a feedback loop because we store normalized positions. So while dragging we enforce absolute positioning.
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
    -- In addition, when an identifier isn't explicitly provided we include the number of columns in the hash to make it uniquer.
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
    -- We aim so that the right-most column will have the same clipping width as other after being clipped by parent ClipRect
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
    -- (which would needlessly attempt to update commands in the wrong channel, then pop or overwrite them),
    local column = columns.Columns.Data[columns.Current + 1]
    ImGui.SetWindowClipRectBeforeSetChannel(window, column.ClipRect)
    columns.Splitter:SetCurrentChannel(window.DrawList, columns.Current + 1)

    local column_padding = g.Style.ItemSpacing.x
    columns.LineMaxY = ImMax(columns.LineMaxY, window.DC.CursorPos.y)
    if columns.Current > 0 then
        -- Columns 1+ ignore IndentX (by canceling it out)
        -- FIXME-COLUMNS: Unnecessary, could be locked?
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

    -- FIXME-COLUMNS: Share code with BeginColumns() - move code on columns setup.
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
    -- The IsBeingResized flag ensure we preserve pre-resize columns width so back-and-forth are not lossy
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
    --flags = bor(flags, ImGuiOldColumnFlags.NoPreserveWidths) -- NB: Legacy behavior
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

return true -- [Port] [Roblox] ModuleScripts must return exactly one value
