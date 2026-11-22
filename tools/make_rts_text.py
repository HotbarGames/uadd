"""Makes UADD_RoadToSixty's Ukrainian from review files, keyed by hashes of Road to Sixty's string literals.

  python3 tools/make_rts_text.py draft  [RTS_DIR]   write local/rts/draft_NN.txt: EN filled, UA empty (a UA already
                                                    written in an old draft is kept)
  python3 tools/make_rts_text.py review [RTS_DIR]   write local/rts/review_NN.txt (keeps every UA by key; fills an
                                                    empty UA from the draft files)
  python3 tools/make_rts_text.py build  [RTS_DIR]   write UADD_RoadToSixty/data/text01..NN.lua
  python3 tools/make_rts_text.py stats  [RTS_DIR]   count done / left / refused per batch

Road to Sixty is all rights reserved: its English is read from the installed addon (or RTS_DIR, or
$UADD_ADDONS_DIR/RoadToSixty) and goes only into local/rts/ (git-ignored). The data keeps only hashes and our
Ukrainian. Rules: tools/rts_rules.py (tables: tools/rts_rules2.py); source: tools/rts_source.py (`python3
tools/rts_source.py all` prints every literal and why it is left out); machinery: tools/key_text.py,
tools/make_code_text.py. Draft format: blocks of an "EN: " line and a "UA: " line, "#" lines are comments.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import key_text as K  # noqa: E402
import make_code_text as C  # noqa: E402
import rts_rules as R  # noqa: E402
from rts_source import addon_dir, source, version  # noqa: E402,F401

NAME = "RoadToSixty"
TOOL = "tools/make_rts_text.py"
LOCAL = ROOT / "local" / "rts"
DATA = ROOT / "UADD_RoadToSixty" / "data"
FILES = 4  # the TOC lists all of them; the last ones are room for an update
BATCHES = R.BATCHES
HELP = """\
# Keys: Code.<hash> is one string literal of its code (a piece the code glues with .. is its own row).
# Slots: v a value (a number, a time, a date, money), f a player's own name (kept as it is), n a game name
#   (the line stays English), t another text of ours glued in, u a duration in English units (line stays English).
# Plurals: after a number slot write {one|few|many}: %d {квест|квести|квестів}. Never without a number slot.
# Upper case: a text the addon upper-cases is its own row in capitals; ours is upper-cased by the core.
# A fixed box (tab, tile label, button) has a letter limit in its "# box" line: keep it short.
"""
DATA_HEAD = [
    "-- Made by tools/make_rts_text.py build from Road to Sixty {ver}. Do not edit: change the review files",
    "-- (local/rts/review_NN.txt) and build again. Only hashes and our Ukrainian.",
    "-- T: key = Ukrainian (Code.<hash>: UADD.Hash of one string literal of Road to Sixty's code). S: what each",
    "-- slot of a template holds, in order: v value, f free (kept as it is), n game name, t our text.",
    "local _, ns = ...",
    "local T = ns.RTS or {}; ns.RTS = T",
    "local S = ns.SORT or {}; ns.SORT = S",
]
check, sorts = R.check, R.sorts
SPEC = sys.modules[__name__]
DRAFT, HEADER = C.DRAFT, C.HEADER
draft_key, read_drafts, draft_fills, fill_review = C.draft_key, C.read_drafts, C.draft_fills, C.fill_review


def review(rows, folder=None, drafts=None):
    """Review files for `rows` in `folder`, then fill empty UAs from the drafts. (sizes, gone, filled, unmatched)."""
    return C.review(SPEC, rows, folder, drafts)


def drafts(rows, folder=None):
    """Write draft_NN.txt per batch (EN filled; UA empty unless an older draft had one). {batch: count}."""
    folder = Path(folder or LOCAL)
    folder.mkdir(parents=True, exist_ok=True)
    old = {K.unesc(en): ua for en, ua in C.read_drafts(folder)}
    by, sizes = {}, {}
    for r in rows:
        by.setdefault(r[2], []).append(r)
    for n, group in sorted(by.items()):
        out = [f"# Road to Sixty, batch {n:02d}: {len(group)} texts. Fill each empty UA: line.", *HELP.rstrip().split("\n"), ""]
        for key, en, _, places, note in group:
            letters = R.sorts(key, en)
            out.append(f"# {key} {note}")
            if letters:
                out.append("# slots: " + ", ".join(f"{i + 1}={c or '?'}" for i, c in enumerate(letters)))
            if key in R.BOX:
                out.append(f"# box: at most {R.LONG.get(key, R.MAXLEN)} letters")
            out += ["EN: " + K.esc(en), "UA: " + K.esc(old.get(en, "")), ""]
        (folder / f"draft_{n:02d}.txt").write_text("\n".join(out), encoding="utf-8", newline="\n")
        sizes[n] = len(group)
    return sizes


def main(argv):
    if len(argv) > 1 and argv[1] == "draft":
        addon = addon_dir(argv[2] if len(argv) > 2 else None)
        rows, why = source(addon)
        if not rows:
            print(f"{NAME} not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
            return 1
        sizes = drafts(rows)
        print(f"{len(rows)} keys in {len(sizes)} drafts " + " ".join(f"{b:02d}:{n}" for b, n in sorted(sizes.items()))
              + f" -> {LOCAL}")
        return 0
    return C.main(SPEC, argv, __doc__)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
