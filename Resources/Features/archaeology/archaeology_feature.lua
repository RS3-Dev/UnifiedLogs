-- Define the archaeology feature
local mysteries = { variables = {}, groups = {} }
local collectors = { records = {} }
local relics = { records = {} }
local loadouts = { records = {}, loadouts = nil }
local other = {
    groups = { { name = "Tetracompass" } },
    logs = {
        Tetracompass = {
            { v = "ARCH_RESTORATION_TETRACOMPASS", objectConfig = "ARCH_TETRACOMPASS_NEW", label = "Tetracompass" },
        },
    },
    collection = {
        selectedKey = "selectedArchaeologyOtherGroup",
        searchKey = "archaeologyOtherSearch",
        sidebarTitle = "OTHER",
        groupAll = true,
        allLabel = "All",
        searchPlaceholder = "Search collections...",
        emptySearchText = "No collections match.",
        fallbackHeading = "OTHER",
    },
}

local Feature = {
    id = "archaeology",
    label = "Archaeology",
    modes = {
        {
            id = "mysteries",
            label = "Mysteries",
            data = mysteries,
        },
        {
            id = "collectors",
            label = "Collectors",
            data = collectors,
        },
        {
            id = "relics",
            label = "Relics",
            data = relics,
        },
        {
            id = "loadouts",
            label = "Loadouts",
            data = loadouts,
        },
        { id = "other", label = "Other", data = other },
    },
}

function Feature.LoadData(_, yieldWork)
    local data = require("Resources/Features/archaeology/data/archaeology_catalog").Build(yieldWork)
    Feature.modes[1].data = data.mysteries
    Feature.modes[2].data = data.collectors
    Feature.modes[3].data = data.relics
    Feature.modes[4].data = { records = data.relics.records, loadouts = data.relics.loadouts }
end

function Feature.CreatePage(parent, context)
    return require("Resources/Features/archaeology/archaeology_page").new(parent, {
        x = context.x,
        y = context.y,
        width = context.width,
        height = context.height,
        section = Feature,
        state = context.state,
        saveState = context.saveState,
        otherOptions = require("Resources/Shared/collections/collection_log_page").Options(other, context),
    })
end

return Feature
