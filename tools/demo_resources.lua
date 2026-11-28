package.path = "./?.lua;" .. package.path

local catalog_loader = require "main.catalog"

local function read(path)
	local f = io.open("." .. path, "r")
	if not f then
		return nil
	end
	local source = f:read("*a")
	f:close()
	return source
end

local index = "/" .. (arg[1] or "levels/demo.lua")
local catalog = assert(catalog_loader.load(index, read))
assert(catalog_loader.loadRules(catalog, read))
assert(catalog_loader.loadShowcase(read))

local files = { index, catalog_loader.SHOWCASE }
for _, pack in ipairs(catalog.packs) do
	files[#files + 1] = ("/levels/%s/pack.lua"):format(pack.id)
	for _, path in ipairs(pack.paths) do
		files[#files + 1] = path
	end
end
for _, id in ipairs(catalog_loader.ruleIds(catalog)) do
	files[#files + 1] = catalog_loader.rulePath(id)
end

print("[project]")
print("levels = " .. index)
print("custom_resources = " .. table.concat(files, ","))
