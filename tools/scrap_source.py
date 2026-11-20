"""Reads the installed Scrap for tools/make_scrap_text.py: its English (localization/en.lua only), where its
code names each key, and the texts its settings code writes itself (a page name, buttons). Which keys are
kept and how: tools/scrap_rules.py. Nothing here names Scrap's English (its TOCs say All Rights Reserved)."""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import luatok  # noqa: E402
import scrap_rules as R  # noqa: E402

ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
LOCALE = Path("localization") / "en.lua"
CODE = ("addons/main/main.lua", "addons/main/pricing.lua", "addons/main/spotlight.lua",
        "addons/merchant/button.lua", "addons/merchant/learning.lua", "addons/merchant/visualizer.lua",
        "addons/config/options.lua", "addons/config/tutorials.lua")
OPTIONS = "addons/config/options.lua"
S, N, Y = luatok.STR, luatok.NAME, luatok.SYM


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "Scrap"


def version(addon):
    toc = Path(addon) / "Scrap.toc"
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return m.group(1) if m else "?"


def _toks(path):
    return list(luatok.tokens(luatok.read(path)))


def read_locale(path):
    """[(row key, English, line)] of `L.Key = '...'` and of each string of `L.FAQ = { ... }`."""
    t, out = _toks(path), []
    for i in range(len(t) - 4):
        if t[i][:2] != (N, "L") or t[i + 1][:2] != (Y, ".") or t[i + 2][0] != N or t[i + 3][:2] != (Y, "="):
            continue
        key, v = t[i + 2][1], t[i + 4]
        if v[0] == S:
            out.append(("L." + key, v[1], t[i][2]))
        elif v[:2] == (Y, "{"):
            j, n = i + 5, 0
            while j < len(t) and t[j][:2] != (Y, "}"):
                if t[j][0] == S:
                    n += 1
                    out.append((f"{key}.{n}", t[j][1], t[j][2]))
                j += 1
    return out


def code_uses(addon):
    """{locale key: [(file, line)]} of every `L.Key` or `L['Key']` in Scrap's code."""
    uses = {}
    for name in CODE:
        p = Path(addon) / name
        if not p.is_file():
            continue
        t = _toks(p)
        for i in range(len(t) - 3):
            if t[i][:2] != (N, "L"):
                continue
            if t[i + 1][:2] == (Y, ".") and t[i + 2][0] == N:
                uses.setdefault(t[i + 2][1], []).append((Path(name).name, t[i][2]))
            elif t[i + 1][:2] == (Y, "[") and t[i + 2][0] == S and t[i + 3][:2] == (Y, "]"):
                uses.setdefault(t[i + 2][1], []).append((Path(name).name, t[i][2]))
    return uses


def code_texts(addon):
    """[(English, line)] its settings code writes itself: a `'RedButton', '...'` and the first string of an
    `OptionsGroup(parent, '...' ..)` (a page name). Names of the game's globals are not strings: skipped."""
    p, out = Path(addon) / OPTIONS, []
    if not p.is_file():
        return out
    t = _toks(p)
    for i in range(len(t) - 2):
        if t[i][0] == S and t[i][1] == "RedButton" and t[i + 1][:2] == (Y, ",") and t[i + 2][0] == S:
            out.append((t[i + 2][1], t[i + 2][2]))
        if t[i][:2] == (N, "OptionsGroup") and t[i + 1][:2] == (Y, "("):
            for j in range(i + 2, min(i + 8, len(t) - 1)):
                if t[j][:2] == (Y, ","):
                    if t[j + 1][0] == S:
                        out.append((t[j + 1][1], t[j + 1][2]))
                    break
    return out


def source(addon):
    """(rows, why). rows: (key, English, batch, [(file, line)], note) in batch order; why: {reason: count} of
    the keys left out."""
    addon = Path(addon)
    loc = addon / LOCALE
    if not loc.is_file():
        return [], {}
    uses, rows, why = code_uses(addon), [], {}

    def add(key, en, batch, live, note):
        kept, reason = R.keep(key, en)
        if not kept:
            why[reason] = why.get(reason, 0) + 1
            return
        rows.append((key, en, batch, live, note))

    for key, en, line in read_locale(loc):
        name = key.split(".")[1] if key.startswith("L.") else key.split(".")[0]
        live = uses.get(name) or [("options.lua", 0)]   # the settings name most keys by a built string
        add(key, en, R.batch_of(key, line), live, R.NOTES.get(key, ""))
    for en, line in code_texts(addon):
        add("Code." + H.djb2(en), en, R.batch_of("Code.", 0), [("options.lua", line)], R.CODE_NOTE)
    order = [b[0] for b in R.BATCHES]
    rows.sort(key=lambda r: order.index(r[2]))
    return rows, why
