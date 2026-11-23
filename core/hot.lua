-- Lets hot reload reach modules already required. Hot reload runs an edited module again, but
-- everyone who required it holds the first table; a module that ends with `return hot(..., M)`
-- has its new contents moved into that table instead. Module-level locals start afresh on a
-- reload, so modules keeping state in them (view/resources, view/audio, ui/models,
-- render/frame) do not use this and need a restart.
local tables = {}

return function(name, M)
	local old = name and tables[name]
	if not old then
		if name then
			tables[name] = M
		end
		return M
	end
	for k in pairs(old) do
		old[k] = nil
	end
	for k, v in pairs(M) do
		old[k] = v
	end
	return old
end
