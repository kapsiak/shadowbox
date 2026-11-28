local hot = require "core.hot"
local settings = require "game.settings"
local lessons = require "game.lessons"
local controls = require "input.controls"

local M = {}

function M.mainMenu(title, version, can_continue, has_rules, can_quit, solved, total)
	local items = {
		{ id = "continue", kind = "button", label = can_continue and "Continue" or "Play", primary = true },
		{ id = "levels", kind = "button", label = "Levels" },
	}
	if has_rules then
		items[#items + 1] = { id = "rules", kind = "button", label = "Rules" }
	end
	items[#items + 1] = { id = "settings", kind = "button", label = "Settings" }
	items[#items + 1] = { id = "credits", kind = "button", label = "Credits" }
	if can_quit then
		items[#items + 1] = { id = "quit", kind = "button", label = "Quit", inline = true }
	end
	return {
		heading = title, caption = solved > 0 and ("%d of %d levels solved"):format(solved, total) or nil,
		note = version ~= "" and "v" .. version or nil, modal = false, side = true, items = items,
	}
end

function M.chapterComplete(pack_title, has_next)
	local items = {}
	if has_next then
		items[#items + 1] = { id = "next", kind = "button", label = "Next chapter", primary = true }
	end
	items[#items + 1] = { id = "levels", kind = "button", label = "Levels", primary = not has_next }
	return { title = "Chapter complete", modal = true, text = pack_title, items = items }
end

function M.credits(title)
	return {
		title = "Credits",
		modal = true,
		text = title .. " by Charlie Kapsiak\n\n"
			.. "Made with Defold\nCopyright 2020 The Defold Foundation\n\n"
			.. "Set in Outfit by The Outfit Project Authors\n\n"
			.. "The full licences ship with the game",
		items = { { id = "done", kind = "button", label = "Done", primary = true, footer = true } },
	}
end

function M.rule(card, more, touch)
	return {
		title = card.title,
		modal = true,
		scene = true,
		text = touch and card.touch or card.text,
		items = { { id = "rule_next", kind = "button", label = more and "Next" or "Got it", primary = true } },
	}
end

function M.rules(cards, seen)
	local items = {}
	for _, id in ipairs(lessons.order) do
		if seen[id] and cards[id] then
			items[#items + 1] = { id = "rule:" .. id, kind = "button", label = cards[id].title }
		end
	end
	items[#items + 1] = { id = "done", kind = "button", label = "Done", primary = true, footer = true }
	return { title = "Rules", modal = true, items = items }
end

function M.pause()
	return {
		title = "Paused",
		modal = true,
		items = {
			{ id = "resume", kind = "button", label = "Resume", primary = true },
			{ id = "hint", kind = "button", label = "Hint" },
			{ id = "restart", kind = "button", label = "Restart level" },
			{ id = "rules", kind = "button", label = "Rules" },
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
	values = { "audio", "display", "game", "access", "keys" },
	labels = { "Audio", "Display", "Game", "Access", "Keys" },
}

local function keyRow(row, bindings, rebinding)
	local values, segments = {}, {}
	for i = 2, #row do
		local keys = controls.keysOf(bindings, row[i])
		values[#values + 1] = row[i]
		segments[#segments + 1] = rebinding == row[i] and "…" or keys[1] and controls.keyLabel(keys[1]) or "–"
	end
	return { id = "keys:" .. row[2], kind = "keys", label = row[1], values = values, segments = segments, waiting = rebinding }
end

local function keyItems(prefs, page, rebinding)
	local values, labels, rows = {}, {}, nil
	for _, p in ipairs(controls.pages) do
		values[#values + 1], labels[#labels + 1] = p.id, p.label
		rows = p.id == page and p.rows or rows
	end
	local items = { { id = "keys_page", kind = "tabs", segments = labels, values = values, value = page } }
	for _, row in ipairs(rows) do
		items[#items + 1] = keyRow(row, prefs.bindings, rebinding)
	end
	if page == "other" then
		items[#items + 1] = { id = "reset_keys", kind = "button", label = "Reset keys", danger = true }
	end
	return items
end

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
			toggle("turn_ghost", "Show turn result", prefs),
			toggle("open_all", "Open all levels", prefs),
			{ id = "reset_progress", kind = "button", label = "Reset progress", danger = true },
		}
	end,
	keys = function(prefs, _, view)
		return keyItems(prefs, view.keys_page, view.rebinding)
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

function M.settings(prefs, tab, platform, view)
	local values, labels = {}, {}
	for i, v in ipairs(M.settings_tabs.values) do
		if v ~= "keys" or platform.has_keyboard then
			values[#values + 1], labels[#labels + 1] = v, M.settings_tabs.labels[i]
		end
	end
	local items = { { id = "settings_tab", kind = "tabs", segments = labels, values = values, value = tab } }
	for _, item in ipairs(tab_items[tab](prefs, platform, view)) do
		items[#items + 1] = item
	end
	items[#items + 1] = { id = "done", kind = "button", label = "Done", primary = true, footer = true }
	return { title = "Settings", modal = true, rows = 8, items = items }
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

return hot(..., M)
