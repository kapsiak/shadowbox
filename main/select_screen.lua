-- The level select screen: packs as chapters with their levels on a winding trail, each open
-- level shown as a live 3D thumbnail. Tapping an open level plays it; dragging or the wheel
-- scrolls. Implements the screen contract used by main.script.
local select_layout = require "ui.select_layout"
local hit = require "ui.hit"
local models = require "ui.models"
local audio = require "view.audio"
local cameras = require "view.cameras"
local thumbs = require "view.thumbs"
local rules = require "core.rules"

local M = {}

local SCROLL_RATE = 16
local WHEEL_STEP = 0.08
local FOV = math.rad(16)

-- boards: the saved boards by level key; factories: { piece, glass_piece, panel, anchor } urls.
function M.enter(catalog, saved, boards, factories)
	return {
		module = M, catalog = catalog, saved = saved, boards = boards,
		thumbs = thumbs.new(factories),
	}
end

function M.exit(screen)
	thumbs.destroy(screen.thumbs)
	cameras.clear("board")
	models.publish("select", nil)
	models.publish("hud", nil)
end

-- The first layout opens scrolled to the current level.
function M.layout(screen, info)
	screen.info = info
	if not screen.scroll then
		local focus = select_layout.compute(info, screen.catalog, screen.saved, 0).focus
		screen.scroll, screen.goal_scroll = focus, focus
	end
	screen.view = select_layout.compute(info, screen.catalog, screen.saved, screen.scroll)
	return screen.view
end

local function backButton(info)
	local size = math.min(math.max(52 * info.scale, math.min(info.w, info.h) * 0.075), math.min(info.w, info.h) * 0.12)
	local margin = size * 0.35
	return { id = "back", x = info.safe.left + margin + size / 2, y = info.h - info.safe.top - margin - size / 2, size = size, group = "corner" }
end

-- Only the back button is claimed; levels are not, so a drag that starts on one still scrolls.
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
		local id = hit.find(screen.view.nodes, g.x, g.y)
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
		for _, node in ipairs(screen.view.nodes) do
			if node.id == intent.key then
				audio.cue("ui_tap")
				return { to = "play", pack = node.pack, index = node.index }
			end
		end
	end
end

-- What each open, on-screen level's thumbnail shows: a solved level its solved board (the
-- player's if they left it solved, else the level's own); an open level the board as the
-- player left it, or no pieces (the targets alone).
local function thumbPoses(saved, level, state)
	if state == "solved" and not (saved and rules.evaluate(level, { poses = saved }).solved) then
		return level.solution
	end
	return saved or {}
end

local function thumbSpecs(screen, view, h)
	local specs = {}
	for _, node in ipairs(view.nodes) do
		local visible = node.y > -node.size and node.y < h + node.size
		if node.state ~= "locked" and visible then
			local level = screen.catalog.packs[node.pack].levels[node.index]
			specs[#specs + 1] = {
				id = node.id, level = level, poses = thumbPoses(screen.boards[node.id], level, node.state), number = node.index,
				x = node.x, y = node.y + node.size * 0.08, size = node.size,
			}
		end
	end
	return specs
end

function M.present(screen, dt, info)
	screen.scroll = screen.scroll + (screen.goal_scroll - screen.scroll) * (1 - math.exp(-SCROLL_RATE * dt))
	local view = M.layout(screen, info)
	local eye_from = cameras.setScreen("board", info.w, info.h, FOV)
	thumbs.present(screen.thumbs, thumbSpecs(screen, view, info.h), dt, eye_from, info.settings)
	models.publish("select", view)
	models.publish("hud", { buttons = { backButton(info) }, labels = {} })
end

return M
