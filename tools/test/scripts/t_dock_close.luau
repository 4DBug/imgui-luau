-- Docked windows (floating split node) stop being submitted: the host lingers one frame, its bodies must be filled
-- with the windows' bg colour (node.LastBgColor), not white, and everything must be gone within a few frames.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext()
local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.DockingEnable)
G.ImGui_ImplRoblox.Init()
local frame, closed_at, done = 0, 31, false
RunService.Stepped:Connect(function()
    if done then return end
    frame += 1
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()
    if frame == 2 then
        local id = ImGui.GetID("floating")
        ImGui.DockBuilderRemoveNode(id)
        ImGui.DockBuilderAddNode(id, 0)
        ImGui.DockBuilderSetNodePos(id, ImVec2(100, 100))
        ImGui.DockBuilderSetNodeSize(id, ImVec2(600, 400))
        local left, right = ImGui.DockBuilderSplitNode(id, G.ImGuiDir.Left, 0.5)
        ImGui.DockBuilderDockWindow("A", left)
        ImGui.DockBuilderDockWindow("B", right)
        ImGui.DockBuilderFinish(id)
    end
    if frame < closed_at then
        for _, n in { "A", "B" } do
            if ImGui.Begin(n) then ImGui.Text("window " .. n) end
            ImGui.End()
        end
    end
    if frame == closed_at - 1 then
        local a, b = ImGui.FindWindowByName("A"), ImGui.FindWindowByName("B")
        assert(a.DockNode and b.DockNode and a.DockNode ~= b.DockNode and a.DockNode.HostWindow, "A, B docked side by side")
    end
    ImGui.Render()
    local dd = ImGui.GetDrawData()
    if frame >= closed_at then
        for _, dl in dd.CmdLists:iter() do
            -- white vertices spanning a big area = a white body fill (white text glyphs are small)
            local vb, x0, y0, x1, y1 = dl.VtxBuffer.Buf, math.huge, math.huge, -math.huge, -math.huge
            for _, pcmd in dl.CmdBuffer:iter() do
                for i = pcmd.IdxOffset + 1, pcmd.IdxOffset + pcmd.ElemCount do
                    local o = (pcmd.VtxOffset + dl.IdxBuffer.Data[i] - 1) * G.VTX_STRIDE
                    if buffer.readu32(vb, o + 32) == 0xFFFFFFFF then
                        local x, y = buffer.readf64(vb, o), buffer.readf64(vb, o + 8)
                        x0, y0, x1, y1 = math.min(x0, x), math.min(y0, y), math.max(x1, x), math.max(y1, y)
                    end
                end
            end
            assert(not (x1 - x0 > 100 and y1 - y0 > 100), "white fill on frame " .. frame)
        end
        if dd.TotalVtxCount == 0 then
            G.ImGui_ImplRoblox.RenderDrawData(dd)
            for _, set in io.BackendPlatformUserData.Layers do
                for kind = 1, 3 do assert(not (set[kind] and set[kind].Visible), "backend layer still visible after close") end
            end
            print("DOCK CLOSE OK after", frame - closed_at + 1, "frames")
            done = true
            return
        else
            assert(frame < closed_at + 3, "docked windows still drawn " .. (frame - closed_at + 1) .. " frames after close")
        end
    end
    G.ImGui_ImplRoblox.RenderDrawData(dd)
end)
