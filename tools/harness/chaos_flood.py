"""The chaos test's BG flood (docs/LESSONS3.md, lesson 35): chaos.py runs it in every module's game.

A streamer saw many Lua errors in a battleground. There every chat line of the game and every new frame passes
UADD's hooks on the game-wide paths, and some lines are secret (any string op on one throws). So, from code of an
addon UADD does not translate (chaos_flood.lua):
  * flood: FLOOD_N mixed chat lines (system lines, links, colours, odd bytes, 5 KB lines, Cyrillic, values that
    are no string, every 7th string line secret). No error escapes; each line arrives exactly once, byte for
    byte; no Translate, no Bare and no debugstack for any of them; all of it within a time bound (clock.py);
  * odd frames: the core CreateFrame hook (Attune's, LayerSwap's, Mastercraft's and TomTom's fns) fed odd
    arguments (nil, numbers, a name with no frame, tables that are no frame). No error, no report, in bound.
  * in a BG: no chat wrap and no print handler of ours in the instance, lines and prints through once (a secret
    one too), both back outside, a later addon's wrap or handler kept. Mutants 'unwrap' and 'print gate' take
    each instance gate out (UADD/Lines.lua, UADD/Print.lua) and want their check to fail.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import clock  # noqa: E402

FLOOD_N = 10000
FLOOD_MS = 150.0      # measured 2026-11-21: 25-40 ms for 10k lines on an idle PC; about 4x that, stretched by load
ODD_ROUNDS = 1000     # 9 odd calls a round
ODD_MS = 40.0         # measured 2026-11-21: 5-10 ms for 9k calls


def flood(r):
    """FLOOD_N chat lines of a BG through the module's game."""
    r.C.WrapBare()
    threw, lost, changed, nsec, tr, bare, ds, ms, first = r.C.Flood(FLOOD_N)
    case = f"BG flood ({FLOOD_N} lines, {int(nsec)} secret)"
    detail = str(first or "")[:160]
    r.ok(f"{case}: no error escapes", int(threw) == 0, f"{int(threw)} threw; {detail}")
    r.ok(f"{case}: every line arrives exactly once", int(lost) == 0, f"{int(lost)} lost or doubled; {detail}")
    r.ok(f"{case}: other code's lines arrive byte for byte", int(changed) == 0, f"{int(changed)} changed; {detail}")
    r.ok(f"{case}: no Translate, Bare or debugstack for them", int(tr) + int(bare) + int(ds) == 0,
         f"Translate {int(tr)}, Bare {int(bare)}, debugstack {int(ds)}; {r.C.Where()}")
    limit, ref = clock.bound(FLOOD_MS)
    r.ok(f"{case}: under {FLOOD_MS:g} ms in all", ms <= limit, f"{ms:.0f} ms; {clock.note(limit, ref)}")
    r.no_errors(case)


def odd_frames(r):
    """The core CreateFrame hook with odd arguments."""
    threw, reports, ms = r.C.OddFrames(ODD_ROUNDS)
    case = f"CreateFrame hook, {ODD_ROUNDS * 9} odd calls"
    r.ok(f"{case}: the core hook is there", int(threw) >= 0, "UADD.NewFrameRun missing")
    r.ok(f"{case}: no error escapes, none reported", int(threw) == 0 and int(reports) == 0,
         f"{int(threw)} threw, {int(reports)} reported; {r.C.Where()}")
    limit, ref = clock.bound(ODD_MS)
    r.ok(f"{case}: under {ODD_MS:g} ms in all", ms <= limit, f"{ms:.0f} ms; {clock.note(limit, ref)}")
    r.no_errors(case)


def instance(r):
    """A BG and back: in an instance the chat window has no AddMessage field of ours (it taints the game's chat
    path, where every line is secret); outside it is wrapped again. Returns True when it ran wrapped."""
    wrapped, gone, passed, back, kept, through, again = (bool(x) for x in r.C.Instance())
    case = "in a BG"
    r.ok(f"{case}: the chat window has no AddMessage field of ours", gone, "our wrap is still on in the instance")
    r.ok(f"{case}: lines pass once, byte for byte, a secret one too", passed, "a line lost, doubled or changed")
    if wrapped:
        r.ok(f"{case}: wrapped again outside", back, "no wrap after leaving the instance")
        r.ok(f"{case}: a later addon's wrap is kept, lines pass it once", kept and through, (kept, through))
        r.ok(f"{case}: wrapped again when it comes off", again, "no wrap after the later addon came off")
    r.no_errors(case)
    printed(r)
    return wrapped


def printed(r):
    """The core print handler (UADD/Print.lua) in a BG and back: ours is not set in the instance."""
    wrapped, odd, gone, passed, back, kept, through, again = (bool(x) for x in r.C.PrintInstance())
    case = "in a BG, print"
    r.ok(f"{case}: odd prints pass once outside (a secret one, several values, no string)", odd,
         "a print lost, doubled or changed")
    r.ok(f"{case}: no print handler of ours in the instance", gone, "our handler is still set in the instance")
    r.ok(f"{case}: prints pass once, byte for byte, a secret one too", passed, "a print lost, doubled or changed")
    if wrapped:
        r.ok(f"{case}: ours set again outside", back, "no handler of ours after leaving the instance")
        r.ok(f"{case}: a later addon's handler is kept, prints pass it once", kept and through, (kept, through))
        r.ok(f"{case}: ours set again when it comes off", again, "no handler of ours after the later one came off")
    r.no_errors(case)


# The mutants: the instance gate taken out of U.ChatHook's Sync (UADD/Lines.lua) and of U.PrintHook's (Print.lua).
CUT = ("    if inside then Unwrap(true) elseif nLive > 0 then Wrap() end",
       "    if nLive > 0 and not inside then Wrap() end")
PRINT_CUT = ("    if inside then Unset(true) elseif nLive > 0 then Set() end",
             "    if nLive > 0 and not inside then Set() end")
MUTANTS = (("unwrap", CUT, "Instance", "wraps the chat", "the instance unwrap", ()),
           ("print gate", PRINT_CUT, "PrintInstance", "sets a print handler", "the print handler's instance gate",
            ("UADD_Auctionator", "UADD_Attune")))       # the modules that translate prints: tried first


def prove(check, spied, recipes, only):
    """Each mutant in the first game where it applies: its "in a BG" check must fail there."""
    for name, cut_pair, op, what, fix, first in MUTANTS:
        for folder, _, build in sorted(recipes, key=lambda x: x[0] not in first):
            if only and folder != only:
                continue
            spied.cut = cut_pair
            try:
                c = build()
            finally:
                spied.cut = None
            if c is None:
                continue
            C = c.lua.globals().CHAOS
            res = getattr(C, op)()
            if not bool(res[0]):
                continue
            cut, gone = bool(C.wasCut), bool(res[2 if op == "PrintInstance" else 1])
            check(f"chaos: {folder} in a BG, mutant '{name}': the check fails without {fix}",
                  cut and not gone, f"cut {'made' if cut else 'NOT made'}; ours gone anyway: {gone}")
            break
        else:
            if not only:
                check(f"chaos: in a BG, mutant '{name}': some game {what}", False, "no recipe did")
