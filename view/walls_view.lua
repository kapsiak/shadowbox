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
-- Layer textures have this fixed size; a wall's w x h grid fills their low corner.
local TEXELS = 8

local function zeros(n)
	local t = {}
	for i = 1, n do
		t[i] = 0
	end
	return t
end


-- Texture slots follow the sampler order in panel.material; `cells` is bound twice (sharp, soft).
local LAYERS = { "cells", "focus", "received", "target" }
local slots = { { "texture0", "cells" }, { "texture1", "cells" }, { "texture2", "focus" }, { "texture3", "received" }, { "texture4", "target" } }

-- The wall objects under `parent`, hidden until bound to a level.
function M.create(factory_url, parent)
	local walls = { list = {} }
	for name, axis in pairs(axes_of) do
		local id = factory.create(factory_url)
		go.set_parent(id, parent)
		local mesh = msg.url(nil, id, "mesh")
		local textures = {}
		for _, key in ipairs(LAYERS) do
			textures[key] = resources.texture(nil, TEXELS, TEXELS, (resources.texels(TEXELS, TEXELS)))
		end
		for _, slot in ipairs(slots) do
			go.set(mesh, slot[1], textures[slot[2]])
		end
		msg.post(mesh, "disable")
		walls.list[name] = { name = name, axis = axis, mesh = mesh, buffers = {}, textures = textures, layers = {} }
	end
	return walls
end

-- Each wall has a mesh for either side of the board, both facing it: side -1 sits below
-- the low end of its axis, side 1 beyond the high end. Each layer holds w x h RGBA texels
-- that ease from `now` toward `goal`, uploaded to its texture through `texels`; `moving` is
-- set when a goal changes and cleared once `now` reaches it.
local function bindWall(wall, level, blank)
	local name, axis = wall.name, wall.axis
	local axes = projection.axes[name]
	local w, h = level.size[axes.u], level.size[axes.v]
	assert(w <= TEXELS and h <= TEXELS, "walls_view: a wall larger than the layer textures")
	local far = level.size[axis] + gaps[name]
	local m = margins[name]
	wall.buffers[-1] = resources.buffer(wall.buffers[-1], mesh_gen.panel(axes.u, axes.v, axis, w, h, -gaps[name], m, 1))
	wall.buffers[1] = resources.buffer(wall.buffers[1], mesh_gen.panel(axes.u, axes.v, axis, w, h, far, m, -1))
	for _, key in ipairs(LAYERS) do
		local texture = resources.texture(wall.textures[key], TEXELS, TEXELS, blank)
		local texels, stream = resources.texels(w, h)
		wall.layers[key] = { texture = texture, texels = texels, stream = stream, now = zeros(w * h * 4), goal = zeros(w * h * 4), moving = false }
	end
	go.set(wall.mesh, "vertices", wall.buffers[-1])
	go.set(wall.mesh, "dims", vmath.vector4(w, h, TEXELS, TEXELS))
	go.set(wall.mesh, "margins", vmath.vector4(m[1], m[2], m[3], m[4]))
	wall.w, wall.h = w, h
	wall.side, wall.goal_side, wall.opacity, wall.pulse, wall.matched, wall.glow = -1, -1, 1, 0, false, 0
end

-- Shows `level`'s walls, cleared: cells grow in from nothing.
function M.bind(walls, level)
	walls.level = level
	local blank = resources.texels(TEXELS, TEXELS)
	for _, wall in pairs(walls.list) do
		bindWall(wall, level, blank)
		msg.post(wall.mesh, "enable")
	end
end

function M.hide(walls)
	for _, wall in pairs(walls.list) do
		msg.post(wall.mesh, "disable")
	end
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

-- Sets one goal value of a layer, marking the layer to ease when it changes.
local function put(layer, i, v)
	if layer.goal[i] ~= v then
		layer.goal[i] = v
		layer.moving = true
	end
end

-- Marks the cells the focused piece casts onto, in the red channel of each wall's focus goal.
local function focusGoals(walls, cells)
	for name, wall in pairs(walls.list) do
		local cast = cells and projection.cover(walls.level.size, cells, name)
		local focus = wall.layers.focus
		for i = 1, wall.w * wall.h do
			put(focus, (i - 1) * 4 + 1, cast and cast[i] and 1 or 0)
		end
	end
end

local WHITE = channels.light.identity

-- The floor cells the displayed pieces touch.
local function floorContact(level, poses)
	local contact = {}
	for id, pose in pairs(poses) do
		for _, c in ipairs(boardCells(level, id, pose)) do
			if c[2] == 0 then
				contact[c[1] + c[3] * level.size[1] + 1] = true
			end
		end
	end
	return contact
end

-- Writes the colour of `light` into texel i: rgb the glass colour and a = 1, or a = 0 for
-- darkness (drawn in the panel's ink). White leaves the texel alone, so a cell keeps its
-- colour while it fades out.
local function lightGoal(layer, i, light)
	if not light or light == WHITE then
		return
	end
	local base, color = (i - 1) * 4, theme.glass[light]
	put(layer, base + 4, color and 1 or 0)
	for k = 1, color and 3 or 0 do
		put(layer, base + k, color[k])
	end
end

-- cells, per texel: target, judged coverage, unused, contact, in [0, 1];
-- received and target: the colour of the light received and wanted (see lightGoal).
-- `contact` is given for the floor only.
local function cellGoals(wall, target, comparison, contact)
	local layers = wall.layers
	local wanted = target and target.layers.light
	local current = comparison and comparison.current.layers.light
	for i = 1, wall.w * wall.h do
		local base = (i - 1) * 4
		put(layers.cells, base + 1, wanted and wanted[i] ~= WHITE and 1 or 0)
		put(layers.cells, base + 2, current and current[i] ~= WHITE and 1 or 0)
		put(layers.cells, base + 4, contact and contact[i] and 1 or 0)
		lightGoal(layers.received, i, current and current[i])
		lightGoal(layers.target, i, wanted and wanted[i])
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
	local contact = floorContact(level, display.poses)
	for name, wall in pairs(walls.list) do
		local comparison = display.evaluation.views[name]
		cellGoals(wall, level.targets[name], comparison, name == "top" and contact or nil)
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
		for _, key in ipairs({ "surface", "shadow", "line", "frame" }) do
			go.set(wall.mesh, key, theme.vec(colors[key]))
		end
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

-- Moves a moving layer toward its goal by at most `step` and uploads it; it rests on arrival.
local function easeLayer(layer, w, h, step)
	if not layer.moving then
		return
	end
	local now, goal, stream, moving = layer.now, layer.goal, layer.stream, false
	for i = 1, #now do
		local v, g = now[i], goal[i]
		if v ~= g then
			v = v < g and math.min(g, v + step) or math.max(g, v - step)
			now[i], stream[i] = v, math.floor(v * 255 + 0.5)
			moving = true
		end
	end
	layer.moving = moving
	if moving then
		resources.texture(layer.texture, w, h, layer.texels)
	end
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

return M
