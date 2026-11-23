-- How a piece mesh looks: lighting from the theme, and colour and pattern from preferences.
local orient = require "core.orient"
local palette = require "view.palette"
local theme = require "view.theme"

local M = {}

function M.applyLight(mesh)
	local light = theme.light
	go.set(mesh, "sky", theme.vec(light.sky))
	go.set(mesh, "ground", theme.vec(light.ground))
	go.set(mesh, "key_color", theme.vec(light.key))
	go.set(mesh, "key_dir", vmath.vector4(light.key_dir[1], light.key_dir[2], light.key_dir[3], 0))
	local f = theme.finish
	go.set(mesh, "finish", vmath.vector4(f.bevel, f.gloss, f.grain, f.fill))
end

-- The axis (0, 1, 2) along which a piece is longest, for its wood grain to follow.
local function grainAxis(piece)
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, c in ipairs(piece.shape.forms[orient.identity]) do
		for k = 1, 3 do
			lo[k], hi[k] = math.min(lo[k], c[k]), math.max(hi[k], c[k])
		end
	end
	local best = 1
	for k = 2, 3 do
		if hi[k] - lo[k] > hi[best] - lo[best] then
			best = k
		end
	end
	return best - 1
end

-- prefs: { colors = palette name, patterns = bool }.
function M.apply(mesh, level, id, prefs)
	local piece = level.pieces[id]
	go.set(mesh, "tint", palette.pieceColor(piece, prefs.colors))
	go.set(mesh, "pattern", vmath.vector4(prefs.patterns and (id - 1) % 6 + 1 or 0, grainAxis(piece), 0, 0))
end

-- A key that changes whenever `apply` would give a different result.
function M.key(prefs)
	return tostring(prefs.colors) .. (prefs.patterns and "+patterns" or "")
end

return M
