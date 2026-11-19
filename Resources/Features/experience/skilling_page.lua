-- Group XP history, skill pets, and thieving under Skilling.
local Section = require("Resources/Shared/ui/section_page")
local Collection = require("Resources/Shared/collections/collection_log_page")
local Page = {}
function Page.new(parent, context, feature)
    return Section.new(parent, context, {
        { id = "xp", label = "XP" }, { id = "pets", label = "Skill Pets" }, { id = "thieving", label = "Thieving" },
    }, "skillingMode", function(mode, mount, child)
        if mode == "xp" then
            if not child.state.enableXPLogs or child.xpTracker == nil then
                require("Resources/Shared/ui/components").Text(mount,
                    "Enable XP logging in Settings to view your XP history.", 12, 12, mount.width - 24, 40)
                return {}
            end
            return feature.CreateXPPage(mount, child)
        elseif mode == "pets" then
            local options = Collection.Options(child.registry.byID.pets, child)
            options.groups = { { name = "Skill Pets" } }
            options.logs = { ["Skill Pets"] = options.logs["Skill Pets"] }
            options.allLabel, options.sidebarTitle = nil, "SKILL PETS"
            options.selected = "Skill Pets"
            return Collection.new(mount, options)
        end
        return child.registry.byID.thieving.CreatePage(mount, child)
    end)
end
return Page
