local DIFFICULTY = require('difficulty')
local format_time = require('format_time')

local hud = {}

local hud_state = {
    active = false,
    -- Do not show the hud in the menus.
    has_seen_base_camp = false,

    callbacks = {},

    stats = nil,
    saved_run = nil,
    hardcore = false,
    difficulty = DIFFICULTY.NORMAL,
    won = false,
    initial_level = nil,
    shortcut = false,
    continued = false,
    idols = nil,
    attempts = nil,
}

function hud.update_stats(stats, hardcore, difficulty)
    hud_state.stats = stats
    hud_state.hardcore = hardcore
    hud_state.difficulty = difficulty
end

function hud.update_saved_run(saved_run)
    hud_state.saved_run = saved_run
end

function hud.update_win_state(won)
    hud_state.won = won
end

function hud.update_run_entry(initial_level, shortcut, continued)
    hud_state.initial_level = initial_level
    hud_state.shortcut = shortcut
    hud_state.continued = continued
end

function hud.update_run(idols, attempts)
    hud_state.idols = idols
    hud_state.attempts = attempts
end

function hud.activate()
    if hud_state.active then return end
    hud_state.active = true

    local function add_callback(callback, on)
        hud_state.callbacks[#hud_state.callbacks+1] = set_callback(callback, on)
    end

    add_callback(function()
        hud_state.has_seen_base_camp = true
    end, ON.CAMP)
    add_callback(function()
        hud_state.has_seen_base_camp = false
    end, ON.MENU)
    add_callback(function()
        hud_state.has_seen_base_camp = false
    end, ON.TITLE)

    add_callback(function(ctx)
        if not hud_state.has_seen_base_camp then return end

        local text_color = rgba(255, 255, 255, 195)
        local w = 1.3
        local h = 1.3
        local x = 0
        local y = 0
        
        -- Display stats, or a win screen, for the current difficulty mode and current saved run.
        -- local saved_run = current_saved_run()
        -- local current_stats = stats.current_stats()
        -- local stats_hardcore = hardcore_stats.current_stats()
       
        local saved_run = hud_state.saved_run
        local current_stats = hud_state.stats
        local hardcore_enabled = hud_state.hardcore
        if hud_state.won then
            -- Do not render, showing stats in RENDER_POST_HUD
        elseif state.theme == THEME.BASE_CAMP then
            local texts = {}
            if hardcore_enabled and hud_state.difficulty == DIFFICULTY.EASY then
                texts[#texts+1] = 'Easy mode (Hardcore)'
            elseif hardcore_enabled and hud_state.difficulty == DIFFICULTY.HARD then
                texts[#texts+1] = 'Hard mode (Hardcore)'
            elseif hardcore_enabled then
                texts[#texts+1] = 'Hardcore'
            elseif hud_state.difficulty == DIFFICULTY.EASY then
                texts[#texts+1] = 'Easy mode'
            elseif hud_state.difficulty == DIFFICULTY.HARD then
                texts[#texts+1] = 'Hard mode'
            end
            if hud_state.continued then
                texts[#texts+1] = "Continue run from " .. saved_run.saved_run_level.title
                local text = " Time: " .. format_time(saved_run.saved_run_time) .. " Deaths: " .. (saved_run.saved_run_attempts)
                if saved_run.saved_run_idol_count > 0 then
                    text = text .. " Idols: " .. saved_run.saved_run_idol_count
                end
                texts[#texts+1] = text
            elseif hud_state.shortcut then
                texts[#texts+1] = "Shortcut to " .. hud_state.initial_level.title .. " trial"
            elseif hardcore_enabled then
                if current_stats.completions and current_stats.completions > 0 then
                    idol_text = ""
                    if hud_state.difficulty ~= DIFFICULTY.EASY then
                        if current_stats.best_time_idol_count == 1 then
                            idol_text = f' (1 idol)'
                        elseif current_stats.best_time_idol_count > 1 then
                            idol_text = f' ({current_stats.best_time_idol_count} idols)'
                        end
                    end
                    texts[#texts+1] = f'Wins: {current_stats.completions}  PB: {format_time(current_stats.best_time)}{idol_text}'
                elseif current_stats.best_level then
                    texts[#texts+1] = f'PB: {current_stats.best_level.title}'
                else
                    texts[#texts+1] = "PB: N/A"
                end
            else
                if current_stats.completions and current_stats.completions > 0 then
                    idol_text = ""
                    if hud_state.difficulty ~= DIFFICULTY.EASY then
                        if current_stats.best_time_idol_count == 1 then
                            idol_text = f' (1 idol)'
                        elseif current_stats.best_time_idol_count > 1 then
                            idol_text = f' ({current_stats.best_time_idol_count} idols)'
                        end
                    end
                    texts[#texts+1] = f'Wins: {current_stats.completions}  PB: {format_time(current_stats.best_time)}{idol_text}'
                elseif current_stats.best_level then
                    texts[#texts+1] = f'PB: {current_stats.best_level.title}'
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
        elseif hud_state.shortcut then
            local text = f'{hud_state.initial_level.title} shortcut practice'
            local tw, _ = draw_text_size(28, text)
            ctx:draw_text(0 - tw / 2, -0.935, 28, text, text_color)
        elseif hardcore_enabled then
            local texts = {}
            if hud_state.difficulty == DIFFICULTY.EASY then
                texts[#texts+1] = 'Easy mode (Hardcore)'
            elseif hud_state.difficulty == DIFFICULTY.HARD then
                texts[#texts+1] = 'Hard mode (Hardcore)'
            else
                texts[#texts+1] = 'Hardcore'
            end
            if hud_state.idols > 0 then
                texts[#texts+1] = f'Idols: {hud_state.idols}'
            end
            
            
            local texty = -0.935
            for i = #texts,1,-1 do
                local text = texts[i]
                local tw, th = draw_text_size(28, text)
                ctx:draw_text(0 - tw / 2, texty, 28, text, text_color)
                texty = texty - th
            end
        else
            print("here we are")
            local texts = {}
            if hud_state.difficulty == DIFFICULTY.EASY then
                texts[#texts+1] = 'Easy mode'
            elseif hud_state.difficulty == DIFFICULTY.HARD then
                texts[#texts+1] = 'Hard mode'
            end
            print("and here")
            local idols_text = ""
            if hud_state.idols > 0 then
                idols_text = f'     Idols: {hud_state.idols}'
            end
            print("here?")
            texts[#texts+1] = f'Deaths: {hud_state.attempts - 1}{idols_text}'
            
            print(inspect(texts))
            local texty = -0.935
            for i = #texts,1,-1 do
                local text = texts[i]
                local tw, th = draw_text_size(28, text)
                ctx:draw_text(0 - tw / 2, texty, 28, text, text_color)
                texty = texty - th
            end
        end
    end, ON.GUIFRAME)
end

function hud.deactivate()
    if not hud_state.active then return end
    hud_state.active = false
    
    hud_state.stats = nil
    hud_state.saved_run = nil
    hud_state.hardcore = false
    hud_state.difficulty = DIFFICULTY.NORMAL
    hud_state.won = false
    hud_state.initial_level = nil
    hud_state.shortcut = false
    hud_state.continued = false
    hud_state.idols = nil
    hud_state.attempts = nil
    hud_state.time = nil

    for _, callback in pairs(hud_state.callbacks) do
        clear_callback(callback)
    end
    hud_state.callbacks = {}
end

 set_callback(function()
    hud.activate()
 end, ON.LOAD)

 return hud