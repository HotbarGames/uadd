"""Checks tools/drift.py on two made-up addons (a DialogueUI with a keyed enUS table, a ForeverXP Bar with texts
in code), so no game folder and no real English are needed:

- no drift: "no drift", exit 0;
- a keyed text whose English changed, a new key, a gone key; a code text that changed a little (paired by
  difflib), a new one and a gone one: exit 1, the counts, and the details file;
- an addon that is not installed: a note, exit 0; a new .lua file: drift;
- no local/drift/base.json (a fresh clone): gone is a count only, and the output says so;
- texts not all read (an extractor fails, or finds none where the record has some): a note and exit 1;
  --update-versions refuses (exit 2) and leaves the record as it was;
- the cache stamp follows the UALLF files (DungeonJournal only) and lupa; what drift.py cannot see is printed
  and in --help;
- tools/addon_versions.json covers every UADD_* module that has addon data, holds hashes only, is small, and
  has a version for each (lesson 11).

python3 -m unittest tools.test_drift
"""
import contextlib
import io
import json
import re
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import drift  # noqa: E402
import drift_sources  # noqa: E402

DUI = {"ZORP_ONE": "Zorp the glimmer", "ZORP_TWO": "Polish %s brass knobs", "ZORP_SIX": "Sing to the kettle"}
FXPB = ["Wobble the purple gizmo now", "Fold the paper crane twice", "Count the %d jellybeans"]


def write_dui(root, texts, version="1.0"):
    d = root / "DialogueUI"
    (d / "Locales").mkdir(parents=True, exist_ok=True)
    (d / "DialogueUI.toc").write_text(f"## Interface: 11509\n## Version: {version}\n", encoding="utf-8")
    (d / "Locales" / "enUS.lua").write_text("".join(f'L["{k}"] = "{v}";\n' for k, v in texts.items()),
                                            encoding="utf-8")


def write_fxpb(root, texts):
    d = root / "ForeverXPbar"
    d.mkdir(parents=True, exist_ok=True)
    (d / "ForeverXPBar.toc").write_text("## Interface: 11509\n## Version: 0.1\n", encoding="utf-8")
    (d / "ForeverXPBar.lua").write_text("".join(f'label:SetText("{t}")\n' for t in texts), encoding="utf-8")


class Drift(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addons, self.out = self.tmp / "AddOns", self.tmp / "out"
        self.versions = self.tmp / "versions.json"
        write_dui(self.addons, DUI)
        write_fxpb(self.addons, FXPB)
        self.assertEqual(self.run_drift("--update-versions")[0], 0)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def run_drift(self, *args):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = drift.main(["--addons", str(self.addons), "--versions", str(self.versions),
                               "--out", str(self.out), "--no-cache", *args])
        return code, buf.getvalue()

    def report(self):
        code, text = self.run_drift("--json")
        return code, json.loads(text)

    def test_no_drift(self):
        code, text = self.run_drift()
        self.assertEqual(code, 0)
        self.assertIn("no drift", text.splitlines())
        self.assertIn("What drift.py cannot see:", text)
        self.assertNotIn("Zorp", self.versions.read_text(encoding="utf-8"))

    def test_new_gone_changed(self):
        write_dui(self.addons, {"ZORP_ONE": "Zorp the shimmer", "ZORP_TWO": DUI["ZORP_TWO"],
                                "ZORP_TEN": "Feed the %s robots"}, version="1.1")
        write_fxpb(self.addons, ["Wobble the purple gizmos now", FXPB[2], "Quack loudly at the dawn"])
        code, rep = self.report()
        self.assertEqual(code, 1)
        dui, fx = rep["modules"]["UADD_DialogueUI"], rep["modules"]["UADD_ForeverXPBar"]
        self.assertEqual((dui["old"], dui["new"]), ("1.0", "1.1"))
        self.assertEqual([r[2] for r in dui["newTexts"]], ["Feed the %s robots"])
        self.assertEqual([o[2] for _, o in dui["goneTexts"]], ["Sing to the kettle"])
        self.assertEqual([(o[2], n[2], r) for o, n, r in dui["changedTexts"]],
                         [("Zorp the glimmer", "Zorp the shimmer", None)])
        self.assertEqual([r[2] for r in fx["newTexts"]], ["Quack loudly at the dawn"])
        self.assertEqual([o[2] for _, o in fx["goneTexts"]], ["Fold the paper crane twice"])
        (o, n, ratio), = fx["changedTexts"]
        self.assertEqual((o[2], n[2]), (FXPB[0], "Wobble the purple gizmos now"))
        self.assertGreaterEqual(ratio, drift.RATIO)
        details = (self.out / "UADD_DialogueUI.txt").read_text(encoding="utf-8")
        self.assertIn("== new L", details)
        self.assertIn("slots: %s", details)
        code, text = self.run_drift()
        self.assertIn("UADD_DialogueUI: DialogueUI 1.0 -> 1.1: 1 new, 1 gone, 1 changed", text)
        self.assertNotIn("no drift", text)

    def test_gone_without_local_english(self):
        (self.out / "base.json").unlink()
        write_fxpb(self.addons, FXPB[:2])
        code, rep = self.report()
        self.assertEqual(code, 1)
        fx = rep["modules"]["UADD_ForeverXPBar"]
        self.assertEqual((fx["goneCount"], fx["goneTexts"], fx["exact"]), (1, [], False))
        self.assertNotIn("UADD_DialogueUI", rep["modules"])        # same ids: no base.json needed
        code, text = self.run_drift()
        self.assertEqual(code, 1)
        self.assertIn("1 gone (at least; count only)", text)
        self.assertIn("does not hold the record", text)
        self.assertIn("count only", (self.out / "UADD_ForeverXPBar.txt").read_text(encoding="utf-8"))

    def test_not_installed(self):
        shutil.rmtree(self.addons / "DialogueUI")
        code, text = self.run_drift()
        self.assertEqual(code, 0)
        self.assertIn("UADD_DialogueUI: DialogueUI not installed: not checked", text)
        self.assertIn("no drift", text.splitlines())

    def test_version_only(self):
        write_dui(self.addons, DUI, version="2.0")
        code, text = self.run_drift()
        self.assertEqual(code, 0)
        self.assertIn("version 1.0 -> 2.0, same texts", text)

    def test_new_file(self):
        (self.addons / "DialogueUI" / "Extra.lua").write_text("local x = 1\n", encoding="utf-8")
        code, rep = self.report()
        self.assertEqual(code, 1)
        self.assertEqual(rep["modules"]["UADD_DialogueUI"]["newFiles"], ["Extra.lua"])

    def with_extractor(self, fn):
        old = drift.MODULES["UADD_DialogueUI"]
        return mock.patch.dict(drift.MODULES, {"UADD_DialogueUI": (old[0], fn, *old[2:])})

    def test_failed_extractor(self):
        def boom(folder):
            raise RuntimeError("no lupa")
        before = self.versions.read_bytes()
        for fn, why in ((boom, "texts not read: RuntimeError: no lupa"), (lambda folder: [], "no texts found")):
            with self.with_extractor(fn):
                code, text = self.run_drift("--update-versions")
                self.assertEqual(code, 2)
                self.assertIn(why, text)
                self.assertIn("not recorded", text)
                self.assertEqual(self.versions.read_bytes(), before)
                code, text = self.run_drift()
                self.assertEqual(code, 1)
                self.assertIn("UADD_DialogueUI: " + why, text)
                self.assertNotIn("no drift", text.splitlines())

    def test_stamp(self):
        uallf = self.addons / "UALLF"
        uallf.mkdir()
        (uallf / "World.lua").write_text("a\n", encoding="utf-8")
        dj = drift_sources.tools_stamp("UADD_DungeonJournal", self.addons)
        dui = drift_sources.tools_stamp("UADD_DialogueUI", self.addons)
        (uallf / "World.lua").write_text("a longer file\n", encoding="utf-8")
        self.assertNotEqual(drift_sources.tools_stamp("UADD_DungeonJournal", self.addons), dj)
        self.assertEqual(drift_sources.tools_stamp("UADD_DialogueUI", self.addons), dui)
        with mock.patch.object(drift_sources, "lupa_state", lambda: "no lupa?"):
            self.assertNotEqual(drift_sources.tools_stamp("UADD_DialogueUI", self.addons), dui)

    def test_help_says_what_it_cannot_see(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf), self.assertRaises(SystemExit):
            drift.main(["--help"])
        self.assertIn("What drift.py cannot see:", buf.getvalue())
        self.assertIn("lupa", buf.getvalue())


class Coverage(unittest.TestCase):
    def test_every_module(self):
        dirs = {p.name for p in drift.REPO.glob("UADD_*") if p.is_dir()}
        recorded = json.loads(drift.VERSIONS.read_text(encoding="utf-8"))["modules"]
        self.assertEqual(set(drift.MODULES), dirs)
        self.assertEqual(set(recorded), dirs)

    def test_hashes_only(self):
        recorded = json.loads(drift.VERSIONS.read_text(encoding="utf-8"))["modules"]
        self.assertLess(drift.VERSIONS.stat().st_size, 80000)      # file names are most of it
        for mod, rec in recorded.items():
            self.assertNotIn("texts", rec, mod)
            self.assertRegex(rec["ids"], r"^[0-9a-f]{40}$", mod)
            self.assertIsInstance(rec["count"], int, mod)
            self.assertEqual(sum(rec["tags"].values()), rec["count"], mod)
            self.assertTrue(all(re.fullmatch(r"[A-Z]", t) for t in rec["tags"]), mod)

    def test_every_version_recorded(self):
        # Lesson 11: a null version hides an addon update (BagBrother.toc has no Version: VERSION_FROM).
        recorded = json.loads(drift.VERSIONS.read_text(encoding="utf-8"))["modules"]
        for mod, rec in recorded.items():
            self.assertTrue(rec.get("version"), f"{mod}: no version recorded (see VERSION_FROM in drift_sources.py)")


if __name__ == "__main__":
    unittest.main()
