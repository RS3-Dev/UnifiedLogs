-- Coordinate bounded feature loading, readiness, and cancellation
local FeatureLoader = {
    loadTask = nil,
    pending = {},
    ready = {},
    resumesPerTick = 64,
}

local function startNext()
    if FeatureLoader.loadTask ~= nil or #FeatureLoader.pending == 0 then return end
    local request = table.remove(FeatureLoader.pending, 1)
    request.coroutine = coroutine.create(function()
        local warnings = {}
        local visiting = {}
        -- Load one feature module
        local function load(id)
            local feature = request.registry.byID[id]
            if FeatureLoader.ready[feature] then return end
            assert(not visiting[id], "cyclic feature dependency: " .. id)
            visiting[id] = true
            for _, dependency in ipairs(feature.dependencies or {}) do
                load(dependency)
            end
            if feature.LoadData ~= nil then
                local warning = feature.LoadData(request.registry, coroutine.yield)
                if warning ~= nil then warnings[#warnings + 1] = warning end
            end
            visiting[id] = nil
            FeatureLoader.ready[feature] = true
        end
        load(request.sectionID)
        return { registry = request.registry, warnings = warnings }
    end)
    FeatureLoader.loadTask = request
end

function FeatureLoader.LoadFeatureAsync(registry, sectionID, callback)
    if FeatureLoader.ready[registry.byID[sectionID]] then
        callback({ registry = registry, warnings = {} })
        return true
    end
    local requests = {}
    if FeatureLoader.loadTask ~= nil then requests[#requests + 1] = FeatureLoader.loadTask end
    for _, request in ipairs(FeatureLoader.pending) do
        requests[#requests + 1] = request
    end
    for _, request in ipairs(requests) do
        if request.registry == registry and request.sectionID == sectionID then
            request.callbacks[#request.callbacks + 1] = callback
            return true
        end
    end
    FeatureLoader.pending[#FeatureLoader.pending + 1] = {
        registry = registry,
        sectionID = sectionID,
        callbacks = { callback },
    }
    startNext()
    return true
end

function FeatureLoader.IsReady(registry, sectionID)
    return FeatureLoader.ready[registry.byID[sectionID]] == true
end

-- Advance feature loading
function FeatureLoader.Tick()
    for _ = 1, FeatureLoader.resumesPerTick do
        local task = FeatureLoader.loadTask
        if task == nil then return end
        local ok, value = coroutine.resume(task.coroutine)
        if not ok or coroutine.status(task.coroutine) == "dead" then
            FeatureLoader.loadTask = nil
            for _, callback in ipairs(task.callbacks) do
                callback(ok and value or nil, not ok and value or nil)
            end
            startNext()
        end
    end
end

-- Stop feature loader
function FeatureLoader.Shutdown()
    FeatureLoader.loadTask = nil
    FeatureLoader.pending = {}
    FeatureLoader.ready = {}
end

return FeatureLoader
