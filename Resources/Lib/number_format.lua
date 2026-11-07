-- Format numbers for display
local NumberFormat = {}

-- Format an integer with thousands separators
function NumberFormat.Integer(value)
    local number = math.floor(tonumber(value) or 0)
    local sign = number < 0 and "-" or ""
    local digits = tostring(math.abs(number))
    while true do
        local replaced, count = string.gsub(digits, "^(%d+)(%d%d%d)", "%1,%2")
        digits = replaced
        if count == 0 then return sign .. digits end
    end
end

return NumberFormat
