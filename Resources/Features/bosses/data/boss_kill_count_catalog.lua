-- Group and completion metrics: label, variable
local groups = {
    {"Amascut",{{"NM","BSLAY_KILLS_AMASCUT_BOSS"},{"HM","BSLAY_KILLS_AMASCUT_BOSS_HARDMODE"}}},
    {"Araxxi",{{"KC","BSLAY_KILLS_ARAXXI"}}},
    {"Arch-Glacor",{{"NM","BSLAY_KILLS_EGWD_WEN_BOSS"},{"HM","BSLAY_KILLS_EGWD_WEN_BOSS_HARDMODE"}}},
    {"The Barrows Brothers",{{"KC","BSLAY_KILLS_BARROWS"}}},
    {"The Barrows: Rise of the Six",{{"KC","BSLAY_KILLS_BARROWSROTS"}}},
    {"Chaos Elemental",{{"KC","BSLAY_KILLS_CHAOSELEMENTAL"}}},
    {"Commander Zilyana",{{"NM","BSLAY_KILLS_GWD_ZILYANA"},{"HM","BSLAY_KILLS_GWD_ZILYANA_HARDMODE"}}},
    {"Corporeal Beast",{{"KC","BSLAY_KILLS_CORPBEAST"}}},
    {"Croesus",{{"KC","BSLAY_KILLS_EGWD_BIK_BOSS"}}},
    {"Dagannoth Kings",{{"KC","BSLAY_KILLS_DAGANNOTHKINGS"}}},
    {"Dragonkin Laboratory",{{"Total","BSLAY_KILLS_DUNGEON_DRAGONFORT3"},{"Solo","BSLAY_KILLS_DUNGEON_DRAGONFORT3_SOLO"}}},
    {"Flesh-hatcher Mhekarnahz",{{"KC","BSLAY_KILLS_STALKER_BOSS"}}},
    {"The Gate of Elidinis",{{"KC","BSLAY_KILLS_ELIDINIS_BOSS"}}},
    {"General Graardor",{{"NM","BSLAY_KILLS_GWD_GRAARDOR"},{"HM","BSLAY_KILLS_GWD_GRAARDOR_HARDMODE"}}},
    {"Ghrazi Blood Knights",{{"NM","BSLAY_KILLS_BLOOD_KNIGHT_BOSS"},{"Enrage","BSLAY_KILLS_BLOOD_KNIGHT_BOSS_HARDMODE"}}},
    {"Giant Mole",{{"NM","BSLAY_KILLS_GIANTMOLE"},{"HM","BSLAY_KILLS_GIANTMOLE_HARDMODE"}}},
    {"Gregorovic",{{"NM","BSLAY_KILLS_SLISKE"},{"HM","BSLAY_KILLS_SLISKE_HARDMODE"}}},
    {"Helwyr",{{"NM","BSLAY_KILLS_HELWYR"},{"HM","BSLAY_KILLS_HELWYR_HARDMODE"}}},
    {"Hermod",{{"KC","BSLAY_KILLS_HERMOD_BOSS"}}},
    {"Ivar",{{"KC","BSLAY_KILLS_WENDLE_GIANT_BOSS"}}},
    {"Kalphite King",{{"KC","BSLAY_KILLS_KALPHITEKING"}}},
    {"Kalphite Queen",{{"KC","BSLAY_KILLS_KALPHITEQUEEN"}}},
    {"Kerapac",{{"NM","BSLAY_KILLS_EGWD_JAS_BOSS"},{"HM","BSLAY_KILLS_EGWD_JAS_BOSS_HARDMODE"}}},
    {"King Black Dragon",{{"KC","BSLAY_KILLS_KINGBLACKDRAGON"}}},
    {"Kree'arra",{{"NM","BSLAY_KILLS_GWD_KREEARRA"},{"HM","BSLAY_KILLS_GWD_KREEARRA_HARDMODE"}}},
    {"K'ril Tsutsaroth",{{"NM","BSLAY_KILLS_GWD_KRIL"},{"HM","BSLAY_KILLS_GWD_KRIL_HARDMODE"}}},
    {"Legiones",{{"KC","BSLAY_KILLS_LEGIONES"}}},
    {"Liberation of Mazcab",{{"Durzag","BSLAY_KILLS_BEASTMASTER"},{"Yaka","BSLAY_KILLS_YAKAMARU"}}},
    {"The Magister",{{"KC","BSLAY_KILLS_MENAPHOS_SLAYER_BOSS"}}},
    {"Nex",{{"KC","BSLAY_KILLS_GWD_NEX"}}},
    {"Nex, Angel of Death",{{"KC","BSLAY_KILLS_NEX2"}}},
    {"Queen Black Dragon",{{"KC","BSLAY_KILLS_QUEENBLACKDRAGON"}}},
    {"Raksha",{{"Solo","BSLAY_KILLS_DINO_BOSS_SOLO"},{"Duo","BSLAY_KILLS_DINO_BOSS_DUO"}}},
    {"Rasial",{{"KC","BSLAY_KILLS_RASIAL_BOSS"}}},
    {"Rex Matriarchs",{{"KC","BSLAY_KILLS_REXKINGS"}}},
    {"Sanctum of Rebirth",{{"NM","BSLAY_KILLS_RAID_REBIRTH1_SLAYER_MASTER_BOSS"},{"HM","BSLAY_KILLS_RAID_REBIRTH1_SLAYER_MASTER_BOSS_HARDMODE"}}},
    {"The Shadow Reef",{{"Total","BSLAY_KILLS_DUNGEON_ULTHVEN3"},{"Solo","BSLAY_KILLS_DUNGEON_ULTHVEN3_SOLO"}}},
    {"Silverquill",{{"KC","BSLAY_KILLS_WENDLE_HEDGEHOG_BOSS"}}},
    {"Solak",{{"KC","BSLAY_KILLS_SOLAK"}}},
    {"Telos",{{"KC","BSLAY_KILLS_GWD2_SOLO_BOSS"}}},
    {"Temple of Aminishi",{{"Total","BSLAY_KILLS_DUNGEON_AMINISHI3"},{"Solo","BSLAY_KILLS_DUNGEON_AMINISHI3_SOLO"}}},
    {"The Twin Furies",{{"NM","BSLAY_KILLS_TWINDEMONS"},{"HM","BSLAY_KILLS_TWINDEMONS_HARDMODE"}}},
    {"TzKal-Zuk",{{"NM","BSLAY_KILLS_EGWD_FUL_BOSS"},{"HM","BSLAY_KILLS_EGWD_FUL_BOSS_HARDMODE"}}},
    {"TzTok-Jad and Har-Aken",{{"Jad","BSLAY_KILLS_JAD"},{"Har-Aken","BSLAY_KILLS_HARAKEN"}}},
    {"Vindicta & Gorvek",{{"NM","BSLAY_KILLS_VINDICTA"},{"HM","BSLAY_KILLS_VINDICTA_HARDMODE"}}},
    {"Vorago",{{"NM","BSLAY_KILLS_VORAGO"},{"HM","BSLAY_KILLS_VORAGO_HARDMODE"}}},
    {"Zamorak",{{"Total","BSLAY_KILLS_EGWD_ZAMORAK_BOSS"},{"Solo","BSLAY_KILLS_EGWD_ZAMORAK_BOSS_SOLO"}}},
    {"Zemouregal & Vorkath",{{"NM","BSLAY_KILLS_FORT_BOSS_ZEMO_VORKATH"},{"HM","BSLAY_KILLS_FORT_BOSS_ZEMO_VORKATH_HARD"}}},
}

-- Expand label/variable rows, keeping groups already present
local function Expand(rows, killCounts)
    killCounts = killCounts or {}
    for _, group in ipairs(rows) do
        if killCounts[group[1]] == nil then
            local metrics = {}
            for _, metric in ipairs(group[2]) do
                metrics[#metrics + 1] = { label = metric[1], variable = metric[2] }
            end
            killCounts[group[1]] = metrics
        end
    end
    return killCounts
end
return { groups = groups, Expand = Expand }
