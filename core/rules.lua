-- Decides: turns commands into outcomes (or reasons they are refused) and
-- evaluates a state against the level. Nothing here changes state.
--
-- Commands:  { kind = "place", piece = id, pose = pose }  |  { kind = "remove", piece = id }
-- Outcome:   { changes = { { piece = id, pose = pose_or_nil }, ... } }
local hot = require "core.hot"
local shape = require "core.shape"
local grid = require "core.grid"
local projection = require "core.projection"

local M = {}

-- Placing piece `id` at `pose`, given the cells the other pieces occupy (grid.occupancy without
-- `id`), so callers trying many poses build the occupancy once.
function M.checkPlace(level, occupied, id, pose)
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
		return M.checkPlace(level, grid.occupancy(level, state.poses, command.piece), command.piece, command.pose)
	end
	if command.kind == "remove" then
		return { changes = { { piece = command.piece } } }
	end
	return nil, "unknown_command"
end

-- Projections of the current arrangement compared to each target, and whether the level is solved.
function M.evaluate(level, state)
	local items, placed = {}, 0
	for id, pose in pairs(state.poses) do
		placed = placed + 1
		local piece = level.pieces[id]
		items[#items + 1] = { cells = shape.cellsAt(piece.shape, pose), value = piece.value }
	end
	local views, solved = {}, true
	for _, v in ipairs(level.views) do
		local current = projection.project(level.size, v, level.channels[v], items)
		views[v] = projection.compare(level.targets[v], current)
		solved = solved and views[v].matches
	end
	if level.rules.use_all then
		solved = solved and placed == #level.pieces
	end
	return { views = views, solved = solved }
end

return hot(..., M)
