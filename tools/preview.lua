-- Usage (from the project root): luajit tools/preview.lua levels/<pack>/<level>.lua ...
package.path = "./?.lua;" .. package.path

local level = require "core.level"

local function readFile(path)
	local f, err = io.open(path, "r")
	if not f then
		return nil, err
	end
	local source = f:read("*a")
	f:close()
	return source
end

local function projectionRows(proj)
	local rows = {}
	for v = proj.h - 1, 0, -1 do
		local row = {}
		for u = 0, proj.w - 1 do
			row[#row + 1] = proj.filled[u + v * proj.w + 1] and "#" or "."
		end
		rows[#rows + 1] = table.concat(row, " ")
	end
	return rows
end

local function printSideBySide(level_data)
	local columns, width, height = {}, {}, 0
	for i, v in ipairs(level_data.views) do
		columns[i] = projectionRows(level_data.targets[v])
		table.insert(columns[i], 1, v)
		width[i] = 0
		for _, row in ipairs(columns[i]) do
			width[i] = math.max(width[i], #row)
		end
		height = math.max(height, #columns[i])
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
		print(("  %s  %-8s %d cubes"):format(p.key, p.color, p.shape.size))
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
