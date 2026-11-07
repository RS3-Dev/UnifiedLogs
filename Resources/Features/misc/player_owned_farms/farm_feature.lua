-- Define the farm feature
local Feature = {
    id = "pof",
    label = "PoF",
    logs = {},
    collection = {
        selectedKey = "selectedPofGroup",
        searchKey = "pofSearch",
        sidebarTitle = "ANIMAL TYPES",
        searchPlaceholder = "Search animals...",
        emptySearchText = "No animal types match.",
        emptyItemsText = "No breeds are mapped for this animal.",
        fallbackHeading = "PLAYER-OWNED FARMS",
        showQuantities = false,
    },
}

-- Load entries from client configuration
function Feature.LoadData(_, yieldWork)
    local catalog = require("Resources/Features/misc/player_owned_farms/data/farm_catalog")
    local data = catalog.Build({ yieldWork = yieldWork })
    Feature.collection.resolveObject = catalog.ResolveObject
    Feature.groups, Feature.logs = data.groups, data.logs
end

return require("Resources/Shared/collections/collection_feature").Define(Feature)
