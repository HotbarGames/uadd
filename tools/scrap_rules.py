"""Which Scrap texts UADD_Scrap translates, what each template slot holds, and the review batches.
Used by tools/make_scrap_text.py (through tools/key_text.py).

Scrap's TOCs say All Rights Reserved (CLAUDE.md "Other addons' texts"): nothing here names its English. Its
locale keys are plain names, so every row is keyed by one:
  L.<key>      a key of Scrap's own locale table (AceLocale "Scrap", localization/en.lua)
  FAQ.<n>      the n-th line of its help page's question list (the locale key FAQ is a list)
  Code.<hash>  a text its settings code writes itself (a page name, a button): UADD.Hash of the English
Run `python3 tools/make_scrap_text.py review` to see the texts.

Letters, one per slot (key_text.py): v a value, f a free name kept as it is, n a game name (the line stays
English), t another text of ours.
"""
import re

import key_text as K

# Never written into Scrap's locale, with the reason (lesson 9; RareScanner's item-link lines did the same).
STAY = {
    "L.Added": "a chat line with an item link in it (a game name): the line stays English",
    "L.Removed": "a chat line with an item link in it (a game name): the line stays English",
    "L.Forgotten": "a chat line with an item link in it (a game name): the line stays English",
    "L.Destroyed": "a chat line with an item link in it (a game name): the line stays English",
}

# A letter per %s, by key. The money lines get GetMoneyString (a value). The STAY lines are listed for the
# review only: an item link (n), and a stack count (v).
SORTS = {
    "L.SoldJunk": "v", "L.Repaired": "v", "L.GuildRepaired": "v",
    "L.Added": "n", "L.Removed": "n", "L.Forgotten": "n", "L.Destroyed": "nv",
}

NOTES = {
    "L.Add": "a button under the junk list and the merchant button's tooltip: its width follows the text",
    "L.Remove": "a button under the junk list and the merchant button's tooltip: its width follows the text",
    "L.Forget": "a button under the junk list: its width follows the text",
    "L.Junk": "a tab of the junk list window, 115 wide, after an icon: keep it short",
    "L.NotJunk": "a tab of the junk list window, 115 wide, after an icon: keep it short",
    "L.JunkList": "a settings page name (the game's settings list): an icon is glued after it",
    "L.ToggleMousehover": "also a key binding name; the help page's second answer names it: use the same words",
    "L.SellJunk": "also a key binding name; UALL Forever's words for the same English",
    "L.iLevelTreshold": "a slider label; the glossary says G\"game.item_level\"",
}
CODE_NOTE = "written in Scrap's settings code (options.lua), not in its locale table"

# Review batches: (number, area, test(key, line)). line: the key's line in localization/en.lua (0: code).
SPLIT = 64  # en.lua lines before this: names, chat, the dialog, settings; after: help and the tutorial


BATCHES = [
    (1, "names, buttons, chat lines, the dialog, settings and their tooltips",
     lambda k, line: k.startswith("L.") and 0 < line < SPLIT),
    (2, "the help and patrons pages, the questions list, the tutorial, buttons its code writes",
     lambda k, line: True),
]


def batch_of(key, line=0):
    return next(b for b, _, test in BATCHES if test(key, line))


def stay(key):
    return key in STAY


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


def check(key, en, ua):
    """What makes `ua` unfit as the Ukrainian of `en`."""
    problems = K.base_check(en, ua, sorts(key, en))
    if stay(key):
        problems.append("a STAY key (never written)")
    if "n" in sorts(key, en):
        problems.append("a game name slot: the line stays English")
    m = re.match(r"\|c[0-9a-fA-F]{8}", en)
    if m and not ua.startswith(m.group(0)):
        problems.append("the colour code at the start moved")
    if en.count("|c") != ua.count("|c") or en.count("|r") != ua.count("|r"):
        problems.append("colour codes (|c...|r) differ in number")
    if "—" in ua:
        problems.append("no long dash (the Cyrillic font may lack it)")
    return problems
