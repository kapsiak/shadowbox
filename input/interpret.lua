-- Turns gestures into intents. Pure: what lies under the pointer is answered by the
-- `pick(x, y)` function the caller supplies, returning { piece, cell, from_tray } or nil.
--
-- Intents:
--   orbit { yaw, pitch }          angles in radians
--   orbit_rate { yaw, pitch }     signed rates, scaled by time by the receiver
--   zoom { factor }               multiplicative, < 1 zooms in
--   view { name }                 snap to a named camera view
--   tap { piece }                 piece id or nil (empty space)
--   hover { piece }               piece under a pointer moving with no button held
--   grab { piece, cell, from_tray }, drag { x, y }, drop { x, y, cancelled }
--   turn { about, dir }           about = "vertical" | "right" | "toward" (camera-relative);
--                                 while dragging, a second finger's swipe turns a step per
--                                 `swipe_step` pixels: sideways about vertical, up or down tips
--   nudge { along, delta }        along = "vertical" | "drag" (the drag plane's axis)
--   peek { on }                   while held, pieces fade so the walls show
--   undo, redo, remove, menu, next, rules
-- Intents are shared and must not be changed by their receivers.
local hot = require "core.hot"
local controls = require "input.controls"
local M = {}

local ORBIT_PER_SCREEN = math.pi
local WHEEL_STEP = 0.9

-- What each action (input/controls) stands for, whether from its keys or its HUD button. A
-- `held` action acts while held: { kind, on = true } on press and on = false on release.
local action_intents = {
	turn_left = { kind = "turn", about = "vertical", dir = -1 },
	turn_right = { kind = "turn", about = "vertical", dir = 1 },
	tip_away = { kind = "turn", about = "right", dir = -1 },
	tip_toward = { kind = "turn", about = "right", dir = 1 },
	roll_left = { kind = "turn", about = "toward", dir = 1 },
	roll_right = { kind = "turn", about = "toward", dir = -1 },
	lift = { kind = "nudge", along = "vertical", delta = 1 },
	lower = { kind = "nudge", along = "vertical", delta = -1 },
	remove = { kind = "remove" },
	view_front = { kind = "view", name = "front" },
	view_side = { kind = "view", name = "side" },
	view_top = { kind = "view", name = "top" },
	view_iso = { kind = "view", name = "iso" },
	zoom_in = { kind = "zoom", factor = WHEEL_STEP },
	zoom_out = { kind = "zoom", factor = 1 / WHEEL_STEP },
	peek = { kind = "peek", held = true },
	undo = { kind = "undo" },
	redo = { kind = "redo" },
	rules = { kind = "rules" },
	confirm = { kind = "next" },
	menu = { kind = "menu" },
}
-- Orbit keys turn the camera at a rate for as long as they are held, repeats included.
local key_orbits = {
	orbit_left = { kind = "orbit_rate", yaw = -1, pitch = 0 },
	orbit_right = { kind = "orbit_rate", yaw = 1, pitch = 0 },
	orbit_up = { kind = "orbit_rate", yaw = 0, pitch = -1 },
	orbit_down = { kind = "orbit_rate", yaw = 0, pitch = 1 },
}
local HOLD = { press = true, release = false }

-- Emits an action's intent for a press or release ("press" | "release"; other phases do nothing).
local function act(id, phase, out)
	local intent = action_intents[id]
	if not intent or HOLD[phase] == nil then
		return
	elseif intent.held then
		out[#out + 1] = { kind = intent.kind, on = HOLD[phase] }
	elseif phase == "press" then
		out[#out + 1] = intent
	end
end

-- screen_height normalizes drag distances so sensitivity is resolution independent.
-- sensitivity scales camera drags; invert flips their direction. A touch drag aims `lift`
-- pixels above the finger, so the piece stays in sight.
function M.new(screen_height)
	return { screen_height = screen_height, drag = nil, sensitivity = 1, invert = false, lift = 0, swipe_step = 1 }
end

local function onKey(g, out)
	if key_orbits[g.name] then
		if not g.released then
			out[#out + 1] = key_orbits[g.name]
		end
	else
		act(g.name, g.pressed and "press" or g.released and "release", out)
	end
end

-- The window lost focus: releases never arrive, so every held action lets go.
local function onBlur(out)
	for _, intent in pairs(action_intents) do
		if intent.held then
			out[#out + 1] = { kind = intent.kind, on = false }
		end
	end
end

local function onDragStart(state, g, pick, out)
	local hit = g.button == "primary" and pick(g.x, g.y)
	if hit then
		state.drag = "piece"
		state.raise = g.touch and state.lift or 0
		out[#out + 1] = { kind = "grab", piece = hit.piece, cell = hit.cell, from_tray = hit.from_tray, x = g.x, y = g.y }
	else
		state.drag = "orbit"
	end
end

-- A HUD button (ui/hud_layout ids) pressed or released; phase as in router control events.
function M.button(id, phase, out)
	local action = controls.forButton(id)
	if action then
		act(action.id, phase, out)
	end
end

local function onTap(state, g, pick, out)
	if g.button == "primary" then
		local hit = pick(g.x, g.y)
		out[#out + 1] = { kind = "tap", piece = hit and hit.piece }
	elseif state.drag == "piece" then
		out[#out + 1] = { kind = "turn", about = "vertical", dir = 1 }
	end
end

local function onDragMove(state, g, out)
	if state.drag == "piece" and g.button == "primary" then
		out[#out + 1] = { kind = "drag", x = g.x, y = g.y + state.raise }
	elseif state.drag == "orbit" and not g.multi then
		local scale = ORBIT_PER_SCREEN / state.screen_height * state.sensitivity * (state.invert and -1 or 1)
		out[#out + 1] = { kind = "orbit", yaw = -g.dx * scale, pitch = g.dy * scale }
	end
end

-- A second finger's swipe while dragging turns the piece a step per `swipe_step` of travel along
-- the swipe's first direction: sideways turns about vertical, up or down tips. Swiping back undoes.
local function swipeTurns(state, g, out)
	local s = state.swipe or { x = 0, y = 0, done = 0 }
	state.swipe = s
	s.x, s.y = s.x + g.dx, s.y + g.dy
	if not s.axis then
		if math.max(math.abs(s.x), math.abs(s.y)) < state.swipe_step then
			return
		end
		s.axis = math.abs(s.x) >= math.abs(s.y) and "x" or "y"
	end
	local travel = s[s.axis]
	local steps = (travel < 0 and -1 or 1) * math.floor(math.abs(travel) / state.swipe_step)
	while s.done ~= steps do
		local dir = steps > s.done and 1 or -1
		s.done = s.done + dir
		if s.axis == "x" then
			out[#out + 1] = { kind = "turn", about = "vertical", dir = dir }
		else
			out[#out + 1] = { kind = "turn", about = "right", dir = -dir }
		end
	end
end

function M.gesture(state, g, pick, out)
	local dragging_piece = state.drag == "piece"
	if g.kind == "tap" then
		onTap(state, g, pick, out)
	elseif g.kind == "drag_start" and not state.drag then
		onDragStart(state, g, pick, out)
	elseif g.kind == "drag_move" then
		onDragMove(state, g, out)
	elseif g.kind == "drag_end" and (g.button == "primary" or state.drag == "orbit") then
		if dragging_piece then
			out[#out + 1] = { kind = "drop", x = g.x, y = g.y + state.raise }
		end
		state.drag = nil
	elseif g.kind == "second_move" and dragging_piece then
		swipeTurns(state, g, out)
	elseif g.kind == "second_up" then
		state.swipe = nil
	elseif g.kind == "two_finger" and not dragging_piece then
		out[#out + 1] = { kind = "zoom", factor = 1 / g.scale }
		out[#out + 1] = { kind = "orbit", yaw = -g.twist, pitch = 0 }
	elseif g.kind == "wheel" and dragging_piece then
		if g.start then
			out[#out + 1] = { kind = "nudge", along = "drag", delta = g.amount }
		end
	elseif g.kind == "wheel" then
		out[#out + 1] = { kind = "zoom", factor = WHEEL_STEP ^ g.amount }
	elseif g.kind == "key" then
		onKey(g, out)
	elseif g.kind == "blur" then
		onBlur(out)
	elseif g.kind == "hover" and not state.drag then
		local hit = pick(g.x, g.y)
		out[#out + 1] = { kind = "hover", piece = hit and hit.piece }
	end
end

return hot(..., M)
