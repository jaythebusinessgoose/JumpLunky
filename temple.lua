define_tile_code("catmummy")
require('difficulty')

local temple = {
    identifier = "temp",
    theme = THEME.TEMPLE,
    width = 4,
    height = 6,
    file_name = "temp.lvl",
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
        temple.file_name = "temp-hard.lvl"
    elseif overall_state.difficulty == DIFFICULTY.EASY then
        temple.file_name = "temp-easy.lvl"
    else
        temple.file_name = "temp.lvl"
    end
end

temple.set_difficulty = function(difficulty)
    overall_state.difficulty = difficulty
    update_file_name()
end

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
