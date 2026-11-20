"""The gate for the translators' files: every key in tools/dj_prose/uk_N.lua exists in en_N.lua, and
each Ukrainian text keeps the placeholders, |c/|r/|T codes, %s and numbers of its English
(make_dj_prose_data.validate). A uk_N file that is missing or does not load yet is skipped.

No Latin word may stay in a Ukrainian text (docs/LESSONS.md lesson 9, "Again in Dungeon Journal"):
`python3 tools/test_dj_prose.py --latin` prints every hit and a KNOWN block to paste here."""
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    import lupa  # noqa: F401
    import make_dj_prose_data as D
except ImportError:  # pragma: no cover
    D = None

# Taken out before the Latin scan: placeholders (UALL Forever names them at run time), colour codes,
# |r, textures, links and %s/%d.
NOT_TEXT = re.compile(r"\{(?:npc|item|zone|quest):[^{}]+\}|\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t"
                      r"|\|H[^|]*\|h[^|]*\|h|%[sd]")
LATIN = re.compile(r"[A-Za-z]{2,}")
# Latin that may stay inside Ukrainian. Never a game name (zone, NPC, item, quest, faction).
ALLOW = {
    "WoW": "the game's own short name (\"WoW Forever\"), a product name",
    "Forever": "the realm's name, kept as it is everywhere (UALL Forever)",
    "Classic": "the game's edition (WoW Classic), a product name",
    "Dungeon Journal": "the addon's own name in the game (its TOC Title), kept as it is",
    "Discord": "a chat service's name",
    "Mobalytics": "a website's name, given as a source",
}
ALLOWED = re.compile(r"(?<![A-Za-z])(?:%s)(?![A-Za-z])" % "|".join(map(re.escape, ALLOW)))

# "N:hash" entries that still have Latin (being fixed). Only goes down: a fixed entry must leave.
KNOWN = set("""
""".split())


def latin_words(text):
    """The Latin words (2+ letters) left in a Ukrainian text, sorted; [] when it is clean."""
    return sorted(set(LATIN.findall(ALLOWED.sub(" ", NOT_TEXT.sub(" ", text)))))


def latin_hits(lua):
    """({"N:hash": (words, text)}, batches that loaded)."""
    hits, loaded = {}, set()
    for n in D.BATCHES:
        uk = D.load_uk(lua, n)
        if uk is None:
            continue
        loaded.add(n)
        for key, text in uk.items():
            words = latin_words(text) if isinstance(text, str) else []
            if words:
                hits["%d:%s" % (n, key)] = (words, text)
    return hits, loaded


def print_latin():
    hits, loaded = latin_hits(D.lua_runtime())
    for k in sorted(hits, key=lambda k: (int(k.split(":")[0]), k)):
        print("uk_%s.lua %s  latin: %s\n    %s" % (k.split(":")[0], k, " ".join(hits[k][0]), hits[k][1]))
    print("%d entries in batches %s\n\nKNOWN = set(\"\"\"" % (len(hits), sorted(loaded)))
    keys = sorted(hits, key=lambda k: (int(k.split(":")[0]), k))
    for i in range(0, len(keys), 9):
        print(" ".join(keys[i:i + 9]))
    print("\"\"\".split())")


@unittest.skipIf(D is None, "lupa is not installed")
class DjProseTest(unittest.TestCase):
    def test_uk_files_match_en(self):
        lua = D.lua_runtime()
        for n in D.BATCHES:
            with self.subTest(batch=n):
                if not (D.SRC / ("uk_%d.lua" % n)).exists():
                    self.skipTest("uk_%d.lua not written yet" % n)
                if not (D.SRC / ("en_%d.lua" % n)).exists():  # not in git: FDJ's own text
                    self.skipTest("en_%d.lua missing: run tools/make_dj_prose.py" % n)
                uk = D.load_uk(lua, n)
                if uk is None:
                    self.skipTest("uk_%d.lua does not load yet (still being written?)" % n)
                en = D.load_en(lua, n)
                bad = []
                for key, text in sorted(uk.items()):
                    if key not in en:
                        bad.append("%s: key not in en_%d" % (key, n))
                        continue
                    problems = D.validate(en[key], text)
                    if problems:
                        bad.append("%s: %s" % (key, "; ".join(problems)))
                self.assertEqual(bad, [], "uk_%d.lua:\n  " % n + "\n  ".join(bad))

    def test_no_latin_in_uk(self):
        hits, loaded = latin_hits(D.lua_runtime())
        new = ["%s  latin: %s" % (k, " ".join(hits[k][0])) for k in sorted(hits) if k not in KNOWN]
        gone = sorted(k for k in KNOWN if k not in hits and int(k.split(":")[0]) in loaded)
        if new:
            self.fail("%d texts with Latin left in Ukrainian (a half line: say it without the name, or keep the "
                      "whole text English; see --latin):\n  %s" % (len(new), "\n  ".join(new)))
        if gone:
            self.fail("%d fixed, take them out of KNOWN:\n  %s" % (len(gone), "\n  ".join(gone)))

    def test_latin_mutant(self):
        self.assertEqual(latin_words("Поговоріть із «Wobbly Gizmo» біля табору."), ["Gizmo", "Wobbly"])
        self.assertEqual(latin_words("Поговоріть із «{npc:Wobbly Gizmo}» біля табору."), [])
        self.assertEqual(latin_words("|cffff0000Увага|r: %s у «{zone:Old Town}» |TInterface\\Icons\\X:0|t, "
                                     "|Hitem:123|h[Wobbly]|h. Нове у WoW Forever."), [])
        self.assertEqual(latin_words("Нове у Foreverland."), ["Foreverland"])  # ALLOW is whole words only
        for word in ALLOW:
            self.assertTrue(ALLOW[word], word)

    def test_runtime_key_matches_generator(self):
        import make_dj_prose as G
        lua = D.lua_runtime()
        lua.execute(b"ns = {}; UADD = { Plain = function(v) return v end }; "
                    b"CreateFrame = function() return { SetScript = function() end } end")
        lua.execute((D.REPO / "UADD" / "Hash.lua").read_bytes())
        lua.execute((D.REPO / "UADD_DungeonJournal" / "Prose.lua").read_bytes().replace(b"local _, ns = ...", b""))
        key = lua.eval("ns.Prose.Key")
        for text in ("Kill 5 Edwin VanCleef.", "Убийте НІП «Ґ»\n\n%s" * 40, ""):
            self.assertEqual(key(text.encode("utf-8")).decode(), G.djb2(text))

    def test_validate_catches_changes(self):
        e = {"en": "Kill 5 Edwin VanCleef |cffff0000now|r.", "src": "Kill 5 {npc:Edwin VanCleef} |cffff0000now|r."}
        self.assertEqual(D.validate(e, "Убийте 5 {npc:Edwin VanCleef} |cffff0000зараз|r."), [])
        self.assertTrue(D.validate(e, "Убийте 5 Едвіна |cffff0000зараз|r."))           # placeholder dropped
        self.assertTrue(D.validate(e, "Убийте 6 {npc:Edwin VanCleef} |cffff0000зараз|r."))  # number changed
        self.assertTrue(D.validate(e, "Убийте 5 {npc:Edwin VanCleef} зараз."))          # colour code dropped
        self.assertTrue(D.validate(e, "Убийте 5 {npc:Edwin VanCleef} |cffff0000сейчас|r ы."))  # Russian letter
        t = {"en": "Accept %s before %s."}
        self.assertTrue(D.validate(t, "Візьміть %s."))                                   # %s dropped


if __name__ == "__main__":
    if "--latin" in sys.argv:
        if D is None:
            sys.exit("lupa is not installed")
        print_latin()
    else:
        unittest.main()
