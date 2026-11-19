-- Render the mysteries tab
local UI = require("Resources/Shared/ui/components")
local GameData = require("Resources/Lib/game_data")
local SidebarList = require("Resources/Shared/ui/sidebar_list")
local ProgressStyle = require("Resources/Shared/ui/progress_style")
local CollectionGroupPanel = require("Resources/Shared/ui/collection_group_panel")
local SidebarLayout = require("Resources/Shared/ui/sidebar_layout")
local Preparer = require("Resources/Shared/collections/collection_preparer")
local VirtualList = require("Resources/Features/bosses/combat_achievement_list")

local MysteriesTab = {}
MysteriesTab.__index = MysteriesTab

local SIDEBAR_WIDTH = SidebarLayout.SIDEBAR_WIDTH
local ROW_HEIGHT = 40
local GROUP_HEIGHT = ProgressStyle.GROUP_HEIGHT
local GROUP_GAP = ProgressStyle.GROUP_GAP
local ALL_SITES = "All dig sites"

function MysteriesTab.new(parent, options)
    local self = setmetatable({}, MysteriesTab)
    self.options = options
    self.data = self.options.data or { variables = {}, groups = {} }
    self.selected = self.options.selected or ALL_SITES

    local valid = self.selected == ALL_SITES
    for _, group in ipairs(self.data.groups or {}) do
        if group.name == self.selected then valid = true end
    end
    if not valid then self.selected = ALL_SITES end

    local shell = SidebarLayout.CreateHeaded(parent, self.options, "DIG SITES", "")
    self.root, self.workspace = shell.root, shell.workspace
    self.heading, self.summary = shell.heading, shell.summary
    self:BuildSidebar()
    self:Rebuild(false)
    return self
end

-- Get the selected mystery groups
function MysteriesTab:SelectedGroups()
    if self.selected == ALL_SITES then return self.data.groups or {} end
    for _, group in ipairs(self.data.groups or {}) do
        if group.name == self.selected then return { group } end
    end
    self.selected = ALL_SITES
    return self.data.groups or {}
end

function MysteriesTab:BuildSidebar()
    local scrollY = self.sidebarList and self.sidebarList:GetScrollPosition() or 0
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    self.sidebarList = nil

    local entries = { ALL_SITES }
    for _, group in ipairs(self.data.groups or {}) do
        entries[#entries + 1] = group.name
    end
    if ProgressStyle.greenLogEnabled then
        for index, name in ipairs(entries) do
            local total, complete = 0, true
            for _, group in ipairs(self.data.groups or {}) do
                if name == ALL_SITES or name == group.name then
                    for _, mystery in ipairs(group.mysteries or {}) do
                        total = total + 1
                        local collected
                        if self.options.deferCollections and self.selected == ALL_SITES then
                            collected = self.preparer and self.preparer.complete[mystery] == true
                        else
                            collected = GameData.MysteryBitIsSet(self.options.getValue(mystery.variable), mystery.bit)
                        end
                        if not collected then
                            complete = false
                        end
                    end
                end
            end
            entries[index] = { id = name, label = name, complete = total > 0 and complete }
        end
    end

    self.sidebarList = SidebarList.new(self.root, {
        x = 0,
        y = 38,
        width = SIDEBAR_WIDTH,
        height = math.max(40, self.root.height - 46),
        entries = entries,
        selected = self.selected,
        scrollY = scrollY,
        onSelect = function(name)
            if self.selected == name then return end
            self.selected = name
            self.options.onStateChange(name)
            self:Rebuild(false)
        end,
    })
end

-- Rebuild mystery groups
function MysteriesTab:Rebuild(preserveScroll)
    if self.options.deferCollections and self.options.progress then
        self.options.progress.viewport = self.selected == ALL_SITES
    end
    if self.options.deferCollections and self.selected == ALL_SITES then
        self:RebuildDeferred(preserveScroll)
        return
    end
    if self.preparer then self.preparer:Stop(); self.preparer = nil end
    if self.virtualList then self.virtualList:Destroy(); self.virtualList, self.scroll = nil, nil end
    if ProgressStyle.greenLogEnabled then self:BuildSidebar() end
    local previousY = preserveScroll and self.scroll ~= nil and self.scroll.scrollY or 0
    if self.scroll ~= nil then self.scroll:Destroy() end

    local values = {}
    for _, variableName in ipairs(self.data.variables or {}) do
        values[variableName] = self.options.getValue(variableName)
    end
    local groups = self:SelectedGroups()
    local completeCount, totalCount = 0, 0
    for _, group in ipairs(groups) do
        for _, mystery in ipairs(group.mysteries or {}) do
            totalCount = totalCount + 1
            if GameData.MysteryBitIsSet(values[mystery.variable], mystery.bit) then
                completeCount = completeCount + 1
            end
        end
    end

    self.heading.content = self.selected == ALL_SITES and "ALL MYSTERIES"
        or string.upper(self.selected) .. " MYSTERIES"
    self.summary.content = tostring(completeCount) .. "/" .. tostring(totalCount)

    local scrollY = 46
    local scrollHeight = math.max(120, self.root.height - scrollY)
    local showGroupHeaders = self.selected == ALL_SITES
    local requestedHeight = 0
    for groupIndex, group in ipairs(groups) do
        if showGroupHeaders and groupIndex > 1 then
            requestedHeight = requestedHeight + GROUP_GAP
        end
        requestedHeight = requestedHeight + #(group.mysteries or {}) * ROW_HEIGHT
        if showGroupHeaders then requestedHeight = requestedHeight + GROUP_HEIGHT end
    end
    self.scroll = prettyui.SimpleView.new(self.workspace, {
        categoryID = "auto",
        x = 0,
        y = scrollY,
        width = self.workspace.width,
        height = scrollHeight,
        contentHeight = math.max(scrollHeight, requestedHeight),
        scrollStep = ROW_HEIGHT,
    })

    local rowWidth = math.max(300, self.scroll.content.width)
    local y = 0
    for groupIndex, group in ipairs(groups) do
        local groupTop = y
        local completedWedges = {}
        if showGroupHeaders then
            if groupIndex > 1 then
                y = y + GROUP_GAP
                groupTop = y
            end
            local groupComplete = 0
            for _, mystery in ipairs(group.mysteries or {}) do
                if GameData.MysteryBitIsSet(values[mystery.variable], mystery.bit) then
                    groupComplete = groupComplete + 1
                end
            end
            local groupTotal = #(group.mysteries or {})
            local groupIsComplete = groupTotal > 0 and groupComplete == groupTotal
            CollectionGroupPanel.Header(self.scroll.content, {
                x = 0,
                y = y,
                width = rowWidth,
                title = group.name,
                titleColour = 0xF0DFB1FF,
                countLabel = tostring(groupComplete) .. " / " .. tostring(groupTotal),
                complete = groupIsComplete,
                showWedge = false,
            })
            y = y + GROUP_HEIGHT
        end

        for rowIndex, mystery in ipairs(group.mysteries or {}) do
            local complete = GameData.MysteryBitIsSet(values[mystery.variable], mystery.bit)
            local background = ProgressStyle.Green(complete, ProgressStyle.RowColour(rowIndex), ProgressStyle.GREEN_BACKGROUND)
            UI.Rectangle(self.scroll.content, 0, y, rowWidth, ROW_HEIGHT, background)
            UI.Rectangle(
                self.scroll.content,
                0,
                y + ROW_HEIGHT - 1,
                rowWidth,
                1,
                ProgressStyle.ROW_DIVIDER
            )
            UI.Text(self.scroll.content, mystery.name, 12, y, rowWidth - 52, ROW_HEIGHT, {
                font = id.Font.MUSEO_SANS_13PT_BOLD,
                colour = ProgressStyle.Green(complete, complete and ProgressStyle.TEXT_COMPLETE or ProgressStyle.TEXT_NORMAL),
            })
            ProgressStyle.CompletionMark(
                self.scroll.content,
                rowWidth - 26,
                y + math.floor((ROW_HEIGHT - 14) / 2),
                complete
            )
            if complete then
                completedWedges[#completedWedges + 1] = {
                    y = y,
                    height = ROW_HEIGHT,
                }
            end
            y = y + ROW_HEIGHT
        end

        local groupHeight = y - groupTop
        if groupHeight > 0 then
            ProgressStyle.Frame(self.scroll.content, 0, groupTop, rowWidth, groupHeight)
        end
        for _, wedge in ipairs(completedWedges) do
            ProgressStyle.Wedge(self.scroll.content, 1, wedge.y + 1, wedge.height - 2):MoveToFront()
        end
    end
    if preserveScroll then self.scroll:SetScrollPosition(previousY) end
end

-- Virtualize aggregate mystery rows and read shared varbits in bounded jobs.
function MysteriesTab:RebuildDeferred(preserveScroll)
    if self.preparer then self.preparer:Stop() end
    self.heading.content = "ALL MYSTERIES"
    local height = math.max(120, self.root.height - 46)
    local width = self.workspace.width
    if self.virtualList == nil then
        if self.scroll then self.scroll:Destroy() end
        self.virtualList = VirtualList.new(self.workspace, prettyui, {
            x = 0, y = 46, width = width, height = height, rowHeight = ROW_HEIGHT,
            nameWidth = math.max(100, width - 48),
            fonts = { header = id.Font.CINZEL_18PT_BOLD, marker = id.Font.MUSEO_SANS_13PT_BOLD,
                name = id.Font.MUSEO_SANS_13PT_BOLD, body = id.Font.MUSEO_SANS_13PT_REGULAR },
            onVisibleAchievements = function(records)
                if self.preparer == nil then return end
                self.preparer.visible = {}
                for _, record in ipairs(records) do
                    self.preparer.visible[#self.preparer.visible + 1] = record.job
                end
            end,
        })
        self.scroll = self.virtualList.scroll
    end
    self.preparer = Preparer.new({
        isVisible = self.options.isVisible,
        prepareEntry = function(mystery)
            local value = (self.options.readValue or self.options.getValue)(mystery.variable)
            return {}, GameData.MysteryBitIsSet(value, mystery.bit)
        end,
        onChanged = function() self:RefreshDeferredRows() end,
    })
    self.deferredRows = {}
    local y = 0
    for index, source in ipairs(self:SelectedGroups()) do
        if index > 1 then y = y + GROUP_GAP end
        local group = self.preparer:AddGroup(source.name, source.mysteries or {})
        self.deferredRows[#self.deferredRows + 1] = { kind = "header", group = group.name,
            preparedGroup = group, y = y, height = GROUP_HEIGHT, count = group.total,
            complete = 0, pending = group.total > 0, groupStart = true, hideToggle = true }
        y = y + GROUP_HEIGHT
        for entryIndex, mystery in ipairs(group.entries) do
            self.deferredRows[#self.deferredRows + 1] = {
                kind = "achievement", y = y, height = ROW_HEIGHT, preparedGroup = group,
                achievement = { name = mystery.name, description = "", job = group.jobs[entryIndex] },
                nameLineValues = { mystery.name }, descriptionLineValues = {},
                groupEnd = entryIndex == group.total,
            }
            y = y + ROW_HEIGHT
        end
    end
    self.virtualList:Update({ rows = self.deferredRows, width = width, height = height,
        x = 0, y = 46, rowWidth = math.max(300, self.scroll.content.width),
        contentHeight = y, preserveScroll = preserveScroll })
    self:RefreshDeferredRows()
    self.preparer:Start()
end

function MysteriesTab:RefreshDeferredRows()
    local complete, total = 0, 0
    for _, group in ipairs(self.preparer.groups) do complete, total = complete + group.collected, total + group.total end
    self.summary.content = self.preparer.pending > 0 and "Loading..." or tostring(complete) .. "/" .. tostring(total)
    for _, row in ipairs(self.deferredRows) do
        if row.kind == "header" then
            row.complete, row.pending = row.preparedGroup.collected, row.preparedGroup.loadedCount < row.preparedGroup.total
        else
            local job = row.achievement.job
            if job.loaded then row.achievement.complete = job.group.states[job.index]
            else row.achievement.complete = nil end
            row.complete = row.achievement.complete == true
        end
    end
    self.virtualList:Refresh()
    if self.preparer.pending == 0 and ProgressStyle.greenLogEnabled then self:BuildSidebar() end
end

function MysteriesTab:Destroy()
    if self.preparer then self.preparer:Stop(); self.preparer = nil end
    if self.virtualList then self.virtualList:Destroy(); self.virtualList, self.scroll = nil, nil end
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    self.sidebarList = nil
    if self.scroll ~= nil then self.scroll:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.scroll = nil
    self.root = nil
end

return MysteriesTab
