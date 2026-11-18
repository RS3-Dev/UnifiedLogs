-- Keep overview, cape browsing, quests, and area tasks on separate lazy pages.
local Section = require("Resources/Shared/ui/section_page")
local Requirements = require("Resources/Features/achievements/cape_requirements")
local Page = {}
function Page.new(parent, context, feature)
    if context.state.achievementTab == nil then
        context.state.achievementTab = context.state.achievementMode ~= "overview" and "achievements" or "overview"
    end
    local section = Section.new(parent, context, feature.modes, "achievementTab", function(mode, mount, child, host)
        if mode == "quests" then return child.registry.byID.quests.CreatePage(mount, child) end
        if mode == "area_tasks" then
            return require("Resources/Features/achievements/area_tasks_page").new(mount, child)
        end
        if mode == "overview" then
            local view
            local snapshot = Requirements.NewSnapshot({ isVisible = child.isVisible,
                onChanged = function() if view then view:RefreshProgress() end end })
            view = require("Resources/Features/achievements/cape_overview").new(mount, {
                width = mount.width, height = mount.height, capes = feature.capes, snapshot = snapshot,
                fastSummary = true,
                onSelect = function(cape) child.state.achievementMode = cape; host:SetMode("achievements") end,
            })
            local destroy = view.Destroy
            view.Destroy = function(self) snapshot:Stop(); destroy(self) end
            return view
        end
        local modes = {}
        for _, item in ipairs(feature.capeModes) do if item.id ~= "overview" then modes[#modes + 1] = { id = item.id, label = item.cape.name, cape = item.cape } end end
        if child.state.achievementMode == "overview" then child.state.achievementMode = modes[1].id end
        return require("Resources/Features/achievements/achievements_page").new(mount, {
            width = mount.width, height = mount.height, section = { modes = modes, capes = feature.capes },
            state = child.state, saveState = child.saveState, isVisible = child.isVisible,
        })
    end)
    local refresh = section.RefreshAccountState
    section.RefreshAccountState = function(self)
        if context.state.achievementTab == "overview" then self:SetMode("overview")
        else return refresh(self) end
    end
    local setOrder = section.SetOrderView
    section.SetOrderView = function(self, value)
        if context.state.achievementTab == "achievements" then return setOrder(self, value) end
    end
    section.SetQuestOrderView = function(self, value)
        if context.state.achievementTab == "quests" and self.activeView then return self.activeView:SetOrderView(value) end
    end
    return section
end
return Page
