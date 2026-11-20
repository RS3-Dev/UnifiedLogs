-- Render the completion cape overview
local UI = require("Resources/Shared/ui/components")
local CapeRequirements = require("Resources/Features/achievements/cape_requirements")
local CapeModelCanvas = require("Resources/Features/achievements/cape_model_canvas")

local CapeOverview = {}
CapeOverview.__index = CapeOverview

local GOLD = 0xF2C66DFF
local MUTED = 0x928776FF
local COUNT_TEXT = 0xF2E8D5FF
local GREEN = 0x1A3826FF
local BAR_BACKGROUND = 0x0D0C09FF
local HEADER_BACKGROUND = 0x2A231BFF
local HEADER_DIVIDER = 0x574936FF
local CARD_BACKGROUND = 0x211E1BFF
local CARD_HOVER = 0x2A2622FF
local CARD_BORDER = 0x806432FF
local CARD_GAP = 7
local OUTER_INSET = 10
local TITLE_HEIGHT = 30
local COUNT_HEIGHT = 22
local PROGRESS_HEIGHT = 6
local BASE_MODEL_SCALE = 1.25
local MODEL_GROWTH = 1.15
local MODEL_EVENT = "unifiedlogs_cape_models"
local SUMMARY_EVENT = "unifiedlogs_cape_summaries"
local SUMMARY_CACHE = setmetatable({}, { __mode = "k" })

local function summaryFor(self, cape)
    if self.summaryLoader then
        return self.summaryLoader.summaries[cape] or { complete = 0, total = 0, pending = 1 }
    end
    return CapeRequirements.Summary(cape, self.options.snapshot)
end

-- Create a clickable cape card
local function clickableCard(parent, x, y, width, height, action)
    local root = UI.ContentLayer(parent)
    root:SetPos(x, y)
    root:SetSize(width, height)
    root.clickthrough = false
    local background = UI.Rectangle(root, 0, 0, width, height, CARD_BACKGROUND)
    background:MoveToBack()
    root:Subscribe(ui.Hook.ONMOUSEOVER, function()
        background.rgba = CARD_HOVER
        return true
    end)
    root:Subscribe(ui.Hook.ONMOUSELEAVE, function()
        background.rgba = CARD_BACKGROUND
        return true
    end)
    root:Subscribe(ui.Hook.ONCLICK, function()
        if type(action) == "function" then action() end
        return false
    end)
    return {
        root = root,
        Destroy = function(self)
            if self.root ~= nil then self.root:Destroy() end
            self.root = nil
        end,
    }
end

function CapeOverview.new(parent, options)
    local self = setmetatable({}, CapeOverview)
    self.options = options
    self.root = UI.ContentLayer(parent)
    self.root:SetPos(self.options.x or 0, self.options.y or 0)
    self.root:SetSize(self.options.width, self.options.height)
    self.root.clickthrough = true
    self.controls = {}
    self.modelCanvases = {}
    self.pendingModels = {}
    self.progressCards = {}
    if options.asyncSummary then
        local owner = options.cacheOwner or self
        local key = tostring(options.playerID or "unknown") .. ":" .. (options.orderView == "tree" and "tree" or "linear")
        SUMMARY_CACHE[owner] = SUMMARY_CACHE[owner] or {}
        SUMMARY_CACHE[owner][key] = SUMMARY_CACHE[owner][key] or {}
        self.summaryCache = SUMMARY_CACHE[owner][key]
        self:RefreshAccountState()
    end
    self:Build()
    self:LoadModels()
    return self
end

-- Keep cached percentages visible while fresh achievement states load.
function CapeOverview:RefreshAccountState()
    if not self.summaryCache then return end
    self.summaryLoader = CapeRequirements.NewSummaryLoader(
        self.options.capes or {}, self.options.orderView, self.summaryCache)
    Event.Logic.Unsubscribe(SUMMARY_EVENT)
    Event.Logic.Subscribe(SUMMARY_EVENT, function()
        if self.options.isVisible and not self.options.isVisible() then return end
        local pending, changed = self.summaryLoader:Tick()
        if changed then self:RefreshProgress() end
        if not pending then Event.Logic.Unsubscribe(SUMMARY_EVENT) end
    end)
end

function CapeOverview:Build()
    local width, height = self.root.width, self.root.height
    local capes = self.options.capes or {}
    local availableWidth = width - OUTER_INSET * 2 - CARD_GAP * math.max(0, #capes - 1)
    local cardWidth = math.max(96, math.floor(availableWidth / math.max(1, #capes)))
    local originalCardHeight = math.max(180, math.floor((height - 76) * 0.75))
    local cardHeight = originalCardHeight + PROGRESS_HEIGHT
    local cardY = math.max(0, math.floor((height - originalCardHeight) / 2))
    for index, cape in ipairs(capes) do
        local cardX = OUTER_INSET + (index - 1) * (cardWidth + CARD_GAP)
        local control = clickableCard(self.root, cardX, cardY, cardWidth, cardHeight, function()
            if type(self.options.onSelect) == "function" then self.options.onSelect(cape.mode) end
        end)
        self.controls[#self.controls + 1] = control

        local titleY = 1
        local progressY = cardHeight - PROGRESS_HEIGHT
        local countY = progressY - COUNT_HEIGHT
        local modelX, modelY = 8, TITLE_HEIGHT + 8
        local modelWidth = cardWidth - 16
        local modelHeight = math.max(80, countY - modelY - 2)
        local formerModelHeight = math.max(100, height - 178)
        local modelScale = BASE_MODEL_SCALE * MODEL_GROWTH * formerModelHeight / modelHeight
        -- Reserve the model layer now so the card chrome still draws above it
        local slot = UI.ContentLayer(control.root)
        slot:SetPos(modelX, modelY)
        slot:SetSize(modelWidth, modelHeight)
        slot.clickthrough = true
        self.pendingModels[#self.pendingModels + 1] = {
            slot = slot,
            cape = cape,
            options = {
                width = modelWidth,
                height = modelHeight,
                scale = modelScale,
                verticalShift = 72,
            },
        }

        UI.Rectangle(control.root, 1, titleY, cardWidth - 2, TITLE_HEIGHT, HEADER_BACKGROUND)
        UI.Rectangle(control.root, 1, titleY + TITLE_HEIGHT - 1, cardWidth - 2, 1, HEADER_DIVIDER)
        UI.Text(control.root, cape.label, 6, titleY, cardWidth - 12, TITLE_HEIGHT, {
            font = id.Font.MUSEO_SANS_13PT_BOLD,
            colour = GOLD,
            alignHorizontal = ui.AlignMode.CENTRE,
        })
        local summaryText = "—"
        local progressX, progressWidth = 1, cardWidth - 2
        UI.Rectangle(control.root, progressX, countY, progressWidth, COUNT_HEIGHT, BAR_BACKGROUND)
        UI.Rectangle(
            control.root,
            progressX,
            progressY,
            progressWidth,
            PROGRESS_HEIGHT,
            BAR_BACKGROUND
        )
        local fill = UI.Rectangle(control.root, progressX, progressY, 0, PROGRESS_HEIGHT, GOLD)
        local label = UI.Text(control.root, summaryText, 6, countY, cardWidth - 12, COUNT_HEIGHT, {
            font = id.Font.MUSEO_SANS_11PT_REGULAR,
            colour = COUNT_TEXT,
            alignHorizontal = ui.AlignMode.CENTRE,
        })
        self.progressCards[#self.progressCards + 1] = {
            cape = cape, fill = fill, label = label, width = progressWidth,
        }
        UI.Frame(control.root, 0, 0, cardWidth, cardHeight, { colour = CARD_BORDER })
    end
    self:RefreshProgress()
end

-- Repaint progress bars without recreating models or cape cards.
function CapeOverview:RefreshProgress()
    for _, card in ipairs(self.progressCards) do
        local summary = summaryFor(self, card.cape)
        card.label.content = summary.label or (summary.pending or 0) > 0 and "Loading..."
            or summary.available and summary.total > 0 and tostring(summary.complete) .. " / " .. tostring(summary.total)
            or "—"
        local width = summary.total > 0 and math.floor(card.width * summary.complete / summary.total) or 0
        if summary.complete > 0 then width = math.max(1, width) end
        card.fill:SetSize(width, PROGRESS_HEIGHT)
        card.fill.hidden = width == 0
        card.fill.rgba = summary.complete >= summary.total and GREEN or GOLD
    end
end

-- Create one cape model per client tick so the cards appear first
function CapeOverview:LoadModels()
    local index = 0
    Event.Logic.Unsubscribe(MODEL_EVENT)
    Event.Logic.Subscribe(MODEL_EVENT, function()
        index = index + 1
        local pending = self.pendingModels[index]
        if pending == nil or self.root == nil then
            Event.Logic.Unsubscribe(MODEL_EVENT)
            return
        end
        local options = pending.options
        local canvas = CapeModelCanvas.Create(pending.slot, pending.cape, options)
        if canvas ~= nil then
            self.modelCanvases[#self.modelCanvases + 1] = canvas
        else
            UI.Text(pending.slot, "MODEL UNAVAILABLE", 0, 0, options.width, options.height, {
                font = id.Font.MUSEO_SANS_11PT_REGULAR,
                colour = MUTED,
                alignHorizontal = ui.AlignMode.CENTRE,
                alignVertical = ui.AlignMode.CENTRE,
            })
        end
    end)
end

function CapeOverview:Destroy()
    Event.Logic.Unsubscribe(MODEL_EVENT)
    Event.Logic.Unsubscribe(SUMMARY_EVENT)
    for _, control in ipairs(self.controls) do
        control:Destroy()
    end
    self.controls = {}
    self.modelCanvases = {}
    self.pendingModels = {}
    if self.root ~= nil then self.root:Destroy() end
    self.root = nil
end

return CapeOverview
