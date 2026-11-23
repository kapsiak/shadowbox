-- An orbit camera rig. `goal` is where input puts the camera; `current` eases toward it.
-- Zoom is relative to the distance that fits the board. `ortho` in [0, 1] blends toward an
-- orthographic look by narrowing the field of view while backing away (a dolly zoom),
-- so framing is preserved and the camera stays an ordinary perspective camera.
local hot = require "core.hot"
local M = {}

local PITCH_MIN, PITCH_MAX = math.rad(-89.5), math.rad(5)
local ZOOM_MIN, ZOOM_MAX = 0.45, 1.8
local EASE_RATE = 10
local KEY_RATE = math.rad(120)
local FOV = 0.6
local FOV_ORTHO = 0.0015

M.views = {
	front = { yaw = 0, pitch = 0, ortho = 1 },
	side = { yaw = math.rad(90), pitch = 0, ortho = 1 },
	top = { yaw = 0, pitch = PITCH_MIN, ortho = 1 },
	iso = { yaw = math.rad(35), pitch = math.rad(-28), ortho = 0 },
}

local function clamp(x, lo, hi)
	return math.max(lo, math.min(hi, x))
end

local function copy(p)
	return { yaw = p.yaw, pitch = p.pitch, zoom = p.zoom, ortho = p.ortho }
end

-- target: vector3 the camera orbits; radius: bounding radius to keep in frame.
function M.new(target, radius)
	local iso = M.views.iso
	local goal = { yaw = iso.yaw, pitch = iso.pitch, zoom = 1, ortho = 0 }
	return { target = target, radius = radius, goal = goal, current = copy(goal) }
end

function M.orbitBy(rig, dyaw, dpitch)
	rig.goal.yaw = rig.goal.yaw + dyaw
	rig.goal.pitch = clamp(rig.goal.pitch + dpitch, PITCH_MIN, PITCH_MAX)
	rig.goal.ortho = 0
end

function M.orbitAt(rig, yaw_rate, pitch_rate, dt)
	M.orbitBy(rig, yaw_rate * KEY_RATE * dt, pitch_rate * KEY_RATE * dt)
end

function M.zoomBy(rig, factor)
	rig.goal.zoom = clamp(rig.goal.zoom * factor, ZOOM_MIN, ZOOM_MAX)
end

-- Snaps to a named view along the shortest yaw path.
function M.snapTo(rig, name)
	local v = M.views[name]
	local delta = (v.yaw - rig.goal.yaw + math.pi) % (2 * math.pi) - math.pi
	rig.goal.yaw = rig.goal.yaw + delta
	rig.goal.pitch = v.pitch
	rig.goal.ortho = v.ortho
end

function M.step(rig, dt)
	local k = 1 - math.exp(-EASE_RATE * dt)
	local c, g = rig.current, rig.goal
	for _, field in ipairs({ "yaw", "pitch", "zoom", "ortho" }) do
		c[field] = c[field] + (g[field] - c[field]) * k
	end
end

function M.rotation(rig)
	return vmath.quat_rotation_y(rig.current.yaw) * vmath.quat_rotation_x(rig.current.pitch)
end

-- Unit vector from the target toward the camera.
function M.eyeDirection(rig)
	return vmath.rotate(M.rotation(rig), vmath.vector3(0, 0, 1))
end

-- Camera placement for the current pose. `aspect` is the screen's; `insets` gives the screen
-- fractions ({ left, right, top, bottom }) the board must keep clear of. The board is fit to
-- the remaining region by shifting the camera sideways (not turning it), so the view keeps
-- its angle. Returns position, rotation, fov, near, far.
function M.lens(rig, aspect, insets)
	local c = rig.current
	local t = c.ortho * c.ortho * (3 - 2 * c.ortho)
	local fov = math.exp(math.log(FOV) + (math.log(FOV_ORTHO) - math.log(FOV)) * t)
	local tan_v = math.tan(fov / 2)
	local tan_h = tan_v * aspect
	local fit_tan = math.min(tan_v * (1 - insets.top - insets.bottom), tan_h * (1 - insets.left - insets.right))
	local distance = rig.radius / math.sin(math.atan(fit_tan)) * c.zoom
	local rotation = M.rotation(rig)
	local shift_x = (insets.right - insets.left) * distance * tan_h
	local shift_y = (insets.top - insets.bottom) * distance * tan_v
	local position = rig.target + vmath.rotate(rotation, vmath.vector3(shift_x, shift_y, distance))
	return position, rotation, fov, math.max(0.05, distance - 4 * rig.radius), distance + 4 * rig.radius
end

-- How see-through cubes should be (0 opaque .. 1 fully x-rayed), following the ortho blend.
function M.xray(rig)
	return rig.current.ortho
end

return hot(..., M)
