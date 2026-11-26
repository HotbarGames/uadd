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

    def test_last_newest_kept_and_shown(self):
        old = {"at": 1000, "version": "1.2.3", "sample": "OldFrame: a"}
        new = {"at": 1764144000, "version": "1.2.4", "sample": "LayerSwapPanel: Змінити лейер"}
        n, text = self.run_report(db({"guard": {"box": 2}, "guardLast": {"box": new}}),
                                  db({"guard": {"box": 1, "boxfail": 1}, "guardLast": {"box": old}}))
        self.assertEqual(n, 4)
        self.assertIn("guard box = 3: a text drew boxes", text)
        self.assertIn("guard boxfail = 1: a text drew boxes and nothing fixed it", text)
        self.assertIn("last: 2025-11-26 08:00 UTC, UADD 1.2.4, sample: LayerSwapPanel: Змінити лейер", text)
        self.assertNotIn("OldFrame", text)

    def test_older_version_quiet(self):
        saved = db({"guard": {"box": 5, "font": 1}, "guardLast": {"box": {"at": 9, "version": "1.2.3"},
                                                                 "font": {"at": 9, "version": "1.2.4"}}})
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            n = health_report.report(*health_report.collect([saved]), current="1.2.4")
        self.assertEqual(n, 1)
        self.assertIn("guard font = 1: UADD code changed", out.getvalue())
        self.assertIn("guard box = 5, last in UADD 1.2.3 (installed: 1.2.4): may be fixed", out.getvalue())
        with contextlib.redirect_stdout(io.StringIO()):          # no version known: every kind counts
            self.assertEqual(health_report.report(*health_report.collect([saved])), 6)

    def test_odd_last_safe(self):
        odd = {"a": 5, "b": {"at": -3, "version": 7, "sample": {}}, "c": {"at": float("nan"), "sample": "x\n|y" * 99},
               "d": {"at": "9", "version": "v\x00"}}
        guard, _, last = health_report.collect([db({"guard": {"a": 1, "c": 1, "zz": 1}, "guardLast": odd}),
                                                db({"guardLast": "x"})])
        self.assertEqual(sorted(last), ["c", "d"])
        self.assertEqual(last["c"]["at"], None)
        self.assertLessEqual(len(last["c"]["sample"]), health_report.SAMPLE)
        self.assertNotIn("\n", last["c"]["sample"])
        n, text = self.run_report(db({"guard": {"zz": 2}, "guardLast": odd}))
        self.assertEqual(n, 2)
        self.assertIn("guard zz = 2: a kind this tool does not know", text)

    def test_saved_file_parsed(self):
        import missed
        src = ('UADD_DB = {\n["health"] = {\n["guard"] = {\n["box"] = 1,\n},\n["guardLast"] = {\n["box"] = {\n'
               '["at"] = 1764144000,\n["version"] = "1.2.4",\n["sample"] = "Btn: \\"ой\\"",\n},\n},\n},\n}\n')
        guard, _, last = health_report.collect([missed.parse(src.encode("utf-8"))])
        self.assertEqual((guard, last["box"]["sample"]), ({"box": 1}, 'Btn: "ой"'))

    def test_installed_version(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            self.assertIsNone(health_report.installed_version(d))
            os.makedirs(os.path.join(d, "UADD"))
            with open(os.path.join(d, "UADD", "UADD.toc"), "w", encoding="utf-8") as f:
                f.write("﻿## Interface: 11507\n## Version: 1.2.4\n")
            self.assertEqual(health_report.installed_version(d), "1.2.4")
        self.assertIsNone(health_report.installed_version(None))

    def test_probe_printed(self):
        _, text = self.run_report(db({"probe": {"keepsFileOverObject": True, "build": 11507, "at": 1}}))
        self.assertIn("keepsFileOverObject=True", text)
        self.assertNotIn("at=", text)


if __name__ == "__main__":
    unittest.main()
