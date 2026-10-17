-- Parallel raster worker (Actor LocalScript). The build inlines raster.lua for the Raster line.
local Actor = script:GetActor()
if not Actor then
	return
end

local Raster = require(script.Parent:WaitForChild("Raster"))
local Done = Actor:WaitForChild("Done")
local Textures = {}

Actor:BindToMessageParallel("job", function(Id, Prims, Tiles, TexUpdates, TileLength)
	for _, Texture in TexUpdates do
		if Texture[2] then
			local B, W, H, Fill = Texture[2], Texture[3], Texture[4], Texture[5]
			local n, total = buffer.len(B), W * H * 4
			if n < total then -- the rows below were left out: all Fill (parallel.lua fullCopy)
				local Full = buffer.create(total)
				buffer.copy(Full, 0, B)
				if Fill ~= 0 then
					buffer.writeu32(Full, n, Fill)
					local k = 4
					while k < total - n do
						local c = math.min(k, total - n - k)
						buffer.copy(Full, n + k, Full, n, c)
						k += c
					end
				end
				B = Full
			end
			Textures[Texture[1]] = { Buffer = B, Width = W, Height = H }
		else -- rows changed since the copy this Actor has
			local T = Textures[Texture[1]]
			buffer.copy(T.Buffer, Texture[5], Texture[6])
		end
	end
	local Results = Raster.RasterJobs(Prims, Tiles, TileLength, Textures)
	task.synchronize()
	Done:Fire(Id, Results)
end)

Actor:SetAttribute("Ready", true)
