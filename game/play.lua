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

-- Placement while dragging: every legal pose of the piece that touches something (the floor,
-- a wall behind the board or another piece) is a candidate. The face under the pointer names a
-- target, the free cell in front of it, and the candidate scoring lowest wins. Terms, in cells:
--   target  how far the grabbed cube lies from the target (at most REACH)
--   miss    how far it lies from the pointer ray, times MISS (breaks ties within a cell)
--   snug    faces touching the floor, walls or pieces per cube, times -FIT (fits are preferred)
-- The result depends only on where the pointer is, so going back restores what was shown.
-- Before the pointer moves, a turned placed piece keeps its grabbed cube within PIVOT_REACH
-- cells of where it was.
local REACH = 1.5
local MISS = 0.3
local FIT = 0.1
local PIVOT_REACH = 3

local FACES = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }

-- The middle of a piece in orientation n, from its anchor: the mean of its cubes' offsets.
local function middleOf(level, id, n)
	local m, form = { 0, 0, 0 }, level.pieces[id].shape.forms[n]
	for _, c in ipairs(form) do
		for a = 1, 3 do
			m[a] = m[a] + c[a] / #form
		end
	end
	return m
end

local function distance(a, b)
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

-- The side (-1 low, 1 high) of the x and z walls, which stand behind the board seen along `dir`.
local function wallsBehind(dir)
	return dir[1] > 0 and 1 or -1, dir[3] > 0 and 1 or -1
end

-- Starts dragging `piece`. hit_cell is the board cell grabbed (nil when taken from the tray);
-- dir, the pointer ray's direction, tells which walls stand behind the board.
-- The grabbed cube sits at `offset` from the anchor; nudges add a `shift`. The preview is always
-- legal: with no candidate near it keeps the last one, and off the board that one is refused.
function M.grab(s, piece, hit_cell, dir)
	local from = M.current(s).poses[piece]
	local drag = { piece = piece, from = from, orient = s.held[piece] or orient.identity, offset = { 0, 0, 0 },
		shift = { 0, 0, 0 }, axis = 2, selected = s.selected, wall_x = -1, wall_z = -1 }
	if dir then
		drag.wall_x, drag.wall_z = wallsBehind(dir)
	end
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

local function occupiedOf(s, d)
	d.occupied = d.occupied or othersOf(s, d.piece)
	return d.occupied
end

-- Faces of `cells` touching the floor, a wall behind the board or another piece, per cube.
local function snugness(size, occupied, d, cells)
	local faces = 0
	for _, c in ipairs(cells) do
		for _, f in ipairs(FACES) do
			local m = { c[1] + f[1], c[2] + f[2], c[3] + f[3] }
			if grid.contains(size, m) then
				faces = faces + (occupied[grid.index(size, m)] and 1 or 0)
			elseif m[2] < 0 or (f[1] ~= 0 and f[1] == d.wall_x) or (f[3] ~= 0 and f[3] == d.wall_z) then
				faces = faces + 1
			end
		end
	end
	return faces / #cells
end

-- The candidates for the drag's orientation: { pose, snug } for each legal pose touching something.
local function candidatesOf(s, d)
	local level, size = s.level, s.level.size
	local occupied, form = occupiedOf(s, d), level.pieces[d.piece].shape
	local list = {}
	d.middle = middleOf(level, d.piece, d.orient)
	for x = 0, size[1] - 1 do
		for y = 0, size[2] - 1 do
			for z = 0, size[3] - 1 do
				local pose = { cell = { x, y, z }, orient = d.orient }
				if rules.checkPlace(level, occupied, d.piece, pose) then
					local snug = snugness(size, occupied, d, shape.cellsAt(form, pose))
					if snug > 0 then
						list[#list + 1] = { pose = pose, snug = snug }
					end
				end
			end
		end
	end
	return list
end

-- How far the point (x, y, z) lies from the pointer ray.
local function offRay(d, x, y, z)
	local origin, dir = d.origin, d.dir
	local rx, ry, rz = x - origin[1], y - origin[2], z - origin[3]
	local t = rx * dir[1] + ry * dir[2] + rz * dir[3]
	local px, py, pz = rx - t * dir[1], ry - t * dir[2], rz - t * dir[3]
	return math.sqrt(px * px + py * py + pz * pz)
end

-- Where the grabbed cube is held in place before the pointer moves, if it is.
local function heldAt(d)
	return not d.dir and d.pivot
end

-- Candidate `c`'s score, aimed by the pointer ray (d.origin, d.dir; d.surface: the surface it
-- meets), at where the grabbed cube is held, or while turning at the piece's middle as it was
-- (d.spin.center). Nil when out of reach.
local function score(d, c)
	local p, o = c.pose.cell, d.offset
	if d.spin then
		local m = d.middle
		local away = distance({ p[1] + m[1] + 0.5, p[2] + m[2] + 0.5, p[3] + m[3] + 0.5 }, d.spin.center)
		return away <= PIVOT_REACH and away - FIT * c.snug or nil
	end
	local x, y, z = p[1] + o[1] + 0.5, p[2] + o[2] + 0.5, p[3] + o[3] + 0.5
	local held = heldAt(d)
	local target = held or d.surface and d.surface.cell
	if not target then
		return nil
	end
	local away = math.sqrt((x - target[1] - 0.5) ^ 2 + (y - target[2] - 0.5) ^ 2 + (z - target[3] - 0.5) ^ 2)
	if held then
		return away <= PIVOT_REACH and away - FIT * c.snug or nil
	end
	if away > REACH then
		return nil
	end
	return away + MISS * offRay(d, x, y, z) - FIT * c.snug
end

-- The candidate scoring lowest, or nil when none is in reach.
local function choose(d)
	local best, best_score
	for _, c in ipairs(d.candidates) do
		local value = score(d, c)
		if value and (not best_score or value < best_score) then
			best, best_score = c, value
		end
	end
	return best
end

-- Where the piece is aimed before it is made legal, for showing a refused turn.
local function aimed(d)
	local cell = {}
	if d.spin then
		for b = 1, 3 do
			cell[b] = math.floor(d.spin.center[b] - d.middle[b]) + d.shift[b]
		end
		return cell
	end
	local base = heldAt(d) or d.surface and d.surface.cell
	for b = 1, 3 do
		cell[b] = base[b] - d.offset[b] + d.shift[b]
	end
	return cell
end

-- The candidate as shown: the chosen pose moved by the drag's shift, refused if that is
-- illegal. The same table while nothing changes, so the display is not rebuilt.
local function preview(s, d, pose, ok)
	local sh = d.shift
	if ok and (sh[1] ~= 0 or sh[2] ~= 0 or sh[3] ~= 0) then
		local c = pose.cell
		pose = { cell = { c[1] + sh[1], c[2] + sh[2], c[3] + sh[3] }, orient = pose.orient }
		ok = rules.checkPlace(s.level, occupiedOf(s, d), d.piece, pose) ~= nil
	end
	local last = d.candidate
	if last and last.ok == ok and state.samePose(last.pose, pose) then
		return last
	end
	return { pose = pose, ok = ok }
end

-- With no candidate near, the last legal preview is kept, unless the piece has turned since:
-- then it shows where it is aimed, refused, so the turn is never hidden. Off the board the
-- last preview is refused.
local function updateCandidate(s, d)
	if not (d.dir or d.spin or heldAt(d)) then
		return
	end
	d.candidates = d.candidates or candidatesOf(s, d)
	local choice, last = choose(d), d.candidate
	if choice then
		d.candidate = preview(s, d, choice.pose, true)
	elseif d.off then
		d.candidate = last and preview(s, d, last.pose, false)
	elseif not (last and last.ok and last.pose.orient == d.orient) then
		d.candidate = preview(s, d, { cell = aimed(d), orient = d.orient }, false)
	end
end

-- Moves the drag preview to follow a world-space pointer ray.
-- How far outside the board a pointer ray may pass and still aim at its nearest edge cell.
local EDGE = 1

local function noneSolid()
	return false
end

-- The surface the ray meets (core/raycast surface); a ray passing just beside the board meets
-- its nearest edge cell instead, so the board's rim is forgiving. Nil further out.
local function surfaceOf(size, occupied, origin, dir)
	local surface = raycast.surface(size, origin, dir, function(c)
		return occupied[grid.index(size, c)] ~= nil
	end)
	if surface then
		return surface
	end
	local wide = { size[1] + 2 * EDGE, size[2] + 2 * EDGE, size[3] + 2 * EDGE }
	local edge = raycast.surface(wide, { origin[1] + EDGE, origin[2] + EDGE, origin[3] + EDGE }, dir, noneSolid)
	if not edge then
		return nil
	end
	local cell = {}
	for a = 1, 3 do
		cell[a] = math.max(0, math.min(size[a] - 1, edge.cell[a] - EDGE))
	end
	return { cell = cell, normal = edge.normal }
end

function M.dragTo(s, origin, dir)
	local d = s.drag
	if not d or d.spin then
		return
	end
	d.surface = surfaceOf(s.level.size, occupiedOf(s, d), origin, dir)
	d.off = d.surface == nil
	if d.surface then
		d.axis = M.dominantAxis(d.surface.normal)
	end
	local wall_x, wall_z = wallsBehind(dir)
	if wall_x ~= d.wall_x or wall_z ~= d.wall_z then
		d.wall_x, d.wall_z, d.candidates = wall_x, wall_z, nil
	end
	d.origin, d.dir = origin, dir
	updateCandidate(s, d)
end

-- Row-major 3x3 rotations, as core/orient keeps them.
local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }

local function mul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 1, 3 do
			r[i * 3 + j] = a[i * 3 + 1] * b[j] + a[i * 3 + 2] * b[3 + j] + a[i * 3 + 3] * b[6 + j]
		end
	end
	return r
end

local function transpose(m)
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end

-- The rotation by `angle` radians about the unit vector `axis` (Rodrigues).
local function rotation(axis, angle)
	local x, y, z = axis[1], axis[2], axis[3]
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	return {
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c,
	}
end

local function apply(m, v)
	return { m[1] * v[1] + m[2] * v[2] + m[3] * v[3], m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3] }
end

-- Turns the dragged piece by `angle` radians about the world `axis` (a unit vector) through its
-- middle, which stays where it is shown. Its orientation is the nearest of the 24 to the turn so
-- far, placed nearest that middle; the rest of the turn is only shown (see `spinning`). The
-- grabbed cube turns with it. Returns whether that orientation changed. Needs a preview on the
-- board.
function M.spin(s, axis, angle)
	local d = s.drag
	local c = d and d.candidate
	if not c then
		return false
	end
	if not d.spin then
		local base, p = orient.matrix(d.orient), c.pose.cell
		local m = middleOf(s.level, d.piece, c.pose.orient)
		local center = { p[1] + m[1] + 0.5, p[2] + m[2] + 0.5, p[3] + m[3] + 0.5 }
		d.spin = { free = IDENTITY, base = base, grip = apply(transpose(base), d.offset), center = center }
	end
	local sp = d.spin
	sp.free = mul(rotation(axis, angle), sp.free)
	local n = orient.nearest(mul(sp.free, sp.base))
	if n == d.orient then
		return false
	end
	local offset = apply(orient.matrix(n), sp.grip)
	for a = 1, 3 do
		offset[a] = math.floor(offset[a] + 0.5)
	end
	d.orient, d.offset, d.candidates = n, offset, nil
	updateCandidate(s, d)
	return true
end

-- Ends free turning: the piece keeps its nearest orientation and follows the pointer again.
function M.settle(s)
	if s.drag then
		s.drag.spin = nil
	end
end

-- While turning, how to show the dragged piece turning in place: the rotation still to show on
-- top of its orientation (row-major), the point it turns about (its middle when the turn began,
-- in world units), and how far the preview's middle lies from there. Nil otherwise.
function M.spinning(s)
	local d = s.drag
	local sp = d and d.spin
	local c = sp and d.candidate
	if not c then
		return nil
	end
	local p, m, at = c.pose.cell, middleOf(s.level, d.piece, c.pose.orient), sp.center
	local moved = { p[1] + m[1] + 0.5 - at[1], p[2] + m[2] + 0.5 - at[2], p[3] + m[3] + 0.5 - at[3] }
	return mul(mul(sp.free, sp.base), transpose(orient.matrix(c.pose.orient))), at, moved
end

-- Abandons the drag: the piece stays as it was and the selection as it was before the grab.
function M.cancel(s)
	if s.drag then
		s.selected, s.drag = s.drag.selected, nil
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
		s.held[d.piece] = d.orient
		return d.from ~= nil and commit(s, { kind = "remove", piece = d.piece })
	end
	if d.candidate and d.candidate.ok and not state.samePose(d.candidate.pose, d.from) then
		return commit(s, { kind = "place", piece = d.piece, pose = d.candidate.pose })
	end
	return false
end

local function turnDrag(s, d, axis, dir)
	d.spin = nil
	d.orient = orient.turn(d.orient, axis, dir)
	d.offset = orient.apply(orient.turn(orient.identity, axis, dir), d.offset)
	d.candidates = nil
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
