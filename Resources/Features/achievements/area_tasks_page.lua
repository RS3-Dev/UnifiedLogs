-- Discover area task sets from native metadata and load only the selected area.
local UI = require("Resources/Shared/ui/components")
local ClientConfig = require("Resources/Shared/client_config")
local Read = ClientConfig.Read
local Browser = require("Resources/Features/achievements/achievements_page")
local discoveryCache = setmetatable({}, { __mode = "k" })
local Page = {}
Page.__index = Page
function Page.new(parent, context)
    local self = setmetatable({ context = context, groups = {}, stopped = false }, Page)
    self.root = UI.ContentLayer(parent)
    self.root:SetSize(context.width, context.height)
    self.loading = UI.Text(self.root, "Loading area tasks...", 12, 12, context.width - 24, 30)
    local namespace = config.Achievement
    if discoveryCache[namespace] then
        self.groups = discoveryCache[namespace]
        self:Build()
        return self
    end
    local index = ClientConfig.Named(config.Enum, "CHEEVO_ALL_AREA_CHEEVOS_LIST")
        or ClientConfig.FromID(config.Enum, 12684)
    local indexed = Read(index, "values")
    local identifiers = id and Read(id, "Achievement")
    local iterator = coroutine.create(function()
        local count = 0
        local candidates = {}
        if type(indexed) == "table" then
            for _, entry in pairs(indexed) do
                local struct = type(entry) == "table" and entry[2] or entry
                if type(struct) == "number" then struct = ClientConfig.FromID(config.Struct, struct) end
                local name = ClientConfig.ConfigName(struct)
                local achievement = name and ClientConfig.Named(namespace, name)
                if achievement then candidates[#candidates + 1] = achievement end
            end
        end
        local function add(achievement, configName)
            local name = Read(achievement, "name") or Read(achievement, "displayName")
            if type(name) ~= "string" then return end
            local area, difficulty = name:match("^(.-) Set Tasks %- (.+)$")
            if area and type(configName) == "string" and configName:match("^CHEEVO_AT") then
                local group = self.groups[area] or {}
                self.groups[area] = group
                for _, item in ipairs(group) do if item.difficulty == difficulty then return true end end
                group[#group + 1] = { achievement = achievement, difficulty = difficulty }
                return true
            end
        end
        for _, achievement in ipairs(candidates) do add(achievement, Read(achievement, "configName")) end
        -- New task sets can reach the modern cape graph before the legacy index.
        -- Follow achievement links only; never evaluate progress or individual tests here.
        local root = ClientConfig.Named(namespace, "CHEEVO_TRIM_CAPE_META")
            or ClientConfig.Named(namespace, "CHEEVO_COMP_CAPE_META")
        local queue, seen, cursor = {}, {}, 1
        if root then queue[1] = root end
        while cursor <= #queue do
            local achievement = queue[cursor]
            cursor = cursor + 1
            local key = Read(achievement, "id") or ClientConfig.ConfigName(achievement) or achievement
            if not seen[key] then
                seen[key] = true
                if not add(achievement, ClientConfig.ConfigName(achievement)) then
                    local requirements = Read(achievement, "requirements")
                    for _, test in ipairs(Read(requirements, "achievements") or {}) do
                        queue[#queue + 1] = Read(test, "achievement") or test
                    end
                end
            end
            if cursor % 100 == 0 then coroutine.yield() end
        end
        if next(self.groups) ~= nil then return end
        for key, value in pairs(identifiers or namespace) do
            local achievement = value
            if identifiers then
                achievement = type(key) == "string" and key:match("^CHEEVO_AT") and Read(namespace, key) or nil
            end
            local configName = type(key) == "string" and key:match("^CHEEVO_") and key
                or Read(achievement, "configName") or ""
            if configName:match("^CHEEVO_AT") then add(achievement, configName) end
            count = count + 1
            if count % 400 == 0 then coroutine.yield() end
        end
    end)
    self.event = "unifiedlogs_area_task_discovery"
    Event.Logic.Subscribe(self.event, function()
        if self.stopped or context.isVisible and not context.isVisible() then return end
        local ok, reason = coroutine.resume(iterator)
        if not ok then
            Event.Logic.Unsubscribe(self.event)
            self.loading.content = "Unable to read area task metadata."
            log("unifiedlogs area task discovery: ", tostring(reason))
        elseif coroutine.status(iterator) == "dead" then
            Event.Logic.Unsubscribe(self.event)
            if next(self.groups) ~= nil then discoveryCache[namespace] = self.groups end
            self:Build()
        end
    end)
    return self
end
function Page:Build()
    self.loading:Destroy()
    self.loading = nil
    local modes = {}
    for area, sets in pairs(self.groups) do
        local entries = {}
        for _, set in ipairs(sets) do
            local requirements = Read(set.achievement, "requirements")
            for _, reference in ipairs(Read(requirements, "achievements") or {}) do entries[#entries + 1] = reference end
        end
        modes[#modes + 1] = { id = area, label = area,
            cape = { name = area .. " Area Tasks", achievement = { configName = area }, entries = entries } }
    end
    table.sort(modes, function(a, b) return a.label < b.label end)
    if #modes == 0 then
        UI.Text(self.root, "Unable to resolve the area task index. Reload Unified Logs to retry.", 12, 12, self.root.width - 24, 30)
        return
    end
    self.browser = Browser.new(self.root, {
        width = self.root.width, height = self.root.height, section = { modes = modes },
        state = self.context.state, saveState = self.context.saveState, isVisible = self.context.isVisible,
        stateKeys = { mode = "areaTaskArea", search = "areaTaskSearch", filter = "areaTaskFilter" },
        sidebarTitle = "AREAS", orderView = "linear",
    })
end
function Page:RefreshAccountState() if self.browser then self.browser:RefreshAccountState() end end
function Page:Destroy()
    self.stopped = true
    if self.event then Event.Logic.Unsubscribe(self.event) end
    if self.browser then self.browser:Destroy() end
    self.root:Destroy()
end
return Page
