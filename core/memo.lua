-- Change detection for work that should run only when its inputs change. Pure.
local hot = require "core.hot"
local M = {}

-- Remembers the values in `cache` (a table kept by the caller); true when any differs from the
-- last call, or on the first. Allocates nothing.
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
