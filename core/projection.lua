local hot = require "core.hot"
local channels = require "core.channels"

local M = {}

M.axes = {
	front = { u = 1, v = 2 },
	side = { u = 3, v = 2 },
	top = { u = 1, v = 3 },
}

local function dims(size, view)
	local axes = M.axes[view]
	return axes, size[axes.u], size[axes.v]
end

function M.project(size, view, names, items)
	local axes, w, h = dims(size, view)
	local layers = {}
	for _, name in ipairs(names) do
		local channel, layer = channels[name], {}
		for i = 1, w * h do
			layer[i] = channel.identity
		end
		for _, item in ipairs(items) do
			local v = item.value[name]
			for _, c in ipairs(item.cells) do
				local i = c[axes.u] + c[axes.v] * w + 1
				layer[i] = channel.combine(layer[i], v)
			end
		end
		layers[name] = layer
	end
	return { w = w, h = h, layers = layers }
end

function M.cover(size, cells, view)
	local axes, w, h = dims(size, view)
	local covered = {}
	for i = 1, w * h do
		covered[i] = false
	end
	for _, c in ipairs(cells) do
		covered[c[axes.u] + c[axes.v] * w + 1] = true
	end
	return covered
end

function M.compare(target, current)
	local ok, matches = {}, true
	for i = 1, target.w * target.h do
		local same = true
		for name, layer in pairs(target.layers) do
			same = same and layer[i] == current.layers[name][i]
		end
		ok[i] = same
		matches = matches and same
	end
	return { target = target, current = current, ok = ok, matches = matches }
end

return hot(..., M)
