"""GearQuest Forever's Ukrainian (UADD_GearQuestForever/data/text*.lua) keeps no Latin word: a game name or an
English word inside our Ukrainian is a half line (docs/LESSONS.md lesson 9, as test_dj_prose.test_no_latin_in_uk).

Taken out before the scan: G"..." refs (a game name the module asks for at run time), colour codes, |r, textures,
links, %s/%d slots and slash commands. ALLOW lists the few words that may stay, each with a reason; never a game name.
ARGS: the words a help line lists for its slash command, by key. KNOWN: texts still to fix; it only goes down.
`python3 tools/test_gq_text.py --latin` prints every hit. The data is loaded as the game does (lupa).
"""
import re
import sys
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
DATA = TOOLS.parent / "UADD_GearQuestForever" / "data"
try:
    import lupa
except ImportError:  # pragma: no cover
    lupa = None

CODES = re.compile(r'G"[^"]*"|\|c(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{0,6}%s)|\|r|\|T[^|]*\|t|\|H[^|]*\|h[^|]*\|h'
                   r"|%[-+#0]*\d*\.?\d*[sdif%]")
COMMAND = re.compile(r"(?<![\w/])/[a-z]+(?: [a-z]+)*")          # after CODES: "|cff00ff00/gq log|r" is one too
LATIN = re.compile(r"[A-Za-z]{2,}")
ALLOW = {
    "GearQuest": "the addon's own name in the game (its TOC Title), kept as it is",
    "GEAR QUEST": "the same name, as its guide's greeting writes it in capitals",
    "Forever": "the realm's name, kept as it is everywhere (UALL Forever)",
    "WoW": "the game's own short name (\"WoW: Forever\"), a product name",
    "Wowhead": "a website's name, given as the source of its item lists",
    "Blizzard": "the company that makes the game",
    "OpenMap": "another addon's name, as it names itself in the game",
    "Discord": "a chat service's name",
    "Shift": "a key's name, as printed on the keyboard",
    "Ctrl": "a key's name, as printed on the keyboard",
    "Alt": "a key's name, as printed on the keyboard",
}
ALLOWED = re.compile(r"(?<![A-Za-z])(?:%s)(?![A-Za-z])" % "|".join(map(re.escape, ALLOW)))
# Words its slash command takes as they are (a class, a faction): a help line that lists them keeps them English.
ARGS = {
    "L.261bf559": "druid hunter mage paladin priest rogue shaman warlock warrior",
    "L.28c76ec4": "mage shaman",
    "L.c43333e8": "alliance horde",
}
# Texts still to fix (Latin left in our Ukrainian). It only goes down: an entry that is clean now fails.
KNOWN = {
    "L.412b6072": "PvP",
    "L.55ff757e": "BiS",
}


def latin_words(text, key=None):
    """The Latin words (2+ letters) left in a Ukrainian text, sorted; [] when it is clean."""
    left = ALLOWED.sub(" ", COMMAND.sub(" ", CODES.sub(" ", text)))
    return sorted(set(LATIN.findall(left)) - set(ARGS.get(key, "").split()))


def load():
    """{key: Ukrainian} of every data file, run as the game runs it."""
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    ns = lua.table()
    for f in sorted(DATA.glob("text*.lua")):
        lua.execute(f.read_bytes(), "UADD_GearQuestForever", ns)
    al = ns["AL"]
    if al is None:
        return {}
    return {k.decode() if isinstance(k, bytes) else k: v.decode() if isinstance(v, bytes) else v
            for k, v in al.items()}


def hits():
    out = {}
    for k, v in load().items():
        words = isinstance(v, str) and latin_words(v, k)
        if words:
            out[k] = (words, v)
    return out


@unittest.skipIf(lupa is None, "lupa is not installed")
class GqText(unittest.TestCase):
    def test_no_latin_in_uk(self):
        h = hits()
        bad = ["%s  latin: %s" % (k, " ".join(h[k][0])) for k in sorted(h) if " ".join(h[k][0]) != KNOWN.get(k)]
        self.assertEqual(bad, [], "%d texts with Latin left in Ukrainian (a half line: say it without the name, or "
                                  "keep the whole text English):\n  %s" % (len(bad), "\n  ".join(bad)))

    def test_known_only_goes_down(self):
        h, data = hits(), load()
        gone = sorted(k for k in list(KNOWN) + list(ARGS) if k not in data)
        clean = sorted(k for k in KNOWN if k in data and k not in h)
        self.assertEqual((gone, clean), ([], []), "keys gone from our data, or KNOWN texts clean now: take them out")

    def test_data_loads(self):
        self.assertGreater(len(load()), 100)

    def test_latin_mutant(self):
        self.assertEqual(latin_words("Поговоріть із «Wobbly Gizmo» біля табору."), ["Gizmo", "Wobbly"])
        self.assertEqual(latin_words('|cffff0000Увага|r: %s, %d%% у G"Old Town" |TInterface\\Icons\\X:0|t, '
                                     "|Hitem:123|h[Wobbly]|h. Наберіть /gq reset у GearQuest, Shift."), [])
        self.assertEqual(latin_words("Відкрийте |cff00ff00/gq log|r і |cff%s%d бал|r."), [])
        self.assertEqual(latin_words("Нове у GearQuestland."), ["GearQuestland"])   # ALLOW is whole words only
        self.assertEqual(latin_words("Клас: mage або Wobbly.", "L.28c76ec4"), ["Wobbly"])   # ARGS: its key, its words
        self.assertEqual(latin_words("Клас: mage."), ["mage"])
        for word in ALLOW:
            self.assertTrue(ALLOW[word], word)


if __name__ == "__main__":
    if "--latin" in sys.argv:
        for k, (words, _) in sorted(hits().items()):
            print(k, " ".join(words))
    else:
        unittest.main()
