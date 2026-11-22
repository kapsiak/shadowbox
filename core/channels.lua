-- The channels a wall folds along each ray. Each is a monoid (identity, combine) over plain
-- numbers, plus the piece property that sets it and that property's vocabulary. Channels
-- never interact: a wall cell holds one value per channel, and drawing them is the view's job.
local bit = require "bit"

local M = {}

M.order = { "light", "pattern" }

-- Light is an RGB bit set (R = 1, G = 2, B = 4). White light enters every ray; each cube
-- filters it, and an opaque cube (the default) blocks it entirely.
M.light = {
	identity = 7,
	combine = bit.band,
	key = "glass",
	default = 0,
	names = { red = 1, green = 2, blue = 4, yellow = 3, magenta = 5, cyan = 6 },
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
