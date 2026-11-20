"""The steps of flow_wp.py, each on a running game (c, M = flow_wp._game). Expected Ukrainian is the module's
own data (M.want, M.fill); the English is the installed Waypoint UI's (flow_wp_texts.picks)."""
import os
import re
import sys

from loader import lua_str, txt

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402

UNITS = {"1 yds": "1 ярд", "21 yds": "21 ярд", "5 yds": "5 ярдів", "250 m": "250 м", "1.25 km": "1.25 км"}
TIMES = {"1h 5m 3s": "1 год 5 хв 3 с", "5m ": "5 хв", "12s": "12 с"}
ODD = ("1h x", "5 m", "99999999h", "h", "1h  5m", "-3s", "1,2,3 yds", "5 yds ", "yds", "1.2.3 km", "12s\n",
       "1h 5m 3s 4s 5s 6s 7s 8s 9s 10s 11s 12s")
FAKE = "wobbly gizmo"
SPEED_MS = 5


def cyr(s): return re.search("[Ѐ-ӿ]", s or "") is not None  # noqa: E704
def latin(s): return re.search("[A-Za-z]", s or "") is not None  # noqa: E704
def w(M, en): return txt(M.want(lua_str(hashtext.key(en))) or "")  # noqa: E704
def t(M, name): return txt(M.text(lua_str(name)) or "")  # noqa: E704
def put(M, name, v): return txt(M.set(lua_str(name), lua_str(v)) or "")  # noqa: E704


def login(check, M, p):
    ok = all(w(M, en) for en in (p["button"], p["input"], p["grey"]))
    check("1 shipped Ukrainian for the picked texts", ok, "")
    got = {k: t(M, k) for k in ("button", "input", "pin", "info", "nav", "dist", "time")}
    check("1 at login: button and input prompt ours", got["button"] == w(M, p["button"]) and
          got["input"] == w(M, p["input"]), f'{got["button"]!r} {got["input"]!r}')
    check("1 at login: the destination line and the Navigator stay as they are (never looked up)",
          got["info"] == p["info"] and got["nav"] == p["nav"], f'{got["info"]!r} {got["nav"]!r}')
    check("1 at login: distance and arrival time ours", got["dist"] == "12 ярдів" and got["time"] == "12 с",
          f'{got["dist"]!r} {got["time"]!r}')
    check("1 at login: pinpoint name kept, its grey line ours", got["pin"] == "Quix\n" + w(M, p["grey"]),
          repr(got["pin"]))
    check("10 keyboard free after login (lesson 16)", M.focus() is None, str(M.focus()))


def busy(check, M, p):
    f0 = M.fits()
    got = put(M, "button", p["button"])
    fits = M.fits() - f0
    M.key(True)
    held = t(M, "button")
    M.key(False)
    ok = fits == 2 and got == w(M, p["button"]) and held == p["button"] and t(M, "button") == got
    check("2 busy: its SetText of English and ours make 2 fits, no loop; the hold key still gives the English",
          ok, f"fits {fits}, {got!r}, held {held!r}")
    return ok


def ticks(check, M):
    calls, d, tm = M.ticks(50, lua_str("1,234 yds"), lua_str("1h 5m 3s"))
    d, tm = txt(d), txt(tm)
    ok = calls <= 2 and d.startswith("1,234 ") and cyr(d) and not latin(d) and tm == "1 год 5 хв 3 с"
    check("3 footer: 50 ticks with the same two lines cost one look-up each (lesson 12)", ok,
          f"{calls} look-ups; {d!r} {tm!r}")
    return ok


def units(check, M):
    bad = [(en, g) for en, uk in UNITS.items() if (g := put(M, "dist", en)) != uk]
    bad += [(en, g) for en, uk in TIMES.items() if (g := put(M, "time", en)) != uk]
    check("4 distance and time: 1 yds, 21 yds, 250 m, 1.25 km, 1h 5m 3s, 5m, 12s", not bad, bad[:3])
    bad = [(en, g) for en in ODD for which in ("dist", "time")
           if (g := put(M, which, en)) != en and (latin(g) or not cyr(g))]
    check("4 odd distance and time texts: each whole English or whole Ukrainian", not bad, bad[:3])


def prompts(check, M, p):
    if not p["prompts"]:
        return check("5 replace prompts (skipped: none shipped yet)", True, "")
    bad = []
    for tid, en in p["prompts"]:
        want = txt(M.fill(lua_str(tid), lua_str("Quix")) or "")
        if txt(M.prompt(lua_str(en), lua_str("Quix"))) != want or not want:
            bad.append(("Quix", tid))
        g = txt(M.prompt(lua_str(en), lua_str(FAKE)))
        if cyr(g) or FAKE not in g:
            bad.append((FAKE, g))
        cap = p["capital"]
        g = txt(M.prompt(lua_str(en), lua_str(cap)))
        if cap not in g or (g != txt(M.fill(lua_str(tid), lua_str(cap)) or "") and cyr(g)):
            bad.append((cap, g))
    check(f"5 replace prompts ({len(p['prompts'])}): a name ours around it; made-up English in the free slot "
          "keeps it whole English; a name equal to our text stays as typed", not bad, bad[:2])


def pins(check, M, p):
    cap = p["capital"]
    a = put(M, "pin", cap + "\n" + p["grey"])
    b = put(M, "pin", cap)
    c = put(M, "nav", cap)
    check("6 pin name equal to our text stays as typed (lesson 13); the Navigator too",
          a == cap + "\n" + w(M, p["grey"]) and b == cap and c == cap, f"{a!r} {b!r} {c!r}")


def offon(check, M, p):
    put(M, "button", p["button"])
    put(M, "input", p["input"])
    put(M, "time", "12s")
    M.setRaw(lua_str("input"), lua_str("Zorp Blatter"))        # the addon wrote its own text since
    M.uadd(lua_str("waypointui off"))
    off = (t(M, "button"), t(M, "input"), t(M, "time"))
    check("7 off: English back where ours stood; a text the addon changed is left (lessons 15, 23)",
          off == (p["button"], "Zorp Blatter", "12s") and not M.on(), off)
    M.uadd(lua_str("waypointui on"))
    on = (t(M, "button"), t(M, "input"))
    check("7 on: ours again; the addon's own new text left", on == (w(M, p["button"]), "Zorp Blatter"), on)
    put(M, "pin", "Quix\n" + p["grey"])
    M.setRaw(lua_str("pin"), lua_str("Zorp\nBlatter"))
    M.key(True)
    held = (t(M, "button"), t(M, "pin"))
    M.key(False)
    check("7 hold key: English while held, ours after; a text the addon changed is left",
          held == (p["button"], "Zorp\nBlatter") and t(M, "button") == w(M, p["button"]), held)


def fonts(check, M, p):
    def path(which): return (txt(M.font(lua_str(which))[0]) or "").lower()  # noqa: E704
    game = txt(M.gamePath()).lower()
    seen = [x for x in ("footer", "pinpoint", "ui1", "ui2") if M.cyr(lua_str(x))]
    check("8 fonts: its own font objects get the Cyrillic file, read back", len(seen) == 4, seen)
    M.updateFonts(None, lua_str("OUTLINE"), lua_str("THICKOUTLINE"))
    f, pf = M.font(lua_str("footer")), M.font(lua_str("pinpoint"))
    check("8 fonts: its SetFontFlags after ours keeps the Cyrillic file and its outline",
          M.cyr(lua_str("footer")) and txt(f[2]) == "OUTLINE" and txt(pf[2]) == "THICKOUTLINE",
          (txt(f[0]), txt(f[2]), txt(pf[2])))
    n0 = M.chats()
    put(M, "dist", "21 yds")
    M.updateFonts(lua_str(txt(M.CUSTOM)))
    M.updateFonts(lua_str(txt(M.CUSTOM)))
    notes = M.chats() - n0
    check("8 fonts: a font picked in its list keeps English, one chat note",
          not M.cyr(lua_str("footer")) and t(M, "dist") == "21 yds" and notes == 1, (t(M, "dist"), notes))
    M.updateFonts(None)
    check("8 fonts: the game font chosen again: Cyrillic file and ours again",
          M.cyr(lua_str("footer")) and t(M, "dist") == "21 ярд", t(M, "dist"))
    b0 = M.backs
    M.uadd(lua_str("waypointui off"))
    ok = M.backs > b0 and path("footer") == game and t(M, "dist") == "21 yds"
    check("8 fonts: off puts the font back through U.FontBack (lesson 18)", ok, (M.backs - b0, path("footer")))
    M.uadd(lua_str("waypointui on"))
    check("8 fonts: on again: Cyrillic file again", M.cyr(lua_str("footer")) and t(M, "dist") == "21 ярд",
          t(M, "dist"))


def settings(check, M, p):
    M.open()
    M.wait(0.2)
    got = [t(M, f"set{i}") for i in range(1, len(p["settings"]) + 1)]
    check("9 settings built on first show: rows ours, units too, its font Cyrillic",
          got == [w(M, en) for en in p["settings"]] and t(M, "setUnits") == "250 м" and M.cyr(lua_str("ui3")),
          (got[:2], t(M, "setUnits")))
    tab = txt(M.tab(lua_str(p["tab"]), lua_str("tab1")))
    M.wait(1.2)
    check("9 settings: a tab built later is found by the 1 s walk", t(M, "tab1") == w(M, p["tab"]),
          (tab, t(M, "tab1")))
    n0 = M.count()[0]
    M.close()
    M.wait(1.2)
    M.tab(lua_str(p["tab2"]), lua_str("tab2"))
    M.wait(2.2)
    check("9 settings hidden: the walk stops", M.count()[0] == n0 and t(M, "tab2") == p["tab2"],
          (n0, M.count()[0]))
    M.open()
    M.wait(0.2)
    M.uadd(lua_str("waypointui off"))
    n1 = M.count()[0]
    M.tab(lua_str(p["tab"]), lua_str("tab3"))
    M.wait(2.2)
    check("9 settings open, module off: the walk stops", M.count()[0] == n1, (n1, M.count()[0]))
    M.uadd(lua_str("waypointui on"))
    M.close()


def speed(check, M):
    long = ("Zorp blatter quix " * 700)[:10240]
    ms = {"Text": M.slow(lua_str("Text"), lua_str(long)), "Units": M.slow(lua_str("Units"), lua_str("1" * 10240)),
          "Pinpoint": M.slow(lua_str("Pinpoint"), lua_str("Quix\n" + long)),
          "frame": M.slow(lua_str("frame"), lua_str(long))}
    check(f"11 10 KB text under {SPEED_MS} ms on each path (lesson 22)", max(ms.values()) < SPEED_MS,
          {k: round(v, 2) for k, v in ms.items()})


def faults(check, M, p):
    """Lesson 26: its SetText fails before drawing ours (the text stays whole English), then after (ours drawn,
    FitContent fails). 5 errors: off for the session, English back."""
    M.wait(3.5)                                 # past UADD's settle time after login
    M.throw(lua_str("set"))
    a = put(M, "button", p["button"])
    M.throw(lua_str("fit"))
    for _ in range(4):
        put(M, "button", p["button"])
    M.throw(None)
    M.wait(0.3)
    ok = a == p["button"] and not M.on() and t(M, "button") == p["button"] and \
        "вимкнено до кінця сесії" in txt(M.lastChat(4))
    check("12 errors in its SetText: whole English on a fail, off after 5, English back (lessons 19, 26)", ok,
          (a, M.on(), t(M, "button"), txt(M.lastChat(1))[:80]))
    return ok
