"""UADD_Mastercraft: Mastercraft's SetFont that reads our file back (docs/LESSONS5.md lesson 48, last rule), in a
game of its own (called from flow_mastercraft.run; its mutants from flow_mastercraft --prove).

Mastercraft's fitters set a size by SetFont with the font GetFont gives. While our Cyrillic font is on, that hands
our file to its SetFont wrappers, which keep it (ns.Text in mcPath, ns.RawText in a local of its own) and use it
again later: a name in another alphabet and back, a language switch. Two strings shaped like its own
(flow_mc_readback.lua), the English from the installed addon by hash key:

  * on, then its fitter reads the font back at a new size: our Cyrillic font at that size; its kept file is
    never ours;
  * hold key: its English in its own file at its latest size; released: ours again at that size;
  * a read-back again, then off: its English in its own file at its latest size;
  * after off, a name in another alphabet and back, and a language switch's SetFont of its kept file: its own
    file (never ours with its English); Cyrillic is never in a Latin file at any step.
"""
import gc
import os

import hashtext
import session
from loader import Client, lua_str, read_text, txt
from flow_mc_code import GREY, KEYS

HERE = os.path.dirname(os.path.abspath(__file__))
GREEK = "αβγ"          # a name in another alphabet (its script font goes on, then off again)
STEP = "read back: "
# Each cuts one part of the fix in UADD_Mastercraft (Screen.lua, Kept.lua); the named step must fail.
MUTANTS = {
    # its SetFont while ours is on is no longer kept: the raw line goes back to its old size
    "readback_size": ("Screen.lua",
                      "    if fonted[fs] then U.SafeCall(K.Asked, fs, fonted[fs], path, size, flags) end\n",
                      "", STEP + "hold key"),
    # the font goes back by the game's setter only (as before): the raw line's own kept file stays ours
    "readback_kept": ("Kept.lua", '    local set = rawget(fs, "SetFont")\n', "    local set = nil\n",
                      STEP + "after off"),
}


def _game(F, cut=None):
    c = Client([F._stand_in(), F._addon("UADD"), F._addon(F.MODULE)], None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_mastercraft.lua")))
    c.lua.execute(read_text(os.path.join(HERE, "flow_mc_readback.lua")))
    if cut:
        import mc_prove
        c.lua.execute(mc_prove.CUT_LUA)
        m = c.H.mccut
        m.addon, m.file, m.old, m.new = map(lua_str, (F.MODULE,) + tuple(cut))
        c.H.boxQuiet = True
    c.start()
    c.H.pump(60)
    return c, c.H.mc, c.H.mcRead


def steps(check, F, src, cut=None):
    en = {hashtext.key(e): e for e, _ in src}
    if KEYS["prof"] not in en or KEYS["empty"] not in en:
        check(STEP + "each text read from the installed Mastercraft by its key", False, "")
        return False
    c, M, R = _game(F, cut)
    own = txt(R.OWN)
    loc_en, empty = en[KEYS["prof"]], en[KEYS["empty"]]
    raw_en = GREY + empty + "|r"
    loc_uk = txt(R.want(lua_str(KEYS["prof"])))
    raw_uk = GREY + txt(R.want(lua_str(KEYS["empty"]))) + "|r"
    R.loc("loc", lua_str(loc_en))
    R.raw(lua_str(empty), lua_str(raw_en))
    mixed = []

    def st(name, where):
        t, p, s, kept, cyr, ours = R.state(name)
        t, p, kept = txt(t), txt(p), txt(kept)
        if cyr and not ours:
            mixed.append((where, name, p))
        return t, p, round(float(s), 1), kept, bool(ours)

    def look(where):
        return st("loc", where), st("raw", where)

    loc, raw = look("on")
    check(STEP + "on: our words in our font at its sizes", loc[0] == loc_uk and loc[4] and loc[2] == 12
          and raw[0] == raw_uk and raw[4] and raw[2] == 11, (loc, raw))
    R.readBack("loc", 10)
    R.readBack("raw", 9)
    loc, raw = look("read back")
    check(STEP + "its fitter sets a new size with our file: ours stays at that size, its kept file is its own",
          loc[4] and loc[2] == 10 and loc[3] == own and raw[4] and raw[2] == 9, (loc, raw))
    M.key(True)
    loc, raw = look("hold")
    check(STEP + "hold key: its English in its own file at its latest size",
          loc == (loc_en, own, 10, own, False) and raw == (raw_en, own, 9, "", False), (loc, raw))
    M.key(False)
    loc, raw = look("release")
    check(STEP + "hold key up: ours again at its latest size",
          loc[0] == loc_uk and loc[4] and loc[2] == 10 and raw[0] == raw_uk and raw[4] and raw[2] == 9, (loc, raw))
    R.readBack("loc", 9)
    R.readBack("raw", 10)
    M.uadd("mastercraft off")
    loc, raw = look("off")
    check(STEP + "off after another read-back: its English in its own file at its latest size",
          loc == (loc_en, own, 9, own, False) and raw == (raw_en, own, 10, "", False), (loc, raw))
    for name, text in (("loc", loc_en), ("raw", raw_en)):
        R.set(name, lua_str(GREEK))
        R.set(name, lua_str(text))
    R.again("loc")
    loc, raw = look("after off")
    check(STEP + "after off: a name in another alphabet and back, a language switch: its own file, never ours",
          loc == (loc_en, own, 9, own, False) and raw == (raw_en, own, 10, "", False), (loc, raw))
    M.uadd("mastercraft on")
    loc, raw = look("on again")
    check(STEP + "on again: ours at its latest sizes", loc[0] == loc_uk and loc[4] and loc[2] == 9
          and raw[0] == raw_uk and raw[4] and raw[2] == 10, (loc, raw))
    check(STEP + "Cyrillic never in a Latin file", not mixed, mixed[:3])
    F._errors(c, check, STEP.strip(": ") + " game")
    was = bool(c.H.mccut.wasCut) if cut else True
    del c, M, R
    gc.collect()
    return was


def run(check, F, src):
    steps(check, F, src)


def mutants(check, F, src):
    for name, (f, old, new, step) in MUTANTS.items():
        n = read_text(os.path.join(session.REPO, F.MODULE, f)).count(old)
        if n != 1:
            check(f"mutant {name}: its fix is in {f} once", False, f"found {n} times")
            continue
        got = []
        was = steps(lambda what, ok, detail="": got.append((what, ok)), F, src, (f, old, new))
        bad = [w for w, ok in got if not ok]
        check(f"mutant {name}: {f} fix cut, '{step}' fails", was and any(w.startswith(step) for w in bad),
              f"cut={was}; failed: {bad}")
