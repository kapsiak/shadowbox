local hot = require "core.hot"
local motion = require "view.motion"
local M = {}

local PITCH_MIN, PITCH_MAX = math.rad(-89.5), math.rad(5)
local ZOOM_MIN, ZOOM_MAX = 0.45, 1.8
local EASE_RATE = 10
local KEY_RATE = math.rad(120)
local TRACK_RATE = 25
local FRICTION = 5
local MIN_SPEED = 0.1
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

function M.new(target, radius, footprint)
	local iso = M.views.iso
	local goal = { yaw = iso.yaw, pitch = iso.pitch, zoom = 1, ortho = 0 }
	return { target = target, radius = radius, footprint = footprint, goal = goal, current = copy(goal),
		direct = false, moved = { yaw = 0, pitch = 0 }, speed = { yaw = 0, pitch = 0 }, coasting = false }
end

local function sphereFit(radius, tan)
	return radius * math.sqrt(1 + tan * tan) / tan
end

-- The distance at which the board fills a view whose half extents have tangents tan_h, tan_v.
-- Up the view the bounding sphere must fit; across it, each level of the footprint's cylinder
-- is a sphere of the footprint's radius, at most half_height nearer the camera. Neither
-- depends on yaw or pitch, so the board keeps its size as the camera turns.
function M.fitDistance(rig, tan_h, tan_v)
	local f = rig.footprint
	local across = f and sphereFit(f.radius, tan_h) + f.half_height or sphereFit(rig.radius, tan_h)
	return math.max(sphereFit(rig.radius, tan_v), across)
end

local function turn(rig, dyaw, dpitch)
	local g = rig.goal
	local pitch = clamp(g.pitch + dpitch, PITCH_MIN, PITCH_MAX)
	rig.moved.yaw, rig.moved.pitch = rig.moved.yaw + dyaw, rig.moved.pitch + pitch - g.pitch
	g.yaw, g.pitch, g.ortho = g.yaw + dyaw, pitch, 0
end

function M.orbitBy(rig, dyaw, dpitch)
	if not rig.direct then
		rig.goal.yaw, rig.goal.pitch = rig.current.yaw, rig.current.pitch
	end
	rig.coasting, rig.direct = false, true
	turn(rig, dyaw, dpitch)
end

function M.release(rig)
	local v = rig.speed
	rig.coasting = rig.direct and math.max(math.abs(v.yaw), math.abs(v.pitch)) >= MIN_SPEED
end

function M.halt(rig)
	rig.coasting = false
	rig.speed.yaw, rig.speed.pitch = 0, 0
end

function M.orbitAt(rig, yaw_rate, pitch_rate, dt)
	M.orbitBy(rig, yaw_rate * KEY_RATE * dt, pitch_rate * KEY_RATE * dt)
end

function M.zoomBy(rig, factor)
	rig.goal.zoom = clamp(rig.goal.zoom * factor, ZOOM_MIN, ZOOM_MAX)
end

function M.snapTo(rig, name)
	local v = M.views[name]
	M.halt(rig)
	rig.direct = false
	local delta = (v.yaw - rig.goal.yaw + math.pi) % (2 * math.pi) - math.pi
	rig.goal.yaw = rig.goal.yaw + delta
	rig.goal.pitch = v.pitch
	rig.goal.ortho = v.ortho
end

local FIELDS = { "yaw", "pitch", "zoom", "ortho" }

local function track(rig, dt)
	local m, v = rig.moved, rig.speed
	if dt > 0 and (m.yaw ~= 0 or m.pitch ~= 0 or v.yaw ~= 0 or v.pitch ~= 0) then
		local k = motion.blend(TRACK_RATE, dt)
		v.yaw = motion.ease(v.yaw, m.yaw / dt, k, 1e-3)
		v.pitch = motion.ease(v.pitch, m.pitch / dt, k, 1e-3)
	end
	m.yaw, m.pitch = 0, 0
end

local function coast(rig, dt)
	local v, f = rig.speed, math.exp(-FRICTION * dt)
	turn(rig, v.yaw * dt, v.pitch * dt)
	rig.moved.yaw, rig.moved.pitch = 0, 0
	v.yaw, v.pitch = v.yaw * f, v.pitch * f
	if rig.goal.pitch == PITCH_MIN or rig.goal.pitch == PITCH_MAX then
		v.pitch = 0
	end
	rig.coasting = math.max(math.abs(v.yaw), math.abs(v.pitch)) >= MIN_SPEED
end

function M.step(rig, dt)
	if rig.coasting then
		coast(rig, dt)
	else
		track(rig, dt)
	end
	local k = motion.blend(EASE_RATE, dt)
	local c, g, moved = rig.current, rig.goal, false
	if rig.direct then
		moved = c.yaw ~= g.yaw or c.pitch ~= g.pitch
		c.yaw, c.pitch = g.yaw, g.pitch
	end
	for _, field in ipairs(FIELDS) do
		local v = motion.ease(c[field], g[field], k, 1e-5)
		moved = moved or v ~= c[field]
		c[field] = v
	end
	return moved
end

function M.rotation(rig)
	return vmath.quat_rotation_y(rig.current.yaw) * vmath.quat_rotation_x(rig.current.pitch)
end

function M.eyeDirection(rig)
	return vmath.rotate(M.rotation(rig), vmath.vector3(0, 0, 1))
end

function M.lens(rig, aspect, insets)
	local c = rig.current
	local t = c.ortho * c.ortho * (3 - 2 * c.ortho)
	local fov = math.exp(math.log(FOV) + (math.log(FOV_ORTHO) - math.log(FOV)) * t)
	local tan_v = math.tan(fov / 2)
	local tan_h = tan_v * aspect
	local distance = M.fitDistance(rig, tan_h * (1 - insets.left - insets.right), tan_v * (1 - insets.top - insets.bottom))
		* c.zoom
	local rotation = M.rotation(rig)
	local shift_x = (insets.right - insets.left) * distance * tan_h
	local shift_y = (insets.top - insets.bottom) * distance * tan_v
	local position = rig.target + vmath.rotate(rotation, vmath.vector3(shift_x, shift_y, distance))
	return position, rotation, fov, math.max(0.05, distance - 4 * rig.radius), distance + 4 * rig.radius
end

local ORTHO_XRAY = 0.55

function M.xray(rig)
	return rig.current.ortho * ORTHO_XRAY
end

return hot(..., M)
