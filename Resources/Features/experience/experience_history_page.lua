-- Render the experience history page
local UI = require("Resources/Shared/ui/components")
local LazyTabs = require("Resources/Shared/ui/lazy_tabs")
local SidebarLayout = require("Resources/Shared/ui/sidebar_layout")
local SidebarList = require("Resources/Shared/ui/sidebar_list")
local DailyExperienceList = require("Resources/Features/experience/daily_experience_list")
local SkillIcons = require("Resources/Shared/skills/skill_icons")
local SkillCatalog = require("Resources/Shared/skills/skill_catalog")
local ExperienceTime = require("Resources/Features/experience/experience_time")
local DateTimeFormat = require("Resources/Lib/date_time_format")
local formatNumber = require("Resources/Lib/number_format").Integer
local ExperienceChart = require("Resources/Features/experience/experience_chart")
local DateRangePicker = require("Resources/Features/experience/date_range_picker")

local ExperienceHistoryPage = {}
ExperienceHistoryPage.__index = ExperienceHistoryPage

local TOOLBAR_HEIGHT = 42
local SIDEBAR_WIDTH = 220
local WORKSPACE_GAP = 8
local GOLD = 0xF2C66DFF
local BORDER = 0x574936FF
local DIVIDER = 0x352C21FF
local TARGET_SEGMENTS = 30

-- Check whether two date sets mark the same days
local function sameKeys(left, right)
    if right == nil then return false end
    for key in pairs(left) do
        if right[key] == nil then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

function ExperienceHistoryPage.new(parent, options)
    local self = setmetatable({}, ExperienceHistoryPage)
    self.options = options
    self.section = self.options.section
    self.tracker = self.options.tracker
    self.state = self.options.state
    self.dateFormat = DateTimeFormat.NormalizeDate(self.state.dateFormat)
    self.timeFormat = DateTimeFormat.NormalizeTime(self.state.timeFormat)
    self.controls = {}
    self.dateButtons = {}
    local today = self.tracker:GetCurrentDate() or { year = 2026, month = 10, day = 10 }
    local firstFallback = ExperienceTime.AddDays(today, -6)
    self.startDate = ExperienceTime.NormalizeDate({
        year = self.state.xpStartYear,
        month = self.state.xpStartMonth,
        day = self.state.xpStartDay,
    }, firstFallback, 2000, 2200)
    self.endDate = ExperienceTime.NormalizeDate({
        year = self.state.xpEndYear,
        month = self.state.xpEndMonth,
        day = self.state.xpEndDay,
    }, today, 2000, 2200)
    if ExperienceTime.DateOrdinal(self.endDate) < ExperienceTime.DateOrdinal(self.startDate) then
        self.endDate = ExperienceTime.CloneDate(self.startDate)
    end
    self.calendarYear = math.max(
        2000,
        math.min(2200, math.floor(tonumber(self.state.xpCalendarYear) or self.endDate.year))
    )
    self.calendarMonth = math.max(
        1,
        math.min(12, math.floor(tonumber(self.state.xpCalendarMonth) or self.endDate.month))
    )
    self.selectedSkillID = tonumber(self.state.xpSkillID) or 27
    if SkillCatalog.byID[self.selectedSkillID] == nil then self.selectedSkillID = 27 end
    self.history = nil
    self.historyDailySkillID = nil
    self.dataDirty = true

    self.root = ui.Layer.new(parent)
    self.root:SetPos(self.options.x or 0, self.options.y or 0)
    self.root:SetSize(self.options.width, self.options.height)
    self.root.clickthrough = true

    self.isBuilding = true
    self.tabHost = LazyTabs.new(
        self.root,
        self.section.modes,
        self.state.xpMode,
        function(_, _, mode)
            if self.isBuilding then return end
            self:CloseCalendar()
            self:SetMode(mode, false)
        end
    )
    self.tabs = self.tabHost.tabs
    self:SetMode(self.state.xpMode, true)
    self.isBuilding = false
    -- Persist the default range on first open
    if self.state.xpStartYear == nil then self:SaveState() end
    return self
end

-- Load XP history when needed
function ExperienceHistoryPage:EnsureHistory()
    local dailySkillID = self.state.xpMode == "skills" and self.selectedSkillID or nil
    if
        self.history ~= nil
        and not self.dataDirty
        and self.historyDailySkillID == dailySkillID
    then
        return true
    end
    if self.tracker == nil then return false end
    self.history = self.tracker:Query(
        self.startDate,
        self.endDate,
        TARGET_SEGMENTS,
        dailySkillID
    )
    self.historyDailySkillID = dailySkillID
    self.dataDirty = false
    return true
end

function ExperienceHistoryPage:DestroyModeContent(root)
    if self.modeRoot ~= root then return end
    self:CloseCalendar()
    if self.skillDailyLedger ~= nil then self.skillDailyLedger:Destroy() end
    if self.skillScroll ~= nil then self.skillScroll:Destroy() end
    if self.skillList ~= nil then self.skillList:Destroy() end
    if self.overallChart ~= nil then self.overallChart:Destroy() end
    for _, control in ipairs(self.controls) do
        control:Destroy()
    end
    if root ~= nil then root:Destroy() end
    self.controls = {}
    self.dateButtons = {}
    self.modeRoot = nil
    self.overallPage = nil
    self.overallToolbar = nil
    self.overallChart = nil
    self.skillPage = nil
    self.skillList = nil
    self.skillWorkspace = nil
    self.skillToolbar = nil
    self.skillDailyLedger = nil
    self.skillScroll = nil
    self.skillChart = nil
    self.deleteHistoryButton = nil
    self.cancelDeleteButton = nil
    self.deleteHistoryStatus = nil
    self.deletePlayerID = nil
end

function ExperienceHistoryPage:CreateModeView(mode, page)
    local root = ui.Layer.new(page)
    root:SetSize(page.width, page.height)
    root.clickthrough = true
    self.modeRoot = root
    self.controls = {}
    self.dateButtons = {}
    if mode.id == "notice" then
        self:BuildNotice(root)
    elseif mode.id == "overall" then
        self:EnsureHistory()
        self:BuildOverall(root)
    elseif mode.id == "skills" then
        self:EnsureHistory()
        self:BuildSkills(root)
    elseif mode.id == "danger" then
        self:BuildDanger(root)
    else
        error("Unsupported XP mode: " .. tostring(mode.id))
    end
    local owner = self
    return {
        root = root,
        Destroy = function() owner:DestroyModeContent(root) end,
    }
end

function ExperienceHistoryPage:SetMode(modeID, force)
    local mode = self.tabHost:Mode(modeID) or self.section.modes[1]
    if mode == nil or not force and self.state.xpMode == mode.id then return end
    self.state.xpMode = mode.id
    self.activeView = select(1, self.tabHost:Activate(mode.id, true, function(selected, page)
        return self:CreateModeView(selected, page)
    end))
    if not self.isBuilding then self:SaveState() end
end

-- Schedule an XP history refresh
function ExperienceHistoryPage:MarkDataDirty() self.dataDirty = true end

-- Check whether new XP can appear in the selected range
function ExperienceHistoryPage:ShowsLiveData()
    if self.state.xpMode == "notice" or self.state.xpMode == "danger" then return false end
    local today = self.tracker ~= nil and self.tracker:GetCurrentDate() or nil
    if today == nil then return true end
    local ordinal = ExperienceTime.DateOrdinal(today)
    return ordinal >= ExperienceTime.DateOrdinal(self.startDate)
        and ordinal <= ExperienceTime.DateOrdinal(self.endDate)
end

function ExperienceHistoryPage:SaveState()
    self.state.xpStartYear = self.startDate.year
    self.state.xpStartMonth = self.startDate.month
    self.state.xpStartDay = self.startDate.day
    self.state.xpEndYear = self.endDate.year
    self.state.xpEndMonth = self.endDate.month
    self.state.xpEndDay = self.endDate.day
    self.state.xpCalendarYear = self.calendarYear
    self.state.xpCalendarMonth = self.calendarMonth
    self.state.xpSkillID = self.selectedSkillID
    self.options.saveState()
end

function ExperienceHistoryPage:BuildNotice(parent)
    local width = math.min(parent.width - 80, 680)
    local height = 124
    local x = math.floor((parent.width - width) / 2)
    local y = math.max(24, math.floor((parent.height - height) / 2))

    UI.Text(parent, "XP History is an experimental feature.", x, y, width, 28, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = GOLD,
        alignHorizontal = ui.AlignMode.CENTRE,
        alignVertical = ui.AlignMode.CENTRE,
    })
    UI.Text(parent,
        "Data is recorded locally and does not sync to any other devices. There is currently no way "
            .. "to back up or transfer your historical data. This feature and its storage mechanism "
            .. "may change as development continues, and data loss may occur during that time.",
        x, y + 34, width, 90, {
            font = id.Font.MUSEO_SANS_13PT_REGULAR,
            colour = 0xD5CBB8FF,
            maxLines = 5,
            alignHorizontal = ui.AlignMode.CENTRE,
            alignVertical = ui.AlignMode.TOPLEFT,
        })
end

-- Cancel the character-bound deletion confirmation.
function ExperienceHistoryPage:ResetDeleteConfirmation()
    self.deletePlayerID = nil
    self.deleteHistoryButton.content.content = "Delete all XP history"
    self.deleteHistoryButton.root:SetPos(math.floor((self.modeRoot.width - 200) / 2),
        self.deleteHistoryButton.root.y)
    self.cancelDeleteButton.root.hidden = true
end

function ExperienceHistoryPage:DeleteHistoryClicked()
    if self.deletePlayerID == nil then
        local playerID = self.tracker:GetPlayerID()
        if playerID == nil then
            self.deleteHistoryStatus.content = "Log in with tracking access enabled before deleting XP history."
            return
        end
        self.deletePlayerID = playerID
        self.deleteHistoryButton.content.content = "Confirm deletion"
        self.deleteHistoryButton.root:SetPos(math.floor((self.modeRoot.width - 316) / 2),
            self.deleteHistoryButton.root.y)
        self.cancelDeleteButton.root.hidden = false
        self.deleteHistoryStatus.content = "Permanently delete all recorded XP history for this character? This cannot be undone."
        return
    end
    local successful, reason = self.tracker:DeleteHistory(self.deletePlayerID)
    self:ResetDeleteConfirmation()
    self.history, self.historyDailySkillID, self.dataDirty = nil, nil, true
    if successful then
        self.deleteHistoryStatus.content = "All XP history for this character has been deleted. New gains will continue to be recorded while XP Logs is enabled."
    elseif reason == "player_changed" then
        self.deleteHistoryStatus.content = "Your character changed. Select Delete all XP history again to start a new confirmation."
    else
        self.deleteHistoryStatus.content = "Could not delete all XP history. Some data may have been removed. Please try again."
    end
end

function ExperienceHistoryPage:BuildDanger(parent)
    local width = math.min(parent.width - 80, 680)
    local height = 244
    local x = math.floor((parent.width - width) / 2)
    local y = math.max(24, math.floor((parent.height - height) / 2))
    UI.Text(parent, "Permanently delete your XP history.", x, y, width, 28, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = GOLD,
        alignHorizontal = ui.AlignMode.CENTRE,
        alignVertical = ui.AlignMode.CENTRE,
    })
    UI.Text(parent, "Permanently remove all recorded XP gains for the current character on this device, across all skills and dates. "
        .. "Other characters' history, trophy ownership, and settings are kept. This cannot be undone. "
        .. "New gains will continue to be recorded while XP Logs is enabled.", x, y + 34, width, 90, {
        font = id.Font.MUSEO_SANS_13PT_REGULAR,
        maxLines = 5, colour = 0xD5CBB8FF,
        alignHorizontal = ui.AlignMode.CENTRE,
        alignVertical = ui.AlignMode.TOPLEFT,
    })
    self.deleteHistoryButton = self:AddControl(prettyui.SimpleButton.new(parent,
        "Delete all XP history", function() self:DeleteHistoryClicked() end,
        { x = math.floor((parent.width - 200) / 2), y = y + 130,
            width = 200, height = 32, colour = 0xDD7568FF, toggleable = false }))
    self.cancelDeleteButton = self:AddControl(prettyui.SimpleButton.new(parent,
        "Cancel", function()
            self:ResetDeleteConfirmation()
            self.deleteHistoryStatus.content = "Deletion cancelled."
        end,
        { x = math.floor((parent.width - 316) / 2) + 216, y = y + 130,
            width = 100, height = 32, toggleable = false }))
    self.cancelDeleteButton.root.hidden = true
    self.deleteHistoryStatus = UI.Text(parent, "", x, y + 178, width, 66, {
        font = id.Font.MUSEO_SANS_13PT_REGULAR,
        maxLines = 4, colour = 0xD5CBB8FF,
        alignHorizontal = ui.AlignMode.CENTRE,
        alignVertical = ui.AlignMode.TOPLEFT,
    })
end

-- Add a history range control
function ExperienceHistoryPage:AddControl(control)
    self.controls[#self.controls + 1] = control
    return control
end

function ExperienceHistoryPage:BuildToolbar(parent, total)
    local width = parent.width
    UI.Rectangle(parent, 0, 0, width, TOOLBAR_HEIGHT, 0x1A1712FF)
    UI.Rectangle(parent, 0, TOOLBAR_HEIGHT - 1, width, 1, DIVIDER)
    local totalWidth, dateWidth = 128, 184
    local totalX = width - totalWidth - 8
    local dateButton = self:AddControl(
        prettyui.SimpleButton.new(
            parent,
            DateTimeFormat.Period(self.startDate, self.endDate, self.dateFormat),
            function(button) self:ToggleCalendar(parent, button) end,
            {
                x = 12,
                y = 7,
                width = dateWidth,
                height = 28,
                colour = GOLD,
                toggleable = false,
                tooltip = "Choose XP history dates",
                hoverCursor = UI.NO_CURSOR,
            }
        )
    )
    self.dateButtons[#self.dateButtons + 1] = dateButton
    local totalText = UI.Text(parent, total, totalX, 0, totalWidth, TOOLBAR_HEIGHT - 1, {
        font = id.Font.CINZEL_18PT_BOLD,
        colour = GOLD,
        alignHorizontal = ui.AlignMode.BOTTOMRIGHT,
        alignVertical = ui.AlignMode.CENTRE,
    })
    local statusX = 208
    local statusText =
        UI.Text(parent, "", statusX, 0, math.max(80, totalX - statusX - 10), TOOLBAR_HEIGHT - 1, {
            font = id.Font.MUSEO_SANS_11PT_REGULAR,
            colour = 0xD29A52FF,
            alignHorizontal = ui.AlignMode.CENTRE,
            alignVertical = ui.AlignMode.CENTRE,
        })
    return {
        dateButton = dateButton,
        totalText = totalText,
        statusText = statusText,
    }
end

function ExperienceHistoryPage:UpdateStatusControl(toolbar)
    if toolbar == nil or toolbar.statusText == nil or self.tracker == nil then return end
    local status = self.tracker:GetStatus()
    toolbar.statusText.content = status.message or ""
    toolbar.statusText.rgba = status.code == "persistence_error" and 0xDD7568FF or 0xD29A52FF
end

function ExperienceHistoryPage:UpdatePeriodControls()
    local label = DateTimeFormat.Period(self.startDate, self.endDate, self.dateFormat)
    for _, button in ipairs(self.dateButtons) do
        if button.content ~= nil then button.content.content = label end
    end
    if self.overallToolbar ~= nil then
        self.overallToolbar.totalText.content = formatNumber(self.history.total) .. " XP"
        self:UpdateStatusControl(self.overallToolbar)
    end
    if self.skillToolbar ~= nil then
        local skill = self.history.skillByID[self.selectedSkillID]
        if skill ~= nil then
            self.skillToolbar.totalText.content = formatNumber(skill.total) .. " XP"
        end
        self:UpdateStatusControl(self.skillToolbar)
    end
end

function ExperienceHistoryPage:SetDateFormat(value)
    local normalized = DateTimeFormat.NormalizeDate(value)
    if self.dateFormat == normalized then return end
    self.dateFormat = normalized
    self.state.dateFormat = normalized
    self:UpdatePeriodControls()
    self:RebuildOverallGraph()
    self:RebuildSkillGraph(true)
    if self.calendarParent ~= nil then self:BuildCalendarSheet() end
end

function ExperienceHistoryPage:SetTimeFormat(value)
    local normalized = DateTimeFormat.NormalizeTime(value)
    if self.timeFormat == normalized then return end
    self.timeFormat = normalized
    self.state.timeFormat = normalized
    self:RebuildOverallGraph()
    self:RebuildSkillGraph(true)
    if self.calendarParent ~= nil then self:BuildCalendarSheet() end
end

-- Reload history; live updates keep the daily list position, range changes reset it
function ExperienceHistoryPage:RefreshData(resetScroll)
    self.dataDirty = true
    if self.state.xpMode == "notice" or self.state.xpMode == "danger" or not self:EnsureHistory() then return false end
    self:UpdatePeriodControls()
    if self.state.xpMode == "overall" then
        self:RebuildOverallGraph()
    elseif self.state.xpMode == "skills" then
        self:RebuildSkillGraph(not resetScroll)
    end
    self:BuildCalendarSheet(true)
    return true
end

function ExperienceHistoryPage:SetRange(startDate, endDate)
    local first = ExperienceTime.NormalizeDate(startDate, self.startDate, 2000, 2200)
    local second = ExperienceTime.NormalizeDate(endDate, first, 2000, 2200)
    if ExperienceTime.DateOrdinal(second) < ExperienceTime.DateOrdinal(first) then
        first, second = second, first
    end
    self.startDate = first
    self.endDate = second
    self:SaveState()
    self:RefreshData(true)
end

function ExperienceHistoryPage:CloseCalendar()
    for _, button in ipairs(self.dateButtons or {}) do
        button:SetActive(false)
    end
    if self.calendarSheet ~= nil then self.calendarSheet:Destroy() end
    self.calendarSheet = nil
    self.calendarParent = nil
    self.pendingStartDate = nil
end

-- Raise the calendar above the page
function ExperienceHistoryPage:RaiseCalendar()
    if self.calendarSheet ~= nil then self.calendarSheet:MoveToFront() end
end

function ExperienceHistoryPage:ToggleCalendar(parent, sourceButton)
    if self.calendarSheet ~= nil then
        self:CloseCalendar()
        return
    end
    for _, button in ipairs(self.dateButtons) do
        button:SetActive(button == sourceButton)
    end
    self.calendarParent = parent
    self.pendingStartDate = nil
    self:BuildCalendarSheet()
end

-- Move the calendar by one month
function ExperienceHistoryPage:NavigateCalendarMonth(delta)
    local month = self.calendarMonth + delta
    local year = self.calendarYear
    if month < 1 then
        month = 12
        year = year - 1
    elseif month > 12 then
        month = 1
        year = year + 1
    end
    if year < 2000 then
        year, month = 2000, 1
    elseif year > 2200 then
        year, month = 2200, 12
    end
    self.calendarYear = year
    self.calendarMonth = month
    self:SaveState()
    self:BuildCalendarSheet()
end

function ExperienceHistoryPage:SelectCalendarDate(date)
    local selected = ExperienceTime.NormalizeDate(date, self.endDate, 2000, 2200)
    if self.pendingStartDate == nil then
        self.pendingStartDate = selected
    else
        self:SetRange(self.pendingStartDate, selected)
        self.pendingStartDate = nil
    end
    self:BuildCalendarSheet()
end

-- Rebuild the calendar; live refreshes skip it unless the marked days changed
function ExperienceHistoryPage:BuildCalendarSheet(onlyIfDatesChanged)
    local parent = self.calendarParent
    if parent == nil then return end
    local gainDates = self.tracker ~= nil
            and self.tracker:GainDates(
                self.calendarYear,
                self.calendarMonth,
                self.state.xpMode == "skills" and self.selectedSkillID or nil
            )
        or {}
    local unchanged = self.calendarSheet ~= nil and sameKeys(gainDates, self.calendarDates)
    if onlyIfDatesChanged and unchanged then return end
    if self.calendarSheet ~= nil then self.calendarSheet:Destroy() end
    self.calendarDates = gainDates
    self.calendarSheet = DateRangePicker.Build(parent, {
        x = 12,
        y = TOOLBAR_HEIGHT - 1,
        year = self.calendarYear,
        month = self.calendarMonth,
        startDate = self.startDate,
        endDate = self.endDate,
        pendingStartDate = self.pendingStartDate,
        dateFormat = self.dateFormat,
        gainDates = gainDates,
        onNavigate = function(delta) self:NavigateCalendarMonth(delta) end,
        onSelect = function(date) self:SelectCalendarDate(date) end,
    })
end

-- Bind current history to a chart
function ExperienceHistoryPage:UpdateChart(chart, series, selectedSkill)
    chart:Update({
        series = series,
        selectedSkill = selectedSkill,
        startDate = self.startDate,
        endDate = self.endDate,
        dateFormat = self.dateFormat,
        timeFormat = self.timeFormat,
        segmentCount = TARGET_SEGMENTS,
    })
end

function ExperienceHistoryPage:BuildOverall(parent)
    self.overallPage = parent
    self.overallToolbar = self:BuildToolbar(parent, formatNumber(self.history.total) .. " XP")
    self:UpdateStatusControl(self.overallToolbar)
    self:RebuildOverallGraph()
end

function ExperienceHistoryPage:RebuildOverallGraph()
    local page = self.overallPage
    if page == nil then return end
    if self.overallChart == nil then
        self.overallChart = ExperienceChart.new(page, {
            x = 8,
            y = TOOLBAR_HEIGHT + 8,
            width = page.width - 16,
            height = math.max(248, page.height - TOOLBAR_HEIGHT - 16),
            formatNumber = formatNumber,
        })
    end
    self:UpdateChart(self.overallChart, self.history.series, nil)
    self:RaiseCalendar()
end

function ExperienceHistoryPage:BuildSkills(parent)
    self.skillPage = parent
    local shell = SidebarLayout.Attach(parent, {
        sidebarWidth = SIDEBAR_WIDTH,
        gap = WORKSPACE_GAP,
        sidebarColour = 0x17140FFF,
        dividerColour = BORDER,
        sidebarTitle = "SKILLS",
        titleY = 1,
        titleHeight = 26,
    })
    UI.Rectangle(parent, 0, 0, SIDEBAR_WIDTH, 28, 0x30281EFF)
    shell.sidebarTitle:MoveToFront()
    local entries = {}
    for _, skill in ipairs(SkillCatalog.ordered) do
        entries[#entries + 1] = {
            id = skill.id,
            label = skill.name,
            icon = SkillIcons.SpriteID(skill.id),
        }
    end
    self.skillList = SidebarList.new(parent, {
        x = 0,
        y = 28,
        width = SIDEBAR_WIDTH,
        height = math.max(80, parent.height - 28),
        entries = entries,
        selected = self.selectedSkillID,
        entryIconScale = 150,
        onSelect = function(skillID) self:SelectSkill(skillID) end,
    })
    self.skillList:Reveal(self.selectedSkillID, true)

    self.skillWorkspace = shell.workspace
    local skill = self.history.skillByID[self.selectedSkillID]
    self.skillToolbar = self:BuildToolbar(self.skillWorkspace, formatNumber(skill.total) .. " XP")
    self:UpdateStatusControl(self.skillToolbar)
    self:RebuildSkillGraph()
end

function ExperienceHistoryPage:SelectSkill(skillID)
    local selected = SkillCatalog.byID[tonumber(skillID)]
    if selected == nil then return end
    self.selectedSkillID = selected.id
    self:EnsureHistory()
    if self.skillToolbar ~= nil then
        local history = self.history.skillByID[selected.id]
        self.skillToolbar.totalText.content = formatNumber(history ~= nil and history.total or 0)
            .. " XP"
    end
    self:SaveState()
    self:RebuildSkillGraph()
    if self.calendarParent ~= nil then self:BuildCalendarSheet() end
end

-- Update the skill chart and daily list, building them on first use
function ExperienceHistoryPage:RebuildSkillGraph(preserveScroll)
    local workspace = self.skillWorkspace
    if workspace == nil or self.history == nil then return end
    local skill = self.history.skillByID[self.selectedSkillID]
    if skill == nil then return end
    local viewportHeight = math.max(120, workspace.height - TOOLBAR_HEIGHT)
    local chartHeight = 268
    local tableY = chartHeight + 16
    local rowHeight = 32
    local records = {}
    for _, record in ipairs(skill.daily or {}) do
        records[#records + 1] = {
            day = DateTimeFormat.Date(record.day, self.dateFormat),
            gain = record.gain,
            active = record.active,
            rate = record.rate,
        }
    end
    local contentHeight = math.max(viewportHeight, tableY + rowHeight * (#records + 1) + 8)
    if self.skillScroll == nil then
        self.skillScroll = prettyui.SimpleView.new(workspace, {
            x = 0,
            y = TOOLBAR_HEIGHT,
            width = workspace.width,
            height = viewportHeight,
            contentHeight = contentHeight,
            scrollStep = rowHeight,
        })
        local root = self.skillScroll.content
        self.skillChart = ExperienceChart.new(root, {
            x = 8,
            y = 8,
            width = root.width - 16,
            height = chartHeight,
            formatNumber = formatNumber,
        })
        self.skillDailyLedger = DailyExperienceList.new(self.skillScroll, {
            x = 8,
            y = tableY,
            width = root.width - 16,
            rowHeight = rowHeight,
            rows = records,
            formatNumber = formatNumber,
        })
    else
        self.skillScroll:SetContentHeight(contentHeight)
        self.skillDailyLedger:SetRows(records)
        local maximumY = contentHeight - viewportHeight
        local y = preserveScroll and math.min(self.skillScroll.scrollY, maximumY) or 0
        if y ~= self.skillScroll.scrollY then self.skillScroll:SetScrollPosition(y) end
    end
    self:UpdateChart(self.skillChart, { skill }, skill)
    self:RaiseCalendar()
end

function ExperienceHistoryPage:Destroy()
    if self.tabHost ~= nil then self.tabHost:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.tabHost = nil
    self.activeView = nil
    self.tabs = nil
    self.root = nil
end

return ExperienceHistoryPage
