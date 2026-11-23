-- A play session: what the player is doing to a level. Pure Lua.
-- Committed facts live in the history; a drag is a preview that commits only on drop.
local rules = require "core.rules"
local state = require "core.state"
local history = require "core.history"
local orient = require "core.orient"
local grid = require "core.grid"
local raycast = require "core.raycast"

local M = {}

-- Tried in order when a turned piece does not fit where it is: every offset within reach,
-- nearest first, then up before level before down.
local KICKS = {}
local KICK_REACH = 3
for x = -KICK_REACH, KICK_REACH do
	for y = -KICK_REACH, KICK_REACH do
		for z = -KICK_REACH, KICK_REACH do
			if math.abs(x) + math.abs(y) + math.abs(z) <= KICK_REACH then
				KICKS[#KICKS + 1] = { x, y, z }
			end
		end
	end
end
table.sort(KICKS, function(a, b)
	local da, db = math.abs(a[1]) + math.abs(a[2]) + math.abs(a[3]), math.abs(b[1]) + math.abs(b[2]) + math.abs(b[3])
	if da ~= db then
		return da < db
	end
	if a[2] ~= b[2] then
		return a[2] > b[2]
	end
	if a[1] ~= b[1] then
		return a[1] < b[1]
	end
	return a[3] < b[3]
end)

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

local function extent(cells, axis)
	local lo, hi = math.huge, -math.huge
	for _, c in ipairs(cells) do
		lo, hi = math.min(lo, c[axis]), math.max(hi, c[axis])
	end
	return lo, hi
end

-- Starts dragging `piece`. hit_cell is the board cell grabbed (nil when taken from the tray).
--
-- While dragging, the piece rests against the surface under the pointer (a face of a piece,
-- the floor or a wall): the grabbed cube, at `offset` from the anchor, lines up with the
-- pointer and the piece's near side touches the surface. If that pose overlaps or leaves the
-- board, the nearest legal one wins. Nudges add a `shift`. Before the pointer moves, a placed
-- piece turns about the grabbed cube (`pivot`). The preview is always legal: with no legal
-- pose near it keeps the last one, and off the board that pose is marked refused.
function M.grab(s, piece, hit_cell)
	local from = M.current(s).poses[piece]
	local drag = { piece = piece, from = from, orient = orient.identity, offset = { 0, 0, 0 },
		shift = { 0, 0, 0 }, axis = 2 }
	if from and hit_cell then
		drag.orient = from.orient
		drag.offset = { hit_cell[1] - from.cell[1], hit_cell[2] - from.cell[2], hit_cell[3] - from.cell[3] }
		drag.pivot = hit_cell
		drag.candidate = { pose = from, ok = true }
	end
	s.drag = drag
	s.selected = piece
end

local function check(s, d, cell)
	local pose = { cell = cell, orient = d.orient }
	local outcome, reason = rules.check(s.level, M.current(s), { kind = "place", piece = d.piece, pose = pose })
	return { pose = pose, ok = outcome ~= nil, reason = reason }
end

-- How far a preview may move sideways from where it is aimed to become legal.
local SIDEWAYS = 2

-- The legal pose nearest `base`: each step out along the surface normal or sideways costs
-- one, and at equal cost stepping out wins. Nil if none is near.
local function nearestLegal(s, d, base, normal)
	local a = M.dominantAxis(normal)
	local u, w = a % 3 + 1, (a + 1) % 3 + 1
	local reach = math.max(s.level.size[1], s.level.size[2], s.level.size[3])
	for cost = 0, reach + SIDEWAYS do
		for r = 0, math.min(cost, SIDEWAYS) do
			local k = cost - r
			for du = -r, r do
				local rest = r - math.abs(du)
				for _, dw in ipairs(rest == 0 and { 0 } or { -rest, rest }) do
					local cell = { base[1] + normal[1] * k, base[2] + normal[2] * k, base[3] + normal[3] * k }
					cell[u], cell[w] = cell[u] + du, cell[w] + dw
					local candidate = check(s, d, cell)
					if candidate.ok then
						return candidate
					end
				end
			end
		end
	end
end

-- Where the piece is aimed before it is made legal, for showing a refused turn.
local function aimed(s, d)
	local surface = d.surface
	local cell = {}
	for b = 1, 3 do
		cell[b] = (surface and surface.cell[b] or d.pivot[b]) - d.offset[b] + d.shift[b]
	end
	if surface then
		local lo, hi = extent(s.level.pieces[d.piece].shape.forms[d.orient], d.axis)
		cell[d.axis] = surface.cell[d.axis] - (surface.normal[d.axis] > 0 and lo or hi) + d.shift[d.axis]
	end
	return cell
end

local function aim(s, d)
	return nearestLegal(s, d, aimed(s, d), d.surface and d.surface.normal or { 0, 1, 0 })
end

-- The last legal preview is kept while nothing legal is near, unless the piece has turned
-- since: then it shows where it is aimed, refused, so the turn is never hidden.
local function updateCandidate(s, d)
	if d.off then
		d.candidate = d.candidate and { pose = d.candidate.pose, ok = false }
	elseif d.surface or d.pivot then
		local kept = d.candidate and d.candidate.ok and d.candidate.pose.orient == d.orient and d.candidate
		d.candidate = aim(s, d) or kept or { pose = { cell = aimed(s, d), orient = d.orient }, ok = false }
	end
end

-- Moves the drag preview to follow a world-space pointer ray.
function M.dragTo(s, origin, dir)
	local d = s.drag
	if not d then
		return
	end
	local size = s.level.size
	local occupied = grid.occupancy(s.level, M.current(s).poses, d.piece)
	d.surface = raycast.surface(size, origin, dir, function(c)
		return occupied[grid.index(size, c)] ~= nil
	end)
	d.off = d.surface == nil
	if d.surface then
		d.axis = M.dominantAxis(d.surface.normal)
	end
	updateCandidate(s, d)
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
		d.shift[axis] = d.shift[axis] + delta
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
-- Returns { poses, invalid = piece id or nil, dragging = piece id or nil, evaluation }, the
-- same table until the state or the drag candidate changes (both are replaced, never mutated).
function M.display(s)
	local current, d = M.current(s), s.drag
	local candidate, dragging = d and d.candidate, d and d.piece
	local cached = s.shown
	if cached and cached.state == current and cached.candidate == candidate and cached.dragging == dragging then
		return cached.display
	end
	local poses = {}
	for id, pose in pairs(current.poses) do
		poses[id] = pose
	end
	local invalid
	if candidate then
		poses[dragging] = candidate.pose
		invalid = not candidate.ok and dragging or nil
	end
	local display = {
		poses = poses,
		invalid = invalid,
		dragging = dragging,
		evaluation = rules.evaluate(s.level, invalid and current or { poses = poses }),
	}
	s.shown = { state = current, candidate = candidate, dragging = dragging, display = display }
	return display
end

return M
