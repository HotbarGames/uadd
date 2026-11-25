"""UADD_TomTom on a stand-in for TomTom (tools/harness/tomtom). TomTom is All Rights Reserved: the stand-in
holds none of its English. This flow reads the texts from the installed TomTom (flow_tomtom_texts.py) and
gives them to the stand-in before the game starts. The expected Ukrainian is the module's own data (ns.TT,
read by M.want and M.fill in flow_tomtom.lua); texts are picked from what is shipped.

  * Game A (English client): stand-in, UADD, UADD_TomTom. 1 TomTom.L: ours; off and the hold key give the
    English back; the slash-command keys and TomTom's name stay English. 2 Settings built at login: page,
    rows, tooltip, dropdown entry, button ours; off gives English dropdowns. 3 Pop-ups: ours, English when
    off. 4 Chat: Printf and a plain line with a plural and a zone (UALL name: all ours; none: all English).
    5 Pin tooltip: the distance line ours, also when written again; the coordinates line never half.
    6 Arrow status: plurals for 1, 2, 5, 21, under 5 ms a call. 7 Fonts read back, also in the paste window
    made on first open and a settings page made late. 8 No half-translated line. Review fixes (lesson 12):
    flow_tomtom_review.py.
  * Mutant game: Fonts.lua without its late-window code (cut in memory only): the paste window check must
    fail, so step 7 has teeth.
  * Game C (ruRU client): the module does nothing and says why.
"""
import collections
import gc
import os
import re
import sys

import clock
import flow_tomtom_review
import halves_mods
import session
from flow_tomtom_texts import MODULE, module_there, picks, rows, shipped, templates

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
PREFIX = "|cFF33FF99TomTom|r: "
ZONE, ZONE_UK, NOZONE = "Quixwood Vale", "Долина Квіксвуд", "Glimmerfen Hollow"
STATUS_MS = 5
SPEED_N = 2000


def _game(p, locale="enUS", cut=False, pre=None):
    addons = [Addon("TomTom", os.path.join(HERE, "tomtom"), session.FLAVOR)]
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD", MODULE)]
    c = Client(addons, None, locale)
    c.lua.execute(read_text(os.path.join(HERE, "flow_tomtom.lua")))
    for name in pre or ():                       # more stand-ins before the game starts (menu_compositor.lua)
        c.lua.execute(read_text(os.path.join(HERE, name)))
    M = c.H.tt
    M.cut = cut
    if cut:
        c.H.boxQuiet = True                      # the mutant's boxes are wanted (its late window), not reported
    for en in {p["L"], p["option"], *p["stay"],
               *(p[k] for k in ("dist", "dist_s", "coords", "removed", "local", "added", "unknown") if p[k]),
               *(p[k] for k in ("late_page", "late_row", "paste_title", "paste_button")),
               *(p[k] for k in ("page", "row", "tip", "text", "label", "button", "color", "colorTip")),
               *(en for f in p["popups"].values() for en in f.values())}:
        M.feedL(lua_str(en))
    for k in ("page", "row", "tip", "text", "label", "button", "color", "colorTip"):
        M.feed("settings", k, lua_str(p[k]))
    M.feed("settings", "option", lua_str(p["option"]))
    M.feed("late", "page", lua_str(p["late_page"]))
    M.feed("late", "row", lua_str(p["late_row"]))
    M.feed("paste", "title", lua_str(p["paste_title"]))
    M.feed("paste", "button", lua_str(p["paste_button"]))
    for which, f in p["popups"].items():
        for field, en in f.items():
            M.feedPopup(which, field, lua_str(en))
    c.start()
    c.H.pump(60)
    return c, M


def _errors(c, check, step):
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def _w(M, en):
    return txt(M.want(lua_str(hashtext.key(en))) or "")


def _fill(M, tid, *v):
    return txt(M.fill(lua_str(tid), *(lua_str(str(x)) for x in v)) or "")


def _cyr_only(s):
    return not re.search(r"[A-Za-z]{3,}", re.sub(r"\|c\w{8}|\|r|TomTom", "", s))


def _swap(check, M, p):
    en = p["L"]
    check("1 TomTom.L: ours", txt(M.L(lua_str(en))) == _w(M, en) != en, txt(M.L(lua_str(en))))
    bad = [k for k in p["stay"] if txt(M.L(lua_str(k)) or k) != k]
    check(f"1 TomTom.L: {len(p['stay'])} slash-command keys and TomTom's name stay English", not bad, bad[:3])
    M.key(True)
    down = txt(M.L(lua_str(en)))
    M.key(False)
    check("1 hold key: TomTom.L English, ours again on key up",
          down == en and txt(M.L(lua_str(en))) == _w(M, en), down)


def _settings(check, M, p):
    texts, fonts, name, tip, opt = M.page()
    texts, fonts = {txt(k): txt(v) for k, v in texts.items()}, dict(fonts.items())
    want = {"row": _w(M, p["row"]), "text": _w(M, p["text"]), "button": _w(M, p["label"]),
            "button:button": _w(M, p["button"]), "color": _w(M, p["color"])}
    bad = {k: texts.get(k) for k in want if texts.get(k) != want[k]}
    check("2 settings built at login: rows, a text, a button ours", not bad, list(bad.items())[:3])
    check("2 settings: page name, tooltip, dropdown entry ours",
          (txt(name), txt(tip), txt(opt)) == (_w(M, p["page"]), _w(M, p["tip"]), _w(M, p["option"])),
          (txt(name), txt(tip), txt(opt)))
    badf = [k for k in want if not fonts.get(k)]
    check("7 fonts: settings rows read back in our font (rows the list makes)", not badf, badf)


def _popups(check, M, p):
    if not p["popups"]:
        return check("3 pop-ups (skipped: none fully shipped)", True, "")
    ok = all(txt(M.popupField(w, k)) == _w(M, en) for w, f in p["popups"].items() for k, en in f.items())
    text, cyr = M.popup(next(iter(p["popups"])))
    check(f"3 pop-ups: {len(p['popups'])} ours (text and buttons), shown in our font", ok and cyr, txt(text))


def _chat(check, M, p):
    if not p["removed"]:
        return check("4 chat (skipped: the plural-and-zone line is not shipped)", True, "")
    en = p["removed"]
    got = [txt(M.printf(lua_str(en), n, lua_str(ZONE))) for n in (1, 5)]
    want = [PREFIX + _fill(M, hashtext.key(en), n, ZONE_UK) for n in (1, 5)]
    check("4 chat, Printf line: plural and a UALL zone, all ours", got == want, got)
    got = txt(M.chat(lua_str(en), 2, lua_str(ZONE)))
    check("4 chat, plain line: plural and a UALL zone, all ours", got == _fill(M, hashtext.key(en), 2, ZONE_UK), got)
    got = [txt(M.printf(lua_str(en), 2, lua_str(NOZONE))), txt(M.chat(lua_str(en), 2, lua_str(NOZONE)))]
    check("4 chat: a zone UALL lacks leaves the whole line English",
          got == [PREFIX + en % (2, NOZONE), en % (2, NOZONE)], got)


XY = "41.50, 22.25"


def _touching(check, M, p):
    """Lines whose slots touch: /way local (indent, title) and the "added a waypoint" line (title, " - ",
    coords: one group, tools/tt_rules.py GROUPS)."""
    if p["local"] and p["unknown"]:
        en, unknown = p["local"], txt(M.L(lua_str(p["unknown"])))
        got = txt(M.printf(lua_str(en), lua_str("   "), lua_str(unknown), lua_str(XY), 7))
        check("4 chat, /way local with no title: TomTom.L keeps it English, the line all English",
              txt(M.L(lua_str(en))) == en and got == PREFIX + en % ("   ", unknown, XY, 7), got)
        got = txt(M.printf(lua_str(en), lua_str("   "), lua_str("Quix"), lua_str(XY), 7))
        check("4 chat, /way local with a title: all ours, the title as it is",
              got == PREFIX + _fill(M, hashtext.key(en), "   ", "Quix", XY, 7), got)
    if not p["added"]:
        return check("4 chat, added line (skipped: not shipped)", True, "")
    en, k = p["added"], hashtext.key(p["added"])
    cases = [(("Quix", " - ", XY, ZONE), _fill(M, k, "Quix", " - ", XY, ZONE_UK)),
             (("", "", XY, ZONE), _fill(M, k, "", "", XY, ZONE_UK)),
             (("Quix - Home", " - ", XY, ZONE), None), (("my spot", " - ", XY, ZONE), None),
             (("Quix", " - ", XY, NOZONE), None)]
    bad = []
    for v, want in cases:
        got = txt(M.chat(lua_str(en), *(lua_str(x) for x in v)))
        if got != (want or en % v):
            bad.append((v[0], v[3], got))
    check("4 chat, added line: a title or none ours; a title with \" - \", a phrase or a zone UALL lacks English",
          not bad, bad[:2])


def _tooltip(check, M, p):
    if not (p["dist"] and p["dist_s"]):
        return check("5 tooltip (skipped: distance texts not shipped)", True, "")
    a, ac, b, _ = M.pin(lua_str("Quix"), lua_str(p["dist"]), 21, lua_str(p["coords"]), lua_str(ZONE), 41.5, 22.25)
    eng = p["coords"] % (ZONE, 41.5, 22.25)
    check("5 tooltip: the distance line ours, in our font", (txt(a), ac) == (_fill(M, hashtext.key(p["dist"]), 21), True),
          txt(a))
    check("5 tooltip: coordinates line ours, with UALL's zone", txt(b) == f"{ZONE_UK} (41.50, 22.25)", txt(b))
    _, _, b, _ = M.pin(lua_str("Quix"), lua_str(p["dist"]), 21, lua_str(p["coords"]), lua_str(NOZONE), 41.5, 22.25)
    check("5 tooltip: coordinates line with a zone UALL lacks stays English",
          txt(b) == p["coords"] % (NOZONE, 41.5, 22.25), txt(b))
    del eng
    a, _ = M.pinUpdate(lua_str(p["dist_s"]), lua_str("17"))
    want = txt(M.L(lua_str(p["dist_s"]))).replace("%s", "17")
    check("5 tooltip: the line written again (SetFormattedText) ours", txt(a) == want != p["dist_s"] % "17", txt(a))


def _arrow(check, M, p, facts):
    if not p["dist"]:
        return check("6 arrow (skipped: distance text not shipped)", True, "")
    got = {n: M.status(lua_str(p["dist"]), n) for n in (1, 2, 5, 21)}
    bad = {n: txt(t) for n, (t, cyr) in got.items() if (txt(t), cyr) != (_fill(M, hashtext.key(p["dist"]), n), True)}
    check("6 arrow status: plurals for 1, 2, 5, 21 ours, in our font", not bad, bad)
    facts["arrow"] = {n: txt(t) for n, (t, _) in got.items()}      # docs/TESTING.md step 100
    avg, worst = M.statusSpeed(lua_str(p["dist"]), SPEED_N)
    facts["status_ms"] = round(avg, 4)
    limit, ref = clock.bound(STATUS_MS)          # stretched by the load seen now, as the 0.5 ms average
    check(f"6 arrow status: {SPEED_N} calls, each well under {STATUS_MS} ms", worst < limit and avg * 10 < limit,
          f"avg {avg:.4f} ms, worst {worst:.3f} ms, {clock.note(limit, ref)}")


def _late(M, p):
    title, tc, button, bc = M.paste()
    first = (txt(title), tc, txt(button), bc) == (_w(M, p["paste_title"]), True, _w(M, p["paste_button"]), True)
    title, tc = M.repaste(lua_str(p["paste_title"]))
    return first and (txt(title), tc) == (_w(M, p["paste_title"]), True), (txt(title), tc, txt(button), bc)


def _off(check, M, p):
    M.uadd("tomtom off")
    pop = [txt(M.popupField(w, k)) == en for w, f in p["popups"].items() for k, en in f.items()]
    check("1-3 /uadd tomtom off: TomTom.L, dropdowns and pop-ups English",
          txt(M.L(lua_str(p["L"]))) == p["L"] and txt(M.options()) == p["option"] and all(pop),
          (txt(M.L(lua_str(p["L"]))), txt(M.options())))
    M.uadd("tomtom on")
    check("1 /uadd tomtom on: ours again", txt(M.L(lua_str(p["L"]))) == _w(M, p["L"]), "")


def game_a(check, facts, p, src, temps):
    c, M = _game(p)
    check("module on after login", M.loaded() and M.on(), "")
    M.names(lua_str(ZONE), lua_str(ZONE_UK))
    _swap(check, M, p)
    _settings(check, M, p)
    _popups(check, M, p)
    _chat(check, M, p)
    _touching(check, M, p)
    _tooltip(check, M, p)
    _arrow(check, M, p, facts)
    ok, got = _late(M, p)
    check("7 late window: the paste window made on first open, ours in our font (also shown again)", ok, got)
    texts, fonts, _, _, _ = M.latePage()
    check("7 late settings page (made after login): its row ours, in our font",
          (txt(texts["row"]), fonts["row"]) == (_w(M, p["late_row"]), True), txt(texts["row"]))
    _off(check, M, p)
    flow_tomtom_review.run(check, M, p)
    facts["words"], facts["fonts"], facts["picked_from"] = int(M.count()), int(M.fontCount()), p["n"]
    M.uadd("tomtom")
    check("status: on, with counts", "увімкнено: TomTom українською" in txt(M.lastChat(4)), txt(M.lastChat(2)))
    M.names(lua_str(halves_mods.NAME), lua_str("Квікс"))
    tps = templates(src, temps, p["t_good"], halves_mods.NAME)
    halves_mods.tomtom(check, M, tps, "" if tps else "skipped: no Ukrainian templates shipped yet")
    _errors(c, check, "game A")


def game_mutant(check, p):
    c, M = _game(p, cut=True)
    ok, got = _late(M, p)
    check("7 mutant (Fonts.lua without its late-window code, in memory only): the late-window check fails",
          M.wasCut and not ok, "late code not found in Fonts.lua" if not M.wasCut else got)


def game_c(check, p):
    c, M = _game(p, "ruRU")
    M.uadd("tomtom")
    check("ruRU client: module off, says why, TomTom.L as it is",
          not M.on() and "клієнт не англійський" in txt(M.lastChat(4)) and txt(M.L(lua_str(p["L"]))) == p["L"],
          txt(M.lastChat(2)))
    _errors(c, check, "game C (ruRU)")


def run(check, facts):
    if not module_there():
        return check("UADD_TomTom is there", False, "no UADD_TomTom/UADD_TomTom.toc")
    src = rows()
    if not src:
        check("TomTom checks (skipped: TomTom is not installed)", True, "")
        return halves_mods.tomtom(check, None, [], halves_mods.SKIP)
    exact, temps, keep = shipped()
    p = picks(src, exact, temps, keep)
    if not p:
        check("our-words checks (skipped: too little Ukrainian shipped yet)", True, len(src))
        return halves_mods.tomtom(check, None, [], halves_mods.SKIP)
    check(f"real texts for each step read from the installed TomTom ({p['n']} shipped)", True, "")
    game_a(check, facts, p, src, temps)
    gc.collect()
    game_mutant(check, p)
    gc.collect()
    game_c(check, p)


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("tt: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_tomtom.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
