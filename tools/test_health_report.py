"""tools/health_report.py: the guard's repairs from saved data reach the report, loudly, and odd data is safe."""
import contextlib
import io
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import health_report  # noqa: E402


def db(health):
    return {"UADD_DB": {"health": health}}


class HealthReport(unittest.TestCase):
    def run_report(self, *saved):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            n = health_report.report(*health_report.collect(saved))
        return n, out.getvalue()

    def test_guard_repairs_are_loud(self):
        n, text = self.run_report(db({"guard": {"tip": 106, "line": 2}}), db({"guard": {"tip": 4}}))
        self.assertEqual(n, 112)
        self.assertIn("GAME HEALTH", text)
        self.assertIn("guard tip = 110", text)

    def test_quiet_without_repairs(self):
        n, text = self.run_report(db({"guard": {"tip": 0}}), {}, {"UADD_DB": 5}, db("x"))
        self.assertEqual((n, text), (0, ""))

    def test_odd_counts_ignored(self):
        n, _ = self.run_report(db({"guard": {"a": -1, "b": True, "c": "9", "d": float("nan"), "e": {}}}))
        self.assertEqual(n, 0)

    def test_probe_printed(self):
        _, text = self.run_report(db({"probe": {"keepsFileOverObject": True, "build": 11507, "at": 1}}))
        self.assertIn("keepsFileOverObject=True", text)
        self.assertNotIn("at=", text)


if __name__ == "__main__":
    unittest.main()
