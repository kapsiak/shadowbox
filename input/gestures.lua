-- Turns device-agnostic raw input events into gestures. Pure: no Defold APIs.
--
-- Raw events:
--   { kind = "pointer", button = "primary"|"secondary", x, y, pressed, released }
--   { kind = "touches", points = { { id, x, y, pressed, released }, ... } }
--   { kind = "wheel", amount, start }
--   { kind = "key", key, name, pressed, released }    key: the physical key; name: its action or nil
--   { kind = "hover", x, y }
--   { kind = "blur" }    the window lost focus, so held keys and buttons will not report release
-- Gestures:
--   tap { button, x, y }
--   drag_start { button, x, y, touch }, drag_move { button, x, y, dx, dy, multi }, drag_end { button, x, y }
--   two_finger { scale, twist }        relative scale and twist angle (radians) since the last event
--   second_move { dx, dy }, second_up  another finger moving while the first stays down; lifting it
--   wheel { amount, start } (start: the first step of a scroll gesture), key { key, name, pressed, released }, hover { x, y } (pointer moved, no button)
--   blur (as the raw event)
--
-- On touch devices the first finger also arrives as the primary pointer; `multi` marks pointer
-- moves made while two or more fingers are down, so receivers can treat them as part of a pinch.
local hot = require "core.hot"
local M = {}

function M.new(drag_threshold)
	return { threshold = drag_threshold, pointers = {}, touches = {}, order = 0, multi = false, pair = nil }
end

local function moved(rec, p)
	local mx, my = p.x - p.x0, p.y - p.y0
	return mx * mx + my * my >= rec.threshold * rec.threshold
end

local function onPointer(rec, ev, out)
	local p = rec.pointers[ev.button]
	if ev.pressed or not p then
		rec.pointers[ev.button] = { x0 = ev.x, y0 = ev.y, x = ev.x, y = ev.y, dragging = false, multi = false }
		return
	end
	-- A release reports where the pointer last moved; release coordinates are not trusted.
	local x, y = ev.x, ev.y
	if ev.released then
		x, y = p.x, p.y
	end
	local dx, dy = x - p.x, y - p.y
	p.x, p.y = x, y
	p.multi = p.multi or rec.multi
	if not p.dragging and moved(rec, p) then
		p.dragging = true
		out[#out + 1] = { kind = "drag_start", button = ev.button, x = p.x0, y = p.y0, touch = next(rec.touches) ~= nil }
		dx, dy = x - p.x0, y - p.y0
	end
	if p.dragging and (dx ~= 0 or dy ~= 0) then
		out[#out + 1] = { kind = "drag_move", button = ev.button, x = x, y = y, dx = dx, dy = dy, multi = rec.multi }
	end
	if ev.released then
		if p.dragging then
			out[#out + 1] = { kind = "drag_end", button = ev.button, x = x, y = y }
		elseif not p.multi then
			out[#out + 1] = { kind = "tap", button = ev.button, x = p.x0, y = p.y0 }
		end
		rec.pointers[ev.button] = nil
	end
end

local function wrapAngle(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

local function pairOf(a, b)
	local dx, dy = b.x - a.x, b.y - a.y
	return { ids = a.id .. ":" .. b.id, distance = math.sqrt(dx * dx + dy * dy), angle = math.atan2(dy, dx) }
end

local function isFirst(rec, touch)
	for _, other in pairs(rec.touches) do
		if other.order < touch.order then
			return false
		end
	end
	return true
end

local function track(rec, t)
	local known = rec.touches[t.id]
	if t.pressed or not known then
		rec.order = rec.order + 1
		known = { id = t.id, x0 = t.x, y0 = t.y, order = rec.order }
		rec.touches[t.id] = known
	end
	known.x, known.y = t.x, t.y
	return known
end

local function onTouches(rec, ev, out)
	for _, t in ipairs(ev.points) do
		local last = rec.touches[t.id]
		local px, py = last and last.x, last and last.y
		local known = track(rec, t)
		local second = not isFirst(rec, known)
		if second and px and not t.pressed and not t.released and (known.x ~= px or known.y ~= py) then
			out[#out + 1] = { kind = "second_move", dx = known.x - px, dy = known.y - py }
		end
		if t.released then
			if second then
				out[#out + 1] = { kind = "second_up" }
			end
			rec.touches[t.id] = nil
		end
	end
	local active = {}
	for _, known in pairs(rec.touches) do
		active[#active + 1] = known
	end
	table.sort(active, function(a, b) return a.order < b.order end)
	rec.multi = #active >= 2
	if not rec.multi then
		rec.pair = nil
		return
	end
	local pair = pairOf(active[1], active[2])
	local last = rec.pair
	if last and last.ids == pair.ids and last.distance > 0 then
		out[#out + 1] = { kind = "two_finger", scale = pair.distance / last.distance, twist = wrapAngle(pair.angle - last.angle) }
	end
	rec.pair = pair
end

-- Feeds one raw event; returns the gestures it completes, in order.
function M.feed(rec, ev)
	local out = {}
	if ev.kind == "pointer" then
		onPointer(rec, ev, out)
	elseif ev.kind == "touches" then
		onTouches(rec, ev, out)
	elseif ev.kind == "wheel" then
		out[1] = { kind = "wheel", amount = ev.amount, start = ev.start }
	elseif ev.kind == "key" then
		out[1] = { kind = "key", key = ev.key, name = ev.name, pressed = ev.pressed, released = ev.released }
	elseif ev.kind == "hover" then
		out[1] = { kind = "hover", x = ev.x, y = ev.y }
	elseif ev.kind == "blur" then
		out[1] = ev
	end
	return out
end

return hot(..., M)
