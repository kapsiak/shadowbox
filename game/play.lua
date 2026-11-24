-- A play session: what the player is doing to a level. Pure Lua.
-- Committed facts live in the history; a drag is a preview that commits only on drop. Pieces
-- in the tray can be turned too: `held` keeps their orientations for the session, and a drag
-- from the tray starts from them.
local hot = require "core.hot"
local rules = require "core.rules"
local state = require "core.state"
local history = require "core.history"
local orient = require "core.orient"
local grid = require "core.grid"
local raycast = require "core.raycast"
local shape = require "core.shape"

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
	return { level = level, history = history.new(M.fitting(level, saved)), selected = nil, drag = nil, held = {} }
end

-- Returns to a session left earlier, keeping its history but nothing in hand or hinted.
function M.resume(s)
	s.selected, s.drag, s.hint = nil, nil, nil
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

local function commit(s, command)
	local outcome, reason = rules.check(s.level, M.current(s), command)
	if not outcome then
		return false, reason
	end
	history.push(s.history, state.apply(M.current(s), outcome))
	return true
end

-- The grid indices of the cells piece `id` covers at `pose`, as a set.
local function cellSet(level, id, pose)
	local set = {}
	for _, c in ipairs(shape.cellsAt(level.pieces[id].shape, pose)) do
		set[grid.index(level.size, c)] = true
	end
	return set
end

-- Whether piece `id` covers its solution cells, in whatever orientation.
local function inPlace(level, poses, id)
	local pose = poses[id]
	if not pose then
		return false
	end
	local target = cellSet(level, id, level.solution[id])
	for _, c in ipairs(shape.cellsAt(level.pieces[id].shape, pose)) do
		if not target[grid.index(level.size, c)] then
			return false
		end
	end
	return true
end

-- Whether piece `id` at `pose` covers any cell in `set`.
local function overlaps(level, id, pose, set)
	for _, c in ipairs(shape.cellsAt(level.pieces[id].shape, pose)) do
		if set[grid.index(level.size, c)] then
			return true
		end
	end
	return false
end

-- Pieces bottom up by their solution cells: lowest layer first, then more cells on that layer.
local function hintOrder(level)
	local keys, order = {}, {}
	for id, pose in ipairs(level.solution) do
		local low, count = math.huge, 0
		for _, c in ipairs(shape.cellsAt(level.pieces[id].shape, pose)) do
			if c[2] < low then
				low, count = c[2], 1
			elseif c[2] == low then
				count = count + 1
			end
		end
		keys[id], order[id] = { low, -count }, id
	end
	table.sort(order, function(a, b)
		local ka, kb = keys[a], keys[b]
		if ka[1] ~= kb[1] then
			return ka[1] < kb[1]
		end
		if ka[2] ~= kb[2] then
			return ka[2] < kb[2]
		end
		return a < b
	end)
	return order
end

-- The hinted piece while it is away from its solution cells, else nil.
local function shownHint(s, poses)
	local id = s.hint and s.hint.piece
	return id and not inPlace(s.level, poses, id) and id or nil
end

-- Hints the lowest piece not yet in its solution cells (level.solution): pieces in its way go
-- back to the tray as one undoable step, and a piece in the tray turns to its solution
-- orientation. While a hint is showing it stays. Returns whether a new hint was given.
function M.hint(s)
	local current = M.current(s)
	if s.drag or shownHint(s, current.poses) then
		return false
	end
	local id
	for _, candidate in ipairs(hintOrder(s.level)) do
		if not inPlace(s.level, current.poses, candidate) then
			id = candidate
			break
		end
	end
	if not id then
		return false
	end
	local target = cellSet(s.level, id, s.level.solution[id])
	local poses, blocked = {}, false
	for other, pose in pairs(current.poses) do
		if other ~= id and overlaps(s.level, other, pose, target) then
			blocked = true
			s.held[other] = pose.orient
		else
			poses[other] = pose
		end
	end
	if blocked then
		history.push(s.history, { poses = poses })
	end
	if not poses[id] then
		s.held[id] = s.level.solution[id].orient
	end
	s.selected = nil
	s.hint = { piece = id, at = s.history.at }
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
	local drag = { piece = piece, from = from, orient = s.held[piece] or orient.identity, offset = { 0, 0, 0 },
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

-- The cells the other pieces occupy, for checking where `piece` may go.
local function othersOf(s, piece)
	return grid.occupancy(s.level, M.current(s).poses, piece)
end

-- How far a preview may move sideways from where it is aimed to become legal.
local SIDEWAYS = 2

-- The legal pose nearest `base`: each step out along the surface normal or sideways costs
-- one, and at equal cost stepping out wins. Nil if none is near.
local function nearestLegal(s, d, base, normal)
	local occupied = othersOf(s, d.piece)
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
					local pose = { cell = cell, orient = d.orient }
					if rules.checkPlace(s.level, occupied, d.piece, pose) then
						return { pose = pose, ok = true }
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
		local lo, hi = shape.bounds(s.level.pieces[d.piece].shape.forms[d.orient])
		local a = d.axis
		cell[a] = surface.cell[a] - (surface.normal[a] > 0 and lo[a] or hi[a]) + d.shift[a]
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
		s.held[d.piece] = d.orient
		return d.from ~= nil and commit(s, { kind = "remove", piece = d.piece })
	end
	if d.candidate and d.candidate.ok and not state.samePose(d.candidate.pose, d.from) then
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
-- place (nudging it if it collides) or in the tray. Turns are quarter turns about a world axis.
function M.turn(s, axis, dir)
	if s.drag then
		return turnDrag(s, s.drag, axis, dir)
	end
	if not s.selected then
		return false
	end
	local pose = M.current(s).poses[s.selected]
	if not pose then
		s.held[s.selected] = orient.turn(s.held[s.selected] or orient.identity, axis, dir)
		return true
	end
	local n, occupied = orient.turn(pose.orient, axis, dir), othersOf(s, s.selected)
	for _, k in ipairs(KICKS) do
		local turned = { cell = { pose.cell[1] + k[1], pose.cell[2] + k[2], pose.cell[3] + k[3] }, orient = n }
		if rules.checkPlace(s.level, occupied, s.selected, turned) then
			return commit(s, { kind = "place", piece = s.selected, pose = turned })
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

-- A tap on the already-selected piece, placed or in the tray, turns it; any other tap selects.
function M.tap(s, piece)
	if piece and piece == s.selected then
		return M.turn(s, 2, 1)
	end
	s.selected = piece
	return false
end

function M.removeSelected(s)
	local pose = s.selected and M.current(s).poses[s.selected]
	if pose and not s.drag then
		s.held[s.selected] = pose.orient
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
	if s.hint and s.history.at < s.hint.at then
		s.hint = nil
	end
end

function M.redo(s)
	s.drag = nil
	history.redo(s.history)
end

-- What to show this frame: committed poses with the drag preview laid over them.
-- Returns { poses, invalid = piece id or nil, dragging = piece id or nil, evaluation,
-- hint = { piece, pose } or nil (a ghost to show) }, the
-- same table until the state or the drag candidate changes (both are replaced, never mutated).
function M.display(s)
	local current, d = M.current(s), s.drag
	local candidate, dragging = d and d.candidate, d and d.piece
	local cached = s.shown
	if cached and cached.state == current and cached.candidate == candidate and cached.dragging == dragging
		and cached.hint == s.hint then
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
	local hinted = shownHint(s, poses)
	display.hint = hinted and { piece = hinted, pose = s.level.solution[hinted] }
	s.shown = { state = current, candidate = candidate, dragging = dragging, hint = s.hint, display = display }
	return display
end

return hot(..., M)
