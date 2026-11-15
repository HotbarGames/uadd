"""Part of flow_fxpb.py (game A): which template a text gets, and never a half-translated line.

  * Hints: a FontString's last (short) template is tried first, but a longer one that fits wins.
  * A %s holds a value, a time or one of the addon's own texts. Other English there means another
    text that only starts or ends the same way: it stays English as a whole (halves_mods.fxpb, on
    every template of the installed addon). A value in the same slot, or a name in a slot marked
    free (fxpb_words.FREE), is still translated.
"""
import re

import halves_mods
from loader import lua_str, txt

CYR = re.compile("[Ѐ-ӿ]")
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
