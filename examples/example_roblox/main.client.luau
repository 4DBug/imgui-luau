local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")

local G = require(ReplicatedStorage:WaitForChild("ImGui"))

local BaseEnvironment = getfenv()
setfenv(1, setmetatable({}, {
	__index = function(_, Key)
		local Value = G[Key]
		if Value ~= nil then
			return Value
		end
		return BaseEnvironment[Key]
	end,
}))

local MainScale = 1.0
local RenderScale = 1.0
local RenderRate = 60
local ThumbnailSize = 420
local FontSize = 13.0
local FontNames = { "Cousine-Regular", "DroidSans", "Karla-Regular", "ProggyTiny", "Roboto-Medium" }

local State = {
	ClearColor = ImVec4(0.45, 0.55, 0.60, 1.00),
	ShowDemoWindow = true,
	ShowAnotherWindow = false,
	Float = 0.0,
	Counter = 0,
}

local Spinner = {
	Show = true,
	Speed = 1.0,
	Angle = 0.0,
	Color = ImVec4(0.80, 0.65, 0.97, 1.0),
}

ImGui.CreateContext()

local IO = ImGui.GetIO()
IO.ConfigFlags = bit32.bor(IO.ConfigFlags, ImGuiConfigFlags.NavEnableKeyboard, ImGuiConfigFlags.DockingEnable)

-- catppuccin mocha mauve https://catppuccin.com/palette
local function StyleColorsCatppuccinMocha(Style)
	local function Hex(Value, Alpha)
		return ImVec4(
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
		Style.Colors[ImGuiCol[Name]] = Hex(Color, Alpha)
	end
end

local Style = ImGui.GetStyle()
StyleColorsCatppuccinMocha(Style)
Style:ScaleAllSizes(MainScale)
Style.FontScaleDpi = MainScale

IO.Fonts:AddFontDefault()
for _, Name in ipairs(FontNames) do
	IO.Fonts:AddFontFromFileTTF("fonts/" .. Name .. ".ttf", FontSize)
end

ImGui_ImplRoblox.Init(nil, RenderScale)
ImGui_ImplRoblox.SetRenderRate(RenderRate)
-- ImGui_ImplRoblox.SetBusyRenderRate(30) -- Optional: lower redraw rate while scrolling/resizing/moving windows
-- ImGui_ImplRoblox.SetProfiling(true)    -- MicroProfiler labels; turn off when not profiling
-- ImGui_ImplRoblox.SetTextProxy(true)     -- Optional: hidden TextBox for OS typing (any layout), paste and copy/cut

local function ProfileBegin(Name)
	if ImGui_ImplRoblox.IsProfiling() then
		debug.profilebegin(Name)
	end
end

local function ProfileEnd()
	if ImGui_ImplRoblox.IsProfiling() then
		debug.profileend()
	end
end


local EmbedFlags = {
	None         = 0,
	NoClip       = 1,  -- Don't clip to the window's content area (still moves/hides/stacks with the window)
	NoBackground = 2,  -- No FrameBg behind the Frame
	NoBorder     = 4,  -- No style border
	NoPadding    = 8,  -- No FramePadding inside the Frame (UIPadding)
	NoRounding   = 16, -- No FrameRounding corners (UICorner)
}

G.ImGuiEmbedFlags = EmbedFlags

local Embeds = {}

local function HasFlag(Flags, Flag)
	return bit32.band(Flags, Flag) ~= 0
end

local function CreateEmbed(Id)
	local Frame = Instance.new("Frame")
	Frame.Name = tostring(Id)
	Frame.BackgroundTransparency = 1
	Frame.BorderSizePixel = 0
	Frame.Visible = false

	local Padding = Instance.new("UIPadding")
	Padding.Parent = Frame

	local Corner = Instance.new("UICorner")
	Corner.Parent = Frame

	return { Frame = Frame, Padding = Padding, Corner = Corner }
end

function ImGui.Embed(Id, Size, Flags, Init)
	Flags = Flags or EmbedFlags.None

	local Window = ImGui.GetCurrentWindow()
	local GuiId = Window:GetID(Id)

	local Embed = Embeds[GuiId]
	if not Embed then
		Embed = CreateEmbed(Id)
		Embeds[GuiId] = Embed

		if Init then
			Init(Embed.Frame)
		end
	end

	if Window.SkipItems then
		return Embed.Frame
	end

	local EmbedStyle = ImGui.GetStyle()
	local ItemSize = ImGui.CalcItemSize(
		Size or ImVec2(0, 0),
		ImGui.CalcItemWidth(),
		ImGui.GetFrameHeight() * 4
	)
	local CursorPos = Window.DC.CursorPos
	local BoundingBox = ImRect(CursorPos.x, CursorPos.y, CursorPos.x + ItemSize.x, CursorPos.y + ItemSize.y)

	ImGui.ItemSize(ItemSize)
	if not ImGui.ItemAdd(BoundingBox, GuiId) then
		return Embed.Frame
	end

	local Rounding = HasFlag(Flags, EmbedFlags.NoRounding) and 0 or EmbedStyle.FrameRounding
	local ShowBorder = not HasFlag(Flags, EmbedFlags.NoBorder)

	if not HasFlag(Flags, EmbedFlags.NoBackground) then
		ImGui.RenderFrame(
			BoundingBox.Min,
			BoundingBox.Max,
			ImGui.GetColorU32(ImGuiCol.FrameBg),
			ShowBorder,
			Rounding
		)
	elseif ShowBorder then
		ImGui.RenderFrameBorder(BoundingBox.Min, BoundingBox.Max, Rounding)
	end

	local Scale = ImGui_ImplRoblox.GetRenderScale()
	local PaddingX, PaddingY = 0, 0

	if not HasFlag(Flags, EmbedFlags.NoPadding) then
		PaddingX = EmbedStyle.FramePadding.x / Scale
		PaddingY = EmbedStyle.FramePadding.y / Scale
	end

	if Embed.PaddingX ~= PaddingX or Embed.PaddingY ~= PaddingY then
		Embed.PaddingX, Embed.PaddingY = PaddingX, PaddingY

		local Padding = Embed.Padding
		Padding.PaddingLeft = UDim.new(0, PaddingX)
		Padding.PaddingRight = UDim.new(0, PaddingX)
		Padding.PaddingTop = UDim.new(0, PaddingY)
		Padding.PaddingBottom = UDim.new(0, PaddingY)
	end

	if Embed.Rounding ~= Rounding then
		Embed.Rounding = Rounding
		Embed.Corner.CornerRadius = UDim.new(0, Rounding / Scale)
	end

	ImGui_ImplRoblox.SetOverlay(
		Embed.Frame,
		BoundingBox.Min.x,
		BoundingBox.Min.y,
		ItemSize.x,
		ItemSize.y,
		not HasFlag(Flags, EmbedFlags.NoClip)
	)

	return Embed.Frame
end

function ImGui.DestroyEmbed(Id)
	local GuiId = ImGui.GetCurrentWindow():GetID(Id)
	local Embed = Embeds[GuiId]

	if Embed then
		Embed.Frame:Destroy()
		Embeds[GuiId] = nil
	end
end


local Decal = {
	Show = true,
	Input = ImGui.NewTextBuffer("", 32),
	Status = "Enter a decal or image id",
	Loading = false,
	Texture = nil,
	Width = 0,
	Height = 0,
	Viewer = ExampleImageViewerData(),
}

local function LoadDecal(Id)
	Decal.Loading = true
	Decal.Status = "Loading " .. Id .. "..."

	task.spawn(function()
		local Uri = string.format("rbxthumb://type=Asset&id=%d&w=%d&h=%d", Id, ThumbnailSize, ThumbnailSize)
		local Success, Result = pcall(AssetService.CreateEditableImageAsync, AssetService, Content.fromUri(Uri))

		if Success then
			local Size = Result.Size
			local Pixels = Result:ReadPixelsBuffer(Vector2.zero, Size)
			Result:Destroy()

			if Decal.Texture then
				ImGui_ImplRoblox.DestroyTexture(Decal.Texture)
			end

			Decal.Texture = ImGui_ImplRoblox.CreateTexture(Pixels, Size.X, Size.Y)
			Decal.Width, Decal.Height = Size.X, Size.Y
			Decal.Viewer.ViewReset = true
			Decal.Status = string.format("Thumbnail %d: %dx%d", Id, Size.X, Size.Y)
		else
			Decal.Status = "Failed to load thumbnail: " .. tostring(Result)
		end

		Decal.Loading = false
	end)
end

local function ShowDecalViewer()
	if not Decal.Show then
		return
	end

	Decal.Show = ImGui.Begin("Decal Viewer", Decal.Show)

	ImGui.SetNextItemWidth(ImGui.GetFontSize() * 12)
	local EnterPressed = ImGui.InputTextWithHint(
		"##id",
		"decal id",
		Decal.Input,
		32,
		ImGuiInputTextFlags.CharsDecimal + ImGuiInputTextFlags.EnterReturnsTrue
	)

	ImGui.SameLine()
	ImGui.BeginDisabled(Decal.Loading)
	if (ImGui.Button("Load") or EnterPressed) and not Decal.Loading then
		local Id = tonumber(ImGui.TextBufferToString(Decal.Input))
		if Id and Id == math.floor(Id) then
			LoadDecal(Id)
		else
			Decal.Status = "Not a valid id"
		end
	end
	ImGui.EndDisabled()

	ImGui.SameLine()
	ImGui.TextDisabled(Decal.Status)

	if Decal.Texture then
		ExampleImageViewer_DrawOptions(Decal.Viewer)

		local Available = ImGui.GetContentRegionAvail()
		ExampleImageViewer_DrawCanvas(
			Decal.Viewer,
			ImVec2(math.max(Available.x, 50), math.max(Available.y, 50)),
			Decal.Texture,
			Decal.Width,
			Decal.Height
		)
	end

	ImGui.End()
end

local function ShowHelloWindow()
	ImGui.Begin("Hello, world!")

	ImGui.Text("This is some useful text.")

	local _
	_, State.ShowDemoWindow = ImGui.Checkbox("Demo Window", State.ShowDemoWindow)
	_, State.ShowAnotherWindow = ImGui.Checkbox("Another Window", State.ShowAnotherWindow)

	State.Float = ImGui.SliderFloat("float", State.Float, 0.0, 1.0)
	ImGui.ColorEdit3("clear color", State.ClearColor)

	if ImGui.Button("Button") then
		State.Counter += 1
	end
	ImGui.SameLine()
	ImGui.Text("counter = %d", State.Counter)

	ImGui.Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / IO.Framerate, IO.Framerate)

	ImGui.End()
end

local function ShowAnotherWindow()
	if not State.ShowAnotherWindow then
		return
	end

	State.ShowAnotherWindow = ImGui.Begin("Another Window", State.ShowAnotherWindow)

	ImGui.Text("Hello from another window!")
	if ImGui.Button("Close Me") then
		State.ShowAnotherWindow = false
	end

	ImGui.End()
end

local function CreateSpinnerViewport(Container)
	local Viewport = Instance.new("ViewportFrame")
	Viewport.Size = UDim2.fromScale(1, 1)
	Viewport.BackgroundTransparency = 1
	Viewport.Parent = Container

	local Camera = Instance.new("Camera")
	Camera.CFrame = CFrame.lookAt(Vector3.new(0, 2, 6), Vector3.zero)
	Camera.Parent = Viewport
	Viewport.CurrentCamera = Camera

	local Part = Instance.new("Part")
	Part.Name = "Spinner"
	Part.Size = Vector3.new(2, 2, 2)
	Part.Parent = Viewport
end

local function ShowViewportWindow()
	if not Spinner.Show then
		return
	end

	Spinner.Show = ImGui.Begin("Viewport", Spinner.Show)

	Spinner.Speed = ImGui.SliderFloat("speed", Spinner.Speed, 0.0, 5.0)
	ImGui.ColorEdit3("color", Spinner.Color)

	local Frame = ImGui.Embed("viewport", ImVec2(-1, 220), EmbedFlags.None, CreateSpinnerViewport)

	Spinner.Angle += Spinner.Speed * IO.DeltaTime

	local Part = Frame.ViewportFrame.Spinner
	Part.CFrame = CFrame.Angles(0.4, Spinner.Angle, 0)
	Part.Color = Color3.new(Spinner.Color.x, Spinner.Color.y, Spinner.Color.z)

	ImGui.End()
end

RunService.Stepped:Connect(function()
	ProfileBegin("ImGui frame")
	ImGui_ImplRoblox.NewFrame()

	ProfileBegin("ImGui.NewFrame")
	ImGui.NewFrame()
	ProfileEnd()

	ProfileBegin("ImGui UI")
	ImGui.DockSpaceOverViewport(0, nil, ImGuiDockNodeFlags.PassthruCentralNode)

	if State.ShowDemoWindow then
		-- For reference: https://github.com/4DBug/imgui-luau/blob/master/imgui_demo.lua
		ImGui.ShowDemoWindow()
	end

	ShowHelloWindow()
	ShowAnotherWindow()
	ShowDecalViewer()
	ShowViewportWindow()
	ProfileEnd()

	ProfileBegin("ImGui.Render")
	ImGui.EndFrame()
	ImGui.Render()
	ProfileEnd()

	ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
	ProfileEnd()
end)
