"""tools/make_ofa_text.py, tools/ofa_source.py and tools/ofa_rules.py (with tools/key_text.py): which texts are rows,
the checks, the derived rows, a build from made-up review lines, and what UADD_OneForAll's code never does. Made-up
English only (OneForAll is GPL-3.0-or-later, but the tests need no real text)."""
import re
import sys
import tempfile
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import hashtext as H  # noqa: E402
import key_text as K  # noqa: E402
import ofa_rules as R  # noqa: E402
import ofa_source as S  # noqa: E402
import make_ofa_text as M  # noqa: E402

MOD = ROOT / "UADD_OneForAll"
DE = '''local T = {
  -- Gizmo panel
  ["Wobbly gizmo"] = "x",
  ["Total gizmos"] = "x",
  ["Gizmo supplies vendors sell these:"] = "x",
  -- LNum sentences
  ["Bites for %s damage."] = "x",
  -- Marks
  ["R (raid quest)"] = "x",
}
'''
PETS = '''local P = { { desc = "Bites for 12 damage.", why = "Odd gizmo pet." } }
'''
CODE = '''local f = CreateFrame("Frame", "OneForAllGizmo")
f.title:SetText("Shown gizmo")
f.where:SetText("Gizmo Keeper — Gizmo Vale")
f.tail:SetText(". Try the gizmo")
f.key:SetText("wobbly_key")
'''
SKILL = '''local function tile(i, s) end
tile(1, L["Total gizmos"])
'''


def code(en):
    return "Code." + H.djb2(en)


def addon(folder):
    a = Path(folder) / "OneForAll"
    for rel, text in (("OneForAll.toc", "## Version: 9.9.9\n"), ("Locales/deDE.lua", DE),
                      ("Data/HunterPets.lua", PETS), ("Gizmo.lua", CODE), ("UI/SkillUpUI.lua", SKILL)):
        p = a / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")
    return a


class Source(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.rows, self.why = S.source(addon(self.dir.name))
        self.en = {r[1] for r in self.rows}

    def tearDown(self):
        self.dir.cleanup()

    def test_lnum_key(self):
        self.assertEqual(S.lnum_key("Bites for 12 damage."), "Bites for %s damage.")
        self.assertEqual(S.lnum_key("Lasts 1.5."), "Lasts %s.")
        self.assertEqual(S.lnum_key("50% more"), "%s%% more")

    def test_rows(self):
        for en in ("Wobbly gizmo", "Total gizmos", "Bites for %s damage.", "Odd gizmo pet.", "Shown gizmo"):
            self.assertIn(en, self.en)
        for en in ("R (raid quest)", "Gizmo Keeper — Gizmo Vale", ". Try the gizmo", "wobbly_key"):
            self.assertNotIn(en, self.en)
        self.assertIn("Bites for %s damage.", R.NUMBERED)
        self.assertEqual(R.sorts(code("Bites for %s damage."), "Bites for %s damage."), ["v"])

    def test_keys_are_hashes_and_batched(self):
        for key, en, b, places, _ in self.rows:
            self.assertEqual(key, code(en))
            self.assertGreaterEqual(b, 1)
            self.assertTrue(places)
        self.assertEqual([b for b, _ in R.batches()], sorted({r[2] for r in self.rows}))

    def test_derived(self):
        self.assertEqual(S.DERIVED.get("TOTAL GIZMOS"), (code("Total gizmos"), "upper"))
        self.assertIn("Trade supplies vendors sell these (in every big city).", S.DERIVED)
        self.assertEqual(M.derive("Усього штук", "upper"), "УСЬОГО ШТУК")
        self.assertIsNone(M.derive("%d {штука|штуки|штук}", "upper"))
        self.assertEqual(M.derive("Продають це:", "colon"), "Продають це.")
        self.assertIsNone(M.derive("Продають це", "colon"))


class Rules(unittest.TestCase):
    def test_keep(self):
        self.assertFalse(R.keep("R (raid quest)")[0])
        self.assertFalse(R.keep("x")[0])
        self.assertFalse(R.keep("wobbly_key", "code")[0])
        self.assertFalse(R.keep("/ofa", "code")[0])
        self.assertTrue(R.keep("Wobbly gizmo", "code")[0])

    def test_check(self):
        k = code("Wobbly gizmo")
        self.assertEqual(R.check(k, "Wobbly gizmo", "Хитка штука"), [])
        self.assertTrue(R.check(k, "Wobbly gizmo", "Хитка — штука"))
        self.assertTrue(R.check(k, "Wobbly gizmo", "Хитка {штука|штуки|штук}"))
        self.assertTrue(R.check(code("GIZMO"), "GIZMO", "Штука"))
        self.assertTrue(R.check(k, "Wobbly gizmo", "Хитка\nштука"))
        n = "%d gizmos"
        self.assertEqual(R.check(code(n), n, "%d {штука|штуки|штук}"), [])


class Build(unittest.TestCase):
    def test_round_trip(self):
        with tempfile.TemporaryDirectory() as d:
            a = addon(d)
            review, out = Path(d) / "review", Path(d) / "data"
            review.mkdir()
            out.mkdir()
            rows, _ = M.source(a)
            M.review(rows, review)
            files = sorted(review.glob("review_*.txt"))
            self.assertTrue(files)
            for p in files:
                text = p.read_text(encoding="utf-8")
                text = re.sub(r"(?m)^UA:[ \t]*$", "UA: Хитка штука", text)
                p.write_text(text, encoding="utf-8")
            res = M.build(a, review, out)
            self.assertGreater(res["done"], 0)
            data = "".join(p.read_text(encoding="utf-8") for p in sorted(out.glob("text*.lua")))
            self.assertIn(code("Wobbly gizmo"), data)
            self.assertIn(code("TOTAL GIZMOS"), data)          # derived in capitals
            self.assertIn("ХИТКА ШТУКА", data)
            self.assertNotIn("Wobbly gizmo", data)              # no English in the data
            self.assertIn("ns.OFA", data)


def module_code():
    return {p.name: p.read_text(encoding="utf-8") for p in sorted(MOD.glob("*.lua"))}


class Guards(unittest.TestCase):
    """What UADD_OneForAll's code never does (OneForAll-design.md, the never-change list)."""
    BAD = {
        "addon messages": r"SendAddonMessage",
        "its saved data written": r"OneForAll(?:Char)?DB\s*(?:\.[\w.]+|\[[^\]]+\])\s*=[^=]",
        "its L or metatables": r"FLT\.L\b|setmetatable",
        "a hook on a game or name API": r"hooksecurefunc\s*\(\s*[\"']?(?:C_Item|C_Spell|C_Map|GetTradeSkillLine|"
                                        r"UnitName|LNum|Name)\b|hooksecurefunc\s*\(\s*(?:C_Item|C_Spell|C_Map|FLT|F)\s*,"
                                        r"\s*[\"'](?:LNum|Name)",
        "a game global written": r"_G\s*\[[^\]]+\]\s*=[^=]|BINDING_NAME\w*\s*=[^=]",
        "a chat wrap": r"AddMessage\s*=|setprinthandler",
        "a frame-kind hook": r"hooksecurefunc\s*\(\s*[\"'](?:CreateFrame|CreateFontString)",
    }

    def test_files_listed(self):
        self.assertEqual(set(module_code()), {"Words.lua", "Joined.lua", "Screen.lua", "Chat.lua", "Module.lua"})
        toc = (MOD / "UADD_OneForAll.toc").read_text(encoding="utf-8")
        for name in module_code():
            self.assertIn(name, toc)
        self.assertIn("## OptionalDeps: UALLF, ClassicUA, OneForAll", toc)

    def test_never(self):
        for name, text in module_code().items():
            body = "\n".join(line.split("--", 1)[0] for line in text.split("\n"))
            for why, rx in self.BAD.items():
                self.assertIsNone(re.search(rx, body), f"{name}: {why}")

    def test_guard_finds_planted(self):
        for planted in ('SendAddonMessage("x")', "OneForAllDB.language = 1", 'hooksecurefunc(C_Item, "GetItemInfo", f)',
                        '_G["X"] = 1', "f.AddMessage = g", 'hooksecurefunc("CreateFrame", f)', "setmetatable(t, m)"):
            self.assertTrue(any(re.search(rx, planted) for rx in self.BAD.values()), planted)

    def test_game_names_through_routes(self):
        words = module_code()["Words.lua"]
        self.assertIn("UADD.UALL and UADD.UALL.Zone", words)
        self.assertNotRegex(words, r"UADD\.(?:Zone|Npc|Item|Text|Spell)\b")

    def test_language_gate(self):
        mod = module_code()["Module.lua"]
        self.assertRegex(mod, r'ofaEnglish = OfaLanguage\(\) == "enUS"')
        self.assertIn("ofaEnglish and db ~= nil", mod)


if __name__ == "__main__":
    unittest.main()
