-- The level select screen: a header per pack and a grid of level cards, scrolled vertically.
-- Pure: positions are window pixels with the origin at the bottom left.
local progress = require "game.progress"

local M = {}

local CARD_DP = 150
local GAP = 0.12

-- screen: { w, h, scale, safe }; scroll: pixels scrolled down from the top.
-- Returns { title, headers, cards, max_scroll }. Cards carry their level's front target so
-- the screen can draw a small silhouette of it.
function M.compute(screen, catalog, saved, scroll)
	local w, h, safe = screen.w, screen.h, screen.safe
	local short = math.min(w, h)
	local margin = math.max(short * 0.04, 16 * screen.scale) + math.max(safe.left, safe.right)
	local usable = w - 2 * margin
	local target = math.min(math.max(CARD_DP * screen.scale, short * 0.18), short * 0.3)
	local columns = math.max(2, math.floor((usable + target * GAP) / (target * (1 + GAP))))
	local card_w = (usable - (columns - 1) * target * GAP) / columns
	local card_h = card_w * 1.18
	local gap = card_w * GAP

	local title_size = math.min(short * 0.06, 34 * screen.scale)
	local y = h - safe.top - margin - title_size * 0.6 + scroll
	local layout = { title = { text = "Levels", x = w / 2, y = y, size = title_size }, headers = {}, cards = {} }
	y = y - title_size * 1.6

	for p, pack in ipairs(catalog.packs) do
		local open_pack = progress.isPackOpen(saved, catalog, p)
		layout.headers[#layout.headers + 1] = {
			id = pack.id, x = margin, y = y, size = title_size * 0.62,
			text = pack.title, detail = ("%d / %d"):format(progress.solvedCount(saved, pack), #pack.keys),
			enabled = open_pack,
		}
		y = y - title_size * 0.9 - card_h / 2
		for l, key in ipairs(pack.keys) do
			local column = (l - 1) % columns
			local state = progress.isSolved(saved, key) and "solved"
				or progress.isOpen(saved, catalog, p, l) and "open" or "locked"
			layout.cards[#layout.cards + 1] = {
				id = key, pack = p, index = l, number = l, name = pack.levels[l].name,
				target = pack.levels[l].targets.front, state = state, enabled = state ~= "locked",
				x = margin + card_w / 2 + column * (card_w + gap), y = y, w = card_w, h = card_h,
			}
			if column == columns - 1 or l == #pack.keys then
				y = y - card_h - gap
			end
		end
		y = y + card_h / 2 + gap - title_size
	end
	local content_bottom = y - scroll
	layout.max_scroll = math.max(0, safe.bottom + margin - content_bottom)
	return layout
end

return M
