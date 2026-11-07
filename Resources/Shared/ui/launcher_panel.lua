-- Render the launcher panel
local UI = require("Resources/Shared/ui/components")
local DateTimeFormat = require("Resources/Lib/date_time_format")
local Settings = require("Resources/Lib/settings")

local LauncherPanel = {}
LauncherPanel.__index = LauncherPanel

local BUTTON_WIDTH = 280
local CONTENT_HEIGHT = 548
local OTA_CONTROLS_HEIGHT = 80
local GOLD = 0xF2C66DFF
local TEXT = 0xD7C9ADFF
local MUTED = 0x928776FF

-- Create a settings group header
local function groupHeader(parent, x, y, width, text)
    UI.Rectangle(parent, x, y, width, 28, 0x2A231BFF)
    UI.Rectangle(parent, x, y + 27, width, 1, 0x574936FF)
    UI.Text(parent, text, x + 10, y, width - 20, 28, {
        font = id.Font.MUSEO_SANS_13PT_BOLD,
        colour = GOLD,
    })
end

-- Create the open keybind row
local function keybindRow(parent, x, y, width, binding, onChange)
    local labelWidth = 92
    prettyui.Text.new(parent, {
        text = "Open keybind",
        x = x,
        y = y,
        width = labelWidth - 8,
        height = 30,
        font = id.Font.MUSEO_SANS_11PT_REGULAR,
        colour = TEXT,
    })

    return prettyui.KeybindField.new(parent, {
        x = x + labelWidth,
        y = y,
        width = width - labelWidth,
        height = 30,
        value = binding,
        defaultValue = Settings.DEFAULT_OPEN_LOGS_HOTKEY,
        onChange = function(_, value) onChange(value) end,
    })
end

-- Get the settings font
local function settingFont(control)
    for _, item in ipairs(control.items or {}) do
        item.label.font = id.Font.MUSEO_SANS_13PT_REGULAR
    end
    return control
end

-- Create a checkbox setting
local function checkboxSetting(parent, spec)
    return settingFont(prettyui.CheckboxButton.new(parent, {
        {
            text = spec.text,
            value = spec.value,
            tooltip = spec.tooltip,
        },
    }, {
        x = spec.x,
        y = spec.y,
        width = spec.width,
        selectedValues = spec.selected and { spec.value } or {},
        colour = TEXT,
        selectionCursor = false,
        onChange = function(control) spec.onChange(control:IsSelected(spec.value)) end,
    }))
end

-- Create a radio setting
local function radioSetting(parent, spec)
    return settingFont(prettyui.RadioButton.new(parent, spec.choices, {
        x = spec.x,
        y = spec.y,
        width = spec.width,
        inline = true,
        selectedValue = spec.selectedValue,
        colour = TEXT,
        selectionCursor = false,
        onChange = function(_, value) spec.onChange(value) end,
    }))
end

function LauncherPanel.new(parent, options)
    local self = setmetatable({}, LauncherPanel)
    self.options = options or {}
    self.host = UI.RootLayer(parent)
    self.root = prettyui.SimpleView.new(self.host, {
        width = parent.width,
        height = parent.height,
        contentHeight = CONTENT_HEIGHT
            + (self.options.showOTAControls == true and OTA_CONTROLS_HEIGHT or 0),
        scrollable = true,
        scrollStep = 32,
    })

    local content = self.root.content
    -- Centre the panel inside the scrollbar-free viewport
    local width = math.min(BUTTON_WIDTH, math.max(1, content.width - 24))
    local x = math.max(12, math.floor((content.width - width) / 2))
    self:BuildOpenControls(content, x, width)
    self:BuildBossSettings(content, x, width)
    self:BuildQuestSettings(content, x, width)
    self:BuildAchievementSettings(content, x, width)
    self:BuildXPSettings(content, x, width)
    self:BuildDateTimeSettings(content, x, width)
    groupHeader(content, x, 477, width, "DISPLAY")
    self.greenLogToggle = checkboxSetting(content, {
        x = x + 10, y = 512, width = width - 20,
        text = "Enable green log", value = "green_log",
        tooltip = "Highlight completed collection sections and sidebar entries in green",
        selected = self.options.enableGreenLog == true,
        onChange = function(enabled)
            if self.options.onEnableGreenLogChange ~= nil then self.options.onEnableGreenLogChange(enabled) end
        end,
    })
    -- OTA controls need the optional HTTP permission
    if self.options.showOTAControls == true then self:BuildOTAControls(content, x, width) end
    return self
end

function LauncherPanel:BuildOTAControls(content, x, width)
    self.checkUpdateButton = prettyui.SimpleButton.new(
        content,
        "Check for updates",
        function()
            if type(self.options.onCheckForUpdate) == "function" then
                self.options.onCheckForUpdate()
            end
        end,
        { x = x, y = 546, width = width, height = 32 }
    )
    self.showOTAValuesButton = prettyui.SimpleButton.new(
        content,
        "Show OTA values",
        function()
            if type(self.options.onShowOTAValues) == "function" then
                self.options.onShowOTAValues()
            end
        end,
        { x = x, y = 584, width = width, height = 32 }
    )
end

function LauncherPanel:BuildOpenControls(content, x, width)
    self.openButton = prettyui.SimpleButton.new(
        content,
        self.options.logsVisible == true and "Close Logs" or "Open Logs",
        self.options.onToggleLogs,
        {
            x = x,
            y = 16,
            width = width,
            height = 32,
            hoverCursor = UI.NO_CURSOR,
        }
    )
    self.openButton:SetActive(self.options.logsVisible == true)
    local binding = self.options.openLogsHotkey or {}
    self.openLogsHotkey = keybindRow(content, x, 54, width, binding, function(value)
        if type(self.options.onOpenLogsHotkeyChange) == "function" then
            self.options.onOpenLogsHotkeyChange(value)
        end
    end)
end

function LauncherPanel:BuildBossSettings(content, x, width)
    groupHeader(content, x, 94, width, "BOSS LOGS")
    self.personalBestsToggle = checkboxSetting(content, {
        x = x + 10,
        y = 129,
        width = width - 20,
        text = "Show personal bests",
        value = "personal_bests",
        tooltip = "Show personal-best tables above boss collection logs",
        selected = self.options.showPersonalBests ~= false,
        onChange = function(selected)
            if type(self.options.onShowPersonalBestsChange) == "function" then
                self.options.onShowPersonalBestsChange(selected)
            end
        end,
    })
end

function LauncherPanel:BuildQuestSettings(content, x, width)
    groupHeader(content, x, 159, width, "QUEST LOGS")
    self.questCumulativeToggle = checkboxSetting(content, {
        x = x + 10,
        y = 194,
        width = width - 20,
        text = "Cumulative minimum levels",
        value = "minimum_requirements",
        tooltip = "Include the highest skill requirements from every prerequisite quest; when off, show only the selected quest's own requirements",
        selected = self.options.questUseCumulativeRequirements ~= false,
        onChange = function(selected)
            if type(self.options.onQuestUseCumulativeRequirementsChange) == "function" then
                self.options.onQuestUseCumulativeRequirementsChange(selected)
            end
        end,
    })
    UI.Text(content, "ORDER", x + 10, 222, 44, 22, {
        font = id.Font.MUSEO_SANS_11PT_REGULAR,
        colour = MUTED,
        alignVertical = ui.AlignMode.CENTRE,
    })
    self.questOrderToggle = radioSetting(content, {
        x = x + 58,
        y = 222,
        width = width - 68,
        choices = {
            {
                text = "Linear",
                value = "linear",
                tooltip = "Deduplicate prerequisites into an order that can be completed from top to bottom",
            },
            {
                text = "Tree",
                value = "tree",
                tooltip = "Show the full prerequisite tree, including repeated quests in separate branches",
            },
        },
        selectedValue = self.options.questOrderView == "tree" and "tree" or "linear",
        onChange = function(value)
            if type(self.options.onQuestOrderViewChange) == "function" then
                self.options.onQuestOrderViewChange(value == "tree" and "tree" or "linear")
            end
        end,
    })
end

function LauncherPanel:BuildAchievementSettings(content, x, width)
    groupHeader(content, x, 252, width, "ACHIEVEMENTS")
    UI.Text(content, "ORDER", x + 10, 287, 44, 22, {
        font = id.Font.MUSEO_SANS_11PT_REGULAR,
        colour = MUTED,
        alignVertical = ui.AlignMode.CENTRE,
    })
    self.achievementOrderToggle = radioSetting(content, {
        x = x + 58,
        y = 287,
        width = width - 68,
        choices = {
            {
                text = "Linear",
                value = "linear",
                tooltip = "Deduplicate the full descendant lineage into dependency order",
            },
            {
                text = "Tree",
                value = "tree",
                tooltip = "Preserve the full descendant hierarchy, including shared requirements in each branch",
            },
        },
        selectedValue = self.options.achievementOrderView == "tree" and "tree" or "linear",
        onChange = function(value)
            if type(self.options.onAchievementOrderViewChange) == "function" then
                self.options.onAchievementOrderViewChange(value == "tree" and "tree" or "linear")
            end
        end,
    })
end

function LauncherPanel:BuildXPSettings(content, x, width)
    groupHeader(content, x, 317, width, "XP LOGS")
    self.xpLogsToggle = checkboxSetting(content, {
        x = x + 10,
        y = 352,
        width = width - 20,
        text = "Enable XP Logs",
        value = "xp_logs",
        tooltip = "Record XP gains and show the XP section",
        selected = self.options.enableXPLogs == true,
        onChange = function(selected)
            if type(self.options.onEnableXPLogsChange) == "function" then
                self.options.onEnableXPLogsChange(selected)
            end
        end,
    })
end

function LauncherPanel:BuildDateTimeSettings(content, x, width)
    groupHeader(content, x, 382, width, "DATE & TIME")
    UI.Text(content, "DATE", x + 10, 417, 44, 22, {
        font = id.Font.MUSEO_SANS_11PT_REGULAR,
        colour = MUTED,
        alignVertical = ui.AlignMode.CENTRE,
    })
    self.dateFormatToggle = radioSetting(content, {
        x = x + 58,
        y = 417,
        width = width - 68,
        choices = {
            {
                text = "US",
                value = DateTimeFormat.US,
                tooltip = "Month/day/year dates with a Sunday-first calendar",
            },
            {
                text = "EU",
                value = DateTimeFormat.EUROPEAN,
                tooltip = "Day/month/year dates with a Monday-first calendar",
            },
        },
        selectedValue = DateTimeFormat.NormalizeDate(self.options.dateFormat),
        onChange = function(value)
            if type(self.options.onDateFormatChange) == "function" then
                self.options.onDateFormatChange(DateTimeFormat.NormalizeDate(value))
            end
        end,
    })
    UI.Text(content, "CLOCK", x + 10, 445, 44, 22, {
        font = id.Font.MUSEO_SANS_11PT_REGULAR,
        colour = MUTED,
        alignVertical = ui.AlignMode.CENTRE,
    })
    self.timeFormatToggle = radioSetting(content, {
        x = x + 58,
        y = 445,
        width = width - 68,
        choices = {
            {
                text = "12-hour",
                value = DateTimeFormat.HOUR_12,
                tooltip = "Use a 12-hour clock with AM/PM",
            },
            {
                text = "24-hour",
                value = DateTimeFormat.HOUR_24,
                tooltip = "Use a 24-hour clock",
            },
        },
        selectedValue = DateTimeFormat.NormalizeTime(self.options.timeFormat),
        onChange = function(value)
            if type(self.options.onTimeFormatChange) == "function" then
                self.options.onTimeFormatChange(DateTimeFormat.NormalizeTime(value))
            end
        end,
    })
end

function LauncherPanel:SetLogsVisible(visible)
    if self.openButton == nil then return end
    self.openButton:SetActive(visible == true)
    self.openButton.content.content = visible == true and "Close Logs" or "Open Logs"
end

function LauncherPanel:Destroy()
    for _, control in ipairs({
        self.openButton,
        self.openLogsHotkey,
        self.personalBestsToggle,
        self.questCumulativeToggle,
        self.questOrderToggle,
        self.achievementOrderToggle,
        self.xpLogsToggle,
        self.dateFormatToggle,
        self.timeFormatToggle,
        self.greenLogToggle,
        self.checkUpdateButton,
        self.showOTAValuesButton,
    }) do
        if control ~= nil and control.Destroy ~= nil then control:Destroy() end
    end
    self.openButton = nil
    self.openLogsHotkey = nil
    self.personalBestsToggle = nil
    self.questCumulativeToggle = nil
    self.questOrderToggle = nil
    self.achievementOrderToggle = nil
    self.xpLogsToggle = nil
    self.dateFormatToggle = nil
    self.timeFormatToggle = nil
    self.greenLogToggle = nil
    self.checkUpdateButton = nil
    self.showOTAValuesButton = nil
    if self.root ~= nil then
        self.root:Destroy()
        self.root = nil
    end
    if self.host ~= nil then self.host:Destroy() end
    self.host = nil
end

return LauncherPanel
