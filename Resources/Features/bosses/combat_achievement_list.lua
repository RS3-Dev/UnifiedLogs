-- Render the combat achievement list
local UI = require("Resources/Shared/ui/components")
local CombatAchievementList = {}
CombatAchievementList.__index = CombatAchievementList

local ProgressStyle = require("Resources/Shared/ui/progress_style")

-- Set achievement list visibility
local function setVisible(component, visible) component.hidden = not visible end

function CombatAchievementList:_CreateSlot()
    local parent = ui.Layer.new(self.scroll.content)
    parent.clickthrough = true
    local slot = {
        root = parent,
        background = ui.Rectangle.new(parent),
        primary = ui.Text.new(parent),
        primaryContinuation = ui.Text.new(parent),
        secondary = ui.Text.new(parent),
        secondaryContinuation = ui.Text.new(parent),
        secondaryFinal = ui.Text.new(parent),
        progress = ui.Text.new(parent),
        marker = ui.Text.new(parent),
        completionMark = ProgressStyle.CompletionMark(parent, 0, 0, false),
        wedge = ui.Rectangle.new(parent),
        borderTop = ui.Rectangle.new(parent),
        borderBottom = ui.Rectangle.new(parent),
        borderLeft = ui.Rectangle.new(parent),
        borderRight = ui.Rectangle.new(parent),
        hitbox = ui.Button.new(parent),
        group = nil,
        baseColour = 0x332A1FFF,
    }

    slot.background.fill = true
    slot.background.clickthrough = true
    slot.primary.clickthrough = true
    slot.primaryContinuation.clickthrough = true
    slot.secondary.clickthrough = true
    slot.secondaryContinuation.clickthrough = true
    slot.secondaryFinal.clickthrough = true
    slot.progress.clickthrough = true
    slot.marker.clickthrough = true
    slot.wedge.fill = true
    slot.wedge.clickthrough = true
    for _, border in ipairs({
        slot.borderTop,
        slot.borderBottom,
        slot.borderLeft,
        slot.borderRight,
    }) do
        border.fill = true
        border.clickthrough = true
    end
    slot.hitbox.text.content = ""
    slot.hitbox.alpha = 0
    slot.hitbox.clickthrough = false

    slot.hitbox:Subscribe(ui.Hook.ONMOUSEOVER, function()
        if slot.group ~= nil then slot.background.rgba = 0x493B2BFF end
    end)
    slot.hitbox:Subscribe(
        ui.Hook.ONMOUSELEAVE,
        function() slot.background.rgba = slot.baseColour end
    )
    slot.hitbox:Subscribe(ui.Hook.ONCLICK, function()
        if slot.group ~= nil and self.onToggle ~= nil then self.onToggle(slot.group) end
        return false
    end)

    self.pool[#self.pool + 1] = slot
    return slot
end

function CombatAchievementList:_HideSlot(slot)
    slot.group = nil
    slot.root.hidden = true
    setVisible(slot.background, false)
    setVisible(slot.primary, false)
    setVisible(slot.primaryContinuation, false)
    setVisible(slot.secondary, false)
    setVisible(slot.secondaryContinuation, false)
    setVisible(slot.secondaryFinal, false)
    setVisible(slot.progress, false)
    setVisible(slot.marker, false)
    setVisible(slot.completionMark, false)
    setVisible(slot.wedge, false)
    setVisible(slot.borderTop, false)
    setVisible(slot.borderBottom, false)
    setVisible(slot.borderLeft, false)
    setVisible(slot.borderRight, false)
    setVisible(slot.hitbox, false)
    slot.hitbox.clickthrough = true
end

function CombatAchievementList:_RenderSlot(slot, row)
    slot.root:SetPos(0, row.y)
    slot.root:SetSize(self.rowWidth, row.height)
    slot.root.hidden = false
    local y = 0
    local fonts = self.fonts
    slot.group = nil
    local greenComplete = row.kind == "header" and row.count > 0 and row.complete == row.count
        or row.kind == "achievement" and row.complete == true
    slot.baseColour = ProgressStyle.Green(greenComplete, row.colour or 0x00000000,
        row.kind == "header" and ProgressStyle.GREEN_HEADER or ProgressStyle.GREEN_BACKGROUND)
    slot.background:SetPos(0, y)
    slot.background:SetSize(self.rowWidth, row.height)
    slot.background.rgba = slot.baseColour
    setVisible(slot.background, row.kind ~= "empty")
    setVisible(slot.progress, false)
    setVisible(slot.primaryContinuation, false)
    setVisible(slot.secondaryContinuation, false)
    setVisible(slot.secondaryFinal, false)
    setVisible(slot.completionMark, false)
    setVisible(slot.wedge, false)
    setVisible(slot.borderTop, false)
    setVisible(slot.borderBottom, false)
    setVisible(slot.borderLeft, false)
    setVisible(slot.borderRight, false)

    if row.kind == "header" then
        UI.BindText(slot.primary, row.group, 12, y, self.rowWidth - 178, row.height, {
            font = fonts.header,
            colour = ProgressStyle.Green(greenComplete, 0xF2C66DFF, 0xF2C66DFF),
            maxLines = 1,
            alignHorizontal = ui.AlignMode.TOPLEFT,
            alignVertical = ui.AlignMode.CENTRE,
        })
        UI.BindText(
            slot.progress,
            tostring(row.complete or 0) .. " / " .. tostring(row.count),
            self.rowWidth - 156,
            y,
            96,
            row.height,
            {
                font = fonts.marker,
                colour = ProgressStyle.Green(greenComplete, row.complete == row.count
                        and row.count > 0
                        and ProgressStyle.PROGRESS_COMPLETE
                    or ProgressStyle.PROGRESS_ACTIVE, 0xF2C66DFF),
                maxLines = 1,
                alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
                alignVertical = ui.AlignMode.CENTRE,
            }
        )
        local complete = row.complete == row.count and row.count > 0
        ProgressStyle.PositionCompletionMark(
            slot.completionMark,
            self.rowWidth - 52,
            y + math.floor((row.height - 14) / 2)
        )
        ProgressStyle.SetCompletionMark(slot.completionMark, complete)
        slot.completionMark:MoveToFront()
        UI.BindText(
            slot.marker,
            row.collapsed and "+" or "-",
            self.rowWidth - 30,
            y,
            18,
            row.height,
            {
                font = fonts.marker,
                colour = 0xF2C66DFF,
                maxLines = 1,
                alignHorizontal = ui.AlignMode.CENTRE,
                alignVertical = ui.AlignMode.CENTRE,
            }
        )
        setVisible(slot.secondary, false)
        UI.BindRectangle(slot.borderTop, 0, y, self.rowWidth, 1, ProgressStyle.GROUP_BORDER)
        UI.BindRectangle(slot.borderLeft, 0, y, 1, row.height, ProgressStyle.GROUP_BORDER)
        UI.BindRectangle(
            slot.borderRight,
            self.rowWidth - 1,
            y,
            1,
            row.height,
            ProgressStyle.GROUP_BORDER
        )
        UI.BindRectangle(
            slot.borderBottom,
            0,
            y + row.height - 1,
            self.rowWidth,
            1,
            row.groupEnd and ProgressStyle.GROUP_BORDER or ProgressStyle.GROUP_DIVIDER
        )
        slot.group = row.group
        slot.hitbox:SetPos(0, y)
        slot.hitbox:SetSize(self.rowWidth, row.height)
        slot.hitbox.clickthrough = false
        setVisible(slot.hitbox, true)
        slot.hitbox:MoveToFront()
        return
    end

    setVisible(slot.marker, false)
    setVisible(slot.hitbox, false)
    slot.hitbox.clickthrough = true

    if row.kind == "empty" then
        UI.BindText(slot.primary, row.message, 14, y, self.rowWidth - 28, row.height, {
            font = fonts.body,
            colour = 0xC9BEA4FF,
            maxLines = 1,
            alignHorizontal = ui.AlignMode.TOPLEFT,
            alignVertical = ui.AlignMode.CENTRE,
        })
        setVisible(slot.secondary, false)
        return
    end

    local nameComponents = { slot.primary, slot.primaryContinuation }
    local descriptionComponents = {
        slot.secondary,
        slot.secondaryContinuation,
        slot.secondaryFinal,
    }
    local nameLines = row.nameLineValues or { row.achievement.name }
    local descriptionLines = row.descriptionLineValues or { row.achievement.description }
    for index, component in ipairs(nameComponents) do
        local value = nameLines[index]
        if value ~= nil then
            UI.BindText(
                component,
                value,
                12,
                y + 4 + (index - 1) * self.lineHeight,
                self.nameWidth - 20,
                self.lineHeight,
                {
                    font = fonts.name,
                    colour = row.complete and ProgressStyle.TEXT_COMPLETE
                        or ProgressStyle.TEXT_NORMAL,
                    maxLines = 1,
                    alignHorizontal = ui.AlignMode.TOPLEFT,
                    alignVertical = ui.AlignMode.TOPLEFT,
                }
            )
        else
            setVisible(component, false)
        end
    end
    for index, component in ipairs(descriptionComponents) do
        local value = descriptionLines[index]
        if value ~= nil then
            UI.BindText(
                component,
                value,
                self.nameWidth,
                y + 4 + (index - 1) * self.lineHeight,
                self.rowWidth - self.nameWidth - 40,
                self.lineHeight,
                {
                    font = fonts.body,
                    colour = 0xC9BEA4FF,
                    maxLines = 1,
                    alignHorizontal = ui.AlignMode.TOPLEFT,
                    alignVertical = ui.AlignMode.TOPLEFT,
                }
            )
        else
            setVisible(component, false)
        end
    end
    ProgressStyle.PositionCompletionMark(
        slot.completionMark,
        self.rowWidth - 26,
        y + math.floor((row.height - 14) / 2)
    )
    ProgressStyle.SetCompletionMark(slot.completionMark, row.complete)
    slot.completionMark:MoveToFront()
    if row.complete then
        UI.BindRectangle(
            slot.wedge,
            1,
            y + 1,
            ProgressStyle.COMPLETE_WEDGE_WIDTH,
            row.height - 2,
            ProgressStyle.COMPLETE_WEDGE
        )
        slot.wedge:MoveToFront()
    end
    UI.BindRectangle(slot.borderLeft, 0, y, 1, row.height, ProgressStyle.GROUP_BORDER)
    UI.BindRectangle(
        slot.borderRight,
        self.rowWidth - 1,
        y,
        1,
        row.height,
        ProgressStyle.GROUP_BORDER
    )
    UI.BindRectangle(
        slot.borderBottom,
        0,
        y + row.height - 1,
        self.rowWidth,
        1,
        row.groupEnd and ProgressStyle.GROUP_BORDER or ProgressStyle.ROW_DIVIDER
    )
end

-- Refresh achievement list rows
function CombatAchievementList:Refresh()
    if self.scroll == nil or self.scroll.root == nil then return end
    local overscan = self.rowHeight
    local visibleTop = math.max(0, self.scroll.scrollY - overscan)
    local visibleBottom = self.scroll.scrollY + self.scroll.height + overscan
    local visible = {}

    for _, row in ipairs(self.rows) do
        if row.y < visibleBottom and row.y + row.height > visibleTop then
            visible[#visible + 1] = row
        end
    end

    while #self.pool < #visible do
        self:_CreateSlot()
    end
    for index, slot in ipairs(self.pool) do
        local row = visible[index]
        if row ~= nil then
            self:_RenderSlot(slot, row)
        else
            self:_HideSlot(slot)
        end
    end
end

function CombatAchievementList.new(parent, prettyui, options)
    local self = setmetatable({
        onToggle = options.onToggle,
        rowHeight = options.rowHeight,
        lineHeight = options.lineHeight or 17,
        nameWidth = options.nameWidth,
        fonts = options.fonts,
        rows = {},
        pool = {},
        rowWidth = 300,
    }, CombatAchievementList)

    self.scroll = prettyui.SimpleView.new(parent, {
        x = options.x,
        y = options.y,
        width = options.width,
        height = options.height,
        contentHeight = options.height,
        scrollStep = options.rowHeight,
    })
    self.scroll.onLayout = function() self:Refresh() end
    return self
end

-- Update achievement list layout
function CombatAchievementList:Update(options)
    local previousScrollY = options.preserveScroll and self.scroll.scrollY or 0
    self.rows = options.rows or {}
    self.rowWidth = options.rowWidth or self.rowWidth
    self.scroll.root:SetPos(options.x or 0, options.y or 0)
    self.scroll:SetSize(options.width, options.height)
    self.scroll:SetContentHeight(math.max(options.height, options.contentHeight or 0))
    self.scroll:SetScrollPosition(previousScrollY)
    self:Refresh()
end

function CombatAchievementList:Destroy()
    self.pool = {}
    self.rows = {}
    if self.scroll ~= nil then self.scroll:Destroy() end
    self.scroll = nil
end

return CombatAchievementList
