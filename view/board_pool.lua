-- Boards for the whole run, each under its own anchor object. Screens acquire a board for a
-- level and release it when done; a released board is hidden and kept, and rebound in place
-- when next acquired. Its buffers and textures are rewritten, never freed (released runtime
-- resources were not freed by the engine), so resources stop growing once the pool has grown
-- to the most boards shown at once.
local orient = require "core.orient"
local board_view = require "view.board_view"
local mesh_gen = require "view.mesh_gen"
local resources = require "view.resources"

local M = {}

-- factories: { piece, glass_piece, panel, anchor } urls.
function M.new(factories)
	return { factories = factories, slots = {} }
end

local function freeSlot(pool)
	for _, slot in ipairs(pool.slots) do
		if slot.free then
			return slot
		end
	end
	local anchor = factory.create(pool.factories.anchor)
	local slot = { anchor = anchor, buffers = {}, board = board_view.create(pool.factories, anchor) }
	pool.slots[#pool.slots + 1] = slot
	return slot
end

-- One fused mesh per piece, written over the slot's buffers from earlier levels.
local function fillMeshes(buffers, level)
	for _, piece in ipairs(level.pieces) do
		buffers[piece.id] = resources.buffer(buffers[piece.id], mesh_gen.piece(piece.shape.forms[orient.identity]))
	end
end

-- A board showing `level` with no pieces placed, its anchor at the origin.
-- Returns { anchor, board, buffers }; buffers are the level's piece meshes.
function M.acquire(pool, level)
	local slot = freeSlot(pool)
	slot.free = false
	fillMeshes(slot.buffers, level)
	board_view.bind(slot.board, level, slot.buffers)
	go.set_position(vmath.vector3(), slot.anchor)
	go.set_rotation(vmath.quat(), slot.anchor)
	go.set_scale(1, slot.anchor)
	return slot
end

function M.release(slot)
	slot.free = true
	board_view.hide(slot.board)
end

return M
