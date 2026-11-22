"""Makes UADD_OneForAll's Ukrainian from review files, keyed by hashes of OneForAll's English.

  python3 tools/make_ofa_text.py review [OFA_DIR]   write local/ofa/review_NN.txt (keeps every UA by key)
  python3 tools/make_ofa_text.py build  [OFA_DIR]   write UADD_OneForAll/data/text01..NN.lua
  python3 tools/make_ofa_text.py stats  [OFA_DIR]   count done / left / refused per batch
  python3 tools/make_ofa_text.py check N [OFA_DIR]  why each UA of batch N is refused (writes nothing)

OneForAll is GPL-3.0-or-later: its English may be committed, but the review files are made from the installed
addon (or OFA_DIR, or $UADD_ADDONS_DIR/OneForAll) and live in local/ofa/ (git-ignored) like every module's. Rules:
tools/ofa_rules.py; source: tools/ofa_source.py; machinery: tools/key_text.py, tools/make_code_text.py.
Build also writes the derived rows (ofa_source.DERIVED): a tile label OneForAll upper-cases gets our Ukrainian in
capitals, and the SkillUpUI line whose colon it cuts gets ours with a full stop. They are never reviewed.
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import key_text as K  # noqa: E402
import make_code_text as C  # noqa: E402
import ofa_rules as R  # noqa: E402
import ofa_source as S  # noqa: E402
from ofa_source import addon_dir, version  # noqa: E402,F401

NAME = "OneForAll"
TOOL = "tools/make_ofa_text.py"
LOCAL = ROOT / "local" / "ofa"
DATA = ROOT / "UADD_OneForAll" / "data"
FILES = 20  # the TOC lists all of them; the last ones are room for an update
BATCHES = [(1, "nothing")]
HELP = """\
# Keys: Code.<hash> of the English as OneForAll draws it: an L key, a data sentence (numbers as %s), a literal.
# Slots: v a value (number, money, clock), f a name kept as it is (a profile or player name), n a game name
#   (links, digits, items; anything else leaves the line English), t another text of ours glued in.
# Plurals: after a number slot write {one|few|many}: %d {рецепт|рецепти|рецептів}. Never without a number slot.
# Game names (zones, NPCs, items, quests) are never ours: they come from UALL Forever or ClassicUA.
# A text in capitals stays in capitals. A fixed box has a letter limit in its note: keep it short.
"""
DATA_HEAD = [
    "-- Made by tools/make_ofa_text.py build from OneForAll {ver}. Do not edit: change the review files",
    "-- (local/ofa/review_NN.txt) and build again.",
    "-- T: key = Ukrainian (Code.<hash>: UADD.Hash of OneForAll's English as it draws it). S: what each slot of",
    "-- a template holds, in order: v value, f free (kept as it is), n game name, t our text.",
    "local _, ns = ...",
    "local T = ns.OFA or {}; ns.OFA = T",
    "local S = ns.SORT or {}; ns.SORT = S",
]
check, sorts = R.check, R.sorts
SPEC = sys.modules[__name__]
DRAFT, HEADER = C.DRAFT, C.HEADER
draft_key, read_drafts, draft_fills, fill_review = C.draft_key, C.read_drafts, C.draft_fills, C.fill_review


def source(addon):
    rows, why = S.source(addon)
    SPEC.BATCHES = R.batches()
    return rows, why


def review(rows, folder=None, drafts=None):
    """Review files for `rows` in `folder`, then fill empty UAs from the drafts. (sizes, gone, filled, unmatched)."""
    return C.review(SPEC, rows, folder, drafts)


def derive(ua, how):
    """Our Ukrainian for a derived row, or None when it cannot be made safely."""
    if how == "upper":
        if K.SPECIAL.search(ua) or "{" in ua:
            return None
        return ua.upper()
    if how == "colon":
        return re.sub(r":$", "", ua) + "." if ua.endswith(":") else None
    return None


def derived_entries(rows, glossary, folder=None):
    """Lua chunks of the derived rows whose base row is built (same checks as the base)."""
    rev = K.read_all(folder or LOCAL)
    by_key = {r[0]: r[1] for r in rows}
    out = []
    for en, (base, how) in sorted(S.DERIVED.items()):
        ua = rev.get(base, ("", ""))[1]
        if base not in by_key or not ua.strip():
            continue
        full, problems = K.expand(ua, glossary)
        if problems or check(base, by_key[base], full):
            continue
        uk = derive(full, how)
        if uk:
            out.append(K.lua_entry("T", "Code." + H.djb2(en), uk))
    return out


def build(addon, folder=None, out_dir=None):
    from glossary import Glossary
    rows, _ = source(addon)
    g = Glossary()
    entries, res = K.build(SPEC, rows, g, folder)
    entries += derived_entries(rows, g, folder)
    K.write_data(SPEC, entries, version(addon), out_dir)
    return res


def main(argv):
    if len(argv) > 1 and argv[1] == "build":
        addon = addon_dir(argv[2] if len(argv) > 2 else None)
        if not (Path(addon) / S.TOC).is_file():
            print(f"{NAME} not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
            return 1
        res = build(addon)
        for key, problems in res["bad"]:
            print(f"refused [{key}]: " + "; ".join(problems))
        print(f"built {res['done']} keys; untranslated {res['left']}; refused {len(res['bad'])} -> {DATA} "
              f"(text01.lua ... text{FILES:02d}.lua)")
        return 1 if res["bad"] else 0
    if len(argv) > 2 and argv[1] == "check":      # read-only: why each UA of one batch is refused
        rows, _ = SPEC.source(addon_dir(argv[3] if len(argv) > 3 else None))
        rev, bad = K.read_all(LOCAL), 0
        for key, en, batch, *_ in rows:
            ua = rev.get(key, ("", ""))[1]
            if batch == int(argv[2]) and ua.strip():
                problems = SPEC.check(key, en, ua)
                if problems:
                    bad += 1
                    print(f"refused [{key}]: " + "; ".join(problems))
        print(f"batch {int(argv[2]):02d}: {bad} refused")
        return 1 if bad else 0
    return C.main(SPEC, argv, __doc__)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
