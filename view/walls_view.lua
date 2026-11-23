-- The projection panels: front and side walls plus the floor. Walls stand on the far side
-- of the board from the camera, flipping across with a fade. Each cell's state eases, so
-- cells grow in and fade out; a wall pulses when it becomes satisfied.
local shape = require "core.shape"
local grid = require "core.grid"
local projection = require "core.projection"
local channels = require "core.channels"
local mesh_gen = require "view.mesh_gen"
local resources = require "view.resources"
local motion = require "view.motion"
local theme = require "view.theme"

local M = {}

-- The panels form an open box: the floor sits just under the pieces so they rest on it and
-- reaches out to the walls, which stand on it one margin away from the grid.
local MARGIN = 0.3
M.WALL_GAP = MARGIN
M.FLOOR_GAP = 0.02
local FADE_RATE = 6
-- Cells change at a constant speed (full change per second), so appearing mirrors disappearing.
local CELL_SPEED = 7
local PULSE_RATE = 2.2
local SWITCH = 0.08

local axes_of = { front = 3, side = 1, top = 2 }
local gaps = { front = M.WALL_GAP, side = M.WALL_GAP, top = M.FLOOR_GAP }
local margins = {
	front = { MARGIN, MARGIN, M.FLOOR_GAP, MARGIN },
	side = { MARGIN, MARGIN, M.FLOOR_GAP, MARGIN },
	top = { MARGIN, MARGIN, MARGIN, MARGIN },
}
local AXIS_NAMES = { "x", "y", "z" }

-- Each wall has a mesh for either side of the board, both facing it: side -1 sits below
-- the low end of its axis, side 1 beyond the high end.
local function sideBuffers(level, name, owned)
	local axes, axis = projection.axes[name], axes_of[name]
	local w, h = level.size[axes.u], level.size[axes.v]
	local far = level.size[axis] + gaps[name]
	local buffers = {
		[-1] = resources.createBuffer(mesh_gen.panel(axes.u, axes.v, axis, w, h, -gaps[name], margins[name], 1)),
		[1] = resources.createBuffer(mesh_gen.panel(axes.u, axes.v, axis, w, h, far, margins[name], -1)),
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

-- A w x h RGBA texture whose texels ease from `now` toward `goal`.
local function newLayer(w, h, owned)
	local texture = resources.createTexture(w, h, zeros(w * h * 4))
	owned[#owned + 1] = texture
	return { texture = texture, now = zeros(w * h * 4), goal = zeros(w * h * 4), dirty = true }
end

-- Texture slots follow the sampler order in panel.material; `cells` is bound twice (sharp, soft).
local slots = { { "texture0", "cells" }, { "texture1", "cells" }, { "texture2", "focus" }, { "texture3", "received" }, { "texture4", "target" } }

function M.create(level, factory_url)
	local walls = { level = level, list = {}, owned = {} }
	for name, axis in pairs(axes_of) do
		local buffers, w, h = sideBuffers(level, name, walls.owned)
		local id = factory.create(factory_url)
		local mesh = msg.url(nil, id, "mesh")
		local layers = {}
		for _, layer in ipairs({ "cells", "focus", "received", "target" }) do
			layers[layer] = newLayer(w, h, walls.owned)
		end
		go.set(mesh, "vertices", buffers[-1])
		for _, slot in ipairs(slots) do
			go.set(mesh, slot[1], layers[slot[2]].texture)
		end
		local m = margins[name]
		go.set(mesh, "dims", vmath.vector4(w, h, 0, 0))
		go.set(mesh, "margins", vmath.vector4(m[1], m[2], m[3], m[4]))
		walls.list[name] = {
			name = name, axis = axis, go = id, mesh = mesh, buffers = buffers, w = w, h = h, layers = layers,
			side = -1, goal_side = -1, opacity = 1, pulse = 0, matched = false, glow = 0,
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
		local cast = cells and projection.cover(walls.level.size, cells, name)
		local goal = wall.layers.focus.goal
		for i = 1, wall.w * wall.h do
			goal[(i - 1) * 4 + 1] = cast and cast[i] and 1 or 0
		end
	end
end

local WHITE = channels.light.identity

-- What the displayed pieces cast on the floor: the light each column lets through and the
-- columns touching it.
local function floorShadow(level, poses)
	local items, contact = {}, {}
	for id, pose in pairs(poses) do
		local cells = boardCells(level, id, pose)
		items[#items + 1] = { cells = cells, value = level.pieces[id].value }
		for _, c in ipairs(cells) do
			if c[2] == 0 then
				contact[c[1] + c[3] * level.size[1] + 1] = true
			end
		end
	end
	local light = projection.project(level.size, "top", { "light" }, items).layers.light
	return { light = light, contact = contact }
end

-- Writes the colour of `light` into texel i: rgb the glass colour and a = 1, or a = 0 for
-- darkness (drawn in the panel's ink). White leaves the texel alone, so a cell keeps its
-- colour while it fades out.
local function lightGoal(goal, i, light)
	if not light or light == WHITE then
		return
	end
	local base, color = (i - 1) * 4, theme.glass[light]
	goal[base + 4] = color and 1 or 0
	for k = 1, color and 3 or 0 do
		goal[base + k] = color[k]
	end
end

-- cells, per texel: target, judged coverage, unjudged coverage, contact, in [0, 1];
-- received and target: the colour of the light received and wanted (see lightGoal).
-- `shadow` is given for the floor only.
local function cellGoals(wall, target, comparison, shadow)
	local goal = wall.layers.cells.goal
	local wanted = target and target.layers.light
	local current = comparison and comparison.current.layers.light
	for i = 1, wall.w * wall.h do
		local base = (i - 1) * 4
		goal[base + 1] = wanted and wanted[i] ~= WHITE and 1 or 0
		goal[base + 2] = current and current[i] ~= WHITE and 1 or 0
		local cast = shadow and not comparison and shadow.light[i]
		goal[base + 3] = cast and cast ~= WHITE and 1 or 0
		goal[base + 4] = shadow and shadow.contact[i] and 1 or 0
		lightGoal(wall.layers.received.goal, i, current and current[i] or cast)
		lightGoal(wall.layers.target.goal, i, wanted and wanted[i])
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
		for _, key in ipairs({ "paper", "shadow", "pencil", "frame" }) do
			go.set(wall.mesh, key, theme.vec(colors[key]))
		end
	end
end

function M.attach(walls, parent)
	for _, wall in pairs(walls.list) do
		go.set_parent(wall.go, parent)
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

-- Moves a layer toward its goal by at most `step` and uploads it as bytes when anything moved.
local function easeLayer(layer, w, h, step)
	local now, goal, changed = layer.now, layer.goal, layer.dirty
	for i = 1, #now do
		local v, g = now[i], goal[i]
		if v ~= g then
			now[i] = v < g and math.min(g, v + step) or math.max(g, v - step)
			changed = true
		end
	end
	if changed then
		local bytes = {}
		for i = 1, #now do
			bytes[i] = math.floor(now[i] * 255 + 0.5)
		end
		resources.updateTexture(layer.texture, w, h, bytes)
	end
	layer.dirty = false
end

local function stepCells(wall, step)
	for _, layer in pairs(wall.layers) do
		easeLayer(layer, wall.w, wall.h, step)
	end
end

-- Advances fades, cell easing and pulses. eye: unit vector3 from the board toward the camera.
function M.step(walls, dt, eye)
	local k_fade = motion.blend(FADE_RATE, dt)
	for _, wall in pairs(walls.list) do
		stepSide(wall, eye, k_fade)
		stepCells(wall, CELL_SPEED * dt)
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
