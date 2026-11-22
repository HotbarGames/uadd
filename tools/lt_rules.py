"""Which LootTriage texts UADD_LootTriage translates, what each template slot holds, and the review batches.
Used by tools/make_lt_text.py (through tools/key_text.py) and tools/lt_source.py.

LootTriage has no licence (all rights reserved; CLAUDE.md "Other addons' texts"): nothing here names its English.
It has no locale table, so every row is keyed Code.<hash>: UADD.Hash of one string literal of its code (escapes
decoded). Run `python3 tools/make_lt_text.py review` to see the texts.

Letters, one per slot (key_text.py): v a value, f a free name kept as it is, n a game name (the line stays
English), t another text of ours.
"""
import re

import key_text as K

# Literals its code uses but never shows, by hash (left out of the review): code values it returns or passes on,
# and names kept as they are.
CODE = {
    "Code.7c933d2c": "KeepReason's 'leftover quest item' mark, compared in Tooltip.lua",
    "Code.d06c58af": "TradeSkillMaster's price source name, passed to its API",
    "Code.0b888d07": "a quest kind passed to a callback (Quests.lua), compared in Tooltip.lua",
    "Code.9db08f5a": "a quest kind passed to a callback (Quests.lua), compared in Tooltip.lua",
    "Code.7c871214": "part of a game frame's name (_G[name .. this .. j])",
    "Code.d4e77e1f": "an addon folder name passed to a call (Bags.lua)",
    "Code.a4d263ea": "a loot state (Loot.lua)", "Code.103db657": "a loot state (Loot.lua)",
    "Code.7c96cc3b": "a loot state (Loot.lua)", "Code.7c989e34": "a loot state (Loot.lua)",
}
NAMES = {
    "Code.3bc96936": "its chat prefix (its name in colour): kept as it is",
    "Code.5849882e": "a price addon's name", "Code.ffc7ba27": "a price addon's name",
    "Code.06a8adae": "a slash command", "Code.0b878934": "a slash command",
    "Code.c940fad7": "the What's New title: its name and the version",
}

# A letter per slot, by key (%d slots count anyway; key_text makes %d/%f and |cff%s slots v).
SORTS = {
    "Code.801b6b21": "t",     # a keep click's name (KEEP_CLICKS, ours)
    "Code.0a533f7e": "vt",    # the rank; ValueText: money or ours (Code.d4a55ced), then maybe ours (Code.b29cb80d)
    "Code.ae4b2a63": "t",     # a KeepReason (ours)
    "Code.8ffcf1a4": "vt",    # an item link (or "?"); our number piece (Code.ca207745) or nothing
    "Code.64358fe7": "vt",    # the same
    "Code.13c59ccc": "tt",    # our number piece (Code.ca207745) or nothing; a loot link or ours (Code.d2705709)
}

NOTES = {
    "Code.801b6b21": "a bag item's tooltip; the slot holds a keep click's name (ours)",
    "Code.0a533f7e": "a bag item's tooltip; %d the rank, %s its value: money or ours, maybe with ours glued on",
    "Code.ae4b2a63": "a bag item's tooltip; the slot holds why it is kept (ours, lower case)",
    "Code.8ffcf1a4": "a loot tooltip; slot 1 a bag item's link, slot 2 ours (its number) or nothing",
    "Code.64358fe7": "a loot tooltip; slot 1 a bag item's link, slot 2 ours (its number) or nothing",
    "Code.13c59ccc": "the delete button's tooltip; slot 1 ours (its number) or nothing, slot 2 a loot link or ours",
}
FILE_NOTE = {
    "Settings.lua": "the settings pages (a name, tip, header or choice), or a /lt chat line",
    "SettingsWindow.lua": "the settings window",
    "Tooltip.lua": "an item tooltip line",
    "Loot.lua": "the loot window (delete button and its tooltip)",
    "Bags.lua": "the bags (marks and highlights)",
    "LootTriage.lua": "the core: chat lines, help, why an item is kept",
    "Quests.lua": "the quests a tooltip names",
    "WhatsNew.lua": "the What's New dialog",
}

BATCH_FILES = {"SettingsWindow.lua": 1, "Settings.lua": 1, "WhatsNew.lua": 3}
BATCHES = [
    (1, "the settings window and its pages (SettingsWindow.lua, Settings.lua)", lambda k, sec: sec == 1),
    (2, "tooltips, loot window, bags, chat and help, quests (Tooltip.lua, Loot.lua, Bags.lua, LootTriage.lua, ...)",
     lambda k, sec: sec == 2),
    (3, "the What's New dialog (WhatsNew.lua)", lambda k, sec: True),
]
MAX_BATCH = 150


def batch_of(file):
    return BATCH_FILES.get(file, 2)


def split(rows):
    """Rows in batch order; a batch over MAX_BATCH rows is not split (none is today), so say so loudly."""
    sizes = {}
    for r in rows:
        sizes[r[2]] = sizes.get(r[2], 0) + 1
    big = {b: n for b, n in sizes.items() if n > MAX_BATCH}
    if big:
        raise SystemExit(f"a batch over {MAX_BATCH} rows: {big}; add a batch in lt_rules.BATCHES")
    return rows


def note(key, file, ctx):
    base = NOTES.get(key) or FILE_NOTE.get(file, file)
    return base + (f" ({ctx})" if ctx and not NOTES.get(key) else "")


def keep(key, en):
    """(kept, reason left out)."""
    if key in CODE:
        return False, "code value"
    if key in NAMES:
        return False, "name kept"
    if "n" in sorts(key, en):
        return False, "game name in a slot"
    if not en.strip():
        return False, "empty"
    if not K.LATIN_WORD.search(K.SPECIAL.sub("", en)):
        return False, "no words"
    return True, ""


def sorts(key, en):
    return K.sorts_from(SORTS, key, en)


def check(key, en, ua):
    """What makes `ua` unfit as the Ukrainian of `en`."""
    problems = K.base_check(en, ua, sorts(key, en))
    if key in CODE or key in NAMES:
        problems.append("not a shown text (CODE or NAMES)")
    if "n" in sorts(key, en):
        problems.append("a game name slot: the line stays English")
    if re.match(r"\|c[0-9a-fA-F]{8}", en) and not ua.startswith(en[:10]):
        problems.append("the colour code at the start moved")
    if en.count("|c") != ua.count("|c") or en.count("|r") != ua.count("|r"):
        problems.append("colour codes (|c...|r) differ in number")
    if en.count("\n") != ua.count("\n"):
        problems.append("line breaks differ in number")
    if "·" in ua and "·" not in en:
        problems.append("no middle dot (the Cyrillic font has none)")
    if "•" in ua and "•" not in en:
        problems.append("no bullet (the Cyrillic font may draw a box; tools/test_font_chars.py)")
    return problems
