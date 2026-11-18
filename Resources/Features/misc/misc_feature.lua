-- Define the misc feature
local Feature = {
    id = "misc",
    label = "Misc",
    modes = { { id = "pof", label = "POF" }, { id = "totems", label = "Totems" } },
}

Feature.dependencies = { "pof", "totems" }
function Feature.CreatePage(parent, context)
    return require("Resources/Features/misc/misc_page").new(parent, context, Feature)
end
return Feature
