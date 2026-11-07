-- Display the OTA boss values currently persisted by the plugin
local UI = require("Resources/Shared/ui/components")

local BossPatchValuesWindow = {}
BossPatchValuesWindow.__index = BossPatchValuesWindow

local LINE_HEIGHT = 19
local INSET = 12
local INDENT = 18
local GOLD = 0xF2C66DFF
local TEXT = 0xD7C9ADFF
local MUTED = 0x928776FF
local ERROR = 0xE36D62FF

local function sortedKeys(value)
    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

-- Collect styled lines; depth sets the indent
local function writer()
    local lines = {}
    return lines, function(text, depth, style)
        lines[#lines + 1] = { text = text, depth = depth or 0, style = style }
    end
end

-- Write label: variable rows, adding the record kind when present
local function writeMetrics(add, metrics, depth)
    for _, metric in ipairs(metrics) do
        local text = metric[1] .. ": " .. metric[2]
        if metric[4] ~= nil then text = text .. " + " .. metric[4] end
        if metric[3] ~= nil then text = text .. " (" .. metric[3] .. ")" end
        add(text, depth)
    end
end

-- Write name -> value pairs in name order
local function writePairs(add, values, format)
    for _, key in ipairs(sortedKeys(values)) do
        add(key .. " -> " .. format(values[key]), 1)
    end
end

local SECTIONS = {
    {
        "killCounts",
        "Kill counts",
        function(add, rows)
            for _, row in ipairs(rows) do
                add(row[1], 1, "name")
                writeMetrics(add, row[2], 2)
            end
        end,
    },
    {
        "records",
        "Personal bests",
        function(add, rows)
            for _, row in ipairs(rows) do
                add(row[1], 1, "name")
                for _, encounter in ipairs(row[2]) do
                    add(encounter[1], 2)
                    writeMetrics(add, encounter[2], 3)
                end
            end
        end,
    },
    {
        "trackingNames",
        "Tracking names",
        function(add, groups)
            for _, name in ipairs(sortedKeys(groups)) do
                add(name, 1, "name")
                for index, variable in ipairs(groups[name]) do
                    add(index .. ". " .. variable, 2)
                end
            end
        end,
    },
    {
        "trackingNameRenames",
        "Tracking name renames",
        function(add, renames) writePairs(add, renames, tostring) end,
    },
    {
        "extraBossStructs",
        "Extra boss structs",
        function(add, structs)
            for _, struct in ipairs(structs) do
                add(struct, 1)
            end
        end,
    },
    {
        "extraObjectGroups",
        "Extra object groups",
        function(add, groups)
            writePairs(add, groups, function(ids) return table.concat(ids, ", ") end)
        end,
    },
    {
        "dropOnly",
        "Drops-only logs",
        function(add, names)
            for _, name in ipairs(names) do
                add(name, 1)
            end
        end,
    },
    { "aliases", "Aliases", function(add, aliases) writePairs(add, aliases, tostring) end },
}

local function linesFor(snapshot)
    local lines, add = writer()
    add("Last check: " .. tostring(snapshot.status or "Not checked yet"), 0, "muted")
    if type(snapshot.values) == "table" then
        add("Version: " .. tostring(snapshot.values.version or "Not provided"))
        add("Revision: " .. tostring(snapshot.values.revision or "Not provided"))
    end
    add("")
    if snapshot.text == nil or snapshot.text == "" then
        add("No OTA values are currently stored.")
    elseif snapshot.values == nil then
        add("The stored OTA payload could not be decoded.", 0, "error")
        add(tostring(snapshot.error or "Unknown decoding error"), 0, "error")
        add("")
        add(snapshot.text)
    elseif snapshot.patch == nil then
        add("This version cannot read patch format " .. tostring(snapshot.values.format) .. ".", 0, "error")
    else
        local empty = true
        for _, section in ipairs(SECTIONS) do
            local value = snapshot.patch[section[1]]
            if next(value) ~= nil then
                if not empty then add("") end
                add(section[2], 0, "heading")
                section[3](add, value)
                empty = false
            end
        end
        if empty then add("The stored patch is empty, so only bundled data is used.") end
    end
    return lines
end

local STYLES = {
    heading = { font = id.Font.MUSEO_SANS_13PT_BOLD, colour = GOLD },
    name = { font = id.Font.MUSEO_SANS_11PT_REGULAR, colour = GOLD },
    muted = { font = id.Font.MUSEO_SANS_11PT_REGULAR, colour = MUTED },
    error = { font = id.Font.MUSEO_SANS_11PT_REGULAR, colour = ERROR },
    text = { font = id.Font.MUSEO_SANS_11PT_REGULAR, colour = TEXT },
}

function BossPatchValuesWindow.new(parent, snapshot, onClose)
    local self = setmetatable({}, BossPatchValuesWindow)
    local lines = linesFor(snapshot or {})
    local contentHeight = math.max(454, INSET * 2 + #lines * LINE_HEIGHT)
    local window
    window = prettyui.Window.new(parent, {
        title = "Stored OTA Values",
        x = -380,
        y = -260,
        xAnchor = 0.5,
        yAnchor = 0.5,
        width = 760,
        height = 520,
        minWidth = 520,
        minHeight = 320,
        scrollable = true,
        scrollStep = LINE_HEIGHT * 3,
        contentHeight = contentHeight,
        destroyOnClose = true,
        onClose = function()
            if type(onClose) == "function" then onClose(self) end
        end,
    })
    self.window = window
    -- PrettyUI windows start hidden
    window:Show()

    local width = math.max(1, window.content.width - INSET * 2)
    for index, line in ipairs(lines) do
        local x = INSET + line.depth * INDENT
        UI.Text(
            window.content,
            line.text,
            x,
            INSET + (index - 1) * LINE_HEIGHT,
            width - line.depth * INDENT,
            LINE_HEIGHT,
            STYLES[line.style or "text"]
        )
    end
    return self
end

function BossPatchValuesWindow:Destroy()
    if self.window ~= nil then
        self.window:Destroy()
        self.window = nil
    end
end

return BossPatchValuesWindow
