local Feature = {
    id = "slayer_souls", label = "Slayer Codex", groups = {}, logs = {},
    collection = {
        selectedKey = "selectedSoulGroup", searchKey = "soulSearch", groupAll = false,
        sidebarTitle = "SLAYER CODEX", fallbackHeading = "SOULS", showQuantities = false,
        searchPlaceholder = "Search souls...", searchItems = true,
        isCollected = function(entry, value)
            return require("Resources/Shared/collections/discovery_catalog").BitCollected(entry, value)
        end,
    },
}
function Feature.LoadData(_, yieldWork)
    local catalog = require("Resources/Shared/collections/discovery_catalog").Souls(yieldWork)
    Feature.groups, Feature.logs = catalog.groups, catalog.logs
end
return require("Resources/Shared/collections/collection_feature").Define(Feature)
