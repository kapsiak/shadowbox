-- Builds vertex streams for fused polycube pieces. Pure Lua: returns flat arrays
-- keyed by stream name, ready to be written into a Defold buffer.
--
-- Each visible face carries:
--   texcoord0  face-local uv in [0, 1]
--   tangent    the face's u direction (v is normal x tangent)
--   edge       per side (u0, u1, v0, v1): 1 = convex outer edge, 0 = seam within the piece
--   ao         per-corner ambient occlusion from the piece's own cubes, in [0, 1]
local M = {}

local faces = {
	{ n = { 1, 0, 0 }, u = { 0, 1, 0 }, v = { 0, 0, 1 } },
	{ n = { -1, 0, 0 }, u = { 0, 0, 1 }, v = { 0, 1, 0 } },
	{ n = { 0, 1, 0 }, u = { 0, 0, 1 }, v = { 1, 0, 0 } },
	{ n = { 0, -1, 0 }, u = { 1, 0, 0 }, v = { 0, 0, 1 } },
	{ n = { 0, 0, 1 }, u = { 1, 0, 0 }, v = { 0, 1, 0 } },
	{ n = { 0, 0, -1 }, u = { 0, 1, 0 }, v = { 1, 0, 0 } },
}

local corners = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }

local function key(c)
	return c[1] .. "," .. c[2] .. "," .. c[3]
end

local function offset(c, ...)
	local out = { c[1], c[2], c[3] }
	local steps = { ... }
	for i = 1, #steps, 2 do
		local d, k = steps[i], steps[i + 1]
		out[1], out[2], out[3] = out[1] + d[1] * k, out[2] + d[2] * k, out[3] + d[3] * k
	end
	return out
end

local function cornerAo(has, c, f, su, sv)
	local side1 = has(offset(c, f.n, 1, f.u, su))
	local side2 = has(offset(c, f.n, 1, f.v, sv))
	if side1 and side2 then
		return 0
	end
	local corner = has(offset(c, f.n, 1, f.u, su, f.v, sv))
	return (3 - (side1 and 1 or 0) - (side2 and 1 or 0) - (corner and 1 or 0)) / 3
end

local function push(list, ...)
	local n = #list
	for i = 1, select("#", ...) do
		list[n + i] = select(i, ...)
	end
end

-- cells: piece-local cube positions (cube i spans cell +/- 0.5).
function M.piece(cells)
	local present = {}
	for _, c in ipairs(cells) do
		present[key(c)] = true
	end
	local function has(c)
		return present[key(c)] == true
	end

	local out = { position = {}, normal = {}, texcoord0 = {}, tangent = {}, edge = {}, ao = {} }
	for _, c in ipairs(cells) do
		for _, f in ipairs(faces) do
			if not has(offset(c, f.n, 1)) then
				local edge = {
					has(offset(c, f.u, -1)) and 0 or 1,
					has(offset(c, f.u, 1)) and 0 or 1,
					has(offset(c, f.v, -1)) and 0 or 1,
					has(offset(c, f.v, 1)) and 0 or 1,
				}
				local verts = {}
				for i, uv in ipairs(corners) do
					local su, sv = uv[1] * 2 - 1, uv[2] * 2 - 1
					verts[i] = {
						pos = offset(c, f.n, 0.5, f.u, su * 0.5, f.v, sv * 0.5),
						uv = uv,
						ao = cornerAo(has, c, f, su, sv),
					}
				end
				local order = { 1, 2, 3, 1, 3, 4 }
				if verts[1].ao + verts[3].ao < verts[2].ao + verts[4].ao then
					order = { 2, 3, 4, 2, 4, 1 }
				end
				for _, i in ipairs(order) do
					local v = verts[i]
					push(out.position, v.pos[1], v.pos[2], v.pos[3])
					push(out.normal, f.n[1], f.n[2], f.n[3])
					push(out.texcoord0, v.uv[1], v.uv[2])
					push(out.tangent, f.u[1], f.u[2], f.u[3])
					push(out.edge, edge[1], edge[2], edge[3], edge[4])
					push(out.ao, v.ao)
				end
			end
		end
	end
	out.count = #out.ao
	return out
end

-- A flat w x h quad on the plane where axis `normal_axis` equals `depth`, facing along
-- `facing` (1 or -1) on that axis, with uv (0,0) at the low corner along (u_axis, v_axis).
-- `margins` { u0, u1, v0, v1 } extend the quad beyond each side of the grid; uv outside [0, 1]
-- marks that border region.
function M.panel(u_axis, v_axis, normal_axis, w, h, depth, margins, facing)
	local out = { position = {}, normal = {}, texcoord0 = {} }
	local n = { 0, 0, 0 }
	n[normal_axis] = facing
	local function vertex(u, v)
		local p = {}
		p[u_axis], p[v_axis], p[normal_axis] = u, v, depth
		push(out.position, p[1], p[2], p[3])
		push(out.normal, n[1], n[2], n[3])
		push(out.texcoord0, u / w, v / h)
	end
	local u0, u1, v0, v1 = -margins[1], w + margins[2], -margins[3], h + margins[4]
	for _, uv in ipairs({ { u0, v0 }, { u1, v0 }, { u1, v1 }, { u0, v0 }, { u1, v1 }, { u0, v1 } }) do
		vertex(uv[1], uv[2])
	end
	out.count = 6
	return out
end

return M
