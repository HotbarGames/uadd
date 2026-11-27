"""UADD_DialogueUI, game F: the hold key gives DialogueUI's own font back (lessons 32, 45).

  * Held: every shown text exactly DialogueUI's English, in its own font object, file, size and flags;
    let go: our words in a Cyrillic font again.
  * The font size setting changed while held, as the client does it (the DUIFont_* objects change; a
    FontString that once got a file by hand keeps it): let go, ours at the new size; held again, its
    own font at the new size; off, exact fonts.
  * DialogueUI sets another font object on a FontString while held: let go, held again and off give
    back that object, never the one before it (mutant `stale`).
  * --prove (python3 tools/harness/flow_dialogueui.py --prove): each cut takes one fix out of the
    module in memory and wants this step to fail.
"""
import gc
import os

from loader import Client, lua_str, read_text

CUTS = {
    # The hold key leaves our Cyrillic file on DialogueUI's English (the old way).
    "holdback": ("Texts.lua", "ns.Fonts.Back(fs)", ""),
    # Let go after a size change while held: a new record of the stale size the hold put back.
    "heldsize": ("Fonts.lua", "local o = was and was.back", "local o = false and was.back"),
    # Let go after DialogueUI set another font object while held: the stale record (old object) kept.
    "stale": ("Fonts.lua", "UADD.SafeFontObject(fs) == o and SamePath((o:GetFont()), p)", "true"),
}


def hold(F, c, M, check):
    """The step. Returns True when every check of it passed."""
    ok = [True]

    def chk(name, good, detail=""):
        ok[0] = ok[0] and bool(good)
        check(name, good, detail)
    F._all_uk(c, M, chk, "hold font: on")
    M.hold(True, F.HELD)
    F._all_en(c, M, chk, "hold font: Shift held, DialogueUI's own font", fonts="shown")
    M.objectsSize(16)
    M.hold(False, F.HELD)
    F._all_uk(c, M, chk, "hold font: size 16 set while held, then let go")
    chk("hold font: let go, ours at the new size", int(M.size("questType") or 0) == 16, M.size("questType"))
    M.hold(True, F.HELD)
    F._all_en(c, M, chk, "hold font: held again, its own font at size 16", fonts="shown")
    M.hold(False, F.HELD)
    F._all_uk(c, M, chk, "hold font: let go again")
    # DialogueUI gives a FontString another font object while held (a pooled one reused; same font):
    # the release takes that object, so held again and off give it back, never the old one.
    M.hold(True, F.HELD)
    M.reobject("questType", "DUIFont_Quest_Paragraph")
    M.hold(False, F.HELD)
    F._all_uk(c, M, chk, "hold font: another font object set while held, then let go")
    M.hold(True, F.HELD)
    F._all_en(c, M, chk, "hold font: held again after a new font object", fonts="shown")
    chk("hold font: held again, the font object set while held", M.objectIs("questType", "DUIFont_Quest_Paragraph"))
    M.hold(False, F.HELD)
    M.uadd("dialogueui off")
    M.wait(0.3)
    F._all_en(c, M, chk, "hold font: off after a size change while held")
    return ok[0]


def _client(F, cut=None):
    c = Client([F.STAND_IN, F._uadd(), F._module()], None, "enUS")
    c.lua.execute(read_text(os.path.join(F.HERE, "flow_dialogueui.lua")))
    M = c.H.dui
    if cut:
        file, old, new = CUTS[cut]
        M.addCut(lua_str(cut), lua_str(file), lua_str(old), lua_str(new))
        M.cut = lua_str(cut)
    c.start()
    c.H.pump(60)
    M.showAll()
    M.wait(F.WAIT)
    return c, M


def game_f(F, check):
    c, M = _client(F)
    hold(F, c, M, check)
    F._errors(c, check, "game F (hold font)")
    del c, M
    gc.collect()


def prove(F):
    """Each cut: a fresh game without that fix; the step must fail. Returns the exit code."""
    bad = []
    for name in CUTS:
        c, M = _client(F, name)
        ok = hold(F, c, M, lambda *_: None)
        cut = bool(M.wasCut)
        print(("ok    " if cut and ok is False else "FAIL  ") + f"cut {name}: cut={cut}, step hold ok={ok}")
        if not (cut and ok is False):
            bad.append(name)
        del c, M
        gc.collect()
    print(f"{len(CUTS) - len(bad)}/{len(CUTS)} cuts break their step")
    return 1 if bad else 0
