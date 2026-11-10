-- Define the quest feature
local Feature = {
    id = "quests",
    label = "Quests",
    records = {},
}

function Feature.LoadData() Feature.records = require("Resources/Features/quests/data/quest_catalog").records end

function Feature.CreatePage(parent, context)
    local state = context.state
    local page = require("Resources/Features/quests/quest_page").new(parent, {
        x = context.x,
        y = context.y,
        width = context.width,
        height = context.height,
        records = Feature.records,
        isVisible = context.isVisible,
        onQuestHelperOpened = context.closeLogs,
        selectedID = state.selectedQuestID,
        search = state.questSearch,
        statusFilter = state.questStatusFilter,
        showMiniquests = state.questShowMiniquests,
        showSeasonalQuests = state.questShowSeasonalQuests,
        availableInQH = state.questAvailableInQH,
        sortBy = state.questSortBy,
        useCumulativeRequirements = state.questUseCumulativeRequirements,
        orderView = state.questOrderView,
        requirementFilter = state.questRequirementFilter,
        onRequirementFilterChange = function(value)
            state.questRequirementFilter = value
            context.saveState()
        end,
        onStateChange = function(selectedID, search, persist)
            state.selectedQuestID, state.questSearch = selectedID, search
            if persist ~= false then context.saveState() end
        end,
        onFilterChange = function(status, miniquests, seasonal, availableInQH)
            state.questStatusFilter = status
            state.questShowMiniquests, state.questShowSeasonalQuests = miniquests, seasonal
            state.questAvailableInQH = availableInQH == true
            context.saveState()
        end,
        onSortChange = function(sortBy)
            state.questSortBy = sortBy
            context.saveState()
        end,
    })
    state.selectedQuestID = page.selectedID
    return page
end

return Feature
