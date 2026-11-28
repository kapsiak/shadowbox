local hot = require "core.hot"
local M = {}

-- The fonts' sizes (assets/fonts/*.font), so text can be scaled to a size in pixels.
M.FONT_SIZE = { title = 64, body = 40 }
-- The key image (ui/icons/key.png): its side and its nine-slice borders, in pixels.
M.KEY_SIZE = 96
M.SLICE = vmath.vector4(30, 30, 30, 30)

function M.withAlpha(color, alpha)
	local c = vmath.vector4(color)
	c.w = c.w * alpha
	return c
end

function M.place(node, x, y, w, h, color)
	gui.set_screen_position(node, vmath.vector3(x, y, 0))
	gui.set_size(node, vmath.vector3(w, h, 0))
	gui.set_color(node, color)
end

function M.setText(node, font, value, x, y, size, color, pivot)
	gui.set_text(node, value)
	gui.set_pivot(node, pivot or gui.PIVOT_CENTER)
	gui.set_screen_position(node, vmath.vector3(x, y, 0))
	local s = size / M.FONT_SIZE[font]
	gui.set_scale(node, vmath.vector3(s, s, 1))
	gui.set_color(node, color)
end

function M.placeBar(node, x, y, w, h, color)
	local k = h / M.KEY_SIZE
	M.place(node, x, y, math.max(w, h) / k, M.KEY_SIZE, color)
	gui.set_scale(node, vmath.vector3(k, k, 1))
end

return hot(..., M)
