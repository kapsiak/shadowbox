-- The game's look as data: piece palettes, lighting, panels, background and interface colours.
-- Everything visual reads from here, so a new art direction starts as a new theme table.
-- Colours are { r, g, b } or { r, g, b, a } in [0, 1].
local M = {}

-- Pieces are named by colour in level files; each palette maps every name to a colour.
-- The colour-blind palettes keep pieces distinct under each colour vision deficiency.
M.palettes = {
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

-- Light by its RGB bit set (core/channels): the colour of glass pieces, which multiply what
-- lies behind them, and of the light a wall cell receives. Kept pale so stacked glass mixes
-- visibly (cyan over yellow reads green).
M.glass = {
	[1] = { 0.96, 0.56, 0.54 }, [2] = { 0.56, 0.84, 0.56 }, [3] = { 0.98, 0.9, 0.5 },
	[4] = { 0.56, 0.66, 0.96 }, [5] = { 0.9, 0.6, 0.9 }, [6] = { 0.54, 0.87, 0.93 },
}

-- Candidate looks under comparison; `active` picks one. Each holds the default piece palette,
-- lighting, cube edges, panels, background, tray and interface colours.
local looks = {}

looks.pastel = {
	pieces = {
		coral = { 0.95, 0.55, 0.5 }, sky = { 0.5, 0.72, 0.93 }, mint = { 0.52, 0.85, 0.7 },
		butter = { 0.97, 0.84, 0.48 }, lilac = { 0.74, 0.62, 0.92 }, peach = { 0.98, 0.7, 0.52 },
		sage = { 0.66, 0.78, 0.56 }, rose = { 0.93, 0.6, 0.76 }, teal = { 0.42, 0.78, 0.8 },
		slate = { 0.6, 0.64, 0.74 },
	},
	light = { sky = { 0.86, 0.87, 0.94 }, ground = { 0.56, 0.53, 0.6 }, key = { 0.32, 0.3, 0.26 }, key_dir = { -0.45, -0.8, -0.35 } },
	-- x: highlight along outer edges, y: brightness at the outline, z: darkening along seams
	edges = { 0.1, 0.78, 0.1 },
	panel = {
		normal = { base = { 0.95, 0.93, 0.9 }, ink = { 0.45, 0.48, 0.63 }, warn = { 0.93, 0.5, 0.46 } },
		high_contrast = { base = { 0.97, 0.96, 0.94 }, ink = { 0.12, 0.14, 0.3 }, warn = { 0.85, 0.15, 0.1 } },
	},
	background = { top = { 0.93, 0.9, 0.95 }, bottom = { 0.78, 0.83, 0.9 } },
	tray_fill = { 0.98, 0.97, 0.98, 0.55 },
	ui = {
		face = { 0.99, 0.98, 0.97, 0.94 }, card = { 0.98, 0.97, 0.97, 0.97 }, shadow = { 0.2, 0.2, 0.35, 0.14 },
		ink = { 0.3, 0.32, 0.44, 1 }, soft_ink = { 0.45, 0.47, 0.58, 1 }, icon = { 0.36, 0.38, 0.5, 1 },
		accent = { 0.42, 0.46, 0.66, 1 }, track = { 0.86, 0.86, 0.9, 1 }, danger = { 0.85, 0.36, 0.34, 1 },
		solved = { 0.36, 0.7, 0.55, 1 }, cell_off = { 0.88, 0.87, 0.88, 1 }, dim = { 0.16, 0.17, 0.27, 0.3 },
		fade = { 0.93, 0.91, 0.96, 1 }, white = { 1, 1, 1, 1 },
	},
}

-- Warm plaster under a low sun; matte, earthy pieces; walls hold shadow.
looks.light_study = {
	pieces = {
		coral = { 0.85, 0.42, 0.32 }, sky = { 0.36, 0.58, 0.78 }, mint = { 0.42, 0.68, 0.52 },
		butter = { 0.93, 0.74, 0.32 }, lilac = { 0.6, 0.48, 0.72 }, peach = { 0.92, 0.6, 0.4 },
		sage = { 0.58, 0.66, 0.42 }, rose = { 0.82, 0.46, 0.56 }, teal = { 0.25, 0.58, 0.6 },
		slate = { 0.45, 0.48, 0.55 },
	},
	light = { sky = { 0.62, 0.64, 0.7 }, ground = { 0.42, 0.36, 0.32 }, key = { 0.62, 0.54, 0.42 }, key_dir = { -0.6, -0.6, -0.5 } },
	edges = { 0.04, 0.86, 0.05 },
	panel = {
		normal = { base = { 0.94, 0.9, 0.83 }, ink = { 0.36, 0.3, 0.28 }, warn = { 0.86, 0.42, 0.3 } },
		high_contrast = { base = { 0.98, 0.96, 0.92 }, ink = { 0.15, 0.12, 0.1 }, warn = { 0.85, 0.15, 0.1 } },
	},
	background = { top = { 0.95, 0.91, 0.84 }, bottom = { 0.8, 0.72, 0.62 } },
	tray_fill = { 0.99, 0.96, 0.9, 0.6 },
	ui = {
		face = { 0.99, 0.97, 0.93, 0.95 }, card = { 0.98, 0.96, 0.92, 0.97 }, shadow = { 0.3, 0.2, 0.1, 0.14 },
		ink = { 0.27, 0.22, 0.2, 1 }, soft_ink = { 0.48, 0.42, 0.38, 1 }, icon = { 0.36, 0.3, 0.27, 1 },
		accent = { 0.78, 0.42, 0.28, 1 }, track = { 0.88, 0.84, 0.78, 1 }, danger = { 0.8, 0.3, 0.25, 1 },
		solved = { 0.38, 0.6, 0.42, 1 }, cell_off = { 0.88, 0.85, 0.8, 1 }, dim = { 0.2, 0.15, 0.1, 0.3 },
		fade = { 0.95, 0.91, 0.84, 1 }, white = { 1, 1, 1, 1 },
	},
}

-- Saturated candy colours, chunky bevels, bright sky.
looks.soft_toy = {
	pieces = {
		coral = { 1.0, 0.38, 0.36 }, sky = { 0.22, 0.6, 1.0 }, mint = { 0.2, 0.85, 0.55 },
		butter = { 1.0, 0.82, 0.15 }, lilac = { 0.62, 0.4, 0.95 }, peach = { 1.0, 0.58, 0.2 },
		sage = { 0.55, 0.8, 0.25 }, rose = { 1.0, 0.42, 0.68 }, teal = { 0.1, 0.75, 0.8 },
		slate = { 0.45, 0.5, 0.65 },
	},
	light = { sky = { 0.95, 0.95, 1.0 }, ground = { 0.55, 0.5, 0.62 }, key = { 0.35, 0.33, 0.3 }, key_dir = { -0.45, -0.8, -0.35 } },
	edges = { 0.22, 0.7, 0.18 },
	panel = {
		normal = { base = { 1, 1, 1 }, ink = { 0.25, 0.35, 0.7 }, warn = { 1.0, 0.35, 0.3 } },
		high_contrast = { base = { 1, 1, 1 }, ink = { 0.1, 0.15, 0.4 }, warn = { 0.9, 0.15, 0.1 } },
	},
	background = { top = { 0.72, 0.88, 1.0 }, bottom = { 0.95, 0.97, 1.0 } },
	tray_fill = { 1, 1, 1, 0.7 },
	ui = {
		face = { 1, 1, 1, 0.97 }, card = { 1, 1, 1, 0.98 }, shadow = { 0.1, 0.2, 0.45, 0.18 },
		ink = { 0.15, 0.2, 0.4, 1 }, soft_ink = { 0.35, 0.42, 0.6, 1 }, icon = { 0.2, 0.28, 0.5, 1 },
		accent = { 1.0, 0.45, 0.3, 1 }, track = { 0.85, 0.9, 0.98, 1 }, danger = { 0.95, 0.3, 0.3, 1 },
		solved = { 0.2, 0.78, 0.5, 1 }, cell_off = { 0.88, 0.9, 0.95, 1 }, dim = { 0.1, 0.15, 0.35, 0.3 },
		fade = { 0.85, 0.93, 1, 1 }, white = { 1, 1, 1, 1 },
	},
}

-- Night drafting table: dark ground, glowing edges, cyan line work.
looks.blueprint = {
	pieces = {
		coral = { 1.0, 0.45, 0.45 }, sky = { 0.35, 0.7, 1.0 }, mint = { 0.3, 0.95, 0.7 },
		butter = { 1.0, 0.86, 0.35 }, lilac = { 0.72, 0.55, 1.0 }, peach = { 1.0, 0.62, 0.35 },
		sage = { 0.6, 0.9, 0.4 }, rose = { 1.0, 0.5, 0.8 }, teal = { 0.25, 0.9, 0.95 },
		slate = { 0.55, 0.62, 0.8 },
	},
	light = { sky = { 0.5, 0.55, 0.7 }, ground = { 0.2, 0.22, 0.32 }, key = { 0.25, 0.25, 0.3 }, key_dir = { -0.45, -0.8, -0.35 } },
	edges = { 0.35, 1.0, 0.25 },
	panel = {
		normal = { base = { 0.12, 0.15, 0.25 }, ink = { 0.4, 0.75, 1.0 }, warn = { 1.0, 0.4, 0.4 } },
		high_contrast = { base = { 0.05, 0.06, 0.1 }, ink = { 0.6, 0.9, 1 }, warn = { 1, 0.3, 0.25 } },
	},
	background = { top = { 0.1, 0.13, 0.22 }, bottom = { 0.04, 0.05, 0.1 } },
	tray_fill = { 0.15, 0.18, 0.3, 0.7 },
	ui = {
		face = { 0.14, 0.17, 0.28, 0.95 }, card = { 0.16, 0.2, 0.32, 0.97 }, shadow = { 0, 0, 0, 0.3 },
		ink = { 0.88, 0.92, 1, 1 }, soft_ink = { 0.6, 0.68, 0.82, 1 }, icon = { 0.75, 0.82, 0.95, 1 },
		accent = { 0.3, 0.65, 1.0, 1 }, track = { 0.25, 0.3, 0.45, 1 }, danger = { 1, 0.42, 0.4, 1 },
		solved = { 0.35, 0.9, 0.65, 1 }, cell_off = { 0.25, 0.28, 0.38, 1 }, dim = { 0, 0, 0.05, 0.5 },
		fade = { 0.06, 0.08, 0.14, 1 }, white = { 1, 1, 1, 1 },
	},
}

local active = looks.pastel
M.palettes.default = active.pieces
M.light, M.edges, M.panel = active.light, active.edges, active.panel
M.background, M.tray_fill, M.ui = active.background, active.tray_fill, active.ui

-- Converts a theme colour to a vmath.vector4 (alpha defaults to 1).
function M.vec(c)
	return vmath.vector4(c[1], c[2], c[3], c[4] or 1)
end

return M
