"""Makes UADD_GatherMate2's Ukrainian from review files, keyed by a hash of GatherMate2's locale keys.

  python3 tools/make_gm_text.py review [GM_DIR]   write local/gathermate2/review_NN.txt (keeps every UA by key)
  python3 tools/make_gm_text.py build  [GM_DIR]   write UADD_GatherMate2/data/text01..NN.lua and data/libs.lua
  python3 tools/make_gm_text.py stats  [GM_DIR]   count done / left / refused per batch

GatherMate2's English is read from the installed addon (or GM_DIR, or $UADD_ADDONS_DIR/GatherMate2) and goes
only into local/gathermate2/ (git-ignored): its TOC says ARR, so we treat it as all rights reserved. The data
keeps only hashes, Ace3 key names and our Ukrainian. Rules: tools/gm_rules.py; machinery: tools/key_text.py.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import gm_rules as R  # noqa: E402
import hashtext as H  # noqa: E402
import key_text as K  # noqa: E402
from gm_source import addon_dir, source, version  # noqa: E402

NAME = "GatherMate2"
TOOL = "tools/make_gm_text.py"
LOCAL = ROOT / "local" / "gathermate2"
DATA = ROOT / "UADD_GatherMate2" / "data"
FILES = 3  # the TOC lists all of them; the last one is room for a GatherMate2 update
BATCHES = R.BATCHES
HELP = """\
# Keys: L.<hash> is a text of GatherMate2's own locale; Panel.<app> a settings sub-panel's name; AceDBO.<key>
#   a text of the Profiles tab; AceGUI.<name> a fixed text of a settings widget.
# A text that ends with a space has something glued after it in the code: keep the space at the end.
# Keep |cff...|r colour codes and line breaks where the English has them. Node and zone names come from the
#   game and are not here. A profession name: write the glossary word its note names (G"prof...").
"""
DATA_HEAD = [
    "-- Made by tools/make_gm_text.py build from GatherMate2 {ver}. Do not edit: change the review files",
    "-- (local/gathermate2/review_NN.txt) and build again. Only hashes, Ace3 key names and our Ukrainian.",
    "-- T: key = Ukrainian (L.<hash>: UADD.Hash of GatherMate2's locale key). S: what each slot of a template",
    "-- holds, in order: v value, f free (kept as it is), n game name (the line stays English), t our text.",
    "local _, ns = ...",
    "local T = ns.AL or {}; ns.AL = T",
    "local S = ns.SORT or {}; ns.SORT = S",
]
check, sorts = R.check, R.sorts
SPEC = sys.modules[__name__]


def write_libs(libs, ver, out_dir=None):
    """data/libs.lua: the hash of the English each panel label and Ace3 text had, so the module changes a text
    only while it is still that English (an Ace3 update with new words keeps them)."""
    out = [f"-- Made by tools/make_gm_text.py build from GatherMate2 {ver}. Do not edit. Hashes only:",
           "-- EN: row key = UADD.Hash of the English that row translates.",
           "local _, ns = ...",
           "local EN = {}",
           "ns.EN = EN"]
    for k, h in sorted(libs.items()):
        out.append(f"EN[{H.lua_str(k)}] = {H.lua_str(h)}")
    p = Path(out_dir or DATA) / "libs.lua"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")


def main(argv):
    if len(argv) < 2 or argv[1] not in ("review", "build", "stats"):
        print(__doc__)
        return 2
    addon = addon_dir(argv[2] if len(argv) > 2 else None)
    rows, libs, why = source(addon)
    if not rows:
        print(f"GatherMate2 not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
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
    write_libs(libs, version(addon))
    for key, problems in res["bad"]:
        print(f"refused [{key}]: " + "; ".join(problems))
    print(f"built {res['done']} keys; untranslated {res['left']}; refused {len(res['bad'])} -> {DATA} "
          f"(text01.lua ... text{FILES:02d}.lua, libs.lua)")
    return 1 if res["bad"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
