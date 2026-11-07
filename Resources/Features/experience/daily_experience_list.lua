-- Render the daily experience list
local UI = require("Resources/Shared/ui/components")
local DailyExperienceList = {}
DailyExperienceList.__index = DailyExperienceList

local HEADER = 0x2A231BFF
local ROW_ODD = 0x17130FFF
local ROW_EVEN = 0x1D1914FF
local BORDER = 0x3E3327FF
local DIVIDER = 0x30271EFF
local MUTED = 0x928776FF
local TEXT = 0xB8AD98FF
local GOLD = 0xF2C66DFF

-- Set daily list visibility
local function setVisible(component, visible) component.hidden = not visible end

function DailyExperienceList:_CreateSlot()
    local root = ui.Layer.new(self.rowLayer)
    root.clickthrough = true
    local slot = {
        root = root,
        background = ui.Rectangle.new(root),
        divider = ui.Rectangle.new(root),
        cells = {},
    }
    for column = 1, 4 do
        slot.cells[column] = ui.Text.new(root)
    end
    self.pool[#self.pool + 1] = slot
    return slot
end

function DailyExperienceList:_HideSlot(slot)
    slot.root.hidden = true
    setVisible(slot.background, false)
    setVisible(slot.divider, false)
    for _, cell in ipairs(slot.cells) do
        setVisible(cell, false)
    end
end

function DailyExperienceList:_RenderSlot(slot, record, index)
    slot.root:SetPos(0, self.rowsY + (index - 1) * self.rowHeight)
    slot.root:SetSize(self.rowWidth, self.rowHeight)
    slot.root.hidden = false
    local y = 0
    UI.BindRectangle(
        slot.background,
        0,
        y,
        self.rowWidth,
        self.rowHeight,
        index % 2 == 1 and ROW_ODD or ROW_EVEN
    )
    UI.BindRectangle(slot.divider, 0, y + self.rowHeight - 1, self.rowWidth, 1, DIVIDER)
    -- Format each row once and reuse it while scrolling
    local values = self.values[index]
    if values == nil then
        values = {
            record.day,
            "+" .. self.formatNumber(record.gain),
            record.active,
            self.formatNumber(record.rate),
        }
        self.values[index] = values
    end
    for column = 1, 4 do
        local left = math.floor(self.rowWidth * self.columns[column])
        local right = math.floor(self.rowWidth * self.columns[column + 1])
        UI.BindText(
            slot.cells[column],
            values[column],
            left + 8,
            y,
            right - left - 16,
            self.rowHeight,
            {
                font = column == 2 and id.Font.MUSEO_SANS_13PT_BOLD
                    or id.Font.MUSEO_SANS_11PT_REGULAR,
                colour = column == 2 and GOLD or TEXT,
            }
        )
    end
end

-- Refresh daily XP rows
function DailyExperienceList:Refresh()
    if self.scroll == nil or self.scroll.root == nil then return end
    local overscan = self.rowHeight
    local visibleTop = self.scroll.scrollY - overscan
    local visibleBottom = self.scroll.scrollY + self.scroll.height + overscan
    local first = math.max(1, math.floor((visibleTop - self.rowsY) / self.rowHeight) + 1)
    local last = math.min(#self.rows, math.floor((visibleBottom - self.rowsY) / self.rowHeight) + 1)
    if visibleBottom <= self.rowsY or first > last then
        first, last = 1, 0
    end

    local needed = math.max(0, last - first + 1)
    while #self.pool < needed do
        self:_CreateSlot()
    end
    for poolIndex, slot in ipairs(self.pool) do
        local rowIndex = first + poolIndex - 1
        if poolIndex <= needed and self.rows[rowIndex] ~= nil then
            self:_RenderSlot(slot, self.rows[rowIndex], rowIndex)
        else
            self:_HideSlot(slot)
        end
    end
    self.chromeLayer:MoveToFront()
end

function DailyExperienceList.new(scroll, options)
    local self = setmetatable({
        scroll = scroll,
        rows = options.rows or {},
        tableX = options.x or 0,
        tableY = options.y or 0,
        rowHeight = options.rowHeight or 32,
        rowWidth = options.width,
        columns = options.columns or { 0, 0.33, 0.58, 0.79, 1 },
        formatNumber = options.formatNumber,
        values = {},
        pool = {},
    }, DailyExperienceList)
    self.rowsY = self.tableY + self.rowHeight

    self.rowLayer = ui.Layer.new(scroll.content)
    self.rowLayer:SetPos(self.tableX, 0)
    self.rowLayer.clickthrough = true

    self.chromeLayer = ui.Layer.new(scroll.content)
    self.chromeLayer:SetPos(self.tableX, 0)
    self.chromeLayer.clickthrough = true

    local headers = { "DAY", "GAIN", "ACTIVE", "RATE / HR" }
    for column = 1, 4 do
        local left = math.floor(self.rowWidth * self.columns[column])
        local right = math.floor(self.rowWidth * self.columns[column + 1])
        UI.BindRectangle(
            ui.Rectangle.new(self.chromeLayer),
            left,
            self.tableY,
            right - left,
            self.rowHeight,
            HEADER
        )
        UI.BindText(
            ui.Text.new(self.chromeLayer),
            headers[column],
            left + 8,
            self.tableY,
            right - left - 16,
            self.rowHeight,
            {
                font = id.Font.MUSEO_SANS_11PT_REGULAR,
                colour = MUTED,
            }
        )
    end
    UI.BindRectangle(ui.Rectangle.new(self.chromeLayer), 0, self.tableY, self.rowWidth, 1, BORDER)
    -- Edges that stretch with the row count
    self.bottomEdge = ui.Rectangle.new(self.chromeLayer)
    self.columnEdges = {}
    for column = 1, 5 do
        self.columnEdges[column] = ui.Rectangle.new(self.chromeLayer)
    end
    self:_Layout()

    self.layoutHandler = function() self:Refresh() end
    scroll.onLayout = self.layoutHandler
    self:Refresh()
    return self
end

-- Size the layers and stretching edges for the current rows
function DailyExperienceList:_Layout()
    self.contentBottom = self.rowsY + #self.rows * self.rowHeight
    local layerHeight = math.max(self.scroll.height, self.contentBottom)
    self.rowLayer:SetSize(self.rowWidth, layerHeight)
    self.chromeLayer:SetSize(self.rowWidth, layerHeight)
    UI.BindRectangle(self.bottomEdge, 0, self.contentBottom - 1, self.rowWidth, 1, BORDER)
    local edgeHeight = self.contentBottom - self.tableY
    for column = 1, 5 do
        local x = column == 1 and 0
            or column == 5 and self.rowWidth - 1
            or math.floor(self.rowWidth * self.columns[column])
        local colour = (column == 1 or column == 5) and BORDER or DIVIDER
        UI.BindRectangle(self.columnEdges[column], x, self.tableY, 1, edgeHeight, colour)
    end
end

-- Replace the rows without rebuilding the table
function DailyExperienceList:SetRows(rows)
    self.rows = rows or {}
    self.values = {}
    self:_Layout()
    self:Refresh()
end

function DailyExperienceList:Destroy()
    if self.scroll ~= nil and self.scroll.onLayout == self.layoutHandler then
        self.scroll.onLayout = nil
    end
    if self.rowLayer ~= nil then self.rowLayer:Destroy() end
    if self.chromeLayer ~= nil then self.chromeLayer:Destroy() end
    self.pool = {}
    self.rows = {}
    self.values = {}
    self.rowLayer = nil
    self.chromeLayer = nil
    self.scroll = nil
end

return DailyExperienceList
