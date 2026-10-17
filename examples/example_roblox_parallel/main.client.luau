
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ImGuiModule = ReplicatedStorage:WaitForChild("ImGui")
local G = require(ImGuiModule)
local ImGui, ImGui_ImplRoblox = G.ImGui, G.ImGui_ImplRoblox

ImGui.CreateContext()
local IO = ImGui.GetIO()
IO.ConfigFlags = bit32.bor(IO.ConfigFlags, G.ImGuiConfigFlags.NavEnableKeyboard, G.ImGuiConfigFlags.DockingEnable)

-- catppuccin mocha mauve https://catppuccin.com/palette
local function StyleColorsCatppuccinMocha(Style)
	local function Hex(Value, Alpha)
		return G.ImVec4(
			bit32.extract(Value, 16, 8) / 255,
			bit32.extract(Value, 8, 8) / 255,
			bit32.extract(Value, 0, 8) / 255,
			Alpha or 1.0
		)
	end

	local Crust, Mantle, Base = 0x11111b, 0x181825, 0x1e1e2e
	local Surface0, Surface1, Surface2 = 0x313244, 0x45475a, 0x585b70
	local Overlay0, Overlay2, Text = 0x6c7086, 0x9399b2, 0xcdd6f4
	local Mauve, Lavender = 0xcba6f7, 0xb4befe

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

-- PreSimulation, not RenderStepped: the parallel Finish runs in PostSimulation
RunService.PreSimulation:Connect(function()
	ImGui_ImplRoblox.NewFrame()
	ImGui.NewFrame()
	ImGui.DockSpaceOverViewport(0, nil, G.ImGuiDockNodeFlags.PassthruCentralNode)
	ImGui.ShowDemoWindow()
	ShowParallelWindow()
	ImGui.Render()
	ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)

script.Destroying:Connect(function()
	ImGui_ImplRoblox.DisableParallel()
	ImGui_ImplRoblox.Shutdown()
	ImGui.DestroyContext()
end)
