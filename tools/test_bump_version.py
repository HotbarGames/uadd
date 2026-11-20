"""Tests for tools/bump_version.py (on a made-up repo in a temp folder)."""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bump_version  # noqa: E402


def make(root, log=b"# Changelog\r\n\r\n## Unreleased\r\n\r\n- new\r\n\r\n## 1.0.0\r\n"):
    (root / "UADD").mkdir()
    (root / "UADD" / "UADD.toc").write_bytes(b"## Interface: 11508\r\n## Version: 1.0.0\r\n")
    (root / "UADD" / "CHANGELOG.md").write_bytes(log)
    (root / "UADD_A").mkdir()
    (root / "UADD_A" / "UADD_A.toc").write_bytes(b"## Title: A\n## Version: 1.0.0\n## Notes: x\n")


class BumpVersion(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_sets_tocs_and_names_section_keeping_line_ends(self):
        make(self.root)
        changes = dict(bump_version.plan(self.root, "1.2.0"))
        self.assertEqual(changes[self.root / "UADD" / "UADD.toc"], b"## Interface: 11508\r\n## Version: 1.2.0\r\n")
        self.assertEqual(changes[self.root / "UADD_A" / "UADD_A.toc"], b"## Title: A\n## Version: 1.2.0\n## Notes: x\n")
        log = changes[self.root / "UADD" / "CHANGELOG.md"]
        self.assertIn(b"\r\n## 1.2.0\r\n", log)
        self.assertNotIn(b"Unreleased", log)
        self.assertIn(b"## 1.0.0\r\n", log)

    def test_refuses_without_unreleased_or_bad_version(self):
        make(self.root, log=b"# Changelog\n\n## 1.0.0\n")
        with self.assertRaises(ValueError):
            bump_version.plan(self.root, "1.2.0")
        with self.assertRaises(ValueError):
            bump_version.plan(self.root, "1.2")

    def test_refuses_a_version_already_in_the_changelog(self):
        make(self.root, log=b"## Unreleased\n\n## 1.2.0\n")
        with self.assertRaises(ValueError):
            bump_version.plan(self.root, "1.2.0")


if __name__ == "__main__":
    unittest.main()
