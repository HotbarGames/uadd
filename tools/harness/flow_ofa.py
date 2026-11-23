"""UADD_OneForAll on a stand-in for OneForAll (tools/harness/ofa: made-up English), steps in flow_ofa.lua.

Steps: 1 the walk is ours, in a Cyrillic font  2 the hold key gives the English, ours on release  3 off: English
(a redraw and a chat line too), on: ours  4 a window made later  5 a chat line with its prefix (OneForAll writes
to the chat window, not print)  6 a tooltip line from its files, the same line from other code stays English
7 a profile named like a word of ours stays as typed (lesson 13)  8 a map pin stays as it is  9 up to 5 real texts
of the installed addon (read at run time, never written down) show the module's own Ukrainian  10 OneForAll set to
another language: the module is off and says so  11 its Gear Planner and setup end page, made up (lesson 44):
labels set by hand at its own size, the search box's hint, a body signed "- Name".
mutants(check) cuts one fix out of the module in memory (CUT_LUA, as flow_rts_mod.py) and wants its step to fail;
they run with --prove (run.py runs the steps only).
"""
import gc
import os
import sys

import session
from loader import Addon, Client, lua_str, read_text, txt

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from flow import Check  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE, TARGET = "UADD_OneForAll", "OneForAll"
STAND_IN = Addon(TARGET, os.path.join(HERE, "ofa", TARGET), session.FLAVOR)
LAST = 8                                     # the steps in the main game; 9 real texts; 10 its own game
OTHER = 'OneForAllDB = { language = "deDE", profiles = { Zorp = {} } }'

CUT_LUA = r"""
local H, cut = HARNESS, { wasCut = false }
H.ofacut = cut
local runFile = H.runFile
function H.runFile(addon, path, code)
    if (addon == "UADD_OneForAll" or addon == "UADD") and cut.file and path:sub(-#cut.file) == cut.file then
        local a, b = code:find(cut.old, 1, true)
        if a then code, cut.wasCut = code:sub(1, a - 1) .. cut.new .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end
"""

# name: (file, old text, new text, the step that must fail)
MUTANTS = {
    "font": ("Screen.lua", "font = true,", "font = false,", 1),
    "remove": ("Module.lua", "    U.SafeCall(Screen.Remove)\n", "", 3),
    "late": ("Screen.lua", 'prefix = "OneForAll",', 'prefix = "NoSuchPrefix",', 4),
    "chat": ("Chat.lua", "    U.SafeCall(Chat().Install)\n", "", 5),
    "from": ("Chat.lua", "from = FROM,", "", 6),
    "profile": ("Screen.lua", "if not s or ProfileName(s) then", "if not s then", 7),
    "skip": ("Screen.lua", 'local SKIP_PREFIX = { "OneForAllMapPin", "OneForAllTrainerScanTip", "OneForAllWhatsNew", '
             '"OneForAllNewsShot" }',
             "local SKIP_PREFIX = {}", 8),
    "lang": ("Module.lua", 'ofaEnglish = OfaLanguage() == "enUS"', "ofaEnglish = true", 10),
    "hints": ("Screen.lua", "    hints = true,", "    hints = false,", 11),
    "signed": ("Words.lua", " or Signed(one) then", " then", 11),
    # core UADD/Font.lua (lesson 44): a label set by hand gets the Cyrillic file by hand
    "own": ("Font.lua", 'if type(was) ~= "table" or U.Locked(fs) then return false end', "do return false end", 11),
}
CORE_CUTS = {"Font.lua"}                     # files cut in the core UADD folder, not the module's


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def _addon(name):
    return Addon(name, os.path.join(session.REPO, name), session.FLAVOR)


def game(saved=None, cut=None):
    """The stand-in, UADD and the module, started; saved: OneForAll's saved data as Lua. Returns (c, M, cut box)."""
    c = Client([STAND_IN, _addon("UADD"), _addon(MODULE)], {TARGET: saved} if saved else None, "enUS")
    c.lua.execute(CUT_LUA)
    box = c.H.ofacut
    if cut:
        box.file, box.old, box.new = (lua_str(x) for x in cut[:3])
    c.lua.execute(read_text(os.path.join(HERE, "flow_ofa.lua")))
    c.start()
    c.H.pump(20)
    return c, c.H.ofa, box


def results(M, n):
    f = M.R.lang if n == 10 else M.R.gear if n == 11 else M.R[n]
    return [(txt(r[1]), r[2], txt(r[3]) if r[3] is not None else "") for r in f().values()]


def real_keys(check, M):
    name = "9 real texts of the addon show our data"
    try:
        import ofa_source
        rows, why = ofa_source.source(ofa_source.addon_dir())
    except Exception as e:  # noqa: BLE001
        return check(name, None, f"SKIP: addon not readable ({type(e).__name__})")
    n, bad = 0, []
    for row in rows or []:
        en = row[1]
        if any(ch in en for ch in "%|\n") or not en.strip():
            continue
        shown, want = M.real(lua_str(en))
        if not want:
            continue
        n += 1
        if txt(shown) != txt(want):
            bad.append(row[0])
        if n >= 5:
            break
    M.real(None)
    if not n:
        return check(name, None, f"SKIP: no plain real text ({why})")
    check(name, not bad, f"{n} real texts; wrong: {bad}")


def steps(check):
    c, M, _ = game()
    for n in range(1, LAST + 1):
        try:
            res = results(M, n)
        except Exception as e:  # noqa: BLE001
            check(f"{n} the step ran", False, str(e)[:300])
            continue
        for name, ok, detail in res:
            check(f"{n} {name}", ok, detail)
    real_keys(check, M)
    for name, ok, detail in results(M, 11):
        check(f"11 {name}", ok, detail)
    del c
    c, M, _ = game(OTHER)
    for name, ok, detail in results(M, 10):
        check(f"10 {name}", ok, detail)


def reach(step, cut=None):
    """Steps 1..step on a fresh game (step 10: its own game); returns (all passed, cut applied, failing names)."""
    c, M, box = game(OTHER if step == 10 else None, cut)
    bad = []
    try:
        for n in ((step,) if step >= 10 else range(1, step + 1)):
            bad += [f"{n} {name}" for name, ok, _ in results(M, n) if ok is False]
    except Exception as e:  # noqa: BLE001
        bad.append(str(e)[:120])
    was = bool(box.wasCut)
    del c
    gc.collect()
    return not bad, was, bad


def mutants(check):
    src, base = {}, {}
    for name, (f, old, new, step) in MUTANTS.items():
        if f not in src:
            src[f] = read_text(os.path.join(session.REPO, "UADD" if f in CORE_CUTS else MODULE, f))
        if src[f].count(old) != 1:
            check(f"mutant {name}: its fix is in {f} once", False, f"found {src[f].count(old)} times")
            continue
        if step not in base:
            base[step] = reach(step)
        if not base[step][0]:
            check(f"mutant {name}: the base passes to step {step}", False, base[step][2][:3])
            continue
        ok, was, bad = reach(step, (f, old, new))
        check(f"mutant {name}: {f} fix cut, step {step} fails", was and not ok, f"cut={was}; failing: {bad[:3]}")


def run_checks(prove=False):
    """Every check of this file. Returns (checks, facts)."""
    checks = []

    def check(name, ok, detail=""):
        skip = ok is None
        checks.append(Check("ofa: " + name, True if skip else bool(ok),
                            ("SKIP: " if skip and not str(detail).startswith("SKIP") else "") + str(detail)))
    if not module_there():
        check("module", None, f"SKIP: {MODULE} folder missing")
        return checks, {"module": False}
    steps(check)
    if prove:
        mutants(check)
    return checks, {"module": True}


if __name__ == "__main__":       # alone: python3 tools/harness/flow_ofa.py [--prove]
    cs, fs = run_checks("--prove" in sys.argv)
    for x in cs:
        tag = "SKIP  " if x.detail.startswith("SKIP") else ("PASS  " if x.ok else "FAIL  ")
        print(tag + x.name + (f"  [{x.detail[:300]}]" if x.detail and tag != "PASS  " else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} ok")
    sys.exit(0 if all(x.ok for x in cs) else 1)
