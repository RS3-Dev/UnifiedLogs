-- Render the achievements page
local UI = require("Resources/Shared/ui/components")
local LazyTabs = require("Resources/Shared/ui/sidebar_pages")
local CapeRequirements = require("Resources/Features/achievements/cape_requirements")
local CapeRequirementsView = require("Resources/Features/achievements/cape_requirements_view")

local AchievementsPage = {}
AchievementsPage.__index = AchievementsPage

function AchievementsPage.new(parent, options)
    local self = setmetatable({}, AchievementsPage)
    self.options = options
    self.section = options.section
    self.state = options.state
    self.keys = options.stateKeys or { mode = "achievementMode", search = "achievementRequirementSearch",
        filter = "achievementRequirementFilter" }
    self.activeView = nil
    self.snapshot = self:NewSnapshot()
    self.searchDirty = false
    self.root = UI.ContentLayer(parent)
    self.root:SetPos(options.x or 0, options.y or 0)
    self.root:SetSize(options.width, options.height)
    self.root.clickthrough = true

    self.isBuilding = true
    self.tabHost = LazyTabs.new(
        self.root,
        (self.section.capeModes or self.section.modes),
        self.state[self.keys.mode],
        function(_, _, modeID)
            if self.isBuilding then return end
            self:SetMode(modeID, false)
        end
    )
    self.tabHost.shell.sidebarTitle.content = options.sidebarTitle or "CAPES"
    self.tabs = self.tabHost.tabs
    self.isBuilding = false
    self:SetMode(self.state[self.keys.mode], true)
    return self
end

-- Update cached progress in small batches without rebuilding the native page.
function AchievementsPage:NewSnapshot()
    return CapeRequirements.NewSnapshot({
        isVisible = self.options.isVisible,
        onChanged = function()
            if self.activeView == nil then return end
            self.activeView:ApplyFilters(true)
        end,
    })
end

-- Save search
function AchievementsPage:PersistSearch()
    if not self.searchDirty then return end
    self.searchDirty = false
    self.options.saveState()
end

function AchievementsPage:SetMode(modeID, force)
    local mode = self.tabHost:Mode(modeID) or (self.section.capeModes or self.section.modes)[1]
    if mode == nil or not force and self.state[self.keys.mode] == mode.id then return end

    -- Save pending search text with the selected mode
    self.searchDirty = false
    self.state[self.keys.mode] = mode.id
    self.snapshot.visible = {}
    self.activeView = select(1, self.tabHost:Activate(mode.id, true, function(_, page)
        return CapeRequirementsView.new(page, {
            width = page.width,
            height = page.height,
            cape = mode.cape,
            isVisible = self.options.isVisible,
            snapshot = self.snapshot,
            orderView = self.options.orderView or self.state.achievementOrderView,
            filterMode = self.state[self.keys.filter],
            search = self.state[self.keys.search],
            onFilterChange = function(value)
                self.state[self.keys.filter] = value
                self.options.saveState()
            end,
            onSearchChange = function(value, persist)
                self.state[self.keys.search] = value
                self.searchDirty = true
                if persist then self:PersistSearch() end
            end,
        })
    end))
    self.options.saveState()
end

function AchievementsPage:SetOrderView(value)
    local normalized = value == "tree" and "tree" or "linear"
    if self.state.achievementOrderView == normalized and self.activeView
        and self.activeView.orderView == normalized then return end
    self.state.achievementOrderView = normalized
    self.options.saveState()
    self:SetMode(self.state[self.keys.mode], true)
end

function AchievementsPage:RefreshAccountState()
    if self.snapshot.Stop then self.snapshot:Stop() end
    self.snapshot = self:NewSnapshot()
    self:SetMode(self.state[self.keys.mode], true)
end

function AchievementsPage:Destroy()
    if self.snapshot.Stop then self.snapshot:Stop() end
    self:PersistSearch()
    if self.tabHost ~= nil then self.tabHost:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.tabHost = nil
    self.tabs = nil
    self.root = nil
end

return AchievementsPage
