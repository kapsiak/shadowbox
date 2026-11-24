-- Player preferences. Pure Lua: plain values with defaults, sanitized when loaded.
-- Sliders have ranges, choices have a fixed list of values, `bindings` is a table of the key
-- bindings a player changed (input/controls cleans it), everything else is a toggle.
local hot = require "core.hot"
local M = {}

M.defaults = {
	sound = 0.8,
	music = 0.6,
	sensitivity = 1.0,
	invert = false,
	left_handed = false,
	open_all = false,
	reduced_motion = false,
	patterns = false,
	high_contrast = false,
	colors = "default",
	ui_scale = 1,
	fullscreen = false,
	quality = "balanced",
	frame_rate = 60,
	bindings = {},
}

local ranges = { sound = { 0, 1 }, music = { 0, 1 }, sensitivity = { 0.4, 2 } }

M.choices = {
	colors = {
		values = { "default", "deuteranopia", "protanopia", "tritanopia" },
		labels = { "Off", "Deut", "Prot", "Trit" },
	},
	ui_scale = { values = { 0.85, 1, 1.15, 1.3 }, labels = { "S", "M", "L", "XL" } },
	quality = { values = { "low", "balanced", "high" }, labels = { "Low", "Medium", "High" } },
	frame_rate = { values = { 30, 60, 0 }, labels = { "30", "60", "Max" } },
}

local function isChoice(key, value)
	for _, v in ipairs(M.choices[key].values) do
		if v == value then
			return true
		end
	end
	return false
end

local function sanitize(key, value)
	local default = M.defaults[key]
	if type(value) ~= type(default) then
		return default
	end
	if M.choices[key] then
		return isChoice(key, value) and value or default
	end
	local range = ranges[key]
	if range then
		return math.max(range[1], math.min(range[2], value))
	end
	return value
end

function M.new(data)
	local s = {}
	for key in pairs(M.defaults) do
		s[key] = sanitize(key, data and data[key])
	end
	return s
end

-- Returns a copy of `s` with one value changed (sanitized).
function M.with(s, key, value)
	local copy = {}
	for k, v in pairs(s) do
		copy[k] = v
	end
	copy[key] = sanitize(key, value)
	return copy
end

function M.range(key)
	return ranges[key]
end

-- How much of the screen resolution the 3D scene renders at: a quality choice caps the pixel
-- density (render pixels per logical pixel; high keeps the display's own). display_scale: the
-- display's density (window.get_display_scale).
function M.renderScale(quality, display_scale)
	local cap = ({ low = 1, balanced = 2 })[quality]
	return cap and math.min(1, cap / display_scale) or 1
end

return hot(..., M)
