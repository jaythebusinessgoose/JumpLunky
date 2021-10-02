local DIFFICULTY = require('difficulty')

return function(legacy)
    local stats = {}

    if not legacy then
        -- Stats for games played in the default difficulty.
        stats.normal = {
            best_time = 0,
            best_time_idol_count = 0,
            best_time_death_count = 0,
            least_deaths_completion = nil,
            least_deaths_completion_time = 0,
            max_idol_completions = 0,
            max_idol_best_time = 0,
            deathless_completions = 0,
            best_level = nil,
            completions = 0,
        }

        -- Stats for games played in the easy difficulty.
        stats.easy = {
            best_time = 0,
            best_time_death_count = 0,
            least_deaths_completion = nil,
            least_deaths_completion_time = 0,
            deathless_completions = 0,
            best_level = nil,
            completions = 0,
        }

        -- Stats for games played in the hard difficulty.
        stats.hard = {
            best_time = 0,
            best_time_idol_count = 0,
            best_time_death_count = 0,
            least_deaths_completion = nil,
            least_deaths_completion_time = 0,
            max_idol_completions = 0,
            max_idol_best_time = 0,
            deathless_completions = 0,
            best_level = nil,
            completions = 0,
        }
    end
    function stats.stats_for_difficulty(difficulty)
        if difficulty == DIFFICULTY.HARD then
            return stats.hard
        elseif difficulty == DIFFICULTY.EASY then
            return stats.easy
        end
        return stats.normal
    end

    return stats
end