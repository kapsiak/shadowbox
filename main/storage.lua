-- corrupt file costs at most the latest save. The folder name is fixed here rather than taken
-- from the game's title, so renaming the game keeps saves.
local hot = require "core.hot"
local M = {}

local APP_ID = "projection_game"
local SLOTS = { "save_a", "save_b" }
-- sys.save's limit is 512 KB; warn well before it.
local WARN_BYTES = 256 * 1024

local seq, slot = 0, 1

local function read(app_id, name)
	local ok, data = pcall(function()
		return sys.load(sys.get_save_file(app_id, name))
	end)
	if ok and type(data) == "table" and next(data) then
		return data
	end
end

function M.load()
	local newest
	for i, name in ipairs(SLOTS) do
		local data = read(APP_ID, name)
		local n = data and tonumber(data.seq) or -1
		if data and (not newest or n > seq) then
			newest, seq, slot = data, n, i % #SLOTS + 1
		end
	end
	return newest
end

function M.save(data)
	data.seq = seq + 1
	if sys.get_engine_info().is_debug then
		local ok, bytes = pcall(sys.serialize, data)
		if ok and #bytes > WARN_BYTES then
			print(("save data is %d bytes, nearing the 512 KB limit"):format(#bytes))
		end
	end
	local ok, err = pcall(function()
		sys.save(sys.get_save_file(APP_ID, SLOTS[slot]), data)
	end)
	if not ok then
		print("could not save: " .. tostring(err))
		return false
	end
	seq, slot = data.seq, slot % #SLOTS + 1
	return true
end

return hot(..., M)
