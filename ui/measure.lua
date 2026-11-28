local hot = require "core.hot"
local M = {}

M.EM = 0.5

function M.length(text)
	local _, continuations = text:gsub("[\128-\191]", "")
	return #text - continuations
end

function M.width(text, size, em)
	return M.length(text) * (em or M.EM) * size
end

return hot(..., M)
