"""UADD_WowheadQuickLink on a stand-in for Wowhead Quick Link (tools/harness/wowheadquicklink). It has no licence,
so none of its English is here: the stand-in holds only the game functions the harness lacks and its /wql window
(Shim.lua, its labels handed in from the installed XML at run time), and the game runs the installed addon's own
three Lua files (read only). The flow points the mouse at things, runs its key binding, opens /wql and reads back.

  * Game E (no module): its English: what "off" and the hold key must give back.
  * Game A (on at login): 1 ours: each kind's popup (the NPC type kept as it is), the window's title and labels,
    the two key binding names; what was typed and the URL stay. 2 a link type with no word (enchant) and a header
    left English on purpose (azerite): the whole popup English, its button too; only the first is a missed text.
    3 the button «Закрити» on our popups. 4 hold key, off and on, three times: English exactly, then ours exactly,
    no font kept. 5 our font, read back, on every Cyrillic text and on no other. 6 a binding name another addon
    changed stays as it is on off. 7 /uadd wql says on. Then no half line (halves_mods.wql).
  * Game C (off at login): the player typed the labels' English in the boxes, and the URL line shows one; then on:
    the labels are ours, what was typed and the URL stay (lesson 13).
  * Game B: no Wowhead Quick Link (the module waits).
  * Mutants (--prove): each step fails with its fix cut out.
"""
import os
import sys
from types import SimpleNamespace

import halves_mods
import session
from flow_pawn_game import cyr, diff, errors

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402
import wql_source as G  # noqa: E402
from flow import Check  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE, TARGET = "UADD_WowheadQuickLink", "WowheadQuickLink"
LABELS = {"62c3ca66": "prefix", "69fa1a2d": "suffix", "54d63e75": "title", "b0a39822": "header"}
OURS = ("quest", "spell", "currency", "achievement", "faction", "link", "npc", "item")
STAYS = ("enchant", "azerite")
KEPT = ("url", "typedP", "typedS")
OFF = {"UADD": "UADD_DB = { modules = { wql = { enabled = false } } }"}


def addon_dir():
    return str(G.addon_dir())


def installed():
    return all(os.path.isfile(os.path.join(addon_dir(), f)) for f in (G.MAIN, G.CONFIG, G.STRAT, G.XML))


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def labels():
    """{field: English} of the window's labels, read from the installed XML."""
    return {LABELS[h]: en for _, en, _ in G.xml_texts(addon_dir()) for h in [hashtext.djb2(en)] if h in LABELS}


class WqlClient(Client):
    """The stand-in's Shim.lua, then the installed addon's own Lua files in its TOC's order, as one addon."""

    def run_addon_files(self, a):
        if a.name != TARGET:
            return super().run_addon_files(a)
        state = self.H.addons[a.name]
        state.loading = True
        self.run_lua(a, "Shim.lua")
        real = SimpleNamespace(name=a.name, folder=addon_dir())
        for rel in (G.CONFIG, G.STRAT, G.MAIN):
            self.run_lua(real, rel)
        state.loading = False
        state.loaded = True


def game(target=True, module=True, cut=None, cuts=None, off=False):
    addons = [Addon(TARGET, os.path.join(HERE, "wowheadquicklink", TARGET), session.FLAVOR)] if target else []
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD",) + ((MODULE,) if module else ())]
    c = WqlClient(addons, OFF if off else None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_wql.lua")))
    M = c.H.wql
    c.H.wqlLabels = c.lua.table_from({k: lua_str(v) for k, v in labels().items()})
    for name, (file, old, new) in (cuts or {}).items():
        M.addCut(lua_str(name), lua_str(file), lua_str(old), lua_str(new))
    M.cut = lua_str(cut) if cut else None
    c.start()
    c.H.pump(20)
    if target:
        M.wql()
        M.link("item")
    return c, M


def templates(en):
    """The half-line check's templates: the popup's text (its slot: the header) and the header's words (its slot:
    the link type), each with a real value."""
    import wql_rules as R
    head, item = en.get("Head.2228878c", "%s"), en.get("Type.7c871214", "")
    good = {"Pop.": {1: head.replace("%s", item)}, "Head.": {1: item}}
    return [halves_mods.tpl(k, en[k], {}, good[k[:k.index(".") + 1]], sorts=R.sorts(k, en[k]))
            for k in sorted(en) if k.startswith(("Pop.", "Head."))]


def snap(M):
    return {txt(k): txt(v) for k, v in M.snap().items()}


# ── Steps: each (check, c, M, E, A) -> ok ──────────────────────────────────────────────────────

def ours(check, c, M, E, A):
    pops = [k for k in OURS if not cyr(A["P:" + k])]
    words = [k for k in ("title", "header", "prefix", "suffix") if not cyr(A["W:" + k])]
    kept = [k for k in KEPT if A["W:" + k] != E["W:" + k]]
    ok = (set(A) == set(E) and not pops and not words and not kept and cyr(A["S:text"])
          and "NPC" in (A["P:npc"] or "") and cyr(A["K:1"]) and cyr(A["K:2"]))
    check("1 ours: each kind's popup (NPC kept), the window's title and labels, both binding names; typed text "
          "and the URL stay", ok, (sorted(set(A) ^ set(E))[:3], pops, words, kept, A["P:npc"]))
    return ok


def stays(check, c, M, E, A):
    eng = [k for k in STAYS if A["P:" + k] != E["P:" + k] or A["B:" + k] != E["B:" + k]]
    M.uadd("missed on")
    n0 = int(M.missed())
    M.link("enchant")
    n1 = int(M.missed())
    M.link("azerite")
    n2 = int(M.missed())
    M.uadd("missed off")
    M.link("item")
    ok = not eng and n1 == n0 + 1 and n2 == n1
    check("2 a link type with no word and a header left English on purpose: whole popup English, button too; "
          f"only the first is a missed text ({n0}, {n1}, {n2})", ok, eng)
    return ok


def button(check, c, M, E, A):
    bad = [k for k in OURS if not cyr(A["B:" + k])] + [k for k in STAYS if cyr(A["B:" + k])]
    check("3 the button is ours on our popups, English on the English ones", not bad, bad)
    return not bad


def loop(check, c, M, E, A):
    bad = []
    for i in range(3):
        for how, want in (("hold", E), ("release", A), ("off", E), ("on", A)):
            if how in ("hold", "release"):
                M.key(how == "hold")
            else:
                M.uadd("wql " + how)
            d = diff(want, snap(M))
            n = int(M.saved())
            if d or (how in ("off", "hold") and n):
                bad.append((i + 1, how, d[:3], n))
    check("4 hold key, off, on (x3): English exactly (popups, window, bindings), then ours exactly; no font kept",
          not bad, bad[:3])
    return not bad


def fonts(check, c, M, E, A):
    bad, n = M.fonts()
    bad = [txt(x) for x in bad.values()]
    want = 2 * len(OURS) + 4
    ok = not bad and int(n) == want
    check(f"5 our font read back: on every Cyrillic text, on no other ({int(n)} of {want})", ok, bad[:4])
    return ok


def bindings(check, c, M, E, A):
    c.lua.execute('BINDING_NAME_WOWHEAD_QUICK_LINK_NAME = "Zorp"')
    M.uadd("wql off")
    other = txt(c.ev("BINDING_NAME_WOWHEAD_QUICK_LINK_NAME"))
    second = txt(c.ev("BINDING_NAME_WOWHEAD_QUICK_LINK_RAIDERIO_NAME"))
    M.uadd("wql on")
    ok = other == "Zorp" and second == E["K:2"]
    check("6 off: a binding name another addon changed stays as it is; ours goes back to English", ok, (other, second))
    return ok


def typed(check, c, M, E, A):
    """Game C: off at login; the labels' English typed in both boxes and on the URL line; then on."""
    en = labels()
    M.wql()
    M.type(lua_str(en.get("prefix", "")), lua_str(en.get("header", "")))
    was = snap(M)
    M.uadd("wql on")
    now = snap(M)
    kept = [k for k in KEPT if now["W:" + k] != was["W:" + k]]
    ok = not kept and int(M.shown()) == 4 and all(cyr(now["W:" + k]) for k in ("title", "header", "prefix", "suffix"))
    check("C on after login: the labels ours; the labels' English the player typed and on the URL line stays",
          ok, (kept, int(M.shown())))
    return ok


def run(check, facts):
    if not module_there() or not installed():
        halves_mods.wql(check, None, [], halves_mods.SKIP)
        facts["note"] = "Wowhead Quick Link or the module not there: skipped"
        return
    rows, _ = G.source(G.addon_dir())
    en = {r[0]: r[1] for r in rows}
    c, M = game(module=False)
    E = snap(M)
    errors(c, check, "game E")

    c, M = game()
    A = snap(M)
    for step in (ours, stays, button, loop, fonts, bindings):
        step(check, c, M, E, A)
    M.uadd("wql")
    status = [x for x in c.chat()[-5:] if "увімкнено" in x]
    check("7 /uadd wql: on, with counts", status, c.chat()[-4:])
    facts["texts"] = len(en)
    halves_mods.wql(check, M, templates(en))
    errors(c, check, "game A")

    c, M = game(off=True)
    typed(check, c, M, E, None)
    errors(c, check, "game C")

    c, M = game(target=False)
    c.slash("wql")
    out = [x for x in c.chat() if "Wowhead Quick Link" in x and "чекає" in x]
    check("game B (no Wowhead Quick Link): the module waits", out, c.chat()[-3:])
    errors(c, check, "game B")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("wql: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


# ── Mutants: each cuts one fix out of the module; its step must fail ─────────────────────────────

CUTS = {
    "stay": ("Module.lua", "    return h ~= nil and STAY[U.Hash(h)] == true\n", "    return false\n", stays, False),
    "button": ("Module.lua", "    if uk and not popOurs then return nil end\n", "", stays, False),
    "bindguard": ("Module.lua", "            if now == uk then _G[name] = en end", "            _G[name] = en",
                  bindings, False),
    "getpoint": ("Module.lua", '                if ok and p == "TOPLEFT" and type(y) == "number" and y > 0 then '
                 "Label(r, out) end\n", "                Label(r, out)\n", typed, True),
    "urlskip": ("Module.lua", "        if not (r.GetName and r:GetName() == URL) then Label(r, out) end\n",
                "        Label(r, out)\n", typed, True),
}


def prove():
    """Each cut: a fresh game without that fix; the step must fail. Returns the exit code."""
    _, M = game(module=False)
    E = snap(M)
    cuts = {k: v[:3] for k, v in CUTS.items()}
    bad = []
    for name, (_, _, _, step, off) in CUTS.items():
        c, M = game(cut=name, cuts=cuts, off=off)
        ok = step(lambda *_: None, c, M, E, None if off else snap(M))
        cut = bool(M.wasCut)
        print(("ok    " if cut and ok is False else "FAIL  ") + f"cut {name}: cut={cut}, step {step.__name__} ok={ok}")
        if not (cut and ok is False):
            bad.append(name)
    print(f"{len(CUTS) - len(bad)}/{len(CUTS)} cuts break their step")
    return 1 if bad else 0


if __name__ == "__main__":       # alone: python3 tools/harness/flow_wql.py [--prove]
    if "--prove" in sys.argv:
        sys.exit(prove())
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:400]}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
