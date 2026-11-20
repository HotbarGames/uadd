"""tools/make_scrap_text.py (with tools/key_text.py): the checks, the STAY keys, the data files, and no
English of Scrap in the module. Made-up English only; tests that read the installed Scrap skip when it is
missing."""
import re
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import key_text as K  # noqa: E402
import make_scrap_text as M  # noqa: E402
import scrap_rules as R  # noqa: E402
import scrap_source as S  # noqa: E402

ADDON = S.addon_dir()
INSTALLED = (ADDON / S.LOCALE).is_file()
MOD = ROOT / "UADD_Scrap"


def write_review(folder, rows, uas):
    out = []
    for i, (key, en, *_) in enumerate(rows, 1):
        out += K.block(M.SPEC, i, key, en, uas.get(key, ""))
    (Path(folder) / "review_01.txt").write_text("\n".join(out), encoding="utf-8")


class Checks(unittest.TestCase):
    def test_trailing_space_stays(self):
        self.assertTrue(R.check("L.x", "Wobbly gizmo for ", "Хиткий гвинтик для"))
        self.assertEqual(R.check("L.x", "Wobbly gizmo for ", "Хиткий гвинтик для "), [])

    def test_colour_codes_stay(self):
        self.assertTrue(R.check("L.x", "|cffffd200Wobbly|r gizmo", "Хиткий гвинтик"))
        self.assertTrue(R.check("L.x", "|cffffd200Wobbly|r gizmo", "Хиткий |cffffd200гвинтик|r"))
        self.assertEqual(R.check("L.x", "|cffffd200Wobbly|r gizmo", "|cffffd200Хиткий|r гвинтик"), [])

    def test_value_slot_ok_unsorted_slot_not(self):
        self.assertEqual(R.check("L.SoldJunk", "Wobbly gizmo %s", "Хиткий гвинтик %s"), [])
        self.assertTrue(R.check("L.x", "Wobbly %s gizmo", "Хиткий %s гвинтик"))

    def test_stay_and_game_name_slots(self):
        for key in R.STAY:
            self.assertTrue(R.check(key, "Wobbly %s gizmo", "Хиткий %s гвинтик"), key)
            self.assertFalse(R.keep(key, "Wobbly gizmo")[0], key)
        for key, marks in R.SORTS.items():
            if "n" in marks:
                self.assertIn(key, R.STAY, key)

    def test_no_long_dash(self):
        self.assertTrue(R.check("L.x", "Wobbly gizmo", "Хиткий — гвинтик"))

    def test_batches(self):
        self.assertEqual(R.batch_of("L.x", 10), 1)
        self.assertEqual(R.batch_of("L.x", R.SPLIT + 1), 2)
        self.assertEqual(R.batch_of("FAQ.1", 10), 2)
        self.assertEqual(R.batch_of("Code.0000abcd", 0), 2)


class Build(unittest.TestCase):
    ROWS = [("L.Wob", "Wobbly gizmo", 1, [], ""), ("L.Plain", "Plain gizmo", 1, [], ""),
            ("L.Bent", "Bent gizmo ", 1, [], "")]
    UAS = {"L.Wob": "Хиткий гвинтик", "L.Bent": "Зігнутий"}

    def test_build_keeps_good_refuses_bad(self):
        with tempfile.TemporaryDirectory() as d:
            write_review(d, self.ROWS, self.UAS)
            K.review(M.SPEC, self.ROWS, d)          # a rerun keeps the UA lines
            entries, res = K.build(M.SPEC, self.ROWS, None, d)
            text = "\n".join(entries)
            self.assertIn('T["L.Wob"] = "Хиткий гвинтик"', text)
            self.assertNotIn("L.Bent", text)
            self.assertEqual((res["done"], res["left"]), (1, 1))
            self.assertEqual([k for k, _ in res["bad"]], ["L.Bent"])
            K.write_data(M.SPEC, entries, "0", d, files=M.FILES)
            self.assertTrue((Path(d) / f"text{M.FILES:02d}.lua").is_file())

    def test_toc_lists_every_data_file(self):
        toc = (MOD / "UADD_Scrap.toc").read_text(encoding="utf-8")
        lines = [ln.strip() for ln in toc.splitlines() if ln.strip() and not ln.startswith("#")]
        data = [f"data/text{i:02d}.lua" for i in range(1, M.FILES + 1)]
        self.assertEqual(lines[:len(data)], data)
        self.assertEqual(lines[len(data):], ["Swap.lua", "Screen.lua", "Fonts.lua", "Module.lua"])
        self.assertIn("## Dependencies: UADD\n", toc)
        self.assertRegex(toc, r"## OptionalDeps: Scrap, UALLF\b")


class LuaRules(unittest.TestCase):
    """Swap.lua's STAY list matches tools/scrap_rules.py."""
    LUA = (MOD / "Swap.lua").read_text(encoding="utf-8")

    def test_stay(self):
        block = re.search(r"local STAY = \{([^}]*)\}", self.LUA).group(1)
        self.assertEqual(set(re.findall(r'\["(L\.\w+)"\] = true', block)), set(R.STAY))

    def test_bindings_point_at_data_keys(self):
        block = re.search(r"local BINDINGS = \{([^}]*)\}", self.LUA).group(1)
        keys = re.findall(r'= "(L\.\w+)"', block)
        self.assertEqual(len(keys), 4)
        data = "".join(p.read_text(encoding="utf-8") for p in (MOD / "data").glob("text*.lua"))
        for k in keys:
            self.assertIn(f'T["{k}"]', data, k)


@unittest.skipUnless(INSTALLED, "Scrap is not installed")
class Installed(unittest.TestCase):
    rows, why = S.source(ADDON) if INSTALLED else ([], {})

    def test_module_has_no_english_of_scrap(self):
        ens = {en for _, en, *_ in self.rows if len(en) > 3}
        files = sorted(MOD.rglob("*.lua")) + sorted(TOOLS.glob("scrap_*.py")) + [TOOLS / "make_scrap_text.py"]
        for p in files:
            for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', p.read_text(encoding="utf-8")):
                self.assertNotIn(m.group(1), ens, f"{p.name}: Scrap's English")

    def test_rule_keys_are_real(self):
        """Every key in scrap_rules (and so Swap.lua) is a key of Scrap's locale."""
        keys = {k for k, *_ in S.read_locale(ADDON / S.LOCALE)}
        for k in list(R.STAY) + list(R.SORTS) + list(R.NOTES):
            self.assertIn(k, keys, k)

    def test_saved_texts_are_never_written(self):
        """Lesson 14: Scrap saves item ids and its settings, never a text of its locale table."""
        pat = re.compile(r"\b(?:sets|charsets|junk)\b[\w.\[\]\"]*\s*=\s*L\.")
        bad = []
        for p in sorted(ADDON.rglob("*.lua")):
            if "libs" in p.parts or "localization" in p.parts:
                continue
            for n, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                if pat.search(line.split("--")[0]):
                    bad.append(f"{p.name}:{n}")
        self.assertEqual(bad, [])

    def test_every_slot_sorted(self):
        for key, en, *_ in self.rows:
            self.assertNotIn(None, R.sorts(key, en), key)

    def test_batches_fit(self):
        sizes = {}
        for _, _, b, *_ in self.rows:
            sizes[b] = sizes.get(b, 0) + 1
        self.assertTrue(all(n <= 150 for n in sizes.values()), sizes)
        self.assertEqual([k for k, *_ in self.rows if R.stay(k)], [])


if __name__ == "__main__":
    unittest.main()
