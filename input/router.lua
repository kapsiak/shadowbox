-- Gives on-screen controls first claim on input. A pointer or touch that starts on a control
-- belongs to that control until it lifts; everything else passes through to the gestures.
-- Pure: hit testing is answered by the `hit(x, y)` function the caller supplies.
--
-- Claimed input becomes control events { id, phase = "press" | "move" | "release", x, y },
-- so buttons can act on press and sliders can follow a drag.
--
-- The first finger on a touch device arrives both as the primary pointer and as a touch, so
-- control events come from pointers and from touches other than the first.
local hot = require "core.hot"
local M = {}

function M.new()
	return { pointers = {}, touches = {}, first_touch = nil }
end

local function emit(events, id, phase, x, y)
	events[#events + 1] = { id = id, phase = phase, x = x, y = y }
end

local function routePointer(router, ev, hit, events)
	if ev.pressed then
		local id = hit(ev.x, ev.y)
		router.pointers[ev.button] = id
		if id then
			emit(events, id, "press", ev.x, ev.y)
			return nil
		end
		return ev
	end
	local owner = router.pointers[ev.button]
	if not owner then
		return ev
	end
	emit(events, owner, ev.released and "release" or "move", ev.x, ev.y)
	if ev.released then
		router.pointers[ev.button] = nil
	end
	return nil
end

local function routeTouches(router, ev, hit, events)
	local points = {}
	for _, t in ipairs(ev.points) do
		if t.pressed then
			router.first_touch = router.first_touch or t.id
			router.touches[t.id] = hit(t.x, t.y)
		end
		local owner = router.touches[t.id]
		if not owner then
			points[#points + 1] = t
		elseif t.id ~= router.first_touch then
			emit(events, owner, t.pressed and "press" or t.released and "release" or "move", t.x, t.y)
		end
		if t.released then
			router.touches[t.id] = nil
			if t.id == router.first_touch then
				router.first_touch = nil
			end
		end
	end
	return { kind = "touches", points = points }
end

-- Returns the event to pass on to gestures (or nil when claimed), and appends control events.
function M.route(router, ev, hit, events)
	if ev.kind == "pointer" then
		return routePointer(router, ev, hit, events)
	elseif ev.kind == "touches" then
		return routeTouches(router, ev, hit, events)
	end
	return ev
end

return hot(..., M)
