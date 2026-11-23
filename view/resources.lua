-- Runtime buffer and texture resources under unique paths. Each is created once and then
-- updated in place: released runtime resources were never freed, so views reuse their own.
local M = {}

local counter = 0

local function uniquePath(kind, ext)
	counter = counter + 1
	return ("/runtime/%s_%d.%s"):format(kind, counter, ext)
end

local stream_widths = { position = 3, normal = 3, texcoord0 = 2, tangent = 3, edge = 4, ao = 1 }
local stream_ids = {}
for name in pairs(stream_widths) do
	stream_ids[name] = hash(name)
end
local RGBA = hash("rgba")

local function meshBuffer(streams)
	local declaration = {}
	for name, width in pairs(stream_widths) do
		if streams[name] then
			declaration[#declaration + 1] = { name = stream_ids[name], type = buffer.VALUE_TYPE_FLOAT32, count = width }
		end
	end
	local buf = buffer.create(streams.count, declaration)
	for name in pairs(stream_widths) do
		local values = streams[name]
		if values then
			local stream = buffer.get_stream(buf, stream_ids[name])
			for i = 1, #values do
				stream[i] = values[i]
			end
		end
	end
	return buf
end

-- Writes a mesh into the buffer resource at `path`, or into a new one when path is nil.
-- streams: { count = n, <stream name> = flat number array, ... }. Returns the path.
function M.buffer(path, streams)
	local buf = meshBuffer(streams)
	if not path then
		return resource.create_buffer(uniquePath("mesh", "bufferc"), { buffer = buf })
	end
	resource.set_buffer(path, buf)
	return path
end

-- Blank texels for a w x h texture: a buffer for M.texture and its byte stream, written
-- in place between uploads (four bytes per texel, RGBA).
function M.texels(w, h)
	local buf = buffer.create(w * h, { { name = RGBA, type = buffer.VALUE_TYPE_UINT8, count = 4 } })
	local stream = buffer.get_stream(buf, RGBA)
	for i = 1, w * h * 4 do
		stream[i] = 0
	end
	return buf, stream
end

-- Writes w x h texels (from M.texels) into the low corner of the texture at `path`, or into a
-- new w x h texture when path is nil. Returns the path.
function M.texture(path, w, h, texels)
	local params = { width = w, height = h, type = graphics.TEXTURE_TYPE_2D, format = graphics.TEXTURE_FORMAT_RGBA }
	if not path then
		return resource.create_texture(uniquePath("cells", "texturec"), params, texels)
	end
	params.x, params.y = 0, 0
	resource.set_texture(path, params, texels)
	return path
end

return M
