-- Parses a level definition (a solved arrangement drawn as ASCII layers) into an
-- immutable level. Everything after parsing may trust the level's shape.
local shape = require "core.shape"
local projection = require "core.projection"
local source_data = require "core.source"

local M = {}

local default_views = { "front", "side" }
local neighbors = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }

local function readLayers(layers)
	if type(layers) ~= "table" or #layers == 0 then
		return nil, "layers: expected a non-empty list of layers"
	end
	local depth = #layers[1]
	local width = layers[1][1] and #layers[1][1] or 0
	if depth == 0 or width == 0 then
		return nil, "layer 1: expected non-empty rows"
	end
	local cells_by_key = {}
	for y, layer in ipairs(layers) do
		if #layer ~= depth then
			return nil, ("layer %d: expected %d rows, got %d"):format(y, depth, #layer)
		end
		for r, row in ipairs(layer) do
			if #row ~= width then
				return nil, ("layer %d, row %d: expected %d columns, got %d"):format(y, r, width, #row)
			end
			for x = 1, width do
				local ch = row:sub(x, x)
				if ch:match("%a") then
					cells_by_key[ch] = cells_by_key[ch] or {}
					table.insert(cells_by_key[ch], { x - 1, y - 1, r - 1 })
				elseif ch ~= "." then
					return nil, ("layer %d, row %d: unexpected character '%s'"):format(y, r, ch)
				end
			end
		end
	end
	return cells_by_key, { width, #layers, depth }
end

local function isConnected(cells)
	local present = {}
	for _, c in ipairs(cells) do
		present[table.concat(c, ",")] = true
	end
	local seen, stack, count = { [table.concat(cells[1], ",")] = true }, { cells[1] }, 1
	while #stack > 0 do
		local c = table.remove(stack)
		for _, d in ipairs(neighbors) do
			local n = { c[1] + d[1], c[2] + d[2], c[3] + d[3] }
			local k = table.concat(n, ",")
			if present[k] and not seen[k] then
				seen[k] = true
				count = count + 1
				stack[#stack + 1] = n
			end
		end
	end
	return count == #cells
end

local function readPiece(key, spec)
	if type(spec) == "string" then
		spec = { color = spec }
	end
	if type(spec) ~= "table" or type(spec.color) ~= "string" then
		return nil, ("piece %s: expected a color name or { color = ... }"):format(key)
	end
	return { key = key, color = spec.color }
end

local function readViews(views)
	views = views or default_views
	for _, v in ipairs(views) do
		if not projection.axes[v] then
			return nil, ("views: unknown view '%s'"):format(tostring(v))
		end
	end
	return views
end

function M.parse(def, name)
	if type(def) ~= "table" then
		return nil, "level: expected a table"
	end
	local cells_by_key, size = readLayers(def.layers)
	if not cells_by_key then
		return nil, size
	end
	local views, views_err = readViews(def.views)
	if not views then
		return nil, views_err
	end

	local specs = def.pieces or {}
	for key in pairs(cells_by_key) do
		if specs[key] == nil then
			return nil, ("piece %s: drawn in layers but missing from pieces"):format(key)
		end
	end

	local keys = {}
	for key in pairs(specs) do
		keys[#keys + 1] = key
	end
	table.sort(keys)

	local pieces, solution, all_cells = {}, {}, {}
	for id, key in ipairs(keys) do
		local cells = cells_by_key[key]
		if not cells then
			return nil, ("piece %s: listed in pieces but not drawn in layers"):format(key)
		end
		if not isConnected(cells) then
			return nil, ("piece %s: cells are not face-connected"):format(key)
		end
		local piece, err = readPiece(key, specs[key])
		if not piece then
			return nil, err
		end
		piece.id = id
		local anchor
		piece.shape, anchor = shape.new(cells)
		pieces[id] = piece
		solution[id] = { cell = anchor, orient = 1 }
		for _, c in ipairs(cells) do
			all_cells[#all_cells + 1] = c
		end
	end

	local targets = {}
	for _, v in ipairs(views) do
		targets[v] = projection.project(size, all_cells, v)
	end

	local rules = def.rules or {}
	return {
		name = def.name or name or "untitled",
		size = size,
		pieces = pieces,
		solution = solution,
		views = views,
		targets = targets,
		rules = { use_all = rules.use_all ~= false },
	}
end

-- Evaluates level source in an empty environment, then parses it.
function M.load(source, name)
	local def, err = source_data.eval(source, name)
	if err then
		return nil, err
	end
	return M.parse(def, name)
end

return M
