-- Prints the game.project settings for a demo build: the demo index as the level index and,
-- as custom_resources, only the files it uses (its levels, their pack manifests and rule cards,
-- the menu showcase). Loaded through main/catalog, as the game loads it.
-- Usage (from the project root): luajit tools/demo_resources.lua [levels/demo.lua]
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
assert(catalog_loader.loadShowcase(read), catalog_loader.SHOWCASE .. ": not found")

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
