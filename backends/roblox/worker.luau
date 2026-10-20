-- Parallel raster worker (Actor LocalScript). The build inlines raster.lua for the Raster line.
local Actor = script:GetActor()
if not Actor then
	return
end

local Raster = require(script.Parent:WaitForChild("Raster"))
local Done = Actor:WaitForChild("Done")
local Textures = {}

Actor:BindToMessageParallel("job", function(Id, Prims, Tiles, TexUpdates, TileLength, Dropped)
	-- this Actor's texture copies: destroyed ids dropped, changed rows/rects patched (parallel.lua Flush)
	Raster.ApplyTextures(Textures, TexUpdates, Dropped)
	local Results = Raster.RasterJobs(Prims, Tiles, TileLength, Textures)
	task.synchronize()
	Done:Fire(Id, Results)
end)

Actor:SetAttribute("Ready", true)
