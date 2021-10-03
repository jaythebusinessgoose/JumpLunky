local save_state = {}

function save_state.save(game_state, level_sequence, ctx)
	function saved_run_datar(saved_run)
		if not saved_run or not saved_run.has_saved_run then return nil end
		local saved_run_data = {
			has_saved_run = saved_run.has_saved_run,
			level = level_sequence.index_of_level(saved_run.saved_run_level) - 1,
			attempts = saved_run.saved_run_attempts,
			idols = saved_run.saved_run_idol_count,
			idol_levels = saved_run.saved_run_idols_collected,
			run_time = saved_run.saved_run_time,
		}
		return saved_run_data
	end
	local normal_saved_run_data = saved_run_datar(game_state.normal_saved_run)
	local easy_saved_run_data = saved_run_datar(game_state.easy_saved_run)
	local hard_saved_run_data = saved_run_datar(game_state.hard_saved_run)
	local function convert_stats(stats)
		if not stats then return nil end
		local new_stats = {}
		for k,v in pairs(stats) do new_stats[k] = v end
		local best_level = level_sequence.index_of_level(stats.best_level)
		if best_level then
			new_stats.best_level = best_level - 1
		else
			new_stats.best_level = nil
		end
		return new_stats
	end
    local save_data = {
		version = '1.5',
		idol_levels = game_state.idols_collected,
		total_idols = game_state.total_idols,
		saved_run_data = normal_saved_run_data,
		easy_saved_run = easy_saved_run_data,
		hard_saved_run = hard_saved_run_data,
		stats = convert_stats(game_state.stats.normal),
		easy_stats = convert_stats(game_state.stats.easy),
		hard_stats = convert_stats(game_state.stats.hard),
		legacy_stats = convert_stats(game_state.legacy_stats.normal),
		legacy_easy_stats = convert_stats(game_state.legacy_stats.easy),
		legacy_hard_stats = convert_stats(game_state.legacy_stats.hard),
		has_seen_ana_dead = game_state.has_seen_ana_dead,
		hardcore_enabled = game_state.hardcore_enabled,
		difficulty = game_state.difficulty,
		hpe = game_state.hardcore_previously_enabled,
		hardcore_stats = convert_stats(game_state.hardcore_stats.normal),
		hardcore_stats_easy = convert_stats(game_state.hardcore_stats.easy),
		hardcore_stats_hard = convert_stats(game_state.hardcore_stats.hard),
		legacy_hardcore_stats = convert_stats(game_state.legacy_hardcore_stats.normal),
		legacy_hardcore_stats_easy = convert_stats(game_state.legacy_hardcore_stats.easy),
		legacy_hardcore_stats_hard = convert_stats(game_state.legacy_hardcore_stats.hard),
    }

    ctx:save(json.encode(save_data))
end

function save_state.load(game_state, level_sequence, ctx)
    local load_data_str = ctx:load()

    if load_data_str ~= '' then
        local load_data = json.decode(load_data_str)
		local load_version = load_data.version
		if load_data.difficulty then
            game_state.difficulty = load_data.difficulty
		end
		if not load_version then 
			local normal_stats = game_state.stats.normal
			normal_stats.best_time = load_data.best_time
			normal_stats.best_time_idol_count = load_data.best_time_idols
			normal_stats.best_time_death_count = load_data.best_time_death_count
			normal_stats.best_level = level_sequence.levels()[load_data.best_level+1]
			normal_stats.completions = load_data.completions or 0
			normal_stats.max_idol_completions = load_data.max_idol_completions or 0
			normal_stats.max_idol_best_time = load_data.max_idol_best_time or 0
			normal_stats.deathless_completions = load_data.deathless_completions or 0
			normal_stats.least_deaths_completion = load_data.least_deaths_completion
			normal_stats.least_deaths_completion_time = load_data.least_deaths_completion_time
		elseif load_version == '1.3' then
			local function legacy_stat_convert(stats)
				local new_stats = {}
				for k,v in pairs(stats) do new_stats[k] = v end
				local best_level = stats.best_level
				if best_level then
					if best_level == 3 then
						best_level = 4
					end
					new_stats.best_level = level_sequence.levels()[best_level + 1]
				end
				return new_stats
			end
			if load_data.stats then
				game_state.legacy_stats.normal = legacy_stat_convert(load_data.stats)
			end
			if load_data.easy_stats then
				game_state.legacy_stats.easy = legacy_stat_convert(load_data.easy_stats)
			end
			if load_data.hard_stats then
				game_state.legacy_stats.hard = legacy_stat_convert(load_data.hard_stats)
			end
			if load_data.hardcore_stats then
				game_state.legacy_hardcore_stats.normal = legacy_stat_convert(load_data.hardcore_stats)
			end
			if load_data.hardcore_stats_easy then
				game_state.legacy_hardcore_stats.easy = legacy_stat_convert(load_data.hardcore_stats_easy)
			end
			if load_data.hardcore_stats_hard then
				game_state.legacy_hardcore_stats.hard = legacy_stat_convert(load_data.hardcore_stats_hard)
			end
		else
			local function stat_convert(stats)
				local new_stats = {}
				for k,v in pairs(stats) do new_stats[k] = v end
				if stats.best_level then
					new_stats.best_level = level_sequence.levels()[stats.best_level + 1]
				end
				return new_stats
			end
			if load_data.stats then
				game_state.stats.normal = stat_convert(load_data.stats)
			end
			if load_data.easy_stats then
				game_state.stats.easy = stat_convert(load_data.easy_stats)
			end
			if load_data.hard_stats then
				game_state.stats.hard = stat_convert(load_data.hard_stats)
			end
			if load_data.legacy_stats then
				game_state.legacy_stats.normal = stat_convert(load_data.legacy_stats)
			end
			if load_data.legacy_easy_stats then
				game_state.legacy_stats.easy = stat_convert(load_data.legacy_easy_stats)
			end
			if load_data.legacy_hard_stats then
				game_state.legacy_stats.hard = stat_convert(load_data.legacy_hard_stats)
			end
			
			
			if load_data.hardcore_stats then
				game_state.hardcore_stats.normal = stat_convert(load_data.hardcore_stats)
			end
			if load_data.hardcore_stats_easy then
				game_state.hardcore_stats.easy = stat_convert(load_data.hardcore_stats_easy)
			end
			if load_data.hardcore_stats_hard then
				game_state.hardcore_stats.hard = stat_convert(load_data.hardcore_stats_hard)
			end
			
			if load_data.legacy_hardcore_stats then
				game_state.legacy_hardcore_stats.normal = stat_convert(load_data.legacy_hardcore_stats)
			end
			if load_data.legacy_hardcore_stats_easy then
				game_state.legacy_hardcore_stats.easy = stat_convert(load_data.legacy_hardcore_stats_easy)
			end
			if load_data.legacy_hardcore_stats_hard then
				game_state.legacy_hardcore_stats.hard = stat_convert(load_data.legacy_hardcore_stats_hard)
			end
		end

		game_state.idols_collected = load_data.idol_levels
		game_state.total_idols = load_data.total_idols
        game_state.hardcore_enabled = load_data.hardcore_enabled
		game_state.hardcore_previously_enabled = load_data.hpe
		
		function load_saved_run_data(saved_run, saved_run_data)
            if not saved_run_data or not saved_run_data.has_saved_run then return end
			saved_run.has_saved_run = saved_run_data.has_saved_run or not load_version
			saved_run.saved_run_level = level_sequence.levels()[saved_run_data.level+1]
			saved_run.saved_run_attempts = saved_run_data.attempts
			saved_run.saved_run_idol_count = saved_run_data.idols
			saved_run.saved_run_time = saved_run_data.run_time
			saved_run.saved_run_idols_collected = saved_run_data.idol_levels
		end
		
		local easy_saved_run_data = load_data.easy_saved_run
		local saved_run_data = load_data.saved_run_data
		local hard_saved_run_data = load_data.hard_saved_run
		if saved_run_data then
			load_saved_run_data(game_state.normal_saved_run, saved_run_data)
		end
		if easy_saved_run_data then
			load_saved_run_data(game_state.easy_saved_run, easy_saved_run_data)
		end
		if hard_saved_run_data then
			load_saved_run_data(game_state.hard_saved_run, hard_saved_run_data)
		end
		game_state.has_seen_ana_dead = load_data.has_seen_ana_dead
    end
    return game_state
end

return save_state