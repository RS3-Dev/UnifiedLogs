-- Render the relic loadouts tab
local UI = require("Resources/Shared/ui/components")
local GameData = require("Resources/Lib/game_data")
local SidebarList = require("Resources/Shared/ui/sidebar_list")
local ProgressStyle = require("Resources/Shared/ui/progress_style")
local SidebarLayout = require("Resources/Shared/ui/sidebar_layout")

local RelicLoadoutsTab = {}
RelicLoadoutsTab.__index = RelicLoadoutsTab

local SIDEBAR_WIDTH = SidebarLayout.SIDEBAR_WIDTH
local GREEN = 0x43C967FF

-- Infer missing power sprites from relic config names
local function powerSpriteName(record)
    if type(record) ~= "table" then return nil end
    if record.powerSpriteName ~= nil and record.powerSpriteName ~= "" then
        return record.powerSpriteName
    end
    local configName = tostring(record.configName or "")
    local suffix = string.match(configName, "^ARCH_RELIC_(.+)$")
    return suffix ~= nil and ("ARCH_ICON_RELIC_64PX_" .. suffix) or nil
end

-- Read the active relic loadout
local function activeLoadout(loadouts)
    if type(loadouts) ~= "table" then return nil end
    local value = GameData.VariableValueByID(loadouts.activeVarBitId)
    if value == nil and loadouts.activeVariable ~= nil then
        value = GameData.TrackingValue(loadouts.activeVariable)
    end
    return tonumber(value)
end

function RelicLoadoutsTab.new(parent, options)
    local self = setmetatable({}, RelicLoadoutsTab)
    self.options = options
    self.records = self.options.records or {}
    self.loadouts = self.options.loadouts or { presets = {} }
    self.selected = tonumber(self.options.selected)

    local shell = SidebarLayout.CreateHeaded(parent, self.options, "LOADOUTS")
    self.root, self.workspace, self.heading = shell.root, shell.workspace, shell.heading
    self.heading:SetSize(self.workspace.width - 150, 30)
    self.activeLabel = UI.Text(self.workspace, "", self.workspace.width - 202, 10, 174, 30, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = GREEN,
        alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
    })
    local current = activeLoadout(self.loadouts)
    if self.selected == nil then self.selected = current end
    if self.selected == nil then self.selected = 0 end
    self:RebuildSidebar()
    self:RebuildDetail()
    return self
end

-- Build a relic preset
function RelicLoadoutsTab:Preset(index)
    for _, preset in ipairs(self.loadouts.presets or {}) do
        if tonumber(preset.index) == tonumber(index) then return preset end
    end
    return nil
end

function RelicLoadoutsTab:RebuildSidebar()
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    self.sidebarList = nil

    local current = activeLoadout(self.loadouts)
    local entries = {}
    for position, preset in ipairs(self.loadouts.presets or {}) do
        local presetIndex = tonumber(preset.index) or position - 1
        local name = tostring(preset.name or ("Loadout " .. tostring(position)))
        entries[#entries + 1] = { id = presetIndex, label = name }
    end
    self.sidebarList = SidebarList.new(self.root, {
        x = 0,
        y = 38,
        width = SIDEBAR_WIDTH,
        height = math.max(40, self.root.height - 46),
        entries = entries,
        selected = self.selected,
        frameColourForEntry = function(entryID)
            if tonumber(entryID) == current then return GREEN end
            return nil
        end,
        onSelect = function(presetIndex)
            if self.selected == presetIndex then return end
            self.selected = presetIndex
            self.options.onStateChange(presetIndex)
            self:RebuildDetail()
        end,
    })
end

function RelicLoadoutsTab:RebuildDetail()
    if self.detailLayer ~= nil then self.detailLayer:Destroy() end
    self.detailLayer = ui.Layer.new(self.workspace)
    self.detailLayer:SetPos(0, 46)
    self.detailLayer:SetSize(self.workspace.width, math.max(1, self.workspace.height - 46))
    self.detailLayer.clickthrough = true
    local preset = self:Preset(self.selected)
    local current = activeLoadout(self.loadouts)
    local displayIndex = tonumber(self.selected) or 0
    self.heading.content =
        string.upper(preset ~= nil and preset.name or ("Loadout " .. tostring(displayIndex + 1)))
    self.activeLabel.content = current == displayIndex and "CURRENTLY LOADED" or ""

    local byRelicID = {}
    for _, record in ipairs(self.records) do
        if tonumber(record.relicId) ~= nil then byRelicID[tonumber(record.relicId)] = record end
    end
    local slotRecords = {}
    for _, slotVarBitID in ipairs(preset ~= nil and preset.slotVarBitIds or {}) do
        local relicID = tonumber(GameData.VariableValueByID(slotVarBitID)) or 0
        -- Keep empty slots in place
        slotRecords[#slotRecords + 1] = byRelicID[relicID] or false
    end
    while #slotRecords < 3 do
        slotRecords[#slotRecords + 1] = false
    end

    local rowHeight = 88
    for index = 1, 3 do
        local record = slotRecords[index]
        local hasRecord = type(record) == "table"
        local spriteID = hasRecord
                and GameData.SpriteID(record.powerSpriteId, powerSpriteName(record))
            or nil
        local y = (index - 1) * rowHeight
        UI.Rectangle(
            self.detailLayer,
            0,
            y,
            self.detailLayer.width,
            rowHeight,
            ProgressStyle.RowColour(index)
        )
        if index < 3 then
            UI.Rectangle(
                self.detailLayer,
                0,
                y + rowHeight - 1,
                self.detailLayer.width,
                1,
                ProgressStyle.ROW_DIVIDER
            )
        end
        if hasRecord then
            ProgressStyle.Wedge(self.detailLayer, 1, y + 1, rowHeight - 2):MoveToFront()
        end
        ProgressStyle.CompletionMark(
            self.detailLayer,
            self.detailLayer.width - 26,
            y + math.floor((rowHeight - 14) / 2),
            hasRecord
        )
        UI.Rectangle(self.detailLayer, 8, y + 8, 68, 68, 0x0D0B08FF)
        if spriteID ~= nil then
            local icon = ui.Sprite.new(self.detailLayer)
            icon:SetPos(10, y + 10)
            icon:SetSize(64, 64)
            icon.spriteID = spriteID
            icon.clickthrough = true
        end

        local name = hasRecord and record.name or "Empty slot"
        local description = hasRecord and record.description
            or "No relic power is saved in this slot."
        UI.Text(
            self.detailLayer,
            string.upper(tostring(name)),
            84,
            y + 4,
            self.detailLayer.width - 124,
            20,
            {
                font = id.Font.MUSEO_SANS_13PT_BOLD,
                colour = hasRecord and ProgressStyle.TEXT_COMPLETE or ProgressStyle.TEXT_NORMAL,
            }
        )
        UI.Text(self.detailLayer, description, 84, y + 22, self.detailLayer.width - 124, 34, {
            font = id.Font.MUSEO_SANS_11PT_REGULAR,
            colour = 0xE7E1D5FF,
            maxLines = 2,
            alignVertical = ui.AlignMode.TOPLEFT,
        })
        if hasRecord then
            local powerIcon = tonumber(self.loadouts.powerIconSpriteId)
            if powerIcon ~= nil then
                local icon = ui.Sprite.new(self.detailLayer)
                icon:SetPos(84, y + 62)
                icon:SetSize(16, 16)
                icon.spriteID = powerIcon
                icon.clickthrough = true
            end
            UI.Text(self.detailLayer, tostring(record.powerCost or 0), 104, y + 58, 72, 24, {
                font = id.Font.MUSEO_SANS_13PT_REGULAR,
                colour = 0xE7E1D5FF,
            })
        end
    end
    ProgressStyle.Frame(self.detailLayer, 0, 0, self.detailLayer.width, rowHeight * 3)
end

function RelicLoadoutsTab:RefreshAccountState()
    self:RebuildSidebar()
    self:RebuildDetail()
end

function RelicLoadoutsTab:Destroy()
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    if self.detailLayer ~= nil then self.detailLayer:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.sidebarList = nil
    self.detailLayer = nil
    self.root = nil
end

return RelicLoadoutsTab
