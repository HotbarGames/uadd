"""The gate for the translators' files: every key in tools/dj_prose/uk_N.lua exists in en_N.lua, and
each Ukrainian text keeps the placeholders, |c/|r/|T codes, %s and numbers of its English
(make_dj_prose_data.validate). A uk_N file that is missing or does not load yet is skipped."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    import lupa  # noqa: F401
    import make_dj_prose_data as D
except ImportError:  # pragma: no cover
    D = None


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
    unittest.main()
