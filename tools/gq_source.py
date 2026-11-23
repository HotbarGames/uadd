"""Reads the installed GearQuest Forever for tools/make_gq_text.py: every key its code asks its locale table for
(L["..."], self.L["..."], GQ.L["..."]) with where, and the string literals of the DYNAMIC ranges (keys asked
through L[var]). Which keys are kept and how: tools/gq_rules.py. Nothing here names GearQuest's English (no
licence: all rights reserved)."""
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import luatok  # noqa: E402
import gq_rules as R  # noqa: E402

ADDON_DIRS = ["/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns",
              "/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"]
FOLDER = "GearQuestForever"
S, N, Y = luatok.STR, luatok.NAME, luatok.SYM


def addon_dir(arg=None):
    if arg:
        return Path(arg)
    base = os.environ.get("UADD_ADDONS_DIR") or next((d for d in ADDON_DIRS if os.path.isdir(d)), ADDON_DIRS[0])
    return Path(base) / FOLDER


def version(addon):
    toc = Path(addon) / (FOLDER + ".toc")
    if toc.is_file():
        m = re.search(r"^## Version:\s*(\S+)", toc.read_text(encoding="utf-8-sig", errors="replace"), re.M)
        if m:
            return m.group(1)
    return "?"


def code_files(addon):
    """Its own code, in load order where the TOC names it, then the rest; data folders left out."""
    addon = Path(addon)
    out = [p for p in sorted(addon.rglob("*.lua")) if not any(x in p.parts for x in R.SKIP_PARTS)]
    toc = addon / (FOLDER + ".toc")
    order = {}
    if toc.is_file():
        for i, line in enumerate(toc.read_text(encoding="utf-8-sig", errors="replace").splitlines()):
            line = line.strip().replace("\\", "/")
            if line and not line.startswith("#"):
                order[line] = i
    return sorted(out, key=lambda p: (order.get(p.relative_to(addon).as_posix(), 10 ** 6), p.as_posix()))


def code_uses(addon):
    """{English key: [(file, line)]} of every L["..."] in its code, in file order."""
    uses = {}
    for p in code_files(addon):
        t = list(luatok.tokens(luatok.read(p)))
        rel = p.relative_to(addon).as_posix()
        for i in range(len(t) - 3):
            if t[i][:2] == (N, "L") and t[i + 1][:2] == (Y, "[") and t[i + 2][0] == S and t[i + 3][:2] == (Y, "]"):
                uses.setdefault(t[i + 2][1], []).append((rel, t[i + 2][2]))
    return uses


def dynamic_uses(addon):
    """{English key: [(file, line)]} of the string literals inside each DYNAMIC range."""
    uses = {}
    for rel, first, last in R.DYNAMIC:
        p = Path(addon) / rel
        if not p.is_file():
            continue
        for kind, value, line in luatok.tokens(luatok.read(p)):
            if kind == S and first <= line <= last:
                uses.setdefault(value, []).append((rel, line))
    return uses


GUIDE = "PortraitGuide.lua"


def _local_value(t, name):
    """The string a `local NAME = "..."` sets, or None."""
    for i in range(len(t) - 3):
        if t[i][:2] == (N, "local") and t[i + 1][:2] == (N, name) and t[i + 2][:2] == (Y, "=") and t[i + 3][0] == S:
            return t[i + 3][1]
    return None


def _wrap_parts(t, name):
    """(head, tail) of `local function NAME(x) return "head" .. x .. "tail" end`, or None."""
    for i in range(len(t) - 13):
        if t[i][:2] == (N, "function") and t[i + 1][:2] == (N, name) and t[i - 1][:2] == (N, "local"):
            b = t[i + 2:i + 14]
            arg = b[1][1]
            want = [(Y, "("), (N, arg), (Y, ")"), (N, "return"), S, (Y, "."), (Y, "."), (N, arg), (Y, "."), (Y, "."),
                    S, (N, "end")]
            if all((w == x[0]) if isinstance(w, str) else (w == x[:2]) for w, x in zip(want, b)):
                return b[4][1], b[10][1]
    return None


def _expr(t, i, names, wrap):
    """(the string a concat of literals, names and wrap(...) calls gives, the index after it), or (None, i)."""
    out = []
    while True:
        if i < len(t) and t[i][0] == S:
            out.append(t[i][1])
            i += 1
        elif i < len(t) and t[i][0] == N and t[i][1] in names:
            out.append(names[t[i][1]])
            i += 1
        elif (wrap and i + 1 < len(t) and t[i][:2] == (N, wrap[0]) and t[i + 1][:2] == (Y, "(")):
            inner, j = _expr(t, i + 2, names, wrap)
            if inner is None or j >= len(t) or t[j][:2] != (Y, ")"):
                return None, i
            out.append(wrap[1] + inner + wrap[2])
            i = j + 1
        else:
            return None, i
        if i + 1 < len(t) and t[i][:2] == (Y, ".") and t[i + 1][:2] == (Y, "."):
            i += 2
            continue
        return "".join(out), i


def guide_pages(addon):
    """[(page text as it draws it, (file, line))] of its guide's pages (each `text = ...` of its PAGES list),
    and the count of pages it could not read."""
    p = Path(addon) / GUIDE
    if not p.is_file():
        return [], 0
    t = list(luatok.tokens(luatok.read(p)))
    icon = _local_value(t, "INFO_ICON")
    bold = _wrap_parts(t, "Bold")
    names = {"INFO_ICON": icon} if icon is not None else {}
    wrap = ("Bold",) + bold if bold else None
    start = next((i for i in range(len(t) - 3) if t[i][:2] == (N, "local") and t[i + 1][:2] == (N, "PAGES")
                  and t[i + 2][:2] == (Y, "=") and t[i + 3][:2] == (Y, "{")), None)
    if start is None:
        return [], 0
    out, bad, depth, i = [], 0, 0, start + 3
    while i < len(t):
        k, v = t[i][:2]
        if (k, v) == (Y, "{"):
            depth += 1
        elif (k, v) == (Y, "}"):
            depth -= 1
            if depth == 0:
                break
        elif depth == 2 and (k, v) == (N, "text") and t[i + 1][:2] == (Y, "="):
            text, j = _expr(t, i + 2, names, wrap)
            if text is None or t[j][:2] not in ((Y, ","), (Y, "}")):
                bad += 1
            else:
                out.append((text, (GUIDE, t[i][2])))
                i = j
                continue
        i += 1
    return out, bad


def x_rows(addon):
    """Rows of the whole texts drawn without its locale table (keyed X.<hash>), batch "3b": its guide's pages.
    (rows, {reason: count})."""
    pages, bad = guide_pages(addon)
    rows, seen = [], set()
    for en, where in pages:
        key = "X." + H.djb2(en)
        if key not in seen:
            seen.add(key)
            rows.append((key, en, "3b", [where], "guide page"))
    return rows, ({"guide page not read": bad} if bad else {})


def source(addon):
    """(rows, {reason: count}). A row: (key, English, batch, [(file, line)], note); batches of R.SIZE rows in
    the order its code names them."""
    if not (Path(addon) / (FOLDER + ".toc")).is_file():
        return [], {}
    uses = code_uses(addon)
    for en, where in dynamic_uses(addon).items():
        uses.setdefault(en, []).extend(where)
    rows, why = [], {}
    for en, where in uses.items():
        key = "L." + H.djb2(en)
        ok, reason = R.keep(key, en)
        if not ok:
            why[reason] = why.get(reason, 0) + 1
            continue
        rows.append([key, en, 0, where, R.NOTES.get(key, "")])
    for i, r in enumerate(rows):
        r[2] = i // R.SIZE + 1
    return [tuple(r) for r in rows], why
