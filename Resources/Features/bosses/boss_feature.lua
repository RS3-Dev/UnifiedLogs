-- Define the boss feature
local Feature = {
    id = "bosses",
    label = "PVM",
    modes = {
        { id = 2, label = "Drops" },
        { id = 1, label = "Combat Achievements" },
        { id = 3, label = "POH" },
        { id = 4, label = "Slayer" },
        { id = 5, label = "Abilities" },
    },
}

Feature.providers = {
    {
        id = "boss_drops",
        dropLogs = {},
        records = {},
        killCounts = {},
    },
    {
        id = "combat_achievements",
        records = {},
    },
    {
        id = "poh",
        logs = { Trophies = {} },
    },
}
Feature.dependencies = { "slayer", "abilities" }

-- Copy bundled entries, then let patched ones replace them
local function withPatch(bundled, patched)
    local result = {}
    for _, source in ipairs({ bundled, patched }) do
        for key, value in pairs(source) do
            result[key] = value
        end
    end
    return result
end

function Feature.LoadData(registry, yieldWork)
    local drops = registry.byID.boss_drops
    local BossPatch = require("Resources/Features/bosses/boss_patch")
    local patch = BossPatch.Current()
    local sources = require("Resources/Features/bosses/data/drop_log_sources")
    local heists = require("Resources/Features/misc/thieving/data/heist_catalog").byName
    local extraBossStructs = { table.unpack(sources.extraBossStructs) }
    for _, name in ipairs(patch.extraBossStructs) do
        extraBossStructs[#extraBossStructs + 1] = name
    end
    local collection = require("Resources/Shared/collections/collection_catalog").Build({
        scope = "bosses",
        yieldWork = yieldWork,
        trackingNames = withPatch(sources.trackingNames, patch.trackingNames),
        extraBossStructs = extraBossStructs,
        extraObjectGroups = withPatch(sources.extraObjectGroups, patch.extraObjectGroups),
        trackingNameRenames = patch.trackingNameRenames,
    })
    local slayer = registry.byID.slayer
    for name, entries in pairs(collection.logs) do
        if heists[name] == nil then drops.dropLogs[name] = entries end
    end
    for name, entries in pairs(slayer.logs) do
        if heists[name] == nil then drops.dropLogs[name] = entries end
    end
    local records = require("Resources/Features/bosses/data/boss_record_catalog")
    -- Expand keeps groups already present, so patched groups go first
    drops.records = records.Expand(records.groups, records.Expand(patch.records))
    drops.tickSeconds = records.tickSeconds
    local killCounts = require("Resources/Features/bosses/data/boss_kill_count_catalog")
    drops.killCounts = killCounts.Expand(killCounts.groups, killCounts.Expand(patch.killCounts))
    for name in pairs(heists) do
        drops.dropLogs[name] = nil
        drops.records[name] = nil
        drops.killCounts[name] = nil
    end
    require("Resources/Features/bosses/boss_categories").Extend(patch.aliases, patch.dropOnly)
    registry.byID.poh.logs.Trophies = require("Resources/Features/bosses/trophies/data/trophy_catalog")
    local ok, achievements =
        pcall(require("Resources/Features/bosses/data/combat_achievement_catalog").Build, yieldWork)
    if ok then
        local destination = registry.byID.combat_achievements.records
        for i = #destination, 1, -1 do
            destination[i] = nil
        end
        for _, record in ipairs(achievements) do
            destination[#destination + 1] = record
        end
    end
    -- A patch that arrived mid-load is applied by loading again
    if BossPatch.Current() ~= patch then return Feature.LoadData(registry, yieldWork) end
    if not ok then
        return "unifiedlogs could not build combat achievements: " .. tostring(achievements)
    end
end

function Feature.CreatePage(parent, context)
    local registry = context.registry
    local drops = registry.byID.boss_drops
    return require("Resources/Features/bosses/boss_page").new(parent, {
        x = context.x,
        y = context.y,
        width = context.width,
        height = context.height,
        windowParent = context.windowParent,
        isVisible = context.isVisible,
        section = Feature,
        achievements = registry.byID.combat_achievements.records,
        dropLogs = drops.dropLogs,
        bossRecords = drops.records,
        bossKillCounts = drops.killCounts,
        tickSeconds = drops.tickSeconds,
        trophySection = registry.byID.poh,
        resolveTrophyObject = require("Resources/Lib/game_data").CollectionObject,
        trophyTooltip = require("Resources/Lib/game_data").CollectionTooltip,
        slayerOptions = require("Resources/Shared/collections/collection_log_page").Options(
            registry.byID.slayer,
            context
        ),
        abilitiesOptions = require("Resources/Shared/collections/collection_log_page").Options(
            registry.byID.abilities,
            context
        ),
        progress = context.progress,
        state = context.state,
        saveState = context.saveState,
        refreshProgress = context.refreshProgress,
    })
end

return Feature
