"""The steps of flow_gq.py: each (check, g) -> ok, g a flow_gq.Run (g.E its English, g.A0 / g.A ours before and
after the retry, g.ref: its chat lines, late window and guide pages). No English of GearQuest here."""
from flow_pawn_game import cyr, diff
from loader import lua_str, txt

SLOT = "L.7c864557"


def _fonts(M, tag):
    return [(tag, txt(x)) for x in M.fonts().values()]


def ours(check, g):
    A, E = g.A, g.E
    slot = g.ref["en"][SLOT]
    words = [k for k in A if k[:2] in ("W:", "G:", "T:") and not cyr(A[k])]
    words += [k for k in ("R:1", "R:2", "R:4", "R:5") if not cyr(A.get(k))]
    names = [k for k in ("R:4",) if slot not in (A.get(k) or "")]
    if "Zorpa" not in (A.get("R:1") or ""):
        names.append("R:1")
    ok = set(A) == set(E) and not words and not names and A.get("R:3") == E.get("R:3")
    check("1 ours: labels, option labels, tabs, guide page, Orders headers and rows, source tag, spec name; "
          "the names as typed (lesson 13); an unknown item's row whole English", ok,
          (sorted(set(A) ^ set(E))[:3], words[:4], names, A.get("R:3") == E.get("R:3")))
    return ok


def guide(check, g):
    M, pages, nouk = g.M, g.ref["pages"], g.ref["nouk"]
    M.guide(nouk)
    two, fit2 = txt(M.snap()["G:now"]), bool(M.bubbleOk())
    M.guide(g.ref["uk"])
    seven, fit7 = txt(M.snap()["G:now"]), bool(M.bubbleOk())
    M.guide(1)
    one = txt(M.snap()["G:now"])
    ok = two == pages[nouk - 1] and cyr(seven) and fit2 and fit7 and one == g.A["G:now"]
    check("2 guide: a page with no Ukrainian whole English, one with it ours, the bubble fits each, back to page 1",
          ok, (two == pages[nouk - 1], cyr(seven), fit2, fit7, one == g.A["G:now"]))
    return ok


def chat(check, g):
    M, want = g.M, g.ref["chat"]
    got = [txt(M.nohunts(lua_str(s), p)) for s, p in (("head", False), ("head", True), ("feet", False))]
    M.key(True)
    held = txt(M.nohunts(lua_str("head"), False))
    M.key(False)
    ok = cyr(got[0]) and cyr(got[1]) and got[2] == want[2] and held == want[0]
    check("3 chat line: a known slot ours, the preview ours; an unknown slot and held whole English", ok,
          (cyr(got[0]), cyr(got[1]), got[2] == want[2], held == want[0]))
    return ok


def rows(check, g):
    A0, A, E = g.A0, g.A, g.E
    ok = (A0.get("R:5") == E.get("R:5") and cyr(A.get("R:5")) and cyr(A.get("R:2")) and A.get("R:3") == E.get("R:3")
          and cyr(A.get("R:1")))
    check("4 Orders rows: an item not settled yet English, ours on the retry; a known one ours, an unknown one "
          "English; the header ours", ok, (A0.get("R:5") == E.get("R:5"), cyr(A.get("R:5")), cyr(A.get("R:2")),
                                           A.get("R:3") == E.get("R:3"), cyr(A.get("R:1"))))
    return ok


def fonts(check, g):
    M = g.M
    bad = _fonts(M, "on")
    M.key(True)
    bad += _fonts(M, "held")
    M.key(False)
    M.uadd("gq off")
    bad += _fonts(M, "off")
    M.uadd("gq on")
    bad += _fonts(M, "on again")
    check("5 our font on every Cyrillic text and on no other, no box on screen: on, held, off, on", not bad, bad[:4])
    return not bad


def loop(check, g):
    M, bad = g.M, []
    for i in range(3):
        for how, want in (("hold", g.E), ("release", g.A), ("off", g.E), ("on", g.A)):
            if how in ("hold", "release"):
                M.key(how == "hold")
            else:
                M.uadd("gq " + how)
            d, f = diff(want, snap(M)), _fonts(M, how)
            if d or f:
                bad.append((i + 1, how, d[:3], f[:2]))
    check("6 hold key, off, on (x3): English exactly, then ours exactly, fonts with them", not bad, bad[:3])
    return not bad


def late(check, g):
    M, want = g.M, g.ref["late"]
    M.late()
    got, bad = {}, []
    for how in ("on", "hold", "release", "off", "on"):
        if how in ("hold", "release"):
            M.key(how == "hold")
        elif how == "off" or got:
            M.uadd("gq " + how)
        got = {k: v for k, v in snap(M).items() if k.startswith("L:")}
        english = how in ("hold", "off")
        if set(got) != set(want) or (got != want if english else not all(cyr(v) for v in got.values())):
            bad.append((how, sorted(got)[:2]))
        bad += [x for x in _fonts(M, how) if x[1].startswith("L:")]
    check("7 a window made late: ours, English held and off, ours again", not bad, bad[:3])
    return not bad


def status(check, g):
    g.M.uadd("gq")
    lines = g.c.chat()[-5:]
    ok = any("увімкнено" in x for x in lines)
    check("8 /uadd gq: on", ok, lines[-3:])
    return ok


STEPS = [ours, guide, chat, rows, fonts, loop, late, status]


def language(check, g, langs):
    """Its saved language ukUA; the Languages addon absent (None), there and on, there but off."""
    M, A = g.M, g.A
    choices, lang = txt(M.choices()).split(","), txt(M.lang())
    f = _fonts(M, "on")
    if langs == "off":
        ok = choices == ["enUS"] and lang == "" and cyr(A.get("W:lbl1"))
    else:
        ok = "ukUA" in choices and cyr(lang) and cyr(A.get("W:lbl1"))
    M.key(True)
    held = snap(M).get("W:lbl1") == g.E.get("W:lbl1")
    M.key(False)
    ok = ok and not f and held
    check("L%s language list: ukUA saved, Languages addon %s: %s; our words; English held; no box" % (
        {None: 1, "on": 2, "off": 3}[langs], langs or "absent", "not listed" if langs == "off" else "listed, shown"),
        ok, (choices, cyr(lang), cyr(A.get("W:lbl1")), held, f[:2]))
    return ok


def typed(check, g):
    """Game C: off at login (whole English), then on: ours, the typed name kept."""
    M, slot = g.M, g.ref["en"][SLOT]
    was = g.A.get("W:lbl1") == g.E.get("W:lbl1") and g.A.get("R:4") == g.E.get("R:4")
    M.uadd("gq on")
    now = snap(M)
    f = _fonts(M, "C")                   # a Lua table is always true in Python: count its entries
    ok = was and cyr(now.get("W:lbl1")) and cyr(now.get("R:4")) and slot in (now.get("R:4") or "") and not f
    check("C off at login English; then on: ours, the typed name in an Orders header kept (lesson 13), no box", ok,
          (was, cyr(now.get("W:lbl1")), cyr(now.get("R:4")), slot in (now.get("R:4") or ""), f[:2]))
    return ok


def news(check, G, N, T):
    """Lesson 43: no text that only its news files show is in our data."""
    a = G.addon_dir()
    files = [p for p in G.code_files(a) if N.is_news(p.relative_to(a).as_posix())]
    bad = [r[0] for r in G.source(a)[0] if N.news_only(r[3]) and r[0] in T]
    check("N news: no news-only text in our data (lesson 43)", not bad, (len(files), bad[:3]))
    return not bad


def snap(M):
    return {txt(k): txt(v) for k, v in M.snap().items()}
