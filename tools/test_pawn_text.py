"""tools/make_pawn_text.py (with tools/key_text.py): the slot check, STAY keys, the data files, and no English
of Pawn in the built data. Made-up English only; tests that read the installed Pawn skip when it is missing."""
import re
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import key_text as K  # noqa: E402
import make_pawn_text as M  # noqa: E402
import pawn_rules as R  # noqa: E402
import pawn_source as S  # noqa: E402

ADDON = S.addon_dir()
INSTALLED = (ADDON / "Localization.lua").is_file()


def write_review(folder, rows, uas):
    out = []
    for i, (key, en, *_) in enumerate(rows, 1):
        out += K.block(M.SPEC, i, key, en, uas.get(key, ""))
    (Path(folder) / "review_01.txt").write_text("\n".join(out), encoding="utf-8")


class SlotCheck(unittest.TestCase):
    def test_colon_before_value_stays(self):
        self.assertTrue(M.check("X", "Wobbly gizmo: %d", "Хиткий гвинтик %d"))
        self.assertTrue(M.check("X", "Wobbly: |cff00ff00gizmo|r", "Хиткий |cff00ff00гвинтик|r"))
        self.assertEqual(M.check("X", "Wobbly gizmo: %d", "Хиткий гвинтик: %d"), [])

    def test_leading_colour_stays_first(self):
        self.assertTrue(M.check("X", "|cff00ff00Wobbly|r gizmo", "Хиткий |cff00ff00гвинтик|r"))

    def test_percent_word_is_no_slot(self):
        self.assertEqual(K.slots("Wobbly 50% gizmo"), [])
        self.assertEqual(K.slots("Wobbly % upgrade %S"), [])
        self.assertEqual(K.slots("Wobbly %.1f%% %s"), ["f", "s"])

    def test_unsorted_and_stay(self):
        self.assertTrue(M.check("NO_SUCH_KEY", "Wobbly %s gizmo", "Хиткий %s гвинтик"))
        self.assertTrue(M.check("DecimalSeparator", "Wobbly gizmo", "Хиткий гвинтик"))
        self.assertEqual(M.check("UI.CompareHeader", "Wobbly %s gizmo", "Хиткий %s гвинтик"), [])

    def test_stay_keys_never_kept(self):
        for key in list(R.STAY_EXACT) + ["TooltipParsing.Foo", "Specs.Foo", "FailedToGetFoo"]:
            self.assertFalse(R.keep(key, "Wobbly gizmo")[0], key)
        for key in R.DISPLAY_ONLY:
            self.assertTrue(R.keep(key, "Wobbly gizmo")[0], key)


class Build(unittest.TestCase):
    ROWS = [("DecimalSeparator", "Wobbly gizmo", 4, [], ""), ("UI.CompareHeader", "Wobbly %s gizmo", 1, [], ""),
            ("X_EMPTY", "Plain gizmo", 4, [], ""), ("X_BAD", "Bent %d gizmo", 4, [], "")]
    UAS = {"DecimalSeparator": "Хиткий гвинтик", "UI.CompareHeader": "Хиткий %s гвинтик", "X_BAD": "Зігнутий"}

    def test_build_keeps_good_refuses_bad(self):
        with tempfile.TemporaryDirectory() as d:
            write_review(d, self.ROWS, self.UAS)
            K.review(M.SPEC, self.ROWS, d)          # a rerun keeps the UA lines
            entries, res = K.build(M.SPEC, self.ROWS, None, d)
            text = "\n".join(entries)
            self.assertNotIn("DecimalSeparator", text)
            self.assertIn('T["UI.CompareHeader"] = "Хиткий %s гвинтик"', text)
            self.assertIn('S["UI.CompareHeader"] = "f"', text)
            self.assertEqual(res["done"], 1)
            self.assertEqual(res["left"], 1)
            self.assertEqual(sorted(k for k, _ in res["bad"]), ["DecimalSeparator", "X_BAD"])
            K.write_data(M.SPEC, entries, "0", d, files=2)
            self.assertTrue((Path(d) / "text02.lua").is_file())

    def test_toc_lists_every_data_file(self):
        toc = (ROOT / "UADD_Pawn" / "UADD_Pawn.toc").read_text(encoding="utf-8")
        lines = [ln.strip() for ln in toc.splitlines() if ln.strip() and not ln.startswith("#")]
        data = [f"data/text{i:02d}.lua" for i in range(1, M.FILES + 1)] + ["data/names.lua"]
        self.assertEqual(lines[:len(data)], data)
        self.assertEqual(lines[len(data):], ["Swap.lua", "Game.lua", "Fonts.lua", "Module.lua"])

    def test_long_value_is_cut(self):
        e = K.lua_entry("T", "K", "ї" * 600)
        self.assertTrue(all(len(x) <= K.MAX_LINE for x in e.split("\n")))


class LuaRules(unittest.TestCase):
    """Swap.lua's lists match tools/pawn_rules.py."""
    LUA = (ROOT / "UADD_Pawn" / "Swap.lua").read_text(encoding="utf-8")

    def test_display_only(self):
        block = re.search(r"local DISPLAY = \{([^}]*)\}", self.LUA).group(1)
        self.assertEqual(set(re.findall(r'(\w+(?:\.\w+)?)"?\]? = true', block)), set(R.DISPLAY_ONLY))

    def test_stay_parts(self):
        block = re.search(r"local STAY = \{([^}]*)\}", self.LUA).group(1)
        for k in re.findall(r"(\w+) = true", block):
            self.assertTrue(R.stay(k), k)


@unittest.skipUnless(INSTALLED, "Pawn is not installed")
class Installed(unittest.TestCase):
    rows, names, why = S.source(ADDON) if INSTALLED else ([], {}, {})

    def test_data_has_no_english_of_pawn(self):
        ens = {en for _, en, *_ in self.rows if len(en) > 3}
        for p in sorted((ROOT / "UADD_Pawn").rglob("*.lua")):
            for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', p.read_text(encoding="utf-8")):
                self.assertNotIn(m.group(1), ens, f"{p.name}: Pawn's English")

    def test_saved_texts_are_never_written(self):
        """Lesson 14: a PawnLocal text Pawn copies into a field (a scale's Header, its data) is STAY, shown only
        on screen (DISPLAY_ONLY), or known not to be saved (NOT_SAVED)."""
        pat = re.compile(r"(?:\.\w+\s*=\s*|PawnAddPluginScaleProvider\([^)]*?)PawnLocal\.((?:UI\.|Stats\.)?\w+)")
        bad = set()
        for p in sorted(ADDON.glob("*.lua")):
            if p.name.startswith("Localization") or p.name == "UIStrings.lua":
                continue
            for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
                code = line.split("--")[0]
                for k in pat.findall(code):
                    if not (R.stay(k) or k in R.DISPLAY_ONLY or k in R.NOT_SAVED):
                        bad.add(f"{p.name}: {k}")
        self.assertEqual(sorted(bad), [])

    def test_every_slot_sorted(self):
        for key, en, *_ in self.rows:
            self.assertNotIn(None, M.sorts(key, en), key)

    def test_no_stay_in_rows(self):
        self.assertEqual([k for k, *_ in self.rows if R.stay(k)], [])

    def test_names_point_at_rows(self):
        keys = {k for k, *_ in self.rows}
        for path in self.names["globals"].values():
            self.assertNotIn(path.split(".")[0], ("TooltipParsing", "Specs"), path)
        self.assertTrue(set(self.names["stats"]) <= keys | set(R.DISPLAY_ONLY), "a stat path not in the rows")


if __name__ == "__main__":
    unittest.main()
