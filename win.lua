local DIFFICULTY = require('difficulty')
local format_time = require('format_time')

local win_ui = {}

local win_state = {
    active = false,
    hud = nil,
    check_clear_win = nil,

    win = false,
    time = nil,
    deaths = nil,
    idols = nil,
    difficulty = nil,
    stats = nil,
    hardcore_stats = nil,
    hardcore_enabled = false,
    levels = nil,
    new_time_pb = false,
    new_deaths_pb = false,

    on_dismiss = nil,
}

function win_ui.won()
    return win_state.win
end

function win_ui.win(
        time,
        deaths,
        idols,
        difficulty,
        stats,
        hardcore_stats,
        hardcore_enabled,
        levels,
        new_time_pb,
        new_deaths_pb)
    win_state.win = true
    win_state.time = time
    win_state.deaths = deaths
    win_state.idols = idols
    win_state.difficulty = difficulty
    win_state.stats = stats
    win_state.hardcore_stats = hardcore_stats
    win_state.hardcore_enabled = hardcore_enabled
    win_state.levels = levels
    win_state.new_time_pb = new_time_pb
    win_state.new_deaths_pb = new_deaths_pb
end

function win_ui.clear_win()
    win_state.win = false
    win_state.time = nil
    win_state.deaths = nil
    win_state.idols = nil
    win_state.difficulty = nil
    win_state.stats = nil
    win_state.hardcore_stats = nil
    win_state.hardcore_enabled = false
    win_state.levels = nil
    win_state.new_time_pb = false
    win_state.new_deaths_pb = false
    if win_state.on_dismiss then
        win_state.on_dismiss()
    end
    win_state.on_dismiss = nil
end

function win_ui.set_on_dismiss(on_dismiss)
    win_state.on_dismiss = on_dismiss
end

function win_ui.activate()
    if win_state.active then return end
    win_state.active = true
    
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

    win_state.check_clear_win = set_callback(function ()
        if not win_state.win or state.theme ~= THEME.BASE_CAMP then return end	
        local player_slot = state.player_inputs.player_slot_1
        -- Show the win screen until the player presses the jump button.
        if #players > 0 and test_flag(player_slot.buttons, 1) then
            win_ui.clear_win()
            -- Re-enable the menu when the game is resumed.
            state.level_flags = set_flag(state.level_flags, 20)
        elseif #players > 0 and state.time_total > 120 then
            -- Stun the player while the win screen is showing so that they do not accidentally move or take actions.
            players[1]:stun(2)
            -- Disable the pause menu while the win screen is showing.
            state.level_flags = clr_flag(state.level_flags, 20)
        end
    end, ON.GAMEFRAME)

    -- Win state
    win_state.hud = set_callback(function(ctx)
        if not win_state.win then return end
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
            
        local current_stats = win_state.stats.current_stats()
        local current_hardcore_stats = win_state.hardcore_stats.current_stats()
        
        local format_time = format_time

        local stat_texts = {}
        local pb_stat_texts = {}
        function add_stat(text)
            stat_texts[#stat_texts+1] = text
        end
        function add_pb_stat(text)
            pb_stat_texts[#pb_stat_texts+1] = text
        end
        
        add_stat("Congratulations!")
        if win_state.difficulty == DIFFICULTY.EASY then
            add_stat('Easy completion')
        elseif win_state.difficulty == DIFFICULTY.HARD then
            add_stat('Hard completion')
        else
            add_stat("")
        end
        add_stat("")
        add_stat("")
        
        local empty_stats = 0
        if win_state.new_deaths_pb or win_state.new_time_pb then
            add_stat("New PB!!")
        else
            empty_stats = empty_stats + 1
        end
        add_stat(f'Time: {format_time(win_state.time)}')
        if not win_state.hardcore_enabled then
            if win_state.deaths == 0 then
                add_stat('Deathless!')
            else
                add_stat(f'Deaths: {win_state.deaths}')
            end
        else
            empty_stats = empty_stats + 1
        end
        local all_idols_text = ""
        if win_state.idols == win_state.levels then
            all_idols_text = " (All Idols!)"
        end
        if win_state.difficulty ~= DIFFICULTY.EASY and win_state.idols > 0 then
            add_stat(f'Idols: {win_state.idols}{all_idols_text}')
        else
            empty_stats = empty_stats + 1
        end
        for i=1,empty_stats do
            add_stat("")
        end
        add_stat("")
        add_stat("")
        
        empty_stats = 0
        add_pb_stat(f'Completions: {current_stats.completions}')
        if win_state.hardcore_enabled then
            add_pb_stat(f'Hardcore completions: {current_hardcore_stats.completions}')
        elseif current_stats.deathless_completions and current_stats.deathless_completions > 0 then
            add_pb_stat(f'Deathless completions: {current_stats.deathless_completions}')
        else
            empty_stats = empty_stats + 1
        end
        if win_state.difficulty ~= DIFFICULTY.EASY and
                win_state.hardcore_enabled and
                current_hardcore_stats.max_idol_completions and
                current_hardcore_stats.max_idol_completions > 0 then
            add_pb_stat(f'All idol hardcore completions: {current_hardcore_stats.max_idol_completions}')
        elseif win_state.difficulty ~= DIFFICULTY.EASY and
                not win_state.hardcore_enabled and
                current_stats.max_idol_completions and
                current_stats.max_idol_completions > 0 then
            add_pb_stat(f'All idol completions: {current_stats.max_idol_completions}')
        else
            empty_stats = empty_stats + 1
        end
        
        for i=1,empty_stats do
            add_pb_stat("")
        end
        
        add_pb_stat("")
        
        add_pb_stat("PBs:")
        local time_pb_text = ''
        if win_state.new_time_pb then
            time_pb_text = ' (New PB!)'
        end
        local deaths_pb_text = ''
        if win_state.new_deaths_pb then
            deaths_pb_text = ' (New PB!)'
        end
        empty_stats = 0
        if win_state.hardcore_enabled then
            add_pb_stat(f'Fastest time: {format_time(current_stats.best_time)}{time_pb_text}')
            add_pb_stat(f'Fastest hardcore time: {format_time(current_hardcore_stats.best_time)}{time_pb_text}')
            
            if win_state.difficulty ~= DIFFICULTY.EASY and
            current_hardcore_stats.max_idol_best_time and
                    current_hardcore_stats.max_idol_best_time > 0 then
                add_pb_stat(f'Fastest hardcore all idols: {format_time(current_hardcore_stats.max_idol_best_time)}')
            else
                empty_stats = empty_stats + 1
            end
            empty_stats = empty_stats + 1
        else
            add_pb_stat(f'Fastest time: {format_time(current_stats.best_time)}{time_pb_text}')
            add_pb_stat(f'Least deaths: {current_stats.least_deaths_completion}{deaths_pb_text}')
            
            if current_stats.deathless_completions and
                    current_stats.deathless_completions > 0 and
                    current_stats.least_deaths_completion_time and
                    current_stats.least_deaths_completion_time > 0 then
                add_pb_stat(f'Fastest deathless: {format_time(current_stats.least_deaths_completion_time)}')
            else
                empty_stats = empty_stats + 1
            end
            
            if win_state.difficulty ~= DIFFICULTY.EASY and
                    current_stats.max_idol_best_time and
                    current_stats.max_idol_best_time > 0 then
                add_pb_stat(f'Fastest all idols: {format_time(current_stats.max_idol_best_time)}')
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
            ctx:draw_text(text, statstextx, statstexty, fontsize, fontsize, Color:black(), VANILLA_TEXT_ALIGNMENT.LEFT, VANILLA_FONT_STYLE.ITALIC)
            statstexty = statstexty + textheight - .04
        end
        for _, text in ipairs(pb_stat_texts) do
            local t_color = rgba(0, 0, 36, 230)
            ctx:draw_text(text, hardcoretextx, hardcoretexty, fontsize, fontsize, Color:black(), VANILLA_TEXT_ALIGNMENT.LEFT, VANILLA_FONT_STYLE.ITALIC)
            hardcoretexty = hardcoretexty + textheight - .04
        end
        
        local stats_title = "VICTORY"
        local stats_title_color = rgba(255,255,255,255)
        ctx:draw_text(stats_title, 0, .71, titlesize, titlesize, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
        if win_state.hardcore_enabled then
            ctx:draw_text("Hardcore", statstextx, .7, titlesize, titlesize, Color:black(), VANILLA_TEXT_ALIGNMENT.RIGHT, VANILLA_FONT_STYLE.ITALIC)
        end
    end, ON.RENDER_POST_HUD)
end

function win_ui.deactivate()
    if not win_state.active then return end
    win_state.active = false

    win_state.win = false
    win_state.time = nil
    win_state.deaths = nil
    win_state.idols = nil
    win_state.difficulty = nil
    win_state.stats = nil
    win_state.hardcore_stats = nil
    win_state.hardcore_enabled = false
    win_state.levels = nil
    win_state.new_time_pb = false
    win_state.new_deaths_pb = false
    if win_state.on_dismiss then
        win_state.on_dismiss()
    end
    win_state.on_dismiss = nil

    if win_state.hud then
        clear_callback(win_state.hud)
    end
    win_state.hud = nil
    if win_state.check_clear_win then
        clear_callback(win_state.check_clear_win)
    end
    win_state.check_clear_win = nil
end

set_callback(function()
    win_ui.activate()
end, ON.LOAD)

return win_ui