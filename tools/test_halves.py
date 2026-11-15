"""The half-translation check covers every module, and its free-slot marks point to real slots.

A half translation is a template that matched while a slot kept English ("Рівень card theme").
tools/harness/halves.py fills each slot with made-up English and runs the text through the module
(the harness runs it: tools/harness/run.py). This test makes sure that check cannot quietly miss a module:
- every UADD_* folder is in halves_cover.COVERED or in NO_SLOTS (with a reason), not both;
- each covered module's flow file calls its halves_mods.py function (a real call, not a comment), and
  that function exists; run.py fails a covered module whose flow gave no result;
- every free-slot mark is a %s slot of a real template (read from the installed addon; skipped without it);
- the check itself catches a made-up module that keeps English in a slot, and passes a strict one;
  a template that does not fit fails unless UNFIT lists it, and a stale UNFIT entry fails; a path that
  is slow on a long or tricky text fails.

python3 -m unittest tools.test_halves
"""
import ast
import re
import sys
import time
import unittest
from collections import namedtuple
from unittest import mock
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "harness"))
import halves_cover as C  # noqa: E402
import halves  # noqa: E402


class Coverage(unittest.TestCase):
    def test_every_module_listed(self):
        mods = {p.name for p in C.REPO.iterdir() if p.is_dir() and p.name.startswith("UADD_")}
        self.assertFalse(set(C.COVERED) & set(C.NO_SLOTS), "a module is both covered and listed as no slots")
        self.assertEqual(mods, set(C.COVERED) | set(C.NO_SLOTS),
                         "add a new module to halves_cover.COVERED (with a halves_mods.py function) or NO_SLOTS")
        for mod, why in C.NO_SLOTS.items():
            self.assertGreater(len(why), 20, f"{mod}: say why it fills no slots")

    def test_flows_call_the_check(self):
        mods = (HERE / "harness" / "halves_mods.py").read_text(encoding="utf-8")
        for mod, (flow, fn) in C.COVERED.items():
            with self.subTest(mod):
                self.assertIn(f"\ndef {fn}(", mods)
                tree = ast.parse((HERE / "harness" / flow).read_text(encoding="utf-8"))
                calls = [n for n in ast.walk(tree) if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)
                         and n.func.attr == fn and isinstance(n.func.value, ast.Name)
                         and n.func.value.id == "halves_mods"]
                self.assertTrue(calls, f"{flow} does not call halves_mods.{fn}(...)")
                self.assertIn(f'run(check, "{mod}"', mods)

    def test_run_fails_a_missing_result(self):
        try:
            import run
        except ImportError as e:
            self.skipTest(f"run.py needs {e}")
        Check = namedtuple("Check", "name ok detail")
        done = [Check(f"x: no half-translated line: {m} (1 templates)", True, "") for m in C.COVERED]
        first = next(iter(C.COVERED))
        self.assertEqual(run.halves_guard(done), [])
        self.assertEqual([n for n, _ in run.halves_guard(done[1:])], [f"half-translation check ran: {first}"])
        self.assertEqual(run.halves_guard(done[1:], [first]), [])

    def test_unfit_reasons(self):
        for mod, known in C.UNFIT.items():
            self.assertIn(mod, C.COVERED)
            for i, why in known.items():
                self.assertGreater(len(why), 20, f"{mod} {i}: say why it stays English")

    def test_marks_point_to_slots(self):
        for mod, (bad, note) in C.marks().items():
            with self.subTest(mod):
                if note:
                    self.skipTest(f"{mod}: {note}")
                self.assertEqual(bad, [], f"{mod}: free-slot marks that are no %s slot of a real template")

    def test_mark_readers(self):
        self.assertGreater(len(C.auc_free()), 5)
        self.assertGreater(len(C.dui_slots()), 5)
        self.assertGreater(len(C.openmap_free()), 5)
        kind, by, free = C.att_marks()
        self.assertTrue(kind and by and free)


class Engine(unittest.TestCase):
    """On made-up templates and made-up modules."""
    TPLS = [halves.tpl("a", "Zap the %s now"), halves.tpl("b", "Sent %d blorps to %s", {2: "Quix"}),
            halves.tpl("c", "From %s to %s")]
    UK = {"Zap the ": "Зап ", " now": " зараз", "Sent ": "Надіслано ", " blorps to ": " блорпів до ",
          "From ": "Від ", " to ": " до "}

    def _run(self, translate):
        got = []
        halves.run(lambda name, ok, detail="": got.append((name, ok, detail)), "UADD_Questie", self.TPLS, translate)
        self.assertEqual(len(got), 1)
        return got[0]

    def _loose(self, tp, t, ok=lambda v: True):
        m = re.match("^" + re.escape(tp["en"]).replace("%s", "(.+)").replace("%d", r"(\d+)") + "$", t)
        if not m or not all(ok(v) for v in m.groups()):
            return None
        out, k = [], 0
        for piece in re.split(r"(%[sd])", tp["en"]):
            if piece in ("%s", "%d"):
                k += 1
                out.append(m.group(k))
            else:
                out.append(self.UK.get(piece, piece))
        return "".join(out)

    def test_half_found(self):
        name, ok, detail = self._run(self._loose)
        self.assertFalse(ok)
        self.assertIn("Зап wobbly gizmo зараз", str(detail))

    def test_strict_passes(self):
        def strict(tp, t):
            return self._loose(tp, t, lambda v: v.isdigit() or v == "Quix")
        name, ok, detail = self._run(strict)
        self.assertTrue(ok, detail)
        self.assertIn("2 templates", name)          # "b" has no slot that is not free

    def test_nothing_fits_fails(self):
        self.assertFalse(self._run(lambda tp, t: None)[1])

    def _strict(self, tp, t):
        return self._loose(tp, t, lambda v: v.isdigit() or v == "Quix")

    def _strict_but_c(self, tp, t):
        return None if tp["id"] == "c" else self._strict(tp, t)

    def test_one_unfit_fails(self):
        name, ok, detail = self._run(self._strict_but_c)
        self.assertFalse(ok)
        self.assertIn("'c'", str(detail))

    def test_known_unfit_passes(self):
        with mock.patch.dict(C.UNFIT, {"UADD_Questie": {"c": "a made-up reason, long enough"}}):
            name, ok, detail = self._run(self._strict_but_c)
        self.assertTrue(ok, detail)
        self.assertIn("1 unfit", name)

    def test_stale_unfit_fails(self):
        for known in ({"c": "it fits now, so this entry is stale"}, {"zz": "no such template any more"}):
            with mock.patch.dict(C.UNFIT, {"UADD_Questie": known}):
                name, ok, detail = self._run(self._strict)
            self.assertFalse(ok, known)
            self.assertIn("stale", str(detail))

    def test_fit_is_a_change(self):
        """A translation with no Ukrainian letters ("7 — 7") still fits: the text changed."""
        got = []
        halves.run(lambda n, ok, d="": got.append(ok), "UADD_Questie", [halves.tpl("e", "%s in %s")],
                   lambda tp, t: "7 — 7" if t == "7 in 7" else None)
        self.assertEqual(got, [True])

    def test_slow_fails(self):
        """A path that takes long on a long text (a shared note: it would freeze the game) fails."""
        def slow(tp, t):
            if len(t) > 150:
                time.sleep(2 * halves.BOUND)
            return self._strict(tp, t)
        name, ok, detail = self._run(slow)
        self.assertFalse(ok)
        self.assertIn("too slow", str(detail))
        self.assertTrue(self._run(self._strict)[1])

    def test_fill(self):
        self.assertEqual(halves.fill("%d%% of %s", lambda k, kind: f"<{k}{kind}>"), "<1d>% of <2s>")
        self.assertEqual(len(halves.texts(self.TPLS[2])), len(halves.FILLERS) * 3)
        self.assertEqual(halves.texts(halves.tpl("d", "Only %s", {1: "Quix"})), [])


if __name__ == "__main__":
    unittest.main()
