"""Checks UADD_Attune's tables (ui/locale.lua, ui/notes.lua, data/hashed.lua) against Attune's own files.

The repo keeps no English of Attune's (all rights reserved): the English is read here from the installed
Attune, at test time only.
- ns.UA keys are enUS.lua keys and not English prose (that goes to ns.UA_KEYHASH, by hash);
  ns.UA_CATEGORY and ns.UA_GLUED keys are enUS.lua keys; each shape has one {};
- ns.UA_KEYHASH and ns.UA_GLUEHASH hashes are hashes of enUS.lua keys; ns.UA_TEXTHASH hashes are hashes of
  strings in Attune's code; ns.UA_STEP_TYPE keys are step TYPE values; ns.UA_NOTES keys are N2_ keys;
- each Ukrainian keeps its English's ##TOKEN## places, %s slots (same order), | codes, line breaks and
  leading or trailing space;
- data/hashed.lua is what tools/make_att_text.py builds from a fresh review file (nothing lost on the way).

Attune is read from the game folder, ATTUNE_DIR or $UADD_ADDONS_DIR/Attune. Without it, the tests that need
it are skipped.

python3 -m unittest tools.test_att_strings
"""
import re
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import glossary  # noqa: E402
import hashtext  # noqa: E402
import make_att_text as M  # noqa: E402
from coverage import escape_counts, specs  # noqa: E402

ADDON = M.addon_dir()
ENUS = ADDON / "Locales" / "enUS.lua"
HAVE_ADDON = ENUS.is_file()
PLACE = re.compile(r"##[A-Z][A-Z0-9_]*##")
TYPE = re.compile(r'TYPE\s*=\s*"([^"]+)"')


def norm(text):
    return text.replace("\\n", "\n")


def shape(text):
    """What must stay the same between an English text and its Ukrainian."""
    text = norm(text)
    return {"places": sorted(PLACE.findall(text)), "slots": specs(text), "codes": escape_counts(text),
            "breaks": text.count("\n"), "edges": (text[:1] == " ", text[-1:] == " ")}


def data_types():
    found = set()
    for name in ("AttuneData.lua", "AttuneClassQuests.lua"):
        p = ADDON / name
        if p.is_file():
            found.update(TYPE.findall(p.read_text(encoding="utf-8", errors="replace")))
    return found


class Local(unittest.TestCase):
    """What needs no Attune."""

    @classmethod
    def setUpClass(cls):
        cls.tables = M.our_tables()

    def test_tables_there(self):
        for name in M.TABLES:
            with self.subTest(table=name):
                self.assertTrue(self.tables[name], f"ns.{name} is empty or not there")

    def test_keys_once(self):
        for name, rows in self.tables.items():
            names = [r[0] for r in rows]
            self.assertEqual(sorted(k for k in set(names) if names.count(k) > 1), [], f"{name}: keys twice")

    def test_hashed_keys(self):
        for name in M.BY_HASH:
            bad = [r[0] for r in self.tables[name] if not M.HASH.match(r[0])]
            self.assertEqual(bad, [], f"ns.{name} keys that are not <bytes>:<hash>")

    def test_shapes_have_one_place(self):
        for name in ("UA_GLUED", "UA_GLUEHASH"):
            bad = [r[0] for r in self.tables[name] if r[4] is None or r[4].count("{}") != 1]
            self.assertEqual(bad, [], f"ns.{name}: a value that is not {{ shape with one {{}}, Ukrainian }}")


@unittest.skipUnless(HAVE_ADDON, f"Attune not found in {ADDON} (set ATTUNE_DIR)")
class AgainstAttune(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.enus, cls.bad = M.enus(ADDON)
        cls.strings = M.code_strings(ADDON)
        cls.tables = M.our_tables()
        cls.g = glossary.Glossary()
        cls.by_key = {hashtext.key(k): k for k in cls.enus}
        cls.by_text = {hashtext.key(s): s for s in cls.strings}

    def unknown(self, table, known):
        return [(r[0], r[3]) for r in self.tables[table] if r[0] not in known]

    def test_enus_read(self):
        self.assertEqual(self.bad, [], "enUS.lua lines the tool cannot read")
        self.assertGreater(len(self.enus), 1000)

    def test_plain_keys_in_enus(self):
        for table in ("UA", "UA_CATEGORY", "UA_GLUED"):
            with self.subTest(table=table):
                self.assertEqual(self.unknown(table, self.enus), [], f"ns.{table} keys that are not enUS.lua keys")

    def test_no_prose_keys(self):
        prose = [(k, line) for k, _, _, line, _ in self.tables["UA"] if M.prose(k)]
        self.assertEqual(prose, [], "ns.UA keys that are English prose: run make_att_text.py, use KEYHASH")

    def test_hashes_found(self):
        for table, known in (("UA_KEYHASH", self.by_key), ("UA_GLUEHASH", self.by_key),
                             ("UA_TEXTHASH", self.by_text)):
            with self.subTest(table=table):
                self.assertEqual(self.unknown(table, known), [], f"ns.{table}: not in the installed Attune")

    def test_step_types_are_type_values(self):
        types = data_types()
        self.assertIn("Quest", types)
        self.assertEqual(self.unknown("UA_STEP_TYPE", types), [], "ns.UA_STEP_TYPE keys that are not TYPE values")

    def test_notes_keys_in_enus(self):
        rows = self.tables["UA_NOTES"]
        self.assertGreater(len(rows), 100)
        bad = [(k, line) for k, _, _, line, _ in rows if not k.startswith("N2_") or k not in self.enus]
        self.assertEqual(bad, [], "ns.UA_NOTES keys that are not N2_ keys of enUS.lua")

    def test_shapes(self):
        for table in M.TABLES:
            for key, uk, gid, line, glued in self.tables[table]:
                _, en = M.english(table, key, glued, self.enus, self.by_key, self.by_text)
                if en is None:
                    continue
                uk = uk if gid is None else self.g.text(gid)
                with self.subTest(table=table, line=line):
                    self.assertTrue(uk, "empty, or a glossary id that is not there")
                    self.assertEqual(shape(en), shape(uk), f"{uk!r}: other places, slots, codes, breaks or spaces")

    def test_hashed_lua_in_sync(self):
        text, _ = M.review_text(self.tables, self.enus, self.strings)
        made, problems = M.build_text(M.read_review(text))
        self.assertEqual(problems, [])
        self.assertEqual(M.HASHED.read_text(encoding="utf-8"), made,
                         "data/hashed.lua is not what make_att_text.py builds from its own review")


FIXTURE = '''local _, ns = ...
local G = function() end
ns.UA = {
    ["Kx"] = "Закрити",
    Ky = G"game.level",
}
ns.UA_GLUED = {
    ["Kz"] = { "{} %s", "Рівень %s" },
}
ns.UA_KEYHASH = {
    ["2:00000001"] = "Далі",
}
'''


class Reader(unittest.TestCase):
    def test_tables(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "locale.lua"
            p.write_text(FIXTURE, encoding="utf-8")
            got = M.read_tables(p)
        self.assertEqual([r[:3] for r in got["UA"]], [("Kx", "Закрити", None), ("Ky", None, "game.level")])
        self.assertEqual([(r[0], r[1], r[4]) for r in got["UA_GLUED"]], [("Kz", "Рівень %s", "{} %s")])
        self.assertEqual([r[:2] for r in got["UA_KEYHASH"]], [("2:00000001", "Далі")])
        self.assertEqual(got["UA_NOTES"], [])

    def test_no_file(self):
        self.assertEqual(M.read_tables(Path(tempfile.gettempdir()) / "no-such-locale.lua"),
                         {n: [] for n in M.TABLES})

    def test_round_trip(self):
        lang = {"Qa": "Xq zv", "Qb": "Zz"}
        tables = {n: [] for n in M.TABLES}
        tables["UA_KEYHASH"] = [(hashtext.key("Qa"), "Один\nдва", None, 1, None)]
        tables["UA_GLUEHASH"] = [(hashtext.key("Qb"), "Ні %s", None, 2, "{} %s")]
        tables["UA_TEXTHASH"] = [(hashtext.key("Vv \\ w"), "Ще", None, 3, None),
                                 ("9:0badf00d", "Старе", None, 4, None)]
        text, notes = M.review_text(tables, lang, {"Vv \\ w"})
        self.assertEqual(len(notes), 1, notes)              # the one not found keeps its hash
        made, problems = M.build_text(M.read_review(text))
        self.assertEqual(problems, [])
        for key, uk, *_ in [r for n in M.BY_HASH for r in tables[n]]:
            self.assertIn(f"[{hashtext.lua_str(key)}]", made)
            self.assertIn(hashtext.lua_str(uk), made)
        self.assertNotIn("Xq", made)

    def test_build_problems(self):
        blocks = [("UA_GLUEHASH", None, {"key": "Qb", "uk": "Ні %s"}),
                  ("UA_KEYHASH", None, {"key": "Qa", "uk": 'G"game.level"'}),
                  ("UA_TEXTHASH", None, {"key": "Vv %s", "uk": "Ще"}),
                  ("UA_TEXTHASH", None, {"uk": "Ще"})]
        _, problems = M.build_text(blocks)
        self.assertEqual(len(problems), 4, problems)

    def test_shape(self):
        self.assertEqual(shape("##NAME## in %s\\n"), shape("%s: ##NAME##\n"))
        self.assertNotEqual(shape("|cffffffff##A##|r"), shape("##A##"))
        self.assertNotEqual(shape("##A## ##B##"), shape("##A##"))


if __name__ == "__main__":
    unittest.main()
