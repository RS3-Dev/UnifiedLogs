-- Build discovery logs from named client configs rather than frozen item lists.
local ClientConfig = require("Resources/Shared/client_config")
local read, named, param = ClientConfig.Read, ClientConfig.Named, ClientConfig.Param
local Catalog = {}

local function identifier(value)
    return tonumber(value) or tonumber(read(value, "id"))
end

local function namespace(name) return read(config, name) end
local function parameter(object, name) return param(object, named(namespace("Param"), name)) end
local function enum(name) return read(named(namespace("Enum"), name), "values") or {} end

function Catalog.BitCollected(entry, value)
    local integer = math.tointeger(tonumber(value) or 0)
    return integer ~= nil and (integer >> entry.bit) & 1 == 1
end

function Catalog.Menaphos(yieldWork)
    local result = { groups = {}, logs = {} }
    for _, category in ipairs({ { "Insects", "INSECT" }, { "Jewels", "GEM" }, { "Cats", "CAT" } }) do
        local entries = {}
        for _, pair in ipairs(enum("MENAPHOS_COLLECTIONS_" .. category[2])) do
            local source = pair[2]
            local variable = read(source, "configName")
            local label = parameter(source, "ELRC_OBJECTIVE_TITLE")
            if type(variable) == "string" and type(label) == "string" then
                local objectID = identifier(parameter(source, "COLLECTION_UNLOCK_OBJ"))
                if objectID ~= nil and objectID < 0 then objectID = nil end
                entries[#entries + 1] = {
                    v = variable, label = label,
                    objectID = objectID,
                    spriteID = identifier(parameter(source, "ELRC_OBJECTIVE_GRAPHIC_UNLOCKED")),
                    hint = parameter(source, "ELRC_OBJECTIVE_HINT"),
                }
            end
            if yieldWork then yieldWork() end
        end
        result.groups[#result.groups + 1] = { name = category[1] }
        result.logs[category[1]] = entries
    end
    return result
end

function Catalog.Totems(yieldWork)
    local result = { groups = {}, logs = {} }
    for _, pair in ipairs(enum("DINO_TOTEM_LIST")) do
        local source = pair[2]
        local configName, label = read(source, "configName"), read(source, "name")
        local token = type(configName) == "string" and string.match(configName, "^DINO_TOTEM_(.+)$")
        if token ~= nil and type(label) == "string" then
            local entries = {}
            for index = 1, 3 do
                local objectID = identifier(parameter(source, "RECIPE_INGREDIENT_TYPE_" .. index))
                if objectID ~= nil and objectID >= 0 then
                    local prefix = "DINO_TOTEM_" .. token .. "_PIECE_" .. index
                    entries[#entries + 1] = {
                        objectID = objectID, v = prefix .. "_OWNED", storedVariable = prefix .. "_STORED",
                        label = label .. " piece " .. tostring(index),
                    }
                end
            end
            result.groups[#result.groups + 1] = { name = label }
            result.logs[label] = entries
        end
        if yieldWork then yieldWork() end
    end
    return result
end

function Catalog.TotemCollected(entry, value, progress)
    local stored = progress:GetValue(entry.storedVariable)
    return value == true or type(value) == "number" and value >= 1
        or stored == true or type(stored) == "number" and stored >= 1
end

function Catalog.Souls(yieldWork)
    local byNPC, entries = {}, {}
    for _, pair in ipairs(enum("SLAYER_POD_MONSTER_STRUCT")) do
        local npcID = identifier(pair[1])
        if npcID ~= nil then byNPC[npcID] = pair[2] end
    end
    local seen = {}
    for _, pair in ipairs(enum("SLAYER_POD_NPC_LIST")) do
        local slot, npcID = identifier(pair[1]), identifier(pair[2])
        local source = npcID ~= nil and byNPC[npcID] or nil
        if slot ~= nil and slot >= 1 and slot % 1 == 0 and source ~= nil and not seen[slot] then
            local label = parameter(source, "SLAYER_POD_NAME")
            local objectID = identifier(parameter(source, "SLAYER_POD_OBJ"))
            if type(label) == "string" and objectID ~= nil and objectID >= 0 then
                local index = slot - 1
                entries[#entries + 1] = {
                    label = label, objectID = objectID, bit = index % 32, slot = slot,
                    v = "SLAYER_CODEX_" .. tostring(math.floor(index / 32) + 1),
                }
                seen[slot] = true
            end
        end
        if yieldWork then yieldWork() end
    end
    table.sort(entries, function(a, b) return a.slot < b.slot end)
    return { groups = { { name = "Souls" } }, logs = { Souls = entries } }
end

return Catalog
