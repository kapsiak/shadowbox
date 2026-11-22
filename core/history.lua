-- Undo/redo over a list of immutable states.
local M = {}

function M.new(state)
	return { states = { state }, at = 1 }
end

function M.current(h)
	return h.states[h.at]
end

function M.push(h, state)
	for i = #h.states, h.at + 1, -1 do
		h.states[i] = nil
	end
	h.at = h.at + 1
	h.states[h.at] = state
end

function M.canUndo(h)
	return h.at > 1
end

function M.canRedo(h)
	return h.at < #h.states
end

function M.undo(h)
	h.at = math.max(1, h.at - 1)
end

function M.redo(h)
	h.at = math.min(#h.states, h.at + 1)
end

return M
