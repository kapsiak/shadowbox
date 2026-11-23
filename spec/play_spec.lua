local level = require "core.level"
local play = require "game.play"
local history = require "core.history"

local lvl = assert(level.parse({
	pieces = { A = "coral", B = "sky" },
	layers = { { "AA..", "A.BB" }, { "....", "...." } },
}))
local DOWN = { 0, -1, 0 }

local function dragFromTray(s, piece, x, z)
	play.grab(s, piece)
	play.dragTo(s, { x + 0.5, 10, z + 0.5 }, DOWN)
	return play.drop(s, false)
end

describe("play", function()
	it("places a piece from the tray resting on the floor", function()
		local s = play.new(lvl)
		assert.is_true(dragFromTray(s, 2, 2, 1))
		local pose = play.current(s).poses[2]
		assert.same({ 2, 0, 1 }, pose.cell)
	end)

	it("stacks a dragged piece on top of what lies under the pointer", function()
		local s = play.new(lvl)
		dragFromTray(s, 1, 0, 0)
		play.grab(s, 2)
		play.dragTo(s, { 1.5, 10, 0.5 }, DOWN)
		assert.is_nil(play.display(s).invalid)
		assert.equal(1, play.display(s).poses[2].cell[2])
	end)

	it("refuses a drop off the board, keeping the last legal preview", function()
		local s = play.new(lvl)
		play.grab(s, 1)
		play.dragTo(s, { 0.5, 10, 0.5 }, DOWN)
		play.dragTo(s, { 9.5, 10, 0.5 }, DOWN)
		assert.equal(1, play.display(s).invalid)
		assert.is_false(play.drop(s, false))
		assert.is_nil(play.current(s).poses[1])
	end)

	it("slides a piece that would leave the board back inside", function()
		local s = play.new(lvl)
		assert.is_true(dragFromTray(s, 2, 3, 0))
		assert.same({ 2, 0, 0 }, play.current(s).poses[2].cell)
	end)

	it("rests a piece against the face or wall under the pointer", function()
		local s = play.new(lvl)
		dragFromTray(s, 1, 0, 0)
		play.grab(s, 2)
		play.dragTo(s, { 10, 0.5, 0.5 }, { -1, 0, 0 })
		assert.same({ 2, 0, 0 }, play.display(s).poses[2].cell)
		play.dragTo(s, { 10, 1.5, 0.5 }, { -1, 0, 0 })
		assert.same({ 0, 1, 0 }, play.display(s).poses[2].cell)
		assert.is_nil(play.display(s).invalid)
	end)

	it("reaches the solved state and undoes back out of it", function()
		local s = play.new(lvl)
		history.push(s.history, { poses = lvl.solution })
		assert.is_true(play.isSolved(s))
		play.undo(s)
		assert.is_false(play.isSolved(s))
	end)

	it("kicks a turned piece into a free spot", function()
		local s = play.new(lvl)
		dragFromTray(s, 2, 2, 0)
		play.tap(s, 2)
		assert.is_true(play.turn(s, 3, 1))
		assert.are_not.equal(1, play.current(s).poses[2].orient)
	end)

	it("turns a dragged piece about the grabbed cube's column without committing", function()
		local s = play.new(lvl)
		dragFromTray(s, 1, 0, 0)
		play.grab(s, 1, { 1, 0, 0 })
		play.turn(s, 3, 1)
		local display = play.display(s)
		local cells = require("core.shape").cellsAt(lvl.pieces[1].shape, display.poses[1])
		local in_column = false
		for _, c in ipairs(cells) do
			in_column = in_column or (c[1] == 1 and c[3] == 0)
		end
		assert.is_true(in_column)
		assert.is_nil(display.invalid)
		assert.equal(1, play.current(s).poses[1].orient)
	end)

	it("never hides a turn made while dragging", function()
		local s = play.new(lvl)
		dragFromTray(s, 1, 0, 0)
		play.grab(s, 2)
		play.dragTo(s, { 2.5, 10, 1.5 }, DOWN)
		for _ = 1, 4 do
			play.turn(s, 3, 1)
			assert.equal(s.drag.orient, play.display(s).poses[2].orient)
		end
	end)

	it("nudges a dragged piece off the floor and the selection when idle", function()
		local s = play.new(lvl)
		play.grab(s, 2)
		play.dragTo(s, { 2.5, 10, 0.5 }, DOWN)
		play.nudge(s, 2, 1)
		assert.equal(1, play.display(s).poses[2].cell[2])
		play.drop(s, false)
		assert.is_true(play.nudge(s, 2, -1))
		assert.equal(0, play.current(s).poses[2].cell[2])
	end)

	it("restores a saved arrangement, dropping poses that no longer fit", function()
		local saved = { [1] = lvl.solution[1], [2] = { cell = { 9, 0, 0 }, orient = 1 } }
		local s = play.new(lvl, saved)
		assert.same(lvl.solution[1], play.current(s).poses[1])
		assert.is_nil(play.current(s).poses[2])
		assert.is_true(play.hasProgress(s))
	end)
end)
