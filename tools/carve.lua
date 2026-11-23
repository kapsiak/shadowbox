-- Usage (from the project root):
--   luajit tools/carve.lua [-k min-max] [-t tries] [-o shown] [-n limit] [-r seed]
--                          [-g colour,... [-q opaque] [-m mixes]] sculpture.lua
-- Cuts a sculpture (a level file whose drawn cells may all share one letter; `pieces` is
-- ignored; `views`, `walls` and `rules` carry over) into random pieces of min..max cubes, profiles each cut with the solver and prints
-- the best as level files: fewest solutions first, then the most search.
-- With -g, all but `opaque` pieces become glass, each listed colour used once before repeats;
-- -m keeps only cuts with at least that many wall cells lit by a mix (a colour no piece has).
package.path = "./?.lua;./tools/?.lua;" .. package.path

local level = require "core.level"
local source_data = require "core.source"
local solver = require "solver"
local channels = require "core.channels"

local PALETTE = { "coral", "sky", "mint", "butter", "lilac", "peach", "teal", "rose", "sage" }
local NEIGHBORS = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }

local function key(c)
	return c[1] .. "," .. c[2] .. "," .. c[3]
end

local function readSculpture(path)
	local f = assert(io.open(path, "r"))
	local def, err = source_data.eval(f:read("*a"), path)
	f:close()
	assert(def, err)
	local cells, at = {}, {}
	for y, layer in ipairs(def.layers) do
		for z, row in ipairs(layer) do
			for x = 1, #row do
				if row:sub(x, x):match("%a") then
					local c = { x - 1, y - 1, z - 1 }
					cells[#cells + 1] = c
					at[key(c)] = #cells
				end
			end
		end
	end
	local size = { #def.layers[1][1], #def.layers, #def.layers[1] }
	return def, cells, at, size
end

local function neighbours(cells, at, i)
	local out, c = {}, cells[i]
	for _, d in ipairs(NEIGHBORS) do
		local j = at[key({ c[1] + d[1], c[2] + d[2], c[3] + d[3] })]
		if j then
			out[#out + 1] = j
		end
	end
	return out
end

-- Grows pieces from the most cornered free cell; nil if a piece cannot reach `min` cubes.
local function cut(cells, at, min, max)
	local owner, count = {}, 0
	local free = function(j)
		return not owner[j]
	end
	while true do
		local start, fewest
		for i in ipairs(cells) do
			if free(i) then
				local n = 0
				for _, j in ipairs(neighbours(cells, at, i)) do
					n = n + (free(j) and 1 or 0)
				end
				if not fewest or n < fewest or (n == fewest and math.random() < 0.5) then
					start, fewest = i, n
				end
			end
		end
		if not start then
			return owner, count
		end
		count = count + 1
		owner[start] = count
		local members, target = { start }, math.random(min, max)
		while #members < target do
			local frontier = {}
			for _, m in ipairs(members) do
				for _, j in ipairs(neighbours(cells, at, m)) do
					if free(j) then
						frontier[#frontier + 1] = j
					end
				end
			end
			if #frontier == 0 then
				break
			end
			local j = frontier[math.random(#frontier)]
			owner[j] = count
			members[#members + 1] = j
		end
		if #members < min then
			return nil
		end
	end
end

-- Neighbouring pieces get different colours, preferring the least used.
local function colours(cells, at, owner, count)
	local touching = {}
	for p = 1, count do
		touching[p] = {}
	end
	for i in ipairs(cells) do
		for _, j in ipairs(neighbours(cells, at, i)) do
			if owner[i] ~= owner[j] then
				touching[owner[i]][owner[j]] = true
			end
		end
	end
	local chosen, used = {}, {}
	for p = 1, count do
		local best
		for _, name in ipairs(PALETTE) do
			local clash = false
			for q in pairs(touching[p]) do
				clash = clash or chosen[q] == name
			end
			if not clash and (not best or (used[name] or 0) < (used[best] or 0)) then
				best = name
			end
		end
		chosen[p] = best or PALETTE[1]
		used[chosen[p]] = (used[chosen[p]] or 0) + 1
	end
	return chosen
end

local function shuffled(n)
	local out = {}
	for i = 1, n do
		out[i] = i
	end
	for i = n, 2, -1 do
		local j = math.random(i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- Opaque pieces get colour names; the rest become glass from `glass`, each colour once first.
local function materials(names, count, glass, opaque)
	if not glass then
		return names
	end
	local order, out = shuffled(count), {}
	opaque = math.min(opaque, count - 1)
	for n, p in ipairs(order) do
		if n <= opaque then
			out[p] = names[p]
		else
			local g = n - opaque
			out[p] = { glass = glass[g] or glass[math.random(#glass)] }
		end
	end
	return out
end

local function mixes(lvl, glass)
	local plain = { [0] = true, [7] = true }
	for _, name in ipairs(glass or {}) do
		plain[channels.light.names[name]] = true
	end
	local n = 0
	for _, target in pairs(lvl.targets) do
		for _, v in ipairs(target.layers.light or {}) do
			n = n + (plain[v] and 0 or 1)
		end
	end
	return n
end

local function toLevel(def, cells, at, size, owner, count, glass, opaque)
	local letters, layers = {}, {}
	for p = 1, count do
		letters[p] = string.char(64 + p)
	end
	for y = 1, size[2] do
		layers[y] = {}
		for z = 1, size[3] do
			local row = {}
			for x = 1, size[1] do
				local i = at[key({ x - 1, y - 1, z - 1 })]
				row[x] = i and letters[owner[i]] or "."
			end
			layers[y][z] = table.concat(row)
		end
	end
	local pieces = {}
	for p, material in ipairs(materials(colours(cells, at, owner, count), count, glass, opaque)) do
		pieces[letters[p]] = material
	end
	return { name = def.name, views = def.views, walls = def.walls, rules = def.rules, pieces = pieces, layers = layers }
end

local function format(def)
	local out = { "return {", ('\tname = "%s",'):format(def.name or "Untitled") }
	if def.views then
		out[#out + 1] = ('\tviews = { "%s" },'):format(table.concat(def.views, '", "'))
	end
	if def.walls then
		local parts = {}
		for _, v in ipairs({ "front", "side", "top" }) do
			if def.walls[v] then
				parts[#parts + 1] = ('%s = "%s"'):format(v, def.walls[v])
			end
		end
		out[#out + 1] = "\twalls = { " .. table.concat(parts, ", ") .. " },"
	end
	if def.rules and def.rules.use_all == false then
		out[#out + 1] = "\trules = { use_all = false },"
	end
	local keys, parts = {}, {}
	for k in pairs(def.pieces) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for i, k in ipairs(keys) do
		local m = def.pieces[k]
		parts[i] = type(m) == "table" and ('%s = { glass = "%s" }'):format(k, m.glass) or ('%s = "%s"'):format(k, m)
	end
	out[#out + 1] = "\tpieces = { " .. table.concat(parts, ", ") .. " },"
	out[#out + 1] = "\tlayers = {"
	for _, layer in ipairs(def.layers) do
		local rows = {}
		for i, row in ipairs(layer) do
			rows[i] = '"' .. row .. '"'
		end
		out[#out + 1] = "\t\t{ " .. table.concat(rows, ",\n\t\t  ") .. " },"
	end
	out[#out + 1] = "\t},"
	out[#out + 1] = "}"
	return table.concat(out, "\n")
end

local opts, path = { min = 3, max = 5, tries = 300, shown = 3, limit = 50, seed = os.time(), opaque = 0, mixes = 0 }, nil
local i = 1
while i <= #arg do
	local a = arg[i]
	if a == "-k" then
		i = i + 1
		opts.min, opts.max = arg[i]:match("(%d+)-(%d+)")
		opts.min, opts.max = tonumber(opts.min), tonumber(opts.max)
	elseif a == "-g" then
		i = i + 1
		opts.glass = {}
		for name in arg[i]:gmatch("[^,]+") do
			assert(channels.light.names[name], "unknown glass colour " .. name)
			opts.glass[#opts.glass + 1] = name
		end
	elseif a == "-t" or a == "-o" or a == "-n" or a == "-r" or a == "-q" or a == "-m" then
		i = i + 1
		local field = { ["-t"] = "tries", ["-o"] = "shown", ["-n"] = "limit", ["-r"] = "seed", ["-q"] = "opaque", ["-m"] = "mixes" }
		opts[field[a]] = tonumber(arg[i])
	else
		path = a
	end
	i = i + 1
end
math.randomseed(opts.seed)

local def, cells, at, size = readSculpture(path)
local results, seen = {}, {}
for _ = 1, opts.tries do
	local owner, count = cut(cells, at, opts.min, opts.max)
	if owner then
		local lvl_def = toLevel(def, cells, at, size, owner, count, opts.glass, opts.opaque)
		local text = format(lvl_def)
		local lvl = level.parse(lvl_def)
		local mixed = lvl and mixes(lvl, opts.glass) or 0
		if lvl and not seen[text] and mixed >= opts.mixes then
			seen[text] = true
			local report = solver.analyse(lvl, { limit = opts.limit })
			local turns = 0
			for _, p in ipairs(report.pieces) do
				turns = turns + (p.must_turn and 1 or 0)
			end
			results[#results + 1] = { text = text, report = report, pieces = count, turns = turns, mixed = mixed }
		end
	end
end
table.sort(results, function(a, b)
	if a.report.solutions ~= b.report.solutions then
		return a.report.solutions < b.report.solutions
	end
	return a.report.nodes > b.report.nodes
end)
print(("%d distinct cuts of %d cubes (seed %d)"):format(#results, #cells, opts.seed))
for r = 1, math.min(opts.shown, #results) do
	local res = results[r]
	print(("\n-- %d pieces, %d must turn, solutions %s, nodes %d, mixed cells %d"):format(res.pieces, res.turns,
		res.report.solutions .. (res.report.capped and "+" or ""), res.report.nodes, res.mixed))
	print(res.text)
end
