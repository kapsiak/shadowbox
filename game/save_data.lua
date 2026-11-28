-- Pure Lua. Levels are named by key ("pack/name"), never by position, so adding or reordering
-- levels keeps progress. A saved board carries a fingerprint of its level and is dropped if
-- the level has changed since.
local hot = require "core.hot"
local progress = require "game.progress"
local settings = require "game.settings"
local play = require "game.play"
local shape = require "core.shape"
local orient = require "core.orient"
local channels = require "core.channels"
local lessons = require "game.lessons"

local M = {}

M.VERSION = 2

local function levelIndex(catalog)
	local index = {}
	for p, pack in ipairs(catalog.packs) do
		for l, key in ipairs(pack.keys) do
			index[key] = { pack = p, index = l, level = pack.levels[l] }
		end
	end
	return index
end

local fingerprints = setmetatable({}, { __mode = "k" })

function M.fingerprint(level)
	if fingerprints[level] then
		return fingerprints[level]
	end
	local parts = { table.concat(level.size, ",") }
	for id, piece in ipairs(level.pieces) do
		parts[#parts + 1] = piece.color or ""
		for _, name in ipairs(channels.order) do
			if channels[name].key then
				parts[#parts + 1] = piece.value[name]
			end
		end
		local pose = level.solution[id]
		parts[#parts + 1] = table.concat(pose.cell, ",") .. "@" .. pose.orient
		for _, c in ipairs(shape.cellsAt(piece.shape, pose)) do
			parts[#parts + 1] = table.concat(c, ",")
		end
	end
	for _, v in ipairs(level.views) do
		if level.walls[v] ~= "light" then
			parts[#parts + 1] = v .. "=" .. level.walls[v]
		end
	end
	local text, hash = table.concat(parts, ";"), 5381
	for i = 1, #text do
		hash = (hash * 33 + text:byte(i)) % 4294967296
	end
	fingerprints[level] = hash
	return hash
end

local function isInteger(n)
	return type(n) == "number" and n == math.floor(n)
end

local function isPose(pose)
	if type(pose) ~= "table" or type(pose.cell) ~= "table" then
		return false
	end
	local c = pose.cell
	return isInteger(c[1]) and isInteger(c[2]) and isInteger(c[3])
		and isInteger(pose.orient) and pose.orient >= 1 and pose.orient <= orient.count
end

local function cleanPoses(level, poses)
	local formed = {}
	for id, pose in pairs(type(poses) == "table" and poses or {}) do
		if level.pieces[id] and isPose(pose) then
			formed[id] = { cell = { pose.cell[1], pose.cell[2], pose.cell[3] }, orient = pose.orient }
		end
	end
	return play.fitting(level, formed).poses
end

local migrations = {}

migrations[1] = function(data, index)
	local saved = type(data.progress) == "table" and data.progress or {}
	local seen = {}
	for key, value in pairs(type(saved.solved) == "table" and saved.solved or {}) do
		if value == true and index[key] then
			for _, card in ipairs(lessons.uses(index[key].level)) do
				seen[card] = true
			end
		end
	end
	saved.seen = seen
	data.progress = saved
	return data
end

function M.encode(app, catalog)
	local index = levelIndex(catalog)
	local boards = {}
	for key, poses in pairs(app.boards) do
		if index[key] and next(poses) then
			boards[key] = { fingerprint = M.fingerprint(index[key].level), poses = poses }
		end
	end
	local last = app.last and catalog.packs[app.last.pack]
	return {
		version = M.VERSION,
		progress = progress.data(app.progress),
		settings = app.settings,
		last = last and last.keys[app.last.index],
		boards = boards,
	}
end

function M.decode(data, catalog)
	data = type(data) == "table" and data or {}
	local index = levelIndex(catalog)
	local version = isInteger(data.version) and data.version or 0
	while migrations[version] and version < M.VERSION do
		data = migrations[version](data, index, catalog)
		version = version + 1
	end
	local boards = {}
	for key, board in pairs(type(data.boards) == "table" and data.boards or {}) do
		local entry = index[key]
		if entry and type(board) == "table" and board.fingerprint == M.fingerprint(entry.level) then
			boards[key] = cleanPoses(entry.level, board.poses)
		end
	end
	local last = type(data.last) == "string" and index[data.last]
	return {
		progress = progress.new(type(data.progress) == "table" and data.progress or nil),
		settings = settings.new(type(data.settings) == "table" and data.settings or nil),
		last = last and { pack = last.pack, index = last.index } or nil,
		boards = boards,
	}
end

return hot(..., M)
