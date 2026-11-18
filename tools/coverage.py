"""How much of Questie's UI UADD_Questie/ui/strings.lua translates, and which entries would break.

python3 tools/coverage.py                       summary (keys from data/questie-keys.json)
python3 tools/coverage.py --questie PATH        read the keys from a Questie folder instead
python3 tools/coverage.py --list missing        also print keys with no translation (or: extra, bad, left)
python3 tools/coverage.py --strict              exit 1 when an entry is bad or not a Questie key

A "bad" entry would be skipped in the game (UADD_Questie/Locale.lua, L.Compatible): its %s/%d
list differs from the English key's, or its count of |c |r |T |t |H |h |n escapes differs.
Works before strings.lua exists (everything counts as missing). Standard library only.
"""
import argparse
import collections
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import extract_questie_keys as eqk  # noqa: E402
import glossary  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
STRINGS = REPO / "UADD_Questie" / "ui" / "strings.lua"
KEYS = REPO / "data" / "questie-keys.json"

SPEC = re.compile(r"%(%|[-+ #0]*\d*\.?\d*([A-Za-z])?)")
VALID = set("cdeEfgGioqsuxX")
ESCAPES = "crTtHhn"

# Keys only Questie's quest tracker uses (Questie 12.10). UALL Forever translates the tracker, and UADD
# draws it in English for it (UADD_Questie/Tracker.lua; docs/LESSONS.md, lesson 3). So these stay out
# of strings.lua: they are "left to UALL Forever", not missing.
LEFT_TO_UALLF = frozenset({
    "Questie Tracker", "Quest Complete!", "Quest Failed!", "Blizzard Timer Active!", "Time's up!",
    "Quests (By %% Complete)", "Quests (By %% Complete Reversed)", "Quests (By Level)",
    "Quests (By Level Reversed)", "Quests (By Proximity)", "Quests (By Proximity Reversed)",
    "Achievements", "Recipes", "Challenge Mode",
})


def specs(text):
    """The list of format conversions, as Questie's string.format sees them, or None if broken."""
    out = []
    for m in SPEC.finditer(text):
        if m.group(1) == "%":
            continue
        conv = m.group(2)
        if not conv or conv not in VALID:
            return None
        out.append(conv)
    return out


def escape_counts(text):
    return tuple(text.count("|" + e) for e in ESCAPES)


def compatible(key, uk):
    """Mirror of L.Compatible in UADD_Questie/Locale.lua."""
    if not isinstance(uk, str) or uk == "":
        return False
    a, b = specs(key), specs(uk)
    return a is not None and b is not None and a == b and escape_counts(key) == escape_counts(uk)


def read_strings(path, root=None):
    """{key: value} from strings.lua (`["key"] = "value"` and `["key"] = G"id"` lines), or {} when there is
    no file. G"id" links are read from the word base in root (default: this repo), as the game does."""
    return glossary.read_module_strings(path, glossary.Glossary(root or REPO))


def load_keys(args):
    if args.questie:
        return eqk.extract(args.questie)
    path = Path(args.keys)
    if not path.exists():
        sys.exit(f"coverage: no {path}. Run tools/extract_questie_keys.py --out {path}, or pass --questie PATH")
    return json.loads(path.read_text(encoding="utf-8"))


def report(keys, strings):
    """Numbers and lists. keys: {key: file}; strings: {key: ukrainian}."""
    covered = [k for k in keys if k in strings and compatible(k, strings[k])]
    bad = sorted(k for k in keys if k in strings and not compatible(k, strings[k]))
    missing = sorted(k for k in keys if k not in strings and k not in LEFT_TO_UALLF)
    left = sorted(k for k in keys if k in LEFT_TO_UALLF)
    extra = sorted(k for k in strings if k not in keys)
    by_area = collections.defaultdict(lambda: [0, 0])
    for k, f in keys.items():
        parts = f.split("/")
        area = parts[2] if len(parts) > 3 else Path(f).stem
        by_area[area][1] += 1
        if k in strings and compatible(k, strings[k]):
            by_area[area][0] += 1
    return {"total": len(keys), "covered": len(covered), "bad": bad, "missing": missing, "extra": extra, "left": left,
            "byArea": dict(sorted(by_area.items()))}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--strings", default=str(STRINGS))
    ap.add_argument("--keys", default=str(KEYS))
    ap.add_argument("--questie", help="read keys from this Questie folder instead of --keys")
    ap.add_argument("--list", choices=["missing", "extra", "bad", "left"], action="append", default=[])
    ap.add_argument("--json", action="store_true", help="print the whole report as JSON")
    ap.add_argument("--strict", action="store_true", help="exit 1 when there are bad or extra entries")
    args = ap.parse_args(argv)

    data = load_keys(args)
    strings = read_strings(args.strings)
    r = report(data["keys"], strings)
    if args.json:
        print(json.dumps(r, indent=1, ensure_ascii=False))
    else:
        pct = 100.0 * r["covered"] / r["total"] if r["total"] else 0.0
        where = args.strings if Path(args.strings).exists() else f"{args.strings} (not there yet)"
        print(f"Questie {data.get('questieVersion')}: {r['covered']} of {r['total']} keys translated ({pct:.1f}%)")
        print(f"  strings file: {where}, {len(strings)} entries")
        print(f"  missing {len(r['missing'])}, bad (skipped in game) {len(r['bad'])}, "
              f"not a Questie key {len(r['extra'])}, left to UALL Forever (tracker) {len(r['left'])}")
        for area, (done, total) in r["byArea"].items():
            print(f"    {area:<20} {done:>5} / {total}")
        for name in args.list:
            print(f"--- {name} ---")
            for k in r[name]:
                print(json.dumps(k, ensure_ascii=False) + ("  ->  " + json.dumps(strings[k], ensure_ascii=False)
                                                            if name == "bad" else ""))
    if args.strict and (r["bad"] or r["extra"]):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
