local Feature = {
    id = "totems", label = "Totems", groups = {}, logs = {},
    collection = {
        selectedKey = "selectedTotemGroup", searchKey = "totemSearch", allLabel = "All",
        sidebarTitle = "ANACHRONIA TOTEMS", fallbackHeading = "TOTEMS", showQuantities = false,
        searchPlaceholder = "Search totems...", searchItems = true,
        isCollected = function(entry, value, progress)
            return require("Resources/Shared/collections/discovery_catalog").TotemCollected(entry, value, progress)
        end,
    },
}
function Feature.LoadData(_, yieldWork)
    local catalog = require("Resources/Shared/collections/discovery_catalog").Totems(yieldWork)
    Feature.groups, Feature.logs = catalog.groups, catalog.logs
end
return require("Resources/Shared/collections/collection_feature").Define(Feature)
