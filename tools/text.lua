local CONTENT_KEYS = { name = true, title = true, intro = true, text = true, touch = true }
local INTERFACE = { "ui/sheets.lua", "ui/hud_layout.lua", "ui/select_layout.lua", "input/controls.lua", "game/settings.lua" }

local function lines(path)
	local f = assert(io.open(path))
	local all = {}
	for line in f:lines() do
		all[#all + 1] = line
	end
	f:close()
	return all
end

local function isComment(line)
	return line:match("^%s*%-%-") ~= nil
end

local function showContent(path)
	for n, line in ipairs(lines(path)) do
		local key, value = line:match('^%s*(%a+)%s*=%s*"(.*)",?%s*$')
		if key and CONTENT_KEYS[key] and not isComment(line) then
			print(("%s:%d  %-6s %s"):format(path, n, key, value))
		end
	end
end

local function showInterface()
	for _, path in ipairs(INTERFACE) do
		for n, line in ipairs(lines(path)) do
			if not isComment(line) then
				local found = {}
				for s in line:gmatch('"([A-Z][^"]*)"') do
					found[#found + 1] = s
				end
				if #found > 0 then
					print(("%s:%d  %s"):format(path, n, table.concat(found, " | ")))
				end
			end
		end
	end
end

local function showPack(id)
	local dir = "levels/" .. id .. "/"
	print("== " .. id)
	showContent(dir .. "pack.lua")
	for _, level in ipairs(dofile(dir .. "pack.lua").levels) do
		showContent(dir .. level .. ".lua")
	end
end

local function showRules()
	print("== rules")
	local handle = io.popen("ls levels/rules/*.lua")
	for path in handle:lines() do
		showContent(path)
	end
	handle:close()
end

local packs = dofile("levels/index.lua").packs
local sections = arg
if #arg == 0 then
	sections = { unpack(packs) }
	sections[#sections + 1] = "rules"
	sections[#sections + 1] = "interface"
end
for _, section in ipairs(sections) do
	if section == "rules" then
		showRules()
	elseif section == "interface" then
		print("== interface")
		showInterface()
	else
		showPack(section)
	end
end
