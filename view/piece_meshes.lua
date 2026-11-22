-- One fused mesh buffer per piece, shared by every view that draws the piece.
local orient = require "core.orient"
local mesh_gen = require "view.mesh_gen"
local resources = require "view.resources"

local M = {}

-- Returns { [piece_id] = buffer resource path }.
function M.create(level)
	local buffers = {}
	for _, piece in ipairs(level.pieces) do
		buffers[piece.id] = resources.createBuffer(mesh_gen.piece(piece.shape.forms[orient.identity]))
	end
	return buffers
end

function M.release(buffers)
	for _, path in pairs(buffers) do
		resources.release(path)
	end
end

return M
