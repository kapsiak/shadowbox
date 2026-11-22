-- A play session: what the player is doing to a level. Pure Lua.
-- Committed facts live in the history; a drag is a preview that commits only on drop.
local rules = require "core.rules"
local state = require "core.state"
local history = require "core.history"
local orient = require "core.orient"
local grid = require "core.grid"
local raycast = require "core.raycast"

local M = {}

-- Tried in order when a turned piece does not fit where it is.
local KICKS = {
	{ 0, 0, 0 }, { 0, 1, 0 }, { 1, 0, 0 }, { -1, 0, 0 },
	{ 0, 0, 1 }, { 0, 0, -1 }, { 0, -1, 0 }, { 0, 2, 0 },
}

-- The state holding those of `poses` ({ [piece_id] = pose }) that fit the level; the rest
-- are left in the tray.
function M.fitting(level, poses)
	local fit = state.new()
	for id, pose in pairs(poses or {}) do
		local outcome = level.pieces[id] and rules.check(level, fit, { kind = "place", piece = id, pose = pose })
		if outcome then
			fit = state.apply(fit, outcome)
		end
	end
	return fit
end

-- saved: optional poses from an earlier visit; poses that no longer fit are dropped.
function M.new(level, saved)
	return { level = level, history = history.new(M.fitting(level, saved)), selected = nil, drag = nil }
end

-- Returns to a session left earlier, keeping its history but nothing in hand.
function M.resume(s)
	s.selected, s.drag = nil, nil
	return s
end

-- True when any piece is on the board.
function M.hasProgress(s)
	return next(M.current(s).poses) ~= nil
end

function M.current(s)
	return history.current(s.history)
end

function M.isSolved(s)
	return rules.evaluate(s.level, M.current(s)).solved
end

local function samePose(a, b)
	return a and b and a.orient == b.orient
		and a.cell[1] == b.cell[1] and a.cell[2] == b.cell[2] and a.cell[3] == b.cell[3]
end

local function commit(s, command)
	local outcome, reason = rules.check(s.level, M.current(s), command)
	if not outcome then
		return false, reason
	end
	history.push(s.history, state.apply(M.current(s), outcome))
	return true
end

-- Index of the largest component of v, and that component's sign.
function M.dominantAxis(v)
	local axis = 1
	for a = 2, 3 do
		if math.abs(v[a]) > math.abs(v[axis]) then
			axis = a
		end
	end
	return axis, v[axis] < 0 and -1 or 1
end

-- Pieces slide on the floor plane unless the camera looks nearly level, in which case
-- they move on the vertical plane that faces it.
local LEVEL_VIEW = math.sin(math.rad(20))

local function dragAxis(eye_dir)
	if math.abs(eye_dir[2]) >= LEVEL_VIEW then
		return 2
	end
	return (M.dominantAxis({ eye_dir[1], 0, eye_dir[3] }))
end

local function extent(cells, axis)
	local lo, hi = math.huge, -math.huge
	for _, c in ipairs(cells) do
		lo, hi = math.min(lo, c[axis]), math.max(hi, c[axis])
	end
	return lo, hi
end

-- Starts dragging `piece`. hit_cell is the board cell grabbed (nil when taken from the tray).
-- eye_dir points from the board toward the camera and picks the drag axis: the axis the
-- pointer cannot express. On the floor that is height, from a level view it is depth.
--
-- While dragging, the grabbed cube sits at `offset` from the piece's anchor and follows the
-- pointer cell. Along the drag axis the piece settles by itself: on the floor it drops onto
-- whatever lies below, otherwise it moves to the nearest free layer. Nudging along the drag
-- axis turns settling off and holds the piece at an exact `layer`.
function M.grab(s, piece, hit_cell, eye_dir)
	local from = M.current(s).poses[piece]
	local drag = { piece = piece, from = from, axis = dragAxis(eye_dir), settle = true }
	if from and hit_cell then
		drag.orient = from.orient
		drag.offset = { hit_cell[1] - from.cell[1], hit_cell[2] - from.cell[2], hit_cell[3] - from.cell[3] }
		drag.layer = hit_cell[drag.axis]
		drag.pointer = hit_cell
		drag.candidate = { pose = from, ok = true }
	else
		drag.orient = orient.identity
		drag.offset = { 0, 0, 0 }
		drag.layer = math.floor(s.level.size[drag.axis] / 2)
	end
	s.drag = drag
	s.selected = piece
end

local function check(s, d, cell)
	local pose = { cell = cell, orient = d.orient }
	local outcome, reason = rules.check(s.level, M.current(s), { kind = "place", piece = d.piece, pose = pose })
	return { pose = pose, ok = outcome ~= nil, reason = reason }
end

local function withAxis(cell, axis, value)
	local c = { cell[1], cell[2], cell[3] }
	c[axis] = value
	return c
end

-- Drops from the top of the board and stops on the first surface below, like stacking blocks.
local function dropFromAbove(s, d, cell)
	local lo, hi = extent(s.level.pieces[d.piece].shape.forms[d.orient], 2)
	local top, bottom = s.level.size[2] - 1 - hi, -lo
	local resting
	for y = top, bottom, -1 do
		local candidate = check(s, d, withAxis(cell, 2, y))
		if not candidate.ok then
			break
		end
		resting = candidate
	end
	return resting or check(s, d, withAxis(cell, 2, bottom))
end

-- The free layer along the drag axis nearest to where the piece is held.
local function nearestFree(s, d, cell)
	local held = d.layer - d.offset[d.axis]
	for k = 0, s.level.size[d.axis] do
		for _, layer in ipairs(k == 0 and { held } or { held - k, held + k }) do
			local candidate = check(s, d, withAxis(cell, d.axis, layer))
			if candidate.ok then
				return candidate
			end
		end
	end
	return check(s, d, withAxis(cell, d.axis, held))
end

local function updateCandidate(s, d)
	if not d.pointer then
		return
	end
	local cell = {}
	for a = 1, 3 do
		cell[a] = d.pointer[a] - d.offset[a]
	end
	if not d.settle then
		d.candidate = check(s, d, withAxis(cell, d.axis, d.layer - d.offset[d.axis]))
	elseif d.axis == 2 then
		d.candidate = dropFromAbove(s, d, cell)
	else
		d.candidate = nearestFree(s, d, cell)
	end
end

-- The board column under a pointer ray, looking over the tops of other pieces: a top face
-- gives its own column, a side face the column in front of it, and empty space the floor.
local function columnUnder(s, d, origin, dir)
	local size = s.level.size
	local occupied = grid.occupancy(s.level, M.current(s).poses, d.piece)
	local cell, normal = raycast.firstHit(size, origin, dir, function(c)
		return occupied[grid.index(size, c)] ~= nil
	end)
	if cell and normal and normal[2] == 0 then
		return { cell[1] + normal[1], 0, cell[3] + normal[3] }
	elseif cell then
		return { cell[1], 0, cell[3] }
	end
	if dir[2] >= 0 then
		return nil
	end
	local t = -origin[2] / dir[2]
	return { math.floor(origin[1] + dir[1] * t), 0, math.floor(origin[3] + dir[3] * t) }
end

-- Moves the drag preview to follow a world-space pointer ray.
function M.dragTo(s, origin, dir)
	local d = s.drag
	if not d then
		return
	end
	local pointer
	if d.axis == 2 then
		pointer = columnUnder(s, d, origin, dir)
	elseif math.abs(dir[d.axis]) > 1e-6 then
		local t = (d.layer + 0.5 - origin[d.axis]) / dir[d.axis]
		pointer = t >= 0 and withAxis({
			math.floor(origin[1] + dir[1] * t), math.floor(origin[2] + dir[2] * t), math.floor(origin[3] + dir[3] * t),
		}, d.axis, d.layer) or nil
	end
	if pointer then
		d.pointer = pointer
		updateCandidate(s, d)
	end
end

-- Ends the drag: into the tray removes the piece, otherwise a legal preview is committed.
function M.drop(s, into_tray)
	local d = s.drag
	s.drag = nil
	if not d then
		return false
	end
	if into_tray then
		return d.from ~= nil and commit(s, { kind = "remove", piece = d.piece })
	end
	if d.candidate and d.candidate.ok and not samePose(d.candidate.pose, d.from) then
		return commit(s, { kind = "place", piece = d.piece, pose = d.candidate.pose })
	end
	return false
end

local function turnDrag(s, d, axis, dir)
	d.orient = orient.turn(d.orient, axis, dir)
	d.offset = orient.apply(orient.turn(orient.identity, axis, dir), d.offset)
	updateCandidate(s, d)
	return true
end

-- Turns the dragged piece about the cube under the pointer, or else the selected piece in
-- place (nudging it if it collides). Turns are quarter turns about a world axis.
function M.turn(s, axis, dir)
	if s.drag then
		return turnDrag(s, s.drag, axis, dir)
	end
	local pose = s.selected and M.current(s).poses[s.selected]
	if not pose then
		return false
	end
	local n = orient.turn(pose.orient, axis, dir)
	for _, k in ipairs(KICKS) do
		local cell = { pose.cell[1] + k[1], pose.cell[2] + k[2], pose.cell[3] + k[3] }
		if commit(s, { kind = "place", piece = s.selected, pose = { cell = cell, orient = n } }) then
			return true
		end
	end
	return false
end

-- Moves the dragged preview, or else the selected piece, by `delta` cells along a world axis.
function M.nudge(s, axis, delta)
	local d = s.drag
	if d then
		if axis == d.axis then
			local held = d.candidate and d.candidate.pose.cell[axis] + d.offset[axis] or d.layer
			d.layer = held + delta
			d.settle = false
		else
			d.offset[axis] = d.offset[axis] - delta
		end
		updateCandidate(s, d)
		return true
	end
	local pose = s.selected and M.current(s).poses[s.selected]
	if not pose then
		return false
	end
	local cell = { pose.cell[1], pose.cell[2], pose.cell[3] }
	cell[axis] = cell[axis] + delta
	return commit(s, { kind = "place", piece = s.selected, pose = { cell = cell, orient = pose.orient } })
end

-- A tap on the already-selected placed piece turns it; any other tap selects.
function M.tap(s, piece)
	if piece and piece == s.selected and M.current(s).poses[piece] then
		return M.turn(s, 2, 1)
	end
	s.selected = piece
	return false
end

function M.removeSelected(s)
	if s.selected and M.current(s).poses[s.selected] and not s.drag then
		return commit(s, { kind = "remove", piece = s.selected })
	end
	return false
end

function M.canUndo(s)
	return history.canUndo(s.history)
end

function M.canRedo(s)
	return history.canRedo(s.history)
end

function M.undo(s)
	s.drag = nil
	history.undo(s.history)
end

function M.redo(s)
	s.drag = nil
	history.redo(s.history)
end

-- What to show this frame: committed poses with the drag preview laid over them.
-- Returns { poses, invalid = piece id or nil, dragging = piece id or nil, evaluation }.
function M.display(s)
	local poses = {}
	for id, pose in pairs(M.current(s).poses) do
		poses[id] = pose
	end
	local d, invalid = s.drag, nil
	if d and d.candidate then
		poses[d.piece] = d.candidate.pose
		invalid = not d.candidate.ok and d.piece or nil
	end
	local shown = invalid and M.current(s) or { poses = poses }
	return {
		poses = poses,
		invalid = invalid,
		dragging = d and d.piece,
		evaluation = rules.evaluate(s.level, shown),
	}
end

return M
