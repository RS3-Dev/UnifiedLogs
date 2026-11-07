-- Select XP history date ranges
local UI = require("Resources/Shared/ui/components")
local ExperienceTime = require("Resources/Features/experience/experience_time")
local DateTimeFormat = require("Resources/Lib/date_time_format")

local DateRangePicker = {}

DateRangePicker.WIDTH = 220
DateRangePicker.HEIGHT = 300

local GOLD = 0xF2C66DFF
local MUTED = 0x928776FF
local MONTH_NAMES = {
    "JANUARY",
    "FEBRUARY",
    "MARCH",
    "APRIL",
    "MAY",
    "JUNE",
    "JULY",
    "AUGUST",
    "SEPTEMBER",
    "OCTOBER",
    "NOVEMBER",
    "DECEMBER",
}

function DateRangePicker.Build(parent, options)
    local width = options.width or DateRangePicker.WIDTH
    local height = options.height or DateRangePicker.HEIGHT
    local year, month = options.year, options.month
    local startDate, endDate = options.startDate, options.endDate
    local pendingStartDate = options.pendingStartDate
    local dateFormat = options.dateFormat
    local gainDates = options.gainDates or {}

    local sheet = ui.Layer.new(parent)
    sheet:SetPos(options.x or 0, options.y or 0)
    sheet:SetSize(width, height)
    sheet.clickthrough = false
    UI.Rectangle(sheet, 0, 0, width, height, 0xBC9148FF)
    UI.Rectangle(sheet, 1, 1, width - 2, height - 2, 0x17140FFF)
    UI.Rectangle(sheet, 1, 1, width - 2, 34, 0x30281EFF)

    -- Escape less-than characters parsed as markup
    UI.ClickableText(sheet, "<lt>", 7, 4, 28, 26, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = 0xC9B889FF,
        action = function() options.onNavigate(-1) end,
    })
    UI.ClickableText(sheet, ">", width - 35, 4, 28, 26, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = 0xC9B889FF,
        action = function() options.onNavigate(1) end,
    })
    UI.Text(sheet, MONTH_NAMES[month] .. " " .. tostring(year), 36, 2, width - 72, 30, {
        font = id.Font.CINZEL_13PT_BOLD,
        colour = 0xF0DCA6FF,
        alignHorizontal = ui.AlignMode.CENTRE,
    })

    local weekdays = DateTimeFormat.Weekdays(dateFormat)
    local inset, gap = 8, 2
    local cellWidth = math.floor((width - inset * 2 - gap * 6) / 7)
    for index, name in ipairs(weekdays) do
        UI.Text(
            sheet,
            name,
            inset + (index - 1) * (cellWidth + gap),
            38,
            cellWidth,
            16,
            { colour = MUTED, alignHorizontal = ui.AlignMode.CENTRE }
        )
    end

    local firstDate = { year = year, month = month, day = 1 }
    local weekOffset = dateFormat == DateTimeFormat.EUROPEAN and 5 or 6
    local leading = (ExperienceTime.DateOrdinal(firstDate) + weekOffset) % 7
    local previousMonth, previousYear = month - 1, year
    if previousMonth < 1 then
        previousMonth, previousYear = 12, previousYear - 1
    end
    local previousDays = ExperienceTime.DaysInMonth(previousYear, previousMonth)
    local currentDays = ExperienceTime.DaysInMonth(year, month)
    local appliedStart = ExperienceTime.DateOrdinal(startDate)
    local appliedEnd = ExperienceTime.DateOrdinal(endDate)
    local pendingOrdinal = pendingStartDate ~= nil and ExperienceTime.DateOrdinal(pendingStartDate)
        or nil

    for cell = 1, 42 do
        local column = (cell - 1) % 7
        local row = math.floor((cell - 1) / 7)
        local cellX = inset + column * (cellWidth + gap)
        local cellY = 56 + row * 27
        local day = cell - leading
        if day < 1 then
            UI.Text(
                sheet,
                tostring(previousDays + day),
                cellX,
                cellY,
                cellWidth,
                25,
                { colour = 0x514B43FF, alignHorizontal = ui.AlignMode.CENTRE }
            )
        elseif day > currentDays then
            UI.Text(
                sheet,
                tostring(day - currentDays),
                cellX,
                cellY,
                cellWidth,
                25,
                { colour = 0x514B43FF, alignHorizontal = ui.AlignMode.CENTRE }
            )
        else
            local selectedDate = { year = year, month = month, day = day }
            local ordinal = ExperienceTime.DateOrdinal(selectedDate)
            local inRange = pendingOrdinal == nil
                and ordinal >= appliedStart
                and ordinal <= appliedEnd
            local endpoint = pendingOrdinal ~= nil and ordinal == pendingOrdinal
                or pendingOrdinal == nil and (ordinal == appliedStart or ordinal == appliedEnd)
            if inRange then
                UI.Rectangle(
                    sheet,
                    cellX,
                    cellY,
                    cellWidth,
                    25,
                    endpoint and 0x4B3A24FF or 0x33291CFF
                )
            end
            if endpoint then UI.Frame(sheet, cellX, cellY, cellWidth, 25, 0xD2A54DFF) end
            UI.ClickableText(sheet, tostring(day), cellX, cellY, cellWidth, 25, {
                colour = endpoint and 0xFFF0BDFF or (inRange and 0xF0DEC0FF or 0xB9AE9AFF),
                alignHorizontal = ui.AlignMode.CENTRE,
                action = function() options.onSelect(selectedDate) end,
            })
            if gainDates[ExperienceTime.DateKey(selectedDate)] then
                UI.Rectangle(
                    sheet,
                    cellX + math.floor(cellWidth / 2) - 1,
                    cellY + 20,
                    3,
                    3,
                    0xB78F43FF
                )
            end
        end
    end

    UI.Rectangle(sheet, 8, 222, width - 16, 1, 0x3C3226FF)
    UI.Text(sheet, "START", 10, 230, 96, 14, { colour = MUTED })
    UI.Text(sheet, "END", 112, 230, 98, 14, { colour = MUTED })
    local shownStart = pendingStartDate or startDate
    UI.Text(sheet, DateTimeFormat.Date(shownStart, dateFormat), 10, 245, 96, 21, {
        font = id.Font.MUSEO_SANS_11PT_REGULAR,
        colour = 0xE9D8B5FF,
    })
    UI.Text(
        sheet,
        pendingStartDate ~= nil and "Choose a date" or DateTimeFormat.Date(endDate, dateFormat),
        112,
        245,
        98,
        21,
        {
            font = id.Font.MUSEO_SANS_11PT_REGULAR,
            colour = pendingStartDate ~= nil and GOLD or 0xE9D8B5FF,
            maxLines = 1,
        }
    )
    UI.Text(
        sheet,
        pendingStartDate ~= nil and "Now select the end date."
            or "Select a start date, then an end date.",
        10,
        270,
        width - 20,
        19,
        {
            font = id.Font.MUSEO_SANS_11PT_REGULAR,
            colour = 0x82796BFF,
            alignHorizontal = ui.AlignMode.CENTRE,
        }
    )
    sheet:MoveToFront()
    return sheet
end

return DateRangePicker
