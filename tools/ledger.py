"""A cost and quality ledger of the translation skills (kept outside this repo, in ../.claude/skills/): one row per skill run.

python3 tools/ledger.py add --skill update-translations --addons LayerSwap,Attune --tokens 120000 --agents 3
                            --wall 25 --owner 5 --caught 2 [--note "..."] [--date YYYY-MM-DD]
python3 tools/ledger.py bug ADDON [--run N] [--count 1] [--note "..."]   a bug found in the game, later
python3 tools/ledger.py summary [--last 10]                             cost per run, trend, game bugs

tokens: the sum of the agents' tokens the lead saw. wall: minutes from start to commit. owner: the owner's
minutes (asked or estimated; in-game testing counts most). caught: problems the checks caught before the game.
game_bugs: bugs found in the game (by the owner or players) in what this run made, added later with `bug`.
The file is .claude/ledger.tsv (git-ignored: it stays on this PC); --file or $UADD_LEDGER uses another one.
A run of translations-review is a row too: `add` and `summary` say "Review due" after REVIEW_EVERY other runs.
Standard library only.
"""
import argparse
import datetime
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT = os.path.join(REPO, ".claude", "ledger.tsv")
COLS = ["date", "skill", "addons", "tokens", "agents", "wall_min", "owner_min", "caught", "game_bugs", "note"]
NUM = {"tokens": int, "agents": int, "wall_min": float, "owner_min": float, "caught": int, "game_bugs": int}
REVIEW = "translations-review"
REVIEW_EVERY = 5


def path(arg=None):
    return arg or os.environ.get("UADD_LEDGER") or DEFAULT


def clean(s):
    return " ".join(str(s).replace("\t", " ").split())


def load(p):
    """[{col: value}] in file order (numbers as numbers). A missing file is an empty ledger."""
    if not os.path.exists(p):
        return []
    rows = []
    with open(p, encoding="utf-8") as f:
        for i, ln in enumerate(f):
            parts = ln.rstrip("\n").split("\t")
            if i == 0 and parts[0] == "date":
                continue
            row = dict(zip(COLS, parts + [""] * (len(COLS) - len(parts))))
            for k, kind in NUM.items():
                try:
                    row[k] = kind(row[k] or 0)
                except ValueError:
                    row[k] = kind(0)
            rows.append(row)
    return rows


def save(p, rows):
    os.makedirs(os.path.dirname(os.path.abspath(p)), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write("\t".join(COLS) + "\n")
        for r in rows:
            f.write("\t".join(clean(fmt(r[c])) for c in COLS) + "\n")


def fmt(v):
    return ("%g" % v) if isinstance(v, float) else str(v)


def since_review(rows):
    """Runs (not reviews) since the last translations-review row."""
    n = 0
    for r in reversed(rows):
        if r["skill"] == REVIEW:
            break
        n += 1
    return n


def due_line(rows):
    n = since_review(rows)
    return f"Review due: {n} runs since the last {REVIEW}. Run the {REVIEW} skill." if n >= REVIEW_EVERY else ""


def add(p, a):
    rows = load(p)
    rows.append({"date": a.date or datetime.date.today().isoformat(), "skill": a.skill,
                 "addons": a.addons or "-", "tokens": a.tokens, "agents": a.agents, "wall_min": a.wall,
                 "owner_min": a.owner, "caught": a.caught, "game_bugs": 0, "note": a.note or ""})
    save(p, rows)
    out = [f"run {len(rows)} added to {p}"]
    if a.skill != REVIEW and due_line(rows):
        out.append(due_line(rows))
    return out


def bug(p, a):
    """Adds game bugs to run --run, else to the newest run whose addons name ADDON (any case, part of a name)."""
    rows = load(p)
    if a.run:
        if not 1 <= a.run <= len(rows):
            raise SystemExit(f"no run {a.run} (the ledger has {len(rows)})")
        i = a.run - 1
    else:
        hits = [i for i, r in enumerate(rows) if a.addon.lower() in r["addons"].lower()]
        if not hits:
            raise SystemExit(f"no run names {a.addon}: give --run N (see summary)")
        i = hits[-1]
    rows[i]["game_bugs"] += a.count
    if a.note:
        rows[i]["note"] = clean(f"{rows[i]['note']} bug: {a.note}")
    save(p, rows)
    return [f"run {i + 1} ({rows[i]['date']} {rows[i]['skill']} {rows[i]['addons']}): "
            f"{rows[i]['game_bugs']} game bug(s)"]


def avg(rows, col):
    return sum(r[col] for r in rows) / len(rows) if rows else 0.0


def trend(rows, col):
    """'rising' / 'falling' / 'flat': the newer half's average against the older half's (10% margin)."""
    if len(rows) < 4:
        return "too few runs"
    half = len(rows) // 2
    old, new = avg(rows[:half], col), avg(rows[-half:], col)
    if new > old * 1.1:
        return f"rising ({old:.0f} -> {new:.0f})"
    if new < old * 0.9:
        return f"falling ({old:.0f} -> {new:.0f})"
    return f"flat ({old:.0f} -> {new:.0f})"


def summary(p, last=10):
    rows = load(p)
    if not rows:
        return [f"ledger empty: {p}"]
    out = ["run  date        skill                 addons                tokens agents  wall owner caught game"]
    for i, r in enumerate(rows, 1):
        if i > len(rows) - last:
            out.append(f"{i:>3}  {r['date']:<10}  {r['skill'][:20]:<20}  {r['addons'][:20]:<20}  {r['tokens']:>6}"
                       f" {r['agents']:>6} {fmt(r['wall_min']):>5} {fmt(r['owner_min']):>5} {r['caught']:>6}"
                       f" {r['game_bugs']:>4}")
    for skill in sorted({r["skill"] for r in rows}):
        rs = [r for r in rows if r["skill"] == skill]
        work = [r for r in rs if r["tokens"] > 0]   # the "nothing changed" runs cost 0 and would hide a rise
        out.append(f"{skill}: {len(rs)} runs ({len(rs) - len(work)} with 0 tokens); tokens per working run "
                   f"{trend(work, 'tokens')}; owner minutes {trend(rs, 'owner_min')}")
    bugs = sum(r["game_bugs"] for r in rows)
    caught = sum(r["caught"] for r in rows)
    out.append(f"game bugs: {bugs} in all, {sum(r['game_bugs'] for r in rows[-5:])} in the last 5 runs; "
               f"caught by checks: {caught}")
    out.append(due_line(rows) or f"Review not due ({since_review(rows)} of {REVIEW_EVERY} runs since the last one).")
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--file", default=None, help="ledger file (default .claude/ledger.tsv, or $UADD_LEDGER)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add")
    a.add_argument("--skill", required=True)
    a.add_argument("--addons", default="-")
    a.add_argument("--tokens", type=int, default=0)
    a.add_argument("--agents", type=int, default=0)
    a.add_argument("--wall", type=float, default=0.0)
    a.add_argument("--owner", type=float, default=0.0)
    a.add_argument("--caught", type=int, default=0)
    a.add_argument("--note", default="")
    a.add_argument("--date", default=None)
    b = sub.add_parser("bug")
    b.add_argument("addon")
    b.add_argument("--run", type=int, default=0)
    b.add_argument("--count", type=int, default=1)
    b.add_argument("--note", default="")
    s = sub.add_parser("summary")
    s.add_argument("--last", type=int, default=10)
    args = ap.parse_args(argv)
    p = path(args.file)
    if args.cmd == "add":
        out = add(p, args)
    elif args.cmd == "bug":
        out = bug(p, args)
    else:
        out = summary(p, args.last)
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
