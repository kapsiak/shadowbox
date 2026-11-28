local hot = require "core.hot"
local progress = require "game.progress"
local hud_layout = require "ui.hud_layout"

local M = {}

local NODE_DP = 120
local CELL = 1.55
local ROW = 1.6
local MAX_COLUMNS = 6
local DOT_SPACING = 0.15
local GAP = 0.58
local TURN = 0.32
local SAMPLES = 32
local FOCUS_HEIGHT = 0.45

local function trailDots(dots, at, node, accent, lit)
	local samples, length = { { at(0) } }, 0
	samples[1][3] = 0
	for i = 1, SAMPLES do
		local x, y = at(i / SAMPLES)
		local last = samples[#samples]
		length = length + math.sqrt((x - last[1]) ^ 2 + (y - last[2]) ^ 2)
		samples[#samples + 1] = { x, y, length }
	end
	local count = math.max(1, math.floor(length / (node * DOT_SPACING)))
	local j = 1
	for i = 0, count do
		local d = length * i / count
		while j < SAMPLES and samples[j + 1][3] < d do
			j = j + 1
		end
		local a, b = samples[j], samples[j + 1]
		local f = (d - a[3]) / math.max(b[3] - a[3], 1e-6)
		dots[#dots + 1] = {
			x = a[1] + (b[1] - a[1]) * f, y = a[2] + (b[2] - a[2]) * f,
			size = node * 0.07, accent = accent, lit = lit,
		}
	end
end

local function trailCurve(from, to, node)
	if from.y == to.y then
		local dir = to.x > from.x and 1 or -1
		local x0, x1 = from.x + dir * node * GAP, to.x - dir * node * GAP
		return function(t)
			return x0 + (x1 - x0) * t, from.y
		end
	end
	local side, drop = from.side, from.y - to.y
	return function(t)
		local a = math.pi * t
		return from.x + side * node * (GAP + TURN * math.sin(a)), from.y - drop * (1 - math.cos(a)) / 2
	end
end

local function levelState(saved, catalog, p, l, open_all)
	local key = catalog.packs[p].keys[l]
	return progress.isSolved(saved, key) and "solved" or progress.isOpen(saved, catalog, p, l, open_all) and "open" or "locked"
end

function M.compute(screen, catalog, saved, chapter)
	local w, h, safe = screen.w, screen.h, screen.safe
	local short = math.min(w, h)
	local margin = math.max(short * 0.04, 16 * screen.scale) + math.max(safe.left, safe.right)
	local node = math.min(math.max(NODE_DP * screen.scale, short * 0.17), short * 0.28)
	local pack = catalog.packs[chapter]
	local usable = w - 2 * (margin + node * (TURN + 0.1))
	local columns = math.max(2, math.min(MAX_COLUMNS, #pack.keys, math.floor(usable / (node * CELL))))
	local cell = math.min(usable / columns, node * CELL * 1.3)
	local cx = w / 2
	local left = cx - cell * columns / 2
	local open_all = screen.settings and screen.settings.open_all
	local cur_p, cur_l = progress.next(saved, catalog, 1, 0, open_all)

	local title_size = math.min(short * 0.06, 34 * screen.scale)
	local y = h - safe.top - margin - title_size * 0.6
	local back = M.backKey(screen)
	local layout = {
		back = back,
		title = { text = "Levels", x = cx, y = y, size = title_size },
		marks = {}, nodes = {}, trail = {}, calm = screen.settings and screen.settings.reduced_motion,
	}
	y = y - title_size * 1.25
	local count, arrow = #catalog.packs, title_size * 1.3
	local reach = cx - (back.x + back.size / 2) - arrow * 0.6
	local mark_gap = math.min(title_size * 0.9, (reach - arrow * 0.6) / (count / 2))
	for p = 1, count do
		layout.marks[p] = {
			chapter = p, current = p == chapter, enabled = progress.isPackOpen(saved, catalog, p, open_all),
			x = cx + (p - (count + 1) / 2) * mark_gap, y = y, size = title_size * 0.32, hit = mark_gap,
			accent = catalog.packs[p].accent,
		}
	end
	local arrow_x = count / 2 * mark_gap + arrow * 0.6
	layout.arrows = {
		prev = { x = cx - arrow_x, y = y, size = arrow },
		next = { x = cx + arrow_x, y = y, size = arrow },
	}
	y = y - title_size * 1.8

	local page_w = math.min(w - margin, cell * columns + 2 * node * (GAP + TURN + 0.2))
	local open_pack = progress.isPackOpen(saved, catalog, chapter, open_all)
	local page_top = y + title_size * 1.1
	layout.banner = {
		x = cx, y = y, size = title_size * 0.8, accent = pack.accent,
		text = pack.title, intro = open_pack and pack.intro or "Locked",
		detail = ("%d / %d"):format(progress.solvedCount(saved, pack), #pack.keys),
		enabled = open_pack,
	}
	local top = y - title_size * 1.6 - node * 0.75
	local previous, focus_y
	for l, key in ipairs(pack.keys) do
		local row, column = math.floor((l - 1) / columns), (l - 1) % columns
		local reversed = row % 2 == 1
		local state = levelState(saved, catalog, chapter, l, open_all)
		local spec = {
			id = key, pack = chapter, index = l, name = pack.levels[l].name, state = state,
			current = chapter == cur_p and l == cur_l, accent = pack.accent, enabled = state ~= "locked",
			x = left + cell * ((reversed and columns - 1 - column or column) + 0.5),
			y = top - row * node * ROW, size = node, side = reversed and -1 or 1,
		}
		layout.nodes[#layout.nodes + 1] = spec
		if previous then
			trailDots(layout.trail, trailCurve(previous, spec, node), node, pack.accent, previous.state == "solved")
		end
		if spec.current then
			focus_y = spec.y
		end
		previous = spec
	end
	local page_bottom = previous.y - node * 0.75 - title_size * 0.2
	layout.page = { x = cx, y = (page_top + page_bottom) / 2, w = page_w, h = page_top - page_bottom }
	layout.max_scroll = math.max(0, safe.bottom + margin - page_bottom)
	layout.focus = focus_y and math.max(0, math.min(layout.max_scroll, h * FOCUS_HEIGHT - focus_y)) or 0
	return layout
end

function M.backKey(screen)
	local size = hud_layout.keySize(math.min(screen.w, screen.h), screen.scale)
	local margin = size * 0.35
	return { x = screen.safe.left + margin + size / 2, y = screen.h - screen.safe.top - margin - size / 2, size = size }
end

function M.chapterOf(catalog, saved, last, open_all)
	if last and catalog.packs[last.pack] then
		return last.pack
	end
	return progress.next(saved, catalog, 1, 0, open_all) or 1
end

return hot(..., M)
