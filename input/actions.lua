local hot = require "core.hot"
local controls = require "input.controls"
local M = {}

local pointers = { [hash("touch")] = "primary", [hash("touch_alt")] = "secondary" }
local wheels = { [hash("wheel_up")] = 1, [hash("wheel_down")] = -1 }
local MULTI_TOUCH = hash("multi_touch")

local keys = {}
for _, k in ipairs(controls.keys) do
	keys[hash("key_" .. k.name)] = k.name
end

function M.read(action_id, action, keymap)
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
	-- The wheel arrives as a held button: a trackpad repeats it while scrolling, value 1 each
	-- time and 0 on release, so every event with a value is one step; `start` marks a gesture's first.
	if wheels[action_id] and (action.value or 0) > 0 then
		return { kind = "wheel", amount = wheels[action_id], start = action.pressed }
	end
	if keys[action_id] then
		local key = keys[action_id]
		return { kind = "key", key = key, name = keymap[key], pressed = action.pressed, released = action.released }
	end
end

return hot(..., M)
