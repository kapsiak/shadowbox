local level = require "core.level"
local save_data = require "game.save_data"
local progress = require "game.progress"
local settings = require "game.settings"

local function catalogWith(lvl)
	return { packs = { { id = "p", levels = { lvl, lvl }, keys = { "p/a", "p/b" } } } }
end

local lvl = assert(level.parse({
	pieces = { A = "coral", B = "sky" },
	layers = { { "AAB", "..B" }, { "A..", "..." } },
}))
local catalog = catalogWith(lvl)
local pose = { cell = { 0, 0, 0 }, orient = 1 }

describe("save data", function()
	it("round-trips progress, settings, the last level and boards", function()
		local app = {
			progress = progress.new({ solved = { ["p/a"] = true } }),
			settings = settings.new({ sound = 0.3 }),
			last = { pack = 1, index = 2 },
			boards = { ["p/a"] = { [1] = pose } },
		}
		local back = save_data.decode(save_data.encode(app, catalog), catalog)
		assert.is_true(progress.isSolved(back.progress, "p/a"))
		assert.equal(0.3, back.settings.sound)
		assert.same({ pack = 1, index = 2 }, back.last)
		assert.same({ [1] = pose }, back.boards["p/a"])
	end)

	it("drops boards whose level changed, and malformed or overlapping poses", function()
		local fp = save_data.fingerprint(lvl)
		local back = save_data.decode({ version = 1, boards = {
			["p/a"] = { fingerprint = fp + 1, poses = { [1] = pose } },
			["p/b"] = { fingerprint = fp, poses = { [1] = pose, [2] = pose, [3] = pose } },
			["gone/x"] = { fingerprint = fp, poses = {} },
		} }, catalog)
		assert.is_nil(back.boards["p/a"])
		assert.is_nil(back.boards["gone/x"])
		local count = 0
		for _ in pairs(back.boards["p/b"]) do count = count + 1 end
		assert.equal(1, count)
	end)

	it("survives garbage", function()
		local empty = save_data.decode({ version = "x", progress = 4, settings = "y", boards = { 1 }, last = {} }, catalog)
		assert.is_nil(empty.last)
		assert.same({}, empty.boards)
		assert.equal(settings.defaults.sound, empty.settings.sound)
	end)
end)
