-- Places a sheet (ui/sheets) on screen. Pure: window pixels, origin bottom left.
-- Modal sheets sit centred on a card; others stack in the lower part of the screen.
local M = {}

local ROW_DP = 54
local WIDTH_DP = 380

-- screen: { w, h, scale, safe }. Returns { modal, card, title, items } where each item has
-- x, y (centre), w, h, and for sliders the track's left edge and width.
function M.compute(screen, sheet)
	local w, h = screen.w, screen.h
	local short = math.min(w, h)
	local row = math.min(math.max(ROW_DP * screen.scale, short * 0.07), short * 0.11)
	local width = math.min(WIDTH_DP * screen.scale, w * 0.86)
	local gap = row * 0.28
	local title_h = sheet.title and row * 1.2 or 0
	local rows = math.max(#sheet.items, sheet.rows or 0)
	local content_h = rows * row + (rows - 1) * gap + title_h
	local pad = sheet.modal and row * 0.5 or 0

	local top
	if sheet.modal then
		top = h / 2 + content_h / 2
	else
		top = h * 0.36
	end
	local layout = { modal = sheet.modal, items = {} }
	if sheet.modal then
		layout.card = { x = w / 2, y = top - content_h / 2, w = width + 2 * pad, h = content_h + 2 * pad }
	end
	if sheet.title then
		layout.title = { text = sheet.title, x = w / 2, y = top - title_h * 0.45, size = row * 0.5 }
	end
	if sheet.heading then
		layout.heading = { text = sheet.heading, x = w / 2, y = h - screen.safe.top - row * 1.6, size = row * 1.0 }
	end
	local y = top - title_h - row / 2
	local bottom = top - content_h + row / 2
	for _, item in ipairs(sheet.items) do
		local placed = { x = w / 2, y = item.footer and bottom or y, w = width, h = row }
		for k, v in pairs(item) do
			placed[k] = v
		end
		if item.kind == "slider" or item.kind == "choice" then
			local track = item.segments and #item.segments > 3 and 0.58 or 0.5
			placed.track_x, placed.track_w = w / 2 + width * (0.45 - track), width * track
		elseif item.kind == "tabs" then
			placed.track_x, placed.track_w = w / 2 - width / 2, width
		end
		layout.items[#layout.items + 1] = placed
		y = y - row - gap
	end
	return layout
end

-- The index of the segment at screen x for a placed choice or tabs item.
function M.segmentAt(item, x)
	local n = #item.segments
	local i = math.floor((x - item.track_x) / item.track_w * n) + 1
	return math.max(1, math.min(n, i))
end

-- The slider value at screen x for a placed slider item.
function M.sliderValue(item, x)
	local t = math.max(0, math.min(1, (x - item.track_x) / item.track_w))
	return item.min + (item.max - item.min) * t
end

return M
