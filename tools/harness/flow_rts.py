"""The Road to Sixty flow skeleton (H1) on a stand-in (tools/harness/rts, not the addon: made-up English).

All 13 steps of design section 10 are named here. Each runs two kinds of check:
  * stand-in checks: always run. They hold the stand-in itself (frames, hooks, counts, English output), so H2's
    module checks have a base that does not move.
  * module checks: SKIP while UADD_RoadToSixty is missing. When it is there, flow_rts_mod.py (H2) supplies
    `module_check(n, check, c, M)`; without that file the step says "H2 not written".
Steps: 1 open map  2 info text 100x  3 hold key  4 off, redraw, on  5 tab click, SetEnabled  6 glued zone
7 character name  8 plurals 1,3,5,11,21  9 dates  10 print, tooltip, 3 popups  11 saved data, ERR_* globals
12 the 4 game-wide hooks  13 walk in combat.
"""
import os
import sys

import session
from loader import Addon, Client, read_text, txt

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from flow import Check  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE, TARGET = "UADD_RoadToSixty", "RoadToSixty"
STEPS = ("open map", "info text 100x", "hold key", "off, redraw, on", "tab click, SetEnabled", "glued zone",
         "character name", "plurals", "dates", "print, tooltip, popups", "saved data, ERR_ globals",
         "4 game-wide hooks", "walk in combat")


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def game(module=False):
    addons = [Addon(TARGET, os.path.join(HERE, "rts", TARGET), session.FLAVOR)]
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD",) + ((MODULE,) if module else ())]
    c = Client(addons, None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_rts.lua")))
    c.start()
    c.H.pump(20)
    return c, c.H.rts


def module_check(n, check, c, M):
    """H2 plugs in here: flow_rts_mod.py defines module_check(n, check, c, M) and runs step n on the real module."""
    try:
        import flow_rts_mod
    except ImportError:
        return check(f"{n} module", None, "SKIP: H2 not written (no flow_rts_mod.py)")
    flow_rts_mod.module_check(n, check, c, M)


def steps(check, c, M, module, mc=None):
    """Stand-in checks run in c (no module); module checks in mc = (c, M) of a game with the module."""
    S = M.stand()
    T = {txt(k): txt(v) for k, v in S.T.items()}

    def mod(n):
        if module:
            module_check(n, check, *mc)
        else:
            check(f"{n} module", None, f"SKIP: {MODULE} folder missing")

    S.OpenMap()
    S.OpenCompare()
    S.OpenNews()
    M.wait(0.1)
    names = {txt(k): v for k, v in M.names().items()}
    check("1 open map: the 4 named frames exist, the title is drawn", all(names.values()) and
          txt(S.title.GetText(S.title)) == T["title"], names)
    mod(1)
    before = S.Settext["info"] if "info" in S.Settext else 0
    last = txt(S.Tick(100))
    check("2 info text 100x: 100 SetText calls, the last one kept", S.Settext["info"] - before == 100 and
          last.endswith("100m"), (S.Settext["info"], last))
    mod(2)
    M.key(True)
    held = txt(S.title.GetText(S.title))
    M.key(False)
    check("3 hold key: the stand-in knows nothing of it (English both ways)", held == T["title"] and
          txt(S.title.GetText(S.title)) == T["title"], held)
    mod(3)
    n0 = S.Calls
    S.Redraw()
    check("4 redraw: 5 more SetText calls, English as it was", S.Calls - n0 == 5 and
          txt(S.tabs[1].fs.GetText(S.tabs[1].fs)) == T["tabA"], S.Calls - n0)
    mod(4)
    check("5 tab click keeps Cyrillic-capable font object; SetEnabled flips IsEnabled",
          M.click(2) and not M.tabFont(1) and M.tabFont(2) and M.enabledButton(False) is False
          and M.enabledButton(True) is True, "tab 2 highlighted, button toggled")
    mod(5)
    check("6 glued zone: 'Entered <zone>'", txt(S.Glued("Zorpvale")) == "Entered Zorpvale", "")
    mod(6)
    S.Title("Quix")
    check("7 character name kept in the title", "Quix" in txt(S.title.GetText(S.title)), "")
    mod(7)
    got = [txt(S.Count(n)) for n in (1, 3, 5, 11, 21)]
    check("8 plurals: 1 zone, then zones", got == ["1 zone", "3 zones", "5 zones", "11 zones", "21 zones"], got)
    mod(8)
    d = [txt(S.When(3, 11)), txt(S.When(1, 1))]
    check("9 dates: English month and weekday", d == ["Wed 3 Nov", "Mon 1 Jan"], d)
    mod(9)
    line = txt(M.say("Gizmo saved"))
    S.Tip()
    tip = [txt(x) for x in M.tipLines().values()]
    pops = []
    for key in S.Popups().values():
        c.lua.globals().StaticPopup_Show(txt(key), "Quix")
        pops.append(txt(M.popup()["text"]))
    check("10 print with prefix, tooltip lines, 3 popups", line.startswith("|cff33ff99RoadToSixty|r: ") and
          tip == [T["mini"], T["tipLine"]] and len(pops) == 3 and all(pops), (line, tip, pops))
    mod(10)
    db1, g1 = txt(M.db()), txt(M.globals())
    S.Redraw()
    check("11 saved data and ERR_/LOOT_/FACTION_/DUEL_ globals: same after a redraw",
          db1 == "Quix|12|Zorpvale|kept" and db1 == txt(M.db()) and g1 == txt(M.globals()) and "ERR_CHAT" in g1,
          (db1, g1[:80]))
    mod(11)
    check("12 4 hooks recorded and still the addon's own (filter, SetItemRef, StartDuel, TIME_PLAYED_MSG)",
          M.hookNow(), "identity of the sentinels")
    mod(12)
    M.combat(True)
    ok = True
    try:
        S.Tick(3)
    except Exception as e:  # noqa: BLE001
        ok = str(e)
    M.combat(False)
    check("13 walk in combat: the stand-in still draws (the wait is the module's)", ok is True, ok)
    mod(13)


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        skip = ok is None
        checks.append(Check("rts: " + name, True if skip else bool(ok), ("SKIP: " if skip and not str(detail).startswith("SKIP")
                                                                           else "") + str(detail)))
    module = module_there()
    c, M = game(False)
    steps(check, c, M, module, game(True) if module else None)
    if module and os.environ.get("RTS_NO_MUTANTS") != "1":
        try:
            import flow_rts_mod
        except ImportError:
            flow_rts_mod = None
        if flow_rts_mod:
            flow_rts_mod.mutants(check)
    facts["module"] = module
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_rts.py
    cs, fs = run_checks()
    for x in cs:
        tag = "SKIP  " if x.detail.startswith("SKIP") else ("PASS  " if x.ok else "FAIL  ")
        print(tag + x.name + (f"  [{x.detail[:300]}]" if x.detail and tag != "PASS  " else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} ok")
    sys.exit(0 if all(x.ok for x in cs) else 1)
