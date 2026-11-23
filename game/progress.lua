-- What the player has solved, what is open to them, and what comes next. Pure Lua.
-- A catalog is { packs = { { id, levels = { level, ... }, keys = { "pack/name", ... } }, ... } };
-- progress is { solved = { [key] = true }, seen = { [card id] = true } } (see game/lessons).
local hot = require "core.hot"
local M = {}

-- Within a pack the first two levels are open and each later level opens once either of the
-- two before it is solved, so one hard level can be skipped. A pack opens once at least half
-- of the previous pack is solved.
local OPEN_AT_START = 2
local LOOKBACK = 2
local PACK_THRESHOLD = 0.5

local function trueSet(t)
	local out = {}
	for key, value in pairs(type(t) == "table" and t or {}) do
		out[key] = value == true or nil
	end
	return out
end

function M.new(data)
	data = data or {}
	return { solved = trueSet(data.solved), seen = trueSet(data.seen) }
end

function M.data(progress)
	return { solved = progress.solved, seen = progress.seen }
end

function M.markSeen(progress, card)
	progress.seen[card] = true
end

function M.isSolved(progress, key)
	return progress.solved[key] == true
end

function M.markSolved(progress, key)
	progress.solved[key] = true
end

function M.solvedCount(progress, pack)
	local n = 0
	for _, key in ipairs(pack.keys) do
		n = n + (progress.solved[key] and 1 or 0)
	end
	return n
end

-- open_all (a player setting) opens every pack and level.
function M.isPackOpen(progress, catalog, pack_index, open_all)
	if open_all or pack_index == 1 then
		return true
	end
	local previous = catalog.packs[pack_index - 1]
	return M.solvedCount(progress, previous) >= math.ceil(#previous.keys * PACK_THRESHOLD)
end

function M.isOpen(progress, catalog, pack_index, level_index, open_all)
	if not M.isPackOpen(progress, catalog, pack_index, open_all) then
		return false
	end
	if open_all or level_index <= OPEN_AT_START then
		return true
	end
	local keys = catalog.packs[pack_index].keys
	for back = 1, LOOKBACK do
		if progress.solved[keys[level_index - back]] then
			return true
		end
	end
	return false
end

-- The next open level after (pack_index, level_index), or nil at the end of the catalog.
function M.next(progress, catalog, pack_index, level_index, open_all)
	local p, l = pack_index, level_index + 1
	while catalog.packs[p] do
		if catalog.packs[p].keys[l] then
			if M.isOpen(progress, catalog, p, l, open_all) and not M.isSolved(progress, catalog.packs[p].keys[l]) then
				return p, l
			end
			l = l + 1
		else
			p, l = p + 1, 1
		end
	end
end

return hot(..., M)
