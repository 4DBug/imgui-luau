-- Every code snippet in README.md, verbatim between the "-- [snippet]" markers. Must print README OK.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
ImGui.CreateContext()
G.ImGui_ImplRoblox.Init()

-- [snippet:hello]
local f, counter = 0.6, 0
local buf = ImGui.NewTextBuffer("Hello, world!", 256) -- InputText edits a byte buffer in place
local my_color = ImVec4(1.0, 0.4, 0.2, 1.0)

local function MyFirstTool()
    ImGui.Begin("My First Tool")
    ImGui.Text("Hello, world %d", 123)
    if ImGui.Button("Save") then
        counter += 1
    end
    ImGui.InputText("string", buf, 256)
    f = ImGui.SliderFloat("float", f, 0.0, 1.0)
    ImGui.ColorEdit4("Color", my_color) -- ImVec4 arguments are edited in place
    ImGui.End()
end
-- [/snippet]

-- [snippet:conventions]
local enabled, volume, mode = true, 50, 0
local function Conventions()
    ImGui.Begin("Conventions")
    local pressed
    pressed, enabled = ImGui.Checkbox("Enabled", enabled)      -- bool widgets: pressed, new value
    local changed
    volume, changed = ImGui.SliderInt("Volume", volume, 0, 100) -- scalar widgets: new value, changed
    mode = ImGui.Combo("Mode", mode, { "Easy", "Normal", "Hard" }) -- Combo/ListBox: 0-based index
    if pressed or changed then print("settings changed") end
    ImGui.End()
end
-- [/snippet]

-- [snippet:menus]
local show_log = false
local function MenusAndTable()
    ImGui.Begin("Inventory", nil, G.ImGuiWindowFlags.MenuBar)
    if ImGui.BeginMenuBar() then
        if ImGui.BeginMenu("View") then
            _, show_log = ImGui.MenuItem("Show log", nil, show_log)
            ImGui.EndMenu()
        end
        ImGui.EndMenuBar()
    end
    local flags = bit32.bor(G.ImGuiTableFlags.Borders, G.ImGuiTableFlags.RowBg)
    if ImGui.BeginTable("items", 3, flags) then
        ImGui.TableSetupColumn("Name")
        ImGui.TableSetupColumn("Count")
        ImGui.TableSetupColumn("Value")
        ImGui.TableHeadersRow()
        for _, item in ipairs({ { "Sword", 1, 120 }, { "Potion", 5, 15 }, { "Arrow", 64, 1 } }) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn(); ImGui.Text(item[1])
            ImGui.TableNextColumn(); ImGui.Text("%d", item[2])
            ImGui.TableNextColumn(); ImGui.Text("%d", item[3])
        end
        ImGui.EndTable()
    end
    ImGui.End()
end
-- [/snippet]

-- [snippet:plot]
local samples = {}
local function Plot()
    for i = 1, 90 do
        samples[i] = math.sin(i / 90 * math.pi * 4 + os.clock() * 3)
    end
    ImGui.Begin("Plotting")
    ImGui.PlotLines("Lines", samples, nil, #samples, 0, "sine", -1.0, 1.0, ImVec2(0, 80))
    ImGui.ProgressBar((os.clock() * 0.4) % 1.0, ImVec2(-1, 0))
    ImGui.End()
end
-- [/snippet]

-- [snippet:drawlist]
local function CustomDrawing()
    ImGui.Begin("Custom drawing")
    local draw_list = ImGui.GetWindowDrawList()
    local p = ImGui.GetCursorScreenPos()
    draw_list:AddRectFilled(p, p + ImVec2(100, 100), G.IM_COL32(255, 120, 60, 255), 12.0)
    draw_list:AddCircleFilled(p + ImVec2(170, 50), 45, G.IM_COL32(80, 160, 255, 255))
    draw_list:AddLine(p + ImVec2(0, 120), p + ImVec2(220, 120), G.IM_COL32(255, 255, 0, 255), 2.0)
    ImGui.Dummy(ImVec2(220, 130)) -- reserve the space so the window sizes/scrolls correctly
    ImGui.End()
end
-- [/snippet]

-- [snippet:tool]
local my_tool_active, my_color2, samples2 = true, ImVec4(0.45, 0.28, 0.45, 1.0), {}
local function MyTool()
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
    ImGui.ColorEdit4("Color", my_color2)

    -- Generate samples and plot them
    for n = 1, 100 do samples2[n] = math.sin((n - 1) * 0.2 + ImGui.GetTime() * 1.5) end
    ImGui.PlotLines("Samples", samples2, nil, 100)

    -- Display contents in a scrolling region
    ImGui.TextColored(ImVec4(1, 1, 0, 1), "Important Stuff")
    ImGui.BeginChild("Scrolling")
    for n = 0, 49 do ImGui.Text("%04d: Some text", n) end
    ImGui.EndChild()
    ImGui.End()
end
-- [/snippet]

local frame = 0
RunService.Stepped:Connect(function()
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()
    MyFirstTool(); MyTool(); Conventions(); MenusAndTable(); Plot(); CustomDrawing()
    ImGui.Render()
    G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if frame == 20 then
        assert(ImGui.TextBufferToString(buf) == "Hello, world!")
        print("README OK")
    end
end)
