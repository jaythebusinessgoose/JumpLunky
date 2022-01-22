local clear_embeds = require('clear_embeds')
local DIFFICULTY = require('difficulty')

define_tile_code("ice_turkey")
define_tile_code("ice_yeti")
define_tile_code("ice_idol")

local ice_caves = {
    identifier = "ice",
    title = "Ice Caves",
    theme = THEME.SUNKEN_CITY,
    width = 8,
    height = 2,
    file_name = "Sunken City-2.lvl",
}

local level_state = {
    loaded = false,
    callbacks = {},
}

local overall_state = {
    idol_collected = false,
    run_idol_collected = false,
    difficulty = DIFFICULTY.NORMAL,
}

ice_caves.set_idol_collected = function(collected)
    overall_state.idol_collected = collected
end

ice_caves.set_run_idol_collected = function(collected)
    overall_state.run_idol_collected = collected
end

local function update_file_name()
--     if overall_state.difficulty == DIFFICULTY.HARD then
--         ice_caves.file_name = "ice-hard.lvl"
--     elseif overall_state.difficulty == DIFFICULTY.EASY then
--         ice_caves.file_name = "ice-easy.lvl"
--     else
--         ice_caves.file_name = "ice.lvl"
--     end
end

ice_caves.set_difficulty = function(difficulty)
    overall_state.difficulty = difficulty
    update_file_name()
end

ice_caves.load_level = function()
    if level_state.loaded then return end
    level_state.loaded = true

    -- Spawn a turkey in ice that must be extracted.
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        local ice_uid
        clear_embeds.perform_block_without_embeds(function()
            ice_uid = spawn_entity(ENT_TYPE.FLOOR_ICE, x, y, layer, 0, 0)
        end)
        local turkey_uid = spawn_entity_over(ENT_TYPE.ITEM_ALIVE_EMBEDDED_ON_ICE, ice_uid, 0, 0)
        local turkey = get_entity(turkey_uid)
        turkey.inside = ENT_TYPE.MOUNT_TURKEY
        turkey.animation_frame = 239
        turkey.color.a = 130
        return true
    end, "ice_turkey")

    level_state.callbacks[#level_state.callbacks+1] = set_post_entity_spawn(function(entity)
        if level ~= ICE_LEVEL then return end
        -- Spawn the ice turkey dead so it can't be ridden.
        kill_entity(entity.uid, false)
    end, SPAWN_TYPE.ANY, 0, ENT_TYPE.MOUNT_TURKEY)

    -- Spawn a yeti in ice that must be extracted.
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        local ice_uid
        clear_embeds.perform_block_without_embeds(function()
            ice_uid = spawn_entity(ENT_TYPE.FLOOR_ICE, x, y, layer, 0, 0)
        end)
        local yeti_uid = spawn_entity_over(ENT_TYPE.ITEM_ALIVE_EMBEDDED_ON_ICE, ice_uid, 0, 0)
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

    -- Spawn an idol in ice that must be extracted.
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        local ice_uid
        clear_embeds.perform_block_without_embeds(function()
            ice_uid = spawn_entity(ENT_TYPE.FLOOR_ICE, x, y, layer, 0, 0)
        end)
        if overall_state.difficulty == DIFFICULTY.EASY or overall_state.run_idol_collected then
            -- Do not spawn the idol in easy or if it has been collected.
            return true
        end

        local idol_uid = spawn_entity_over(ENT_TYPE.ITEM_ALIVE_EMBEDDED_ON_ICE, ice_uid, 0, 0)
        local idol = get_entity(idol_uid)
        if overall_state.idol_collected then
            idol.inside = ENT_TYPE.ITEM_MADAMETUSK_IDOL
            idol.animation_frame = 172
        else
            idol.inside = ENT_TYPE.ITEM_IDOL
            idol.animation_frame = 31
        end
        idol.color.a = 130
        return true
    end, "ice_idol")

    level_state.callbacks[#level_state.callbacks+1] = set_post_entity_spawn(function(entity)
        -- Set the price to 0 so the player doesn't get gold for returning the idol.
        entity.price = 0
    end, SPAWN_TYPE.ANY, 0, ENT_TYPE.ITEM_IDOL, ENT_TYPE.ITEM_MADAMETUSK_IDOL)
end

ice_caves.unload_level = function()
    if not level_state.loaded then return end

    local callbacks_to_clear = level_state.callbacks
    level_state.loaded = false
    level_state.callbacks = {}
    for _,callback in ipairs(callbacks_to_clear) do
        clear_callback(callback)
    end
end

return ice_caves
