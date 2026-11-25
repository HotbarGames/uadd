"""docs/LESSONS-INDEX.md against docs/LESSONS*.md: one line per lesson and no extra one, a "+" where a lesson has
"Lesson N again" cases, and under 9,000 characters (it loads in every session)."""
import re
import unittest
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent / "docs"
LIMIT = 9000


def problems(index, lessons):
    """What is wrong with the index text, as a list of strings."""
    lines = re.findall(r"^- (\d+)(\*?)(\+?) [APN] ", index, re.M)
    have = [int(n) for n, _, _ in lines]
    want = [int(n) for n in re.findall(r"^## (\d+)\. ", lessons, re.M)]
    again = {int(n) for n in re.findall(r"\bLesson (\d+) again", lessons)}
    out = [f"lesson {n}: no line in the index" for n in want if n not in have]
    out += [f"index line {n}: no such lesson" for n in have if n not in want]
    out += [f"index line {n}: twice" for n in sorted(set(have)) if have.count(n) > 1]
    out += [f"index line {n}: the '+' does not match the 'Lesson {n} again' cases"
            for n, _, p in lines if bool(p) != (int(n) in again)]
    if len(index) >= LIMIT:
        out.append(f"the index has {len(index)} characters (limit {LIMIT}): shorten lines")
    return out


class LessonsIndex(unittest.TestCase):
    def setUp(self):
        self.index = (DOCS / "LESSONS-INDEX.md").read_text(encoding="utf-8")
        files = [p for p in sorted(DOCS.glob("LESSONS*.md")) if p.name != "LESSONS-INDEX.md"]
        self.lessons = "\n".join(p.read_text(encoding="utf-8") for p in files)

    def test_index_matches_the_lessons(self):
        self.assertEqual(problems(self.index, self.lessons), [])

    def test_it_finds_faults(self):
        line = next(x for x in self.index.split("\n") if x.startswith("- 2* "))
        for bad in (self.index.replace(line + "\n", ""), self.index + line + "\n", self.index + "- 999 N x\n",
                    self.index.replace("- 2* ", "- 2*+ "), self.index + "x" * LIMIT):
            self.assertNotEqual(problems(bad, self.lessons), [])


if __name__ == "__main__":
    unittest.main()
