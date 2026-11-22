-- Live 3D thumbnails: a small board per level, each under an anchor object that places it at a
-- screen position (see cameras.setScreen). Boards exist only while on screen, grow in when they
-- appear, and sway gently. Owns the game objects and resources it creates.
local board_view = require "view.board_view"
local piece_meshes = require "view.piece_meshes"
local rules = require "core.rules"
local motion = require "view.motion"

local M = {}

local YAW, PITCH = math.rad(-38), math.rad(24)
local SWAY, SWAY_RATE = math.rad(14), 0.5
local GROW_RATE = 9
local FILL = 0.62

-- factories: { piece, glass_piece, panel, anchor } urls.
function M.new(factories)
	return { factories = factories, live = {}, time = 0 }
end

local function create(thumbs, spec)
	local level = spec.level
	local anchor = factory.create(thumbs.factories.anchor)
	local buffers = piece_meshes.create(level)
	local board = board_view.create(level, thumbs.factories, buffers)
	board_view.attach(board, anchor)
	local center, radius = board_view.bounds(level)
	board_view.present(board, { poses = spec.poses, evaluation = rules.evaluate(level, { poses = spec.poses }) })
	return {
		anchor = anchor, buffers = buffers, board = board, center = center, radius = radius,
		grow = 0.05, phase = spec.number * 1.7,
	}
end

local function release(t)
	board_view.destroy(t.board)
	piece_meshes.release(t.buffers)
	go.delete(t.anchor)
end

-- specs: { { id, level, poses, number, x, y, size } } for the thumbnails to show this frame;
-- others are released. eye_from: the camera position from cameras.setScreen.
function M.present(thumbs, specs, dt, eye_from, prefs)
	thumbs.time = thumbs.time + dt
	local seen = {}
	for _, spec in ipairs(specs) do
		seen[spec.id] = true
		local t = thumbs.live[spec.id]
		if not t then
			t = create(thumbs, spec)
			thumbs.live[spec.id] = t
		end
		board_view.configure(t.board, prefs)
		t.grow = prefs.reduced_motion and 1 or motion.approach(t.grow, 1, motion.blend(GROW_RATE, dt))
		local sway = prefs.reduced_motion and 0 or SWAY * math.sin(thumbs.time * SWAY_RATE + t.phase)
		local rotation = vmath.quat_rotation_x(PITCH) * vmath.quat_rotation_y(YAW + sway)
		local scale = spec.size * FILL / t.radius * t.grow
		local at = vmath.vector3(spec.x, spec.y, 0)
		go.set_position(at - vmath.rotate(rotation, t.center * scale), t.anchor)
		go.set_rotation(rotation, t.anchor)
		go.set_scale(scale, t.anchor)
		local eye = vmath.rotate(vmath.conj(rotation), vmath.normalize(eye_from - at))
		board_view.step(t.board, dt, eye, 0)
	end
	for id, t in pairs(thumbs.live) do
		if not seen[id] then
			release(t)
			thumbs.live[id] = nil
		end
	end
end

function M.destroy(thumbs)
	for id, t in pairs(thumbs.live) do
		release(t)
		thumbs.live[id] = nil
	end
end

return M
