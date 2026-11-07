-- Group and encounter metric records
local groups = {
    {"Ghrazi Blood Knights",{{"Ghrazi Blood Knights",{{"Normal mode","BOSS_INSTANCE_SCORES_BLOOD_KNIGHT_BOSS","ticks"},{"Enrage mode","BOSS_INSTANCE_SCORES_BLOOD_KNIGHT_BOSS_HARD","ticks"}}}}},
    {"Amascut",{{"Amascut",{{"Normal mode","BOSS_INSTANCE_SCORES_AMASCUT_BOSS","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_AMASCUT_BOSS_HARD","ticks"}}}}},
    {"Araxxi",{{"Araxxi",{{"Fastest kill","BOSS_INSTANCE_SCORES_ARAXXI","ticks"}}}}},
    {"Arch-Glacor",{{"Arch-Glacor",{{"Normal mode","BOSS_INSTANCE_SCORES_EGWD_WEN_BOSS","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_EGWD_WEN_BOSS_HARD","ticks"}}}}},
    {"The Barrows: Rise of the Six",{{"The Barrows: Rise of the Six",{{"Fastest kill","BOSS_INSTANCE_SCORES_ROTS","ticks"}}}}},
    {"Commander Zilyana",{{"Commander Zilyana",{{"Normal mode","BOSS_INSTANCE_SCORES_ZILYANA","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_ZILYANA_HARD","ticks"}}}}},
    {"Corporeal Beast",{{"Corporeal Beast",{{"Fastest kill","BOSS_INSTANCE_SCORES_CORP_BEAST","ticks"}}}}},
    {"Croesus",{{"Croesus",{{"Fastest kill","BOSS_INSTANCE_SCORES_EGWD_BIK_BOSS","ticks"}}}}},
    {"Dragonkin Laboratory",{{"Astellarn",{{"Group","BOSS_INSTANCE_SCORES_DRAGONFORT1","ticks"},{"Solo","BOSS_INSTANCE_SCORES_DRAGONFORT1_HARD","ticks"}}},{"Verak Lith",{{"Group","BOSS_INSTANCE_SCORES_DRAGONFORT2","ticks"},{"Solo","BOSS_INSTANCE_SCORES_DRAGONFORT2_HARD","ticks"}}},{"The Black Stone Dragon",{{"Group","BOSS_INSTANCE_SCORES_DRAGONFORT3","ticks"},{"Solo","BOSS_INSTANCE_SCORES_DRAGONFORT3_HARD","ticks"}}}}},
    {"The Gate of Elidinis",{{"The Gate of Elidinis",{{"Fastest kill","BOSS_INSTANCE_SCORES_ELIDINIS_BOSS","ticks"}}}}},
    {"General Graardor",{{"General Graardor",{{"Normal mode","BOSS_INSTANCE_SCORES_GRAARDOR","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_GRAARDOR_HARD","ticks"}}}}},
    {"Giant Mole",{{"Giant Mole",{{"Normal mode","BOSS_INSTANCE_SCORES_MOLE","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_MOLE_HARD","ticks"}}}}},
    {"Gregorovic",{{"Gregorovic",{{"Normal mode","BOSS_INSTANCE_SCORES_SLISKE","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_SLISKE_HARD","ticks"}}}}},
    {"Helwyr",{{"Helwyr",{{"Normal mode","BOSS_INSTANCE_SCORES_HELWYR","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_HELWYR_HARD","ticks"}}}}},
    {"Hermod",{{"Hermod",{{"Fastest kill","BOSS_INSTANCE_SCORES_HERMOD_BOSS","ticks"}}}}},
    {"Ivar",{{"Ivar",{{"Fastest kill","BOSS_INSTANCE_SCORES_WENDLE_GIANT_BOSS","ticks"}}}}},
    {"Kalphite King",{{"Kalphite King",{{"Fastest kill","BOSS_INSTANCE_SCORES_KK","ticks"}}}}},
    {"Kalphite Queen",{{"Kalphite Queen",{{"Fastest kill","BOSS_INSTANCE_SCORES_KQ","ticks"}}}}},
    {"Kerapac",{{"Kerapac",{{"Normal mode","BOSS_INSTANCE_SCORES_EGWD_JAS_BOSS","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_EGWD_JAS_BOSS_HARD","ticks"}}}}},
    {"King Black Dragon",{{"King Black Dragon",{{"Fastest kill","BOSS_INSTANCE_SCORES_KBD","ticks"}}}}},
    {"Kree'arra",{{"Kree'arra",{{"Normal mode","BOSS_INSTANCE_SCORES_KREEARRA","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_KREEARRA_HARD","ticks"}}}}},
    {"K'ril Tsutsaroth",{{"K'ril Tsutsaroth",{{"Normal mode","BOSS_INSTANCE_SCORES_KRIL","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_KRIL_HARD","ticks"}}}}},
    {"Legiones",{{"Legiones",{{"Fastest kill","BOSS_INSTANCE_SCORES_LEGIONES","ticks"}}}}},
    {"Liberation of Mazcab",{{"Beastmaster Durzag",{{"Fastest kill","BOSS_INSTANCE_SCORES_BEASTMASTER","ticks"}}},{"Yakamaru",{{"Fastest kill","BOSS_INSTANCE_SCORES_YAKAMARU","ticks"}}}}},
    {"Nex",{{"Nex",{{"Fastest kill","BOSS_INSTANCE_SCORES_NEX","ticks"}}}}},
    {"Nex, Angel of Death",{{"Nex, Angel of Death",{{"Fastest kill","BOSS_INSTANCE_SCORES_NEX2","ticks"}}}}},
    {"The Magister",{{"The Magister",{{"Fastest kill","BOSS_INSTANCE_SCORES_MENAPHOS_SLAYER_BOSS","ticks"}}}}},
    {"Queen Black Dragon",{{"Queen Black Dragon",{{"Fastest kill","BOSS_INSTANCE_SCORES_QBD","ticks"}}}}},
    {"Raksha",{{"Raksha",{{"Solo","BOSS_INSTANCE_SCORES_DINO_BOSS_SOLO","ticks"},{"Duo","BOSS_INSTANCE_SCORES_DINO_BOSS_DUO","ticks"}}}}},
    {"Rasial",{{"Rasial",{{"Fastest kill","BOSS_INSTANCE_SCORES_RASIAL_BOSS","ticks"}}}}},
    {"Sanctum of Rebirth",{{"Vermyx, Brood Mother",{{"Normal mode","BOSS_INSTANCE_SCORES_RAID_REBIRTH1_WYRM_BOSS","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_RAID_REBIRTH1_WYRM_BOSS_HARD","ticks"}}},{"Kezalam, the Wanderer",{{"Normal mode","BOSS_INSTANCE_SCORES_RAID_REBIRTH1_BEAST_BOSS","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_RAID_REBIRTH1_BEAST_BOSS_HARD","ticks"}}},{"Nakatra, Devourer Eternal",{{"Normal mode","BOSS_INSTANCE_SCORES_RAID_REBIRTH1_SLAYER_MASTER_BOSS","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_RAID_REBIRTH1_SLAYER_MASTER_BOSS_HARD","ticks"}}}}},
    {"The Shadow Reef",{{"The Crassian Leviathan",{{"Group","BOSS_INSTANCE_SCORES_ULTHVEN1","ticks"},{"Solo","BOSS_INSTANCE_SCORES_ULTHVEN1_HARD","ticks"}}},{"Taraket the Necromancer",{{"Group","BOSS_INSTANCE_SCORES_ULTHVEN2","ticks"},{"Solo","BOSS_INSTANCE_SCORES_ULTHVEN2_HARD","ticks"}}},{"The Ambassador",{{"Group","BOSS_INSTANCE_SCORES_ULTHVEN3","ticks"},{"Solo","BOSS_INSTANCE_SCORES_ULTHVEN3_HARD","ticks"}}}}},
    {"Solak",{{"Solak",{{"Solo","BOSS_INSTANCE_SCORES_SOLAK","ticks"},{"Duo","BOSS_INSTANCE_SCORES_SOLAK_DUO","ticks"}}}}},
    {"Telos",{{"Telos",{{"Fastest kill","BOSS_INSTANCE_SCORES_TELOS","ticks"}}}}},
    {"Temple of Aminishi",{{"The Sanctum Guardian",{{"Group","BOSS_INSTANCE_SCORES_AMINISHI1","ticks"},{"Solo","BOSS_INSTANCE_SCORES_AMINISHI1_HARD","ticks"}}},{"Masuta the Ascended",{{"Group","BOSS_INSTANCE_SCORES_AMINISHI2","ticks"},{"Solo","BOSS_INSTANCE_SCORES_AMINISHI2_HARD","ticks"}}},{"Seiryu the Azure Serpent",{{"Group","BOSS_INSTANCE_SCORES_AMINISHI3","ticks"},{"Solo","BOSS_INSTANCE_SCORES_AMINISHI3_HARD","ticks"}}}}},
    {"The Twin Furies",{{"The Twin Furies",{{"Normal mode","BOSS_INSTANCE_SCORES_TWINDEMONS","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_TWINDEMONS_HARD","ticks"}}}}},
    {"TzKal-Zuk",{{"TzKal-Zuk",{{"Normal mode","BOSS_INSTANCE_SCORES_EGWD_FUL_BOSS","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_EGWD_FUL_BOSS_HARD","ticks"}}}}},
    {"TzTok-Jad and Har-Aken",{{"TzTok-Jad",{{"Fastest kill","BOSS_INSTANCE_SCORES_JAD","ticks"}}},{"Har-Aken",{{"Fastest kill","BOSS_INSTANCE_SCORES_HARAKEN","ticks"}}}}},
    {"Vindicta & Gorvek",{{"Vindicta & Gorvek",{{"Normal mode","BOSS_INSTANCE_SCORES_VINDICTA","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_VINDICTA_HARD","ticks"}}}}},
    {"Vorago",{{"Vorago",{{"Normal mode","BOSS_INSTANCE_SCORES_VORAGO","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_VORAGO_HARD","ticks"}}}}},
    {"Zamorak",{{"Zamorak",{{"Normal mode","BOSS_INSTANCE_SCORES_EGWD_ZAMORAK_BOSS","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_EGWD_ZAMORAK_BOSS_HARD","ticks"}}}}},
    {"Zemouregal & Vorkath",{{"Zemouregal & Vorkath",{{"Normal mode","BOSS_INSTANCE_SCORES_FORT_BOSS_ZEMO_VORKATH","ticks"},{"Hard mode","BOSS_INSTANCE_SCORES_FORT_BOSS_ZEMO_VORKATH_HARD","ticks"}}}}},
}

-- Expand encounter rows, keeping groups already present
local function Expand(rows, records)
    records = records or {}
    for _, group in ipairs(rows) do
        if records[group[1]] == nil then
            local bosses = {}
            for _, tuple in ipairs(group[2]) do
                local metrics = {}
                for _, metric in ipairs(tuple[2]) do
                    metrics[#metrics + 1] = {
                        label = metric[1],
                        variable = metric[2],
                        kind = metric[3],
                        secondaryVariable = metric[4],
                    }
                end
                bosses[#bosses + 1] = { name = tuple[1], metrics = metrics }
            end
            records[group[1]] = bosses
        end
    end
    return records
end
return { groups = groups, Expand = Expand, tickSeconds = 0.6 }
