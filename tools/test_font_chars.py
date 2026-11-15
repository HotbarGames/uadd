"""Fails when a string we ship has a character the game's fonts may not draw.

Allowed: ASCII, the Cyrillic letters U+0400-U+045F (Ѐ to џ) plus Ґ and ґ, and the punctuation
’ « » — … №. Anything else can show as a box in one of the game's fonts. This reads every string
literal in the .lua files each addon's TOC loads (every .toc in the repo, so a new addon is checked
as soon as it has one: our code, the glossaries, Questie's menu strings) as it is written in the
file, and each TOC's Title and Notes lines. Byte escapes such as "\\226\\128\\148" are left out:
they are byte patterns for matching, not text to show.

The same rule is checked at run time on the tracker and on the names we pass to QuestieDB
(tools/harness/flow_original.py).

python3 -m unittest discover -s tools
python3 tools/test_font_chars.py          (lists every bad string: file:line: text)
"""
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import luatok  # noqa: E402
from test_ukrainian_letters import shipped_lua, tocs  # noqa: E402

# № is in the Cyrillic code page (UALL Forever item names use it).
PUNCTUATION = "’«»—…№"
ALLOWED = re.compile("[\t\n\x20-\x7eЀ-џҐґ" + PUNCTUATION + "]*")
# \ddd byte escapes (after an even number of backslashes): dropped before reading the strings.
BYTE_ESCAPE = re.compile(r"(?<!\\)((?:\\\\)*)\\\d{1,3}")
# A TOC line the game shows: "## Title: ...", "## Notes-ukUA: ...".
TOC_SHOWN = re.compile(r"##\s*(Title|Notes)(-\w+)?\s*:(.*)", re.IGNORECASE)


def bad_strings():
    """[(path, line, text)] for every string literal or TOC Title/Notes with a character outside ALLOWED."""
    found = []
    for toc in tocs():
        with open(os.path.join(REPO, toc), encoding="utf-8-sig", errors="replace") as f:
            for n, line in enumerate(f, 1):
                m = TOC_SHOWN.match(line.strip())
                if m and not ALLOWED.fullmatch(m.group(3).strip()):
                    found.append((toc, n, m.group(3).strip()))
    for path in shipped_lua():
        full = os.path.join(REPO, path)
        if not os.path.isfile(full):
            continue
        text = BYTE_ESCAPE.sub(r"\1", luatok.read(full))
        for kind, value, line in luatok.tokens(text):
            if kind == luatok.STR and not ALLOWED.fullmatch(value):
                found.append((path, line, value))
    return found


def bad_chars(found):
    """{character: count} of the characters outside ALLOWED in found."""
    out = {}
    for _, _, value in found:
        for ch in value:
            if not ALLOWED.fullmatch(ch):
                out[ch] = out.get(ch, 0) + 1
    return out


class FontChars(unittest.TestCase):
    def test_every_shipped_string_is_drawable(self):
        bad = bad_strings()
        chars = ", ".join(f"U+{ord(ch):04X} {ch!r} x{n}" for ch, n in sorted(bad_chars(bad).items()))
        detail = "; ".join(f"{p}:{n}: {v!r}" for p, n, v in bad[:5])
        self.assertEqual(bad, [], f"{len(bad)} strings the font may not draw ({chars}): {detail}")

    def test_the_rule(self):
        for ok in ("Підземелля", "«Ґ» — так…", "|cff00ff00[34D]|r", "Ї’жак №3", "Ѐџ ґ"):
            self.assertTrue(ALLOWED.fullmatch(ok), ok)
        for bad in ("�", "☐", "D\u0080", "ʼ", "中", "Ü", "–", "“", "•", "Ѡ", "Ӏ", "\xa0"):
            self.assertFalse(ALLOWED.fullmatch(bad), repr(bad))
        self.assertEqual(BYTE_ESCAPE.sub(r"\1", r'"\226\128\148" "\\123"'), r'"" "\\123"')

    def test_every_toc_is_read(self):
        found = tocs()
        self.assertIn("UADD/UADD.toc", found)
        self.assertIn("UADD_Questie/UADD_Questie.toc", found)
        self.assertTrue(TOC_SHOWN.match("## Title: UADD").group(3).strip() == "UADD")
        self.assertTrue(TOC_SHOWN.match("## Notes-ukUA: Так").group(3).strip() == "Так")


def main():
    bad = bad_strings()
    for path, line, value in bad:
        print(f"{path}:{line}: {value!r}")
    for ch, n in sorted(bad_chars(bad).items()):
        print(f"U+{ord(ch):04X} {ch!r}: {n}")


if __name__ == "__main__":
    main()
