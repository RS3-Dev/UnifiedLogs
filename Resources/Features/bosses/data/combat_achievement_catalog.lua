-- Build the combat achievement catalogue
local ClientConfig = require("Resources/Shared/client_config")
local read, configName = ClientConfig.Read, ClientConfig.ConfigName

local CombatAchievementCatalog = {}

local AchievementText = require("Resources/Shared/achievements/achievement_text")
local Descriptions = require("Resources/Features/bosses/combat_achievement_descriptions")

local TIER_ORDER = {
    EASY = 1,
    MEDIUM = 2,
    HARD = 3,
    ELITE = 4,
    MASTER = 5,
    GRANDMASTER = 6,
}

-- Map encounter lists to Bosses sidebar groups
local CATEGORY_GROUPS = {
    { 4842, { 4843, 4844, 4845 } },
    { 4846, { 4847, 4848, 4849 } },
    { 4850, { 4851, 4852, 4853 } },
    { 4854, { 4855, 4856, 4857, 4858 } },
    { 4859, { 4860, 4861, 4862, 4863 } },
    { 5439, { 4866, 4867 } },
    { 5440, { 5431, 5433, 5435 } },
}

local CATEGORY_NAME_OVERRIDES = {
    [4854] = "God Wars Dungeon",
}

-- Resolve a named enum
local function namedEnum(name)
    return ClientConfig.Named(config ~= nil and config.Enum or nil, name)
end

-- Read enum entries
local function enumEntries(enum)
    local values = read(enum, "values")
    if type(values) ~= "table" then return {} end
    local result = {}
    for key, entry in pairs(values) do
        if type(entry) == "table" and entry[2] ~= nil then
            result[#result + 1] = { key = entry[1], value = entry[2] }
        else
            result[#result + 1] = { key = key, value = entry }
        end
    end
    return result
end

-- Format an achievement label
local function label(value)
    if value == nil then return nil end
    local result = tostring(value)
    result = string.gsub(result, "^.-<[Bb][Rr]%s*/?>", "")
    result = string.gsub(result, "<[^>]+>", "")
    result = string.gsub(result, "^%s+", "")
    result = string.gsub(result, "%s+$", "")
    return result ~= "" and result or nil
end

-- Build an enum lookup
local function enumMap(enum)
    local result = {}
    for _, entry in ipairs(enumEntries(enum)) do
        local key = tonumber(entry.key)
        if key ~= nil then result[key] = entry.value end
    end
    return result
end

-- Map achievements to categories
local function categoryMap()
    local result = {}
    for _, group in ipairs(CATEGORY_GROUPS) do
        for _, bossID in ipairs(group[2]) do
            result[bossID] = group[1]
        end
    end
    return result
end

-- Read required tasks and their tiers from the client's mastery roots.
local function masteryTasks(sets, yieldWork)
    local roots, rootIDs, tiers = {}, {}, {}
    for _, entry in ipairs(enumEntries(sets)) do
        local root = entry.value
        local rootID = tonumber(read(root, "id"))
        local token = string.match(configName(root) or "", "^COMBAT_MASTERY_(%u+)$")
        if rootID ~= nil then rootIDs[rootID] = true end
        if token ~= nil and TIER_ORDER[token] ~= nil then
            roots[#roots + 1] = { achievement = root, tier = token }
            tiers[token] = true
        end
    end
    for token in pairs(TIER_ORDER) do
        if not tiers[token] then error("combat mastery tier roots are unavailable") end
    end

    local tasks, processed = {}, 0
    for _, root in ipairs(roots) do
        local requirements = read(read(root.achievement, "requirements"), "achievements")
        if type(requirements) ~= "table" then error("combat mastery requirements are unavailable") end
        for _, requirement in pairs(requirements) do
            local achievement = read(requirement, "achievement")
            local identifier = tonumber(read(achievement, "id"))
            if identifier == nil then error("combat mastery requirement achievement is unavailable") end
            -- Earlier-tier completion requirements are not individual tasks.
            if not rootIDs[identifier] then
                local existing = tasks[identifier]
                if existing == nil or TIER_ORDER[root.tier] < TIER_ORDER[existing.tier] then
                    tasks[identifier] = { achievement = achievement, tier = root.tier }
                end
            end
            processed = processed + 1
            if processed % 24 == 0 then yieldWork() end
        end
    end
    if next(tasks) == nil then error("combat mastery requirements contained no tasks") end
    return tasks
end

function CombatAchievementCatalog.Build(yieldWork)
    yieldWork = yieldWork or function() end
    local descriptions = Descriptions.Current()
    local router = namedEnum("CHEEVO_COMBAT_SUBCATEGORY_TO_DISPLAY_LIST")
    local names = namedEnum("CHEEVO_SUBCAT_TO_NAME")
    local sets = namedEnum("COMBAT_MASTERY_TASK_SETS")
    if router == nil or names == nil or sets == nil then
        error("combat achievement client enums are unavailable")
    end

    local namesByID = enumMap(names)
    local categoryByBoss = categoryMap()
    local tasks = masteryTasks(sets, yieldWork)
    local records, processed = {}, 0

    -- Boss display lists supply ordering, while mastery requirements supply membership.
    for _, route in ipairs(enumEntries(router)) do
        local bossID = tonumber(route.key)
        if bossID ~= nil then
            for _, item in ipairs(enumEntries(route.value)) do
                local achievement = item.value
                local achievementID = tonumber(read(achievement, "id"))
                local task = tasks[achievementID]
                if task ~= nil and tonumber(read(task.achievement, "subCategory")) == bossID then
                    task.displayOrder = task.displayOrder or (tonumber(item.key) or 0) + 1
                end
                processed = processed + 1
                if processed % 24 == 0 then yieldWork() end
            end
        end
    end

    for identifier, task in pairs(tasks) do
        local achievement = task.achievement
        local bossID = tonumber(read(achievement, "subCategory"))
        if bossID == nil then error("combat mastery task subcategory is unavailable") end
        local categoryID = categoryByBoss[bossID] or bossID
        local category = CATEGORY_NAME_OVERRIDES[categoryID]
            or label(namesByID[categoryID]) or label(namesByID[bossID]) or "Unknown"
        local progress = tonumber(read(achievement, "progress"))
        local complete
        if progress ~= nil then complete = progress == -2 or progress >= 10000 end
        records[#records + 1] = {
            id = identifier,
            configName = configName(achievement),
            source = achievement,
            progress = progress,
            complete = complete,
            name = tostring(read(achievement, "name") or "Unknown achievement"),
            description = Descriptions.Get(achievement) or AchievementText.Description(achievement),
            tier = string.upper(string.sub(task.tier, 1, 1)) .. string.lower(string.sub(task.tier, 2)),
            tierOrder = TIER_ORDER[task.tier],
            bossID = bossID,
            boss = label(namesByID[bossID]) or category,
            categoryID = categoryID,
            category = category,
            displayOrder = task.displayOrder or 1000000 + identifier,
        }
        processed = processed + 1
        if processed % 24 == 0 then yieldWork() end
    end

    table.sort(records, function(left, right)
        if left.bossID ~= right.bossID then return left.bossID < right.bossID end
        if left.displayOrder ~= right.displayOrder then
            return left.displayOrder < right.displayOrder
        end
        return left.id < right.id
    end)
    if Descriptions.Current() ~= descriptions then return CombatAchievementCatalog.Build(yieldWork) end
    if #records == 0 then error("combat achievement client enums contained no mastery tasks") end
    return records
end


return CombatAchievementCatalog
