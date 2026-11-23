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

-- The workshop wall: plaster from top to bottom of the screen, and the window light on it
-- (rgb, a: strength).
M.background = { top = { 0.74, 0.66, 0.57 }, bottom = { 0.5, 0.42, 0.35 }, window_light = { 1.0, 0.86, 0.62, 0.26 } }
-- The tray is the workbench's oak front edge.
M.tray_wood = { 0.6, 0.47, 0.35 }

-- The interface is paper and graphite: cards of the screens' paper with ink text, the main
-- action on paper washed with lamplight amber, shadows cast onto the dim wall.
M.ui = {
	face = { 0.95, 0.91, 0.84, 1 },
	card = { 0.95, 0.91, 0.84, 1 },
	primary = { 0.95, 0.8, 0.58, 1 },
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

-- Converts a theme colour to a vmath.vector4 (alpha defaults to 1).
function M.vec(c)
	return vmath.vector4(c[1], c[2], c[3], c[4] or 1)
end

return M
