"""Mastercraft's texts for UADD_Mastercraft: the source, the review batches and the checks.

Mastercraft is all rights reserved: its English is read from the installed addon (the keys of
Locales/ru.lua and Locales/ru_data.lua, the union of all its locales) and goes only into the
git-ignored local/mastercraft/NN.txt batches. tools/make_mc_text.py is the command line.
Keys are stored the way Mastercraft's Locale.lua stores them (Strip: no spaces around, no colour code
around the whole text); a multi-line key with a slot is one text per line there, so it is here too.
The parts every hash-keyed module shares (batches, review files, checks) live in tools/text_lib.py.
"""
import re
from pathlib import Path

import luatok
from text_lib import (CYR, GREF, IS_PATTERN, LATIN_WORD, PLURAL, WS, batches, block, check,  # noqa: F401
                      ends, esc, expand, is_pattern, kind_of, read_review, unesc)

COLOUR = re.compile(r"^\|c[0-9A-Fa-f]{8}")
SECTION_RULE = re.compile(r"^-{20,}\s*$")
SOURCES = ("Locales/ru.lua", "Locales/ru_data.lua")


def strip(en):
    """Locale.lua Strip: no spaces around, then no colour code around the whole text (again)."""
    en = en.strip(WS)
    if COLOUR.match(en) and en.endswith("|r") and en.count("|c") == 1 and en.count("|r") == 1:
        return strip(en[10:-2])
    return en


def sections(text):
    """{line number: (section, sub)}: the top-level comment just before an Add({ (under a ---- rule or
    not), and the last indented comment inside it."""
    out, sec, sub = {}, "Other", ""
    lines = text.split("\n")
    for n, line in enumerate(lines, 1):
        s = line.strip()
        after = [x for x in lines[n:n + 3] if not SECTION_RULE.match(x)]
        if line.startswith("--") and not SECTION_RULE.match(line) and after and after[0].startswith("Add("):
            sec, sub = s.lstrip("- ").strip(), ""
        elif line.startswith((" ", "\t")) and s.startswith("--") and not SECTION_RULE.match(s):
            sub = s.lstrip("- ").strip()
        out[n] = (sec, sub)
    return out


def read_keys(path):
    """[(English key, line)] of every ["key"] = ... entry of one locale file."""
    text = luatok.read(path)
    t = list(luatok.tokens(text))
    keys = []
    for i in range(len(t) - 3):
        if t[i][:2] == (luatok.SYM, "[") and t[i + 1][0] == luatok.STR and t[i + 2][:2] == (luatok.SYM, "]") \
                and t[i + 3][:2] == (luatok.SYM, "="):
            keys.append((t[i + 1][1], t[i + 1][2]))
    return keys, sections(text)


def source(addon):
    """[(English, kind, section, sub, file)] in source order, each English once (stripped like Locale.lua)."""
    rows, seen = [], set()
    for rel in SOURCES:
        path = Path(addon) / rel
        if not path.is_file():
            continue
        keys, secs = read_keys(path)
        for raw, line in keys:
            en = strip(raw)
            if not en or en in seen:
                continue
            seen.add(en)
            sec, sub = secs.get(line, ("Other", ""))
            rows.append((en, kind_of(en), sec, sub, Path(rel).name))
    return rows
