local settings = require "game.settings"

describe("settings", function()
	it("fills in defaults and rejects values of the wrong shape", function()
		local s = settings.new({ sound = 3, colors = "sepia", invert = "yes", ui_scale = 1.15 })
		assert.equal(1, s.sound)
		assert.equal("default", s.colors)
		assert.is_false(s.invert)
		assert.equal(1.15, s.ui_scale)
	end)

	it("changes one value without touching the original", function()
		local a = settings.new()
		local b = settings.with(a, "frame_rate", 30)
		assert.equal(60, a.frame_rate)
		assert.equal(30, b.frame_rate)
	end)
end)
