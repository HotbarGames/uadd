"""Runs our real addon files with the real Questie, QuestieDB and UALLF in the offline harness
(tools/harness), then the Dungeon Journal module with the real ForeverDungeonJournal (tools/harness/run.py).
Skips when lupa or the Forever AddOns folder is missing.

python3 -m unittest discover -s tools
"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))

import loader  # noqa: E402
import session  # noqa: E402

WHY_NOT = None
if loader.lua_runtime() is None:
    WHY_NOT = "lupa is not installed (pip install lupa)"
elif session.missing_addons():
    WHY_NOT = "addons not found in " + session.addons_dir() + ": " + ", ".join(session.missing_addons())


@unittest.skipIf(WHY_NOT, WHY_NOT or "")
class Flow(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import run
        cls.checks, cls.facts, _ = run.run_all()      # the main flow, then the Dungeon Journal module

    def test_every_check_passes(self):
        for c in self.checks:
            with self.subTest(c.name):
                self.assertTrue(c.ok, c.detail)

    def test_collection_finds_most_names(self):
        facts = self.facts
        for kind, total in facts["totals"].items():
            self.assertGreater(facts["counts"][kind], total // 2, kind)


if __name__ == "__main__":
    unittest.main()
