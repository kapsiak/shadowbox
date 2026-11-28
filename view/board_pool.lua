-- Buffers and textures are rewritten, never freed (released runtime resources were not freed
-- by the engine), so resources stop growing once the pool has grown to the most boards shown
-- at once.
local hot = require "core.hot"
local orient = require "core.orient"
local board_view = require "view.board_view"
local mesh_gen = require "view.mesh_gen"
local resources = require "view.resources"

local M = {}

function M.new(factories)
	return { factories = factories, slots = {} }
end

local function freeSlot(pool)
	for _, slot in ipairs(pool.slots) do
		if slot.free then
			return slot
		end
	end
	local anchor = msg.url(nil, factory.create(pool.factories.anchor), nil)
	local slot = { anchor = anchor, buffers = {}, board = board_view.create(pool.factories, anchor) }
	pool.slots[#pool.slots + 1] = slot
	return slot
end

local function fillMeshes(buffers, level)
	for _, piece in ipairs(level.pieces) do
		buffers[piece.id] = resources.buffer(buffers[piece.id], mesh_gen.piece(piece.shape.forms[orient.identity]))
	end
end

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

return hot(..., M)
