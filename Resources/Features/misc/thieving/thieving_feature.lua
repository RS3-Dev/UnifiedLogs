local Feature = { id = "thieving", label = "Thieving", groups = {}, logs = {} }

function Feature.LoadData(_, yieldWork)
    local catalog = require("Resources/Features/misc/thieving/data/heist_catalog")
    local patch = require("Resources/Features/bosses/boss_patch").Current()
    local trackingNames = {}
    for name, names in pairs(require("Resources/Shared/collections/collection_tracking_names")) do
        trackingNames[name] = names
    end
    for name, names in pairs(patch.trackingNames) do
        trackingNames[name] = names
    end
    local objects = {}
    for _, group in ipairs(catalog.groups) do
        objects[group.name] = patch.extraObjectGroups[group.name] or group.objects
    end
    local logs = require("Resources/Shared/collections/collection_catalog").Build({
        scope = "thieving",
        extraObjectGroups = objects,
        trackingNames = trackingNames,
        trackingNameRenames = patch.trackingNameRenames,
        yieldWork = yieldWork,
    }).logs
    -- Existing OTA heist overrides continue to work in their new home.
    local counts = require("Resources/Features/bosses/data/boss_kill_count_catalog").Expand(patch.killCounts)
    local records = require("Resources/Features/bosses/data/boss_record_catalog").Expand(patch.records)
    Feature.groups, Feature.logs = {}, logs
    for _, group in ipairs(catalog.groups) do
        Feature.groups[#Feature.groups + 1] = {
            name = group.name,
            items = logs[group.name] or {},
            killCounts = counts[group.name] or { { label = "Completions", variable = group.completions } },
            records = records[group.name] or {
                { name = group.name, metrics = {
                    { label = "Fastest completion", variable = group.minutes,
                        secondaryVariable = group.seconds, kind = "minutes_seconds" },
                } },
            },
        }
    end
    for _, category in ipairs({
        { name = "Pickpocketing", sections = {
            { name = "Vyrelords and Vyrelady consumers", items = {
                { v = "ITEMLOG_ITEM_VITUR_RING", objectConfig = "VITUR_RING" },
            } },
            { name = "TzHaar-Hur Traders", items = {
                { v = "ITEMLOG_ITEM_BLACKSTONE_ONYX", objectConfig = "BLACKSTONE_ONYX" },
            } },
        } },
        { name = "Chests", sections = {
            { name = "Dwarven mines chest", items = {
                { v = "ITEMLOG_ITEM_DOUBLE_AMMO_MOULD", objectConfig = "DOUBLE_AMMO_MOULD" },
            } },
        } },
    }) do
        Feature.groups[#Feature.groups + 1] = category
        for _, section in ipairs(category.sections) do
            Feature.logs[section.name] = section.items
        end
    end
    if require("Resources/Features/bosses/boss_patch").Current() ~= patch then
        return Feature.LoadData(nil, yieldWork)
    end
end

return Feature
