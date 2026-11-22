-- Voxel ray traversal (Amanatides & Woo) through a grid of `size`.
local M = {}

local function clipToBox(size, origin, dir)
	local t_enter, t_exit, enter_axis = 0, math.huge, nil
	for a = 1, 3 do
		if dir[a] == 0 then
			if origin[a] < 0 or origin[a] > size[a] then
				return nil
			end
		else
			local ta, tb = -origin[a] / dir[a], (size[a] - origin[a]) / dir[a]
			if ta > tb then
				ta, tb = tb, ta
			end
			if ta > t_enter then
				t_enter, enter_axis = ta, a
			end
			t_exit = math.min(t_exit, tb)
		end
	end
	if t_enter > t_exit then
		return nil
	end
	return t_enter, enter_axis
end

-- Returns the first cell for which isSolid(cell) holds, the normal of the face the ray
-- entered it through (nil if the ray starts inside that cell), and the ray distance.
function M.firstHit(size, origin, dir, isSolid)
	local t, enter_axis = clipToBox(size, origin, dir)
	if not t then
		return nil
	end
	local cell, step, t_max, t_delta = {}, {}, {}, {}
	for a = 1, 3 do
		local p = origin[a] + dir[a] * t
		cell[a] = math.max(0, math.min(size[a] - 1, math.floor(p)))
		if dir[a] > 0 then
			step[a], t_max[a], t_delta[a] = 1, t + (cell[a] + 1 - p) / dir[a], 1 / dir[a]
		elseif dir[a] < 0 then
			step[a], t_max[a], t_delta[a] = -1, t + (cell[a] - p) / dir[a], -1 / dir[a]
		else
			step[a], t_max[a], t_delta[a] = 0, math.huge, math.huge
		end
	end
	local normal
	if enter_axis then
		normal = { 0, 0, 0 }
		normal[enter_axis] = -step[enter_axis]
	end
	while true do
		if isSolid(cell) then
			return { cell[1], cell[2], cell[3] }, normal, t
		end
		local a = 1
		if t_max[2] < t_max[a] then
			a = 2
		end
		if t_max[3] < t_max[a] then
			a = 3
		end
		t = t_max[a]
		cell[a] = cell[a] + step[a]
		if cell[a] < 0 or cell[a] >= size[a] then
			return nil
		end
		t_max[a] = t_max[a] + t_delta[a]
		normal = { 0, 0, 0 }
		normal[a] = -step[a]
	end
end

return M
