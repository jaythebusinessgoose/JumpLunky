local idols = require('idols')
local sound = require('play_sound')
require('difficulty')

define_tile_code("firefrog")
define_tile_code("laser_switch")
define_tile_code("challenge_forcefield_switchable")
define_tile_code("challenge_waitroom_switchable")
define_tile_code("ana_spelunky")
define_tile_code("challenge_reward")
define_tile_code("sunchallenge_generator")
define_tile_code("kali_statue")

local sunken_city = {
    theme = THEME.SUNKEN_CITY,
    width = 4,
    height = 4,
}

local level_state = {
    loaded = false,
    callbacks = {},
}

local overall_state = {
    idol_collected = false,
    run_idol_collected = false,
    difficulty = nil,
    seen_ana_callback = nil,
}

sunken_city.set_idol_collected = function(collected)
    overall_state.idol_collected = collected
end

sunken_city.set_run_idol_collected = function(collected)
    overall_state.run_idol_collected = collected
end

sunken_city.set_difficulty = function(difficulty)
    overall_state.difficulty = difficulty
end

sunken_city.set_ana_callback = function(callback)
    overall_state.seen_ana_callback = callback
end

sunken_city.load_level = function()
    if level_state.loaded then return end
    level_state.loaded = true

    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        spawn_entity(ENT_TYPE.MONS_FIREFROG, x, y, layer, 0, 0)
        return true
    end, "firefrog")

    local challenge_forcefield
    local challenge_waitroom
    local challenge_switch
    local has_switched_forcefield = false
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        local switch_id = spawn_entity(ENT_TYPE.ITEM_SLIDINGWALL_SWITCH, x, y, layer, 0, 0)
        challenge_switch = get_entity(switch_id)
        return true
    end, "laser_switch")

    -- Laser that guards the entrance of the sun challenge until laser_switch is switched.
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        local forcefield_id = spawn_entity(ENT_TYPE.FLOOR_FORCEFIELD, x, y, layer, 0, 0)
        challenge_forcefield = get_entity(forcefield_id)
        challenge_forcefield:activate_laserbeam(true)
        return true
    end, "challenge_forcefield_switchable")

    -- Laser that turns on while participating in the sun challenge.
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        local forcefield_id = spawn_entity(ENT_TYPE.FLOOR_CHALLENGE_WAITROOM, x, y, layer, 0, 0)
        challenge_waitroom = get_entity(forcefield_id)
        challenge_waitroom:activate_laserbeam(false)
        return true
    end, "challenge_waitroom_switchable")

    level_state.callbacks[#level_state.callbacks+1] = set_callback(function ()
        if has_switched_forcefield then return end
        if challenge_switch.timer > 0 then
            challenge_forcefield:activate_laserbeam(false)
            has_switched_forcefield = true
            
            -- Play a sound when flipping the switch so the player knows something happened.
            sound.play_sound(VANILLA_SOUND.UI_SECRET)
        end
    end, ON.FRAME)

    local function is_shop_template_at(x, y)
        if x == 2 and y == 2 then
            return true
        end
        return false
    end

    -- Replace the back layer door with the correct style door for the challenge.
    level_state.callbacks[#level_state.callbacks+1] = set_post_entity_spawn(function (entity)
        local x, y, layer = get_position(entity.uid)
        local roomX, roomY = get_room_index(x, y)
        if is_shop_template_at(roomX, roomY) then
            kill_entity(entity.uid)
            spawn_entity(ENT_TYPE.BG_SHOP_BACKDOOR, x, y, layer, 0, 0)
        end
    end, SPAWN_TYPE.ANY, 0, ENT_TYPE.BG_DOOR_FRONT_LAYER)

    local tun, tunx, tuny, tunlayer
    level_state.callbacks[#level_state.callbacks+1] = set_post_entity_spawn(function (entity)
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
                if i == room_start_x+2 and j == room_start_y - 7 then
                    texture_definition.sub_image_offset_x = texture_definition.sub_image_offset_x - 128
                end
                texture_definition.sub_image_offset_y = 0
                texture_definition.sub_image_width = 128
                texture_definition.sub_image_height = 128
                local new_texture = define_texture(texture_definition)
                shop:set_texture(new_texture)
            end
        end

        -- Prepare Tun to be killed.
        tun = entity
        -- Set the aggro to 1 so Tun's dead body remains instead of poofing.
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

    local tun_killed = false
    level_state.callbacks[#level_state.callbacks+1] = set_callback(function()
        if tun_killed or not tun then return end
        if tun.health == 0 then
            tun_killed = true
            tun.flags = clr_flag(tun.flags, ENT_FLAG.INVISIBLE)
            tun.flags = set_flag(tun.flags, ENT_FLAG.FACING_LEFT)
            if overall_state.difficulty == DIFFICULTY.EASY then
                -- Do not allow Tun to be picked up in easy mode; the sun challenge should be unavailable.
                tun.flags = clr_flag(tun.flags, ENT_FLAG.PICKUPABLE)
                tun.flags = clr_flag(tun.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
            else
                -- Allow the player to pick up Tun to activate the sun challenge.
                tun.flags = set_flag(tun.flags, ENT_FLAG.PICKUPABLE)
                tun.flags = set_flag(tun.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
            end
            move_entity(tun.uid, tunx, tuny, tunlayer, 0, 0)
        end
    end, ON.FRAME)
    
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        -- Spawn a non-loaded HouYi Bow.
        spawn_entity(ENT_TYPE.ITEM_HOUYIBOW, x, y, layer, 0, 0)
        return true
    end, "houyibow")

    local ana
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        local ana_uid = spawn_entity(ENT_TYPE.MONS_CAVEMAN, x, y, layer, 0, 0)
        ana = get_entity(ana_uid)
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
        return true
    end, "ana_spelunky")
    
    level_state.callbacks[#level_state.callbacks+1] = set_callback(function()
        if not ana then return end
        -- Kill ana on each frame in case a necromancer revives her.
        ana.health = 0
    end, ON.FRAME)

    local rewardx, rewardy, rewardlayer
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        -- Save the position of the tile we want to spawn the challenge reward (idol) at so we can spawn it later when
        -- the challenge has been completed.
        rewardx, rewardy, rewardlayer = x, y, layer
        return true
    end, "challenge_reward")

    local sunchallenge_generators = {}
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        local generator_id = spawn_entity(ENT_TYPE.FLOOR_SUNCHALLENGE_GENERATOR, x, y, layer, 0, 0)
        local generator = get_entity(generator_id)
        generator.on_off = false
        -- Store these so we can activate them later.
        sunchallenge_generators[#sunchallenge_generators + 1] = generator
        return true
    end, "sunchallenge_generator")

    level_state.callbacks[#level_state.callbacks+1] = set_post_entity_spawn(function(entity)
        -- Do not spawn capes from sun challenge vampires
        -- Do not spawn rubies from sun challenge enemies.
        entity:destroy()
    end, SPAWN_TYPE.SYSTEMIC, 0, ENT_TYPE.ITEM_CAPE, ENT_TYPE.ITEM_RUBY)
    
    local has_payed_for_sun_challenge = false
    local sun_wait_timer
    local has_activated_sun_challenge = false
    local sun_challenge_activation_time
    local has_completed_sun_challenge = false
    local sun_challenge_toast_shown = 0
    level_state.callbacks[#level_state.callbacks+1] = set_callback(function ()
        -- This allows us to kill all of the spawns when the challenge is completed or the player dies.
        local function clear_sun_challenge_spawns()
            local sun_challenge_spawns = get_entities_by_type({
                ENT_TYPE.MONS_SORCERESS,
                ENT_TYPE.MONS_VAMPIRE,
                ENT_TYPE.MONS_WITCHDOCTOR,
                ENT_TYPE.MONS_NECROMANCER,
                ENT_TYPE.MONS_REDSKELETON,
                ENT_TYPE.MONS_BAT,
                ENT_TYPE.MONS_BEE,
                ENT_TYPE.MONS_SKELETON,
                ENT_TYPE.MONS_SNAKE,
                ENT_TYPE.MONS_SPIDER
            })
            for _, spawn in ipairs(sun_challenge_spawns) do
                kill_entity(spawn)
            end
        end
        
        -- Turns off all generators.
        local function deactivate_generators()
            for _, generator in ipairs(sunchallenge_generators) do
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
                    if rewardx then
                        local collected = IDOL_COLLECTED_STATE.NOT_COLLECTED
                        if overall_state.run_idol_collected then
                            collected = IDOL_COLLECTED_STATE.COLLECTED_ON_RUN
                        elseif overall_state.idol_collected then
                            collected = IDOL_COLLECTED_STATE.COLLECTED
                        end
                        print(f'idol_state: {collected}')
                        spawn_idol(
                            rewardx,
                            rewardy,
                            rewardlayer,
                            collected,
                            overall_state.difficulty == DIFFICULTY.EASY)
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
    end, ON.FRAME)

    -- We don't want sun challenge bats or Guts tadpoles/coffins.
    level_state.callbacks[#level_state.callbacks+1] = set_post_entity_spawn(function (entity)
        entity.flags = set_flag(entity.flags, ENT_FLAG.INVISIBLE)
        move_entity(entity.uid, 1000, 0, 0, 0)
        entity:destroy()
    end, SPAWN_TYPE.ANY, 0, ENT_TYPE.MONS_BAT, ENT_TYPE.MONS_TADPOLE, ENT_TYPE.ITEM_COFFIN)

    -- Do not spawn frogs from the goliath frog -- if a player cheeses into the goliath area, it should
    -- be to no avail.
    level_state.callbacks[#level_state.callbacks+1] = set_post_entity_spawn(function(entity)
        entity:destroy()
    end, SPAWN_TYPE.SYSTEMIC, 0, ENT_TYPE.MONS_FIREFROG, ENT_TYPE.MONS_FROG)
    
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        local kali_uid = spawn_entity(ENT_TYPE.BG_KALI_STATUE, x + .5, y, layer, 0, 0)
        local kali = get_entity(kali_uid)
        kali.height = 7
        kali.width = 6
    end, "kali_statue")

    level_state.callbacks[#level_state.callbacks+1] = set_callback(function()
        if #players < 1 then return end
        local player = players[1]
        local x, y, layer = get_position(player.uid)
        if tun and layer == LAYER.FRONT and distance(player.uid, tun.uid) <= 2 then
            say(player.uid, "What happened here?", 0, true)
            tun = nil
        end
        if ana and layer == LAYER.BACK and distance(player.uid, ana.uid) <= 2 then
            if player:get_name() == "Ana Spelunky" then
                say(player.uid, "What? Is that... me? What's going on here?", 0, true)
            else
                say(player.uid, "Ana? This can't be... The caves are supposed to...", 0, true)
            end
            if overall_state.seen_ana_callback then
                overall_state.seen_ana_callback()
            end
            ana = nil
        end
    end, ON.FRAME)
end

sunken_city.unload_level = function()
    if not level_state.loaded then return end

    local callbacks_to_clear = level_state.callbacks
    level_state.loaded = false
    level_state.callbacks = {}
    for _,callback in ipairs(callbacks_to_clear) do
        clear_callback(callback)
    end
end

return sunken_city
