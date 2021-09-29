local sound = require('play_sound')
local clear_embeds = require('clear_embeds')
require('difficulty')

define_tile_code("bat_generator")
define_tile_code("bat_switch")
define_tile_code("moving_totem")
define_tile_code("totem_switch")
define_tile_code("dialog_block")

local dwelling = {
    identifier = "dwelling",
    title = "Dwelling",
    theme = THEME.DWELLING,
    width = 4,
    height = 5,
    file_name = "dwell.lvl",
}

local level_state = {
    loaded = false,
    callbacks = {},
}

local overall_state = {
    difficulty = DIFFICULTY.NORMAL,
}

local function update_file_name()
    if overall_state.difficulty == DIFFICULTY.HARD then
        dwelling.file_name = "dwell-hard.lvl"
    elseif overall_state.difficulty == DIFFICULTY.EASY then
        dwelling.file_name = "dwell-easy.lvl"
    else
        dwelling.file_name = "dwell.lvl"
    end
end

dwelling.set_difficulty = function(difficulty)
    overall_state.difficulty = difficulty
    update_file_name()
end

dwelling.load_level = function()
    if level_state.loaded then return end
    level_state.loaded = true

    local bat_generator
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        -- Creates a generator that will spawn bats when turned on. Defaults to off.
        local generator_id = spawn_entity(ENT_TYPE.FLOOR_SUNCHALLENGE_GENERATOR, x, y, layer, 0.0, 0.0)
        local generator = get_entity(generator_id)
        generator.on_off = false
        bat_generator = generator
        return true
    end, "bat_generator")
    
    local bat_switch
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        local switch_id = spawn_entity(ENT_TYPE.ITEM_SLIDINGWALL_SWITCH, x, y, layer, 0, 0)
        bat_switch = get_entity(switch_id)
        return true
    end, "bat_switch")
    
    
    local last_spawn
    local spawned_bat
    level_state.callbacks[#level_state.callbacks+1] = set_post_entity_spawn(function(ent)
        if last_spawn ~= nil then
            -- Kill the last enemy that was spawned so that we don't end up with too many enemies in
            -- memory. Doing this here since we couldn't kill the enemy earlier.
            kill_entity(last_spawn.uid)
        end
        last_spawn = ent
        local x, y, l = get_position(ent.uid)
        -- Spawn a bat one tile lower than the tile the enemy was spawned at; otherwise the bat will be
        -- crushed in the generator.
        spawned_bat = spawn_entity_nonreplaceable(ENT_TYPE.MONS_BAT, x, y - 1, l, 0, 0)
        -- Move the actual spawn out of the way instead of killing it; killing it now causes the
        --  generator to immediately spawn again, leading to infinite spawns.
        ent.x = 10000
        -- Turn off the generator when a bat is spawned to make sure only one bat is ever spawned at a time.
        bat_generator.on_off = false
    end, SPAWN_TYPE.SYSTEMIC, 0, {ENT_TYPE.MONS_SORCERESS, ENT_TYPE.MONS_VAMPIRE, ENT_TYPE.MONS_WITCHDOCTOR, ENT_TYPE.MONS_NECROMANCER})
    
    level_state.callbacks[#level_state.callbacks+1] = set_callback(function ()
        local bat_entity = get_entity(spawned_bat)
        if bat_entity and bat_entity.health == 0 then
            -- Turn the generator back on now that the bat is dead.
            bat_generator.on_off = true
            spawned_bat = nil
        end
        if bat_switch.timer > 0 and bat_entity == nil and not bat_generator.on_off then
            bat_generator.on_off = true
            
            sound.play_sound(VANILLA_SOUND.UI_SECRET)
        end
    end, ON.FRAME)

    -- Creates walls that will be destroyed when the totem_switch is switched. Don't ask why these are called totems, they're just walls.
    local moving_totems = {}
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        clear_embeds.perform_block_without_embeds(function()        
            local totem_uid = spawn_entity(ENT_TYPE.FLOOR_GENERIC, x, y, layer, 0, 0)
            moving_totems[#moving_totems + 1] = get_entity(totem_uid)
        end)
        return true
    end, "moving_totem")

    local totem_switch;
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        local switch_id = spawn_entity(ENT_TYPE.ITEM_SLIDINGWALL_SWITCH, x, y, layer, 0, 0)
        totem_switch = get_entity(switch_id)
        return true
    end, "totem_switch")

    level_state.callbacks[#level_state.callbacks+1] = set_callback(function()
        if not totem_switch then return end
        if totem_switch.timer > 0 and not has_activated_totem then
            has_activated_totem = true
            for _, moving_totem in ipairs(moving_totems) do
                kill_entity(moving_totem.uid)	
            end
            moving_totems = {}
        end
    end, ON.FRAME)

    -- This is a block that will cause the player to say a message upon walking past it.
    local dialog_block_pos_x
    local dialog_block_pos_y
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        dialog_block_pos_x = x
        dialog_block_pos_y = y
        return true
    end, "dialog_block")

    local hasDisplayedDialog = false
    level_state.callbacks[#level_state.callbacks+1] = set_callback(function ()
        if #players < 1 then return end
        local player = players[1]
        local player_uid = player.uid
        local x, y, layer = get_position(player_uid)
  
        if x <= dialog_block_pos_x and y >= dialog_block_pos_y then
            if not hasDisplayedDialog then
                say(player_uid, "I don't think this is the right way.", 0, true)
                hasDisplayedDialog = true
            end
        else
            hasDisplayedDialog = false
        end
    end, ON.FRAME)
end

dwelling.unload_level = function()
    if not level_state.loaded then return end

    local callbacks_to_clear = level_state.callbacks
    level_state.loaded = false
    level_state.callbacks = {}
    for _,callback in ipairs(callbacks_to_clear) do
        clear_callback(callback)
    end
end

return dwelling
