"""Fails when a string we ship uses a word we decided against.

BANNED maps a regex (case is ignored) to (the word to use instead, why). It reads every string literal
in the .lua files each addon's TOC loads (every .toc in the repo, so a new addon is checked as soon as it
has one), each TOC's Title and Notes lines, and the Dungeon Journal texts in tools/dj_prose/uk_*.lua.
Comments, docs/ and test files are not read. When we decide against a word, add it to BANNED and put
the right word in the glossary (UADD/glossary/*.lua, docs/GLOSSARY.md). See docs/LESSONS.md.

python3 -m unittest discover -s tools -p 'test_*.py'
python3 tools/test_banned_words.py          (lists every hit: file:line: text)
"""
import glob
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import luatok  # noqa: E402
from test_font_chars import TOC_SHOWN  # noqa: E402
from test_ukrainian_letters import shipped_lua, tocs  # noqa: E402

# regex: (use instead, reason)
BANNED = {
    r"інстанс": ("підземелля (у підземеллі, у підземеллях, поза підземеллям, портал підземелля)",
                 "«інстанс» is slang"),
}
RULES = [(re.compile(p, re.IGNORECASE), p) for p in BANNED]


def lua_files():
    """Repo-relative .lua files whose strings players can see."""
    prose = sorted(os.path.relpath(p, REPO).replace("\\", "/")
                   for p in glob.glob(os.path.join(REPO, "tools", "dj_prose", "uk_*.lua")))
    return shipped_lua() + [p for p in prose if p not in shipped_lua()]


def hits_in_text(path, text):
    """[(path, line, string, pattern)] for each banned word in the string literals of Lua source text."""
    found = []
    for kind, value, line in luatok.tokens(text):
        if kind == luatok.STR:
            found += [(path, line, value, p) for rx, p in RULES if rx.search(value)]
    return found


def hits():
    """Every banned word in what we ship: [(path, line, text, pattern)]."""
    found = []
    for toc in tocs():
        with open(os.path.join(REPO, toc), encoding="utf-8-sig", errors="replace") as f:
            for n, line in enumerate(f, 1):
                m = TOC_SHOWN.match(line.strip())
                if m:
                    found += [(toc, n, m.group(3).strip(), p) for rx, p in RULES if rx.search(m.group(3))]
    for path in lua_files():
        full = os.path.join(REPO, path)
        if os.path.isfile(full):
            found += hits_in_text(path, luatok.read(full))
    return found


class BannedWords(unittest.TestCase):
    def test_no_banned_word_is_shipped(self):
        bad = hits()
        detail = "\n".join(f"{p}:{n}: {v!r} -> use {BANNED[pat][0]}" for p, n, v, pat in bad[:20])
        self.assertEqual(bad, [], f"{len(bad)} banned words in shipped strings:\n{detail}")

    def test_a_banned_word_is_caught(self):
        src = 'local a = "в інстансі"\n-- інстанс in a comment is fine\nlocal b = "ІНСТАНСАХ"\nlocal c = "підземелля"\n'
        found = hits_in_text("fake.lua", src)
        self.assertEqual([(n, v) for _, n, v, _ in found], [(1, "в інстансі"), (3, "ІНСТАНСАХ")])

    def test_every_file_is_read(self):
        files = lua_files()
        self.assertIn("tools/dj_prose/uk_1.lua", files)
        self.assertTrue(any(f.startswith("UADD/glossary/") for f in files), files[:5])
        self.assertTrue(any(f.startswith("UADD_Questie/") for f in files))


def main():
    for path, line, value, pat in hits():
        print(f"{path}:{line}: {value!r} -> use {BANNED[pat][0]}")


if __name__ == "__main__":
    main()
