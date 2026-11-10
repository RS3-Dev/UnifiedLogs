-- Render the quest page
local QuestPage = {}
QuestPage.__index = QuestPage

local QuestRequirements = require("Resources/Features/quests/quest_requirements")
local QuestDetailsPanel = require("Resources/Features/quests/quest_details_panel")
local SkillIcons = require("Resources/Shared/skills/skill_icons")
local UI = require("Resources/Shared/ui/components")
local SidebarLayout = require("Resources/Shared/ui/sidebar_layout")
local SidebarList = require("Resources/Shared/ui/sidebar_list")
local QuestHelper = require("Resources/Features/quests/quest_helper")

local MENU_EVENT = "unifiedlogs_quest_menu"
local DEPENDENCY_EVENT = "unifiedlogs_quest_dependency"
local QUEST_SPRITE = id.Sprite.RS3_ICON_MENU_TAB_QUEST_LIST_0

local SIDEBAR_WIDTH = 250
local WORKSPACE_X = SIDEBAR_WIDTH + 8
local LIST_TOP = 34
local FILTER_BUTTON_SIZE = 24
local FILTER_GAP = 6
local FILTER_SHEET_WIDTH = 230
local FILTER_SHEET_HEIGHT = 216

local QUEST_SORT_NAME = 1
local QUEST_SORT_STATUS = 2
local QUEST_SORT_RELEASE = 3
local QUEST_SORT_ENTRIES = {
    { label = "Name", id = QUEST_SORT_NAME },
    { label = "Status", id = QUEST_SORT_STATUS },
    { label = "Release date", id = QUEST_SORT_RELEASE },
}

local QUEST_STATUS_COLOURS = {
    complete = 0x71E69AFF,
    started = 0xF2C66DFF,
    incomplete = 0xE06A5FFF,
}

-- Read a quest sort ID
local function questSortEntryID(sortBy)
    if sortBy == "status" then return QUEST_SORT_STATUS end
    if sortBy == "release" then return QUEST_SORT_RELEASE end
    return QUEST_SORT_NAME
end

-- Create quest page text
local function text(parent, value, x, y, width, height, options)
    options = options or {}
    if options.font == nil then options.font = id.Font.MUSEO_SANS_13PT_REGULAR end
    return UI.Text(parent, value, x, y, width, height, options)
end

function QuestPage.new(parent, options)
    local self = setmetatable({}, QuestPage)
    self.options = options
    self.records = self.options.records or {}
    self.byID = {}
    -- Lowercase names once for searching and sorting
    self.searchNames = {}
    self.search = tostring(self.options.search or "")
    self.searchDirty = false
    self.selectedID = tonumber(self.options.selectedID)
    self.statusFilter = (self.options.statusFilter == "completed" or self.options.statusFilter == "incomplete")
        and self.options.statusFilter or "all"
    self.showMiniquests = self.options.showMiniquests ~= false
    self.showSeasonalQuests = self.options.showSeasonalQuests ~= false
    self.availableInQH = self.options.availableInQH == true
    self.sortBy = (self.options.sortBy == "status" or self.options.sortBy == "release")
            and self.options.sortBy
        or "name"
    self.useCumulativeRequirements = self.options.useCumulativeRequirements ~= false
    self.orderView = self.options.orderView == "tree" and "tree" or "linear"
    self.requirementFilter = self.options.requirementFilter == "incomplete" and "incomplete" or "all"
    self.filterOpen = false
    self.history = {}
    for _, quest in ipairs(self.records) do
        self.byID[quest.id] = quest
        self.searchNames[quest] = UI.Lower(quest.name)
    end
    if self.byID[self.selectedID] == nil and self.records[1] ~= nil then
        self.selectedID = self.records[1].id
    end

    local shell = SidebarLayout.Create(parent, {
        x = self.options.x or 0,
        y = self.options.y or 0,
        width = self.options.width,
        height = self.options.height,
        sidebarWidth = SIDEBAR_WIDTH,
        showTitle = false,
        createWorkspace = false,
    })
    self.root = shell.root

    local searchWidth = SIDEBAR_WIDTH - 20 - FILTER_BUTTON_SIZE - FILTER_GAP
    self.searchField = prettyui.TextField.new(self.root, {
        x = 10,
        y = 3,
        width = searchWidth,
        height = 28,
        text = self.search,
        placeholder = "Search quests...",
        maxLength = 80,
        onChange = function(_, reason, content)
            self.search = tostring(content or "")
            self:RebuildList(false)
            local persist = reason == ui.InputFieldActionResult.SUBMIT
            self.searchDirty = not persist
            self.options.onStateChange(self.selectedID, self.search, persist)
        end,
    })
    self.filterButton = prettyui.SpriteButton.new(self.root, "FILTER", function()
        self.filterOpen = not self.filterOpen
        self.filterSheet.hidden = not self.filterOpen
        if self.filterOpen then self.filterSheet:MoveToFront() end
    end, {
        x = 10 + searchWidth + FILTER_GAP,
        y = 5,
        size = FILTER_BUTTON_SIZE,
        tooltip = "Filter quests",
        hoverCursor = UI.NO_CURSOR,
    })

    self.filterSheet = ui.Layer.new(self.root)
    self.filterSheet:SetPos(SIDEBAR_WIDTH - FILTER_SHEET_WIDTH - 10, LIST_TOP)
    self.filterSheet:SetSize(FILTER_SHEET_WIDTH, FILTER_SHEET_HEIGHT)
    self.filterSheet.clickthrough = false
    UI.Rectangle(self.filterSheet, 0, 0, FILTER_SHEET_WIDTH, FILTER_SHEET_HEIGHT, 0x8B6F42FF)
    UI.Rectangle(
        self.filterSheet,
        1,
        1,
        FILTER_SHEET_WIDTH - 2,
        FILTER_SHEET_HEIGHT - 2,
        0x211B14FF
    )
    local StatusCombo = prettyui.OrderedComboBox or prettyui.ComboBox
    self.statusCombo = StatusCombo.new(self.filterSheet, {
        x = 8, y = 80, width = FILTER_SHEET_WIDTH - 16, height = 28,
        entries = {
            { id = 1, label = "Show all" },
            { id = 2, label = "Show completed" },
            { id = 3, label = "Show incomplete" },
        },
        selectedID = self.statusFilter == "completed" and 2 or self.statusFilter == "incomplete" and 3 or 1,
        onChange = function(_, entryID, _, eventType)
            if eventType ~= nil and ui.SelectionChangeEvent ~= nil
                and eventType ~= ui.SelectionChangeEvent.SELECTED then return end
            self.statusFilter = tonumber(entryID) == 2 and "completed"
                or tonumber(entryID) == 3 and "incomplete" or "all"
            self:RebuildList(true)
            self.options.onFilterChange(self.statusFilter, self.showMiniquests, self.showSeasonalQuests, self.availableInQH)
        end,
    })
    local selectedTypes = {}
    if self.showMiniquests then selectedTypes[#selectedTypes + 1] = "miniquests" end
    if self.showSeasonalQuests then selectedTypes[#selectedTypes + 1] = "seasonal" end
    if self.availableInQH then selectedTypes[#selectedTypes + 1] = "questhelper" end
    self.typeChoices = prettyui.CheckboxButton.new(self.filterSheet, {
        { text = "Show mini quests", value = "miniquests" },
        { text = "Show seasonal quests", value = "seasonal" },
        { text = "Available in QH", value = "questhelper" },
    }, {
        x = 8,
        y = 120,
        width = FILTER_SHEET_WIDTH - 16,
        selectedValues = selectedTypes,
        selectionCursor = false,
        onChange = function(control)
            self.showMiniquests = control:IsSelected("miniquests")
            self.showSeasonalQuests = control:IsSelected("seasonal")
            self.availableInQH = control:IsSelected("questhelper")
            self:RebuildList(true)
            self.options.onFilterChange(self.statusFilter, self.showMiniquests, self.showSeasonalQuests, self.availableInQH)
        end,
    })
    text(self.filterSheet, "STATUS", 8, 60, FILTER_SHEET_WIDTH - 16, 18, {
        font = id.Font.MUSEO_SANS_11PT_REGULAR,
        colour = 0xF2C66DFF,
    })
    text(self.filterSheet, "SORT BY", 8, 6, FILTER_SHEET_WIDTH - 16, 18, {
        font = id.Font.MUSEO_SANS_11PT_REGULAR,
        colour = 0xF2C66DFF,
    })
    self.sortCombo = prettyui.ComboBox.new(self.filterSheet, {
        x = 8,
        y = 26,
        width = FILTER_SHEET_WIDTH - 16,
        height = 28,
        entries = QUEST_SORT_ENTRIES,
        selectedID = questSortEntryID(self.sortBy),
        onChange = function(_, entryID)
            local selected = tonumber(entryID)
            self.sortBy = selected == QUEST_SORT_STATUS and "status"
                or selected == QUEST_SORT_RELEASE and "release"
                or "name"
            self:RebuildList(false)
            self.options.onSortChange(self.sortBy)
        end,
    })
    self.filterSheet.hidden = true

    self.workspace = ui.Layer.new(self.root)
    self.workspace:SetPos(WORKSPACE_X, 0)
    self.workspace:SetSize(self.root.width - WORKSPACE_X, self.root.height)
    self.workspace.clickthrough = true
    self.detailView = QuestDetailsPanel.new(self.workspace, {
        x = 0,
        y = 0,
        width = self.workspace.width,
        height = self.workspace.height,
        onBack = function() self:GoBack() end,
        onSelect = function(questID) self:SelectQuest(questID, "push") end,
        onOpenQuestHelper = function(questID) self:OpenQuestHelper(questID) end,
        onRequirementFilterChange = function(value)
            self.requirementFilter = value
            if self.options.onRequirementFilterChange ~= nil then
                self.options.onRequirementFilterChange(value)
            end
            self:RebuildDetail()
        end,
    })
    self:RebuildList(false)
    self:RebuildDetail()
    if Event ~= nil and Event.MiniMenuReady ~= nil then
        Event.MiniMenuReady.Subscribe(MENU_EVENT, function(event) self:AddMiniMenuEntries(event) end)
    end
    if Event ~= nil and Event.OptionalDependencyChanged ~= nil then
        Event.OptionalDependencyChanged.Subscribe(DEPENDENCY_EVENT, function(event)
            if event.pluginIdentifier ~= "questhelper" then return end
            self.questHelperDisabled = event.enabled == false
            self:RebuildList(true)
            self:RebuildDetail()
        end)
    end
    return self
end

function QuestPage:RebuildList(preserveScroll, revealSelected)
    self.helperQuests = not self.questHelperDisabled and QuestHelper.AvailableQuests() or {}
    local previousY = preserveScroll
            and self.sidebarList ~= nil
            and self.sidebarList:GetScrollPosition()
        or 0
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    self.sidebarList = nil
    if self.emptySidebarText ~= nil then self.emptySidebarText:Destroy() end
    self.emptySidebarText = nil

    local height = math.max(120, self.root.height - LIST_TOP)
    local visible, needle = {}, UI.Lower(self.search)
    for _, quest in ipairs(self.records) do
        local searchMatches = needle == ""
            or string.find(self.searchNames[quest], needle, 1, true) ~= nil
        local status = QuestRequirements.Status(quest.id)
        local statusMatches = self.statusFilter == "all"
            or self.statusFilter == "completed" and status == "complete"
            or self.statusFilter == "incomplete" and status ~= "complete"
        local typeMatches = (self.showMiniquests or not quest.isMiniquest)
            and (self.showSeasonalQuests or not quest.isSeasonalQuest)
        local helperMatches = not self.availableInQH or self.helperQuests[quest.id] ~= nil
        if searchMatches and statusMatches and typeMatches and helperMatches then
            visible[#visible + 1] = { quest = quest, status = status }
        end
    end
    table.sort(visible, function(left, right)
        if self.sortBy == "release" then
            local leftID = tonumber(left.quest.id) or math.huge
            local rightID = tonumber(right.quest.id) or math.huge
            if leftID ~= rightID then return leftID < rightID end
        elseif self.sortBy == "status" then
            local leftOrder = QuestRequirements.STATUS_ORDER[left.status] or math.huge
            local rightOrder = QuestRequirements.STATUS_ORDER[right.status] or math.huge
            if leftOrder ~= rightOrder then return leftOrder < rightOrder end
        end
        return self.searchNames[left.quest] < self.searchNames[right.quest]
    end)
    local entries = {}
    for _, entry in ipairs(visible) do
        entries[#entries + 1] = {
            id = entry.quest.id,
            label = entry.quest.name,
            complete = entry.status == "complete",
            textColour = QUEST_STATUS_COLOURS[entry.status],
        }
    end
    self.sidebarList = SidebarList.new(self.root, {
        x = 0,
        y = LIST_TOP,
        width = SIDEBAR_WIDTH,
        height = height,
        entries = entries,
        selected = self.selectedID,
        scrollY = previousY,
        onSelect = function(questID) self:SelectQuest(questID, "reset") end,
    })
    -- Reserve the end of supported rows for a small quest icon.
    for _, row in ipairs(self.sidebarList.list.rows or {}) do
        if self.helperQuests[row.entry.id] ~= nil then
            local sprite = ui.Sprite.new(row.root)
            sprite:SetPos(row.root.width - 23, 8)
            sprite:SetSize(16, 16)
            sprite.spriteID = QUEST_SPRITE
            sprite.clickthrough = true
            if row.label ~= nil then row.label:SetSize(-29 - row.label.x, 32, 1, 0) end
        end
    end
    if #visible == 0 then
        self.emptySidebarText = text(
            self.root,
            "No quests match.",
            12,
            LIST_TOP + 8,
            SIDEBAR_WIDTH - 24,
            30,
            { colour = 0xC9BEA4FF }
        )
        self.emptySidebarText:MoveToFront()
    end
    if revealSelected and self.selectedID ~= nil then
        self.sidebarList:Reveal(self.selectedID, true)
    end
    if self.filterOpen then self.filterSheet:MoveToFront() end
end

-- Only offer native menu actions for a hovered row in the visible logs window.
function QuestPage:AddMiniMenuEntries(event)
    local menu = event and event.miniMenu
    if self.root == nil or self.root.hidden or self.filterOpen or menu == nil
        or type(menu.Add) ~= "function" then return false end
    if self.options.isVisible ~= nil and not self.options.isVisible() then return false end
    local questID
    for _, row in ipairs(self.sidebarList.list.rows or {}) do
        local hovered = row.root.isMouseOver
        if type(hovered) == "function" then hovered = hovered(row.root) end
        if hovered == true then questID = row.entry.id; break end
    end
    if questID == nil then
        for _, entry in ipairs(self.detailView.orderEntries or {}) do
            local hovered = entry.root.isMouseOver
            if type(hovered) == "function" then hovered = hovered(entry.root) end
            if hovered == true then questID = entry.questID; break end
        end
    end
    if questID == nil then return false end
    menu:Add("View quest requirements", function()
        if self.root ~= nil then self:SelectQuest(questID, "reset") end
    end)
    if not self.questHelperDisabled and self.helperQuests[questID] ~= nil then
        menu:Add("Open QuestHelper", function()
            if self.root ~= nil then self:OpenQuestHelper(questID) end
        end)
    end
    -- Native menus display entries in reverse order. Keep requirements first.
    if type(menu.Swap) == "function" then
        local count = #(menu.entries or {})
        if count >= 2 and menu.entries[count].verbText == "Open QuestHelper" then
            menu:Swap(count, count - 1)
        end
        for index, entry in ipairs(menu.entries or {}) do
            if entry.verbText == "Cancel" then
                for current = index, 2, -1 do menu:Swap(current, current - 1) end
                break
            end
        end
    end
    return true
end

function QuestPage:OpenQuestHelper(questID)
    local opened, reason = false, "unavailable"
    if not self.questHelperDisabled then opened, reason = QuestHelper.OpenQuest(questID) end
    if opened then
        if self.selectedID ~= questID then
            self:SelectQuest(questID, "reset")
        else
            self.searchDirty = false
            self.options.onStateChange(self.selectedID, self.search, true)
        end
        if self.options.onQuestHelperOpened ~= nil then self.options.onQuestHelperOpened() end
        return true
    end
    self:RebuildList(true)
    self:RebuildDetail()
    if self.helperPopup ~= nil then self.helperPopup:Destroy(); self.helperPopup = nil end
    if prettyui.AchievementPopup ~= nil and prettyui.AchievementPopup.show ~= nil then
        self.helperPopup = prettyui.AchievementPopup.show({
            title = "QUESTHELPER",
            text = reason == "not_ready" and "QuestHelper is not ready. Try again once you are in game."
                or "Could not open this quest. Check that QuestHelper is enabled and supports it.",
            width = 380, x = -190, y = -46, xAnchor = 0.5, yAnchor = 0.5,
            onComplete = function(completed)
                if self.helperPopup == completed then self.helperPopup = nil end
            end,
        })
    end
    return false
end

function QuestPage:SelectQuest(questID, navigation)
    local selectedID = tonumber(questID)
    if selectedID == nil or self.byID[selectedID] == nil or self.selectedID == selectedID then
        return
    end
    if navigation == "reset" then
        self.history = {}
    elseif navigation == "push" and self.selectedID ~= nil then
        self.history[#self.history + 1] = self.selectedID
        if #self.history > 10 then table.remove(self.history, 1) end
    end
    self.selectedID = selectedID
    local clearSearch = navigation == "push" or navigation == "back"
    if clearSearch and self.search ~= "" then
        self.search = ""
        self.searchField:SetText("", false)
    end
    self.searchDirty = false
    self.options.onStateChange(self.selectedID, self.search, true)
    if clearSearch then
        self:RebuildList(false, true)
    elseif self.sidebarList ~= nil then
        self.sidebarList:Select(self.selectedID)
        self.sidebarList:Reveal(self.selectedID, true)
    end
    self:RebuildDetail()
end

-- Return to the quest list
function QuestPage:GoBack()
    local previousID = table.remove(self.history)
    if previousID ~= nil then self:SelectQuest(previousID, "back") end
end

function QuestPage:SetCumulativeRequirements(enabled)
    local value = enabled ~= false
    if self.useCumulativeRequirements == value then return end
    self.useCumulativeRequirements = value
    self:RebuildDetail()
end

function QuestPage:SetOrderView(value)
    local normalized = value == "tree" and "tree" or "linear"
    if self.orderView == normalized then return end
    self.orderView = normalized
    self:RebuildDetail()
end

function QuestPage:RebuildDetail()
    local quest = self.byID[self.selectedID]
    if quest == nil then
        self.detailView:RenderEmpty("No quest data was supplied by the manifest.")
        return
    end
    local state = QuestRequirements.DetailState(quest, self.byID, {
        cumulativeRequirements = self.useCumulativeRequirements,
        orderView = self.orderView,
        playerLevel = SkillIcons.PlayerLevel,
        requirementFilter = self.requirementFilter,
    })
    self.detailView:Render(state, {
        helperQuests = self.helperQuests,
        selectedID = self.selectedID,
        previousQuest = self.byID[self.history[#self.history]],
    })
end

function QuestPage:Destroy()
    if Event ~= nil and Event.MiniMenuReady ~= nil then Event.MiniMenuReady.Unsubscribe(MENU_EVENT) end
    if Event ~= nil and Event.OptionalDependencyChanged ~= nil then
        Event.OptionalDependencyChanged.Unsubscribe(DEPENDENCY_EVENT)
    end
    if self.helperPopup ~= nil then self.helperPopup:Destroy(); self.helperPopup = nil end
    if self.searchDirty then
        self.searchDirty = false
        self.options.onStateChange(self.selectedID, self.search, true)
    end
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    if self.emptySidebarText ~= nil then self.emptySidebarText:Destroy() end
    if self.statusCombo ~= nil then self.statusCombo:Destroy() end
    if self.typeChoices ~= nil then self.typeChoices:Destroy() end
    if self.sortCombo ~= nil then self.sortCombo:Destroy() end
    if self.filterButton ~= nil then self.filterButton:Destroy() end
    if self.detailView ~= nil then self.detailView:Destroy() end
    self.statusCombo = nil
    self.typeChoices = nil
    self.sortCombo = nil
    self.filterButton = nil
    self.detailView = nil
    self.filterSheet = nil
    if self.root ~= nil then self.root:Destroy() end
    self.root = nil
end

return QuestPage
