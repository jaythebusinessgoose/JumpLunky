local function play_sound(vanilla_sound)
	sound = get_sound(vanilla_sound)
	if sound then
		sound:play()
	end
end

return {play_sound = play_sound}