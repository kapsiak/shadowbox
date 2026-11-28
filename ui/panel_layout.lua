local hot = require "core.hot"
local measure = require "ui.measure"
local M = {}

local ROW_DP = 54
local WIDTH_DP = 380
local MARK_EM, MARK_GAP = 2, 0.35
M.SIDE = 0.4
local SCENE_ROWS = 4.2
local TEXT_SIZE, LINE = 0.36, 1.4
local LABEL_SIZE = 0.36
local HEADING_EM = 0.55

local function paragraphHeight(text, width, size)
	local per_line, lines = math.max(1, math.floor(width / (measure.EM * size))), 0
	for line in (text .. "\n"):gmatch("(.-)\n") do
		lines = lines + math.max(1, math.ceil(measure.length(line) / per_line))
	end
	return (lines + 0.4) * size * LINE
end

local function spread(items, cx, width, gap)
	local n = #items
	local w = (width - gap * (n - 1)) / n
	for k, item in ipairs(items) do
		item.x, item.w = cx - width / 2 + w / 2 + (k - 1) * (w + gap), w
	end
end

function M.sideBySide(screen)
	return screen.w > screen.h * 1.2
end

function M.compute(screen, sheet)
	local w, h = screen.w, screen.h
	local short = math.min(w, h)
	local row = math.min(math.max(ROW_DP * screen.scale, short * 0.07), short * 0.11)
	local side = sheet.side and M.sideBySide(screen)
	local width = math.min(WIDTH_DP * screen.scale, w * (side and M.SIDE * 0.8 or 0.86))
	local cx = side and screen.safe.left + w * M.SIDE * 0.55 or w / 2
	local gap = row * 0.28
	local title_h = sheet.title and row * 1.2 or 0
	local rows = 0
	for _, item in ipairs(sheet.items) do
		rows = rows + (item.inline and 0 or 1)
	end
	rows = math.max(rows, sheet.rows or 0)
	local scene_h = sheet.scene and math.min(row * SCENE_ROWS, h * 0.4) or 0
	local text_size = row * TEXT_SIZE
	local text_h = sheet.text and paragraphHeight(sheet.text, width, text_size) or 0
	local content_h = rows * row + (rows - 1) * gap + title_h + scene_h + text_h
	local pad = sheet.modal and row * 0.5 or 0

	local heading_em = measure.width(sheet.heading or "x", 1, HEADING_EM) + MARK_EM + MARK_GAP
	local heading_size = side and math.min(row * 1.3, width / heading_em) or row
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
		local size = heading_size
		local left = side and cx - width / 2 or w / 2 - heading_em * size / 2
		local y = side and top + size * 1.4 or h - screen.safe.top - row * 1.6
		local mark_h = size * MARK_EM / 2
		layout.heading = {
			text = sheet.heading, x = left + size * (MARK_EM + MARK_GAP), y = y, size = size,
			mark = { x = left + mark_h, y = y + size * 0.02, w = mark_h * 2, h = mark_h },
		}
		if sheet.caption then
			layout.caption = { text = sheet.caption, x = layout.heading.x, y = y - size * 0.8, size = row * 0.3 }
		end
	end
	if sheet.note then
		layout.note = { text = sheet.note, x = w - screen.safe.right - row * 0.4, y = screen.safe.bottom + row * 0.4, size = row * 0.28 }
	end
	if sheet.scene then
		layout.scene = { x = cx, y = top - title_h - scene_h / 2, w = width, h = scene_h }
	end
	if sheet.text then
		layout.text = { text = sheet.text, x = cx, y = top - title_h - scene_h - text_h / 2, w = width, size = text_size }
	end
	local y = top - title_h - scene_h - text_h - row / 2
	local bottom = top - content_h + row / 2
	local shared = {}
	for i, item in ipairs(sheet.items) do
		if i > 1 and not item.inline then
			y = y - row - gap
			shared = {}
		end
		local placed = { x = cx, y = item.footer and bottom or y, w = width, h = row, label_size = row * LABEL_SIZE }
		for k, v in pairs(item) do
			placed[k] = v
		end
		shared[#shared + 1] = placed
		spread(shared, cx, width, gap)
		if item.kind == "slider" or item.kind == "choice" or item.kind == "keys" then
			local label_end = row * 0.4 + measure.width(item.label, row * LABEL_SIZE) + row * 0.3
			local share = item.segments and #item.segments > 3 and 0.58 or 0.5
			local track = math.min(share, 0.95 - label_end / width)
			placed.track_x, placed.track_w = cx + width * (0.45 - track), width * track
		elseif item.kind == "tabs" then
			placed.track_x, placed.track_w = cx - width / 2, width
		end
		layout.items[#layout.items + 1] = placed
	end
	return layout
end

function M.segmentAt(item, x)
	local n = #item.segments
	local i = math.floor((x - item.track_x) / item.track_w * n) + 1
	return math.max(1, math.min(n, i))
end

function M.sliderValue(item, x)
	local t = math.max(0, math.min(1, (x - item.track_x) / item.track_w))
	return item.min + (item.max - item.min) * t
end

return hot(..., M)
