-- Evaluates Lua data files (levels, pack manifests) in an empty environment.
-- Targets Lua 5.1 / LuaJIT, which Defold and the project tools run on.
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
