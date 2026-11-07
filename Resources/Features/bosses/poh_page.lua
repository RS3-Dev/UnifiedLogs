-- Render the player-owned house collections within Bosses.
local SidebarLayout = require("Resources/Shared/ui/sidebar_layout")
local SidebarList = require("Resources/Shared/ui/sidebar_list")
local TrophyTab = require("Resources/Features/bosses/trophies/trophy_tab")
local TrophyManualState = require("Resources/Features/bosses/trophies/trophy_manual_state")
local FurniturePlansTab = require("Resources/Features/bosses/furniture_plans_tab")
local furniturePlans = require("Resources/Features/bosses/data/furniture_plan_catalog")
local CollectionEntries = require("Resources/Shared/collections/collection_entries")
local ProgressStyle = require("Resources/Shared/ui/progress_style")

local POHPage = {}
POHPage.__index = POHPage

function POHPage.new(parent, options)
    local self = setmetatable({ options = options }, POHPage)
    local shell = SidebarLayout.Create(parent, {
        width = options.width, height = options.height, sidebarTitle = "POH",
    })
    self.root, self.workspace = shell.root, shell.workspace
    self:Select(options.state.selectedPohGroup)
    return self
end

function POHPage:RebuildSidebar()
    local scrollY = self.sidebar and self.sidebar:GetScrollPosition() or 0
    if self.sidebar then self.sidebar:Destroy() end
    local entries = self.options.entries or {}
    self.sidebar = SidebarList.new(self.root, {
        y = 38, width = SidebarLayout.SIDEBAR_WIDTH, height = self.root.height - 38,
        entries = {
            { id = "Trophies", label = "Trophies", complete = #entries > 0
                and TrophyManualState.Count(self.options.state.trophyFound, entries) == #entries },
            { id = "Furniture Plans", label = "Furniture Plans",
                complete = ProgressStyle.greenLogEnabled and CollectionEntries.IsComplete(furniturePlans,
                    FurniturePlansTab.Options(self.options.progress)) },
        },
        selected = self.selected, scrollY = scrollY,
        onSelect = function(name) if self.selected ~= name then self:Select(name) end end,
    })
end

function POHPage:Select(name)
    self.selected = name == "Furniture Plans" and name or "Trophies"
    if self.activeView then self.activeView:Destroy() end
    self.activeView = nil
    self.options.state.selectedPohGroup = self.selected
    self:RebuildSidebar()
    if self.selected == "Trophies" then
        self.activeView = TrophyTab.new(self.workspace, {
            width = self.workspace.width, height = self.workspace.height,
            windowParent = self.options.windowParent, isVisible = self.options.isVisible,
            entries = self.options.entries, resolveObject = self.options.resolveObject,
            tooltip = self.options.tooltip, state = self.options.state,
            catalogueColumns = 8, minimumPreviewWidth = 220,
            saveState = function()
                self.options.saveState()
                self:RebuildSidebar()
            end,
        })
    else
        self.activeView = FurniturePlansTab.new(self.workspace, {
            width = self.workspace.width, height = self.workspace.height,
            progress = self.options.progress,
        })
    end
    self.options.saveState()
end

function POHPage:RefreshAccountState()
    if self.activeView then self.activeView:RefreshAccountState() end
    self:RebuildSidebar()
end

function POHPage:Destroy()
    if self.activeView then self.activeView:Destroy() end
    if self.sidebar then self.sidebar:Destroy() end
    if self.root then self.root:Destroy() end
    self.activeView, self.sidebar, self.root = nil, nil, nil
end

return POHPage
