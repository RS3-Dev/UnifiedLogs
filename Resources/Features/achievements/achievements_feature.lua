-- Define the achievements feature
local CapeCatalog = require("Resources/Features/achievements/cape_catalog")

local modes = { { id = "overview", label = "Overview" } }
for _, cape in ipairs(CapeCatalog.ordered) do
    modes[#modes + 1] = { id = cape.mode, label = cape.label, cape = cape }
end

local Feature = {
    id = "achievements",
    label = "Achievements",
    modes = modes,
    capes = CapeCatalog.ordered,
}

function Feature.CreatePage(parent, context)
    return require("Resources/Features/achievements/achievements_page").new(parent, {
        x = context.x,
        y = context.y,
        width = context.width,
        height = context.height,
        section = Feature,
        state = context.state,
        saveState = context.saveState,
    })
end

return Feature
