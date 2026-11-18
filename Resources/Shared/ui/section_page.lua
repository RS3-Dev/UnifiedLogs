-- Host lazy section tabs and forward updates to the mounted child.
local UI = require("Resources/Shared/ui/components")
local Tabs = require("Resources/Shared/ui/lazy_tabs")
local Page = {}
Page.__index = Page
function Page.new(parent, context, modes, stateKey, create)
    local self = setmetatable({ context = context }, Page)
    self.root = UI.ContentLayer(parent)
    self.root:SetPos(context.x or 0, context.y or 0)
    self.root:SetSize(context.width, context.height)
    function self:SetMode(value)
        local mode = self.host:Mode(value) or modes[1]
        context.state[stateKey] = mode.id
        self.activeView = self.host:Activate(mode.id, true, function(_, mount)
            local child = {}
            for key, item in pairs(context) do child[key] = item end
            child.x, child.y, child.width, child.height = 0, 0, mount.width, mount.height
            return create(mode.id, mount, child, self)
        end)
        context.saveState()
    end
    function self:SetQuestOrderView(value)
        if self.activeView and self.activeView.SetQuestOrderView then return self.activeView:SetQuestOrderView(value) end
    end
    self.host = Tabs.new(self.root, modes, context.state[stateKey], function(_, _, value) self:SetMode(value) end)
    self:SetMode(context.state[stateKey])
    return self
end
for _, name in ipairs({ "RefreshAccountState", "RefreshData", "SetShowPersonalBests", "SetOrderView", "RefreshAchievements", "SetDateFormat", "SetTimeFormat", "SetCumulativeRequirements", "MarkDataDirty", "ShowsLiveData" }) do
    Page[name] = function(self, ...)
        if self.activeView and self.activeView[name] then return self.activeView[name](self.activeView, ...) end
        if name == "RefreshAccountState" and self.activeView and self.activeView.RebuildGrid then
            return self.activeView:RebuildGrid(true)
        end
        if name == "RefreshData" or name == "ShowsLiveData" then return false end
    end
end
function Page:Destroy() self.host:Destroy(); self.root:Destroy(); self.activeView = nil end
return Page
