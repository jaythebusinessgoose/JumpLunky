meta.name = 'Jumplunky'
meta.version = '1.5'
meta.description = 'Challenging platforming puzzles'
meta.author = 'JayTheBusinessGoose'

local DWELLING_LEVEL <const> = 0
local VOLCANA_LEVEL <const> = 1
local TEMPLE_LEVEL <const> = 2
local ICE_LEVEL <const> = 3
local SUNKEN_LEVEL <const> = 4

local default_levels = {DWELLING_LEVEL, VOLCANA_LEVEL, TEMPLE_LEVEL, ICE_LEVEL, SUNKEN_LEVEL}
local levels = default_levels

first_level = levels[1]
initial_level = first_level
max_level = levels[#levels]
level = initial_level
continuing_run = false
local save_context

initial_bombs = 0
initial_ropes = 0

local DIFFICULTY <const> = {
	EASY = 0,
	NORMAL = 1,
	HARD = 2,
}
local current_difficulty = DIFFICULTY.NORMAL

-- overall state
total_idols = 0
idols_collected = {}
hardcore_enabled = false
hardcore_previously_enabled = false

-- Total time of the current run.
local time_total = 0

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

-- current run state
attempts = 0
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

local keep_entity_x, keep_entity_y, keep_entity_layer

------------------------
---- BUTTON PROMPTS ----
------------------------

-- The prompt type determines what icon is shown along with the prompt.
local PROMPT_TYPE <const> = {
	DOOR = 0,
	INTERACT = 1,
	VIEW = 2,
	SPEECH = 3,
}

local tvs = {}
local button_prompts_hidden = false
function hide_button_prompts(hidden)
	button_prompts_hidden = hidden
end

-- Spawn a button prompt at the coordinates.
function spawn_button_prompt(prompt_type, x, y, layer)
	-- Spawn a TV to "host" the prompt. We will hide the TV and silence its sound.
	local tv_uid = spawn_entity(ENT_TYPE.ITEM_TV, x, y, layer, 0, 0)
	local tv = get_entity(tv_uid)
	tv.flags = set_flag(tv.flags, ENT_FLAG.INVISIBLE)
	local prompt = get_entity(entity_get_items_by(tv.fx_button.uid, ENT_TYPE.FX_BUTTON_DIALOG, 0)[1])
	prompt.animation_frame = 137 + 16 * prompt_type
	tvs[#tvs+1] = tv
	return tv_uid
end

-- Silence the sound of TVs turning on -- these TVs are used to host the button prompts.
set_vanilla_sound_callback(VANILLA_SOUND.ITEMS_TV_LOOP, VANILLA_SOUND_CALLBACK_TYPE.STARTED, function(playing_sound)
	playing_sound:set_volume(0)
end)

set_callback(function()
	for _, tv in ipairs(tvs) do
		-- If the station was changed, reset it back to 0 (off).
		tv.station = 0
		if button_prompts_hidden then
			tv.flags = clr_flag(tv.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
		else
			tv.flags = set_flag(tv.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
		end
	end
end, ON.GAMEFRAME)

-------------------------
---- /BUTTON PROMPTS ----
-------------------------

---------------
---- SOUNDS ---
---------------

function play_sound(vanilla_sound)
	sound = get_sound(vanilla_sound)
	if sound then
		sound:play()
	end
end


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

local volcana_door
local temple_door
local ice_door
local sunken_door
local volcana_sign
local temple_sign
local ice_sign
local sunken_sign

local continue_door
local continue_sign

-- Title of a level that can be displayed to the player.
function title_of_level(level)
	if level == DWELLING_LEVEL then
		return "Dwelling"
	elseif level == VOLCANA_LEVEL then
		return "Volcana"
	elseif level == TEMPLE_LEVEL then
		return "Temple"
	elseif level == ICE_LEVEL then
		return "Ice Caves"
	elseif level == SUNKEN_LEVEL then
		return "Sunken City"
	end
	return "Unknown level: " .. level
end

-- Replace the background texture of a door with the texture of the correct level's theme.
function texture_door_at(x, y, layer, level)
	function texture_file_for_level(level)
		if level == DWELLING_LEVEL then
			return "floor_cave.png"
		elseif level == VOLCANA_LEVEL then
			return "floor_volcano.png"
		elseif level == TEMPLE_LEVEL then
			return "floor_temple.png"
		elseif level == ICE_LEVEL then
			return "floor_ice.png"
		elseif level == SUNKEN_LEVEL then
			return "floor_sunken.png"
		else
			return "floor_cave.png"
		end
	end

	local doors = get_entities_at(ENT_TYPE.BG_DOOR, 0, x, y, layer, 1)
	for i = 1, #doors do
		local door = get_entity(doors[i])
		local texture = door:get_texture()
		local texture_definition = get_texture_definition(texture)
		-- The image for the door is in the same position in all texture maps, so all we need to do is
		-- replace the image we pull from.
		texture_definition.texture_path = "Data/Textures/" .. texture_file_for_level(level)
		local new_texture = define_texture(texture_definition)
		door:set_texture(new_texture)
	end
end
	
function update_continue_door_enabledness()
	-- Effectively disables the "continue run" door if there is no saved progress to continue from.
	if continue_door then
		local x, y, layer = get_position(continue_door)
		local doors = get_entities_at(0, 0, x, y, layer, 1)
		for i=1,#doors do
			local door = get_entity(doors[i])
			if not current_saved_run().has_saved_run or hardcore_enabled then
				door.flags = clr_flag(door.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
			else
				-- Re-enable the door if hardcore mode is disabled, or if the difficulty is changed to one with a saved run.
				door.flags = set_flag(door.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
			end
		end
		texture_door_at(x, y, layer, current_saved_run().saved_run_level)
		local continue_door_entity = get_entity(continue_door)
		continue_door_entity.world = world_for_level(current_saved_run().saved_run_level)
		continue_door_entity.level = level_for_level(current_saved_run().saved_run_level)
		continue_door_entity.theme = theme_for_level(current_saved_run().saved_run_level)
	end
end

set_callback(function ()
	update_continue_door_enabledness()
	
	-- Replace the texture of the three shortcut doors and the continue door with the theme they lead to.
	if volcana_door then
		local x, y, layer = get_position(volcana_door)
		texture_door_at(x, y, layer, VOLCANA_LEVEL)
	end
	if temple_door then
		local x, y, layer = get_position(temple_door)
		texture_door_at(x, y, layer, TEMPLE_LEVEL)
	end
	if ice_door then
		local x, y, layer = get_position(ice_door)
		texture_door_at(x, y, layer, ICE_LEVEL)
	end
	if sunken_door then
		local x, y, layer = get_position(sunken_door)
		texture_door_at(x, y, layer, SUNKEN_LEVEL)
	end
	
	-- Replace the main entrance door with a door that leads to the first level (Dwelling).
    local entrance_uid = get_entities_by_type(ENT_TYPE.FLOOR_DOOR_STARTING_EXIT)
    if entrance_uid[1] then
        kill_entity(entrance_uid[1])
        spawn_door(42, 84, LAYER.FRONT, world_for_level(first_level), level_for_level(first_level), theme_for_level(first_level))
    end
end, ON.CAMP)

-- Spawn an idol that is not interactible in any way. Only spawns the idol if it has been collected
-- from the level it is being spawned for.
function spawn_camp_idol_for_level(level, x, y, layer)
	if not idols_collected[level] then return end
	
	local idol_uid = spawn_entity(ENT_TYPE.ITEM_IDOL, x, y, layer, 0, 0)
	local idol = get_entity(idol_uid)
	idol.flags = clr_flag(idol.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
	idol.flags = clr_flag(idol.flags, ENT_FLAG.PICKUPABLE)
end

-- Creates a "room" for the Volcana shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("volcana_shortcut")
set_pre_tile_code_callback(function(x, y, layer)
	volcana_door = spawn_door(x + 1, y, layer, world_for_level(VOLCANA_LEVEL), level_for_level(VOLCANA_LEVEL), theme_for_level(VOLCANA_LEVEL))
	volcana_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 3, y, layer, 0, 0)
	local sign = get_entity(volcana_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	sign.flags = clr_flag(sign.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	spawn_button_prompt(PROMPT_TYPE.VIEW, x + 3, y, layer)
	spawn_camp_idol_for_level(VOLCANA_LEVEL, x + 2, y, layer)
	return true
end, "volcana_shortcut")

-- Creates a "room" for the Temple shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("temple_shortcut")
set_pre_tile_code_callback(function(x, y, layer)
	temple_door = spawn_door(x + 1, y, layer, world_for_level(TEMPLE_LEVEL), level_for_level(TEMPLE_LEVEL), theme_for_level(TEMPLE_LEVEL))
	temple_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 3, y, layer, 0, 0)
	local sign = get_entity(temple_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	sign.flags = clr_flag(sign.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	spawn_button_prompt(PROMPT_TYPE.VIEW, x + 3, y, layer)
	spawn_camp_idol_for_level(TEMPLE_LEVEL, x + 2, y, layer)
	return true
end, "temple_shortcut")

-- Creates a "room" for the Ice Caves shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("ice_shortcut")
set_pre_tile_code_callback(function(x, y, layer)
	ice_door = spawn_door(x - 1, y, layer, world_for_level(ICE_LEVEL), level_for_level(ICE_LEVEL), theme_for_level(ICE_LEVEL))
	ice_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x - 3, y, layer, 0, 0)
	local sign = get_entity(ice_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	sign.flags = clr_flag(sign.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	spawn_button_prompt(PROMPT_TYPE.VIEW, x - 3, y, layer)
	spawn_camp_idol_for_level(ICE_LEVEL, x - 2, y, layer)
	return true
end, "ice_shortcut")

-- Creates a "room" for the Sunken City shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("sunken_shortcut")
set_pre_tile_code_callback(function(x, y, layer)
	sunken_door = spawn_door(x - 1, y, layer, world_for_level(SUNKEN_LEVEL), level_for_level(SUNKEN_LEVEL), theme_for_level(SUNKEN_LEVEL))
	sunken_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x - 3, y, layer, 0, 0)
	local sign = get_entity(sunken_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	sign.flags = clr_flag(sign.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	spawn_button_prompt(PROMPT_TYPE.VIEW, x - 3, y, layer)
	spawn_camp_idol_for_level(SUNKEN_LEVEL, x - 2, y, layer)
	return true
end, "sunken_shortcut")

-- Creates a "room" for a shortcut to a level that hasn't been created yet.
define_tile_code("locked_shortcut")
set_pre_tile_code_callback(function(x, y, layer)
	local sign_uid = spawn_entity(ENT_TYPE.ITEM_CONSTRUCTION_SIGN , x - 3, y, layer, 0, 0)
	local sign = get_entity(sign_uid)
	sign.flags = set_flag(sign.flags, ENT_FLAG.FACING_LEFT)
	return true
end, "locked_shortcut")

-- Creates a "room" for the continue entrance, with a door and a sign.
define_tile_code("continue_run")
set_pre_tile_code_callback(function(x, y, layer)
	continue_door = spawn_door(
		x + 1,
		y,
		layer,
		world_for_level(current_saved_run().saved_run_level),
		level_for_level(current_saved_run().saved_run_level),
		theme_for_level(current_saved_run().saved_run_level))
	continue_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 3, y, layer, 0, 0)
	local sign = get_entity(continue_sign)
	
	-- This stops the sign from displaying its default toast text when pressing the door button.
	sign.flags = clr_flag(sign.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	spawn_button_prompt(PROMPT_TYPE.VIEW, x + 3, y, layer)
	return true
end, "continue_run")

-- Spawns an idol if collected from the dwelling level, since there is no Dwelling shortcut.
define_tile_code("dwelling_idol")
set_pre_tile_code_callback(function(x, y, layer)
	spawn_camp_idol_for_level(DWELLING_LEVEL, x, y, layer)
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
	hardcore_tv = spawn_button_prompt(PROMPT_TYPE.INTERACT, x + 3, y, layer)
	
	easy_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 6, y, layer, 0, 0)
	local easy_sign_entity = get_entity(easy_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	easy_sign_entity.flags = clr_flag(easy_sign_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	easy_tv = spawn_button_prompt(PROMPT_TYPE.INTERACT, x + 6, y, layer)
	
	normal_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 7, y, layer, 0, 0)
	local normal_sign_entity = get_entity(normal_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	normal_sign_entity.flags = clr_flag(normal_sign_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	normal_tv = spawn_button_prompt(PROMPT_TYPE.INTERACT, x + 7, y, layer)
	
	hard_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 8, y, layer, 0, 0)
	local hard_sign_entity = get_entity(hard_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	hard_sign_entity.flags = clr_flag(hard_sign_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	hard_tv = spawn_button_prompt(PROMPT_TYPE.INTERACT, x + 8, y, layer)
	
	stats_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 10, y, layer, 0, 0)
	local stats_sign_entity = get_entity(stats_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	stats_sign_entity.flags = clr_flag(stats_sign_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	stats_tv = spawn_button_prompt(PROMPT_TYPE.VIEW, x + 10, y, layer)
	
	if legacy_normal_stats and legacy_easy_stats and legacy_hard_stats and legacy_hardcore_stats and legacy_hardcore_stats_easy and legacy_hardcore_stats_hard then
		legacy_stats_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 11, y, layer, 0, 0)
		local legacy_stats_sign_entity = get_entity(legacy_stats_sign)
		-- This stops the sign from displaying its default toast text when pressing the door button.
		legacy_stats_sign_entity.flags = clr_flag(legacy_stats_sign_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
		legacy_stats_tv = spawn_button_prompt(PROMPT_TYPE.VIEW, x + 11, y, layer)
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
	for i, lvl in ipairs(default_levels) do
		if idols_collected[lvl] then
			unique_idol_count = unique_idol_count + 1
		end
	end
	return unique_idol_count
end

function hardcore_available()
	return unique_idols_collected() == #default_levels
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
		play_sound(VANILLA_SOUND.UI_JOURNAL_ON)
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
		hide_button_prompts(true)
		journal_page = current_difficulty
		stats_open_button = 6
		stats_open_button_closed = false

		play_sound(VANILLA_SOUND.UI_JOURNAL_ON)
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
		hide_button_prompts(true)
		journal_page = current_difficulty
		stats_open_button = 6
		stats_open_button_closed = false

		play_sound(VANILLA_SOUND.UI_JOURNAL_ON)
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
			play_sound(VANILLA_SOUND.UI_JOURNAL_OFF)
			return
		end
		
		function play_journal_pageflip_sound()
			play_sound(VANILLA_SOUND.MENU_PAGE_TURN)
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
		hide_button_prompts(false)
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
		if player.layer == LAYER.FRONT and volcana_sign and distance(player.uid, volcana_sign) <= 1 then
			toast("Shortcut to Volcana trial")
		elseif player.layer == LAYER.FRONT and temple_sign and distance(player.uid, temple_sign) <= 1 then
			toast("Shortcut to Temple trial")
		elseif player.layer == LAYER.FRONT and ice_sign and distance(player.uid, ice_sign) <= 1 then
			toast("Shortcut to Ice Caves trial")
		elseif player.layer == LAYER.FRONT and sunken_sign and distance(player.uid, sunken_sign) <= 1 then
			toast("Shortcut to Sunken City trial")
		elseif player.layer == LAYER.FRONT and continue_sign and distance(player.uid, continue_sign) <= 1 then
			if hardcore_enabled then
				toast("Cannot continue in hardcore mode")
			elseif current_saved_run().has_saved_run then
				toast("Continue run from " .. title_of_level(current_saved_run().saved_run_level))
			else
				toast("No run to continue")
			end
		elseif player.layer == LAYER.FRONT and continue_door and not current_saved_run().has_saved_run and distance(player.uid, continue_door) <= 1 then
			toast("No run to continue")
		elseif player.layer == LAYER.FRONT and continue_door and hardcore_enabled and distance(player.uid, continue_door) <= 1 then
			toast("Cannot continue in hardcore mode")
		elseif player.layer == LAYER.BACK and hardcore_sign and distance(player.uid, hardcore_sign) <= .5 then
			if hardcore_available() then
				hardcore_enabled = not hardcore_enabled
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
	
	local saved_run = current_saved_run()
	continuing_run = false
	attempts = 0
	time_total = 0
	run_idols_collected = {}
	idols = 0
	-- Set some level and state properties for the door that the player is standing by. This is how we make sure to load the correct
	-- level when entering a door -- it is all based on which door they were closest to when entering.
	if (volcana_door and distance(players[1].uid, volcana_door) <= 1) or (volcana_sign and distance(player.uid, volcana_sign) <= 1) then
		initial_level = VOLCANA_LEVEL
		level = initial_level
	elseif (temple_door and distance(players[1].uid, temple_door) <= 1) or (temple_sign and distance(player.uid, temple_sign) <= 1) then
		initial_level = TEMPLE_LEVEL
		level = initial_level
	elseif (ice_door and distance(player.uid, ice_door) <= 1) or (ice_sign and distance(player.uid, ice_sign) <= 1) then
		initial_level = ICE_LEVEL
		level = initial_level
	elseif (sunken_door and distance(players[1].uid, sunken_door) <= 1) or (sunken_sign and distance(player.uid, sunken_sign) <= 1) then
		initial_level = SUNKEN_LEVEL
		level = initial_level
	elseif (saved_run.has_saved_run and not hardcore_enabled) and ((continue_door and distance(players[1].uid, continue_door) <= 1) or (continue_sign and distance(player.uid, continue_sign) <= 1)) then
		initial_level = first_level
		level = saved_run.saved_run_level
		continuing_run = true
		attempts = saved_run.saved_run_attempts
		time_total = saved_run.saved_run_time
		idols = saved_run.saved_run_idol_count
		run_idols_collected = saved_run.saved_run_idols_collected
	else
		-- If not next to any door, just set the state to the initial level. This will be overridden before actually entering a
		-- door, but is useful for showing GUI in the Camp.
		initial_level = first_level
		level = initial_level
	end
end, ON.GAMEFRAME)

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

--------------------------
---- LEVEL GENERATION ----
--------------------------

set_callback(function (ctx)
	if state.theme == THEME.BASE_CAMP then return end
	
	-- Most level types do not allow generation via setroom. For this reason, we add our level file
	-- instead of replacing the existing level files with it. Our level generation will run after
	-- the level has already been generated and will simply increase the size of the level to add our
	-- rooms and also fill in the existing rooms.
	local level_file_name
    if level == DWELLING_LEVEL then
		level_file_name = 'dwell'
	elseif level == VOLCANA_LEVEL then
		level_file_name = 'volc'
    elseif level == TEMPLE_LEVEL then
		level_file_name = 'temp'
	elseif level == ICE_LEVEL then
		level_file_name = 'ice'
    elseif level == SUNKEN_LEVEL then
		level_file_name = 'sunk'
	else
		return
	end
	local difficulty_prefix = '.lvl'
	if current_difficulty == DIFFICULTY.HARD then
		difficulty_prefix = '-hard.lvl'
	elseif current_difficulty == DIFFICULTY.EASY then
		difficulty_prefix = '-easy.lvl'
	end
	local file_name = f'{level_file_name}{difficulty_prefix}'

	ctx:override_level_files({ file_name, 'buffer.lvl', 'empty_rooms.lvl', 'icecavesarea.lvl'})
end, ON.PRE_LOAD_LEVEL_FILES)

-- Create a bunch of room templates that can be used in lvl files to create rooms. The maximum
-- level size is 8x15, so we only create that many templates.
local room_templates = {}
for x = 0, 7 do
	local room_templates_x = {}
	for y = 0, 14 do
		local room_template = define_room_template("setroom" .. y .. "_" .. x, ROOM_TEMPLATE_TYPE.NONE)
		room_templates_x[y] = room_template
	end
	room_templates[x] = room_templates_x
end
local buffer_template = define_room_template("buffer", ROOM_TEMPLATE_TYPE.NONE)
local buffer_hard_template = define_room_template("buffer_hard", ROOM_TEMPLATE_TYPE.NONE)
local buffer_special_template = define_room_template("buffer_special", ROOM_TEMPLATE_TYPE.NONE)

-- Returns size of the level in width, height.
function size_of_level(level)
	if level == TEMPLE_LEVEL then
		return 4, 6
	elseif level == DWELLING_LEVEL then
		return 4, 5
	elseif level == ICE_LEVEL then
		return 4, 13
	else
		return 4, 4
	end
end

-- Returns how many subrooms down to begin the actual level in x, y. Returning an x offset other than 0 isn't really
-- fully supported, so could have some undefined results.
function level_offset(level)
	return 0, 0
end

-- Returns the template that will be used to replace the rooms in the generated level.
function buffer_template_for_level(level, layer)
	return buffer_template
end

-- This doesn't actually create a shop template anymore, but it is used for swapping the backlayer door
-- for a shop-themed door.
function is_shop_template_for_level_at(level, x, y)
	if level == SUNKEN_LEVEL then
		if x == 2 and y == 2 then
			return true
		end
	end
	return false
end

set_callback(function (ctx)
	if state.theme == THEME.BASE_CAMP then return end
	-- For some reason, Volcana (maybe other areas?) will crash if we try to replace one of its exit door layouts.
	-- To avoid this crash, we offset the Y-position that we insert our generated level. We give it an offset of 4
	-- typically so that we can add several rooms of floor between the top layer and our level. This way the player
	-- does not see any of the generated level.
	-- This offset is configurable in case there are other crashes that require the offset to be changed for a level
	-- type.
	-- The X-position's offset is also configurable, but the way it is written currently does not properly handle an
	-- offset other than 0.
	local width, height = size_of_level(level)
	local offsetX, offsetY = level_offset(level)
	state.height = height + offsetY
	state.width = width + offsetX
	local buffer = buffer_template_for_level(level)
	for x = 0, width - 1 do
		for y = 0, height - 1 do
			ctx:set_room_template(x + offsetX, y + offsetY, LAYER.BACK, buffer_hard_template)
			ctx:set_room_template(x + offsetX, y + offsetY, LAYER.FRONT, room_templates[x][y])
       	end
		for y = 0, offsetY - 1 do
			ctx:set_room_template(x, y , LAYER.BACK, buffer_hard_template)
			ctx:set_room_template(x, y, LAYER.FRONT, buffer_hard_template)
		end
	end
end, ON.POST_ROOM_GENERATION)

---------------------------
---- /LEVEL GENERATION ----
---------------------------

-------------------
---- TELESCOPE ----
-------------------

local telescopes = {}
define_tile_code("telescope")
set_pre_tile_code_callback(function(x, y, layer)
	local new_telescope = spawn_entity(ENT_TYPE.ITEM_TELESCOPE, x, y, layer, 0, 0)
	telescopes[#telescopes + 1] = new_telescope
	local telescope_entity = get_entity(new_telescope)
	-- Disable the telescope's default interaction because it interferes with the zooming and panning we want to do
	-- when interacting with the telescope.
	telescope_entity.flags = clr_flag(telescope_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	-- Turn the telescope to the right since we start on the left side of every level. Should not call this
	-- line in levels that start on the right side.
	telescope_entity.flags = clr_flag(telescope_entity.flags, ENT_FLAG.FACING_LEFT)
	spawn_button_prompt(PROMPT_TYPE.VIEW, x, y, layer)
	return true
end, "telescope")

-- Telescope facing left.
define_tile_code("telescope_left")
set_pre_tile_code_callback(function(x, y, layer)
	local new_telescope = spawn_entity(ENT_TYPE.ITEM_TELESCOPE, x, y, layer, 0, 0)
	telescopes[#telescopes + 1] = new_telescope
	local telescope_entity = get_entity(new_telescope)
	-- Disable the telescope's default interaction because it interferes with the zooming and panning we want to do
	-- when interacting with the telescope.
	telescope_entity.flags = clr_flag(telescope_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	spawn_button_prompt(PROMPT_TYPE.VIEW, x, y, layer)
	return true
end, "telescope_left")

local telescope_activated = false 
local telescope_was_activated = nil
local telescope_activated_time = nil
local telescope_previous_zoom = nil
set_callback(function() 
	if #players < 1 or not telescopes then return end
	if state.theme == THEME.BASE_CAMP then return end 
	
	local player = players[1]
	for _, telescope in ipairs(telescopes) do
		if telescope and get_entity(telescope) and player.layer == get_entity(telescope).layer and distance(player.uid, telescope) <= 1 and player:is_button_pressed(BUTTON.DOOR) then
			-- Begin telescope interaction when the door button is pressed within a tile of the telescope.
			telescope_activated = true
			telescope_was_activated = nil
			telescope_activated_time = state.time_level
			-- Save the previous zoom level so that we can correct the camera's zoom when exiting the telescope.
			telescope_previous_zoom = get_zoom_level()
			-- Do not focus on the player while interacting with the telescope.
			state.camera.focused_entity_uid = -1
			local width, _ = size_of_level(level)
			-- Set the x position of the camera to the half-way point of the level. The 2.5 is added due to the amount
			-- of concrete border that is shown at the edges of the level.
			state.camera.focus_x = width * 5 + 2.5
			-- 30 is a good zoom level to fit a 4-room wide level width-wise. For larger or smaller levels, this value should be
			-- adjusted. Also, it should be adjusted to fit height-wise if the level scrolls horizontally.
			zoom(30)
			
			-- While looking through the telescope, the player should not be able to make any inputs. Instead, the movement
			-- keys will move the camera and the bomb key will dismiss the telescope.
			steal_input(player.uid)
			hide_button_prompts(true)
			break	
		end
	end
	if telescope_activated then
		-- Gets a bitwise integer that contains the set of pressed buttons while the input is stolen.
		local buttons = read_stolen_input(player.uid)
		local telescope_activated_long = telescope_activated_time and state.time_level - telescope_activated_time > 40
		-- 1 = jump, 2 = whip, 3 = bomb, 4 = rope, 6 = Door
		if test_flag(buttons, 1) or test_flag(buttons, 2) or test_flag(buttons, 3) or test_flag(buttons, 4) or (telescope_activated_long and test_flag(buttons, 6)) then
			telescope_activated = false
			-- Keep track of the time that the telescope was deactivated. This will allow us to enable the player's
			-- inputs later so that the same input isn't recognized again to cause a bomb to be thrown or another action.
			telescope_was_activated = state.time_level
			telescope_activated_time = nil
			-- Zoom back to the original zoom level.
			zoom(telescope_previous_zoom)
			telescope_previous_zoom = nil
			-- Make the camera follow the player again.
			state.camera.focused_entity_uid = player.uid
			return
		end
		
		-- Calculate the top and bottom of the level to stop the camera from moving.
		-- We don't want to show the player what we had to do at the top to get the level to generate without crashing.
		local offset_x, offset_y = level_offset(level)
		local _, room_pos_y = get_room_pos(offset_x, offset_y)
		local width, height = size_of_level(level)
		local camera_speed = .3
		width = width + offset_x
		height = height + offset_y
		local _, max_room_pos_y = get_room_pos(width, height)
		-- Currently, all levels fit the width of the zoomed-out screen, so only handling moving up and down.
		if test_flag(buttons, 11) then -- up_key
			state.camera.focus_y = state.camera.focus_y + camera_speed
			if state.camera.focus_y > room_pos_y - 11 then
				state.camera.focus_y = room_pos_y - 11
			end
		elseif test_flag(buttons, 12) then -- down_key
			state.camera.focus_y = state.camera.focus_y - camera_speed
			if state.camera.focus_y < max_room_pos_y + 8 then
				state.camera.focus_y = max_room_pos_y + 8
			end
		end
	elseif telescope_was_activated ~= nil and state.time_level  - telescope_was_activated > 40 then
		-- Re-activate the player's inputs 40 frames after the button was pressed to leave the telescope.
		-- This gives plenty of time for the player to release the button that was pressed, but also doesn't feel
		-- too long since it mostly occurs while the camera is moving back.
		return_input(player.uid)
		hide_button_prompts(false)
		telescope_was_activated = nil
	end
end, ON.FRAME)

--------------------
---- /TELESCOPE ----
--------------------

-----------------------
---- SPAWN ENEMIES ----
-----------------------

define_tile_code("catmummy")
set_pre_tile_code_callback(function(x, y, layer)
	spawn_entity(ENT_TYPE.MONS_CATMUMMY, x, y, layer, 0, 0)
	return true
end, "catmummy")

define_tile_code("firefrog")
set_pre_tile_code_callback(function(x, y, layer)
	spawn_entity(ENT_TYPE.MONS_FIREFROG, x, y, layer, 0, 0)
	return true
end, "firefrog")

-- Spawn a turkey in ice that must be extracted.
define_tile_code("ice_turkey")
set_pre_tile_code_callback(function(x, y, layer)
	-- Set the keep_entity properties so that we don't delete this entity with the procedural spawns.
	local ice_uid = spawn_entity(ENT_TYPE.FLOOR_ICE, x, y, layer, 0, 0)
	keep_entity_x, keep_entity_y, keep_entity_layer = x, y, layer
	local turkey_uid = spawn_entity_over(ENT_TYPE.ITEM_ALIVE_EMBEDDED_ON_ICE, ice_uid, 0, 0)
	keep_entity_x, keep_entity_y, keep_entity_layer = nil, nil, nil
	local turkey = get_entity(turkey_uid)
	turkey.inside = ENT_TYPE.MOUNT_TURKEY
	turkey.animation_frame = 239
	turkey.color.a = 130
	return true
end, "ice_turkey")

set_post_entity_spawn(function(entity)
	if level ~= ICE_LEVEL then return end
	-- Spawn the ice turkey dead so it can't be ridden.
	entity.health = 0
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.MOUNT_TURKEY)

-- Spawn a yeti in ice that must be extracted.
define_tile_code("ice_yeti")
set_pre_tile_code_callback(function(x, y, layer)
	-- Set the keep_entity properties so that we don't delete this entity with the procedural spawns.
	local ice_uid = spawn_entity(ENT_TYPE.FLOOR_ICE, x, y, layer, 0, 0)
	keep_entity_x, keep_entity_y, keep_entity_layer = x, y, layer
	local yeti_uid = spawn_entity_over(ENT_TYPE.ITEM_ALIVE_EMBEDDED_ON_ICE, ice_uid, 0, 0)
	keep_entity_x, keep_entity_y, keep_entity_layer = nil, nil, nil
	local yeti = get_entity(yeti_uid)
	yeti.inside = ENT_TYPE.MONS_YETI

	local texture_definition = TextureDefinition.new()
	texture_definition.texture_path = "Data/Textures/monsters03.png"
	texture_definition.width = 2048
	texture_definition.height = 2048
	texture_definition.tile_width = 128
	texture_definition.tile_height = 128
	texture_definition.sub_image_offset_x = 128 * 11 -- Let the computer do the math.
	texture_definition.sub_image_offset_y = 128 * 4
	texture_definition.sub_image_width = 128
	texture_definition.sub_image_height = 128
	local new_texture = define_texture(texture_definition)
	yeti:set_texture(new_texture)

	yeti.animation_frame = 0
	yeti.color.a = 130
	return true
end, "ice_yeti")

------------------------
---- /SPAWN ENEMIES ----
------------------------

----------------------------
---- HIDE ENTRANCE DOOR ----
----------------------------

local entranceX
local entranceY
local entranceLayer

set_pre_tile_code_callback(function(x, y, layer)
	entranceX = math.floor(x)
	entranceY = math.floor(y)
	entranceLayer = math.floor(layer)
	return false
end, "entrance")

set_post_entity_spawn(function (entity)
	if state.theme == THEME.BASE_CAMP then return end
	if not entranceX or not entranceY or not entranceLayer then return end
	local px, py, pl = get_position(entity.uid)
	if math.abs(px - entranceX) < 1 and math.abs(py - entranceY) < 1 and pl == entranceLayer then
        kill_entity(entity.uid)
	end
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.BG_DOOR)

-----------------------------
---- /HIDE ENTRANCE DOOR ----
-----------------------------

--------------
---- IDOL ----
--------------

local idol
function spawn_idol(x, y , layer)
	local idol_uid
	if current_difficulty == DIFFICULTY.EASY then
		spawn_entity(ENT_TYPE.ITEM_MADAMETUSK_IDOLNOTE, x, y, layer, 0, 0)
		return true
	elseif run_idols_collected[level] then
		-- Do not spawn the idol if it has already been collected on this run. This should be pretty rare because the
		-- the idol can only be deposited at the exit door, and the player cannot return to the level after exiting.
		return true
	elseif idols_collected[level] then
		-- If the idol for the level has _ever_ been collected, spawn a tusk idol instead.
		idol_uid = spawn_entity_snapped_to_floor(ENT_TYPE.ITEM_MADAMETUSK_IDOL, x, y, layer, 0, 0)
	else
		idol_uid = spawn_entity_snapped_to_floor(ENT_TYPE.ITEM_IDOL, x, y, layer, 0, 0)
	end
	idol = get_entity(idol_uid)
	-- Set the price to 0 so the player doesn't get gold for returning the idol.
	idol.price = 0
	return true
end

-- Spawn an idol in ice  that must be extracted.
define_tile_code("ice_idol")
set_pre_tile_code_callback(function(x, y, layer)
	-- Set the keep_entity properties so that we don't delete this entity with the procedural spawns.
	local ice_uid = spawn_entity(ENT_TYPE.FLOOR_ICE, x, y, layer, 0, 0)
	if current_difficulty == DIFFICULTY.EASY or run_idols_collected[level] then
		-- Do not spawn the idol in easy or if it has been collected.
		return true
	end
	
	keep_entity_x, keep_entity_y, keep_entity_layer = x, y, layer
	local idol_uid = spawn_entity_over(ENT_TYPE.ITEM_ALIVE_EMBEDDED_ON_ICE, ice_uid, 0, 0)
	keep_entity_x, keep_entity_y, keep_entity_layer = nil, nil, nil
	local idol = get_entity(idol_uid)
	if idols_collected[level] then
		idol.inside = ENT_TYPE.ITEM_MADAMETUSK_IDOL
		idol.animation_frame = 172
	else
		idol.inside = ENT_TYPE.ITEM_IDOL
		idol.animation_frame = 31
	end
	idol.color.a = 130
	return true
end, "ice_idol")

set_post_entity_spawn(function(entity)
	-- Set the price to 0 so the player doesn't get gold for returning the idol.
	entity.price = 0
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.ITEM_IDOL, ENT_TYPE.ITEM_MADAMETUSK_IDOL)

define_tile_code("idol_reward")
set_pre_tile_code_callback(function(x, y, layer)
	return spawn_idol(x, y, layer)
end, "idol_reward")

set_vanilla_sound_callback(VANILLA_SOUND.UI_DEPOSIT, VANILLA_SOUND_CALLBACK_TYPE.STARTED, function()
	if idol then
		-- Consider the idol collected when the deposit sound effect plays.
		idols_collected[level] = true
		run_idols_collected[level] = true
		idols = idols + 1
		total_idols = total_idols + 1
		idol = nil
	end
end)

---------------
---- /IDOL ----
---------------

------------------------------
---- CRATE WITH ROPE PILE ----
------------------------------

-- Spawns a crate that contains a pile of three ropes.
define_tile_code("rope_crate")
set_pre_tile_code_callback(function(x, y, layer)
	-- We must "force" the crate to spawn here since we typically kill crate spawns so the player doesn't see randomly
	-- generated crates.
	local crate_id = spawn_entity_forced(ENT_TYPE.ITEM_CRATE, x, y, layer)
	local crate = get_entity(crate_id)
	crate.inside = ENT_TYPE.ITEM_PICKUP_ROPEPILE
	return true
end, "rope_crate")

-------------------------------
---- /CRATE WITH ROPE PILE ----
-------------------------------

----------------
---- LASERS ----
----------------

local challenge_forcefield
local challenge_waitroom
local laser_switch
local has_switched_forcefield = false

define_tile_code("laser_switch")
set_pre_tile_code_callback(function(x, y, layer)
	local switch_id = spawn_entity(ENT_TYPE.ITEM_SLIDINGWALL_SWITCH, x, y, layer, 0, 0)
	laser_switch = get_entity(switch_id)
	return true
end, "laser_switch")

-- Laser that guards the entrance of the sun challenge until laser_switch is switched.
define_tile_code("challenge_forcefield_switchable")
set_pre_tile_code_callback(function(x, y, layer)
	local forcefield_id = spawn_entity(ENT_TYPE.FLOOR_FORCEFIELD, x, y, layer, 0, 0)
	challenge_forcefield = get_entity(forcefield_id)
	challenge_forcefield:activate_laserbeam(true)
	return true
end, "challenge_forcefield_switchable")

-- Laser that turns on while participating in the sun challenge.
define_tile_code("challenge_waitroom_switchable")
set_pre_tile_code_callback(function(x, y, layer)
	local forcefield_id = spawn_entity(ENT_TYPE.FLOOR_CHALLENGE_WAITROOM, x, y, layer, 0, 0)
	challenge_waitroom = get_entity(forcefield_id)
	challenge_waitroom:activate_laserbeam(false)
	return true
end, "challenge_waitroom_switchable")

set_callback(function ()
	if level == SUNKEN_LEVEL then
		if has_switched_forcefield then return end
		if laser_switch.timer > 0 then
			challenge_forcefield:activate_laserbeam(false)
			has_switched_forcefield = true
			
			-- Play a sound when flipping the switch so the player knows something happened.
			play_sound(VANILLA_SOUND.UI_SECRET)
		end
	end
end, ON.FRAME)

-----------------
---- /LASERS ----
-----------------

-----------------------
---- SUN CHALLENGE ----
-----------------------


-- Replace the back layer door with the correct style door for the challenge.
set_post_entity_spawn(function (entity)
	local x, y, layer = get_position(entity.uid)
	local roomX, roomY = get_room_index(x, y)
	local offsetX, offsetY = level_offset(level)
	if is_shop_template_for_level_at(level, roomX - offsetX, roomY - offsetY) then
		kill_entity(entity.uid)
		spawn_entity(ENT_TYPE.BG_SHOP_BACKDOOR, x, y, layer, 0, 0)
	end
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.BG_DOOR_FRONT_LAYER)

local kill_tun_plz
local tunx,tuny,tunlayer
set_post_entity_spawn(function (entity)
	-- Add shop backlayer tiles to the room so it looks more like an actual challenge.
	local x, y, layer = get_position(entity.uid)
	local room_index_x, room_index_y = get_room_index(x, y)
	local room_start_x, room_start_y = get_room_pos(room_index_x, room_index_y)
	for i=room_start_x + 2,room_start_x+9 do
		for j=room_start_y-7, room_start_y-1 do
			local ship = spawn_entity(ENT_TYPE.BG_SHOP, i, j, layer, 0, 0)
			local shop = get_entity(ship)
			local texture_definition = TextureDefinition.new()
			texture_definition.texture_path = "Data/Textures/floorstyled_wood.png"
			texture_definition.width = 1280
			texture_definition.height = 1280
			texture_definition.tile_width = 128
			texture_definition.tile_height = 128
			texture_definition.sub_image_offset_x = 768 + 128 -- Let the computer do the math.
			texture_definition.sub_image_offset_y = 0
			texture_definition.sub_image_width = 256
			texture_definition.sub_image_height = 128
			local new_texture = define_texture(texture_definition)
			shop:set_texture(new_texture)
		end
	end

	-- Prepare Tun to be killed.
	kill_tun_plz = entity
	state.merchant_aggro = 1
	tunx, tuny, tunlayer = x, y, layer
	entity.health = 1
	entity.flags = set_flag(entity.flags, ENT_FLAG.INVISIBLE)
	entity.flags = set_flag(entity.flags, ENT_FLAG.FACING_LEFT)
	
	-- Move Tun off-screen to kill her without the player seeing or hearing.
	move_entity(entity.uid, 10000, y, layer, 0, 0)
	-- Spawn a skull at Tun's position to kill her.
	spawn_entity(ENT_TYPE.ITEM_SKULLDROPTRAP_SKULL, 10000, y, layer, 0, 0)
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.MONS_MERCHANT)

set_callback(function()
	if level == SUNKEN_LEVEL and kill_tun_plz then
		if kill_tun_plz.health == 0 then
			kill_tun_plz.flags = clr_flag(kill_tun_plz.flags, ENT_FLAG.INVISIBLE)
			kill_tun_plz.flags = set_flag(kill_tun_plz.flags, ENT_FLAG.FACING_LEFT)
			if current_difficulty == DIFFICULTY.EASY then
				-- Do not allow Tun to be picked up in easy mode; the sun challenge should be unavailable.
				kill_tun_plz.flags = clr_flag(kill_tun_plz.flags, ENT_FLAG.PICKUPABLE)
				kill_tun_plz.flags = clr_flag(kill_tun_plz.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
			else
				-- Allow the player to pick up Tun to activate the sun challenge.
				kill_tun_plz.flags = set_flag(kill_tun_plz.flags, ENT_FLAG.PICKUPABLE)
				kill_tun_plz.flags = set_flag(kill_tun_plz.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
			end
			move_entity(kill_tun_plz.uid, tunx, tuny, tunlayer, 0, 0)
			kill_tun_plz = nil
		end
	end
end, ON.FRAME)

set_pre_tile_code_callback(function(x, y, layer)
	-- Spawn a non-loaded HouYi Bow.
	spawn_entity(ENT_TYPE.ITEM_HOUYIBOW, x, y, layer, 0, 0)
	return true
end, "houyibow")

local dead_ana_pls_kill
define_tile_code("ana_spelunky")
set_pre_tile_code_callback(function(x, y, layer)
	local ana_uid = spawn_entity(ENT_TYPE.MONS_CAVEMAN, x, y, layer, 0, 0)
	local ana = get_entity(ana_uid)
	local ana_texture = ana:get_texture()
	local ana_texture_definition = get_texture_definition(ana_texture)
	ana_texture_definition.texture_path = "Data/Textures/ana_dead2.png"
	local new_texture = define_texture(ana_texture_definition)
	ana:set_texture(new_texture)
	-- We must kill Ana too, otherwise we can't get the bow she brought to the challenge room. :(
	ana.health = 0
	ana.flags = clr_flag(ana.flags, ENT_FLAG.PICKUPABLE)
	ana.flags = clr_flag(ana.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
	ana.flags = set_flag(ana.flags, ENT_FLAG.TAKE_NO_DAMAGE)
	ana.flags = set_flag(ana.flags, ENT_FLAG.DEAD)
	dead_ana_pls_kill = ana
	return true
end, "ana_spelunky")

set_callback(function()
	if not dead_ana_pls_kill then return end
	-- Kill ana on each frame in case a necromancer revives her.
	dead_ana_pls_kill.health = 0
end, ON.FRAME)

local challenge_reward_position_x
local challenge_reward_position_y
local challenge_reward_layer
define_tile_code("challenge_reward")
set_pre_tile_code_callback(function(x, y, layer)
	-- Save the position of the tile we want to spawn the challenge reward (idol) at so we can spawn it later when
	-- the challenge has been completed.
	challenge_reward_position_x = x
	challenge_reward_position_y = y
	challenge_reward_layer = layer
	return true
end, "challenge_reward")

local sunchallenge_generators = {}
local sunchallenge_switch

-- Generators that will spawn the sun challenge enemies.
define_tile_code("sunchallenge_generator")
set_pre_tile_code_callback(function(x, y, layer)
	local generator_id = spawn_entity(ENT_TYPE.FLOOR_SUNCHALLENGE_GENERATOR, x, y, layer, 0, 0)
	local generator = get_entity(generator_id)
	generator.on_off = false
	-- Store these so we can activate them later.
	sunchallenge_generators[#sunchallenge_generators + 1] = generator
	return true
end, "sunchallenge_generator")

define_tile_code("sunchallenge_switch")
set_pre_tile_code_callback(function(x, y, layer)
    local switch_id = spawn_entity(ENT_TYPE.ITEM_SLIDINGWALL_SWITCH, x, y, layer, 0, 0)
	sunchallenge_switch = get_entity(switch_id)
	return true
end, "sunchallenge_switch")

set_post_entity_spawn(function(entity)
	if level == SUNKEN_LEVEL then
		-- Do not spawn capes from sun challenge vampires.
		kill_entity(entity.uid)
	end
end, SPAWN_TYPE.SYSTEMIC, 0, ENT_TYPE.ITEM_CAPE)

local has_payed_for_sun_challenge = false
local sun_wait_timer
local has_activated_sun_challenge = false
local sun_challenge_activation_time
local has_completed_sun_challenge = false
local sun_challenge_toast_shown = 0
set_callback(function ()
	if level == SUNKEN_LEVEL then
		-- This allows us to kill all of the spanws when the challenge is completed or the player dies.
		function clear_sun_challenge_spawns()
			local sun_challenge_spawns = get_entities_by_type({ENT_TYPE.MONS_SORCERESS, ENT_TYPE.MONS_VAMPIRE, ENT_TYPE.MONS_WITCHDOCTOR, ENT_TYPE.MONS_NECROMANCER, ENT_TYPE.MONS_REDSKELETON, ENT_TYPE.MONS_BAT, ENT_TYPE.MONS_BEE, ENT_TYPE.MONS_SKELETON, ENT_TYPE.MONS_SNAKE, ENT_TYPE.MONS_SPIDER})
			for i=1,#sun_challenge_spawns do
				local spawn = sun_challenge_spawns[i]
				kill_entity(spawn)
			end
		end
		
		-- Turns off all generators.
		function deactivate_generators()
			for i = 1, #sunchallenge_generators do
				local generator = sunchallenge_generators[i]
				generator.on_off = false
			end
		end
		if #players < 1 or players[1].health == 0 then
			deactivate_generators()
			clear_sun_challenge_spawns()
			return
		end
		if has_completed_sun_challenge then
			-- Do nothing, all done.
		elseif has_activated_sun_challenge then
			-- This means the player is currently participating in the challenge or waiting for it to begin.
			
			-- The number of frames since the challenge was started.
			local time_waiting = state.time_level - sun_challenge_activation_time
			
			-- Turns on all generators to begin the challenge.
			function activate_generators()
				for i = 1, #sunchallenge_generators do
					local generator = sunchallenge_generators[i]
					generator.on_off = true
				end
			end
			if players[1].health == 0 then
				-- Turn off the challenge and kill all spawns if the player dies.
				clear_sun_challenge_spawns()
				has_completed_sun_challenge = true
				deactivate_generators()
				return
			elseif sun_challenge_toast_shown == 0 then
				if time_waiting > 60 then
					toast("3...")
					sun_challenge_toast_shown = 1
				end
			elseif sun_challenge_toast_shown == 1 then
				if time_waiting > 110 then
					-- Cancel the previous toast to make sure the next one displays.
					cancel_toast()
				end
				if time_waiting > 120 then
					toast("2...")
					sun_challenge_toast_shown = 2
				end
			elseif sun_challenge_toast_shown == 2 then
				if time_waiting > 170 then
					-- Cancel the previous toast to make sure the next one displays.
					cancel_toast()
				end
				if time_waiting > 180 then
					toast("1...")
					sun_challenge_toast_shown = 3
				end
			elseif sun_challenge_toast_shown == 3 then
				if time_waiting > 230 then
					-- Cancel the previous toast to make sure the next one displays.
					cancel_toast()
				end
				if time_waiting > 240 then
					challenge_waitroom:activate_laserbeam(false)
					toast("Survive!")
					sun_challenge_toast_shown = 4
					activate_generators()
				end
			elseif sun_challenge_toast_shown == 4 then
				if time_waiting > 240 + 25 * 60 then
					toast("5 seconds remaining!")
					sun_challenge_toast_shown = 5
				end
			elseif sun_challenge_toast_shown == 5 then
				if time_waiting > 240 + 30 * 60 then
					toast("You've won!")
					deactivate_generators()
					clear_sun_challenge_spawns()
					challenge_forcefield:activate_laserbeam(false)
					sun_challenge_toast_shown = 6
					has_completed_sun_challenge = true
					if challenge_reward_position_x then
						spawn_idol(challenge_reward_position_x, challenge_reward_position_y, challenge_reward_layer)
					end
				end
			end
		elseif sun_wait_timer and state.time_level - sun_wait_timer > 90 then
			-- After the player has been in the waiting room for 90 frames (1.5 seconds), turn on the laserbeams and start the countdown
			-- to begin the challenge.
			has_activated_sun_challenge = true
			challenge_forcefield:activate_laserbeam(true)
			challenge_waitroom:activate_laserbeam(true)
			sun_challenge_activation_time = state.time_level
		elseif has_payed_for_sun_challenge then
			local minx, miny, layer = get_position(challenge_waitroom.uid)
			local maxx, _, _ = get_position(challenge_forcefield.uid) 
			local playerx, playery, playerLayer = get_position(players[1].uid)
			
			-- Reset the wait timer if the player leaves the waiting room within 90 frames (1.5 seconds) of entering it.
			if not (layer == playerLayer and playerx > minx and playerx < maxx - 1 and playery < miny + 3 and playery > miny) then
				sun_wait_timer = state.time_level
			end
		elseif state.kali_favor >= 3 then
			cancel_toast()
			has_payed_for_sun_challenge = true			
			challenge_waitroom:activate_laserbeam(true)
			function activate_challenge()
				toast("Enter the door to begin the Challenge.")		
			end
			set_timeout(activate_challenge, 1)
			sun_wait_timer = state.time_level
		end
	end
end, ON.FRAME)

-- We don't want sun challenge bats or Guts tadpoles/coffins.
set_post_entity_spawn(function (entity)
	if level == SUNKEN_LEVEL then
		entity.flags = set_flag(entity.flags, ENT_FLAG.INVISIBLE)
		move_entity(entity.uid, 1000, 0, 0, 0)
	end
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.MONS_BAT, ENT_TYPE.MONS_TADPOLE, ENT_TYPE.ITEM_COFFIN)

define_tile_code("kali_statue")
set_pre_tile_code_callback(function(x, y, layer)
	local kali_uid = spawn_entity(ENT_TYPE.BG_KALI_STATUE, x + .5, y, layer, 0, 0)
	local kali = get_entity(kali_uid)
	kali.height = 7
	kali.width = 6
end, "kali_statue")

------------------------
---- /SUN CHALLENGE ----
------------------------

-----------------------
---- BAT GENERATOR ----
-----------------------

local bat_generator
define_tile_code("bat_generator")
set_pre_tile_code_callback(function(x, y, layer)
	-- Creates a generator that will spawn bats when turned on. Defaults to off.
	local generator_id = spawn_entity(ENT_TYPE.FLOOR_SUNCHALLENGE_GENERATOR, x, y, layer, 0.0, 0.0)
	local generator = get_entity(generator_id)
	generator.on_off = false
	bat_generator = generator
	return true
end, "bat_generator")

define_tile_code("bat_switch")
local bat_switch
set_pre_tile_code_callback(function(x, y, layer)
    local switch_id = spawn_entity(ENT_TYPE.ITEM_SLIDINGWALL_SWITCH, x, y, layer, 0, 0)
	bat_switch = get_entity(switch_id)
	return true
end, "bat_switch")


local last_spawn
local spawned_bat
set_post_entity_spawn(function(ent)
	if level == DWELLING_LEVEL then
		if last_spawn ~= nil then
			-- Kill the last enemy that was spawned so that we don't end up with too many enemies in memory. Doing this here
			-- since we couldn't kill the enemy earlier.
			kill_entity(last_spawn.uid)
		end
		last_spawn = ent
		local x, y, l = get_position(ent.uid)
		-- Spawn a bat one tile lower than the tile the enemy was spawned at; otherwise the bat will be crushed in the generator.
		spawned_bat = spawn_entity_nonreplaceable(ENT_TYPE.MONS_BAT, x, y - 1, l, 0, 0)
		-- Move the actual spawn out of the way instead of killing it; killing it now causes the generator to immediately
		-- spawn again, leading to infinite spawns.
		ent.x = 10000
		-- Turn off the generator when a bat is spawned to make sure only one bat is ever spawned at a time.
		bat_generator.on_off = false
	end
end, SPAWN_TYPE.SYSTEMIC, 0, {ENT_TYPE.MONS_SORCERESS, ENT_TYPE.MONS_VAMPIRE, ENT_TYPE.MONS_WITCHDOCTOR, ENT_TYPE.MONS_NECROMANCER})

set_callback(function ()
	if level == DWELLING_LEVEL then
		local bat_entity = get_entity(spawned_bat)
		if bat_entity and bat_entity.health == 0 then
			-- Turn the generator back on now that the bat is dead.
			bat_generator.on_off = true
			spawned_bat = nil
		end
		if bat_switch.timer > 0 and bat_entity == nil and not bat_generator.on_off then
			bat_generator.on_off = true
			
			play_sound(VANILLA_SOUND.UI_SECRET)
		end
	end
end, ON.FRAME)

------------------------
---- /BAT GENERATOR ----
------------------------

------------------
---- MAGMAMAN ----
------------------

set_post_entity_spawn(function (entity)
	if level == VOLCANA_LEVEL then
		-- Do not spawn magma men in the volcana lava.
		local x, y, layer = get_position(entity.uid)
		local lavas = get_entities_at(0, MASK.LAVA, x, y, layer, 1)
		if #lavas > 0 then
			entity.flags = set_flag(entity.flags, ENT_FLAG.INVISIBLE)
			move_entity(entity.uid, 1000, 0, 0, 0)
		end
	end
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.MONS_MAGMAMAN)

-------------------
---- /MAGMAMAN ----
-------------------

----------------------
---- SWITCH WALLS ----
----------------------

-- Creates walls that will be destroyed when the totem_switch is switched. Don't ask why these are called totems, they're just walls.
local moving_totems = {}
define_tile_code("moving_totem")
set_pre_tile_code_callback(function(x, y, layer)
	local totem_uid = spawn_entity(ENT_TYPE.FLOOR_GENERIC, x, y, layer, 0, 0)
	moving_totems[#moving_totems + 1] = get_entity(totem_uid)
	return true
end, "moving_totem")

define_tile_code("totem_switch")
local totem_switch;
set_pre_tile_code_callback(function(x, y, layer)
    local switch_id = spawn_entity(ENT_TYPE.ITEM_SLIDINGWALL_SWITCH, x, y, layer, 0, 0)
	totem_switch = get_entity(switch_id)
	return true
end, "totem_switch")

set_callback(function()
	if not totem_switch then return end
	if totem_switch.timer > 0 and not has_activated_totem then
		has_activated_totem = true
		for i=1, #moving_totems do
			kill_entity(moving_totems[i].uid)	
		end
		moving_totems = {}
	end
end, ON.FRAME)

-----------------------
---- /SWITCH WALLS ----
-----------------------

-----------------------------
---- PLAYER SPEECH HINTS ----
-----------------------------

-- Specific to the Dwelling level, this is a block that will cause the player to say a message upon
-- walking past it.
local dialog_block_pos_x
local dialog_block_pos_y
define_tile_code("dialog_block")
set_pre_tile_code_callback(function(x, y, layer)
	dialog_block_pos_x = x
	dialog_block_pos_y = y
	return true
end, "dialog_block")

-- A merchant (Tun) that will be spoken to when walking near.
local dialog_merchant
set_post_entity_spawn(function (entity)
	if level == SUNKEN_LEVEL then
		dialog_merchant = entity
	end
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.MONS_MERCHANT)

-- A character (Ana) that will be spoken to when walking near (she is actually a Caveman so she doesn't crash the game).
local dialog_ana
set_post_entity_spawn(function (entity)
	if level == SUNKEN_LEVEL and not dialog_ana then
		dialog_ana = entity
	end
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.MONS_CAVEMAN)

local hasDisplayedDialog = false
set_callback(function ()
    if #players < 1 then return end
	local player = players[1]
	local player_uid = player.uid
	local x, y, layer = get_position(player_uid)
	
	if level == DWELLING_LEVEL then
		if x <= dialog_block_pos_x and y >= dialog_block_pos_y then
			if not hasDisplayedDialog then
				say(player_uid, "I don't think this is the right way.", 0, true)
				hasDisplayedDialog = true
			end
		else
			hasDisplayedDialog = false
		end
	elseif level == SUNKEN_LEVEL then
		if dialog_merchant and layer == LAYER.FRONT then
			if distance(player_uid, dialog_merchant.uid) <= 2 then
				say(player_uid, "What happened here?", 0, true)
				dialog_merchant = nil
			end
		end
		if dialog_ana and layer == LAYER.BACK then
			if distance(player_uid, dialog_ana.uid) <= 2 then
				if player:get_name() == "Ana Spelunky" then
					say(player_uid, "What? Is that... me? What's going on here?", 0, true)
				else
					say(player_uid, "Ana? This can't be... The caves are supposed to...", 0, true)
				end
				has_seen_ana_dead = true
				dialog_ana = nil
			end
		end
	end
end, ON.FRAME)

------------------------------
---- /PLAYER SPEECH HINTS ----
------------------------------

----------------------------
---- DO NOT SPAWN GHOST ----
----------------------------

set_ghost_spawn_times(-1, -1)

-----------------------------
---- /DO NOT SPAWN GHOST ----
-----------------------------

-------------------------------
---- PREVENT RANDOM SPAWNS ----
-------------------------------

set_pre_entity_spawn(function(entity, x, y, layer, overlay)
	-- Spawn TVs instead of cursed pots to make sure the cursed pot doesn't break and spawn the ghost.
	return spawn_entity(ENT_TYPE.ITEM_TV, 1000, 0, 0, 0, 0)
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.ITEM_CURSEDPOT)

set_post_entity_spawn(function (entity)
	if state.theme == THEME.BASE_CAMP then return end
	local x, y, layer = get_position(entity.uid)
	if keep_entity_x and keep_entity_y and keep_entity_layer and keep_entity_x == x and keep_entity_y == y and keep_entity_layer == layer then return end
	entity.flags = set_flag(entity.flags, ENT_FLAG.INVISIBLE)
	move_entity(entity.uid, 1000, 0, 0, 0)
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.ITEM_TORCH, ENT_TYPE.ITEM_ALIVE_EMBEDDED_ON_ICE, ENT_TYPE.MONS_PET_DOG, ENT_TYPE.ITEM_BONES, ENT_TYPE.EMBED_GOLD, ENT_TYPE.EMBED_GOLD_BIG, ENT_TYPE.ITEM_POT, ENT_TYPE.ITEM_NUGGET, ENT_TYPE.ITEM_NUGGET_SMALL, ENT_TYPE.ITEM_SKULL, ENT_TYPE.ITEM_CHEST, ENT_TYPE.ITEM_CRATE, ENT_TYPE.MONS_PET_CAT, ENT_TYPE.MONS_PET_HAMSTER, ENT_TYPE.ITEM_ROCK, ENT_TYPE.ITEM_RUBY, ENT_TYPE.ITEM_SAPPHIRE, ENT_TYPE.ITEM_EMERALD, ENT_TYPE.ITEM_WALLTORCH, ENT_TYPE.MONS_SCARAB, ENT_TYPE.ITEM_AUTOWALLTORCH, ENT_TYPE.ITEM_WEB, ENT_TYPE.ITEM_GOLDBAR, ENT_TYPE.ITEM_GOLDBARS, ENT_TYPE.MONS_SKELETON, ENT_TYPE.ITEM_CURSEDPOT, ENT_TYPE.MONS_CRITTERDUNGBEETLE, ENT_TYPE.MONS_CRITTERBUTTERFLY, ENT_TYPE.MONS_CRITTERSNAIL, ENT_TYPE.MONS_CRITTERFISH, ENT_TYPE.MONS_CRITTERANCHOVY, ENT_TYPE.MONS_CRITTERCRAB, ENT_TYPE.MONS_CRITTERLOCUST, ENT_TYPE.MONS_CRITTERPENGUIN, ENT_TYPE.MONS_CRITTERFIREFLY, ENT_TYPE.MONS_CRITTERDRONE, ENT_TYPE.MONS_CRITTERSLIME)

-- Spawning via this method essentially ignores the spawn prevention by moving the entity back. This must be called when spawning an
-- entity that is normally removed.
function spawn_entity_forced(entity_type, x, y, layer)
	local entity_uid = spawn_entity_nonreplaceable(entity_type, x, y, layer, 0, 0)
	local entity = get_entity(entity_uid)
	move_entity(entity_uid, x, y, 0, 0)
	entity.flags = clr_flag(entity.flags, ENT_FLAG.INVISIBLE)
	return entity_uid
end

--------------------------------
---- /PREVENT RANDOM SPAWNS ----
--------------------------------

----------------------------------
---- MANAGE LEVEL TRANSITIONS ----
----------------------------------

-- Mange saving data and keeping the time in sync during level transitions and resets.

function save_data()
	if save_context then
		force_save(save_context)
	end
end

-- Since we are keeping track of time for the entire run even through deaths and resets, we must track
-- what the time was on resets and level transitions.
local started = false
set_callback(function ()
    if state.theme == THEME.BASE_CAMP then return end
	if started then 
		if hardcore_enabled then
			-- Reset the time when hardcore is enabled; the run is going to be reset.
			time_total = 0
		else
			-- Save the time on reset so we can keep the timer going.
			time_total = state.time_total
			
			save_current_run_stats()
		end
		save_data()
	end
end, ON.RESET)

set_callback(function ()
	if state.theme == THEME.BASE_CAMP then return end
	if started and not win then
		time_total = state.time_total
		
		save_current_run_stats()
		save_data()
	end
--	local x, y, layer = players[1].x, players[1].y, LAYER.FRONT-- get_postition(players[1].uid)
--	spawn_entity(players[1].type.id, 15, 0, LAYER.PLAYER, 0, 0)
--	players[1].x = players[1].x + 5
--	players[1].flags = set_flag(players[1].flags, ENT_FLAG.INVISIBLE)
end, ON.TRANSITION)

set_callback(function ()
    if state.theme == THEME.BASE_CAMP then return end
	state.time_total = time_total
end, ON.POST_LEVEL_GENERATION)

set_callback(function ()
end, ON.LEVEL)

set_callback(function ()
    if state.theme == THEME.BASE_CAMP then return end
	started = true
	attempts = attempts + 1
end, ON.START)

set_callback(function ()
	started = false
end, ON.CAMP)

-----------------------------------
---- /MANAGE LEVEL TRANSITIONS ----
-----------------------------------

----------------------
---- LEVEL THEMES ----
----------------------

function theme_for_level(level)
	if level == DWELLING_LEVEL then
		return THEME.DWELLING
	elseif level == VOLCANA_LEVEL then
		return THEME.VOLCANA
	elseif level == TEMPLE_LEVEL then
		return THEME.TEMPLE
	elseif level == ICE_LEVEL then
		return THEME.ICE_CAVES
	elseif level == SUNKEN_LEVEL then
		return THEME.SUNKEN_CITY
	end
	return THEME.BASE_CAMP
end

function level_for_level(level)
	return 5
end

function world_for_level(level)
	if level == DWELLING_LEVEL then
		return 1
	elseif level == VOLCANA_LEVEL then
		return 2
	elseif level == TEMPLE_LEVEL then
		return 4
	elseif level == ICE_LEVEL then
		return 5
	elseif level == SUNKEN_LEVEL then
		return 7
	end
	return 1
end

set_callback(function ()
	if #players == 0 then return end

	players[1].inventory.bombs = initial_bombs
	players[1].inventory.ropes = initial_ropes
	if players[1]:get_name() == "Roffy D. Sloth" or level == ICE_LEVEL then
		players[1].health = 1
	else
		players[1].health = 2
	end
	
	-- This doesn't affect anything except what is displayed in the UI. When we have more than one level
	-- per theme, we can use more complicated logic to determine what do display.
	state.world = level + 1
	state.level = 1
	
	if not hardcore_enabled then
		-- Setting the _start properties of the state will ensure that Instant Restarts will take the player back to the
		-- current level, instead of going to the starting level.
		state.world_start = world_for_level(level)
		state.theme_start = theme_for_level(level)
		state.level_start = level_for_level(level)
	end

	local next_level = level + 1
	local exit_uids = get_entities_by_type(ENT_TYPE.FLOOR_DOOR_EXIT)
	for i = 1,  #exit_uids do
		local exit_uid = exit_uids[i]
		local exit_ent = get_entity(exit_uid)
		if exit_ent then
			exit_ent.entered = false
			exit_ent.special_door = true
			if level == max_level then
				-- The door in the final level will take the player back to the camp.
				exit_ent.world = 1
				exit_ent.level = 1
				exit_ent.theme = THEME.BASE_CAMP
			else
				-- Sets the theme of the door to the theme of the next level we will load.
				exit_ent.world = world_for_level(next_level)
				exit_ent.level = level_for_level(next_level)
				exit_ent.theme = theme_for_level(next_level)
			end
		end
	end
end, ON.POST_LEVEL_GENERATION)


-----------------------
---- /LEVEL THEMES ----
-----------------------

--------------------------
---- STATE MANAGEMENT ----
--------------------------

-- Saves the current state of the run so that it can be continued later if exited.
function save_current_run_stats()
	time_total = state.time_total
	-- Save the current run only if there is a run in progress that did not start from a shorcut, and harcore mode is disabled.
	if initial_level == first_level and not hardcore_enabled and state.theme ~= THEME.BASE_CAMP and started then
		local saved_run = current_saved_run()
		saved_run.saved_run_attempts = attempts
		saved_run.saved_run_idol_count = idols
		saved_run.saved_run_level = level
		saved_run.saved_run_time = time_total
		saved_run.saved_run_idols_collected = run_idols_collected
		saved_run.has_saved_run = true
	end
	
end

set_callback(function()
	if started and state.theme ~= THEME.BASE_CAMP then
		-- This doesn't actually save to file every frame, it just updates the properties that will be saved.
		save_current_run_stats()
	end
end, ON.FRAME)

-- Leaving these variables set between resets can lead to undefined behavior due to the high likelyhood of entities being reused.
function clear_variables()
	idol = nil
	if bat_generator then
		bat_generator.on_off = false
	end
	bat_generator = nil
	bat_switch = nil
	moving_totems = {}
	totem_slots = {}
	totem_switch = nil
	last_spawn = nil
	spawned_bat = nil
	has_activated_totem = false
	dialog_block_pos_x = nil
	dialog_block_pos_y = nil
	dialog_merchant = nil
	dialog_ana = nil
	hasDisplayedDialog = false
	
	telescope = nil
	
	challenge_forcefield = nil
	challenge_waitroom = nil
	laser_switch = nil
	has_switched_forcefield = false
	sunchallenge_generators = {}
	sunchallenge_switch = nil
	has_activated_sun_challenge = false
	has_completed_sun_challenge = false
	sun_challenge_activation_time = nil
	sun_challenge_toast_shown = 0
	challenge_reward_position_x = nil
	challenge_reward_position_y = nil
	challenge_reward_layer = nil
	has_payed_for_sun_challenge = false
	sun_wait_timer = nil
	kill_tun_plz = nil
	tunx = nil
	tuny = nil
	tunlayer = nil
	
	volcana_door = nil
	volcana_sign = nil
	temple_door = nil
	temple_sign = nil
	ice_door = nil
	ice_sign = nil
	sunken_door = nil
	sunken_sign = nil
	continue_door = nil
	continue_sign = nil
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
	dead_ana_pls_kill = nil
	
	player_near_easy_sign = false
	player_near_hard_sign = false
	player_near_normal_sign = false
	player_near_hardcore_sign = false
	
	if telescope_previous_zoom then
		zoom(telescope_previous_zoom)
	end
	telescopes = {}
	telescope_activated = false 
	telescope_was_activated = nil
	telescope_activated_time = nil
	telescope_previous_zoom = nil
	
	tvs = {}
	button_prompts_hidden = false
end

set_callback(function()
	clear_variables()
end, ON.PRE_LOAD_LEVEL_FILES)

---------------------------
---- /STATE MANAGEMENT ----
---------------------------

------------------------------------
---- UPDATE LEVEL AND WIN STATE ----
------------------------------------

set_callback(function ()
	level = level + 1
	
	-- Update stats for the current difficulty mode.
	local stats = current_stats()
	local stats_hardcore = current_hardcore_stats()
	-- Update the PB if the new level has not been reached yet.
	if (not stats.best_level or level > stats.best_level) and initial_level == first_level then
		stats.best_level = level
	end
	if hardcore_enabled and (not stats_hardcore.best_level or level > stats_hardcore.best_level) and initial_level == first_level then
		stats_hardcore.best_level = level
	end
	if level >= max_level + 1 then
		if initial_level == first_level then
			-- Consider the transition to be to a "Win" state if the completed level was the final level and the 
			-- run started on the first level. This excludes shortcuts, but does not exclude continuing a run, since
			-- continuing sets the initial level to the first level.
			win = true
			stats.completions = stats.completions + 1
			completion_time = time_total
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
			
			if hardcore_enabled and (not stats_hardcore.best_time or stats_hardcore.best_time == 0 or completion_time < stats_hardcore.best_time) then
				stats_hardcore.best_time = completion_time
				completion_time_new_pb = true
				if current_difficulty ~= DIFFICULTY.EASY then
					stats_hardcore.best_time_idol_count = idols
				end
			end
			
			if idols == #levels and current_difficulty ~= DIFFICULTY.EASY then
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
	end
end, ON.TRANSITION)

set_callback(function ()
    if win and state.theme == THEME.BASE_CAMP then	
		local player_slot = state.player_inputs.player_slot_1
		-- Show the win screen until the player presses the jump button.
		if #players > 0 and test_flag(player_slot.buttons, 1) then
			win = false
			level = initial_level
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
	if (not stats.best_level or level > stats.best_level) and initial_level == first_level then
		stats.best_level = level
	end
	if hardcore_enabled and (not stats_hardcore.best_level or level > stats_hardcore.best_level) and initial_level == first_level then
		stats_hardcore.best_level = level
	end

	if hardcore_enabled then
		-- Reset the level and progress to the initial_level if reseting in hardcore mode.
		level = initial_level
		run_idols_collected = {}
		idols = 0
		attempts = 0
	end
end, ON.RESET)

-------------------------------------
---- /UPDATE LEVEL AND WIN STATE ----
-------------------------------------

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
		add_stat(f'PB: {title_of_level(stats.best_level)}')
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
		add_hardcore_stat(f'PB: {title_of_level(hardcore_stats.best_level)}')
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
--		local tw, th = ctx:draw_text_size(text, fontsize, fontsize, VANILLA_FONT_STYLE.ITALIC)
		ctx:draw_text(text, statstextx, statstexty, fontsize, fontsize, Color:black(), VANILLA_TEXT_ALIGNMENT.LEFT, VANILLA_FONT_STYLE.ITALIC)
		statstexty = statstexty + textheight - .04
	end
	for _, text in ipairs(hardcore_stat_texts) do
		local t_color = rgba(0, 0, 36, 230)
	--	local tw, th = ctx:draw_text_size(text, fontsize, fontsize, VANILLA_FONT_STYLE.ITALIC)
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
--	local stats_title_width, stats_title_height = ctx:draw_text_size(100, stats_title)
--	ctx:draw_text(-stats_title_width / 2, .75, 100, stats_title, stats_title_color)
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
	if completion_idols == max_level + 1 then
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
--		local tw, th = ctx:draw_text_size(text, fontsize, fontsize, VANILLA_FONT_STYLE.ITALIC)
		ctx:draw_text(text, statstextx, statstexty, fontsize, fontsize, Color:black(), VANILLA_TEXT_ALIGNMENT.LEFT, VANILLA_FONT_STYLE.ITALIC)
		statstexty = statstexty + textheight - .04
	end
	for _, text in ipairs(pb_stat_texts) do
		local t_color = rgba(0, 0, 36, 230)
	--	local tw, th = ctx:draw_text_size(text, fontsize, fontsize, VANILLA_FONT_STYLE.ITALIC)
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
			texts[#texts+1] = "Continue run from " .. title_of_level(saved_run.saved_run_level)
			local text = " Time: " .. format_time(saved_run.saved_run_time) .. " Deaths: " .. (saved_run.saved_run_attempts)
			if saved_run.saved_run_idol_count > 0 then
				text = text .. " Idols: " .. saved_run.saved_run_idol_count
			end
			texts[#texts+1] = text
		elseif initial_level ~= first_level then
			texts[#texts+1] = "Shortcut to " .. title_of_level(initial_level) .. " trial"
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
				texts[#texts+1] = f'PB: {title_of_level(stats_hardcore.best_level)}'
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
				texts[#texts+1] = f'PB: {title_of_level(stats.best_level)}'
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
	elseif initial_level == first_level and hardcore_enabled then
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
    elseif initial_level == first_level then
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
		texts[#texts+1] = f'Deaths: {attempts - 1}{idols_text}'
		
		local texty = -0.935
		for i = #texts,1,-1 do
			local text = texts[i]
			local tw, th = draw_text_size(28, text)
			ctx:draw_text(0 - tw / 2, texty, 28, text, text_color)
			texty = texty - th
		end
	else
		local text = f'{title_of_level(initial_level)} shortcut practice'
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
			normal_stats.best_level = load_data.best_level
			normal_stats.completions = load_data.completions or 0
			normal_stats.max_idol_completions = load_data.max_idol_completions or 0
			normal_stats.max_idol_best_time = load_data.max_idol_best_time or 0
			normal_stats.deathless_completions = load_data.deathless_completions or 0
			normal_stats.least_deaths_completion = load_data.least_deaths_completion
			normal_stats.least_deaths_completion_time = load_data.least_deaths_completion_time
		elseif load_version == '1.3' then
			if load_data.stats then
				legacy_normal_stats = load_data.stats
				if legacy_normal_stats.best_level == ICE_LEVEL then
					legacy_normal_stats.best_level = SUNKEN_LEVEL
				end 
			end
			if load_data.easy_stats then
				legacy_easy_stats = load_data.easy_stats
				if legacy_easy_stats.best_level == ICE_LEVEL then
					legacy_easy_stats.best_level = SUNKEN_LEVEL
				end 
			end
			if load_data.hard_stats then
				legacy_hard_stats = load_data.hard_stats
				if legacy_hard_stats.best_level == ICE_LEVEL then
					legacy_hard_stats.best_level = SUNKEN_LEVEL
				end 
			end
			if load_data.hardcore_stats then
				legacy_hardcore_stats = load_data.hardcore_stats
				if legacy_hardcore_stats.best_level == ICE_LEVEL then
					legacy_hardcore_stats.best_level = SUNKEN_LEVEL
				end 
			end
			if load_data.hardcore_stats_easy then
				legacy_hardcore_stats_easy = load_data.hardcore_stats_easy
				if legacy_hardcore_stats_easy.best_level == ICE_LEVEL then
					legacy_hardcore_stats_easy.best_level = SUNKEN_LEVEL
				end 
			end
			if load_data.hardcore_stats_hard then
				legacy_hardcore_stats_hard = load_data.hardcore_stats_hard
				if legacy_hardcore_stats_hard.best_level == ICE_LEVEL then
					legacy_hardcore_stats_hard.best_level = SUNKEN_LEVEL
				end 
			end
		else
			if load_data.stats then
				normal_stats = load_data.stats
			end
			if load_data.easy_stats then
				easy_stats = load_data.easy_stats
			end
			if load_data.hard_stats then
				hard_stats = load_data.hard_stats
			end
			if load_data.legacy_stats then
				legacy_normal_stats = load_data.legacy_stats
			end
			if load_data.legacy_easy_stats then
				legacy_easy_stats = load_data.legacy_easy_stats
			end
			if load_data.legacy_hard_stats then
				legacy_hard_stats = load_data.legacy_hard_stats
			end
			
			
			if load_data.hardcore_stats then
				hardcore_stats = load_data.hardcore_stats
			end
			if load_data.hardcore_stats_easy then
				hardcore_stats_easy = load_data.hardcore_stats_easy
			end
			if load_data.hardcore_stats_hard then
				hardcore_stats_hard = load_data.hardcore_stats_hard
			end
			
			if load_data.legacy_hardcore_stats then
				legacy_hardcore_stats = load_data.legacy_hardcore_stats
			end
			if load_data.legacy_hardcore_stats_easy then
				legacy_hardcore_stats_easy = load_data.legacy_hardcore_stats_easy
			end
			if load_data.legacy_hardcore_stats_hard then
				legacy_hardcore_stats_hard = load_data.legacy_hardcore_stats_hard
			end
		end
		local idol_levels = load_data.idol_levels
		local saved_idols_collected = {}
		if idol_levels.dwelling then
			saved_idols_collected[DWELLING_LEVEL] = true
		end
		if idol_levels.volcana then
			saved_idols_collected[VOLCANA_LEVEL] = true
		end
		if idol_levels.temple then
			saved_idols_collected[TEMPLE_LEVEL] = true
		end
		if idol_levels.ice then
			saved_idols_collected[ICE_LEVEL] = true
		end
		if idol_levels.sunken then
			saved_idols_collected[SUNKEN_LEVEL] = true
		end
		idols_collected = saved_idols_collected
		total_idols = load_data.total_idols
		hardcore_enabled = load_data.hardcore_enabled
		hardcore_previously_enabled = load_data.hpe
		
		function load_saved_run_data(saved_run, saved_run_data)
			saved_run.has_saved_run = saved_run_data.has_saved_run or not load_version
			saved_run.saved_run_level = saved_run_data.level
			saved_run.saved_run_attempts = saved_run_data.attempts
			saved_run.saved_run_idol_count = saved_run_data.idols
			saved_run.saved_run_time = saved_run_data.run_time
			local saved_idol_levels = {}
			local saved_data_idol_levels = saved_run_data.idol_levels
			if saved_data_idol_levels.dwelling then
				saved_idol_levels[DWELLING_LEVEL] = true
			end
			if saved_data_idol_levels.volcana then
				saved_idol_levels[VOLCANA_LEVEL] = true
			end
			if saved_data_idol_levels.temple then
				saved_idol_levels[TEMPLE_LEVEL] = true
			end
			if saved_data_idol_levels.ice then
				saved_idol_levels[ICE_LEVEL] = true
			end
			if saved_data_idol_levels.sunken then
				saved_idol_levels[SUNKEN_LEVEL] = true
			end
			saved_run.saved_run_idols_collected = saved_idol_levels
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
	local idol_levels = {
		dwelling = idols_collected[DWELLING_LEVEL],
		volcana = idols_collected[VOLCANA_LEVEL],
		temple = idols_collected[TEMPLE_LEVEL],
		ice = idols_collected[ICE_LEVEL],
		sunken = idols_collected[SUNKEN_LEVEL],
	}
	
	function saved_run_datar(saved_run)
		if not saved_run then return nil end
		local saved_run_idol_levels = {
			dwelling = saved_run.saved_run_idols_collected[DWELLING_LEVEL],
			volcana = saved_run.saved_run_idols_collected[VOLCANA_LEVEL],
			temple = saved_run.saved_run_idols_collected[TEMPLE_LEVEL],
			ice = saved_run.saved_run_idols_collected[ICE_LEVEL],
			sunken = saved_run.saved_run_idols_collected[SUNKEN_LEVEL],
		}
		local saved_run_data = {
			has_saved_run = saved_run.has_saved_run,
			level = saved_run.saved_run_level,
			attempts = saved_run.saved_run_attempts,
			idols = saved_run.saved_run_idol_count,
			idol_levels = saved_run_idol_levels,
			run_time = saved_run.saved_run_time,
		}
		return saved_run_data
	end
	local normal_saved_run_data = saved_run_datar(normal_saved_run)
	local easy_saved_run_data = saved_run_datar(easy_saved_run)
	local hard_saved_run_data = saved_run_datar(hard_saved_run)
    local save_data = {
		version = '1.5',
		idol_levels = idol_levels,
		total_idols = total_idols,
		saved_run_data = normal_saved_run_data,
		easy_saved_run = easy_saved_run_data,
		hard_saved_run = hard_saved_run_data,
		stats = normal_stats,
		easy_stats = easy_stats,
		hard_stats = hard_stats,
		legacy_stats = legacy_normal_stats,
		legacy_easy_stats = legacy_easy_stats,
		legacy_hard_stats = legacy_hard_stats,
		has_seen_ana_dead = has_seen_ana_dead,
		hardcore_enabled = hardcore_enabled,
		difficulty = current_difficulty,
		hpe = hardcore_previously_enabled,
		hardcore_stats = hardcore_stats,
		hardcore_stats_easy = hardcore_stats_easy,
		hardcore_stats_hard = hardcore_stats_hard,
		legacy_hardcore_stats = legacy_hardcore_stats,
		legacy_hardcore_stats_easy = legacy_hardcore_stats_easy,
		legacy_hardcore_stats_hard = legacy_hardcore_stats_hard,
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
