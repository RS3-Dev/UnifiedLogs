-- Render the trophy tab
local UI = require("Resources/Shared/ui/components")
local ItemGrid = require("Resources/Shared/ui/item_grid")
local CollectionGroupPanel = require("Resources/Shared/ui/collection_group_panel")
local ProgressStyle = require("Resources/Shared/ui/progress_style")
local TrophyRotation = require("Resources/Features/bosses/trophies/trophy_rotation")
local TrophyManualState = require("Resources/Features/bosses/trophies/trophy_manual_state")

local TrophyModelPreview = require("Resources/Features/bosses/trophies/trophy_model_preview")

local TrophyTab = {}
TrophyTab.__index = TrophyTab
TrophyTab.TransformFor = TrophyModelPreview.TransformFor
TrophyTab.ApplyModelTransform = TrophyModelPreview.ApplyModelTransform
TrophyTab.SetPreviewModel = TrophyModelPreview.SetPreviewModel

local OUTER_INSET = 12
local PANE_GAP = 8
local HEADER_HEIGHT = ProgressStyle.GROUP_HEIGHT
local SLOT_SIZE = 40
local SLOT_GAP = 4
local GRID_PADDING = 12
local CATALOGUE_COLUMNS = 9
local CATALOGUE_WIDTH = GRID_PADDING * 2
    + CATALOGUE_COLUMNS * SLOT_SIZE
    + (CATALOGUE_COLUMNS - 1) * SLOT_GAP
local QUANTITY_MODE = ui.ObjectQuantityDisplayMode.NEVER or 0
local MODEL_LABEL_HEIGHT = 104
local MANUAL_NOTICE_HEIGHT = 42
local MENU_EVENT = "unifiedlogs_trophy_menu"

-- Draw the selected trophy frame
local function selectionFrame(parent)
    local root = ui.Layer.new(parent)
    root:SetSize(SLOT_SIZE, SLOT_SIZE)
    root.clickthrough = true
    root.hidden = true
    local colour = ProgressStyle.PROGRESS_ACTIVE
    UI.Rectangle(root, 0, 0, SLOT_SIZE, 2, colour)
    UI.Rectangle(root, 0, SLOT_SIZE - 2, SLOT_SIZE, 2, colour)
    UI.Rectangle(root, 0, 0, 2, SLOT_SIZE, colour)
    UI.Rectangle(root, SLOT_SIZE - 2, 0, 2, SLOT_SIZE, colour)
    return root
end

-- Check whether a component is hovered
local function componentIsMouseOver(component)
    if component == nil then return false end
    local hovered = component.isMouseOver
    if type(hovered) == "function" then
        local ok, value = pcall(hovered, component)
        return ok and value == true
    end
    return hovered == true
end

-- Add menu actions in visible priority order
local function moveCancelToBottom(menu)
    for index, entry in ipairs(menu.entries or {}) do
        if entry.verbText == "Cancel" then
            for current = index, 2, -1 do menu:Swap(current, current - 1) end
            return
        end
    end
end

function TrophyTab.new(parent, options)
    local self = setmetatable({}, TrophyTab)
    self.options = options
    self.entries = self.options.entries or {}
    self.selectedIndex = #self.entries > 0 and 1 or nil
    self.grids = {}
    self.slotLocations = {}
    self.entrySlots = {}
    self.resolvedObjects = {}
    self.objectResolutionAttempted = {}
    self.modelTransforms = {}
    self.autoRotation = TrophyRotation.new(self)
    self.windowParent = self.options.windowParent or parent
    self.menuSubscribed = false

    self.root = ui.Layer.new(parent)
    self.root:SetPos(self.options.x or 0, self.options.y or 0)
    self.root:SetSize(self.options.width, self.options.height)
    self.root.clickthrough = true

    self:BuildShell()
    self:SubscribeMiniMenu()
    if self.options.deferInitialBuild ~= true then self:BuildContent() end
    return self
end

function TrophyTab:IsTrophyCollected(index)
    local state = self.options.state or {}
    return TrophyManualState.IsFound(state.trophyFound, self.entries[index])
end

function TrophyTab:RefreshAccountState()
    for index, slot in pairs(self.entrySlots or {}) do
        slot:SetDisabled(not self:IsTrophyCollected(index))
    end
    self:UpdateCatalogueCount()
end

-- Count found trophies
function TrophyTab:FoundCount()
    local state = self.options.state or {}
    return TrophyManualState.Count(state.trophyFound, self.entries)
end

function TrophyTab:UpdateCatalogueCount()
    if self.catalogueCountLabel ~= nil then
        self.catalogueCountLabel.content = tostring(self:FoundCount()) .. " / " .. tostring(#self.entries)
    end
end

function TrophyTab:SetTrophyFound(index, found)
    local entry = self.entries[index]
    if entry == nil then return false end
    local state = self.options.state or {}
    state.trophyFound = TrophyManualState.SetFound(state.trophyFound, entry, found)
    self.options.state = state
    local slot = self.entrySlots ~= nil and self.entrySlots[index] or nil
    if slot ~= nil then slot:SetDisabled(not self:IsTrophyCollected(index)) end
    self:UpdateCatalogueCount()
    if type(self.options.saveState) == "function" then self.options.saveState() end
    return true
end

-- Find the hovered trophy
function TrophyTab:HoveredTrophyIndex()
    if self.contentRoot == nil or self.root == nil or self.root.hidden == true then return nil end
    for index, slot in pairs(self.entrySlots or {}) do
        if componentIsMouseOver(slot.root) then return index end
    end
    return nil
end

-- Add trophy minimenu actions
function TrophyTab:AddMiniMenuEntries(event)
    local menu = event ~= nil and event.miniMenu or nil
    local index = self:HoveredTrophyIndex()
    if menu == nil or index == nil or type(menu.Add) ~= "function" then return false end

    local found = self:IsTrophyCollected(index)
    menu:Add("Open display", function(targetIndex)
        if self.root ~= nil then self:Select(targetIndex) end
    end, index)
    menu:Add(found and "Mark not found" or "Mark found", function(targetIndex)
        if self.root ~= nil then self:SetTrophyFound(targetIndex, not found) end
    end, index)
    moveCancelToBottom(menu)
    return true
end

function TrophyTab:SubscribeMiniMenu()
    if Event == nil or Event.MiniMenuReady == nil or self.menuSubscribed then return end
    Event.MiniMenuReady.Subscribe(MENU_EVENT, function(event) self:AddMiniMenuEntries(event) end)
    self.menuSubscribed = true
end

-- Unsubscribe from mini menu
function TrophyTab:UnsubscribeMiniMenu()
    if not self.menuSubscribed then return end
    if Event ~= nil and Event.MiniMenuReady ~= nil then Event.MiniMenuReady.Unsubscribe(MENU_EVENT) end
    self.menuSubscribed = false
end

function TrophyTab:BuildShell()
    local usableWidth = math.max(320, self.root.width - OUTER_INSET * 2)
    local availableWidth = math.max(1, usableWidth - PANE_GAP)
    local columns = self.options.catalogueColumns
    local preferredWidth = columns and GRID_PADDING * 2 + columns * SLOT_SIZE
        + (columns - 1) * SLOT_GAP + 16 or CATALOGUE_WIDTH
    local catalogueWidth = math.min(preferredWidth,
        math.max(220, availableWidth - (self.options.minimumPreviewWidth or 260)))
    local previewWidth = availableWidth - catalogueWidth

    self.previewX = OUTER_INSET
    self.previewWidth = previewWidth
    self.catalogueX = self.previewX + previewWidth + PANE_GAP
    self.catalogueWidth = catalogueWidth
    self.bodyY = HEADER_HEIGHT
    self.bodyHeight = math.max(120, self.root.height - HEADER_HEIGHT - 8)

    CollectionGroupPanel.Header(self.root, {
        x = self.previewX,
        y = 0,
        width = self.previewWidth,
        title = "TROPHY PREVIEW",
        showProgress = false,
        showCompletionMark = false,
        showWedge = false,
    })
    CollectionGroupPanel.Body(self.root, {
        x = self.previewX,
        y = self.bodyY,
        width = self.previewWidth,
        height = self.bodyHeight,
        groupEnd = true,
        showWedge = false,
    })

    local catalogueHeader = CollectionGroupPanel.Header(self.root, {
        x = self.catalogueX,
        y = 0,
        width = self.catalogueWidth,
        title = "TROPHIES",
        countLabel = tostring(self:FoundCount()) .. " / " .. tostring(#self.entries),
        showProgress = false,
        showCompletionMark = false,
        showWedge = false,
    })
    self.catalogueCountLabel = catalogueHeader[3]

    CollectionGroupPanel.Body(self.root, {
        x = self.catalogueX, y = self.bodyY,
        width = self.catalogueWidth, height = self.bodyHeight,
        groupEnd = true, showWedge = false,
    })
    self.modelLabelHeight = MODEL_LABEL_HEIGHT - 22
    TrophyModelPreview.Create(self)

    local labelY = self.bodyY + self.bodyHeight - MODEL_LABEL_HEIGHT
    self.previewName =
        UI.Text(self.root, "", self.previewX + 32, labelY + 22, self.previewWidth - 64, 48, {
            font = id.Font.CINZEL_18PT_BOLD,
            colour = 0xF2C66DFF,
            maxLines = 2,
            alignHorizontal = ui.AlignMode.CENTRE,
        })
    self.previewNote = UI.Text(
        self.root,
        "",
        self.previewX + 32,
        self.bodyY + math.floor(self.bodyHeight / 2) - 12,
        self.previewWidth - 64,
        48,
        {
            colour = 0xC9BEA4FF,
            maxLines = 2,
            alignHorizontal = ui.AlignMode.CENTRE,
        }
    )
    self.autoRotateToggle = prettyui.CheckboxButton.new(self.root, {
        {
            text = "Auto-rotate",
            value = "autoRotate",
        },
    }, {
        x = self.previewX + 10,
        y = self.bodyY + self.bodyHeight - 26,
        width = 140,
        selectionCursor = false,
        onChange = function(control) self:SetAutoRotation(control:IsSelected("autoRotate")) end,
    })
    self:UpdatePreview()
end

function TrophyTab:ResolveObject(index)
    if self.objectResolutionAttempted[index] then return self.resolvedObjects[index] end
    self.objectResolutionAttempted[index] = true
    local entry = self.entries[index]
    if entry ~= nil and type(self.options.resolveObject) == "function" then
        local object = self.options.resolveObject("Trophies", entry, index)
        self.resolvedObjects[index] = object
    end
    return self.resolvedObjects[index]
end

function TrophyTab:SetAutoRotation(enabled) self.autoRotation:SetEnabled(enabled) end

function TrophyTab:UpdatePreview()
    local entry = self.selectedIndex ~= nil and self.entries[self.selectedIndex] or nil
    if self.modelGroup ~= nil then self.modelGroup.hidden = true end
    if entry ~= nil then
        self.previewName.content = tostring(entry.label or "Trophy")
        if self:SetPreviewModel(entry, self.selectedIndex) then
            self.previewNote.content = ""
            self.previewNote.hidden = true
        else
            self.previewNote.content = "Model preview unavailable for this trophy."
            self.previewNote.hidden = false
        end
    else
        self.previewName.content = "Select a trophy"
        self.previewNote.content = "Choose a trophy from the catalogue."
        self.previewNote.hidden = false
    end
    self.previewName:MoveToFront()
    self.previewNote:MoveToFront()
end

function TrophyTab:Select(index)
    if self.entries[index] == nil then return end
    self.selectedIndex = index
    if self.autoRotation:IsEnabled() then self.autoRotation:Reset() end
    self:UpdatePreview()
    self:PositionSelectionFrame()
end

function TrophyTab:PositionSelectionFrame()
    if self.selectionFrame == nil then return end
    local location = self.slotLocations[self.selectedIndex]
    if location == nil then
        self.selectionFrame.hidden = true
        return
    end
    self.selectionFrame:SetPos(location.x, location.y)
    self.selectionFrame.hidden = false
    self.selectionFrame:MoveToFront()
end

function TrophyTab:DestroyContent()
    self:SetAutoRotation(false)
    for _, grid in ipairs(self.grids) do
        grid:Destroy()
    end
    self.grids = {}
    self.slotLocations = {}
    self.entrySlots = {}
    self.selectionFrame = nil
    for _, notice in ipairs(self.manualNotice or {}) do notice:Destroy() end
    self.manualNotice = nil
    if self.catalogueScroll ~= nil then self.catalogueScroll:Destroy() end
    self.catalogueScroll = nil
    self.contentRoot = nil
end

function TrophyTab:BuildContent()
    if self.contentRoot ~= nil then return end

    self.catalogueScroll = prettyui.SimpleView.new(self.root, {
        x = self.catalogueX + 1, y = self.bodyY + 1,
        width = self.catalogueWidth - 2, height = math.max(48, self.bodyHeight - MANUAL_NOTICE_HEIGHT - 1),
        contentHeight = 48, scrollStep = SLOT_SIZE + SLOT_GAP,
    })
    self.contentRoot = self.catalogueScroll.content
    self.contentRoot.clickthrough = true

    local rowWidth = self.contentRoot.width
    local gridWidth = math.max(SLOT_SIZE, rowWidth - 24)
    local columns = math.max(1, math.floor((gridWidth + SLOT_GAP) / (SLOT_SIZE + SLOT_GAP)))
    local rows = math.ceil(#self.entries / columns)
    local gridHeight = rows > 0 and 8 + rows * SLOT_SIZE + math.max(0, rows - 1) * SLOT_GAP or 48
    local bodyHeight = math.max(self.catalogueScroll.height, gridHeight + 12)
    self.catalogueScroll:SetContentHeight(bodyHeight)

    UI.Rectangle(self.contentRoot, 0, 0, rowWidth, bodyHeight, ProgressStyle.ROW_ODD)

    for first = 1, #self.entries, columns do
        local last = math.min(first + columns - 1, #self.entries)
        local rowEntries = {}
        for index = first, last do
            local entry = self.entries[index]
            local object = self:ResolveObject(index)
            local tooltip = tostring(entry.label or "Trophy")
            if type(self.options.tooltip) == "function" then
                tooltip = self.options.tooltip(object, entry)
            end
            rowEntries[#rowEntries + 1] = {
                object = object,
                tooltip = tooltip,
            }
        end

        local row = math.floor((first - 1) / columns)
        local gridX = GRID_PADDING
        local gridY = 4 + row * (SLOT_SIZE + SLOT_GAP)
        local grid = ItemGrid.new(self.contentRoot, rowEntries, {
            x = gridX,
            y = gridY,
            columns = #rowEntries,
            slotGap = SLOT_GAP,
            quantityMode = QUANTITY_MODE,
            _onScrollWheel = self.catalogueScroll._onScrollWheel,
        })
        self.grids[#self.grids + 1] = grid

        for index = first, last do
            local slotIndex = index - first + 1
            local slot = grid:GetSlot(slotIndex)
            if slot ~= nil then
                local itemIndex = index
                self.slotLocations[itemIndex] = {
                    x = gridX + (slot.root.x or 0),
                    y = gridY,
                }
                self.entrySlots[itemIndex] = slot
                slot:SetDisabled(not self:IsTrophyCollected(itemIndex))
                slot.root:Subscribe(ui.Hook.ONCLICK, function()
                    self:Select(itemIndex)
                    return false
                end)
            end
        end
    end

    if #self.entries == 0 then
        UI.Text(
            self.contentRoot,
            "No trophies are mapped.",
            14,
            8,
            rowWidth - 28,
            32,
            { colour = 0xC9BEA4FF }
        )
    end

    local noticeY = self.bodyY + self.bodyHeight - MANUAL_NOTICE_HEIGHT + 4
    local noticeWidth = rowWidth - GRID_PADDING * 2
    self.manualNotice = {
        UI.Text(
            self.root,
            "Trophy ownership cannot be read from the client.",
            self.catalogueX + GRID_PADDING,
            noticeY,
            noticeWidth,
            17,
            { colour = 0x9A907FFF, alignHorizontal = ui.AlignMode.CENTRE }
        ),
        UI.Text(
            self.root,
            "Right-click a trophy to mark it found.",
            self.catalogueX + GRID_PADDING,
            noticeY + 17,
            noticeWidth,
            17,
            { colour = 0x9A907FFF, alignHorizontal = ui.AlignMode.CENTRE }
        ),
    }

    self.selectionFrame = selectionFrame(self.contentRoot)
    self:PositionSelectionFrame()
end

function TrophyTab:Destroy()
    self:UnsubscribeMiniMenu()
    self:DestroyContent()
    if self.autoRotation ~= nil then self.autoRotation:Destroy() end
    self.autoRotation = nil
    if self.autoRotateToggle ~= nil then self.autoRotateToggle:Destroy() end
    self.autoRotateToggle = nil
    self.catalogueCountLabel = nil
    self.manualNotice = nil
    if self.root ~= nil then self.root:Destroy() end
    self.root = nil
end

return TrophyTab
