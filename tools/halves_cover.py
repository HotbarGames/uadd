"""Which modules the half-translation check covers, and checks of their free-slot marks.

A half translation is a template that matched while one of its slots kept English ("Рівень card theme").
tools/harness/halves.py fills every slot with made-up English and runs the text through the module.
This file needs no Lua: tools/test_halves.py uses it to make sure every UADD_* module is either covered
or listed as filling no slots, and that every free-slot mark points to a real slot.

  COVERED      module -> (the harness flow file that runs its check, the halves_mods.py function)
  NO_SLOTS     module -> why it fills no template slot from text on screen
  UNFIT        module -> {template id: why it stays English even with fitting values}: a real gap,
               not a bug (halves.py fails on one missing here, and on a stale entry)
  marks()      module -> (problems, note): each module's free-slot marks against the real English
               (read from the installed addon; note says "skipped" when it is not installed)
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(HERE))
import hashtext  # noqa: E402

COVERED = {
    "UADD_ForeverXPBar": ("flow_fxpb_mixed.py", "fxpb"),
    "UADD_LayerSwap": ("flow_lsw_mixed.py", "lsw"),
    "UADD_DialogueUI": ("flow_dialogueui.py", "dui"),
    "UADD_Auctionator": ("flow_auc_more.py", "auc"),
    "UADD_Attune": ("flow_att_fix.py", "att"),
    "UADD_OpenMap": ("flow_openmap.py", "openmap"),
    "UADD_DungeonJournal": ("flow_dj_summon.py", "dj"),
    "UADD_AutoPotion": ("flow_autopotion.py", "ap"),
    "UADD_Bagnon": ("flow_bagnon.py", "bgn"),
    "UADD_Mastercraft": ("flow_mastercraft.py", "mc"),
    "UADD_WhatsTraining": ("flow_whatstraining.py", "wt"),
    "UADD_TomTom": ("flow_tomtom.py", "tomtom"),
    "UADD_RareScanner": ("flow_rarescanner.py", "rs"),
    "UADD_Pawn": ("flow_pawn.py", "pawn"),
    "UADD_GatherMate2": ("flow_gm.py", "gm"),
    "UADD_Scrap": ("flow_scrap.py", "scrap"),
    "UADD_SpeedyAutoLoot": ("flow_sal.py", "sal"),
    "UADD_WaypointUI": ("flow_wp.py", "wp"),
    "UADD_ForeverQuestPins": ("flow_fqp.py", "fqp"),
    "UADD_LiteMount": ("flow_litemount.py", "litemount"),
    "UADD_WhatTheWhisper": ("flow_wtw.py", "wtw"),
    "UADD_LootTriage": ("flow_lt.py", "lt"),
    "UADD_DeleteCheapestItem": ("flow_dci.py", "dci"),
    "UADD_WowheadQuickLink": ("flow_wql.py", "wql"),
    "UADD_BugSack": ("flow_bs.py", "bs"),
    "UADD_GearQuestForever": ("flow_gq.py", "gq"),
    "UADD_RoadToSixty": ("flow_rts_halves.py", "rts"),
    "UADD_OneForAll": ("flow_ofa_halves.py", "ofa"),
}
NO_SLOTS = {
    "UADD_Questie": "gives Questie whole Ukrainian strings and names; no UADD code fills a template slot "
                    "(the tracker's objective lines are left to UALL Forever, Tracker.lua)",
}
UNFIT = {
    "UADD_GearQuestForever": {
        "L.b32b5450": "no entry in our data yet: glue alone (a number, a colour and one of its texts), no words; "
                      "built at run time with its text already ours, so only the hold key cannot turn it",
    },
    "UADD_ForeverXPBar": {
        "18:e82f8f8b": "no Ukrainian for it yet: its slot holds a whole message the addon sends to chat, "
                       "joined from parts at run time, so there is no fixed text to translate",
    },
    "UADD_LayerSwap": {
        "25:2288ecc9": "no Ukrainian for it on purpose: its name in front of a chat line; Chat.lua keeps the "
                       "name and translates the line after it",
    },
    "UADD_GatherMate2": {
        "L.adde7058": "stays English on purpose: the world map pin menu glues a node's game name after it, and "
                      "node names stay English (GatherMate2 matches them with the game's tooltip); the module "
                      "never writes this key into GatherMate2's table (Swap.lua PIN)",
    },
    "UADD_Scrap": {k: "stays English on purpose: a chat line with an item link (a game name) in it; the module "
                      "never writes this key into Scrap's table (scrap_rules.STAY)"
                   for k in ("L.Added", "L.Destroyed", "L.Forgotten", "L.Removed")},
    "UADD_WhatTheWhisper": {
        "L.17d2f1f2": "stays English on purpose: its slot holds a size with English units (sort u in "
                      "tools/wtw_rules.py); the module never writes this key into its table (Swap.lua W.Skip)",
    },
    "UADD_ForeverQuestPins": dict(
        {k: "debug line, kept English on purpose (Lc.NAMES): never written into its L"
         for k in ("59:a05b813a", "32:7421be4c", "19:716b8f42")},
        **{k: "/fqp debug or status output, kept English on purpose (data/uk_config.lua): no Ukrainian for it"
           for k in ("34:a889335a", "37:a5d0a754", "34:cc8dc0a3")}),
    "UADD_RoadToSixty": dict(
        {k: "stays English on purpose: a slot holds a duration in the addon's English units (sort u in ns.SORT)"
         for k in ("Code.205f37f2", "Code.83a6ef2d", "Code.667eca79", "Code.16a2068b")},
        **{"Code.9ff8af0a": "no Ukrainian for it yet: no sort and no text shipped in ns.RTS"}),
    "UADD_OneForAll": dict(
        {"Code." + k: "a real gap: its t slot holds a capitalised text of ours (a profession, a filter), and Words.lua "
                      "Ours takes only small letters there, so the whole line stays English"
         for k in ("530a41e7 7d7ef18e 99bc95d2 62fba321 93f737ea abccb153 268cf87e 0c54d8fb 1617a860 944cf9dd "
                   "f6f15ff7 699ab1d9 ecf3e226 efb22e55 9b269860 b5bd0e78 d8e9ae47 e39f3245 2e174645 dedd2926 "
                   "cb43a0f6 be5ed555 d25947f0 3e777cab").split()},
        **{"Code." + k: "a real gap: a free name with a value in one line; Words.lua fills a free name only in a "
                        "template of one slot (NameSlot), so the whole line stays English"
           for k in "805fca38 dba8f5a8 2a894688 dbee665a ca2a7b8b 71894578 31774ba8 9d8cd6f1 ef33a4f0 b40742bd "
                    "3299f542 27c6530f".split()},
        **{"Code." + k: "no Ukrainian for it on purpose: a hunter pet note full of game names (spells, places) "
                        "we never write (lesson 9)"
           for k in "0b96a301 a03a1ee0 a501b8fa c4438c7f 709d7f8f 704b50b2 75277a9f 11c1e2f2 0a4fc08e ed642bae "
                    "13f3acda c8acb9e8 14b55eb6 45a6ad04 0c11e0cf e841de76 dfb4d1e9 ade693b8 979b6913 "
                    "3d872f28".split()},
        **{"Code." + k: "no Ukrainian for it yet: no text shipped in ns.OFA"
           for k in "ce10d379 a174ec26".split()},
        **{"Code.9856bfbc": "stays English: its literal 1 is read as a value slot, so the one-item line never "
                            "matches its own template",
           "Code.24423d3c": "stays English: two value slots glued with no gap between, which the sample values do not fit",
           "Code.7cd10afd": "stays English: an ability text with five value slots that the sample values do not fit"}),
    "UADD_Mastercraft": {
        "21:c3a7c5ff": "a real gap: two slots side by side (a guide step's title, then a crafts count the code "
                       "glues on, or nothing); Words.lua gives the first nothing, so it fits only with no count, "
                       "and a line with a count stays whole English",
    },
}
DUI_KINDS = ("name", "quest", "npc", "item", "list", "addon", "player", "key")
SKIP = "skipped: the addon is not installed"


def kinds(en):
    """The kinds of en's slots, in order (slot 1 first)."""
    return [t[1] for t in hashtext.tokens(en) if t[0] == "slot"] if en else []


def s_slot(en, i):
    k = kinds(en)
    return 1 <= i <= len(k) and k[i - 1] == "s"


def _src(rel):
    return (REPO / rel).read_text(encoding="utf-8")


def _block(text, start):
    # A block it cannot find (say, a closing brace moved onto the last line) would read as "no free slots"
    # and fail far away, in the half-translation check: say so here instead.
    m = re.search(r"\n" + re.escape(start) + r" = \{\n(.*?)\n\}", text, re.S)
    if not m:
        raise ValueError(f"{start} = {{ ... }} not found: its closing brace must stand alone on a line")
    return m.group(1)


def auc_free():
    """Words.lua FREE: Auctionator locale key -> slot numbers that take any text."""
    block = _block(_src("UADD_Auctionator/Words.lua"), "local FREE")
    return {k: [int(i) for i in v.split(",")] for k, v in re.findall(r"([A-Z0-9_]+) = \{ ([\d, ]+) \}", block)}


def dui_slots():
    """Slots.lua SLOTS: DialogueUI locale key -> what its %s holds."""
    block = _block(_src("UADD_DialogueUI/Slots.lua"), "local SLOTS")
    return dict(re.findall(r'\["([^"]+)"\] = "(\w+)"', block))


def _unlua(lit):
    import make_dui_data
    return make_dui_data.unlua(lit)


def openmap_free():
    """Locale.lua Lc.FREE: OpenMap's English key -> slot numbers that take any text."""
    block = _block(_src("UADD_OpenMap/Locale.lua"), "Lc.FREE")
    pairs = re.findall(r'\[("(?:[^"\\]|\\.)*")\] = \{ ([\d, ]+) \}', block)
    return {_unlua(k): [int(i) for i in v.split(",")] for k, v in pairs}


def openmap_keys():
    """The English keys of UADD_OpenMap/ui/locale.lua (OpenMap is MIT: the repo keeps them)."""
    return {_unlua(k) for k in re.findall(r'^\s*\[("(?:[^"\\]|\\.)*")\]\s*=', _src("UADD_OpenMap/ui/locale.lua"), re.M)}


def att_marks():
    """Pairs.lua: {place name: kind}, {locale key: {place: kind}}, the free kinds."""
    text = _src("UADD_Attune/Pairs.lua")
    kind = dict(re.findall(r'(\w+) = "(\w+)"', _block(text, "local KIND")))
    by = {k: {p: v} for k, p, v in re.findall(r'(\w+) = \{ (\w+) = "(\w+)" \}',
                                              re.search(r"local BYKEY = \{(.*)\}\n", text).group(1))}
    free = set(re.findall(r"(\w+) = true", re.search(r"local FREE = \{(.*)\}\n", text).group(1)))
    return kind, by, free


def _fxpb():
    import fxpb_words
    import make_fxpb_data
    if not make_fxpb_data.have_addon():
        return None
    kept, _ = make_fxpb_data.collect()
    fmt = {hashtext.key(en): en for kind, en in make_fxpb_data.texts(kept) if kind == "format"}
    marks = list(fxpb_words.FREE.items()) + list(fxpb_words.BLANK.items())
    return [(k, i) for k, ii in marks for i in ii if not s_slot(fmt.get(k), i)]


def _lsw():
    import lsw_words
    import make_lsw_data
    if not make_lsw_data.have_addon():
        return None
    kept, _ = make_lsw_data.collect()
    fmt = {hashtext.key(en): en for kind, en in make_lsw_data.texts(kept) if kind == "format"}
    marks = list(lsw_words.FREE.items()) + list(lsw_words.BLANK.items())
    return [(k, i) for k, ii in marks for i in ii if not s_slot(fmt.get(k), i)]


def _dui():
    import make_dui_data
    path = make_dui_data.DEFAULT / "Locales" / "enUS.lua"
    if not path.is_file():
        return None
    real, _ = make_dui_data.read_enus(path)
    real = {make_dui_data.unlua(k): v[1] for k, v in real.items()}
    ours = {make_dui_data.unlua(k) for k, _ in make_dui_data.read_locale()}
    return [(k, v) for k, v in dui_slots().items()
            if v not in DUI_KINDS or k not in ours or "s" not in kinds(real.get(k))]


def _auc():
    import make_auc_text
    addon = make_auc_text.addon_dir()
    if not (addon / "Locales" / "enUS.lua").is_file():
        return None
    real, _ = make_auc_text.read_enus(addon)
    ua = make_auc_text.read_ua()
    code = {hashtext.key(en): en for _, en in make_auc_text.all_code_texts(addon) if hashtext.is_template(en)}
    free = auc_free()
    bad = [(k, i) for k, ii in free.items() for i in ii if k not in ua or not s_slot(real.get(k, ("",))[0], i)]
    bad += [(k, i) for k, mk in make_auc_text.SLOTS.items() for i in sum(mk.values(), [])
            if not s_slot(code.get(k), i)]
    return bad + ([("FREE", "almost empty")] if len(free) <= 5 else [])


def _att():
    import make_att_text
    real, _ = make_att_text.enus(make_att_text.addon_dir())
    if not real:
        return None
    kind, by, free = att_marks()
    places = {p for en in real.values() for p in re.findall(r"##([A-Z][A-Z0-9_]*)##", en)}
    bad = [(p, k) for p, k in kind.items() if k in free and p not in places]
    bad += [(key, p) for key, m in by.items() for p in m if f"##{p}##" not in real.get(key, "")]
    return bad


def _openmap():
    keys = openmap_keys()
    return [(en, i) for en, ii in openmap_free().items() for i in ii if en not in keys or not s_slot(en, i)]


def _bgn():
    import make_bgn_text
    rows, _ = make_bgn_text.texts(make_bgn_text.addon_dir())
    if not rows:
        return None
    real = {k: en for k, _, en, _ in rows}
    return [(k, i) for k, ii in make_bgn_text.FREE.items() for i in ii if not s_slot(real.get(k), i)]


def marks():
    """module -> (problems, note)."""
    out = {}
    for mod, fn in (("UADD_ForeverXPBar", _fxpb), ("UADD_DialogueUI", _dui), ("UADD_Auctionator", _auc),
                    ("UADD_Attune", _att), ("UADD_OpenMap", _openmap), ("UADD_LayerSwap", _lsw),
                    ("UADD_Bagnon", _bgn)):
        bad = fn()
        out[mod] = ([], SKIP) if bad is None else (bad, "")
    return out
