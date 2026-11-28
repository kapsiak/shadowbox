local hot = require "core.hot"
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
	go.set(mesh, "finish", vmath.vector4(f.bevel, f.gloss, f.fill, 0))
end

function M.apply(mesh, level, id, prefs)
	local piece = level.pieces[id]
	go.set(mesh, "tint", palette.pieceColor(piece, prefs.colors))
	go.set(mesh, "pattern", vmath.vector4(prefs.patterns and (id - 1) % 6 + 1 or 0, 0, 0, 0))
end

function M.update(look, pieces, level, prefs)
	if look and look.colors == prefs.colors and look.patterns == prefs.patterns then
		return look
	end
	for id, p in pairs(pieces) do
		M.apply(p.mesh, level, id, prefs)
	end
	return { colors = prefs.colors, patterns = prefs.patterns }
end

return hot(..., M)
