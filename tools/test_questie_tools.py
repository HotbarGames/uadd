"""Tests for tools/extract_questie_keys.py and tools/coverage.py, and a Lua 5.1 syntax check of the addon files.

python3 -m unittest discover -s tools
The syntax check uses the lupa module (pip install --user lupa) or luac5.1 / luac, and is skipped without both.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path.insert(0, str(HERE))
import coverage  # noqa: E402
import extract_questie_keys as eqk  # noqa: E402


def strs(lua):
    return [v for t, v in eqk.tokens(lua.encode("utf-8")) if t == eqk.STR]


class Tokens(unittest.TestCase):
    def test_escapes(self):
        self.assertEqual(strs(r'"a\nb" "q\"q" "\65\066x" ' + r"'it\'s' " + '"\\\\"'),
                         ["a\nb", 'q"q', "ABx", "it's", "\\"])

    def test_long_strings_and_comments(self):
        lua = '--[[ "not this" ]] x = [[\nfirst]] -- "nor this"\ny = [==[a]]b]==] --[=[ "x" ]=]'
        self.assertEqual(strs(lua), ["first", "a]]b"])

    def test_utf8(self):
        self.assertEqual(strs('"Українська"'), ["Українська"])


class Extract(unittest.TestCase):
    def test_extract_from_a_questie_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "Questie"
            (root / "Localization" / "Translations" / "Options").mkdir(parents=True)
            (root / "Questie.toc").write_text("## Version: 9.9.9\n", encoding="utf-8")
            (root / "Localization" / "Translations" / "Options" / "General.lua").write_text(
                'local t = {\n ["Show %s"] = { ["ptBR"] = "Mostrar %s", ["enUS"] = true, },\n'
                ' ["Only de"] = { ["deDE"] = "Nur" },\n'
                ' ["Line\\nTwo"] = {\n  ["enUS"] = true, -- ["fake"] = { ["enUS"] = true }\n },\n}\n',
                encoding="utf-8")
            data = eqk.extract(str(root))
        self.assertEqual(data["questieVersion"], "9.9.9")
        self.assertEqual(data["keys"], {"Line\nTwo": "Localization/Translations/Options/General.lua",
                                        "Show %s": "Localization/Translations/Options/General.lua"})

    def test_saved_keys_look_right(self):
        data = json.loads((REPO / "data" / "questie-keys.json").read_text(encoding="utf-8"))
        self.assertGreater(data["count"], 2400)
        self.assertEqual(data["count"], len(data["keys"]))
        self.assertTrue(data["questieVersion"])


class Coverage(unittest.TestCase):
    def test_compatible(self):
        ok = [("Show %s", "Показати %s"), ("%d of %d", "%d з %d"), ("100%%", "100%%"),
              ("|cFFFF0000Red|r", "|cFFFF0000Червоний|r"), ("a\nb", "а\nб")]
        bad = [("Show %s", "Показати"), ("%s %d", "%d %s"), ("x", "50% ще"), ("|cFFFF0000Red|r", "Червоний"),
               ("x", ""), ("Hi", "%s")]
        for key, uk in ok:
            self.assertTrue(coverage.compatible(key, uk), (key, uk))
        for key, uk in bad:
            self.assertFalse(coverage.compatible(key, uk), (key, uk))

    def test_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "strings.lua"
            path.write_text('local _, ns = ...\nns.uiStrings = {\n  ["Show %s"] = "Показати %s",\n'
                            '  ["Count: %d"] = "Кількість",\n  ["Not Questie"] = "Ні",\n}\n', encoding="utf-8")
            strings = coverage.read_strings(path)
        keys = {"Show %s": "Localization/Translations/Options/a.lua",
                "Count: %d": "Localization/Translations/Options/a.lua",
                "Elwynn Forest": "Localization/Translations/Zones/Zones.lua"}
        r = coverage.report(keys, strings)
        self.assertEqual((r["total"], r["covered"]), (3, 1))
        self.assertEqual(r["bad"], ["Count: %d"])
        self.assertEqual(r["missing"], ["Elwynn Forest"])
        self.assertEqual(r["extra"], ["Not Questie"])
        self.assertEqual(r["byArea"], {"Options": [1, 2], "Zones": [0, 1]})

    def test_runs_without_a_strings_file(self):
        self.assertEqual(coverage.read_strings("/no/such/strings.lua"), {})
        out = subprocess.run([sys.executable, str(HERE / "coverage.py"), "--strings", "/no/such/strings.lua"],
                             capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("not there yet", out.stdout)

    def test_shipped_strings_have_no_bad_entries(self):
        if not coverage.STRINGS.exists():
            self.skipTest("no UADD_Questie/ui/strings.lua yet")
        data = json.loads(coverage.KEYS.read_text(encoding="utf-8"))
        r = coverage.report(data["keys"], coverage.read_strings(coverage.STRINGS))
        self.assertEqual(r["bad"], [], "these would be skipped in the game")

    def test_tracker_words_stay_left_to_uallf(self):
        strings = coverage.read_strings(coverage.STRINGS)
        back = sorted(k for k in coverage.LEFT_TO_UALLF if k in strings)
        self.assertEqual(back, [], "UALL Forever translates the tracker: leave these out of strings.lua")
        data = json.loads(coverage.KEYS.read_text(encoding="utf-8"))
        gone = sorted(k for k in coverage.LEFT_TO_UALLF if k not in data["keys"])
        self.assertEqual(gone, [], "no longer Questie keys: drop them from coverage.LEFT_TO_UALLF")
        r = coverage.report({"Questie Tracker": "Localization/Translations/TrackerUI.lua"}, {})
        self.assertEqual((r["missing"], r["left"]), ([], ["Questie Tracker"]))


def lua_files():
    return sorted(p for d in ("UADD", "UADD_Questie") for p in (REPO / d).rglob("*.lua"))


class LuaSyntax(unittest.TestCase):
    def test_all_lua_files_compile(self):
        try:
            from lupa import lua51
        except ImportError:
            lua51 = None
        files = lua_files()
        self.assertTrue(files)
        if lua51 is not None:
            runtime = lua51.LuaRuntime()
            compile_ = runtime.eval("function(src, name) local f, err = loadstring(src, '@' .. name) "
                                    "return err end")
            for path in files:
                err = compile_(path.read_bytes(), str(path.relative_to(REPO)))
                self.assertIsNone(err, err)
            return
        luac = shutil.which("luac5.1") or shutil.which("luac")
        if not luac:
            self.skipTest("no lupa and no luac: pip install --user lupa")
        for path in files:
            out = subprocess.run([luac, "-p", str(path)], capture_output=True, text=True)
            self.assertEqual(out.returncode, 0, out.stderr)


if __name__ == "__main__":
    unittest.main()
