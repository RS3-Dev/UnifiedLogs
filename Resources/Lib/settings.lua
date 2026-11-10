-- Load and save plugin settings
local Storage = require("Resources/Lib/storage")
local Identity = require("Resources/Lib/player_identity")

-- Keybinds use PrettyUI's KeybindField format: up to two distinct GameKey values
local DEFAULT_OPEN_LOGS_HOTKEY = { GameKey.SHIFT, GameKey.F12 }

local function normalizedKeybind(value, fallback)
    if type(value) ~= "table" then return fallback end
    local count = 0
    for _ in pairs(value) do
        count = count + 1
    end
    if count ~= #value or count > 2 or count == 2 and value[1] == value[2] then return fallback end
    local keys = {}
    for index, code in ipairs(value) do
        keys[index] = math.tointeger(code)
        if keys[index] == nil then return fallback end
    end
    return keys
end

local Settings = {
    key = "unifiedlogs:view_settings:v1",
    DEFAULT_OPEN_LOGS_HOTKEY = DEFAULT_OPEN_LOGS_HOTKEY,
    STATUS_ALL = 0,
    STATUS_COMPLETE = 1,
    STATUS_INCOMPLETE = 2,
    ALL_CATEGORIES_ID = 0,
}

-- Build default settings
local function defaults()
    return {
        activeSection = "bosses",
        tierFilter = 0,
        statusFilter = Settings.STATUS_ALL,
        search = "",
        categorySearch = "",
        selectedCategoryID = Settings.ALL_CATEGORIES_ID,
        activeTab = 1,
        xpMode = "notice",
        xpSkillID = 27,
        enableXPLogs = false,
        openLogsHotkey = { table.unpack(DEFAULT_OPEN_LOGS_HOTKEY) },
        dateFormat = "us",
        timeFormat = "12",
        selectedSlayerGroup = "Asgarnia & Misthalin",
        slayerSearch = "",
        selectedAbilityGroup = "All",
        abilitySearch = "",
        selectedClueGroup = "General clue rewards",
        clueSearch = "",
        selectedPofGroup = "All",
        selectedPohGroup = "Trophies",
        selectedMinigameGroup = "Big Game Hunter",
        minigameSearch = "",
        selectedSkillingOutfitGroup = "All",
        skillingOutfitSearch = "",
        selectedPetGroup = "Skill Pets",
        petSearch = "",
        selectedEnchantmentGroup = "All",
        enchantmentSearch = "",
        miscMode = "thieving",
        selectedThievingGroup = "Asuran Arsenal",
        pofSearch = "",
        selectedQuestID = nil,
        questSearch = "",
        questStatusFilter = "all",
        questShowMiniquests = true,
        questShowSeasonalQuests = true,
        questAvailableInQH = false,
        questSortBy = "name",
        questUseCumulativeRequirements = true,
        questOrderView = "linear",
        questRequirementFilter = "all",
        achievementMode = "overview",
        achievementOrderView = "linear",
        achievementRequirementFilter = "all",
        achievementRequirementSearch = "",
        archaeologyMode = "mysteries",
        selectedArchaeologyOtherGroup = "All",
        archaeologyOtherSearch = "",
        selectedMysterySite = "All dig sites",
        selectedCollector = nil,
        selectedRelicCategory = "All relics",
        selectedRelicLoadout = nil,
        showPersonalBests = true,
        enableGreenLog = false,
        trophyFound = {},
        collapsedTiers = {},
    }
end

local function copyBoundedNumber(state, saved, key, minimum, maximum)
    local value = tonumber(saved[key])
    if value == nil or value < minimum or value > maximum then return end
    state[key] = value
end

-- Validate the saved section
local function validActiveSection(registry, value)
    if type(value) ~= "string" then return nil end
    for _, section in ipairs(registry.ordered or {}) do
        if section.id == value then return value end
    end
    return nil
end

-- Load manual progress for the current character.
function Settings.RefreshPlayer(state)
    local playerID = Identity.Current()
    if state.playerID == playerID then return false end
    state.playerID = playerID
    state.trophyFound = {}
    local key = Identity.Key(playerID, "trophies:v1")
    local saved = key and Storage.ReadStructured(key)
    if type(saved) == "table" then
        for name, found in pairs(saved) do
            if type(name) == "string" and name ~= "" and found == true then
                state.trophyFound[name] = true
            end
        end
    end
    return true
end

-- Load saved settings.
function Settings.Load(registry)
    local state = defaults()
    Settings.RefreshPlayer(state)
    local saved = Storage.ReadStructured(Settings.key)
    if type(saved) ~= "table" then return state end

    local tier = tonumber(saved.tierFilter)
    if tier ~= nil and tier >= 0 and tier <= 6 then state.tierFilter = tier end

    local status = tonumber(saved.statusFilter)
    if
        status == Settings.STATUS_ALL
        or status == Settings.STATUS_COMPLETE
        or status == Settings.STATUS_INCOMPLETE
    then
        state.statusFilter = status
    end

    for _, key in ipairs({
        "search",
        "categorySearch",
        "selectedSlayerGroup",
        "slayerSearch",
        "selectedAbilityGroup",
        "abilitySearch",
        "selectedClueGroup",
        "clueSearch",
        "selectedPofGroup",
        "selectedPohGroup",
        "selectedMinigameGroup",
        "minigameSearch",
        "selectedSkillingOutfitGroup",
        "skillingOutfitSearch",
        "selectedPetGroup",
        "petSearch",
        "selectedEnchantmentGroup",
        "enchantmentSearch",
        "selectedThievingGroup",
        "pofSearch",
        "questSearch",
        "achievementRequirementSearch",
        "selectedMysterySite",
        "selectedArchaeologyOtherGroup",
        "archaeologyOtherSearch",
        "selectedCollector",
        "selectedRelicCategory",
    }) do
        if type(saved[key]) == "string" then state[key] = saved[key] end
    end

    local selectedQuestID = tonumber(saved.selectedQuestID)
    if saved.miscMode == "thieving" or saved.miscMode == "pof" or saved.miscMode == "minigames"
        or saved.miscMode == "pets" or saved.miscMode == "enchantments"
        or saved.miscMode == "skilling_outfits" then
        state.miscMode = saved.miscMode
    end
    if selectedQuestID ~= nil then state.selectedQuestID = selectedQuestID end
    if saved.questStatusFilter == "all" or saved.questStatusFilter == "completed"
        or saved.questStatusFilter == "incomplete" then
        state.questStatusFilter = saved.questStatusFilter
    elseif saved.questShowCompleted == true and saved.questShowIncomplete == false then
        state.questStatusFilter = "completed"
    elseif saved.questShowCompleted == false and saved.questShowIncomplete == true then
        state.questStatusFilter = "incomplete"
    end
    if type(saved.questShowMiniquests) == "boolean" then
        state.questShowMiniquests = saved.questShowMiniquests
    end
    if type(saved.questShowSeasonalQuests) == "boolean" then
        state.questShowSeasonalQuests = saved.questShowSeasonalQuests
    end
    if type(saved.questAvailableInQH) == "boolean" then
        state.questAvailableInQH = saved.questAvailableInQH
    end
    if type(saved.questUseCumulativeRequirements) == "boolean" then
        state.questUseCumulativeRequirements = saved.questUseCumulativeRequirements
    end
    if saved.questRequirementFilter == "all" or saved.questRequirementFilter == "incomplete" then
        state.questRequirementFilter = saved.questRequirementFilter
    end
    if saved.questOrderView == "linear" or saved.questOrderView == "tree" then
        state.questOrderView = saved.questOrderView
    end
    if
        saved.achievementMode == "overview"
        or saved.achievementMode == "master_quest"
        or saved.achievementMode == "max"
        or saved.achievementMode == "completionist"
        or saved.achievementMode == "trimmed_completionist"
        or saved.achievementMode == "master_max"
        or saved.achievementMode == "master_completionist"
        or saved.achievementMode == "master_trimmed_completionist"
    then
        state.achievementMode = saved.achievementMode
    end
    if saved.achievementOrderView == "linear" or saved.achievementOrderView == "tree" then
        state.achievementOrderView = saved.achievementOrderView
    end
    if
        saved.achievementRequirementFilter == "all"
        or saved.achievementRequirementFilter == "incomplete"
        or saved.achievementRequirementFilter == "unblocked"
    then
        state.achievementRequirementFilter = saved.achievementRequirementFilter
    end
    if type(saved.enableGreenLog) == "boolean" then state.enableGreenLog = saved.enableGreenLog end
    if type(saved.showPersonalBests) == "boolean" then
        state.showPersonalBests = saved.showPersonalBests
    end
    if type(saved.enableXPLogs) == "boolean" then state.enableXPLogs = saved.enableXPLogs end
    state.openLogsHotkey = normalizedKeybind(saved.openLogsHotkey, state.openLogsHotkey)
    if saved.dateFormat == "us" or saved.dateFormat == "european" then
        state.dateFormat = saved.dateFormat
    end
    if saved.timeFormat == "12" or saved.timeFormat == "24" then
        state.timeFormat = saved.timeFormat
    end
    if
        saved.questSortBy == "name"
        or saved.questSortBy == "status"
        or saved.questSortBy == "release"
    then
        state.questSortBy = saved.questSortBy
    end
    if
        saved.archaeologyMode == "mysteries"
        or saved.archaeologyMode == "collectors"
        or saved.archaeologyMode == "relics"
        or saved.archaeologyMode == "loadouts"
        or saved.archaeologyMode == "other"
    then
        state.archaeologyMode = saved.archaeologyMode
    end
    local selectedRelicLoadout = tonumber(saved.selectedRelicLoadout)
    if selectedRelicLoadout ~= nil and selectedRelicLoadout >= 0 and selectedRelicLoadout <= 3 then
        state.selectedRelicLoadout = selectedRelicLoadout
    end

    local categoryID = tonumber(saved.selectedCategoryID)
    if categoryID ~= nil then state.selectedCategoryID = categoryID end
    local activeTab = tonumber(saved.activeTab)
    if activeTab == 1 or activeTab == 2 or activeTab == 3 or activeTab == 4 or activeTab == 5 then
        state.activeTab = activeTab
    end
    if saved.xpMode == "notice" or saved.xpMode == "overall" or saved.xpMode == "skills"
        or saved.xpMode == "danger" then
        state.xpMode = saved.xpMode
    end
    copyBoundedNumber(state, saved, "xpStartYear", 2000, 2200)
    copyBoundedNumber(state, saved, "xpEndYear", 2000, 2200)
    copyBoundedNumber(state, saved, "xpStartMonth", 1, 12)
    copyBoundedNumber(state, saved, "xpEndMonth", 1, 12)
    copyBoundedNumber(state, saved, "xpCalendarYear", 2000, 2200)
    copyBoundedNumber(state, saved, "xpCalendarMonth", 1, 12)
    copyBoundedNumber(state, saved, "xpStartDay", 1, 31)
    copyBoundedNumber(state, saved, "xpEndDay", 1, 31)
    copyBoundedNumber(state, saved, "xpSkillID", 0, 28)

    local activeSection = validActiveSection(registry, saved.activeSection)
    if activeSection ~= nil then state.activeSection = activeSection end
    if state.activeSection == "xp" and not state.enableXPLogs then
        state.activeSection = "bosses"
    end
    if type(saved.collapsedTiers) == "table" then state.collapsedTiers = saved.collapsedTiers end
    return state
end

-- Save current settings
function Settings.Save(state)
    local legacy = Storage.ReadStructured(Settings.key)
    local playerKey = Identity.Key(state.playerID, "trophies:v1")
    local playerSaved = true
    if playerKey ~= nil and state.playerID == Identity.Current()
        and (next(state.trophyFound) ~= nil or Storage.ReadStructured(playerKey) ~= nil) then
        playerSaved = Storage.WriteStructured(playerKey, state.trophyFound)
    end
    local saved = Storage.WriteStructured(Settings.key, {
        activeSection = state.activeSection,
        tierFilter = state.tierFilter,
        statusFilter = state.statusFilter,
        search = state.search,
        categorySearch = state.categorySearch,
        selectedCategoryID = state.selectedCategoryID,
        activeTab = state.activeTab,
        xpMode = state.xpMode,
        xpStartYear = state.xpStartYear,
        xpStartMonth = state.xpStartMonth,
        xpStartDay = state.xpStartDay,
        xpEndYear = state.xpEndYear,
        xpEndMonth = state.xpEndMonth,
        xpEndDay = state.xpEndDay,
        xpCalendarYear = state.xpCalendarYear,
        xpCalendarMonth = state.xpCalendarMonth,
        xpSkillID = state.xpSkillID,
        enableXPLogs = state.enableXPLogs,
        openLogsHotkey = state.openLogsHotkey,
        dateFormat = state.dateFormat,
        timeFormat = state.timeFormat,
        selectedSlayerGroup = state.selectedSlayerGroup,
        slayerSearch = state.slayerSearch,
        selectedAbilityGroup = state.selectedAbilityGroup,
        abilitySearch = state.abilitySearch,
        selectedClueGroup = state.selectedClueGroup,
        clueSearch = state.clueSearch,
        selectedPofGroup = state.selectedPofGroup,
        selectedPohGroup = state.selectedPohGroup,
        selectedMinigameGroup = state.selectedMinigameGroup,
        minigameSearch = state.minigameSearch,
        selectedSkillingOutfitGroup = state.selectedSkillingOutfitGroup,
        skillingOutfitSearch = state.skillingOutfitSearch,
        selectedPetGroup = state.selectedPetGroup,
        petSearch = state.petSearch,
        selectedEnchantmentGroup = state.selectedEnchantmentGroup,
        enchantmentSearch = state.enchantmentSearch,
        miscMode = state.miscMode,
        selectedThievingGroup = state.selectedThievingGroup,
        pofSearch = state.pofSearch,
        selectedQuestID = state.selectedQuestID,
        questSearch = state.questSearch,
        questStatusFilter = state.questStatusFilter,
        questShowMiniquests = state.questShowMiniquests,
        questShowSeasonalQuests = state.questShowSeasonalQuests,
        questAvailableInQH = state.questAvailableInQH,
        questSortBy = state.questSortBy,
        questUseCumulativeRequirements = state.questUseCumulativeRequirements,
        questOrderView = state.questOrderView,
        questRequirementFilter = state.questRequirementFilter,
        achievementMode = state.achievementMode,
        achievementOrderView = state.achievementOrderView,
        achievementRequirementFilter = state.achievementRequirementFilter,
        achievementRequirementSearch = state.achievementRequirementSearch,
        archaeologyMode = state.archaeologyMode,
        selectedArchaeologyOtherGroup = state.selectedArchaeologyOtherGroup,
        archaeologyOtherSearch = state.archaeologyOtherSearch,
        selectedMysterySite = state.selectedMysterySite,
        selectedCollector = state.selectedCollector,
        selectedRelicCategory = state.selectedRelicCategory,
        selectedRelicLoadout = state.selectedRelicLoadout,
        showPersonalBests = state.showPersonalBests,
        enableGreenLog = state.enableGreenLog,
        trophyFound = type(legacy) == "table" and legacy.trophyFound or nil,
        collapsedTiers = state.collapsedTiers,
    })
    return saved and playerSaved
end

return Settings
