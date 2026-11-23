-- Live 3D thumbnails: a small board per level, its anchor placing it at a screen position (see
-- cameras.setScreen). Boards are held from the pool (view/board_pool) only while on screen,
-- built a few per frame so a full page cascades in rather than stalling, then grow in and
-- sway gently.
local board_view = require "view.board_view"
local board_pool = require "view.board_pool"
local rules = require "core.rules"
local motion = require "view.motion"

local M = {}

local YAW, PITCH = math.rad(-38), math.rad(24)
local SWAY, SWAY_RATE = math.rad(14), 0.5
local GROW_RATE = 9
local FILL = 0.62
local BUILDS_PER_FRAME = 2

function M.new(pool)
	return { pool = pool, live = {}, time = 0 }
end

local function build(thumbs, spec)
	local level = spec.level
	local slot = board_pool.acquire(thumbs.pool, level)
	local center, radius = board_view.bounds(level)
	board_view.present(slot.board, { poses = spec.poses, evaluation = rules.evaluate(level, { poses = spec.poses }) })
	return { slot = slot, center = center, radius = radius, grow = 0.05, phase = spec.number * 1.7 }
end

local function place(thumbs, t, spec, dt, eye_from, prefs)
	local calm = prefs.reduced_motion
	t.grow = calm and 1 or motion.approach(t.grow, 1, motion.blend(GROW_RATE, dt))
	local sway = calm and 0 or SWAY * math.sin(thumbs.time * SWAY_RATE + t.phase)
	local rotation = vmath.quat_rotation_x(PITCH) * vmath.quat_rotation_y(YAW + sway)
	local scale = spec.size * FILL / t.radius * t.grow
	local at = vmath.vector3(spec.x, spec.y, 0)
	local anchor = t.slot.anchor
	go.set_position(at - vmath.rotate(rotation, t.center * scale), anchor)
	go.set_rotation(rotation, anchor)
	go.set_scale(scale, anchor)
	local board = t.slot.board
	board_view.configure(board, prefs)
	board_view.step(board, dt, vmath.rotate(vmath.conj(rotation), vmath.normalize(eye_from - at)), 0)
end

local function releaseUnless(thumbs, keep)
	for id, t in pairs(thumbs.live) do
		if not keep[id] then
			board_pool.release(t.slot)
			thumbs.live[id] = nil
		end
	end
end

-- specs: { { id, level, poses, number, x, y, size } } for the thumbnails to show this frame,
-- in the order to build them; others are released. eye_from: the camera position from
-- cameras.setScreen.
function M.present(thumbs, specs, dt, eye_from, prefs)
	thumbs.time = thumbs.time + dt
	local seen, builds = {}, BUILDS_PER_FRAME
	for _, spec in ipairs(specs) do
		seen[spec.id] = true
		local t = thumbs.live[spec.id]
		if not t and builds > 0 then
			t, builds = build(thumbs, spec), builds - 1
			thumbs.live[spec.id] = t
		end
		if t then
			place(thumbs, t, spec, dt, eye_from, prefs)
		end
	end
	releaseUnless(thumbs, seen)
end

function M.release(thumbs)
	releaseUnless(thumbs, {})
end

return M
