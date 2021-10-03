meta.name = 'Jumplunky'
meta.version = '1.5'
meta.description = 'Challenging platforming puzzles'
meta.author = 'JayTheBusinessGoose'

local level_sequence = require("LevelSequence/level_sequence")
local SIGN_TYPE = level_sequence.SIGN_TYPE
local telescopes = require("Telescopes/telescopes")
local button_prompts = require("ButtonPrompts/button_prompts")
local action_signs = require('action_signs')
require('idols')
local sound = require('play_sound')
local journal = require('journal')
local win_ui = require('win')
local bottom_hud = require('bottom_hud')
local clear_embeds = require('clear_embeds')
local save_state = require('save_state')
local DIFFICULTY = require('difficulty')

local dwelling = require("dwelling")
local volcana = require("volcana")
local temple = require("temple")
local ice_caves = require("ice_caves")
local sunken_city = require("sunken_city")

level_sequence.set_levels({dwelling, volcana, temple, ice_caves, sunken_city})
telescopes.set_hud_button_insets(0, 0, .1, 0)

-- Forward declare local function
local update_continue_door_enabledness
local force_save
local save_data

-- Store the save context in a local var so we can save whenever we want.
local save_context

local initial_bombs = 0
local initial_ropes = 0

local create_stats = require('stats')
local function create_saved_run()
	return {
		has_saved_run = false,
		saved_run_attempts = nil,
		saved_run_time = nil,
		saved_run_level = nil,
		saved_run_idol_count = nil,
		saved_run_idols_collected = {},
	}
end

local game_state = {
	difficulty = DIFFICULTY.NORMAL,

	hardcore_enabled = false,
	hardcore_previously_enabled = false,

	total_idols = 0,
	idols_collected = {},

	idols = 0,
	run_idols_collected = {},

	-- True if the player has seen ana dead in the sunken city level.
	has_seen_ana_dead = false,

	stats = create_stats(),
	hardcore_stats = create_stats(),
	legacy_stats = create_stats(true),
	legacy_hardcore_stats = create_stats(true),

	easy_saved_run = create_saved_run(),
	normal_saved_run = create_saved_run(),
	hard_saved_run = create_saved_run(),
}

function game_state.stats.current_stats()
	return game_state.stats.stats_for_difficulty(game_state.difficulty)
end
function game_state.legacy_stats.current_stats()
	return game_state.legacy_stats.stats_for_difficulty(game_state.difficulty)
end
function game_state.hardcore_stats.current_stats()
	return game_state.hardcore_stats.stats_for_difficulty(game_state.difficulty)
end
function game_state.legacy_hardcore_stats.current_stats()
	return game_state.legacy_hardcore_stats.stats_for_difficulty(game_state.difficulty)
end

-- saved run state for the current difficulty.
local function current_saved_run()
	if game_state.difficulty == DIFFICULTY.EASY then
		return game_state.easy_saved_run
	elseif game_state.difficulty == DIFFICULTY.HARD then
		return game_state.hard_saved_run
	else
		return game_state.normal_saved_run
	end
end

local function set_hardcore_enabled(enabled)
	game_state.hardcore_enabled = enabled
	bottom_hud.update_stats(
		game_state.hardcore_enabled and game_state.hardcore_stats.current_stats() or game_state.stats.current_stats(),
		game_state.hardcore_enabled,
		game_state.difficulty)
	level_sequence.set_keep_progress(not game_state.hardcore_enabled)
	update_continue_door_enabledness()
end

local function set_difficulty(difficulty)
	game_state.difficulty = difficulty
	bottom_hud.update_stats(
		game_state.hardcore_enabled and game_state.hardcore_stats.current_stats() or game_state.stats.current_stats(),
		game_state.hardcore_enabled,
		game_state.difficulty)
	bottom_hud.update_saved_run(current_saved_run())
	update_continue_door_enabledness()
end

local function unique_idols_collected()
	local unique_idol_count = 0
	for i, lvl in ipairs(level_sequence.levels()) do
		if game_state.idols_collected[lvl.identifier] then
			unique_idol_count = unique_idol_count + 1
		end
	end
	return unique_idol_count
end

local function hardcore_available()
	return unique_idols_collected() == #level_sequence.levels()
end

--------------------------------------
---- SOUNDS
--------------------------------------

local function spring_volume_callback()
	-- Make spring traps quieter.
	return set_vanilla_sound_callback(VANILLA_SOUND.TRAPS_SPRING_TRIGGER, VANILLA_SOUND_CALLBACK_TYPE.STARTED, function(playing_sound)
		playing_sound:set_volume(.3)
	end)
end

local function sign_mute_callback()
	-- Mute the vocal sound that was playing on the signs when they "say" something.
	return set_vanilla_sound_callback(VANILLA_SOUND.UI_NPC_VOCAL, VANILLA_SOUND_CALLBACK_TYPE.STARTED, function(playing_sound)
		playing_sound:set_volume(0)
	end)
end

--------------------------------------
---- /SOUNDS
--------------------------------------

--------------------------------------
---- CAMP
--------------------------------------

local continue_door

function update_continue_door_enabledness()
	if not continue_door then return end
	local saved_run = current_saved_run()
	continue_door.update_door(saved_run.saved_run_level, saved_run.saved_run_attempts, saved_run.saved_run_time)
end

-- Spawn an idol that is not interactible in any way. Only spawns the idol if it has been collected
-- from the level it is being spawned for.
local function spawn_camp_idol_for_level(level, x, y, layer)
	if not game_state.idols_collected[level.identifier] then return end
	
	local idol_uid = spawn_entity(ENT_TYPE.ITEM_IDOL, x, y, layer, 0, 0)
	local idol = get_entity(idol_uid)
	idol.flags = clr_flag(idol.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
	idol.flags = clr_flag(idol.flags, ENT_FLAG.PICKUPABLE)
end

-- Creates a "room" for the Volcana shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("volcana_shortcut")
local function volcano_shortcut_callback()
	return set_pre_tile_code_callback(function(x, y, layer)
		level_sequence.spawn_shortcut(x, y, layer, volcana, SIGN_TYPE.LEFT)
		spawn_camp_idol_for_level(volcana, x - 1, y, layer)
		return true
	end, "volcana_shortcut")
end

-- Creates a "room" for the Temple shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("temple_shortcut")
local function temple_shortcut_callback()
	return set_pre_tile_code_callback(function(x, y, layer)
		level_sequence.spawn_shortcut(x, y, layer, temple, SIGN_TYPE.LEFT)
		spawn_camp_idol_for_level(temple, x - 1, y, layer)
		return true
	end, "temple_shortcut")
end

-- Creates a "room" for the Ice Caves shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("ice_shortcut")
local function ice_shortcut_callback()
	return set_pre_tile_code_callback(function(x, y, layer)
		level_sequence.spawn_shortcut(x, y, layer, ice_caves, SIGN_TYPE.LEFT)
		spawn_camp_idol_for_level(ice_caves, x - 1, y, layer)
		return true
	end, "ice_shortcut")
end

-- Creates a "room" for the Sunken City shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("sunken_shortcut")
local function sunken_shortcut_callback()
	return set_pre_tile_code_callback(function(x, y, layer)
		level_sequence.spawn_shortcut(x, y, layer, sunken_city, SIGN_TYPE.LEFT)
		spawn_camp_idol_for_level(sunken_city, x - 1, y, layer)
		return true
	end, "sunken_shortcut")
end

-- Creates a "room" for the continue entrance, with a door and a sign.
define_tile_code("continue_run")
local function continue_run_callback()
	return set_pre_tile_code_callback(function(x, y, layer)
		continue_door = level_sequence.spawn_continue_door(
			x,
			y,
			layer,
			current_saved_run().saved_run_level,
			current_saved_run().saved_run_attempts,
			current_saved_run().saved_run_time,
			SIGN_TYPE.RIGHT)
		return true
	end, "continue_run")
end

-- Spawns an idol if collected from the dwelling level, since there is no Dwelling shortcut.
define_tile_code("dwelling_idol")
local function dwelling_idol_callback()
	return set_pre_tile_code_callback(function(x, y, layer)
		spawn_camp_idol_for_level(dwelling, x, y, layer)
		return true
	end, "dwelling_idol")
end

local tunnel_x, tunnel_y, tunnel_layer
-- Spawn tunnel, and spawn the difficulty and mode signs relative to her position.
define_tile_code("tunnel_position")
local function tunnel_position_callback()
	return set_pre_tile_code_callback(function(x, y, layer)
		tunnel_x, tunnel_y, tunnel_layer = x, y, layer

		-- Hardcore mode sign
		action_signs.spawn_sign(x + 3, y, layer, button_prompts.PROMPT_TYPE.INTERACT, function()
			if hardcore_available() then
				set_hardcore_enabled(not game_state.hardcore_enabled)
				game_state.hardcore_previously_enabled = true
				save_data()
				if game_state.hardcore_enabled then
					toast("Hardcore mode enabled")
				else
					toast("Hardcore mode disabled")
				end
			else
				toast("Collect more idols to unlock hardcore mode")
			end
		end, function(sign)
			cancel_speechbubble()
			set_timeout(function()
				if game_state.hardcore_enabled then
					say(sign.uid, "Hardcore mode (enabled)", 0, true)
				else
					say(sign.uid, "Hardcore mode", 0, true)
				end
			end, 1)
		end)

		-- Easy difficulty sign.
		action_signs.spawn_sign(x + 6, y, layer, button_prompts.PROMPT_TYPE.INTERACT, function()
			if game_state.difficulty ~= DIFFICULTY.EASY then
				set_difficulty(DIFFICULTY.EASY)
				save_data()
				toast("Easy mode enabled")
			end
		end, function(sign)
			cancel_speechbubble()
			set_timeout(function()
				if game_state.difficulty == DIFFICULTY.EASY then
					say(sign.uid, "Easy mode (enabled)", 0, true)
				else
					say(sign.uid, "Easy mode", 0, true)
				end
			end, 1)
		end)

		-- Normal difficulty sign.
		action_signs.spawn_sign(x + 7, y, layer, button_prompts.PROMPT_TYPE.INTERACT, function()
			if game_state.difficulty ~= DIFFICULTY.NORMAL then
				if game_state.difficulty == DIFFICULTY.EASY then
					toast("Easy mode disabled")
				elseif game_state.difficulty == DIFFICULTY.HARD then
					toast("Hard mode disabled")
				end
				set_difficulty(DIFFICULTY.NORMAL)
				save_data()
			end
		end, function(sign)
			cancel_speechbubble()
			set_timeout(function()
				if game_state.difficulty == DIFFICULTY.NORMAL then
					say(sign.uid, "Normal mode (enabled)", 0, true)
				else
					say(sign.uid, "Normal mode", 0, true)
				end
			end, 1)
		end)

		-- Hard difficulty sign.
		action_signs.spawn_sign(x + 8, y, layer, button_prompts.PROMPT_TYPE.INTERACT, function()
			if game_state.difficulty ~= DIFFICULTY.HARD then
				set_difficulty(DIFFICULTY.HARD)
				save_data()
				toast("Hard mode enabled")
			end
		end, function(sign)
			cancel_speechbubble()
			set_timeout(function()
				if game_state.difficulty == DIFFICULTY.HARD then
					say(sign.uid, "Hard mode (enabled)", 0, true)
				else
					say(sign.uid, "Hard mode", 0, true)
				end
			end, 1)
		end)

		-- Stats sign opens journal.
		action_signs.spawn_sign(x + 10, y, layer, button_prompts.PROMPT_TYPE.VIEW, function()
			journal.show(game_state.stats, game_state.hardcore_stats, game_state.difficulty, 6)

			-- Cancel speech bubbles so they don't show above stats.
			cancel_speechbubble()
			-- Hide the prompt so it doesn't show above stats.
			button_prompts.hide_button_prompts(true)
		end, function(sign)
			cancel_speechbubble()
			set_timeout(function()
				say(sign.uid, "Stats", 0, true)
			end, 1)
		end)

		if game_state.legacy_stats.normal and
				game_state.legacy_stats.easy and
				game_state.legacy_stats.hard and
				game_state.legacy_hardcore_stats.normal and
				game_state.legacy_hardcore_stats.easy and
				game_state.legacy_hardcore_stats.hard then
			-- Legacy stats sign opens journal; only spawns if legacy stats exist.
			action_signs.spawn_sign(x + 11, y, layer, button_prompts.PROMPT_TYPE.VIEW, function()
				journal.show(game_state.legacy_stats, game_state.legacy_hardcore_stats, game_state.difficulty, 6)
		
				-- Cancel speech bubbles so they don't show above stats.
				cancel_speechbubble()
				-- Hide the prompt so it doesn't show above stats.
				button_prompts.hide_button_prompts(true)
			end, function(sign)
				cancel_speechbubble()
				set_timeout(function()
					say(sign.uid, "Legacy Stats", 0, true)
				end, 1)
			end)
		end
	end, "tunnel_position")
end

local tunnel
local function tunnel_spawn_callback()
	return set_callback(function()
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
end

-- STATS

local function journal_button_callback()
	return set_callback(function()
		if #players < 1 then return end
		local player = players[1]
		local buttons = read_input(player.uid)
		-- 8 = Journal
		if test_flag(buttons, 8) and not journal.showing_stats() then
			journal.show(game_state.stats, game_state.hardcore_stats, game_state.difficulty, 8)

			-- Cancel speech bubbles so they don't show above stats.
			cancel_speechbubble()
			-- Hide the prompt so it doesn't show above stats.
			button_prompts.hide_button_prompts(true)
		end
	end, ON.GAMEFRAME)
end

journal.set_on_journal_closed(function()
	button_prompts.hide_button_prompts(false)
end)


local tunnel_enter_displayed
local tunnel_exit_displayed
local tunnel_enter_hardcore_state
local tunnel_enter_difficulty
local tunnel_exit_hardcore_state
local tunnel_exit_difficulty
local tunnel_exit_ready
local function tunnel_text_callback()
	return set_callback(function()
		if state.theme ~= THEME.BASE_CAMP then return end
		if #players < 1 then return end
		local player = players[1]
		
		local x, y, layer = get_position(player.uid)
		if layer == LAYER.FRONT then
			-- Reset tunnel dialog states when exiting the back layer so the dialog shows again.
			tunnel_enter_displayed = false
			tunnel_exit_displayed = false
			tunnel_enter_hardcore_state = game_state.hardcore_enabled
			tunnel_exit_hardcore_state = game_state.hardcore_enabled
			tunnel_enter_difficulty = game_state.difficulty
			tunnel_exit_difficulty = game_state.difficulty
			tunnel_exit_ready = false
		elseif tunnel_enter_displayed and x > tunnel_x + 2 then
			-- Do not show Tunnel's exit dialog until the player moves a bit to her right.
			tunnel_exit_ready = true
		end

		-- Speech bubbles for Tunnel and mode signs.
		if tunnel and player.layer == tunnel.layer and distance(player.uid, tunnel.uid) <= 1 then
			if not tunnel_enter_displayed then
				-- Display a different Tunnel text on entering depending on how many idols have been collected and the hardcore state.
				tunnel_enter_displayed = true
				tunnel_enter_hardcore_state = game_state.hardcore_enabled
				tunnel_enter_difficulty = game_state.difficulty
				if unique_idols_collected() == 0 then
					say(tunnel.uid, "Looking to turn down the heat?", 0, true)
				elseif unique_idols_collected() < 2 then
					say(tunnel.uid, "Come back when you're seasoned for a more difficult challenge.", 0, true)
				elseif game_state.hardcore_enabled then
					say(tunnel.uid, "Maybe that was too much. Go back over to disable hardcore mode.", 0, true)
				elseif game_state.difficulty == DIFFICULTY.HARD then
					say(tunnel.uid, "Maybe that was too much. Go back over to disable hard mode.", 0, true)
				elseif game_state.hardcore_previously_enabled then
					say(tunnel.uid, "Back to try again? Step on over.", 0, true)
				elseif hardcore_available() then
					say(tunnel.uid, "This looks too easy for you. Step over there to enable hardcore mode.", 0, true)
				else
					say(tunnel.uid, "You're quite the adventurer. Collect the rest of the idols to unlock a more difficult challenge.", 0, true)
				end
			elseif (not tunnel_exit_displayed or
						tunnel_exit_hardcore_state ~= game_state.hardcore_enabled or
						tunnel_exit_difficulty ~= game_state.difficulty) and
					tunnel_exit_ready and
					(hardcore_available() or
						(game_state.difficulty == DIFFICULTY.EASY and tunnel_exit_difficulty ~=DIFFICULTY.EASY)) then
				-- On exiting, display a Tunnel dialog depending on whether hardcore mode has been enabled/disabled or the difficulty changed.
				cancel_speechbubble()
				tunnel_exit_displayed = true
				tunnel_exit_hardcore_state = game_state.hardcore_enabled
				tunnel_exit_difficulty = game_state.difficulty
				set_timeout(function()
					if game_state.hardcore_enabled and not tunnel_enter_hardcore_state or game_state.difficulty > tunnel_enter_difficulty then
						say(tunnel.uid, "Good luck out there!", 0, true)
					elseif not game_state.hardcore_enabled and tunnel_enter_hardcore_state or game_state.difficulty < tunnel_enter_difficulty then
						say(tunnel.uid, "Take it easy.", 0, true)
					elseif game_state.hardcore_enabled or game_state.difficulty == DIFFICULTY.HARD then
						say(tunnel.uid, "Sticking with it. I like your guts!", 0, true)
					else
						say(tunnel.uid, "Maybe another time.", 0, true)
					end
				end, 1)
			end
		end
	end, ON.GAMEFRAME)
end

-- Sorry, Ana...
local function remove_ana_callback()
	return set_post_entity_spawn(function (entity)
		if game_state.has_seen_ana_dead then
			if state.screen == 11 then
				entity.x = 1000
			else
				entity:set_texture(TEXTURE.DATA_TEXTURES_CHAR_CYAN_0)
			end
		end
	end, SPAWN_TYPE.ANY, MASK.ANY, ENT_TYPE.CHAR_ANA_SPELUNKY)
end

--------------------------------------
---- /CAMP
--------------------------------------

--------------------------------------
---- LEVEL SEQUENCE
--------------------------------------

level_sequence.set_on_level_will_load(function(level)
	level.set_difficulty(game_state.difficulty)
	if level == sunken_city then
		level.set_idol_collected(game_state.idols_collected[level.identifier])
		level.set_run_idol_collected(game_state.run_idols_collected[level.identifier])
		level.set_ana_callback(function()
			has_seen_ana_dead = true
		end)
	elseif level == ice_caves then
		level.set_idol_collected(game_state.idols_collected[level.identifier])
		level.set_run_idol_collected(game_state.run_idols_collected[level.identifier])
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

level_sequence.set_on_completed_level(function(completed_level, next_level)
	if not next_level then return end
	-- Update stats for the current difficulty mode.
	local current_stats = game_state.stats.current_stats()
	local stats_hardcore = game_state.hardcore_stats.current_stats()
	local best_level_index = level_sequence.index_of_level(current_stats.best_level)
	local hardcore_best_level_index = level_sequence.index_of_level(stats_hardcore.best_level)
	local current_level_index = level_sequence.index_of_level(next_level)
	-- Update the PB if the new level has not been reached yet.
	if (not best_level_index or current_level_index > best_level_index) and
			not level_sequence.took_shortcut() then
				current_stats.best_level = next_level
	end
	if game_state.hardcore_enabled and
			(not hardcore_best_level_index or current_level_index > hardcore_best_level_index) and
			not level_sequence.took_shortcut() then
		stats_hardcore.best_level = next_level
	end
end)

level_sequence.set_on_win(function(attempts, total_time)
	local current_stats = game_state.stats.current_stats()
	local stats_hardcore = game_state.hardcore_stats.current_stats()
	if not level_sequence.took_shortcut() then
		local deaths = attempts - 1

		current_stats.completions = current_stats.completions + 1
		if game_state.hardcore_enabled then
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
			
		local new_time_pb = false
		if not current_stats.best_time or
				current_stats.best_time == 0 or
				total_time < current_stats.best_time then
			current_stats.best_time = total_time
			new_time_pb = true
			if game_state.difficulty ~= DIFFICULTY.EASY then
				current_stats.best_time_idol_count = game_state.idols
			end
			current_stats.best_time_death_count = deaths
		end

		if game_state.hardcore_enabled and
				(not stats_hardcore.best_time or
				stats_hardcore.best_time == 0 or
				total_time < stats_hardcore.best_time) then
			stats_hardcore.best_time = total_time
			new_time_pb = true
			if game_state.difficulty ~= DIFFICULTY.EASY then
				stats_hardcore.best_time_idol_count = game_state.idols
			end
		end
		
		if game_state.idols == #level_sequence.levels() and game_state.difficulty ~= DIFFICULTY.EASY then
			current_stats.max_idol_completions = current_stats.max_idol_completions + 1
			if not current_stats.max_idol_best_time or
					current_stats.max_idol_best_time == 0 or
					total_time < current_stats.max_idol_best_time then
				current_stats.max_idol_best_time = total_time
			end
			if game_state.hardcore_enabled then
				stats_hardcore.max_idol_completions = stats_hardcore.max_idol_completions + 1
				if not stats_hardcore.max_idol_best_time or
						stats_hardcore.max_idol_best_time == 0 or
						total_time < stats_hardcore.max_idol_best_time then
					stats_hardcore.max_idol_best_time = total_time
				end
			end
		end
		
		local new_deaths_pb = false
		if not current_stats.least_deaths_completion or
				deaths < current_stats.least_deaths_completion or
				(deaths == current_stats.least_deaths_completion and
				 total_time < current_stats.least_deaths_completion_time) then
			if not current_stats.least_deaths_completion or
					deaths < current_stats.least_deaths_completion then
				new_deaths_pb = true
			end
			current_stats.least_deaths_completion = deaths
			current_stats.least_deaths_completion_time = total_time
			if attempts == 1 then
				current_stats.deathless_completions = current_stats.deathless_completions + 1
			end
		end 

		win_ui.win(
			total_time,
			deaths,
			game_state.idols,
			game_state.difficulty,
			game_state.stats,
			game_state.hardcore_stats,
			game_state.hardcore_enabled,
			#level_sequence.levels(),
			new_time_pb,
			new_deaths_pb)
		bottom_hud.update_win_state(true)
		win_ui.set_on_dismiss(function()
			bottom_hud.update_win_state(false)
		end)
	end 
	warp(1, 1, THEME.BASE_CAMP)
end)

local function pb_update_callback()
	return set_callback(function ()
		-- Update the PB if the new level has not been reached yet. This is only really for the first time entering Dwelling,
		-- since other times ON.RESET will not have an increased level from the best_level.
		local current_stats = game_state.stats.current_stats()
		local stats_hardcore = game_state.hardcore_stats.current_stats()
		local best_level_index = level_sequence.index_of_level(current_stats.best_level)
		local hardcore_best_level_index = level_sequence.index_of_level(stats_hardcore.best_level)
		local current_level = level_sequence.get_run_state().current_level
		local current_level_index = level_sequence.index_of_level(current_level)
		if (not best_level_index or current_level_index > best_level_index) and
				not level_sequence.took_shortcut() then
			current_stats.best_level = current_level
		end
		if game_state.hardcore_enabled and
				(not hardcore_best_level_index or current_level_index > hardcore_best_level_index) and
				not level_sequence.took_shortcut() then
			stats_hardcore.best_level = current_level
		end
	end, ON.RESET)
end

local function update_hud_run_entry(continuing)
	local run_state = level_sequence.get_run_state()
	local took_shortcut = level_sequence.took_shortcut()
	bottom_hud.update_run_entry(run_state.initial_level, took_shortcut, continuing)
end

local function update_hud_run_state()
	local run_state = level_sequence.get_run_state()
	bottom_hud.update_run(game_state.idols, run_state.attempts, run_state.total_time)
end

level_sequence.set_on_reset_run(function()
	game_state.run_idols_collected = {}
	game_state.idols = 0
	update_hud_run_state()
end)

level_sequence.set_on_prepare_initial_level(function(level, continuing)
	local saved_run = current_saved_run()
	if continuing then
		game_state.idols = saved_run.saved_run_idol_count
		game_state.run_idols_collected = saved_run.saved_run_idols_collected
	else
		game_state.idols = 0
		game_state.run_idols_collected = {}
	end
	update_hud_run_state()
	update_hud_run_entry(continuing)
end)

level_sequence.set_on_level_start(function(level)
	update_hud_run_state()
end)

--------------------------------------
---- /LEVEL SEQUENCE
--------------------------------------

--------------------------------------
---- IDOL
--------------------------------------

local function idol_price_callback()
	return set_post_entity_spawn(function(entity)
		-- Set the price to 0 so the player doesn't get gold for returning the idol.
		entity.price = 0
	end, SPAWN_TYPE.ANY, 0, ENT_TYPE.ITEM_IDOL, ENT_TYPE.ITEM_MADAMETUSK_IDOL)
end

local function idol_collected_state_for_level(level)
	if game_state.run_idols_collected[level.identifier] then
		return IDOL_COLLECTED_STATE.COLLECTED_ON_RUN
	elseif game_state.idols_collected[level.identifier] then
		return IDOL_COLLECTED_STATE.COLLECTED
	end
	return IDOL_COLLECTED_STATE.NOT_COLLECTED
end

define_tile_code("idol_reward")
local function idol_tile_code_callback()
	return set_pre_tile_code_callback(function(x, y, layer)
		return spawn_idol(
			x,
			y,
			layer,
			idol_collected_state_for_level(level_sequence.get_run_state().current_level),
			game_state.difficulty == DIFFICULTY.EASY)
	end, "idol_reward")
end

local function idol_sound_callback()
	return set_vanilla_sound_callback(VANILLA_SOUND.UI_DEPOSIT, VANILLA_SOUND_CALLBACK_TYPE.STARTED, function()
		-- Consider the idol collected when the deposit sound effect plays.
		game_state.idols_collected[level_sequence.get_run_state().current_level.identifier] = true
		game_state.run_idols_collected[level_sequence.get_run_state().current_level.identifier] = true
		game_state.idols = game_state.idols + 1
		game_state.total_idols = game_state.total_idols + 1
		update_hud_run_state()
	end)
end

--------------------------------------
---- /IDOL
--------------------------------------

--------------------------------------
---- DO NOT SPAWN GHOST 
--------------------------------------

set_ghost_spawn_times(-1, -1)

--------------------------------------
---- /DO NOT SPAWN GHOST 
--------------------------------------

--------------------------------------
---- SAVE STATE
--------------------------------------

-- Manage saving data and keeping the time in sync during level transitions and resets.
local function save_data()
	if save_context then
		force_save(save_context)
	end
end

-- Saves the current state of the run so that it can be continued later if exited.
local function save_current_run_stats_callback()
	return set_callback(function()
		local run_state = level_sequence.get_run_state()
		-- Save the current run only if there is a run in progress that did not start from a shorcut, and harcore mode is disabled.
		if not level_sequence.took_shortcut() and
				not game_state.hardcore_enabled and
				state.theme ~= THEME.BASE_CAMP and
				level_sequence.run_in_progress() then
			local saved_run = current_saved_run()
			saved_run.saved_run_attempts = run_state.attempts
			saved_run.saved_run_idol_count = game_state.idols
			saved_run.saved_run_level = run_state.current_level
			saved_run.saved_run_time = run_state.total_time
			saved_run.saved_run_idols_collected = game_state.run_idols_collected
			saved_run.has_saved_run = true
		end
	end, ON.FRAME)
end

-- Since we are keeping track of time for the entire run even through deaths and resets, we must track
-- what the time was on resets and level transitions.
local function reset_save_callback()
	return set_callback(function ()
		if state.theme == THEME.BASE_CAMP then return end
		if level_sequence.run_in_progress() then
			if not game_state.hardcore_enabled then
				save_current_run_stats()
			end
			save_data()
		end
	end, ON.RESET)
end

local function transition_save_callback()
	return set_callback(function ()
		if state.theme == THEME.BASE_CAMP then return end
		if level_sequence.run_in_progress() and not win_ui.won() then
			save_current_run_stats()
			save_data()
		end
	end, ON.TRANSITION)
end

--------------------------------------
---- /SAVE STATE
--------------------------------------

--------------------------------------
---- STATE MANAGEMENT
--------------------------------------

-- Leaving these variables set between resets can lead to undefined behavior due to the high likelyhood of entities being reused.
local function clear_variables_callback()
	return set_callback(function()
		continue_door = nil

		tunnel_x = nil
		tunnel_y = nil
		tunnel_layer = nil
		tunnel = nil
	end, ON.PRE_LOAD_LEVEL_FILES)
end

--------------------------------------
---- /STATE MANAGEMENT
--------------------------------------

--------------------------------------
---- SAVE DATA
--------------------------------------

set_callback(function(ctx)
	game_state = save_state.load(game_state, level_sequence, ctx)
	set_difficulty(game_state.difficulty)
	set_hardcore_enabled(game_state.hardcore_enabled)
end, ON.LOAD)

local function force_save(ctx)
	save_state.save(game_state, level_sequence, ctx)
end

local function on_save_callback()
	return set_callback(function(ctx)
		save_context = ctx
		force_save(ctx)
	end, ON.SAVE)
end

--------------------------------------
---- /SAVE DATA
--------------------------------------

local active = false
local callbacks = {}
local vanilla_sound_callbacks = {}

local function activate()
	if active then return end
	active = true
	level_sequence.activate()
	telescopes.activate()
	button_prompts.activate()
	action_signs.activate()
	journal.activate()
	win_ui.activate()
	bottom_hud.activate()

	local function add_callback(callback_id)
		callbacks[#callbacks+1] = callback_id
	end
	local function add_vanilla_sound_callback(callback_id)
		vanilla_sound_callbacks[#vanilla_sound_callbacks+1] = callback_id
	end

	set_journal_enabled(false)

	add_callback(volcano_shortcut_callback())
	add_callback(temple_shortcut_callback())
	add_callback(ice_shortcut_callback())
	add_callback(sunken_shortcut_callback())
	add_callback(continue_run_callback())
	add_callback(dwelling_idol_callback())
	add_callback(tunnel_position_callback())
	add_callback(tunnel_spawn_callback())
	add_callback(journal_button_callback())
	add_callback(tunnel_text_callback())
	add_callback(remove_ana_callback())
	add_callback(pb_update_callback())
	add_callback(idol_price_callback())
	add_callback(idol_tile_code_callback())
	add_callback(reset_save_callback())
	add_callback(transition_save_callback())
	add_callback(clear_variables_callback())
	add_callback(on_save_callback())
	add_callback(save_current_run_stats_callback())

	add_vanilla_sound_callback(spring_volume_callback())
	add_vanilla_sound_callback(sign_mute_callback())
	add_vanilla_sound_callback(idol_sound_callback())
end

set_callback(function()
	activate()
end, ON.LOAD)

set_callback(function()
	activate()
end, ON.SCRIPT_ENABLE)

set_callback(function()
	if not active then return end
	active = false
	level_sequence.deactivate()
	telescopes.deactivate()
	button_prompts.deactivate()
	action_signs.deactivate()
	journal.deactivate()
	win_ui.deactivate()
	bottom_hud.deactivate()

	set_journal_enabled(true)

	for _, callback in pairs(callbacks) do
		clear_callback(callback)
	end
	for _, vanilla_sound_callback in pairs(vanilla_sound_callbacks) do
		clear_vanilla_sound_callback(vanilla_sound_callback)
	end
	callbacks = {}
	vanilla_sound_callbacks = {}
end, ON.SCRIPT_DISABLE)
