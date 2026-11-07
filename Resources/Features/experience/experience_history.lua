-- Store and query XP history
local Storage = require("Resources/Lib/storage")
local SkillCatalog = require("Resources/Shared/skills/skill_catalog")
local ExperienceTime = require("Resources/Features/experience/experience_time")
local Identity = require("Resources/Lib/player_identity")

local ExperienceHistory = {}
ExperienceHistory.__index = ExperienceHistory

local PREFIX = "xp_history:v1:"
local BUCKET_MINUTES = 15

-- Count active minutes
local function popcount(value)
    local count = 0
    local remaining = value
    while remaining > 0 do
        if remaining % 2 == 1 then count = count + 1 end
        remaining = math.floor(remaining / 2)
    end
    return count
end

-- Normalize a history cell
local function normalizedCell(value)
    if type(value) ~= "table" then return nil end
    local xp = tonumber(value[1])
    local activity = tonumber(value[2]) or 0
    if xp == nil or xp <= 0 then return nil end
    return { xp = xp, activity = math.max(0, math.floor(activity)) }
end

-- Normalize a history shard
local function normalizedShard(value, monthKey)
    local result = {
        month = monthKey,
        buckets = {},
    }
    if type(value) ~= "table" or type(value.buckets) ~= "table" then return result end
    for bucketKey, bucket in pairs(value.buckets) do
        local bucketMinute = tonumber(bucketKey)
        if bucketMinute ~= nil and type(bucket) == "table" then
            local normalized = {}
            for skillKey, cell in pairs(bucket) do
                local skillID = tonumber(skillKey)
                local nextCell = normalizedCell(cell)
                if skillID ~= nil and SkillCatalog.byID[skillID] ~= nil and nextCell ~= nil then
                    normalized[tostring(skillID)] = nextCell
                end
            end
            if next(normalized) ~= nil then
                result.buckets[tostring(math.floor(bucketMinute))] = normalized
            end
        end
    end
    return result
end

-- Prepare a shard for storage
local function persistedShard(shard)
    local buckets = {}
    for bucketKey, bucket in pairs(shard.buckets) do
        local persistedBucket = {}
        for skillKey, cell in pairs(bucket) do
            persistedBucket[skillKey] = { cell.xp, cell.activity }
        end
        buckets[bucketKey] = persistedBucket
    end
    return {
        month = shard.month,
        buckets = buckets,
    }
end

local function formatActive(minutes)
    local value = math.max(0, math.floor(tonumber(minutes) or 0))
    return tostring(math.floor(value / 60)) .. "h " .. string.format("%02d", value % 60) .. "m"
end

function ExperienceHistory.new()
    return setmetatable({ playerID = Identity.Current(), months = {}, dirty = {}, lastQuery = nil }, ExperienceHistory)
end

function ExperienceHistory:LoadMonth(monthKey)
    if self.months[monthKey] ~= nil then return self.months[monthKey] end
    local key = Identity.Key(self.playerID, PREFIX .. monthKey)
    local saved = key and Storage.ReadStructured(key)
    local shard = normalizedShard(saved, monthKey)
    self.months[monthKey] = shard
    return shard
end

-- Record an XP sample
function ExperienceHistory:Record(minute, skillID, delta)
    if self.playerID == nil or self.playerID ~= Identity.Current() then return false end
    minute = math.floor(tonumber(minute) or 0)
    skillID = math.floor(tonumber(skillID) or -1)
    delta = tonumber(delta) or 0
    if minute <= 0 or delta <= 0 or SkillCatalog.byID[skillID] == nil then return false end

    local bucketMinute = minute - minute % BUCKET_MINUTES
    local monthKey = ExperienceTime.MonthKeyFromMinute(bucketMinute)
    local shard = self:LoadMonth(monthKey)
    local bucketKey = tostring(bucketMinute)
    local skillKey = tostring(skillID)
    local bucket = shard.buckets[bucketKey]
    if bucket == nil then
        bucket = {}
        shard.buckets[bucketKey] = bucket
    end
    local cell = bucket[skillKey]
    if cell == nil then
        cell = { xp = 0, activity = 0 }
        bucket[skillKey] = cell
    end
    cell.xp = cell.xp + delta
    local activityBit = 2 ^ (minute - bucketMinute)
    if math.floor(cell.activity / activityBit) % 2 == 0 then
        cell.activity = cell.activity + activityBit
    end
    self.dirty[monthKey] = true
    self.lastQuery = nil
    return true
end

function ExperienceHistory:IsDirty() return next(self.dirty) ~= nil end

-- Remove this character's saved months and pending samples.
function ExperienceHistory:Clear()
    if self.playerID == nil or self.playerID ~= Identity.Current() then return false end
    local prefix = Identity.Key(self.playerID, PREFIX)
    local keys = Storage.KeysWithPrefix(prefix)
    if keys == nil then return false end
    for _, key in ipairs(keys) do
        if self.playerID ~= Identity.Current() or not Storage.Delete(key) then return false end
        local month = key:sub(#prefix + 1)
        self.months[month], self.dirty[month] = nil, nil
        self.lastQuery = nil
    end
    self.months, self.dirty, self.lastQuery = {}, {}, nil
    return true
end

-- Persist pending XP history
function ExperienceHistory:Flush()
    local successful = true
    for monthKey in pairs(self.dirty) do
        local shard = self.months[monthKey]
        local key = Identity.Key(self.playerID, PREFIX .. monthKey)
        if key ~= nil and shard ~= nil and Storage.WriteStructured(key, persistedShard(shard)) then
            self.dirty[monthKey] = nil
        else
            successful = false
        end
    end
    return successful
end

-- List dates with recorded gains, optionally for one skill
function ExperienceHistory:GainDates(year, month, skillID)
    local monthKey = string.format("%04d-%02d", year, month)
    local shard = self:LoadMonth(monthKey)
    local result = {}
    for bucketKey, bucket in pairs(shard.buckets) do
        local hasGain = false
        if skillID ~= nil then
            local cell = bucket[tostring(skillID)]
            hasGain = cell ~= nil and cell.xp > 0
        else
            for _, cell in pairs(bucket) do
                if cell.xp > 0 then
                    hasGain = true
                    break
                end
            end
        end
        local bucketMinute = tonumber(bucketKey)
        if hasGain then
            result[ExperienceTime.DateKey(ExperienceTime.MinuteToDate(bucketMinute))] = true
        end
    end
    return result
end

-- Query XP history
function ExperienceHistory:Query(startDate, endDate, segmentCount, dailySkillID)
    segmentCount = math.max(1, math.floor(tonumber(segmentCount) or 30))
    dailySkillID = tonumber(dailySkillID)
    if SkillCatalog.byID[dailySkillID] == nil then dailySkillID = nil end
    local queryKey = table.concat({
        ExperienceTime.DateKey(startDate),
        ExperienceTime.DateKey(endDate),
        tostring(segmentCount),
        tostring(dailySkillID or "none"),
    }, ":")
    if self.lastQuery ~= nil and self.lastQuery.key == queryKey then
        return self.lastQuery.value
    end

    local startMinute = ExperienceTime.DateToMinute(startDate)
    local endMinute = ExperienceTime.DateToMinute(ExperienceTime.NextDate(endDate))
    local duration = math.max(1, endMinute - startMinute)
    local result = {
        total = 0,
        series = {},
        skills = {},
        skillByID = {},
    }
    local dailyByDate = dailySkillID ~= nil and {} or nil
    for _, definition in ipairs(SkillCatalog.ordered) do
        local skill = {
            id = definition.id,
            name = definition.name,
            colour = definition.colour,
            total = 0,
            buckets = {},
            daily = {},
        }
        for index = 1, segmentCount do
            skill.buckets[index] = 0
        end
        result.skills[#result.skills + 1] = skill
        result.skillByID[skill.id] = skill
    end

    for _, monthKey in ipairs(ExperienceTime.MonthKeys(startDate, endDate)) do
        local shard = self:LoadMonth(monthKey)
        for bucketKey, bucket in pairs(shard.buckets) do
            local bucketMinute = tonumber(bucketKey)
            if bucketMinute >= startMinute and bucketMinute < endMinute then
                local segment = math.min(
                    segmentCount,
                    math.floor((bucketMinute - startMinute) * segmentCount / duration) + 1
                )
                local dayKey
                for skillKey, cell in pairs(bucket) do
                    local skillID = tonumber(skillKey)
                    local skill = result.skillByID[skillID]
                    local xp = cell.xp
                    skill.total = skill.total + xp
                    skill.buckets[segment] = skill.buckets[segment] + xp
                    result.total = result.total + xp
                    if skillID == dailySkillID then
                        dayKey = dayKey
                            or ExperienceTime.DateKey(ExperienceTime.MinuteToDate(bucketMinute))
                        local daily = dailyByDate[dayKey]
                        if daily == nil then
                            daily = { gain = 0, activeMinutes = 0 }
                            dailyByDate[dayKey] = daily
                        end
                        daily.gain = daily.gain + xp
                        daily.activeMinutes = daily.activeMinutes + popcount(cell.activity)
                    end
                end
            end
        end
    end

    for _, skill in ipairs(result.skills) do
        if skill.total > 0 then result.series[#result.series + 1] = skill end
        if skill.id == dailySkillID then
            local date = { year = startDate.year, month = startDate.month, day = startDate.day }
            local ascending = {}
            while ExperienceTime.DateToMinute(date) < endMinute do
                local daily = dailyByDate[ExperienceTime.DateKey(date)]
                    or { gain = 0, activeMinutes = 0 }
                ascending[#ascending + 1] = {
                    day = date,
                    gain = daily.gain,
                    activeMinutes = daily.activeMinutes,
                    active = formatActive(daily.activeMinutes),
                    rate = daily.activeMinutes > 0 and math.floor(
                        daily.gain * 60 / daily.activeMinutes
                    ) or 0,
                }
                date = ExperienceTime.NextDate(date)
            end
            for index = #ascending, 1, -1 do
                skill.daily[#skill.daily + 1] = ascending[index]
            end
        end
    end
    self.lastQuery = { key = queryKey, value = result }
    return result
end

return ExperienceHistory
