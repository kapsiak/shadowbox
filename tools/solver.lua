local orient = require "core.orient"
local shape = require "core.shape"
local grid = require "core.grid"
local channels = require "core.channels"
local projection = require "core.projection"
local rules = require "core.rules"

local M = {}

local function cellsKey(indices)
	local sorted = { unpack(indices) }
	table.sort(sorted)
	return table.concat(sorted, ",")
end

local function normalized(form)
	local lo = { math.huge, math.huge, math.huge }
	for _, c in ipairs(form) do
		for a = 1, 3 do
			lo[a] = math.min(lo[a], c[a])
		end
	end
	local out = {}
	for i, c in ipairs(form) do
		out[i] = { c[1] - lo[1] + 0, c[2] - lo[2] + 0, c[3] - lo[3] + 0 }
	end
	return out
end

local function formKey(form)
	local parts = {}
	for i, c in ipairs(normalized(form)) do
		parts[i] = table.concat(c, ":")
	end
	table.sort(parts)
	return table.concat(parts, " ")
end

local function shapeInfo(piece_shape)
	local seen, distinct, canonical = {}, 0, nil
	for n = 1, orient.count do
		local key = formKey(piece_shape.forms[n])
		if not seen[key] then
			seen[key], distinct = true, distinct + 1
			canonical = (not canonical or key < canonical) and key or canonical
		end
	end
	return distinct, canonical
end

local function mirrored(piece_shape)
	local cells = {}
	for i, c in ipairs(piece_shape.forms[1]) do
		cells[i] = { -c[1], c[2], c[3] }
	end
	return shape.new(cells)
end

local function valueKey(piece)
	local parts = {}
	for i, name in ipairs(channels.order) do
		parts[i] = piece.value[name]
	end
	return table.concat(parts, ":")
end

local function targetAt(level, v, i)
	local t = {}
	for _, name in ipairs(level.channels[v]) do
		t[name] = level.targets[v].layers[name][i]
	end
	return t
end

local function buildRays(level)
	local size, rays, targets = level.size, {}, {}
	local count = size[1] * size[2] * size[3]
	for i = 1, count do
		rays[i] = {}
	end
	local offset = 0
	for _, v in ipairs(level.views) do
		local axes, target = projection.axes[v], level.targets[v]
		for x = 0, size[1] - 1 do
			for y = 0, size[2] - 1 do
				for z = 0, size[3] - 1 do
					local c = { x, y, z }
					local r = offset + c[axes.u] + c[axes.v] * target.w + 1
					table.insert(rays[grid.index(size, c)], r)
				end
			end
		end
		for i = 1, target.w * target.h do
			targets[offset + i] = targetAt(level, v, i)
		end
		offset = offset + target.w * target.h
	end
	return rays, targets, count
end

local function allowed(target, value, k)
	for name, t in pairs(target) do
		local channel, v = channels[name], value[name]
		if channel.combine(v, v) == v and channel.combine(t, v) ~= t then
			return false
		end
		if channel.monotone then
			local x = channel.identity
			for _ = 1, k do
				x = channel.combine(x, v)
			end
			if x > t then
				return false
			end
		end
	end
	return true
end

local function needy(target)
	for name, t in pairs(target) do
		if t ~= channels[name].identity then
			return true
		end
	end
	return false
end

local function rayLimit(target)
	return target.count
end

local function rayExact(target)
	if target.count then
		return function(n) return n == target.count end
	end
	if target.parity then
		return function(n) return n % 2 == target.parity end
	end
end

local function candidatesFor(level, piece, rays, targets)
	local size, out, seen = level.size, {}, {}
	for n = 1, orient.count do
		local form = piece.shape.forms[n]
		local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
		for _, c in ipairs(form) do
			for a = 1, 3 do
				lo[a], hi[a] = math.min(lo[a], c[a]), math.max(hi[a], c[a])
			end
		end
		for x = -lo[1], size[1] - 1 - hi[1] do
			for y = -lo[2], size[2] - 1 - hi[2] do
				for z = -lo[3], size[3] - 1 - hi[3] do
					local pose = { cell = { x, y, z }, orient = n }
					local indices, hits, ok = {}, {}, true
					for i, c in ipairs(shape.cellsAt(piece.shape, pose)) do
						local idx = grid.index(size, c)
						indices[i] = idx
						for _, r in ipairs(rays[idx]) do
							hits[r] = (hits[r] or 0) + 1
						end
					end
					local ray_list, ray_hits = {}, {}
					for r, k in pairs(hits) do
						ok = ok and allowed(targets[r], piece.value, k)
						ray_list[#ray_list + 1], ray_hits[#ray_list + 1] = r, k
					end
					local key = cellsKey(indices)
					if ok and not seen[key] then
						seen[key] = true
						out[#out + 1] = { pose = pose, cells = indices, rays = ray_list, hits = ray_hits, key = key }
					end
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.key < b.key end)
	return out
end

local function hiddenCubes(level)
	local items = {}
	for id, piece in ipairs(level.pieces) do
		items[id] = { cells = shape.cellsAt(piece.shape, level.solution[id]), value = piece.value }
	end
	local hidden = {}
	for id, item in ipairs(items) do
		for i, c in ipairs(item.cells) do
			local others = {}
			for j, other in ipairs(items) do
				local cells = other.cells
				if j == id then
					cells = { unpack(cells) }
					table.remove(cells, i)
				end
				others[j] = { cells = cells, value = other.value }
			end
			local same = true
			for _, v in ipairs(level.views) do
				local proj = projection.project(level.size, v, level.channels[v], others)
				same = same and projection.compare(level.targets[v], proj).matches
			end
			if same then
				hidden[#hidden + 1] = { piece = level.pieces[id].key, cell = c }
			end
		end
	end
	return hidden
end

local function solidViews(level)
	local out = {}
	for _, v in ipairs(level.views) do
		local target, solid = level.targets[v], true
		for i = 1, target.w * target.h do
			solid = solid and needy(targetAt(level, v, i))
		end
		if solid then
			out[#out + 1] = v
		end
	end
	return out
end

-- Identical pieces (same shape and value, colour aside) form a group. Candidates are sorted by
-- cell set, so members' lists align and members are placed in increasing candidate order:
-- swapping them never counts as a new solution.
local function buildPieces(level, rays, targets)
	local info, groups = {}, {}
	for id, piece in ipairs(level.pieces) do
		local orients, canonical = shapeInfo(piece.shape)
		local mirror = mirrored(piece.shape)
		local _, mirror_canonical = shapeInfo(mirror)
		local group_key = canonical .. "|" .. valueKey(piece)
		local entry = {
			id = id, key = piece.key, piece = piece, orients = orients, canonical = canonical,
			chiral = mirror_canonical ~= canonical, mirror_canonical = mirror_canonical,
			candidates = candidatesFor(level, piece, rays, targets),
		}
		local group = groups[group_key]
		if not group then
			group = { members = {} }
			groups[group_key] = group
		end
		entry.group = group
		group.members[#group.members + 1] = entry
		info[id] = entry
	end
	for _, group in pairs(groups) do
		for i, entry in ipairs(group.members) do
			entry.rank = i
		end
	end
	return info
end

function M.analyse(level, options)
	local limit = options and options.limit or 1000
	local rays, targets, cell_count = buildRays(level)
	local info = buildPieces(level, rays, targets)
	local use_all = level.rules.use_all

	local needy_rays, limits, exact_rays, exact = {}, {}, {}, {}
	for r, t in ipairs(targets) do
		if needy(t) then
			needy_rays[#needy_rays + 1] = r
		end
		limits[r] = rayLimit(t)
		exact[r] = rayExact(t)
		if exact[r] then
			exact_rays[#exact_rays + 1] = r
		end
	end

	local occupied, ray_cover = {}, {}
	for i = 1, cell_count do
		occupied[i] = false
	end
	for r = 1, #targets do
		ray_cover[r] = 0
	end
	local chosen, last_in_group, done = {}, {}, {}
	local report = { solutions = 0, nodes = 0, capped = false, placements = {}, rested = {}, found = {} }
	for id in ipairs(info) do
		report.placements[id] = {}
	end

	local function fits(cand)
		for _, idx in ipairs(cand.cells) do
			if occupied[idx] then
				return false
			end
		end
		return true
	end

	local function eligible(entry)
		return not done[entry.id] and (entry.rank == 1 or done[entry.group.members[entry.rank - 1].id])
	end

	local function options_of(entry)
		local out, from = {}, last_in_group[entry.group] or 0
		for i = from + 1, #entry.candidates do
			if fits(entry.candidates[i]) then
				out[#out + 1] = i
			end
		end
		return out
	end

	local function record()
		local poses = {}
		for id, i in pairs(chosen) do
			if i then
				poses[id] = info[id].candidates[i].pose
			end
		end
		if not rules.evaluate(level, { poses = poses }).solved then
			return
		end
		report.solutions = report.solutions + 1
		if options and options.keep and #report.found < options.keep then
			report.found[#report.found + 1] = poses
		end
		for id, i in pairs(chosen) do
			local cand = i and info[id].candidates[i]
			report.placements[id][cand and cand.key or "-"] = true
			report.rested[id] = report.rested[id] or not cand or cand.pose.orient == orient.identity
		end
		report.capped = report.solutions >= limit
	end

	local function place(entry, i, delta)
		local cand, fits_rays = entry.candidates[i], true
		for _, idx in ipairs(cand.cells) do
			occupied[idx] = delta > 0
		end
		for j, r in ipairs(cand.rays) do
			ray_cover[r] = ray_cover[r] + delta * cand.hits[j]
			fits_rays = fits_rays and not (limits[r] and ray_cover[r] > limits[r])
		end
		return fits_rays
	end

	local function search()
		report.nodes = report.nodes + 1
		local best, best_options, coverable = nil, nil, {}
		for _, entry in ipairs(info) do
			if eligible(entry) then
				local opts = options_of(entry)
				for _, i in ipairs(opts) do
					for _, r in ipairs(entry.candidates[i].rays) do
						coverable[r] = true
					end
				end
				if not best or #opts < #best_options then
					best, best_options = entry, opts
				end
			end
		end
		for _, r in ipairs(needy_rays) do
			if ray_cover[r] == 0 and not coverable[r] then
				return
			end
		end
		for _, r in ipairs(exact_rays) do
			if not coverable[r] and not exact[r](ray_cover[r]) then
				return
			end
		end
		if not best then
			return record()
		end
		if use_all and #best_options == 0 then
			return
		end
		local group, saved = best.group, last_in_group[best.group]
		done[best.id] = true
		for _, i in ipairs(best_options) do
			if report.capped then
				break
			end
			chosen[best.id], last_in_group[group] = i, i
			if place(best, i, 1) then
				search()
			end
			place(best, i, -1)
		end
		if not use_all and not report.capped then
			local skipped = {}
			for k = best.rank, #group.members do
				local id = group.members[k].id
				skipped[#skipped + 1] = id
				done[id], chosen[id] = true, false
			end
			search()
			for _, id in ipairs(skipped) do
				done[id], chosen[id] = nil, nil
			end
		end
		done[best.id], chosen[best.id], last_in_group[group] = nil, nil, saved
	end

	search()

	report.pieces = {}
	for id, entry in ipairs(info) do
		local distinct = 0
		for _ in pairs(report.placements[id]) do
			distinct = distinct + 1
		end
		local mirror_of
		for other_id, other in ipairs(info) do
			if other_id ~= id and entry.chiral and other.canonical == entry.mirror_canonical then
				mirror_of = other.key
			end
		end
		report.pieces[id] = {
			key = entry.key, cubes = entry.piece.shape.size, orients = entry.orients,
			chiral = entry.chiral, mirror_of = mirror_of, candidates = #entry.candidates,
			placements = distinct, must_turn = report.solutions > 0 and not report.rested[id],
		}
	end
	report.hidden = hiddenCubes(level)
	report.solid_views = solidViews(level)
	return report
end

return M
