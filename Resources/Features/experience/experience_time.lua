-- Convert the client UTC minute counter without local-time adjustment
local ExperienceTime = {}

-- Check whether a year is a leap year
local function isLeapYear(year) return year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0) end

-- Count days in a month
local function daysInMonth(year, month)
    if month == 2 then return isLeapYear(year) and 29 or 28 end
    if month == 4 or month == 6 or month == 9 or month == 11 then return 30 end
    return 31
end

ExperienceTime.IsLeapYear = isLeapYear
ExperienceTime.DaysInMonth = daysInMonth

-- Count days before a year
local function daysBeforeYear(year)
    local days = 0
    if year >= 1970 then
        for current = 1970, year - 1 do
            days = days + (isLeapYear(current) and 366 or 365)
        end
    else
        for current = year, 1969 do
            days = days - (isLeapYear(current) and 366 or 365)
        end
    end
    return days
end

-- Convert a date to epoch minutes
function ExperienceTime.DateToMinute(date)
    local year = math.floor(tonumber(date and date.year) or 1970)
    local month = math.max(1, math.min(12, math.floor(tonumber(date and date.month) or 1)))
    local day = math.max(
        1,
        math.min(daysInMonth(year, month), math.floor(tonumber(date and date.day) or 1))
    )
    local days = daysBeforeYear(year)
    for current = 1, month - 1 do
        days = days + daysInMonth(year, current)
    end
    return (days + day - 1) * 1440
end

local DISPLAY_ORDINAL_BASE = ExperienceTime.DateToMinute({ year = 2000, month = 1, day = 1 })

function ExperienceTime.NormalizeDate(date, fallback, minimumYear, maximumYear)
    fallback = fallback or { year = 1970, month = 1, day = 1 }
    minimumYear = tonumber(minimumYear) or 1970
    maximumYear = tonumber(maximumYear) or 9999
    local year = math.max(
        minimumYear,
        math.min(maximumYear, math.floor(tonumber(date and date.year) or fallback.year))
    )
    local month =
        math.max(1, math.min(12, math.floor(tonumber(date and date.month) or fallback.month)))
    local day = math.max(
        1,
        math.min(daysInMonth(year, month), math.floor(tonumber(date and date.day) or fallback.day))
    )
    return { year = year, month = month, day = day }
end

-- Copy a date value
function ExperienceTime.CloneDate(date)
    return { year = date.year, month = date.month, day = date.day }
end

-- Convert a date to an ordinal
function ExperienceTime.DateOrdinal(date)
    return math.floor((ExperienceTime.DateToMinute(date) - DISPLAY_ORDINAL_BASE) / 1440)
end

-- Convert an ordinal to a date
function ExperienceTime.DateFromOrdinal(ordinal)
    return ExperienceTime.MinuteToDate(
        DISPLAY_ORDINAL_BASE + math.max(0, math.floor(tonumber(ordinal) or 0)) * 1440
    )
end

-- Count days in a date range
function ExperienceTime.RangeLength(startDate, endDate)
    return math.max(
        1,
        ExperienceTime.DateOrdinal(endDate) - ExperienceTime.DateOrdinal(startDate) + 1
    )
end

-- Convert epoch minutes to a date
function ExperienceTime.MinuteToDate(value)
    local remaining = math.floor((tonumber(value) or 0) / 1440)
    local year = 1970
    if remaining >= 0 then
        while remaining >= (isLeapYear(year) and 366 or 365) do
            remaining = remaining - (isLeapYear(year) and 366 or 365)
            year = year + 1
        end
    else
        repeat
            year = year - 1
            remaining = remaining + (isLeapYear(year) and 366 or 365)
        until remaining >= 0
    end
    local month = 1
    while remaining >= daysInMonth(year, month) do
        remaining = remaining - daysInMonth(year, month)
        month = month + 1
    end
    return { year = year, month = month, day = remaining + 1 }
end

-- Get the following date
function ExperienceTime.NextDate(date)
    local nextDate = { year = date.year, month = date.month, day = date.day + 1 }
    if nextDate.day > daysInMonth(nextDate.year, nextDate.month) then
        nextDate.day = 1
        nextDate.month = nextDate.month + 1
        if nextDate.month > 12 then
            nextDate.month = 1
            nextDate.year = nextDate.year + 1
        end
    end
    return nextDate
end

-- Move a date by a number of days
function ExperienceTime.AddDays(date, amount)
    return ExperienceTime.MinuteToDate(
        ExperienceTime.DateToMinute(date) + (tonumber(amount) or 0) * 1440
    )
end

-- Build a daily storage key
function ExperienceTime.DateKey(date)
    return string.format("%04d-%02d-%02d", date.year, date.month, date.day)
end

-- Build a monthly storage key
function ExperienceTime.MonthKey(date) return string.format("%04d-%02d", date.year, date.month) end

-- Build a monthly key from epoch minutes
function ExperienceTime.MonthKeyFromMinute(minute)
    return ExperienceTime.MonthKey(ExperienceTime.MinuteToDate(minute))
end

-- List monthly keys in a range
function ExperienceTime.MonthKeys(startDate, endDate)
    local keys = {}
    local year, month = startDate.year, startDate.month
    while year < endDate.year or year == endDate.year and month <= endDate.month do
        keys[#keys + 1] = string.format("%04d-%02d", year, month)
        month = month + 1
        if month > 12 then
            month, year = 1, year + 1
        end
    end
    return keys
end

return ExperienceTime
