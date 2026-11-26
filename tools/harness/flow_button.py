"""Flow: the core's button fonts and box guard alone (docs/LESSONS4.md lesson 46), no module.

  1. U.ButtonCyr puts our Cyrillic copy on each state object of a button (font and size of its own, colour too),
     one copy per object; U.ButtonBack puts the button's own objects back. look=true changes nothing.
  2. A state object the addon set since stays (off and on).
  3. Protected and forbidden buttons are never touched (nor their labels).
  4. The client's own state switches (hover, Disable, Enable, SetEnabled, LockHighlight) keep the label in Cyrillic.
  5. U.SaveFont never takes a label's font for one set by hand (the client changes it with the state), so going
     back never pins a Latin file on it.
  6. A font saved while our copy is on is the button's own object, never our copy.
  7. The box guard (by width, H.glyphWidths) leaves alone a Cyrillic file it does not know by name, a family on a
     plain text, and a known Cyrillic file.
  8. It finds boxes on a watched text and repairs them, once; guardLast.box keeps date, version and sample.
  9. A repair that does not take: English, marked, our font not put on again; guardLast.boxfail.
 10. The cap of 64 copies holds; a button that would pass it stays as it was (whole or nothing).
 11. A state object the addon set while the label was empty is our copy before our text goes on (no later look).
 12. Back on a label the addon gave a new object while ours was on: the addon's newer object (U.FontBase).
 13. The cap reached while ours is on, the addon sets a new state object: English (U.BoxGiveUp), never boxes.
  * Mutants (--prove): each step fails with its fix cut out of the core.

Run alone: python3 tools/harness/flow_button.py [--prove]
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import session  # noqa: E402
from flow import Check  # noqa: E402
from flow_pawn_game import errors  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402


def game(cut=None, cuts=None, quiet=False):
    c = Client([Addon("UADD", os.path.join(session.REPO, "UADD"), session.FLAVOR)], None, "enUS")
    c.H.glyphWidths = True              # before the start: the box guard measures each file once
    if quiet:
        c.H.boxQuiet = True             # a mutant's boxes are its point, not a finding
    for f in ("flow_button.lua", "flow_button_guard.lua"):
        c.lua.execute(read_text(os.path.join(HERE, f)))
    M = c.H.btn
    for name, (file, old, new) in (cuts or {}).items():
        M.addCut(lua_str(name), lua_str(file), lua_str(old), lua_str(new))
    M.cut = lua_str(cut) if cut else None
    c.start()
    c.H.pump(20)
    return c, M


def _step(name, fn):
    def step(check, c, M):
        bad = [txt(x) for x in c.lines(getattr(M, fn)())]
        check(name, not bad, "; ".join(bad[:4]))
        return not bad
    step.__name__ = fn
    return step


on_back = _step("1 helper: our copies on, the button's own back", "onBack")
kept = _step("2 a state object the addon set since is kept", "kept")
locked = _step("3 protected and forbidden buttons untouched", "locked")
states = _step("4 native state switches keep Cyrillic", "states")
save_font = _step("5 SaveFont never pins a Latin font on a label", "saveFont")
font_base = _step("6 a font saved while ours is on is the button's own", "fontBase")
box_fine = _step("7 box guard: no alarm on Cyrillic file, family, arialn", "boxFine")
box_find = _step("8 box guard finds and repairs boxes; guardLast.box", "boxFind")
box_fail = _step("9 box guard: a repair that fails gives English; guardLast.boxfail", "boxFail")
cap = _step("10 the cap of 64 copies holds, whole or nothing", "cap")
empty_then = _step("11 a state object set while the label is empty is ours before our text", "emptyThen")
label_back = _step("12 back on a label: the addon's newer object, not the saved one", "labelBack")
late_before = _step("13 before the cap: our text on a button", "lateBefore")
late = _step("13 the cap reached, a new state object: English, never boxes", "late")


def late_game(check, c, M):
    """Step 13 needs its button before the cap and the cap itself (game B, and its mutant)."""
    late_before(check, c, M)
    cap(check, c, M)
    return late(check, c, M)


def run(check, facts):
    c, M = game()
    for step in (on_back, kept, locked, states, save_font, font_base, box_fine, box_find, box_fail, empty_then,
                 label_back):
        step(check, c, M)
    say = [x for x in c.chat() if "вартовий" in x]
    fixed, english = [x for x in say if "виправлено" in x], [x for x in say if "англійською" in x]
    check("8-9 the box guard told the player once per kind", len(say) == 2 and len(fixed) == len(english) == 1,
          say[:3])
    facts["copies"] = int(c.ev("UADD.ButtonFonts()"))
    errors(c, check, "game A")

    c, M = game()
    late_game(check, c, M)
    facts["cap"] = int(c.ev("UADD.ButtonFonts()"))
    errors(c, check, "game B (cap)")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("button: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


# ── Mutants: each cuts one fix out of the core; its step must fail ───────────────────────────────

CUTS = {
    "back": ("UADD:ButtonFont.lua", "if Get(btn, s) == c then Set(btn, s, base[c]) end", "Set(btn, s, base[c])", kept),
    "free": ("UADD:ButtonFont.lua", "local free = Free(btn)", "local free = true", locked),
    "states": ("UADD:ButtonFont.lua", "local ok, yes = pcall(Put, btn, look)", "local ok, yes = true, true", states),
    "savefont": ("UADD:Font.lua", " and not U.LabelButton(fs) then", " then", save_font),
    # The core's side of BugSack's old Fresh() (flow_bs.py, lesson 32 again): never save our copy as its own.
    "fontbase": ("UADD:Font.lua", "local o = U.FontBase(fs.GetFontObject and fs:GetFontObject() or nil)",
                 "local o = fs.GetFontObject and fs:GetFontObject() or nil", font_base),
    "name": ("UADD:BoxGuard.lua", "    local gap = math.abs(box - good)\n"
             "    return gap >= 0.12 * good and math.abs(w - box) <= 0.25 * gap",
             "    return not U.IsCyrFont(path)", box_fine),
    "repair": ("UADD:BoxGuard.lua", "        Repair(fs)\n", "", box_find),
    "cap": ("UADD:ButtonFont.lua", "        if made >= CAP then return nil end\n", "", cap),
    # The old order: the states only once the label shows Cyrillic.
    "empty": ("UADD:ButtonFont.lua", "    local states = U.ButtonCyr(btn)\n    local fs = btn:GetFontString()\n",
              "    local fs = btn:GetFontString()\n    local t0 = fs and U.Plain(fs:GetText())\n"
              "    if not t0 or not t0:find(\"[\\208\\209\\210]\") then return end\n"
              "    local states = U.ButtonCyr(btn)\n", empty_then),
    "labelback": ("UADD:Font.lua", "if own ~= o then U.LabelOn(fs, own) end", "", label_back),
    "giveup": ("UADD:ButtonFont.lua", "if not states then return U.BoxGiveUp and U.BoxGiveUp(fs) end", "", late_game),
}


def prove():
    """Each cut: a fresh game without that fix; the step must fail. Returns the exit code."""
    cuts = {k: v[:3] for k, v in CUTS.items()}
    bad = []
    for name, (_, _, _, step) in CUTS.items():
        c, M = game(cut=name, cuts=cuts, quiet=True)
        ok = step(lambda *_: None, c, M)
        was = bool(M.wasCut)
        print(("ok    " if was and ok is False else "FAIL  ") + f"cut {name}: cut={was}, step {step.__name__} ok={ok}")
        if not (was and ok is False):
            bad.append(name)
    print(f"{len(CUTS) - len(bad)}/{len(CUTS)} cuts break their step")
    return 1 if bad else 0


if __name__ == "__main__":       # alone: python3 tools/harness/flow_button.py [--prove]
    if "--prove" in sys.argv:
        sys.exit(prove())
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:400]}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
