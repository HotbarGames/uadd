"""The game's ACCEPT / CANCEL words on Auctionator's StaticPopup questions (lesson 1 again, 2026-11-21).

ClassicUA alone leaves those globals English, so the "Продаж" question showed English buttons under Ukrainian
text. The core helper UADD/Popups.lua (registered by UADD_Auctionator/Popup.lua) writes our word into the button
fields of Auctionator's own entries while the global is English, and the English back on the hold key and off; it
flips a shown button both ways. Words.lua takes the same pairs (also BACK, NOT_BOUND, EMPTY) as exact texts.

  * pop: 1  at login: the fields and the shown buttons of its three questions are ours, with a Cyrillic font
            (also the bid question, whose name is in mixed case; its Skip button is Auctionator's own word).
  * pop: 2  the hold key: English while held, ours after release (fields, the shown question, one shown while held).
  * pop: 3  off: English (fields, shown, one shown while off); on again: ours, also on the question still shown
            (Rescan in Popup.lua).
  * pop: 4  ACCEPT and CANCEL are never written, and another addon's question keeps the game's words.
  * pop: 5  ACCEPT already Cyrillic (another addon set it): that word stays on and off; CANCEL is still ours.
  * pop: 6  a field the addon changed after us stays the addon's, off and on.
  * pop: 7  BACK, NOT_BOUND, EMPTY as Auctionator shows them (alone, NOT_BOUND and EMPTY grey) are ours.
  * pop: 8  a BACK already Cyrillic gets no word of ours.
Each mutant cuts one fix out of the core helper or a module file (in memory, flow_auc_popup.lua) and wants its step to fail.
The mutant "shown" wants step 1 (no Cyrillic font on the buttons): its step 2 passes now without it, since a dialog
with no record gets its buttons' English back on the hold key anyway (Unrecorded, flow_popups.py step 8).
Run by run.py after flow_auc.py.
"""
import collections
import gc
import os
import re
import sys

import flow_auc
from loader import Client, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
PRESET = "Згода"            # a made-up Cyrillic ACCEPT, as if another addon had set it
THEIRS = "Later"            # a made-up button word the addon puts in after us

STEPS = {
    1: "pop: 1 at login the fields and shown buttons of its 3 questions are ours, Cyrillic font",
    2: "pop: 2 English while held, ours after release (fields, the shown question, one shown while held)",
    3: "pop: 3 English when off (fields, shown, one shown while off), ours when on again",
    4: "pop: 4 the ACCEPT / CANCEL globals are never written; another addon's question keeps the game's words",
    5: "pop: 5 an ACCEPT already Cyrillic stays as it is on and off; CANCEL still ours",
    6: "pop: 6 a field the addon changed after us stays the addon's, off and on",
    7: "pop: 7 BACK / NOT_BOUND / EMPTY on its frames (alone, or grey) are ours",
    8: "pop: 8 a BACK already Cyrillic gets no word of ours; NOT_BOUND / EMPTY still ours",
}


def cyr(s): return re.search("[Ѐ-ӿ]", s or "") is not None  # noqa: E704


def _game(cut=None, preset=None):
    c = Client([flow_auc.STAND_IN, flow_auc._addon("UADD"), flow_auc._addon(flow_auc.MODULE)], None, "enUS")
    for f in ("flow_auc.lua", "flow_auc_sell.lua", "flow_auc_popup.lua"):
        c.lua.execute(read_text(os.path.join(HERE, f)))
    P = c.H.auc.pop
    P.setCut(cut)
    if preset:
        P.presetAccept(lua_str(preset))
        P.presetBack(lua_str(preset))
    c.start()
    c.H.pump(60)
    return c, c.H.auc, P


def _hold(M, down):
    M.key(down)
    M.wait(flow_auc.HELD)


def step1(check, M, P):
    ok, got = txt(P.fields()) == txt(P.fieldsExpect("uk")) and cyr(txt(P.fields())), [txt(P.fields())]
    for n in (1, 2, 3):
        shown, font = P.show(n)
        good = txt(shown) == txt(P.showExpect(n, "uk")) and font
        ok = ok and good
        got.append((txt(P.which(n)), txt(shown), bool(font), "want", txt(P.showExpect(n, "uk"))))
    check(STEPS[1], ok, got)
    return ok


def _flip(check, step, M, P, away, back, n_open, n_new):
    """The question n_open shown; away(): fields and it English, n_new shown then English too; back(): ours."""
    P.show(n_open)
    away()
    got = [txt(P.fields()), txt(P.open())]
    ok = got == [txt(P.fieldsExpect("en")), txt(P.showExpect(n_open, "en"))]
    new = txt(P.show(n_new)[0])
    ok = ok and new == txt(P.showExpect(n_new, "en"))
    back()
    after = [txt(P.fields()), txt(P.open())]
    ok = ok and after == [txt(P.fieldsExpect("uk")), txt(P.showExpect(n_new, "uk"))]
    check(STEPS[step], ok, {"away": got + [new], "back": after})
    return ok


def step2(check, M, P):
    return _flip(check, 2, M, P, lambda: _hold(M, True), lambda: _hold(M, False), 1, 2)


def step3(check, M, P):
    return _flip(check, 3, M, P, lambda: M.uadd("auctionator off"), lambda: M.uadd("auctionator on"), 2, 3)


def step4(check, M, P, seen):
    want = "Accept / Cancel"
    ok = all(g == want for g in seen) and txt(P.other()) == want
    check(STEPS[4], ok, {"globals": sorted(set(seen)), "other": txt(P.other())})
    return ok


def step5(check, M, P):
    got, ok = [], True
    for act in (None, lambda: _hold(M, True), lambda: _hold(M, False),
                lambda: M.uadd("auctionator off"), lambda: M.uadd("auctionator on")):
        if act:
            act()
        f, b = txt(P.field(1, "button1")), txt(P.field(1, "button2"))
        got.append((f, b))
        ok = ok and f == PRESET
    shown = txt(P.show(1)[0])
    want = txt(P.showExpect(1, "uk"))
    ok = ok and shown == want and want.startswith(PRESET + " / ") and cyr(want[len(PRESET):])
    ok = ok and txt(P.globals()).startswith(PRESET + " / ")
    check(STEPS[5], ok, {"button1/button2 on, held, released, off, on": got, "shown": shown, "want": want})
    return ok


def step6(check, M, P):
    P.theirs(lua_str(THEIRS))
    got = []
    for msg in ("auctionator off", "auctionator on"):
        M.uadd(msg)
        got.append(txt(P.field(1, "button2")))
    ok = got == [THEIRS, THEIRS] and txt(P.field(1, "button1")) == txt(P.fieldsExpect("uk")).split(" / ")[0]
    check(STEPS[6], ok, got)
    return ok


def step7(check, P, step=7):
    """Game A: each of the three ours, alone and grey. Game B (BACK Cyrillic): BACK gets no word of ours."""
    got, want = txt(P.three()), txt(P.threeExpect())
    ok = got == want and cyr(got) and (step == 7) != want.startswith("nil | nil ||")
    check(STEPS[step], ok, {"got": got, "want": want})
    return ok


def game_a(check, cut=None):
    c, M, P = _game(cut)
    seen = [txt(P.globals())]
    step7(check, P)
    for s in (step1, step2, step3):
        s(check, M, P)
        seen.append(txt(P.globals()))
    step4(check, M, P, seen)
    step6(check, M, P)
    flow_auc._errors(c, check, "pop: game A")
    return c, P


def game_b(check, cut=None):
    c, M, P = _game(cut, preset=PRESET)
    step5(check, M, P)
    step7(check, P, 8)
    flow_auc._errors(c, check, "pop: game B (ACCEPT Cyrillic)")
    return c, P


# cut -> (the step it must break, the game that reaches it)
MUTANTS = {"fields": (1, game_a), "prefix": (1, game_a), "shown": (1, game_a), "restore": (3, game_a),
           "rescan": (3, game_a), "ours": (4, game_a), "cyr": (5, game_b), "words": (7, game_a)}


def mutants(check):
    for cut, (step, game) in MUTANTS.items():
        got = {}

        def quiet(name, ok, detail=""): got[name] = ok  # noqa: E704
        c, P = game(quiet, cut)
        ok = got.get(STEPS[step])
        check(f"pop: mutant {cut} (the helper or module file without that fix, in memory only): step {step} fails",
              P.wasCut and ok is False, "cut not found" if not P.wasCut else "it passed" if ok else "")
        del c, P
        gc.collect()


def run(check, facts):
    if not flow_auc.module_there():
        return check("UADD_Auctionator is there", False, "no UADD_Auctionator/UADD_Auctionator.toc")
    for g in (lambda: game_a(check), lambda: game_b(check), lambda: mutants(check)):
        g()
        gc.collect()


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("auc: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_auc_popup.py
    cs, _ = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
