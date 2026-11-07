-- Define the slayer feature
return require("Resources/Shared/collections/collection_feature").Define({
    id = "slayer",
    label = "Slayer",
    catalog = function() return require("Resources/Features/slayer/data/slayer_region_catalog") end,
    collection = {
        selectedKey = "selectedSlayerGroup",
        searchKey = "slayerSearch",
        sidebarTitle = "SLAYER REGIONS",
        searchPlaceholder = "Search regions...",
        emptySearchText = "No regions match.",
        emptyItemsText = "No items are mapped for this region.",
        fallbackHeading = "SLAYER",
        allLabel = "All regions",
    },
})
