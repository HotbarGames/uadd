"""The keyboard stays free (docs/LESSONS2.md lesson 16). One English game with UADD, every stand-in in
tools/harness/ that has a TOC, and every UADD module whose addons are among them (Mastercraft and What's
Training? always). After login nobody has the keyboard focus (GetCurrentKeyBoardFocus() is nil), so Enter
opens chat. A module that made a throwaway EditBox (shown, autoFocus on, as the game makes it) fails here.
"""
import collections
import glob
import os
import sys

import session
from loader import Addon, Client, read_text

HERE = os.path.dirname(os.path.abspath(__file__))
MUST = ("UADD_Mastercraft", "UADD_WhatsTraining")


def _deps(toc):
    with open(toc, encoding="utf-8-sig") as f:
        for line in f:
            if line.lower().startswith(("## dependencies:", "## requireddeps:")):
                return [d.strip() for d in line.split(":", 1)[1].split(",") if d.strip()]
    return []


def addons():
    """[Addon] in load order: the stand-ins, UADD, then the modules that can load with them."""
    stand = []
    for toc in sorted(glob.glob(os.path.join(HERE, "*", "*.toc"))):
        name = os.path.splitext(os.path.basename(toc))[0]
        stand.append(Addon(name, os.path.dirname(toc), session.FLAVOR))
    have = {a.name for a in stand} | {"UADD"}
    mods = []
    for toc in sorted(glob.glob(os.path.join(session.REPO, "UADD_*", "UADD_*.toc"))):
        name = os.path.splitext(os.path.basename(toc))[0]
        if name in MUST or all(d in have for d in _deps(toc)):
            mods.append(Addon(name, os.path.dirname(toc), session.FLAVOR))
    return stand + [Addon("UADD", os.path.join(session.REPO, "UADD"), session.FLAVOR)] + mods, mods


def run(check, facts):
    every, mods = addons()
    c = Client(every, None, "enUS")
    for lua in ("flow_mastercraft.lua", "flow_whatstraining.lua"):   # their method-table stand-ins
        c.lua.execute(read_text(os.path.join(HERE, lua)))
    before = c.H.Widget.CreateFontString
    c.start()
    c.H.pump(60)
    names = [m.name for m in mods]
    facts["modules"] = len(names)
    changed = c.lua.eval("function(a) return HARNESS.Widget.CreateFontString ~= a end")(before)
    check("CreateFontString hooked through UADD.WidgetMethods (Mastercraft, What's Training?)", changed, "")
    focus = c.lua.globals().GetCurrentKeyBoardFocus()
    who = None if focus is None else c.H.Widget.GetDebugName(focus)
    check(f"keyboard free after login with {len(names)} modules (Enter opens chat)", focus is None, who)


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("focus: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_focus.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
