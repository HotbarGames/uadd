"""GearQuest Forever's part of the half-translation check (halves_mods.gq runs it): its templates, read from the
installed addon (gq_source), free slots from gq_rules.SORTS ("f"), and the module's own path: GearQuest's L looks
the template up (so the module learns it, as when its code formats it), then Screen.Other turns the whole line, as
the hold key and on do. No English of GearQuest is kept here."""
import gq_rules as R
import gq_source as G
import hashtext
from halves import tpl
from halves_mods import NAME, SKIP, _t
from loader import lua_str


WORD = "L.7c864557"      # one of its texts we have (a slot's name): what a "t" slot holds in the good sample


def templates(a):
    rows, _ = G.source(a)
    word = next(en for k, en, *_ in rows if k == WORD)
    out = []
    for k, en, *_ in rows:
        if hashtext.is_template(en):
            letters = R.sorts(k, en)
            out.append(tpl(k, en, {i: NAME for i, x in enumerate(letters, 1) if x == "f"},
                           {i: word for i, x in enumerate(letters, 1) if x == "t"}))
    return out


def parts(c, note=""):
    """(templates, translate, note) for halves.run. c None: GearQuest is not installed (a note)."""
    if c is None:
        return [], None, note or SKIP
    L, ns = c.lua.globals().GearQuest.L, c.H.ns.UADD_GearQuestForever

    def tr(tp, t):
        L[lua_str(tp["en"])]
        out = ns.Screen.Other(lua_str(t), False)
        return t if out is None else _t(out)
    return templates(G.addon_dir()), tr, note
