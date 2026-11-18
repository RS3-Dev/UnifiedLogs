-- Prepare visible collection entries first, with bounded work for aggregate totals.
local Entries = require("Resources/Shared/collections/collection_entries")
local GameData = require("Resources/Lib/game_data")
local Preparer = {}
Preparer.__index = Preparer
local nextID = 0

function Preparer.new(options)
    nextID = nextID + 1
    return setmetatable({ options = options, jobs = {}, groups = {}, visible = {}, cursor = 1,
        pending = 0, complete = {}, event = "unifiedlogs_collection_prepare_" .. nextID }, Preparer)
end

-- Share cache, viewport, and account-read policy across item collection pages.
function Preparer.Collection(options, onChanged, cache)
    local settings, progress = {}, options.progress
    for key, value in pairs(options) do settings[key] = value end
    cache = cache or options.objectCache or {}
    settings.getValue = options.readValue or options.getValue or function(name) return progress:ReadValueNow(name) end
    settings.isCollected = options.isCollected or function(entry, value) return progress:IsCollected(entry, value) end
    settings.stateOnly, settings.visibleBudget, settings.onChanged = true, 32, onChanged
    settings.isCached = progress and function(entry)
        local resolved = progress.resolved or {}
        return resolved[entry.v] and (not entry.storedVariable or resolved[entry.storedVariable])
    end
    settings.cachedObject = function(entry) return cache[entry] end
    local resolve = options.resolveObject or GameData.CollectionObject
    settings.resolveObject = function(name, entry, index)
        local object = cache[entry]
        if object == nil then object = resolve(name, entry, index); cache[entry] = object end
        return object
    end
    settings.tooltip = options.tooltip or GameData.CollectionTooltip
    return Preparer.new(settings)
end

function Preparer:AddGroup(name, entries)
    local group = { name = name, entries = entries, total = #entries, collected = 0,
        loadedCount = 0, revision = 0, objects = {}, states = {}, jobs = {},
        showProgress = self.options.showProgress ~= false, preparer = self }
    for index, entry in ipairs(entries) do
        local job = { entry = entry, group = group, index = index, visualLoaded = false }
        self.jobs[#self.jobs + 1], group.jobs[index] = job, job
        if self.options.stateOnly and self.options.isCached and self.options.isCached(entry) then
            local value = self.options.getValue(entry.v)
            local complete = not group.showProgress or self.options.isCollected(entry, value)
            job.loaded = true
            group.states[index], self.complete[entry] = complete, complete
            group.loadedCount = group.loadedCount + 1
            if group.showProgress and complete then group.collected = group.collected + 1 end
        else
            self.pending = self.pending + 1
        end
    end
    self.groups[#self.groups + 1] = group
    return group
end

function Preparer:SetVisibleRows(rows)
    self.visible = {}
    for _, row in ipairs(rows) do
        if row.group and row.group.preparer == self and row.first then
            for index = row.first, row.last do
                local job = row.group.jobs[index]
                if job.loaded and not job.visualLoaded and self.options.cachedObject
                    and self.options.cachedObject(job.entry) ~= nil then
                    local object = Entries.PrepareEntry(row.group.name, job.entry, index, self.options)
                    row.group.objects[index], job.visualLoaded = object, true
                    row.revision = (row.revision or 0) + 1
                end
                self.visible[#self.visible + 1] = job
            end
        end
    end
    self:Start()
end

function Preparer:Stop()
    Event.Logic.Unsubscribe(self.event)
    self.running = false
end

function Preparer:HasVisibleWork()
    for _, job in ipairs(self.visible) do if not job.visualLoaded then return true end end
    return false
end

function Preparer:Start()
    if self.running or self.pending == 0 and not self:HasVisibleWork() then return end
    self.running = true
    Event.Logic.Subscribe(self.event, function() self:Tick() end)
end

function Preparer:Tick()
    if not self.running then return end
    if self.options.isVisible and not self.options.isVisible() then return end
    local read = 0
    local function prepare(job, visual)
        if job == nil or (visual and job.visualLoaded or not visual and job.loaded) then return end
        local group = job.group
        local object, complete
        if self.options.prepareEntry then
            object, complete = self.options.prepareEntry(job.entry, job.index, group)
            visual = true
        elseif visual or not self.options.stateOnly then
            if job.entry.storedVariable then self.options.getValue(job.entry.storedVariable) end
            object, complete = Entries.PrepareEntry(group.name, job.entry, job.index, self.options)
            visual = true
        else
            if job.entry.storedVariable then self.options.getValue(job.entry.storedVariable) end
            complete = not group.showProgress or self.options.isCollected(job.entry, self.options.getValue(job.entry.v))
        end
        if visual then
            group.objects[job.index], job.visualLoaded = object, true
        end
        local previous = group.states[job.index]
        if job.loaded and group.showProgress and previous ~= complete then
            group.collected = group.collected + (complete and 1 or 0) - (previous and 1 or 0)
        end
        group.states[job.index] = complete
        if not job.loaded then
            job.loaded = true
            group.loadedCount = group.loadedCount + 1
            if group.showProgress and complete then group.collected = group.collected + 1 end
            self.complete[job.entry], self.pending = complete, self.pending - 1
        end
        self.complete[job.entry] = complete
        group.revision = group.revision + 1
        if job.row then job.row.revision = (job.row.revision or 0) + 1 end
        read = read + 1
    end
    for _, job in ipairs(self.visible) do
        if read >= (self.options.visibleBudget or 8) then break end
        prepare(job, true)
    end
    local background, cached = 0, 0
    while self.cursor <= #self.jobs do
        local job = self.jobs[self.cursor]
        if not job.loaded then
            local known = self.options.isCached and self.options.isCached(job.entry)
            if known then
                if cached >= 128 then break end
                cached = cached + 1
            else
                if background >= 4 then break end
                background = background + 1
            end
            prepare(job, false)
        end
        self.cursor = self.cursor + 1
    end
    if self.pending == 0 and not self:HasVisibleWork() then self:Stop() end
    if read > 0 and self.options.onChanged then self.options.onChanged(self) end
end

return Preparer
