-- The main menu: a slowly turning cube sculpture casting its projections, with the title and
-- the main menu sheet. Dragging spins the sculpture. Implements the screen contract in main.script.
local rules = require "core.rules"
local board_view = require "view.board_view"
local piece_meshes = require "view.piece_meshes"
local orbit = require "view.orbit"
local cameras = require "view.cameras"
local sheets = require "main.sheets"
local interpret = require "input.interpret"
local models = require "ui.models"

local M = {}

local SPIN = math.rad(9)
local INSETS = { left = 0, right = 0, top = 0.17, bottom = 0.4 }

function M.enter(showcase, factories)
	local buffers = piece_meshes.create(showcase)
	local state = { poses = showcase.solution }
	local screen = {
		module = M, level = showcase, sheets = { "main_menu" }, buffers = buffers,
		board = board_view.create(showcase, factories, buffers),
		rig = orbit.new(board_view.bounds(showcase)),
		interpreter = interpret.new(1),
		display = { poses = showcase.solution, evaluation = rules.evaluate(showcase, state) },
	}
	screen.rig.goal.pitch = math.rad(-22)
	screen.rig.goal.zoom, screen.rig.current.zoom = 0.78, 0.78
	return screen
end

function M.exit(screen)
	board_view.destroy(screen.board)
	piece_meshes.release(screen.buffers)
	models.publish("panel", nil)
end

function M.layout(screen, info)
	screen.info = info
	return sheets.layout(screen, info)
end

function M.hit(screen, x, y)
	return sheets.hit(screen, x, y)
end

function M.button(screen, ev, intents)
	if ev.phase == "press" then
		models.pressed("panel", ev.id)
	end
	sheets.control(screen, ev, intents)
end

function M.gesture(screen, g, intents)
	if #screen.sheets > 1 then
		return
	end
	screen.interpreter.screen_height = screen.info.h
	interpret.gesture(screen.interpreter, g, function() return nil end, intents)
end

function M.apply(screen, intent)
	local kind = intent.kind
	if kind == "orbit" then
		orbit.orbitBy(screen.rig, intent.yaw, 0)
	elseif kind == "menu" and #screen.sheets > 1 then
		sheets.close(screen)
	elseif kind == "sheet" or kind == "setting" or kind == "tab" then
		return sheets.apply(screen, intent)
	end
end

function M.present(screen, dt, info)
	local w, h = info.w, info.h
	if not info.settings.reduced_motion then
		screen.rig.goal.yaw = screen.rig.goal.yaw + SPIN * dt
	end
	orbit.step(screen.rig, dt)
	local position, rotation, fov, near, far = orbit.lens(screen.rig, w / h, INSETS)
	cameras.set("board", position, rotation, fov, w / h, near, far)
	board_view.configure(screen.board, info.settings)
	board_view.present(screen.board, screen.display, nil, nil)
	board_view.step(screen.board, dt, orbit.eyeDirection(screen.rig), 0)
	models.publish("panel", M.layout(screen, info))
end

return M
