"""Reads the installed GatherMate2 for tools/make_gm_text.py: its English (the GatherMate2 table of
Locales/GatherMate2-enUS.lua only, never the node tables), where its code names each key, the sub-panel
labels its Config.lua writes, and the English of the two Ace3 parts the module translates (AceDBOptions'
Profiles tab, AceGUI's key binding hint). Which keys are kept and how: tools/gm_rules.py. Nothing here names
GatherMate2's English (its TOC says ARR: we treat it as all rights reserved)."""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gm_rules as R  # noqa: E402
import hashtext as H  # noqa: E402
import luatok  # noqa: E402

ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
LOCALE = Path("Locales") / "GatherMate2-enUS.lua"
CODE = ("GatherMate2.lua", "Collector.lua", "Display.lua", "Constants.lua", "Config.lua")
DBO = Path("Libs") / "AceDBOptions-3.0" / "AceDBOptions-3.0.lua"
KEYBIND = Path("Libs") / "AceGUI-3.0" / "widgets" / "AceGUIWidget-Keybinding.lua"
DBO_SKIP = {"default": "the default profile's name (lesson 13: profile names are never changed)"}
S, N, Y = luatok.STR, luatok.NAME, luatok.SYM


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "GatherMate2"


def version(addon):
    toc = Path(addon) / "GatherMate2.toc"
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return m.group(1) if m else "?"


def _toks(path):
    return list(luatok.tokens(luatok.read(path)))


def read_locale(path):
    """[(key, English, line)] of `L["key"] = true | "..."` up to the next NewLocale (the node tables)."""
    t, out, seen_new = _toks(path), [], 0
    for i in range(len(t) - 5):
        if t[i][:2] == (N, "NewLocale"):
            seen_new += 1
            if seen_new > 1:
                break
        if t[i][:2] == (N, "L") and t[i + 1][:2] == (Y, "[") and t[i + 2][0] == S \
                and t[i + 3][:2] == (Y, "]") and t[i + 4][:2] == (Y, "="):
            key, v = t[i + 2][1], t[i + 5]
            if v[:2] == (N, "true"):
                out.append((key, key, t[i][2]))
            elif v[0] == S:
                out.append((key, v[1], t[i][2]))
    return out


def code_uses(addon):
    """{locale key: [(file, line)]} of every `L["key"]` in GatherMate2's code (comments are not tokens)."""
    uses = {}
    for name in CODE:
        p = Path(addon) / name
        if not p.is_file():
            continue
        t = _toks(p)
        for i in range(len(t) - 3):
            if t[i][:2] == (N, "L") and t[i + 1][:2] == (Y, "[") and t[i + 2][0] == S and t[i + 3][:2] == (Y, "]"):
                uses.setdefault(t[i + 2][1], []).append((name, t[i][2]))
    return uses


def panels(addon):
    """[(app suffix, label, line)] of `AddToBlizOptions("GM2/<app>", "<label>", ...)` in Config.lua."""
    p, out = Path(addon) / "Config.lua", []
    if not p.is_file():
        return out
    t = _toks(p)
    for i in range(len(t) - 5):
        if t[i][:2] == (N, "AddToBlizOptions") and t[i + 1][:2] == (Y, "(") and t[i + 2][0] == S \
                and t[i + 3][:2] == (Y, ",") and t[i + 4][0] == S and t[i + 2][1].startswith("GM2/"):
            out.append((t[i + 2][1][4:], t[i + 4][1], t[i][2]))
    return out


def dbo_texts(addon):
    """[(key, English, line)] of the first `local L = { key = "..." }` of AceDBOptions-3.0 (its English)."""
    p = Path(addon) / DBO
    if not p.is_file():
        return []
    t, out = _toks(p), []
    start = next((i + 4 for i in range(len(t) - 3) if t[i][:2] == (N, "local") and t[i + 1][:2] == (N, "L")
                  and t[i + 2][:2] == (Y, "=") and t[i + 3][:2] == (Y, "{")), None)
    i = start
    while i is not None and i + 2 < len(t) and t[i][:2] != (Y, "}"):
        if t[i][0] == N and t[i + 1][:2] == (Y, "=") and t[i + 2][0] == S:
            out.append((t[i][1], t[i + 2][1], t[i][2]))
            i += 3
        else:
            i += 1
    return out


def keybind_hint(addon):
    """(English, line) of the first literal `msg:SetText("...")` of AceGUI's Keybinding widget, or (None, 0)."""
    p = Path(addon) / KEYBIND
    if not p.is_file():
        return None, 0
    t = _toks(p)
    for i in range(len(t) - 4):
        if t[i][:2] == (N, "msg") and t[i + 1][:2] == (Y, ":") and t[i + 2][:2] == (N, "SetText") \
                and t[i + 4][0] == S:
            return t[i + 4][1], t[i + 4][2]
    return None, 0


def source(addon):
    """(rows, libs, why). rows: (key, English, batch, [(file, line)], note) in batch order; libs: {row key:
    hash of its English} for the rows the module compares at run time (panel labels, Ace3 texts); why:
    {reason: count} of the keys left out."""
    addon = Path(addon)
    loc = addon / LOCALE
    if not loc.is_file():
        return [], {}, {}
    uses, rows, why, libs = code_uses(addon), [], {}, {}

    def add(key, en, live):
        kept, reason = R.keep(key, en)
        if not kept:
            why[reason] = why.get(reason, 0) + 1
            return
        rows.append((key, en, R.batch_of(key, live), live, R.NOTES.get(key, "")))

    for lk, en, line in read_locale(loc):
        live = uses.get(lk, [])
        if not live:
            why["not named in its code"] = why.get("not named in its code", 0) + 1
            continue
        add("L." + H.djb2(lk), en, live)
    for app, label, line in panels(addon):
        add("Panel." + app, label, [("Config.lua", line)])
        libs["Panel." + app] = H.djb2(label)
    for k, en, line in dbo_texts(addon):
        if k in DBO_SKIP:
            why["a profile name"] = why.get("a profile name", 0) + 1
            continue
        add("AceDBO." + k, en, [(DBO.name, line)])
        libs["AceDBO." + k] = H.djb2(en)
    en, line = keybind_hint(addon)
    if en:
        add("AceGUI.keybinding_hint", en, [(KEYBIND.name, line)])
        libs["AceGUI.keybinding_hint"] = H.djb2(en)
    order = [b[0] for b in R.BATCHES]
    rows.sort(key=lambda r: order.index(r[2]))
    return rows, libs, why
