-- Render automatically tracked furniture plan unlocks.
local UI = require("Resources/Shared/ui/components")
local GameData = require("Resources/Lib/game_data")
local CollectionEntries = require("Resources/Shared/collections/collection_entries")
local ScrollableItemList = require("Resources/Shared/ui/scrollable_item_list")
local entries = require("Resources/Features/bosses/data/furniture_plan_catalog")

local FurniturePlansTab = {}
FurniturePlansTab.__index = FurniturePlansTab

function FurniturePlansTab.Options(progress)
    return {
        getValue = function(variable) return progress:GetValue(variable) end,
        isCollected = function(entry, value) return progress:IsCollected(entry, value) end,
        resolveObject = GameData.CollectionObject, tooltip = GameData.CollectionTooltip,
        showQuantities = false,
    }
end

function FurniturePlansTab.new(parent, options)
    local self = setmetatable({ options = options }, FurniturePlansTab)
    self.root = ui.Layer.new(parent)
    self.root:SetSize(options.width, options.height)
    self.root.clickthrough = true
    UI.Text(self.root, "FURNITURE PLANS", 12, 2, options.width - 140, 30, {
        font = id.Font.CINZEL_18PT_BOLD, colour = 0xF2C66DFF,
    })
    self.summary = UI.Text(self.root, "0 / 12", options.width - 118, 2, 100, 30, {
        font = id.Font.MUSEO_SANS_13PT_BOLD, colour = 0xF2C66DFF,
        alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
    })
    self.scroll = prettyui.SimpleView.new(self.root, {
        y = 38, width = options.width, height = math.max(120, options.height - 38),
        contentHeight = 120, scrollStep = 44,
    })
    self.ledger = ScrollableItemList.new(self.scroll, {
        rowWidth = math.max(300, options.width - 18),
    })
    self:RefreshAccountState()
    return self
end

function FurniturePlansTab:RefreshAccountState()
    local prepared = CollectionEntries.PrepareGroup("Furniture Plans", entries,
        FurniturePlansTab.Options(self.options.progress))
    prepared.showHeader = false
    self.summary.content = tostring(prepared.collected) .. " / " .. tostring(prepared.total)
    self.ledger:Update({ prepared }, { preserveScroll = true })
end

function FurniturePlansTab:Destroy()
    self.ledger:Destroy()
    self.scroll:Destroy()
    self.root:Destroy()
    self.root = nil
end

return FurniturePlansTab
