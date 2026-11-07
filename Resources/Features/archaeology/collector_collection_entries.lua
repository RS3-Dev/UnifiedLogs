-- Prepare collector collection entries
local CollectorCollectionEntries = {}

CollectorCollectionEntries.ALL_COLLECTORS = "All collectors"

function CollectorCollectionEntries.IsComplete(value)
    return value == true or type(value) == "number" and value >= 1
end

-- Collect or names
function CollectorCollectionEntries.CollectorNames(records)
    local names = {}
    local seen = {}
    for _, record in ipairs(records or {}) do
        local name = record.collector
        if type(name) == "string" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    return names
end

function CollectorCollectionEntries.NormalizeSelection(records, selected)
    local names = CollectorCollectionEntries.CollectorNames(records)
    if selected == CollectorCollectionEntries.ALL_COLLECTORS then return selected, names end
    for _, name in ipairs(names) do
        if name == selected then return selected, names end
    end
    return CollectorCollectionEntries.ALL_COLLECTORS, names
end

function CollectorCollectionEntries.Prepare(records, selected, getValue)
    records = records or {}
    getValue = getValue or function() return 0 end

    local groups = {}
    local groupByName = {}
    local completeCount = 0
    local total = 0
    for _, record in ipairs(records) do
        if
            selected == CollectorCollectionEntries.ALL_COLLECTORS
            or record.collector == selected
        then
            local collector = tostring(record.collector or "Collector")
            local group = groupByName[collector]
            if group == nil then
                group = { name = collector, entries = {}, complete = 0 }
                groupByName[collector] = group
                groups[#groups + 1] = group
            end

            local complete = CollectorCollectionEntries.IsComplete(getValue(record.variableName))
            group.entries[#group.entries + 1] = {
                record = record,
                complete = complete,
            }
            if complete then
                group.complete = group.complete + 1
                completeCount = completeCount + 1
            end
            total = total + 1
        end
    end

    return {
        groups = groups,
        complete = completeCount,
        total = total,
        showGroupHeaders = selected == CollectorCollectionEntries.ALL_COLLECTORS,
    }
end

return CollectorCollectionEntries
