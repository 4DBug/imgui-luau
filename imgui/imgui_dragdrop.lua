--- ImGui Sincerely
-- Drag and drop: 1:1 port of imgui.cpp [SECTION] DRAG AND DROP (docking branch)
-- Payload `Data` is any Lua value (no copy is made). `data_size` is optional and only kept for API parity.

function ImGui.IsDragDropActive()
    return ImGui.GetCurrentContext().DragDropActive
end

function ImGui.ClearDragDrop()
    local g = ImGui.GetCurrentContext()
    g.DragDropActive = false
    ImGuiPayload_Clear(g.DragDropPayload)
    g.DragDropAcceptFlagsCurr = ImGuiDragDropFlags.None
    g.DragDropAcceptIdCurr = 0
    g.DragDropAcceptIdPrev = 0
    g.DragDropAcceptIdCurrRectSurface = FLT_MAX
    g.DragDropAcceptFrameCount = -1
end

function ImGui.BeginDragDropSource(flags)
    if flags == nil then flags = 0 end
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow

    local mouse_button = ImGuiMouseButton.Left

    local source_drag_active = false
    local source_id = 0
    local source_parent_id = 0
    if bit32.band(flags, ImGuiDragDropFlags.SourceExtern) == 0 then
        source_id = g.LastItemData.ID
        if source_id ~= 0 then
            if g.ActiveId ~= source_id then return false end
            if g.ActiveIdMouseButton ~= -1 then mouse_button = g.ActiveIdMouseButton end
            if g.IO.MouseDown[mouse_button] == false or window.SkipItems then return false end
            g.ActiveIdAllowOverlap = false
        else
            if g.IO.MouseDown[mouse_button] == false or window.SkipItems then return false end
            if bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredRect) == 0 and (g.ActiveId == 0 or g.ActiveIdWindow ~= window) then
                return false
            end
            if bit32.band(flags, ImGuiDragDropFlags.SourceAllowNullID) == 0 then
                IM_ASSERT(false, "Use ImGuiDragDropFlags.SourceAllowNullID for items without an ID")
                return false
            end
            source_id = window:GetIDFromRectangle(g.LastItemData.Rect)
            g.LastItemData.ID = source_id
            ImGui.KeepAliveID(source_id)
            local is_hovered = ImGui.ItemHoverable(g.LastItemData.Rect, source_id, g.LastItemData.ItemFlags)
            if is_hovered and g.IO.MouseClicked[mouse_button] then
                ImGui.SetActiveID(source_id, window)
                ImGui.FocusWindow(window)
            end
            if g.ActiveId == source_id then g.ActiveIdAllowOverlap = is_hovered end
        end
        if g.ActiveId ~= source_id then return false end
        source_parent_id = window.IDStack.Data[window.IDStack.Size]
        source_drag_active = ImGui.IsMouseDragging(mouse_button)

        ImGui.SetActiveIdUsingAllKeyboardKeys()
    else
        window = nil
        source_id = ImHashStr("#SourceExtern")
        source_drag_active = true
        mouse_button = g.IO.MouseDown[0] and 0 or -1
        ImGui.KeepAliveID(source_id)
        ImGui.SetActiveID(source_id, nil)
    end

    IM_ASSERT(g.DragDropWithinTarget == false)
    if not source_drag_active then return false end

    if not g.DragDropActive then
        IM_ASSERT(source_id ~= 0)
        ImGui.ClearDragDrop()
        local payload = g.DragDropPayload
        payload.SourceId = source_id
        payload.SourceParentId = source_parent_id
        g.DragDropActive = true
        g.DragDropSourceFlags = flags
        g.DragDropMouseButton = mouse_button
        if payload.SourceId == g.ActiveId then g.ActiveIdNoClearOnFocusLoss = true end
    end
    g.DragDropSourceFrameCount = g.FrameCount
    g.DragDropWithinSource = true

    if bit32.band(flags, ImGuiDragDropFlags.SourceNoPreviewTooltip) == 0 then
        local ret
        if g.DragDropAcceptIdPrev ~= 0 and bit32.band(g.DragDropAcceptFlagsPrev, ImGuiDragDropFlags.AcceptNoPreviewTooltip) ~= 0 then
            ret = ImGui.BeginTooltipHidden()
        else
            ret = ImGui.BeginTooltip()
        end
        IM_ASSERT(ret)
    end

    if bit32.band(flags, ImGuiDragDropFlags.SourceNoDisableHover) == 0 and bit32.band(flags, ImGuiDragDropFlags.SourceExtern) == 0 then
        g.LastItemData.StatusFlags = bit32.band(g.LastItemData.StatusFlags, bit32.bnot(ImGuiItemStatusFlags.HoveredRect))
    end
    return true
end

function ImGui.EndDragDropSource()
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(g.DragDropActive)
    IM_ASSERT(g.DragDropWithinSource, "Not after a BeginDragDropSource()?")

    if bit32.band(g.DragDropSourceFlags, ImGuiDragDropFlags.SourceNoPreviewTooltip) == 0 then
        ImGui.EndTooltip()
    end

    if g.DragDropPayload.DataFrameCount == -1 then ImGui.ClearDragDrop() end
    g.DragDropWithinSource = false
end

--- @param data any # any Lua value
--- @return bool accepted
function ImGui.SetDragDropPayload(type, data, data_size, cond)
    local g = ImGui.GetCurrentContext()
    local payload = g.DragDropPayload
    if cond == nil or cond == 0 then cond = ImGuiCond.Always end

    IM_ASSERT(type ~= nil)
    IM_ASSERT(#type < 32, "Payload type can be at most 32 characters long")
    IM_ASSERT(cond == ImGuiCond.Always or cond == ImGuiCond.Once)
    IM_ASSERT(payload.SourceId ~= 0)

    if cond == ImGuiCond.Always or payload.DataFrameCount == -1 then
        payload.DataType = type
        payload.Data = data
        payload.DataSize = data_size or ((data ~= nil) and 1 or 0)
    end
    payload.DataFrameCount = g.FrameCount

    return (g.DragDropAcceptFrameCount == g.FrameCount) or (g.DragDropAcceptFrameCount == g.FrameCount - 1)
end

function ImGui.BeginDragDropTargetCustom(bb, id)
    local g = ImGui.GetCurrentContext()
    if not g.DragDropActive then return false end

    local window = g.CurrentWindow
    local hovered_window = g.HoveredWindowUnderMovingWindow
    if hovered_window == nil or window.RootWindowDockTree ~= hovered_window.RootWindowDockTree then return false end
    IM_ASSERT(id ~= 0)
    if not ImGui.IsMouseHoveringRect(bb.Min, bb.Max) or (id == g.DragDropPayload.SourceId) then return false end
    if window.SkipItems then return false end

    IM_ASSERT(g.DragDropWithinTarget == false and g.DragDropWithinSource == false)
    g.DragDropTargetRect = ImRect(bb.Min, bb.Max)
    g.DragDropTargetClipRect = ImRect(window.ClipRect.Min, window.ClipRect.Max)
    g.DragDropTargetId = id
    g.DragDropTargetFullViewport = 0
    g.DragDropWithinTarget = true
    return true
end

function ImGui.BeginDragDropTargetViewport(viewport, p_bb)
    local g = ImGui.GetCurrentContext()
    if not g.DragDropActive then return false end

    local bb = p_bb or viewport:GetWorkRect()
    local id = viewport.ID
    if g.MouseViewport ~= viewport or not ImGui.IsMouseHoveringRect(bb.Min, bb.Max, false) or (id == g.DragDropPayload.SourceId) then
        return false
    end

    IM_ASSERT(g.DragDropWithinTarget == false and g.DragDropWithinSource == false)
    g.DragDropTargetRect = ImRect(bb.Min, bb.Max)
    g.DragDropTargetClipRect = ImRect(bb.Min, bb.Max)
    g.DragDropTargetId = id
    g.DragDropTargetFullViewport = id
    g.DragDropWithinTarget = true
    return true
end

function ImGui.BeginDragDropTarget()
    local g = ImGui.GetCurrentContext()
    if not g.DragDropActive then return false end

    local window = g.CurrentWindow
    if bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HoveredRect) == 0 then return false end
    local hovered_window = g.HoveredWindowUnderMovingWindow
    if hovered_window == nil or window.RootWindowDockTree ~= hovered_window.RootWindowDockTree or window.SkipItems then return false end

    local display_rect = (bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasDisplayRect) ~= 0) and g.LastItemData.DisplayRect or g.LastItemData.Rect
    local id = g.LastItemData.ID
    if id == 0 then
        id = window:GetIDFromRectangle(display_rect)
        ImGui.KeepAliveID(id)
    end
    if g.DragDropPayload.SourceId == id then return false end

    IM_ASSERT(g.DragDropWithinTarget == false and g.DragDropWithinSource == false)
    g.DragDropTargetRect = ImRect(display_rect.Min, display_rect.Max)
    local clip = (bit32.band(g.LastItemData.StatusFlags, ImGuiItemStatusFlags.HasClipRect) ~= 0) and g.LastItemData.ClipRect or window.ClipRect
    g.DragDropTargetClipRect = ImRect(clip.Min, clip.Max)
    g.DragDropTargetId = id
    g.DragDropWithinTarget = true
    return true
end

function ImGui.IsDragDropPayloadBeingAccepted()
    local g = ImGui.GetCurrentContext()
    return g.DragDropActive and g.DragDropAcceptIdPrev ~= 0
end

--- @return ImGuiPayload?
function ImGui.AcceptDragDropPayload(type, flags)
    if flags == nil then flags = 0 end
    local g = ImGui.GetCurrentContext()
    local payload = g.DragDropPayload
    IM_ASSERT(g.DragDropActive)
    IM_ASSERT(payload.DataFrameCount ~= -1)
    if type ~= nil and not ImGuiPayload_IsDataType(payload, type) then return nil end

    local was_accepted_previously = (g.DragDropAcceptIdPrev == g.DragDropTargetId)
    local r = g.DragDropTargetRect
    local r_surface = r:GetWidth() * r:GetHeight()
    if r_surface > g.DragDropAcceptIdCurrRectSurface then return nil end

    g.DragDropAcceptFlagsCurr = flags
    g.DragDropAcceptIdCurr = g.DragDropTargetId
    g.DragDropAcceptIdCurrRectSurface = r_surface

    payload.Preview = was_accepted_previously
    flags = bit32.bor(flags, bit32.band(g.DragDropSourceFlags, ImGuiDragDropFlags.AcceptNoDrawDefaultRect))
    local draw_target_rect = payload.Preview and bit32.band(flags, ImGuiDragDropFlags.AcceptNoDrawDefaultRect) == 0
    if draw_target_rect and g.DragDropTargetFullViewport ~= 0 then
        ImGui.RenderDragDropTargetRectForViewport(g.DragDropTargetFullViewport, g.DragDropTargetRect)
    elseif draw_target_rect then
        ImGui.RenderDragDropTargetRectForItem(r)
    end

    g.DragDropAcceptFrameCount = g.FrameCount
    if bit32.band(g.DragDropSourceFlags, ImGuiDragDropFlags.SourceExtern) ~= 0 and g.DragDropMouseButton == -1 then
        payload.Delivery = was_accepted_previously and (g.DragDropSourceFrameCount < g.FrameCount)
    else
        payload.Delivery = was_accepted_previously and not ImGui.IsMouseDown(g.DragDropMouseButton)
    end
    if not payload.Delivery and bit32.band(flags, ImGuiDragDropFlags.AcceptBeforeDelivery) == 0 then return nil end
    return payload
end

function ImGui.RenderDragDropTargetRectForItem(bb)
    local g = ImGui.GetCurrentContext()
    local window = g.CurrentWindow
    local bb_display = ImRect(bb.Min, bb.Max)
    bb_display:ClipWith(g.DragDropTargetClipRect)
    bb_display:Expand(g.Style.DragDropTargetPadding)
    local push_clip_rect = not window.ClipRect:Contains(bb_display)
    if push_clip_rect then window.DrawList:PushClipRectFullScreen() end
    ImGui.RenderDragDropTargetRectEx(window.DrawList, bb_display, g.Style.DragDropTargetRounding)
    if push_clip_rect then window.DrawList:PopClipRect() end
end

function ImGui.RenderDragDropTargetRectForViewport(viewport_id, bb)
    local g = ImGui.GetCurrentContext()
    local viewport = ImGui.FindViewportByID(viewport_id)
    IM_ASSERT(viewport ~= nil)
    local bb_padded = ImRect(bb.Min, bb.Max)
    bb_padded:Expand(-g.Style.DragDropTargetPadding)
    ImGui.RenderDragDropTargetRectEx(ImGui.GetForegroundDrawList(viewport), bb_padded, g.Style.DragDropTargetRounding)
end

function ImGui.RenderDragDropTargetRectEx(draw_list, bb, rounding)
    local g = ImGui.GetCurrentContext()
    draw_list:AddRectFilled(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.DragDropTargetBg), rounding, 0)
    draw_list:AddRect(bb.Min, bb.Max, ImGui.GetColorU32(ImGuiCol.DragDropTarget), rounding, g.Style.DragDropTargetBorderSize)
end

--- @return ImGuiPayload?
function ImGui.GetDragDropPayload()
    local g = ImGui.GetCurrentContext()
    return (g.DragDropActive and g.DragDropPayload.DataFrameCount ~= -1) and g.DragDropPayload or nil
end

function ImGui.EndDragDropTarget()
    local g = ImGui.GetCurrentContext()
    IM_ASSERT(g.DragDropActive)
    IM_ASSERT(g.DragDropWithinTarget)
    g.DragDropWithinTarget = false
    if g.DragDropPayload.Delivery then ImGui.ClearDragDrop() end
end

-- Payload methods (C++ ImGuiPayload members): payload:IsDataType(t) etc. also work through these globals
function ImGui.PayloadIsDataType(payload, t) return ImGuiPayload_IsDataType(payload, t) end

return true
