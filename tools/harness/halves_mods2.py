"""The half-translation check's module functions, part 2 (halves_mods.py imports them all, so each flow still calls
halves_mods.<name>): the shared helpers (NAME, SKIP, _t, _s_slots) and the modules whose rules sit in a
tools/<x>_rules.py file (RareScanner, Pawn, GatherMate2, Scrap, Road to Sixty)."""
import os
import sys

from halves import run, tpl
from halves_shapes import bgn_value, parts
from loader import lua_str, txt

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import halves_cover  # noqa: E402
import hashtext  # noqa: E402

NAME, SKIP = "Quix", halves_cover.SKIP
def _s_slots(en): return [k for k, kind in enumerate(halves_cover.kinds(en), 1) if kind == "s"]  # noqa: E704
def _t(v): return txt(v) if isinstance(v, str) else None  # noqa: E704


def rs(check, M, note=""):
    """RareScanner: the lines it read at load (settings, pop-ups) are read back by Options.Translate with the English template of each key put into its locale table (M.templates(): English, slot kinds, f free)."""  # noqa: E501
    if M is None:
        return run(check, "UADD_RareScanner", [], None, note or SKIP)
    tps = [tpl(k, txt(row[1]), {i: NAME for i, c in enumerate(txt(row[2]), 1) if c == "f"})
           for k, row in M.templates().items()]
    run(check, "UADD_RareScanner", tps, lambda tp, t: _t(M.tr(lua_str(t))), note)


def pawn(check, M, en=None, note=""):
    """Pawn: the module swaps whole templates; a text Pawn builds is read back as our template (M.fmt) with
    its values. pawn_rules.SORTS: f free, v a value (English in a v %s is no text Pawn builds: kept as it
    is); a template with an n slot is never taken (M.usable)."""
    if M is None:
        return run(check, "UADD_Pawn", [], None, note or SKIP)
    import re
    import pawn_rules
    tps = []
    for p, e in sorted(en.items()):
        s = pawn_rules.sorts(p, e)
        if halves_cover.kinds(e) and None not in s and M.usable(lua_str(p)) is not None:
            tps.append(tpl(p, e, {i: NAME for i, c in enumerate(s, 1) if c == "f"}, sorts=s))
    def tr(tp, t):
        toks = hashtext.tokens(tp["en"])
        pat = "".join(re.escape(x[1]) if x[0] == "lit" else "(.*?)" if x[2][0] == "arg" else "(?:.*?)"
                      for x in toks)
        m = re.fullmatch(pat, t, re.S)
        if not m:
            return None
        slots = [x for x in toks if x[0] == "slot" and x[2][0] == "arg"]
        args = [None] * len(slots)
        try:
            for (_, kind, (_, n)), v, sort in zip(slots, m.groups(), tp["sorts"]):
                if kind == "s" and sort == "v" and not bgn_value(v):
                    return t
                args[n - 1] = int(v) if kind == "d" else float(v) if kind == "f" else int(v, 16) if kind[0] == "x" \
                    else lua_str(v)
        except ValueError:
            return t
        return _t(M.fmt(lua_str(tp["id"]), *args))
    run(check, "UADD_Pawn", tps, tr, note)


def gm(check, M, en=None, note=""):
    """GatherMate2: no %s; its code glues a value after a key (gm_rules.GLUE_AFTER), so each is a template
    (its English plus the glue), the line built by the stand-in's own code (M.line). f free (fed glued too)."""
    if M is None:
        return run(check, "UADD_GatherMate2", [], None, note or SKIP)
    import gm_rules as R
    tps = [tpl(k, en[k] + g, {i: NAME for i, c in enumerate(R.slot_sorts(k, en[k]), 1) if c == "f"})
           for k, g in sorted(R.GLUE_AFTER.items())]
    def tr(tp, t):
        v = parts(tp["en"], t)
        return _t(M.line(lua_str(tp["id"]), lua_str(v[0]))) if v else None
    run(check, "UADD_GatherMate2", tps, tr, note, glue=True)


def scrap(check, M, en=None, note=""):
    """Scrap: its own code builds each line from its locale row (the stand-in's M.line). scrap_rules.SORTS: v money
    (other English there is no line Scrap builds: kept as it is), n an item link (STAY keeps the line English)."""
    if M is None:
        return run(check, "UADD_Scrap", [], None, note or SKIP)
    import scrap_rules as R
    tps = [tpl(k, en[k], {}, sorts=s) for k, s in sorted(R.SORTS.items())]
    def tr(tp, t):
        v = parts(tp["en"], t)
        if not v or any(s == "v" and not bgn_value(x) for s, x in zip(tp["sorts"], v)):
            return v and t
        return _t(M.line(lua_str(tp["id"]), *v))
    run(check, "UADD_Scrap", tps, tr, note)


def rts(check, W, tps, note=""):
    """Road to Sixty: Words.Translate (W) on each whole line, as its hooks hand them over (glue=True: a free slot
    at an edge is fed glued text too). tps: flow_rts_halves.templates() (slot sorts from the module's ns.SORT)."""
    run(check, "UADD_RoadToSixty", tps, W and (lambda tp, t: _t(W.Translate(lua_str(t)))), note, glue=True)
