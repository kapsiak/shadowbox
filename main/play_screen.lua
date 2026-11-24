-- The play screen: one level, its views, the HUD, and the input that drives them.
-- Implements the screen contract used by main.script (see there).
local hot = require "core.hot"
local play = require "game.play"
local interpret = require "input.interpret"
local board_view = require "view.board_view"
local tray_view = require "view.tray_view"
local board_pool = require "view.board_pool"
local orbit = require "view.orbit"
local pick = require "view.pick"
local cameras = require "view.cameras"
local hud_layout = require "ui.hud_layout"
local hit = require "ui.hit"
local models = require "ui.models"
local sheets = require "main.sheets"
local audio = require "view.audio"
local card_scene = require "view.card_scene"
local lessons = require "game.lessons"
local controls = require "input.controls"
local motion = require "view.motion"
local memo = require "core.memo"

local M = {}

local TRAY_BACKDROP = "/tray_backdrop#mesh"
-- A button's tooltip shows once the pointer has rested on it this long (desktop only: touch
-- does not hover), until it leaves or presses.
local TIP_DELAY = 0.45

local PEEK_RATE = 14

local LIFT_DP = 70
local SWIPE_DP = 50

-- The button whose tooltip shows, or nil.
local function shownTip(tip)
	return tip and not tip.pressed and tip.t >= TIP_DELAY and tip.id or nil
end

-- The tooltip for button `id`: its action and first key.
local function tipFor(id, bindings)
	local action = id and controls.forButton(id)
	if not action then
		return nil
	end
	local keys = controls.keysOf(controls.changed(bindings), action.id)
	return { id = id, text = keys[1] and action.label .. "   " .. controls.keyLabel(keys[1]) or action.label }
end

local function toTable(v)
	return { v.x, v.y, v.z }
end

-- pool: the board pool (view/board_pool); factories: { tray_piece, glass_tray_piece } urls;
-- saved: the board as last left, or nil; session: this level's session from earlier in this
-- run, kept for its undo history, or nil; rules: the rule cards (catalog.loadRules); seen: the
-- card ids already seen. Cards the level uses and the player has not seen open first.
function M.enter(pack, index, pool, factories, saved, session, rules, seen)
	local lvl = pack.levels[index]
	local slot = board_pool.acquire(pool, lvl)
	local screen = {
		module = M, pack = pack, index = index, key = pack.keys[index],
		session = session and play.resume(session) or play.new(lvl, saved), solved = false, hovered = nil, pointer = nil, sheets = {},
		interpreter = interpret.new(1),
		slot = slot,
		board = slot.board,
		tray = tray_view.create(lvl, factories, slot.buffers),
		rig = orbit.new(board_view.bounds(lvl)),
		rules = rules, card_scene = card_scene.new(pool),
		peek = false, peek_amount = 0, hud_inputs = {}, ui = {},
		subtitle = ("%s  ·  %d / %d"):format(pack.title, index, #pack.levels),
	}
	local unseen = lessons.unseen(seen, lvl)
	if #unseen > 0 then
		sheets.showCards(screen, unseen)
	end
	return screen
end

function M.exit(screen)
	card_scene.release(screen.card_scene)
	board_pool.release(screen.slot)
	tray_view.destroy(screen.tray)
	go.set(TRAY_BACKDROP, "rect", vmath.vector4())
	cameras.clear("tray")
	models.publish("hud", nil)
	models.publish("panel", nil)
end

-- The board as it stands, for saving.
function M.board(screen)
	return play.current(screen.session).poses
end

-- The HUD is laid out again only when something it depends on changes.
function M.layout(screen, info)
	local s, safe, prefs = screen.session, info.safe, info.settings
	screen.info = info
	local piece_controls, can_undo, can_redo = s.selected ~= nil and not screen.solved, play.canUndo(s), play.canRedo(s)
	local tip = #screen.sheets == 0 and shownTip(screen.tip) or nil
	if memo.changed(screen.hud_inputs, info.w, info.h, info.scale, safe.left, safe.right, safe.top, safe.bottom,
		prefs.left_handed, prefs.bindings, piece_controls, can_undo, can_redo, screen.solved, screen.peek, tip) then
		screen.hud = hud_layout.compute(info, {
			piece_controls = piece_controls, can_undo = can_undo, can_redo = can_redo,
			title = s.level.name, subtitle = screen.subtitle, solved = screen.solved,
			left_handed = prefs.left_handed, peek = screen.peek, tip = tipFor(tip, prefs.bindings),
		})
	end
	return screen.hud
end

function M.hit(screen, x, y)
	if #screen.sheets > 0 then
		return sheets.hit(screen, x, y)
	end
	return hit.find(screen.hud.buttons, x, y)
end

-- HUD buttons act on press (held ones also on release); while a sheet is open, controls
-- belong to the sheet.
function M.button(screen, ev, intents)
	if #screen.sheets > 0 then
		if ev.phase == "press" then
			models.pressed("panel", ev.id)
		end
		sheets.control(screen, ev, intents)
	elseif ev.phase == "press" then
		if screen.tip then
			screen.tip.pressed = true
		end
		models.pressed("hud", ev.id)
		interpret.button(ev.id, "press", intents)
	elseif ev.phase == "release" then
		interpret.button(ev.id, "release", intents)
	end
end

local function pickAt(screen, x, y)
	local tray_piece = tray_view.pick(screen.tray, x, y)
	if tray_piece then
		return { piece = tray_piece, from_tray = true }
	end
	if tray_view.contains(screen.tray, y) then
		return nil
	end
	local origin, dir = cameras.ray("board", x, y, screen.info.w, screen.info.h)
	local piece, cell = pick.piece(screen.session.level, play.current(screen.session), origin, dir)
	return piece and { piece = piece, cell = cell }
end

function M.gesture(screen, g, intents)
	if #screen.sheets > 0 then
		if sheets.key(screen, g, intents, screen.info.settings.bindings) then
			return
		end
		local escape = g.kind == "key" and g.pressed and g.name == "menu"
		if escape or (g.kind == "tap" and sheets.outside(screen, g.x, g.y)) then
			intents[#intents + 1] = { kind = "sheet", id = sheets.top(screen) == "rule" and "rule_next" or "resume" }
		end
		return
	end
	if g.kind == "hover" then
		local id = hit.find(screen.hud.buttons, g.x, g.y)
		if id ~= (screen.tip and screen.tip.id) then
			screen.tip = id and { id = id, t = 0 } or nil
		end
	end
	local prefs = screen.info.settings
	screen.interpreter.screen_height = screen.info.h
	screen.interpreter.sensitivity = prefs.sensitivity
	screen.interpreter.invert = prefs.invert
	screen.interpreter.lift = LIFT_DP * screen.info.scale
	screen.interpreter.swipe_step = SWIPE_DP * screen.info.scale
	interpret.gesture(screen.interpreter, g, function(x, y)
		return pickAt(screen, x, y)
	end, intents)
end

-- Resolves a camera-relative direction name to a world axis and the sign it points along.
local function cameraAxis(screen, about)
	if about == "vertical" then
		return 2, 1
	end
	local v = about == "right" and vmath.rotate(orbit.rotation(screen.rig), vmath.vector3(1, 0, 0))
		or orbit.eyeDirection(screen.rig)
	if about == "toward" then
		v.y = 0
	end
	return play.dominantAxis(toTable(v))
end

-- Refused moves shake the piece they were aimed at; accepted ones play `cue`.
local function respond(screen, done, cue)
	if done then
		audio.cue(cue)
	elseif screen.session.selected then
		board_view.shake(screen.board, screen.session.selected)
		audio.cue("refuse")
	end
end

local function applyCamera(screen, intent, dt)
	local kind = intent.kind
	if kind == "orbit" then
		orbit.orbitBy(screen.rig, intent.yaw, intent.pitch)
	elseif kind == "orbit_rate" then
		orbit.orbitAt(screen.rig, intent.yaw, intent.pitch, dt)
	elseif kind == "zoom" then
		orbit.zoomBy(screen.rig, intent.factor)
	elseif kind == "view" then
		orbit.snapTo(screen.rig, intent.name)
	else
		return false
	end
	return true
end

-- Applies one intent; returns a request for the app (see main.script) or nil.
function M.apply(screen, intent, dt)
	local s, kind = screen.session, intent.kind
	if kind == "sheet" and intent.id == "restart" then
		if play.hasProgress(s) then
			sheets.open(screen, "confirm_restart")
		else
			sheets.close(screen)
		end
		return nil
	elseif kind == "sheet" and intent.id == "confirm_restart" then
		screen.session = play.new(s.level)
		screen.solved = false
		screen.sheets = {}
		return nil
	elseif kind == "sheet" or kind == "setting" or kind == "tab" or kind == "rebind" then
		return sheets.apply(screen, intent)
	elseif applyCamera(screen, intent, dt) then
		return nil
	elseif kind == "peek" then
		screen.peek = intent.on
		return nil
	elseif kind == "rules" then
		sheets.open(screen, "rules")
		screen.session.drag = nil
		return nil
	elseif kind == "menu" then
		sheets.open(screen, "pause")
		screen.session.drag = nil
		return nil
	elseif kind == "next" then
		return screen.solved and { to = "next" } or nil
	elseif screen.solved and kind ~= "hover" and kind ~= "undo" then
		return nil
	elseif kind == "hover" then
		screen.hovered = intent.piece
	elseif kind == "tap" then
		if play.tap(s, intent.piece) then
			audio.cue("turn")
		end
	elseif kind == "grab" then
		audio.cue("pick")
		screen.hovered = nil
		screen.pointer = { x = intent.x, y = intent.y }
		play.grab(s, intent.piece, intent.cell)
	elseif kind == "drag" then
		screen.pointer = { x = intent.x, y = intent.y }
		play.dragTo(s, cameras.ray("board", intent.x, intent.y, screen.info.w, screen.info.h))
	elseif kind == "drop" then
		screen.pointer = nil
		local refused = play.display(s).invalid ~= nil
		local placed = play.drop(s, tray_view.contains(screen.tray, intent.y))
		if refused then
			respond(screen, false)
		elseif placed then
			audio.cue("place")
		end
	elseif kind == "turn" then
		local axis, sign = cameraAxis(screen, intent.about)
		respond(screen, play.turn(s, axis, intent.dir * sign), "turn")
	elseif kind == "nudge" then
		local axis = intent.along == "drag" and s.drag and s.drag.axis or 2
		respond(screen, play.nudge(s, axis, intent.delta), "turn")
	elseif kind == "undo" or kind == "redo" then
		play[kind](s)
		audio.cue("turn", { pitch = 0.8 })
	elseif kind == "remove" then
		if play.removeSelected(s) then
			audio.cue("pick", { pitch = 0.8 })
		end
	end
end

-- A wall chimes as it becomes matched, though not for walls already matched on arrival.
local function cueWalls(screen, evaluation)
	local arriving = screen.matched == nil
	screen.matched = screen.matched or {}
	for name, view in pairs(evaluation.views) do
		if view.matches and not screen.matched[name] and not arriving then
			audio.cue("wall")
		end
		screen.matched[name] = view.matches
	end
end

function M.present(screen, dt, info)
	local w, h = info.w, info.h
	local s = screen.session
	local display = play.display(s)
	cueWalls(screen, display.evaluation)
	if screen.tip then
		screen.tip.t = screen.tip.t + dt
	end

	if display.evaluation.solved ~= screen.solved and not s.drag then
		screen.solved = display.evaluation.solved
		if screen.solved then
			s.selected = nil
			board_view.celebrate(screen.board)
			audio.cue("solve")
		end
	end

	if #screen.sheets > 0 then
		screen.peek = false
	end
	screen.peek_amount = motion.ease(screen.peek_amount, screen.peek and 1 or 0, motion.blend(PEEK_RATE, dt))

	local layout = M.layout(screen, info)
	if orbit.step(screen.rig, dt) or not screen.eye or layout.insets ~= screen.lens_insets or w / h ~= screen.lens_aspect then
		screen.lens_insets, screen.lens_aspect = layout.insets, w / h
		local position, rotation, fov, near, far = orbit.lens(screen.rig, w / h, layout.insets)
		cameras.set("board", position, rotation, fov, w / h, near, far)
		screen.rotation, screen.eye = rotation, orbit.eyeDirection(screen.rig)
	end

	board_view.configure(screen.board, info.settings)
	tray_view.configure(screen.tray, info.settings)
	board_view.present(screen.board, display, s.selected, screen.hovered)
	board_view.step(screen.board, dt, screen.eye, math.max(orbit.xray(screen.rig), screen.peek_amount))
	local ui = screen.ui
	ui.selected, ui.hovered, ui.pointer, ui.held = s.selected, screen.hovered, screen.pointer, s.held
	tray_view.present(screen.tray, display, ui, w, h, hud_layout.TRAY_INSET, screen.rotation)
	tray_view.step(screen.tray, dt)

	if layout ~= screen.backdrop_layout then
		screen.backdrop_layout = layout
		local t = layout.tray
		go.set(TRAY_BACKDROP, "rect", vmath.vector4(t.x, t.y, t.w, t.h))
		go.set(TRAY_BACKDROP, "screen", vmath.vector4(w, h, 0, 0))
	end
	models.publish("hud", layout)
	local sheet = sheets.layout(screen, info)
	models.publish("panel", sheet)
	card_scene.present(screen.card_scene, sheets.cardLevel(screen), sheet and sheet.scene, dt, info.settings)
end

return hot(..., M)
