-- Render the collector collections tab
local CollectorCollectionsTab = {}
CollectorCollectionsTab.__index = CollectorCollectionsTab

local SidebarList = require("Resources/Shared/ui/sidebar_list")
local SidebarLayout = require("Resources/Shared/ui/sidebar_layout")
local CollectorCollectionEntries = require("Resources/Features/archaeology/collector_collection_entries")
local CollectorCollectionList = require("Resources/Features/archaeology/collector_collection_list")
local ProgressStyle = require("Resources/Shared/ui/progress_style")

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
            local data = CollectorCollectionEntries.Prepare(self.records, name, self.options.getValue)
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

function CollectorCollectionsTab:Destroy()
    if self.ledger ~= nil then self.ledger:Destroy() end
    self.ledger = nil
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    self.sidebarList = nil
    if self.root ~= nil then self.root:Destroy() end
    self.root = nil
end

return CollectorCollectionsTab
