"""Which WhatTheWhisper texts UADD_WhatTheWhisper translates, what each template slot holds, and the review batches.
Used by tools/make_wtw_text.py (through tools/key_text.py).

WhatTheWhisper has no licence (all rights reserved; CLAUDE.md "Other addons' texts"): nothing here names its
English. Its locale keys ARE its English, so every row is keyed by a hash:
  L.<hash>   a key of its enUS locale table (Core/Locale/enUS.lua): UADD.Hash of the key
  X.<hash>   a text drawn without its locale table: a sound label (Sounds.LIBRARY), or a label its code draws
             through L though enUS lacks it: UADD.Hash of the English
  Day.<n>    a weekday name, Sunday = 1 (the order of the game's WEEKDAY_* globals in its Format.lua)
Run `python3 tools/make_wtw_text.py review` to see the texts.

Letters, one per slot (key_text.py): v a value, f a free name kept as it is, n a game name (the line stays
English), t another text of ours, u its own English units (the line stays English, lesson 15).
"""
import calendar
import re

import key_text as K

# Keys its code saves or sends, found in the installed code at build time (wtw_source.stay_texts), never written.
STAY_FRIEND = "the name it gives a friend with no BattleTag: saved into its history (lesson 14)"
STAY_STARTER = "a quick-reply starter: saved once the player edits the list, and sent to other players"
STAY_GROUP = "a group thread's name (party, raid ...): saved into its history; drawn nowhere else"
STAY_NOW = set()      # filled by wtw_source.source() from the installed code

# Names kept as they are (the addon's own name, export format names): left out of the review.
NAMES = {"L.675ca07c": "the addon's name", "L.c8066a48": "a format's name", "L.a6a47264": "a format's name",
         "L.0b87daf1": "a format's name", "L.76f8717d": "a brand name", "L.55f20236": "a brand name"}

# A letter per slot, by key (%d slots count too; key_text makes %d/%f and |cff%s slots v anyway). f: the
# conversation's display name (CM.DisplayName: the nickname or the name; one name) or a wire name.
SORTS = {
    "L.33d98e6c": "f", "L.04af38c1": "ff", "L.7007900f": "f", "L.7dcb6c6e": "f", "L.c93f1e2f": "f",
    "L.2e7cadcc": "f", "L.8930958f": "fv", "L.3d8f8002": "f", "L.a67a9685": "f", "L.ce6ee520": "f",
    "L.c455616e": "v",    # the export file's path
    "L.cc8e48a1": "v",    # a chat player link
    "L.6fe136bf": "f", "L.5b49ebd2": "f",    # the context menu's "Whisper/Block <short name>"
    "L.abf52159": "f",    # the icon picker's hint: a group thread's display name (a nickname, or its thread id)
    "L.26a34d4a": "fu",   # the zone alert: a name, then the zone's English name (Lines.lua asks the Zone route)
    "L.17d2f1f2": "u",    # Format.Bytes: a size in its own English units (lesson 15): the line stays English
}

# Sort-u templates whose units are ours (lesson 15): never put in its table (Swap.lua skips u), but our Ukrainian
# is in the data, and the module's own code fills the slot where the line is drawn, else the line stays English.
OWN_UNITS = {
    "L.17d2f1f2": "the History page's size line: Gaps.lua says its B, KB and MB in Ukrainian; any other unit "
                  "keeps the whole line English",
    "L.26a34d4a": "the zone alert: Lines.lua asks UADD.UALL.Zone where it is printed; no name: whole English",
}

# Drawn in a game font (the stub page in the game's AddOns settings), not in its own Inter/Manrope (which have
# the long dash and every Ukrainian letter): no long dash there.
GAME_FONT = {"L.675b0b9c", "L.8aca3ff6"}

_NAME = "the slot holds the conversation's name (a nickname or a player): kept as it is"
NOTES = {
    "L.33d98e6c": "the composer's placeholder; " + _NAME,
    "L.04af38c1": "a chat line; both slots hold the same player name",
    "L.7007900f": "the not-delivered tooltip; " + _NAME,
    "L.c93f1e2f": "the not-delivered tooltip; " + _NAME,
    "L.2e7cadcc": "the empty conversation's body; " + _NAME,
    "L.8930958f": "the delete dialog; " + _NAME + "; then a count",
    "L.3d8f8002": "a toast; " + _NAME,
    "L.a67a9685": "the delete-message dialog; " + _NAME,
    "L.ce6ee520": "a chat line (the online alert); " + _NAME,
    "L.c455616e": "a note in the export dialog; the slot holds a file path",
    "L.cc8e48a1": "a chat line; the slot holds a clickable player link",
    "L.675b0b9c": "the stub page in the game's AddOns settings, built once (the module redraws it)",
    "L.8aca3ff6": "also the stub page's button, built once",
    "L.ee627ce9": "also a key binding name (copied at load)",
    "L.270fcac7": "also a key binding name (copied at load)",
    "L.b82b593e": "also an export format name (copied at load)",
    "L.0b885db2": "glued between a name and a nickname: keep it short, in small letters",
    "L.0db28224": "glued after a status with a dot between",
    "L.00a9c057": "a dialog button, built once",
    "L.ab41f40b": "dialog buttons, built once",
    "L.7c8c3f34": "a dialog button, built once",
    "L.0d76c6e2": "a dialog button, built once",
    "L.ce81b906": "an emoji picker tab, built once: keep it short",
}
SOUND_NOTE = "a sound's name in the sound dropdowns (Sounds.LIBRARY), drawn without its locale table"
MISSING_NOTE = "drawn through its locale table, but enUS lacks the key, so the English shows by key"
DAY_NOTE = "a weekday (the game's global): the date line, and its first 3 letters in the list's time column"

# The game's English weekday names, Sunday first (Python's own, in the C locale: calendar starts on Monday).
WEEKDAYS = tuple(calendar.day_name[(i + 6) % 7] for i in range(7))

# enUS.lua's section comments by UADD.Hash (wtw_source.sections), in file order, and the batch of each.
SECTIONS = {
    "3e6f103b": 1, "b7da324d": 1, "44aada94": 1, "3ec78c28": 1, "dcd0ce9f": 1, "723dd268": 1,
    "aa1ee99c": 2, "a29c1fce": 2, "99b199e0": 2, "6d6c576e": 2, "f94da8c2": 2, "7ebb92ec": 2, "cde5e0ea": 2,
    "a2e66583": 3, "59647266": 3, "17f15b75": 3, "31f99906": 3,
    "e1fdadf7": 3, "51b294f9": 1, "11f711a8": 4,    # the emoji picker went to 3 when batch 1 passed 150 (1.0.0 update);
    "534c8789": 3,                                  # slash help went to 4 when it passed 150 again (group chats)
}

BATCHES = [
    (1, "window, composer, conversation states, empty states, menu, dialogs, toasts",
     lambda k, sec: SECTIONS.get(sec) == 1),
    (2, "settings: pages, general, appearance, layout, history, sounds, notifications",
     lambda k, sec: SECTIONS.get(sec) == 2),
    (4, "slash help, group chats, channels, reactions, message requests, blocking, notes, minimap button",
     lambda k, sec: SECTIONS.get(sec) == 4),
    (3, "settings: animations, combat, links, advanced, schema labels; emoji picker; sound names, missing labels, weekdays",
     lambda k, sec: True),
]


def batch_of(key, sec=""):
    return next(b for b, _, test in BATCHES if test(key, sec))


def stay(key):
    return key in STAY_NOW


def keep(key, en):
    """(kept, reason left out)."""
    if stay(key):
        return False, "stay"
    if key in NAMES:
        return False, "name kept"
    letters = set(sorts(key, en))
    if "n" in letters or ("u" in letters and key not in OWN_UNITS):
        return False, "own English in a slot"
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
    if stay(key):
        problems.append("a STAY key (never written)")
    if key in NAMES:
        problems.append("a name kept as it is")
    letters = sorts(key, en)
    if "n" in letters or ("u" in letters and key not in OWN_UNITS):
        problems.append("a game name or English units slot: the line stays English")
    if re.match(r"\|c[0-9a-fA-F]{8}", en) and not ua.startswith(en[:10]):
        problems.append("the colour code at the start moved")
    if en.count("|c") != ua.count("|c") or en.count("|r") != ua.count("|r"):
        problems.append("colour codes (|c...|r) differ in number")
    if en.count("\n") != ua.count("\n"):
        problems.append("line breaks differ in number")
    if "·" in ua and "·" not in en:
        problems.append("no middle dot (the Cyrillic font has none)")
    if "—" in ua and "—" not in en and key in GAME_FONT:
        problems.append("no long dash here (drawn in a game font, which may lack it)")
    return problems
