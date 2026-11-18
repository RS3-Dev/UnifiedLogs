-- Define the achievements feature
local CapeCatalog = require("Resources/Features/achievements/cape_catalog")

local modes = {}
for _, cape in ipairs(CapeCatalog.ordered) do
    modes[#modes + 1] = { id = cape.mode, label = cape.name, cape = cape }
end

local Feature = {
    id = "achievements",
    label = "Achievements",
    capeModes = modes,
    dependencies = { "quests" },
    modes = { { id = "overview", label = "Overview" }, { id = "achievements", label = "Achievements" },
        { id = "quests", label = "Quests" }, { id = "area_tasks", label = "Area Tasks" } },
    capes = CapeCatalog.ordered,
}

function Feature.CreatePage(parent, context)
    return require("Resources/Features/achievements/achievement_section").new(parent, context, Feature)
end
return Feature
