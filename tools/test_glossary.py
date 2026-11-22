"""Tests for tools/glossary.py (the shared word base checker) and tools/luatok.py.

python3 -m unittest discover -s tools
The Lua test uses the lupa module (pip install --user lupa) and is skipped without it.
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(HERE))
import coverage  # noqa: E402
import glossary  # noqa: E402
import luatok  # noqa: E402

try:
    import lupa
except ImportError:
    lupa = None

HEAD = "local E = UADD.Glossary.Add\n"
STRINGS_HEAD = "local _, ns = ...\nlocal G = UADD and UADD.Glossary and UADD.Glossary.Text\nns.uiStrings = {\n"


class Repo:
    """A temp repo with glossary data files and one module strings file."""

    def __init__(self, glossary_files, strings=None, other=None):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "UADD" / "glossary").mkdir(parents=True)
        (self.root / "UADD" / "Glossary.lua").write_text("UADD = UADD or {}\n", encoding="utf-8")
        for name, body in glossary_files.items():
            (self.root / "UADD" / "glossary" / name).write_text(HEAD + body, encoding="utf-8")
        if strings is not None:
            (self.root / "UADD_Test" / "ui").mkdir(parents=True)
            self.strings = self.root / "UADD_Test" / "ui" / "strings.lua"
            self.strings.write_text(STRINGS_HEAD + strings + "}\n", encoding="utf-8")
        for name, body in (other or {}).items():
            (self.root / "UADD_Test" / name).write_text(body, encoding="utf-8")

    def check(self):
        problems, warnings, _ = glossary.check(self.root)
        return problems, warnings

    def close(self):
        self.tmp.cleanup()


ENTRIES = ('E{ id = "ui.close", en = "Close", uk = "Закрити", note = "Button: close a window." }\n'
           'E({ id = "ui.settings", en = { "Settings", "Options" }, uk = "Налаштування", note = "The menu." })\n')


class Checker(unittest.TestCase):
    def repo(self, *args, **kw):
        r = Repo(*args, **kw)
        self.addCleanup(r.close)
        return r

    def test_clean(self):
        r = self.repo({"ui.lua": ENTRIES}, '  ["Close"] = G"ui.close",\n  ["Options"] = G("ui.settings"),\n'
                                           '  ["Mine"] = "Моє",\n')
        self.assertEqual(r.check(), ([], []))
        self.assertEqual(glossary.read_module_strings(r.strings, glossary.Glossary(r.root)),
                         {"Close": "Закрити", "Options": "Налаштування", "Mine": "Моє"})
        self.assertEqual(coverage.read_strings(r.strings, r.root)["Options"], "Налаштування")

    def test_missing_id_fails(self):
        r = self.repo({"ui.lua": ENTRIES}, '  ["Close"] = G"ui.closee",\n',
                      {"Other.lua": 'local t = UADD.Glossary.Text("ui.nope")\n'})
        problems, _ = r.check()
        self.assertEqual(len(problems), 2, problems)
        self.assertIn("'ui.closee'", problems[0] + problems[1])
        self.assertIn("'ui.nope'", problems[0] + problems[1])
        self.assertNotIn("Close", glossary.read_module_strings(r.strings, glossary.Glossary(r.root)))

    def test_duplicate_id_fails(self):
        dup = 'E{ id = "ui.close", en = "Near", uk = "Поруч", note = "Not far." }\n'
        r = self.repo({"ui.lua": ENTRIES, "world.lua": dup})
        problems, _ = r.check()
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("already used", problems[0])
        self.assertEqual(glossary.Glossary(r.root).text("ui.close"), "Закрити")  # the first one wins

    def test_bad_entries_fail(self):
        bad = ('E{ id = "Close", en = "Close", uk = "Закрити", note = "bad id" }\n'
               'E{ id = "ui.no_note", en = "X", uk = "Х" }\n'
               'E{ id = "ui.level_n", en = "Level %s", uk = "Рівень", note = "lost %s" }\n')
        problems, _ = self.repo({"ui.lua": bad}).check()
        self.assertEqual(len(problems), 3, problems)
        self.assertIn("bad id", problems[0])
        self.assertIn("no note", problems[1])
        self.assertIn("%s/%d", problems[2])

    def test_same_english_different_ukrainian_warns(self):
        r = self.repo({"ui.lua": ENTRIES}, '  ["Close"] = "Поруч",\n')
        problems, warnings = r.check()
        self.assertEqual(problems, [])
        self.assertEqual(len(warnings), 1, warnings)
        self.assertIn("different Ukrainian", warnings[0])

    def test_two_modules_disagree_warns(self):
        r = self.repo({"ui.lua": ENTRIES}, '  ["Track"] = "Стежити",\n')
        other = r.root / "UADD_Other" / "ui"
        other.mkdir(parents=True)
        (other / "strings.lua").write_text(STRINGS_HEAD + '  ["Track"] = "Трек",\n}\n', encoding="utf-8")
        _, warnings = r.check()
        self.assertEqual(len(warnings), 1, warnings)
        self.assertIn("'Track' has different Ukrainian", warnings[0])

    def test_two_meanings_linked_do_not_warn(self):
        two = ENTRIES + 'E{ id = "ui.close_near", en = "Close", uk = "Поруч", note = "Near, not a button." }\n'
        r = self.repo({"ui.lua": two}, '  ["Close"] = G"ui.close_near",\n')
        other = r.root / "UADD_Other" / "ui"
        other.mkdir(parents=True)
        (other / "strings.lua").write_text(STRINGS_HEAD + '  ["Close"] = G"ui.close",\n}\n', encoding="utf-8")
        self.assertEqual(r.check(), ([], []))
        r.strings.write_text(STRINGS_HEAD + '  ["Close"] = "Біля",\n}\n', encoding="utf-8")
        _, warnings = r.check()
        self.assertEqual(len(warnings), 1, warnings)
        self.assertIn("'Close' has different Ukrainian", warnings[0])

    def test_unlinked_exact_match_warns(self):
        r = self.repo({"ui.lua": ENTRIES}, '  ["Settings"] = "Налаштування",\n')
        problems, warnings = r.check()
        self.assertEqual(problems, [])
        self.assertEqual(len(warnings), 1, warnings)
        self.assertIn('link it (G"ui.settings")', warnings[0])

    def test_link_with_other_wording_warns(self):
        r = self.repo({"ui.lua": ENTRIES}, '  ["Close Window"] = G"ui.close",\n')
        _, warnings = r.check()
        self.assertEqual(len(warnings), 1, warnings)
        self.assertIn("whose English is ['Close']", warnings[0])

    def test_link_the_game_would_skip_fails(self):
        r = self.repo({"ui.lua": ENTRIES}, '  ["Close %s"] = G"ui.close",\n')
        problems, _ = r.check()
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("would skip", problems[0])

    def test_cli_exit_codes(self):
        ok = self.repo({"ui.lua": ENTRIES})
        bad = self.repo({"ui.lua": ENTRIES + ENTRIES})
        run = [sys.executable, str(HERE / "glossary.py"), "--list", "--root"]
        out = subprocess.run(run + [str(ok.root)], capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        self.assertIn("2 entries in 1 files", out.stdout)
        out = subprocess.run(run + [str(bad.root)], capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(out.returncode, 1, out.stdout + out.stderr)


class Tokens(unittest.TestCase):
    def test_strings_comments_lines(self):
        src = '-- c "no"\n--[[ long\n"no" ]] x = "a\\"b" .. [[\nlong]]\n["k"] = 1'
        toks = list(luatok.tokens(src))
        self.assertEqual([t for t in toks if t[0] == luatok.STR], [("str", 'a"b', 3), ("str", "long", 3),
                                                                   ("str", "k", 5)])
        self.assertIn(("name", "x", 3), toks)

    def test_fast_reader_matches_slow(self):
        """tokens() (a regex for the common tokens) gives exactly what slow_tokens() (the letter-by-letter
        reader) gives, errors too: on every Lua file of the repo and on odd made-up text."""
        import random

        def run(fn, text):
            try:
                return list(fn(text))
            except Exception as e:      # the old reader raises on some letters; the fast one must too
                return type(e).__name__
        texts = [p.read_bytes().decode("utf-8", "replace") for p in sorted(REPO.rglob("*.lua"))
                 if ".git" not in p.parts]
        rng = random.Random(7)
        alpha = list("ab_Z09x. \t\r\n\f\v\"'\\[]=-{}()é²Ж#;,") + ["--", "[[", "]]", "[==[", "]==]", "\\9", "\\\n"]
        texts += ["".join(rng.choice(alpha) for _ in range(rng.randint(0, 30))) for _ in range(20000)]
        bad = [t[:60] for t in texts if run(luatok.tokens, t) != run(luatok.slow_tokens, t)]
        self.assertEqual(bad, [])


class ThisRepo(unittest.TestCase):
    def test_no_problems_and_no_warnings(self):
        problems, warnings, g = glossary.check(REPO)
        self.assertEqual(problems, [])
        self.assertEqual(warnings, [])
        self.assertGreater(len(g.entries), 100)

    @unittest.skipIf(lupa is None, "lupa is not installed")
    def test_lua_builds_the_same_table(self):
        """Real Lua: the glossary files from UADD.toc, then strings.lua, give what the Python reader gives."""
        toc = (REPO / "UADD" / "UADD.toc").read_text(encoding="utf-8").splitlines()
        files = [line.strip() for line in toc if line.strip().startswith(("Glossary", "glossary"))]
        self.assertIn("Glossary.lua", files)
        lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        load = lua.eval("function(src, name) return assert((loadstring or load)(src, name)) end")
        ns = lua.table()
        for name in files:
            load((REPO / "UADD" / name).read_text(encoding="utf-8"), name)("UADD", lua.table())
        load(coverage.STRINGS.read_text(encoding="utf-8"), "strings.lua")("UADD_Questie", ns)
        self.assertEqual(dict(lua.globals().UADD.Glossary.missing.items()), {})
        self.assertEqual(dict(lua.globals().UADD.Glossary.duplicates.items()), {})
        self.assertEqual(dict(ns.uiStrings.items()), coverage.read_strings(coverage.STRINGS))


if __name__ == "__main__":
    unittest.main()
