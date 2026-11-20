"""Which Speedy AutoLoot texts UADD_SpeedyAutoLoot translates, what each template slot holds, and the review
batch. Used by tools/make_sal_text.py (through tools/key_text.py); the texts are found by tools/sal_source.py.

Speedy AutoLoot has no licence file (all rights reserved; CLAUDE.md "Other addons' texts"): nothing here names
its English. Every row is keyed Code.<hash>, UADD.Hash of the English as the module sees it:
  state  a chat line of its slash command, after the addon's name prefix (the prefix stays as it is)
  help   a line of its slash command's help list, after the colour code and "/sal " (kept as they are)
  label  the label of its loot display's anchor (a small movable box)
  test   an item name of a test entry, shown while the anchor is being moved
Run `python3 tools/make_sal_text.py review` to see the texts.

Letters, one per slot (key_text.py): v a value, f a free name kept as it is, n a game name (the line stays
English), t another text of ours. The only template is the sound line: its slot is a sound's number (v).
"""
import re

import key_text as K

# A letter per %s, by key: the sound line (its slot: a number).
SORTS = {
    "Code.d1e44faf": "v",
}

NOTES = {
    "state": "a chat line of /sal after the addon's name; keep the colour codes",
    "help": "a help line of /sal after the command; keep the colour codes; the part before the first |r is the "
            "command's own words (the player types them): keep them as they are",
    "label": "the label of the loot display's anchor (a small box you drag): keep it short",
    "test": "an item name of a test entry shown while you move the anchor: keep it short",
    "other": "",
}

BATCHES = [
    (1, "chat lines of /sal, the loot display's anchor and its test entries", lambda k, line: True),
]

# A help line: the command's own words, up to and with the dash and the description's colour code.
HELP_HEAD = re.compile(r"^[^|]*-\|r \|c[0-9a-fA-F]{8}")


def batch_of(key, line=0):
    return next(b for b, _, test in BATCHES if test(key, line))


def keep(kind, en):
    """(kept, reason left out)."""
    if kind == "other":
        return False, "not the addon's line"
    if not en.strip():
        return False, "empty"
    if not K.LATIN_WORD.search(K.SPECIAL.sub("", re.sub(r"/\w+", "", en))):
        return False, "no words"
    return True, ""


def sorts(key, en):
    return K.sorts_from(SORTS, key, en)


def head(en):
    """The part of a help line kept as it is (the command's words), or ''."""
    m = HELP_HEAD.match(en)
    return m.group(0) if m else ""


def check(key, en, ua):
    """What makes `ua` unfit as the Ukrainian of `en`."""
    problems = K.base_check(en, ua, sorts(key, en))
    if "n" in sorts(key, en):
        problems.append("a game name slot: the line stays English")
    m = re.match(r"\|c[0-9a-fA-F]{8}", en)
    if m and not ua.startswith(m.group(0)):
        problems.append("the colour code at the start moved")
    if en.count("|c") != ua.count("|c") or en.count("|r") != ua.count("|r"):
        problems.append("colour codes (|c...|r) differ in number")
    h = head(en)
    if h and not ua.startswith(h):
        problems.append("a help line's command part changed (keep it up to the description's colour code)")
    if "—" in ua:
        problems.append("no long dash (the Cyrillic font may lack it)")
    if "·" in ua:
        problems.append("no middle dot")
    return problems
