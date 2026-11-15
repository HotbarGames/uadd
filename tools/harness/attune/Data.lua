-- Not Attune: a few rows of Attune's tables in its own shapes (AttuneData.lua, AttuneQuestGivers.lua),
-- English from AttuneLang like the real ones: three attunements, their steps, two NPCs, two givers.
local L = AttuneLang
Attune_Data = {}

Attune_Data.attunes = {
    { ID = "20", NAME = L["Molten Core"], SHORT = "MC", EXPAC = L["World of Warcraft"], GROUP = L['RAIDS'],
        FACTION = "Both", ICON = "Interface\\Icons\\spell_fire_lavaspawn", DESC = L["MC_Desc"], GROUPSIZE = 40 },
    { ID = "30", NAME = L["Onyxia's Lair"], SHORT = "Ony", EXPAC = L["World of Warcraft"], GROUP = L['RAIDS'],
        FACTION = "Horde", ICON = "Interface\\Icons\\inv_misc_head_dragon_01", DESC = L["Ony_Desc"], GROUPSIZE = 40 },
    { ID = "160", NAME = L["Ragefire Chasm"], SHORT = "RFC", EXPAC = L["World of Warcraft"], GROUP = L['DUNGEONS'],
        FACTION = "Horde", ICON = "Interface\\Icons\\spell_fire_fire", DESC = L["DungeonQuest_Desc"], GROUPSIZE = 5,
        LEVELS = "13-16" },
}

Attune_Data.steps = {
    { ID_ATTUNE = "20", ID = "20", TYPE = "Level", STEP = L["Reach level"] .. " 55", LOCATION = "", ID_WOWHEAD = "55",
        FOLLOWS = "0", STAGE = "1" },
    { ID_ATTUNE = "20", ID = "30", TYPE = "Pick Up", STEP = "", LOCATION = L["Blackrock Mountain"], ID_WOWHEAD = "7848",
        FOLLOWS = "20", STAGE = "2" },
    { ID_ATTUNE = "20", ID = "40", TYPE = "Item", STEP = "", LOCATION = L["Blackrock Depths"], ID_WOWHEAD = "18412", COUNT = "2",
        FOLLOWS = "30", STAGE = "3" },
    { ID_ATTUNE = "20", ID = "45", TYPE = "Turn In", STEP = "", LOCATION = L["Blackrock Mountain"], ID_WOWHEAD = "7848",
        FOLLOWS = "40", STAGE = "4" },
    { ID_ATTUNE = "20", ID = "50", TYPE = "End", STEP = "Attuned", LOCATION = "", ID_WOWHEAD = "0", FOLLOWS = "45",
        STAGE = "5" },
    { ID_ATTUNE = "30", ID = "20", TYPE = "Pick Up", STEP = "", LOCATION = L["Badlands"], ID_WOWHEAD = "4903",
        FOLLOWS = "0", STAGE = "1" },
    { ID_ATTUNE = "30", ID = "30", TYPE = "Kill", STEP = "", LOCATION = L["Lower Blackrock Spire"], ID_WOWHEAD = "9196",
        FOLLOWS = "20", STAGE = "2" },
    { ID_ATTUNE = "30", ID = "115", TYPE = "Interact", STEP = "", LOCATION = L["Desolace"], ID_WOWHEAD = "10182",
        FOLLOWS = "30", STAGE = "3" },
    { ID_ATTUNE = "160", ID = "20", TYPE = "Pick Up", STEP = "", LOCATION = L["Orgrimmar"], ID_WOWHEAD = "4903",
        FOLLOWS = "0", STAGE = "1" },
}

Attune_Data.quests = { [7848] = { 55, 5 }, [4903] = { 55, 1 } }    -- level, group size
Attune_Data.npcs = { [9196] = { "59", L["Elite"], L["Ogre"] }, [10182] = { "??", L["Elite"], L["Half-Orc"] } }
Attune_Data.questGivers = { [7848] = { 1428, 26.4, 24.6, "Lothos Riftwaker" },
    [4903] = { 1418, 5.8, 47.4, "Warlord Goretooth" } }
