"""Makes UADD_SpeedyAutoLoot's Ukrainian from review files, keyed by a hash of Speedy AutoLoot's English.

  python3 tools/make_sal_text.py review [SAL_DIR]   write local/sal/review_NN.txt (keeps every UA by key)
  python3 tools/make_sal_text.py build  [SAL_DIR]   write UADD_SpeedyAutoLoot/data/text01.lua
  python3 tools/make_sal_text.py stats  [SAL_DIR]   count done / left / refused

Speedy AutoLoot's English is read from the installed addon (or SAL_DIR, or $UADD_ADDONS_DIR/SpeedyAutoLoot) and
goes only into local/sal/ (git-ignored): it has no licence file, so all rights are reserved. The data keeps only
hashes and our Ukrainian. Texts: tools/sal_source.py; rules: tools/sal_rules.py; machinery: tools/key_text.py.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import key_text as K  # noqa: E402
import sal_rules as R  # noqa: E402
from sal_source import addon_dir, source, version  # noqa: E402

NAME = "Speedy AutoLoot"
TOOL = "tools/make_sal_text.py"
LOCAL = ROOT / "local" / "sal"
DATA = ROOT / "UADD_SpeedyAutoLoot" / "data"
FILES = 1
BATCHES = R.BATCHES
HELP = """\
# Keys: Code.<hash> is UADD.Hash of the English. A chat line comes after the addon's name prefix, a help line
#   after the colour code and "/sal " (both kept as they are, not here).
# Keep |cff...|r colour codes where the English has them. A help line keeps its command part as it is, up to
#   and with the description's colour code. The addon's name "Speedy AutoLoot" stays as it is.
# Loot: G"game.loot". Fishing: G"prof.fishing". Informal "ти", short.
"""
DATA_HEAD = [
    "-- Made by tools/make_sal_text.py build from Speedy AutoLoot {ver}. Do not edit: change the review files",
    "-- (local/sal/review_NN.txt) and build again. Only hashes and our Ukrainian.",
    "-- T: Code.<hash> (UADD.Hash of the English) = Ukrainian. S: what each slot of a template holds, in order:",
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
        print(f"Speedy AutoLoot not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
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
