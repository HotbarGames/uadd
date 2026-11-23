"""tools/make_lt_text.py, tools/lt_source.py and tools/lt_rules.py (with tools/key_text.py): which literals are rows,
the checks, the drafts, the data files, and no English of LootTriage in our files. Made-up English only; tests that
read the installed addon skip when it is missing."""
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
import luatok  # noqa: E402
import lt_rules as R  # noqa: E402
import lt_source as S  # noqa: E402
import make_lt_text as M  # noqa: E402
import news_texts as N  # noqa: E402

ADDON = S.addon_dir()
INSTALLED = (ADDON / S.TOC).is_file()
MOD = ROOT / "UADD_LootTriage"
OURS = [TOOLS / "make_lt_text.py", TOOLS / "lt_rules.py", TOOLS / "lt_source.py", TOOLS / "test_lt_text.py"]
LUA = r'''
local f = CreateFrame("Frame", "WobblyFrame")
f:SetText("Wobbly gizmo")
if kind == "plain gizmo" then end
if "bent gizmo" ~= kind then end
local t = { ["odd gizmo"] = 1, key = "hidden gizmo", label = "Shown gizmo" }
local p = "Interface\\Icons\\Gizmo"
print("wobblyKey", "WOBBLY_KEY", "wobbly-gizmo-atlas")
print("Two" .. " gizmos")
'''


def code(en):
    return "Code." + H.djb2(en)


def row(en, batch=1):
    return (code(en), en, batch, [], "")


def write(folder, name, text):
    (Path(folder) / name).write_text(text, encoding="utf-8")


def data_entries(folder):
    """({key: Ukrainian}, {key: sorts}) of the data files, read as Lua tokens (long values are cut with ..)."""
    t, s = {}, {}
    for p in sorted(Path(folder).glob("text*.lua")):
        tok = list(luatok.tokens(luatok.read(p)))
        for i in range(len(tok) - 5):
            if tok[i][0] == luatok.NAME and tok[i][1] in ("T", "S") and tok[i + 1][1] == "[" \
                    and tok[i + 2][0] == luatok.STR and tok[i + 4][1] == "=" and tok[i + 5][0] == luatok.STR:
                j, val = i + 5, tok[i + 5][1]
                while j + 2 < len(tok) and tok[j + 1][1] == "." and tok[j + 2][1] == "." and tok[j + 3][0] == luatok.STR:
                    j += 3
                    val += tok[j][1]
                (t if tok[i][1] == "T" else s)[tok[i + 2][1]] = val
    return t, s


class Source(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        write(self.dir.name, "Gizmo.lua", LUA)
        self.lits = {en: why for en, _, why, _ in S.literals(Path(self.dir.name) / "Gizmo.lua")}

    def tearDown(self):
        self.dir.cleanup()

    def test_left_out_by_place(self):
        self.assertEqual(self.lits["Frame"], "call CreateFrame")
        self.assertEqual(self.lits["plain gizmo"], "compare")
        self.assertEqual(self.lits["bent gizmo"], "compare")
        self.assertEqual(self.lits["odd gizmo"], "table key")
        self.assertEqual(self.lits["hidden gizmo"], "field key")
        self.assertEqual(self.lits["Interface\\Icons\\Gizmo"], "path")
        for en in ("WobblyFrame", "wobblyKey", "WOBBLY_KEY", "wobbly-gizmo-atlas"):
            self.assertIn(self.lits[en], ("key-like", "call CreateFrame"), en)

    def test_shown_kept(self):
        for en in ("Wobbly gizmo", "Shown gizmo", "Two", " gizmos"):
            self.assertEqual(self.lits[en], "", en)

    def test_source_rows(self):
        d = Path(self.dir.name)
        write(d, S.TOC, "## Version: 9.9\nGizmo.lua\n")
        rows, why = S.source(d)
        self.assertEqual([r[1] for r in rows], ["Wobbly gizmo", "Shown gizmo", "Two", " gizmos"])
        self.assertTrue(all(r[0] == code(r[1]) and r[2] == 2 for r in rows))
        self.assertEqual({k: why.get(k, 0) for k in ("compare", "table", "field", "path")},
                         {"compare": 2, "table": 1, "field": 1, "path": 1})
        self.assertEqual(S.version(d), "9.9")
        self.assertEqual(S.source(d / "missing"), ([], {}))


class Rules(unittest.TestCase):
    def test_keep(self):
        for key in list(R.CODE) + list(R.NAMES):
            self.assertFalse(R.keep(key, "Wobbly gizmo")[0], key)
        self.assertEqual(R.keep(code("x"), "  "), (False, "empty"))
        self.assertEqual(R.keep(code("x"), "%d%%"), (False, "no words"))
        self.assertEqual(R.keep(code("x"), "Wobbly gizmo"), (True, ""))

    def test_slots_codes_breaks(self):
        k = code("x")
        self.assertEqual(R.check(k, "Wobbly gizmo", "Хиткий гвинтик"), [])
        self.assertTrue(R.check(k, "Wobbly %d gizmo", "Хиткий гвинтик"))
        self.assertEqual(R.check(k, "Wobbly %d gizmo", "Хиткий %d гвинтик"), [])
        self.assertTrue(R.check(k, "Wobbly %s gizmo", "Хиткий %s гвинтик"))      # a slot nobody sorted
        self.assertTrue(R.check(k, "|cffffd200Wobbly|r gizmo", "Хиткий гвинтик"))
        self.assertTrue(R.check(k, "|cffffd200Wobbly|r gizmo", "Хиткий |cffffd200гвинтик|r"))
        self.assertEqual(R.check(k, "|cffffd200Wobbly|r gizmo", "|cffffd200Хиткий|r гвинтик"), [])
        self.assertTrue(R.check(k, "Wobbly\ngizmo", "Хиткий гвинтик"))

    def test_font_marks(self):
        k = code("x")
        self.assertTrue(R.check(k, "Wobbly gizmo", "Хиткий · гвинтик"))
        self.assertTrue(R.check(k, "Wobbly gizmo", "• Хиткий гвинтик"))
        self.assertEqual(R.check(k, "Wobbly gizmo", "Хиткий — гвинтик"), [])

    def test_rule_keys(self):
        for key in list(R.CODE) + list(R.NAMES):
            self.assertTrue(R.check(key, "Wobbly gizmo", "Хиткий гвинтик"), key)
        self.assertEqual(set(R.NOTES), set(R.SORTS))
        for key, letters in R.SORTS.items():
            self.assertRegex(key, r"^Code\.[0-9a-f]{8}$")
            self.assertRegex(letters, r"^[vtf]+$", key)      # an n would keep the line English: not a row

    def test_batches(self):
        self.assertEqual((R.batch_of("Settings.lua"), R.batch_of("SettingsWindow.lua")), (1, 1))
        self.assertEqual(R.batch_of("Gizmo.lua"), 2)
        self.assertEqual([b[0] for b in R.BATCHES], [1, 2])        # its What's New is no batch (lesson 43)
        self.assertNotIn("WhatsNew.lua", R.BATCH_FILES)
        self.assertNotIn("WhatsNew.lua", R.FILE_NOTE)
        with self.assertRaises(SystemExit):
            R.split([row("g%d" % i) for i in range(R.MAX_BATCH + 1)])


class Drafts(unittest.TestCase):
    ROWS = [row('Wobbly "gizmo"'), row("Two\nlines"), row("Plain gizmo", 2), row("Wobbly \\ gizmo", 2),
            row("Bent gizmo ", 2), row("Left gizmo", 2)]
    DRAFT = ("# made-up\nEN: Wobbly \\\"gizmo\\\"\nUA: Хиткий «гвинтик»\n\nEN: Two\\nlines\nUA: Два\\nрядки\n\n"
             "EN: Plain gizmo\nUA: Простий гвинтик\n\nEN: Wobbly \\ gizmo\nUA: Хиткий \\\\ гвинтик\n\n"
             "EN: Bent gizmo\nUA: Зігнутий гвинтик\n\nEN: Left gizmo\nUA: \n\nEN: Nowhere gizmo\nUA: Ніде\n")

    def test_key(self):
        self.assertEqual(M.draft_key("Wobbly gizmo"), "Code." + H.djb2("Wobbly gizmo"))
        self.assertRegex(M.draft_key("Wobbly gizmo"), r"^Code\.[0-9a-f]{8}$")

    def test_fills(self):
        with tempfile.TemporaryDirectory() as d:
            write(d, "draft_01.txt", self.DRAFT)
            write(d, "notes.txt", "EN: Plain gizmo\nUA: Ні\n")
            fills, unmatched = M.draft_fills(self.ROWS, d)
        k = [r[0] for r in self.ROWS]
        self.assertEqual(fills[k[0]], "Хиткий «гвинтик»")
        self.assertEqual(fills[k[1]], "Два\nрядки")
        self.assertEqual(fills[k[2]], "Простий гвинтик")
        self.assertEqual(fills[k[3]], "Хиткий \\ гвинтик")     # a raw backslash in its EN still names the row
        self.assertNotIn(k[4], fills)                           # exact only: the row has a trailing space
        self.assertNotIn(k[5], fills)                           # an empty UA fills nothing ...
        self.assertEqual(unmatched, ["Bent gizmo", "Nowhere gizmo"])   # ... but names its row

    def test_no_drafts(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(M.draft_fills(self.ROWS, Path(d) / "missing"), ({}, []))
            self.assertEqual(M.draft_fills(self.ROWS, d), ({}, []))

    def test_round_trip(self):
        """review -> drafts fill only empty UAs -> build -> data files; a rerun keeps every UA."""
        with tempfile.TemporaryDirectory() as d:
            K.review(M.SPEC, self.ROWS, d)
            p = Path(d) / "review_02.txt"
            write(d, "review_02.txt", p.read_text(encoding="utf-8").replace(
                "EN: Plain gizmo\nUA: ", "EN: Plain gizmo\nUA: Мій гвинтик", 1))
            write(d, "draft_01.txt", self.DRAFT)
            sizes, gone, filled, unmatched = M.review(self.ROWS, d)
            self.assertEqual((sizes, gone, filled), ({1: 2, 2: 4}, 0, 3))
            M.review(self.ROWS, d)
            rev = K.read_all(d)
            self.assertEqual(rev[self.ROWS[2][0]][1], "Мій гвинтик")   # the review's own UA wins
            self.assertEqual(rev[self.ROWS[1][0]][1], "Два\nрядки")
            entries, res = K.build(M.SPEC, self.ROWS, None, d)
            self.assertEqual((res["done"], res["left"], res["bad"]), (4, 2, []))
            out = Path(d) / "data"
            K.write_data(M.SPEC, entries, "0", out, files=M.FILES)
            t, _ = data_entries(out)
            self.assertEqual(t[self.ROWS[0][0]], "Хиткий «гвинтик»")
            self.assertEqual(len(list(out.glob("text*.lua"))), M.FILES)
            head = (out / "text01.lua").read_text(encoding="utf-8")
            for line in ("local _, ns = ...", "local T = ns.LT or {}; ns.LT = T", "local S = ns.SORT or {}; ns.SORT = S"):
                self.assertIn(line + "\n", head)
            for p in out.glob("text*.lua"):
                self.assertNotIn("gizmo", p.read_text(encoding="utf-8"), p.name)   # only hashes and ours


@unittest.skipUnless(INSTALLED, "LootTriage is not installed")
class Installed(unittest.TestCase):
    rows, why = S.source(ADDON) if INSTALLED else ([], {})
    every = [en for f in S.files(ADDON) for en, *_ in S.literals(ADDON / f)] if INSTALLED else []

    def test_rule_keys_are_real(self):
        keys = {code(en) for en in self.every}
        for k in list(R.SORTS) + list(R.NOTES) + list(R.CODE) + list(R.NAMES):
            self.assertIn(k, keys, k)

    def test_sorts_fit_and_batches(self):
        sizes, rows = {}, {k: en for k, en, *_ in self.rows}
        for key, en, b, *_ in self.rows:
            self.assertNotIn(None, R.sorts(key, en), key)
            sizes[b] = sizes.get(b, 0) + 1
        self.assertEqual(sorted(sizes), [1, 2])
        self.assertTrue(all(n <= R.MAX_BATCH for n in sizes.values()), sizes)
        for key, letters in R.SORTS.items():
            self.assertIn(key, rows, key)
            self.assertEqual(len(letters), len(K.slots(rows[key])), key)

    def test_whats_new_left_english(self):
        """Lesson 43: no row is shown only in its What's New; its texts are in the addon, so the drop is real."""
        news = [f for f in S.files(ADDON) if N.is_news(f)]
        self.assertTrue(news, "no What's New file found: check tools/news_texts.FILE")
        shown = {code(en) for f in news for en, _, why, _ in S.literals(ADDON / f) if not why}
        self.assertTrue(shown)
        for key, en, b, where, _ in self.rows:
            self.assertFalse(N.news_only(where), key)
        rows = {r[0] for r in self.rows}
        self.assertTrue(shown - rows, "every What's New text is a row")
        if (MOD / "data" / "text01.lua").is_file():
            t, _ = data_entries(MOD / "data")
            self.assertEqual(sorted((shown - rows) & set(t)), [], "our data holds a What's New text")

    def test_no_english_in_our_files(self):
        ens = {en for _, en, *_ in self.rows if len(en.strip()) > 3}
        files = OURS + sorted(MOD.rglob("*.lua")) + sorted(MOD.glob("*.toc"))
        for p in files:
            text = p.read_text(encoding="utf-8")
            for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', text):      # the message names the hash, not the text
                lit = K.unesc(m.group(1))
                self.assertFalse(lit in ens, f"{p.name}: its English ({code(lit)})")
            for line in text.splitlines():
                if line.lstrip().startswith(("--", "#")):
                    for en in ens:
                        if len(en.split()) >= 4:          # a sentence, not a plain two-word term
                            self.assertFalse(en in line, f"{p.name}: its English in a comment ({code(en)})")

    @unittest.skipUnless((MOD / "data" / "text01.lua").is_file(), "no data built yet")
    def test_data(self):
        """Every built entry is a row and passes the checks, its slots match, all files present."""
        t, s = data_entries(MOD / "data")
        rows = {k: en for k, en, *_ in self.rows}
        for key, ua in t.items():
            self.assertRegex(key, r"^Code\.[0-9a-f]{8}$")
            self.assertIn(key, rows, key)
            self.assertNotIn(key, R.CODE)
            self.assertNotIn(key, R.NAMES)
            self.assertEqual(R.check(key, rows[key], ua), [], key)
            self.assertEqual(s.get(key, ""), "".join(R.sorts(key, rows[key])), key)
        self.assertEqual(set(s) - set(t), set())
        for n in range(1, M.FILES + 1):
            self.assertTrue((MOD / "data" / f"text{n:02d}.lua").is_file(), n)


if __name__ == "__main__":
    unittest.main()
