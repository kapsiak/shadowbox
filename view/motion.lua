local hot = require "core.hot"
local M = {}

function M.blend(rate, dt)
	return 1 - math.exp(-rate * dt)
end

function M.approach(current, goal, k)
	return current + (goal - current) * k
end

function M.ease(current, goal, k, epsilon)
	local v = current + (goal - current) * k
	return math.abs(goal - v) < (epsilon or 1e-4) and goal or v
end

function M.spring(x, v, target, dt, omega, zeta)
	local a = (target - x) * (omega * omega) - v * (2 * zeta * omega)
	v = v + a * dt
	return x + v * dt, v
end

return hot(..., M)
