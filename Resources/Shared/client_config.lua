-- Guard client config reads
local ClientConfig = {}

-- Read a client config value
function ClientConfig.Read(object, key)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    return ok and value or nil
end

-- Resolve a client config by name
function ClientConfig.Named(namespace, name)
    if namespace == nil or type(name) ~= "string" or name == "" then return nil end
    return ClientConfig.Read(namespace, name)
end

-- Resolve a client config by ID
function ClientConfig.FromID(namespace, identifier)
    if namespace == nil or identifier == nil then return nil end
    local ok, object = pcall(function()
        if namespace.FromID == nil then return nil end
        return namespace.FromID(identifier)
    end)
    return ok and object or nil
end

-- Read a client config column
function ClientConfig.Column(row, index)
    if row == nil then return {} end
    local ok, values = pcall(function()
        if row.GetColumnValues == nil then return nil end
        return row:GetColumnValues(index)
    end)
    return ok and type(values) == "table" and values or {}
end

-- Read a client config parameter
function ClientConfig.Param(object, parameter)
    if object == nil or parameter == nil then return nil end
    local ok, value = pcall(function()
        if object.GetParamValue == nil then return nil end
        return object:GetParamValue(parameter)
    end)
    return ok and value or nil
end

-- Read a client config name
function ClientConfig.ConfigName(object)
    local name = ClientConfig.Read(object, "configName")
    if type(name) == "string" then return name end
    return string.match(tostring(object or ""), "config%.[^.]+%.([^%(]+)%(")
end

return ClientConfig
