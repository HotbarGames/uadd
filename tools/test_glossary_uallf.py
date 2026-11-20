"""A glossary game name says what UALL Forever (UALLF) says (docs/LESSONS2.md, lesson 17; owner 2026-11-20).

The owner's rule: game names come from UALLF. Where UALLF has a word for a profession, a rank, a trainer title
or a weapon skill, the glossary entry (UADD/glossary/professions.lua, ids prof.*, npc.*, weapon.*) uses that
word. Case is not compared: UALLF writes spell and NPC titles With Capitals, its UI words without.

UALLF is read from $UALLF_DIR, $UADD_ADDONS_DIR/UALLF or the WoW _forever_ folder (tools/game_names_src.py).
The test skips, with a message, when it is not installed.

    python3 -m unittest tools.test_glossary_uallf
"""
import re
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fxpb_words as FW  # noqa: E402
import game_names_src as GN  # noqa: E402
import glossary  # noqa: E402

GLOSSARY = HERE.parent / "UADD" / "glossary" / "professions.lua"
FILES = ["UI.lua", "Spells.lua", "NpcNames.lua"]
GROUPS = ("prof.", "npc.", "weapon.")
PAIR = re.compile(r'\[\s*("(?:[^"\\]|\\.)*")\s*\]\s*=\s*("(?:[^"\\]|\\.)*")')

# id: why our word may differ from UALLF's for the same English
ALLOW = {
    "prof.guide": "Mastercraft's levelling guide (a book of steps); UALLF's «Наставник» for Guide is a person",
}


def uallf_words(folder):
    """{English: {Ukrainian, ...}} from UALLF's UI, spell and NPC tables; None when UALLF is not installed."""
    if not all((folder / f).is_file() for f in FILES):
        return None
    words = {}
    for f in FILES:
        for m in PAIR.finditer((folder / f).read_text("utf-8", "replace")):
            words.setdefault(FW.unlua(m.group(1)), set()).add(FW.unlua(m.group(2)))
    return words


def mismatches(entries, words):
    """[(line, id, English, ours, UALLF's)] for game-name entries whose Ukrainian is not one of UALLF's."""
    out = []
    for fields, line in entries:
        if not fields["id"].startswith(GROUPS) or fields["id"] in ALLOW:
            continue
        ens = fields["en"] if isinstance(fields["en"], list) else [fields["en"]]
        for en in ens:
            theirs = words.get(en)
            if theirs and fields["uk"].casefold() not in {w.casefold() for w in theirs}:
                out.append((line, fields["id"], en, fields["uk"], " / ".join(sorted(theirs))))
    return out


class GlossaryMatchesUallf(unittest.TestCase):
    def setUp(self):
        self.words = uallf_words(GN.uallf_dir())
        if self.words is None:
            self.skipTest("UALL Forever is not installed (%s): glossary not compared" % GN.uallf_dir())

    def test_game_names_are_uallf_words(self):
        bad = mismatches(glossary.parse_entries(GLOSSARY), self.words)
        self.assertEqual(bad, [], "glossary words that are not UALL Forever's (take its word, or ALLOW it):\n"
                         + "\n".join("professions.lua:%d %s | %s | ours «%s» | UALLF «%s»" % b for b in bad))

    def test_allow_is_needed(self):
        ids = {f["id"]: f for f, _ in glossary.parse_entries(GLOSSARY)}
        for key in ALLOW:
            self.assertIn(key, ids, "ALLOW names a glossary id that is gone: %s" % key)
            f = ids[key]
            ens = f["en"] if isinstance(f["en"], list) else [f["en"]]
            theirs = {w.casefold() for en in ens for w in self.words.get(en, ())}
            self.assertTrue(theirs and f["uk"].casefold() not in theirs,
                            "ALLOW is not needed any more (UALLF has no word, or ours matches): %s" % key)


class Comparer(unittest.TestCase):
    def test_finds_a_different_word(self):
        words = {"Skinning": {"Білування"}, "Mining": {"Гірнича справа", "Гірнича Справа"}}
        entries = [({"id": "prof.skinning", "en": "Skinning", "uk": "Здирання шкур"}, 1),
                   ({"id": "prof.mining", "en": "Mining", "uk": "гірнича справа"}, 2),
                   ({"id": "prof.new", "en": "Fletching", "uk": "Що завгодно"}, 3),
                   ({"id": "ui.cleanup", "en": "Mining", "uk": "Інше"}, 4)]
        self.assertEqual([b[1] for b in mismatches(entries, words)], ["prof.skinning"])


if __name__ == "__main__":
    unittest.main()
