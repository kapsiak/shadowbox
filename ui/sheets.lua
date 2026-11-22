-- The content of each text panel ("sheet"), as plain data. Pure: a sheet is
-- { title, modal, items = { { id, kind = "button" | "toggle" | "slider", label, value, primary } } }.
-- Modal sheets dim the screen behind them and sit on a card; the main menu does not.
local settings = require "game.settings"

local M = {}

function M.mainMenu(title, can_continue)
	return {
		heading = title,
		modal = false,
		items = {
			{ id = "continue", kind = "button", label = can_continue and "Continue" or "Play", primary = true },
			{ id = "levels", kind = "button", label = "Levels" },
			{ id = "settings", kind = "button", label = "Settings" },
		},
	}
end

function M.pause()
	return {
		title = "Paused",
		modal = true,
		items = {
			{ id = "resume", kind = "button", label = "Resume", primary = true },
			{ id = "restart", kind = "button", label = "Restart level" },
			{ id = "levels", kind = "button", label = "Levels" },
			{ id = "settings", kind = "button", label = "Settings" },
			{ id = "main_menu", kind = "button", label = "Main menu" },
		},
	}
end

local function slider(id, label, prefs)
	local range = settings.range(id)
	return { id = id, kind = "slider", label = label, value = prefs[id], min = range[1], max = range[2] }
end

local function toggle(id, label, prefs)
	return { id = id, kind = "toggle", label = label, value = prefs[id] }
end

local function choice(id, label, prefs)
	local c = settings.choices[id]
	return { id = id, kind = "choice", label = label, segments = c.labels, values = c.values, value = prefs[id] }
end

M.settings_tabs = {
	values = { "audio", "display", "game", "access" },
	labels = { "Audio", "Display", "Game", "Access" },
}

local tab_items = {
	audio = function(prefs)
		return { slider("sound", "Sound", prefs), slider("music", "Music", prefs) }
	end,
	display = function(prefs, platform)
		local items = {}
		if platform.can_fullscreen then
			items[#items + 1] = toggle("fullscreen", "Fullscreen", prefs)
		end
		items[#items + 1] = choice("quality", "Quality", prefs)
		items[#items + 1] = choice("frame_rate", "Frame rate", prefs)
		return items
	end,
	game = function(prefs)
		return {
			slider("sensitivity", "Camera speed", prefs),
			toggle("invert", "Invert camera", prefs),
			toggle("left_handed", "Left-handed", prefs),
			{ id = "reset_progress", kind = "button", label = "Reset progress", danger = true },
		}
	end,
	access = function(prefs)
		return {
			choice("colors", "Colour-blind", prefs),
			toggle("patterns", "Piece patterns", prefs),
			toggle("high_contrast", "High contrast", prefs),
			toggle("reduced_motion", "Reduce motion", prefs),
			choice("ui_scale", "Interface size", prefs),
		}
	end,
}

-- tab: one of M.settings_tabs.values; platform: { can_fullscreen }.
function M.settings(prefs, tab, platform)
	local items = {
		{ id = "tab", kind = "tabs", segments = M.settings_tabs.labels, values = M.settings_tabs.values, value = tab },
	}
	for _, item in ipairs(tab_items[tab](prefs, platform)) do
		items[#items + 1] = item
	end
	items[#items + 1] = { id = "done", kind = "button", label = "Done", primary = true, footer = true }
	return { title = "Settings", modal = true, rows = 7, items = items }
end

function M.confirmRestart()
	return {
		title = "Restart this level?",
		modal = true,
		items = {
			{ id = "confirm_restart", kind = "button", label = "Restart", danger = true },
			{ id = "cancel", kind = "button", label = "Cancel", primary = true },
		},
	}
end

function M.confirmReset()
	return {
		title = "Reset all progress?",
		modal = true,
		items = {
			{ id = "confirm_reset", kind = "button", label = "Reset", danger = true },
			{ id = "cancel", kind = "button", label = "Cancel", primary = true },
		},
	}
end

return M
