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
--   press { button, x, y } (a pointer went down), tap { button, x, y }
--   drag_start { button, x, y, touch }, drag_move { button, x, y, dx, dy, multi }, drag_end { button, x, y }
--   two_finger { scale, twist, dx, dy, start }  relative scale, twist angle (radians) and the
--                                       pair's midpoint movement since the last event; `start`
--                                       marks a pair's first
--   second_up                           a finger other than the first lifted
--   wheel { amount, start } (start: the first step of a scroll gesture), key { key, name, pressed, released }, hover { x, y } (pointer moved, no button)
--   blur (as the raw event)
--   drag_cancel { button }        a second finger landed with the first (a pinch, not a drag)
-- Raw events may carry `t`, the time in seconds they arrived.
--
-- On touch devices the first finger also arrives as the primary pointer; `multi` marks pointer
-- moves made while two or more fingers are down, so receivers can treat them as part of a pinch.
-- Fingers landing within PAIR_WINDOW seconds of each other make a pinch: whatever the first one
-- started is cancelled and it reports nothing more until it lifts.
local hot = require "core.hot"
local M = {}

local PAIR_WINDOW = 0.15
-- A finger lifting rolls a little: a drag ends where the pointer rested SETTLE seconds before
-- release if it moved at most SLIP drag thresholds since.
local SETTLE = 0.1
local SLIP = 2
local TRAIL = 8

function M.new(drag_threshold)
	return { threshold = drag_threshold, pointers = {}, touches = {}, order = 0, multi = false, pair = nil }
end

local function moved(rec, p)
	local mx, my = p.x - p.x0, p.y - p.y0
	return mx * mx + my * my >= rec.threshold * rec.threshold
end

-- Keeps the pointer's last TRAIL positions and times, in a ring.
local function remember(p, t, x, y)
	local trail = p.trail
	trail.at = trail.at % TRAIL + 1
	local slot = trail[trail.at] or {}
	trail[trail.at] = slot
	slot.t, slot.x, slot.y = t, x, y
end

-- Where a drag released at time `now` ends: where it rested SETTLE seconds before, if it has
-- slipped only a little since; otherwise where it last moved.
local function settled(rec, p, now)
	local rest
	for _, slot in ipairs(p.trail) do
		if now and slot.t <= now - SETTLE and (not rest or slot.t > rest.t) then
			rest = slot
		end
	end
	local limit = SLIP * rec.threshold
	if rest and (rest.x - p.x) ^ 2 + (rest.y - p.y) ^ 2 <= limit * limit then
		return rest.x, rest.y
	end
	return p.x, p.y
end

local function onPointer(rec, ev, out)
	local p = rec.pointers[ev.button]
	if ev.pressed or not p then
		rec.pointers[ev.button] = { x0 = ev.x, y0 = ev.y, x = ev.x, y = ev.y, dragging = false, multi = false,
			cancelled = ev.pressed and ev.button == "primary" and rec.multi, trail = { at = 0 } }
		if ev.pressed then
			out[#out + 1] = { kind = "press", button = ev.button, x = ev.x, y = ev.y }
		end
		return
	end
	if p.cancelled then
		rec.pointers[ev.button] = not ev.released and p or nil
		return
	end
	-- A release reports where the pointer last moved; release coordinates are not trusted.
	local x, y = ev.x, ev.y
	if ev.released then
		x, y = p.x, p.y
	end
	if ev.released and p.dragging then
		x, y = settled(rec, p, ev.t)
	elseif ev.t then
		remember(p, ev.t, x, y)
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
	return { ids = a.id .. ":" .. b.id, distance = math.sqrt(dx * dx + dy * dy), angle = math.atan2(dy, dx),
		x = (a.x + b.x) / 2, y = (a.y + b.y) / 2 }
end

local function isFirst(rec, touch)
	for _, other in pairs(rec.touches) do
		if other.order < touch.order then
			return false
		end
	end
	return true
end

local function track(rec, t, now)
	local known = rec.touches[t.id]
	if t.pressed or not known then
		rec.order = rec.order + 1
		known = { id = t.id, x0 = t.x, y0 = t.y, order = rec.order, t0 = now }
		rec.touches[t.id] = known
	end
	known.x, known.y = t.x, t.y
	return known
end

-- The primary pointer reports nothing more until it lifts; a drag it started is cancelled.
local function cancelPrimary(rec, out)
	local p = rec.pointers.primary
	if p and not p.cancelled then
		p.cancelled = true
		if p.dragging then
			out[#out + 1] = { kind = "drag_cancel", button = "primary" }
		end
	end
end

local function firstTouch(rec)
	local first
	for _, known in pairs(rec.touches) do
		if not first or known.order < first.order then
			first = known
		end
	end
	return first
end

local function onTouches(rec, ev, out)
	for _, t in ipairs(ev.points) do
		local known = track(rec, t, ev.t)
		local second = not isFirst(rec, known)
		local first = second and t.pressed and firstTouch(rec)
		if first and ev.t and first.t0 and ev.t - first.t0 < PAIR_WINDOW then
			cancelPrimary(rec, out)
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
		out[#out + 1] = { kind = "two_finger", scale = pair.distance / last.distance,
			twist = wrapAngle(pair.angle - last.angle), dx = pair.x - last.x, dy = pair.y - last.y, start = last.start }
		pair.start = false
	else
		pair.start = true
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
