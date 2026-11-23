-- Turns device-agnostic raw input events into gestures. Pure: no Defold APIs.
--
-- Raw events:
--   { kind = "pointer", button = "primary"|"secondary", x, y, pressed, released }
--   { kind = "touches", points = { { id, x, y, pressed, released }, ... } }
--   { kind = "wheel", amount, start }
--   { kind = "key", name, pressed, released }
--   { kind = "hover", x, y }
-- Gestures:
--   tap { button, x, y }
--   drag_start { button, x, y }, drag_move { button, x, y, dx, dy, multi }, drag_end { button, x, y }
--   two_finger { scale, twist }        relative scale and twist angle (radians) since the last event
--   second_tap { x, y }                a quick touch by another finger while the first stays down
--   wheel { amount, start } (start: the first step of a scroll gesture), key { name, pressed, released }, hover { x, y } (pointer moved, no button)
--
-- On touch devices the first finger also arrives as the primary pointer; `multi` marks pointer
-- moves made while two or more fingers are down, so receivers can treat them as part of a pinch.
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
		out[#out + 1] = { kind = "drag_start", button = ev.button, x = p.x0, y = p.y0 }
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
		local known = track(rec, t)
		if t.released then
			if not isFirst(rec, known) and not moved(rec, known) and not known.pinched then
				out[#out + 1] = { kind = "second_tap", x = t.x, y = t.y }
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
		pair.start = last.start
		out[#out + 1] = { kind = "two_finger", scale = pair.distance / last.distance, twist = wrapAngle(pair.angle - last.angle) }
		local start = pair.start
		if math.abs(pair.distance / start.distance - 1) > 0.08 or math.abs(wrapAngle(pair.angle - start.angle)) > 0.12 then
			active[1].pinched, active[2].pinched = true, true
		end
	else
		pair.start = { distance = math.max(pair.distance, 1), angle = pair.angle }
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
		out[1] = { kind = "key", name = ev.name, pressed = ev.pressed, released = ev.released }
	elseif ev.kind == "hover" then
		out[1] = { kind = "hover", x = ev.x, y = ev.y }
	end
	return out
end

return M
