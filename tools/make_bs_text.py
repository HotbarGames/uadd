"""Makes UADD_BugSack's Ukrainian from review files, keyed by a hash of BugSack's English.

  python3 tools/make_bs_text.py review [BS_DIR]   write local/bs/review_NN.txt (keeps every UA by key)
  python3 tools/make_bs_text.py build  [BS_DIR]   write UADD_BugSack/data/text01.lua
  python3 tools/make_bs_text.py stats  [BS_DIR]   count done / left / refused

BugSack's English is read from the installed addon (or BS_DIR, or $UADD_ADDONS_DIR/BugSack) and goes only into
local/bs/ (git-ignored): it is All Rights Reserved. The data keeps only hashes and our Ukrainian. Texts:
tools/bs_source.py; rules: tools/bs_rules.py; machinery: tools/key_text.py.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import bs_rules as R  # noqa: E402
import key_text as K  # noqa: E402
from bs_source import addon_dir, source, version  # noqa: E402

NAME = "BugSack"
TOOL = "tools/make_bs_text.py"
LOCAL = ROOT / "local" / "bs"
DATA = ROOT / "UADD_BugSack" / "data"
FILES = 1
BATCHES = R.BATCHES
HELP = """\
# Keys: L.<hash> a value of its locale table, Word.<hash> a word glued into the session line, Game.<hash> the
#   game's word (its options tab). <hash> is UADD.Hash of the English.
# The names "BugSack", "BugGrabber", "Shift", "Alt" stay as they are. Keep every |cff...|r colour.
# A bug is "помилка", a session "сесія". Informal "ти", short. No long dash, no middle dot, no angle quotes.
"""
DATA_HEAD = [
    "-- Made by tools/make_bs_text.py build from BugSack {ver}. Do not edit: change the review files",
    "-- (local/bs/review_NN.txt) and build again. Only hashes and our Ukrainian.",
    "-- T: <kind>.<hash> (UADD.Hash of the English) = Ukrainian. S: what each slot of a template holds, in order:",
    "-- f a player's name (kept as it is), t our word, v a number.",
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
        print(f"BugSack not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
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
