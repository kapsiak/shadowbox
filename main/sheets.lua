-- The text panels a screen can show (main menu, pause, settings, confirmations), kept as a
-- stack on the screen: screen.sheets = { "pause", "settings" }. Turns control events on a
-- panel into intents, and intents into requests for the app (see main.script).
local content = require "ui.sheets"
local panel_layout = require "ui.panel_layout"
local hit = require "ui.hit"

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

local builders = {
	main_menu = function(info) return content.mainMenu(info.title, info.can_continue) end,
	pause = function() return content.pause() end,
	settings = function(info, screen) return content.settings(info.settings, screen.settings_tab or "audio", info) end,
	confirm_reset = function() return content.confirmReset() end,
	confirm_restart = function() return content.confirmRestart() end,
}

-- Lays out the top sheet (or nil when none is open) and remembers it for hit testing.
function M.layout(screen, info)
	local name = M.top(screen)
	screen.sheet_layout = name and panel_layout.compute(info, builders[name](info, screen)) or nil
	return screen.sheet_layout
end

function M.hit(screen, x, y)
	local layout = screen.sheet_layout
	return layout and hit.find(layout.items, x, y)
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
		intents[#intents + 1] = { kind = "tab", value = item.values[panel_layout.segmentAt(item, ev.x)] }
	elseif ev.phase == "press" and item.kind == "toggle" then
		intents[#intents + 1] = { kind = "setting", key = item.id, value = not item.value }
	elseif ev.phase == "press" then
		intents[#intents + 1] = { kind = "sheet", id = item.id }
	end
end

-- Handles the panel intents every screen shares. Returns a request for the app, or nil.
-- Navigation between sheets (settings, confirmations, closing) happens here; ids a screen
-- handles itself (such as "restart") should be checked by the screen first.
function M.apply(screen, intent)
	if intent.kind == "setting" then
		return { setting = intent.key, value = intent.value }
	elseif intent.kind == "tab" then
		screen.settings_tab = intent.value
		return nil
	end
	local id = intent.id
	if id == "settings" then
		M.open(screen, "settings")
	elseif id == "reset_progress" then
		M.open(screen, "confirm_reset")
	elseif id == "confirm_reset" then
		M.close(screen)
		return { reset_progress = true }
	elseif id == "done" or id == "cancel" or id == "resume" then
		M.close(screen)
	elseif id == "levels" then
		return { to = "select" }
	elseif id == "main_menu" then
		return { to = "menu" }
	elseif id == "continue" then
		return { to = "continue" }
	end
end

return M
