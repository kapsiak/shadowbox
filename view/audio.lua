local M = {}

local AUDIO = "/audio"
local PITCH_JITTER = 0.04

local SFX, MUSIC = hash("sfx"), hash("music")
local NO_OPTIONS = {}

local queue, played = {}, {}
local sound_gain, music_gain
local focused = true

function M.cue(name, options)
	queue[#queue + 1] = { name = name, options = options }
end

function M.setFocused(value)
	focused = value
end

function M.flush(prefs)
	local sfx, music = focused and prefs.sound or 0, focused and prefs.music or 0
	if sound_gain ~= sfx or music_gain ~= music then
		sound_gain, music_gain = sfx, music
		sound.set_group_gain(SFX, sfx)
		sound.set_group_gain(MUSIC, music)
	end
	if #queue == 0 then
		return
	end
	for _, cue in ipairs(queue) do
		if not played[cue.name] then
			played[cue.name] = true
			local options = cue.options or NO_OPTIONS
			local speed = (options.pitch or 1) * (1 + (math.random() * 2 - 1) * PITCH_JITTER)
			sound.play(msg.url(nil, AUDIO, cue.name), { gain = options.gain or 1, speed = speed })
		end
	end
	for i = #queue, 1, -1 do
		queue[i] = nil
	end
	for name in pairs(played) do
		played[name] = nil
	end
end

function M.startMusic()
	sound.play(msg.url(nil, AUDIO, "music"))
end

return M
