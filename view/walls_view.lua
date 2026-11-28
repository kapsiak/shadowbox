local hot = require "core.hot"
local shape = require "core.shape"
local grid = require "core.grid"
local projection = require "core.projection"
local channels = require "core.channels"
local mesh_gen = require "view.mesh_gen"
local resources = require "view.resources"
local motion = require "view.motion"
local theme = require "view.theme"

local M = {}

local MARGIN = 0.3
M.WALL_GAP = MARGIN
M.FLOOR_GAP = 0.02
local FADE_RATE = 6
local CELL_SPEED = 7
local PULSE_RATE = 2.2
local SWITCH = 0.08

local axes_of = { front = 3, side = 1, top = 2 }
local gaps = { front = MARGIN, side = MARGIN, top = M.FLOOR_GAP }
local margins = {
	front = { MARGIN, MARGIN, M.FLOOR_GAP, MARGIN },
	side = { MARGIN, MARGIN, M.FLOOR_GAP, MARGIN },
	top = { MARGIN, MARGIN, MARGIN, MARGIN },
}
local AXIS_NAMES = { "x", "y", "z" }
local TEXELS = 8

local function zeros(n)
	local t = {}
	for i = 1, n do
		t[i] = 0
	end
	return t
end

-- Texture slots follow the sampler order in panel.material: slot 0 is the static digit strip
-- (panel.mesh) and `cells` is bound twice (sharp, soft). Channels holding numbers or ids snap
-- rather than ease: all of `counts`, and the wanted-light id in `shape`.
local LAYERS = { "cells", "shape", "received", "target", "counts" }
local SNAP = { counts = { true, true, true, true }, shape = { false, false, false, true } }
local slots = { { "texture1", "counts" }, { "texture2", "cells" }, { "texture3", "cells" }, { "texture4", "shape" }, { "texture5", "received" }, { "texture6", "target" } }
local OPERATOR_IDS = { light = 0, count = 1, parity = 2 }

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
		wall.layers[key] = { texture = texture, texels = texels, stream = stream, now = zeros(w * h * 4), goal = zeros(w * h * 4), moving = false, snap = SNAP[key] }
	end
	wall.operator, wall.cubes_of = level.walls[name] or "light", nil
	go.set(wall.mesh, "operator", vmath.vector4(OPERATOR_IDS[wall.operator], 0, 0, 0))
	go.set(wall.mesh, "vertices", wall.buffers[-1])
	go.set(wall.mesh, "dims", vmath.vector4(w, h, TEXELS, TEXELS))
	go.set(wall.mesh, "margins", vmath.vector4(m[1], m[2], m[3], m[4]))
	wall.w, wall.h = w, h
	wall.side, wall.goal_side, wall.opacity, wall.pulse, wall.matched, wall.glow = -1, -1, 1, 0, false, 0
	wall.fx = vmath.vector4(-1, 0, 0, 0)
end

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

local function put(layer, i, v)
	if layer.goal[i] ~= v then
		layer.goal[i] = v
		layer.moving = true
	end
end

local function focusGoals(walls, cells)
	for name, wall in pairs(walls.list) do
		local cast = cells and projection.cover(walls.level.size, cells, name)
		local shape_layer = wall.layers.shape
		for i = 1, wall.w * wall.h do
			put(shape_layer, (i - 1) * 4 + 3, cast and cast[i] and 1 or 0)
		end
	end
end

local WHITE = channels.light.identity

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

local casts = {
	light = function(v) return v ~= WHITE end,
	count = function(v) return v > 0 end,
	parity = function(v) return v == 1 end,
}

local function seenLight(operator, v)
	if operator == "light" or v == nil then
		return v
	end
	return casts[operator](v) and 0 or WHITE
end

local function wantId(layer, i, light)
	if light and light ~= WHITE then
		put(layer, (i - 1) * 4 + 4, (theme.glass[light] and light or 0) / 255)
	end
end

-- Each cell's goals, per layer (as materials/panel.fp reads them): shape { target, coverage,
-- focus, wanted-light id }; cells { -, -, wrong, contact }; received and target, the light's
-- colour (lightGoal); counts { wanted count, cubes on the ray }. `contact` is given for the
-- floor, `cubes` for walls that count.
local function cellGoals(wall, target, comparison, contact, cubes)
	local layers, op = wall.layers, wall.operator
	local wanted = target and target.layers[op]
	local current = comparison and comparison.current.layers[op]
	local cast = casts[op]
	for i = 1, wall.w * wall.h do
		local base = (i - 1) * 4
		local want_cast, cur_cast = wanted and cast(wanted[i]), current and cast(current[i])
		put(layers.shape, base + 1, want_cast and 1 or 0)
		put(layers.shape, base + 2, cur_cast and 1 or 0)
		put(layers.cells, base + 3, cur_cast and (op == "count" and current[i] ~= wanted[i] or not want_cast) and 1 or 0)
		put(layers.cells, base + 4, contact and contact[i] and 1 or 0)
		put(layers.counts, base + 1, op == "count" and wanted and wanted[i] / 255 or 0)
		put(layers.counts, base + 2, cubes and cubes[i] / 255 or 0)
		lightGoal(layers.received, i, seenLight(op, current and current[i]))
		local want = seenLight(op, wanted and wanted[i])
		lightGoal(layers.target, i, want)
		wantId(layers.shape, i, want)
	end
end

local function cubeCounts(wall, level, poses)
	if wall.cubes_of ~= poses then
		local items = {}
		for id, pose in pairs(poses) do
			items[#items + 1] = { cells = boardCells(level, id, pose), value = { count = 1 } }
		end
		wall.cubes = projection.project(level.size, wall.name, { "count" }, items).layers.count
		wall.cubes_of = poses
	end
	return wall.cubes
end

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
		local cubes = wall.operator ~= "light" and cubeCounts(wall, level, display.poses) or nil
		cellGoals(wall, level.targets[name], comparison, name == "top" and contact or nil, cubes)
		local matched = comparison ~= nil and comparison.matches
		if matched and not wall.matched then
			wall.pulse = 1
		end
		wall.matched = matched
	end
end

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

local function aimSide(wall, eye)
	if wall.axis ~= 2 then
		local e = eye[AXIS_NAMES[wall.axis]]
		if e > SWITCH then
			wall.goal_side = -1
		elseif e < -SWITCH then
			wall.goal_side = 1
		end
	end
end

local function showSide(wall, side)
	wall.side = side
	go.set(wall.mesh, "vertices", wall.buffers[side])
end

local function stepSide(wall, eye, k)
	aimSide(wall, eye)
	wall.opacity = motion.ease(wall.opacity, wall.goal_side == wall.side and 1 or 0, k)
	if wall.goal_side ~= wall.side and wall.opacity < 0.02 then
		showSide(wall, wall.goal_side)
	end
end

local function easeLayer(layer, w, h, step)
	if not layer.moving then
		return
	end
	local snap = layer.snap
	local now, goal, stream, moving = layer.now, layer.goal, layer.stream, false
	for i = 1, #now do
		local v, g = now[i], goal[i]
		if v ~= g then
			local s = snap and snap[(i - 1) % 4 + 1] and 1 or step
			v = v < g and math.min(g, v + s) or math.max(g, v - s)
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

local function showFx(wall)
	local fx = wall.fx
	if fx.x ~= wall.opacity or fx.y ~= wall.pulse or fx.z ~= wall.glow then
		fx.x, fx.y, fx.z = wall.opacity, wall.pulse, wall.glow
		go.set(wall.mesh, "opacity", fx)
	end
end

function M.finish(walls, eye)
	for _, wall in pairs(walls.list) do
		aimSide(wall, eye)
		if wall.side ~= wall.goal_side then
			showSide(wall, wall.goal_side)
		end
		wall.opacity = 1
		stepCells(wall, 1)
		wall.pulse, wall.glow = 0, wall.matched and 1 or 0
		showFx(wall)
	end
end

function M.step(walls, dt, eye)
	local k_fade = motion.blend(FADE_RATE, dt)
	for _, wall in pairs(walls.list) do
		stepSide(wall, eye, k_fade)
		stepCells(wall, CELL_SPEED * dt)
		wall.pulse = math.max(0, wall.pulse - PULSE_RATE * dt)
		wall.glow = motion.ease(wall.glow, wall.matched and 1 or 0, k_fade)
		showFx(wall)
	end
end

return hot(..., M)
