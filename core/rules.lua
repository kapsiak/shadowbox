-- Decides: turns commands into outcomes (or reasons they are refused) and
-- evaluates a state against the level. Nothing here changes state.
--
-- Commands:  { kind = "place", piece = id, pose = pose }  |  { kind = "remove", piece = id }
-- Outcome:   { changes = { { piece = id, pose = pose_or_nil }, ... } }
local shape = require "core.shape"
local grid = require "core.grid"
local projection = require "core.projection"

local M = {}

local function checkPlace(level, state, id, pose)
	local occupied = grid.occupancy(level, state.poses, id)
	for _, c in ipairs(shape.cellsAt(level.pieces[id].shape, pose)) do
		if not grid.contains(level.size, c) then
			return nil, "out_of_bounds"
		end
		if occupied[grid.index(level.size, c)] then
			return nil, "overlap"
		end
	end
	return { changes = { { piece = id, pose = pose } } }
end

function M.check(level, state, command)
	if not level.pieces[command.piece] then
		return nil, "unknown_piece"
	end
	if command.kind == "place" then
		return checkPlace(level, state, command.piece, command.pose)
	end
	if command.kind == "remove" then
		return { changes = { { piece = command.piece } } }
	end
	return nil, "unknown_command"
end

-- Projections of the current arrangement compared to each target, and whether the level is solved.
function M.evaluate(level, state)
	local cells, placed = {}, 0
	for id, pose in pairs(state.poses) do
		placed = placed + 1
		for _, c in ipairs(shape.cellsAt(level.pieces[id].shape, pose)) do
			cells[#cells + 1] = c
		end
	end
	local views, solved = {}, true
	for _, v in ipairs(level.views) do
		views[v] = projection.compare(level.targets[v], projection.project(level.size, cells, v))
		solved = solved and views[v].matches
	end
	if level.rules.use_all then
		solved = solved and placed == #level.pieces
	end
	return { views = views, solved = solved }
end

return M
