"""BugSack's part of the half-translation check (halves_mods.bs runs it): its templates, read from the installed
addon (bs_source), and the path each one takes through the module. No English of BugSack is kept here.

The session label's two parts (our word in its slot; "sent by": a player, kept, then our word) go into a whole line
built by the stand-in's own Line (a clock, a date) and set on the label, where the module's hook turns it
(flow_bs.lua M.session); a line left as the stand-in built it gives back the input. Chat lines: the template now in
its table (ns.Translate, as swapped in) formatted with the values; the popup: its shown text (ns.Translate).
"""
import re

import bs_rules as R
import bs_source as G
import halves_cover
import hashtext
from halves import tpl
from halves_mods import NAME, SKIP, _s_slots, _t
from halves_shapes import parts as split
from loader import lua_str


def templates(a):
    """Every template of the installed BugSack at a, as halves.tpl rows; the label's word slot gets a real word."""
    rows, _ = G.source(a)
    word = G.uses(a)[1][0][0]
    tps = []
    for k, en, *_ in rows:
        if not hashtext.is_template(en):
            continue
        if R.KINDS[k] != "window":
            tps.append(tpl(k, en, {i: NAME for i in _s_slots(en)}, kind=R.KINDS[k]))
            continue
        two = len(halves_cover.kinds(en)) == 2
        for when in (("sent",) if two else ("local", "date")):
            tps.append(tpl(k + "@" + when, en, {1: NAME} if two else {}, {2 if two else 1: word}, kind="window",
                           when=when, two=two))
    return tps


def parts(c, note=""):
    """(templates, translate, note) for halves.run. c None: BugSack is not installed (a note)."""
    if c is None:
        return [], None, note or SKIP
    lua, M, ns = c.lua, c.H.bs, c.H.ns.UADD_BugSack
    S, st = lua.globals().BugSackStandIn, lua.eval("function(k, w, n) return { kind = k, word = w, name = n } end")
    fmt = lua.eval("function(f, ...) return f:format(...) end")

    def line(tp, t):
        v = split(tp["en"], t)
        if v is None:
            return None
        w, n = (v[1], v[0]) if tp["two"] else (v[0], None)
        out = M.session(lua_str(tp["when"]), w, n)
        return t if out == S.Line(st(lua_str(tp["when"]), w, n)) else _t(out)

    def chat(tp, t):
        toks = hashtext.tokens(tp["en"])
        slots = [x for x in toks if x[0] == "slot"]
        m = re.fullmatch("".join(re.escape(x[1]) if x[0] == "lit" else r"(\d+)" if x[1] == "d" else "(.*?)"
                                 for x in toks), t, re.S)
        ours = m and ns.Translate(lua_str(tp["en"]))
        if not ours:
            return m and t
        return _t(fmt(ours, *(int(g) if x[1] == "d" else lua_str(g) for g, x in zip(m.groups(), slots))))

    def tr(tp, t):
        if tp["kind"] == "window":
            return line(tp, t)
        return chat(tp, t) if tp["kind"] == "chat" else _t(ns.Translate(lua_str(t)))
    return templates(G.addon_dir()), tr, note
