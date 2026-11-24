-- Does: the mutable facts of a game in progress. A state is { poses = { [piece_id] = pose } };
-- a piece without a pose is in the tray. States are treated as immutable values.
local hot = require "core.hot"
local M = {}

function M.new()
	return { poses = {} }
end

-- Whether two poses (or nils) put a piece in the same place.
function M.samePose(a, b)
	return a == b or (a ~= nil and b ~= nil and a.orient == b.orient
		and a.cell[1] == b.cell[1] and a.cell[2] == b.cell[2] and a.cell[3] == b.cell[3])
end

function M.apply(state, outcome)
	local poses = {}
	for id, pose in pairs(state.poses) do
		poses[id] = pose
	end
	for _, change in ipairs(outcome.changes) do
		poses[change.piece] = change.pose
	end
	return { poses = poses }
end

return hot(..., M)
