-- Read and cache variables requested by mounted views
local GameData = require("Resources/Lib/game_data")

local Progress = {}
Progress.__index = Progress

local EVENT = "unifiedlogs_account_progress"
local BATCH_SIZE = 80

function Progress.new(onComplete)
    return setmetatable({
        onComplete = onComplete,
        values = {},
        resolved = {},
        requested = {},
        queued = {},
        queue = {},
        queueIndex = 1,
        running = false,
    }, Progress)
end

-- Start account progress tracking
function Progress:_Start()
    if self.running or self.queueIndex > #self.queue then return false end
    self.running = true
    Event.Logic.Unsubscribe(EVENT)
    Event.Logic.Subscribe(EVENT, function()
        local last = math.min(#self.queue, self.queueIndex + BATCH_SIZE - 1)
        while self.queueIndex <= last do
            local reference = self.queue[self.queueIndex]
            local value = GameData.TrackingValue(reference)
            self.values[reference] = value
            self.resolved[reference] = true
            self.queued[reference] = nil
            self.queueIndex = self.queueIndex + 1
        end
        if self.queueIndex <= #self.queue then return end

        self.queue = {}
        self.queueIndex = 1
        self.running = false
        Event.Logic.Unsubscribe(EVENT)
        if type(self.onComplete) == "function" then self.onComplete() end
    end)
    return true
end

-- Request current account progress
function Progress:_Request(reference, refresh)
    if type(reference) ~= "string" and type(reference) ~= "number" then return false end
    if reference == "" then return false end
    self.requested[reference] = true
    if refresh then self.resolved[reference] = nil end
    if self.resolved[reference] or self.queued[reference] then return false end
    self.queue[#self.queue + 1] = reference
    self.queued[reference] = true
    self:_Start()
    return true
end

-- Read the current progress value
function Progress:GetValue(reference)
    self:_Request(reference, false)
    return self.values[reference]
end

function Progress:IsCollected(entry, value)
    if value == nil then value = self:GetValue(entry.v) end
    local minimum = tonumber(entry.min) or 1
    if value == true then return minimum <= 1 end
    return type(value) == "number" and value >= minimum
end

-- Refresh variables requested by the mounted feature
function Progress:BeginScope()
    Event.Logic.Unsubscribe(EVENT)
    self.running = false
    self.requested = {}
    self.queue = {}
    self.queueIndex = 1
    self.queued = {}
end

function Progress:Refresh()
    local added = false
    for reference in pairs(self.requested) do
        if self:_Request(reference, true) then added = true end
    end
    return added
end

-- Stop progress
function Progress:Shutdown()
    Event.Logic.Unsubscribe(EVENT)
    self.running = false
    self.queue = {}
    self.queueIndex = 1
    self.queued = {}
end

return Progress
