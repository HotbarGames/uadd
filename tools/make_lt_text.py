"""Makes UADD_LootTriage's Ukrainian from review files, keyed by hashes of LootTriage's string literals.

  python3 tools/make_lt_text.py review [LT_DIR]   write local/loottriage/review_NN.txt (keeps every UA by key;
                                                  fills an empty UA from local/loottriage/draft_NN.txt)
  python3 tools/make_lt_text.py build  [LT_DIR]   write UADD_LootTriage/data/text01..NN.lua
  python3 tools/make_lt_text.py stats  [LT_DIR]   count done / left / refused per batch

LootTriage's English is read from the installed addon (or LT_DIR, or $UADD_ADDONS_DIR/LootTriage) and goes only
into local/loottriage/ (git-ignored): it has no licence. The data keeps only hashes and our Ukrainian.
Rules: tools/lt_rules.py; source: tools/lt_source.py (`python3 tools/lt_source.py all` prints every literal and
why it is left out); machinery: tools/key_text.py.

Draft files (the text agents' format): blocks of an "EN: " line and a "UA: " line, "#" lines are comments. EN is
the literal as written in its Lua source (\\n, \\" escapes). A draft fills only an empty UA, and only where its EN
is the row's English exactly. An empty UA means the row stays English.
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import key_text as K  # noqa: E402
import lt_rules as R  # noqa: E402
from lt_source import addon_dir, source, version  # noqa: E402

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
DRAFT = re.compile(r"^draft_\d\d\.txt$")
HEADER = re.compile(r"^#\d+ \S.*?\[(%s)\]" % K.KEY)


def draft_key(en):
    """The row key a draft EN names (its text as Lua reads it)."""
    return "Code." + H.djb2(en)


def read_drafts(folder):
    """[(EN as written, UA)] of every draft file, in file order. Missing folder or files: []."""
    out = []
    for p in sorted(Path(folder).glob("draft_*.txt")) if Path(folder).is_dir() else []:
        if not DRAFT.match(p.name):
            continue
        en = None
        for raw in p.read_text(encoding="utf-8-sig").replace("\r\n", "\n").split("\n"):
            if raw.startswith("#"):
                continue
            if raw.startswith("EN:"):
                en = raw[3:][1:] if raw[3:4] == " " else raw[3:]
            elif raw.startswith("UA:") and en is not None:
                ua = raw[3:][1:] if raw[3:4] == " " else raw[3:]
                out.append((en, K.unesc(ua)))
                en = None
    return out


def draft_fills(rows, folder):
    """({key: UA} for the rows, [EN of drafts that name no row]). The EN is read with its escapes; the raw text
    is tried too, for a draft that wrote a backslash as it is. A draft with an empty UA names a row too."""
    want, fills, unmatched = {r[0]: r[1] for r in rows}, {}, []
    for en, ua in read_drafts(folder):
        for cand in (K.unesc(en), en):
            key = draft_key(cand)
            if key in want and want[key] == cand:
                if ua.strip():
                    fills.setdefault(key, ua)
                break
        else:
            unmatched.append(en)
    return fills, unmatched


def fill_review(folder, fills):
    """Write each fill into an empty "UA: " line of the review files. Returns how many were filled."""
    n = 0
    for p in K.review_files(folder):
        lines, key, changed = p.read_text(encoding="utf-8").split("\n"), None, False
        for i, line in enumerate(lines):
            m = HEADER.match(line)
            if m:
                key = m.group(1)
            elif line == "UA: " and key in fills:
                lines[i], changed, key = "UA: " + K.esc(fills[key]), True, None
                n += 1
        if changed:
            p.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return n


def review(rows, folder=None, drafts=None):
    """Review files for `rows` in `folder`, then fill empty UAs from the drafts. (sizes, gone, filled, unmatched)."""
    folder = Path(folder or LOCAL)
    sizes, gone = K.review(SPEC, rows, folder)
    fills, unmatched = draft_fills(rows, drafts or folder)
    return sizes, gone, fill_review(folder, fills), unmatched


def main(argv):
    if len(argv) < 2 or argv[1] not in ("review", "build", "stats"):
        print(__doc__)
        return 2
    addon = addon_dir(argv[2] if len(argv) > 2 else None)
    rows, why = source(addon)
    if not rows:
        print(f"LootTriage not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
        return 1
    if argv[1] == "review":
        sizes, gone, filled, unmatched = review(rows)
        print(f"{len(rows)} keys in {len(sizes)} batches " + " ".join(f"{b:02d}:{n}" for b, n in sorted(sizes.items()))
              + f"; gone with UA: {gone}; filled from drafts: {filled} -> {LOCAL}")
        print("left out: " + ", ".join(f"{k} {v}" for k, v in sorted(why.items())))
        if unmatched:
            print(f"draft lines that match no row ({len(unmatched)}): " + " | ".join(unmatched[:20]))
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
