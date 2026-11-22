"""Makes UADD_DeleteCheapestItem's Ukrainian from review files, keyed by hashes of its L keys.

  python3 tools/make_dci_text.py review [DIR]   write local/deletecheapestitem/review_NN.txt (keeps every UA by key;
                                                fills an empty UA from local/deletecheapestitem/draft_NN.txt)
  python3 tools/make_dci_text.py build  [DIR]   write UADD_DeleteCheapestItem/data/text01..NN.lua
  python3 tools/make_dci_text.py stats  [DIR]   count done / left / refused per batch

DeleteCheapestItem Reloaded is all rights reserved (TOC X-License): its English is read from the installed addon
(or DIR, or $UADD_ADDONS_DIR/DeleteCheapestItem) and goes only into local/deletecheapestitem/ (git-ignored). The
data keeps only hashes and our Ukrainian. Rules: tools/dci_rules.py; source: tools/dci_source.py; machinery:
tools/key_text.py, tools/make_code_text.py. A join row (a text the code glues a name to) with an empty UA takes
its part's Ukrainian and the same glue.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import dci_rules as R  # noqa: E402
import key_text as K  # noqa: E402
import make_code_text as C  # noqa: E402
from dci_source import addon_dir, source, version  # noqa: E402,F401

NAME = "DeleteCheapestItem Reloaded"
TOOL = "tools/make_dci_text.py"
LOCAL = ROOT / "local" / "deletecheapestitem"
DATA = ROOT / "UADD_DeleteCheapestItem" / "data"
FILES = 3  # the TOC lists all of them; the last ones are room for an update
BATCHES = R.BATCHES
HELP = """\
# Keys: Code.<hash> is one L key of its code. A join row is a text the code glues a name to, with its slot.
# Slots: v a value (a number, money, a coloured count), f a free name (a profile, a price addon), n an item's
#   name or link (the line stays English without UALL Forever's or ClassicUA's), t another text of ours.
"""
DATA_HEAD = [
    "-- Made by tools/make_dci_text.py build from DeleteCheapestItem Reloaded {ver}. Do not edit: change the review",
    "-- files (local/deletecheapestitem/review_NN.txt) and build again. Only hashes and our Ukrainian.",
    "-- T: key = Ukrainian (Code.<hash>: UADD.Hash of one L key of its code). S: what each slot of a template holds,",
    "-- in order: v value, f free (kept as it is), n game name, t our text.",
    "local _, ns = ...",
    "local T = ns.T or {}; ns.T = T",
    "local S = ns.SORT or {}; ns.SORT = S",
]
check, sorts = R.check, R.sorts
SPEC = sys.modules[__name__]
DRAFT, HEADER = C.DRAFT, C.HEADER
draft_key, read_drafts, draft_fills, fill_review = C.draft_key, C.read_drafts, C.draft_fills, C.fill_review


def join_fills(folder):
    """{join key: UA} for each join row whose part has a Ukrainian in the review files: the part and its glue."""
    have = K.read_all(folder)
    out = {}
    for jkey, part in R.JOINED.items():
        ua = (have.get(part) or ("", ""))[1]
        if ua.strip():
            out[jkey] = ua.replace("%", "%%") + R.JOINS[part]
    return out


def review(rows, folder=None, drafts=None):
    """Review files for `rows` in `folder`, then fill empty UAs from the drafts and the join rows from their part.
    (sizes, gone, filled, unmatched)."""
    folder = Path(folder or LOCAL)
    sizes, gone, filled, unmatched = C.review(SPEC, rows, folder, drafts)
    spaced, left = space_fills(rows, unmatched, drafts or folder)
    filled += fill_review(folder, spaced)
    return sizes, gone, filled + fill_review(folder, join_fills(folder)), left


def space_fills(rows, unmatched, folder):
    """A draft whose EN lost the row's space at the end (an editor trims it): ({key: UA with that space}, still
    unmatched). Only when the row is the draft's EN and one space, and the UA has no space at its end."""
    want = {r[0]: r[1] for r in rows}
    fills, left = {}, []
    for en in unmatched:
        key = draft_key(K.unesc(en) + " ")
        ua = next((u for e, u in read_drafts(folder) if e == en), "")
        if key in want and want[key] == K.unesc(en) + " " and ua.strip() and ua == ua.rstrip():
            fills.setdefault(key, ua + " ")
        else:
            left.append(en)
    return fills, left


def main(argv):
    return C.main(SPEC, argv, __doc__)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
