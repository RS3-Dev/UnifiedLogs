-- Keep optional QuestHelper calls outside the quest UI.
local QuestHelper = {}

local function api()
    local value = questhelper
    if type(value) == "table" and value.apiVersion == 1
        and type(value.listQuests) == "function" and type(value.hasQuest) == "function"
        and type(value.openQuest) == "function" then return value end
end

function QuestHelper.AvailableQuests()
    local dependency = api()
    if dependency == nil then return {} end
    local ok, quests = pcall(dependency.listQuests)
    if not ok or type(quests) ~= "table" then return {} end
    local byID = {}
    for _, quest in ipairs(quests) do
        if type(quest) == "table" and math.type(quest.id) == "integer" and quest.id >= 0 then
            byID[quest.id] = true
        end
    end
    return byID
end

function QuestHelper.OpenQuest(questID)
    local dependency = api()
    if dependency == nil then return false, "unavailable" end
    if math.type(questID) ~= "integer" or questID < 0 then return false, "unsupported_quest" end
    local checked, supported = pcall(dependency.hasQuest, questID)
    if not checked then return false, "helper_unavailable" end
    if supported ~= true then return false, "unsupported_quest" end
    -- Version 1 returns acceptance; QuestHelper drains the request on a later tick.
    local ok, opened = pcall(dependency.openQuest, questID)
    if not ok then return false, "helper_unavailable" end
    if opened ~= true then return false, "helper_unavailable" end
    return true
end

return QuestHelper
