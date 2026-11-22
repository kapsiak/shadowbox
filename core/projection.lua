-- Orthographic projections of cells onto a view's (u, v) plane, as dense boolean grids.
local M = {}

M.axes = {
	front = { u = 1, v = 2 },
	side = { u = 3, v = 2 },
	top = { u = 1, v = 3 },
}

function M.project(size, cells, view)
	local axes = M.axes[view]
	local w, h = size[axes.u], size[axes.v]
	local filled = {}
	for i = 1, w * h do
		filled[i] = false
	end
	for _, c in ipairs(cells) do
		filled[c[axes.u] + c[axes.v] * w + 1] = true
	end
	return { w = w, h = h, filled = filled }
end

-- Per-cell status: "hit" (wanted and covered), "missing", "extra", or false (neither).
function M.compare(target, current)
	local status = {}
	local matches = true
	for i, wanted in ipairs(target.filled) do
		local covered = current.filled[i]
		if wanted and covered then
			status[i] = "hit"
		elseif wanted then
			status[i] = "missing"
		elseif covered then
			status[i] = "extra"
		else
			status[i] = false
		end
		matches = matches and wanted == covered
	end
	return { w = target.w, h = target.h, status = status, matches = matches }
end

return M
