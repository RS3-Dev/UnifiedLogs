-- Skill categories from the wiki's standard experience-boosting outfit table.
local Feature = {
    id = "skilling_outfits",
    label = "Skilling Outfits",
    groups = {
        { name = "Agility" },
        { name = "Archaeology" },
        { name = "Construction" },
        { name = "Cooking" },
        { name = "Crafting" },
        { name = "Divination" },
        { name = "Farming" },
        { name = "Firemaking" },
        { name = "Fishing" },
        { name = "Fletching" },
        { name = "Herblore" },
        { name = "Hunter" },
        { name = "Mining" },
        { name = "Necromancy" },
        { name = "Prayer" },
        { name = "Runecrafting" },
        { name = "Smithing" },
        { name = "Summoning" },
        { name = "Thieving" },
        { name = "Woodcutting" },
    },
    logs = {},
    collection = {
        selectedKey = "selectedSkillingOutfitGroup",
        searchKey = "skillingOutfitSearch",
        sidebarTitle = "SKILLS",
        allLabel = "All",
        searchPlaceholder = "Search skills...",
        emptySearchText = "No skills match.",
        fallbackHeading = "SKILLING OUTFITS",
        showQuantities = false,
    },
}

function Feature.LoadData()
    Feature.logs = {}
    for _, group in ipairs(Feature.groups) do Feature.logs[group.name] = {} end
end

return require("Resources/Shared/collections/collection_feature").Define(Feature)
