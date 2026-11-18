"""tools/ledger.py on a temporary ledger: add, bug, summary, the review reminder and the trend.

Run: python3 -m unittest tools.test_ledger
"""
import contextlib
import io
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
        out = self.run_cli("summary")
        self.assertIn("6 runs (2 with 0 tokens); tokens per working run rising (1000 -> 3000)", out)
        self.assertIn("game bugs: 0 in all", out)

    def test_empty_ledger(self):
        self.assertIn("ledger empty", self.run_cli("summary"))


if __name__ == "__main__":
    unittest.main()
