local hot = require "core.hot"
local M = {}

M.palettes = {
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
	coral = { 0.93, 0.33, 0.27 }, sky = { 0.2, 0.5, 0.9 }, mint = { 0.2, 0.72, 0.45 },
	butter = { 0.98, 0.78, 0.16 }, lilac = { 0.58, 0.4, 0.85 }, peach = { 0.98, 0.56, 0.2 },
	sage = { 0.55, 0.74, 0.25 }, rose = { 0.94, 0.42, 0.62 }, teal = { 0.1, 0.68, 0.7 },
	slate = { 0.4, 0.45, 0.55 },
}

M.light = {
	sky = { 0.8, 0.8, 0.83 },
	ground = { 0.5, 0.5, 0.53 },
	key = { 0.55, 0.55, 0.53 },
	key_dir = { -0.6, -0.6, -0.5 },
}

M.finish = { bevel = 0.1, gloss = 0.55, fill = 0.35 }

M.panel = {
	normal = { surface = { 0.98, 0.98, 0.97 }, shadow = { 0.3, 0.31, 0.35 }, line = { 0.15, 0.15, 0.17 }, frame = { 0.8, 0.8, 0.81 } },
	high_contrast = { surface = { 1, 0.99, 0.97 }, shadow = { 0.16, 0.18, 0.26 }, line = { 0.08, 0.08, 0.09 }, frame = { 0.5, 0.5, 0.52 } },
}

M.background = {
	top = { 0.85, 0.845, 0.83 }, bottom = { 0.75, 0.745, 0.73 },
	glow = { 1, 1, 1, 0.04 }, lattice = { 0.6, 0.6, 0.6, 0.22 },
}
M.tray = { color = { 0.91, 0.905, 0.89 }, lip = { 0.66, 0.655, 0.64, 10 }, chamfer = 22 }

M.ui = {
	lift = 0.09,
	face = { 1, 1, 1, 1 }, card = { 0.89, 0.885, 0.87, 1 }, page = { 0.98, 0.98, 0.97, 1 },
	primary = { 0.93, 0.33, 0.27, 1 }, primary_ink = { 1, 1, 1, 1 }, primary_shadow = { 0.68, 0.2, 0.17, 1 },
	shadow = { 0.66, 0.655, 0.64, 1 },
	ink = { 0.13, 0.13, 0.15, 1 }, soft_ink = { 0.42, 0.42, 0.45, 1 }, icon = { 0.15, 0.15, 0.17, 1 },
	accent = { 0.93, 0.33, 0.27, 1 }, track = { 0.79, 0.785, 0.77, 1 },
	danger = { 0.85, 0.25, 0.2, 1 }, solved = { 0.2, 0.62, 0.38, 1 }, cell_off = { 0.86, 0.85, 0.83, 1 },
	dim = { 0.88, 0.875, 0.86, 0.62 }, fade = { 0.85, 0.845, 0.83, 1 },
	white = { 1, 1, 1, 1 },
}

function M.vec(c)
	return vmath.vector4(c[1], c[2], c[3], c[4] or 1)
end

return hot(..., M)
