-- Loads the level packs bundled under /levels (custom_resources): levels/index.lua lists the
-- packs in order, and each pack's pack.lua lists its levels. levels/rules holds the rule cards.
local hot = require "core.hot"
local level = require "core.level"
local source_data = require "core.source"
local lessons = require "game.lessons"

local M = {}

local function evalResource(path)
	local source = sys.load_resource(path)
	if not source then
		return nil, path .. ": not found"
	end
	local value, err = source_data.eval(source, path)
	if err then
		return nil, err
	end
	return value
end

local function loadPack(id)
	local manifest_path = ("/levels/%s/pack.lua"):format(id)
	local manifest, err = evalResource(manifest_path)
	if not manifest then
		return nil, err
	end
	local pack = { id = id, title = manifest.title or id, intro = manifest.intro, accent = manifest.accent,
		levels = {}, keys = {} }
	for i, name in ipairs(manifest.levels) do
		local path = ("/levels/%s/%s.lua"):format(id, name)
		local source = sys.load_resource(path)
		if not source then
			return nil, path .. ": not found"
		end
		local lvl, level_err = level.load(source, path)
		if not lvl then
			return nil, level_err
		end
		pack.levels[i] = lvl
		pack.keys[i] = id .. "/" .. name
	end
	return pack
end

-- The rule cards (game/lessons), each { id, title, text, touch, level } with its scene as a
-- level; `touch` is the text for touch screens where it differs.
-- Returns { [id] = card }, or nil and the first error.
function M.loadRules()
	local cards = {}
	for _, id in ipairs(lessons.order) do
		local path = ("/levels/rules/%s.lua"):format(id)
		local def, err = evalResource(path)
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

-- The level shown as a sculpture on the main menu.
function M.loadShowcase()
	local path = "/levels/showcase.lua"
	local source = sys.load_resource(path)
	return source and level.load(source, path)
end

-- Returns { packs = { { id, title, intro, levels, keys } } }, or nil and the first error.
function M.load()
	local index, err = evalResource("/levels/index.lua")
	if not index then
		return nil, err
	end
	local catalog = { packs = {} }
	for i, id in ipairs(index.packs) do
		local pack, pack_err = loadPack(id)
		if not pack then
			return nil, pack_err
		end
		catalog.packs[i] = pack
	end
	return catalog
end

return hot(..., M)
