-- Heist rewards and completion metrics belong to Misc > Thieving.
local groups = {
    {
        name = "Asuran Arsenal",
        objects = { 59925, 59921 },
        completions = "HEIST_DRAGONKIN_COMPLETIONS",
        minutes = "HEIST_DRAGONKIN_FASTEST_COMPLETION_TIME_MINUTES",
        seconds = "HEIST_DRAGONKIN_FASTEST_COMPLETION_TIME_SECONDS",
    },
    {
        name = "Vault of Hereditas",
        objects = { 59943, 59917, 59932 },
        completions = "HEIST_KHARIDET_COMPLETIONS",
        minutes = "HEIST_KHARIDET_FASTEST_COMPLETION_TIME_MINUTES",
        seconds = "HEIST_KHARIDET_FASTEST_COMPLETION_TIME_SECONDS",
    },
}
local byName = {}
for _, group in ipairs(groups) do
    byName[group.name] = group
end
return { groups = groups, byName = byName }
