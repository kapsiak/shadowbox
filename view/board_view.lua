-- Presents the board: pieces at their displayed poses, and the projection walls (view/walls_view).
-- Pieces move on springs, lift while dragged, shake when a move is refused, and hop when the
-- level is solved. A hint shows as a ghost of a piece at its solution pose. Owns its game objects; rebound to another level in place (see
-- view/board_pool), it replaces its piece objects and keeps the walls. Never touches game state.
local hot = require "core.hot"
local orient = require "core.orient"
local state = require "core.state"
local memo = require "core.memo"
local palette = require "view.palette"
local motion = require "view.motion"
local walls_view = require "view.walls_view"
local piece_look = require "view.piece_look"

local M = {}

local SPRING_OMEGA, SPRING_ZETA = 26, 0.62
local TURN_RATE = 16
local FX_RATE = 12
local LIFT = 0.16
local LIFT_SCALE = 1.04
local SHAKE_DECAY = 3.2
local SHAKE_AMPLITUDE = 0.09
local HOP_HEIGHT, HOP_TIME, HOP_STAGGER = 0.45, 0.5, 0.09
local MAX_DT = 1 / 30
local REST = 1e-6

-- The rotation of orientation n (core/orient) as a quaternion.
function M.poseRotation(n)
	local x, y, z = orient.apply(n, { 1, 0, 0 }), orient.apply(n, { 0, 1, 0 }), orient.apply(n, { 0, 0, 1 })
	return vmath.quat_basis(vmath.vector3(x[1], x[2], x[3]), vmath.vector3(y[1], y[2], y[3]), vmath.vector3(z[1], z[2], z[3]))
end

local function cellCenter(c)
	return vmath.vector3(c[1] + 0.5, c[2] + 0.5, c[3] + 0.5)
end

-- An empty board under `parent`, a game object whose transform places it in the world.
-- factories: { piece, glass_piece, ghost_piece, panel } urls.
function M.create(factories, parent)
	local ghost = factory.create(factories.ghost_piece)
	go.set_parent(ghost, parent)
	local mesh = msg.url(nil, ghost, "mesh")
	piece_look.applyLight(mesh)
	go.set(mesh, "fx", vmath.vector4(0, 1, 0, 0))
	msg.post(mesh, "disable")
	return {
		factories = factories, parent = parent, pieces = {}, time = 0, presented = {},
		ghost = { go = msg.url(nil, ghost, nil), mesh = mesh, hint = nil },
		walls = walls_view.create(factories.panel, parent),
	}
end

-- Shows `hint` ({ piece, pose } or nil) as a ghost; its look follows the pieces'.
local function showGhost(view, hint)
	local ghost = view.ghost
	if not hint then
		if ghost.hint then
			msg.post(ghost.mesh, "disable")
		end
		ghost.hint = nil
		return
	end
	if not ghost.hint then
		msg.post(ghost.mesh, "enable")
	end
	ghost.hint = hint
	go.set(ghost.mesh, "vertices", view.buffers[hint.piece])
	if view.look then
		piece_look.apply(ghost.mesh, view.level, hint.piece, view.look)
	end
	go.set_position(cellCenter(hint.pose.cell), ghost.go)
	go.set_rotation(M.poseRotation(hint.pose.orient), ghost.go)
end

local function clearPieces(view)
	for _, p in pairs(view.pieces) do
		go.delete(p.go)
	end
	view.pieces = {}
end

-- Shows `level` with no pieces placed; buffers: its piece meshes by piece id.
function M.bind(view, level, buffers)
	clearPieces(view)
	showGhost(view, nil)
	view.level, view.buffers, view.time, view.look, view.presented = level, buffers, 0, nil, {}
	for _, piece in ipairs(level.pieces) do
		local object = factory.create(palette.isGlass(piece) and view.factories.glass_piece or view.factories.piece)
		local id = msg.url(nil, object, nil)
		go.set_parent(id, view.parent)
		local mesh = msg.url(nil, object, "mesh")
		go.set(mesh, "vertices", buffers[piece.id])
		piece_look.applyLight(mesh)
		msg.post(mesh, "disable")
		view.pieces[piece.id] = {
			go = id, mesh = mesh, shown = false, goal = nil,
			velocity = vmath.vector3(), scale = 1, scale_velocity = 0,
			fx = vmath.vector4(), goal_fx = vmath.vector4(), shake = 0, hop = nil,
		}
	end
	walls_view.bind(view.walls, level)
end

-- Removes the pieces and hides the walls until the next bind.
function M.hide(view)
	clearPieces(view)
	showGhost(view, nil)
	walls_view.hide(view.walls)
end

-- A piece's goal and effects change only when its pose, lift or highlights do; any change
-- wakes a resting piece.
local function setGoal(p, pose, lifted, selected, invalid, hovered)
	if not state.samePose(p.pose, pose) then
		p.pose = pose
		p.goal = pose and { position = cellCenter(pose.cell), rotation = M.poseRotation(pose.orient) }
		p.rest = nil
	end
	local fx = p.goal_fx
	if p.lifted ~= lifted or fx.x ~= selected or fx.z ~= invalid or fx.w ~= hovered then
		p.lifted, fx.x, fx.z, fx.w = lifted, selected, invalid, hovered
		p.rest = nil
	end
end

-- display: { poses, invalid, dragging, evaluation, hint } from game/play (a new table whenever it
-- changes); selected, hovered: piece ids or nil. Does nothing when none of them changed.
function M.present(view, display, selected, hovered)
	if not memo.changed(view.presented, display, selected, hovered, view.colors) then
		return
	end
	for id, p in pairs(view.pieces) do
		setGoal(p, display.poses[id], id == display.dragging,
			id == selected and 1 or 0, id == display.invalid and 1 or 0, id == hovered and 1 or 0)
	end
	local hint, shown = display.hint, view.ghost.hint
	if (hint and hint.piece) ~= (shown and shown.piece) or not state.samePose(hint and hint.pose, shown and shown.pose) then
		showGhost(view, display.hint)
	end
	local focus = selected and { piece = selected, color = palette.pieceColor(view.level.pieces[selected], view.colors) }
	walls_view.present(view.walls, display, focus)
end

-- Applies display preferences: { colors, patterns, high_contrast, reduced_motion }.
function M.configure(view, prefs)
	view.calm = prefs.reduced_motion
	view.colors = prefs.colors
	local look = piece_look.update(view.look, view.pieces, view.level, prefs)
	if look ~= view.look then
		if view.ghost.hint then
			piece_look.apply(view.ghost.mesh, view.level, view.ghost.hint.piece, look)
		end
	end
	view.look = look
	walls_view.configure(view.walls, prefs)
end

-- A refused move: the piece shakes in place.
function M.shake(view, id)
	if view.pieces[id] and not view.calm then
		view.pieces[id].shake, view.pieces[id].rest = 1, nil
	end
end

-- The level is solved: pieces hop in a wave and the walls pulse.
function M.celebrate(view)
	for id, p in pairs(view.pieces) do
		p.hop, p.rest = not view.calm and -(id - 1) * HOP_STAGGER or nil, nil
	end
	walls_view.celebrate(view.walls)
end

local function hopHeight(p, dt)
	if not p.hop then
		return 0
	end
	p.hop = p.hop + dt
	if p.hop >= HOP_TIME then
		p.hop = nil
		return 0
	end
	return p.hop > 0 and HOP_HEIGHT * math.sin(math.pi * p.hop / HOP_TIME) or 0
end

local function quatDot(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w
end

-- A piece at rest keeps its transform until present gives it a new goal, or it shakes or hops.
local function settled(p, target, goal)
	return p.shake == 0 and not p.hop and not p.lifted
		and vmath.length_sqr(p.velocity) < REST and vmath.length_sqr(target - p.position) < REST
		and math.abs(p.scale - 1) < REST and math.abs(p.scale_velocity) < REST
		and 1 - math.abs(quatDot(p.rotation, goal.rotation)) < REST
end

local UP = vmath.vector3(0, 1, 0)
local NUDGE = vmath.vector3(1e-6, 0, 0)

local function stepPiece(view, p, dt, eye, xray)
	local goal = p.goal
	if not goal then
		if p.shown then
			msg.post(p.mesh, "disable")
			p.shown = false
		end
		return
	end
	if p.rest == goal then
		return
	end
	local target = goal.position + vmath.vector3(0, (p.lifted and LIFT or 0) + hopHeight(p, dt), 0)
	if not p.shown then
		msg.post(p.mesh, "enable")
		p.shown = true
		p.position, p.rotation, p.velocity = target, goal.rotation, vmath.vector3()
	end
	local zeta = view.calm and 1 or SPRING_ZETA
	p.position, p.velocity = motion.spring(p.position, p.velocity, target, dt, SPRING_OMEGA, zeta)
	p.rotation = vmath.slerp(motion.blend(TURN_RATE, dt), p.rotation, goal.rotation)
	p.scale, p.scale_velocity = motion.spring(p.scale, p.scale_velocity, p.lifted and LIFT_SCALE or 1, dt, SPRING_OMEGA, zeta)
	p.shake = math.max(0, p.shake - SHAKE_DECAY * dt)
	if p.shake > 0 then
		local right = vmath.normalize(vmath.cross(UP, eye) + NUDGE)
		go.set_position(p.position + right * (math.sin(view.time * 48) * SHAKE_AMPLITUDE * p.shake), p.go)
	else
		go.set_position(p.position, p.go)
	end
	go.set_rotation(p.rotation, p.go)
	go.set_scale(p.scale, p.go)

	local fx = motion.approach(p.fx, p.goal_fx, motion.blend(FX_RATE, dt))
	fx.y = xray
	local fx_moved = vmath.length(fx - p.fx) > 1e-4
	if fx_moved then
		p.fx = fx
		go.set(p.mesh, "fx", fx)
	end
	if not fx_moved and settled(p, target, goal) then
		go.set_position(target, p.go)
		go.set_rotation(goal.rotation, p.go)
		p.position, p.rotation, p.rest = target, goal.rotation, goal
	end
end

-- Advances all motion. eye: unit vector3 from the board toward the camera; xray in [0, 1]
-- (0 solid, 1 ghosts). A change of xray wakes resting pieces to take it up.
function M.step(view, dt, eye, xray)
	dt = math.min(dt, MAX_DT)
	view.time = view.time + dt
	if xray ~= view.xray then
		view.xray = xray
		for _, p in pairs(view.pieces) do
			p.rest = nil
		end
	end
	for _, p in pairs(view.pieces) do
		stepPiece(view, p, dt, eye, xray)
	end
	walls_view.step(view.walls, dt, eye)
end

-- Ends all motion at once: pieces stand at their goals and the walls settle, as seen from `eye`
-- with `xray` (see M.step), for a still picture.
function M.finish(view, eye, xray)
	view.xray = xray
	for _, p in pairs(view.pieces) do
		local goal = p.goal
		if goal then
			if not p.shown then
				msg.post(p.mesh, "enable")
				p.shown = true
			end
			p.position, p.rotation, p.velocity, p.scale, p.scale_velocity = goal.position, goal.rotation, vmath.vector3(), 1, 0
			p.shake, p.hop = 0, nil
			go.set_position(goal.position, p.go)
			go.set_rotation(goal.rotation, p.go)
			go.set_scale(1, p.go)
			p.fx = vmath.vector4(p.goal_fx)
			p.fx.y = xray
			go.set(p.mesh, "fx", p.fx)
			p.rest = goal
		end
	end
	walls_view.finish(view.walls, eye)
end

-- The bounding sphere of the board, walls on either side included, for camera framing.
function M.bounds(level)
	local s, gap = level.size, walls_view.WALL_GAP
	local lo = vmath.vector3(-gap, -walls_view.FLOOR_GAP, -gap)
	local hi = vmath.vector3(s[1] + gap, s[2], s[3] + gap)
	return (lo + hi) * 0.5, vmath.length(hi - lo) * 0.5
end

return hot(..., M)
