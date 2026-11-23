-- Parses a level definition (a solved arrangement drawn as ASCII layers) into an
-- immutable level. Everything after parsing may trust the level's shape.
local shape = require "core.shape"
local projection = require "core.projection"
local channels = require "core.channels"
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

local allowed_keys = { color = true }
for _, name in ipairs(channels.order) do
	if channels[name].key then
		allowed_keys[channels[name].key] = true
	end
end

local function readValue(key, spec)
	local value = {}
	for _, name in ipairs(channels.order) do
		local channel = channels[name]
		local word = channel.key and spec[channel.key]
		value[name] = channel.default
		if word ~= nil then
			value[name] = channel.names[word]
			if not value[name] then
				return nil, ("piece %s: unknown %s '%s'"):format(key, channel.key, tostring(word))
			end
		end
	end
	return value
end

-- A piece is a colour name, or a table of properties; glass pieces need no colour.
local function readPiece(key, spec)
	if type(spec) == "string" then
		spec = { color = spec }
	end
	if type(spec) ~= "table" then
		return nil, ("piece %s: expected a color name or a table of properties"):format(key)
	end
	for k in pairs(spec) do
		if not allowed_keys[k] then
			return nil, ("piece %s: unknown property '%s'"):format(key, tostring(k))
		end
	end
	local value, err = readValue(key, spec)
	if not value then
		return nil, err
	end
	if spec.color ~= nil and type(spec.color) ~= "string" then
		return nil, ("piece %s: color must be a name"):format(key)
	end
	if spec.color == nil and value.light == channels.light.default then
		return nil, ("piece %s: opaque pieces need a color"):format(key)
	end
	return { key = key, color = spec.color, value = value }
end

-- A wall folds its operator, then any piece property channel once a piece sets it.
local function usedChannels(pieces, operator)
	local names = { operator }
	for _, name in ipairs(channels.order) do
		local used = false
		for _, piece in ipairs(pieces) do
			used = used or (channels[name].key and name ~= "light" and piece.value[name] ~= channels[name].default)
		end
		if used then
			names[#names + 1] = name
		end
	end
	return names
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

-- Each view's operator: light unless the level names another.
local function readWalls(walls, views)
	walls = walls or {}
	local out, listed = {}, {}
	for _, v in ipairs(views) do
		listed[v] = true
		out[v] = walls[v] or "light"
		if not channels.operators[out[v]] then
			return nil, ("walls: unknown operator '%s'"):format(tostring(out[v]))
		end
	end
	for v in pairs(walls) do
		if not listed[v] then
			return nil, ("walls: '%s' is not a view"):format(tostring(v))
		end
	end
	return out
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
	local walls, walls_err = readWalls(def.walls, views)
	if not walls then
		return nil, walls_err
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

	local pieces, solution, items = {}, {}, {}
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
		piece.shape = shape.new(shape.rest(cells))
		pieces[id] = piece
		solution[id] = shape.poseOf(piece.shape, cells)
		items[id] = { cells = cells, value = piece.value }
	end

	local names, targets = {}, {}
	for _, v in ipairs(views) do
		names[v] = usedChannels(pieces, walls[v])
		targets[v] = projection.project(size, v, names[v], items)
	end

	local rules = def.rules or {}
	return {
		name = def.name or name or "untitled",
		size = size,
		pieces = pieces,
		solution = solution,
		views = views,
		walls = walls,
		channels = names,
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
