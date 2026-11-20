"""Makes UADD_Scrap's Ukrainian from review files, keyed by Scrap's own locale keys.

  python3 tools/make_scrap_text.py review [SCRAP_DIR]   write local/scrap/review_NN.txt (keeps every UA by key)
  python3 tools/make_scrap_text.py build  [SCRAP_DIR]   write UADD_Scrap/data/text01..NN.lua
  python3 tools/make_scrap_text.py stats  [SCRAP_DIR]   count done / left / refused per batch

Scrap's English is read from the installed addon (or SCRAP_DIR, or $UADD_ADDONS_DIR/Scrap) and goes only into
local/scrap/ (git-ignored): its TOCs say All Rights Reserved. The data keeps only locale keys, hashes and our
Ukrainian. Rules: tools/scrap_rules.py; machinery: tools/key_text.py.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import key_text as K  # noqa: E402
import scrap_rules as R  # noqa: E402
from scrap_source import addon_dir, source, version  # noqa: E402

NAME = "Scrap"
TOOL = "tools/make_scrap_text.py"
LOCAL = ROOT / "local" / "scrap"
DATA = ROOT / "UADD_Scrap" / "data"
FILES = 2  # the TOC lists all of them; the last one is room for a Scrap update
BATCHES = R.BATCHES
HELP = """\
# Keys: L.<key> is a text of Scrap's own locale; FAQ.<n> a line of its questions list (odd: a question, even:
#   its answer); Code.<hash> a text its settings code writes itself.
# Keep |cff...|r colour codes and |n line breaks where the English has them. Item names come from the game
#   and are not here. The addon's name "Scrap" stays as it is. Junk: G"item.junk" or plain «мотлох».
"""
DATA_HEAD = [
    "-- Made by tools/make_scrap_text.py build from Scrap {ver}. Do not edit: change the review files",
    "-- (local/scrap/review_NN.txt) and build again. Only Scrap's locale keys, hashes and our Ukrainian.",
    "-- T: key = Ukrainian (L.<key>: Scrap's locale key; FAQ.<n>: a line of its questions list; Code.<hash>:",
    "-- UADD.Hash of a text its settings code writes). S: what each slot of a template holds, in order:",
    "-- v value, f free (kept as it is), n game name (the line stays English), t our text.",
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
        print(f"Scrap not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
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
