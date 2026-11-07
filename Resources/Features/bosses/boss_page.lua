-- Render the boss page
local UI = require("Resources/Shared/ui/components")
local LazyTabs = require("Resources/Shared/ui/lazy_tabs")
local Settings = require("Resources/Lib/settings")
local SidebarLayout = require("Resources/Shared/ui/sidebar_layout")
local SidebarList = require("Resources/Shared/ui/sidebar_list")
local DebouncedAction = require("Resources/Lib/debounced_action")
local BossCategories = require("Resources/Features/bosses/boss_categories")
local CombatAchievementsTab = require("Resources/Features/bosses/combat_achievements_tab")
local POHPage = require("Resources/Features/bosses/poh_page")
local BossDropsTab = require("Resources/Features/bosses/boss_drops_tab")
local CollectionLogPage = require("Resources/Shared/collections/collection_log_page")
local CollectionEntries = require("Resources/Shared/collections/collection_entries")
local ProgressStyle = require("Resources/Shared/ui/progress_style")

local BossPage = {}
BossPage.__index = BossPage

local SUBLOG_NAV_HEIGHT = 42
local SIDEBAR_WIDTH = 220
local WORKSPACE_X = SIDEBAR_WIDTH + 8
local SEARCH_DEBOUNCE_TICKS = 10
local SEARCH_EVENT = "unifiedlogs_boss_search"
local TABLE_EVENT = "unifiedlogs_boss_table"

function BossPage.new(parent, options)
    local self = setmetatable({}, BossPage)
    self.options = options
    self.section = self.options.section
    self.state = self.options.state
    self.achievements = self.options.achievements or {}
    self.dropLogs = self.options.dropLogs or {}
    self.bossRecords = self.options.bossRecords or {}
    self.bossKillCounts = self.options.bossKillCounts or {}
    self.progress = self.options.progress
    self.model =
        BossCategories.new(self.achievements, self.dropLogs, self.bossRecords, self.bossKillCounts)
    self.searchPending = false
    self.categorySearchPending = false

    self.model:EnsureSelectedCategory(self.state)
    self.isBuilding = true
    self:Build(parent)
    self.isBuilding = false
    self:SubscribeSearchEvent()
    self:SetMode(self.state.activeTab, true)
    return self
end

function BossPage:IsDropsActive() return self.state.activeTab == 2 end

function BossPage:IsCombatActive() return self.state.activeTab == 1 end

function BossPage:IsTrophiesActive() return self.state.activeTab == 3 end

function BossPage:IsSlayerActive() return self.state.activeTab == 4 end

function BossPage:IsAbilitiesActive() return self.state.activeTab == 5 end

function BossPage:IsBossCategoryActive() return self:IsDropsActive() or self:IsCombatActive() end

function BossPage:SaveState() self.options.saveState() end

function BossPage:SubscribeSearchEvent()
    self.searchAction = DebouncedAction.new(SEARCH_EVENT, SEARCH_DEBOUNCE_TICKS, function()
        if self.root == nil then return end
        if self.categorySearchPending then
            self.categorySearchPending = false
            if self:IsBossCategoryActive() then self:RebuildCategories(false) end
        end
        if self.searchPending then
            self.searchPending = false
            if self:IsCombatActive() then self:RebuildAchievements(false) end
        end
        self:SaveState()
    end)
    self.tableAction = DebouncedAction.new(TABLE_EVENT, 1, function()
        if self.root ~= nil and self:IsCombatActive() then self:RebuildAchievements(true) end
    end)
end

-- Get the selected category name
function BossPage:SelectedCategoryName()
    return self.model:CategoryName(self.state.selectedCategoryID)
end

-- Build the bosses page
function BossPage:Build(parent)
    self.root = ui.Layer.new(parent)
    self.root:SetPos(self.options.x or 0, self.options.y or 0)
    self.root:SetSize(self.options.width, self.options.height)
    self.root.clickthrough = true

    self.tabHost = LazyTabs.new(
        self.root,
        self.section.modes,
        self.state.activeTab,
        function(_, _, modeID)
            if self.isBuilding then return end
            self:SetMode(modeID, false)
        end
    )
    self.tabs = self.tabHost.tabs

    local shell = SidebarLayout.Attach(self.root, {
        sidebarWidth = SIDEBAR_WIDTH,
        sidebarY = SUBLOG_NAV_HEIGHT,
        sidebarTitle = "BOSS",
        titleY = SUBLOG_NAV_HEIGHT + 2,
        titleHeight = 28,
        createWorkspace = false,
    })
    self.sidebarBackground = shell.sidebarBackground
    self.sidebarDivider = shell.sidebarDivider
    self.sidebarHeading = shell.sidebarTitle
    self.categorySearchField = prettyui.TextField.new(self.root, {
        x = 10,
        y = SUBLOG_NAV_HEIGHT + 34,
        width = SIDEBAR_WIDTH - 20,
        height = 28,
        text = self.state.categorySearch,
        placeholder = "Search bosses...",
        maxLength = 60,
        onChange = function(_, reason, content)
            self.state.categorySearch = tostring(content or "")
            self.categorySearchPending = true
            self.searchAction:Trigger(reason == ui.InputFieldActionResult.SUBMIT)
        end,
    })

end

function BossPage:ClearModeViewReferences()
    self.activeView = nil
    self.combatView = nil
    self.dropsView = nil
    self.trophiesView = nil
    self.slayerView = nil
    self.abilitiesView = nil
end

function BossPage:CreateModeView(modeID, page)
    local workspaceWidth = self.root.width - WORKSPACE_X
    local contentHeight = self.root.height - SUBLOG_NAV_HEIGHT
    if modeID == 1 then
        self.combatView = CombatAchievementsTab.new(page, {
            x = WORKSPACE_X,
            y = 0,
            width = workspaceWidth,
            height = contentHeight,
            state = self.state,
            model = self.model,
            achievements = self.achievements,
            categoryName = function() return self:SelectedCategoryName() end,
            onSearchChange = function(reason)
                self.searchPending = true
                self.searchAction:Trigger(reason == ui.InputFieldActionResult.SUBMIT)
            end,
            onFilterChange = function()
                self:SaveState()
                self:RebuildAchievements(false)
            end,
            onToggleTier = function(group) self:ToggleTier(group) end,
        })
        return self.combatView
    elseif modeID == 2 then
        self.dropsView = BossDropsTab.new(page, {
            x = WORKSPACE_X,
            y = 0,
            width = workspaceWidth,
            height = contentHeight,
            progress = self.progress,
            tickSeconds = self.options.tickSeconds,
            showPersonalBests = self.state.showPersonalBests ~= false,
        })
        return self.dropsView
    elseif modeID == 3 then
        local trophySection = self.options.trophySection or {}
        self.trophiesView = POHPage.new(page, {
            x = 0,
            y = 0,
            width = self.root.width,
            height = contentHeight,
            windowParent = self.options.windowParent,
            isVisible = self.options.isVisible,
            entries = (trophySection.logs or {}).Trophies or {},
            progress = self.progress,
            resolveObject = self.options.resolveTrophyObject,
            tooltip = self.options.trophyTooltip,
            state = self.state,
            saveState = function() self:SaveState() end,
        })
        return self.trophiesView
    end

    if modeID == 5 then
        local abilitiesOptions = self.options.abilitiesOptions
        abilitiesOptions.selected = self.state.selectedAbilityGroup
        abilitiesOptions.search = self.state.abilitySearch
        abilitiesOptions.x, abilitiesOptions.y = 0, 0
        abilitiesOptions.width, abilitiesOptions.height = self.root.width, contentHeight
        self.abilitiesView = CollectionLogPage.new(page, abilitiesOptions)
        self.state.selectedAbilityGroup = self.abilitiesView.selected
        return self.abilitiesView
    end
    local slayerOptions = self.options.slayerOptions
    slayerOptions.x = 0
    slayerOptions.y = 0
    slayerOptions.width = self.root.width
    slayerOptions.height = contentHeight
    self.slayerView = CollectionLogPage.new(page, slayerOptions)
    return self.slayerView
end

function BossPage:SetBossSidebarVisible(visible)
    local hidden = visible ~= true
    for _, component in ipairs({
        self.sidebarBackground,
        self.sidebarDivider,
        self.sidebarHeading,
    }) do
        if component ~= nil then component.hidden = hidden end
    end
    if self.categorySearchField ~= nil and self.categorySearchField.root ~= nil then
        self.categorySearchField.root.hidden = hidden
    end
    if self.sidebarList ~= nil then self.sidebarList:SetHidden(hidden) end
    if self.emptySidebarText ~= nil then self.emptySidebarText.hidden = hidden end
end

function BossPage:UpdateHeadings()
    local categoryName = self:SelectedCategoryName()
    if self.combatView ~= nil then self.combatView:UpdateHeading(categoryName) end
    if self.dropsView ~= nil then
        self.dropsView.heading.content = self.state.selectedCategoryID == Settings.ALL_CATEGORIES_ID
                and "All boss drops"
            or categoryName .. " drops"
    end
end

function BossPage:DestroySidebarContent()
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    if self.emptySidebarText ~= nil then self.emptySidebarText:Destroy() end
    self.sidebarList = nil
    self.emptySidebarText = nil
end

function BossPage:RebuildCategories(preserveScroll)
    local previousY = preserveScroll
            and self.sidebarList ~= nil
            and self.sidebarList:GetScrollPosition()
        or 0
    self:DestroySidebarContent()

    local listY = SUBLOG_NAV_HEIGHT + 72
    local listHeight = math.max(120, self.root.height - listY)
    local entries = self.model:CategoryEntries(self.state.categorySearch, self:IsDropsActive())
    local listEntries = {}
    for _, category in ipairs(entries) do
        local complete, total = true, 0
        if ProgressStyle.greenLogEnabled then
            if self:IsDropsActive() then
                for _, group in ipairs(self.model:SelectedDropGroups({ selectedCategoryID = category.id })) do
                    total = total + #group.items
                    if not CollectionEntries.IsComplete(group.items, {
                        getValue = function(name) return self.progress:GetValue(name) end,
                        isCollected = function(item, value) return self.progress:IsCollected(item, value) end,
                    }) then complete = false end
                end
            else
                local categoryID = self.model:PageCategoryID(category.id)
                for _, achievement in ipairs(self.achievements) do
                    if categoryID == Settings.ALL_CATEGORIES_ID or achievement.categoryID == categoryID then
                        total = total + 1
                        if achievement.complete ~= true then complete = false end
                    end
                end
            end
        end
        listEntries[#listEntries + 1] = { id = category.id, label = category.name,
            complete = total > 0 and complete }
    end
    self.sidebarList = SidebarList.new(self.root, {
        x = 0,
        y = listY,
        width = SIDEBAR_WIDTH,
        height = listHeight,
        entries = listEntries,
        selected = self.state.selectedCategoryID,
        scrollY = previousY,
        onSelect = function(categoryID)
            if self.state.selectedCategoryID == categoryID then return end
            self.state.selectedCategoryID = categoryID
            self:SaveState()
            self:UpdateHeadings()
            if self:IsDropsActive() then
                self:RebuildDrops(false)
            else
                self:RebuildAchievements(false)
            end
        end,
    })
    if #entries == 0 then
        self.emptySidebarText =
            UI.Text(self.root, "No categories match.", 12, listY + 8, SIDEBAR_WIDTH - 24, 32, {
                colour = 0xC9BEA4FF,
                maxLines = 2,
                alignVertical = ui.AlignMode.TOPLEFT,
            })
        self.emptySidebarText:MoveToFront()
    end
    self.sidebarList:SetHidden(not self:IsBossCategoryActive())
    if self.emptySidebarText ~= nil then
        self.emptySidebarText.hidden = not self:IsBossCategoryActive()
    end
end

function BossPage:ToggleTier(group)
    self.state.collapsedTiers[group] = not (self.state.collapsedTiers[group] == true)
    self:SaveState()
    self.tableAction:Trigger(true)
end

function BossPage:RebuildAchievements(preserveScroll)
    if self.combatView ~= nil then self.combatView:Rebuild(preserveScroll) end
end

function BossPage:RebuildDrops(preserveScroll)
    if self.dropsView == nil then return end
    local categoryName = self.state.selectedCategoryID == Settings.ALL_CATEGORIES_ID
            and "All bosses"
        or self:SelectedCategoryName()
    self.dropsView:Rebuild(categoryName, self.model:SelectedDropGroups(self.state), preserveScroll)
end

function BossPage:SetShowPersonalBests(visible)
    self.state.showPersonalBests = visible == true
    if self.dropsView ~= nil then
        self.dropsView.options.showPersonalBests = self.state.showPersonalBests
    end
    if self:IsDropsActive() then self:RebuildDrops(true) end
end

function BossPage:SetMode(modeID, force)
    modeID = tonumber(modeID)
    if modeID ~= 1 and modeID ~= 2 and modeID ~= 3 and modeID ~= 4 and modeID ~= 5 then modeID = 1 end
    if not force and self.state.activeTab == modeID then return end
    self.state.activeTab = modeID

    if modeID == 1 then
        local categoryExists = self.state.selectedCategoryID == Settings.ALL_CATEGORIES_ID
        local categoryID = self.model:PageCategoryID(self.state.selectedCategoryID)
        for _, achievement in ipairs(self.achievements) do
            if achievement.categoryID == categoryID then
                categoryExists = true
                break
            end
        end
        if not categoryExists then self.state.selectedCategoryID = Settings.ALL_CATEGORIES_ID end
    end

    if
        modeID == 2
        and self.state.selectedCategoryID ~= Settings.ALL_CATEGORIES_ID
        and #self.model:SelectedDropGroups(self.state) == 0
    then
        for _, category in ipairs(self.model:OrderedCategories()) do
            if #self.model:MatchingDropGroups(category.id, category.name) > 0 then
                self.state.selectedCategoryID = category.id
                break
            end
        end
    end

    self:ClearModeViewReferences()
    self.activeView = select(1, self.tabHost:Activate(modeID, true, function(_, page)
        return self:CreateModeView(modeID, page)
    end))
    self:SetBossSidebarVisible(modeID == 1 or modeID == 2)
    if modeID == 3 then
        self:DestroySidebarContent()
    elseif modeID == 1 or modeID == 2 then
        self:RebuildCategories(false)
        self:UpdateHeadings()
    else
        self:DestroySidebarContent()
    end
    if modeID == 2 then
        self:RebuildDrops(false)
    elseif modeID == 1 then
        self:RebuildAchievements(false)
    end
    self.options.refreshProgress()
    self:SaveState()
end

function BossPage:RefreshAccountState()
    if ProgressStyle.greenLogEnabled and self:IsBossCategoryActive() then self:RebuildCategories(true) end
    if self:IsDropsActive() then
        self:RebuildDrops(true)
    elseif self:IsTrophiesActive() and self.trophiesView ~= nil then
        self.trophiesView:RefreshAccountState()
    elseif self:IsSlayerActive() and self.slayerView ~= nil then
        self.slayerView:RebuildGrid(true)
    elseif self:IsAbilitiesActive() and self.abilitiesView ~= nil then
        self.abilitiesView:RebuildGrid(true)
    end
end

function BossPage:RefreshAchievements()
    if ProgressStyle.greenLogEnabled and self:IsCombatActive() then self:RebuildCategories(true) end
    if self:IsCombatActive() then self:RebuildAchievements(true) end
end

function BossPage:Destroy()
    if self.searchPending or self.categorySearchPending then
        self.searchPending = false
        self.categorySearchPending = false
        self:SaveState()
    end
    if self.searchAction ~= nil then self.searchAction:Destroy() end
    if self.tableAction ~= nil then self.tableAction:Destroy() end
    self:DestroySidebarContent()
    if self.tabHost ~= nil then self.tabHost:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.tabHost = nil
    self.activeView = nil
    self.dropsView = nil
    self.trophiesView = nil
    self.slayerView = nil
    self.combatView = nil
    self.abilitiesView = nil
    self.sidebarList = nil
    self.emptySidebarText = nil
    self.tabs = nil
    self.root = nil
end

return BossPage
