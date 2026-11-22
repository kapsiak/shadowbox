local progress = require "game.progress"

local function catalogOf(...)
	local packs = {}
	for i, count in ipairs({ ... }) do
		local keys = {}
		for l = 1, count do
			keys[l] = ("p%d/l%d"):format(i, l)
		end
		packs[i] = { id = "p" .. i, keys = keys }
	end
	return { packs = packs }
end

describe("progress", function()
	local catalog = catalogOf(4, 2)

	it("opens the first levels and unlocks by solving recent ones", function()
		local p = progress.new()
		assert.is_true(progress.isOpen(p, catalog, 1, 2))
		assert.is_false(progress.isOpen(p, catalog, 1, 3))
		progress.markSolved(p, "p1/l1")
		assert.is_true(progress.isOpen(p, catalog, 1, 3))
		assert.is_false(progress.isOpen(p, catalog, 1, 4))
	end)

	it("opens a pack once half of the previous one is solved", function()
		local p = progress.new()
		progress.markSolved(p, "p1/l1")
		assert.is_false(progress.isPackOpen(p, catalog, 2))
		progress.markSolved(p, "p1/l2")
		assert.is_true(progress.isPackOpen(p, catalog, 2))
	end)

	it("finds the next unsolved open level, crossing packs", function()
		local p = progress.new({ solved = { ["p1/l1"] = true, ["p1/l2"] = true, ["p1/l3"] = true, ["p1/l4"] = true } })
		assert.same({ 2, 1 }, { progress.next(p, catalog, 1, 4) })
		assert.is_nil(progress.next(p, catalog, 2, 2))
	end)
end)
