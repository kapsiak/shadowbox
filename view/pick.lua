local hot = require "core.hot"
local grid = require "core.grid"
local raycast = require "core.raycast"

local M = {}

function M.piece(level, state, origin, dir)
	local occupied = grid.occupancy(level, state.poses)
	local cell, normal = raycast.firstHit(level.size, origin, dir, function(c)
		return occupied[grid.index(level.size, c)] ~= nil
	end)
	if cell then
		return occupied[grid.index(level.size, cell)], cell, normal
	end
end

return hot(..., M)
