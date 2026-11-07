-- Build completion cape requirements
local SkillCatalog = require("Resources/Shared/skills/skill_catalog")
local AchievementText = require("Resources/Shared/achievements/achievement_text")
local ClientConfig = require("Resources/Shared/client_config")

local CapeRequirements = {}

local field = ClientConfig.Read

-- Create a requirement snapshot
function CapeRequirements.NewSnapshot()
    return {
        summaryNodes = {},
        detailNodes = {},
    }
end

-- Get the requirement node cache
local function nodeCache(snapshot, details)
    if snapshot == nil then return {} end
    local key = details and "detailNodes" or "summaryNodes"
    snapshot[key] = snapshot[key] or {}
    return snapshot[key]
end

-- Read the first available field
local function firstField(source, keys)
    for _, key in ipairs(keys) do
        local value = field(source, key)
        if value ~= nil then return value end
    end
    return nil
end

-- Read a numeric field
local function numberField(source, keys) return tonumber(firstField(source, keys)) end

-- Read a text field
local function stringField(source, keys)
    local value = firstField(source, keys)
    return type(value) == "string" and value ~= "" and value or nil
end

-- Read config values
local function values(source)
    local result = {}
    if source == nil then return result end
    local ok = pcall(function()
        for _, value in ipairs(source) do
            result[#result + 1] = value
        end
    end)
    if ok and #result > 0 then return result end
    pcall(function()
        for _, value in pairs(source) do
            result[#result + 1] = value
        end
    end)
    return result
end

-- Resolve an achievement by ID
local function achievementFromID(achievementID)
    return ClientConfig.FromID(config ~= nil and config.Achievement or nil, achievementID)
end

-- Resolve the cape achievement
local function achievementFromCape(cape)
    if config == nil or config.Achievement == nil then return nil end
    return ClientConfig.Named(config.Achievement, cape.achievementConfig)
        or achievementFromID(tonumber(cape.achievementID))
end

-- Resolve an achievement reference
local function achievementFromReference(reference)
    if reference == nil then return nil end
    local nested = firstField(reference, { "achievement", "achievementConfig", "config" })
    if nested ~= nil and type(nested) ~= "string" and type(nested) ~= "number" then
        reference = nested
    end
    if field(reference, "requirements") ~= nil or field(reference, "prereqs") ~= nil then
        return reference
    end
    local achievementID = type(reference) == "number" and reference
        or numberField(reference, { "id", "achievementID", "achievementId" })
    return achievementFromID(achievementID)
end

-- Check achievement completion
local function achievementComplete(achievement)
    if field(achievement, "complete") == true or field(achievement, "isComplete") == true then
        return true
    end
    local progress = tonumber(field(achievement, "progress"))
    return progress == -2 or progress ~= nil and progress >= 10000
end

-- Build a stable achievement key
local function achievementKey(achievement)
    local achievementID = numberField(achievement, { "id", "achievementID", "achievementId" })
    if achievementID ~= nil then return "achievement:" .. tostring(achievementID) end
    local configName = stringField(achievement, { "configName", "name" })
    return configName ~= nil and "achievement:" .. configName or nil
end

-- Build an achievement node
local function achievementNode(reference, path, cache, details)
    local achievement = achievementFromReference(reference)
    if achievement == nil then return nil end
    local key = achievementKey(achievement)
    if key == nil or path[key] then return nil end
    if cache[key] ~= nil then return cache[key] end

    local node = {
        key = key,
        complete = achievementComplete(achievement),
        children = {},
    }
    if details then
        local achievementID = numberField(achievement, { "id", "achievementID", "achievementId" })
        node.source = achievement
        node.name = stringField(achievement, { "displayName", "title", "name" })
            or "Achievement " .. tostring(achievementID or "")
        node.description = AchievementText.Description(achievement)
    end
    cache[key] = node

    path[key] = true
    local seen = {}
    for _, sourceName in ipairs({ "requirements", "prereqs" }) do
        local source = field(achievement, sourceName)
        for _, referenceValue in ipairs(values(field(source, "achievements"))) do
            local child = achievementNode(referenceValue, path, cache, details)
            if child ~= nil and not seen[child.key] then
                seen[child.key] = true
                node.children[#node.children + 1] = child
            end
        end

        for _, questReference in ipairs(values(field(source, "quests"))) do
            local questID = type(questReference) == "number" and questReference
                or numberField(questReference, { "id", "questID", "questId" })
            local quest = ClientConfig.FromID(config ~= nil and config.Quest or nil, questID)
            local questKey = questID ~= nil and "quest:" .. tostring(questID) or nil
            if questKey ~= nil and not seen[questKey] then
                seen[questKey] = true
                local child = {
                    key = questKey,
                    complete = field(quest, "hasFinishedQuest") == true,
                    children = {},
                }
                if details then
                    child.name = stringField(quest, { "displayName", "name" })
                        or stringField(questReference, { "displayName", "name" })
                        or "Quest " .. tostring(questID)
                end
                node.children[#node.children + 1] = child
            end
        end

        for _, skillReference in ipairs(values(field(source, "skills"))) do
            local skillID = type(skillReference) == "number" and skillReference
                or numberField(skillReference, { "id", "skillID", "skillId" })
            local level = numberField(skillReference, {
                "minimumLevel",
                "level",
                "requiredLevel",
            }) or 1
            local skillKey = skillID ~= nil
                    and "skill:" .. tostring(skillID) .. ":" .. tostring(level)
                or nil
            if skillKey ~= nil and not seen[skillKey] then
                seen[skillKey] = true
                local currentLevel = nil
                if Player ~= nil and Player.GetLevelGameplay ~= nil then
                    pcall(function() currentLevel = Player.GetLevelGameplay(skillID) end)
                end
                currentLevel = tonumber(currentLevel)
                local child = {
                    key = skillKey,
                    complete = currentLevel ~= nil and currentLevel >= level,
                    children = {},
                }
                if details then
                    local skill = SkillCatalog.byID[skillID]
                    child.name = stringField(skillReference, { "displayName", "name" })
                        or skill ~= nil and skill.name
                        or "Skill " .. tostring(skillID)
                    child.description = "Level " .. tostring(level)
                end
                node.children[#node.children + 1] = child
            end
        end
    end
    path[key] = nil
    return node
end

-- Build the achievement guide
function CapeRequirements.Guide(node)
    if node == nil then return nil end
    local rawEntries = AchievementText.GuideEntries(node.source)
    local entries, skippedSummary = {}, false
    for _, entry in ipairs(rawEntries) do
        if not skippedSummary and entry.text == node.description then
            skippedSummary = true
        else
            entries[#entries + 1] = entry
        end
    end

    local total = numberField(node.source, { "totalRequirementCount" }) or #entries
    total = math.max(total, #entries)
    local progress = numberField(node.source, { "progress" })
    local complete = node.complete == true and total or 0
    if node.complete ~= true and progress ~= nil and progress >= 0 and progress <= total then
        complete = math.floor(progress)
    end
    if node.complete == true then
        for _, entry in ipairs(entries) do
            entry.complete = true
        end
    end

    return {
        name = node.name,
        description = node.description or "",
        complete = complete,
        total = total,
        entries = entries,
        achievementComplete = node.complete == true,
    }
end

-- Build linear requirement rows
function CapeRequirements.LinearRows(root)
    local rows, visited = {}, {}
    -- Visit requirement nodes
    local function visit(node)
        if node == nil or visited[node.key] then return end
        visited[node.key] = true
        for _, child in ipairs(node.children or {}) do
            visit(child)
        end
        rows[#rows + 1] = { node = node, depth = 0, index = #rows + 1 }
    end
    for _, child in ipairs(root ~= nil and root.children or {}) do
        visit(child)
    end
    return rows
end

-- Build tree requirement rows
function CapeRequirements.TreeRows(root)
    local rows = {}
    -- Visit requirement nodes
    local function visit(node, depth, continuations, isLast, path)
        if node == nil or path[node.key] then return end
        local rowContinuations = {}
        for level, continues in pairs(continuations or {}) do
            rowContinuations[level] = continues == true
        end
        rows[#rows + 1] = {
            node = node,
            depth = depth,
            continuations = rowContinuations,
            isLast = isLast == true,
        }
        path[node.key] = true
        for index, child in ipairs(node.children or {}) do
            local childContinuations = {}
            for level, continues in pairs(rowContinuations) do
                childContinuations[level] = continues
            end
            childContinuations[depth + 1] = index < #(node.children or {})
            visit(child, depth + 1, childContinuations, index == #(node.children or {}), path)
        end
        path[node.key] = nil
    end
    local children = root ~= nil and root.children or {}
    for index, child in ipairs(children) do
        visit(child, 0, {}, index == #children, {})
    end
    return rows
end

function CapeRequirements.IsUnblocked(node)
    if node == nil or node.complete == true then return false end
    for _, prerequisite in ipairs(node.children or {}) do
        if prerequisite.complete ~= true then return false end
    end
    return true
end

function CapeRequirements.FilterRows(rows, mode, query)
    query = string.lower(tostring(query or ""))
    local filtered = {}
    for _, row in ipairs(rows or {}) do
        local include = mode == "incomplete" and row.node.complete ~= true
            or mode == "unblocked" and CapeRequirements.IsUnblocked(row.node)
            or mode ~= "incomplete" and mode ~= "unblocked"
        if include and query ~= "" then
            local searchable = row.node.searchText
            if searchable == nil then
                searchable = string.lower(
                    tostring(row.node.name or "") .. " " .. tostring(row.node.description or "")
                )
                row.node.searchText = searchable
            end
            include = string.find(searchable, query, 1, true) ~= nil
        end
        if include then filtered[#filtered + 1] = row end
    end
    return filtered
end

-- Calculate requirement progress
local function progress(root)
    local complete, total, visited = 0, 0, { [root.key] = true }
    -- Visit requirement nodes
    local function visit(node)
        if visited[node.key] then return end
        visited[node.key] = true
        total = total + 1
        if node.complete then complete = complete + 1 end
        for _, child in ipairs(node.children) do
            visit(child)
        end
    end
    for _, child in ipairs(root.children) do
        visit(child)
    end
    return complete, total
end

-- Build a cape requirement snapshot
function CapeRequirements.Build(cape, snapshot)
    local achievement = achievementFromCape(cape)
    if achievement == nil then return nil end
    local root = achievementNode(achievement, {}, nodeCache(snapshot, true), true)
    if root == nil then return nil end
    local linearRows = CapeRequirements.LinearRows(root)
    local complete, total = progress(root)
    return {
        cape = cape,
        root = root,
        linearRows = linearRows,
        complete = complete,
        total = total,
    }
end

-- Select visible requirement rows
function CapeRequirements.Rows(data, orderView)
    if orderView ~= "tree" then return data.linearRows end
    data.treeRows = data.treeRows or CapeRequirements.TreeRows(data.root)
    return data.treeRows
end

-- Build the cape progress summary
function CapeRequirements.Summary(cape, snapshot)
    local root = achievementNode(
        achievementFromCape(cape),
        {},
        nodeCache(snapshot, false),
        false
    )
    if root == nil then return { complete = 0, total = 0, available = false } end
    local complete, total = progress(root)
    return {
        complete = complete,
        total = total,
        available = true,
    }
end

return CapeRequirements
