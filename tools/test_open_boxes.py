"""No release while a case of boxes is open (docs/OPEN-BOXES.md, the owner's rule of 2026-11-26)."""
import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bump_version  # noqa: E402
import make_zip  # noqa: E402
import open_boxes  # noqa: E402


class OpenBoxes(unittest.TestCase):
    def write(self, text):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        p = Path(d.name) / "OPEN-BOXES.md"
        p.write_text(text, encoding="utf-8")
        return p

    def test_open_case_stops(self):
        for item in ("- OPEN 2026-11-26 X: boxes", "* open y", "  - opne typo", "- fixed, not looked at"):
            self.assertIn("no release", open_boxes.stop(self.write(f"# T\n- a rule\n\n## Cases\n\n{item}\n")))

    def test_empty_list_lets_through(self):
        self.assertIsNone(open_boxes.stop(self.write("# T\n- a rule\n\n## Cases\n\nNone.\n")))

    def test_broken_list_stops(self):
        self.assertIn("no release", open_boxes.stop(self.write("# T\n")))
        self.assertIn("no release", open_boxes.stop(Path("nowhere/OPEN-BOXES.md")))

    def test_the_real_list_reads(self):
        open_boxes.cases()

    def test_release_tools_refuse(self):
        with mock.patch.object(open_boxes, "stop", return_value="no release: test"):
            with mock.patch.object(make_zip.zipfile, "ZipFile") as z:
                with self.assertRaises(SystemExit) as e:
                    make_zip.main()
                self.assertIn("no release: test", str(e.exception))
                z.assert_not_called()
            with mock.patch.object(bump_version, "plan") as plan, redirect_stdout(io.StringIO()):
                self.assertEqual(bump_version.main(["bump_version.py", "9.9.9"]), 1)
                plan.assert_not_called()

    def test_release_workflow_asks_too(self):
        wf = open_boxes.LIST.parent.parent / ".github" / "workflows" / "release.yml"
        self.assertIn("tools/open_boxes.py", wf.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
