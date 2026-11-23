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

M.palettes.default = {
	coral = { 0.85, 0.42, 0.32 }, sky = { 0.36, 0.58, 0.78 }, mint = { 0.42, 0.68, 0.52 },
	butter = { 0.93, 0.74, 0.32 }, lilac = { 0.6, 0.48, 0.72 }, peach = { 0.92, 0.6, 0.4 },
	sage = { 0.58, 0.66, 0.42 }, rose = { 0.82, 0.46, 0.56 }, teal = { 0.25, 0.58, 0.6 },
	slate = { 0.45, 0.48, 0.55 },
}

M.light = {
	sky = { 0.7, 0.68, 0.68 },
	ground = { 0.56, 0.47, 0.4 },
	key = { 0.6, 0.52, 0.4 },
	key_dir = { -0.6, -0.6, -0.5 },
}

-- Lacquered wood: bevel width (in faces), gloss of the clear coat, darkening by the grain, and the
-- lamplight from the viewer's side (relative to the key light).
M.finish = { bevel = 0.07, gloss = 0.35, grain = 0.1, fill = 0.35 }

-- Projection panels: paper, the shadow cast on it, the pencil of the target sketch, the frame.
M.panel = {
	normal = { paper = { 0.95, 0.91, 0.84 }, shadow = { 0.4, 0.43, 0.53 }, pencil = { 0.34, 0.31, 0.3 }, frame = { 0.72, 0.58, 0.44 } },
	high_contrast = { paper = { 1, 0.99, 0.97 }, shadow = { 0.16, 0.18, 0.26 }, pencil = { 0.08, 0.06, 0.06 }, frame = { 0.5, 0.36, 0.24 } },
}

-- The wall behind the board, from the top to the bottom of the screen; the window light on it,
-- a glow behind the board, an overhead spotlight on it and a faint isometric lattice (rgb, a: strength).
M.background = {
	top = { 0.74, 0.66, 0.57 }, bottom = { 0.5, 0.42, 0.35 },
	window_light = { 1.0, 0.86, 0.62, 0.26 }, glow = { 1.0, 0.95, 0.85, 0.05 }, stage = { 1, 1, 1, 0 },
	lattice = { 0, 0, 0, 0 },
}
-- The tray is the workbench's oak front edge: its colour, the strength of its grain, an optional
-- solid lip under it (rgb, a: height in pixels; 0 casts a soft shadow instead) and its corners.
M.tray = { color = { 0.6, 0.47, 0.35 }, grain = 1, lip = { 0, 0, 0, 0 }, radius = 10, chamfer = 0 }

-- The interface is paper and graphite: cards of the screens' paper with ink text, the main
-- action on paper washed with lamplight amber, shadows cast onto the dim wall.
M.ui = {
	-- the atlas images of a card and its shadow; how far the shadow drops and spreads (in card
	-- heights) and whether a pressed card sinks onto it rather than shrinking; the level label font
	card_image = "button", card_shadow = "button_shadow",
	lift = { drop = 0.05, spread = 0.1, sink = false }, label_font = "hand", page_tilt = 0.4,
	face = { 0.95, 0.91, 0.84, 1 },
	card = { 0.95, 0.91, 0.84, 1 },
	page = { 0.95, 0.91, 0.84, 1 },
	primary = { 0.95, 0.8, 0.58, 1 },
	primary_ink = { 0.25, 0.2, 0.18, 1 },
	primary_shadow = { 0.12, 0.08, 0.05, 0.38 },
	shadow = { 0.12, 0.08, 0.05, 0.38 },
	ink = { 0.25, 0.2, 0.18, 1 },
	soft_ink = { 0.42, 0.36, 0.32, 1 },
	icon = { 0.3, 0.25, 0.22, 1 },
	accent = { 0.7, 0.42, 0.29, 1 },
	track = { 0.84, 0.78, 0.69, 1 },
	danger = { 0.7, 0.28, 0.22, 1 },
	solved = { 0.36, 0.5, 0.34, 1 },
	cell_off = { 0.84, 0.78, 0.69, 1 },
	dim = { 0.12, 0.08, 0.05, 0.45 },
	fade = { 0.16, 0.12, 0.09, 1 },
	white = { 1, 1, 1, 1 },
}

-- Variants override parts of the look above (the workshop). `[theme] variant` in game.project
-- picks one at startup.
local variants = {
	workshop = {},
	-- A dark, neutral gallery: the board is lit like an exhibit, the screens are neutral so colour
	-- means only puzzle data, and the interface is quiet light on dark with the light as its accent.
	gallery = {
		light = { sky = { 0.72, 0.73, 0.76 }, ground = { 0.4, 0.4, 0.43 }, key = { 0.62, 0.61, 0.58 } },
		finish = { grain = 0, gloss = 0.4 },
		panel = {
			normal = { paper = { 0.95, 0.95, 0.94 }, shadow = { 0.36, 0.37, 0.4 }, pencil = { 0.2, 0.2, 0.22 }, frame = { 0.58, 0.58, 0.6 } },
		},
		background = {
			top = { 0.15, 0.155, 0.17 }, bottom = { 0.07, 0.07, 0.08 },
			window_light = { 1, 1, 1, 0 }, glow = { 0.85, 0.85, 0.9, 0.04 }, stage = { 1, 0.95, 0.86, 0.16 },
		},
		tray = { color = { 0.12, 0.12, 0.135 }, grain = 0 },
		ui = {
			card_image = "tile", card_shadow = "tile_shadow",
			face = { 0.24, 0.24, 0.27, 1 }, card = { 0.17, 0.17, 0.19, 1 }, page = { 0.17, 0.17, 0.19, 1 },
			primary = { 0.96, 0.93, 0.86, 1 }, primary_ink = { 0.12, 0.12, 0.13, 1 },
			primary_shadow = { 0, 0, 0, 0.5 },
			shadow = { 0, 0, 0, 0.5 },
			ink = { 0.92, 0.92, 0.9, 1 }, soft_ink = { 0.62, 0.62, 0.65, 1 }, icon = { 0.86, 0.86, 0.85, 1 },
			accent = { 0.95, 0.85, 0.62, 1 }, track = { 0.3, 0.3, 0.33, 1 },
			danger = { 0.9, 0.45, 0.4, 1 }, solved = { 0.6, 0.78, 0.58, 1 }, cell_off = { 0.3, 0.3, 0.33, 1 },
			dim = { 0, 0, 0, 0.55 }, fade = { 0.04, 0.04, 0.05, 1 },
		},
	},
	-- Geometric, satisfying, clever: a light, precise world of solid shapes. Glossy moulded
	-- pieces in toy colours, crisp white screens, flat keys on a solid lip, one bold accent.
	geometric = {
		palettes = {
			default = {
				coral = { 0.93, 0.33, 0.27 }, sky = { 0.2, 0.5, 0.9 }, mint = { 0.2, 0.72, 0.45 },
				butter = { 0.98, 0.78, 0.16 }, lilac = { 0.58, 0.4, 0.85 }, peach = { 0.98, 0.56, 0.2 },
				sage = { 0.55, 0.74, 0.25 }, rose = { 0.94, 0.42, 0.62 }, teal = { 0.1, 0.68, 0.7 },
				slate = { 0.4, 0.45, 0.55 },
			},
		},
		light = { sky = { 0.8, 0.8, 0.83 }, ground = { 0.5, 0.5, 0.53 }, key = { 0.55, 0.55, 0.53 } },
		finish = { bevel = 0.1, gloss = 0.55, grain = 0 },
		panel = {
			normal = { paper = { 0.98, 0.98, 0.97 }, shadow = { 0.3, 0.31, 0.35 }, pencil = { 0.15, 0.15, 0.17 }, frame = { 0.8, 0.8, 0.81 } },
		},
		background = {
			top = { 0.85, 0.845, 0.83 }, bottom = { 0.75, 0.745, 0.73 },
			window_light = { 1, 1, 1, 0 }, glow = { 1, 1, 1, 0.04 }, stage = { 1, 1, 1, 0 },
			lattice = { 0.6, 0.6, 0.6, 0.22 },
		},
		tray = { color = { 0.91, 0.905, 0.89 }, grain = 0, lip = { 0.66, 0.655, 0.64, 10 }, radius = 0, chamfer = 22 },
		ui = {
			card_image = "key", card_shadow = "key",
			lift = { drop = 0.09, spread = 0, sink = true }, label_font = "body", page_tilt = 0,
			face = { 1, 1, 1, 1 }, card = { 0.89, 0.885, 0.87, 1 }, page = { 0.98, 0.98, 0.97, 1 },
			primary = { 0.93, 0.33, 0.27, 1 }, primary_ink = { 1, 1, 1, 1 }, primary_shadow = { 0.68, 0.2, 0.17, 1 },
			shadow = { 0.66, 0.655, 0.64, 1 },
			ink = { 0.13, 0.13, 0.15, 1 }, soft_ink = { 0.42, 0.42, 0.45, 1 }, icon = { 0.15, 0.15, 0.17, 1 },
			accent = { 0.93, 0.33, 0.27, 1 }, track = { 0.79, 0.785, 0.77, 1 },
			danger = { 0.85, 0.25, 0.2, 1 }, solved = { 0.2, 0.62, 0.38, 1 }, cell_off = { 0.86, 0.85, 0.83, 1 },
			dim = { 0.88, 0.875, 0.86, 0.62 }, fade = { 0.85, 0.845, 0.83, 1 },
		},
	},
}

-- Tables merge key by key; colours (lists) are replaced whole.
local function merge(into, from)
	for k, v in pairs(from) do
		if type(v) == "table" and v[1] == nil and type(into[k]) == "table" then
			merge(into[k], v)
		else
			into[k] = v
		end
	end
end

M.variant = sys.get_config_string("theme.variant", "workshop")
merge(M, assert(variants[M.variant], "unknown theme variant " .. M.variant))

-- Converts a theme colour to a vmath.vector4 (alpha defaults to 1).
function M.vec(c)
	return vmath.vector4(c[1], c[2], c[3], c[4] or 1)
end

return M
