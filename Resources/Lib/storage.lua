-- Guard PersistentDB access
local Storage = {}

function Storage.ReadStructured(key)
    local ok, value = pcall(function() return PersistentDB:GetStructuredData(key) end)
    return ok and value or nil
end

function Storage.WriteStructured(key, value)
    local ok, result = pcall(function() return PersistentDB:SetStructuredData(key, value) end)
    return ok and result ~= false
end

function Storage.KeysWithPrefix(prefix)
    local keys = {}
    local ok = pcall(function()
        PersistentDB:IterateEntries(function(key)
            if type(key) == "string" and key:sub(1, #prefix) == prefix then
                keys[#keys + 1] = key
            end
            return false
        end)
    end)
    if not ok then return nil end
    table.sort(keys)
    return keys
end

function Storage.Delete(key)
    local ok, result = pcall(function() return PersistentDB:Delete(key) end)
    return ok and result == true
end

return Storage
