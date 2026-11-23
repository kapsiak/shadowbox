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

local function bounds(cells)
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, c in ipairs(cells) do
		for a = 1, 3 do
			lo[a], hi[a] = math.min(lo[a], c[a]), math.max(hi[a], c[a])
		end
	end
	return lo, hi
end

local function cellSet(cells, offset)
	local set = {}
	for _, c in ipairs(cells) do
		set[(c[1] + offset[1]) .. "," .. (c[2] + offset[2]) .. "," .. (c[3] + offset[3])] = true
	end
	return set
end

-- The cells turned to the piece's resting orientation and moved to the origin: lowest, then
-- shallowest, then the first by a fixed order. Depends only on the shape, never on how it was drawn.
function M.rest(cells)
	local best, best_score
	for n = 1, orient.count do
		local turned = {}
		for i, c in ipairs(cells) do
			turned[i] = orient.apply(n, c)
		end
		local lo, hi = bounds(turned)
		local parts = {}
		for i, c in ipairs(turned) do
			turned[i] = { c[1] - lo[1] + 0, c[2] - lo[2] + 0, c[3] - lo[3] + 0 }
			parts[i] = table.concat(turned[i], ",")
		end
		table.sort(parts)
		local score = ("%03d%03d%s"):format(hi[2] - lo[2], hi[3] - lo[3], table.concat(parts, " "))
		if not best_score or score < best_score then
			best, best_score = turned, score
		end
	end
	return best
end

-- The pose that puts the shape exactly on `cells`, or nil if no orientation fits.
function M.poseOf(shape, cells)
	local target_lo = bounds(cells)
	local target = cellSet(cells, { 0, 0, 0 })
	for n = 1, orient.count do
		local form = shape.forms[n]
		local lo = bounds(form)
		local cell = { target_lo[1] - lo[1], target_lo[2] - lo[2], target_lo[3] - lo[3] }
		local fits = true
		for key in pairs(cellSet(form, cell)) do
			fits = fits and target[key]
		end
		if fits then
			return { cell = cell, orient = n }
		end
	end
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
