-- Estimated text sizes for pure layouts, which cannot ask the engine for font metrics: a
-- character takes about EM of the type size.
local hot = require "core.hot"
local M = {}

M.EM = 0.5

-- The characters in UTF-8 text (continuation bytes are not counted).
function M.length(text)
	local _, continuations = text:gsub("[\128-\191]", "")
	return #text - continuations
end

-- The width of `text` at type size `size`; em: the font's average width, EM by default.
function M.width(text, size, em)
	return M.length(text) * (em or M.EM) * size
end

return hot(..., M)
