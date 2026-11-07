-- Define the clue feature
return require("Resources/Shared/collections/collection_feature").Define({
    id = "clues",
    label = "Clues",
    catalog = function() return require("Resources/Features/clues/data/clue_catalog") end,
    collection = {
        selectedKey = "selectedClueGroup",
        searchKey = "clueSearch",
        sidebarTitle = "CLUE TIERS",
        searchPlaceholder = "Search tiers...",
        emptySearchText = "No clue tiers match.",
        emptyItemsText = "No rewards are mapped for this clue tier.",
        fallbackHeading = "CLUES",
        allLabel = "All tiers",
    },
})
