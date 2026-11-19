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
        m = re.search(r'\bid = "(\d+:[0-9a-f]{8})".*\buk = \{(.*?)\}', line)
        if m:
            out[m.group(1)] = "".join(FW.unlua(s) for s in re.findall(r'"(?:[^"\\]|\\.)*"', m.group(2)))
    return out


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
MODULES = {"UADD_AutoPotion": autopotion, "UADD_LayerSwap": layerswap}
