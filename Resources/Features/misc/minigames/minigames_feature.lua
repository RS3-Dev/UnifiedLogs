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
    },
    logs = {},
    collection = {
        selectedKey = "selectedMinigameGroup",
        searchKey = "minigameSearch",
        sidebarTitle = "MINIGAMES",
        allLabel = "All",
        searchPlaceholder = "Search minigames...",
        emptySearchText = "No minigames match.",
        fallbackHeading = "MINIGAMES",
    },
}

function Feature.LoadData()
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
end

return require("Resources/Shared/collections/collection_feature").Define(Feature)
