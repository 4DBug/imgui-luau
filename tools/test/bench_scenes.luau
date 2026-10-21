-- Benchmark scenes shared by the Studio bench (slopgame place, ReplicatedStorage.Shared.BenchScenes) and the headless
-- tools/test/scripts/t_stress2.luau. Deterministic: everything animates from the frame number f, never from time.
-- return function(G, ImPlot?) -> { plots = fn(f), colorpicker = fn(f), implot = fn(f) (if ImPlot), demo_all = fn(f) }
return function(G, ImPlot)
    local ImGui, ImVec2, ImVec4 = G.ImGui, G.ImVec2, G.ImVec4
    local Cond = G.ImGuiCond
    local S = { values = table.create(90, 0), col1 = ImVec4(0.4, 0.7, 0.2, 0.5), col2 = ImVec4(0.9, 0.3, 0.6, 0.8),
        edits = { ImVec4(1, 0, 0, 1), ImVec4(0, 1, 0, 0.5), ImVec4(0, 0, 1, 1), ImVec4(1, 1, 0, 0.25) } }
    local scenes = {}

    local function Place(name, x, y, w, h)
        ImGui.SetNextWindowPos(ImVec2(x, y), Cond.Always)
        ImGui.SetNextWindowSize(ImVec2(w, h), Cond.Always)
        return ImGui.Begin(name)
    end

    -- PlotLines + PlotHistogram over a 90-sample ring buffer, one new sample per frame (demo "Plots Widgets" pattern)
    function scenes.plots(f)
        local v = S.values
        local off = f % 90
        v[off + 1] = math.sin(f * 0.13) * 0.7 + math.sin(f * 0.031) * 0.3
        Place("Plots", 60, 60, 520, 640)
        ImGui.PlotLines("Lines", v, nil, 90, off, "avg", -1.0, 1.0, ImVec2(0, 120))
        ImGui.PlotHistogram("Histogram", v, nil, 90, off, nil, -1.0, 1.0, ImVec2(0, 120))
        ImGui.PlotLines("Lines small", v, nil, 90, off, nil, -1.0, 1.0, ImVec2(0, 60))
        ImGui.PlotHistogram("Histogram small", v, nil, 90, off, nil, -1.0, 1.0, ImVec2(0, 60))
        ImGui.End()
    end

    -- ColorPicker4 with hue bar and with hue wheel (+ alpha bars), colour animated every frame, plus ColorEdit4s
    function scenes.colorpicker(f)
        local h = (f * 0.005) % 1
        local r, g, b = ImGui.ColorConvertHSVtoRGB(h, 0.7, 0.9)
        S.col1.x, S.col1.y, S.col1.z = r, g, b
        r, g, b = ImGui.ColorConvertHSVtoRGB((h + 0.5) % 1, 0.5, 0.8)
        S.col2.x, S.col2.y, S.col2.z = r, g, b
        local F = G.ImGuiColorEditFlags
        Place("Colors", 60, 60, 520, 640)
        ImGui.ColorPicker4("bar", S.col1, bit32.bor(F.PickerHueBar, F.AlphaBar))
        ImGui.ColorPicker4("wheel", S.col2, bit32.bor(F.PickerHueWheel, F.AlphaBar))
        for i, c in S.edits do ImGui.ColorEdit4("edit " .. i, c) end
        ImGui.End()
    end

    if ImPlot then
        local xs, ys, sx, sy, bars, xs101, y1, y2, heat = {}, {}, {}, {}, {}, {}, {}, {}, {}
        for i = 1, 1001 do xs[i] = (i - 1) * 0.001 end
        for i = 1, 100 do
            sx[i] = ((i * 7919) % 1000) / 1000
            sy[i] = ((i * 104729) % 1000) / 1000
        end
        for i = 1, 101 do xs101[i] = i - 1 end
        -- line (1001 pts, animated), scatter (100 pts), bars (10, animated), shaded (2x101, animated), heatmap (10x10, animated)
        function scenes.implot(f)
            for i = 1, 1001 do ys[i] = 0.5 + 0.5 * math.sin(50 * (xs[i] + f * 0.002)) end
            for i = 1, 10 do bars[i] = 5 + 4 * math.sin(f * 0.05 + i) end
            for i = 1, 101 do
                y1[i] = 250 + 100 * math.sin((i + f) * 0.07)
                y2[i] = 200 + 80 * math.cos((i + f) * 0.05)
            end
            for i = 1, 100 do heat[i] = 0.5 + 0.5 * math.sin(i * 0.37 + f * 0.04) end
            Place("ImPlot", 60, 60, 620, 900)
            local sz = ImVec2(-1, 200)
            if ImPlot.BeginPlot("Line", sz) then
                ImPlot.SetupAxesLimits(0, 1, 0, 1, Cond.Always)
                ImPlot.PlotLine("f(x)", xs, ys, 1001)
                ImPlot.EndPlot()
            end
            if ImPlot.BeginPlot("Scatter + Bars", sz) then
                ImPlot.SetupAxesLimits(0, 10, 0, 10, Cond.Always)
                ImPlot.PlotBars("bars", bars, 10, 0.7, 0)
                local sxx, syy = {}, {}
                for i = 1, 100 do sxx[i], syy[i] = sx[i] * 10, sy[i] * 10 end
                ImPlot.PlotScatter("pts", sxx, syy, 100)
                ImPlot.EndPlot()
            end
            if ImPlot.BeginPlot("Shaded", sz) then
                ImPlot.SetupAxesLimits(0, 100, 0, 500, Cond.Always)
                ImPlot.PlotShaded("a", xs101, y1, 101, 0)
                ImPlot.PlotShaded("b", xs101, y2, 101, 0)
                ImPlot.PlotLine("a", xs101, y1, 101)
                ImPlot.PlotLine("b", xs101, y2, 101)
                ImPlot.EndPlot()
            end
            if ImPlot.BeginPlot("##Heatmap", ImVec2(220, 220)) then
                ImPlot.PlotHeatmap("heat", heat, 10, 10, 0, 1, "%.1f")
                ImPlot.EndPlot()
            end
            ImGui.End()
        end
    end

    -- the whole demo window, every CollapsingHeader / TreeNode forced open, static
    local realCH, realTN, forcing = ImGui.CollapsingHeader, ImGui.TreeNode, false
    ImGui.CollapsingHeader = function(label, ...)
        if forcing then ImGui.SetNextItemOpen(true, Cond.Always) end
        return realCH(label, ...)
    end
    ImGui.TreeNode = function(label, ...)
        if forcing then ImGui.SetNextItemOpen(true, Cond.Always) end
        return realTN(label, ...)
    end
    function scenes.demo_all(f)
        ImGui.SetNextWindowPos(ImVec2(60, 40), Cond.Always)
        ImGui.SetNextWindowSize(ImVec2(620, 900), Cond.Always)
        forcing = true
        ImGui.ShowDemoWindow()
        forcing = false
    end

    return scenes
end
