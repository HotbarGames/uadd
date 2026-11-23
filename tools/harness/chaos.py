"""The chaos test: try to break each UADD module on purpose, then check the game still works.

The owner's rule (2026-11-20): the worst UADD may do is leave a text English. For every module with a harness
flow (chaos_mods.RECIPES) the flow's own game is built with spies under every hook (chaos.lua), then fed bad
and odd cases (chaos_ops.lua, chaos_cases.py, the steps in chaos_steps.py). After each case:
  * no Lua error from UADD's code reaches the game's error handler or the caller;
  * each text UADD changed is whole: exactly the English fed, or no made-up English left (no half line);
  * "/uadd <key> off" gives back the exact English (also after 100 fast off/on, a reinstall, a throw);
  * no text takes over 5 ms (best of 3; more under load, clock.py), no cache grows past its bound over 10k calls;
  * the keyboard is free and no tooltip line stays pinned to a file (tipfont, run.py's segment);
  * other code's tooltip lines, chat lines and font strings cost UADD no Translate and no debugstack;
  * idle, UADD's frame visits stay in budget and stop when the addon's windows close.
chaos_more.py adds the cases that need games of their own (install failing part-way, the addon missing or
late, its locale changed by an update, SafeCall's error table, the UALL Forever probe, a throw while busy).

  python3 tools/harness/chaos.py            # CHAOS_SEED (default 20261120), CHAOS_N (random cases per
                                            # text, default 3), CHAOS_ONLY=UADD_X (one module)
Each failure names the module, the case, the seed and the line that runs it again.
"""
import collections
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))

import chaos_cases as K  # noqa: E402
import chaos_flood  # noqa: E402
import chaos_mods  # noqa: E402
import chaos_steps as S  # noqa: E402
import loader  # noqa: E402
from chaos_steps import N, ONLY, SEED  # noqa: E402
from loader import lua_str, read_text, txt  # noqa: E402

Check = collections.namedtuple("Check", "name ok detail")


class Spied:
    """Runs chaos.lua and chaos_ops.lua in every Client made inside the block (before its flow and start)."""

    def __enter__(self):
        self.init = init = loader.Client.__init__

        def spied(c, *a, **k):
            init(c, *a, **k)
            for f in ("chaos.lua", "chaos_ops.lua", "chaos_more.lua", "chaos_flood.lua"):
                c.lua.execute(read_text(os.path.join(HERE, f)))
            if Spied.hook_fail:
                c.lua.globals().CHAOS.hookFail = Spied.hook_fail
            if Spied.cut:                       # chaos_flood.prove's mutant, cut as UADD/Lines.lua loads
                c.lua.globals().CHAOS.cutFrom, c.lua.globals().CHAOS.cutTo = Spied.cut
        loader.Client.__init__ = spied
        return self

    def __exit__(self, *_):
        loader.Client.__init__ = self.init
    hook_fail = None
    cut = None


class Run:
    def __init__(self, folder, target, c, check):
        self.folder, self.target, self.c, self.check = folder, target, c, check
        self.C, self.H = c.lua.globals().CHAOS, c.H
        self.U = c.lua.globals().UADD
        order = [txt(k) for k in self.U.order.values()]
        self.key = order[-1] if order else None
        self.base = len(c.errors())
        self.notes = []

    def repro(self):
        return f"CHAOS_SEED={SEED} CHAOS_N={N} CHAOS_ONLY={self.folder} python3 tools/harness/chaos.py"

    def ok(self, case, good, detail=""):
        self.check(f"chaos: {self.folder} {case}", good, "" if good else f"{detail} | seed {SEED} | {self.repro()}")

    def errors(self):
        """New Lua errors since the last call that UADD's code raised or was on the stack of."""
        errs = self.c.errors()
        new, self.base = errs[self.base:], len(errs)
        return [f"{w}: {m[:140]}" for w, m, tb in new if "UADD" in (w + m + tb)]

    def no_errors(self, case):
        e = self.errors()
        self.ok(f"{case}: no Lua error reaches the game", not e, "; ".join(e[:2]))

    def slash(self, text, frames=5):
        self.c.slash(text)
        self.H.pump(frames)

    def off_gives_english(self, case, snap):
        if not self.key:
            return
        self.slash(self.key + " off")
        wrong = [(en, txt(self.C.Text(fs))) for fs, en in snap if txt(self.C.Text(fs)) != en]
        self.ok(f"{case}: off gives back the exact English", not wrong, f"{len(wrong)}/{len(snap)}: {wrong[:2]}")
        self.slash(self.key + " on")

    def whole(self, case, snap):
        bad = []
        for fs, en in snap:
            why = K.half(txt(self.C.Text(fs)), en)
            if why:
                bad.append(f"{en[:40]!r} -> {txt(self.C.Text(fs))[:60]!r}: {why}")
        self.ok(f"{case}: every text whole English or whole Ukrainian", not bad, "; ".join(bad[:2]))

    def tr_per_set(self, fs, en):
        self.C.Reset()
        self.C.counting = True
        self.C.Set(self.target, fs, lua_str(en))
        self.C.counting = False
        return int(self.C.n.tr)


def module(folder, target, build, check, notes, hooks):
    rng = K.seeded(SEED, folder)
    t0 = time.time()
    c = build()
    if c is None:
        notes.append(f"{folder}: skipped (its addon or its data is not installed here)")
        return
    r = Run(folder, target, c, check)
    r.notes = notes
    hooks[folder] = int(r.C.hooks)      # chaos_more fails the middle one of these in a second build
    r.C.WrapTranslate()
    r.ok("its game builds", r.key, "no module registered")
    r.no_errors("its game builds")
    focus = c.lua.globals().GetCurrentKeyBoardFocus()
    r.ok("the keyboard is free after login", focus is None, focus and c.H.Widget.GetDebugName(focus))
    if not r.key:
        return
    fss = list(r.C.Touched(12).values()) or list(r.C.Seen(target, 4).values())
    snap = [(fs, txt(r.C.Orig(fs))) for fs in fss]
    if not snap:     # its words are swapped in before the addon sets them: one font string of its own
        notes.append(f"{folder}: no English seen on its windows: the cases run on a new font string of its")
        snap = [(r.C.NewFs(target, lua_str("Zorp Blatter")), "Zorp Blatter")]
    r.off_gives_english("first off", snap)
    S.feeds(r, snap, rng)
    S.foreign(r, snap[0][1], snap)
    chaos_flood.flood(r)                # a BG: 10k chat lines, some secret, and odd CreateFrame calls
    chaos_flood.odd_frames(r)
    chaos_flood.instance(r)             # in a BG the chat wrap is off (taint), wrapped again outside
    S.stress(r, snap)
    S.bulk(r, snap)
    S.idle(r)
    S.throw(r, snap)
    S.locale(r, snap, rng)
    focus = c.lua.globals().GetCurrentKeyBoardFocus()
    r.ok("the keyboard is free at the end", focus is None, focus and c.H.Widget.GetDebugName(focus))
    notes.append(f"{folder}: {len(snap)} texts, {time.time() - t0:.1f} s")


def _adder(checks):
    def check(name, ok, detail=""):
        checks.append(Check(name, bool(ok), str(detail)))
    return check


def part(folder):
    """One module's games: its cases (module()), its tooltip font check, then its install failing part-way.
    Returns (checks, facts); facts["later"] holds the part-way checks, which go after the extra cases (assemble)."""
    import boxes
    import chaos_more
    import tipfont
    checks, later, notes, hooks = [], [], [], {}
    check = _adder(checks)
    target, build = next((t, b) for f, t, b in chaos_mods.RECIPES if f == folder)
    with Spied():
        try:
            module(folder, target, build, check, notes, hooks)
        except Exception as e:      # a broken recipe is a failure of this test, not a crash of run.py
            check(f"chaos: {folder} ran", False, f"{type(e).__name__}: {e} | seed {SEED}")
        checks += tipfont.segment("chaos " + folder, Check) + boxes.segment("chaos " + folder, Check)
        chaos_more.partway(_adder(later), Spied, hooks, SEED, folder)
    return checks, {"notes": notes, "hooks": hooks, "later": later}


def rest():
    """The cases after the modules: the BG mutant proof and chaos_more's extra cases (all but install part-way)."""
    import chaos_more
    checks, notes = [], []
    check = _adder(checks)
    with Spied():
        try:
            chaos_flood.prove(check, Spied, chaos_mods.RECIPES, ONLY)
        except Exception as e:
            check("chaos: in a BG, mutant 'unwrap' ran", False, f"{type(e).__name__}: {str(e)[:160]}")
        try:
            chaos_more.run(check, notes, Spied, SEED, ONLY)
        except Exception as e:
            check("chaos: the extra cases ran", False, f"{type(e).__name__}: {e} | seed {SEED}")
    return checks, {"notes": notes}


def pieces():
    """The test as jobs that need nothing from each other: (fn, args), one per module, then rest. jobs.py runs
    them side by side; assemble() puts their results together in this order."""
    return [(part, (f,)) for f, _, _ in chaos_mods.RECIPES if not ONLY or f == ONLY] + [(rest, ())]


def assemble(results):
    """[(checks, facts)] of pieces(), in order -> (checks, facts), as one run in order gives them."""
    import chaos_more
    checks, later, notes, hooks = [], [], [], {}
    for folder in chaos_mods.folders():
        if folder not in [x[0] for x in chaos_mods.RECIPES] and folder not in chaos_mods.SKIPPED:
            checks.append(Check(f"chaos: {folder} has a recipe", False, "add it to chaos_mods.RECIPES"))
    *mods, (rest_checks, rest_facts) = results
    for cs, facts in mods:
        checks += cs
        notes += facts.get("notes", [])
        hooks.update(facts.get("hooks", {}))
        later += facts.get("later", [])
    checks += rest_checks + later
    notes += rest_facts.get("notes", []) + [chaos_more.covers(hooks)]
    return checks, {"seed": SEED, "n": N, "notes": notes}


def run_checks():
    """Every check of the chaos test, one piece after another. Returns (checks, facts)."""
    return assemble([fn(*args) for fn, args in pieces()])


if __name__ == "__main__":
    t = time.time()
    cs, facts = run_checks()
    for x in cs:
        if not x.ok or os.environ.get("CHAOS_ALL"):
            print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    for n in facts["notes"]:
        print("note  " + n)
    bad = sum(not x.ok for x in cs)
    print(f"{len(cs) - bad}/{len(cs)} passed in {time.time() - t:.0f} s (seed {SEED})")
    sys.exit(1 if bad else 0)
