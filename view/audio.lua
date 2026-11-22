-- Sound cues. Anything may cue a sound by name; cues are only recorded here and are played
-- by the outer loop at its sound phase, with the player's volumes.
local M = {}

local AUDIO = "/audio"
local PITCH_JITTER = 0.04

local queue = {}

-- options: { gain = 0..1, pitch = playback speed }
function M.cue(name, options)
	queue[#queue + 1] = { name = name, options = options }
end

-- Plays queued cues once each per frame; prefs: { sound, music } volumes in [0, 1].
function M.flush(prefs)
	sound.set_group_gain(hash("sfx"), prefs.sound)
	sound.set_group_gain(hash("music"), prefs.music)
	local played = {}
	for _, cue in ipairs(queue) do
		if not played[cue.name] then
			played[cue.name] = true
			local options = cue.options or {}
			local speed = (options.pitch or 1) * (1 + (math.random() * 2 - 1) * PITCH_JITTER)
			sound.play(msg.url(nil, AUDIO, cue.name), { gain = options.gain or 1, speed = speed })
		end
	end
	queue = {}
end

function M.startMusic()
	sound.play(msg.url(nil, AUDIO, "music"))
end

return M
