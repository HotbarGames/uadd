"""TomTom's arrow title and a pin's tooltip title named after a map (the owner saw "Tirisfal Glades" in English).

OpenMap gives TomTom a pin's map name (C_Map.GetMapInfo(mapID).name, English) as the title when the pin has no note.
That is a game name: ours only from ClassicUA or UALL Forever (UADD.UALL.Zone), through the core helper U.Place
(UADD/Place.lua), and only when it is the name of the waypoint's map, the player's map or a map above them. A title
the player typed stays as typed. Made-up maps and zone answers (flow_tomtom_place.lua) keep TomTom's English out.

  * place 1 arrow title: the waypoint's map and its parent are ours; another map's name, a name no source knows and
    a typed note stay as typed; the player's map counts too.
  * place 2 same title: the title set 50 times asks for the name at most once (lesson 12), still ours.
  * place 3 hold key and off: whole English while held and off (also when set again then), ours after.
  * place 4 wait: a "not known yet" answer leaves English and is asked again; ours about 3 s later.
  * place 5 title font: the title keeps a font with Cyrillic letters (lesson 18).
  * place 6 pin tooltip: TomTom's pin tooltip title, the arrow waypoint's map name, is ours; another stays.

`python3 tools/harness/flow_tomtom_place.py --prove`: each mutant (flow_tomtom_place.lua CUTS) takes one fix out of
UADD_TomTom/Module.lua and wants its step to fail.
"""
import collections
import os
import sys

import flow_tomtom
import flow_tomtom_arrow
import loader
from flow_tomtom_texts import module_there, picks, rows, shipped
from loader import lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
LUA = os.path.join(HERE, "flow_tomtom_place.lua")
ZONES = {"Zorpwood Vale": "Зорпова долина", "Blatter Reach": "Блатерський край", "Glorp Hollow": "Глорпова западина"}
NOTE = "My camp spot"
ELSEWHERE = 9999
MUTANTS = [("hook", "tt: place 2"), ("map", "tt: place 1"), ("cache", "tt: place 2"), ("wait", "tt: place 4"),
           ("back", "tt: place 3"), ("tip", "tt: place 6")]

_cut = [None]


class _Client(loader.Client):
    def start(self):
        self.lua.execute(read_text(LUA))
        if _cut[0]:
            self.H.ttp["cut"] = lua_str(_cut[0])
        return super().start()


def _game(p):
    plain = flow_tomtom.Client
    flow_tomtom.Client = _Client
    try:
        return flow_tomtom._game(p)
    finally:
        flow_tomtom.Client = plain


def _run(check, p):
    c, M = _game(p)
    T = c.H.ttp
    c.lua.execute(flow_tomtom_arrow.PROBE.encode("utf-8"))
    A = c.lua.globals().ARROW
    T.maps()
    for en, uk in ZONES.items():
        T.zone(lua_str(en), lua_str(uk))
    T.at(ELSEWHERE)

    def arrow(m, title):
        return txt(T.arrow(m, lua_str(title)) or "")

    def title():
        return txt(T.title() or "")

    # 1
    got = {"vale": arrow(7001, "Zorpwood Vale"), "parent": arrow(7001, "Blatter Reach"),
           "other map": arrow(7001, "Glorp Hollow"), "unknown": arrow(7002, "Fizzle Marsh"),
           "note": arrow(7001, NOTE)}
    T.at(7003)
    got["player's map"] = arrow(7001, "Glorp Hollow")
    T.at(ELSEWHERE)
    want = {"vale": ZONES["Zorpwood Vale"], "parent": ZONES["Blatter Reach"], "other map": "Glorp Hollow",
            "unknown": "Fizzle Marsh", "note": NOTE, "player's map": ZONES["Glorp Hollow"]}
    bad = [f"{k}: {got[k]!r}" for k in want if got[k] != want[k]]
    check("place 1 arrow title: its waypoint's or the player's map name is ours, other titles as typed",
          not bad, "; ".join(bad))
    # 2
    arrow(7001, "Zorpwood Vale")
    asks, shown = T.again(lua_str("Zorpwood Vale"), 50)
    shown = txt(shown or "")
    check("place 2 same title: set 50 times, at most 1 look-up, still ours",
          asks <= 1 and shown == ZONES["Zorpwood Vale"], f"{asks} asks, {shown!r}")
    # 3
    seen = [arrow(7001, "Zorpwood Vale")]
    M.key(True); seen.append(title())
    T.again(lua_str("Zorpwood Vale"), 3); seen.append(title())
    M.key(False); seen.append(title())
    M.uadd("tomtom off"); seen.append(title())
    T.again(lua_str("Zorpwood Vale"), 3); seen.append(title())
    M.uadd("tomtom on"); M.wait(0.2); seen.append(title())
    uk, en = ZONES["Zorpwood Vale"], "Zorpwood Vale"
    check("place 3 hold key and off: English while held and off, ours after",
          seen == [uk, en, en, uk, en, en, uk], " / ".join(seen))
    # 4
    T.wait4(True)
    first = arrow(7002, "Blatter Reach")
    T.wait4(False)
    M.wait(3.5)
    later = title()
    check("place 4 wait: English while not known yet, ours about 3 s later",
          first == "Blatter Reach" and later == ZONES["Blatter Reach"], f"{first!r}, then {later!r}")
    # 5
    ok, info = A.capable()
    M.uadd("tomtom off"); M.uadd("tomtom on"); M.wait(0.2)
    ok2, info2 = A.capable()
    check("place 5 title font: keeps a font with Cyrillic letters", ok and ok2, f"{txt(info)}; {txt(info2)}")
    # 6
    arrow(7001, NOTE)
    tips = {"vale": txt(T.tip(lua_str("Zorpwood Vale")) or ""), "other": txt(T.tip(lua_str("Glorp Hollow")) or "")}
    check("place 6 pin tooltip: the arrow waypoint's map name is ours, another stays",
          tips == {"vale": ZONES["Zorpwood Vale"], "other": "Glorp Hollow"}, repr(tips))
    flow_tomtom._errors(c, check, "place")
    return T


def run(check, facts=None, cut=None):
    if not module_there() or not rows():
        return check("place (skipped: TomTom or UADD_TomTom not there)", True, "")
    exact, temps, keep = shipped()
    p = picks(rows(), exact, temps, keep)
    if not p:
        return check("place (skipped: too little Ukrainian shipped yet)", True, "")
    _cut[0] = cut
    try:
        T = _run(check, p)
    finally:
        _cut[0] = None
    return bool(T.wasCut)


Check = collections.namedtuple("Check", "name ok detail")


def run_checks(cut=None):
    checks = []

    def check(name, ok, detail=""):
        checks.append(Check("tt: " + name, bool(ok), str(detail)))
    was = run(check, {}, cut)
    if cut is None:
        for name, step in MUTANTS:
            sub, cutdone = [], False
            try:
                sub, _ = run_checks(name)
                cutdone = any(x.name == "tt: cut made" and x.ok for x in sub)
                failed = [x.name for x in sub if x.name.startswith(step) and not x.ok]
            except Exception as e:                      # the cut broke the flow: no proof
                failed = [f"flow stopped: {e!r}"[:200]]
            check(f"place mutant {name}: {step[4:]} fails without the fix", cutdone and failed,
                  f"cut {'made' if cutdone else 'NOT made'}; failed: {'; '.join(failed)[:200]}")
    else:
        check("cut made", was)
    return checks, {}


if __name__ == "__main__":
    cs, _ = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
