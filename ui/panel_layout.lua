-- Places a sheet (ui/sheets) on screen. Pure: window pixels, origin bottom left.
-- Modal sheets sit centred on a card; others stack in the lower part of the screen, or, for a
-- `side` sheet on a wide screen, form a column on the left under a left-aligned heading.
local hot = require "core.hot"
local M = {}

local ROW_DP = 54
local WIDTH_DP = 380
-- The heading's mark (twice as wide as tall) and the gap after it, in ems of the heading.
local MARK_EM, MARK_GAP = 2, 0.35
-- The fraction of the width the side column takes, leaving the rest to the scene.
M.SIDE = 0.4
-- A rule card's scene, in rows; its paragraph's type size and line height, in rows.
local SCENE_ROWS = 4.2
local TEXT_SIZE, LINE = 0.36, 1.4

-- The height of a paragraph wrapped to `width`, at about 0.5 em per character.
local function paragraphHeight(text, width, size)
	local per_line = math.max(1, math.floor(width / (0.5 * size)))
	return (math.ceil(#text / per_line) + 0.4) * size * LINE
end

-- Whether a side sheet stands in a column beside the scene rather than below it.
function M.sideBySide(screen)
	return screen.w > screen.h * 1.2
end

-- screen: { w, h, scale, safe }. Returns { modal, card, title, scene, text, items } where each
-- item has x, y (centre), w, h, and for sliders the track's left edge and width; scene is a
-- rectangle { x, y, w, h } (centre) and text { text, x, y, w, size } a paragraph.
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
	local scene_h = sheet.scene and math.min(row * SCENE_ROWS, h * 0.4) or 0
	local text_size = row * TEXT_SIZE
	local text_h = sheet.text and paragraphHeight(sheet.text, width, text_size) or 0
	local content_h = rows * row + (rows - 1) * gap + title_h + scene_h + text_h
	local pad = sheet.modal and row * 0.5 or 0

	-- A side heading and its mark fit the column, at about 0.55 em per character.
	local heading_em = 0.55 * #(sheet.heading or "x") + MARK_EM + MARK_GAP
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
	end
	if sheet.note then
		layout.note = { text = sheet.note, x = screen.safe.left + row * 0.4, y = screen.safe.bottom + row * 0.4, size = row * 0.28 }
	end
	if sheet.scene then
		layout.scene = { x = cx, y = top - title_h - scene_h / 2, w = width, h = scene_h }
	end
	if sheet.text then
		layout.text = { text = sheet.text, x = cx, y = top - title_h - scene_h - text_h / 2, w = width, size = text_size }
	end
	local y = top - title_h - scene_h - text_h - row / 2
	local bottom = top - content_h + row / 2
	for _, item in ipairs(sheet.items) do
		local placed = { x = cx, y = item.footer and bottom or y, w = width, h = row }
		for k, v in pairs(item) do
			placed[k] = v
		end
		if item.kind == "slider" or item.kind == "choice" or item.kind == "keys" then
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

return hot(..., M)
