-- Reads and writes the player's saved data: { progress = {...}, settings = {...}, last = {...} }.
local M = {}

local function path()
	return sys.get_save_file(sys.get_config_string("project.title") or "game", "save")
end

function M.load()
	return sys.load(path())
end

function M.save(data)
	if not sys.save(path(), data) then
		print("could not save")
	end
end

return M
