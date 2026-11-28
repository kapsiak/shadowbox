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
