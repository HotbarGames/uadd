"""Step 9 of flow_wtw.py (UADD_WhatTheWhisper, Lines.lua), on game A after login: the zone alert in chat, the export
window's title for a group thread, the icon picker open while the words switch. Its cuts go into CUTS of
flow_wtw_steps.py. The addon's English is read from the installed addon (wtw_source), the zones are made up."""
import hashtext
import wtw_source as G
from flow_pawn_game import cyr
from loader import lua_str, txt

ZONE = "26a34d4a"
STEP_ZONE = ("9 the zone alert: ours with a known zone (also a nickname that holds the template's words); no name, "
             "not known yet, a route that throws, odd text, held and off: whole English; off: its own Print")
STEP_WIN = ("9 the export title of a group thread and the open icon picker: ours, English held and off, ours again; "
            "a player's and a channel's name and the saved name as they are")
EN_ZONE, UA_ZONE = "Wobbly Vale", "Хитка долина"


def key():
    return next(r[1] for r in G.source(G.addon_dir())[0] if r[0] == "L." + ZONE)


def zone(check, c, M, E, A):
    en = key()
    mid = hashtext.tokens(en)[1][1]
    M.zones[lua_str(EN_ZONE)] = lua_str(UA_ZONE)
    bad = []

    def want(tag, name, z, ours):
        t = txt(M.alert(lua_str(en), lua_str(name), lua_str(z)))
        full = txt(M.english(lua_str(en), lua_str(name), lua_str(z)))
        ok = (t != full and cyr(t) and name in t and UA_ZONE in t and z not in t) if ours else t == full
        if not ok:
            bad.append((tag, t))

    M.zoneStub(None)
    want("known", "Zorp", EN_ZONE, True)
    want("nickname with the words", "Al" + mid + "Bo", EN_ZONE, True)
    want("percent in a name", "50%d", EN_ZONE, True)
    want("unknown", "Zorp", "Grommit Flats", False)
    want("brackets", "Zorp", EN_ZONE + " (1-10)", False)
    asked = int(M.nAsked())
    other = txt(M.print(lua_str("wobbly gizmo.")))
    two = txt(M.print(lua_str("wobbly"), lua_str("gizmo")))
    free = int(M.nAsked()) == asked and (other, two) == ("wobbly gizmo.", "wobbly gizmo")
    M.zoneStub(lua_str("wait"))
    want("wait", "Zorp", EN_ZONE, False)
    M.zoneStub(lua_str("error"))
    want("error", "Zorp", EN_ZONE, False)
    M.zoneStub(None)
    M.key(True)
    want("held", "Zorp", EN_ZONE, False)
    M.key(False)
    want("released", "Zorp", EN_ZONE, True)
    M.uadd("wtw off")
    want("off", "Zorp", EN_ZONE, False)
    own = bool(M.printIsOwn())
    M.uadd("wtw on")
    want("on", "Zorp", EN_ZONE, True)
    M.zoneBack()
    ok = not bad and free and own
    check(STEP_ZONE, ok, (bad[:3], free, (other, two), own))
    return ok


def windows(check, c, M, E, A):
    fields = ("title", "hint", "empty", "reset")
    en = {f: txt(M.feedKey(lua_str(f))) for f in fields + ("export",)}
    eng = {f: en[f] for f in fields}
    eng["hint"] = en["hint"].replace("%s", "Zorp")

    def now():
        return {txt(k): txt(v) for k, v in M.windows().items()}

    bad = []
    M.icon(lua_str("Zorp"))
    M.export(lua_str("CH:PARTY"), lua_str("Party"))
    eng["export"] = en["export"] + " · Party"
    ours = now()
    if any(not cyr(ours[f]) or ours[f] == eng[f] for f in eng) or "Zorp" not in ours["hint"] or "Party" in ours["export"]:
        bad.append(("ours", ours))
    for how, want in (("hold", eng), ("release", ours), ("off", eng), ("on", ours)):
        M.key(how == "hold") if how in ("hold", "release") else M.uadd("wtw " + how)
        M.wait(0.2)
        if now() != want:
            bad.append((how, {k: v for k, v in now().items() if v != want[k]}))
    for tid, name in (("Zorp-Realm", "Party"), ("CH:C:Party", "Party")):     # a player, a channel: kept
        M.export(lua_str(tid), lua_str(name))
        t = now()["export"]
        if not t.endswith(" · Party") or not cyr(t):
            bad.append((tid, t))
    M.hideWindows()
    ok = not bad
    check(STEP_WIN, ok, bad[:3])
    return ok


CUTS = {
    "lnprint": ("Lines.lua", "    a.Print = fn\n", "", zone),
    "lnlast": ("Lines.lua", "        first, last, from = s, e, e + 1\n", "        first, last = s, e break\n", zone),
    "lnwait": ("Lines.lua", "    if not ok or wait or type(ua)", "    if not ok or type(ua)", zone),
    "lnoff": ("Lines.lua", "        a.Print = prints.orig\n", "", zone),
    "lntitle": ("Lines.lua", "    if now and now ~= was then d.title:SetText(now) end\n", "", windows),
    "lnicons": ("Lines.lua", "    Hint(d.hint)\n", "", windows),
    "lnrefresh": ("Module.lua", "    U.SafeCall(ns.Lines.Refresh)\n", "", windows),
}
