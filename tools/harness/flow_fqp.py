"""UADD_ForeverQuestPins on the real Forever Quest Pins (GPL-3.0), read from the installed AddOns folder; when it
is not installed every check is skipped. Lua helpers: flow_fqp.lua (HARNESS.fqp) and flow_fqp_pages.lua (its pages
under the main one, its tracker). Steps: flow_fqp_steps.py.

  * Game A (English client): 1 at login: menu, setup window, settings pages (its main one and the 5 under it,
    found through the category links flow_fqp.lua gives the stand-in), tips and What's New ours.
    2 World Map menu, off and on. 3 hold key (lessons 15, 23), its canvas label with the level range apart.
    4 names in the breadcrumb and abandoned lines (lessons 9, 20), What's New lines with quest names English;
    an untitled quest ("Quest 5", our word) in a line that stays English (lesson 27). 5 off and on (its canvas label apart),
    then 5 errors turn it off and the English comes back, tooltips too (lesson 19). 6 its pages' names in the
    settings tree, its tracker's sort and filter names and its tracker menu: ours, English held and off. 6 no
    half-translated line (halves_mods.fqp).
  * Game B: two spoiled words (a % spec, an escape the English lacks) are not used.
  * Mutants (one fix cut from one module file, in memory only): each named step must fail, so it has teeth.
"""
import collections
import gc
import os
import sys

import flow_fqp_steps as S
import halves_mods
import session
from loader import Addon, Client, lua_str, read_text

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = "UADD_ForeverQuestPins"
# Prepared names (flow_fqp_steps.KNOWN) are the only ones UADD.UALL knows.


def installed():
    return os.path.isdir(os.path.join(session.addons_dir(), "ForeverQuestPins"))


def _game(cut=None, bad=False, locale="enUS"):
    addons = [Addon("ForeverQuestPins", os.path.join(session.addons_dir(), "ForeverQuestPins"), session.FLAVOR)]
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD", MODULE)]
    c = Client(addons, None, locale)
    for name in ("flow_fqp.lua", "flow_fqp_pages.lua"):
        c.lua.execute(read_text(os.path.join(HERE, name)))
    M = c.H.fqp
    M.cut = cut and lua_str(cut)
    M.bad = bad or None
    c.start()
    c.H.pump(60)
    M.openCanvas()
    M.crumbtest()
    M.wait(1.2)
    for en, uk in S.KNOWN.items():
        M.know(lua_str(en), lua_str(uk))
    M.known(True)
    return c, M


def _errors(c, check, step, skip=()):
    errs = [e for e in c.errors() if not any(s in e[1] for s in skip)]
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def game_a(check, K):
    c, M = _game()
    check("module on, its words in L", M.on() and M.written() > 0, M.written())
    S.login(check, M)
    S.menu(check, M)
    S.hold(check, M)
    S.names(check, c, M, K)
    S.untitled(check, c, M, K)
    S.off(check, c, M, K)
    S.pages(check, M)
    halves_mods.fqp(check, M, S.templates(M, K))
    _errors(c, check, "game A before the errors")
    S.faults(check, c, M)
    del c, M


def game_b(check):
    c, M = _game(bad=True)
    S.spoiled(check, M)
    _errors(c, check, "game B (spoiled words)")


# cut -> (the sub-check it must break, how to reach it on a fresh game).
MUTANTS = {
    "usable": ("spoiled", dict(bad=True), lambda q, c, M, K: S.spoiled(q, M)),
    "menu": ("menu", {}, lambda q, c, M, K: S.menu(q, M)),
    "draw": ("menu", {}, lambda q, c, M, K: S.menu(q, M)),
    "hold": ("hold", {}, lambda q, c, M, K: S.hold(q, M)),
    "range": ("hold canvas", {}, lambda q, c, M, K: S.hold(q, M)),
    "names": ("names", {}, lambda q, c, M, K: S.names(q, c, M, K)),
    "plain": ("untitled", {}, lambda q, c, M, K: S.untitled(q, c, M, K)),
    "restore": ("off", {}, lambda q, c, M, K: S.off(q, c, M, K)),
    "fault": ("faults", {}, lambda q, c, M, K: S.faults(q, c, M)),
    "tiphook": ("tips", {}, lambda q, c, M, K: S.faults(q, c, M)),
    "pages": ("tree", {}, lambda q, c, M, K: S.pages(q, M)),
    "rename": ("tree", {}, lambda q, c, M, K: S.pages(q, M)),
    "labels": ("labels", {}, lambda q, c, M, K: S.pages(q, M)),
}


def mutants(check, K):
    for cut, (sub, kw, reach) in MUTANTS.items():
        got = {}

        def quiet(name, ok, detail=""): got[name] = ok  # noqa: E704
        c, M = _game(cut=cut, **kw)
        reach(quiet, c, M, K)
        ok = got.get(S.STEPS[sub])
        check(f"mutant {cut} (a module file without that fix, in memory only): step '{S.STEPS[sub]}' fails",
              M.wasCut and ok is False, "cut not found" if not M.wasCut else "it passed" if ok else "")
        del c, M
        gc.collect()


def run(check, facts):
    if not os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc")):
        return check(f"{MODULE} is there", False, f"no {MODULE}/{MODULE}.toc")
    if not installed():
        check("Forever Quest Pins checks (skipped: Forever Quest Pins is not installed)", True, "")
        return halves_mods.fqp(check, None, [], halves_mods.SKIP)
    K = S.keys()
    check("its breadcrumb and abandoned-quest keys found by hash", S.CRUMB in K and S.GONE in K, len(K))
    if S.CRUMB not in K or S.GONE not in K:
        return halves_mods.fqp(check, None, [], "skipped: its keys changed (update-translations)")
    for game in (lambda: game_a(check, K), lambda: game_b(check), lambda: mutants(check, K)):
        game()
        gc.collect()
    facts["keys with a slot"] = len(K)


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("fqp: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_fqp.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
