-- Dear ImGui extensions on LÖVE:  python3 tools/bundle.py --target love  then  love examples/example_love_extensions
local ROOT = love.filesystem.getSource() .. "/../../"   -- repo root (build/, fonts/, extensions/)
local f = assert(io.open(ROOT .. "build/imgui_love.lua", "rb"), "run: python3 tools/bundle.py --target love")
local G = assert(loadstring(f:read("*a"), "@imgui_love.lua"))(); f:close()
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
local _

-- Each extension repo ships a LÖVE/LuaJIT build in its love/ folder (regenerate with <repo>/tools/love.sh)
local function LoadExt(repo, name)
    return assert(loadfile(ROOT .. "extensions/" .. repo .. "/love/" .. name))()
end

-- catppuccin mocha mauve https://catppuccin.com/palette
local Crust, Mantle, Base = 0x11111b, 0x181825, 0x1e1e2e
local Surface0, Surface1, Surface2 = 0x313244, 0x45475a, 0x585b70
local Overlay0, Overlay2, Text = 0x6c7086, 0x9399b2, 0xcdd6f4
local Mauve, Lavender = 0xcba6f7, 0xb4befe
local Red, Peach, Yellow, Green, Blue, Pink = 0xf38ba8, 0xfab387, 0xf9e2af, 0xa6e3a1, 0x89b4fa, 0xf5c2e7

local function Col32(Value, Alpha)
    return G.IM_COL32(bit32.extract(Value, 16, 8), bit32.extract(Value, 8, 8), bit32.extract(Value, 0, 8),
        math.floor((Alpha or 1.0) * 255 + 0.5))
end

local function StyleColorsCatppuccinMocha(Style)
    local function Hex(Value, Alpha)
        return ImVec4(bit32.extract(Value, 16, 8) / 255, bit32.extract(Value, 8, 8) / 255, bit32.extract(Value, 0, 8) / 255, Alpha or 1.0)
    end
    local Entries = {
        { "Text", Text }, { "TextDisabled", Overlay0 },
        { "WindowBg", Base }, { "ChildBg", Base, 0.0 }, { "PopupBg", Mantle, 0.98 }, { "Border", Surface1 }, { "BorderShadow", Crust, 0.0 },
        { "FrameBg", Surface0 }, { "FrameBgHovered", Surface1 }, { "FrameBgActive", Surface2 },
        { "TitleBg", Mantle }, { "TitleBgActive", Crust }, { "TitleBgCollapsed", Mantle, 0.75 }, { "MenuBarBg", Mantle },
        { "ScrollbarBg", Mantle }, { "ScrollbarGrab", Surface1 }, { "ScrollbarGrabHovered", Surface2 }, { "ScrollbarGrabActive", Overlay0 },
        { "CheckMark", Mauve }, { "CheckboxSelectedBg", Surface0 }, { "SliderGrab", Mauve, 0.8 }, { "SliderGrabActive", Mauve },
        { "Button", Surface0 }, { "ButtonHovered", Surface1 }, { "ButtonActive", Mauve, 0.6 },
        { "Header", Surface0 }, { "HeaderHovered", Surface1 }, { "HeaderActive", Mauve, 0.5 },
        { "Separator", Surface1 }, { "SeparatorHovered", Mauve, 0.7 }, { "SeparatorActive", Mauve },
        { "ResizeGrip", Mauve, 0.2 }, { "ResizeGripHovered", Mauve, 0.6 }, { "ResizeGripActive", Mauve, 0.9 },
        { "InputTextCursor", Text },
        { "Tab", Surface0 }, { "TabHovered", Surface2 }, { "TabSelected", Surface1 }, { "TabSelectedOverline", Mauve },
        { "TabDimmed", Mantle }, { "TabDimmedSelected", Surface0 }, { "TabDimmedSelectedOverline", Overlay0 },
        { "DockingPreview", Mauve, 0.7 }, { "DockingEmptyBg", Crust },
        { "PlotLines", Overlay2 }, { "PlotLinesHovered", Mauve }, { "PlotHistogram", Mauve, 0.8 }, { "PlotHistogramHovered", Lavender },
        { "TableHeaderBg", Surface0 }, { "TableBorderStrong", Surface1 }, { "TableBorderLight", Surface0 }, { "TableRowBg", Base, 0.0 }, { "TableRowBgAlt", Surface0, 0.3 },
        { "TextLink", Mauve }, { "TextSelectedBg", Mauve, 0.35 }, { "TreeLines", Surface2 }, { "DragDropTarget", Mauve, 0.9 },
        { "NavCursor", Lavender }, { "NavWindowingHighlight", Lavender, 0.7 }, { "NavWindowingDimBg", Crust, 0.5 }, { "ModalWindowDimBg", Crust, 0.6 },
    }
    for _, E in ipairs(Entries) do
        Style.Colors[G.ImGuiCol[E[1]]] = Hex(E[2], E[3])
    end
end

local Demos = {}

local CurveLabels = { "Translation", "Rotation", "Scale" }
local function NewRampEdit(ImCurveEdit, Min, Max)
    local R = {
        mPts = {
            { ImVec2(-10, 0), ImVec2(20, 0.6), ImVec2(25, 0.2), ImVec2(70, 0.4), ImVec2(120, 1) },
            { ImVec2(-50, 0.2), ImVec2(33, 0.7), ImVec2(80, 0.2), ImVec2(82, 0.8) },
            { ImVec2(40, 0), ImVec2(60, 0.1), ImVec2(90, 0.82), ImVec2(150, 0.24), ImVec2(200, 0.34), ImVec2(250, 0.12) },
        },
        mbVisible = { true, true, true }, mMin = Min, mMax = Max,
    }
    function R:GetCurveCount() return 3 end
    function R:IsVisible(c) return self.mbVisible[c] end
    function R:GetPointCount(c) return #self.mPts[c] end
    function R:GetCurveColor(c) return ({ 0xFF0000FF, 0xFF00FF00, 0xFFFF0000 })[c] end
    function R:GetPoints(c) return self.mPts[c] end
    function R:GetCurveType() return ImCurveEdit.CurveSmooth end
    function R:SortValues(c) table.sort(self.mPts[c], function(a, b) return a.x < b.x end) end
    function R:EditPoint(c, p, value)
        self.mPts[c][p] = ImVec2(value.x, value.y)
        self:SortValues(c)
        for i, pt in ipairs(self.mPts[c]) do if pt.x == value.x then return i end end
        return p
    end
    function R:AddPoint(c, value)
        if #self.mPts[c] >= 8 then return end
        table.insert(self.mPts[c], value)
        self:SortValues(c)
    end
    function R:GetMax() return self.mMax end
    function R:GetMin() return self.mMin end
    function R:GetBackgroundColor() return 0 end
    return R
end

-- ImCurveEdit
do
    local D = { Name = "ImCurveEdit" }
    local ImCurveEdit, RampEdit, Selected
    function D.Init()
        ImCurveEdit = LoadExt("imcurveedit-luau", "ImCurveEdit.lua")(G)
        RampEdit, Selected = NewRampEdit(ImCurveEdit, ImVec2(-100, 0), ImVec2(300, 1)), {}
    end
    function D.Draw()
        ImGui.SetNextWindowSize(ImVec2(700, 400), G.ImGuiCond.FirstUseEver)
        D.Show = ImGui.Begin("ImCurveEdit", D.Show)
        for i = 1, 3 do
            _, RampEdit.mbVisible[i] = ImGui.Checkbox(CurveLabels[i], RampEdit.mbVisible[i])
            ImGui.SameLine()
        end
        ImGui.Text("selected: %d", #Selected)
        local Avail = ImGui.GetContentRegionAvail()
        _, Selected = ImCurveEdit.Edit(RampEdit, ImVec2(Avail.x, Avail.y), 137, nil, Selected)
        ImGui.End()
    end
    table.insert(Demos, D)
end

-- ImGradient
do
    local D = { Name = "ImGradient" }
    local ImGradient, Gradient, Selection = nil, nil, -1
    local Size = ImVec2(400, 24)
    function D.Init()
        ImGradient = LoadExt("imgradient-luau", "ImGradient.lua")(G)
        Gradient = { Points = { ImVec4(1, 0.2, 0.2, 0), ImVec4(1, 0.9, 0.2, 0.4), ImVec4(0.2, 0.4, 1, 1) } }
        function Gradient:GetPointCount() return #self.Points end
        function Gradient:GetPoints() return self.Points end
        function Gradient:EditPoint(i, v) self.Points[i] = v; return i end
        function Gradient:AddPoint(v) table.insert(self.Points, v) end
        function Gradient:Sorted()
            local s = table.clone(self.Points)
            table.sort(s, function(a, b) return a.w < b.w end)
            return s
        end
    end
    function D.Draw()
        D.Show = ImGui.Begin("ImGradient", D.Show)
        local Pos = ImGui.GetCursorScreenPos()
        local Dl, S = ImGui.GetWindowDrawList(), Gradient:Sorted()
        local X0 = Pos.x
        for i = 0, #S do
            local a, b = S[math.max(i, 1)], S[math.min(i + 1, #S)]
            local X1 = Pos.x + Size.x * (i < #S and b.w or 1)
            local Ca = ImGui.ColorConvertFloat4ToU32(ImVec4(a.x, a.y, a.z, 1))
            local Cb = ImGui.ColorConvertFloat4ToU32(ImVec4(b.x, b.y, b.z, 1))
            if X1 > X0 then Dl:AddRectFilledMultiColor(ImVec2(X0, Pos.y), ImVec2(X1, Pos.y + Size.y), Ca, Cb, Cb, Ca) end
            X0 = X1
        end
        _, Selection = ImGradient.Edit(Gradient, Size, Selection)
        ImGui.Text("points: %d  selection: %d", #Gradient.Points, Selection)
        local P = Gradient.Points[Selection]
        if P then
            local Col = ImVec4(P.x, P.y, P.z, 1)
            if ImGui.ColorEdit3("color", Col) then Gradient:EditPoint(Selection, ImVec4(Col.x, Col.y, Col.z, P.w)) end
            if ImGui.Button("Delete point") and #Gradient.Points > 2 then table.remove(Gradient.Points, Selection); Selection = -1 end
        end
        ImGui.End()
    end
    table.insert(Demos, D)
end

-- ImSequencer
do
    local D = { Name = "ImSequencer" }
    local ImSequencer, ImCurveEdit, RampEdit, MySequence, Options
    local TypeNames = { "Camera", "Music", "ScreenEffect", "FadeIn", "Animation" }
    local SelectedEntry, FirstFrame, Expanded, CurrentFrame = -1, 0, true, 100
    function D.Init()
        ImSequencer = LoadExt("imsequencer-luau", "ImSequencer.lua")(G)
        ImCurveEdit = LoadExt("imcurveedit-luau", "ImCurveEdit.lua")(G)
        RampEdit = NewRampEdit(ImCurveEdit, ImVec2(0, 0), ImVec2(1, 1))
        local function Item(t, s, e, x) return { mType = t, mFrameStart = s, mFrameEnd = e, mExpanded = x } end
        MySequence = { mFrameMin = -100, mFrameMax = 1000 }
        MySequence.myItems = { Item(1, 10, 30, false), Item(2, 20, 30, true), Item(4, 12, 60, false), Item(3, 61, 90, false), Item(5, 90, 99, false) }
        function MySequence:GetFrameMin() return self.mFrameMin end
        function MySequence:GetFrameMax() return self.mFrameMax end
        function MySequence:GetItemCount() return #self.myItems end
        function MySequence:GetItemTypeCount() return #TypeNames end
        function MySequence:GetItemTypeName(t) return TypeNames[t] end
        function MySequence:GetItemLabel(i) return string.format("[%02d] %s", i - 1, TypeNames[self.myItems[i].mType]) end
        function MySequence:Get(i)
            local it = self.myItems[i]
            return it.mFrameStart, it.mFrameEnd, it.mType, 0xFFAA8080
        end
        function MySequence:Set(i, s, e) local it = self.myItems[i]; it.mFrameStart, it.mFrameEnd = s, e end
        function MySequence:Add(t) table.insert(self.myItems, Item(t, 0, 10, false)) end
        function MySequence:Del(i) table.remove(self.myItems, i) end
        function MySequence:Duplicate(i) table.insert(self.myItems, table.clone(self.myItems[i])) end
        function MySequence:GetCustomHeight(i) return self.myItems[i].mExpanded and 300 or 0 end
        function MySequence:DoubleClick(i)
            if self.myItems[i].mExpanded then self.myItems[i].mExpanded = false; return end
            for _, it in ipairs(self.myItems) do it.mExpanded = false end
            self.myItems[i].mExpanded = true
        end
        function MySequence:CustomDraw(i, dl, rc, legendRect, clippingRect, legendClippingRect)
            RampEdit.mMax = ImVec2(self.mFrameMax, 1)
            RampEdit.mMin = ImVec2(self.mFrameMin, 0)
            dl:PushClipRect(legendClippingRect.Min, legendClippingRect.Max, true)
            for c = 1, 3 do
                local pta = ImVec2(legendRect.Min.x + 30, legendRect.Min.y + (c - 1) * 14)
                local ptb = ImVec2(legendRect.Max.x, legendRect.Min.y + c * 14)
                dl:AddText(pta, RampEdit.mbVisible[c] and 0xFFFFFFFF or 0x80FFFFFF, CurveLabels[c])
                if G.ImRect(pta, ptb):Contains(ImGui.GetMousePos()) and ImGui.IsMouseClicked(0) then
                    RampEdit.mbVisible[c] = not RampEdit.mbVisible[c]
                end
            end
            dl:PopClipRect()
            ImGui.SetCursorScreenPos(rc.Min)
            ImCurveEdit.Edit(RampEdit, ImVec2(rc.Max.x - rc.Min.x, rc.Max.y - rc.Min.y), 137 + i, clippingRect)
        end
        function MySequence:CustomDrawCompact(i, dl, rc, clippingRect)
            RampEdit.mMax = ImVec2(self.mFrameMax, 1)
            RampEdit.mMin = ImVec2(self.mFrameMin, 0)
            dl:PushClipRect(clippingRect.Min, clippingRect.Max, true)
            local it = self.myItems[i]
            for c = 1, 3 do
                for _, pt in ipairs(RampEdit.mPts[c]) do
                    local p = pt.x
                    if p >= it.mFrameStart and p <= it.mFrameEnd then
                        local x = rc.Min.x + (rc.Max.x - rc.Min.x) * (p - self.mFrameMin) / (self.mFrameMax - self.mFrameMin)
                        dl:AddLine(ImVec2(x, rc.Min.y + 6), ImVec2(x, rc.Max.y - 4), 0xAA000000, 4)
                    end
                end
            end
            dl:PopClipRect()
        end
        local S = ImSequencer
        Options = bit32.bor(S.SEQUENCER_EDIT_STARTEND, S.SEQUENCER_ADD, S.SEQUENCER_DEL, S.SEQUENCER_COPYPASTE, S.SEQUENCER_CHANGE_FRAME)
    end
    function D.Draw()
        ImGui.SetNextWindowSize(ImVec2(900, 600), G.ImGuiCond.FirstUseEver)
        D.Show = ImGui.Begin("ImSequencer", D.Show)
        ImGui.PushItemWidth(130)
        MySequence.mFrameMin = ImGui.InputInt("Frame Min", MySequence.mFrameMin)
        ImGui.SameLine()
        CurrentFrame = ImGui.InputInt("Frame ", CurrentFrame)
        ImGui.SameLine()
        MySequence.mFrameMax = ImGui.InputInt("Frame Max", MySequence.mFrameMax)
        ImGui.PopItemWidth()
        _, CurrentFrame, Expanded, SelectedEntry, FirstFrame = ImSequencer.Sequencer(MySequence, CurrentFrame, Expanded, SelectedEntry, FirstFrame, Options)
        if SelectedEntry ~= -1 then
            ImGui.Text("I am a %s, please edit me", TypeNames[MySequence.myItems[SelectedEntry].mType])
        end
        ImGui.End()
    end
    table.insert(Demos, D)
end

-- imgui_memory_editor
do
    local D = { Name = "Memory Editor" }
    local ffi = require("ffi")
    local Data, Ptr, MemEdit, MemEdit2, Frame = nil, nil, nil, nil, 0
    function D.Init()
        local MemoryEditor = LoadExt("imgui-memory-editor-luau", "MemoryEditor.lua")(G)
        Data = love.data.newByteData(0x400)
        Ptr = ffi.cast("uint8_t*", Data:getFFIPointer())
        ffi.cast("float*", Ptr + 0x10)[0] = math.pi
        ffi.copy(Ptr + 0x20, "Hello from a LOVE ByteData!")
        for i = 0x40, 0x3FF do Ptr[i] = (i * 37) % 256 end
        MemEdit = MemoryEditor.new()
        MemEdit.OptShowDataPreview = true
        MemEdit2 = MemoryEditor.new()
        MemEdit2.HighlightFn = function(_, off) return Ptr[off] % 2 == 0 end
    end
    function D.Draw()
        Frame = Frame + 1
        ffi.cast("uint32_t*", Ptr)[0] = Frame
        MemEdit:DrawWindow("Memory Editor", Data)
        local Open, Visible = ImGui.Begin("Memory Editor (DrawContents)", D.Show)
        D.Show = Open
        if Visible then
            ImGui.Text("frame = %d (the u32 at 0x00)", Frame)
            MemEdit2:DrawContents(Data, 0x80, 0x1000)
        end
        ImGui.End()
    end
    table.insert(Demos, D)
end

-- ImGuizmo (fixed camera, one cube; matrices are column-major float[16] like upstream)
do
    local D = { Name = "ImGuizmo" }
    local ImGuizmo, OP, MODE
    local Operation, Mode
    local UseSnap, ShowGrid = false, true
    local Snap = { 1, 1, 1 }
    local AngleSnap, ScaleSnap = 15, 0.1
    local BoundSizing, BoundSizingSnap = false, false
    local Bounds = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 }
    local BoundsSnap = { 0.1, 0.1, 0.1 }
    local Identity = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
    local Object = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
    local View

    local function Cross(a, b) return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] } end
    local function Norm(a) local l = math.sqrt(a[1] ^ 2 + a[2] ^ 2 + a[3] ^ 2); return { a[1] / l, a[2] / l, a[3] / l } end
    local function Dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
    -- upstream example's LookAt / Perspective
    local function LookAt(eye, at, up)
        local z = Norm({ eye[1] - at[1], eye[2] - at[2], eye[3] - at[3] })
        local x = Norm(Cross(up, z))
        local y = Norm(Cross(z, x))
        return { x[1], y[1], z[1], 0, x[2], y[2], z[2], 0, x[3], y[3], z[3], 0, -Dot(x, eye), -Dot(y, eye), -Dot(z, eye), 1 }
    end
    local function Perspective(fovy, aspect, n, fa)
        local ymax = n * math.tan(fovy * math.pi / 360)
        local xmax = ymax * aspect
        local t2, w, h, d = 2 * n, 2 * xmax, 2 * ymax, fa - n
        return { t2 / w, 0, 0, 0, 0, t2 / h, 0, 0, 0, 0, (-fa - n) / d, -1, 0, 0, (-t2 * fa) / d, 0 }
    end

    function D.Init()
        ImGuizmo = LoadExt("imguizmo-luau", "ImGuizmo.lua")(G)
        OP, MODE = ImGuizmo.OPERATION, ImGuizmo.MODE
        Operation, Mode = OP.TRANSLATE, MODE.WORLD
        View = LookAt({ 6, 5, 8 }, { 0, 0, 0 }, { 0, 1, 0 })
    end

    local function EditTransform(Matrix)
        local K = G.ImGuiKey
        if ImGui.IsKeyPressed(K.T) then Operation = OP.TRANSLATE end
        if ImGui.IsKeyPressed(K.E) then Operation = OP.ROTATE end
        if ImGui.IsKeyPressed(K.R) then Operation = OP.SCALE end
        _, Operation = ImGui.RadioButton("Translate", Operation, OP.TRANSLATE); ImGui.SameLine()
        _, Operation = ImGui.RadioButton("Rotate", Operation, OP.ROTATE); ImGui.SameLine()
        _, Operation = ImGui.RadioButton("Scale", Operation, OP.SCALE); ImGui.SameLine()
        _, Operation = ImGui.RadioButton("Universal", Operation, OP.UNIVERSAL)

        local Tr, Rt, Sc = {}, {}, {}
        ImGuizmo.DecomposeMatrixToComponents(Matrix, Tr, Rt, Sc)
        local Edited = ImGui.DragFloat3("Tr", Tr, 0.1)
        Edited = ImGui.DragFloat3("Rt", Rt, 1) or Edited
        Edited = ImGui.DragFloat3("Sc", Sc, 0.01) or Edited
        if Edited then ImGuizmo.RecomposeMatrixFromComponents(Tr, Rt, Sc, Matrix) end

        if Operation ~= OP.SCALE then
            _, Mode = ImGui.RadioButton("Local", Mode, MODE.LOCAL); ImGui.SameLine()
            _, Mode = ImGui.RadioButton("World", Mode, MODE.WORLD)
        end
        _, UseSnap = ImGui.Checkbox("Snap", UseSnap); ImGui.SameLine()
        if Operation == OP.ROTATE then
            AngleSnap = ImGui.DragFloat("Angle Snap", AngleSnap, 1)
        elseif Operation == OP.SCALE then
            ScaleSnap = ImGui.DragFloat("Scale Snap", ScaleSnap, 0.01)
        else
            ImGui.DragFloat3("Snap Value", Snap, 0.1)
        end
        if Operation == OP.SCALE then
            _, BoundSizing = ImGui.Checkbox("Bound Sizing", BoundSizing)
            if BoundSizing then
                ImGui.PushID(3)
                _, BoundSizingSnap = ImGui.Checkbox("Bound Snap", BoundSizingSnap); ImGui.SameLine()
                ImGui.DragFloat3("Snap", BoundsSnap, 0.01)
                ImGui.PopID()
            end
        end
        _, ShowGrid = ImGui.Checkbox("Show Grid", ShowGrid)

        local SnapArg
        if UseSnap then
            if Operation == OP.ROTATE then SnapArg = { AngleSnap, AngleSnap, AngleSnap }
            elseif Operation == OP.SCALE then SnapArg = { ScaleSnap, ScaleSnap, ScaleSnap }
            else SnapArg = Snap end
        end
        return SnapArg
    end

    function D.Draw()
        ImGuizmo.BeginFrame()
        local W, H = love.graphics.getDimensions()
        local Proj = Perspective(45, W / H, 0.1, 100)
        ImGuizmo.SetDrawlist(ImGui.GetBackgroundDrawList())
        ImGuizmo.SetRect(0, 0, W, H)

        D.Show = ImGui.Begin("ImGuizmo", D.Show)
        local SnapArg = EditTransform(Object)
        ImGui.End()

        if ShowGrid then ImGuizmo.DrawGrid(View, Proj, Identity, 10) end
        ImGuizmo.DrawCubes(View, Proj, Object, 1)
        -- Bound Sizing replaces the scale gizmo (BOUNDS draws only the bounds box)
        local UseBounds = BoundSizing and Operation == OP.SCALE
        ImGuizmo.Manipulate(View, Proj, UseBounds and OP.BOUNDS or Operation, Mode, Object, nil, SnapArg,
            UseBounds and Bounds or nil, UseBounds and BoundSizingSnap and BoundsSnap or nil)
        ImGuizmo.ViewManipulate(View, 10, ImVec2(W - 128, 0), ImVec2(128, 128), 0x10101010)
    end
    table.insert(Demos, D)
end

-- ImNodes (Logic Simulator)
do
    local D = { Name = "ImNodes" }
    local UI
    function D.Init()
        local ImNodes = LoadExt("imnodes-luau", "ImNodes.lua")(G)
        local LogicSim = LoadExt("imnodes-luau", "LogicSim.lua")(G, ImNodes)
        UI = LoadExt("imnodes-luau", "LogicUI.lua")(G, ImNodes, LogicSim)

        ImNodes.CreateContext()
        ImNodes.PushAttributeFlag(ImNodes.ImNodesAttributeFlags.EnableLinkDetachWithDragClick)
        local NodesIO = ImNodes.GetIO()
        local KeyCtrl = function() return ImGui.GetIO().KeyCtrl end
        NodesIO.LinkDetachWithModifierClick.Modifier = KeyCtrl
        NodesIO.MultipleSelectModifier.Modifier = KeyCtrl
        local NodesStyle = ImNodes.GetStyle()
        NodesStyle.Flags = bit32.bor(NodesStyle.Flags, ImNodes.ImNodesStyleFlags.GridLinesPrimary)

        -- catppuccin mocha
        local Col, C = ImNodes.ImNodesCol, NodesStyle.Colors
        C[Col.NodeBackground] = Col32(Surface0)
        C[Col.NodeBackgroundHovered] = Col32(Surface1)
        C[Col.NodeBackgroundSelected] = Col32(Surface1)
        C[Col.NodeOutline] = Col32(Surface2)
        C[Col.TitleBar] = Col32(Mantle)
        C[Col.TitleBarHovered] = Col32(Surface1)
        C[Col.TitleBarSelected] = Col32(Mauve, 0.6)
        C[Col.Link] = Col32(Mauve, 0.8)
        C[Col.LinkHovered] = Col32(Lavender)
        C[Col.LinkSelected] = Col32(Lavender)
        C[Col.Pin] = Col32(Mauve, 0.7)
        C[Col.PinHovered] = Col32(Lavender)
        C[Col.BoxSelector] = Col32(Mauve, 0.12)
        C[Col.BoxSelectorOutline] = Col32(Mauve, 0.6)
        C[Col.GridBackground] = Col32(Crust)
        C[Col.GridLine] = Col32(Surface0, 0.6)
        C[Col.GridLinePrimary] = Col32(Surface1, 0.8)
        C[Col.MiniMapBackground] = Col32(Mantle, 0.6)
        C[Col.MiniMapBackgroundHovered] = Col32(Mantle, 0.8)
        C[Col.MiniMapOutline] = Col32(Surface1, 0.6)
        C[Col.MiniMapOutlineHovered] = Col32(Surface2)
        C[Col.MiniMapNodeBackground] = Col32(Surface1, 0.6)
        C[Col.MiniMapNodeBackgroundHovered] = Col32(Surface2)
        C[Col.MiniMapNodeBackgroundSelected] = Col32(Mauve, 0.6)
        C[Col.MiniMapNodeOutline] = Col32(Overlay0, 0.6)
        C[Col.MiniMapLink] = C[Col.Link]
        C[Col.MiniMapLinkSelected] = C[Col.LinkSelected]
        C[Col.MiniMapCanvas] = Col32(Text, 0.1)
        C[Col.MiniMapCanvasOutline] = Col32(Text, 0.6)
    end
    function D.Draw() UI.Draw() end
    table.insert(Demos, D)
end

-- ImPlot
do
    local D = { Name = "ImPlot" }
    local ImPlot
    function D.Init()
        ImPlot = LoadExt("implot-luau", "ImPlot.lua")(G)
        LoadExt("implot-luau", "ImPlotDemo.lua")(G, ImPlot)
        ImPlot.CreateContext()
    end
    function D.Draw() ImPlot.ShowDemoWindow() end
    table.insert(Demos, D)
end

-- ImPlot3D
do
    local D = { Name = "ImPlot3D" }
    local ImPlot3D
    function D.Init()
        ImPlot3D = LoadExt("implot3d-luau", "ImPlot3D.lua")(G)
        LoadExt("implot3d-luau", "ImPlot3DDemo.lua")(G, ImPlot3D)
        ImPlot3D.CreateContext()
    end
    function D.Draw() ImPlot3D.ShowDemoWindow() end
    table.insert(Demos, D)
end

-- ImGuiColorTextEdit
do
    local D = { Name = "ImGuiColorTextEdit" }
    local TextEditor, Editor, SavedUndoIndex
    local SampleCode = [==[
-- Sample Lua code
local function Greet(name)
	return "Hello, " .. name .. "!"
end

for i = 1, 10 do
	if i % 2 == 0 then
		print(Greet("Player" .. i), 3.14 * i, 0xFF)
	end
end

--[[ block
     comment ]]
local t = { a = 1, b = "two", [3] = true, nil }
]==]
    -- catppuccin mocha, in TextEditor.Color order
    local CatppuccinPalette = {
        Col32(Text), Col32(Mauve), Col32(Yellow), Col32(Peach), Col32(Green), Col32(Overlay2), Col32(Pink), Col32(Text),
        Col32(Blue), Col32(Overlay0), Col32(Base), Col32(Text), Col32(Surface2), Col32(Surface1), Col32(Surface0), Col32(Overlay0),
        Col32(Yellow), Col32(Blue), Col32(Mauve), Col32(Red), Col32(Overlay0), Col32(Lavender), Col32(Text, 0.03), Col32(Text, 0.06),
    }
    function D.Init()
        TextEditor = LoadExt("imguicolortextedit-luau", "TextEditor.lua")(G)
        Editor = TextEditor.new()
        Editor:SetPalette(CatppuccinPalette)
        Editor:SetLanguage(TextEditor.Language.Lua())
        Editor:SetText(SampleCode)
        SavedUndoIndex = Editor:GetUndoIndex()
    end
    function D.Draw()
        ImGui.SetNextWindowSize(ImVec2(800, 600), G.ImGuiCond.FirstUseEver)
        D.Show = ImGui.Begin("Text Editor Demo", D.Show, G.ImGuiWindowFlags.MenuBar)
        if ImGui.BeginMenuBar() then
            if ImGui.BeginMenu("File") then
                if ImGui.MenuItem("Save") then SavedUndoIndex = Editor:GetUndoIndex() end -- stub: nowhere to save to
                ImGui.EndMenu()
            end
            if ImGui.BeginMenu("Edit") then
                local ReadOnly = Editor:IsReadOnlyEnabled()
                if ImGui.MenuItem("Read-only mode", nil, ReadOnly) then Editor:SetReadOnlyEnabled(not ReadOnly) end
                ImGui.Separator()
                if ImGui.MenuItem("Undo", "Ctrl-Z", nil, Editor:CanUndo()) then Editor:Undo() end
                if ImGui.MenuItem("Redo", "Ctrl-Y", nil, Editor:CanRedo()) then Editor:Redo() end
                ImGui.Separator()
                local HasSelection = Editor:AnyCursorHasSelection()
                if ImGui.MenuItem("Copy", "Ctrl-C", nil, HasSelection) then Editor:Copy() end
                if ImGui.MenuItem("Cut", "Ctrl-X", nil, not ReadOnly and HasSelection) then Editor:Cut() end
                if ImGui.MenuItem("Delete", "Del", nil, not ReadOnly and HasSelection) then Editor:ReplaceTextInAllCursors("") end
                if ImGui.MenuItem("Paste", "Ctrl-V", nil, not ReadOnly) then Editor:Paste() end
                ImGui.Separator()
                if ImGui.MenuItem("Select all", "Ctrl-A") then Editor:SelectAll() end
                ImGui.EndMenu()
            end
            if ImGui.BeginMenu("View") then
                if ImGui.MenuItem("Catppuccin palette") then Editor:SetPalette(CatppuccinPalette) end
                if ImGui.MenuItem("Dark palette") then Editor:SetPalette(TextEditor.GetDarkPalette()) end
                if ImGui.MenuItem("Light palette") then Editor:SetPalette(TextEditor.GetLightPalette()) end
                ImGui.EndMenu()
            end
            ImGui.EndMenuBar()
        end
        local Pos = Editor:GetMainCursorPosition()
        ImGui.Text(string.format("%d/%d | %d lines | %s | %s | %s",
            Pos.line + 1, Pos.index + 1, Editor:GetLineCount(),
            Editor:IsOverwriteEnabled() and "Ovr" or "Ins",
            Editor:GetUndoIndex() ~= SavedUndoIndex and "*" or " ",
            Editor:GetLanguageName()))
        Editor:Render("TextEditor")
        ImGui.End()
    end
    table.insert(Demos, D)
end

local ShowImGuiDemo = true
local function ShowExtensionsWindow()
    ImGui.Begin("Extensions")
    _, ShowImGuiDemo = ImGui.Checkbox("Dear ImGui Demo", ShowImGuiDemo)
    local Fr = ImGui.GetIO().Framerate
    ImGui.SameLine(); ImGui.TextDisabled("%.1f FPS", Fr)
    ImGui.Separator()
    for _, D in ipairs(Demos) do
        local Changed
        Changed, D.Show = ImGui.Checkbox(D.Name, D.Show or false)
        if Changed and D.Show and not D.Ready then
            local Ok, Err = pcall(D.Init)
            D.Ready, D.Error = Ok, (not Ok) and tostring(Err) or nil
            D.Show = Ok
        end
        if D.Error then
            ImGui.SameLine()
            ImGui.TextDisabled("(failed)")
            if ImGui.BeginItemTooltip() then
                ImGui.TextUnformatted(D.Error)
                ImGui.EndTooltip()
            end
        end
    end
    ImGui.End()
end

function love.load()
    ImGui.CreateContext()
    local io = ImGui.GetIO()
    io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.NavEnableKeyboard, G.ImGuiConfigFlags.DockingEnable)
    io.IniFilename = nil
    G.ImGui_ImplLove.Init({ root = ROOT })
    StyleColorsCatppuccinMocha(ImGui.GetStyle())
    io.Fonts:AddFontDefault()
    for _, Name in ipairs({ "Cousine-Regular", "DroidSans", "Karla-Regular", "ProggyTiny", "Roboto-Medium" }) do
        io.Fonts:AddFontFromFileTTF("fonts/" .. Name .. ".ttf", 13.0)
    end
end

function love.update(dt)
    G.ImGui_ImplLove.NewFrame()
    ImGui.NewFrame()
    ImGui.DockSpaceOverViewport(0, nil, G.ImGuiDockNodeFlags.PassthruCentralNode)
    if ShowImGuiDemo then ShowImGuiDemo = ImGui.ShowDemoWindow(ShowImGuiDemo) end
    ShowExtensionsWindow()
    for _, D in ipairs(Demos) do
        if D.Show then
            -- a throwing demo would skip Render and break every later frame: unwind its stacks and turn it off
            local State = G.ImGuiErrorRecoveryState()
            ImGui.ErrorRecoveryStoreState(State)
            local Ok, Err = pcall(D.Draw)
            if not Ok then
                ImGui.ErrorRecoveryTryToRecoverState(State)
                D.Show, D.Error = false, tostring(Err)
                print(D.Name .. " demo error: " .. D.Error)
            end
        end
    end
    ImGui.Render()
end

function love.draw()
    local c = 0x1e1e2e
    love.graphics.clear(bit32.extract(c, 16, 8) / 255, bit32.extract(c, 8, 8) / 255, bit32.extract(c, 0, 8) / 255, 1)
    G.ImGui_ImplLove.RenderDrawData(ImGui.GetDrawData())
end

function love.mousemoved(x, y) G.ImGui_ImplLove.MouseMoved(x, y) end
function love.mousepressed(x, y, b) G.ImGui_ImplLove.MousePressed(x, y, b) end
function love.mousereleased(x, y, b) G.ImGui_ImplLove.MouseReleased(x, y, b) end
function love.wheelmoved(x, y) G.ImGui_ImplLove.WheelMoved(x, y) end
function love.keypressed(k) G.ImGui_ImplLove.KeyPressed(k) end
function love.keyreleased(k) G.ImGui_ImplLove.KeyReleased(k) end
function love.textinput(t) G.ImGui_ImplLove.TextInput(t) end
function love.focus(f) G.ImGui_ImplLove.Focus(f) end
