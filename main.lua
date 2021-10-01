meta.name = 'Jumplunky'
meta.version = '1.5'
meta.description = 'Challenging platforming puzzles'
meta.author = 'JayTheBusinessGoose'

local level_sequence = require("LevelSequence/level_sequence")
local telescopes = require("Telescopes/telescopes")
local button_prompts = require("ButtonPrompts/button_prompts")
local idols = require('idols.lua')
local sound = require('play_sound')
local clear_embeds = require('clear_embeds')
require('difficulty.lua')

local dwelling = require("dwelling")
local volcana = require("volcana")
local temple = require("temple")
local ice_caves = require("ice_caves")
local sunken_city = require("sunken_city")

level_sequence.set_levels({dwelling, volcana, temple, ice_caves, sunken_city})

continuing_run = false
local save_context

initial_bombs = 0
initial_ropes = 0

local current_difficulty = DIFFICULTY.NORMAL

-- overall state
total_idols = 0
idols_collected = {}
hardcore_enabled = false
hardcore_previously_enabled = false

-- Stats for games played in the default difficulty.
normal_stats = {
	best_time = 0,
	best_time_idol_count = 0,
	best_time_death_count = 0,
	least_deaths_completion = nil,
	least_deaths_completion_time = 0,
	max_idol_completions = 0,
	max_idol_best_time = 0,
	deathless_completions = 0,
	best_level = nil,
	completions = 0,
}

-- Stats for games played in the easy difficulty.
easy_stats = {
	best_time = 0,
	best_time_death_count = 0,
	least_deaths_completion = nil,
	least_deaths_completion_time = 0,
	deathless_completions = 0,
	best_level = nil,
	completions = 0,
}

-- Stats for games played in the hard difficulty.
hard_stats = {
	best_time = 0,
	best_time_idol_count = 0,
	best_time_death_count = 0,
	least_deaths_completion = nil,
	least_deaths_completion_time = 0,
	max_idol_completions = 0,
	max_idol_best_time = 0,
	deathless_completions = 0,
	best_level = nil,
	completions = 0,
}

legacy_normal_stats = nil
legacy_easy_stats = nil
legacy_hard_stats = nil

-- Stats for games played at the input difficulty.
function stats_for_difficulty(difficulty)
	if difficulty == DIFFICULTY.HARD then
		return hard_stats
	elseif difficulty == DIFFICULTY.EASY then
		return easy_stats
	end
	return normal_stats
end

-- Stats for games played in the current difficulty.
function current_stats()
	return stats_for_difficulty(current_difficulty)
end

-- Stats for games played at the input difficulty.
function legacy_stats_for_difficulty(difficulty)
	if difficulty == DIFFICULTY.HARD then
		return legacy_hard_stats
	elseif difficulty == DIFFICULTY.EASY then
		return legacy_easy_stats
	end
	return legacy_normal_stats
end

-- Stats for games played in the current difficulty.
function current_legacy_stats()
	return legacy_stats_for_difficulty(current_difficulty)
end

-- Stats for games played in the default difficulty in hardcore mode.
hardcore_stats = {
	best_time = 0,
	best_level = nil,
	completions = 0,
	best_time_idol_count = 0,
	max_idol_completions = 0,
	max_idol_best_time = 0,
}

-- Stats for games played in the easy difficulty in hardcore mode.
hardcore_stats_easy = {
	best_time = 0,
	best_level = nil,
	completions = 0,
}

-- Stats for games played in the hard difficulty in hardcore mode.
hardcore_stats_hard = {
	best_time = 0,
	best_level = nil,
	completions = 0,
	best_time_idol_count = 0,
	max_idol_completions = 0,
	max_idol_best_time = 0,
}

legacy_hardcore_stats = nil
legacy_hardcore_stats_easy = nil
legacy_hardcore_stats_hard = nil

-- Stats for games played at the input difficulty in hardcore mode.
function hardcore_stats_for_difficulty(difficulty)
	if difficulty == DIFFICULTY.HARD then
		return hardcore_stats_hard
	elseif difficulty == DIFFICULTY.EASY then
		return hardcore_stats_easy
	end
	return hardcore_stats
end

-- Stats for games played in the current difficulty in hardcore mode.
function current_hardcore_stats()
	return hardcore_stats_for_difficulty(current_difficulty)
end

-- Stats for games played at the input difficulty in hardcore mode.
function legacy_hardcore_stats_for_difficulty(difficulty)
	if difficulty == DIFFICULTY.HARD then
		return legacy_hardcore_stats_hard
	elseif difficulty == DIFFICULTY.EASY then
		return legacy_hardcore_stats_easy
	end
	return legacy_hardcore_stats
end

-- Stats for games played in the current difficulty in hardcore mode.
function current_legacy_hardcore_stats()
	return legacy_hardcore_stats_for_difficulty(current_difficulty)
end

-- True if the player has seen ana dead in the sunken city level.
has_seen_ana_dead = false

idols = 0
run_idols_collected = {}

-- saved run state for the default difficulty.
local easy_saved_run = {
	has_saved_run = false,
	saved_run_attempts = nil,
	saved_run_time = nil,
	saved_run_level = nil,
	saved_run_idol_count = nil,
	saved_run_idols_collected = {},
}
-- saved run state for the easy difficulty.
local normal_saved_run = {
	has_saved_run = false,
	saved_run_attempts = nil,
	saved_run_time = nil,
	saved_run_level = nil,
	saved_run_idol_count = nil,
	saved_run_idols_collected = {},
}
-- saved run state for the hard difficulty.
local hard_saved_run = {
	has_saved_run = false,
	saved_run_attempts = nil,
	saved_run_time = nil,
	saved_run_level = nil,
	saved_run_idol_count = nil,
	saved_run_idols_collected = {},
}
-- saved run state for the current difficulty.
function current_saved_run()
	if current_difficulty == DIFFICULTY.EASY then
		return easy_saved_run
	elseif current_difficulty == DIFFICULTY.HARD then
		return hard_saved_run
	else
		return normal_saved_run
	end
end

-- Whether the win screen should currently be showing.
local win = false
local show_stats = false
local show_legacy_stats = false
local journal_page = DIFFICULTY.NORMAL

-- Stats for the current completion.
completion_time = 0
completion_time_new_pb = false
completion_deaths = 0
completion_deaths_new_pb = false
completion_idols = 0

-- Whether in a game and not in the menus -- including in the base camp.
local has_seen_base_camp = false

---------------
---- SOUNDS ---
---------------

-- Make spring traps quieter.
set_vanilla_sound_callback(VANILLA_SOUND.TRAPS_SPRING_TRIGGER, VANILLA_SOUND_CALLBACK_TYPE.STARTED, function(playing_sound)
	playing_sound:set_volume(.3)
end)

-- Mute the vocal sound that was playing on the signs when they "say" something.
set_vanilla_sound_callback(VANILLA_SOUND.UI_NPC_VOCAL, VANILLA_SOUND_CALLBACK_TYPE.STARTED, function(playing_sound)
	playing_sound:set_volume(0)
end)

----------------
---- /SOUNDS ---
----------------

--------------
---- CAMP ----
--------------

local continue_door

function update_continue_door_enabledness()
	local saved_run = current_saved_run()
	continue_door.update_door(saved_run.saved_run_level, saved_run.saved_run_attempts, saved_run.saved_run_time)
end

-- Spawn an idol that is not interactible in any way. Only spawns the idol if it has been collected
-- from the level it is being spawned for.
function spawn_camp_idol_for_level(level, x, y, layer)
	if not idols_collected[level.identifier] then return end
	
	local idol_uid = spawn_entity(ENT_TYPE.ITEM_IDOL, x, y, layer, 0, 0)
	local idol = get_entity(idol_uid)
	idol.flags = clr_flag(idol.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
	idol.flags = clr_flag(idol.flags, ENT_FLAG.PICKUPABLE)
end

-- Creates a "room" for the Volcana shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("volcana_shortcut")
set_pre_tile_code_callback(function(x, y, layer)
	level_sequence.spawn_shortcut(x, y, layer, volcana, level_sequence.SIGN_TYPE.RIGHT)
	spawn_camp_idol_for_level(volcana, x + 1, y, layer)
	return true
end, "volcana_shortcut")

-- Creates a "room" for the Temple shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("temple_shortcut")
set_pre_tile_code_callback(function(x, y, layer)
	level_sequence.spawn_shortcut(x, y, layer, temple, level_sequence.SIGN_TYPE.RIGHT)
	spawn_camp_idol_for_level(temple, x + 1, y, layer)
	return true
end, "temple_shortcut")

-- Creates a "room" for the Ice Caves shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("ice_shortcut")
set_pre_tile_code_callback(function(x, y, layer)
	level_sequence.spawn_shortcut(x, y, layer, ice_caves, level_sequence.SIGN_TYPE.LEFT)
	spawn_camp_idol_for_level(ice_caves, x - 1, y, layer)
	return true
end, "ice_shortcut")

-- Creates a "room" for the Sunken City shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("sunken_shortcut")
set_pre_tile_code_callback(function(x, y, layer)
	level_sequence.spawn_shortcut(x, y, layer, sunken_city, level_sequence.SIGN_TYPE.LEFT)
	spawn_camp_idol_for_level(sunken_city, x - 1, y, layer)
	return true
end, "sunken_shortcut")

-- Creates a "room" for the continue entrance, with a door and a sign.
define_tile_code("continue_run")
set_pre_tile_code_callback(function(x, y, layer)
	continue_door = level_sequence.spawn_continue_door(
		x,
		y,
		layer,
		current_saved_run().saved_run_level,
		current_saved_run().saved_run_attempts,
		current_saved_run().saved_run_time,
		level_sequence.SIGN_TYPE.RIGHT)
	return true
end, "continue_run")

-- Spawns an idol if collected from the dwelling level, since there is no Dwelling shortcut.
define_tile_code("dwelling_idol")
set_pre_tile_code_callback(function(x, y, layer)
	spawn_camp_idol_for_level(dwelling, x, y, layer)
	return true
end, "dwelling_idol")

local tunnel_x, tunnel_y, tunnel_layer
local hardcore_sign, easy_sign, normal_sign, hard_sign, stats_sign, legacy_stats_sign
local hardcore_tv, easy_tv, normal_tv, hard_tv, stats_tv, legacy_stats_tv
-- Spawn tunnel, and spawn the difficulty and mode signs relative to her position.
define_tile_code("tunnel_position")
set_pre_tile_code_callback(function(x, y, layer)
	tunnel_x, tunnel_y, tunnel_layer = x, y, layer
	
	hardcore_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 3, y, layer, 0, 0)
	local hardcore_sign_entity = get_entity(hardcore_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	hardcore_sign_entity.flags = clr_flag(hardcore_sign_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	hardcore_tv = button_prompts.spawn_button_prompt(button_prompts.PROMPT_TYPE.INTERACT, x + 3, y, layer)
	
	easy_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 6, y, layer, 0, 0)
	local easy_sign_entity = get_entity(easy_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	easy_sign_entity.flags = clr_flag(easy_sign_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	easy_tv = button_prompts.spawn_button_prompt(button_prompts.PROMPT_TYPE.INTERACT, x + 6, y, layer)
	
	normal_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 7, y, layer, 0, 0)
	local normal_sign_entity = get_entity(normal_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	normal_sign_entity.flags = clr_flag(normal_sign_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	normal_tv = button_prompts.spawn_button_prompt(button_prompts.PROMPT_TYPE.INTERACT, x + 7, y, layer)
	
	hard_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 8, y, layer, 0, 0)
	local hard_sign_entity = get_entity(hard_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	hard_sign_entity.flags = clr_flag(hard_sign_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	hard_tv = button_prompts.spawn_button_prompt(button_prompts.PROMPT_TYPE.INTERACT, x + 8, y, layer)
	
	stats_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 10, y, layer, 0, 0)
	local stats_sign_entity = get_entity(stats_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	stats_sign_entity.flags = clr_flag(stats_sign_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	stats_tv = button_prompts.spawn_button_prompt(button_prompts.PROMPT_TYPE.VIEW, x + 10, y, layer)
	
	if legacy_normal_stats and legacy_easy_stats and legacy_hard_stats and legacy_hardcore_stats and legacy_hardcore_stats_easy and legacy_hardcore_stats_hard then
		legacy_stats_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 11, y, layer, 0, 0)
		local legacy_stats_sign_entity = get_entity(legacy_stats_sign)
		-- This stops the sign from displaying its default toast text when pressing the door button.
		legacy_stats_sign_entity.flags = clr_flag(legacy_stats_sign_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
		legacy_stats_tv = button_prompts.spawn_button_prompt(button_prompts.PROMPT_TYPE.VIEW, x + 11, y, layer)
	end
end, "tunnel_position")

local tunnel
set_callback(function()
	-- Spawn tunnel in the mode room and turn the normal tunnel invisible so the player doesn't see her.
	if state.theme ~= THEME.BASE_CAMP then return end
	local tunnels = get_entities_by_type(ENT_TYPE.MONS_MARLA_TUNNEL)
	if #tunnels > 0 then
		local tunnel_uid = tunnels[1]
		local tunnel = get_entity(tunnel_uid)
		tunnel.flags = set_flag(tunnel.flags, ENT_FLAG.INVISIBLE)
		tunnel.flags = clr_flag(tunnel.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	end
	local tunnel_id = spawn_entity(ENT_TYPE.MONS_MARLA_TUNNEL, tunnel_x, tunnel_y, tunnel_layer, 0, 0)
	tunnel = get_entity(tunnel_id)
	
	tunnel.flags = clr_flag(tunnel.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	tunnel.flags = set_flag(tunnel.flags, ENT_FLAG.FACING_LEFT)
	--end
end, ON.CAMP)

function unique_idols_collected()
	local unique_idol_count = 0
	for i, lvl in ipairs(level_sequence.levels()) do
		if idols_collected[lvl.identifier] then
			unique_idol_count = unique_idol_count + 1
		end
	end
	return unique_idol_count
end

function hardcore_available()
	return unique_idols_collected() == #level_sequence.levels()
end


-- STATS
local stats_closed_time = nil
local last_left_input = nil
local last_right_input = nil
local stats_open_button = nil
local stats_open_button_closed = false

set_journal_enabled(false)
set_callback(function()
	if #players < 1 then return end
	local player = players[1]
	local buttons = read_input(player.uid)
	-- 8 = Journal
	if test_flag(buttons, 8) and not show_stats then
		show_stats = true
		show_legacy_stats = false
		steal_input(player.uid)
		state.level_flags = clr_flag(state.level_flags, 20)
		journal_page = current_difficulty
		sound.play_sound(VANILLA_SOUND.UI_JOURNAL_ON)
		stats_open_button = 8
		stats_open_button_closed = false
	end
end, ON.GAMEFRAME)

set_callback(function()
	if #players < 1 then return end
	local player = players[1]
	
	-- Show the stats journal when pressing the door button by the sign.
	if player:is_button_pressed(BUTTON.DOOR) and 
			stats_sign and get_entity(stats_sign) and
			player.layer == get_entity(stats_sign).layer and 
			distance(player.uid, stats_sign) <= .5 then
			show_stats = true
		show_legacy_stats = false
		-- Do not allow the player to move while showing stats.
		steal_input(player.uid)
		-- Disable pausing.
		state.level_flags = clr_flag(state.level_flags, 20)
		-- Cancel speech bubbles so they don't show above stats.
		cancel_speechbubble()
		-- Hide the prompt so it doesn't show above stats.
		button_prompts.hide_button_prompts(true)
		journal_page = current_difficulty
		stats_open_button = 6
		stats_open_button_closed = false

		sound.play_sound(VANILLA_SOUND.UI_JOURNAL_ON)
	end

	-- Show the legacy stats journal when pressing the door button by the sign.
	if player:is_button_pressed(BUTTON.DOOR) and
			legacy_stats_sign and 
			player.layer == get_entity(legacy_stats_sign).layer and
			distance(player.uid, legacy_stats_sign) <= .5 then
		show_stats = true
		show_legacy_stats = true
		-- Do not allow the player to move while showing stats.
		steal_input(player.uid)
		-- Disable pausing.
		state.level_flags = clr_flag(state.level_flags, 20)
		-- Cancel speech bubbles so they don't show above stats.
		cancel_speechbubble()
		-- Hide the prompt so it doesn't show above stats.
		button_prompts.hide_button_prompts(true)
		journal_page = current_difficulty
		stats_open_button = 6
		stats_open_button_closed = false

		sound.play_sound(VANILLA_SOUND.UI_JOURNAL_ON)
	end
	

	-- Controls while stats journal is opened.
	if show_stats then
		-- Gets a bitwise integer that contains the set of pressed buttons while the input is stolen.
		local buttons = read_stolen_input(player.uid)
		if not stats_open_button_closed and stats_open_button then
			if not test_flag(buttons, stats_open_button) then
				stats_open_button_closed = true
			end
		end
		-- 1 = jump, 2 = whip, 3 = bomb, 4 = rope, 6 = Door, 8 = Journal
		if test_flag(buttons, 1) or
				test_flag(buttons, 2) or 
				test_flag(buttons, 3) or 
				test_flag(buttons, 4) or 
				((stats_open_button ~= 6 or stats_open_button_closed) and test_flag(buttons, 6) or 
				((stats_open_button ~= 8 or stats_open_button_closed) and test_flag(buttons, 8))) then
			show_stats = false
			-- Keep track of the time that the stats were closed. This will allow us to enable the player's
			-- inputs later so that the same input isn't recognized again to cause a bomb to be thrown or another action.
			stats_closed_time = state.time_level
			journal_page = DIFFICULTY.NORMAL
			state.level_flags = set_flag(state.level_flags, 20)
			stats_open_button = nil
			stats_open_button_closed = false
			sound.play_sound(VANILLA_SOUND.UI_JOURNAL_OFF)
			return
		end
		
		function play_journal_pageflip_sound()
			sound.play_sound(VANILLA_SOUND.MENU_PAGE_TURN)
		end
		
		-- Change difficulty when pressing left or right.
		if test_flag(buttons, 9) then -- left_key
			if not last_left_input or state.time_level - last_left_input > 20 then
				last_left_input = state.time_level
				if journal_page > DIFFICULTY.EASY then
					play_journal_pageflip_sound()
					journal_page = math.max(journal_page - 1, DIFFICULTY.EASY)				
				end
			end
		else
			last_left_input = nil
		end
		if test_flag(buttons, 10) then -- right_key
			if not last_right_input or state.time_level - last_right_input > 20 then
				last_right_input = state.time_level
				if journal_page < DIFFICULTY.HARD then
					play_journal_pageflip_sound()
					journal_page = math.min(journal_page + 1, DIFFICULTY.HARD)
				end
			end
		else
			last_right_input = nil
		end
	elseif stats_closed_time ~= nil and state.time_level  - stats_closed_time > 20 then
		-- Re-activate the player's inputs 40 frames after the button was pressed to close the stats.
		-- This gives plenty of time for the player to release the button that was pressed, but also doesn't feel
		-- too long since it mostly occurs while the camera is moving back.
		return_input(player.uid)
		state.level_flags = set_flag(state.level_flags, 20)
		button_prompts.hide_button_prompts(false)
		stats_closed_time = nil
	end
end, ON.GAMEFRAME)

local tunnel_enter_displayed
local tunnel_exit_displayed
local tunnel_enter_hardcore_state
local tunnel_enter_difficulty
local tunnel_exit_hardcore_state
local tunnel_exit_difficulty
local tunnel_exit_ready
set_callback(function()
	if state.theme ~= THEME.BASE_CAMP then return end
	if #players < 1 then return end
	local player = players[1]
	local x, y, layer = get_position(player.uid)
	if layer == LAYER.FRONT then
		-- Reset tunnel dialog states when exiting the back layer so the dialog shows again.
		tunnel_enter_displayed = false
		tunnel_exit_displayed = false
		tunnel_enter_hardcore_state = hardcore_enabled
		tunnel_exit_hardcore_state = hardcore_enabled
		tunnel_enter_difficulty = current_difficulty
		tunnel_exit_difficulty = current_difficulty
		tunnel_exit_ready = false
	elseif tunnel_enter_displayed and x > tunnel_x + 2 then
		-- Do not show Tunnel's exit dialog until the player moves a bit to her right.
		tunnel_exit_ready = true
	end
end, ON.GAMEFRAME)

local player_near_hardcore_sign = false
local player_near_easy_sign = false
local player_near_normal_sign = false
local player_near_hard_sign = false
local player_near_stats_sign = false
local player_near_legacy_stats_sign = false

set_callback(function()
	if state.theme ~= THEME.BASE_CAMP then return end
	if #players < 1 then return end
	local player = players[1]
	
	-- Show a toast when pressing the door button on the signs near shortcut doors and continue door.
	if player:is_button_pressed(BUTTON.DOOR) then
		if player.layer == LAYER.BACK and hardcore_sign and distance(player.uid, hardcore_sign) <= .5 then
			if hardcore_available() then
				hardcore_enabled = not hardcore_enabled
				level_sequence.set_keep_progress(not hardcore_enabled)
				hardcore_previously_enabled = true
				update_continue_door_enabledness()
				save_data()
				if hardcore_enabled then
					toast("Hardcore mode enabled")
				else
					toast("Hardcore mode disabled")
				end
			else
				toast("Collect more idols to unlock hardcore mode")
			end
		elseif player.layer == get_entity(easy_sign).layer and distance(player.uid, easy_sign) <= .5 then
			if current_difficulty ~= DIFFICULTY.EASY then
				current_difficulty = DIFFICULTY.EASY
				update_continue_door_enabledness()
				save_data()
				toast("Easy mode enabled")
			end
		elseif player.layer == get_entity(hard_sign).layer and distance(player.uid, hard_sign) <= .5 then
			if hardcore_available() then
				if current_difficulty ~= DIFFICULTY.HARD then
					current_difficulty = DIFFICULTY.HARD
					update_continue_door_enabledness()
				save_data()
					toast("Hard mode enabled")
				end
			else 
				toast("collect more idols to unlock hard mode")
			end
		elseif player.layer == get_entity(normal_sign).layer and distance(player.uid, normal_sign) <= .5 then
			if current_difficulty ~= DIFFICULTY.NORMAL then
				if current_difficulty == DIFFICULTY.EASY then
					toast("Easy mode disabled")
				elseif current_difficulty == DIFFICULTY.HARD then
					toast("Hard mode disabled")
				end
				current_difficulty = DIFFICULTY.NORMAL
				update_continue_door_enabledness()
				save_data()
			end
		end
	end
	
	-- Speech bubbles for Tunnel and mode signs.
	if tunnel and player.layer == tunnel.layer and distance(player.uid, tunnel.uid) <= 1 then
		if not tunnel_enter_displayed then
			-- Display a different Tunnel text on entering depending on how many idols have been collected and the hardcore state.
			tunnel_enter_displayed = true
			tunnel_enter_hardcore_state = hardcore_enabled
			tunnel_enter_difficulty = current_difficulty
			if unique_idols_collected() == 0 then
				say(tunnel.uid, "Looking to turn down the heat?", 0, true)
			elseif unique_idols_collected() < 2 then
				say(tunnel.uid, "Come back when you're seasoned for a more difficult challenge.", 0, true)
			elseif hardcore_enabled then
				say(tunnel.uid, "Maybe that was too much. Go back over to disable hardcore mode.", 0, true)
			elseif current_difficulty == DIFFICULTY.HARD then
				say(tunnel.uid, "Maybe that was too much. Go back over to disable hard mode.", 0, true)
			elseif hardcore_previously_enabled then
				say(tunnel.uid, "Back to try again? Step on over.", 0, true)
			elseif hardcore_available() then
				say(tunnel.uid, "This looks too easy for you. Step over there to enable hardcore mode.", 0, true)
			else
				say(tunnel.uid, "You're quite the adventurer. Collect the rest of the idols to unlock a more difficult challenge.", 0, true)
			end
		elseif (not tunnel_exit_displayed or tunnel_exit_hardcore_state ~= hardcore_enabled or tunnel_exit_difficulty ~= current_difficulty) and tunnel_exit_ready and (hardcore_available() or (current_difficulty == DIFFICULTY.EASY and tunnel_exit_difficulty ~=DIFFICULTY.EASY)) then
			-- On exiting, display a Tunnel dialog depending on whether hardcore mode has been enabled/disabled or the difficulty changed.
			cancel_speechbubble()
			tunnel_exit_displayed = true
			tunnel_exit_hardcore_state = hardcore_enabled
			tunnel_exit_difficulty = current_difficulty
			set_timeout(function()
				if hardcore_enabled and not tunnel_enter_hardcore_state or current_difficulty > tunnel_enter_difficulty then
					say(tunnel.uid, "Good luck out there!", 0, true)
				elseif not hardcore_enabled and tunnel_enter_hardcore_state or current_difficulty < tunnel_enter_difficulty then
					say(tunnel.uid, "Take it easy.", 0, true)
				elseif hardcore_enabled or current_difficulty == DIFFICULTY.HARD then
					say(tunnel.uid, "Sticking with it. I like your guts!", 0, true)
				else
					say(tunnel.uid, "Maybe another time.", 0, true)
				end
			end, 1)
		end
	end
	if hardcore_sign and player.layer == get_entity(hardcore_sign).layer and distance(player.uid, hardcore_sign) <= .5 then
		-- When passing by the sign, read out what the sign is for.
		if not player_near_hardcore_sign then
			cancel_speechbubble()
			player_near_hardcore_sign = true
			set_timeout(function()
				if hardcore_enabled then
					say(hardcore_sign, "Hardcore mode (enabled)", 0, true)
				else
					say(hardcore_sign, "Hardcore mode", 0, true)
				end
			end, 1)
		end
	else
		player_near_hardcore_sign = false
	end
	if easy_sign and player.layer == get_entity(easy_sign).layer and distance(player.uid, easy_sign) <= .5 then
		-- When passing by the sign, read out what the sign is for.
		if not player_near_easy_sign then
			cancel_speechbubble()
			player_near_easy_sign = true
			set_timeout(function()
				if current_difficulty == DIFFICULTY.EASY then
					say(easy_sign, "Easy mode (enabled)", 0, true)
				else
					say(easy_sign, "Easy mode", 0, true)
				end
			end, 1)
		end
	else
		player_near_easy_sign = false
	end
	if normal_sign and player.layer == get_entity(normal_sign).layer and distance(player.uid, normal_sign) <= .5 then
		-- When passing by the sign, read out what the sign is for.
		if not player_near_normal_sign then
			cancel_speechbubble()
			player_near_normal_sign = true
			set_timeout(function()
				if current_difficulty == DIFFICULTY.NORMAL then
					say(normal_sign, "Normal mode (enabled)", 0, true)
				else
					say(normal_sign, "Normal mode", 0, true)
				end
			end, 1)
		end
	else
		player_near_normal_sign = false
	end
	if hard_sign and player.layer == get_entity(hard_sign).layer and distance(player.uid, hard_sign) <= .5 then
		-- When passing by the sign, read out what the sign is for.
		if not player_near_hard_sign then
			cancel_speechbubble()
			player_near_hard_sign = true
			set_timeout(function()
				if current_difficulty == DIFFICULTY.HARD then
					say(hard_sign, "Hard mode (enabled)", 0, true)
				else
					say(hard_sign, "Hard mode", 0, true)
				end
			end, 1)
		end
	else
		player_near_hard_sign = false
	end
	if stats_sign and player.layer == get_entity(stats_sign).layer and distance(player.uid, stats_sign) <= .5 then
		-- When passing by the sign, read out what the sign is for.
		if not player_near_stats_sign then
			cancel_speechbubble()
			player_near_stats_sign = true
			set_timeout(function()
				say(stats_sign, "Stats", 0, true)
			end, 1)
		end
	else
		player_near_stats_sign = false
	end
	if legacy_stats_sign and player.layer == get_entity(legacy_stats_sign).layer and distance(player.uid, legacy_stats_sign) <= .5 then
		-- When passing by the sign, read out what the sign is for.
		if not player_near_legacy_stats_sign then
			cancel_speechbubble()
			player_near_legacy_stats_sign = true
			set_timeout(function()
				say(legacy_stats_sign, "Legacy Stats", 0, true)
			end, 1)
		end
	else
		player_near_legacy_stats_sign = false
	end
end, ON.GAMEFRAME)

level_sequence.set_on_prepare_initial_level(function(level, continuing_run_)
	local saved_run = current_saved_run()
	if continuing_run_ then
		continuing_run = true
		idols = saved_run.saved_run_idol_count
		run_idols_collected = saved_run.saved_run_idols_collected
	else
		continuing_run = false
		idols = 0
		run_idols_collected = {}
	end
end)

-- Sorry, Ana...
set_post_entity_spawn(function (entity)
	if state.theme == THEME.BASE_CAMP and has_seen_base_camp then
		if has_seen_ana_dead then
			entity.x = 1000
		end
	end
end, SPAWN_TYPE.ANY, MASK.ANY, ENT_TYPE.CHAR_ANA_SPELUNKY)

---------------
---- /CAMP ----
---------------

------------------------
---- LEVEL SEQUENCE ----
------------------------

level_sequence.set_on_level_will_load(function(level)
	level.set_difficulty(current_difficulty)
	if level == sunken_city then
		level.set_idol_collected(idols_collected[level.identifier])
		level.set_run_idol_collected(run_idols_collected[level.identifier])
		level.set_ana_callback(function()
			has_seen_ana_dead = true
		end)
	elseif level == ice_caves then
		level.set_idol_collected(idols_collected[level.identifier])
		level.set_run_idol_collected(run_idols_collected[level.identifier])
	end
end)

level_sequence.set_on_post_level_generation(function(level)
	if #players == 0 then return end
	
	players[1].inventory.bombs = initial_bombs
	players[1].inventory.ropes = initial_ropes
	if players[1]:get_name() == "Roffy D. Sloth" or level == ice_caves then
		players[1].health = 1
	else
		players[1].health = 2
	end
end)

level_sequence.set_on_completed_level(function(completed_level, next_level, initial_level)
	if not next_level then return end
	-- Update stats for the current difficulty mode.
	local stats = current_stats()
	local stats_hardcore = current_hardcore_stats()
	local best_level_index = level_sequence.index_of_level(stats.best_level)
	local hardcore_best_level_index = level_sequence.index_of_level(stats_hardcore.best_level)
	local current_level_index = level_sequence.index_of_level(next_level)
	local initial_level_index = level_sequence.index_of_level(initial_level)
	-- Update the PB if the new level has not been reached yet.
	if (not best_level_index or current_level_index > best_level_index) and
			initial_level_index == 1 then
		stats.best_level = next_level
	end
	if hardcore_enabled and
			(not hardcore_best_level_index or current_level_index > hardcore_best_level_index) and
			initial_level_index == 1 then
		stats_hardcore.best_level = next_level
	end
end)

level_sequence.set_on_win(function(attempts, total_time, initial_level)
	local initial_level_index = level_sequence.index_of_level(initial_level)
	local stats = current_stats()
	local stats_hardcore = current_hardcore_stats()
	if not level_sequence.took_shortcut() then
		win = true
		stats.completions = stats.completions + 1
		completion_time = total_time
		completion_deaths = attempts - 1
		completion_idols = idols

		if hardcore_enabled then
			stats_hardcore.completions = stats_hardcore.completions + 1
		else
			-- Clear the saved run for the current difficulty if hardcore is disabled.
			local saved_run = current_saved_run()
			saved_run.has_saved_run = false
			saved_run.saved_run_attempts = nil
			saved_run.saved_run_idol_count = nil
			saved_run.saved_run_idols_collected = {}
			saved_run.saved_run_level = nil
			saved_run.saved_run_time = nil
		end
				
		if not stats.best_time or stats.best_time == 0 or completion_time < stats.best_time then
			stats.best_time = completion_time
			completion_time_new_pb = true
			if current_difficulty ~= DIFFICULTY.EASY then
				stats.best_time_idol_count = idols
			end
			stats.best_time_death_count = completion_deaths
		else
			completion_time_new_pb = false
		end

		if hardcore_enabled and
				(not stats_hardcore.best_time or
				stats_hardcore.best_time == 0 or
				completion_time < stats_hardcore.best_time) then
			stats_hardcore.best_time = completion_time
			completion_time_new_pb = true
			if current_difficulty ~= DIFFICULTY.EASY then
				stats_hardcore.best_time_idol_count = idols
			end
		end
		
		if idols == #level_sequence.levels() and current_difficulty ~= DIFFICULTY.EASY then
			stats.max_idol_completions = stats.max_idol_completions + 1
			if not stats.max_idol_best_time or stats.max_idol_best_time == 0 or completion_time < stats.max_idol_best_time then
				stats.max_idol_best_time = completion_time
			end
			if hardcore_enabled then
				stats_hardcore.max_idol_completions = stats_hardcore.max_idol_completions + 1
				if not stats_hardcore.max_idol_best_time or stats_hardcore.max_idol_best_time == 0 or completion_time < stats_hardcore.max_idol_best_time then
					stats_hardcore.max_idol_best_time = completion_time
				end
			end
		end
		
		if not stats.least_deaths_completion or completion_deaths < stats.least_deaths_completion or (completion_deaths == stats.least_deaths_completion and completion_time < stats.least_deaths_completion_time) then
			if not stats.least_deaths_completion or completion_deaths < stats.least_deaths_completion then
				completion_deaths_new_pb = true
			end
			stats.least_deaths_completion = completion_deaths
			stats.least_deaths_completion_time = completion_time
			if attempts == 1 then
				stats.deathless_completions = stats.deathless_completions + 1
			end
		else
			completion_deaths_new_pb = false
		end 
	end 
	warp(1, 1, THEME.BASE_CAMP)
end)

set_callback(function ()
    if win and state.theme == THEME.BASE_CAMP then	
		local player_slot = state.player_inputs.player_slot_1
		-- Show the win screen until the player presses the jump button.
		if #players > 0 and test_flag(player_slot.buttons, 1) then
			win = false
			-- Re-enable the menu when the game is resumed.
			state.level_flags = set_flag(state.level_flags, 20)
		elseif #players > 0 and state.time_total > 120 then
			-- Stun the player while the win screen is showing so that they do not accidentally move or take actions.
			players[1]:stun(2)
			-- Disable the pause menu while the win screen is showing.
			state.level_flags = clr_flag(state.level_flags, 20)
		end
    end
end, ON.GAMEFRAME)

set_callback(function ()
	-- Update the PB if the new level has not been reached yet. This is only really for the first time entering Dwelling,
	-- since other times ON.RESET will not have an increased level from the best_level.
	local stats = current_stats()
	local stats_hardcore = current_hardcore_stats()
	local best_level_index = level_sequence.index_of_level(stats.best_level)
	local hardcore_best_level_index = level_sequence.index_of_level(stats_hardcore.best_level)
	local current_level = level_sequence.get_run_state().current_level
	local current_level_index = level_sequence.index_of_level(current_level)
	if (not best_level_index or current_level_index > best_level_index) and
			initial_level_index == 1 then
		stats.best_level = current_level
	end
	if hardcore_enabled and
			(not hardcore_best_level_index or current_level_index > hardcore_best_level_index) and
			initial_level_index == 1 then
		stats_hardcore.best_level = current_level
	end
end, ON.RESET)

level_sequence.set_on_reset_run(function()
	run_idols_collected = {}
	idols = 0
end)

-------------------------
---- /LEVEL SEQUENCE ----
-------------------------

--------------
---- IDOL ----
--------------

set_post_entity_spawn(function(entity)
	-- Set the price to 0 so the player doesn't get gold for returning the idol.
	entity.price = 0
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.ITEM_IDOL, ENT_TYPE.ITEM_MADAMETUSK_IDOL)

function idol_collected_state_for_level(level)
	if run_idols_collected[level.identifier] then
		return IDOL_COLLECTED_STATE.COLLECTED_ON_RUN
	elseif idols_collected[level.identifier] then
		return IDOL_COLLECTED_STATE.COLLECTED
	end
	return IDOL_COLLECTED_STATE.NOT_COLLECTED
end

define_tile_code("idol_reward")
set_pre_tile_code_callback(function(x, y, layer)
	return spawn_idol(
		x,
		y,
		layer,
		idol_collected_state_for_level(level_sequence.get_run_state().current_level),
		current_difficulty == DIFFICULTY.EASY)
end, "idol_reward")

set_vanilla_sound_callback(VANILLA_SOUND.UI_DEPOSIT, VANILLA_SOUND_CALLBACK_TYPE.STARTED, function()
	-- Consider the idol collected when the deposit sound effect plays.
	idols_collected[level_sequence.get_run_state().current_level.identifier] = true
	run_idols_collected[level_sequence.get_run_state().current_level.identifier] = true
	idols = idols + 1
	total_idols = total_idols + 1
end)

---------------
---- /IDOL ----
---------------

----------------------------
---- DO NOT SPAWN GHOST ----
----------------------------

set_ghost_spawn_times(-1, -1)

-----------------------------
---- /DO NOT SPAWN GHOST ----
-----------------------------

--------------------
---- SAVE STATE ----
--------------------

-- Manage saving data and keeping the time in sync during level transitions and resets.

function save_data()
	if save_context then
		force_save(save_context)
	end
end

-- Since we are keeping track of time for the entire run even through deaths and resets, we must track
-- what the time was on resets and level transitions.
set_callback(function ()
    if state.theme == THEME.BASE_CAMP then return end
	if level_sequence.run_in_progress() then 
		if not hardcore_enabled then			
			save_current_run_stats()
		end
		save_data()
	end
end, ON.RESET)

set_callback(function ()
	if state.theme == THEME.BASE_CAMP then return end
	if level_sequence.run_in_progress() and not win then
		save_current_run_stats()
		save_data()
	end
end, ON.TRANSITION)

-- Saves the current state of the run so that it can be continued later if exited.
function save_current_run_stats()
	local run_state = level_sequence.get_run_state()
	-- Save the current run only if there is a run in progress that did not start from a shorcut, and harcore mode is disabled.
	if not level_sequence.took_shortcut() and
			not hardcore_enabled and
			state.theme ~= THEME.BASE_CAMP and
			level_sequence.run_in_progress() then
		local saved_run = current_saved_run()
		saved_run.saved_run_attempts = run_state.attempts
		saved_run.saved_run_idol_count = idols
		saved_run.saved_run_level = run_state.current_level
		saved_run.saved_run_time = run_state.total_time
		saved_run.saved_run_idols_collected = run_idols_collected
		saved_run.has_saved_run = true
	end
end

set_callback(function()
	if level_sequence.run_in_progress() and state.theme ~= THEME.BASE_CAMP then
		-- This doesn't actually save to file every frame, it just updates the properties that will be saved.
		save_current_run_stats()
	end
end, ON.FRAME)

---------------------
---- /SAVE STATE ----
---------------------

--------------------------
---- STATE MANAGEMENT ----
--------------------------

-- Leaving these variables set between resets can lead to undefined behavior due to the high likelyhood of entities being reused.
function clear_variables()
	continue_door = nil

	hard_sign = nil
	easy_sign = nil
	normal_sign = nil
	hardcore_sign = nil
	stats_sign = nil
	legacy_stats_sign = nil
	tunnel_x = nil
	tunnel_y = nil
	tunnel_layer = nil
	tunnel = nil
	show_stats = false
	show_legacy_stats = false
	
	player_near_easy_sign = false
	player_near_hard_sign = false
	player_near_normal_sign = false
	player_near_hardcore_sign = false
end

set_callback(function()
	clear_variables()
end, ON.PRE_LOAD_LEVEL_FILES)

---------------------------
---- /STATE MANAGEMENT ----
---------------------------

----------------------
---- HELPER UTILS ----
----------------------

function round(num, dp)
  local mult = 10^(dp or 0)
  return math.floor(num * mult + 0.5)/mult
end

function format_time(frames)
    local seconds = round(frames / 60, 3)
    local minutes = math.floor(seconds / 60)
	local hours = math.floor(minutes / 60)
    local seconds_text = seconds % 60 < 10 and '0' or ''
    local minutes_text = minutes % 60 < 10 and '0' or ''
	local hours_prefix = hours < 10 and '0' or ''
	local hours_text = hours > 0 and f'{hours_prefix}{hours}:' or ''
    return hours_text .. minutes_text .. tostring(minutes % 60) .. ':' .. seconds_text .. string.format("%.3f", seconds % 60)
end

-----------------------
---- /HELPER UTILS ----
-----------------------

-----------
--- GUI ---
-----------

-- Do not show the GUI unless in the game or in the base camp.
set_callback(function(ctx)
	has_seen_base_camp = true
end, ON.CAMP)
set_callback(function(ctx)
	has_seen_base_camp = false
end, ON.MENU)
set_callback(function(ctx)
	has_seen_base_camp = false
end, ON.TITLE)

local banner_texture_definition = TextureDefinition.new()
banner_texture_definition.texture_path = "banner.png"
banner_texture_definition.width = 540
banner_texture_definition.height = 118
banner_texture_definition.tile_width = 540
banner_texture_definition.tile_height = 118
banner_texture_definition.sub_image_offset_x = 0
banner_texture_definition.sub_image_offset_y = 0
banner_texture_definition.sub_image_width = 540
banner_texture_definition.sub_image_height = 118
local banner_texture = define_texture(banner_texture_definition)

-- Stats page
set_callback(function(ctx)
	if not show_stats then return end
	local color = Color:white()
	local fontsize = 0.0009
	local titlesize = 0.0012
	local w = 1.9
	local h = 1.8
	local bannerw = .5
	local bannerh = .2
	local bannery = .7
	ctx:draw_screen_texture(TEXTURE.DATA_TEXTURES_JOURNAL_BACK_0, 0, 0, -w/2, h/2, w/2, -h/2, color)
	ctx:draw_screen_texture(TEXTURE.DATA_TEXTURES_JOURNAL_PAGEFLIP_0, 0, 0, -w/2, h/2, w/2, -h/2, color)
	ctx:draw_screen_texture(banner_texture, 0, 0, -bannerw/2, bannery + bannerh/2, bannerw/2, bannery - bannerh/2, color)
		
	local stats = show_legacy_stats and legacy_stats_for_difficulty(journal_page) or stats_for_difficulty(journal_page)
	local hardcore_stats = show_legacy_stats and legacy_hardcore_stats_for_difficulty(journal_page) or hardcore_stats_for_difficulty(journal_page)
	
	local stat_texts = {}
	local hardcore_stat_texts = {}
	function add_stat(text)
		stat_texts[#stat_texts+1] = text
	end
	function add_hardcore_stat(text)
		hardcore_stat_texts[#hardcore_stat_texts+1] = text
	end
	if stats.completions > 0 then
		add_stat(f'Completions: {stats.completions}')
		local empty_stats = 0
		if journal_page ~= DIFFICULTY.EASY and stats.max_idol_completions > 0 then
			add_stat(f'All idol completions: {stats.max_idol_completions}')
		else
			empty_stats = empty_stats + 1
		end
		if stats.deathless_completions > 0 then
			add_stat(f'Deathless completions: {stats.deathless_completions}')
		else
			empty_stats = empty_stats + 1
		end
		for i=1,empty_stats do
			add_stat("")
		end
		add_stat("")
		add_stat("")
		add_stat("PBs:")
		local idol_text = ''
		if journal_page ~= DIFFICULTY.EASY and stats.best_time_idol_count == 1 then
			idol_text = '1 idol, '
		elseif journal_page ~= DIFFICULTY.EASY and stats.best_time_idol_count > 0 then
			idol_text = f'{stats.best_time_idol_count} idols, '
		end
		local deaths_text = '1 death'
		if stats.best_time_death_count > 1 then
			deaths_text = f'{stats.best_time_death_count} deaths'
		elseif stats.best_time_death_count == 0 then
			deaths_text = f'deathless'
		end
		add_stat(f'Best time: {format_time(stats.best_time)} ({idol_text}{deaths_text})')
		if journal_page ~= DIFFICULTY.EASY and stats.max_idol_completions > 0 then
			add_stat(f'All idols: {format_time(stats.max_idol_best_time)}')
		end
		if stats.deathless_completions > 0 then
			add_stat(f'Deathless: {format_time(stats.least_deaths_completion_time)}')
		else
			add_stat(f'Least deaths: {stats.least_deaths_completion} ({format_time(stats.least_deaths_completion_time)})')
		end
	elseif stats.best_level then
		add_stat(f'PB: {stats.best_level.title}')
	else
		add_stat("PB: N/A")
	end
	if hardcore_stats.completions > 0 then
		add_hardcore_stat(f'Completions: {hardcore_stats.completions}')
		if journal_page ~= DIFFICULTY.EASY and hardcore_stats.max_idol_completions > 0 then
			add_hardcore_stat(f'All idol completions: {hardcore_stats.max_idol_completions}')
		else
			add_hardcore_stat("")
		end
		add_hardcore_stat("")
		add_hardcore_stat("")
		add_hardcore_stat("")
		add_hardcore_stat("PBs:")
		local idol_text = ''
		if journal_page ~= DIFFICULTY.EASY and hardcore_stats.best_time_idol_count == 1 then
			idol_text = ' (1 idol)'
		elseif journal_page ~= DIFFICULTY.EASY and hardcore_stats.best_time_idol_count > 0 then
			idol_text = f' ({hardcore_stats.best_time_idol_count} idols)'
		end
		add_hardcore_stat(f'Best time: {format_time(hardcore_stats.best_time)}{idol_text}')
		if journal_page ~= DIFFICULTY.EASY and hardcore_stats.max_idol_completions > 0 then
			add_hardcore_stat(f'All idols: {format_time(hardcore_stats.max_idol_best_time)}')
		end
	elseif hardcore_stats.best_level then
		add_hardcore_stat(f'PB: {hardcore_stats.best_level.title}')
	else
		add_hardcore_stat("PB: N/A")
	end
		
	local starttexty = .5
	local statstexty = starttexty
	local hardcoretexty = starttexty
	local statstextx = -.65
	local hardcoretextx = .1
	local _, textheight = ctx:draw_text_size("TestText,", fontsize, fontsize, VANILLA_FONT_STYLE.ITALIC)
	for _, text in ipairs(stat_texts) do
		local t_color = rgba(0, 0, 36, 230)
		ctx:draw_text(text, statstextx, statstexty, fontsize, fontsize, Color:black(), VANILLA_TEXT_ALIGNMENT.LEFT, VANILLA_FONT_STYLE.ITALIC)
		statstexty = statstexty + textheight - .04
	end
	for _, text in ipairs(hardcore_stat_texts) do
		local t_color = rgba(0, 0, 36, 230)
		ctx:draw_text(text, hardcoretextx, hardcoretexty, fontsize, fontsize, Color:black(), VANILLA_TEXT_ALIGNMENT.LEFT, VANILLA_FONT_STYLE.ITALIC)
		hardcoretexty = hardcoretexty + textheight - .04
	end
	
	local stats_title = "STATS"
	if journal_page == DIFFICULTY.EASY then
		stats_title = "EASY"
	elseif journal_page == DIFFICULTY.HARD then
		stats_title = "HARD"
	else
		stats_title = "STATS"
	end
	local stats_title_color = rgba(255,255,255,255)
	ctx:draw_text(stats_title, 0, .71, titlesize, titlesize, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
	ctx:draw_text("Hardcore", -statstextx, .7, titlesize, titlesize, Color:black(), VANILLA_TEXT_ALIGNMENT.RIGHT, VANILLA_FONT_STYLE.ITALIC)
	if show_legacy_stats then
		ctx:draw_text("Legacy", statstextx, .7, titlesize, titlesize, Color:black(), VANILLA_TEXT_ALIGNMENT.LEFT, VANILLA_FONT_STYLE.ITALIC)
	end
	
	local buttonsx = .82
	local buttonssize = .0023
	if journal_page ~= DIFFICULTY.EASY then
		ctx:draw_text("\u{8B}", -buttonsx, 0, buttonssize, buttonssize, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
	end
	if journal_page ~= DIFFICULTY.HARD then
		ctx:draw_text("\u{8C}", buttonsx, 0, buttonssize, buttonssize, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
	end
end, ON.RENDER_POST_HUD)

-- Win state
set_callback(function(ctx)
	if not win then return end
	local color = Color:white()
	local fontsize = 0.0009
	local titlesize = 0.0012
	local w = 1.9
	local h = 1.8
	local bannerw = .5
	local bannerh = .2
	local bannery = .7
	ctx:draw_screen_texture(TEXTURE.DATA_TEXTURES_BASE_SKYNIGHT_0, 0, 0, -3, 3, 3, -3, Color.black())
	ctx:draw_screen_texture(TEXTURE.DATA_TEXTURES_JOURNAL_BACK_0, 0, 0, -w/2, h/2, w/2, -h/2, color)
	ctx:draw_screen_texture(TEXTURE.DATA_TEXTURES_JOURNAL_PAGEFLIP_0, 0, 0, -w/2, h/2, w/2, -h/2, color)
	ctx:draw_screen_texture(banner_texture, 0, 0, -bannerw/2, bannery + bannerh/2, bannerw/2, bannery - bannerh/2, color)
		
	local stats = current_stats()
	local hardcore_stats = current_hardcore_stats()
	
	local stat_texts = {}
	local pb_stat_texts = {}
	function add_stat(text)
		stat_texts[#stat_texts+1] = text
	end
	function add_pb_stat(text)
		pb_stat_texts[#pb_stat_texts+1] = text
	end
	
	add_stat("Congratulations!")
	if current_difficulty == DIFFICULTY.EASY then
		add_stat('Easy completion')
	elseif current_difficulty == DIFFICULTY.HARD then
		add_stat('Hard completion')
	else
		add_stat("")
	end
	add_stat("")
	add_stat("")
	
	local empty_stats = 0
	if completion_deaths_new_pb or completion_time_new_pb then
		add_stat("New PB!!")
	else
		empty_stats = empty_stats + 1
	end
	add_stat(f'Time: {format_time(completion_time)}')
	if not hardcore_enabled then
		if completion_deaths == 0 then
			add_stat('Deathless!')
		else
			add_stat(f'Deaths: {completion_deaths}')
		end
	else
		empty_stats = empty_stats + 1
	end
	local all_idols_text = ""
	if completion_idols == #level_sequence.levels() then
		all_idols_text = " (All Idols!)"
	end
	if current_difficulty ~= DIFFICULTY.EASY and completion_idols > 0 then
		add_stat(f'Idols: {completion_idols}{all_idols_text}')
	else
		empty_stats = empty_stats + 1
	end
	for i=1,empty_stats do
		add_stat("")
	end
	add_stat("")
	add_stat("")
	
	empty_stats = 0
	add_pb_stat(f'Completions: {stats.completions}')
	if hardcore_enabled then
		add_pb_stat(f'Hardcore completions: {stats_hardcore.completions}')
	elseif stats.deathless_completions and stats.deathless_completions > 0 then
		add_pb_stat(f'Deathless completions: {stats.deathless_completions}')
	else
		empty_stats = empty_stats + 1
	end
	if current_difficulty ~= DIFFICULTY.EASY and hardcore_enabled and stats_hardcore.max_idol_completions and stats_hardcore.max_idol_completions > 0 then
		add_pb_stat(f'All idol hardcore completions: {stats_hardcore.max_idol_completions}')
	elseif current_difficulty ~= DIFFICULTY.EASY and not hardcore_enabled and stats.max_idol_completions and stats.max_idol_completions > 0 then
		add_pb_stat(f'All idol completions: {stats.max_idol_completions}')
	else
		empty_stats = empty_stats + 1
	end
	
	for i=1,empty_stats do
		add_pb_stat("")
	end
	
	add_pb_stat("")
	
	add_pb_stat("PBs:")
	local time_pb_text = ''
	if completion_time_new_pb then
		time_pb_text = ' (New PB!)'
	end
	local deaths_pb_text = ''
	if completion_deaths_new_pb then
		deaths_pb_text = ' (New PB!)'
	end
	empty_stats = 0
	if hardcore_enabled then
		add_pb_stat(f'Fastest time: {format_time(stats.best_time)}{time_pb_text}')
		add_pb_stat(f'Fastest hardcore time: {format_time(stats_hardcore.best_time)}{time_pb_text}')
		
		if current_difficulty ~= DIFFICULTY.EASY and stats_hardcore.max_idol_best_time and stats_hardcore.max_idol_best_time > 0 then
			add_pb_stat(f'Fastest hardcore all idols: {format_time(stats_hardcore.max_idol_best_time)}')
		else
			empty_stats = empty_stats + 1
		end
		empty_stats = empty_stats + 1
	else
		add_pb_stat(f'Fastest time: {format_time(stats.best_time)}{time_pb_text}')
		add_pb_stat(f'Least deaths: {stats.least_deaths_completion}{deaths_pb_text}')
		
		if stats.deathless_completions and stats.deathless_completions > 0 and stats.least_deaths_completion_time and stats.least_deaths_completion_time > 0 then
			add_pb_stat(f'Fastest deathless: {format_time(stats.least_deaths_completion_time)}')
		else
			empty_stats = empty_stats + 1
		end
		
		if current_difficulty ~= DIFFICULTY.EASY and stats.max_idol_best_time and stats.max_idol_best_time > 0 then
			add_pb_stat(f'Fastest all idols: {format_time(stats.max_idol_best_time)}')
		else
			empty_stats = empty_stats + 1
		end
	end	
	
	for i=1,empty_stats do
		add_pb_stat("")
	end
	add_pb_stat("")
	add_pb_stat("")
	add_pb_stat("")
	add_pb_stat("Continue \u{83}")
		
	local starttexty = .5
	local statstexty = starttexty
	local hardcoretexty = starttexty
	local statstextx = -.65
	local hardcoretextx = .1
	local _, textheight = ctx:draw_text_size("TestText,", fontsize, fontsize, VANILLA_FONT_STYLE.ITALIC)
	for _, text in ipairs(stat_texts) do
		local t_color = rgba(0, 0, 36, 230)
		ctx:draw_text(text, statstextx, statstexty, fontsize, fontsize, Color:black(), VANILLA_TEXT_ALIGNMENT.LEFT, VANILLA_FONT_STYLE.ITALIC)
		statstexty = statstexty + textheight - .04
	end
	for _, text in ipairs(pb_stat_texts) do
		local t_color = rgba(0, 0, 36, 230)
		ctx:draw_text(text, hardcoretextx, hardcoretexty, fontsize, fontsize, Color:black(), VANILLA_TEXT_ALIGNMENT.LEFT, VANILLA_FONT_STYLE.ITALIC)
		hardcoretexty = hardcoretexty + textheight - .04
	end
	
	local stats_title = "VICTORY"
	local stats_title_color = rgba(255,255,255,255)
	ctx:draw_text(stats_title, 0, .71, titlesize, titlesize, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
	if hardcore_enabled then
		ctx:draw_text("Hardcore", statstextx, .7, titlesize, titlesize, Color:black(), VANILLA_TEXT_ALIGNMENT.RIGHT, VANILLA_FONT_STYLE.ITALIC)
	end
end, ON.RENDER_POST_HUD)

set_callback(function (ctx)
    local text_color = rgba(255, 255, 255, 195)
    local w = 1.3
    local h = 1.3
    local x = 0
    local y = 0
	if not has_seen_base_camp then return end
	
	-- Display stats, or a win screen, for the current difficulty mode and current saved run.
	local saved_run = current_saved_run()
	local stats = current_stats()
	local stats_hardcore = current_hardcore_stats()
	
    if win then
		-- Do not render, showing stats in RENDER_POST_HUD
	elseif state.theme == THEME.BASE_CAMP then
		local texts = {}
		if hardcore_enabled and current_difficulty == DIFFICULTY.EASY then
			texts[#texts+1] = 'Easy mode (Hardcore)'
		elseif hardcore_enabled and current_difficulty == DIFFICULTY.HARD then
			texts[#texts+1] = 'Hard mode (Hardcore)'
		elseif hardcore_enabled then
			texts[#texts+1] = 'Hardcore'
		elseif current_difficulty == DIFFICULTY.EASY then
			texts[#texts+1] = 'Easy mode'
		elseif current_difficulty == DIFFICULTY.HARD then
			texts[#texts+1] = 'Hard mode'
		end
		if continuing_run then
			texts[#texts+1] = "Continue run from " .. saved_run.saved_run_level.title
			local text = " Time: " .. format_time(saved_run.saved_run_time) .. " Deaths: " .. (saved_run.saved_run_attempts)
			if saved_run.saved_run_idol_count > 0 then
				text = text .. " Idols: " .. saved_run.saved_run_idol_count
			end
			texts[#texts+1] = text
		elseif level_sequence.took_shortcut() then
			texts[#texts+1] = "Shortcut to " .. level_sequence.get_run_state().initial_level.title .. " trial"
		elseif hardcore_enabled then
			if stats_hardcore.completions and stats_hardcore.completions > 0 then
				idol_text = ""
				if current_difficulty ~= DIFFICULTY.EASY then
					if stats_hardcore.best_time_idol_count == 1 then
						idol_text = f' (1 idol)'
					elseif stats_hardcore.best_time_idol_count > 1 then
						idol_text = f' ({stats_hardcore.best_time_idol_count} idols)'
					end
				end
				texts[#texts+1] = f'Wins: {stats_hardcore.completions}  PB: {format_time(stats_hardcore.best_time)}{idol_text}'
			elseif stats_hardcore.best_level then
				texts[#texts+1] = f'PB: {stats_hardcore.best_level.title}'
			else
				texts[#texts+1] = "PB: N/A"
			end
		else
			if stats.completions and stats.completions > 0 then
				idol_text = ""
				if current_difficulty ~= DIFFICULTY.EASY then
					if stats.best_time_idol_count == 1 then
						idol_text = f' (1 idol)'
					elseif stats.best_time_idol_count > 1 then
						idol_text = f' ({stats.best_time_idol_count} idols)'
					end
				end
				texts[#texts+1] = f'Wins: {stats.completions}  PB: {format_time(stats.best_time)}{idol_text}'
			elseif stats.best_level then
				texts[#texts+1] = f'PB: {stats.best_level.title}'
			else
				texts[#texts+1] = "PB: N/A"
			end
		end
		
		local texty = -0.935
		for i = #texts,1,-1 do
			local text = texts[i]
			local tw, th = draw_text_size(28, text)
			ctx:draw_text(0 - tw / 2, texty, 28, text, text_color)
			texty = texty - th
		end
		return
	elseif not level_sequence.took_shortcut() and hardcore_enabled then
		local texts = {}
		if current_difficulty == DIFFICULTY.EASY then
			texts[#texts+1] = 'Easy mode (Hardcore)'
		elseif current_difficulty == DIFFICULTY.HARD then
			texts[#texts+1] = 'Hard mode (Hardcore)'
		else
			texts[#texts+1] = 'Hardcore'
		end
		if idols > 0 then
			texts[#texts+1] = f'Idols: {idols}'
		end
		
		
		local texty = -0.935
		for i = #texts,1,-1 do
			local text = texts[i]
			local tw, th = draw_text_size(28, text)
			ctx:draw_text(0 - tw / 2, texty, 28, text, text_color)
			texty = texty - th
		end
    elseif not level_sequence.took_shortcut() then
		local texts = {}
		if current_difficulty == DIFFICULTY.EASY then
			texts[#texts+1] = 'Easy mode'
		elseif current_difficulty == DIFFICULTY.HARD then
			texts[#texts+1] = 'Hard mode'
		end
		
		local idols_text = ""
		if idols > 0 then
			idols_text = f'     Idols: {idols}'
		end
		texts[#texts+1] = f'Deaths: {level_sequence.get_run_state().attempts - 1}{idols_text}'
		
		local texty = -0.935
		for i = #texts,1,-1 do
			local text = texts[i]
			local tw, th = draw_text_size(28, text)
			ctx:draw_text(0 - tw / 2, texty, 28, text, text_color)
			texty = texty - th
		end
	else
		local text = f'{level_sequence.get_run_state().initial_level.title} shortcut practice'
        local tw, _ = draw_text_size(28, text)
		ctx:draw_text(0 - tw / 2, -0.935, 28, text, text_color)
    end
end, ON.GUIFRAME)

------------
--- /GUI ---
------------

-------------------
---- SAVE DATA ----
-------------------

set_callback(function (ctx)
    local load_data_str = ctx:load()

    if load_data_str ~= '' then
        local load_data = json.decode(load_data_str)
		local load_version = load_data.version
		if load_data.difficulty then
			current_difficulty = load_data.difficulty
		end
		if not load_version then 
			normal_stats.best_time = load_data.best_time
			normal_stats.best_time_idol_count = load_data.best_time_idols
			normal_stats.best_time_death_count = load_data.best_time_death_count
			normal_stats.best_level = level_sequence.levels()[load_data.best_level+1]
			normal_stats.completions = load_data.completions or 0
			normal_stats.max_idol_completions = load_data.max_idol_completions or 0
			normal_stats.max_idol_best_time = load_data.max_idol_best_time or 0
			normal_stats.deathless_completions = load_data.deathless_completions or 0
			normal_stats.least_deaths_completion = load_data.least_deaths_completion
			normal_stats.least_deaths_completion_time = load_data.least_deaths_completion_time
		elseif load_version == '1.3' then
			local function legacy_stat_convert(stats)
				local new_stats = {}
				for k,v in pairs(stats) do new_stats[k] = v end
				local best_level = stats.best_level
				if best_level then
					if best_level == 3 then
						best_level = 4
					end
					new_stats.best_level = level_sequence.levels()[best_level + 1]
				end
				return new_stats
			end
			if load_data.stats then
				legacy_normal_stats = legacy_stat_convert(load_data.stats)
			end
			if load_data.easy_stats then
				legacy_easy_stats = legacy_stat_convert(load_data.easy_stats)
			end
			if load_data.hard_stats then
				legacy_hard_stats = legacy_stat_convert(load_data.hard_stats)
			end
			if load_data.hardcore_stats then
				legacy_hardcore_stats = legacy_stat_convert(load_data.hardcore_stats)
			end
			if load_data.hardcore_stats_easy then
				legacy_hardcore_stats_easy = legacy_stat_convert(load_data.hardcore_stats_easy)
			end
			if load_data.hardcore_stats_hard then
				legacy_hardcore_stats_hard = legacy_stat_convert(load_data.hardcore_stats_hard)
			end
		else
			local function stat_convert(stats)
				local new_stats = {}
				for k,v in pairs(stats) do new_stats[k] = v end
				if stats.best_level then
					new_stats.best_level = level_sequence.levels()[stats.best_level + 1]
				end
				return new_stats
			end
			if load_data.stats then
				normal_stats = stat_convert(load_data.stats)
			end
			if load_data.easy_stats then
				easy_stats = stat_convert(load_data.easy_stats)
			end
			if load_data.hard_stats then
				hard_stats = stat_convert(load_data.hard_stats)
			end
			if load_data.legacy_stats then
				legacy_normal_stats = stat_convert(load_data.legacy_stats)
			end
			if load_data.legacy_easy_stats then
				legacy_easy_stats = stat_convert(load_data.legacy_easy_stats)
			end
			if load_data.legacy_hard_stats then
				legacy_hard_stats = stat_convert(load_data.legacy_hard_stats)
			end
			
			
			if load_data.hardcore_stats then
				hardcore_stats = stat_convert(load_data.hardcore_stats)
			end
			if load_data.hardcore_stats_easy then
				hardcore_stats_easy = stat_convert(load_data.hardcore_stats_easy)
			end
			if load_data.hardcore_stats_hard then
				hardcore_stats_hard = stat_convert(load_data.hardcore_stats_hard)
			end
			
			if load_data.legacy_hardcore_stats then
				legacy_hardcore_stats = stat_convert(load_data.legacy_hardcore_stats)
			end
			if load_data.legacy_hardcore_stats_easy then
				legacy_hardcore_stats_easy = stat_convert(load_data.legacy_hardcore_stats_easy)
			end
			if load_data.legacy_hardcore_stats_hard then
				legacy_hardcore_stats_hard = stat_convert(load_data.legacy_hardcore_stats_hard)
			end
		end

		idols_collected = load_data.idol_levels
		total_idols = load_data.total_idols
		hardcore_enabled = load_data.hardcore_enabled
		level_sequence.set_keep_progress(not hardcore_enabled)
		hardcore_previously_enabled = load_data.hpe
		
		function load_saved_run_data(saved_run, saved_run_data)
			saved_run.has_saved_run = saved_run_data.has_saved_run or not load_version
			saved_run.saved_run_level = level_sequence.levels()[saved_run_data.level+1]
			saved_run.saved_run_attempts = saved_run_data.attempts
			saved_run.saved_run_idol_count = saved_run_data.idols
			saved_run.saved_run_time = saved_run_data.run_time
			saved_run.saved_run_idols_collected = saved_run_data.idol_levels
		end
		
		local easy_saved_run_data = load_data.easy_saved_run
		local saved_run_data = load_data.saved_run_data
		local hard_saved_run_data = load_data.hard_saved_run
		if saved_run_data then
			load_saved_run_data(normal_saved_run, saved_run_data)
		end
		if easy_saved_run_data then
			load_saved_run_data(easy_saved_run, easy_saved_run_data)
		end
		if hard_saved_run_data then
			load_saved_run_data(hard_saved_run, hard_saved_run_data)
		end
		has_seen_ana_dead = load_data.has_seen_ana_dead
    end
end, ON.LOAD)

function force_save(ctx)
	function saved_run_datar(saved_run)
		if not saved_run then return nil end
		local saved_run_data = {
			has_saved_run = saved_run.has_saved_run,
			level = level_sequence.index_of_level(saved_run.saved_run_level) - 1,
			attempts = saved_run.saved_run_attempts,
			idols = saved_run.saved_run_idol_count,
			idol_levels = saved_run.saved_run_idols_collected,
			run_time = saved_run.saved_run_time,
		}
		return saved_run_data
	end
	local normal_saved_run_data = saved_run_datar(normal_saved_run)
	local easy_saved_run_data = saved_run_datar(easy_saved_run)
	local hard_saved_run_data = saved_run_datar(hard_saved_run)
	local function convert_stats(stats)
		local new_stats = {}
		for k,v in pairs(stats) do new_stats[k] = v end
		local best_level = level_sequence.index_of_level(stats.best_level)
		if best_level then
			new_stats.best_level = best_level - 1
		else
			new_stats.best_level = nil
		end
		return new_stats
	end
    local save_data = {
		version = '1.5',
		idol_levels = idols_collected,
		total_idols = total_idols,
		saved_run_data = normal_saved_run_data,
		easy_saved_run = easy_saved_run_data,
		hard_saved_run = hard_saved_run_data,
		stats = convert_stats(normal_stats),
		easy_stats = convert_stats(easy_stats),
		hard_stats = convert_stats(hard_stats),
		legacy_stats = convert_stats(legacy_normal_stats),
		legacy_easy_stats = convert_stats(legacy_easy_stats),
		legacy_hard_stats = convert_stats(legacy_hard_stats),
		has_seen_ana_dead = has_seen_ana_dead,
		hardcore_enabled = hardcore_enabled,
		difficulty = current_difficulty,
		hpe = hardcore_previously_enabled,
		hardcore_stats = convert_stats(hardcore_stats),
		hardcore_stats_easy = convert_stats(hardcore_stats_easy),
		hardcore_stats_hard = convert_stats(hardcore_stats_hard),
		legacy_hardcore_stats = convert_stats(legacy_hardcore_stats),
		legacy_hardcore_stats_easy = convert_stats(legacy_hardcore_stats_easy),
		legacy_hardcore_stats_hard = convert_stats(legacy_hardcore_stats_hard),
    }

    ctx:save(json.encode(save_data))
end
	
set_callback(function (ctx)
	save_context = ctx
	force_save(ctx)
end, ON.SAVE)

--------------------
---- /SAVE DATA ----
--------------------
