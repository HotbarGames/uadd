"""Reads the installed BugSack for tools/make_bs_text.py: the English of its locale table (locales.lua, the block
before the other languages) and, from its code, which keys it reads and where. Which texts are kept and how:
tools/bs_rules.py. Nothing here names its English (All Rights Reserved).

Every text is keyed by UADD.Hash of the English as the module sees it at run time:
  L.<hash>     a value of its locale table (the module writes ours into the table by the hash of the English)
  Word.<hash>  a word its code glues into the session line (the string given to a session format)
  Game.<hash>  the game's word it shows (OPTIONS)
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import bs_rules as R  # noqa: E402
import hashtext as H  # noqa: E402
import luatok  # noqa: E402

ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
FOLDER = "BugSack"
TOC = "BugSack.toc"
LOCALES = "locales.lua"
CODE = ["core.lua", "sack.lua", "config.lua", "ldb.lua"]
GAME = ["Options"]                    # the game's OPTIONS, as its English client has it
FORMATS = ("localFormat", "sourceFormat")      # the session line's formats: the string they get is a word
S, N, Y = luatok.STR, luatok.NAME, luatok.SYM


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / FOLDER


def version(addon):
    toc = Path(addon) / TOC
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return m.group(1) if m else "?"


def _toks(path):
    return list(luatok.tokens(luatok.read(path))) if Path(path).is_file() else []


def english(addon):
    """{key: English} of the locale table's first block (up to the GetLocale branch)."""
    t, out = _toks(Path(addon) / LOCALES), {}
    for i in range(len(t) - 5):
        if t[i][:2] == (N, "GetLocale"):
            break
        if t[i][:2] != (N, "L"):
            continue
        if t[i + 1][:2] == (Y, "[") and t[i + 2][0] == S and t[i + 3][:2] == (Y, "]") \
                and t[i + 4][:2] == (Y, "=") and t[i + 5][0] == S:
            out[t[i + 2][1]] = t[i + 5][1]
        elif t[i + 1][:2] == (Y, ".") and t[i + 2][0] == N and t[i + 3][:2] == (Y, "=") and t[i + 4][0] == S:
            out[t[i + 2][1]] = t[i + 4][1]
    return out


def _line_names(t, i):
    """The names on token i's line before it."""
    j, out = i - 1, []
    while j >= 0 and t[j][2] == t[i][2]:
        if t[j][0] == N:
            out.append(t[j][1])
        j -= 1
    return out


def uses(addon):
    """[(key, kind, file, line)] for each L read in its code, and [(word, file, line)] given to a session format."""
    out, words = [], []
    for f in CODE:
        t = _toks(Path(addon) / f)
        in_names = 0
        for i in range(len(t) - 3):
            if t[i][:2] == (N, "names") and t[i + 1][:2] == (Y, "=") and t[i + 2][:2] == (Y, "{"):
                in_names = t[i][2]
            if t[i][0] == N and t[i][1] in FORMATS and t[i + 1][:2] == (Y, ":") and t[i + 2][:2] == (N, "format"):
                k = i + 4
                while k < len(t) and t[k][:2] != (Y, ")"):
                    if t[k][0] == S:
                        words.append((t[k][1], f, t[k][2]))
                    k += 1
            if t[i][:2] != (N, "L") or (i and t[i - 1][:2] == (Y, ".")):
                continue
            if t[i + 1][:2] == (Y, "[") and t[i + 2][0] == S and t[i + 3][:2] == (Y, "]"):
                key = t[i + 2][1]
            elif t[i + 1][:2] == (Y, ".") and t[i + 2][0] == N:
                key = t[i + 2][1]
            else:
                continue
            names = _line_names(t, i)
            if in_names == t[i][2]:
                kind = "menu"
            elif "error" in names:
                kind = "error"
            elif key == "bugGrabberMissing":
                kind = "missing"
            elif f == "core.lua":
                kind = "popup" if ("text" in names or "button1" in names) else "chat"
            elif f == "ldb.lua" or "GameTooltip" in names:
                kind = "tip"
            elif f == "config.lua":
                first = not any(x[:2] == (N, "L") for x in t[max(0, i - 12):i] if x[2] == t[i][2])
                kind = "option" if first or "CreateDropdown" in names else "tip"
            else:
                kind = "window"
            out.append((key, kind, f, t[i][2]))
    return out, words


PREFIX = {"word": "Word.", "game": "Game."}


def key_of(kind, en):
    return PREFIX.get(kind, "L.") + H.djb2(en)


def found(addon):
    """[(kind, English, file, line)]: every text, kept or not (the first use of each locale key)."""
    addon = Path(addon)
    en = english(addon)
    used, words = uses(addon)
    out, seen = [], set()
    for key, kind, f, line in used:
        if key in en and key not in seen:
            seen.add(key)
            out.append((kind, en[key], f, line))
    out += [("unused", v, LOCALES, 0) for k, v in en.items() if k not in seen]
    for w, f, line in words:
        if w not in {x[1] for x in out if x[0] == "word"}:
            out.append(("word", w, f, line))
    out += [("game", g, "the game", 0) for g in GAME]
    return out


def source(addon):
    """(rows, why). rows: (key, English, batch, [(file, line)], note); why: {reason: count} of the texts left out."""
    addon = Path(addon)
    if not (addon / LOCALES).is_file():
        return [], {}
    rows, why, seen = [], {}, set()
    for kind, en, f, line in found(addon):
        kept, reason = R.keep(kind, en)
        if not kept:
            why[reason] = why.get(reason, 0) + 1
            continue
        key = key_of(kind, en)
        if key in seen:
            continue
        seen.add(key)
        R.KINDS[key] = kind
        rows.append((key, en, R.batch_of(key), [(f, line)], R.NOTES[kind]))
    return rows, why


def stays(addon):
    """{hash: reason} of the texts its windows may show that stay English on purpose."""
    return {H.djb2(en): kind for kind, en, *_ in found(addon) if kind in ("menu", "error")}


if __name__ == "__main__":      # prints the English: for a look, never into a tracked file
    a = addon_dir(sys.argv[1] if len(sys.argv) > 1 else None)
    rs, w = source(a)
    for r in rs:
        print(r[0], R.KINDS[r[0]], repr(r[1])[:70], r[3])
    print(w, stays(a))
