-- Voxel ray traversal (Amanatides & Woo) through a grid of `size`.
local hot = require "core.hot"
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

-- Visits the cells the ray crosses inside the box, in order: visit(cell, normal, t), where
-- normal is the face the ray entered through (nil if it starts inside the cell). Stops when
-- visit returns a value, which is returned; otherwise returns nil and the exit (last cell,
-- inward normal of the face the ray left through).
local function traverse(size, origin, dir, visit)
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
		local result = visit({ cell[1], cell[2], cell[3] }, normal, t)
		if result then
			return result
		end
		local a = 1
		if t_max[2] < t_max[a] then
			a = 2
		end
		if t_max[3] < t_max[a] then
			a = 3
		end
		normal = { 0, 0, 0 }
		normal[a] = -step[a]
		if cell[a] + step[a] < 0 or cell[a] + step[a] >= size[a] then
			return nil, { cell = { cell[1], cell[2], cell[3] }, normal = normal }
		end
		t = t_max[a]
		cell[a] = cell[a] + step[a]
		t_max[a] = t_max[a] + t_delta[a]
	end
end

-- Returns the first cell for which isSolid(cell) holds, the normal of the face the ray
-- entered it through (nil if the ray starts inside that cell), and the ray distance.
function M.firstHit(size, origin, dir, isSolid)
	local hit = traverse(size, origin, dir, function(cell, normal, t)
		if isSolid(cell) then
			return { cell = cell, normal = normal, t = t }
		end
	end)
	if hit then
		return hit.cell, hit.normal, hit.t
	end
end

-- The surface the ray meets first, as { cell, normal }: the free cell in front of it and the
-- normal pointing out of it. A surface is a solid cell's face or the inside of the box's
-- boundary (floor or wall) where the ray leaves. Nil when the ray misses the box.
function M.surface(size, origin, dir, isSolid)
	local last
	local hit, exit = traverse(size, origin, dir, function(cell, normal)
		if isSolid(cell) then
			return normal and { cell = last or { cell[1] + normal[1], cell[2] + normal[2], cell[3] + normal[3] },
				normal = normal }
		end
		last = cell
	end)
	return hit or exit
end

return hot(..., M)
