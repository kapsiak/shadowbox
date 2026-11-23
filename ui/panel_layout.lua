-- Places a sheet (ui/sheets) on screen. Pure: window pixels, origin bottom left.
-- Modal sheets sit centred on a card; others stack in the lower part of the screen, or, for a
-- `side` sheet on a wide screen, form a column on the left under a left-aligned heading.
local M = {}

local ROW_DP = 54
local WIDTH_DP = 380
-- The fraction of the width the side column takes, leaving the rest to the scene.
M.SIDE = 0.4

-- Whether a side sheet stands in a column beside the scene rather than below it.
function M.sideBySide(screen)
	return screen.w > screen.h * 1.2
end

-- screen: { w, h, scale, safe }. Returns { modal, card, title, items } where each item has
-- x, y (centre), w, h, and for sliders the track's left edge and width.
function M.compute(screen, sheet)
	local w, h = screen.w, screen.h
	local short = math.min(w, h)
	local row = math.min(math.max(ROW_DP * screen.scale, short * 0.07), short * 0.11)
	local side = sheet.side and M.sideBySide(screen)
	local width = math.min(WIDTH_DP * screen.scale, w * (side and M.SIDE * 0.8 or 0.86))
	local cx = side and screen.safe.left + w * M.SIDE * 0.55 or w / 2
	local gap = row * 0.28
	local title_h = sheet.title and row * 1.2 or 0
	local rows = math.max(#sheet.items, sheet.rows or 0)
	local content_h = rows * row + (rows - 1) * gap + title_h
	local pad = sheet.modal and row * 0.5 or 0

	-- A side heading fits its column, at about 0.55 em per character.
	local heading_size = side and math.min(row * 1.3, width / (0.55 * #(sheet.heading or "x"))) or row
	local top
	if sheet.modal then
		top = h / 2 + content_h / 2
	elseif side then
		top = h / 2 + content_h / 2 - heading_size
	else
		top = h * 0.36
	end
	local layout = { modal = sheet.modal, items = {} }
	if sheet.modal then
		layout.card = { x = cx, y = top - content_h / 2, w = width + 2 * pad, h = content_h + 2 * pad }
	end
	if sheet.title then
		layout.title = { text = sheet.title, x = cx, y = top - title_h * 0.45, size = row * 0.5 }
	end
	if sheet.heading then
		if side then
			layout.heading = { text = sheet.heading, x = cx - width / 2, y = top + heading_size * 1.4, size = heading_size, align = "left" }
		else
			layout.heading = { text = sheet.heading, x = w / 2, y = h - screen.safe.top - row * 1.6, size = heading_size }
		end
	end
	local y = top - title_h - row / 2
	local bottom = top - content_h + row / 2
	for _, item in ipairs(sheet.items) do
		local placed = { x = cx, y = item.footer and bottom or y, w = width, h = row }
		for k, v in pairs(item) do
			placed[k] = v
		end
		if item.kind == "slider" or item.kind == "choice" then
			-- The control takes what the label leaves (labels are drawn at 0.36 rows from 0.4
			-- rows in, at about 0.5 em per character), up to its usual share of the row.
			local label_end = row * 0.4 + #item.label * 0.5 * row * 0.36 + row * 0.3
			local share = item.segments and #item.segments > 3 and 0.58 or 0.5
			local track = math.min(share, 0.95 - label_end / width)
			placed.track_x, placed.track_w = cx + width * (0.45 - track), width * track
		elseif item.kind == "tabs" then
			placed.track_x, placed.track_w = cx - width / 2, width
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
