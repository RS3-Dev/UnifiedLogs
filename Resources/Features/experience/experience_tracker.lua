-- Track live XP gains
local ExperienceHistory = require("Resources/Features/experience/experience_history")
local SkillCatalog = require("Resources/Shared/skills/skill_catalog")
local ExperienceTime = require("Resources/Features/experience/experience_time")
local Identity = require("Resources/Lib/player_identity")

local ExperienceTracker = {}
ExperienceTracker.__index = ExperienceTracker

local VAR_EVENT = "unifiedlogs_xp_tracker_var"
local SKILL_EVENT = "unifiedlogs_xp_tracker_skill"
local GAME_STATE_EVENT = "unifiedlogs_xp_tracker_game_state"
local WARMUP_EVENT = "unifiedlogs_xp_tracker_warmup"
local WARMUP_TICKS = 10 * 50
local GAME_STATE = 30
local MAP_LOADING_STATE = 40
local CHECKPOINT_MINUTES = 5
local CLOCK_OPTIONS_VARP_ID = 3680
local CLOCK_MINUTE_VARP_ID = 11489

-- Check whether the game clock is enabled
local function isClockEnabled()
    if var == nil or var.VarPlayer == nil then return false end
    local ok, value = pcall(function()
        local option = var.VarPlayer.TOPLEVEL_V2_CLOCK_OPTIONS
        return option ~= nil and tonumber(option.value) or nil
    end)
    return ok and value ~= nil and value >= 1 and value <= 3
end

local function readClockMinute()
    if var == nil or var.VarPlayer == nil then return nil end
    local ok, value = pcall(function()
        local clock = var.VarPlayer.CLOCK_TIME_DATE_MINUTES
        return clock ~= nil and tonumber(clock.value) or nil
    end)
    if not ok or value == nil or value <= 0 then return nil end
    return math.floor(value)
end

local function xpValue(value)
    value = tonumber(value)
    if value == nil or value < 0 or value ~= value or value == math.huge then return nil end
    return value
end

function ExperienceTracker.new(onChange)
    return setmetatable({
        history = ExperienceHistory.new(),
        histories = {},
        skillXP = {},
        warmupTicks = WARMUP_TICKS,
        onChange = onChange,
        status = "stopped",
        clockMinute = nil,
        lastFlushAttempt = nil,
        started = false,
    }, ExperienceTracker)
end

-- Retain each character's pending writes under its original owner.
function ExperienceTracker:SyncPlayer()
    local playerID = Identity.Current()
    if self.history.playerID == playerID then return false end
    self.history:Flush()
    if self.history.playerID ~= nil then self.histories[self.history.playerID] = self.history end
    self.history = playerID and self.histories[playerID] or nil
    if self.history == nil then self.history = ExperienceHistory.new() end
    self.clockMinute = nil
    self.lastFlushAttempt = nil
    self.skillXP = {}
    self.status = "stopped"
    self:BeginWarmup()
    return true
end

-- Allow ten seconds of logged-in client logic for initial stats to settle.
function ExperienceTracker:BeginWarmup()
    self.warmupTicks = WARMUP_TICKS
    if not self.started then return end
    Event.Logic.Unsubscribe(WARMUP_EVENT)
    Event.Logic.Subscribe(WARMUP_EVENT, function()
        if not self.started then return end
        self:SyncPlayer()
        if self.history.playerID == nil then return end
        self.warmupTicks = self.warmupTicks - 1
        if self.warmupTicks > 0 then return end
        Event.Logic.Unsubscribe(WARMUP_EVENT)
        self:SeedSkillXP(true)
        self:RefreshClock()
    end)
end

-- Positive client totals establish baselines for skills already loaded.
function ExperienceTracker:SeedSkillXP(refresh)
    for skillID in pairs(SkillCatalog.byID) do
        if refresh or self.skillXP[skillID] == nil then
            local ok, value = pcall(function() return Player.GetXPUncapped(skillID) end)
            value = ok and xpValue(value) or nil
            if value ~= nil and value > 0 then self.skillXP[skillID] = value end
        end
    end
end

-- Notify XP history listeners
function ExperienceTracker:Notify()
    if self.started and type(self.onChange) == "function" then self.onChange() end
end

function ExperienceTracker:SetStatus(status)
    if self.status == status then return end
    self.status = status
    self:Notify()
end

-- Pause tracking while the clock is hidden
function ExperienceTracker:PauseForClock()
    local previous = self.clockMinute
    self.clockMinute = nil
    if previous ~= nil and self.history:IsDirty() then
        self:Flush(previous)
    else
        self:SetStatus("clock_unavailable")
    end
end

function ExperienceTracker:RefreshClock()
    self:SyncPlayer()
    if self.history.playerID == nil then
        self.clockMinute = nil
        self:SetStatus("player_unavailable")
        return nil
    end
    self:SeedSkillXP()
    if not isClockEnabled() then
        self:PauseForClock()
        return nil
    end

    local minute = readClockMinute()
    if minute == nil then
        self:PauseForClock()
        return nil
    end

    local previous = self.clockMinute
    if previous ~= nil and minute < previous and self.history:IsDirty() then self:Flush(previous) end
    self.clockMinute = minute
    if self.status ~= "persistence_error" then
        self:SetStatus(self.warmupTicks > 0 and "warming_up" or "recording")
    end
    if
        self.history:IsDirty()
        and (self.lastFlushAttempt == nil or minute - self.lastFlushAttempt >= CHECKPOINT_MINUTES)
    then
        self:Flush(minute)
    end
    return minute
end

-- Persist pending XP history
function ExperienceTracker:Flush(referenceMinute)
    if not self.history:IsDirty() then return true end
    self.lastFlushAttempt = referenceMinute or self.clockMinute
    local successful = self.history:Flush()
    local clockStatus = self.clockMinute ~= nil and "recording" or "clock_unavailable"
    if self.clockMinute ~= nil and self.warmupTicks > 0 then clockStatus = "warming_up" end
    self:SetStatus(successful and clockStatus or "persistence_error")
    return successful
end

-- Record transmitted skill XP
function ExperienceTracker:OnSkillTransmit(event)
    if not self.started then return end
    local switched = self:SyncPlayer()
    if self.history.playerID == nil then return end
    local skillID = tonumber(event and event.skill)
    local oldXP = xpValue(event and event.oldXP)
    local newXP = xpValue(event and event.newXP)
    if SkillCatalog.byID[skillID] == nil or oldXP == nil or newXP == nil then return end
    if self.warmupTicks > 0 then
        self.skillXP[skillID] = newXP
        return
    end
    local previous = self.skillXP[skillID]
    if previous == nil or switched then
        self.skillXP[skillID] = newXP
        return
    end
    -- Initial stat transmissions and duplicate snapshots establish totals only.
    if oldXP == 0 then
        self.skillXP[skillID] = math.max(previous, newXP)
        return
    end
    if newXP < previous then
        if oldXP == previous then self.skillXP[skillID] = newXP end
        return
    end
    self.skillXP[skillID] = newXP
    local delta = newXP - math.max(previous, oldXP)
    if delta <= 0 then return end
    local minute = self.clockMinute
    if minute == nil then return end
    if self.history:Record(minute, skillID, delta) then self:Notify() end
end

-- Respond to clock setting changes
function ExperienceTracker:OnVarTransmit(event)
    local variable = event and event.var
    local variableID = tonumber(variable and variable.id)
    local configName = variable and variable.configName
    if
        variableID == CLOCK_OPTIONS_VARP_ID
        or variableID == CLOCK_MINUTE_VARP_ID
        or configName == "TOPLEVEL_V2_GENERAL_VARP"
        or configName == "CLOCK_TIME_DATE_MINUTES"
    then
        self:RefreshClock()
    end
end

-- Start live XP tracking
function ExperienceTracker:Start()
    if self.started then return end
    self.started = true
    self.status = "stopped"
    self.clockMinute = nil
    self.skillXP = {}
    self:BeginWarmup()
    Event.VarTransmit.Subscribe(VAR_EVENT, function(event) self:OnVarTransmit(event) end)
    Event.SkillTransmit.Subscribe(SKILL_EVENT, function(event) self:OnSkillTransmit(event) end)
    if Event.GameStateChanged ~= nil then
        Event.GameStateChanged.Subscribe(GAME_STATE_EVENT, function(event)
            -- Ordinary map loading is not a new login session.
            if event ~= nil and (event.newState == MAP_LOADING_STATE
                or event.oldState == MAP_LOADING_STATE and event.newState == GAME_STATE) then return end
            self:Flush(self.clockMinute)
            self.clockMinute = nil
            self.skillXP = {}
            self:BeginWarmup()
            self:RefreshClock()
        end)
    end
    self:RefreshClock()
    self.lastFlushAttempt = self.clockMinute
end

function ExperienceTracker:GetStatus()
    if self.history.playerID == nil then
        return { code = "player_unavailable", message = "XP tracking is paused until your player ID is available. Grant tracking access and log in to resume." }
    end
    if self.status == "persistence_error" then
        return {
            code = self.status,
            message = "Recording in memory; XP history could not be saved.",
        }
    end
    if self.status == "clock_unavailable" then
        return {
            code = self.status,
            message = "XP tracking is paused. Enable the in-game clock to resume.",
        }
    end
    if self.warmupTicks > 0 then
        return { code = "warming_up", message = "XP tracking starts after a 10-second login warm-up." }
    end
    return { code = "recording", message = "" }
end

function ExperienceTracker:GetCurrentDate()
    local minute = self.clockMinute
    return minute ~= nil and ExperienceTime.MinuteToDate(minute) or nil
end

-- Identify the character whose history is displayed.
function ExperienceTracker:GetPlayerID()
    self:SyncPlayer()
    return self.history.playerID
end

-- Confirmation belongs to the character who requested it.
function ExperienceTracker:DeleteHistory(playerID)
    self:SyncPlayer()
    if playerID == nil or self.history.playerID ~= playerID then return false, "player_changed" end
    local successful = self.history:Clear()
    self:Notify()
    if not successful then return false, "storage_error" end
    return true
end

-- Query XP history
function ExperienceTracker:Query(startDate, endDate, segmentCount, dailySkillID)
    self:SyncPlayer()
    return self.history:Query(startDate, endDate, segmentCount, dailySkillID)
end

-- List dates with recorded gains
function ExperienceTracker:GainDates(year, month, skillID)
    self:SyncPlayer()
    return self.history:GainDates(year, month, skillID)
end

-- Stop experience tracker
function ExperienceTracker:Shutdown()
    if not self.started then return end
    self:Flush(self.clockMinute)
    for _, history in pairs(self.histories) do history:Flush() end
    Event.VarTransmit.Unsubscribe(VAR_EVENT)
    Event.Logic.Unsubscribe(WARMUP_EVENT)
    Event.SkillTransmit.Unsubscribe(SKILL_EVENT)
    if Event.GameStateChanged ~= nil then Event.GameStateChanged.Unsubscribe(GAME_STATE_EVENT) end
    self.started = false
end

return ExperienceTracker
