-- Loads the level packs bundled under /levels (custom_resources): an index (levels/index.lua, or
-- levels/demo.lua in demo builds) lists the packs in order and optionally caps each pack's
-- levels (`limit = { [pack] = n }`); each pack's pack.lua lists its levels. levels/rules holds
-- the rule cards. Every loader takes `read` (resource path -> text or nil), sys.load_resource
-- by default, so tools/demo_resources.lua can load from disk.
local hot = require "core.hot"
local level = require "core.level"
local source_data = require "core.source"
local lessons = require "game.lessons"

local M = {}

M.INDEX = "/levels/index.lua"

local function defaultRead(path)
	return sys.load_resource(path)
end

local function evalResource(read, path)
	local source = read(path)
	if not source then
		return nil, path .. ": not found"
	end
	local value, err = source_data.eval(source, path)
	if err then
		return nil, err
	end
	return value
end

local function loadPack(read, id, limit)
	local manifest_path = ("/levels/%s/pack.lua"):format(id)
	local manifest, err = evalResource(read, manifest_path)
	if not manifest then
		return nil, err
	end
	local pack = { id = id, title = manifest.title or id, intro = manifest.intro, accent = manifest.accent,
		levels = {}, keys = {}, paths = {} }
	for i = 1, math.min(#manifest.levels, limit or math.huge) do
		local name = manifest.levels[i]
		local path = ("/levels/%s/%s.lua"):format(id, name)
		local source = read(path)
		if not source then
			return nil, path .. ": not found"
		end
		local lvl, level_err = level.load(source, path)
		if not lvl then
			return nil, level_err
		end
		pack.levels[i] = lvl
		pack.keys[i] = id .. "/" .. name
		pack.paths[i] = path
	end
	return pack
end

-- The ids of the rule cards the catalog's levels use, in teaching order.
function M.ruleIds(catalog)
	local used = {}
	for _, pack in ipairs(catalog.packs) do
		for _, lvl in ipairs(pack.levels) do
			for _, id in ipairs(lessons.uses(lvl)) do
				used[id] = true
			end
		end
	end
	local ids = {}
	for _, id in ipairs(lessons.order) do
		if used[id] then
			ids[#ids + 1] = id
		end
	end
	return ids
end

function M.rulePath(id)
	return ("/levels/rules/%s.lua"):format(id)
end

-- The rule cards the catalog uses (game/lessons), each { id, title, text, touch, level } with
-- its scene as a level; `touch` is the text for touch screens where it differs.
-- Returns { [id] = card }, or nil and the first error.
function M.loadRules(catalog, read)
	read = read or defaultRead
	local cards = {}
	for _, id in ipairs(M.ruleIds(catalog)) do
		local path = M.rulePath(id)
		local def, err = evalResource(read, path)
		if not def then
			return nil, err
		end
		local lvl, level_err = level.parse(def, path)
		if not lvl then
			return nil, level_err
		end
		cards[id] = { id = id, title = def.title or id, text = def.text or "", touch = def.touch, level = lvl }
	end
	return cards
end

M.SHOWCASE = "/levels/showcase.lua"

-- The level shown as a sculpture on the main menu.
function M.loadShowcase(read)
	local source = (read or defaultRead)(M.SHOWCASE)
	return source and level.load(source, M.SHOWCASE)
end

-- Returns { packs = { { id, title, intro, levels, keys, paths } } }, or nil and the first error.
function M.load(index_path, read)
	read = read or defaultRead
	local index, err = evalResource(read, index_path or M.INDEX)
	if not index then
		return nil, err
	end
	local limits = index.limit or {}
	local catalog = { packs = {} }
	for i, id in ipairs(index.packs) do
		local pack, pack_err = loadPack(read, id, limits[id])
		if not pack then
			return nil, pack_err
		end
		catalog.packs[i] = pack
	end
	return catalog
end

return hot(..., M)
