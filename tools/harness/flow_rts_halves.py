"""Road to Sixty's half-translation check (halves.py): every real template of the installed addon (read at run
time by tools/rts_source.py, never kept), sent through the module's own Words.Translate in a game with the
stand-in, UADD and UADD_RoadToSixty (flow_rts.game). What each slot holds comes from the module's data
(ns.SORT): f a free name ("Quix"), t a link, v and n a value. Run alone: python3 tools/harness/flow_rts_halves.py
"""
import os
import re
import sys

import flow_rts
import halves_mods

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402
import rts_source  # noqa: E402
from flow import Check  # noqa: E402
from loader import txt  # noqa: E402

LINK = "|cff1eff00|Hitem:6948::::::::|h[Quix]|h|r"
# Templates whose t slot the addon fills with a chart's name in small letters (StatsScreen.lua: its CURVES
# table, each name put through :lower()): fed that real name, read from the installed addon, never kept.
LOWERED = {"Code.9207f3ad"}


def chart_word(addon):
    """The first chart name of the installed addon, in small letters, or None."""
    try:
        with open(os.path.join(addon, "StatsScreen.lua"), encoding="utf-8", errors="replace") as f:
            src = f.read()
    except OSError:
        return None
    m = re.search(r"local CURVES = \{(.*?)\n\}", src, re.S)
    names = re.findall(r'\{\s*"\w+",\s*"([^"]+)"', m.group(1)) if m else []
    return names[0].lower() if names else None


def templates(sorts):
    """[tpl] for each real template; ([], why) when the addon is not installed."""
    addon = rts_source.addon_dir()
    rows, why = rts_source.source(addon) if addon else ([], "not installed")
    low = chart_word(addon) if addon else None
    tps = []
    for key, en, *_ in rows:
        if not hashtext.is_template(en):
            continue
        s = sorts.get(key) or ""
        free = {i: halves_mods.NAME for i, c in enumerate(s, 1) if c == "f"}
        t = low if key in LOWERED and low else LINK
        good = {i: t for i, c in enumerate(s, 1) if c == "t"}
        tps.append(halves_mods.tpl(key, en, free, good, sorts=s))
    return tps, why


def run_checks():
    checks = []

    def check(name, ok, detail=""):
        checks.append(Check("rtsh: " + name, bool(ok), str(detail)))
    if not flow_rts.module_there():
        halves_mods.rts(check, None, [], "skipped: " + flow_rts.MODULE + " folder missing")
        return checks, {}
    c, _ = flow_rts.game(True)
    ns = c.H.ns.UADD_RoadToSixty
    sorts = {txt(k): txt(v) for k, v in ns.SORT.items() if isinstance(v, (str, bytes))}
    tps, why = templates(sorts)
    halves_mods.rts(check, ns.Words, tps, "" if tps else halves_mods.SKIP)
    return checks, {"templates": len(tps), "source": why if not tps else ""}


if __name__ == "__main__":
    cs, fs = run_checks()
    for x in cs:
        print(("PASS  " if x.ok else "FAIL  ") + x.name + (f"  [{str(x.detail)[:400]}]" if not x.ok else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} ok")
    sys.exit(0 if all(x.ok for x in cs) else 1)
