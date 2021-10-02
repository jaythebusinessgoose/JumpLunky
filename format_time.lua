local function round(num, dp)
    local mult = 10^(dp or 0)
    return math.floor(num * mult + 0.5)/mult
end
  
local function format_time(frames)
    local seconds = round(frames / 60, 3)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    local seconds_text = seconds % 60 < 10 and '0' or ''
    local minutes_text = minutes % 60 < 10 and '0' or ''
    local hours_prefix = hours < 10 and '0' or ''
    local hours_text = hours > 0 and f'{hours_prefix}{hours}:' or ''
    return hours_text .. minutes_text .. tostring(minutes % 60) .. ':' .. seconds_text .. string.format("%.3f", seconds % 60)
end

return format_time