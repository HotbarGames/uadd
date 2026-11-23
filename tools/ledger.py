"""A cost and quality ledger of the translation skills (kept outside this repo, in ../.claude/skills/): one row per skill run.

python3 tools/ledger.py add --skill update-translations --addons LayerSwap,Attune --tokens 120000 --agents 3
                            --wall 25 --owner 5 --caught 2 [--note "..."] [--date YYYY-MM-DD]
python3 tools/ledger.py bug ADDON [--run N] [--count 1] [--note "..."]   a bug found in the game, later
python3 tools/ledger.py summary [--last 10]                             cost per run, trend, game bugs

Real costs from the Claude Code logs (usage numbers and timestamps only, never message text): give a window
with --since "<ISO time, UTC>" [--until ...] [--session ID ...] and `add` fills --tokens, --wall and --agents
itself from the lead plus all its subagents; a value given by hand wins. --dry-run prints and writes nothing.
  python3 tools/ledger.py add --skill translate-addon --addons Foo --since 2026-11-23T08:00 --dry-run
Logs: $UADD_LOGS, else the newest-matching ~/.claude/projects/*hotbar-public* (also under /mnt/c/Users/*).
Without --session, every session of the project touched in the window counts.

tokens: input + output + cache-creation + 1/10 of cache-read tokens (cache reads cost about a tenth); old rows
are hand estimates. raw_tokens (blank on old rows): the plain sum. agents: subagents with a call in the window.
wall: minutes from the first to the last log line in the window (idle gaps included).
owner: the owner's minutes (asked or estimated). caught: problems the checks caught before the game.
game_bugs: bugs found in the game (by the owner or players) in what this run made, added later with `bug`.
The file is ../.claude/ledger.tsv, next to the skills (a private repo), when that folder exists; else
.claude/ledger.tsv (git-ignored). --file or $UADD_LEDGER uses another one.
A run of translations-review is a row too: `add` and `summary` say "Review due" after REVIEW_EVERY other runs.
Standard library only.
"""
import argparse
import datetime
import glob
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_PRIVATE = os.path.join(os.path.dirname(REPO), ".claude")
DEFAULT = (os.path.join(_PRIVATE, "ledger.tsv") if os.path.isdir(os.path.join(_PRIVATE, "skills"))
           else os.path.join(REPO, ".claude", "ledger.tsv"))
COLS = ["date", "skill", "addons", "tokens", "agents", "wall_min", "owner_min", "caught", "game_bugs", "note", "raw_tokens"]
NUM = {"raw_tokens": int, "tokens": int, "agents": int, "wall_min": float, "owner_min": float, "caught": int, "game_bugs": int}
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


def parse_time(s):
    """ISO time (a date, or date and time; no zone means UTC) as an aware datetime."""
    d = datetime.datetime.fromisoformat(s.replace("Z", "+00:00"))
    return d if d.tzinfo else d.replace(tzinfo=datetime.timezone.utc)


def log_dirs():
    """Project log folders: $UADD_LOGS, else any projects/*hotbar-public* under ~ or /mnt/c/Users/*."""
    env = os.environ.get("UADD_LOGS")
    if env:
        return [env]
    pats = [os.path.expanduser("~/.claude/projects/*hotbar-public*"),
            "/mnt/c/Users/*/.claude/projects/*hotbar-public*"]
    return sorted(d for pat in pats for d in glob.glob(pat) if os.path.isdir(d))


def read_usage(fp, since, until, calls, stamps):
    """Adds one file's assistant calls in [since, until) to calls {message id: (in, out, cc, cr)}, the largest
    numbers seen per id (streamed lines repeat an id), and every line's time to stamps. Only usage and
    timestamp are read; unreadable lines are skipped."""
    with open(fp, encoding="utf-8", errors="replace") as f:
        for ln in f:
            if '"timestamp"' not in ln:
                continue
            try:
                o = json.loads(ln)
                t = parse_time(o["timestamp"])
            except (ValueError, KeyError, TypeError):
                continue
            if t < since or (until and t >= until):
                continue
            stamps.append(t)
            m = o.get("message") if o.get("type") == "assistant" else None
            u = m.get("usage") if isinstance(m, dict) else None
            if not isinstance(u, dict) or m.get("model") == "<synthetic>":
                continue
            v = tuple(int(u.get(k) or 0) for k in ("input_tokens", "output_tokens",
                                                   "cache_creation_input_tokens", "cache_read_input_tokens"))
            key = (fp, m.get("id") or o.get("requestId") or o.get("uuid"))
            calls[key] = tuple(max(x, y) for x, y in zip(calls.get(key, v), v))


def from_logs(since, until=None, sessions=None, dirs=None):
    """{'tokens', 'raw_tokens', 'agents', 'wall', 'calls', 'sessions'} for the lead and all subagents in the
    window. Without sessions, every session file of the project changed since the window began."""
    since = parse_time(since) if isinstance(since, str) else since
    until = parse_time(until) if isinstance(until, str) else until
    calls, stamps, agent_files, ses = {}, [], set(), set()
    for d in (dirs if dirs is not None else log_dirs()):
        for fp in glob.glob(os.path.join(d, "*.jsonl")):
            sid = os.path.basename(fp)[:-6]
            if sessions and sid not in sessions:
                continue
            subs = glob.glob(os.path.join(d, sid, "subagents", "**", "*.jsonl"), recursive=True)
            if not sessions and max([os.path.getmtime(x) for x in [fp] + subs]) < since.timestamp():
                continue
            before = len(calls)
            read_usage(fp, since, until, calls, stamps)
            for sp in subs:
                n = len(calls)
                read_usage(sp, since, until, calls, stamps)
                if len(calls) > n:
                    agent_files.add(sp)
            if len(calls) > before:
                ses.add(sid)
    tot = [sum(v[i] for v in calls.values()) for i in range(4)]
    wall = round((max(stamps) - min(stamps)).total_seconds() / 60, 1) if stamps else 0.0
    return {"tokens": tot[0] + tot[1] + tot[2] + tot[3] // 10, "raw_tokens": sum(tot), "agents": len(agent_files),
            "wall": wall, "calls": len(calls), "sessions": sorted(ses), "parts": tot}


def add(p, a):
    got = None
    if a.since or a.session:
        got = from_logs(a.since or "1970-01-01", a.until, a.session or None)
    hand = {"tokens": a.tokens, "agents": a.agents, "wall": a.wall}
    val = {k: (hand[k] if hand[k] is not None else (got[k] if got else 0)) for k in hand}
    out = []
    if got:
        pt = got["parts"]
        out.append(f"from logs: {got['calls']} calls in {len(got['sessions'])} session(s); input {pt[0]}, output {pt[1]}, "
                   f"cache-write {pt[2]}, cache-read {pt[3]} -> tokens {got['tokens']} (raw {got['raw_tokens']}), "
                   f"agents {got['agents']}, wall {got['wall']} min")
        out += [f"  {k}: {val[k]} (by hand)" for k in hand if hand[k] is not None]
    if a.dry_run:
        return out + ["dry run: nothing written"]
    rows = load(p)
    rows.append({"date": a.date or datetime.date.today().isoformat(), "skill": a.skill,
                 "addons": a.addons or "-", "tokens": val["tokens"], "agents": val["agents"],
                 "wall_min": val["wall"], "owner_min": a.owner, "caught": a.caught, "game_bugs": 0,
                 "note": a.note or "", "raw_tokens": got["raw_tokens"] if got and a.tokens is None else 0})
    save(p, rows)
    out.append(f"run {len(rows)} added to {p}")
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
        # the "nothing changed" runs cost 0 and would hide a rise; only measured rows (raw_tokens filled from the
        # logs) are compared: the old rows are hand estimates, a separate series
        work = [r for r in rs if r["tokens"] > 0 and r["raw_tokens"] > 0]
        out.append(f"{skill}: {len(rs)} runs ({sum(1 for r in rs if r['tokens'] == 0)} with 0 tokens); tokens per measured run "
                   f"{trend(work, 'tokens')}; owner minutes {trend(rs, 'owner_min')}")
    est = sum(1 for r in rows if r["tokens"] > 0 and r["raw_tokens"] == 0)
    out.append(f"{est} of {len(rows)} rows have estimated tokens (by hand, not from the logs); "
               f"trends use the {len(rows) - est - sum(1 for r in rows if r['tokens'] == 0)} measured rows only")
    bugs = sum(r["game_bugs"] for r in rows)
    caught = sum(r["caught"] for r in rows)
    out.append(f"game bugs: {bugs} in all, {sum(r['game_bugs'] for r in rows[-5:])} in the last 5 runs; "
               f"caught by checks: {caught}")
    out.append(due_line(rows) or f"Review not due ({since_review(rows)} of {REVIEW_EVERY} runs since the last one).")
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--file", default=None, help="ledger file (default ../.claude/ledger.tsv, or $UADD_LEDGER)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add")
    a.add_argument("--skill", default="-")
    a.add_argument("--addons", default="-")
    a.add_argument("--tokens", type=int, default=None, help="cost-weighted: in+out+cache-write+cache-read/10")
    a.add_argument("--agents", type=int, default=None)
    a.add_argument("--wall", type=float, default=None)
    a.add_argument("--since", default=None, help="ISO time (UTC): fill tokens/agents/wall from the logs")
    a.add_argument("--until", default=None, help="end of the log window (default: now)")
    a.add_argument("--session", action="append", help="session id (repeatable); default: all sessions in window")
    a.add_argument("--dry-run", action="store_true", help="print what would be added, write nothing")
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
        if args.skill == "-" and not args.dry_run:
            ap.error("add needs --skill")
        out = add(p, args)
    elif args.cmd == "bug":
        out = bug(p, args)
    else:
        out = summary(p, args.last)
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
