-- Does: the mutable facts of a game in progress. A state is { poses = { [piece_id] = pose } };
-- a piece without a pose is in the tray. States are treated as immutable values.
local hot = require "core.hot"
local M = {}

function M.new()
	return { poses = {} }
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
