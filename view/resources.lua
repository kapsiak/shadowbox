-- Creates and releases runtime buffer and texture resources under unique paths.
local M = {}

local counter = 0

local function uniquePath(kind, ext)
	counter = counter + 1
	return ("/runtime/%s_%d.%s"):format(kind, counter, ext)
end

local stream_widths = { position = 3, normal = 3, texcoord0 = 2, tangent = 3, edge = 4, ao = 1 }

-- streams: { count = n, <stream name> = flat number array, ... }
function M.createBuffer(streams)
	local declaration = {}
	for name, width in pairs(stream_widths) do
		if streams[name] then
			declaration[#declaration + 1] = { name = hash(name), type = buffer.VALUE_TYPE_FLOAT32, count = width }
		end
	end
	local buf = buffer.create(streams.count, declaration)
	for name in pairs(stream_widths) do
		local values = streams[name]
		if values then
			local stream = buffer.get_stream(buf, hash(name))
			for i = 1, #values do
				stream[i] = values[i]
			end
		end
	end
	return resource.create_buffer(uniquePath("mesh", "bufferc"), { buffer = buf })
end

local function rgbaBuffer(w, h, texels)
	local buf = buffer.create(w * h, { { name = hash("rgba"), type = buffer.VALUE_TYPE_UINT8, count = 4 } })
	local stream = buffer.get_stream(buf, hash("rgba"))
	for i = 1, #texels do
		stream[i] = texels[i]
	end
	return buf
end

-- texels: flat array of w * h * 4 bytes.
function M.createTexture(w, h, texels)
	local params = { width = w, height = h, type = graphics.TEXTURE_TYPE_2D, format = graphics.TEXTURE_FORMAT_RGBA }
	return resource.create_texture(uniquePath("cells", "texturec"), params, rgbaBuffer(w, h, texels))
end

function M.updateTexture(path, w, h, texels)
	local params = { width = w, height = h, x = 0, y = 0, type = graphics.TEXTURE_TYPE_2D, format = graphics.TEXTURE_FORMAT_RGBA }
	resource.set_texture(path, params, rgbaBuffer(w, h, texels))
end

function M.release(path)
	resource.release(path)
end

return M
