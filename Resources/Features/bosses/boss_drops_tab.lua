-- Render the boss drops tab
local CollectionEntries = require("Resources/Shared/collections/collection_entries")
local UI = require("Resources/Shared/ui/components")
local GameData = require("Resources/Lib/game_data")
local NumberFormat = require("Resources/Lib/number_format")
local ItemGrid = require("Resources/Shared/ui/item_grid")
local CollectionGroupPanel = require("Resources/Shared/ui/collection_group_panel")
local ProgressStyle = require("Resources/Shared/ui/progress_style")
local ScrollableItemList = require("Resources/Shared/ui/scrollable_item_list")

local BossDropsTab = {}
BossDropsTab.__index = BossDropsTab

local HEADER_HEIGHT = 38
local GROUP_HEIGHT = ProgressStyle.GROUP_HEIGHT
local SLOT_SIZE = 40
local SLOT_GAP = 4
local MATRIX_HEAD_HEIGHT = GROUP_HEIGHT
local MATRIX_ROW_HEIGHT = ProgressStyle.GROUP_HEIGHT
local QUANTITY_MODE = ui.ObjectQuantityDisplayMode.ALWAYS or 2

local function formatTime(value, tickSeconds)
    local ticks = tonumber(value)
    if ticks == nil or ticks <= 0 then return "--" end
    local seconds = ticks * tickSeconds
    local minutes = math.floor(seconds / 60)
    local remainder = seconds - minutes * 60
    return string.format("%d:%04.1f", minutes, remainder)
end

local function formatMetric(progress, metric, tickSeconds)
    local kind = metric.kind
    if kind == "minutes_seconds" then
        local minutes = tonumber(progress:GetValue(metric.variable))
        local seconds = tonumber(progress:GetValue(metric.secondaryVariable))
        if minutes == nil and seconds == nil then return "--" end
        minutes = math.max(0, math.floor(minutes or 0))
        seconds = math.max(0, math.floor(seconds or 0))
        if minutes == 0 and seconds == 0 then return "--" end
        minutes = minutes + math.floor(seconds / 60)
        seconds = seconds % 60
        return string.format("%d:%02d", minutes, seconds)
    end
    local value = progress:GetValue(metric.variable)
    if kind == "percent" then
        local numeric = tonumber(value)
        return numeric ~= nil and numeric >= 0 and tostring(math.floor(numeric)) .. "%" or "--"
    end
    return formatTime(value, tickSeconds)
end

local function formatCount(value)
    local numeric = tonumber(value)
    return numeric ~= nil and numeric >= 0 and NumberFormat.Integer(numeric) or "--"
end

-- Build drop metric columns
local function metricColumns(records)
    local columns, seen = {}, {}
    for _, record in ipairs(records) do
        for _, metric in ipairs(type(record.metrics) == "table" and record.metrics or {}) do
            local label = tostring(metric.label or "Record")
            if not seen[label] then
                seen[label] = true
                columns[#columns + 1] = label
            end
        end
    end
    return columns
end

local function findMetric(record, label)
    for _, metric in ipairs(type(record.metrics) == "table" and record.metrics or {}) do
        if tostring(metric.label or "Record") == label then return metric end
    end
    return nil
end

function BossDropsTab.new(parent, options)
    local self = setmetatable({}, BossDropsTab)
    self.options = options
    self.progress = self.options.progress
    self.tickSeconds = tonumber(self.options.tickSeconds) or 0.6
    self.grids = {}
    self.root = ui.Layer.new(parent)
    self.root:SetPos(self.options.x or 0, self.options.y or 0)
    self.root:SetSize(self.options.width, self.options.height)
    self.root.clickthrough = true
    self.heading = UI.Text(self.root, "", 12, 2, math.max(180, self.root.width - 390), 28, {
        font = id.Font.CINZEL_18PT_BOLD,
        colour = 0xF2C66DFF,
    })
    self.killCountText = UI.Text(self.root, "", self.root.width - 264, 2, 246, 28, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = 0xF2C66DFF,
        alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
    })
    self.summary = UI.Text(self.root, "0 / 0", self.root.width - 118, 2, 100, 28, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = 0xF2C66DFF,
        alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
    })
    return self
end

function BossDropsTab:DestroyContent()
    if self.itemLedger ~= nil then self.itemLedger:Destroy() end
    self.itemLedger = nil
    for _, grid in ipairs(self.grids) do
        grid:Destroy()
    end
    self.grids = {}
    if self.scroll ~= nil then self.scroll:Destroy() end
    self.scroll = nil
end

function BossDropsTab:PrepareGroup(group, showHeader)
    return CollectionEntries.PrepareGroup(group.name, group.items, {
        getValue = function(name) return self.progress:GetValue(name) end,
        isCollected = function(entry, value) return self.progress:IsCollected(entry, value) end,
        resolveObject = GameData.CollectionObject,
        tooltip = GameData.CollectionTooltip,
        showHeader = showHeader,
        emptyText = self.options.emptyItemsText or "No collection-log items are mapped for this boss.",
    })
end

function BossDropsTab:RenderVirtualGroups(preparedGroups, rowWidth, previousY, preserveScroll)
    self.itemLedger = ScrollableItemList.new(self.scroll, {
        rowWidth = rowWidth,
        quantityMode = QUANTITY_MODE,
        emptyText = "No collection-log data matched this category.",
    })
    self.itemLedger:Update(preparedGroups, { preserveScroll = false })
    self.scroll:SetScrollPosition(preserveScroll and previousY or 0)
    self.itemLedger:Refresh()
end

function BossDropsTab:RenderRecordMatrix(records, rowWidth, y)
    local columns = metricColumns(records)
    if #records == 0 or #columns == 0 then return y end

    local matrixTop = y
    local bossWidth = math.floor(rowWidth * (#columns >= 3 and 0.34 or 0.4))
    local metricWidth = math.floor((rowWidth - bossWidth) / #columns)
    UI.Rectangle(
        self.scroll.content,
        0,
        y,
        rowWidth,
        MATRIX_HEAD_HEIGHT,
        ProgressStyle.GROUP_BACKGROUND
    )
    UI.Text(self.scroll.content, self.options.recordHeading or "BOSS", 12, y, bossWidth - 20, MATRIX_HEAD_HEIGHT, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = 0xF2C66DFF,
    })
    for columnIndex, label in ipairs(columns) do
        local x = bossWidth + (columnIndex - 1) * metricWidth
        local width = columnIndex == #columns and rowWidth - x or metricWidth
        UI.Text(
            self.scroll.content,
            string.upper(label),
            x + 10,
            y,
            width - 20,
            MATRIX_HEAD_HEIGHT,
            {
                font = id.Font.MUSEO_SANS_13PT_BOLD,
                colour = 0xF2C66DFF,
            }
        )
    end
    UI.Rectangle(
        self.scroll.content,
        0,
        y + MATRIX_HEAD_HEIGHT - 1,
        rowWidth,
        1,
        ProgressStyle.GROUP_DIVIDER
    )
    y = y + MATRIX_HEAD_HEIGHT

    for index, record in ipairs(records) do
        UI.Rectangle(
            self.scroll.content,
            0,
            y,
            rowWidth,
            MATRIX_ROW_HEIGHT,
            ProgressStyle.RowColour(index)
        )
        UI.Text(self.scroll.content, record.name, 10, y, bossWidth - 20, MATRIX_ROW_HEIGHT, {
            font = id.Font.MUSEO_SANS_13PT_BOLD,
            colour = 0xC9BEA4FF,
        })
        for columnIndex, label in ipairs(columns) do
            local x = bossWidth + (columnIndex - 1) * metricWidth
            local width = columnIndex == #columns and rowWidth - x or metricWidth
            UI.Rectangle(
                self.scroll.content,
                x,
                y,
                1,
                MATRIX_ROW_HEIGHT,
                ProgressStyle.GROUP_DIVIDER
            )
            local metric = findMetric(record, label)
            local display = metric ~= nil and formatMetric(self.progress, metric, self.tickSeconds)
                or "--"
            UI.Text(self.scroll.content, display, x + 10, y, width - 20, MATRIX_ROW_HEIGHT, {
                font = id.Font.MUSEO_SANS_13PT_BOLD,
                colour = metric ~= nil and 0xF2C66DFF or 0x756B5DFF,
            })
        end
        UI.Rectangle(
            self.scroll.content,
            0,
            y + MATRIX_ROW_HEIGHT - 1,
            rowWidth,
            1,
            ProgressStyle.ROW_DIVIDER
        )
        y = y + MATRIX_ROW_HEIGHT
    end
    ProgressStyle.Frame(self.scroll.content, 0, matrixTop, rowWidth, y - matrixTop)
    return y
end

-- Rebuild boss drop rows
function BossDropsTab:Rebuild(categoryName, groups, preserveScroll)
    local aggregate = categoryName == (self.options.aggregateLabel or "All bosses")
    local previousY = preserveScroll and self.scroll ~= nil and self.scroll.scrollY or 0
    self:DestroyContent()
    self.heading.content = aggregate and (self.options.aggregateHeading or "All boss drops")
        or categoryName .. " " .. (self.options.itemLabel or "drops")
    local summaries = {}
    -- Show kill count only for one resolved boss log
    for _, group in ipairs(#groups == 1 and groups or {}) do
        for _, metric in ipairs(type(group.killCounts) == "table" and group.killCounts or {}) do
            summaries[#summaries + 1] = tostring(metric.label or "KC")
                .. " "
                .. formatCount(self.progress:GetValue(metric.variable))
        end
    end
    self.killCountText.content = table.concat(summaries, "  |  ")
    local preparedGroups, collectedTotal, itemTotal = {}, 0, 0
    for _, group in ipairs(groups) do
        local prepared = self:PrepareGroup(group, aggregate)
        preparedGroups[#preparedGroups + 1] = prepared
        collectedTotal = collectedTotal + prepared.collected
        itemTotal = itemTotal + prepared.total
    end
    self.summary.content = tostring(collectedTotal) .. " / " .. tostring(itemTotal)
    self.summary.hidden = not aggregate

    local scrollHeight = math.max(120, self.root.height - HEADER_HEIGHT)
    self.scroll = prettyui.SimpleView.new(self.root, {
        x = 0,
        y = HEADER_HEIGHT,
        width = self.root.width,
        height = scrollHeight,
        contentHeight = scrollHeight,
        scrollStep = SLOT_SIZE + SLOT_GAP,
    })
    local rowWidth = math.max(300, self.root.width - 18)
    if aggregate then
        self:RenderVirtualGroups(preparedGroups, rowWidth, previousY, preserveScroll)
        return
    end
    local y = 0
    local pageRecords = {}
    if #groups > 1 then
        for _, group in ipairs(groups) do
            for _, record in ipairs(type(group.records) == "table" and group.records or {}) do
                pageRecords[#pageRecords + 1] = record
            end
        end
    end
    local hasPageMatrix = #pageRecords > 1
    if hasPageMatrix and self.options.showPersonalBests ~= false then
        y = self:RenderRecordMatrix(pageRecords, rowWidth, y)
        y = y + 8
    end
    for groupIndex, group in ipairs(groups) do
        local prepared = preparedGroups[groupIndex]
        local collected, objects, states = prepared.collected, prepared.objects, prepared.states

        local records = hasPageMatrix and {}
            or (type(group.records) == "table" and group.records or {})
        if self.options.showPersonalBests ~= false then
            y = self:RenderRecordMatrix(records, rowWidth, y)
        end

        local groupComplete = #group.items > 0 and collected >= #group.items
        CollectionGroupPanel.Header(self.scroll.content, {
            x = 0,
            y = y,
            width = rowWidth,
            title = #records > 0 and (group.name .. " " .. (self.options.itemLabel or "drops")) or group.name,
            collected = collected,
            total = #group.items,
            complete = groupComplete,
            showProgress = true,
        })
        y = y + GROUP_HEIGHT

        local gridWidth = math.max(SLOT_SIZE, rowWidth - 24)
        local columns = math.max(1, math.floor((gridWidth + SLOT_GAP) / (SLOT_SIZE + SLOT_GAP)))
        local rows = math.ceil(#group.items / columns)
        local bodyHeight = rows > 0 and (8 + rows * SLOT_SIZE + math.max(0, rows - 1) * SLOT_GAP)
            or 40
        CollectionGroupPanel.Body(self.scroll.content, {
            x = 0,
            y = y,
            width = rowWidth,
            height = bodyHeight,
            complete = groupComplete,
            groupEnd = true,
        })
        if rows > 0 then
            for row = 1, rows do
                local first = (row - 1) * columns + 1
                local last = math.min(first + columns - 1, #group.items)
                local rowObjects = {}
                for index = first, last do
                    rowObjects[#rowObjects + 1] = objects[index]
                end
                local grid = ItemGrid.new(self.scroll.content, rowObjects, {
                    x = 12,
                    y = y + 4 + (row - 1) * (SLOT_SIZE + SLOT_GAP),
                    columns = #rowObjects,
                    slotGap = SLOT_GAP,
                    quantityMode = QUANTITY_MODE,
                    _onScrollWheel = self.scroll._onScrollWheel,
                })
                for index = first, last do
                    local slot = grid:GetSlot(index - first + 1)
                    if slot ~= nil then slot:SetDisabled(not states[index]) end
                end
                self.grids[#self.grids + 1] = grid
            end
        else
            UI.Text(
                self.scroll.content,
                self.options.emptyItemsText or "No collection-log items are mapped for this boss.",
                14,
                y,
                rowWidth - 28,
                bodyHeight,
                { colour = 0xC9BEA4FF }
            )
        end
        y = y + bodyHeight + ProgressStyle.GROUP_GAP
    end
    if #groups == 0 then
        UI.Text(
            self.scroll.content,
            "No collection-log data matched this category.",
            14,
            12,
            rowWidth - 28,
            32,
            { colour = 0xC9BEA4FF }
        )
        y = 56
    end
    self.scroll:SetContentHeight(math.max(scrollHeight, y))
    if preserveScroll then self.scroll:SetScrollPosition(previousY) end
end

function BossDropsTab:Destroy()
    self:DestroyContent()
    if self.root ~= nil then self.root:Destroy() end
    self.root = nil
    self.killCountText = nil
    self.summary = nil
end

return BossDropsTab
