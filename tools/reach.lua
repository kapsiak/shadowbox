-- Usage (from the project root): luajit tools/reach.lua [-p WxH] [-a orbit_degrees] levels/<pack>/<level>.lua ...
-- How easy each piece is to drag into its solution pose: pointer positions are swept over a
-- phone screen (-p, in dp; default 390x844) seen from the iso view (or turned by -a degrees),
-- and the area whose drop lands on the solution is reported in finger targets (44 dp squares).
-- "order": the pieces placed bottom up (hint order), each onto the ones before it;
-- "last": every other piece already placed. 0 means no pointer position reaches it.
-- -m contact (the game's placement) | score (prototype: nearest resting pose to the ray).
-- drift: mean dp between the pointer and the grabbed cube's centre where a pose is shown.
package.path = "./?.lua;./tools/?.lua;" .. package.path

local level = require "core.level"
local play = require "game.play"
local state = require "core.state"
local grid = require "core.grid"
local rules = require "core.rules"
local raycast = require "core.raycast"
local shape = require "core.shape"
local hud_layout = require "ui.hud_layout"

local STEP = 4
local FINGER = 44
local FOV = 0.6
local MARGIN, FLOOR_GAP = 0.3, 0.02
local ISO_YAW, ISO_PITCH = math.rad(35), math.rad(-28)

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

-- The board camera as view/orbit lens builds it, as a function from screen point to world ray.
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
	local fit_tan = math.min(tan_v * (1 - insets.top - insets.bottom), tan_h * (1 - insets.left - insets.right))
	local distance = radius / math.sin(math.atan(fit_tan))
	if os.getenv("FIT") == "cylinder" then
		local r_h = math.sqrt((hi[1] - lo[1]) ^ 2 + (hi[3] - lo[3]) ^ 2) / 2
		distance = math.max(r_h / math.sin(math.atan(tan_h * (1 - insets.left - insets.right))),
			radius / math.sin(math.atan(tan_v * (1 - insets.top - insets.bottom))))
	end
	local offset = rotate(yaw, pitch, { (insets.right - insets.left) * distance * tan_h,
		(insets.top - insets.bottom) * distance * tan_v, distance })
	local origin = { target[1] + offset[1], target[2] + offset[2], target[3] + offset[3] }
	return h / 2 / tan_v, function(x, y)
		local d = rotate(yaw, pitch, { (2 * x / w - 1) * tan_h, (2 * y / h - 1) * tan_v, -1 })
		local n = math.sqrt(d[1] ^ 2 + d[2] ^ 2 + d[3] ^ 2)
		return origin, { d[1] / n, d[2] / n, d[3] / n }
	end, layout.tray.y + layout.tray.h
end

local NEIGHBOURS = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }

-- Whether a piece at `cells` touches the floor, the back walls or another piece.
local function touches(size, occupied, cells)
	for _, c in ipairs(cells) do
		if c[1] == 0 or c[2] == 0 or c[3] == 0 then
			return true
		end
		for _, n in ipairs(NEIGHBOURS) do
			local m = { c[1] + n[1], c[2] + n[2], c[3] + n[3] }
			if grid.contains(size, m) and occupied[grid.index(size, m)] then
				return true
			end
		end
	end
	return false
end

-- How many faces of `cells` touch the floor, the back walls or another piece, per cube.
local function snugness(size, occupied, cells)
	local faces = 0
	for _, c in ipairs(cells) do
		for _, n in ipairs(NEIGHBOURS) do
			local m = { c[1] + n[1], c[2] + n[2], c[3] + n[3] }
			if m[1] < 0 or m[2] < 0 or m[3] < 0 or (grid.contains(size, m) and occupied[grid.index(size, m)]) then
				faces = faces + 1
			end
		end
	end
	return faces / #cells
end

-- Every legal pose of `id` in orientation `o` that touches something.
local function restingPoses(lvl, occupied, id, o)
	local out, size = {}, lvl.size
	for x = 0, size[1] - 1 do
		for y = 0, size[2] - 1 do
			for z = 0, size[3] - 1 do
				local pose = { cell = { x, y, z }, orient = o }
				local cells = shape.cellsAt(lvl.pieces[id].shape, pose)
				if rules.checkPlace(lvl, occupied, id, pose) and touches(size, occupied, cells) then
					pose.snug = snugness(size, occupied, cells)
					out[#out + 1] = pose
				end
			end
		end
	end
	return out
end

local DEPTH_WEIGHT = tonumber(os.getenv("DEPTH_WEIGHT") or "0.3")
local SNAP = tonumber(os.getenv("SNAP") or "1")
local SNUG = tonumber(os.getenv("SNUG") or "0")

-- The resting pose whose grabbed cube lies nearest the ray, in angle; depth away from the first
-- surface the ray meets costs DEPTH_WEIGHT as much. Returns it and its angular miss.
local function scored(lvl, occupied, poses, origin, dir)
	local size = lvl.size
	local _, _, t_hit = raycast.firstHit(size, origin, dir, function(c)
		return occupied[grid.index(size, c)] ~= nil
	end)
	local best, best_score, best_miss
	for _, pose in ipairs(poses) do
		local v = { pose.cell[1] + 0.5 - origin[1], pose.cell[2] + 0.5 - origin[2], pose.cell[3] + 0.5 - origin[3] }
		local t = v[1] * dir[1] + v[2] * dir[2] + v[3] * dir[3]
		local px, py, pz = v[1] - t * dir[1], v[2] - t * dir[2], v[3] - t * dir[3]
		local off = math.sqrt(px * px + py * py + pz * pz)
		local miss = off / t
		local depth = t_hit and math.abs(t - (t_hit - 0.5)) or 0
		local score = (off + DEPTH_WEIGHT * depth - SNUG * pose.snug) / t
		if off <= SNAP and (not best_score or score < best_score) then
			best, best_score, best_miss = pose, score, miss
		end
	end
	return best, best_miss
end

-- Finger targets' worth of screen area whose drop puts `id` at its solution pose over `placed`.
local function angularMiss(pose, origin, dir)
	local v = { pose.cell[1] + 0.5 - origin[1], pose.cell[2] + 0.5 - origin[2], pose.cell[3] + 0.5 - origin[3] }
	local t = v[1] * dir[1] + v[2] * dir[2] + v[3] * dir[3]
	local px, py, pz = v[1] - t * dir[1], v[2] - t * dir[2], v[3] - t * dir[3]
	return math.sqrt(px * px + py * py + pz * pz) / t
end

local drift = { sum = 0, n = 0 }

-- Finger targets' worth of screen area whose drop puts `id` at its solution pose over `placed`;
-- `px_per_radian` turns angular misses into dp for the drift tally.
local function reach(lvl, placed, id, ray, w, h, tray_top, method, px_per_radian)
	local s = play.new(lvl, placed)
	local goal = lvl.solution[id]
	local occupied = grid.occupancy(lvl, placed, id)
	local poses = method == "score" and restingPoses(lvl, occupied, id, goal.orient)
	local hits = 0
	for y = tray_top + STEP / 2, h, STEP do
		for x = STEP / 2, w, STEP do
			local origin, dir = ray(x, y)
			local pose, miss
			if poses then
				pose, miss = scored(lvl, occupied, poses, origin, dir)
			else
				s.held[id] = goal.orient
				play.grab(s, id, nil)
				play.dragTo(s, origin, dir)
				local c = s.drag.candidate
				pose = c and c.ok and c.pose
				miss = pose and angularMiss(pose, origin, dir)
				s.drag = nil
			end
			if pose then
				drift.sum, drift.n = drift.sum + miss * px_per_radian, drift.n + 1
			end
			if pose and state.samePose(pose, goal) then
				hits = hits + 1
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

local w, h, turn, method = 390, 844, 0, "contact"
local paths = {}
local i = 1
while arg[i] do
	if arg[i] == "-p" then
		w, h = arg[i + 1]:match("(%d+)x(%d+)")
		w, h = tonumber(w), tonumber(h)
		i = i + 1
	elseif arg[i] == "-m" then
		method = arg[i + 1]
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
	local px_per_radian, ray, tray_top = camera(lvl, w, h, ISO_YAW + turn, ISO_PITCH)
	local order, placed, cells = hintOrder(lvl), {}, {}
	for _, id in ipairs(order) do
		local all = {}
		for other, pose in ipairs(lvl.solution) do
			all[other] = other ~= id and pose or nil
		end
		local a, b = reach(lvl, placed, id, ray, w, h, tray_top, method, px_per_radian),
			reach(lvl, all, id, ray, w, h, tray_top, method, px_per_radian)
		cells[#cells + 1] = ("%d:%.1f/%.1f"):format(id, a, b)
		placed[id] = lvl.solution[id]
	end
	print(("%-36s %s  drift %.0f"):format(path, table.concat(cells, "  "), drift.sum / drift.n))
	drift.sum, drift.n = 0, 0
end
