"""tools/make_gm_text.py (with tools/key_text.py): the checks, STAY and DISPLAY keys, the data files, and no
English of GatherMate2 in the module. Made-up English only; tests that read the installed GatherMate2 skip
when it is missing."""
import re
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import gm_rules as R  # noqa: E402
import gm_source as S  # noqa: E402
import hashtext as H  # noqa: E402
import key_text as K  # noqa: E402
import make_gm_text as M  # noqa: E402

ADDON = S.addon_dir()
INSTALLED = (ADDON / S.LOCALE).is_file()
MOD = ROOT / "UADD_GatherMate2"


def write_review(folder, rows, uas):
    out = []
    for i, (key, en, *_) in enumerate(rows, 1):
        out += K.block(M.SPEC, i, key, en, uas.get(key, ""))
    (Path(folder) / "review_01.txt").write_text("\n".join(out), encoding="utf-8")


class Checks(unittest.TestCase):
    def test_trailing_space_stays(self):
        self.assertTrue(M.check("L.x", "Wobbly gizmo for ", "Хиткий гвинтик для"))
        self.assertEqual(M.check("L.x", "Wobbly gizmo for ", "Хиткий гвинтик для "), [])

    def test_colour_codes_stay(self):
        self.assertTrue(M.check("L.x", "|cffffd200Wobbly|r gizmo", "Хиткий |cffffd200гвинтик|r"))
        self.assertTrue(M.check("L.x", "Wobbly |cffffd200gizmo|r", "Хиткий гвинтик"))
        self.assertEqual(M.check("L.x", "|cffffd200Wobbly|r gizmo", "|cffffd200Хиткий|r гвинтик"), [])

    def test_unsorted_slot_and_stay(self):
        self.assertTrue(M.check("L.x", "Wobbly %s gizmo", "Хиткий %s гвинтик"))
        for key in R.STAY:
            self.assertTrue(M.check(key, "Wobbly gizmo", "Хиткий гвинтик"), key)
            self.assertFalse(R.keep(key, "Wobbly gizmo")[0], key)
        for key in R.DISPLAY_ONLY:
            self.assertTrue(R.keep(key, "Wobbly gizmo")[0], key)

    def test_batches(self):
        self.assertEqual(R.batch_of("L.x", [("Config.lua", 10)]), 1)
        self.assertEqual(R.batch_of("L.x", [("Config.lua", R.SPLIT + 1)]), 2)
        self.assertEqual(R.batch_of("L.x", [("Display.lua", 10)]), 3)
        self.assertEqual(R.batch_of("AceDBO.new", [("Config.lua", 10)]), 3)


class Build(unittest.TestCase):
    ROWS = [("L.8d54e40a", "Wobbly gizmo ", 3, [], ""), ("L.00000001", "Wobbly gizmo", 1, [], ""),
            ("L.00000002", "Plain gizmo", 1, [], ""), ("L.00000003", "Bent gizmo ", 2, [], "")]
    UAS = {"L.8d54e40a": "Хиткий гвинтик ", "L.00000001": "Хиткий гвинтик", "L.00000003": "Зігнутий"}

    def test_build_keeps_good_refuses_bad(self):
        with tempfile.TemporaryDirectory() as d:
            write_review(d, self.ROWS, self.UAS)
            K.review(M.SPEC, self.ROWS, d)          # a rerun keeps the UA lines
            entries, res = K.build(M.SPEC, self.ROWS, None, d)
            text = "\n".join(entries)
            self.assertNotIn("8d54e40a", text)
            self.assertIn('T["L.00000001"] = "Хиткий гвинтик"', text)
            self.assertEqual((res["done"], res["left"]), (1, 1))
            self.assertEqual(sorted(k for k, _ in res["bad"]), ["L.00000003", "L.8d54e40a"])
            K.write_data(M.SPEC, entries, "0", d, files=2)
            self.assertTrue((Path(d) / "text02.lua").is_file())
            M.write_libs({"Panel.X": H.djb2("Wobbly")}, "0", d)
            self.assertIn(f'EN["Panel.X"] = "{H.djb2("Wobbly")}"', (Path(d) / "libs.lua").read_text(encoding="utf-8"))

    def test_toc_lists_every_data_file(self):
        toc = (MOD / "UADD_GatherMate2.toc").read_text(encoding="utf-8")
        lines = [ln.strip() for ln in toc.splitlines() if ln.strip() and not ln.startswith("#")]
        data = [f"data/text{i:02d}.lua" for i in range(1, M.FILES + 1)] + ["data/libs.lua"]
        self.assertEqual(lines[:len(data)], data)
        self.assertEqual(lines[len(data):], ["Swap.lua", "Options.lua", "Fonts.lua", "Module.lua"])
        self.assertIn("## Dependencies: UADD\n", toc)
        self.assertRegex(toc, r"## OptionalDeps: GatherMate2\b")


class LuaRules(unittest.TestCase):
    """Swap.lua's lists match tools/gm_rules.py."""
    LUA = (MOD / "Swap.lua").read_text(encoding="utf-8")

    def keys(self, name):
        block = re.search(r"local %s = \{([^}]*)\}" % name, self.LUA).group(1)
        return set(re.findall(r'\["(L\.[0-9a-f]{8})"\] = true', block))

    def test_stay(self):
        self.assertEqual(self.keys("STAY"), set(R.STAY))

    def test_display_only(self):
        self.assertEqual(self.keys("DISPLAY"), set(R.DISPLAY_ONLY))


@unittest.skipUnless(INSTALLED, "GatherMate2 is not installed")
class Installed(unittest.TestCase):
    rows, libs, why = S.source(ADDON) if INSTALLED else ([], {}, {})

    def test_module_has_no_english_of_gathermate2(self):
        ens = {en for _, en, *_ in self.rows if len(en) > 3}
        ens |= {k for k, *_ in S.read_locale(ADDON / S.LOCALE) if len(k) > 3}
        for p in sorted(MOD.rglob("*.lua")) + [p for p in TOOLS.glob("gm_*.py")]:
            for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', p.read_text(encoding="utf-8")):
                self.assertNotIn(m.group(1), ens, f"{p.name}: GatherMate2's English")

    def test_rule_keys_are_real(self):
        """Every hashed key in gm_rules (and so Swap.lua) is a key of GatherMate2's locale."""
        keys = {"L." + H.djb2(k) for k, *_ in S.read_locale(ADDON / S.LOCALE)}
        for k in list(R.STAY) + list(R.DISPLAY_ONLY) + list(R.GLUED):
            self.assertIn(k, keys, k)

    def test_saved_texts_are_never_written(self):
        """Lesson 14: GatherMate2 saves no text of its locale table: its settings and node data are saved by
        key (database names, numeric node IDs), never by an L[...] value."""
        pat = re.compile(r"\bdb\.[\w.\[\]\"]*\s*=\s*L\[")
        bad = []
        for name in S.CODE:
            p = ADDON / name
            for n, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                if pat.search(line.split("--")[0]):
                    bad.append(f"{name}:{n}")
        self.assertEqual(bad, [])

    def test_every_slot_sorted(self):
        for key, en, *_ in self.rows:
            self.assertNotIn(None, M.sorts(key, en), key)

    def test_batches_fit(self):
        sizes = {}
        for _, _, b, *_ in self.rows:
            sizes[b] = sizes.get(b, 0) + 1
        self.assertTrue(all(n <= 150 for n in sizes.values()), sizes)
        self.assertEqual([k for k, *_ in self.rows if R.stay(k)], [])

    def test_libs_cover_their_rows(self):
        lib_rows = {k for k, *_ in self.rows if not k.startswith("L.")}
        self.assertEqual(lib_rows, set(self.libs))


if __name__ == "__main__":
    unittest.main()
