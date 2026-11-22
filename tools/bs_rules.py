"""Which BugSack texts UADD_BugSack translates, what each template slot holds, and the review batch. Used by
tools/make_bs_text.py (through tools/key_text.py); the texts are found by tools/bs_source.py.

BugSack is All Rights Reserved: nothing here names its English. Kinds (from where its code reads the text):
  window   a text of the sack window set once (a button, a tab, the filter label, the session line's parts)
  option   a check box or row label on the window's options tab
  tip      a tooltip line (a check box's, a button's, the minimap icon's)
  chat     a line it prints to the chat
  popup    the send popup's text and button
  word     a word its code glues into the session line
  game     the game's own word it shows (its options tab)
Left English on purpose (STAY): the font size menu's rows (the game's menu draws them, lesson 38: later), the
text it raises as a Lua error (an error text stays as it is) and the line shown only without BugGrabber (UADD
cannot load then). Run `python3 tools/bs_source.py` to see the texts.
"""
import re

import key_text as K

STAY_MENU = "a font size menu row: the game's menu draws it, stays English"
STAY_ERROR = "raised as a Lua error: an error text stays as it is"
STAY_MISSING = "shown only without BugGrabber, when UADD_BugSack cannot load"
UNUSED = "not read by its code"

NOTES = {
    "window": "a text of the sack window (a button 200 wide, a tab, the filter label): short",
    "option": "a label on the options tab (a check box or a row): short",
    "tip": "a tooltip line: plain, can be longer",
    "chat": "a line it prints to the chat",
    "popup": "the send popup: its text (%d: the session number) or its button",
    "word": "a word glued into the session line, after its time: small letters",
    "game": "the game's word on the options tab and the session line",
}

BATCHES = [
    (1, "the sack window, its options tab, tooltips, chat lines and the send popup", lambda k, line: True),
]

# What each %s holds: f a player's name (kept as it is), t our word. %d is a number (v). The window's one
# two-slot template is the session line's "sent by": a player, then our word.
SLOTS = {"chat": "ffff", "popup": "vvvv"}


def batch_of(key, line=0):
    return next(b for b, _, test in BATCHES if test(key, line))


def keep(kind, en):
    """(kept, reason left out)."""
    if not en.strip():
        return False, "empty"
    if kind in ("menu", "error", "missing", "unused"):
        return False, {"menu": STAY_MENU, "error": STAY_ERROR, "missing": STAY_MISSING, "unused": UNUSED}[kind]
    if not K.LATIN_WORD.search(K.SPECIAL.sub("", en)):
        return False, "no words"
    return True, ""


KINDS = {}          # key -> kind, filled by bs_source.source()


def sorts(key, en):
    letters = SLOTS.get(KINDS.get(key, "")) or ("ft" if len(K.slots(en)) == 2 else "tttt")
    return K.sorts_from({key: letters}, key, en)


def check(key, en, ua):
    """What makes `ua` unfit as the Ukrainian of `en`."""
    problems = K.base_check(en, ua, sorts(key, en))
    kind = KINDS.get(key, "")
    if en.count("\n") != ua.count("\n"):
        problems.append("a different number of lines")
    if kind in ("window", "option") and len(ua) > len(en) * 1.7 + 4:
        problems.append("much longer than the English on a fixed button or row")
    if kind == "word" and re.match(r"[А-ЯҐЄІЇ]", ua):
        problems.append("a word glued into a line starts with a small letter")
    if "—" in ua or "–" in ua:
        problems.append("no long dash (the Cyrillic font may lack it)")
    if "·" in ua:
        problems.append("no middle dot")
    if "«" in ua or "»" in ua:
        problems.append("no angle quotes (the font may lack them)")
    return problems
