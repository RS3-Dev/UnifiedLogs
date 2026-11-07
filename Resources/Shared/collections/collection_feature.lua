-- Define features that render collection logs
local CollectionFeature = {}

-- Add collection loading and page creation to a feature
function CollectionFeature.Define(feature)
    feature.groups = feature.groups or {}
    feature.collection.groupAll = true

    -- Load groups from a catalogue and logs scoped to the feature
    if feature.LoadData == nil then
        function feature.LoadData(registry, yieldWork)
            feature.groups = feature.catalog().groups
            feature.logs = require("Resources/Shared/collections/collection_catalog").Build({
                scope = feature.id,
                trackingNames = require("Resources/Shared/collections/collection_tracking_names"),
                yieldWork = yieldWork,
            }).logs
            local dropLogs = registry.byID.boss_drops.dropLogs
            for name, entries in pairs(feature.logs) do
                dropLogs[name] = entries
            end
        end
    end

    function feature.CreatePage(parent, context)
        local CollectionLogPage = require("Resources/Shared/collections/collection_log_page")
        return CollectionLogPage.CreateFeature(parent, feature, context)
    end
    return feature
end

return CollectionFeature
