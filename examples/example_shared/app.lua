-- One UI that runs unchanged on Roblox and LÖVE: only the Dear ImGui API is used, and the code is plain Lua 5.1
-- (no Luau-only syntax), so both Luau and LuaJIT run it. The platform launchers are roblox.client.luau and main.lua.
--   local App = require(app)(G)   -- G = the table returned by the ImGui bundle
--   every frame, between ImGui.NewFrame() and ImGui.Render():  App.Frame()
return function(G)
    local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
    local App = {
        Platform = "?",                                  -- set by the launcher ("Roblox" / "LÖVE")
        ClearColor = ImVec4(0.45, 0.55, 0.60, 1.00),     -- launchers may use it as the background colour
    }
    local show_demo, show_table = false, true
    local counter, speed = 0, 1.0
    local name = ImGui.NewTextBuffer("Player", 64)
    local samples, t = {}, 0.0
    local items = { { "Sword", 1, 120 }, { "Potion", 5, 15 }, { "Arrow", 64, 1 }, { "Shield", 1, 80 } }

    function App.Frame()
        local io = ImGui.GetIO()
        t = t + io.DeltaTime * speed
        for i = 1, 90 do samples[i] = math.sin(i / 90 * math.pi * 4 + t * 3) end

        ImGui.SetNextWindowPos(ImVec2(20, 20), G.ImGuiCond.FirstUseEver)
        ImGui.SetNextWindowSize(ImVec2(420, 360), G.ImGuiCond.FirstUseEver)
        ImGui.Begin("Shared Example")
        ImGui.Text("Running on %s (%.1f FPS)", App.Platform, io.Framerate)
        ImGui.Separator()
        ImGui.InputText("name", name, 64)
        if ImGui.Button("Click me") then counter = counter + 1 end
        ImGui.SameLine(); ImGui.Text("%s clicked %d times", ImGui.TextBufferToString(name), counter)
        speed = ImGui.SliderFloat("speed", speed, 0.0, 4.0)
        ImGui.ColorEdit3("background", App.ClearColor)
        ImGui.PlotLines("wave", samples, nil, #samples, 0, nil, -1.0, 1.0, ImVec2(0, 60))
        local _
        _, show_table = ImGui.Checkbox("Inventory table", show_table)
        ImGui.SameLine(); _, show_demo = ImGui.Checkbox("Demo window", show_demo)
        if show_table and ImGui.BeginTable("inv", 3, bit32.bor(G.ImGuiTableFlags.Borders, G.ImGuiTableFlags.RowBg, G.ImGuiTableFlags.Sortable)) then
            ImGui.TableSetupColumn("Item"); ImGui.TableSetupColumn("Count"); ImGui.TableSetupColumn("Value")
            ImGui.TableHeadersRow()
            for _, it in ipairs(items) do
                ImGui.TableNextRow()
                ImGui.TableNextColumn(); ImGui.Text(it[1])
                ImGui.TableNextColumn(); ImGui.Text("%d", it[2])
                ImGui.TableNextColumn(); ImGui.Text("%d", it[3])
            end
            ImGui.EndTable()
        end
        ImGui.End()

        if show_demo and ImGui.ShowDemoWindow then show_demo = ImGui.ShowDemoWindow(show_demo) end
    end

    return App
end
