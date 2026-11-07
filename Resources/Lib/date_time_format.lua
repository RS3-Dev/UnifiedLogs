-- Format UTC-backed XP history for regional display
local Format = {}

Format.US = "us"
Format.EUROPEAN = "european"
Format.HOUR_12 = "12"
Format.HOUR_24 = "24"

local MONTH_SHORT = {
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
}

function Format.NormalizeDate(value)
    return value == Format.EUROPEAN and Format.EUROPEAN or Format.US
end

function Format.NormalizeTime(value)
    return value == Format.HOUR_24 and Format.HOUR_24 or Format.HOUR_12
end

function Format.Date(date, convention)
    if convention == Format.EUROPEAN then
        return string.format("%02d/%02d/%04d", date.day, date.month, date.year)
    end
    return string.format("%02d/%02d/%04d", date.month, date.day, date.year)
end

-- Format a date range
function Format.Period(startDate, endDate, convention)
    local first = Format.Date(startDate, convention)
    local last = Format.Date(endDate, convention)
    return first == last and first or first .. " - " .. last
end

function Format.Time(hour, minute, clockFormat)
    hour = math.floor(tonumber(hour) or 0)
    minute = math.floor(tonumber(minute) or 0)
    if clockFormat == Format.HOUR_24 then return string.format("%02d:%02d", hour, minute) end
    local wrapped = hour % 24
    local period = wrapped < 12 and "AM" or "PM"
    local displayHour = wrapped % 12
    if displayHour == 0 then displayHour = 12 end
    return minute == 0 and tostring(displayHour) .. " " .. period
        or string.format("%d:%02d %s", displayHour, minute, period)
end

-- Format a chart date
function Format.AxisDate(date, convention)
    local month = string.upper(MONTH_SHORT[date.month])
    if convention == Format.EUROPEAN then return tostring(date.day) .. " " .. month end
    return month .. " " .. tostring(date.day)
end

-- List localized weekday names
function Format.Weekdays(convention)
    if convention == Format.EUROPEAN then return { "MO", "TU", "WE", "TH", "FR", "SA", "SU" } end
    return { "SU", "MO", "TU", "WE", "TH", "FR", "SA" }
end

return Format
