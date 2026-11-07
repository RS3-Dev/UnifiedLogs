-- Render the misc page
local LazyTabs = require("Resources/Shared/ui/lazy_tabs")
local CollectionLogPage = require("Resources/Shared/collections/collection_log_page")

local MiscPage = {}
MiscPage.__index = MiscPage

function MiscPage.new(parent, options)
    local self = setmetatable({}, MiscPage)
    self.options = options
    self.root = ui.Layer.new(parent)
    self.root:SetPos(options.x or 0, options.y or 0)
    self.root:SetSize(options.width, options.height)
    self.root.clickthrough = true

    self.tabHost = LazyTabs.new(self.root, options.section.modes, options.state.miscMode,
        function(_, _, modeID) self:SetMode(modeID, false) end)
    self.tabs = self.tabHost.tabs
    self:SetMode(options.state.miscMode, true)
    return self
end

function MiscPage:SetMode(modeID, force)
    local mode = self.tabHost:Mode(modeID) or self.options.section.modes[1]
    if mode == nil or not force and self.tabHost.activeMode == mode.id then return end
    local options = self.options
    options.state.miscMode = mode.id
    self.pofView = nil
    self.activeView = select(1, self.tabHost:Activate(mode.id, true, function(_, page)
        if mode.id == "thieving" then
            return require("Resources/Features/misc/thieving/thieving_page").new(page, {
                width = page.width, height = page.height,
                groups = options.thieving.groups,
                progress = options.progress,
                selected = options.state.selectedThievingGroup,
                showPersonalBests = options.state.showPersonalBests,
                onSelect = function(selected)
                    options.state.selectedThievingGroup = selected
                    options.saveState()
                end,
            })
        end
        if mode.id == "skilling_outfits" then
            local outfitOptions = options.skillingOutfitOptions
            outfitOptions.selected = options.state.selectedSkillingOutfitGroup
            outfitOptions.search = options.state.skillingOutfitSearch
            outfitOptions.x, outfitOptions.y = 0, 0
            outfitOptions.width, outfitOptions.height = page.width, page.height
            local view = CollectionLogPage.new(page, outfitOptions)
            options.state.selectedSkillingOutfitGroup = view.selected
            return view
        end
        if mode.id == "minigames" then
            local minigameOptions = options.minigameOptions
            minigameOptions.selected = options.state.selectedMinigameGroup
            minigameOptions.search = options.state.minigameSearch
            minigameOptions.x, minigameOptions.y = 0, 0
            minigameOptions.width, minigameOptions.height = page.width, page.height
            local view = CollectionLogPage.new(page, minigameOptions)
            options.state.selectedMinigameGroup = view.selected
            return view
        end
        if mode.id == "pets" then
            local petOptions = options.petOptions
            petOptions.selected = options.state.selectedPetGroup
            petOptions.search = options.state.petSearch
            petOptions.x, petOptions.y = 0, 0
            petOptions.width, petOptions.height = page.width, page.height
            local view = CollectionLogPage.new(page, petOptions)
            options.state.selectedPetGroup = view.selected
            return view
        end
        if mode.id == "enchantments" then
            local enchantmentOptions = options.enchantmentOptions
            enchantmentOptions.selected = options.state.selectedEnchantmentGroup
            enchantmentOptions.search = options.state.enchantmentSearch
            enchantmentOptions.x, enchantmentOptions.y = 0, 0
            enchantmentOptions.width, enchantmentOptions.height = page.width, page.height
            local view = CollectionLogPage.new(page, enchantmentOptions)
            options.state.selectedEnchantmentGroup = view.selected
            return view
        end
        local pofOptions = options.pofOptions
        pofOptions.selected = options.state.selectedPofGroup
        pofOptions.search = options.state.pofSearch
        pofOptions.x, pofOptions.y = 0, 0
        pofOptions.width, pofOptions.height = page.width, page.height
        local view = CollectionLogPage.new(page, pofOptions)
        options.state.selectedPofGroup = view.selected
        self.pofView = view
        return view
    end))
    options.saveState()
end

function MiscPage:RefreshAccountState()
    if self.activeView == nil then return end
    if self.tabHost.activeMode == "thieving" then
        self.activeView:RefreshAccountState()
    else
        self.activeView:RebuildGrid(true)
    end
end

function MiscPage:SetShowPersonalBests(visible)
    self.options.state.showPersonalBests = visible
    if self.tabHost.activeMode == "thieving" and self.activeView ~= nil then
        self.activeView:SetShowPersonalBests(visible)
    end
end

function MiscPage:Destroy()
    if self.tabHost ~= nil then self.tabHost:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.pofView = nil
    self.activeView = nil
    self.tabHost = nil
    self.tabs = nil
    self.root = nil
end

return MiscPage
