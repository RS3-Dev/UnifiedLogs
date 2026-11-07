-- Define skill metadata
local SkillCatalog = {}

SkillCatalog.ordered = {
    { id = 0, name = "Attack", colour = 0xB85445FF },
    { id = 2, name = "Strength", colour = 0x6E9B4BFF },
    { id = 1, name = "Defence", colour = 0x6D87A0FF },
    { id = 4, name = "Ranged", colour = 0x8C8F48FF },
    { id = 5, name = "Prayer", colour = 0xD2C89DFF },
    { id = 6, name = "Magic", colour = 0x5A77BDFF },
    { id = 3, name = "Constitution", colour = 0xB8616AFF },
    { id = 16, name = "Agility", colour = 0x688F78FF },
    { id = 15, name = "Herblore", colour = 0x798C52FF },
    { id = 17, name = "Thieving", colour = 0x7E6B86FF },
    { id = 12, name = "Crafting", colour = 0xA97957FF },
    { id = 9, name = "Fletching", colour = 0x6F8D68FF },
    { id = 14, name = "Mining", colour = 0x8A7763FF },
    { id = 13, name = "Smithing", colour = 0x787D82FF },
    { id = 10, name = "Fishing", colour = 0x527F91FF },
    { id = 7, name = "Cooking", colour = 0xA65E43FF },
    { id = 8, name = "Woodcutting", colour = 0x55764CFF },
    { id = 11, name = "Firemaking", colour = 0xC26D3DFF },
    { id = 18, name = "Slayer", colour = 0x775B87FF },
    { id = 19, name = "Farming", colour = 0x64854CFF },
    { id = 20, name = "Runecrafting", colour = 0x71658EFF },
    { id = 21, name = "Hunter", colour = 0x806F55FF },
    { id = 22, name = "Construction", colour = 0xA46E51FF },
    { id = 23, name = "Summoning", colour = 0x6F7799FF },
    { id = 24, name = "Dungeoneering", colour = 0x8E7257FF },
    { id = 25, name = "Divination", colour = 0x7465A0FF },
    { id = 26, name = "Invention", colour = 0xA79054FF },
    { id = 27, name = "Archaeology", colour = 0xB37A45FF },
    { id = 28, name = "Necromancy", colour = 0x718978FF },
}

SkillCatalog.byID = {}
for _, skill in ipairs(SkillCatalog.ordered) do SkillCatalog.byID[skill.id] = skill end

return SkillCatalog
