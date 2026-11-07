-- Render the relics tab
local GameData = require("Resources/Lib/game_data")
local SidebarList = require("Resources/Shared/ui/sidebar_list")
local ScrollableItemList = require("Resources/Shared/ui/scrollable_item_list")
local SidebarLayout = require("Resources/Shared/ui/sidebar_layout")
local ProgressStyle = require("Resources/Shared/ui/progress_style")

local RelicsTab = {}
RelicsTab.__index = RelicsTab

local SIDEBAR_WIDTH = SidebarLayout.SIDEBAR_WIDTH
local ALL_RELICS = "All relics"
local CATEGORY_ORDER = {
    ALL_RELICS,
    "Combat",
    "Gathering",
    "Production",
    "Luck & utility",
}
local QUANTITY_MODE = ui.ObjectQuantityDisplayMode.ALWAYS or 2

-- Check whether a relic is unlocked
local function isUnlocked(value) return value == true or type(value) == "number" and value >= 1 end

-- Build a relic tooltip
local function tooltip(record) return tostring(record.name or "Unknown relic") end

function RelicsTab.new(parent, options)
    local self = setmetatable({}, RelicsTab)
    self.options = options
    self.records = self.options.records or {}
    self.selected = self.options.selected or ALL_RELICS

    local shell = SidebarLayout.CreateHeaded(parent, self.options, "RELIC POWERS", "0/0")
    self.root, self.workspace = shell.root, shell.workspace
    self.heading, self.summary = shell.heading, shell.summary
    self:BuildSidebar()
    self:Rebuild(false)
    return self
end

function RelicsTab:BuildSidebar()
    local scrollY = self.sidebarList and self.sidebarList:GetScrollPosition() or 0
    if self.sidebarList then self.sidebarList:Destroy() end
    local available = { [ALL_RELICS] = true }
    for _, record in ipairs(self.records) do
        if type(record.category) == "string" then available[record.category] = true end
    end
    if not available[self.selected] then self.selected = ALL_RELICS end

    local entries = {}
    for _, category in ipairs(CATEGORY_ORDER) do
        if available[category] then entries[#entries + 1] = category end
    end
    if ProgressStyle.greenLogEnabled then
        for index, category in ipairs(entries) do
            local total, complete = 0, true
            for _, record in ipairs(self.records) do
                if category == ALL_RELICS or record.category == category then
                    total = total + 1
                    local value = GameData.VariableValueByID(record.unlockVarBitId)
                    if value == nil then value = GameData.TrackingValue(record.unlockVariable) end
                    if not isUnlocked(value) then complete = false end
                end
            end
            entries[index] = { id = category, label = category, complete = total > 0 and complete }
        end
    end
    self.sidebarList = SidebarList.new(self.root, {
        x = 0,
        y = 38,
        width = SIDEBAR_WIDTH,
        height = math.max(40, self.root.height - 46),
        entries = entries,
        selected = self.selected,
        scrollY = scrollY,
        onSelect = function(name)
            if self.selected == name then return end
            self.selected = name
            self.options.onStateChange(name)
            self:Rebuild(false)
        end,
    })
end

-- Get the selected relic records
function RelicsTab:SelectedRecords()
    if self.selected == ALL_RELICS then return self.records end
    local records = {}
    for _, record in ipairs(self.records) do
        if record.category == self.selected then records[#records + 1] = record end
    end
    return records
end

function RelicsTab:DestroyContent()
    if self.itemLedger ~= nil then self.itemLedger:Destroy() end
    self.itemLedger = nil
    if self.scroll ~= nil then self.scroll:Destroy() end
    self.scroll = nil
end

-- Rebuild relic rows
function RelicsTab:Rebuild(preserveScroll)
    if ProgressStyle.greenLogEnabled then self:BuildSidebar() end
    local previousY = preserveScroll and self.scroll ~= nil and self.scroll.scrollY or 0
    self:DestroyContent()
    local records = self:SelectedRecords()
    local unlocked = 0

    local recordGroups = {}
    if self.selected == ALL_RELICS then
        local recordsByCategory = {}
        for _, record in ipairs(records) do
            local category = type(record.category) == "string" and record.category or "Other"
            recordsByCategory[category] = recordsByCategory[category] or {}
            recordsByCategory[category][#recordsByCategory[category] + 1] = record
        end
        for index = 2, #CATEGORY_ORDER do
            local category = CATEGORY_ORDER[index]
            if recordsByCategory[category] ~= nil then
                recordGroups[#recordGroups + 1] = {
                    name = category,
                    records = recordsByCategory[category],
                }
                recordsByCategory[category] = nil
            end
        end
        local extraCategories = {}
        for category in pairs(recordsByCategory) do
            extraCategories[#extraCategories + 1] = category
        end
        table.sort(extraCategories)
        for _, category in ipairs(extraCategories) do
            recordGroups[#recordGroups + 1] = {
                name = category,
                records = recordsByCategory[category],
            }
        end
    else
        recordGroups[1] = { name = self.selected, records = records }
    end

    for _, group in ipairs(recordGroups) do
        group.objects = {}
        group.states = {}
        group.collected = 0
        group.total = #group.records
        group.showProgress = true
        group.showHeader = self.selected == ALL_RELICS
        group.emptyText = "No relics are mapped for this category."
        for index, record in ipairs(group.records) do
            local value = GameData.VariableValueByID(record.unlockVarBitId)
            if value == nil and record.unlockVariable ~= nil then
                value = GameData.TrackingValue(record.unlockVariable)
            end
            group.states[index] = isUnlocked(value)
            if group.states[index] then
                group.collected = group.collected + 1
                unlocked = unlocked + 1
            end
            group.objects[index] = {
                object = GameData.ObjectFromID(record.objectId),
                tooltip = tooltip(record),
            }
        end
    end

    self.heading.content = self.selected == ALL_RELICS and "MONOLITH RELICS"
        or string.upper(self.selected) .. " RELICS"
    self.summary.content = tostring(unlocked) .. "/" .. tostring(#records)

    local scrollY = 46
    local scrollHeight = math.max(120, self.workspace.height - scrollY)
    local rowWidth = math.max(300, self.workspace.width - 18)
    self.scroll = prettyui.SimpleView.new(self.workspace, {
        x = 0,
        y = scrollY,
        width = self.workspace.width,
        height = scrollHeight,
        contentHeight = scrollHeight,
        scrollStep = 44,
    })
    self.itemLedger = ScrollableItemList.new(self.scroll, {
        rowWidth = rowWidth,
        quantityMode = QUANTITY_MODE,
        emptyText = "No relic data was supplied by the current manifest.",
    })
    self.itemLedger:Update(recordGroups)
    self.scroll:SetScrollPosition(preserveScroll and previousY or 0)
    self.itemLedger:Refresh()
end

function RelicsTab:Destroy()
    self:DestroyContent()
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    self.sidebarList = nil
    if self.root ~= nil then self.root:Destroy() end
    self.root = nil
end

return RelicsTab
