local SidebarLayout = require("Resources/Shared/ui/sidebar_layout")
local SidebarList = require("Resources/Shared/ui/sidebar_list")
local CollectionDetails = require("Resources/Features/bosses/boss_drops_tab")
local CollectionEntries = require("Resources/Shared/collections/collection_entries")
local ProgressStyle = require("Resources/Shared/ui/progress_style")

local ThievingPage = {}
ThievingPage.__index = ThievingPage

function ThievingPage.new(parent, options)
    local self = setmetatable({ options = options, groups = options.groups }, ThievingPage)
    local shell = SidebarLayout.Create(parent, {
        width = options.width, height = options.height, sidebarTitle = "THIEVING",
    })
    self.root, self.workspace = shell.root, shell.workspace
    self.details = CollectionDetails.new(self.workspace, {
        width = self.workspace.width, height = self.workspace.height,
        progress = options.progress, showPersonalBests = options.showPersonalBests,
        recordHeading = "HEIST", itemLabel = "rewards",
        aggregateLabel = "All", aggregateHeading = "All thieving rewards",
        emptyItemsText = "No collection-log rewards are mapped for this activity.",
    })
    local selected = options.selected
    local found = selected == "All"
    for _, group in ipairs(self.groups) do
        if group.name == selected then found = true end
    end
    if not found then selected = self.groups[1] and self.groups[1].name end
    self:Select(selected)
    return self
end

function ThievingPage:Select(name, preserveScroll)
    self.selected = name
    local scrollY = preserveScroll and self.sidebar and self.sidebar:GetScrollPosition() or 0
    if self.sidebar ~= nil then self.sidebar:Destroy() end
    local entries, selectedGroup, allSections, allItems = {}, nil, {}, {}
    for _, group in ipairs(self.groups) do
        local items = {}
        for _, section in ipairs(group.sections or { group }) do
            allSections[#allSections + 1] = section
            for _, item in ipairs(section.items or {}) do
                items[#items + 1] = item
                allItems[#allItems + 1] = item
            end
        end
        entries[#entries + 1] = { id = group.name, label = group.name,
            complete = ProgressStyle.greenLogEnabled and CollectionEntries.IsComplete(items, {
                getValue = function(variable) return self.options.progress:GetValue(variable) end,
                isCollected = function(item, value) return self.options.progress:IsCollected(item, value) end,
            }) }
        if group.name == name then selectedGroup = group end
    end
    table.insert(entries, 1, { id = "All", label = "All",
        complete = ProgressStyle.greenLogEnabled and CollectionEntries.IsComplete(allItems, {
            getValue = function(variable) return self.options.progress:GetValue(variable) end,
            isCollected = function(item, value) return self.options.progress:IsCollected(item, value) end,
        }) })
    self.sidebar = SidebarList.new(self.root, {
        y = 38, width = SidebarLayout.SIDEBAR_WIDTH, height = self.root.height - 38,
        entries = entries, selected = name,
        scrollY = scrollY,
        onSelect = function(value) self:Select(value) end,
    })
    self.details:Rebuild(name or "Thieving",
        name == "All" and allSections
            or selectedGroup and (selectedGroup.sections or { selectedGroup }) or {}, preserveScroll)
    if not preserveScroll then self.options.onSelect(name) end
end

function ThievingPage:RefreshAccountState()
    self:Select(self.selected, true)
end

function ThievingPage:SetShowPersonalBests(visible)
    self.details.options.showPersonalBests = visible
    self:RefreshAccountState()
end

function ThievingPage:Destroy()
    if self.sidebar ~= nil then self.sidebar:Destroy() end
    self.details:Destroy()
    self.root:Destroy()
end

return ThievingPage
