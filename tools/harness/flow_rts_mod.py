"""H2: the module checks of flow_rts.py, on the real UADD_RoadToSixty (steps in flow_rts_mod.lua), and its mutants.

module_check(n, check, c, M) runs step n in the module's game. Step 1 also puts up to 5 real texts of the
installed addon (read at run time, never written down) on the title and wants the module's own Ukrainian.
mutants(check) cuts one guard out of the module in memory (as flow_dci_mut.py) and wants a step to fail.
"""
import gc
import os

from loader import lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = "UADD_RoadToSixty"

CUT_LUA = r"""
local H, cut = HARNESS, { wasCut = false }
H.rtscut = cut
local runFile = H.runFile
function H.runFile(addon, path, code)
    if addon == "UADD_RoadToSixty" and cut.file and path:sub(-#cut.file) == cut.file then
        local a, b = code:find(cut.old, 1, true)
        if a then code, cut.wasCut = code:sub(1, a - 1) .. cut.new .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end
"""

# name: (file, old text, new text, the step that must fail)
MUTANTS = {
    "prefix": ("Chat.lua", "if #s > #p and sub(s, 1, #p) == p then", "if true then", 10),
    "from": ("Chat.lua", "from = FROM,", "", 10),
    "nameslot": ("Words.lua", 'ns.SORT[k] == "f"', "true", 6),
    "font": ("Screen.lua", "font = true,", "font = false,", 5),
    "remove": ("Module.lua", "    U.SafeCall(Screen.Remove)\n", "", 4),
    "fault": ("Words.lua", "local ok, uk = pcall(Look, s)", "local ok, uk = true, Look(s)", 13),
    "glue": ("Words.lua", "(c == 39 and FreeName(before))", "nil", 7),
    # fixes of 2026-11-22 (A-F)
    "popup": ("Words.lua", "return Whole(s) or NameSlot(s) or Lines(s)", "return Whole(s) or Lines(s)", 10),
    "mark": ("Words.lua", 'while e >= a and find(s, "^[%?!%.,]", e) do e = e - 1 end', "", 10),
    "spaced": ("Chat.lua", "local PREFIXES = { PREFIX, SPACED }", "local PREFIXES = { PREFIX }", 10),
    "canvas": ("Screen.lua", "if not f then f = Container(cat) end", "", 1),
    "names": ("Screen.lua", "if type(fs) == \"table\" and NameLabel(fs) then return nil, false end", "", 7),
    # lesson 43: its What's New window stays English (the old code: a root, no skip)
    "news": ("Screen.lua", "local SKIP = { RoadToSixtyWhatsNew = true }",
             'local SKIP = {} ROOTS[#ROOTS + 1] = "RoadToSixtyWhatsNew"', 1),
}


def results(c, n):
    R = c.H.rtsmod
    return [(txt(r[1]), r[2], txt(r[3]) if r[3] is not None else "") for r in R[n]().values()]


def real_keys(check, c):
    try:
        import rts_source
        rows, why = rts_source.source(rts_source.addon_dir())
    except Exception as e:  # noqa: BLE001
        return check("1 module: real texts of the addon show our data", None, f"SKIP: addon not readable ({type(e).__name__})")
    R, n, bad = c.H.rtsmod, 0, []
    for row in rows or []:
        en = row[1]
        if any(ch in en for ch in "%|\n") or not en.strip():
            continue
        shown, want = R.real(lua_str(en))
        if not want:
            continue
        n += 1
        if txt(shown) != txt(want):
            bad.append(row[0])
        if n >= 5:
            break
    R.real(None)
    if not n:
        return check("1 module: real texts of the addon show our data", None, f"SKIP: no plain real text ({why})")
    check("1 module: real texts of the addon show our data", not bad, f"{n} real texts; wrong: {bad}")


def load(c):
    for f in ("flow_rts_mod.lua", "flow_rts_mod2.lua"):
        c.lua.execute(read_text(os.path.join(HERE, f)))


def module_check(n, check, c, M):
    if n == 1:
        load(c)
    try:
        res = results(c, n)
    except Exception as e:  # noqa: BLE001
        return check(f"{n} module: the step ran", False, str(e)[:300])
    for name, ok, detail in res:
        check(f"{n} module: {name}", None if ok is None else bool(ok), detail)
    if n == 1:
        real_keys(check, c)


def game(cut=None):
    import flow_rts as F
    real, box = F.Client, {}

    def client(*a, **k):
        cl = real(*a, **k)
        cl.lua.execute(CUT_LUA)
        t = box["t"] = cl.H.rtscut
        if cut:
            t.file, t.old, t.new = (lua_str(x) for x in cut[:3])
            cl.H.boxQuiet = True         # a mutant's boxes are wanted (step 5's "font"), not in the segment's check
        return cl
    F.Client = client
    try:
        c, M = F.game(True)
    finally:
        F.Client = real
    load(c)
    return c, box["t"]


def reach(step, cut=None):
    """Steps 1..step on a fresh game; returns (all passed, cut applied, failing names)."""
    c, t = game(cut)
    bad = []
    try:
        for n in range(1, step + 1):
            bad += [f"{n} {name}" for name, ok, _ in results(c, n) if ok is False]
    except Exception as e:  # noqa: BLE001
        bad.append(str(e)[:120])
    was = bool(t.wasCut)
    del c
    gc.collect()
    return not bad, was, bad


def mutants(check):
    src = {}
    for name, (f, old, new, step) in MUTANTS.items():
        if f not in src:
            src[f] = read_text(os.path.join(os.path.dirname(HERE), "..", MODULE, f))
        if src[f].count(old) != 1:
            check(f"mutant {name}: its guard is in {f} once", False, f"found {src[f].count(old)} times")
            continue
    base = {}
    for name, (f, old, new, step) in MUTANTS.items():
        if src[f].count(old) != 1:
            continue
        if step not in base:
            base[step] = reach(step)
        if not base[step][0]:
            check(f"mutant {name}: the base passes to step {step}", False, base[step][2][:3])
            continue
        ok, was, bad = reach(step, (f, old, new))
        check(f"mutant {name}: {f} guard cut, step {step} fails", was and not ok, f"cut={was}; failing: {bad[:3]}")
