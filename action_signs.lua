local button_prompts = require('ButtonPrompts/button_prompts')

local action_signs = {}

local action_sign_state = {
    active = false,

    signs = {},
    callbacks = {},
}

function action_signs.spawn_sign(x, y, layer, prompt_type, action, encounter_action, radius)
    local sign_uid = spawn_entity(ENT_TYPE.ITEM_SPEEDRUN_SIGN, x, y, layer, 0, 0)
    local sign = get_entity(sign_uid)
	-- This stops the sign from displaying its default toast text when pressing the door button.
	sign.flags = clr_flag(sign.flags, ENT_FLAG.ENABLE_BUTTON_PROMPT)
	local sign_prompt_uid = button_prompts.spawn_button_prompt(prompt_type, x + 6, y, layer)
    local sign_prompt = get_entity(sign_prompt)

    local sign_state = {
        sign = sign,
        action = action,
        encounter_action = encounter_action,
        radius = radius,
        player_near = false,
    }
    
    local destroyed = false
    sign_state.destroy = function()
        if destroyed then return end
        destroyed = true
        sign:destroy()
        sign_prompt:destroy()

        local new_signs = {}
        for _, new_sign in pairs(action_sign_state.signs) do
            if new_sign ~= sign_state then
                new_signs[#new_signs+1] = new_sign
            end
        end
        action_sign_state.signs = new_signs
    end
    action_sign_state.signs[#action_sign_state.signs+1] = sign_state
    return sign_state
end

function action_signs.activate()
    if action_sign_state.active then return end
    action_sign_state.active = true

    action_sign_state.callbacks[#action_sign_state.callbacks+1] = set_callback(function()
        if #players < 1 then return end
        local player = players[1]

        -- Only perform the actions of one sign per pass, in case multiple overlap.
        local resolved_a_sign = false
        for _, sign_state in pairs(action_sign_state.signs) do
            local sign = sign_state.sign
            local action = sign_state.action
            local encounter_action = sign_state.encounter_action
            local radius = sign_state.radius or .5

            if sign and player.layer == sign.layer and distance(player.uid, sign.uid) <= radius then
                if not resolved_a_sign then
                    resolved_a_sign = true
                    if not sign_state.player_near then
                        sign_state.player_near = true
                        if encounter_action then
                            encounter_action(sign)
                        end
                    end
                    if player:is_button_pressed(BUTTON.DOOR) then
                        if action then
                            action(sign)
                        end
                    end
                end
            else
                sign_state.player_near = false
            end
        end
    end, ON.GAMEFRAME)

    action_sign_state.callbacks[#action_sign_state.callbacks+1] = set_callback(function()
        action_sign_state.signs = {}
    end, ON.PRE_LOAD_LEVEL_FILES)
end

function action_signs.deactivate()
    if not action_sign_state.active then return end
    action_sign_state.active = false

    for _, callback in pairs(action_sign_state.callbacks) do
        clear_callback(callback)
    end
    action_sign_state.callbacks = {}

    for _, sign in pairs(action_sign_state.signs) do
        sign.destroy()
    end
    action_sign_state.signs = {}
end

set_callback(function()
    action_signs.activate()
end, ON.LOAD)

return action_signs