-- Prepare collection descriptors without UI components
local CollectionEntries = {}

-- Empty and unresolved logs must never appear completed.
function CollectionEntries.IsComplete(entries, options)
    if options.showProgress == false or #entries == 0 then return false end
    local complete = true
    for _, entry in ipairs(entries) do
        local value = options.getValue(entry.v)
        if not options.isCollected(entry, value) then complete = false end
    end
    return complete
end

function CollectionEntries.PrepareGroup(name, entries, options)
    local showProgress = options.showProgress ~= false
    local group = {
        name = name,
        entries = entries,
        objects = {},
        states = {},
        collected = 0,
        total = #entries,
        showProgress = showProgress,
        showHeader = options.showHeader,
        emptyText = options.emptyText,
    }
    for index, entry in ipairs(entries) do
        local value = showProgress and options.getValue(entry.v) or nil
        local complete = not showProgress or options.isCollected(entry, value)
        group.states[index] = complete
        if showProgress and complete then group.collected = group.collected + 1 end
        local object = options.resolveObject(name, entry, index)
        local quantity
        if complete and options.showQuantities ~= false then
            if entry.min ~= nil or value == true then
                quantity = 1
            elseif type(value) == "number" then
                quantity = math.max(1, math.floor(value))
            end
        end
        group.objects[index] = {
            object = object,
            placeholder = entry.placeholder == true,
            spriteID = entry.spriteID,
            tooltip = options.tooltip(object, entry, value),
            quantity = quantity,
        }
    end
    return group
end

return CollectionEntries
