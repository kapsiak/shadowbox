local hot = require "core.hot"
local shape = require "core.shape"

local M = {}

function M.contains(size, c)
	return c[1] >= 0 and c[2] >= 0 and c[3] >= 0
		and c[1] < size[1] and c[2] < size[2] and c[3] < size[3]
end

function M.index(size, c)
	return c[1] + size[1] * (c[2] + size[2] * c[3]) + 1
end

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

return hot(..., M)
