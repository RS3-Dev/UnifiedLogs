-- Render the combat achievements tab
local CombatAchievementsTab = {}
CombatAchievementsTab.__index = CombatAchievementsTab

local Settings = require("Resources/Lib/settings")
local CombatAchievementList = require("Resources/Features/bosses/combat_achievement_list")
local ProgressStyle = require("Resources/Shared/ui/progress_style")
local UI = require("Resources/Shared/ui/components")

local HEADER_HEIGHT = 112
local MIN_ROW_HEIGHT = 32
local LINE_HEIGHT = 17
local VERTICAL_PADDING = 8
local NAME_WIDTH = 238

local TIER_FILTERS = {
    { label = "All tiers", id = 0, order = 0 },
    { label = "Easy", id = 1, order = 1 },
    { label = "Medium", id = 2, order = 2 },
    { label = "Hard", id = 3, order = 3 },
    { label = "Elite", id = 4, order = 4 },
    { label = "Master", id = 5, order = 5 },
    { label = "Grandmaster", id = 6, order = 6 },
}

local STATUS_FILTERS = {
    { label = "All statuses", id = Settings.STATUS_ALL, order = 0 },
    { label = "Complete", id = Settings.STATUS_COMPLETE, order = 1 },
    { label = "Incomplete", id = Settings.STATUS_INCOMPLETE, order = 2 },
}

-- Measure wrapped text width
local function measuredWidth(font, value)
    if font ~= nil and font.GetStringWidth ~= nil then
        local ok, width = pcall(
            function() return font:GetStringWidth(tostring(value or ""), false) end
        )
        if ok and type(width) == "number" then return width end
    end
    return #tostring(value or "") * 7
end

-- Wrap text into display lines
local function wrappedLines(value, font, width, maxLines)
    local content = tostring(value or "")
    if content == "" then return { "" } end
    local lines = {}
    local current = ""
    for word in string.gmatch(content, "%S+") do
        local candidate = current == "" and word or (current .. " " .. word)
        if current ~= "" and measuredWidth(font, candidate) > width then
            lines[#lines + 1] = current
            current = word
            if #lines >= maxLines then return lines end
        else
            current = candidate
        end
    end
    if current ~= "" and #lines < maxLines then lines[#lines + 1] = current end
    if #lines == 0 then lines[1] = content end
    return lines
end

-- Calculate achievement row dimensions
local function rowMetrics(achievement, rowWidth)
    local nameFont = config ~= nil and config.Font ~= nil and config.Font.MUSEO_SANS_13PT_BOLD
        or nil
    local bodyFont = config ~= nil and config.Font ~= nil and config.Font.MUSEO_SANS_13PT_REGULAR
        or nil
    local nameLines = wrappedLines(achievement.name, nameFont, NAME_WIDTH - 20, 2)
    local descriptionLines =
        wrappedLines(achievement.description, bodyFont, math.max(40, rowWidth - NAME_WIDTH - 40), 3)
    local lines = math.max(#nameLines, #descriptionLines)
    local height = math.max(MIN_ROW_HEIGHT, VERTICAL_PADDING + lines * LINE_HEIGHT)
    return height, nameLines, descriptionLines
end

function CombatAchievementsTab.new(parent, options)
    local self = setmetatable({}, CombatAchievementsTab)
    self.options = options
    self.state = self.options.state
    self.model = self.options.model
    self.achievements = self.options.achievements or {}
    self.root = ui.Layer.new(parent)
    self.root:SetPos(self.options.x or 0, self.options.y or 0)
    self.root:SetSize(self.options.width, self.options.height)
    self.root.clickthrough = true
    self:BuildHeader()
    return self
end

function CombatAchievementsTab:BuildHeader()
    local width = self.root.width
    self.heading =
        UI.Text(self.root, self.options.categoryName(), 12, 2, math.max(180, width - 140), 28, {
            font = id.Font.CINZEL_18PT_BOLD,
            colour = 0xF2C66DFF,
        })
    self.summary = UI.Text(self.root, "0 / 0", width - 118, 2, 100, 28, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = 0xF2C66DFF,
        alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
    })

    UI.Text(self.root, "TIER", 12, 32, 130, 20, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = 0xF2C66DFF,
    })
    local ComboBox = prettyui.OrderedComboBox or prettyui.ComboBox
    self.tierCombo = ComboBox.new(self.root, {
        x = 12,
        y = 52,
        width = 130,
        height = 28,
        entries = TIER_FILTERS,
        selectedID = self.state.tierFilter,
        onChange = function(_, entryID)
            self.state.tierFilter = tonumber(entryID) or 0
            self:FiltersChanged()
        end,
    })

    UI.Text(self.root, "STATUS", 154, 32, 140, 20, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = 0xF2C66DFF,
    })
    self.statusCombo = ComboBox.new(self.root, {
        x = 154,
        y = 52,
        width = 140,
        height = 28,
        entries = STATUS_FILTERS,
        selectedID = self.state.statusFilter,
        onChange = function(_, entryID)
            self.state.statusFilter = tonumber(entryID) or Settings.STATUS_ALL
            self:FiltersChanged()
        end,
    })

    UI.Text(self.root, "SEARCH", 306, 32, math.max(130, width - 318), 20, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = 0xF2C66DFF,
    })
    self.searchField = prettyui.TextField.new(self.root, {
        x = 306,
        y = 52,
        width = math.max(130, width - 318),
        height = 28,
        text = self.state.search,
        placeholder = "Achievement or description...",
        maxLength = 80,
        onChange = function(_, reason, content)
            self.state.search = tostring(content or "")
            self.options.onSearchChange(reason)
        end,
    })

    UI.Rectangle(self.root, 0, 88, width, 24, 0x2A221AFF)
    UI.Text(self.root, "ACHIEVEMENT", 12, 88, 226, 24, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = 0xF2C66DFF,
    })
    UI.Text(self.root, "DESCRIPTION", 238, 88, width - 250, 24, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = 0xF2C66DFF,
    })

    local selectedTier = tonumber(self.tierCombo:GetSelectedID())
    if selectedTier ~= nil and selectedTier >= 0 and selectedTier <= 6 then
        self.state.tierFilter = selectedTier
    end
    local selectedStatus = tonumber(self.statusCombo:GetSelectedID())
    if
        selectedStatus == Settings.STATUS_ALL
        or selectedStatus == Settings.STATUS_COMPLETE
        or selectedStatus == Settings.STATUS_INCOMPLETE
    then
        self.state.statusFilter = selectedStatus
    end
end

-- Apply changed filters
function CombatAchievementsTab:FiltersChanged() self.options.onFilterChange() end

function CombatAchievementsTab:UpdateHeading(categoryName) self.heading.content = categoryName end

-- Rebuild combat achievement rows
function CombatAchievementsTab:Rebuild(preserveScroll)
    local records = self.model:VisibleAchievements(self.state)
    local contentWidth = self.root.width
    local scrollHeight = math.max(120, self.root.height - HEADER_HEIGHT)
    local rowWidth = math.max(300, contentWidth - 18)
    local groups, groupByName = {}, {}
    for _, achievement in ipairs(records) do
        local group = groupByName[achievement.tier]
        if group == nil then
            group = { name = achievement.tier, achievements = {}, complete = 0 }
            groupByName[achievement.tier] = group
            groups[#groups + 1] = group
        end
        group.achievements[#group.achievements + 1] = achievement
        if achievement.complete == true then group.complete = group.complete + 1 end
    end

    local rows = {}
    local y = 0
    for groupIndex, group in ipairs(groups) do
        if groupIndex > 1 then y = y + ProgressStyle.GROUP_GAP end
        local collapsed = self.state.collapsedTiers[group.name] == true
        rows[#rows + 1] = {
            kind = "header",
            group = group.name,
            count = #group.achievements,
            complete = group.complete,
            collapsed = collapsed,
            groupStart = true,
            groupEnd = collapsed or #group.achievements == 0,
            colour = ProgressStyle.GROUP_BACKGROUND,
            y = y,
            height = ProgressStyle.GROUP_HEIGHT,
        }
        y = y + ProgressStyle.GROUP_HEIGHT
        if not collapsed then
            for rowIndex, achievement in ipairs(group.achievements) do
                local height, nameLines, descriptionLines = rowMetrics(achievement, rowWidth)
                rows[#rows + 1] = {
                    kind = "achievement",
                    achievement = achievement,
                    complete = achievement.complete == true,
                    colour = ProgressStyle.RowColour(rowIndex),
                    groupEnd = rowIndex == #group.achievements,
                    y = y,
                    height = height,
                    nameLineValues = nameLines,
                    descriptionLineValues = descriptionLines,
                }
                y = y + height
            end
        end
    end
    if #records == 0 then
        rows[1] = {
            kind = "empty",
            message = "No achievements match this filter.",
            y = 12,
            height = 32,
        }
        y = 56
    end

    if self.list == nil then
        self.list = CombatAchievementList.new(self.root, prettyui, {
            x = 0,
            y = HEADER_HEIGHT,
            width = contentWidth,
            height = scrollHeight,
            rowHeight = MIN_ROW_HEIGHT,
            lineHeight = LINE_HEIGHT,
            nameWidth = NAME_WIDTH,
            onToggle = self.options.onToggleTier,
            fonts = {
                header = id.Font.CINZEL_18PT_BOLD,
                marker = id.Font.MUSEO_SANS_13PT_BOLD,
                name = id.Font.MUSEO_SANS_13PT_BOLD,
                body = id.Font.MUSEO_SANS_13PT_REGULAR,
            },
        })
    end
    self.list:Update({
        x = 0,
        y = HEADER_HEIGHT,
        width = contentWidth,
        height = scrollHeight,
        rowWidth = rowWidth,
        rows = rows,
        contentHeight = y,
        preserveScroll = preserveScroll,
    })

    -- Completion totals cover the selected category regardless of list filters.
    local categoryTotal, categoryComplete = 0, 0
    local categoryID = self.model:PageCategoryID(self.state.selectedCategoryID)
    for _, achievement in ipairs(self.achievements) do
        if
            categoryID == Settings.ALL_CATEGORIES_ID or achievement.categoryID == categoryID
        then
            categoryTotal = categoryTotal + 1
            if achievement.complete == true then categoryComplete = categoryComplete + 1 end
        end
    end
    self.summary.content = tostring(categoryComplete) .. " / " .. tostring(categoryTotal)
end

function CombatAchievementsTab:DestroyContent()
    if self.list ~= nil then self.list:Destroy() end
    self.list = nil
end

function CombatAchievementsTab:Destroy()
    self:DestroyContent()
    if self.tierCombo ~= nil then self.tierCombo:Destroy() end
    if self.statusCombo ~= nil then self.statusCombo:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.tierCombo = nil
    self.statusCombo = nil
    self.root = nil
end

return CombatAchievementsTab
