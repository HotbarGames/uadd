"""Which Pawn texts UADD_Pawn translates, what each template slot holds, and the review batches.
Used by tools/make_pawn_text.py (through tools/key_text.py).

Pawn is CC BY-NC-ND 3.0, which we treat as all rights reserved (CLAUDE.md "Other addons' texts"): nothing
here names its English. Every entry is keyed by its PawnLocal path ("Key", "Stats.Key", "UI.Key"); the
English is read from the installed addon. Run `python3 tools/make_pawn_text.py review` to see the texts.

Letters, one per slot:
  v  a value (a number, a colour, an icon, a version): kept as it is
  f  a free name, kept as it is: a scale name (the player's own, or Pawn's built-in one), a player or
     realm name, a command word, a key
  n  a game name (an item, a gem): UALL Forever's Ukrainian, else English: the module keeps the line English
  t  another text of ours (a PawnLocal key Pawn fills in)
A %d or %f is always v. A |cff%s slot is always v. A %s with no entry in SORTS has no sort: the build refuses
its Ukrainian until one is added. Lua's string.format has no %2$s: the Ukrainian keeps the English order.
"""
import re

import key_text as K

# Never written, with the reason (the brief, lesson 14 and Pawn's own code).
STAY_EXACT = {
    "DecimalSeparator": "Pawn parses numbers with it",
    "ThousandsSeparator": "Pawn parses numbers with it",
    "EngineeringName": "an internal name Pawn compares with",
    "TooltipParsing": "Pawn reads item tooltips with these patterns",
    "Specs": "spec names Pawn compares with the game's and changes itself (Pawn.lua)",
    # debug-only messages (/pawn debug on): read by nobody else, kept English
    "DidntUnderstandMessage": "debug only", "FoundStatMessage": "debug only",
    "ValueCalculationMessage": "debug only", "TotalValueMessage": "debug only",
    "NormalizationMessage": "debug only", "UnusableStatMessage": "debug only",
    "SocketBonusValueCalculationMessage": "debug only", "MissocketWorthwhileMessage": "debug only",
    "EnchantedStatsHeader": "debug only", "UnenchantedStatsHeader": "debug only",
}
STAY_PREFIX = ("TooltipParsing.", "Specs.", "FailedToGet")

# In our data, but never written into PawnLocal: Pawn saves them in the player's data, so only the module's
# display hooks show ours (UADD_Pawn/Swap.lua DISPLAY).
DISPLAY_ONLY = {
    "NoScale": "Pawn compares the selected scale name with it; shown by the module only on screen",
    "UI.AskMrRobotProvider": "saved as a scale's Header (Pawn.lua NewScale.Header); shown only on screen",
    "UI.StarterProvider": "saved as a scale's Header the same way; shown only on screen",
}

# PawnLocal keys that land in a field but are not saved (tools/test_pawn_text.py SavedData), with the reason.
NOT_SAVED = {
    "HiddenScalesHeader": "a header line of the scale list (ScaleData is a temporary copy)",
    "UI.CompareSocketsHeader": "a local of the Compare tab, rebuilt on each refresh",
    "UI.CompareOtherHeader": "a local of the Compare tab, rebuilt on each refresh",
    "GemListMany": "a local of the Gems tab",
}

NOTES = {
    "NoScale": "only on screen: Pawn's own copy stays English",
    "UI.AskMrRobotProvider": "only on screen: Pawn saves it in scales",
    "UI.StarterProvider": "only on screen: Pawn saves it in scales",
}
CREDITS_NOTE = "a fixed line in PawnUI.lua's code (About tab), found by its hash"

NAMES_NOTE = "an item type the game shows in tooltips: the same word as UALL Forever's tooltips (glossary)"
for _k in ("Cloth", "Leather", "Mail", "Plate", "Shield", "ArmorTypes", "WeaponTypes"):
    NOTES["Stats." + _k] = NAMES_NOTE

# A letter per slot, by key, in slot order (a %d/%f place is v whatever is written; see the letters above).
SORTS = {
    "UI.CompareHeader": "f", "UI.ValuesHeader": "f", "UI.GemsHeader": "f",  # the scale's name
    "UI.GemsColorHeader": "n",          # a gem colour, the game's own word (RED_GEM)
    "UI.AboutVersion": "v",             # Pawn's version number
    "UI.ReforgeInstructions": "nn",     # lists of the game's stat names
    "CopyScaleEnterName": "f", "RenameScaleEnterName": "f", "ExportScaleMessage": "f",  # a scale's name
    "DeleteScaleConfirmation": "ff",    # a scale's name; the word the player must type (the game's own)
    "GemList2": "nn",                   # two gem names
    "StatNameText": "n",                # a stat name, mostly the game's own (PawnStats[1])
    "TooltipBestAnnotation": "f", "TooltipBestAnnotationSimple": "f",  # the tooltip line: a scale name and
    "TooltipSecondBestAnnotation": "f", "TooltipSecondBestAnnotationSimple": "f",  # its value
    "TooltipBigUpgradeAnnotation": "fv",  # the tooltip line; "" (nothing)
    "TooltipUpgradeAnnotation": "fvv", "TooltipUpgradeNeedsEnhancementsAnnotation": "fvv",
    "TooltipDowngradeAnnotation": "fvv",
    "TooltipRelicUpgradeAnnotation": "vvv",  # ""; a number; ""
    "TooltipVersusLine": "fvn",         # the advisor's line; a quality colour; the item now worn
    "VisibleScalesHeader": "f",         # the player's name
}

# Review batches: (number, area, test(key)). The first that fits takes the key.
BATCHES = [
    (1, "the Pawn window: scales, values, compare, gems",
     lambda k: k.startswith("UI.") and re.match(r"UI\.(Scale|Values|Compare|Gems|Tab|Header|Rename|Copy|New|"
                                                r"Delete|Import|Export|Auto|Weights|Normal)", k) is not None),
    (2, "the Pawn window: options, about, help, key bindings, other UI", lambda k: k.startswith("UI.")),
    (3, "stat names and their help", lambda k: k.startswith("Stats.")),
    (4, "tooltips, chat messages, code lines", lambda k: True),
]


def batch_of(key):
    return next(b for b, _, test in BATCHES if test(key))


def stay(key):
    return key in STAY_EXACT or key.startswith(STAY_PREFIX)


def keep(key, en):
    """(kept, reason left out)."""
    if stay(key):
        return False, "stay"
    if not en.strip():
        return False, "empty"
    if not K.LATIN_WORD.search(K.SPECIAL.sub("", en)):
        return False, "no words"
    return True, ""


def sorts(key, en):
    return K.sorts_from(SORTS, key, en)


COLON_SLOT = re.compile(r":\s+(?=%|\|c)")


def check(key, en, ua):
    """What makes `ua` unfit as the Ukrainian of `en`."""
    problems = K.base_check(en, ua, sorts(key, en))
    if stay(key):
        problems.append("a STAY key (never written)")
    # Tooltip lines: ": " before the value stays, and a leading colour code stays first.
    if len(COLON_SLOT.findall(en)) != len(COLON_SLOT.findall(ua)):
        problems.append('": " before a value is gone or added (tooltip value lines keep it)')
    m = re.match(r"\|c[0-9a-fA-F]{8}", en)
    if m and not ua.startswith(m.group(0)):
        problems.append("the colour code at the start moved")
    return problems
