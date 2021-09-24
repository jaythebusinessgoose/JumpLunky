define_tile_code("rope_crate")

local volcana = {
    theme = THEME.VOLCANA,
    width = 4,
    height = 4,
}

local level_state = {
    loaded = false,
    callbacks = {},
}

volcana.load_level = function()
    if level_state.loaded then return end
    level_state.loaded = true

    -- Spawns a crate that contains a pile of three ropes.
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        local crate_id = spawn_entity(ENT_TYPE.ITEM_CRATE, x, y, layer, 0, 0)
        local crate = get_entity(crate_id)
        crate.inside = ENT_TYPE.ITEM_PICKUP_ROPEPILE
        return true
    end, "rope_crate")

    level_state.callbacks[#level_state.callbacks+1] = set_post_entity_spawn(function (entity)
        -- Do not spawn magma men in the volcana lava.
        local x, y, layer = get_position(entity.uid)
        local lavas = get_entities_at(0, MASK.LAVA, x, y, layer, 1)
        if #lavas > 0 then
            entity.flags = set_flag(entity.flags, ENT_FLAG.INVISIBLE)
            move_entity(entity.uid, 1000, 0, 0, 0)
        end
    end, SPAWN_TYPE.ANY, 0, ENT_TYPE.MONS_MAGMAMAN)
end

volcana.unload_level = function()
    if not level_state.loaded then return end

    local callbacks_to_clear = level_state.callbacks
    level_state.loaded = false
    level_state.callbacks = {}
    for _,callback in ipairs(callbacks_to_clear) do
        clear_callback(callback)
    end
end

return volcana
