local hot = require "core.hot"
local channels = require "core.channels"

local M = {}

M.order = { "controls", "shadows", "floor", "glass", "count", "parity" }

local function hasWall(level, operator)
	for _, v in ipairs(level.views) do
		if level.walls[v] == operator then
			return true
		end
	end
	return false
end

local function hasView(level, view)
	for _, v in ipairs(level.views) do
		if v == view then
			return true
		end
	end
	return false
end

local function hasGlass(level)
	for _, piece in ipairs(level.pieces) do
		if piece.value.light ~= channels.light.default then
			return true
		end
	end
	return false
end

local features = {
	controls = function() return true end,
	shadows = function(level) return hasWall(level, "light") end,
	floor = function(level) return hasView(level, "top") end,
	glass = function(level) return hasGlass(level) and hasWall(level, "light") end,
	count = function(level) return hasWall(level, "count") end,
	parity = function(level) return hasWall(level, "parity") end,
}

function M.uses(level)
	local out = {}
	for _, id in ipairs(M.order) do
		if features[id](level) then
			out[#out + 1] = id
		end
	end
	return out
end

function M.unseen(seen, level)
	local out = {}
	for _, id in ipairs(M.uses(level)) do
		if not seen[id] then
			out[#out + 1] = id
		end
	end
	return out
end

return hot(..., M)
