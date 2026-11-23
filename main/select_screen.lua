-- The level select screen: one chapter (pack) per page, its levels on a winding trail, each
-- open level shown as a live 3D thumbnail. Tapping an open level plays it; dragging up and down
-- (with a fling on release) or the wheel scrolls; swiping sideways, the arrow keys beside the
-- banner, the left and right keys, or a chapter's dot under the title turn the page.
-- Implements the screen contract used by main.script.
--
-- The layout is computed once per screen size and chapter and published with the scroll and
-- slide offsets, so scrolling moves one offset rather than rebuilding the page.
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
-- A turned page slides in from this fraction of the screen width and settles at SLIDE_RATE; a
-- swipe turns the page once it has moved TURN_AT of the width.
local SLIDE_FROM = 0.35
local SLIDE_RATE = 14
local TURN_AT = 0.12
local KEY_STEPS = { orbit_left = -1, orbit_right = 1 }

-- boards: the saved boards by level key; pool: the board pool (view/board_pool); last: the
-- level last played ({ pack, index }) or nil, whose chapter opens first.
function M.enter(catalog, saved, boards, pool, last)
	return {
		module = M, catalog = catalog, saved = saved, boards = boards, last = last,
		thumbs = thumbs.new(pool), specs = {}, model = {},
		clock = 0, velocity = 0, drag_velocity = 0, moved_at = -math.huge, slide = 0,
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

-- Lays out the page when the screen or the chapter changes; a chapter opens scrolled to the
-- current level when it holds it, else to its top.
function M.layout(screen, info)
	screen.info = info
	screen.chapter = screen.chapter or select_layout.chapterOf(screen.catalog, screen.saved, screen.last, info.settings.open_all)
	local key = frameKey(info) .. " " .. screen.chapter
	if key ~= screen.frame then
		local turned = screen.view_chapter ~= screen.chapter
		screen.frame, screen.view_chapter = key, screen.chapter
		screen.view = select_layout.compute(info, screen.catalog, screen.saved, screen.chapter)
		screen.model.layout = screen.view
		screen.specs = {}
		if turned then
			screen.scroll, screen.goal_scroll, screen.velocity = screen.view.focus, screen.view.focus, 0
		end
		screen.goal_scroll = clamped(screen, screen.goal_scroll)
	end
	return screen.view
end

local function backButton(info)
	local size = math.min(math.max(52 * info.scale, math.min(info.w, info.h) * 0.075), math.min(info.w, info.h) * 0.12)
	local margin = size * 0.35
	return { id = "back", x = info.safe.left + margin + size / 2, y = info.h - info.safe.top - margin - size / 2, size = size, group = "corner", enabled = true }
end

-- The back button and the page's arrow keys, which move with the page.
local function buttons(screen)
	local arrows, slide, scroll = screen.view.arrows, screen.slide, screen.scroll
	local function arrow(id, a, enabled)
		return { id = id, x = a.x + slide, y = a.y + scroll, size = a.size, group = "corner", enabled = enabled }
	end
	return {
		backButton(screen.info),
		arrow("page_prev", arrows.prev, screen.chapter > 1),
		arrow("page_next", arrows.next, screen.chapter < #screen.catalog.packs),
	}
end

-- Only the buttons are claimed; levels are not, so a drag that starts on one still scrolls.
function M.hit(screen, x, y)
	return hit.find(buttons(screen), x, y)
end

local button_intents = {
	back = { kind = "back" }, page_prev = { kind = "chapter", by = -1 }, page_next = { kind = "chapter", by = 1 },
}

function M.button(screen, ev, intents)
	if ev.phase == "press" then
		models.pressed("hud", ev.id)
		intents[#intents + 1] = button_intents[ev.id]
	end
end

-- The chapter whose dot lies under (x, y), or nil.
local function markAt(screen, x, y)
	for _, mark in ipairs(screen.view.marks) do
		if math.abs(x - mark.x) <= mark.hit / 2 and math.abs(y - screen.scroll - mark.y) <= mark.hit / 2 then
			return mark.chapter
		end
	end
end

local function onTap(screen, g, intents)
	if screen.velocity ~= 0 then
		intents[#intents + 1] = { kind = "grab" }
		return
	end
	local chapter = markAt(screen, g.x, g.y)
	if chapter then
		intents[#intents + 1] = { kind = "chapter", to = chapter }
		return
	end
	local id = hit.find(screen.view.nodes, g.x - screen.slide, g.y - screen.scroll)
	if id then
		intents[#intents + 1] = { kind = "open", key = id }
	end
end

-- A drag follows the axis it first moves along: up and down scrolls, sideways turns the page.
local function onDragMove(screen, g, intents)
	screen.drag_axis = screen.drag_axis or (math.abs(g.dx) > math.abs(g.dy) and "x" or "y")
	if screen.drag_axis == "x" then
		intents[#intents + 1] = { kind = "swipe", by = g.dx }
	else
		intents[#intents + 1] = { kind = "drag", by = g.dy }
	end
end

function M.gesture(screen, g, intents)
	if g.kind == "tap" and g.button == "primary" then
		onTap(screen, g, intents)
	elseif g.kind == "drag_start" then
		screen.drag_axis = nil
		intents[#intents + 1] = { kind = "grab" }
	elseif g.kind == "drag_move" and not g.multi then
		onDragMove(screen, g, intents)
	elseif g.kind == "drag_end" then
		intents[#intents + 1] = { kind = "release" }
	elseif g.kind == "key" and g.pressed and g.name == "menu" then
		intents[#intents + 1] = { kind = "back" }
	elseif g.kind == "key" and g.pressed and KEY_STEPS[g.name] then
		intents[#intents + 1] = { kind = "chapter", by = KEY_STEPS[g.name] }
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

-- Turns to `chapter` if it exists and differs; the new page slides in from the side it lies on.
local function turnTo(screen, chapter)
	if chapter == screen.chapter or not screen.catalog.packs[chapter] then
		return false
	end
	local dir = chapter > screen.chapter and 1 or -1
	screen.chapter = chapter
	screen.slide = screen.info.settings.reduced_motion and 0 or dir * screen.info.w * SLIDE_FROM
	audio.cue("ui_tap")
	return true
end

-- Applies one intent; returns a request for the app (see main.script) or nil.
function M.apply(screen, intent, dt)
	local kind = intent.kind
	if kind == "back" then
		return { to = "menu" }
	elseif kind == "open" then
		return openLevel(screen, intent.key)
	elseif kind == "chapter" then
		turnTo(screen, intent.to or screen.chapter + intent.by)
	elseif kind == "swipe" then
		local edge = (screen.chapter == 1 and intent.by > 0) or (screen.chapter == #screen.catalog.packs and intent.by < 0)
		screen.slide = screen.slide + intent.by * (edge and 0.3 or 1)
		screen.swiping = true
	elseif kind == "release" and screen.swiping then
		screen.swiping = false
		local limit = screen.info.w * TURN_AT
		if math.abs(screen.slide) > limit then
			turnTo(screen, screen.chapter + (screen.slide < 0 and 1 or -1))
		end
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

-- The thumbnail of `node`, made once per layout; only its position follows the scroll.
local function thumbSpec(screen, node)
	local spec = screen.specs[node.id]
	if not spec then
		local level = screen.catalog.packs[node.pack].levels[node.index]
		spec = { id = node.id, level = level, poses = thumbPoses(screen.boards[node.id], level, node.state), number = node.index, size = node.size }
		screen.specs[node.id] = spec
	end
	spec.x, spec.y = node.x + screen.slide, node.y + node.size * 0.08 + screen.scroll
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
	if not screen.swiping then
		screen.slide = screen.slide * math.exp(-SLIDE_RATE * dt)
		screen.slide = math.abs(screen.slide) < 0.5 and 0 or screen.slide
	end
	local eye_from = cameras.setScreen("board", info.w, info.h, FOV)
	thumbs.present(screen.thumbs, thumbSpecs(screen, info.h), dt, eye_from, info.settings)
	screen.model.scroll, screen.model.slide = screen.scroll, screen.slide
	models.publish("select", screen.model)
	models.publish("hud", { buttons = buttons(screen), labels = {} })
end

return hot(..., M)
