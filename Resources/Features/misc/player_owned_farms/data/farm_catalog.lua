-- Build the farm catalogue
local GameData = require("Resources/Lib/game_data")
local ClientConfig = require("Resources/Shared/client_config")
local read, fromID, configName = ClientConfig.Read, ClientConfig.FromID, ClientConfig.ConfigName

local FarmCatalog = {}

local ENUM_FIRST = 16299
local ENUM_LAST = 16321
local VARIABLE_RANGES = {
    { -41841, -41889 },
    { -45422, -45486 },
    { -60849, -60849 },
}

local VARIABLE_GROUP_ALIASES = {
    VARANUSAUR = "VENOMOUS_DINOSAUR",
    ARACANE_APOTERRASAUR = "ARCANE_APOTERRASAUR",
    SCIMITOPS = "QUAD_SCIMITOPS",
    ASCIATOPS = "QUAD_ASCIATOPS",
    MALLETOPS = "QUAD_MALLETOPS",
}

local ITEM_ORDER = {
    RABBIT = { "BROWN", "WHITE", "CREAM", "SHINY" },
    CHICKEN = { "WHITE", "BROWN", "RED", "OOMLIE", "SHINY" },
    COW = { "BASIC", "STRAWBERRY", "CHOCOLATE", "VANILLA", "SHINY" },
    CHINCHOMPA = {
        "GREY", "CARNIVOROUS", "VOLATILE", "COBALT", "VIRIDIAN",
        "AZURE", "CRIMSON", "CRYSTAL", "SHINY",
    },
    ZYGOMITE = { "MORT_MYRE", "MORCHELLA", "ARC", "DUNG", "SHINY" },
}

local OBJECT_OVERRIDES = {
    POF_COLLECTION_BREED_RABBIT_BROWN = "POF_ANIMAL_RABBIT",
    POF_COLLECTION_BREED_COW_BASIC = "POF_ANIMAL_COW",
    POF_COLLECTION_BREED_CHINCHOMPA_GREY = "POF_ANIMAL_CHINCHOMPA",
    POF_COLLECTION_BREED_SPIDER_SPIRIT = "POF_ANIMAL_SPIDER",
    POF_COLLECTION_BREED_YAK_FREMENNIK = "POF_ANIMAL_YAK",
    POF_COLLECTION_BREED_ZYGOMITE_MORT_MYRE = "POF_ANIMAL_ZYGOMITE",
    POF_COLLECTION_BREED_ZYGOMITE_MORCHELLA = "POF_ANIMAL_ZYGOMITE_ZANARIAN",
    POF_COLLECTION_BREED_DRAGON_GREEN = "POF_ANIMAL_DRAGON",
    POF_COLLECTION_BREED_DRAGON_SHINY = "POF_ANIMAL_DRAGON_ROYAL",
}

local LABEL_OVERRIDES = {
    POF_COLLECTION_BREED_DRAGON_SHINY = "Royal dragon",
}

-- Format an animal group label
local function groupLabel(token)
    token = string.gsub(token, "^ARACANE_", "ARCANE_")
    local words = {}
    for word in string.gmatch(string.lower(token), "[^_]+") do
        words[#words + 1] = word
    end
    local last = words[#words]
    if last == "rex" then
        words[#words] = "rexes"
    elseif last ~= "sheep" and not string.match(last or "", "s$") then
        words[#words] = last .. "s"
    end
    words[1] = string.upper(string.sub(words[1], 1, 1)) .. string.sub(words[1], 2)
    return table.concat(words, " ")
end

-- Map farm ranks to breeds
local function rankMap(groupKey)
    local order = ITEM_ORDER[groupKey]
    if order == nil then return nil end
    local ranks = {}
    for rank, suffix in ipairs(order) do ranks[suffix] = rank end
    return ranks
end

-- Read an animal item suffix
local function itemSuffix(variableName, groupKey)
    local prefix = "POF_COLLECTION_BREED_" .. groupKey .. "_"
    return string.sub(variableName, 1, #prefix) == prefix
            and string.sub(variableName, #prefix + 1)
        or nil
end

local function sortItems(groupKey, items)
    local ranks = rankMap(groupKey)
    table.sort(items, function(left, right)
        if ranks ~= nil then
            local leftRank = ranks[itemSuffix(left.variableName, groupKey)] or math.huge
            local rightRank = ranks[itemSuffix(right.variableName, groupKey)] or math.huge
            if leftRank ~= rightRank then return leftRank < rightRank end
        end
        return left.v > right.v
    end)
end

-- Resolve farm data sources
local function runtimeSources(options)
    local enumSource = options.enumSource
        or (config ~= nil and config.Enum or nil)
    local variableSource = options.variableSource
        or (var ~= nil and var.VarPlayer or nil)
    return enumSource, variableSource
end

-- Build the farm breed catalog
function FarmCatalog.Build(options)
    options = options or {}
    local enumSource, variableSource = runtimeSources(options)
    local enumFirst = options.enumFirst or ENUM_FIRST
    local enumLast = options.enumLast or ENUM_LAST
    local variableRanges = options.variableRanges or VARIABLE_RANGES
    local yieldWork = options.yieldWork
    local groups = {}

    for enumID = enumFirst, enumLast do
        local name = configName(fromID(enumSource, enumID))
        local token = type(name) == "string"
                and string.match(name, "^POF_ANIMAL_(.+)_BREED_OBJS$")
            or nil
        if token ~= nil then
            groups[#groups + 1] = {
                name = groupLabel(token),
                key = VARIABLE_GROUP_ALIASES[token] or token,
                items = {},
            }
        end
        if type(yieldWork) == "function" then yieldWork() end
    end

    for _, range in ipairs(variableRanges) do
        local step = range[1] <= range[2] and 1 or -1
        for variableID = range[1], range[2], step do
            local name = configName(fromID(variableSource, variableID))
            if type(name) == "string" then
                for _, group in ipairs(groups) do
                    local suffix = itemSuffix(name, group.key)
                    if suffix ~= nil then
                        group.items[#group.items + 1] = {
                            v = variableID,
                            variableName = name,
                            objectConfig = OBJECT_OVERRIDES[name]
                                or string.gsub(name, "^POF_COLLECTION_BREED_", "POF_ANIMAL_"),
                            label = LABEL_OVERRIDES[name],
                        }
                        break
                    end
                end
            end
            if type(yieldWork) == "function" then yieldWork() end
        end
    end

    local navigation = { { name = "All", synthetic = true } }
    local logs = { All = {} }
    for _, group in ipairs(groups) do
        sortItems(group.key, group.items)
        navigation[#navigation + 1] = { name = group.name }
        logs[group.name] = group.items
        for _, entry in ipairs(group.items) do logs.All[#logs.All + 1] = entry end
    end
    return { groups = navigation, logs = logs }
end

-- Resolve a farm animal from a variable
local function pofObjectFromVariable(variableName)
    if type(variableName) ~= "string" or config == nil or config.Obj == nil then return nil end
    local candidate = string.gsub(variableName, "^POF_COLLECTION_BREED_", "POF_ANIMAL_")
    return GameData.ConfigEntry(config.Obj, candidate)
end

function FarmCatalog.ResolveObject(_, entry)
    if type(entry.objectConfig) == "string" and entry.objectConfig ~= "" then
        local object = GameData.ConfigEntry(config ~= nil and config.Obj or nil, entry.objectConfig)
        if object ~= nil then return object end
    end
    if entry.objectID ~= nil then return GameData.ObjectFromID(entry.objectID) end
    return pofObjectFromVariable(entry.variableName or entry.v)
end

return FarmCatalog
