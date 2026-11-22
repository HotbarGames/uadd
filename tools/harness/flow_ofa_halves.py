"""OneForAll's half-translation check (halves.py): every real template of the installed addon (read at run time
by tools/ofa_source.py, never kept), sent through the module's own Words.Translate in a game with the stand-in,
UADD and UADD_OneForAll (flow_ofa.game). What each slot holds comes from the module's data (ns.SORT): f a free
name ("Quix"), t one of our texts (a capitalised one-word text of ours, picked from the installed addon at run time), v
and n a value. Run alone: python3 tools/harness/flow_ofa_halves.py
"""
import os
import re
import sys

import flow_ofa
import halves_mods

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402
import ofa_source  # noqa: E402
from flow import Check  # noqa: E402
from loader import txt  # noqa: E402

LINK = "|cff1eff00|Hitem:6948::::::::|h[Quix]|h|r"


def our_word(rows, ours):
    """A one-word English text of the addon that has our Ukrainian, capitalised as the addon fills a t slot (a
    profession, a filter), or a link."""
    for key, en, *_ in rows:
        if re.fullmatch(r"[A-Z][a-z]{3,11}", en) and key in ours:
            return en
    return LINK


def templates(sorts, ours=()):
    """[tpl] for each real template; ([], why) when the addon is not installed. ours: the keys with our Ukrainian."""
    try:
        addon = ofa_source.addon_dir()
    except Exception:  # noqa: BLE001
        addon = None
    rows, why = ofa_source.source(addon) if addon else ([], "not installed")
    word, tps = our_word(rows, ours), []
    for key, en, *_ in rows:
        if not hashtext.is_template(en):
            continue
        s = sorts.get(key) or ""
        free = {i: halves_mods.NAME for i, c in enumerate(s, 1) if c == "f"}
        good = {i: word for i, c in enumerate(s, 1) if c == "t"}
        tps.append(halves_mods.tpl(key, en, free, good, sorts=s))
    return tps, why


def run_checks():
    checks = []

    def check(name, ok, detail=""):
        checks.append(Check("ofah: " + name, bool(ok), str(detail)))
    if not flow_ofa.module_there():
        halves_mods.ofa(check, None, [], "skipped: " + flow_ofa.MODULE + " folder missing")
        return checks, {}
    c, _, _ = flow_ofa.game()
    ns = c.H.ns.UADD_OneForAll
    sorts = {txt(k): txt(v) for k, v in ns.SORT.items() if isinstance(v, (str, bytes))}
    tps, why = templates(sorts, {txt(k) for k in ns.OFA.keys()})
    halves_mods.ofa(check, ns.Words, tps, "" if tps else halves_mods.SKIP)
    return checks, {"templates": len(tps), "source": why if not tps else ""}


if __name__ == "__main__":
    cs, fs = run_checks()
    for x in cs:
        print(("PASS  " if x.ok else "FAIL  ") + x.name + (f"  [{str(x.detail)[:400]}]" if not x.ok else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} ok")
    sys.exit(0 if all(x.ok for x in cs) else 1)
