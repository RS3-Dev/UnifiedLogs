-- Render XP history charts
local UI = require("Resources/Shared/ui/components")
local ExperienceTime = require("Resources/Features/experience/experience_time")
local DateTimeFormat = require("Resources/Lib/date_time_format")

local ExperienceChart = {}
ExperienceChart.__index = ExperienceChart

local GOLD = 0xF2C66DFF
local MUTED = 0x928776FF
local HEADER = 0x2A231BFF
local AXIS_HEIGHT = 18
local SMALL_FONT = id.Font.MUSEO_SANS_11PT_REGULAR

-- Build chart axis labels
local function axisLabels(startDate, endDate, dateFormat, timeFormat)
    local days = ExperienceTime.RangeLength(startDate, endDate)
    if days == 1 then
        return {
            DateTimeFormat.Time(0, 0, timeFormat),
            DateTimeFormat.Time(6, 0, timeFormat),
            DateTimeFormat.Time(12, 0, timeFormat),
            DateTimeFormat.Time(18, 0, timeFormat),
            DateTimeFormat.Time(24, 0, timeFormat),
        }
    end
    local labels = {}
    local firstOrdinal = ExperienceTime.DateOrdinal(startDate)
    for index = 0, 4 do
        local offset = math.floor((days - 1) * index / 4 + 0.5)
        labels[#labels + 1] = DateTimeFormat.AxisDate(
            ExperienceTime.DateFromOrdinal(firstOrdinal + offset),
            dateFormat
        )
    end
    return labels
end

-- Round the chart maximum
local function roundedMaximum(value)
    local maximum = math.max(0, tonumber(value) or 0)
    if maximum <= 0 then return 4 end

    -- Round the scale to a readable step
    local target = maximum * 1.08
    local magnitude = 1
    while target >= magnitude * 10 do
        magnitude = magnitude * 10
    end
    while target < magnitude do
        magnitude = magnitude / 10
    end

    local normalized = target / magnitude
    local factors = { 1, 1.25, 1.5, 2, 2.5, 3, 4, 5, 7.5, 10 }
    for _, factor in ipairs(factors) do
        if normalized <= factor then return math.max(4, factor * magnitude) end
    end
    return math.max(4, 10 * magnitude)
end

-- Format a compact number
local function shortNumber(value)
    local number = tonumber(value) or 0
    if number >= 1000000 then return string.format("%.1fm", number / 1000000) end
    if number >= 1000 then return tostring(math.floor(number / 1000)) .. "k" end
    return tostring(math.floor(number))
end

-- Find the tallest stacked bar; history supplies one bucket per segment
local function stackedMaximum(series, segmentCount)
    local maximum = 0
    for bucket = 1, segmentCount do
        local total = 0
        for _, skill in ipairs(series) do
            total = total + skill.buckets[bucket]
        end
        if total > maximum then maximum = total end
    end
    return roundedMaximum(maximum)
end

-- Count legend rows for the overall chart
local function legendRowCount(series, width)
    local rows, used = 1, 0
    for _, skill in ipairs(series) do
        local itemWidth = math.max(79, #skill.name * 7 + 29)
        if used > 0 and used + itemWidth > width - 24 then
            rows = rows + 1
            used = 0
        end
        used = used + itemWidth
    end
    return rows
end

-- Create a chart whose frame is built once and whose data is bound by Update
function ExperienceChart.new(parent, options)
    local width, height = options.width, options.height
    local self = setmetatable({
        width = width,
        height = height,
        formatNumber = assert(options.formatNumber),
        segments = {},
        legend = {},
        gridLines = {},
        gridLabels = {},
        axisLabels = {},
    }, ExperienceChart)
    self.root = ui.Layer.new(parent)
    self.root:SetPos(options.x or 0, options.y or 0)
    self.root:SetSize(width, height)
    self.root.clickthrough = true
    local root = self.root

    UI.Rectangle(root, 0, 0, width, height, 0x100E0BFF)
    UI.Frame(root, 0, 0, width, height, 0x403528FF)
    UI.Rectangle(root, 1, 1, width - 2, 27, HEADER)
    UI.Rectangle(root, 1, 28, width - 2, 1, 0x352C21FF)
    local readoutWidth = math.min(260, math.max(150, math.floor(width * 0.42)))
    self.title = UI.Text(root, "", 12, 1, width - readoutWidth - 30, 27, {
        font = id.Font.CINZEL_13PT_BOLD,
        colour = 0xEDDBB9FF,
        alignVertical = ui.AlignMode.CENTRE,
    })
    self.hoverReadout = UI.Text(root, "", width - readoutWidth - 12, 1, readoutWidth, 27, {
        font = SMALL_FONT,
        colour = GOLD,
        alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
        alignVertical = ui.AlignMode.CENTRE,
    })
    self.plotLeft = ui.Rectangle.new(root)
    self.plotBottom = ui.Rectangle.new(root)
    for index = 1, 5 do
        self.gridLines[index] = ui.Rectangle.new(root)
        self.gridLabels[index] = ui.Text.new(root)
        self.axisLabels[index] = ui.Text.new(root)
    end
    self.emptyText = ui.Text.new(root)
    self.hoverOutline = ui.Rectangle.new(root)
    self.hoverOutline.fill = false
    self.hoverOutline.outlineThickness = 1
    self.hoverOutline.rgba = GOLD
    self.hoverOutline.clickthrough = true
    self.hoverOutline.hidden = true
    return self
end

-- Show the hover readout for one bar segment
function ExperienceChart:ShowHover(slot)
    self.hovered, self.hoveredKey = slot, slot.key
    self.hoverReadout.content = slot.skillName .. "  |  " .. self.formatNumber(slot.value) .. " XP"
    self.hoverOutline:SetPos(slot.x, slot.y)
    self.hoverOutline:SetSize(slot.width, slot.height)
    self.hoverOutline.hidden = false
    self.hoverOutline:MoveToFront()
end

function ExperienceChart:HideHover()
    self.hovered = nil
    self.hoverReadout.content = ""
    self.hoverOutline.hidden = true
end

-- Reuse or create a bar segment whose hover handlers read its current data
function ExperienceChart:Segment(index)
    local slot = self.segments[index]
    if slot ~= nil then return slot end
    slot = { rectangle = ui.Rectangle.new(self.root) }
    slot.rectangle:Subscribe(ui.Hook.ONMOUSEOVER, function()
        self:ShowHover(slot)
        return true
    end)
    slot.rectangle:Subscribe(ui.Hook.ONMOUSELEAVE, function()
        if self.hovered == slot then self:HideHover() end
        return true
    end)
    self.segments[index] = slot
    return slot
end

function ExperienceChart:DrawGrid(plot, maximum)
    for grid = 0, 4 do
        local gridY = plot.y + plot.height - 1 - math.floor(grid * (plot.height - 1) / 4)
        local colour = grid == 0 and 0x493C2DFF or 0x261F18FF
        UI.BindRectangle(self.gridLines[grid + 1], plot.x, gridY, plot.width, 1, colour)
        local label = shortNumber(maximum * grid / 4)
        UI.BindText(self.gridLabels[grid + 1], label, 5, gridY - 8, 38, 16, {
            font = SMALL_FONT,
            colour = 0x746C60FF,
            alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
        })
    end
end

-- Bind stacked bars and hide segments left over from earlier data
function ExperienceChart:DrawBars(plot, series, segmentCount, maximum)
    local gap = segmentCount > 20 and 3 or 5
    local barWidth =
        math.max(3, math.floor((plot.width - 14 - gap * (segmentCount - 1)) / segmentCount))
    local barsWidth = barWidth * segmentCount + gap * (segmentCount - 1)
    local barX = plot.x + math.max(6, math.floor((plot.width - barsWidth) / 2))
    local used = 0
    for bucket = 1, segmentCount do
        local bottom = plot.y + plot.height - 1
        for _, skill in ipairs(series) do
            local value = skill.buckets[bucket]
            local segmentHeight = value > 0
                    and math.max(1, math.floor(value / maximum * (plot.height - 5)))
                or 0
            if segmentHeight > 0 then
                bottom = bottom - segmentHeight
                used = used + 1
                local slot = self:Segment(used)
                slot.x, slot.y, slot.width, slot.height = barX, bottom, barWidth, segmentHeight
                slot.value, slot.skillName = value, string.upper(skill.name)
                slot.key = bucket .. ":" .. tostring(skill.id)
                local rectangle = slot.rectangle
                UI.BindRectangle(rectangle, barX, bottom, barWidth, segmentHeight, skill.colour)
                rectangle.clickthrough = false
            end
        end
        barX = barX + barWidth + gap
    end
    for index = used + 1, #self.segments do
        self.segments[index].rectangle.hidden = true
    end
    return used
end

function ExperienceChart:DrawAxis(plot, options)
    local axisY = plot.y + plot.height
    local labels =
        axisLabels(options.startDate, options.endDate, options.dateFormat, options.timeFormat)
    for index, label in ipairs(labels) do
        local tickX = plot.x + math.floor((index - 1) * (plot.width - 1) / 4)
        local labelX = math.max(plot.x, math.min(plot.x + plot.width - 42, tickX - 21))
        UI.BindText(self.axisLabels[index], label, labelX, axisY, 42, AXIS_HEIGHT, {
            font = SMALL_FONT,
            colour = 0x71695DFF,
            alignHorizontal = ui.AlignMode.CENTRE,
        })
    end
end

-- Bind legend entries and hide entries left over from earlier data
function ExperienceChart:DrawLegend(series, legendHeight)
    local legendX = 12
    local legendY = self.height - legendHeight + 1
    for index, skill in ipairs(series) do
        local labelWidth = math.max(62, #skill.name * 7 + 12)
        if legendX > 12 and legendX + labelWidth + 17 > self.width - 12 then
            legendX = 12
            legendY = legendY + 22
        end
        local item = self.legend[index]
        if item == nil then
            item = { swatch = ui.Rectangle.new(self.root), label = ui.Text.new(self.root) }
            self.legend[index] = item
        end
        UI.BindRectangle(item.swatch, legendX, legendY + 8, 7, 7, skill.colour)
        UI.BindText(item.label, skill.name, legendX + 11, legendY, labelWidth, 23, {
            font = SMALL_FONT,
            colour = 0xA59A88FF,
        })
        legendX = legendX + labelWidth + 17
    end
    for index = #series + 1, #self.legend do
        self.legend[index].swatch.hidden = true
        self.legend[index].label.hidden = true
    end
end

-- Bind new chart data to the existing components
function ExperienceChart:Update(options)
    local series, selectedSkill = options.series or {}, options.selectedSkill
    local segmentCount = options.segmentCount or 30
    self.title.content = selectedSkill == nil and "OVERALL XP HISTORY"
        or string.upper(selectedSkill.name) .. " HISTORY"
    local legendRows = selectedSkill == nil and #series > 0 and legendRowCount(series, self.width)
        or 0
    local legendHeight = selectedSkill == nil and math.max(16, 12 + legendRows * 22) or 12
    local plot = {
        x = 48,
        y = 36,
        width = self.width - 60,
        height = self.height - AXIS_HEIGHT - legendHeight - 44,
    }
    UI.BindRectangle(self.plotLeft, plot.x, plot.y, 1, plot.height, 0x493C2DFF)
    UI.BindRectangle(self.plotBottom, plot.x, plot.y + plot.height - 1, plot.width, 1, 0x493C2DFF)
    local maximum = stackedMaximum(series, segmentCount)
    self:DrawGrid(plot, maximum)
    local used = self:DrawBars(plot, series, segmentCount, maximum)
    UI.BindText(
        self.emptyText,
        "No XP gains recorded in this period.",
        plot.x + 16,
        plot.y + math.floor(plot.height / 2) - 14,
        plot.width - 32,
        28,
        {
            font = SMALL_FONT,
            colour = MUTED,
            alignHorizontal = ui.AlignMode.CENTRE,
            alignVertical = ui.AlignMode.CENTRE,
        }
    )
    self.emptyText.hidden = #series > 0
    self:DrawAxis(plot, options)
    self:DrawLegend(selectedSkill == nil and series or {}, legendHeight)

    -- Keep the readout only while the hovered slot still shows the same bar
    local hovered = self.hovered
    if hovered ~= nil then
        local index
        for slotIndex = 1, used do
            if self.segments[slotIndex] == hovered then index = slotIndex end
        end
        if index ~= nil and hovered.key == self.hoveredKey then
            self:ShowHover(hovered)
        else
            self:HideHover()
        end
    end
    self.hoverReadout:MoveToFront()
end

function ExperienceChart:Destroy()
    if self.root ~= nil then self.root:Destroy() end
    self.root = nil
    self.segments, self.legend, self.hovered = {}, {}, nil
end

return ExperienceChart
