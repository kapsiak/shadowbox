-- Hit testing for laid-out elements: { x, y } centres with either `size` (square) or `w`/`h`.
local M = {}

-- The id of the first enabled element containing the point, or nil.
function M.find(elements, x, y)
	for _, e in ipairs(elements) do
		local hw, hh = (e.w or e.size) / 2, (e.h or e.size) / 2
		if e.enabled ~= false and math.abs(x - e.x) <= hw and math.abs(y - e.y) <= hh then
			return e.id
		end
	end
end

return M
