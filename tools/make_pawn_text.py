"""Makes UADD_Pawn's Ukrainian from review files, keyed by Pawn's own PawnLocal paths.

  python3 tools/make_pawn_text.py review [PAWN_DIR]   write local/pawn/review_NN.txt (keeps every UA by key)
  python3 tools/make_pawn_text.py build  [PAWN_DIR]   write UADD_Pawn/data/text01..NN.lua and data/names.lua
  python3 tools/make_pawn_text.py stats  [PAWN_DIR]   count done / left / refused per batch

Pawn's English is read from the installed addon (or PAWN_DIR, or $UADD_ADDONS_DIR/Pawn) and goes only into
local/pawn/ (git-ignored): Pawn is CC BY-NC-ND 3.0, which we treat as all rights reserved. The data keeps only
PawnLocal paths, the names of Pawn's UI globals, and our Ukrainian. Rules: tools/pawn_rules.py; machinery:
tools/key_text.py.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import key_text as K  # noqa: E402
import pawn_rules as R  # noqa: E402
from pawn_source import addon_dir, source, version  # noqa: E402

NAME = "Pawn"
TOOL = "tools/make_pawn_text.py"
LOCAL = ROOT / "local" / "pawn"
DATA = ROOT / "UADD_Pawn" / "data"
FILES = 8  # the TOC lists all of them; the last ones are room for a Pawn update
BATCHES = R.BATCHES
HELP = """\
# Slot letters after "slots:" (what Pawn puts in each slot; tools/pawn_rules.py SORTS):
#   v a value (a number, a colour, nothing), f a name kept as it is (a scale, a player), n a game name (the
#   module keeps that line English), t another of these texts.
# Tooltip lines: keep ": " before the value and a |cff... code at the start where the English has them.
"""
DATA_HEAD = [
    "-- Made by tools/make_pawn_text.py build from Pawn {ver}. Do not edit: change the review files",
    "-- (local/pawn/review_NN.txt) and build again. Only PawnLocal paths of Pawn and our Ukrainian.",
    "-- T: PawnLocal path = Ukrainian. S: what each slot of a template holds, in order: v value, f free (kept",
    "-- as it is), n game name (the line stays English), t our text (another path).",
    "local _, ns = ...",
    "local T = ns.AL or {}; ns.AL = T",
    "local S = ns.SORT or {}; ns.SORT = S",
]
check, sorts = R.check, R.sorts
SPEC = sys.modules[__name__]


def write_names(names, ver, out_dir=None):
    """data/names.lua: which Pawn UI globals hold which PawnLocal path, the two label lists, the stat keys."""
    out = [f"-- Made by tools/make_pawn_text.py build from Pawn {ver}. Do not edit. Identifiers only:",
           "-- G: a global UIStrings.lua fills from PawnLocal = its path. X: the globals PawnUI.xml shows.",
           "-- L: Pawn's label lists = their paths. ST: the PawnLocal.Stats paths in Pawn's stat rows.",
           "local _, ns = ...",
           "local G, X, L = {}, {}, {}",
           "ns.Names = { G = G, X = X, L = L, ST = {} }"]
    for n, p in sorted(names["globals"].items()):
        out.append(f"G.{n} = {H.lua_str(p)}")
    for n in names["xml"]:
        out.append(f"X.{n} = true")
    for n, paths in sorted(names["lists"].items()):
        out.append(f"L.{n} = {{ " + ", ".join(H.lua_str(p) for p in paths) + " }")
    st = names["stats"]
    for i in range(0, len(st), 6):
        out.append("for _, p in ipairs({ " + ", ".join(H.lua_str(p) for p in st[i:i + 6]) +
                   " }) do ns.Names.ST[#ns.Names.ST + 1] = p end")
    p = Path(out_dir or DATA) / "names.lua"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("\n".join(out) + "\n", encoding="utf-8", newline="\n")


def main(argv):
    if len(argv) < 2 or argv[1] not in ("review", "build", "stats"):
        print(__doc__)
        return 2
    addon = addon_dir(argv[2] if len(argv) > 2 else None)
    rows, names, why = source(addon)
    if not rows:
        print(f"Pawn not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
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
    write_names(names, version(addon))
    for key, problems in res["bad"]:
        print(f"refused [{key}]: " + "; ".join(problems))
    print(f"built {res['done']} keys; untranslated {res['left']}; refused {len(res['bad'])} -> {DATA} "
          f"(text01.lua ... text{FILES:02d}.lua, names.lua)")
    return 1 if res["bad"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
