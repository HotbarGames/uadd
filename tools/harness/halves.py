"""No half-translated line: one check for every module that fills template slots (halves_mods.py).

A half translation is a template that matched while one of its slots kept English ("Рівень card theme").
Each template's real English (read from the installed addon at test time) gets made-up English in its
slots, and goes through the module's real translate path:
  * pass 1: every slot that is not free holds the same filler;
  * pass 2 (two or more such slots): one slot holds the filler, the others a value that fits ("7");
  * free slots (a name the module keeps as it is) hold a made-up name, the other slots a value
    of their kind (7, 7.5, ff, a picture).
The check fails when the module gives back a changed text that still has the filler in it: Ukrainian
around English that is not a name. It also fails when a template does not translate with fitting
values (its real sample values: the output is not the input), unless halves_cover.UNFIT lists it with
a reason; and when an UNFIT entry is stale (the template fits now, or is gone).
With glue=True (a module that finds whole lines on screen, where the addon may have glued two of its
texts before we see them: ForeverXP Bar, LayerSwap), glued() texts are fed too: a free slot at an edge of
a template must not take a glued text (a module whose templates hold only free slots, Waypoint UI's,
says free_only=True and passes on its glued texts alone; for the others no template found still fails). Modules that fill a slot at the call that makes the text (DialogueUI,
Auctionator, OpenMap...) get exactly the name there, which may hold any spaces, so they are not fed.
It fails, too, when one long or tricky text (hard(): many short Cyrillic words, a 160-byte note, many
separators, colour pieces, brackets) takes more than BOUND: a line can come from another player (a
shared note), and a slow one freezes the game.

  run(check, module, templates, translate)   templates: tpl(..) dicts; translate(tpl, text) -> str,
                                             None or a list of those (one per path); hard= another
                                             translate for the time check (more paths), if wanted;
                                             glue=True to feed glued() texts too; free_only=True
                                             when every template holds only free slots
"""
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import clock  # noqa: E402
import halves_cover  # noqa: E402
import hashtext  # noqa: E402

FILLERS = ("wobbly gizmo", "Zorp Blatter", "It went fine.", "zork42")
GLUES = ("   ", "\n", " - ")   # marks addons join two texts with (glued()); a name never holds one
NAME = "Quix"
VALUE = {"d": "7", "f": "7.5", "x": "ff", "x2": "0f", "t": "|TInterface\\Icons\\INV_Misc_QuestionMark:0|t"}
GOOD = "7"
BOUND = 0.005   # seconds: the most one text may take, at best of three, on an idle PC (clock.py stretches it)


def tpl(id, en, free=None, good=None, **extra):
    """A template: its id (a key or a hash), real English, {slot: made-up name} for free slots and
    {slot: value} for slots that take neither a number nor a free name."""
    return dict(extra, id=id, en=en, free=free or {}, good=good or {})


def fill(en, pick):
    """en with slot k (1-based, in order) replaced by pick(k, kind)."""
    out, k = [], 0
    for t in hashtext.tokens(en):
        if t[0] == "lit":
            out.append(t[1])
        else:
            k += 1
            out.append(pick(k, t[1]))
    return "".join(out)


def texts(tp):
    """[(filler, text)] for one template; [] when it has no slot that is not free."""
    free, good = tp["free"], tp["good"]
    open_ = [k for k, kind in enumerate(halves_cover.kinds(tp["en"]), 1) if kind in ("s", "l") and k not in free]
    if not open_:
        return []
    sets = [set(open_)] + ([{j} for j in open_] if len(open_) > 1 else [])

    def picker(f, these):
        def pick(k, kind):
            if k in free:
                return free[k]
            if k in these:
                return f
            return good.get(k, GOOD) if kind in ("s", "l") else VALUE[kind]
        return pick
    return [(f, fill(tp["en"], picker(f, these))) for f in FILLERS for these in sets]


def _bare(lit):
    """A literal with no letters once colour codes are taken out ("|cffffb040", "|r", ". (")."""
    return not re.search(r"[A-Za-z]", re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", lit))


def glued(tp):
    """[(filler, text)]: each free slot at an edge of the template (no letters and no other slot between
    it and the start or the end) holds a name glued to made-up English with a mark addons join texts
    with ("Quix" + "   " + filler at the end, filler + "   " + "Quix" at the start), as when an addon
    puts its own text before or after this one (LayerSwap's one-line mini bar: name, wide gap, status).
    A free slot keeps a name, never a glued text: such a line must stay English or be ours as a whole.
    Blank slots (tp["blank"]: a plural ending the module drops) are not names, so not fed."""
    toks, out = hashtext.tokens(tp["en"]), []
    at = [i for i, t in enumerate(toks) if t[0] == "slot"]
    for k, i in enumerate(at, 1):
        if k not in tp["free"] or k in tp.get("blank", ()) or toks[i][1] not in ("s", "l"):
            continue
        head = i == at[0] and all(_bare(t[1]) for t in toks[:i])
        tail = i == at[-1] and all(_bare(t[1]) for t in toks[i + 1:])
        for f in FILLERS[:2]:
            for g in GLUES:
                for v in ([f + g + NAME] if head else []) + ([NAME + g + f] if tail else []):
                    out.append((f, fill(tp["en"], lambda j, kind: v if j == k else tp["free"].get(j) or (
                        tp["good"].get(j, GOOD) if kind in ("s", "l") else VALUE[kind]))))
    return out


def good_text(tp):
    return fill(tp["en"], lambda k, kind: tp["free"].get(k) or (tp["good"].get(k, GOOD) if kind in ("s", "l")
                                                                 else VALUE[kind]))


def hard(tp, v):
    """Long and tricky texts, alone and in the template's open slots; variant v (0-2) uses other
    letters, so no answer is remembered from the one before."""
    a = "абв"[v]
    raw = [" ".join([a + "ж"] * 40) + " Hogger", a * 80, " · ".join([a + "к Orgrimmar"] * 12),
           "  ".join([a + "м"] * 30), ": ".join([a + "н"] * 30), f"|cffffffff{a}п|r · " * 15,
           "(" * 20 + a + "р" + ")" * 20, "Level " * 30 + a, ", ".join([a + "с"] * 30)]
    def into(t):
        return fill(tp["en"], lambda k, kind: tp["free"][k] if k in tp["free"] else
                    t if kind in ("s", "l") else VALUE[kind])
    return raw + [into(t) for t in raw]


def slowest(tp, translate):
    """(seconds, text, reference samples): the slowest hard text, each at the best of its three variants;
    a run of clock.py's reference job before each, so the bound sees the same load."""
    worst, refs = (0.0, ""), []
    for row in zip(*(hard(tp, v) for v in range(3))):
        refs.append(clock.sample())
        best = None
        for t in row:
            t0 = time.process_time()          # CPU time, as chaos's os.clock (load still slows it: clock.py)
            translate(tp, t)
            dt = time.process_time() - t0
            best = dt if best is None else min(best, dt)
        worst = max(worst, (best, row[0]))
    return worst + (refs,)


def _outs(got):
    return [g for g in (got if isinstance(got, list) else [got]) if isinstance(g, str)]


def run(check, module, templates, translate, note="", hard=None, glue=False, free_only=False):
    """One check for the module: no output keeps a filler while the rest changed."""
    assert module in halves_cover.COVERED, module
    name = f"no half-translated line: {module}"
    if note:
        check(f"{name} ({note})", True, note)
        return
    bad, n, count, unfit, first, nglue = [], 0, 0, [], None, 0
    for tp in templates:
        for f, t in (glued(tp) if glue else []):
            nglue += 1
            bad += [(tp["id"], "free slot took a glued text", t, o)
                    for o in _outs(translate(tp, t)) if o != t and f in o]
        cases = texts(tp)
        if not cases:
            continue
        n, first = n + 1, first or tp
        g = good_text(tp)
        if not any(o != g for o in _outs(translate(tp, g))):
            unfit.append(tp["id"])
        for f, t in cases:
            count += 1
            bad += [(tp["id"], t, o) for o in _outs(translate(tp, t)) if o != t and f in o]
    known = halves_cover.UNFIT.get(module, {})
    new, stale = [i for i in unfit if i not in known], [i for i in known if i not in unfit]
    sec, text, refs = slowest(first, hard or translate) if first else (0.0, "", None)
    limit, ref = clock.bound(BOUND * 1000, refs)      # BOUND stretched by the load seen meanwhile (clock.py)
    slow = sec * 1000 > limit and {"too slow (ms)": round(sec * 1000, 1), "text": text[:80],
                                   "time": clock.note(limit, ref)}
    detail = (bad[:3] or slow or (new and {"unfit, not in UNFIT": new[:8]})
              or (stale and {"stale UNFIT": stale[:8]})
              or f"{n} templates, {n - len(unfit)} fit, {len(unfit)} known unfit")
    glues = f"{nglue} glued to a free slot, " if glue else ""
    check(f"{name} ({n} templates, {count} texts, {glues}{n - len(unfit)} fit, "
          f"{len(unfit)} unfit, slowest {sec * 1000:.1f} ms, {clock.note(limit, ref)})",
          (n > 0 or (free_only and nglue > 0)) and not bad and not slow and not new and not stale, detail)
