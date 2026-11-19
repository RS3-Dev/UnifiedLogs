-- Show Slayer drops and codex souls in one sidebar.
local CollectionLogPage = require("Resources/Shared/collections/collection_log_page")
local SlayerPage = {}

function SlayerPage.new(parent, options)
    local drops, souls = options.dropOptions, options.soulOptions
    local merged = {}
    for key, value in pairs(drops) do merged[key] = value end
    merged.groups = { { name = "Souls", synthetic = true, beforeAggregate = true } }
    for _, group in ipairs(drops.groups) do merged.groups[#merged.groups + 1] = group end
    merged.logs = {}
    for name, entries in pairs(drops.logs) do merged.logs[name] = entries end
    merged.logs.Souls = {}
    for _, source in ipairs(souls.logs.Souls or {}) do
        local entry = {}
        for key, value in pairs(source) do entry[key] = value end
        entry.showQuantities = false
        merged.logs.Souls[#merged.logs.Souls + 1] = entry
    end
    if options.petOptions then
        merged.groups[#merged.groups + 1] = { name = "Revenant Pets", synthetic = true }
        merged.logs["Revenant Pets"] = {}
        for _, source in ipairs(options.petOptions.logs["Revenant Pets"] or {}) do
            local entry = {}
            for key, value in pairs(source) do entry[key] = value end
            entry.showQuantities = false
            merged.logs["Revenant Pets"][#merged.logs["Revenant Pets"] + 1] = entry
        end
    end
    merged.x, merged.y, merged.width, merged.height = 0, 0, options.width, options.height
    merged.sidebarTitle, merged.searchPlaceholder = "SLAYER", "Search Slayer..."
    merged.groupAll, merged.allLabel, merged.searchItems = true, drops.allLabel or "All regions", true
    merged.selected, merged.search = options.state.selectedSlayerGroup, options.state.slayerSearch
    merged.resolveObject, merged.tooltip = drops.resolveObject or souls.resolveObject, drops.tooltip or souls.tooltip
    merged.isCollected = function(entry, value)
        if entry.v == "DMBH_REWARD_REVENANT_PET_LEVEL" then return options.petOptions.isCollected(entry, value) end
        if entry.bit ~= nil then return souls.isCollected(entry, value) end
        return drops.isCollected(entry, value)
    end
    merged.onStateChange = function(selected, search, persist)
        options.state.selectedSlayerGroup, options.state.slayerSearch = selected, search
        if persist ~= false then options.saveState() end
    end
    local view = CollectionLogPage.new(parent, merged)
    options.state.selectedSlayerGroup = view.selected
    return view
end

return SlayerPage
