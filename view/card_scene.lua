-- The live scene on a rule card: the card's level, solved, on a board from the pool. It stands
-- far below the play board, beyond any other camera's reach, and its own camera ("card" in
-- view/cameras) draws it into the card's scene rectangle after the GUI.
local hot = require "core.hot"
local board_view = require "view.board_view"
local board_pool = require "view.board_pool"
local rules = require "core.rules"
local cameras = require "view.cameras"
local motion = require "view.motion"

local M = {}

local AWAY = vmath.vector3(0, -20000, 0)
local YAW, PITCH = math.rad(-38), math.rad(-26)
local SWAY, SWAY_RATE = math.rad(22), 0.45
local FOV = 0.5
local FILL = 1.3
-- Cubes are partly see-through so the walls, the subject of every card, stay readable.
local XRAY = 0.27
local GROW_RATE = 9

function M.new(pool)
	return { pool = pool, time = 0 }
end

function M.release(scene)
	if scene.slot then
		board_pool.release(scene.slot)
	end
	scene.slot, scene.level = nil, nil
	cameras.clear("card")
end

local function show(scene, level)
	scene.slot = board_pool.acquire(scene.pool, level)
	scene.level = level
	scene.center, scene.radius = board_view.bounds(level)
	scene.grow = 0.05
	local evaluation = rules.evaluate(level, { poses = level.solution })
	board_view.present(scene.slot.board, { poses = level.solution, evaluation = evaluation })
end

-- level: the card's scene, or nil to show none; rect: { x, y, w, h } (centre) in window pixels.
function M.present(scene, level, rect, dt, prefs)
	if level ~= scene.level then
		M.release(scene)
		if level then
			show(scene, level)
		end
	end
	if not scene.slot or not rect then
		cameras.clear("card")
		return
	end
	scene.time = scene.time + dt
	local calm = prefs.reduced_motion
	scene.grow = calm and 1 or motion.approach(scene.grow, 1, motion.blend(GROW_RATE, dt))
	local sway = calm and 0 or SWAY * math.sin(scene.time * SWAY_RATE)
	local rotation = vmath.quat_rotation_y(YAW + sway) * vmath.quat_rotation_x(PITCH)

	local anchor = scene.slot.anchor
	go.set_position(AWAY - scene.center * scene.grow, anchor)
	go.set_scale(scene.grow, anchor)

	local aspect = rect.w / rect.h
	local fit = math.min(FOV, 2 * math.atan(math.tan(FOV / 2) * aspect))
	local distance = scene.radius / math.sin(fit / 2) / FILL
	local eye = vmath.rotate(rotation, vmath.vector3(0, 0, 1))
	cameras.set("card", AWAY + eye * distance, rotation, FOV, aspect, math.max(0.05, distance - 3 * scene.radius), distance + 3 * scene.radius)
	cameras.setViewport("card", rect.x - rect.w / 2, rect.y - rect.h / 2, rect.w, rect.h)

	local board = scene.slot.board
	board_view.configure(board, prefs)
	board_view.step(board, dt, eye, XRAY)
end

return hot(..., M)
