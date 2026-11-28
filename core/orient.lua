-- The 24 rotations of a cube, addressed by index. An orientation is a number
-- in 1..24, so an invalid rotation cannot be expressed.
local hot = require "core.hot"
local M = {}

local function mul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s = s + a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end

local function key(m)
	return table.concat(m, ",")
end

local quarter_turns = {
	{ 1, 0, 0, 0, 0, -1, 0, 1, 0 },
	{ 0, 0, 1, 0, 1, 0, -1, 0, 0 },
	{ 0, -1, 0, 1, 0, 0, 0, 0, 1 },
}

local matrices = { { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }
local index_of = { [key(matrices[1])] = 1 }

local frontier = 1
while frontier <= #matrices do
	for _, q in ipairs(quarter_turns) do
		local m = mul(q, matrices[frontier])
		if not index_of[key(m)] then
			matrices[#matrices + 1] = m
			index_of[key(m)] = #matrices
		end
	end
	frontier = frontier + 1
end
assert(#matrices == 24)

local turns = {}
for n, m in ipairs(matrices) do
	turns[n] = {}
	for axis, q in ipairs(quarter_turns) do
		local back = mul(q, mul(q, q))
		turns[n][axis] = { [1] = index_of[key(mul(q, m))], [-1] = index_of[key(mul(back, m))] }
	end
end

M.count = 24
M.identity = 1

function M.apply(n, v)
	local m = matrices[n]
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end

-- The rotation matrix of orientation n, row-major (3x3 as 9 numbers); not to be changed.
function M.matrix(n)
	return matrices[n]
end

-- The orientation nearest the rotation matrix m (row-major): the one the least turn away.
function M.nearest(m)
	local best, best_trace = 1, -math.huge
	for n, r in ipairs(matrices) do
		local trace = 0
		for i = 1, 9 do
			trace = trace + r[i] * m[i]
		end
		if trace > best_trace then
			best, best_trace = n, trace
		end
	end
	return best
end

-- Rotates orientation n a quarter turn about a world axis (1=x, 2=y, 3=z), dir = 1 or -1.
function M.turn(n, axis, dir)
	return turns[n][axis][dir]
end

return hot(..., M)
