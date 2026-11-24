-- Level thumbnails as still images. Each level's board, posed as asked, is drawn once into a
-- cell of the thumbnail render target ("thumbs" in render/game.render), which a runtime atlas
-- shows as one image per cell ("cell1", "cell2", ...). Boards come from the pool a few per
-- frame: built in one frame, drawn in the next (so newly made objects are in the scene), and
-- returned in the one after. The images are a cache of the specs and preferences: new ones draw
-- them again.
local hot = require "core.hot"
local board_view = require "view.board_view"
local board_pool = require "view.board_pool"
local rules = require "core.rules"
local cameras = require "view.cameras"

local M = {}

local TARGET = "thumbs"
local TARGET_PATH = "/render/thumbs.render_targetc"
local ATLAS = "/thumbs.texturesetc"
-- The target's size in pixels (render/thumbs.render_target), and the largest grid of cells.
local SIZE = 2048
local GRID_MAX = 6
local YAW, PITCH = math.rad(-38), math.rad(24)
local FOV = math.rad(16)
-- The board's bounding sphere fits its cell, its radius spanning FIT of the cell's side. Shown,
-- the radius spans FILL of the level's slot, so the image is SCALE times the slot.
local FIT = 0.48
local FILL = 0.62
M.SCALE = FILL / FIT
local BUILDS_PER_FRAME = 2
-- Boards stand far below everything else, a spacing apart, each seen only by its own camera.
local AWAY = vmath.vector3(0, -40000, 0)
local SPACING = 100
local ROTATION = vmath.quat_rotation_x(PITCH) * vmath.quat_rotation_y(YAW)
local EYE = vmath.rotate(vmath.conj(ROTATION), vmath.vector3(0, 0, 1))

-- Cell i of an n x n grid: its left and top edge in target pixels (from the top left, as the
-- atlas counts) and its size.
local function cellOf(i, n)
	local size = math.floor(SIZE / n)
	return (i - 1) % n * size, math.floor((i - 1) / n) * size, size
end

-- Atlas data for an n x n grid. Every cell of the largest grid has an image, so an image name
-- stays valid whatever the grid; cells beyond n x n show the first.
local function atlasData(n)
	local animations, geometries = {}, {}
	for i = 1, GRID_MAX * GRID_MAX do
		local x, y, size = cellOf(i <= n * n and i or 1, n)
		animations[i] = { id = "cell" .. i, width = size, height = size, frames = { i } }
		geometries[i] = {
			vertices = { 0, 0, 0, size, size, size, size, 0 },
			uvs = { x, y, x, y + size, x + size, y + size, x + size, y },
			indices = { 0, 1, 2, 0, 2, 3 },
		}
	end
	local texture = resource.get_render_target_info(TARGET_PATH).attachments[1].texture
	return { texture = texture, animations = animations, geometries = geometries }
end

-- The atlas over the thumbnail target. Made once per run; returns its path for a GUI to use.
function M.createAtlas()
	return resource.create_atlas(ATLAS, atlasData(1))
end

-- atlas: the path from M.createAtlas.
function M.new(pool, atlas)
	return { pool = pool, atlas = atlas, n = 1, queue = {}, built = {}, shooting = {}, images = {} }
end

local function releaseAll(thumbs)
	for _, list in ipairs({ thumbs.built, thumbs.shooting }) do
		for i = #list, 1, -1 do
			board_pool.release(list[i].slot)
			list[i] = nil
		end
	end
end

-- Begins drawing a new set: the old images are dropped and every spec is queued.
local function start(thumbs, specs, prefs)
	assert(#specs <= GRID_MAX * GRID_MAX, "thumbs: more levels than thumbnail cells")
	releaseAll(thumbs)
	thumbs.specs, thumbs.prefs, thumbs.images, thumbs.clear = specs, prefs, {}, true
	local n = math.max(1, math.ceil(math.sqrt(#specs)))
	if n ~= thumbs.n then
		thumbs.n = n
		resource.set_atlas(thumbs.atlas, atlasData(n))
	end
	for i = #thumbs.queue, 1, -1 do
		thumbs.queue[i] = nil
	end
	for i = 1, #specs do
		thumbs.queue[i] = i
	end
end

-- A board for spec (cell `cell`), settled and placed before its own camera.
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
	local x, top, size = cellOf(cell, thumbs.n)
	local shot = cameras.shot(at + vmath.vector3(0, 0, distance), vmath.quat(), FOV, 1,
		math.max(0.05, distance - 3 * radius), distance + 3 * radius, x, SIZE - top - size, size, size)
	return { id = spec.id, cell = cell, slot = slot, shot = shot }
end

-- specs: { { id, level, poses } }, the levels to show in the order to draw them; a new table
-- (or new prefs: colours, patterns, contrast) draws them all again. thumbs.images then maps each
-- drawn spec's id to its image name.
function M.present(thumbs, specs, prefs)
	for i, t in ipairs(thumbs.shooting) do
		board_pool.release(t.slot)
		thumbs.images[t.id] = "cell" .. t.cell
		thumbs.shooting[i] = nil
	end
	if specs ~= thumbs.specs or prefs ~= thumbs.prefs then
		start(thumbs, specs, prefs)
	end
	if #thumbs.built > 0 then
		local shots = {}
		for i, t in ipairs(thumbs.built) do
			shots[i], thumbs.shooting[i], thumbs.built[i] = t.shot, t, nil
		end
		cameras.setShots("thumbs", TARGET, thumbs.clear, shots)
		thumbs.clear = false
	else
		cameras.clear("thumbs")
	end
	for _ = 1, math.min(BUILDS_PER_FRAME, #thumbs.queue) do
		local i = table.remove(thumbs.queue, 1)
		thumbs.built[#thumbs.built + 1] = build(thumbs, specs[i], i)
	end
end

-- Returns every board to the pool and stops drawing.
function M.release(thumbs)
	releaseAll(thumbs)
	cameras.clear("thumbs")
end

return hot(..., M)
