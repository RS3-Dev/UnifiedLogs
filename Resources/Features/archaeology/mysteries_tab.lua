-- Render the mysteries tab
local UI = require("Resources/Shared/ui/components")
local GameData = require("Resources/Lib/game_data")
local SidebarList = require("Resources/Shared/ui/sidebar_list")
local ProgressStyle = require("Resources/Shared/ui/progress_style")
local CollectionGroupPanel = require("Resources/Shared/ui/collection_group_panel")
local SidebarLayout = require("Resources/Shared/ui/sidebar_layout")

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
                        if not GameData.MysteryBitIsSet(self.options.getValue(mystery.variable), mystery.bit) then
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

function MysteriesTab:Destroy()
    if self.sidebarList ~= nil then self.sidebarList:Destroy() end
    self.sidebarList = nil
    if self.scroll ~= nil then self.scroll:Destroy() end
    if self.root ~= nil then self.root:Destroy() end
    self.scroll = nil
    self.root = nil
end

return MysteriesTab
