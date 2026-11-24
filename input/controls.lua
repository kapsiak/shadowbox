-- Every keyboard action and the keys that can be bound. Pure data and lookups: one table drives
-- the key mapping (input/actions), key hints, the Keys settings and the input binding file
-- (tools/make_bindings.lua). Bindings in settings hold only the actions a player changed:
-- { [action id] = { key, ... } }.
local hot = require "core.hot"
local M = {}

-- `button`: the HUD button standing for the action; `fixed`: not rebindable.
M.actions = {
	{ id = "turn_left", label = "Turn left", keys = { "q" }, button = "turn_left" },
	{ id = "turn_right", label = "Turn right", keys = { "e" }, button = "turn_right" },
	{ id = "tip_away", label = "Tip away", keys = { "w" }, button = "tip_away" },
	{ id = "tip_toward", label = "Tip toward", keys = { "s" } },
	{ id = "roll_left", label = "Roll left", keys = { "a" } },
	{ id = "roll_right", label = "Roll right", keys = { "d" }, button = "roll_right" },
	{ id = "lift", label = "Lift", keys = { "r" }, button = "lift" },
	{ id = "lower", label = "Lower", keys = { "f" }, button = "lower" },
	{ id = "remove", label = "Put back", keys = { "backspace", "delete" }, button = "stow" },
	{ id = "view_front", label = "Front view", keys = { "1" }, button = "view_front" },
	{ id = "view_side", label = "Side view", keys = { "2" }, button = "view_side" },
	{ id = "view_top", label = "Top view", keys = { "3" }, button = "view_top" },
	{ id = "view_iso", label = "Free view", keys = { "4" }, button = "view_iso" },
	{ id = "orbit_left", label = "Orbit left", keys = { "left" } },
	{ id = "orbit_right", label = "Orbit right", keys = { "right" } },
	{ id = "orbit_up", label = "Orbit up", keys = { "up" } },
	{ id = "orbit_down", label = "Orbit down", keys = { "down" } },
	{ id = "zoom_in", label = "Zoom in", keys = { "equals" } },
	{ id = "zoom_out", label = "Zoom out", keys = { "minus" } },
	{ id = "peek", label = "Peek at walls (hold)", keys = { "space" }, button = "peek" },
	{ id = "undo", label = "Undo", keys = { "z" }, button = "undo" },
	{ id = "redo", label = "Redo", keys = { "y" }, button = "redo" },
	{ id = "rules", label = "Rules", keys = { "h" }, button = "rules" },
	{ id = "confirm", label = "Next level", keys = { "enter" }, button = "next" },
	{ id = "menu", label = "Menu", keys = { "escape" }, button = "menu", fixed = true },
}

local by_id, by_button = {}, {}
for _, a in ipairs(M.actions) do
	by_id[a.id] = a
	if a.button then
		by_button[a.button] = a
	end
end

-- The Keys settings: pages of rows, each row a label and the actions it binds.
M.pages = {
	{ id = "piece", label = "Piece", rows = {
		{ "Turn", "turn_left", "turn_right" }, { "Tip", "tip_away", "tip_toward" },
		{ "Roll", "roll_left", "roll_right" }, { "Lift, lower", "lift", "lower" }, { "Put back", "remove" },
	} },
	{ id = "camera", label = "Camera", rows = {
		{ "Views", "view_front", "view_side", "view_top", "view_iso" }, { "Orbit", "orbit_left", "orbit_right" },
		{ "Tilt", "orbit_up", "orbit_down" }, { "Zoom", "zoom_in", "zoom_out" }, { "Peek", "peek" },
	} },
	{ id = "other", label = "Other", rows = {
		{ "Undo, redo", "undo", "redo" }, { "Next level", "confirm" }, { "Rules", "rules" },
	} },
}

-- Bindable keys: name, Defold trigger, label. Escape stays with the menu (and cancels rebinding).
M.keys = {}
local function key(name, trigger, label)
	M.keys[#M.keys + 1] = { name = name, trigger = trigger, label = label }
end
for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
	key(c, "KEY_" .. c:upper(), c:upper())
end
for d = 0, 9 do
	key(tostring(d), "KEY_" .. d, tostring(d))
	key("kp_" .. d, "KEY_KP_" .. d, "Num " .. d)
end
for f = 1, 12 do
	key("f" .. f, "KEY_F" .. f, "F" .. f)
end
for _, k in ipairs({
	{ "escape", "KEY_ESC", "Esc" }, { "enter", "KEY_ENTER", "Enter" }, { "space", "KEY_SPACE", "Space" },
	{ "tab", "KEY_TAB", "Tab" }, { "backspace", "KEY_BACKSPACE", "Backspace" }, { "delete", "KEY_DEL", "Del" },
	{ "insert", "KEY_INSERT", "Ins" }, { "home", "KEY_HOME", "Home" }, { "end", "KEY_END", "End" },
	{ "pageup", "KEY_PAGEUP", "PgUp" }, { "pagedown", "KEY_PAGEDOWN", "PgDn" },
	{ "up", "KEY_UP", "↑" }, { "down", "KEY_DOWN", "↓" }, { "left", "KEY_LEFT", "←" }, { "right", "KEY_RIGHT", "→" },
	{ "minus", "KEY_MINUS", "-" }, { "equals", "KEY_EQUALS", "=" }, { "lbracket", "KEY_LBRACKET", "[" },
	{ "rbracket", "KEY_RBRACKET", "]" }, { "semicolon", "KEY_SEMICOLON", ";" }, { "quote", "KEY_QUOTE", "'" },
	{ "comma", "KEY_COMMA", "," }, { "period", "KEY_PERIOD", "." }, { "slash", "KEY_SLASH", "/" },
	{ "backslash", "KEY_BACKSLASH", "\\" }, { "backquote", "KEY_BACKQUOTE", "`" },
	{ "kp_add", "KEY_KP_ADD", "Num +" }, { "kp_subtract", "KEY_KP_SUBTRACT", "Num -" },
	{ "kp_multiply", "KEY_KP_MULTIPLY", "Num *" }, { "kp_divide", "KEY_KP_DIVIDE", "Num /" },
	{ "kp_decimal", "KEY_KP_DECIMAL", "Num ." }, { "kp_enter", "KEY_KP_ENTER", "Num Enter" },
	{ "lshift", "KEY_LSHIFT", "Shift" }, { "rshift", "KEY_RSHIFT", "R Shift" },
	{ "lctrl", "KEY_LCTRL", "Ctrl" }, { "rctrl", "KEY_RCTRL", "R Ctrl" },
	{ "lalt", "KEY_LALT", "Alt" }, { "ralt", "KEY_RALT", "R Alt" },
}) do
	key(k[1], k[2], k[3])
end
local key_labels = {}
for _, k in ipairs(M.keys) do
	key_labels[k.name] = k.label
end

function M.action(id)
	return by_id[id]
end

-- The action a HUD button stands for, or nil.
function M.forButton(button)
	return by_button[button]
end

function M.keyLabel(name)
	return key_labels[name] or name
end

function M.keysOf(bindings, id)
	local a = by_id[id]
	return not a.fixed and bindings[id] or a.keys
end

-- { [key name] = action id } for the player's bindings.
function M.keymap(bindings)
	local map = {}
	for _, a in ipairs(M.actions) do
		for _, k in ipairs(M.keysOf(bindings, a.id)) do
			map[k] = a.id
		end
	end
	return map
end

-- Bindings with `id` on `key` alone, taken from any action that had it (which may be left
-- without a key). Nil when the action or key cannot be bound.
function M.rebind(bindings, id, key_name)
	local a = by_id[id]
	if not a or a.fixed or not key_labels[key_name] or key_name == "escape" then
		return nil
	end
	local out = {}
	for _, other in ipairs(M.actions) do
		if not other.fixed and other.id ~= id then
			local kept = {}
			for _, k in ipairs(M.keysOf(bindings, other.id)) do
				if k ~= key_name then
					kept[#kept + 1] = k
				end
			end
			out[other.id] = kept
		end
	end
	out[id] = { key_name }
	return M.changed(out)
end

local function sameKeys(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- Only the bindings that differ from the defaults, with unknown actions and keys dropped.
function M.changed(bindings)
	local out = {}
	for _, a in ipairs(M.actions) do
		local keys = type(bindings) == "table" and bindings[a.id]
		if not a.fixed and type(keys) == "table" then
			local clean = {}
			for _, k in ipairs(keys) do
				if key_labels[k] and k ~= "escape" then
					clean[#clean + 1] = k
				end
			end
			if not sameKeys(clean, a.keys) then
				out[a.id] = clean
			end
		end
	end
	return out
end

return hot(..., M)
