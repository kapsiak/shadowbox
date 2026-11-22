-- The level select screen: packs and their level cards. Tapping an open card plays it;
-- dragging or the wheel scrolls. Implements the screen contract used by main.script.
local select_layout = require "ui.select_layout"
local hit = require "ui.hit"
local models = require "ui.models"
local audio = require "view.audio"

local M = {}

local SCROLL_RATE = 16
local WHEEL_STEP = 0.08

function M.enter(catalog, saved)
	return { module = M, catalog = catalog, saved = saved, scroll = 0, goal_scroll = 0 }
end

function M.exit(screen)
	models.publish("select", nil)
	models.publish("hud", nil)
end

function M.layout(screen, info)
	screen.info = info
	screen.view = select_layout.compute(info, screen.catalog, screen.saved, screen.scroll)
	return screen.view
end

local function backButton(info)
	local size = math.min(math.max(52 * info.scale, math.min(info.w, info.h) * 0.075), math.min(info.w, info.h) * 0.12)
	local margin = size * 0.35
	return { id = "back", x = info.safe.left + margin + size / 2, y = info.h - info.safe.top - margin - size / 2, size = size, group = "corner" }
end

-- Only the back button is claimed; cards are not, so a drag that starts on one still scrolls.
function M.hit(screen, x, y)
	return hit.find({ backButton(screen.info) }, x, y)
end

function M.button(screen, ev, intents)
	if ev.phase == "press" then
		models.pressed("hud", ev.id)
		intents[#intents + 1] = { kind = "back" }
	end
end

function M.gesture(screen, g, intents)
	if g.kind == "tap" and g.button == "primary" then
		local id = hit.find(screen.view.cards, g.x, g.y)
		if id then
			intents[#intents + 1] = { kind = "open", key = id }
		end
	elseif g.kind == "drag_move" and not g.multi then
		intents[#intents + 1] = { kind = "scroll", by = g.dy, follow = true }
	elseif g.kind == "key" and g.pressed and g.name == "menu" then
		intents[#intents + 1] = { kind = "back" }
	elseif g.kind == "wheel" then
		intents[#intents + 1] = { kind = "scroll", by = -g.amount * screen.info.h * WHEEL_STEP }
	end
end

-- Applies one intent; returns a request for the app (see main.script) or nil.
function M.apply(screen, intent)
	if intent.kind == "back" then
		return { to = "menu" }
	elseif intent.kind == "scroll" then
		screen.goal_scroll = math.max(0, math.min(screen.view.max_scroll, screen.goal_scroll + intent.by))
		if intent.follow then
			screen.scroll = screen.goal_scroll
		end
	elseif intent.kind == "open" then
		for _, card in ipairs(screen.view.cards) do
			if card.id == intent.key then
				audio.cue("ui_tap")
				return { to = "play", pack = card.pack, index = card.index }
			end
		end
	end
end

function M.present(screen, dt, info)
	screen.scroll = screen.scroll + (screen.goal_scroll - screen.scroll) * (1 - math.exp(-SCROLL_RATE * dt))
	models.publish("select", M.layout(screen, info))
	models.publish("hud", { buttons = { backButton(info) }, labels = {} })
end

return M
