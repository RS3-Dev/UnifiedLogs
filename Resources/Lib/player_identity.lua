-- Resolve the current character's storage namespace.
local Identity = {}

function Identity.Current()
    local ok, value = pcall(function()
        if not Plugin.HasPermission(PluginPermissions.trackingAccess) then return nil end
        if not Player.IsAvailable() then return nil end
        return Player.GetTrackingID()
    end)
    if not ok or value == nil then return nil end
    -- Preserve the full 64-bit ID without converting it to floating point.
    local key = tostring(value)
    if not string.match(key, "^%-?%d+$") then return nil end
    return key
end

function Identity.Key(playerID, key)
    if playerID == nil then return nil end
    return "unifiedlogs:player:" .. playerID .. ":" .. key
end

return Identity
