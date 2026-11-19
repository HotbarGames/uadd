"""tools/make_mc_text.py and tools/mc_text_lib.py: the UA checks (slots, colour codes, lines, spaces),
Locale.lua's Strip, the slot sorts, data files that UADD/Hash.lua reads back with the same hashes, and a
review rerun that keeps each UA. Made-up strings only (Mastercraft is all rights reserved)."""
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import hashtext as H  # noqa: E402
import make_mc_text as M  # noqa: E402
import mc_rules as R  # noqa: E402
import mc_text_lib as L  # noqa: E402
from test_hashtext import lua51, lua_core  # noqa: E402


class Gloss:
    def text(self, gid):
        return {"ui.gizmo": "Ґаджет"}.get(gid)


def row(en):
    return (en, L.kind_of(en), "Made up", "", "ru.lua")


ROWS = [row("Wobble the gizmo"), row("Gizmo %d ready on %s"), row("Fizz %d\nBuzz here"),
        row("Sprocket"), row("Plonk\nPlink")]
UA = {"Wobble the gizmo": "Похитати ґаджет", "Gizmo %d ready on %s": "Ґаджет %d готовий у %s",
      "Fizz %d\nBuzz here": "Шипіння %d\nДзижчання тут", "Sprocket": 'G"ui.gizmo"',
      "Plonk\nPlink": "Плюх\nДзень"}


def fill(folder, ua):
    """Put `ua` ({English: UA}) into the review files of `folder`."""
    for p in M.batch_files(folder):
        lines = p.read_text(encoding="utf-8").split("\n")
        for i, line in enumerate(lines):
            if line.startswith("EN: ") and L.unesc(line[4:]) in ua:
                lines[i + 1] = "UA: " + L.esc(ua[L.unesc(line[4:])])
        p.write_text("\n".join(lines), encoding="utf-8")


class CheckTest(unittest.TestCase):
    def test_good(self):
        self.assertEqual(L.check("Gizmo %d of %s", "Ґаджет %d з %s"), [])
        self.assertEqual(L.check("%s then %s", "%2$s, потім %1$s"), [])
        self.assertEqual(L.check("|cffff0000Zap|r %d", "|cffff0000Бах|r %d"), [])
        self.assertEqual(L.check("Zap %d gizmo", "Бах %d {ґаджет|ґаджети|ґаджетів}"), [])

    def test_slots(self):
        self.assertTrue(L.check("Gizmo %d of %s", "Ґаджет %d"))
        self.assertTrue(L.check("Gizmo %d", "Ґаджет %s"))
        self.assertTrue(L.check("Gizmo %s", "Ґаджет {один|два|п'ять}"))      # a plural needs a number

    def test_codes(self):
        self.assertTrue(L.check("|cffff0000Zap|r", "Бах"))
        self.assertTrue(L.check("|T123:0|t Zap", "Бах"))
        self.assertTrue(L.check("Zap {x}", "Бах {x}"))

    def test_lines_and_spaces(self):
        self.assertEqual(L.check("Zap %d\nWham", "Бах %d\nТрах"), [])
        self.assertTrue(L.check("Zap %d\nWham", "Бах %d Трах"))
        self.assertTrue(L.check("Zap\nWham %d", "Бах %d\nТрах"))            # each line its own slots
        self.assertTrue(L.check("  Zap", "Бах"))
        self.assertTrue(L.check("Zap ", "Бах"))

    def test_some_ukrainian(self):
        self.assertTrue(L.check("Wobble now", "Wobble now"))
        self.assertEqual(L.check("%d / %d", "%d / %d"), [])


class StripTest(unittest.TestCase):
    def test_strip(self):
        self.assertEqual(L.strip("  Zap \n"), "Zap")
        self.assertEqual(L.strip("|cff112233 Zap |r"), "Zap")
        self.assertEqual(L.strip("|cff112233Zap|r and |cff112233Wham|r"), "|cff112233Zap|r and |cff112233Wham|r")

    def test_kinds(self):
        self.assertEqual([L.kind_of(x) for x in ("Zap", "Zap %d", "Zap\nWham", "Zap %d\nWham")],
                         ["exact", "template", "multi-line", "multi-line template"])

    def test_sorts(self):
        self.assertEqual(R.sorts("Gizmo %d ready on %s"), [R.VALUE, R.FREE])
        self.assertEqual(R.sorts("%d gizmo, %d step%s"), [R.VALUE, R.VALUE, R.BLANK])
        self.assertEqual(R.sorts("|cff%sZap|r"), [R.VALUE])
        self.assertEqual(R.sorts("Wibble %s wobble"), [None])

    def test_colour_slot_never_free(self):
        """A |cff%s slot holds a colour code: VALUE even when OVERRIDE marks it free (lesson 7)."""
        en = "|cff%sZap|r  -  ready on %s"
        old = dict(R.OVERRIDE)
        try:
            R.OVERRIDE[H.key(en)] = "FF"
            self.assertEqual(R.sorts(en), [R.VALUE, R.FREE])
        finally:
            R.OVERRIDE.clear()
            R.OVERRIDE.update(old)


class RecordsTest(unittest.TestCase):
    def test_multi_line_template_is_split(self):
        ex, ts, problems, _ = M.records("Fizz %d\nBuzz here", "multi-line template", "Шипіння %d\nДзижчання тут", Gloss())
        self.assertEqual(problems, [])
        self.assertEqual(ex, [(H.key("Buzz here"), H.lua_str("Дзижчання тут"))])
        self.assertEqual([t["id"] for t in ts], [H.key("Fizz %d")])
        self.assertEqual(ts[0]["sort"], ["v"])

    def test_line_colour_is_kept(self):
        ex, _, problems, _ = M.records("|cff112233Plonk|r\nZip %d", "multi-line template",
                                       "|cff112233Плюх|r\nЗіп %d", Gloss())
        self.assertEqual((problems, ex), ([], [(H.key("Plonk"), H.lua_str("Плюх"))]))
        _, _, problems, _ = M.records("|cff112233Plonk|r\nZip %d", "multi-line template", "Плюх|cff112233|r\nЗіп %d",
                                      Gloss())
        self.assertTrue(problems)

    def test_refused(self):
        self.assertTrue(M.records("Wibble %s wobble", "template", "Вібл %s вобл", Gloss())[2])   # not sorted
        self.assertTrue(M.records("Zap", "exact", 'G"ui.nope"', Gloss())[2])
        ex = M.records("Zap", "exact", 'G"ui.gizmo"', Gloss())[0]
        self.assertEqual(ex, [(H.key("Zap"), 'G"ui.gizmo"')])

    def test_loose(self):
        self.assertEqual(M.records("%d, %d", "template", "%d, %d", Gloss())[3], ["%d, %d"])


class ReviewTest(unittest.TestCase):
    def test_rerun_keeps_ua(self):
        with tempfile.TemporaryDirectory() as tmp:
            M.review(ROWS, tmp)
            fill(tmp, UA)
            sizes, gone = M.review(ROWS[1:] + [row("Brand new %d")], tmp)
            self.assertEqual((sizes, gone), ([5], 1))
            rev = M.read_all(tmp)
            for en in UA:
                self.assertEqual(rev[H.key(en)][2], UA[en])
            self.assertEqual(rev[H.key("Wobble the gizmo")][1], "gone")
            self.assertEqual(rev[H.key("Brand new %d")][2], "")
            self.assertIn("slots: V", (Path(tmp) / "01.txt").read_text(encoding="utf-8"))

    def test_stale_batches_go(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "07.txt").write_text("", encoding="utf-8")
            M.review(ROWS, tmp)
            self.assertEqual([p.name for p in M.batch_files(tmp)], ["01.txt"])


@unittest.skipIf(lua51 is None, "lupa is not installed")
class LuaDataTest(unittest.TestCase):
    def test_hash_lua_reads_the_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "data"
            M.review(ROWS, tmp)
            fill(tmp, UA)
            res = M.build(ROWS, tmp, out, Gloss(), "0")
            self.assertEqual((res["bad"], res["left"], res["exact"], res["templates"]), ([], 0, 4, 2))
            files = sorted(out.glob("text*.lua"))
            self.assertEqual(len(files), M.FILES)
            text = "".join(p.read_text(encoding="utf-8") for p in files)
            for en in UA:
                for line in en.split("\n"):
                    self.assertNotIn(L.strip(line), text)
            lua = lua_core()
            lua.execute(b"UADD.Glossary = { Text = function(id) return id == 'ui.gizmo' and 'G!' or nil end }")
            ns = lua.table()
            run = lua.eval(b"function(code, ns) return assert(loadstring(code))('UADD_Mastercraft', ns) end")
            for p in files:
                run(p.read_bytes(), ns)
            ix = lua.eval(b"UADD.TextIndex")(ns.MC)
            self.assertEqual(ix.Exact(ix, b"Wobble the gizmo").decode(), "Похитати ґаджет")
            self.assertEqual(ix.Exact(ix, b"Sprocket"), b"G!")
            self.assertEqual(ix.Exact(ix, b"Plonk\nPlink").decode(), "Плюх\nДзень")
            self.assertEqual(ix.Exact(ix, b"Buzz here").decode(), "Дзижчання тут")
            tid, caps = ix.Match(ix, b"Gizmo 7 ready on Bob")[:2]
            self.assertEqual(ix.Fill(ix, tid, caps).decode(), "Ґаджет 7 готовий у Bob")


if __name__ == "__main__":
    unittest.main()
