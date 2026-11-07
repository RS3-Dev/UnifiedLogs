-- Build the archaeology catalogue
local RelicCategories = require("Resources/Features/archaeology/data/relic_categories")
local ClientConfig = require("Resources/Shared/client_config")
local entry, property, column = ClientConfig.Named, ClientConfig.Read, ClientConfig.Column

local ArchaeologyCatalog = {}

local MYSTERY_SITE_ORDER = {
    "ARCHAEOLOGY_GUILD",
    "ARCH_SITE_KHARIDET",
    "ARCH_SITE_INFERNALSOURCE",
    "ARCH_SITE_EVERLIGHT",
    "ARCH_SITE_STORMGUARD",
    "ARCH_SITE_WARFORGE",
    "ARCH_SITE_ORTHEN",
    "ARCH_SITE_SENNTISTEN",
    "ARCH_SITE_DAEMONHEIM",
    "ARCH_SITE_MOONRISE",
}

local SITE_NAMES = {
    ARCHAEOLOGY_GUILD = "Archaeology Guild",
    ARCH_SITE_WARFORGE = "Warforge!",
}

local LOADOUTS = {
    activeVarBitId = -57206,
    activeVariable = "ARCH_RELIC_LOADOUT",
    powerIconSpriteId = 10318,
    presets = {
        { index = 0, name = "Loadout 1", slotVarBitIds = { -57208, -57209, -57210 } },
        { index = 1, name = "Loadout 2", slotVarBitIds = { -57212, -57213, -57214 } },
        { index = 2, name = "Loadout 3", slotVarBitIds = { -57216, -57217, -57218 } },
        { index = 3, name = "Loadout 4", slotVarBitIds = { -57220, -57221, -57222 } },
    },
}

-- Read config values
local function values(value)
    return property(value, "values") or {}
end

-- Read a value from a key-value pair
local function pairValue(pair)
    return type(pair) == "table" and pair[2] or nil
end

-- Read a runtime config name
local function configName(value)
    local name = property(value, "configName")
    return type(name) == "string" and name or nil
end

-- Classify a relic
local function relicCategory(name)
    local suffix = string.match(name, "^ARCH_RELIC_(.+)$")
    for category, members in pairs(RelicCategories) do
        if suffix ~= nil and members[suffix] then return category end
    end
    return "Other"
end

local function buildRelics(yieldWork)
    local root = entry(config ~= nil and config.Enum or nil, "ARCH_RELIC_LIST")
    local records = {}
    for _, pair in ipairs(values(root)) do
        local row = pairValue(pair)
        local name = configName(row)
        if name ~= nil then
            local object = column(row, 10)[1]
            local variable = entry(var ~= nil and var.VarBit or nil, name .. "_UNLOCKED")
            records[#records + 1] = {
                configName = name,
                name = column(row, 2)[1] or name,
                description = column(row, 3)[1] or "",
                category = relicCategory(name),
                powerCost = tonumber(column(row, 6)[1]) or 0,
                objectId = tonumber(property(object, "id")),
                unlockVarBitId = tonumber(property(variable, "id")),
                unlockVariable = name .. "_UNLOCKED",
                relicId = tonumber(column(row, 1)[1]),
                powerSpriteId = tonumber(column(row, 7)[1]),
            }
        end
        if yieldWork ~= nil then yieldWork() end
    end
    table.sort(records, function(left, right)
        return (left.relicId or math.huge) < (right.relicId or math.huge)
    end)
    return { records = records, loadouts = LOADOUTS }
end

-- Map collections to collectors
local function collectionCollectorMap(yieldWork)
    local root = entry(config ~= nil and config.Enum or nil, "COLLECTOR_BOARD_ARCHAEOLOGY")
    local collectors = {}
    for _, pair in ipairs(values(root)) do
        local collector = pairValue(pair)
        local collectorName = column(collector, 2)[1]
        for _, log in ipairs(column(collector, 8)) do
            for _, collection in ipairs(column(log, 8)) do
                collectors[tostring(property(collection, "id"))] = collectorName
            end
        end
        if yieldWork ~= nil then yieldWork() end
    end
    return collectors
end

local function buildCollectors(yieldWork)
    local collectors = collectionCollectorMap(yieldWork)
    local root = entry(config ~= nil and config.Enum or nil, "ARCH_COLLECTOR_COLLECTION_LIST")
    local records = {}
    for _, pair in ipairs(values(root)) do
        local row = pairValue(pair)
        local name = configName(row)
        -- The tutorial collection has no persistent completion state.
        if name ~= nil and name ~= "COLLECTION_ARCH_TUTORIAL" then
            local items = {}
            for _, object in ipairs(column(row, 14)) do
                items[#items + 1] = {
                    id = tonumber(property(object, "id")),
                    name = property(object, "name") or configName(object) or "Unknown artefact",
                    configName = configName(object),
                }
            end
            records[#records + 1] = {
                collectionName = column(row, 5)[1] or name,
                collector = collectors[tostring(property(row, "id"))] or "Arch Tutorial",
                variableName = name .. "_COMPLETE",
                items = items,
            }
        end
        if yieldWork ~= nil then yieldWork() end
    end
    return { records = records }
end

-- Resolve an archaeology site name
local function siteName(row, name)
    if SITE_NAMES[name] ~= nil then return SITE_NAMES[name] end
    return column(row, 3)[1] or name
end

local function buildMysteries(yieldWork)
    local groupsBySite = { ARCHAEOLOGY_GUILD = { mysteries = {} } }
    local siteRows = {}
    local sites = entry(config ~= nil and config.Enum or nil, "ARCH_SITE_MAP_LIST")
    for _, pair in ipairs(values(sites)) do
        local row = pairValue(pair)
        local name = configName(row)
        if name ~= nil then
            siteRows[tostring(property(row, "id"))] = name
            groupsBySite[name] = { mysteries = {}, row = row }
        end
    end

    local variables, variableSet = {}, {}
    local root = entry(config ~= nil and config.Enum or nil, "ARCH_JOURNAL_MYSTERIES_DATA")
    for _, enumPair in ipairs(values(root)) do
        for _, mysteryPair in ipairs(values(pairValue(enumPair))) do
            local row = pairValue(mysteryPair)
            local bitIndex = tonumber(column(row, 1)[1])
            if row ~= nil and bitIndex ~= nil then
                local site = column(row, 4)[1]
                local siteKey = siteRows[tostring(property(site, "id"))] or "ARCHAEOLOGY_GUILD"
                local variable = "ARCH_MYSTERY_COMPLETE_" .. tostring(math.floor(bitIndex / 32) + 1)
                if not variableSet[variable] then
                    variableSet[variable] = true
                    variables[#variables + 1] = variable
                end
                local group = groupsBySite[siteKey]
                if group == nil then
                    group = { mysteries = {}, row = site }
                    groupsBySite[siteKey] = group
                end
                group.mysteries[#group.mysteries + 1] = {
                    name = column(row, 2)[1] or configName(row) or "Mystery",
                    variable = variable,
                    bit = bitIndex % 32,
                }
            end
            if yieldWork ~= nil then yieldWork() end
        end
    end

    local groups = {}
    for _, siteKey in ipairs(MYSTERY_SITE_ORDER) do
        local group = groupsBySite[siteKey]
        if group ~= nil and #group.mysteries > 0 then
            group.name = siteName(group.row, siteKey)
            group.row = nil
            groups[#groups + 1] = group
        end
    end
    return { variables = variables, groups = groups }
end

function ArchaeologyCatalog.Build(yieldWork)
    if config == nil then
        return { mysteries = { variables = {}, groups = {} }, collectors = { records = {} }, relics = { records = {}, loadouts = LOADOUTS } }
    end
    return {
        mysteries = buildMysteries(yieldWork),
        collectors = buildCollectors(yieldWork),
        relics = buildRelics(yieldWork),
    }
end

return ArchaeologyCatalog
