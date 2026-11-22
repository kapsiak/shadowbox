-- Where the on-screen controls and labels go for a given screen. Pure: positions are window
-- pixels with the origin at the bottom left, the same space as pointer input, so one layout
-- serves both drawing (ui/hud.gui_script) and hit testing (main.script).
local M = {}

M.TRAY_INSET = 0.2

local top_left = { "menu", "undo", "redo" }
local top_right = { "view_front", "view_side", "view_top", "view_iso" }
local rail = { "turn_left", "turn_right", "tip_away", "roll_right", "lift", "lower", "stow" }

local BUTTON_DP = 52
local GAP = 0.22
local RAIL_STEP = 1.2

local function place(out, id, x, y, size, group, enabled)
	out[#out + 1] = { id = id, x = x, y = y, size = size, group = group, enabled = enabled ~= false }
end

-- Button size: a comfortable touch target in density-independent pixels, kept within sensible
-- bounds of the screen, and small enough that the top row fits across.
local function buttonSize(w, h, scale)
	local short = math.min(w, h)
	local size = math.max(short * 0.075, math.min(short * 0.12, BUTTON_DP * scale))
	local row = #top_left + #top_right + 1.5
	return math.min(size, w / (row * (1 + GAP) + 0.7))
end

-- screen: { w, h, scale, safe = { left, right, top, bottom } } in window pixels.
-- state: { piece_controls, can_undo, can_redo, title, subtitle, solved, left_handed }
-- Returns { buttons, labels, tray, insets } where insets are the screen fractions the board
-- should keep clear of (left, right, top, bottom).
function M.compute(screen, state)
	local w, h, safe = screen.w, screen.h, screen.safe
	local size = buttonSize(w, h, screen.scale)
	local gap = size * GAP
	local margin = size * 0.35
	local left, right = safe.left + margin, w - safe.right - margin
	local top = h - safe.top - margin - size / 2
	local buttons, labels = {}, {}

	for i, id in ipairs(top_left) do
		local enabled = (id ~= "undo" or state.can_undo) and (id ~= "redo" or state.can_redo)
		place(buttons, id, left + size / 2 + (i - 1) * (size + gap), top, size, "corner", enabled)
	end
	for i, id in ipairs(top_right) do
		place(buttons, id, right - size / 2 - (#top_right - i) * (size + gap), top, size, "corner")
	end

	local tray_h = h * M.TRAY_INSET + safe.bottom
	local rail_x = state.left_handed and left + size / 2 or right - size / 2
	if state.piece_controls then
		local available = top - size / 2 - gap - tray_h
		local rail_size = math.min(size, available / (#rail * RAIL_STEP))
		local step = rail_size * RAIL_STEP
		local first = tray_h + available / 2 + step * (#rail - 1) / 2
		for i, id in ipairs(rail) do
			place(buttons, id, rail_x, first - (i - 1) * step, rail_size, "rail")
		end
	end

	local corner_span = (#top_left + #top_right) * (size + gap)
	local landscape = w - corner_span - 2 * margin > size * 5
	local title_y = landscape and top or top - size * 1.15
	if state.title then
		labels[#labels + 1] = { id = "title", text = state.title, x = w / 2, y = title_y + size * 0.14, size = size * 0.36, style = "title" }
		labels[#labels + 1] = { id = "subtitle", text = state.subtitle or "", x = w / 2, y = title_y - size * 0.24, size = size * 0.22, style = "body" }
	end
	local inset = margin * 0.6
	local tray = { x = safe.left + inset, y = safe.bottom + inset * 0.5, w = w - safe.left - safe.right - 2 * inset, h = tray_h - safe.bottom - inset }
	if state.solved then
		local y = tray.y + tray.h / 2
		labels[#labels + 1] = { id = "banner", text = "Solved", x = w / 2 - size * 0.7, y = y, size = size * 0.6, style = "title" }
		place(buttons, "next", w / 2 + size * 1.5, y, size * 1.1, "action")
	end

	local board_top = h - (title_y - size * 0.6)
	return {
		buttons = buttons,
		labels = labels,
		tray = tray,
		insets = {
			left = state.left_handed and (rail_x + size * 0.6) / w or safe.left / w,
			right = state.left_handed and safe.right / w or (w - rail_x + size * 0.6) / w,
			top = board_top / h, bottom = tray_h / h,
		},
	}
end

-- The enabled button id under a screen point, or nil.
function M.hit(layout, x, y)
	for _, b in ipairs(layout.buttons) do
		local half = b.size / 2
		if b.enabled and math.abs(x - b.x) <= half and math.abs(y - b.y) <= half then
			return b.id
		end
	end
end

return M
