-- Named unlock configs and sprite IDs supplied from client discovery.
local ClientConfig = require("Resources/Shared/client_config")
local SkillCatalog = require("Resources/Shared/skills/skill_catalog")
local ABILITIES = {
    Melee = {
        "Bladed Dive", "Greater Barge", "Greater Flurry", "Greater Fury", "Chaos Roar",
    },
    Magic = {
        "Corruption Blast", "Golden Touch", "Greater Chain",
        "Greater Concentrated Blast", "Magma Tempest", "Magma Tempest (Targeted)",
        "Greater Sunshine", "Greater Sonic Wave", "Sanguine offering",
    },
    Ranged = {
        "Corruption Shot", "Greater Ricochet",
        "Greater Death's Swiftness",
    },
    Necromancy = { "Lord of Bones", "Invoke Arisen Flesh" },
    Prayer = {
        "Eclipsed Soul", "Divine Rage", "Ruination", "Desolation", "Malevolence", "Affliction",
    },
    Defence = { "Natural Instinct", "Devotion", "Aggression", "Unsullied", "Divert" },
    Constitution = {
        "Tuska's Wrath", "Sacrifice", "Transfigure",
        "Storm Shards", "Shatter", "Onslaught", "Reprisal", "Slayer's Insight",
        "Kuradal's Favour", "Limitless", "Dragon Slayer", "Demon Slayer", "Undead Slayer",
        "Ingenuity of the Humans", "Vital Drain", "Vampyre Slayer",
    },
}

local function tracked(spriteID, variable) return { spriteID = spriteID, v = variable } end
local function quest(spriteID, name, skill, level)
    return { spriteID = spriteID, quest = name, skill = skill, level = level }
end
local UNLOCKS = {
    ["Bladed Dive"] = tracked(30331, "SWORLDS_UNLOCKED_BLADED_DIVE_ABILITY"),
    ["Greater Barge"] = tracked(840, "DUNGEON_REWARD_SHOP_BARGE_OVERRIDE_UNLOCK"),
    ["Greater Flurry"] = tracked(841, "DUNGEON_REWARD_SHOP_FLURRY_OVERRIDE_UNLOCK"),
    ["Greater Fury"] = tracked(842, "DUNGEON_REWARD_SHOP_FURY_OVERRIDE_UNLOCK"),
    ["Chaos Roar"] = tracked(21238, "COMBATV2_ABILITY_STRENGTH_CHAOS_ROAR_UNLOCKED"),
    ["Corruption Blast"] = tracked(19226, "RAID1_MAGIC_BASIC_UNLOCKED"),
    ["Golden Touch"] = tracked(1520, "MENAPHOS_GOLDEN_TOUCH_ABILITY_UNLOCKED"),
    ["Greater Chain"] = tracked(15038, "COMBATV2_ABILITY_MAGIC_GREATER_CHAIN_UNLOCKED"),
    ["Greater Concentrated Blast"] = tracked(13310, "COMBATV2_ABILITY_MAGIC_GREATER_CONCENTRATED_BLAST_UNLOCKED"),
    ["Magma Tempest"] = tracked(4378, "COMBATV2_ABILITY_MAGIC_MAGMA_TEMPEST_UNLOCKED"),
    ["Magma Tempest (Targeted)"] = tracked(15033, "COMBATV2_ABILITY_MAGIC_MAGMA_TEMPEST_UNLOCKED"),
    ["Greater Sunshine"] = tracked(20184, "COMBATV2_ABILITY_MAGIC_GREATER_SUNSHINE_UNLOCKED"),
    ["Greater Sonic Wave"] = tracked(27432, "COMBATV2_ABILITY_MAGIC_GREATER_SONIC_WAVE_UNLOCKED"),
    ["Sanguine offering"] = tracked(19217, "COMBATV2_ABILITY_MAGIC_SANGUINE_OFFERING_UNLOCKED"),
    ["Corruption Shot"] = tracked(17255, "RAID1_RANGED_BASIC_UNLOCKED"),
    ["Greater Ricochet"] = tracked(15039, "COMBATV2_ABILITY_RANGED_GREATER_RICOCHET_UNLOCKED"),
    ["Greater Death's Swiftness"] = tracked(20186, "COMBATV2_ABILITY_RANGED_GREATER_DEATHS_SWIFTNESS_UNLOCKED"),
    ["Lord of Bones"] = tracked(33147, "COMBATV2_ABILITY_NECROMANCY_INVOKE_LORD_OF_BONES_UNLOCKED"),
    ["Invoke Arisen Flesh"] = tracked(24805, "COMBATV2_ABILITY_NECROMANCY_INVOKE_ARISEN_FLESH_UNLOCKED"),
    ["Eclipsed Soul"] = tracked(34199, "COMBATV2_PRAYER_ECLIPSED_SOUL_UNLOCKED"),
    ["Divine Rage"] = tracked(33970, "COMBATV2_PRAYER_DIVINE_RAGE_UNLOCKED"),
    ["Ruination"] = tracked(30769, "COMBATV2_CURSE_RUINATION_UNLOCKED"),
    ["Desolation"] = tracked(29263, "NEX2_OVERHEAD_ANGUISH_PRAYER_UNLOCKED"),
    ["Malevolence"] = tracked(29262, "NEX2_OVERHEAD_TURMOIL_PRAYER_UNLOCKED"),
    ["Affliction"] = tracked(29264, "NEX2_OVERHEAD_TORMENT_PRAYER_UNLOCKED"),
    ["Natural Instinct"] = quest(16549, "WORLD_WAKES", "Defence", 85),
    ["Devotion"] = quest(21665, "ONE_PIERCING_NOTE"),
    ["Aggression"] = tracked(1516, "SWORLDS_AGGRESSION_ABILITY_UNLOCKED"),
    ["Unsullied"] = tracked(1525, "MENAPHOS_UNSULLIED_ABILITY_UNLOCKED"),
    ["Divert"] = tracked(15035, "COMBATV2_ABILITY_DEFENCE_DIVERT_UNLOCKED"),
    ["Tuska's Wrath"] = tracked(8861, "TUSKA_WRATH_UNLOCKED"),
    ["Sacrifice"] = quest(21666, "ONE_PIERCING_NOTE"),
    ["Transfigure"] = quest(26106, "ONE_PIERCING_NOTE"),
    ["Storm Shards"] = tracked(19227, "RAID1_STORM_SHARDS_UNLOCKED"),
    ["Shatter"] = tracked(19228, "RAID1_STORM_SHARDS_UNLOCKED"),
    ["Onslaught"] = tracked(19289, "RAID1_SURGING_ONSLAUGHT_UNLOCKED"),
    ["Reprisal"] = tracked(799, "GWD2_SOLO_ABILITY_UNLOCKED"),
    ["Slayer's Insight"] = tracked(1523, "SWORLDS_SLAYING_ABILITY_UNLOCKED"),
    ["Kuradal's Favour"] = tracked(1519, "SWORLDS_FEROCIOUS_ABILITY_UNLOCKED"),
    ["Limitless"] = tracked(1522, "MENAPHOS_LIMITLESS_ABILITY_UNLOCKED"),
    ["Dragon Slayer"] = tracked(1518, "DUNGEON_ULTHVEN_DRAGON_SLAYER_ABILITY_UNLOCKED"),
    ["Demon Slayer"] = tracked(1517, "DUNGEON_ULTHVEN_DEMON_SLAYER_ABILITY_UNLOCKED"),
    ["Undead Slayer"] = tracked(1524, "DUNGEON_ULTHVEN_UNDEAD_SLAYER_ABILITY_UNLOCKED"),
    ["Ingenuity of the Humans"] = tracked(1521, "ALCH_ONYX_STRIKE_ABILITY_UNLOCKED"),
    ["Vital Drain"] = tracked(19213, "COMBATV2_ABILITY_CONSTITUTION_VITAL_DRAIN_UNLOCKED"),
    ["Vampyre Slayer"] = tracked(19212, "COMBATV2_ABILITY_CONSTITUTION_VAMPYRE_SLAYER_UNLOCKED"),
}

local function isCollected(entry, value)
    if entry.quest ~= nil then
        local source = ClientConfig.Named(ClientConfig.Read(config, "Quest"), entry.quest)
        if ClientConfig.Read(source, "hasFinishedQuest") ~= true then return false end
        if entry.skillID == nil then return true end
        -- Use permanent XP so a temporary boost cannot mark a reward unlocked.
        local ok, xp = pcall(function() return Player.GetXPUncapped(entry.skillID) end)
        xp = ok and tonumber(xp) or nil
        return xp ~= nil and xp >= entry.requiredXP
    end
    return entry.v ~= nil and (value == true or type(value) == "number" and value >= 1)
end

local Feature = {
    id = "abilities",
    label = "Abilities",
    groups = {
        { name = "Melee" }, { name = "Magic" }, { name = "Ranged" },
        { name = "Necromancy" }, { name = "Prayer" },
        { name = "Defence" }, { name = "Constitution" },
    },
    logs = {},
    collection = {
        selectedKey = "selectedAbilityGroup",
        searchKey = "abilitySearch",
        sidebarTitle = "ABILITIES",
        allLabel = "All",
        searchPlaceholder = "Search abilities...",
        emptySearchText = "No ability categories match.",
        emptyItemsText = "No abilities have been added to this category yet.",
        fallbackHeading = "ABILITIES",
        showQuantities = false,
        isCollected = isCollected,
    },
}

function Feature.LoadData()
    Feature.logs = {}
    for _, group in ipairs(Feature.groups) do
        local entries = {}
        for _, name in ipairs(ABILITIES[group.name] or {}) do
            local source = assert(UNLOCKS[name], "Missing ability mapping: " .. name)
            local entry = { label = name }
            for key, value in pairs(source) do entry[key] = value end
            if entry.skill ~= nil then
                for _, skill in ipairs(SkillCatalog.ordered) do
                    if skill.name == entry.skill then entry.skillID = skill.id; break end
                end
                assert(entry.skillID ~= nil, "Unknown ability skill: " .. entry.skill)
                local points = 0
                for level = 1, entry.level - 1 do
                    points = points + math.floor(level + 300 * 2 ^ (level / 7))
                end
                entry.requiredXP = math.floor(points / 4)
            end
            entries[#entries + 1] = entry
        end
        Feature.logs[group.name] = entries
    end
end

return require("Resources/Shared/collections/collection_feature").Define(Feature)
