local DIFFICULTY = require('difficulty')
local format_time = require('format_time')
local sound = require('play_sound')

-- Module for handling showing stats in a journal UI.
local journal = {}

local journal_state = {
    active = false,
    hud = nil,
    button_handling = nil,

    show_stats = false,
    show_legacy_stats = false,
    stats = nil,
    hardcore_stats = nil,
    difficulty = DIFFICULTY.NORMAL,

    journal_open_button = nil,
    journal_open_button_closed = false,
    journal_closed_time = nil,

    last_left_input = nil,
    last_right_input = nil,
}

local journal_callbacks = {
    on_journal_closed = nil,
}

-- Sets a callback to be called when the journal is closed.
--
-- on_journal_closed: Callback called when journal is closed.
function journal.set_on_journal_closed(on_journal_closed)
    journal_callbacks.on_journal_closed = on_journal_closed
end

-- Whether or not the journal is currently showing stats.
--
-- Return: True if the journal is visible.
function journal.showing_stats()
    return journal_state.show_stats
end

-- Show the journal.
--
-- stats: Stats to show in the journal.
-- hardcore_stats: Stats for hardcore mode to show in the journal.
-- default_difficulty: Difficulty page to open the journal to.
-- open_button: The button that was pressed to open the journal. This will be used just to make
--              sure the button is released before reading it to close the journal.
-- showing_legacy_stats: Whether the stats that are being shown are legacy stats.
function journal.show(stats, hardcore_stats, default_difficulty, open_button, showing_legacy_stats)
    if journal_state.show_stats then return end

    journal_state.show_stats = true
    journal_state.show_legacy_stats = showing_legacy_stats
    journal_state.stats = stats
    journal_state.hardcore_stats = hardcore_stats
    journal_state.difficulty = default_difficulty
    journal_state.journal_open_button = open_button
    journal_state.journal_open_button_closed = false
    journal_state.last_left_input = nil
    journal_state.last_right_input = nil
    journal_state.journal_closed_time = nil

    sound.play_sound(VANILLA_SOUND.UI_JOURNAL_ON)
    state.level_flags = clr_flag(state.level_flags, 20)
    if #players > 0 then
        steal_input(players[1].uid)
    end
end

-- Force the journal to hide.
function journal.hide()
    if not journal_state.show_stats then return end

    journal_state.show_stats = false
    journal_state.show_legacy_stats = false
    journal_state.stats = nil
    journal_state.hardcore_stats = nil
    journal_state.difficulty = DIFFICULTY.NORMAL
    journal_state.journal_open_button = nil
    journal_state.journal_open_button_closed = false
    journal_state.last_left_input = nil
    journal_state.last_right_input = nil

    -- Keep track of the time that the stats were closed. This will allow us to enable the player's
    -- inputs later so that the same input isn't recognized again to cause a bomb to be thrown or another action.
    journal_state.journal_closed_time = state.time_level
    sound.play_sound(VANILLA_SOUND.UI_JOURNAL_OFF)
end

-- Activate journal callbacks, allowing the script to read button inputs to flip pages and
-- close the journal.
function journal.activate()
    if journal_state.active then return end
    journal_state.active = true

    journal_state.button_handling = set_callback(function()
        if #players < 1 then return end
        local player = players[1]

        if journal_state.show_stats then
            -- Gets a bitwise integer that contains the set of pressed buttons while the input is stolen.
            local buttons = read_stolen_input(player.uid)
            if not journal_state.journal_open_button_closed and journal_state.journal_open_button then
                if not test_flag(buttons, journal_state.journal_open_button) then
                    journal_state.journal_open_button_closed = true
                end
            end
            -- 1 = jump, 2 = whip, 3 = bomb, 4 = rope, 6 = Door, 8 = Journal
            if test_flag(buttons, 1) or
                    test_flag(buttons, 2) or 
                    test_flag(buttons, 3) or 
                    test_flag(buttons, 4) or 
                    ((journal_state.journal_open_button ~= 6 or journal_state.journal_open_button_closed) and
                     test_flag(buttons, 6) or 
                    ((journal_state.journal_open_button ~= 8 or journal_state.journal_open_button_closed) and
                     test_flag(buttons, 8))) then
                journal.hide()
                return
            end
            
            local function play_journal_pageflip_sound()
                sound.play_sound(VANILLA_SOUND.MENU_PAGE_TURN)
            end
            
            -- Change difficulty when pressing left or right.
            if test_flag(buttons, 9) then -- left_key
                if not journal_state.last_left_input or state.time_level - journal_state.last_left_input > 20 then
                    journal_state.last_left_input = state.time_level
                    if journal_state.difficulty > DIFFICULTY.EASY then
                        play_journal_pageflip_sound()
                        journal_state.difficulty = math.max(journal_state.difficulty - 1, DIFFICULTY.EASY)				
                    end
                end
            else
                journal_state.last_left_input = nil
            end
            if test_flag(buttons, 10) then -- right_key
                if not journal_state.last_right_input or state.time_level - journal_state.last_right_input > 20 then
                    journal_state.last_right_input = state.time_level
                    if journal_state.difficulty < DIFFICULTY.HARD then
                        play_journal_pageflip_sound()
                        journal_state.difficulty = math.min(journal_state.difficulty + 1, DIFFICULTY.HARD)
                    end
                end
            else
                journal_state.last_right_input = nil
            end
        elseif journal_state.journal_closed_time ~= nil and state.time_level  - journal_state.journal_closed_time > 20 then
            -- Re-activate the player's inputs 20 frames after the button was pressed to close the stats.
            -- This gives plenty of time for the player to release the button that was pressed.
            return_input(player.uid)
            state.level_flags = set_flag(state.level_flags, 20)
            journal_state.journal_closed_time = nil
            if journal_callbacks.on_journal_closed then
                journal_callbacks.on_journal_closed()
            end
        end
    end, ON.GAMEFRAME)

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

    -- Stats page
    journal_state.hud = set_callback(function(ctx)
        if not journal_state.show_stats then return end
        local color = Color:white()
        local fontsize = 0.0009
        local titlesize = 0.0012
        local w = 1.9
        local h = 1.8
        local bannerw = .5
        local bannerh = .2
        local bannery = .7
        ctx:draw_screen_texture(TEXTURE.DATA_TEXTURES_JOURNAL_BACK_0, 0, 0, -w/2, h/2, w/2, -h/2, color)
        ctx:draw_screen_texture(TEXTURE.DATA_TEXTURES_JOURNAL_PAGEFLIP_0, 0, 0, -w/2, h/2, w/2, -h/2, color)
        ctx:draw_screen_texture(banner_texture, 0, 0, -bannerw/2, bannery + bannerh/2, bannerw/2, bannery - bannerh/2, color)
            
        local current_stats = journal_state.stats.stats_for_difficulty(journal_state.difficulty)
        local current_hardcore_stats = journal_state.hardcore_stats.stats_for_difficulty(journal_state.difficulty)

        local stat_texts = {}
        local hardcore_stat_texts = {}
        function add_stat(text)
            stat_texts[#stat_texts+1] = text
        end
        function add_hardcore_stat(text)
            hardcore_stat_texts[#hardcore_stat_texts+1] = text
        end
        if current_stats.completions > 0 then
            add_stat(f'Completions: {current_stats.completions}')
            local empty_stats = 0
            if journal_state.difficulty ~= DIFFICULTY.EASY and current_stats.max_idol_completions > 0 then
                add_stat(f'All idol completions: {current_stats.max_idol_completions}')
            else
                empty_stats = empty_stats + 1
            end
            if current_stats.deathless_completions > 0 then
                add_stat(f'Deathless completions: {current_stats.deathless_completions}')
            else
                empty_stats = empty_stats + 1
            end
            for i=1,empty_stats do
                add_stat("")
            end
            add_stat("")
            add_stat("")
            add_stat("PBs:")
            local idol_text = ''
            if journal_state.difficulty ~= DIFFICULTY.EASY and current_stats.best_time_idol_count == 1 then
                idol_text = '1 idol, '
            elseif journal_state.difficulty ~= DIFFICULTY.EASY and current_stats.best_time_idol_count > 0 then
                idol_text = f'{current_stats.best_time_idol_count} idols, '
            end
            local deaths_text = '1 death'
            if current_stats.best_time_death_count > 1 then
                deaths_text = f'{current_stats.best_time_death_count} deaths'
            elseif current_stats.best_time_death_count == 0 then
                deaths_text = f'deathless'
            end
            add_stat(f'Best time: {format_time(current_stats.best_time)} ({idol_text}{deaths_text})')
            if journal_state.difficulty ~= DIFFICULTY.EASY and current_stats.max_idol_completions > 0 then
                add_stat(f'All idols: {format_time(current_stats.max_idol_best_time)}')
            end
            if current_stats.deathless_completions > 0 then
                add_stat(f'Deathless: {format_time(current_stats.least_deaths_completion_time)}')
            else
                add_stat(f'Least deaths: {current_stats.least_deaths_completion} ({format_time(current_stats.least_deaths_completion_time)})')
            end
        elseif current_stats.best_level then
            add_stat(f'PB: {current_stats.best_level.title}')
        else
            add_stat("PB: N/A")
        end
        if current_hardcore_stats.completions > 0 then
            add_hardcore_stat(f'Completions: {current_hardcore_stats.completions}')
            if journal_state.difficulty ~= DIFFICULTY.EASY and current_hardcore_stats.max_idol_completions > 0 then
                add_hardcore_stat(f'All idol completions: {current_hardcore_stats.max_idol_completions}')
            else
                add_hardcore_stat("")
            end
            add_hardcore_stat("")
            add_hardcore_stat("")
            add_hardcore_stat("")
            add_hardcore_stat("PBs:")
            local idol_text = ''
            if journal_state.difficulty ~= DIFFICULTY.EASY and current_hardcore_stats.best_time_idol_count == 1 then
                idol_text = ' (1 idol)'
            elseif journal_state.difficulty ~= DIFFICULTY.EASY and current_hardcore_stats.best_time_idol_count > 0 then
                idol_text = f' ({current_hardcore_stats.best_time_idol_count} idols)'
            end
            add_hardcore_stat(f'Best time: {format_time(current_hardcore_stats.best_time)}{idol_text}')
            if journal_state.difficulty ~= DIFFICULTY.EASY and current_hardcore_stats.max_idol_completions > 0 then
                add_hardcore_stat(f'All idols: {format_time(current_hardcore_stats.max_idol_best_time)}')
            end
        elseif current_hardcore_stats.best_level then
            add_hardcore_stat(f'PB: {current_hardcore_stats.best_level.title}')
        else
            add_hardcore_stat("PB: N/A")
        end
            
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
        for _, text in ipairs(hardcore_stat_texts) do
            local t_color = rgba(0, 0, 36, 230)
            ctx:draw_text(text, hardcoretextx, hardcoretexty, fontsize, fontsize, Color:black(), VANILLA_TEXT_ALIGNMENT.LEFT, VANILLA_FONT_STYLE.ITALIC)
            hardcoretexty = hardcoretexty + textheight - .04
        end
        
        local stats_title = "STATS"
        if journal_state.difficulty == DIFFICULTY.EASY then
            stats_title = "EASY"
        elseif journal_state.difficulty == DIFFICULTY.HARD then
            stats_title = "HARD"
        else
            stats_title = "STATS"
        end
        local stats_title_color = rgba(255,255,255,255)
        ctx:draw_text(stats_title, 0, .71, titlesize, titlesize, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
        ctx:draw_text("Hardcore", -statstextx, .7, titlesize, titlesize, Color:black(), VANILLA_TEXT_ALIGNMENT.RIGHT, VANILLA_FONT_STYLE.ITALIC)
        if journal_state.show_legacy_stats then
            ctx:draw_text("Legacy", statstextx, .7, titlesize, titlesize, Color:black(), VANILLA_TEXT_ALIGNMENT.LEFT, VANILLA_FONT_STYLE.ITALIC)
        end
        
        local buttonsx = .82
        local buttonssize = .0023
        if journal_state.difficulty ~= DIFFICULTY.EASY then
            ctx:draw_text("\u{8B}", -buttonsx, 0, buttonssize, buttonssize, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
        end
        if journal_state.difficulty ~= DIFFICULTY.HARD then
            ctx:draw_text("\u{8C}", buttonsx, 0, buttonssize, buttonssize, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
        end
    end, ON.RENDER_POST_HUD)
end

-- Deactivate the journal.
function journal.deactivate()
    if not journal_state.active then return end
    journal_state.active = false

    journal_state.show_stats = false
    journal_state.show_legacy_stats = false
    journal_state.stats = nil
    journal_state.hardcore_stats = nil
    journal_state.difficulty = DIFFICULTY.NORMAL
    journal_state.journal_open_button = nil
    journal_state.journal_open_button_closed = false
    journal_state.last_left_input = nil
    journal_state.last_right_input = nil
    journal_state.journal_closed_time = nil
    
    state.level_flags = set_flag(state.level_flags, 20)

    if journal_state.hud then
        clear_callback(journal_state.hud)
    end
    if journal_state.button_handling then
        clear_callback(journal_state.button_handling)
    end
end

set_callback(function()
    journal.activate()
end, ON.LOAD)

return journal