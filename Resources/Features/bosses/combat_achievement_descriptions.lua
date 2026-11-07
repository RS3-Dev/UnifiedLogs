-- Fetch wiki descriptions once and reuse them from PersistentDB
local Json = require("Resources/Lib/json")
local Storage = require("Resources/Lib/storage")
local ClientConfig = require("Resources/Shared/client_config")
local BossPatch = require("Resources/Features/bosses/boss_patch")
local GameData = require("Resources/Lib/game_data")
local Descriptions = {}
local KEY = "unifiedlogs:combat_achievement_descriptions:v1"
local current, loaded, request

local function valid(value)
    if type(value) ~= "table" or value.format ~= 1
        or type(value.descriptions) ~= "table" or next(value.descriptions) == nil
        or type(value.names) ~= "table" then return nil end
    for _, map in ipairs({ value.descriptions, value.names }) do
        for key, text in pairs(map) do
            if type(key) ~= "string" or type(text) ~= "string" or text == "" then return nil end
        end
    end
    return value
end

function Descriptions.Current()
    if not loaded then
        current, loaded = valid(Storage.ReadStructured(KEY)), true
    end
    return current
end

function Descriptions.Get(achievement)
    local data = Descriptions.Current()
    if data == nil then return nil end
    local key = ClientConfig.ConfigName(achievement)
    local template = data.descriptions[key]
        or data.descriptions[data.names[ClientConfig.Read(achievement, "name")]]
    if template == nil then return nil end
    local unresolved = false
    local rendered = string.gsub(template, "{%$([%w_]+)}", function(name)
        local value = GameData.TrackingValue(name)
        if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
            unresolved = true
            return ""
        end
        return tostring(value)
    end)
    if unresolved or string.find(rendered, "{$", 1, true) then return nil end
    return rendered
end

function Descriptions.Fetch(onChanged, onDone, force)
    local function finish(status)
        if onDone ~= nil then onDone(status) end
        return false
    end
    if request ~= nil then return finish("Already checking") end
    if Descriptions.Current() ~= nil and not force then return false end
    if not BossPatch.HasAccess() then return finish("HTTP permission not granted") end
    local baseURL = type(Plugin.urls) == "table" and Plugin.urls.featfinder or nil
    if baseURL == nil or HTTPRequest == nil then return finish("HTTP request unavailable") end
    local pending = HTTPRequest.new(baseURL, "/RS3-Dev/UnifiedLogs/main/Patches/combat-achievements.json")
    request = pending
    pending:Get(function()
        if request ~= pending then return end
        request = nil
        if not pending.successful then return finish("Request failed") end
        if pending.responseCode ~= 200 then return finish("HTTP " .. tostring(pending.responseCode)) end
        local data = valid(Json.Decode(pending.data))
        if data == nil then return finish("Ignored unreadable descriptions") end
        if BossPatch.SameVersion(current, data) then return finish("Up to date") end
        Storage.WriteStructured(KEY, data)
        current = data
        finish("Applied new descriptions")
        onChanged()
    end)
    return true
end

function Descriptions.Shutdown()
    local pending = request
    request = nil
    if pending ~= nil then pcall(function() pending:Cancel() end) end
end

return Descriptions
