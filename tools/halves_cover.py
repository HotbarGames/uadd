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
    "UADD_DialogueUI": ("flow_dialogueui.py", "dui"),
    "UADD_Auctionator": ("flow_auc_more.py", "auc"),
    "UADD_Attune": ("flow_att_fix.py", "att"),
    "UADD_OpenMap": ("flow_openmap.py", "openmap"),
    "UADD_DungeonJournal": ("flow_dj_summon.py", "dj"),
}
NO_SLOTS = {
    "UADD_Questie": "gives Questie whole Ukrainian strings and names; no UADD code fills a template slot "
                    "(the tracker's objective lines are left to UALL Forever, Tracker.lua)",
}
UNFIT = {
    "UADD_ForeverXPBar": {
        "18:e82f8f8b": "no Ukrainian for it yet: its slot holds a whole message the addon sends to chat, "
                       "joined from parts at run time, so there is no fixed text to translate",
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
    m = re.search(r"\n" + re.escape(start) + r" = \{\n(.*?)\n\}", text, re.S)
    return m.group(1) if m else ""


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


def marks():
    """module -> (problems, note)."""
    out = {}
    for mod, fn in (("UADD_ForeverXPBar", _fxpb), ("UADD_DialogueUI", _dui), ("UADD_Auctionator", _auc),
                    ("UADD_Attune", _att), ("UADD_OpenMap", _openmap)):
        bad = fn()
        out[mod] = ([], SKIP) if bad is None else (bad, "")
    return out
