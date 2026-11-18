"""UADD_OpenMap on lines OpenMap builds from L's words (ours) and its own parts, on the stand-in
(tools/harness/openmap/Built.lua): the News title with its version, the note and pin editors'
titles, a row of the pin list and the dock's tooltip, each with a zone name the game gives in English.

With a zone UALL saved, each line is whole Ukrainian (the version and the player's note kept as they
are); with one nobody saved, whole English; the hold key gives OpenMap's English back. The player's
own note stays exactly as written in the pin list row and the pin tooltips, on, held and off. Then the World
Map's hover label (flow_openmap_label.py). Called from flow_openmap.in_game; the Lua helpers are in flow_openmap.lua.
"""
import re

import flow_openmap_label
from loader import lua_str, txt

ZONE, NOWHERE = "Razorfen Kraul", "Zorp Blatter"   # a zone the journal saved; a made-up one
CYR = re.compile("[Ѐ-ӿ]")
HELD = 0.3


def _texts(M, s, version, zone):
    M.built(lua_str(version), lua_str(zone))
    M.wait(1.2)                          # the next look finds the new windows and hooks their texts
    M.built(lua_str(version), lua_str(zone))   # OpenMap sets them again: through the hook
    s.pump(5)
    return {txt(k): txt(v) for k, v in M.builtTexts().items()}


def _want(L, zone, version="v0.8.9"):
    pin = "%s · %s  45.2, 30.1  |cff99ccff%s|r" % (L("Map pin"), zone, L("Shared by %s").replace("%s", "Quix"))
    top = L("What's new in OpenMap")
    return {"top": f"{top}  |cff998866{version}|r",
            "new": f"{L('New note')} · {zone}", "old": f"{L('Note')} #3 · {zone}", "pin": pin,
            "row": f"{zone} · |cffffffffmy note|r |cffe6c27a({L('drawing')})|r |cff80f070({L('followed')})|r"}


def run(s, M, check):
    L = lambda k: txt(M.L(lua_str(k)))  # noqa: E731
    zone_uk = txt(M.cached("zones", ZONE))
    got = _texts(M, s, "v0.8.9", ZONE)
    want = _want(L, zone_uk)
    check("built lines: News title with its version, note and pin titles, pin row all Ukrainian",
          zone_uk and got == want and not any(ZONE in v for v in got.values()), {"got": got, "want": want})
    dev = _texts(M, s, "dev", ZONE)["top"]
    check("built lines: the News title with a checkout's \"dev\" stays Ukrainian", dev == _want(L, zone_uk, "dev")["top"], dev)

    _texts(M, s, "v0.8.9", ZONE)
    M.key(True)
    M.wait(HELD)
    held = {txt(k): txt(v) for k, v in M.builtTexts().items()}
    M.key(False)
    M.wait(0.1)
    en = _want(lambda k: k, ZONE)
    check("built lines, hold key: OpenMap's English back, whole", held == en, {"got": held, "want": en})
    back = {txt(k): txt(v) for k, v in M.builtTexts().items()}
    check("built lines, hold key released: Ukrainian again", back == want, back)

    odd = _texts(M, s, "v0.8.9", NOWHERE)
    mixed = [v for k, v in odd.items() if k != "top" and CYR.search(v)]
    check("built lines, a zone nobody saved: whole English, never half", not mixed and odd["top"] == want["top"], odd)

    tip = txt(M.dockTip(lua_str(ZONE)))
    check("dock tooltip: L[\"To\"] and the zone, all Ukrainian", tip == f"{L('To')} {zone_uk}", tip)
    tip = txt(M.dockTip(lua_str(NOWHERE)))
    check("dock tooltip, a zone nobody saved: whole English", tip == f"To {NOWHERE}", tip)
    _notes(s, M, check)
    M.closeBuilt()
    flow_openmap_label.run(s, M, check)   # the World Map's hover label: OpenMap's levels and fishing


# Notes a player might write (or get from another player): our words, English, names, a long one.
NOTES = ("малюнок", "Нотатка", "Поділився: Вася", "Скриня біля Orgrimmar", "Квест на Level 20",
         "Нотатка for raid", "Позначка Hogger", "my note Orgrimmar", "ж" * 80)


def _note_lines(s, M, note):
    """The note as the pin list row and both pin tooltips show it: [(where, what is shown)]."""
    M.built(lua_str("v0.8.9"), lua_str(ZONE), lua_str(note))
    s.pump(5)
    row = txt(M.builtTexts()["row"])
    got = [("row", row.split(" · ", 1)[-1].split("|r", 1)[0] + "|r")]
    for how in ("data", "pin"):
        got.append((how + " tip", txt(M.pinTip(lua_str(note), lua_str(ZONE), how)[1])))
    return got


def _notes(s, M, check):
    """The player's own text is never changed: in the pin list row and the pin tooltips, on and off."""
    bad = []
    for state in ("on", "held", "off"):
        if state == "held":
            M.key(True)
            M.wait(HELD)
        if state == "off":
            s.uadd("openmap off")
        for note in NOTES:
            want = {"row": f"|cffffffff{note}|r", "data tip": note, "pin tip": note}
            bad += [(state, where, note, shown) for where, shown in _note_lines(s, M, note) if shown != want[where]]
        if state == "held":
            M.key(False)
            M.wait(0.1)
    s.uadd("openmap on")
    check(f"player text untouched: {len(NOTES)} notes in the pin row and pin tooltips, on, held and off",
          not bad, bad[:4] or "all as written")
