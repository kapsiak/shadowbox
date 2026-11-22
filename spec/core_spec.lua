local orient = require "core.orient"
local shape = require "core.shape"
local level = require "core.level"
local rules = require "core.rules"
local state = require "core.state"
local history = require "core.history"

local function parse(layers, pieces, extra)
	local def = extra or {}
	def.layers, def.pieces = layers, pieces
	return level.parse(def)
end

local function solvedState(lvl)
	return { poses = lvl.solution }
end

describe("orient", function()
	it("has 24 distinct rotations", function()
		local seen = {}
		for n = 1, orient.count do
			seen[table.concat(orient.apply(n, { 1, 2, 3 }), ",")] = true
		end
		local count = 0
		for _ in pairs(seen) do
			count = count + 1
		end
		assert.equal(24, count)
	end)

	it("returns to the start after four quarter turns", function()
		for n = 1, orient.count do
			for axis = 1, 3 do
				local m = n
				for _ = 1, 4 do
					m = orient.turn(m, axis, 1)
				end
				assert.equal(n, m)
				assert.equal(n, orient.turn(orient.turn(n, axis, 1), axis, -1))
			end
		end
	end)
end)

describe("shape", function()
	it("keeps the anchor fixed when turning", function()
		local s, anchor = shape.new({ { 0, 0, 0 }, { 1, 0, 0 }, { 2, 0, 0 } })
		assert.same({ 1, 0, 0 }, anchor)
		local turned = shape.cellsAt(s, { cell = { 5, 5, 5 }, orient = orient.turn(1, 3, 1) })
		assert.same({ { 5, 4, 5 }, { 5, 5, 5 }, { 5, 6, 5 } }, turned)
	end)
end)

describe("level.parse", function()
	it("derives size, pieces and targets from the drawing", function()
		local lvl = assert(parse({ { "AAB", "..B" }, { "A..", "..." } }, { A = "coral", B = "sky" }))
		assert.same({ 3, 2, 2 }, lvl.size)
		assert.equal(2, #lvl.pieces)
		assert.same({ true, true, true, true, false, false }, lvl.targets.front.filled)
		assert.same({ true, true, true, false }, lvl.targets.side.filled)
	end)

	it("rejects malformed levels with a reason", function()
		local cases = {
			{ { { "AA", "A" } }, { A = "red" }, "expected 2 columns" },
			{ { { "A#" } }, { A = "red" }, "unexpected character" },
			{ { { "AB" } }, { A = "red" }, "missing from pieces" },
			{ { { "A." } }, { A = "red", B = "sky" }, "not drawn" },
			{ { { "A.A" } }, { A = "red" }, "not face%-connected" },
		}
		for _, case in ipairs(cases) do
			local lvl, err = parse(case[1], case[2])
			assert.is_nil(lvl)
			assert.truthy(err:find(case[3]), err)
		end
	end)

	it("runs level source in an empty environment", function()
		local lvl, err = level.load("os.exit(1)", "evil")
		assert.is_nil(lvl)
		assert.truthy(err:find("os"))
	end)
end)

describe("rules", function()
	local lvl = assert(parse({ { "AAB", "..B" }, { "A..", "..." } }, { A = "coral", B = "sky" }))

	it("accepts the authored solution as solved", function()
		assert.is_true(rules.evaluate(lvl, solvedState(lvl)).solved)
	end)

	it("requires every piece when use_all is set", function()
		local partial = state.apply(solvedState(lvl), { changes = { { piece = 2 } } })
		assert.is_false(rules.evaluate(lvl, partial).solved)
	end)

	it("refuses overlap and out-of-bounds placements", function()
		local s = state.apply(state.new(), { changes = { { piece = 1, pose = lvl.solution[1] } } })
		local _, overlap = rules.check(lvl, s, { kind = "place", piece = 2, pose = lvl.solution[1] })
		assert.equal("overlap", overlap)
		local _, outside = rules.check(lvl, s, { kind = "place", piece = 2, pose = { cell = { 9, 0, 0 }, orient = 1 } })
		assert.equal("out_of_bounds", outside)
	end)
end)

describe("history", function()
	it("drops redo states when a new state is pushed", function()
		local h = history.new("a")
		history.push(h, "b")
		history.undo(h)
		history.push(h, "c")
		history.redo(h)
		assert.equal("c", history.current(h))
		history.undo(h)
		assert.equal("a", history.current(h))
	end)
end)
