-- Translates Defold input actions into the raw events input/gestures.lua consumes.
local M = {}

local pointers = { [hash("touch")] = "primary", [hash("touch_alt")] = "secondary" }
local wheels = { [hash("wheel_up")] = 1, [hash("wheel_down")] = -1 }
local MULTI_TOUCH = hash("multi_touch")

local keys = {}
for _, name in ipairs({
	"view_front", "view_side", "view_top", "view_iso",
	"orbit_left", "orbit_right", "orbit_up", "orbit_down",
	"zoom_in", "zoom_out",
	"turn_left", "turn_right", "tip_away", "tip_toward", "roll_left", "roll_right",
	"undo", "redo", "remove", "lift", "lower", "menu", "confirm",
}) do
	keys[hash(name)] = name
end

-- Returns a raw event, or nil for actions the game does not use.
function M.read(action_id, action)
	if action_id == nil then
		return { kind = "hover", x = action.screen_x, y = action.screen_y }
	end
	if pointers[action_id] then
		return {
			kind = "pointer", button = pointers[action_id],
			x = action.screen_x, y = action.screen_y,
			pressed = action.pressed, released = action.released,
		}
	end
	if action_id == MULTI_TOUCH then
		local points = {}
		for i, t in ipairs(action.touch) do
			points[i] = { id = t.id, x = t.screen_x, y = t.screen_y, pressed = t.pressed, released = t.released }
		end
		return { kind = "touches", points = points }
	end
	if wheels[action_id] and action.pressed then
		return { kind = "wheel", amount = wheels[action_id] * (action.value or 1) }
	end
	if keys[action_id] then
		return { kind = "key", name = keys[action_id], pressed = action.pressed, released = action.released }
	end
end

return M
