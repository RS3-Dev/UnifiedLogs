-- Clear plugin modules before startup
local RUNTIME_KEY = "__unifiedlogs_runtime"
local previousRuntime = rawget(_G, RUNTIME_KEY)
if previousRuntime ~= nil then previousRuntime:Shutdown() end

if package ~= nil and package.loaded ~= nil then
    local modules = {
        "Resources/Features/achievements/achievement_guide_panel",
        "Resources/Features/achievements/achievements_feature",
        "Resources/Features/achievements/achievements_page",
        "Resources/Features/achievements/cape_catalog",
        "Resources/Features/achievements/cape_model_canvas",
        "Resources/Features/achievements/cape_overview",
        "Resources/Features/achievements/cape_requirements",
        "Resources/Features/achievements/cape_requirements_view",
        "Resources/Features/archaeology/archaeology_feature",
        "Resources/Features/archaeology/archaeology_page",
        "Resources/Features/archaeology/collector_collection_entries",
        "Resources/Features/archaeology/collector_collection_list",
        "Resources/Features/archaeology/collector_collections_tab",
        "Resources/Features/archaeology/data/archaeology_catalog",
        "Resources/Features/archaeology/data/relic_categories",
        "Resources/Features/archaeology/mysteries_tab",
        "Resources/Features/archaeology/relic_loadouts_tab",
        "Resources/Features/archaeology/relics_tab",
        "Resources/Features/bosses/combat_achievement_state_loader",
        "Resources/Features/bosses/boss_categories",
        "Resources/Features/bosses/abilities/abilities_feature",
        "Resources/Features/bosses/boss_drops_tab",
        "Resources/Features/bosses/boss_feature",
        "Resources/Features/bosses/boss_patch",
        "Resources/Features/bosses/boss_patch_values_window",
        "Resources/Features/bosses/boss_page",
        "Resources/Features/bosses/poh_page",
        "Resources/Features/bosses/combat_achievement_list",
        "Resources/Features/bosses/combat_achievement_descriptions",
        "Resources/Features/bosses/combat_achievements_tab",
        "Resources/Features/bosses/data/boss_kill_count_catalog",
        "Resources/Features/bosses/data/boss_record_catalog",
        "Resources/Features/bosses/data/combat_achievement_catalog",
        "Resources/Features/bosses/data/drop_log_sources",
        "Resources/Features/bosses/data/furniture_plan_catalog",
        "Resources/Features/bosses/furniture_plans_tab",
        "Resources/Features/bosses/trophies/data/trophy_catalog",
        "Resources/Features/bosses/trophies/trophy_manual_state",
        "Resources/Features/bosses/trophies/trophy_model_preview",
        "Resources/Features/bosses/trophies/trophy_models",
        "Resources/Features/bosses/trophies/trophy_rotation",
        "Resources/Features/bosses/trophies/trophy_tab",
        "Resources/Features/clues/clue_feature",
        "Resources/Features/clues/data/clue_catalog",
        "Resources/Features/experience/daily_experience_list",
        "Resources/Features/experience/date_range_picker",
        "Resources/Features/experience/experience_chart",
        "Resources/Features/experience/experience_feature",
        "Resources/Features/experience/experience_history",
        "Resources/Features/experience/experience_history_page",
        "Resources/Features/experience/experience_time",
        "Resources/Features/experience/experience_tracker",
        "Resources/Features/feature_registry",
        "Resources/Features/misc/misc_feature",
        "Resources/Features/misc/misc_page",
        "Resources/Features/misc/minigames/minigames_feature",
        "Resources/Features/misc/skilling_outfits/skilling_outfits_feature",
        "Resources/Features/misc/pets/pets_feature",
        "Resources/Features/misc/enchantments/enchantments_feature",
        "Resources/Features/misc/thieving/data/heist_catalog",
        "Resources/Features/misc/thieving/thieving_feature",
        "Resources/Features/misc/thieving/thieving_page",
        "Resources/Features/misc/player_owned_farms/data/farm_catalog",
        "Resources/Features/misc/player_owned_farms/farm_feature",
        "Resources/Features/quests/data/quest_catalog",
        "Resources/Features/quests/quest_details_panel",
        "Resources/Features/quests/quest_feature",
        "Resources/Features/quests/quest_page",
        "Resources/Features/quests/quest_requirements",
        "Resources/Features/slayer/data/slayer_region_catalog",
        "Resources/Features/slayer/slayer_feature",
        "Resources/Lib/app",
        "Resources/Lib/date_time_format",
        "Resources/Lib/debounced_action",
        "Resources/Lib/feature_loader",
        "Resources/Lib/game_data",
        "Resources/Lib/json",
        "Resources/Lib/number_format",
        "Resources/Lib/progress/account",
        "Resources/Lib/player_identity",
        "Resources/Lib/settings",
        "Resources/Lib/storage",
        "Resources/Shared/achievements/achievement_text",
        "Resources/Shared/client_config",
        "Resources/Shared/collections/collection_catalog",
        "Resources/Shared/collections/collection_entries",
        "Resources/Shared/collections/collection_feature",
        "Resources/Shared/collections/collection_log_page",
        "Resources/Shared/collections/collection_tracking_names",
        "Resources/Shared/skills/skill_catalog",
        "Resources/Shared/skills/skill_icons",
        "Resources/Shared/ui/collection_group_panel",
        "Resources/Shared/ui/components",
        "Resources/Shared/ui/item_grid",
        "Resources/Shared/ui/lazy_tabs",
        "Resources/Shared/ui/launcher_panel",
        "Resources/Shared/ui/progress_style",
        "Resources/Shared/ui/scrollable_item_list",
        "Resources/Shared/ui/sidebar_layout",
        "Resources/Shared/ui/sidebar_list",
    }
    for _, moduleName in ipairs(modules) do
        package.loaded[moduleName] = nil
    end
end

local registry = require("Resources/Features/feature_registry")
local App = require("Resources/Lib/app")

local app = App.new(registry)
app:Start()
_G[RUNTIME_KEY] = app

-- Stop the plugin
function PluginShutdown()
    app:Shutdown()
    if rawget(_G, RUNTIME_KEY) == app then _G[RUNTIME_KEY] = nil end
end
