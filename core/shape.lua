-- A polycube with all 24 orientations precomputed as offsets from an anchor cube
-- (the one nearest the centroid). A pose's cell is where the anchor sits, so
-- turning a piece only changes its orientation and never drifts.
local orient = require "core.orient"

local M = {}

local function nearestToCentroid(cells)
	local sum = { 0, 0, 0 }
	for _, c in ipairs(cells) do
		for a = 1, 3 do
			sum[a] = sum[a] + c[a]
		end
	end
	local best, best_d
	for _, c in ipairs(cells) do
		local d = 0
		for a = 1, 3 do
			local delta = c[a] * #cells - sum[a]
			d = d + delta * delta
		end
		if not best_d or d < best_d then
			best, best_d = c, d
		end
	end
	return best
end

-- Returns the shape and its anchor cell in the input's coordinates.
function M.new(cells)
	local anchor = nearestToCentroid(cells)
	local forms = {}
	for n = 1, orient.count do
		local form = {}
		for i, c in ipairs(cells) do
			form[i] = orient.apply(n, { c[1] - anchor[1], c[2] - anchor[2], c[3] - anchor[3] })
		end
		forms[n] = form
	end
	return { forms = forms, size = #cells }, { anchor[1], anchor[2], anchor[3] }
end

function M.cellsAt(shape, pose)
	local o = pose.cell
	local out = {}
	for i, c in ipairs(shape.forms[pose.orient]) do
		out[i] = { c[1] + o[1], c[2] + o[2], c[3] + o[3] }
	end
	return out
end

return M
