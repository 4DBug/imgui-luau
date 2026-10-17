-- Scrolling a long child window must not leak tiles: scrolled-away tiles are freed (recycled), so the live tile count
-- stays bounded by what is on screen. Then with a tiny EditableImage cap (SetEditableImageCap): tiles that don't fit
-- are skipped (GetTile -> nil, no assert) and the budget is never exceeded.
-- run: python3 tools/test/run.py --main tools/test/scripts/t_tile_bound.luau --frames 200 --quiet --roblox
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local Impl = G.ImGui_ImplRoblox
ImGui.CreateContext()
Impl.Init()
Impl.SetRenderRate(0)
local io = ImGui.GetIO()
local P = 100 -- frames per phase
local frame, peak = 0, 0
local TILE_BYTES = 128 * 128 * 4

game:GetService("RunService").Stepped:Connect(function()
    frame += 1
    if frame > 2 * P then return end
    local t = (frame - 1) % P + 1
    if frame == P + 1 then Impl.SetEditableImageCap(10 * TILE_BYTES); Impl.SetRenderScale(2) end -- (rebuild: shown tiles are never evicted)
    Impl.NewFrame()
    io.DeltaTime = 1 / 60
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(20, 20), G.ImGuiCond.Always)
    ImGui.SetNextWindowSize(ImVec2(400, 400), G.ImGuiCond.Always)
    ImGui.Begin("Scroll")
    ImGui.BeginChild("long", ImVec2(0, 0), G.ImGuiChildFlags.Borders)
    for i = 1, 3000 do ImGui.Text("row %d  some text to fill the tile width ........", i) end
    ImGui.SetScrollY(t * 300) -- ~30k px per phase: hundreds of distinct tiles if never freed
    ImGui.EndChild()
    ImGui.End()
    ImGui.Render()
    Impl.RenderDrawData(ImGui.GetDrawData())
    local s = Impl.GetStats()
    if frame <= P or t > 1 then assert(s.EditableImageBytes <= s.EditableImageCap, "over the EditableImage budget") end -- (the free list drains on the next create)
    assert(s.EditableImages >= s.Tiles)
    if frame <= P and t > 20 then peak = math.max(peak, s.Tiles) end
    if frame == P then
        print(("raster: peak tiles %d, now %d tiles, %d EditableImages, %d Instances"):format(peak, s.Tiles, s.EditableImages, s.Instances))
        -- a 400x400 window covers ~4x4 tiles per layer (+1 row/col when unaligned) + a few spares
        assert(peak <= 60, "tile count not bounded by what is on screen")
    end
    if frame == 2 * P then
        print(("capped: %d tiles, %d EditableImages, %d / %d bytes"):format(s.Tiles, s.EditableImages, s.EditableImageBytes, s.EditableImageCap))
        assert(s.EditableImages <= 10)
        Impl.SetEditableImageCap(nil)
        print("TILEBOUND OK")
    end
end)
