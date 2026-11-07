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
    self.root = ui.Layer.new(parent)
    self.root:SetPos(self.options.x or 0, self.options.y or 0)
    self.root:SetSize(self.options.width, self.options.height)
    self.root.clickthrough = false
    self:Build()
    self.root:MoveToFront()
    return self
end

function AchievementGuidePanel:Build()
    local width, height = self.root.width, self.root.height
    UI.Rectangle(self.root, 0, 0, width, height, BACKGROUND)
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

    UI.Text(self.root, self.guide.description, 12, HEADER_HEIGHT + 4, width - 24, 48, {
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
    UI.Text(self.root, progress, width - 124, sectionY, 112, SECTION_HEIGHT, {
        font = id.Font.MUSEO_SANS_11PT_REGULAR,
        colour = self.guide.achievementComplete and ProgressStyle.PROGRESS_COMPLETE
            or ProgressStyle.PROGRESS_ACTIVE,
        alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
    })

    local scrollY = sectionY + SECTION_HEIGHT
    local scrollHeight = math.max(60, height - scrollY)
    local contentHeight = math.max(scrollHeight, #self.guide.entries * ROW_HEIGHT)
    self.scroll = prettyui.SimpleView.new(self.root, {
        x = 0,
        y = scrollY,
        width = width,
        height = scrollHeight,
        contentHeight = contentHeight,
        scrollable = true,
        scrollStep = ROW_HEIGHT,
    })
    local rowWidth =
        math.max(120, math.min(self.scroll.content.width, self.scroll.width - SCROLLBAR_GUTTER))
    for index, entry in ipairs(self.guide.entries) do
        local y = (index - 1) * ROW_HEIGHT
        UI.Rectangle(
            self.scroll.content,
            0,
            y,
            rowWidth,
            ROW_HEIGHT,
            ProgressStyle.RowColour(index)
        )
        UI.Rectangle(
            self.scroll.content,
            0,
            y + ROW_HEIGHT - 1,
            rowWidth,
            1,
            ProgressStyle.ROW_DIVIDER
        )
        if entry.complete == true then
            ProgressStyle.Wedge(self.scroll.content, 1, y + 1, ROW_HEIGHT - 2)
        end
        UI.Text(self.scroll.content, entry.text, 12, y, rowWidth - 46, ROW_HEIGHT, {
            font = id.Font.MUSEO_SANS_11PT_REGULAR,
            colour = entry.complete == true and ProgressStyle.TEXT_COMPLETE
                or ProgressStyle.TEXT_NORMAL,
            maxLines = 2,
        })
        ProgressStyle.CompletionMark(
            self.scroll.content,
            rowWidth - 26,
            y + math.floor((ROW_HEIGHT - 14) / 2),
            entry.complete == true
        )
    end
    ProgressStyle.Frame(self.root, 0, 0, width, height)
end

function AchievementGuidePanel:Destroy()
    if self.scroll ~= nil then self.scroll:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.scroll = nil
    self.root = nil
end

return AchievementGuidePanel
