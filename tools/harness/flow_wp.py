"""UADD_WaypointUI on a stand-in for Waypoint UI (tools/harness/waypointui). Waypoint UI has no licence file: the
stand-in holds none of its English. This flow reads the texts from the installed Waypoint UI
(flow_wp_texts.py) and gives them to the stand-in before the game starts. The expected Ukrainian is the
module's own data (ns.WP, read by M.want and M.fill in flow_wp.lua). Steps: flow_wp_steps.py.

  * Game A (English client): 1 at login: prompts, footer and pinpoint ours; destination and Navigator kept.
    2 busy flag. 3 footer ticks (lesson 12). 4 distance and time, odd ones too. 5 replace prompts (free slot).
    6 pin names (lesson 13). 13 a pin named after its map: the map's name from UADD.UALL.Zone (made-up maps).
    14 a quest's pin: the tracked quest's title from UADD.UALL.Quest (made-up quests).
    7 off/on and the hold key (lessons 15, 23). 8 fonts (lessons 2, 18).
    9 settings built late, the 1 s walk stops. 10 keyboard free (lesson 16). 11 10 KB speed (lesson 22).
    No half-translated line (halves_mods.wp).
  * Game B: roots missing. Game E: errors in its SetText (lesson 26). Game C: ruRU client. Game F: 15 five errors
    in its own hooks, then on again: they work (lesson 19, flow_wp_errors.py).
  * Mutants (one fix cut from the module, in memory only): steps 2, 3, 12 to 15 must fail, so they have teeth.
"""
import collections
import gc
import os
import sys

import flow_wp_errors as E
import flow_wp_steps as S
import halves_mods
import session
from flow_wp_texts import MODULE, module_there, picks, rows, shipped, templates
from loader import Addon, Client, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
ROOTS = ("WUIWaypointFrame", "WUIPinpointFrame", "WUISettingFrame", "WUINavigatorFrame")


def _game(p, locale="enUS", cut=None, miss=()):
    addons = [Addon("WaypointUI", os.path.join(HERE, "waypointui"), session.FLAVOR)]
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD", MODULE)]
    c = Client(addons, None, locale)
    c.lua.execute(read_text(os.path.join(HERE, "flow_wp.lua")))
    M = c.H.wp
    M.cut = cut and lua_str(cut)
    for en in p["settings"]:
        M.feedSetting(lua_str(en))
    for k in ("button", "input", "info", "nav"):
        M.feed(k, lua_str(p[k]))
    M.feed("pin", lua_str("Quix\n" + p["grey"]))
    for name in miss:
        M.miss(name)
    c.start()
    c.H.pump(60)
    M.after()
    return c, M


def _errors(c, check, step):
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def game_a(check, p, src, temps):
    c, M = _game(p)
    check("module on, its words loaded", M.loaded() and M.on() and M.words() > 0, M.words())
    S.login(check, M, p)
    S.busy(check, M, p)
    S.ticks(check, M)
    S.units(check, M)
    S.prompts(check, M, p)
    S.pins(check, M, p)
    S.place(check, M)
    S.quest(check, M, p)
    S.offon(check, M, p)
    S.fonts(check, M, p)
    S.settings(check, M, p)
    S.speed(check, M)
    M.uadd(lua_str("waypointui"))
    check("status: on, with counts", "увімкнено: Waypoint UI українською" in txt(M.lastChat(4)), txt(M.lastChat(4)))
    tps = templates(src, temps, halves_mods.NAME)
    halves_mods.wp(check, M, tps, "" if tps else "skipped: no Ukrainian templates shipped yet")
    _errors(c, check, "game A")


def game_b(check, p):
    c, M = _game(p, miss=ROOTS)
    ok = M.on() and S.t(M, "button") == S.w(M, p["button"]) and S.t(M, "input") == S.w(M, p["input"])
    check("B roots missing (waypoint, pinpoint, settings, Navigator): no error, the prompts still ours", ok,
          (M.on(), S.t(M, "button")))
    check("B frames without a whole text (no font string, no GetText, one that throws) are skipped",
          M.count()[0] >= 2, M.count())
    _errors(c, check, "game B")


def game_e(check, p):
    for name, step in (("E", S.faults), ("F", E.guard)):
        c, M = _game(p)
        step(check, M, p)
        errs = [e for e in c.errors() if "stand-in" not in e[1]]
        check(f"game {name}: no other Lua errors", not errs, "; ".join(m[:160] for _, m, _ in errs[:3]))


def mutants(check, p):
    def quiet(name, ok, detail=""): out.append(ok)  # noqa: E704
    for cut, step, run in (("busy", "2", lambda M: S.busy(quiet, M, p)), ("cache", "3", lambda M: S.ticks(quiet, M)),
                           ("fault", "12", lambda M: S.faults(quiet, M, p)), ("place", "13", lambda M: S.place(quiet, M)),
                           ("pinplace", "13", lambda M: S.place(quiet, M)), ("wait", "13", lambda M: S.place(quiet, M)),
                           ("quest", "14", lambda M: S.quest(quiet, M, p)),
                           ("guard", "15", lambda M: E.guard(quiet, M, p)),
                           ("guardshow", "15", lambda M: E.guard(quiet, M, p)),
                           ("guardfont", "15", lambda M: E.guard(quiet, M, p))):
        out = []
        c, M = _game(p, cut=cut)
        ok = run(M)
        check(f"mutant {cut} (the module without that fix, in memory only): step {step} fails",
              M.wasCut and not ok, "cut not found" if not M.wasCut else "it passed" if ok else "")
        del c, M
        gc.collect()


def game_c(check, p):
    c, M = _game(p, "ruRU")
    M.uadd(lua_str("waypointui"))
    check("ruRU client: module off, says why, its texts as they are",
          not M.on() and "клієнт не англійський" in txt(M.lastChat(4)) and S.t(M, "button") == p["button"],
          txt(M.lastChat(2)))
    _errors(c, check, "game C (ruRU)")


def run(check, facts):
    if not module_there():
        return check("UADD_WaypointUI is there", False, "no UADD_WaypointUI/UADD_WaypointUI.toc")
    src = rows()
    if not src:
        check("Waypoint UI checks (skipped: Waypoint UI is not installed)", True, "")
        return halves_mods.wp(check, None, [], halves_mods.SKIP)
    exact, temps = shipped()
    p = picks(src, exact, temps)
    if not p:
        check("our-words checks (skipped: too little Ukrainian shipped yet)", True, len(exact))
        return halves_mods.wp(check, None, [], halves_mods.SKIP)
    check(f"real texts for each step read from the installed Waypoint UI ({p['n']} shipped)", True, "")
    for game in (lambda: game_a(check, p, src, temps), lambda: game_b(check, p), lambda: game_e(check, p),
                 lambda: mutants(check, p), lambda: game_c(check, p)):
        game()
        gc.collect()
    facts["shipped"] = p["n"]


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("wp: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_wp.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
