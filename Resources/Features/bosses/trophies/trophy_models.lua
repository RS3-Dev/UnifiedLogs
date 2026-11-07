-- Resolve trophy display models
local TrophyModels = {}

local OBJECT_PREFIX = "CONSTRUCTION_HOUSE_FURNITURE_TROPHY_BOSS_"
local MODEL_PREFIX = "HUMAN_FURNITURE_BOSS_TROPHY_"
local FURNITURE_PREFIX = {
    wall_small = "CONSTRUCTION_HOUSE_FURNITURE_TROPHY_WALL_MOUNT_MAHOGANY_BOSS_",
    wall_large = "CONSTRUCTION_HOUSE_FURNITURE_TROPHY_WALL_MOUNT_LARGE_MAHOGANY_BOSS_",
    plinth_small = "CONSTRUCTION_HOUSE_FURNITURE_TROPHY_PLINTH_SMALL_MAHOGANY_BOSS_",
    plinth_large = "CONSTRUCTION_HOUSE_FURNITURE_TROPHY_PLINTH_LARGE_MAHOGANY_BOSS_",
    plinth_huge = "CONSTRUCTION_HOUSE_FURNITURE_TROPHY_PLINTH_HUGE_MAHOGANY_BOSS_",
}

function TrophyModels.ReadNumber(value, field)
    if value == nil then return nil end
    local ok, result = pcall(function() return value[field] end)
    result = ok and tonumber(result) or nil
    return result ~= nil and result >= 0 and result or nil
end

-- Read a configured model name
local function configuredModelName(entry)
    if type(entry.modelConfig) == "string" and entry.modelConfig ~= "" then
        return entry.modelConfig
    end
    local objectConfig = tostring(entry.objectConfig or "")
    if string.sub(objectConfig, 1, #OBJECT_PREFIX) ~= OBJECT_PREFIX then return nil end
    return MODEL_PREFIX .. string.sub(objectConfig, #OBJECT_PREFIX + 1)
end

-- Resolve a configured model ID
function TrophyModels.ConfiguredModelID(entry)
    if id == nil or id.Model == nil then return nil end
    local modelName = configuredModelName(entry)
    if modelName == nil then return nil end
    local ok, modelID = pcall(function() return id.Model[modelName] end)
    modelID = ok and tonumber(modelID) or nil
    return modelID ~= nil and modelID >= 0 and modelID or nil
end

-- Resolve configured trophy furniture
local function configuredFurniture(entry)
    if config == nil or config.Loc == nil then return nil end
    local configName = entry.furnitureConfig
    if type(configName) ~= "string" or configName == "" then
        local prefix = FURNITURE_PREFIX[entry.mount]
        local objectConfig = tostring(entry.objectConfig or "")
        if prefix == nil or string.sub(objectConfig, 1, #OBJECT_PREFIX) ~= OBJECT_PREFIX then
            return nil
        end
        configName = prefix .. string.sub(objectConfig, #OBJECT_PREFIX + 1)
    end
    local ok, furniture = pcall(function() return config.Loc[configName] end)
    if not ok or furniture == nil or TrophyModels.ReadNumber(furniture, "id") == nil then
        return nil
    end
    return furniture
end

-- Read furniture model IDs
local function furnitureModels(furniture)
    local result = {}
    if furniture == nil then return result end
    local ok = pcall(function()
        for _, shapeType in ipairs(furniture.locShapeTypes or {}) do
            for _, modelID in ipairs(furniture:GetModelIDs(shapeType) or {}) do
                modelID = tonumber(modelID)
                if modelID ~= nil and modelID >= 0 then result[#result + 1] = modelID end
            end
        end
    end)
    return ok and result or {}
end

-- Resolve mounted trophy models
function TrophyModels.MountedPreviewModels(entry)
    local allModels = furnitureModels(configuredFurniture(entry))
    local trophyModelID = TrophyModels.ConfiguredModelID(entry)
    if entry.useFurnitureModel == true and #allModels > 0 then
        trophyModelID = allModels[#allModels]
    end

    if trophyModelID ~= nil then
        local result = {}
        if entry.selfMounted ~= true then
            for _, modelID in ipairs(allModels) do
                if modelID ~= trophyModelID then
                    result[#result + 1] = modelID
                    break
                end
            end
        end
        result[#result + 1] = trophyModelID
        return result
    end

    local result = {}
    for index = 1, math.min(2, #allModels) do
        result[#result + 1] = allModels[index]
    end
    return result
end

return TrophyModels
