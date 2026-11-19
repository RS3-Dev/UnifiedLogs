local Feature = {
    id = "menaphos", label = "Menaphos", groups = {}, logs = {},
    collection = {
        selectedKey = "selectedMenaphosGroup", searchKey = "menaphosSearch", allLabel = "All",
        sidebarTitle = "MENAPHOS JOURNAL", fallbackHeading = "MENAPHOS", showQuantities = false,
        searchPlaceholder = "Search journal entries...", searchItems = true,
        tooltip = function(object, entry)
            return entry.label .. (type(entry.hint) == "string" and "<br>" .. entry.hint or "")
        end,
    },
}
function Feature.LoadData(_, yieldWork)
    local catalog = require("Resources/Shared/collections/discovery_catalog").Menaphos(yieldWork)
    Feature.groups, Feature.logs = catalog.groups, catalog.logs
end
return require("Resources/Shared/collections/collection_feature").Define(Feature)
