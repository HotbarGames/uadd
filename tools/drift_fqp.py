"""tools/drift.py's extraction for UADD_ForeverQuestPins (Forever Quest Pins, GPL-3.0: our data is keyed by its
English, so the English may be tracked). Standard library only."""
from pathlib import Path

import luatok

REPO = Path(__file__).resolve().parent.parent


def _l_keys(toks):
    for i in range(len(toks) - 3):
        if (toks[i][:2] == (luatok.NAME, "L") and toks[i + 1][:2] == (luatok.SYM, "[")
                and toks[i + 2][0] == luatok.STR and toks[i + 3][:2] == (luatok.SYM, "]")):
            yield toks[i + 2][1]


def _table_keys(toks):
    for i in range(len(toks) - 3):
        if (toks[i][:2] == (luatok.SYM, "[") and toks[i + 1][0] == luatok.STR
                and toks[i + 2][:2] == (luatok.SYM, "]") and toks[i + 3][:2] == (luatok.SYM, "=")):
            yield toks[i + 1][1]


def _news_lines(toks):
    """The strings of WhatsNew.lua's `lines = { ... }` (lesson 42: shown on login, keyed by their English)."""
    for i in range(len(toks) - 2):
        if toks[i][:2] == (luatok.NAME, "lines") and toks[i + 1][:2] == (luatok.SYM, "=") \
                and toks[i + 2][:2] == (luatok.SYM, "{"):
            for t in toks[i + 3:]:
                if t[:2] == (luatok.SYM, "}"):
                    return
                if t[0] == luatok.STR:
                    yield t[1]


def extract(path):
    """Every L["..."] key in the addon's own code, every key of its Localization.lua and every What's New line
    (WhatsNew.lua), as drift rows."""
    keys = {}
    for f in sorted(path.rglob("*.lua")):
        rel = f.relative_to(path).as_posix()
        if rel.startswith("Database/"):
            continue
        toks = list(luatok.tokens(luatok.read(f)))
        for k in _l_keys(toks):
            keys.setdefault(k, rel)
        if rel == "Localization.lua":
            for k in _table_keys(toks):
                keys.setdefault(k, rel)
        if rel == "WhatsNew.lua":
            for k in _news_lines(toks):
                keys.setdefault(k, rel)
    return [("L", None, k, rel) for k, rel in sorted(keys.items())]


def old():
    """The English keys our data holds: T["..."] in UADD_ForeverQuestPins/data/uk_*.lua."""
    out = []
    for f in sorted((REPO / "UADD_ForeverQuestPins" / "data").glob("uk_*.lua")):
        toks = list(luatok.tokens(luatok.read(f)))
        for i in range(len(toks) - 3):
            if (toks[i][:2] == (luatok.NAME, "T") and toks[i + 1][:2] == (luatok.SYM, "[")
                    and toks[i + 2][0] == luatok.STR and toks[i + 3][:2] == (luatok.SYM, "]")):
                out.append(toks[i + 2][1])
    return out
