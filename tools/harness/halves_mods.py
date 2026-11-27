"""The half-translation check (halves.py) for each module: its templates' real English, its free slots and its
translate path. Each flow named in halves_cover.COVERED calls its function here. The English is read from the
installed addon at test time; without it the check is a note. Made-up names for free slots: "Quix" (an item
link, a key binding "QUIX" where the module wants one). Shapes, values, read-back helpers: halves_shapes.py."""
import os
import sys

from halves import run, tpl
from halves_mods2 import NAME, SKIP, _s_slots, _t, gm, pawn, rs, rts, scrap  # noqa: F401  (flows call halves_mods.<name>)
from halves_shapes import ATT_BY_KEY, ATT_FREE, ATT_LUA, DUI_FREE, OM_LABEL, OM_SHAPES, bgn_value, named, parts
from loader import lua_str, txt

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import halves_cover  # noqa: E402
import hashtext  # noqa: E402

def dci(check, M, tps, note=""): run(check, "UADD_DeleteCheapestItem", tps, M and (lambda tp, t: _t(M.translate(lua_str(t)))), note)  # noqa: E704,E501  DeleteCheapestItem Reloaded: Words.Translate on each whole text (M.translate); tps: flow_dci.templates(); What's Training? next: M.uk on whole lines (glue=True), tps: flow_whatstraining_texts.py
def ofa(check, W, tps, note=""): run(check, "UADD_OneForAll", tps, W and (lambda tp, t: _t(W.Translate(lua_str(t)))), note, glue=True)  # noqa: E704,E501  OneForAll: Words.Translate on whole lines (glue=True); tps: flow_ofa_halves.templates()
def wt(check, M, tps, note=""): run(check, "UADD_WhatsTraining", tps, lambda tp, t: _t(M.uk(lua_str(t))), note, glue=True)  # noqa: E704,E501


def _words(M, p):
    """ForeverXP Bar (p "fxpb"), LayerSwap ("lsw"): (templates, translate, note) for run(). Words.Text (M.uk); free slots from <p>_words.FREE and BLANK, texts from make_<p>_data."""  # noqa: E501
    import importlib
    W, D = importlib.import_module(p + "_words"), importlib.import_module("make_" + p + "_data")
    if not D.have_addon():
        return [], None, SKIP
    tps = []
    for k, en in ((hashtext.key(en), en) for kind, en in D.texts(D.collect()[0]) if kind == "format"):
        free = {i: NAME for i in W.FREE.get(k, [])}
        free.update({i: "s" for i in W.BLANK.get(k, [])})
        good = {i: "|cffa335ee" for i in getattr(W, "COLOUR", {}).get(k, [])}  # colour-code slots (fxpb_words.COLOUR)
        tps.append(tpl(k, en, free, good, blank=set(W.BLANK.get(k, []))))
    return tps, lambda tp, t: _t(M.uk(lua_str(t))), ""


def fxpb(check, M): run(check, "UADD_ForeverXPBar", *_words(M, "fxpb"), glue=True)  # noqa: E704
def lsw(check, M): run(check, "UADD_LayerSwap", *_words(M, "lsw"), glue=True)  # noqa: E704
def sal(check, M, tps, note=""): run(check, "UADD_SpeedyAutoLoot", tps, M and (lambda tp, t: _t(M.tr(lua_str(t)))), note)  # noqa: E704,E501  Speedy AutoLoot: each text through its real chat hook after the addon's name (M.tr); tps: flow_sal.templates()
def wtw(check, M, tps, note=""): run(check, "UADD_WhatTheWhisper", tps, M and (lambda tp, t: (lambda a: t if a is None else _t(M.line(lua_str(tp["key"]), *map(lua_str, a))))(tp["args"](t))), note)  # noqa: E704,E501  WhatTheWhisper: its own L[key]:format (M.line); tps: flow_wtw.templates()
def lt(check, M, tps, note=""): run(check, "UADD_LootTriage", tps, M and (lambda tp, t: _t(M.tr(lua_str(t)))), note)  # noqa: E704,E501  LootTriage: each line on its tooltip from its own file (M.tr); tps: flow_lt.templates()
def wql(check, M, tps, note=""): run(check, "UADD_WowheadQuickLink", tps, M and (lambda tp, t: _t(M.tr(lua_str(t), tp["id"].startswith("Pop.")))), note)  # noqa: E704,E501  Wowhead Quick Link: through its real popup (M.tr); tps: flow_wql.templates()
def bs(check, c, note=""): run(check, "UADD_BugSack", *__import__("halves_bs").parts(c, note))  # noqa: E704,E501  BugSack: the session label through the module's hook, chat lines and the popup through ns.Translate (halves_bs.py); c None: not installed
def gq(check, c, note=""): run(check, "UADD_GearQuestForever", *__import__("halves_gq").parts(c, note))  # noqa: E704,E501  GearQuest Forever: its L learns each template, then Screen.Other turns the line (halves_gq.py); c None: not installed

def ap(check, M):
    """Auto Potion: Words.Text and Words.Bare (the flow's M.uk, M.bare); free slots from
    make_ap_text.FREE, or "(slot free)" in texts(). M None: Auto Potion is not installed."""
    import make_ap_text
    if M is None:
        return run(check, "UADD_AutoPotion", [], None, SKIP)
    if not M.count():
        return run(check, "UADD_AutoPotion", [], None, "skipped: data/words.lua has no Ukrainian yet")
    tps = []
    for k, kind, en, where in make_ap_text.texts(make_ap_text.addon_dir()):
        if kind == "template":
            slots = make_ap_text.FREE.get(k) or ([1] if "(slot free)" in where else [])
            tps.append(tpl(k, en, {i: NAME for i in slots}))
    run(check, "UADD_AutoPotion", tps, lambda tp, t: [_t(M.uk(lua_str(t))), _t(M.bare(lua_str(t)))],
        glue=True)


def dui(check, M):
    """DialogueUI: Words.Text (M.words); a key in Slots.lua SLOTS takes a name of its kind in each %s."""
    import make_dui_data as D
    path = D.DEFAULT / "Locales" / "enUS.lua"
    if not path.is_file():
        return run(check, "UADD_DialogueUI", [], None, SKIP)
    real, _ = D.read_enus(path)
    slots, tps = halves_cover.dui_slots(), []
    for lit, value in D.read_locale():
        if lit not in real or value == "false":
            continue
        key, en = D.unlua(lit), real[lit][1]
        kind = slots.get(key)
        free = {k: DUI_FREE.get(kind, NAME) for k in _s_slots(en)} if kind else {}
        tps.append(tpl(key, en, free))
    run(check, "UADD_DialogueUI", tps, lambda tp, t: _t(M.words(lua_str(t), False)))


def auc(check, c):
    """Auctionator: Words.Text and Words.Key, on its locale texts (FREE in Words.lua) and the texts of its
    code (make_auc_text.SLOTS: free and one-word slots). Its real English goes into the AUCTIONATOR_L_
    globals for a while, then the stand-in's are put back."""
    import make_auc_text as A
    addon = A.addon_dir()
    if not (addon / "Locales" / "enUS.lua").is_file():
        return run(check, "UADD_Auctionator", [], None, SKIP)
    W, g = c.H.ns.UADD_Auctionator.Words, c.lua.globals()
    real, _ = A.read_enus(addon)
    keys = [k for k in A.read_ua() if k in real]
    free, tps = halves_cover.auc_free(), []
    saved = {k: g["AUCTIONATOR_L_" + k] for k in keys}
    for k in keys:
        g["AUCTIONATOR_L_" + k] = lua_str(real[k][0])
        if hashtext.is_template(real[k][0]):
            tps.append(tpl(k, real[k][0], {i: NAME for i in free.get(k, [])}, key=k))
    for _, en in A.all_code_texts(addon):
        if hashtext.is_template(en):
            k = hashtext.key(en)
            mk = A.SLOTS.get(k, {})
            marks = {i: NAME for i in mk.get("free", [])}
            marks.update({i: "quix" for i in mk.get("word", [])})
            tps.append(tpl(k, en, marks))
    W.Build()
    def tr(tp, t):
        out = [_t(W.Text(lua_str(t)))]
        return out + [_t(W.Key(tp["key"], lua_str(t)))] if tp.get("key") else out
    try:
        run(check, "UADD_Auctionator", tps, tr)
    finally:
        for k, v in saved.items():
            g["AUCTIONATOR_L_" + k] = v
        W.Build()


def att(check, c):
    """Attune: Words.Text on its locale texts (##PLACE## kinds in Pairs.lua ns.Slots; a %s must translate).
    Its real AttuneLang goes in for a while, then the stand-in's is put back."""
    import make_att_text
    real, _ = make_att_text.enus(make_att_text.addon_dir())
    if not real:
        return run(check, "UADD_Attune", [], None, SKIP)
    lua, ns = c.lua, c.H.ns.UADD_Attune
    get, put = lua.eval("function(k) return rawget(AttuneLang, k) end"), lua.eval("function(k, v) rawset(AttuneLang, k, v) end")
    saved = {k: get(k) for k in real}
    for k, en in real.items():
        put(k, lua_str(en))
    try:
        ns.Words.Build()
        S, faction = ns.Slots, lua.eval('select(2, UnitFactionGroup("player"))')
        good_by = {"attune": "Molten Core", "faction": faction}
        tps = []
        for row in lua.execute(ATT_LUA).values():
            en, key = txt(row[1]), row[2] or None
            free, good, k = {}, {}, 0
            for t in hashtext.tokens(en):
                if t[0] != "slot":
                    continue
                k += 1
                ref = t[2]
                kind = S.Kind(ref[1] if ref[0] == "place" else "S%d" % ref[1], key)
                if S.Free(kind):
                    free[k] = ATT_FREE[kind]
                elif kind in good_by:
                    good[k] = good_by[kind]
                elif ref[0] == "place" and real.get(ATT_BY_KEY.get(ref[1])):
                    good[k] = real[ATT_BY_KEY[ref[1]]]
            tps.append(tpl(key or hashtext.key(en), en, free, good))
        run(check, "UADD_Attune", tps, lambda tp, t: _t(ns.Words.Text(lua_str(t))))
    finally:
        for k, v in saved.items():
            put(k, v)
        ns.Words.Build()


def openmap(check, lua):
    """OpenMap: Words.Line, on ui/locale.lua's formatted texts (free slots: Locale.lua Lc.FREE) and its
    own shapes. OpenMap is MIT: its English keys are in the repo."""
    Lc, Wd = lua.globals().UADD.OpenMapLocale, lua.globals().HARNESS.ns.UADD_OpenMap.Words
    free = halves_cover.openmap_free()
    tps = [tpl(en, en, {i: NAME for i in free.get(en, [])})
           for en in sorted(txt(k) for k in Lc.entries.keys()) if hashtext.is_template(en)]
    tps += [tpl(en, en, {}, good) for en, good in OM_SHAPES]
    tps += [tpl(en, en, {}, good, label=True) for en, good in OM_LABEL]
    P, Lb = lua.globals().HARNESS.ns.UADD_OpenMap.Parts, lua.globals().HARNESS.ns.UADD_OpenMap.Label
    every = lambda tp, t: [Wd.Line(lua_str(t)), Wd.Whole(lua_str(t)), Wd.English(lua_str(t)),  # noqa: E731
                           P.Built(lua_str(t)), P.English(lua_str(t)), Lb.Text(lua_str(t))]   # the time check: the tooltip's and label's paths too
    run(check, "UADD_OpenMap", tps, lambda tp, t: _t((Lb.Text if tp.get("label") else Wd.Line)(lua_str(t))), hard=every)


def dj(check, s):
    """Dungeon Journal: the lines it builds with names in our words (Built.lua), each drawn by the
    journal's own function (PlaceSummonHelp, ShowLootChild) with the slot values as its names."""
    X, F = s.H.djx, s.lua.globals().ForeverDungeonJournal_NS
    if not F or not X:
        return run(check, "UADD_DungeonJournal", [], None, SKIP)
    en = F.Locales.enUS
    _, _, boss, item = (list(X.summonQuest()) + [None] * 4)[:4]
    own, own_boss, other, other_boss = X.halves()
    keys = {"SUMMON_QUEST_NOTE": {1: boss, 2: item}, "HOW_TO_SUMMON": {1: boss}, "LOOT_COMBINE_WITH": {1: other},
            "LOOT_MADE_FROM": {1: f"{txt(own)} ({txt(own_boss)})", 2: f"{txt(other)} ({txt(other_boss)})"}}
    tps = [tpl(k, txt(en[k]), {}, {i: txt(v) for i, v in good.items()}) for k, good in keys.items()]
    paths = {"SUMMON_QUEST_NOTE": lambda v: X.summon(v[0], v[1])[0],
             "HOW_TO_SUMMON": lambda v: X.summon(v[0], item)[1],
             "LOOT_COMBINE_WITH": lambda v: X.child(own, own_boss, v[0], other_boss)[0],
             "LOOT_MADE_FROM": lambda v: X.child(*named(v[0]), *named(v[1]))[1]}
    def tr(tp, t):
        v = parts(tp["en"], t)
        return _t(paths[tp["id"]](v)) if v else None
    run(check, "UADD_DungeonJournal", tps, tr)


def bgn(check, M, rows):
    """Bagnon: the module only puts our words into Bagnon's AceLocale tables; Bagnon formats them itself. A text
    is read into its values by the English template and formatted with the table's word now (M.shows). Free:
    make_bgn_text.FREE. A VALUE slot (a number or money) with no digit is no text Bagnon shows: kept as is."""
    import make_bgn_text
    if M is None or not rows:
        return run(check, "UADD_Bagnon", [], None, SKIP)
    tps = [tpl(k, en, {i: NAME for i in make_bgn_text.FREE.get(k, [])}) for k, kind, en, _ in rows
           if kind == "template"]

    def tr(tp, t):
        v = parts(tp["en"], t)
        if v is None or tp["id"] in make_bgn_text.VALUE and not all(bgn_value(x) for x in v):
            return v and t
        which, _, key = tp["id"].partition(":")
        return _t(M.shows(which, key, *v))
    run(check, "UADD_Bagnon", tps, tr)


def mc(check, M, src, temps):
    """Mastercraft: Words.Translate (M.uk) on whole lines, as Screen.lua gets them (glue=True), each line of a
    multi-line text alone. Slots by the data's sort (temps: {id: sort}): f free, b blank, n a game name."""
    import mc_text_lib as L
    if M is None:
        return run(check, "UADD_Mastercraft", [], None, SKIP)
    lines = {hashtext.key(x): x for en, kind in src if "template" in kind for x in map(L.strip, en.split("\n"))}
    def by(k, c, v): return {i: v for i, s in enumerate(temps[k], 1) if s == c}  # noqa: E704
    tps = [tpl(k, x, {**by(k, "f", NAME), **by(k, "b", "s")}, by(k, "n", NAME), blank=set(by(k, "b", 1)))
           for k, x in lines.items() if k in temps and L.is_pattern(x)]
    run(check, "UADD_Mastercraft", tps, lambda tp, t: _t(M.uk(lua_str(t))), glue=True)


def tomtom(check, M, tps, note=""): run(check, "UADD_TomTom", tps, M and (lambda tp, t: _t(M.uk(lua_str(t)))), note, glue=True)  # noqa: E704,E501 Words.Translate on whole lines; tps: flow_tomtom_texts.templates()
def wp(check, M, tps, note=""): run(check, "UADD_WaypointUI", tps, M and (lambda tp, t: _t(M.Text(lua_str(t)))), note, glue=True, free_only=True)  # noqa: E704,E501 ns.Text on a whole text, as its Text frames hand it over; tps: flow_wp_texts.templates()
def fqp(check, M, tps, note=""): run(check, "UADD_ForeverQuestPins", tps, M and (lambda tp, t: _t(M.half(lua_str(tp.get("path", tp["id"])), lua_str(t)))), note, glue=True)  # noqa: E704,E501 each text as Forever Quest Pins builds it (M.half in flow_fqp.lua); tps: flow_fqp_steps.templates()
def litemount(check, M, tps, note=""): run(check, "UADD_LiteMount", tps, M and (lambda tp, t: [_t(x) for x in (lambda v: v if isinstance(v, tuple) else (v,))(M.half(lua_str(tp["id"]), lua_str(t)))]), note)  # noqa: E704,E501 each text as LiteMount builds it from L (M.half in flow_litemount.lua; "Not %s" both ways); tps: flow_litemount_steps.templates()
# RareScanner, Pawn, GatherMate2, Scrap and Road to Sixty: halves_mods2.py (imported at the top).
