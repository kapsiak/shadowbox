-- What each on-screen interface ("hud", "select") should show. Written by main.script each frame
-- and read by the GUI scripts (scripts share one Lua state), so the outer loop stays the only
-- place that decides. A nil layout means the interface is hidden.
local M = {}

local layouts, presses = {}, {}
local none = {}

function M.publish(name, layout)
	layouts[name] = layout
end

function M.layout(name)
	return layouts[name]
end

function M.pressed(name, id)
	presses[name] = presses[name] or {}
	table.insert(presses[name], id)
end

-- Returns and clears the presses since the last call.
function M.takePresses(name)
	local list = presses[name]
	if not list or #list == 0 then
		return none
	end
	presses[name] = {}
	return list
end

return M
