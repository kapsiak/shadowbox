-- View and projection matrices for each render pass ("board", "tray"). Written once per frame
-- by main.script and read by the render script and picking, so drawing and picking always
-- agree with the camera that was just placed.
local M = {}

local passes = {}

-- Places a perspective camera at `position` with `rotation`, looking down its local -z.
function M.set(name, position, rotation, fov, aspect, near, far)
	local view = vmath.inv(vmath.matrix4_compose(position, rotation, vmath.vector3(1, 1, 1)))
	local proj = vmath.matrix4_perspective(fov, aspect, near, far)
	passes[name] = { view = view, proj = proj, frustum = proj * view, inverse = vmath.inv(proj * view) }
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

return M
