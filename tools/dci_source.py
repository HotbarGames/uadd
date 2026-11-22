"""Reads the installed DeleteCheapestItem Reloaded for tools/make_dci_text.py: every text it shows through its
locale table L. Which texts are kept and how: tools/dci_rules.py. Nothing here names its English (all rights
reserved, TOC X-License).

Its L is private (`local L = DCI.L`) and keyed by the English itself, so every text is keyed Code.<hash>:
UADD.Hash of the L key as Lua reads it (escapes decoded), as UADD_LootTriage does. A text the code glues to a
value (`L["x"] .. name`, `L["x"] .. " " .. name`) also gets a join row ("x%s" or "x %s") when dci_rules.JOINS
names it: the template the module fills on screen and in chat.

  python3 tools/dci_source.py all [DIR]   print every row (key, batch, file:line, note) and each join candidate
"""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import luatok  # noqa: E402
import dci_rules as R  # noqa: E402

ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
FOLDER = "DeleteCheapestItem"
TOC = "DeleteCheapestItem.toc"
FILES = ["DeleteCheapestItem.lua", "Profiles.lua", "ProfileUI.lua", "Broker.lua"]
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


def key_of(en):
    return "Code." + H.djb2(en)


def lookups(path):
    """[(English, line, join)] of every L["..."] of one file. join: "" when the key is not glued to a name,
    "%s" for L[x] .. name, " %s" for L[x] .. " " .. name."""
    t = list(luatok.tokens(luatok.read(path)))
    at = lambda j: t[j][:2] if 0 <= j < len(t) else (None, None)  # noqa: E731
    out = []
    for i, (kind, value, line) in enumerate(t):
        if not (kind == S and at(i - 1) == (Y, "[") and at(i - 2) == (N, "L") and at(i + 1) == (Y, "]")):
            continue
        join = ""
        dots = lambda j: at(j) == (Y, ".") and at(j + 1) == (Y, ".")  # noqa: E731  (luatok gives .. as two .)
        if dots(i + 2):
            nxt = at(i + 4)
            if nxt[0] == N or nxt == (Y, "("):
                join = "%s"
            elif nxt == (S, " ") and dots(i + 5) and (at(i + 7)[0] == N or at(i + 7) == (Y, "(")):
                join = " %s"
        out.append((value, line, join))
    return out


def source(addon):
    """(rows, why). rows: (key, English, batch, [(file, line)], note) in batch order; why: {reason: count}."""
    addon = Path(addon)
    if not (addon / TOC).is_file():
        return [], {}
    found, why = {}, {}

    def add(en, f, line):
        key = key_of(en)
        kept, reason = R.keep(key, en)
        if not kept:
            why[reason] = why.get(reason, 0) + 1
            return
        if key in found:
            found[key][3].append((f, line))
        else:
            found[key] = [key, en, R.batch_of(f), [(f, line)], R.note(key, f)]

    for f in FILES:
        if not (addon / f).is_file():
            continue
        for en, line, join in lookups(addon / f):
            add(en, f, line)
            if join and key_of(en) in R.JOINS and R.JOINS[key_of(en)] == join:
                add(en.replace("%", "%%") + join, f, line)
    rows = sorted((tuple(r) for r in found.values()), key=lambda r: (r[2], r[3][0]))
    return R.split(rows), why


def main(argv):
    addon = addon_dir(argv[2] if len(argv) > 2 else None)
    if len(argv) < 2 or argv[1] != "all":
        print(__doc__)
        return 2
    for f in FILES:
        if (addon / f).is_file():
            for en, line, join in lookups(addon / f):
                print(f"{key_of(en)}\t{f}:{line}\tjoin={join!r}\t{en!r}")
    rows, why = source(addon)
    print(f"{len(rows)} rows; left out: {why}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
