-- Coordinate services, events, navigation, and active pages
local UI = require("Resources/Shared/ui/components")
local FeatureLoader = require("Resources/Lib/feature_loader")
local Settings = require("Resources/Lib/settings")
local LauncherPanel = require("Resources/Shared/ui/launcher_panel")
local AccountProgress = require("Resources/Lib/progress/account")
local DateTimeFormat = require("Resources/Lib/date_time_format")
local BossPatch = require("Resources/Features/bosses/boss_patch")
local CombatDescriptions = require("Resources/Features/bosses/combat_achievement_descriptions")
local BossPatchValuesWindow = require("Resources/Features/bosses/boss_patch_values_window")
local CombatAchievementStateLoader =
    require("Resources/Features/bosses/combat_achievement_state_loader")

local App = {}
App.__index = App

local WINDOW_WIDTH = 1028
local WINDOW_HEIGHT = 620
local NAV_HEIGHT = 58
local PRIMARY_BUTTON_HEIGHT = 46
local FEATURE_LOAD_EVENT = "unifiedlogs_feature_load"
local CONTENT_EVENT = "unifiedlogs_content"
local KEY_EVENT = "unifiedlogs_open_logs_hotkey"
local XP_REFRESH_EVENT = "unifiedlogs_xp_refresh"
local XP_REFRESH_TICKS = 10
local PLAYER_EVENT = "unifiedlogs_player_identity"
local MODIFIER_KEYS = { [GameKey.CONTROL] = true, [GameKey.SHIFT] = true, [GameKey.ALT] = true }

-- Modifier presses only trigger keybinds made entirely of modifiers
local function triggersKeybind(binding, key)
    if binding[1] ~= key and binding[2] ~= key then return false end
    if not MODIFIER_KEYS[key] then return true end
    for _, bound in ipairs(binding) do
        if not MODIFIER_KEYS[bound] then return false end
    end
    return true
end

function App.new(registry)
    local self = setmetatable({}, App)
    self.registry = registry
    self.dataReady = false
    self.state = Settings.Load(registry)
    require("Resources/Shared/ui/progress_style").greenLogEnabled = self.state.enableGreenLog
    self.primaryButtons = {}
    self.navigationSections = {}
    self.activeView = nil
    self.window = nil
    self.launcherView = nil
    self.xpClockPopup = nil
    self.otaValuesWindow = nil
    self.lastXPTrackerStatus = nil
    self.xpHistoryDirty = false

    self.accountProgress = AccountProgress.new(function() self:RefreshAccountState() end)
    self.combatAchievementStateLoader = CombatAchievementStateLoader.new(
        registry.byID.combat_achievements.records,
        function() self:RefreshAchievements() end
    )
    self.xpTracker = nil
    return self
end

-- Finish loading the initial page
function App:FinishInitialLoad()
    self.dataReady = true

    if self.window ~= nil then
        self:DestroyActiveView()
        self:BuildNavigation()
        self:MountSection(self.state.activeSection)
    end
    return true
end

function App:SaveState() Settings.Save(self.state) end

-- Get sections visible in the current mode
function App:VisibleSections()
    local sections = {}
    for _, section in ipairs(self.registry.ordered) do
        if section.id ~= "xp" or self.state.enableXPLogs == true then
            sections[#sections + 1] = section
        end
    end
    return sections
end

function App:BuildNavigation()
    if self.navigation == nil then return end
    for _, button in ipairs(self.primaryButtons) do
        button:Destroy()
    end
    self.primaryButtons = {}
    self.navigationSections = self:VisibleSections()

    local gap, inset = 6, 8
    local count = math.max(1, #self.navigationSections)
    local buttonWidth =
        math.floor((self.window.content.width - inset * 2 - gap * (count - 1)) / count)
    local x = inset
    for _, section in ipairs(self.navigationSections) do
        local sectionID = section.id
        local button = prettyui.SimpleButton.new(self.navigation, "", function()
            if self.dataReady then self:MountSection(sectionID) end
        end, {
            x = x,
            y = 6,
            width = buttonWidth,
            height = PRIMARY_BUTTON_HEIGHT,
            active = self.dataReady and self.state.activeSection == sectionID,
            toggleable = false,
            hoverCursor = UI.NO_CURSOR,
        })
        UI.Text(button.root, section.label, 8, 0, buttonWidth - 16, PRIMARY_BUTTON_HEIGHT, {
            font = id.Font.MUSEO_SANS_13PT_BOLD,
            colour = 0xF2C66DFF,
            maxLines = 2,
            alignHorizontal = ui.AlignMode.CENTRE,
            alignVertical = ui.AlignMode.CENTRE,
        })
        self.primaryButtons[#self.primaryButtons + 1] = button
        x = x + buttonWidth + gap
    end
    self.navigation:MoveToFront()
end

-- Create the XP tracker when needed
function App:EnsureXPTracker()
    if self.xpTracker == nil then
        self.xpTracker = require("Resources/Features/experience/experience_tracker").new(
            function() self:OnXPTrackerChanged() end
        )
    end
    return self.xpTracker
end

function App:SetXPLogsEnabled(enabled)
    local value = enabled == true
    if self.state.enableXPLogs == value then return end
    local leavingXP = not value and self.state.activeSection == "xp"
    self.state.enableXPLogs = value

    if value then
        self.lastXPTrackerStatus = nil
        self:EnsureXPTracker():Start()
    else
        if self.xpTracker ~= nil then self.xpTracker:Shutdown() end
        self.lastXPTrackerStatus = nil
        if self.xpClockPopup ~= nil and self.xpClockPopup.Destroy ~= nil then
            pcall(function() self.xpClockPopup:Destroy() end)
        end
        self.xpClockPopup = nil
    end

    if leavingXP then
        self:DestroyActiveView()
        self.state.activeSection = "bosses"
    end
    self:SaveState()
    self:BuildNavigation()
    if leavingXP and self.dataReady then self:MountSection("bosses") end
end

function App:RefreshAccountState()
    if self.activeView ~= nil and self.activeView.RefreshAccountState ~= nil then
        self.activeView:RefreshAccountState()
    elseif self.activeView ~= nil and self.activeView.RebuildGrid ~= nil then
        self.activeView:RebuildGrid(true)
    end
end

function App:RefreshAchievements()
    if self.activeView ~= nil and self.activeView.RefreshAchievements ~= nil then
        self.activeView:RefreshAchievements()
    end
end

function App:RefreshXPHistory()
    if not self:IsLogsVisible() then return false end
    if
        self.activeView ~= nil
        and self.activeView.RefreshData ~= nil
        and self.state.activeSection == "xp"
    then
        local refreshed = self.activeView:RefreshData()
        if refreshed ~= false then self.xpHistoryDirty = false end
        return refreshed ~= false
    end
    return false
end

function App:ShowXPClockWarning()
    if
        prettyui == nil
        or prettyui.AchievementPopup == nil
        or prettyui.AchievementPopup.show == nil
    then
        return
    end
    if self.xpClockPopup ~= nil and self.xpClockPopup.Destroy ~= nil then
        pcall(function() self.xpClockPopup:Destroy() end)
    end
    local popup
    popup = prettyui.AchievementPopup.show({
        title = "XP TRACKING PAUSED",
        text = "Enable the in-game clock so Unified Logs can timestamp and resume recording XP.",
        width = 380,
        x = -190,
        y = -46,
        xAnchor = 0.5,
        yAnchor = 0.5,
        onComplete = function(completed)
            if self.xpClockPopup == completed then self.xpClockPopup = nil end
        end,
    })
    self.xpClockPopup = popup
end

-- Refresh views after XP changes
function App:OnXPTrackerChanged()
    local status = self.xpTracker:GetStatus()
    if status.code == "clock_unavailable" and self.lastXPTrackerStatus ~= "clock_unavailable" then
        self:ShowXPClockWarning()
    end
    local statusChanged = self.lastXPTrackerStatus ~= status.code
    self.lastXPTrackerStatus = status.code
    self.xpHistoryDirty = true
    if self.activeView ~= nil and self.activeView.MarkDataDirty ~= nil then
        self.activeView:MarkDataDirty()
    end
    if statusChanged then
        self:RefreshXPHistory()
    elseif
        not self.xpRefreshScheduled
        and self:IsLogsVisible()
        and (
            self.activeView == nil
            or self.activeView.ShowsLiveData == nil
            or self.activeView:ShowsLiveData()
        )
    then
        -- Batch frequent XP drops into one redraw per interval
        self.xpRefreshScheduled = true
        local ticks = 0
        Event.Logic.Subscribe(XP_REFRESH_EVENT, function()
            ticks = ticks + 1
            if ticks < XP_REFRESH_TICKS then return end
            Event.Logic.Unsubscribe(XP_REFRESH_EVENT)
            self.xpRefreshScheduled = false
            if self.xpHistoryDirty then self:RefreshXPHistory() end
        end)
    end
end

function App:DestroyActiveView()
    if self.activeView ~= nil then self.activeView:Destroy() end
    self.activeView = nil
    if self.pageRoot ~= nil then self.pageRoot:Destroy() end
    self.pageRoot = nil
    if self.loadingMessage ~= nil then self.loadingMessage:Destroy() end
    self.loadingMessage = nil
end

-- Reload pages that consume OTA encounter and heist data.
function App:OnBossPatchChanged()
    local active = self.state.activeSection
    local remount = (active == "bosses" or active == "misc")
        and self.activeView ~= nil and FeatureLoader.IsReady(self.registry, active)
    for _, id in ipairs({ "bosses", "thieving", "misc" }) do
        local feature = self.registry.byID[id]
        if feature ~= nil then FeatureLoader.ready[feature] = nil end
    end
    if remount then
        self:DestroyActiveView()
        self:MountSection(active)
    end
end

-- Manually check both CDN payloads; the OTA values window remains patch-only.
function App:CheckForBossPatchUpdate()
    local patch = BossPatch.Fetch(function() self:OnBossPatchChanged() end, function(status)
        log("unifiedlogs boss patch check: ", status)
        if self.otaValuesWindow ~= nil then self:ShowStoredBossPatchValues() end
    end)
    local descriptions = CombatDescriptions.Fetch(function() self:OnBossPatchChanged() end, function(status)
        log("unifiedlogs combat descriptions check: ", status)
    end, true)
    return patch or descriptions
end

-- Show exactly what is persisted, without fetching the OTA endpoint
function App:ShowStoredBossPatchValues()
    local parent = self:EnsureWindowParent()
    if parent == nil then return false end
    if self.otaValuesWindow ~= nil then self.otaValuesWindow:Destroy() end
    local valuesWindow
    valuesWindow = BossPatchValuesWindow.new(parent, BossPatch.StoredValues(), function(closed)
        if self.otaValuesWindow == closed then self.otaValuesWindow = nil end
    end)
    self.otaValuesWindow = valuesWindow
    return true
end

-- Refresh views as features load
function App:WatchFeatureLoader()
    Event.Logic.Unsubscribe(FEATURE_LOAD_EVENT)
    Event.Logic.Subscribe(FEATURE_LOAD_EVENT, function()
        FeatureLoader.Tick()
        if FeatureLoader.loadTask == nil then Event.Logic.Unsubscribe(FEATURE_LOAD_EVENT) end
    end)
end

function App:UpdateNavigationSelection(sectionID)
    for index, section in ipairs(self.navigationSections) do
        self.primaryButtons[index]:SetActive(section.id == sectionID)
    end
end

-- Mount the selected section
function App:MountSection(sectionID)
    local feature = self.registry.byID[sectionID]
    if not self.dataReady or feature == nil or feature.CreatePage == nil then return false end
    if sectionID == "xp" and self.state.enableXPLogs ~= true then sectionID = "bosses" end
    if self.state.activeSection == sectionID and self.activeView ~= nil then return true end
    self:DestroyActiveView()
    self.combatAchievementStateLoader:Shutdown()
    self.state.activeSection = sectionID
    self.mountVersion = (self.mountVersion or 0) + 1
    local ticket = self.mountVersion
    self:UpdateNavigationSelection(sectionID)
    self:SaveState()
    if not FeatureLoader.IsReady(self.registry, sectionID) then
        self.loadingMessage =
            UI.Text(self.window.content, "Loading...", 12, NAV_HEIGHT + 12, 500, 30)
        FeatureLoader.LoadFeatureAsync(self.registry, sectionID, function(result, reason)
            if self.window == nil or ticket ~= self.mountVersion then return end
            if result ~= nil then
                for _, warning in ipairs(result.warnings) do
                    log(warning)
                end
                self:MountSection(sectionID)
            else
                self.loadingMessage.content = "Unable to load this page."
                log("unifiedlogs could not load ", sectionID, ": ", tostring(reason))
            end
        end)
        self:WatchFeatureLoader()
        return true
    end
    self.accountProgress:BeginScope()
    local width = self.window.content.width
    local height = math.max(220, self.window.content.height - NAV_HEIGHT)
    self.pageRoot = UI.RootLayer(self.window.content)
    self.pageRoot:SetPos(0, NAV_HEIGHT)
    self.pageRoot:SetSize(width, height)
    local ok, view = pcall(self.registry.byID[sectionID].CreatePage, self.pageRoot, {
        x = 0,
        y = 0,
        width = width,
        height = height,
        registry = self.registry,
        state = self.state,
        progress = self.accountProgress,
        xpTracker = self.xpTracker,
        windowParent = self.windowParent,
        isVisible = function() return self:IsLogsVisible() end,
        closeLogs = function() self:CloseLogs() end,
        saveState = function() self:SaveState() end,
        refreshProgress = function() self.accountProgress:Refresh() end,
    })
    if not ok then
        self.pageRoot:Destroy()
        self.pageRoot = nil
        self.accountProgress:BeginScope()
        log("unifiedlogs could not build ", sectionID, ": ", tostring(view))
        self.loadingMessage = UI.Text(self.window.content, "Unable to build this page.",
            12, NAV_HEIGHT + 12, 500, 30)
        return false
    end
    self.activeView = view
    if sectionID == "xp" then self.xpHistoryDirty = self.activeView.dataDirty == true end
    self.accountProgress:Refresh()
    if sectionID == "bosses" then self.combatAchievementStateLoader:Start() end
    return true
end

-- Keep floating windows under one plugin-owned collection.
function App:EnsureWindowParent(parent)
    if self.windowParent ~= nil then return self.windowParent end
    if parent == nil and ui ~= nil and ui.Interfaces ~= nil then
        parent = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
    end
    if parent == nil then return nil end
    self.windowLayer = UI.RootLayer(parent)
    self.windowParent = self.windowLayer
    return self.windowParent
end

function App:CreateWindow(windowParent)
    windowParent = self:EnsureWindowParent(windowParent)
    self.window = prettyui.Window.new(windowParent, {
        title = "Unified Logs",
        x = -math.floor(WINDOW_WIDTH / 2),
        y = -math.floor(WINDOW_HEIGHT / 2),
        xAnchor = 0.5,
        yAnchor = 0.5,
        width = WINDOW_WIDTH,
        height = WINDOW_HEIGHT,
        minWidth = 888,
        minHeight = 500,
        onClose = function()
            self.combatAchievementStateLoader:Shutdown()
            if self.launcherView ~= nil then self.launcherView:SetLogsVisible(false) end
        end,
    })

    self.navigation = ui.Layer.new(self.window.content)
    self.navigation:SetPos(0, 0)
    self.navigation:SetSize(self.window.content.width, NAV_HEIGHT)
    self.navigation.clickthrough = true
    UI.Rectangle(self.navigation, 0, 0, self.window.content.width, NAV_HEIGHT, 0x17130FFF)
    self:BuildNavigation()

    -- Mount the page after its data load completes
    if self.dataReady then self:MountSection(self.state.activeSection) end
    return true
end

-- Build the plugin window
function App:Build()
    if self.window ~= nil then return true end
    if ui == nil or ui.Interfaces == nil then return false end
    local windowParent =
        ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
    if windowParent == nil then return false end
    return self:CreateWindow(windowParent)
end

function App:IsLogsVisible()
    return self.window ~= nil and self.window.root ~= nil and self.window.root.hidden ~= true
end

function App:OpenLogs()
    if not self:Build() then return false end
    self.accountProgress:Refresh()
    self.window:Show()
    if self.state.activeSection == "bosses" then
        self.combatAchievementStateLoader:Start()
    end
    if self.xpHistoryDirty then self:RefreshXPHistory() end
    if self.launcherView ~= nil then self.launcherView:SetLogsVisible(true) end
    return true
end

function App:CloseLogs()
    if self.window ~= nil then self.window:Close() end
    return true
end

function App:ToggleLogs()
    if self:IsLogsVisible() then
        return self:CloseLogs()
    end
    return self:OpenLogs()
end

-- Toggle the logs when a key press completes the open keybind
function App:OnKeyDown(event)
    if event == nil or event.isRepeat or Keyboard.IsBlocked() then return end
    local binding = self.state.openLogsHotkey
    if triggersKeybind(binding, event.gameKey) and prettyui.KeybindField.IsDown(binding) then
        self:ToggleLogs()
    end
end

function App:CreateContentLayer(parent)
    if self.launcherView ~= nil then self.launcherView:Destroy() end
    self.launcherView = LauncherPanel.new(parent, {
        onToggleLogs = function() self:ToggleLogs() end,
        logsVisible = self:IsLogsVisible(),
        openLogsHotkey = self.state.openLogsHotkey,
        onOpenLogsHotkeyChange = function(value)
            self.state.openLogsHotkey = value
            self:SaveState()
        end,
        showPersonalBests = self.state.showPersonalBests ~= false,
        enableGreenLog = self.state.enableGreenLog,
        onEnableGreenLogChange = function(enabled)
            self.state.enableGreenLog = enabled == true
            require("Resources/Shared/ui/progress_style").greenLogEnabled = self.state.enableGreenLog
            self:SaveState()
            if self.activeView ~= nil then
                self:DestroyActiveView()
                self:MountSection(self.state.activeSection)
            end
        end,
        questUseCumulativeRequirements = self.state.questUseCumulativeRequirements ~= false,
        questOrderView = self.state.questOrderView,
        achievementOrderView = self.state.achievementOrderView,
        enableXPLogs = self.state.enableXPLogs == true,
        dateFormat = self.state.dateFormat,
        timeFormat = self.state.timeFormat,
        onShowPersonalBestsChange = function(visible)
            self.state.showPersonalBests = visible == true
            self:SaveState()
            if self.activeView ~= nil and self.activeView.SetShowPersonalBests ~= nil then
                self.activeView:SetShowPersonalBests(self.state.showPersonalBests)
            end
        end,
        onQuestUseCumulativeRequirementsChange = function(enabled)
            self.state.questUseCumulativeRequirements = enabled == true
            self:SaveState()
            if self.activeView ~= nil and self.activeView.SetCumulativeRequirements ~= nil then
                self.activeView:SetCumulativeRequirements(self.state.questUseCumulativeRequirements)
            end
        end,
        onQuestOrderViewChange = function(value)
            self.state.questOrderView = value == "tree" and "tree" or "linear"
            self:SaveState()
            if self.state.activeSection == "quests" and self.activeView ~= nil then
                self.activeView:SetOrderView(self.state.questOrderView)
            end
        end,
        onAchievementOrderViewChange = function(value)
            self.state.achievementOrderView = value == "tree" and "tree" or "linear"
            self:SaveState()
            if self.state.activeSection == "achievements" and self.activeView ~= nil then
                self.activeView:SetOrderView(self.state.achievementOrderView)
            end
        end,
        onEnableXPLogsChange = function(enabled) self:SetXPLogsEnabled(enabled) end,
        showOTAControls = BossPatch.HasAccess(),
        onCheckForUpdate = function() self:CheckForBossPatchUpdate() end,
        onShowOTAValues = function() self:ShowStoredBossPatchValues() end,
        onDateFormatChange = function(value)
            self.state.dateFormat = DateTimeFormat.NormalizeDate(value)
            self:SaveState()
            if self.activeView ~= nil and self.activeView.SetDateFormat ~= nil then
                self.activeView:SetDateFormat(self.state.dateFormat)
            end
        end,
        onTimeFormatChange = function(value)
            self.state.timeFormat = DateTimeFormat.NormalizeTime(value)
            self:SaveState()
            if self.activeView ~= nil and self.activeView.SetTimeFormat ~= nil then
                self.activeView:SetTimeFormat(self.state.timeFormat)
            end
        end,
    })
end

-- Start the plugin application
function App:Start()
    Event.Logic.Subscribe(PLAYER_EVENT, function()
        if not Settings.RefreshPlayer(self.state) then return end
        if self.xpTracker ~= nil then self.xpTracker:RefreshClock() end
        self.accountProgress.values = {}
        self.accountProgress.resolved = {}
        for _, record in ipairs(self.registry.byID.combat_achievements.records) do
            record.progress, record.complete = nil, nil
        end
        if self.activeView ~= nil then
            self:DestroyActiveView()
            self:MountSection(self.state.activeSection)
        end
    end)
    Event.ContentLayerReady.Subscribe(
        CONTENT_EVENT,
        function(event) self:CreateContentLayer(event.component) end
    )
    Event.KeyDown.Subscribe(KEY_EVENT, function(event) self:OnKeyDown(event) end)
    if self.state.enableXPLogs == true then self:EnsureXPTracker():Start() end
    FeatureLoader.LoadFeatureAsync(
        self.registry,
        self.state.activeSection,
        function(catalog, reason)
            if catalog ~= nil then
                for _, warning in ipairs(catalog.warnings) do
                    log(warning)
                end
            else
                log("unifiedlogs could not load its feature data: ", tostring(reason))
            end
            self:FinishInitialLoad()
        end
    )
    self:WatchFeatureLoader()
    BossPatch.Fetch(function() self:OnBossPatchChanged() end)
    CombatDescriptions.Fetch(function() self:OnBossPatchChanged() end)
end

-- Stop app
function App:Shutdown()
    Event.Logic.Unsubscribe(PLAYER_EVENT)
    BossPatch.Shutdown()
    CombatDescriptions.Shutdown()
    FeatureLoader.Shutdown()
    Event.Logic.Unsubscribe(FEATURE_LOAD_EVENT)
    Event.Logic.Unsubscribe(XP_REFRESH_EVENT)
    self.xpRefreshScheduled = false
    Event.ContentLayerReady.Unsubscribe(CONTENT_EVENT)
    Event.KeyDown.Unsubscribe(KEY_EVENT)
    if self.xpTracker ~= nil then self.xpTracker:Shutdown() end
    self.combatAchievementStateLoader:Shutdown()
    self.accountProgress:Shutdown()
    if self.xpClockPopup ~= nil and self.xpClockPopup.Destroy ~= nil then
        pcall(function() self.xpClockPopup:Destroy() end)
    end
    self.xpClockPopup = nil
    if self.otaValuesWindow ~= nil then self.otaValuesWindow:Destroy() end
    self.otaValuesWindow = nil
    self:DestroyActiveView()
    for _, button in ipairs(self.primaryButtons) do
        button:Destroy()
    end
    self.primaryButtons = {}
    if self.navigation ~= nil then self.navigation:Destroy() end
    if self.window ~= nil then self.window:Destroy() end
    if self.launcherView ~= nil then self.launcherView:Destroy() end
    self.navigation = nil
    self.window = nil
    if self.windowLayer ~= nil then self.windowLayer:Destroy() end
    self.windowLayer = nil
    self.windowParent = nil
    self.launcherView = nil
end

return App
