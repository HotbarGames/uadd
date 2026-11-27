"""UADD_WhatsTraining, game A's font-object step (flow_whatstraining.py runs it after the late window).

What's Training?'s own labels are made from a font object (CreateFontString with a font template), and its
skills list's pooled rows switch object while shown (a header's, then a recipe's). The client keeps a file set by
hand over SetFontObject (tools/harness/client_facts.py), so a Cyrillic file put on by hand and given back by the
object alone stays: held and off would show the English in our file, at the size it had before the switch.
The step wants ours in a Cyrillic file at each label's own size, also after the switch, and, held and off, the
English in the label's own file at its latest size (M.objLabels, M.objState in flow_whatstraining.lua).
A label the addon set by hand (ours on by hand) that then takes another object while ours is on: held and off
give back that object (M.handLabel, mutant `handobj`).

  python3 tools/harness/flow_whatstraining_objs.py --prove   (or flow_whatstraining.py --prove): each mutant
  cuts one part of the fix out of UADD_WhatsTraining/Screen.lua and wants the step to fail.
"""
import gc
import sys

import flow_whatstraining as fw
from loader import lua_str, txt

OBJ_A, OBJ_B = ("fonts\\morpheus.ttf", 13), ("fonts\\skurri.ttf", 10)   # flow_whatstraining.lua OWN


def _objs(M):
    return {txt(k): (txt(v[1]), txt(v[2]), float(v[3]), bool(v[4])) for k, v in M.objState().items()}


def objects(check, M, p):
    """The two checks; returns True when both pass."""
    want = fw._want(M, p["label"])
    own = {"plain": OBJ_A, "row": OBJ_B}
    sizes = {k: v[1] for k, v in own.items()}

    def ours(s, size):
        return len(s) == 2 and all(s[k][0] == want and s[k][3] and s[k][2] == size[k] for k in s)

    def english(s):
        return len(s) == 2 and all(s[k][0] == p["label"] and (s[k][1], s[k][2]) == own[k] for k in s)

    M.objLabels(lua_str(p["label"]))
    first = _objs(M)
    M.objSwitch()
    switched = _objs(M)
    ok1 = ours(first, {"plain": 13, "row": 13}) and ours(switched, sizes)
    check("labels from a font object: ours in a Cyrillic file at their own size, also after the row's object "
          "switch (13 to 10)", ok1, (first, switched))
    M.key(True)
    held = _objs(M)
    M.key(False)
    back = _objs(M)
    M.uadd("whatstraining off")
    off = _objs(M)
    M.uadd("whatstraining on")
    again = _objs(M)
    ok2 = english(held) and english(off) and ours(back, sizes) and ours(again, sizes)
    check("labels from a font object, held and off: the English in its own file at its latest size; key up and "
          "on: ours again", ok2, (held, off, back, again))
    return ok1 and ok2 and hand(check, M, p, want)


def _hand(M):
    v = M.handState()
    return (txt(v[1]), txt(v[2]), float(v[3]), bool(v[4]), bool(v[5]))


def hand(check, M, p, want):
    """A label whose font What's Training? set by hand (ours on by hand, U.CyrOnOwn), then object B set while
    ours is on (the client keeps our file): held and off give back B, with its own hand-set file and size."""
    M.handLabel(lua_str(p["label"]))
    first = _hand(M)
    M.handSwitch()
    switched = _hand(M)
    M.key(True)
    held = _hand(M)
    M.key(False)
    back = _hand(M)
    M.uadd("whatstraining off")
    off = _hand(M)
    M.uadd("whatstraining on")
    again = _hand(M)

    def ours(s):
        return s[0] == want and s[3] and s[2] == OBJ_A[1]

    def english(s):
        return s[0] == p["label"] and (s[1], s[2]) == OBJ_A and s[4]

    ok = ours(first) and ours(switched) and english(held) and ours(back) and english(off) and ours(again)
    check("a label set by hand, then a font object set while ours is on: held and off, the English in its own "
          "file and size on that new object; key up and on: ours again", ok, (first, switched, held, back, off, again))
    return ok


# Each cuts one part of the fix out of Screen.lua as it loads.
CUTS = {
    # going back: the record dropped, nothing put back (English left in our file)
    "unfix": ("Screen.lua", "    if kept[fs] then pcall(U.CyrUnfix, fs, kept) end\n", "    kept[fs] = nil\n"),
    # a font object switch while ours is on: no fix again (Cyrillic in the new object's Latin file)
    "refix": ("Screen.lua", "    local ok, took = pcall(Cyr, fs)", "    local ok, took = true, true"),
    # a new font object while our hand-set file stays: the record keeps the old object (held and off give it back)
    "handobj": ("Screen.lua", "    U.SafeCall(NewObject, self)\n", ""),
}


def _setup():
    """The texts the checks use, as flow_whatstraining.run() picks them; None when What's Training? or our
    Ukrainian is missing."""
    if not fw.module_there():
        return None
    src = fw.rows()
    if not src:
        return None
    exact, temps = fw.shipped()
    p = fw.picks(src, exact, temps)
    if not p:
        return None
    p["title"] = fw.title(exact) or p["label"]
    return p


def _cutter(name):
    def pre(c, M):
        file, old, new = CUTS[name]
        M.addCut(lua_str(name), lua_str(file), lua_str(old), lua_str(new))
        M.cut = lua_str(name)
        c.H.boxQuiet = True             # a mutant's boxes are its point, not a finding
    return pre


def prove():
    """Each cut: a fresh game A without that fix; the font-object step must fail. Returns the exit code."""
    p = _setup()
    if not p:
        print("skipped: What's Training? or our Ukrainian is missing, nothing to prove")
        return 0
    bad = []
    for name in CUTS:
        c, M = fw._game([fw._stand_in(), fw._addon("UADD"), fw._addon(fw.MODULE)], "enUS", p, pre=_cutter(name))
        M.later()
        ok = objects(lambda *_: None, M, p)
        cut = bool(M.wasCut)
        print(("ok    " if cut and not ok else "FAIL  ") + f"cut {name}: cut={cut}, font-object step ok={ok}")
        if not (cut and not ok):
            bad.append(name)
        del c, M
        gc.collect()
    print(f"{len(CUTS) - len(bad)}/{len(CUTS)} cuts break their step")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(prove())
