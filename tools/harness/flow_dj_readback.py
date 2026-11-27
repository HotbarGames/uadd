"""The Dungeon Journal's SetFont that reads our file back (docs/LESSONS5.md lesson 48), in its own game.

The journal sets a size or flags with the file its GetFont gives (its quest page's class line, its marks): with
our font on, that passes our Cyrillic file. A made-up text on the journal's window, drawn as the journal draws
that line (flow_dj_readback.lua, from a chunk in its folder), at a new size on each draw:
  1 on: ours on at the journal's new size; the module still knows the journal's own file, at that size
  2 held: English, never Cyrillic in a Latin file; its own file known at the latest size
  3 released: Ukrainian in our file
  4 off: English in the journal's own file at its latest size and flags, not ours
  5 on again: Ukrainian in our file
mutants(check) cuts each fix out of UADD_DungeonJournal/Fonts.lua in memory and wants its step to fail.
Alone: python3 tools/harness/flow_dj_readback.py [--prove]. flow_dj_module.py runs it without --prove.
"""
import collections
import gc
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import flow_dj  # noqa: E402
import session  # noqa: E402
from loader import read_text, txt, lua_str  # noqa: E402

Check = collections.namedtuple("Check", "name ok detail")
MODULE = "UADD_DungeonJournal"
HELD = 0.3                 # seconds: the core waits 0.25 s before it shows the original

CUT_LUA = r"""
local H, cut = HARNESS, { wasCut = false }
H.djrbcut = cut
local runFile = H.runFile
function H.runFile(addon, path, code)
    if addon == "UADD_DungeonJournal" and cut.file and path:sub(-#cut.file) == cut.file then
        local a, b = code:find(cut.old, 1, true)
        if a then code, cut.wasCut = code:sub(1, a - 1) .. cut.new .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end
"""

# name: (file, old text, new text, the step that must fail)
MUTANTS = {
    # the journal's SetFont of our file taken as its own choice of a Cyrillic font: the record is dropped
    "readback": ("Fonts.lua", "if was and ours and SamePath(path, ours) and UADD.IsCyrFont((fs:GetFont())) then",
                 "if false then", 4),
    # its SetFontObject over our file (kept by hand) taken as a font of its own: the record is dropped
    "object": ("Fonts.lua", "if was and UADD.IsCyrFont((fs:GetFont())) then return UADD.SafeCall(NewObject, fs, was) end",
               "", 4),
    # off forgets a text that still shows Ukrainian before the journal draws its English
    "keep": ("Fonts.lua", "if not last and LineShowsCyr(fs) then", "if false then", 4),
}


class _CutClient(flow_dj.Client):
    """The harness client, with the cut put in before the addons load."""
    cut = None

    def start(self):
        self.lua.execute(CUT_LUA)
        if self.cut:
            box = self.H.djrbcut
            box.file, box.old, box.new = (lua_str(x) for x in self.cut[:3])
            self.H.boxQuiet = True             # its wanted boxes stay its own (lesson 45)
        return super().start()


def game(cut=None):
    """The module's game (flow_dj_module.ModuleSession), maybe with a cut. Returns (session, M, cut box)."""
    import flow_dj_module
    old = flow_dj.Client
    _CutClient.cut = cut
    flow_dj.Client = _CutClient
    try:
        s = flow_dj_module.ModuleSession()
    finally:
        flow_dj.Client = old
        _CutClient.cut = None
    s.lua.execute(read_text(os.path.join(HERE, "flow_dj_readback.lua")))
    return s, s.H.djrb, s.H.djrbcut


def now(M):
    r = M.now()
    t, p, size, flags, cyr, rp, rs, rfl = (list(r if isinstance(r, tuple) else (r,)) + [None] * 8)[:8]
    return {"text": txt(t), "file": txt(p), "size": size, "flags": txt(flags), "ours": bool(cyr),
            "rfile": txt(rp) if rp is not None else None, "rsize": rs, "rflags": txt(rfl) if rfl is not None else None}


def steps(s, M):
    """[(step, name, ok, detail)]"""
    out = []
    s.open_dungeon("rfk")
    made = M.make()
    p0 = txt(made[0] if isinstance(made, tuple) else made)
    s.pump(10)
    uk, en = txt(M.UK), txt(M.EN)

    M.draw(16)
    s.pump(5)
    n = now(M)
    out.append((1, "on: ours at the journal's new size, its own file known at that size",
                n["text"] == uk and n["ours"] and n["size"] == 16 and n["rfile"] == p0 and n["rsize"] == 16, n))

    M.size = 14
    s.M.key(True)
    s.M.wait(HELD)
    n = now(M)
    out.append((2, "held: English, never in a Latin file while Cyrillic; its own file known at the latest size",
                n["text"] == en and not M.box() and n["rfile"] == p0 and n["rsize"] == 14, n))
    s.M.key(False)
    s.M.wait(0.1)
    s.pump(5)
    n = now(M)
    out.append((3, "released: Ukrainian in our file", n["text"] == uk and n["ours"] and not M.box(), n))

    M.size = 13
    s.uadd("dj off")
    n = now(M)
    out.append((4, "off: English in the journal's own file at its latest size and flags",
                n["text"] == en and not n["ours"] and n["file"] == p0 and n["size"] == 13 and n["flags"] == ""
                and not M.box(), f"{n} (its own file {p0})"))

    s.uadd("dj on")
    s.pump(20)
    n = now(M)
    out.append((5, "on again: Ukrainian in our file", n["text"] == uk and n["ours"] and not M.box(), n))
    errs = s.new_errors()
    out.append((5, "no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m in errs[:3])))
    return out


def reach(step, cut=None):
    """All steps on a fresh game; returns (steps 1..step passed, cut applied, failing names)."""
    s, M, box = game(cut)
    try:
        bad = [f"{n} {name}" for n, name, ok, _ in steps(s, M) if n <= step and not ok]
    except Exception as e:  # noqa: BLE001
        bad = [str(e)[:120]]
    was = bool(box.wasCut)
    del s, M, box
    gc.collect()
    return not bad, was, bad


def mutants(check):
    src = read_text(os.path.join(session.REPO, MODULE, "Fonts.lua"))
    base = {}
    for name, (f, old, new, step) in MUTANTS.items():
        if src.count(old) != 1:
            check(f"mutant {name}: its fix is in {f} once", False, f"found {src.count(old)} times")
            continue
        if step not in base:
            base[step] = reach(step)
        if not base[step][0]:
            check(f"mutant {name}: the base passes to step {step}", False, base[step][2][:3])
            continue
        ok, was, bad = reach(step, (f, old, new))
        check(f"mutant {name}: {f} fix cut, step {step} fails", was and not ok, f"cut={was}; failing: {bad[:3]}")


def run(check, facts=None):
    """The steps in one game, as checks named "readback <step> ..."."""
    s, M, _ = game()
    for n, name, ok, detail in steps(s, M):
        check(f"readback {n} {name}", ok, "" if ok else detail)
    del s, M
    gc.collect()


def run_checks(prove=False):
    checks = []

    def check(name, ok, detail=""):
        checks.append(Check("dj readback: " + name, bool(ok), str(detail)))

    if flow_dj.missing_addons():
        check("addons", True, "SKIP: missing " + ", ".join(flow_dj.missing_addons()))
        return checks
    run(check)
    if prove:
        mutants(check)
    return checks


if __name__ == "__main__":
    cs = run_checks("--prove" in sys.argv)
    for x in cs:
        tag = "SKIP  " if x.detail.startswith("SKIP") else ("PASS  " if x.ok else "FAIL  ")
        print(tag + x.name + (f"  [{x.detail[:300]}]" if x.detail and tag != "PASS  " else ""))
    print(f"{sum(x.ok for x in cs)}/{len(cs)} ok")
    sys.exit(0 if all(x.ok for x in cs) else 1)
