"""Which Road to Sixty texts UADD_RoadToSixty translates, what each template slot holds, the batches, and the check.
Used by tools/make_rts_text.py (through tools/key_text.py) and tools/rts_source.py.

Road to Sixty is all rights reserved (CLAUDE.md "Other addons' texts"): nothing here names its English. It has no
locale table: every row is keyed Code.<hash>, UADD.Hash of one string literal (escapes decoded).

Slot letters (key_text.py), one per %s slot: v a value (number, money, clock, date), f the player's own names, n a
game name (the line stays English unless a route gives it), t our text glued in, u a duration in English units.
Plurals are written in Ukrainian as {one|few|many} after a number slot: "%d {квест|квести|квестів}".
"""
import re

import key_text as K
from rts_rules2 import BATCH_FILES, BATCHES, NOTES, SORTS, STAY, WORDS     # noqa: F401  (the tables)
from test_banned_words import BANNED

MAX_BATCH = 150
FILE_NOTE = {
    "Core.lua": "chat prints and the /rts help", "Map.lua": "the journey map window",
    "Panel.lua": "the History / Characters panel", "Options.lua": "the options page",
    "MinimapButton.lua": "the minimap button tooltip and /rts minimap", "WhatsNew.lua": "the What's New frame",
    "Screens.lua": "a screen tab", "Style.lua": "route legend, day heads", "StatsScreen.lua": "the Stats screen",
    "Range.lua": "the range menu", "LevelShot.lua": "the screenshot line", "Journal.lua": "/rts stats",
    "LevelChat.lua": "the level-up chat summary", "FriendsPanel.lua": "the remove-friend popup",
}
PLURAL = re.compile(r"\{([^{}|]*)\|([^{}|]*)\|([^{}|]*)\}")
NUMBER_BEFORE = re.compile(r"(?:%\d*(?:\.\d*)?[df]|%s)\s*$")     # a number slot right before a plural mark
MAXLEN = 34         # a fixed box (tab, button, tile label): the UA at most this long unless in LONG


def batch_of(file):
    return BATCH_FILES.get(file, 4)


def split(rows):
    """Rows in batch order; a group of one base batch is cut into batches of at most MAX_BATCH, numbered in turn."""
    groups, out, n = {}, [], 0
    for r in rows:
        groups.setdefault(r[2], []).append(r)
    for base in sorted(groups):
        g = groups[base]
        size = -(-len(g) // -(-len(g) // MAX_BATCH))         # equal parts, none over MAX_BATCH
        for i in range(0, len(g), size):
            n += 1
            out += [[*r[:2], n, *r[3:]] for r in g[i:i + size]]
    if n > len(BATCHES):
        raise SystemExit(f"{n} batches, but rts_rules2.BATCHES has {len(BATCHES)}: add some")
    return out


def note(key, file, ctx):
    base = NOTES.get(key) or FILE_NOTE.get(file, file)
    if not NOTES.get(key) and ctx:
        base += f" ({ctx})"
    return base


def keep(key, en, ctx=""):
    """(kept, reason left out)."""
    if key in STAY:
        return False, "stays English"
    if not en.strip():
        return False, "empty"
    plain = K.SPECIAL.sub("", en)
    if not K.LATIN_WORD.search(plain):
        return False, "no words"
    if en.startswith("|cff%") or re.fullmatch(r"[A-Za-z]{1,2}", plain.strip()):
        return False, "format piece"
    if re.fullmatch(r"[a-z]+", en) and en not in WORDS:
        return False, "machine word"
    if re.fullmatch(r"/\S+|\S*[:=]", en):
        return False, "command or key"
    if "n" in sorts(key, en):
        return False, "game name in a slot"
    return True, ""


def sorts(key, en):
    return K.sorts_from(SORTS, key, en)


def check(key, en, ua):
    """What makes `ua` unfit as the Ukrainian of `en`."""
    plain, problems = PLURAL.sub("", ua), []
    for m in PLURAL.finditer(ua):
        if not NUMBER_BEFORE.search(ua[:m.start()]):
            problems.append("a plural {a|b|c} only after a number slot (%d)")
    if "{" in plain or "}" in plain:
        if "{" not in en:
            problems.append("a stray brace (a plural has three forms: one|few|many)")
    problems += K.base_check(en, plain, sorts(key, en))
    if key in STAY:
        problems.append("not a shown text (STAY)")
    if "n" in sorts(key, en):
        problems.append("a game name slot: the line stays English")
    if en.count("|c") != ua.count("|c") or en.count("|r") != ua.count("|r"):
        problems.append("colour codes (|c...|r) differ in number")
    if re.match(r"\|c[0-9a-fA-F]{8}", en) and not ua.startswith(en[:10]):
        problems.append("the colour code at the start moved")
    if en.count("\n") != ua.count("\n"):
        problems.append("line breaks differ in number")
    for ch, why in (("—", "a long dash"), ("–", "a long dash"), ("·", "a middle dot"), ("•", "a bullet"),
                    ("«", "angle quotes"), ("»", "angle quotes")):
        if ch in ua and ch not in en:
            problems.append(f"no {why} (the Cyrillic font and the owner's rule)")
    for rx, (use, why) in BANNED.items():
        if re.search(rx, ua, re.I):
            problems.append(f"banned word: use {use} ({why})")
    limit = LONG.get(key, MAXLEN) if key in BOX else None
    if limit and len(plain.split("\n")[0]) > limit:
        problems.append(f"too long for its box: {len(plain)} > {limit}")
    return problems


from rts_rules2 import BOX, LONG    # noqa: E402  (fixed-box keys and their limits)
