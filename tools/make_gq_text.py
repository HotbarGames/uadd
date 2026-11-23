"""Makes UADD_GearQuestForever's Ukrainian from review files, keyed by hashes of GearQuest Forever's locale keys.

  python3 tools/make_gq_text.py review [GQ_DIR]   write local/gearquest/review_NN.txt (keeps every UA by key;
                                                  fills an empty UA from local/gearquest/draft_*.txt)
  python3 tools/make_gq_text.py review3b [GQ_DIR] write local/gearquest/review_3b.txt (its guide's pages, keyed
                                                  X.<hash>; keeps every UA by key; review_NN files untouched)
  python3 tools/make_gq_text.py build  [GQ_DIR]   write UADD_GearQuestForever/data/text01..NN.lua (review_NN + 3b)
  python3 tools/make_gq_text.py stats  [GQ_DIR]   count done / left / refused per batch

GearQuest Forever's English is read from the installed addon (or GQ_DIR, or $UADD_ADDONS_DIR/GearQuestForever) and
goes only into local/gearquest/ (git-ignored): it has no licence. The data keeps only hashes and our Ukrainian.
Rules: tools/gq_rules.py; source: tools/gq_source.py; machinery: tools/key_text.py.

Draft files (the text agents' format): blocks of an "EN: " line and a "UA: " line, "#" lines are comments. EN is
the key as written in its source (\\n, \\" escapes). A draft fills only an empty UA, and only where its EN is the
row's English exactly. A batch's agent may also write the UA straight into its review file.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import hashtext as H  # noqa: E402
import key_text as K  # noqa: E402
import gq_rules as R  # noqa: E402
from gq_source import addon_dir, source, version, x_rows  # noqa: E402

NAME = "GearQuest Forever"
TOOL = "tools/make_gq_text.py"
LOCAL = ROOT / "local" / "gearquest"
DATA = ROOT / "UADD_GearQuestForever" / "data"
FILES = 6  # the TOC lists all of them; the last ones are room for an update
BATCHES = []  # set from the rows: (n, area, None), R.SIZE rows each, in the order its code names them
HELP = """\
# Keys: L.<hash> is a key of its locale table (GearQuest.L); X.<hash> a whole text drawn without it.
# Slots: v value (number, money, colour, link), f a name kept as it is, n a game name (the line stays English),
#   t another text of ours, u its own English units (stays English). "?" = not sorted yet: sort it in
#   tools/gq_rules.py SORTS before its UA builds. Game names (items, zones, NPCs, quests, spells, skills) are never
#   written here: they come from ClassicUA and UALL Forever.
"""
DATA_HEAD = [
    "-- Made by tools/make_gq_text.py build from GearQuest Forever {ver}. Do not edit: change the review files",
    "-- (local/gearquest/review_NN.txt) and build again. Only hashes and our Ukrainian.",
    "-- T: key = Ukrainian (L.<hash>: UADD.Hash of a key of its locale table; X.<hash>: UADD.Hash of a text drawn",
    "-- without it). S: what each slot of a template holds, in order: v value, f free (kept as it is), t our text.",
    "local _, ns = ...",
    "local T = ns.AL or {}; ns.AL = T",
    "local S = ns.SORT or {}; ns.SORT = S",
]
check, sorts = R.check, R.sorts
SPEC = sys.modules[__name__]


def set_batches(rows):
    global BATCHES
    nums = sorted({r[2] for r in rows}) or [1]
    BATCHES[:] = []
    for n in nums:
        files = []
        for r in rows:
            if r[2] == n and r[3] and r[3][0][0] not in files:
                files.append(r[3][0][0])
        BATCHES.append((n, "texts of " + ", ".join(files[:6]) + (" ..." if len(files) > 6 else ""), None))


def read_drafts(folder):
    """[(EN as written, UA)] of every draft file, in file order."""
    out = []
    folder = Path(folder)
    for p in sorted(folder.glob("draft_*.txt")) if folder.is_dir() else []:
        en = None
        for raw in p.read_text(encoding="utf-8-sig").replace("\r\n", "\n").split("\n"):
            if raw.startswith("#"):
                continue
            if raw.startswith("EN:"):
                en = raw[4:] if raw[3:4] == " " else raw[3:]
            elif raw.startswith("UA:") and en is not None:
                out.append((K.unesc(en), K.unesc(raw[4:] if raw[3:4] == " " else raw[3:])))
                en = None
    return out


def fill_from_drafts(rows, folder):
    """Write each draft's UA into the empty "UA: " line of its row. (filled, [EN of drafts that name no row])."""
    want = {r[0]: r[1] for r in rows}
    fills, unmatched = {}, []
    for en, ua in read_drafts(folder):
        key = "L." + H.djb2(en)
        if ua.strip() and want.get(key) == en:
            fills.setdefault(key, ua)
        elif ua.strip():
            unmatched.append(en)
    n = 0
    for p in K.review_files(folder):
        lines, key, changed = p.read_text(encoding="utf-8").split("\n"), None, False
        for i, line in enumerate(lines):
            if line.startswith("#") and "[" in line:
                key = line.split("[", 1)[1].split("]", 1)[0]
            elif line == "UA: " and key in fills:
                lines[i], changed, key = "UA: " + K.esc(fills[key]), True, None
                n += 1
        if changed:
            p.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return n, unmatched


# ── Stage 3b: whole texts drawn without its locale table (X.<hash>), in their own review file ─────────────────
# review_3b.txt is not a review_NN file, so `review` never rewrites it and K.read_all never reads it.
REVIEW_3B = "review_3b.txt"
HEAD_3B = ("# GearQuest Forever's whole texts drawn without its locale table (stage 3b: its guide's pages). Made by:"
           " python3 tools/make_gq_text.py review3b\n"
           "# Never commit this file: it holds GearQuest Forever's English (local/ is git-ignored).\n"
           "# Same rules as review_NN.txt: the same |cff..|r, |T..|t and \\n in the same order. No game names.\n")


def read_3b(folder=None):
    p = Path(folder or LOCAL) / REVIEW_3B
    return K.read_review(p.read_text(encoding="utf-8")) if p.is_file() else {}


def review_3b(xrows, folder=None):
    """Write review_3b.txt, keeping every UA by key (gone ones too). Returns (count, gone with UA)."""
    folder = Path(folder or LOCAL)
    folder.mkdir(parents=True, exist_ok=True)
    old = read_3b(folder)
    out, now = [HEAD_3B], set()
    for n, (key, en, _b, where, note) in enumerate(xrows, 1):
        now.add(key)
        out += K.block(SPEC, n, key, en, old.get(key, ("", ""))[1], f"{note}, {where[0][0]}:{where[0][1]}")
    gone = [(k, v) for k, v in old.items() if k not in now and v[1]]
    for i, (k, (en, ua)) in enumerate(gone, len(xrows) + 1):
        out += [f"#{i} gone  [{k}]", "EN: " + K.esc(en), "UA: " + K.esc(ua), ""]
    (folder / REVIEW_3B).write_text("\n".join(out), encoding="utf-8", newline="\n")
    return len(xrows), len(gone)


def build_3b(xrows, glossary, folder=None):
    """(entries, done, left, bad) of the X rows, as K.build does for the L rows."""
    rev = read_3b(folder)
    entries, bad, left, done = [], [], 0, 0
    for key, en, *_ in xrows:
        ua = rev.get(key, ("", ""))[1]
        if not ua.strip():
            left += 1
            continue
        full, problems = K.expand(ua, glossary)
        problems += check(key, en, full)
        if problems:
            bad.append((key, problems))
            continue
        done += 1
        entries.append(K.lua_entry("T", key, full))
    return entries, done, left, bad


def main(argv):
    if len(argv) < 2 or argv[1] not in ("review", "review3b", "build", "stats"):
        print(__doc__)
        return 2
    addon = addon_dir(argv[2] if len(argv) > 2 else None)
    rows, why = source(addon)
    if not rows:
        print(f"GearQuest Forever not found in {addon} (pass its folder or set UADD_ADDONS_DIR)")
        return 1
    xrows, xwhy = x_rows(addon)
    if argv[1] == "review3b":
        n, gone = review_3b(xrows)
        print(f"{n} whole texts; gone with UA: {gone} -> {LOCAL / REVIEW_3B}"
              + ("; " + ", ".join(f"{k} {v}" for k, v in xwhy.items()) if xwhy else ""))
        return 1 if xwhy else 0
    set_batches(rows)
    if argv[1] == "review":
        sizes, gone = K.review(SPEC, rows, LOCAL)
        filled, unmatched = fill_from_drafts(rows, LOCAL)
        print(f"{len(rows)} keys in {len(sizes)} batches " + " ".join(f"{b:02d}:{n}" for b, n in sorted(sizes.items()))
              + f"; gone with UA: {gone}; filled from drafts: {filled} -> {LOCAL}")
        print("left out: " + (", ".join(f"{k} {v}" for k, v in sorted(why.items())) or "none"))
        if unmatched:
            print(f"draft lines that match no row: {len(unmatched)}")
        return 0
    if argv[1] == "stats":
        K.print_stats(SPEC, rows)
        rev = read_3b()
        done = sum(1 for k, en, *_ in xrows if rev.get(k, ("", ""))[1].strip() and not check(k, en, rev[k][1]))
        left = sum(1 for k, *_ in xrows if not rev.get(k, ("", ""))[1].strip())
        print(f"batch 3b: {len(xrows)} whole texts, done {done}, left {left}, refused {len(xrows) - done - left}"
              + ("; " + ", ".join(f"{k} {v}" for k, v in xwhy.items()) if xwhy else ""))
        return 0
    from glossary import Glossary
    glossary = Glossary()
    entries, res = K.build(SPEC, rows, glossary)
    xentries, xdone, xleft, xbad = build_3b(xrows, glossary)
    K.write_data(SPEC, entries + xentries, version(addon))
    for key, problems in res["bad"] + xbad:
        print(f"refused [{key}]: " + "; ".join(problems))
    print(f"built {res['done']} keys + {xdone} whole texts; untranslated {res['left']} + {xleft}; refused "
          f"{len(res['bad'])} + {len(xbad)} -> {DATA} (text01.lua ... text{FILES:02d}.lua)")
    return 1 if res["bad"] or xbad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
