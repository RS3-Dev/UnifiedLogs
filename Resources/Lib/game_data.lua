-- Read account state and resolve known client configs
local GameData = {}
local ClientConfig = require("Resources/Shared/client_config")

GameData.ConfigEntry = ClientConfig.Named

-- Read a tracked client value
function GameData.TrackingValue(variableName)
    if type(variableName) == "number" then return GameData.VariableValueByID(variableName) end
    if var == nil or type(variableName) ~= "string" then return nil end
    for _, namespaceName in ipairs({
        "VarPlayer",
        "VarBit",
        "Varbit",
        "VarGlobal",
        "VarClient",
    }) do
        local namespace = GameData.ConfigEntry(var, namespaceName)
        local variable = GameData.ConfigEntry(namespace, variableName)
        if variable ~= nil then
            local ok, value = pcall(function() return variable.value end)
            if ok and value ~= nil then return value end
        end
    end
    return nil
end

-- Read verified VarBits from the VarPlayer namespace
function GameData.VariableValueByID(variableID)
    local ok, value = pcall(function()
        local variable = var.VarPlayer.FromID(tonumber(variableID))
        return variable ~= nil and variable.value or nil
    end)
    return ok and value or nil
end

-- Resolve an object by ID
function GameData.ObjectFromID(objectID)
    return ClientConfig.FromID(config ~= nil and config.Obj or nil, objectID)
end

-- Resolve the skill sprite ID
function GameData.SpriteID(spriteID, spriteName)
    local numeric = tonumber(spriteID)
    if numeric ~= nil and numeric >= 0 then return numeric end
    -- Resolve numeric and config-backed sprite entries
    local roots = {}
    if config ~= nil then roots[#roots + 1] = config end
    if id ~= nil then roots[#roots + 1] = id end
    for _, root in ipairs(roots) do
        local sprites = root ~= nil and GameData.ConfigEntry(root, "Sprite") or nil
        local value = GameData.ConfigEntry(sprites, spriteName)
        numeric = tonumber(value)
        if numeric == nil and value ~= nil then
            local ok, objectID = pcall(function() return value.id end)
            if ok then numeric = tonumber(objectID) end
        end
        if numeric ~= nil and numeric >= 0 then return numeric end
    end
    return nil
end

-- Resolve an item using its collection descriptor
function GameData.CollectionObject(_, entry)
    if type(entry.objectConfig) == "string" and entry.objectConfig ~= "" then
        local object = GameData.ConfigEntry(config ~= nil and config.Obj or nil, entry.objectConfig)
        if object ~= nil then return object end
    end
    -- Use numeric object IDs when no config name resolves
    return GameData.ObjectFromID(entry.objectID)
end

-- Prefer the descriptor label, then the client object name
function GameData.CollectionTooltip(object, entry)
    if type(entry.label) == "string" and entry.label ~= "" then return entry.label end
    if object ~= nil then
        local ok, name = pcall(function() return object.name end)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return "Collection item"
end

function GameData.MysteryBitIsSet(value, bitIndex)
    value = tonumber(value)
    bitIndex = tonumber(bitIndex)
    if value == nil or bitIndex == nil then return false end
    if value < 0 then value = value + 4294967296 end
    return math.floor(value / (2 ^ bitIndex)) % 2 == 1
end

return GameData
