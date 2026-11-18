-- Build completion cape requirements
local AchievementText = require("Resources/Shared/achievements/achievement_text")
local ClientConfig = require("Resources/Shared/client_config")

local CapeRequirements = {}

local field = ClientConfig.Read

-- Create a requirement snapshot
function CapeRequirements.NewSnapshot(options)
    local snapshot = {
        summaryNodes = {},
        detailNodes = {},
        deferred = options ~= nil,
        states = {}, queue = {}, cursor = 1, visible = {},
    }
    if options then
        local event = "unifiedlogs_cape_progress"
        function snapshot:Stop() self.running = false; Event.Logic.Unsubscribe(event) end
        function snapshot:Tick()
            if options.isVisible and not options.isVisible() then return end
            local changed, read = false, 0
            local function update(state)
                if state == nil or state.loaded then return end
                state.complete, state.loaded = state.read(), true
                for _, node in ipairs(state.nodes) do
                    node.complete, node.loaded = state.complete, true
                end
                changed, read = true, read + 1
            end
            for _, node in ipairs(self.visible) do
                if read >= 8 then break end
                update(node.progressState)
            end
            local background = 0
            while self.cursor <= #self.queue and background < 4 do
                local state = self.queue[self.cursor]
                self.cursor = self.cursor + 1
                if not state.loaded then update(state); background = background + 1 end
            end
            if self.cursor > #self.queue then self:Stop() end
            if changed and options.onChanged then options.onChanged() end
        end
        function snapshot:Wake()
            if self.running then return end
            self.running = true
            Event.Logic.Subscribe(event, function() self:Tick() end)
        end
    end
    return snapshot
end

-- Register state without reading player values while the requirement tree is built.
local function trackNode(snapshot, node, reader)
    if snapshot == nil or not snapshot.deferred then node.complete = reader(); return end
    local state = snapshot.states[node.key]
    if state == nil then
        state = { read = reader, nodes = {} }
        snapshot.states[node.key] = state
        snapshot.queue[#snapshot.queue + 1] = state
        snapshot:Wake()
    end
    state.nodes[#state.nodes + 1] = node
    node.progressState, node.complete, node.loaded = state, state.complete, state.loaded == true
end

-- Get the requirement node cache
local function nodeCache(snapshot, details)
    if snapshot == nil then return {} end
    local key = details and "detailNodes" or "summaryNodes"
    snapshot[key] = snapshot[key] or {}
    return snapshot[key]
end

-- Read the first available field
local function firstField(source, keys)
    for _, key in ipairs(keys) do
        local value = field(source, key)
        if value ~= nil then return value end
    end
    return nil
end

-- Read a numeric field
local function numberField(source, keys) return tonumber(firstField(source, keys)) end

-- Read a text field
local function stringField(source, keys)
    local value = firstField(source, keys)
    return type(value) == "string" and value ~= "" and value or nil
end

-- Read config values
local function values(source)
    local result = {}
    if source == nil then return result end
    local ok = pcall(function()
        for _, value in ipairs(source) do
            result[#result + 1] = value
        end
    end)
    if ok and #result > 0 then return result end
    pcall(function()
        for _, value in pairs(source) do
            result[#result + 1] = value
        end
    end)
    return result
end

-- Resolve an achievement by ID
local function achievementFromID(achievementID)
    return ClientConfig.FromID(config ~= nil and config.Achievement or nil, achievementID)
end

-- Resolve the cape achievement
local function achievementFromCape(cape)
    if cape.achievement then return cape.achievement end
    if config == nil or config.Achievement == nil then return nil end
    return ClientConfig.Named(config.Achievement, cape.achievementConfig)
        or achievementFromID(tonumber(cape.achievementID))
end

-- Check achievement completion
local function achievementComplete(achievement)
    if field(achievement, "complete") == true or field(achievement, "isComplete") == true then
        return true
    end
    local progress = tonumber(field(achievement, "progress"))
    return progress == -2 or progress ~= nil and progress >= 10000
end

-- Build a stable achievement key
local function achievementKey(achievement)
    local achievementID = numberField(achievement, { "id", "achievementID", "achievementId" })
    if achievementID ~= nil then return "achievement:" .. tostring(achievementID) end
    local configName = stringField(achievement, { "configName", "name" })
    return configName ~= nil and "achievement:" .. configName or nil
end

-- Build the achievement guide
function CapeRequirements.Guide(node, options)
    if node == nil then return nil end
    local rawEntries = AchievementText.GuideEntries(node.source, options)
    local entries, skippedSummary = {}, false
    for _, entry in ipairs(rawEntries) do
        if not skippedSummary and entry.text == node.description then
            skippedSummary = true
        else
            entries[#entries + 1] = entry
        end
    end

    local total = numberField(node.source, { "totalRequirementCount" }) or #entries
    total = math.max(total, #entries)
    local complete = node.complete == true and total or 0
    if rawEntries.verifiedProgress then total = #entries end
    if node.complete ~= true then
        for _, entry in ipairs(entries) do if entry.complete == true then complete = complete + 1 end end
    end
    if node.complete == true then
        complete = total
        for _, entry in ipairs(entries) do
            entry.complete = true
            entry.loaded = true
        end
    end

    return {
        name = node.name,
        description = node.description or "",
        complete = complete,
        total = total,
        entries = entries,
        achievementComplete = node.complete == true,
        runeScore = node.runeScore or 0,
    }
end

-- Build linear requirement rows
function CapeRequirements.LinearRows(root)
    local rows, visited = {}, {}
    -- Visit requirement nodes
    local function visit(node)
        if node == nil or visited[node.key] then return end
        visited[node.key] = true
        for _, child in ipairs(node.children or {}) do
            visit(child)
        end
        rows[#rows + 1] = { node = node, depth = 0, index = #rows + 1 }
    end
    for _, child in ipairs(root ~= nil and root.children or {}) do
        visit(child)
    end
    return rows
end

-- Build tree requirement rows
function CapeRequirements.TreeRows(root)
    local rows = {}
    -- Visit requirement nodes
    local function visit(node, depth, continuations, isLast, path)
        if node == nil or path[node.key] then return end
        local rowContinuations = {}
        for level, continues in pairs(continuations or {}) do
            rowContinuations[level] = continues == true
        end
        rows[#rows + 1] = {
            node = node,
            depth = depth,
            continuations = rowContinuations,
            isLast = isLast == true,
        }
        path[node.key] = true
        for index, child in ipairs(node.children or {}) do
            local childContinuations = {}
            for level, continues in pairs(rowContinuations) do
                childContinuations[level] = continues
            end
            childContinuations[depth + 1] = index < #(node.children or {})
            visit(child, depth + 1, childContinuations, index == #(node.children or {}), path)
        end
        path[node.key] = nil
    end
    local children = root ~= nil and root.children or {}
    for index, child in ipairs(children) do
        visit(child, 0, {}, index == #children, {})
    end
    return rows
end

function CapeRequirements.IsUnblocked(node)
    if node == nil or node.complete == true then return false end
    if node.achievementOnly then return node.prereqsComplete == true end
    for _, prerequisite in ipairs(node.children or {}) do
        if prerequisite.complete ~= true then return false end
    end
    return true
end

function CapeRequirements.FilterRows(rows, mode, query)
    query = string.lower(tostring(query or ""))
    local filtered = {}
    for _, row in ipairs(rows or {}) do
        local include = mode == "incomplete" and row.node.complete ~= true
            or mode == "unblocked" and CapeRequirements.IsUnblocked(row.node)
            or mode ~= "incomplete" and mode ~= "unblocked"
        if include and query ~= "" then
            local searchable = row.node.searchText
            if searchable == nil then
                searchable = string.lower(
                    tostring(row.node.name or "") .. " " .. tostring(row.node.description or "")
                )
                row.node.searchText = searchable
            end
            include = string.find(searchable, query, 1, true) ~= nil
        end
        if include then filtered[#filtered + 1] = row end
    end
    return filtered
end

-- Calculate requirement progress
local function progress(root)
    local complete, total, pending, visited = 0, 0, 0, { [root.key] = true }
    -- Visit requirement nodes
    local function visit(node)
        if visited[node.key] then return end
        visited[node.key] = true
        total = total + 1
        if node.loaded == false then pending = pending + 1 end
        if node.complete then complete = complete + 1 end
        for _, child in ipairs(node.children) do
            visit(child)
        end
    end
    for _, child in ipairs(root.children) do
        visit(child)
    end
    return complete, total, pending
end

-- Build a cape requirement snapshot
local function buildGraph(cape, snapshot, details)
    local source = achievementFromCape(cape)
    if source == nil then return nil end
    local root = { key = achievementKey(source), children = {} }
    local cache = nodeCache(snapshot, details)
    local path = { [root.key] = true }
    local function visit(reference)
        local achievement = field(reference, "achievement") or reference
        if type(achievement) == "number" then
            local key = "achievement:" .. achievement
            if path[key] then return nil end
            if cache[key] then return cache[key] end
            achievement = achievementFromID(achievement)
        end
        local key = achievementKey(achievement)
        if key == nil or path[key] then return nil end
        if cache[key] then return cache[key] end
        local node = { key = key, children = {}, achievementOnly = true }
        if details then
            node.source = achievement
            node.name = stringField(achievement, { "displayName", "title", "name" }) or key
            node.description = AchievementText.Description(achievement)
            node.runeScore = tonumber(field(achievement, "runeScore")) or 0
        end
        cache[key], path[key] = node, true
        trackNode(snapshot, node, function()
            node.prereqsComplete = field(achievement, "prereqsComplete")
            return achievementComplete(achievement)
        end)
        local seen = {}
        for _, family in ipairs({ "requirements", "prereqs" }) do
            local requirements = field(achievement, family)
            for _, childReference in ipairs(values(field(requirements, "achievements"))) do
                local child = visit(childReference)
                if child and not seen[child.key] then
                    seen[child.key] = true
                    node.children[#node.children + 1] = child
                end
            end
        end
        path[key] = nil
        return node
    end
    local references = cape.entries or values(field(field(source, "requirements"), "achievements"))
    local seen = {}
    for _, reference in ipairs(references) do
        local node = visit(reference)
        if node and not seen[node.key] then
            seen[node.key] = true
            root.children[#root.children + 1] = node
        end
    end
    if details then table.sort(root.children, function(a, b) return a.name < b.name end) end
    return root
end

-- Read the cape's native progress without enumerating any requirements.
function CapeRequirements.FastSummary(cape)
    local source = achievementFromCape(cape)
    local value = tonumber(field(source, "progress"))
    if value == nil then return { available = false, complete = 0, total = 10000 } end
    value = value == -2 and 10000 or math.max(0, math.min(10000, value))
    return { available = true, complete = value, total = 10000,
        label = string.format("%.1f%%", value / 100) }
end

-- Build a cape requirement snapshot
function CapeRequirements.Build(cape, snapshot)
    local root = buildGraph(cape, snapshot, true)
    if root == nil then return nil end
    local complete, total = progress(root)
    return { cape = cape, root = root, linearRows = CapeRequirements.LinearRows(root), complete = complete, total = total }
end

-- Select visible requirement rows
function CapeRequirements.Rows(data, orderView)
    if orderView ~= "tree" then return data.linearRows end
    data.treeRows = data.treeRows or CapeRequirements.TreeRows(data.root)
    return data.treeRows
end

-- Build the cape progress summary
function CapeRequirements.Summary(cape, snapshot)
    local root = buildGraph(cape, snapshot, false)
    if root == nil then return { complete = 0, total = 0, available = false } end
    local complete, total, pending = progress(root)
    return {
        complete = complete,
        total = total,
        pending = pending,
        available = true,
    }
end

return CapeRequirements
