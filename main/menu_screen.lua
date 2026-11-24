-- The main menu: a slowly turning cube sculpture casting its projections, with the title and
-- the main menu sheet. Dragging spins the sculpture. Implements the screen contract in main.script.
local hot = require "core.hot"
local core_rules = require "core.rules"
local board_view = require "view.board_view"
local board_pool = require "view.board_pool"
local orbit = require "view.orbit"
local cameras = require "view.cameras"
local sheets = require "main.sheets"
local interpret = require "input.interpret"
local models = require "ui.models"
local panel_layout = require "ui.panel_layout"
local card_scene = require "view.card_scene"

local M = {}

local SPIN = math.rad(9)
local INSETS = { left = 0, right = 0, top = 0.17, bottom = 0.4 }
local SIDE_INSETS = { left = panel_layout.SIDE, right = 0.03, top = 0.12, bottom = 0.12 }
local ZOOM, SIDE_ZOOM = 0.78, 1.15

-- pool: the board pool (view/board_pool); rules: the rule cards (catalog.loadRules).
function M.enter(showcase, pool, rules)
	local slot = board_pool.acquire(pool, showcase)
	local screen = {
		module = M, level = showcase, sheets = { "main_menu" }, slot = slot,
		board = slot.board,
		rig = orbit.new(board_view.bounds(showcase)),
		interpreter = interpret.new(1),
		display = { poses = showcase.solution, evaluation = core_rules.evaluate(showcase, { poses = showcase.solution }) },
		rules = rules, card_scene = card_scene.new(pool),
	}
	screen.rig.goal.pitch = math.rad(-22)
	screen.rig.goal.zoom, screen.rig.current.zoom = ZOOM, ZOOM
	return screen
end

function M.exit(screen)
	card_scene.release(screen.card_scene)
	board_pool.release(screen.slot)
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
	if sheets.key(screen, g, intents, screen.info.settings.bindings) then
		return
	end
	if #screen.sheets > 1 then
		if g.kind == "tap" and sheets.outside(screen, g.x, g.y) then
			intents[#intents + 1] = { kind = "menu" }
		end
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
		screen.rebinding = nil
		sheets.close(screen)
	elseif kind == "sheet" or kind == "setting" or kind == "tab" or kind == "rebind" then
		return sheets.apply(screen, intent)
	end
end

function M.present(screen, dt, info)
	local w, h = info.w, info.h
	if not info.settings.reduced_motion then
		screen.rig.goal.yaw = screen.rig.goal.yaw + SPIN * dt
	end
	orbit.step(screen.rig, dt)
	local side = panel_layout.sideBySide(info)
	local insets = side and SIDE_INSETS or INSETS
	screen.rig.goal.zoom = side and SIDE_ZOOM or ZOOM
	local position, rotation, fov, near, far = orbit.lens(screen.rig, w / h, insets)
	cameras.set("board", position, rotation, fov, w / h, near, far)
	board_view.configure(screen.board, info.settings)
	board_view.present(screen.board, screen.display, nil, nil)
	board_view.step(screen.board, dt, orbit.eyeDirection(screen.rig), 0)
	local sheet = M.layout(screen, info)
	models.publish("panel", sheet)
	card_scene.present(screen.card_scene, sheets.cardLevel(screen), sheet and sheet.scene, dt, info.settings)
end

return hot(..., M)
