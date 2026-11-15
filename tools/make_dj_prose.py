#!/usr/bin/env python3
"""Make the English source files for the Dungeon Journal long texts.

Reads Forever Dungeon Journal's real data files (read only) and writes
tools/dj_prose/en_<n>.lua, one file per batch, for translators.

Each entry is one unique English text:
  key    8-hex djb2 hash of the English (UTF-8 bytes); the runtime finds it the same way
  kind   objective | note | warning | description (or several, joined by ",")
  shown  false when FDJ never shows this text (boss and dungeon descriptions)
  where  dungeon / boss / quest where it is used (first few places)
  en     the English exactly as FDJ has it
  src    the English with names swapped for {npc:..} {item:..} {zone:..} {quest:..}
         placeholders (only when there is at least one); translate this one
  names  placeholder -> id from FDJ data (npc / item / quest), for reference

A name becomes a placeholder only when UALL Forever has it: NPC, item and
zone names are checked against the English keys of UALLF's NpcNames.lua,
Items.lua and World.lua, and quests against the ids in Quests.lua. Nothing
from UALLF is copied; Ukrainian names are filled in at runtime.

Translators write uk_<n>.lua next to en_<n>.lua:  return { ["key"] = "...", }
See docs/scratch-dj-prose.md.

Usage: python3 tools/make_dj_prose.py [--batches 6]
Needs: lupa (Lua 5.1), as the test harness does.
"""
import argparse
import sys
from collections import OrderedDict
from pathlib import Path

from dj_prose_fdj import collect, load_fdj
from dj_prose_names import Names
from dj_prose_src import make_src
from hashtext import djb2  # the key: the same hash as UADD/Hash.lua

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "tools" / "dj_prose"


def partition(sizes, k):
    """Split a list of sizes into k runs of whole items, minimising the largest run."""
    n = len(sizes)
    k = max(1, min(k, n))
    pre = [0]
    for s in sizes:
        pre.append(pre[-1] + s)
    INF = float("inf")
    best = [[INF] * (k + 1) for _ in range(n + 1)]
    cut = [[0] * (k + 1) for _ in range(n + 1)]
    best[0][0] = 0
    for i in range(1, n + 1):
        for j in range(1, k + 1):
            for p in range(j - 1, i):
                v = max(best[p][j - 1], pre[i] - pre[p])
                if v < best[i][j]:
                    best[i][j], cut[i][j] = v, p
    runs, i = [], n
    for j in range(k, 0, -1):
        p = cut[i][j]
        runs.append((p, i))
        i = p
    return list(reversed(runs))


def lua_str(s):
    s = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r")
    return '"' + s + '"'


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--batches", type=int, default=6)
    args = ap.parse_args()

    data = load_fdj()
    names = Names()
    rows, groups = collect(data, names)
    names.add_uallf_extras()
    names.index()

    entries = OrderedDict()   # en -> entry
    for g, kind, where, en, shown in rows:
        e = entries.get(en)
        if e is None:
            e = entries[en] = {"group": g, "kinds": [], "where": [], "en": en, "shown": False}
        if kind not in e["kinds"]:
            e["kinds"].append(kind)
        e["where"].append(where)
        e["shown"] = e["shown"] or shown

    keys, braces, used_missing = {}, [], {}
    for en, e in entries.items():
        k = djb2(en)
        if k in keys:
            sys.exit("hash collision: %s\n  %r\n  %r" % (k, keys[k], en))
        keys[k] = en
        e["key"] = k
        if "{" in en or "}" in en:
            braces.append(k)
        e["src"], e["names"], e["counts"] = make_src(en, names)
        for miss, kind in names.missing.items():
            if len(miss) > 3 and miss in en and miss not in names.known:
                used_missing.setdefault(kind, set()).add(miss)

    # Batches: whole groups in FDJ order, split near equal counts.
    by_group = OrderedDict((g, []) for g in groups)
    for e in entries.values():
        by_group.setdefault(e["group"], []).append(e)
    total = len(entries)
    filled = [g for g, lst in by_group.items() if lst]
    batches = [filled[a:b] for a, b in partition([len(by_group[g]) for g in filled], args.batches)]

    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("en_*.lua"):
        old.unlink()
    print("entries: %d unique (from %d uses)" % (total, len(rows)))
    kinds = {}
    for e in entries.values():
        for k in e["kinds"]:
            kinds[k] = kinds.get(k, 0) + 1
    print("by kind:", ", ".join("%s %d" % kv for kv in sorted(kinds.items())))
    print("not shown by FDJ:", sum(1 for e in entries.values() if not e["shown"]))
    print("with placeholders:", sum(1 for e in entries.values() if e["names"]))
    print("number + name (flagged as counts):", sum(1 for e in entries.values() if e["counts"]))
    for i, gs in enumerate(batches, 1):
        lst = [e for g in gs for e in by_group[g]]
        lines = ["-- en_%d.lua: made by tools/make_dj_prose.py from Forever Dungeon Journal. Do not edit." % i,
                 "-- Translate `src` (or `en` when there is no src) into uk_%d.lua with the same keys." % i,
                 "-- Groups: " + "; ".join(gs),
                 "return {"]
        for e in lst:
            parts = ["key = %s" % lua_str(e["key"]), "kind = %s" % lua_str(",".join(e["kinds"]))]
            if not e["shown"]:
                parts.append("shown = false")
            lines.append("  { " + ", ".join(parts) + ",")
            lines.append("    where = { " + ", ".join(lua_str(w) for w in e["where"][:4]) +
                         (" --[[ +%d more ]]" % (len(e["where"]) - 4) if len(e["where"]) > 4 else "") + " },")
            lines.append("    en = %s," % lua_str(e["en"]))
            if e["names"]:
                lines.append("    src = %s," % lua_str(e["src"]))
                lines.append("    names = { " + ", ".join(
                    "[%s] = %s" % (lua_str(p), "nil" if v is None else str(v)) for p, v in e["names"].items()) + " },")
            if e["counts"]:
                # Number + name: the name can't take the plural, so write «{item:X}»: 10 шт. (creatures: «{npc:X}»: 10).
                lines.append("    counts = { " + ", ".join(lua_str(c) for c in e["counts"]) + " },")
            lines.append("  },")
        lines.append("}")
        (OUT / ("en_%d.lua" % i)).write_text("\n".join(lines) + "\n", "utf-8")
        shown = sum(1 for e in lst if e["shown"])
        print("en_%d.lua: %d entries (%d shown) - %s" % (i, len(lst), shown, ", ".join(gs)))
    if braces:
        print("WARNING: English with { or }:", ", ".join(braces))
    for kind, ns in sorted(used_missing.items()):
        print("FDJ %s names in texts that UALLF lacks (%d): %s" % (kind, len(ns), "; ".join(sorted(ns)[:12])))


if __name__ == "__main__":
    main()
