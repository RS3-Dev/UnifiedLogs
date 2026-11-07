-- Render the scrollable item list
local UI = require("Resources/Shared/ui/components")
local ProgressStyle = require("Resources/Shared/ui/progress_style")
local ItemGrid = require("Resources/Shared/ui/item_grid")

-- Pool visible rows for item-only collection logs
local ScrollableItemList = {}
ScrollableItemList.__index = ScrollableItemList

local SLOT_SIZE = 40
local SLOT_GAP = 4
local BODY_TOP_PADDING = 4
local BODY_BOTTOM_PADDING = 4

-- Set list visibility
local function setVisible(component, visible) component.hidden = not visible end

function ScrollableItemList:_CreateRowSlot()
    local parent = ui.Layer.new(self.scroll.content)
    parent.clickthrough = true
    local slot = {
        root = parent,
        background = ui.Rectangle.new(parent),
        title = ui.Text.new(parent),
        count = ui.Text.new(parent),
        completionMark = ProgressStyle.CompletionMark(parent, 0, 0, false),
        wedge = ui.Rectangle.new(parent),
        borderTop = ui.Rectangle.new(parent),
        borderBottom = ui.Rectangle.new(parent),
        borderLeft = ui.Rectangle.new(parent),
        borderRight = ui.Rectangle.new(parent),
    }
    slot.background.fill = true
    slot.background.clickthrough = true
    slot.title.clickthrough = true
    slot.count.clickthrough = true
    slot.wedge.fill = true
    slot.wedge.clickthrough = true
    for _, border in ipairs({
        slot.borderTop,
        slot.borderBottom,
        slot.borderLeft,
        slot.borderRight,
    }) do
        border.fill = true
        border.clickthrough = true
    end
    self.rowPool[#self.rowPool + 1] = slot
    return slot
end

function ScrollableItemList:_HideRowSlot(slot)
    slot.root.hidden = true
    if slot.grid ~= nil then slot.grid:SetHidden(true) end
end

function ScrollableItemList:_CreateGrid(slot)
    local grid = ItemGrid.new(slot.root, {}, {
        x = self.itemInset,
        y = 0,
        columns = self.columns,
        slotGap = self.slotGap,
        quantityMode = self.quantityMode,
        _onScrollWheel = self.scroll._onScrollWheel,
        -- Use the scroll view's tooltip context instead of the short pooled row.
        _tooltipParent = self.scroll.content,
        _tooltipOffset = function() return slot.root.x or 0, slot.root.y or 0 end,
    })
    slot.grid = grid
    return grid
end

function ScrollableItemList:_RenderRow(slot, row)
    slot.root:SetPos(0, row.y)
    slot.root:SetSize(self.rowWidth, row.height)
    slot.root.hidden = false
    local y = 0
    local width = self.rowWidth
    local complete = row.complete == true
    UI.BindRectangle(
        slot.background,
        0,
        y,
        width,
        row.height,
        ProgressStyle.Green(complete,
            row.kind == "header" and ProgressStyle.GROUP_BACKGROUND or ProgressStyle.ROW_ODD,
            row.kind == "header" and ProgressStyle.GREEN_HEADER or ProgressStyle.GREEN_BACKGROUND)
    )
    setVisible(slot.title, false)
    setVisible(slot.count, false)
    setVisible(slot.completionMark, false)
    setVisible(slot.wedge, false)
    setVisible(slot.borderTop, false)

    if complete and row.showProgress ~= false then
        UI.BindRectangle(
            slot.wedge,
            1,
            y + (row.kind == "header" and 1 or 0),
            ProgressStyle.COMPLETE_WEDGE_WIDTH,
            row.height - (row.kind == "header" and 2 or 0),
            ProgressStyle.COMPLETE_WEDGE
        )
        slot.wedge:MoveToFront()
    end

    if row.kind == "header" then
        UI.BindText(slot.title, row.group.name, 12, y, math.max(40, width - 182), row.height, {
            colour = ProgressStyle.Green(complete, 0xF2C66DFF, 0xF2C66DFF),
            font = id.Font.MUSEO_SANS_13PT_BOLD,
            alignHorizontal = ui.AlignMode.TOPLEFT,
        })
        local label = row.showProgress ~= false
                and (tostring(row.group.collected or 0) .. "/" .. tostring(row.group.total or 0))
            or (tostring(row.group.total or 0) .. " items")
        local countRight = row.showProgress ~= false and 42 or 12
        UI.BindText(slot.count, label, width - 154, y, 142 - countRight + 12, row.height, {
            colour = ProgressStyle.Green(complete,
                complete and ProgressStyle.PROGRESS_COMPLETE or ProgressStyle.PROGRESS_ACTIVE, 0xF2C66DFF),
            alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
            font = id.Font.MUSEO_SANS_13PT_BOLD,
        })
        if row.showProgress ~= false then
            ProgressStyle.PositionCompletionMark(
                slot.completionMark,
                width - 26,
                y + math.floor((row.height - 14) / 2)
            )
            ProgressStyle.SetCompletionMark(slot.completionMark, complete)
            slot.completionMark:MoveToFront()
        end
    elseif row.kind == "empty" then
        UI.BindText(slot.title, row.message, 14, y, width - 28, row.height, {
            colour = 0xC9BEA4FF,
            font = id.Font.MUSEO_SANS_13PT_BOLD,
            alignHorizontal = ui.AlignMode.TOPLEFT,
        })
    end

    if row.groupStart then
        UI.BindRectangle(slot.borderTop, 0, y, width, 1, ProgressStyle.GROUP_BORDER)
        slot.borderTop:MoveToFront()
    end
    UI.BindRectangle(slot.borderLeft, 0, y, 1, row.height, ProgressStyle.GROUP_BORDER)
    UI.BindRectangle(slot.borderRight, width - 1, y, 1, row.height, ProgressStyle.GROUP_BORDER)
    UI.BindRectangle(
        slot.borderBottom,
        0,
        y + row.height - 1,
        width,
        1,
        row.groupEnd and ProgressStyle.GROUP_BORDER
            or (row.kind == "header" and ProgressStyle.GROUP_DIVIDER or ProgressStyle.ROW_DIVIDER)
    )
    slot.borderLeft:MoveToFront()
    slot.borderRight:MoveToFront()
    slot.borderBottom:MoveToFront()
    if ProgressStyle.greenLogEnabled and complete then
        slot.wedge.rgba = slot.background.rgba
        for _, border in ipairs({slot.borderTop, slot.borderBottom, slot.borderLeft, slot.borderRight}) do
            border.rgba = slot.background.rgba
        end
    end
end

function ScrollableItemList:_BuildRows(groups)
    local rows = {}
    local y = self.startY
    for groupIndex, group in ipairs(groups or {}) do
        if groupIndex > 1 then y = y + self.groupGap end
        local total = tonumber(group.total) or #(group.objects or {})
        local collected = tonumber(group.collected) or 0
        local showProgress = group.showProgress ~= false
        local complete = showProgress and total > 0 and collected >= total
        local showHeader = group.showHeader ~= false
        local groupStartIndex = #rows + 1

        if showHeader then
            rows[#rows + 1] = {
                kind = "header",
                group = group,
                y = y,
                height = ProgressStyle.GROUP_HEIGHT,
                complete = complete,
                showProgress = showProgress,
            }
            y = y + ProgressStyle.GROUP_HEIGHT
        end

        local objects = group.objects or {}
        if #objects == 0 then
            rows[#rows + 1] = {
                kind = "empty",
                group = group,
                y = y,
                height = 40,
                complete = complete,
                showProgress = showProgress,
                message = group.emptyText or self.emptyText,
            }
            y = y + 40
        else
            for first = 1, #objects, self.columns do
                local last = math.min(first + self.columns - 1, #objects)
                local rowObjects, rowStates = {}, {}
                for index = first, last do
                    rowObjects[#rowObjects + 1] = objects[index]
                    local state = true
                    if group.states ~= nil and group.states[index] ~= nil then
                        -- Preserve explicit false values
                        state = group.states[index]
                    end
                    rowStates[#rowStates + 1] = state
                end
                local isLast = last == #objects
                local height = SLOT_SIZE + BODY_TOP_PADDING + (isLast and BODY_BOTTOM_PADDING or 0)
                rows[#rows + 1] = {
                    kind = "items",
                    group = group,
                    objects = rowObjects,
                    states = rowStates,
                    y = y,
                    gridY = y + BODY_TOP_PADDING,
                    height = height,
                    complete = complete,
                    showProgress = showProgress,
                }
                y = y + height
            end
        end
        rows[groupStartIndex].groupStart = true
        rows[#rows].groupEnd = true
    end

    if #rows == 0 then
        rows[1] = {
            kind = "empty",
            group = { name = "" },
            y = y,
            height = 40,
            groupStart = true,
            groupEnd = true,
            showProgress = false,
            message = self.emptyText,
        }
        y = y + 40
    end
    self.rows = rows
    self.contentHeight = y + self.bottomPadding
end

-- Refresh visible list rows
function ScrollableItemList:Refresh()
    if self.scroll == nil or self.scroll.root == nil then return end
    local overscan = SLOT_SIZE + self.slotGap
    local visibleTop = math.max(0, self.scroll.scrollY - overscan)
    local visibleBottom = self.scroll.scrollY + self.scroll.height + overscan
    local visible = {}
    for _, row in ipairs(self.rows) do
        if row.y < visibleBottom and row.y + row.height > visibleTop then
            visible[#visible + 1] = row
        end
    end

    while #self.rowPool < #visible do
        self:_CreateRowSlot()
    end
    for _, slot in ipairs(self.rowPool) do
        self:_HideRowSlot(slot)
    end

    for index, row in ipairs(visible) do
        local slot = self.rowPool[index]
        self:_RenderRow(slot, row)
        if row.kind == "items" then
            local grid = slot.grid or self:_CreateGrid(slot)
            grid:SetPos(self.itemInset, row.gridY - row.y)
            grid:SetEntries(row.objects, row.states)
            grid:SetHidden(false)
            grid.root:MoveToFront()
        end
    end
end

function ScrollableItemList.new(scroll, options)
    options = options or {}
    local rowWidth = options.rowWidth or math.max(300, (scroll.width or 318) - 18)
    local itemInset = options.itemInset or 12
    local gridWidth = math.max(SLOT_SIZE, rowWidth - itemInset * 2)
    local slotGap = options.slotGap or SLOT_GAP
    local columns = math.max(1, math.floor((gridWidth + slotGap) / (SLOT_SIZE + slotGap)))
    local self = setmetatable({
        scroll = scroll,
        rowWidth = rowWidth,
        itemInset = itemInset,
        slotGap = slotGap,
        columns = columns,
        quantityMode = options.quantityMode or ui.ObjectQuantityDisplayMode.ALWAYS or 2,
        groupGap = options.groupGap or ProgressStyle.GROUP_GAP,
        startY = options.startY or 0,
        bottomPadding = options.bottomPadding or 8,
        emptyText = options.emptyText or "No items are mapped for this collection.",
        rows = {},
        rowPool = {},
        contentHeight = 0,
    }, ScrollableItemList)
    self.layoutHandler = function() self:Refresh() end
    self.scroll.onLayout = self.layoutHandler
    return self
end

-- Update the list layout
function ScrollableItemList:Update(groups, options)
    options = options or {}
    local previousY = options.preserveScroll and self.scroll.scrollY or 0
    self.startY = options.startY or self.startY or 0
    self:_BuildRows(groups or {})
    self.scroll:SetContentHeight(math.max(self.scroll.height, self.contentHeight))
    self.scroll:SetScrollPosition(previousY)
    self:Refresh()
    return self.contentHeight
end

function ScrollableItemList:Destroy()
    if self.scroll ~= nil and self.scroll.onLayout == self.layoutHandler then
        self.scroll.onLayout = nil
    end
    for _, slot in ipairs(self.rowPool) do
        if slot.grid ~= nil then slot.grid:Destroy() end
        slot.root:Destroy()
    end
    self.rowPool = {}
    self.rows = {}
    self.scroll = nil
end

return ScrollableItemList
