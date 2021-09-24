define_tile_code("catmummy")

local temple = {
    theme = THEME.TEMPLE,
}

local level_state = {
    loaded = false,
    callbacks = {},
}

temple.load_level = function()
    if level_state.loaded then return end
    level_state.loaded = true
    level_state.callbacks[#level_state.callbacks+1] = set_pre_tile_code_callback(function(x, y, layer)
        spawn_entity(ENT_TYPE.MONS_CATMUMMY, x, y, layer, 0, 0)
        return true
    end, "catmummy")
end

temple.unload_level = function()
    if not level_state.loaded then return end

    local callbacks_to_clear = level_state.callbacks
    level_state.loaded = false
    level_state.callbacks = {}
    for _,callback in ipairs(callbacks_to_clear) do
        clear_callback(callback)
    end
end

return temple
