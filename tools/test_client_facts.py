"""The harness's font model must match what the real client recorded (docs/LESSONS4.md, lesson 44).

UADD/Probe.lua records font facts once per session in the game (UADD_DB.health.probe); the owner only logs
in. Here each recorded fact must equal what the harness assumes (FACTS in tools/harness/client_facts.py).
With no probe recorded yet, that test skips with a message. Self-tests prove a probe that disagrees fails
and one that agrees passes. A harness test loads UADD, fires login, and wants the probe saved, no error.

python3 -m unittest tools.test_client_facts
"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.join(HERE, "harness")
sys.path.insert(0, HERE)
sys.path.insert(0, HARNESS)
import client_facts  # noqa: E402

AGREE = {name: assumed for name, (assumed, _note) in client_facts.FACTS.items()}
AGREE.update({"widthObject": 36, "widthFriz": 36, "widthCyr": 36, "build": 11508, "at": 1})


class RealClient(unittest.TestCase):
    def test_recorded_facts_match_the_harness(self):
        probe = client_facts.latest_probe()
        if probe is None:
            self.skipTest("no font probe in the game's SavedVariables yet: log in once with UADD on, then out")
        bad = client_facts.mismatches(probe)
        self.assertEqual(bad, [], "\n" + "\n".join(bad))


class SelfTest(unittest.TestCase):
    def test_agreeing_probe_passes(self):
        self.assertEqual(client_facts.mismatches(AGREE), [])

    def test_disagreeing_probe_fails(self):
        probe = dict(AGREE, keepsFileOverObject=not AGREE["keepsFileOverObject"])
        bad = client_facts.mismatches(probe)
        self.assertEqual(len(bad), 1)
        want = AGREE["keepsFileOverObject"]
        self.assertIn("the client says %r, the harness assumes %r: fix the harness model" % (not want, want), bad[0])

    def test_info_only_and_missing_facts_are_not_compared(self):
        probe = dict(AGREE, widthCyr=99)
        del probe["objectPath"]
        self.assertEqual(client_facts.mismatches(probe), [])

    def test_newest_probe_wins(self):
        import tempfile
        old = 'UADD_DB = { ["health"] = { ["probe"] = { ["at"] = 5, ["nilKeepsFile"] = false } } }\n'
        new = 'UADD_DB = { ["health"] = { ["probe"] = { ["at"] = 9, ["nilKeepsFile"] = true } } }\n'
        with tempfile.TemporaryDirectory() as d:
            paths = []
            for i, text in enumerate((new, old, "not lua {")):
                p = os.path.join(d, "UADD%d.lua" % i)
                with open(p, "w", encoding="utf-8") as f:
                    f.write(text)
                paths.append(p)
            self.assertEqual(client_facts.latest_probe(paths)["at"], 9)


class Harness(unittest.TestCase):
    def test_probe_runs_after_login_without_errors(self):
        try:
            import loader
            import session
        except ImportError as e:
            self.skipTest("harness not available: %s" % e)
        c = loader.Client([loader.Addon("UADD", os.path.join(session.REPO, "UADD"), session.FLAVOR)], None, "enUS")
        c.start()
        c.lua.execute("HARNESS.pump(200, function() return false end, 0.05)")    # 10 s after login
        probe = c.lua.eval("UADD_DB and UADD_DB.health and UADD_DB.health.probe")
        self.assertIsNotNone(probe, "UADD_DB.health.probe was not saved")
        facts = {k: probe[k] for k in probe}
        self.assertIn("at", facts)
        self.assertGreaterEqual(len([k for k in facts if k in client_facts.FACTS]), 8, facts)
        self.assertEqual(list(c.errors()), [])
        # the harness agrees with itself: its own probe matches FACTS
        self.assertEqual(client_facts.mismatches(facts), [], facts)


if __name__ == "__main__":
    unittest.main()
