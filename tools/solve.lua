-- Usage (from the project root): luajit tools/solve.lua [-s] [-n limit] levels/<pack>/<level>.lua ...
-- Prints each level's difficulty profile; -s prints one summary line per level instead.
package.path = "./?.lua;./tools/?.lua;" .. package.path

local level = require "core.level"
local solver = require "solver"

local function loadLevel(path)
	local f, err = io.open(path, "r")
	if not f then
		return nil, err
	end
	local source = f:read("*a")
	f:close()
	return level.load(source, path)
end

local function count(report)
	return report.solutions .. (report.capped and "+" or "")
end

local function totals(lvl, report)
	local cubes, cands = 0, 0
	for _, p in ipairs(report.pieces) do
		cubes, cands = cubes + p.cubes, cands + p.candidates
	end
	return cubes, cands / #report.pieces
end

local function printDetail(path, lvl, report, seconds)
	local s = lvl.size
	print(("%s  (%s)  %dx%dx%d  views: %s%s"):format(lvl.name, path, s[1], s[2], s[3],
		table.concat(lvl.views, " "), lvl.rules.use_all and "" or "  spares allowed"))
	print(("  solutions %s   nodes %d   %.2fs"):format(count(report), report.nodes, seconds))
	for _, p in ipairs(report.pieces) do
		local notes = p.chiral and (p.mirror_of and "mirror of " .. p.mirror_of or "chiral") or ""
		notes = p.must_turn and notes .. " must turn" or notes
		print(("  %s  %d cubes  %2d orients  %4d candidates  %3d placements in solutions  %s"):format(
			p.key, p.cubes, p.orients, p.candidates, p.placements, notes))
	end
	if #report.hidden > 0 then
		local by_piece, keys = {}, {}
		for _, h in ipairs(report.hidden) do
			if not by_piece[h.piece] then
				keys[#keys + 1] = h.piece
			end
			by_piece[h.piece] = (by_piece[h.piece] or 0) + 1
		end
		for i, k in ipairs(keys) do
			keys[i] = k .. by_piece[k]
		end
		print(("  hidden cubes %d/%d: %s"):format(#report.hidden, totals(lvl, report), table.concat(keys, " ")))
	end
	for _, v in ipairs(report.solid_views) do
		print(("  solid view: %s"):format(v))
	end
	if #lvl.pieces > 7 then
		print(("  tray: %d pieces"):format(#lvl.pieces))
	end
	print()
end

local header = ("%-18s %-7s %6s %5s %6s %5s %9s %8s %6s"):format(
	"level", "size", "pieces", "cubes", "views", "turns", "solutions", "avg cand", "nodes")

local function printSummary(lvl, report)
	local s = lvl.size
	local cubes, avg = totals(lvl, report)
	local turns = 0
	for _, p in ipairs(report.pieces) do
		turns = turns + (p.must_turn and 1 or 0)
	end
	print(("%-18s %-7s %6d %5d %6d %5d %9s %8.1f %6d"):format(lvl.name:sub(1, 18),
		("%dx%dx%d"):format(s[1], s[2], s[3]), #lvl.pieces, cubes, #lvl.views, turns, count(report),
		avg, report.nodes))
end

local summary, limit, paths = false, 1000, {}
local i = 1
while i <= #arg do
	if arg[i] == "-s" then
		summary = true
	elseif arg[i] == "-n" then
		i = i + 1
		limit = tonumber(arg[i])
	else
		paths[#paths + 1] = arg[i]
	end
	i = i + 1
end

if summary then
	print(header)
end
local ok = true
for _, path in ipairs(paths) do
	local lvl, err = loadLevel(path)
	if not lvl then
		print(path .. ": " .. err)
		ok = false
	else
		local start = os.clock()
		local report = solver.analyse(lvl, { limit = limit })
		if summary then
			printSummary(lvl, report)
		else
			printDetail(path, lvl, report, os.clock() - start)
		end
	end
end
os.exit(ok and 0 or 1)
