-- Resolve sprite names before numeric fallbacks
local SkillIcons = {}

local FALLBACK_IDS = {
    [0] = 4588,
    [1] = 6895,
    [2] = 6917,
    [3] = 4589,
    [4] = 6912,
    [5] = 6911,
    [6] = 6908,
    [7] = 4591,
    [8] = 6920,
    [9] = 6904,
    [10] = 6903,
    [11] = 6902,
    [12] = 4592,
    [13] = 6916,
    [14] = 6909,
    [15] = 6905,
    [16] = 4586,
    [17] = 6919,
    [18] = 6915,
    [19] = 6901,
    [20] = 6914,
    [21] = 6906,
    [22] = 4590,
    [23] = 6918,
    [24] = 6899,
    [25] = 6896,
    [26] = 6907,
    [27] = 4587,
    [28] = 6910,
}

local NAMES = {
    [0] = "STATICONS_0", -- Attack
    [1] = "STATICONS_2", -- Defence
    [2] = "STATICONS_1", -- Strength
    [3] = "STATICONS_6", -- Constitution
    [4] = "STATICONS_3", -- Ranged
    [5] = "STATICONS_4", -- Prayer
    [6] = "STATICONS_5", -- Magic
    [7] = "STATICONS_15", -- Cooking
    [8] = "STATICONS_17", -- Woodcutting
    [9] = "STATICONS_11", -- Fletching
    [10] = "STATICONS_14", -- Fishing
    [11] = "STATICONS_16", -- Firemaking
    [12] = "STATICONS_10", -- Crafting
    [13] = "STATICONS_13", -- Smithing
    [14] = "STATICONS_12", -- Mining
    [15] = "STATICONS_8", -- Herblore
    [16] = "STATICONS_7", -- Agility
    [17] = "STATICONS_9", -- Thieving
    [18] = "STATICONS2_1", -- Slayer
    [19] = "STATICONS2_2", -- Farming
    [20] = "STATICONS2_0", -- Runecrafting
    [21] = "STATICONS2_5", -- Hunter
    [22] = "STATICONS2_6", -- Construction
    [23] = "STATICONS2_7", -- Summoning
    [24] = "STATICONS2_13", -- Dungeoneering
    [25] = "STATICONS2_14", -- Divination
    [26] = "SKILL_ICON_INVENTION_25PX_0", -- Invention
    [27] = "SKILL_ICON_ARCHAEOLOGY_25PX_0", -- Archaeology
    [28] = "SKILL_ICON_NECROMANCY_25PX_0", -- Necromancy
}

-- Resolve the skill sprite ID
function SkillIcons.SpriteID(skillID)
    local name = NAMES[skillID]
    if name ~= nil and id ~= nil and id.Sprite ~= nil then
        local ok, value = pcall(function() return id.Sprite[name] end)
        if ok and tonumber(value) ~= nil then return tonumber(value) end
    end
    return FALLBACK_IDS[skillID]
end

-- Read the player's current level
function SkillIcons.PlayerLevel(skillID)
    if Player == nil or Player.GetLevelGameplay == nil then return nil end
    local ok, level = pcall(function() return Player.GetLevelGameplay(skillID) end)
    return ok and tonumber(level) or nil
end

return SkillIcons
