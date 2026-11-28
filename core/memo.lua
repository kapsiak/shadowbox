local hot = require "core.hot"
local M = {}

function M.changed(cache, ...)
	local n = select("#", ...)
	local changed = cache.n ~= n
	for i = 1, n do
		local v = select(i, ...)
		if cache[i] ~= v then
			cache[i] = v
			changed = true
		end
	end
	cache.n = n
	return changed
end

return hot(..., M)
