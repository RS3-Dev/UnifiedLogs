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

-- Read achievement completion state
local function completion(value)
    local complete = read(value, "complete")
    if type(complete) == "boolean" then return complete end
    complete = read(value, "isComplete")
    return type(complete) == "boolean" and complete or nil
end

local textFields = {
    "description",
    "requirementDescription",
    "text",
    "label",
    "displayName",
    "name",
    "content",
    "value",
}

local nestedFields = {
    "children",
    "details",
    "entries",
    "items",
    "requirements",
    "subItems",
    "subDescriptions",
    "descriptions",
    "requirementDescriptions",
}

-- Add a unique guide entry
local function addEntry(entries, seenText, text, complete)
    if type(text) ~= "string" or text == "" or seenText[text] then return end
    seenText[text] = true
    entries[#entries + 1] = { text = text, complete = complete }
end

local function collectExposedText(value, entries, seenText)
    local ok, meta = pcall(getmetatable, value)
    if not ok or type(meta) ~= "table" then return end

    local count = 0
    for key in pairs(meta) do
        count = count + 1
        if count > 64 then break end
        if type(key) == "string" and string.sub(key, 1, 2) ~= "__" then
            local normalized = string.lower(key)
            if
                string.find(normalized, "description", 1, true)
                or string.find(normalized, "label", 1, true)
                or string.find(normalized, "text", 1, true)
                or normalized == "name"
            then
                addEntry(entries, seenText, read(value, key), completion(value))
            end
        end
    end
end

local function collectEntries(value, entries, seenText, visited, depth)
    if type(value) == "string" then
        addEntry(entries, seenText, value)
        return
    end
    local kind = type(value)
    if (kind ~= "table" and kind ~= "userdata") or visited[value] or depth > 5 then return end
    visited[value] = true

    local text
    for _, key in ipairs(textFields) do
        local candidate = read(value, key)
        if type(candidate) == "string" and candidate ~= "" then
            text = candidate
            break
        end
    end
    if text ~= nil then addEntry(entries, seenText, text, completion(value)) end
    if kind == "userdata" then collectExposedText(value, entries, seenText) end

    if kind == "table" then
        local count = 0
        for _, key in ipairs(orderedKeys(value)) do
            count = count + 1
            if count > 128 then break end
            collectEntries(value[key], entries, seenText, visited, depth + 1)
        end
    end
    for _, key in ipairs(nestedFields) do
        collectEntries(read(value, key), entries, seenText, visited, depth + 1)
    end
end

-- Build achievement guide entries
function AchievementText.GuideEntries(achievement)
    local entries = {}
    local seenText = {}
    local visited = {}
    collectEntries(read(achievement, "descriptions"), entries, seenText, visited, 0)
    local requirements = read(achievement, "requirements")
    collectEntries(read(requirements, "varTotals"), entries, seenText, visited, 0)
    collectEntries(read(requirements, "varTestBits"), entries, seenText, visited, 0)
    return entries
end

return AchievementText
