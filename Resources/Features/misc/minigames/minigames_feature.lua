-- Define minigame reward collections.
local Feature = {
    id = "minigames",
    label = "Minigames",
    groups = {
        { name = "Hero Items" },
        { name = "Big Game Hunter" },
        { name = "Dungeoneering" },
        { name = "Fenmoor Totems" },
        { name = "Forgotten Paintings" },
        { name = "Menaphos" },
    },
    logs = {},
    dependencies = { "menaphos" },
    collection = {
        selectedKey = "selectedMinigameGroup",
        searchKey = "minigameSearch",
        sidebarTitle = "MINIGAMES",
        allLabel = "All",
        searchPlaceholder = "Search minigames...",
        emptySearchText = "No minigames match.",
        fallbackHeading = "MINIGAMES",
        searchItems = true,
        tooltip = function(object, entry)
            if entry.hint then
                return entry.label .. "<br>" .. entry.hint
            end
            return require("Resources/Lib/game_data").CollectionTooltip(object, entry)
        end,
    },
}

function Feature.LoadData(registry)
    local entries = {}
    for piece = 3, 1, -1 do
        entries[#entries + 1] = {
            v = "DINO_GAME_REWARD_WEAPON_PIECE_" .. piece .. "_COUNT",
            objectConfig = "DINO_GAME_REWARD_WEAPON_PART_" .. piece,
        }
    end
    local paintings = {}
    for piece = 1, 5 do
        paintings[#paintings + 1] = {
            v = "ITEMLOG_ITEM_HAVENHYTHE_HERO_PAINTING_PIECE_" .. piece,
            objectConfig = "HAVENHYTHE_HERO_PAINTING_PIECE_" .. piece,
        }
    end
    Feature.logs = {
        ["Hero Items"] = {
            { v = "ITEMLOG_ITEM_HERO_HATCHET", objectConfig = "HERO_HATCHET" },
            { v = "dsf_hero_island_rod_investigated", objectConfig = "DSF_HERO_ROD" },
        },
        ["Big Game Hunter"] = entries,
        Dungeoneering = {
            { v = "ITEMLOG_ITEM_RAND_WARPED_STONE", objectConfig = "RAND_WARPED_STONE" },
        },
        ["Fenmoor Totems"] = {
            { v = "ITEMLOG_ITEM_FENMOOR_FLETCHING_KNIFE", objectConfig = "FENMOOR_FLETCHING_KNIFE" },
            { v = "ITEMLOG_ITEM_FENMOOR_WOODCUTTING_TORCH", objectConfig = "FENMOOR_WOODCUTTING_TORCH" },
        },
        ["Forgotten Paintings"] = paintings,
    }
    local journal = registry and registry.byID.menaphos
        or require("Resources/Shared/collections/discovery_catalog").Menaphos()
    local entries = {}
    for _, group in ipairs(journal.groups) do
        for _, entry in ipairs(journal.logs[group.name] or {}) do entries[#entries + 1] = entry end
    end
    Feature.logs.Menaphos = entries
end

return require("Resources/Shared/collections/collection_feature").Define(Feature)
