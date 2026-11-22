"""Which Wowhead Quick Link texts UADD_WowheadQuickLink translates, what each template slot holds, and the review
batch. Used by tools/make_wql_text.py (through tools/key_text.py); the texts are found by tools/wql_source.py.

Wowhead Quick Link has no licence file (all rights reserved; CLAUDE.md "Other addons' texts"): nothing here names
its English. Kinds:
  popup    the link popup's text; its slot is the header (t: our header, or a site name kept as it is)
  button   the popup's button
  head     the header's template, the words before the link type; its slot is the type (t: our type word)
  type     a link type as the header shows it
  binding  a key binding name (the game's key bindings page)
  label    a text of the /wql window (its title and three labels)
  whole    a header returned whole: a site name (one word) is kept as it is; the others stay English (the lead,
           2026-11-22: the popup stays English for them)
Run `python3 tools/make_wql_text.py review` to see the texts.
"""
import re

import key_text as K

AS_IS = "kept as it is (a site name or an abbreviation)"

NOTES = {
    "popup": "the link popup's text; %s is the header (\"Wowhead: <type>\" or a site name); keep the line break",
    "button": "the popup's button: short",
    "head": "the popup's header before the link type; %s is the type word",
    "type": "a link type in the popup's header, in small letters (the lead, 2026-11-22)",
    "binding": "a key binding name on the game's key bindings page",
    "label": "a text of the /wql window (330 wide; a label sits above a box 120 wide): keep it short",
}

BATCHES = [
    (1, "the link popup, its header, the key bindings and the /wql window", lambda k, line: True),
]


def batch_of(key, line=0):
    return next(b for b, _, test in BATCHES if test(key, line))


def keep(kind, en):
    """(kept, reason left out)."""
    if not en.strip():
        return False, "empty"
    if kind == "whole":
        return (False, AS_IS) if " " not in en.strip() else (False, "a whole header: stays English")
    if kind == "type" and en.isupper():
        return False, AS_IS
    if not K.LATIN_WORD.search(K.SPECIAL.sub("", en)):
        return False, "no words"
    return True, ""


def sorts(key, en):
    if key.startswith(("Pop.", "Head.")):
        return ["t" for m in K.SLOT.finditer(en) if m.group(0) != "%%"]
    return K.sorts_from({}, key, en)


def check(key, en, ua):
    """What makes `ua` unfit as the Ukrainian of `en`."""
    problems = K.base_check(en, ua, sorts(key, en))
    if key.startswith("Head."):         # the header's words are a site name and a colon: no Ukrainian letters
        problems = [p for p in problems if p != "no Ukrainian letters"]
    if en.count("\n") != ua.count("\n"):
        problems.append("a different number of lines")
    if key.startswith("Type.") and re.match(r"[А-ЯҐЄІЇ]", ua):
        problems.append("a link type starts with a small letter (it follows the header's colon)")
    if key.startswith(("Pop.", "Head.")) and ua.count("%s") != 1:
        problems.append("one %s, no other slot")
    if "—" in ua:
        problems.append("no long dash (the Cyrillic font may lack it)")
    if "·" in ua:
        problems.append("no middle dot")
    return problems
