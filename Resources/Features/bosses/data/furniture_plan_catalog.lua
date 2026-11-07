-- Furniture plan objects and their matching unlock variables.
local entries = {}
for _, kind in ipairs({ "RUG", "ALTAR" }) do
    for _, god in ipairs({ "ARMADYL", "BANDOS", "SARADOMIN", "SEREN", "ZAMORAK", "ZAROS" }) do
        local objectConfig = "CONSTRUCTION_HOUSE_FURNITURE_" .. kind .. "_" .. god .. "_RECIPE"
        entries[#entries + 1] = { objectConfig = objectConfig, v = objectConfig .. "_UNLOCKED" }
    end
end
return entries
