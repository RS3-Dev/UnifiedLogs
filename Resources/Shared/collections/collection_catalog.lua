-- Build the collection catalogue
local ClientConfig = require("Resources/Shared/client_config")
local entry, property = ClientConfig.Named, ClientConfig.Read
local column, paramValue = ClientConfig.Column, ClientConfig.Param

local CollectionCatalog = {}

local CLUE_ROWS = {
    "COLLECTION_CLUESCROLL_GENERAL",
    "COLLECTION_CLUESCROLL_EASY",
    "COLLECTION_CLUESCROLL_MEDIUM",
    "COLLECTION_CLUESCROLL_HARD",
    "COLLECTION_CLUESCROLL_ELITE",
    "COLLECTION_CLUESCROLL_MASTER",
}

-- Derived names whose variables still exist but no longer track the item
local RENAMED_TRACKING_NAMES = {
    ITEMLOG_ITEM_EGWD_WEN_BOSS_INGREDIENT_RARE = "ITEMLOG_ITEM_EGWD_WEN_BOSS_INGREDIENT_RARE_NEW",
    ITEMLOG_ITEM_DRAGONFIRE_VISAGE = "ITEMLOG_ITEM_VISAGE",
}

local function normalized(value)
    return string.gsub(string.lower(tostring(value or "")), "[^%w]", "")
end

local function decodeVariable(value)
    local encoded = tonumber(value)
    if encoded == nil or encoded < 0 then return nil end
    local identifier = encoded % 16777216
    if encoded >= 16777216 then return -(identifier + 1) end
    return identifier
end

-- Resolve a variable by name
local function namedVariable(object, renamed)
    local configName = property(object, "configName")
    if type(configName) ~= "string" or configName == "" then return nil end
    local variables = var ~= nil and var.VarPlayer or nil
    local variableName = "ITEMLOG_ITEM_" .. configName
    variableName = renamed[variableName] or variableName
    return entry(variables, variableName) ~= nil and variableName or nil
end

-- Resolve an object's tracking variable
local function objectVariable(object, fallback, renamed)
    local params = config ~= nil and config.Param or nil
    local tracking = entry(params, "COLLECTION_TRACKING_VAR")
    local variableID = decodeVariable(paramValue(object, tracking))
    if variableID ~= nil then return variableID end
    variableID = namedVariable(object, renamed)
    if variableID ~= nil then return variableID end
    if type(fallback) ~= "string" or fallback == "" then return nil end
    return renamed[fallback] or fallback
end

-- Read an object's display name
local function objectName(object)
    local name = property(object, "name")
    if type(name) == "string" and name ~= "" then return name end
    return tostring(property(object, "configName") or "Collection item")
end

-- Add a unique catalog row
local function addRow(result, seen, row, lookup, yieldWork)
    if row == nil then return end
    local rowID = tonumber(property(row, "id"))
    local rowKey = rowID ~= nil and tostring(rowID) or tostring(row)
    if seen[rowKey] then return end

    local names, objects = column(row, 5), column(row, 14)
    local name = names[1]
    if type(name) ~= "string" or name == "" or #objects == 0 then return end
    seen[rowKey] = true

    local fallback = lookup.names[normalized(name)] or {}
    local log = {}
    for index, object in ipairs(objects) do
        local label = objectName(object)
        local trackingVariable = objectVariable(object, fallback[index], lookup.renamed)
        log[index] = {
            v = trackingVariable,
            label = label,
            objectID = tonumber(property(object, "id")),
        }
        if yieldWork ~= nil and index % 16 == 0 then yieldWork() end
    end
    result.logs[name] = log
    if yieldWork ~= nil then yieldWork() end
end

local function addObjects(result, name, objectIDs, lookup, yieldWork)
    local fallback = lookup.names[normalized(name)] or {}
    local log = {}
    for index, objectID in ipairs(objectIDs) do
        local objects = config ~= nil and config.Obj or nil
        local object = ClientConfig.FromID(objects, objectID)
        if object ~= nil then
            local label = objectName(object)
            local trackingVariable = objectVariable(object, fallback[index], lookup.renamed)
            log[#log + 1] = {
                v = trackingVariable,
                label = label,
                objectID = objectID,
            }
        end
    end
    if #log > 0 then result.logs[name] = log end
    if yieldWork ~= nil then yieldWork() end
end

local function addBossRows(result, seen, lookup, yieldWork, options)
    local enums = config ~= nil and config.Enum or nil
    local structs = entry(enums, "BSLAY_STRUCT_ALPHABETISED")
    local collection = entry(config ~= nil and config.Param or nil, "BSLAY_COLLECTION")
    for _, pair in ipairs(property(structs, "values") or {}) do
        local boss = type(pair) == "table" and pair[2] or nil
        addRow(result, seen, paramValue(boss, collection), lookup, yieldWork)
    end
    local structNamespace = config ~= nil and config.Struct or nil
    for _, name in ipairs(options.extraBossStructs or {}) do
        addRow(
            result,
            seen,
            paramValue(entry(structNamespace, name), collection),
            lookup,
            yieldWork
        )
    end
end

local function addSlayerRows(result, seen, lookup, yieldWork)
    local enums = config ~= nil and config.Enum or nil
    local rows = config ~= nil and config.DBRow or nil
    local metadata = entry(enums, "ITEMLOG_SLAYER_ALL_LOGS_META")
    for _, pair in ipairs(property(metadata, "values") or {}) do
        local record = type(pair) == "table" and pair[2] or nil
        local configName = property(record, "configName")
        if type(configName) == "string" then
            addRow(
                result,
                seen,
                entry(rows, string.gsub(configName, "^ITEMLOG_", "COLLECTION_")),
                lookup,
                yieldWork
            )
        end
    end
    addRow(result, seen, entry(rows, "COLLECTION_SLAYER_GENERAL"), lookup, yieldWork)
end

local function addClueRows(result, seen, lookup, yieldWork)
    local rows = config ~= nil and config.DBRow or nil
    for _, name in ipairs(CLUE_ROWS) do
        addRow(result, seen, entry(rows, name), lookup, yieldWork)
    end
end

-- Omit scope to discover every collection source
function CollectionCatalog.Build(options)
    options = options or {}
    local logs, seen = {}, {}
    -- Apply bundled renames, then patched ones over them
    local lookup = { names = {}, renamed = {} }
    for _, renames in ipairs({ RENAMED_TRACKING_NAMES, options.trackingNameRenames or {} }) do
        for from, to in pairs(renames) do
            lookup.renamed[from] = to
        end
    end
    local result = { logs = logs }
    for name, variableNames in pairs(options.trackingNames or {}) do
        lookup.names[normalized(name)] = variableNames
    end
    if config == nil then return result end
    local scope, yieldWork = options.scope, options.yieldWork
    if scope == nil or scope == "bosses" then
        addBossRows(result, seen, lookup, yieldWork, options)
    end
    if scope == nil or scope == "slayer" then
        addSlayerRows(result, seen, lookup, yieldWork)
    end
    if scope == nil or scope == "clues" then
        addClueRows(result, seen, lookup, yieldWork)
    end
    for name, objectIDs in pairs(options.extraObjectGroups or {}) do
        addObjects(result, name, objectIDs, lookup, yieldWork)
    end
    return result
end

return CollectionCatalog
