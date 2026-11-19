"""The half-translation check (halves.py) for each module: its templates' real English, its free
slots and its translate path. Each flow named in halves_cover.COVERED calls its function here.
The English is read from the installed addon at test time; without it the check is a note.
Made-up names for free slots: "Quix" (an item link, a key binding "QUIX" where the module wants one).
"""
import os
import re
import sys

from halves import run, tpl
from loader import lua_str, txt

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import halves_cover  # noqa: E402
import hashtext  # noqa: E402

NAME = "Quix"
SKIP = halves_cover.SKIP


def _s_slots(en):
    return [k for k, kind in enumerate(halves_cover.kinds(en), 1) if kind == "s"]


def _t(v):
    return txt(v) if isinstance(v, str) else None


def fxpb(check, M):
    """ForeverXP Bar: Words.Text (the stand-in's M.uk); free slots from fxpb_words.FREE and BLANK."""
    import fxpb_words
    import make_fxpb_data
    if not make_fxpb_data.have_addon():
        return run(check, "UADD_ForeverXPBar", [], None, SKIP)
    kept, _ = make_fxpb_data.collect()
    tps = []
    for kind, en in make_fxpb_data.texts(kept):
        if kind == "format":
            k = hashtext.key(en)
            free = {i: NAME for i in fxpb_words.FREE.get(k, [])}
            free.update({i: "s" for i in fxpb_words.BLANK.get(k, [])})
            tps.append(tpl(k, en, free, blank=set(fxpb_words.BLANK.get(k, []))))
    run(check, "UADD_ForeverXPBar", tps, lambda tp, t: _t(M.uk(lua_str(t))), glue=True)


def lsw(check, M):
    """LayerSwap: Words.Text (the stand-in's M.uk); free slots from lsw_words.FREE and BLANK."""
    import lsw_words
    import make_lsw_data
    if not make_lsw_data.have_addon():
        return run(check, "UADD_LayerSwap", [], None, SKIP)
    kept, _ = make_lsw_data.collect()
    tps = []
    for kind, en in make_lsw_data.texts(kept):
        if kind == "format":
            k = hashtext.key(en)
            free = {i: NAME for i in lsw_words.FREE.get(k, [])}
            free.update({i: "s" for i in lsw_words.BLANK.get(k, [])})
            tps.append(tpl(k, en, free, blank=set(lsw_words.BLANK.get(k, []))))
    run(check, "UADD_LayerSwap", tps, lambda tp, t: _t(M.uk(lua_str(t))), glue=True)


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


DUI_FREE = {"item": "|cff1eff00|Hitem:2140::::::::60:::::|h[Quix]|h|r", "key": "QUIX"}


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


_ATT = r"""
local ns, out = HARNESS.ns.UADD_Attune, {}
ns.Pairs(function(en, uk, key)
  if type(en) == "string" and type(uk) == "string" and uk ~= "" and uk ~= en
      and (en:find("%s", 1, true) or en:find("##%u[%u%d_]*##")) then out[#out + 1] = { en, key or false } end
end)
return out
"""
ATT_FREE = {"value": "7", "player": NAME, "target": NAME}
ATT_BY_KEY = {"WHAT": "Guild"}   # a place Attune fills with the text of one of its own keys (its real value)


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
        for row in lua.execute(_ATT).values():
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


# Words.lua's own shapes around a name ("Level %s", the card's "Name, Name", a dungeon and its levels),
# in colour pieces, and as OpenMap's Map/Dungeons.lua builds them: its English around L's words (ours,
# so Ukrainian) and a level range in colour. Then the lines OpenMap builds from L's words and its own
# parts (Parts.lua): the News title with a version, a note's and a pin's title, a pin row and the dock's
# "To" (both forms) with a zone name.
RFK, RANGE = "Razorfen Kraul", "|cffff804024-33|r"
OM_SHAPES = (("Level %s", {}), ("%s, %s", {1: RFK, 2: RFK}), ("%s  %d-%d", {1: RFK}),
             ("Floor 1 |cffffffff%s|r", {}), ("|cffffd100%s|r %s", {1: RFK, 2: RFK}),
             ("|cffffd100%s|r  |cff998866%d / %d|r", {1: "Floor 1"}),
             ("Level %s   |cffbbbbbb%s|r", {1: RANGE, 2: "Raid"}), ("Level %s   |cffbbbbbbРейд|r", {1: RANGE}),
             ("Level %s  (від 20)", {}), ("|cffffd100%s  %s, %s  %s|r", {1: RFK, 2: RANGE, 3: RFK, 4: RANGE}),
             ("|cffe6c27a%s|r  |cff998866(Questie)|r", {1: "Quests"}), ("|cff808080%s|r", {1: "done"}),
             ("What's new in OpenMap  |cff998866%s|r", {1: "v0.8.9"}), ("Нова нотатка · %s", {1: RFK}),
             ("Нотатка #%d · %s", {2: RFK}), ("%s · |cffffffffmy note|r |cffe6c27a(малюнок)|r", {1: RFK}),
             ("Мітка · %s  %.1f, %.1f", {1: RFK}), ("Куди: %s", {1: RFK}), ("To %s", {1: RFK}))
# The World Map's hover label as OpenMap writes it (Label.lua): a zone and its level range in colour.
OM_LABEL = (("%s |cffff8040(%d-%d)|r", {1: RFK}), ("%s |cff40c040(%d)|r", {1: RFK}))


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


def _parts(en, text):
    """The slot values of `text` read back by the English template `en` (all %s), or None."""
    m = re.match("^" + "(.*?)".join(re.escape(p) for p in en.split("%s")) + "$", text, re.S)
    return [lua_str(v) for v in m.groups()] if m else None


def _named(v):
    """An item part of the joined-item line, "Name (Boss)": (name, boss or None)."""
    m = re.match(r"^(.*) \(([^()]*)\)$", txt(v))
    return (lua_str(m[1]), lua_str(m[2])) if m else (v, None)


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
             "LOOT_MADE_FROM": lambda v: X.child(*_named(v[0]), *_named(v[1]))[1]}

    def tr(tp, t):
        v = _parts(tp["en"], t)
        return _t(paths[tp["id"]](v)) if v else None
    run(check, "UADD_DungeonJournal", tps, tr)


def _bgn_value(s):
    """A number, or money as the game writes it (digits and coin icons, maybe coloured)."""
    s = re.sub(r"\|T[^|]*\|t|\|c[0-9a-fA-F]{8}|\|r", "", s)
    return re.fullmatch(r"[\d\s.,]+", s) is not None


def bgn(check, M, rows):
    """Bagnon: the module only puts our words into Bagnon's AceLocale tables, and Bagnon formats them
    itself (L[key]:format(values)). So a text is read back into its values by the English template and
    formatted with the table's word now (the flow's M.shows). Free slots: make_bgn_text.FREE. A VALUE slot
    (make_bgn_text.VALUE: a number or money, Bagnon's own code passes nothing else) holding no digit is
    not a text Bagnon ever shows: it stays as it is. rows: make_bgn_text.texts(); None: not installed."""
    import make_bgn_text
    if M is None or not rows:
        return run(check, "UADD_Bagnon", [], None, SKIP)
    tps = [tpl(k, en, {i: NAME for i in make_bgn_text.FREE.get(k, [])}) for k, kind, en, _ in rows
           if kind == "template"]

    def tr(tp, t):
        v = _parts(tp["en"], t)
        if v is None:
            return None
        if tp["id"] in make_bgn_text.VALUE and not all(_bgn_value(x) for x in v):
            return t
        which, _, key = tp["id"].partition(":")
        return _t(M.shows(which, key, *v))
    run(check, "UADD_Bagnon", tps, tr)
