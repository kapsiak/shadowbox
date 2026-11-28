package.path = "./?.lua;./tools/?.lua;" .. package.path

local level = require "core.level"
local play = os.getenv("PLAY") and dofile(os.getenv("PLAY")) or require "game.play"
local state = require "core.state"
local hud_layout = require "ui.hud_layout"
local orbit = require "view.orbit"

local STEP = 4
local FINGER = 44
local FOV = 0.6
local MARGIN, FLOOR_GAP = 0.3, 0.02
local ISO_YAW = math.rad(35)

local function loadLevel(path)
	local f = assert(io.open(path, "r"))
	local source = f:read("*a")
	f:close()
	return assert(level.load(source, path))
end

local function rotate(yaw, pitch, v)
	local cp, sp, cy, sy = math.cos(pitch), math.sin(pitch), math.cos(yaw), math.sin(yaw)
	local x, y, z = v[1], v[2] * cp - v[3] * sp, v[2] * sp + v[3] * cp
	return { x * cy + z * sy, y, -x * sy + z * cy }
end

local function camera(lvl, w, h, yaw, pitch)
	local s = lvl.size
	local lo = { -MARGIN, -FLOOR_GAP, -MARGIN }
	local hi = { s[1] + MARGIN, s[2], s[3] + MARGIN }
	local target, radius = {}, 0
	for a = 1, 3 do
		target[a] = (lo[a] + hi[a]) / 2
		radius = radius + (hi[a] - lo[a]) ^ 2
	end
	radius = math.sqrt(radius) / 2
	local layout = hud_layout.compute({ w = w, h = h, scale = 1, safe = { left = 0, right = 0, top = 0, bottom = 0 } },
		{ title = lvl.name or "", subtitle = "" })
	local insets = layout.insets
	local tan_v = math.tan(FOV / 2)
	local tan_h = tan_v * w / h
	local footprint = { radius = math.sqrt((hi[1] - lo[1]) ^ 2 + (hi[3] - lo[3]) ^ 2) / 2, half_height = (hi[2] - lo[2]) / 2 }
	local distance = orbit.fitDistance({ radius = radius, footprint = footprint },
		tan_h * (1 - insets.left - insets.right), tan_v * (1 - insets.top - insets.bottom))
	local offset = rotate(yaw, pitch, { (insets.right - insets.left) * distance * tan_h,
		(insets.top - insets.bottom) * distance * tan_v, distance })
	local origin = { target[1] + offset[1], target[2] + offset[2], target[3] + offset[3] }
	return h / 2 / tan_v, function(x, y)
		local d = rotate(yaw, pitch, { (2 * x / w - 1) * tan_h, (2 * y / h - 1) * tan_v, -1 })
		local n = math.sqrt(d[1] ^ 2 + d[2] ^ 2 + d[3] ^ 2)
		return origin, { d[1] / n, d[2] / n, d[3] / n }
	end, layout.tray.y + layout.tray.h
end

local function angularMiss(pose, origin, dir)
	local v = { pose.cell[1] + 0.5 - origin[1], pose.cell[2] + 0.5 - origin[2], pose.cell[3] + 0.5 - origin[3] }
	local t = v[1] * dir[1] + v[2] * dir[2] + v[3] * dir[3]
	local px, py, pz = v[1] - t * dir[1], v[2] - t * dir[2], v[3] - t * dir[3]
	return math.sqrt(px * px + py * py + pz * pz) / t
end

local drift = { sum = 0, n = 0 }
local sticky = { changed = 0, n = 0 }

local function sweep(s, points, fresh, order)
	local shown = {}
	for _, i in ipairs(order) do
		local d = s.drag
		if fresh then
			d.candidate = nil
		end
		play.dragTo(s, points[i][1], points[i][2])
		local c = d.candidate
		shown[i] = c and c.ok and c.pose or false
	end
	return shown
end

local function reach(lvl, placed, id, ray, w, h, tray_top, px_per_radian)
	local s = play.new(lvl, placed)
	local goal = lvl.solution[id]
	local points, forward, backward = {}, {}, {}
	for y = tray_top + STEP / 2, h, STEP do
		for x = STEP / 2, w, STEP do
			points[#points + 1] = { ray(x, y) }
			forward[#forward + 1] = #points
		end
	end
	for i = #points, 1, -1 do
		backward[#backward + 1] = i
	end
	s.held[id] = goal.orient
	play.grab(s, id, nil, points[1][2])
	local fresh = sweep(s, points, true, forward)
	local hits = 0
	for i, pose in ipairs(fresh) do
		if pose then
			drift.sum, drift.n = drift.sum + angularMiss(pose, points[i][1], points[i][2]) * px_per_radian, drift.n + 1
			hits = hits + (state.samePose(pose, goal) and 1 or 0)
		end
	end
	s.drag.candidate = nil
	for _, order in ipairs({ forward, backward }) do
		local run = sweep(s, points, false, order)
		for i, pose in ipairs(fresh) do
			if pose then
				local same = run[i] and state.samePose(pose, run[i])
				sticky.changed, sticky.n = sticky.changed + (same and 0 or 1), sticky.n + 1
			end
		end
	end
	return hits * STEP * STEP / (FINGER * FINGER)
end

local function hintOrder(lvl)
	local order = {}
	for id in ipairs(lvl.solution) do
		order[#order + 1] = id
	end
	local low = {}
	for id, pose in ipairs(lvl.solution) do
		low[id] = math.huge
		for _, c in ipairs(require("core.shape").cellsAt(lvl.pieces[id].shape, pose)) do
			low[id] = math.min(low[id], c[2])
		end
	end
	table.sort(order, function(a, b)
		if low[a] ~= low[b] then
			return low[a] < low[b]
		end
		return a < b
	end)
	return order
end

local w, h, turn, tilt = 390, 844, 0, 28
local paths = {}
local i = 1
while arg[i] do
	if arg[i] == "-p" then
		w, h = arg[i + 1]:match("(%d+)x(%d+)")
		w, h = tonumber(w), tonumber(h)
		i = i + 1
	elseif arg[i] == "-t" then
		tilt = tonumber(arg[i + 1])
		i = i + 1
	elseif arg[i] == "-a" then
		turn = math.rad(tonumber(arg[i + 1]))
		i = i + 1
	else
		paths[#paths + 1] = arg[i]
	end
	i = i + 1
end

for _, path in ipairs(paths) do
	local lvl = loadLevel(path)
	local px_per_radian, ray, tray_top = camera(lvl, w, h, ISO_YAW + turn, -math.rad(tilt))
	local order, placed, cells = hintOrder(lvl), {}, {}
	for _, id in ipairs(order) do
		local all = {}
		for other, pose in ipairs(lvl.solution) do
			all[other] = other ~= id and pose or nil
		end
		local a, b = reach(lvl, placed, id, ray, w, h, tray_top, px_per_radian),
			reach(lvl, all, id, ray, w, h, tray_top, px_per_radian)
		cells[#cells + 1] = ("%d:%.1f/%.1f"):format(id, a, b)
		placed[id] = lvl.solution[id]
	end
	print(("%-36s %s  drift %.0f  sticky %.1f%%"):format(path, table.concat(cells, "  "), drift.sum / drift.n,
		100 * sticky.changed / sticky.n))
	drift.sum, drift.n, sticky.changed, sticky.n = 0, 0, 0, 0
end
