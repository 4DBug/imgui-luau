-- Two contexts sharing one font atlas (one backend module): new glyphs baked while B is current used to hit
-- UpdateTexture's assert (per-context texture tables). Textures are now module-wide.
-- run: python3 tools/test/run.py --main tools/test/scripts/t_pool_ctx.luau --frames 60 --quiet --roblox
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local Impl = G.ImGui_ImplRoblox
local a = ImGui.CreateContext(); ImGui.SetCurrentContext(a); Impl.Init(); Impl.SetRenderRate(0)
local b = ImGui.CreateContext(ImGui.GetIO().Fonts); ImGui.SetCurrentContext(b); Impl.Init(); Impl.SetRenderRate(0)

local function frame(ctx, body)
    ImGui.SetCurrentContext(ctx)
    Impl.NewFrame(); ImGui.GetIO().DeltaTime = 1 / 60
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10), G.ImGuiCond.Always); ImGui.SetNextWindowSize(ImVec2(900, 700), G.ImGuiCond.Always)
    ImGui.Begin("W"); body(); ImGui.End()
    ImGui.Render(); Impl.RenderDrawData(ImGui.GetDrawData())
end

local n = 0
game:GetService("RunService").Stepped:Connect(function()
    n += 1
    if n > 60 then return end
    frame(a, function() ImGui.Text("context A"); if n == 20 then ImGui.PushFont(nil, 33); ImGui.Text("Glyphs baked under A"); ImGui.PopFont() end end)
    frame(b, function()
        if n == 5 then ImGui.PushFont(nil, 41); ImGui.Text("Big glyphs baked under B"); ImGui.PopFont() end
        ImGui.Text("context B")
    end)
    if n == 60 then
        assert(Impl.GetStats().Tiles > 0)
        print("POOLCTX OK")
    end
end)
