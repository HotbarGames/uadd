"""Part of flow_fxpb.py (game A): which template a text gets, and never a half-translated line.

  * Hints: a FontString's last (short) template is tried first, but a longer one that fits wins.
  * The reputation strip's drag tooltip (a nameless movable frame on UIParent since 0.9.1): all
    Ukrainian, Latin-free; a short word on that same owner stays English (it could be any addon's).
  * A %s holds a value, a time or one of the addon's own texts. Other English there means another
    text that only starts or ends the same way: it stays English as a whole (halves_mods.fxpb, on
    every template of the installed addon). A value in the same slot, or a name in a slot marked
    free (fxpb_words.FREE), is still translated.
"""
import re

import halves_mods
from loader import lua_str, txt

CYR = re.compile("[Ѐ-ӿ]")
LATIN = re.compile("[A-Za-z]")
BONUS = ("+8% All stats", "+3% Well Rested", "+21 Stamina")   # camp buff tooltip: a bonus and its label
KEPT = (("Level 12", "12"), ("Active: Bob", "Bob"))     # a value; a name in a free slot


def checks(check, eq, M, S):
    short, long_ = "Race goal received: reach level %s%s.", "Race goal received: reach level %s by %s."
    eq(check, "hint: a short template first", M.ukAt("race", lua_str("Race goal received: reach level 20.")),
       S[short] % ("20", ""))
    eq(check, "hint loses to a longer template that matches too",
       M.ukAt("race", lua_str("Race goal received: reach level 30 by Fri 22:30.")), S[long_] % ("30", "пт 22:30"))
    halves_mods.fxpb(check, M)
    for en, keep in KEPT:
        got = txt(M.uk(lua_str(en)))
        ok = bool(got) and bool(CYR.search(got)) and keep in got and \
            not any(w in got for w in en.replace(keep, "").split())
        check(f"... but {en!r} is translated", ok, got)
    for en in BONUS:
        got = txt(M.uk(lua_str(en))) or ""
        check(f"bonus {en!r}: Ukrainian, the value kept",
              bool(CYR.search(got)) and not LATIN.search(got) and got.startswith(en.split()[0]), got)
    odd = [M.uk(lua_str(en)) for en in ("+8% Wobbly gizmo", "+Wobbly gizmo All stats")]
    check("bonus: an unknown label or value: the whole line English", odd == [None, None], odd)
    M.hoverRep(False)
    for i in (1, 2):
        got = txt(M.tipLine(i)) or ""
        check(f"rep strip drag tooltip line {i}: Ukrainian", bool(CYR.search(got)) and not LATIN.search(got), got)
    M.leave()
    M.hoverRep(True)
    got = txt(M.tipLine(1)) or ""
    check("rep strip: a short word stays English", not CYR.search(got), got)
    M.leave()
