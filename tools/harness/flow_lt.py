"""UADD_LootTriage on a stand-in for LootTriage (tools/harness/loottriage). Its English may not be copied here (no
licence): the stand-in draws its shapes (tooltip lines from its own file, chat, its nameless settings window with a
dropdown, the loot window's Delete button, What's New, its Settings panel row) and gets the installed addon's English
at run time (feed(), from tools/lt_source.py).

  * Game E (no module): its English: what "off" and the hold key must give back.
  * Game A: 1 its window ours, each Cyrillic text in our font. 2 its tooltip lines: whole Ukrainian or whole
    English. 3 a quest line after a line of ours, by UALL's quest name; an unknown one stays English. 4 lines that
    are not its own cost no Translate, no Hash, no cache. 5 hold key: English; release: ours. 6 off: all English as
    in game E, on: ours. 7 a text it renamed itself is left as it is on off (lesson 23). 8 its dropdown's choices:
    ours with the same values, its own function back when off. 9 the Settings panel row both ways. 10 What's New
    stays its English (lesson 43), from both buttons, on, held and off. 11 its chat and help lines. 12 five errors in its hooks: off, the
    English back (lesson 19); on: ours again. 13 status. 16 the game's word on its two New buttons: ours in our
    font (also through its hover), English on the hold key and off, the global never written, one already
    Cyrillic left. No half line (halves_mods.lt).
  * Game B (no LootTriage): "/uadd lt" says it waits.
"""
import os
import sys

import halves_mods
import session
from flow_pawn_game import cyr, diff as _diff, errors

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import lt_rules as R  # noqa: E402
import lt_source as G  # noqa: E402
import news_texts as N  # noqa: E402
from flow import Check  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE, TARGET = "UADD_LootTriage", "LootTriage"
PREFIX = "|cff33ff99LootTriage|r: "
TIPS = ("Tooltip.lua", "Loot.lua")
WIN = ("Settings.lua", "SettingsWindow.lua")
CHOICES = ("Code.2a01e32d", "Code.345f502a", "Code.5cc4fa39")
PANEL = ("Code.9c2202f0", "Code.7c8a4b57", "Code.775f1a16")
CHAT = ("Code.677e69f9", "Code.21e9e085", "Code.01721026", "Code.5116e3ec", "Code.0c4d453c")
HELP = ("Code.7dc3363b", "Code.4a6c5645", "Code.6871896a", "Code.6eae7f9c", "Code.67046501", "Code.44367bc2",
        "Code.9d6152b4")
MONEY = "12|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"


def installed():
    d = G.addon_dir()
    return bool(d) and os.path.isfile(os.path.join(str(d), G.TOC))


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def diff(a, b):
    return str(_diff(a, b))


def rows():
    return G.source(G.addon_dir())[0] if installed() else []


def english():
    return {r[0]: r[1] for r in rows()}


def _q(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r") + '"'


def news_lines():
    """The What's New dialog's lines, read from the installed addon's own file at run time (no row of ours has
    them: lt_source drops them, lesson 43)."""
    out, seen = [], set()
    for f in G.files(G.addon_dir()):
        if not N.is_news(f):
            continue
        for v, _, why, _ in G.literals(G.addon_dir() / f):
            k = "Code." + G.H.djb2(v)
            if not why and R.keep(k, v)[0] and k not in seen:
                seen.add(k)
                out.append(v)
    return out


def feed():
    """Lua code setting LootTriageStandInFeed from the installed addon's English, and the window's label keys."""
    rs = rows()
    skip = set(R.CODE) | set(R.NAMES)
    files = lambda r: {f for f, _ in r[3]}  # noqa: E731
    win = [r[0] for r in rs if files(r) & set(WIN) and "%" not in r[1] and r[0] not in skip][:40]
    en = {r[0]: r[1] for r in rs}
    news_text = news_lines()
    # its help: the header through its Print (with its prefix, Settings.lua ShowHelp), the lines bare
    chat = [(PREFIX if k == HELP[0] else "") + en[k].replace("%d", "5") for k in HELP if k in en]
    return ("LootTriageStandInFeed = { en = { %s }, win = { %s }, choices = { %s }, news = { %s }, chat = { %s },"
            " panel = { %s } }" % (
                ", ".join("[%s] = %s" % (_q(k), _q(v)) for k, v in en.items()), ", ".join(map(_q, win)),
                ", ".join(map(_q, CHOICES)), ", ".join(map(_q, news_text)), ", ".join(map(_q, chat)),
                ", ".join(map(_q, PANEL))))


def game(module=True, target=True):
    addons = [Addon(TARGET, os.path.join(HERE, "loottriage", TARGET), session.FLAVOR)] if target else []
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD",) + ((MODULE,) if module else ())]
    c = Client(addons, None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_lt.lua")))
    M = c.H.lt
    if target:
        M.feed(lua_str(feed()))
    c.start()
    c.H.pump(20)
    if module and target:
        M.uall()
    return c, M


def snap(M):
    return {txt(k): txt(v) for k, v in M.snap().items()}


def lines(t):
    return [txt(t[i]) for i in range(1, len(t) + 1)]


def whole(out, en):
    """Whole English (as it was) or whole Ukrainian (Cyrillic, no made-up English)."""
    return out == en or (out is not None and cyr(out) and "Quix" not in out and "Zorp" not in out)


def templates(en):
    """Each template the module fills (lt_rules.SORTS), with real values: our pieces' English, a known link."""
    piece = en.get("Code.ca207745", "").replace("%d", "7")
    link = "|cff1eff00|Hitem:4711::::::::60:::::|h[Zorp Shard]|h|r"
    good = {"Code.13c59ccc": {1: piece, 2: link}, "Code.801b6b21": {1: en.get("Code.2f8fc263", "")},
            "Code.0a533f7e": {2: MONEY}, "Code.ae4b2a63": {1: en.get("Code.9acb900c", "")},
            "Code.8ffcf1a4": {1: link, 2: piece}, "Code.64358fe7": {1: link, 2: piece}}
    return [halves_mods.tpl(k, en[k], {}, good.get(k, {}), sorts=s) for k, s in sorted(R.SORTS.items()) if k in en]


def menu(M, open_=False):
    """The game's menu its dropdown opens: (text, in our font, the game's font object) per shown entry."""
    return [tuple(x.split("\t")) for x in lines(M.menu(open_))]


def menu_steps(check, M):
    """14: the game's pooled menu (not under its window) its dropdown opens; 15: a tooltip with a forbidden owner."""
    def ours(m):
        return len(m) >= 3 and all(cyr(t) and f == "1" for t, f, _ in m)

    def english(m):
        return len(m) >= 3 and all(not cyr(t) and f == "0" and o == "1" for t, f, o in m)
    m = menu(M, True)
    check("14 its dropdown's menu: our names in our Cyrillic font", ours(m), m)
    M.key(True)
    h = menu(M)
    M.key(False)
    r = menu(M)
    check("14 menu, hold key: English, the game's font object; released: ours", english(h) and ours(r), (h, r))
    M.uadd("lt off")
    o = menu(M)
    o2 = menu(M, True)
    check("14 menu, off: English with the game's font object back, also opened again", english(o) and english(o2),
          (o, o2))
    M.closeMenu()
    M.uadd("lt on")
    m = menu(M, True)
    M.closeMenu()
    check("14 menu, on again: ours; hidden: none left in our font", ours(m) and int(M.menuCount()) == 0, m)
    out, reported, faults = M.forbiddenTip(lua_str("Quix plain line"))
    out = lines(out)
    check("15 a tooltip with a forbidden owner: no error, no fault", reported == 0 and faults == 0
          and out == ["Quix plain line"], (out, reported, faults))


def steps(check, c, M, E, A, en):
    import flow_lt_news
    on = {k: v for k, v in A.items() if v != E.get(k)}
    check("1 its window ours", sum(1 for k in on if k.startswith("W:")) >= 5 and all(cyr(on[k]) for k in on),
          f"{len(on)} changed; " + diff(E, A)[:300])
    bad, n = M.fonts()
    check("1 Cyrillic only in our font", len(bad) == 0 and n > 0, f"{n} ours; bad {[txt(b) for b in bad.values()]}")
    tipr = [r for r in rows() if {f for f, _ in r[3]} & set(TIPS) and "%" not in r[1] and r[0] not in R.CODE
            and r[0] not in R.NAMES]
    outs = [(r[1], txt(M.tr(lua_str(r[1])))) for r in tipr]
    check("2 tooltip lines whole", outs and all(whole(o, e) for e, o in outs) and any(o != e for e, o in outs),
          [o for e, o in outs if not whole(o, e)][:3])
    head = next((r[1] for r in tipr if r[1].startswith("LootTriage: ")), None)
    q = lines(M.tip(lua_str(head or ""), lua_str("  " + txt(M.QUEST)), lua_str("  Quix Wobbly Hunt")))
    check("3 quest line by UALL's name", head and cyr(q[1]) and q[2] == "  Quix Wobbly Hunt", q)
    other, stand, grow = M.cheap()
    check("4 lines not its own cost nothing", other == 0 and stand == 0 and grow == 0, (other, stand, grow))
    M.key(True)
    H = snap(M)
    check("5 hold key: English", H == E, diff(E, H)[:300])
    M.key(False)
    check("5 release: ours", snap(M) == A, diff(A, snap(M))[:300])
    M.uadd("lt off")
    O = snap(M)
    check("6 off: English as without it", O == E, diff(E, O)[:300])
    check("8 off: its own choices back", M.choicesBack())
    M.uadd("lt on")
    check("6 on: ours", snap(M) == A, diff(A, snap(M))[:300])
    S = M.stand()
    check("8 choices ours, values the same", all(cyr(A["C:%d" % i]) and A["C:%d" % i].startswith("%d=" % i)
                                                 for i in (1, 2, 3)), [A.get("C:%d" % i) for i in (1, 2, 3)])
    check("9 panel row ours", all(cyr(A[k]) for k in ("P:name", "P:buttonText", "P:tooltip", "R:text", "R:button")),
          {k: A[k] for k in A if k[:2] in ("P:", "R:")})
    menu_steps(check, M)
    dlg = S.dialog.text
    check("10 What's New stays its English (lesson 43)", E["X"] and "\n" in E["X"] and not cyr(E["X"])
          and A["X"] == E["X"], A["X"][:200])
    M.click(S.newButton)
    xp = txt(dlg.GetText(dlg))
    M.key(True)
    M.click(S.win.news)
    xh = txt(dlg.GetText(dlg))
    M.key(False)
    M.uadd("lt off")
    M.click(S.newButton)
    xo = txt(dlg.GetText(dlg))
    M.uadd("lt on")
    M.click(S.newButton)
    xa = txt(dlg.GetText(dlg))
    check("10 What's New from its panel New button, held, off and on again: its English",
          xp == xh == xo == xa == E["X"], [x[:80] for x in (xp, xh, xo, xa)])
    flow_lt_news.steps(check, M, E)
    S.Rename(1, lua_str("Quix label"))
    M.uadd("lt off")
    check("7 a text it renamed itself stays (lesson 23)", txt(S.win.labels[1].fs.GetText(S.win.labels[1].fs)) ==
          "Quix label")
    M.uadd("lt on")
    S.Rename(1, S.E(S.win.labels[1].key))
    help_ = [txt(x) for x in M.help().values()]
    check("11 help lines ours", help_ and all(cyr(x) for x in help_), help_[:3])
    said = [txt(M.chat(lua_str(PREFIX + en[k]))) for k in CHAT if k in en and "%" not in en[k]]
    check("11 chat lines ours", said and all(cyr(x) and x.startswith(PREFIX) for x in said), said[:3])
    halves_mods.lt(check, M, templates(en))
    errors(c, check, "game A before the errors")
    M.wait(4)                    # past the settle time after login: an error now counts, it is not a failed setup
    M.fault(5)
    for _ in range(3):
        M.lt("")
    left = M.boom
    M.wait(0.3)                  # U.TurnOff runs the module's off one frame later
    said = "\n".join(c.chat()[-8:])
    F = snap(M)
    check("12 five errors: off, English back", left == 0 and not M.on() and "вимкнено до кінця сесії" in said
          and {k: F[k] for k in F if k[0] == "W"} == {k: E[k] for k in E if k[0] == "W"},
          (left, M.on(), said[-200:], diff(E, F)[:300]))
    M.uadd("lt on")
    check("12 then on: ours", M.on() and snap(M) == A, diff(A, snap(M))[:300])
    st = txt(M.said("lt"))
    check("13 status", "увімкнено" in st, st[:300])


def run(check, facts):
    if not module_there() or not installed():
        halves_mods.lt(check, None, [], halves_mods.SKIP)
        facts["note"] = "LootTriage or the module not there: skipped"
        return
    en = english()
    c, M = game(module=False)
    E = snap(M)
    errors(c, check, "game E")
    del c, M
    c, M = game()
    A = snap(M)
    steps(check, c, M, E, A, en)
    del c, M
    import flow_lt_mut
    flow_lt_mut.mutants(check, E, en)
    c, M = game(target=False)
    st = txt(M.said("lt"))
    check("B without LootTriage: waits", "чекає" in st, st[:300])
    facts["changed"] = sum(1 for k in A if A[k] != E.get(k))


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("lt: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_lt.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:400]}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
