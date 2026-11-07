-- Render read-only item grids with one shared tooltip
local ItemGrid = {}
ItemGrid.__index = ItemGrid

local SLOT_SIZE = 40
local NEVER = ui.ObjectQuantityDisplayMode.NEVER or 0
local HOVER_EVENT = "unifiedlogs_static_item_hover"

-- Resolve an object ID
local function objectID(object)
    if object == nil then return nil end
    local ok, value = pcall(function() return object.id end)
    value = ok and math.tointeger(value) or nil
    return value
end

-- Bind wheel scrolling
local function bindWheel(component, handler)
    if handler == nil then return end
    component:Subscribe(ui.Hook.ONSCROLLWHEEL, "unifiedlogs_static_item_scroll", handler)
end

-- Set a component's disabled state
local function setDisabled(slot, disabled)
    slot.disabled = disabled == true
    local visible = (slot.object ~= nil or slot.spriteID ~= nil) and slot.disabled
    slot.item.alpha = visible and 0.75 or 1
    if slot.icon ~= nil then slot.icon.alpha = visible and 0.75 or 1 end
    slot.disabledOverlay.hidden = not visible
    if visible then slot.disabledOverlay:MoveToFront() end
end

function ItemGrid.new(parent, entries, options)
    options = options or {}
    local self = setmetatable({}, ItemGrid)
    self.capacity = math.max(1, math.floor(options.columns or #(entries or {})))
    self.slotGap = math.max(0, math.floor(options.slotGap or 2))
    self.quantityMode = options.quantityMode or ui.ObjectQuantityDisplayMode.MULTIPLE
    self.slots = {}
    self.tooltipOffset = options._tooltipOffset

    self.root = ui.Layer.new(parent)
    self.root:SetPos(options.x or 0, options.y or 0)
    self.root:SetSize(self.capacity * SLOT_SIZE + (self.capacity - 1) * self.slotGap, SLOT_SIZE)
    self.root.clickthrough = true
    bindWheel(self.root, options._onScrollWheel)

    -- Move one tooltip proxy over the hovered slot
    local tooltipParent = options._tooltipParent or parent
    self.tooltipTarget = ui.Layer.new(tooltipParent)
    self.tooltipTarget:SetPos(-100000, -100000)
    -- Match the visible slot footprint for tooltip placement
    self.tooltipTarget:SetSize(SLOT_SIZE, SLOT_SIZE)
    self.tooltipTarget.clickthrough = true
    self.tooltip = prettyui.Tooltip.attach(self.tooltipTarget, tooltipParent, "", {
        onMouseOver = function() end,
        onMouseLeave = function() end,
    })
    -- Keep the proxy from covering slot input
    self.tooltipTarget.clickthrough = true

    for index = 1, self.capacity do
        local slot = { index = index, disabled = false }
        slot.root = ui.Layer.new(self.root)
        slot.root:SetPos((index - 1) * (SLOT_SIZE + self.slotGap), 0)
        slot.root:SetSize(SLOT_SIZE, SLOT_SIZE)
        slot.root.clickthrough = false
        bindWheel(slot.root, options._onScrollWheel)

        slot.background = ui.Sprite.new(slot.root)
        slot.background:SetSize(SLOT_SIZE, SLOT_SIZE)
        slot.background.spriteID = prettyui.Sprites.ITEM_GRID_BACKGROUND
        slot.background.clickthrough = true

        slot.item = ui.Sprite.new(slot.root)
        slot.item:SetPos(4, 4)
        slot.item:SetSize(32, 32)
        slot.item.clickthrough = true
        slot.item.hidden = true

        slot.disabledOverlay = ui.Rectangle.new(slot.root)
        slot.disabledOverlay:SetPos(4, 4)
        slot.disabledOverlay:SetSize(32, 32)
        slot.disabledOverlay.fill = true
        slot.disabledOverlay.rgba = 0x000000FF
        slot.disabledOverlay.alpha = 0.55
        slot.disabledOverlay.clickthrough = true
        slot.disabledOverlay.hidden = true

        function slot:SetDisabled(disabled) setDisabled(self, disabled) end

        slot.root:Subscribe(ui.Hook.ONMOUSEOVER, HOVER_EVENT, function()
            if slot.tooltip == nil or slot.tooltip == "" then return true end
            local offsetX, offsetY = 0, 0
            if self.tooltipOffset ~= nil then offsetX, offsetY = self.tooltipOffset() end
            self.tooltipTarget:SetPos(offsetX + (self.root.x or 0) + (slot.root.x or 0),
                offsetY + (self.root.y or 0))
            self.tooltip:SetText(slot.tooltip)
            self.tooltip:Show()
            return true
        end)
        slot.root:Subscribe(ui.Hook.ONMOUSELEAVE, HOVER_EVENT, function()
            self.tooltip:Hide()
            return true
        end)
        self.slots[index] = slot
    end
    self:SetEntries(entries or {})
    return self
end

function ItemGrid:SetPos(x, y) self.root:SetPos(x, y) end

function ItemGrid:SetHidden(hidden)
    self.root.hidden = hidden == true
    if self.root.hidden then self.tooltip:Hide() end
end

function ItemGrid:SetEntries(entries, states)
    entries = entries or {}
    for index, slot in ipairs(self.slots) do
        local entry = entries[index]
        local object = type(entry) == "table" and entry.object or entry
        local objectIDValue = objectID(object)
        local spriteID = type(entry) == "table" and tonumber(entry.spriteID) or nil
        slot.spriteID = spriteID ~= nil and spriteID >= 0 and spriteID or nil
        if slot.spriteID ~= nil and slot.icon == nil then
            -- Ordinary collection grids do not need extra sprite components.
            slot.icon = ui.Sprite.new(slot.root)
            slot.icon:SetPos(4, 4)
            slot.icon:SetSize(32, 32)
            slot.icon.clickthrough = true
        end
        if slot.icon ~= nil then
            slot.icon.hidden = slot.spriteID == nil or objectIDValue ~= nil
            if not slot.icon.hidden then slot.icon.spriteID = slot.spriteID end
        end
        slot.object = objectIDValue ~= nil and object or nil
        slot.tooltip = type(entry) == "table" and entry.tooltip or nil
        local placeholder = type(entry) == "table" and entry.placeholder == true
        slot.root.hidden = objectIDValue == nil and slot.spriteID == nil and not placeholder
        if objectIDValue ~= nil then
            slot.item:SetAssociatedObject(objectIDValue)
            slot.item.hidden = false
            local quantity = type(entry) == "table" and entry.quantity or nil
            if quantity ~= nil then
                slot.item.associatedObjectQuantity =
                    math.max(0, math.floor(tonumber(quantity) or 0))
                slot.item.associatedObjectQuantityMode = self.quantityMode
            else
                slot.item.associatedObjectQuantityMode = NEVER
            end
        else
            slot.item.hidden = true
            slot.item.associatedObjectQuantityMode = NEVER
        end
        setDisabled(slot, states ~= nil and states[index] == false)
    end
end

-- Find an item slot
function ItemGrid:GetSlot(index) return self.slots[index] end

function ItemGrid:Destroy()
    if self.tooltip ~= nil then self.tooltip:Destroy() end
    self.tooltip = nil
    if self.tooltipTarget ~= nil then self.tooltipTarget:Destroy() end
    self.tooltipTarget = nil
    if self.root ~= nil then self.root:Destroy() end
    self.root = nil
    self.slots = {}
end

return ItemGrid
