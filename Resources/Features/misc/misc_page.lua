-- Mount collection features through the shared section lifecycle.
local Section = require("Resources/Shared/ui/section_page")
local Page = {}
function Page.new(parent, context, feature)
    local page = Section.new(parent, context, feature.modes, "miscMode", function(mode, mount, child, host)
        host.pofView = nil
        local view = child.registry.byID[mode].CreatePage(mount, child)
        if mode == "pof" then host.pofView = view end
        return view
    end)
    page.tabHost, page.tabs = page.host, page.host.tabs
    return page
end
return Page
