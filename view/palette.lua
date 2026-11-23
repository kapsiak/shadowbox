-- Piece colours from the theme, in the player's chosen palette.
local hot = require "core.hot"
local theme = require "view.theme"
local channels = require "core.channels"

local M = {}

function M.isGlass(piece)
	return piece.value.light ~= channels.light.default
end

-- mode: a theme palette name ("default", "deuteranopia", ...). Glass is coloured by its light.
function M.pieceColor(piece, mode)
	if M.isGlass(piece) then
		return theme.vec(theme.glass[piece.value.light])
	end
	local palette = theme.palettes[mode] or theme.palettes.default
	return theme.vec(palette[piece.color] or theme.fallback_piece)
end

return hot(..., M)
