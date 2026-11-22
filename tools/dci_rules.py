"""Which DeleteCheapestItem Reloaded texts UADD_DeleteCheapestItem translates, what each template slot holds, the
glued texts that get a join row, the fixed-width buttons, and the review batches. Used by tools/make_dci_text.py
(through tools/key_text.py) and tools/dci_source.py.

The addon is all rights reserved (TOC X-License; CLAUDE.md "Other addons' texts"): nothing here names its English.
Every row is keyed Code.<hash>: UADD.Hash of one L key. Run `python3 tools/make_dci_text.py review` to see them.

Letters, one per slot (key_text.py): v a value (a number, money, a coloured count), f a free name kept as it is (a
profile the player named, an addon's name), n a game name (an item: its link or name from UALL Forever or ClassicUA;
the line stays English without one), t another text of ours.
"""
import re

import key_text as K

# Keys its code uses but never shows (left out of the review), by hash.
CODE = {
}

# A letter per slot, by key (%d slots count anyway; key_text makes %d/%f and |cff%s slots v).
SORTS = {
    "Code.a3427f33": "v",   # an item's id
    "Code.39a20359": "t",   # the count text of ours (a number and a noun)
    "Code.ec9c14c7": "t",   # the same
    "Code.38f7fc9a": "t",   # our coloured word
    "Code.0d30bcd1": "v", "Code.402dfc64": "v", "Code.d582e66f": "v", "Code.85dfbd62": "v",  # a coloured count
    "Code.87f2d25f": "v",   # a coloured count
    "Code.5da45718": "v",   # money
    "Code.9af193aa": "ff",  # two profile names
    "Code.73dba259": "f", "Code.9b24ff42": "f",  # a profile name
}

# Glued texts: the L key's hash -> the glue after it ("%s": L[x] .. name; " %s": L[x] .. " " .. name).
JOINS = {
    "Code.17eb494b": "%s",   # chat: an item's name (or its id)
    "Code.f37f62fa": "%s",   # chat: an item's link and count
    "Code.8957114e": " %s",  # the price addon's name, in parens
}
# The join rows (key: the hash of the L key's English, %% for %, and its glue) and their part's key.
JOINED = {"Code.bfe2cd43": "Code.17eb494b", "Code.d0e40eb2": "Code.f37f62fa", "Code.a774c3e6": "Code.8957114e"}
SORTS.update({"Code.bfe2cd43": "n", "Code.d0e40eb2": "n", "Code.a774c3e6": "f"})

# Buttons of a fixed width (lesson 5): (where, its width in px). The Ukrainian may have at most width / PX_PER
# letters, less 1 for the edges (GameFontNormal draws a small Cyrillic letter about 6 px wide; the game draws
# DELETE, «Видалити» with UALL Forever, in the same 60 px button). Manual: look at them in the game.
FIT = {
    "Code.ce876053": ("the ignored items row's button", 76),
    "Code.7c8c4ef5": ("the main window's button", 60),
    "Code.cf210732": ("the ignored items window's button", 200),
    "Code.469cdfcf": ("a settings page button", 150),
    "Code.b93f244f": ("a settings page button", 150),
    "Code.1b102619": ("a settings page button", 150),
}
PX_PER = 6


def fit_max(key):
    return FIT[key][1] // PX_PER - 1


NOTES = {
}
FILE_NOTE = {
    "DeleteCheapestItem.lua": "the main window, its tooltips, the ignored items window, chat, the settings page",
    "Profiles.lua": "a profile message or question",
    "ProfileUI.lua": "the profiles part of the settings page",
    "Broker.lua": "the minimap button's tooltip",
}
BATCHES = [
    (1, "the main window, tooltips, ignored items, chat and settings (DeleteCheapestItem.lua)", lambda k, sec: sec == 1),
    (2, "profiles and the minimap tooltip (Profiles.lua, ProfileUI.lua, Broker.lua)", lambda k, sec: True),
]
MAX_BATCH = 150


def batch_of(file):
    return 1 if file == "DeleteCheapestItem.lua" else 2


def split(rows):
    sizes = {}
    for r in rows:
        sizes[r[2]] = sizes.get(r[2], 0) + 1
    big = {b: n for b, n in sizes.items() if n > MAX_BATCH}
    if big:
        raise SystemExit(f"a batch over {MAX_BATCH} rows: {big}; add a batch in dci_rules.BATCHES")
    return rows


def note(key, file):
    base = NOTES.get(key) or FILE_NOTE.get(file, file)
    if key in FIT:
        base += f"; {FIT[key][0]}, {FIT[key][1]} px wide: at most {fit_max(key)} letters"
    return base


def keep(key, en):
    """(kept, reason left out)."""
    if key in CODE:
        return False, "code value"
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
    if key in CODE:
        problems.append("not a shown text (CODE)")
    if None in sorts(key, en):
        problems.append("a %s slot with no letter in dci_rules.SORTS")
    if key in FIT and len(ua) > fit_max(key):
        problems.append(f"too long for its {FIT[key][1]} px button: {len(ua)} letters, at most {fit_max(key)}")
    if en.count("|c") != ua.count("|c") or en.count("|r") != ua.count("|r"):
        problems.append("colour codes (|c...|r) differ in number")
    if en.count("\n") != ua.count("\n"):
        problems.append("line breaks differ in number")
    if "|" in ua.replace("|c", "").replace("|r", "").replace("|n", "") and "|" not in en:
        problems.append("a | in the Ukrainian starts an escape code")
    if ua.rstrip() != ua and en.rstrip() == en or ua.rstrip() == ua and en.rstrip() != en:
        problems.append("a space at the end differs (the code glues a name after it)")
    if "·" in ua and "·" not in en:
        problems.append("no middle dot (the Cyrillic font has none)")
    if "•" in ua and "•" not in en:
        problems.append("no bullet (the Cyrillic font may draw a box; tools/test_font_chars.py)")
    return problems
