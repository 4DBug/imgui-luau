-- Renders README screenshots headless: runs one SCENE (prepended by tools/screenshots/make.py), composites the
-- backend's tile ImageLabels exactly like Roblox stacks them (ZIndex, nested offsets, ClipsDescendants) over a
-- background colour, and prints frames as "PX <frame> <y> <hex rgb row>" for the crop rect.
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
local Cond = G.ImGuiCond
ImGui.CreateContext()
local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.DockingEnable)
io.IniFilename = nil
G.ImGui_ImplRoblox.Init()
G.ImGui_ImplRoblox.SetRenderRate(0)
local BG = { 115, 140, 153 } -- examples/example_roblox clear_color

-- force tree nodes / headers / tabs open by label
local OPEN = {}
for _, fname in ipairs({ "TreeNode", "CollapsingHeader" }) do
    local real = ImGui[fname]
    ImGui[fname] = function(label, ...)
        if OPEN[label] then ImGui.SetNextItemOpen(true, Cond.Always) end
        return real(label, ...)
    end
end
local SELECT_TAB = nil
local realBTI = ImGui.BeginTabItem
ImGui.BeginTabItem = function(label, p_open, flags)
    if label == SELECT_TAB then flags = bit32.bor(flags or 0, G.ImGuiTabItemFlags.SetSelected) end
    return realBTI(label, p_open, flags)
end

-- the demo sets its own pos/size (FirstUseEver) right before Begin: override it there
local DEMO_RECT = nil
local realBegin = ImGui.Begin
ImGui.Begin = function(name, ...)
    if name == "Dear ImGui Demo" and DEMO_RECT then
        ImGui.SetNextWindowPos(ImVec2(DEMO_RECT[1], DEMO_RECT[2]), Cond.Always); ImGui.SetNextWindowSize(ImVec2(DEMO_RECT[3], DEMO_RECT[4]), Cond.Always)
    end
    return realBegin(name, ...)
end

local function Pos(x, y, w, h) ImGui.SetNextWindowPos(ImVec2(x, y), Cond.Always); if w then ImGui.SetNextWindowSize(ImVec2(w, h), Cond.Always) end end

-- ---------------------------------------------------------------- scenes
-- Each: crop {x, y, w, h}, frames to capture (list), mouse position, draw(frame)
local scenes = {}

-- README "Usage" example, verbatim
local f, counter = 0.6, 0
local buf = ImGui.NewTextBuffer("Hello, world!", 256)
local my_color = ImVec4(1.0, 0.4, 0.2, 1.0)
local function HelloWorld()
    ImGui.Begin("My First Tool")
    ImGui.Text("Hello, world %d", 123)
    if ImGui.Button("Save") then counter += 1 end
    ImGui.InputText("string", buf, 256)
    f = ImGui.SliderFloat("float", f, 0.0, 1.0)
    ImGui.ColorEdit4("Color", my_color)
    ImGui.End()
end

scenes.hello = { crop = { 0, 0, 420, 200 }, shots = { 30 }, mouse = { 1900, 1060 }, draw = function()
    Pos(10, 10, 400, 180); HelloWorld()
end }

scenes.demo = { crop = { 0, 0, 1000, 740 }, shots = { 40 }, mouse = { 640, 330 }, draw = function()
    OPEN["Widgets"] = true; OPEN["Basic"] = true
    Pos(10, 10, 380, 200)
    ImGui.Begin("Hello, world!")
    ImGui.Text("This is some useful text.")
    ImGui.Checkbox("Demo Window", true)
    ImGui.SliderFloat("float", 0.42, 0.0, 1.0)
    ImGui.Button("Button"); ImGui.SameLine(); ImGui.Text("counter = %d", 3)
    ImGui.Text("Application average %.3f ms/frame (%.1f FPS)", 16.667, 60.0)
    ImGui.End()
    DEMO_RECT = { 410, 10, 580, 720 }; ImGui.ShowDemoWindow()
end }

scenes.tables = { crop = { 0, 0, 700, 740 }, shots = { 40 }, mouse = { 1900, 1060 }, draw = function()
    OPEN["Tables & Columns"] = true; OPEN["Borders, background"] = true; OPEN["Sorting"] = true
    DEMO_RECT = { 10, 10, 680, 720 }; ImGui.ShowDemoWindow()
end }

scenes.style = { crop = { 0, 0, 560, 740 }, shots = { 40 }, mouse = { 1900, 1060 }, draw = function()
    SELECT_TAB = "Colors"
    Pos(10, 10, 540, 720); ImGui.Begin("Dear ImGui Style Editor"); ImGui.ShowStyleEditor(); ImGui.End()
end }

scenes.metrics = { crop = { 0, 0, 620, 560 }, shots = { 40 }, mouse = { 1900, 1060 }, draw = function()
    OPEN["Windows"] = true; OPEN["DrawLists"] = true
    Pos(10, 10, 600, 540); ImGui.ShowMetricsWindow()
end }

scenes.docking = { crop = { 0, 0, 1100, 640 }, shots = { 40 }, mouse = { 1900, 1060 }, draw = function(frame)
    Pos(10, 10, 1080, 620)
    ImGui.Begin("Editor", nil, G.ImGuiWindowFlags.MenuBar)
    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu("File") then ImGui.EndMenu() end
        if ImGui.BeginMenu("View") then ImGui.EndMenu() end
        ImGui.EndMenuBar()
    end
    local id = ImGui.GetID("MainDock")
    if frame == 2 then
        ImGui.DockBuilderRemoveNode(id)
        ImGui.DockBuilderAddNode(id, G.ImGuiDockNodeFlags.None)
        ImGui.DockBuilderSetNodeSize(id, ImVec2(1064, 560))
        local left, right = ImGui.DockBuilderSplitNode(id, G.ImGuiDir.Left, 0.3)
        local rtop, rbottom = ImGui.DockBuilderSplitNode(right, G.ImGuiDir.Up, 0.65)
        ImGui.DockBuilderDockWindow("Scene", left)
        ImGui.DockBuilderDockWindow("Inspector", rtop)
        ImGui.DockBuilderDockWindow("Properties", rtop)
        ImGui.DockBuilderDockWindow("Console", rbottom)
        ImGui.DockBuilderFinish(id)
    end
    ImGui.DockSpace(id)
    ImGui.End()
    ImGui.Begin("Scene")
    for _, n in ipairs({ "Workspace", "Lighting", "Players", "ReplicatedStorage" }) do
        if ImGui.TreeNode(n) then ImGui.BulletText("Part"); ImGui.BulletText("Model"); ImGui.TreePop() end
    end
    ImGui.End()
    ImGui.Begin("Inspector")
    ImGui.SeparatorText("Transform")
    ImGui.DragFloat3("Position", { 12.0, 4.5, -3.0 }, 0.1)
    ImGui.DragFloat3("Rotation", { 0.0, 90.0, 0.0 }, 1.0)
    ImGui.SeparatorText("Appearance")
    ImGui.ColorEdit3("Color", ImVec4(0.2, 0.6, 1.0, 1.0))
    ImGui.SliderFloat("Transparency", 0.25, 0.0, 1.0)
    ImGui.Checkbox("Anchored", true); ImGui.SameLine(); ImGui.Checkbox("CanCollide", false)
    ImGui.End()
    ImGui.Begin("Properties"); ImGui.Text("Properties"); ImGui.End()
    ImGui.Begin("Console")
    for i = 1, 6 do ImGui.TextColored(ImVec4(0.6, 0.9, 0.6, 1), "[%02d:00] Loaded chunk %d", i, i * 7) end
    ImGui.End()
end }

-- README plot example (animated -> GIF)
local values, hist = {}, { 0.6, 0.1, 1.0, 0.5, 0.92, 0.1, 0.2 }
scenes.plot = { crop = { 0, 0, 440, 330 }, shots = {}, mouse = { 1900, 1060 }, draw = function(frame)
    local t = frame / 30
    for i = 1, 90 do values[i] = math.sin((i / 90) * math.pi * 4 + t * 3) * math.cos(t + i * 0.05) end
    for i = 1, #hist do hist[i] = 0.5 + 0.5 * math.sin(t * 2 + i) end
    Pos(10, 10, 420, 310)
    ImGui.Begin("Plotting")
    ImGui.PlotLines("Lines", values, nil, #values, 0, "sine", -1.0, 1.0, ImVec2(0, 90))
    ImGui.PlotHistogram("Histogram", hist, nil, #hist, 0, nil, 0.0, 1.0, ImVec2(0, 90))
    ImGui.ProgressBar((t * 0.4) % 1.0, ImVec2(-1, 0))
    ImGui.Text("frame %d", frame)
    ImGui.End()
end }
for i = 30, 149 do table.insert(scenes.plot.shots, i) end

scenes.drawlist = { crop = { 0, 0, 380, 300 }, shots = { 30 }, mouse = { 1900, 1060 }, draw = function()
    Pos(10, 10, 360, 280)
    ImGui.Begin("Custom drawing")
    local dl = ImGui.GetWindowDrawList()
    local p = ImGui.GetCursorScreenPos()
    dl:AddRectFilled(p, p + ImVec2(100, 100), G.IM_COL32(255, 120, 60, 255), 12.0)
    dl:AddCircleFilled(p + ImVec2(170, 50), 45, G.IM_COL32(80, 160, 255, 255))
    dl:AddTriangleFilled(p + ImVec2(230, 100), p + ImVec2(280, 0), p + ImVec2(330, 100), G.IM_COL32(120, 220, 120, 255))
    dl:AddBezierCubic(p + ImVec2(0, 140), p + ImVec2(100, 100), p + ImVec2(200, 220), p + ImVec2(330, 150), G.IM_COL32(255, 255, 0, 255), 3.0)
    dl:AddText(p + ImVec2(0, 190), G.IM_COL32(255, 255, 255, 255), "ImDrawList: lines, shapes, text")
    ImGui.Dummy(ImVec2(330, 220))
    ImGui.End()
end }

-- README hero: same "Debug" window in the dark and light styles (like upstream's README)
local dbg_buf = ImGui.NewTextBuffer("quick brown fox", 256)
local function DebugWindow(title)
    ImGui.Begin(title)
    ImGui.Text("Hello, world %d", 123)
    ImGui.Button("Save")
    ImGui.InputText("string", dbg_buf, 256)
    ImGui.SliderFloat("float", 0.6, 0.0, 1.0)
    ImGui.End()
end
scenes.debug = { crop = { 0, 0, 540, 150 }, shots = { 30 }, mouse = { 140, 113 }, cursor = true, draw = function()
    Pos(10, 10, 250, 130); DebugWindow("Debug##dark")
    local saved = {}
    for i, c in pairs(ImGui.GetStyle().Colors) do saved[i] = ImVec4(c.x, c.y, c.z, c.w) end
    ImGui.StyleColorsLight()
    Pos(280, 10, 250, 130); DebugWindow("Debug##light")
    for i, c in pairs(saved) do G.ImVec4_Copy(ImGui.GetStyle().Colors[i], c) end
end }

-- README "My First Tool" (verbatim from README.md / t_readme.luau), with the color picker popup opened by a click
local my_tool_active, tool_color = true, ImVec4(0.455, 0.282, 0.455, 1.0)
local samples = {}
local btn = nil
scenes.tool = { crop = { 0, 0, 560, 420 }, shots = { 40 }, cursor = true,
    mouse = function(frame) if frame < 16 then return btn and btn[1] or 5, btn and btn[2] or 5 end return 300, 240 end,
    button = function(frame) if frame == 12 then return true elseif frame == 13 then return false end end,
    draw = function()
    io.ConfigColorEditFlags = bit32.bor(G.ImGuiColorEditFlags.PickerHueWheel, G.ImGuiColorEditFlags.Uint8, G.ImGuiColorEditFlags.DisplayRGB, G.ImGuiColorEditFlags.InputRGB)
    Pos(10, 10, 340, 330)
    -- [snippet:tool]
    -- Create a window called "My First Tool", with a menu bar.
    my_tool_active = ImGui.Begin("My First Tool", my_tool_active, G.ImGuiWindowFlags.MenuBar)
    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu("File") then
            if ImGui.MenuItem("Open..", "Ctrl+O") then --[[ Do stuff ]] end
            if ImGui.MenuItem("Save", "Ctrl+S") then --[[ Do stuff ]] end
            if ImGui.MenuItem("Close", "Ctrl+W") then my_tool_active = false end
            ImGui.EndMenu()
        end
        ImGui.EndMenuBar()
    end

    -- Edit a color stored as 4 floats
    local p, w, h = ImGui.GetCursorScreenPos(), ImGui.CalcItemWidth(), ImGui.GetFrameHeight()
    btn = { p.x + w - h * 0.5, p.y + h * 0.5 }
    ImGui.ColorEdit4("Color", tool_color)

    -- Generate samples and plot them
    for n = 1, 100 do samples[n] = math.sin((n - 1) * 0.2 + ImGui.GetTime() * 1.5) end
    ImGui.PlotLines("Samples", samples, nil, 100)

    -- Display contents in a scrolling region
    ImGui.TextColored(ImVec4(1, 1, 0, 1), "Important Stuff")
    ImGui.BeginChild("Scrolling")
    for n = 0, 49 do ImGui.Text("%04d: Some text", n) end
    ImGui.EndChild()
    ImGui.End()
    -- [/snippet]
end }

local SC = assert(scenes[SCENE], "unknown SCENE")
io.MouseDrawCursor = SC.cursor == true

-- ---------------------------------------------------------------- compositor
local CX, CY, CW, CH = SC.crop[1], SC.crop[2], SC.crop[3], SC.crop[4]
local function composite(gui)
    local screen = buffer.create(CW * CH * 3)
    for i = 0, CW * CH - 1 do buffer.writeu8(screen, i * 3, BG[1]); buffer.writeu8(screen, i * 3 + 1, BG[2]); buffer.writeu8(screen, i * 3 + 2, BG[3]) end
    local function walk(inst, ox, oy, kx0, ky0, kx1, ky1)
        local kids = inst:GetChildren()
        table.sort(kids, function(a, b) return (a.ZIndex or 1) < (b.ZIndex or 1) end)
        for _, c in ipairs(kids) do
            if c.Visible ~= false then
                local x, y = ox + (c.Position and c.Position.X or 0), oy + (c.Position and c.Position.Y or 0)
                local cx0, cy0, cx1, cy1 = kx0, ky0, kx1, ky1
                if c.ClipsDescendants then
                    cx0, cy0 = math.max(cx0, x), math.max(cy0, y)
                    cx1, cy1 = math.min(cx1, x + c.Size.X), math.min(cy1, y + c.Size.Y)
                end
                if c.ClassName == "ImageLabel" then
                    local img = c.ImageContent.Object
                    local px, sz = img.Pixels, img.Size.X
                    for ty = 0, sz - 1 do
                        local sy = y + ty
                        if sy >= ky0 and sy < ky1 then
                            for tx = 0, sz - 1 do
                                local sx = x + tx
                                if sx >= kx0 and sx < kx1 then
                                    local o = (ty * sz + tx) * 4
                                    local a = buffer.readu8(px, o + 3)
                                    if a > 0 then
                                        local d = ((sy - CY) * CW + (sx - CX)) * 3
                                        local fa = a / 255
                                        for ch = 0, 2 do
                                            local v = buffer.readu8(px, o + ch) * fa + buffer.readu8(screen, d + ch) * (1 - fa)
                                            buffer.writeu8(screen, d + ch, math.floor(v + 0.5))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                walk(c, x, y, cx0, cy0, cx1, cy1)
            end
        end
    end
    walk(gui, 0, 0, CX, CY, CX + CW, CY + CH)
    return screen
end

local shoot = {}
for _, s in ipairs(SC.shots) do shoot[s] = true end
local frame = 0
game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    io.DeltaTime = 1 / 30
    if type(SC.mouse) == "function" then io:AddMousePosEvent(SC.mouse(frame)) else io:AddMousePosEvent(SC.mouse[1], SC.mouse[2]) end
    local b = SC.button and SC.button(frame)
    if b ~= nil then io:AddMouseButtonEvent(0, b) end
    ImGui.NewFrame()
    SC.draw(frame)
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if shoot[frame] then
        local screen = composite(game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ImGui"))
        print("SIZE", CW, CH)
        for y = 0, CH - 1 do
            local t = table.create(CW * 3)
            for i = 0, CW * 3 - 1 do t[i + 1] = string.format("%02x", buffer.readu8(screen, y * CW * 3 + i)) end
            print("PX", frame, y, table.concat(t))
        end
    end
end)
