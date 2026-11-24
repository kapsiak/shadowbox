-- The text panels a screen can show (main menu, pause, settings, confirmations), kept as a
-- stack on the screen: screen.sheets = { "pause", "settings" }. Turns control events on a
-- panel into intents, and intents into requests for the app (see main.script).
local hot = require "core.hot"
local content = require "ui.sheets"
local panel_layout = require "ui.panel_layout"
local hit = require "ui.hit"
local controls = require "input.controls"
local memo = require "core.memo"

local M = {}

function M.open(screen, name)
	table.insert(screen.sheets, name)
end

function M.close(screen)
	table.remove(screen.sheets)
end

function M.top(screen)
	return screen.sheets[#screen.sheets]
end

-- Rule cards wait in screen.cards (ids, the shown one first) with their content in screen.rules
-- (catalog.loadRules); the "rule" sheet shows the first.
function M.showCards(screen, ids)
	screen.cards = { unpack(ids) }
	M.open(screen, "rule")
end

-- The scene level of the rule card on top, or nil.
function M.cardLevel(screen)
	return M.top(screen) == "rule" and screen.rules[screen.cards[1]].level or nil
end

local builders = {
	main_menu = function(info) return content.mainMenu(info.title, info.version, info.can_continue, next(info.seen) ~= nil) end,
	rule = function(info, screen) return content.rule(screen.rules[screen.cards[1]], #screen.cards > 1, not info.has_keyboard) end,
	rules = function(info, screen) return content.rules(screen.rules, info.seen) end,
	pause = function() return content.pause() end,
	settings = function(info, screen)
		local view = { keys_page = screen.keys_page or "piece", rebinding = screen.rebinding }
		return content.settings(info.settings, screen.settings_tab or "audio", info, view)
	end,
	confirm_reset = function() return content.confirmReset() end,
	confirm_restart = function() return content.confirmRestart() end,
}

-- Lays out the top sheet (or nil when none is open) and remembers it for hit testing; laid out
-- again only when the sheet or something its content reads changes.
function M.layout(screen, info)
	local name, cards = M.top(screen), screen.cards
	screen.sheet_inputs = screen.sheet_inputs or {}
	if memo.changed(screen.sheet_inputs, name, info.geometry, info.settings, info.can_continue, info.seen,
		cards and cards[1], cards and #cards, screen.keys_page, screen.rebinding, screen.settings_tab) then
		screen.sheet_layout = name and panel_layout.compute(info, builders[name](info, screen)) or nil
	end
	return screen.sheet_layout
end

function M.hit(screen, x, y)
	local layout = screen.sheet_layout
	return layout and hit.find(layout.items, x, y)
end

-- Whether (x, y) lies outside the top sheet's card; a tap there dismisses it, as Escape does.
-- Sheets without a card (the main menu) are never dismissed.
function M.outside(screen, x, y)
	local card = screen.sheet_layout and screen.sheet_layout.card
	if not card then
		return false
	end
	return math.abs(x - card.x) > card.w / 2 or math.abs(y - card.y) > card.h / 2
end

local function itemById(screen, id)
	for _, item in ipairs(screen.sheet_layout.items) do
		if item.id == id then
			return item
		end
	end
end

-- A control event on the panel: buttons and toggles act on press, sliders follow the pointer.
function M.control(screen, ev, intents)
	local item = screen.sheet_layout and itemById(screen, ev.id)
	if not item then
		return
	end
	if item.kind == "slider" then
		intents[#intents + 1] = { kind = "setting", key = item.id, value = panel_layout.sliderValue(item, ev.x) }
	elseif ev.phase == "press" and item.kind == "choice" then
		intents[#intents + 1] = { kind = "setting", key = item.id, value = item.values[panel_layout.segmentAt(item, ev.x)] }
	elseif ev.phase == "press" and item.kind == "tabs" then
		intents[#intents + 1] = { kind = "tab", id = item.id, value = item.values[panel_layout.segmentAt(item, ev.x)] }
	elseif ev.phase == "press" and item.kind == "keys" then
		intents[#intents + 1] = { kind = "rebind", action = item.values[panel_layout.segmentAt(item, ev.x)] }
	elseif ev.phase == "press" and item.kind == "toggle" then
		intents[#intents + 1] = { kind = "setting", key = item.id, value = not item.value }
	elseif ev.phase == "press" then
		intents[#intents + 1] = { kind = "sheet", id = item.id }
	end
end

-- While an action waits for a key, the next key press binds it (Escape cancels). Returns
-- whether the key gesture `g` was taken. bindings: the player's (settings.bindings).
function M.key(screen, g, intents, bindings)
	if not screen.rebinding or g.kind ~= "key" or not g.pressed then
		return false
	end
	local changed = g.key ~= "escape" and controls.rebind(bindings, screen.rebinding, g.key)
	if changed then
		intents[#intents + 1] = { kind = "setting", key = "bindings", value = changed }
	end
	screen.rebinding = nil
	return true
end

-- Handles the panel intents every screen shares. Returns a request for the app, or nil.
-- Navigation between sheets (settings, confirmations, closing) happens here; ids a screen
-- handles itself (such as "restart") should be checked by the screen first.
function M.apply(screen, intent)
	if intent.kind == "setting" then
		return { setting = intent.key, value = intent.value }
	elseif intent.kind == "tab" then
		screen[intent.id] = intent.value
		screen.rebinding = nil
		return nil
	elseif intent.kind == "rebind" then
		screen.rebinding = screen.rebinding ~= intent.action and intent.action or nil
		return nil
	end
	local id = intent.id
	local card = id:match("^rule:(.+)")
	if card then
		M.showCards(screen, { card })
	elseif id == "rule_next" then
		local seen = table.remove(screen.cards, 1)
		if #screen.cards == 0 then
			M.close(screen)
		end
		return { seen = seen }
	elseif id == "rules" then
		M.open(screen, "rules")
	elseif id == "settings" then
		M.open(screen, "settings")
	elseif id == "reset_progress" then
		M.open(screen, "confirm_reset")
	elseif id == "confirm_reset" then
		M.close(screen)
		return { reset_progress = true }
	elseif id == "reset_keys" then
		screen.rebinding = nil
		return { setting = "bindings", value = {} }
	elseif id == "done" or id == "cancel" or id == "resume" then
		screen.rebinding = nil
		M.close(screen)
	elseif id == "levels" then
		return { to = "select" }
	elseif id == "main_menu" then
		return { to = "menu" }
	elseif id == "continue" then
		return { to = "continue" }
	end
end

return hot(..., M)
