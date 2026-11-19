-- Render the collector collections tab
local CollectorCollectionsTab = {}
CollectorCollectionsTab.__index = CollectorCollectionsTab

local SidebarList = require("Resources/Shared/ui/sidebar_list")
local SidebarLayout = require("Resources/Shared/ui/sidebar_layout")
local CollectorCollectionEntries = require("Resources/Features/archaeology/collector_collection_entries")
local CollectorCollectionList = require("Resources/Features/archaeology/collector_collection_list")
local ProgressStyle = require("Resources/Shared/ui/progress_style")
local Preparer = require("Resources/Shared/collections/collection_preparer")

local SIDEBAR_WIDTH = SidebarLayout.SIDEBAR_WIDTH

function CollectorCollectionsTab.new(parent, options)
    local self = setmetatable({}, CollectorCollectionsTab)
    self.options = options
    self.records = options.records or {}
    self.selected = options.selected

    local shell = SidebarLayout.CreateHeaded(parent, options, "COLLECTORS", "0/0")
    self.root, self.workspace = shell.root, shell.workspace
    self.heading, self.summary = shell.heading, shell.summary
    self.ledger = CollectorCollectionList.new(self.workspace, {
        y = 46,
        emptyMessage = options.emptyMessage,
        onVisibleRecords = function(records)
            if self.preparer == nil then return end
            self.preparer.visible = {}
            for _, record in ipairs(records) do
                local job = self.jobsByRecord[record]
                if job then self.preparer.visible[#self.preparer.visible + 1] = job end
            end
        end,
    })
    self:RebuildSidebar(false)
    self:RebuildRows(false)
    return self
end

function CollectorCollectionsTab:RebuildSidebar(preserveScroll)
    local previousY = preserveScroll
            and self.sidebarList ~= nil
            and self.sidebarList:GetScrollPosition()
        or 0
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    self.sidebarList = nil

    local selected, groups =
        CollectorCollectionEntries.NormalizeSelection(self.records, self.selected)
    if selected ~= self.selected then
        self.selected = selected
        self.options.onStateChange(selected)
    end

    local entries = { CollectorCollectionEntries.ALL_COLLECTORS }
    for _, group in ipairs(groups) do
        entries[#entries + 1] = group
    end
    if ProgressStyle.greenLogEnabled then
        for index, name in ipairs(entries) do
            local reader = self.options.getValue
            if self.options.deferCollections and self.selected == CollectorCollectionEntries.ALL_COLLECTORS then
                reader = function(reference) return self.options.progress:PeekValue(reference) end
            end
            local data = CollectorCollectionEntries.Prepare(self.records, name, reader)
            entries[index] = { id = name, label = name, complete = data.total > 0 and data.complete == data.total }
        end
    end

    local listY = 38
    self.sidebarList = SidebarList.new(self.root, {
        x = 0,
        y = listY,
        width = SIDEBAR_WIDTH,
        height = math.max(40, self.root.height - listY - 8),
        entries = entries,
        selected = self.selected,
        scrollY = previousY,
        onSelect = function(name)
            if self.selected == name then return end
            self.selected = name
            self.options.onStateChange(name)
            self:RebuildRows(false)
        end,
    })
end

function CollectorCollectionsTab:RebuildRows(preserveScroll)
    if self.options.deferCollections and self.selected == CollectorCollectionEntries.ALL_COLLECTORS then
        self:RebuildDeferred(preserveScroll)
        return
    end
    if self.preparer then self.preparer:Stop(); self.preparer = nil end
    if self.options.progress then self.options.progress.viewport = false end
    if ProgressStyle.greenLogEnabled then self:RebuildSidebar(true) end
    local data =
        CollectorCollectionEntries.Prepare(self.records, self.selected, self.options.getValue)
    self.heading.content = self.selected == CollectorCollectionEntries.ALL_COLLECTORS
            and "ALL COLLECTIONS"
        or string.upper(tostring(self.selected or "COLLECTOR")) .. " COLLECTIONS"
    self.heading:SetSize(self.workspace.width - 120, 30)
    self.summary.content = tostring(data.complete) .. "/" .. tostring(data.total)
    self.ledger:SetData(data, preserveScroll)
end

-- Keep collection metadata while completion variables load around the viewport.
function CollectorCollectionsTab:RebuildDeferred(preserveScroll)
    if self.preparer then self.preparer:Stop() end
    self.options.progress.viewport = true
    self.heading.content = "ALL COLLECTIONS"
    self.collectorData = CollectorCollectionEntries.Prepare(self.records, self.selected, function() return nil end)
    self.jobsByRecord = {}
    self.preparer = Preparer.new({
        isVisible = self.options.isVisible,
        prepareEntry = function(record)
            return {}, CollectorCollectionEntries.IsComplete(self.options.readValue(record.variableName))
        end,
        onChanged = function() self:RefreshDeferredProgress() end,
    })
    for _, group in ipairs(self.collectorData.groups) do
        local records = {}
        for _, entry in ipairs(group.entries) do records[#records + 1] = entry.record end
        local prepared = self.preparer:AddGroup(group.name, records)
        for index, record in ipairs(records) do self.jobsByRecord[record] = prepared.jobs[index] end
    end
    self.summary.content = "Loading..."
    self.ledger:SetData(self.collectorData, preserveScroll)
    self:RefreshDeferredProgress()
    self.preparer:Start()
end

function CollectorCollectionsTab:RefreshDeferredProgress()
    local complete = 0
    for _, group in ipairs(self.collectorData.groups) do
        group.complete, group.pending = 0, false
        for _, entry in ipairs(group.entries) do
            local job = self.jobsByRecord[entry.record]
            entry.complete = self.preparer.complete[entry.record] == true
            if entry.complete then group.complete = group.complete + 1; complete = complete + 1 end
            if not job.loaded then group.pending = true end
        end
    end
    self.summary.content = self.preparer.pending > 0 and "Loading..."
        or tostring(complete) .. "/" .. tostring(self.collectorData.total)
    self.ledger.renderedRangeKey = nil
    self.ledger:Refresh()
    if self.preparer.pending == 0 and ProgressStyle.greenLogEnabled then self:RebuildSidebar(true) end
end

function CollectorCollectionsTab:Destroy()
    if self.preparer then self.preparer:Stop(); self.preparer = nil end
    if self.ledger ~= nil then self.ledger:Destroy() end
    self.ledger = nil
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    self.sidebarList = nil
    if self.root ~= nil then self.root:Destroy() end
    self.root = nil
end

return CollectorCollectionsTab
