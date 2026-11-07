-- Define the misc feature
local Feature = {
    id = "misc",
    label = "Misc",
    modes = {
        { id = "pets", label = "Pets" },
        { id = "thieving", label = "Thieving" },
        -- Disabled until outfit items and unlock mappings are ready.
        -- { id = "skilling_outfits", label = "Skilling Outfits" },
        { id = "minigames", label = "Minigames" },
        { id = "enchantments", label = "Enchantments" },
        { id = "pof", label = "POF" },
    },
}

Feature.dependencies = { "thieving", "pof", "minigames", "pets", "enchantments", "skilling_outfits" }
function Feature.CreatePage(parent, context)
    local page = require("Resources/Features/misc/misc_page").new(parent, {
        x = context.x,
        y = context.y,
        width = context.width,
        height = context.height,
        section = Feature,
        state = context.state,
        progress = context.progress,
        saveState = context.saveState,
        thieving = context.registry.byID.thieving,
        skillingOutfitOptions = require("Resources/Shared/collections/collection_log_page").Options(
            context.registry.byID.skilling_outfits,
            context
        ),
        pofOptions = require("Resources/Shared/collections/collection_log_page").Options(
            context.registry.byID.pof,
            context
        ),
        minigameOptions = require("Resources/Shared/collections/collection_log_page").Options(
            context.registry.byID.minigames,
            context
        ),
        petOptions = require("Resources/Shared/collections/collection_log_page").Options(
            context.registry.byID.pets,
            context
        ),
        enchantmentOptions = require("Resources/Shared/collections/collection_log_page").Options(
            context.registry.byID.enchantments,
            context
        ),
    })
    return page
end

return Feature
