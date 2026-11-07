-- Create feature pages only when selected
local UI = require("Resources/Shared/ui/components")

local LazyTabs = {}
LazyTabs.__index = LazyTabs

function LazyTabs.new(parent, modes, activeMode, onChange)
    local self = setmetatable({}, LazyTabs)
    self.modes = modes or {}
    self.tabs, self.indexByID = UI.Tabs(parent, self.modes, activeMode, onChange)
    self.activeMode = nil
    self.activeView = nil
    return self
end

-- Read the current tab mode
function LazyTabs:Mode(modeID)
    for _, mode in ipairs(self.modes) do
        if mode.id == modeID then return mode end
    end
    return nil
end

function LazyTabs:DestroyActiveView()
    if self.activeView ~= nil and self.activeView.Destroy ~= nil then
        self.activeView:Destroy()
    end
    if self.mountRoot ~= nil then self.mountRoot:Destroy() end
    self.mountRoot = nil
    self.activeView = nil
    self.activeMode = nil
end

-- Activate a tab
function LazyTabs:Activate(modeID, force, createView)
    local mode = self:Mode(modeID) or self.modes[1]
    if mode == nil then return nil, nil, false end
    if not force and self.activeMode == mode.id then return self.activeView, mode, false end

    self:DestroyActiveView()
    local index = self.indexByID[mode.id]
    self.tabs:SetActive(index, false)
    local page = self.tabs:GetPage(index).content
    self.mountRoot = UI.RootLayer(page)
    local ok, view = pcall(createView, mode, self.mountRoot)
    if not ok then
        self.mountRoot:Destroy()
        self.mountRoot = nil
        error(view, 0)
    end
    self.activeMode = mode.id
    self.activeView = view
    return self.activeView, mode, true
end

function LazyTabs:Destroy()
    self:DestroyActiveView()
    if self.tabs ~= nil then self.tabs:Destroy() end
    self.tabs = nil
    self.indexByID = nil
end

return LazyTabs
