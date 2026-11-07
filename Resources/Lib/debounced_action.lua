-- Run delayed actions on client ticks
local DebouncedAction = {}
DebouncedAction.__index = DebouncedAction

function DebouncedAction.new(eventName, delayTicks, action)
    local self = setmetatable({}, DebouncedAction)
    self.eventName = assert(eventName)
    self.delayTicks = math.max(1, math.floor(tonumber(delayTicks) or 1))
    self.action = assert(action)
    self.pending = false
    self.ticks = 0

    Event.Logic.Unsubscribe(self.eventName)
    Event.Logic.Subscribe(self.eventName, function()
        if not self.pending then return end
        self.ticks = self.ticks + 1
        if self.ticks < self.delayTicks then return end
        self.pending = false
        self.ticks = 0
        self.action()
    end)
    return self
end

-- Restart the debounce timer
function DebouncedAction:Trigger(immediate)
    self.pending = true
    self.ticks = immediate and self.delayTicks or 0
end

function DebouncedAction:Destroy()
    Event.Logic.Unsubscribe(self.eventName)
    self.pending = false
end

return DebouncedAction
