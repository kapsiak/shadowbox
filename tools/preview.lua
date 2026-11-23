-- Usage (from the project root): luajit tools/preview.lua levels/<pack>/<level>.lua ...
package.path = "./?.lua;" .. package.path

local level = require "core.level"
local channels = require "core.channels"

local function readFile(path)
	local f, err = io.open(path, "r")
	if not f then
		return nil, err
	end
	local source = f:read("*a")
	f:close()
	return source
end

local glyphs = {
	light = { [0] = "#", "r", "g", "y", "b", "m", "c", "." },
	pattern = { [0] = ".", "-", "|", "+" },
	parity = { [0] = ".", "#" },
}
glyphs.count = setmetatable({ [0] = "." }, { __index = function(_, n) return tostring(n) end })

local function layerRows(proj, name)
	local rows = {}
	for v = proj.h - 1, 0, -1 do
		local row = {}
		for u = 0, proj.w - 1 do
			row[#row + 1] = glyphs[name][proj.layers[name][u + v * proj.w + 1]]
		end
		rows[#rows + 1] = table.concat(row, " ")
	end
	return rows
end

local function printSideBySide(level_data)
	local columns, width, height = {}, {}, 0
	for _, v in ipairs(level_data.views) do
		local names = level_data.channels[v]
		for _, name in ipairs(names) do
			local column = layerRows(level_data.targets[v], name)
			table.insert(column, 1, (#names > 1 or name ~= "light") and v .. " " .. name or v)
			local w = 0
			for _, row in ipairs(column) do
				w = math.max(w, #row)
			end
			columns[#columns + 1], width[#columns + 1] = column, w
			height = math.max(height, #column)
		end
	end
	for r = 1, height do
		local line = {}
		for i, column in ipairs(columns) do
			line[#line + 1] = ("%-" .. width[i] .. "s"):format(column[r] or "")
		end
		print("  " .. table.concat(line, "    "))
	end
end

local function preview(path)
	local source, read_err = readFile(path)
	if not source then
		print(path .. ": " .. read_err)
		return false
	end
	local lvl, err = level.load(source, path)
	if not lvl then
		print(path .. ": " .. err)
		return false
	end
	local s = lvl.size
	print(("%s  (%s)  %dx%dx%d"):format(lvl.name, path, s[1], s[2], s[3]))
	for _, p in ipairs(lvl.pieces) do
		local look = p.color or ""
		for _, name in ipairs(channels.order) do
			local channel = channels[name]
			for word, n in pairs(channel.names or {}) do
				if n == p.value[name] then
					look = look .. " " .. channel.key .. "=" .. word
				end
			end
		end
		print(("  %s  %-24s %d cubes"):format(p.key, look, p.shape.size))
	end
	printSideBySide(lvl)
	print()
	return true
end

local ok = true
for _, path in ipairs(arg) do
	ok = preview(path) and ok
end
os.exit(ok and 0 or 1)
