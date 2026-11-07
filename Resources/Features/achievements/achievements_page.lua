-- Render the achievements page
local LazyTabs = require("Resources/Shared/ui/lazy_tabs")
local CapeOverview = require("Resources/Features/achievements/cape_overview")
local CapeRequirements = require("Resources/Features/achievements/cape_requirements")
local CapeRequirementsView = require("Resources/Features/achievements/cape_requirements_view")

local AchievementsPage = {}
AchievementsPage.__index = AchievementsPage

function AchievementsPage.new(parent, options)
    local self = setmetatable({}, AchievementsPage)
    self.options = options
    self.section = options.section
    self.state = options.state
    self.activeView = nil
    self.snapshot = CapeRequirements.NewSnapshot()
    self.searchDirty = false
    self.root = ui.Layer.new(parent)
    self.root:SetPos(options.x or 0, options.y or 0)
    self.root:SetSize(options.width, options.height)
    self.root.clickthrough = true

    self.isBuilding = true
    self.tabHost = LazyTabs.new(
        self.root,
        self.section.modes,
        self.state.achievementMode,
        function(_, _, modeID)
            if self.isBuilding then return end
            self:SetMode(modeID, false)
        end
    )
    self.tabs = self.tabHost.tabs
    self.isBuilding = false
    self:SetMode(self.state.achievementMode, true)
    return self
end

-- Save search
function AchievementsPage:PersistSearch()
    if not self.searchDirty then return end
    self.searchDirty = false
    self.options.saveState()
end

function AchievementsPage:SetMode(modeID, force)
    local mode = self.tabHost:Mode(modeID) or self.section.modes[1]
    if mode == nil or not force and self.state.achievementMode == mode.id then return end

    -- Save pending search text with the selected mode
    self.searchDirty = false
    self.state.achievementMode = mode.id
    self.activeView = select(1, self.tabHost:Activate(mode.id, true, function(_, page)
        if mode.id == "overview" then
            return CapeOverview.new(page, {
                width = page.width,
                height = page.height,
                capes = self.section.capes,
                snapshot = self.snapshot,
                onSelect = function(selectedMode) self:SetMode(selectedMode, false) end,
            })
        end
        return CapeRequirementsView.new(page, {
            width = page.width,
            height = page.height,
            cape = mode.cape,
            snapshot = self.snapshot,
            orderView = self.state.achievementOrderView,
            filterMode = self.state.achievementRequirementFilter,
            search = self.state.achievementRequirementSearch,
            onFilterChange = function(value)
                self.state.achievementRequirementFilter = value
                self.options.saveState()
            end,
            onSearchChange = function(value, persist)
                self.state.achievementRequirementSearch = value
                self.searchDirty = true
                if persist then self:PersistSearch() end
            end,
        })
    end))
    self.options.saveState()
end

function AchievementsPage:SetOrderView(value)
    local normalized = value == "tree" and "tree" or "linear"
    if
        self.state.achievementOrderView == normalized
        and (
            self.state.achievementMode == "overview"
            or self.activeView ~= nil and self.activeView.orderView == normalized
        )
    then
        return
    end
    self.state.achievementOrderView = normalized
    self.options.saveState()
    if self.state.achievementMode ~= "overview" then
        self:SetMode(self.state.achievementMode, true)
    end
end

function AchievementsPage:RefreshAccountState()
    self.snapshot = CapeRequirements.NewSnapshot()
    self:SetMode(self.state.achievementMode, true)
end

function AchievementsPage:Destroy()
    self:PersistSearch()
    if self.tabHost ~= nil then self.tabHost:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.tabHost = nil
    self.tabs = nil
    self.root = nil
end

return AchievementsPage
