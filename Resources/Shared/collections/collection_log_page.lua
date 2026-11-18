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
local Preparer = require("Resources/Shared/collections/collection_preparer")

-- Build collection log page options
function CollectionLogPage.Options(feature, context)
    local definition = feature.collection
    local state = context.state
    feature.objectCache = feature.objectCache or setmetatable({}, { __mode = "k" })
    return {
        objectCache = feature.objectCache,
        x = context.x,
        y = context.y,
        width = context.width,
        height = context.height,
        groups = feature.groups,
        logs = feature.logs,
        deferCollections = context.deferCollections,
        isVisible = context.isVisible,
        readValue = function(reference) return context.progress:ReadValueNow(reference) end,
        progress = context.progress,
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
        searchItems = definition.searchItems,
        getValue = function(name) return context.progress:GetValue(name) end,
        isCollected = function(entry, value)
            if definition.isCollected ~= nil then return definition.isCollected(entry, value, context.progress) end
            return context.progress:IsCollected(entry, value)
        end,
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
        categoryID = "auto",
        x = 10,
        y = 34,
        width = SIDEBAR_WIDTH - 20,
        height = 28,
        text = self.search,
        placeholder = options.searchPlaceholder or "Search collections...",
        maxLength = 60,
        onChange = function(_, reason, content)
            self.search = tostring(content or "")
            if self.options.searchItems then self:RebuildGrid(false) else self:RebuildRegions(false) end
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
    local needle = self.options.searchItems and "" or UI.Lower(self.search)
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
            if group.beforeAggregate then
                table.insert(visible, 1, group)
            else
                visible[#visible + 1] = group
            end
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
        local complete = false
        if ProgressStyle.greenLogEnabled then
            if self.options.deferCollections and self.selected == self.aggregateSelection then
                complete = #items > 0 and self.preparer ~= nil
                for _, item in ipairs(items) do
                    if self.preparer == nil or self.preparer.complete[item] ~= true then complete = false; break end
                end
            else
                complete = CollectionEntries.IsComplete(items, self.options)
            end
        end
        entries[#entries + 1] = { id = group.name, label = group.name, complete = complete }
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
    if self.preparer then self.preparer:Stop(); self.preparer = nil end
    if self.itemLedger ~= nil then self.itemLedger:Destroy() end
    self.itemLedger = nil
    if self.itemScroll ~= nil then self.itemScroll:Destroy() end
    self.itemScroll = nil
end

function CollectionLogPage:RebuildGrid(preserveScroll)
    if self.preparer then self.preparer:Stop(); self.preparer = nil end
    if ProgressStyle.greenLogEnabled then
        if self.options.deferCollections and self.selected == self.aggregateSelection and self.sidebarList then
            self.sidebarList:Select(self.selected)
        else
            self:RebuildRegions(true)
        end
    end

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
    if self.options.progress and self.options.deferCollections then
        self.options.progress.viewport = showGroupHeaders
    end
    if self.options.deferCollections and showGroupHeaders then
        self.objectCache = self.options.objectCache or self.objectCache or {}
        self.preparer = Preparer.Collection(self.options, function() self:RefreshPreparedProgress() end, self.objectCache)
    end
    for _, groupName in ipairs(selectedGroups) do
        local entries = self.options.logs[groupName] or {}
        if self.options.searchItems and self.search ~= "" then
            local needle = UI.Lower(self.search)
            if string.find(UI.Lower(groupName), needle, 1, true) == nil then
                local matching = {}
                for _, entry in ipairs(entries) do
                    local label = UI.Lower(entry.label or entry.objectConfig or "")
                    if string.find(label, needle, 1, true) ~= nil then matching[#matching + 1] = entry end
                end
                entries = matching
            end
        end
        local prepared = self.preparer and self.preparer:AddGroup(groupName, entries)
            or CollectionEntries.PrepareGroup(groupName, entries, self.options)
        prepared.showHeader = showGroupHeaders
        prepared.emptyText = self.options.emptyItemsText
            or "No items are mapped for this collection."
        if self.options.searchItems and self.search ~= "" then prepared.emptyText = "No items match your search." end
        totalCollected = totalCollected + prepared.collected
        totalEntries = totalEntries + #entries
        if #entries > 0 or not showGroupHeaders or self.search == "" or not self.options.searchItems then
            preparedGroups[#preparedGroups + 1] = prepared
        end
    end
    self.summary.content = showProgress
            and (tostring(totalCollected) .. "/" .. tostring(totalEntries))
        or (tostring(totalEntries) .. " items")

    local scrollY = 38
    local scrollHeight = math.max(120, self.workspace.height - scrollY)
    if self.itemScroll == nil then
        self.itemScroll = prettyui.SimpleView.new(self.workspace, {
            categoryID = "auto",
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
        })
    end
    self.itemLedger.emptyText = self.options.searchItems and self.search ~= "" and "No items match your search."
        or self.options.emptyItemsText or "No items are mapped for this collection."
    self.itemLedger:Update(preparedGroups, {
        preserveScroll = preserveScroll,
    })
    if self.preparer then self:RefreshPreparedProgress(); self.preparer:Start() end
end

-- Only rebind pooled rows as bounded preparation jobs complete.
function CollectionLogPage:RefreshPreparedProgress()
    if self.preparer == nil then return end
    local collected, total = 0, 0
    for _, group in ipairs(self.preparer.groups) do
        collected, total = collected + group.collected, total + group.total
    end
    self.summary.content = self.options.showProgress == false and tostring(total) .. " items"
        or self.preparer.pending > 0 and "Loading..." or tostring(collected) .. "/" .. tostring(total)
    if self.itemLedger then self.itemLedger:Refresh() end
    if self.preparer.pending == 0 and not self.preparer.sidebarRefreshed and ProgressStyle.greenLogEnabled then
        self.preparer.sidebarRefreshed = true
        self:RebuildRegions(true)
    end
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
