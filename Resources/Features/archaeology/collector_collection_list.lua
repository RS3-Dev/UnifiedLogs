-- Render the collector collection list
local CollectorCollectionList = {}
CollectorCollectionList.__index = CollectorCollectionList

local UI = require("Resources/Shared/ui/components")
local ItemGrid = require("Resources/Shared/ui/item_grid")
local ProgressStyle = require("Resources/Shared/ui/progress_style")
local CollectionGroupPanel = require("Resources/Shared/ui/collection_group_panel")

local ROW_HEIGHT = ProgressStyle.GROUP_HEIGHT
local SLOT_SIZE = 40
local SLOT_GAP = 4
local QUANTITY_MODE = ui.ObjectQuantityDisplayMode.ALWAYS or 2
local VIRTUAL_EVENT = "unifiedlogs_collectors_virtual_rows"

-- Resolve an object from an item
local function objectFromItem(item)
    if config == nil or config.Obj == nil or type(item) ~= "table" then return nil end
    local configName = tostring(item.configName or "")
    if configName ~= "" then
        local ok, object = pcall(function() return config.Obj[configName] end)
        if ok and object ~= nil then return object end
    end
    if item.id ~= nil and config.Obj.FromID ~= nil then
        local ok, object = pcall(function() return config.Obj.FromID(item.id) end)
        if ok then return object end
    end
    return nil
end

-- Build a collection record layout
local function recordLayout(record, width)
    local itemCount = type(record.items) == "table" and #record.items or 0
    if itemCount == 0 then return 0, ROW_HEIGHT end
    local gridWidth = math.max(SLOT_SIZE, width - 24)
    local columns = math.max(1, math.floor((gridWidth + SLOT_GAP) / (SLOT_SIZE + SLOT_GAP)))
    local rows = math.ceil(itemCount / columns)
    return columns, ROW_HEIGHT + rows * (SLOT_SIZE + SLOT_GAP) + 8
end

local function buildLayouts(groups, showGroupHeaders, rowWidth)
    local layouts = {}
    local contentHeight = 0
    for groupIndex, group in ipairs(groups) do
        if groupIndex > 1 then contentHeight = contentHeight + ProgressStyle.GROUP_GAP end
        if showGroupHeaders then
            layouts[#layouts + 1] = {
                kind = "header",
                group = group,
                y = contentHeight,
                height = ROW_HEIGHT,
                groupStart = true,
                groupEnd = #group.entries == 0,
            }
            contentHeight = contentHeight + ROW_HEIGHT
        end
        for rowIndex, entry in ipairs(group.entries) do
            local columns, height = recordLayout(entry.record, rowWidth)
            layouts[#layouts + 1] = {
                kind = "record",
                group = group,
                entry = entry,
                index = rowIndex,
                y = contentHeight,
                height = height,
                columns = columns,
                groupStart = not showGroupHeaders and rowIndex == 1,
                groupEnd = rowIndex == #group.entries,
            }
            contentHeight = contentHeight + height
        end
    end
    return layouts, contentHeight
end

function CollectorCollectionList.new(parent, options)
    local self = setmetatable({}, CollectorCollectionList)
    self.parent = parent
    self.options = options or {}
    self.grids = {}
    self.virtualRenderPending = false

    Event.Logic.Unsubscribe(VIRTUAL_EVENT)
    Event.Logic.Subscribe(VIRTUAL_EVENT, function()
        if not self.virtualRenderPending or self.rowScroll == nil then return end
        self.virtualRenderPending = false
        self:Refresh()
    end)
    return self
end

-- Clear collection list rows
function CollectorCollectionList:Clear()
    if self.rowScroll ~= nil then self.rowScroll.onLayout = nil end
    for _, grid in ipairs(self.grids) do
        grid:Destroy()
    end
    self.grids = {}
    if self.virtualLayer ~= nil then self.virtualLayer:Destroy() end
    self.virtualLayer = nil
    self.renderedRangeKey = nil
    self.virtualRenderPending = false
    self.layouts = nil
    if self.rowScroll ~= nil then self.rowScroll:Destroy() end
    self.rowScroll = nil
end

function CollectorCollectionList:SetData(data, preserveScroll)
    local previousY = preserveScroll and self.rowScroll ~= nil and self.rowScroll.scrollY or 0
    self:Clear()

    local groups = data.groups or {}
    local showGroupHeaders = data.showGroupHeaders == true
    local scrollY = self.options.y or 46
    local scrollHeight = math.max(120, self.parent.height - scrollY)
    local estimatedRowWidth = math.max(300, self.parent.width - 18)
    local _, requestedHeight = buildLayouts(groups, showGroupHeaders, estimatedRowWidth)

    self.rowScroll = prettyui.SimpleView.new(self.parent, {
        x = 0,
        y = scrollY,
        width = self.parent.width,
        height = scrollHeight,
        contentHeight = math.max(scrollHeight, requestedHeight),
        scrollStep = ROW_HEIGHT,
    })

    local rowWidth = math.max(300, self.rowScroll.content.width)
    local layouts, contentHeight = buildLayouts(groups, showGroupHeaders, rowWidth)
    self.rowScroll:SetContentHeight(math.max(scrollHeight, contentHeight))

    self.rowWidth, self.layouts = rowWidth, layouts
    self.scrollHeight, self.contentHeight = scrollHeight, contentHeight
    self.rowScroll.onLayout = function() self.virtualRenderPending = true end
    self.rowScroll:SetScrollPosition(preserveScroll and previousY or 0)
    self.virtualRenderPending = false
    self:Refresh()
end

function CollectorCollectionList:DrawHeader(layout)
    local group = layout.group
    CollectionGroupPanel.Header(self.virtualLayer, {
        y = layout.y,
        width = self.rowWidth,
        height = layout.height,
        title = group.name,
        titleWidth = self.rowWidth - 154,
        countLabel = tostring(group.complete) .. " / " .. tostring(#group.entries),
        countInset = 132,
        countWidth = 96,
        complete = #group.entries > 0 and group.complete == #group.entries,
        groupEnd = layout.groupEnd,
    })
end

function CollectorCollectionList:DrawRecord(layout)
    local rowWidth = self.rowWidth
    local record = layout.entry.record
    local complete = layout.entry.complete
    local y = layout.y
    UI.Rectangle(
        self.virtualLayer,
        0,
        y,
        rowWidth,
        layout.height,
        ProgressStyle.Green(complete, ProgressStyle.RowColour(layout.index), ProgressStyle.GREEN_BACKGROUND)
    )
    if complete then
        ProgressStyle.Wedge(self.virtualLayer, 1, y + 1, layout.height - 2):MoveToFront()
    end
    UI.Text(self.virtualLayer, record.collectionName, 12, y, rowWidth - 56, 26, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = ProgressStyle.Green(complete, complete and ProgressStyle.TEXT_COMPLETE or ProgressStyle.TEXT_NORMAL),
    })
    ProgressStyle.CompletionMark(
        self.virtualLayer,
        rowWidth - 26,
        y + math.floor((ROW_HEIGHT - 14) / 2),
        complete
    )
    y = y + ROW_HEIGHT

    local items = type(record.items) == "table" and record.items or nil
    if items ~= nil and #items > 0 then
        for first = 1, #items, layout.columns do
            local last = math.min(first + layout.columns - 1, #items)
            local objects = {}
            for index = first, last do
                local item = items[index]
                objects[#objects + 1] = {
                    object = objectFromItem(item),
                    tooltip = item.name,
                }
            end
            self.activeGridCount = self.activeGridCount + 1
            local grid = self.grids[self.activeGridCount]
            if grid == nil then
                grid = ItemGrid.new(self.rowScroll.content, {}, {
                    x = 12,
                    y = y,
                    columns = layout.columns,
                    slotGap = SLOT_GAP,
                    quantityMode = QUANTITY_MODE,
                    _onScrollWheel = self.rowScroll._onScrollWheel,
                })
                self.grids[self.activeGridCount] = grid
            end
            local states = {}
            for slotIndex = 1, #objects do
                states[slotIndex] = complete
            end
            grid:SetPos(12, y)
            grid:SetEntries(objects, states)
            grid:SetHidden(false)
            grid.root:MoveToFront()
            y = y + SLOT_SIZE + SLOT_GAP
        end
    end

    CollectionGroupPanel.Frame(self.virtualLayer, {
        y = layout.y,
        width = rowWidth,
        height = layout.height,
        groupStart = layout.groupStart,
        groupEnd = layout.groupEnd,
        complete = complete,
    })
end

function CollectorCollectionList:RenderRange(first, last)
    local rowWidth, layouts = self.rowWidth, self.layouts
    local scrollHeight, contentHeight = self.scrollHeight, self.contentHeight
    local key = tostring(first) .. ":" .. tostring(last)
    if self.renderedRangeKey == key then return end
    self.activeGridCount = 0
    for _, grid in ipairs(self.grids) do
        grid:SetHidden(true)
    end
    if self.virtualLayer ~= nil then self.virtualLayer:Destroy() end
    self.virtualLayer = ui.Layer.new(self.rowScroll.content)
    self.virtualLayer:SetPos(0, 0)
    self.virtualLayer:SetSize(rowWidth, math.max(scrollHeight, contentHeight))
    self.virtualLayer.clickthrough = true

    if #layouts == 0 then
        UI.Text(
            self.virtualLayer,
            self.options.emptyMessage or "No collector data is available.",
            14,
            12,
            rowWidth - 28,
            32,
            { colour = 0xC9BEA4FF }
        )
        self.renderedRangeKey = key
        return
    end
    for index = first, last do
        local layout = layouts[index]
        if layout ~= nil then
            if layout.kind == "header" then
                self:DrawHeader(layout)
            else
                self:DrawRecord(layout)
            end
        end
    end
    self.renderedRangeKey = key
end

-- Refresh collection list rows
function CollectorCollectionList:Refresh()
    local layouts = self.layouts
    if self.rowScroll == nil or self.rowScroll.root == nil then return end
    local overscan = SLOT_SIZE + SLOT_GAP
    local visibleTop = math.max(0, self.rowScroll.scrollY - overscan)
    local visibleBottom = self.rowScroll.scrollY + self.rowScroll.height + overscan
    local first, last = nil, nil
    for index, layout in ipairs(layouts) do
        if layout.y < visibleBottom and layout.y + layout.height > visibleTop then
            first = first or index
            last = index
        elseif first ~= nil and layout.y >= visibleBottom then
            break
        end
    end
    self:RenderRange(first or 1, last or 0)
end

function CollectorCollectionList:Destroy()
    Event.Logic.Unsubscribe(VIRTUAL_EVENT)
    self:Clear()
    self.parent = nil
end

return CollectorCollectionList
