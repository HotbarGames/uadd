"""Makes UADD_LootTriage's Ukrainian from review files, keyed by hashes of LootTriage's string literals.

  python3 tools/make_lt_text.py review [LT_DIR]   write local/loottriage/review_NN.txt (keeps every UA by key;
                                                  fills an empty UA from local/loottriage/draft_NN.txt)
  python3 tools/make_lt_text.py build  [LT_DIR]   write UADD_LootTriage/data/text01..NN.lua
  python3 tools/make_lt_text.py stats  [LT_DIR]   count done / left / refused per batch

LootTriage's English is read from the installed addon (or LT_DIR, or $UADD_ADDONS_DIR/LootTriage) and goes only
into local/loottriage/ (git-ignored): it has no licence. The data keeps only hashes and our Ukrainian.
Rules: tools/lt_rules.py; source: tools/lt_source.py (`python3 tools/lt_source.py all` prints every literal and
why it is left out); machinery: tools/key_text.py, tools/make_code_text.py (drafts, review, main).

Draft files (the text agents' format): blocks of an "EN: " line and a "UA: " line, "#" lines are comments. EN is
the literal as written in its Lua source (\\n, \\" escapes). A draft fills only an empty UA, and only where its EN
is the row's English exactly. An empty UA means the row stays English.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import lt_rules as R  # noqa: E402
import make_code_text as C  # noqa: E402
from lt_source import addon_dir, source, version  # noqa: E402,F401

NAME = "LootTriage"
TOOL = "tools/make_lt_text.py"
LOCAL = ROOT / "local" / "loottriage"
DATA = ROOT / "UADD_LootTriage" / "data"
FILES = 4  # the TOC lists all of them; the last ones are room for an update
BATCHES = R.BATCHES
HELP = """\
# Keys: Code.<hash> is one string literal of its code (a piece the code glues with .. is its own row).
# Slots: v a value (a number, an item link, money), t another text of ours. Its name, its chat prefix, the price
#   addons' names and the slash commands stay as they are and are not here.
"""
DATA_HEAD = [
    "-- Made by tools/make_lt_text.py build from LootTriage {ver}. Do not edit: change the review files",
    "-- (local/loottriage/review_NN.txt) and build again. Only hashes and our Ukrainian.",
    "-- T: key = Ukrainian (Code.<hash>: UADD.Hash of one string literal of LootTriage's code). S: what each",
    "-- slot of a template holds, in order: v value, f free (kept as it is), n game name, t our text.",
    "local _, ns = ...",
    "local T = ns.LT or {}; ns.LT = T",
    "local S = ns.SORT or {}; ns.SORT = S",
]
check, sorts = R.check, R.sorts
SPEC = sys.modules[__name__]
DRAFT, HEADER = C.DRAFT, C.HEADER
draft_key, read_drafts, draft_fills, fill_review = C.draft_key, C.read_drafts, C.draft_fills, C.fill_review


def review(rows, folder=None, drafts=None):
    """Review files for `rows` in `folder`, then fill empty UAs from the drafts. (sizes, gone, filled, unmatched)."""
    return C.review(SPEC, rows, folder, drafts)


def main(argv):
    return C.main(SPEC, argv, __doc__)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
