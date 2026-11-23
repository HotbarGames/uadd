"""The symptom check for boxes (boxes.lua; docs/LESSONS2.md lesson 18, LESSONS3.md 32, LESSONS4.md 44), per segment.

Each Client loads boxes.lua (from wow_fontfam.lua), which sends here every hit: a FontString shown and placed at a
HARNESS.step with Cyrillic text in a font that has none (a box in the game). Built like tipfont.py: take() hands over
what came in and starts again, merge() joins the parts of one segment that ran in other processes (pool.py), and
segment() turns them into one check. A client loaded with a cut (a mutant) sets H.boxQuiet and reports nothing.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
STATE = {"hits": []}
MAX = 20


def lua_source():
    with open(os.path.join(HERE, "boxes.lua"), encoding="latin-1") as f:
        return f.read()


def _text(s):
    s = str(s)
    try:
        return s.encode("latin-1").decode("utf-8", "replace")   # the Lua bytes came in as latin-1 (loader.py)
    except UnicodeEncodeError:
        return s


ADDONS = os.environ.get("UADD_ADDONS_DIR") or "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"
_CYR = {}


def file_cyr(path):
    """True when an addon's own font file ("Interface\\AddOns\\<addon>\\...") has і, є and ж; else False."""
    path = _text(path)
    if path not in _CYR:
        rel = path.replace("\\", "/").split("/", 2)[2:]       # drop "Interface/AddOns"
        _CYR[path] = False
        try:
            from fontTools.ttLib import TTFont
            cmap = TTFont(os.path.join(ADDONS, rel[0]), lazy=True).getBestCmap()
            _CYR[path] = all(c in cmap for c in (0x456, 0x454, 0x436))
        except Exception:
            pass                                                 # no fontTools or no file: strict
    return _CYR[path]


def report(name, path, sample):
    hit = f"{_text(name)} {_text(path)}: {_text(sample)}"
    if hit not in STATE["hits"] and len(STATE["hits"]) < MAX:
        STATE["hits"].append(hit)


def take():
    got = {"hits": list(STATE["hits"])}
    STATE["hits"] = []
    return got


def merge(takes):
    out = {"hits": []}
    for got in takes:
        out["hits"] += [h for h in got["hits"] if h not in out["hits"]]
    return out


def segment(key, check, got=None):
    """[check] for what came in since the last call (or for `got`); [] when nothing showed a box."""
    got = take() if got is None else got
    if not got["hits"]:
        return []
    hits = got["hits"]
    return [check(f"no boxes on screen: {key}", False, "; ".join(hits[:8]) + f" ({len(hits)} texts)")]
