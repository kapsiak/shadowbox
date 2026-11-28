local hot = require "core.hot"
local M = {}

function M.eval(source, name)
	local fn, err = loadstring(source, "=" .. name)
	if not fn then
		return nil, err
	end
	local ok, value = pcall(setfenv(fn, {}))
	if not ok then
		return nil, value
	end
	return value
end

return hot(..., M)
