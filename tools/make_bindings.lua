-- Usage (from the project root): luajit tools/make_bindings.lua
-- Writes input/game.input_binding: every bindable key (input/controls) as its own action
-- "key_<name>", which input/actions maps to game actions through the player's bindings, and
-- the fixed mouse and touch triggers.
package.path = "./?.lua;" .. package.path

local controls = require "input.controls"

local out = {}
local function trigger(kind, input, action)
	out[#out + 1] = ("%s {\n  input: %s\n  action: \"%s\"\n}"):format(kind, input, action)
end
for _, k in ipairs(controls.keys) do
	trigger("key_trigger", k.trigger, "key_" .. k.name)
end
trigger("mouse_trigger", "MOUSE_BUTTON_LEFT", "touch")
trigger("mouse_trigger", "MOUSE_BUTTON_RIGHT", "touch_alt")
trigger("mouse_trigger", "MOUSE_WHEEL_UP", "wheel_up")
trigger("mouse_trigger", "MOUSE_WHEEL_DOWN", "wheel_down")
trigger("touch_trigger", "TOUCH_MULTI", "multi_touch")

local f = assert(io.open("input/game.input_binding", "w"))
f:write(table.concat(out, "\n"), "\n")
f:close()
