-- Decode JSON text; the client provides no parser
local Json = {}

local ESCAPES = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
local LITERALS = { ["true"] = true, ["false"] = false }

local decodeValue

local function skip(text, index) return string.find(text, "[^ \t\r\n]", index) or #text + 1 end

local function decodeString(text, index)
    local parts = {}
    local position = index + 1
    while true do
        local stop, _, character = string.find(text, '(["\\])', position)
        if stop == nil then error("unterminated string") end
        parts[#parts + 1] = string.sub(text, position, stop - 1)
        if character == '"' then return table.concat(parts), stop + 1 end
        local escape = string.sub(text, stop + 1, stop + 1)
        if escape == "u" then
            local code = tonumber(string.sub(text, stop + 2, stop + 5), 16)
            if code == nil then error("invalid unicode escape") end
            parts[#parts + 1] = utf8.char(code)
            position = stop + 6
        else
            parts[#parts + 1] = ESCAPES[escape] or escape
            position = stop + 2
        end
    end
end

local function decodeList(text, index, closing, readEntry)
    local result = {}
    index = skip(text, index + 1)
    if string.sub(text, index, index) == closing then return result, index + 1 end
    while true do
        index = skip(text, readEntry(result, index))
        local separator = string.sub(text, index, index)
        if separator == closing then return result, index + 1 end
        if separator ~= "," then error("expected ',' or '" .. closing .. "'") end
        index = skip(text, index + 1)
    end
end

function decodeValue(text, index)
    index = skip(text, index)
    local first = string.sub(text, index, index)
    if first == "{" then
        return decodeList(text, index, "}", function(result, position)
            if string.sub(text, position, position) ~= '"' then error("expected key") end
            local key, after = decodeString(text, position)
            after = skip(text, after)
            if string.sub(text, after, after) ~= ":" then error("expected ':'") end
            local value
            value, after = decodeValue(text, after + 1)
            result[key] = value
            return after
        end)
    elseif first == "[" then
        return decodeList(text, index, "]", function(result, position)
            local value, after = decodeValue(text, position)
            result[#result + 1] = value
            return after
        end)
    elseif first == '"' then
        return decodeString(text, index)
    end
    local word = string.match(text, "^%a+", index)
    if word == "null" then return nil, index + 4 end
    if LITERALS[word] ~= nil then return LITERALS[word], index + #word end
    local number = string.match(text, "^-?%d+%.?%d*[eE]?[-+]?%d*", index)
    if number == nil or tonumber(number) == nil then error("unexpected character at " .. index) end
    return tonumber(number), index + #number
end

-- Return the decoded value, or nil and an error message
function Json.Decode(text)
    if type(text) ~= "string" then return nil, "expected text" end
    local ok, value, index = pcall(decodeValue, text, 1)
    if not ok then return nil, tostring(value) end
    if skip(text, index) <= #text then return nil, "trailing characters" end
    return value
end

return Json
