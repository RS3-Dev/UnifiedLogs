-- Mount one page beside the shared virtualized sidebar.
local UI = require("Resources/Shared/ui/components")
local Layout = require("Resources/Shared/ui/sidebar_layout")
local List = require("Resources/Shared/ui/sidebar_list")
local Pages = {}
Pages.__index = Pages
function Pages.new(parent, modes, selected, onChange)
    local self = setmetatable({ modes = modes }, Pages)
    self.shell = Layout.Create(parent, { width = parent.width, height = parent.height, sidebarTitle = "SELECT" })
    local entries = {}
    for _, mode in ipairs(modes) do entries[#entries + 1] = { id = mode.id, label = mode.label } end
    self.sidebar = List.new(self.shell.root, { x = 0, y = 36, width = 220, height = parent.height - 36,
        entries = entries, selected = selected, onSelect = function(value) onChange(nil, nil, value) end })
    return self
end
function Pages:Mode(value)
    for _, mode in ipairs(self.modes) do if mode.id == value then return mode end end
end
function Pages:Activate(value, force, create)
    local mode = self:Mode(value) or self.modes[1]
    if not force and self.activeMode == mode.id then return self.activeView, mode end
    if self.activeView and self.activeView.Destroy then self.activeView:Destroy() end
    if self.mount then self.mount:Destroy() end
    self.mount = UI.RootLayer(self.shell.workspace)
    self.activeMode = mode.id
    self.sidebar:Select(mode.id)
    self.activeView = create(mode, self.mount)
    return self.activeView, mode
end
function Pages:Destroy()
    if self.activeView and self.activeView.Destroy then self.activeView:Destroy() end
    self.sidebar:Destroy()
    self.shell.root:Destroy()
    self.activeView = nil
end
return Pages
