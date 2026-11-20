"""UADD_Pawn on a stand-in for Pawn (tools/harness/pawn). Pawn's licence allows none of its English here:
the game (flow_pawn_game.py) runs the installed Pawn's Localization.lua and UIStrings.lua (read only)
before the stand-in, so every word comes from Pawn's own PawnLocal and UI globals. For each key the
module's data lacks, a test line made from Pawn's English (words in Cyrillic; slots, colour codes and ": "
kept), as the build would take it (tools/pawn_rules.py), goes to the module (flow_pawn.lua).

  * Game E (no UADD_Pawn): Pawn's English, window closed and opened: what "off" must give back.
  * Game A (on at login): 1 PawnLocal, the UI globals, the tab and header lists, the stat rows and the
    window's texts are ours; STAY and game-name keys stay. 2 NoScale and the provider headers never go
    into PawnLocal or the saved scales, also after a save; ours only on screen. 3 Hold key, off and on,
    three times, window closed: English exactly, then ours exactly. 4 First open while on: the labels set
    once, the selector's provider lines, the scale-name label and the header are ours; scale names and
    the EditBox stay; our font on every Cyrillic text, also on a page shown later. Hold, off, on with the
    window open. A scale named like one of Pawn's texts stays as typed. 5 Tooltip lines keep ": " and
    the colour code; our font only on Pawn's lines, back when the tooltip is cleared. 6 No half line.
  * Game B: first opened while off, then on and off. Game C: first opened with the hold key held.
  * Game D: no Pawn (the module waits).
  * The game's stat names from UALL Forever: flow_pawn_names.py.
"""
import os
import sys

import flow_pawn_names
import halves_mods
from flow_pawn_game import cyr as _cyr, diff, errors as _errors, fonts, game as _game, installed, module_there
from flow_pawn_game import snap, test_data, tip_lines

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import pawn_rules as R  # noqa: E402
from flow import Check  # noqa: E402
from loader import lua_str, txt  # noqa: E402

DISPLAY = ("NoScale", "UI.AskMrRobotProvider", "UI.StarterProvider")
THANKS_UK = "Квікс дякує команді."
COLOUR = "|cff8ec3e6"


def game_e():
    c, M = _game({}, module=False)
    E = {"closed": snap(M)}
    M.open()
    E["open"] = snap(M)
    return E


def loop(check, M, en, uk, step):
    """Hold key, off and on, three times: English exactly, ours exactly, fonts right each time."""
    bad = []
    for i in range(3):
        for how, want in (("hold", en), ("release", uk), ("off", en), ("on", uk)):
            if how in ("hold", "release"):
                M.key(how == "hold")
            else:
                M.uadd("pawn " + how)
            s, (fbad, n) = snap(M), fonts(M)
            # A label set once that Pawn has not set yet (window never opened) may hold Pawn's English:
            # Pawn sets it again on first open.
            d = [k for k in diff(want, s) if not (k not in want and k.startswith("F:") and not _cyr(s[k]))]
            if d or fbad or (how == "off" and int(M.fontCount()) != 0):
                bad.append((i + 1, how, d[:3], fbad[:2]))
    check(f"{step} hold key, off, on (x3): English exactly, then ours exactly; fonts follow", not bad, bad[:3])


def game_a(check, facts, data, en, E):
    c, M = _game(data)
    A0 = snap(M)
    wrong = [txt(x) for x in M.wrong().values()]
    check("1 PawnLocal: ours for each key it may take; the rest as Pawn had it", not wrong, wrong[:5])
    changed = diff(E["closed"], A0)
    notcyr = [k for k in changed if not _cyr(A0.get(k))]
    kinds = {k.split(":")[0] for k in changed}
    check("1 all it changed is ours: PawnLocal, UI globals, tab and header lists, stat rows, window texts",
          {"L", "G", "T", "H", "S", "F"} <= kinds and not notcyr, (sorted(kinds), notcyr[:5]))
    nkeys = [p for p, (_, s) in data.items() if "n" in s]
    still = [p for p in nkeys if A0.get("L:" + p) != E["closed"].get("L:" + p)]
    check(f"1 a template with a game-name slot stays English ({len(nkeys)} keys)", nkeys and not still, still)
    stay = [k for k in E["closed"] if k.startswith(("L:TooltipParsing.", "L:Specs."))
            or k in ("L:DecimalSeparator", "L:ThousandsSeparator")]
    check(f"1 STAY: tooltip parsing, separators, spec names stay Pawn's ({len(stay)})",
          stay and all(A0.get(k) == E["closed"][k] for k in stay), [k for k in stay if A0.get(k) != E["closed"][k]][:3])
    facts["test_keys"], facts["swapped"], facts["changed"] = len(data), int(M.count()), len(changed)

    # 2 Words Pawn saves: never ours in PawnLocal or the saved scales; ours only on screen.
    M.save()
    A1 = snap(M)
    keys = ["L:" + d for d in DISPLAY] + [k for k in A1 if k.startswith("C:")]
    bad = [k for k in keys if A1.get(k) != E["closed"].get(k)]
    shown = [d for d in DISPLAY if not _cyr(txt(M.shown(lua_str(d))))]
    check("2 NoScale and provider headers: never in PawnLocal or saved scales (saved again too); ours to show",
          not bad and not shown, (bad, shown))

    # 3 Window closed.
    loop(check, M, E["closed"], A0, "3 window closed:")

    # 4 First open while on.
    M.open()
    O = snap(M)
    want = {
        "F:PawnUIFrame_ShowScaleCheck_Label": txt(M.fmt("UI.ScaleSelectorShowScale", "Tester")),
        "F:PawnUIFrame_AboutVersionLabel": txt(M.fmt("UI.AboutVersion", "0")),
        "F:PawnUIFrame_MrRobotLabel": THANKS_UK,
        "F:PawnUIFrame_ScaleNameLabel": txt(M.shown("NoScale")),
        "F:PawnUIScaleLine1": txt(M.shown("UI.StarterProvider")),
        "F:PawnUIScaleLine3": txt(M.shown("UI.AskMrRobotProvider")),
        "F:PawnUIScaleLine2": "Quixwood Tank", "F:PawnUIScaleLine4": "Quixwood Healer",
        "F:PawnUIScaleLine5": en["UI.ValuesTab"], "F:PawnUIFrame_ScaleNameBox": en["UI.ValuesTab"],
    }
    bad = {k: (O.get(k), v) for k, v in want.items() if O.get(k) != v}
    hdr = O.get("F:PawnUIHeader")
    check("4 first open (on): labels set once, header, scale-name label, provider lines ours; scale names and "
          "the EditBox stay", not bad and _cyr(hdr) and en["NoScale"] not in hdr, (bad, hdr))
    notcyr = [k for k in diff(E["open"], O) if not _cyr(O.get(k))]
    check("4 first open: all it changed in the window is ours", not notcyr, notcyr[:5])
    fbad, n = fonts(M)
    check("4 late window: our font on every Cyrillic text, none on others", n > 0 and not fbad, fbad[:4])
    M.about(True)
    fbad, _ = fonts(M)
    check("4 a page shown later (a tab switch): our font on its Cyrillic texts", not fbad, fbad[:4])
    facts["fonts"] = int(M.fontCount())
    loop(check, M, E["open"], O, "4 window open:")

    # Header with a scale slot (Values tab): NoScale ours; a scale's name as it is.
    h0, _ = M.header(2, None)
    h1, lab = M.header(2, "Mine")
    M.uadd("pawn off")
    M.uadd("pawn on")
    lab2 = txt(M.text("PawnUIFrame_ScaleNameLabel"))
    h0, h1, lab = txt(h0), txt(h1), txt(lab)
    check("4 header with a scale slot: ours around NoScale (ours) and around a scale's own name",
          h0 == txt(M.fmt("UI.ValuesHeader", M.shown("NoScale"))) and h1 == txt(M.fmt("UI.ValuesHeader",
                                                                                   lua_str(COLOUR + en["UI.ValuesTab"] + "|r"))),
          (h0, h1))
    check("4 a scale named like one of Pawn's texts stays as typed in the scale-name label, also after off/on",
          lab == en["UI.ValuesTab"] and lab2 == en["UI.ValuesTab"], (lab, lab2))
    scale_label(check, M, en)
    M.header(1, None)

    # 5 Tooltips.
    tip(check, M, en)
    # 6 No half line.
    halves_mods.pawn(check, M, en)
    _errors(c, check, "game A")
    return O


def scale_label(check, M, en):
    """Lesson 13: the scale-name label holds the player's scale name. Named exactly like one of Pawn's whole
    texts we translate, or like our Ukrainian for it, it stays as typed through off, on and the hold key,
    with the window closed (no refresh puts it back) and open. No scale: Pawn's NoScale text, ours when on."""
    raw_en, raw_uk = M.wholeText()
    bad, steps = [], ("off", "on", "hold", "release")
    for shown in (False, True):
        M.open() if shown else M.close()
        for kind, raw in (("Pawn's text", raw_en), ("ours", raw_uk), ("no scale", None)):
            got = txt(M.pickScale(raw))
            for how in ("chosen",) + steps:
                if how in ("hold", "release"):
                    M.key(how == "hold")
                elif how != "chosen":
                    M.uadd("pawn " + how)
                lab = txt(M.text("PawnUIFrame_ScaleNameLabel")) if how != "chosen" else got
                if raw is not None:
                    want = txt(raw)
                else:
                    want = en["NoScale"] if how in ("off", "hold") else txt(M.shown("NoScale"))
                if lab != want:
                    bad.append((("closed", "open")[shown], kind, how, lab))
    M.pickScale(None)
    M.open()
    check("4 lesson 13: a scale named like one of Pawn's whole texts, or like ours, stays as typed in the "
          "scale-name label (off, on, hold key; window closed and open); no scale: ours",
          raw_en and raw_uk and not bad, (txt(raw_uk), bad[:4]))


def tip(check, M, en):
    lines = tip_lines(M.itemTip(lua_str("Чужий рядок")))
    base = txt(M.at("BaseValueWord"))
    l1, l2, l3 = (lines + [None] * 3)[:3]
    ok1 = l1 and l1[0] == COLOUR + base and l1[1] == COLOUR + "|cffffffff45.6" and l1[2] and not l1[3]
    ok2 = l2 and l2[0] == COLOUR + "Quixwood Tank" and l2[1].startswith(COLOUR + "12.3") and _cyr(l2[1]) \
        and l2[3] and not l2[2]
    check("5 tooltip: split at ': ' as Pawn does; colour code first on the right; our font on Pawn's "
          "Cyrillic lines only", _cyr(base) and ok1 and ok2 and l3 and not l3[2], lines)
    check("5 tooltip cleared: every line's font back", M.clearTip(), "")
    bad = []
    for path in data_paths(M, en):
        e, uk = en[path], txt(M.at(lua_str(path)))
        if uk != e and [p for p in R.check(path, e, uk) if '": "' in p or "colour code" in p]:
            bad.append(path)
    check("5 each line it wrote keeps the ': ' before a value and the leading colour code", not bad, bad[:5])
    h = tip_lines(M.helpTip())
    ok = len(h) == 2 and all(_cyr(x[0]) and x[2] for x in h)
    M.key(True)
    held = tip_lines(M.helpTip())
    M.key(False)
    check("5 window help tooltip: ours in our font; with the hold key, English in Pawn's font",
          ok and len(held) == 2 and not any(_cyr(x[0]) or x[2] for x in held), (h, held))
    M.clearTip()


def data_paths(M, en):
    return [p for p in en if M.usable(lua_str(p)) is not None]


def game_b(check, data, E, O):
    c, M = _game(data)
    M.uadd("pawn off")
    M.open()
    s1, f1 = snap(M), fonts(M)
    M.uadd("pawn on")
    s2, f2 = snap(M), fonts(M)
    M.uadd("pawn off")
    s3 = snap(M)
    check("3b first open while off: English; on: as if opened on; off: English again",
          s1 == E["open"] and s2 == O and s3 == E["open"] and not f1[0] and not f2[0],
          (diff(E["open"], s1)[:3], diff(O, s2)[:3], diff(E["open"], s3)[:3], f1[0][:2], f2[0][:2]))
    _errors(c, check, "game B")
    c, M = _game(data)
    M.key(True)
    M.open()
    s1 = snap(M)
    M.key(False)
    s2, f2 = snap(M), fonts(M)
    check("3c first open with the hold key held: English; key up: ours, as if opened on",
          s1 == E["open"] and s2 == O and not f2[0], (diff(E["open"], s1)[:3], diff(O, s2)[:3], f2[0][:2]))
    _errors(c, check, "game C")


def game_d(check):
    c, M = _game({}, target=False)
    c.slash("pawn")
    out = " ".join(c.chat())
    check("game D (no Pawn): the module waits", "Pawn" in out and "чекає" in out, out[-160:])
    _errors(c, check, "game D")


def run(check, facts):
    if not module_there() or not installed():
        halves_mods.pawn(check, None, None)
        facts["note"] = "Pawn or the module not there: skipped"
        return
    data, en = test_data()
    E = game_e()
    O = game_a(check, facts, data, en, E)
    game_b(check, data, E, O)
    game_d(check)
    flow_pawn_names.run(check, data)


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("pawn: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_pawn.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:400]}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
