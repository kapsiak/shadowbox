-- The level select screen: packs as chapters with their levels on a winding trail, each open
-- level shown as a live 3D thumbnail. Tapping an open level plays it; dragging (with a fling on
-- release) or the wheel scrolls. Implements the screen contract used by main.script.
--
-- The layout is computed once per screen size and published with the scroll offset, so
-- scrolling moves one offset rather than rebuilding the page.
local hot = require "core.hot"
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
-- A fling keeps the release speed and slows by FRICTION per second until below FLING_MIN
-- pixels per second; a release more than FLING_HOLD seconds after the last move does not fling.
local FRICTION = 3.5
local FLING_MIN = 40
local FLING_HOLD = 0.08
-- Thumbnails are built this many node sizes before they scroll into view.
local THUMB_MARGIN = 1.5

-- boards: the saved boards by level key; pool: the board pool (view/board_pool).
function M.enter(catalog, saved, boards, pool)
	return {
		module = M, catalog = catalog, saved = saved, boards = boards,
		thumbs = thumbs.new(pool), specs = {}, model = {},
		clock = 0, velocity = 0, drag_velocity = 0, moved_at = -math.huge,
	}
end

function M.exit(screen)
	thumbs.release(screen.thumbs)
	cameras.clear("board")
	models.publish("select", nil)
	models.publish("hud", nil)
end

local function frameKey(info)
	local safe = info.safe
	return ("%d %d %g %d %d %d %d %s"):format(info.w, info.h, info.scale, safe.left, safe.right, safe.top, safe.bottom,
		tostring(info.settings.reduced_motion))
end

local function clamped(screen, scroll)
	return math.max(0, math.min(screen.view.max_scroll, scroll))
end

-- Lays out the page when the screen changes; the first layout opens scrolled to the current level.
function M.layout(screen, info)
	screen.info = info
	local key = frameKey(info)
	if key ~= screen.frame then
		screen.frame = key
		screen.view = select_layout.compute(info, screen.catalog, screen.saved)
		screen.model.layout = screen.view
		if not screen.scroll then
			screen.scroll, screen.goal_scroll = screen.view.focus, screen.view.focus
		end
		screen.goal_scroll = clamped(screen, screen.goal_scroll)
	end
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
	if g.kind == "tap" and g.button == "primary" and screen.velocity ~= 0 then
		intents[#intents + 1] = { kind = "grab" }
	elseif g.kind == "tap" and g.button == "primary" then
		local id = hit.find(screen.view.nodes, g.x, g.y - screen.scroll)
		if id then
			intents[#intents + 1] = { kind = "open", key = id }
		end
	elseif g.kind == "drag_start" then
		intents[#intents + 1] = { kind = "grab" }
	elseif g.kind == "drag_move" and not g.multi then
		intents[#intents + 1] = { kind = "drag", by = g.dy }
	elseif g.kind == "drag_end" then
		intents[#intents + 1] = { kind = "release" }
	elseif g.kind == "key" and g.pressed and g.name == "menu" then
		intents[#intents + 1] = { kind = "back" }
	elseif g.kind == "wheel" then
		intents[#intents + 1] = { kind = "wheel", by = -g.amount * screen.info.h * WHEEL_STEP }
	end
end

local function openLevel(screen, key)
	for _, node in ipairs(screen.view.nodes) do
		if node.id == key then
			audio.cue("ui_tap")
			return { to = "play", pack = node.pack, index = node.index }
		end
	end
end

-- Applies one intent; returns a request for the app (see main.script) or nil.
function M.apply(screen, intent, dt)
	local kind = intent.kind
	if kind == "back" then
		return { to = "menu" }
	elseif kind == "open" then
		return openLevel(screen, intent.key)
	elseif kind == "grab" then
		screen.velocity, screen.drag_velocity = 0, 0
	elseif kind == "drag" then
		screen.goal_scroll = clamped(screen, screen.goal_scroll + intent.by)
		screen.scroll = screen.goal_scroll
		screen.drag_velocity = 0.5 * screen.drag_velocity + 0.5 * intent.by / math.max(dt, 1 / 240)
		screen.moved_at = screen.clock
	elseif kind == "release" then
		screen.velocity = screen.clock - screen.moved_at < FLING_HOLD and screen.drag_velocity or 0
	elseif kind == "wheel" then
		screen.velocity = 0
		screen.goal_scroll = clamped(screen, screen.goal_scroll + intent.by)
	end
end

local function fling(screen, dt)
	if screen.velocity == 0 then
		return
	end
	local goal = screen.goal_scroll + screen.velocity * dt
	screen.goal_scroll = clamped(screen, goal)
	screen.velocity = screen.velocity * math.exp(-FRICTION * dt)
	if screen.goal_scroll ~= goal or math.abs(screen.velocity) < FLING_MIN then
		screen.velocity = 0
	end
end

-- What each open level's thumbnail shows: a solved level its solved board (the player's if
-- they left it solved, else the level's own); an open level the board as the player left it,
-- or no pieces (the targets alone).
local function thumbPoses(saved, level, state)
	if state == "solved" and not (saved and rules.evaluate(level, { poses = saved }).solved) then
		return level.solution
	end
	return saved or {}
end

-- The thumbnail of `node`, made once per screen; only its position follows the scroll.
local function thumbSpec(screen, node)
	local spec = screen.specs[node.id]
	if not spec then
		local level = screen.catalog.packs[node.pack].levels[node.index]
		spec = { id = node.id, level = level, poses = thumbPoses(screen.boards[node.id], level, node.state), number = node.index, x = node.x, size = node.size }
		screen.specs[node.id] = spec
	end
	spec.y = node.y + node.size * 0.08 + screen.scroll
	return spec
end

local function thumbSpecs(screen, h)
	local specs = {}
	for _, node in ipairs(screen.view.nodes) do
		local y, reach = node.y + screen.scroll, node.size * THUMB_MARGIN
		if node.state ~= "locked" and y > -reach and y < h + reach then
			specs[#specs + 1] = thumbSpec(screen, node)
		end
	end
	return specs
end

function M.present(screen, dt, info)
	screen.clock = screen.clock + dt
	M.layout(screen, info)
	fling(screen, dt)
	screen.scroll = screen.scroll + (screen.goal_scroll - screen.scroll) * (1 - math.exp(-SCROLL_RATE * dt))
	local eye_from = cameras.setScreen("board", info.w, info.h, FOV)
	thumbs.present(screen.thumbs, thumbSpecs(screen, info.h), dt, eye_from, info.settings)
	screen.model.scroll = screen.scroll
	models.publish("select", screen.model)
	models.publish("hud", { buttons = { backButton(info) }, labels = {} })
end

return hot(..., M)
