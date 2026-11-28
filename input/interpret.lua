-- Turns gestures into intents. Pure: what lies under the pointer is answered by the
-- `pick(x, y)` function the caller supplies, returning { piece, cell, from_tray } or nil.
--
-- Intents:
--   orbit { yaw, pitch }          angles in radians
--   orbit_rate { yaw, pitch }     signed rates, scaled by time by the receiver
--   coast, halt                   an orbiting hand let go (the camera runs on) / a pointer went
--                                 down (the camera stops)
--   zoom { factor }               multiplicative, < 1 zooms in
--   view { name }                 snap to a named camera view
--   tap { piece }                 piece id or nil (empty space)
--   hover { piece }               piece under a pointer moving with no button held
--   grab { piece, cell, from_tray }, drag { x, y }, drop { x, y } or drop { cancelled = true }
--                                 (the piece goes back as it was)
--   turn { about, dir }           about = "vertical" | "right" | "toward" (camera-relative)
--   spin { about, angle }         turn a dragged piece by `angle` radians about = "vertical" |
--                                 "right" (camera-relative), following a second finger or the
--                                 right button; the piece stays put meanwhile. spin_end: let go
--   nudge { along, delta }        along = "vertical" | "drag" (the drag plane's axis)
--   peek { on }                   while held, pieces fade so the walls show
--   undo, redo, remove, menu, next, rules, hint
-- Intents are shared and must not be changed by their receivers.
local hot = require "core.hot"
local controls = require "input.controls"
local M = {}

local ORBIT_PER_SCREEN = math.pi
local WHEEL_STEP = 0.9
-- A pinch zooms once its scale has changed by ZOOM_LOCK (a log ratio) and twists once it has
-- turned by TWIST_LOCK; once one has begun, the other needs twice as much.
local ZOOM_LOCK = math.log(1.08)
local TWIST_LOCK = math.rad(12)
-- A turn of a dragged piece spins it once its angle reaches SPIN_LOCK (see turnPiece).
local SPIN_LOCK = math.rad(10)

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
	hint = { kind = "hint" },
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
	return { screen_height = screen_height, drag = nil, sensitivity = 1, invert = false, lift = 0, held_x = 0, held_y = 0,
		tip_lock = 8, turn_step = 80 }
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
		state.held_x, state.held_y = 0, 0
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

-- Turning a dragged piece about one grid axis per touch (two fingers) or right-button drag
-- (mouse): the first motion past its threshold picks the axis, and the turn then follows the
-- motion; what moved before the choice is passed on, so nothing is lost to the threshold.
-- Sideways spins about vertical once past SPIN_LOCK: the mouse moved right turns the side facing
-- the viewer right; a twist turns the piece against it, as a dial would carry the piece, which
-- stands above the finger holding it while the thumb circles below. Up or down
-- tips once past `tip_lock` pixels, `turn_step` pixels a quarter turn, down tipping toward the
-- viewer.
local function turnPiece(state, angle, tip, out)
	local t = state.turning
	if not t.about then
		t.angle, t.tip = t.angle + angle, t.tip + tip
		if math.abs(t.angle) >= SPIN_LOCK then
			t.about, angle = "vertical", t.angle
		elseif math.abs(t.tip) >= state.tip_lock then
			t.about, tip = "right", t.tip
		else
			return
		end
	end
	if t.about == "vertical" and angle ~= 0 then
		out[#out + 1] = { kind = "spin", about = "vertical", angle = angle }
	elseif t.about == "right" and tip ~= 0 then
		out[#out + 1] = { kind = "spin", about = "right", angle = -tip / state.turn_step * math.pi / 2 }
	end
end

local function endTurn(state, out)
	if state.turning then
		state.turning = nil
		out[#out + 1] = { kind = "spin_end" }
	end
end

-- A dragged piece follows the pointer, except while it is being turned; the way the pointer
-- moved meanwhile is left out, so the piece goes on from where it is.
local function onDragMove(state, g, out)
	if state.drag == "piece" and g.button == "secondary" and state.turning then
		turnPiece(state, g.dx / state.turn_step * math.pi / 2, g.dy, out)
	elseif state.drag == "piece" and g.button == "primary" and (g.multi or state.turning) then
		state.held_x, state.held_y = state.held_x - g.dx, state.held_y - g.dy
	elseif state.drag == "piece" and g.button == "primary" then
		out[#out + 1] = { kind = "drag", x = g.x + state.held_x, y = g.y + state.raise + state.held_y }
	elseif state.drag == "orbit" and not g.multi then
		local scale = ORBIT_PER_SCREEN / state.screen_height * state.sensitivity * (state.invert and -1 or 1)
		out[#out + 1] = { kind = "orbit", yaw = -g.dx * scale, pitch = g.dy * scale }
	end
end

-- A pinch's zoom and twist, each once past its threshold (from that point on, so nothing jumps).
local function pinch(state, g, out)
	local p = (g.start or not state.pinch) and { scale = 0, twist = 0 } or state.pinch
	state.pinch = p
	p.scale, p.twist = p.scale + math.log(g.scale), p.twist + g.twist
	p.zooming = p.zooming or math.abs(p.scale) >= ZOOM_LOCK * (p.twisting and 2 or 1)
	p.twisting = p.twisting or math.abs(p.twist) >= TWIST_LOCK * (p.zooming and 2 or 1)
	if p.zooming then
		out[#out + 1] = { kind = "zoom", factor = 1 / g.scale }
	end
	if p.twisting then
		out[#out + 1] = { kind = "orbit", yaw = -g.twist, pitch = 0 }
	end
end

function M.gesture(state, g, pick, out)
	local dragging_piece = state.drag == "piece"
	if g.kind == "tap" then
		onTap(state, g, pick, out)
	elseif g.kind == "drag_start" and not state.drag then
		onDragStart(state, g, pick, out)
	elseif g.kind == "drag_start" and g.button == "secondary" and dragging_piece then
		state.turning = { angle = 0, tip = 0 }
	elseif g.kind == "drag_end" and g.button == "secondary" and dragging_piece then
		endTurn(state, out)
	elseif g.kind == "drag_move" then
		onDragMove(state, g, out)
	elseif g.kind == "press" then
		out[#out + 1] = { kind = "halt" }
	elseif g.kind == "drag_end" and (g.button == "primary" or state.drag == "orbit") then
		if dragging_piece then
			out[#out + 1] = { kind = "drop", x = g.x + state.held_x, y = g.y + state.raise + state.held_y }
		else
			out[#out + 1] = { kind = "coast" }
		end
		state.drag, state.turning = nil, nil
	elseif g.kind == "two_finger" and dragging_piece then
		if g.start or not state.turning then
			state.turning = { angle = 0, tip = 0 }
		end
		turnPiece(state, -g.twist, 2 * g.dy, out)
	elseif g.kind == "second_up" and dragging_piece then
		endTurn(state, out)
	elseif g.kind == "two_finger" then
		pinch(state, g, out)
	elseif g.kind == "drag_cancel" then
		if dragging_piece then
			out[#out + 1] = { kind = "drop", cancelled = true }
		end
		state.drag, state.turning = nil, nil
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
