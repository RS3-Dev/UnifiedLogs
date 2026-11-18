-- Discover area task sets from native metadata and load only the selected area.
local UI = require("Resources/Shared/ui/components")
local ClientConfig = require("Resources/Shared/client_config")
local Read = ClientConfig.Read
local Sidebar = require("Resources/Shared/ui/sidebar_pages")
local Requirements = require("Resources/Features/achievements/cape_requirements")
local View = require("Resources/Features/achievements/cape_requirements_view")
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
    for area in pairs(self.groups) do modes[#modes + 1] = { id = area, label = area } end
    table.sort(modes, function(a, b) return a.label < b.label end)
    if #modes == 0 then
        UI.Text(self.root, "Unable to resolve the area task index. Reload Unified Logs to retry.", 12, 12, self.root.width - 24, 30)
        return
    end
    self.host = Sidebar.new(self.root, modes, self.context.state.areaTaskArea,
        function(_, _, value) self:SetArea(value) end)
    self.host.shell.sidebarTitle.content = "AREAS"
    self:SetArea(self.context.state.areaTaskArea or modes[1].id)
end
function Page:SetArea(value)
    if self.snapshot then self.snapshot:Stop() end
    local context = self.context
    self.snapshot = Requirements.NewSnapshot({ achievementOnly = true, isVisible = context.isVisible,
        onChanged = function() if self.view then self.view:ApplyFilters(true) end end })
    self.view = self.host:Activate(value, true, function(mode, mount)
        context.state.areaTaskArea = mode.id
        local tests = {}
        local order = { Beginner = 1, Easy = 2, Medium = 3, Hard = 4, Elite = 5 }
        table.sort(self.groups[mode.id], function(a, b) return (order[a.difficulty] or 9) < (order[b.difficulty] or 9) end)
        local seen = {}
        for _, item in ipairs(self.groups[mode.id]) do
            local requirements = Read(item.achievement, "requirements")
            for _, test in ipairs(Read(requirements, "achievements") or {}) do
                local achievement = Read(test, "achievement") or test
                local key = Read(achievement, "id") or Read(achievement, "configName") or achievement
                if not seen[key] then
                    seen[key] = true
                    tests[#tests + 1] = { achievement = achievement }
                end
            end
        end
        local source = { name = "Area Tasks: " .. mode.id, configName = "unifiedlogs_area_" .. mode.id,
            requirements = { achievements = tests }, progress = 0 }
        return View.new(mount, { width = mount.width, height = mount.height,
            cape = { name = mode.id .. " Area Tasks", achievement = source }, snapshot = self.snapshot,
            orderView = "linear", filterMode = context.state.areaTaskFilter, search = context.state.areaTaskSearch,
            isVisible = context.isVisible,
            onFilterChange = function(v) context.state.areaTaskFilter = v; context.saveState() end,
            onSearchChange = function(v, persist) context.state.areaTaskSearch = v; if persist then context.saveState() end end,
        })
    end)
    context.saveState()
end
function Page:RefreshAccountState() if self.host then self:SetArea(self.context.state.areaTaskArea) end end
function Page:Destroy()
    self.stopped = true
    if self.event then Event.Logic.Unsubscribe(self.event) end
    if self.snapshot then self.snapshot:Stop() end
    if self.host then self.host:Destroy() end
    self.root:Destroy()
end
return Page
