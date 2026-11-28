-- Boards come from the pool a few per frame: built in one frame, drawn in the next (so newly
-- made objects are in the scene), and returned in the one after.
local hot = require "core.hot"
local board_view = require "view.board_view"
local board_pool = require "view.board_pool"
local rules = require "core.rules"
local cameras = require "view.cameras"

local M = {}

local TARGET = "thumbs"
local TARGET_PATH = "/render/thumbs.render_targetc"
local ATLAS = "/thumbs.texturesetc"
local GRID_MAX = 6
local YAW, PITCH = math.rad(-38), math.rad(24)
local FOV = math.rad(16)
local FIT = 0.48
local FILL = 0.62
M.SCALE = FILL / FIT
local BUILDS_PER_FRAME = 2
local AWAY = vmath.vector3(0, -40000, 0)
local SPACING = 100
local ROTATION = vmath.quat_rotation_x(PITCH) * vmath.quat_rotation_y(YAW)
local EYE = vmath.rotate(vmath.conj(ROTATION), vmath.vector3(0, 0, 1))

local function targetImage()
	local attachment = resource.get_render_target_info(TARGET_PATH).attachments[1]
	return attachment.texture, attachment.width
end

local function cellOf(i, n, side)
	local size = math.floor(side / n)
	return (i - 1) % n * size, math.floor((i - 1) / n) * size, size
end

local function atlasData(n)
	local texture, side = targetImage()
	local animations, geometries = {}, {}
	for i = 1, GRID_MAX * GRID_MAX do
		local x, y, size = cellOf(i <= n * n and i or 1, n, side)
		animations[i] = { id = "cell" .. i, width = size, height = size, frames = { i } }
		geometries[i] = {
			vertices = { 0, 0, 0, size, size, size, size, 0 },
			uvs = { x, y, x, y + size, x + size, y + size, x + size, y },
			indices = { 0, 1, 2, 0, 2, 3 },
		}
	end
	return { texture = texture, animations = animations, geometries = geometries }
end

function M.createAtlas()
	return resource.create_atlas(ATLAS, atlasData(1))
end

function M.new(pool, atlas)
	local _, side = targetImage()
	return { pool = pool, atlas = atlas, side = side, n = 1, next_cell = 1, built = {}, shooting = {}, images = {} }
end

local function releaseEach(list)
	for i = #list, 1, -1 do
		board_pool.release(list[i].slot)
		list[i] = nil
	end
end

local function start(thumbs, specs, prefs)
	assert(#specs <= GRID_MAX * GRID_MAX, "thumbs: more levels than thumbnail cells")
	releaseEach(thumbs.built)
	thumbs.specs, thumbs.prefs, thumbs.images, thumbs.clear, thumbs.next_cell = specs, prefs, {}, true, 1
	local n = math.max(1, math.ceil(math.sqrt(#specs)))
	if n ~= thumbs.n then
		thumbs.n = n
		resource.set_atlas(thumbs.atlas, atlasData(n))
	end
end

local function build(thumbs, spec, cell)
	local level = spec.level
	local slot = board_pool.acquire(thumbs.pool, level)
	local board = slot.board
	board_view.present(board, { poses = spec.poses, evaluation = rules.evaluate(level, { poses = spec.poses }) })
	board_view.configure(board, thumbs.prefs)
	board_view.finish(board, EYE, 0)
	local center, radius = board_view.bounds(level)
	local at = AWAY + vmath.vector3(cell * SPACING, 0, 0)
	go.set_position(at - vmath.rotate(ROTATION, center), slot.anchor)
	go.set_rotation(ROTATION, slot.anchor)
	local distance = radius / (2 * FIT * math.tan(FOV / 2))
	local x, top, size = cellOf(cell, thumbs.n, thumbs.side)
	local shot = cameras.shot(at + vmath.vector3(0, 0, distance), vmath.quat(), FOV, 1,
		math.max(0.05, distance - 3 * radius), distance + 3 * radius, x, thumbs.side - top - size, size, size)
	return { id = spec.id, cell = cell, slot = slot, shot = shot }
end

function M.present(thumbs, specs, prefs)
	for _, t in ipairs(thumbs.shooting) do
		thumbs.images[t.id] = "cell" .. t.cell
	end
	releaseEach(thumbs.shooting)
	if specs ~= thumbs.specs or prefs ~= thumbs.prefs then
		start(thumbs, specs, prefs)
	end
	thumbs.shooting, thumbs.built = thumbs.built, thumbs.shooting
	if #thumbs.shooting > 0 then
		local shots = {}
		for i, t in ipairs(thumbs.shooting) do
			shots[i] = t.shot
		end
		cameras.setShots("thumbs", TARGET, thumbs.clear, shots)
		thumbs.clear = false
	else
		cameras.clear("thumbs")
	end
	while #thumbs.built < BUILDS_PER_FRAME and thumbs.next_cell <= #specs do
		local cell = thumbs.next_cell
		thumbs.built[#thumbs.built + 1] = build(thumbs, specs[cell], cell)
		thumbs.next_cell = cell + 1
	end
end

function M.release(thumbs)
	releaseEach(thumbs.built)
	releaseEach(thumbs.shooting)
	cameras.clear("thumbs")
end

return hot(..., M)
