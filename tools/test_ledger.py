"""tools/ledger.py on a temporary ledger: add, bug, summary, the review reminder and the trend.

Run: python3 -m unittest tools.test_ledger
"""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ledger  # noqa: E402


class Ledger(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.file = os.path.join(self.tmp.name, "sub", "ledger.tsv")

    def tearDown(self):
        self.tmp.cleanup()

    def run_cli(self, *args):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.assertEqual(ledger.main(["--file", self.file, *args]), 0)
        return buf.getvalue()

    def add(self, tokens=1000, owner=5, addons="LayerSwap", skill="update-translations", **kw):
        args = ["add", "--skill", skill, "--addons", addons, "--tokens", str(tokens), "--agents", "2",
                "--wall", "12.5", "--owner", str(owner), "--caught", "1", "--date", "2026-11-18"]
        for k, v in kw.items():
            args += ["--" + k, str(v)]
        return self.run_cli(*args)

    def test_add_writes_a_row_with_a_header(self):
        self.assertIn("run 1 added", self.add(note="tab\there"))
        with open(self.file, encoding="utf-8") as f:
            lines = f.read().splitlines()
        self.assertEqual(lines[0].split("\t"), ledger.COLS)
        row = ledger.load(self.file)[0]
        self.assertEqual((row["tokens"], row["wall_min"], row["game_bugs"], row["note"]), (1000, 12.5, 0, "tab here"))

    def test_bug_goes_to_the_newest_run_of_that_addon(self):
        self.add(addons="Attune")
        self.add(addons="LayerSwap,Attune")
        self.add(addons="OpenMap")
        out = self.run_cli("bug", "attune", "--note", "box in the title")
        self.assertIn("run 2", out)
        rows = ledger.load(self.file)
        self.assertEqual([r["game_bugs"] for r in rows], [0, 1, 0])
        self.assertIn("bug: box in the title", rows[1]["note"])
        self.run_cli("bug", "x", "--run", "1", "--count", "2")
        self.assertEqual(ledger.load(self.file)[0]["game_bugs"], 2)

    def test_bug_with_no_matching_run_fails(self):
        self.add()
        with self.assertRaises(SystemExit):
            self.run_cli("bug", "Questie")
        with self.assertRaises(SystemExit):
            self.run_cli("bug", "x", "--run", "9")

    def test_review_reminder_after_five_runs_and_reset_by_a_review(self):
        for _ in range(4):
            self.assertNotIn("Review due", self.add())
        self.assertIn("Review due: 5 runs", self.add())
        self.assertIn("Review due", self.run_cli("summary"))
        self.assertNotIn("Review due", self.add(skill="translations-review"))
        self.assertIn("Review not due (0 of 5", self.run_cli("summary"))

    def test_summary_trend_ignores_zero_token_runs(self):
        for t in (1000, 0, 1000, 0, 3000, 3000):
            self.add(tokens=t)
        rows = ledger.load(self.file)
        for r in rows:
            r["raw_tokens"] = r["tokens"] * 5   # measured rows
        ledger.save(self.file, rows)
        out = self.run_cli("summary")
        self.assertIn("6 runs (2 with 0 tokens); tokens per measured run rising (1000 -> 3000)", out)
        self.assertIn("game bugs: 0 in all", out)

    def test_summary_keeps_estimates_out_of_trend(self):
        for t in (900000, 900000, 900000, 900000):   # old hand estimates
            self.add(tokens=t)
        rows = ledger.load(self.file)
        for t in (30000000, 31000000, 32000000, 33000000):
            self.add(tokens=t)
        rows = ledger.load(self.file)
        for r in rows[4:]:
            r["raw_tokens"] = r["tokens"] * 6
        ledger.save(self.file, rows)
        out = self.run_cli("summary")
        self.assertIn("4 of 8 rows have estimated tokens", out)
        self.assertIn("4 measured rows", out)
        self.assertIn("flat (30500000 -> 32500000)", out)
        self.assertNotIn("900000 ->", out)

    def test_empty_ledger(self):
        self.assertIn("ledger empty", self.run_cli("summary"))


class FromLogs(unittest.TestCase):
    """Costs read from a fake log folder written here: a lead file and two subagent files."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.logs = os.path.join(self.tmp.name, "proj")
        self.file = os.path.join(self.tmp.name, "ledger.tsv")
        sub = os.path.join(self.logs, "sess1", "subagents")
        os.makedirs(sub)

        def line(t, mid, i, o, cc, cr, kind="assistant"):
            m = {"id": mid, "model": "x", "content": "SECRET TEXT",
                 "usage": {"input_tokens": i, "output_tokens": o,
                           "cache_creation_input_tokens": cc, "cache_read_input_tokens": cr}}
            return json.dumps({"type": kind, "timestamp": t, "message": m})

        def put(p, lines):
            with open(p, "w", encoding="utf-8") as f:
                f.write("\n".join(lines) + "\n")
        put(os.path.join(self.logs, "sess1.jsonl"), [
            line("2026-11-23T08:00:00.000Z", "a", 1, 10, 100, 1000),
            line("2026-11-23T08:00:01.000Z", "a", 1, 20, 100, 1000),      # same id again: counted once, max
            line("2026-11-23T09:00:00.000Z", "b", 2, 5, 0, 500),
            line("2026-11-22T08:00:00.000Z", "old", 999, 999, 999, 999),  # before the window
            "not json"])
        put(os.path.join(sub, "agent-1.jsonl"), [line("2026-11-23T08:30:00.000Z", "c", 3, 7, 10, 100)])
        put(os.path.join(sub, "agent-2.jsonl"), [line("2026-11-21T08:30:00.000Z", "d", 5, 5, 5, 5)])

    def tearDown(self):
        self.tmp.cleanup()

    def cli(self, *args):
        buf = io.StringIO()
        os.environ["UADD_LOGS"] = self.logs
        try:
            with contextlib.redirect_stdout(buf):
                ledger.main(["--file", self.file, "add", "--skill", "s", *args])
        finally:
            del os.environ["UADD_LOGS"]
        return buf.getvalue()

    def test_sums_dedupes_and_counts(self):
        g = ledger.from_logs("2026-11-23T00:00", dirs=[self.logs])
        # a: 1+20+100+1000, b: 2+5+0+500, c: 3+7+10+100
        self.assertEqual(g["parts"], [6, 32, 110, 1600])
        self.assertEqual(g["tokens"], 6 + 32 + 110 + 160)
        self.assertEqual(g["raw_tokens"], 6 + 32 + 110 + 1600)
        self.assertEqual(g["agents"], 1)       # agent-2 has nothing in the window
        self.assertEqual(g["wall"], 60.0)

    def test_dry_run_writes_nothing_and_hand_value_wins(self):
        out = self.cli("--since", "2026-11-23T00:00", "--tokens", "42", "--dry-run")
        self.assertIn("tokens 308", out)
        self.assertIn("dry run", out)
        self.assertFalse(os.path.exists(self.file))
        self.cli("--since", "2026-11-23T00:00", "--tokens", "42", "--date", "2026-11-23")
        row = ledger.load(self.file)[0]
        self.assertEqual((row["tokens"], row["agents"], row["wall_min"]), (42, 1, 60.0))

    def test_old_rows_and_summary_still_work(self):
        with open(self.file, "w", encoding="utf-8") as f:
            f.write("\t".join(ledger.COLS[:-1]) + "\n2026-11-19\tx\tA\t1000\t2\t5\t1\t0\t0\tn\n")
        self.assertEqual(ledger.load(self.file)[0]["raw_tokens"], 0)
        self.assertIn("1000", "\n".join(ledger.summary(self.file)))

    def test_no_message_text_printed(self):
        self.assertNotIn("SECRET", self.cli("--since", "2026-11-23T00:00", "--dry-run"))


if __name__ == "__main__":
    unittest.main()
