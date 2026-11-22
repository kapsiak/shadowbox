-- The projection panels: front and side walls plus the floor. Walls stand on the far side
-- of the board from the camera, flipping across with a fade. Each cell's state eases, so
-- cells grow in and fade out; a wall pulses when it becomes satisfied.
local shape = require "core.shape"
local grid = require "core.grid"
local projection = require "core.projection"
local mesh_gen = require "view.mesh_gen"
local resources = require "view.resources"
local motion = require "view.motion"
local audio = require "view.audio"
local theme = require "view.theme"

local M = {}

-- Walls stand further from the board than panels extend past their grids, so panels never
-- meet; the floor sits just under the pieces so they rest on it.
M.WALL_GAP = 0.34
M.FLOOR_GAP = 0.02
local MARGIN = 0.24
local FADE_RATE = 6
local CELL_RATE = 14
local PULSE_RATE = 2.2
local SWITCH = 0.08

local axes_of = { front = 3, side = 1, top = 2 }
local gaps = { front = M.WALL_GAP, side = M.WALL_GAP, top = M.FLOOR_GAP }
local AXIS_NAMES = { "x", "y", "z" }

-- Each wall has a mesh for either side of the board, both facing it: side -1 sits below
-- the low end of its axis, side 1 beyond the high end.
local function sideBuffers(level, name, owned)
	local axes, axis = projection.axes[name], axes_of[name]
	local w, h = level.size[axes.u], level.size[axes.v]
	local far = level.size[axis] + gaps[name]
	local buffers = {
		[-1] = resources.createBuffer(mesh_gen.panel(axes.u, axes.v, axis, w, h, -gaps[name], MARGIN, 1)),
		[1] = resources.createBuffer(mesh_gen.panel(axes.u, axes.v, axis, w, h, far, MARGIN, -1)),
	}
	owned[#owned + 1] = buffers[-1]
	owned[#owned + 1] = buffers[1]
	return buffers, w, h
end

local function zeros(n)
	local t = {}
	for i = 1, n do
		t[i] = 0
	end
	return t
end

function M.create(level, factory_url)
	local walls = { level = level, list = {}, owned = {} }
	for name, axis in pairs(axes_of) do
		local buffers, w, h = sideBuffers(level, name, walls.owned)
		local id = factory.create(factory_url)
		local mesh = msg.url(nil, id, "mesh")
		local texture = resources.createTexture(w, h, zeros(w * h * 4))
		local focus_texture = resources.createTexture(w, h, zeros(w * h * 4))
		walls.owned[#walls.owned + 1] = texture
		walls.owned[#walls.owned + 1] = focus_texture
		go.set(mesh, "vertices", buffers[-1])
		go.set(mesh, "texture0", texture)
		go.set(mesh, "texture1", texture)
		go.set(mesh, "texture2", focus_texture)
		go.set(mesh, "dims", vmath.vector4(w, h, MARGIN, 0))
		walls.list[name] = {
			name = name, axis = axis, go = id, mesh = mesh, buffers = buffers, texture = texture, w = w, h = h,
			side = -1, goal_side = -1, opacity = 1, pulse = 0, matched = false, glow = 0,
			cells = zeros(w * h * 4), goal = zeros(w * h * 4), dirty = true,
			focus_texture = focus_texture, focus = zeros(w * h * 4), focus_goal = zeros(w * h * 4), focus_dirty = true,
		}
	end
	return walls
end

local function boardCells(level, id, pose)
	local cells = {}
	for _, c in ipairs(shape.cellsAt(level.pieces[id].shape, pose)) do
		if grid.contains(level.size, c) then
			cells[#cells + 1] = c
		end
	end
	return cells
end

-- Marks the cells the focused piece casts onto, in the red channel of each wall's focus goal.
local function focusGoals(walls, cells)
	for name, wall in pairs(walls.list) do
		local cast = cells and projection.project(walls.level.size, cells, name).filled
		for i = 1, wall.w * wall.h do
			wall.focus_goal[(i - 1) * 4 + 1] = cast and cast[i] and 1 or 0
		end
	end
end

-- What the displayed pieces cast on the floor: covered columns and those touching it.
local function floorShadow(level, poses)
	local cells, contact = {}, {}
	for id, pose in pairs(poses) do
		for _, c in ipairs(shape.cellsAt(level.pieces[id].shape, pose)) do
			if grid.contains(level.size, c) then
				cells[#cells + 1] = c
				if c[2] == 0 then
					contact[c[1] + c[3] * level.size[1] + 1] = true
				end
			end
		end
	end
	return { covered = projection.project(level.size, cells, "top").filled, contact = contact }
end

-- Per cell, four channels in [0, 1]: target, judged coverage, unjudged coverage, contact.
-- `shadow` is given for the floor only.
local function cellGoals(wall, target, comparison, shadow)
	local goal = wall.goal
	for i = 1, wall.w * wall.h do
		local status = comparison and comparison.status[i]
		local base = (i - 1) * 4
		goal[base + 1] = target and target.filled[i] and 1 or 0
		goal[base + 2] = (status == "hit" or status == "extra") and 1 or 0
		goal[base + 3] = shadow and not comparison and shadow.covered[i] and 1 or 0
		goal[base + 4] = shadow and shadow.contact[i] and 1 or 0
	end
end

-- display: { poses, evaluation } from game/play. focus: { piece, color } for the selected
-- piece, whose cast cells are outlined in its colour, or nil.
function M.present(walls, display, focus)
	local level = walls.level
	local focus_pose = focus and display.poses[focus.piece]
	focusGoals(walls, focus_pose and boardCells(level, focus.piece, focus_pose))
	if focus then
		for _, wall in pairs(walls.list) do
			go.set(wall.mesh, "accent", focus.color)
		end
	end
	local shadow = floorShadow(level, display.poses)
	for name, wall in pairs(walls.list) do
		local comparison = display.evaluation.views[name]
		cellGoals(wall, level.targets[name], comparison, name == "top" and shadow or nil)
		local matched = comparison ~= nil and comparison.matches
		if matched and not wall.matched then
			wall.pulse = 1
			audio.cue("wall")
		end
		wall.matched = matched
	end
end

-- Applies display preferences: { high_contrast }.
function M.configure(walls, prefs)
	local style = prefs.high_contrast and "high_contrast" or "normal"
	if walls.style == style then
		return
	end
	walls.style = style
	local colors = theme.panel[style]
	for _, wall in pairs(walls.list) do
		go.set(wall.mesh, "base", theme.vec(colors.base))
		go.set(wall.mesh, "ink", theme.vec(colors.ink))
		go.set(wall.mesh, "warn", theme.vec(colors.warn))
	end
end

function M.celebrate(walls)
	for _, wall in pairs(walls.list) do
		wall.pulse = 1
	end
end

local function stepSide(wall, eye, k)
	if wall.axis ~= 2 then
		local e = eye[AXIS_NAMES[wall.axis]]
		if e > SWITCH then
			wall.goal_side = -1
		elseif e < -SWITCH then
			wall.goal_side = 1
		end
	end
	wall.opacity = motion.approach(wall.opacity, wall.goal_side == wall.side and 1 or 0, k)
	if wall.goal_side ~= wall.side and wall.opacity < 0.02 then
		wall.side = wall.goal_side
		go.set(wall.mesh, "vertices", wall.buffers[wall.side])
	end
end

-- Eases `cells` toward `goal` and uploads them as bytes when anything moved.
local function easeTexture(texture, w, h, cells, goal, k, force)
	local changed = force
	for i = 1, #cells do
		local v, g = cells[i], goal[i]
		if v ~= g then
			cells[i] = math.abs(g - v) < 0.004 and g or motion.approach(v, g, k)
			changed = true
		end
	end
	if changed then
		local bytes = {}
		for i = 1, #cells do
			bytes[i] = math.floor(cells[i] * 255 + 0.5)
		end
		resources.updateTexture(texture, w, h, bytes)
	end
end

local function stepCells(wall, k)
	easeTexture(wall.texture, wall.w, wall.h, wall.cells, wall.goal, k, wall.dirty)
	easeTexture(wall.focus_texture, wall.w, wall.h, wall.focus, wall.focus_goal, k, wall.focus_dirty)
	wall.dirty, wall.focus_dirty = false, false
end

-- Advances fades, cell easing and pulses. eye: unit vector3 from the board toward the camera.
function M.step(walls, dt, eye)
	local k_fade, k_cell = motion.blend(FADE_RATE, dt), motion.blend(CELL_RATE, dt)
	for _, wall in pairs(walls.list) do
		stepSide(wall, eye, k_fade)
		stepCells(wall, k_cell)
		wall.pulse = math.max(0, wall.pulse - PULSE_RATE * dt)
		wall.glow = motion.approach(wall.glow, wall.matched and 1 or 0, k_fade)
		go.set(wall.mesh, "opacity", vmath.vector4(wall.opacity, wall.pulse, wall.glow, 0))
	end
end

function M.destroy(walls)
	for _, wall in pairs(walls.list) do
		go.delete(wall.go)
	end
	for _, path in ipairs(walls.owned) do
		resources.release(path)
	end
end

return M
