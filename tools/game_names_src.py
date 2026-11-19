"""What tools/test_game_names.py reads (docs/LESSONS.md, lesson 9): UALL Forever's (UALLF) name tables, and
each module's texts as [(key, English, our Ukrainian or "")]. The English is read from the installed addon,
never kept here.

UALLF is read from $UALLF_DIR, $UADD_ADDONS_DIR/UALLF or the WoW _forever_ folder; {} when it is not
installed. A module whose addon is not installed gives None.
"""
import functools
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fxpb_words as FW  # noqa: E402
import hashtext as H  # noqa: E402

WOW_ADDONS = "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"
TABLES = [("Items.lua", "itemNames", "item"), ("Spells.lua", "spellNameEN", "spell"),
          ("NpcNames.lua", "npcNames", "npc"), ("World.lua", "zoneNames", "zone"),
          ("Quests.lua", "questTitles", "quest")]
ROW = re.compile(r'^\s*\[("(?:[^"\\]|\\.)*")\]\s*=\s*("(?:[^"\\]|\\.)*"),')


def uallf_dir():
    if os.environ.get("UALLF_DIR"):
        return Path(os.environ["UALLF_DIR"])
    return Path(os.environ.get("UADD_ADDONS_DIR") or WOW_ADDONS) / "UALLF"


@functools.lru_cache(maxsize=None)
def uallf_names():
    """{English name: (Ukrainian, kind)} from UALLF's name tables; {} when UALLF is not installed."""
    names = {}
    for fname, table, kind in TABLES:
        path = uallf_dir() / fname
        if not path.is_file():
            return {}
        inside = False
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                if line.startswith("ns.%s = {" % table):
                    inside = True
                elif inside and line.startswith("}"):
                    break
                elif inside:
                    m = ROW.match(line)
                    if m:
                        names.setdefault(FW.unlua(m.group(1)), (FW.unlua(m.group(2)), kind))
    return names


# ── Modules ──────────────────────────────────────────────────────────────────────────────────────

def _lua_data(path):
    """{key: Ukrainian} from a hashtext.write_lua data file: exact entries and templates (slots dropped)."""
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s*\["(\d+:[0-9a-f]{8})"\] = ("(?:[^"\\]|\\.)*"),$', line)
        if m:
            out[m.group(1)] = FW.unlua(m.group(2))
            continue
        m = TEMPLATE.search(line)
        if m:
            out[m.group(1)] = _template_uk(m)
    return out


# A template line of a data file: its key and its uk = { "text", 1, "text" } list (slot numbers dropped). A
# string in the list may hold braces of its own (a plural form {один|два}).
TEMPLATE = re.compile(r'\bid = "(\d+:[0-9a-f]{8})".*?\buk = \{((?:"(?:[^"\\]|\\.)*"|[^"}])*)\}')


def _template_uk(m):
    return "".join(FW.unlua(s) for s in re.findall(r'"(?:[^"\\]|\\.)*"', m.group(2)))


def autopotion():
    """(rows, own words) for UADD_AutoPotion, or None without Auto Potion."""
    import make_ap_text as AP
    texts = AP.texts(AP.addon_dir())
    if not texts:
        return None
    uk = _lua_data(AP.DATA)
    rows = [(k, en, "" if kind == "skip" else uk.get(k, "")) for k, kind, en, _ in texts]
    return rows, set(AP.MACROS)


def bagnon():
    """(rows, own words) for UADD_Bagnon, or None without Bagnon. Our Ukrainian: data/<table>.lua, by key."""
    import make_bgn_text as B
    texts, _ = B.texts(B.addon_dir())
    if not texts:
        return None
    uk = {}
    for path in sorted(B.DATA.glob("*.lua")):
        which = None
        for line in path.read_text(encoding="utf-8").splitlines():
            m = re.match(r"B\.(\w+) = \{$", line)
            if m:
                which = m.group(1)
                continue
            m = re.match(r'\s*\[("(?:[^"\\]|\\.)*"|\d+)\] = ("(?:[^"\\]|\\.)*"),$', line)
            if which and m:
                k = m.group(1)
                uk["%s:%s" % (which, FW.unlua(k) if k.startswith('"') else k)] = FW.unlua(m.group(2))
    return [(k, en, uk.get(k, "")) for k, _, en, _ in texts], {"Bagnon"}


def mastercraft():
    """(rows, own words) for UADD_Mastercraft, or None without Mastercraft. Our Ukrainian: data/text*.lua, by key
    (a multi-line text: its lines' Ukrainian joined; a line we have not translated makes the whole text empty)."""
    import make_mc_text as M
    import mc_text_lib as L
    rows_en = L.source(M.addon_dir())
    if not rows_en:
        return None
    uk = {}
    for path in sorted(M.DATA.glob("*.lua")):
        for line in path.read_text(encoding="utf-8").splitlines():
            m = re.match(r'E\["(\d+:[0-9a-f]{8})"\] = ("(?:[^"\\]|\\.)*")$', line)
            if m:
                uk[m.group(1)] = FW.unlua(m.group(2))
                continue
            m = TEMPLATE.search(line)
            if m:
                uk[m.group(1)] = _template_uk(m)
    rows = []
    for en, _, _, _, _ in rows_en:
        parts = [uk.get(H.key(L.strip(x)), "") for x in en.split("\n") if L.strip(x)]
        rows.append((H.key(en), en, "\n".join(parts) if parts and all(parts) else ""))
    words = {w for _, en, _ in rows for w in re.findall(r"[A-Za-z][A-Za-z'-]*", en)}
    ui = {w for w in words if H.key(w) in MC_UI_WORDS}
    return rows, {"Mastercraft", "GatherMate"} | CALENDAR | LANGUAGES | glossary_ranks() | ui


# Mastercraft's words that the check takes for names but that name no game thing: its own tabs, pages,
# buttons, settings and styles, a placeholder, a region, and the game's UI (a frame, a list, a menu button,
# gear slots and item types, a key). By hash (hashtext.key of the word), so its English is not kept here.
# Reviewed 2026-11-19. Add one only after reading every text it is in: a word here is skipped in all of them.
MC_UI_WORDS = {
    "5:0cf9fed8", "6:a77f30fe", "7:6c0d6a8f", "8:8f1e82eb", "6:ce81b906", "4:7c85f041",   # tabs, pages, buttons
    "6:c5eb6dfe", "4:7c8903d0", "6:c38d6fca", "7:2c46f767", "6:d9e968e8", "8:8d26dd54",   # buttons, styles
    "7:1219c7c0", "6:b1589555",                                                         # placeholder, region
    "6:b2d2363d", "6:b9adaf89", "4:7c84f21f", "5:0cf62e3c", "4:7c8877b0", "8:cfe37487",   # the game's UI
    "12:69b0bb6d", "11:07a0d6d6",                                                       # item types, a key
}

# Capitalised English words that are never game names: months and days (also short), and languages.
CALENDAR = set("January February March April May June July August September October November December "
               "Jan Feb Mar Apr Jun Jul Aug Sep Sept Oct Nov Dec Monday Tuesday Wednesday Thursday Friday "
               "Saturday Sunday".split())
LANGUAGES = set("English German French Spanish Italian Portuguese Russian Polish Greek Korean Chinese Japanese "
                "Ukrainian".split())


def glossary_ranks():
    """The English of the glossary's one-word profession ranks. The owner's words for them (the brief and the
    glossary), so a UALLF item of the same English (a book) is not the rank the text names."""
    import glossary
    return {en for gid, e in glossary.Glossary().entries.items() if gid.startswith("prof.rank_")
            for en in e["en"] if " " not in en}


def _fxpb_like(maker):
    """(rows, own words) for a module built by make_fxpb_data / make_lsw_data, or None without its addon."""
    import glossary
    if not maker.have_addon():
        return None
    kept, _ = maker.collect()
    values = maker.ukrainian(kept, fresh=True)
    gl = glossary.Glossary()
    rows = []
    for _, en in maker.texts(kept):
        v = values.get(en)
        uk = FW.text_of(v, gl) if v else ""
        rows.append((H.key(en), en, uk or ""))
    return rows, set()


def layerswap():
    import make_lsw_data
    return _fxpb_like(make_lsw_data)


def foreverxpbar():
    import make_fxpb_data
    return _fxpb_like(make_fxpb_data)


# ForeverXPBar is not here yet: its many Title Case labels and key names give about 50 false hits.
# Bagnon neither: its Title Case labels ("Border Color") give 73 hits (2026-11-19), none a game name we wrote
# ("At the Auction House" is the glossary's «аукціон», the place, not UALLF's zone name).
MODULES = {"UADD_AutoPotion": autopotion, "UADD_LayerSwap": layerswap, "UADD_Mastercraft": mastercraft}
