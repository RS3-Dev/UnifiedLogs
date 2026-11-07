-- Control trophy preview rotation
local TrophyRotation = {}
TrophyRotation.__index = TrophyRotation

local EVENT = "unifiedlogs_trophy_auto_rotate"
local CENTRE_YAW = -90
local RANGE = 50
local MIN_YAW = CENTRE_YAW - RANGE
local MAX_YAW = CENTRE_YAW + RANGE
local STEP = 0.5

-- Normalize an angle
local function normalizedDegrees(value)
    value = tonumber(value) or 0
    while value > 180 do
        value = value - 360
    end
    while value < -180 do
        value = value + 360
    end
    return value
end

function TrophyRotation.new(host)
    return setmetatable({
        host = host,
        enabled = false,
        yaw = MIN_YAW,
        direction = 1,
    }, TrophyRotation)
end

function TrophyRotation:IsEnabled() return self.enabled end

-- Calculate the displayed trophy yaw
function TrophyRotation:DisplayYaw(fallback) return self.enabled and self.yaw or fallback end

-- Read the rotation mode
function TrophyRotation:Mode()
    local host = self.host
    local entry = host.selectedIndex ~= nil and host.entries[host.selectedIndex] or nil
    if entry ~= nil and entry.autoRotationMode ~= nil then
        return entry.autoRotationMode == "continuous" and "continuous" or "swing"
    end
    local mount = entry ~= nil and tostring(entry.mount or "") or ""
    return string.sub(mount, 1, 7) == "plinth_" and "continuous" or "swing"
end

function TrophyRotation:Reset()
    self.yaw = CENTRE_YAW
    self.direction = 1
end

function TrophyRotation:SetEnabled(enabled)
    enabled = enabled == true
    Event.Logic.Unsubscribe(EVENT)
    self.enabled = enabled

    local host = self.host
    if
        host.autoRotateToggle ~= nil
        and host.autoRotateToggle:IsSelected("autoRotate") ~= enabled
    then
        host.autoRotateToggle:SetSelected("autoRotate", enabled, false)
    end

    if not enabled then
        if host.selectedIndex ~= nil then host:ApplyModelTransform(host.selectedIndex) end
        return
    end

    self:Reset()
    if host.selectedIndex ~= nil then host:ApplyModelTransform(host.selectedIndex) end
    Event.Logic.Subscribe(EVENT, function()
        if host.root == nil or self.enabled ~= true then
            Event.Logic.Unsubscribe(EVENT)
            return
        end
        -- Skip camera rebuilds while the logs window is closed
        local isVisible = host.options.isVisible
        if host.selectedIndex == nil or isVisible ~= nil and not isVisible() then return end

        if self:Mode() == "continuous" then
            self.yaw = normalizedDegrees(self.yaw + STEP)
        else
            self.yaw = self.yaw + STEP * self.direction
            if self.yaw >= MAX_YAW then
                self.yaw = MAX_YAW
                self.direction = -1
            elseif self.yaw <= MIN_YAW then
                self.yaw = MIN_YAW
                self.direction = 1
            end
        end
        host:ApplyModelTransform(host.selectedIndex)
    end)
end

function TrophyRotation:Destroy()
    Event.Logic.Unsubscribe(EVENT)
    self.enabled = false
    self.host = nil
end

return TrophyRotation
