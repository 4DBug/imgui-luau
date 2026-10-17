
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ImGuiModule = ReplicatedStorage:WaitForChild("ImGui")
local G = require(ImGuiModule)
local ImGui, ImGui_ImplRoblox = G.ImGui, G.ImGui_ImplRoblox

ImGui.CreateContext()
local IO = ImGui.GetIO()
IO.ConfigFlags = bit32.bor(IO.ConfigFlags, G.ImGuiConfigFlags.NavEnableKeyboard, G.ImGuiConfigFlags.DockingEnable)

-- catppuccin mocha mauve https://catppuccin.com/palette
local Crust, Mantle, Base = 0x11111b, 0x181825, 0x1e1e2e
local Surface0, Surface1, Surface2 = 0x313244, 0x45475a, 0x585b70
local Overlay0, Overlay2, Text = 0x6c7086, 0x9399b2, 0xcdd6f4
local Mauve, Lavender = 0xcba6f7, 0xb4befe
local Red, Peach, Yellow, Green, Blue, Pink = 0xf38ba8, 0xfab387, 0xf9e2af, 0xa6e3a1, 0x89b4fa, 0xf5c2e7

-- IM_COL32 from a 0xRRGGBB hex and 0..1 alpha
local function Col32(Value, Alpha)
	return G.IM_COL32(
		bit32.extract(Value, 16, 8),
		bit32.extract(Value, 8, 8),
		bit32.extract(Value, 0, 8),
		math.floor((Alpha or 1.0) * 255 + 0.5)
	)
end

local function StyleColorsCatppuccinMocha(Style)
	local function Hex(Value, Alpha)
		return G.ImVec4(
			bit32.extract(Value, 16, 8) / 255,
			bit32.extract(Value, 8, 8) / 255,
			bit32.extract(Value, 0, 8) / 255,
			Alpha or 1.0
		)
	end

	local Entries = {
		{ "Text", Text },
		{ "TextDisabled", Overlay0 },

		{ "WindowBg", Base },
		{ "ChildBg", Base, 0.0 },
		{ "PopupBg", Mantle, 0.98 },
		{ "Border", Surface1 },
		{ "BorderShadow", Crust, 0.0 },

		{ "FrameBg", Surface0 },
		{ "FrameBgHovered", Surface1 },
		{ "FrameBgActive", Surface2 },

		{ "TitleBg", Mantle },
		{ "TitleBgActive", Crust },
		{ "TitleBgCollapsed", Mantle, 0.75 },
		{ "MenuBarBg", Mantle },

		{ "ScrollbarBg", Mantle },
		{ "ScrollbarGrab", Surface1 },
		{ "ScrollbarGrabHovered", Surface2 },
		{ "ScrollbarGrabActive", Overlay0 },

		{ "CheckMark", Mauve },
		{ "CheckboxSelectedBg", Surface0 },
		{ "SliderGrab", Mauve, 0.8 },
		{ "SliderGrabActive", Mauve },

		{ "Button", Surface0 },
		{ "ButtonHovered", Surface1 },
		{ "ButtonActive", Mauve, 0.6 },

		{ "Header", Surface0 },
		{ "HeaderHovered", Surface1 },
		{ "HeaderActive", Mauve, 0.5 },

		{ "Separator", Surface1 },
		{ "SeparatorHovered", Mauve, 0.7 },
		{ "SeparatorActive", Mauve },

		{ "ResizeGrip", Mauve, 0.2 },
		{ "ResizeGripHovered", Mauve, 0.6 },
		{ "ResizeGripActive", Mauve, 0.9 },

		{ "InputTextCursor", Text },

		{ "Tab", Surface0 },
		{ "TabHovered", Surface2 },
		{ "TabSelected", Surface1 },
		{ "TabSelectedOverline", Mauve },
		{ "TabDimmed", Mantle },
		{ "TabDimmedSelected", Surface0 },
		{ "TabDimmedSelectedOverline", Overlay0 },

		{ "DockingPreview", Mauve, 0.7 },
		{ "DockingEmptyBg", Crust },

		{ "PlotLines", Overlay2 },
		{ "PlotLinesHovered", Mauve },
		{ "PlotHistogram", Mauve, 0.8 },
		{ "PlotHistogramHovered", Lavender },

		{ "TableHeaderBg", Surface0 },
		{ "TableBorderStrong", Surface1 },
		{ "TableBorderLight", Surface0 },
		{ "TableRowBg", Base, 0.0 },
		{ "TableRowBgAlt", Surface0, 0.3 },

		{ "TextLink", Mauve },
		{ "TextSelectedBg", Mauve, 0.35 },
		{ "TreeLines", Surface2 },
		{ "DragDropTarget", Mauve, 0.9 },

		{ "NavCursor", Lavender },
		{ "NavWindowingHighlight", Lavender, 0.7 },
		{ "NavWindowingDimBg", Crust, 0.5 },
		{ "ModalWindowDimBg", Crust, 0.6 },
	}

	for _, Entry in ipairs(Entries) do
		local Name, Color, Alpha = Entry[1], Entry[2], Entry[3]
		Style.Colors[G.ImGuiCol[Name]] = Hex(Color, Alpha)
	end
end

StyleColorsCatppuccinMocha(ImGui.GetStyle())
IO.Fonts:AddFontDefault()
for _, Name in { "Cousine-Regular", "DroidSans", "Karla-Regular", "ProggyTiny", "Roboto-Medium" } do
	IO.Fonts:AddFontFromFileTTF("fonts/" .. Name .. ".ttf", 13.0)
end

ImGui_ImplRoblox.Init()
ImGui_ImplRoblox.SetTextProxy(true) -- OS copy/paste for ImGuiColorTextEdit
local RenderRate = 60 -- UI redraws per second (0 = every frame)
ImGui_ImplRoblox.SetRenderRate(RenderRate)
ImGui_ImplRoblox.EnableParallel({ Actors = 4 })

-- Game FPS and ImGui render FPS, sampled every 0.5 s
local GameFps, RenderFps, Frames, Renders, Since = 0, 0, 0, nil, os.clock()
RunService.RenderStepped:Connect(function()
	Frames += 1
	local Now = os.clock()
	local Dt = Now - Since
	if Dt >= 0.5 then
		GameFps = Frames / Dt
		local R = ImGui_ImplRoblox.GetStats().Renders
		RenderFps = (R and Renders) and (R - Renders) / Dt or 0
		Frames, Renders, Since = 0, R, Now
	end
end)

local function Help(Desc)
	ImGui.SameLine()
	ImGui.TextDisabled("(?)")
	if ImGui.BeginItemTooltip() then
		ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
		ImGui.TextUnformatted(Desc)
		ImGui.PopTextWrapPos()
		ImGui.EndTooltip()
	end
end

local Enabled, Timing = true, false
local function ShowParallelWindow()
	local C, S = ImGui_ImplRoblox.GetParallelConfig(), ImGui_ImplRoblox.GetParallelStats()
	ImGui.Begin("Parallel")

	local Fr = IO.Framerate
	ImGui.Text("Game         %.1f FPS (%.2f ms)", GameFps, GameFps > 0 and 1000 / GameFps or 0)
	Help("Frames Roblox actually renders per second (counted from RenderStepped).")
	ImGui.Text("ImGui Logic  %.1f FPS (%.2f ms)", Fr, Fr > 0 and 1000 / Fr or 0)
	Help("How often ImGui logic runs NewFrame..Render (io.Framerate, 60-frame average). Runs every game frame so input stays responsive.")
	ImGui.Text("ImGui Render %.1f FPS", RenderFps)
	Help("How often the backend actually redraws the UI (capped by Render rate). Frames in between reuse the last drawn UI.")
	local Rate, RateChanged = ImGui.SliderInt("Render rate", RenderRate, 0, 240, RenderRate == 0 and "every frame" or "%d Hz")
	Help("Max UI redraws per second (SetRenderRate). 0 = redraw every game frame.")
	if RateChanged then
		RenderRate = Rate
		ImGui_ImplRoblox.SetRenderRate(Rate)
	end

	ImGui.Separator()
	local Changed
	Changed, Enabled = ImGui.Checkbox("Enabled", Enabled)
	Help("Rasterize dirty tiles on Actors (parallel Luau). Off = everything is rasterized on the main thread.")
	if Changed then
		if Enabled then
			ImGui_ImplRoblox.EnableParallel()
		else
			ImGui_ImplRoblox.DisableParallel()
		end
	end
	local Actors = C.Actors
	Actors, Changed = ImGui.SliderInt("Actors", Actors, 1, 16)
	Help("Number of worker Actors. Changing it finishes the pending frame and replaces the Actors. More than your CPU core count won't help.")
	if Changed then
		C.Actors = Actors
		if Enabled then
			ImGui_ImplRoblox.EnableParallel()
		end
	end
	C.MinTiles = ImGui.SliderInt("MinTiles", C.MinTiles, 0, 64)
	Help("A frame with fewer dirty tiles than this is rasterized on the main thread (dispatch overhead isn't worth it).")
	C.MinPixels = ImGui.SliderInt("MinPixels", C.MinPixels, 0, 262144)
	Help("A frame with fewer dirty pixels than this is rasterized on the main thread.")
	C.MaxBytesPerPixel = ImGui.SliderFloat("MaxBytesPerPixel", C.MaxBytesPerPixel, 0, 16)
	Help("If the packed data sent to Actors exceeds this many bytes per dirty pixel (e.g. lots of small text), the frame stays on the main thread, since copying would cost more than it saves. 0 = no limit.")

	local B = ImGui_ImplRoblox.GetStats()
	ImGui.Separator()
	ImGui.Text("Flushes parallel %d serial %d", S.ParallelFlushes, S.SerialFlushes)
	Help("Frames whose dirty tiles went to Actors vs. were rasterized on the main thread (below thresholds, or ImGui ran too late in the frame).")
	ImGui.Text("Fallbacks %d Late %d", S.Fallbacks, S.Late)
	Help("Fallbacks: Actor batches not finished in time, rasterized on the main thread so the frame is never partial. Late: results that arrived after that and were discarded. Both should stay at 0.")
	ImGui.Text("Tiles %d EditableImage %.1f MB", B.Tiles, B.EditableImageBytes / 1048576)
	Help("Live 128x128 raster tiles and EditableImage memory used by the backend (hard-capped).")
	Changed, Timing = ImGui.Checkbox("Stage timing", Timing)
	Help("Per-stage main-thread time of the last rendered frame. With parallel on, Raster is only the packing for Actors.")
	if Changed then
		ImGui_ImplRoblox.SetStageTiming(Timing)
	end
	if Timing and B.Frame then
		for _, K in { "Compare", "Collect", "Hash", "Raster", "Upload", "Other", "Total" } do
			ImGui.Text("%-8s %.3f ms", K, (B.Frame[K] or 0) * 1000)
		end
	end

	ImGui.End()
end

-- Extension demos (code from extensions/*/examples/roblox). Each is required/initialized on first enable.
local RS = ReplicatedStorage
local ImVec2 = G.ImVec2
local _

local Demos = {}

-- imgui_memory_editor
do
	local D = { Name = "Memory Editor" }
	local Data, MemEdit, MemEdit2, Frame = nil, nil, nil, 0
	function D.Init()
		local MemoryEditor = require(RS:WaitForChild("MemoryEditor"))(G)
		Data = buffer.create(0x400)
		buffer.writef32(Data, 0x10, math.pi)
		buffer.writestring(Data, 0x20, "Hello from a Roblox buffer!")
		for i = 0x40, 0x3FF do buffer.writeu8(Data, i, (i * 37) % 256) end
		MemEdit = MemoryEditor.new()
		MemEdit.OptShowDataPreview = true
		MemEdit2 = MemoryEditor.new()
		MemEdit2.HighlightFn = function(mem, off) return buffer.readu8(mem, off) % 2 == 0 end
	end
	function D.Draw()
		Frame += 1
		buffer.writeu32(Data, 0x00, Frame)
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

-- ImGuizmo
do
	local D = { Name = "ImGuizmo" }
	local ImGuizmo, OP, MODE, Roblox, Part
	local Operation, Mode
	local UseSnap, ShowGrid = false, false
	local Snap = { 1, 1, 1 }
	local AngleSnap, ScaleSnap = 15, 0.1
	local BoundSizing, BoundSizingSnap = false, false
	local Bounds = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 }
	local BoundsSnap = { 0.1, 0.1, 0.1 }
	local Identity = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
	local Camera = workspace.CurrentCamera

	function D.Init()
		ImGuizmo = require(RS:WaitForChild("ImGuizmo"))(G)
		OP, MODE, Roblox = ImGuizmo.OPERATION, ImGuizmo.MODE, ImGuizmo.Roblox
		Operation, Mode = OP.TRANSLATE, MODE.WORLD
		Part = workspace:FindFirstChild("GizmoPart")
		if not Part then
			Part = Instance.new("Part")
			Part.Name = "GizmoPart"
			Part.Anchored = true
			Part.Size = Vector3.new(4, 4, 4)
			Part.CFrame = CFrame.new(0, 5, 0)
			Part.Parent = workspace
		end
	end

	local function EditTransform(Matrix)
		local ImGuiKey = G.ImGuiKey
		if ImGui.IsKeyPressed(ImGuiKey.T) then Operation = OP.TRANSLATE end
		if ImGui.IsKeyPressed(ImGuiKey.E) then Operation = OP.ROTATE end
		if ImGui.IsKeyPressed(ImGuiKey.R) then Operation = OP.SCALE end
		_, Operation = ImGui.RadioButton("Translate", Operation, OP.TRANSLATE)
		ImGui.SameLine()
		_, Operation = ImGui.RadioButton("Rotate", Operation, OP.ROTATE)
		ImGui.SameLine()
		_, Operation = ImGui.RadioButton("Scale", Operation, OP.SCALE)
		ImGui.SameLine()
		_, Operation = ImGui.RadioButton("Universal", Operation, OP.UNIVERSAL)

		local Tr, Rt, Sc = {}, {}, {}
		ImGuizmo.DecomposeMatrixToComponents(Matrix, Tr, Rt, Sc)
		local Edited = ImGui.DragFloat3("Tr", Tr, 0.1)
		Edited = ImGui.DragFloat3("Rt", Rt, 1) or Edited
		Edited = ImGui.DragFloat3("Sc", Sc, 0.01) or Edited
		if Edited then ImGuizmo.RecomposeMatrixFromComponents(Tr, Rt, Sc, Matrix) end

		if Operation ~= OP.SCALE then
			_, Mode = ImGui.RadioButton("Local", Mode, MODE.LOCAL)
			ImGui.SameLine()
			_, Mode = ImGui.RadioButton("World", Mode, MODE.WORLD)
		end

		_, UseSnap = ImGui.Checkbox("Snap", UseSnap)
		ImGui.SameLine()
		if Operation == OP.ROTATE then
			AngleSnap = ImGui.DragFloat("Angle Snap", AngleSnap, 1)
		elseif Operation == OP.SCALE then
			ScaleSnap = ImGui.DragFloat("Scale Snap", ScaleSnap, 0.01)
		else
			ImGui.DragFloat3("Snap Value", Snap, 0.1)
		end

		if Operation == OP.SCALE then
			_, BoundSizing = ImGui.Checkbox("Bound Sizing", BoundSizing)
		end
		if Operation == OP.SCALE and BoundSizing then
			ImGui.PushID(3)
			_, BoundSizingSnap = ImGui.Checkbox("Bound Snap", BoundSizingSnap)
			ImGui.SameLine()
			ImGui.DragFloat3("Snap", BoundsSnap, 0.01)
			ImGui.PopID()
		end
		_, ShowGrid = ImGui.Checkbox("Show Grid", ShowGrid)

		local SnapArg = nil
		if UseSnap then
			if Operation == OP.ROTATE then
				SnapArg = { AngleSnap, AngleSnap, AngleSnap }
			elseif Operation == OP.SCALE then
				SnapArg = { ScaleSnap, ScaleSnap, ScaleSnap }
			else
				SnapArg = Snap
			end
		end
		return Edited, SnapArg
	end

	function D.Draw()
		ImGuizmo.BeginFrame()
		local Viewport = Camera.ViewportSize
		ImGuizmo.SetDrawlist(ImGui.GetForegroundDrawList())
		ImGuizmo.SetRect(0, 0, Viewport.X, Viewport.Y)

		local View = Roblox.ViewFromCamera(Camera)
		local Proj = Roblox.ProjFromCamera(Camera)

		-- Part.Size is baked into the basis so SCALE / bounds edit it
		local Matrix = Roblox.MatrixFromCFrame(Part.CFrame)
		local Size = Part.Size
		for I = 1, 3 do
			Matrix[I] *= Size.X
			Matrix[4 + I] *= Size.Y
			Matrix[8 + I] *= Size.Z
		end

		D.Show = ImGui.Begin("ImGuizmo", D.Show)
		local Edited, SnapArg = EditTransform(Matrix)
		ImGui.End()

		if ShowGrid then ImGuizmo.DrawGrid(View, Proj, Identity, 10) end
		-- Bound Sizing replaces the scale gizmo (BOUNDS draws only the bounds box)
		local UseBounds = BoundSizing and Operation == OP.SCALE
		local Moved = ImGuizmo.Manipulate(View, Proj, UseBounds and OP.BOUNDS or Operation, Mode, Matrix, nil, SnapArg,
			UseBounds and Bounds or nil, UseBounds and BoundSizingSnap and BoundsSnap or nil)
		if Edited or Moved then
			local NewCFrame, NewSize = Roblox.CFrameFromMatrix(Matrix)
			Part.CFrame = NewCFrame
			Part.Size = NewSize
		end

		-- ViewManipulate edits View in place; the camera is its inverse
		ImGuizmo.ViewManipulate(View, 10, ImVec2(Viewport.X - 128, 0), ImVec2(128, 128), 0x10101010)
		if ImGuizmo.IsUsingViewManipulate() then
			Camera.CameraType = Enum.CameraType.Scriptable
			Camera.CFrame = Roblox.CFrameFromMatrix(View):Inverse()
		end
	end
	table.insert(Demos, D)
end

-- ImNodes (Logic Simulator)
do
	local D = { Name = "ImNodes" }
	local UI
	function D.Init()
		local ImNodes = require(RS:WaitForChild("ImNodes"))(G)
		local Logic = RS:WaitForChild("Logic")
		local LogicSim = require(Logic:WaitForChild("Simulation"))(G, ImNodes)
		UI = require(Logic:WaitForChild("UI"))(G, ImNodes, LogicSim)

		ImNodes.CreateContext()
		ImNodes.PushAttributeFlag(ImNodes.ImNodesAttributeFlags.EnableLinkDetachWithDragClick)
		local NodesIO = ImNodes.GetIO()
		local KeyCtrl = function()
			return ImGui.GetIO().KeyCtrl
		end
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
	function D.Draw()
		UI.Draw()
	end
	table.insert(Demos, D)
end

-- ImPlot
do
	local D = { Name = "ImPlot" }
	local ImPlot
	function D.Init()
		local Module = RS:WaitForChild("ImPlot")
		ImPlot = require(Module)(G)
		require(Module:WaitForChild("ImPlotDemo"))(G, ImPlot)
		ImPlot.CreateContext()
	end
	function D.Draw()
		ImPlot.ShowDemoWindow()
	end
	table.insert(Demos, D)
end

-- ImPlot3D
do
	local D = { Name = "ImPlot3D" }
	local ImPlot3D
	function D.Init()
		local Module = RS:WaitForChild("ImPlot3D")
		ImPlot3D = require(Module)(G)
		require(Module:WaitForChild("ImPlot3DDemo"))(G, ImPlot3D)
		ImPlot3D.CreateContext()
	end
	function D.Draw()
		ImPlot3D.ShowDemoWindow()
	end
	table.insert(Demos, D)
end

-- ImGuiColorTextEdit
do
	local D = { Name = "ImGuiColorTextEdit" }
	local Editor, SavedUndoIndex
	local SampleCode = [==[
-- Sample Lua code
local Players = game:GetService("Players")

local function Greet(name: string): string
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
	local TextEditor
	-- catppuccin mocha, in TextEditor.Color order
	local CatppuccinPalette = {
		Col32(Text), -- text
		Col32(Mauve), -- keyword
		Col32(Yellow), -- declaration
		Col32(Peach), -- number
		Col32(Green), -- string
		Col32(Overlay2), -- punctuation
		Col32(Pink), -- preprocessor
		Col32(Text), -- identifier
		Col32(Blue), -- known identifier
		Col32(Overlay0), -- comment
		Col32(Base), -- background
		Col32(Text), -- cursor
		Col32(Surface2), -- selection
		Col32(Surface1), -- whitespace
		Col32(Surface0), -- matchingBracketBackground
		Col32(Overlay0), -- matchingBracketActive
		Col32(Yellow), -- matchingBracketLevel1
		Col32(Blue), -- matchingBracketLevel2
		Col32(Mauve), -- matchingBracketLevel3
		Col32(Red), -- matchingBracketError
		Col32(Overlay0), -- line number
		Col32(Lavender), -- current line number
		Col32(Text, 0.03), -- current line highlight
		Col32(Text, 0.06), -- current line highlight border
	}
	function D.Init()
		TextEditor = require(RS:WaitForChild("TextEditor"))(G)
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
				if ImGui.MenuItem("Save") then
					SavedUndoIndex = Editor:GetUndoIndex() -- stub: nowhere to save to
				end
				ImGui.EndMenu()
			end
			if ImGui.BeginMenu("Edit") then
				local ReadOnly = Editor:IsReadOnlyEnabled()
				if ImGui.MenuItem("Read-only mode", nil, ReadOnly) then
					Editor:SetReadOnlyEnabled(not ReadOnly)
				end
				ImGui.Separator()
				if ImGui.MenuItem("Undo", "Ctrl-Z", nil, Editor:CanUndo()) then Editor:Undo() end
				if ImGui.MenuItem("Redo", "Ctrl-Y", nil, Editor:CanRedo()) then Editor:Redo() end
				ImGui.Separator()
				local HasSelection = Editor:AnyCursorHasSelection()
				if ImGui.MenuItem("Copy", "Ctrl-C", nil, HasSelection) then Editor:Copy() end
				if ImGui.MenuItem("Cut", "Ctrl-X", nil, not ReadOnly and HasSelection) then Editor:Cut() end
				if ImGui.MenuItem("Delete", "Del", nil, not ReadOnly and HasSelection) then
					Editor:ReplaceTextInAllCursors("")
				end
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
	ImGui.Separator()
	for _, D in Demos do
		local Changed
		Changed, D.Show = ImGui.Checkbox(D.Name, D.Show or false)
		if Changed and D.Show and not D.Ready then
			local Ok, Err = pcall(D.Init)
			D.Ready, D.Error = Ok, not Ok and tostring(Err) or nil
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

-- PreSimulation, not RenderStepped: the parallel Finish runs in PostSimulation
RunService.PreSimulation:Connect(function()
	ImGui_ImplRoblox.NewFrame()
	ImGui.NewFrame()
	ImGui.DockSpaceOverViewport(0, nil, G.ImGuiDockNodeFlags.PassthruCentralNode)
	if ShowImGuiDemo then
		ImGui.ShowDemoWindow()
	end
	ShowParallelWindow()
	ShowExtensionsWindow()
	for _, D in Demos do
		if D.Show then
			-- a throwing demo would skip Render and break every later frame: unwind its Begin/Push stacks and turn it off
			local State = G.ImGuiErrorRecoveryState()
			ImGui.ErrorRecoveryStoreState(State)
			local Ok, Err = pcall(D.Draw)
			if not Ok then
				ImGui.ErrorRecoveryTryToRecoverState(State)
				D.Show, D.Error = false, tostring(Err)
				warn(D.Name .. " demo error: " .. D.Error)
			end
		end
	end
	ImGui.Render()
	ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)

script.Destroying:Connect(function()
	ImGui_ImplRoblox.DisableParallel()
	ImGui_ImplRoblox.Shutdown()
	ImGui.DestroyContext()
end)
