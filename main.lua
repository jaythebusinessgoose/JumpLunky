meta.name = 'Jumplunky'
meta.version = '1'
meta.description = 'Challenging platforming puzzles'
meta.author = 'JayTheBusinessGoose'

local DWELLING_LEVEL <const> = 0
local VOLCANA_LEVEL <const> = 1
local TEMPLE_LEVEL <const> = 2
local SUNKEN_LEVEL <const> = 3

first_level = DWELLING_LEVEL
initial_level = first_level
max_level = SUNKEN_LEVEL
level = initial_level
continuing_run = false
local save_context

initial_bombs = 0
initial_ropes = 0

-- overall state
local time_total = 0
completion_time = 0
completion_time_new_pb = false
completion_deaths = 0
completion_deaths_new_pb = false
completion_idols = 0
best_time = 0
best_time_idol_count = 0
best_time_death_count = 0
least_deaths_completion = nil
least_deaths_completion_time = 0
max_idol_completions = 0
max_idol_best_time = 0
deathless_completions = 0
best_level = nil
completions = 0
total_idols = 0
idols_collected = {}

has_seen_ana_dead = false

-- current run state
attempts = 0
idols = 0
run_idols_collected = {}

-- saved run state
has_saved_run = false
saved_run_attempts = nil
saved_run_time = nil
saved_run_level = nil
saved_run_idol_count = nil
saved_run_idols_collected = nil

local win = false
local has_seen_base_camp = false

--------------
---- CAMP ----
--------------

local volcana_door
local temple_door
local sunken_door
local volcana_sign
local temple_sign
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
	elseif level == SUNKEN_LEVEL then
		return "Sunken City"
	end
	return "Unknown level: " .. level
end

set_callback(function ()
	-- Effectively disables the "continue run" door if there is no saved progress to continue from.
	if not has_saved_run and continue_door then
		local x, y, layer = get_position(continue_door)
		local doors = get_entities_at(0, 0, x, y, layer, 1)
		for i=1,#doors do
			local door = get_entity(doors[i])
			door.flags = clr_flag(door.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
		end
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
	
	-- Replace the texture of the three shortcut doors and the continue door with the theme they lead to.
	if continue_door then
		local x, y, layer = get_position(continue_door)
		texture_door_at(x, y, layer, saved_run_level)
	end
	if volcana_door then
		local x, y, layer = get_position(volcana_door)
		texture_door_at(x, y, layer, VOLCANA_LEVEL)
	end
	if temple_door then
		local x, y, layer = get_position(temple_door)
		texture_door_at(x, y, layer, TEMPLE_LEVEL)
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
	spawn_camp_idol_for_level(VOLCANA_LEVEL, x + 2, y, layer)
	return true
end, "volcana_shortcut")

-- Creates a "room" for the Temple shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("temple_shortcut")
set_pre_tile_code_callback(function(x, y, layer)
	temple_door = spawn_door(x + 1, y, layer, world_for_level(TEMPLE_LEVEL), level_for_level(TEMPLE_LEVEL), theme_for_level(TEMPLE_LEVEL))
	temple_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 3, y, layer, 0, 0)
	local sign = get_entity(temple_sign)
	sign.flags = clr_flag(sign.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	spawn_camp_idol_for_level(TEMPLE_LEVEL, x + 2, y, layer)
	return true
end, "temple_shortcut")

-- Creates a "room" for the Sunken City shortcut, with a door, a sign, and an idol if it has been collected.
define_tile_code("sunken_shortcut")
set_pre_tile_code_callback(function(x, y, layer)
	sunken_door = spawn_door(x - 1, y, layer, world_for_level(SUNKEN_LEVEL), level_for_level(SUNKEN_LEVEL), theme_for_level(SUNKEN_LEVEL))
	sunken_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x - 3, y, layer, 0, 0)
	local sign = get_entity(sunken_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	sign.flags = clr_flag(sign.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
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
	continue_door = spawn_door(x + 1, y, layer, world_for_level(saved_run_level), level_for_level(saved_run_level), theme_for_level(saved_run_level))
	continue_sign = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x + 3, y, layer, 0, 0)
	local sign = get_entity(continue_sign)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	sign.flags = clr_flag(sign.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	return true
end, "continue_run")

-- Spawns an idol if collected from the dwelling level, since there is no Dwelling shortcut.
define_tile_code("dwelling_idol")
set_pre_tile_code_callback(function(x, y, layer)
	spawn_camp_idol_for_level(DWELLING_LEVEL, x, y, layer)
	return true
end, "dwelling_idol")

local button_was_pressed = false
set_callback(function()
	if state.theme ~= THEME.BASE_CAMP then return end
	if #players < 1 then return end
	local player = players[1]
	
	-- Show a toast when pressing the door button on the signs near shortcut doors and continue door.
	if player:is_button_pressed(BUTTON.DOOR) then
		button_was_pressed = true
		
		if volcana_sign and distance(player.uid, volcana_sign) <= 1 then
			toast("Shortcut to Volcana trial")
		elseif temple_sign and distance(player.uid, temple_sign) <= 1 then
			toast("Shortcut to Temple trial")
		elseif sunken_sign and distance(player.uid, sunken_sign) <= 1 then
			toast("Shortcut to Sunken City trial")
		elseif continue_sign and distance(player.uid, continue_sign) <= 1 then
			if has_saved_run then
				toast("Continue run from " .. title_of_level(saved_run_level))
			else
				toast("No run to continue")
			end
		elseif continue_door and not has_saved_run and distance(player.uid, continue_door) <= 1 then
			toast("No run to continue")
		end
	else
		button_was_pressed = false
	end
	
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
	elseif (sunken_door and distance(players[1].uid, sunken_door) <= 1) or (sunken_sign and distance(player.uid, sunken_sign) <= 1) then
		initial_level = SUNKEN_LEVEL
		level = initial_level
	elseif has_saved_run and ((continue_door and distance(players[1].uid, continue_door) <= 1) or (continue_sign and distance(player.uid, continue_sign) <= 1)) then
		initial_level = first_level
		level = saved_run_level
		continuing_run = true
		attempts = saved_run_attempts
		time_total = saved_run_time
		idols = saved_run_idol_count
		run_idols_collected = saved_run_idols_collected
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
	state.level_gen.shop_type = SHOP_TYPE.DICE_SHOP
	-- Add buffer templates so that we can replace generated rooms with a room full of floor.
	ctx:add_level_files { 'buffer.lvl' }
	
	-- Most level types do not allow generation via setroom. For this reason, we add our level file
	-- instead of replacing the existing level files with it. Our level generation will run after
	-- the level has already been generated and will simply increase the size of the level to add our
	-- rooms and also fill in the existing rooms.
    if level == DWELLING_LEVEL then
		ctx:add_level_files { 'dwell.lvl' }
	elseif level == VOLCANA_LEVEL then
       ctx:add_level_files { 'volc.lvl' }
	elseif level == TEMPLE_LEVEL then
       ctx:add_level_files { 'temp.lvl' }
	elseif level == SUNKEN_LEVEL then
		ctx:add_level_files { 'sunk.lvl' }
    end
end, ON.PRE_LOAD_LEVEL_FILES)

-- Create a bunch of room templates that can be used in lvl files to create rooms. To create a level
-- larger than 4x5, these must be increased to create more templates. 
local room_templates = {}
for x = 0, 3 do
	local room_templates_x = {}
	for y = 0, 4 do
		local room_template = define_room_template("setroom" .. y .. "_" .. x, ROOM_TEMPLATE_TYPE.NONE)
		room_templates_x[y] = room_template
	end
	room_templates[x] = room_templates_x
end
local buffer_template = define_room_template("buffer", ROOM_TEMPLATE_TYPE.NONE)
local buffer_special_template = define_room_template("buffer_special", ROOM_TEMPLATE_TYPE.NONE)

-- Returns size of the level in width, height.
function size_of_level(level)
	if level == TEMPLE_LEVEL then
		return 4, 5
	else
		return 4, 4
	end
end

-- Returns how many subrooms down to begin the actual level in x, y. Returning an x offset other than 0 isn't really
-- fully supported, so could have some undefined results.
function level_offset(level)
	return 0, 4
end

-- Returns the template that will be used to replace the rooms in the generated level.
function buffer_template_for_level(level, layer)
	return buffer_template
end

-- This doesn't actually create a shop template anymore, but it is used for swapping the backlayer door
-- for a shop-themed door.
function is_shop_template_for_level_at(level, x, y)
	if level == SUNKEN_LEVEL then
		if x == 1 and y == 2 then
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
	for x = 0, width - 1 do
		for y = 0, height - 1 do
			ctx:set_room_template(x + offsetX, y + offsetY, LAYER.BACK, buffer_template)
			ctx:set_room_template(x + offsetX, y + offsetY, LAYER.FRONT, room_templates[x][y])
       	end
		for y = 1, offsetY - 1 do
			ctx:set_room_template(x, y , LAYER.BACK, buffer_template)
			ctx:set_room_template(x, y, LAYER.FRONT, buffer_template)
		end
	end
end, ON.POST_ROOM_GENERATION)

---------------------------
---- /LEVEL GENERATION ----
---------------------------

-------------------
---- TELESCOPE ----
-------------------

local telescope
define_tile_code("telescope")
set_pre_tile_code_callback(function(x, y, layer)
	telescope = spawn_entity(ENT_TYPE.ITEM_TELESCOPE, x, y, layer, 0, 0)
	local telescope_entity = get_entity(telescope)
	-- Disable the telescope's default interaction because it interferes with the zooming and panning we want to do
	-- when interacting with the telescope.
	telescope_entity.flags = clr_flag(telescope_entity.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	-- Turn the telescope to the right since we start on the left side of every level. Should not call this
	-- line in levels that start on the right side.
	telescope_entity.flags = clr_flag(telescope_entity.flags, ENT_FLAG.FACING_LEFT)
	return true
end, "telescope")

local telescope_activated = false 
local telescope_was_activated = nil
local telescope_previous_zoom = nil
set_callback(function() 
	if #players < 1 or not telescope then return end
	if state.theme == THEME.BASE_CAMP then return end 
	
	local player = players[1]
	if distance(player.uid, telescope) <= 1 and player:is_button_pressed(BUTTON.DOOR) then
		-- Begin telescope interaction when the door button is pressed within a tile of the telescope.
		telescope_activated = true
		telescope_was_activated = true
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
		
	end
	if telescope_activated then
		-- Gets a bitwise integer that contains the set of pressed buttons while the input is stolen.
		local buttons = read_stolen_input(player.uid)
		-- 3 = bomb
		if test_flag(buttons, 3) then
			telescope_activated = false
			-- Keep track of the time that the telescope was deactivated. This will allow us to enable the player's
			-- inputs later so that the same input isn't recognized again to cause a bomb to be thrown or another action.
			telescope_was_activated = state.time_level 
			-- Zoom back to the original zoom level.
			zoom(telescope_previous_zoom)
			-- Make the camera follow the player again.
			state.camera.focused_entity_uid = player.uid
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
	if run_idols_collected[level] then
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
			sound = get_sound(VANILLA_SOUND.UI_SECRET)
			if sound then
				sound:play()
			end
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

-- Add shop backlayer tiles to the room so it looks more like an actual challenge.
set_post_entity_spawn(function (entity)
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
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.MONS_MERCHANT)

set_post_entity_spawn(function (entity)
	if level == SUNKEN_LEVEL then
		-- Kill Tun when she spawns.
		entity.health = 0
		entity.flags = set_flag(entity.flags, ENT_FLAG.FACING_LEFT)
		entity.flags = clr_flag(entity.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
	end
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.MONS_MERCHANT)
----- here
set_pre_tile_code_callback(function(x, y, layer)
	-- Spawn a non-loaded HouYi Bow.
	spawn_entity(ENT_TYPE.ITEM_HOUYIBOW, x, y, layer, 0, 0)
	return true
end, "houyibow")

define_tile_code("ana_spelunky")
set_pre_tile_code_callback(function(x, y, layer)
	local ana_uid = spawn_entity(ENT_TYPE.CHAR_ANA_SPELUNKY, x, y, layer, 0, 0)
	local ana = get_entity(ana_uid)
	-- We must kill Ana too, otherwise we can't get the bow she brought to the challenge room. :(
	ana.health = 0
	return true
end, "ana_spelunky")

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

local has_activated_sun_challenge = false
local sun_challenge_activation_time
local has_completed_sun_challenge = false
local sun_challenge_toast_shown = 0
set_callback(function ()
	if level == SUNKEN_LEVEL then
		if has_activated_sun_challenge and not has_completed_sun_challenge then
			-- This means the player is currently participating in the challenge or waiting for it to begin.
			
			-- The number of frames since the challenge was started.
			local time_waiting = state.time_level - sun_challenge_activation_time
			
			-- This allows us to kill all of the spanws when the challenge is completed or the player dies.
			function clear_sun_challenge_spawns()
				local sun_challenge_spawns = get_entities_by_type({ENT_TYPE.MONS_SORCERESS, ENT_TYPE.MONS_VAMPIRE, ENT_TYPE.MONS_WITCHDOCTOR, ENT_TYPE.MONS_NECROMANCER, ENT_TYPE.MONS_REDSKELETON })
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
			
			-- Turns on all generators that are within 8 tiles of the player. For some reason these generators are spawning enemies
			-- with a greater range than real sun challenges. Turns all other generators off.
			function activate_generators()
				for i = 1, #sunchallenge_generators do
					local generator = sunchallenge_generators[i]
					local generatorX, generatorY = get_position(generator.uid)
					local playerX, playerY = get_position(players[1].uid)
					generator.on_off = (math.abs(playerX - generatorX) < 8 and math.abs(playerY - generatorY) < 8)
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
					toast("Survive!")
					sun_challenge_toast_shown = 4
					activate_generators()
				end
			elseif sun_challenge_toast_shown == 4 then
				-- Call activate_generators() every frame so that the correct ones turn on if the player moves into or out of range.
				activate_generators()
				if time_waiting > 240 + 25 * 60 then
					toast("5 seconds remaining!")
					sun_challenge_toast_shown = 5
				end
			elseif sun_challenge_toast_shown == 5 then
				if time_waiting > 240 + 30 * 60 then
					toast("You've won!")
					deactivate_generators()
					clear_sun_challenge_spawns()
					challenge_waitroom:activate_laserbeam(false)
					sun_challenge_toast_shown = 6
					has_completed_sun_challenge = true
					if challenge_reward_position_x then
						spawn_idol(challenge_reward_position_x, challenge_reward_position_y, challenge_reward_layer)
					end
				else
					activate_generators()
				end
			end
		elseif not has_activated_sun_challenge then
			if sunchallenge_switch.timer > 0 then
				has_activated_sun_challenge = true
				sun_challenge_activation_time = state.time_level
				challenge_waitroom:activate_laserbeam(true)
				
				-- TODO: Figure out how to play the music.
			end
		end
	end
end, ON.FRAME)

set_post_entity_spawn(function (entity)
	if level == SUNKEN_LEVEL then
		entity.flags = set_flag(entity.flags, ENT_FLAG.INVISIBLE)
		move_entity(entity.uid, 1000, 0, 0, 0)
	end
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.MONS_BAT, ENT_TYPE.MONS_TADPOLE, ENT_TYPE.ITEM_COFFIN)

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
			
			sound = get_sound(VANILLA_SOUND.UI_SECRET)
			if sound then
				sound:play()
			end
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
		entity.flags = set_flag(entity.flags, ENT_FLAG.INVISIBLE)
		move_entity(entity.uid, 1000, 0, 0, 0)
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

-- A character (Ana) that will be spoken to when walking near.
local dialog_ana
set_post_entity_spawn(function (entity)
	if level == SUNKEN_LEVEL and not dialog_ana then
		dialog_ana = entity
	end
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.CHAR_ANA_SPELUNKY)

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
   entity.flags = set_flag(entity.flags, ENT_FLAG.INVISIBLE)
   move_entity(entity.uid, 1000, 0, 0, 0)
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.ITEM_TORCH, ENT_TYPE.MONS_PET_DOG, ENT_TYPE.EMBED_GOLD, ENT_TYPE.EMBED_GOLD_BIG, ENT_TYPE.ITEM_POT, ENT_TYPE.ITEM_NUGGET, ENT_TYPE.ITEM_NUGGET_SMALL, ENT_TYPE.ITEM_SKULL, ENT_TYPE.ITEM_CHEST, ENT_TYPE.ITEM_CRATE, ENT_TYPE.MONS_PET_CAT, ENT_TYPE.MONS_PET_HAMSTER, ENT_TYPE.ITEM_ROCK, ENT_TYPE.ITEM_RUBY, ENT_TYPE.ITEM_SAPPHIRE, ENT_TYPE.ITEM_EMERALD, ENT_TYPE.ITEM_WALLTORCH, ENT_TYPE.MONS_SCARAB, ENT_TYPE.ITEM_AUTOWALLTORCH, ENT_TYPE.ITEM_WEB, ENT_TYPE.ITEM_GOLDBAR, ENT_TYPE.ITEM_GOLDBARS, ENT_TYPE.MONS_SKELETON, ENT_TYPE.ITEM_CURSEDPOT, ENT_TYPE.MONS_CRITTERDUNGBEETLE, ENT_TYPE.MONS_CRITTERBUTTERFLY, ENT_TYPE.MONS_CRITTERSNAIL, ENT_TYPE.MONS_CRITTERFISH, ENT_TYPE.MONS_CRITTERANCHOVY, ENT_TYPE.MONS_CRITTERCRAB, ENT_TYPE.MONS_CRITTERLOCUST, ENT_TYPE.MONS_CRITTERPENGUIN, ENT_TYPE.MONS_CRITTERFIREFLY, ENT_TYPE.MONS_CRITTERDRONE, ENT_TYPE.MONS_CRITTERSLIME)

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
		time_total = state.time_total
		
		save_current_run_stats()
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
	elseif level == SUNKEN_LEVEL then
		return 7
	end
	return 1
end

set_callback(function ()
	if #players == 0 then return end

	players[1].inventory.bombs = initial_bombs
	players[1].inventory.ropes = initial_ropes
	if players[1]:get_name() == "Roffy D. Sloth" then
		players[1].health = 1
	else
		players[1].health = 2
	end
	
	-- This doesn't affect anything except what is displayed in the UI. When we have more than one level
	-- per theme, we can use more complicated logic to determine what do display.
	state.world = level + 1
	state.level = 1
	
	-- Settting the _start properties of the state will ensure that Instant Restarts will take the player back to the
	-- current level, instead of going to the starting level.
	state.world_start = world_for_level(level)
	state.theme_start = theme_for_level(level)
	state.level_start = level_for_level(level)

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
	if initial_level == first_level and state.theme ~= THEME.BASE_CAMP and started then
		saved_run_attempts = attempts
		saved_run_idol_count = idols
		saved_run_level = level
		saved_run_time = time_total
		saved_run_idols_collected = run_idols_collected
		has_saved_run = true
		
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
	
	volcana_door = nil
	volcana_sign = nil
	temple_door = nil
	temple_sign = nil
	sunken_door = nil
	sunken_sign = nil
	continue_door = nil
	continue_sign = nil
	
	if telescope_previous_zoom then
		zoom(telescope_previous_zoom)
	end
	telescope = nil
	telescope_activated = false 
	telescope_was_activated = -1
	telescope_previous_zoom = nil
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
	-- Update the PB if the new level has not been reached yet.
	if (not best_level or level > best_level) and initial_level == first_level then
		best_level = level
	end
	if level >= max_level + 1 then
		if initial_level == first_level then
			-- Consider the transition to be to a "Win" state if the completed level was the final level and the 
			-- run started on the first level. This excludes shortcuts, but does not exclude continuing a run, since
			-- continuing sets the initial level to the first level.
			win = true
			completions = completions + 1
			completion_time = time_total
			completion_deaths = attempts - 1
			completion_idols = idols
			
			has_saved_run = false
			saved_run_attempts = nil
			saved_run_idol_count = nil
			saved_run_idols_collected = nil
			saved_run_level = nil
			saved_run_time = nil

			if not best_time or best_time == 0 or completion_time < best_time then
				best_time = completion_time
				completion_time_new_pb = true
				best_time_idol_count = idols
				best_time_death_count = attempts - 1
			else
				completion_time_new_pb = false
			end
			
			if idols == max_level + 1 then
				max_idol_completions = max_idol_completions + 1
				if not max_idol_best_time or max_idol_best_time == 0 or completion_time < max_idol_best_time then
					max_idol_best_time = completion_time
				end
			end
			
			if not least_deaths_completion or completion_deaths < least_deaths_completion or (completion_deaths == least_deaths_completion and completion_time < least_deaths_completion_time) then
				if not least_deaths_completion or completion_deaths < least_deaths_completion then
					completion_deaths_new_pb = true
				end
				least_deaths_completion = completion_deaths
				least_deaths_completion_time = completion_time
				if attempts == 1 then
					deathless_completions = deathless_completions + 1
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
	if (not best_level or level > best_level) and initial_level == first_level then
		best_level = level
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
    local seconds_text = seconds < 10 and '0' or ''
    local minutes_text = minutes < 10 and '0' or ''

    return minutes_text .. tostring(minutes) .. ':' .. seconds_text .. tostring(seconds % 60)
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

local image, imagewidth, imageheight = create_image('jpt.png')
set_callback(function (ctx)
    local text_color = rgba(255, 255, 255, 195)
    local w = 1.3
    local h = 1.3
    local x = 0
    local y = 0
	if not has_seen_base_camp then return end
	
    if win then
		-- Draw a black screen to cover the game.
        ctx:draw_rect_filled(-1, 1, 1, -1, 0, rgba(0, 0, 0, 255))
		
		-- Draw a journal page that the text will be rendered on top of.
		ctx:draw_image_rotated(image, x - w / 2, y + h / 2, x+w/2, y-h/2, 0, 0, 1, 1, 0xffffffff, -math.pi/2, 0, 0)
		local texts = {}
		texts[#texts+1] = 'Congratulations!'
		texts[#texts+1] = ''
		if completion_deaths_new_pb or completion_time_new_pb then
			texts[#texts+1] = 'New PB!!'
		end
		texts[#texts+1] = f'Time: {format_time(completion_time)}'
		texts[#texts+1] = f'Deaths: {completion_deaths}'
		local all_idols_text = ""
		if completion_idols == max_level + 1 then
			all_idols_text = " (All Idols!)"
		end
		if completion_idols > 0 then
			texts[#texts+1] = f'Idols: {completion_idols}{all_idols_text}'
		end
		texts[#texts+1] = ''
		texts[#texts+1] = ''
		texts[#texts+1] = 'PBs:'
		local time_pb_text = ''
		if completion_time_new_pb then
			time_pb_text = ' (New PB!)'
		end
		local deaths_pb_text = ''
		if completion_deaths_new_pb then
			deaths_pb_text = ' (New PB!)'
		end
		texts[#texts+1] = f'Fastest time: {format_time(best_time)}{time_pb_text}'
		texts[#texts+1] = f'Least deaths: {least_deaths_completion}{deaths_pb_text}'
		if max_idol_best_time and max_idol_best_time > 0 then
			texts[#texts+1] = f'Fastest all idols: {format_time(max_idol_best_time)}'
		end
		if deathless_completions and deathless_completions > 0 and least_deaths_completion_time and least_deaths_completion_time > 0 then
			texts[#texts+1] = f'Fastest deathless: {format_time(least_deaths_completion_time)}'
		end
		texts[#texts+1] = ''
		texts[#texts+1] = f'Completions: {completions}'
		if deathless_completions and deathless_completions > 0 then
			texts[#texts+1] = f'Deathless completions: {deathless_completions}'
		end
		if max_idol_completions and max_idol_completions > 0 then
			texts[#texts+1] = f'All idol completions: {max_idol_completions}'
		end
		
		local texty = .79
		for i = 1,#texts do
			local t_color = rgba(0, 0, 36, 230)
			local text = texts[i]
			local tw, th = draw_text_size(85, text)
			ctx:draw_text(-.285, texty, 85, text, t_color)
			texty = texty + th
		end
	elseif state.theme == THEME.BASE_CAMP then
		local text
		local top_text
		if continuing_run then
			top_text = "Continue run from " .. title_of_level(saved_run_level)
			text = " Time: " .. format_time(saved_run_time) .. " Deaths: " .. (saved_run_attempts)
			if saved_run_idol_count > 0 then
				text = text .. " Idols: " .. saved_run_idol_count
			end
		elseif initial_level ~= first_level then
			text = "Shortcut to " .. title_of_level(initial_level) .. " trial"
		else
			if completions > 0 then
				idol_text = ""
				if best_time_idol_count == 1 then
					idol_text = f' (1 idol)'
				elseif best_time_idol_count > 1 then
					idol_text = f' ({best_time_idol_count} idols)'
				end
				completionist_text = ""
				if max_idol_completions > 0 then
				--	completionist_text = f' All idols wins: {max_idol_completions} PB: {format_time(max_idol_best_time)}'
				end
				text = f'Wins: {completions}  PB: {format_time(best_time)}{idol_text}{completionist_text}'
			elseif best_level then
				text = f'PB: {title_of_level(best_level)}'
			else
				text = "PB: N/A"
			end
		end
        local tw, th = draw_text_size(28, text)
		ctx:draw_text(0 - tw / 2, -0.935, 28, text, text_color)
		
		if top_text then
			local topw, _ = draw_text_size(28, top_text)
			ctx:draw_text(0 - topw / 2, -0.935 - th, 28, top_text, text_color)
		end
		return
		
    elseif initial_level == first_level then
		local pb_text
		local wins_text = ""
		local idols_text = ""
		if completions > 0 and format_time(best_time) then
			local best_idol_text = ""
			if best_time_idol_count == 1 then
				best_idol_text = f' (1 idol)'
			elseif best_time_idol_count > 1 then
				best_idol_text = f' ({best_time_idol_count} idols)'
			end
			pb_text = f'{format_time(best_time)}{best_idol_text}'
			wins_text = f'Wins: {completions}  '
		elseif best_level then
			pb_text = title_of_level(best_level)
		else
			pb_text = 'N/A'
		end
		if idols > 0 then
			idols_text = f'     Idols: {idols}'
		end
		local text = f'Deaths: {attempts - 1}{idols_text}'
		local win_message = f'{wins_text}PB:  {pb_text}'
		local message_offset = 0
		if max_idol_completions > 0 then
			local completionist_text = f'All idol wins: {max_idol_completions} PB: {format_time(max_idol_best_time)}'
			local wg, hg = draw_text_size(28, completionist_text)
			ctx:draw_text(0 - wg / 2, -0.935, 28, completionist_text, text_color)
			message_offset = hg
		end
        local tw, _ = draw_text_size(28, text)
		local ww, wh = draw_text_size(28, win_message)
        ctx:draw_text(0 - tw / 2, -0.935 - wh - message_offset, 28, text, text_color)
		ctx:draw_text(0 - ww / 2, -0.935 - message_offset, 28, win_message, text_color)
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
        attempts = load_data.attempts
        best_time = load_data.best_time
		best_time_idol_count = load_data.best_time_idols
		best_time_death_count = load_data.best_time_death_count
		best_level = load_data.best_level
        completions = load_data.completions
		max_idol_completions = load_data.max_idol_completions or 0
		max_idol_best_time = load_data.max_idol_best_time or 0
		deathless_completions = load_data.deathless_completions or 0
		least_deaths_completion = load_data.least_deaths_completion
		least_deaths_completion_time = load_data.least_deaths_completion_time
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
		if idol_levels.sunken then
			saved_idols_collected[SUNKEN_LEVEL] = true
		end
		idols_collected = saved_idols_collected
		total_idols = load_data.total_idols
		
		local saved_run_data = load_data.saved_run_data
		if saved_run_data then
			has_saved_run = true
			saved_run_level = saved_run_data.level
			saved_run_attempts = saved_run_data.attempts
			saved_run_idol_count = saved_run_data.idols
			saved_run_time = saved_run_data.run_time
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
			if saved_data_idol_levels.sunken then
				saved_idol_levels[SUNKEN_LEVEL] = true
			end
			saved_run_idols_collected = saved_idol_levels
		end
		has_seen_ana_dead = load_data.has_seen_ana_dead
    end
end, ON.LOAD)

function force_save(ctx)
	local idol_levels = {
		dwelling = idols_collected[DWELLING_LEVEL],
		volcana = idols_collected[VOLCANA_LEVEL],
		temple = idols_collected[TEMPLE_LEVEL],
		sunken = idols_collected[SUNKEN_LEVEL],
	}
	local saved_run_data = nil
	if has_saved_run then
		local saved_run_idol_levels = {
			dwelling = saved_run_idols_collected[DWELLING_LEVEL],
			volcana = saved_run_idols_collected[VOLCANA_LEVEL],
			temple = saved_run_idols_collected[TEMPLE_LEVEL],
			sunken = saved_run_idols_collected[SUNKEN_LEVEL],
		}
		saved_run_data = {
			level = saved_run_level,
			attempts = saved_run_attempts,
			idols = saved_run_idol_count,
			idol_levels = saved_run_idol_levels,
			run_time = saved_run_time,
		}
	end
    local save_data = {
        attempts = attempts,
        best_time = best_time,
		best_time_idols = best_time_idol_count,
		best_time_death_count = best_time_death_count,
		best_level = best_level,
        completions = completions,
		max_idol_completions = max_idol_completions,
		deathless_completions = deathless_completions,
		max_idol_best_time = max_idol_best_time,
		least_deaths_completion = least_deaths_completion,
		least_deaths_completion_time = least_deaths_completion_time,
		idol_levels = idol_levels,
		total_idols = total_idols,
		saved_run_data = saved_run_data,
		has_seen_ana_dead = has_seen_ana_dead,
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
