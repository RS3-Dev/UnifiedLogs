-- Render the achievement guide panel
local UI = require("Resources/Shared/ui/components")
local ProgressStyle = require("Resources/Shared/ui/progress_style")

local AchievementGuidePanel = {}
AchievementGuidePanel.__index = AchievementGuidePanel

local HEADER_HEIGHT = 36
local SUMMARY_HEIGHT = 60
local SECTION_HEIGHT = 28
local ROW_HEIGHT = 42
local SCROLLBAR_GUTTER = 18
local GOLD = 0xF2C66DFF
local MUTED = 0x928776FF
local BACKGROUND = 0x17140FFF

function AchievementGuidePanel.new(parent, guide, options)
    local self = setmetatable({}, AchievementGuidePanel)
    self.guide = guide
    self.options = options
    self.root = UI.ContentLayer(parent)
    self.root:SetPos(self.options.x or 0, self.options.y or 0)
    self.root:SetSize(self.options.width, self.options.height)
    self.root.clickthrough = false
    self:Build()
    self.root:MoveToFront()
    return self
end

function AchievementGuidePanel:Build()
    local width, height = self.root.width, self.root.height
    self.background = UI.Rectangle(self.root, 0, 0, width, height, BACKGROUND)
    self.background:MoveToBack()
    UI.Rectangle(self.root, 0, 0, width, HEADER_HEIGHT, ProgressStyle.GROUP_BACKGROUND)
    UI.Text(self.root, self.guide.name, 12, 0, width - 50, HEADER_HEIGHT, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = GOLD,
    })
    self.close = UI.ClickableText(self.root, "×", width - 38, 0, 30, HEADER_HEIGHT, {
        font = id.Font.MUSEO_SANS_15PT_BOLD,
        colour = MUTED,
        hoverColour = 0xFFFFFFFF,
        alignHorizontal = ui.AlignMode.CENTRE,
        action = self.options.onClose,
    })

    UI.Text(self.root, ((self.guide.runeScore or 0) > 0 and tostring(self.guide.runeScore) .. " RuneScore<br>" or "") .. self.guide.description, 12, HEADER_HEIGHT + 4, width - 24, 48, {
        font = id.Font.MUSEO_SANS_11PT_REGULAR,
        colour = ProgressStyle.TEXT_NORMAL,
        alignVertical = ui.AlignMode.TOPLEFT,
        maxLines = 3,
    })
    if #self.guide.entries == 0 then
        ProgressStyle.Frame(self.root, 0, 0, width, height)
        return
    end

    local sectionY = HEADER_HEIGHT + SUMMARY_HEIGHT
    UI.Rectangle(self.root, 0, sectionY, width, SECTION_HEIGHT, ProgressStyle.GROUP_BACKGROUND)
    UI.Text(self.root, "Requirements", 12, sectionY, width - 136, SECTION_HEIGHT, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = GOLD,
    })
    local progress = self.guide.total > 0
            and tostring(self.guide.complete) .. " / " .. tostring(self.guide.total)
        or (self.guide.achievementComplete and "Complete" or "Incomplete")
    self.progressText = UI.Text(self.root, progress, width - 124, sectionY, 112, SECTION_HEIGHT, {
        font = id.Font.MUSEO_SANS_11PT_REGULAR,
        colour = self.guide.achievementComplete and ProgressStyle.PROGRESS_COMPLETE
            or ProgressStyle.PROGRESS_ACTIVE,
        alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
    })

    local scrollY = sectionY + SECTION_HEIGHT
    local scrollHeight = math.max(60, height - scrollY)
    local contentHeight = math.max(scrollHeight, #self.guide.entries * ROW_HEIGHT)
    self.scroll = prettyui.SimpleView.new(self.root, {
        categoryID = "auto",
        x = 0,
        y = scrollY,
        width = width,
        height = scrollHeight,
        contentHeight = contentHeight,
        scrollable = true,
        scrollStep = ROW_HEIGHT,
    })
    self.rowPool = {}
    self.scroll.onLayout = function() self:RefreshRows() end
    self:RefreshRows()
    self:UpdateProgress()
    self:StartProgress()
    ProgressStyle.Frame(self.root, 0, 0, width, height)
end

-- The guide can contain thousands of requirements; retain only viewport rows.
function AchievementGuidePanel:RefreshRows()
    if self.scroll == nil then return end
    local first = math.max(1, math.floor(self.scroll.scrollY / ROW_HEIGHT))
    local last = math.min(#self.guide.entries, math.ceil((self.scroll.scrollY + self.scroll.height) / ROW_HEIGHT) + 1)
    local needed = math.max(0, last - first + 1)
    local width = math.max(120, math.min(self.scroll.content.width, self.scroll.width - SCROLLBAR_GUTTER))
    self.visibleEntries = {}
    while #self.rowPool < needed do
        local root = UI.ContentLayer(self.scroll.content)
        root:SetSize(width, ROW_HEIGHT)
        root.clickthrough = true
        local slot = { root = root }
        slot.background = UI.Rectangle(root, 0, 0, width, ROW_HEIGHT, 0)
        slot.background:MoveToBack()
        slot.divider = UI.Rectangle(root, 0, ROW_HEIGHT - 1, width, 1, ProgressStyle.ROW_DIVIDER)
        slot.wedge = ProgressStyle.Wedge(root, 1, 1, ROW_HEIGHT - 2)
        slot.text = UI.Text(root, "", 12, 0, width - 46, ROW_HEIGHT, {
            font = id.Font.MUSEO_SANS_11PT_REGULAR, maxLines = 2,
        })
        slot.mark = ProgressStyle.CompletionMark(root, width - 26, math.floor((ROW_HEIGHT - 14) / 2), false)
        UI.ForwardScrollWheel(root, self.scroll)
        self.rowPool[#self.rowPool + 1] = slot
    end
    for offset, slot in ipairs(self.rowPool) do
        local index = first + offset - 1
        local entry = offset <= needed and self.guide.entries[index] or nil
        slot.root.hidden = entry == nil
        if entry then
            self.visibleEntries[#self.visibleEntries + 1] = entry
            if slot.entry ~= entry or slot.loaded ~= entry.loaded or slot.complete ~= entry.complete then
                slot.root:SetPos(0, (index - 1) * ROW_HEIGHT)
                slot.background.rgba = ProgressStyle.RowColour(index)
                slot.text.content = entry.text
                slot.text.rgba = entry.complete == true and ProgressStyle.TEXT_COMPLETE or ProgressStyle.TEXT_NORMAL
                slot.wedge.hidden = entry.complete ~= true
                ProgressStyle.SetCompletionMark(slot.mark, entry.complete == true)
                if entry.complete == nil then slot.mark.hidden = true end
                slot.entry, slot.loaded, slot.complete = entry, entry.loaded, entry.complete
            end
        else slot.entry = nil end
    end
end

function AchievementGuidePanel:UpdateProgress()
    if self.progressText == nil then return end
    local complete, pending, unknown = 0, 0, 0
    for _, entry in ipairs(self.guide.entries) do
        if entry.complete == true then complete = complete + 1 end
        if entry.loaded == false then pending = pending + 1
        elseif entry.complete == nil then unknown = unknown + 1 end
    end
    self.guide.complete = complete
    self.progressText.content = pending > 0 and "Loading..." or unknown > 0 and "Unknown"
        or tostring(complete) .. " / " .. tostring(self.guide.total)
end

-- Read visible states first; shared variables are cached by the guide evaluator.
function AchievementGuidePanel:StartProgress()
    local event = "unifiedlogs_achievement_guide_progress"
    self.progressEvent = event
    local pending = false
    for _, entry in ipairs(self.guide.entries) do if entry.loaded == false then pending = true; break end end
    if not pending then return end
    local cursor = 1
    Event.Logic.Subscribe(event, function()
        if self.stopped or self.options.isVisible and not self.options.isVisible() then return end
        local read = 0
        local function update(entry)
            if entry.loaded ~= false then return end
            entry.complete, entry.loaded = entry.resolve(), true
            read = read + 1
        end
        for _, entry in ipairs(self.visibleEntries) do if read >= 8 then break end; update(entry) end
        local background = 0
        while cursor <= #self.guide.entries and background < 4 do
            local entry = self.guide.entries[cursor]
            cursor = cursor + 1
            if entry.loaded == false then update(entry); background = background + 1 end
        end
        if cursor > #self.guide.entries then Event.Logic.Unsubscribe(event) end
        if read > 0 then self:UpdateProgress(); self:RefreshRows() end
    end)
end

function AchievementGuidePanel:Destroy()
    self.stopped = true
    if self.progressEvent then Event.Logic.Unsubscribe(self.progressEvent) end
    if self.scroll ~= nil then self.scroll:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.scroll = nil
    self.root = nil
end

return AchievementGuidePanel
