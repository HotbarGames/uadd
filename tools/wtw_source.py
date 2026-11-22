"""Reads the installed WhatTheWhisper for tools/make_wtw_text.py: its English (Core/Locale/enUS.lua), where its code
names each key, the texts drawn without its locale table (sound labels, labels missing from enUS), and the keys
its code saves or sends (STAY, lesson 14). Which keys are kept and how: tools/wtw_rules.py. Nothing here names
WhatTheWhisper's English (no licence: all rights reserved)."""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import luatok  # noqa: E402
import wtw_rules as R  # noqa: E402

ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
FOLDER = "WhatTheWhisper"
LOCALE = Path("Core") / "Locale" / "enUS.lua"
SOUNDS = Path("Modules") / "Sounds.lua"
PROFILE = Path("UI") / "ProfilePanel.lua"
FRIEND = Path("Modules") / "ConversationManager.lua"
QUICK = Path("Modules") / "QuickReplies.lua"
GROUP = Path("Modules") / "GroupChat.lua"
S, N, Y = luatok.STR, luatok.NAME, luatok.SYM


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / FOLDER


def version(addon):
    for name in ("WhatTheWhisper_Camelot.toc", "WhatTheWhisper_Vanilla.toc"):
        toc = Path(addon) / name
        if toc.is_file():
            m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M)
            if m:
                return m.group(1)
    return "?"


def _toks(path):
    return list(luatok.tokens(luatok.read(path)))


def sections(path):
    """[(first line, djb2 of the section comment)] of the `-- ...` lines inside enUS's table, in order."""
    out = []
    for n, line in enumerate(luatok.read(path).split("\n"), 1):
        m = re.match(r"^\s+--\s*(.*?)\s*$", line)
        if m and m.group(1):
            out.append((n, H.djb2(m.group(1))))
    return out


def read_enus(path):
    """[(English, line, section hash)] of each `["key"] = true` (or `= "text"`) of enUS's table."""
    t, out, secs = _toks(path), [], sections(path)
    for i in range(len(t) - 4):
        if t[i][:2] == (Y, "[") and t[i + 1][0] == S and t[i + 2][:2] == (Y, "]") and t[i + 3][:2] == (Y, "="):
            v = t[i + 4]
            if v[:2] == (N, "true") or v[0] == S:
                line = t[i + 1][2]
                sec = next((h for n, h in reversed(secs) if n < line), "")
                out.append((t[i + 1][1] if v[0] != S else v[1], line, sec))
    return out


def code_files(addon):
    return [p for p in sorted(Path(addon).rglob("*.lua"))
            if "Libs" not in p.parts and "Locale" not in p.parts]


def code_uses(addon):
    """{English: [(file, line)]} of every `L["..."]` in its code (also `ns.L[...]`)."""
    uses = {}
    for p in code_files(addon):
        t = _toks(p)
        for i in range(len(t) - 3):
            if t[i][:2] == (N, "L") and t[i + 1][:2] == (Y, "[") and t[i + 2][0] == S and t[i + 3][:2] == (Y, "]"):
                uses.setdefault(t[i + 2][1], []).append((p.name, t[i][2]))
    return uses


def _labels(path, start=None):
    """[(text, line)] of each `label = "..."` in a file (after the NAME `start`, up to its table's end)."""
    if not path.is_file():
        return []
    t, out, depth, on = _toks(path), [], 0, start is None
    for i in range(len(t) - 2):
        if not on and t[i][:2] == (N, start):
            on, depth = True, 0
            continue
        if on and start:
            if t[i][:2] == (Y, "{"):
                depth += 1
            elif t[i][:2] == (Y, "}"):
                depth -= 1
                if depth == 0:
                    break
        if on and t[i][:2] == (N, "label") and t[i + 1][:2] == (Y, "=") and t[i + 2][0] == S:
            out.append((t[i + 2][1], t[i + 2][2]))
    return out


def sound_labels(addon):
    """[(English, line)] of `Sounds.LIBRARY`'s labels (drawn as they are, not through L)."""
    return _labels(Path(addon) / SOUNDS, "LIBRARY")


def missing(addon, keys):
    """[(English, file, line)] drawn through L but missing from enUS: `L["..."]` in code, and the profile panel's
    row labels (it draws `L[label] or label`)."""
    out, seen = [], set()
    for en, places in code_uses(addon).items():
        if en not in keys and en not in seen:
            seen.add(en)
            out.append((en, places[0][0], places[0][1]))
    for en, line in _labels(Path(addon) / PROFILE, "FIELDS"):
        if en not in keys and en not in seen:
            seen.add(en)
            out.append((en, PROFILE.name, line))
    return out


def stay_texts(addon):
    """{English: reason} of locale keys its code saves or sends (lesson 14): the name it gives a friend with no
    BattleTag (saved into its history), and the quick-reply starters (saved once edited, sent as whispers)."""
    out = {}
    p = Path(addon) / FRIEND
    if p.is_file():
        for n, line in enumerate(luatok.read(p).split("\n"), 1):
            if "battleTag" in line:
                for m in re.finditer(r'L\["((?:[^"\\]|\\.)*)"\]', line):
                    out[m.group(1)] = R.STAY_FRIEND
    p = Path(addon) / QUICK
    if p.is_file():
        t, on = _toks(p), False
        for i in range(len(t) - 3):
            if t[i][:2] == (N, "Starters"):
                on = True
            elif on and t[i][:2] == (N, "end"):
                break
            elif on and t[i][:2] == (N, "L") and t[i + 1][:2] == (Y, "[") and t[i + 2][0] == S:
                out[t[i + 2][1]] = R.STAY_STARTER
    out.update({en: R.STAY_GROUP for en in group_labels(addon) if not elsewhere(addon, en)})
    return out


def group_labels(addon):
    """The texts of GroupChat.lua's LABELS: a group thread's name, saved into its history (and its export file)."""
    p = Path(addon) / GROUP
    if not p.is_file():
        return []
    t, out, depth = _toks(p), [], 0
    start = next((i for i in range(len(t) - 2) if t[i][:2] == (N, "LABELS") and t[i + 1][:2] == (Y, "=")), None)
    for i in range(start + 2 if start is not None else len(t), len(t) - 1):
        if t[i][:2] == (Y, "{"):
            depth += 1
        elif t[i][:2] == (Y, "}"):
            depth -= 1
            if depth <= 0:
                break
        elif t[i][:2] == (Y, "=") and t[i + 1][0] == S:
            out.append(t[i + 1][1])
    return out


def elsewhere(addon, en):
    """True when another code file has the text as a string too (it is drawn there: Swap.lua's ours, and the
    module's Groups.lua gives the thread its English)."""
    return any(p.name != GROUP.name and any(k == S and v == en for k, v, *_ in _toks(p)) for p in code_files(addon))


def source(addon):
    """(rows, why). rows: (key, English, batch, [(file, line)], note) in batch order; why: {reason: count} of
    the keys left out."""
    addon = Path(addon)
    loc = addon / LOCALE
    if not loc.is_file():
        return [], {}
    uses, rows, why, seen = code_uses(addon), [], {}, set()
    R.STAY_NOW.clear()
    R.STAY_NOW.update("L." + H.djb2(en) for en in stay_texts(addon))

    def add(key, en, batch, live, note):
        if key in seen:
            return
        seen.add(key)
        kept, reason = R.keep(key, en)
        if not kept:
            why[reason] = why.get(reason, 0) + 1
            return
        rows.append((key, en, batch, live, note))

    enus = read_enus(loc)
    for en, line, sec in enus:
        key = "L." + H.djb2(en)
        add(key, en, R.batch_of(key, sec), uses.get(en) or [("enUS.lua", line)], R.NOTES.get(key, ""))
    for en, line in sound_labels(addon):
        add("X." + H.djb2(en), en, 3, [("Sounds.lua", line)], R.SOUND_NOTE)
    for en, f, line in missing(addon, {e for e, *_ in enus}):
        add("X." + H.djb2(en), en, 3, [(f, line)], R.MISSING_NOTE)
    for n, en in enumerate(R.WEEKDAYS, 1):
        add(f"Day.{n}", en, 3, [("Format.lua", 0)], R.DAY_NOTE)
    order = [b[0] for b in R.BATCHES]
    rows.sort(key=lambda r: order.index(r[2]))
    return rows, why
