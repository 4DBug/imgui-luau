--- ImGui Backend for Love2D
--- Structurally mirrors imgui_impl_gmod.lua

local love = love

local ImGui_ImplLOVE_GetBackendData
local ImGui_ImplLOVE_UpdateTexture
local ImGui_ImplLOVE_RenderDrawData
local ImGui_ImplLOVE_Shutdown

local CURSOR_MAP = {
    [ImGuiMouseCursor.None]       = nil,
    [ImGuiMouseCursor.Arrow]      = "arrow",
    [ImGuiMouseCursor.TextInput]  = "ibeam",
    [ImGuiMouseCursor.ResizeAll]  = "sizeall",
    [ImGuiMouseCursor.ResizeNS]   = "sizens",
    [ImGuiMouseCursor.ResizeEW]   = "sizewe",
    [ImGuiMouseCursor.ResizeNESW] = "sizenesw",
    [ImGuiMouseCursor.ResizeNWSE] = "sizenwse",
    [ImGuiMouseCursor.Hand]       = "hand",
    [ImGuiMouseCursor.Wait]       = "wait",
    [ImGuiMouseCursor.Progress]   = "waitarrow",
    [ImGuiMouseCursor.NotAllowed] = "no",
}

local KEY_MAP = {
    ["return"]    = ImGuiKey.Enter,       ["escape"]    = ImGuiKey.Escape,
    ["backspace"] = ImGuiKey.Backspace,   ["tab"]       = ImGuiKey.Tab,
    ["space"]     = ImGuiKey.Space,       ["enter"]     = ImGuiKey.KeypadEnter,
    ["up"]        = ImGuiKey.UpArrow,     ["down"]      = ImGuiKey.DownArrow,
    ["left"]      = ImGuiKey.LeftArrow,   ["right"]     = ImGuiKey.RightArrow,
    ["home"]      = ImGuiKey.Home,        ["end"]       = ImGuiKey.End,
    ["pageup"]    = ImGuiKey.PageUp,      ["pagedown"]  = ImGuiKey.PageDown,
    ["insert"]    = ImGuiKey.Insert,      ["delete"]    = ImGuiKey.Delete,
    ["lctrl"]     = ImGuiKey.LeftCtrl,    ["rctrl"]     = ImGuiKey.RightCtrl,
    ["lshift"]    = ImGuiKey.LeftShift,   ["rshift"]    = ImGuiKey.RightShift,
    ["lalt"]      = ImGuiKey.LeftAlt,     ["ralt"]      = ImGuiKey.RightAlt,
    ["lgui"]      = ImGuiKey.LeftSuper,   ["rgui"]      = ImGuiKey.RightSuper,
}
for i = 0, 9 do KEY_MAP[tostring(i)] = ImGuiKey["K" .. i] end
for i = 1, 12 do KEY_MAP["f" .. i] = ImGuiKey["F" .. i] end
for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
    KEY_MAP[c] = ImGuiKey[c:upper()]
end

local function ImGui_ImplLOVE_UpdateKeyModifiers()
    local io = ImGui.GetIO()
    io:AddKeyEvent(ImGuiMod_Ctrl, love.keyboard.isDown("lctrl", "rctrl"))
    io:AddKeyEvent(ImGuiMod_Shift, love.keyboard.isDown("lshift", "rshift"))
    io:AddKeyEvent(ImGuiMod_Alt, love.keyboard.isDown("lalt", "ralt"))
    io:AddKeyEvent(ImGuiMod_Super, love.keyboard.isDown("lgui", "rgui"))
end

--- @return table?
function ImGui_ImplLOVE_GetBackendData()
    return ImGui.GetCurrentContext() and ImGui.GetIO().BackendPlatformUserData or nil
end

---------------------------------------------------------
-- VIEWPORT STUBS
-- Required for ImGui BackendPlatformHasViewports logic
---------------------------------------------------------

local function ImGui_ImplLOVE_CreateWindow(viewport)
    -- STUB: Triggered when ImGui creates a new multi-viewport window (e.g., dragging a panel outside main window).
    -- If your LÖVE fork supports multiple OS windows (or if managing internal canvases), initialize it here.
    local vd = { WindowID = nil, Owned = true }
    viewport.PlatformUserData = vd
    viewport.PlatformHandle = vd
    viewport.PlatformHandleRaw = vd
end

local function ImGui_ImplLOVE_DestroyWindow(viewport)
    -- STUB: Destroy the OS-level window or release the canvas associated with this viewport.
    viewport.PlatformUserData = nil
    viewport.PlatformHandle = nil
end

local function ImGui_ImplLOVE_ShowWindow(viewport)
    -- STUB: OS-level call to make the window visible.
end

local function ImGui_ImplLOVE_SetWindowPos(viewport, pos)
    -- STUB: Set the OS-level window position (pos.x, pos.y).
end

local function ImGui_ImplLOVE_GetWindowPos(viewport)
    -- STUB: Return the OS-level window position as ImVec2(x, y).
    return ImVec2(0, 0) 
end

local function ImGui_ImplLOVE_SetWindowSize(viewport, size)
    -- STUB: Resize the OS-level window to (size.x, size.y).
end

local function ImGui_ImplLOVE_GetWindowSize(viewport)
    -- STUB: Return the OS-level window size.
    return ImVec2(800, 600) 
end

local function ImGui_ImplLOVE_SetWindowFocus(viewport)
    -- STUB: Bring the OS-level window to focus.
end

local function ImGui_ImplLOVE_GetWindowFocus(viewport)
    -- STUB: Return true if this OS-level window has focus.
    return false
end

local function ImGui_ImplLOVE_SetWindowTitle(viewport, title)
    -- STUB: Set the title of the OS-level window.
end

local function ImGui_ImplLOVE_RenderWindow(viewport)
    -- STUB: Render routine for the secondary viewport.
    -- Set render target to this window's canvas/context, then call ImGui_ImplLOVE_RenderDrawData(viewport.DrawData)
end

local function ImGui_ImplLOVE_SwapBuffers(viewport)
    -- STUB: OS-level call to swap buffers for this specific window context.
end

local function ImGui_ImplGMOD_UpdateMonitors()
    local bd = ImGui_ImplLOVE_GetBackendData()
    local io = ImGui.GetPlatformIO()
    io.Monitors:resize(0)

    local imgui_monitor = ImGuiPlatformMonitor()
    ImVec2_Copy(imgui_monitor.MainSize, ImVec2(800, 600))
    ImVec2_Copy(imgui_monitor.WorkSize, ImVec2(800, 600))

    io.Monitors:push_back(imgui_monitor)

    bd.WantUpdateMonitors = false
end


local function ImGui_ImplLOVE_InitMultiViewportSupport()
    local platform_io = ImGui.GetPlatformIO()
    platform_io.Platform_CreateWindow   = ImGui_ImplLOVE_CreateWindow
    platform_io.Platform_DestroyWindow  = ImGui_ImplLOVE_DestroyWindow
    platform_io.Platform_ShowWindow     = ImGui_ImplLOVE_ShowWindow
    platform_io.Platform_SetWindowPos   = ImGui_ImplLOVE_SetWindowPos
    platform_io.Platform_GetWindowPos   = ImGui_ImplLOVE_GetWindowPos
    platform_io.Platform_SetWindowSize  = ImGui_ImplLOVE_SetWindowSize
    platform_io.Platform_GetWindowSize  = ImGui_ImplLOVE_GetWindowSize
    platform_io.Platform_SetWindowFocus = ImGui_ImplLOVE_SetWindowFocus
    platform_io.Platform_GetWindowFocus = ImGui_ImplLOVE_GetWindowFocus
    platform_io.Platform_SetWindowTitle = ImGui_ImplLOVE_SetWindowTitle

    platform_io.Renderer_RenderWindow   = ImGui_ImplLOVE_RenderWindow
    platform_io.Renderer_SwapBuffers    = ImGui_ImplLOVE_SwapBuffers

    local main_viewport = ImGui.GetMainViewport()
    main_viewport.PlatformUserData = { Owned = false }
end

---------------------------------------------------------
-- PLATFORM DATA & CALLBACKS
---------------------------------------------------------

local function ImGui_ImplLOVE_PlatformSetImeData(ctx, vp, data)
    -- Unlike GMod's invisible VGUI TextEntry workaround[cite: 1], 
    -- Love2D has native IME support we can toggle directly.
    if data.WantVisible or data.WantTextInput then
        love.keyboard.setTextInput(true, data.InputPos.x, data.InputPos.y, 1, data.InputLineHeight)
    else
        love.keyboard.setTextInput(false)
    end
end

local function ImGui_ImplLOVE_PlatformSetClipboardText(ctx, text)
    love.system.setClipboardText(text)
end

local function ImGui_ImplLOVE_PlatformGetClipboardText(ctx)
    return love.system.getClipboardText()
end

local function ImGui_ImplLOVE_OpenInShellFn(ctx, path)
    love.system.openURL(path)
end

---------------------------------------------------------
-- TEXTURE MANAGEMENT 
---------------------------------------------------------
local ffi = require("ffi")

function ImGui_ImplLOVE_UpdateTexture(tex)
    if tex.Status == ImTextureStatus.WantCreate then
        local w, h = tex.Width, tex.Height
        local row, row_base = tex:GetPixelsAt(0, 0)
        
        local imgData = love.image.newImageData(w, h)
        local ptr = ffi.cast("uint8_t*", imgData:getFFIPointer())
        
        -- Iterate through the Lua table to manually assign the bytes to the C pointer
        local total_bytes = w * h * 4
        for i = 0, total_bytes - 1 do
            ptr[i] = row[row_base + i]
        end

        local loveTex = love.graphics.newImage(imgData)
        loveTex:setFilter("nearest", "nearest")
        
        tex.BackendUserData = loveTex
        tex:SetTexID(1)
        tex:SetStatus(ImTextureStatus.OK)
    elseif tex.Status == ImTextureStatus.WantUpdates then
        local loveTex = tex.BackendUserData
        IM_ASSERT(loveTex ~= nil)

        for _, r in tex.Updates:iter() do
            local w, h = r.w, r.h

            local updateData = love.image.newImageData(w, h)
            local dst = ffi.cast("uint8_t*", updateData:getFFIPointer())

            for y = 0, h - 1 do
                local src, src_base = tex:GetPixelsAt(r.x, r.y + y)
                local dst_base = y * w * 4

                for i = 0, w * 4 - 1 do
                    dst[dst_base + i] = src[src_base + i]
                end
            end

            loveTex:replacePixels(
                updateData,
                nil,
                1,
                r.x,
                r.y,
                false
            )

            updateData:release()
        end

        tex:SetStatus(ImTextureStatus.OK)
    elseif tex.Status == ImTextureStatus.WantDestroy then
        if tex.BackendUserData then
            tex.BackendUserData:release()
            tex.BackendUserData = nil
        end
        tex:SetTexID(ImTextureID_Invalid)
        tex:SetStatus(ImTextureStatus.Destroyed)
    end
end

---------------------------------------------------------
-- RENDERING
---------------------------------------------------------

local rshift, band = bit32.rshift, bit32.band

local function u32ToRGBA(col)
    -- Extract bytes from u32 integer just like GMod implementation[cite: 1]
    return band(col, 0xFF) / 255, 
           band(rshift(col, 8), 0xFF) / 255, 
           band(rshift(col, 16), 0xFF) / 255, 
           band(rshift(col, 24), 0xFF) / 255
end

function ImGui_ImplLOVE_RenderDrawData(draw_data)
    if draw_data.DisplaySize.x <= 0.0 or draw_data.DisplaySize.y <= 0.0 then return end

    if draw_data.Textures ~= nil then
        for _, tex in draw_data.Textures:iter() do
            if tex.Status ~= ImTextureStatus.OK then
                ImGui_ImplLOVE_UpdateTexture(tex)
            end
        end
    end

    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "alphamultiply")

    local format = {
        {"VertexPosition", "float", 2},
        {"VertexTexCoord", "float", 2},
        {"VertexColor", "byte", 4},
    }

    local idx_data, vtx_data
    for _, draw_list in draw_data.CmdLists:iter() do
        idx_data = draw_list.IdxBuffer; vtx_data = draw_list.VtxBuffer

        for _, pcmd in draw_list.CmdBuffer:iter() do
            if pcmd.UserCallback ~= nil then
                pcmd.UserCallback(draw_list, pcmd)
            elseif pcmd.ElemCount > 0 and pcmd.ClipRect.z > pcmd.ClipRect.x and pcmd.ClipRect.w > pcmd.ClipRect.y then

                -- LÖVE Scissor mapping
                love.graphics.setScissor(pcmd.ClipRect.x, pcmd.ClipRect.y, 
                    pcmd.ClipRect.z - pcmd.ClipRect.x, pcmd.ClipRect.w - pcmd.ClipRect.y)

                -- Create a temporary table for vertices
                -- Note: For production use, passing `ByteData` with an FFI pointer directly to `newMesh` is significantly faster.
                local vertices = {}
                for i = 0, pcmd.ElemCount - 1, 3 do
                    local idx0 = idx_data[pcmd.IdxOffset + 1 + i]
                    local idx1 = idx_data[pcmd.IdxOffset + 2 + i]
                    local idx2 = idx_data[pcmd.IdxOffset + 3 + i]

                    local vtx0 = vtx_data[pcmd.VtxOffset + idx0]
                    local vtx1 = vtx_data[pcmd.VtxOffset + idx1]
                    local vtx2 = vtx_data[pcmd.VtxOffset + idx2]

                    local r0, g0, b0, a0 = u32ToRGBA(vtx0[3])
                    table.insert(vertices, {vtx0[1][1], vtx0[1][2], vtx0[2][1], vtx0[2][2], r0, g0, b0, a0})
                    
                    local r1, g1, b1, a1 = u32ToRGBA(vtx1[3])
                    table.insert(vertices, {vtx1[1][1], vtx1[1][2], vtx1[2][1], vtx1[2][2], r1, g1, b1, a1})
                    
                    local r2, g2, b2, a2 = u32ToRGBA(vtx2[3])
                    table.insert(vertices, {vtx2[1][1], vtx2[1][2], vtx2[2][1], vtx2[2][2], r2, g2, b2, a2})
                end

                local mesh = love.graphics.newMesh(format, vertices, "triangles")
                
                -- The Texture object is stored in BackendUserData
                local tex_id = pcmd:GetTexID()
                local tex = ImGui.GetPlatformIO().Textures[tex_id]
                if tex and tex.BackendUserData then
                    mesh:setTexture(tex.BackendUserData)
                end

                love.graphics.draw(mesh)
            end
        end
    end

    love.graphics.setScissor()
    love.graphics.pop()
end

---------------------------------------------------------
-- CORE LIFECYCLE
---------------------------------------------------------

function ImGui_ImplLOVE_Init()
    local io = ImGui.GetIO()

    local bd = { Time = love.timer.getTime() }
    io.BackendPlatformUserData = bd

    --io.BackendFlags = bit32.bor(io.BackendFlags, ImGuiBackendFlags.PlatformHasViewports)
    io.BackendFlags = bit32.bor(io.BackendFlags, ImGuiBackendFlags.RendererHasTextures)
    io.BackendFlags = bit32.bor(io.BackendFlags, ImGuiBackendFlags.RendererHasVtxOffset)
    --io.BackendFlags = bit32.bor(io.BackendFlags, ImGuiBackendFlags.RendererHasViewports)

    local platform_io = ImGui.GetPlatformIO()
    platform_io.Platform_SetImeDataFn       = ImGui_ImplLOVE_PlatformSetImeData
    platform_io.Platform_SetClipboardTextFn = ImGui_ImplLOVE_PlatformSetClipboardText
    platform_io.Platform_GetClipboardTextFn = ImGui_ImplLOVE_PlatformGetClipboardText
    platform_io.Platform_OpenInShellFn      = ImGui_ImplLOVE_OpenInShellFn

    --ImGui_ImplLOVE_InitMultiViewportSupport()
    ImGui_ImplGMOD_UpdateMonitors()
end

function ImGui_ImplLOVE_Shutdown()
    local io = ImGui.GetIO()
    ImGui.DestroyPlatformWindows()
    
    io.BackendPlatformUserData = nil
    io.BackendFlags = bit32.band(io.BackendFlags, bit32.bnot(bit32.bor(
        ImGuiBackendFlags.HasMouseCursors, 
        ImGuiBackendFlags.PlatformHasViewports, 
        ImGuiBackendFlags.RendererHasViewports
    )))
end

function ImGui_ImplLOVE_NewFrame()
    local io = ImGui.GetIO()
    local bd = ImGui_ImplLOVE_GetBackendData()

    local w, h = love.graphics.getDimensions()
    ImVec2_CopyV(io.DisplaySize, w, h)

    local current_time = love.timer.getTime()
    io.DeltaTime = (bd.Time > 0.0) and (current_time - bd.Time) or (1.0 / 60.0)
    bd.Time = current_time

    -- Update Cursor
    if bit32.band(io.ConfigFlags, ImGuiConfigFlags.NoMouseCursorChange) == 0 then
        local cursor = CURSOR_MAP[ImGui.GetMouseCursor()]
        if cursor then
            love.mouse.setCursor(love.mouse.getSystemCursor(cursor))
        else
            love.mouse.setCursor()
        end
    end
end

---------------------------------------------------------
-- LOVE EVENT HOOKS (Call these from main.lua)
---------------------------------------------------------

local function Hook_MouseMoved(x, y)
    local io = ImGui.GetIO()
    io:AddMouseSourceEvent(ImGuiMouseSource.Mouse)
    io:AddMousePosEvent(x, y)
end

local function Hook_MousePressed(x, y, button)
    local io = ImGui.GetIO()
    io:AddMouseSourceEvent(ImGuiMouseSource.Mouse)
    -- LÖVE passes buttons as 1=left, 2=right, 3=middle. ImGui uses 0=left, 1=right, 2=middle.
    if button <= 3 then
        local ig_btn = (button == 1) and ImGuiMouseButton.Left or (button == 2 and ImGuiMouseButton.Right or ImGuiMouseButton.Middle)
        io:AddMouseButtonEvent(ig_btn, true)
    end
end

local function Hook_MouseReleased(x, y, button)
    local io = ImGui.GetIO()
    if button <= 3 then
        local ig_btn = (button == 1) and ImGuiMouseButton.Left or (button == 2 and ImGuiMouseButton.Right or ImGuiMouseButton.Middle)
        io:AddMouseButtonEvent(ig_btn, false)
    end
end

local function Hook_WheelMoved(x, y)
    local io = ImGui.GetIO()
    io:AddMouseWheelEvent(x, y)
end

local function Hook_KeyPressed(key)
    local io = ImGui.GetIO()
    ImGui_ImplLOVE_UpdateKeyModifiers()
    if KEY_MAP[key] then
        io:AddKeyEvent(KEY_MAP[key], true)
    end
end

local function Hook_KeyReleased(key)
    local io = ImGui.GetIO()
    ImGui_ImplLOVE_UpdateKeyModifiers()
    if KEY_MAP[key] then
        io:AddKeyEvent(KEY_MAP[key], false)
    end
end

local function Hook_TextInput(text)
    local io = ImGui.GetIO()
    for _, code in utf8.codes(text) do
        io:AddInputCharacter(code)
    end
end

--Implementing some bullshit
function ImStd.ImFileOpen(_filename, _mode)
    if _mode == "rb" then _mode = "r" end
    local file, _ = love.filesystem.newFile(_filename, _mode)
    return file
end

function ImStd.ImFileClose(f)
    f:close()
end

function ImStd.ImFileGetSize(f)
    return f:getSize()
end

function ImStd.ImFileRead(f, data, count)
    local CHUNK_SIZE = 8000 -- We don't read byte by byte
    local offset = 0

    while offset < count do
        local read_size = math.min(CHUNK_SIZE, count - offset)
        local str = f:read(read_size)

        -- Handle EOF or read failure gracefully
        if not str or #str == 0 then break end

        -- Iterate based on actual bytes read without risking stack overflow
        for i = 1, #str do
            data[offset + i] = string.byte(str, i)
        end

        offset = offset + #str
    end
end

function ImStd.ImFileLoadToMemory(filename, mode)
    local f = ImStd.ImFileOpen(filename, mode)
    if not f then return end

    local file_size = ImStd.ImFileGetSize(f)
    if file_size <= 0 then
        ImStd.ImFileClose(f)
        return
    end

    local file_data = {}
    ImStd.ImFileRead(f, file_data, file_size)
    if #file_data == 0 then
        ImStd.ImFileClose(f)
        return
    end

    ImStd.ImFileClose(f)

    return file_data, file_size
end

ImGui_ImplLove = {
    Init           = ImGui_ImplLOVE_Init,
    Shutdown       = ImGui_ImplLOVE_Shutdown,
    NewFrame       = ImGui_ImplLOVE_NewFrame,
    RenderDrawData = ImGui_ImplLOVE_RenderDrawData,
    
    -- Event hooks to connect in love.* callbacks
    MouseMoved     = Hook_MouseMoved,
    MousePressed   = Hook_MousePressed,
    MouseReleased  = Hook_MouseReleased,
    WheelMoved     = Hook_WheelMoved,
    KeyPressed     = Hook_KeyPressed,
    KeyReleased    = Hook_KeyReleased,
    TextInput      = Hook_TextInput,
}