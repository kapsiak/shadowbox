-- Frame-rate independent easing helpers. Values may be numbers or vmath vectors.
local hot = require "core.hot"
local M = {}

-- Fraction of the remaining distance to cover this frame when easing at `rate` per second.
function M.blend(rate, dt)
	return 1 - math.exp(-rate * dt)
end

function M.approach(current, goal, k)
	return current + (goal - current) * k
end

-- Like approach, for numbers, but lands on the goal once within `epsilon` (default 1e-4), so
-- an ease comes to rest and work waiting on it can stop.
function M.ease(current, goal, k, epsilon)
	local v = current + (goal - current) * k
	return math.abs(goal - v) < (epsilon or 1e-4) and goal or v
end

-- One step of a damped spring toward `target`. omega: stiffness (rad/s); zeta: damping
-- ratio (< 1 overshoots). Returns the new value and velocity.
function M.spring(x, v, target, dt, omega, zeta)
	local a = (target - x) * (omega * omega) - v * (2 * zeta * omega)
	v = v + a * dt
	return x + v * dt, v
end

return hot(..., M)
