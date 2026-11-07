-- Render the sidebar list
local UI = require("Resources/Shared/ui/components")
local ProgressStyle = require("Resources/Shared/ui/progress_style")

local SidebarList = {}
SidebarList.__index = SidebarList

SidebarList.ROW_HEIGHT = 32
SidebarList.ROW_ODD = 0x211E1BFF
SidebarList.ROW_EVEN = 0x2A2622FF
SidebarList.ROW_HOVER = 0x403728FF
SidebarList.ROW_SELECTED = 0x49371FFF
SidebarList.SELECTED_BORDER = 0xD2A84DFF
SidebarList.BORDER = 0x806432FF
SidebarList.TEXT = 0xE7D7B0FF

-- Normalize a sidebar entry; plain strings use their text as the ID
local function normalizedEntry(value, index, selectedID)
    local source = type(value) == "table" and value or { id = value, label = value }
    local entryID = source.id
    if entryID == nil then entryID = index end
    return {
        id = entryID,
        label = tostring(source.label or ""),
        selected = source.selected == true or entryID == selectedID,
        enabled = source.enabled ~= false,
        backgroundColour = ProgressStyle.Green(source.complete,
            index % 2 == 1 and SidebarList.ROW_ODD or SidebarList.ROW_EVEN, ProgressStyle.GREEN_BACKGROUND),
        hoverColour = ProgressStyle.Green(source.complete, SidebarList.ROW_HOVER, ProgressStyle.GREEN_HEADER),
        selectedColour = ProgressStyle.Green(source.complete, SidebarList.ROW_SELECTED, ProgressStyle.GREEN_HEADER),
        textColour = ProgressStyle.Green(source.complete, source.textColour or SidebarList.TEXT, 0xF2C66DFF),
        icon = source.icon,
    },
        source
end

function SidebarList.new(parent, options)
    options = options or {}
    local self = setmetatable({}, SidebarList)
    self.options = options
    self.frames = {}
    self.frameByRow = {}
    self.sources = {}

    local entries = {}
    for index, value in ipairs(options.entries or {}) do
        local entry, source = normalizedEntry(value, index, options.selected)
        entries[#entries + 1] = entry
        self.sources[entry.id] = source
    end

    self.host = UI.RootLayer(parent)
    self.host:SetPos(options.x or 0, options.y or 0)
    self.host:SetSize(options.width, options.height)
    local ok, list = pcall(prettyui.List.new, self.host, {
        x = 0,
        y = 0,
        width = options.width,
        height = options.height,
        entryHeight = options.entryHeight or SidebarList.ROW_HEIGHT,
        entryIconScale = options.entryIconScale,
        maxSelected = 1,
        font = options.font or id.Font.MUSEO_SANS_13PT_BOLD,
        backgroundColour = options.backgroundColour or 0x00000000,
        borderColour = options.borderColour or SidebarList.BORDER,
        selectedColour = SidebarList.ROW_SELECTED,
        entries = entries,
        _onEntryClick = function(_, entryID, selected)
            self:Decorate()
            if type(options.onSelect) == "function" then
                options.onSelect(entryID, selected, self.sources[entryID])
            end
        end,
    })
    if not ok then
        self.host:Destroy()
        error(list, 0)
    end
    self.list = list
    self.root = self.list.root
    self:Decorate()
    if options.scrollY ~= nil then self:SetScrollPosition(options.scrollY) end
    return self
end

-- Apply sidebar entry styling
function SidebarList:Decorate()
    for _, edges in ipairs(self.frames) do
        for _, edge in ipairs(edges) do
            edge.hidden = true
        end
    end
    if self.list == nil then return end
    for _, row in ipairs(self.list.rows or {}) do
        UI.RemoveCursor(row.root)
        local colour = nil
        if type(self.options.frameColourForEntry) == "function" then
            colour = self.options.frameColourForEntry(
                row.entry.id,
                row.entry.selected,
                self.sources[row.entry.id]
            )
        end
        if colour == nil and row.entry.selected then colour = SidebarList.SELECTED_BORDER end
        if colour ~= nil then
            local edges = self.frameByRow[row.root]
            if edges == nil then
                edges = UI.Frame(row.root, 0, 0, row.root.width,
                    row.height or SidebarList.ROW_HEIGHT, colour)
                self.frameByRow[row.root] = edges
                self.frames[#self.frames + 1] = edges
            end
            for _, edge in ipairs(edges) do
                edge.rgba = colour
                edge.hidden = false
            end
        end
    end
end

-- Update selection without recreating every list row.
function SidebarList:Select(entryID)
    for _, entry in ipairs(self.list.entries or {}) do
        self.list:SetSelected(entry.id, entry.id == entryID, false)
    end
    self:Decorate()
end

function SidebarList:GetScrollPosition() return self.list ~= nil and self.list.scrollY or 0 end

function SidebarList:SetScrollPosition(value)
    if self.list ~= nil then self.list:SetScrollPosition(value or 0) end
end

-- Scroll a sidebar entry into view
function SidebarList:Reveal(entryID, centred)
    if self.list == nil then return false end
    local y = 0
    for _, entry in ipairs(self.list.entries or {}) do
        local height = entry.height or self.list.entryHeight
        if entry.id == entryID then
            if centred then
                y = math.max(
                    0,
                    y - math.floor(self.list:_ViewportHeight() / 2) + math.floor(height / 2)
                )
            end
            self.list:SetScrollPosition(y)
            return true
        end
        if entry.visible then y = y + height end
    end
    return false
end

function SidebarList:SetHidden(hidden)
    if self.root ~= nil then self.root.hidden = hidden == true end
end

function SidebarList:Destroy()
    for _, edges in ipairs(self.frames or {}) do
        for _, edge in ipairs(edges) do
            edge:Destroy()
        end
    end
    self.frames = {}
    self.frameByRow = {}
    if self.list ~= nil then self.list:Destroy() end
    if self.host ~= nil then self.host:Destroy() end
    self.host = nil
    self.list = nil
    self.root = nil
end

return SidebarList
