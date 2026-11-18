-- Define the misc feature
local Feature = {
    id = "misc",
    label = "Misc",
    modes = { { id = "pof", label = "POF" }, { id = "totems", label = "Totems" } },
}

Feature.dependencies = { "pof", "totems" }
function Feature.CreatePage(parent, context)
    local page = require("Resources/Features/misc/misc_page").new(parent, {
        x = context.x,
        y = context.y,
        width = context.width,
        height = context.height,
        section = Feature,
        state = context.state,
        progress = context.progress,
        deferCollections = context.deferCollections,
        isVisible = context.isVisible,
        saveState = context.saveState,
        thieving = context.registry.byID.thieving,
        totemOptions = require("Resources/Shared/collections/collection_log_page").Options(
            context.registry.byID.totems, context
        ),
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
