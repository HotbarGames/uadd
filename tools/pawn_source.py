"""Reads the installed Pawn for tools/make_pawn_text.py: its English (Localization.lua, the enUS table only),
the UI globals UIStrings.lua fills from it, the names PawnUI.xml shows, and where its code names each key.
Which keys are kept and how: tools/pawn_rules.py. Nothing here names Pawn's English (CC BY-NC-ND 3.0: we
treat it as all rights reserved)."""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import luatok  # noqa: E402
import pawn_rules as R  # noqa: E402

ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
GLOBAL = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*L\.([A-Za-z0-9_]+)\s*(?:--.*)?$")
LISTS = ("PawnUITabLabels", "PawnUIHeaders")
XML_TEXT = re.compile(r'\btext="([A-Za-z_][A-Za-z0-9_]*)"')


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / "Pawn"


def version(addon):
    toc = Path(addon) / "Pawn.toc"
    m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M) \
        if toc.is_file() else None
    return m.group(1) if m else "?"


def _value(t, i):
    """(string or None, next index) of the value that starts at t[i]: "..." (.. "...")*, else None."""
    if t[i][0] != luatok.STR:
        return None, i
    val, j = t[i][1], i + 1
    while j + 1 < len(t) and t[j][:2] == (luatok.SYM, "..") and t[j + 1][0] == luatok.STR:
        val, j = val + t[j + 1][1], j + 2
    return val, j


def read_locale(path):
    """{"Key" / "Stats.Key" / "UI.Key": English} of the first `PawnLocal = { ... }` (the enUS table), in order,
    and {path: line}. Values that are not plain strings (sub-tables other than one level, numbers) are skipped."""
    t = list(luatok.tokens(luatok.read(path)))
    start = next((i + 3 for i in range(len(t) - 2) if t[i][:2] == (luatok.NAME, "PawnLocal")
                  and t[i + 1][:2] == (luatok.SYM, "=") and t[i + 2][:2] == (luatok.SYM, "{")), None)
    out, lines = {}, {}
    if start is None:
        return out, lines
    stack, depth, i = [], 1, start
    while i < len(t) and depth > 0:
        kind, v, ln = t[i]
        key = None
        if (kind, v) == (luatok.SYM, "[") and i + 3 < len(t) and t[i + 1][0] == luatok.STR \
                and t[i + 2][:2] == (luatok.SYM, "]") and t[i + 3][:2] == (luatok.SYM, "="):
            key, i = t[i + 1][1], i + 4
        elif kind == luatok.NAME and i + 1 < len(t) and t[i + 1][:2] == (luatok.SYM, "=") \
                and t[i - 1][:2] in ((luatok.SYM, "{"), (luatok.SYM, ","), (luatok.SYM, ";")):
            key, i = v, i + 2
        if key is not None:
            if t[i][:2] == (luatok.SYM, "{"):
                stack.append(key)
                depth += 1
                i += 1
                continue
            val, i = _value(t, i)
            if val is not None and len(stack) <= 1 and None not in stack:
                path_ = ".".join(stack + [key])
                out[path_], lines[path_] = val, t[i - 1][2]
            continue
        if (kind, v) == (luatok.SYM, "{"):
            depth += 1
            stack.append(None)
        elif (kind, v) == (luatok.SYM, "}"):
            depth -= 1
            if stack:
                stack.pop()
        i += 1
    return out, lines


def read_names(path):
    """(globals {NAME: "UI.Key" / "Stats.Key"}, lists {list name: [paths]}, stat keys [paths], {path: line})
    from UIStrings.lua: only lines `NAME = L.Key`, the two label lists and the L.* names in the stat rows."""
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    glob, lists, stats, where, part, cur = {}, {}, [], {}, None, None
    for n, line in enumerate(text.split("\n"), 1):
        m = re.match(r"^L\s*=\s*PawnLocal\.(\w+)", line)
        if m:
            part = m.group(1)
            continue
        m = re.match(r"^(\w+)\s*=", line)
        if m and m.group(1) in LISTS:
            cur = m.group(1)
            lists[cur] = []
        m = GLOBAL.match(line)
        if m and part:
            glob[m.group(1)] = f"{part}.{m.group(2)}"
            where.setdefault(glob[m.group(1)], n)
            continue
        for k in re.findall(r"\bL\.([A-Za-z0-9_]+)", line.split("--")[0]):
            p = f"{part}.{k}"
            if cur:
                lists[cur].append(p)
            elif part == "Stats" and p not in stats:
                stats.append(p)
            where.setdefault(p, n)
        if cur and line.startswith("}"):
            cur = None
    return glob, lists, stats, where


def xml_names(path):
    """{global name: line} of every text="NAME" in PawnUI.xml."""
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    return {m.group(1): text.count("\n", 0, m.start()) + 1 for m in XML_TEXT.finditer(text)}


def code_uses(addon, leaves):
    """{leaf name: [(file, line)]} of `.Leaf` in Pawn's Lua (Localization*.lua and UIStrings.lua left out)."""
    uses = {}
    for p in sorted(Path(addon).glob("*.lua")):
        if p.name.startswith("Localization") or p.name == "UIStrings.lua":
            continue
        t = list(luatok.tokens(luatok.read(p)))
        for i in range(1, len(t)):
            if t[i][0] == luatok.NAME and t[i][1] in leaves and t[i - 1][:2] == (luatok.SYM, "."):
                uses.setdefault(t[i][1], []).append((p.name, t[i][2]))
    return uses


def credits_line(addon):
    """(English, line) of the last literal `PawnUIFrame_MrRobotLabel:SetText("...")` in PawnUI.lua: the one a
    Classic client shows (PawnUI_EnsureLoaded's last branch), or (None, 0)."""
    p = Path(addon) / "PawnUI.lua"
    if not p.is_file():
        return None, 0
    t, found = list(luatok.tokens(luatok.read(p))), (None, 0)
    for i in range(len(t) - 4):
        if t[i][:2] == (luatok.NAME, "PawnUIFrame_MrRobotLabel") and t[i + 2][:2] == (luatok.NAME, "SetText") \
                and t[i + 4][0] == luatok.STR:
            found = (t[i + 4][1], t[i + 4][2])
    return found


def source(addon):
    """(rows, names, why). rows: (key, English, batch, [(file, line)], note) in batch order; names: what the
    module needs to find Pawn's globals (identifiers only); why: {reason: count} of the keys left out."""
    addon = Path(addon)
    loc = addon / "Localization.lua"
    if not loc.is_file():
        return [], {}, {}
    texts, lines = read_locale(loc)
    glob, lists, stat_keys, ui_where = read_names(addon / "UIStrings.lua")
    xml = xml_names(addon / "PawnUI.xml")
    leaves = {k.split(".")[-1] for k in texts}
    uses = code_uses(addon, leaves)
    by_path = {}
    for name, path in glob.items():
        by_path.setdefault(path, []).append(name)
    rows, why = [], {}
    for key, en in texts.items():
        keep, reason = R.keep(key, en)
        if not keep:
            why[reason] = why.get(reason, 0) + 1
            continue
        live = []
        if key in ui_where:
            live.append(("UIStrings.lua", ui_where[key]))
        for name in by_path.get(key, []):
            if name in xml:
                live.append(("PawnUI.xml", xml[name]))
        live += uses.get(key.split(".")[-1], [])
        note = R.NOTES.get(key, "")
        if not live and key not in R.DISPLAY_ONLY:
            why["not named in its code"] = why.get("not named in its code", 0) + 1
            continue
        rows.append((key, en, R.batch_of(key), live or [("Localization.lua", lines.get(key, 0))], note))
    en, ln = credits_line(addon)
    if en:
        rows.append(("Code." + H.djb2(en), en, R.batch_of("Code."), [("PawnUI.lua", ln)], R.CREDITS_NOTE))
    order = [b[0] for b in R.BATCHES]
    rows.sort(key=lambda r: order.index(r[2]))
    names = {"globals": {n: p for n, p in glob.items() if p in texts},
             "xml": sorted(n for n in xml if n in glob), "lists": lists, "stats": [k for k in stat_keys if k in texts]}
    return rows, names, why
