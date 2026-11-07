-- Define feature pages and loading dependencies
local ordered = {
    (require("Resources/Features/bosses/boss_feature")),
    (require("Resources/Features/experience/experience_feature")),
    (require("Resources/Features/quests/quest_feature")),
    (require("Resources/Features/achievements/achievements_feature")),
    (require("Resources/Features/archaeology/archaeology_feature")),
    (require("Resources/Features/clues/clue_feature")),
    (require("Resources/Features/misc/misc_feature")),
}
local hidden = {
    (require("Resources/Features/bosses/abilities/abilities_feature")),
    (require("Resources/Features/misc/thieving/thieving_feature")),
    (require("Resources/Features/slayer/slayer_feature")),
    (require("Resources/Features/misc/player_owned_farms/farm_feature")),
    (require("Resources/Features/misc/minigames/minigames_feature")),
    (require("Resources/Features/misc/skilling_outfits/skilling_outfits_feature")),
    (require("Resources/Features/misc/pets/pets_feature")),
    (require("Resources/Features/misc/enchantments/enchantments_feature")),
}
local byID = {}
local function register(feature)
    byID[feature.id] = feature
    for _, provider in ipairs(feature.providers or {}) do
        byID[provider.id] = provider
    end
end
for _, feature in ipairs(ordered) do
    register(feature)
end
for _, feature in ipairs(hidden) do
    register(feature)
end
return { ordered = ordered, byID = byID }
