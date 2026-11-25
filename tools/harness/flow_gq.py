"""UADD_GearQuestForever on a stand-in for GearQuest Forever (tools/harness/gearquest). GearQuest is all rights
reserved, so none of its English is here: the stand-in runs the installed addon's own Locales/Locale.lua and gets
every text at run time from a feed built here from the installed addon (tools/gq_source.py). Keys only in this file.

  * Game E (no module): its English: what "off" and the hold key must give back (window, guide, Orders, chat).
  * Game A (on at login), steps in flow_gq_steps.py: 1 ours: labels, option labels, tabs,
    the guide page, the Orders headers and rows, the source tag and spec name; the names stay as typed (lesson 13),
    an unknown item's row whole English. 2 guide: a page with no Ukrainian stays English, one with it ours, the
    bubble fits. 3 the chat line: a known slot ours, the preview ours, an unknown slot and held whole English.
    4 Orders rows: an item ClassicUA has not settled shows English, then ours on the retry. 5 our font on every
    Cyrillic text and on no other (and no box on screen): on, held, off, on. 6 hold key, off, on (x3): English
    exactly, ours exactly. 7 a window made late: ours, English held and off. 8 /uadd gq says on.
    9-11 (flow_gq_menu.py) its right-click menu, copy box and notices.
  * Language games: its saved choice ukUA with the Languages addon absent, there and on, there but off.
  * Game C (off at login), then on: ours, the typed name in an Orders header kept. Game B: no GearQuest (no errors).
  * News (lesson 43): no text only its news files show is in our data.
  * Mutants (--prove): each step fails with its fix cut out.
"""
import glob
import os
import re
import sys

import flow_gq_menu
import halves_mods
import session
from flow_pawn_game import errors

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import gq_source as G  # noqa: E402
import news_texts  # noqa: E402
from flow import Check  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE, TARGET = "UADD_GearQuestForever", "GearQuestForever"
ROLES = {"slot": "L.7c864557", "source": "L.d7dc5f93", "spec": "L.0c41e1c4", "skill": "L.3e6e7a4d",
         "none": "L.7daf35e5", "hint": "L.dd9e1ccc", "asked": "L.e2444f80"}
PLAIN = ["L.b1dc5722", "L.c392d9dd", "L.64bd2450", "L.0de35f31", "L.7382e9dc", "L.9b979727", "L.689ff4ed",
         "L.f610e09c", "L.086cad68", "L.be85b2d7", "L.a3198921", "L.f21b2ab1", "L.adde7058", "L.0cf88a3b",
         "L.8d84e022", "L.0cf84ebb", "L.7c898026"]
OFF = {"UADD": "UADD_DB = { modules = { gq = { enabled = false } } }"}
UKUA = 'GearQuestForeverDB = { settings = { locale = "ukUA" } }'
ITEMS = ("Zorp Helm", "Шолом Зорпа", "Slow Boots", "Повільні чоботи")


def installed():
    return os.path.isfile(os.path.join(str(G.addon_dir()), TARGET + ".toc"))


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def _q(s):
    """A Lua string literal (every byte outside plain ASCII as a decimal escape)."""
    return '"' + "".join(chr(b) if 32 <= b < 127 and b not in (34, 92) else "\\%03d" % b
                         for b in s.encode("utf-8")) + '"'


def _list(xs):
    return "{" + ",".join(_q(x) for x in xs) + "}"


def english():
    """{key: English} of the installed addon, and its guide pages in order."""
    a = G.addon_dir()
    rows, _ = G.source(a)
    return {r[0]: r[1] for r in rows}, [r[1] for r in G.x_rows(a)[0]] + [MADE_UP]


MADE_UP = "Wobbly gizmo page: made-up words, so one page has no Ukrainian."   # every real page has ours


def ours():
    """{key: our Ukrainian} from the module's data (a long text: its first part only; the keys are what count)."""
    T = {}
    for f in sorted(glob.glob(os.path.join(session.REPO, MODULE, "data", "*.lua"))):
        with open(f, encoding="utf-8") as fh:
            for m in re.finditer(r'^T\["([^"]+)"\] = "((?:[^"\\\n]|\\.)*)"', fh.read(), re.M):
                T[m.group(1)] = m.group(2)
    return T


def feed(langs=None):
    """The stand-in's feed (Lua code): which English each part of its windows shows."""
    en, pages = english()
    e = {r: en[k] for r, k in ROLES.items()}
    p = [en[k] for k in PLAIN]
    mn = flow_gq_menu.feed(en)
    roles = ",".join("%s=%s" % (r, _q(v)) for r, v in e.items())
    return ("GearQuestStandInFeed = { win = %s, opts = %s, tabs = %s, late = %s, pages = %s, menu = %s, copy = %s, %s%s }"
            % (_list(p[:5]), _list(p[5:9]), _list(p[9:13]), _list(p[13:17]), _list(pages), _list(mn["menu"]),
               _q(mn["copy"]), roles,
               ", langs = %s" % _q(langs) if langs else ""))


def locale_src():
    with open(os.path.join(str(G.addon_dir()), "Locales", "Locale.lua"), encoding="utf-8") as fh:
        return "GearQuestStandInLocale = " + _q(fh.read())


def game(target=True, module=True, cut=None, cuts=None, off=False, saved=None, langs=None):
    addons = [Addon(TARGET, os.path.join(HERE, "gearquest", TARGET), session.FLAVOR)] if target else []
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD",) + ((MODULE,) if module else ())]
    sv = dict(OFF if off else {}, **({TARGET: saved} if saved else {}))
    c = Client(addons, sv or None, "enUS")
    for f in ("flow_gq.lua", "flow_gq_menu.lua"):
        c.lua.execute(read_text(os.path.join(HERE, f)))
    M = c.H.gq
    if target:
        M.feed(lua_str(locale_src()))
        M.feed(lua_str(feed(langs)))
    for name, (file, old, new) in (cuts or {}).items():
        M.addCut(lua_str(name), lua_str(file), lua_str(old), lua_str(new))
    M.cut = lua_str(cut) if cut else None
    c.start()
    c.H.pump(20)
    if target:
        M.stub(*(lua_str(x) for x in ITEMS), 1)
        M.open()
        M.guide(1)
        e = english()[0]
        slot = e[ROLES["slot"]]
        M.feed(lua_str("GearQuestStandIn.Orders({ {%s, 5, %s}, {%s, 3, %s}, {%s, 1, %s} })" % (
            _q(ITEMS[0]), _q("Zorpa"), _q("Gizmo Ring"), _q("Zorpa"), _q(ITEMS[2]), _q(slot))))
    return c, M


def snap(M):
    return {txt(k): txt(v) for k, v in M.snap().items()}


class Run:
    """One game and what the steps compare it with: E, its English (game E); A0 its first look, A after the retry."""

    def __init__(self, c, M, E, ref):
        self.c, self.M, self.E, self.ref = c, M, E, ref
        self.A0 = snap(M)
        M.wait(3.2)
        self.A = snap(M)


def reference():
    """Game E: the addon alone. Its texts, its chat lines, its late window, its guide pages."""
    c, M = game(module=False)
    M.wait(3.2)
    E = snap(M)
    en, pages = english()
    ref = {"chat": [txt(M.nohunts(lua_str(s), p)) for s, p in (("head", False), ("head", True), ("feet", False))],
           "pages": pages, "en": en}
    M.late()
    ref["late"] = {k: v for k, v in snap(M).items() if k.startswith("L:")}
    keys, T = [r[0] for r in G.x_rows(G.addon_dir())[0]] + [None], ours()
    ref["nouk"] = next(i for i, k in enumerate(keys, 1) if k not in T)        # a guide page with no Ukrainian
    ref["uk"] = next(i for i, k in enumerate(keys, 1) if k in T and i > 1)    # one with it
    return c, E, ref


def run(check, facts):
    import flow_gq_steps as S
    if not module_there() or not installed():
        halves_mods.gq(check, None, halves_mods.SKIP)
        facts["note"] = "GearQuest Forever or the module not there: skipped"
        return
    c, E, ref = reference()
    errors(c, check, "game E")
    c, M = game()
    g = Run(c, M, E, ref)
    for step in S.STEPS:
        step(check, g)
    facts["texts"] = len(E)
    halves_mods.gq(check, c)
    errors(c, check, "game A")
    for langs in (None, "on", "off"):
        c, M = game(saved=UKUA, langs=langs)
        S.language(check, Run(c, M, E, ref), langs)
        errors(c, check, "language game %s" % langs)
    c, M = game(off=True)
    S.typed(check, Run(c, M, E, ref))
    errors(c, check, "game C")
    c, M = game(target=False)
    errors(c, check, "game B (no GearQuest)")
    S.news(check, G, news_texts, ours())


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("gq: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


# ── Mutants: each cuts one fix out of the module; its step must fail ─────────────────────────────

CUTS = {
    "fontback": ("Fonts.lua", "    if face and U.IsCyrFont(face) then pcall(U.FontBack, w, was) end", "", "fonts"),
    "fresh": ("Fonts.lua", "    if U.IsCyrFont(face) then return end                  -- ours (or a Cyrillic face) "
              "is on: keep what we saved", "", "fonts"),
    "known": ("Fonts.lua", "    for w in pairs(known) do", "    for w in pairs(saved) do", "fonts"),
    "guide": ("Glued.lua", '    hooksecurefunc(fs, "SetText", Guard(OnBody))', "", "guide"),
    "chat": ("Glued.lua", "    WrapChat(g)", "", "chat"),
    "rows": ("Rows.lua", '    hooksecurefunc(orders, "Paint", G.Guard(AfterPaint))', "", "rows"),
    **flow_gq_menu.CUTS,
}


def prove():
    """Each cut: a fresh game without that fix; the step must fail. Returns the exit code."""
    import flow_gq_steps as S
    _, E, ref = reference()
    cuts = {k: v[:3] for k, v in CUTS.items()}
    bad = []
    for name, (_, _, _, step) in CUTS.items():
        c, M = game(cut=name, cuts=cuts)
        ok = getattr(S, step)(lambda *_: None, Run(c, M, E, ref))
        cut = bool(M.wasCut)
        print(("ok    " if cut and ok is False else "FAIL  ") + f"cut {name}: cut={cut}, step {step} ok={ok}")
        if not (cut and ok is False):
            bad.append(name)
    print(f"{len(CUTS) - len(bad)}/{len(CUTS)} cuts break their step")
    return 1 if bad else 0


if __name__ == "__main__":       # alone: python3 tools/harness/flow_gq.py [--prove]
    if "--prove" in sys.argv:
        sys.exit(prove())
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:400]}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
