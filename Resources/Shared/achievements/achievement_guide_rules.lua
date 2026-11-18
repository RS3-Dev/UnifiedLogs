-- Evaluate native requirement objects without an achievement ID catalogue.
-- https://developer.runescape.com/rs/game/config/achievementtype.html
local Read = require("Resources/Shared/client_config").Read
local Rules = {}

local function ordered(source)
    local keys = {}
    if type(source) == "table" then
        for key in pairs(source) do if type(key) == "number" then keys[#keys + 1] = key end end
        table.sort(keys)
    end
    return keys
end

local function nativeComplete(test)
    local value = Read(test, "isComplete")
    if type(value) ~= "boolean" then value = Read(test, "complete") end
    if type(value) == "boolean" then return value end
end

function Rules.Evaluate(test, kind, reader)
    if kind == "varTotals" then
        local variables, target = Read(test, "vars"), tonumber(Read(test, "totalValue"))
        local keys = ordered(variables)
        if target ~= nil and #keys > 0 then
            local total = 0
            for _, key in ipairs(keys) do
                local value = tonumber(reader(variables[key]))
                if value == nil then return nil end
                total = total + value
            end
            return total >= target
        end
    elseif kind == "varTestBits" then
        local variable = Read(test, "var")
        local bit = math.tointeger(tonumber(Read(test, "bitIndex")) or -1)
        local expected = tonumber(Read(test, "bitValue"))
        if variable ~= nil and bit ~= nil and bit >= 0 and bit < 32 and (expected == 0 or expected == 1) then
            local value = math.tointeger(tonumber(reader(variable)) or 0/0)
            if value == nil then return nil end
            return ((value >> bit) & 1) == expected
        end
    end
    return nativeComplete(test)
end

function Rules.Entries(achievement, options)
    local requirements = Read(achievement, "requirements")
    local entries, values, resolved = {}, {}, {}
    local function reader(variable)
        if not resolved[variable] then
            values[variable], resolved[variable] = Read(variable, "value"), true
        end
        return values[variable]
    end
    for _, kind in ipairs({ "varTotals", "varTestBits", "achievements", "quests", "skills" }) do
        local tests = Read(requirements, kind)
        for _, key in ipairs(ordered(tests)) do
            local test = tests[key]
            local text = Read(test, "description")
            if type(text) ~= "string" or text == "" then
                local reference = Read(test, "achievement") or Read(test, "quest") or test
                text = Read(reference, "displayName") or Read(reference, "name")
                if kind == "skills" then
                    local skills, names = Read(test, "skillTypes"), {}
                    for _, index in ipairs(ordered(skills)) do
                        names[#names + 1] = tostring(Read(skills[index], "name") or skills[index])
                    end
                    if #names > 0 then text = table.concat(names, " + ") end
                    local level = Read(test, "totalLevels")
                    if text and level then text = tostring(text) .. " level " .. tostring(level) end
                end
            end
            if type(text) == "string" and text ~= "" then
                local entry = { text = text }
                entry.resolve = function() return Rules.Evaluate(test, kind, reader) end
                if options and options.defer then entry.loaded = false
                else entry.complete, entry.loaded = entry.resolve(), true end
                entries[#entries + 1] = entry
            end
        end
    end
    if #entries == 0 then return nil end
    return entries
end

return Rules
