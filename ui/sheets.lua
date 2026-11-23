-- The content of each text panel ("sheet"), as plain data. Pure: a sheet is
-- { title, modal, scene, text, items = { { id, kind = "button" | "toggle" | "slider", label, value, primary } } }.
-- `scene` reserves room for a live 3D scene (a rule card's) and `text` is a paragraph under it.
-- Modal sheets dim the screen behind them and sit on a card; the main menu does not, and stands
-- beside the scene on wide screens (`side`).
local hot = require "core.hot"
local settings = require "game.settings"
local lessons = require "game.lessons"
local controls = require "input.controls"

local M = {}

-- has_rules: whether any rule card has been seen, so the Rules list has something to show.
function M.mainMenu(title, can_continue, has_rules)
	local items = {
		{ id = "continue", kind = "button", label = can_continue and "Continue" or "Play", primary = true },
		{ id = "levels", kind = "button", label = "Levels" },
	}
	if has_rules then
		items[#items + 1] = { id = "rules", kind = "button", label = "Rules" }
	end
	items[#items + 1] = { id = "settings", kind = "button", label = "Settings" }
	return { heading = title, modal = false, side = true, items = items }
end

-- One rule card (catalog.loadRules); `more` when further cards follow it; touch: whether to
-- use the card's touch-screen text.
function M.rule(card, more, touch)
	return {
		title = card.title,
		modal = true,
		scene = true,
		text = touch and card.touch or card.text,
		items = { { id = "rule_next", kind = "button", label = more and "Next" or "Got it", primary = true } },
	}
end

-- The cards seen so far, in teaching order; each button opens its card.
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

-- One row of the Keys tab: a keycap per action, showing its first key ("…" while waiting for
-- a key, "–" when it has none). Pressing a cap rebinds that action.
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
	local bindings = controls.changed(prefs.bindings)
	for _, row in ipairs(rows) do
		items[#items + 1] = keyRow(row, bindings, rebinding)
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

-- tab: one of M.settings_tabs.values; platform: { can_fullscreen, has_keyboard }; view: the
-- Keys tab's state { keys_page, rebinding } (a page id from input/controls, the action waiting
-- for a key or nil). The Keys tab is offered only with a keyboard.
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
