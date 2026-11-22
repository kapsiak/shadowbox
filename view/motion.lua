-- Frame-rate independent easing helpers. Values may be numbers or vmath vectors.
local M = {}

-- Fraction of the remaining distance to cover this frame when easing at `rate` per second.
function M.blend(rate, dt)
	return 1 - math.exp(-rate * dt)
end

function M.approach(current, goal, k)
	return current + (goal - current) * k
end

-- One step of a damped spring toward `target`. omega: stiffness (rad/s); zeta: damping
-- ratio (< 1 overshoots). Returns the new value and velocity.
function M.spring(x, v, target, dt, omega, zeta)
	local a = (target - x) * (omega * omega) - v * (2 * zeta * omega)
	v = v + a * dt
	return x + v * dt, v
end

return M
