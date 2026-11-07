-- Render collection sidebars and item grids
local CollectionLogPage = {}
CollectionLogPage.__index = CollectionLogPage

local CollectionEntries = require("Resources/Shared/collections/collection_entries")
local UI = require("Resources/Shared/ui/components")
local SidebarList = require("Resources/Shared/ui/sidebar_list")
local ScrollableItemList = require("Resources/Shared/ui/scrollable_item_list")
local SidebarLayout = require("Resources/Shared/ui/sidebar_layout")
local GameData = require("Resources/Lib/game_data")
local ProgressStyle = require("Resources/Shared/ui/progress_style")

local SIDEBAR_WIDTH = SidebarLayout.SIDEBAR_WIDTH
local QUANTITY_MODE = ui.ObjectQuantityDisplayMode.ALWAYS or 2

-- Build collection log page options
function CollectionLogPage.Options(feature, context)
    local definition = feature.collection
    local state = context.state
    return {
        x = context.x,
        y = context.y,
        width = context.width,
        height = context.height,
        groups = feature.groups,
        logs = feature.logs,
        sidebarTitle = definition.sidebarTitle,
        searchPlaceholder = definition.searchPlaceholder,
        emptySearchText = definition.emptySearchText,
        emptyItemsText = definition.emptyItemsText,
        fallbackHeading = definition.fallbackHeading,
        groupAll = definition.groupAll,
        allLabel = definition.allLabel,
        selected = state[definition.selectedKey],
        search = state[definition.searchKey],
        showQuantities = definition.showQuantities,
        showProgress = definition.showProgress,
        getValue = function(name) return context.progress:GetValue(name) end,
        isCollected = definition.isCollected
            or function(entry, value) return context.progress:IsCollected(entry, value) end,
        resolveObject = definition.resolveObject or GameData.CollectionObject,
        tooltip = definition.tooltip or GameData.CollectionTooltip,
        onStateChange = function(selected, search, persist)
            state[definition.selectedKey] = selected
            state[definition.searchKey] = search
            if persist ~= false then context.saveState() end
        end,
    }
end

function CollectionLogPage.CreateFeature(parent, feature, context)
    local view = CollectionLogPage.new(parent, CollectionLogPage.Options(feature, context))
    context.state[feature.collection.selectedKey] = view.selected
    return view
end

function CollectionLogPage.new(parent, options)
    local self = setmetatable({}, CollectionLogPage)
    self.options = options
    self.groups = options.groups or {}
    self.selected = options.selected
    self.search = tostring(options.search or "")
    self.searchDirty = false
    self.aggregateSelection = options.allLabel or (options.groupAll and "All" or nil)

    if
        self.selected == nil
        or self.selected ~= self.aggregateSelection and options.logs[self.selected] == nil
    then
        self.selected = self.aggregateSelection
            or (self.groups[1] ~= nil and self.groups[1].name or nil)
    end

    local shell = SidebarLayout.Create(parent, {
        x = options.x or 0,
        y = options.y or 0,
        width = options.width,
        height = options.height,
        sidebarTitle = options.sidebarTitle or "COLLECTIONS",
        titleY = 2,
        titleHeight = 28,
    })
    self.root = shell.root
    self.workspace = shell.workspace

    self.searchField = prettyui.TextField.new(self.root, {
        x = 10,
        y = 34,
        width = SIDEBAR_WIDTH - 20,
        height = 28,
        text = self.search,
        placeholder = options.searchPlaceholder or "Search collections...",
        maxLength = 60,
        onChange = function(_, reason, content)
            self.search = tostring(content or "")
            self:RebuildRegions(false)
            local persist = reason == ui.InputFieldActionResult.SUBMIT
            self.searchDirty = not persist
            self.options.onStateChange(self.selected, self.search, persist)
        end,
    })
    self.heading = UI.Text(self.workspace, "", 12, 2, self.workspace.width - 136, 30, {
        font = id.Font.CINZEL_18PT_BOLD,
        colour = 0xF2C66DFF,
    })
    self.summary = UI.Text(self.workspace, "0/0", self.workspace.width - 112, 2, 100, 30, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = 0xF2C66DFF,
        alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
    })

    self:RebuildRegions(false)
    self:RebuildGrid(false)
    return self
end

function CollectionLogPage:RebuildRegions(preserveScroll)
    local previousY = preserveScroll
            and self.sidebarList ~= nil
            and self.sidebarList:GetScrollPosition()
        or 0
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    self.sidebarList = nil
    if self.emptySidebarText ~= nil then self.emptySidebarText:Destroy() end
    self.emptySidebarText = nil

    local listY = 72
    local listHeight = math.max(120, self.root.height - listY)
    local visible = {}
    local needle = UI.Lower(self.search)
    if
        self.options.allLabel ~= nil
        and (needle == "" or string.find(UI.Lower(self.options.allLabel), needle, 1, true) ~= nil)
    then
        visible[#visible + 1] = {
            name = self.options.allLabel,
            aggregate = true,
        }
    end
    for _, group in ipairs(self.groups) do
        if needle == "" or string.find(UI.Lower(group.name), needle, 1, true) ~= nil then
            visible[#visible + 1] = group
        end
    end

    local entries = {}
    for _, group in ipairs(visible) do
        local items = self.options.logs[group.name] or {}
        if group.name == self.aggregateSelection and self.options.groupAll then
            items = {}
            for _, source in ipairs(self.groups) do
                if not source.synthetic and source.name ~= self.aggregateSelection then
                    for _, item in ipairs(self.options.logs[source.name] or {}) do items[#items + 1] = item end
                end
            end
        end
        entries[#entries + 1] = { id = group.name, label = group.name,
            complete = ProgressStyle.greenLogEnabled and CollectionEntries.IsComplete(items, self.options) }
    end
    self.sidebarList = SidebarList.new(self.root, {
        x = 0,
        y = listY,
        width = SIDEBAR_WIDTH,
        height = listHeight,
        entries = entries,
        selected = self.selected,
        scrollY = previousY,
        onSelect = function(name)
            if self.selected == name then return end
            self.selected = name
            self.searchDirty = false
            self.options.onStateChange(self.selected, self.search, true)
            self:RebuildGrid(false)
        end,
    })
    if #visible == 0 then
        self.emptySidebarText = UI.Text(
            self.root,
            self.options.emptySearchText or "No collections match.",
            12,
            listY + 8,
            SIDEBAR_WIDTH - 24,
            30,
            { colour = 0xC9BEA4FF }
        )
        self.emptySidebarText:MoveToFront()
    end
end

function CollectionLogPage:DestroyGridContent()
    if self.itemLedger ~= nil then self.itemLedger:Destroy() end
    self.itemLedger = nil
    if self.itemScroll ~= nil then self.itemScroll:Destroy() end
    self.itemScroll = nil
end

function CollectionLogPage:RebuildGrid(preserveScroll)
    if ProgressStyle.greenLogEnabled then self:RebuildRegions(true) end
    local previousY = preserveScroll and self.itemScroll ~= nil and self.itemScroll.scrollY or 0
    self:DestroyGridContent()

    self.heading.content =
        string.upper(tostring(self.selected or self.options.fallbackHeading or "COLLECTION"))

    local selectedGroups = {}
    if self.options.groupAll and self.selected == self.aggregateSelection then
        for _, group in ipairs(self.groups) do
            if not group.synthetic and group.name ~= self.aggregateSelection then
                selectedGroups[#selectedGroups + 1] = group.name
            end
        end
    elseif self.selected ~= nil then
        selectedGroups[1] = self.selected
    end

    local preparedGroups = {}
    local totalCollected = 0
    local totalEntries = 0
    local showProgress = self.options.showProgress ~= false
    local showGroupHeaders = self.options.groupAll and self.selected == self.aggregateSelection
    for _, groupName in ipairs(selectedGroups) do
        local entries = self.options.logs[groupName] or {}
        local prepared = CollectionEntries.PrepareGroup(groupName, entries, self.options)
        prepared.showHeader = showGroupHeaders
        prepared.emptyText = self.options.emptyItemsText
            or "No items are mapped for this collection."
        totalCollected = totalCollected + prepared.collected
        totalEntries = totalEntries + #entries
        preparedGroups[#preparedGroups + 1] = prepared
    end
    self.summary.content = showProgress
            and (tostring(totalCollected) .. "/" .. tostring(totalEntries))
        or (tostring(totalEntries) .. " items")

    local scrollY = 38
    local scrollHeight = math.max(120, self.workspace.height - scrollY)
    self.itemScroll = prettyui.SimpleView.new(self.workspace, {
        x = 0,
        y = scrollY,
        width = self.workspace.width,
        height = scrollHeight,
        contentHeight = scrollHeight,
        scrollStep = 44,
    })
    local rowWidth = math.max(300, self.workspace.width - 18)
    self.itemLedger = ScrollableItemList.new(self.itemScroll, {
        rowWidth = rowWidth,
        quantityMode = QUANTITY_MODE,
        emptyText = self.options.emptyItemsText or "No items are mapped for this collection.",
    })
    self.itemLedger:Update(preparedGroups, {
        preserveScroll = false,
    })
    self.itemScroll:SetScrollPosition(preserveScroll and previousY or 0)
    self.itemLedger:Refresh()
end

function CollectionLogPage:Destroy()
    if self.searchDirty then
        self.searchDirty = false
        self.options.onStateChange(self.selected, self.search, true)
    end
    self:DestroyGridContent()
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    if self.emptySidebarText ~= nil then self.emptySidebarText:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.root = nil
end

return CollectionLogPage
