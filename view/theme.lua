-- The game's look as data: piece palettes, lighting, panels, background and interface colours.
-- Everything visual reads from here, so a new art direction starts as a new theme table.
-- Colours are { r, g, b } or { r, g, b, a } in [0, 1].
local M = {}

-- Pieces are named by colour in level files; each palette maps every name to a colour.
-- The colour-blind palettes keep pieces distinct under each colour vision deficiency.
M.palettes = {
	default = {
		coral = { 0.95, 0.55, 0.5 }, sky = { 0.5, 0.72, 0.93 }, mint = { 0.52, 0.85, 0.7 },
		butter = { 0.97, 0.84, 0.48 }, lilac = { 0.74, 0.62, 0.92 }, peach = { 0.98, 0.7, 0.52 },
		sage = { 0.66, 0.78, 0.56 }, rose = { 0.93, 0.6, 0.76 }, teal = { 0.42, 0.78, 0.8 },
		slate = { 0.6, 0.64, 0.74 },
	},
	-- Okabe-Ito based, for deuteranopia and protanopia.
	deuteranopia = {
		coral = { 0.93, 0.62, 0.25 }, sky = { 0.45, 0.72, 0.92 }, mint = { 0.25, 0.68, 0.55 },
		butter = { 0.95, 0.89, 0.4 }, lilac = { 0.78, 0.55, 0.7 }, peach = { 0.86, 0.45, 0.22 },
		sage = { 0.2, 0.45, 0.72 }, rose = { 0.9, 0.75, 0.85 }, teal = { 0.55, 0.85, 0.85 },
		slate = { 0.55, 0.55, 0.58 },
	},
	tritanopia = {
		coral = { 0.9, 0.35, 0.38 }, sky = { 0.35, 0.75, 0.78 }, mint = { 0.55, 0.85, 0.8 },
		butter = { 0.98, 0.72, 0.75 }, lilac = { 0.5, 0.45, 0.6 }, peach = { 0.75, 0.2, 0.28 },
		sage = { 0.2, 0.5, 0.55 }, rose = { 0.95, 0.55, 0.65 }, teal = { 0.15, 0.62, 0.65 },
		slate = { 0.55, 0.55, 0.58 },
	},
}
M.palettes.protanopia = M.palettes.deuteranopia
M.fallback_piece = { 0.8, 0.8, 0.8 }

M.light = {
	sky = { 0.86, 0.87, 0.94 },
	ground = { 0.56, 0.53, 0.6 },
	key = { 0.32, 0.3, 0.26 },
	key_dir = { -0.45, -0.8, -0.35 },
}

-- Projection panels: base surface, ink for covered target cells, warn for extra coverage.
M.panel = {
	normal = { base = { 0.95, 0.93, 0.9 }, ink = { 0.45, 0.48, 0.63 }, warn = { 0.93, 0.5, 0.46 } },
	high_contrast = { base = { 0.97, 0.96, 0.94 }, ink = { 0.12, 0.14, 0.3 }, warn = { 0.85, 0.15, 0.1 } },
}

M.background = { top = { 0.93, 0.9, 0.95 }, bottom = { 0.78, 0.83, 0.9 } }
M.tray_fill = { 0.98, 0.97, 0.98, 0.55 }

M.ui = {
	face = { 0.99, 0.98, 0.97, 0.94 },
	card = { 0.98, 0.97, 0.97, 0.97 },
	shadow = { 0.2, 0.2, 0.35, 0.14 },
	ink = { 0.3, 0.32, 0.44, 1 },
	soft_ink = { 0.45, 0.47, 0.58, 1 },
	icon = { 0.36, 0.38, 0.5, 1 },
	accent = { 0.42, 0.46, 0.66, 1 },
	track = { 0.86, 0.86, 0.9, 1 },
	danger = { 0.85, 0.36, 0.34, 1 },
	solved = { 0.36, 0.7, 0.55, 1 },
	cell_off = { 0.88, 0.87, 0.88, 1 },
	dim = { 0.16, 0.17, 0.27, 0.3 },
	fade = { 0.93, 0.91, 0.96, 1 },
	white = { 1, 1, 1, 1 },
}

-- Converts a theme colour to a vmath.vector4 (alpha defaults to 1).
function M.vec(c)
	return vmath.vector4(c[1], c[2], c[3], c[4] or 1)
end

return M
