"""Makes UADD_WowheadQuickLink's Ukrainian from review files, keyed by a hash of Wowhead Quick Link's English.

  python3 tools/make_wql_text.py review [WQL_DIR]   write local/wql/review_NN.txt (keeps every UA by key)
  python3 tools/make_wql_text.py build  [WQL_DIR]   write UADD_WowheadQuickLink/data/text01.lua
  python3 tools/make_wql_text.py stats  [WQL_DIR]   count done / left / refused

Wowhead Quick Link's English is read from the installed addon (or WQL_DIR, or $UADD_ADDONS_DIR/WowheadQuickLink)
and goes only into local/wql/ (git-ignored): it has no licence file, so all rights are reserved. The data keeps only
hashes and our Ukrainian. Texts: tools/wql_source.py; rules: tools/wql_rules.py; machinery: tools/key_text.py.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import key_text as K  # noqa: E402
import wql_rules as R  # noqa: E402
from wql_source import addon_dir, source, version  # noqa: E402

NAME = "Wowhead Quick Link"
TOOL = "tools/make_wql_text.py"
LOCAL = ROOT / "local" / "wql"
DATA = ROOT / "UADD_WowheadQuickLink" / "data"
FILES = 1
BATCHES = R.BATCHES
HELP = """\
# Keys: Pop.<hash> the popup's text (%s: its header), Head.<hash> the header's words (%s: the link type),
#   Type.<hash> a link type, Code.<hash> a button, a key binding name or a label. <hash> is UADD.Hash of the English.
# The names "Wowhead", "Wowhead Quick Link", "Raider.IO", "URL" and the keys "CTRL-C" stay as they are.
# A link type in small letters. Close: G"ui.close". Informal "ти", short.
"""
DATA_HEAD = [
    "-- Made by tools/make_wql_text.py build from Wowhead Quick Link {ver}. Do not edit: change the review files",
    "-- (local/wql/review_NN.txt) and build again. Only hashes and our Ukrainian.",
    "-- T: <kind>.<hash> (UADD.Hash of the English) = Ukrainian. S: what each slot of a template holds, in order:",
    "-- t our text (the header, the link type).",
    "local _, ns = ...",
    "local T = ns.AL or {}; ns.AL = T",
    "local S = ns.SORT or {}; ns.SORT = S",
]
check, sorts = R.check, R.sorts
SPEC = sys.modules[__name__]


def main(argv):
    if len(argv) < 2 or argv[1] not in ("review", "build", "stats"):
        print(__doc__)
        return 2
    addon = addon_dir(argv[2] if len(argv) > 2 else None)
    rows, why = source(addon)
    if not rows:
        print(f"Wowhead Quick Link not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
        return 1
    if argv[1] == "review":
        sizes, gone = K.review(SPEC, rows)
        print(f"{len(rows)} keys in {len(sizes)} batches " + " ".join(f"{b:02d}:{n}" for b, n in sorted(sizes.items()))
              + f"; gone with UA: {gone} -> {LOCAL}")
        print("left out: " + ", ".join(f"{k} {v}" for k, v in sorted(why.items())))
        return 0
    if argv[1] == "stats":
        K.print_stats(SPEC, rows)
        return 0
    from glossary import Glossary
    entries, res = K.build(SPEC, rows, Glossary())
    K.write_data(SPEC, entries, version(addon))
    for key, problems in res["bad"]:
        print(f"refused [{key}]: " + "; ".join(problems))
    print(f"built {res['done']} keys; untranslated {res['left']}; refused {len(res['bad'])} -> {DATA} "
          f"(text01.lua ... text{FILES:02d}.lua)")
    return 1 if res["bad"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
