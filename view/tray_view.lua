-- Presents unplaced pieces in a strip along the bottom of the screen, drawn by the
-- tray camera. Pieces are sized by their bounding sphere (`extent`, its diameter), so they fit
-- at any camera angle. The tray camera shares the board camera's orientation, so a piece in the
-- tray looks as it will on the board. Layout is in screen pixels, so picking is a rectangle test.
local hot = require "core.hot"
local orient = require "core.orient"
local piece_look = require "view.piece_look"
local palette = require "view.palette"
local cameras = require "view.cameras"
local board_view = require "view.board_view"

local M = {}

local DEPTH = 10
local CAMERA_POSITION = vmath.vector3(0, -1000, 0)
local CAMERA_FOV = 0.5
local SLOT_FILL = 0.85
local EASE_RATE = 14

local function boxOf(cells)
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, c in ipairs(cells) do
		for a = 1, 3 do
			lo[a], hi[a] = math.min(lo[a], c[a]), math.max(hi[a], c[a])
		end
	end
	local center = vmath.vector3((lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2)
	local diagonal = vmath.vector3(hi[1] - lo[1] + 1, hi[2] - lo[2] + 1, hi[3] - lo[3] + 1)
	return center, vmath.length(diagonal)
end

-- The tray scene lives far from the board, seen by its own camera ("tray" in view/cameras).
-- factories: { tray_piece, glass_tray_piece } urls.
function M.create(level, factories, buffers)
	local view = { level = level, pieces = {}, slots = {}, height = 0, extent = 1, count = #level.pieces }
	for _, piece in ipairs(level.pieces) do
		local id = factory.create(palette.isGlass(piece) and factories.glass_tray_piece or factories.tray_piece)
		local mesh = msg.url(nil, id, "mesh")
		go.set(mesh, "vertices", buffers[piece.id])
		piece_look.applyLight(mesh)
		msg.post(mesh, "disable")
		local center, extent = boxOf(piece.shape.forms[orient.identity])
		view.pieces[piece.id] = { go = id, mesh = mesh, center = center, shown = false,
			fx = vmath.vector4(), goal_fx = vmath.vector4(), emphasis = 0 }
		view.extent = math.max(view.extent, extent)
	end
	return view
end

-- Lays out unplaced pieces (those without a displayed pose) for a w x h screen whose bottom
-- `inset` fraction is the tray; rotation is the board camera's. A piece being dragged out of
-- the tray, not yet over the board, follows `pointer` ({ x, y } or nil). ui.held: the
-- orientations of turned tray pieces (game/play), shown as the pieces will be placed.
function M.present(view, display, ui, w, h, inset, rotation)
	cameras.set("tray", CAMERA_POSITION, rotation, CAMERA_FOV, w / h, 0.1, 50)
	view.rotation = rotation
	view.screen_width = w
	view.screen_height = h
	view.height = h * inset
	view.slots = {}
	local unplaced = {}
	for id in pairs(view.pieces) do
		if not display.poses[id] then
			unplaced[#unplaced + 1] = id
		end
	end
	table.sort(unplaced)
	local slot = math.min(w * 0.9 / view.count, view.height * 1.3)
	local left = (w - slot * #unplaced) / 2
	for i, id in ipairs(unplaced) do
		view.slots[id] = { x = left + slot * (i - 0.5), y = view.height / 2, size = slot }
	end
	local held = view.slots[display.dragging or -1]
	if held and ui.pointer then
		held.x, held.y, held.size, held.held = ui.pointer.x, ui.pointer.y, slot * 1.2, true
	end
	for id, piece_view in pairs(view.pieces) do
		piece_view.goal_rotation = board_view.poseRotation(ui.held and ui.held[id] or orient.identity)
		piece_view.goal_fx = vmath.vector4(id == ui.selected and 1 or 0, 0, 0, id == ui.hovered and 1 or 0)
		piece_view.emphasis = (id == ui.selected or id == ui.hovered) and 1 or 0
	end
end

-- Applies display preferences: { colors, patterns }.
function M.configure(view, prefs)
	view.look = piece_look.update(view.look, view.pieces, view.level, prefs)
end

function M.contains(view, y)
	return y <= view.height
end

-- Piece id whose slot contains the screen point, or nil.
function M.pick(view, x, y)
	for id, s in pairs(view.slots) do
		if not s.held and math.abs(x - s.x) <= s.size / 2 and y <= view.height then
			return id
		end
	end
end

-- World position of a screen point at DEPTH in front of the tray camera.
local function slotToWorld(view, x, y, tan_half)
	local half_h = view.screen_height / 2
	local local_point = vmath.vector3(
		(x - view.screen_width / 2) / half_h * DEPTH * tan_half,
		(y - half_h) / half_h * DEPTH * tan_half,
		-DEPTH)
	return CAMERA_POSITION + vmath.rotate(view.rotation, local_point)
end

-- Slots ease in screen space, so pieces glide when the layout changes but stay put on
-- screen while the camera turns.
function M.step(view, dt)
	local k = 1 - math.exp(-EASE_RATE * dt)
	local tan_half = math.tan(CAMERA_FOV / 2)
	local world_per_px = 2 * DEPTH * tan_half / view.screen_height
	for id, piece_view in pairs(view.pieces) do
		local slot = view.slots[id]
		local should_show = slot ~= nil
		if should_show ~= piece_view.shown then
			piece_view.shown = should_show
			msg.post(piece_view.mesh, piece_view.shown and "enable" or "disable")
			piece_view.screen = nil
		end
		if slot then
			local goal = vmath.vector3(slot.x, slot.y, math.min(slot.size, view.height) * (1 + 0.1 * piece_view.emphasis))
			piece_view.screen = piece_view.screen and vmath.lerp(k, piece_view.screen, goal) or goal
			local sx, sy, size = piece_view.screen.x, piece_view.screen.y, piece_view.screen.z
			local scale = size * world_per_px * SLOT_FILL / view.extent
			local goal_rotation = piece_view.goal_rotation or vmath.quat()
			piece_view.rotation = piece_view.rotation and vmath.slerp(k, piece_view.rotation, goal_rotation) or goal_rotation
			local position = slotToWorld(view, sx, sy, tan_half) - vmath.rotate(piece_view.rotation, piece_view.center) * scale
			piece_view.fx = vmath.lerp(k, piece_view.fx, piece_view.goal_fx)
			go.set_position(position, piece_view.go)
			go.set_rotation(piece_view.rotation, piece_view.go)
			go.set_scale(scale, piece_view.go)
			go.set(piece_view.mesh, "fx", piece_view.fx)
		end
	end
end

function M.destroy(view)
	for _, piece_view in pairs(view.pieces) do
		go.delete(piece_view.go)
	end
end

return hot(..., M)
