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
--   turn { about, dir }           about = "vertical" | "right" | "toward" (camera-relative)
--   nudge { along, delta }        along = "vertical" | "drag" (the drag plane's axis)
--   undo, redo, remove, menu, next
local M = {}

local ORBIT_PER_SCREEN = math.pi
local WHEEL_STEP = 0.9

local key_views = { view_front = "front", view_side = "side", view_top = "top", view_iso = "iso" }
local key_orbits = {
	orbit_left = { -1, 0 },
	orbit_right = { 1, 0 },
	orbit_up = { 0, -1 },
	orbit_down = { 0, 1 },
}
local key_zooms = { zoom_in = WHEEL_STEP, zoom_out = 1 / WHEEL_STEP }
local key_turns = {
	turn_left = { "vertical", -1 },
	turn_right = { "vertical", 1 },
	tip_away = { "right", -1 },
	tip_toward = { "right", 1 },
	roll_left = { "toward", 1 },
	roll_right = { "toward", -1 },
}
local key_nudges = { lift = 1, lower = -1 }
local key_commands = { undo = "undo", redo = "redo", remove = "remove", menu = "menu", confirm = "next" }

-- On-screen buttons (ui/hud_layout ids) and the intents they stand for.
local buttons = {
	undo = { kind = "undo" },
	redo = { kind = "redo" },
	menu = { kind = "menu" },
	view_front = { kind = "view", name = "front" },
	view_side = { kind = "view", name = "side" },
	view_top = { kind = "view", name = "top" },
	view_iso = { kind = "view", name = "iso" },
	turn_left = { kind = "turn", about = "vertical", dir = -1 },
	turn_right = { kind = "turn", about = "vertical", dir = 1 },
	tip_away = { kind = "turn", about = "right", dir = -1 },
	roll_right = { kind = "turn", about = "toward", dir = -1 },
	lift = { kind = "nudge", along = "vertical", delta = 1 },
	lower = { kind = "nudge", along = "vertical", delta = -1 },
	stow = { kind = "remove" },
	next = { kind = "next" },
}

-- screen_height normalizes drag distances so sensitivity is resolution independent.
-- sensitivity scales camera drags; invert flips their direction.
function M.new(screen_height)
	return { screen_height = screen_height, drag = nil, sensitivity = 1, invert = false }
end

local function onKey(g, out)
	local name = g.name
	if g.pressed and key_views[name] then
		out[#out + 1] = { kind = "view", name = key_views[name] }
	elseif not g.released and key_orbits[name] then
		local o = key_orbits[name]
		out[#out + 1] = { kind = "orbit_rate", yaw = o[1], pitch = o[2] }
	elseif g.pressed and key_zooms[name] then
		out[#out + 1] = { kind = "zoom", factor = key_zooms[name] }
	elseif g.pressed and key_turns[name] then
		out[#out + 1] = { kind = "turn", about = key_turns[name][1], dir = key_turns[name][2] }
	elseif g.pressed and key_nudges[name] then
		out[#out + 1] = { kind = "nudge", along = "vertical", delta = key_nudges[name] }
	elseif g.pressed and key_commands[name] then
		out[#out + 1] = { kind = key_commands[name] }
	end
end

local function onDragStart(state, g, pick, out)
	local hit = g.button == "primary" and pick(g.x, g.y)
	if hit then
		state.drag = "piece"
		out[#out + 1] = { kind = "grab", piece = hit.piece, cell = hit.cell, from_tray = hit.from_tray, x = g.x, y = g.y }
	else
		state.drag = "orbit"
	end
end

function M.button(id, out)
	local intent = buttons[id]
	if intent then
		local copy = {}
		for k, v in pairs(intent) do
			copy[k] = v
		end
		out[#out + 1] = copy
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
		out[#out + 1] = { kind = "drag", x = g.x, y = g.y }
	elseif state.drag == "orbit" and not g.multi then
		local scale = ORBIT_PER_SCREEN / state.screen_height * state.sensitivity * (state.invert and -1 or 1)
		out[#out + 1] = { kind = "orbit", yaw = -g.dx * scale, pitch = g.dy * scale }
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
			out[#out + 1] = { kind = "drop", x = g.x, y = g.y }
		end
		state.drag = nil
	elseif g.kind == "second_tap" and dragging_piece then
		out[#out + 1] = { kind = "turn", about = "vertical", dir = 1 }
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
	elseif g.kind == "hover" and not state.drag then
		local hit = pick(g.x, g.y)
		out[#out + 1] = { kind = "hover", piece = hit and hit.piece }
	end
end

return M
