-- Skill pet frames and unlock variables use named client configs.
local Feature = {
    id = "pets",
    label = "Pets",
    groups = { { name = "Skill Pets" }, { name = "Revenant Pets" } },
    logs = {},
    collection = {
        selectedKey = "selectedPetGroup",
        searchKey = "petSearch",
        sidebarTitle = "PETS",
        allLabel = "All",
        searchPlaceholder = "Search pets...",
        emptySearchText = "No pet groups match.",
        fallbackHeading = "PETS",
        showQuantities = false,
    },
}

function Feature.LoadData()
    local entries = {}
    for _, skill in ipairs(require("Resources/Shared/skills/skill_catalog").ordered) do
        local token = skill.name == "Runecrafting" and "RUNECRAFT" or string.upper(skill.name)
        local objectConfig = "SKILLPETS_" .. token
        entries[#entries + 1] = { v = objectConfig .. "_UNLOCKED", objectConfig = objectConfig }
    end
    local revenants = {}
    for _, appearance in ipairs({
        { "IMP", "Imp", 0 },
        { "GOBLIN", "Goblin", 1 },
        { "ICEFIEND", "Icefiend", 2 },
        { "PYREFIEND", "Pyrefiend", 3 },
        { "HOBGOBLIN", "Hobgoblin", 4 },
        { "VAMPYRE", "Vampyre", 5 },
        { "WEREWOLF", "Werewolf", 6 },
        { "CYCLOPS", "Cyclops", 7 },
        { "HELLHOUND", "Hellhound", 8 },
        { "LESSERDEMON", "Lesser demon", 9 },
        { "ORK", "Ork", 10 },
        { "DARKBEAST", "Dark beast", 11 },
        { "DRAGON", "Dragon", 13 },
    }) do
        revenants[#revenants + 1] = {
            v = "DMBH_REWARD_REVENANT_PET_LEVEL",
            min = appearance[3],
            objectConfig = "DMBH_PET_REV_" .. appearance[1],
            label = "Revenant " .. string.lower(appearance[2]),
        }
    end
    Feature.logs = { ["Skill Pets"] = entries, ["Revenant Pets"] = revenants }
end

return require("Resources/Shared/collections/collection_feature").Define(Feature)
