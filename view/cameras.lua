-- View and projection matrices for each render pass ("board", "tray", "card", "thumbs"). Written
-- by the screens in the present phase and read by the render script and picking, so drawing and
-- picking always agree with the camera that was just placed.
local hot = require "core.hot"
local M = {}

local passes = {}

-- A perspective camera at `position` with `rotation`, looking down its local -z.
local function lens(position, rotation, fov, aspect, near, far)
	local view = vmath.inv(vmath.matrix4_compose(position, rotation, vmath.vector3(1, 1, 1)))
	local proj = vmath.matrix4_perspective(fov, aspect, near, far)
	local frustum = proj * view
	return { view = view, proj = proj, frustum = frustum, inverse = vmath.inv(frustum), options = { frustum = frustum } }
end

function M.set(name, position, rotation, fov, aspect, near, far)
	passes[name] = lens(position, rotation, fov, aspect, near, far)
end

-- One view of a snapshot pass: a camera (as M.set) drawing into a rectangle of the target
-- (pixels, origin bottom left).
function M.shot(position, rotation, fov, aspect, near, far, x, y, w, h)
	local shot = lens(position, rotation, fov, aspect, near, far)
	shot.viewport = { x = x, y = y, w = w, h = h }
	return shot
end

-- A pass drawn into the render target resource named `target` (render/game.render) rather than
-- the screen: each shot into its own viewport, after emptying the target when `clear`.
function M.setShots(name, target, clear, shots)
	passes[name] = { target = target, clear = clear, shots = shots }
end

-- Draws the pass into a window rectangle (pixels, origin bottom left) instead of the whole frame.
function M.setViewport(name, x, y, w, h)
	passes[name].viewport = { x = math.floor(x), y = math.floor(y), w = math.ceil(w), h = math.ceil(h) }
end

function M.clear(name)
	passes[name] = nil
end

function M.get(name)
	return passes[name]
end

-- The world-space ray through screen point (x, y) of a w x h screen, as plain { x, y, z } tables.
function M.ray(name, x, y, w, h)
	local inverse = passes[name].inverse
	local nx, ny = 2 * x / w - 1, 2 * y / h - 1
	local near = inverse * vmath.vector4(nx, ny, -1, 1)
	local far = inverse * vmath.vector4(nx, ny, 1, 1)
	local a = vmath.vector3(near.x / near.w, near.y / near.w, near.z / near.w)
	local b = vmath.vector3(far.x / far.w, far.y / far.w, far.z / far.w)
	local dir = vmath.normalize(b - a)
	return { a.x, a.y, a.z }, { dir.x, dir.y, dir.z }
end

return hot(..., M)
