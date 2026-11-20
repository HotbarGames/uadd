"""Lesson 24: every module is named where players read about UADD.

README.md, the core TOC's Notes and docs/curseforge-description.md (pasted on CurseForge by hand) must name each
UADD_* module by its TOC Title, and must name nothing as "coming" that is already there.

python3 -m unittest tools.test_listing
"""
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import listing  # noqa: E402

REPO = listing.REPO
COMING = re.compile(r"coming next|coming soon|planned|згодом|незабаром|у планах", re.I)


def section(text, heading):
    """Lines under a '## heading' (or '# heading') up to the next heading of the same or higher level."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.strip().lstrip("#").strip() == heading:
            level = len(line) - len(line.lstrip("#"))
            out = []
            for rest in lines[i + 1:]:
                lv = len(rest) - len(rest.lstrip("#"))
                if rest.startswith("#") and lv <= level:
                    break
                out.append(rest)
            return "\n".join(out)
    raise AssertionError(f"no heading {heading!r}")


def bullets(text):
    """The name of each '- **Name**' or '- Name' bullet: up to ':' or the end."""
    names = []
    for line in text.splitlines():
        m = re.match(r"^- (?:\*\*(.+?)\*\*|([^:]+?))(?::.*)?$", line.strip())
        if m:
            names.append(m.group(1) or m.group(2))
    return names


class Listing(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.names = listing.module_names()
        cls.readme = (REPO / "README.md").read_text(encoding="utf-8")
        cls.desc = listing.DESCRIPTION.read_text(encoding="utf-8")
        en, _, uk = cls.desc.partition("\n# Українською")
        cls.en, cls.uk = en, uk

    def test_every_module_has_a_title(self):
        for folder, name in self.names.items():
            self.assertTrue(name, f"{folder}.toc has no '## Title: UADD - <name>' line")
        self.assertGreater(len(self.names), 0)

    def expect_list(self, where, got):
        want = sorted(self.names.values())
        self.assertEqual(sorted(got), want,
                         f"{where}: the module list must be exactly the TOC Titles (missing: "
                         f"{sorted(set(want) - set(got))}, extra: {sorted(set(got) - set(want))})")

    def test_readme_list(self):
        self.expect_list("README 'What it translates'", bullets(section(self.readme, "What it translates")))

    def test_readme_install_folders(self):
        install = section(self.readme, "Install")
        for folder in self.names:
            self.assertIn(f"`{folder}`", install, f"README 'Install' does not name the {folder} folder")

    def test_core_toc_notes(self):
        notes = re.search(r"^## Notes:(.*)$", (REPO / "UADD" / "UADD.toc").read_text(encoding="utf-8"), re.M).group(1)
        for name in self.names.values():
            self.assertIn(name, notes, f"UADD/UADD.toc Notes does not name {name}")

    def test_description_lists(self):
        self.assertTrue(self.uk, "docs/curseforge-description.md has no '# Українською' part")
        self.expect_list("description, English list", bullets(section(self.en, "What addons it translates")))
        self.expect_list("description, Ukrainian list", bullets(section(self.uk, "Які аддони перекладено")))

    def test_description_thanks(self):
        thanks = section(self.en, "Thanks")
        for name in self.names.values():
            self.assertRegex(thanks, rf"(?m)^- {re.escape(name)} by .+: https://www\.curseforge\.com/wow/addons/\S+$",
                             f"description 'Thanks' has no line for {name} (its authors and CurseForge page)")

    def test_nothing_named_as_coming(self):
        for where, text in (("README.md", self.readme), ("description", self.desc)):
            for line in text.splitlines():
                self.assertIsNone(COMING.search(line), f"{where}: a 'coming' line goes stale; drop it: {line}")

    def test_stamp_is_a_sha256(self):
        self.assertRegex(listing.pasted() or "", r"^[0-9a-f]{64}$",
                         "tools/cf_description.sha256 is missing: paste the description, then "
                         "python3 tools/listing.py --pasted")

    def test_bullets_parser(self):
        self.assertEqual(bullets("- **A b**\n- C: note\n  more\n- **D?**: x"), ["A b", "C", "D?"])
        self.assertEqual(section("# X\n## a\n1\n### b\n2\n## c\n3", "a"), "1\n### b\n2")


if __name__ == "__main__":
    unittest.main()
