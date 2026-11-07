-- Build quest prerequisite trees and routes
local QuestRequirements = {}

QuestRequirements.STATUS_ORDER = {
    incomplete = 1,
    started = 2,
    complete = 3,
}

-- Resolve a quest object
local function questObject(questID)
    if config == nil or config.Quest == nil or config.Quest.FromID == nil then return nil end
    local ok, quest = pcall(function() return config.Quest.FromID(questID) end)
    return ok and quest or nil
end

function QuestRequirements.IsFinished(questID)
    local quest = questObject(questID)
    if quest == nil then return false end
    local ok, finished = pcall(function() return quest.hasFinishedQuest end)
    return ok and finished == true
end

-- Read a quest's status
function QuestRequirements.Status(questID)
    local quest = questObject(questID)
    if quest == nil then return "incomplete" end
    local finishedOk, finished = pcall(function() return quest.hasFinishedQuest end)
    if finishedOk and finished == true then return "complete" end
    local startedOk, started = pcall(function() return quest.hasStartedQuest end)
    if startedOk and started == true then return "started" end
    return "incomplete"
end

-- Build the quest requirement order
function QuestRequirements.RequirementOrder(target, byID)
    local ordered, visited, visiting = {}, {}, {}
    -- Visit requirement nodes
    local function visit(quest)
        if quest == nil or visited[quest.id] or visiting[quest.id] then return end
        visiting[quest.id] = true
        for _, prerequisite in ipairs(quest.preReqQuests or {}) do
            visit(byID[prerequisite.id])
        end
        visiting[quest.id] = nil
        visited[quest.id] = true
        ordered[#ordered + 1] = quest
    end
    visit(target)
    return ordered
end

-- Build a root-first tree with branch-local cycle detection
function QuestRequirements.RequirementTree(target, byID)
    local rows = {}
    -- Visit requirement nodes
    local function visit(quest, depth, continuations, isLast, path)
        if quest == nil or path[quest.id] then return end

        local rowContinuations = {}
        for level, continues in pairs(continuations or {}) do
            rowContinuations[level] = continues == true
        end
        rows[#rows + 1] = {
            quest = quest,
            depth = depth,
            continuations = rowContinuations,
            isLast = isLast == true,
        }

        path[quest.id] = true
        local children = {}
        for _, prerequisite in ipairs(quest.preReqQuests or {}) do
            local child = byID[prerequisite.id]
            if child ~= nil and not path[child.id] then children[#children + 1] = child end
        end
        for index, child in ipairs(children) do
            local childContinuations = {}
            for level, continues in pairs(rowContinuations) do
                childContinuations[level] = continues
            end
            childContinuations[depth + 1] = index < #children
            visit(child, depth + 1, childContinuations, index == #children, path)
        end
        path[quest.id] = nil
    end
    visit(target, 0, {}, true, {})
    return rows
end

-- Combine duplicate skill requirements
function QuestRequirements.AggregateSkills(chain)
    local levels = {}
    for _, quest in ipairs(chain) do
        for _, requirement in ipairs(quest.preReqSkills or {}) do
            local skillID = tonumber(requirement.id)
            local level = tonumber(requirement.minimumLevel) or 0
            if skillID ~= nil and (levels[skillID] == nil or levels[skillID].level < level) then
                levels[skillID] = {
                    id = skillID,
                    name = requirement.name or ("Skill " .. tostring(skillID)),
                    level = level,
                }
            end
        end
    end
    local result = {}
    for _, requirement in pairs(levels) do
        result[#result + 1] = requirement
    end
    table.sort(result, function(left, right)
        if left.level == right.level then return left.name < right.name end
        return left.level > right.level
    end)
    return result
end

-- Build quest detail state
function QuestRequirements.DetailState(target, byID, options)
    options = options or {}
    local chain = QuestRequirements.RequirementOrder(target, byID)
    local skillSource = options.cumulativeRequirements == false and { target } or chain
    local skills = QuestRequirements.AggregateSkills(skillSource)
    local isFinished = options.isFinished or QuestRequirements.IsFinished
    local playerLevel = options.playerLevel

    local skillStates = {}
    local completedSkills = 0
    for index, requirement in ipairs(skills) do
        local currentLevel = playerLevel ~= nil and playerLevel(requirement.id) or nil
        local complete = currentLevel ~= nil and currentLevel >= requirement.level
        skillStates[index] = complete
        if complete then completedSkills = completedSkills + 1 end
    end

    local chainStates = {}
    local completedQuests = 0
    for _, quest in ipairs(chain) do
        local complete = isFinished(quest.id) == true
        chainStates[quest.id] = complete
        if complete then completedQuests = completedQuests + 1 end
    end

    local orderView = options.orderView == "tree" and "tree" or "linear"
    local orderRows = {}
    if orderView == "tree" then
        orderRows = QuestRequirements.RequirementTree(target, byID)
    else
        for index, quest in ipairs(chain) do
            orderRows[#orderRows + 1] = {
                quest = quest,
                index = index,
                depth = 0,
            }
        end
    end

    local totalSkills = #skills
    local incompleteOnly = options.requirementFilter == "incomplete"
    if incompleteOnly then
        local visibleSkills, visibleStates = {}, {}
        for index, skill in ipairs(skills) do
            if not skillStates[index] then
                visibleSkills[#visibleSkills + 1] = skill
                visibleStates[#visibleStates + 1] = false
            end
        end
        skills, skillStates = visibleSkills, visibleStates
        local visibleRows, ancestors = {}, {}
        for _, row in ipairs(orderRows) do
            local originalDepth = row.depth
            while #ancestors > originalDepth do table.remove(ancestors) end
            local depth = 0
            for _, visible in ipairs(ancestors) do
                if visible then depth = depth + 1 end
            end
            local visible = not chainStates[row.quest.id]
            ancestors[#ancestors + 1] = visible
            if visible then
                row.depth = depth
                row.index = #visibleRows + 1
                visibleRows[#visibleRows + 1] = row
            end
        end
        -- Rebuild branch connectors after completed ancestors have been removed.
        for index, row in ipairs(visibleRows) do
            row.isLast = true
            row.continuations = {}
            for nextIndex = index + 1, #visibleRows do
                local nextDepth = visibleRows[nextIndex].depth
                if nextDepth <= row.depth then
                    row.isLast = nextDepth < row.depth
                    break
                end
            end
            for level = 1, row.depth - 1 do
                for nextIndex = index + 1, #visibleRows do
                    local nextDepth = visibleRows[nextIndex].depth
                    if nextDepth <= level then
                        row.continuations[level] = nextDepth == level
                        break
                    end
                end
            end
        end
        orderRows = visibleRows
    end

    return {
        quest = target,
        finished = isFinished(target.id) == true,
        chain = chain,
        chainStates = chainStates,
        completedQuests = completedQuests,
        skills = skills,
        skillStates = skillStates,
        completedSkills = completedSkills,
        totalSkills = totalSkills,
        requirementFilter = incompleteOnly and "incomplete" or "all",
        orderView = orderView,
        orderRows = orderRows,
    }
end

return QuestRequirements
