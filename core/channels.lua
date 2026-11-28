local hot = require "core.hot"
local bit = require "bit"

local M = {}

M.order = { "light", "count", "parity", "pattern" }
M.operators = { light = true, count = true, parity = true }

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

M.pattern = {
	identity = 0,
	combine = bit.bor,
	key = "pattern",
	default = 0,
	names = { horizontal = 1, vertical = 2, grid = 3 },
}

return hot(..., M)
