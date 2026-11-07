-- Group boss records and collection logs
local BossCategories = {}
BossCategories.__index = BossCategories

local ALL_CATEGORIES_ID = 0
-- These encounters retain shared pages, with individual bosses in the sidebar.
local SHARED_DUNGEON_CATEGORIES = { [4854] = true, [4859] = true }
local DROP_GROUP_ALIASES = {
    ivar = "ivarkingofbones",
    silverquill = "silverquillthedreadhog",
    rexmatriarchosseous = "rexmatriarchs",
}
local DROP_ONLY_CATEGORIES = {
    croesus = true,
    gateofelidinis = true,
    ghrazibloodknights = true,
}

-- Cache derived catalogue text; the same names are compared on every rebuild
local lowerCache, logNameCache, logPartsCache = {}, {}, {}

-- Normalize text case
local function lower(value)
    local text = tostring(value or "")
    local result = lowerCache[text]
    if result == nil then
        result = string.lower(text)
        lowerCache[text] = result
    end
    return result
end

-- Normalize search input
local function trimmedLower(value)
    local result = string.lower(tostring(value or ""))
    result = string.gsub(result, "^%s+", "")
    return string.gsub(result, "%s+$", "")
end

-- Normalize a collection log name
local function normalizedLogName(value)
    local text = tostring(value or "")
    local result = logNameCache[text]
    if result == nil then
        result = string.gsub(string.gsub(lower(text), "^the%s+", ""), "[^%w]", "")
        logNameCache[text] = result
    end
    return result
end

-- Split a combined log name such as "A & B" into normalized names
local function logNameParts(groupName)
    local text = tostring(groupName or "")
    local parts = logPartsCache[text]
    if parts == nil then
        parts = {}
        local split = string.gsub(text, "%s+&%s+", "|")
        split = string.gsub(split, "%s+[Aa][Nn][Dd]%s+", "|")
        for part in string.gmatch(split, "[^|]+") do
            parts[#parts + 1] = normalizedLogName(part)
        end
        logPartsCache[text] = parts
    end
    return parts
end

-- Create a stable category ID
local function syntheticCategoryID(value)
    local hash = 0
    local name = normalizedLogName(value)
    for index = 1, #name do
        hash = (hash * 31 + string.byte(name, index)) % 1000000000
    end
    return -(hash + 1)
end

-- Check whether a record matches a target
local function matchesTargets(groupName, targets)
    local normalized = normalizedLogName(groupName)
    if targets[normalized] == true then return true end
    local alias = DROP_GROUP_ALIASES[normalized]
    if alias ~= nil and targets[alias] == true then return true end

    for _, part in ipairs(logNameParts(groupName)) do
        if targets[part] then return true end
    end
    return false
end

-- Add patched aliases, replacing bundled ones, and drops-only logs
function BossCategories.Extend(aliases, dropOnly)
    for from, to in pairs(aliases) do
        DROP_GROUP_ALIASES[normalizedLogName(from)] = normalizedLogName(to)
    end
    for _, name in ipairs(dropOnly) do
        DROP_ONLY_CATEGORIES[normalizedLogName(name)] = true
    end
end

function BossCategories.new(achievements, dropLogs, bossRecords, bossKillCounts)
    return setmetatable({
        achievements = achievements or {},
        dropLogs = dropLogs or {},
        bossRecords = bossRecords or {},
        bossKillCounts = bossKillCounts or {},
    }, BossCategories)
end

-- Build the ordered boss categories
function BossCategories:OrderedCategories()
    local byID, achievementTargets = {}, {}
    for _, achievement in ipairs(self.achievements) do
        achievementTargets[normalizedLogName(achievement.category)] = true
        achievementTargets[normalizedLogName(achievement.boss)] = true
        if achievement.categoryID ~= nil and byID[achievement.categoryID] == nil then
            byID[achievement.categoryID] = {
                id = achievement.categoryID,
                name = achievement.category,
                count = 0,
                searchText = lower(achievement.category),
            }
        end
        local category = achievement.categoryID ~= nil and byID[achievement.categoryID] or nil
        if category ~= nil then
            category.count = category.count + 1
            category.searchText = category.searchText .. " " .. lower(achievement.boss)
        end
    end
    -- Keep uncategorized encounter logs accessible
    for groupName, items in pairs(self.dropLogs) do
        local hasEncounterMetadata = self.bossRecords[groupName] ~= nil
            or self.bossKillCounts[groupName] ~= nil
        local normalized = normalizedLogName(groupName)
        local alias = DROP_GROUP_ALIASES[normalized]
        local represented = achievementTargets[normalized] == true
            or alias ~= nil and achievementTargets[alias] == true
        if hasEncounterMetadata and DROP_ONLY_CATEGORIES[normalized] and not represented then
            local id = syntheticCategoryID(groupName)
            byID[id] = {
                id = id,
                name = groupName,
                count = type(items) == "table" and #items or 0,
                searchText = lower(groupName),
            }
        end
    end
    local entries = {}
    for _, category in pairs(byID) do
        entries[#entries + 1] = category
    end
    table.sort(entries, function(left, right) return lower(left.name) < lower(right.name) end)
    return entries
end

-- Build entries for a boss category
function BossCategories:CategoryEntries(search, dropsOnly)
    local entries = {}
    local query = trimmedLower(search)
    local sidebarCategories = {}
    for _, category in ipairs(self:OrderedCategories()) do
        local bosses = {}
        if SHARED_DUNGEON_CATEGORIES[category.id] then
            for _, achievement in ipairs(self.achievements) do
                if achievement.categoryID == category.id and achievement.bossID ~= nil
                    and achievement.bossID ~= category.id then
                    bosses[achievement.bossID] = {
                        id = achievement.bossID, name = achievement.boss,
                        categoryID = category.id, count = category.count,
                        searchText = lower(achievement.boss) .. " " .. lower(category.name),
                    }
                end
            end
        end
        if next(bosses) == nil then
            sidebarCategories[#sidebarCategories + 1] = category
        else
            for _, boss in pairs(bosses) do sidebarCategories[#sidebarCategories + 1] = boss end
        end
    end
    table.sort(sidebarCategories, function(left, right) return lower(left.name) < lower(right.name) end)
    for _, category in ipairs(sidebarCategories) do
        if
            (query == "" or string.find(category.searchText, query, 1, true) ~= nil)
            and (not dropsOnly or #self:SelectedDropGroups({ selectedCategoryID = category.id }) > 0)
        then
            entries[#entries + 1] = category
        end
    end
    if dropsOnly then
        if query == "" or string.find("all bosses", query, 1, true) ~= nil then
            local count = 0
            for _, group in ipairs(self:AllBossDropGroups()) do
                count = count + #group.items
            end
            table.insert(entries, 1, {
                id = ALL_CATEGORIES_ID,
                name = "All bosses",
                count = count,
            })
        end
    else
        table.insert(entries, 1, {
            id = ALL_CATEGORIES_ID,
            name = "All",
            count = #self.achievements,
        })
    end
    return entries
end

-- Resolve a sidebar boss to the shared dungeon page without changing its selection.
function BossCategories:PageCategoryID(categoryID)
    for _, achievement in ipairs(self.achievements) do
        if SHARED_DUNGEON_CATEGORIES[achievement.categoryID] and achievement.bossID == categoryID then
            return achievement.categoryID
        end
    end
    return categoryID
end

-- Select an available boss category
function BossCategories:EnsureSelectedCategory(state)
    if state.activeTab == 3 or state.activeTab == 4 or state.activeTab == 5 then return end
    if state.selectedCategoryID == ALL_CATEGORIES_ID then return end
    -- Restore an older shared-page selection to a visible boss entry.
    if SHARED_DUNGEON_CATEGORIES[state.selectedCategoryID] then
        for _, category in ipairs(self:CategoryEntries("", state.activeTab == 2)) do
            if category.categoryID == state.selectedCategoryID then
                state.selectedCategoryID = category.id
                break
            end
        end
    end
    local pageCategoryID = self:PageCategoryID(state.selectedCategoryID)
    if state.activeTab == 2 then
        for _, category in ipairs(self:OrderedCategories()) do
            if category.id == pageCategoryID then return end
        end
    end
    for _, achievement in ipairs(self.achievements) do
        if achievement.categoryID == pageCategoryID then return end
    end
    state.selectedCategoryID = ALL_CATEGORIES_ID
    state.activeTab = 1
end

-- Get the selected category name
function BossCategories:CategoryName(categoryID)
    categoryID = self:PageCategoryID(categoryID)
    if categoryID == ALL_CATEGORIES_ID then return "All" end
    for _, category in ipairs(self:OrderedCategories()) do
        if category.id == categoryID then return category.name end
    end
    return "Select a category"
end

-- Get achievements for the selected boss
function BossCategories:VisibleAchievements(state)
    local records = {}
    local query = trimmedLower(state.search)
    local categoryID = self:PageCategoryID(state.selectedCategoryID)
    for _, achievement in ipairs(self.achievements) do
        local categoryMatches = categoryID == ALL_CATEGORIES_ID or achievement.categoryID == categoryID
        local tierMatches = state.tierFilter == 0 or achievement.tierOrder == state.tierFilter
        local statusMatches = state.statusFilter == 0
            or state.statusFilter == 1 and achievement.complete == true
            or state.statusFilter == 2 and achievement.complete ~= true
        local searchMatches = query == ""
            or string.find(lower(achievement.category), query, 1, true) ~= nil
            or string.find(lower(achievement.boss), query, 1, true) ~= nil
            or string.find(lower(achievement.name), query, 1, true) ~= nil
            or string.find(lower(achievement.description), query, 1, true) ~= nil
        if categoryMatches and tierMatches and statusMatches and searchMatches then
            records[#records + 1] = achievement
        end
    end
    table.sort(records, function(left, right)
        if left.tierOrder ~= right.tierOrder then return left.tierOrder < right.tierOrder end
        local leftName, rightName = lower(left.name), lower(right.name)
        if leftName ~= rightName then return leftName < rightName end
        return (left.id or 0) < (right.id or 0)
    end)
    return records
end

-- Find collection groups for a boss
function BossCategories:MatchingDropGroups(categoryID, categoryName)
    local targets = { [normalizedLogName(categoryName)] = true }
    for _, achievement in ipairs(self.achievements) do
        if achievement.categoryID == categoryID then
            targets[normalizedLogName(achievement.boss)] = true
        end
    end

    local groups = {}
    for groupName, items in pairs(self.dropLogs) do
        if matchesTargets(groupName, targets) and type(items) == "table" then
            groups[#groups + 1] = {
                name = groupName,
                items = items,
                records = self.bossRecords[groupName] or {},
                killCounts = self.bossKillCounts[groupName] or {},
            }
        end
    end
    table.sort(groups, function(left, right) return lower(left.name) < lower(right.name) end)
    return groups
end

-- Build all boss collection groups
function BossCategories:AllBossDropGroups()
    -- Limit aggregate groups to boss-owned logs
    local targets = {}
    for _, achievement in ipairs(self.achievements) do
        targets[normalizedLogName(achievement.category)] = true
        targets[normalizedLogName(achievement.boss)] = true
    end
    for groupName in pairs(self.bossRecords) do
        targets[normalizedLogName(groupName)] = true
    end
    for groupName in pairs(self.bossKillCounts) do
        targets[normalizedLogName(groupName)] = true
    end

    local groups = {}
    for groupName, items in pairs(self.dropLogs) do
        if type(items) == "table" and matchesTargets(groupName, targets) then
            groups[#groups + 1] = {
                name = groupName,
                items = items,
                records = {},
                killCounts = {},
            }
        end
    end
    table.sort(groups, function(left, right) return lower(left.name) < lower(right.name) end)
    return groups
end

-- Get collection groups for the selected boss
function BossCategories:SelectedDropGroups(state)
    if state.selectedCategoryID == ALL_CATEGORIES_ID then return self:AllBossDropGroups() end
    return self:MatchingDropGroups(
        self:PageCategoryID(state.selectedCategoryID),
        self:CategoryName(state.selectedCategoryID)
    )
end

return BossCategories
