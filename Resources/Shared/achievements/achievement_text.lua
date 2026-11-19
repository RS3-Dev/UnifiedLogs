-- Read achievement names and descriptions
local AchievementText = {}

local read = require("Resources/Shared/client_config").Read

-- Sort numeric table keys
local function orderedKeys(source)
    local keys = {}
    for key in pairs(source) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        local leftType, rightType = type(left), type(right)
        if leftType == rightType and (leftType == "number" or leftType == "string") then
            return left < right
        end
        return tostring(left) < tostring(right)
    end)
    return keys
end

-- Read the first available text field
local function firstText(value, visited, depth)
    if type(value) == "string" then return value ~= "" and value or nil end
    if value == nil or depth > 4 then return nil end
    local kind = type(value)
    if kind ~= "table" and kind ~= "userdata" or visited[value] then return nil end
    visited[value] = true

    for _, key in ipairs({ "description", "text", "content", "value" }) do
        local found = firstText(read(value, key), visited, depth + 1)
        if found ~= nil then return found end
    end
    if kind == "table" then
        for _, key in ipairs(orderedKeys(value)) do
            local found = firstText(value[key], visited, depth + 1)
            if found ~= nil then return found end
        end
    end
    return nil
end

-- Read an achievement description
function AchievementText.Description(achievement)
    return firstText(read(achievement, "description"), {}, 0)
        or firstText(read(achievement, "descriptions"), {}, 0)
        or ""
end

-- Prefer native requirement tests; descriptions remain a text-only fallback.
function AchievementText.GuideEntries(achievement, options)
    local entries = require("Resources/Shared/achievements/achievement_guide_rules").Entries(achievement, options)
    if entries then return entries end
    entries = {}
    local seen = {}
    local function collect(value)
        if type(value) == "string" then
            if value ~= "" and not seen[value] then
                seen[value] = true
                entries[#entries + 1] = { text = value }
            end
        elseif type(value) == "table" and not seen[value] then
            seen[value] = true
            local text = read(value, "text") or read(value, "description")
            if type(text) == "string" then collect(text)
            else for _, key in ipairs(orderedKeys(value)) do
                if type(key) == "number" then collect(value[key]) end
            end end
        end
    end
    collect(read(achievement, "descriptions"))
    return entries
end

return AchievementText
