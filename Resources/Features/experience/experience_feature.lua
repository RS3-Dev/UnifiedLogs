-- Define the experience feature
local Feature = {
    id = "xp",
    label = "Skilling",
    modes = {
        { id = "notice", label = "Read First" },
        { id = "overall", label = "Overall" },
        { id = "skills", label = "Skills" },
        { id = "danger", label = "Danger" },
    },
}

function Feature.CreateXPPage(parent, context)
    return require("Resources/Features/experience/experience_history_page").new(parent, {
        x = context.x,
        y = context.y,
        width = context.width,
        height = context.height,
        section = Feature,
        tracker = context.xpTracker,
        state = context.state,
        saveState = context.saveState,
    })
end

Feature.dependencies = { "pets", "thieving" }
function Feature.CreatePage(parent, context)
    return require("Resources/Features/experience/skilling_page").new(parent, context, Feature)
end
return Feature
