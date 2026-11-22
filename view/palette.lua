-- Piece colours from the theme, in the player's chosen palette.
local theme = require "view.theme"

local M = {}

-- mode: a theme palette name ("default", "deuteranopia", ...).
function M.color(name, mode)
	local palette = theme.palettes[mode] or theme.palettes.default
	return theme.vec(palette[name] or theme.fallback_piece)
end

return M
