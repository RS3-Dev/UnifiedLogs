-- Render the archaeology page
local LazyTabs = require("Resources/Shared/ui/lazy_tabs")
local GameData = require("Resources/Lib/game_data")
local MysteriesTab = require("Resources/Features/archaeology/mysteries_tab")
local CollectorCollectionsTab = require("Resources/Features/archaeology/collector_collections_tab")
local RelicsTab = require("Resources/Features/archaeology/relics_tab")
local RelicLoadoutsTab = require("Resources/Features/archaeology/relic_loadouts_tab")
local CollectionLogPage = require("Resources/Shared/collections/collection_log_page")

local ArchaeologyPage = {}
ArchaeologyPage.__index = ArchaeologyPage

function ArchaeologyPage.new(parent, options)
    local self = setmetatable({}, ArchaeologyPage)
    self.options = options
    self.section = self.options.section
    self.state = self.options.state
    self.activeView = nil

    self.root = ui.Layer.new(parent)
    self.root:SetPos(self.options.x or 0, self.options.y or 0)
    self.root:SetSize(self.options.width, self.options.height)
    self.root.clickthrough = true

    self.tabHost = LazyTabs.new(
        self.root,
        self.section.modes,
        self.state.archaeologyMode,
        function(_, _, modeID) self:SetMode(modeID, false) end
    )
    self.tabs = self.tabHost.tabs
    self:SetMode(self.state.archaeologyMode, true)
    return self
end

function ArchaeologyPage:SetMode(modeID, force)
    local mode = self.tabHost:Mode(modeID) or self.section.modes[1]
    if mode == nil or not force and self.state.archaeologyMode == mode.id then return end

    self.state.archaeologyMode = mode.id
    self.activeView = select(1, self.tabHost:Activate(mode.id, true, function(_, page)
        if mode.id == "other" then
            local otherOptions = self.options.otherOptions
            otherOptions.selected = self.state.selectedArchaeologyOtherGroup
            otherOptions.search = self.state.archaeologyOtherSearch
            otherOptions.x, otherOptions.y = 0, 0
            otherOptions.width, otherOptions.height = page.width, page.height
            return CollectionLogPage.new(page, otherOptions)
        elseif mode.id == "mysteries" then
            return MysteriesTab.new(page, {
                width = page.width,
                height = page.height,
                data = mode.data,
                selected = self.state.selectedMysterySite,
                getValue = GameData.TrackingValue,
                onStateChange = function(selected)
                    self.state.selectedMysterySite = selected
                    self.options.saveState()
                end,
            })
        elseif mode.id == "collectors" then
            return CollectorCollectionsTab.new(page, {
                width = page.width,
                height = page.height,
                records = mode.data.records,
                selected = self.state.selectedCollector,
                getValue = GameData.TrackingValue,
                emptyMessage = "No collector records were supplied by the current manifest.",
                onStateChange = function(selected)
                    self.state.selectedCollector = selected
                    self.options.saveState()
                end,
            })
        elseif mode.id == "relics" then
            return RelicsTab.new(page, {
                width = page.width,
                height = page.height,
                records = mode.data.records,
                selected = self.state.selectedRelicCategory,
                onStateChange = function(selected)
                    self.state.selectedRelicCategory = selected
                    self.options.saveState()
                end,
            })
        elseif mode.id == "loadouts" then
            return RelicLoadoutsTab.new(page, {
                width = page.width,
                height = page.height,
                records = mode.data.records,
                loadouts = mode.data.loadouts,
                selected = self.state.selectedRelicLoadout,
                onStateChange = function(selected)
                    self.state.selectedRelicLoadout = selected
                    self.options.saveState()
                end,
            })
        end
        error("Unsupported Archaeology mode: " .. tostring(mode.id))
    end))
    if mode.id == "other" then
        self.state.selectedArchaeologyOtherGroup = self.activeView.selected
    elseif mode.id == "collectors" then
        self.state.selectedCollector = self.activeView.selected
    elseif mode.id == "relics" then
        self.state.selectedRelicCategory = self.activeView.selected
    elseif mode.id == "loadouts" then
        self.state.selectedRelicLoadout = self.activeView.selected
    end
    self.options.saveState()
end

function ArchaeologyPage:RefreshAccountState()
    if self.state.archaeologyMode == "other" and self.activeView ~= nil then
        self.activeView:RebuildGrid(true)
    elseif self.state.archaeologyMode == "mysteries" and self.activeView ~= nil then
        self.activeView:Rebuild(true)
    elseif self.state.archaeologyMode == "collectors" and self.activeView ~= nil then
        self.activeView:RebuildRows(true)
    elseif self.state.archaeologyMode == "relics" and self.activeView ~= nil then
        self.activeView:Rebuild(true)
    elseif self.state.archaeologyMode == "loadouts" and self.activeView ~= nil then
        self.activeView:RefreshAccountState()
    end
end

function ArchaeologyPage:Destroy()
    if self.tabHost ~= nil then self.tabHost:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.tabHost = nil
    self.tabs = nil
    self.root = nil
end

return ArchaeologyPage
