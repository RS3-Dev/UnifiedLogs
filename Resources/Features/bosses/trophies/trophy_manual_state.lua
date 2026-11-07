-- Track manually found trophies
local TrophyManualState = {}

-- Persist found state by stable object config name
function TrophyManualState.Key(entry)
    if type(entry) ~= "table" then return nil end
    local key = entry.objectConfig
    if type(key) ~= "string" or key == "" then return nil end
    return key
end

-- Normalize saved trophy states
function TrophyManualState.Normalize(value)
    local normalized = {}
    if type(value) ~= "table" then return normalized end
    for key, found in pairs(value) do
        if type(key) == "string" and key ~= "" and found == true then
            normalized[key] = true
        end
    end
    return normalized
end

function TrophyManualState.IsFound(value, entry)
    local key = TrophyManualState.Key(entry)
    return key ~= nil and type(value) == "table" and value[key] == true
end

function TrophyManualState.SetFound(value, entry, found)
    local state = type(value) == "table" and value or {}
    local key = TrophyManualState.Key(entry)
    if key == nil then return state, false end
    if found == true then
        state[key] = true
    else
        state[key] = nil
    end
    return state, true
end

-- Count manually found trophies
function TrophyManualState.Count(value, entries)
    local count = 0
    for _, entry in ipairs(entries or {}) do
        if TrophyManualState.IsFound(value, entry) then count = count + 1 end
    end
    return count
end

return TrophyManualState
