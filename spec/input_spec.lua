local raycast = require "core.raycast"
local gestures = require "input.gestures"
local interpret = require "input.interpret"
local router = require "input.router"

local function feedAll(rec, events)
	local out = {}
	for _, ev in ipairs(events) do
		for _, g in ipairs(gestures.feed(rec, ev)) do
			out[#out + 1] = g
		end
	end
	return out
end

local function kinds(list)
	local out = {}
	for i, g in ipairs(list) do
		out[i] = g.kind
	end
	return out
end

local function pointer(x, y, flags)
	local ev = { kind = "pointer", button = "primary", x = x, y = y }
	for k, v in pairs(flags or {}) do
		ev[k] = v
	end
	return ev
end

describe("raycast", function()
	local size = { 3, 3, 3 }
	local function solidAt(target)
		return function(c)
			return c[1] == target[1] and c[2] == target[2] and c[3] == target[3]
		end
	end

	it("hits the first solid cell and reports the entry face", function()
		local cell, normal = raycast.firstHit(size, { 1.5, 1.5, 10 }, { 0, 0, -1 }, solidAt({ 1, 1, 0 }))
		assert.same({ 1, 1, 0 }, cell)
		assert.same({ 0, 0, 1 }, normal)
	end)

	it("misses rays that pass beside the grid", function()
		assert.is_nil(raycast.firstHit(size, { 5, 1.5, 10 }, { 0, 0, -1 }, function() return true end))
	end)

	it("walks diagonally through cells", function()
		local d = 1 / math.sqrt(3)
		local cell = raycast.firstHit(size, { -1, -1, -1 }, { d, d, d }, solidAt({ 2, 2, 2 }))
		assert.same({ 2, 2, 2 }, cell)
	end)
end)

describe("gestures", function()
	it("reports a short press as a tap", function()
		local out = feedAll(gestures.new(10), { pointer(0, 0, { pressed = true }), pointer(3, 0, { released = true }) })
		assert.same({ "press", "tap" }, kinds(out))
	end)

	it("reports movement past the threshold as a drag, ending where it last moved", function()
		local out = feedAll(gestures.new(10), {
			pointer(0, 0, { pressed = true }), pointer(20, 0), pointer(25, 0, { released = true }),
		})
		assert.same({ "press", "drag_start", "drag_move", "drag_end" }, kinds(out))
		assert.equal(20, out[4].x)
		assert.equal(20, out[3].dx)
	end)

	local function touches(...)
		return { kind = "touches", points = { ... } }
	end

	it("reports a second finger lifting, and moving fingers as a pinch", function()
		local rec = gestures.new(10)
		local tapped = feedAll(rec, {
			touches({ id = 1, x = 0, y = 0, pressed = true }),
			touches({ id = 1, x = 0, y = 0 }, { id = 2, x = 100, y = 0, pressed = true }),
			touches({ id = 1, x = 0, y = 0 }, { id = 2, x = 100, y = 0, released = true }),
		})
		assert.same({ "second_up" }, kinds(tapped))

		local pinched = feedAll(gestures.new(10), {
			touches({ id = 1, x = 0, y = 0, pressed = true }, { id = 2, x = 100, y = 0, pressed = true }),
			touches({ id = 1, x = 0, y = 0 }, { id = 2, x = 200, y = 0 }),
			touches({ id = 1, x = 0, y = 0 }, { id = 2, x = 200, y = 0, released = true }),
		})
		assert.same({ "two_finger", "second_up" }, kinds(pinched))
		assert.equal(2, pinched[1].scale)
		assert.equal(50, pinched[1].dx)
	end)

	it("keeps a drag alive while a second button is clicked", function()
		local out = feedAll(gestures.new(10), {
			pointer(0, 0, { pressed = true }), pointer(30, 0),
			{ kind = "pointer", button = "secondary", x = 30, y = 0, pressed = true },
			{ kind = "pointer", button = "secondary", x = 30, y = 0, released = true },
			pointer(40, 0), pointer(40, 0, { released = true }),
		})
		assert.same({ "press", "drag_start", "drag_move", "press", "tap", "drag_move", "drag_end" }, kinds(out))
	end)
end)

describe("router", function()
	local function onControl(x)
		return x < 10 and "undo" or nil
	end

	local function phases(events)
		local out = {}
		for i, e in ipairs(events) do
			out[i] = e.id .. ":" .. e.phase
		end
		return out
	end

	it("claims a pointer that starts on a control until it lifts", function()
		local r, events = router.new(), {}
		assert.is_nil(router.route(r, pointer(5, 0, { pressed = true }), onControl, events))
		assert.is_nil(router.route(r, pointer(50, 0), onControl, events))
		assert.is_nil(router.route(r, pointer(50, 0, { released = true }), onControl, events))
		assert.truthy(router.route(r, pointer(50, 0, { pressed = true }), onControl, events))
		assert.same({ "undo:press", "undo:move", "undo:release" }, phases(events))
	end)

	it("lets a second finger use a control while the first drags", function()
		local r, events = router.new(), {}
		router.route(r, { kind = "touches", points = { { id = 1, x = 50, y = 0, pressed = true } } }, onControl, events)
		local passed = router.route(r, { kind = "touches", points = {
			{ id = 1, x = 60, y = 0 }, { id = 2, x = 5, y = 0, pressed = true },
		} }, onControl, events)
		assert.same({ "undo:press" }, phases(events))
		assert.equal(1, #passed.points)
	end)
end)

describe("interpret", function()
	it("selects what a tap picks and orbits on drag", function()
		local state, out = interpret.new(100), {}
		interpret.gesture(state, { kind = "tap", button = "primary", x = 1, y = 2 }, function() return { piece = 7 } end, out)
		interpret.gesture(state, { kind = "drag_start", button = "primary" }, function() return nil end, out)
		interpret.gesture(state, { kind = "drag_move", button = "primary", dx = 100, dy = 0 }, nil, out)
		assert.same({ kind = "tap", piece = 7 }, out[1])
		assert.equal("orbit", out[2].kind)
		assert.near(-math.pi, out[2].yaw, 1e-9)
	end)

	it("drags a grabbed piece and drops it where the pointer lifts", function()
		local state, out = interpret.new(100), {}
		local hit = { piece = 3, cell = { 1, 0, 1 } }
		interpret.gesture(state, { kind = "drag_start", button = "primary", x = 0, y = 0 }, function() return hit end, out)
		interpret.gesture(state, { kind = "drag_move", button = "primary", x = 5, y = 6, dx = 5, dy = 6 }, nil, out)
		interpret.gesture(state, { kind = "drag_end", button = "primary", x = 5, y = 6 }, nil, out)
		assert.same({ "grab", "drag", "drop" }, kinds(out))
		assert.equal(3, out[1].piece)
	end)

	it("turns a dragged piece about one axis per touch, holding it still meanwhile", function()
		local state, out = interpret.new(100), {}
		interpret.gesture(state, { kind = "drag_start", button = "primary", x = 0, y = 0 }, function() return { piece = 1 } end, out)
		interpret.gesture(state, { kind = "drag_move", button = "primary", x = 5, y = 0, dx = 5, dy = 0, multi = true }, nil, out)
		for _, step in ipairs({ { 0.1, 3 }, { 0.1, 0 }, { 0, 30 }, { 0.05, 0 } }) do
			interpret.gesture(state, { kind = "two_finger", scale = 1, twist = step[1], dx = 0, dy = step[2] }, nil, out)
		end
		interpret.gesture(state, { kind = "second_up" }, nil, out)
		interpret.gesture(state, { kind = "drag_move", button = "primary", x = 20, y = 0, dx = 15, dy = 0 }, nil, out)
		assert.same({ "grab", "spin", "spin", "spin_end", "drag" }, kinds(out))
		assert.same({ "vertical", "vertical" }, { out[2].about, out[3].about })
		assert.near(-0.2, out[2].angle, 1e-9)
		assert.equal(15, out[5].x)
	end)

	it("tips a dragged piece while the right button drags", function()
		local state, out = interpret.new(100), {}
		state.turn_step = 80
		interpret.gesture(state, { kind = "drag_start", button = "primary", x = 0, y = 0 }, function() return { piece = 1 } end, out)
		interpret.gesture(state, { kind = "drag_start", button = "secondary", x = 0, y = 0 }, nil, out)
		interpret.gesture(state, { kind = "drag_move", button = "secondary", x = 0, y = -10, dx = 0, dy = -10 }, nil, out)
		interpret.gesture(state, { kind = "drag_move", button = "primary", x = 0, y = -10, dx = 0, dy = -10 }, nil, out)
		interpret.gesture(state, { kind = "drag_end", button = "secondary", x = 0, y = -10 }, nil, out)
		assert.same({ "grab", "spin", "spin_end" }, kinds(out))
		assert.equal("right", out[2].about)
		assert.near(10 / 80 * math.pi / 2, out[2].angle, 1e-9)
	end)

	it("acts on keys and buttons alike; held actions let go on release or blur", function()
		local state, out = interpret.new(100), {}
		interpret.button("stow", "press", out)
		interpret.button("stow", "release", out)
		interpret.gesture(state, { kind = "key", name = "remove", pressed = true }, nil, out)
		interpret.button("peek", "press", out)
		interpret.gesture(state, { kind = "key", name = "peek", released = true }, nil, out)
		interpret.gesture(state, { kind = "blur" }, nil, out)
		local seen = {}
		for i, intent in ipairs(out) do
			seen[i] = intent.kind .. (intent.on == nil and "" or tostring(intent.on))
		end
		assert.same({ "remove", "remove", "peektrue", "peekfalse", "peekfalse" }, seen)
	end)
end)

describe("controls", function()
	local controls = require "input.controls"

	it("maps keys to actions, with the player's changes over the defaults", function()
		local map = controls.keymap({ turn_left = { "j" } })
		assert.equal("turn_left", map.j)
		assert.is_nil(map.q)
		assert.equal("remove", map.delete)
		assert.equal("menu", map.escape)
	end)

	it("moves a key to the action it is bound to, keeping only changes", function()
		local b = controls.rebind({}, "undo", "q")
		assert.same({ undo = { "q" }, turn_left = {} }, b)
		assert.same({}, controls.rebind(b, "turn_left", "q") and controls.changed(controls.rebind(controls.rebind(b, "turn_left", "q"), "undo", "z")))
		assert.is_nil(controls.rebind({}, "menu", "m"))
		assert.is_nil(controls.rebind({}, "undo", "escape"))
	end)

	it("drops unknown actions and keys from saved bindings", function()
		assert.same({ undo = { "x" } }, controls.changed({ undo = { "x", "nope" }, jump = { "j" }, redo = { "y" } }))
	end)
end)
