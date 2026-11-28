local hot = require "core.hot"
local M = {}

function M.find(elements, x, y)
	for _, e in ipairs(elements) do
		local hw, hh = (e.w or e.size) / 2, (e.h or e.size) / 2
		if e.enabled ~= false and math.abs(x - e.x) <= hw and math.abs(y - e.y) <= hh then
			return e.id
		end
	end
end

return hot(..., M)
