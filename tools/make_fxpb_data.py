"""ForeverXP Bar's texts for UADD_ForeverXPBar: read from the installed addon, its English never kept in the repo.

ForeverXP Bar is all rights reserved and has no locale table, so the module finds its texts on screen by
hash (UADD/Hash.lua). This tool reads the addon's Lua files (tools/fxpb_scan.py finds the texts it shows,
tools/fxpb_rules.py says what is left out and why) and writes
  * local/foreverxpbar.txt (git-ignored): every text's English (EN) and our Ukrainian (UA), by screen area;
  * UADD_ForeverXPBar/data/words.lua (tracked): hashes of the English and our Ukrainian (tools/fxpb_words.py).

Translator workflow:
  1. python3 tools/make_fxpb_data.py      after an addon update, or to get the review file. Our Ukrainian
     comes from the review file when there is one, else from data/words.lua; data/words.lua is rebuilt.
  2. change UA lines in local/foreverxpbar.txt, then run step 1 again.
  3. python3 -m unittest tools.test_fxpb_strings, then the harness (tools/harness/flow_fxpb*.py).
  --fresh     forget the review file: take our Ukrainian from data/words.lua (after a git pull)
  --check     exit 1 when data/words.lua differs from a build of itself against the addon now
  --skipped   also print the texts left out, with the reason
A text new in the addon gets an empty UA line (it stays English); one the addon dropped is reported.
ForeverXP Bar is read from $FXPB_DIR, else the WoW _forever_ AddOns folder. Standard library only.
"""
import argparse
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fxpb_rules as R  # noqa: E402
import fxpb_scan as S  # noqa: E402
import fxpb_words as W  # noqa: E402
import glossary  # noqa: E402
import hashtext as H  # noqa: E402
import luatok  # noqa: E402

REPO = HERE.parent
DATA = REPO / "UADD_ForeverXPBar" / "data" / "words.lua"
REVIEW = REPO / "local" / "foreverxpbar.txt"
WOW_DIR = "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/ForeverXPbar"
MAIN = "ForeverXPBar.lua"
# Fonts.lua (font names) and Compat70006.lua (no text) are not read; CampData.lua holds only match names.
FILES = ["ForeverXPBarSounds.lua", "ForeverXPBarCampData.lua", "ForeverXPBarFlightTiming.lua", MAIN]
# Screen areas: (id, title, [(file, first line, last line)]). The first area that holds a line wins;
# lines of the main file that no range holds go to "misc". Only the review file shows them.
AREAS = [
    ("flight", "Flight timer", [(MAIN, 2370, 2420), (MAIN, 6970, 7010), ("ForeverXPBarFlightTiming.lua", 1, 9999)]),
    ("bar", "XP bar texts, analytics, tooltips, buff banners, session summary",
     [(MAIN, 1, 5299), (MAIN, 12601, 12899)]),
    ("options", "Minimap button, settings window, options pages", [(MAIN, 5300, 7399),
                                                                   ("ForeverXPBarSounds.lua", 1, 9999)]),
    ("settings", "Adjust, profiles, challenge setup, help page, what's new, reset popups", [(MAIN, 7400, 8899)]),
    ("card", "Record panel, level-up card, chat card", [(MAIN, 8900, 9899)]),
    ("race", "Challenge goal, races, leaderboard", [(MAIN, 9900, 12600)]),
    ("chat", "Chat messages and /fxpb help", [(MAIN, 12900, 99999)]),
    ("misc", "Other", []),
    ("joined", "Whole texts the addon glues together from the pieces above (fxpb_rules.JOINED)", []),
]
FILE_ID = {"ForeverXPBar.lua": "", "ForeverXPBarSounds.lua": "Sounds:", "ForeverXPBarCampData.lua": "CampData:",
           "ForeverXPBarFlightTiming.lua": "FlightTiming:"}


def addon_dir(arg=None):
    return Path(arg or os.environ.get("FXPB_DIR") or WOW_DIR)


def have_addon(arg=None):
    return (addon_dir(arg) / MAIN).exists()


def version(src_dir=None):
    toc = addon_dir(src_dir) / "ForeverXPBar.toc"
    ver = re.search(r"## Version:\s*(\S+)", luatok.read(toc)) if toc.exists() else None
    return ver.group(1) if ver else "?"


def debug_lines(toks, text):
    """Line numbers inside the DEBUG_STARTS blocks (from the opening line to its `end`)."""
    lines = text.split("\n")
    starts = {n + 1 for n, s in enumerate(lines) if any(re.search(p, s) for p in R.DEBUG_STARTS)}
    out = set()
    for n in sorted(starts):
        i = next((k for k, tk in enumerate(toks) if tk[2] == n and tk[1] in ("if", "function")), None)
        if i is None:
            continue
        depth = 0
        for k in range(i, len(toks)):
            if toks[k][0] != luatok.NAME:
                continue
            if toks[k][1] in ("function", "if", "do", "repeat"):
                depth += 1
            elif toks[k][1] in ("end", "until"):
                depth -= 1
                if depth == 0:
                    out.update(range(n, toks[k][2] + 1))
                    break
    return out


def area_of(fname, line):
    for aid, _, ranges in AREAS:
        if any(f == fname and lo <= line <= hi for f, lo, hi in ranges):
            return aid
    return "misc"


def utf8(s):
    """luatok turns a "\\226\\128\\162" escape into three characters; join them back into the UTF-8 one."""
    if not any(128 <= ord(c) < 256 for c in s):
        return s
    try:
        return s.encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return s


def joined(recipe, lits):
    """A JOINED recipe as text (its keys looked up in the addon's string literals), or None."""
    parts = [lits.get(p) if W.KEY.fullmatch(p) else p for p in recipe]
    return None if None in parts else "".join(parts)


def collect(src_dir=None):
    """(kept, skipped): kept = {area: [[kind, text, [where...]]]} in source order; skipped = [(reason, item, where)]."""
    src_dir = addon_dir(src_dir)
    kept, skipped, seen, lits = {a[0]: [] for a in AREAS}, [], {}, {}
    for fname in FILES:
        path = src_dir / fname
        if not path.exists():
            continue
        text = luatok.read(path)
        toks = list(luatok.tokens(text))
        for kind, val, _ in toks:
            if kind == luatok.STR:
                lits.setdefault(H.key(utf8(val)), utf8(val))
        src, dbg = text.split("\n"), debug_lines(toks, text)
        for item in S.scan(text):
            where = f"{FILE_ID[fname]}L{item.line}"
            item.text = utf8(item.text)
            why = R.skip_reason(item, src[item.line - 1], item.line in dbg)
            if why:
                skipped.append((why, item, where))
            elif (item.kind, item.text) in seen:
                seen[(item.kind, item.text)][2].append(where)
            else:
                seen[(item.kind, item.text)] = [item.kind, item.text, [where]]
                kept[area_of(fname, item.line)].append(seen[(item.kind, item.text)])
    for n, recipe in enumerate(R.JOINED, 1):
        text = joined(recipe, lits)
        if text is None:
            skipped.append(("gone", S.Text("format", repr(recipe), 0, "joined"), f"JOINED #{n}"))
        elif ("format", text) not in seen:
            seen[("format", text)] = ["format", text, [f"JOINED #{n}"]]
            kept["joined"].append(seen[("format", text)])
    return kept, skipped


def texts(kept):
    """[(kind, English)] of all kept texts, in review order."""
    return [(kind, text) for aid, _, _ in AREAS for kind, text, _ in kept[aid]]


def write_review(kept, uk, ver):
    """The review file's text: each text's EN and UA lines, by area."""
    out = [f"# ForeverXP Bar {ver}: its English (EN) and our Ukrainian (UA). Made by tools/make_fxpb_data.py.",
           '# Change UA lines only: "text", G"glossary.id" (UADD/glossary), or nothing (stays English); then',
           "# run the tool again. A template keeps its slots (%s %d %.1f, %2$s to change their order; %% is a",
           "# real percent sign), its |c..|r colour codes, \\n breaks and the spaces at its ends (the addon glues",
           "# those pieces to other words). Commands, the addon's name, the default race name, addon messages",
           "# and the game's own chat lines it reads back are not listed: they stay English.", ""]
    n = 0
    for aid, title, _ in AREAS:
        rows = kept[aid]
        if rows:
            out += [f"## {aid}: {title} (#{n + 1}-#{n + len(rows)})", ""]
        for kind, text, where in rows:
            n += 1
            more = f" (also {', '.join(where[1:4])}{' ...' if len(where) > 4 else ''})" if len(where) > 1 else ""
            out += [f"#{n} {where[0]}{more}{' template' if kind == 'format' else ''}",
                    "EN: " + H.lua_str(text), "UA: " + (uk.get(text) or ""), ""]
    return "\n".join(out)


def read_review(text):
    """{English: UA value} from the review file ("" for an empty UA line)."""
    out, en = {}, None
    for line in text.split("\n"):
        if line.startswith("EN: "):
            en = W.unlua(line[4:].strip())
        elif line.startswith("UA:") and en is not None:
            v = line[3:].strip()
            if v and not W.VALUE.fullmatch(v):
                raise SystemExit(f"{REVIEW}: {en!r}: not a Lua string or G\"id\": {v}")
            out[en], en = v, None
    return out


def ukrainian(kept, fresh=False):
    """Our Ukrainian by English: the review file's, else data/words.lua's."""
    if REVIEW.exists() and not fresh:
        return read_review(REVIEW.read_text(encoding="utf-8"))
    return W.ukrainian(texts(kept), DATA.read_text(encoding="utf-8") if DATA.exists() else "")


def build(src_dir=None, uk=None):
    """(data/words.lua text, problems, kept). uk: our Ukrainian by English (default: from data/words.lua)."""
    kept, _ = collect(src_dir)
    if uk is None:
        uk = ukrainian(kept, fresh=True)
    data, problems = W.build(texts(kept), uk, glossary.Glossary())
    return W.write(data, version(src_dir)), problems, kept


def report(kept, uk, old):
    """What is new, gone or untranslated, against the Ukrainian we had."""
    now = texts(kept)
    have = {en for _, en in now}
    new = [en for _, en in now if en not in old]
    gone = [en for en in old if en not in have and old[en]]
    empty = [en for _, en in now if not uk.get(en)]
    print(f"{len(now)} texts: {len(new)} new, {len(empty)} without Ukrainian; {len(gone)} translated ones gone")
    for en in gone:
        print("  gone:", repr(en))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("dir", nargs="?", help="ForeverXP Bar folder (default $FXPB_DIR, else the WoW AddOns folder)")
    ap.add_argument("--fresh", action="store_true", help="take our Ukrainian from data/words.lua, not the review file")
    ap.add_argument("--check", action="store_true", help="only compare data/words.lua with a fresh build")
    ap.add_argument("--skipped", action="store_true", help="print the texts left out, with the reason")
    args = ap.parse_args(argv)
    if not have_addon(args.dir):
        print(f"ForeverXP Bar not found in {addon_dir(args.dir)} (set FXPB_DIR)", file=sys.stderr)
        return 2
    if args.skipped:
        for why, item, where in collect(args.dir)[1]:
            print(f"{why:8} {where:18} {item.sink:28} {item.text!r}")
    if args.check:
        text, problems, _ = build(args.dir)
        same = DATA.exists() and DATA.read_text(encoding="utf-8") == text
        print("data/words.lua is up to date" if same else "data/words.lua is out of date: run tools/make_fxpb_data.py")
        return 0 if same and not problems else 1
    kept, _ = collect(args.dir)
    old = ukrainian(kept)
    uk = ukrainian(kept, args.fresh)
    text, problems, _ = build(args.dir, uk)
    for p in problems:
        print("  not used:", p)
    REVIEW.parent.mkdir(exist_ok=True)
    REVIEW.write_text(write_review(kept, uk, version(args.dir)), encoding="utf-8", newline="\n")
    DATA.parent.mkdir(parents=True, exist_ok=True)
    DATA.write_text(text, encoding="utf-8", newline="\n")
    report(kept, uk, old)
    print(f"wrote {REVIEW.relative_to(REPO)} and {DATA.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
