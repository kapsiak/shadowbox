-- Presents the board: pieces at their displayed poses, and the projection walls (view/walls_view).
-- Pieces move on springs, lift while dragged, shake when a move is refused, and hop when the
-- level is solved. Owns the game objects and resources it creates; never touches game state.
local orient = require "core.orient"
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

local function poseRotation(n)
	local x, y, z = orient.apply(n, { 1, 0, 0 }), orient.apply(n, { 0, 1, 0 }), orient.apply(n, { 0, 0, 1 })
	return vmath.quat_basis(vmath.vector3(x[1], x[2], x[3]), vmath.vector3(y[1], y[2], y[3]), vmath.vector3(z[1], z[2], z[3]))
end

local function cellCenter(c)
	return vmath.vector3(c[1] + 0.5, c[2] + 0.5, c[3] + 0.5)
end

-- factories: { piece, glass_piece, panel } urls; buffers: piece mesh buffers (view/piece_meshes).
function M.create(level, factories, buffers)
	local view = { level = level, pieces = {}, time = 0, walls = walls_view.create(level, factories.panel) }
	for _, piece in ipairs(level.pieces) do
		local id = factory.create(palette.isGlass(piece) and factories.glass_piece or factories.piece)
		local mesh = msg.url(nil, id, "mesh")
		go.set(mesh, "vertices", buffers[piece.id])
		piece_look.applyLight(mesh)
		msg.post(mesh, "disable")
		view.pieces[piece.id] = {
			go = id, mesh = mesh, shown = false, goal = nil,
			velocity = vmath.vector3(), scale = 1, scale_velocity = 0,
			fx = vmath.vector4(), goal_fx = vmath.vector4(), shake = 0, hop = nil,
		}
	end
	return view
end

-- display: { poses, invalid, dragging, evaluation } from game/play; selected, hovered: piece ids or nil.
function M.present(view, display, selected, hovered)
	for id, p in pairs(view.pieces) do
		local pose = display.poses[id]
		p.goal = pose and { position = cellCenter(pose.cell), rotation = poseRotation(pose.orient) }
		p.lifted = id == display.dragging
		p.goal_fx = vmath.vector4(id == selected and 1 or 0, 0, id == display.invalid and 1 or 0, id == hovered and 1 or 0)
	end
	local focus = selected and { piece = selected, color = palette.pieceColor(view.level.pieces[selected], view.colors) }
	walls_view.present(view.walls, display, focus)
end

-- Applies display preferences: { colors, patterns, high_contrast, reduced_motion }.
function M.configure(view, prefs)
	view.calm = prefs.reduced_motion
	view.colors = prefs.colors
	local key = piece_look.key(prefs)
	if view.look ~= key then
		view.look = key
		for id, p in pairs(view.pieces) do
			piece_look.apply(p.mesh, view.level, id, prefs)
		end
	end
	walls_view.configure(view.walls, prefs)
end

-- Moves the board under `parent`, a game object whose transform places it in the world.
function M.attach(view, parent)
	for _, p in pairs(view.pieces) do
		go.set_parent(p.go, parent)
	end
	walls_view.attach(view.walls, parent)
end

-- A refused move: the piece shakes in place.
function M.shake(view, id)
	if view.pieces[id] and not view.calm then
		view.pieces[id].shake = 1
	end
end

-- The level is solved: pieces hop in a wave and the walls pulse.
function M.celebrate(view)
	for id, p in pairs(view.pieces) do
		p.hop = not view.calm and -(id - 1) * HOP_STAGGER or nil
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

local function stepPiece(view, p, dt, right, xray)
	local goal = p.goal
	if not goal then
		if p.shown then
			msg.post(p.mesh, "disable")
			p.shown = false
		end
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
	local shake = right * (math.sin(view.time * 48) * SHAKE_AMPLITUDE * p.shake)

	go.set_position(p.position + shake, p.go)
	go.set_rotation(p.rotation, p.go)
	go.set_scale(p.scale, p.go)

	local fx = motion.approach(p.fx, p.goal_fx, motion.blend(FX_RATE, dt))
	fx.y = xray
	if vmath.length(fx - p.fx) > 1e-4 then
		p.fx = fx
		go.set(p.mesh, "fx", fx)
	end
end

-- Advances all motion. eye: unit vector3 from the board toward the camera; xray in [0, 1].
function M.step(view, dt, eye, xray)
	dt = math.min(dt, MAX_DT)
	view.time = view.time + dt
	local right = vmath.normalize(vmath.cross(vmath.vector3(0, 1, 0), eye) + vmath.vector3(1e-6, 0, 0))
	for _, p in pairs(view.pieces) do
		stepPiece(view, p, dt, right, xray)
	end
	walls_view.step(view.walls, dt, eye)
end

function M.destroy(view)
	for _, p in pairs(view.pieces) do
		go.delete(p.go)
	end
	walls_view.destroy(view.walls)
end

-- The bounding sphere of the board, walls on either side included, for camera framing.
function M.bounds(level)
	local s, gap = level.size, walls_view.WALL_GAP
	local lo = vmath.vector3(-gap, -walls_view.FLOOR_GAP, -gap)
	local hi = vmath.vector3(s[1] + gap, s[2], s[3] + gap)
	return (lo + hi) * 0.5, vmath.length(hi - lo) * 0.5
end

return M
