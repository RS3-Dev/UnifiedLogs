-- Render the cape requirements view
local UI = require("Resources/Shared/ui/components")
local ProgressStyle = require("Resources/Shared/ui/progress_style")
local CapeRequirements = require("Resources/Features/achievements/cape_requirements")
local AchievementGuidePanel = require("Resources/Features/achievements/achievement_guide_panel")

local CapeRequirementsView = {}
CapeRequirementsView.__index = CapeRequirementsView

local ROW_HEIGHT = 42
local HEADER_HEIGHT = 32
local GROUP_HEIGHT = 32
local GOLD = 0xF2C66DFF
local MUTED = 0x928776FF
local ROW_SELECTED = 0x30281DFF
local SCROLLBAR_GUTTER = 18
local FILTER_ALL = 0
local FILTER_INCOMPLETE = 1
local FILTER_UNBLOCKED = 2
local FILTER_ENTRIES = {
    { label = "Show all", id = FILTER_ALL, order = FILTER_ALL },
    { label = "Show incomplete", id = FILTER_INCOMPLETE, order = FILTER_INCOMPLETE },
    { label = "Show Unblocked", id = FILTER_UNBLOCKED, order = FILTER_UNBLOCKED },
}

local function filterMode(entryID)
    entryID = tonumber(entryID)
    if entryID == FILTER_INCOMPLETE then return "incomplete" end
    if entryID == FILTER_UNBLOCKED then return "unblocked" end
    return "all"
end

-- Map a filter mode to its entry ID
local function filterEntryID(mode)
    if mode == "incomplete" then return FILTER_INCOMPLETE end
    if mode == "unblocked" then return FILTER_UNBLOCKED end
    return FILTER_ALL
end

-- Normalize the saved filter mode
local function normalizedFilterMode(mode)
    if mode == "incomplete" then return "incomplete" end
    if mode == "unblocked" then return "unblocked" end
    return "all"
end

-- Set requirement list visibility
local function setVisible(component, visible)
    if component ~= nil then component.hidden = not visible end
end

-- Calculate the visible row width
local function visibleRowWidth(scroll)
    return math.max(240, math.min(scroll.content.width, scroll.width - SCROLLBAR_GUTTER))
end

local function hideSlot(slot)
    for key, component in pairs(slot) do
        if key ~= "branches" and key ~= "row" then setVisible(component, false) end
    end
    for _, component in ipairs(slot.branches) do
        setVisible(component, false)
    end
    slot.row = nil
end

function CapeRequirementsView.new(parent, options)
    local self = setmetatable({}, CapeRequirementsView)
    self.options = options
    self.root = ui.Layer.new(parent)
    self.root:SetPos(self.options.x or 0, self.options.y or 0)
    self.root:SetSize(self.options.width, self.options.height)
    self.root.clickthrough = true
    self.rowPool = {}
    self.static = {}
    self:Build()
    return self
end

-- Remember the selected requirement
function CapeRequirementsView:Remember(component)
    self.static[#self.static + 1] = component
    return component
end

function CapeRequirementsView:CreateRowSlot()
    local parent = ui.Layer.new(self.scroll.content)
    parent.clickthrough = true
    local slot = {
        root = parent,
        background = ui.Rectangle.new(parent),
        wedge = ui.Rectangle.new(parent),
        number = ui.Text.new(parent),
        name = ui.Text.new(parent),
        description = ui.Text.new(parent),
        mark = ProgressStyle.CompletionMark(parent, 0, 0, false),
        divider = ui.Rectangle.new(parent),
        branches = {},
    }
    slot.background.clickthrough = false
    slot.background:Subscribe(ui.Hook.ONCLICK, function()
        if slot.row ~= nil then self:OpenGuide(slot.row.node) end
        return false
    end)
    UI.ForwardScrollWheel(slot.background, self.scroll)
    self.rowPool[#self.rowPool + 1] = slot
    return slot
end

-- Build a requirement branch
function CapeRequirementsView:Branch(slot, index)
    while #slot.branches < index do
        slot.branches[#slot.branches + 1] = ui.Rectangle.new(slot.root)
    end
    return slot.branches[index]
end

function CapeRequirementsView:RenderRow(slot, row, rowIndex)
    slot.row = row
    local node = row.node
    slot.root:SetPos(0, (rowIndex - 1) * ROW_HEIGHT)
    slot.root:SetSize(self.rowWidth, ROW_HEIGHT)
    slot.root.hidden = false
    local y = 0
    local width = self.rowWidth
    local complete = node.complete == true
    UI.BindRectangle(
        slot.background,
        0,
        y,
        width,
        ROW_HEIGHT,
        self.selectedKey == node.key and ROW_SELECTED or ProgressStyle.RowColour(rowIndex)
    )
    slot.background.clickthrough = false
    UI.BindRectangle(slot.divider, 0, y + ROW_HEIGHT - 1, width, 1, ProgressStyle.ROW_DIVIDER)
    setVisible(slot.wedge, complete)
    if complete then
        UI.BindRectangle(
            slot.wedge,
            1,
            y + 1,
            ProgressStyle.COMPLETE_WEDGE_WIDTH,
            ROW_HEIGHT - 2,
            ProgressStyle.COMPLETE_WEDGE
        )
        slot.wedge:MoveToFront()
    end

    local labelX = 50
    if self.orderView == "tree" then
        local depth = math.min(22, math.max(0, tonumber(row.depth) or 0))
        local branchGap = 16
        local branchIndex = 0
        for level = 1, depth - 1 do
            if row.continuations[level] == true then
                branchIndex = branchIndex + 1
                UI.BindRectangle(
                    self:Branch(slot, branchIndex),
                    16 + (level - 1) * branchGap,
                    y,
                    1,
                    ROW_HEIGHT,
                    ProgressStyle.GROUP_BORDER
                )
            end
        end
        if depth > 0 then
            local branchX = 16 + (depth - 1) * branchGap
            local centreY = y + math.floor(ROW_HEIGHT / 2)
            branchIndex = branchIndex + 1
            UI.BindRectangle(
                self:Branch(slot, branchIndex),
                branchX,
                y,
                1,
                row.isLast and math.floor(ROW_HEIGHT / 2) + 1 or ROW_HEIGHT,
                ProgressStyle.GROUP_BORDER
            )
            branchIndex = branchIndex + 1
            UI.BindRectangle(
                self:Branch(slot, branchIndex),
                branchX,
                centreY,
                10,
                1,
                ProgressStyle.GROUP_BORDER
            )
        end
        for index = branchIndex + 1, #slot.branches do
            setVisible(slot.branches[index], false)
        end
        setVisible(slot.number, false)
        labelX = 12 + depth * branchGap
    else
        for _, branch in ipairs(slot.branches) do
            setVisible(branch, false)
        end
        UI.BindText(slot.number, tostring(rowIndex), 8, y, 34, ROW_HEIGHT, {
            font = id.Font.MUSEO_SANS_13PT_BOLD,
            colour = GOLD,
            alignHorizontal = ui.AlignMode.CENTRE,
        })
    end

    local rightInset = 40
    local description = tostring(node.description or "")
    local nameHeight = description ~= "" and 23 or ROW_HEIGHT
    UI.BindText(slot.name, node.name, labelX, y, width - labelX - rightInset, nameHeight, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = complete and ProgressStyle.TEXT_COMPLETE or ProgressStyle.TEXT_NORMAL,
        alignVertical = ui.AlignMode.CENTRE,
    })
    setVisible(slot.description, description ~= "")
    if description ~= "" then
        UI.BindText(
            slot.description,
            description,
            labelX,
            y + 21,
            width - labelX - rightInset,
            18,
            {
                font = id.Font.MUSEO_SANS_11PT_REGULAR,
                colour = MUTED,
                alignVertical = ui.AlignMode.CENTRE,
            }
        )
    end
    ProgressStyle.PositionCompletionMark(
        slot.mark,
        width - 26,
        y + math.floor((ROW_HEIGHT - 14) / 2)
    )
    ProgressStyle.SetCompletionMark(slot.mark, complete)
    slot.mark:MoveToFront()
end

function CapeRequirementsView:CloseGuide()
    if self.guidePanel ~= nil then self.guidePanel:Destroy() end
    self.guidePanel = nil
    self.selectedKey = nil
    if self.scroll ~= nil then
        self.scroll:SetSize(self.root.width, self.scroll.height)
        self.rowWidth = visibleRowWidth(self.scroll)
        self:RefreshRows()
    end
end

function CapeRequirementsView:OpenGuide(node)
    local guide = CapeRequirements.Guide(node)
    if guide == nil then return end
    if self.guidePanel ~= nil then self.guidePanel:Destroy() end
    self.selectedKey = node.key
    local panelWidth = math.floor(self.root.width * 0.38)
    local listWidth = self.root.width - panelWidth
    self.scroll:SetSize(listWidth, self.scroll.height)
    self.rowWidth = visibleRowWidth(self.scroll)
    self.guidePanel = AchievementGuidePanel.new(self.root, guide, {
        x = listWidth,
        y = self.scroll.root.y,
        width = panelWidth,
        height = self.scroll.height,
        onClose = function() self:CloseGuide() end,
    })
    self:RefreshRows()
end

function CapeRequirementsView:ApplyFilters(preserveScroll)
    local source = CapeRequirements.Rows(self.data, self.orderView)
    self.rows = CapeRequirements.FilterRows(source, self.filterMode, self.search)
    self.filteredComplete = 0
    for _, row in ipairs(self.rows) do
        if row.node.complete == true then self.filteredComplete = self.filteredComplete + 1 end
    end
    self.filteredTotal = #self.rows
    self:UpdateSummary()
    if self.scroll == nil then return end
    local previousY = preserveScroll and self.scroll.scrollY or 0
    self.scroll:SetContentHeight(math.max(self.scroll.height, #self.rows * ROW_HEIGHT))
    self.scroll:SetScrollPosition(previousY)
    self:RefreshRows()
end

function CapeRequirementsView:UpdateSummary()
    if self.summaryText == nil then return end
    self.summaryText.content = tostring(self.filteredComplete or 0)
        .. " / "
        .. tostring(self.filteredTotal or 0)
    self.summaryText.rgba = self.filteredTotal > 0
            and self.filteredComplete >= self.filteredTotal
            and ProgressStyle.PROGRESS_COMPLETE
        or ProgressStyle.PROGRESS_ACTIVE
end

function CapeRequirementsView:SetFilterMode(mode, preserveScroll)
    self.filterMode = normalizedFilterMode(mode)
    self:ApplyFilters(preserveScroll)
end

function CapeRequirementsView:SetSearch(value, preserveScroll)
    self.search = tostring(value or "")
    self:ApplyFilters(preserveScroll)
end

function CapeRequirementsView:RefreshRows()
    if self.scroll == nil then return end
    local first = math.max(1, math.floor(self.scroll.scrollY / ROW_HEIGHT) + 1)
    local last =
        math.min(#self.rows, math.ceil((self.scroll.scrollY + self.scroll.height) / ROW_HEIGHT) + 1)
    local needed = math.max(0, last - first + 1)
    while #self.rowPool < needed do
        self:CreateRowSlot()
    end
    for _, slot in ipairs(self.rowPool) do
        hideSlot(slot)
    end
    for poolIndex = 1, needed do
        local rowIndex = first + poolIndex - 1
        self:RenderRow(self.rowPool[poolIndex], self.rows[rowIndex], rowIndex)
    end
end

function CapeRequirementsView:BuildUnavailable()
    self:Remember(
        UI.Text(self.root, "ACHIEVEMENT DATA UNAVAILABLE", 14, 16, self.root.width - 28, 28, {
            font = id.Font.CINZEL_18PT_BOLD,
            colour = GOLD,
        })
    )
    self:Remember(
        UI.Text(
            self.root,
            "The client did not expose this cape's achievement requirements.",
            14,
            52,
            self.root.width - 28,
            26,
            { colour = MUTED }
        )
    )
end

function CapeRequirementsView:Build()
    self.data = CapeRequirements.Build(self.options.cape, self.options.snapshot)
    if self.data == nil then
        self:BuildUnavailable()
        return
    end

    self.orderView = self.options.orderView == "tree" and "tree" or "linear"
    self.filterMode = normalizedFilterMode(self.options.filterMode)
    self.search = tostring(self.options.search or "")
    self:ApplyFilters(false)
    local width, height = self.root.width, self.root.height
    self:Remember(UI.Text(self.root, string.upper(self.options.cape.name), 12, 0, width - 210, 30, {
        font = id.Font.CINZEL_18PT_BOLD,
        colour = GOLD,
    }))
    self.summaryText = self:Remember(
        UI.Text(
            self.root,
            "",
            width - 196,
            0,
            184,
            30,
            {
                font = id.Font.MUSEO_SANS_13PT_BOLD,
                colour = ProgressStyle.PROGRESS_ACTIVE,
                alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
            }
        )
    )
    self:UpdateSummary()
    local groupY = HEADER_HEIGHT
    self:Remember(
        UI.Rectangle(self.root, 0, groupY, width, GROUP_HEIGHT, ProgressStyle.GROUP_BACKGROUND)
    )
    self:Remember(
        UI.Rectangle(self.root, 0, groupY + GROUP_HEIGHT - 1, width, 1, ProgressStyle.GROUP_DIVIDER)
    )
    self.searchField = self:Remember(prettyui.TextField.new(self.root, {
        x = 8,
        y = groupY + 2,
        width = width - 206,
        height = GROUP_HEIGHT - 4,
        text = self.search,
        placeholder = "Search requirements...",
        maxLength = 80,
        onChange = function(_, reason, content)
            local value = tostring(content or "")
            local persist = reason == ui.InputFieldActionResult.SUBMIT
            if value == self.search then
                if persist then self.options.onSearchChange(value, true) end
                return
            end
            self:SetSearch(value, false)
            self.options.onSearchChange(value, persist)
        end,
    }))
    local ComboBox = prettyui.OrderedComboBox or prettyui.ComboBox
    self.filterCombo = self:Remember(ComboBox.new(self.root, {
        x = width - 190,
        y = groupY + 2,
        width = 178,
        height = GROUP_HEIGHT - 4,
        entries = FILTER_ENTRIES,
        selectedID = filterEntryID(self.filterMode),
        onChange = function(_, entryID)
            local selectedMode = filterMode(entryID)
            if selectedMode == self.filterMode then return end
            self:SetFilterMode(selectedMode, false)
            self.options.onFilterChange(selectedMode)
        end,
    }))

    local scrollY = groupY + GROUP_HEIGHT
    local scrollHeight = math.max(80, height - scrollY)
    self.scroll = prettyui.SimpleView.new(self.root, {
        x = 0,
        y = scrollY,
        width = width,
        height = scrollHeight,
        contentHeight = math.max(scrollHeight, #self.rows * ROW_HEIGHT),
        scrollable = true,
        scrollStep = ROW_HEIGHT,
    })
    self.rowWidth = visibleRowWidth(self.scroll)
    self.layoutHandler = function() self:RefreshRows() end
    self.scroll.onLayout = self.layoutHandler
    self:RefreshRows()
end

function CapeRequirementsView:Destroy()
    if self.guidePanel ~= nil then self.guidePanel:Destroy() end
    if self.scroll ~= nil then
        if self.scroll.onLayout == self.layoutHandler then self.scroll.onLayout = nil end
        self.scroll:Destroy()
    end
    for _, component in ipairs(self.static) do
        component:Destroy()
    end
    self.static = {}
    self.rowPool = {}
    self.scroll = nil
    self.filterCombo = nil
    self.searchField = nil
    self.guidePanel = nil
    if self.root ~= nil then self.root:Destroy() end
    self.root = nil
end

return CapeRequirementsView
