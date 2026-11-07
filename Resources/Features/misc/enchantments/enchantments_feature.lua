-- Track permanent enchantment unlocks using named client configs.
local Feature = {
    id = "enchantments",
    label = "Enchantments",
    groups = {
        { name = "Dark Onyx Core" },
        { name = "Demonic Enchantments" },
        { name = "Amascut Enchantments" },
    },
    logs = {},
    collection = {
        selectedKey = "selectedEnchantmentGroup",
        searchKey = "enchantmentSearch",
        sidebarTitle = "ENCHANTMENTS",
        allLabel = "All",
        searchPlaceholder = "Search enchantments...",
        emptySearchText = "No enchantment groups match.",
        emptyItemsText = "No enchantments have been added to this group yet.",
        fallbackHeading = "ENCHANTMENTS",
        showQuantities = false,
    },
}

function Feature.LoadData()
    local entries = {}
    for _, suffix in ipairs({ "GRACE", "LUCK", "PASSAGE" }) do
        local name = "WILDY_EVENTS_REWARDS_ENCHANTMENT_" .. suffix
        entries[#entries + 1] = { v = name, objectConfig = name }
    end
    local amascut = {}
    -- Frame order is independent of the upgrade variable names.
    for _, pair in ipairs({
        { "EGWD_WEN_BOSS_MELEE_WEAPON_HM_NEW", "DARK_SHARDS_OF_LENG_TIER_UNLOCKED" },
        { "RANGED_GHRAZI_CROSSBOW_T95", "MALACHI_TOOTH_CLAW_UNLOCKED" },
        { "MAGIC_DEVOURER_WAND_T95", "SONG_OF_DESTRUCTION_TIER_UNLOCKED" },
        { "NECRO_RASIAL_ARMGUARD_T95", "OMNI_SOULBOUND_TIER_UNLOCKED" },
        { "NECRO_DEVOURER_ARMGUARD_T95", "DEVOURERS_GUARD_TIER_UNLOCKED" },
        { "EGWD_FUL_BOSS_MELEE_WEAPON_NEW", "EK_ZEKKIL_TIER_UNLOCKED" },
        { "MELEE_DEVOURER_HALBERD_T95", "TUMEKENS_LIGHT_TIER_UNLOCKED" },
        { "EGWD_ZAMORAK_BOSS_RANGED_WEAPON_NEW", "BOW_OF_THE_LAST_GUARDIAN_TIER_UNLOCKED" },
        { "EGWD_JAS_BOSS_MAGIC_WEAPON_NEW", "FRACTURED_STAFF_OF_ARMADYL_TIER_UNLOCKED" },
    }) do
        amascut[#amascut + 1] = {
            objectConfig = pair[1],
            v = "COMBATV2_INNATE_MASTERY_STAT_UPGRADE_" .. pair[2],
        }
    end
    local demonic = {}
    for _, pair in ipairs({
        { "REXKINGS_WARRIOR_RING", "RING_CHAMPION" },
        { "REXKINGS_ARCHER_RING", "RING_STALKER" },
        { "REXKINGS_SEER_RING", "RING_CHANNELLER" },
        { "DINO_GAME_REWARD_WEAPON_NEW", "TERRASAUR" },
        { "STALKER_HEXHUNTER_BOW_NEW", "HEXHUNTER" },
        { "ARCH_INQUISITOR_STAFF_NEW", "INQUISITOR" },
        { "ENHANCED_MENAPHOS_SLAYER_GLOVES_NEW", "GLOVES_OF_PASSAGE" },
        { "ENHANCED_FOTG2_GLOVES_RANGE_NEW", "NIGHTMARE_GAUNTLETS" },
        { "ENHANCED_EGWD_JAS_BOSS_MAGIC_GLOVES_NEW", "KERAPAC_GLOVES" },
    }) do
        demonic[#demonic + 1] = {
            objectConfig = pair[1],
            v = "EGWD_ZAMORAK_BOSS_REWARD_ENCHANTMENT_" .. pair[2],
        }
    end
    Feature.logs = {
        ["Dark Onyx Core"] = entries,
        ["Demonic Enchantments"] = demonic,
        ["Amascut Enchantments"] = amascut,
    }
end

return require("Resources/Shared/collections/collection_feature").Define(Feature)
