-- The channels a wall folds along each ray. Each is a monoid (identity, combine) over plain
-- numbers, plus the piece property that sets it and that property's vocabulary. Channels
-- never interact: a wall cell holds one value per channel, and drawing them is the view's job.
-- A wall's operator is light, count or parity; it replaces light on that wall. Count and
-- parity have no piece property: every cube adds 1.
local bit = require "bit"

local M = {}

M.order = { "light", "count", "parity", "pattern" }
M.operators = { light = true, count = true, parity = true }

-- Light is an RGB bit set (R = 1, G = 2, B = 4). White light enters every ray; each cube
-- filters it, and an opaque cube (the default) blocks it entirely.
M.light = {
	identity = 7,
	combine = bit.band,
	key = "glass",
	default = 0,
	names = { red = 1, green = 2, blue = 4, yellow = 3, magenta = 5, cyan = 6 },
}

M.count = {
	identity = 0,
	combine = function(a, b) return a + b end,
	default = 1,
	monotone = true,
}

M.parity = {
	identity = 0,
	combine = bit.bxor,
	default = 1,
}

-- Stripes overlay: horizontal and vertical together make a grid.
M.pattern = {
	identity = 0,
	combine = bit.bor,
	key = "pattern",
	default = 0,
	names = { horizontal = 1, vertical = 2, grid = 3 },
}

return M
