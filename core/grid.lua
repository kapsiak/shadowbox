-- The board volume: bounds, cell indexing, and occupancy derived from poses.
local shape = require "core.shape"

local M = {}

function M.contains(size, c)
	return c[1] >= 0 and c[2] >= 0 and c[3] >= 0
		and c[1] < size[1] and c[2] < size[2] and c[3] < size[3]
end

function M.index(size, c)
	return c[1] + size[1] * (c[2] + size[2] * c[3]) + 1
end

-- Maps cell index -> piece id for every placed piece except `skip_id`.
function M.occupancy(level, poses, skip_id)
	local occupied = {}
	for id, pose in pairs(poses) do
		if id ~= skip_id then
			for _, c in ipairs(shape.cellsAt(level.pieces[id].shape, pose)) do
				occupied[M.index(level.size, c)] = id
			end
		end
	end
	return occupied
end

return M
