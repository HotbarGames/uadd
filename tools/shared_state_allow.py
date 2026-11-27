"""ALLOW for tools/test_shared_state.py: (file, kind) -> (how many, why), each risky call outside the core helpers.

More uses than the number fails (a new one: use a helper), fewer fails too (lower the number). "TODO: move to
helper" marks old uses that should go through a core helper.
"""

FONT_FIX = "module font helper: Cyrillic file on one FontString, back with its font object"
TODO = "TODO: move to helper (U.SaveFont / U.FontBack in UADD/Font.lua)"; CYRON = "CyrOn: after U.SaveFont, read back; U.FontBack"
OWN_FONT = "our own named font object (UADD_...), a copy with the Cyrillic file"
SWAP = "the addon's global strings (key binding names), swapped both ways on on/off"
PROBE = "the font probe (lesson 44): only FontStrings of its own hidden frame and its own UADD_ProbeFont"
ALLOW = {
    ("UADD/Probe.lua", "set font"): (2, PROBE), ("UADD/Probe.lua", "new font"): (1, PROBE),
    ("UADD/Core.lua", "global write"): (1, "SLASH_UADD1: the /uadd command"),
    ("UADD/Core.lua", "game field"): (1, "SlashCmdList.UADD: the /uadd command"),
    ("UADD_Auctionator/Fonts.lua", "set font"): (3, FONT_FIX),
    ("UADD_AutoPotion/Bindings.lua", "global write"): (2, SWAP), ("UADD_Bagnon/Locale.lua", "global write"): (1, SWAP),
    ("UADD_LiteMount/Tables.lua", "global write"): (2, SWAP),
    ("UADD_DialogueUI/Fonts.lua", "set font"): (3, FONT_FIX + "; " + TODO),
    ("UADD_DungeonJournal/Fonts.lua", "set font"): (2, FONT_FIX + "; " + TODO),
    ("UADD_DungeonJournal/Fonts.lua", "new font"): (1, OWN_FONT),
    ("UADD_ForeverXPBar/Fonts.lua", "set font"): (3, FONT_FIX),
    ("UADD_GatherMate2/Swap.lua", "global write"): (2, SWAP),
    ("UADD_Pawn/Swap.lua", "global write"): (2, SWAP),
    ("UADD_Questie/HeaderFont.lua", "new font"): (1, OWN_FONT),
    ("UADD_Questie/HeaderFont.lua", "set font"): (1, "our own font object UADD_QuestieHeaderFont"),
    ("UADD_Questie/HeaderFont.lua", "put object"): (1, "our own font object UADD_QuestieHeaderFont on its header"),
    ("UADD_DungeonJournal/Language.lua", "put object"): (1, "our own named copy (ns.Fonts.FontFor), else "
                                                            "GameFontHighlight"),
    ("UADD/Probe.lua", "put object"): (1, PROBE),
    ("UADD_Questie/Locale.lua", "global write"): (1, "QUESTIE_LOCALES_OVERRIDE: Questie's own documented locale switch"),
    ("UADD_WaypointUI/Fonts.lua", "set font"): (1, "Cyrillic file on Waypoint UI's own font objects after "
                                                   "U.SaveFont, read back; back with U.FontBack"),
    ("UADD_Mastercraft/Kept.lua", "set font"): (1, "Mastercraft's own SetFont wrapper on its own label, to give "
                                                   "its own file back; read back, else its raw setter"),
    ("UADD_Scrap/Swap.lua", "global write"): (2, SWAP), ("UADD_WhatTheWhisper/Swap.lua", "global write"): (1, SWAP),
    ("UADD_WowheadQuickLink/Module.lua", "global write"): (1, SWAP),
    ("UADD/Lines.lua", "chat replace"): (2, "core chat bus (U.ChatHook): one wrap for all modules, lesson 35"),
}
WALK_TODO = "a frame walk with no IsForbidden test; TODO: use U.Regions / U.Children (UADD/Guard.lua)"
for _f, _n in {"Attune/Claim": 4, "Attune/Screen": 6, "Auctionator/Menu": 2, "Auctionator/Rows": 1,
               "Auctionator/Screen": 2, "AutoPotion/Screen": 2, "Bagnon/Fonts": 2, "DialogueUI/Screen": 3,
               "DungeonJournal/Language": 2, "DungeonJournal/Map": 1, "DungeonJournal/Screen": 2,
               "DungeonJournal/Search": 1, "ForeverXPBar/Screen": 2, "GatherMate2/Fonts": 2, "LayerSwap/Screen": 2,
               "OpenMap/Screen": 3, "Pawn/Fonts": 2, "Pawn/Swap": 2,
               "Questie/ControlFont": 2, "Questie/HeaderFont": 2, "RareScanner/Fonts": 2, "Scrap/Fonts": 2,
               "SpeedyAutoLoot/Module": 2, "TomTom/Fonts": 2}.items():
    ALLOW[(f"UADD_{_f}.lua", "walk")] = (_n, WALK_TODO)
