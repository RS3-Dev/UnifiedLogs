-- Load combat achievement state in bounded client ticks
local CombatAchievementStateLoader = {}
local Descriptions = require("Resources/Features/bosses/combat_achievement_descriptions")
local AchievementText = require("Resources/Shared/achievements/achievement_text")
local ClientConfig = require("Resources/Shared/client_config")
CombatAchievementStateLoader.__index = CombatAchievementStateLoader

local EVENT = "unifiedlogs_combat_achievement_state_load"
local BATCH_SIZE = 25
local WATCH_EVENT = "unifiedlogs_combat_achievement_state_watch"
local REFRESH_TICKS = 100

function CombatAchievementStateLoader.new(records, onChanged, options)
    return setmetatable({
        records = records or {},
        onChanged = onChanged,
        index = nil,
        options = options or {}, visibleRecords = {},
    }, CombatAchievementStateLoader)
end

-- The virtualized table supplies its visible rows and overscan buffer.
function CombatAchievementStateLoader:SetVisibleRecords(records)
    self.visibleRecords = records or {}
end

-- Client account state may settle after the first catalogue load.
function CombatAchievementStateLoader:Start()
    self:Refresh()
    local ticks = 0
    Event.Logic.Unsubscribe(WATCH_EVENT)
    Event.Logic.Subscribe(WATCH_EVENT, function()
        if self.index ~= nil then return end
        ticks = ticks + 1
        if ticks < REFRESH_TICKS then return end
        ticks = 0
        self:Refresh()
    end)
end

-- Refresh combat achievement states
function CombatAchievementStateLoader:Refresh()
    if self.index ~= nil then return true end
    if
        #self.records == 0
        or config == nil
        or config.Achievement == nil
    then
        return false
    end

    self.index = 1
    self.readThisPass = {}
    Event.Logic.Unsubscribe(EVENT)
    Event.Logic.Subscribe(EVENT, function()
        if self.options.isVisible and not self.options.isVisible() then return end
        local changed, requested = false, {}
        local function enqueue(record)
            if self.readThisPass[record] then return end
            self.readThisPass[record] = true
            requested[#requested + 1] = record
        end
        if self.options.viewport then
            for _, record in ipairs(self.visibleRecords) do
                if #requested >= 8 then break end
                enqueue(record)
            end
        end
        local background = 0
        local limit = self.options.viewport and 4 or BATCH_SIZE
        while self.index <= #self.records and background < limit do
            local record = self.records[self.index]
            self.index = self.index + 1
            if not self.readThisPass[record] then enqueue(record); background = background + 1 end
        end
        for _, record in ipairs(requested) do
            local achievement
            local value
            -- The live mastery requirement can be readable before the ID lookup.
            for _, candidate in ipairs({
                ClientConfig.Named(config.Achievement, record.configName) or false,
                record.source or false,
            }) do
                local progress = tonumber(ClientConfig.Read(candidate, "progress"))
                if progress ~= nil then
                    achievement, value = candidate, progress
                    break
                end
            end
            if value == nil then
                achievement = ClientConfig.FromID(config.Achievement, record.id)
                value = tonumber(ClientConfig.Read(achievement, "progress"))
            end
            -- Unavailable progress is unknown, not an incomplete achievement.
            if value ~= nil then
                local complete = value == -2 or type(value) == "number" and value >= 10000
                changed = changed or record.progress ~= value or record.complete ~= complete
                record.progress = value
                record.complete = complete
            end
            local descriptionOK, description = pcall(function()
                if achievement == nil then return nil end
                return Descriptions.Get(achievement) or AchievementText.Description(achievement)
            end)
            if descriptionOK and description ~= nil then
                changed = changed or record.description ~= description
                record.description = description
            end
        end
        if self.index > #self.records then
            self.index = nil
            Event.Logic.Unsubscribe(EVENT)
        end
        -- Refresh the view after each batch with the loaded completion states.
        if changed and type(self.onChanged) == "function" then self.onChanged() end
    end)
    return true
end

-- Stop combat achievement state loader
function CombatAchievementStateLoader:Shutdown()
    Event.Logic.Unsubscribe(EVENT)
    Event.Logic.Unsubscribe(WATCH_EVENT)
    self.index = nil
end

return CombatAchievementStateLoader
