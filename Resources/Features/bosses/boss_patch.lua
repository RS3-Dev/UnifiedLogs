-- Fetch boss catalogue additions published between plugin releases
local Json = require("Resources/Lib/json")
local Storage = require("Resources/Lib/storage")

local BossPatch = { current = nil, text = nil, request = nil, status = "Not checked yet" }

local STORAGE_KEY = "unifiedlogs:boss_patch:v1"
local PATCH_PATH = "/RS3-Dev/UnifiedLogs/main/Patches/patch.json"
local FORMAT = 1

local function isText(value) return type(value) == "string" and value ~= "" end
local function isNumber(value) return math.type(value) == "integer" end

-- Check that a value is a non-empty list of valid items
local function every(value, check)
    if type(value) ~= "table" or #value == 0 then return false end
    for _, item in ipairs(value) do
        if not check(item) then return false end
    end
    return true
end

-- Metric rows match the bundled catalogs: label, variable, kind?, secondary?
local function isMetric(row)
    return type(row) == "table" and isText(row[1]) and isText(row[2])
        and (row[3] == nil or isText(row[3])) and (row[4] == nil or isText(row[4]))
end
local function isMetricGroup(row)
    return type(row) == "table" and isText(row[1]) and every(row[2], isMetric)
end
local function isRecordGroup(row)
    return type(row) == "table" and isText(row[1]) and every(row[2], isMetricGroup)
end

local function filteredList(value, check)
    local result = {}
    for _, item in ipairs(type(value) == "table" and value or {}) do
        if check(item) then result[#result + 1] = item end
    end
    return result
end

local function filteredMap(value, check)
    local result = {}
    for key, item in pairs(type(value) == "table" and value or {}) do
        if isText(key) and check(item) then result[key] = item end
    end
    return result
end

-- Keep the rows this version understands and drop anything malformed
function BossPatch.Decode(text)
    local patch = Json.Decode(text)
    if type(patch) ~= "table" or patch.format ~= FORMAT then return nil end
    return {
        version = patch.version,
        revision = patch.revision,
        killCounts = filteredList(patch.killCounts, isMetricGroup),
        records = filteredList(patch.records, isRecordGroup),
        trackingNames = filteredMap(patch.trackingNames, function(names)
            return every(names, isText)
        end),
        extraBossStructs = filteredList(patch.extraBossStructs, isText),
        extraObjectGroups = filteredMap(patch.extraObjectGroups, function(ids)
            return every(ids, isNumber)
        end),
        dropOnly = filteredList(patch.dropOnly, isText),
        aliases = filteredMap(patch.aliases, isText),
        trackingNameRenames = filteredMap(patch.trackingNameRenames, isText),
    }
end

-- Legacy payloads without version metadata still use content comparison.
function BossPatch.SameVersion(left, right)
    return type(left) == "table" and type(right) == "table"
        and type(left.version) == "string" and math.type(left.revision) == "integer"
        and left.version == right.version and left.revision == right.revision
end

-- Return the last saved patch, or an empty one
function BossPatch.Current()
    if BossPatch.current == nil then
        local saved = Storage.ReadStructured(STORAGE_KEY)
        BossPatch.text = type(saved) == "table" and saved.text or nil
        BossPatch.current = BossPatch.Decode(BossPatch.text) or BossPatch.Decode('{"format":1}')
    end
    return BossPatch.current
end

-- Read the persisted payload directly for diagnostics; do not use the in-memory patch
function BossPatch.StoredValues()
    local saved = Storage.ReadStructured(STORAGE_KEY)
    local text = type(saved) == "table" and saved.text or nil
    local values, reason = nil, nil
    if type(text) == "string" and text ~= "" then
        values, reason = Json.Decode(text)
    end
    return {
        key = STORAGE_KEY,
        text = text,
        values = values,
        -- The rows the plugin applies, after malformed ones are skipped
        patch = values ~= nil and BossPatch.Decode(text) or nil,
        error = reason,
        status = BossPatch.status,
    }
end

-- Record the outcome of a fetch for diagnostics
local function finish(status, onDone)
    BossPatch.status = status
    if onDone ~= nil then onDone(status) end
    return false
end

-- Describe a request that did not complete
local function failure(request)
    if request.timedOut then return "Request timed out" end
    if request.failed then return "Request failed (error " .. tostring(request.errorCode) .. ")" end
    return "Request cancelled"
end

-- Check whether the player granted the optional HTTP permission
function BossPatch.HasAccess()
    local ok, granted = pcall(function() return Plugin.HasPermission(PluginPermissions.httpAccess) end)
    return ok and granted == true
end

-- Request the published patch; onChanged runs only when it differs from the saved one,
-- and onDone receives a status describing every outcome
function BossPatch.Fetch(onChanged, onDone)
    if not BossPatch.HasAccess() then return finish("HTTP permission not granted", onDone) end
    local baseURL = type(Plugin.urls) == "table" and Plugin.urls.featfinder or nil
    if baseURL == nil then return finish("Manifest URL featfinder is missing", onDone) end
    if HTTPRequest == nil then return finish("HTTPRequest is unavailable", onDone) end
    local request = HTTPRequest.new(baseURL, PATCH_PATH)
    BossPatch.request, BossPatch.status = request, "Checking..."
    request:Get(function()
        if BossPatch.request ~= request then return end
        BossPatch.request = nil
        if not request.successful then return finish(failure(request), onDone) end
        if request.responseCode ~= 200 then
            return finish("HTTP " .. tostring(request.responseCode), onDone)
        end
        BossPatch.Current()
        if request.data == BossPatch.text then return finish("Up to date", onDone) end
        local patch = BossPatch.Decode(request.data)
        if patch == nil then
            log("unifiedlogs ignored an unreadable boss patch")
            return finish("Ignored an unreadable patch", onDone)
        end
        if BossPatch.SameVersion(BossPatch.Current(), patch) then return finish("Up to date", onDone) end
        Storage.WriteStructured(STORAGE_KEY, { text = request.data })
        BossPatch.current, BossPatch.text = patch, request.data
        finish("Applied a new patch", onDone)
        onChanged()
    end)
    return true
end

function BossPatch.Shutdown()
    local request = BossPatch.request
    BossPatch.request = nil
    if request ~= nil then pcall(function() request:Cancel() end) end
end

return BossPatch
